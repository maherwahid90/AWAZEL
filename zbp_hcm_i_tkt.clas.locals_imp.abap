CLASS lhc_TKT DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR tkt RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR tkt RESULT result.

    METHODS setRequestNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR tkt~setRequestNumber.

    METHODS populateMembers FOR DETERMINE ON MODIFY
      IMPORTING keys FOR tkt~populateMembers.

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

  METHOD populateMembers.
    " Auto-maintain _Member rows as a function of TicketType - this single determination now
    " covers both what populateMembers and clearMembers used to do separately: Employee-only
    " ('01') clears any existing rows, Family/Both ('02'/'03') auto-lists PA0021 dependants
    " the first time (only if none exist yet for this request).
    "
    " _Member's key is no longer FAMILY_SEQ - FamilyUuid is now a proper "numbering: managed"
    " UUID key, exactly like _Attachment's AttachmentUuid, with FamilySeq demoted to a plain
    " display-order field (see the BDEF/table changes). This removes the need for any
    " "early numbering" handler at all, and with it the whole history of dumps that handler
    " caused (CX_ABAP_BEHV_RUNTIME_ERROR, CX_CSP_ACT_RESPONSE, "Invalid operation 'O'") -
    " CREATE BY \_Member now behaves exactly like any other UUID-keyed composition child.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( TicketType Pernr )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tickets).

    DELETE tickets WHERE TicketType IS INITIAL.
    CHECK tickets IS NOT INITIAL.

    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt BY \_Member
        FIELDS ( RequestUuid FamilySeq Name Birthdate )
        WITH CORRESPONDING #( tickets )
      RESULT DATA(members).

    DATA tickets_to_create TYPE TABLE FOR CREATE zhcm_i_tkt\_Member.
    DATA tickets_to_delete TYPE TABLE FOR DELETE zhcm_i_tkt\_Member.

    LOOP AT tickets INTO DATA(ticket).

      IF ticket-TicketType = '01'.
        READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
          ENTITY tkt BY \_Member
          ALL FIELDS WITH VALUE #( ( %tky = ticket-%tky ) )
          RESULT DATA(existing_members).
        CHECK existing_members IS NOT INITIAL.

        LOOP AT existing_members INTO DATA(mem_wa).
          APPEND VALUE #( %tky = mem_wa-%tky %is_draft = mem_wa-%is_draft ) TO tickets_to_delete.
        ENDLOOP.

      ELSEIF ( ticket-TicketType = '02' OR ticket-TicketType = '03' ) AND members IS INITIAL.

        " PA0021 (Family Member/Dependants) name field confirmed against the real system:
        " FAVOR (family/last name) + FANAM (first name). Passport number is not on PA0021
        " itself - it comes from PA3254 (country-specific ID document infotype), joined on
        " the same PERNR/SUBTY/BEGDA/ENDDA as the PA0021 record.
        SELECT pernr, subty, fanam, favor, fgbdt, begda, endda
          FROM pa0021
          WHERE pernr = @ticket-Pernr
            AND begda <= @sy-datum AND endda >= @sy-datum
          INTO TABLE @DATA(family_it).

        CHECK family_it IS NOT INITIAL.

        APPEND VALUE #( %tky = ticket-%tky ) TO tickets_to_create ASSIGNING FIELD-SYMBOL(<cba>).

        " Reset per ticket, not just once for the whole batch - otherwise FamilySeq (now a
        " plain display field, not a key) would keep climbing across different tickets
        " processed in the same call instead of restarting at 1 for each one.
        DATA cid_counter TYPE i.
        CLEAR cid_counter.

        LOOP AT family_it INTO DATA(member).
          DATA: years  TYPE pea_scryy,
                months TYPE pea_scrmm,
                days   TYPE pea_scrdd,
                age    TYPE p LENGTH 3 DECIMALS 2.
          CALL FUNCTION 'HR_HK_DIFF_BT_2_DATES'
            EXPORTING
              date1          = sy-datum
              date2          = member-fgbdt
              output_format  = '05'
            IMPORTING
              years          = years
              months         = months
              days           = days
            EXCEPTIONS
              OTHERS         = 1.
          IF sy-subrc = 0.
            " NOTE: ZHCM_TICK_MEMBER-AGE is typed DEC(3,2) - only 1 digit before the decimal
            " point (max 9.99). This has already dumped live (BCD_FIELD_OVERFLOW) for a real
            " dependant's age - widen AGE (e.g. DEC(3,0) or a plain integer) before relying
            " on this determination for real use.
            age = years.
          ELSE.
            CLEAR age.
          ENDIF.

          SELECT SINGLE pspnm FROM pa3254 INTO @DATA(pspnm)
            WHERE pernr = @member-pernr AND subty = @member-subty
              AND begda = @member-begda AND endda = @member-endda.
          IF sy-subrc <> 0.
            CLEAR pspnm.
          ENDIF.

          cid_counter += 1.

          APPEND VALUE #( %cid        = |MEM{ cid_counter }|
                           %is_draft   = ticket-%is_draft
                           FamilyUuid  = cl_system_uuid=>create_uuid_c32_static( )
                           RequestUuid = ticket-RequestUuid
                           FamilySeq   = cid_counter
                           Name        = |{ member-favor } { member-fanam }|
                           Birthdate   = member-fgbdt
                           Age         = age
                           PassportNo  = pspnm )
            TO <cba>-%target.
        ENDLOOP.
      ENDIF.

    ENDLOOP.

    CHECK tickets_to_create IS NOT INITIAL OR tickets_to_delete IS NOT INITIAL.

    MODIFY ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY _Member
        DELETE FROM tickets_to_delete
      ENTITY tkt
        CREATE BY \_Member
          FIELDS ( RequestUuid FamilySeq Name Birthdate Age PassportNo )
          WITH tickets_to_create
      REPORTED DATA(modify_reported).

    reported = CORRESPONDING #( DEEP modify_reported ).
  ENDMETHOD.

  METHOD validateTicket.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( Pernr TicketType Begda Endda TicketDirection TravelDestination )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tkts)
      ENTITY tkt BY \_Member ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(tkts_member).

    LOOP AT tkts INTO DATA(tkt_wa).

      " All travel-related fields are mandatory before a request can be saved.
      IF tkt_wa-Begda IS INITIAL OR tkt_wa-Endda IS INITIAL OR tkt_wa-TicketType IS INITIAL OR
         tkt_wa-TicketDirection IS INITIAL OR tkt_wa-TravelDestination IS INITIAL.
        APPEND VALUE #( %tky = tkt_wa-%tky ) TO failed-tkt.
        APPEND VALUE #( %tky        = tkt_wa-%tky
                        %state_area = 'VALIDATE_TICKET'
                        %msg        = new_message(
                                              id       = 'ZHCM_MSGS'
                                              number   = '010'
                                              severity = if_abap_behv_message=>severity-error )
                        %element-TicketType         = if_abap_behv=>mk-on
                        %element-TicketDirection     = if_abap_behv=>mk-on
                        %element-TravelDestination   = if_abap_behv=>mk-on
                        %element-Begda = if_abap_behv=>mk-on
                        %element-Endda = if_abap_behv=>mk-on ) TO reported-tkt.
        CONTINUE.
      ENDIF.

      " At least one selected member is required for ticket types that include family.
      IF tkt_wa-TicketType = '02' OR tkt_wa-TicketType = '03'.
        READ TABLE tkts_member TRANSPORTING NO FIELDS
          WITH KEY %tky = tkt_wa-%tky selected = abap_true.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = tkt_wa-%tky ) TO failed-tkt.
          APPEND VALUE #( %tky        = tkt_wa-%tky
                          %state_area = 'VALIDATE_TICKET'
                          %msg        = new_message(
                                                id       = 'ZHCM_MSGS'
                                                number   = '018'
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

CLASS lhc__Member DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR _Member RESULT result.

ENDCLASS.

CLASS lhc__Member IMPLEMENTATION.

  METHOD get_instance_features.
    " Only Selected is ever changed by the employee - _Member rows are exclusively
    " auto-populated/cleaned up by populateMembers; create and delete are not exposed to the
    " UI for this entity at all (see the BDEF), so %delete is not reported here.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky    = key-%tky
                       %update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled ) )
        TO result.
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
    " %tky must exist as a row in result BEFORE it can be addressed via a table expression -
    " writing straight into a table expression on an empty table raises
    " CX_SY_ITAB_LINE_NOT_FOUND (ITAB_LINE_NOT_FOUND).
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky    = key-%tky
                       %update = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
                       %delete = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled ) )
        TO result.
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
        " Overtime Request - see ZHCM_ESS_APPROV configuration for APP_ID = '07'.
        CALL FUNCTION 'ZHCM_UPDATE_APPROVALS' DESTINATION 'NONE'
          EXPORTING
            requestuuid = <tkt_wa>-RequestUuid
            pernr       = <tkt_wa>-pernr
            status      = 'I'
            app_id      = '07'.

        DATA: return_code     TYPE syst_subrc,
              workitem_id     TYPE sww_wiid,
              new_status      TYPE swr_wistat,
              input_container TYPE TABLE OF swr_cont,
              message_struct  TYPE TABLE OF swr_mstruc.

        input_container = VALUE #(
                            ( element = 'RequestUuid' value = <tkt_wa>-RequestUuid )
                            ( element = 'ENAME'        value = <tkt_wa>-ename )
                            ( element = 'APP_ID'        value = '07' ) ).

        CALL FUNCTION 'SAP_WAPI_START_WORKFLOW' DESTINATION 'NONE'
          EXPORTING
            task            = 'WS95000009'
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
              app_id      = '07'.

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
              app_id      = '07'.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
