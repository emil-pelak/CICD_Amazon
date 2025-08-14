# CICD_Wikipedia

Prosty pipeline Jenkins + Robot Framework (Selenium) testujący wyszukiwanie na Wikipedii.

## Lokalnie

```bash
./run_tests.sh               # HEADLESS=true, SEARCH_TERM="Robot Framework"
HEADLESS=false SEARCH_TERM="Python" ./run_tests.sh
