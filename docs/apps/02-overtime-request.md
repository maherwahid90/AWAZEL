# Overtime Request (ESS/MSS)

Employee Self-Service app for an employee to request overtime hours for a given day, and for
the employee's **direct manager to approve the hours** directly inside the same object (a
manager-editable field on the same entity, not a separate approval app). Structurally a near
duplicate of [Leave Request](01-leave-request.md) — same RAP pattern, same shared building
blocks — with one distinguishing feature: a **RAP virtual element with an `if_sadl_exit`
read-exit** that turns the "manager hours" field on/off depending on who is looking at the
record.

* Fiori Launchpad semantic object referenced via `zhcm_overtime.wapa` (OData service
  `ZHCM_C_OVER_SB`).
* `APP_ID = '02'` in the shared approval engine (doc 05).
* SAP Business Workflow template **`WS95000003`**.

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app | `zhcm_overtime` | `zhcm_overtime.wapa.*` |
| Service binding | `ZHCM_C_OVER_SB` (v2), `ZHCM_C_OVER_SB_V4` (v4) | `zhcm_c_over_sb*.srvb.xml` |
| Service definition | `ZHCM_C_OVER_SD` | `zhcm_c_over_sd.srvd.xml` |
| Projection CDS | `zhcm_c_OVER` (root), `zhcm_c_OVER_att`, `zhcm_c_OVER_approvals` | `zhcm_c_over*.ddls.asddls` |
| Projection BDEF | `projection implementation in class zbp_hcm_c_OVER` | `zhcm_c_over.bdef.asbdef` |
| UI metadata ext. | `zhcm_c_over_me.ddlx`, `zhcm_c_over_att_me`, `zhcm_c_over_approvals_me` | `*.ddlx.asddlxs` |
| Projection behavior class | `ZBP_HCM_C_OVER` (`augment_create`) | `zbp_hcm_c_over.clas.locals_imp.abap` |
| Interface CDS | `zhcm_i_over` (root), `zhcm_i_over_att`, `zhcm_i_OVER_approvals` | `zhcm_i_over*.ddls.asddls` |
| Interface BDEF | `managed implementation in class zbp_hcm_i_over`, `strict(2)`, `with draft` | `zhcm_i_over.bdef.asbdef` |
| Interface behavior class | `ZBP_HCM_I_OVER` (`lhc_OVER`, `lsc_ZHCM_I_OVER`) | `zbp_hcm_i_over.clas.locals_imp.abap` |
| Active table | `ZHCM_OVERT_REQ` | `zhcm_overt_req.tabl.xml` |
| Draft table | `ZHCM_DR_OVER` | (see `zhcm_dr_ov_at`/`zhcm_dr_ov_aps` siblings) |
| Approvals sub-table | `ZHCM_OV_APPROV` (+ draft `ZHCM_DR_OV_APS`) | `zhcm_ov_approv.tabl.xml` |
| Attachment sub-table | `ZHCM_OV_ATTACH` (+ draft `ZHCM_DR_OV_AT`) | `zhcm_ov_attach.tabl.xml` |
| Virtual element exit | `ZHCM_OVER_CHECK_MANAGER_ANZHL` (`if_sadl_exit_calc_element_read`) | `zhcm_over_check_manager_anzhl.clas.abap` |
| Overtime simulation FM | `ZHCM_SIMULATE_OVERT_TIME` | `zhcm_fg.fugr.zhcm_simulate_overt_time.abap` |

## Data model (`ZHCM_OVERT_REQ`)

Same skeleton as `ZHCM_LEAVE_REQ` (`REQUEST_UUID`, `REQUEST_ID`, `PERNR`, `HIRE_DATE`,
`REMARKS`, `REQ_STATUS`, `WORKITEM_ID`, `RETURN_CODE`, standard RAP admin fields), plus the
overtime-specific fields:

| Field | Purpose |
|---|---|
| `BEGDA` | The single date the overtime was worked (no end date — overtime is per-day) |
| `EMP_ANZHL` | Overtime **hours requested by the employee** |
| `MANGER_ANZHL` | Overtime **hours approved/adjusted by the manager** (sic — "manger" is a typo of "manager" baked into the field name; keep it if extending this table) |

There is no `AWART`/absence-type — overtime posts to infotype **0015** (Additional Payments),
wage type/subtype `3005` (see `ZHCM_SIMULATE_OVERT_TIME`), not infotype 2001.

## Behavior definition highlights (`zhcm_i_over.bdef`)

* Same shape as Leave Request: `create`, `update(features: instance)`, `delete(features:
  instance)`, draft actions `Prepare`/`resume`/`Edit`/`Activate optimized`/`Discard`.
* `determination setRequestNumber on save` — identical max+1 pattern.
* `validation validateDates on save { field Begda; }`.
* Mandatory: `Pernr`, `Begda`, `emp_anzhl`. Read-only: `LocalLastChangedAt`, `LocalCreatedAt`,
  and the virtual field `manager_anzhl_h`.
* The absence-calculation determinations/side-effects/internal actions used by Leave Request
  are present in the BDEF **commented out** — overtime doesn't need calendar-day calculation,
  confirming this app was cloned from the Leave Request template and trimmed down.

## Business logic (`ZBP_HCM_I_OVER` / `lhc_OVER`)

* **`get_instance_features`** — beyond the standard read-only/draft-editable rules, this method
  implements the **role-based field switch** that is the app's key difference from Leave
  Request:
  1. Look up the request's owning `PERNR`.
  2. Look up whether the *current logged-on user* (`sy-uname`, matched via `PA0105` subtype
     `0001`) is that employee's **direct manager** in `ZHCM_EMP_APPROV`
     (`zhcm_emp_approv~pernr = request_pernr`, joined to `pa0105` on `approval_emp`).
  3. If the current user **is** the manager: `%update` is enabled, `emp_anzhl` and `Begda`
     become read-only, and **`manger_anzhl` becomes editable** — the manager can enter/adjust
     the approved overtime hours directly on the object.
  4. Otherwise (the requesting employee, or anyone else): `manger_anzhl` is read-only,
     `emp_anzhl` and `Begda` are mandatory/editable (normal request entry).
  This means the **same Fiori object page doubles as the employee's request screen and the
  manager's "approve/adjust hours" screen**, gated purely by whether the viewer is the
  configured direct manager — no separate approval UI is needed for the hours themselves (the
  workflow/approval log still tracks the formal approve/reject decision, see doc 05).
* **`setRequestNumber`** — identical max+1 pattern over `ZHCM_OVERT_REQ`.
* **`validateDates`** — in order:
  1. **Attachment required** (msg `007`) — unlike Leave Request there is no leave-type
     exemption list; every overtime request needs a supporting attachment.
  2. **No duplicate request** for the same employee/date with
     `req_status IN ('1','2','4','5')` (msg `004`).
  3. `Begda`/`emp_anzhl` initial → msg `010` ("Enter the Mandatory fields.").
  4. **Simulates** the posting via FM `ZHCM_SIMULATE_OVERT_TIME`, surfacing any BAPI error on
     `Begda`.

### `ZHCM_SIMULATE_OVERT_TIME` (simulation-only infotype write)

Builds a `P0015` (Additional Payments) record — `SUBTY`/`LGART = '3005'`, `ANZHL` = requested
hours, unit `'001'` — locks the employee (`BAPI_EMPLOYEE_ENQUEUE`), calls
`HR_INFOTYPE_OPERATION` with `operation = 'INS'` and `NOCOMMIT = 'X'`, then **always rolls back**
(`BAPI_TRANSACTION_ROLLBACK`) and unlocks the employee. This is a pure dry-run used purely to
surface infotype/time-constraint errors to the validation before the request is even submitted.

## Save / submit flow (`lsc_ZHCM_I_OVER~save_modified`, additional save)

Identical pattern to Leave Request, parameterized for overtime:
`ZHCM_UPDATE_APPROVALS(status = 'I', app_id = '02')` →
`SAP_WAPI_START_WORKFLOW(task = 'WS95000003')` → on failure roll back the approval chain
(`status = 'D'`) and report workflow errors, on success persist `WORKITEM_ID`/`RETURN_CODE` and
log via `ZHCM_UPDATE_WORKITEM`.

## Create defaulting (`ZBP_HCM_C_OVER` — projection `augment_create`)

Same as Leave Request: `ReqStatus = '1'`, `Pernr` from `PA0105` (`usrid = sy-uname`),
`HireDate` via `RP_GET_HIRE_DATE`, `ename`/`PlansTxt`/`OrgehTxt` via `zhcm_employee_help`. No
balance defaulting (overtime has no quota concept).

## Virtual element: `manager_anzhl_h`

Declared on `zhcm_i_over` as
`@ObjectModel.virtualElementCalculatedBy: 'ABAP:ZHCM_OVER_CHECK_MANAGER_ANZHL'`
(`cast('' as boolean)`), a **read-time-only** boolean the UI can bind to (e.g. to
show/hide the manager-hours input) computed by `ZHCM_OVER_CHECK_MANAGER_ANZHL~calculate`:
returns `true` only when the request's `req_status = '01'` **and** the current user is the
resolved direct manager — otherwise `false`. This mirrors, but is independent of, the
`get_instance_features` edit-permission logic above (one drives editability at the RAP
framework level, the other exposes the same fact as a plain field the UI/annotations can use
for visibility, e.g. `@UI.hidden` expressions).

## UI (`zhcm_c_over_me.ddlx`)

Same Fiori Elements pattern as Leave Request: header data points, field groups, `_Attachment`
and `_Approval` line-item facets. List sorted by `RequestId` descending (same
`statusCriticality` `case` expression copied from Leave Request).

## Related tcodes / config

Same shared approval configuration as Leave Request — see
[05-approvals-and-rules.md](05-approvals-and-rules.md) — filtered to `APP_ID = '02'`.
