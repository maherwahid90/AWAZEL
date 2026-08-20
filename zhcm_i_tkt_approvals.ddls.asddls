@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Request Approvals'
//@Metadata.ignorePropagatedAnnotations: true

define view entity zhcm_i_tkt_approvals as select from zhcm_tkt_approv
association to parent zhcm_i_tkt as _Ticket
    on $projection.RequestUuid = _Ticket.RequestUuid
{
    key request_uuid as RequestUuid,
    key approval_seq as ApprovalSeq,
    approval_pernr as ApprovalPernr,
    approval_name as ApprovalName,
    receive_ts as ReceiveTs,
    complete_ts as CompleteTs,
    status as Status,
    case status when 'APPROVED' then 3 when 'REJECTED' then 1 else 5 end as StatusCrit,
    approval_comment as ApprovalComment,
    _Ticket
}
