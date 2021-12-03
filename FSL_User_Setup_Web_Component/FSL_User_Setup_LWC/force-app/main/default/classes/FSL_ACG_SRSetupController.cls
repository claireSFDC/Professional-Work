public without sharing class FSL_ACG_SRSetupController {

    @AuraEnabled
    public static list<FSLSetupUserWrapper> getUsers(String searchkey){

        List<FSLSetupUserWrapper> userWrapperList = new List<FSLSetupUserWrapper>();

        String searchString = 'SELECT id, EmployeeNumber, FederationIdentifier, firstname, lastname, Name, username, email, isactive, profileid, userroleid, profile.name, userrole.name, phone, street, city, state, PostalCode, country, contactID, contact.accountid, contact.account.Service_Territory__c, contact.account.name, contact.account.type, isportalenabled FROM user WHERE name like \'%' + searchkey + '%\' AND profile.name IN (\'FSL Contractor Dispatcher Access\', \'FSL Contractor Technician Access\', \'FSL Mobile (Fleet Technician)\', \'FSL facility Dispatcher (Fleet)\') AND userroleid != \'\' AND (NOT profile.name like \'%chatter%\') LIMIT 10';
            System.debug('search string : ' + searchString);
            List<User> userlist = database.query(searchString);
            Permissionset hybridp = [select id, name from permissionset where name = 'Hybrid_Driver'];
            List<permissionsetassignment> hybridperms = [SELECT id, assigneeid from permissionsetassignment where AssigneeId IN :userlist AND PermissionSetId = :hybridp.Id];
                List<String> hybriddriverIds = new list<String>();
                for(permissionsetassignment psa : hybridperms){
                    hybriddriverIds.add(psa.assigneeId);
                }
            List<serviceresource> serviceresources = [SELECT id, RelatedRecordId, Primary_Service_Territory__c, Driver_Id__c from ServiceResource WHERE RelatedRecordId IN :userlist];
                Map<Id, ServiceResource> userIDserviceresource = new Map<id, ServiceResource>();
                for(serviceresource sr : serviceresources){
                    userIDserviceresource.put(sr.relatedrecordid, sr);
                }
            list<FSL__User_Territory__c> userterritories = [SELECT id, FSL__ServiceTerritory__c, FSL__User__c, FSL__Territory_Name__c FROM FSL__User_Territory__c WHERE fsl__User__c IN :userlist];
                Map<Id, FSL__User_Territory__c> userIdTerrId = new Map<Id,FSL__User_Territory__c>();
                for(FSL__User_Territory__c ut : userterritories){
                    userIdTerrId.put(ut.fsl__user__c, ut);
                }
            List<ServiceTerritory> serviceTerritoriesList = [Select Id, Name, OperatingHoursId, OperatingHours.TimeZone from serviceterritory];
            Map<Id, ServiceTerritory> stmap = new Map<Id, ServiceTerritory>(serviceTerritoriesList);
            Map<Id, String> stIdAccountType = new Map<Id, String>();
            List<Account> STAccounts = [Select Id, Type, Service_Territory__c from account where Service_Territory__c IN :serviceTerritoriesList];
            for(account a : STAccounts){
                stIdAccountType.put(a.Service_Territory__c, a.Type);
            }

            for(user u : userlist){
                FSLSetupUserWrapper userwrapper = new FSLSetupUserWrapper();
                userwrapper.user = u;
                userwrapper.userId = u.id;
                userwrapper.firstname = u.firstname;
                userwrapper.fullname = u.name;
                userwrapper.lastname = u.lastname;
                userwrapper.username = u.username;
                userwrapper.email = u.email;
                userwrapper.profilename = u.profile.name;
                userwrapper.profileId = u.profileid;
                userwrapper.userroleid = u.userroleid;
                userwrapper.street = u.street;
                userwrapper.city = u.city;
                userwrapper.state = u.state;
                userwrapper.postal = u.postalcode;
                userwrapper.country = u.country;
                userwrapper.contactid = u.contactid;
                userwrapper.EmployeeNumber = !String.isBlank(u.employeenumber) ? u.employeenumber : u.FederationIdentifier;

                if(hybriddriverIds.contains(u.id)){
                    userwrapper.usertype = 'Technician_Dispatcher';
                }
                else if(u.profile.name.contains('Dispatcher')){
                    userwrapper.usertype = 'Dispatcher';
                }
                else{
                    userwrapper.usertype = 'Technician';
                }

                if(userIDserviceresource.containskey(u.id)){
                    userwrapper.serviceresourceId = userIDserviceresource.get(u.id).id;
                    userwrapper.serviceresource = userIDserviceresource.get(u.id);
                    String stId = userIDserviceresource.get(u.id).primary_service_territory__c;
                    userwrapper.facilityName = stmap.get(stId).name;
                    userwrapper.facilityType = stIdAccountType.get(stId);
                    userwrapper.serviceterritoryId = stId;
                    userWrapper.TimeZone = stmap.get(stID).operatingHours.TimeZone;
                    userwrapper.serviceterritory = stmap.get(stId);
                    userwrapper.drivernumber = userIDserviceresource.get(u.id).Driver_Id__c;
                    if(u.isportalenabled == true){
                        userwrapper.accountid = u.contact.accountid;
                        userwrapper.contactid = u.contactid;
                    }                
                }
                else if(u.IsPortalEnabled == TRUE){
                    userwrapper.facilityName = u.contact.account.name;
                    userwrapper.facilityType = u.contact.account.type;
                    userwrapper.accountid = u.contact.accountid;
                    String stId = u.contact.account.Service_Territory__c;
                    userwrapper.serviceterritoryId = stId;
                    userwrapper.serviceterritory = stmap.get(stId);
                    userWrapper.TimeZone = stmap.get(stID).operatingHours.TimeZone;
                }
                else if(userIdTerrId.containsKey(u.Id)){
                    userwrapper.facilityName = userIdTerrId.get(u.Id).FSL__Territory_Name__c;
                    String stId = userIdTerrId.get(u.Id).FSL__ServiceTerritory__c;
                    userwrapper.serviceterritoryId = stId;
                    userwrapper.serviceterritory = stmap.get(stId);
                    userWrapper.TimeZone = stmap.get(stID).operatingHours.TimeZone;
                    userwrapper.facilityType = stIdAccountType.get(stId);
                }
                else{
                    userwrapper.facilityName = 'ACG Fleet - UNDEFINED';
                    userwrapper.facilityType = 'Fleet';
                }

                if(u.isactive == true){
                    userwrapper.status = 'Active';
                }
                else{
                    userwrapper.status = 'INACTIVE';
                }

                userWrapperList.add(userwrapper);
            }
            System.debug(userWrapperList);

        return userWrapperList;
    }

    @AuraEnabled
    public static FSLSetupUserWrapper getSelectedPersonInfo(FSLSetupUserWrapper selectedperson){
        selectedperson.setupStatus = 'Incomplete';
        List<PermissionSetAssignment> psa = [SELECT id, assigneeid, permissionsetid FROM permissionsetassignment where assigneeid = :selectedperson.userId  AND assignee.isactive = true AND permissionset.name IN ('FSL_Community_Dispatcher_License', 'FSL_Community_Dispatcher_Permissions', 'FSL_Dispatcher_License' ,'FSL_Dispatcher_Permissions', 'FSL Hybrid_Driver', 'FSL_Resource_License', 'FSL_Resource_Permissions', 'Mobile_Technician_Permission_Set', 'Dispatcher_Permission_Set')];
        List<ServiceResourceSkill> servResSkills = new list<ServiceResourceSkill>();
        String SkillsString = '';
        if(psa.size() >= 3){
            List<FSL__User_Territory__c> selectedUserTerritory = [Select id from FSL__User_Territory__c WHERE FSL__User__c = :selectedperson.userId];
            if(selectedUserTerritory.size() > 0){
                if(selectedperson.usertype == 'Dispatcher'){
                    selectedperson.setupStatus = 'Complete';
                }
                else{
                    if(selectedperson.serviceresource != NULL){
                        List<ServiceTerritoryMember> primarystm = [SELECT id, EffectiveStartDate, OperatingHoursId FROM ServiceTerritoryMember where serviceresourceid = :selectedperson.serviceresourceid
                                                                    AND TerritoryType = 'P'];
                        if(primarystm.size() == 1){
                            selectedperson.startdate = primarystm[0].EffectiveStartDate;
                            if(!String.isBlank(primarystm[0].OperatingHoursId)){
                                selectedperson.setupStatus = 'Complete';
                            }
                        }
                    }
                }
            }
        }

        IF(!String.isBlank(selectedperson.serviceterritoryId)){
            List<Account> acc = [SELECT Id, Name, Service_Territory__c, Service_Territory__r.OperatingHoursId, Service_Territory__r.OperatingHours.Timezone, ownerid, Facility_Id__c, IsPartner  FROM Account WHERE Service_Territory__c = :selectedperson.serviceterritoryId];
            if(acc.size() ==1){
                selectedperson.TimeZone = acc[0].Service_Territory__r.OperatingHours.Timezone;
                selectedperson.accountId = acc[0].Id;
                selectedperson.account = acc[0];}
        }

        servResSkills = [select id, skill.masterlabel from serviceresourceskill where Skill_Type__c = 'Resource-Dependent' AND serviceresourceid = :selectedperson.serviceresourceId];
        if(servResSkills.size() >0){
            SkillsString = '[';
            for(ServiceResourceSkill sk : servResSkills){
                SkillsString += (sk.skill.masterlabel + ';');
            }
            SkillsString = SkillsString.mid(0, SkillsString.length() - 1) + ']';
        }
        selectedperson.resourceSkills = SkillsString;
        System.debug('SKILLZZ : ' + SkillsString);
        return selectedperson;
    }

    @AuraEnabled
    public static list<account> getFacilities(String searchkey, boolean isFleet, boolean isPersonSelected){
        string query = 'Select Id, Name, Type, OwnerId, Owner.Name, Owner.Userroleid, Owner.Userrole.Developername, BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode, Service_Territory__c, Service_Territory__r.OperatingHoursId, Service_Territory__r.OperatingHours.TimeZone, Facility_id__c, IsPartner from account where name like \'%' + searchkey + '%\' AND Service_Territory__c !=\'\' AND Service_Territory__r.isactive = true AND Facility_ID__c !=\'\' AND Owner.Userrole.developername = \'Field_Representative\' AND Service_Territory__r.OperatingHoursId !=\'\'';
        if(isFleet == true){
            query = query + ' AND type = \'Fleet\'';
        }
        else if (isFleet == false && isPersonSelected == True){
            query = query + ' AND (type != \'Fleet\') and IsPartner = TRUE';
        }
        list<account> accounts = (list<account>)database.query(query);
        return accounts; 
    }

}