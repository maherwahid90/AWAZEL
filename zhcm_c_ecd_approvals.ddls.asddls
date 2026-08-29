@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Employee Communication Data Approvals'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_ecd_approvals as projection on zhcm_i_ecd_approvals
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
    _Ecd :redirected to parent zhcm_c_ecd
}
