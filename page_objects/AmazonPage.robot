*** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Library    Collections
Library    String
Library    BuiltIn
Library    random

*** Variables ***
${HEADLESS}           False
${AMAZON_URL}         https://www.amazon.com
${SEARCH_BAR}         id=twotabsearchtextbox
${SEARCH_BUTTON}      id=nav-search-submit-button
${SEARCH_RESULTS}     css=.s-search-results
${FIRST_RESULT_LINK}  xpath=(//div[@data-component-type='s-search-result']//h2/a[contains(@href, '/dp/')])[1]

*** Keywords ***
Open Amazon Page
    [Arguments]    ${user_dir}=None
    ${headless_env}=    Get Environment Variable    HEADLESS    false
    ${headless_env}=    Convert To Lower Case    ${headless_env}
    Set Global Variable    ${HEADLESS}    ${headless_env}
    Run Keyword If    '${user_dir}' != 'None'    Set Global Variable    ${USER_DATA_DIR}    ${user_dir}
    IF    '${HEADLESS}' == 'true'
        Open Amazon Headless
    ELSE
        Open Amazon GUI
    END

Open Amazon GUI
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    Call Method    ${options}    add_argument    --start-maximized
    Call Method    ${options}    add_argument    --disable-infobars
    Call Method    ${options}    add_argument    --disable-extensions
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --no-first-run
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page
    Wait For Page To Load Completely
    Wait Until Page Contains Element    ${SEARCH_BAR}    30s
    Wait Until Element Is Visible    ${SEARCH_BAR}    30s

Open Amazon Headless
    ${options}=    Evaluate    sys.modules["selenium.webdriver"].ChromeOptions()    sys
    ${arguments}=    Create List
    ...    --user-data-dir=${USER_DATA_DIR}
    ...    --headless=new
    ...    --disable-blink-features=AutomationControlled
    ...    --window-size=1920,1080
    ...    --disable-dev-shm-usage
    ...    --disable-gpu
    ...    --no-sandbox
    ...    --disable-extensions
    ...    --disable-infobars
    ...    --no-first-run
    ...    --lang=en-US
    ...    user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36
    FOR    ${arg}    IN    @{arguments}
        Call Method    ${options}    add_argument    ${arg}
    END
    ${exclude}=    Evaluate    ["enable-automation"]
    Call Method    ${options}    add_experimental_option    excludeSwitches    ${exclude}
    Call Method    ${options}    add_experimental_option    useAutomationExtension    ${False}
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Sleep    3s
    Handle Amazon Interstitial Page
    Wait For Page To Load Completely
    Sleep    3s
    FOR    ${i}    IN RANGE    5
        ${visible}=    Run Keyword And Return Status    Wait Until Element Is Visible    ${SEARCH_BAR}    15s
        IF    ${visible}
            Exit For Loop
        END
        Log    Retry ${i+1}: Search bar not visible yet...
        Sleep    3s
    END
    IF    not ${visible}
        Capture Page Screenshot
        Fail    Search bar not visible after retries.
    END

Wait For Page To Load Completely
    ${ready}=    Execute JavaScript    return document.readyState
    WHILE    '${ready}' != 'complete'
        Sleep    1s
        ${ready}=    Execute JavaScript    return document.readyState
    END
    Sleep    1s

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
    ${random_delay}=    Evaluate    random.uniform(1.5, 3.5)    random
    Scroll Element Into View    ${SEARCH_BAR}
    Wait Until Element Is Visible    ${SEARCH_BAR}    30s
    Clear Element Text    ${SEARCH_BAR}
    Input Text    ${SEARCH_BAR}    ${query}
    Sleep    ${random_delay}

Submit Search
    Click Button    ${SEARCH_BUTTON}
    Wait Until Page Contains Element    ${SEARCH_BAR}    10s
    Run Keyword And Ignore Error    Wait Until Element Is Visible    ${SEARCH_RESULTS}    10s

Results Should Be Visible
    Element Should Be Visible    ${SEARCH_RESULTS}

Scroll To Bottom
    Execute JavaScript    window.scrollTo(0, document.body.scrollHeight)
    Sleep    2s

Scroll To Top
    Execute JavaScript    window.scrollTo(0, 0)
    Sleep    1s

Select First Search Result
    Run Keyword And Ignore Error    Wait Until Element Is Visible    ${FIRST_RESULT_LINK}    10s
    Run Keyword And Ignore Error    Scroll Element Into View    ${FIRST_RESULT_LINK}
    Sleep    1s
    Run Keyword And Ignore Error    Wait Until Element Is Enabled    ${FIRST_RESULT_LINK}    10s
    Run Keyword And Ignore Error    Click Element    ${FIRST_RESULT_LINK}
    Sleep    3s
    Run Keyword And Ignore Error    Press Keys    None    
    Run Keyword And Ignore Error    Wait Until Element Is Visible    ${SEARCH_BAR}    10s
    Sleep    1s

Close Browser Window
    Close Browser
