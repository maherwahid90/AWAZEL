class ZCL_IM_HCM_IT08_VALIDATION definition
  public
  final
  create public .

public section.

  interfaces IF_EX_HRPAD00INFTY .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_HCM_IT08_VALIDATION IMPLEMENTATION.


  method IF_EX_HRPAD00INFTY~AFTER_INPUT.

      data : i0008 type p0008.

    IF new_innnn-infty = '0008' and ( ipsyst-ioper = 'INS' or ipsyst-ioper = 'MOD' ).

    CALL METHOD CL_HR_PNNNN_TYPE_CAST=>prelp_to_pnnnn
      EXPORTING
        prelp =  new_innnn                " HR Master Data Buffer
      IMPORTING
        pnnnn = i0008
      .

SELECT SINGLE famst FROM pa0002 INTO @DATA(famst) WHERE pernr = @i0008-pernr AND begda <= @i0008-begda AND endda >= @i0008-begda.
  IF famst = '0'.

  IF ( i0008-lga01 = '1001' AND i0008-bet01 < 750 ) or  ( i0008-lga02 = '1001' AND i0008-bet02 < 750 ) or  ( i0008-lga03 = '1001' AND i0008-bet03 < 750 ) or  ( i0008-lga04 = '1001' AND i0008-bet04 < 750 )
    or  ( i0008-lga05 = '1001' AND i0008-bet05 < 750 ) or  ( i0008-lga06 = '1001' AND i0008-bet06 < 750 ).
  sy-msgid = 'ZHCM_MSGS'.
  sy-msgno = '008'.
  sy-msgty = 'E'.
RAISE error_with_message.
  ENDIF.

    ELSEIF famst = '1'.
 IF ( i0008-lga01 = '1001' AND i0008-bet01 < 1167 ) or  ( i0008-lga02 = '1001' AND i0008-bet02 < 1167 ) or  ( i0008-lga03 = '1001' AND i0008-bet03 < 1167 ) or  ( i0008-lga04 = '1001' AND i0008-bet04 < 1167 )
    or  ( i0008-lga05 = '1001' AND i0008-bet05 < 1167 ) or  ( i0008-lga06 = '1001' AND i0008-bet06 < 1167 ).
  sy-msgid = 'ZHCM_MSGS'.
  sy-msgno = '009'.
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
