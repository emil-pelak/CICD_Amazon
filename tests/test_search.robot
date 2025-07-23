*** Settings ***
Library     SeleniumLibrary
Resource    ../page_objects/AmazonPage.robot
Resource    ../keywords/BrowserUtils.robot

*** Variables ***
@{SEARCH_TERMS}    Mouse    Keyboard    Display    Laptop

*** Test Cases ***
Search For Items On Amazon
    Open Amazon Page
    FOR    ${term}    IN    @{SEARCH_TERMS}
        Input Search Query    ${term}
        Submit Search
        Results Should Be Visible
        Sleep    1s
    END
    Close Browser Window
