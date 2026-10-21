# Open decisions

**Opened by:** anyone · **Decided by:** the role in *Owner* only · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 23:05 (po)
Background, options and consequences for the `D-*` items: `docs/engineering/DECISIONS_NEEDED.md`.

## Open

| ID | Owner | Kind | Question | Recommendation | Blocks | Opened |
|---|---|---|---|---|---|---|
| Q7 | po | product | Do location features (team bases, service radius, geocoding) belong in NAVORA's matching? | **PO view 2026-10-21:** yes, in Gate 5 together with J4; not before. Region match is enough for the pilot; geocoding needs a data-protection review first | – | 2026-10-21 (eng) |
| COORD-3 | eng | technical | `tests/unit/agents-layer.test.ts` "ranks follow the row order" edits the literal `\| 2 \| J1 \|`, so it breaks whenever the PO re-ranks (same class as #29). Make the fixture pick any row | as in #29: derive the row from the table instead of a fixed rank. Until then the PO keeps J1 at rank 2 | – | 2026-10-21 (po) |
| Q8 | po | product | Team response time per referral type and decline-reason list for J2 | **PO answer 2026-10-21 22:20:** pilot defaults, changeable by NAVORA administrators: hospital discharge 4 working hours; nursing home 1 working day; private 2 working days. Decline reasons: capacity, qualification, distance, other. Now in `briefs/J2.md`. Eng: drop Q8 from the J2 row; PO then moves it to Decided | J2 | 2026-10-21 (po) |
| Q9 | po | product | Thresholds and urgency for Operations exceptions (OPS1) | **PO answer 2026-10-21 22:20:** P1 safety / P2 continuity / P3 administration defaults as listed in `briefs/OPS1.md`; configuration, not code. Eng: drop Q9 from the OPS1 row; PO then moves it to Decided | OPS1 | 2026-10-21 (po) |
| D-10 | clinical | clinical | Must a registered nurse countersign visit reports when a care assistant performed the visit? (Care assistants cannot start category B or needs-assessment visits since #32, so this concerns their A/C work.) | until answered, F6 requires the countersignature (safe default, configurable); `clinical` may relax it for category C | F6 | 2026-10-21 (po) |
| D-11 | owner | regulatory | Pilot canton and municipalities | one canton, a few municipalities; it decides residual-financing rules, operating licence and quality obligations | – | 2026-10-21 (po) |
| D-12 | owner | regulatory | Legal entity that holds the cantonal operating licence and the OKP admission (insurer billing) | decide before the pilot; without admission no visit is billable | – | 2026-10-21 (po) |
| D-13 | owner | product | Assessment instrument: interRAI HC (home care) instead of interRAI LTCF (nursing homes)? | interRAI HC for the home-care product; LTCF only if a nursing-home offer is decided; then clarify the licence | – | 2026-10-21 (po) |
| D-14 | owner | financial | Platform fee and team surplus model | decide with pilot data from J5; until then J7 stays draft | – | 2026-10-21 (po) |
| D-15 | clinical | clinical | Approve the J1 readiness checklist, the J3 care-plan fields and the mapping of services to KLV categories A/B/C | as in `briefs/J1.md` and `briefs/J3.md` | J1, J3 | 2026-10-21 (po) |
| D-16 | clinical | clinical | Quality event types, severities, which ones set a quality hold, and who may lift it (QG1) | short list: fall, wound, medication, acute decline, social situation; serious → coach and quality specialist | – | 2026-10-21 (po) |
| D-1 | owner | legal | Live database: are the 6 cases / 3 care notes real people? Rotate the anon key; enable leaked-password protection | confirm synthetic or start the legal assessment; rotate the key now | – | 2026-10-21 (eng) |
| D-2 | owner | financial | Staging hosting provider and region | Supabase EU/CH plus Render Frankfurt or Vercel, synthetic data only | T12 | 2026-10-21 (eng) |
| D-3 | owner | product | Permission matrix: read scope of health data per role | option B now (team-scoped clinical read), C before production. **PO 2026-10-21:** supports B; it is the last access gap in F0 and a precondition for any real client data. **PO 22:20:** engineering builds B now as the restrictive default (it only narrows access; no real data affected); widening access needs the owner's answer | F0 | 2026-10-21 (eng) |
| D-17 | clinical | clinical | Which safety alerts must a nurse see before the first visit (e.g. allergies, fall risk, infection precautions, emergency contact, access or key arrangement)? | a short fixed list, captured at intake, shown on the `/field` card; nothing diagnostic | J1 | 2026-10-21 (po) |
| D-7 | owner | production | Branch protection, secret scanning, repository visibility (public → private) | protect `main` and `recovery/main` with required CI checks; make the repository private | M2 | 2026-10-21 (eng) |
| D-8 | owner | production | Merge `recovery/main` into `main` | merge commit after D-7 | M2 | 2026-10-21 (eng) |
| SR-26 | owner | production | Move or delete the foreign `orders` table (Stripe test checkouts with e-mail addresses) in the live NAVORA database | move it to the other app's project, then delete | – | 2026-10-21 (eng) |
| D-4 | legal | legal | Audit log retention and access | keep everything; admin-only read until decided | – | 2026-10-21 (eng) |
| D-9 | legal | legal | Legal basis for processing client data at intake (consent vs. care mandate) | keep the provisional consent gate; collect no more than name, region and needs | – | 2026-10-21 (eng) |
| D-6 | clinical | clinical | Visit assignment (team / nurse / both) and full state list (assigned, accepted, cancelled, no_show) | team plus optional responsible nurse; confirm transitions. **PO 2026-10-21 23:05:** J3 shipped and the PO accepted team plus responsible member; J6 builds on it. `clinical` confirms or changes the model. | – | 2026-10-21 (eng) |

## Decided

| ID | Owner | Answer | Date |
|---|---|---|---|
| Q4 | po | The nurse who performed the visit signs her report and requests her own time corrections; countersignature rule is D-10 (`clinical`), safe default in F6 until answered. Role matrix stays D-3 | 2026-10-21 |
| COORD-2 | po | F6 adopted, next build item after F0; J4 deferred to Gate 5 | 2026-10-21 |
| COORD-1 | po | Briefs for F0, J1, J2, J3, F1-F4, F6 published (PR #28), later QG1, OPS1, J5, J6, J7 | 2026-10-21 |
| D-5 | owner | NAVORA administrators manage organisations, memberships and member qualifications. Pilot qualification model: `registered_nurse`, `care_assistant` (two values, nothing else until `clinical` asks for more) | 2026-10-21 |
| D-1a | owner | Live containment C-1 approved and executed by the owner (anon access revoked) | 2026-10-21 |
| COORD-0 | owner | Multi-agent coordination model approved; official layer = `docs/agents/NEXT_CAPABILITY.md`, `IMPLEMENTATION_STATUS.md`, `OPEN_DECISIONS.md` | 2026-10-21 |
| PRIO-1 | owner | PO recommendations approved; engineering priority order F0, J1, J2, J3 | 2026-10-21 |
