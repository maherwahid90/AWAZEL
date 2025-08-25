@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for LR Approvals'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_c_lr_approvals as projection on zhcm_i_lr_approvals
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
    _LR :redirected to parent zhcm_c_lr
}
