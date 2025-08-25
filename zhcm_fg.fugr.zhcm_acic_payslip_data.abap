FUNCTION ZHCM_ACIC_PAYSLIP_DATA.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(SEQNR) TYPE  CDSEQ
*"     REFERENCE(PERNR) TYPE  PERNR_D
*"  EXPORTING
*"     REFERENCE(HEADER) TYPE  ZHCM_ACIC_PAYSLIP_H
*"  TABLES
*"      ITEMS TYPE  ZHCM_ACIC_PAYSLIP_ITEM_TT
*"      WAGETYPES TYPE  ZBAPIP0008P_TT OPTIONAL
*"----------------------------------------------------------------------
DATA: ST_PAYRESULT TYPE paysa_result,    " Deep structure type for importing Payroll results from the cluster
       WA_RT TYPE PC207,
       wa like LINE OF items,
       langu like sy-langu.
DATA : relid TYPE relid_pcl,
          molga TYPE molga.

IF SY-LANGU = 'E'.
  LANGU = 'A'.
  ELSEIF SY-LANGU = 'A'.
    LANGU = 'E'.

ENDIF.

* Get the area identifier for cluster
  CALL FUNCTION 'PYXX_GET_RELID_FROM_PERNR'
    EXPORTING
      employee = pernr
    IMPORTING
      relid    = relid
      molga    = molga.

** Once if you are ready with the Sequence number for a particular employee call the FM to import Payroll results into Deep structure ( ST_PAYRESULT).
  CALL FUNCTION 'PYXX_READ_PAYROLL_RESULT'
    EXPORTING
     CLUSTERID                          = relid
      EMPLOYEENUMBER                     = PERNR
      SEQUENCENUMBER                     = SEQNR
    CHANGING
      PAYROLL_RESULT                     = ST_PAYRESULT
   EXCEPTIONS
     ILLEGAL_ISOCODE_OR_CLUSTERID       = 1
     ERROR_GENERATING_IMPORT            = 2
     IMPORT_MISMATCH_ERROR              = 3
     SUBPOOL_DIR_FULL                   = 4
     NO_READ_AUTHORITY                  = 5
     NO_RECORD_FOUND                    = 6
     VERSIONS_DO_NOT_MATCH              = 7
     ERROR_READING_ARCHIVE              = 8
     ERROR_READING_RELID                = 9
     OTHERS                             = 10
            .
  IF SY-SUBRC <> 0.
    MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
            WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.




  select t512w~lgart, b~betrg FROM t512w
    INNER join @ST_PAYRESULT-INTER-RT as b on  t512w~lgart = b~lgart
    WHERE begda <= @sy-datum
    AND endda >= @sy-datum AND SUBSTRING( aklas,3,2 ) = '07'
    AND t512w~molga = '24' and b~betrg ne 0 ORDER BY t512w~lgart
    INTO TABLE @DATA(earning_it).


  select t512w~lgart, b~betrg FROM t512w
    INNER join @ST_PAYRESULT-INTER-RT as b on  t512w~lgart = b~lgart
    WHERE begda <= @sy-datum
    AND endda >= @sy-datum AND SUBSTRING( aklas,3,2 ) = '09'
    AND t512w~molga = '24' and b~betrg ne 0 ORDER BY t512w~lgart
    INTO TABLE @DATA(deduction_it).

IF lines( earning_it ) >= lines( deduction_it ).
  LOOP AT earning_it INTO DATA(eArning_wa).
   wa-e_lgart = eArning_wa-lgart.
   wa-e_betrg = abs( eArning_wa-betrg ).
   HEADER-gross_amt += abs( earning_wa-BETRG ).
   SELECT SINGLE lgtxt FROM t512t INTO @wa-e_lg_name WHERE molga = '24' AND
     lgart = @earning_wa-lgart AND sprsl = @sy-langu.
     IF sy-subrc ne 0  .
         SELECT SINGLE lgtxt FROM t512t INTO @wa-e_lg_name WHERE molga = '24' AND
     lgart = @earning_wa-lgart AND sprsl = @LANGU.

     ENDIF.

     READ TABLE deduction_it INTO DATA(deduction_wa) INDEX sy-tabix.
     IF sy-subrc eq 0.

     wa-d_lgart = deduction_wa-lgart.
   wa-d_betrg = abs( deduction_wa-betrg ).
   SELECT SINGLE lgtxt FROM t512t INTO @wa-d_lg_name WHERE molga = '24' AND
     lgart = @deduction_wa-lgart AND sprsl = @sy-langu.
     IF sy-subrc ne 0 .
         SELECT SINGLE lgtxt FROM t512t INTO @wa-d_lg_name WHERE molga = '24' AND
     lgart = @earning_wa-lgart AND sprsl = @LANGU.

     ENDIF.
     HEADER-total_deduction += abs( deduction_wa-BETRG ).
     ENDIF.
     append wa to items.
     clear wa.
  ENDLOOP.
  else.
LOOP AT DEDUCTION_it INTO DEDUCTION_WA.
       wa-d_lgart = deduction_wa-lgart.
   wa-d_betrg = abs( deduction_wa-betrg ).
   SELECT SINGLE lgtxt FROM t512t INTO @wa-d_lg_name WHERE molga = '24' AND
     lgart = @deduction_wa-lgart AND sprsl = @sy-langu.
     IF sy-subrc ne 0 .
         SELECT SINGLE lgtxt FROM t512t INTO @wa-d_lg_name WHERE molga = '24' AND
     lgart = @earning_wa-lgart AND sprsl = @LANGU.

     ENDIF.
     HEADER-total_deduction += abs( deduction_wa-BETRG ).


     READ TABLE EARNING_it INTO EARNING_wa INDEX sy-tabix.
     IF sy-subrc eq 0.
wa-e_lgart = eArning_wa-lgart.
   wa-e_betrg = abs( eArning_wa-betrg ).
   HEADER-gross_amt += abs( earning_wa-BETRG ).
   SELECT SINGLE lgtxt FROM t512t INTO @wa-e_lg_name WHERE molga = '24' AND
     lgart = @earning_wa-lgart AND sprsl = @sy-langu.
     IF sy-subrc ne 0  .
         SELECT SINGLE lgtxt FROM t512t INTO @wa-e_lg_name WHERE molga = '24' AND
     lgart = @earning_wa-lgart AND sprsl = @LANGU.

     ENDIF.

     ENDIF.
     append wa to items.
     clear wa.
  ENDLOOP.
ENDIF.

READ TABLE ST_PAYRESULT-inter-RT INTO WA_RT WITH KEY lgart = '/560'.
IF SY-SUBRC = 0.
  HEADER-net_amount = abs( WA_RT-betrg ).
ENDIF.

SELECT SINGLE pernr, PLANS , ENAME , BUKRS FROM PA0001 INTO CORRESPONDING FIELDS OF @HEADER
  WHERE PERNR = @PERNR AND BEGDA <= @SY-DATUM AND ENDDA >= @SY-DATUM.

  SELECT SINGLE BUTXT FROM T001 INTO @HEADER-butxt WHERE BUKRS = @HEADER-BUKRS AND spras = @SY-LANGU.

    SELECT SINGLE STEXT FROM HRP1000 INTO @HEADER-STEXT WHERE otype = 'S'
      AND OBJID = @HEADER-PLANS AND BEGDA <= @SY-DATUM AND ENDDA >= @SY-DATUM.

      SELECT SINGLE FPPER , FPEND FROM HRPY_RGDIR INTO (@DATA(FPPER),@data(FPEND)) WHERE PERNR = @PERNR AND SEQNR = @SEQNR.
        IF SY-SUBRC = 0.
          HEADER-MONTH = FPPER+4(2).
          HEADER-YEAR = FPPER+0(4).

        ENDIF.
        SELECT SINGLE * from pa0008 INTO @DATA(wa_0008) where pernr = @pernr and begda <= @fpend and endda >= @fpend.
          IF sy-subrc eq 0.

        CALL FUNCTION 'BAPI_BASICPAY_GETDETAIL'
          EXPORTING
            employeenumber              = wa_0008-pernr
            subtype                     = wa_0008-subty
            objectid                    = wa_0008-objps
            lockindicator               = wa_0008-SPRPS
            validitybegin               = wa_0008-begda
            validityend                 = wa_0008-endda
            recordnumber                = wa_0008-seqnr

         TABLES
           WAGETYPES                   = wagetypes
                  .

          ENDIF.
ENDFUNCTION.
