*&---------------------------------------------------------------------*
*& Report ZHCM_TIME_MACHINE_INTEGRATION
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*

INCLUDE ZHCM_TIME_MACHINE_TOP                   .    " Global Data
PERFORM GET_TIME_DATA.
PERFORM POST_TIME.
PERFORM SEND_ERROR_NOTIFICATION.
* INCLUDE ZHCM_TIME_MACHINE_O01                   .  " PBO-Modules
* INCLUDE ZHCM_TIME_MACHINE_I01                   .  " PAI-Modules
 INCLUDE ZHCM_TIME_MACHINE_F01                   .  " FORM-Routines
