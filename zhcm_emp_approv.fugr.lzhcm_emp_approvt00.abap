*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZHCM_EMP_APPROV.................................*
DATA:  BEGIN OF STATUS_ZHCM_EMP_APPROV               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZHCM_EMP_APPROV               .
CONTROLS: TCTRL_ZHCM_EMP_APPROV
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZHCM_EMP_APPROV               .
TABLES: ZHCM_EMP_APPROV                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
