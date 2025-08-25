@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCM Leave Balance Items'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zhcm_i_leave_balance_it as select from ptquoded
  inner join pa2001 on pa2001.pernr = ptquoded.pernr and pa2001.begda <= ptquoded.datum and pa2001.endda >= ptquoded.datum

  association [1] to zhcm_absence_types_cds as absences on absences.awart = pa2001.awart
{
    key ptquoded.quonr as Quonr,
    key ptquoded.docnr as Docnr,
    key ptquoded.datum as Datum,
    ptquoded.pernr as Pernr,
    @ObjectModel.text.element: ['atext']
    pa2001.awart,
    @Semantics.text: true
    absences.atext
}
