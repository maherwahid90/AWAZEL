CLASS zcl_virtual_element_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_virtual_element_calc IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~calculate.
  CHECK NOT it_original_data is INITIAL.

DATA : lt_calculated_data TYPE STANDARD TABLE OF zhcm_employee_help WITH DEFAULT KEY.

    MOVE-CORRESPONDING it_original_data TO lt_calculated_data.

    LOOP AT lt_calculated_data ASSIGNING FIELD-SYMBOL(<emp_wa>).
       CALL FUNCTION 'RP_GET_HIRE_DATE'
         EXPORTING
           persnr          =  <emp_wa>-pernr
           check_infotypes = '0000'
*           datumsart       = '01'
*           status2         = '3'
*           p0016_optionen  = ' '
         IMPORTING
           hiredate        = <emp_wa>-hiredate
         .
*******get quota for employee*********
DATA cmulatedv type table of BAPIHRQUOTACV.
call FUNCTION 'BAPI_TIMEQUOTA_GETDETAILEDLIST'
  EXPORTING
    employeenumber             =   <emp_wa>-pernr
*    quotaselectionmod          = '1'
*    wayofcalculation           = 'D'
*    keydateforentitle          =
*    keydatefordeduction        =

    deductbegin                = cl_abap_context_info=>get_system_date( )
    deductend                  =  cl_abap_context_info=>get_system_date( )
  TABLES
*    absencequotatypeselection  =
*    presencequotatypeselection =
*    absencequotareturntable    =
*    presencequotareturntable   =
*    return                     =
    cumulatedvalues            = cmulatedv
*    absencequotatransferpool   =
  .
  READ TABLE cmulatedv into DATA(cmulativ_Wa) WITH KEY quotatype = '01'.
  if sy-subrc eq 0.
  <emp_wa>-entitle = cmulativ_wa-entitle.
  <emp_wa>-deduct = cmulativ_wa-deduct.
  SELECT SUM( abwtg ) FROM zhcm_leave_req INTO @<EMP_WA>-pendingreq WHERE pernr = @<EMP_WA>-pernr AND AWART = '1000' AND req_status = 1.
  <emp_wa>-rest = cmulativ_wa-rest - <emp_wa>-pendingreq.
  ENDIF.
      FREE cmulatedv.
    CLEAR cmulativ_wa.
    ENDLOOP.

    MOVE-CORRESPONDING lt_calculated_data TO ct_calculated_data.

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
*  et_requested_orig_elements = VALUE #( BASE et_requested_orig_elements
*                                          ( CONV #( 'HIREDATE' ) )
*
*                                        ).
  ENDMETHOD.
ENDCLASS.
