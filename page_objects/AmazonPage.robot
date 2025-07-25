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
    ${headless_env}=    Get Environment Variable    HEADLESS    false
    ${headless_env}=    Convert To Lower Case    ${headless_env}
    Set Global Variable    ${HEADLESS}    ${headless_env}
    Run Keyword If    '${HEADLESS}' == 'true'    Open Amazon Headless    ELSE    Open Amazon GUI

Open Amazon GUI
    ${options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys
    Call Method    ${options}    add_argument    --start-maximized
    Call Method    ${options}    add_argument    --disable-infobars
    Call Method    ${options}    add_argument    --disable-extensions
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page
    Wait Until Element Is Visible    ${SEARCH_BAR}    15s

Open Amazon Headless
    ${options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys
    Call Method    ${options}    add_argument    headless
    Call Method    ${options}    add_argument    no-sandbox
    Call Method    ${options}    add_argument    disable-dev-shm-usage
    Call Method    ${options}    add_argument    disable-gpu
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page
    Wait Until Element Is Visible    ${SEARCH_BAR}    15s

Handle Amazon Interstitial Page
    ${continue_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//button[contains(text(), 'Continue shopping')]
    Run Keyword If    ${continue_present}    Click Button    xpath=//button[contains(text(), 'Continue shopping')]
    ${cookies_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//input[@name='accept']
    Run Keyword If    ${cookies_present}    Click Button    xpath=//input[@name='accept']
    ${zip_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//input[@aria-labelledby='GLUXZipUpdate-announce']
    Run Keyword If    ${zip_present}    Press Keys    None    ESCAPE
    Sleep    2s

Input Search Query
    [Arguments]    ${query}
    ${random_delay}=    Evaluate    random.uniform(1.5, 3.5)    random
    Wait Until Element Is Visible    ${SEARCH_BAR}    10s
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
