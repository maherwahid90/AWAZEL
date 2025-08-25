*&---------------------------------------------------------------------*
*& Include ZHCM_TIME_SHEET_UPLOAD_TOP               - Report ZHCM_TIME_SHEET_UPLOAD
*&---------------------------------------------------------------------*
REPORT ZHCM_TIME_SHEET_UPLOAD.
TYPE-POOLS: TRUXS.

SELECTION-SCREEN: BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-000.
PARAMETERS: S_FILE TYPE RLGRAP-FILENAME.
SELECTION-SCREEN: END OF BLOCK B1.

TYPES: BEGIN OF TY_STR,
pernr TYPE CHAR10,"pernr_d,
begda TYPE CHAR10,"begda,
LTIME TYPE char10,
satza TYPE RETYP,
END OF TY_STR.


TYPES: BEGIN OF alv_STR,
pernr TYPE CHAR10,"pernr_d,
begda TYPE CHAR10,"begda,
LTIME TYPE char10,
satza TYPE RETYP,
sap_pernr type pernr_d,
sap_begda type begda,
sap_ltime TYPE uzeit,
remarks type char250,
END OF alv_STR.

DATA: IT TYPE TABLE OF TY_STR,
IT_RAW TYPE TRUXS_T_TEXT_DATA,
IT_ERROR TYPE TABLE OF TY_STR,
alv_it TYPE TABLE OF alv_str,
alv_wa like LINE OF alv_it,
 wa_2011 TYPE p2011,
 return      TYPE bapireturn1,
 hours TYPE numc2,
 minutes TYPE numc2,
 seconds TYPE numc2,
ERROR_FILE TYPE STRING VALUE 'TEST.TXT'.

TYPE-POOLS:
   SLIS.
TYPES:
  T_FIELDCAT TYPE SLIS_FIELDCAT_ALV.


DATA :  W_FIELDCAT TYPE T_FIELDCAT,
       i_fieldcat         TYPE STANDARD TABLE OF t_fieldcat,
       w_layout TYPE slis_layout_alv.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR S_FILE.
CALL FUNCTION 'F4_FILENAME'
EXPORTING
FIELD_NAME = 'S_FILE'
PROGRAM_NAME = SY-CPROG
IMPORTING
FILE_NAME = S_FILE.
