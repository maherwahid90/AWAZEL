CLASS lhc_ECD DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS augment_create FOR MODIFY
      IMPORTING entities FOR CREATE ecd.

ENDCLASS.

CLASS lhc_ECD IMPLEMENTATION.

  METHOD augment_create.

    DATA: ecd_create TYPE TABLE FOR CREATE zhcm_i_ecd.

    ecd_create = CORRESPONDING #( entities ).
    LOOP AT ecd_create ASSIGNING FIELD-SYMBOL(<ecd_wa>).
      <ecd_wa>-ReqStatus = '1'.
      <ecd_wa>-%control-ReqStatus = if_abap_behv=>mk-on.

      SELECT SINGLE pernr FROM pa0105 INTO @<ecd_wa>-pernr
        WHERE usrid = @sy-uname AND begda <= @sy-datum AND endda >= @sy-datum AND usrty = '0001'.
      IF sy-subrc = 0.
        SELECT SINGLE ename, PlansTxt, orgehTxt FROM zhcm_employee_help
          INTO ( @<ecd_wa>-ename, @<ecd_wa>-PlansTxt, @<ecd_wa>-OrgehTxt )
          WHERE pernr = @<ecd_wa>-Pernr.
      ENDIF.

      <ecd_wa>-%control-pernr    = if_abap_behv=>mk-on.
      <ecd_wa>-%control-ename    = if_abap_behv=>mk-on.
      <ecd_wa>-%control-PlansTxt = if_abap_behv=>mk-on.
      <ecd_wa>-%control-OrgehTxt = if_abap_behv=>mk-on.
      <ecd_wa>-%control-ReqStatus = if_abap_behv=>mk-on.
    ENDLOOP.

    MODIFY AUGMENTING ENTITIES OF zhcm_i_ecd ENTITY ecd
      CREATE FIELDS ( Pernr ename ReqStatus PlansTxt OrgehTxt )
      WITH CORRESPONDING #( ecd_create ).

  ENDMETHOD.

ENDCLASS.
