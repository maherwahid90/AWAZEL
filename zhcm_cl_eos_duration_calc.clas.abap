class ZHCM_CL_EOS_DURATION_CALC definition
  public
  create public .

public section.

  interfaces IF_BADI_INTERFACE .
  interfaces IF_HRPAYSA_EOS_SER_DURATION .
protected section.
private section.
ENDCLASS.



CLASS ZHCM_CL_EOS_DURATION_CALC IMPLEMENTATION.


  METHOD IF_HRPAYSA_EOS_SER_DURATION~CALCULATE_SERVICE_DURATION.

* This code snippet calculates service duration in days
* Every month is assumed to consist of 30 days in this scenario
    DATA: lv_difference_year  TYPE pea_scryy,
          lv_difference_month TYPE pea_scrmm,
          lv_difference_days  TYPE pea_scrdd.

* Calculate difference in days
    CALL FUNCTION 'HR_HK_DIFF_BT_2_DATES'
      EXPORTING
        date1                       = i_termination_date
        date2                       = i_hire_date
        output_format               = '05'
      IMPORTING
        years                       = lv_difference_year
        months                      = lv_difference_month
        days                        = lv_difference_days
      EXCEPTIONS
        overflow_long_years_between = 1
        invalid_dates_specified     = 2
        OTHERS                      = 3.
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.
    data e_tage(4) type N.
CALL FUNCTION 'LEAP_DAYS_BETWEEN_TWO_DATES'
  EXPORTING
    I_DATUM_BIS       = i_termination_date
    I_DATUM_VON       = i_hire_date
 IMPORTING
   E_TAGE            = E_TAGE
          .
*i_leap_days = E_TAGE.
    e_service_duration = ( lv_difference_days +
                         ( lv_difference_month * 30 ) +
                         ( lv_difference_year * 360 ) )
                         - i_unpaid_days - i_invalid_days + E_TAGE -  i_leap_days.

  ENDMETHOD.
ENDCLASS.
