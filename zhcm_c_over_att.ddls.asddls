
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for  Attachment'
//@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define view entity zhcm_c_OVER_att  as projection on zhcm_i_over_att
{
    key AttachmentUuid,
    @Search.defaultSearchElement: true
  
    RequestUuid,
    Attachment,
    Mimetype,
    Filename,
    Comments,
    LocalCreatedBy,
    LocalCreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt,
    /* Associations */
    _OVER: redirected to parent zhcm_c_OVER
}
