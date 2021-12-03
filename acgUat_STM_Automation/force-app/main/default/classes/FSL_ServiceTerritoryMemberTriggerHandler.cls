public without sharing class FSL_ServiceTerritoryMemberTriggerHandler {

    public static void handleOperations (System.TriggerOperation operationType, List<ServiceTerritoryMember> oldList, Map<Id, ServiceTerritoryMember> oldMap,
            List<ServiceTerritoryMember> newList, Map<Id, ServiceTerritoryMember> newMap) {
        if (operationType == TriggerOperation.BEFORE_INSERT || operationType == TriggerOperation.BEFORE_UPDATE) {
            FSL_UpdateSRPrimaryTerritory.updateTerritoryMemberAddress(newList);
        }
        else if (operationType == TriggerOperation.AFTER_INSERT) {
            Map<Id,Id> srSTIdMap = new Map<Id,Id>();
            //List<ServiceTerritoryMember> primarySTMList = new List<ServiceTerritoryMember>();
            for(ServiceTerritoryMember stm : newMap.values()) {
                if(stm.TerritoryType == 'P') {
                    srSTIdMap.put(stm.ServiceResourceId,stm.ServiceTerritoryId);
                }
            }
            System.debug('///////srSTIdMap = ' + srSTIdMap);

            if(!srSTIdMap.isEmpty()) {
                FSL_UpdateSRPrimaryTerritory.updateSRPrimaryTerritory(srSTIdMap);
                FSL_UpdateSRPrimaryTerritory.shareServiceResourcewithPublicGroup(srSTIdMap);
            }

            List<ServiceTerritoryMember> primarySTMInserts = new List<ServiceTerritoryMember>();
            for (ServiceTerritoryMember stm : newList){
                if (stm.TerritoryType == 'P'){
                    primarySTMInserts.add(stm);
                }
            }
            if(!primarySTMInserts.isEmpty()){
                FSL_UpdateSRPrimaryTerritory.addRelatedTerritories(primarySTMInserts);
            }
        }
        else if (operationType == TriggerOperation.AFTER_UPDATE) {
            Map<Id,Id> srSTIdMap = new Map<Id,Id>();
            for(ServiceTerritoryMember stmNew : newList) {
                for(ServiceTerritoryMember stmOld : oldList) {
                    if(stmNew.Id == stmOld.Id) {
                        if(stmNew.TerritoryType == 'P' && stmOld.TerritoryType != 'P') {
                            srSTIdMap.put(stmNew.ServiceResourceId, stmNew.ServiceTerritoryId);

                        } else if(stmNew.TerritoryType != 'P' && stmOld.TerritoryType == 'P') {
                            srSTIdMap.put(stmNew.ServiceResourceId, null);
                        }
                    }
                }
            }
            System.debug('///////srSTIdMap = ' + srSTIdMap);
            if(!srSTIdMap.isEmpty()) {
                FSL_UpdateSRPrimaryTerritory.updateSRPrimaryTerritory(srSTIdMap);
            }

            List<ServiceTerritoryMember> primarySTMUpdates = new List<ServiceTerritoryMember>();
            for (ServiceTerritoryMember stm : newList){
                if (stm.TerritoryType == 'P'){
                    primarySTMUpdates.add(stm);
                }
            }
            if(!primarySTMUpdates.isEmpty()){
                FSL_UpdateSRPrimaryTerritory.addRelatedTerritories(primarySTMUpdates);
            }
        }
    }
}