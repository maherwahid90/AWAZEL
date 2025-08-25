@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Attachment Intervace View'
//@Metadata.ignorePropagatedAnnotations: true
define view entity zhcm_i_lr_att as select from zhcm_lr_attach
association to parent zhcm_i_lr as _LR
    on $projection.RequestUuid = _LR.RequestUuid
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
    _LR // Make association public
}
