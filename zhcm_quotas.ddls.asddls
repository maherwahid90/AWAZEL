@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCM Quotas'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zhcm_quotas as select from t556b
{
    key sprsl as Sprsl,
    key mopgk as Mopgk,
    key mozko as Mozko,
    @ObjectModel.text.element: ['Ktext']
    key ktart as Ktart,
    @Semantics.text: true
    ktext as Ktext
} where sprsl = $session.system_language and mopgk = '2'  and mozko = '90'
