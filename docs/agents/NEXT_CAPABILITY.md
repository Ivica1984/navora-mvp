# Next capability: Product Owner priority queue

**Owned by:** Product Owner (`po`) · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-22 12:00, F0, J2, OPS1, QG1, J6 accepted; J5 changes-requested (Q11 rule); C1, ADM1, AN1 approved

The order of the table is the order engineering builds in, top to bottom, skipping accepted rows. Every row needs a brief in [`briefs/`](briefs/). Strategic reference: `ARCHITECTURE.md` (data flow and bounded contexts), then `PRODUCT_REQUIREMENTS.md` and `DOMAIN_RULES.md`.

**Active now:** J5 minutes rule (small), then **C1** case and visit lifecycle.

## Standing review rule (owner instruction, 2026-10-22)

- When an item reaches `in-review` or `delivered` in `IMPLEMENTATION_STATUS.md`, the PO reviews it automatically against its brief. Evidence is merged tests plus green CI.
- The PO then sets `accepted` or `changes-requested`, and activates the next item, without waiting for the owner.
- The PO runs a review cycle every hour.
- **Engineering may start an approved item under "Next up" in its listed order** as soon as it has added a `not-started` row. The PO moves it into the queue at the next cycle.

## Priority queue

| Rank | ID | Capability | PO status | Brief | Why |
|---|---|---|---|---|---|
| 1 | J5 | Billable visit facts and monthly revenue preview | changes-requested | [J5](briefs/J5.md) | one rule: never bill more than the measured care minutes (Q11 answered in the brief). Without it the revenue estimate overstates what the model earns |
| 2 | J7 | Team economics transparency | draft | [J7](briefs/J7.md) | fair pay made checkable; stays draft until the owner decides D-14. AN1 provides the evidence for that decision |
| 3 | F0 | Shared access foundation for the care journey | accepted | [F0](briefs/F0.md) | accepted 2026-10-22 (#34, #38, CI green) |
| 4 | J1 | Referral intake → case → matching request | accepted | [J1](briefs/J1.md) | accepted 2026-10-21 (#23, #30); safety alerts follow D-17 |
| 5 | J2 | Team decision workflow | accepted | [J2](briefs/J2.md) | accepted 2026-10-22 (#24, #36, CI green) |
| 6 | J3 | Visit planning with billable basis | accepted | [J3](briefs/J3.md) | accepted 2026-10-21 (#25, #32); category mapping D-15 |
| 7 | F1-F4 | Verified visit (field tool slice) | accepted | [F1-F4](briefs/F1-F4.md) | accepted 2026-10-21 (#19–#22) |
| 8 | F6 | Signed visit report | accepted | [F6](briefs/F6.md) | accepted 2026-10-21 (#35); countersignature rule until D-10 |
| 9 | QG1 | Quality signals and quality hold | accepted | [QG1](briefs/QG1.md) | accepted 2026-10-22 (#41, CI green); operational once `clinical` answers D-16 |
| 10 | OPS1 | Operations exception center | accepted | [OPS1](briefs/OPS1.md) | accepted 2026-10-22 (#39, CI green) |
| 11 | J6 | Continuity of care: primary nurse | accepted | [J6](briefs/J6.md) | accepted 2026-10-22 (#42, CI green); member names via ADM1 |

## Next up (approved briefs; engineering may start in this order after adding a `not-started` row)

| Order | ID | Capability | Brief | Why |
|---|---|---|---|---|
| 1 | C1 | Case and visit lifecycle: pause, close, reopen, cancel, no-show | [C1](briefs/C1.md) | the journey can start care but not interrupt or end it. Hospital stays, end of care and cancelled visits happen weekly; today they leave visits on the plan, false exceptions, distorted continuity and revenue figures, and no workflow when a client does not open the door |
| 2 | ADM1 | Pilot administration: members, qualifications, operating rules | [ADM1](briefs/ADM1.md) | without it every invitation, team or threshold change is an engineering task, and colleagues have no names; the pilot cannot be run by NAVORA staff |
| 3 | AN1 | Pilot impact dashboard | [AN1](briefs/AN1.md) | turns J1–J6 data into proof of the model (admin time, start of care, continuity, billable share); the evidence for D-14 and for partners |

## Engineering proposals

| ID | PO answer |
|---|---|
| F1-F4 | adopted and accepted |
| F6 | adopted and accepted |
| J4 (team availability and capacity) | deferred to Gate 5 (matching quality). Teams decide on capacity themselves in J2; with few pilot teams, derived capacity adds little before F6, QG1 and J5 |
| T12, M2 | engineering/owner items, not product priorities; no PO objection |

## Notes from the PO

- 2026-10-22 12:00: **Accepted: F0** (#38), **J2** (#36), **OPS1** (#39), **QG1** (#41), **J6** (#42), all merged with green CI; evidence tables are in the briefs. QG1 becomes operational when `clinical` answers D-16. **J5 changes-requested** for one rule: billable minutes never exceed the measured care minutes (Q11). **Next capability: C1** (case and visit lifecycle), the largest remaining journey gap. After it come **ADM1** (pilot administration, which also gives members names) and **AN1** (pilot impact dashboard). **Decided:** Q7, Q8, Q9, Q10. **New:** D-18 (`legal`: billing time rules in the tariff contract) and D-19 (`clinical`: what the nurse does when a client does not open the door).
- 2026-10-21 23:05: **F6 accepted** (#35): every criterion met; deviation accepted (countersignature rule in code, adjusted by migration once D-10 is answered). **Order:** OPS1 moves ahead of QG1 because QG1 waits for D-16 and OPS1 can already surface every exception F6, J1 and J3 create. J6 is not blocked by D-6. Build order of open items: F0 (reasons), J2, OPS1, QG1 (after D-16), J6, J5, J7.
- 2026-10-21 22:35: **F0 team-scoped clinical read accepted** (#34, ADR-031, pgTAP 015, e2e `access.spec.ts`, CI green). F0 criteria 2, 3a, 3c, 3d and 6 are met. Criterion 5 is the only remaining item, and the engineering question "which commands need a mandatory reason" is answered in `briefs/F0.md`. Criterion 1 for live is an owner decision; criterion 4 is in J2.
- 2026-10-21 22:20: **J1 accepted** (#30, CI green): every criterion met except safety alerts, which correctly wait for D-17; deviation "`unknown` insurance type counts as missing" accepted as product rule. **J3 accepted** (#32, CI green): every criterion met, including member qualification as data (F0 criterion 2). Deviations accepted: the team chooses the KLV category per service until `clinical` signs off a mapping (D-15); assignment is team plus responsible member with the registered-nurse check at start (D-6). Clinical sign-offs D-15 and D-17 are gates before real client data; if they change fields, they come back as follow-up items, not reopens. **F0** stays changes-requested with a narrower scope (see brief): criterion 1 for live is an owner production decision (T12, M5), not F0; criterion 4 moves into J2. **Build order:** F0 → F6 → J2 → QG1 → OPS1 → J5 → J6 → J7 (accepted J1, J3, F1-F4 listed after F0). Q8 and Q9 answered; COORD-1, COORD-2, Q4 decided.
- 2026-10-21 21:59: owner decided **D-5**: NAVORA administrators manage qualifications; pilot model `registered_nurse`, `care_assistant`. F0 gap 1 proceeds; engineering builds it inside J3 (rank 3, in progress), which the PO accepts as the delivery vehicle. J1 changes (#30) reviewed: meet the brief; `accepted` once merged with green CI.
- 2026-10-21 21:55: **F0 changes-requested.** Met on merged evidence: reproducible schema with drift report (#18), organisations/roles/team memberships (#8), anonymous and other-organisation negative tests (pgTAP 004, 011–013), audit and idempotency (#9), no client identity in offers (#24), synthetic seeds. Missing: member qualification as data; team-scoped read of cases, visits, care notes and quality events inside an organisation (today any organisation member reads them; scope is owner decision D-3). Partner self-submission moved out of scope for the pilot (operations records referrals). Order unchanged; engineering builds F0 gap 1, then J1, then F0 gap 2 once D-3 is decided.
- 2026-10-21 19:20: **F1-F4 accepted.** Evidence: e2e `field.spec.ts` (own team only, full depart → complete path, corrections with reason, observations with provenance and handover, phone width); pgTAP 009–011 (duplicate key is not a second event, disallowed transitions rejected, append-only events and corrections, versioned observations, other team / other organisation / anonymous get nothing). Not met: care goals and safety alerts on the visit card; the data does not exist yet. Routed to J3 (care-plan goals) and J1 (alerts captured at intake, list from `clinical` in D-17). No separate item.
- 2026-10-21 19:10: briefs for F0, J1, J2, J3, F1-F4, F6 published (COORD-1); draft briefs QG1, OPS1, J5, J6, J7. J1, J2 and J3 reviewed against their briefs from the migrations: **changes-requested**, gaps listed in each brief and marked *(delivered … to confirm)* where #23–#25 already meet a criterion. Q4 answered (performing nurse signs; countersignature rule goes to `clinical` as D-10). COORD-2 answered: F6 before J4.
- 2026-10-21: owner approved the PO recommendations; engineering priority order F0, J1, J2, J3.
