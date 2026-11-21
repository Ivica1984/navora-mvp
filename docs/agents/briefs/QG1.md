---
id: QG1
title: Quality signals and quality hold
author: po
status: approved
updated: 2026-10-22
---

# QG1 — Quality signals and quality hold

## PO note — 2026-10-23 15:25: condition CGR-13 met (wording)

"Qualitäts-Stopp" no longer appears in `src/` (PO search on 81f1a47); the UI says "Abrechnungssperre" with the sentence that only billing is blocked, on `/field`, `/operations` and the billing preview (`quality-section.tsx`, `holds-panel.tsx`, `billing-preview.tsx`, `features/quality/rules.ts`, `features/billing/rules.ts`); unit `quality-rules.test.ts` and e2e `quality.spec.ts` updated; CI green on 20a3566 and 81f1a47. `cra` 15:00 (PR #203): closed for the wording. QG1 stays `accepted`; what a hold stops clinically and who may lift it stay **D-16** (`clinical`). **The PO did not run the tests.**

## Clinical review gate — 2026-10-22 23:00: stays accepted, one condition

Clinical Governance Report 2026-10-22 22:30 considered.

| Finding | Severity | PO decision |
|---|---|---|
| CGR-13 | advisory now, blocking before real data | condition: until D-16 is answered, the UI labels a hold "Abrechnungssperre" (billing hold), delivered in [CSR1](CSR1.md). What a hold stops is decided by `clinical` (D-16) |

## PO acceptance — 2026-10-22 12:00: accepted (operational once D-16 is answered)

| Criterion | Result | Evidence |
|---|---|---|
| Record from the visit: type, severity, time, case, visit, author | met structurally | #41 (ADR-036); **type list ships empty until `clinical` answers D-16**, recording is refused and `/field` says so |
| Team sees; serious events also coach and admin; other teams never | met | #41 |
| Status open → in review → closed, owner, note, audited | met | #41 |
| Hold by type or manual decision; lifted only by authorised role with reason | met | coach or admin (stricter than brief) |
| J5 never counts a held visit | met | `visit_has_open_hold`, used by J5 (#43) |
| No automatic scoring, no AI | met | — |

Deviations accepted: no quality-specialist role until D-3; minor events not readable by Operations through the table. Nothing clinical was invented, as required. PO did not run the tests; evidence is the merged test suite and green CI on the merge commit.

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
