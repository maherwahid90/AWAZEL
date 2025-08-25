@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for LR'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true 
@Search.searchable: true
define root view entity zhcm_c_lr provider contract transactional_query as projection on zhcm_i_lr
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
    entitle,
    deduct,
    pendingreq,
    rest,
    
    @ObjectModel.text.element:  [ 'Atext' ] 
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_absence_types_cds', element : 'awart' } }]
    Awart,
    @Semantics.text: true
    Atext,
    Begda,
    Endda,
    Abwtg,
    Kaltg,
    @ObjectModel.text.element:  [ 'SubtEmpName' ] 
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_employee_help', element : 'pernr' } }]
    SubtEmp,
    @Semantics.text: true
    SubtEmpName,
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
    _Attachment:redirected to composition child zhcm_c_lr_att,
    _Approval:redirected to composition child zhcm_c_lr_approvals
} where LocalCreatedBy = $session.user
