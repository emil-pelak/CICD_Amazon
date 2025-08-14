*** Settings ***
Resource    ../page_objects/WikipediaPage.robot
Library     SeleniumLibrary
Library     Collections

*** Variables ***
${BROWSER}    chrome
@{SEARCH_TERMS}    Robot Framework    Jenkins    Pythons

*** Test Cases ***
Wikipedia Search Multiple Terms
    Open Wikipedia Home Page
    FOR    ${term}    IN    @{SEARCH_TERMS}
        Search Wikipedia    ${term}
        Wait Until Element Is Visible    css:#firstHeading    10s
        Page Should Contain    ${term}
    END
