/**
 * Created by divnaidu on 1/3/2019.
 */

trigger FSL_ServiceTerritoryMemberTrigger on ServiceTerritoryMember (after insert, after update, before insert, before update) {
    if(!FSL_TriggerUtility.isDisabled('ServiceTerritoryMember')){
        FSL_ServiceTerritoryMemberTriggerHandler.handleOperations(Trigger.OperationType, Trigger.old, Trigger.oldMap, Trigger.new, Trigger.newMap);
    }
}