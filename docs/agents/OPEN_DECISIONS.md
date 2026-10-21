# Open decisions

**Opened by:** anyone · **Decided by:** the role in *Owner* only · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 19:10 (po)
Background, options and consequences for the `D-*` items: `docs/engineering/DECISIONS_NEEDED.md`.

## Open

| ID | Owner | Kind | Question | Recommendation | Blocks | Opened |
|---|---|---|---|---|---|---|
| COORD-1 | po | product | Publish the approved engineering briefs for F0, J1, J2 and J3 in `docs/agents/briefs/` | **PO answer 2026-10-21:** published, plus F1-F4 and F6. Eng: unblock F0; PO then moves COORD-1 to Decided | F0 | 2026-10-21 (eng) |
| COORD-2 | po | product | Prioritise or reject the engineering proposals J4 (team availability and capacity) and F6 (visit report) | **PO answer 2026-10-21:** F6 adopted, queue rank 4; J4 deferred to Gate 5 (see `NEXT_CAPABILITY.md`). Eng: drop COORD-2 from the J4/F6 rows; PO then moves it to Decided | J4, F6 | 2026-10-21 (eng) |
| Q4 | po | product | Final role set; who approves visit reports and time corrections | **PO answer 2026-10-21:** the nurse who performed the visit signs her report and requests her own time corrections; countersignature by a registered nurse when a care assistant performed the visit, pending D-10 (`clinical`). Role matrix stays D-3. PO moves Q4 to Decided once the F6 row no longer lists it | F6 | 2026-10-21 (eng) |
| Q7 | po | product | Do location features (team bases, service radius, geocoding) belong in NAVORA's matching? | **PO view 2026-10-21:** yes, in Gate 5 together with J4; not before. Region match is enough for the pilot; geocoding needs a data-protection review first | – | 2026-10-21 (eng) |
| Q8 | po | product | Team response time per referral type (hospital discharge, nursing home, private) and decline-reason list for J2 | configurable values; shortest for hospital discharge; v1 reasons: capacity, qualification, distance, other. Values set with the first pilot partner | J2 | 2026-10-21 (po) |
| Q9 | po | product | Thresholds and urgency for Operations exceptions (OPS1) | configuration, not code; hospital discharge highest urgency | – | 2026-10-21 (po) |
| D-10 | clinical | clinical | Must a registered nurse countersign visit reports when a care assistant performed the visit? | yes for category B services and the needs assessment; confirm for category C | F6 | 2026-10-21 (po) |
| D-11 | owner | regulatory | Pilot canton and municipalities | one canton, a few municipalities; it decides residual-financing rules, operating licence and quality obligations | – | 2026-10-21 (po) |
| D-12 | owner | regulatory | Legal entity that holds the cantonal operating licence and the OKP admission (insurer billing) | decide before the pilot; without admission no visit is billable | – | 2026-10-21 (po) |
| D-13 | owner | product | Assessment instrument: interRAI HC (home care) instead of interRAI LTCF (nursing homes)? | interRAI HC for the home-care product; LTCF only if a nursing-home offer is decided; then clarify the licence | – | 2026-10-21 (po) |
| D-14 | owner | financial | Platform fee and team surplus model | decide with pilot data from J5; until then J7 stays draft | – | 2026-10-21 (po) |
| D-15 | clinical | clinical | Approve the J1 readiness checklist, the J3 care-plan fields and the mapping of services to KLV categories A/B/C | as in `briefs/J1.md` and `briefs/J3.md` | J1, J3 | 2026-10-21 (po) |
| D-16 | clinical | clinical | Quality event types, severities, which ones set a quality hold, and who may lift it (QG1) | short list: fall, wound, medication, acute decline, social situation; serious → coach and quality specialist | – | 2026-10-21 (po) |
| D-1 | owner | legal | Live database: are the 6 cases / 3 care notes real people? Rotate the anon key; enable leaked-password protection | confirm synthetic or start the legal assessment; rotate the key now | – | 2026-10-21 (eng) |
| D-2 | owner | financial | Staging hosting provider and region | Supabase EU/CH plus Render Frankfurt or Vercel, synthetic data only | T12 | 2026-10-21 (eng) |
| D-3 | owner | product | Permission matrix: read scope of health data per role | option B now (team-scoped clinical read), C before production | – | 2026-10-21 (eng) |
| D-5 | owner | product | Who manages organisations and memberships | NAVORA staff first, then organisation admins | – | 2026-10-21 (eng) |
| D-7 | owner | production | Branch protection, secret scanning, repository visibility (public → private) | protect `main` and `recovery/main` with required CI checks; make the repository private | M2 | 2026-10-21 (eng) |
| D-8 | owner | production | Merge `recovery/main` into `main` | merge commit after D-7 | M2 | 2026-10-21 (eng) |
| SR-26 | owner | production | Move or delete the foreign `orders` table (Stripe test checkouts with e-mail addresses) in the live NAVORA database | move it to the other app's project, then delete | – | 2026-10-21 (eng) |
| D-4 | legal | legal | Audit log retention and access | keep everything; admin-only read until decided | – | 2026-10-21 (eng) |
| D-9 | legal | legal | Legal basis for processing client data at intake (consent vs. care mandate) | keep the provisional consent gate; collect no more than name, region and needs | – | 2026-10-21 (eng) |
| D-6 | clinical | clinical | Visit assignment (team / nurse / both) and full state list (assigned, accepted, cancelled, no_show) | team plus optional responsible nurse; confirm transitions | – | 2026-10-21 (eng) |

## Decided

| ID | Owner | Answer | Date |
|---|---|---|---|
| D-1a | owner | Live containment C-1 approved and executed by the owner (anon access revoked) | 2026-10-21 |
| COORD-0 | owner | Multi-agent coordination model approved; official layer = `docs/agents/NEXT_CAPABILITY.md`, `IMPLEMENTATION_STATUS.md`, `OPEN_DECISIONS.md` | 2026-10-21 |
| PRIO-1 | owner | PO recommendations approved; engineering priority order F0, J1, J2, J3 | 2026-10-21 |
