@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Old number Help View'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zhcm_old_umber as select from pa0105
inner join pa0001 on pa0001.pernr = pa0105.pernr
{
    key pa0105.pernr as Pernr,
    @EndUserText.label: 'Old Number'
    pa0105.usrid as Usrid,
    pa0001.ename
} where pa0105.begda <= $session.system_date and pa0105.endda >= $session.system_date and pa0105.subty = '0009' and
 pa0001.begda <= $session.system_date and pa0001.endda >= $session.system_date
