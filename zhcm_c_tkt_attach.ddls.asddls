@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Attachments'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_tkt_attach as projection on zhcm_i_tkt_attach
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
    _Ticket :redirected to parent zhcm_c_tkt
}
