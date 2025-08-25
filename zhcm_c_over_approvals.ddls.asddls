@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Approvals'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_OVER_approvals as projection on zhcm_i_OVER_approvals
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
    _OVER :redirected to parent zhcm_c_OVER
}
