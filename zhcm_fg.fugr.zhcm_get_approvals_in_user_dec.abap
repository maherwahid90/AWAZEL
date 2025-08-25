FUNCTION ZHCM_GET_APPROVALS_IN_USER_DEC.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  TABLES
*"      AC_CONTAINER STRUCTURE  SWCONT OPTIONAL
*"      ACTOR_TAB STRUCTURE  SWHACTOR
*"  EXCEPTIONS
*"      NO_ACTIVE_PLVAR
*"      NO_ACTOR_FOUND
*"      EXCEPTION_OF_ROLE_RAISED
*"      NO_VALID_AGENT_DETERMINED
*"      NO_CONTAINER
*"----------------------------------------------------------------------

  INCLUDE <CNTN01>.

* define variables stored in container
  DATA: current_approval type zhcm_lr_approv,
        APP_ID TYPE zhcm_app_id,
        ACTOR_WA LIKE LINE OF actor_tab.

  REFRESH ACTOR_TAB.
  CLEAR ACTOR_TAB.

* convert persistent container to runtime container
  SWC_CONTAINER_TO_RUNTIME AC_CONTAINER.

* read elements out of container
  SWC_GET_ELEMENT AC_CONTAINER 'CURRENT_APPROVAL' current_approval.
  SWC_GET_ELEMENT AC_CONTAINER 'APP_ID' app_id.

  CASE APP_ID.
    WHEN '01'.
      SELECT SINGLE PERNR FROM zhcm_leave_req INTO @DATA(PERNR) WHERE request_uuid = @current_approval-request_uuid.
    WHEN '02'.
SELECT SINGLE PERNR FROM zhcm_overt_req INTO @PERNR WHERE request_uuid = @current_approval-request_uuid.
  ENDCASE.

   SELECT SINGLE * FROM zhcm_ess_approv INTO @DATA(ESS_APPROVAL) WHERE APP_ID = @APP_ID AND approver_seq = @current_approval-approval_seq.
* exception and parameter handling
  IF SY-SUBRC NE 0.
    RAISE no_actor_found.
  ELSE.
    CASE ess_approval-approver_type.
    WHEN '01'.
SELECT SINGLE ZHCM_EMP_APPROV~APPROVAL_EMP as OBJID from ZHCM_EMP_APPROV
into @actor_wa-objid
wHERE
  zhcm_emp_approv~pernr = @pernr .
  actor_wa-otype = 'P'.
  APPEND actor_wa TO actor_tab.
  CLEAR ACTOR_WA.
when '02'.
actor_wa-objid = ess_approval-pernr.
 actor_wa-otype = 'P'.
  APPEND actor_wa TO actor_tab.
  CLEAR ACTOR_WA.
when '03'.
actor_wa-objid = ess_approval-plans.
 actor_wa-otype = 'S'.
  APPEND actor_wa TO actor_tab.
  CLEAR ACTOR_WA.


WHEN '04'.
SELECT  PERNR from zhcm_approv_r_l INto @DATA(RULE_PERNR) WHERE  APPROVER_RULE = @ess_approval-approver_rule.
  actor_wa-objid = rule_pernr.
 actor_wa-otype = 'P'.
  APPEND actor_wa TO actor_tab.
  CLEAR ACTOR_WA.
ENDSELECT.
    ENDCASE.
  ENDIF.
ENDFUNCTION.
