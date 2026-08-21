@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Request Attachments'
//@Metadata.ignorePropagatedAnnotations: true
define view entity zhcm_i_tkt_attach as select from zhcm_tick_attach
association to parent zhcm_i_tkt as _Ticket
    on $projection.RequestUuid = _Ticket.RequestUuid
{
    key attachment_uuid as AttachmentUuid,

    request_uuid as RequestUuid,
@Semantics.largeObject:
{ mimeType: 'Mimetype',
  fileName: 'Filename',
  contentDispositionPreference: #INLINE }
    attachment as Attachment,
    @Semantics.mimeType: true
    mimetype as Mimetype,
    filename as Filename,
    comments as Comments,
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
