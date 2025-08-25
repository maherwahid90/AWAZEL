FUNCTION zhcm_update_approvals.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(REQUESTUUID) TYPE  SYSUUID_X16
*"     VALUE(PERNR) TYPE  PERNR_D
*"     VALUE(STATUS) TYPE  CHAR1
*"     VALUE(APP_ID) TYPE  ZHCM_APP_ID
*"----------------------------------------------------------------------



DATA:approvals_it type table of zhcm_lr_approv ,
     approval_wa like LINE OF approvals_it.
IF status = 'I'.

SELECT * FROM zhcm_ess_approv INto TABLE @data(approvals_lev) where app_id = @app_id order by approver_seq.
LOOP AT approvals_lev INTO DATA(level_wa).
approval_wa-request_uuid = requestuuid.
IF sy-tabix = 1.
get TIME STAMP FIELD approval_wa-receive_ts.
ENDIF.
approval_wa-approval_seq = level_wa-approver_seq.
CASE level_wa-approver_type.
WHEN '01'.
SELECT SINGLE ZHCM_EMP_APPROV~APPROVAL_EMP as approval_pernr ,pa0001~ename as approval_name from ZHCM_EMP_APPROV INNER join pa0001 on pa0001~pernr = ZHCM_EMP_APPROV~approval_emp
into ( @approval_wa-approval_pernr,@approval_wa-approval_name )
wHERE
  zhcm_emp_approv~pernr = @pernr AND pa0001~begda <= @sy-datum AND pa0001~endda >= @sy-datum.
when '02'.
SELECT SINGLE pa0001~pernr as approval_pernr , pa0001~ename as approval_name from  pa0001
into ( @approval_wa-approval_pernr,@approval_wa-approval_name )
wHERE
  pa0001~pernr = @level_wa-pernr AND pa0001~begda <= @sy-datum AND pa0001~endda >= @sy-datum.
when '03'.
SELECT SINGLE pa0001~pernr as approval_pernr , pa0001~ename as approval_name from  pa0001
into ( @approval_wa-approval_pernr,@approval_wa-approval_name )
wHERE
  pa0001~plans = @level_wa-plans AND pa0001~begda <= @sy-datum AND pa0001~endda >= @sy-datum.

WHEN '04'.
SELECT single rule_name from ZHCM_APPROV_R INto @approval_wa-approval_name WHERE  APPROVER_RULE = @level_wa-approver_rule.

ENDCASE.
APPEND approval_wa to approvals_it.
clear approval_wa.
ENDLOOP.

case app_id.
  when '01'.

MODIFY zhcm_lr_approv FROM TABLE approvals_it.
when '02'.
MODIFY zhcm_ov_approv FROM TABLE approvals_it.
endcase.
COMMIT WORK AND WAIT.
ELSEIF status = 'D'.
case app_id.
  when '01'.

  delete from zhcm_lr_approv WHERE request_uuid = @requestuuid.
  when '02'.
    delete from zhcm_ov_approv WHERE request_uuid = @requestuuid.
endcase.
  COMMIT WORK AND WAIT.
  endif.





ENDFUNCTION.
