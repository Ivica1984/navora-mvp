---
id: COVER1
title: Cross-team cover without a dispatcher
author: po
status: approved
updated: 2026-10-22
---

# COVER1 — Cross-team cover without a dispatcher

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
