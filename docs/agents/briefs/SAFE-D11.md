---
id: SAFE-D11
title: Safety exception Δ11 — a reopened case without a team is never invisible
author: po
status: approved
updated: 2026-11-12
---

# SAFE-D11 — Reopened case without a team

**Approved 2026-11-12 15:45 CET** as the **documented safety-fix exception** before B1.1, confirmed by the founder (FE-071, founder reply to FE-070 Lieferung 1). This is the only Engineering feature work allowed while no feature block is active. **Gate: «Simulation, synthetic data».**

## Problem
IMPLEMENTED today, found in the code (`specs/B1.md` Δ11; confirmed by `eng` 2026-11-12 14:22):
- `close_case` withdraws the open team search (0031:43);
- `reopen_case` sets the case `active` and keeps `ready_for_matching_at` (0024:300-323);
- `open_matching_if_ready` opens a search only if **no** `matching_requests` row of any status exists for the case (0034:187).

So a case closed before any team accepted and then reopened can never be matched again. No exception is raised:
- the J2 escalations read only `status = 'open'` (0019:105);
- `case_not_ready` needs `ready_for_matching_at is null` (0024:468).

Only the Operations «Fallstatus» shows «ohne Team» (0031:112). The client falls out of every team's and every role's responsibility without a signal.

## Users and journey step
Operations (`admin`, `operations`) and the teams of the region; journey step 1 (Anfrage → Fall → Teamsuche), lifecycle C1.

## Outcome
After a reopen, a case without a team has **exactly one** of two results:
- (A) an open, admissible team search;
- (B) a visible exception, assigned to the organisation's Operations role, that names why no search is open.

It never has neither.

## Acceptance criteria
- [ ] **R1 search again (A):** Given a case that was closed before any team accepted (its search `withdrawn`), when it is reopened and its readiness list is empty, then one new open team search exists:
  - region, urgency, required qualification, response deadline and RET1 first refusal are derived exactly as for a first search;
  - the withdrawn row stays unchanged (audit history);
  - pgTAP.
- [ ] **R2 exception when no search is possible (B):** Given the same case, when it is reopened while its readiness list is not empty, then `operations_exceptions()` returns one exception for the case:
  - its type is new and named by `eng`, e.g. `case_reopened_no_team`;
  - label «Wiedereröffneter Fall ohne Team», next step «Fehlende Angaben ergänzen; die Teamsuche öffnet sich dann selbst. Nie automatisch zuweisen.»;
  - it lists the missing items;
  - it is visible only to coordination roles of the case's organisation;
  - it closes automatically when a search opens, a team is assigned or the case is closed again;
  - pgTAP plus e2e at 1440 px on `/operations`.
  - Priority **P2** (continuity), as `candidates_exhausted`. Whether an urgent or hospital-discharge case needs P1 is `cra`'s to say; until then P2.
- [ ] **R3 the normal exceptions still apply after (A):** a reopened case whose new search finds no eligible team, is declined by all or passes its deadline shows `candidates_exhausted` or `offer_overdue`, exactly as a first search does (pgTAP).
- [ ] **R4 a case with a team keeps it:** a case closed after a team accepted and then reopened keeps its team and gets no new search (pgTAP, unchanged behaviour). `eng` checks whether a team can be inactive while a case is assigned to it. If yes, that case also shows an exception (same pattern as R2); if no, the PR says why (UNKNOWN today).
- [ ] **R5 never assigned automatically:** no path in this fix sets `assigned_team_id` (pgTAP: after R1 the case has no team until a team decides).
- [ ] **R6 idempotent:** reopen with the same idempotency key, or two reopen and close cycles, leave at most one open search (pgTAP).
- [ ] **Negative:**
  - a member of another team or organisation and `anon` cannot see the exception or the new search outside the normal J2 visibility;
  - the coach gets no new handling right;
  - pgTAP.
- [ ] **Red first:** the R1 and R2 tests are pushed first on a probe branch against today's `recovery/main` and are red there. The PR names the probe run.
- [ ] **Integration line:**
  - `ci` green on the PR head and on the merge commit;
  - `ci-repeat` 10/10 (`db`, `e2e`) on the merge commit;
  - the BD flow stays green.
  Only then is SAFE-D11 accepted; the record goes into `docs/product/ABNAHMEAKTE.md`.

## Rules and their input class
No new care rule. R1 restores the existing rule «a ready, active case without a team has an open team search» (*visit/schedule fact*). R2 adds a derived exception with an existing priority class; it routes to Operations, decides nothing and assigns nothing.

## AI leverage
1. **Remove:** nobody has to look through «Fallstatus» for lost cases. 2. **Rules:** existing matching rules. 3. **Monitor:** the derived exception shows continuously. 4.-7. No AI; the team decides; Operations completes data only.

## Gates
- `cra-gate` on the head (safety);
- `uxa` (label and next-step text, one line);
- `lca` is informed only: the exception shows only what OPS1 already shows (case label, region, missing items, no health fields).
- ADR by `eng`: reuse or new row, the unique-constraint check, and whether reopen resets `ready_for_matching_at`.

## Out of scope
Every other Δ of B1; the readiness tiers; any change to who may reopen.

## Open questions for engineering
1. A unique constraint on `matching_requests.case_id`? (UNKNOWN)
2. Is the call made in `reopen_case`, in `open_matching_if_ready`, or in both?
3. Can a team be inactive while it holds an active case (R4)?
