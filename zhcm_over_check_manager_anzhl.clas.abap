CLASS zhcm_over_check_manager_anzhl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zhcm_over_check_manager_anzhl IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~calculate.
  CHECK NOT it_original_data is INITIAL.

DATA : lt_calculated_data TYPE STANDARD TABLE OF zhcm_i_over WITH DEFAULT KEY.

    MOVE-CORRESPONDING it_original_data TO lt_calculated_data.

    LOOP AT lt_calculated_data ASSIGNING FIELD-SYMBOL(<emp_wa>).
       SELECT SINGLE pernr,req_status from zhcm_overt_req into ( @data(request_pernr) ,@data(status) ) WHERE request_uuid = @<emp_wa>-RequestUuid.
        if sy-subrc eq 0.
        if status ne '01'.
        <emp_wa>-manager_anzhl_h = abap_true.
        return.
        ENDIF.
        SELECT SINGLE pa0105~usrid from pa0105 INNER join zhcm_emp_approv on pa0105~pernr = zhcm_emp_approv~approval_emp
        into @data(approval_user) WHERE pa0105~begda <= @sy-datum AND pa0105~endda >= @sy-datum AND pa0105~usrty = '0001'.
        if approval_user = sy-uname.
        <emp_wa>-manager_anzhl_h = abap_true.
         else.
        <emp_wa>-manager_anzhl_h = abap_false.
        ENDIF.
        else.
        <emp_wa>-manager_anzhl_h = abap_false.
        endif.
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
