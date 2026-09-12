@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for Tickets Request'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZHCM_C_TKT_INBOX provider contract transactional_query as projection on zhcm_i_tkt
{
    key RequestUuid,
    @Search.defaultSearchElement: true
    RequestId,
    @Search.defaultSearchElement: true
    @ObjectModel.text.element: ['ename']
    Pernr,
    @Semantics.text: true
    ename,
    PlansTxt,
    OrgehTxt,
    hiredate,

    @ObjectModel.text.element:  [ 'TicketTypeText' ]
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_ticket_type_view', element : 'DomvalueL' } }]
    TicketType,
    @Semantics.text: true
    TicketTypeText,
    Begda,
    Endda,
    TicketDirection,
    TravelDestination,
    JourneyRoute,
    Remarks,
    @ObjectModel.text.element:  [ 'ReqStatusText' ]
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_req_status_view', element : 'DomvalueL' } }]
    ReqStatus,
    @Semantics.text: true
    ReqStatusText,
    statusCriticality,
    LocalCreatedBy,
    LocalCreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt,
    /* Associations */
    _Attachment:redirected to composition child zhcm_c_tkt_attach_INBOX,
    _Member:redirected to composition child zhcm_c_tkt_member_INBOX,
    _Approval:redirected to composition child zhcm_c_tkt_approvals_INBOX
}
