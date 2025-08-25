*&---------------------------------------------------------------------*
*& Include          ZHCM_TIME_SHEET_UPLOAD_F01
*&---------------------------------------------------------------------*
form process_data.




CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
EXPORTING
  I_LINE_HEADER = 'X'
I_TAB_RAW_DATA = IT_RAW
I_FILENAME = S_FILE
TABLES
I_TAB_CONVERTED_DATA = IT
EXCEPTIONS
CONVERSION_FAILED = 1
OTHERS = 2.

IF SY-SUBRC <> 0.
MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
ENDIF.

LOOP AT IT INTO DATA(WA).
  MOVE-CORRESPONDING wa to alv_wa.
hours = floor( ( wa-ltime * 86400 ) / 3600 ).
minutes = floor( ( ( wa-ltime * 86400 ) mod 3600 ) / 60 ).
seconds = ( wa-ltime * 86400 ) mod 60.
alv_wa-sap_ltime = hours && minutes &&  seconds.
alv_wa-ltime = hours && ':' && minutes && ':' && seconds.
CONCATENATE wa-begda+6(4) wa-begda+3(2) wa-begda+0(2) INTO alv_wa-sap_begda.
select SINGLE pernr FROM pa0050 into alv_wa-sap_pernr where zausw EQ wa-pernr AND begda <= alv_wa-sap_begda AND endda >= alv_Wa-sap_begda.
  IF sy-subrc ne 0.
  alv_wa-remarks = 'The finger print employee number not mapped in infotype 50'.
  APPEND alv_wa to alv_it.
  clear alv_wa.
  CONTINUE.
  ENDIF.

  select SINGLE ZTERF FROM pa0007 into @DATA(ZTERF) where PERNR = @ALV_WA-sap_PERNR AND begda <= @alv_wa-sap_begda AND endda >= @alv_Wa-sap_begda AND ZTERF NE 0.
  IF sy-subrc ne 0.
  alv_wa-remarks = 'No time accounts maintained in infotype 7'.
  APPEND alv_wa to alv_it.
  clear alv_wa.
  CONTINUE.
  ENDIF.

wa_2011-pernr = alv_wa-sap_pernr.
wa_2011-begda = wa_2011-endda = alv_wa-sap_begda.
wa_2011-ltime = alv_wa-sap_ltime.
wa_2011-satza = alv_wa-satza.
  CALL FUNCTION 'BAPI_EMPLOYEE_ENQUEUE'
    EXPORTING
      number = wa_2011-pernr
    IMPORTING
      return = return.

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
  alv_wa-remarks = return-message.
  else.
    alv_wa-remarks = 'Record saved successfully'.

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



APPEND alv_Wa to alv_it.
  CLEAR: wa_2011,alv_wa.

*BREAK-POINT.

ENDLOOP.


  ENDFORM.

  FORM build_fcat .
w_layout-colwidth_optimize = 'X'.

  PERFORM build_fcatalog USING:
           'PERNR' '' 'Finger Print Employee No' 'X',
           'BEGDA' '' 'Finger Print Date' 'X',
           'LTIME' '' 'Finger Print Time' 'X',
           'SATZA' '' 'Finger Print Type' 'X',
           'ZTERM' 'VBRK' 'Payment Terms' 'X',
           'SAP_PERNR' '' 'SAP Employee No.' '',
           'SAP_BEGDA' '' 'SAP Date' '',
           'SAP_LTIME' '' 'SAP Time' '',
           'REMARKS' '' 'Posting Status' ''.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  BUILD_FCATALOG
*&---------------------------------------------------------------------*
FORM build_fcatalog USING l_field l_tab l_text L_KEY.

  w_fieldcat-fieldname      = l_field.
  if l_tab is NOT INITIAL.
  w_fieldcat-tabname        = l_tab.
  ENDIF.
  w_fieldcat-seltext_m      = l_text.
  w_fieldcat-key      = l_KEY.

  APPEND w_fieldcat TO i_fieldcat.
  CLEAR w_fieldcat.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form ALV_DISPLAY
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM alv_display .
 CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = SY-REPID
      is_layout          = w_layout
      it_fieldcat        = i_fieldcat

    TABLES
      t_outtab           = alv_it
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
ENDFORM.
