# Employee Communication Data (ESS) — new application

Employee Self-Service Fiori app for requesting a change to a piece of "communication data"
held on infotype **0105** (Communication) — e.g. the value on file for a given communication
type (system username, email, mobile number, etc., depending on what `USRTY` subtypes are
configured in the system). The employee picks the communication type, the app retrieves
whatever value is already on file for it, and the employee edits/confirms the value they want
and submits it for approval — with attachment and approval children, and the same
create/validate/save/workflow mechanics as every other request app in this suite.

Built with the exact same RAP pattern as [Tickets Request](10-tickets-request.md) — root +
`_Attachment` + `_Approval` (no member/family child needed here) — see [../README.md](../README.md)
for the shared 5-layer architecture and the "how to add a new self-service request app"
checklist this app follows.

* `APP_ID = '04'` in the shared approval engine ([05-approvals-and-rules.md](05-approvals-and-rules.md)).
* SAP Business Workflow template **`WS95000005`** (next in sequence after `WS95000002`/
  `WS95000003`/`WS95000004`) — must be created in the Business Workflow Builder (`PFTC`) the
  same way the others were; not expressible as ABAP/CDS source, so not a file in this repo.
* Fiori Launchpad semantic object: `zhcm_ecd_req`, action `DISPLAY`.
* Tables use the same **source-based (`.tabl.astabl`) table definition** syntax as Tickets
  Request, for consistency with the most recently added app (there are no pre-existing tables
  to match here, unlike Tickets — this repo's older apps use the classic SE11 `.tabl.xml` style
  instead; either is a legitimate default, this one follows Tickets).

## Requirement → object mapping

| Requirement | Implementation |
|---|---|
| "Begin date of activating this data" | `Begda` field on the root entity |
| "Communication type with help value from PA0105-USRTYP" | `CommunicationType` field, typed on the same data element PA0105 itself uses (`USRTY`); value help/text sourced from `zhcm_comm_type_view` (a CDS view over standard table `T591S`, infotype 0105's own subtype-text table — the same table SAP itself uses for `USRTY`'s F4 help) |
| "Field system id reference to PA0105-USRID" | `SystemId` field, typed on `USRID` (the same data element PA0105 itself uses) |
| "When employee select communication type, application should retrieve the existing data in system" | `retrieveSystemId` determination — see below |
| "Will follow approvals and attachment childs as ticket app" | `_Attachment` (`ZHCM_ECD_ATTACH`) and `_Approval` (`ZHCM_ECD_APPROV`) compositions, identical shape to Tickets Request's own children |

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app manifest | `zhcm_ecd_req` (List Report / Object Page) | `zhcm_ecd_req.wapa.manifest.json` |
| Service binding | `ZHCM_C_ECD_SB` (OData v2) | `zhcm_c_ecd_sb.srvb.xml` |
| Service definition | `ZHCM_C_ECD_SD` — exposes `zhcm_c_ecd`, `zhcm_c_ecd_attach`, `zhcm_c_ecd_approvals`, `zhcm_comm_type_view`, `zhcm_employee_help` | `zhcm_c_ecd_sd.srvd.xml` / `.srvdsrv` |
| Projection CDS | `zhcm_c_ecd` (root), `zhcm_c_ecd_attach`, `zhcm_c_ecd_approvals` | `zhcm_c_ecd*.ddls.asddls` |
| Projection BDEF | `projection implementation in class zbp_hcm_c_ecd` | `zhcm_c_ecd.bdef.asbdef` |
| UI metadata ext. | Fiori Elements annotations | `zhcm_c_ecd_me.ddlx.asddlxs`, `zhcm_c_ecd_attach_me`, `zhcm_c_ecd_approvals_me` |
| Projection behavior class | `ZBP_HCM_C_ECD` (`augment_create`) | `zbp_hcm_c_ecd.clas.locals_imp.abap` |
| Interface CDS | `zhcm_i_ecd` (root), `zhcm_i_ecd_attach`, `zhcm_i_ecd_approvals` | `zhcm_i_ecd*.ddls.asddls` |
| Interface BDEF | `managed implementation in class zbp_hcm_i_ecd`, `strict(2)`, `with draft` | `zhcm_i_ecd.bdef.asbdef` |
| Interface behavior class | `ZBP_HCM_I_ECD` (determinations, validation, saver) | `zbp_hcm_i_ecd.clas.locals_imp.abap` |
| Active table (header) | `ZHCM_ECD_REQ` | `zhcm_ecd_req.tabl.astabl` |
| Draft table (header) | `ZHCM_DR_ECD` | `zhcm_dr_ecd.tabl.astabl` |
| Attachment sub-table | `ZHCM_ECD_ATTACH` (+ draft `ZHCM_DR_ECD_AT`) | `zhcm_ecd_attach.tabl.astabl` |
| Approvals sub-table | `ZHCM_ECD_APPROV` (+ draft `ZHCM_DR_ECD_APS`) | `zhcm_ecd_approv.tabl.astabl` |
| Workflow log | `ZHCM_ECD_WFLOG` | `zhcm_ecd_wflog.tabl.astabl` |
| Communication type value help | `zhcm_comm_type_view` (text view over `T591S`, `infty = '0105'`) | `zhcm_comm_type_view.ddls.asddls` |
| Shared engine changes | `ZHCM_APP_ID` domain value `04`; `ZHCM_UPDATE_APPROVALS` and `ZHCM_GET_APPROVALS_IN_USER_DEC` extended with an `APP_ID = '04'` branch (targeting `ZHCM_ECD_APPROV`/`ZHCM_ECD_REQ`) | `zhcm_app_id.doma.xml`, `zhcm_fg.fugr.zhcm_update_approvals.abap`, `zhcm_fg.fugr.zhcm_get_approvals_in_user_dec.abap` |
| Messages | Reuses existing `ZHCM_MSGS` `004` — no new message numbers needed | `zhcm_msgs.msag.xml` (unchanged) |

## Data model (`ZHCM_ECD_REQ`)

Key: `CLIENT`, `REQUEST_UUID`. Fields:

| Field | Type | Purpose |
|---|---|---|
| `REQUEST_ID` | `ZHCM_REQ_NO` | Sequential request number (max+1 pattern, same as every other app) |
| `PERNR` | `PERNR_D` | Requesting employee |
| `BEGDA` | `BEGDA` | Date the new/changed communication data becomes effective |
| `COMMUNICATION_TYPE` | `USRTY` | Same data element PA0105 itself uses for its subtype-like "Communication Type" field |
| `SYSTEM_ID` | `USRID` | Same data element PA0105 itself uses for the actual communication value (username, email, phone, etc., depending on the type) |
| `REQ_STATUS` | `ZHCM_REQ_STATUS` | Shared status domain (reused as-is) |
| `RETURN_CODE` / `WORKITEM_ID` | `SYST_SUBRC`/`SWW_WIID` | Workflow work item started for this request |

No `HIRE_DATE`/absence/balance-style cached fields — this app's only business data beyond
identity is the three fields above, exactly as specified.

### Communication type value help (`zhcm_comm_type_view`)

```
select from t591s
{ key subty as Subty, @Semantics.text: true itext as Itext }
where sprsl = $session.system_language and infty = '0105'
```

`T591S` is the standard infotype-subtype text table SAP itself uses to render subtype value
helps generically (the same table that ultimately backs infotype 0105's own `USRTY` F4 help in
PA30/PA20). Filtering it to `infty = '0105'` reproduces exactly the same list of communication
types your system already has configured for infotype 0105 — no separate custom domain/fixed
values needed, and it will automatically pick up new communication types if more are added to
infotype 0105 configuration later. This mirrors the same "reuse a standard SAP subtype text
table" pattern `zhcm_absence_types_cds` already uses for Leave Request's `Awart` field
(`T554T`/`T554S`).

## Behavior definition highlights (`zhcm_i_ecd.bdef`)

Same shape as every other app in the suite: `strict(2)`, `with draft`, `with additional save`,
`create`/`update(features: instance)`/`delete(features: instance)`, draft actions
`Prepare`/`resume`/`Edit`/`Activate optimized`/`Discard`. Specifics:

* `determination retrieveSystemId on modify { create; field CommunicationType; }` +
  `side effects { field CommunicationType affects field SystemId; }` — see below.
* Mandatory: `Pernr`, `Begda`, `CommunicationType`, `SystemId` (root); `Attachment` is **not**
  mandatory on the attachment child (matches Tickets Request's own default — optional, not
  required before save).
* `_Attachment` and `_Approval` children are byte-for-byte the same shape/behavior as Tickets
  Request's own (`update`/`delete` only on `_Approval` — rows are inserted by the backend
  approval engine, never created via the UI; `update`/`delete` on `_Attachment` with `create`
  granted via the parent's association clause).

## Business logic (`ZBP_HCM_I_ECD`)

* **`setRequestNumber`** — identical max+1 pattern over `ZHCM_ECD_REQ`.
* **`retrieveSystemId`** (determination on modify of `CommunicationType`) — the "retrieve the
  exist data in system" requirement: looks up the employee's current, valid-today **PA0105**
  record for `(Pernr, usrty = CommunicationType)` and pre-fills `SystemId` with the value
  already on file (`PA0105-USRID`). If no such record exists yet, `SystemId` is cleared so the
  employee enters a brand-new value instead of an accidentally-stale one. Same idiom as
  Overtime's balance lookup or Tickets' member auto-population: a determination triggered by a
  side effect, reading standard infotype data and writing the result back onto the entity.
* **`validateEcd`** (validation on save) — no other **own**, still-relevant (`req_status IN
  ('1','2')`) request already changing the *same* `CommunicationType` — reuses `ZHCM_MSGS 004`
  verbatim (the same "There is a request conflict... with no( &1 )" message Leave
  Request/Overtime/Tickets already use for their own duplicate-request checks). No new message
  numbers were needed for this app.
* **`get_instance_features`** (root, `_Attachment`, `_Approval`) — same draft-gated
  update/delete pattern as every other app; `Pernr`/`PlansTxt`/`OrgehTxt`/`RequestId` read-only.

## Save / submit flow (`lsc_zhcm_i_ecd~save_modified`, additional save)

Identical mechanism to every other app in the suite, parameterized for this one:
`ZHCM_UPDATE_APPROVALS(status='I', app_id='04')` (targeting `ZHCM_ECD_APPROV`) →
`SAP_WAPI_START_WORKFLOW(task='WS95000005')` → on failure roll back the approval chain and
report workflow errors; on success persist `WORKITEM_ID`/`RETURN_CODE` and log via
`ZHCM_UPDATE_WORKITEM` into `ZHCM_ECD_WFLOG`.

## Create defaulting (`ZBP_HCM_C_ECD` — projection `augment_create`)

Same pattern as every app in the suite: `ReqStatus = '1'`, `Pernr` resolved from `PA0105`
(`usrid = sy-uname`, `usrty = '0001'`), `ename`/`PlansTxt`/`OrgehTxt` sourced from
`zhcm_employee_help`. `SystemId` is deliberately **not** defaulted here — it's populated by
`retrieveSystemId` once the employee picks a `CommunicationType`, not at create time (the
employee hasn't chosen a type yet when the draft is first created).

## UI (`zhcm_c_ecd_me.ddlx`)

Object page facets: header data points for `Employee` and `ReqStatus`; field group
"Communication Data" (communication type, system ID, begin date, remarks); line-item facets for
`_Attachment` and `_Approval`. List report sorted by `RequestId` descending — same
`statusCriticality` `case` expression reused verbatim from every other app.

## Configuration needed before go-live

1. Add `ZHCM_ESS_APPROV` row(s) for `APP_ID = '04'` (tcode `ZHCM_APPROVALS`) — approver
   type/level is not specified by the requirement; configure whichever is appropriate (direct
   manager, HR, or a named rule) the same way as any other app — see
   [05-approvals-and-rules.md](05-approvals-and-rules.md).
2. Create workflow template `WS95000005` in the Business Workflow Builder, agent determination
   rule = `ZHCM_GET_APPROVALS_IN_USER_DEC` (already extended for `APP_ID = '04'`), and add its
   tasks to `SWFVISU` (Task Visualization) so the approval work item surfaces correctly in
   Fiori My Inbox.
3. Confirm which `USRTY` values (infotype 0105 subtypes) should actually be selectable from
   this app — `zhcm_comm_type_view` currently shows every subtype configured for infotype 0105
   system-wide (including `0001` System user name, which is probably not something ESS users
   should be requesting changes to through this app). Consider adding a `WHERE subty <> '0001'`
   (or an explicit allow-list) to `zhcm_comm_type_view` if the type list needs restricting.
4. Generate the remaining Fiori app scaffold (`Component.js`, `index.html`, `i18n`, local mock
   service files, UI5 ABAP repository mapping) with `@sap/generator-fiori:lrop` pointed at
   `ZHCM_C_ECD_SB` — only `manifest.json` is hand-authored here, same as every other app.
5. Add a Fiori Launchpad catalog tile/semantic object (`zhcm_ecd_req-DISPLAY`).

## Open item: what actually happens to PA0105 on approval

As with every request app in this suite, this repository has no ABAP for the workflow step
that finalizes an approval decision (the code that sets `REQ_STATUS = '2'` and, presumably,
actually posts the new value into infotype 0105 via `HR_INFOTYPE_OPERATION`). Unlike Leave
Request/Overtime — which validate their eventual posting with a BAPI **simulation** call before
allowing save (`BAPI_PTMGRATTABS_MNGCREATION`, `ZHCM_SIMULATE_OVERT_TIME`) — this app has no
equivalent pre-save simulation of the IT0105 update, since none was requested. If the real
posting step needs the same "simulate before you let the employee submit" safety net, add a
validation calling `HR_INFOTYPE_OPERATION` in simulate mode (or the closest available BAPI),
matching the established pattern in
[01-leave-request.md](01-leave-request.md#business-logic-zbp_hcm_i_lr_bd--lhc_lr).
