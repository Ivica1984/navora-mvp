---
id: COVER1
title: Cross-team cover without a dispatcher
author: po
status: approved
updated: 2026-10-22
---

# COVER1 — Cross-team cover without a dispatcher

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
