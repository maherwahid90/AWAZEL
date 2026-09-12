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
the RAP/CDS/behavior/service layers here are built to match those tables exactly, and have been
revised repeatedly against live testing in the real system.

* `APP_ID = '07'` in the shared approval engine ([05-approvals-and-rules.md](05-approvals-and-rules.md)).
  **Renumbered from the original `'03'`** once other apps (not in this repo) claimed `03`/`05`/`06`
  in the meantime.
* SAP Business Workflow template **`WS95000009`** (renumbered from the original `WS95000004` for
  the same reason) — must be created in the Business Workflow Builder (`PFTC`); it is not
  expressible as ABAP/CDS source, so it is not a file in this repo.
* Fiori Launchpad semantic object: `zhcm_tkt_req`, action `DISPLAY`.

## A note on table format

Unlike every other table in this repository (classic SE11-style, serialized as `.tabl.xml`
with `DD02V`/`DD03P`), the tables behind this app were created using the newer **ABAP Cloud
source-based table definition** syntax (`define table ... { ... }`) and are therefore serialized
here as **`.tabl.astabl`** source files rather than `.tabl.xml`. The draft tables and the
workflow log added to support them follow the same source-based syntax for internal consistency
within this one feature.

## Functional spec → object mapping

| FS requirement | Implementation |
|---|---|
| "Employees can request tickets for work-related travel, events, or conferences" | Root entity `zhcm_i_tkt` / table `ZHCM_TICKET_REQ` |
| "This request can include flight tickets, event tickets, or accommodation bookings" | `_Attachment` composition (`ZHCM_TICK_ATTACH`) for supporting documents |
| "for themselves, their family, or both" | `TicketType` field, domain/data element `ZTICKET_TYPE` (`'01'` Employee / `'02'` Family / `'03'` Employee and Family) |
| "family members are auto-populated from the employee's file" | `_Member` composition to `zhcm_i_tkt_member` / `ZHCM_TICK_MEMBER` — see [Member auto-maintenance](#member-auto-maintenance-populatemembers) below. **Manual add/delete of members is not exposed to the UI** — members exist only because `populateMembers` created them |
| "1st Screen: Submit Tickets Request" | Fiori Elements app `zhcm_tkt_req` (List Report/Object Page) on projection `zhcm_c_tkt`, plus a read-mostly `ZHCM_C_TKT_INBOX` projection for the approver's My Inbox preview — see [Inbox projection](#inbox-projection-zhcm_c_tkt_inbox) below |
| "2nd Screen: HR Tickets Request Approval... HR can approve it or refused" | SAP Business Workflow `WS95000009` (Fiori **My Inbox**), agents resolved by `ZHCM_GET_APPROVALS_IN_USER_DEC` from `ZHCM_ESS_APPROV` rows configured for `APP_ID = '07'` — identical mechanism to Leave/Overtime, see [05-approvals-and-rules.md](05-approvals-and-rules.md) |
| "HR: A custom table has been configured... once approved, automatically replicated" | FM `ZHCM_TICKET_REPLICATE_HR` — see [HR replication hook](#hr-replication-hook-no-dedicated-table) below (no dedicated replication table exists in the current table design) |

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app manifest | `zhcm_tkt_req` (List Report / Object Page) | `zhcm_tkt_req.wapa.manifest.json` |
| Service binding | `ZHCM_C_TKT_SB` (OData v2) | `zhcm_c_tkt_sb.srvb.xml` |
| Service definition (maintenance) | `ZHCM_C_TKT_SD` — exposes `zhcm_c_tkt`, `zhcm_c_tkt_attach`, `zhcm_c_tkt_member`, `zhcm_c_tkt_approvals`, `zhcm_ticket_type_view`, `zhcm_employee_help` | `zhcm_c_tkt_sd.srvd.xml` / `.srvdsrv` |
| Service definition (inbox) | `ZHCM_C_TKT_SD_INBOX` — read-mostly variant for My Inbox, see [below](#inbox-projection-zhcm_c_tkt_inbox) | `zhcm_c_tkt_sd_inbox.srvd.xml` / `.srvdsrv` |
| Projection CDS (maintenance) | `zhcm_c_tkt` (root), `zhcm_c_tkt_attach`, `zhcm_c_tkt_member`, `zhcm_c_tkt_approvals` | `zhcm_c_tkt*.ddls.asddls` |
| Projection CDS (inbox) | `ZHCM_C_TKT_INBOX` (root), `ZHCM_C_TKT_ATTACH_INBOX`, `ZHCM_C_TKT_MEMBER_INBOX`, `ZHCM_C_TKT_APPROVALS_INBOX` | `zhcm_c_tkt_inbox.ddls.asddls`, `zhcm_c_tkt_*_inbox.ddls.asddls` |
| Projection BDEF (maintenance) | `projection implementation in class zbp_hcm_c_tkt` | `zhcm_c_tkt.bdef.asbdef` |
| Projection BDEF (inbox) | Pure declarative `projection;` — no implementing class; root has no create/update/delete at all, only draft actions + associations | `zhcm_c_tkt_inbox.bdef.asbdef` |
| UI metadata ext. (maintenance) | Fiori Elements annotations | `zhcm_c_tkt_me.ddlx.asddlxs`, `zhcm_c_tkt_attach_me`, `zhcm_c_tkt_member_me`, `zhcm_c_tkt_approvals_me` |
| UI metadata ext. (inbox) | Fiori Elements annotations for the inbox projection | `zhcm_c_tkt_inbox_me.ddlx.asddlxs`, `zhcm_c_tkt_*_inbox_me.ddlx.asddlxs` |
| Projection behavior class | `ZBP_HCM_C_TKT` (`augment_create`) | `zbp_hcm_c_tkt.clas.locals_imp.abap` |
| Interface CDS | `zhcm_i_tkt` (root), `zhcm_i_tkt_attach`, `zhcm_i_tkt_member`, `zhcm_i_tkt_approvals` | `zhcm_i_tkt*.ddls.asddls` |
| Interface BDEF | `managed implementation in class zbp_hcm_i_tkt`, `strict(2)`, `with draft` | `zhcm_i_tkt.bdef.asbdef` |
| Interface behavior class | `ZBP_HCM_I_TKT` (determinations, validation, member auto-maintenance, saver) | `zbp_hcm_i_tkt.clas.locals_imp.abap` |
| Active table (header) | `ZHCM_TICKET_REQ` | `zhcm_ticket_req.tabl.astabl` |
| Draft table (header) | `ZHCM_DR_TKT` | `zhcm_dr_tkt.tabl.astabl` |
| Attachment sub-table | `ZHCM_TICK_ATTACH` (+ draft `ZHCM_DR_TKT_AT`) | `zhcm_tick_attach.tabl.astabl` |
| Member sub-table | `ZHCM_TICK_MEMBER` (+ draft `ZHCM_DR_TKT_MEM`) | `zhcm_tick_member.tabl.astabl` |
| Approvals sub-table | `ZHCM_TICK_APPROV` (+ draft `ZHCM_DR_TKT_APS`) | `zhcm_tick_approv.tabl.astabl` |
| Workflow log | `ZHCM_TICK_WFLOG` | `zhcm_tick_wflog.tabl.astabl` |
| HR replication hook | FM `ZHCM_TICKET_REPLICATE_HR` (in function group `ZHCM_FG`) — no dedicated table, see below | `zhcm_fg.fugr.zhcm_ticket_replicate_hr.abap` |
| Ticket type value help | `zhcm_ticket_type_view` (text view, assumed domain `ZTICKET_TYPE`) | `zhcm_ticket_type_view.ddls.asddls` |
| Shared engine changes | `ZHCM_APP_ID` domain value `07`; `ZHCM_UPDATE_APPROVALS` and `ZHCM_GET_APPROVALS_IN_USER_DEC` extended with an `APP_ID = '07'` branch (targeting `ZHCM_TICK_APPROV`/`ZHCM_TICKET_REQ`) | `zhcm_app_id.doma.xml`, `zhcm_fg.fugr.zhcm_update_approvals.abap`, `zhcm_fg.fugr.zhcm_get_approvals_in_user_dec.abap` |
| Messages | New `ZHCM_MSGS` numbers `010`, `018`; reuses `003`, `004` | `zhcm_msgs.msag.xml` |

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
| `TICKET_TYPE` | `ZTICKET_TYPE` | Employee (`'01'`) / Family (`'02'`) / Employee and Family (`'03'`) — confirmed against the real system; `_Member` auto-maintenance and its validation trigger on `'02'`/`'03'` |
| `BEGDA` / `ENDDA` | `BEGDA`/`ENDDA` | Travel period |
| `TICKET_DIRECTION` | `ZTICKET_DIRECTION` | "Travel Ticket Entity/Direction" per the FS — now mandatory |
| `TRAVEL_DESTINATION` | `ZTRAVEL_DESTINATION` | Travel destination — now mandatory |
| `JOURNEY_ROUTE` | `ZJOURNEY_ROUTE` | Journey route |
| `REQ_STATUS` | `ZHCM_REQ_STATUS` | Shared status domain (reused as-is) |
| `RETURN_CODE` / `WORKITEM_ID` | `SYST_SUBRC`/`SWW_WIID` | Workflow work item started for this request |

**No `HIRE_DATE` column** (unlike `ZHCM_LEAVE_REQ`/`ZHCM_OVERT_REQ`, which cache it). `hiredate`
is exposed on `zhcm_i_tkt` via the `EMP` association to `zhcm_employee_help`, but `augment_create`
now sources the *create-response* value directly from **`RP_GET_HIRE_DATE`** (not from
`zhcm_employee_help`'s virtual element) for immediate UI feedback — see
[Create defaulting](#create-defaulting-zbp_hcm_c_tkt--projection-augment_create) below.

### `ZHCM_TICK_ATTACH` — attachments

Same shape as `ZHCM_LR_ATTACH`/`ZHCM_OV_ATTACH`: `ATTACHMENT_UUID` (key), `REQUEST_UUID`,
`ATTACHMENT` (`ZHCM_ATTACHMENT`, large object), `MIMETYPE`, `FILENAME`, `COMMENTS`, standard
admin fields. Not mentioned explicitly in the FS text, but built by the customer team — wired up
here exactly like Leave Request's attachment child (`create`/`update`/`delete`, not mandatory).
Its own `get_instance_features` handler was removed entirely, so update/delete now follow the
plain BDEF permissions unconditionally (no per-instance draft gating for this entity).

### `ZHCM_TICK_MEMBER` — family/companion data

| Field | Type | Notes |
|---|---|---|
| `FAMILY_UUID` (key, with `REQUEST_UUID`) | `sysuuid_x16` | **Now a proper UUID key**, `field (numbering: managed, readonly)` — exactly like `_Attachment`'s `AttachmentUuid`. This replaces the original design where `FAMILY_SEQ` itself was the key. |
| `FAMILY_SEQ` | `abap.int1` | Demoted to a **plain, non-key display-order field** — assigned by `populateMembers` itself as a simple per-request counter, no numbering mechanism involved. |
| `SELECTED` | `boolean` | Employee ticks this for whichever auto-listed dependents actually need a ticket (see UX below) |
| `NAME` | `char200` | Single free-text name field (not split first/last) — built from `PA0021-FAVOR` (family/last name) + `PA0021-FANAM` (first name), confirmed against the real system |
| `GBDAT` (exposed as `Birthdate`) | `gbdat` | Standard SAP birth-date field, from `PA0021-FGBDT` |
| `AGE` | `abap.dec(3,2)` | ⚠️ See [open item](#open-item-age-field-type) below — **this has already dumped live** (`BCD_FIELD_OVERFLOW`) for a real dependent's age |
| `PASSPORT_NO` | `p24_pspnm` | Country-specific (Saudi Arabia, `MOLGA=24`) passport number data element — **not** on `PA0021` itself; looked up per-member from `PA3254`, joined on the same `PERNR`/`SUBTY`/`BEGDA`/`ENDDA` as the `PA0021` record |

No `LOCAL_CREATED_BY`/`LOCAL_LAST_CHANGED_AT`/etc. on this table (unlike the attachment/header
tables) — so its BDEF behavior block has **no `etag master` clause**.

### Member auto-maintenance (`populateMembers`)

A **single** determination now owns the entire lifecycle of `_Member` rows as a function of
`TicketType` (this replaces an earlier, separate `populateMembers`/`clearMembers` pair):

* **`TicketType = '01'`** (Employee only) → any existing `_Member` rows for the request are
  deleted.
* **`TicketType = '02'`/`'03'`** (Family / Employee and Family) → if no `_Member` rows exist yet
  for the request, every infotype 0021 (Family Member/Dependants) record valid today for the
  requester is listed, one `ZHCM_TICK_MEMBER` row per dependent, `Selected = false` by default.

The employee then **ticks `Selected`** for whichever dependents actually need a ticket for this
trip. **There is no manual add or delete of `_Member` rows from the UI at all** — `create`/`delete`
are not exposed on the `Member` projection entity (see [Behavior definition](#behavior-definition-highlights-zhcm_i_tktbdef)
below), so the only fields an employee can ever touch on a member row are `Selected`.
`validateTicket` requires **at least one `Selected = true` member** when `TicketType` is
`'02'`/`'03'` — simply having auto-populated rows present is not enough.

## Behavior definition highlights (`zhcm_i_tkt.bdef`)

Same shape as Leave Request/Overtime: `strict(2)`, `with draft`, `with additional save`,
`create`/`update(features: instance)`/`delete(features: instance)`, draft actions
`Prepare`/`resume`/`Edit`/`Activate optimized`/`Discard`. Differences:

* Three composition children now: `_Attachment`, `_Member`, `_Approval`.
* `determination populateMembers on modify { create; field TicketType; }` +
  `side effects { field TicketType affects entity _Member; }`.
* `_Member`'s own behavior block declares **no `create;`** at all (create-by-association is
  still permitted via the root's `association _Member { create; with draft; }`, which is all
  `populateMembers`'s own `MODIFY ENTITIES ... CREATE BY \_Member` needs — see below) and
  `update (features: instance)` / `delete (features: instance)` for the framework-internal
  delete `populateMembers` performs. `FamilyUuid` is `numbering: managed, readonly`.
* Mandatory (root): `Pernr`, `TicketType`, `Begda`, `Endda`, `TicketDirection`,
  `TravelDestination` (the last two were added after live testing surfaced them as FS
  requirements).

### Why this no longer needs "early numbering"

An earlier design made `FAMILY_SEQ` itself the table key, which (being a plain `INT1`, not a
UUID) required RAP's `early numbering` BDEF clause and a dedicated `FOR NUMBERING` handler
(`earlynumbering_create`) to assign it. That combination was hit by three separate live dumps in
sequence while testing against the real system:

1. `CX_ABAP_BEHV_RUNTIME_ERROR` ("Illegal mixture of ACTIVE and DRAFT in a %TARGET table of a
   CBA activity") — a missing `%is_draft` on the `CREATE BY \_Member` header row.
2. `CX_CSP_ACT_RESPONSE` ("handler returned neither FAILED nor MAPPED for a specific input
   instance") — `earlynumbering_create` re-querying `MAX(family_seq)` per row instead of
   tracking a running counter across the whole batch.
3. `Invalid operation 'O' with entity 'ZHCM_I_TKT'` — after working around the numbering handler
   entirely by writing `_Member` rows directly into the draft table with a plain `INSERT`, RAP's
   own internal draft-consistency tracking (which expects every change to go through EML) could
   no longer reconcile the root instance.

The fix that actually held up: **give `ZHCM_TICK_MEMBER` a real UUID key (`FAMILY_UUID`)**,
exactly like every other composition child in this suite, and demote `FAMILY_SEQ` to an ordinary
display field. With a `numbering: managed` key, `CREATE BY \_Member` needs no numbering handler
at all — it behaves exactly like `_Attachment`'s always has.

## Business logic (`ZBP_HCM_I_TKT`)

* **`setRequestNumber`** — identical max+1 pattern over `ZHCM_TICKET_REQ`.
* **`populateMembers`** — see [Member auto-maintenance](#member-auto-maintenance-populatemembers)
  above. For the family-type branch: builds `Name` from `PA0021-FAVOR`/`FANAM`, looks up
  `PassportNo` from `PA3254`, and computes `Age` inline via `HR_HK_DIFF_BT_2_DATES` (age
  calculation is no longer a separate `calculateAge` determination on `_Member` — it happens once,
  at creation time, in this same method). Issues one `MODIFY ENTITIES` call per invocation that
  combines a `DELETE` (Employee-only tickets) and a `CREATE BY \_Member` (family tickets) for
  every root instance in the batch, via `ENTITY _Member DELETE FROM ... ENTITY tkt CREATE BY
  \_Member ... WITH ... REPORTED DATA(modify_reported)`.
* **`validateTicket`** (validation on save):
  1. `Begda`, `Endda`, `TicketType`, `TicketDirection`, or `TravelDestination` missing → message
     `ZHCM_MSGS 010` ("Enter the Mandatory fields").
  2. If `TicketType` is `'02'`/`'03'`, at least one `_Member` row must have `Selected = true` —
     message `018`.
  3. `Endda < Begda` → message `003` (reused).
  4. No other **own** ticket request (`req_status IN ('1','2','4')`) with an overlapping
     `Begda`–`Endda` range → message `004` (reused).
* **`get_instance_features`** (root, `_Member`, `_Approval`) — same draft-gated update/(delete)
  pattern as every other app. `_Attachment` no longer has its own handler (removed — see above).

### Open item: AGE field type

`ZHCM_TICK_MEMBER-AGE` is typed `DEC(3,2)` — 1 digit before the decimal point, 2 after, so the
maximum representable value is **9.99**. `populateMembers` assigns a whole number of years into
this field; **this has already dumped live** (`CX_SY_CONVERSION_OVERFLOW` /
`BCD_FIELD_OVERFLOW`) for a real dependent aged 10 or over. `AGE` needs to be widened (e.g.
`DEC(3,0)` or a plain integer) before this can be relied on for real use — this is a DDIC change
only you can make on your own table.

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

`ZHCM_UPDATE_APPROVALS(status='I', app_id='07')` (targeting `ZHCM_TICK_APPROV`) →
`SAP_WAPI_START_WORKFLOW(task='WS95000009')` → on failure roll back the approval row and report
workflow errors; on success persist `WORKITEM_ID`/`RETURN_CODE` and log via
`ZHCM_UPDATE_WORKITEM` into `ZHCM_TICK_WFLOG`.

## Create defaulting (`ZBP_HCM_C_TKT` — projection `augment_create`)

Same pattern as every app in the suite: `ReqStatus = '1'`, `Pernr` resolved from `PA0105`
(`usrid = sy-uname`, `usrty = '0001'`), `ename`/`PlansTxt`/`OrgehTxt` sourced from
`zhcm_employee_help`. **`hiredate` is now sourced directly via `RP_GET_HIRE_DATE`**
(`check_infotypes = '0000'`) rather than `zhcm_employee_help`'s virtual element — none of these
four are persisted on `ZHCM_TICKET_REQ`.

## UI (`zhcm_c_tkt_me.ddlx`)

Object page facets: header data points for `Employee` and `ReqStatus`; field group "Ticket Data"
(ticket type, start/end date, direction, destination, route, remarks); line-item facets for
`_Attachment`, `_Member` ("Family Members") and `_Approval`. List report sorted by `RequestId`
descending — same `statusCriticality` `case` expression reused verbatim from Leave
Request/Overtime.

## Inbox projection (`ZHCM_C_TKT_INBOX`)

A second, parallel set of projection CDS views/BDEF/service definition exists purely for the
approver-facing side (SAP Fiori My Inbox / a simplified approval preview), separate from the
`zhcm_c_tkt` maintenance app the requester uses:

* `ZHCM_C_TKT_INBOX` (root, `provider contract transactional_query`), `ZHCM_C_TKT_ATTACH_INBOX`,
  `ZHCM_C_TKT_MEMBER_INBOX`, `ZHCM_C_TKT_APPROVALS_INBOX` — field lists mirror the maintenance
  projection exactly.
* `zhcm_c_tkt_inbox.bdef.asbdef` is a **pure declarative `projection;`** (no
  `implementation in class`) — the root exposes **no create/update/delete at all**, only the
  draft actions (`Prepare`/`resume`/`Edit`/`Activate`/`Discard`) and the three associations.
  `Attachment` keeps `update`/`delete`; `Member` and `Approval` expose neither — this projection
  is for viewing/approving, not for editing request data.
* `ZHCM_C_TKT_SD_INBOX` exposes the four inbox views plus `zhcm_ticket_type_view` and
  `zhcm_employee_help`, same as the maintenance service definition.
* **No service binding was supplied for this projection** — add one in ADT if/when this inbox
  view is wired into a UI (Fiori Elements app, custom My Inbox card, etc.); none is assumed here.

## Configuration needed before go-live

1. Add `ZHCM_ESS_APPROV` row(s) for `APP_ID = '07'` (tcode `ZHCM_APPROVALS`) — a single level,
   typically `APPROVER_TYPE = '02'` (fixed HR employee) or `'03'` (fixed HR position) — see
   [05-approvals-and-rules.md](05-approvals-and-rules.md).
2. Create workflow template `WS95000009` in the Business Workflow Builder, agent determination
   rule = `ZHCM_GET_APPROVALS_IN_USER_DEC` (already extended for `APP_ID = '07'`), and add its
   tasks to `SWFVISU` (Task Visualization) so the approval work item surfaces correctly in Fiori
   My Inbox; have that workflow's "approved" step call `ZHCM_TICKET_REPLICATE_HR`.
3. Confirm the real domain name behind `ZTICKET_TYPE` (assumed `ZTICKET_TYPE`); its fixed values
   (`'01'`/`'02'`/`'03'`) are already confirmed against the real system and used consistently by
   `populateMembers`/`validateTicket`.
4. Widen the `AGE` field type on `ZHCM_TICK_MEMBER` (see [open item](#open-item-age-field-type))
   — this has already dumped against real data.
5. If the inbox projection (`ZHCM_C_TKT_INBOX`/`ZHCM_C_TKT_SD_INBOX`) is meant to be consumed by
   a UI, add a service binding for it — none exists yet in this repo.
6. Generate the remaining Fiori app scaffold (`Component.js`, `index.html`, `i18n`, local mock
   service files, UI5 ABAP repository mapping) with `@sap/generator-fiori:lrop` pointed at
   `ZHCM_C_TKT_SB` — only `manifest.json` is hand-authored here.
7. Add a Fiori Launchpad catalog tile/semantic object (`zhcm_tkt_req-DISPLAY`), same as
   `catalog1.PNG`/`catalog2.PNG` show for the existing apps.
