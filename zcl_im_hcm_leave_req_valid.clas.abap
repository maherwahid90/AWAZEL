class ZCL_IM_HCM_LEAVE_REQ_VALID definition
  public
  final
  create public .

public section.

  interfaces IF_EX_HRPAD00INFTY .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_HCM_LEAVE_REQ_VALID IMPLEMENTATION.


  method IF_EX_HRPAD00INFTY~AFTER_INPUT.
    data : i2001 type p2001,
          hiredate type begda,
          calc_date type datum.

    IF new_innnn-infty = '2001' and ( ipsyst-ioper = 'INS' or ipsyst-ioper = 'MOD' ).

    CALL METHOD CL_HR_PNNNN_TYPE_CAST=>prelp_to_pnnnn
      EXPORTING
        prelp =  new_innnn                " HR Master Data Buffer
      IMPORTING
        pnnnn = i2001
      .
  CALL FUNCTION 'RP_GET_HIRE_DATE'
    EXPORTING
      persnr                = i2001-pernr
      check_infotypes       = '0000'
*     DATUMSART             = '01'
*     STATUS2               = '3'
*     P0016_OPTIONEN        = ' '
   IMPORTING
     HIREDATE              = hiredate
            .
   AUTHORITY-CHECK OBJECT 'ZHCM_2001'
    ID 'ZHCM_2001' FIELD abap_true.
  IF sy-subrc <> 0.
*   Implement a suitable exception handling here
    DATA(NOT_AUTH) = 'X'.
  ENDIF.


IF i2001-subty = '1000' or i2001-subty = '1004'. "annual and Mariage Leaves

CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
  EXPORTING
    date            = hiredate
    days            = 0
    months          = 3
*   SIGNUM          = '+'
    years           = 0
 IMPORTING
   CALC_DATE       = calc_date
          .

IF i2001-begda < calc_date.
  sy-msgid = 'ZHCM_MSGS'.
  sy-msgno = '000'.
  sy-msgty = 'E'.
RAISE error_with_message.
ENDIF.

elseif i2001-subty = '1005'. " Haj Leave

CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
  EXPORTING
    date            = hiredate
    days            = 0
    months          = 0
*   SIGNUM          = '+'
    years           = 2
 IMPORTING
   CALC_DATE       = calc_date
          .
IF i2001-begda < calc_date AND not_auth = 'X'.
  sy-msgid = 'ZHCM_MSGS'.
  sy-msgno = '002'.
  sy-msgty = 'E'.
RAISE error_with_message.
ENDIF.

select SINGLE subty from pa2001 INto @data(subty) WHERE pernr = @i2001-pernr and subty = '1005'.
  IF sy-subrc eq 0.
      sy-msgid = 'ZHCM_MSGS'.
  sy-msgno = '001'.
  sy-msgty = 'E'.
RAISE error_with_message.

  ENDIF.

  elseif i2001-subty = '1011'."Exam Leave Validation
  SELECT SINGLE natio from pa0002 INTO @DATA(natio) WHERE pernr = @i2001-pernr AND begda <= @i2001-begda AND endda >= @i2001-begda.
    IF natio ne 'SA' and not_auth = 'X'.
sy-msgid = 'ZHCM_MSGS'.
  sy-msgno = '005'.
  sy-msgty = 'E'.
RAISE error_with_message.
    ENDIF.
ENDIF.


    ENDIF.
  endmethod.


  method IF_EX_HRPAD00INFTY~BEFORE_OUTPUT.
  endmethod.


  method IF_EX_HRPAD00INFTY~IN_UPDATE.
  endmethod.
ENDCLASS.
