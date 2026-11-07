---
id: ORD1
title: Medical order renewal without chasing the GP
author: po
status: draft
updated: 2026-11-07
---

# ORD1 — Medical order renewal without chasing the GP

## Problem
**Challenge finding (PO, 2026-10-22).** Category B services need a valid medical order (J1, J3). J3 flags an order after its validity end, and OPS1 raises "order expiring". Then a person phones or faxes the GP's practice, waits, chases, and re-types the answer. This is the classic administrative work between home care and GPs. It sits with Operations or a team member, and it is neither care nor coordination of care. When it fails, B visits stop being generated (PLAN2) or billable (J5), so the client's care is at risk for an administrative reason.

## Users and journey step
The primary nurse (J6) and the client's GP (a new external actor, not yet a NAVORA user). Operations handles exceptions only. Journey: Planning → Visit → Billing.

## Outcome
Before an order expires, NAVORA prepares the renewal request from the care plan, and the primary nurse sends it with one tap. The GP confirms it digitally. The order validity updates itself, and nobody phones anyone.

## Acceptance criteria (draft, depends on D-22 and D-9)
- [ ] At a lead time before the order's validity end (pilot default 14 days), the primary nurse gets a **prepared renewal request**. It contains the current care-plan services with KLV category, minutes and frequency, and the GP named in J1. It contains nothing she has to re-type.
- [ ] She reviews it and sends it with one tap. NAVORA adds nothing clinical of its own.
- [ ] The GP receives it through the channel and in the form that D-22 declares legally valid, and confirms, changes or declines it.
- [ ] A confirmation updates the order status and validity (J1/J3) with its source. A change creates a care-plan change proposal for the team. It does not apply itself.
- [ ] If there is no answer at a second lead time, the existing OPS1 "order expiring" exception takes over unchanged.
- [ ] Measured in AN1: share of renewals without a manual step, and days of B care lost to expired orders.
- [ ] Negative tests: no request leaves without the nurse's send; the GP sees only this client's request; other teams and organisations see nothing.

### Conditions placed by the PO 2026-11-07 13:39 (`cra` 13:25, advisory S2; the brief stays a draft)
- [ ] **ORD1-C1 (CGR-156): no unbounded order.** An order end date beyond the maximum validity the applicable rule allows is refused or flagged. The bound is **not set by the PO or `eng`**. `cra` cites KLV Art. 8 Abs. 2 (2020 text: nine months; Abs. 3 is the exception for a helplessness allowance). The consolidated current text is UNKNOWN until `lca` reads fedlex. The bound comes in as a versioned rule row with its source, PROVISIONAL until then (CR-196). The order record keeps an issue date and, where Abs. 3 applies, its basis (D-22 item 4). pgTAP: an end date past the bound is refused or flagged, and a bound change is versioned.
- [ ] **ORD1-C2 (CGR-157): a renewal opens a new needs assessment.** Every renewal or extension of an order (a later end date, or an order recorded again) opens one reassessment task on the ORD0 pattern: never two open at once; closed only by a completed needs-assessment visit; shown in `/team`. How soon it must be done is UNKNOWN (Clinical Owner, CR-197). pgTAP: moving `medical_order_valid_until` later on a case with an active B care plan opens exactly one task, and a second move opens no second task.
- Both conditions also bind any invoicing brief (BILL1) before a real invoice. On synthetic data they are acceptance criteria of whichever of ORD1 or BILL1 is built first.

## Out of scope
New orders at first referral (REF2), electronic patient record (EPD) integration, prescribing medication.

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | Order administration between home care and GP practices |
| Manual activity removed | Phoning, faxing, chasing and re-typing orders |
| Role less necessary | Administrative staff or Operations handling orders; nurse time spent on the phone with practices |
| Continuity of care | No gap in category B care because of an expired order |
| Direct care time | Phone and chasing time goes back to visits |
| Caregiver income potential | Category B visits stay billable (J5) without interruption |
| Long-term operating model | The GP becomes a connected actor in the client's care plan: the first step to integrated care networks (horizon 4) |

## Constraints and references
J1 order status and GP named (ADR-029); J3 order validity rules (ADR-030); PLAN2; OPS1. **D-22 (`legal`):** what form of medical order and renewal is valid for OKP billing (written, electronic signature level, confirmation by secure link) and how the GP is identified. **D-9 (`legal`):** legal basis for sending client data to the GP. Nothing is built until both are answered.

## Open questions for engineering
- Which secure channel (e-mail link, HIN, EPD) is technically realistic for a pilot? This is input for the D-22 answer, not a choice.
