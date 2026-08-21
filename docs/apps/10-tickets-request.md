# Tickets Request (ESS) — new application

Employee Self-Service Fiori app implementing the **"Tickets Request Custom App"** functional
spec (`HCM-FS { Tickets Request Custom App }`, v1, 04.05.2025): employees request tickets for
work-related travel, events or conferences — for themselves, their family, or both — with
family/companion data auto-populated from HR master data, routed through a single-level **HR
approval** step (SAP Business Workflow / Fiori My Inbox), with the approved request available
for downstream replication.

Built with the exact same RAP pattern as [Leave Request](01-leave-request.md) and
[Overtime Request](02-overtime-request.md) — see [../README.md](../README.md) for the shared
5-layer architecture and the "how to add a new self-service request app" checklist this app
follows. **All persistence tables below were authored by the customer team, not generated** —
the RAP/CDS/behavior/service layers here are built to match those tables exactly.

* `APP_ID = '03'` in the shared approval engine ([05-approvals-and-rules.md](05-approvals-and-rules.md)).
* SAP Business Workflow template **`WS95000004`** (next in sequence after `WS95000002`/
  `WS95000003`) — must be created in the Business Workflow Builder (`PFTC`) the same way the
  other two were; it is not expressible as ABAP/CDS source, so it is not a file in this repo
  (same as `WS95000002`/`WS95000003`).
* Fiori Launchpad semantic object: `zhcm_tkt_req`, action `DISPLAY`.

## A note on table format

Unlike every other table in this repository (classic SE11-style, serialized as `.tabl.xml`
with `DD02V`/`DD03P`), the four tables behind this app were created using the newer **ABAP
Cloud source-based table definition** syntax (`define table ... { ... }`) and are therefore
serialized here as **`.tabl.astabl`** source files rather than `.tabl.xml`. The draft tables and
the workflow log added to support them follow the same source-based syntax for internal
consistency within this one feature.

## Functional spec → object mapping

| FS requirement | Implementation |
|---|---|
| "Employees can request tickets for work-related travel, events, or conferences" | Root entity `zhcm_i_tkt` / table `ZHCM_TICKET_REQ` |
| "This request can include flight tickets, event tickets, or accommodation bookings" | `_Attachment` composition (`ZHCM_TICK_ATTACH`) for supporting documents |
| "for themselves, their family, or both" | `TicketType` field, domain/data element `ZTICKET_TYPE` |
| "family members are auto-populated from the employee's file... can also manually add and select" | `_Member` composition to `zhcm_i_tkt_member` / `ZHCM_TICK_MEMBER` — see [Family/member auto-population](#family-member-auto-population-from-pa0021) |
| "1st Screen: Submit Tickets Request" | Fiori Elements app `zhcm_tkt_req` (List Report/Object Page) on projection `zhcm_c_tkt` |
| "2nd Screen: HR Tickets Request Approval... HR can approve it or refused" | SAP Business Workflow `WS95000004` (Fiori **My Inbox**), agents resolved by `ZHCM_GET_APPROVALS_IN_USER_DEC` from `ZHCM_ESS_APPROV` rows configured for `APP_ID = '03'` — identical mechanism to Leave/Overtime, see [05-approvals-and-rules.md](05-approvals-and-rules.md) |
| "HR: A custom table has been configured... once approved, automatically replicated" | FM `ZHCM_TICKET_REPLICATE_HR` — see [HR replication hook](#hr-replication-hook-no-dedicated-table) below (no dedicated replication table exists in the current table design) |

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app manifest | `zhcm_tkt_req` (List Report / Object Page) | `zhcm_tkt_req.wapa.manifest.json` |
| Service binding | `ZHCM_C_TKT_SB` (OData v2) | `zhcm_c_tkt_sb.srvb.xml` |
| Service definition | `ZHCM_C_TKT_SD` — exposes `zhcm_c_tkt`, `zhcm_c_tkt_attach`, `zhcm_c_tkt_member`, `zhcm_c_tkt_approvals`, `zhcm_ticket_type_view`, `zhcm_employee_help` | `zhcm_c_tkt_sd.srvd.xml` / `.srvdsrv` |
| Projection CDS | `zhcm_c_tkt` (root), `zhcm_c_tkt_attach`, `zhcm_c_tkt_member`, `zhcm_c_tkt_approvals` | `zhcm_c_tkt*.ddls.asddls` |
| Projection BDEF | `projection implementation in class zbp_hcm_c_tkt` | `zhcm_c_tkt.bdef.asbdef` |
| UI metadata ext. | Fiori Elements annotations | `zhcm_c_tkt_me.ddlx.asddlxs`, `zhcm_c_tkt_attach_me`, `zhcm_c_tkt_member_me`, `zhcm_c_tkt_approvals_me` |
| Projection behavior class | `ZBP_HCM_C_TKT` (`augment_create`) | `zbp_hcm_c_tkt.clas.locals_imp.abap` |
| Interface CDS | `zhcm_i_tkt` (root), `zhcm_i_tkt_attach`, `zhcm_i_tkt_member`, `zhcm_i_tkt_approvals` | `zhcm_i_tkt*.ddls.asddls` |
| Interface BDEF | `managed implementation in class zbp_hcm_i_tkt`, `strict(2)`, `with draft` | `zhcm_i_tkt.bdef.asbdef` |
| Interface behavior class | `ZBP_HCM_I_TKT` (determinations, validation, member auto-fill, early numbering, saver) | `zbp_hcm_i_tkt.clas.locals_imp.abap` |
| Active table (header) | `ZHCM_TICKET_REQ` | `zhcm_ticket_req.tabl.astabl` |
| Draft table (header) | `ZHCM_DR_TKT` | `zhcm_dr_tkt.tabl.astabl` |
| Attachment sub-table | `ZHCM_TICK_ATTACH` (+ draft `ZHCM_DR_TKT_AT`) | `zhcm_tick_attach.tabl.astabl` |
| Member sub-table | `ZHCM_TICK_MEMBER` (+ draft `ZHCM_DR_TKT_MEM`) | `zhcm_tick_member.tabl.astabl` |
| Approvals sub-table | `ZHCM_TICK_APPROV` (+ draft `ZHCM_DR_TKT_APS`) | `zhcm_tick_approv.tabl.astabl` |
| Workflow log | `ZHCM_TICK_WFLOG` | `zhcm_tick_wflog.tabl.astabl` |
| HR replication hook | FM `ZHCM_TICKET_REPLICATE_HR` (in function group `ZHCM_FG`) — no dedicated table, see below | `zhcm_fg.fugr.zhcm_ticket_replicate_hr.abap` |
| Ticket type value help | `zhcm_ticket_type_view` (text view, assumed domain `ZTICKET_TYPE`) | `zhcm_ticket_type_view.ddls.asddls` |
| Shared engine changes | `ZHCM_APP_ID` domain value `03`; `ZHCM_UPDATE_APPROVALS` and `ZHCM_GET_APPROVALS_IN_USER_DEC` extended with an `APP_ID = '03'` branch (targeting `ZHCM_TICK_APPROV`/`ZHCM_TICKET_REQ`) | `zhcm_app_id.doma.xml`, `zhcm_fg.fugr.zhcm_update_approvals.abap`, `zhcm_fg.fugr.zhcm_get_approvals_in_user_dec.abap` |
| Messages | New `ZHCM_MSGS` number `011`; reuses `003`, `004` | `zhcm_msgs.msag.xml` |

Data elements `ZTICKET_TYPE`, `ZTICKET_DIRECTION`, `ZTRAVEL_DESTINATION`, `ZJOURNEY_ROUTE` are
assumed to already exist in the target system (per the table definitions supplied) and are not
re-created here. `zhcm_ticket_type_view` assumes the domain backing `ZTICKET_TYPE` is also named
`ZTICKET_TYPE` (the common convention elsewhere in this codebase, e.g. `ZHCM_REQ_STATUS`); adjust
its `WHERE domname = ...` if the real domain name differs.

## Data model

### `ZHCM_TICKET_REQ` — header

Key: `CLIENT`, `REQUEST_UUID`. Notable fields (as supplied):

| Field | Type | Purpose |
|---|---|---|
| `REQUEST_ID` | `ZHCM_REQ_NO` | Sequential request number (max+1 pattern, same as every other app) |
| `PERNR` | `PERNR_D` | Requesting employee |
| `TICKET_TYPE` | `ZTICKET_TYPE` | Employee / Family / Both (exact value texts not confirmed — see open item) |
| `BEGDA` / `ENDDA` | `BEGDA`/`ENDDA` | Travel period |
| `TICKET_DIRECTION` | `ZTICKET_DIRECTION` | "Travel Ticket Entity/Direction" per the FS |
| `TRAVEL_DESTINATION` | `ZTRAVEL_DESTINATION` | Travel destination |
| `JOURNEY_ROUTE` | `ZJOURNEY_ROUTE` | Journey route |
| `REQ_STATUS` | `ZHCM_REQ_STATUS` | Shared status domain (reused as-is) |
| `RETURN_CODE` / `WORKITEM_ID` | `SYST_SUBRC`/`SWW_WIID` | Workflow work item started for this request |

**No `HIRE_DATE` column** (unlike `ZHCM_LEAVE_REQ`/`ZHCM_OVERT_REQ`, which cache it). `hiredate`
is exposed on `zhcm_i_tkt` purely via the `EMP` association to `zhcm_employee_help` (itself a
virtual element calculated by `ZCL_VIRTUAL_ELEMENT_CALC`) — it is never a persisted field on
this table. `augment_create` still seeds it into the create-response buffer for immediate UI
feedback, the same idiom Leave Request already uses for `ename`/`PlansTxt`/`OrgehTxt` (which
also aren't stored on `ZHCM_LEAVE_REQ`).

### `ZHCM_TICK_ATTACH` — attachments

Same shape as `ZHCM_LR_ATTACH`/`ZHCM_OV_ATTACH`: `ATTACHMENT_UUID` (key), `REQUEST_UUID`,
`ATTACHMENT` (`ZHCM_ATTACHMENT`, large object), `MIMETYPE`, `FILENAME`, `COMMENTS`, standard
admin fields. Not mentioned explicitly in the FS text, but built by the customer team — wired up
here exactly like Leave Request's attachment child (`create`/`update`/`delete`, not mandatory —
the FS never states an attachment requirement for tickets, so no "attachment required" validation
was added; add one in `validateTicket` if that turns out to be needed).

### `ZHCM_TICK_MEMBER` — family/companion data

| Field | Type | Notes |
|---|---|---|
| `FAMILY_SEQ` (key, with `REQUEST_UUID`) | `abap.int1` | **Not a UUID** — a per-request running line number, unlike every other child entity in this suite. See [Numbering ZHCM_TICK_MEMBER](#numbering-zhcm_tick_member-early-numbering) below. |
| `SELECTED` | `boolean` | Employee ticks this for whichever auto-listed dependents actually need a ticket (see UX below) |
| `NAME` | `char200` | Single free-text name field (not split first/last) |
| `GBDAT` (exposed as `Birthdate`) | `gbdat` | Standard SAP birth-date field |
| `AGE` | `abap.dec(3,2)` | ⚠️ See [open item](#open-item-agepassport_no-field-types) below — this type can only hold ages up to 9.99 |
| `PASSPORT_NO` | `p24_pspnm` | Country-specific (Saudi Arabia, `MOLGA=24`) passport number data element |

No `LOCAL_CREATED_BY`/`LOCAL_LAST_CHANGED_AT`/etc. on this table (unlike the attachment/header
tables) — so its BDEF behavior block has **no `etag master` clause** (there is no field to use
as one).

### Member selection UX

`populateMembers` (determination on `TicketType`) auto-lists **every** infotype 0021 (Family
Member/Dependants) record valid today for the requester, one `ZHCM_TICK_MEMBER` row per
dependent, `Selected = false` by default, whenever `TicketType` is `2`/`3`. The employee then
**ticks `Selected`** for whichever dependents actually need a ticket for this trip, and can still
add further rows by hand (`create` is enabled on `_Member`) for anyone not found in PA0021.
`validateTicket` requires **at least one `Selected = true` member** when `TicketType` is `2`/`3`
— simply having auto-populated rows present is not enough.

## Behavior definition highlights (`zhcm_i_tkt.bdef`)

Same shape as Leave Request/Overtime: `strict(2)`, `with draft`, `with additional save`,
`create`/`update(features: instance)`/`delete(features: instance)`, draft actions
`Prepare`/`resume`/`Edit`/`Activate optimized`/`Discard`. Differences:

* Three composition children now: `_Attachment`, `_Member`, `_Approval`.
* `determination populateMembers on modify { create; field TicketType; }` +
  `side effects { field TicketType affects entity _Member; }`.
* `_Member`'s own behavior block is declared **`early numbering`** (see below) and has no
  `etag master` clause.
* Mandatory: `Pernr`, `TicketType`, `Begda`, `Endda` (root); `Attachment` (attachment child);
  `Name` (member child).

### Numbering `ZHCM_TICK_MEMBER` (early numbering)

Every other child entity in this app suite (`_Attachment`, `RequestUuid` itself) uses RAP's
built-in `field ( numbering : managed, readonly )` UUID generation. `ZHCM_TICK_MEMBER`'s key
field `FAMILY_SEQ` is an `INT1` running line number instead, which that mechanism cannot
auto-generate. Two different paths assign it:

* **Auto-populated rows** (from `populateMembers`): the determination itself builds the create
  request and assigns `FamilySeq` directly (a simple per-request counter) — no special
  machinery needed, since the server-side code already controls the full row.
* **Rows the employee adds by hand** via the Fiori Elements "Add" button: the UI doesn't know
  the next sequence number, so the entity is declared `early numbering` in the BDEF, and
  `zbp_hcm_i_tkt` implements `lhc__Member~earlynumbering_create` (`FOR NUMBERING`) to compute
  `MAX(family_seq) + 1` per request and assign it before the row is created.

**This early-numbering handler is the one piece of RAP code in this app that could not be
verified against a real ABAP compiler in this session** — the general shape (a `FOR NUMBERING`
method building a `mapped-_member` table keyed by `%cid`/`%key`/`%is_draft`) matches the
documented RAP pattern, but re-check it against ADT's syntax check/type proposal when you
activate this object, and adjust if the exact field names differ.

## Business logic (`ZBP_HCM_I_TKT`)

* **`setRequestNumber`** — identical max+1 pattern over `ZHCM_TICKET_REQ`.
* **`populateMembers`** — see [Member selection UX](#member-selection-ux) above. Concatenates
  `PA0021-FANAM` and `PA0021-NACHN` into the single `Name` field (verify the actual "last/family
  name" field on your PA0021 subtype structure — this repeats the same open item flagged in the
  original design).
* **`validateTicket`** (validation on save):
  1. If `TicketType` is `2`/`3`, at least one `_Member` row must have `Selected = true` —
     message `ZHCM_MSGS 011`.
  2. `Endda < Begda` → message `003` (reused).
  3. No other **own** ticket request (`req_status IN ('1','2','4')`) with an overlapping
     `Begda`–`Endda` range → message `004` (reused).
* **`lhc__Member~calculateAge`** (determination on modify of `Birthdate`) — computes `Age` via
  `HR_HK_DIFF_BT_2_DATES` (same FM reused from `ZHCM_CL_EOS_DURATION_CALC`, see
  [08-shared-master-data-and-enhancements.md](08-shared-master-data-and-enhancements.md)),
  taking the `years` component. **See the open item below before activating** — the target
  field's type can't actually hold most real ages.
* **`get_instance_features`** (root, `_Attachment`, `_Member`, `_Approval`) — same draft-gated
  update/delete pattern as every other app.

### Open item: AGE/PASSPORT_NO field types

* `ZHCM_TICK_MEMBER-AGE` is typed `DEC(3,2)` — 1 digit before the decimal point, 2 after, so
  the maximum representable value is **9.99**. `calculateAge` assigns a whole number of years
  into this field; for any dependent aged 10 or over this will overflow (likely a runtime
  short dump on activation, not merely a wrong value). This looks like it should be an integer
  or `DEC(3,0)` — flagging clearly rather than silently working around it, since this is your
  table and not mine to change unilaterally.
* `PASSPORT_NO` uses `P24_PSPNM` (Saudi Arabia / `MOLGA=24`-specific) rather than the generic
  `PSPNM` used elsewhere in this codebase — assumed intentional given the KSA-specific pattern
  already established elsewhere in this suite (EOS duration calc, IT0008 validation), but worth
  a quick confirmation if this app is ever used for other country groupings.

## HR replication hook (no dedicated table)

Per your direction, this design does **not** invent a `ZHCM_TKT_HR`/`ZHCM_TKT_HR_FAM`-style
replication table (none exists in your table set). Instead, `ZHCM_TICKET_REPLICATE_HR`:

1. Reads the approved `ZHCM_TICKET_REQ` header.
2. Reads every `ZHCM_TICK_MEMBER` row with `SELECTED = 'X'`.
3. Returns both to the caller (`EXPORTING header`, `TABLES members`) with a `TODO` marking
   where a downstream call (RFC/BAPI/proxy to whatever system actually needs this data, or an
   `INSERT`/`MODIFY` if a real replication table is added later) belongs.

As with Leave Request/Overtime, **this repository has no ABAP for the workflow step that
finalizes an approval decision** (the code that sets `REQ_STATUS = '2'`) — that step, wherever
it lives in the Business Workflow Builder configuration, should call
`ZHCM_TICKET_REPLICATE_HR(requestuuid)` right after setting the status.

## Save / submit flow (`lsc_zhcm_i_tkt~save_modified`, additional save)

Unchanged from the original design: `ZHCM_UPDATE_APPROVALS(status='I', app_id='03')` (now
targeting `ZHCM_TICK_APPROV`) → `SAP_WAPI_START_WORKFLOW(task='WS95000004')` → on failure roll
back the approval row and report workflow errors; on success persist `WORKITEM_ID`/
`RETURN_CODE` and log via `ZHCM_UPDATE_WORKITEM` into `ZHCM_TICK_WFLOG`.

## Create defaulting (`ZBP_HCM_C_TKT` — projection `augment_create`)

Same pattern as every app in the suite: `ReqStatus = '1'`, `Pernr` resolved from `PA0105`
(`usrid = sy-uname`, `usrty = '0001'`), `ename`/`PlansTxt`/`OrgehTxt`/`hiredate` all sourced from
`zhcm_employee_help` (none of these four are persisted on `ZHCM_TICKET_REQ`).

## UI (`zhcm_c_tkt_me.ddlx`)

Object page facets: header data points for `Employee` and `ReqStatus`; field group "Travel Data"
(ticket type, start/end date, direction, destination, route, remarks); line-item facets for
`_Attachment`, `_Member` ("Family Members") and `_Approval`. List report sorted by `RequestId`
descending — same `statusCriticality` `case` expression reused verbatim from Leave
Request/Overtime.

## Configuration needed before go-live

1. Add `ZHCM_ESS_APPROV` row(s) for `APP_ID = '03'` (tcode `ZHCM_APPROVALS`) — a single level,
   typically `APPROVER_TYPE = '02'` (fixed HR employee) or `'03'` (fixed HR position) — see
   [05-approvals-and-rules.md](05-approvals-and-rules.md).
2. Create workflow template `WS95000004` in the Business Workflow Builder, agent determination
   rule = `ZHCM_GET_APPROVALS_IN_USER_DEC` (already extended for `APP_ID = '03'`), and add its
   tasks to `SWFVISU` (Task Visualization) so the approval work item surfaces correctly in Fiori
   My Inbox; have that workflow's "approved" step call `ZHCM_TICKET_REPLICATE_HR`.
3. Confirm the real domain name behind `ZTICKET_TYPE` (assumed `ZTICKET_TYPE`) and its fixed
   values, and adjust `zhcm_ticket_type_view` if it differs.
4. Fix the `AGE` field type on `ZHCM_TICK_MEMBER` (see [open item](#open-item-agepassport_no-field-types)) before activating `calculateAge`.
5. Verify the PA0021 "last/family name" field used by `populateMembers` against the real subtype
   structure.
6. Re-check the `earlynumbering_create` method (see
   [Numbering ZHCM_TICK_MEMBER](#numbering-zhcm_tick_member-early-numbering)) against ADT's
   syntax check — it's the one piece of code in this app not verified against a live compiler.
7. Generate the remaining Fiori app scaffold (`Component.js`, `index.html`, `i18n`, local mock
   service files, UI5 ABAP repository mapping) with `@sap/generator-fiori:lrop` pointed at
   `ZHCM_C_TKT_SB` — only `manifest.json` is hand-authored here.
8. Add a Fiori Launchpad catalog tile/semantic object (`zhcm_tkt_req-DISPLAY`), same as
   `catalog1.PNG`/`catalog2.PNG` show for the existing apps.
