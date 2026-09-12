# Approval Configuration, Approval Rules & Workflow Engine

This is the shared **backend configuration and SAP Business Workflow layer** used by every
request-type app ([Leave Request](01-leave-request.md), [Overtime Request](02-overtime-request.md),
and any future request app — see [../README.md](../README.md#how-to-add-a-new-self-service-request-app)).
It is not itself an end-user Fiori app; it is maintained by HR/IT administrators through classic
SAP GUI transactions (table maintenance generators and a view cluster), and executed at runtime
by generic function modules and SAP Business Workflow.

## 5.1 Configuration transactions

| Tcode | Purpose | Maintains | Generator |
|---|---|---|---|
| `ZHCM_EMP_MANAGER` — "Manager of Employee" | Employee → direct-approver (manager) mapping | `ZHCM_EMP_APPROV` | SM30 (`/*SM30 VIEWNAME=ZHCM_EMP_APPROV;UPDATE=X;`) |
| `ZHCM_APPROVALS` — "HCM Approvals" | Per-application, per-level approver configuration | `ZHCM_ESS_APPROV` | SM30 (`/*SM30 VIEWNAME=ZHCM_ESS_APPROV;UPDATE=X;`) |
| `ZHCM_RULES` — "Approval Rules" | Named, reusable "rule" approver lists | `ZHCM_APPROV_R` (header) + `ZHCM_APPROV_R_L` (list) | SM34 view cluster `ZHCM_RULE_CV` (`/*SM34 VCLDIR-VCLNAME=ZHCM_RULE_CV;UPDATE=X;`) |

The function groups `zhcm_emp_approv.fugr` and `zhcm_ess_approv.fugr` are **generated table
maintenance dialogs** (their main includes are just `LSVIMFXX`/`LSVIMOXX`/`LSVIMIXX` — standard
SM30 generator code, no custom logic). `zhcm_rule_mv.fugr` and `zhcm_rule_l_mv2.fugr` are
likewise generated **view-cluster** dialogs (`ZHCM_RULE_MV` over `ZHCM_APPROV_R`,
`ZHCM_RULE_L_MV`/`ZHCM_RULE_L_MV2` over `ZHCM_APPROV_R_L`, combined into view cluster
`ZHCM_RULE_CV`/`ZHCM_RULE_CVC`, class `ZHCM_RULE_CV`). No documentation is needed of their
internals — they are pure Dictionary/SM30 configuration UIs.

## 5.2 Tables

### `ZHCM_EMP_APPROV` — direct manager mapping

| Field | Type | Meaning |
|---|---|---|
| `PERNR` (key) | `PERNR_D` | Employee |
| `APPROVAL_EMP` | `ZHCM_APPROVAL_PERNR_D` | That employee's direct approver/manager (personnel number) |

Both fields use search help `PREM` (standard personnel number search help).

### `ZHCM_ESS_APPROV` — approval level configuration (per request type)

| Field | Type | Meaning |
|---|---|---|
| `APP_ID` (key) | `ZHCM_APP_ID` | `01` Leave Request · `02` Overtime Request · `04` Employee Communication Data · `07` Tickets Request (extend for new apps) |
| `APPROVER_SEQ` (key) | `ZHCM_APPROV_SEQ` | Sequence number of this approval level (1, 2, 3, …) |
| `APPROVER_TYPE` | `ZHCM_APPROVER_TYPE` | `01` Direct Manager · `02` Employee No. · `03` Fixed Position · `04` Rule |
| `PLANS` | `PLANS` | Used when `APPROVER_TYPE = 03` |
| `PERNR` | `PERNR_D` | Used when `APPROVER_TYPE = 02` |
| `APPROVER_RULE` | `ZHCM_APPROVER_RULE` | Used when `APPROVER_TYPE = 04`, FK to `ZHCM_APPROV_R` |

This is the table an administrator edits to define, per request type, **how many approval
levels exist and who resolves each one**. A new request app needs one row per approval level
under its own `APP_ID`.

### `ZHCM_APPROV_R` / `ZHCM_APPROV_R_L` — named approver rules

* `ZHCM_APPROV_R` (header): `APPROVER_RULE` (key, own number range `ZHCM_APPROVER_RULE`,
  search help `ZHCM_APPROV_R_SH`) + `RULE_NAME`.
* `ZHCM_APPROV_R_L` (list, foreign key to the header): `APPROVER_RULE` + `PERNR` — the set of
  personnel numbers that belong to this rule.

Used for approval scenarios that aren't a simple direct-manager/fixed-person/fixed-position
lookup — e.g. "any of these 3 specific people can approve" or department/committee-style
approval — resolved by `APPROVER_TYPE = '04'` referencing `RULE_PERNR` (see 5.3).

## 5.3 Runtime approval engine (function group `ZHCM_FG`)

### `ZHCM_UPDATE_APPROVALS` — build/tear down the approval chain

`IMPORTING requestuuid, pernr, status ('I' insert / 'D' delete), app_id`

* On `status = 'I'`: reads `ZHCM_ESS_APPROV` for the given `APP_ID` ordered by
  `APPROVER_SEQ`, and for each level resolves the actual approver **name and personnel number**
  by `APPROVER_TYPE`:
  * `01` Direct Manager → `ZHCM_EMP_APPROV` joined to `PA0001` on the requester's `PERNR`.
  * `02` Employee No. → `PA0001` on the configured `PERNR`.
  * `03` Fixed Position → `PA0001` on the configured `PLANS` (position holder).
  * `04` Rule → just the rule's `RULE_NAME` from `ZHCM_APPROV_R` (the actual agent(s) are
    resolved later, at work-item-dispatch time, by `ZHCM_GET_APPROVALS_IN_USER_DEC`, not here).
  The **first level's row** gets a timestamp in `RECEIVE_TS`; every row gets `REQUEST_UUID` +
  `APPROVAL_SEQ`. The resulting rows are inserted into the request-type's approval table
  (`ZHCM_LR_APPROV` for `app_id = '01'`, `ZHCM_OV_APPROV` for `'02'` — **extend this `CASE`
  for a new `app_id`**) and committed.
* On `status = 'D'`: deletes all approval rows for the `request_uuid` from the matching table
  (used to roll back if workflow start fails).

This is what populates the `_Approval` composition child shown on both request apps' object
pages.

### `SAP_WAPI_START_WORKFLOW` — kick off the workflow

Called from each request app's `lsc_*~save_modified` (see docs 01/02) with `task = 'WS95000002'`
(Leave Request) or `'WS95000003'` (Overtime Request) and a container carrying `RequestUuid`,
`ENAME`, `APP_ID`. Standard SAP Business Workflow API — the workflow templates themselves
(`WS95000002`/`WS95000003`, plus the underlying tasks `TS95000001`, `TS95000006`, … visible in
`SWFVISU1.PNG`/`SWFVISU2.PNG`) are Business Workflow Builder objects, not represented as
abapGit-serializable source in this repository beyond their PD task IDs (`95000001.pdts.xml`
… `95000007.pdts.xml`).

### `ZHCM_GET_APPROVALS_IN_USER_DEC` — workflow agent determination rule

A **standard Workflow "rule" function module** (uses `SWCONT`/`SWHACTOR`, the classic rule
interface) invoked by the workflow runtime to determine **who the current work item's agents
are**, reading `CURRENT_APPROVAL` (a `ZHCM_LR_APPROV`-shaped structure) and `APP_ID` out of the
workflow container:

1. Looks up the request's owning `PERNR` from `ZHCM_LEAVE_REQ` (`app_id = '01'`) or
   `ZHCM_OVERT_REQ` (`'02'`) by `request_uuid`.
2. Reads the matching `ZHCM_ESS_APPROV` row for `(app_id, approver_seq = current_approval-
   approval_seq)` to get that level's `APPROVER_TYPE`.
3. Resolves the actual workflow actor(s) into `ACTOR_TAB`:
   * `01` → the requester's manager from `ZHCM_EMP_APPROV`, actor type `P` (person/org-unit
     `Person`).
   * `02` → the fixed `PERNR` configured on the `ZHCM_ESS_APPROV` row, type `P`.
   * `03` → the fixed `PLANS` configured on the row, type `S` (**Position** — the workflow
     routes to whoever currently holds that position).
   * `04` → **every** `PERNR` in `ZHCM_APPROV_R_L` for the configured `APPROVER_RULE`, each
     appended as a separate actor (i.e. any one of them can process the work item — rule-based
     multi-agent).
   If no matching `ZHCM_ESS_APPROV` row is found, raises exception `NO_ACTOR_FOUND`.

### `ZHCM_UPDATE_WORKITEM` — workflow start log

`IMPORTING requestuuid, workitem_id, return_code, requestid, pernr, app_id` — inserts one row
into `ZHCM_LR_WFLOG` (`REQUEST_UUID` + `APP_ID` key) recording the work item that was started
for the request. Purely a log/audit table; not read back by the apps themselves.

## 5.4 End-to-end sequence (either request app)

```
Employee submits request (RAP Activate)
        │
        ▼
lsc_*~save_modified (additional save)
        │
        ├─► ZHCM_UPDATE_APPROVALS(status='I') ──► approval chain rows inserted
        │        (reads ZHCM_ESS_APPROV, resolves approver per level)
        │
        ├─► SAP_WAPI_START_WORKFLOW(task = WSxxxxxxxx)
        │        │
        │        ├─ failure ─► ZHCM_UPDATE_APPROVALS(status='D')  (rollback chain)
        │        │             + workflow error messages reported on the entity
        │        │
        │        └─ success ─► WORKITEM_ID/RETURN_CODE saved on the request
        │                      + ZHCM_UPDATE_WORKITEM (audit log)
        ▼
Workflow work item dispatched to approver(s)
        │  (agent resolved at each step by ZHCM_GET_APPROVALS_IN_USER_DEC,
        │   surfaced to the approver via SAP Fiori "My Inbox" — SWFVISU config)
        ▼
Approver decision → (outside this repo's scope: presumably updates ZHCM_*_APPROV.STATUS
                      and the request's REQ_STATUS via the workflow's own steps/tasks)
```

This checklist has since been followed for real by
[Tickets Request](10-tickets-request.md) (`APP_ID = '07'`, workflow `WS95000009` — renumbered
from the original `'03'`/`WS95000004` once other apps claimed `03`/`05`/`06` in the meantime) and
[Employee Communication Data](11-employee-communication-data.md) (`APP_ID = '04'`) — see those
documents for concrete, worked examples of every step below.

## 5.5 Checklist for a new request type

1. Add a new value to domain `ZHCM_APP_ID`.
2. Add one `ZHCM_ESS_APPROV` row per approval level for the new `APP_ID` (tcode
   `ZHCM_APPROVALS`), using existing `ZHCM_APPROV_R`/`_L` rules where a named rule fits, or
   create a new rule via tcode `ZHCM_RULES`.
3. Create a matching approvals table for the new object (`zhcm_<x>_approv`,
   `zhcm_dr_<x>_aps`) — the shape must match `ZHCM_LR_APPROV`/`ZHCM_OV_APPROV` exactly, since
   `ZHCM_UPDATE_APPROVALS`/`ZHCM_GET_APPROVALS_IN_USER_DEC` are generic over that structure.
4. Extend the `CASE app_id` branches in `ZHCM_UPDATE_APPROVALS` and
   `ZHCM_GET_APPROVALS_IN_USER_DEC` to target the new table.
5. Create a new SAP Business Workflow template (Business Workflow Builder, transaction `PFTC`)
   whose agent-assignment rule calls `ZHCM_GET_APPROVALS_IN_USER_DEC`, and note its `WSxxxxxxxx`
   ID for the new `save_modified` implementation.
6. Add the new workflow's tasks to `SWFVISU` (Task Visualization) so approval work items surface
   correctly in Fiori "My Inbox" (see `SWFVISU1.PNG`).
