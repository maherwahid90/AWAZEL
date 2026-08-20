@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Request Family Members'
//@Metadata.ignorePropagatedAnnotations: true
define view entity zhcm_i_tkt_family as select from zhcm_tkt_family
association to parent zhcm_i_tkt as _Ticket
    on $projection.RequestUuid = _Ticket.RequestUuid
{
    key family_uuid as FamilyUuid,

    request_uuid as RequestUuid,
    first_name as FirstName,
    last_name as LastName,
    birthdate as Birthdate,
    age as Age,
    passport_no as PassportNo,
    source_subty as SourceSubty,
 @Semantics.user.createdBy: true
    local_created_by as LocalCreatedBy,
          @Semantics.systemDateTime.createdAt: true
    local_created_at as LocalCreatedAt,
     @Semantics.user.localInstanceLastChangedBy: true
    local_last_changed_by as LocalLastChangedBy,
    @Semantics.systemDateTime.localInstanceLastChangedAt: true
    local_last_changed_at as LocalLastChangedAt,
    //total ETag field
    @Semantics.systemDateTime.lastChangedAt: true
    last_changed_at as LastChangedAt,
    _Ticket // Make association public
}
