*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZHCM_RULE_L_MV..................................*
TABLES: ZHCM_RULE_L_MV, *ZHCM_RULE_L_MV. "view work areas
CONTROLS: TCTRL_ZHCM_RULE_L_MV
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZHCM_RULE_L_MV. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZHCM_RULE_L_MV.
* Table for entries selected to show on screen
DATA: BEGIN OF ZHCM_RULE_L_MV_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZHCM_RULE_L_MV.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZHCM_RULE_L_MV_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZHCM_RULE_L_MV_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZHCM_RULE_L_MV.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZHCM_RULE_L_MV_TOTAL.

*.........table declarations:.................................*
TABLES: ZHCM_APPROV_R_L                .
