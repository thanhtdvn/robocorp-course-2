*** Settings ***
Documentation   Orders robots from RobotSpareBin Industries Inc.
...             Saves the order HTML receipt as a PDF file.
...             Saves the screenshot of the ordered robot.
...             Embeds the screenshot of the robot to the PDF receipt.
...             Creates ZIP archive of the receipts and the images.
Library    Browser
Library    RPA.HTTP
Library    RPA.Tables
Library    RPA.Browser
Library    RPA.PDF
Library    String
Library    OperatingSystem
Library    RPA.Archive
Library    Collections
Library    RPA.Robocloud.Secrets
Library    RPA.Dialogs

*** Variables ***
${ORDER_PAGE_URL}=    https://robotsparebinindustries11.com/#/robot-order
${DOWNLOAD_ORDER_FILE_URL}=    https://robotsparebinindustries.com/orders.csv
${MAX_TRIED_COUNTS}=    ${3}
# Running mode: Full -> loop over full csv; Test -> loop over only 2 orders.
${RUNNING_MODE}=    FULL


${SAVED_ORDER_FILE}=    orders.csv
${ORDERED_ROBOTS_FOLDER}=    ${CURDIR}${/}output${/}orders

*** Keywords ***
Initialize
    Create Directory    ${ORDERED_ROBOTS_FOLDER}
    Empty Directory    ${ORDERED_ROBOTS_FOLDER}
    ${secret}=    Get Secret    SETTINGS
    Set Global Variable    ${ORDER_PAGE_URL}    ${secret}[ORDER_PAGE_URL]
    Set Global Variable    ${DOWNLOAD_ORDER_FILE_URL}    ${secret}[DOWNLOAD_ORDER_FILE_URL]    
    IF    ${secret}[MAX_TRIED_COUNTS] > 0
        Set Global Variable    ${MAX_TRIED_COUNTS}    ${secret}[MAX_TRIED_COUNTS]
    END

    Log    ${ORDER_PAGE_URL}
    Log    ${DOWNLOAD_ORDER_FILE_URL}
    Log    ${MAX_TRIED_COUNTS}

*** Keywords ***
Process An Order
    [Arguments]    ${order_row}
    FOR    ${counter}    IN RANGE    ${MAX_TRIED_COUNTS}
        Log    Try times: ${counter}
        ${status}=    Run Keyword And Return Status    Build A Robot    ${order_row}
        IF    ${status}
            Exit For Loop
        ELSE
            Reload The Robot Order Page
        END    
    END
    [Return]    ${status}

*** Keywords ***
Build A Robot
    [Arguments]    ${order_row}
    Close The Annoyding Modal
    Fill The Form    ${order_row}
    Preview The Robot
    Submit The Order
#     ${pdf}=    Store The Receipt As A PDF File    ${order_row}[Order Number]
    ${robot_name}=    Set Variable    robot_${order_row}[Order number]
    Take A Screenshot Of The Robot    ${robot_name}
    Export The Reciept As A PDF File    ${robot_name}
    Go To Order Another Robot
    
*** Keywords ***
Open The Robot Order Website
    New Browser    headless=true
    New Page    ${ORDER_PAGE_URL}

*** Keywords ***
Reload The Robot Order Page
    Browser.Go To    ${ORDER_PAGE_URL}

*** Keywords ***
Get Orders
    RPA.HTTP.Download    ${DOWNLOAD_ORDER_FILE_URL}    ${SAVED_ORDER_FILE}    overwrite=True
    @{orders}   Read Orders From CSV File    ${SAVED_ORDER_FILE}
    [Return]    @{orders}

*** Keywords ***
Read Orders From CSV File
    [Arguments]    ${file_name}
    ${table}=    Read Table From Csv    ${SAVED_ORDER_FILE}    header=True
    [Return]    ${table}

*** Keywords ***
Close The Annoyding Modal
    Click    css=.alert-buttons >> text=OK

*** Keywords ***
Fill The Form    
    [Arguments]    ${row}
    Log    ${row}[Head]
    Select Options By    css=#head    value    ${row}[Head]
    Click    id=id-body-${row}[Body]
    Type Text    //input[@placeholder="Enter the part number for the legs"]  ${row}[Legs]
    Type Text    id=address    ${row}[Address]

*** Keywords ***
Preview The Robot
    Click    id=preview

*** Keywords ***
Submit The Order
   Click    id=order

*** Keywords ***
Take A Screenshot Of The Robot
    [Arguments]    ${robot_name}
    Wait For Elements State    css=#robot-preview-image > img
    Sleep    2
    Take Screenshot    filename=${ORDERED_ROBOTS_FOLDER}${/}${robot_name}    selector=id=robot-preview-image

*** Keywords ***
Export The Reciept As A PDF File 
    [Arguments]    ${robot_name}
    ${receipt_html}=    Get Property    id=receipt    innerHTML
    ${receipt_html}=    Set Variable    ${receipt_html} <p><img src="${ORDERED_ROBOTS_FOLDER}${/}${robot_name}.png"/></p>
    #${receipt_html}=    Format String    {receipt_html} <p><img src="{robot_img}"/></p>    receipt_html=${receipt_html}    robot_img=${CURDIR}${/}output${/}${robot_name}.png
    Html To Pdf    ${receipt_html}    ${ORDERED_ROBOTS_FOLDER}${/}${robot_name}_receipt.pdf

*** Keywords ***
Go To Order Another Robot
    Click    id=order-another

*** Keywords ***
Create A Zip File Of The Receipts
    Archive Folder With Zip    ${ORDERED_ROBOTS_FOLDER}    ${OUTPUT_DIR}${/}ordered_orders.zip

*** Keywords ***
Confirmation Running Mode Dialog
    Add icon    Warning
    Add heading    Please choose which running mode do you want to test?
    Add drop-down    
    ...    name=running_mode
    ...    options=FULL,TEST
    ...    default=FULL
    ...    label=Running mode:
    Add text    Note:
    Add text    .... FULL -> loop over full of orders from csv
    Add text    .... TEST -> loop over only 2 orders
    ${result}=    Run dialog
    Set Global Variable    ${RUNNING_MODE}    ${result.running_mode}

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Initialize
    #Confirmation Running Mode Dialog
    Open The Robot Order Website
    @{orders}=    Get Orders
    @{failed_orders}=    Create List
    ${i}    Set Variable    1
    FOR    ${row}    IN    @{orders}
        Exit For Loop If    """${RUNNING_MODE}""" == """TEST""" and ${i} > 2
        Log    Process order number: ${row}[Order number]
        ${status}=    Process An Order    ${row}
        IF    ${status}
            Log    Successed!
        ELSE
            Append To List    @{failed_orders}    ${row}
            Log    Failed!
        END
        
        ${i}    Set Variable    ${i} + 1
        # sleep 10s for next order
        Sleep    10s
    END
    Create A Zip File Of The Receipts
    [Teardown]    RPA.Browser.Close Browser
    
