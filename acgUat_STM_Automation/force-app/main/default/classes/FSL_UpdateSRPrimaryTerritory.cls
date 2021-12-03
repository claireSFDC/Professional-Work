/**
 * Created by divnaidu on 1/3/2019.
 */

public class FSL_UpdateSRPrimaryTerritory {

/**********
* @Method Name:updateSRPrimaryTerritory
* @Parameters:(Map<Id,Id>)
* @Description: Accepts the map of ServiceResource Id's and corresponding Primary Service Territory id to populate the Primary_Service_Territory__c field
* @Author: Divyendra Naidu
* **********/

    public static void updateSRPrimaryTerritory(Map<Id, Id> srTerritoryMap) {

        System.debug('///Entering updateSRPrimaryTerritory method');
        List<ServiceResource> srList = new List<ServiceResource>([SELECT Id, Primary_Service_Territory__c, Vehicle__c FROM ServiceResource WHERE Id IN: srTerritoryMap.keySet()]);
        List<ServiceResource> srListToUpdate = new List<ServiceResource>();
        for(ServiceResource sr : srList) {
            sr.Primary_Service_Territory__c = srTerritoryMap.get(sr.Id);
            sr.Vehicle__c =  null;
            srListToUpdate.add(sr);

        }
        try {
            update srListToUpdate;
        }
        catch (Exception ex) {
            System.debug('Catch block error : ' + ex);
        }

    }
    
    public static void addRelatedTerritories(List<ServiceTerritoryMember> newPrimaryTerritories){
        try{
            system.debug('entering addRelatedTerritories: ' + newPrimaryTerritories);
            
            Map<ID, ID> srIdToSTIdMap = new Map<ID, ID>();
            Map<ID, List<ID>> existingSRToSTM = new Map<ID, List<ID>>();
            Map<ID, DateTime> srToStartDateMap = new Map<ID, DateTime>();
            Set<ID> territoryIDs = new Set<ID>();
            
            // get map or resources that had new primary territories inserted
            for(ServiceTerritoryMember stm : newPrimaryTerritories){
                if(stm.TerritoryType == 'P'){
                    system.debug('populating map: '+ stm.ServiceResource + ' / ' + stm.ServiceTerritory);
                    srIdToSTIdMap.put(stm.ServiceResourceId, stm.ServiceTerritoryId);
                    territoryIDs.add(stm.ServiceTerritoryID);
                    srToStartDateMap.put(stm.ServiceResourceId, stm.EffectiveStartDate);
                }
            }
            
            // get all secondary territories for the resources that just had new primary territories inserted
            //List<ServiceTerritoryMember> secondarySTMList = [SELECT id, ServiceResourceID, ServiceTerritoryID, TerritoryType FROM ServiceTerritoryMember WHERE TerritoryType = 'S' AND ServiceResourceID IN :srIdToSTIdMap.keySet()];
            //for(ServiceTerritoryMember stm2 : secondarySTMList){
                //existingSRToSTM.put(stm2.ServiceResourceId, stm2.ServiceTerritoryId);
            //}
            
            // Find all parent territories
            List<ServiceTerritory> stList = [SELECT ParentTerritoryId, ParentTerritory.Auto_Create_STMs__c, Id, Name FROM ServiceTerritory WHERE ID IN :territoryIDs];
            List<FSL_Service_Territory_STM_Rule__c> stmRuleList = [SELECT Primary_Service_Territory_Member_s_Of__c, Of_Service_Territory__c, Id, Name FROM FSL_Service_Territory_STM_Rule__c WHERE Primary_Service_Territory_Member_s_Of__c IN :territoryIDs /*AND Active__c = true*/];
            System.debug('STM RULE LIST::: ' + stmRuleList);
            List<ServiceTerritory> parentTerritoryList = new List<ServiceTerritory>();
            Map<Id,Id> primTrIdOfTrIdMap = new Map<Id,Id>();
            Set<ID> parentIDSet = new Set<ID>();
            for(ServiceTerritory st : stList){
                //Matt - 2/13: adding check on Auto Create STM Field per UF-1313
                if(!parentIDSet.contains(st.ParentTerritoryId) && st.ParentTerritory.Auto_Create_STMs__c){
                    parentIDSet.add(st.ParentTerritoryId);
                }
            }
            /*for(FSL_Service_Territory_STM_Rule__c stmRule : stmRuleList){
                parentIDSet.add(stmRule.Of_Service_Territory__c);
                primTrIdOfTrIdMap.put(stmRule.Primary_Service_Territory_Member_s_Of__c,stmRule.Of_Service_Territory__c);
            }*/
            // Find all children territories
            List<ServiceTerritory> childTerritoryList = [SELECT ParentTerritoryId, Id, Name, IsActive FROM ServiceTerritory WHERE ParentTerritoryId IN :parentIDSet AND IsActive = true];
            Map<ID, ID> childToParentMap = new Map<ID, ID>();
            // Create parent to child map
            for(ServiceTerritory st : childTerritoryList){
                if (String.isNotBlank(st.ParentTerritoryId)) {
                    System.debug('Panda++');
                    childToParentMap.put(st.id, st.ParentTerritoryId);
                }
            }

            List<ServiceTerritoryMember> newSTMs = new List<ServiceTerritoryMember>();
            // Add all territories
            for(ID updatedResourceID : srIdToSTIdMap.keySet()){
                ID newPrimaryTerritoryID = srIdToSTIdMap.get(updatedResourceID);
                ID parentTerritoryID = childToParentMap.get(newPrimaryTerritoryID);
                for(ServiceTerritory secondaryTerritory : childTerritoryList){
                    system.debug('new secondary parent id: ' + secondaryTerritory.ParentTerritoryId);
                    system.debug('primary parent id: ' + parentTerritoryID);
                    system.debug('new primary id: ' + String.valueOf(newPrimaryTerritoryID) + ' vs new secondary id: ' + String.valueOf(secondaryTerritory.id));
                    
                    if(secondaryTerritory.ParentTerritoryId != null &&
                            String.valueOf(secondaryTerritory.id) != String.valueOf(newPrimaryTerritoryID)  &&
                            String.valueOf(secondaryTerritory.ParentTerritoryId) == String.valueOf(parentTerritoryID)){
                        // iterate over existing secondary territories to make sure we don't already have a matching reconrd
                            try{
                                system.debug('adding new Secondary STM: ' + secondaryTerritory);
                                // create STM copy
                                ServiceTerritoryMember secondarySTM = new ServiceTerritoryMember();
                                secondarySTM.ServiceResourceID = updatedResourceID;
                                //secondarySTM.EffectiveStartDate = System.now();
                                secondarySTM.EffectiveStartDate = srToStartDateMap.get(updatedResourceID);
                                secondarySTM.EffectiveEndDate = null;
                                secondarySTM.ServiceTerritoryID = secondaryTerritory.Id;
                                secondarySTM.TerritoryType = 'S';
                                newSTMs.add(secondarySTM);
                                //insert secondarySTM;
                            }catch(Exception e){
                                system.debug('exception inserting secondary territory ' + e);
                            }
                        
                            
                    }
                }
            }
            

            //insert parent stm
            for(ServiceTerritoryMember stm : newPrimaryTerritories){
                try{
                    ServiceTerritoryMember secondarySTM = new ServiceTerritoryMember(); 
                    secondarySTM.ServiceResourceID = stm.ServiceResourceID;
                    //secondarySTM.EffectiveStartDate = System.now();
                    secondarySTM.EffectiveStartDate = stm.EffectiveStartDate;
                    secondarySTM.EffectiveEndDate = null;
                    secondarySTM.ServiceTerritoryID = childToParentMap.get(stm.ServiceTerritoryId);
                    secondarySTM.TerritoryType = 'S';   
                    newSTMs.add(secondarySTM);
                    //insert secondarySTM;
                }
                catch(Exception e){
                    system.debug('exception inserting secondary parent territory ' + e);
                }
            }
            //If logic is to create New STM's based on Rules defined in STM rule object. 
            //for additional secondary membership of outside the actual highrarchy
            if(!stmRuleList.isEmpty()) {
                createSTMBasedOnSTMRules(stmRuleList,newSTMs);
            }            
            list<Database.SaveResult> srs = Database.insert(newSTMs, false);
            system.debug('**SRS**:'+srs);
        }
        catch(Exception e){
            system.debug('Exception caught! - ' + e);
        }
        
    }
    /*****
     * *@Method Name: createSTMBasedOnSTMRules
     * *@Params : List<FSL_Service_Territory_STM_Rule__c> stmRuleList,List<ServiceTerritoryMember> newSTMs
     * *@Description : Method is to create additional secondary STM's of outside actual highrarchy 
     * *for given territory in STM rule object
     * ****/
    public static List<ServiceTerritoryMember> createSTMBasedOnSTMRules(List<FSL_Service_Territory_STM_Rule__c> stmRuleList,List<ServiceTerritoryMember> newSTMs) {
        Map<Id,List<Id>> primTrIdOfTrIdMap = new Map<Id,List<Id>>();
        Set<Id> primaryStmTerIdSet = new Set<Id>();
        Set<Id> rulesServTerIdSet = new Set<Id>();
        if(newSTMs == null) {
            newSTMs = new List<ServiceTerritoryMember>();
        }
        for(FSL_Service_Territory_STM_Rule__c stmRule : stmRuleList){
            primaryStmTerIdSet.add(stmRule.Primary_Service_Territory_Member_s_Of__c);
            rulesServTerIdSet.add(stmRule.Of_Service_Territory__c);
            if(!primTrIdOfTrIdMap.containsKey(stmRule.Primary_Service_Territory_Member_s_Of__c)){
                List<id> ruleTerrIdListNew = new List<Id>();
                ruleTerrIdListNew.add(stmRule.Of_Service_Territory__c);
                primTrIdOfTrIdMap.put(stmRule.Primary_Service_Territory_Member_s_Of__c,ruleTerrIdListNew);
            }else{
                primTrIdOfTrIdMap.get(stmRule.Primary_Service_Territory_Member_s_Of__c).add(stmRule.Of_Service_Territory__c);
            }
            
        }
        //Added 8/27/2021 Claire Crabtree to check if secondary STM exists already
        list<serviceterritorymember> PrimarySTMs = [SELECT serviceTerritoryId, Id,serviceResourceId FROM ServiceTerritoryMember WHERE serviceTerritoryId IN :primaryStmTerIdSet AND TerritoryType = 'P' and serviceresource.isactive = true];
        list<String> primarySTMresourceIds = new list<String>();
        for(serviceterritorymember ps : PrimarySTMs){
            primarySTMresourceIds.add(ps.serviceresourceId);
        }
        list<serviceterritorymember> existingSecondarySTMs = [select id, serviceresourceid, serviceterritoryid from serviceterritorymember where serviceresourceid IN :primarySTMresourceIds and territorytype = 'S' and serviceterritoryid IN :rulesServTerIdSet and serviceresource.isactive = true and serviceterritory.isactive = true];
        list<String> resourceId_terrId = new list<String>();
        for(serviceterritorymember sts : existingSecondarySTMs){
            resourceId_terrId.add(sts.serviceresourceid +'_' + sts.serviceterritoryid);
        }
        //end of new code
        if(!primaryStmTerIdSet.isEmpty()) {
            for(ServiceTerritoryMember stm : PrimarySTMs) {
                //for primTrIdOfTrIdMap loop added 12/2/2021 Claire Crabtree
                for(ID ruleT : primTrIdOfTrIdMap.get(stm.serviceTerritoryId)){
                    //IF statement added 8/27/2021 Claire Crabtree
                    if(!resourceId_terrId.contains(stm.serviceresourceid + '_' + ruleT)){
                        ServiceTerritoryMember newStm = new ServiceTerritoryMember();
                        newStm.ServiceResourceID = stm.ServiceResourceId;
                        newStm.ServiceTerritoryId = ruleT;
                        newStm.TerritoryType = 'S';
                        newStm.EffectiveStartDate = System.now();
                        newStm.EffectiveEndDate = null;
                        newSTMs.add(newStm);
                    }
                }

            }
        }
        return newSTMs;
    }
/**********
* @Method shareServiceResourcewithPublicGroup
* @Parameters:(Map<Id,Id>)
* @Description: Accepts the map of ServiceResource Id's and corresponding Primary Service Territory id to share service resource with corresponding public group
* @Author: Balaram Naidu
* ***********/
    public static void shareServiceResourcewithPublicGroup(Map<Id, Id> srTerritoryMap) {
        Set<String> territoryNamesSet = new Set<String>();
        List<ServiceResourceshare> resourceShareList = new List<ServiceResourceshare>();
        //Map<Id,ServiceResource> serviceResourcesMap = new Map<Id,ServiceResource>([SELECT Id, Primary_Service_Territory__c FROM ServiceResource WHERE Id IN: srTerritoryMap.keySet()]);
        Map<Id,ServiceTerritory> serviceTerritoryMap = new Map<Id,ServiceTerritory>([SELECT Id, Name FROM ServiceTerritory WHERE Id IN: srTerritoryMap.values()]);
        for(ServiceTerritory territory : serviceTerritoryMap.values()) {
            territoryNamesSet.add(territory.Name);
        }
        if(!territoryNamesSet.isEmpty()) {
            Map<String,Group> publicGroupMap = new Map<String,Group>();
            List<Group> publicGroupList = [select id,relatedid,name from Group where Name IN : territoryNamesSet];
            for(Group pGroup : publicGroupList ) {
                publicGroupMap.put(pGroup.name,pGroup);
            }
            
            for(Id resourceId : srTerritoryMap.keySet()) {
                if(publicGroupMap.get(serviceTerritoryMap.get(srTerritoryMap.get(resourceId)).Name) != null) {
                    ServiceResourceshare srShare = new ServiceResourceshare();
                    srShare.ParentID = resourceId;
                    srShare.UserOrGroupId = publicGroupMap.get(serviceTerritoryMap.get(srTerritoryMap.get(resourceId)).Name).Id;
                    srShare.AccessLevel = 'Edit';
                    resourceShareList.add(srShare);
                }
            }
            if(!resourceShareList.isEmpty()) {
                insert resourceShareList;
            }
        }
    }
    
    /**********
    * @Method updateTerritoryMemberAddress
    * @Parameters:(List<ServiceTerritoryMember>)
    * @Description: Updates Territory member Address from Primary territory
    * @Author: Balaram Naidu
    * ***********/
    public static void updateTerritoryMemberAddress(List<ServiceTerritoryMember> newSTMList) {
        Set<Id> territoryIdSet = new Set<Id>();
        for(ServiceTerritoryMember stm : newSTMList) {
            if(stm.TerritoryType =='P' && stm.Street == null && stm.city == null && stm.state == null ) {
                territoryIdSet.add(stm.ServiceTerritoryId);                
            }
        }
        if(!territoryIdSet.isEmpty()) {
            Map<Id,ServiceTerritory> territoryMap = new Map<Id,ServiceTerritory>([Select Id,Name, City, country, postalcode, State,Street from ServiceTerritory where id IN : territoryIdSet]);
            for(ServiceTerritoryMember stm : newSTMList) {
                if(territoryIdSet.contains(stm.ServiceTerritoryId) && territoryMap.get(stm.ServiceTerritoryId) != null) {
                    stm.city = territoryMap.get(stm.ServiceTerritoryId).city;
                    stm.country = territoryMap.get(stm.ServiceTerritoryId).country;
                    stm.postalcode = territoryMap.get(stm.ServiceTerritoryId).postalcode;
                    stm.street = territoryMap.get(stm.ServiceTerritoryId).street;
                }
            }
        }
    }
    
    /*****
     * *@Method Name: createSTMBasedOnSTMRules
     * *@Params : List<FSL_Service_Territory_STM_Rule__c> stmRuleList,List<ServiceTerritoryMember> newSTMs
     * *@Description : Method is to create additional secondary STM's of outside actual highrarchy 
     * *for given territory in STM rule object
     * ****/
    public static void removeSTMBasedOnSTMRules(List<FSL_Service_Territory_STM_Rule__c> stmRuleList) {
        Map<Id,Id> primTrIdOfTrIdMap = new Map<Id,Id>();
        Set<Id> primaryStmTerIdSet = new Set<Id>();
        Set<Id> primResourceIdSet = new Set<Id>();
        for(FSL_Service_Territory_STM_Rule__c stmRule : stmRuleList){
            primaryStmTerIdSet.add(stmRule.Primary_Service_Territory_Member_s_Of__c);
            primTrIdOfTrIdMap.put(stmRule.Primary_Service_Territory_Member_s_Of__c,stmRule.Of_Service_Territory__c);
        }
        if(!primaryStmTerIdSet.isEmpty()) {
            for(ServiceTerritoryMember stm : [SELECT serviceTerritoryId, Id,serviceResourceId FROM ServiceTerritoryMember WHERE serviceTerritoryId IN :primaryStmTerIdSet AND TerritoryType = 'P']) {
                primResourceIdSet.add(stm.serviceResourceId);
            }
            System.debug('primResourceIdSet===>>'+primResourceIdSet);
            System.debug('primTrIdOfTrIdMap.values()===>>'+primTrIdOfTrIdMap.values());
            List<ServiceTerritoryMember> stmList = [Select Id from ServiceTerritoryMember where serviceResourceId IN : primResourceIdSet AND serviceTerritoryId IN :primTrIdOfTrIdMap.values() AND  TerritoryType = 'S'];
            System.debug('stmList====>>'+stmList);
            if(!primResourceIdSet.isEmpty()) {
                Delete [Select Id from ServiceTerritoryMember where serviceResourceId IN : primResourceIdSet AND serviceTerritoryId IN :primTrIdOfTrIdMap.values() AND  TerritoryType = 'S' AND FSL_part_time__c =: false];
            }
        }
        //return newSTMs;
    }
}