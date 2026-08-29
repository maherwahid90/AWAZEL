@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for Employee Communication Data'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity zhcm_c_ecd provider contract transactional_query as projection on zhcm_i_ecd
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
    Begda,

    @ObjectModel.text.element:  [ 'CommunicationTypeText' ]
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_comm_type_view', element : 'Subty' } }]
    CommunicationType,
    @Semantics.text: true
    CommunicationTypeText,
    SystemId,
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
    _Attachment:redirected to composition child zhcm_c_ecd_attach,
    _Approval:redirected to composition child zhcm_c_ecd_approvals
} where LocalCreatedBy = $session.user
