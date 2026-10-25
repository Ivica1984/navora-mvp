---
id: DST1
title: Safety alerts are on time on the nights the clock changes
author: po
status: changes-requested
updated: 2026-10-25
---

# DST1 — Safety alerts are on time on the nights the clock changes

**Approved by the PO 2026-10-25 02:10 CET** (product authority; patient safety is a precondition; no clinical rule is set or changed). Source: `cra` 2026-10-25 02:26 CGR-52 (open PR #341; advisory S3, root cause UNKNOWN) and the red `db` job on docs-only PRs #340 (00:17 and 00:23 UTC) and #341 (00:35 UTC) on the night Zurich clocks went back (2026-10-25, 03:00 CEST → 02:00 CET, 01:00 UTC).

## Problem
- On 2026-10-25 between about 00:15 and 00:35 UTC, the `db` job failed on PRs that change only documentation, with code identical to `recovery/main` fca2b40, whose `db` job was green hours earlier. Failing assertions: pgTAP **038** tests 16, 17, 20 (CSR1: "10 minutes after the planned start it is already raised, as P2"), **046** tests 71, 72 (ABS1: a released overdue visit stays alerted), **062** tests 17, 30, 39, 41, 46 (SIG1: P1 delivery, the step to Operations, the Operations fallback). More assertions failed as the night went on.
- These are the main controls against H-01 (a planned visit nobody notices). Two explanations remain open (`cra`, not verified): (a) only the **test fixtures** are clock-dependent (built from `now()` and stored as a Zurich local date and time, falling on the previous Zurich day or in the repeated hour); (b) **production code** resolves a planned start in the repeated hour 02:00-02:59 to the later instant (CET), so on the fall-back night an overdue alert and its P1 escalation come up to one hour late. The spring-forward night (2027-03-28, no 02:00-02:59) has the opposite problem: a local time that does not exist.
- **Same night, later run (po push 0e155e9, 01:16-01:20 UTC = 02:16-02:20 CET):** `db` failed in 046 tests 71-72, 062 test 15 and 064 test 69 ("SIG2-9: a P2 overdue visit has no delivery", which now saw deliveries), and **e2e** failed in `tests/e2e/field.spec.ts:123` (F3 time correction): a correction of the departure time was refused with "Die korrigierte Zeit darf nicht in der Zukunft liegen" at 02:19 local. The failing set changes with the hour, so both pgTAP and e2e depend on the clock.
- Three earlier clock-dependent failures (AN2-C1, SIG2-14, DAY-1) were fixed one by one. Each blocked every PR for hours. No test today proves the controls at a DST transition.

## Users and journey step
The responsible nurse, her team and Operations (Visit → safety signal: CSR1 overdue, SIG1, SIG2, ABS1 release); every agent's PR (CI).

## Outcome
A visit planned in the repeated or missing hour raises its overdue signal and its escalation no later than on any other night, and the test suite passes whatever instant it runs at.

## Acceptance criteria
- [ ] **DST1-1 Root cause recorded.** The pgTAP suite is run at fixed clocks 2026-10-25 00:35 UTC, 2026-10-25 01:30 UTC, 2027-03-28 01:30 UTC and one ordinary daytime instant; for each failing assertion, the ADR names whether production code, a fixture, or both are affected. A fixed-clock mechanism (for example a test-only `now()` override) is part of the deliverable.
- [ ] **DST1-2 Repeated hour: never late.** Wherever a Zurich local date and time is turned into an instant for a signal, planning or exception rule, an ambiguous local time (2026-10-25 02:00-02:59) resolves to the **earlier** instant (CEST). pgTAP at a pinned clock: a visit planned at 02:30 local on 2026-10-25 and not started → the overdue signal follows CR-038 measured from **00:30 UTC** (P2 from the planned start, P1 one hour later; PROVISIONAL, D-28), exactly as on any other day; the SIG1 P1 path for a no-show in that hour reaches its receivers and Operations as on any other night.
- [ ] **DST1-3 Missing hour: defined and tested.** A local time that does not exist (2027-03-28 02:00-02:59) is either refused when a visit is planned (with a clear reason) or resolved by a rule written in the ADR; whichever is chosen, its overdue signal is never raised later than if the time were read in standard time (CET). pgTAP at a pinned clock on 2027-03-28 for the chosen rule.
- [ ] **DST1-4 Tests independent of the hour they run.** Every pgTAP fixture and every e2e step (at least `field.spec.ts` F3 time corrections) that builds times from `now()` and stores a Zurich local date or time is made deterministic (pinned clock or explicit conversion). Proof: the full suite passes at the four clocks of DST1-1 (CI matrix or a documented one-off CI run with the fixed clocks; the PR states which).
- [ ] **DST1-5 No assertion weakened.** 038, 046 and 062 keep the meaning of every failing assertion (same signal, same priority, same receivers); no test is skipped, quarantined or loosened to pass. If production code was affected (DST1-1), the ADR says so and `cra` is asked to review the change (clinical review gate: it touches CSR1 and SIG1).
- [ ] **DST1-6 No regression.** pgTAP, unit and e2e green; DAY-1 guards (Europe/Zurich calendar day) unchanged; AN2-C1 and SIG2-14 fixtures still pass.
- [ ] **DST1-7 Watched-hours windows are never shorter than their wall-clock length** (added by the PO 2026-10-25 06:10 CET from `cra` 05:30 CET, CGR-52 addition (4)). A watched period (SIG1/SIG2 watched hours) whose start or end is an ambiguous local time starts at the **earlier** instant and ends at the **later** instant; a start or end in the missing hour follows the DST1-3 rule. pgTAP at a pinned clock: a period 00:00-02:30 local on 2026-10-25 covers 01:15 UTC (the second 02:15); a period 02:30-06:00 local on 2026-10-25 covers 00:45 UTC (the first 02:45); one assertion on 2027-03-28 for a period ending in the missing hour.
- [ ] **DST1-8 The test clock cannot act outside a test database** (added by the PO 2026-10-25 06:10 CET; patient safety: a pinned clock in staging or production would freeze every overdue and escalation signal). Whatever fixed-clock mechanism DST1-1 delivers: (a) a database built from the migrations alone (no seed) reads the real clock, proved by a pgTAP assertion or CI step run **before** the seed; (b) no role used by the app (`anon`, `authenticated`, `service_role`) can set, read or change the pin (catalogue assertion on grants and on any setting function); (c) the ADR states how staging and production are kept free of the pin and that no seed runs there. No check is run against the live database for this criterion.

**PO notes for the review (2026-10-25 06:10 CET, PR #349 open, not reviewed):** DST1-4 asks for proof at the four clocks in **CI** (a matrix or a documented one-off CI run). A local run under a clock offset is useful evidence of the root cause (DST1-1) but does not by itself meet DST1-4; if the runner cannot set the clock, the PR shows the pinned-clock pgTAP files for the four instants running in CI instead, and says so. DST1-7 and DST1-8 apply to PR #349 as it stands; neither asks for new production behaviour beyond what the PR describes.

## PO review 2026-10-25 10:12 CET: changes-requested

**Reviewed:** PR #349 merged as `3c2da15` (merge commit; head `2702403`): migration 0067, pgTAP 068 (44), ADR-081, CI `db` job, `src/features/field/time.ts`, unit `field-time`, e2e `field.spec.ts` F3, fixture changes in about 60 pgTAP files. **CI** `app`, `db`, `e2e` green on `2702403`, `3c2da15` and `recovery/main` `16e4e9c` (runs 40176036755, 40176429793; read through the API). `cra` 09:31 CET (open PR #358): CGR-52 closed, no blocking finding, advisory CGR-53, CGR-54, CGR-56; DST1-7 test gaps named. **The PO did not run the tests**; results below are from the code, CI and the `cra` review.

| Criterion | Result | Evidence |
|---|---|---|
| DST1-1 root cause, fixed-clock mechanism | met | ADR-081 table: four clocks, production code and fixtures named per failing assertion (local run under a clock offset); `private.now()` + `private.test_clock` + `navora.test_now` (0067 §2) |
| DST1-2 repeated hour → earlier instant | met | `private.at_zurich` (0067 §1); 068 tests 1-5 (02:00/02:30/02:59 → CEST); 02:30 visit P2 at 00:40 UTC, P1 at 01:30 UTC for team and Operations, receivers responsible + team, Operations after 15 min untaken, once (068:85-114). Deviation (a) below |
| DST1-3 missing hour defined and tested | met | rule: CET reading (ADR-081; refusal not chosen, reason given); 068:116-127 (2027-03-28: P2 not later than the CET reading, P1 one hour after) |
| DST1-4 tests independent of the hour | met with deviation (b) | CI `db` job pins the whole suite to 10:00 of the Zurich day; 068 runs the DST instants in CI; fixtures use explicit conversion; e2e F3 picks typeable minute counts; guards 068:152-170 |
| DST1-5 no assertion weakened; `cra` asked | met | no expected value of 038, 046 or 062 changed (`cra` 09:31 read the fixture diff); ADR-081 names the production change; `cra` reviewed after merge (process note below) |
| DST1-6 no regression | **not met** | CI green, but `cra` CGR-53: 0067 gives the **end** of `private.visit_interval` the earlier instant too, so a visit 01:30-02:30 on 2026-10-25 occupies 23:30-00:30 UTC instead of 23:30-01:30 UTC; an absence of the responsible nurse from 01:00 UTC no longer overlaps it, and ABS1 neither releases the visit nor flags `responsible_absent` (H-01, H-17). Before 0067 it did. A behaviour regression of an accepted control (ABS1), introduced by this delivery |
| DST1-7 watched-hours windows never shorter | **partly met** | end: `private.at_zurich_end` in `watched_raise_at`, 068:138-150 (00:00-02:30 covers 01:15 UTC; look-ahead). **Missing** the two assertions the criterion names: a period 02:30-06:00 covering 00:45 UTC, and a 2027-03-28 period ending in the missing hour (`cra` 09:31 confirms) |
| DST1-8 (a) no seed → real clock, proved before the seed | **partly met** | 068:80-83 deletes the row and shows `private.now() = now()` **after** the seed; no assertion or CI step runs before the seed, as the criterion asks |
| DST1-8 (b) no app role sets, reads or changes the pin | **partly met** | 068:76-79 checks `authenticated` select/insert and `anon` select only; `service_role` and update/delete/truncate are not asserted |
| DST1-8 (c) ADR states how staging and production stay free | met, residual risk CGR-56 | ADR-081 test-clock bullet ("`supabase db push` never runs the seed"); `cra` CGR-56: UNKNOWN whether staging is ever rebuilt with a seed |

**Deviations decided:**
- (a) DST1-2 asks for the SIG1 P1 path "for a no-show in that hour"; 068 proves it for the unstarted visit (`visit_overdue`). Accepted: a no-show is recorded at an instant by the nurse and is not converted from a local time; the converted path is the overdue one.
- (b) DST1-4: no CI matrix at the four clocks (UNKNOWN whether the hosted runner keeps a changed clock). Accepted as the fallback the PO note allowed: the pinned suite plus 068's pinned DST instants in CI, and ADR-081 says so. The CI matrix stays PLANNED; when built it includes one night-time instant after Zurich midnight (`cra` 09:31).
- (c) Ends in the repeated hour other than watched-hours windows take the earlier instant (ADR-081). **Not accepted for intervals used in a safety overlap check** (CGR-53, DST1-C1). Accepted for the stuck reference (0038, 0058): an earlier end raises the alert sooner.
- (d) Merged before the `cra` review although the brief and the PO 08:10 note asked for it first. Decided by po (process, product authority): merging on green CI stays allowed; the PO's acceptance is the clinical gate, and the PO accepts an item in clinical scope only once `cra` has reviewed its merge commit (README *Clinical review gate*). No owner decision needed. No harm: `cra` found no blocking finding.

**Why `changes-requested`:** DST1's outcome is "never later than on any other night". CGR-53 makes one safety check later than before on the same night (an absent nurse's visit is not released), and three criteria are only partly proved. Each fix is small and in the same files.

**Changes requested (must be met for acceptance; one follow-up PR):**
- [ ] **DST1-C1 (CGR-53) A visit interval is never shorter than its wall-clock length.** The end of `private.visit_interval` uses `private.at_zurich_end`, the start stays `private.at_zurich`. Check every other interval used for an overlap test (absence, cover, plan conflicts) and apply the same rule; list them in ADR-081. pgTAP at a pinned clock: a visit 01:30-02:30 local on 2026-10-25 overlaps an absence of its responsible nurse starting 01:00 UTC; ABS1 releases it or flags `responsible_absent` exactly as for the same case on an ordinary day; the 0058 stuck reference keeps the earlier end.
- [ ] **DST1-C2 The two DST1-7 assertions.** In 068 (or a new file): a watched period 02:30-06:00 local on 2026-10-25 covers 00:45 UTC; a period on 2027-03-28 that ends in the missing hour ends at the DST1-3 reading.
- [ ] **DST1-C3 DST1-8 proved as written.** (a) a CI step between "Pin the database clock" and the seed fails unless `private.now()` equals `now()` while `navora.test_now` is set (the row is not yet there); (b) 068 asserts that `anon`, `authenticated` and `service_role` hold no privilege of any kind on `private.test_clock` and that no function executable by them writes it.

**Conditions with their own deadline (do not block this acceptance; tracked here):**
- [ ] **DST1-C4 (CGR-54) A corrected time in the repeated hour can be entered either way.** Decided by po: option (a). When a typed correction on the fall-back date lies in 02:00-02:59, the form asks "02:20 Sommerzeit (MESZ)" or "02:20 Winterzeit (MEZ)", nothing preselected, and sends the chosen instant; the doc comment of `zurichLocalToIso` matches the code. Unit test: both readings of 02:20 on 2026-10-25 can be produced; e2e or component test of the choice. Reason: a corrected time is documentation and, once signed, the billing basis (H-14); option (b) (refuse) would leave the nurse unable to record what happened. **Due** before 2027-10-31 or before the first real client, whichever is first.
- [ ] **DST1-C5 (CGR-56) The pin can never reach a shared database.** After every migration run on staging and production, a scripted check fails the deploy unless `private.test_clock` is empty and `navora.test_now` is unset at database and role level; recorded in the release checklist (`docs/engineering/OWNER_RUNBOOK.md` or its successor). **Due** before gate B (staging with real users). No check against the live database from an agent.

## Rules and their input class
- DST1-2 and DST1-3 add a time-conversion rule only (input class *visit/schedule fact*). They change no threshold, priority, receiver or step: the thresholds stay PROVISIONAL (D-28), the routes stay SIG1/SIG2.

## Out of scope
- Showing the repeated hour differently on `/field` or `/team` (for example "02:30 (Sommerzeit)"): a later item only if the pilot shows confusion.
- Any threshold change (D-28, Clinical Owner).

## Constraints and references
- `cra` CGR-52 (`reports/CLINICAL_GOVERNANCE.md` 2026-10-25 02:26, open PR #341); H-01; CR-038 (overdue P2/P1), CR-066 and CR-072 (SIG1 delivery and the step to Operations); DAY-1 (`briefs/AN2.md` 00:20, migration 0055), AN2-C1, SIG2-14 (earlier clock-dependent failures).
- CI comments on PR #340 (2026-10-25 00:20 and 00:24 UTC).
- `cra` 2026-10-25 05:30 CET (#348): CGR-52 re-assessed to S2, production code affected (0038, 0045, 0062); addition (4), watched-hours windows, taken up as DST1-7.
- Hard rule: never skip, disable or quarantine a test to get green.

## Open questions for engineering
1. Is a planned visit stored as a local date plus local time, or as an instant? Where exactly is it converted (one helper or several)?
2. Does RLS2's red `db` job on #331 share this cause (`cra` thinks part of it may)?
3. Cheapest reliable fixed-clock mechanism for pgTAP in this CI (a `private.now()` wrapper used by every function, or a session setting read only in tests).
