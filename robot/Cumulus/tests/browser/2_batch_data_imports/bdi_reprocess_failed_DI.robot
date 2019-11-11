*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/DataImportPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             Setup Variables
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Keywords ***
Setup Variables
    ${org_ns} =           Get Org Namespace Prefix
    Set suite variable    ${org_ns}
    ${date} =             Get Current Date    result_format=%Y-%m-%d
    Set suite variable    ${date}
    ${ns} =               Get NPSP Namespace Prefix
    Set suite variable    ${ns}
    
Create Data Import Record  
    ${account} =      Generate Random String 
    ${gau} =          Generate Random String 
    ${check} =            Generate Random String
    &{gau} =  API Create GAU
    &{data_import} =  API Create DataImport     
    ...        ${ns}Account1_Name__c=${account}
    ...        ${ns}Donation_Amount__c=100
    ...        ${ns}Donation_Date__c=${date}
    ...        ${ns}Donation_Donor__c=Contact1
    ...        ${org_ns}CO2_currency__c=500
    [return]   &{data_import}

    
*** Test Cases ***
Verify Donation Creation Fails on Incorrect Data and Reprocess
    [Documentation]        
    ...                    Create a DI record with Account, CustomObject2 and Donation details but select Donation Donor as Contact.
    ...                    Verify that DI processing fails but account is created. Edit DI and change Donor to Account and reprocess DI record. 
    ...                    DI completes and account matches to previous and Donation and Custom Object records are created 
    [tags]                 W-035913    feature:BDI
    
    #Create DI record and process batch
    &{data_import} =                 Create Data Import Record
    Process Data Import Batch        Errors
    &{data_import_upd} =             Salesforce Get  ${ns}DataImport__c  &{data_import}[Id]
    Log Many       &{data_import_upd}
    Open Data Import Record          &{data_import_upd}[Name]    
    Confirm Value                    Failure Information        Invalid Donation Donor    Y
    Confirm Value                    Donation Import Status     Invalid Donation Donor    Y
    
    # Verify Account Details
    Verify Expected Values                     nonns    Account            &{data_import_upd}[${ns}Account1Imported__c]
    ...    Name=&{data_import}[${ns}Account1_Name__c]
    
    #Update DI record and reprocess batch
    Edit Record
    Click Dropdown                   Donation Donor
    Click Link                       Account1
    Click Modal Button               Save
    Wait Until Modal Is Closed
    Process Data Import Batch        Completed
    &{data_import_upd} =             Salesforce Get  ${ns}DataImport__c  &{data_import}[Id]
    Log Many       &{data_import_upd}
    Open Data Import Record          &{data_import_upd}[Name]    
    Confirm Value                    Account1 Import Status     Matched    Y
    Confirm Value                    Donation Import Status     Created    Y
   
    #Verify Opportunity is created as closed won with given date and amount
    Verify Expected Values                     nonns    Opportunity        &{data_import_upd}[${ns}DonationImported__c]
    ...    Amount=100.0
    ...    CloseDate=${date}
    ...    StageName=Closed Won
    ...    AccountId=&{data_import_upd}[${ns}Account1Imported__c]
        
    #Verify Payment record is created and linked to opportunity with correct details
    Verify Expected Values                     nonns    npe01__OppPayment__c        &{data_import_upd}[${ns}PaymentImported__c]
    ...    npe01__Paid__c=True
    ...    npe01__Payment_Amount__c=100.0
    ...    npe01__Payment_Date__c=${date}
    ...    npe01__Opportunity__c=&{data_import_upd}[${ns}DonationImported__c]
    ...    Payment_Status__c=Paid

    #Verify CustomObject2 record is created and linked to opportunity with correct details
    Verify Expected Values                     nonns       CustomObject2__c      &{data_import_upd}[${org_ns}CustomObject2Imported__c]
    ...    ${org_ns}C2_currency_2__c=500.0
    ...    ${org_ns}Account__c=&{data_import_upd}[${ns}Account1Imported__c]