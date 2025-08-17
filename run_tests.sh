#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🧹 Cleaning previous reports...${NC}"
rm -rf robot_reports
mkdir -p robot_reports

# Decide HEADLESS from env/CI
if [[ -z "${HEADLESS:-}" ]]; then
  if [[ "${CI:-}" == "true" || "${CI:-}" == "True" ]]; then
    export HEADLESS=true
  else
    export HEADLESS=false
  fi
fi

# Unique user data dir for Selenium browser only (not used to open the report)
export USER_DATA_DIR="/tmp/robot-$(uuidgen 2>/dev/null || echo $$)"

echo -e "${GREEN}🐍 Creating virtualenv...${NC}"
python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate

echo -e "${GREEN}📦 Installing dependencies...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${GREEN}🚀 Running tests (HEADLESS=$HEADLESS)...${NC}"

# Do not abort the script on test failures—capture Robot's exit code instead
set +e
robot --outputdir robot_reports \
      --variable HEADLESS:"${HEADLESS}" \
      --variable USER_DATA_DIR:"${USER_DATA_DIR}" \
      tests/
RC=$?
set -e

# Open the report even on FAIL when running with GUI (HEADLESS=false)
if [[ "$HEADLESS" == "false" && -f "robot_reports/report.html" ]]; then
  REPORT_URL="file://$(readlink -f robot_reports/report.html)"

  # Detect Chrome/Chromium
  CHROME_BIN=""
  for CAND in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$CAND" >/dev/null 2>&1; then
      CHROME_BIN="$CAND"
      break
    fi
  done

  if [[ -n "$CHROME_BIN" ]]; then
    echo -e "${GREEN}🌐 Opening report full screen in ${CHROME_BIN}...${NC}"
    # Open in a new full-screen window; avoid --user-data-dir (can be locked by test session)
    "$CHROME_BIN" --start-fullscreen --new-window "$REPORT_URL" >/dev/null 2>&1 &
    # Optional: push F11 if wmctrl/xdotool are available
    if command -v wmctrl >/dev/null 2>&1 && command -v xdotool >/dev/null 2>&1; then
      sleep 2
      wmctrl -a "report.html" || true
      xdotool key F11 || true
    fi
  else
    echo -e "${GREEN}💡 Chrome/Chromium not found. Falling back to system opener (xdg-open).${NC}"
    xdg-open "$REPORT_URL" >/dev/null 2>&1 || true
  fi
fi

echo -e "${GREEN}✅ Done. Report: robot_reports/report.html${NC}"
exit $RC
