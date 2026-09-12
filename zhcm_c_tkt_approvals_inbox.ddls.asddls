@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Approvals'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZHCM_C_TKT_APPROVALS_INBOX as projection on zhcm_i_tkt_approvals
{
    key RequestUuid,
    key ApprovalSeq,
    @ObjectModel.text.element:  [ 'ApprovalName' ]
    ApprovalPernr,
    @Semantics.text: true
    ApprovalName,
    ReceiveTs,
    CompleteTs,
    Status,
    StatusCrit,
    ApprovalComment,

    /* Associations */
    _Ticket :redirected to parent zhcm_c_tkt_INBOX
}
