trigger FSL_ServiceTerritoryTrigger on ServiceTerritory (After insert, After update) {
    if(!FSL_TriggerUtility.isDisabled('ServiceTerritory')){
          FSL_ServiceTerritoryTriggerHandler.handleOperations(Trigger.OperationType, Trigger.old, Trigger.oldMap, Trigger.new, Trigger.newMap);
      }
  }
  