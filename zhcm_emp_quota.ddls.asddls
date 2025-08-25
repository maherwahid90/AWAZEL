@EndUserText.label: 'Employee Quota'
define table function ZHCM_EMP_Quota
with parameters i_pernr : pernr_d
returns {
  client : abap.clnt;
  pernr : pernr_d;
  entitle:hrptm_entitle;
  deduct:hrptm_deduct;
  pending_req:hrptm_entitle;
  rest:hrptm_rest;
  QUOTATEXT:hrqtext;
}
implemented by method zhcm_TF_class=>get_emp_quota;
