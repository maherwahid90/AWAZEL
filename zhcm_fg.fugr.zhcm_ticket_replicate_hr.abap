FUNCTION ZHCM_TICKET_REPLICATE_HR.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(REQUESTUUID) TYPE  SYSUUID_X16
*"----------------------------------------------------------------------
* Called once a Tickets Request has been approved (REQ_STATUS = '2'),
* to replicate the approved request - header and family/companion data -
* into the HR-facing tables (ZHCM_TKT_HR / ZHCM_TKT_HR_FAM), per the FS:
* "HR: A custom table has been configured for HR. Once a request is
* approved, it will be automatically replicated in the system."
*
* NOTE: this repository does not contain the ABAP for the workflow step
* that finalizes an approval decision (the same is true for how Leave
* Request / Overtime Request ultimately set REQ_STATUS to Approved) -
* that step should call this function module after setting
* ZHCM_TICKET_REQ-REQ_STATUS = '2'.

DATA: header TYPE zhcm_ticket_req,
      hr_hd  TYPE zhcm_tkt_hr,
      hr_fam TYPE TABLE OF zhcm_tkt_hr_fam,
      fam_wa LIKE LINE OF hr_fam.

SELECT SINGLE * FROM zhcm_ticket_req INTO @header WHERE request_uuid = @requestuuid.
IF sy-subrc <> 0.
  RETURN.
ENDIF.

hr_hd-request_uuid   = header-request_uuid.
hr_hd-request_id     = header-request_id.
hr_hd-pernr          = header-pernr.
hr_hd-ticket_type     = header-ticket_type.
hr_hd-begda          = header-begda.
hr_hd-endda          = header-endda.
hr_hd-direction      = header-direction.
hr_hd-destination    = header-destination.
hr_hd-route          = header-route.
GET TIME STAMP FIELD hr_hd-replicated_at.
hr_hd-replicated_by  = sy-uname.

MODIFY zhcm_tkt_hr FROM hr_hd.

SELECT family_uuid, request_uuid, first_name, last_name, birthdate, age, passport_no
  FROM zhcm_tkt_family
  WHERE request_uuid = @requestuuid
  INTO TABLE @DATA(family_it).

LOOP AT family_it INTO DATA(family_wa).
  CLEAR fam_wa.
  fam_wa-request_uuid = family_wa-request_uuid.
  fam_wa-family_uuid  = family_wa-family_uuid.
  fam_wa-first_name   = family_wa-first_name.
  fam_wa-last_name    = family_wa-last_name.
  fam_wa-birthdate    = family_wa-birthdate.
  fam_wa-age          = family_wa-age.
  fam_wa-passport_no  = family_wa-passport_no.
  APPEND fam_wa TO hr_fam.
ENDLOOP.

IF hr_fam IS NOT INITIAL.
  MODIFY zhcm_tkt_hr_fam FROM TABLE hr_fam.
ENDIF.

COMMIT WORK AND WAIT.

ENDFUNCTION.
