# NAVORA Engineering Quality Scorecard

**Owned by:** Engineering (`eng`) · **Basis:** founder order 2026-11-19 ca. 20:50 (live session with `eng`, relayed to `po` in an issue; FE row is written by the PO) · ADR-218 · **Created:** 2026-11-19 20:55 Europe/Zurich

The founder's target: when the NAVORA product is complete, every area below stands at **«sehr gut»**. A grade is never self-declared: each area has measurable criteria, read from code or CI, and `eng` updates the «today» column at every ready report (`Paket prüfbereit:`) and at least once a week. A grade goes up only when every criterion of that grade is met on `recovery/main`.

Grades: **schwach** < **mittel** < **gut** < **sehr gut**. Labels: IMPLEMENTED, PLANNED, OPEN, UNKNOWN.

## 1. Scorecard

| Area | Today (2026-11-19, read in code and CI) | «sehr gut» means (all criteria, measured) | Programme item |
|---|---|---|---|
| Technology | gut: Next.js 16, React 19, TypeScript strict (1 `any` in `src/`), Zod 4, Supabase | 0 `any` outside generated types; every dependency ≤ 1 minor behind or a recorded reason; upgrades grouped and CI-tested automatically | Q6 |
| Database, security, audit | sehr gut: RLS, column grants, audit triggers, append-only ledgers, 151 pgTAP files | stays: every new table in the generated RLS/grant matrix test (Q5); Supabase advisors 0 security findings on staging | Q5, Q6 |
| AI safeguards | gut: source per line, AUT-149, ledger without text, kill switch, S2 in CI; **no model measured** | every AI function: eval set in CI, eval run against the real model on staging with quality, p95 latency and cost per version recorded; structured output schema; versioned prompts; one gateway with kill switch, cost limit and ledger | Q2 |
| Code structure | mittel: ca. 28 000 lines app code; `team-client.tsx` 1291 and `field-client.tsx` 1285 lines | no hand-written file in `src/app` over 400 lines (CI check); shared UI component library used by every view; sector differences only as configuration | Q4 |
| Operations, observability | schwach: no error monitoring, no latency measurement, staging smoke never green | per-PR preview environment; version and migration level visible in the app with a CI match check; errors and p95 latency of every server command visible within minutes (Swiss/EU region); staging smoke green on every merge | Q1 |
| Mobile and offline | UNKNOWN: a service worker exists; offline behaviour of `/field` not verified | `/field` works offline end to end (e2e with network cut: input kept, sent once on reconnect, no double booking); performance budget in CI at 390 px on a slow network, a breach fails the PR | Q3 |
| Test quality | gut, but blind: 1589 unit tests, 47 e2e files, 151 pgTAP files; no coverage, no mutation score | coverage reported per PR; mutation score measured automatically on the critical modules (AI control, time across midnight, qualification limits) with a floor that fails CI; property-based tests for time and planning logic | Q5 |
| Security hygiene | mittel: default branch `main` outdated with 25 GitHub alerts (5 critical); `recovery/main` 1 moderate (`next`) | default branch is the integrated code; 0 high or critical alerts; CodeQL in CI; secret scanning on; SBOM per release | Q6 |

## 2. Quality questions `eng` asks at every package (standing duty, founder 2026-11-19)

1. Which scorecard criterion does this package move, and which could it worsen?
2. Is a file growing past 400 lines, or a second copy of a component appearing?
3. Can the founder click this package before the merge (preview), and is the flow checked on staging after it?
4. What does the package cost at runtime (latency, model cost), measured or labelled as estimate?
5. Would the tests catch a deliberate fault in the new logic (mutation check)?
6. Does it work at 390 px and without network where a carer uses it?

The answers go into the ready report under «Qualität».
