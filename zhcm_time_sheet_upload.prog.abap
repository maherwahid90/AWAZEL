*&---------------------------------------------------------------------*
*& Report ZHCM_TIME_SHEET_UPLOAD
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*

INCLUDE ZHCM_TIME_SHEET_UPLOAD_TOP              .    " Global Data
START-OF-SELECTION.
PERFORM Process_data.
PERFORM BUILD_FCAT.
PERFORM ALV_DISPLAY.

 INCLUDE ZHCM_TIME_SHEET_UPLOAD_F01              .  " FORM-Routines
