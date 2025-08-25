*&---------------------------------------------------------------------*
*& Include          ZHCM_TIME_MACHINE_F01
*&---------------------------------------------------------------------*
FORM GET_TIME_DATA.
SELECT * FROM zhcm_timem_data INTO TABLE time_it WHERE msg_type = 'E'.
  ENDFORM.
*&---------------------------------------------------------------------*
*& Form POST_TIME
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM post_time .
LOOP AT TIME_IT ASSIGNING FIELD-SYMBOL(<TIME_WA>).

DATA(LDATE_ST) = <time_wa>-punch_time+0(10).
REPLACE ALL OCCURRENCES OF '-' IN LDATE_ST WITH '' .

LTIME_ST = <time_wa>-punch_time+11(8).
REPLACE ALL OCCURRENCES OF ':' IN LTIME_ST WITH '' .

<TIME_WA>-LDATE = ldate_st.
<TIME_WA>-LTIME = lTIME_st.
IF <TIME_WA>-punch_state = '0'.
<TIME_WA>-retyp = 'P10'.
ELSEIF <TIME_WA>-punch_state = '1'.
<TIME_WA>-retyp = 'P20'.
ENDIF.

select SINGLE pernr FROM pa0050 into <TIME_WA>-sap_pernr where zausw EQ <time_wa>-emp_code AND begda <= <TIME_WA>-LDATE AND endda >= <TIME_WA>-LDATE.
  IF sy-subrc ne 0.
  <TIME_wA>-message = 'The finger print employee number not mapped in infotype 50'.
  <TIME_WA>-msg_type = 'E'.
  CONTINUE.
  ENDIF.

  select SINGLE ZTERF FROM pa0007 into @DATA(ZTERF) where PERNR = @<TIME_WA>-sap_PERNR AND begda <= @<TIME_WA>-LDATE AND endda >= @<TIME_WA>-LDATE AND ZTERF NE 0.
  IF sy-subrc ne 0.
  <TIME_wA>-message = 'No time accounts maintained in infotype 7'.
  <TIME_WA>-msg_type = 'E'.
  CONTINUE.
  ENDIF.

wa_2011-pernr = <TIME_WA>-sap_pernr.
wa_2011-begda = wa_2011-endda = <TIME_WA>-LDATE.
wa_2011-ltime = <TIME_WA>-ltime.
wa_2011-satza = <TIME_WA>-retyp.
  CALL FUNCTION 'BAPI_EMPLOYEE_ENQUEUE'
    EXPORTING
      number = wa_2011-pernr
    IMPORTING
      return = return.
  IF RETURN-type = 'E'.
  MOVE-CORRESPONDING RETURN TO <TIME_WA>.
  ENDIF.

  CALL FUNCTION 'HR_INFOTYPE_OPERATION'
    EXPORTING
      infty     = '2011'
      number    = wa_2011-pernr
*     SUBTYPE   =
*     OBJECTID  =
*     LOCKINDICATOR          =
*     VALIDITYEND            = WA_2011-ENDDA
*     VALIDITYBEGIN          = WA_2011-BEGDA
*     RECORDNUMBER           =
      record    = wa_2011
      operation = 'INS'
*     TCLAS     = 'A'
*     DIALOG_MODE            = '0'
*     NOCOMMIT  =
*     VIEW_IDENTIFIER        =
*     SECONDARY_RECORD       =
    IMPORTING
      return    = return.

if return-type = 'E'.
  MOVE-CORRESPONDING RETURN TO <TIME_WA>.
  else.
    <TIME_WA>-MESSAGE = 'Record saved successfully'.
<TIME_WA>-MSG_TYPE = 'S'.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
     EXPORTING
       WAIT          = 'X'
*     IMPORTING
*       RETURN        =
              .

  ENDIF.

  CALL FUNCTION 'BAPI_EMPLOYEE_DEQUEUE'
    EXPORTING
      number = wa_2011-pernr
    IMPORTING
      return = return.

  CLEAR: wa_2011.

*BREAK-POINT.

ENDLOOP.

MODIFY ZHCM_TIMEM_DATA FROM TABLE TIME_IT.
  COMMIT WORK AND WAIT.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SEND_ERROR_NOTIFICATION
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM send_error_notification .
READ TABLE time_it INTO time_wa WITH KEY msg_type = 'E'.
  IF sy-subrc = 0 .

DATA:
      html_it TYPE SOLI_TAB,
      lv_html_body like LINE OF html_it.

    CONCATENATE '<html><body>'
                '<p>Hello,</p>'
                '<p>Kindly find the below errors when trying pull time machine data:'
                      '</p>'
                '<table border="1">'
                '<tr><th>Time Machine Emp Code </th><th>SAP Emp Code</th> <th>Punch Time </th><th>Error</th></tr>'
                INTO lv_html_body-line.
    APPEND lv_html_body to html_it.
    CLEAR lv_html_body.

    LOOP AT time_it INTO time_wa WHERE msg_type = 'E'.
      CONCATENATE lv_html_body
                  '<tr><td>' time_wa-emp_code '</td>'
                  '<td>' time_wa-sap_pernr '</td>'
                  '<td>' time_wa-punch_time '</td>'
                  '<td>' time_wa-message '</td>'
                  '</tr>'
                  INTO lv_html_body-line.
      APPEND lv_html_body to html_it.
    CLEAR lv_html_body.
    ENDLOOP.

    CONCATENATE lv_html_body
                '</table>'
                '<p>Regards,<br>SAP System</p>'
                '</body></html>'
                INTO lv_html_body-line.
    APPEND lv_html_body to html_it.
    CLEAR lv_html_body.

        DATA: lo_send_request TYPE REF TO cl_bcs,
          lo_document     TYPE REF TO cl_document_bcs,
          lo_recipient    TYPE REF TO if_recipient_bcs,
          lv_subject      TYPE so_obj_des.

    TRY.
        lo_send_request = cl_bcs=>create_persistent( ).

        lv_subject = 'Error Log for Finger Print Integration'.
        lo_document = cl_document_bcs=>create_document(
            i_type    = 'HTM'
            i_text    = html_it
            i_subject = lv_subject ).

        lo_send_request->set_document( lo_document ).

        lo_recipient = cl_cam_address_bcs=>create_internet_address( 'eng.maherwahid@gmail.com' ).
        lo_send_request->add_recipient( lo_recipient ).

        lo_send_request->set_send_immediately( abap_true ).
        lo_send_request->send( ).

        COMMIT WORK.

      CATCH cx_bcs INTO DATA(lx_bcs).
        " Handle error
*        MESSAGE lx_bcs->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDIF.
ENDFORM.
