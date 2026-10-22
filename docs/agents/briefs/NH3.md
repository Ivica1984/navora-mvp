---
id: NH3
title: Signals go to the team
author: po
status: draft
updated: 2026-10-22
---

# NH3 — Signals go to the team: status change and quality (nursing homes, horizon 3)

## Problem
Today the coordinator reviews the ADL index and discusses changes with the supervisor so that significant status changes are started in time (p. 50–51). A quality steering group, with the expert, interprets the LTCF quality indicators and MQI (p. 52–53). Information travels upward to meetings and back down. Changes in a resident's needs reach a reassessment late, and quality findings reach the team late or not at all.

## Users and journey step
The primary nurse, the ward team, the coach and a network quality specialist on demand. Journey: Care → Quality.

## Outcome
When the records show a change that `clinical` has listed (D-26), the primary nurse gets a suggestion with the evidence, and she decides whether to start a reassessment. The team sees its own quality indicators and restraint context and decides what to do. There is no steering-group meeting in between.

## Acceptance criteria (draft)
- [ ] Status-change suggestions use only the criteria approved by `clinical` in **D-26**. Each shows its evidence; the primary nurse accepts or dismisses it with a reason; NAVORA never starts a reassessment itself.
- [ ] Quality indicators come from the licensed software (**D-24**) and are shown per ward team, with definitions. Never per nurse.
- [ ] Freedom-restricting measures recorded as "context not clarified, not all legal conditions met" (p. 48) raise an OPS1 exception at once for the team and the coach.
- [ ] The coach and the quality specialist are called by these signals, not by a calendar.
- [ ] Measured: lead time from the first documented change to reassessment; open restraint exceptions; the team's acted-on share of signals.
- [ ] Negative tests: other wards and organisations see no signals; no ranking of individual nurses.

## Out of scope
Computing indicators in NAVORA; clinical rules not approved by `clinical`.

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | Quality management and status-change monitoring |
| Manual activity removed | ADL-index reviews, steering-group preparation, reporting upward |
| Role less necessary | Quality manager, supervisor (monitoring part) |
| Continuity of care | Care follows the resident's need, not the calendar |
| Direct care time | Fewer review meetings |
| Caregiver income potential | Quality as a basis for team income (D-14) |
| Long-term operating model | Learning from data at team level, which Buurtzorg does not do |

## Constraints and references
Handbook p. 47–53. D-24, D-25, D-26. QG1, OPS1, AN1.

## Open questions for engineering
- none yet
