FUNCTION ZHCM_SIMULATE_OVERT_TIME.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(PERNR) TYPE  PERNR_D
*"     VALUE(ANZHL) TYPE  ANZHL
*"     VALUE(BEGDA) TYPE  BEGDA
*"  EXPORTING
*"     VALUE(RETURN) TYPE  BAPIRET1
*"     VALUE(KEY) TYPE  BAPIPAKEY
*"----------------------------------------------------------------------

DATA:p0015 type p0015.

P0015-PERNR = PERNR.
P0015-BEGDA = P0015-ENDDA = BEGDA.
P0015-SUBTY = P0015-LGART = '3005'.
P0015-anzhl = anzhl.
P0015-ZEINH = '001'.

CALL FUNCTION 'BAPI_EMPLOYEE_ENQUEUE'
  EXPORTING
    number        = pernr
* IMPORTING
*   RETURN        = lock_ret
          .
CALL FUNCTION 'HR_PSBUFFER_INITIALIZE'
          .

CALL FUNCTION 'HR_INFOTYPE_OPERATION'
  EXPORTING
    infty                  = '0015'
    number                 = pernr
*   SUBTYPE                =
*   OBJECTID               =
*   LOCKINDICATOR          =
*   VALIDITYEND            =
*   VALIDITYBEGIN          =
*   RECORDNUMBER           =
    record                 = P0015
    operation              = 'INS'
*   TCLAS                  = 'A'
*   DIALOG_MODE            = '0'
   NOCOMMIT               = 'X'
*   VIEW_IDENTIFIER        =
*   SECONDARY_RECORD       =
 IMPORTING
   RETURN                 = RETURN
   KEY                    = key
          .


CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'
* IMPORTING
*   RETURN        =
          .



  CALL FUNCTION 'BAPI_EMPLOYEE_DEQUEUE'
    EXPORTING
      number        = pernr
*   IMPORTING
*     RETURN        =
            .
ENDFUNCTION.
