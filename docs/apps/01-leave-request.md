# Leave Request (ESS)

Employee Self-Service Fiori app that lets an employee submit, track and (while in draft) edit a
leave/absence request, attach supporting documents, and see the multi-level approval chain and
their real-time leave balance. Fully built on the **RAP managed model with draft** — see
[../README.md](../README.md) for the shared 5-layer architecture pattern this app defines.

* Fiori Launchpad semantic object: `zhcm_leave_req`, action `DISPLAY` (see
  `zhcm_leave_req.wapa.manifest.json`).
* `APP_ID = '01'` in the shared approval engine (doc 05).
* SAP Business Workflow template **`WS95000002`**.

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app | `zhcm_leave_req` (List Report / Object Page, `@sap/generator-fiori:lrop`) | `zhcm_leave_req.wapa.*` |
| Service binding | `ZHCM_C_LR_SB` (OData v2), `ZHCM_C_LR_SB_V4` (OData v4) | `zhcm_c_lr_sb*.srvb.xml`, `zhcm_c_lr_sb*.iw*.xml` |
| Service definition | `ZHCM_C_LR_SD` — "Service Definition for Leave Request" | `zhcm_c_lr_sd.srvd.xml` |
| Projection CDS | `zhcm_c_lr` (root), `zhcm_c_lr_att`, `zhcm_c_lr_approvals` | `zhcm_c_lr*.ddls.asddls` |
| Projection BDEF | `zhcm_c_lr` — `projection implementation in class zbp_hcm_c_lr` | `zhcm_c_lr.bdef.asbdef` |
| UI metadata ext. | Fiori Elements annotations (facets, line items, data points) | `zhcm_c_lr_me.ddlx.asddlxs`, `zhcm_c_lr_att_me`, `zhcm_c_lr_approvals_me` |
| Projection behavior class | `ZBP_HCM_C_LR` (`augment_create`) | `zbp_hcm_c_lr.clas.locals_imp.abap` |
| Interface CDS | `zhcm_i_lr` (root), `zhcm_i_lr_att`, `zhcm_i_lr_approvals` | `zhcm_i_lr*.ddls.asddls` |
| Interface BDEF | `zhcm_i_lr` — `managed implementation in class zbp_hcm_i_lr_bd`, `strict(2)`, `with draft` | `zhcm_i_lr.bdef.asbdef` |
| Interface behavior class | `ZBP_HCM_I_LR_BD` (determinations, validation, saver) | `zbp_hcm_i_lr_bd.clas.locals_imp.abap` |
| Active table | `ZHCM_LEAVE_REQ` | `zhcm_leave_req.tabl.xml` |
| Draft table | `ZHCM_DR_LR` | `zhcm_dr_lr.tabl.xml` |
| Approvals sub-table | `ZHCM_LR_APPROV` (+ draft `ZHCM_DR_LR_APS`) | `zhcm_lr_approv.tabl.xml` |
| Attachment sub-table | `ZHCM_LR_ATTACH` (+ draft `ZHCM_DR_LR_AT`) | `zhcm_lr_attach.tabl.xml` |
| Workflow log | `ZHCM_LR_WFLOG` | `zhcm_lr_wflog.tabl.xml` |
| Infotype exit | `ZCL_IM_HCM_LEAVE_REQ_VALID` (BAdI `HRPAD00INFTY`) | `zcl_im_hcm_leave_req_valid.clas.abap` |
| Messages | Message class `ZHCM_MSGS` (`000`–`007`, `010`) | `zhcm_msgs.msag.xml` |

## Data model (`ZHCM_LEAVE_REQ`)

Key: `MANDT`, `REQUEST_UUID` (RAP semantic key). Notable fields:

| Field | Type | Purpose |
|---|---|---|
| `REQUEST_ID` (`ZHCM_REQ_NO`) | numeric | Sequential, human-readable request number (see numbering below) |
| `PERNR` | `PERNR_D` | Requesting employee |
| `HIRE_DATE` | `BEGDA` | Cached at creation from `RP_GET_HIRE_DATE` |
| `AWART` | `AWART` | Absence type (leave type) |
| `BEGDA` / `ENDDA` | `BEGDA`/`ENDDA` | Requested period |
| `ABWTG` / `KALTG` | `ABWTG`/`KALTG` | Working days / calendar days (calculated, read-only) |
| `SUBT_EMP` | `PERNR_D` | Replacement/substitute employee during the leave |
| `ENTITLE` / `DEDUCT` / `PENDINGREQ` / `REST` | `DEC(10,2)` | Live leave-balance snapshot (annual leave only) |
| `REQ_STATUS` | `ZHCM_REQ_STATUS` | `1` In Progress · `2` Approved · `3` Rejected · `4` Posted Successfully · `5` Errors In Posting |
| `WORKITEM_ID` / `RETURN_CODE` | `SWW_WIID`/`SYST_SUBRC` | Workflow work item started for this request |

## Behavior definition highlights (`zhcm_i_lr.bdef`)

* `strict(2)`, `with draft`, persistent table `ZHCM_LEAVE_REQ`, draft table `ZHCM_DR_LR`,
  **`with additional save`** (custom save logic runs after the standard persist — see below).
* Operations: `create`, `update(features: instance)`, `delete(features: instance)`.
* Two internal actions used only by determinations: `recalculateAbsence`, `recalculateBalance`.
* Determinations: `setRequestNumber on save`, `calculateAbsence on modify` (fields `Awart`,
  `Begda`, `Endda`), `calculateBalance on modify` (field `Awart`).
* Side effects: `Awart` → refreshes `Kaltg`, `Abwtg`, `entitle`, `deduct`, `pendingreq`, `rest`;
  `Begda`/`Endda` → refresh `Kaltg`, `Abwtg`.
* Validation `validateDates on save`.
* Mandatory fields: `Pernr`, `Awart`, `Begda`, `Endda`.
* Draft actions: `Prepare`, `resume`, `Edit`, `Activate optimized`, `Discard` (standard RAP
  draft lifecycle).

## Business logic (`ZBP_HCM_I_LR_BD` / `lhc_LR`)

* **`get_instance_features`** — makes derived/read-only fields non-editable (`Pernr`, `Abwtg`,
  `Kaltg`, `hiredate`, `PlansTxt`, `OrgehTxt`, `entitle`, `deduct`, `pendingreq`, `rest`,
  `RequestId`); update/delete are only enabled while the instance is a draft.
* **`setRequestNumber`** (on save) — idempotent: skips rows that already have a `RequestId`;
  computes `MAX(request_id) + 1` per row over `ZHCM_LEAVE_REQ` (i.e. a simple max+1 sequence,
  **not** an SNRO number-range object — a new request type should follow the same simple
  pattern unless a strict gapless number range is required).
* **`calculateAbsence` / `recalculateAbsence`** — calls FM `ZHCM_GET_ABSENCE_CALENDAR_DAYS`
  (wraps standard `HR_ABS_ATT_TIMES_AT_ENTRY`) to compute `Abwtg` (working/absence days) and
  `Kaltg` (calendar days) for the chosen `Awart`/`Begda`/`Endda`.
* **`calculateBalance` / `recalculateBalance`** — only for annual leave (`Awart = '1000'`):
  calls BAPI `BAPI_TIMEQUOTA_GETDETAILEDLIST` (quota type `01`) to get `entitle`/`deduct`/`rest`
  as of today, then subtracts the sum of the employee's own **pending** (`req_status = 1`)
  annual-leave requests to get a true "available to request" balance (`rest`). For all other
  leave types the four balance fields are simply zeroed.
* **`validateDates`** (validation on save) — in order:
  1. **Attachment required** unless `Awart` is one of `1000`, `1002`, `1003`, `1008` — message
     `ZHCM_MSGS 007` ("Attachment is required for this Request").
  2. **No overlapping request**: another of the employee's own leave requests
     (`req_status IN ('1','2','4','5')`, i.e. anything except rejected) with dates overlapping
     `Begda`–`Endda` → message `004` ("There is a request conflict with this date range with
     no( &1 )").
  3. **No existing IT2001 record** in that date range (`PA2001`) → message `006` ("There is a
     leave saved within the date range you entered.").
  4. `Endda < Begda` → message `003` ("Begin date is greater than End date.").
  5. Otherwise, **simulates** the absence posting via `BAPI_PTMGRATTABS_MNGCREATION` with
     `simulate = 'X'`; any error returned is surfaced as a field-level message on `Awart`/
     `Begda`/`Endda`. This guarantees a request that passes validation can later be posted for
     real without a payroll/time-evaluation surprise.
* **`ZCL_IM_HCM_LEAVE_REQ_VALID`** (BAdI `HRPAD00INFTY`, method `AFTER_INPUT`) — a
  complementary check that fires when infotype **2001** (Absences) is actually maintained
  (whether via this app's eventual posting or directly in PA30/PA20):
  * Subtype `1000`/`1004` (Annual/Marriage leave): must start ≥ 3 months after hire date
    (msg `000`), unless authorization object `ZHCM_2001` is granted to the user.
  * Subtype `1005` (Hajj leave): must start ≥ 2 years after hire date (msg `002`), and an
    employee can only take it **once ever** (msg `001`, checked via `PA2001` subtype `1005`).
  * Subtype `1011` (Exam leave): only allowed for Saudi nationals (`PA0002-NATIO = 'SA'`,
    msg `005`).

## Save / submit flow (`lsc_zhcm_i_lr~save_modified`, additional save)

On `CREATE`, for every newly created leave request:

1. `ZHCM_UPDATE_APPROVALS(status = 'I', app_id = '01')` — builds the multi-level approval chain
   for the request from `ZHCM_ESS_APPROV` and inserts it into `ZHCM_LR_APPROV` (see doc 05).
2. `SAP_WAPI_START_WORKFLOW(task = 'WS95000002')` with container `RequestUuid`, `ENAME`,
   `APP_ID = '01'` — starts the leave-approval workflow.
3. If the workflow fails to start, the approval chain rows are rolled back
   (`ZHCM_UPDATE_APPROVALS(status = 'D', ...)`) and the workflow engine's error messages are
   reported back on the entity.
4. On success, `WORKITEM_ID`/`RETURN_CODE` are written back to the request and logged via
   `ZHCM_UPDATE_WORKITEM` into `ZHCM_LR_WFLOG`.

## Create defaulting (`ZBP_HCM_C_LR` — projection `augment_create`)

When a new leave request is created from the Fiori app, before persistence:

* `ReqStatus` defaults to `'1'` (In Progress).
* `Pernr` is looked up from **`PA0105`** (Communication infotype) where `USRID = sy-uname` and
  the record is valid today — i.e. **the logged-on Fiori user is resolved to a personnel
  number via their SAP username stored in IT0105**, not via a 1:1 SU01↔PERNR link.
* `HireDate` via `RP_GET_HIRE_DATE`.
* `ename`, `PlansTxt` (position text), `OrgehTxt` (org unit text) via `zhcm_employee_help`.
* The balance-fields defaulting block (`BAPI_TIMEQUOTA_GETDETAILEDLIST`) is present but
  **commented out** here — balances are instead computed later by `calculateBalance` in the
  interface layer.

## UI (`zhcm_c_lr_me.ddlx`)

Object page facets: header data points for `SubtEmp` (replacement), `ReqStatus` (criticality
colored) and `REST` (balance); field groups "Leave Data" (type, dates, absence/calendar days,
remarks, replacement) and "Balance" (entitlement/deducted/pending/rest, `rest` rendered as a
`#PROGRESS` data point with `targetValue: 150`); line-item facets for `_Attachment` and
`_Approval` (approval rows show `StatusCrit` criticality: Approved=3/green, Rejected=1/red,
else=5/neutral, from `zhcm_i_lr_approvals`). List report is sorted by `RequestId` descending.

## Value helps used

* `Awart` → `zhcm_absence_types_cds` (leave type texts).
* `SubtEmp` → `zhcm_employee_help` (replacement employee).
* `ReqStatus` → `zhcm_req_status_view`.

## Related tcodes / config

* Approval routing per level for `APP_ID = '01'` is configured via tcode **`ZHCM_APPROVALS`**
  (SM30 on `ZHCM_ESS_APPROV`) — see [05-approvals-and-rules.md](05-approvals-and-rules.md).
* Direct-manager mapping via tcode **`ZHCM_EMP_MANAGER`** (SM30 on `ZHCM_EMP_APPROV`).
