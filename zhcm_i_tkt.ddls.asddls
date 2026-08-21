
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Tickets Request'
@Metadata.ignorePropagatedAnnotations: true
define root view entity zhcm_i_tkt as select from zhcm_ticket_req
composition [0..*] of zhcm_i_tkt_attach as _Attachment
composition [0..*] of zhcm_i_tkt_member as _Member
composition [0..*] of zhcm_i_tkt_approvals as _Approval
association [1] to zhcm_employee_help as EMP on EMP.pernr = zhcm_ticket_req.pernr
association [1] to zhcm_ticket_type_view as tkt_type_v on tkt_type_v.DomvalueL = zhcm_ticket_req.ticket_type
association [1] to zhcm_req_status_view as req_st_v on req_st_v.DomvalueL = zhcm_ticket_req.req_status

{
    key request_uuid as RequestUuid,
    request_id as RequestId,
    pernr as Pernr,
    EMP.ename,
    EMP.PlansTxt,
    EMP.OrgehTxt,
    EMP.hiredate,
    ticket_type as TicketType,
    tkt_type_v.Ddtext as TicketTypeText,
    begda as Begda,
    endda as Endda,
    ticket_direction as TicketDirection,
    travel_destination as TravelDestination,
    journey_route as JourneyRoute,
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
    _Member,
    _Approval
}
