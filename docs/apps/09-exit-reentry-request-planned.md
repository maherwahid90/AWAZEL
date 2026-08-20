# Exit / Re-entry Visa Request — ⚠️ Planned, Data Model Only

Unlike every other application in this repository, **Exit/Re-entry Visa Request has no CDS
views, no behavior definition, no Fiori app and no OData service** — only its three database
tables exist. It is documented here explicitly so that a future "new application" self-service
request to build this out is recognized as **completing an existing design**, not starting from
a blank page — and so the existing table shapes are reused rather than re-invented.

This is a Saudi-market HR process: requesting an **exit/re-entry visa** for an expatriate
employee to legally leave and return to the country (e.g. for annual leave travel), tracked
alongside the employee's Iqama/residency ID.

## What already exists

| Table | Purpose | Shape |
|---|---|---|
| `ZHCM_EXIT_REQ` | Request header | `REQUEST_UUID` (key), `REQUEST_ID` (`ZHCM_REQ_NO`), `PERNR`, `HIRE_DATE`, `ICNUM` (`PSG_IDNUM` — Iqama/ID number), `EXPID` (`EXPID` — passport/expiry-tracking ID type), `NATIO`, `VISA_DUR` (`ZHCM_VISA_DUR`), `VISA_TYPE` (`ZHCM_VISA_TY`), `VISA_PURP` (`ZHCM_VISA_PURP`), `TRAVEL_D` (travel date), `REMARKS` (`ZHCM_REQ_REMARKS`), `REQ_STATUS` (`ZHCM_REQ_STATUS` — the same shared status domain), the standard RAP admin fields (`LOCAL_CREATED_BY/AT`, `LOCAL_LAST_CHANGED_BY/AT`, `LAST_CHANGED_AT`), `RETURN_CODE`, `WORKITEM_ID` |
| `ZHCM_EXIT_APPROV` | Approval chain sub-table | **Identical shape** to `ZHCM_LR_APPROV`/`ZHCM_OV_APPROV`: `REQUEST_UUID` + `APPROVAL_SEQ` (key), `APPROVAL_PERNR`, `APPROVAL_NAME`, `RECEIVE_TS`, `COMPLETE_TS`, `STATUS`, `APPROVAL_COMMENT`, `APPROVAL_USER`, `WF_USER` |
| `ZHCM_EXIT_ATTACH` | Attachment sub-table | **Identical shape** to `ZHCM_LR_ATTACH`/`ZHCM_OV_ATTACH`: `ATTACHMENT_UUID` (key), `REQUEST_UUID`, `ATTACHMENT` (`ZHCM_ATTACHMENT`), `MIMETYPE`, `FILENAME`, `COMMENTS`, standard admin fields |

No draft tables (`ZHCM_DR_EXIT*`) exist yet, confirming the RAP layer was never started.

## Domains already defined

| Domain | Values |
|---|---|
| `ZHCM_VISA_DUR` | `1`–`12` → "1 Month" … "12 Months" |
| `ZHCM_VISA_TY` | `1` Single Entry Visa · `2` Multiple Entry Visa |
| `ZHCM_VISA_PURP` | `1` Annual Leave · `2` Business Visit · `3` Extension of Business Visa · `4` Others |

## Build plan (follow the pattern in [../README.md](../README.md) and [01-leave-request.md](01-leave-request.md))

Because the table design already matches the Leave Request/Overtime pattern exactly, building
this app is mechanical:

1. Register `APP_ID` value (e.g. `03`) for "Exit/Re-entry Visa Request" in `ZHCM_APP_ID`.
2. Add `ZHCM_DR_EXIT` (+ `_APS`, `_AT` draft variants).
3. Interface CDS `zhcm_i_exit` (root, `composition` to interface CDS wrapping
   `ZHCM_EXIT_ATTACH`/`ZHCM_EXIT_APPROV`) + BDEF (`managed ... with draft`, persistent table
   `ZHCM_EXIT_REQ`, `with additional save`) — copy `zhcm_i_lr.bdef` structurally, replacing the
   leave-specific determinations/validations with exit-specific ones (e.g. Iqama/visa validity
   checks, travel date must be in the future, etc. — business rules not present anywhere in the
   current codebase and need to be sourced from the process owner).
4. Interface behavior class with `setRequestNumber`, a validation on save, and
   `lsc_zhcm_i_exit~save_modified` calling `ZHCM_UPDATE_APPROVALS`/`SAP_WAPI_START_WORKFLOW`/
   `ZHCM_UPDATE_WORKITEM` exactly like Leave Request/Overtime (needs `ZHCM_UPDATE_APPROVALS`'s
   `CASE app_id` extended to target `ZHCM_EXIT_APPROV`, and a new workflow template).
5. Projection CDS + BDEF + `.ddlx` UI annotations + projection behavior class with
   `augment_create` defaulting `Pernr`/`HireDate`/name from `PA0105`/`zhcm_employee_help`,
   exactly like the other two apps.
6. Service definition/binding, Fiori Elements List Report/Object Page app, Fiori Launchpad
   catalog tile — see [../README.md](../README.md#how-to-add-a-new-self-service-request-app).
7. `ZHCM_ESS_APPROV` configuration rows for the new `APP_ID` via tcode `ZHCM_APPROVALS`.

## Open questions to resolve with the process owner before building

* What validates `TRAVEL_D` / `VISA_DUR` (e.g. against the employee's Iqama expiry, or a
  minimum notice period)? No such rule exists anywhere in the current codebase.
* Is `ICNUM`/`EXPID` entered manually by the employee or looked up from an HR infotype
  (residency/ID data is often held in a custom or country-specific infotype not present in this
  repository)?
* Does this request post anywhere in SAP on approval (unlike Leave/Overtime, which post to
  infotypes 2001/0015), or is it purely a document/approval trail for an external visa
  process?
