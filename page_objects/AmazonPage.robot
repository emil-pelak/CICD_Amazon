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
    Run Keyword If    ${HEADLESS}    Open Amazon Headless
    ...    ELSE    Open Amazon GUI

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
    Wait Until Element Is Visible    ${SEARCH_BAR}    5s

Open Amazon Headless
    ${options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys
    ${temp_profile}=    Evaluate    str(__import__('tempfile').mkdtemp())    tempfile
    ${args}=    Create List    --headless    --disable-gpu    --no-sandbox    --disable-dev-shm-usage    --window-size=1920x1080    --user-data-dir=${temp_profile}
    FOR    ${arg}    IN    @{args}
        Call Method    ${options}    add_argument    ${arg}
    END
    Create WebDriver    Chrome    options=${options}
    Go To    ${AMAZON_URL}
    Handle Amazon Interstitial Page
    Wait Until Element Is Visible    ${SEARCH_BAR}    5s

Handle Amazon Interstitial Page
    ${is_present}=    Run Keyword And Return Status    Element Should Be Visible    xpath=//button[contains(text(), 'Continue shopping')]
    Run Keyword If    ${is_present}    Click Button    xpath=//button[contains(text(), 'Continue shopping')]
    Sleep    1s

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
    Run Keyword And Ignore Error    Press Keys    None    \ue00e
    Run Keyword And Ignore Error    Wait Until Element Is Visible    ${SEARCH_BAR}    10s
    Sleep    1s

Close Browser Window
    Close Browser
