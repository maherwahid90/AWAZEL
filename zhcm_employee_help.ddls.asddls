@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Help View'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zhcm_employee_help as select from pa0001
inner join pa0002 on pa0001.pernr = pa0002.pernr
inner join t500p on t500p.persa = pa0001.werks
association [1] to I_CompanyCode on I_CompanyCode.CompanyCode = pa0001.bukrs
association[1] to hrp1000 as plans_txt on plans_txt.objid = pa0001.plans and plans_txt.otype = 'S'
and plans_txt.begda <= $session.system_date and plans_txt.endda >= $session.system_date
association[1] to hrp1000 as orgeh_txt on orgeh_txt.objid = pa0001.orgeh and orgeh_txt.otype = 'O'
and orgeh_txt.begda <= $session.system_date and orgeh_txt.endda >= $session.system_date
{
@ObjectModel.text.element:  [ 'ename' ] 
    key pa0001.pernr,
    @Semantics.text: true
    pa0001.ename,
    @ObjectModel.text.element:  [ 'CompanyCodeName' ] 
     @Consumption.valueHelpDefinition: [{ entity: { name : 'I_CompanyCode', element : 'CompanyCode' } }] 
    pa0001.bukrs,
    @Semantics.text: true
    I_CompanyCode.CompanyCodeName,
    @ObjectModel.text.element:  [ 'name1' ] 
    //@Consumption.valueHelpDefinition: [{ entity: { name : 't500p', element : 'persa' } }] 
    pa0001.werks,
    @Semantics.text: true
    t500p.name1,
    pa0001.btrtl,
    pa0001.persg,
    pa0001.persk,
    @ObjectModel.text.element: [ 'OrgehTxt' ]
    pa0001.orgeh,
    @Semantics.text: true
    orgeh_txt.stext as OrgehTxt,
    @ObjectModel.text.element: [ 'PlansTxt' ]
    pa0001.plans,
    @Semantics.text: true
    @EndUserText.label: 'Position Name'
    plans_txt.stext as PlansTxt,
    pa0002.gesch,
   // pa0002.gbdat,
    pa0002.natio,
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VIRTUAL_ELEMENT_CALC'
      @EndUserText.label: 'Hire Date'
      @ObjectModel.virtualElement: true
      cast('' as abap.dats) as hiredate,
      
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VIRTUAL_ELEMENT_CALC'
      @EndUserText.label: 'Quota'
      @ObjectModel.virtualElement: true
      @UI.hidden: true
      cast(0 as abap.dec( 10, 2 )) as ENTITLE,
      
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VIRTUAL_ELEMENT_CALC'
      @EndUserText.label: 'Quota Deducted'
      @ObjectModel.virtualElement: true
      @UI.hidden: true
      cast(0 as abap.dec( 10, 2 )) as DEDUCT,
      
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VIRTUAL_ELEMENT_CALC'
      @EndUserText.label: 'Pending Requests'
      @ObjectModel.virtualElement: true
      @UI.hidden: true
      cast(0 as abap.dec( 10, 2 )) as PENDINGREQ,
      
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VIRTUAL_ELEMENT_CALC'
      @EndUserText.label: 'Rest Of Balance'
      @ObjectModel.virtualElement: true
      @UI.hidden: true
      cast(0 as abap.dec( 10, 2 )) as REST
}where pa0001.begda <= $session.system_date and pa0001.endda >= $session.system_date and 
pa0002.begda <= $session.system_date and pa0002.endda >= $session.system_date
