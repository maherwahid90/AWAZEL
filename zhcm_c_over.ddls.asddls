@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for LR'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity zhcm_c_OVER
  provider contract transactional_query
  as projection on zhcm_i_over
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
      Begda,
      emp_anzhl,
      manger_anzhl,
      manager_anzhl_h,
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
      _Attachment : redirected to composition child zhcm_c_OVER_att,
      _Approval   : redirected to composition child zhcm_c_OVER_approvals
}
where
  LocalCreatedBy = $session.user
