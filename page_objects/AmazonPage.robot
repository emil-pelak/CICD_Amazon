*** Settings ***
Library    SeleniumLibrary

*** Variables ***
${AMAZON_URL}         https://www.amazon.com
${SEARCH_BAR}         id=twotabsearchtextbox
${SEARCH_BUTTON}      id=nav-search-submit-button
${SEARCH_RESULTS}     css=.s-search-results
${FIRST_RESULT_LINK}  xpath=(//div[@data-component-type='s-search-result']//h2/a[contains(@href, '/dp/')])[1]

*** Keywords ***
Open Amazon Page
    Open Browser    ${AMAZON_URL}    Chrome
    Maximize Browser Window
    Wait Until Element Is Visible    ${SEARCH_BAR}    15s
    Handle Continue Shopping Page

Input Search Query
    [Arguments]    ${query}
    Wait Until Element Is Visible    ${SEARCH_BAR}    15s
    Clear Element Text    ${SEARCH_BAR}
    Input Text    ${SEARCH_BAR}    ${query}
    Sleep    1s

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
    Run Keyword And Ignore Error    Wait Until Element Is Visible    ${FIRST_RESULT_LINK}    15s
    Run Keyword And Ignore Error    Scroll Element Into View    ${FIRST_RESULT_LINK}
    Sleep    1s
    Run Keyword And Ignore Error    Wait Until Element Is Enabled    ${FIRST_RESULT_LINK}    10s
    Run Keyword And Ignore Error    Click Element    ${FIRST_RESULT_LINK}
    Sleep    3s
    Run Keyword And Ignore Error    Press Keys    None    \ue00e
    Run Keyword And Ignore Error    Wait Until Element Is Visible    ${SEARCH_BAR}    15s
    Sleep    1s

Close Browser Window
    Close Browser

Handle Continue Shopping Page
    ${is_present}=    Run Keyword And Return Status
    ...    Element Should Be Visible    xpath=/html/body/div/div[1]/div[3]/div/div/form/div/div/span/span/button
    IF    ${is_present}
        Click Button    xpath=/html/body/div/div[1]/div[3]/div/div/form/div/div/span/span/button
        Sleep    2s
    END