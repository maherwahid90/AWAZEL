@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for Tickets Request Members'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_tkt_member as projection on zhcm_i_tkt_member
{
    key RequestUuid,
    key FamilySeq,
    Selected,
    Name,
    Birthdate,
    Age,
    PassportNo,

    /* Associations */
    _Ticket :redirected to parent zhcm_c_tkt
}
