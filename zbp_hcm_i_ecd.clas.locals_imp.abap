CLASS lhc_ECD DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ecd RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR ecd RESULT result.

    METHODS setRequestNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR ecd~setRequestNumber.

    METHODS retrieveSystemId FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ecd~retrieveSystemId.

    METHODS validateEcd FOR VALIDATE ON SAVE
      IMPORTING keys FOR ecd~validateEcd.

ENDCLASS.

CLASS lhc_ECD IMPLEMENTATION.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky                  = key-%tky
                      %field-Pernr          = if_abap_behv=>fc-f-read_only
                      %field-PlansTxt       = if_abap_behv=>fc-f-read_only
                      %field-OrgehTxt       = if_abap_behv=>fc-f-read_only
                      %field-requestid      = if_abap_behv=>fc-f-read_only
                      ) TO result.

      result[ %key = CORRESPONDING #( key ) ]-%update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled ).
      result[ %key = CORRESPONDING #( key ) ]-%delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD setRequestNumber.
    "Ensure idempotence
    READ ENTITIES OF zhcm_i_ecd IN LOCAL MODE
      ENTITY ecd
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(ecds).
    DELETE ecds WHERE RequestId IS NOT INITIAL.
    CHECK ecds IS NOT INITIAL.
    "Get max requestId (simple max+1 sequence, same pattern as Leave Request / Overtime / Tickets)
    SELECT SINGLE FROM zhcm_ecd_req FIELDS MAX( request_id ) INTO @DATA(max_requestid).
    MODIFY ENTITIES OF zhcm_i_ecd IN LOCAL MODE
      ENTITY ecd
        UPDATE FIELDS ( RequestId )
        WITH VALUE #( FOR ecd IN ecds INDEX INTO i (
                           %tky      = ecd-%tky
                           RequestId = max_requestid + i ) ).
  ENDMETHOD.

  METHOD retrieveSystemId.
    " "when employee select communication type application should retrieve the exist data
    " in system" - look up the employee's current PA0105 record for the chosen
    " communication type (USRTY) and pre-fill SystemId with the value already on file
    " (USRID), so the employee edits/confirms it rather than starting from a blank field.
    " If no record exists yet for that type, SystemId is cleared so the employee enters a
    " brand-new value.
    READ ENTITIES OF zhcm_i_ecd IN LOCAL MODE
      ENTITY ecd
        FIELDS ( Pernr CommunicationType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(ecds).

    LOOP AT ecds ASSIGNING FIELD-SYMBOL(<ecd_wa>) WHERE CommunicationType IS NOT INITIAL.
      SELECT SINGLE usrid FROM pa0105 INTO @<ecd_wa>-SystemId
        WHERE pernr = @<ecd_wa>-Pernr
          AND usrty = @<ecd_wa>-CommunicationType
          AND begda <= @sy-datum AND endda >= @sy-datum.
      IF sy-subrc <> 0.
        CLEAR <ecd_wa>-SystemId.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zhcm_i_ecd IN LOCAL MODE
      ENTITY ecd
        UPDATE FIELDS ( SystemId )
        WITH CORRESPONDING #( ecds ).
  ENDMETHOD.

  METHOD validateEcd.
    READ ENTITIES OF zhcm_i_ecd IN LOCAL MODE
      ENTITY ecd
        FIELDS ( Pernr Begda CommunicationType SystemId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(ecds).

    LOOP AT ecds INTO DATA(ecd_wa).

      " No other own, still-relevant request already changing the same communication type.
      SELECT SINGLE request_id FROM zhcm_ecd_req
        WHERE pernr = @ecd_wa-Pernr AND communication_type = @ecd_wa-CommunicationType
          AND req_status IN ( '1', '2' )
        INTO @DATA(exist_req).
      IF exist_req > 0.
        APPEND VALUE #( %tky = ecd_wa-%tky ) TO failed-ecd.
        APPEND VALUE #( %tky        = ecd_wa-%tky
                        %state_area = 'VALIDATE_ECD'
                        %msg        = new_message(
                                              id       = 'ZHCM_MSGS'
                                              number   = '004'
                                              v1       = exist_req
                                              severity = if_abap_behv_message=>severity-error )
                        %element-CommunicationType = if_abap_behv=>mk-on ) TO reported-ecd.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc__Attachment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR _Attachment RESULT result.

ENDCLASS.

CLASS lhc__Attachment IMPLEMENTATION.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(key).
      result[ %key = CORRESPONDING #( key ) ]-%update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled ).
      result[ %key = CORRESPONDING #( key ) ]-%delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled ).
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
      result[ %key = CORRESPONDING #( key ) ]-%update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled ).
      result[ %key = CORRESPONDING #( key ) ]-%delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zhcm_i_ecd DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zhcm_i_ecd IMPLEMENTATION.

  METHOD save_modified.
    IF create-ecd IS NOT INITIAL.
      READ ENTITIES OF zhcm_i_ecd IN LOCAL MODE
        ENTITY ecd
          FIELDS ( RequestId Pernr ename ) WITH CORRESPONDING #( create-ecd )
        RESULT DATA(ecds).

      LOOP AT ecds ASSIGNING FIELD-SYMBOL(<ecd_wa>).

        " Seed the approval chain exactly like Leave Request / Overtime / Tickets Request -
        " see ZHCM_ESS_APPROV configuration for APP_ID = '04'.
        CALL FUNCTION 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
          EXPORTING
            requestuuid = <ecd_wa>-RequestUuid
            pernr       = <ecd_wa>-pernr
            status      = 'I'
            app_id      = '04'.

        DATA: return_code     TYPE syst_subrc,
              workitem_id     TYPE sww_wiid,
              new_status      TYPE swr_wistat,
              input_container TYPE TABLE OF swr_cont,
              message_struct  TYPE TABLE OF swr_mstruc.

        input_container = VALUE #(
                            ( element = 'RequestUuid' value = <ecd_wa>-RequestUuid )
                            ( element = 'ENAME'        value = <ecd_wa>-ename )
                            ( element = 'APP_ID'        value = '04' ) ).

        CALL FUNCTION 'SAP_WAPI_START_WORKFLOW' DESTINATION 'NONE'
          EXPORTING
            task            = 'WS95000005'
          IMPORTING
            return_code     = return_code
            workitem_id     = workitem_id
            new_status      = new_status
          TABLES
            input_container = input_container.

        IF return_code <> 0.
          CALL FUNCTION 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
            EXPORTING
              requestuuid = <ecd_wa>-RequestUuid
              pernr       = <ecd_wa>-pernr
              status      = 'D'
              app_id      = '04'.

          LOOP AT message_struct INTO DATA(msg_wa) WHERE msgty = 'E'.
            APPEND VALUE #( %tky = <ecd_wa>-%tky
                            %msg = new_message(
                                        id       = msg_wa-msgid
                                        number   = msg_wa-msgno
                                        v1       = msg_wa-msgv1
                                        v2       = msg_wa-msgv2
                                        v3       = msg_wa-msgv3
                                        v4       = msg_wa-msgv4
                                        severity = if_abap_behv_message=>severity-error )
                            ) TO reported-ecd.
          ENDLOOP.
        ELSE.
          <ecd_wa>-workitem_id = workitem_id.
          <ecd_wa>-return_code = return_code.
          CALL FUNCTION 'ZHCM_UPDATE_WORKITEM' DESTINATION 'NONE'
            EXPORTING
              requestuuid = <ecd_wa>-RequestUuid
              workitem_id = <ecd_wa>-workitem_id
              return_code = <ecd_wa>-return_code
              requestid   = <ecd_wa>-RequestId
              pernr       = <ecd_wa>-pernr
              app_id      = '04'.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
