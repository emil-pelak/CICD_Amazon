*** Settings ***
Resource    ../page_objects/WikipediaPage.robot
Library     SeleniumLibrary
Test Teardown    Run Keyword If Test Failed    Capture Page Screenshot
Test Template    Wikipedia Article Has Infobox

*** Test Cases ***
Infobox: Robot Framework
    Robot Framework
Infobox: Jenkins (software)
    Jenkins (software)
Infobox: Python (programming language)
    Python (programming language)
Infobox: Amazon (company)
    Amazon (company)

*** Keywords ***
Wikipedia Article Has Infobox
    [Arguments]    ${term}
    Open Wikipedia Page
    # Search For                 ${term}
    Page Should Have Infobox
    Close Browser Window
