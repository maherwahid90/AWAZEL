# Shared Master Data CDS Views, Domains & HR Enhancements

Cross-cutting building blocks consumed by multiple applications, plus standard-SAP
enhancements/BAdIs that implement Saudi-specific (KSA, `MOLGA = '24'`) HR business rules. These
are not applications in their own right but are essential context for extending any of them.

## 8.1 Shared CDS views

### `zhcm_employee_help` — the universal employee value help

```
select from pa0001
  inner join pa0002 on pa0001.pernr = pa0002.pernr
  inner join t500p  on t500p.persa  = pa0001.werks
  association [1] to I_CompanyCode on ... = pa0001.bukrs
  association [1] to hrp1000 as plans_txt on objid = pa0001.plans and otype = 'S' (position text)
  association [1] to hrp1000 as orgeh_txt on objid = pa0001.orgeh and otype = 'O' (org unit text)
```
Exposes name, company (+ text), personnel area (+ text), personnel subarea/group, org unit (+
text), position (+ text), gender, nationality, and **four virtual elements** —
`hiredate`, `ENTITLE`, `DEDUCT`, `PENDINGREQ`, `REST` — all calculated on read by
`ZCL_VIRTUAL_ELEMENT_CALC` (§8.3). Used as the employee value help / text association in:
Leave Request (`SubtEmp`), Overtime, Leave Balance, and Payroll Data (Admin).

### `zhcm_absence_types_cds` — leave type texts

`T554T`/`T554S` joined and filtered to grouping `MOABW = '90'`, screen `2000`/`2001` — the
custom absence-type subset relevant to ESS, in the session language. Used by Leave Request's
`Awart` value help and Leave Balance's consuming-document view.

### `zhcm_req_status_view` — generic request status texts

Thin wrapper over `DD07T` filtered to `DOMNAME = 'ZHCM_REQ_STATUS'` — reused by both request
apps so a status text/label never needs to be duplicated per app.

### `zhcm_quotas` / `zhcm_emp_quota` — time quota type texts

`zhcm_quotas`: `T556B` filtered to `MOPGK = '2'`, `MOZKO = '90'` — quota-type texts consumed by
Leave Balance. `zhcm_emp_quota` exists as a sibling CDS (own `.ddls`) — check its definition
before assuming it's identical; it is not currently wired into any documented app's UI (verify
before reuse).

### `zhcm_v_emp_payroll_period` / `_adm`

Payroll period value helps (`HRPY_RGDIR` × `T247` month names), the `_adm` variant without the
`$session.user` employee restriction — used by Payslip employee/admin respectively (doc 04).

## 8.2 Domains (fixed value lists)

Documented in full in [../README.md](../README.md) — `ZHCM_REQ_STATUS`, `ZHCM_APPROVER_TYPE`,
`ZHCM_APP_ID`. Other custom domains in the repo used for the (currently unbuilt) Exit/Re-entry
Visa Request — `ZHCM_VISA_DUR`, `ZHCM_VISA_TY`, `ZHCM_VISA_PURP` — are documented in
[09-exit-reentry-request-planned.md](09-exit-reentry-request-planned.md).

## 8.3 Virtual element read-exits (`if_sadl_exit_calc_element_read`)

RAP/CDS "virtual elements" backed by a small ABAP class implementing the SADL read-exit
interface — the standard pattern for a computed field that can't be expressed as a CDS
expression (it needs a BAPI/FM call). Both classes here follow the identical shape: `calculate`
loops the input rows, enriches them, `get_calculation_info` is unused (empty).

| Class | Backs field(s) on | Logic |
|---|---|---|
| `ZCL_VIRTUAL_ELEMENT_CALC` | `zhcm_employee_help.hiredate/ENTITLE/DEDUCT/PENDINGREQ/REST` | `RP_GET_HIRE_DATE` for hire date; `BAPI_TIMEQUOTA_GETDETAILEDLIST` (quota `01`, as-of today) for entitlement/deducted; subtracts the employee's own pending (`req_status = 1`) annual-leave requests from `ZHCM_LEAVE_REQ` to get `REST` — **identical formula to `recalculateBalance` in Leave Request** (doc 01); kept in sync manually since it's duplicated logic. |
| `ZHCM_OVER_CHECK_MANAGER_ANZHL` | `zhcm_i_over.manager_anzhl_h` | See [02-overtime-request.md](02-overtime-request.md#virtual-element-manager_anzhl_h) — resolves whether the current user is the request owner's manager. |

**When adding a similar computed field to a new CDS view**, follow this same pattern: declare
the field `@ObjectModel.virtualElement: true` /
`@ObjectModel.virtualElementCalculatedBy: 'ABAP:<class>'` with a `cast('' as <type>)` /
`cast(0 as <type>)` placeholder, and implement `IF_SADL_EXIT_CALC_ELEMENT_READ~CALCULATE`
against `IT_ORIGINAL_DATA` cast to the view's row type.

## 8.4 Infotype validation exits (`IF_EX_HRPAD00INFTY`, BAdI `HRPAD00INFTY`)

Two independent BAdI implementations, both firing on infotype maintenance (`AFTER_INPUT`),
i.e. they run **regardless of whether the record originates from PA30/PA20, the ESS apps'
BAPI-simulation validations, or any future posting path** — they are the final, always-enforced
line of defense.

### `ZCL_IM_HCM_LEAVE_REQ_VALID` — infotype 2001 (Absences) rules

Fires when `new_innnn-infty = '2001'` and the operation is insert/modify. See
[01-leave-request.md](01-leave-request.md#zcl_im_hcm_leave_req_valid-badi-hrpad00infty-method-after_input)
for the full rule set (3-month waiting period for annual/marriage leave unless authorization
object `ZHCM_2001` is granted, 2-year wait + one-time-only for Hajj leave, Saudi-nationals-only
exam leave).

Authorization object **`ZHCM_2001`** (`zhcm_2001.auth.xml`/`zhcm_2001.suso.xml`) is checked
here specifically to allow authorized HR staff to bypass the waiting-period rule (e.g. for
manual corrections) — assign it only to roles that should be able to override this rule.

### `ZCL_IM_HCM_IT08_VALIDATION` — infotype 0008 (Basic Pay) rules

Fires when `new_innnn-infty = '0008'`. Enforces a **minimum housing allowance wage type
`1001`**, threshold depending on marital status from infotype 0002 (`PA0002-FAMST`):
750 SAR minimum if single (`FAMST = '0'`), 1167 SAR minimum if married (`FAMST = '1'`) —
message class `ZHCM_MSGS` numbers `008`/`009`. Checks all six basic pay wage type slots
(`LGA01..LGA06`/`BET01..BET06`).

## 8.5 Payroll/EOS (End of Service) enhancements — KSA-specific

### `ZHCM_CL_EOS_DURATION_CALC` — BAdI `HRPAYSA_EOS_SERVICE_DURATION`

Implementation `ZHCM_EOS_DURATION_CALC` of the standard Saudi-payroll BAdI spot
`HRPADSA_GENERIC_ENHANCEMENTS`, method
`IF_HRPAYSA_EOS_SER_DURATION~CALCULATE_SERVICE_DURATION`. Computes End-of-Service (indemnity)
service duration under the **Saudi Labor Law "30-day month" convention** rather than actual
calendar days:

```
service_duration = days + (months * 30) + (years * 360) - unpaid_days - invalid_days
                    + leap_days_between(hire_date, termination_date) - i_leap_days
```

using `HR_HK_DIFF_BT_2_DATES` (format `05`) for the year/month/day breakdown and
`LEAP_DAYS_BETWEEN_TWO_DATES` to add back leap days that the 30-day-month convention would
otherwise undercount.

### `ZHCM_ENH_DIFF_DAYS_THIRTY` — classic enhancement on `HSACALC0`

An implicit/explicit enhancement at `\PR:HSACALC0\FO:GET_DIF_DAYS\SE:END\EI` (standard payroll
schema day-difference calculation): if the period's `to_day` is the **last calendar day of its
month**, forces the calculated day count (`cv_anzhl`) to exactly `30`, reinforcing the same
30-day-month convention used by the EOS BAdI above, at the payroll schema level.

**Together, these two objects are the canonical KSA "30-day month" pattern** — if a new payroll
or leave-days calculation needs the same convention, follow this pair as the reference
implementation.
