@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCM Payroll Data'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZHCM_I_PAYROLL_DATA as select from pa0001 as emp
inner join hrpy_rgdir as pay on emp.pernr = pay.pernr 
inner join pa0105 on emp.pernr = pa0105.pernr
association [1] to I_CompanyCode on I_CompanyCode.CompanyCode = emp.bukrs
association [1] to zhcm_v_emp_payroll_period as period on pay.fpper = period.fpper
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
} where emp.begda <= $session.system_date and emp.endda >= $session.system_date and pay.payty = '' and
pa0105.begda <= $session.system_date and pa0105.endda >= $session.system_date and pa0105.usrty = '0001' and pa0105.usrid = $session.user
