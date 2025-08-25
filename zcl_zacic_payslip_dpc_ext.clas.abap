class ZCL_ZACIC_PAYSLIP_DPC_EXT definition
  public
  inheriting from ZCL_ZACIC_PAYSLIP_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_STREAM
    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZCL_ZACIC_PAYSLIP_DPC_EXT IMPLEMENTATION.


  method /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_STREAM.

DATA: fm_name           TYPE rs38l_fnam,      " CHAR 30 0 Name of Function Module
      fp_docparams      TYPE sfpdocparams,    " Structure  SFPDOCPARAMS Short Description  Form Parameters for Form Processing
      fp_outputparams   TYPE sfpoutputparams, " Structure  SFPOUTPUTPARAMS Short Description  Form Processing Output Parameter
      pdf_output TYPE FPFORMOUTPUT.

    DATA ls_lheader TYPE ihttpnvp.


READ TABLE IT_KEY_TAB INTO DATA(wa_key) WITH KEY NAME = 'docId'.
IF sy-subrc = 0.
DATA(docid) = wa_key-value.
ENDIF.


DATA:  SEQNR TYPE PC261-SEQNR,             " Vairable to store the sequence number.
       pernr TYPE pernr_d,
       HEADER TYPE  ZHCM_ACIC_PAYSLIP_H,
      ITEMS  TYPE  ZHCM_ACIC_PAYSLIP_ITEM_TT,
wagetypes type ZBAPIP0008P_TT.

seqnr = docid+0(5).
pernr = docid+5(8).

CALL FUNCTION 'ZHCM_ACIC_PAYSLIP_DATA'
  EXPORTING
    seqnr         = seqnr
    pernr         = pernr
 IMPORTING
   HEADER        = header
  TABLES
    items         = items
    wagetypes = wagetypes
          .

types:
begin of ty_s_media_resource,
mime_type type string,
value type xstring,
end of ty_s_media_resource.

*mime_type = 'application/pdf'.
DATA:ls_stream TYPE ty_s_media_resource.

fp_outputparams-nodialog = abap_true.
fp_outputparams-preview = abap_true.
fp_outputparams-getpdf = abap_true.


CALL FUNCTION 'FP_JOB_OPEN'                   "& Form Processing: Call Form
  CHANGING
    ie_outputparams = fp_outputparams
  EXCEPTIONS
    cancel          = 1
    usage_error     = 2
    system_error    = 3
    internal_error  = 4
    OTHERS          = 5.
IF sy-subrc <> 0.
*            <error handling>
ENDIF.
*&---- Get the name of the generated function module
CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'           "& Form Processing Generation
  EXPORTING
    i_name     = 'ZACIC_PAYSLIP'
  IMPORTING
    e_funcname = fm_name.
IF sy-subrc <> 0.
*  <error handling>
ENDIF.

* Language and country setting (here US as an example)
fp_docparams-langu   = 'E'.
fp_docparams-country = 'US'.
*&--- Call the generated function module

CALL FUNCTION fm_name
  EXPORTING
    /1bcdwb/docparams        = fp_docparams
    header                  = header
    items                   = items
wagetypes = wagetypes

    IMPORTING
     /1BCDWB/FORMOUTPUT       = pdf_output
  EXCEPTIONS
    usage_error           = 1
    system_error          = 2
    internal_error           = 3.
IF sy-subrc <> 0.
*  <error handling>
ENDIF.
*&---- Close the spool job
CALL FUNCTION 'FP_JOB_CLOSE'
*    IMPORTING
*     E_RESULT             =
  EXCEPTIONS
    usage_error           = 1
    system_error          = 2
    internal_error        = 3
    OTHERS               = 4.
IF sy-subrc <> 0.
*            <error handling>
ENDIF.

    ls_lheader-name = 'Content-Disposition'.
    ls_lheader-value = 'outline; filename="' && header-pernr &&'_payslip.pdf";'.
    set_header( is_header = ls_lheader ).

ls_stream-value = pdf_output-pdf.
ls_stream-mime_type = 'application/pdf'.

copy_data_to_ref(
  EXPORTING
    is_data = ls_stream
  CHANGING
    cr_data = er_stream
).

  endmethod.
ENDCLASS.
