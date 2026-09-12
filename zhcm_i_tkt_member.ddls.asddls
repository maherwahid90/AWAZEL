@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Request Members'
//@Metadata.ignorePropagatedAnnotations: true
define view entity zhcm_i_tkt_member as select from zhcm_tick_member
association to parent zhcm_i_tkt as _Ticket
    on $projection.RequestUuid = _Ticket.RequestUuid
{
    key request_uuid as RequestUuid,
    key family_uuid as FamilyUuid,
    family_seq as FamilySeq,
    selected as Selected,
    name as Name,
    gbdat as Birthdate,
    age as Age,
    passport_no as PassportNo,
    _Ticket // Make association public
}
