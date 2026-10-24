---
id: ADM1
title: Pilot administration — members, qualifications and operating rules
author: po
status: approved
updated: 2026-10-24
---

# ADM1 — Pilot administration: members, qualifications and operating rules

## PO acceptance — 2026-10-24 09:12: accepted (ADM1-R1 to R6 met; CGR-39 remedy met in code)

Reviewed #268 (head `d2e9b74`, merged as `c1bd8cb`): migration 0059, pgTAP 061 (49 assertions) and the changed 035 and 045, `src/features/admin/rules.ts`, `admin-client.tsx`, unit `admin-rules` and e2e `admin.spec.ts`, ADR-072, remediation plan `clinical/remediation/CGR-39.md`. CI read through the API: green for app, db (migrations, seed, pgTAP) and e2e on the head (run 40070559456), on the merge commit (runs 40070955122, 40070952402) and on the current `recovery/main` `f35ab63` (runs 40072166088, 40072162324). **The PO did not run the tests.**

| Criterion | Result | Evidence |
|---|---|---|
| ADM1-R1 direction per rule; no amount-bearing rule without one | met | 0059 §1: `amount_direction`, constraint `exception_rules_amount_has_direction` (`(amount is null) = (amount_direction is null)`); look_ahead for `visit_uncovered_hospital`, `visit_uncovered`, `order_expiring`, `team_cancellation_late`, `cover_without_access`; delay for `case_not_ready`, `report_not_final`, `visit_overdue`, `visit_stuck`, each with the reader line; pgTAP 061 lines 20-31 (list, count 0, two refused inserts) |
| ADM1-R2 never later than the default; stricter allowed within an engineering bound | met | `private.exception_rule_range` (look_ahead: default to min(4×, 720); delay: floor 0, `visit_stuck` 1, up to the default); one check `private.exception_override_in_range` used by `set_exception_rule` and the reset; priority and escalation unchanged; pgTAP 061 lines 58-88 |
| ADM1-R3 existing overrides reset, audited, count stated | met | `private.adm1_reset_out_of_range_overrides` (delete plus one `audit_events` row `adm1_range_reset` with the old values), NOTICE with the count; PR: 0 on `db reset` (the seed has no override); pgTAP 061 lines 123-136 (2 found in a fixture, audited, idempotent, not executable by `authenticated`) |
| ADM1-R4 pgTAP matrix and behavioural test; 035:191-196 replaced | met | every value of the brief's matrix in 061 lines 58-84 (plus `cover_without_access`, `visit_overdue`, `case_not_ready`, 4× caps); behavioural: no P1 with the default, P1 with an accepted 48 h override for an unassigned visit in 36 h after a hospital discharge (061 lines 36-51 and 107-112); 035 diff replaces the inverted assertions, plan stays 67 |
| ADM1-R5 `/admin` text per rule, tested | met | `RULES_INTRO` keeps "Sicherheitsausnahmen melden sich nie später als der Standard"; `stricterHint` ("Früher melden = mehr … Vorlauf" / "weniger … Wartezeit"); range shown as "min bis max"; e2e: `order_expiring` 3 is refused with "zwischen 7 und 28", the hint and the general rule |
| ADM1-R6 read model unchanged otherwise | met | `derived_exceptions`, `operations_exceptions` and every default unchanged; `effective_exception_rules` re-created only for the row type (same rows, direction appended); CI green on every pgTAP file without other edits except 045 (AN2-C1 fixture, below) |
| `cra` remedy for CGR-39 (section 06:30, #259 head) | met in code | each remedy point: no look-ahead override below the default (0 included); higher allowed under a cap; delay rules never above the default; audited reset; `/admin` text; the named pgTAP values; inverted 035 assertions replaced |
| Clinical gate | met with condition **ADM1-G1** | see below |

**Deviations, decided:**
1. `cover_without_access` is look-ahead (the brief said "delay for every other"): **accepted**; Engineering is right, the reader (0029:259-261) is a window ahead, and "delay" would have repeated the inversion. The brief was wrong.
2. `visit_stuck` floor 1 h, not 0: **accepted**; at 0 every visit in progress would be stuck at once. Its default is 1 h, so no override is possible today (range 1 to 1); that is intended.
3. Unit and e2e threshold tests updated: **accepted**; they asserted the inverted range.
4. pgTAP 047 still inserts a 48 h `report_not_final` override directly as table owner, a value the command now refuses: **accepted for now** (R6 asked for no edits). **ADM1-M1 (non-blocking):** the next PR that touches 047 changes that fixture to a value inside the range, or states in the file why an out-of-range row is needed. No user path can write the table (RLS: `authenticated` has select only, 0035:515-518).
5. `database.types.ts` edited by hand: **accepted**; db-types-sync may regenerate it.

**AN2-C1 met** (same PR): the red `db` job was pgTAP 045 test 14, a fixture that was not unique between 07:50 and 08:00 Zurich (seed visit 501). The reader is unchanged; the fixture moves the case's other planned visits a week ahead and a new precondition assertion proves no other planned visit precedes "next" at any hour. No assertion was weakened.

**Clinical gate (why accepted before the `cra` re-review).** The README gate asks the PO to consider the latest report before acceptance; it does not require a second `cra` cycle. The PO checked 0059 against every remedy point `cra` wrote for CGR-39, and all are met. Waiting for a further review cycle while the fix is merged and green is the serial hand-off this team challenged before (challenge row "A clinical gate review held as a separate cycle after merge"). The 07:10 sentence "the PO accepts after the `cra` section closes CGR-39" is replaced by: **ADM1-G1:** `cra` confirms CGR-39 closed on 0059 in its next section; if it names a remaining blocking gap, ADM1 returns to `changes-requested` with that gap as the criterion.

**Business value and care model.** A setting can no longer silence a safety signal; it can only bring it forward. The administration screen keeps no power to weaken what a team relies on. Alignment with the Handbook: safety rules stay server-side, one check function, audited changes. The challenge row of 07:10 (the override screen may go entirely if no organisation uses it) stays open for pilot data.

**SIG1-9:** its range part is now met by ADM1-R; what remains for SIG1 is only "every signal reads its threshold from `effective_exception_rules`".

## PO review — 2026-10-24 07:10: `changes-requested` (CGR-39, blocking S1): the override range is inverted for look-ahead rules

**Why.** The Clinical Governance Report section 2026-10-24 06:30 (`cra`, open PR #259) found **CGR-39 (blocking, S1)**. The PO checked it against the code on `recovery/main` @ `f77cb08` and confirms it: `private.exception_rule_range` (0035:526-536) treats every amount as a **delay** (larger = later) and `public.set_exception_rule` (0035:577-583) accepts any amount from **0** up to that maximum. Four rules are **look-ahead windows**, where a *smaller* amount means a *later* signal: `visit_uncovered_hospital` (P1, 24 h; window `between now() and after_threshold(now(), amount)`, 0019:175-178), `visit_uncovered` (P2, 24 h, same window), `order_expiring` (P3, 7 days, 0024:492, 501) and `team_cancellation_late` (P2, 24 h, 0024:543-546). An organisation administrator can therefore set the **P1 hospital-discharge rule to 0 h**, and the P1 signal for an unassigned visit after a hospital discharge **never fires**; a stricter value (e.g. 48 h) is refused. pgTAP 035:191-196 asserts this inversion ("it can come earlier" for 12 h), and the `/admin` text promises the opposite. ADM1 was accepted on 2026-10-23 07:10 with this defect; the PO's acceptance missed it. Patient safety is a precondition, so ADM1 goes back to Engineering **ahead of AN2 part 3** (ADM1 ranks above *Next up*; the watcher makes it the active hand-off). The PO's own SIG1-9 (2026-10-24 06:10) repeated the inversion for `visit_uncovered`; SIG1-9 is rewritten and its delay-rule part moves here, so the range is fixed once, in one migration.

No clinical value is set by any criterion below: each only removes an engineering range that no clinician approved (D-28). Synthetic data only; the live database is not touched.

**Acceptance criteria (each testable):**
- [x] **ADM1-R1 Direction per rule.** Each amount-bearing exception rule carries a server-side direction: `look_ahead` (larger = earlier signal) for `visit_uncovered_hospital`, `visit_uncovered`, `order_expiring`, `team_cancellation_late`; `delay` (larger = later signal) for every other amount-bearing rule (`visit_overdue`, `visit_stuck`, `report_not_final`, which also times `report_correction_open` (CR-053), `case_not_ready`, and any further one Engineering finds; the PR lists every rule with its direction and the line that proves it). A new amount-bearing rule without a direction cannot be inserted (constraint or pgTAP over the whole table).
- [x] **ADM1-R2 Never later than the default.** Until the Clinical Owner approves a band (D-28), `public.set_exception_rule` returns `out_of_range` for any override that makes a signal later than the platform default: for `look_ahead` an amount **below** the default (0 included); for `delay` an amount **above** the default. A stricter amount stays `ok` within an engineering bound: for `delay` rules down to 0 where 0 means "immediately" in that rule's query, else down to 1 (Engineering states it per rule); for `look_ahead` rules up to 4× the default (a bound against alert floods, not a clinical value). Priority may not be lowered (as today); the escalation hours of `quality_serious_open` stay "never later" (as today).
- [x] **ADM1-R3 Existing overrides.** A migration lists every existing organisation override that R2 would refuse and resets it to the platform default, with one audit row per reset naming the old value (expected none on synthetic data; the PR says how many).
- [x] **ADM1-R4 pgTAP (replacing 035:191-196, the inverted assertions).** `visit_uncovered_hospital` P1: 12 → `out_of_range`, 0 → `out_of_range`, 48 → `ok`; `visit_uncovered`: 0 → `out_of_range`, 36 → `ok`; `order_expiring`: 0 → `out_of_range`, 3 → `out_of_range`, 14 → `ok`; `team_cancellation_late`: 0 → `out_of_range`, 48 → `ok`; `visit_stuck`: 2 → `out_of_range`, 1 → `ok`; `report_not_final`: 48 → `out_of_range`, 12 → `ok`; priority P1 → P2 for `visit_uncovered_hospital` → `out_of_range` (kept). One behavioural test: with an accepted stricter `visit_uncovered_hospital` override of 48 h, an unassigned planned visit after a hospital discharge starting in 36 h raises the P1 exception; with the default it does not.
- [x] **ADM1-R5 Text.** The `/admin` operating-rules text says, per rule, which way is stricter (e.g. "früher melden = mehr Stunden Vorlauf" for look-ahead rules) and keeps "Sicherheitsausnahmen melden sich nie später als der Standard"; an e2e or unit test asserts that a look-ahead rule's input refuses a lower value with that text.
- [x] **ADM1-R6 Read model unchanged otherwise.** `effective_exception_rules` and every exception query keep their results for the defaults (existing pgTAP for OPS1, CSR1, SIG1-free paths stay green without edits other than 035:191-196).

**Out of scope:** any clinical band or value (D-28, Clinical Owner); team-level overrides (D-28 option C).

**Clinical gate:** `cra` is a mandatory reviewer of the PR (CGR-39 is its finding); the PO accepts after the `cra` section closes CGR-39 or names no blocking finding.


## PO acceptance — 2026-10-23 07:10: accepted (clinical gate passed)

The only open condition of the 04:17 review was the clinical gate. the Clinical Governance Report section 2026-10-23 06:30 (`reports/CLINICAL_GOVERNANCE.md`, merged with #167 as 6fc517a) reviewed migration 0037 and pgTAP 037 and closed **CGR-18** (0037:57-75; pgTAP 037 cases 1–4); its gate table says "ADM1: no blocking finding; the PO may accept". **The PO did not run the tests**; evidence is the 04:17 evidence table, CI green on b979cd6 (run 39884986430) and 95ed737 (run 39888181373), and the report section.

| Criterion | Result | Evidence |
|---|---|---|
| Every criterion of the brief and of the 20:15, 22:15, 23:00 and 03:10 changes | met | evidence tables below (04:17, 00:10, 01:10) |
| Clinical gate: latest report section holds no blocking finding for ADM1 | met | section 06:30, gate table; CGR-09, CGR-10, CGR-18 closed |

**Advisory findings, decided:** CGR-19 (correction of a departed author's report) stays with CSR1's interim refusal and D-30; CGR-16 (qualification verification) stays advisory until real data, D-29 (`owner`). Neither blocks a pilot on synthetic data.

**Decision: ADM1 accepted.** No condition. A team-level admission (D-20) or the "Vor dem Teamwechsel offen" hypothesis would be new items, not reopens.

## PO review — 2026-10-23 04:17: #153 (head b979cd6, merged as 95ed737; CI green on both); the CGR-18 change is met

Read from PR #153 (migration 0037 `remove_team_member`, pgTAP 037 with 24 assertions, `src/features/admin/rules.ts`, unit `admin-rules.test.ts`, ADR-046 amendment, `clinical/remediation/CGR-18.md`) and from 0016 (report statuses). **The PO did not run the tests**; results are taken from CI run 39884986430 on b979cd6 and from reading the code.

| Criterion (03:10 change) | Result | Evidence |
|---|---|---|
| 1a. refused while she is the performer of a `started`/`paused` team visit | met | 0037: `has_visit_in_progress` when `private.visit_performer(v.id) = p_user_id` and the visit is `on_the_way`, `started` or `paused`, checked before any release. pgTAP 037 (1): B starts A's visit → refused while started and while paused; B stays a member; her own planned visit is not released |
| 1b. refused while she performed a `completed` team visit whose report is missing or `draft` | met | 0037: `has_unsigned_reports` unless a report is `signed` or `final`. pgTAP 037 (2) no report → refused; (3) draft → refused, nothing released |
| 3. `signed` (awaiting countersignature) or `final` → allowed | met | pgTAP 037 (4a) care assistant signs → `signed` → removal `ok`, her future visit released, the completed visit untouched; (4b) registered nurse signs → `final` → `ok`. 0016 has no path from `signed` back to `draft`, so a countersigner never needs the removed author |
| 3. A (responsible, not performer) still handled by CGR-10 | met | the CGR-10 block is unchanged in 0037 (same condition as 0036:107-110); pgTAP 036 still runs green in the db job. No new 037 case for A; the PO accepts the unchanged code plus 036 as evidence |
| 2. `/admin` shows the reason and what clears it | met | `ADMIN_MESSAGES.has_unsigned_reports`: "… Nur sie kann ihn schreiben und unterschreiben. Erst unterschreiben lassen, dann entfernen."; unit test added |
| 4. PR names the 02:28 section and CGR-18 | met | PR body and migration header |
| No regression | met on the merge commit | CI green on b979cd6 (run 39884986430) and on the merge commit 95ed737 (run 39888181373): app (lint, typecheck, unit, audit, build), db (migrations from scratch, pgTAP), e2e. The merge added only `recovery/main` docs |

**Deviations, decided:**
- A correction draft of a `final` report does not refuse removal (the final version stays in force). **Accepted:** the care is documented; who may sign a correction after she leaves is CGR-19 → CSR1 interim refusal and D-30.
- Residual race between the check and the commit (membership row locked; drafting, signing and starting need that membership). **Accepted** as low, same as CGR-10.
- CR-036 in the Clinical Rule Register is left to `cra`. **Agreed:** the register is the Architect's.

**Decision:** every engineering criterion is met; no engineering change is requested. Status stays `changes-requested` only because the clinical gate is open: #153 was merged before the `cra` review of its head (the 02:28 agreement), and the PO does not skip the gate. ADM1 is **accepted without another PO round** in the first PO cycle after a `cra` review of migration 0037 and pgTAP 037 (on b979cd6 or 95ed737, same code) that holds no blocking finding.

## PO review — 2026-10-23 03:10: changes-requested (clinical gate, CGR-18)

Read from `recovery/main` @ 0e90932 (ADM1 merged as eceac83), the Clinical Governance Report section 2026-10-23 02:28 (PR #155, open) and the code it cites. **The PO did not run the tests**; CI on eceac83 and 0e90932 is green (app, db, e2e).

| Condition (00:10 / 01:10) | Result | Evidence |
|---|---|---|
| 1. #135 merged with green CI on the merge commit | met | eceac83, CI run 39864278704 green (01:10 review) |
| 2. next Clinical Governance Report section finds no blocking finding on #135 | **not met** | section 02:28: CGR-18 blocking (S1) |
| CGR-18 confirmed by the PO in the code | confirmed | 0036 `remove_team_member`: the in-progress refusal checks `v.responsible_user_id = p_user_id` only. RLS `team_members_update_visits` (0003:175-178) lets any team member start any team visit; `private.visit_performer` (0016) is the first `started` actor; `create_report_draft` and `sign_report` (0016) refuse anyone but the performer, and `sign_report` also requires team membership. A removed performer therefore leaves a visit that nobody can document or bill |

**Decision: `changes-requested`.** The removal rule must hold for the person who actually performs the care, not only the one planned for it. Patient safety (documentation of delivered care) is a precondition, so this is not accepted with a condition.

**Change (testable, one small PR, before or as the first commit of CSR1's first PR):**
1. `remove_team_member` is also refused (result code engineering's choice, e.g. `has_visit_in_progress` and `has_unsigned_reports`) while she is the **performer** of a visit of that team that is `started` or `paused`, or the performer of a `completed` visit of that team whose report is missing or `draft`.
2. `/admin` shows the refusal with a plain reason and what clears it ("Sie hat noch einen offenen Einsatzbericht: zuerst abschliessen lassen").
3. pgTAP:
   - B starts A's visit → removing B is refused, nothing is released, B stays a member;
   - B completed a visit, no report → refused;
   - B's report is `draft` → refused;
   - B's report is `signed` (awaiting countersignature) or `final` → removal allowed;
   - A (responsible, not performer) of the visit B started is handled by the existing CGR-10 rule (unchanged).
4. The PR names the 02:28 section and CGR-18.

**Not ADM1's:** CGR-19 (correcting a departed author's final report) goes to CSR1 as an interim refusal and to decision D-30 (`clinical`, with `legal`).

**Acceptance path:** merged with green CI on the merge commit, and the `cra` review of the open PR (agreed 02:28) finds no blocking finding. Then the PO accepts in the same cycle.

## PO review — 2026-10-23 01:10: #135 merged (eceac83), CI green on the merge commit; waits only for the clinical gate

Read from the merge commit eceac83 (#135) and CI run 39864278704 on it (jobs app, db and e2e all `success`). **The PO did not run the tests**; results are taken from CI.

| Condition (00:10) | Result | Evidence |
|---|---|---|
| 1. #135 merged with green CI on the merge commit | met | eceac83 merged 2026-10-23 00:20; CI on eceac83: app (lint, typecheck, unit, audit, build), db (migrations from scratch, pgTAP incl. 036, concurrency, types), e2e (Playwright) all green. Also green on the following head b0bd82b |
| C1 pause e2e (C1 condition, fixed in #135) | met | `tests/e2e/lifecycle.spec.ts` "the team pauses a case … and resumes it (C1)" runs in the green e2e job on eceac83 |
| 2. next Clinical Governance Report section finds no blocking finding on #135 | **open** | the newest section is 2026-10-22 23:05 (written before #135 merged); its 23:05 note says the Architect reviews ADM1 at delivery |

**Decision:** no engineering change is requested. Status stays `changes-requested` only because acceptance waits for the clinical gate (condition 2), which the PO does not skip: ADM1 releases and refuses care visits, so it is in gate scope. **Engineering:** set ADM1 `delivered` in `IMPLEMENTATION_STATUS.md` (PRs #101, #135), so the review hand-off opens. **cra:** one report section on eceac83 (CGR-09, CGR-10, the past-visit residual now in CSR1). The PO accepts at the first cycle after that section, if it holds no blocking finding.

## PO pre-review — 2026-10-23 00:10: #135 head 85b1519 (CI green: app, db, e2e); the three open changes are met

Read from PR #135 (commits 6994ee5, baf084a, 85b1519), migration 0036 and pgTAP 036 (39 assertions), the ADR-046 amendment, e2e `admin.spec.ts`, unit `admin-rules.test.ts` and engineering's gate trail (journal 23:25). **The PO did not run the tests**; results are taken from CI on 85b1519 and from reading the code.

| Change | Result | Evidence |
|---|---|---|
| Privacy (PO 22:15): the team-readable release row carries the fixed text only | met | `remove_team_member` passes the literal 'Mitglied aus dem Team entfernt' to `private.release_member_visits`; the reason goes only to `change_log` and the audit. pgTAP 036: no `visit_plan_changes` row contains the removal reason, the `change_log` row does |
| CGR-09: suspended visits are released too | met | `release_member_visits` selects every `planned` visit, suspended or not. pgTAP 036: pause → removal → resume: both future visits active again, no responsible member, J3 `uncovered` flag, OPS1 `derived_exceptions` row |
| CGR-10: no removal while a visit of hers is in progress | met | `has_visit_in_progress` for `on_the_way`, `started`, `paused`, checked before any release. pgTAP 036 tests each status alone; nothing released, she stays a member. `/admin` message (unit test) |
| Changes 2–4 and the C1 pause e2e | unchanged since 22:15 | still met; the C1 pause e2e is confirmed only on the merge commit |
| No regression | met on the PR head | CI green on 85b1519 (app, db, e2e) |

**Merge state:** #135 has a merge conflict with `recovery/main` in `docs/agents/JOURNAL.md` only (journal entries from #140 and #141). Engineering merges `recovery/main` in and keeps both entries, newest first.

**Residual gap, not ADM1's to fix:** a `planned` visit of hers dated **before today** that never started is left unchanged (pgTAP 036 "her past visit is unchanged"). After the removal she can no longer see it, and nobody in the team is responsible for it. Releasing it would not help: it is already missed. It belongs to the overdue-visit exception of CSR1 (CGR-04). The PO added a criterion to `briefs/CSR1.md`: the exception is raised and stays visible to the team even when the responsible person is no longer a member.

**Decision:** status stays `changes-requested` only for the steps that cannot be done in code review. ADM1 is **accepted without another PO round** once:
1. #135 is merged with green CI on the merge commit (the C1 pause e2e included);
2. the next Clinical Governance Report section finds no blocking finding on #135 (the 23:00 gate condition).

## Clinical review gate — 2026-10-22 23:00: #135 not acceptable yet

Clinical Governance Report 2026-10-22 22:30 considered. Changes 1–4, the removal of legacy heuristics and the PO's 22:15 privacy fix are endorsed by the report.

| Finding | Severity | PO decision |
|---|---|---|
| CGR-09 | blocking | change: removal also releases her **suspended** visits, or `resume_case` clears a responsible person who is no longer an eligible team member. pgTAP: remove → resume → the visit is uncovered |
| CGR-10 | blocking | change: refuse removal while she has a visit `on_the_way`, `started` or `paused` (result `has_visit_in_progress`, the UI says so). pgTAP |
| CGR-16 | advisory now, blocking before real data | qualification verification: D-29 (`owner`). Not part of ADM1 |

ADM1 is accepted once #135 carries the privacy fix, CGR-09 and CGR-10, is merged with green CI on the merge commit, and the next Clinical Governance Report section finds no blocking finding on it.

## PO pre-review — 2026-10-22 22:15: #135 (open, CI green on becb9c4); one privacy change before merge

Read from PR #135 (head becb9c4: app, db, e2e green), migration 0036, pgTAP 036 (28 assertions), ADR-046 amendment, e2e `admin.spec.ts` and `lifecycle.spec.ts`. **The PO did not run the tests**; results are taken from CI and from reading the code. Status stays `changes-requested` until #135 is merged with green CI on the merge commit.

| Change (20:15) | Result | Evidence |
|---|---|---|
| 1. Removal releases her future planned visits in the same command, logged, count shown; one release rule shared with ABS1 | met, **one privacy defect** (below) | `private.release_member_visits` (not executable by app roles); `remove_team_member` returns `{result, released}`; pgTAP 036: near and later visit released, `uncovered` flag, OPS1 `derived_exceptions`, started/completed/past/suspended/other team unchanged, change log, audit under the command, duplicate, foreign admin releases nothing; e2e notice "… jetzt offen im Team" |
| 2. Role change explicit and tested | met | ADR-046 amendment: role change keeps membership, qualification and visits; pgTAP 036 nurse → coach, qualification kept, visit still hers, `start_visit` = ok |
| 3. Names asserted in reports and quality | met | pgTAP 036 `signed_by_name`, `countersigned_by_name`, `field_quality.person_name`; profile of organisation B never shown; null without a profile |
| 4. Legacy hints removed | met | `features/operations/rules.ts` and its unit test deleted; "Weitere Hinweise" gone from `operations-client.tsx` |
| C1 condition (pause e2e) | fixed in code; **confirm on the merge commit** | `lifecycle.spec.ts` waits for the resume before leaving `/team` |

**Privacy defect (blocking, small).** The release row in `visit_plan_changes` carries the administrator's free-text reason ("Mitglied aus dem Team entfernt: <reason>"). That table is readable by every member of the team (`team_members_read`), so former colleagues read why a person was removed, which is an employment matter, not a care fact. The care record needs the fact, not the reason. Change:
- the team-readable release row stores the fixed text "Mitglied aus dem Team entfernt", nothing else;
- the administrator's reason stays in `change_log` and the audit (administrators only), as today;
- pgTAP: after a removal with reason "Testgrund", no `visit_plan_changes` row contains "Testgrund", and the `change_log` row does.
ABS1 already follows this rule (fixed reason "Abwesenheit", no free text); the release function should take only fixed texts from callers that write into team-readable rows.

**Engineering's open questions, answered:**
- *Should HAND1 show `released` entries?* **Yes, as a fact without a reason**: "Einsatz <Datum Zeit> wieder offen im Team", with the date of the release. The next nurse on the case needs to know the planned person changed (continuity); she does not need the cause. It ships with ABS1 (which releases the same way and adds "take"), not in #135, and AN1 planning actions keep excluding `released` (it is not a planning action by the team).
- *An accepted cover by a nurse removed from her own team is not withdrawn:* **accepted as open** while COVER1 is off (D-3). It becomes a condition of the COVER1 delta review after D-3: removal or absence of the covering nurse releases the cover the same way.

**Acceptance path:** fix the defect in #135 (or a follow-up PR before ABS1 merges), merge with green CI on the merge commit; the PO then accepts without a further round on changes 2–4.

## PO review — 2026-10-22 20:15: changes-requested (patient safety)

Reviewed on merged evidence: #101 (head c736429, CI green: app, db, e2e; merge commit bdb0d1d on `recovery/main`: app and db green, e2e red on one run only in `lifecycle.spec.ts` "a visit suspended by a pause …", the known C1 flake, see below; `admin.spec.ts` passed), ADR-046, migration 0035, pgTAP 035 (67 assertions), unit `admin-rules.test.ts`, e2e `admin.spec.ts`. **The PO did not run the tests**; results are taken from CI and from reading the code.

| Criterion | Result | Evidence |
|---|---|---|
| Member profile with display name, shown in the team week, primary nurse and deputy | met | `member_profiles` (name only, commands only); pgTAP 035 "Anna M." in `team_cases()` members, primary nurse id; e2e "Carla Coach" in `/admin` |
| … shown at report signature and countersignature, quality-event author, exception owner | met in code; **not asserted** for report and quality | `signed_by_name`, `countersigned_by_name`, author name in `field_quality`; pgTAP 035 only `lives_ok` for `field_reports` and `field_quality`; unit `handlerLabel` asserts the exception owner name |
| Invite with role, optional team and qualification; accepted on sign-in with the confirmed email | met | `invite_member`, `accept_my_invitations` (`auth/actions.ts`); pgTAP 035 invalid email, team without qualification refused, duplicate member, revoke, accept once, idempotent, unconfirmed email accepts nothing; e2e invite |
| Add and remove team memberships; qualification change with a reason, audited | met for the commands; **unsafe side effect on removal** (change 1) | `add_team_member`, `remove_team_member` (reason, refused while primary nurse or deputy of an open case), qualification through the F0 command `set_member_qualification` (reason, change log); pgTAP 035 add once, removal guard, removal logged |
| Create, rename, deactivate teams, set the region; deactivation refused while cases are open | met | `create_team`, `update_team`, `deactivate_team` (`status = 'closed'`, J2 excludes it); pgTAP 035 unique name, refused with open cases, closed team takes no member, audited; e2e create and refused deactivation with the reason shown |
| Response deadlines and exception thresholds and priorities within safe ranges, audited, no migration, who and when | met | `set_response_deadline`, `set_exception_rule`, `reset_exception_rule`, `private.effective_exception_rules`; pgTAP 035 P1 never lowered or later, others ≤ 2× default, escalation never later, override per organisation only, who and when; e2e out-of-range refused, reset to default |
| Tariff and reference data not editable | met | pgTAP 035 no insert/update privilege on `tariff_rates`; no `tariff`/`billing_rule` command exists |
| Negative tests: nurse, coach, operations, other organisation | met | pgTAP 035 nurse, coach, operations and foreign administrator each refused and see nothing; e2e nurse sees `admin-denied` |

**Why changes-requested.** The administration does what the brief asks, and the safe ranges for operating rules are exactly right: an organisation may make safety alerts earlier, never later. But `remove_team_member` deletes the membership and leaves every future visit with `responsible_user_id` = that person. `private.visit_flags` raises `uncovered` only when the responsible member is null, so these visits **look covered, raise no J3 flag, no OPS1 exception and no COVER1 offer, and the person they are assigned to can no longer see them**. This is the same silent-miss failure that ABS1 was approved to close, created here by an administrator's routine action. Patient safety is a precondition, so it cannot be accepted with a condition.

**Changes (testable, one PR):**
1. **Removal releases her visits.** `remove_team_member` sets the responsible member to null on every visit of that team's cases that is `planned` (not started, not cancelled, not suspended) and dated today or later, in the same command. Each release is written to the plan change log with the reason "Mitglied aus dem Team entfernt: <reason>"; the result returns the number released, and `/admin` shows it ("3 Einsätze sind jetzt offen im Team"). pgTAP:
   - a removed member's future planned visit has no responsible member, carries the flag `uncovered` and appears in OPS1 `derived_exceptions` as an uncovered visit;
   - her started, completed and past visits are unchanged;
   - the release is in the change log with the reason;
   - another team's visits are untouched.
   Build it as one private release function that ABS1 reuses (ABS1 releases the same set for a time range), so there is one release rule, not two.
2. **Role change is explicit about visits.** pgTAP for `set_member_role` from nurse to coach or operations while she is responsible for a future visit: either she can still start it (team membership and qualification unchanged, asserted), or the visit is released as in change 1. ADR-046 states which.
3. **Names asserted where people appear.** pgTAP: `field_reports` returns the signer's and countersigner's display name; `field_quality` returns the author's display name; a profile of another organisation never appears; without a profile the name is null and the neutral label stays.
4. **Remove the unvalidated legacy hints** ("Weitere Hinweise" on `/operations`, `src/features/operations/rules.ts`), as the brief's constraint asks once ADM1 ships. There are no pilot users yet who rely on them; the OPS1 exception list is the validated source.

**Deviations, decided:**
- Account creation and the invitation e-mail outside the app until D-26: **accepted** for the pilot (a few accounts, created by NAVORA operations). D-26 stays with the owner; the PO recommendation is added there.
- Built under D-5 while D-20 is open: **accepted**. D-5 is the decided rule. The PO's 18:20 line "ADM1 waits for D-20" is withdrawn: D-20 may later move admission to the teams as a follow-up, and the commands are already scoped so that a team-level permission can be added without a data change.
- Deactivation refused while cases are open (active or paused), not only active: **accepted**, it is the stricter and safer reading (a paused case returns to its team, RET1).
- Qualification changed through the existing F0 command: **accepted**, one rule for J2, J3 and ADM1.

**C1 condition (open since 16:15):** the e2e "a visit suspended by a pause is marked on /field …" failed again on the merge commit bdb0d1d while it passed on the PR head. It is not ADM1's failure. It must be fixed in engineering's next PR (the ADM1 changes or ABS1), not re-run.

## Problem
Several things NAVORA administrators must manage can today be changed only by a command or by a migration:
- member qualifications (D-5, F0);
- response deadlines (J2);
- exception thresholds (OPS1).

Members also have no display names, so a nurse cannot see who her case's primary nurse is (J6). Running a pilot this way means every invitation, every new team and every threshold change becomes an engineering task, and teams work with unnamed colleagues.

## Users and journey step
NAVORA administrators. Every user benefits from names. Cross-cutting: Team Decision, Planning, Visit, Operations.

## Outcome
A NAVORA administrator manages members, teams and operating rules in one admin area without engineering help. Every person shows by name wherever the product lists people.

## Acceptance criteria
- [ ] **Member profile** with a display name. It is shown wherever members appear: team week, primary nurse and deputy, report signature and countersignature, exception owner, quality-event author.
- [ ] An administrator **invites** a person to the organisation with a role, adds and removes team memberships, and sets the qualification (`registered_nurse`, `care_assistant`). A qualification change needs a reason (F0 rule) and is audited.
- [ ] An administrator **creates, renames and deactivates teams** and sets their region. Deactivating a team with active cases is refused until the cases are handed over.
- [ ] An administrator changes **response deadlines** per referral type (J2) and **exception thresholds and priorities** (OPS1) within safe ranges. Changes are audited, take effect without a migration and show who changed what and when.
- [ ] **Tariff and reference data (J5) are not editable here.** They change only through a reviewed migration with a cited source, because they are regulated data.
- [ ] Negative tests: nurses, coaches and operations can open none of these functions; another organisation's administrator sees nothing.

## Out of scope
Self-administration by partners or teams (D-5), single sign-on, MFA rollout, payroll data.

## Constraints and references
D-5 (decided: NAVORA administrators manage members and qualifications). D-3 (role matrix). J6 gap "members without names". OPS1 follow-up: remove the unvalidated legacy hints once this ships, unless pilot users rely on one.

## Open questions for engineering
- Do profiles belong in `organization_memberships` or in a separate table that does not hold health data?
