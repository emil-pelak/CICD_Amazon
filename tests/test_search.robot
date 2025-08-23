*** Settings ***
Resource    ../page_objects/WikipediaPage.robot
Library     SeleniumLibrary
Test Teardown    Run Keyword If Test Failed    Capture Page Screenshot
Test Template    Wikipedia Search Should Succeed

*** Test Cases ***
Search: Robot Framework
    Robot Framework
Search: Jenkins (software)
    Jenkins (software)
Search: Python (programming language)
    Python (programming language)
Search: Selenium (software)
    Selenium (software)
Search: Docker (software)
    Docker (software)
Search: Git
    Git
Search: Linux
    Linux
Search: Amazon (company)
    Amazon (company)

*** Keywords ***
Wikipedia Search Should Succeed
    [Arguments]    ${term}
    Open Wikipedia Page
    # Search For                 ${term}
    Heading Should Contain     ${term}
    Page Should Have First Paragraph
    Close Browser Window
