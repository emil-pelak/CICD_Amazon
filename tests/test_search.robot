*** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Library    Collections
Library    String
Library    BuiltIn
Library    random
Resource    ../keywords/BrowserUtils.robot
Resource    ../page_objects/AmazonPage.robot

Test Teardown    Close Browser Window

*** Variables ***
@{SEARCH_TERMS}    Mouse    Keyboard    Display    Laptopy

*** Test Cases ***
Search For Items On Amazon
    Open Amazon Page    ${USER_DATA_DIR}
    FOR    ${term}    IN    @{SEARCH_TERMS}
        Input Search Query    ${term}
        Submit Search
        Results Should Be Visible
        Sleep    1s
    END
    Select First Search Result
    Sleep    2s
    Capture Page Screenshot
