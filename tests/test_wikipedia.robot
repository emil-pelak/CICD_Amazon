*** Settings ***
Resource    ../page_objects/WikipediaPage.robot
Library     SeleniumLibrary

*** Variables ***
${BROWSER}    chrome

*** Test Cases ***
Wikipedia Search Test
    Open Wikipedia Home Page
    Search Wikipedia    Robot Framework
    Wait Until Element Is Visible    css:#firstHeading    10s
    Page Should Contain    Robot Framework

