FUNCTION ZHCM_TICKET_REPLICATE_HR.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(REQUESTUUID) TYPE  SYSUUID_X16
*"  EXPORTING
*"     REFERENCE(HEADER) TYPE  ZHCM_TICKET_REQ
*"  TABLES
*"      MEMBERS STRUCTURE  ZHCM_TICK_MEMBER OPTIONAL
*"----------------------------------------------------------------------
* Called once a Tickets Request has been approved (REQ_STATUS = '2'), per the FS:
* "HR: A custom table has been configured for HR. Once a request is approved, it will
* be automatically replicated in the system."
*
* This implementation does NOT write to a dedicated HR replication table - none exists
* in the current table design (ZHCM_TICKET_REQ / ZHCM_TICK_ATTACH / ZHCM_TICK_APPROV /
* ZHCM_TICK_MEMBER only). It assembles the approved header and every *selected*
* (SELECTED = 'X') family member and returns them to the caller. Extend the TODO block
* below to call whatever downstream system/table is meant to receive this data (e.g. an
* RFC/proxy call to a travel-booking system, or an insert into a table once one exists).
*
* NOTE: this repository does not contain the ABAP for the workflow step that finalizes
* an approval decision (the same is true for how Leave Request / Overtime Request
* ultimately set REQ_STATUS to Approved) - that step should call this function module
* after setting ZHCM_TICKET_REQ-REQ_STATUS = '2'.

DATA member_wa LIKE LINE OF members.

CLEAR header.
SELECT SINGLE * FROM zhcm_ticket_req INTO @header WHERE request_uuid = @requestuuid.
IF sy-subrc <> 0.
  RETURN.
ENDIF.

SELECT * FROM zhcm_tick_member
  WHERE request_uuid = @requestuuid AND selected = @abap_true
  INTO TABLE @DATA(selected_members).

LOOP AT selected_members INTO DATA(member).
  CLEAR member_wa.
  MOVE-CORRESPONDING member TO member_wa.
  APPEND member_wa TO members.
ENDLOOP.

* TODO: forward HEADER + MEMBERS to the downstream HR/travel-booking system here
* (RFC destination, BAPI, proxy call, or - if a replication table is added later -
* MODIFY it from here instead of just returning the data).

ENDFUNCTION.
