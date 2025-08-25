class ZHCM_ESS_WF_CLASS definition
  public
  final
  create public .

public section.

  interfaces BI_OBJECT .
  interfaces BI_PERSISTENT .
  interfaces IF_WORKFLOW .

  class-methods GET_LEAVE_REQUEST_APPROVALS
    importing
      !REQUESTUUID type SYSUUID_X16
      !APP_ID type ZHCM_APP_ID
    exporting
      !APPROVALS type ZHCM_LR_APPROV_TT
      !APPROVALS_COUNT type INT1
      !CURRENT_APPROVAL type ZHCM_LR_APPROV
      !CURRENT_APPROVAL_INDEX type INT1 .
  class-methods READ_CURRENT_APPROVAL
    importing
      !APPROVALS type ZHCM_LR_APPROV_TT
      !CURRENT_APPROVAL_INDEX type INT1
      !APP_ID type ZHCM_APP_ID
    exporting
      !CURRENT_APPROVAL type ZHCM_LR_APPROV .
  class-methods UPDATE_WF_DECISION
    importing
      value(CURRENT_APPROVAL) type ZHCM_LR_APPROV
      !STATUS type CHAR40
      !APP_ID type ZHCM_APP_ID .
  class-methods POST_LEAVE_REQUEST
    importing
      !REQUESTUUID type SYSUUID_X16 .
  class-methods POST_OVERTIME_REQUEST
    importing
      !REQUESTUUID type SYSUUID_X16 .
protected section.
private section.
ENDCLASS.



CLASS ZHCM_ESS_WF_CLASS IMPLEMENTATION.


  method BI_OBJECT~DEFAULT_ATTRIBUTE_VALUE.
  endmethod.


  method BI_OBJECT~EXECUTE_DEFAULT_METHOD.
  endmethod.


  method BI_OBJECT~RELEASE.
  endmethod.


  method BI_PERSISTENT~FIND_BY_LPOR.
  endmethod.


  method BI_PERSISTENT~LPOR.
  endmethod.


  method BI_PERSISTENT~REFRESH.
  endmethod.


  method GET_LEAVE_REQUEST_APPROVALS.
    CASE APP_ID.
      WHEN '01'.
        select * from ZHCM_LR_APPROV into  TABLE @approvals where request_uuid = @requestuuid ORDER BY approval_seq.
      WHEN '02'.

        select * from ZHCM_ov_APPROV into CORRESPONDING FIELDS OF TABLE @approvals where request_uuid = @requestuuid ORDER BY approval_seq.
      WHEN OTHERS.
    ENDCASE.

      DESCRIBE TABLE approvals LINES approvals_count.
      IF approvals_count > 0.
        READ TABLE approvals INTO current_approval INDEX 1.
        current_approval_index = 1.

      ENDIF.
  endmethod.


  method POST_LEAVE_REQUEST.
SELECT SINGLE * from zhcm_leave_req INTO @DATA(leave_req) WHERE request_uuid = @requestuuid.
  IF sy-subrc eq 0.
 DATA:return      TYPE TABLE OF bapiret2,
       lock_ret TYPE TABLE OF bapiret1,
         rt_wa       LIKE LINE OF return,
         hrabsatt_in TYPE bapihrabsatt_in,
         hrtimeskey TYPE  bapihrtimeskey,
         lr_log type ZHCM_LR_POST_L.
CALL FUNCTION 'BAPI_EMPLOYEE_ENQUEUE'
  EXPORTING
    number        = leave_req-pernr
* IMPORTING
*   RETURN        = lock_ret
          .


    CLEAR hrabsatt_in.
        hrabsatt_in-from_date = leave_req-begda.
        hrabsatt_in-to_date = leave_req-endda.
        CALL FUNCTION 'BAPI_PTMGRATTABS_MNGCREATION'
          EXPORTING
            employeenumber = leave_req-pernr
            abs_att_type   = leave_req-awart
            hrabsatt_in    = hrabsatt_in
            simulate       = ''
            IMPORTING
              HRTIMESKEY = HRTIMESKEY
          TABLES
            return         = return.

     IF hrtimeskey-documentnumber IS INITIAL.

        LOOP AT return INTO rt_wa WHERE type EQ 'E'.
          clear lr_log.
          MOVE-CORRESPONDING rt_wa to lr_log.
          lr_log-request_id = leave_req-request_id.
          lr_log-request_uuid = leave_req-request_uuid.
          GET TIME STAMP FIELD lr_log-created_at.
          INSERT INTO ZHCM_LR_POST_L VALUES lr_log.
          endloop.
          UPDATE zhcm_leave_req set req_status = '5' WHERE request_uuid = @requestuuid.
          COMMIT WORK AND WAIT.
          else.
UPDATE zhcm_leave_req set req_status = '4' WHERE request_uuid = @requestuuid.
          COMMIT WORK AND WAIT.
     ENDIF.
  ENDIF.

  CALL FUNCTION 'BAPI_EMPLOYEE_DEQUEUE'
    EXPORTING
      number        = leave_req-pernr
*   IMPORTING
*     RETURN        =
            .

  endmethod.


  method POST_OVERTIME_REQUEST.
SELECT SINGLE * from zhcm_overt_req INTO @DATA(overtime_req) WHERE request_uuid = @requestuuid.
  IF sy-subrc eq 0.
 DATA:return      TYPE  bapiret1,
       P0015 TYPE P0015,
       lock_ret TYPE TABLE OF bapiret1,
         RET_KEY TYPE BAPIPAKEY ,
         LR_LOG TYPE ZHCM_LR_POST_L.
CALL FUNCTION 'BAPI_EMPLOYEE_ENQUEUE'
  EXPORTING
    number        = overtime_req-pernr
* IMPORTING
*   RETURN        = lock_ret
          .

P0015-PERNR = overtime_req-PERNR.
P0015-BEGDA = P0015-ENDDA = overtime_req-BEGDA.
P0015-SUBTY = P0015-LGART = '3005'.
IF overtime_req-manger_anzhl > 0.

P0015-anzhl = overtime_req-manger_anzhl.
else.

P0015-anzhl = overtime_req-emp_anzhl.
ENDIF.
P0015-ZEINH = '001'.


CALL FUNCTION 'HR_PSBUFFER_INITIALIZE'
          .
CALL FUNCTION 'HR_INFOTYPE_OPERATION'
  EXPORTING
    infty                  = '0015'
    number                 = overtime_req-pernr
*   SUBTYPE                =
*   OBJECTID               =
*   LOCKINDICATOR          =
*   VALIDITYEND            =
*   VALIDITYBEGIN          =
*   RECORDNUMBER           =
    record                 = P0015
    operation              = 'INS'
*   TCLAS                  = 'A'
*   DIALOG_MODE            = '0'
*   NOCOMMIT               =
*   VIEW_IDENTIFIER        =
*   SECONDARY_RECORD       =
 IMPORTING
   RETURN                 = RETURN
   KEY                    = ret_key
          .


     IF ret_key IS INITIAL.

          MOVE-CORRESPONDING RETURN to lr_log.
          lr_log-APP_ID = '02'.
          lr_log-request_id = overtime_req-request_id.
          lr_log-request_uuid = overtime_req-request_uuid.
          GET TIME STAMP FIELD lr_log-created_at.
          INSERT INTO ZHCM_LR_POST_L VALUES lr_log.

          UPDATE zhcm_overt_req set req_status = '5' WHERE request_uuid = @requestuuid.
          COMMIT WORK AND WAIT.
          else.
UPDATE zhcm_overT_req set req_status = '4' WHERE request_uuid = @requestuuid.
          COMMIT WORK AND WAIT.
     ENDIF.
  ENDIF.

  CALL FUNCTION 'BAPI_EMPLOYEE_DEQUEUE'
    EXPORTING
      number        = overtime_req-pernr
*   IMPORTING
*     RETURN        =
            .

  endmethod.


  method READ_CURRENT_APPROVAL.
    read TABLE approvals INTO current_approval index current_approval_index.
    IF sy-subrc = 0.
    GET TIME STAMP FIELD current_approval-receive_ts.
    CASE app_id.
      WHEN '01'.

    UPDATE zhcm_lr_approv set receive_ts = @current_approval-receive_ts where request_uuid = @current_approval-request_uuid
    and approval_seq = @current_approval-approval_seq.
    COMMIT WORK and WAIT.
      WHEN '02'.

    UPDATE zhcm_ov_approv set receive_ts = @current_approval-receive_ts where request_uuid = @current_approval-request_uuid
    and approval_seq = @current_approval-approval_seq.
    COMMIT WORK and WAIT.
      WHEN OTHERS.
    ENDCASE.
    ENDIF.
  endmethod.


  method UPDATE_WF_DECISION.
DATA lt_soli_tab TYPE  SOLI_TAB.
    select SINGLE WORKITEM_ID FROM  ZHCM_LR_WFLOG INto @data(req_wi) WHERE request_uuid = @current_approval-request_uuid AND APP_ID = @APP_ID.
      IF sy-subrc eq 0.
        SELECT MAX( wi_id ) INTO @DATA(lv_wiid)
    FROM swwwihead
    WHERE top_wi_id = @req_wi
    AND wi_type = 'W'.

    CALL FUNCTION 'SAP_WAPI_DECISION_COMMENT'
      EXPORTING
        workitem_id       = lv_wiid
*       LANGUAGE          = SY-LANGU
*       PDF_FORM          =
      IMPORTING
        decision_soli_tab = lt_soli_tab.



    READ TABLE lt_soli_tab INTO DATA(lwa_soli_tab) INDEX 1.
    IF sy-subrc = 0.
      current_approval-approval_comment = lwa_soli_tab-line.

    ENDIF.
SELECT SINGLE wi_aagent FROM swwwihead INTO @DATA(actual_agent) WHERE wi_id = @lv_wiid.
  SELECT SINGLE pernr FROM pa0105 INTO @current_approval-approval_pernr WHERE usrid = @actual_agent AND subty = '0001' AND begda <= @sy-datum and endda >= @sy-datum.
    IF sy-subrc = 0.
SELECT SINGLE ename FROM pa0001 INTO @current_approval-approval_name WHERE pernr = @current_approval-approval_pernr AND begda <= @sy-datum and endda >= @sy-datum.
    ENDIF.
      ENDIF.
    get TIME STAMP FIELD current_approval-complete_ts.
    CASE APP_ID.
      WHEN '01'.
    UPDATE ZHCM_LR_APPROV set status = @status, complete_ts = @current_approval-complete_ts , approval_comment = @current_approval-approval_comment,approval_pernr = @current_approval-approval_pernr ,approval_name = @current_approval-approval_name
    WHERE request_uuid = @current_approval-request_uuid AND approval_seq = @current_approval-approval_seq.

      WHEN '02'.
          UPDATE ZHCM_ov_APPROV set status = @status, complete_ts = @current_approval-complete_ts , approval_comment = @current_approval-approval_comment,approval_pernr = @current_approval-approval_pernr ,approval_name = @current_approval-approval_name
    WHERE request_uuid = @current_approval-request_uuid AND approval_seq = @current_approval-approval_seq.

      WHEN OTHERS.
    ENDCASE.
    COMMIT WORK and  wait.
    IF status = 'REJECTED'.
      CASE APP_ID.
        WHEN '01'.

      UPDATE ZHCM_LEAVE_REQ SET req_status = '3' WHERE request_uuid = @current_approval-request_uuid.
        WHEN '02'.

      UPDATE zhcm_overt_req SET req_status = '3' WHERE request_uuid = @current_approval-request_uuid.
        WHEN OTHERS.
      ENDCASE.
      COMMIT WORK AND WAIT.

    ENDIF.
  endmethod.
ENDCLASS.
