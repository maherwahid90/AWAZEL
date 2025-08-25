*&---------------------------------------------------------------------*
*& Include ZHCM_TIME_MACHINE_TOP                    - Report ZHCM_TIME_MACHINE_INTEGRATION
*&---------------------------------------------------------------------*
REPORT ZHCM_TIME_MACHINE_INTEGRATION.

DATA:TIME_IT TYPE TABLE OF ZHCM_TIMEM_DATA,
      TIME_WA LIKE LINE OF TIME_IT,
      wa_2011 TYPE p2011,
      LTIME_ST TYPE CHAR8,
 return      TYPE bapireturn1.
