# Time Sheet Upload

An SAP GUI report giving HR/time administrators a **manual, file-based fallback** for posting
time events (infotype 2011) when the automatic [Time Machine integration](06-time-machine-integration.md)
can't be used — e.g. a spreadsheet export from a device/vendor with no direct DB link, or a
correction batch.

* Tcode: **`ZHCM_UPLOAD_TS`** — "Upload Time sheet", calls program `ZHCM_TIME_SHEET_UPLOAD`
  screen `1000` directly.

## Object stack

| Object | File(s) |
|---|---|
| Report `ZHCM_TIME_SHEET_UPLOAD` | `zhcm_time_sheet_upload.prog.abap` |
| Include `ZHCM_TIME_SHEET_UPLOAD_TOP` (selection screen + types) | `zhcm_time_sheet_upload_top.prog.abap` |
| Include `ZHCM_TIME_SHEET_UPLOAD_F01` (processing logic) | `zhcm_time_sheet_upload_f01.prog.abap` |

## Flow

1. **Selection screen**: a single parameter `S_FILE` (local file path, `F4_FILENAME` value
   help) — an Excel (`.xls`) export with columns `PERNR` (device employee code, text),
   `BEGDA` (punch date, text), `LTIME` (punch time, as an Excel time fraction), `SATZA`
   (SAP time event type, `RETYP`, expected already resolved to `P10`/`P20`/etc. — **unlike**
   Time Machine, this upload does not infer P10 vs P20 from a punch-state code, the file must
   already carry the correct `SATZA`).
2. **`PROCESS_DATA`**:
   * `TEXT_CONVERT_XLS_TO_SAP` parses the Excel file into a working table.
   * Converts the Excel time fraction (`LTIME`, a fraction of a day) into `HH:MM:SS` — both a
     display string and the true `UZEIT` value (`SAP_LTIME`) via day-fraction arithmetic
     (`floor(ltime * 86400 / 3600)` etc.).
   * Converts the date column from a display `DD.MM.YYYY`-ish text field into SAP `BEGDA`
     format.
   * Same two prerequisite checks and posting sequence as the Time Machine integration:
     resolve SAP `PERNR` from **infotype 0050** (`PA0050-ZAUSW`) — error row if not mapped;
     verify **infotype 0007** has a non-zero `ZTERF` — error row if not; lock the employee, post
     via `HR_INFOTYPE_OPERATION` (`infty = '2011'`, `operation = 'INS'`), commit on success,
     unlock. Every row's outcome is written to a `REMARKS` column.
3. **`BUILD_FCAT`** / **`ALV_DISPLAY`**: shows an ALV grid of every uploaded row with both the
   raw file values and the resolved SAP values (`SAP_PERNR`, `SAP_BEGDA`, `SAP_LTIME`) plus the
   posting outcome in `REMARKS` — this report has **no persistent log table**; the ALV output
   is the only record of a given upload run (unlike `ZHCM_TIMEM_DATA` for Time Machine).

## Notes / differences from Time Machine Integration

* No staging table — nothing is persisted before posting, so a failed run must be re-uploaded
  from the same source file rather than "rerun" like `ZHCM_TIME_MACHINE_INTEG_RERUN`.
* No email notification — errors are only visible in the on-screen ALV grid for that session.
* Column `SATZA`/time event type comes directly from the file rather than being derived, so the
  uploader (a human) is trusted to classify clock-in vs clock-out correctly.
