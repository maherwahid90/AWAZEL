CLASS lhc_TKT DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR tkt RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR tkt RESULT result.

    METHODS setRequestNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR tkt~setRequestNumber.

    METHODS populateFamily FOR DETERMINE ON MODIFY
      IMPORTING keys FOR tkt~populateFamily.

    METHODS validateTicket FOR VALIDATE ON SAVE
      IMPORTING keys FOR tkt~validateTicket.

ENDCLASS.

CLASS lhc_TKT IMPLEMENTATION.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky                  = key-%tky
                      %field-Pernr          = if_abap_behv=>fc-f-read_only
                      %field-hiredate       = if_abap_behv=>fc-f-read_only
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
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tkts).
    DELETE tkts WHERE RequestId IS NOT INITIAL.
    CHECK tkts IS NOT INITIAL.
    "Get max requestId (simple max+1 sequence, same pattern as Leave Request / Overtime)
    SELECT SINGLE FROM zhcm_ticket_req FIELDS MAX( request_id ) INTO @DATA(max_requestid).
    MODIFY ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        UPDATE FIELDS ( RequestId )
        WITH VALUE #( FOR tkt IN tkts INDEX INTO i (
                           %tky      = tkt-%tky
                           RequestId = max_requestid + i ) ).
  ENDMETHOD.

  METHOD populateFamily.
    " Auto-populate family/companion data from infotype 0021 (Family Member/Dependants)
    " the first time the employee chooses a ticket type that involves family members.
    " The employee can still manually add/remove/edit rows afterwards (_Family allows
    " create/update/delete), matching the FS: "family members are auto-populated from
    " the employee's file, but the employee can also manually add and select a family
    " member if needed".
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( Pernr TicketType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tkts).

    DATA family_create TYPE TABLE FOR CREATE zhcm_i_tkt\_Family.
    DATA lv_cid_no TYPE i VALUE 0.

    LOOP AT tkts INTO DATA(tkt_wa) WHERE TicketType = '2' OR TicketType = '3'.

      READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
        ENTITY tkt BY \_Family
        ALL FIELDS WITH VALUE #( ( %tky = tkt_wa-%tky ) )
        RESULT DATA(existing_family).
      CHECK existing_family IS INITIAL.

      " NOTE: PA0021 (Family Member/Dependants) field names below follow the
      " functional spec (PA0021-FANAM for first name, PA0021-ARLNM for family/
      " last name). ARLNM is not a universally standard PA0021 field in every
      " system configuration - verify the actual subtype structure/field names
      " against the target system before activating and adjust the SELECT below
      " (e.g. NACHN or a customer-specific field) if it differs.
      SELECT pernr, subty, fanam, nachn, fgbdt, pspnm
        FROM pa0021
        WHERE pernr = @tkt_wa-Pernr
          AND begda <= @sy-datum AND endda >= @sy-datum
        INTO TABLE @DATA(family_it).

      CHECK family_it IS NOT INITIAL.

      APPEND VALUE #( %tky    = tkt_wa-%tky
                       %target = VALUE #( FOR fam IN family_it (
                                              %cid                  = |TKTFAM{ lv_cid_no = lv_cid_no + 1 }|
                                              FirstName             = fam-fanam
                                              LastName              = fam-nachn
                                              Birthdate             = fam-fgbdt
                                              PassportNo            = fam-pspnm
                                              SourceSubty           = fam-subty
                                              %control-FirstName    = if_abap_behv=>mk-on
                                              %control-LastName     = if_abap_behv=>mk-on
                                              %control-Birthdate    = if_abap_behv=>mk-on
                                              %control-PassportNo   = if_abap_behv=>mk-on
                                              %control-SourceSubty  = if_abap_behv=>mk-on ) ) )
             TO family_create.
    ENDLOOP.

    CHECK family_create IS NOT INITIAL.
    MODIFY ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        CREATE BY \_Family
        FROM family_create.
  ENDMETHOD.

  METHOD validateTicket.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( Pernr TicketType Begda Endda )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tkts)
      ENTITY tkt BY \_Family ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(tkts_family).

    LOOP AT tkts INTO DATA(tkt_wa).

      " Family data required for ticket types that include family members.
      IF tkt_wa-TicketType = '2' OR tkt_wa-TicketType = '3'.
        READ TABLE tkts_family TRANSPORTING NO FIELDS WITH KEY %tky = tkt_wa-%tky.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = tkt_wa-%tky ) TO failed-tkt.
          APPEND VALUE #( %tky        = tkt_wa-%tky
                          %state_area = 'VALIDATE_TICKET'
                          %msg        = new_message(
                                                id       = 'ZHCM_MSGS'
                                                number   = '011'
                                                severity = if_abap_behv_message=>severity-error )
                          %element-TicketType = if_abap_behv=>mk-on ) TO reported-tkt.
          CONTINUE.
        ENDIF.
      ENDIF.

      " End date may not be before start date.
      IF tkt_wa-Endda < tkt_wa-Begda AND tkt_wa-Begda IS NOT INITIAL AND tkt_wa-Endda IS NOT INITIAL.
        APPEND VALUE #( %tky = tkt_wa-%tky ) TO failed-tkt.
        APPEND VALUE #( %tky        = tkt_wa-%tky
                        %state_area = 'VALIDATE_TICKET'
                        %msg        = new_message(
                                              id       = 'ZHCM_MSGS'
                                              number   = '003'
                                              severity = if_abap_behv_message=>severity-error )
                        %element-Begda = if_abap_behv=>mk-on
                        %element-Endda = if_abap_behv=>mk-on ) TO reported-tkt.
        CONTINUE.
      ENDIF.

      " No other own, still-relevant ticket request for an overlapping date range.
      SELECT SINGLE request_id FROM zhcm_ticket_req
        WHERE begda <= @tkt_wa-Endda AND endda >= @tkt_wa-Begda AND pernr = @tkt_wa-Pernr
          AND req_status IN ( '1', '2', '4' )
        INTO @DATA(exist_req).
      IF exist_req > 0.
        APPEND VALUE #( %tky = tkt_wa-%tky ) TO failed-tkt.
        APPEND VALUE #( %tky        = tkt_wa-%tky
                        %state_area = 'VALIDATE_TICKET'
                        %msg        = new_message(
                                              id       = 'ZHCM_MSGS'
                                              number   = '004'
                                              v1       = exist_req
                                              severity = if_abap_behv_message=>severity-error )
                        %element-Begda = if_abap_behv=>mk-on
                        %element-Endda = if_abap_behv=>mk-on ) TO reported-tkt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc__Family DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR _Family RESULT result.

    METHODS calculateAge FOR DETERMINE ON MODIFY
      IMPORTING keys FOR _Family~calculateAge.

ENDCLASS.

CLASS lhc__Family IMPLEMENTATION.

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

  METHOD calculateAge.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY _Family
        FIELDS ( Birthdate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(family_it).

    LOOP AT family_it ASSIGNING FIELD-SYMBOL(<fam_wa>) WHERE Birthdate IS NOT INITIAL.
      DATA: years  TYPE pea_scryy,
            months TYPE pea_scrmm,
            days   TYPE pea_scrdd.
      CALL FUNCTION 'HR_HK_DIFF_BT_2_DATES'
        EXPORTING
          date1          = sy-datum
          date2          = <fam_wa>-Birthdate
          output_format  = '05'
        IMPORTING
          years          = years
          months         = months
          days           = days
        EXCEPTIONS
          OTHERS         = 1.
      IF sy-subrc = 0.
        <fam_wa>-Age = years.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY _Family
        UPDATE FIELDS ( Age )
        WITH CORRESPONDING #( family_it ).
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

CLASS lsc_zhcm_i_tkt DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zhcm_i_tkt IMPLEMENTATION.

  METHOD save_modified.
    IF create-tkt IS NOT INITIAL.
      READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
        ENTITY tkt
          FIELDS ( RequestId Pernr ename ) WITH CORRESPONDING #( create-tkt )
        RESULT DATA(tkts).

      LOOP AT tkts ASSIGNING FIELD-SYMBOL(<tkt_wa>).

        " Seed the (single-level, HR) approval chain exactly like Leave Request /
        " Overtime Request - see ZHCM_ESS_APPROV configuration for APP_ID = '03'.
        CALL FUNCTION 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
          EXPORTING
            requestuuid = <tkt_wa>-RequestUuid
            pernr       = <tkt_wa>-pernr
            status      = 'I'
            app_id      = '03'.

        DATA: return_code     TYPE syst_subrc,
              workitem_id     TYPE sww_wiid,
              new_status      TYPE swr_wistat,
              input_container TYPE TABLE OF swr_cont,
              message_struct  TYPE TABLE OF swr_mstruc.

        input_container = VALUE #(
                            ( element = 'RequestUuid' value = <tkt_wa>-RequestUuid )
                            ( element = 'ENAME'        value = <tkt_wa>-ename )
                            ( element = 'APP_ID'        value = '03' ) ).

        CALL FUNCTION 'SAP_WAPI_START_WORKFLOW' DESTINATION 'NONE'
          EXPORTING
            task            = 'WS95000004'
          IMPORTING
            return_code     = return_code
            workitem_id     = workitem_id
            new_status      = new_status
          TABLES
            input_container = input_container.

        IF return_code <> 0.
          CALL FUNCTION 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
            EXPORTING
              requestuuid = <tkt_wa>-RequestUuid
              pernr       = <tkt_wa>-pernr
              status      = 'D'
              app_id      = '03'.

          LOOP AT message_struct INTO DATA(msg_wa) WHERE msgty = 'E'.
            APPEND VALUE #( %tky = <tkt_wa>-%tky
                            %msg = new_message(
                                        id       = msg_wa-msgid
                                        number   = msg_wa-msgno
                                        v1       = msg_wa-msgv1
                                        v2       = msg_wa-msgv2
                                        v3       = msg_wa-msgv3
                                        v4       = msg_wa-msgv4
                                        severity = if_abap_behv_message=>severity-error )
                            ) TO reported-tkt.
          ENDLOOP.
        ELSE.
          <tkt_wa>-workitem_id = workitem_id.
          <tkt_wa>-return_code = return_code.
          CALL FUNCTION 'ZHCM_UPDATE_WORKITEM' DESTINATION 'NONE'
            EXPORTING
              requestuuid = <tkt_wa>-RequestUuid
              workitem_id = <tkt_wa>-workitem_id
              return_code = <tkt_wa>-return_code
              requestid   = <tkt_wa>-RequestId
              pernr       = <tkt_wa>-pernr
              app_id      = '03'.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
