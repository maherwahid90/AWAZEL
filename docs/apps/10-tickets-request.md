# Tickets Request (ESS) — new application

Employee Self-Service Fiori app implementing the **"Tickets Request Custom App"** functional
spec (`HCM-FS { Tickets Request Custom App }`, v1, 04.05.2025): employees request tickets for
work-related travel, events or conferences — for themselves, their family, or both — with
family/companion data auto-populated from HR master data, routed through a single-level **HR
approval** step, and replicated into a dedicated HR-facing table once approved.

Built with the exact same RAP pattern as [Leave Request](01-leave-request.md) and
[Overtime Request](02-overtime-request.md) — see [../README.md](../README.md) for the shared
5-layer architecture and the "how to add a new self-service request app" checklist this app
follows.

* `APP_ID = '03'` in the shared approval engine ([05-approvals-and-rules.md](05-approvals-and-rules.md)).
* SAP Business Workflow template **`WS95000004`** (next in sequence after `WS95000002`/
  `WS95000003`) — **must be created in the Business Workflow Builder (`PFTC`)** the same way
  `WS95000002`/`WS95000003` were; it is not expressible as ABAP/CDS source and so is not
  included as a file in this repository, exactly as the two existing templates aren't either
  (only their PD task IDs appear, as `9500000x.pdts.xml`).
* Fiori Launchpad semantic object: `zhcm_tkt_req`, action `DISPLAY`.

## Functional spec → object mapping

| FS requirement | Implementation |
|---|---|
| "Employees can request tickets for work-related travel, events, or conferences" | Root entity `zhcm_i_tkt` / table `ZHCM_TICKET_REQ` |
| "for themselves, their family, or both" | `TicketType` field, domain `ZHCM_TKT_TYPE` (`1` Employee, `2` Family, `3` Employee and Family) |
| "family members are auto-populated from the employee's file... can also manually add" | `_Family` composition to `zhcm_i_tkt_family` / `ZHCM_TKT_FAMILY`, auto-filled from **PA0021** by determination `populateFamily`; `create`/`update`/`delete` all enabled on the child so the employee can add/edit/remove rows |
| "1st Screen: Submit Tickets Request" | Fiori Elements app `zhcm_tkt_req` (List Report/Object Page) on projection `zhcm_c_tkt` |
| "2nd Screen: HR Tickets Request Approval... HR can approve it or refused" | SAP Business Workflow `WS95000004` (Fiori **My Inbox**), agents resolved by `ZHCM_GET_APPROVALS_IN_USER_DEC` from `ZHCM_ESS_APPROV` rows configured for `APP_ID = '03'` — identical mechanism to Leave/Overtime approval, see [05-approvals-and-rules.md](05-approvals-and-rules.md) |
| "HR: A custom table has been configured... once approved, automatically replicated" | Tables `ZHCM_TKT_HR` (header) / `ZHCM_TKT_HR_FAM` (family), populated by FM `ZHCM_TICKET_REPLICATE_HR` |
| Data model table (employee/position/department/hire date auto-populated from PA0000/PA0001/PA0002) | Same `augment_create` + `zhcm_employee_help`/`PA0105` pattern as every other app in this suite — **not** re-stored on the ticket table itself, sourced live via association, exactly like Leave Request's `EMP`/`PlansTxt`/`OrgehTxt` |
| Family fields from PA0021 (name, birthdate, age, passport) | See [Family auto-population](#family-auto-population-from-pa0021) below |

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app manifest | `zhcm_tkt_req` (List Report / Object Page) | `zhcm_tkt_req.wapa.manifest.json` |
| Service binding | `ZHCM_C_TKT_SB` (OData v2) | `zhcm_c_tkt_sb.srvb.xml` |
| Service definition | `ZHCM_C_TKT_SD` — exposes `zhcm_c_tkt`, `zhcm_c_tkt_family`, `zhcm_c_tkt_approvals`, `zhcm_tkt_type_view`, `zhcm_employee_help` | `zhcm_c_tkt_sd.srvd.xml` / `.srvdsrv` |
| Projection CDS | `zhcm_c_tkt` (root), `zhcm_c_tkt_family`, `zhcm_c_tkt_approvals` | `zhcm_c_tkt*.ddls.asddls` |
| Projection BDEF | `projection implementation in class zbp_hcm_c_tkt` | `zhcm_c_tkt.bdef.asbdef` |
| UI metadata ext. | Fiori Elements annotations | `zhcm_c_tkt_me.ddlx.asddlxs`, `zhcm_c_tkt_family_me`, `zhcm_c_tkt_approvals_me` |
| Projection behavior class | `ZBP_HCM_C_TKT` (`augment_create`) | `zbp_hcm_c_tkt.clas.locals_imp.abap` |
| Interface CDS | `zhcm_i_tkt` (root), `zhcm_i_tkt_family`, `zhcm_i_tkt_approvals` | `zhcm_i_tkt*.ddls.asddls` |
| Interface BDEF | `managed implementation in class zbp_hcm_i_tkt`, `strict(2)`, `with draft` | `zhcm_i_tkt.bdef.asbdef` |
| Interface behavior class | `ZBP_HCM_I_TKT` (determinations, validation, family auto-fill, saver) | `zbp_hcm_i_tkt.clas.locals_imp.abap` |
| Active table | `ZHCM_TICKET_REQ` | `zhcm_ticket_req.tabl.xml` |
| Draft table | `ZHCM_DR_TKT` | `zhcm_dr_tkt.tabl.xml` |
| Family sub-table | `ZHCM_TKT_FAMILY` (+ draft `ZHCM_DR_TKT_FAM`) | `zhcm_tkt_family.tabl.xml` |
| Approvals sub-table | `ZHCM_TKT_APPROV` (+ draft `ZHCM_DR_TKT_APS`) | `zhcm_tkt_approv.tabl.xml` |
| Workflow log | `ZHCM_TKT_WFLOG` | `zhcm_tkt_wflog.tabl.xml` |
| HR replication tables | `ZHCM_TKT_HR` (header), `ZHCM_TKT_HR_FAM` (family) | `zhcm_tkt_hr.tabl.xml`, `zhcm_tkt_hr_fam.tabl.xml` |
| HR replication FM | `ZHCM_TICKET_REPLICATE_HR` (in function group `ZHCM_FG`) | `zhcm_fg.fugr.zhcm_ticket_replicate_hr.abap` |
| Ticket type value help | `zhcm_tkt_type_view` (text view over domain `ZHCM_TKT_TYPE`) | `zhcm_tkt_type_view.ddls.asddls` |
| Domain / data elements | `ZHCM_TKT_TYPE` (+ dtel), `ZHCM_TKT_DIRECTION`, `ZHCM_TKT_DEST`, `ZHCM_TKT_ROUTE`, `ZHCM_TKT_AGE` | `zhcm_tkt_*.doma.xml` / `.dtel.xml` |
| Messages | New `ZHCM_MSGS` number `011`; reuses `003`, `004` | `zhcm_msgs.msag.xml` |
| Shared engine changes | `ZHCM_APP_ID` domain value `03`; `ZHCM_UPDATE_APPROVALS` and `ZHCM_GET_APPROVALS_IN_USER_DEC` extended with an `APP_ID = '03'` branch | `zhcm_app_id.doma.xml`, `zhcm_fg.fugr.zhcm_update_approvals.abap`, `zhcm_fg.fugr.zhcm_get_approvals_in_user_dec.abap` |

## Data model (`ZHCM_TICKET_REQ`)

Key: `MANDT`, `REQUEST_UUID`. Notable fields:

| Field | Type | Purpose |
|---|---|---|
| `REQUEST_ID` (`ZHCM_REQ_NO`) | numeric | Sequential request number (same max+1 pattern as every other app — see [../README.md](../README.md)) |
| `PERNR` | `PERNR_D` | Requesting employee |
| `HIRE_DATE` | `BEGDA` | Cached at creation from `RP_GET_HIRE_DATE` |
| `TICKET_TYPE` | `ZHCM_TKT_TYPE` | `1` Employee · `2` Family · `3` Employee and Family |
| `BEGDA` / `ENDDA` | `BEGDA`/`ENDDA` | Travel start/end date |
| `DIRECTION` | `ZHCM_TKT_DIRECTION` | "Travel Ticket Entity/Direction" per the FS |
| `DESTINATION` | `ZHCM_TKT_DEST` | Travel destination |
| `ROUTE` | `ZHCM_TKT_ROUTE` | Journey route |
| `REQ_STATUS` | `ZHCM_REQ_STATUS` | Shared status domain — `1` In Progress · `2` Approved · `3` Rejected · `4` Posted Successfully · `5` Errors In Posting |
| `WORKITEM_ID` / `RETURN_CODE` | `SWW_WIID`/`SYST_SUBRC` | Workflow work item started for this request |

### `ZHCM_TKT_FAMILY` — family/companion data

| Field | Type | Source (FS) |
|---|---|---|
| `FAMILY_UUID` (key) | `SYSUUID_X16` | RAP-managed |
| `REQUEST_UUID` | FK to header | |
| `FIRST_NAME` | `FANAM` | `PA0021-FANAM` |
| `LAST_NAME` | `NACHN` | `PA0021-ARLNM` per the FS — see [assumption note](#open-item-pa0021-last-name-field) below |
| `BIRTHDATE` | `FGBDT` | `PA0021-FGBDT` |
| `AGE` | `ZHCM_TKT_AGE` (new) | Calculated (not stored on PA0021) — "from Birthdate until today" |
| `PASSPORT_NO` | `PSPNM` | `PA0021-PSPNM` |
| `SOURCE_SUBTY` | `SUBTY` | The originating PA0021 subtype, kept for traceability (not in the FS's field list; added so a manually-added row can still be told apart from an auto-populated one if needed) |

## Behavior definition highlights (`zhcm_i_tkt.bdef`)

Same shape as Leave Request/Overtime: `strict(2)`, `with draft`, `with additional save`,
`create`/`update(features: instance)`/`delete(features: instance)`, draft actions
`Prepare`/`resume`/`Edit`/`Activate optimized`/`Discard`. Differences:

* `determination populateFamily on modify { create; field TicketType; }` — the family
  auto-population trigger (see below).
* `side effects { field TicketType affects entity _Family; }` — so the Fiori Elements UI
  re-reads the `_Family` table the moment the employee picks a type that needs it.
* `_Family` child: `create; update; delete;` (all three — unlike the `_Approval` log, family
  rows are fully employee-editable, matching "the employee can also manually add and select a
  family member if needed").
* Mandatory: `Pernr`, `TicketType`, `Begda`, `Endda` (root); `FirstName`, `LastName`,
  `Birthdate`, `PassportNo` (family child — all "Mandatory" per the FS's data model table).

## Business logic (`ZBP_HCM_I_TKT` / `lhc_TKT`, `lhc__Family`)

* **`setRequestNumber`** — identical max+1 pattern over `ZHCM_TICKET_REQ`.
* **`populateFamily` (determination on modify of `TicketType`)** — when `TicketType` is `2`
  (Family) or `3` (Employee and Family) **and** the request has no `_Family` rows yet, selects
  every infotype **0021** (Family Member/Dependants) record valid today for the requester's
  `PERNR` and creates one `_Family` child row per record via `MODIFY ENTITIES ... CREATE BY
  \_Family`. Idempotent by construction (only fires when `_Family` is currently empty), so it
  won't fight with rows the employee has since edited or added manually.
* **`validateTicket` (validation on save)**:
  1. If `TicketType` is `2`/`3`, at least one `_Family` row must exist — message `ZHCM_MSGS
     011` ("At least one family member is required for this tickets type.").
  2. `Endda < Begda` → message `003` (reused verbatim from Leave Request).
  3. No other **own** ticket request (`req_status IN ('1','2','4')`) with an overlapping
     `Begda`–`Endda` range → message `004` (reused verbatim, same pattern as Leave
     Request/Overtime's duplicate-request check).
* **`lhc__Family~calculateAge` (determination on modify of `Birthdate`)** — computes `Age` via
  `HR_HK_DIFF_BT_2_DATES(date1 = sy-datum, date2 = Birthdate, output_format = '05')`, taking the
  `years` component — the same FM already used by
  [`ZHCM_CL_EOS_DURATION_CALC`](08-shared-master-data-and-enhancements.md#85-payrolleos-end-of-service-enhancements--ksa-specific)
  elsewhere in this codebase, reused here for consistency rather than hand-rolling a new
  date-diff calculation.
* **`get_instance_features`** (root and `_Family`) — same draft-gated update/delete pattern as
  every other app; `Pernr`/`hiredate`/`PlansTxt`/`OrgehTxt`/`RequestId` read-only (defaulted by
  `augment_create`, never user-entered).

### Open item: PA0021 "last name" field

The FS lists the family member "Name" field as sourced from **`PA0021-ARLNM and PA0021-FANAM`**.
`FANAM` (first name) is a well-known standard PA0021 field and is used as-is. `ARLNM` is not a
universally standard PA0021 field across SAP HCM configurations — the `populateFamily`
determination selects `NACHN` as a placeholder with an inline comment flagging this, and the
table field `ZHCM_TKT_FAMILY-LAST_NAME` is typed on data element `NACHN` for the same reason.
**Before activating this app**, confirm the actual last-name field on the target system's PA0021
subtype structure and adjust the `SELECT` in `zbp_hcm_i_tkt.clas.locals_imp.abap` (method
`populateFamily`) accordingly.

## Save / submit flow (`lsc_zhcm_i_tkt~save_modified`, additional save)

Identical mechanism to [Leave Request](01-leave-request.md#save--submit-flow-lsc_zhcm_i_lrsave_modified-additional-save) /
[Overtime Request](02-overtime-request.md#save--submit-flow-lsc_zhcm_i_oversave_modified-additional-save),
parameterized for tickets:

1. `ZHCM_UPDATE_APPROVALS(status = 'I', app_id = '03')` — seeds the (single-level, HR) approval
   row from `ZHCM_ESS_APPROV` into `ZHCM_TKT_APPROV`.
2. `SAP_WAPI_START_WORKFLOW(task = 'WS95000004')` with container `RequestUuid`, `ENAME`,
   `APP_ID = '03'`.
3. On failure: roll back the approval row (`status = 'D'`) and report the workflow's error
   messages on the entity.
4. On success: persist `WORKITEM_ID`/`RETURN_CODE`, log via `ZHCM_UPDATE_WORKITEM` into
   `ZHCM_TKT_WFLOG`.

## HR replication on approval

This repository does not contain the ABAP for *any* app's final "approved" step (the code that
flips `REQ_STATUS` to `2`/Approved from within the workflow decision) — that is true for Leave
Request and Overtime Request too; it lives in the SAP Business Workflow step configuration
(`PFTC`), not as loose ABAP source. For Tickets Request, that same workflow step must call the
new FM **`ZHCM_TICKET_REPLICATE_HR(requestuuid)`** immediately after setting `REQ_STATUS = '2'`.
The FM copies the approved header into `ZHCM_TKT_HR` and every family/companion row into
`ZHCM_TKT_HR_FAM`, satisfying the FS's "once a request is approved, it will be automatically
replicated in the system."

## Create defaulting (`ZBP_HCM_C_TKT` — projection `augment_create`)

Identical pattern to every other app in the suite: `ReqStatus = '1'`, `Pernr` resolved from
**`PA0105`** (`usrid = sy-uname`, `usrty = '0001'`), `HireDate` via `RP_GET_HIRE_DATE`, `ename`/
`PlansTxt`/`OrgehTxt` via `zhcm_employee_help`.

## UI (`zhcm_c_tkt_me.ddlx`)

Object page facets: header data points for `Employee` and `ReqStatus`; field group "Travel Data"
(ticket type, start/end date, direction, destination, route, remarks); line-item facets for
`_Family` ("Family Members") and `_Approval` ("Approvals"). List report sorted by `RequestId`
descending — same `statusCriticality` `case` expression reused verbatim from Leave
Request/Overtime.

## Configuration needed before go-live

1. Add `ZHCM_ESS_APPROV` row(s) for `APP_ID = '03'` (tcode `ZHCM_APPROVALS`) — a single level is
   enough per the FS ("HR will review... approve it or refused"), typically `APPROVER_TYPE =
   '02'` (a fixed HR employee number) or `'03'` (a fixed HR position) — see
   [05-approvals-and-rules.md](05-approvals-and-rules.md).
2. Create workflow template `WS95000004` in the Business Workflow Builder, agent determination
   rule = `ZHCM_GET_APPROVALS_IN_USER_DEC` (already extended for `APP_ID = '03'`), and add its
   tasks to `SWFVISU` (Task Visualization) so the approval work item surfaces correctly in Fiori
   My Inbox.
3. Verify/adjust the PA0021 last-name field per the [open item](#open-item-pa0021-last-name-field) above.
4. Generate the remaining Fiori app scaffold (`Component.js`, `index.html`, `i18n`, local mock
   service files, UI5 ABAP repository mapping) with `@sap/generator-fiori:lrop` pointed at
   `ZHCM_C_TKT_SB`, exactly as the other apps' `.wapa` folders were generated — only
   `manifest.json` is hand-authored here since the rest is boilerplate the generator produces
   from the OData service metadata.
5. Add a Fiori Launchpad catalog tile/semantic object (`zhcm_tkt_req-DISPLAY`), same as
   `catalog1.PNG`/`catalog2.PNG` show for the existing apps.
