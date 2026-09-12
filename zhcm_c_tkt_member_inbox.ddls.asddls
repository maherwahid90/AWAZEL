@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for Tickets Req Members'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZHCM_C_TKT_MEMBER_INBOX as projection on zhcm_i_tkt_member
{
    key FamilyUuid,
    RequestUuid,
    FamilySeq,
    Selected,
    Name,
    Birthdate,
    Age,
    PassportNo,

    /* Associations */
    _Ticket :redirected to parent zhcm_c_tkt_INBOX
}
