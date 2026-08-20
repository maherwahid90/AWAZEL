# Time Machine (Biometric Device) Integration

A background integration that pulls raw punch (clock-in/clock-out) events from an external
biometric attendance device database and posts them into SAP as **infotype 2011 (Time Events)**
records. This is documented in the repository itself in `Time Machine Integration.txt`; this
page restates and cross-references it against the actual objects.

Not a Fiori app — it is a **batch report**, normally scheduled periodically (e.g. every few
minutes) as a background job.

## Object stack

| Object | Purpose | File(s) |
|---|---|---|
| Report `ZHCM_TIME_MACHINE_INTEGRATION` | Main pull-and-post job | `zhcm_time_machine_top/_f01.prog.abap`, `Time Machine Integration.txt` |
| Report `ZHCM_TIME_MACHINE_INTEG_RERUN` | Retry job for previously **errored** rows only | `zhcm_time_machine_integ_rerun.prog.abap`, `zhcm_time_machine_rerun_top/_f01.prog.abap` |
| Staging table `ZHCM_TIMEM_DATA` | Local copy of every pulled punch event + posting status | defined inline in `Time Machine Integration.txt` |
| Tcode `ZHCM_TIME_LOG` — "Time Machine Data Log" | ALV report over `ZHCM_TIMEM_DATA` for monitoring/troubleshooting | `zhcm_time_log.tran.xml` |
| External DB connection | `ZKBIOTIME` (secondary DB connection, `EXEC SQL`) | referenced in the report only — connection itself configured in DBCON, not in this repo |

## Flow (main job — `ZHCM_TIME_MACHINE_INTEGRATION`)

1. **`GET_TIME_DATA`**:
   * `SELECT MAX(ID) FROM ZHCM_TIMEM_DATA` — determines the high-water mark of the last
     successful pull.
   * `EXEC SQL CONNECT TO 'ZKBIOTIME'` — opens a **native SQL** connection to the external
     device database (a MySQL-family database judging by table name `iclock_transaction`,
     typical of ZKTeco/biometric terminal software).
   * Opens a cursor on `iclock_transaction WHERE punch_state BETWEEN '0' AND '1' AND ID >
     :MAX_ID` and fetches all new rows into internal table `TIME_IT` (columns: `id`, `emp_code`,
     `punch_time`, `punch_state`, `verify_type`, `work_code`, `terminal_sn`, `terminal_alias`,
     `area_alias`, GPS coordinates, `mobile`, `source`, `purpose`, `crc`, `is_attendance`,
     `upload_time`, `sync_status`/`sync_time`, `is_mask`, `temperature`, `emp_id`,
     `terminal_id`).
   * Disconnects, then persists every fetched row into `ZHCM_TIMEM_DATA` (`MODIFY ... FROM
     TABLE`) so the raw device data is never re-fetched even if posting later fails.
   * On any DB error (open connection, cursor open, disconnect) sets an error message and
     returns without posting — a fully failed pull attempt is logged via email (`SEND_ERROR_
     NOTIFICATION` still fires because `message` is non-initial) but nothing is (re)posted.
2. **`POST_TIME`** — for every row pulled in this run:
   * Parses `punch_time` (ISO-ish `YYYY-MM-DD HH:MM:SS...`) into SAP `LDATE`/`LTIME`.
   * Maps device `punch_state` to SAP time event type `RETYP`: `'0'` → `'P10'` (clock-in),
     `'1'` → `'P20'` (clock-out).
   * Resolves the SAP personnel number from the device's `emp_code` via **infotype 0050**
     (`PA0050-ZAUSW`, the "Time Recording" infotype's badge/device ID field), valid on the punch
     date. **If not mapped, the row is flagged as an error** ("The finger print employee number
     not mapped in infotype 50") and skipped — this is the #1 prerequisite for this integration
     to work for a given employee.
   * Verifies the employee has a **time recording ID** in infotype 0007 (`PA0007-ZTERF <> 0`,
     Planned Working Time / time management status), valid on the punch date; if not, flagged
     as an error ("No time accounts maintained in infotype 7") and skipped.
   * Locks the employee (`BAPI_EMPLOYEE_ENQUEUE`), posts the time event via
     `HR_INFOTYPE_OPERATION` (`infty = '2011'`, `operation = 'INS'`), commits
     (`BAPI_TRANSACTION_COMMIT WAIT='X'`) on success or captures the BAPI return message on
     failure, then unlocks the employee (`BAPI_EMPLOYEE_DEQUEUE`).
   * Every row (success or failure) is written back into `ZHCM_TIMEM_DATA` with `MSG_TYPE`
     (`'S'`/`'E'`) and `MESSAGE` populated, so the log table doubles as the audit trail shown by
     tcode `ZHCM_TIME_LOG`.
3. **`SEND_ERROR_NOTIFICATION`** — if any row has `MSG_TYPE = 'E'` (or a top-level connection
   `message` was set), builds an HTML table of failed rows (device emp code, SAP pernr, punch
   time, error text) and emails it via `CL_BCS`/`CL_DOCUMENT_BCS` to a fixed recipient address
   hardcoded in the report (**`eng.maherwahid@gmail.com`** in `SEND_ERROR_NOTIFICATION`) —
   consider parameterizing this recipient (e.g. via a customizing table or job variant) rather
   than relying on the hardcoded address if this report is copied for a new integration.

## Retry job — `ZHCM_TIME_MACHINE_INTEG_RERUN`

Structurally identical to the main job, but `GET_TIME_DATA` is replaced with a simple
`SELECT * FROM zhcm_timem_data WHERE msg_type = 'E'` — i.e. **no external DB call**, it just
re-attempts posting for whatever is already staged locally with an error status, reusing the
exact same `POST_TIME`/`SEND_ERROR_NOTIFICATION` logic. Intended to be scheduled after fixing
the underlying cause (e.g. after infotype 50/0007 master data is corrected) without re-pulling
from the device.

## Prerequisites checklist (for onboarding a new employee to biometric time capture)

1. Maintain **infotype 0050** with the device badge/employee code in `ZAUSW`.
2. Maintain **infotype 0007** with a non-zero time recording ID (`ZTERF`).
3. The device pushes/stores punches into `iclock_transaction` on the `ZKBIOTIME` database —
   nothing further to configure in SAP once 1–2 are done; the next job run will pick it up.

## Related app

[07-time-sheet-upload.md](07-time-sheet-upload.md) is a **manual Excel-based fallback** for the
exact same infotype 2011 posting, useful when the device/DB link is unavailable.
