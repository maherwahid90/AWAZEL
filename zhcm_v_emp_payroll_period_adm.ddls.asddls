@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Payroll Periods'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZHCM_V_EMP_PAYROLL_PERIOD_adm as select distinct from hrpy_rgdir 
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
} where hrpy_rgdir.payty = '' 
 
