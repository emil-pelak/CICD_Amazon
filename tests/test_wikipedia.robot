*** Settings ***
Resource    ../page_objects/WikipediaPage.robot
Library     SeleniumLibrary
Library     Collections

Test Teardown    Run Keyword If Test Failed    Capture Page Screenshot
...              Close Browser Window

*** Variables ***
@{SEARCH_TERMS}    Robot Framework    Jenkins    Python

*** Test Cases ***
Wikipedia Search Multiple Terms
    Open Wikipedia Page
    FOR    ${term}    IN    @{SEARCH_TERMS}
        Search For                 ${term}
        Heading Should Contain     ${term}
    END
