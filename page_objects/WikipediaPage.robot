*** Settings ***
Library    SeleniumLibrary

*** Variables ***
${SEARCH_INPUT}    css:input#searchInput
${SEARCH_BUTTON}   css:input#searchButton

*** Keywords ***
Open Wikipedia Home Page
    Open Browser    https://en.wikipedia.org/wiki/Main_Page    ${BROWSER}
    Maximize Browser Window
    Wait Until Element Is Visible    ${SEARCH_INPUT}    10s

Search Wikipedia
    [Arguments]    ${query}
    Input Text    ${SEARCH_INPUT}    ${query}
    Press Keys    ${SEARCH_INPUT}    RETURN


Open Wikipedia GUI
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    ${args}=    Create List
    ...    --start-maximized
    ...    --disable-infobars
    ...    --disable-extensions
    ...    --no-sandbox
    ...    --disable-dev-shm-usage
    ...    --no-first-run
    ...    --lang=en-US
    FOR    ${arg}    IN    @{args}
        Call Method    ${options}    add_argument    ${arg}
    END
    Create WebDriver    Chrome    options=${options}
    Go To    ${WIKI_URL}

Open Wikipedia Headless
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    ${args}=    Create List
    ...    --headless=new
    ...    --window-size=1920,1080
    ...    --disable-gpu
    ...    --no-sandbox
    ...    --disable-extensions
    ...    --disable-infobars
    ...    --disable-dev-shm-usage
    ...    --lang=en-US
    ...    --no-first-run
    FOR    ${arg}    IN    @{args}
        Call Method    ${options}    add_argument    ${arg}
    END
    Create WebDriver    Chrome    options=${options}
    Go To    ${WIKI_URL}

Search For
    [Arguments]    ${term}
    Input Text    ${SEARCH_INPUT}    ${term}
    Press Keys    ${SEARCH_INPUT}    RETURN
    Wait Until Element Is Visible    ${FIRST_HEADING}_
