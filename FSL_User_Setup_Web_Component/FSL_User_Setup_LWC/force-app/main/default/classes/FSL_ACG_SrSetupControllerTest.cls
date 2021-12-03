@isTest(seeAllData = true)
public class FSL_ACG_SrSetupControllerTest {

    static TestMethod void getUsersTest() {
        List<user> aaaadmins= [select id from user where profile.name = 'System Administrator' and isactive = true]; //check, System Administrater?
        User admin = aaaadmins[0];
        System.runAs(admin){
        //fslcarrecordsfactory();
        String orgId = UserInfo.getOrganizationId();
        //operating Hours
        OperatingHours oph = new OperatingHours(
            name = 'Test Op Hours'
        );
        insert oph;
        //Service Territories
        ServiceTerritory st = new ServiceTerritory(
            name = 'Sr Setup Test Serv Terr',
            IsActive = True,
            OperatingHoursId = oph.id
        );
        ServiceTerritory fleetst = new ServiceTerritory(
            name = 'Fleet Sr Setup Serv Terr',
            IsActive = True,
            OperatingHoursId = oph.id
        );
        List<ServiceTerritory> sttoinsert = new List<ServiceTerritory>{st, fleetst};
        insert sttoinsert;
        //account owner
        List<User> ersmanagers = [Select id, name from user where userrole.developername ='Field_Representative' and isactive = true limit 1];
        User ersmanager = ersmanagers[0];
        //Accounts
        Account acc = new Account(
            Name = 'Sr Setup Test Serv Terr',
            BillingStreet = '1600 Penn Ave',
            BillingCity = 'Washington',
            BillingState = 'DC',
            BillingCountry = 'USA',
            BillingPostalCode = '28216',
            Service_Territory__c = st.Id,
            Facility_id__c = '66666',
            ownerid = ersmanager.id, 
            type = 'Partner'
        );
        Account fleetacc = new Account(
            Name = 'Fleet Sr Setup Serv Terr',
            BillingStreet = '1600 Penn Ave',
            BillingCity = 'Washington',
            BillingState = 'DC',
            BillingCountry = 'USA',
            BillingPostalCode = '28216',
            Service_Territory__c = fleetst.Id,
            Facility_id__c = '66667',
            Type = 'Fleet'
        );
        List<Account> acctoinsert = new list<account>{acc, fleetacc};
        insert acctoinsert;
        acc.isPartner = true;
        update acc;
        //partner contacts
        List<Contact> partnercontacts = new list<contact>();
        for(Integer i = 1; i<=18; i++){
            Contact con = new Contact(
                firstname = 'name' + i,
                lastname = 'last'+ i,
                accountid = acc.id,
                email = orgId + i + '@yopmail.com'
            );
            partnercontacts.add(con);
        }
        insert partnercontacts;
        List<profile> fslprofiles = [SELECT id, name from profile where name IN ('FSL Contractor Dispatcher Access', 'FSL Contractor Technician Access', 'FSL Mobile (Fleet Technician)', 'FSL facility Dispatcher (Fleet)')];
        Map<String, profile> profilemap = new map<String, profile>();
        for(profile p : fslprofiles){
            profilemap.put(p.name, p);
        }

        //partner users
        List<user> partnerusers = new list<user>();
        String profileidt;
        for(Integer j = 1; j<=partnercontacts.size(); j++){
            Contact c = partnercontacts[(j-1)];
            if((math.mod(j, 2) == 0)){
                profileidt = profilemap.get('FSL Contractor Dispatcher Access').id;

            }
            else{profileidt = profilemap.get('FSL Contractor Technician Access').id;}
            User u = new User(
                firstname = c.firstname,
                lastname = c.lastname,
                email=c.email,
                username = c.email,
                contactid = c.id,
                alias = c.firstname + j,
                isactive = true,
                profileid =  profileidt,
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'ISO-8859-1',
                TimeZoneSidKey = 'America/New_York',
                CommunityNickname = c.email
            );
            partnerusers.add(u);

        }

        //Fleet Users
        List<user> fleetusers =new list<user>();
        for(Integer k=1; k<=18; k++){
            if((math.mod(k,3) == 0)){
                profileidt = profilemap.get('FSL Mobile (Fleet Technician)').id;
            }
            else{
                profileidt = profilemap.get('FSL Facility Dispatcher (Fleet)').id;
            }
            User u = new User(
            firstname = 'tname' + k,
            lastname = 'tlastname' + k,
            email=orgId + k + '=aaaACG@yopmail.com',
            username = orgId + k + '=aaaACG@yopmail.com',
            alias = 'tname' + k +'@',
            isactive = true,
            profileid = profileidt,
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            TimeZoneSidKey = 'America/New_York'
            );
            fleetusers.add(u);
        }
        List<user> allusers = new list<user>();
        allusers.addall(fleetusers);
        allusers.addall(partnerusers);
        insert allusers;
        fleetusers = [SELECT id, firstname, lastname, isactive, email, username, profileid, profile.name, userroleid from user where id IN :fleetusers];
        partnerusers = [SELECT id, firstname, lastname, isactive, email, username, profileid, profile.name, userroleid, contactid from user where id IN :partnerusers];
        allusers = [SELECT id, firstname, lastname, isactive, email, username, profileid, profile.name, userroleid, contactid from user where id IN :allusers];
        System.debug(allusers);
        //get permission sets lists
        List<permissionset> permsets = [Select id, name from permissionset where name IN ('FSL_Community_Dispatcher_License', 'FSL_Community_Dispatcher_Permissions', 'FSL_Dispatcher_License' ,'FSL_Dispatcher_Permissions','Hybrid_Driver', 'FSL_Resource_License', 'FSL_Resource_Permissions', 'Mobile_Technician_Permission_Set', 'Dispatcher_Permission_Set')];
        List<permissionset> commtechperms = new list<permissionset>();
        list<permissionset> commdispperms = new list<permissionset>();
        list<permissionset> commhybridperms = new list<permissionset>();
        List<permissionset> towmarktechperms = new list<permissionset>();
        list<permissionset> towmarkdispperms = new list<permissionset>();
        list<permissionset> towmarkhybridperms = new list<permissionset>();
        for(permissionset ps : permsets){
            if(ps.name.contains('Dispatcher')){
                if(ps.name.contains('Community')){
                    commdispperms.add(ps);
                    commhybridperms.add(ps);
                }
                else if(ps.name =='Dispatcher_Permission_Set'){
                    commdispperms.add(ps);
                    towmarkdispperms.add(ps);
                    commhybridperms.add(ps);
                    towmarkhybridperms.add(ps);
                }
                else{
                    towmarkdispperms.add(ps);
                    towmarkhybridperms.add(ps);
                }
            }
            else if(ps.name.contains('Resource')){
                commtechperms.add(ps);
                commhybridperms.add(ps);
                towmarktechperms.add(ps);
                towmarkhybridperms.add(ps);
            }
            else if(ps.name.contains('Hybrid')){
                towmarkhybridperms.add(ps);
                commhybridperms.add(ps);
            }
        }
        //insert permission sets
        List<permissionsetassignment> permsetas = new list<permissionsetassignment>();
        for(Integer m=0; m<fleetusers.size(); m++){
            User u = fleetusers[m];
            if(u.profile.name.contains('Technician')){
                for(permissionset ps : towmarktechperms){
                    permissionsetassignment psa = new permissionsetassignment(
                        AssigneeId = u.id,
                        PermissionSetId = ps.id
                    );
                    permsetas.add(psa);
                }
            }
            else if(math.mod(m,2)==0 && u.profile.name.contains('Dispatcher')){
                for(permissionset ps : towmarkdispperms){
                    permissionsetassignment psa = new permissionsetassignment(
                        AssigneeId = u.id,
                        PermissionSetId = ps.id
                    );
                    permsetas.add(psa);
                }
            }
            else if(u.profile.name.contains('Dispatcher')){
                for(permissionset ps : towmarkhybridperms){
                    permissionsetassignment psa = new permissionsetassignment(
                        AssigneeId = u.id,
                        PermissionSetId = ps.id
                    );
                    permsetas.add(psa);
                }

            }
        }
        for(Integer n=0; n<partnerusers.size(); n++){
            User u = partnerusers[n];
            if(u.profile.name.contains('Technician')){
                for(permissionset ps : commtechperms){
                    permissionsetassignment psa = new permissionsetassignment(
                        AssigneeId = u.id,
                        PermissionSetId = ps.id
                    );
                    permsetas.add(psa);
                }
            }
            else if(math.mod(n,2)==0){
                for(permissionset ps : commdispperms){
                    permissionsetassignment psa = new permissionsetassignment(
                        AssigneeId = u.id,
                        PermissionSetId = ps.id
                    );
                    permsetas.add(psa);
                }
            }
            else{
                for(permissionset ps : commhybridperms){
                    permissionsetassignment psa = new permissionsetassignment(
                        AssigneeId = u.id,
                        PermissionSetId = ps.id
                    );
                    permsetas.add(psa);
                }

            }
        }
        insert permsetas;

        //create service resources
        list<serviceresource> serviceresources = new list<serviceresource>();
        list<user> usersnoSR = new list<user>();
        for(Integer l = 0; l<allusers.size(); l++){
            User u = allusers[l];
            if(u.profile.name.contains('Technician') && math.mod(l, 2)==0){
                serviceresource sr = new serviceresource(
                    name = u.firstname + ' ' + u.lastname,
                    primary_service_territory__c = String.isBlank(u.contactid) ? st.id : fleetst.id,
                    relatedrecordid = u.id,
                    driver_id__c = String.valueOf(l),
                    isactive = true,
                    IsOptimizationCapable = true,
                    ResourceType = 'T'
                );
                serviceresources.add(sr);
            }
            else{usersnoSR.add(u);}
        }
        insert serviceresources;
        // create User Territories
        list<FSL__User_Territory__c> UTs = new list<FSL__User_Territory__c>();
        for(ServiceResource sr : serviceresources){
            FSL__User_Territory__c ut = new FSL__User_Territory__c(
                FSL__User__c = sr.relatedrecordid,
                FSL__ServiceTerritory__c =sr.primary_service_territory__c
            );
            UTs.add(ut);
        }
        for(user u : usersnoSR){
            FSL__User_Territory__c ut = new FSL__User_Territory__c(
                FSL__User__c = u.id,
                FSL__ServiceTerritory__c = String.isBlank(u.contactid) ? st.id : fleetst.id
            );
        }
        insert UTs;
        //deactivate half of users
        // for(Integer x=0; x<allusers.size(); x++){
        //     if(math.mod(x, 2)==0){
        //         allusers[x].isactive = false;
        //     }
        // }
        // update allusers;
        //create primary STMs
        list<ServiceTerritoryMember> STMs = new list<Serviceterritorymember>();
        for(serviceresource sr : serviceresources){
            ServiceTerritoryMember stm = new serviceterritorymember(
                operatinghoursid = oph.id,
                serviceresourceid = sr.id,
                serviceterritoryid = sr.primary_service_territory__c,
                effectivestartdate = datetime.now(),
                TerritoryType = 'P'
            );
        }
        insert STMs;

        //perform test
        Test.startTest();
        List<FSLSetupUserWrapper> Wrapperlist = FSL_ACG_SRSetupController.getUsers('name');
        FSLSetupUserWrapper wrapperrec = Wrapperlist[0];
        wrapperrec = FSL_ACG_SRSetupController.getSelectedPersonInfo(wrapperrec);
        Test.stopTest();
    }
}

    
    static TestMethod void getFacilitiesTest() {

        OperatingHours oph = new OperatingHours(
            name = 'Claire Test Hours',
            TimeZone = 'America/New_York'
        );
        insert oph;
        ServiceTerritory st = new ServiceTerritory(
            name = 'Claire Serv Terr',
            IsActive = True,
            OperatingHoursId = oph.id
        );
        ServiceTerritory fleetst = new ServiceTerritory(
            name = 'Fleet Serv Terr',
            IsActive = True,
            OperatingHoursId = oph.id
        );
        List<ServiceTerritory> sttoinsert = new List<ServiceTerritory>{st, fleetst};
        insert sttoinsert;
        Account acc = new Account(
            Name = 'Claire Serv Terr',
            BillingStreet = '1600 Penn Ave',
            BillingCity = 'Washington',
            BillingState = 'DC',
            BillingCountry = 'USA',
            BillingPostalCode = '28216',
            Service_Territory__c = st.Id,
            Facility_id__c = '66666',
            Type = 'Partner'
        );
        Account fleetacc = new Account(
            Name = 'Towmark Serv Terr',
            BillingStreet = '1600 Penn Ave',
            BillingCity = 'Washington',
            BillingState = 'DC',
            BillingCountry = 'USA',
            BillingPostalCode = '28216',
            Service_Territory__c = fleetst.Id,
            Facility_id__c = '66667',
            Type = 'Fleet'
        );
        List<Account> acctoinsert = new list<account>{acc, fleetacc};
        insert acctoinsert;

        Test.startTest();
        List<account> servterrs = FSL_ACG_SRSetupController.getFacilities('serv terr', true, true);
        List<account> servterrstowmark = FSL_ACG_SRSetupController.getFacilities('serv terr', false, true);

        Test.stopTest();
    }

}