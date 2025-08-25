@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Payroll Periods'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zhcm_v_emp_payroll_period as select from hrpy_rgdir
inner join pa0105 on pa0105.pernr = hrpy_rgdir.pernr 
inner join t247 on t247.mnr = substring(hrpy_rgdir.fpper,5,2) and t247.spras = $session.system_language

{
@EndUserText.label:'Period'
    key hrpy_rgdir.fpper,
    @EndUserText.label:'Month'
    t247.mnr,
    @EndUserText.label:'Month Name'
    t247.ltx,
    @EndUserText.label:'Year'
    substring(hrpy_rgdir.fpper,1,4) as year_no
} where pa0105.begda <= $session.system_date and pa0105.endda >= $session.system_date and hrpy_rgdir.payty = ''
 and pa0105.usrty = '0001' and pa0105.usrid = $session.user
