*** Settings ***
Resource    ../page_objects/WikipediaPage.robot
Library     SeleniumLibrary
Test Teardown    Run Keyword If Test Failed    Capture Page Screenshot
Test Template    Wikipedia Article Has First Paragraph

*** Test Cases ***
Paragraph: Robot Framework
    Robot Framework
Paragraph: Jenkins (software)
    Jenkins (software)
Paragraph: Python (programming language)
    Python (programming language)

*** Keywords ***
Wikipedia Article Has First Paragraph
    [Arguments]    ${term}
    Open Wikipedia Page
    Search For                 ${term}
    Page Should Have First Paragraph
    Close Browser Window
