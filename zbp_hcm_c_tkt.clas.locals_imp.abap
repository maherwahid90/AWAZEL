CLASS lhc_TKT DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS augment_create FOR MODIFY
      IMPORTING entities FOR CREATE tkt.

ENDCLASS.

CLASS lhc_TKT IMPLEMENTATION.

  METHOD augment_create.

    DATA: tkt_create TYPE TABLE FOR CREATE zhcm_i_tkt.

    tkt_create = CORRESPONDING #( entities ).
    LOOP AT tkt_create ASSIGNING FIELD-SYMBOL(<tkt_wa>).
      <tkt_wa>-ReqStatus = '1'.
      <tkt_wa>-%control-ReqStatus = if_abap_behv=>mk-on.

      SELECT SINGLE pernr FROM pa0105 INTO @<tkt_wa>-pernr
        WHERE usrid = @sy-uname AND begda <= @sy-datum AND endda >= @sy-datum AND usrty = '0001'.
      IF sy-subrc = 0.
        " ename/PlansTxt/OrgehTxt/hiredate are association-sourced (from zhcm_employee_help),
        " not persisted columns on ZHCM_TICKET_REQ - setting them here just seeds the
        " create-response buffer for immediate UI feedback, exactly like Leave Request's
        " augment_create does for the same fields.
        SELECT SINGLE ename, PlansTxt, orgehTxt, hiredate FROM zhcm_employee_help
          INTO ( @<tkt_wa>-ename, @<tkt_wa>-PlansTxt, @<tkt_wa>-OrgehTxt, @<tkt_wa>-hiredate )
          WHERE pernr = @<tkt_wa>-Pernr.
      ENDIF.

      <tkt_wa>-%control-hiredate = if_abap_behv=>mk-on.
      <tkt_wa>-%control-pernr    = if_abap_behv=>mk-on.
      <tkt_wa>-%control-ename    = if_abap_behv=>mk-on.
      <tkt_wa>-%control-PlansTxt = if_abap_behv=>mk-on.
      <tkt_wa>-%control-OrgehTxt = if_abap_behv=>mk-on.
      <tkt_wa>-%control-ReqStatus = if_abap_behv=>mk-on.
    ENDLOOP.

    MODIFY AUGMENTING ENTITIES OF zhcm_i_tkt ENTITY tkt
      CREATE FIELDS ( Pernr hiredate ename ReqStatus PlansTxt OrgehTxt )
      WITH CORRESPONDING #( tkt_create ).

  ENDMETHOD.

ENDCLASS.
