CLASS lhc__approval DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR _Approval RESULT result.

ENDCLASS.

CLASS lhc__approval IMPLEMENTATION.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(key).


                       result[ %key = CORRESPONDING #(  key ) ]-%update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).
result[ %key = CORRESPONDING #(  key ) ]-%delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).
                                  ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zhcm_i_lr DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zhcm_i_lr IMPLEMENTATION.

  METHOD save_modified.
  data : message_struct type table of swr_mstruc.
  IF create-lr IS NOT INITIAL.
      READ ENTITIES OF zhcm_i_lr IN LOCAL MODE
        ENTITY lr
          FIELDS ( RequestId ) WITH CORRESPONDING #( create-lr )
        RESULT DATA(LRS).
LOOP AT LRS ASSIGNING FIELD-SYMBOL(<lr_wa>).

call function 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
  EXPORTING
    requestuuid = <lr_Wa>-RequestUuid
    pernr       = <lr_Wa>-pernr
    status      = 'I'
    app_id      = '01'
  .
DATA: RETURN_CODE   type SYST_SUBRC,
WORKITEM_ID type SWW_WIID,
NEW_STATUS  TYPE    SWR_WISTAT,
INPUT_CONTAINER TYPE TABLE OF  SWR_CONT.
input_container = VALUE #(
                    ( element = 'RequestUuid'  value = <lr_wa>-RequestUuid )       "Line 1
( element = 'ENAME'  value = <lr_wa>-ename )
( element = 'APP_ID' value = '01')
                  ).
CALL FUNCTION 'SAP_WAPI_START_WORKFLOW' DESTINATION 'NONE'
  EXPORTING
    task                = 'WS95000002'

  IMPORTING
    return_code         = return_code
    workitem_id         = workitem_id
    new_status          = new_status
  TABLES
    input_container     = input_container
*    message_lines       =
*    message_struct      =
*    agents              =
  .
  if return_code ne 0.

call function 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
  EXPORTING
    requestuuid = <lr_Wa>-RequestUuid
    pernr       = <lr_Wa>-pernr
    status      = 'D'
    app_id      = '01'
  .
  LOOP AT message_struct INTO DATA(msg_wa) where msgty = 'E'.
   APPEND VALUE #( %tky               = <lr_wa>-%tky

                        %msg               = new_message(
                                                                id     = msg_wa-msgid
                                                                number = msg_wa-msgno
                                                                v1 = msg_wa-msgv1
                                                                v2 = msg_wa-msgv2
                                                                v3 = msg_wa-msgv3
                                                                v4 = msg_wa-msgv4
                                                                severity   = if_abap_behv_message=>severity-error )

                        ) TO reported-lr.
                        ENDLOOP.
  else.
  <lr_wa>-workitem_id = workitem_id.
  <lr_wa>-return_code = return_code.
  call function 'ZHCM_UPDATE_WORKITEM' DESTINATION 'NONE'
    EXPORTING
      requestuuid =  <lr_wa>-RequestUuid
      workitem_id = <lr_wa>-workitem_id
      return_code = <lr_wa>-return_code
      requestid = <lr_wa>-RequestId
      pernr  = <lr_wa>-pernr
      app_id = '01'
    .
    endif.
ENDLOOP.


    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_LR DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR lr RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR lr RESULT result.
    METHODS setrequestnumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR lr~setrequestnumber.
    METHODS calculateabsence FOR DETERMINE ON MODIFY
      IMPORTING keys FOR lr~calculateabsence.
    METHODS recalculateabsence FOR MODIFY
      IMPORTING keys FOR ACTION lr~recalculateabsence.
    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR lr~validatedates.
    METHODS calculatebalance FOR DETERMINE ON MODIFY
      IMPORTING keys FOR lr~calculatebalance.
    METHODS recalculatebalance FOR MODIFY
      IMPORTING keys FOR ACTION lr~recalculatebalance.

ENDCLASS.

CLASS lhc_LR IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
  LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky                = key-%tky
                      %field-Pernr       = if_abap_behv=>fc-f-read_only
                      %field-Abwtg       = if_abap_behv=>fc-f-read_only
                      %field-Kaltg       = if_abap_behv=>fc-f-read_only
                      %field-hiredate       = if_abap_behv=>fc-f-read_only
                      %field-PlansTxt       = if_abap_behv=>fc-f-read_only
                      %field-OrgehTxt       = if_abap_behv=>fc-f-read_only
                      %field-entitle       = if_abap_behv=>fc-f-read_only
                      %field-deduct       = if_abap_behv=>fc-f-read_only
                      %field-pendingreq       = if_abap_behv=>fc-f-read_only
                      %field-rest       = if_abap_behv=>fc-f-read_only
                      %field-requestid      = if_abap_behv=>fc-f-read_only

                      ) TO result.

                       result[ %key = CORRESPONDING #(  key ) ]-%update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).
result[ %key = CORRESPONDING #(  key ) ]-%delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).

    ENDLOOP.

  ENDMETHOD.

  METHOD setRequestNumber.
   "Ensure idempotence
    READ ENTITIES OF zhcm_i_lr in local mode
      ENTITY lr
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lrs).
    DELETE lrs WHERE RequestId IS NOT INITIAL.
    CHECK lrs IS NOT INITIAL.
    "Get max travelID
    SELECT SINGLE FROM zhcm_leave_req FIELDS MAX( request_id ) INTO @DATA(max_requestid).
    "update involved instances
    MODIFY ENTITIES OF zhcm_i_lr in LOCAL MODE
      ENTITY lr
        UPDATE FIELDS ( RequestId )
        WITH VALUE #( FOR lr IN lrs INDEX INTO i (
                           %tky      = lr-%tky
                           RequestId  = max_requestid + i ) ).

  ENDMETHOD.

  METHOD calculateAbsence.
   MODIFY ENTITIES OF zhcm_i_lr IN LOCAL MODE
      ENTITY lr
        EXECUTE recalculateAbsence
        FROM CORRESPONDING #( keys ).
  ENDMETHOD.

  METHOD recalculateAbsence.
   READ ENTITIES OF zhcm_i_lr in local mode
      ENTITY lr
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lrs).
      CHECK LRS IS NOT INITIAL.
      LOOP AT lrs ASSIGNING FIELD-SYMBOL(<lr_wa>).

      CALL FUNCTION 'ZHCM_GET_ABSENCE_CALENDAR_DAYS' DESTINATION 'NONE'
        EXPORTING
          pernr = <lr_wa>-pernr
          awart = <lr_wa>-awart
          begda = <lr_wa>-begda
          endda = <lr_wa>-endda
        IMPORTING
          abwtg = <lr_wa>-Abwtg
          kaltg = <lr_wa>-kaltg
        .
      endloop.

       MODIFY ENTITIES OF zhcm_i_lr in LOCAL MODE
      ENTITY lr
        UPDATE FIELDS ( Abwtg Kaltg )
         WITH CORRESPONDING #( LRS ).
  ENDMETHOD.

  METHOD validateDates.
      DATA:return      TYPE TABLE OF bapiret2,
         rt_wa       LIKE LINE OF return,
         return2     TYPE bapiret1,
         hrabsatt_in TYPE bapihrabsatt_in.
    DATA hrtimeskey TYPE  bapihrtimeskey.
  READ ENTITIES OF zhcm_i_lr IN LOCAL MODE
 ENTITY lr
 FIELDS (  Pernr Awart Begda Endda )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lrs)
 ENTITY lr by \_Attachment all FIELDS WITH CORRESPONDING #(  keys ) RESULT DATA(lrs_attach).




    LOOP AT lrs INTO DATA(lr_wa).
case lr_wa-awart.
when '1000' or '1002' or '1003' or '1008'.
"No attachment validatioin
when OTHERS.
read TABLE lrs_attach into DATA(attach_wa) INDEX 1.
if ( sy-subrc ne 0 or attach_wa-Attachment is INITIAL ) .
  APPEND VALUE #( %tky = lr_wa-%tky ) TO failed-lr.
        APPEND VALUE #( %tky               = lr_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '007'

                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-awart = if_abap_behv=>mk-on ) TO reported-lr.
                        return.
ENDIF.
ENDCASE.


SELECT SINGLE REQUEST_ID FROM zhcm_leave_req WHERE BEGDA <= @LR_WA-ENDDA AND ENDDA >= @LR_WA-Begda and pernr = @lr_wa-pernr
AND req_status IN ('1','2','4','5' ) INTO @DATA(EXIST_REQ).
IF exist_req > 0.
        APPEND VALUE #( %tky = lr_wa-%tky ) TO failed-lr.
        APPEND VALUE #( %tky               = lr_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '004'
                                                                v1 = exist_req
                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-begda = if_abap_behv=>mk-on
                        %element-endda   = if_abap_behv=>mk-on ) TO reported-lr.
                        return.
ENDIF.

SELECT SINGLE pernr FROM pa2001 WHERE BEGDA <= @LR_WA-ENDDA AND ENDDA >= @LR_WA-Begda and pernr = @lr_wa-pernr
 INTO @DATA(EXIST_pernr).
IF exist_pernr is NOT INITIAL.
        APPEND VALUE #( %tky = lr_wa-%tky ) TO failed-lr.
        APPEND VALUE #( %tky               = lr_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '006'
                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-begda = if_abap_behv=>mk-on
                        %element-endda   = if_abap_behv=>mk-on ) TO reported-lr.
                        return.
ENDIF.

      IF lr_wa-endda < lr_wa-begda AND lr_wa-begda IS NOT INITIAL
                                           AND lr_wa-endda IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_wa-%tky ) TO failed-lr.
        APPEND VALUE #( %tky               = lr_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '003'
                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-begda = if_abap_behv=>mk-on
                        %element-endda   = if_abap_behv=>mk-on ) TO reported-lr.

      Else.
**********************************************************************
*simulate leave request creation
**********************************************************************
      CLEAR hrabsatt_in.
        hrabsatt_in-from_date = lr_wa-begda.
        hrabsatt_in-to_date = lr_wa-endda.
        CALL FUNCTION 'BAPI_PTMGRATTABS_MNGCREATION' DESTINATION 'NONE'
          EXPORTING
            employeenumber = lr_wa-pernr
            abs_att_type   = lr_wa-awart
            hrabsatt_in    = hrabsatt_in
            simulate       = 'X'
          TABLES
            return         = return.


        LOOP AT return INTO rt_wa WHERE type EQ 'E'.
        APPEND VALUE #( %tky = lr_wa-%tky ) TO failed-lr.
        APPEND VALUE #( %tky               = lr_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = rt_wa-id
                                                                number = rt_wa-number
                                                                v1 = rt_wa-message_v1
                                                                v2 = rt_wa-message_v2
                                                                v3 = rt_wa-message_v3
                                                                v4 = rt_wa-message_v4
                                                                severity   = if_abap_behv_message=>severity-error )
%element-awart = if_abap_behv=>mk-on
                        %element-begda = if_abap_behv=>mk-on
                        %element-endda   = if_abap_behv=>mk-on ) TO reported-lr.
        ENDLOOP.
        endif.
     ENDLOOP.

  ENDMETHOD.

  METHOD calculateBalance.
    MODIFY ENTITIES OF zhcm_i_lr IN LOCAL MODE
      ENTITY lr
        EXECUTE recalculateBalance
        FROM CORRESPONDING #( keys ).
  ENDMETHOD.

  METHOD recalculateBalance.

   READ ENTITIES OF zhcm_i_lr in local mode
      ENTITY lr
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lrs).
      CHECK LRS IS NOT INITIAL.
      LOOP AT lrs ASSIGNING FIELD-SYMBOL(<lr_wa>).


if <lr_wa>-awart = '1000'.
*******get quota for employee*********
DATA cmulatedv type table of BAPIHRQUOTACV.
call FUNCTION 'BAPI_TIMEQUOTA_GETDETAILEDLIST'
  EXPORTING
    employeenumber             =   <lr_wa>-pernr
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
  <lr_wa>-entitle = cmulativ_wa-entitle.
  <lr_wa>-deduct = cmulativ_wa-deduct.
  SELECT SUM( abwtg ) FROM zhcm_leave_req INTO @<lr_WA>-pendingreq WHERE pernr = @<lr_WA>-pernr AND AWART = '1000' AND req_status = 1.
  <lr_wa>-rest = cmulativ_wa-rest - <lr_wa>-pendingreq.
  ENDIF.
      FREE cmulatedv.
    CLEAR cmulativ_wa.
    else.
    <lr_wa>-entitle = <lr_wa>-deduct = <lr_wa>-rest = <lr_wa>-pendingreq = 0.
    endif.

      endloop.

       MODIFY ENTITIES OF zhcm_i_lr in LOCAL MODE
      ENTITY lr
        UPDATE FIELDS ( entitle deduct pendingreq rest )
         WITH CORRESPONDING #( LRS ).
  ENDMETHOD.

ENDCLASS.
