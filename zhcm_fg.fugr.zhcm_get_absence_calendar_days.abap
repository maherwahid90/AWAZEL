FUNCTION ZHCM_GET_ABSENCE_CALENDAR_DAYS.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(PERNR) TYPE  PERNR_D
*"     VALUE(AWART) TYPE  AWART
*"     VALUE(BEGDA) TYPE  BEGDA
*"     VALUE(ENDDA) TYPE  ENDDA
*"  EXPORTING
*"     VALUE(ABWTG) TYPE  ABWTG
*"     VALUE(KALTG) TYPE  KALTG
*"----------------------------------------------------------------------


DATA:M0001 TYPE TABLE OF P0001,
      M0000	TYPE TABLE OF	P0000,
M0002	TYPE TABLE OF	P0002,
M0007	TYPE TABLE OF	P0007,
M2001	TYPE TABLE OF	P2001,
M2002	TYPE TABLE OF	P2002,
M2003	TYPE TABLE OF	P2003,
PWS	TYPE TABLE OF	PTPSP,
TIMES_PER_DAY	TYPE TABLE OF	PTM_TIMES_PER_DAY,
BEGUZ LIKE  P2001-BEGUZ,
ENDUZ LIKE  P2001-ENDUZ,
VTKEN LIKE  P2001-VTKEN,
STDAZ LIKE  P2001-STDAZ.


SELECT * FROM PA0001 INTO CORRESPONDING FIELDS OF TABLE @M0001 WHERE PERNR = @PERNR.
CALL FUNCTION 'HR_ABS_ATT_TIMES_AT_ENTRY'
  EXPORTING
    pernr                    = PERNR
    awart                    = awart
    begda                    = BEGDA
    endda                    = ENDDA
*   USE_VARIANT              = 'X'
 IMPORTING
   ABWTG                    = ABWTG
*   ABRTG                    =
*   ABRST                    =
   KALTG                    = KALTG
*   HRSIF                    =
*   ALLDF                    =
*   ERROR_WO_EXCEPTION       =
  TABLES
    m0000                    = M0000
    m0001                    = M0001
    m0002                    = M0002
    m0007                    = M0007
    m2001                    = M2001
    m2002                    = M2002
    m2003                    = M2003
*   PWS                      =
    times_per_day            = TIMES_PER_DAY
  CHANGING
    beguz                    = BEGUZ
    enduz                    = ENDUZ
    vtken                    = VTKEN
    stdaz                    = STDAZ
*   BREAKS                   =
*   NXDFL                    =
*   START_BEF_ZERO           =
*   CV_ABSATT_NEXT_DAY       = ABAP_FALSE
 EXCEPTIONS
   IT0001_MISSING           = 1
   CUSTOMIZING_ERROR        = 2
   ERROR_OCCURRED           = 3
   END_BEFORE_BEGIN         = 4
   OTHERS                   = 5
          .
IF sy-subrc <> 0.
* Implement suitable error handling here
ENDIF.


ENDFUNCTION.
