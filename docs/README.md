# AWAZEL — SAP HCM Employee Self-Service (ZHCM) — Technical Documentation

This repository contains the ABAP/RAP (RESTful ABAP Programming Model) development for a
suite of **Employee Self-Service (ESS) / Manager Self-Service (MSS)** Fiori applications built
on top of standard SAP HCM (Personnel Administration, Time Management, Payroll), plus the
backend configuration, workflow and integration objects that support them.

All custom objects use the namespace prefix `ZHCM_*` / `ZACIC_*` (payslip) and live in the
package **HCM Development Package** (`package.devc.xml`). The repository is a flat abapGit
serialization (no folders) — every file name encodes `<object_name>.<object_type>.<extension>`.

This `docs/` folder documents **every application** found in the repository, one file per
application/module, plus this index describing the shared architecture and conventions so that
**new self-service requests can be implemented consistently** with what already exists.

## Applications documented

| # | Document | Application | Type |
|---|----------|-------------|------|
| 1 | [apps/01-leave-request.md](apps/01-leave-request.md) | **Leave Request** (`ZHCM_LEAVE_REQ`) | RAP transactional Fiori app (employee) |
| 2 | [apps/02-overtime-request.md](apps/02-overtime-request.md) | **Overtime Request** (`ZHCM_OVERTIME`) | RAP transactional Fiori app (employee + manager) |
| 3 | [apps/03-leave-balance.md](apps/03-leave-balance.md) | **Leave Balance** (`ZHCM_LEAVE_BAL`) | RAP read-only Fiori app (employee) |
| 4 | [apps/04-payslip.md](apps/04-payslip.md) | **Payslip** (employee `ZHCM_PAYSLIP` + admin `ZHCM_PAYSLIP_AD`) | RAP read-only Fiori app + classic SAP Gateway PDF service |
| 5 | [apps/05-approvals-and-rules.md](apps/05-approvals-and-rules.md) | **Approval configuration & workflow** (`ZHCM_EMP_APPROV`, `ZHCM_ESS_APPROV`, `ZHCM_RULES`) | SAP GUI config transactions + SAP Business Workflow |
| 6 | [apps/06-time-machine-integration.md](apps/06-time-machine-integration.md) | **Time Machine (biometric device) Integration** | Background report (RFC to external MySQL DB) |
| 7 | [apps/07-time-sheet-upload.md](apps/07-time-sheet-upload.md) | **Time Sheet Upload** (`ZHCM_UPLOAD_TS`) | SAP GUI report (Excel upload) |
| 8 | [apps/08-shared-master-data-and-enhancements.md](apps/08-shared-master-data-and-enhancements.md) | **Shared CDS views, domains & HR enhancements/BAdIs** | Cross-application building blocks |
| 9 | [apps/09-exit-reentry-request-planned.md](apps/09-exit-reentry-request-planned.md) | **Exit / Re-entry Visa Request** | ⚠️ Data model only — not yet built |
| 10 | [apps/10-tickets-request.md](apps/10-tickets-request.md) | **Tickets Request** (`ZHCM_TICKET_REQ`) | RAP transactional Fiori app (employee) + HR approval workflow |

## High-level architecture

The suite mixes **two generations** of SAP extensibility:

1. **RAP (RESTful ABAP Programming Model), managed, with draft** — used for every
   transactional self-service app created recently: Leave Request, Overtime Request. Read-only
   apps (Leave Balance, Payslip) use **unmanaged, non-draft CDS-only** read models (no behavior
   definition needed because there is nothing to create/update).
2. **Classic ABAP** — table maintenance generators (SM30/SM34), SAP Business Workflow, classic
   SAP Gateway (SEGW) OData service, Smart Forms/Adobe Forms, and background reports. These
   carry configuration, the approval/workflow engine, and the PDF payslip rendering, none of
   which currently exist as RAP.

### The RAP application pattern (Leave Request / Overtime Request)

Every managed-RAP transactional app follows the **same five-layer stack**. Use this as the
template for any new self-service request app:

```
Fiori Elements app (.wapa)            zhcm_<app>.wapa
        │  OData V2 (via *_van/*_SB) or V4 (via *_v4)
        ▼
Service Binding (.srvb)               zhcm_c_<x>_sb / zhcm_c_<x>_sb_v4
        │
Service Definition (.srvd)            zhcm_c_<x>_sd  →  exposes zhcm_c_<x>
        │
Projection CDS + behavior (.ddls/.bdef, "C_" view)   zhcm_c_<x>
   + UI metadata extension (.ddlx)                   zhcm_c_<x>_me   (Fiori Elements annotations)
   + projection behavior implementation (.clas)       zbp_hcm_c_<x>  ("augment_create" logic)
        │  projection on
        ▼
Interface CDS + behavior (.ddls/.bdef, "I_" view)     zhcm_i_<x>
   + interface behavior implementation (.clas)        zbp_hcm_i_<x>[_bd]
        (determinations, validations, actions, save logic → SAP Business Workflow)
        │  persistent table / draft table
        ▼
Database tables (.tabl)               zhcm_<x>_req (active) + zhcm_dr_<x> (draft)
                                       zhcm_<x>_approv / zhcm_dr_<x>_aps (approval sub-entity)
                                       zhcm_<x>_attach / zhcm_dr_<x>_at  (attachment sub-entity)
```

Each request app is a **root RAP business object with two compositions**:

* `_Attachment` — a large-object (PDF/image) attachment sub-node, mandatory for most leave
  types (see the `validateDates` validation), stored as a demand-loaded BLOB
  (`@Semantics.largeObject`).
* `_Approval` — a read-mostly log of the approval chain (one row per approval level/sequence),
  populated by `ZHCM_UPDATE_APPROVALS` when the request is submitted (see doc 5).

Both request apps share the same **create/submit flow**:

1. `augment_create` (projection behavior, `zbp_hcm_c_<x>.clas.locals_imp`) defaults the
   requester's `Pernr` (from infotype **PA0105**, subtype `0001` = "SAP username"), hire date,
   name/position/department (from `zhcm_employee_help`), and initial status `'1'` (In Progress).
2. `setRequestNumber` (determination on save) assigns the next sequential `RequestId` (max+1 on
   the active table — **not** a real SAP number range object).
3. `validateDates` (validation on save) enforces the request-specific business rules (see each
   app's document) and always **simulates** the resulting infotype record via the relevant BAPI
   before allowing the save, so a request can never be approved into something HR can't post.
4. On **save** (`lsc_zhcm_i_<x>~save_modified`, "additional save"): the behavior definition uses
   `with additional save` so that a plain CDS/table save is not enough — after the framework's
   own persist, custom code runs to seed the approval chain (`ZHCM_UPDATE_APPROVALS`,
   `status = 'I'`) and start the matching **SAP Business Workflow** (`SAP_WAPI_START_WORKFLOW`),
   logging the resulting work item in `ZHCM_LR_WFLOG` / equivalent via `ZHCM_UPDATE_WORKITEM`.
   See [apps/05-approvals-and-rules.md](apps/05-approvals-and-rules.md) for the full approval
   engine.

### Status model (shared)

Both request apps share the domain **`ZHCM_REQ_STATUS`** for `ReqStatus`:

| Value | Meaning | UI criticality |
|-------|---------|-----------------|
| `1` | In Progress | Warning (2) |
| `2` | Approved | Positive... wait, see below |
| `3` | Rejected | Positive-mapped in the CDS `case` (verify against `t554s`/workflow before reuse) |
| `4` | Posted Successfully | |
| `5` | Errors In Posting | |

(The exact CDS `case` expression that derives `statusCriticality` is in each app's `I_` view;
copy it verbatim for a new request type rather than re-deriving it.)

### Approver types (shared)

Domain **`ZHCM_APPROVER_TYPE`**, used by `ZHCM_ESS_APPROV` (see doc 5) to decide who approves a
given level of a given request type:

| Value | Meaning | Resolved from |
|-------|---------|----------------|
| `01` | Direct Manager | `ZHCM_EMP_APPROV` (employee → manager `PERNR` mapping table) |
| `02` | Fixed Employee No. | `ZHCM_ESS_APPROV-PERNR` |
| `03` | Fixed Position | `ZHCM_ESS_APPROV-PLANS` |
| `04` | Rule | `ZHCM_APPROV_R` / `ZHCM_APPROV_R_L` (maintained via tcode `ZHCM_RULES`) |

### Application IDs (shared)

Domain **`ZHCM_APP_ID`** identifies *which* request type a generic FM/table row belongs to
(used by the shared approval FMs and the workflow container):

| Value | Application |
|-------|-------------|
| `01` | Leave Request |
| `02` | Overtime Request |
| `03` | Tickets Request |

**When adding a new request-type app, register a new value here first** — the whole approval
engine (`ZHCM_UPDATE_APPROVALS`, `ZHCM_GET_APPROVALS_IN_USER_DEC`) branches on `APP_ID`.

## Shared master data / value help CDS views

These are consumed by nearly every app above — see
[apps/08-shared-master-data-and-enhancements.md](apps/08-shared-master-data-and-enhancements.md)
for full definitions:

* `zhcm_employee_help` — employee search help / value help (name, position, org unit, company,
  plus **virtual elements** for hire date and leave-quota balance, calculated by
  `ZCL_VIRTUAL_ELEMENT_CALC`).
* `zhcm_absence_types_cds` — absence type (`AWART`) texts from `T554T`/`T554S` (grouping `90`).
* `zhcm_req_status_view` — text view over domain `ZHCM_REQ_STATUS` (`DD07T`).
* `zhcm_quotas` / `zhcm_emp_quota` — time quota type texts (`T556B`).
* `zhcm_v_emp_payroll_period[_adm]` — payroll period value help (`HRPY_RGDIR` + `T247`).

## How to add a new self-service request app

Based on the pattern above, a new "X Request" ESS app needs, at minimum:

1. **Domain values**: add an `APP_ID` value (`ZHCM_APP_ID`), and if it needs a distinct
   approver-configuration set, reuse `ZHCM_APPROVER_TYPE` as-is.
2. **Tables**: `zhcm_x_req` (active), `zhcm_dr_x` (draft), `zhcm_x_approv` +
   `zhcm_dr_x_aps` (approvals), optionally `zhcm_x_attach` + `zhcm_dr_x_at` (attachments).
3. **Interface CDS + BDEF** `zhcm_i_x` — `managed ... with draft`, persistent table
   `zhcm_x_req`, `with additional save`, plus compositions to the approvals/attachment
   interface CDS views (copy `zhcm_i_lr_approvals` / `zhcm_i_lr_att` almost verbatim).
4. **Interface behavior class** `zbp_hcm_i_x[_bd]` implementing: `setRequestNumber`,
   `validateDates` (your business rules + a BAPI **simulation** call), any calculated fields as
   `determination ... on modify`, and `lsc_zhcm_i_x~save_modified` to call
   `ZHCM_UPDATE_APPROVALS` + `SAP_WAPI_START_WORKFLOW` + `ZHCM_UPDATE_WORKITEM` exactly like
   Leave Request/Overtime (only the workflow template `WS9xxxxxxx` and `app_id` differ).
5. **Projection CDS + BDEF** `zhcm_c_x` (`provider contract transactional_query`,
   `where LocalCreatedBy = $session.user` for an employee-scoped list), **metadata extension**
   `zhcm_c_x_me` for the Fiori Elements UI annotations, and projection behavior class
   `zbp_hcm_c_x` with an `augment_create` handler that defaults `Pernr`/name/etc. from
   `PA0105` + `zhcm_employee_help`.
6. **Service definition + binding** (`zhcm_c_x_sd` / `zhcm_c_x_sb`), then generate the OData V2
   annotation binding (`_sb_van`) that the Fiori app's `manifest.json` references.
7. **Fiori Elements List Report / Object Page app** (`zhcm_x.wapa`) generated with
   `@sap/generator-fiori:lrop`, wired to a Fiori Launchpad tile/catalog entry with its own
   semantic object (`zhcm_x-display`), as shown in `catalog1.PNG`/`catalog2.PNG`.
8. **Approval configuration rows** in `ZHCM_ESS_APPROV` (tcode `ZHCM_APPROVALS`) for the new
   `APP_ID`, and a new SAP Business Workflow template (`WSnnnnnnnn`) whose agent assignment
   calls `ZHCM_GET_APPROVALS_IN_USER_DEC` (extend its `CASE app_id` branch) — see doc 5.

## Reference screenshots in the repo root

* `catalog1.PNG` / `catalog2.PNG` / `catalog3.PNG` — Fiori Launchpad catalog/tile
  configuration for the ESS apps.
* `SWFVISU1.PNG` / `SWFVISU2.PNG` — SAP Business Workflow task visualization configuration
  (`SWFVISU`) mapping workflow tasks (`TS95000001`, `TS95000006`, …) to "My Inbox"/intent-based
  navigation, i.e. how approval work items surface in Fiori "My Inbox".
* `ZHCM_DEV_20250825_225130.zip` — a point-in-time transport/export snapshot (not unpacked as
  part of this documentation pass).
