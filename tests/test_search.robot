*** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Library    Collections
Library    String
Library    BuiltIn
Library    random
Resource    ../keywords/BrowserUtils.robot

Test Teardown    Close Browser Window

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
