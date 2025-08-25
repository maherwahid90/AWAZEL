
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for LR Attachment'
//@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define view entity zhcm_c_lr_att  as projection on zhcm_i_lr_att
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
    _LR: redirected to parent zhcm_c_lr
}
