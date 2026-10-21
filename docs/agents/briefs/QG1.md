---
id: QG1
title: Quality signals and quality hold
author: po
status: draft
updated: 2026-10-21
---

# QG1 — Quality signals and quality hold

## Problem
Quality is the promise to clients, partners and the canton, and `ARCHITECTURE.md` places a Quality Gate before any billing fact. Today warning signs from a visit (fall, wound deterioration, medication problem, acute decline, social situation) sit in free-text observations, and `quality_events` has no workflow. Nothing stops a disputed visit from being billed.

## Users and journey step
Nurse (records), assigned team (sees), coach and quality specialist (serious events). Journey: Dokumentation → Qualität → Billing-Fakten.

## Outcome
A nurse flags an event from a short list during the visit; the team sees it on the case at once, serious events reach coach and quality, and a visit with an open hold never counts as billable until a person reviews it.

## Acceptance criteria
- [ ] A quality event can be recorded from the visit with type (from a clinically approved list), severity, time, case, visit and author.
- [ ] Events are visible to the assigned team; serious events also to coach and quality specialist; invisible to other teams.
- [ ] Each event has a status (open, in review, closed) with owner and closing note; transitions are audited.
- [ ] Defined event types, or a manual decision, set a quality hold on the visit; only an authorised role lifts it, with a reason.
- [ ] Billing facts (J5) never count a visit with an open hold.
- [ ] No automatic clinical scoring and no AI risk prediction in QG1.

## Out of scope
Cantonal quality reporting, MQI, risk prediction, incident reporting to authorities.

## Constraints and references
`ARCHITECTURE.md` Quality/Clinical Intelligence; `PRODUCT_REQUIREMENTS.md` (keine ungeprüften Prognosen). Event types, severities, hold rules and roles: D-16 (`clinical`).

## Open questions for engineering
- Can the existing `quality_events` table carry this, or does it need a new model? Check against the live schema first.
