import { LightningElement ,track , api, wire} from 'lwc';
import getSTMData from '@salesforce/apex/Fsl_STM_ViewMembershipController.getRequiredTerritories';
import { refreshApex } from '@salesforce/apex';

const columns = [
    // icon appended with a label
    {label: 'Type', fieldName : 'territoryType', type: 'text', fixedWidth : 40, hideDefaultActions : true},
    {label : 'Resource', fieldName : 'resourceURL', type: 'url', typeAttributes: 
        {label: { fieldName: 'serviceResourceName' }, target: '_blank' }, cellAttributes :
        {class: { fieldName : 'cellStyle' }}},
    {label : 'Territory', fieldName : 'terrURL', type: 'url', typeAttributes: 
        {label: { fieldName: 'serviceTerritoryName' }, target: '_blank' }, cellAttributes :
        {class: { fieldName : 'cellStyle' }}},
    {label: 'STM', fieldName: 'stmURL', type: 'url', typeAttributes:
        {label : {fieldName : 'serviceTerritoryMemberNumber'}, target: '_blank'}, 
        cellAttributes:
            { iconName: { fieldName: 'membershipIcon' }, iconPosition: 'left', class : {fieldName : 'cellStyle'} }},
    {label: 'Op Hours', fieldName: 'opHoursURL', type : 'url', typeAttributes:
        {label : {fieldName : 'operatingHoursName'}, target: '_blank' }, 
        cellAttributes :
            { iconName : {fieldName : 'operatingHoursIcon'}, iconPosition : 'left', class: { fieldName : 'cellStyle' }}}
     ];

const membershipIcons =[
    {MembershipDesc : 'Missing', membershipIcon: 'action:close'},
    {MembershipDesc : 'Extra', membershipIcon: 'action:priority'},
    {MembershipDesc : 'Valid', membershipIcon: 'action:approval'}]

const attributesByTerrType = [
    {territoryType: 'P', cellStyle : 'slds-text-title_bold'},
    {territoryType: 'S', cellStyle : 'slds-text-body_regular'}
]

export default class Fsl_STM_ViewMembership extends LightningElement {

    @api recordId;
    @api objectApiName;

    membershipIconsAssignment = membershipIcons;
    columns = columns;
    attributesByTerrType = attributesByTerrType;
    @track membersList = undefined;
    @track errorMessage = undefined;

    @wire(getSTMData, {myRecordId : '$recordId', objectType :'$objectApiName'})
    wiredSTMs(value){
        this.wiredSTMValue = value;
        const{ data, error} = value;
        if(data){
            const newmemlist = [];
            data.forEach(member => {
                var newmem = {
                serviceTerritoryName : member.serviceTerritoryName,
                serviceTerritoryMemberNumber : member.serviceTerritoryMembernumber,
                serviceTerritoryMemberId : member.serviceTerritoryMemberId,
                serviceResourceName : member.serviceResourceName,
                resourceURL : "/" + member.serviceResourceId,
                terrURL : "/" + member.serviceTerritoryId,
                stmURL : member.serviceTerritoryMembernumber.startsWith('STM') ?  "/" + member.serviceTerritoryMemberId : '',
                opHoursURL : member.OperatingHoursId ? "/" + member.OperatingHoursId : '',
                territoryType : member.territoryType,
                membershipIcon : this.membershipIconsAssignment.find( ({ MembershipDesc }) => MembershipDesc === member.membershipDesc).membershipIcon,
                cellStyle : this.attributesByTerrType.find( ({ territoryType }) => territoryType === member.territoryType).cellStyle,
                membershipDesc : member.membershipDesc,              
                operatingHoursId : member.OperatingHoursId,
                operatingHoursName : member.OperatingHoursName,
                operatingHoursIcon : (member.OperatingHoursId || member.territoryType == 'P')  && member.hasTimeSlots == false ? 'action:close' : '',
            }
                console.log(newmem);
                newmemlist.push(newmem);
            });
            this.membersList = newmemlist;
            this.errorMessage = undefined;
        } else if (error){
            this.errorMessage = error.body.message;
            console.log(this.errorMessage);
            this.membersList = undefined;
        }
    }

    refreshList(){
        refreshApex(this.wiredSTMValue);
    }

}