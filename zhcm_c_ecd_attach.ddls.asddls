@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Employee Communication Data Attachments'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_ecd_attach as projection on zhcm_i_ecd_attach
{
    key AttachmentUuid,
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
    _Ecd :redirected to parent zhcm_c_ecd
}
