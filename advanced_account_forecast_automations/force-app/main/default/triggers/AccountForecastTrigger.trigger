trigger AccountForecastTrigger on AdvAccountForecastFact (after update) {
    // Totals Forecast Set ID, used to validate which Set Partner records to update and conditional statements
     String totalsForecastSetId = '0niDn000000PBbXIAW';
     
     // variable to store the Target Partner Set record ID of the Totals Forecast Set
    String targetPartnerSetId;

    // SOQL Query to get the active Set Partner record ID that is of the Totals Forecast Set
    AdvAcctForecastSetPartner setPartnerRecordQuery = [
        SELECT Id 
        FROM AdvAcctForecastSetPartner 
        WHERE AdvAccountForecastSetId = :totalsForecastSetId AND Status = 'Active'
        LIMIT 1
    ];
    
    // Coditional to assign result of Query to the String variable
    if (setPartnerRecordQuery != null) {
        targetPartnerSetId = setPartnerRecordQuery.Id;
    } else {
        // If no targetPartnerSetID is found than exit the entire Trigger
        return;
    }
    
    // Get the first (and only) updated Fact record
    AdvAccountForecastFact changedRecord = Trigger.new[0]; 
    
    // Get the old Fact record to access the previous value
    AdvAccountForecastFact oldRecord = Trigger.oldMap.get(changedRecord.Id);
    
    // Define ID variables from changed Fact record for SOQL query
    Id changedProductId = changedRecord.ProductId;
    Id changedPeriodId = changedRecord.PeriodId;
    
    // If the forecast Fact record that was changed is the TOTALS forecast than don't execute code block
    if (changedRecord.AdvAcctForecastSetPartnerId != targetPartnerSetId) {

    // Retrieve the Fact records associated with the target Partner Set record
    List<AdvAccountForecastFact> targetRecords = [
        SELECT Id, Name, PeriodID, Global_MGR_Adjustment_QTY__c, ProductId
        FROM AdvAccountForecastFact
        WHERE AdvAcctForecastSetPartnerId = :targetPartnerSetId AND ProductId = :changedProductId AND PeriodId = :changedPeriodId
        
    ];    

    // Update the associated target Fact record(s) with the new value
    // If statement checks if this Trigger was invoked by a previous Trigger invocation (prevents recursion)
    if (changedRecord != null && AccountForecastTriggerHandler.recursionLevel == 0) {               
        // Increment the recursion level to prevent recursion
        AccountForecastTriggerHandler.recursionLevel++;
        
        // loop through Fact records pulled from SOQL query
        for (AdvAccountForecastFact targetRecord : targetRecords) {                   
                // Match the Fact record to update based on Period ID and Field ID and Product ID
                if (targetRecord.PeriodID == changedRecord.PeriodID && targetRecord.ProductID == changedRecord.ProductID) {
                    // Declare difference variable to store difference between old value and new value
                    Decimal difference = 0;
                    
                    // Check if old value isn't null, if not null, subtract old value from new value for difference
                    if (oldRecord.Global_MGR_Adjustment_QTY__c != null) {
                       difference = changedRecord.Global_MGR_Adjustment_QTY__c - oldRecord.Global_MGR_Adjustment_QTY__c;
                    } else { //else old value is null
                        difference = changedRecord.Global_MGR_Adjustment_QTY__c;
                    }
                    
                    // Check if target cell isn't null, if not null, add values and update
                    if (targetRecord.Global_MGR_Adjustment_QTY__c != null) {
                        // Update the target cell with the new value from the changed record
                        targetRecord.Global_MGR_Adjustment_QTY__c = difference + targetRecord.Global_MGR_Adjustment_QTY__c;
                    } else { //target cell is null, add updated value to target cell
                        targetRecord.Global_MGR_Adjustment_QTY__c = difference;
                    }                    
            }
        }

        // Save the updated target record(s)
        update targetRecords;
        
        // Decrement the recursion level
        AccountForecastTriggerHandler.recursionLevel--;
        } // Close bracket for if statement checking
    }
}