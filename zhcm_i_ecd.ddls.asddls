
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Employee Communication Data'
@Metadata.ignorePropagatedAnnotations: true
define root view entity zhcm_i_ecd as select from zhcm_ecd_req
composition [0..*] of zhcm_i_ecd_attach as _Attachment
composition [0..*] of zhcm_i_ecd_approvals as _Approval
association [1] to zhcm_employee_help as EMP on EMP.pernr = zhcm_ecd_req.pernr
association [1] to zhcm_comm_type_view as comm_type_v on comm_type_v.Subty = zhcm_ecd_req.communication_type
association [1] to zhcm_req_status_view as req_st_v on req_st_v.DomvalueL = zhcm_ecd_req.req_status

{
    key request_uuid as RequestUuid,
    request_id as RequestId,
    pernr as Pernr,
    EMP.ename,
    EMP.PlansTxt,
    EMP.OrgehTxt,
    begda as Begda,
    communication_type as CommunicationType,
    comm_type_v.Itext as CommunicationTypeText,
    system_id as SystemId,
    remarks as Remarks,
    req_status as ReqStatus,
    req_st_v.Ddtext as ReqStatusText,
    case req_status when '1' then '2' when '2' then '3' when '4' then '3' when '3' then '1' when '5' then '1' else '0' end as statusCriticality,
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
    workitem_id,
    return_code,
    EMP,
    _Attachment, // Make association public
    _Approval
}
