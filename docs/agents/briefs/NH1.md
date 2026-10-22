---
id: NH1
title: The ward team organises itself
author: po
status: draft
updated: 2026-10-22
---

# NH1 — The ward team organises itself (nursing homes, horizon 3)

## Problem
A nursing-home ward is run by a ward leader. The ward leader writes the roster, allocates residents each shift, runs the handover meeting and escalates problems. A scheduling administrator coordinates rosters across wards. None of this is care. It exists because the ward has no shared, current picture of residents and staff. Analysis: [`NURSING_HOME_TRANSFORMATION.md`](../../product/NURSING_HOME_TRANSFORMATION.md) §2–3. The source describes departments but not the ward leader's tasks. The pilot home must confirm them (ASSUMPTION).

## Users and journey step
Ward team members, the primary nurse of each resident, neighbouring wards, the coach on signals. Journey: Planning → Care → Documentation.

## Outcome
The ward team plans its own shifts, allocates residents with the primary nurse as the default, accepts new residents within its capacity, and gets cover from neighbouring wards. There is no ward leader or scheduling administrator in the loop.

## Acceptance criteria (draft)
- [ ] The team builds its roster in NAVORA. Skill-mix rules (minimum registered nurses per shift) come from the canton and `clinical` as configuration. NAVORA invents none, and the roster shows any shift that breaks a configured rule.
- [ ] Daily allocation proposes each resident's primary nurse (J6) when she is on shift, otherwise her deputy. The team changes it with one action.
- [ ] Handover is read from the record ("since you were last here", HAND1), not held in a meeting.
- [ ] An uncovered shift is offered to qualified members of neighbouring wards (COVER1 pattern), and OPS1 is the fallback.
- [ ] A new resident is offered to the ward team, which accepts or declines with a reason (J2 pattern).
- [ ] Measured: direct care share on the ward, nurses per resident per week, handover-meeting minutes (from the baseline).
- [ ] Negative tests: other wards see no resident data before they accept cover; other organisations see nothing.

## Out of scope
Assessment (NH2), quality signals (NH3), payroll.

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | Ward management and central scheduling |
| Manual activity removed | Rostering, daily allocation, handover meetings, phoning for staff |
| Role less necessary | Ward leader, scheduling administrator |
| Continuity of care | The primary nurse is the default every shift |
| Direct care time | Coordination time goes back to residents |
| Caregiver income potential | The team keeps the value of its own organisation (J7, D-14) |
| Long-term operating model | The same team model in home care and nursing homes |

## Constraints and references
D-25 (owner: enter nursing homes, pilot ward), D-11 (canton: skill-mix rules), J2, J6, HAND1, COVER1, OPS1.

## Open questions for engineering
- Can a shift be modelled as a "visit" with a long window, or does the roster need its own entity?
