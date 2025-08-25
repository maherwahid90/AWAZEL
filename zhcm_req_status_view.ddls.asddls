@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Request Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zhcm_req_status_view as select from dd07t
{
@ObjectModel.text.element:  [ 'Ddtext' ] 
    key domvalue_l as DomvalueL,
@Semantics.text: true
    ddtext as Ddtext
    
} where ddlanguage = $session.system_language and domname = 'ZHCM_REQ_STATUS'
