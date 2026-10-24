# Decision packages: index and order

**Owner:** `po` · **Process:** [`../DECISION_PACKAGES.md`](../DECISION_PACKAGES.md) · **Last change:** 2026-10-24 03:10 (po: `cra` Clinical impact copied into D-22, D-18, D-28; `lca` input merged for D-31, D-3, D-29 (#241); packages D-30, D-16, D-12 written, inputs requested; D-32 added, tier 2 (CGR-37)); 2026-10-24 02:20 (po: packages D-31, D-3, D-29 written, inputs requested; `lca` input for D-22 and D-18 in PR #241, not yet merged); 2026-10-24 01:15 (po: packages D-22, D-18, D-28 written, inputs requested); 2026-10-24 00:15 (po: priority override by the owner; first triage of the 29 open decisions)

The PO works this list top to bottom, about three packages per run. **Order (owner, 2026-10-24):** tier 1 D-22 and D-18; tier 2 every decision referenced by an open or provisional clinical finding (CGR); tier 3 every decision blocking billing, reimbursement, invoicing, compliance, governance or a production release; tier 4 the rest. Within a tier: what blocks the most first. A new decision is placed by the same tiers. *Preliminary route* is the PO's first triage, before any input: a package may change it. **The PO did not ask any person anything for this triage.**

Inputs: **E** Engineering (`eng`), **C** Clinical & Regulatory Architect (`cra`), **L** Legal & Compliance Agent (`lca`).

| Order | Tier | ID | Row owner | Question (short) | Blocks | CGR | Inputs | Preliminary route | Package status |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 owner override | D-22 | legal | Valid form of a medical order and renewal | ORD1, J5-C2 provisional | CGR-07 (provisional) | E, C, L | `legal` | [inputs-requested](D-22.md) (2026-10-24 01:15); C and L in, E open; PO draft direction 03:10 |
| 2 | 1 owner override | D-18 | legal | Billing time rules of the tariff contract | invoicing (CGR-31) | CGR-31 (open), CGR-07, CGR-08 | E, C, L | `legal` (needs the actual contract; D-11, D-12 first) | [inputs-requested](D-18.md) (2026-10-24 01:15); C and L in, E open; PO draft 03:10 |
| 3 | 2 open CGR finding | D-28 | clinical | When an overdue or stuck visit raises an exception | CSR1 thresholds (PROVISIONAL) | CGR-23, CGR-35 (open); CGR-04, -22, -24 (provisional) | E, C | `clinical` | [inputs-requested](D-28.md) (2026-10-24 01:15); C in, E open; delivery part decided by po (SIG1) |
| 4 | 2 open CGR finding | D-31 | clinical | Documentation and billing of a broken-off visit | OPS1 (PROVISIONAL) | CGR-35 (open); CGR-20, -25, -26 (provisional) | E, C, L | `clinical` | [inputs-requested](D-31.md) (2026-10-24 02:20); L in (#241), E and C open |
| 5 | 2 open CGR finding | D-3 | owner | Read scope of health data per role | F0, COVER1; any real client data | CGR-21, CGR-28 (open) | E, C, L | po may decide if `lca` finds option B compliant under every interpretation (privacy, professional secrecy); otherwise `owner` | [inputs-requested](D-3.md) (2026-10-24 02:20); L in (#241), E and C open |
| 6 | 2 open CGR finding | D-29 | owner | How a member's qualification is verified before it is active | real clients | CGR-16 (open) | E, C, L | `owner` (regulatory liability) | [inputs-requested](D-29.md) (2026-10-24 02:20); L in (#241), E and C open |
| 7 | 2 open CGR finding | D-30 | clinical | Correcting a report when its author left the team | F6 (PROVISIONAL) | CGR-19 (provisional) | E, C, L | `clinical` | [inputs-requested](D-30.md) (2026-10-24 03:10) |
| 8 | 2 open CGR finding | D-16 | clinical | Quality event types, holds, who lifts them | QG1 relaxation | CGR-13 (provisional) | E, C, L | `clinical` | [inputs-requested](D-16.md) (2026-10-24 03:10) |
| 9 | 2 open CGR finding | D-32 | po | Safety-signal delivery outside the app (provider, region, content) | SIG1 outside the app; go-live condition SIG1-8 | CGR-37 (open) | E, L | po may decide if `lca` finds the fixed-text proposal compliant under every interpretation and no paid contract is needed; otherwise `owner` | not-started |
| 10 | 3 billing, compliance, governance, release | D-12 | owner | Legal entity for licence and OKP admission | billing | – | E, L | `owner` (regulatory liability) | [inputs-requested](D-12.md) (2026-10-24 03:10) |
| 11 | 3 billing, compliance, governance, release | D-11 | owner | Pilot canton and municipalities | D-18, D-25, statistics | – | L | `owner` (strategic) | not-started |
| 12 | 3 billing, compliance, governance, release | D-15 | clinical | J1 readiness checklist, J3 care-plan fields, KLV A/B/C mapping | J1, J3 | – | E, C, L | `clinical` (the KLV mapping is a clinical and billing rule) | not-started |
| 13 | 3 billing, compliance, governance, release | D-9 | legal | Legal basis for client data at intake | REF2, real clients | – | E, L | `legal`/`owner` if unresolved; the consent gate stays | not-started |
| 14 | 3 billing, compliance, governance, release | D-4 | legal | Audit log retention and access | production | – | E, L | po may decide a provisional default if compliant under every interpretation; final retention `legal` | not-started |
| 15 | 3 billing, compliance, governance, release | D-10 | clinical | Countersignature of care-assistant visit reports | F6 relaxation | – | E, C, L | `clinical` | not-started |
| 16 | 3 billing, compliance, governance, release | D-7 | owner | Branch protection, secret scanning, repository visibility | M2 | – | E, L | `owner` (production, irreversible visibility change) | not-started |
| 17 | 3 billing, compliance, governance, release | D-8 | owner | Merge `recovery/main` into `main` | M2 | – | E | `owner` (production); after D-7 | not-started |
| 18 | 3 billing, compliance, governance, release | D-1 | owner | Live database: real people? key rotation, leaked-password protection | containment | – | E, L | `owner` (facts only the owner knows; live system) | not-started |
| 19 | 3 billing, compliance, governance, release | SR-26 | owner | Foreign `orders` table in the live database | – | – | E, L | `owner` (live system, irreversible delete) | not-started |
| 20 | 3 billing, compliance, governance, release | D-2 | owner | Staging hosting provider and region | T12 | – | E, L | po may decide the design (EU/CH, synthetic data); `owner` only for a paid contract | not-started |
| 21 | 3 billing, compliance, governance, release | D-26 | owner | Service-role key on the app server for invitations | ADM1 invitations | – | E, L | po may decide (technical, reversible) if `lca` raises no privacy issue | not-started |
| 22 | 3 billing, compliance, governance, release | D-23 | legal | Working-time record derived from field events | North Star measure | – | E, L | `legal` if unresolved | not-started |
| 23 | 4 other | D-17 | clinical | Safety alerts a nurse sees before the first visit | J1 | – | E, C | `clinical` | not-started |
| 24 | 4 other | D-6 | clinical | Visit assignment and state list | – | – | E, C | po may decide if `cra` confirms it is a workflow, not a clinical rule (J3 already ships team + responsible member) | not-started |
| 25 | 4 other | D-19 | clinical | On-site protocol when the client does not open | C1 | – | C, L | `clinical` | not-started |
| 26 | 4 other | D-20 | owner | Who admits members to a team | ADM1 relaxation | – | E, L | po may decide (team autonomy) if `lca` finds no employment-law limit; otherwise `owner` | not-started |
| 27 | 4 other | D-14 | owner | Platform fee and team surplus model | J7 | – | E, L | `owner` (pricing) | not-started |
| 28 | 4 other | D-13 | owner | interRAI HC instead of LTCF | assessment | – | C, L | `owner` (licence cost, partnership) | not-started |
| 29 | 4 other | D-24 | owner | Enter nursing homes, design partner, interRAI LTCF licence | Horizon 3 | – | C, L | `owner` (strategy, partnership) | not-started |
| 30 | 4 other | D-25 | legal | Nursing-home leadership licensing rules | NH briefs | – | C, L | `legal`; after D-11 | not-started |

**Not a decision row, but it gates every `clinical` package:** the owner names the Clinical Owner (G-1, D-27). Until then a package that needs `clinical` approval is complete and waits.
