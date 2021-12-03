trigger FSL_ServiceTerritoryStmRuleTrigger on FSL_Service_Territory_STM_Rule__c (before insert,before update, after insert, after update, after delete) {
    if(!FSL_TriggerUtility.isDisabled('ServiceTerritoryStmRule')){
        FSL_STSTMRuleTriggerHandler.handleOperations(Trigger.OperationType, Trigger.old, Trigger.oldMap, Trigger.new, Trigger.newMap);
    }
}