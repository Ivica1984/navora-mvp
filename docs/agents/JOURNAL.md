# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

## 2026-10-24 02:26 · Clinical & Regulatory Architect (review)
- **Reviewed** #234 (ABS1-C6), #239 (DAY-1: 0055, pgTAP 056, ADR-068), #237 (zod), the PO cycles in #238, the packages D-22, D-18, D-28 and the `lca` input in open PR #241. CI green on `d31709f`, `2e79532`, `35e28a4`. I did not run the tests.
- **No blocking finding.** ABS1-C6: no finding (CR-065). DAY-1: safety fix endorsed; by reading, no other day derivation exists in migrations or `src/` today; DAY-1-R1-R3 (PO) still needed (CR-064).
- **New (advisory):** CGR-36 (S2): the `inform_gp` task can never be completed, so NAVORA cannot record that the doctor was informed of A/C care without an order. CGR-37 (S2; S1 if visits are planned when nobody watches): every visit safety signal is pull-only, with no delivery to anyone. CGR-38 (S2): an order `present` without an end date never raises an expiry signal while B visits keep being planned. New register rows: H-18, PS-29, PS-30, BL-16. CGR-35: decided by the PO, PLANNED in AN2. CGR-31: evidence widened by `lca` (residence canton may be the wrong key).
- **Clinical impact for D-22, D-18, D-28** is written in the report section (my self-merged PR may touch only the report, registers and journal). **po:** copy it verbatim into the packages, signed as stated there. D-31, D-3, D-29 follow once #242 is merged.
- **Next agent (po):** decide CGR-36, CGR-37, CGR-38; copy the Clinical impact blocks; pilot visit hours and who watches `/team`/OPS1 then. **(eng):** AN2 first PR (CGR-35, ABS1-C7, DAY-1-R1-R3); Engineering impact in the packages. **(owner):** G-1 Clinical Owner; optionally allow `cra` to write package sections directly.

## 2026-10-24 01:15 · po (Product Owner)
- **#238 continued, not a second PO PR:** `recovery/main` (with #239) merged in at 33b2532 (JOURNAL conflict resolved, both entries kept, newest first); CI re-runs at 01:1x Zurich, inside the split-day window. Merge on green.
- **DAY-1 reviewed (#239, migration 0055, pgTAP 056, ADR-068; merged as 2e79532; CI green in app, db, e2e, run 40033219652 at 00:22 Zurich).** The PO read the diff and CI through the API; **the PO did not run the tests**. Evidence table in `briefs/AN2.md` 01:15. Safety fix met: OPS1 order-expiring and review-overdue, `pause_case`, `apply_case_facts`, `add_care_plan_item` use the Zurich day. Proof `changes-requested`, non-blocking: **DAY-1-R1** guard also refuses `now()::date`, `current_timestamp::date`, `localtimestamp`, dates in views; **R2** one behavioural pgTAP at a split-day clock; **R3** ADR-068 names the hosted DB time zone as an owner check with D-2. They ride in AN2's first PR with CGR-35 and ABS1-C7. Deviations accepted: inline expression instead of a helper (given R1), night run as proof (given R2), delivered outside AN2 (speed was right).
- **COORD5 unblocked** (was "after DAY-1").
- **Decision packages (owner process 2026-10-24), INDEX order:** D-22, D-18, D-28 written (`decisions/D-22.md`, `D-18.md`, `D-28.md`), status `inputs-requested`; one comment per issue (#104, #80, #150) names the roles. D-22 and D-18: `eng`, `cra`, `lca`. D-28: `eng`, `cra` (legal not needed unless `cra` names a professional-accountability question). All three Low confidence; no recommendation and no new rule; the strict defaults stay. D-18 likely cannot settle before D-11 and D-12 name the tariff contract.
- **Challenge:** why is a safety-signal threshold one central value for every team? From scratch the Clinical Owner sets a band and each team chooses inside it (D-28 option C). Row added; AN2 data first.
- Nothing escalated. **Waiting on people (unchanged):** owner names the clinical owner (G-1); `clinical`, `legal` and `owner` rows now go through packages.
- **Next agent (po):** merge #238 on green; packages D-31, D-3, D-29 (INDEX 4-6). **(eng):** AN2 first PR (DAY-1-R1-R3, CGR-35, ABS1-C7); COORD5; *Engineering impact* in D-22, D-18, D-28. **(cra):** *Clinical impact* in D-22, D-18, D-28; a look at 0055 (date logic of safety exceptions). **(lca):** D-22, D-18.

## 2026-10-24 00:40 · eng (Lead Engineer)
- **CI red between 00:00 and 02:00 Zurich (UTC vs Zurich "today").** The PO cycle PR #238 (docs only) failed db and e2e at 00:03: the seed, pgTAP and two e2e specs used `current_date` (UTC), seed visit 532 and the app use the Zurich date. Five product functions also used `current_date` (OPS1 order expiring and review overdue, `pause_case`, `apply_case_facts`, `add_care_plan_item`), so for one or two hours a night they judged dates against yesterday.
- **Fix PR (fix/zurich-today):** migration 0055 replaces `current_date` with the Zurich date in every `public`/`private` function body (no rule changes), pgTAP 056 guards it, seed/pgTAP/e2e use the Zurich date, pgTAP 044 reads reports on the visit's own date. ADR-068. IMPLEMENTED; CI is the test runner, no local run (container registries are blocked here).
- **CSR1 (#149):** nothing left to build; the hand-off closes when #238 merges. AN2 (#205) starts once it carries `active`.
- **For the PO:** #238 needs a fresh CI run after this merges (or outside 00:00–02:00 Zurich).

## 2026-10-24 00:15 · po (Product Owner, session with the owner)
- **Owner instruction (2026-10-24, live session): decision packages.** No `human-decision` issue is put to the owner as an open question any more. Agents analyse it, gather Engineering, Clinical & Regulatory and (where needed) Legal & Compliance input, and write a package with a recommended default, a confidence and whether owner approval is actually required. The PO decides when no escalation criterion applies; escalation only for unresolved legal interpretation, the Clinical Owner, commercial/strategic/business, regulatory liability, funding, pricing or partnership (and, carried over, irreversible production changes). Process: `DECISION_PACKAGES.md`; template and order: `decisions/_TEMPLATE.md`, `decisions/INDEX.md`.
- **New role `lca` (Legal & Compliance Agent)**, approved by the owner with additions: advisory only, never a final legal determination; reads the newest `cra` findings first when a decision touches safety, documentation, billing, care delivery or professional accountability; names missing canton, tariff-contract, payer-agreement or policy information; no repeat review unless the package changed, new evidence exists or a reviewer asks. Involved automatically for billing, reimbursement, tariffs, OKP/KVG/KLV, data protection, privacy, retention, contracts, governance, regulatory compliance. Scheduled task "NAVORA Legal & Compliance Agent" (`trig_011mvABASzho3mC4nYWHhyFk`, hourly at :39 UTC).
- **Priority (owner):** D-22 and D-18 first; then decisions referenced by open or provisional CGR findings (D-28, D-31, D-3, D-29, D-30, D-16); then decisions blocking billing, reimbursement, invoicing, compliance, governance or production release; then the rest. 29 decisions triaged in `decisions/INDEX.md`; **no package written yet**, all `not-started`. Preliminary routes are a first triage, not answers.
- **Scheduled tasks:** PO prompt updated for the package workflow (step F). The Engineering prompt update was refused by the platform's permission check, and the `cra` prompt was not changed; both agents read README and COORDINATION each run, which now carry their package duties (`eng`: *Engineering impact*; `cra`: *Clinical impact*). If they do not pick them up within two runs, the PO drafts those sections, marked unconfirmed.
- **COORD5 approved** (Next up 2): the watcher assigns a decision issue to a person only when its package awaits approval; buildable right after DAY-1. Until then the INDEX is authoritative and the watcher still assigns every decision issue to the owner.
- Tests: none run; `node scripts/agents-check.mjs` ok; watcher dry run: active AN2, COORD5 next.
- **Next agent (po):** packages D-22, D-18, D-28 (inputs requested). **(lca):** D-22, D-18 once requested. **(eng):** DAY-1, then COORD5; *Engineering impact* in requested packages. **(cra):** *Clinical impact* in requested packages.

## 2026-10-24 00:20 · po (Product Owner)
- **#238 (PO cycle 23:15) not merged:** after the base merge (09e4416, `zod` fix #237) its CI went red in `db` and `e2e` (run 40030758280, started 22:00 UTC = 00:00 Zurich). `app` is green, so the `zod` audit is fixed. The PR is docs only; `recovery/main` was green at 21:23 UTC on the same code. The failure follows the clock, not the change. No second PO PR opened: this entry rides on #238.
- **Cause, read in the repository (the PO did not run the tests):** pgTAP 008, 015, 043, 044, 049 mix `current_date` (UTC in CI) with the Zurich day and build visits at `now() ± hours` that fall on the previous Zurich day after midnight; live functions use `current_date` too (0013/0017 requested start, 0014 review date, 0019/0024 OPS1 order expiring and review overdue, 0024/0031 C1 pause end and visit window). UNKNOWN: hosted DB time zone; the e2e failure (report not read).
- **PO decision (product authority):** NAVORA's calendar day is the Europe/Zurich day everywhere. **DAY-1** ordered as AN2's first change, before CGR-35 and ABS1-C7; criteria (1)-(5) in `briefs/AN2.md` 00:20, including a CI proof at a split-day clock. Reason: CI red two hours every night stalls merges, and date-based safety exceptions run on the UTC day in that window (patient safety is a precondition).
- **Challenge:** why does any function decide "today" for itself? From scratch there would be one clock and one rule; DAY-1 makes it so and adds a CI check against new bare `current_date`.
- No review delivered since 23:15; no `po` decision open. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (po):** after 00:00 UTC re-run #238's failed jobs once; merge on green (merge commit). **(eng):** DAY-1 under #205, then CGR-35 and ABS1-C7, then the AN2 measures. **(cra):** #234 (ABS1-C6).

ENGINEERING BRIEF
- **Capability:** DAY-1, one calendar day (Europe/Zurich) for every server-side "today" and date bound; first change of AN2.
- **Why:** functions and tests mix the UTC and the Zurich day; CI is red every night between 22:00 and 24:00 UTC (23:00-24:00 in winter time), and OPS1's order-expiring and review-overdue exceptions use the UTC day in that window.
- **Business outcome:** merges do not stall at night; no red build mistaken for a flake.
- **Care outcome:** date-based safety exceptions fire from the first minute of the Zurich day.
- **Expected nurse outcome:** a pause ending "today" or a date entered after midnight is judged by the day she lives in.
- **Expected team outcome:** exceptions and "yesterday" in `/field` agree with the team's clock.
- **Expected patient outcome:** an expired order or overdue care-plan review is not missed for two hours each night.
- **Acceptance criteria:** `briefs/AN2.md` 00:20, DAY-1 (1)-(5).
- **Dependencies:** none open; base CI green (#237). Hosted DB time zone is an owner check once staging exists (D-2).
- **Priority:** first, before CGR-35 and ABS1-C7 (Next up 1, AN2).
- **Implementation recommendation:** one stable SQL helper for the Zurich day, used by functions and pgTAP fixtures; a test clock override for one CI pass at a split-day time; a pgTAP or script check over `pg_proc` source for bare `current_date`/`now()::date`; own small PR with an ADR.

## 2026-10-23 23:20 · eng (Engineering)
- **`recovery/main` is red** since 62609af: the app job's supply-chain audit (`npm audit --omit=dev --audit-level=high`) fails on a new advisory, **GHSA-mrhx-c7xc-m3w5** (zod < 4.6.6, high: memory exhaustion validating oversized constrained collections). Lint, typecheck, unit (24 files), build, db and e2e were green in the same run. Not caused by #234 or #236; every PR is red until it is fixed.
- **Fix PR** (`fix/zod-audit-ghsa-mrhx-c7xc-m3w5`): `zod` `^4.1.0` → `^4.6.6` in `package.json`; `package-lock.json` resolved by lockfile-sync (ADR-012/014; no registry access here). Same major; no code change. IMPLEMENTED (awaiting CI); nothing run locally.
- Active issue #149 (CSR1): no eng work open. Part 12 (ABS1-C6, #234) waits on the PO; CGR-35 waits on the PO. Not claimed.
- **Next agent (eng):** CI on the fix PR; merge when green, then other PRs need `recovery/main` merged in. **(po):** ABS1-C6, CGR-35, then AN2 (#205).

## 2026-10-23 23:15 · po (Product Owner)
- **ABS1-C6 reviewed: met** (#234 head 351345c, CI run 40020564005 green; merged as d31709f, CI run 40022316185 green on the merge commit, checked through the API). The PO read the full diff, the unit tests, the e2e case and ADR-067. Evidence table in `briefs/ABS1.md` 23:15. **The PO did not run the tests.**
- **Deviations decided:** lower bound "yesterday" is a form rule only (accepted; AN2 measure 8 counts earlier starts); no notice on a replay (accepted); seeded absence replaced by the e2e (accepted, one-worker rule of ADR-066); built from #231 before merge (accepted).
- **ADR-067 *Open* decided: ABS1-C7** — at n = 1 "1 vergangener Einsatz ist noch offen: bitte im Team entscheiden".
- **CGR-35 decided** (`cra` 22:30, advisory S3; product authority, not a clinical rule): a flagged past visit moved with `reschedule_visit` stores `responsible_absent = true` on its `moved` row, server-side, immutable; same fixed text in HAND1; no new reason code, no extra tap. D-28, D-31 stay `clinical`.
- **CSR1 complete** (parts 1-12) and removed from *Next up*: the watcher closes #149 and **AN2 (#205) becomes active** (dry run checked: `active capability: AN2`). CGR-35 and ABS1-C7 are AN2's first change; AN2 measure 8 extended (moved flagged visits; absence starts earlier than yesterday). ABS1 stays accepted.
- **Base CI red** since 62609af: app job, `npm audit` reports `zod` < 4.6.6 (GHSA-mrhx-c7xc-m3w5, high). Not caused by a change; every PR's app job is red until engineering bumps `zod`. This PR (docs only) is merged only on green CI; if it is red from the audit alone it stays open for the next PO run.
- **Challenge:** advisory conditions on an accepted item travelled as four sequential CSR1 parts and held AN2 back for eight hours. Verdict no: advisory (S3) conditions now ride with the next capability that touches the same data; blocking findings still go first. Row added with a check.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** bump `zod` (≥ 4.6.6) so CI is green; then AN2 under #205, starting with CGR-35 and ABS1-C7. **(cra):** #234 (ABS1-C6); CGR-35 when its PR is open.

ENGINEERING BRIEF
- **Capability:** AN2 first change: CGR-35 (a moved flagged past visit keeps the absence fact) and ABS1-C7 (singular confirmation text).
- **Why:** a "Folgeeinsatz" is the team's most likely answer to a visit missed during a reported absence; today the move erases why the care on the original date was not given once the absence is changed.
- **Business outcome:** documentation that survives later corrections without anyone typing a reason; AN2 measure 8 counts missed care completely.
- **Care outcome:** continuity gaps stay visible for the team, HAND1 and `clinical` (D-28, D-31 answerable from data).
- **Expected nurse outcome:** no extra tap or text; correct German at n = 1.
- **Expected team outcome:** the team decides make-up visits itself and the record shows why, with no coordinator relaying it.
- **Expected patient outcome:** missed care is not hidden behind a planning move.
- **Acceptance criteria:** `briefs/ABS1.md` 23:15, CGR-35 (1)-(5) and ABS1-C7 (pgTAP case set incl. withdrawal, unit tests for the HAND1 line and n = 1 / n = 2).
- **Dependencies:** base CI green (`zod`); 0053, 0054 (merged). No open decision blocks it.
- **Priority:** first change of the active capability AN2 (Next up 1).
- **Implementation recommendation:** same shape as 0054: column on `visit_plan_changes` with a check `not responsible_absent or change = 'moved'`, computed in `reschedule_visit` before the move from `private.visit_responsible_absent`; patch the function as 0052 does; own small PR or inside AN2's first PR.

## 2026-10-23 22:50 · eng (Engineering)
- **#234 merged** (merge commit d31709f), CI green on its head 351345c (run 40020564005: app, db incl. pgTAP, e2e). ABS1-C6 IMPLEMENTED. ABS1 `delivered`.
- Two base merges were needed before merging (PO #231/#233, `cra` #235; journal conflicts only, both entries kept). The first CI run on 223362b was green too.
- `cra` 22:30 opened **CGR-35** (advisory: a flagged past visit moved with `reschedule_visit` stores nothing about the absence). PO decides; not built.
- `claimed` removed from #149. **Next agent (po):** ABS1-C6 against `briefs/ABS1.md` 21:17 (and the singular-wording question in ADR-067 *Open*); CGR-35; then AN2 (#205). **(eng):** the PO's next order.

## 2026-10-23 22:30 · Clinical & Regulatory Architect (review)
- **Reviewed** #228 (0053, pgTAP 054, CGR-32) and #230 (0054, pgTAP 055, CGR-34), the 046 fixture fix, the seed fixture, and the PO cycles #227, #231, #233. CI green on `87612aa` and `673ba50` (db job in the evening: the 046 fix holds). I did not run the tests.
- **Closed:** CGR-32 (0053; pgTAP 054, incl. my 19:46 hand-closed case at 054:79-80, 96-97), CGR-34 (0054; pgTAP 055:55-128). PS-26, PS-27 closed. Rules CR-062, CR-063 added (PROVISIONAL, product authority).
- **New (advisory S3):** CGR-35 (PS-28): a flagged past visit moved with `reschedule_visit` loses the absence fact (stored only on cancellation). PO decides; could ride with ABS1-C6 in CSR1 part 12.
- This PR also carries the unmerged 19:57 addendum (#226, CGR-34), which is closed as superseded.
- **Next agent (po):** CGR-35; AN2 measure 8 should count moved flagged visits. **(eng):** CSR1 part 12 (ABS1-C6, and CGR-35 if ordered). **(owner):** G-1 clinical owner.

## 2026-10-23 22:28 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 22:11** for the **CSR1 part 12 remainder = ABS1-C6** (PO decision 21:17 in PR #231, **not merged** at build time; built from its text). CGR-34, the other half of part 12, was delivered in #230.
- **PR #234** (`feat/csr1-part12-abs1-c6`): no migration; ADR-067; unit tests and e2e at phone width. ABS1 row `in-review`.
- IMPLEMENTED (awaiting CI): `/field` offers an absence start of yesterday (no earlier); `recordAbsence` returns `pastPlanned`; at n > 0 the section shows "<n> vergangene Einsätze sind noch offen: bitte im Team entscheiden" with a link to `/team`.
- **Seed:** the ended absence of assist.test (from #228) is removed; the new e2e records it through the app before the CGR-32 and CGR-34 tests. pgTAP comments updated; no pgTAP assertion depended on it (checked by reading, not run).
- **Clinical gate:** no report finding names ABS1-C6 (sections 19:46, addendum 19:57); no remediation plan. D-28, D-31 untouched.
- OPEN for `po`: the literal text reads "1 vergangene Einsätze" at n = 1; a singular form only on the PO's word.
- **Tests:** nothing run locally (no npm registry access, no local Supabase in this container); a pure-function spot check of the three helpers with node only. CI is the runner; nothing claimed as passed.
- **Next agent (eng):** CI on #234; approve a waiting types-bot run; fix if red; merge; ABS1 `delivered`. **(po):** merge #231 after a base merge; check ABS1-C6 against `briefs/ABS1.md` 21:17; then AN2 (#205).

## 2026-10-23 22:15 · po (Product Owner)
- **#231 (PO cycle 21:17) merged** (merge commit 993b5df) after merging `recovery/main` into it (journal: kept both entries, newest first); CI green on its head 05408d4.
- **CGR-34 reviewed: met** (#230 head 87612aa, CI run 40011124704 green; merged as 673ba50, CI green on the merge commit and on 0717c05, checked through the API). The PO read 0054 in full, pgTAP 055 (26), the unit tests and the e2e case. Evidence table in `briefs/ABS1.md` 22:15. **The PO did not run the tests.**
- **Deviations decided:** HAND1 shows the fact as its own line under "Einsatz abgesagt" (accepted); "Abgesagt (<reason>)" everywhere on `/field` (accepted); e2e order dependence on the CGR-32 case (accepted while the suite runs on one worker); built from #227 before merge (accepted, decision unchanged).
- **ABS1 stays accepted.** Open: ABS1-C6 only. **CSR1 part 12 = ABS1-C6** (criteria `briefs/ABS1.md` 21:17), then AN2 (#205).
- **Challenge:** a flagged past visit still needs a reason picked from a list although NAVORA knows why it was not done. Row added: if AN2 measure 8 shows > 80 % `team_cancelled` on flagged past visits, propose one action "Nicht durchgeführt (abwesend)" on the overdue alert; the make-up decision stays with the team and D-28.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 and others in `OPEN_DECISIONS.md`.
- **Next agent (eng):** CSR1 part 12 = ABS1-C6 under issue #149; then AN2. **(cra):** 0053 (#228) and 0054 (#230); #226 needs `recovery/main` merged in (red only from the old 046).

## 2026-10-23 21:30 · eng (Engineering)
- **#230 merged** (merge commit 673ba50), CI green on its head 87612aa (run 40011124704: app, db incl. pgTAP `055_csr1_cgr34_cancel_keeps_absence` (26), e2e). CGR-34 IMPLEMENTED. ABS1 `delivered`.
- First CI round red in db only (run 40010479455): pgTAP 047 test 5 asserted the exact column list of `field_visit_status_notes`; updated for the new `responsible_absent` column (87612aa). 055 was green in both rounds.
- Correction: the entry below is stamped 21:35, ahead of the clock (written about 21:20).
- `claimed` removed from #149. **Next agent (po):** CGR-34 against `briefs/ABS1.md` 20:15; then AN2 (#205). **(cra):** 0054. **(eng):** the PO's next order, or AN2.

## 2026-10-23 21:35 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 21:12** for the **CSR1 part 11 remainder = CGR-34** (PO decision 20:15 in PR #227 and `cra` addendum 19:57 in PR #226, both **not merged** at build time; built from their text). CGR-32 and the pgTAP 046 time-of-day fix were already in #228.
- **PR #230** (`fix/csr1-part11-cgr34`): migration 0054, ADR-066, pgTAP `055_csr1_cgr34_cancel_keeps_absence` (26), unit tests (labels), e2e at phone width. ABS1 row `in-review`.
- IMPLEMENTED (awaiting CI): `visit_status_notes.responsible_absent` (only on `cancelled`, append-only, not writable by the caller); `cancel_visit` sets it when the visit is planned, dated before today and its responsible member is absent at its interval; survives a later withdrawal. Shown as "nicht durchgeführt: zuständige Person abwesend gemeldet" on the /field card ("Abgesagt (<reason>) · …"), in HAND1, and as OPS1 flag `not_done_responsible_absent` on the late team cancellation. No new reason code.
- **Clinical gate:** latest merged report section 19:46 has no CGR-34; applied per the 19:57 addendum (#226) and the PO decision. No remediation plan (advisory, no clinical rule). D-28, D-31 untouched.
- **Tests:** nothing run locally (no npm registry, no local Supabase in this container). CI is the runner; nothing claimed as passed.
- **Next agent (eng):** CI on #230; approve a waiting types-bot run; fix if red; merge; ABS1 `delivered`. **(po):** merge #227 (and #226) after a base merge; check CGR-34 against `briefs/ABS1.md` 20:15. **(cra):** 0054.

## 2026-10-23 21:17 · po (Product Owner)
- **#227 (PO cycle 20:15) merged** (merge commit 7257feb) after merging `recovery/main` into it (journal kept both entries); CI green on its head d37a706. It was red only from pgTAP 046 (fixed in #228).
- **CSR1 part 11 reviewed** (#228 head c1b562a, CI run 40005346459 green; merged as 33112e3, CI green on the merge commit and on e6f35ad, checked through the API). The PO read 0053 in full, the pgTAP 054 fixtures and assertions, the label, its unit test and the e2e case. **The PO did not run the tests.** Evidence table in `briefs/ABS1.md` 21:17.
- **CGR-32 met in code**, and the `cra` 19:46 case (a hand-closed overdue alert still counted in `past_planned`). Three deviations accepted (generic flag rule; seed and fixture changes; auth.spec by time). Awaiting a `cra` section on 0053. **ABS1 stays accepted.**
- **CGR-34 is not in #228** (built before the 20:15 decision merged; not a defect).
- **Engineering's OPEN decided (product authority): new condition ABS1-C6.** `/field` sets `min={today}`, so "krank seit gestern" never reaches CGR-32 from the app. `/field` offers a start of yesterday (no earlier). When `past_planned` > 0, the confirmation shows "<n> vergangene Einsätze sind noch offen: bitte im Team entscheiden" with a link to `/team`. e2e at phone width and a unit test.
- **Order:** CSR1 part 12 = CGR-34 + ABS1-C6 (small) → AN2 (#205).
- **Challenge:** a sick member must guess her return date, and a longer illness needs a second report. Row added: if more than 30 % of absences are changed after they are recorded, propose an open-ended absence ending with "Ich bin wieder da". AN2 measure 8 extended to measure it; no change before the data.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** CSR1 part 12 under issue #149 (criteria in `briefs/ABS1.md` 20:15 and 21:17); then AN2. **(cra):** 0053 (#228); #226 needs `recovery/main` merged in (red only from the old 046).

## 2026-10-23 20:48 · eng (Engineering)
- **#228 merged** (merge commit 33112e3), CI green on its head c1b562a (run 40005346459: app, db incl. pgTAP `054_csr1_cgr32_past_visit_absence_flag` (34), e2e). CGR-32 IMPLEMENTED. ABS1 `delivered`.
- First CI round red in e2e only (run 40003570491): auth.spec started "the first planned visit" on /visits, which became the new seed visit 532 (yesterday, sorts first), so 501 stayed open and 532 lost its alert. Fixed by selecting 501 by its time (c1b562a). The db job was green, including the 046 evening fix (docs-only PRs #226 and the PO cycle at 20:02/20:12 were red on 046 for that reason; they turn green once they merge `recovery/main`).
- `claimed` removed from #149. **Next agent (po):** CGR-32 (ABS1 condition) against the brief; then AN2 (#205). **(cra):** 0053. **(eng):** the PO's next order, or AN2.

## 2026-10-23 20:27 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 20:13** for **CSR1 part 11 = CGR-32** (ABS1 acceptance condition, PO 19:12). **PR #228** (`fix/csr1-part11-cgr32`): migration 0053, ADR-065, pgTAP `054_csr1_cgr32_past_visit_absence_flag` (34, incl. the `cra` 19:46 hand-closed-alert case), unit test (label), e2e at phone width. ABS1 row `in-review`.
- IMPLEMENTED (awaiting CI): `record_absence` returns `past_planned` (caller's teams only); past planned visits inside a new absence keep her and are not released; `team_visit_alerts()` and `operations_exceptions()` gain `flags text[]` (`responsible_absent`, computed from the absence, cleared by withdraw/shorten); fixed label "Zuständige Person abwesend gemeldet" on /team and in OPS1.
- **Found while testing locally:** pgTAP 046 fixtures rolled to tomorrow after 20:00/21:00 Zurich (CI red in the evening, not caused by a code change). Fixed in #228 (fixtures stay on today's date). Seed gains an ended absence + visit 532 for the e2e; pgTAP 004/046/048/050 adjusted.
- Engineering rebuilt a local PostgreSQL 16 with a Supabase/pgTAP shim and ran all 53 pgTAP files: pass. No npm registry access: lint, typecheck, unit, build and e2e only in CI.
- OPEN for the PO: the `/field` absence form allows a start from today only, so a past start ("krank seit gestern") is recordable only via the command.
- **Next agent (eng):** #228: approve a waiting types-bot run if any, fix CI if red, merge when green, set ABS1 `delivered`. **(po):** CGR-32 against `briefs/ABS1.md` once merged. **(cra):** 0053.

## 2026-10-23 20:15 · po (Product Owner)
- **Nothing new delivered** since 19:30 (no open engineering PR; CSR1 part 11 not started). No `agent:po` issue open.
- **CGR-34 decided** (`cra` addendum 19:57, PR #226, advisory S3, PS-27; product authority, not a clinical rule): when `cancel_visit` closes a past visit flagged by CGR-32, the server stores on its status note that the responsible member was absent (`responsible_absent`, immutable, never set by the caller); shown as "nicht durchgeführt: zuständige Person abwesend gemeldet". **No new reason code, no extra tap**: NAVORA records what it already knows. Whether missed care must be made up stays `clinical` (D-28, D-31). Criteria in `briefs/ABS1.md` 20:15. The PO read `cancel_visit` (0024); **the PO did not run any test.**
- **CSR1 part 11** = CGR-32 + CGR-34 + the `cra` 19:46 case (a hand-closed overdue alert still counts in `past_planned`); then AN2. AN2 measure 8 now also counts flagged past visits and how they ended.
- **CI:** pgTAP 046 test 74 is time-dependent (`cra` 19:57) and turns every db job red between 20:00 and 24:00 Europe/Zurich; engineering fixes it first. This PR (docs only) is merged only on green CI; if it is red from that test alone, it stays open for the next PO run.
- **Challenge:** new row: staff pick a reason code or type a note for a fact NAVORA already holds. Verdict no; hypothesis on `cancel_visit` "other" notes, tested with AN2 measure 10 data before any new reason code.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** pgTAP 046:66 fix; CSR1 part 11 under issue #149; then AN2 (#205). **(cra):** part 11 when its PR is open.

## 2026-10-23 19:57 · Clinical & Regulatory Architect (review)
- **Second review run** on the same changes as the 19:46 entry (#222, PO cycle #221); it agrees with the 19:46 section (CGR-33 closed, CGR-32 decision endorsed). Its own PR #225 duplicated #224 and is closed; this addendum carries only what is new. Tests not run by me.
- **New (advisory S3):** CGR-34 (PS-27): a flagged past visit (CGR-32) can be closed only through `cancel_visit` with a planned-cancellation reason, and the flag is computed, so the record loses that care was missed because the responsible member was absent. Remedy rides with CSR1 part 11; PO decides.
- **CI note (eng):** pgTAP 046 test 74 fails when run 20:00-24:00 Europe/Zurich (visit `later` at `now() + 4 h` crosses midnight; 046:66, 267). Code correct, test time-dependent; it made this docs-only PR's db job red at 20:00.
- **Next agent (po):** CGR-34 into CSR1 part 11. **(eng):** part 11 with CGR-32, the 19:46 pgTAP case and, if the PO agrees, CGR-34; fix pgTAP 046:66 to a fixed time inside today.

## 2026-10-23 19:46 · Clinical & Regulatory Architect (review)
- **Reviewed** #222 (pgTAP `053_cgr33_order_audit_guard`, test only; CI green on 4661392, d67055b, 50ee5f5) and the PO cycle #221 (ABS1 accepted with CGR-32; CGR-32 remedy decided; AN2 measure 12; challenge row on late billing facts). I did not run the tests.
- **Closed:** CGR-33 (053:23-92); BL-15 closed (residuals: `residence_canton` not asserted, needed only with a D-18 as-of residence rule; `session_replication_role = replica` UNKNOWN, eng runbook).
- **No new finding.** CGR-32 stays open until CSR1 part 11 merges; the PO's "flag, not release" decision is endorsed; one extra pgTAP case asked (a hand-closed overdue alert still counted in `past_planned`).
- **Gate:** no blocking finding on J5, ABS1 or any item. No decision answered.
- **Waiting:** owner G-1 (clinical owner); `legal` D-22, D-18; `clinical` D-28, D-31, D-10, D-30, D-16, D-17; `owner` D-3 before cover.
- **Next (cra):** CSR1 part 11 PR when open.

## 2026-10-23 19:30 · po (Product Owner)
- **CSR1 part 10 reviewed** (#216 head 9ea3cb3, CI run 39988490243 green; merged as 3d48a00, CI green on the merge commit (runs 39989101189, 39989106823) and on 279d026, checked through the API). The PO read 0052 in full, 0051's cut-off and reconstruction, and the pgTAP 051 and 052 assertions. **The PO did not run the tests.** Evidence in `briefs/CSR1.md` and `briefs/ABS1.md`.
- **ABS1 accepted** (issue #219): ABS1-C5 met; clinical gate passed (`cra` 18:30 on 0048/0050, 19:00 on 0052: no blocking finding). Deviation (check on the outcome, not on the date) accepted. **Condition CGR-32, PO decision (product authority, not a clinical rule):** a planned, not started visit dated before today inside a newly recorded absence is **flagged, not released**: it keeps its responsible member, `record_absence` returns `past_planned`, its overdue alert shows "Zuständige Person abwesend gemeldet"; the absence is never refused. Released, it would invite a take of a visit nobody can still do and could not be closed by hand (CGR-22). Whether the care must be made up stays `clinical` (D-28, D-31).
- **J5** stays accepted: J5-C2 met (`cra` 19:00), J5-C1 and CGR-29 closed (`cra` 18:30). All five deviations decided in `briefs/CSR1.md` (no "history missing" reason accepted on condition CGR-33). Conditions: **CGR-33** (pgTAP guarding the order audit history; before go-live) and **CGR-31** (residence correction; before any invoicing brief, D-18).
- **CGR-33 met** (#222 merged as d67055b, CI green on its head 4661392 and the merge commit; pgTAP `053_cgr33_order_audit_guard` read by the PO): trigger shape and both order columns, `{old, new}` read back by `case_order_as_of`, append-only for the owner, `authenticated` select only. Deviation (owner path only, no separate intake edit) accepted: the trigger has no column list and fires on every write path, which 053 asserts. `cra` review of 053 pending; J5 stays accepted. (The engineering entry below is stamped 19:50, ahead of the clock.)
- **Order:** CSR1 part 11 (now CGR-32 only; small) → AN2. AN2 gains measure 12 (late billing facts, `basis_changed` per 100 facts).
- **Challenge:** billing facts built in a later batch force each rule to reconstruct the visit date from the audit log; built from scratch, the basis would be snapshotted at visit end (row added; measured by AN2 measure 12 before any ADR).
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** CSR1 part 11 under issue #149 (CGR-32 per `briefs/ABS1.md` 19:12); then AN2 (#205). **(cra):** 053 (CGR-33); part 11 when its PR is open.

## 2026-10-23 19:50 · eng (Engineering)
- **#222 merged** (merge commit d67055b), CI green on its head 4661392 (run 39993536097: app, db incl. pgTAP `053_cgr33_order_audit_guard` (21), e2e). CGR-33 IMPLEMENTED (regression guard, test only). J5 `delivered`.
- `claimed` removed from #149. **Next agent (po):** J5 (J5-C2, CGR-33) and ABS1 (ABS1-C5; CGR-32 decision) against the briefs. **(cra):** 053. **(eng):** the PO's next order under #149, or AN2.

## 2026-10-23 19:25 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 19:13** for **CGR-33** (`cra` 19:00, advisory S2, BL-15, owner eng). CSR1 part 10 was already delivered in #216; the PO's review of it is pending.
- PR **#222** (`fix/cgr33-order-audit-guard`): pgTAP `053_cgr33_order_audit_guard` (21), ADR-064. Test only, no migration. IMPLEMENTED (CI pending): `audit_cases` must stay after insert or update, for each row, without a column list, enabled, with both order columns; order edits audited as `{old, new}` and read back by `case_order_as_of`; `audit_events` append-only for the owner; `authenticated` select only, `anon` nothing.
- J5 status row `in-review` (#222). Not touched: CGR-32 (PO decides how past visits in a newly recorded absence are shown), CGR-31 (D-18, `legal`).
- **Tests:** CI is the runner; nothing run locally against a database. Nothing claimed as passed.
- **Next agent (eng):** CI on #222; merge, J5 `delivered`; then whatever the PO orders next under #149, or AN2. **(po):** J5-C2, ABS1-C5, and CGR-33 as a J5 condition.

## 2026-10-23 19:00 · Clinical & Regulatory Architect (review)
- **Reviewed** #216 as merged (`3d48a00`): 0051 (J5-C2) and 0052 (ABS1-C5), pgTAP 051 and 052, the UI text and label. CI green on `9ea3cb3`, `3d48a00`, `279d026` (API). Tests not run by me.
- **Met in code:** J5-C2 (0051:49-87, pgTAP 051:103-231; cut-off PROVISIONAL, D-22) and ABS1-C5 (0052:36-55, pgTAP 052 (a)-(c)).
- **New (advisory):** CGR-32 (S3, PS-26): `record_absence` accepts a start in the past, and the release rule skips past dates, so past planned visits inside a newly recorded absence still name her (the end state ABS1-C5 refuses for a move); never fix it by refusing the absence. CGR-33 (S2, BL-15): no test guards that `audit_cases` audits both order columns, on which J5-C2 depends.
- **Gate:** ABS1 and J5 have no blocking finding; the PO may accept with CGR-32, CGR-33 (and CGR-31) as conditions. Cover stays off. Rule register: CR-058, CR-061 checked.
- **Waiting on people:** owner G-1 (clinical owner); `legal` D-22, D-18; `clinical` D-28, D-31, D-10, D-30, D-16, D-17; `owner` D-3.
- **Next agent (po):** accept ABS1 and J5 if agreed; record CGR-32 and CGR-33 as conditions; decide how CGR-32's past visits are shown. **(eng):** CGR-33 is a small pgTAP addition.

## 2026-10-23 18:43 · eng (Engineering)
- **#216 merged** (merge commit 3d48a00), CI green on its head 9ea3cb3 (run 39988490243: app, db incl. pgTAP `051_csr1_order_as_of_visit_date` (35) and `052_abs1_c5_no_past_move_into_absence` (12), e2e); earlier heads 86ff266 and ca215fa green too. Two base merges on the way (PO 18:15, `cra` 18:30): journal kept both entries; rule register kept the Architect's rows and added CR-058 and CR-061. Nothing is claimed beyond CI.
- **J5 `delivered`** (CSR1 part 10: J5-C2 IMPLEMENTED) and **ABS1 `delivered`** (ABS1-C5 IMPLEMENTED). No `cra` section reviews 0052 yet (UNKNOWN); the 18:30 section read 0051 from the diff with no blocking finding.
- **Next agent (po):** J5-C2 and ABS1-C5 against the briefs; CGR-31 as a J5 condition (`cra` 18:30). **(cra):** 0051 as merged, 0052. **(eng):** AN2 when it becomes active.

## 2026-10-23 18:30 · Clinical & Regulatory Architect (review)
- **Reviewed** 0048 (#206), 0049 (#210), 0050 (#212) as merged, and open PR #216 (0051, J5-C2) from its diff. CI green on `2401a11`, `378f811`, `1f64128`, `be22e2c` (API); #216: no CI run reported (UNKNOWN). **I did not run the tests.**
- **Closed:** CGR-27 (blocking S1; 0048:29-54, pgTAP 048:65-126), CGR-29 (0049:383-388, pgTAP 049:243-271), the CGR-24 withdraw residual (0049:206-262, pgTAP 049:101-237). ABS1-C3, ABS1-C4, ABS1-N1, J5-C1 endorsed. PS-23 and BL-13 closed; H-17 mitigated-in-code (cover off).
- **New:** CGR-31 (advisory S3, S1 before invoicing; BL-14): a residence correction never re-derives a fact, while the preview prices with the live canton. Time rule for the residence: PO with `legal` (D-18), UNKNOWN.
- **Gate:** ABS1 and CSR1 part 9 have no blocking clinical finding; ABS1 still waits on the PO's ABS1-C5, which #216 does not carry. #216: no blocking finding; merge only with green CI. Cover stays off (CGR-28, `accept_cover` absence check, D-3).
- Rule register: CR-059 (ABS1-C3, interval), CR-060 (ABS1-C4) added; CR-058 left to #216. This PR carries the 14:30 and 15:00 sections (#203, conflicted) and supersedes #203.
- **Waiting on people:** owner G-1 (clinical owner); `legal` D-22 (order before the visit? #216), D-18 (incl. CGR-31); `clinical` D-28, D-31, D-10, D-30, D-16, D-17; `owner` D-3.
- **Next agent (po):** accept ABS1 after ABS1-C5 and CSR1 part 9 if agreed; CGR-31 as a J5 condition; where ABS1-C5 is built. **(eng):** CI on #216; ABS1-C5.

## 2026-10-23 18:22 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 18:11** for **CSR1 part 10 (J5-C2)** per the PO's 16:55 order (ABS1 part 3 delivered in #212). PR **#216** (`fix/csr1-part10`): migration 0051, pgTAP `051_csr1_order_as_of_visit_date` (35), ADR-062, rule register CR-058 (PROVISIONAL, D-22), label `order_recorded_after_visit` with its unit test.
- **IMPLEMENTED (CI pending):** a fact's order basis is the case's order as recorded at the end of the visit date (first instant of the next day, Europe/Zurich), reconstructed backwards from the live row through `audit_events`; one path for the first build, a correction version and CGR-29's build. CGR-07 rules unchanged; `order_recorded_after_visit` names a visit whose order is valid only now. Facts record `order_as_of` and `order_recorded`. Pre-0051 facts are re-derived (`basis_changed`) by the next generation or the last lift.
- **Deviations / OPEN for the PO:** no "history missing" reason (the history is complete); an A/C-only visit with the order recorded later reads as `without_order_ac`; no catch-up in the migration (no user to attribute it to, as J5-C1); cut-off compares with the audit row's transaction start. Found while testing, not changed: CGR-29's build at a lift does not run when the visit had **no** fact before the hold (the trigger returns early); the next generation builds it (UNKNOWN whether the PO wants it at the lift).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim: 051 35/35 and every behavioural file the shim runs green (022, 043, 049 included); the files that do not run under the shim fail identically without 0051. vitest, typecheck, lint, e2e not run. `database.types.ts` edited by hand (two columns).
- **ABS1-C5 added to #216** after the PO's 18:15 cycle merged into the branch (journal conflict kept both entries): migration 0052, pgTAP `052_abs1_c5_no_past_move_into_absence` (12), ADR-063, move-specific refusal text on `/team`. IMPLEMENTED (CI pending): `reschedule_visit` refuses with `responsible_absent` and writes nothing when the visit would stay with a member absent at its interval (a move to yesterday inside her absence); a move into her absence ahead still releases. Locally (same shim): 052 12/12, 050 31/31, 046, 048, 051 green.
- Status rows J5 and ABS1 set `in-review` (#216). The `claimed` label on #149 was removed at the end of the first part of this run.
- **Next agent (eng):** CI on #216; fix, merge, set J5 and ABS1 `delivered`; then AN2. **(po):** J5-C2 and ABS1-C5 against the briefs; the CGR-29 no-prior-fact note. **(cra):** 0051, 0052.

## 2026-10-23 18:15 · po (Product Owner)
- **ABS1 part 3 reviewed** (#212 head 93a66f8, CI run 39978598901 green; merged as 1f64128, CI green on the merge commit (runs 39979449276, 39979442607) and on cfb4808 (runs 39981426191, 39981419043), checked through the API). The PO read 0050 in full and the pgTAP 050 assertions, and searched every migration for commands that set a responsible member or insert visits. **The PO did not run the tests.** Evidence in `briefs/ABS1.md`.
- **Met in code:** ABS1-C4 (a)-(e) (`plan_visit` refuses `responsible_absent`; a move into her absence releases the visit with "Abwesenheit"; absent via team A also blocks team B) and ABS1-N1. Every hand path to a responsible member is now absence-checked except `accept_cover` (COVER1 condition before D-3).
- **Engineering's question decided (product authority, strict default, not a clinical rule):** a move to a date before today inside her absence is **refused** with `responsible_absent` (**ABS1-C5**), because the release rule acts from today on and the visit would otherwise name an absent member. Unlinked release in a team without an absence row: accepted (open and visible, the safe direction).
- **Clinical gate:** no `cra` section covers 0048 or 0050: **awaiting clinical review**. ABS1 stays `changes-requested` for ABS1-C5 only.
- **Challenge:** every move of a planned visit needs a typed reason, also the nurse's own small moves (row added; measured after AN2 from events, never by reading the texts).
- No `po` decision open. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-28, D-30, D-31; `legal`: D-18, D-22; `owner`: D-3 before cover.
- **Next agent (eng):** CSR1 part 10 (J5-C2) with ABS1-C5 riding along, under issue #149 (WATCH-1); then AN2. **(cra):** review 0048, 0049, 0050; merge #203.

## 2026-10-23 17:40 · eng (Engineering)
- **#212 merged** (merge commit 1f64128), CI green on its head 93a66f8 (run 39978598901: app, db incl. pgTAP `050_abs1_part3` (31) and the adjusted `048_abs1_part2`, e2e). The run on 72027bf was cancelled by the second push. Nothing is claimed beyond CI.
- **ABS1 `delivered`** (parts 1-3: #195, #206, #212): ABS1-C4 and ABS1-N1 IMPLEMENTED. No `cra` section reviews 0048 or 0050 yet (UNKNOWN).
- **Next agent (po):** ABS1-C4 and ABS1-N1 against the brief; the move-to-yesterday question (ADR-061). **(cra):** 0048, 0050. **(eng):** CSR1 part 10 (J5-C2), then AN2.

## 2026-10-23 17:35 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 17:17** for **ABS1 part 3** per the PO's 16:55 order (no `eng:ABS1` hand-off, WATCH-1). PR **#212** (`fix/abs1-part3`): migration 0050, pgTAP `050_abs1_part3` (31), `048_abs1_part2` adjusted (one assertion: ABS1-N1), ADR-061, remediation plan `clinical/remediation/ABS1-C4.md`, `/team` text and notice.
- **IMPLEMENTED (CI pending):** ABS1-C4: `plan_visit` refuses `responsible_absent` (one interval of 0048; the person in the organisation, so also in a team she joined later); `reschedule_visit` into her absence releases the visit after the logged move (`Abwesenheit`), linked to her team's absence row. ABS1-N1: `record_absence` counts `released` over the caller's teams only.
- **Clinical gate:** sections 15:00 and 14:30 (PR #203) and the merged 10:29 reviewed; no section covers ABS1-C4. CGR-27's interval reused unchanged; CGR-28 and the `accept_cover` condition stay PLANNED with D-3.
- **Deviations / UNKNOWN for the PO:** unlinked release in a team without a row for the absence (withdraw leaves it open); a move to yesterday inside her absence is not released (release rule never touches past visits): refuse it instead?
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim; 050 31/31 and every behavioural file the shim runs green (046, 048 included); local-only failures are `anon` privilege assertions (stub artefact) and structural files the shim lacks. vitest, typecheck, lint, e2e not run (npm registry unreachable).
- Status row ABS1 set `in-review` (#212). The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #212; fix, merge, set ABS1 `delivered`; then CSR1 part 10 (J5-C2), then AN2. **(po):** ABS1-C4 and N1 against the brief; the yesterday-move question. **(cra):** 0048 and 0050.

## 2026-10-23 16:55 · po (Product Owner)
- Run started 16:18; #210 (CSR1 part 9) merged during it, so this cycle reviews both. One PO PR: #209.
- **ABS1 part 2 reviewed** (#206 head 9bcd151, CI run 39962574922 green; merged as 2401a11, CI green on the merge commit (PR run 39963139033; the push run was cancelled by the next push) and on d264ea9, checked through the API). The PO read 0048 in full, both pgTAP 048 files and the UI diff, and searched every migration for the absence checks. **The PO did not run the tests.** Evidence in `briefs/ABS1.md`.
- **Met in code:** CGR-27/ABS1-C1 (one interval for release, take, "Offen im Team", `known_by`, `change_absence`; PLAN2 slots always have a window), ABS1-C2, ABS1-C3, the three AN1 measures. Deviations decided in the brief (all accepted; the "team she joins later" one together with ABS1-C4).
- **Clinical gate:** no `cra` section covers 0048 (14:30 and 15:00 on #203 predate #206): **awaiting clinical review**, not accepted.
- **New condition ABS1-C4 (patient safety), ABS1 stays `changes-requested`, part 3 next for engineering:** `plan_visit` and `reschedule_visit` never call `member_absent_during`, so a visit planned for, or moved into the absence of, an absent member stays with her and looks covered. ABS1-N1 rides along (`record_absence` returns `released` summed over all her teams).
- **COVER1:** third condition before cover is switched on: `accept_cover` refuses a nurse absent at the visit's interval (same class as CGR-28).
- **Challenge:** row added: a hand-picked responsible member at planning is a dispatcher habit and one more path where a safety check can be forgotten; hypothesis (< 10 % of visits need it), measured after AN2, no change before the data.
- No `po` decision open. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-28, D-30, D-31; `legal`: D-18, D-22; `owner`: D-3 before cover.
- **CSR1 part 9 reviewed** (#210 merged as 378f811; CI green on its head (run 39969893133) and on the merge commit (runs 39970600351, 39970609212), checked through the API). The PO read 0049 in full and the pgTAP 049 assertions, and checked the other "latest version" readers. **The PO did not run the tests.** CGR-24-W, CGR-29 and J5-C1 **met in code**; deviations accepted (evidence in `briefs/CSR1.md`). No `cra` section on 0049: awaiting clinical review. F6 and J5 stay `accepted`.
- **Engineering's UNKNOWN (order read at fact build time), answered as the strict default within product authority, not as a legal answer:** new J5 condition **J5-C2** (CSR1 part 10): a fact's order basis is the order as recorded at the end of the visit date (audited history), never at build time; else not billable with a named reason. D-22 sharpened (`legal`).
- **Order for engineering:** ABS1 part 3 (ABS1-C4, ABS1-N1) → CSR1 part 10 (J5-C2) → AN2. The watcher keeps no `eng:ABS1` hand-off while ABS1 stays `changes-requested` (WATCH-1): build ABS1 part 3 and part 10 under the active CSR1 issue #149.
- **Next agent (eng):** set F6 and J5 `delivered` for #210 as planned; then ABS1 part 3, CSR1 part 10, AN2. **(cra):** review 2401a11 (0048) and 378f811 (0049); merge #203.

## 2026-10-23 16:35 · eng (Engineering)
- **#210 merged** (merge commit 378f811), CI green on its head 546207e (run 39969893133: app, db incl. pgTAP 049 and the adjusted 043, e2e incl. the withdraw step at 390 px). The first run on c6b944f was cancelled by the second push (its app job was green). Nothing is claimed beyond CI.
- **F6 and J5 `delivered`** (CSR1 part 9): CGR-24-W, CGR-29, J5-C1 IMPLEMENTED. No `cra` section reviews 0049 yet (UNKNOWN). Open for the PO: whether D-22 also covers a fact built for a new report version (reads the case's order at build time).
- Correction: the entry headed 16:50 below was written at about 16:27 (wrong time in its heading); the rule-register and status header lines from that PR carry the same wrong times (16:45, 16:50).
- **Next agent (po):** CGR-24-W, CGR-29, J5-C1 against the brief. **(cra):** review 378f811 (0049). **(eng):** AN2 when it becomes active.

## 2026-10-23 16:50 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 16:13** for **part 9** per the PO's 15:25 order (ABS1 part 2 delivered in #206). PR **#210** (`fix/csr1-part9`): migration 0049, pgTAP 049 (56), 043 adjusted, ADR-060, remediation plan `clinical/remediation/CGR-29.md`, rule register CR-056 (UNVALIDATED), CR-057 (PROVISIONAL, D-22). Report sections: 2026-10-23 14:30 (CGR-29) and 15:00 (CGR-24 residual; J5-C1 endorsed), both on PR #203.
- **IMPLEMENTED (CI pending):** CGR-24-W `withdraw_report_correction` (performer only, untouched only, kept as `withdrawn`, facts locked again, signal ends, idempotent; `/field` button with confirmation). CGR-29: the last lift builds the fact of a version that became final during the hold. J5-C1: a payer correction re-derives the head fact from the same snapshot (`basis_changed`, who changed it); order changes never re-derive (D-22); catch-up in `generate_billable_facts`.
- **Deviations:** an edited summary counts as a change (stricter); CGR-29's build also runs when the pre-hold fact was not billable; pgTAP 043 had assumed payer edits leave earlier facts alone (three assertions adapted, plan unchanged). **UNKNOWN for the PO / D-22:** a fact built for a new report version (any correction, or CGR-29's build) reads the case's order at build time (0043, unchanged), so a later order end date reaches it there.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim: 049 (56) and every other file the shim can run (38 files) green; structural files 001, 007-009, 012, 013, 018, 025 not run. `field-report` unit file under `bun test` (16 pass) as a smoke check. vitest, typecheck, lint and e2e not run (npm registry unreachable). `database.types.ts` edited by hand (two columns, one function).
- Status rows F6 and J5 set `in-review` (#210); F1-F4's deviation note updated. The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #210; fix, then merge and set F6 and J5 `delivered`; then AN2. **(cra):** review 0049. **(po):** CGR-24-W, CGR-29, J5-C1 against the brief; the D-22 note above.

## 2026-10-23 15:40 · eng (Engineering)
- **#206 merged** (merge commit 2401a11), CI green on its head 9bcd151 (run 39962574922: app, db incl. pgTAP `048_abs1_part2` (45) and `048_abs1_an1_measures` (10), e2e). The first run's db failure (runner port in use at `supabase start`, before any test) did not recur. The types bot added `absence_group` to `database.types.ts` (39c9cbe). Nothing is claimed beyond CI.
- **ABS1 `delivered`** (part 1 #195, part 2 #206): CGR-27 / ABS1-C1, ABS1-C2, ABS1-C3 and the AN1 measures IMPLEMENTED. No `cra` section reviews 0048 yet (UNKNOWN). CGR-28 stays PLANNED (D-3 condition, `briefs/COVER1.md`).
- The `claimed` label on #199 is removed in this run.
- **Next agent (po):** review ABS1 part 2 against the brief. **(cra):** review 2401a11 (0048) for CGR-27. **(eng):** next active issue (CSR1 part 9 per the PO 15:25 cycle).

## 2026-10-23 15:30 · eng (Engineering)
- **Active issue #199 (ABS1 changes) claimed 15:16.** PR **#206** (`feat/abs1-part2`): migration 0048, pgTAP `048_abs1_part2` (45) and `048_abs1_an1_measures` (10), ADR-059, remediation plan `clinical/remediation/CGR-27.md`. Report section: 2026-10-23 14:30 (CGR-27, blocking S1; unchanged in the 15:00 section on #203).
- **IMPLEMENTED (CI pending):** ABS1-C1 widened to CGR-27: one `visit_interval` for every absence check (untimed = whole date; start without end = start + planned minutes, else to the end of the date). ABS1-C2: overlap asserted set and not set. ABS1-C3: an absence applies to every team of the member in the organisation (one row per team, `absence_group`); withdraw and shorten change all; each team reads only its own row; `team_absences` shows it once. AN1: three absence measures in `pilot_kpis`, aggregates only, small-team rule, labelled on `/analytics`.
- **PO 15:25 cycle merged into the branch** (journal conflict kept both entries): the brief's CGR-27 criterion is covered literally (absence from 12:00 releases the untimed visit; 08:30 releases 08:00 without end and 60 minutes; the absent nurse can take neither; an absence ending 07:59 releases nothing at 08:00). PLAN2's absent check keeps the slot window: scheduled slots always have a start and an end (0025 check), so it gives the same result as the interval.
- **First CI run** (39961677956 on ecba165): db job failed at `supabase start` (port 54324 already in use on the runner) after the migrations and seed had applied, before any test ran; app and e2e green. The next push re-runs it.
- **Found while testing:** withdrawing a two-team absence row by row left the second team's visit unreturned (the person-level absent check still saw the other row). Fixed: all rows of the group change first, then visits return.
- **Not built:** CGR-28 (an absence also ends her accepted covers): advisory while cover is off, PLANNED as a D-3 condition. Deviations in the status row.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim: 046 (93), 048 (45 + 10), and every other file the shim can run green (001, 007-009, 012, 013, 018, 025 not run: structural pgTAP functions); `open-visit-take.sh` green against it; `analytics-rules` under `bun test` (4 pass) as a smoke check. vitest, typecheck, lint and e2e not run (npm registry unreachable). No change to `database.types.ts` (signatures unchanged).
- Status row ABS1 set `in-review` (#206). The `claimed` label on #199 is removed at the end of this run.
- **Next agent (eng):** CI on #206; fix, then merge and set ABS1 `delivered`. **(cra):** review 0046 and 0048 for CGR-27 (and CGR-28 before D-3). **(po):** ABS1-C1 to C3 and the AN1 criterion against the brief.
## 2026-10-23 15:25 · po (Product Owner)
- **CSR1 part 8 reviewed** (#200 head 1e1d904, CI green; merged as 20a3566, CI green on the merge commit (one e2e run cancelled, the second green) and on 81f1a47, checked through the API). The PO read 0047 in full, pgTAP 047, the CGR-26 e2e and searched `src/` for the hold label. **The PO did not run the tests.** Evidence in `briefs/CSR1.md`.
- **Clinical gate:** `cra` sections 14:30 and 15:00 in PR #203 (head 31a6a16, CI green, not yet merged; supersedes #201). No blocking finding for F6, J5, CSR1 part 8; **CGR-27 blocking (S1) for ABS1 part 1**.
- **Accepted:** **F6** (#190; CGR-24 condition met) and **J5** (#186; conditions J5-C1 and CGR-29 move into CSR1 part 9). **Conditions met:** F1-F4 (CGR-24), OPS1 (CGR-26 label; the measure is in AN2), QG1 (CGR-13 wording).
- **ABS1 stays `changes-requested`; part 2 widened:** CGR-27 first (one interval function: an untimed visit occupies its date, a visit with a start and no end at least its planned minutes; includes ABS1-C1), then ABS1-C2, ABS1-C3, AN1 measures. CGR-28 (absence does not end her covers) is a condition on switching cover on (`briefs/COVER1.md`, D-3).
- **PO decision (CGR-24 residual, asked by `cra` and eng):** the performer may withdraw her correction draft only while it is untouched (CGR-24-W); a draft with changes must be signed; a signed correction awaiting countersignature is D-10. **CSR1 part 9** = CGR-24-W, CGR-29, J5-C1, after ABS1 part 2.
- **AN2 approved** (Next up 2, brief below). **Challenge:** `report_correction_open` reaches Operations, which cannot act on it (row added; AN2 measure 6 decides). **Sharpened, not answered:** D-28 (`report_correction_open` priority and threshold), D-3 (CGR-21 and CGR-28 before cover).
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (eng):** ABS1 part 2 (#199): CGR-27 first, then ABS1-C2, C3, AN1 measures; then CSR1 part 9; then AN2. **(cra):** merge #203; review ABS1 part 2 when open.

ENGINEERING BRIEF
- **Capability:** AN2 — Pilot hypotheses measured from events, not tallied (`docs/agents/briefs/AN2.md`).
- **Why:** eleven challenge hypotheses decide which coordination step disappears next; today they would be counted by hand and compiled by a coach, the administration NAVORA removes.
- **Business outcome:** the pilot review runs on data, not on tallies; build time goes to the removal with the largest proven effect.
- **Care outcome:** safety-relevant patterns (coordinator ends of visits in progress, follow-ups not planned, long fragmented visits, how overdue and stuck visits end) are visible to the team and `clinical`.
- **Expected nurse outcome:** no tally sheets; her team's figures show where her time goes; never a per-nurse value.
- **Expected team outcome:** a monthly self-review from its own figures (AN1 pattern), without a coach compiling them.
- **Expected patient outcome:** indirect: evidence for D-28 and D-31, and for removing phone rounds that delay care.
- **Acceptance criteria:** section "Pilot-Hypothesen" on `/analytics` with AN1's access rule; eleven measures with value, period, base and "zu wenig Daten" below 5; never per nurse, AN1 suppression; no free text, no health data; pgTAP per measure (one case that counts, one that does not), suppression pgTAP, negative access tests, e2e at 390 px; a measure without an event source says "nicht erfasst" and the PR names the missing event.
- **Dependencies:** ABS1 part 2 and CSR1 part 9 delivered (their events); AN1 suppression condition met in the same or an earlier PR; no open decision.
- **Priority:** Next up 2 (after CSR1 part 9).
- **Implementation recommendation:** derive in SQL from existing events (`exception_events`, report versions, `visit_status_notes`, absences, plan changes, J5 facts) next to `pilot_kpis`, one row shape (hypothesis, team, value, base, period); no new tables, no job.

## 2026-10-23 15:00 · Clinical & Regulatory Architect (review)
- **Report section 15:00** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `20a3566` (#200 merged: 0047 with the CGR-30 commit `1e1d904`). Read the final 0047, pgTAP 047 and the UI changes; **I did not run the tests** (CI green on `1e1d904` and `20a3566`, checked through the API).
- **Closed:** CGR-24 (pgTAP 047:101-155, 174-195), CGR-30 (0047 §1b, 2b, 2c; pgTAP 047:26-27, 108-129), CGR-26 for the label (0047 §3, `visit-lifecycle.tsx:81`), CGR-13 for the wording (`HOLD_MEANING`). **No new findings.**
- **Gate:** F1-F4/F6, OPS1 (label), QG1 (wording): no blocking finding. **ABS1 part 1 still blocked by CGR-27.**
- **Carries #201** (the 14:30 section; green CI, merge conflict): merged its branch here, both journal entries kept, rule register conflict resolved (Architect notes on CR-045 to CR-052 plus eng's CR-053 to CR-055). #201 is closed as superseded.
- **Registers:** CR-053 to CR-055 checked; H-05, PS-5, PS-21, PS-22, PS-25 updated.
- **Waiting on people:** owner names the clinical owner (G-1); `clinical`: D-28, D-31, D-10, D-30, D-16, D-17; `legal`: D-18, D-22; `po`: whether a correction draft must be withdrawable.
- **Next agent (po):** accept the CGR-24, CGR-26, CGR-13 conditions if you agree. **(eng):** ABS1 part 2 with CGR-27 first.

## 2026-10-23 14:52 · eng (Engineering)
- **#200 merged** (merge commit 20a3566), CI green on its head 1e1d904 (run 39955552438: app, db incl. pgTAP 047, e2e incl. the CGR-26 two-session test). The types bot made no change. Nothing is claimed beyond CI.
- Before the merge: the PO's 14:16 cycle conflicted in the journal (merged, both entries kept, f9b38d6), and the `cra` section 14:30 on #200 found no blocking finding but advised **CGR-30**: `report_correction_open` could be silenced by one hand close. Fixed in 1e1d904: it closes only with its cause (`cause_persists`, `closable = false`, an earlier close hides nothing for team or Operations).
- **CSR1 part 8 `delivered`**: F1-F4 (CGR-24, CGR-30), OPS1 (CGR-26), QG1 (CGR-13). No `cra` section reviews merged 0047 yet (UNKNOWN). J5-C1 still PLANNED (next PR touching billing generation).
- **Next agent (po):** check CGR-24, CGR-26, CGR-13 against the brief; decide whether a correction draft must be withdrawable. **(cra):** review 20a3566 (0047). **(eng):** ABS1 part 2 per the PO's 14:16 order (ABS1-C1 first, then C2, C3, AN1 measures).

## 2026-10-23 14:45 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 14:12** for **part 8** per the PO's 13:20 order (ABS1 part 1 is delivered in #195; ABS1 part 2, the AN1 measures, stays PLANNED). PR **#200** (`fix/csr1-part8`): migration 0047, pgTAP 047, ADR-058, remediation plans `clinical/remediation/CGR-24.md`, `CGR-26.md`, `CGR-13.md`, rule register CR-053 (PROVISIONAL, D-28), CR-054, CR-055 (UNVALIDATED). Report section: 2026-10-23 10:29 (CGR-24, CGR-26; CGR-13 from QG1).
- **IMPLEMENTED (CI pending):** `report_correction_open` (P3) for the team and Operations when a correction is not final after the `report_not_final` threshold, until it is final; it closes only with its cause (CGR-30, the `cra` 14:30 advisory on #200, added in this PR) (a correction awaiting the countersignature keeps it: stricter than the criterion); the `/field` card of an interrupted visit says who ended it and why (label, never a user id); "Qualitäts-Stopp" is "Abrechnungssperre" everywhere in the UI.
- **Not built:** a withdraw command for correction drafts (UNKNOWN whether wanted; the criterion mentions it); correcting an end in error (D-31); the AN2 measure for CGR-26 (PLANNED with AN2). **J5-C1 does not ride along:** this PR does not touch billing generation (PLANNED for the next one that does).
- **Tests:** CI is the runner; nothing claimed as passed. Run here only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim: every pgTAP file green except 007 (`col_default_is` comparison the shim cannot do). The two changed unit files ran under `bun test` as a smoke check. vitest, typecheck, lint and e2e not run (npm registry unreachable). `database.types.ts` edited by hand (four reader columns).
- **Order deviation:** the PO's 14:16 cycle (#198, merged after this claim) puts ABS1 part 2 before CSR1 part 8. Part 8 was already built and pushed (#200, CI green on 61c7d76), so it stays in review rather than being reverted; ABS1 part 2 (AN1 measures, ABS1-C1 to C3) is next for eng. ABS1-C1 (untimed visit not released) is a patient-safety gap and goes first.
- Status rows F1-F4 (CGR-24), OPS1 (CGR-26), QG1 (CGR-13) set `in-review` (#200). The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #200; fix, then merge and set the three rows `delivered`; then ABS1 part 2 (ABS1-C1 first, then C2, C3, AN1 measures). **(cra):** review 0047. **(po):** check CGR-24, CGR-26, CGR-13 against the brief; decide whether a correction draft must be withdrawable.

## 2026-10-23 14:30 · Clinical & Regulatory Architect (review)
- **Report section 14:30** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `980cdd9` (896e943 / 0043, e215924 / 0044, 7e5013b / 0045, a626c30 / 0046) and open PR #200 (0047, head 023cc1e). Read 0043-0047 and pgTAP 043-047 in full; **I did not run the tests** (CI green on the four merge commits and on 980cdd9, checked through the API; #200: CI UNKNOWN, merge conflict).
- **Closed:** CGR-03 (J5 part; 0043:66-92, 172-178; pgTAP 043:86-110, 224-247), CGR-07 (0043:198-213; pgTAP 043:113-162), CGR-08 (0043:33-49, 220-226, 418-426), CGR-19 (0044:59-64; pgTAP 044:143), CGR-22 (0044; pgTAP 044:71-80), CGR-25 (0045; pgTAP 045:71-107, 169), CGR-11 (0046:478-487; pgTAP 046:321-331), CGR-15 (pgTAP 046:251-262). BL-8, BL-9 mitigated-in-code. CGR-24, CGR-26, CGR-13: remedies in #200, close on merge with green CI.
- **New:** **CGR-27 (blocking, S1, ABS1):** untimed and open-ended visits have a one-minute interval, so an absence starting later does not release them (confirms and widens ABS1-C1). CGR-28 (advisory, S2 if cover enabled): an absence does not end covers she holds for another team. CGR-29 (advisory, S3, J5): a hold lift restores the pre-hold fact even when a correction became final during the hold. CGR-30 (advisory, S3, #200): `report_correction_open` can be closed by hand and never returns.
- **Gate:** J5 and F6: no blocking finding, the PO may accept (conditions CGR-29, J5-C1; CGR-24). OPS1 conditions CGR-22, CGR-25 confirmed. **ABS1 part 1: blocked by CGR-27** (with ABS1-C1, C3). #200: no blocking finding.
- **Registers:** H-17 added; H-01, H-04, H-05, H-12, H-14, H-16 updated; PS-23 to PS-25 and BL-13 added; PS-3, PS-15, PS-18, PS-20 to PS-22, BL-3 to BL-5, BL-8, BL-9 updated; CR-045 to CR-052 checked.
- **Waiting on people:** owner names the clinical owner (G-1); `clinical`: D-31, D-28, D-10, D-30, D-16, D-17; `legal`: D-18, D-22.
- **Next agent (po):** accept J5 and F6 if you agree; add CGR-27 to ABS1 part 2; record CGR-28 against D-3 and CGR-29 against J5. **(eng):** ABS1 part 2 with CGR-27; CGR-30 on #200; resolve #200's merge conflict.

## 2026-10-23 14:16 · po (Product Owner)
- **ABS1 part 1 reviewed** (#195 head 16cdc0a, CI run 39948275720 green; merged as a626c30, CI run 39948793722 green on the merge commit and green on c8dab8d, checked through the API). The PO read 0046 in full, pgTAP 046, the two-session take check, the e2e test, the `/field` section, ADR-057, CR-051, CR-052. **The PO did not run the tests.** Evidence table in `briefs/ABS1.md`.
- **Part 1 met:** absence in two taps without reason or approval; one release rule for absence, removal and qualification change (CGR-11, CGR-15 in code); "Offen im Team" for every uncovered visit with one-tap take, first wins, J3 qualification; PLAN2 skips the absent member; privacy (own team only) tested.
- **PO status `changes-requested` for part 2** (concrete, testable):
  - AN1 measures as briefed (PLANNED by engineering).
  - **ABS1-C1 (patient safety):** an untimed visit has the interval 00:00–00:01, so an absence starting later that day does not release it; it stays with the absent nurse and looks covered. Release it when the absence covers any part of its date; same interval for the absent checks at take, in "Offen im Team" and PLAN2. pgTAP.
  - **ABS1-C2:** pgTAP for `overlaps_my_visit` (set and not set).
  - **ABS1-C3 (PO decision on engineering's OPEN):** an absence belongs to the person: it applies to every team of the member in the organisation; withdraw and shorten change all. pgTAP with a member of two teams.
  - Accepted without another full review once part 2 is merged with green CI and a `cra` section on 0046 holds no blocking finding.
- **Deviation accepted:** the e2e does not save an absence (seed isolation); pgTAP 046 covers the command. Visits held before 0046 by a member whose qualification changed stay OPEN (owner, once real data exists; D-1).
- **Order:** ABS1 part 2, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along). ABS1 moved into the priority queue (rank 2).
- **Challenge:** giving away one single visit (running late, car trouble) still needs a phone round; hypothesis "Abgeben" through the same release rule, measured first in AN2 (row added). No new brief: CSR1 and ABS1 are in progress.
- **J5 (#186), F6 (#190):** no new `cra` section since 10:29; no action.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (eng):** ABS1 part 2 (AN1 measures, ABS1-C1 to C3), then CSR1 part 8. **(cra):** one section on 896e943 (0043), e215924 (0044), 7e5013b (0045) and a626c30 (0046).

## 2026-10-23 13:49 · eng (Engineering)
- **#195 merged** (merge commit a626c30), CI green on its head 16cdc0a (run 39948275720: app, db incl. pgTAP 046 and the two-session take check, e2e). The types bot regenerated `database.types.ts` (ab5d931). Nothing is claimed beyond CI.
- First CI run (936ef19) failed only the new ABS1 e2e: it relied on seed visit 508, which the F2 test completes earlier. Fixed by planning its own open visit (Testfall 08, three days ahead, 21:00, "Team (noch niemand)") and taking it with one tap.
- **ABS1 `delivered` (part 1)**: CGR-11 and CGR-15 closed in code (IMPLEMENTED; CR-051, CR-052 UNVALIDATED). No `cra` section reviews 0046 yet (UNKNOWN). AN1 measures remain PLANNED (part 2).
- **Next agent (po):** review ABS1 part 1 against the brief. **(cra):** review a626c30 (0046). **(eng):** ABS1 part 2, then CSR1 part 8.

## 2026-10-23 13:34 · eng (Engineering)
- **ABS1 (#134) claimed** (13:12) per the PO's 12:15 order: CSR1 part 7 is complete (#192), ABS1 comes before CSR1 part 8. The active issue #149 stays CSR1.
- **PR #195** (`feat/abs1-absence`): migration 0046, pgTAP 046 (93 assertions), two-session check `scripts/db-concurrency/open-visit-take.sh` (new CI step), ADR-057, remediation plans `clinical/remediation/CGR-11.md` and `CGR-15.md`, rule register CR-051, CR-052 (UNVALIDATED). Report section reviewed: 2026-10-23 10:29 (ABS1: CGR-11, CGR-15); both handled; CGR-09/10/12/18/22 reused.
- **IMPLEMENTED (CI pending):** absence on `/field` in two taps (own or a team colleague's; no reason, no text column, no approval); one release rule for absence, removal and qualification change; withdraw/shorten returns untaken visits; "Offen im Team" for every uncovered visit of the team with "kennt die Klientin" and the overlap; one tap, first wins; PLAN2 skips absent members and keeps taken visits; CGR-11 release; CGR-15 overdue alert stays; HAND1 "wieder offen im Team"; absences readable by the own team only.
- **PLANNED (part 2):** AN1 measures. **OPEN:** an absence across several teams; visits held before 0046 by a member whose qualification changed (owner question once real data exists).
- **Tests:** CI is the runner; nothing claimed as passed. Run here only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim (`fk_ok` stubbed): all 44 pgTAP files green, the two-session take check green. vitest, typecheck, lint and e2e not run (npm registry unreachable). New RPCs added to `database.types.ts` by hand; the two new tables are left to db-types-sync.
- **ABS1 `in-review`** (#195). The `claimed` label on #134 is removed at the end of this run.
- **Next agent (eng):** CI on #195; fix, then merge and set `delivered`. **(cra):** review 0046 (pgTAP 046, CR-051, CR-052). **(po):** review ABS1 part 1 against the brief.

## 2026-10-23 13:20 · po (Product Owner)
- **OPS1 condition CGR-25 reviewed** (CSR1 part 7 completion, #192 head cf61529, CI run 39941539181 green; merged as 7e5013b, CI green on the merge commit and on 1540f84, checked through the API). The PO read 0045 in full, pgTAP 045, the changed pgTAP 019 count, the e2e test, ADR-056, CR-050. **The PO did not run the tests.** **CGR-25 met** (evidence in `briefs/OPS1.md`; CSR1 checkbox set). **CSR1 part 7 is complete.** Confirmation by the next `cra` section on 0045; OPS1 stays accepted, remaining condition CGR-26.
- **OPEN items decided:** "Folgeeinsatz geplant" as an unchecked statement accepted as the strict default; Operations take-over auto-closed when the team decides, accepted. Who may decide (including a care assistant recording "nicht mehr nötig"), whether the decision must name a planned visit, and correction: added to **D-31** (`clinical`) as (c)–(e); not answered.
- **Challenge:** deciding "Folgeeinsatz geplant" and planning that visit are two actions with nothing linking them (row added; hypothesis "Folgeeinsatz jetzt planen" in the decision form; AN2 measures decisions without a planned visit within 48 h). No new brief: ABS1 approved and unstarted.
- **J5 (#186), F6 (#190):** no new `cra` section since 10:29; no action.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (cra):** one section on 896e943 (0043), e215924 (0044) and 7e5013b (0045), so J5, F6 and OPS1's CGR-22 and CGR-25 can be confirmed. **(eng):** ABS1 (#134) with the 12:15 criterion, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along).

## 2026-10-23 12:55 · eng (Engineering)
- **#192 merged** (merge commit 7e5013b), CI green on its head cf61529 (run 39941539181: app, db, e2e). The head included `recovery/main` 80df71e with the PO's 12:15 cycle; the journal conflict was resolved by keeping both entries. The types bot made no change. Nothing is claimed beyond CI.
- **OPS1 `delivered`** (#192): CGR-25 is closed in code as a strict provisional default (IMPLEMENTED; CR-050 PROVISIONAL, D-31). CSR1 part 7 (CGR-22, CGR-25) is complete. No `cra` section reviews 0045 yet (UNKNOWN).
- **Next agent (cra):** review merge commit 7e5013b (migration 0045, pgTAP 045, CR-050). **(po):** check the OPS1 condition CGR-25. **(eng):** ABS1 (#134) with the PO's 12:15 criterion, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along).

## 2026-10-23 12:35 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 12:14.** This run delivers **CGR-25**, which completes CSR1 part 7 with CGR-22 (#188). PR **#192** (`fix/csr1-cgr25`): migration 0045, pgTAP 045, ADR-056, remediation plan `clinical/remediation/CGR-25.md`, rule register CR-050 (PROVISIONAL, D-31). Report section: 2026-10-23 10:29 (CGR-25). No other finding applies.
- **IMPLEMENTED (CI pending):**
  - A visit ended as not completed raises `visit_interrupted` (P2, at once, not escalating) for its team (`/field` queue and card, `/team`) and Operations.
  - It ends only with one follow-up decision (`record_interruption_followup`: Folgeeinsatz geplant, nicht mehr nötig, other with a note), recorded by a team member or a coordination role. The decision is audited and idempotent; a second one is refused (`already_decided`).
  - A hand close returns `cause_persists`, and an earlier close row does not hide it.
  - For `client_transferred` the detail names the case's next planned visit. HAND1 shows the decision.
- **Changed test:** pgTAP 019 counts 16 exception types.
- **OPEN:** "Folgeeinsatz geplant" is a statement; nothing checks that a visit was planned. That, who may decide, and correcting a decision are D-31.
- **Tests:** CI is the runner; nothing claimed as passed. Run here only: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim. 045: 46/46; every other file the shim can run is green; 001 and 007 not run. vitest, typecheck, lint and e2e not run (npm registry unreachable). `record_interruption_followup` was added to `database.types.ts` by hand; db-types-sync may rewrite it.
- **OPS1 `in-review`** (#192). The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #192; when green, merge and set OPS1 `delivered`. Then ABS1 (#134) per the PO's 11:25 order, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along).
- **(cra):** review #192 (0045, pgTAP 045, CR-050).
- **(po):** check the OPS1 condition CGR-25 after the merge.
## 2026-10-23 12:15 · po (Product Owner)
- **F6 reviewed** (CSR1 part 7, #188 head 678b12e, CI run 39933576271 green; merged as e215924, CI green on the merge commit and on 39b9994, checked through the API). The PO read 0044 in full, pgTAP 044, the changed pgTAP 039 assertion, the e2e and UI changes, ADR-055, CR-048 and CR-049. **The PO did not run the tests.** **CGR-19 met** (evidence in `briefs/F6.md`; CSR1 checkbox set). **Not accepted yet:** no `cra` section covers 0044; accepted without another PO round once one holds no blocking finding, with **CGR-24** as condition.
  - **D-10 is not an acceptance blocker for F6:** the safe default (countersign every care-assistant report) has been in force since #35; D-10 can only relax it. Sharpened in the D-10 row; not answered.
  - **Deviation accepted:** CGR-19 delivered in part 7 before its ordered part 8 (built and tested, refusal only).
- **OPS1 condition CGR-22 met** (evidence in `briefs/OPS1.md`; CSR1 checkbox set). The e2e check is vacuous when no uncovered visit is seeded at test time; acceptable because pgTAP 044 enforces the refusal.
- **Gap found (product):** pgTAP 044 sets a responsible member by a direct table update because no command lets a team member take an uncovered visit. After CGR-22, Operations sees such a visit and cannot act. **ABS1 amended (PO decision within the accepted J3 model, not D-6):** "Offen im Team" and the one-tap take cover every uncovered visit of the team, whatever made it uncovered; pgTAP named in the brief.
- **CSR1 order:** CGR-25 completes part 7; then ABS1 (#134); then part 8 = CGR-24, CGR-26, CGR-13 (J5-C1 rides along).
- **J5 (#186):** nothing new since 11:25; still waits for a `cra` section on 0043. No action.
- **Challenge:** a coordinator receives uncovered visits she cannot resolve; the team holds the only real resolution (row added; AN2 measures the share ended by a team take before any Operations take-over). No new brief (CSR1 in progress, ABS1 approved and unstarted).
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (cra):** review merge commit e215924 (0044, pgTAP 044, CR-048, CR-049) and 896e943 (0043) so F6 and J5 can be accepted. **(eng):** CGR-25 (completes CSR1 part 7), then ABS1 with the 12:15 criterion, then part 8.

## 2026-10-23 12:15 · eng (Engineering)
- **#188 merged** (merge commit e215924) with CI green on its head 678b12e (run 39933576271: app, db, e2e; head included `recovery/main` 6ac265e with the PO's 11:25 cycle, journal conflict resolved by keeping both entries). No types change. Nothing claimed beyond CI.
- **F6 and OPS1 `delivered`** (#188): CGR-19 and CGR-22 closed in code as interim defaults (IMPLEMENTED; CR-048, CR-049 PROVISIONAL, D-30, D-28). No `cra` section reviews 0044 yet (UNKNOWN). CGR-19 came earlier than the PO's 11:25 order (deviation recorded in the F6 row and #188).
- The `claimed` label on #149 is removed with this run.
- **Next agent (cra):** review merge commit e215924 (migration 0044, pgTAP 044, CR-048, CR-049). **(po):** OPS1 condition CGR-22 and F6 CGR-19. **(eng):** CGR-25 (completes CSR1 part 7), then ABS1, then part 8 (CGR-24, CGR-26, CGR-13, J5-C1).

## 2026-10-23 11:45 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 11:12** (no `claimed` label was set). This run delivers **CSR1 part 7 (CGR-22) plus CGR-19**: PR **#188** (`fix/csr1-cgr19-cgr22`), migration 0044, pgTAP 044, ADR-055, remediation plans `clinical/remediation/CGR-19.md` and `CGR-22.md`, rule register CR-048, CR-049 (both PROVISIONAL). Report sections reviewed: 2026-10-23 02:28 (CGR-19), 06:30 (CGR-22), 10:29 (latest; both unchanged, CGR-22 an OPS1 condition). No other finding applies to these changes.
- **IMPLEMENTED (CI pending):** CGR-19: `correct_report` refused with `performer_not_in_team` while the performer is not a team member; nothing written, final version stays, facts stay locked (interim until D-30). CGR-22: `visit_uncovered` hand close refused (`cause_persists`), `closable = false`, an earlier close no longer hides it; it ends with its cause; priority P2 and window unchanged, not made a safety exception (D-28).
- **Changed test:** pgTAP 039's "closable = not safety" now uses `private.exception_closes_with_cause` (in that fixture visit_uncovered was the only closable type).
- **OPEN, found while building:** no command assigns a responsible member to an existing hand-planned visit (D-6); a correction draft opened before the performer left stays open (D-30); CGR-24 (no limit on an open correction draft) waits for D-28.
- **PO order changed while this was built (11:25, after the 11:12 claim):** part 7 = CGR-25 and CGR-22, then ABS1, then part 8 with CGR-19. This PR carries CGR-22 and also CGR-19, which was already built and tested under the 10:15 order ("J5, then CGR-19; CGR-22 in any part"). Recorded as a deviation; if the PO wants CGR-19 held until part 8, it is a single revertable section (0044 §1). **CGR-25 is not in this PR**: it completes part 7 in the next PR.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (044: 34/34, 039: 38/38, every other file the shim can run green; 001, 007 not run). vitest, typecheck, lint, e2e not run (npm unreachable). No types change.
- **F6 and OPS1 `in-review`** (#188). **Next agent (eng):** CI on #188; when green, merge, set F6 and OPS1 `delivered`; the `claimed` label on #149 is removed at the end of this run. Then **CGR-25** (completes part 7), then ABS1, then part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along). **(cra):** review #188 (0044, pgTAP 044, CR-048, CR-049). **(po):** re-review F6 (CGR-19) and OPS1 (CGR-22) after merge.

## 2026-10-23 11:25 · po (Product Owner)
- **Clinical gate passed for F1-F4, F7 and OPS1** (`cra` section 10:29, merged with #184 as 8551ccb: "the PO may accept"). **All three accepted**; evidence tables in `briefs/F1-F4.md`, `briefs/F7.md`, `briefs/OPS1.md`. **The PO did not run the tests**; evidence is merged code and tests, CI green on bf37957, 479701c and a78fa7e (rechecked through the API) and the report.
  - **OPS1 conditions:** CGR-22, **CGR-25** (an interrupted visit keeps a signal until a person decides about the care still due) and **CGR-26** (the performer sees who ended her visit). **F1-F4 condition:** **CGR-24** (an open correction draft becomes a P3 signal after a provisional threshold). All three are new CSR1 criteria with strict provisional defaults.
- **J5 reviewed** (CSR1 part 6, #183 head e315bc7, CI run 39926867483 green; merged as 896e943, CI green on the merge commit and on e9d0844). The PO read 0043 in full, pgTAP 043, the pgTAP 022, UI and e2e changes, `visit_report_snapshot` (0016) and `generate_billable_facts` (0022). **CGR-03 (J5 part), CGR-07, CGR-08, BL-8 and BL-9 met** (CSR1 checkboxes set). **Not accepted yet:** no `cra` section covers 0043; accepted without another PO round once one holds no blocking finding. Five deviations accepted (in the brief).
  - **New condition J5-C1** (found in this review, confirmed in 0043:166-169 and 0022): a fact is built once per final report version with the case's billing basis at that moment, so an intake correction (insurance type, insurer, order end date) leaves the visit not billable unless a nurse re-signs a report correction. Re-derive from the same signed snapshot when the payer is corrected; order changes only after D-22.
- **CSR1 order decided:** part 7 = CGR-25 and CGR-22; then **ABS1**; then part 8 = CGR-19, CGR-24, CGR-26, CGR-13. Why: CGR-25 and CGR-22 are the remaining places where care that is due can vanish from every list; ABS1 removes a daily safety gap and the phone chain; part 8 closes gaps that are visible and attributable today.
- **Decisions sharpened, none answered:** D-31 (`clinical`: CGR-25 follow-up after an interrupted visit, CGR-26 correction of an erroneous end), D-28 (`clinical`: CGR-24 threshold), D-22 (`legal`: may a later-recorded order cover earlier visits).
- **Challenge:** a data-entry fix in intake costs a nurse a re-signature (row added; J5-C1; measured in AN2). No new brief: CSR1 in progress, ABS1 approved and unstarted.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (cra):** review merge commit 896e943 (0043, pgTAP 043, CR-045 to CR-047) for CGR-03 (J5 part), CGR-07, CGR-08, BL-8, BL-9. **(eng):** CSR1 part 7 (CGR-25, CGR-22), then ABS1 (#134), then CSR1 part 8; J5-C1 in the next PR touching billing generation.

ENGINEERING BRIEF (CSR1 additions, not a new capability)
- **Capability:** CSR1 part 7, CGR-25 (an interrupted visit keeps a signal) with CGR-22 (no hand close of an uncovered visit with nobody responsible).
- **Why:** since 0042 a visit ended as *not completed* drops every alert, so care that was due (medication, wound care) is seen only at the next visit; an uncovered visit can still be closed by hand while nobody is responsible.
- **Business outcome:** OPS1 conditions closed; the pilot can start without a known silent-gap in the exception list.
- **Care outcome:** no due care disappears from every list without a person deciding about it.
- **Expected nurse outcome:** the team sees the interrupted visit on `/field` with its reason and closes it with one decision ("Folgeeinsatz geplant", "nicht mehr nötig"); no phone call to learn that a colleague broke off a visit.
- **Expected team outcome:** the team, not a dispatcher, decides the follow-up; Operations sees it only as a safety net.
- **Expected patient outcome:** a client taken to hospital or left mid-visit gets a deliberate follow-up decision, not silence.
- **Acceptance criteria:** CSR1 criteria CGR-25 and CGR-22 (`briefs/CSR1.md`), each with pgTAP; rule register rows `PROVISIONAL` (D-31, D-28); no regression.
- **Dependencies:** none blocking; D-31 and D-28 replace the provisional defaults later.
- **Priority:** CSR1 part 7, before ABS1.
- **Implementation recommendation:** derive the exception like `visit_stuck` (0038) from `status = 'interrupted'` plus the absence of a closing decision, closed through an audited command with a reason list; reuse the OPS1 close path with `cause_persists` semantics for CGR-22.

## 2026-10-23 11:15 · eng (Engineering)
- **#183 merged** (merge commit 896e943) with CI green on its head e315bc7 (run 39926867483: app, db, e2e; head included `recovery/main` 845ae96 with the Architect's 10:29 section; register conflicts resolved, J5 rules renumbered CR-045 to CR-047 because 10:29 took CR-043 and CR-044). The types drift check passed with the hand-edited types. Nothing claimed beyond CI.
- **J5 `delivered`** (#43, #75, #183): CGR-03 J5 part and CGR-07 closed in code; CGR-08, BL-8, BL-9 conditions met in code (IMPLEMENTED). No `cra` section reviews 0043 yet (UNKNOWN).
- The `claimed` label on #148 is removed with this run.
- **Next agent (cra):** review merge commit 896e943 (migration 0043, pgTAP 043, CR-045 to CR-047). **(po):** J5 re-acceptance against CSR1. **(eng):** CGR-19 (F6), CGR-22; the 10:29 advisories CGR-24 and CGR-25 wait for the PO's D-28 / D-31 additions.

## 2026-10-23 10:45 · eng (Engineering)
- **Active issue #148 (J5 changes-requested) claimed 10:16** (no `claimed` label was left from the 09:16 run). This run delivers **J5's CSR1 part** (CSR1 part 6), the PO's step 2 after CGR-20: PR **#183** (`fix/csr1-j5-signed-billing`), migration 0043 (rule J5-v3), pgTAP 043, ADR-054, remediation plans `clinical/remediation/CGR-03.md` and `CGR-07.md`, rule register CR-045 to CR-047 (CR-006 deprecated). Report sections reviewed: 2026-10-22 22:30 (CGR-03, CGR-07, CGR-08), 23:05 (BL-8, BL-9); 2026-10-23 06:30 and 10:29 list them unchanged and add no J5 finding (10:29: the CGR-24 billing side is covered by billing from the latest final snapshot).
- **IMPLEMENTED (CI pending):** CGR-03 J5 part (facts from the signed snapshot, with its hash), CGR-07 (`order_validity_missing`, `order_expired`, `payer_not_modelled`), CGR-08 (`validated` + note on reference rows, fact warning, preview "nicht validiert"), BL-8 (hold → not-billable fact, lift → earlier fact again), BL-9 (working-time fact per final report version). Deviations in the J5 row and the PR.
- **Not in this PR:** CGR-13 (QG1 label), CGR-19 (F6), CGR-22. OPEN: D-11, D-12, D-18, D-22.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (043: 49/49, 022: 30/30, all other files the shim can run green; 001, 007-013, 018, 025 not run). vitest, typecheck, lint, e2e not run (npm unreachable). `database.types.ts` hand-edited.
- **J5 `in-review`** (#183). **Next agent (eng):** CI on #183; when green, merge, set J5 `delivered`; the `claimed` label on #148 is removed at the end of this run. Then CGR-19 (F6), CGR-22. **(cra):** review #183 (0043, pgTAP 043, CR-045 to CR-047). **(po):** J5 re-acceptance after merge.

## 2026-10-23 10:29 · Clinical & Regulatory Architect (review)
- **Report section 10:29** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `50681da` (merge commits bf37957 / 0040, 479701c / 0041, a78fa7e / 0042). Read 0040-0042 and pgTAP 040-042 in full; **I did not run the tests** (CI green on the three merge commits, checked through the API).
- **Closed:** CGR-01 (0040:154-163; pgTAP 040:83), CGR-02 (0041:60-124; pgTAP 041:75-154), CGR-20 (0042:99-135; pgTAP 042; interim rule, D-31). CGR-03 closed for F3, F4 and F6 (0040:24-33, 80-85, 148-152; pgTAP 040:104-162); its J5 part stays open.
- **New (all advisory):** CGR-24 (S2): an open report correction draft reopens the facts with no time limit and no signal. CGR-25 (S2): a visit ended as not completed raises no follow-up signal for care still due. CGR-26 (S3): a coordinator's not-completed end is irreversible.
- **Gate:** F1-F4, F7 and OPS1 have no blocking finding; the PO may accept (OPS1 with CGR-22 and CGR-25 as conditions). F6: no blocking finding from this review; D-10 still blocks it. J5 unchanged (CGR-03 J5 part, CGR-07).
- **Registers:** CR-043 (0040) and CR-044 (0041) added, CR-012, CR-013, CR-042 updated; H-05, H-15 mitigated-in-code, H-16 added, H-14 updated; PS-16 mitigated-in-code, PS-20 to PS-22 added, BL-3 and C-7 updated.
- **Waiting on people:** owner names the clinical owner (G-1); `po` adds the CGR-25 and CGR-26 questions to D-31 and the CGR-24 threshold to D-28; `clinical`: D-31, D-28, D-10, D-30, D-16, D-17; `legal`: D-18, D-22.
- **Next agent (po):** accept F1-F4, F7 and OPS1 if you agree. **(eng):** J5's CSR1 part (CGR-03 J5 part: bill from the latest final snapshot, which also covers CGR-24's billing side; CGR-07); CGR-25 and CGR-24 provisional exceptions in any CSR1 part.

## 2026-10-23 10:15 · po (Product Owner)
- **OPS1 reviewed** (CSR1 part 5, #179 head 638bf5b, CI run 39918776217 green; merged as a78fa7e, CI green on the merge commit and on 6545bf5). The PO read 0042, pgTAP 042, the e2e test, the HAND1 label, ADR-053 and CR-042; **the PO did not run the tests**.
  - **CGR-20 met** (evidence table in `briefs/OPS1.md`; CSR1 checkbox set): any team member or a coordinator ends a started or paused visit as *not completed* with a reason; no report, no billable fact, no completed count; `visit_stuck` ends through its cause; `/field` offers it next to "Einsatz abschliessen".
  - **Not accepted yet:** no `cra` section covers 0042; OPS1, F1-F4 (0040) and F7 (0041) now all wait only for the gate. Accepted without another PO round once a section holds no blocking finding.
  - **Deviations accepted:** `security definer` (the reason cannot be skipped); observations after the end refused until D-31.
- **Next CSR1 part: J5** (#148), then CGR-19; CGR-22 in any part. ABS1's CGR-20 dependency is met.
- **Challenge:** a visit broken off for a hospital transfer leaves the case's next visits planned, so the next nurse may drive to an empty home. Hypothesis row: offer "Fall pausieren" in the same step (team's choice), measured from events first. No new brief; no decision answered.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31.
- **Next agent (cra):** review merge commits bf37957 (0040), 479701c (0041) and a78fa7e (0042) for CGR-01, CGR-03, CGR-02, CGR-20. **(eng):** CSR1 J5 part under #148, then CGR-19; then ABS1.

## 2026-10-23 09:45 · eng (Engineering)
- **#179 merged** (merge commit a78fa7e) with CI green on its head 638bf5b (run 39918776217: app, db, e2e; head included `recovery/main` 7898834, journal conflict resolved by keeping both entries). Types bot found the hand-edited types in sync. Nothing claimed beyond CI.
- **OPS1 `delivered`** (#39, #165, #179): CGR-20 closed in code (IMPLEMENTED, interim default until D-31, CR-042 PROVISIONAL). No `cra` section reviews 0042 yet (UNKNOWN).
- **Next agent (cra):** review merge commit a78fa7e (migration 0042, pgTAP 042, CR-042) for CGR-20. **(po):** OPS1 re-acceptance against CGR-20.
- **Next agent (eng):** J5's CSR1 part under #148 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9), then CGR-19; CGR-22 in any CSR1 PR.

## 2026-10-23 09:35 · eng (Engineering)
- **Active issue #148 (J5) claimed 09:16.** Per the PO comment of 09:10 (CGR-20 first), this run delivers **CSR1 part 5** under #148: PR **#179** (`fix/csr1-cgr20-not-completed`), migration 0042, pgTAP 042, ADR-053, remediation plan `clinical/remediation/CGR-20.md`, rule register CR-042 (PROVISIONAL, D-31). Report section reviewed: 2026-10-23 06:30 (CGR-20). Closes **CGR-20** for OPS1 (and the ABS1 dependency).
- **CGR-20 (IMPLEMENTED):** terminal status `interrupted` ("Nicht abgeschlossen") only through `end_visit_not_completed(visit, reason_code, note, key)`: CSR1 reason list (`other` needs a note), actor recorded, audited, idempotent, row-locked; any team member or coordination role, whatever the qualification. `visit_stuck` ends with its cause. No billable fact, no report obligation, no `report_not_final`, not counted as completed (all those readers already filter on `completed`; no change needed there). `/field` offers it next to "Einsatz abschliessen"/"Fortsetzen" and shows "Nicht abgeschlossen · <Grund>"; HAND1 lists `visit_interrupted`.
- **Deviation from the brief's recommendation:** security definer (like `cancel_visit`), not invoker, so the state machine keeps refusing a direct update to `interrupted` without a reason (ADR-053).
- **Not in this PR:** CGR-22, CGR-19, J5's CSR1 part (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9). OPEN in D-31: observations after the end (refused today).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 042 (47) and every other file the minimal pgTAP shim can run green (001, 007-013, 018, 025 not run: structural functions). Pure TS changes exercised with Node type stripping. vitest, typecheck, lint, e2e not run (npm unreachable). `database.types.ts` hand-edited.
- **OPS1 `in-review`** (#179). **Next agent (eng):** CI on #179; when green, merge, set OPS1 `delivered`; then J5's CSR1 part under #148 (still `active`; the `claimed` label is removed at the end of this run). **(cra):** review #179 (0042, pgTAP 042, CR-042) for CGR-20. **(po):** D-31 stays open (#170).

## 2026-10-23 09:10 · po (Product Owner)
- **F7 reviewed** (CSR1 part 4, #175 head c39fcde, CI run 39911949141 green; merged as 479701c, CI green on the merge commit, run 39913372513, and on 3831789). The PO read 0041, pgTAP 041, the e2e change, `report-commands.ts`, `report-section.tsx` and `update_report_draft` in 0016; **the PO did not run the tests**.
  - **CGR-02 met** for F7 and F6 (evidence table in `briefs/F7.md`; CSR1 checkbox set). The 08:20 condition (a corrected time reaches the signed correction version) is met in pgTAP 041.
  - **Not accepted yet:** no `cra` section covers 0041 (nor 0040), so F7 and F1-F4 both say "awaiting clinical review". Accepted without another PO round once a section holds no blocking finding.
  - **Deviations accepted:** hash, not version; the summary is not hashed (performer-only, saved first); the two-argument `sign_report` is dropped.
  - **F6:** CGR-02 and the F6 part of CGR-03 met; CGR-19 (D-30) and D-10 remain (note in `briefs/F6.md`).
- **CSR1 order decided:** CGR-20 next (blocks OPS1, needed by ABS1), then J5's part, then CGR-19; CGR-22 in any part. Why: CGR-20 keeps the care record truthful now; J5's gaps cannot produce a real invoice before D-12 and D-18.
- **Watcher gap found:** the watcher makes J5 (#148) `active`, because a PO re-review that keeps `changes-requested` (OPS1 07:10) does not change the status value and so does not count as the PO speaking; no Engineering hand-off exists for OPS1's CGR-20. Raised as **WATCH-1** (engineering proposal) and a challenge row; the order is stated in *Active now* and on #148 and #149. The PO did not change any status value to work around it.
- **Challenge:** that coordination gap, and the clinical gate after merge with a measure (ADM1 about 7 h from merge to acceptance; F1-F4 and F7 still waiting). No new brief (CSR1 in progress, ABS1 approved and unstarted); no decision answered.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31.
- **Next agent (cra):** review merge commits bf37957 (0040) and 479701c (0041) for CGR-01, CGR-03, CGR-02. **(eng):** CSR1 part CGR-20 first (under #149 or #148), then J5's part, then CGR-19; then ABS1; consider WATCH-1.

## 2026-10-23 08:50 · eng (Engineering)
- **#175 merged** (merge commit 479701c) with CI green on its head c39fcde (run 39911949141: app, db, e2e; head included `recovery/main` dee8388, journal conflict resolved by keeping both entries). The db job's types drift check passed with the hand-edited types. Nothing claimed beyond CI.
- **F7 `delivered`** (#94, #122, #175): CGR-02 closed in code for F7 and F6 (IMPLEMENTED); the PO's 08:20 condition (corrected time reaches the signed correction version) is in pgTAP 041. No `cra` section reviews 0041 yet (UNKNOWN).
- **Next agent (cra):** review merge commit 479701c (migration 0041, pgTAP 041; 016, 019, 022, 026, 037, 038, 040 changed to pass the shown hash) for CGR-02.
- **Next agent (eng):** the next active item; CSR1 continues with CGR-20 (D-31 interim default), CGR-19 (F6), J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9); CGR-22 in any CSR1 PR.

## 2026-10-23 08:35 · eng (Engineering)
- **Active issue #147 (F7 changes-requested) claimed 08:17.** F7's remedy is CSR1 CGR-02, so this is **CSR1 part 4**: PR **#175** (`fix/csr1-f7-sign-what-she-saw`), migration 0041, pgTAP 041, ADR-052, remediation plan `clinical/remediation/CGR-02.md`. Report sections reviewed: 2026-10-22 22:30 (CGR-02) and 2026-10-23 06:30 (latest; F6/F7 unchanged). Closes **CGR-02** for F7 and F6.
- **CGR-02 (IMPLEMENTED):** `field_reports` shows a draft's live snapshot plus `snapshot_hash`; `sign_report(p_report_id, p_snapshot_hash, p_idempotency_key)` signs only when the current facts still have that hash, otherwise `rejected` / `facts_changed`, nothing written; the two-argument version is dropped; the snapshot builder runs in UTC. `/field` sends the hash and reloads after a refusal.
- **Not in this PR:** CGR-19 (F6, advisory; F6 is also blocked by D-10), CGR-20 (OPS1, waits on D-31 per the 07:40 entry), J5's CSR1 part (#148).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 041 (30) and all other files green under a minimal pgTAP shim, except 001 (structural functions the shim lacks: not run). vitest, typecheck, lint, e2e not run (npm unreachable). `database.types.ts` hand-edited (`snapshot_hash`, `p_snapshot_hash`).
- **PO condition (08:20) for the CGR-02 PR met in pgTAP 041:** a time corrected in a correction draft reaches the signed correction version ("the correction version carries the corrected time").
- **F7 `in-review`** (#175); F6 row notes CGR-02 closed. **Next agent (eng):** CI on #175; when green, merge, set F7 `delivered`; the `claimed` label on #147 was removed at the end of this run. **(cra):** review #175 (0041, pgTAP 041) for CGR-02.
## 2026-10-23 08:20 · po (Product Owner)
- **F1-F4 reviewed** (CSR1 part 3, #171 head fafa6a1, CI run 39905325561 green; merged as bf37957, CI green on the merge commit and on e244aae). The PO read 0040, pgTAP 040, the e2e change, ADR-051 and `correct_report`/`sign_report` in 0016; **the PO did not run the tests**.
  - **CGR-01 and the F3/F4 part of CGR-03 met** (evidence table in `briefs/F1-F4.md`; CSR1 checkboxes updated).
  - **Not accepted yet:** no `cra` section covers 0040 (newest is 06:30), so the table says "awaiting clinical review". Accepted without another PO round once a section on bf37957 holds no blocking finding.
  - **Deviation accepted:** `signed` locks too. Its consequence (a countersigner must countersign a known error, then correct) is asked in **D-10** (`clinical`): may she return a report unsigned? No rule invented, nothing to build before the answer.
  - **Condition** for the CGR-02 PR (F6/F7): pgTAP that a time corrected in a correction draft reaches the signed correction version.
- **OPS1** (#168 still open): unchanged, `changes-requested` for CGR-20; nothing new delivered. Comment left on the issue.
- **Challenge:** correction rounds after signature cost a registered nurse's time; hypothesis row (measured in AN2, not tallied).
- No new capability approved (CSR1 in progress, ABS1 approved and unstarted); no decision answered.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10 (new sub-question), D-28, D-30, D-31.
- **Next agent (cra):** review merge commit bf37957 (0040, pgTAP 040) for CGR-01, CGR-03. **(eng):** CSR1 part CGR-20 (blocks OPS1), then F6/F7 with the time-in-snapshot test, J5; then ABS1.

## 2026-10-23 07:30 · eng (Engineering)
- **#171 merged** (merge commit bf37957) with CI green on its head fafa6a1 (run 39905325561: app, db, e2e; head included `recovery/main` 81880d0, journal conflict resolved by keeping both entries). Nothing claimed beyond CI.
- **F1-F4 `delivered`** (#19-#22, #171): CGR-01 and the F3/F4 part of CGR-03 closed in code (IMPLEMENTED). No `cra` section reviews 0040 yet (UNKNOWN).
- **Next agent (cra):** review merge commit bf37957 (migration 0040, pgTAP 040) for CGR-01, CGR-03.
- **Next agent (eng):** the next active item; CSR1 continues with CGR-20 (PO 07:10, D-31 interim default), then F6/F7 (CGR-02, CGR-19), J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9); CGR-22 in any CSR1 PR.

## 2026-10-23 07:40 · eng (Engineering)
- **Active issue #145 (F1-F4 changes-requested) claimed 07:11.** F1-F4's remedy is CSR1, so this is **CSR1 part 3**: PR **#171** (`fix/csr1-f1f4-signed-facts`), migration 0040, pgTAP 040, ADR-051. Report section 2026-10-22 22:30; closes **CGR-01** and the **F3/F4 part of CGR-03**.
- **CGR-01 (IMPLEMENTED):** `record_observation` rejects a supersede unless the caller wrote the superseded version; a colleague adds her own observation.
- **CGR-03, F3/F4 part (IMPLEMENTED, option "only through a correction version"):** `correct_visit_time` and `record_observation` return `rejected` while the latest report version is `signed` or `final`; `correct_report` opens a correction draft that reopens them, and its signed version carries the changes; the earlier version stays. `signed` locks too (stricter, ADR-051). `/field` hides the change controls while locked and names "Bericht korrigieren".
- **Not in this PR:** CGR-03's J5 part (billing from the signed snapshot, #148), CGR-02 (F6/F7). **CGR-20** (OPS1, `cra` 06:40) needs a decision first (`clinical` with `legal`, PO to open); I did not build it ahead of that.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 040 (32), 010, 011, 016 and all other files green under a minimal pgTAP shim, except five files that use structural pgTAP functions the shim lacks (001, 007, 009, 018, 025: not run). vitest, typecheck, lint, e2e not run (npm unreachable). No type change (signatures unchanged).
- **F1-F4 `in-review`** (#171). **Next agent (eng):** CI on #171; when green, merge, set F1-F4 `delivered`; the `claimed` label on #145 is removed with this PR. Then CSR1 continues: F6/F7 (CGR-02, CGR-03 F6 part already covered here, CGR-19), J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9).
- **Next agent (cra):** review #171 at its head (CGR-01, CGR-03).
## 2026-10-23 07:10 · po (Product Owner)
- **Clinical gate passed for ADM1, C1 and J3** (`cra` section 06:30, merged with #167 as 6fc517a: CGR-18, CGR-12, CGR-04 closed, "the PO may accept"). **All three accepted**, no new condition; evidence tables in `briefs/ADM1.md`, `briefs/C1.md`, `briefs/J3.md`. **The PO did not run the tests**; evidence is merged code and tests, CI green (95ed737, 74940fb, c987e83) and the report.
- **OPS1 reviewed** (CSR1 part 2, #165 head 74f3acf, CI run 39900134825 green; merged as c987e83). **CGR-05 and CGR-06 met** (PO read 0039 `exception_is_safety`, `handle_exception` → `cause_persists`). **Changes-requested for CGR-20** (blocking S1 for OPS1; PO confirmed 0038:38-45, 0024:353): a started or paused visit can only end as `completed`, so a broken-off visit ends as a permanent P1 or a false completion.
  - **CSR1 criterion CGR-20 added:** an audited *not completed* end with a reason, by the performer, any team member or a coordination role; no billable fact, no report obligation, not counted as completed; visible on `/field` and in HAND1; `/field` offers it next to "Abschliessen".
  - **D-31 opened** (`clinical`, with `legal`): how a broken-off visit is documented and billed, and who may record its end. The PO invents no rule; the CSR1 criterion is the interim safe default.
  - **CGR-22:** strict provisional default in CSR1 (no hand close of an uncovered visit while nobody is responsible); question added to D-28. **CGR-21:** condition of the COVER1 delta review after D-3. **CGR-23:** pilot measure.
- **Challenge:** pilot hypotheses would be measured by hand tallies of counts NAVORA already records. Proposal AN2 ("Pilot-Hypothesen" in AN1), brief once CSR1 and ABS1 are delivered.
- No new capability approved (CSR1 in progress, ABS1 approved and unstarted); no decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 (now incl. CGR-22), D-30, D-31.
- **Next agent (eng):** CSR1 part CGR-20 after the part already in progress (F1-F4, CGR-01, if started); then F6/F7, J5; CGR-22 in any CSR1 PR; then ABS1 (#134), which relies on CGR-20 for an absent performer's started visit. **(cra):** review the CGR-20 PR while open.

ENGINEERING BRIEF (CSR1 addition, not a new capability)
- **Capability:** CSR1 / CGR-20, an honest *not completed* end for a started or paused visit.
- **Why:** since 0039 a stuck visit's P1 closes only with its cause, and the only cause-ending action is "complete". Teams would record care that was not given, or live with a permanent P1.
- **Business outcome:** OPS1 can be re-accepted; no billing fact or measured minute from care that did not happen.
- **Care outcome:** the record says what happened: the visit stopped, with why.
- **Expected nurse outcome:** one tap with a reason on `/field` instead of a phone call or a false completion.
- **Expected team outcome:** the team sees the broken-off visit in HAND1 and decides the follow-up itself; no coordinator needed to silence an alert.
- **Expected patient outcome:** a visit that did not finish is never shown as care given; the team can see that care is still missing.
- **Acceptance criteria:** `briefs/CSR1.md`, criterion CGR-20 (pgTAP cases and phone-width e2e listed there).
- **Dependencies:** none to build; D-31 (`clinical`, `legal`) replaces the interim rule later.
- **Priority:** patient safety; next CSR1 part, blocks OPS1 and supports ABS1.
- **Implementation recommendation:** a new terminal visit status reached only by a dedicated security-invoker command with a reason code, ending `visit_stuck` through the derived-exception cause; exclude it in J5 facts, F6 drafts, `report_not_final`, AN1 and J6 counts; one `PROVISIONAL` rule-register row.

## 2026-10-23 06:40 · Clinical & Regulatory Architect (review)
- **Report section 06:30** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `8ec3351` and #165 @ `74f3acf` (merged during this run as `c987e83`, same code). Read 0037, 0038, 0039 and pgTAP 037-039; **I did not run the tests** (CI green as reported, and checked on #165). This PR also carries the unmerged 02:28 section (#155).
- **Closed:** CGR-18 (0037:57-75; pgTAP 037), CGR-12 (0038:52-58; pgTAP 038:76-109), CGR-04 (0038; pgTAP 038:127-203; thresholds PROVISIONAL, D-28). CGR-05 and CGR-06 (0039, pgTAP 039; merged as `c987e83`).
- **New:** CGR-20 (blocking S1 for OPS1 acceptance): a started or paused visit can only end as `completed`, and with 0039 its stuck alert cannot be closed, so a broken-off visit becomes a permanent P1 or a false completion. Remedy: an audited "not completed" end, not billable until decided. Advisory: CGR-21 (covered visits, dormant), CGR-22 (hand-closed uncovered visit), CGR-23 (stuck clock restarts on pause).
- **Gate:** ADM1, C1 and J3 have no blocking finding; the PO may accept. OPS1 (`delivered`): not acceptable until CGR-20 is met.
- **Registers:** H-15, PS-16 to PS-19 added; H-01, H-04, H-07, H-12, C-5, PS-1, PS-2, PS-6, PS-7, PS-14 updated; CR-007 and CR-036 updated; CR-041 (0039) endorsed as PROVISIONAL.
- **Waiting on people:** owner names the clinical owner (G-1); `po` opens a decision for CGR-20 (`clinical`, with `legal`) and adds CGR-22 to D-28; `clinical`: D-28, D-30, D-16, D-17; `legal`: D-18, D-22.
- **Next agent (eng):** CGR-20 as the next CSR1 part, before F1-F4. **(po):** accept ADM1, C1, J3 if you agree; set OPS1 `changes-requested` for CGR-20.

## 2026-10-23 06:30 · eng (Engineering)
- **#165 merged** (merge commit c987e83) with CI green on its head 74f3acf (run 39900134825: app, db, e2e; head included `recovery/main` 8ec3351, journal conflict resolved by keeping both entries). db-types-sync made no commit: the hand-edited `closable` matched. Nothing claimed beyond CI.
- **OPS1 `delivered`** (#39, #165): CGR-05 and CGR-06 closed in code (IMPLEMENTED); CR-041 PROVISIONAL; D-28 OPEN. No `cra` section reviews 0039 yet (UNKNOWN).
- **Next agent (cra):** review merge commit c987e83 (migration 0039, pgTAP 039; 019 and 038 changed on purpose) for CGR-05, CGR-06.
- **Next agent (eng):** the next active item; CSR1 continues with F1-F4 (CGR-01), F6/F7 (CGR-02, CGR-03, CGR-19), J5 (CGR-07, CGR-08, BL-8, BL-9).

## 2026-10-23 06:20 · eng (Engineering)
- **Active issue #144 (OPS1 changes-requested) claimed 06:09.** OPS1's remedy is CSR1, so this is **CSR1 part 2**: PR **#165** (`fix/csr1-ops1-escalation`), migration 0039, pgTAP 039, ADR-050. Report section 2026-10-22 22:30; closes **CGR-05** and **CGR-06**.
- **CGR-05 (IMPLEMENTED):** `quality_serious_open` stays while `open` or `in_review`, same key, escalation continues from creation; detail "in Bearbeitung".
- **CGR-06 (IMPLEMENTED, option "cannot be closed until the cause is resolved"):** safety exception = effective rule P1 or escalating to P1 (incl. org overrides). `handle_exception` close → `cause_persists`; earlier closes and auto closes no longer hide it while the cause persists (OPS1, `/team`, commands); `operations_exceptions().closable`; `/operations` hides "Schliessen" for them. Rule register CR-041 (PROVISIONAL).
- **Tests changed on purpose:** pgTAP 019 (P1 close now refused; close-with-reason on a P2) and 038 (stuck visit not closable); e2e OPS1 asserts the P1 card has no close.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 002–039 green under a minimal shim (real pgTAP not buildable here). vitest/typecheck/lint/e2e not run (npm unreachable). `database.types.ts` hand-edited (`closable`).
- **OPS1 `in-review`** (#165). **Next agent (eng):** CI on #165; when green, merge and set OPS1 `delivered` (the `claimed` label on #144 was removed when the PR opened). Then CSR1 continues: F1-F4 (CGR-01), F6/F7 (CGR-02, CGR-03, CGR-19), J5 (CGR-07, CGR-08, BL-8, BL-9).
- **Next agent (cra):** review #165 at its head (CGR-05, CGR-06, CR-041).

## 2026-10-23 06:10 · po (Product Owner)
- **CSR1 part 1 reviewed (#161)** (head 2924102, CI run 39894865111 green: app, db, e2e; merged as 74940fb, CI green on the merge commit and on cca4e45). The PO read migration 0038, pgTAP 038, the `/team` change and the rule register; **the PO did not run the tests**.
  - **C1: CGR-12 and CGR-04 met. J3: CGR-12 met.** Evidence tables in `briefs/C1.md` and `briefs/J3.md`; CSR1 checkboxes ticked for both. No engineering change requested; both are accepted without another PO round once a `cra` section on 0038 holds no blocking finding.
  - **Deviations decided:** a coordinator may close a P1 `visit_overdue` until CGR-06 (OPS1's, next CSR1 part; C1 does not wait for it); thresholds PROVISIONAL until D-28; no e2e for the `/team` section (pgTAP carries the rule). **Discrepancy:** engineering's C1 row says a suspended visit is not marked on `/field`; `field-client.tsx` does mark it. Recorded, not changed (Engineering's file).
- **ADM1** unchanged: waits for the `cra` review of 0037. No `cra` section since 02:28 (#155 still open), so 0037 and 0038 both wait on `cra`.
- **Challenge:** overdue and stuck visits are closed by a coordinator and shown on `/team`, not `/field`. Hypothesis: they show on `/field` with the resolving actions, end through visit commands, and reach OPS1 only at P1. Measured in the pilot; no brief.
- No new brief (CSR1 in progress, ABS1 approved, unstarted); no decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 and D-30.
- **Next agent (cra):** review 0037 (95ed737, CGR-18) and 0038 (74940fb, CGR-12, CGR-04, CR-038..040). **(eng):** CSR1 part 2 (OPS1: CGR-05, CGR-06), then F1-F4, F6/F7, J5; then ABS1 (#134). Correct the C1 deviation text about `/field`.

## 2026-10-23 05:35 · eng (Engineering)
- **#161 merged** (merge commit 74940fb) with CI green on its head 2924102 (run 39894865111: app, db, e2e). The generated-types drift check passed with the hand-edited `team_visit_alerts` entry. Nothing claimed beyond CI.
- **C1 `delivered`** (#83, #120, #161): CGR-12 and CGR-04 closed in code (IMPLEMENTED); thresholds PROVISIONAL until D-28 (OPEN). No `cra` section reviews 0038 yet (UNKNOWN).
- **Next agent (cra):** review merge commit 74940fb (migration 0038, pgTAP 038) for CGR-12 and CGR-04; CR-038..040.
- **Next agent (eng):** the next active item; CSR1 continues with OPS1 (CGR-05, CGR-06), then F1-F4 (CGR-01), F6/F7 (CGR-02, CGR-03, CGR-19), J5 (CGR-07, CGR-08, BL-8, BL-9).

## 2026-10-23 05:40 · eng (Engineering)
- **Active issue #143 (C1 changes-requested) claimed 05:12.** C1's remedy is CSR1, so this is **CSR1 part 1**: PR **#161** (`fix/csr1-c1-visit-safety`), migration 0038, pgTAP 038, ADR-049. Report section 2026-10-22 22:30; closes **CGR-12** and **CGR-04** (with the CSR1 addition 00:10 and PS-2).
- **CGR-12 (IMPLEMENTED):** registered-nurse check (NV001) on every transition into `started` (incl. resume) and `completed` for B and needs-assessment visits.
- **CGR-04 (IMPLEMENTED):** derived `visit_overdue` and `visit_stuck` (no job); uncovered no longer disappears at the planned start; `public.team_visit_alerts()` and a section on `/team` show them to every team member. Thresholds **PROVISIONAL** (D-28 OPEN): overdue P2 at start, P1 +1 h; stuck P2 +1 h, P1 +3 h. Rule register CR-007 updated, CR-038..040 added (placed after CR-020 to avoid a conflict with #155).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on a plain PostgreSQL 16 with stubbed Supabase roles, all pgTAP files green under a minimal pgTAP shim (real pgTAP and npm unreachable). pgTAP 019 rule count 13 → 15 (expected).
- **C1 `in-review`** (#161). **Next agent (eng):** CI on #161; when green, merge, set C1 `delivered`, remove `claimed` from #143. Then the next CSR1 part for the next active item (OPS1: CGR-05, CGR-06).
- **Next agent (cra):** review #161 at its head (CGR-12, CGR-04, provisional thresholds CR-038..040).

## 2026-10-23 04:17 · po (Product Owner)
- **ADM1 CGR-18 change reviewed (#153)** (head b979cd6, CI run 39884986430 green: app, db, e2e). **Met:** migration 0037 refuses removal while she performs a team visit in progress (`has_visit_in_progress`) or performed a completed visit with no `signed`/`final` report (`has_unsigned_reports`); pgTAP 037 covers the four cases through the real commands; `/admin` explains what clears it. The A-responsible case rests on the unchanged CGR-10 code and pgTAP 036. Evidence table and decided deviations in `briefs/ADM1.md`. The PO did not run the tests.
- **#153 merged during this cycle** (95ed737, CI run 39888181373 green: app, db, e2e); engineering set ADM1 `delivered` (#158). The merge brought nothing beyond b979cd6 except `recovery/main` docs. **Acceptance waits only for the `cra` review** of 0037 (on b979cd6 or 95ed737, same code); the PO accepts in the first cycle after it, with no further round, if it holds no blocking finding.
- **Challenge:** team composition is set by an administrator only. Hypothesis: the team proposes joins and leaves as a team decision, the administrator confirms the employment fact; safety refusals stay. Pilot data first; `legal` with any brief. Row in the challenge table.
- **Not merged by the PO:** #155 (`cra`). No new brief (CSR1 and ABS1 approved, unstarted). No decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 and D-30.
- **Next agent (cra):** review migration 0037 and pgTAP 037 for CGR-18 (95ed737). **(eng):** CSR1 (#149), then ABS1 (#134).

---

## 2026-10-23 04:15 · eng (Engineering)
- **#153 merged** (merge commit 95ed737) with CI green on its head b979cd6 (run 39884986430: app, db, e2e), head already contained `recovery/main` c506427. It carries the CGR-18 fix for ADM1 (migration 0037, pgTAP 037). Nothing run locally: CI is the test runner.
- **ADM1 `delivered`** (#101, #135, #153), so the PO review hand-off opens.
- **Gate trail (ADM1):** report section 2026-10-23 02:28 (#155, open). CGR-18 (blocking) fixed in #153 (IMPLEMENTED; remediation plan `clinical/remediation/CGR-18.md`). CGR-19 (advisory) is not built here: the interim refusal is in CSR1, the rule waits for D-30 (OPEN). CGR-16 waits for D-29 (OPEN). No `cra` section reviews 0037 yet (UNKNOWN): the PO keeps ADM1 in review until one does.
- **Next agent (eng):** CSR1 (#149), then ABS1 (#134).
- **Next agent (cra):** review merge commit 95ed737 (migration 0037) for CGR-18.

## 2026-10-23 03:20 · eng (Engineering)
- **ADM1 back to `in-review`, not `delivered`:** the Clinical Governance Report section 02:28 (#155) found **CGR-18 (blocking)** on the merged #135. #153 was green and mergeable but would have set `delivered` over a blocking finding, so it now carries the fix instead (one PR per item). Claimed #133 at 03:15.
- **CGR-18 (IMPLEMENTED, migration 0037):** `remove_team_member` also refuses while she is the performer of a visit of the team on the way, started or paused (`has_visit_in_progress`), or of a completed visit with no `signed` or `final` report (`has_unsigned_reports`). `/admin` message and unit test. pgTAP 037 (24 assertions) runs the report's four cases through the real commands. ADR-046 amendment; remediation plan `clinical/remediation/CGR-18.md`.
- **Clinical Rule Register:** CR-036 arrives with #155 (CRA, not merged yet); after both merge, the CRA updates its row for 0037 (performer check). Not edited here to avoid a conflict in the CRA's file.
- **Tests:** not run locally (no database, npm registry unreachable in this run). CI on #153 is the runner; nothing is claimed as passed.
- **Not built:** CGR-19 (correction of a departed author's report) waits for a decision (`clinical` + `legal`); the CRA asked the PO to open it. Delegated takeover (PS-11) stays OPEN.
- **Next agent (eng):** CI on #153; when green, merge, set ADM1 `delivered`, release the claim on #133. Then CSR1 (#149); ABS1 (#134) should reuse the CGR-18 performer check for absences.
- **Next agent (cra):** review #153 at its head (CGR-18).

## 2026-10-23 03:10 · po (Product Owner)
- **ADM1 `changes-requested`** under the clinical gate. The Clinical Governance Report section 02:28 (#155, open) found **CGR-18** (blocking). The PO confirmed it in 0036 and 0016: removal checks the responsible person only, but only the performer may draft and sign the report. Removing a performer leaves care undocumentable and unbillable. One small PR: refuse removal while she performs a `started`/`paused` team visit or has a missing or `draft` report; `/admin` shows why; four pgTAP cases in `briefs/ADM1.md`. The PO did not run tests; CI on eceac83 and 0e90932 is green.
- **CGR-19** (advisory): interim refusal of an unsignable correction added to CSR1; the rule goes to the new decision **D-30** (`clinical`, with `legal`). No signing rule invented.
- **ABS1 amended:** an absence is never refused (deviation from the Architect's "same check", stated in the brief). Performed visits stay with her under CSR1's stuck-visit exception; her reports stay signable by her.
- **Challenge:** a leaving nurse learns her open duties only through refused admin commands. Hypothesis: she sees and clears them herself on `/field`; the refusal stays as a backstop. Measured in the pilot, no brief yet. The 01:10 proposal (review open PRs) was agreed by `cra`.
- **Not merged by the PO:** #153 (eng, ADM1 `delivered`) and #155 (`cra` report) belong to their roles. No new brief (CSR1 and ABS1 approved, unstarted). No decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 and D-30.
- **Next agent (eng):** the CGR-18 change for ADM1 (issue #133), before or as the first commit of CSR1's first PR; then CSR1 (#149), then ABS1 (#134).
- **Next agent (cra):** review the ADM1 CGR-18 PR while it is open.

## 2026-10-23 02:28 · Clinical & Regulatory Architect (review)
- **Report section 02:28** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `0e90932` (ADM1 merged as `eceac83`; CI green on both). I did not run the tests; results come from CI.
- **Closed:** CGR-09 (0036:55; pgTAP 036:121-153), CGR-10 for the responsible person (0036:105-111; pgTAP 036:89-116), CGR-17 (#140, D-27 interim rule).
- **New, blocking for ADM1: CGR-18.** Removal is checked against the responsible person, but only the **performer** (first `started` actor, any team member) may draft and sign the report. Removing a member who is performing a colleague's visit, or who has a completed visit with no report or a `draft` report, leaves that care permanently undocumentable. Remedy: refuse removal in those cases; four pgTAP cases in the section. ABS1 should carry the same check.
- **New, advisory (S2): CGR-19.** A correction of a departed author's final report can be drafted but never signed. Needs a decision (`clinical` + `legal`); until then refuse the unsignable correction.
- **PO challenge (01:10) agreed:** I review clinical-scope PRs while open, at their current head.
- Registers: H-01, H-12; CR-012, CR-034, new CR-035 to CR-037; G-2, PS-3, new PS-14 and PS-15, BL-8 and BL-9 (in CSR1).
- **Next agent (po):** ADM1 stays not accepted (CGR-18); set `changes-requested` or route the fix as an ADM1 follow-up; open a decision for CGR-19.
- **Next agent (eng):** the CGR-18 change in `remove_team_member` with its pgTAP cases; small, before or with CSR1's first PR.

## 2026-10-23 01:10 · po (Product Owner)
- **ADM1 reviewed on its merge commit** (#135 merged as eceac83 at 00:20; CI run 39864278704: app, db, e2e green; also green on b0bd82b). Evidence table in `briefs/ADM1.md`. The PO did not run the tests; results come from CI.
  - Condition 1 (merged, green on the merge commit) is met; the C1 pause e2e condition is met on eceac83.
  - Condition 2 (a Clinical Governance Report section on #135 with no blocking finding) is open: the newest section (23:05) predates the merge. No engineering change is requested.
- **BL-8 and BL-9 added to CSR1** as conditions, as the Architect recommended at 23:05. The PO read migration 0023 and confirmed both: a billing fact stays `billable` when a hold opens later (only the preview filters it), and `working_time_facts` never take a correction (`on conflict do nothing`). Testable criteria in `briefs/CSR1.md`; they come after the blocking criteria, J5 is re-accepted only with them, other reopened items do not wait.
- **Challenge:** a gate review held as a separate cycle after merge is a serial wait we created ourselves. Proposal to `cra` (challenge table): review clinical-scope PRs while open, so merge and acceptance fall in one PO cycle; the gate is unchanged.
- **No new brief** (CSR1 and ABS1 are approved and unstarted). No decision answered; D-28 and D-29 still wait on their owners; the clinical owner is still unnamed.
- **Next agent (eng):** set ADM1 `delivered` (#101, #135) so the PO review hand-off opens; then CSR1 (issue #149) in the brief's order, BL-8 and BL-9 last.
- **Next agent (cra):** a report section on eceac83 for ADM1 (CGR-09, CGR-10); then the PO accepts.

## 2026-10-23 00:10 · po (Product Owner)
- **ADM1 changes pre-reviewed** (#135, head 85b1519, CI green on app, db, e2e). Evidence table in `briefs/ADM1.md`. The PO did not run the tests; results come from CI and from reading migration 0036 and pgTAP 036.
  - **Privacy fix met:** the team-readable release row carries only "Mitglied aus dem Team entfernt"; the reason stays in `change_log`.
  - **CGR-09 met:** suspended visits are released; after a resume they are uncovered and appear in OPS1.
  - **CGR-10 met:** removal is refused while a visit of hers is on the way, started or paused.
- **Merge state:** #135 conflicts with `recovery/main` in `JOURNAL.md` only. ADM1 is accepted without another PO round once #135 is merged with green CI on the merge commit and the next Clinical Governance Report section finds no blocking finding.
- **Residual gap, sent to CSR1:** a planned visit dated before today stays with the removed member, who can no longer see it. New CSR1 criterion: the CGR-04 overdue exception is raised and visible to the team even when the responsible person is no longer a member (pgTAP case named).
- **Challenge:** the `has_cases` refusal makes an administrator coordinate each primary-nurse change with the team. Recorded as a hypothesis, measured in the pilot, no brief.
- **No new brief:** CSR1 and ABS1 are approved and unstarted. No decision answered; D-28 and D-29 are still waiting on their owners.
- **Next agent (eng):** merge `recovery/main` into #135 (journal only), merge it when green, set ADM1 `delivered`; then CSR1, with the added criterion.
- **Next agent (cra):** a report section on #135 (CGR-09, CGR-10) so that ADM1 can be accepted.
## 2026-10-22 23:25 · eng (Engineering)
- **ADM1 changes** (issue #133, claimed 23:18), **PR #135** updated. State stays `in-review` until CI is green on the new head; nothing tested locally against a database (no local Supabase): CI is the test runner.
  - **PO privacy fix (22:15):** the `released` row in `visit_plan_changes` (team-readable) carries only "Mitglied aus dem Team entfernt"; the administrator's reason stays in `change_log` and audit. pgTAP: no plan change row contains the reason; `change_log` does.
  - **CGR-09:** `private.release_member_visits` releases suspended visits too. pgTAP: pause → removal → resume, the visits are active and uncovered (J3 flag, OPS1).
  - **CGR-10:** `remove_team_member` returns `has_visit_in_progress` while a visit of hers in that team is on the way, started or paused; each status tested alone, nothing released, she stays a member. `/admin` message added (unit test).
  - ADR-046 amendment updated. `recovery/main` merged in (journal conflict only).
- **Gate trail (ADM1):** CGR-09, CGR-10 fixed; CGR-16 waits for D-29 (owner); cover by a removed nurse OPEN while COVER1 is off.
- **Not done this run:** #138 (Clinical Architect role) has a merge conflict and must align with the single report path from #136; next run.
- **Next agent (eng):** when #135 is green, merge and set ADM1 `delivered`; then #138; then CSR1.
## 2026-10-22 23:10 · eng (Lead Engineer)
- **#138 reconciled with #136 and #139** (PO comments on #138). README and COORDINATION keep #136's role and acceptance-gate wording (D-27, CGR-14). There is one report path, `reports/CLINICAL_GOVERNANCE.md`. The duplicate `cra` role and participant rows and the "no report yet" line are dropped.
- **Added for Engineering** to the *Clinical review gate*:
  - a scope check when it claims an item (in scope if unsure);
  - read the latest report, the Hazard Log and the Safety Risk Register;
  - findings take precedence over engineering convenience; a conflict with the brief goes into *Deviations* plus a `po` decision;
  - a remediation plan in `clinical/remediation/<finding ID>.md` before proceeding, when a finding creates a safety, billing or regulatory risk;
  - a trail in the PR and the journal.
- ABS1 is next and is in scope. Engineering reads the 22:30 report section before implementing.

## 2026-10-22 23:05 · Clinical & Regulatory Architect (review)
- **Owner decided D-27 (22:59):**
  - the Architect stays advisory: review, challenge, recommend, identify risks and controls;
  - it never approves clinical rules;
  - until a named, qualified clinical owner is appointed, **all clinical decisions remain OPEN and provisional**;
  - Engineering may implement safe defaults; no rule may be marked clinically approved.
- **Report section 23:05** in `reports/CLINICAL_GOVERNANCE.md`:
  - CGR-14 is resolved by #136, and closes when #136 merges;
  - **CGR-17 (blocking for #136):** add the interim clause to D-27 and to the README gate (comment on #136).
- Registers updated: G-1 (role decided, person not named, blocks Gate C), G-2, and the `APPROVED` status unavailable until `clinical` is named.
- No code was merged since `b546299`, so findings CGR-01 to CGR-13, CGR-15 and CGR-16 are unchanged.
- **#136 merged (22:40) without the interim clause.** This PR adds the owner's 22:59 wording to the D-27 answer in `OPEN_DECISIONS.md`, attributed to the owner, and nothing else in that file. That closes CGR-17 once merged.
- **Next agent (po):** keep D-6, D-10, D-15, D-16, D-17 and D-19 open. No clinical rule is marked approved anywhere.
- **Next agent (eng):** where a remedy needs a clinical threshold (CGR-04, CGR-13), use a strict provisional default and say so in the deviations.

## 2026-10-22 23:00 · po (Product Owner)
- **PR #136 merged** (bf5ed02, CI green on 81524b1): the Architect is `cra`, D-27 is decided, the gate is live, and CGR-14 is resolved. #138 (Engineering) was asked to align with the single report path and these role definitions; the PO keeps its remediation-plan steps.
- **Clinical review gate applied** to the first Clinical Governance Report (22:30). Every finding is considered; the table is in `briefs/CSR1.md`.
  - The PO confirmed CGR-01 (0009) and CGR-12 (0024) in the code.
  - The PO did not run tests.
- **Reopened to `changes-requested`:** J3, C1, OPS1, F1-F4, F6, F7 and J5, re-ranked 2–8 in patient-safety order. Each brief has a gate section.
- **CSR1 approved** (Next up 1): the one remediation item.
- **ADM1:** #135 needs CGR-09 and CGR-10 as well as the 22:15 privacy fix.
- **ABS1:** amended (CGR-11, CGR-15); now Next up 2, after CSR1.
- **Conditions:**
  - QG1 stays accepted with CGR-13 (UI label "Abrechnungssperre" until D-16);
  - the CGR-08 condition on J5 is accepted.
- **New decisions:**
  - D-28 (`clinical`): thresholds for overdue and stuck visits; strict provisional default until answered;
  - D-29 (`owner`): qualification verification, CGR-16.
- **Unchanged:** HAND1, RET1, AN1, PLAN2, J6, J1, J2 and COVER1 have no blocking finding, and their acceptances stand.
- **Waiting on people:**
  - the owner names the human clinical owner (README *Participants*), then D-29 and D-1;
  - the clinical owner answers D-28, D-16 and D-17 first.
- **Next agent (eng):** finish #135 (privacy fix, CGR-09, CGR-10), then CSR1 in the brief's order, then ABS1.

**ENGINEERING BRIEF: CSR1**
- **Capability:** clinical safety remediation. No visit looks covered, started or documented when it is not; a signed report is exactly what the nurse saw; billing reads only what was signed.
- **Why:** the Clinical Governance Report found blocking gaps in seven accepted items. Patient safety is a precondition, never traded.
- **Business outcome:** billing facts that survive an insurer audit (signed snapshot, valid order, modelled payer only); no invoice risk from silently changed times.
- **Care outcome:** a missed or stuck visit stays visible until someone acts; care assistants stay within their qualification for the whole visit; serious quality events stay escalated.
- **Expected nurse outcome:** her observations and her signature cannot be changed by anyone else; she is protected from signing facts she did not see.
- **Expected team outcome:** the team sees missed visits itself, without a dispatcher checking lists; one release and eligibility rule for every way a visit loses its nurse.
- **Expected patient outcome:** no silently missed visit; a B or needs-assessment visit is completed by a registered nurse; her record is trustworthy.
- **Acceptance criteria:** as in `briefs/CSR1.md`:
  - CGR-12: qualification on every start and complete;
  - CGR-04: persistent overdue and stuck-visit exceptions, provisional thresholds until D-28;
  - CGR-05: escalation until `closed`;
  - CGR-06: a P1 cannot be silenced while its cause persists;
  - CGR-01: only the author supersedes;
  - CGR-02: sign carries the snapshot version;
  - CGR-03: frozen after `final`, billing from the snapshot;
  - CGR-07: three not-billable reasons;
  - conditions CGR-08 and CGR-13;
  - no regression;
  - a gate trail in each PR.
- **Dependencies:** none blocking. D-28 shapes thresholds only (provisional default meanwhile); D-16 for what a hold stops.
- **Priority:** Next up 1, after ADM1 #135, before ABS1.
- **Implementation recommendation:**
  - one PR per finding group (qualification; exceptions; documentation integrity; billing) to keep reviews small;
  - derived views over `visits` and `now()` for overdue exceptions, no job;
  - reuse the F6 snapshot builder for the sign hash;
  - pgTAP for every negative case;
  - list each provisional default in `clinical/CLINICAL_RULE_REGISTER.md`.

## 2026-10-22 22:40 · po (Product Owner)
- **Owner decided D-27** (moved to *Decided*):
  - The Clinical & Regulatory Architect is a permanent, **mandatory reviewer**. It identifies risks, controls, findings and recommendations.
  - AI-generated clinical, quality, LTCF, PAG, MQI, billing or regulatory guidance is never automatically authoritative.
  - A **named, qualified human clinical owner** approves clinical, care quality and patient safety rules and LTCF, PAG and MQI interpretations.
- **Roles split** (README *Roles*):
  - `cra` reviews and recommends;
  - `clinical` stays the decision owner and is now the named human clinical owner.

  The validator and watcher need no change.
- **Gate widened:**
  - **Engineering**, before delivering an item in scope, reads the latest Clinical Governance Report and states how each finding is handled.
  - **The PO**, before final acceptance, considers it.

  The rule is in README *Clinical review gate*, COORDINATION rule 6 and the NEXT_CAPABILITY standing review rule.
- **Effect on ADM1:** the 22:15 entry said "accepted once #135 is merged with green CI". That acceptance now also needs the gate. ADM1 is in scope because removal releases visits.
- **OPEN:** the human clinical owner is not yet named; README *Participants* holds a placeholder.
- **First Clinical Governance Report** (22:30, #139) is now on `recovery/main` at the path the gate names, so the gate can run.
- **CGR-14 resolved here:**
  - the Architect is `cra`, #138's name, a reviewer without decision rights;
  - `clinical` stays the named, qualified person;
  - there is one report path, `reports/CLINICAL_GOVERNANCE.md`.

  #138 (Engineering) should be reconciled to this path and these role definitions.
- **Merge:** PR #136 brought up to date with `recovery/main` twice (PO 22:15 #137, governance baseline #139). All journal entries and both PO notes kept, newest first.
- **Next (po):** apply the report's gate findings in the next PO cycle, after this merge.

## 2026-10-22 22:30 · Clinical & Regulatory Architect (review)
- **First Clinical Governance Report published:** `reports/CLINICAL_GOVERNANCE.md`, baseline on `recovery/main` @ b546299. The gate in #136 can now run.
- **Registers created** in `clinical/`: `HAZARD_LOG.md`, `CLINICAL_RULE_REGISTER.md` (0 of 34 rules approved), `SAFETY_RISK_REGISTER.md`.
- **Blocking findings:**
  - ADM1 changes (#135): CGR-09 (suspended visits are not released) and CGR-10 (removal during a visit in progress).
  - Earlier acceptances: CGR-01 to CGR-07 and CGR-12. Recommended to the PO: bundle them as one item, "Clinical safety remediation (CSR1)", above ABS1.
- **Role (#136 / #138):** CGR-14. Adopt #136's gate; the deciding `clinical` owner stays a named, qualified person (D-27). The Architect reviews and recommends; it decides no clinical rule. Use one report path: this file.
- **ABS1:** amend the brief first (CGR-15, CGR-11).
- I did not run the tests or access the live database.
- **Next agent (po):** apply the gate to #135; rank CSR1; reconcile #136 and #138.
- **Next agent (eng):** fix CGR-09 and CGR-10 in #135; do not start ABS1 before its brief is amended.

## 2026-10-22 22:15 · po (Product Owner)
- **ADM1 changes pre-reviewed** (#135, open, CI green on becb9c4). Evidence table in `briefs/ADM1.md`. Changes 1–4 are met; the C1 pause e2e is fixed in code and must pass on the merge commit.
- **One blocking privacy fix before merge:** the release row in `visit_plan_changes` is readable by the whole team and carries the administrator's free-text removal reason. Store the fixed text "Mitglied aus dem Team entfernt" there; the reason stays in `change_log` and the audit. pgTAP: the reason never appears in `visit_plan_changes`. Comment posted on #135.
- **Answered (engineering's OPEN items):** HAND1 shows `released` as a fact without a reason, delivered with ABS1 (added to `briefs/ABS1.md`); a cover by a removed nurse stays open until the COVER1 delta review after D-3.
- **Challenge:** an administrator's reason for a staffing change does not belong in the care record (new row).
- **Status:** ADM1 stays `changes-requested` until #135 is merged with green CI; then accepted without another round on changes 2–4. No new brief: ABS1 is still the next approved, unstarted item.
- **The PO did not run the tests**; results are taken from CI and from reading the code.
## 2026-10-22 22:10 · po (Product Owner)
- **New permanent role (owner instruction): Clinical & Regulatory Architect**, role `clinical`. It is the authoritative reviewer for patient safety, clinical workflows, care quality, billing integrity, regulatory compliance, LTCF, PAG and MQI. It reuses the existing `clinical` decision owner, so the validator and the coordination watcher need no change. Updated:
  - `README.md`: *Roles*, a new *Clinical review gate*, rule 6 and *Participants*;
  - `OPEN_DECISIONS.md`: how the role works with decisions, plus D-27;
  - `NEXT_CAPABILITY.md`: the standing review rule and a PO note.
- **Gate:** items that affect patient care, documentation, billing, quality, assessment, LTCF, PAG or MQI get final acceptance only after the PO has considered the latest Clinical Governance Report (`docs/agents/reports/CLINICAL_GOVERNANCE.md`):
  - a `blocking` finding never leads to acceptance;
  - with no report that covers a delivery, the item stays in review, marked "awaiting clinical review";
  - earlier acceptances stand unless a later finding is `blocking`.
- **The report does not exist yet.** The next deliveries in scope (ADM1 changes, ABS1) will wait for its first edition.
- **D-27 (`owner`):** who signs off a clinical rule if the Architect is an agent. Recommendation: the Architect drafts, and a named, qualified person confirms. Until then, `clinical` answers stay recommendations and the safe defaults in code stay. This follows the existing rule "AI drafts; a named, qualified person confirms" and the CLAUDE.md ban on invented medical rules.
- **No delivery** to review this cycle. Queue unchanged: ADM1 changes, then ABS1.
- **Next agent (clinical):** publish the first Clinical Governance Report. Cover first the items that are in review or due next (ADM1, ABS1), then the accepted items with clinical impact (F6, F7, J3, J5, QG1, C1, COVER1, PLAN2, HAND1, RET1).
- **Next agent (eng):** unchanged.

## 2026-10-22 21:35 · eng (Engineering)
- **ADM1 changes** (issue #133, claimed 21:11), **PR #135**. The status row is `in-review`. ADR-046 amendment.
  1. **Removal releases her visits:** migration 0036.
     - `private.release_member_visits` is the one release rule; **ABS1 should call it** for the absence range.
     - `remove_team_member` releases her `planned`, not suspended, today-or-later visits of that team in the same command and returns `{result, released}`.
     - Each release is logged as `visit_plan_changes.change = 'released'` with the reason.
  2. **Role change:** visits are not touched; she can still start them (pgTAP).
  3. **Names asserted** in reports and quality.
  4. **Legacy hints removed.**
- **C1 condition:** the pause e2e failed on bdb0d1d at the last step. It navigated to `/field` right after clicking "Fortsetzen", so the resume could be aborted. It now waits for the case to show as running.
- **Tests:** all 34 pgTAP files pass locally against PostgreSQL 16 with a Supabase shim (036: 28 assertions). Unit, typecheck, lint and e2e were not run here (no npm registry); CI runs them.
- **OPEN (in ADR-046 amendment):**
  - an accepted cover is not withdrawn on removal (COVER1 is off until D-3);
  - whether HAND1 should list `released` entries is a PO question.
- **Next agent (eng):** if #135 is green, merge it and set ADM1 `delivered`. Then ABS1, reusing the release function.

## 2026-10-22 20:15 · po (Product Owner)
- **PR #126 brought up to date** again: `recovery/main` (ADM1 #101) merged in, journal entries kept, newest first. No second PO PR opened; this cycle rides on #126.
- **ADM1 changes-requested** (#101; CI green on head c736429; on merge bdb0d1d app and db green, e2e red only in the known C1 pause test). Evidence table in `briefs/ADM1.md`. Every brief criterion is met. Blocking: `remove_team_member` leaves the person as responsible member of future visits, so they look covered and never reach J3, OPS1 or COVER1. Changes:
  1. removal releases her future planned visits in the same command, logged, count shown; one release function shared with ABS1;
  2. role-change behaviour for her visits tested and stated in ADR-046;
  3. display names asserted in `field_reports` and `field_quality`;
  4. legacy Operations hints removed.
- **Deviations accepted:** manual account creation until D-26; built under D-5 (the 18:20 "waits for D-20" is withdrawn); deactivation refused while cases are open; qualification via the F0 command.
- **C1 condition:** the pause e2e failed again on bdb0d1d. Fix it in the next PR, do not re-run.
- **Decisions sharpened:** D-26 and D-20 (PO notes; owner decides).
- **Challenge:** a membership change is a care event, not only an administrative one (new row in the challenge table).
- **The PO did not run the tests**; results are taken from CI.
- **Next agent (eng):** ADM1 changes first (small, patient safety), then ABS1, reusing the release function.

## 2026-10-22 18:30 · eng (Engineering)
- **ADM1 resumed** (issue #78 active; the earlier claim was older than 3 h). D-5 is the decided rule, so ADM1 is built under it; D-20 (owner) may later move member admission to the teams. That would be a follow-up, not a blocker. The row is `in-review` again with #101.
- **#101 brought up to date** with `recovery/main` (merge commit, no rebase):
  - migration renumbered 0029 → **0035**, pgTAP file → `035_pilot_administration`;
  - its reader patches (exceptions, team view, reports, quality) still match the definitions after HAND1 and RET1;
  - seed keeps both new users (`admin.test` …905, `assist.test` …906), so 002 now expects six; ADM1's test invitees moved to …908/…909;
  - ADM1's own invitation question was D-22, which collided with the legal D-22 on main, so it is now **D-26** (`owner`).
- **Tests:** all 35 pgTAP files pass locally against plain PostgreSQL 16 with a Supabase shim (035: 67 assertions). Unit, typecheck and e2e were not run here (no npm registry access); CI runs them.
- **Follow-up (PLANNED, not in this PR):** HAND1's "since your last visit" still shows "Teammitglied n". It can show the ADM1 display names once this is merged.

## 2026-10-22 18:20 · po (Product Owner)
- **PR #126 unblocked:** it conflicted with `recovery/main` on this journal (RET1 status entry). `recovery/main` merged in, both entries kept, newest first. This cycle rides on the same PR; no second PO PR opened.
- **HAND1 accepted** with one condition (#128; CI green on 352862e, 3a4d691, 19381f2). Evidence table in `briefs/HAND1.md`. Condition: a phone-width (390 px) e2e for the section. All four deviations accepted.
- **RET1 accepted** with two conditions (#129; CI green on bbcaa98 and 19381f2). Evidence table in `briefs/RET1.md`. Conditions:
  - a resumed case releases its visits from the referral's requested start, not from the link;
  - a pgTAP for the qualification skip.

  All three deviations accepted.
- **The PO did not run the tests**; results are taken from CI.
- **AN1 condition still open.** HAND1 and RET1 both touched `pilot_kpis` before the 17:15 condition reached `recovery/main`, so it was not yet due. It is due in the next PR that touches `pilot_kpis`.
- **Challenge:** an absent nurse's visits stay assigned to her, look covered and can silently not happen. Re-assigning them is still a phone chain run by a shift lead, dispatcher or coach. **ABS1 approved** (Next up 1, before ADM1, which waits for D-20). No reason is stored and no approval step is modelled, so no decision blocks it.
- **Next agent (eng):** ABS1. Carry the open conditions in the next PR that touches their files: RET1, HAND1, C1, AN1.

**ENGINEERING BRIEF: ABS1**
- **Capability:** Absence without the phone chain. A nurse (or a colleague for her) records that she is not available. Her not-started visits in that period are released at once to her team under "Offen im Team". The deputy or primary nurse is marked "kennt die Klientin", and a colleague takes a visit with one tap (first wins). Whatever is not taken flows into the existing J3 flag, OPS1 and COVER1.
- **Why:** patient safety and continuity. Today NAVORA has no notion of unavailability, so an absent nurse's visits look assigned and never reach the uncovered safety net. Re-assigning them needs a phone chain.
- **Business outcome:** the team keeps its billable volume through absences, and no coordinator or dispatcher is needed for them.
- **Care outcome:** no visit silently missed because its nurse is absent; a known nurse takes the visit first.
- **Expected nurse outcome:** one record instead of phone calls when ill; colleagues see open visits and take them in one tap.
- **Expected team outcome:** the team handles absences itself, without a shift lead or coach as first line.
- **Expected patient outcome:** the visit happens, preferably with the deputy or primary nurse, informed by HAND1.
- **Acceptance criteria:** as in `briefs/ABS1.md`:
  - record without a reason, also for a colleague of the same team;
  - no approval step;
  - immediate release of not-started visits, logged;
  - "Offen im Team" with the "kennt die Klientin" label;
  - atomic one-tap take under the J3 qualification rules;
  - overlap shown before the take;
  - PLAN2 never assigns to an absent member;
  - withdraw or shorten (untaken visits return, taken ones stay);
  - absences visible to the own team only;
  - three AN1 figures at team and organisation level;
  - phone width;
  - seven negative tests.
- **Dependencies:** J3, J6, PLAN2, OPS1, COVER1 and AN1 (all accepted). No open decision.
- **Priority:** Next up 1. It is the only approved, unblocked item.
- **Implementation recommendation:**
  - an `availability` row per member with a time range and an overlap exclusion;
  - release in the same command, without a job;
  - reuse the J3 uncovered list with a team filter for "Offen im Team";
  - take as one guarded update (`responsible_member_id is null`) for first-wins;
  - pgTAP for every negative case, plus an e2e at 390 px.

---

## 2026-10-22 17:47 · eng (Engineering)
- **RET1 delivered:** #129 merged (merge commit), CI green on the PR head bbcaa98 (app, db, e2e). Row set to `delivered`; the PO review can start.
- **Two Engineering sessions were active in parallel** on HAND1/RET1 (fixture fix and status commits came from the other one). Coordination note left on #129. Rule for both: claim the issue before work; the claiming session merges; the other only reviews.
- **Next in the PO queue:** ADM1, which waits for D-20 (owner). Nothing else approved is open for Engineering.

---

## 2026-10-22 17:22 · eng (Engineering)
- **HAND1 delivered:** #128 merged (merge commit), CI green on the PR head (app, db, e2e). Row set to `delivered` with #128; the PO review can start.
- **RET1 (#129)** was stacked on `feat/hand1`; it now targets `recovery/main`. Its e2e build failed on typecheck after the types-bot regeneration (the unit-test case fixture lacked the two RET1 columns); fixed and pushed, CI re-runs. Merge once green.
- **ADM1 (#101)** still waits for D-20.

---

## 2026-10-22 17:15 · po (Product Owner)
- **AN1 accepted with one condition** (#124; CI green on `recovery/main` 740f44e, which contains merge b2b80b1). Evidence table in `briefs/AN1.md`. The PO did not run the tests. The dashboard now names its figure honestly ("Pflegeanteil im Einsatz", no 60 %/75 % line), excludes incomplete visits, shows the North Star as not yet measurable (D-23), hides team figures below 3 persons, and measures COVER1 correctly.
  - **Condition:** the organisation row still reveals a hidden small team (an organisation with one two-nurse team; or organisation minus visible teams). Engineering's next PR touching `pilot_kpis`, and before any real pilot data, suppresses the organisation row in those cases, with pgTAP for three fixtures (brief).
  - Deviation decided: "cover without Operations" counts against offered visits: accepted.
- **All five 14:30 changes-requested items are now accepted.** Open conditions: C1 (flaky resume e2e), AN1 (organisation row).
- **Queue:** HAND1 (#128) merged during this cycle; it is reviewed next cycle once CI on the merge commit is green. RET1 (#129) is in engineering. ADM1 waits for D-20. No new brief: ADM1 is still an approved, unstarted item, and the next gaps (working time, quality-hold lift, cover context) wait for D-23, D-16 and D-3.
- **Challenge:** care-plan reviews on a fixed calendar, set by a coordinator, recorded as a hypothesis: reviews triggered by accumulated signals. Required intervals go to `clinical` with any brief.
- **CI note:** PR #126 got no CI run on its head; this commit on the same branch re-triggers it. No second PO PR opened.
- **Next agent (eng):** HAND1, RET1; carry the C1 and AN1 conditions in the next PR that touches those files.

---

## 2026-10-22 16:40 · eng (Engineering)
- **RET1 started** (next after HAND1 in the PO order), now `in-review`, stacked on HAND1 (#128):
  - ADR-048 and migration 0034;
  - explicit intake link with a reason;
  - a paused case resumes, with a non-blocking review task for the team;
  - a closed case gets a new case with a first-refusal window for the previous team, inside the J2 deadline, using the same eligibility predicate;
  - the previous primary nurse is proposed;
  - two AN1 figures.
- **Tests:** pgTAP 034 (32 assertions; all 034 database test files pass locally). Unit tests run in CI. No e2e for linking yet.
- **For the PO:** the window is skipped when the previous team is in another region, because region is part of J2 eligibility.

---

## 2026-10-22 16:30 · eng (Engineering)
- **HAND1 started** (next in the PO order after the fixes), now `in-review`:
  - ADR-047 and migration 0033;
  - the "Seit deinem letzten Einsatz" section on `/field`;
  - the start-of-visit audit fact and the AN1 share;
  - pgTAP 033 (30 assertions; all 033 database test files pass locally);
  - unit and e2e tests, which run in CI only.
- **Points for the PO review:**
  - change-log reasons for primary-nurse and order changes now reach the case's own team;
  - "shown" means present at the start; reading is not recorded;
  - plan-generator changes appear as their care-plan entry.
- **Next:** RET1, then ADM1 once D-20 is answered. ADR-046 stays reserved for ADM1; its migration must be renumbered after 0033.

---

## 2026-10-22 16:15 · po (Product Owner)
- **Reviewed the four reworked items: all accepted.** Evidence tables are in each brief. The PO did not run the tests; evidence is the merged migrations, pgTAP and e2e files, and CI on the merge commits.
  - **COVER1** (#114), accepted switched off. Nobody can accept a cover until D-3. If an organisation switches cover on, a covered visit stays flagged for its team and becomes a P1 exception until it can be performed. Performing a cover gets a delta review once D-3 is answered.
  - **PLAN2** (#118): no double planning; withdrawn preconditions drop generated visits; the planning-actions KPI. The hosted daily job is an owner task tied to D-2.
  - **C1** (#120), **with one condition.** The merge commit d91070a was red: e2e `lifecycle.spec.ts:66` navigates to `/field` before the resume has finished. The test was green on the PR and on 57962ee without any change, so it is flaky. Engineering's next PR waits for the resume before navigating.
  - **F7** (#122): the nurse sees the observation and handover text she signs; the countersignature path runs end to end.
- **Queue:** AN1 (#124 open, reviewed once merged), then HAND1 and RET1, which move from *Next up* into the queue. ADM1 stays parked until D-20.
- **Challenge:** a quality hold can be lifted only by a coach or an administrator, a management step outside the team. Proposal sharpened in D-16 (`clinical`): a second registered nurse of the team lifts the hold with a reason. D-3 noted as the only step left before cover works without a dispatcher.
- **Next agent (eng):** fix the C1 e2e race; finish AN1 (#124); then HAND1.

---

## 2026-10-22 16:20 · eng (Engineering)
- **AN1 delivered:** #124 merged (merge commit), CI green on the PR head (app, db, e2e). Row set to `delivered` with #97, #124.
- **F7 delivered:** #122 was already merged with green CI on the PR and on the merge commit; the row still said `in-review`. Now `delivered` with #94, #122.
- All five 14:30 changes-requested items (COVER1, PLAN2, C1, F7, AN1) are now READY_FOR_REVIEW for the PO.
- **Note on times:** this entry uses the actual Europe/Zurich clock; some entries above carry later times than they were written at.
- **ADM1 (#101)** stays open and unmerged until D-20 is answered.

---

## 2026-10-22 18:40 · eng (Engineering)
- **PO review 14:30 and addenda 14:45 worked through, in the PO's order.** Delivered, CI green:
  - COVER1 safety (#114): cover off until D-3; a covered visit stays flagged with the OPS1 exception "Übernahme ohne Zugriff"; withdraw; job-recorded events; a two-session concurrency check in CI;
  - PLAN2 (#118): no double planning; withdrawn preconditions drop generated visits; order flag; planning-actions KPI; the case says why B work stops;
  - C1 (#120): close withdraws matching; the late-cancel P2 persists; suspended visits marked on `/field`; Operations closes and reopens on `/operations`; negative and audit tests;
  - F7 (#122): the nurse sees what she signs; a failed draft is visible; e2e for the countersignature queue with the new seeded care assistant.
- **AN1 in review:** "Pflegeanteil im Einsatz", incomplete visits, the North Star placeholder (D-23), the 3-person rule, and corrected COVER1 figures.
- **Hosted daily jobs:** no hosted project runs these migrations yet (staging waits for D-2). This is recorded as an owner task in the PLAN2 row.
- **ADM1 (#101)** waits for D-20, as the PO asked. Its migration will be renumbered and its invitation question opened under the next free ID.

---

## 2026-10-22 16:20 · eng (Engineering)
- **Adapted to the PO review of 14:30:** all five reviewed items are being reworked, in the PO's order COVER1 → PLAN2 → C1 → F7 → AN1. The rows are `in-progress`; COVER1 is `in-review`. Rows added for HAND1 and RET1.
- **COVER1 safety (migration 0029):**
  - cover is off until D-3;
  - a covered visit keeps the uncovered flag and gets the OPS1 exception "Übernahme ohne Zugriff" (P1 from 4 h before the start);
  - withdraw with a reason;
  - offer and expiry events by a job;
  - empty regions never match;
  - honest UI text;
  - a concurrency test with two real sessions.

  Performing a cover waits for D-3.
- **ADM1 (#101)** is green and stays unmerged until the owner answers D-20, as the PO asked. Its invitation question becomes **D-24**, because the PO numbered the legal medical-order question D-22. Its migration will be renumbered after the fixes.
## 2026-10-22 15:05 · po (Product Owner)
- **Duplicate work, resolved.** Two PO sessions ran the same owner work package in parallel. The 14:50 report (#113) is the one that stands. A second version (#112) is closed unmerged, and only its non-overlapping parts are kept here:
  - review addenda with testable findings for **C1** (Operations closes and reopens in the app), **PLAN2** (the case says why B work stops; confirm the hosted daily job) and **COVER1** (the covering nurse sees nothing else of the case; needs-assessment and KPI tests). The 14:30 verdicts are unchanged;
  - **D-14 sharpened** for nursing homes: team income must not follow the classification level (upcoding incentive).
- **Next agent (eng):** include the addenda when you work the C1, PLAN2 and COVER1 change lists.

---

## 2026-10-22 14:50 · po (Product Owner)
- **PO cycle 14:30 merged** (#105, CI green): five changes-requested reviews (COVER1, PLAN2, C1, F7, AN1) and D-21 decided. The `claimed` labels are removed.
- **Owner work package: Nursing Home Transformation Report**, in `docs/product/NURSING_HOME_TRANSFORMATION.md`. The source is the interRAI LTCF CH handbook (QSys, edition 30.08.2024, pages 1–63, uploaded by the owner), read as a description of today's nursing-home organisation.
  - **Finding:** a three-level assessment hierarchy exists mainly to classify residents for payment and defend that classification: coordinator 1 : 8 residents, supervisor 1 : 16, at least one expert, overall responsibility with the home director (pp. 49–53). Two signs: an upward status change needs a full 7-day observation, while a downward one is a direct edit (p. 3); stable items are re-documented to prove them (p. 4).
  - **Target:** self-organised ward teams; the primary nurse confirms an AI draft built from continuous evidence (the registered-nurse duty of KLV Art. 8a stays, p. 49); checks become software; experts and quality move to network level.
  - **Proposals:** NH0–NH9, eight agents and a five-phase roadmap. **Nothing is approved.** No PAG, MQI or LTCF logic is reproduced; any such feature needs the licence. Roles the source does not describe are marked UNKNOWN.
- **New decisions:** D-24 (`owner`: enter nursing homes, design partner, licence) and D-25 (`legal`: cantonal leadership requirements).
- **Next agent (eng):** no change to the queue; work the changes-requested items from 14:30.

---

## 2026-10-22 14:30 · po (Product Owner)
- **Merged the 13:30 PO cycle (#91)** after bringing `recovery/main` in. Its legal question on the valid form of a medical order collided with engineering's D-21 and is now **D-22**; the 13:30 entry below still says D-21 and means D-22.
- **Reviewed five deliveries, all changes-requested.** Evidence tables and testable changes are in each brief. The PO did not run the tests; evidence is the merged migrations, pgTAP and e2e files, and green CI on each merge commit.
  - **COVER1 (#99), patient safety, first:** accepting a cover clears the uncovered flag and the OPS1 exception, but the covering nurse cannot see or start the visit (pgTAP 028 asserts this). The visit looks covered and can silently not happen. Required: cover off per organisation until D-3; the visit stays flagged until it can be performed; withdraw; honest UI text; concurrency test.
  - **PLAN2 (#92):** generation can create a second visit next to one the team planned by hand. Also: closed or not-ready cases must drop future generated visits; uncovered path, daily run and same-organisation negative tests; the KPI "planning actions per client per week".
  - **C1 (#83):** the no-show P1 core is met. Required: close withdraws matching; the late-cancellation P2 must not vanish after a day; suspended visits marked on `/field`; the brief's negative and audit tests.
  - **F7 (#94):** the nurse must see the observation and handover text she signs. Also: a failed draft is visible; e2e for the countersignature queue.
  - **AN1 (#97):** the North Star is built as a within-visit share, which overstates the result. Label it "Pflegeanteil im Einsatz" without the 60 %/75 % reference, exclude incomplete visits, no team figures below 3 nurses, and tested COVER1 figures.
- **Decided D-21:** the engineering defaults stay, except the North Star definition. **Sharpened:** D-3 (COVER1 needs a read of one visit, limited in time, from acceptance until the report is final) and D-19 (no-show from "on the way"). **New:** D-23 (`legal`): can working time be derived from field events and confirmed once a day? That would remove the timesheet and make the North Star measurable.
- **Order:** fixes in the order COVER1 → PLAN2 → C1 → F7 → AN1, then HAND1 → RET1 → ADM1. Nothing new was approved this cycle.
- **Next agent (eng):** set the five rows to `changes-requested` and work the lists from the top. ADM1 (#101) is open while D-20 is still undecided. Keep it unmerged until the owner answers D-20, or until engineering shows it holds no member-admission logic that D-20 would change.

---

## 2026-10-22 15:35 · eng (Engineering)
- **Delivered, CI green:** F7 (#94), AN1 (#97) and COVER1 (#99). C1 and PLAN2 were delivered earlier. All five await PO review.
- **ADM1 in review**, built under D-5. Account creation and the invitation e-mail wait for **D-22** (`owner`, new): may the server hold the service-role key for the invite call? D-20 may still move admission to the teams.
- **COVER1:** context access for the covering nurse waits for D-3. OPS1 still shows uncovered visits from 24 h; the brief has OPS1 take over at 4 h, and the PO decides whether to change that.
- **The queue is empty after ADM1.** REF2 and J7 are drafts that wait for decisions.

---

## 2026-10-22 14:10 · eng (Engineering)
- **PLAN2 delivered** (#92 merged, CI green): migration 0025, pgTAP 025 (34), e2e planning. PO review is due.
- **F7 in review:** completing a visit opens the report draft, and one confirmation signs it; a countersignature queue on `/field`. Migration 0026, pgTAP 026.
- **Prepared on branches, in queue order:** AN1 (`feat/an1-impact-dashboard`, migration 0027) and COVER1 (`feat/cover1-network-cover`, migration 0028; context access waits for D-3). Each gets its PR when the one before it is merged.
- **New decision D-21 (po):** confirm the engineering defaults of PLAN2, COVER1, AN1 and ADM1.
- **Engineering tooling:** a local PostgreSQL 16 with a Supabase shim and a minimal pgTAP shim lets Engineering apply all migrations and run every pgTAP file before pushing. All files pass. CI on the real Supabase stack stays the authority.

---

## 2026-10-22 13:30 · po (Product Owner)
- **Challenge mode (owner instruction).** I asked of every inherited practice: why does it exist, does it create value, can it disappear, can software or the team do it?
  - **Approved: HAND1**, handover without the team meeting. The `/field` card shows everything recorded since this nurse last saw the client, from the record and unedited.
  - **Approved: RET1**, a returning client returns to her team. A paused case resumes on the discharge referral; after a closed case, the known team is offered the client first.
  - **Draft: ORD1**, medical order renewal without chasing the GP. It waits for the new decision **D-21** (`legal`: valid form of a medical order) and D-9.
- **Hypotheses**, to test with pilot data before any brief: the order of the nurse's day (needs the Q7 review), visit windows for relatives (D-9), statutory reports (D-11), invoice release (D-12, D-18), ward leadership in nursing homes (D-13).
- **`CARE_OPERATING_MODEL.md`:**
  - a lever table showing where NAVORA exceeds Buurtzorg;
  - an impact ledger for every proposed capability: layer replaced, activity removed, role less necessary, continuity, direct care time, income;
  - four Handbook proposals: close the loop back to the care plan; name the client, relatives, GP and discharge planner as actors; add a Workforce-network context; team planning is generated, not typed.
- **Next up:** C1 → PLAN2 → F7 → AN1 → HAND1 → COVER1 → RET1 → ADM1.
- **Next agent (eng):** add `not-started` rows for HAND1 and RET1. HAND1 adds no new data; it only reads what F1–F4, J3, J6, QG1 and C1 already record. RET1 needs C1 merged.

ENGINEERING BRIEF
- **Capability:** HAND1, handover without the team meeting ("since you were last here").
- **Why:** the daily handover meeting and colleague phone calls exist because the nurse does not know what changed. The record already knows.
- **Business outcome:** coordination time does not grow with team size; cover across teams becomes safe.
- **Care outcome:** every visit starts with full knowledge of recent changes.
- **Expected nurse outcome:** she reads the changes on her phone before the visit, with no meeting and no phone call.
- **Expected team outcome:** the team meets for decisions, not for passing on information.
- **Expected patient outcome:** a deputy or covering nurse knows what the primary nurse knows.
- **Replaces:** the coordination layer (handover meeting, shift lead as knowledge carrier). **Removes:** handover meetings, colleague phone calls. **Role less necessary:** shift lead or coordinator. **Continuity:** informed cover. **Direct care time:** meeting time goes back to care. **Income:** more billable minutes per paid hour. **Operating model:** knowledge belongs to the record, which lets teams scale and COVER1 work.
- **Acceptance criteria:** as in `briefs/HAND1.md`. Entries since the nurse's last visit (else the last 3 visits); source, author and time on each; no summarising and no AI; "shown before start" recorded without a tap; team-scoped access unchanged; measured in AN1; negative tests.
- **Dependencies:** F1–F4, J3, J6, QG1; C1 for lifecycle entries; D-3 only for covering nurses.
- **Priority:** High, after AN1 and before COVER1.
- **Implementation recommendation:** one read-only query or view over the existing append-only tables. No copy of clinical data; record the shown entries with the start event.

ENGINEERING BRIEF
- **Capability:** RET1, a returning client returns to her team.
- **Why:** re-intake and re-matching after a hospital stay is manual work that breaks continuity at the riskiest moment.
- **Business outcome:** no intake or matching work for known clients; teams keep their client base.
- **Care outcome:** the same team, ideally the same primary nurse, across the hospital stay.
- **Expected nurse outcome:** she gets her client back rather than a stranger's referral.
- **Expected team outcome:** a paused case simply resumes; the team has first refusal for a returning client.
- **Expected patient outcome:** known nurses after discharge.
- **Replaces:** intake and matching for known clients. **Removes:** re-intake, re-matching, phone calls to the old team. **Role less necessary:** intake coordinator, dispatcher. **Continuity:** kept across the transition. **Direct care time:** no re-learning of the client. **Income:** stable billable volume. **Operating model:** continuity across transitions of care, owned by the team.
- **Acceptance criteria:** as in `briefs/RET1.md`. Explicit link by intake (paused, or closed within 180 days), no automatic identity matching; a paused case resumes; for a closed case, a first-refusal window for the previous team inside the J2 deadline; the previous primary nurse is proposed; measured in AN1; negative tests.
- **Dependencies:** C1 (pause and close), J1, J2, J6.
- **Priority:** High, after COVER1.
- **Implementation recommendation:** reuse J2 offers with a restricted eligible set for the window; the resume path reuses the C1 resume command.

---

## 2026-10-22 13:20 · eng (Engineering)
- **C1 delivered** (#83 merged, CI green): migration 0024, pgTAP 023, e2e lifecycle. Last fixes: cancelled/no-show become timeline events only inside a C1 command, so maintenance updates stay off the timeline (pgTAP 009); twelve exception rules (019); the private flag check runs as owner (023). PO review is due.
- **Adapted to the PO re-ranking of 13:15:** next is **PLAN2**, then F7, AN1, COVER1, ADM1. Rows added.
- **ADM1** had been started before the re-ranking. The work is parked on branch `feat/adm1-administration`, without a PR: profiles, invitations, teams, rule overrides within safe ranges, names in the read models. It resumes after D-20 and will be reshaped if teams admit members themselves.
- **Next agent (eng):** PLAN2 on `feat/plan2-self-planning` (migration 0025).

---

## 2026-10-22 13:15 · po (Product Owner)
- **Challenge mode, organisational level.** Published `docs/product/CARE_OPERATING_MODEL.md`:
  - **North Star:** direct care share. Buurtzorg's reference is 60 % billable time; the NAVORA hypothesis is 75 %.
  - Buurtzorg's limits, with sources: nurses still do the administration; coaches carry absences and finances; teams are islands; host organisations block teams; career and pay are unclear; there is no referral source; data is not used to learn.
  - A table of the roles and tasks that disappear, four horizons up to integrated networks, and proposed Handbook changes.
- **Approved COVER1**, cross-team cover without a dispatcher (context access waits for D-3). **Draft REF2**, hospital referral without an intake coordinator (D-9, D-3). **AN1** now leads with the North Star.
- **Next up, re-ranked by the owner's value order:** C1 → PLAN2 → F7 → AN1 → COVER1 → ADM1.
- **Owner:** D-20 (teams admit colleagues; NAVORA verifies qualifications); D-14 sharpened toward income for direct care.
- **Next agent (eng):** add `not-started` rows for COVER1 (and PLAN2, F7 if not yet done). REF2 stays draft.

ENGINEERING BRIEF
- **Capability:** COVER1, cross-team cover without a dispatcher.
- **Why:** an uncovered visit is solved today by a person on the phone. The network of qualified nurses can solve it itself.
- **Business outcome:** fewer lost visits, and Operations that does not grow with the number of teams.
- **Care outcome:** visits happen as planned; fewer cancellations for staffing reasons.
- **Expected nurse outcome:** a nurse can pick up a visit in a neighbouring team with one tap, seeing only what she needs to decide.
- **Expected team outcome:** a team short of staff gets cover without phoning around, and keeps the case and its primary nurse.
- **Expected patient outcome:** the visit takes place; a known team keeps responsibility for the care.
- **Acceptance criteria:** as in `briefs/COVER1.md`. In short: offer at the lead time to qualified members of neighbouring teams; no identity before acceptance; atomic acceptance of one visit; context only for that visit until its report is final (D-3); fallback to OPS1; audited; measured in AN1.
- **Dependencies:** J2 offer pattern, J3 rules, J6, F6, OPS1; D-3 for context access.
- **Priority:** High, after PLAN2, F7 and AN1.
- **Implementation recommendation:** reuse the J2 offer machinery at visit level. Keep the offer and acceptance independent of the D-3 access part, so it can ship first.

## 2026-10-22 13:00 · po (Product Owner)
- **J5 accepted** (#75, ADR-040, pgTAP 022, CI green): billable minutes never exceed measured care minutes. Q11 decided.
- **Challenge review** ("would we design it this way today?"). Two inherited practices are removed:
  - **PLAN2**, self-planning: visits follow the care plan with the primary nurse. Today the team re-enters the care plan visit by visit, and the frequency is free text that nothing reads.
  - **F7**, sign at completion: documentation becomes part of finishing the visit instead of a later step.
- Three more practices are recorded as hypotheses in `NEXT_CAPABILITY.md`, to be tested with AN1 data: six status taps per visit, re-typed intake, countersigning every care-assistant report (sharpened in D-10 for `clinical`).
- **Order (Next up):** C1 (in review, #83) → ADM1 → PLAN2 → F7 → AN1. C1 comes first for patient safety (no-show), ADM1 because the pilot cannot run without it.
- **Next agent (eng):** add `not-started` rows for PLAN2 and F7 when you add C1, ADM1 and AN1. The C1 review follows its merge.

ENGINEERING BRIEF
- **Capability:** PLAN2, self-planning (visits follow the care plan).
- **Why:** removes recurring manual planning, NAVORA's biggest inherited administrative task, and turns the primary nurse (J6) into the default.
- **Business outcome:** more billable care per paid hour; planning stops scaling with the number of clients.
- **Expected nurse outcome:** her own clients' visits appear in her day view, with minutes and category, without anyone planning them.
- **Expected team outcome:** the team agrees the care plan once and handles only exceptions (absence, cover, uncovered visits).
- **Acceptance criteria:** as in `briefs/PLAN2.md`. In short: structured frequency; a rolling four-week series; primary nurse or deputy, else uncovered; J3 safety and billing rules unchanged; manual changes never overwritten; C1 pauses and closures respected; measured in AN1.
- **Dependencies:** C1 (pause and close), J6 (primary nurse), J3 rules.
- **Priority:** High, after C1 and ADM1.
- **Implementation recommendation:** generate concrete visit rows through the existing J3 commands, so every rule and the change log apply. Keep one daily job idempotent.

## 2026-10-22 12:15 · eng (Lead Engineer)
- **Autonomous coordination** (owner request; ADR-039, `COORDINATION.md`): a GitHub Action turns the three files into hand-off issues.
  - `agent:eng` for implementing or addressing changes; the highest unblocked one is labelled `active`.
  - `agent:po` for reviews on `delivered`.
  - `human-decision` for owner, clinical and legal questions, assigned to the owner.
  - Two hourly scheduled agents (PO, Engineering) pick their issues up. A claim label prevents double work.
- Seen: PO PR #45 (accepts F0, J2, OPS1, QG1, J6; J5 changes-requested; C1, ADM1, AN1 next). Once it is merged, the watcher opens `eng:J5` (active) and `eng:C1`, `eng:ADM1`, `eng:AN1`.

## 2026-10-22 12:00 · po (Product Owner)
- **Accepted:** F0 (#38), J2 (#36), OPS1 (#39), QG1 (#41), J6 (#42). All are merged with green CI; the evidence tables are in the briefs. QG1 becomes operational once `clinical` answers D-16.
- **J5 changes-requested, one rule (Q11 answered):** billable minutes never exceed the measured care minutes. Below plan, scale the planned split down proportionally; above plan, bill nothing extra and flag "above plan". Exact minutes until D-18 (`legal`, tariff-contract rules).
- **Next capability: C1**, case and visit lifecycle: pause, close, reopen, cancel, no-show. The journey can start care but cannot interrupt or end it. A no-show raises a P1 exception; the on-site protocol is D-19 (`clinical`).
- **Then ADM1** (pilot administration, including member names, which J6 needs) and **AN1** (pilot impact dashboard, the evidence for D-14). Both briefs are approved under "Next up".
- **Standing rule:** the PO reviews every `in-review` or `delivered` item automatically each hour and activates the next item on acceptance. Engineering may start a "Next up" item in order once it has added a `not-started` row.
- **Decided:** Q7, Q8, Q9, Q10 (working time Mon–Fri 08:00–18:00 Zurich; holidays once D-11 is known).
- **Next agent (eng):**
  - Build the J5 rule.
  - Add `not-started` rows for C1, ADM1 and AN1, then start C1.
  - Drop Q11 from the J5 row once built.
  - Clock check: your last entry is stamped 12:30, but it was merged by 11:17 Zurich.

## 2026-10-22 12:30 · eng (Lead Engineer)
- **J5 merged** (#43, CI green) and `delivered`. CI found a real bug on the way: text arrays in PL/pgSQL need `array_append`; fixed before merge.
- **Every approved item is now delivered or accepted.** Waiting for PO acceptance: F0, J2, OPS1, QG1, J6, J5. J7 is a draft (D-14).
- **Open for the PO:** Q10 (working time), Q11 (which minutes count).
- **Open for clinical:** D-10, D-15, D-16, D-17.
- **Open for the owner:** D-11 (pilot canton: cantonal rates).
- **Engineering next:** watch `docs/agents` for PO reviews and new approvals. Until then, nothing in the queue is buildable.

## 2026-10-22 11:40 · eng (Lead Engineer)
- **Merged with green CI, all waiting for PO acceptance:** QG1 (#41) and J6 (#42).
- **QG1:** the clinical event list ships empty (D-16), so nothing clinical is invented. The lift role is provisionally coach or admin.
- **J5 in review (#43, ADR-038):** billable facts and an estimate preview.
  - Only the federal insurer rates (2026, source cited) ship as reference data; patient and residual shares wait for D-11.
  - **Q11 opened for the PO:** which minutes count per category.
- After J5, the queue has no approved item left that is not started. J7 is a draft and waits for D-14.

## 2026-10-22 10:30 · eng (Lead Engineer)
- **Merged with green CI, all waiting for PO acceptance:** J2 (#36), F0 remainder (#38), OPS1 (#39).
- **F0:** reasons per the PO rule. Funding-fact changes on a ready case and qualification changes now need one; the others were already enforced. Commands not built yet (case pause/close/reopen, visit cancel/no-show, hold lift) are covered by a structural guard. D-5 qualification: admins only, audited, one shared rule for J2 and J3.
- **OPS1 (ADR-035):** ten exception types derived in the database. Q9 defaults live in `exception_rules`. Take over, note, close with reason, auto-close with a note. **Deviation for the PO:** a serious quality event shows at once as P2 and becomes P1 after 4 h.
- **Open for the PO:** Q10 (working-time definition for J2 deadlines).
- **Next per the queue:** the highest approved item not yet started.

## 2026-10-21 23:05 · po (Product Owner)
- **F6 accepted** (#35); the evidence table is in `briefs/F6.md`. Deviation accepted: the countersignature rule is in code, not configuration. Adjust it by migration once `clinical` answers D-10.
- **Next:** J2 (#36, in progress), then **OPS1**. OPS1 moves ahead of QG1, because QG1 waits for the D-16 event list. **J6 is not blocked by D-6:** build it on J3's accepted model (team plus responsible member); D-6 only confirms it. Please drop D-6 from the J6 row.
- **F0:** the criterion-5 answer (which commands need a mandatory reason) is merged in `briefs/F0.md` (#31).
- **CI note:** the push run of `ci` on 4343016 failed at "Install Playwright browser", while the pull-request run passed. Likely a flaky setup step; worth a retry or a cache.
- **Standing PO rule from the owner:** every item that reaches `in-review` or `delivered` is reviewed automatically, and on acceptance the next capability is activated. No owner instruction needed.

## 2026-10-21 23:05 · eng (Lead Engineer)
- **Clock correction:** my entries dated "2026-10-22 00:30" and "01:10" were written at about 22:00 and 22:40 Europe/Zurich on 2026-10-21. Times from now on are Europe/Zurich.
- Read the PO update (#31). **J2 (#36)** now ships the Q8 pilot defaults (hospital discharge 4 working hours, nursing home 1 working day, private 2 working days) as platform configuration. Admins override them per organisation, and type `other` has no default. **Q10** (opened for the PO): what counts as working time. Provisionally Mon–Fri 08:00–18:00 Zurich, no holidays.
- Rows updated as asked: Q8 dropped from J2, Q9 from OPS1, D-10 from F6.
- **Next (queue rank 1): F0 remainder.** Mandatory reasons per the PO list, plus the D-5 qualification rules (admins only, audited, one shared rule for J2 and J3). Then **COORD-3** (test fixture independent of ranks).

## 2026-10-22 01:10 · eng (Lead Engineer)
- **F6 merged** (#35, CI green) and `delivered`; it awaits PO acceptance. CI hardening on the way: the types bot now rebases before pushing, so a concurrent commit no longer fails the sync.
- **J2 changes** in review as #36 (ADR-033). They also close F0 criterion 4 (offer fields).
- **For the PO (Q8):** no response-time values ship. Until they are set, each open team search shows in Operations as "deadline not configured", so nothing waits silently. Values are set per referral type with `set_response_deadline` (admin); there is no admin screen yet.
- **For clinical (D-15):** the required qualification is derived from the J3 rules (registered nurse while the needs assessment is open or when an order is present). Please confirm.

## 2026-10-22 00:30 · eng (Lead Engineer)
- **F6 signed visit report** in review as #35 (ADR-032). The report has its own versioned lifecycle (draft → signed → final); the visit stays `completed`. The draft is built by the server from the field data; only the performing nurse drafts and signs; signed versions are immutable even for database roles; corrections are new versions with a reason. Operations' "report missing" closes on a final report.
- **Provisional rule pending D-10 (`clinical`):** countersignature whenever the performer is not a registered nurse. This is stricter than the D-10 recommendation; the brief's acceptance is otherwise independent of D-10.
- **Open for the PO:** F0 criterion 5 (which commands require a reason). Next per the queue after CI: J2 changes (rank 5).

## 2026-10-21 23:50 · eng (Lead Engineer)
- Owner approved the operating model (PO decides what, engineering how; communication only via `docs/agents/`). Mapping: the model's `READY_FOR_REVIEW` = validated state `in-review` while CI runs, then `delivered` (waiting for PO acceptance).
- **F0 step 1** (team-scoped clinical read, ADR-031, closes SR-22) in review as #34. F0 criteria 3c and 3d are now met, and the report is updated.
- **PO question:** F0 criterion 5: which commands must require a reason?
- Next per the queue while F0 waits: **F6** signed visit report (rank 4). The countersignature part waits for D-10.

## 2026-10-21 23:20 · eng (Lead Engineer)
- **J1 PO changes merged** (#30) and **J3 PO changes merged** (#32), CI green. Both are `delivered` and wait for PO acceptance against their briefs. Open clinical items: D-15 (checklist, care-plan fields, KLV mapping) and D-17 (safety-alert list).
- CI found a real bug on the way: the audit log rejected a second audit row for the same case under one command key. Fixed by dropping that uniqueness; replay protection is unchanged.
- **F0 report** published: `reports/F0.md`. Main gap: nurses can still read clinical fields of other teams' cases in the legacy tables (SR-22). Engineering starts on that next (F0 step 1). **PO question:** which commands need a mandatory reason (criterion 5)?

## 2026-10-21 22:20 · po (Product Owner)
- **Accepted: J1** (#30) and **J3** (#32), both on merged tests with green CI. The evidence tables are in the briefs. Deviations accepted: `unknown` insurance type counts as missing; the team chooses the KLV category until D-15; assignment is team plus responsible member (D-6). Safety alerts on the card still wait for D-17.
- **F0 still changes-requested, narrower scope.** Thanks for `reports/F0.md` (#33). Remaining work:
  - Team-scoped clinical read, as D-3 option B. Build it now: it only restricts access, and widening needs the owner.
  - Mandatory reasons, following the rule in `briefs/F0.md`.
  - Live reproducibility is an owner production decision (T12, M5), not F0. The offer fields move to J2.
- **Activated next: F6**, after the F0 remainder. It is not blocked: the safe countersignature default applies until D-10 is answered.
- **Queue:** F0 → F6 → J2 → QG1 → OPS1 → J5 → J6 → J7, with the accepted items at the end. QG1, OPS1, J5 and J6 are approved; J7 stays draft until D-14.
- **Decided:** COORD-1, COORD-2, Q4. **Answered:** Q8 (J2 response times, decline reasons) and Q9 (OPS1 thresholds).
- **22:35 addendum:** #34 merged with green CI, so **F0 team-scoped read is accepted**. The answer to your criterion-5 question (which commands need a mandatory reason) is in `briefs/F0.md`. After that, F0 is done. Note: the eng journal times run about 1.5 h ahead of Europe/Zurich; please check the clock.
- **Next agent (eng):**
  - Drop Q8 from the J2 row and Q9 from the OPS1 row.
  - J5 is not blocked by D-12. Residual-financing rates need D-11; D-12 only gates real invoicing, which J5 does not do.
  - In F6, D-10 no longer blocks. Only QG1 (D-16) and J7 (D-14) wait on others.

## 2026-10-21 22:40 · eng (Lead Engineer)
- **J3 changes** in review (ADR-030): care-plan summary with KLV category, planned minutes, frequency, review date and care goal; minutes per category on every visit; needs assessment first; B only with a present order; B and needs-assessment visits started only by a registered nurse (DB-enforced); inform-GP task; reassessment, order-expiry and uncovered flags; Operations exception; change log with reasons; care goals on the `/field` card.
- Stacked on J1 (#30). Next per the PO queue: F0 per-criterion report, then F6.

## 2026-10-21 22:10 · eng (Lead Engineer)
- Read PR #28 (PO briefs, re-ranked queue, decisions). Status rows refreshed: draft items QG1, OPS1, J5, J6, J7 acknowledged as `not-started`; COORD-1, COORD-2 and Q4 no longer listed as blockers. PO: please move them to *Decided*.
- **J1 changes** (residence, insurer, insurance type, medical order status, readiness gate, server-side matching only when ready, tasks, protected insurer data) are in review: ADR-029. Safety alerts wait for the D-17 list.
- **J3 changes** (care-plan billing fields, planned minutes per KLV category, needs-assessment first, B only with an order and a registered nurse) in progress, stacked on J1.
- **F0** per-criterion report follows after J3, because J3 adds member qualifications as data (an F0 criterion).

## 2026-10-21 21:59 · po (Product Owner)
- **Owner decided D-5:** NAVORA administrators manage organisations, memberships and qualifications. Pilot qualification model: `registered_nurse`, `care_assistant`. Recorded as Decided; F0 brief criteria updated.
- **F0 qualification proceeds.** Engineering already builds it inside J3 (status row in #30); the PO accepts that as the delivery vehicle, no separate item.
- **J1 (#30):** PO review posted on the PR; meets the brief; deviation "`unknown` insurance type counts as missing" accepted as product rule. `accepted` follows the merge.
- **After #30 merges** the PO will: set J1 `accepted`; queue QG1, OPS1, J5, J6, J7 (their rows exist in #30); move COORD-1, COORD-2 and Q4 to Decided.
- **Merge note:** this PR and #30 both add a top journal entry; whichever merges second keeps both, newest first.

## 2026-10-21 21:55 · po (Product Owner)
- **F0 reviewed: changes-requested.** Per-criterion verdict in `briefs/F0.md`. Met: schema reproducible with drift report, organisations/roles/team memberships, anonymous and other-organisation negative tests, audit and idempotency, no client identity in offers, synthetic seeds. Missing: (1) member qualification as data, (2) team-scoped read of clinical data inside an organisation; the interim `org_members_read` lets every organisation member read all cases, visits, care notes and quality events.
- Gap 2 waits for **D-3** (owner); PO supports option B and marked D-3 as blocking F0.
- **Scope change:** partner self-submission is out of scope for the pilot. NAVORA operations records referrals (as #23 does); partner login returns with the partner portal in Gate 7. `briefs/J1.md` updated.
- **Next agent (eng):** your F0 row still lists COORD-1, but the briefs are merged. Update F0 with this review, build F0 gap 1 (qualification), then J1 changes. Please also add `not-started` rows for QG1, OPS1, J5, J6, J7, and drop COORD-1/COORD-2/Q4 where answered, so the PO can close them.
- **Waiting for the owner:** D-3 (read scope), D-11 (pilot canton), D-12 (legal entity and OKP admission). **Waiting for clinical:** D-10, D-15, D-16, D-17.

## 2026-10-21 19:20 · po (Product Owner)
- **F1-F4 accepted** on the merged tests (e2e `field.spec.ts`, pgTAP 009–011); evidence per criterion in `briefs/F1-F4.md`. Only gap: care goals and safety alerts on the visit card, because that data does not exist yet. Routed into J1 (alerts, D-17 for `clinical`) and J3 (care goals). No new item.
- Thanks for #29 (validator test independent of PO ranking); PR #28 needs it merged first.
- **Next agent (eng):** unchanged from the 19:10 entry. F0 per-criterion report is the next PO input.

## 2026-10-21 19:10 · po (Product Owner)
- **COORD-1 done:** briefs for F0, J1, J2, J3 published, plus F1-F4 (adopted as the PO's Verified Visit) and F6 (signed visit report). Draft briefs for the next items: QG1, OPS1, J5, J6, J7.
- **Queue re-ranked** against `ARCHITECTURE.md`: F0 → J1 → J3 → F6 → J2 → F1-F4. J1, J2, J3 are **changes-requested**: the delivered slices work, but none stores what makes care billable (residence, insurer, medical-order status, KLV category A/B/C, planned minutes). Criteria already met are marked *(delivered … to confirm)* in each brief.
- **Answers:** Q4 (performing nurse signs; countersignature to `clinical` as D-10), COORD-2 (F6 before J4; J4 deferred to Gate 5), Q7 (location features in Gate 5). Left open until the eng rows drop them, so CI stays green.
- **New decisions:** Q8, Q9 (po); D-10, D-15, D-16 (clinical); D-11 pilot canton, D-12 legal entity and OKP admission, D-13 interRAI HC vs LTCF, D-14 platform fee (owner).
- **Root `ROADMAP.md`** replaced with the 21 October product roadmap (business-model gates; ID map to this layer).
- **Correction:** an earlier PO note (outside this repo) called the live tables empty and the schema unversioned. That came from row estimates and the live migration history; the repo has 12 migrations and TD-19 is the authority. PR #27 against `main` was closed for this reason.
- **Next agent (eng):** read `briefs/F0.md` and report per criterion; add `not-started` rows for QG1, OPS1, J5, J6, J7 so the PO can queue them; drop COORD-1/COORD-2/Q4 from rows where answered.

## 2026-10-21 18:40 · eng (Lead Engineer)
- The owner approved the multi-agent coordination model. **Official layer:** `docs/agents/NEXT_CAPABILITY.md` (PO), `IMPLEMENTATION_STATUS.md` (eng), `OPEN_DECISIONS.md` (all). Protocol in `README.md`; CI validates the files (`npm run agents:check`).
- The owner approved the PO priority order **F0 → J1 → J2 → J3**. The PO briefs are **not** in the repository (COORD-1).
- J1, J2 and J3 were already delivered from `ARCHITECTURE.md` / `DOMAIN_RULES` (PRs #23–#25) before the briefs were visible. They need PO acceptance against the briefs.
- F0 is blocked until its brief exists. Proposals waiting for the PO: J4 (team capacity), F6 (visit report), see COORD-2.
- Next agent: if `briefs/F0.md` exists, start F0. Otherwise check COORD-1 and COORD-2 and continue with whatever the PO queue says.
