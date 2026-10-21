# Next capability: Product Owner priority queue

**Owned by:** Product Owner (`po`) · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 19:20, F1-F4 accepted; briefs published (COORD-1); queue re-ranked against `ARCHITECTURE.md`

The order of the table is the order engineering builds in. Every row needs a brief in [`briefs/`](briefs/) before engineering starts it. Strategic reference: `ARCHITECTURE.md` (data flow and bounded contexts), then `PRODUCT_REQUIREMENTS.md`.

## Priority queue

| Rank | ID | Capability | PO status | Brief | Why |
|---|---|---|---|---|---|
| 1 | F0 | Shared access foundation for the care journey | approved | [F0](briefs/F0.md) | every journey depends on scoped access; T8–T10 reported delivered, now accept them against one frame |
| 2 | J1 | Referral intake → case → matching request | changes-requested | [J1](briefs/J1.md) | #23 works but stores no residence, insurer or medical-order status, so cases reach matching that can never be billed |
| 3 | J3 | Visit planning with billable basis | changes-requested | [J3](briefs/J3.md) | #25 has no KLV category, planned minutes or order check; planning is where billing is won or lost |
| 4 | F6 | Signed visit report | approved | [F6](briefs/F6.md) | `ARCHITECTURE.md`: freigegebener Bericht → Quality Gate → billable_facts; nothing after the visit works without it |
| 5 | J2 | Team decision workflow | changes-requested | [J2](briefs/J2.md) | #24 has no response time, escalation or qualification check; fewer than J1/J3 revenue gaps, so after them |
| 6 | F1-F4 | Verified visit (field tool slice) | accepted | [F1-F4](briefs/F1-F4.md) | accepted 2026-10-21 on test evidence (#19–#22); care goals and safety alerts on the card follow via J3 and J1 (D-17) |

## Next up (briefs drafted, not yet in the queue)

These enter the queue as soon as engineering acknowledges them with a `not-started` row in `IMPLEMENTATION_STATUS.md` (validator rule 2). Proposed order:

| Order | ID | Capability | Brief | Why |
|---|---|---|---|---|
| 7 | QG1 | Quality signals and quality hold | [QG1](briefs/QG1.md) | Quality Gate before billing facts (`ARCHITECTURE.md`); clinical safety for warning signs from visits |
| 8 | OPS1 | Operations exception center | [OPS1](briefs/OPS1.md) | Operations as exception-based control tower; J1–J3 exceptions need one place |
| 9 | J5 | Billable visit facts and monthly revenue preview | [J5](briefs/J5.md) | first proof that the model pays; needs F6 and QG1 |
| 10 | J6 | Continuity of care: primary nurse | [J6](briefs/J6.md) | NAVORA's quality promise, cheap extension of J3 |
| 11 | J7 | Team economics transparency | [J7](briefs/J7.md) | fair pay made checkable; needs J5 and D-14 |

## Engineering proposals

| ID | PO answer |
|---|---|
| F1-F4 | adopted and accepted, see queue rank 6 |
| F6 | adopted and ranked 4, ahead of J4 (COORD-2) |
| J4 (team availability and capacity) | deferred to Gate 5 (matching quality). In J2 teams decide on capacity themselves; with few pilot teams, derived capacity adds little before F6, QG1 and J5 |
| T12, M2 | engineering/owner items, not product priorities; no PO objection |

## Notes from the PO

- 2026-10-21 19:20: **F1-F4 accepted.** Evidence: e2e `field.spec.ts` (own team only, full depart → complete path, corrections with reason, observations with provenance and handover, phone width); pgTAP 009–011 (duplicate key is not a second event, disallowed transitions rejected, append-only events and corrections, versioned observations, other team / other organisation / anonymous get nothing). Not met: care goals and safety alerts on the visit card; the data does not exist yet. Routed to J3 (care-plan goals) and J1 (alerts captured at intake, list from `clinical` in D-17). No separate item.
- 2026-10-21 19:10: briefs for F0, J1, J2, J3, F1-F4, F6 published (COORD-1); draft briefs QG1, OPS1, J5, J6, J7. J1, J2 and J3 reviewed against their briefs from the migrations: **changes-requested**, gaps listed in each brief and marked *(delivered … to confirm)* where #23–#25 already meet a criterion. Q4 answered (performing nurse signs; countersignature rule goes to `clinical` as D-10). COORD-2 answered: F6 before J4.
- 2026-10-21: owner approved the PO recommendations; engineering priority order F0, J1, J2, J3.
