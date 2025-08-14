*** Settings ***
Library    SeleniumLibrary    timeout=10    implicit_wait=0    run_on_failure=Capture Page Screenshot
Library    BuiltIn
Library    OperatingSystem
Library    String

*** Variables ***
${WIKI_URL}           https://en.wikipedia.org
${SEARCH_INPUT}       css:input#searchInput
${FIRST_HEADING}      css:#firstHeading
${PROFILE_DIR}        ${None}

*** Keywords ***
_Open Unique Chrome Profile
    ${tmp}=      Get Environment Variable    TMPDIR    /tmp
    ${stamp}=    Get Time    epoch
    ${dir}=      Set Variable    ${tmp}/robot-${stamp}
    Create Directory    ${dir}
    Set Suite Variable  ${PROFILE_DIR}    ${dir}

_Open Chrome With Args
    [Arguments]    @{extra_args}
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    FOR    ${arg}    IN    @{extra_args}
        Call Method    ${options}    add_argument    ${arg}
    END
    Create WebDriver    Chrome    options=${options}

Open Wikipedia Page
    ${headless}=    Get Environment Variable    HEADLESS    true
    ${headless}=    Convert To Lower Case    ${headless}
    _Open Unique Chrome Profile
    IF    '${headless}' == 'true'
        _Open Chrome With Args
        ...    --headless=new
        ...    --window-size=1920,1080
        ...    --disable-gpu
        ...    --no-sandbox
        ...    --disable-extensions
        ...    --disable-infobars
        ...    --disable-dev-shm-usage
        ...    --lang=en-US
        ...    --no-first-run
        ...    --user-data-dir=${PROFILE_DIR}
    ELSE
        _Open Chrome With Args
        ...    --start-maximized
        ...    --disable-infobars
        ...    --disable-extensions
        ...    --no-sandbox
        ...    --disable-dev-shm-usage
        ...    --no-first-run
        ...    --lang=en-US
        ...    --user-data-dir=${PROFILE_DIR}
    END
    Go To    ${WIKI_URL}
    Wait Until Element Is Visible    ${SEARCH_INPUT}    15s

Search For
    [Arguments]    ${term}
    Input Text    ${SEARCH_INPUT}    ${term}
    Press Keys    ${SEARCH_INPUT}    RETURN
    Wait Until Element Is Visible    ${FIRST_HEADING}    15s

Heading Should Contain
    [Arguments]    ${expected}
    ${heading}=    Get Text    ${FIRST_HEADING}
    Should Contain    ${heading}    ${expected}

Close Browser Window
    Close Browser
    # Sprzątanie po teście – usuń tymczasowy profil
    Run Keyword And Ignore Error    Remove Directory    ${PROFILE_DIR}    recursive=True
