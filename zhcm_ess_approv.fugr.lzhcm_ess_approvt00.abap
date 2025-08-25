*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZHCM_ESS_APPROV.................................*
DATA:  BEGIN OF STATUS_ZHCM_ESS_APPROV               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZHCM_ESS_APPROV               .
CONTROLS: TCTRL_ZHCM_ESS_APPROV
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZHCM_ESS_APPROV               .
TABLES: ZHCM_ESS_APPROV                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
