---
id: COVER1
title: Cross-team cover without a dispatcher
author: po
status: approved
updated: 2026-10-22
---

# COVER1 — Cross-team cover without a dispatcher

## PO note — 2026-10-23 15:25: second condition before cover is switched on (CGR-28)

Cover stays switched off until D-3. Before it is switched on, two conditions must be met in the same delta review: **CGR-21** (overdue and stuck alerts of a covered visit reach the covering nurse and her team) and, new, **CGR-28** (`cra` 14:30, advisory S2): an absence of the covering nurse also ends her covers in the period, like `withdraw_cover` but without the lead-time limit and with the fixed text "Abwesenheit"; the visit is uncovered again for its own team and Operations. pgTAP: she accepts a cover → records an absence → `covered_by` is empty → `visit_uncovered` for the original team.

## PO acceptance — 2026-10-22 16:15: accepted (switched off; performing a cover waits for D-3)

Reviewed on merged evidence: #114 (merge f717074; its own CI run was cancelled by the next push, the same code is green on every later merge commit, latest 57962ee), migration 0029, pgTAP 029 (27 assertions) and the amended pgTAP 028, the two-session check `scripts/db-concurrency/cover-accept.sh` (CI step "Concurrency checks", green), `cover-section.tsx`. The cover KPIs are tested in AN1's PR #124 (pgTAP 032), which is reviewed with AN1. **The PO did not run the tests**; results come from reading the migrations, the tests and the CI runs.

| Criterion (14:30 list and 14:45 addendum) | Result | Evidence |
|---|---|---|
| Cover off until D-3, per organisation, default off; `accept_cover` returns `disabled` | met | `cover_settings.cover_enabled` default false; `cover_open_visits` requires it; pgTAP 029 "cover is off by default", "nobody is offered", "acceptance is refused", "no offer is recorded" |
| A covered visit stays safe until it can be performed | met | acceptance sets `covered_by`, not the responsible member; pgTAP 029 "the case team keeps its uncovered flag", OPS1 "Übernahme ohne Zugriff" P2, and P1 inside 4 h; the plain uncovered exception is replaced, not duplicated |
| She can perform the visit once access exists | deferred to D-3 | not built; the brief allows it. Delta review when D-3 is answered |
| Withdraw with a reason up to 4 h; offered again; case team sees it | met | `withdraw_cover`; pgTAP 029 "only the covering nurse", "needs a reason", "not inside the last 4 h", "offered again", "the case team sees it in its plan log"; UI form on `/field` |
| Honest UI text | met | `cover-section.tsx`: no promise of name or address; says the team coordinates until D-3 |
| Negative tests: other organisation, outside the window, two parallel sessions | met | pgTAP 029 "another organisation cannot accept", "outside the window nobody can accept" (before the window; after the window the same predicate in `cover_open_visits` applies); two-session script: exactly one `ok`, one `taken`, one accepted event |
| Offer events at the right time | met, hosted job unverified | pg_cron job `navora-cover1-events` every 10 min where available, page-load sync as backup. Hosted check waits for staging (D-2); owner task recorded in the PLAN2 status row |
| Two empty regions never match | met | pgTAP 029 "teams without a region are not neighbours" |
| Addendum: the covering nurse sees nothing else of the case | met | pgTAP 029: 0 rows from `care_visits`, `field_visits`, `team_cases`; `my_covers` returns only her visit |
| Addendum: needs assessment never to a care assistant | met | pgTAP 029 "not offered", "nor can she accept it" |
| Addendum: KPIs tested | in AN1 | pgTAP 032 in #124 (cover without Operations 50 %, median 10 h); judged in the AN1 review |

**Why accepted.** The patient-safety finding is resolved: in the shipped state nobody can accept a cover, and if an organisation switches it on, a covered visit stays flagged for its team and becomes P1 for Operations until it can actually be performed. The mechanism (offer without identity, atomic acceptance, withdraw, events, regional and qualification rules) is complete and tested. What is missing is the one step that needs an owner answer (D-3), so holding the item open would block nothing engineering can do.

**Care-model impact:** none yet in the field, because cover is off. Its value (no dispatcher, no phone chain) starts the day D-3 allows the visit-bounded read; HAND1 then gives the covering nurse the context a colleague would otherwise phone through.

**Deviations, decided:** acceptance after the window closed is covered by the same predicate as before the window: **accepted** without a separate test. Hosted pg_cron unverified: **accepted** until staging exists (D-2). The delta after D-3 must include the e2e from the 14:30 list (perform and sign one covered visit, read nothing else and nothing after the final report).

## PO addendum — 2026-10-22 14:45 (adds to the 14:30 review, same verdict)

- [ ] **The covering nurse sees nothing else of the case.** pgTAP: after acceptance she gets 0 rows for the case's other visits from `care_visits`, `field_visits(date)` and `team_cases()`, and `my_covers()` returns only her visit. This is the brief's own negative test.
- [ ] **Needs assessment:** a needs-assessment visit is never offered to, or accepted by, a care assistant. pgTAP.
- [ ] **KPIs tested:** `cover_without_operations` and `cover_median_hours` return the expected values for seeded offers. pgTAP.

## PO review — 2026-10-22 14:30: changes-requested

Reviewed on merged evidence: #99 (merge d5f9dd8, CI green on the merge commit), migration 0028, ADR-045, pgTAP 028. No e2e test exists for cover. **The PO did not run the tests**; results come from reading the migration and the tests.

| Criterion | Result | Evidence |
|---|---|---|
| Offer at the lead time to qualified members of other teams in the region | met | window > 4 h and ≤ 24 h before start; other active team, same organisation and region; RN only for B and needs assessment; pgTAP 028. Two teams with an empty region count as the same region |
| No client identity before acceptance | met | offer: date, times, town, team name, services, minutes, qualification. No name, address or postcode |
| Atomic first acceptance; case, team and primary nurse unchanged | partial | row lock and unique accepted event; pgTAP 028 tests a second acceptance one after the other, not concurrently. Case, team and primary nurse unchanged (pgTAP) |
| Covering nurse gets context for that visit until the report is final | deferred | waits for D-3, as the brief allows |
| J6 not-primary; J5 and F6 | partial | J6 tested. She cannot perform or sign the visit, so J5 and F6 are not reachable |
| Fallback to OPS1 | partial | OPS1 already shows the visit from 24 h, not from 4 h |
| Offered, accepted, expired recorded and audited; own team sees who covered | met with a gap | append-only `cover_events` with audit; events are written only when someone loads `/field` |
| AN1 metrics | partial | see the AN1 review |
| Negative tests | partial | other organisation sees no offers; care assistant gets no B offer; own team gets no offer. Missing: acceptance from another organisation, after expiry, concurrent double acceptance |

**Why changes-requested (patient safety).** On acceptance the visit gets a responsible nurse, so it stops counting as uncovered: the team's flag and the OPS1 exception disappear. But the covering nurse cannot see the visit in her day view and cannot start it (pgTAP 028 asserts that `depart_visit` fails for her), and she has no address, care plan or safety information until D-3. The visit looks covered and can silently not happen. The UI also promises "Name und Adresse siehst du erst nach der Übernahme", which is not true. Patient safety is a precondition, so COVER1 must not be usable in this state.

- [ ] **Cover is off until D-3.** A per-organisation setting `cover_enabled`, default **off**; while off, no offers are created and `accept_cover` returns `disabled`. pgTAP.
- [ ] **A covered visit stays safe until it can be performed.** While the covering nurse cannot start the visit, the visit keeps an OPS1 exception "Übernahme ohne Zugriff" (P1 from 4 h before start) and the case team's uncovered flag. pgTAP: after acceptance with no access, the exception exists.
- [ ] **She can perform the visit once access exists.** Built behind D-3: after acceptance the covering nurse sees that one visit in her `/field` day view and can depart, start, complete and sign it (F1–F4, F6, F7), and reads the visit card context (care goals, safety alerts, HAND1 entries, address) of that case only until the report is final. pgTAP and e2e prove she reads nothing else of the case and nothing after the report is final.
- [ ] **Withdraw:** the covering nurse can hand a cover back with a reason up to 4 h before start; the visit is offered again and the case team is notified in its view. pgTAP.
- [ ] **Honest UI text:** no promise of name and address until the access part exists.
- [ ] **Negative tests:** acceptance from another organisation, acceptance after the window closed, and two acceptances in parallel sessions (only one succeeds).
- [ ] **Offer events at the right time:** offered and expired are recorded when the visit enters and leaves the window (job or trigger), not when someone loads `/field`.

**Deviations, decided:** OPS1 showing the uncovered visit from 24 h: **accepted**; visibility early is the safe side. Region equality: two empty regions must **not** match (add to the pgTAP). Lead times 24 h / 4 h: accepted (D-21).

## Problem
When a team cannot cover a visit (illness, peak load), the traditional fix is a dispatcher or a phone chain. Buurtzorg leaves it to the team and its coach, and teams are islands. In NAVORA today an uncovered visit becomes an Operations exception (J3, OPS1). A person must then find someone. This is coordination work that the network can do itself.

## Users and journey step
Nurses of neighbouring teams in the same organisation and region; the visit's own team; Operations only as fallback. Journey: Planning → Visit.

## Outcome
An uncovered visit is offered automatically to qualified nurses of neighbouring teams. One accepts it in a tap, the visit happens, and nobody had to phone anyone.

## Acceptance criteria
- [ ] When a visit is still uncovered at a configurable lead time before its start (pilot default: 24 h), it is **offered to members of other active teams in the same region and organisation** who have the required qualification (`registered_nurse` for category B and needs assessment).
- [ ] The offer shows only what is needed to decide: date and time window, area, services with category and minutes, required qualification. **No client identity before acceptance** (same rule as J2).
- [ ] The first acceptance assigns that one visit to the accepting nurse, atomically. The case stays with its team, and the primary nurse (J6) is unchanged.
- [ ] After acceptance, the covering nurse sees the **same minimal visit context as the team's own nurses** (F1–F4), for that visit only. Access ends when its report is final (F6). Whether this temporary cross-team access is permitted is part of owner decision **D-3**. Until D-3 is answered, the offer and acceptance work, and context access waits.
- [ ] The visit counts in J6 as "not primary", is billed as usual (J5), and the report is signed by the covering nurse (F6).
- [ ] If nobody accepts before a second lead time (pilot default: 4 h before start), the existing OPS1 exception takes over unchanged.
- [ ] Every offer, acceptance and expiry is audited. The visit's own team sees who covered.
- [ ] Measured in AN1: uncovered visits resolved without Operations, and median time to cover.
- [ ] Negative tests: other organisations never see offers; members without the required qualification never see B or assessment offers; the covering nurse never sees the case's other visits.

## Out of scope
Pay supplements for cover (financial, D-14), cover across organisations, automatic assignment without acceptance.

## Constraints and references
`DOMAIN_RULES.md`: the team plans cover itself; COVER1 extends this to the network without a dispatcher. J2 offer pattern (ADR-027, ADR-033); J3 qualification rules; J6; OPS1. Cross-team data access: D-3 (`owner`).

## Open questions for engineering
- Can the J2 offer machinery be reused for visit-level offers?
