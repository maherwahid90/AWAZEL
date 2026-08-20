# Leave Balance (ESS)

Read-only Employee Self-Service app showing the logged-on employee's leave/absence **quota
records** (from infotype **2006** — Absence Quotas) and, drilling into one quota, the list of
**leave documents that consumed it** (infotype **2001** postings referencing that quota via
`PTQUODED`).

Unlike Leave Request/Overtime, this is **not a managed RAP transactional object** — there is no
behavior definition (`.bdef`) at all. It is a plain **CDS-based read model**
(`provider contract` not set — default/basic query) exposed straight through a service
definition/binding, because there is nothing to create or edit.

* Fiori Launchpad semantic object: `zhcm_leave_balance`, action `display`
  (`zhcm_leave_bal.wapa.manifest.json`).

## Object stack

| Layer | Object | File(s) |
|---|---|---|
| Fiori app | `zhcm_leave_bal` (List Report / Object Page, read-only) | `zhcm_leave_bal.wapa.*` |
| Service binding | `ZHCM_LEAVE_BALANCE_SB` | `zhcm_leave_balance_sb*.srvb.xml` |
| Service definition | `ZHCM_LEAVE_BALANCE_SD` — "Service Definition for Leave Balance" | `zhcm_leave_balance_sd.srvd.xml` |
| Root CDS view | `zhcm_i_leave_balance` | `zhcm_i_leave_balance.ddls.asddls` |
| Child CDS view | `zhcm_i_leave_balance_it` (`_Leaves` association — the consuming documents) | `zhcm_i_leave_balance_it.ddls.asddls` |
| UI metadata ext. | `zhcm_i_leave_balance.ddlx` | `zhcm_i_leave_balance.ddlx.asddlxs` |

## `zhcm_i_leave_balance` — quota header

```
select from pa2006 as LR_B
  inner join pa0105 on LR_B.pernr = pa0105.pernr
  association [0..*] to zhcm_i_leave_balance_it as _Leaves on LR_B.quonr = _Leaves.Quonr
  association [1]    to zhcm_employee_help       as EMP     on EMP.pernr = LR_B.pernr
  association [1]    to zhcm_quotas              on zhcm_quotas.Ktart = LR_B.ktart
```

Key: `pernr`, `begda`, `endda`, `ktart` (quota type), `quonr` (quota record number, from
`PTQUODED`/`PA2006`). Exposed fields: quota type text (`Ktext`, via `zhcm_quotas`), employee
name, deduction period (`desta`/`deend`), entitlement (`anzhl`), consumed (`kverb`), and the
computed **`rest = anzhl - kverb`** (remaining balance).

**Row-level authorization is baked into the `WHERE` clause**, not `@AccessControl`: only
`PA0105` records valid today with `usrty = '0001'` (SAP username) and `usrid = $session.user`
are joined — i.e. **the CDS view itself only ever returns the logged-on user's own quotas**, the
same PA0105-based user↔employee resolution used across the whole suite (see doc 01).

## `zhcm_i_leave_balance_it` — consuming documents

```
select from ptquoded
  inner join pa2001 on pa2001.pernr = ptquoded.pernr
                    and pa2001.begda <= ptquoded.datum and pa2001.endda >= ptquoded.datum
  association [1] to zhcm_absence_types_cds as absences on absences.awart = pa2001.awart
```

Key: `Quonr`, `Docnr`, `Datum` (from `PTQUODED`, the quota-deduction detail table). Exposes the
absence type (`awart`) and its text for each document that deducted from the quota.

## UI (`zhcm_i_leave_balance.ddlx`)

Header identification facet + a `_Leaves` line-item facet ("Leave Dates") on the object page.
List report sorted by `begda` descending; title = quota type text (`Ktext`), description =
employee name (`ename`). Only 3 fields are filterable/`selectionField` (`begda`, `endda`,
`ktart`); `quonr`/`Ktext`/`ename` are `@UI.hidden` (used for text/association resolution only).

## Notes for building a similar read-only app

* No `.bdef`, no `zbp_*` behavior class, no draft — just CDS + `.ddlx` + service definition +
  service binding + a Fiori Elements list-report app pointed at the resulting OData entity set.
* Row-level "show only my own data" security is done via a `$session.user` filter in the CDS
  `WHERE` clause resolved through `PA0105`, exactly as in the transactional apps' projection
  views (`LocalCreatedBy = $session.user` there vs. a join here since there's no "created by"
  field on infotype-based data).
