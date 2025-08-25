@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view of payroll data'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZHCM_C_PAYROLL_DATA_adm as select from ZHCM_I_PAYROLL_DATA_adm

{
    @ObjectModel.text.element:  [ 'ename' ] 
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_employee_help', element : 'pernr' } }] 
    key pernr,
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_v_emp_payroll_period_adm', element : 'fpper' } }] 
    key fpper,
    key seqnr,
     @Semantics.text: true
    ename,
     @ObjectModel.text.element:  [ 'companyName' ] 
     @Consumption.valueHelpDefinition: [{ entity: { name : 'I_CompanyCode', element : 'CompanyCode' } }] 
    bukrs,
    @Semantics.text: true
    companyName,
    @ObjectModel.text.element:  [ 'monthName' ] 
    month_no,
    @Semantics.text: true
    monthName,
    year_no,
    ShowPDF,
    LinkToPdf
}
