@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCM Payroll Data'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZHCM_I_PAYROLL_DATA_adm as select from zhcm_employee_help as emp
inner join hrpy_rgdir as pay on emp.pernr = pay.pernr 
association [1] to I_CompanyCode on I_CompanyCode.CompanyCode = emp.bukrs
association [1] to ZHCM_V_EMP_PAYROLL_PERIOD_adm as period on pay.fpper = period.fpper
{
    key emp.pernr,
    key pay.fpper,
    key pay.seqnr,
    emp.ename,
    emp.bukrs,
    I_CompanyCode.CompanyCodeName as companyName,
    period.mnr as month_no, 
    period.ltx as monthName,
    period.year_no,
    'Payslip' as ShowPDF,
concat('/sap/opu/odata/sap/ZACIC_PAYSLIP_SRV/PAYSLIPSet(''',concat(concat(pay.seqnr,pay.pernr), ''')/$value')) as LinkToPdf 
}  
