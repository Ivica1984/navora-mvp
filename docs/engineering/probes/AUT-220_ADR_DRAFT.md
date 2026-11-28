# AUT-220 ADR draft (eng, 2026-11-26 10:20 CET): budget tests under forced join orders

Status: **PROPOSED** (draft for the PO contract; not an active package, no code on any branch). AUT-220 is `aia` review 95 (`docs/agents/reports/AUTOMATION_REVIEW.md`), ordered by the PO «first after the acceptance» of HD-3a / ORDER-F1. This draft only states HOW `eng` would build it and one technical trap found while reading the tests, so the brief can be written without a further round.

## Goal (from AUT-220, unchanged)

The call-count budgets of pgTAP 178, 179 and 180 also run under the forced plans that pgTAP 181 introduced, so a plan-dependent per-row evaluation turns red on the first `db` run instead of in one of ten `ci-repeat` runs. No budget, timeout or assertion is loosened.

## Proposed design

1. **Same four plan cases as 181** (`plan_default`, `plan_index_only`, `plan_seq_hash`, `plan_written_order`), set transaction-locally with `set_config(..., true)` and reset to the captured defaults after each case (the `pg_temp.pin()` pattern of 181, lines 175–192).
2. **Per file, the existing measurement runs once per plan case.** The test then asserts the **same** call-count bound under every case. For example, in 178: `member_step >= 1000 and visit_interval <= 20 * 1000`; in 180: the A → B helper counts unchanged per helper; in 179: clock reads `< 51`. Each case is one pgTAP assertion, so a red line names the plan.
3. **Wall-clock asserts stay under `plan_default` only.** One example is 178 «under 4 s». A forced plan can legitimately be slower, and asserting time there would make the test flaky without finding the defect class. Under the forced cases the wall time is printed with `diag()` only.
4. **Helper copied per file, not shared.** `supabase test db` runs `pg_prove` in a container; whether `\ir` resolves a shared helper path there is UNKNOWN. A test helper in a real schema would need a migration (test code in the product schema). So each file keeps its own `pg_temp.pin()`, and its header comment names 181 as the source.

## Technical trap (needs to be in the contract)

The measured functions are not all SQL-language:

| Function | Language | Plan behaviour (PostgreSQL 17, `supabase/config.toml` major_version 17) |
|---|---|---|
| `private.order_offer_reasons` (181) | sql | planned per calling statement, so forced settings take effect (what 181 relies on) |
| `public.team_order_offers` (180), `public.client_orders` (178) | sql | as above |
| `private.order_member_step` (178, 179) | plpgsql | statements without parameters keep a **cached plan for the session**; a later `enable_*` change does not replan |
| `private.recheck_member_takes` (179) | plpgsql | as above |

So for 178 and 179, a naive loop over plan cases would measure the first plan four times and could stay green while the defect hides. This is the exact failure AUT-220 is meant to prevent. Proposed counter-measures, both inside the test transaction:

- `discard plans` before each case (allowed inside a transaction block), together with `set_config('plan_cache_mode', 'force_custom_plan', true)`;
- **a proof that the pin reached the plpgsql body:** a `pg_temp` plpgsql probe returns `current_setting('enable_seqscan')` and so on per case. In addition, `EXPLAIN (format json)` of the inner statement is captured once per case. The test asserts that the four cases yield at least two different join shapes, so that «forced» is shown, not assumed.

Labelled UNKNOWN until the first run: whether the four forced cases actually produce different plans for the plpgsql inner statements at the seeded sizes. If they do not, the test says so (red), and the case set is adjusted. It is never silently dropped.

## Tests and way back

- First run on a tests-only head against `recovery/main` as it is. Expected result: green, because F1, F2, F3 and F5 are fixed. A green first run is acceptable here: AUT-220 is a guard, not a fix. Proof that the guard bites: one probe commit on an unmerged branch, not in the PR, that temporarily runs the frozen pre-F5 body (as 181 does with `pg_temp.reasons_old`). It must go red under at least one forced case.
- `db` run time: four cases × three files. Estimate (not measured): +30–60 s on the `db` job. To be measured on the first run and reported.
- Way back: tests only, no migration, no function change. Reverting the PR removes it completely.

## Open for the PO contract

- Order and size: after the `ABNAHMEAKTE.md` for HD-3a / ORDER-F1, as AUT-220 says. Estimate: 1–2 hourly runs.
- No gate expected: tests only, no visible behaviour.
