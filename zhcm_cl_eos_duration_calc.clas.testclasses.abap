*"* use this source file for your ABAP unit test classes

*************************************************************************************************************
* Code Under Test (original class with some minor redefinitions for test double injection)
*************************************************************************************************************
CLASS lct_main_testclass DEFINITION DEFERRED.

CLASS lct_hrpaysa_eos_serv_duration DEFINITION
      INHERITING FROM zhcm_cl_eos_duration_calc
      FRIENDS lct_main_testclass.
  PUBLIC SECTION.
    METHODS setup_with_test_double.
ENDCLASS.

CLASS lct_hrpaysa_eos_serv_duration IMPLEMENTATION.
  METHOD setup_with_test_double.
  ENDMETHOD. "setup_with_test_double.
ENDCLASS.

*************************************************************************************************************
* ABAP Unit Test Class
*************************************************************************************************************
CLASS lct_main_testclass DEFINITION FOR TESTING
      RISK LEVEL HARMLESS DURATION SHORT
      INHERITING FROM cl_aunit_assert.

  PUBLIC SECTION.
    DATA: mo_message_handler TYPE REF TO if_hrbas_message_handler.
    DATA: lv_service_duration TYPE pranz.

  PRIVATE SECTION.
    DATA: lo_eos             TYPE REF TO lct_hrpaysa_eos_serv_duration.
    DATA: mv_message_counter TYPE sy-index.
    DATA: la_p0001           TYPE p0001.

    METHODS setup_test.
    METHODS test_date_month  FOR TESTING.
    METHODS test_date_day    FOR TESTING.
    METHODS test_date_mix    FOR TESTING.
    METHODS test_date_simple FOR TESTING.
ENDCLASS.

CLASS lct_main_testclass IMPLEMENTATION.
  METHOD setup_test.
    CREATE OBJECT lo_eos.
  ENDMETHOD.

  METHOD test_date_month.

    setup_test( ).
    lo_eos->if_hrpaysa_eos_ser_duration~calculate_service_duration( EXPORTING i_hijri            = abap_true
                                                                              i_p0001            = la_p0001
                                                                              i_termination_date = '20140512'
                                                                              i_hire_date        = '20101111'
                                                                    IMPORTING e_service_duration = lv_service_duration ).
    cl_aunit_assert=>assert_equals( EXPORTING exp = '1299'
                                              act = lv_service_duration
                                              msg = 'Difference in Months' quit = 0 ).

  ENDMETHOD.

  METHOD test_date_day.

    setup_test( ).
    lo_eos->if_hrpaysa_eos_ser_duration~calculate_service_duration( EXPORTING i_hijri            = abap_true
                                                                              i_p0001            = la_p0001
                                                                              i_termination_date = '20140512'
                                                                              i_hire_date        = '20100419'
                                                                    IMPORTING e_service_duration = lv_service_duration ).
    cl_aunit_assert=>assert_equals( EXPORTING exp = '1508'
                                              act = lv_service_duration
                                              msg = 'Difference in Days' quit = 0 ).
  ENDMETHOD.

  METHOD test_date_mix.

    setup_test( ).
    lo_eos->if_hrpaysa_eos_ser_duration~calculate_service_duration( EXPORTING i_hijri            = abap_true
                                                                              i_p0001            = la_p0001
                                                                              i_termination_date = '20140512'
                                                                              i_hire_date        = '20101119'
                                                                    IMPORTING e_service_duration = lv_service_duration ).
    cl_aunit_assert=>assert_equals( EXPORTING exp = '1291'
                                              act = lv_service_duration
                                              msg = 'Difference in Months and Days' quit = 0 ).
  ENDMETHOD.

  METHOD test_date_simple.

    setup_test( ).
    lo_eos->if_hrpaysa_eos_ser_duration~calculate_service_duration( EXPORTING i_hijri            = abap_true
                                                                              i_p0001            = la_p0001
                                                                              i_termination_date = '20191230'
                                                                              i_hire_date        = '20131105'
                                                                    IMPORTING e_service_duration = lv_service_duration ).
    cl_aunit_assert=>assert_equals( EXPORTING exp = '2283'
                                              act = lv_service_duration
                                              msg = 'Difference in Simple Example' quit = 0 ).
  ENDMETHOD.
ENDCLASS.
