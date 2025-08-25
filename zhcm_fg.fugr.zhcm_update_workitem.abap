function zhcm_update_workitem.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(REQUESTUUID) TYPE  SYSUUID_X16
*"     VALUE(WORKITEM_ID) TYPE  SWW_WIID
*"     VALUE(RETURN_CODE) TYPE  SYST_SUBRC
*"     VALUE(REQUESTID) TYPE  ZHCM_REQ_NO
*"     VALUE(PERNR) TYPE  PERNR_D
*"     VALUE(APP_ID) TYPE  ZHCM_APP_ID
*"----------------------------------------------------------------------

data lr_wf type zhcm_lr_wflog.
lr_wf-request_uuid = requestuuid.
lr_wf-workitem_id = workitem_id.
lr_wf-return_code = return_code.
lr_wf-app_id = app_id.
insert into zhcm_lr_wflog VALUES lr_wf.
COMMIT WORK AND WAIT.





ENDFUNCTION.
