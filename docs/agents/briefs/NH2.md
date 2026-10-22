---
id: NH2
title: Assessment as a by-product of care
author: po
status: draft
updated: 2026-10-22
---

# NH2 — Assessment as a by-product of care (nursing homes, horizon 3)

## Problem
The interRAI LTCF CH assessment determines the care-effort group (PAG), and through it the tariff level of care financing (handbook p. 55). Because insurers control it (p. 3), homes run a parallel organisation:
- coordinators (1 per 8 residents) plan and code;
- supervisors (registered nurses, 1 per 16) control the codings;
- an expert controls by sample and defends the codings in insurer controls (p. 49–53);
- each observation period runs three meetings and a 3-day documentation phase, in which care already in the plan must be documented again as evidence (p. 3–5).

For a 64-resident home that means about 87 to 130 observation periods and about 260 to 390 meetings a year (DERIVED). Analysis: [`NURSING_HOME_TRANSFORMATION.md`](../../product/NURSING_HOME_TRANSFORMATION.md) §1–2.

## Users and journey step
The primary nurse (assesses and codes), the registered nurse of the team (signs per KLV Art. 8a), the physician (informed), the licensed assessment software. Journey: Care → Documentation → Quality → Billing.

## Outcome
The assessment calendar and the observation-period plan run themselves. The evidence for the documentation phase is what the team recorded during care. A traceability check replaces control sampling. The coding stays human and stays in the licensed software.

## Acceptance criteria (draft)
- [ ] An assessment calendar per resident from the home's configured deadline (180 or 270 days, 90 for a short stay; p. 50), with due and overdue items for the team.
- [ ] A generated observation-period plan (days, and which items need documentation from whom) in the team's day view. The primary nurse confirms or changes it.
- [ ] Support given during care is recorded as structured events: who, when, which activity, which support. The documentation phase is a filtered view of these events; nothing is written twice. Whether the insurers accept this as documentation is **D-27**. Until then, nurses can still add narrative entries.
- [ ] A traceability check lists every item that needs documentation in the period without a supporting entry. It checks **presence only** and never whether a code is correct.
- [ ] An evidence pack per resident and period: time-stamped and versioned, for insurer controls.
- [ ] NAVORA exchanges data with the licensed assessment software (**D-24**). It sends documented observations and receives the coded result and the PAG. NAVORA computes **no** PAG, CAP, scale or quality indicator itself.
- [ ] Signatures follow p. 49: everyone involved signs; the registered nurse signs needs determination; the result goes to the physician for information. Each is one digital step.
- [ ] Measured against the Phase-0 baseline: documentation minutes per observation period, meetings per period, insurer-control findings (must not rise).
- [ ] Negative tests: no coding without a signed-in coder; free-text fields carry no names in exports (p. 3); other organisations see nothing.

## Out of scope
Changing, simplifying or re-implementing any interRAI, PAG, CAP or MQI logic. Automatic coding (only a later, separate agent, and only with a licence and validation).

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | The assessment planning and control chain (expert, supervisor, coordinator as separate roles) |
| Manual activity removed | Planning observation periods, duplicate evidence entries, control sampling, insurer-control preparation |
| Role less necessary | LTCF coordinator, supervisor and expert as separate roles; their competence moves into the team and a network specialist |
| Continuity of care | The primary nurse assesses her own resident |
| Direct care time | The largest administrative block in nursing homes goes |
| Caregiver income potential | Correct classification without overhead; income does not follow the PAG (D-14 guardrail) |
| Long-term operating model | Evidence is a by-product of care in every setting |

## Constraints and references
Handbook p. 3–5, 18–20, 49–55. KLV Art. 8a (as cited on p. 49). D-13 (instrument), D-24 (licence and integration), D-25 (enter nursing homes), D-27 (evidence form). F1–F4 (append-only events), F6 (signed versions), J5 (billing facts pattern).

## Open questions for engineering
- What interfaces does the licensed software offer? This is input for D-24.
