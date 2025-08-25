@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Absence types'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
    
}
define view entity zhcm_absence_types_cds as select from t554t inner join t554s on
t554s.moabw = t554t.moabw and t554s.subty = t554t.awart
{
@EndUserText.label: 'Leave Type'
@ObjectModel.text.element:  [ 'atext' ] 
   key t554t.awart,
   @EndUserText.label: 'Leave Type text'
   @Semantics.text: true
   t554t.atext 
}where t554s.moabw = '90' and t554t.sprsl = $session.system_language 
and t554s.begda <= $session.system_date and t554s.endda >= $session.system_date and 
( t554s.dynnr = '2000' or t554s.dynnr = '2001' )
