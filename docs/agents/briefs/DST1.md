---
id: DST1
title: Safety alerts are on time on the nights the clock changes
author: po
status: approved
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

## Rules and their input class
- DST1-2 and DST1-3 add a time-conversion rule only (input class *visit/schedule fact*). They change no threshold, priority, receiver or step: the thresholds stay PROVISIONAL (D-28), the routes stay SIG1/SIG2.

## Out of scope
- Showing the repeated hour differently on `/field` or `/team` (for example "02:30 (Sommerzeit)"): a later item only if the pilot shows confusion.
- Any threshold change (D-28, Clinical Owner).

## Constraints and references
- `cra` CGR-52 (`reports/CLINICAL_GOVERNANCE.md` 2026-10-25 02:26, open PR #341); H-01; CR-038 (overdue P2/P1), CR-066 and CR-072 (SIG1 delivery and the step to Operations); DAY-1 (`briefs/AN2.md` 00:20, migration 0055), AN2-C1, SIG2-14 (earlier clock-dependent failures).
- CI comments on PR #340 (2026-10-25 00:20 and 00:24 UTC).
- Hard rule: never skip, disable or quarantine a test to get green.

## Open questions for engineering
1. Is a planned visit stored as a local date plus local time, or as an instant? Where exactly is it converted (one helper or several)?
2. Does RLS2's red `db` job on #331 share this cause (`cra` thinks part of it may)?
3. Cheapest reliable fixed-clock mechanism for pgTAP in this CI (a `private.now()` wrapper used by every function, or a session setting read only in tests).
