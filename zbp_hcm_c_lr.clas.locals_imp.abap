CLASS lhc_LR DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS augment_create FOR MODIFY
      IMPORTING entities FOR CREATE lr.

ENDCLASS.

CLASS lhc_LR IMPLEMENTATION.

  METHOD augment_create.

  DATA: lr_create TYPE TABLE FOR CREATE zhcm_i_lr.

    lr_create = CORRESPONDING #( entities ).
    LOOP AT lr_create ASSIGNING FIELD-SYMBOL(<lr_wa>).
      <lr_wa>-ReqStatus = '1'.
      <lr_wa>-%control-ReqStatus = if_abap_behv=>mk-on.
      select SINGLE pernr from pa0105 into @<lr_wa>-pernr WHERE usrid = @sy-uname AND begda <= @sy-datum AND endda >= @sy-datum.
      if sy-subrc = 0.
      CALL FUNCTION 'RP_GET_HIRE_DATE'
         EXPORTING
           persnr          =  <lr_wa>-pernr
           check_infotypes = '0000'
*           datumsart       = '01'
*           status2         = '3'
*           p0016_optionen  = ' '
         IMPORTING
           hiredate        = <lr_wa>-hiredate
         .
      select SINGLE ename,PlansTxt,orgehTxt from zhcm_employee_help into ( @<lr_wa>-ename,@<lr_wa>-PlansTxt,@<lr_wa>-OrgehTxt ) WHERE pernr = @<lr_wa>-Pernr.


*******get quota for employee*********
*DATA cmulatedv type table of BAPIHRQUOTACV.
*call FUNCTION 'BAPI_TIMEQUOTA_GETDETAILEDLIST'
*  EXPORTING
*    employeenumber             =   <lr_wa>-pernr
**    quotaselectionmod          = '1'
**    wayofcalculation           = 'D'
**    keydateforentitle          =
**    keydatefordeduction        =
*
*    deductbegin                = cl_abap_context_info=>get_system_date( )
*    deductend                  =  cl_abap_context_info=>get_system_date( )
*  TABLES
**    absencequotatypeselection  =
**    presencequotatypeselection =
**    absencequotareturntable    =
**    presencequotareturntable   =
**    return                     =
*    cumulatedvalues            = cmulatedv
**    absencequotatransferpool   =
*  .
*  READ TABLE cmulatedv into DATA(cmulativ_Wa) WITH KEY quotatype = '01'.
*  if sy-subrc eq 0.
*  <lr_wa>-entitle = cmulativ_wa-entitle.
*  <lr_wa>-deduct = cmulativ_wa-deduct.
*  SELECT SUM( abwtg ) FROM zhcm_leave_req INTO @<lr_WA>-pendingreq WHERE pernr = @<lr_WA>-pernr AND AWART = '1000' AND req_status = 1.
*  <lr_wa>-rest = cmulativ_wa-rest - <lr_wa>-pendingreq.
*  ENDIF.
*      FREE cmulatedv.
*    CLEAR cmulativ_wa.

*
*      <lr_wa>-%control-entitle = if_abap_behv=>mk-on.
*<lr_wa>-%control-deduct = if_abap_behv=>mk-on.
*      <lr_wa>-%control-pendingreq = if_abap_behv=>mk-on.
*<lr_wa>-%control-rest = if_abap_behv=>mk-on.
      ENDIF.
      <lr_wa>-%control-hiredate = if_abap_behv=>mk-on.
      <lr_wa>-%control-pernr = if_abap_behv=>mk-on.
      <lr_wa>-%control-ename = if_abap_behv=>mk-on.
      <lr_wa>-%control-PlansTxt = if_abap_behv=>mk-on.
      <lr_wa>-%control-OrgehTxt = if_abap_behv=>mk-on.
      <lr_wa>-%control-ReqStatus = if_abap_behv=>mk-on.
    ENDLOOP.

DATA : lt_approval TYPE TABLE FOR READ RESULT zhcm_c_lr\\Approval .

*    APPEND INITIAL LINE TO lt_approval ASSIGNING FIELD-SYMBOL(<fs_new_approval>).
*    <fs_new_approval>-RequestUuid = <lr_wa>-RequestUuid.
*    <fs_new_approval>-%key = <lr_wa>-%key.
*    <fs_new_approval>-ApprovalSeq = 1.
    MODIFY AUGMENTING ENTITIES OF zhcm_i_lr ENTITY lr CREATE FIELDS ( Pernr hiredate ename ReqStatus entitle deduct pendingreq rest PlansTxt OrgehTxt )  WITH CORRESPONDING #(  lr_create ).


  ENDMETHOD.

ENDCLASS.
