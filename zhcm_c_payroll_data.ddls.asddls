@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view of payroll data'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZHCM_c_PAYROLL_DATA as select from ZHCM_I_PAYROLL_DATA

{
    @ObjectModel.text.element:  [ 'ename' ] 
    key pernr,
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_v_emp_payroll_period', element : 'fpper' } }] 
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
