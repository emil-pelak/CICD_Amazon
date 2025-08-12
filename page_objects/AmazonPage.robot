**** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Library    BuiltIn
Library    Collections
Library    String
Library    random

*** Variables ***
${AMAZON_URL}         https://www.amazon.com
${SEARCH_BAR}         id=twotabsearchtextbox
${SEARCH_BUTTON}      id=nav-search-submit-button
${SEARCH_RESULTS}     css=.s-search-results
${FIRST_RESULT_LINK}  xpath=(//div[@data-component-type='s-search-result']//h2/a[contains(@href, '/dp/')])[1]
${USER_DATA_DIR}      ${EMPTY}

*** Keywords ***
Open Amazon Page
    ${headless}=    Get Environment Variable    HEADLESS    false
    ${headless}=    Convert To Lower Case    ${headless}
    ${jenkins}=     Get Environment Variable    JENKINS_HOME    ${EMPTY}
    Run Keyword If    '${headless}' == 'true'    Open Amazon Headless    ${jenkins}
    ...    ELSE    Open Amazon GUI    ${jenkins}

Open Amazon GUI
    [Arguments]    ${jenkins_env}
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    ${args}=    Create List
    ...    --start-maximized
    ...    --disable-infobars
    ...    --disable-extensions
    ...    --no-sandbox
    ...    --disable-dev-shm-usage
    ...    --no-first-run
    Run Keyword If    '${jenkins_env}' == '' and '${USER_DATA_DIR}' != ''    Append To List    ${args}    --user-data-dir=${USER_DATA_DIR}
    FOR    ${arg}    IN    @{args}
        Call Method    ${options}    add_argument    ${arg}
    END
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page

Open Amazon Headless
    [Arguments]    ${jenkins_env}
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
    Run Keyword If    '${jenkins_env}' == '' and '${USER_DATA_DIR}' != ''    Append To List    ${args}    --user-data-dir=${USER_DATA_DIR}
    FOR    ${arg}    IN    @{args}
        Call Method    ${options}    add_argument    ${arg}
    END
    ${exclude}=    Evaluate    ["enable-automation"]
    Call Method    ${options}    add_experimental_option    excludeSwitches    ${exclude}
    Call Method    ${options}    add_experimental_option    useAutomationExtension    ${False}
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page


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
    Click Element    ${FIRST_RESULT_LINK}

Close Browser Window
    Close Browser
