CLASS lhc_OVER DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR over RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR over RESULT result.

    METHODS setRequestNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR over~setRequestNumber.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR over~validateDates.

ENDCLASS.

CLASS lhc_OVER IMPLEMENTATION.

  METHOD get_instance_features.



 LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky                = key-%tky
                      %field-Pernr       = if_abap_behv=>fc-f-read_only

                      %field-hiredate       = if_abap_behv=>fc-f-read_only
                      %field-PlansTxt       = if_abap_behv=>fc-f-read_only
                      %field-OrgehTxt       = if_abap_behv=>fc-f-read_only
%field-manger_anzhl       = if_abap_behv=>fc-o-disabled

                      %field-requestid      = if_abap_behv=>fc-f-read_only

                      ) TO result.

                       result[ %key = CORRESPONDING #(  key ) ]-%update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).
result[ %key = CORRESPONDING #(  key ) ]-%delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).
        SELECT SINGLE pernr from zhcm_overt_req into @data(request_pernr) WHERE request_uuid = @key-RequestUuid.
        if sy-subrc eq 0.
        SELECT SINGLE pa0105~usrid from pa0105 INNER join zhcm_emp_approv on pa0105~pernr = zhcm_emp_approv~approval_emp
        into @data(approval_user) WHERE pa0105~begda <= @sy-datum AND pa0105~endda >= @sy-datum AND pa0105~usrty = '0001'
        and zhcm_emp_approv~pernr = @request_pernr.
        if approval_user = sy-uname.
          result[ %key = CORRESPONDING #(  key ) ]-%update =  if_abap_behv=>fc-o-enabled.
          result[ %key = CORRESPONDING #(  key ) ]-%field-emp_anzhl =  if_abap_behv=>fc-f-read_only.
          result[ %key = CORRESPONDING #(  key ) ]-%field-Begda =  if_abap_behv=>fc-f-read_only.
          result[ %key = CORRESPONDING #(  key ) ]-%field-manger_anzhl =  if_abap_behv=>fc-o-enabled.
          else.
          result[ %key = CORRESPONDING #(  key ) ]-%field-manger_anzhl =  if_abap_behv=>fc-f-read_only.
        endif.
          else.
          result[ %key = CORRESPONDING #(  key ) ]-%field-manger_anzhl =  if_abap_behv=>fc-F-read_only.
result[ %key = CORRESPONDING #(  key ) ]-%field-emp_anzhl =  if_abap_behv=>fc-f-mandatory.
          result[ %key = CORRESPONDING #(  key ) ]-%field-Begda =  if_abap_behv=>fc-f-mandatory.

        endif.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD setRequestNumber.
    "Ensure idempotence
    READ ENTITIES OF zhcm_i_OVER in local mode
      ENTITY over
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(OVERs).
    DELETE OVERS WHERE RequestId IS NOT INITIAL.
    CHECK OVERS IS NOT INITIAL.
    "Get max travelID
    SELECT SINGLE FROM zhcm_OVERT_req FIELDS MAX( request_id ) INTO @DATA(max_requestid).
    "update involved instances
    MODIFY ENTITIES OF zhcm_i_OVER in LOCAL MODE
      ENTITY OVER
        UPDATE FIELDS ( RequestId )
        WITH VALUE #( FOR lr IN OVERS INDEX INTO i (
                           %tky      = lr-%tky
                           RequestId  = max_requestid + i ) ).
  ENDMETHOD.

  METHOD validateDates.

   READ ENTITIES OF zhcm_i_OVER IN LOCAL MODE
 ENTITY over
 FIELDS (  Pernr Begda )
 WITH CORRESPONDING #( keys )
 RESULT DATA(OVERS)
 ENTITY OVER by \_Attachment all FIELDS WITH CORRESPONDING #(  keys ) RESULT DATA(OVERS_attach).

 LOOP AT overs INTO DATA(OVER_wA).
 read TABLE OVERS_attach into DATA(attach_wa) INDEX 1.
if ( sy-subrc ne 0 or attach_wa-Attachment is INITIAL ) .
  APPEND VALUE #( %tky = OVER_wa-%tky ) TO failed-over.
        APPEND VALUE #( %tky               = OVER_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '007'

                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-_Attachment = if_abap_behv=>mk-on ) TO reported-OVER.
                        return.
ENDIF.

SELECT SINGLE REQUEST_ID FROM zhcm_overt_req WHERE BEGDA = @over_WA-Begda and pernr = @over_wa-pernr
AND req_status IN ('1','2','4','5' ) INTO @DATA(EXIST_REQ).
IF exist_req > 0.
        APPEND VALUE #( %tky = over_wa-%tky ) TO failed-over.
        APPEND VALUE #( %tky               = over_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '004'
                                                                v1 = exist_req
                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-begda = if_abap_behv=>mk-on
                         ) TO reported-over.
                        return.
ENDIF.

if over_wa-Begda is INITIAL or over_wa-emp_anzhl is INITIAL.
  APPEND VALUE #( %tky = over_wa-%tky ) TO failed-over.
        APPEND VALUE #( %tky               = over_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = 'ZHCM_MSGS'
                                                                number = '010'
                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-begda = if_abap_behv=>mk-on
                         ) TO reported-over.
                         return.
endif.
**********************************************************************
*simulate over request creation
**********************************************************************
 DATA:return      TYPE  bapiret1,
         RET_KEY TYPE BAPIPAKEY .
call FUNCTION 'ZHCM_SIMULATE_OVERT_TIME' DESTINATION 'NONE'
  EXPORTING
    pernr  = over_wa-pernr
    anzhl  = over_wa-emp_anzhl
    begda  = over_wa-begda
  IMPORTING
    return =  return
    key    = ret_key
  .
  if return-type = 'E' .
    APPEND VALUE #( %tky = over_wa-%tky ) TO failed-over.
        APPEND VALUE #( %tky               = over_wa-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new_message(
                                                                id     = return-id
                                                                number = return-number
                                                                severity   = if_abap_behv_message=>severity-error )

                        %element-begda = if_abap_behv=>mk-on
                         ) TO reported-over.
                         return.
  endif.

 ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc__Approval DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR _Approval RESULT result.

ENDCLASS.

CLASS lhc__Approval IMPLEMENTATION.

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

CLASS lsc_ZHCM_I_OVER DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZHCM_I_OVER IMPLEMENTATION.

  METHOD save_modified.

  data : message_struct type table of swr_mstruc.
  IF create-over IS NOT INITIAL.
      READ ENTITIES OF zhcm_i_over IN LOCAL MODE
        ENTITY over
          FIELDS ( RequestId ) WITH CORRESPONDING #( create-over )
        RESULT DATA(LRS).
LOOP AT LRS ASSIGNING FIELD-SYMBOL(<lr_wa>).

call function 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
  EXPORTING
    requestuuid = <lr_Wa>-RequestUuid
    pernr       = <lr_Wa>-pernr
    status      = 'I'
    app_id      = '02'
  .
DATA: RETURN_CODE   type SYST_SUBRC,
WORKITEM_ID type SWW_WIID,
NEW_STATUS  TYPE    SWR_WISTAT,
INPUT_CONTAINER TYPE TABLE OF  SWR_CONT.
input_container = VALUE #(
                    ( element = 'RequestUuid'  value = <lr_wa>-RequestUuid )       "Line 1
( element = 'ENAME'  value = <lr_wa>-ename )
( element = 'APP_ID' value = '02')
                  ).
CALL FUNCTION 'SAP_WAPI_START_WORKFLOW' DESTINATION 'NONE'
  EXPORTING
    task                = 'WS95000003'

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
    app_id      = '02'
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

                        ) TO reported-over.
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
      app_id = '02'
    .
    endif.
ENDLOOP.


    ENDIF.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
