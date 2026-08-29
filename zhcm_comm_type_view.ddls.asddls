@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Communication Type (PA0105 subtypes)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #S
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zhcm_comm_type_view as select from t591s
{
@ObjectModel.text.element:  [ 'Itext' ]
    key subty as Subty,
@Semantics.text: true
    itext as Itext

} where sprsl = $session.system_language and infty = '0105'
