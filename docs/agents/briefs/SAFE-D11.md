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

## PO 2026-11-12 17:39 CET, scheduled run: merge state and placed findings (the PO ran no tests)

- **Merge state of #1143 (head `7e191ec`):** not merged. Section 4 condition 5 and the brief's gate «`uxa` (label and next-step text)» are open: no `uxa` statement on the two labels «Wiedereröffneter Fall ohne Team» and the inactive-team type exists (the `uxa` review of 15:51 predates the texts). `ci` on `7e191ec`: `app`, `db`, `e2e`, `ui-screenshots` all `success` (check runs read at 17:58; `e2e` 131327090970). `cra-gate: #1143 977880c clear` covers `7e191ec`: `git diff 977880c 7e191ec -- src supabase tests e2e` is empty (journal and status row only; AUT-50). R2 e2e is delivered (`safe-d11.spec.ts`, `e2e` 164 passed on `977880c`, read from the `eng` journal 17:18 and `cra` 17:29). Merge as soon as `uxa` has spoken and `ci` is 4/4 on the then current head.
- **CGR-194 (`cra`, advisory): placed as a SAFE-D11 acceptance condition, not a merge condition.** R1 asks for the derived fields «with pgTAP»; the code meets it (unchanged first-search insert), the test does not assert it. Before acceptance, a pgTAP assertion on the new row of R1 checks `required_qualification`, `urgency`, `referral_type`, `response_due_at` (new deadline from the time of reopening, PO decision 15:39 on ADR-184) and `first_refusal_until` against the values a first search of the same case gets. It may come in a follow-up PR inside SAFE-D11; `ci-repeat` 10/10 then runs on the merge commit that contains it.
- **CGR-195 (`cra`, advisory, S2 before real data): accepted as a known gap of the simulation gate.** R4 makes the inactive-team case visible (P2, never auto-assigned) but nothing resolves it in the app. Recorded for the Abnahmeakte as «sichtbar, nicht lösbar in Phase A»; the resolution (hand-over, responsible team during a hand-over) is placed in **B1.3** ([B1](B1.md)). Responsibility during a hand-over is a question for `lca` (CGR-195 (3)) and the Clinical Owner; the PO sets no rule.
- **`eng` finding 1 (journal 17:18): the R2 state has no form in the app.** `/intake` lists only cases never ready, and a funding fact on a ready case needs a reason the form does not send (`src/features/intake/commands.ts:199`). The next step «Fehlende Angaben ergänzen» therefore has no screen for a reopened case. Decision: **not a SAFE-D11 merge condition** (the app cannot produce R2 today; R1 is the app path) and **not added to B1.1** (scope fixed by FE-071 (4)). Placed in **B1.1b** (completion of intake facts, with REF2): `/intake` also lists a reopened case that is not ready, with a reason field; e2e from the exception to the completed fact. Recorded as a known gap in the acceptance.
- **`eng` finding 2: the exception detail shows the item code (`insurance_type`).** Goes to `uxa` together with the label gate; the words are part of the `uxa` gate line.

## PO 2026-11-12 20:39 CET, scheduled run: merged, not accepted; follow-up scope (the PO ran no tests)

- **Merged:** #1143, head `7e191ec`, merge commit `c6b0ff8`, title «PO merge #1143: SAFE-D11 reopened case search or exception (head 7e191ec)». Record comment 6834033486 with the seven conditions: `ci` 43259624651 on the head 4/4 `success` (check runs read), `mergeable_state` `clean`; `cra-gate: #1143 977880c clear` with `git diff 977880c 7e191ec -- src supabase tests e2e` empty (AUT-50); `uxa: #1143 7e191ec clear` (comment 6832893361, report 19:48); 0 reviews, 0 review threads; no code change on `recovery/main` between the PR base `daa7360` and `78cf9e4`. CI on the merge commit: push run 43292630799, `app`, `db`, `e2e`, `ui-screenshots` all `success` (job conclusions read 20:55).
- **Not accepted yet.** Two acceptance conditions remain, delivered in **one follow-up PR inside SAFE-D11** (the only Engineering feature work allowed until acceptance; branch `fix/` or `feature/`, red-first not required for a test-only assertion, required for the UXR-181 change):
  1. **CGR-194** (as placed 17:39): pgTAP on the new R1 row: `region`, `urgency`, `referral_type`, `required_qualification` equal the withdrawn row's, with a fixture that needs a registered nurse; `response_due_at` = `private.response_due(org, type, reopen time)`; `first_refusal_until` set and ≤ `response_due_at` for the returning team.
  2. **UXR-181 (`uxa`, medium), placed here:** the detail of `case_reopened_no_team` **and** of `case_not_ready` is built from the stored reason of each readiness item (`m ->> 'reason'`, joined by «; »), never from the item code. Both types read the same `private.case_readiness` output in the same derived function, so one fact gets one wording (DESIGN_SYSTEM §4, PROPOSED). The reason texts are existing stored words and stay word for word; no new wording. Tests: e2e `safe-d11.spec.ts` asserts «Versicherungsart fehlt oder unbekannt» and **not** `insurance_type`; pgTAP 130 asserts the detail equals the reason text; the existing `case_not_ready` tests are adjusted, not removed. Migration `create or replace` only, no grant, policy or column.
  - Gate: `cra-gate` on the follow-up head (the detail is an exception text, `cra` UXR-170 group 4); `uxa` informed.
- **UXR-183 (low): not in the follow-up.** The next-step wording of `case_reopened_team_inactive` and the ending «; nie automatisch zuweisen» are exception texts that `cra` fixes, and the open question «who is responsible meanwhile» is CGR-195's (`cra`, `lca`). Placed in **B1.3** with CGR-195; until then the honest text stays.
- **UXR-182 (low):** stays in B1.1b (placed 17:39).
- **Acceptance gate:** «Simulation, synthetic data». Accepted only on the merge commit of the follow-up: `ci` green, `ci-repeat` 10/10 (`db`, `e2e`) read from the job logs, BD flow green, record in `docs/product/ABNAHMEAKTE.md`. Known gaps to record then: CGR-195 «sichtbar, nicht lösbar in Phase A», UXR-182 (no app form for a reopened, not-ready case), UXR-183.

## PO 2026-11-12 21:39 CET, scheduled run: CGR-194 (b) added to the follow-up (the PO ran no tests)

- **Source:** `cra` review 21:35 (PR #1149, head `357765b`; not merged in this run, see journal 21:39). The finding text is the one in that PR's `CLINICAL_GOVERNANCE.md` section.
- **Criterion 1 of the follow-up (CGR-194) now reads, in addition to 20:39 (1):** with a fixture whose first search lies in the past, the new R1 row's `first_refusal_until` is **after the reopen time**, and its `response_due_at` is **after the reopen time** and **differs from the withdrawn row's**. Reason (`cra`): «set and ≤ `response_due_at`» alone also passes when the row copied a stale window; the test must tell a fresh derivation from a copy.
- **UXR-181 gate condition (`cra`):** the visibility of `case_reopened_no_team` and `case_not_ready` stays as it is (coordination roles only); the pgTAP 130 negatives stay unchanged and pass.
- Everything else of §PO 20:39 stands. `cra-gate` on the follow-up head checks CGR-194 with (b).

## PO 2026-11-12 22:39 CET, scheduled run: pre-review of #1151 by reading the diff (not a merge, not an acceptance; the PO ran no tests)

#1151 is still a **draft** at head `aba49e8` (docs commit after the fix `11816af`); `e2e` on `aba49e8` was `in_progress` at 22:45, `app`, `db`, `ui-screenshots` `success`; no `cra-gate` comment on any head. Merge waits for: ready for review, `ci` 4/4 `success` on the then current head, `cra-gate` on that head (`PO_MERGE_PROCESS.md` §4). The table records what the diff shows against §PO 20:39 and §PO 21:39 so the merge run need not re-read it; the PO re-checks it if the head changes in `src`, `supabase` or `tests`.

| Criterion | Result (diff read, not run) | Evidence |
|---|---|---|
| CGR-194: R1 row's region, urgency, referral type, required qualification equal the withdrawn row's; fixture needs a registered nurse | covered | pgTAP `131_safe_d11_r1_derived_fields.test.sql` (plan 14); fixture RET1, hospital referral, needs assessment not done (J3) |
| CGR-194: `response_due_at` = `private.response_due(org, type, reopen time)` | covered | 131, assertion against the reopen time `t1` |
| CGR-194 (b): `first_refusal_until` and `response_due_at` after the reopen time, `response_due_at` differs from the withdrawn row's | covered | 131: first search at `t0`, reopen at `t0` + 7 days; the withdrawn row's windows end before `t1`, so a copied row fails |
| UXR-181: both details from the stored reason (`m ->> 'reason'`, «; », readiness order), never the item code | covered | migration `0126`: patch of `private.derived_exceptions`, find must match exactly twice, marker UXR-181; reason texts not copied |
| UXR-181: e2e asserts «Versicherungsart fehlt oder unbekannt» and not `insurance_type` | covered | `tests/e2e/safe-d11.spec.ts` (2 lines changed) |
| UXR-181: pgTAP 130 asserts detail equals reason; existing `case_not_ready` tests adjusted, not removed | covered | 130 plan 34 → 37 (exact detail for one and two missing items; no double exception for D11M); 019 #15 adjusted to the reason words |
| No grant, policy or column; visibility unchanged; 130 negatives unchanged (`cra` 21:39) | covered by reading | `0126` revokes the temporary patch function and `derived_exceptions` from `public`, `anon`, `authenticated`; the changed lines in 130 are positive assertions only |
| Red first for UXR-181 | stated in the PR | `ci` 43308442526 on `e64990d`: `app`, `db`, `e2e` failure on the new assertions; green `ci` 43310111560 on `11816af` (PR body; job conclusions to be read by the merge run) |
| `cra-gate` on the head | open | none yet |

Observation (no finding): the 131 clock fixture uses two Tuesdays 09:00 Zurich in the past, one week apart; no DST change lies between them in November, so it should not add `ci-repeat` variance. `ci-repeat` 10/10 on the merge commit decides.

## Out of scope
Every other Δ of B1; the readiness tiers; any change to who may reopen.

## Open questions for engineering
1. A unique constraint on `matching_requests.case_id`? (UNKNOWN)
2. Is the call made in `reopen_case`, in `open_matching_if_ready`, or in both?
3. Can a team be inactive while it holds an active case (R4)?
