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

echo -e "${GREEN}🐍 Tworzenie środowiska virtualenv...${NC}"
python3 -m venv venv
source venv/bin/activate

echo -e "${GREEN}📦 Instalowanie zależności...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${GREEN}🚀 Uruchamianie testów (HEADLESS=$HEADLESS)...${NC}"
robot --outputdir robot_reports tests/

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
