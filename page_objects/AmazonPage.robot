*** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Library    BuiltIn
Library    String
Library    random

*** Variables ***
${AMAZON_URL}         https://www.amazon.com
${SEARCH_BAR}         id=twotabsearchtextbox
${SEARCH_BUTTON}      id=nav-search-submit-button
${SEARCH_RESULTS}     css=.s-search-results
${FIRST_RESULT_LINK}  xpath=(//div[@data-component-type='s-search-result']//h2/a[contains(@href, '/dp/')])[1]

*** Keywords ***
Open Amazon Page
    [Arguments]    ${user_dir}=None
    ${headless}=    Get Environment Variable    HEADLESS    false
    ${headless}=    Convert To Lower Case    ${headless}
    Run Keyword If    '${user_dir}' != 'None'    Set Global Variable    ${USER_DATA_DIR}    ${user_dir}
    Run Keyword If    '${headless}' == 'true'    Open Amazon Headless    ELSE    Open Amazon GUI

Open Amazon GUI
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    Call Method    ${options}    add_argument    --start-maximized
    Call Method    ${options}    add_argument    --disable-infobars
    Call Method    ${options}    add_argument    --disable-extensions
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --no-first-run
    Run Keyword If    '${USER_DATA_DIR}' != ''    Call Method    ${options}    add_argument    --user-data-dir=${USER_DATA_DIR}
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page
    Wait Until Page Contains Element    ${SEARCH_BAR}    30s
    Wait Until Element Is Visible    ${SEARCH_BAR}    30s

Open Amazon Headless
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --window-size=1920,1080
    Call Method    ${options}    add_argument    --disable-gpu
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-extensions
    Call Method    ${options}    add_argument    --disable-infobars
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --lang=en-US
    Call Method    ${options}    add_argument    --no-first-run
    Run Keyword If    '${USER_DATA_DIR}' != ''    Call Method    ${options}    add_argument    --user-data-dir=${USER_DATA_DIR}
    ${exclude}=    Evaluate    ["enable-automation"]
    Call Method    ${options}    add_experimental_option    excludeSwitches    ${exclude}
    Call Method    ${options}    add_experimental_option    useAutomationExtension    ${False}
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page
    Wait Until Page Contains Element    ${SEARCH_BAR}    30s
    Wait Until Element Is Visible    ${SEARCH_BAR}    30s

Handle Amazon Interstitial Page
    ${continue_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//button[contains(text(), 'Continue shopping')]    5s
    Run Keyword If    ${continue_present}    Click Button    xpath=//button[contains(text(), 'Continue shopping')]
    ${cookies_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//input[@name='accept']    5s
    Run Keyword If    ${cookies_present}    Click Button    xpath=//input[@name='accept']
    ${zip_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//input[@aria-labelledby='GLUXZipUpdate-announce']    5s
    Run Keyword If    ${zip_present}    Press Keys    None    ESCAPE
    Sleep    2s

Input Search Query
    [Arguments]    ${query}
    Scroll Element Into View    ${SEARCH_BAR}
    Wait Until Element Is Visible    ${SEARCH_BAR}    30s
    Clear Element Text    ${SEARCH_BAR}
    Input Text    ${SEARCH_BAR}    ${query}
    Sleep    1.5s

Submit Search
    Click Button    ${SEARCH_BUTTON}
    Wait Until Page Contains Element    ${SEARCH_RESULTS}    10s

Results Should Be Visible
    Element Should Be Visible    ${SEARCH_RESULTS}

Select First Search Result
    Wait Until Element Is Visible    ${FIRST_RESULT_LINK}    10s
    Scroll Element Into View    ${FIRST_RESULT_LINK}
    Wait Until Element Is Enabled    ${FIRST_RESULT_LINK}    10s
    Click Element    ${FIRST_RESULT_LINK}

Close Browser Window
    Close Browser
