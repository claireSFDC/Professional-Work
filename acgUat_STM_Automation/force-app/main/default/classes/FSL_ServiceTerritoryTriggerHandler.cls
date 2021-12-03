public class FSL_ServiceTerritoryTriggerHandler {
    public static void handleOperations(System.TriggerOperation operationType, List<ServiceTerritory> oldList, Map<Id, ServiceTerritory> oldMap, List<ServiceTerritory> newList, Map<Id, ServiceTerritory> newMap) {        
    	if (operationType == TriggerOperation.AFTER_INSERT) {
            Set<Id> parentTerritorySet = new Set<Id>();
            for(ServiceTerritory newTerritory : newList) {
                if(newTerritory.ParentTerritoryId != null && newTerritory.Auto_Create_STMs__c) {
                    parentTerritorySet.add(newTerritory.ParentTerritoryId);
                }
            }
            if(!parentTerritorySet.isEmpty()) {
                System.debug('parentTerritorySet===>'+parentTerritorySet);
                createNewSTMs(newList,parentTerritorySet);
            }
        } else if (operationType == TriggerOperation.AFTER_UPDATE) {
            Set<Id> parentTerritorySet = new Set<Id>();
            Set<Id> oldParentTerritorySet = new Set<Id>();
            Set<Id> currentTerritorySet = new Set<Id>();
            Map<Id, Id> facilityId_oldParentId = new Map<Id, Id>();
            for(ServiceTerritory newTerritory : newList) {
                if(newTerritory.Auto_Create_STMs__c && ((newTerritory.ParentTerritoryId != oldMap.get(newTerritory.Id).ParentTerritoryId) 
                                                        || (newTerritory.Auto_Create_STMs__c != oldMap.get(newTerritory.Id).Auto_Create_STMs__c))) {
                   if(newTerritory.ParentTerritoryId  == null && oldMap.get(newTerritory.Id).ParentTerritoryId != null) {
                       currentTerritorySet.add(newTerritory.Id);
                       oldParentTerritorySet.add(oldMap.get(newTerritory.Id).ParentTerritoryId);
                       facilityId_oldParentId.put(newTerritory.Id, oldMap.get(newTerritory.Id).ParentTerritoryId);
                   }else if(oldMap.get(newTerritory.Id).ParentTerritoryId != null && newTerritory.ParentTerritoryId != oldMap.get(newTerritory.Id).ParentTerritoryId) {
                      oldParentTerritorySet.add(oldMap.get(newTerritory.Id).ParentTerritoryId);
                      facilityId_oldParentId.put(newTerritory.Id, oldMap.get(newTerritory.Id).ParentTerritoryId);
                       parentTerritorySet.add(newTerritory.ParentTerritoryId);
                   }else if(oldMap.get(newTerritory.Id).ParentTerritoryId == null && newTerritory.ParentTerritoryId != oldMap.get(newTerritory.Id).ParentTerritoryId) {
                       parentTerritorySet.add(newTerritory.ParentTerritoryId);
                   }else if(newTerritory.ParentTerritoryId != null) {
                      parentTerritorySet.add(newTerritory.ParentTerritoryId);
                   }
                   
                }
            }
            if(!oldParentTerritorySet.isEmpty()) {
                deleteOldSecondarySTMs(oldParentTerritorySet,currentTerritorySet,facilityId_oldParentId);
            }
            if(!parentTerritorySet.isEmpty()){
                createNewSTMs(newList,parentTerritorySet);
            }
        }
    }
    
    /*****
     *@Method Name :  insertNewSTMs
     *@Parameters : List<ServiceTerritory> newList, Set<Id> parentTerritorySet
     *@Description: Method is to Delete old secondary STM's while updating parent territory of territory.
     Updated 11/4/2021 by Claire Crabtree to have better, more granular, and more bulkified logic
     *******/
    private static void deleteOldSecondarySTMs(Set<Id> oldParentTerritorySet,Set<Id> currentTerritorySet, Map<id, id> facilityId_oldParentId) {

        Map<Id, list<id>> facilityId_oldParentFamilyIds = new Map<Id, list<id>>();
        Map<Id, List<Id>> ParentId_allChildrenAndSelfIds = new Map<id, List<Id>>();
        List<serviceTerritoryMember> primarySTMs = new List<serviceterritoryMember>();
        List<Id> servresIdofPrimary = new list<id>();
        List<ServiceterritoryMember> secondarySTMs = new List<serviceterritoryMember>();
        List<ServiceterritoryMember> STMStoDelete = new List<serviceterritoryMember>();
        map<id, id> resourceid_primaryterritoryId = new Map<Id, Id>();

        List<serviceterritory> childterritories = [Select Id,ParentTerritoryId,Name FROM ServiceTerritory WHERE (ParentTerritoryId IN :oldParentTerritorySet)];
        Set<serviceTerritory> childterritoriesSet = new set<serviceterritory>(childterritories);
        childterritories.clear();
        childterritories.addAll(childterritoriesSet);
        Set<Id> childterritoriesIds = new set<Id>();
        for(serviceterritory c : childterritories){
            childterritoriesIds.add(c.Id);
        }

        //Created ParentId_allChildrenAndSelfIds where key set is all parent territory ids, and their value is the list of themselves and their children
        if(childterritories.size() >0){
            for(serviceTerritory stt : childterritories){
                if(ParentId_allChildrenAndSelfIds.containsKey(stt.ParentTerritoryId)){
                    ParentId_allChildrenAndSelfIds.get(stt.ParentTerritoryId).add(stt.Id);
                }else{
                    list<Id> newIdList = new list<id>{stt.Id, stt.ParentTerritoryId};
                    ParentId_allChildrenAndSelfIds.put(stt.ParentTerritoryId, newIdList);
                }
            }
        }else{
            for(id pid : oldParentTerritorySet){
                list<Id> newparentIdList = new list<id>{pid, pid};
                ParentId_allChildrenAndSelfIds.put(pid,newparentIdList);
            }
        }

        childterritoriesIds.addAll(oldParentTerritorySet);

        //create facilityId_oldParentFamilyIds map where key set is the list of updated service territories, and their value is the list of service territories that are children of the prior parent territory value
        for(id currentTerritory : currentTerritorySet){
            facilityId_oldParentFamilyIds.put(currentTerritory, ParentId_allChildrenAndSelfIds.get(facilityId_oldParentId.get(currentTerritory)));
        }
        System.debug('facilityId_oldParentFamilyIds:::: ' + facilityId_oldParentFamilyIds);

        //create a list of all secondary service territory members where serviceresource.primary = current territory OR oldparent/children and serviceterritory = current territory OR oldparent/children
        primarySTMs = [select id,serviceresourceid, serviceterritoryid from serviceterritorymember where territorytype = 'P' and (serviceterritoryid IN :currentTerritorySet OR serviceterritoryId IN :childterritoriesIds)];
        for(serviceterritorymember ttt : primarySTMs){
            servresIdofPrimary.add(ttt.serviceresourceId);
            resourceid_primaryterritoryId.put(ttt.serviceresourceid, ttt.serviceterritoryId);
        }
        secondarySTMs = [select id,serviceresourceid, serviceterritoryid FROM serviceterritorymember WHERE serviceresourceid in :servresIdofPrimary and territorytype = 'S' and (serviceterritoryid IN :currentTerritorySet OR serviceterritoryId IN :childterritoriesIds)];

        //loop through secondary STMS and create a list of STMS to delete
        for(serviceterritoryMember mmm : secondarySTMs){
            System.debug('MMM : ' + mmm.Id);
            Id primaryTerritoryofMMM = resourceid_primaryterritoryId.get(mmm.serviceresourceId);
            System.debug('primaryTerritoryofMMM :::' + primaryTerritoryofMMM);
            //If stm is primary to updated facility and secondary is former family member OR if primary is a former family member and stm territory is updated facility
            if((facilityId_oldParentFamilyIds.containsKey(primaryTerritoryofMMM) && facilityId_oldParentFamilyIds.get(primaryTerritoryofMMM).contains(mmm.serviceTerritoryId)) || (facilityId_oldParentFamilyIds.containsKey(mmm.serviceTerritoryId) && facilityId_oldParentFamilyIds.get(mmm.serviceTerritoryId).contains(primaryTerritoryofMMM))){
                STMStoDelete.add(mmm);
            }
        }
        System.debug('STMS TO DELETE ' + STMStoDelete);
        delete STMStoDelete;

        /* REMOVED BY CLAIRE CRABTREE 11/4/2021 because it was super wrong
        system.debug('current territory id set: ' + currentTerritorySet);
        Set<Id> resourceIdSet = new Set<Id>();
        Set<Id> allChildTerritoryIds = new Set<Id>();
        for(ServiceTerritory childTerritory : [Select Id,ParentTerritoryId,Name FROM ServiceTerritory WHERE ParentTerritoryId IN :oldParentTerritorySet]) {
            allChildTerritoryIds.add(childTerritory.Id);
         }
        if(!allChildTerritoryIds.isEmpty()) {
            allChildTerritoryIds.addAll(oldParentTerritorySet);
            if(!currentTerritorySet.isEmpty()) {
                allChildTerritoryIds.addAll(currentTerritorySet);
            }
            system.debug(allChildTerritoryIds);
            for(ServiceTerritoryMember stm : [Select Id, ServiceTerritory.parentTerritoryId,ServiceResourceID from ServiceTerritoryMember where ServiceTerritoryID IN :allChildTerritories  AND TerritoryType = 'S' ]) {
            	resourceIdSet.add(stm.ServiceResourceID);
            }
            system.debug(resourceIdSet);
        }
        List<ServiceTerritoryMember> stmList = [Select Id from ServiceTerritoryMember where serviceResourceId In : resourceIdSet AND ServiceTerritoryId IN : currentTerritorySet AND TerritoryType = 'S'];
        System.debug('=stmList===>>>'+stmList);
        
        Delete stmList;
        */
        
    }
    
    /*****
     *@Method Name :  insertNewSTMs
     *@Parameters : List<ServiceTerritory> newList, Set<Id> parentTerritorySet
     *@Description: Method is to insert new STM's while inserting territory with parent 
	 *				or updating parent territory of territory. 
     *******/
    private static void createNewSTMs(List<ServiceTerritory> newList, Set<Id> parentTerritorySet) {
        List<ServiceTerritoryMember> finalSTMList = new List<ServiceTerritoryMember>();
        Map<Id,List<Id>> parentAndItsChildMap = new Map<Id,List<Id>>();
        Map<Id, List<Id>> facility_AllSiblingTerritories = new map<id, list<Id>>();
        Set<Id> allChildTerritories = new Set<Id>();
        list<serviceTerritoryMember> primarySTMs = new list<serviceTerritoryMember>();
        list<serviceTerritoryMember> existingSecondarySTMs = new list<serviceTerritoryMember>();
        list<String> stm_ResourceTerritory_Concat = new List<String>();
        dateTime nowtime = System.now();
        List<ServiceTerritory> childServTerrs = [Select Id,ParentTerritoryId,Name FROM ServiceTerritory WHERE (ParentTerritoryId IN :parentTerritorySet) AND Auto_Create_STMs__c = true AND IsActive = true];
        //Map<Id,List<ServiceTerritoryMember>> grandTerritoryAndMemberMap = new Map<Id,List<ServiceTerritoryMember>>();

        //create map of parent territory to all children, and a map of facility territory to parent.
        for(ServiceTerritory childTerritory : childServTerrs) {
            if(parentAndItsChildMap.get(childTerritory.ParentTerritoryId) != null) {
               parentAndItsChildMap.get(childTerritory.ParentTerritoryId).add(childTerritory.Id);
            }else {
               parentAndItsChildMap.put(childTerritory.ParentTerritoryId,new List<Id>{childTerritory.Id});
            }
            allChildTerritories.add(childTerritory.Id);
        }
        //create a map of facility territory to all required territories (parent and siblings)
        for(ServiceTerritory childTerr : childServTerrs){
            if(!facility_AllSiblingTerritories.containsKey(childTerr.Id)){
                list<id> listofChildIds = new list<id>();
                for(id childterrloopId : parentAndItsChildMap.get(childTerr.ParentTerritoryId)){
                    if(childterrloopId != childTerr.Id){
                        listofChildIds.add(childterrloopId);
                    }
                }
                listofChildIds.add(childTerr.parentTerritoryId);
                facility_AllSiblingTerritories.put(childTerr.Id, listofChildIds);

            }
        }

        if(!parentAndItsChildMap.isEmpty()) {
            allChildTerritories.addAll(parentTerritorySet); //Adding parent territories Here Hence no need of querying
            System.debug('allChildTerritories===>'+allChildTerritories);
            primarySTMs = [Select Id, ServiceTerritory.parentTerritoryId,ServiceResourceID from ServiceTerritoryMember where ServiceTerritoryID IN :allChildTerritories  AND TerritoryType = 'P' and serviceresource.isactive = true];
            List<string> serviceResIdsofPrimarySTMS = new list<String>();
            for(serviceTerritoryMember pstm : primarySTMs){
                serviceResIdsofPrimarySTMS.add(pstm.serviceResourceId);
            }
            existingSecondarySTMs = [Select Id, ServiceTerritoryid, ServiceTerritory.parentTerritoryId,ServiceResourceID FROM serviceTerritoryMember WHERE serviceResourceId IN :serviceResIdsofPrimarySTMS and TerritoryType = 'S' and (EffectiveEndDate = null OR (EffectiveEndDate < :nowtime ))];
            for(ServiceTerritoryMember exs : existingSecondarySTMs){
                stm_ResourceTerritory_Concat.add(String.valueOf(exs.serviceResourceId) + String.valueOf(exs.ServiceTerritoryID));
            }

            for(ServiceTerritoryMember primary : primarySTMs){
                for(id reqSTId : facility_AllSiblingTerritories.get(primary.serviceterritoryId)){

                    if(!stm_ResourceTerritory_Concat.contains(String.valueOf(primary.ServiceResourceId)+ String.valueOf(reqSTId))){
                        System.debug('STM UNIQUE::: servresid: ' + primary.serviceresourceId + ', servterrID: ' + reqSTId + ' /// NOT FOUND');

                        ServiceTerritoryMember newStm = new ServiceTerritoryMember();
                            newStm.ServiceResourceID = primary.ServiceResourceId;
                            newStm.ServiceTerritoryId = reqSTId;
                            newStm.TerritoryType = 'S';
                            newStm.EffectiveStartDate = System.now();
                            newStm.EffectiveEndDate = null;
                            finalSTMList.add(newStm);
                    }
                }
            }

                /*blocked out by Claire 11/3/2021 because this is super wrong
                //The below If logic for adding child's Primary STM to the map

                if(stm.ServiceTerritory.parentTerritoryId != null) {
                    if(grandTerritoryAndMemberMap.get(stm.ServiceTerritory.parentTerritoryId) != null) {
                         grandTerritoryAndMemberMap.get(stm.ServiceTerritory.parentTerritoryId).add(stm);
                    }else {
                         grandTerritoryAndMemberMap.put(stm.ServiceTerritory.parentTerritoryId,new List<ServiceTerritoryMember>{stm});
                    }
                }
                //The below If logic for adding parent's Primary STM to the map
                if(stm.ServiceTerritoryId != null && parentTerritorySet.contains(stm.ServiceTerritoryId)) {
                    if(grandTerritoryAndMemberMap.get(stm.ServiceTerritoryId) != null) {
                         grandTerritoryAndMemberMap.get(stm.ServiceTerritoryId).add(stm);
                    }else {
                         grandTerritoryAndMemberMap.put(stm.ServiceTerritoryId,new List<ServiceTerritoryMember>{stm});
                    }
                }
                */
                
        }
        

          /*blocked out by Claire 11/3/2021 because this is super wrong
            for(ServiceTerritory newTerritory : newList) {
                if(newTerritory.ParentTerritoryId != null && newTerritory.Auto_Create_STMs__c) {
                    for(ServiceTerritoryMember primStm : grandTerritoryAndMemberMap.get(newTerritory.ParentTerritoryId)) {
                        if(primStm.ServiceTerritoryId != newTerritory.Id) {
                            ServiceTerritoryMember newStm = new ServiceTerritoryMember();
                            newStm.ServiceResourceID = primStm.ServiceResourceId;
                            newStm.ServiceTerritoryId = newTerritory.Id;
                            newStm.TerritoryType = 'S';
                            newStm.EffectiveStartDate = System.now();
                            newStm.EffectiveEndDate = null;
                            finalSTMList.add(newStm);
                        }
                     
                    }
                } 
            } */
        System.debug('finalSTMList====>>'+finalSTMList);
        if(!finalSTMList.isEmpty()) {
            Database.insert(finalSTMList, true);
        }
    }
}