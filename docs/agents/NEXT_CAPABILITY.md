# Next capability: Product Owner priority queue

**Owned by:** Product Owner (`po`) · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 22:35, J1 and J3 accepted; F0 team-scoped read accepted (#34); F6 next; QG1, OPS1, J5, J6, J7 queued

The order of the table is the order engineering builds in. Every row needs a brief in [`briefs/`](briefs/) before engineering starts it. Strategic reference: `ARCHITECTURE.md` (data flow and bounded contexts), then `PRODUCT_REQUIREMENTS.md` and `DOMAIN_RULES.md`. Accepted items stay at the end for traceability.

**Active now:** F0 last item (mandatory reasons, rule in the brief), then **F6**.

## Priority queue

| Rank | ID | Capability | PO status | Brief | Why |
|---|---|---|---|---|---|
| 1 | F0 | Shared access foundation for the care journey | changes-requested | [F0](briefs/F0.md) | team-scoped clinical read accepted (#34); one item left: a mandatory reason on commands that undo, change recorded facts or override a rule (list in the brief). Small; then F0 is accepted |
| 2 | F6 | Signed visit report | approved | [F6](briefs/F6.md) | `ARCHITECTURE.md`: freigegebener Bericht → Quality Gate → billable_facts. With J1 and J3 accepted, the unsigned visit is the biggest gap in the journey: no documentation the client can inspect, nothing to bill. Not blocked: countersignature defaults to safe until D-10 |
| 3 | J2 | Team decision workflow | changes-requested | [J2](briefs/J2.md) | partner promise of a dependable answer: response time, escalation, qualification check, and the offer fields from F0 criterion 4 (start, expected hours, required qualification). Q8 answered |
| 4 | QG1 | Quality signals and quality hold | approved | [QG1](briefs/QG1.md) | clinical safety for warning signs from visits and the Quality Gate before billing facts; event list waits for D-16 (`clinical`) |
| 5 | OPS1 | Operations exception center | approved | [OPS1](briefs/OPS1.md) | one place for every exception J1–J3, F6 and QG1 create; J3 already adds uncovered visits. Q9 answered |
| 6 | J5 | Billable visit facts and monthly revenue preview | approved | [J5](briefs/J5.md) | first proof that the model pays; needs F6 and QG1; residual financing needs the pilot canton (D-11). D-12 only gates real invoicing, which J5 does not do |
| 7 | J6 | Continuity of care: primary nurse | approved | [J6](briefs/J6.md) | continuity is NAVORA's quality promise; J3's responsible member is the natural start (D-6) |
| 8 | J7 | Team economics transparency | draft | [J7](briefs/J7.md) | fair pay made checkable; stays draft until the owner decides D-14 |
| 9 | J1 | Referral intake → case → matching request | accepted | [J1](briefs/J1.md) | accepted 2026-10-21 (#23, #30, CI green); safety alerts follow D-17; checklist sign-off D-15 |
| 10 | J3 | Visit planning with billable basis | accepted | [J3](briefs/J3.md) | accepted 2026-10-21 (#25, #32, CI green); includes F0 qualification data; category mapping sign-off D-15 |
| 11 | F1-F4 | Verified visit (field tool slice) | accepted | [F1-F4](briefs/F1-F4.md) | accepted 2026-10-21 on test evidence (#19–#22) |

## Engineering proposals

| ID | PO answer |
|---|---|
| F1-F4 | adopted and accepted |
| F6 | adopted; queue rank 2 |
| J4 (team availability and capacity) | deferred to Gate 5 (matching quality). Teams decide on capacity themselves in J2; with few pilot teams, derived capacity adds little before F6, QG1 and J5 |
| T12, M2 | engineering/owner items, not product priorities; no PO objection |

## Notes from the PO

- 2026-10-21 22:35: **F0 team-scoped clinical read accepted** (#34, ADR-031, pgTAP 015, e2e `access.spec.ts`, CI green). F0 criteria 2, 3a, 3c, 3d and 6 are met. Criterion 5 is the only remaining item, and the engineering question "which commands need a mandatory reason" is answered in `briefs/F0.md`. Criterion 1 for live is an owner decision; criterion 4 is in J2.
- 2026-10-21 22:20: **J1 accepted** (#30, CI green): every criterion met except safety alerts, which correctly wait for D-17; deviation "`unknown` insurance type counts as missing" accepted as product rule. **J3 accepted** (#32, CI green): every criterion met, including member qualification as data (F0 criterion 2). Deviations accepted: the team chooses the KLV category per service until `clinical` signs off a mapping (D-15); assignment is team plus responsible member with the registered-nurse check at start (D-6). Clinical sign-offs D-15 and D-17 are gates before real client data; if they change fields, they come back as follow-up items, not reopens. **F0** stays changes-requested with a narrower scope (see brief): criterion 1 for live is an owner production decision (T12, M5), not F0; criterion 4 moves into J2. **Queue re-ranked:** F0 → F6 → J2 → QG1 → OPS1 → J5 → J6 → J7. Q8 and Q9 answered; COORD-1, COORD-2, Q4 decided.
- 2026-10-21 21:59: owner decided **D-5**: NAVORA administrators manage qualifications; pilot model `registered_nurse`, `care_assistant`. F0 gap 1 proceeds; engineering builds it inside J3 (rank 3, in progress), which the PO accepts as the delivery vehicle. J1 changes (#30) reviewed: meet the brief; `accepted` once merged with green CI.
- 2026-10-21 21:55: **F0 changes-requested.** Met on merged evidence: reproducible schema with drift report (#18), organisations/roles/team memberships (#8), anonymous and other-organisation negative tests (pgTAP 004, 011–013), audit and idempotency (#9), no client identity in offers (#24), synthetic seeds. Missing: member qualification as data; team-scoped read of cases, visits, care notes and quality events inside an organisation (today any organisation member reads them; scope is owner decision D-3). Partner self-submission moved out of scope for the pilot (operations records referrals). Order unchanged; engineering builds F0 gap 1, then J1, then F0 gap 2 once D-3 is decided.
- 2026-10-21 19:20: **F1-F4 accepted.** Evidence: e2e `field.spec.ts` (own team only, full depart → complete path, corrections with reason, observations with provenance and handover, phone width); pgTAP 009–011 (duplicate key is not a second event, disallowed transitions rejected, append-only events and corrections, versioned observations, other team / other organisation / anonymous get nothing). Not met: care goals and safety alerts on the visit card; the data does not exist yet. Routed to J3 (care-plan goals) and J1 (alerts captured at intake, list from `clinical` in D-17). No separate item.
- 2026-10-21 19:10: briefs for F0, J1, J2, J3, F1-F4, F6 published (COORD-1); draft briefs QG1, OPS1, J5, J6, J7. J1, J2 and J3 reviewed against their briefs from the migrations: **changes-requested**, gaps listed in each brief and marked *(delivered … to confirm)* where #23–#25 already meet a criterion. Q4 answered (performing nurse signs; countersignature rule goes to `clinical` as D-10). COORD-2 answered: F6 before J4.
- 2026-10-21: owner approved the PO recommendations; engineering priority order F0, J1, J2, J3.
