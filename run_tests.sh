#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🧹 Czyszczenie poprzednich raportów...${NC}"
rm -rf robot_reports
mkdir -p robot_reports

# Ustal tryb HEADLESS na podstawie środowiska
if [[ -z "$HEADLESS" ]]; then
  if [[ "$CI" == "true" || "$CI" == "True" ]]; then
    export HEADLESS=true
  else
    export HEADLESS=false
  fi
fi

# Losowy unikalny folder USER_DATA_DIR
export USER_DATA_DIR="/tmp/robot-$(uuidgen)"

echo -e "${GREEN}🐍 Tworzenie środowiska virtualenv...${NC}"
python3 -m venv venv
source venv/bin/activate

echo -e "${GREEN}📦 Instalowanie zależności...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${GREEN}🚀 Uruchamianie testów (HEADLESS=$HEADLESS)...${NC}"
robot --outputdir robot_reports \
      --variable HEADLESS:"${HEADLESS}" \
      --variable USER_DATA_DIR:"${USER_DATA_DIR}" \
      tests/

# Otwórz raport tylko jeśli HEADLESS == false
if [[ "$HEADLESS" == "false" && -f "robot_reports/report.html" ]]; then
  if command -v google-chrome &> /dev/null; then
    echo -e "${GREEN}🌐 Otwieram raport w trybie blokującym. Zamknij przeglądarkę, aby zakończyć skrypt.${NC}"
    google-chrome --app="file://$(pwd)/robot_reports/report.html" --window-size=1200,800
  else
    echo -e "${GREEN}💡 Zainstaluj google-chrome aby automatycznie otwierać raport.${NC}"
  fi
fi

echo -e "${GREEN}✅ Zakończono. Raport: robot_reports/report.html${NC}"


# #!/usr/bin/env bash
# set -euo pipefail

# # Domyślne wartości (możesz nadpisać: HEADLESS=false SEARCH_TERM="Python")
# : "${HEADLESS:=true}"
# : "${SEARCH_TERM:=Robot Framework}"

# python3 -m venv venv 2>/dev/null || true
# . venv/bin/activate
# pip install --upgrade pip wheel
# pip install -r requirements.txt

# mkdir -p robot_reports/local
# echo "Running locally: HEADLESS=${HEADLESS}, SEARCH_TERM=${SEARCH_TERM}"
# robot --outputdir robot_reports/local \
#       --variable HEADLESS:${HEADLESS} \
#       --variable SEARCH_TERM:"${SEARCH_TERM}" \
#       tests/ || true

# echo "Done. See robot_reports/local/report.html"
