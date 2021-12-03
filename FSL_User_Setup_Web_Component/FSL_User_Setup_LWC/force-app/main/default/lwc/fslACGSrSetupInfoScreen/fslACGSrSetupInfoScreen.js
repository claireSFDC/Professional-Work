import { LightningElement , track , api} from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import GetUsers from '@salesforce/apex/FSL_ACG_SRSetupController.getUsers';
import GetSelectedUser from '@salesforce/apex/FSL_ACG_SRSetupController.getSelectedPersonInfo';
import getFacilities from '@salesforce/apex/FSL_ACG_SRSetupController.getFacilities';

export default class fslACGSrSetupInfoScreen extends LightningElement {


    @api firstname;
    @api lastname;
    @api emailaddress;
    @api phone;
    @api startdate;
    @api driverNumber;
    @api employeeNumber = this.driverNumber;
    @api typeofuser;
    @api street;
    @api city;
    @api state;
    @api country;
    @api postal;
    @api fleetOrPartnerFlow;
    @api selectedPersonUser;
    @api selectedPersonServiceTerritory;
    @api selectedPersonServiceResource;
    @api selectedPersonAccountId;
    @api ServiceTerritoryId;
    @api actionFlow = 'Setup';
    @api selectedPersonIsOwner = false;
    @api emailisInvalid;
    @api selectedFacility;
    @api infoNotComplete;
    @api emailIsTaken;
    @api facilityName;
    @api selectedSkillsString;

    @track timeZone;
    @track fullname;
    @track selectedPerson;
    @track error;    
    @track peopleFromSearch =[];
    @track showPeople = false;
    @track userId;
    @track showFacilities = false;
    @track facilities = [];
    @track FacilityIsSet = false;
    @track status;
    @track setupStatus;
    @track isHybrid;
    @track statusChangeWarning;
    @track selectedSkills =[];
    
    connectedCallback(){
        this.buildSkillsList();
    } 

    buildSkillsList(){
        if(this.selectedSkillsString != null){
            this.selectedSkillsString = this.selectedSkillsString.substring(1, this.selectedSkillsString.length - 1);
            this.selectedSkills = this.selectedSkillsString.split(';');
        }else{
            this.selectedSkills = ['Change Tire', 'Extrication', 'Lockout Entry', 'Tire Fill'];
        }
    }

    get skillsOptions(){
        return [{ label : 'Change Tire', value: 'Change Tire'},
        { label : 'Tire Fill', value: 'Tire Fill'},
        { label : 'Extrication', value: 'Extrication'},
        { label : 'Lockout Entry', value: 'Lockout Entry'},
        { label : 'Battery Technician', value: 'Battery Technician'},
        { label : 'Motorcycle Expert', value: 'Motorcycle Expert'},
        { label : 'Locksmith Expert', value: 'Locksmith Expert'}];
    }
    
    get isFleet(){
        return (this.fleetOrPartnerFlow && this.fleetOrPartnerFlow.includes('Fleet')) ? true : false;
    }

    get isPersonSelected(){
        return (this.selectedPerson) ? true : false;
    }
    

    handleFullNameChange(event){
        this.fullname = event.target.value;
        if(!this.fullname){
            this.peopleFromSearch.length = 0;
            this.showPeople = false;
        }
        else{
            this.delayTimeout = setTimeout(() =>{
                GetUsers({ searchkey : this.fullname})
                    .then(result =>{
                        this.showPeople = true;
                        this.peopleFromSearch = result;
                    })
                    .catch(error =>{
                        this.error = error;
                    })
            }, 300)
        }
    }

    handleFacilityNameChange(event){
        this.facilityName = event.target.value;
        if(!this.facilityName){
            this.facilities.length = 0;
            this.showFacilities = false;
        }
        else{
            this.delayTimeout = setTimeout(() =>{
                getFacilities({ searchkey : this.facilityName, isFleet : this.isFleet, isPersonSelected : this.isPersonSelected})
                    .then(result =>{
                        this.showFacilities = true;
                        this.facilities = result;
                    })
                    .catch(error =>{
                        this.error = error;
                    })
            }, 300)
        }
    }

    handleSelectFacility(event){
        this.showFacilities = false;
        let index = this.facilities.findIndex(f => f.Id === event.currentTarget.dataset.facilityid); 
        this.selectedFacility = this.facilities[index];
        this.ServiceTerritoryId = this.selectedFacility.Service_Territory__c;
        this.timeZone = this.selectedFacility.Service_Territory__r.OperatingHours.TimeZone;
        this.facilities.length = 0;
        this.fleetOrPartnerFlow = this.selectedFacility.Type == 'Fleet' ? 'Fleet' : 'Partner';
        //this.fleetOrPartnerFlow = this.selectedFacility.Name.includes('Fleet') ? 'Fleet' : 'Partner'; this is the old one
        this.street = this.selectedFacility.BillingStreet;
        this.city = this.selectedFacility.BillingCity;
        this.state = this.selectedFacility.BillingState;
        this.postal = this.selectedFacility.BillingPostalCode;
        this.country = this.selectedFacility.BillingCountry;
    }

    handleRemoveFacility(event){
        event.preventDefault();
        this.selectedFacility = null;
        this.ServiceTerritoryId = '';
        this.facilityName = '';
        this.street = '';
        this.city = '';
        this.state = '';
        this.postal = '';
        this.country = '';
        this.timeZone = '';

        this.handleUpdateFlow();
    }

    get typeofuserOptions() {
        return [
            { label: 'Technician (Driver)', value: 'Technician' },
            { label: 'Dispatcher', value: 'Dispatcher' },
            { label: 'Hybrid Technician & Dispatcher', value: 'Technician_Dispatcher' },
        ];
    }

    get statusOptions(){
        return [
            { label: 'Active', value: 'Active' },
            { label: 'INACTIVE', value: 'INACTIVE' },
        ];
    }

    handleInfoChange(event){
        if(event.target.name == "firstname"){
            this.firstname = event.target.value;
            this.firstNameFlow = event.target.value;
        }
        else if(event.target.name == "lastname"){
            this.lastname = event.target.value;
            this.lastNameFlow = event.target.value;
        }
        else if(event.target.name == "emailaddress"){
            this.emailaddress = event.target.value;
        }
        else if(event.target.name == "phone"){
            this.phone = event.target.value;
        }
        else if(event.target.name == "startdate"){
            this.startdate = event.detail.value;
        }
        else if(event.target.name == "drivernumber"){
            this.driverNumber = event.target.value;
            if(this.isFleet == false){
                this.employeeNumber = event.target.value;
            }
            
        }
        else if(event.target.name == "employeenumber"){
            this.employeeNumber = event.target.value;
        }
        else if(event.target.name == "typeofuser"){
            this.typeofuser = event.target.value;
            if(event.target.value == 'Technician_Dispatcher'){
                this.isHybrid = true;
            }
            else{
                this.isHybrid = false;
                this.selectedPersonIsOwner = false;
            }
        }
        else if(event.target.name == 'userstatus' || event.target.name == 'userstatuss'){
            if(event.target.value == 'Active' && this.selectedPerson.status == 'INACTIVE'){
                this.statusChangeWarning = "You have selected to ACTIVATE a currently inactive user. This user will be assigned a Field Service license and be able to log in to Salesforce.";
                this.actionFlow = 'Reactivate';
            }
            else if(event.target.value == 'INACTIVE' && this.selectedPerson.status =='Active'){
                this.statusChangeWarning = "You have selected to DEACTIVATE an active user. The Field Service license will be removed and they will no longer have login access to Salesforce.";
                this.actionFlow = 'Deactivate';
            }
            else if(event.target.value == 'INACTIVE' && this.selectedPerson.status == 'INACTIVE'){
                this.actionFlow = 'Deactivate';
            }
            else{
                this.statusChangeWarning = null;
            }
        }
        else if(event.target.name == 'address' || event.target.name == 'addressT' ){
            this.street = event.target.street;
            this.city = event.target.city;
            this.state = event.target.province;
            this.postal = event.target.postalCode;
            this.country = event.target.country;
        }
        else if(event.target.name=='isowner'){
            this.selectedPersonIsOwner = event.target.checked;
        }
        else if(event.target.name=='Skills Group'){
            this.selectedSkills = event.detail.value;
        }
        this.handleUpdateFlow();
    }

    handleSelectPerson(event){
        this.showPeople = false;
        this.selectedSkillsString = '';
        this.selectedSkills = [];
        
        this.userId = event.currentTarget.dataset.userid;
        let index = this.peopleFromSearch.findIndex(person => person.userId === this.userId);
        this.selectedPerson = this.peopleFromSearch[index];

        GetSelectedUser({selectedperson : this.selectedPerson})
            .then(result =>{
                this.selectedPerson = result;
                
                this.fullname = this.selectedPerson.fullname;
                this.firstname = this.selectedPerson.firstname;
                this.lastname = this.selectedPerson.lastname;
                this.emailaddress = this.selectedPerson.email;
                this.phone = this.selectedPerson.phone;
                this.driverNumber =this.selectedPerson.drivernumber;
                this.typeofuser = this.selectedPerson.usertype;
                this.startdate = this.selectedPerson.startdate;
                this.status = this.selectedPerson.status;
                this.setupStatus = this.selectedPerson.setupStatus;
                this.street = this.selectedPerson.street;
                this.city = this.selectedPerson.city;
                this.state = this.selectedPerson.state;
                this.postal = this.selectedPerson.postal;
                this.country = this.selectedPerson.country;
                this.employeeNumber = this.selectedPerson.EmployeeNumber;
                this.selectedSkillsString = this.selectedPerson.resourceSkills;
                this.buildSkillsList();

                if(this.selectedPerson.usertype == 'Technician_Dispatcher'){
                    this.isHybrid = true;
                }

                this.handleCheckFacility();

                this.selectedPersonUser = this.selectedPerson.user;
                this.selectedPersonServiceTerritory = this.selectedPerson.serviceterritory;
                this.selectedPersonServiceResource = this.selectedPerson.serviceresource;
                this.ServiceTerritoryId = this.selectedPerson.serviceterritoryId;
                this.timeZone = this.selectedPerson.TimeZone;

                if(this.selectedPerson.status == 'INACTIVE'){
                    this.actionFlow = 'Deactivate'
                }
                else{
                    this.actionFlow ='Update';
                }

                this.handleUpdateFlow;
            })
            .catch(error=>{
                this.error=error;
            })
            this.peopleFromSearch.length = 0;
    }

    handleCheckFacility(){

        //this.fleetOrPartnerFlow = this.selectedPerson.facilityName.includes('Fleet') ? 'Fleet' : 'Partner'; //old version
        this.fleetOrPartnerFlow = this.selectedPerson.facilityType == 'Fleet' ? 'Fleet' : 'Partner'; 

        if(this.selectedFacility && this.selectedPerson.facilityName.includes('UNDEFINED')){
            this.selectedFacility = null;
            this.facilityName = '';
        }
        else if(this.selectedPerson.serviceterritoryId){
            this.FacilityIsSet = true;
            this.facilityName = this.selectedPerson.facilityName;
            this.selectedFacility = this.selectedPerson.account;
        }
        else{
            this.facilityName = '';
        }
        this.facilities.length = 0;
    }

    handleRemovePerson(event){
        event.preventDefault();

        this.selectedPerson = null;
        this.selectedPersonUser = null;
        this.personIsSelected = false;
        this.FacilityIsSet = false;
        this.actionFlow = 'Setup';

        this.fullname = null;
        this.firstname = null
        this.lastname = null;
        this.emailaddress = this
        this.phone = null;
        this.driverNumber =null;
        this.typeofuser = null;
        this.startdate = null;
        this.facilityName = null;
        this.status = null;
        this.setupStatus = null;
        this.street = '';
        this.city = '';
        this.state = '';
        this.postal = '';
        this.country = '';
        this.isHybrid = false;
        this.statusChangeWarning = null;
        this.fleetOrPartnerFlow = null;
        this.selectedSkillsString = null;
        this.selectedSkills = ['Change Tire', 'Extrication', 'Lockout Entry', 'Tire Fill'];

        if(this.selectedFacility && this.selectedFacility.Type == 'Fleet'){ 
            this.selectedFacility = null;
            this.timeZone = '';
            this.ServiceTerritoryId = '';
        }

        this.handleUpdateFlow;
    }
    
    handleUpdateFlow(){
        this.selectedSkillsString = "[" + this.selectedSkills.join(';') + "]";
        ["selectedFacility", "fleetOrPartnerFlow", "selectedPersonUser", "selectedPersonServiceTerritory", "selectedPersonServiceResource", "ServiceTerritoryId", "firstname", "lastname", "emailaddress", "phone", "startdate", "drivernumber", "typeofuser", "actionFlow", "street", "city", "state", "postal", "country", "employeeNumber", "selectedSkillsString"].forEach((prop)=>{
            this.dispatchEvent(new FlowAttributeChangeEvent(prop, this[prop]))
        });
    }
}