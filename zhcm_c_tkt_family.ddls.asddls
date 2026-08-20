@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for Tickets Request Family Members'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_tkt_family as projection on zhcm_i_tkt_family
{
    key FamilyUuid,
    RequestUuid,
    FirstName,
    LastName,
    Birthdate,
    Age,
    PassportNo,
    SourceSubty,
    LocalCreatedBy,
    LocalCreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt,

    /* Associations */
    _Ticket :redirected to parent zhcm_c_tkt
}
