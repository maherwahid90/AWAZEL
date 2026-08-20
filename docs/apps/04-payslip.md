# Payslip (Employee + Admin) & PDF Payslip Print Service

Two read-only Fiori apps that list an employee's payroll results per period and let the user
download the rendered PDF payslip, plus the classic SAP Gateway service and Adobe Form that
actually generates the PDF. This is the one area of the suite that mixes **RAP (for the list of
periods)** with a **classic SEGW OData service + Smart Forms/Adobe Forms** (for the PDF itself)
— there is no RAP "media entity" streaming here, the PDF link points to a separate, older-style
Gateway service.

## 4.1 Payslip (employee-facing) — `zhcm_payslip`

Shows the logged-on employee's own payroll periods.

| Layer | Object | File(s) |
|---|---|---|
| Fiori app | `zhcm_payslip` | `zhcm_payslip.wapa.*` |
| Service binding | `ZHCM_SBINDING_PAYROLL_DATA` (`_van` = value-help/annotation proxy) | `zhcm_sbinding_payroll_data*.srvb.xml` |
| Service definition | `ZHCM_SD_PAYROLL_DATA` | `zhcm_sd_payroll_data.srvd.xml` |
| Projection CDS | `ZHCM_C_PAYROLL_DATA` | `zhcm_c_payroll_data.ddls.asddls` |
| UI metadata ext. | `zhcm_c_payroll_data_me` | `zhcm_c_payroll_data_me.ddlx.asddlxs` |
| Interface CDS | `ZHCM_I_PAYROLL_DATA` | `zhcm_i_payroll_data.ddls.asddls` |
| Period value help | `zhcm_v_emp_payroll_period` | `zhcm_v_emp_payroll_period.ddls.asddls` |

`ZHCM_I_PAYROLL_DATA`:

```
select from pa0001 as emp
  inner join hrpy_rgdir on emp.pernr = hrpy_rgdir.pernr
  inner join pa0105     on emp.pernr = pa0105.pernr
  association [1] to I_CompanyCode              on ... = emp.bukrs
  association [1] to zhcm_v_emp_payroll_period   on hrpy_rgdir.fpper = period.fpper
```
Key: `pernr`, `fpper` (payroll period), `seqnr` (payroll result sequence number, from the
payroll results directory `HRPY_RGDIR`). Filters: `emp` valid today, `pay.payty = ''`
(regular/live payroll results only, no simulation runs), and — the row-security filter — only
`PA0105` records for the **logged-on user** (`usrid = $session.user`, `usrty = '0001'`), exactly
like Leave Balance.

Every row computes a ready-to-use PDF link as a CDS expression:

```
LinkToPdf = '/sap/opu/odata/sap/ZACIC_PAYSLIP_SRV/PAYSLIPSet(''' || seqnr || pernr || ''')/$value'
```

i.e. the RAP layer's only job is to **enumerate periods and build the URL** into the classic
Gateway media entity (§4.3); it does not stream the PDF itself. The `ShowPDF` UI facet renders
this as a clickable "Print Payslip" link (`@UI: { lineItem: [{...}, { type: #WITH_URL, url:
'LinkToPdf' }] }` in `zhcm_c_payroll_data_me.ddlx`).

## 4.2 Payslip Admin — `zhcm_payslip_ad`

Same shape, for an **HR admin/payroll admin viewing any employee's** payslips (no
`$session.user` restriction; employee is chosen via value help instead).

| Layer | Object | File(s) |
|---|---|---|
| Fiori app | `zhcm_payslip_ad` | `zhcm_payslip_ad.wapa.*` |
| Service binding | `ZHCM_SBIN_PAYROLL_DATA_ADM` | `zhcm_sbin_payroll_data_adm*.srvb.xml` |
| Service definition | `ZHCM_SD_PAYROLL_DATA_ADM` | `zhcm_sd_payroll_data_adm.srvd.xml` |
| Projection CDS | `ZHCM_C_PAYROLL_DATA_ADM` | `zhcm_c_payroll_data_adm.ddls.asddls` |
| Interface CDS | `ZHCM_I_PAYROLL_DATA_ADM` | `zhcm_i_payroll_data_adm.ddls.asddls` |
| Period value help | `zhcm_v_emp_payroll_period_adm` (no user filter) | `zhcm_v_emp_payroll_period_adm.ddls.asddls` |

`ZHCM_I_PAYROLL_DATA_ADM` differs from the employee variant only in its `FROM`:
`zhcm_employee_help` (the general employee value-help view, not `pa0001` restricted to the
logged-in user) joined to `hrpy_rgdir`, and **no `WHERE` clause** — any employee's periods are
selectable. Authorization for who may use this admin app is therefore expected to come from
standard HR structural/general authorization on the underlying tables, not from the CDS.

## 4.3 PDF rendering — classic SAP Gateway service `ZACIC_PAYSLIP_SRV`

This predates the RAP objects above and is a traditional **SEGW** project.

| Object | Purpose | File(s) |
|---|---|---|
| Gateway project | `ZACIC_PAYSLIP` | `zacic_payslip.iwpr.xml` |
| Model provider class | `ZCL_ZACIC_PAYSLIP_MPC` (+ `_EXT`) | `zcl_zacic_payslip_mpc*.clas.abap` |
| Data provider class | `ZCL_ZACIC_PAYSLIP_DPC` (+ `_EXT`) | `zcl_zacic_payslip_dpc*.clas.abap` |
| Payroll data extraction FM | `ZHCM_ACIC_PAYSLIP_DATA` | `zhcm_fg.fugr.zhcm_acic_payslip_data.abap` |
| Header structure | `ZHCM_ACIC_PAYSLIP_H` | `zhcm_acic_payslip_h.tabl.xml` |
| Line-item structure/table type | `ZHCM_ACIC_PAYSLIP_ITEM(_TT)` | `zhcm_acic_payslip_item*.xml` |
| Wage type detail table type | `ZBAPIP0008P_TT` | `zbapip0008p_tt.ttyp.xml` |
| Adobe Form (interface + layout) | `ZACIC_PAYSLIP` | `zacic_payslip.sfpi.xml`, `zacic_payslip.sfpf.xml/.xdp` |

**Media entity streaming** — `ZCL_ZACIC_PAYSLIP_DPC_EXT~/IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_STREAM`:

1. Reads the `docId` key from the URL (`PAYSLIPSet('<docId>')`) — the RAP layer built this as
   `seqnr (5 chars) || pernr (8 chars)` concatenated, so `docId+0(5) = SEQNR`,
   `docId+5(8) = PERNR`.
2. Calls FM `ZHCM_ACIC_PAYSLIP_DATA` to build the header/items/wage-type data (see below).
3. Opens an Adobe form job (`FP_JOB_OPEN`), resolves the generated function module for form
   `ZACIC_PAYSLIP` (`FP_FUNCTION_MODULE_NAME`), calls it with the header/items/wagetypes
   (language `E`, country `US` hardcoded), closes the job (`FP_JOB_CLOSE`), and returns the
   resulting PDF bytes as the stream (`mime_type = 'application/pdf'`,
   `Content-Disposition: outline; filename="<pernr>_payslip.pdf"`).

**`ZHCM_ACIC_PAYSLIP_DATA`** (the payroll-cluster read):

1. Resolves the payroll cluster area (`PYXX_GET_RELID_FROM_PERNR`) and reads the payroll result
   for `(PERNR, SEQNR)` via `PYXX_READ_PAYROLL_RESULT` into the international results table
   `RT` (`ST_PAYRESULT-INTER-RT`).
2. Splits wage types into **earnings** (`T512W` wage-type class `AKLAS` positions 3-4 = `'07'`)
   and **deductions** (`AKLAS` positions 3-4 = `'09'`), for country grouping `MOLGA = '24'`
   (Saudi Arabia), non-zero amounts only, and interleaves them row-by-row into `ITEMS`
   (`E_LGART`/`E_BETRG` vs `D_LGART`/`D_BETRG` columns side by side on the same output line) —
   this is why the structure has both an "earnings" and a "deductions" column pair per row
   rather than one flat list; it directly drives a two-column payslip layout.
3. `HEADER-gross_amt` / `HEADER-total_deduction` accumulate as the loop runs; `HEADER-net_amount`
   comes from wage type `/560` (standard net-pay technical wage type).
4. Header master data: `PA0001` (name, position, company), `T001` (company name), `HRP1000`
   (position `stext`), payroll period month/year from `HRPY_RGDIR-FPPER`.
5. Also fetches the **basic pay wage types** for the period via `BAPI_BASICPAY_GETDETAIL` off
   the `PA0008` record valid at period-end, returned separately in `WAGETYPES` (used for
   whatever the Adobe form layout does with fixed/basic pay elements, e.g. showing the
   allowance breakdown even when it didn't move through payroll results as a variable line).

Note: the field name is literally spelled `WAGETYPES` in the interface and the row structure has
an odd swapped-language quirk in the code (`IF sy-langu = 'E'. langu = 'A'. ELSEIF sy-langu =
'A'. langu = 'E'.` before falling back to the alternate language when a wage-type text isn't
found in the user's own logon language) — worth being aware of if this FM is reused/extended.

## Related validations elsewhere in the suite

`ZCL_IM_HCM_IT08_VALIDATION` (infotype 0008 exit, minimum housing allowance by marital status)
indirectly affects what ends up in a payslip's basic pay wage types — documented in
[08-shared-master-data-and-enhancements.md](08-shared-master-data-and-enhancements.md).
