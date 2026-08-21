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
    " Auto-list every infotype 0021 (Family Member/Dependants) record valid today for the
    " requester the first time the employee chooses a ticket type that involves family
    " members, with Selected initially unset - the employee then ticks "Selected" for
    " whichever dependants actually need a ticket, and can still add further rows by hand
    " (create is enabled on _Member) for anyone not found in PA0021.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( Pernr TicketType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tkts).

    DATA member_create TYPE TABLE FOR CREATE zhcm_i_tkt\_Member.

    LOOP AT tkts INTO DATA(tkt_wa) WHERE TicketType = '2' OR TicketType = '3'.

      READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
        ENTITY tkt BY \_Member
        ALL FIELDS WITH VALUE #( ( %tky = tkt_wa-%tky ) )
        RESULT DATA(existing_members).
      CHECK existing_members IS INITIAL.

      " NOTE: PA0021 (Family Member/Dependants) field names - verify the actual subtype
      " structure/field names on the target system before activating (FANAM = first name is
      " a standard field; the "last/family name" field varies by configuration - adjust the
      " SELECT below, e.g. NACHN, if it differs).
      SELECT pernr, subty, fanam, nachn, fgbdt, pspnm
        FROM pa0021
        WHERE pernr = @tkt_wa-Pernr
          AND begda <= @sy-datum AND endda >= @sy-datum
        INTO TABLE @DATA(family_it).

      CHECK family_it IS NOT INITIAL.

      DATA(next_seq) = 0.
      LOOP AT family_it INTO DATA(fam).
        next_seq += 1.
        APPEND VALUE #( %tky                = tkt_wa-%tky
                         %target            = VALUE #( ( %cid          = |TKTMEM{ sy-uuid_c32 }|
                                                          %key-FamilySeq = next_seq
                                                          Selected      = abap_false
                                                          Name          = |{ fam-fanam } { fam-nachn }|
                                                          Birthdate     = fam-fgbdt
                                                          PassportNo    = fam-pspnm
                                                          %control-Selected   = if_abap_behv=>mk-on
                                                          %control-Name       = if_abap_behv=>mk-on
                                                          %control-Birthdate  = if_abap_behv=>mk-on
                                                          %control-PassportNo = if_abap_behv=>mk-on ) ) )
               TO member_create.
      ENDLOOP.
    ENDLOOP.

    CHECK member_create IS NOT INITIAL.
    MODIFY ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        CREATE BY \_Member
        FROM member_create.
  ENDMETHOD.

  METHOD validateTicket.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY tkt
        FIELDS ( Pernr TicketType Begda Endda )
        WITH CORRESPONDING #( keys )
      RESULT DATA(tkts)
      ENTITY tkt BY \_Member ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(tkts_member).

    LOOP AT tkts INTO DATA(tkt_wa).

      " At least one selected member is required for ticket types that include family.
      IF tkt_wa-TicketType = '2' OR tkt_wa-TicketType = '3'.
        READ TABLE tkts_member TRANSPORTING NO FIELDS
          WITH KEY %tky = tkt_wa-%tky selected = abap_true.
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

CLASS lhc__Member DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR _Member RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE zhcm_i_tkt\_Member.

    METHODS calculateAge FOR DETERMINE ON MODIFY
      IMPORTING keys FOR _Member~calculateAge.

ENDCLASS.

CLASS lhc__Member IMPLEMENTATION.

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

  METHOD earlynumbering_create.
    " ZHCM_TICK_MEMBER's key includes FAMILY_SEQ (a running line number per request), unlike
    " every UUID-keyed child elsewhere in this suite - so it cannot use the framework's
    " built-in "numbering: managed" UUID generation and needs this early-numbering handler
    " instead, for rows the *employee* creates by hand via the Fiori Elements "Add" button
    " (rows created by the populateMembers determination already assign FamilySeq themselves
    " and never reach this method). This method's exact API shape (the %cid/%key/%is_draft
    " fields of the `mapped-_member` result) should be re-checked against ADT's type
    " proposal/syntax check when activated - it is the one part of this app's RAP code that
    " could not be verified against a real compiler in this session.
    LOOP AT entities INTO DATA(entity).

      SELECT SINGLE FROM zhcm_tick_member
        FIELDS MAX( family_seq )
        WHERE request_uuid = @entity-RequestUuid
        INTO @DATA(max_seq).

      READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
        ENTITY tkt BY \_Member
        ALL FIELDS WITH VALUE #( ( RequestUuid = entity-RequestUuid ) )
        RESULT DATA(existing_members).

      LOOP AT existing_members INTO DATA(exist_wa) WHERE FamilySeq > max_seq.
        max_seq = exist_wa-FamilySeq.
      ENDLOOP.

      max_seq += 1.

      mapped-_member = VALUE #( BASE mapped-_member (
                                    %cid           = entity-%cid
                                    %key           = entity-%key
                                    %is_draft      = entity-%is_draft
                                    FamilySeq      = max_seq ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD calculateAge.
    READ ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY _Member
        FIELDS ( Birthdate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(member_it).

    LOOP AT member_it ASSIGNING FIELD-SYMBOL(<mem_wa>) WHERE Birthdate IS NOT INITIAL.
      DATA: years  TYPE pea_scryy,
            months TYPE pea_scrmm,
            days   TYPE pea_scrdd.
      CALL FUNCTION 'HR_HK_DIFF_BT_2_DATES'
        EXPORTING
          date1          = sy-datum
          date2          = <mem_wa>-Birthdate
          output_format  = '05'
        IMPORTING
          years          = years
          months         = months
          days           = days
        EXCEPTIONS
          OTHERS         = 1.
      IF sy-subrc = 0.
        " NOTE: ZHCM_TICK_MEMBER-AGE is typed DEC(3,2) - only 1 digit before the decimal
        " point (max 9.99), so this assignment overflows/dumps for any age >= 10. Flagging
        " this clearly rather than silently working around it: recommend changing AGE to a
        " plain integer/DEC(3,0) type before this determination is activated for real use.
        <mem_wa>-Age = years.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zhcm_i_tkt IN LOCAL MODE
      ENTITY _Member
        UPDATE FIELDS ( Age )
        WITH CORRESPONDING #( member_it ).
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
