"Name: \PR:HSACALC0\FO:GET_DIF_DAYS\SE:END\EI
ENHANCEMENT 0 ZHCM_ENH_DIFF_DAYS_THIRTY.
*
  if from_day+6(2) = '01'.

data:lv_last_day type dats.

CALL FUNCTION 'HR_HR_LAST_DAY_OF_MONTH'
  EXPORTING
    day_in                  = to_day
 IMPORTING
   LAST_DAY_OF_MONTH       = lv_last_day
 EXCEPTIONS
   DAY_IN_NO_DATE          = 1
   OTHERS                  = 2
          .
IF sy-subrc <> 0.
* Implement suitable error handling here
ENDIF.

if to_day = lv_last_day.
cv_anzhl = 30.
endif.
endif.
ENDENHANCEMENT.
