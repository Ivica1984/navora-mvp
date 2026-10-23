---
id: OPS1
title: Operations exception center
author: po
status: approved
updated: 2026-10-23
---

# OPS1 — Operations exception center

## PO review — 2026-10-23 13:20: condition CGR-25 met (awaits clinical review of 0045)

Delivered by CSR1 part 7 completion (#192, head cf61529, CI run 39941539181 green; merged as 7e5013b, CI green on the merge commit and on 1540f84, checked through the API). The PO read migration 0045 in full, pgTAP 045 (46 assertions), the changed pgTAP 019 count, the new e2e test in `lifecycle.spec.ts`, ADR-056, CR-050 and `clinical/remediation/CGR-25.md`. **The PO did not run the tests.**

| Criterion (CSR1 CGR-25) | Result | Evidence |
|---|---|---|
| An `interrupted` visit raises an exception for its team (`/field`, `/team`) | met | 0045 §4a derives `visit_interrupted` from `status = 'interrupted'` without a follow-up decision; §4c adds it to `team_visit_alerts`; pgTAP 045 "the team sees the interrupted visit", "every member of the team sees it (care assistant)", "a nurse of another team does not"; e2e: card "Entscheid offen", `/field` queue and `/team` alert at 390 px |
| … and for Operations; type and priority PROVISIONAL, not escalating | met | `exception_rules` row P2, no threshold, no escalation (pgTAP 045 "P2/-/-"); not a safety exception; `operations_exceptions` lists it (pgTAP 045 "Operations sees the interrupted visit (P2)") |
| Closed by a team member or a coordination role with a reason from the short list | met | `record_interruption_followup` (team member or coordinator; audited, idempotent, row lock, unique index): pgTAP 045 team member "Folgeeinsatz geplant" and coordinator outside the team "nicht mehr nötig" → gone for team and Operations; actor and audit row asserted; outsiders and another organisation `rejected` |
| A close without a reason is refused | met | OPS1 hand close returns `cause_persists`, `closable = false`, refused close writes no event (pgTAP 045); command refuses null, off-list and `other` without a note (22023); a second decision `already_decided`; an earlier close row hides it neither from Operations nor from the team |
| Detail shows the interruption reason and note; for `client_transferred` the next planned visit | met | §4a detail text; pgTAP 045 asserts the next planned visit for `client_transferred` and no next-visit line for another reason |
| Rule register: one PROVISIONAL row referring to D-31 | met | CR-050 PROVISIONAL, D-31 |
| No regression | met (CI) | pgTAP 019 counts 16 types; app, db and e2e green on head, merge commit and 1540f84 |

**Decisions on the OPEN items engineering listed (all interim until D-31, no rule assumed):**
- "Folgeeinsatz geplant" is a statement; nothing checks that a visit was planned. **Accepted** as the strict default asked for in CSR1 (the criterion asked for a reason, not a plan). Product follow-up recorded as a challenge row (link the decision to a visit planned in the same step); measured first in AN2.
- Who may decide, including whether a care assistant may record "nicht mehr nötig", and how a decision is corrected: **not answered by the PO**; added to D-31 (`clinical`).
- A take-over by Operations stays possible and is auto-closed with a note when the team decides (pgTAP 045). Accepted: Operations stays a safety net, the team holds the resolution.

OPS1 stays **accepted**; the CGR-25 condition is met in code and is confirmed by the next `cra` section on 0045. Remaining condition: CGR-26 (CSR1 part 8).

## PO review — 2026-10-23 12:15: condition CGR-22 met (awaits clinical review of 0044)

Delivered by CSR1 part 7 (#188, merged as e215924, CI green on head 678b12e, the merge commit and 39b9994). The PO read 0044 §2–§4, pgTAP 044 (CGR-22 block), the changed pgTAP 039 assertion and the e2e change; **the PO did not run the tests**.

| Criterion (CSR1 CGR-22) | Result | Evidence |
|---|---|---|
| Hand close of `visit_uncovered` refused while nobody is responsible | met | `handle_exception(…,'close',…)` returns `cause_persists` via `private.exception_closes_with_cause`; pgTAP 044 refused close writes no event row; take over and note still work |
| An earlier hand close no longer hides it | met | `operations_exceptions()` lists it whatever the last event; pgTAP 044 "a close written before 0044 no longer hides it" |
| It ends with its cause: assigning someone, starting, cancelling | met | pgTAP 044: started, cancelled and a responsible member set → gone |
| Priority unchanged (D-28) | met | still P2, not escalating; `exception_is_safety` false for it (pgTAP 044) |
| UI | met, weak test | e2e `operations.spec.ts` checks no "Schliessen" on any listed uncovered card; the loop passes vacuously when none is listed (time-of-day seed). Acceptable because the refusal is enforced and tested in the database |

**Finding from this review (product gap, not a defect of #188):** the "someone responsible" ending is simulated in pgTAP by a direct table update, because **no command lets a team member take responsibility for an existing uncovered visit** (engineering OPEN item, 11:45). So after CGR-22 an uncovered visit that is not yet due can end only by being cancelled or by a cover; Operations sees it and can do nothing. **Decision (PO, within product authority, J3 model accepted 2026-10-21: team plus optional responsible member):** ABS1's one-tap take ("Offen im Team") applies to **every** uncovered visit of the team, whatever made it uncovered; criterion added to `ABS1.md`. This does not answer D-6 (`clinical`), which may still change the assignment model.

OPS1 stays **accepted**; the CGR-22 condition is met in code and is confirmed by the next `cra` section on 0044. Remaining conditions: CGR-25 (CSR1 part 7), CGR-26 (part 8).


## PO acceptance — 2026-10-23 11:25: accepted with conditions (clinical gate passed)

The Clinical Governance Report section 2026-10-23 10:29 (`reports/CLINICAL_GOVERNANCE.md`, merged with #184 as 8551ccb) reviewed merge commit a78fa7e (migration 0042, pgTAP 042) and states for OPS1: **no blocking finding; the PO may accept, recording CGR-22 and CGR-25 as conditions**. CGR-20 closed (interim rule PROVISIONAL, D-31). CI green on a78fa7e (app, db; e2e green on its second run after one cancelled run; rechecked through the API this cycle). **The PO did not run the tests**.

| Criterion | Result | Evidence |
|---|---|---|
| CGR-04, CGR-05, CGR-06 (07:10 table), CGR-20 (10:15 table) | met | unchanged; confirmed by the `cra` sections 06:30 and 10:29 |
| Clinical gate: latest `cra` section covers 0042 with no blocking finding | **met** | section 10:29, *Gate status per item* |

**Conditions (advisory findings, decided; each is a CSR1 criterion, OPS1 does not wait for them):**
- **CGR-22 (S2):** an uncovered visit with nobody responsible is not silenced by hand (CSR1 criterion since 07:10).
- **CGR-25 (S2):** ending a visit as *not completed* removes every signal about care still due. Strict provisional default added to CSR1: an `interrupted` visit raises a non-escalating exception for its team and Operations, closed by a person with a reason; for `client_transferred` the detail names the case's next planned visit. Whether a follow-up is required, by whom and how fast is added to D-31 (`clinical`).
- **CGR-26 (S3):** a coordinator's *not completed* end is terminal, so an error cannot be corrected. Added to CSR1: `/field` shows the performer who ended her visit and why; AN2 counts coordinator-recorded ends of a visit in progress. How an end recorded in error is corrected is added to D-31.

**Why this matters for the care model:** OPS1 is a safety net that reaches a coordinator only when the team's own record says something is wrong; with CGR-25 the team, not a dispatcher, is the first to see care that is still due.

**PO status: accepted** (with the three conditions above).

## PO review — 2026-10-23 10:15: CGR-20 met; acceptance awaits clinical review

Reviewed CSR1 part 5: #179 (head 638bf5b, CI run 39918776217 green: app, db, e2e; merged as a78fa7e, CI green on the merge commit and on 6545bf5). The PO read migration 0042, pgTAP 042, the e2e test added to `tests/e2e/lifecycle.spec.ts`, the HAND1 label change in `src/features/handover/rules.ts`, ADR-053 and CR-042. **The PO did not run the tests.**

| Criterion (CSR1, CGR-20) | Result | Evidence |
|---|---|---|
| Audited, idempotent command ends a `started` or `paused` visit as *not completed*, mandatory reason from the list, actor recorded | met | 0042:99-136 `end_visit_not_completed` (reason list, `other` needs a note, `begin_command` idempotency, row lock `for update`, `wrong_state` outside started/paused); table check `visit_status_notes_interrupted_reason`; pgTAP 042:104-113 (no reason, unknown reason, `other` without note refused), 122-143 (ok, duplicate, second end refused, reason, note, actor, two audit rows) |
| Allowed for the performer, any team member and a coordination role, whatever the qualification; nobody outside the team or organisation | met | 0042:125-127; pgTAP 042:122 (a care assistant ends a registered nurse's started B visit), 128 (performer, `other` with note), 157 (coordinator outside the team ends a paused visit), 93 and 98 (another team, another organisation: `rejected`); anon has no execute |
| Ends `visit_stuck` through its cause, no hand close | met | pgTAP 042:148-165 (stuck before; gone in OPS1 and for the team after; no hand close written) |
| No billable fact, no F6 report obligation, no `report_not_final`, not counted as completed (AN1, J6) | met | pgTAP 042:180-188, 208 (report draft refused, no billable fact, no working-time fact, needs assessment not counted as done, nothing else written); readers filter on `status = 'completed'` (PO read 0032:44 AN1, 0021:131 J6) |
| Visible as "nicht abgeschlossen · <Grund>" on `/field` and in HAND1; recorded observations unchanged | met | pgTAP 042:200-202 (`field_visit_status_notes` returns the reason); `visit-lifecycle.tsx` `interrupt-reason`; HAND1 lists `visit_status_notes` rows (0033), label `visit_interrupted` and unit test `handover-rules.test.ts` |
| `/field` offers it next to "Einsatz abschliessen" on a started or paused visit; nothing after the end | met | e2e at 390 px: button absent before start, present next to "Einsatz abschliessen" after start, reason required, status and reason shown after save and after reload, no complete/resume/start/report afterwards, no sideways scroll |
| Not completed cannot be completed, resumed, restarted or cancelled; a direct status update cannot skip the reason | met | pgTAP 042:113 (direct update to `interrupted` refused), 170-176 (no complete, resume, restart, cancel, direct complete) |
| Rule register: one `PROVISIONAL` row referring to D-31 | met | CR-042 in `clinical/CLINICAL_RULE_REGISTER.md` |
| No regression | met | CI green on head, merge commit and 6545bf5 (pgTAP all files, unit, e2e) |
| Clinical gate | **awaiting** | no `cra` section covers 0042 yet (newest section 2026-10-23 06:30) |

**Deviations, decided:**
- `security definer` instead of the brief's invoker recommendation: **accepted**. The transition list stays closed to app users, so the reason can never be skipped (pgTAP 042:113); membership and organisation checks are inside the command.
- Observations after a not-completed end are refused (as for every other end state): **accepted** as the interim safe default; whether care already given needs a report stays in D-31.

**Why this matters for the care model:** the team now records what really happened instead of choosing between a permanent alarm and a false completion. That keeps the record truthful (no report or billable minutes for care not given) and lets any colleague, not a coordinator, close a broken-off visit, which ABS1 needs.

**Decision:** CGR-20 met. OPS1 stays `changes-requested` only for the clinical gate: accepted without another PO round once a `cra` section on a78fa7e holds no blocking finding.

## PO review — 2026-10-23 07:10: CGR-05 and CGR-06 met; changes-requested for CGR-20 (clinical gate)

Reviewed CSR1 part 2: #165 (head 74f3acf, CI run 39900134825 green: app, db, e2e; merged as c987e83) with the Clinical Governance Report section 2026-10-23 06:30 (`reports/CLINICAL_GOVERNANCE.md`, merged with #167 as 6fc517a). The PO read migration 0039 (`private.exception_is_safety`, `handle_exception`) and the report's citations of pgTAP 039. **The PO did not run the tests.**

| Criterion | Result | Evidence |
|---|---|---|
| CGR-05: a serious quality event stays an exception while `in_review`, escalation continues | met | 0039:59-64 `quality_serious_open` while `open` or `in_review`, same key, clock from `created_at`; pgTAP 039:40-66 (stays in review, P1 continues, not closable, ends on `closed`) |
| CGR-06: a P1 safety exception cannot be silenced while its cause persists, incl. `no_show_open` | met | 0039:25-32 safety = effective P1 or escalating to P1; `handle_exception` close → `cause_persists` (PO read 0039:132-134); legacy closes ignored; `closable` in `operations_exceptions()`, `/operations` offers "Schliessen" only where closable; pgTAP 039:68-127, 139-145; e2e asserts no close on a P1 card |
| No regression | met | pgTAP 019 and 038 changed on purpose (P1 close now refused); CI green on head; CR-041 PROVISIONAL |
| Clinical gate | **not met** | section 06:30: **CGR-20 blocking (S1) for OPS1** |

**Why changes-requested (CGR-20, confirmed by the PO in 0038:38-45 and 0024:353):** since 0039 a `visit_stuck` exception closes only with its cause, which is right. But a `started` or `paused` visit can end only as `completed`. When a visit is really broken off (client taken to hospital during the visit, nurse called away, started by mistake), the team either lives with a permanent P1 or records a completion for care not given, which creates a report and measured minutes for care that did not happen. An exception center that can only be silenced by a false record is not safe.

**Change (next CSR1 part; testable criteria in `CSR1.md`, CGR-20):** an audited command ends a `started` or `paused` visit as *not completed*, with a reason; it ends `visit_stuck`, produces no billable fact, no report obligation and no completed-visit count until D-31 is answered; `/field` offers it next to "Abschliessen".

**Advisory CGR-22, decided:** a strict provisional default, as a CSR1 condition: the hand close of `visit_uncovered` is refused while the visit is planned and nobody is responsible; it ends by assigning or cancelling. Reason: a hand close 24 h ahead silences the only signal until the visit is already late. Whether an uncovered visit is a safety signal, and at which priority, is added to D-28 (`clinical`).

**Decision:** OPS1 stays `changes-requested`. Re-accepted without another PO round when the CGR-20 criterion is merged with green CI and the next `cra` section holds no blocking finding for it. CGR-22 rides in the same or a later CSR1 PR and does not hold OPS1.

## Clinical review gate — 2026-10-22 23:00: reopened, changes-requested

The PO considered the Clinical Governance Report (`reports/CLINICAL_GOVERNANCE.md`, 2026-10-22 22:30) under the gate (README; D-27). The acceptance below is withdrawn for these findings; the remedy is [CSR1](CSR1.md). The PO did not run tests; evidence is the report's code references.

| Finding | Severity | PO decision |
|---|---|---|
| CGR-04 | blocking | considered; remedy CSR1, thresholds D-28 |
| CGR-05 | blocking | considered; escalation continues until `closed`; remedy CSR1 |
| CGR-06 | blocking | considered; a P1 cannot be silenced while its cause persists; remedy CSR1 |

## PO acceptance — 2026-10-22 12:00: accepted

| Criterion | Result | Evidence |
|---|---|---|
| Exceptions derived from state, all brief sources | met | #39 (ADR-035), 10 types incl. report not final (F6) and serious quality event (QG1) |
| Reason, age, case, team, link; Operations-scoped data | met | #39 |
| Take over, note, close with reason; auto-close with note | met | #39 |
| ≤ 6 KPIs, no matching start, no case editing | met | #39 |
| Thresholds as configuration with Q9 defaults | met | `exception_rules` |

Deviations accepted: a serious quality event shows at once as P2 and becomes P1 after 4 h (safer than the brief); rules change by migration until ADM1. Follow-up: the legacy heuristics below the list are labelled "unvalidated" — remove them when ADM1 ships unless a pilot user relies on one. PO did not run the tests; evidence is the merged test suite and green CI on the merge commit.

## Problem
Self-organisation works only with a safety net: no case waits silently, no visit stays uncovered. `ARCHITECTURE.md` defines Operations as an exception-based control tower, not dispatch. J1–J3 and QG1 create exceptions (blocked cases, overdue offers, uncovered visits, expired orders, serious quality events), but there is no single place that derives them from state. This is the scaling lever of the model: a small Operations group can support many teams.

## Users and journey step
NAVORA Operations. Cross-cutting over Fall → Matching → Teamentscheid → Teamplanung → Qualität.

## Outcome
Operations opens one list of open exceptions sorted by urgency, each with reason, age, case, team and next step; who took it is visible; resolved exceptions close with a trace.

## Acceptance criteria
- [ ] Exceptions are derived from state, never entered by hand: case not ready for matching after a threshold (J1); offer overdue or all candidates exhausted (J2); visit uncovered within 24 h, medical order expired, care-plan review overdue (J3); serious quality event open (QG1); report missing (F6).
- [ ] Each exception shows reason, creation time, case, team and a link to its origin; data limited to what Operations may see.
- [ ] Take over, comment and close are audited commands; closing needs a reason; a fixed cause closes the exception automatically with a note.
- [ ] At most six KPI cards; no matching start and no case editing from OPS1.
- [ ] Thresholds and urgency are configuration, not code. Pilot defaults (Q9):
    - **P1 safety:** serious quality event open longer than 4 hours; uncovered visit within 24 hours for a hospital-discharge case.
    - **P2 continuity:** any other uncovered visit within 24 hours (delivered in #32); all candidates exhausted; offer past its Q8 deadline.
    - **P3 administration:** case not ready for matching 1 working day after the referral; medical order expiring within 7 days or expired; care-plan review overdue; report not final 24 hours after the visit ended.

## Out of scope
Team performance ranking, workforce planning, reporting exports.

## Constraints and references
`PRODUCT_REQUIREMENTS.md` Operations (max. six KPIs, kein Matching-Start). Existing `/operations` attention list (T13 seed coverage, #15): extend it rather than build a second one. Thresholds: Q9.

## Open questions for engineering
- Which exception types the current attention list already derives, and which are new.
