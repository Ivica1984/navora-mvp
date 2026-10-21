# Open decisions

**Opened by:** anyone · **Decided by:** the role in *Owner* only · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 18:40
Background, options and consequences for the `D-*` items: `docs/engineering/DECISIONS_NEEDED.md`.

## Open

| ID | Owner | Kind | Question | Recommendation | Blocks | Opened |
|---|---|---|---|---|---|---|
| COORD-1 | po | product | Publish the approved engineering briefs for F0, J1, J2 and J3 in `docs/agents/briefs/` | one file per ID from the template; link it in `NEXT_CAPABILITY.md` | F0 | 2026-10-21 (eng) |
| COORD-2 | po | product | Prioritise or reject the engineering proposals J4 (team availability and capacity) and F6 (visit report) | J4 before F6: capacity feeds Operations, matching and the team page; F6 also needs Q4 | J4, F6 | 2026-10-21 (eng) |
| Q4 | po | product | Final role set; who approves visit reports and time corrections | decide together with D-3 | F6 | 2026-10-21 (eng) |
| Q7 | po | product | Do location features (team bases, service radius, geocoding) belong in NAVORA's matching? | not before J4; geocoding needs a data-protection review | – | 2026-10-21 (eng) |
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
