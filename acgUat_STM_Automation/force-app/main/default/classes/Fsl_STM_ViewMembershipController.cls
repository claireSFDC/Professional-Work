public with sharing class Fsl_STM_ViewMembershipController {
    
    @AuraEnabled(cacheable = true)
    public static list<stmwrapper> getRequiredTerritories(String myRecordId, String objectType){
        try {
            System.debug(objectType + ' is my objecttype');
            //
            //FOR FUTURE DEPLOYMENT TO ROADSIDE: String usertype = UserInfo.getUserType();

            //instantiate variables
            list<serviceresource> serviceResourcesList = new list<serviceresource>();
            List<serviceterritoryMember> existingSTMs = new List<serviceterritoryMember>();
            List<stmWrapper> membershipList = new list<stmWrapper>();
            
            List<String> primaryServTerrIds = new List<String>();
            Map<String, list<String>> resource_territoriesIdMap = new Map<String, list<String>>();
            Map<string, string> resourceId_PrimaryTerrId = new Map<String, String>();
            Map<String, list<String>> territoryId_familyTerritoriesIds = new Map<String, list<String>>();
            List<serviceterritoryMember> primarySTMList = new list<serviceterritorymember>();
            List<serviceterritory> allserviceterritories = new List<serviceterritory>();
            Map<string, List<String>> terrId_ruleterritoriesIds = new Map<String, List<String>>();
            List<operatinghours> opHoursWithTimeslots = new List<operatingHours>();

            if(objectType == 'ServiceResource'){
                serviceResourcesList = [select id, name from serviceresource WHERE id = :myRecordId];
            }else if(objectType == 'ServiceTerritory'){
                serviceResourcesList = [Select id, name from serviceresource WHERE id in (select serviceresourceid from serviceterritorymember where territorytype = 'p' and serviceterritoryid = :myRecordId) and isactive = true];
            }
            if(serviceResourcesList.size() >0){
                //create map of key=service resource id, value = list of strings to hold all required service territory memberships
                for(serviceresource srr : serviceResourcesList){
                    resource_territoriesIdMap.put(srr.Id, new List<String>());
                }
                Map<Id, serviceresource> allserviceresourceIdMap = new Map<id, serviceresource>(serviceResourcesList); 

                //get resources' primary territories
                primarySTMList = [select id, serviceterritoryid, serviceterritory.parentterritoryid, serviceresourceid, serviceresource.name, territorytype from serviceterritorymember where serviceresourceid IN :serviceResourcesList AND territorytype = 'p'];
                Set<String> primaryServTerrIdsSet = new Set<String>();
                for(serviceterritorymember stm : primarySTMList){
                    primaryServTerrIdsSet.add(stm.serviceterritoryid);
                    resourceId_PrimaryTerrId.put(String.valueOf(stm.serviceresourceid), String.valueOf(stm.serviceterritoryid));
                }
                primaryServTerrIds.clear();
                primaryServTerrIds.addAll(primaryServTerrIdsSet);

                //create mappings of service territories
                allserviceterritories = getAllRelatedServiceTerritories(primarySTMList);
                territoryId_familyTerritoriesIds = mapFamilyTerritories(allserviceterritories);
        
                //Get all territories required by rules on the primary territory
                terrId_ruleterritoriesIds = getRuleTerritoriesMap(primaryServTerrIds);

                //Combine lists, so territoryID_familyTerritoriesIds holds key = primary territory, value set = ALL required secondaries
                if(!terrId_ruleterritoriesIds.isEmpty()){
                    for(String terrId : primaryServTerrIds){
                        if(terrId_ruleterritoriesIds.get(terrId).size()>0){
                            Set<String> allServTerrIds = new Set<String>(territoryId_familyTerritoriesIds.get(terrId));
                            allServTerrIds.addAll(terrId_ruleterritoriesIds.get(terrId));
                            List<string> allServTerrIdsList = new List<String>(allServTerrIds);
                            territoryId_familyTerritoriesIds.remove(terrId);
                            territoryId_familyTerritoriesIds.put(terrId,allServTerrIdsList);
                        }
                    }
                }
                allserviceterritories = getNamesforAllTerritories(territoryId_familyTerritoriesIds);
                Map<id, serviceterritory> allserviceterritoryIdMap = new Map<id, serviceTerritory>(allserviceterritories);

                //complete map of service resource to ALL required service territories
                for(serviceresource srd : serviceResourcesList){
                    resource_territoriesIdMap.get(srd.Id).addAll(territoryId_familyTerritoriesIds.get(resourceId_PrimaryTerrId.get(srd.Id)));
                }

                //get all existing STMS and list/map of related operatinghours
                existingSTMs = [select id, MemberNumber, serviceresourceid, serviceresource.name, serviceterritoryid, serviceterritory.name, territorytype, operatinghoursid, operatinghours.name FROM serviceterritorymember WHERE serviceresourceid IN :serviceResourcesList AND (effectiveenddate = null OR effectiveenddate > today) and serviceresource.isactive = TRUE order by territorytype, serviceresourceid];
                //if usertype = 'PowerPartner', amend existingSTMs query to include territorytype = 'P'

                //Oct 18 2021 Claire Crabtree
                IF(existingSTMs.size()>300){
                    throw new customException('There was an error retrieving Service Territory Members. Either there are no Primary Service Territory Members, or there are too many to handle.');
                }
                else{
                    opHoursWithTimeslots = [select id, name from operatinghours WHERE id IN (select operatinghoursid from timeslot) and id IN (select operatinghoursid from serviceterritorymember where id in :existingSTMs)];
                    Map<id, operatinghours> opHoursMap = new Map<Id, operatinghours>(opHoursWithTimeslots);
                    //create wrapper list containing information about existing, missing, and extra service territory members
                    for(serviceterritorymember sm : existingSTMs){
                        String resourceIdvar = String.valueOf(sm.serviceresourceId);
                        String terrIdVar = String.valueOf(sm.serviceterritoryId);
                        stmwrapper wrapperVar = new stmwrapper();
                            wrapperVar.serviceTerritoryName = sm.serviceterritory.name;
                            wrapperVar.serviceTerritoryId = sm.serviceterritoryid;
                            wrapperVar.serviceTerritoryMemberNumber = String.valueOf(sm.MemberNumber);
                            wrapperVar.serviceResourceId = resourceIdvar;
                            wrapperVar.serviceResourceName = sm.serviceresource.name;
                            wrapperVar.serviceTerritoryMemberId = sm.id;
                            wrapperVar.TerritoryType = sm.territorytype;
                            WrapperVar.OperatingHoursId = sm.operatinghoursid;
                            WrapperVar.OperatingHoursName = !String.isBlank(sm.operatinghoursid) ? sm.operatinghours.name : '';
                            WrapperVar.hasTimeSlots = opHoursMap.containsKey(sm.operatinghoursId)? true : false;
                        if(resource_territoriesIdMap.get(resourceIdvar).contains(terrIdVar)){
                            wrapperVar.membershipDesc = 'Valid';
                            resource_territoriesIdMap.get(resourceIdvar).remove(resource_territoriesIdMap.get(resourceIdvar).indexOf(terrIdVar));
                        }else{
                            wrapperVar.membershipDesc = 'Extra';
                        }
                        membershipList.add(wrapperVar);
                    }
                    //loop through remaining territories to see which STMs are missing
    
                    for(String rsr : resource_territoriesIdMap.keySet()){
                        if(resource_territoriesIdMap.get(rsr).size()>0){
                            Integer i = membershipList.size();
                            for(String stid : resource_territoriesIdMap.get(rsr)){
                                i += 1;
                                stmWrapper missingWrapperVar = new stmWrapper();
                                missingWrapperVar.serviceTerritoryName = allserviceterritoryIdMap.get(stid).name;
                                missingWrapperVar.serviceTerritoryId = stid;
                                missingWrapperVar.membershipDesc = 'Missing';
                                missingWrapperVar.serviceResourceId = rsr;
                                missingWrapperVar.serviceResourceName = allserviceresourceIdMap.get(rsr).name;
                                missingWrapperVar.serviceTerritoryMemberNumber = '';
                                missingWrapperVar.serviceTerritoryMemberId = String.valueOf(i);
                                missingWrapperVar.TerritoryType = 'S';
                                missingWrapperVar.OperatingHoursId = '';
                                membershipList.add(missingWrapperVar);
                                
                            }
                        }
                    }
                }


            }
            else if(serviceResourcesList.size()==0){
                throw new customException('There was an error retrieving Service Territory Members. Either there are no Primary Service Territory Members, or there are too many to handle.');
            }
            return membershipList;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static List<serviceterritory> getAllRelatedServiceTerritories(List<serviceterritoryMember> stmsList){

        List<serviceterritory> allServiceTerritories = new list<serviceterritory>();
        LIst<String> TerritoryIds = new List<String>();
        List<String> PrimaryTerritoryIds = new List<String>();
        for(serviceterritoryMember stmp : stmsList){
            TerritoryIds.add(stmp.serviceterritoryid);
            PrimaryTerritoryIds.add(stmp.serviceterritoryid);
            if(!String.isBlank(stmp.serviceterritory.parentterritoryId)){
                TerritoryIds.add(stmp.serviceterritory.parentterritoryid);
            }
        }       
        allServiceTerritories = [select id, name, parentterritoryid from serviceterritory where ((parentterritoryid in :TerritoryIds and isactive  = true and Auto_Create_STMs__c = true) OR id IN :PrimaryTerritoryIds) ];

        return allServiceTerritories;
    }

    public static Map<String, list<String>> mapFamilyTerritories(List<serviceTerritory> allserviceterritories){
        Map<String, list<String>> terrId_FamilyList = new Map<String, list<String>>();
        for(serviceterritory st : allserviceterritories){
            terrId_FamilyList.put(st.Id, new list<String>());
            for(serviceterritory stx : allserviceterritories){
                if((stx.parentterritoryid == st.parentterritoryid /*&& stx.id != st.id*/)|| stx.id == st.parentterritoryid){
                    terrId_FamilyList.get(st.id).add(stx.id);
                }
            }
        }

        return terrId_FamilyList;
    }

    public static Map<String, List<String>> getRuleTerritoriesMap(List<String> primaryTerrs){
        Map<String, List<String>> terr_ruleterrs = new Map<String, List<String>>();
        List<FSL_Service_Territory_STM_Rule__c> allRules = [select id, Primary_Service_Territory_Member_s_Of__c, Of_Service_Territory__c from FSL_Service_Territory_STM_Rule__c where Primary_Service_Territory_Member_s_Of__c IN :primaryTerrs];
        if(allRules.size()>0){
            for(FSL_Service_Territory_STM_Rule__c rulet : allRules){
                if(!terr_ruleterrs.containsKey(rulet.Primary_Service_Territory_Member_s_Of__c)){
                    terr_ruleterrs.put(rulet.Primary_Service_Territory_Member_s_Of__c, new List<String>());
                    
                }
                terr_ruleterrs.get(rulet.Primary_Service_Territory_Member_s_Of__c).add(rulet.Of_Service_Territory__c);
            }
        } 
        return terr_ruleterrs;
    }

    public static List<serviceterritory> getNamesforAllTerritories(map<string, list<string>> servTerrMap){
        List<serviceterritory> allServTerrs = new List<ServiceTerritory>();
        Set<string> StidsSet = new Set<String>();

        for(string one : servTerrMap.keySet()){
            for(string two : servTerrMap.get(one)){
                StidsSet.add(two);
            }
        }
        list<string> Stids = new list<String>(StidsSet);
        allServTerrs = [select id, name, parentterritoryid from serviceterritory where id IN :stids];
        return allServTerrs;
    }



private class stmWrapper{
    @AuraEnabled
    public String serviceTerritoryName {get; set;} 
    @AuraEnabled
    public String serviceTerritoryId {get; set;}   
    @AuraEnabled
    public String serviceTerritoryMembernumber {get; set;}   
    @AuraEnabled
    public String serviceTerritoryMemberId {get; set;}    
    @AuraEnabled
    public String serviceResourceName {get; set;}   
    @AuraEnabled
    public String serviceResourceId {get; set;}
    @AuraEnabled
    public String membershipDesc{get; set;} //3 values: Missing, Valid, Extra
    @AuraEnabled
    public string territoryType{get; set;}
    @AuraEnabled
    public string OperatingHoursId{get; set;}
    @AuraEnabled
    public string OperatingHoursName{get; set;}
    @AuraEnabled
    public boolean hasTimeSlots{get; set;}

    public stmWrapper(){}
}

}