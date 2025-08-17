*** Settings ***
Library    SeleniumLibrary
Library    Collections  

*** Variables ***
# Domyślnie wyłączone – w CI nadpisujesz: --variable HEADLESS:true
${HEADLESS}              false
${WIKI_BASE}             https://%{LANG=en}.wikipedia.org

# Lokatory (bazowe + alternatywny dla różnych skinów)
${SEARCH_INPUT_MAIN}     css:#searchInput
${SEARCH_INPUT_ALT}      css:input[name="search"]
${SEARCH_RESULTS}        css:ul.mw-search-results li a
${DISAMBIG_NOTE}         css:table.hatnote.disambig
${FIRST_HEADING}         xpath=//h1[@id='firstHeading' or contains(@class,'firstHeading')]
${FIRST_PARA}            xpath=(//div[@id='mw-content-text']//p[normalize-space()])[1]
${INFOBOX}               xpath=(//table[contains(@class,'infobox')] | //div[contains(@class,'infobox')] | //aside[contains(@class,'infobox')])[1]

*** Keywords ***
Open Wikipedia Page
    [Arguments]    ${lang}=en
    ${url}=            Set Variable    https://${lang}.wikipedia.org
    ${is_headless}=    Set Variable If    '${HEADLESS}'=='true'    ${True}    ${False}

    # ChromeOptions
    ${options}=    Evaluate    selenium.webdriver.ChromeOptions()    modules=selenium.webdriver
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-gpu
    Call Method    ${options}    add_argument    --disable-dev-shm-usage

    # HEADLESS → stały rozmiar
    Run Keyword If    ${is_headless}        Call Method    ${options}    add_argument    --headless\=new
    Run Keyword If    ${is_headless}        Call Method    ${options}    add_argument    --window-size\=1920,1080

    # GUI → start w trybie full screen (często pewniejsze niż "start-maximized")
    Run Keyword If    not ${is_headless}    Call Method    ${options}    add_argument    --start-fullscreen

    Create WebDriver    Chrome    options=${options}
    Go To    ${url}

    # Wymuś „pełny ekran” w GUI (po starcie strony)
    Run Keyword If    not ${is_headless}    Set Window Position    0    0
    ${w}=    Run Keyword If    not ${is_headless}    Execute Javascript    return screen.availWidth
    ${h}=    Run Keyword If    not ${is_headless}    Execute Javascript    return screen.availHeight
    Run Keyword If    not ${is_headless} and ${w} and ${h}    Set Window Size    ${w}    ${h}
    Run Keyword If    not ${is_headless}    Maximize Browser Window

    # dalej Twoje oczekiwanie na textbox wyszukiwania:
    Wait Until Element Is Visible    ${SEARCH_INPUT_MAIN}    20s


Wait For Search Box To Be Ready
    ${loc}=    Get Search Box Locator
    Wait Until Element Is Visible    ${loc}    15s

Get Search Box Locator
    # Preferuj główny; jeśli go nie ma — alternatywny; jeśli nadal brak, przełącz skin i spróbuj ponownie
    ${ok_main}=    Run Keyword And Return Status    Page Should Contain Element    ${SEARCH_INPUT_MAIN}
    Run Keyword If    ${ok_main}     Return From Keyword    ${SEARCH_INPUT_MAIN}
    ${ok_alt}=     Run Keyword And Return Status    Page Should Contain Element    ${SEARCH_INPUT_ALT}
    Run Keyword If    ${ok_alt}      Return From Keyword    ${SEARCH_INPUT_ALT}

    ${current}=    Get Location
    Go To          ${current}?useskin=vector-2022
    ${ok_main2}=   Run Keyword And Return Status    Page Should Contain Element    ${SEARCH_INPUT_MAIN}
    Run Keyword If  ${ok_main2}     Return From Keyword    ${SEARCH_INPUT_MAIN}
    ${ok_alt2}=    Run Keyword And Return Status    Page Should Contain Element    ${SEARCH_INPUT_ALT}
    Run Keyword If  ${ok_alt2}      Return From Keyword    ${SEARCH_INPUT_ALT}

    Fail    Could not find a usable search input on this page.

Handle Wikipedia Consent If Present
    # Rozmaite warianty przycisku cookies
    ${clicked}=    Set Variable    ${False}
    ${has_btn}=    Run Keyword And Return Status    Page Should Contain Element    css:button#pc-accept-all
    Run Keyword If    ${has_btn}    Click Element    css:button#pc-accept-all
    Run Keyword If    ${has_btn}    Set Variable    ${clicked}    ${True}

    Run Keyword If    not ${clicked}    Click Element    xpath=//button[normalize-space()='Accept all' or normalize-space()='Accept all cookies']    timeout=0.1s
    ...    ELSE    No Operation
    Run Keyword If    not ${clicked}    Click Element    xpath=//button[contains(.,'Zgadzam') or contains(.,'Akceptuj')]    timeout=0.1s
    ...    ELSE    No Operation

Search For
    [Arguments]    ${term}
    ${loc}=    Get Search Box Locator
    Wait Until Element Is Visible    ${loc}    10s
    Clear Element Text               ${loc}
    Input Text                       ${loc}    ${term}
    Press Keys                       ${loc}    ENTER
    Ensure On Article Page

Ensure On Article Page
    ${on_results}=    Run Keyword And Return Status    Page Should Contain Element    ${SEARCH_RESULTS}
    Run Keyword If    ${on_results}    Click Element    xpath=(//ul[contains(@class,'mw-search-results')]//li//a)[1]
    ${is_disambig}=   Run Keyword And Return Status    Page Should Contain Element    ${DISAMBIG_NOTE}
    Run Keyword If    ${is_disambig}   Click Element    xpath=(//div[@id='mw-content-text']//ul[1]//a)[1]
    Wait Until Element Is Visible    ${FIRST_HEADING}    20s

Page Should Have First Paragraph
    Wait Until Element Is Visible    ${FIRST_PARA}    20s
    Element Should Be Visible        ${FIRST_PARA}

Page Should Have Infobox
    Ensure On Article Page
    Wait Until Element Is Visible    ${INFOBOX}    20s
    Element Should Be Visible        ${INFOBOX}

Heading Should Contain
    [Arguments]    ${term}
    # retry, żeby wygasić ewentualne przeładowania H1
    Wait Until Keyword Succeeds    5x    1s    _Heading Should Contain Once    ${term}

_Heading Should Contain Once
    [Arguments]    ${term}
    ${text}=    Get Text    ${FIRST_HEADING}
    Should Contain    ${text}    ${term}    ignore_case=True

Close Browser Window
    Run Keyword And Ignore Error    Close Browser
