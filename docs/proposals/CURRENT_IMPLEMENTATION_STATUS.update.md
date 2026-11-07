# Proposal — "Verified 2026-10-21" section for CURRENT_IMPLEMENTATION_STATUS.md

Per `CLAUDE.md` the handover documents are not changed automatically. This file lists the
deviations between `CURRENT_IMPLEMENTATION_STATUS.md` and what is now verified in Git and CI,
with a proposed section to append. The owner applies it (or rejects it) by PR.

## Deviations found

| Row in the handover doc | Doc says | Verified 2026-10-21 | Evidence |
|---|---|---|---|
| Next.js/React/TS App | Next 16.3.0, later 16.3.4 | **16.4.1** on `recovery/main`; 16.3.x has critical advisories | CI `npm ls` on PR #1 |
| Abhängigkeitssicherheit | 0 findings back then | 0 vulnerabilities (`npm audit --omit=dev`) today | CI PR #1 |
| Lint und Build | green back then | green today; lint has 1 warning (login navigation) | CI PR #1 |
| `@supabase/ssr` | installed, usage UNKNOWN | **not installed and not used** in the recovered code | `package.json`, code search |
| Geschützte Routen | UNKNOWN/OPEN | **not implemented** (no middleware/proxy, no server session check) | code |
| Matching Read UI | later replaced by Supabase reads | recovered code still has the **mock**; now hidden by flag | `src/app/matching/` |
| `cases`… tables | 9 tables | 8 reconstructed locally; `orders` not reconstructed (purpose unknown) | `supabase/migrations` |
| Docker/Actions | PLANNED/UNKNOWN | **GitHub Actions CI implemented** (app + db jobs) | `.github/workflows/ci.yml` |
| Reproduktionscheck | to do | done for code; DB still needs the live pull | `docs/recovery/RECOVERY_LOG.md` |

## Proposed section to append

```markdown
## Verified 2026-10-21 (Git + CI)

Branch `recovery/main` (to become `main` at M2). Source: recovered `src/` imported from the
Project copies (byte verification against `src.zip` pending). Results come from GitHub Actions.

| Bereich | Status |
|---|---|
| Build, Lint, Typecheck | IMPLEMENTED — grün in CI |
| Next.js | IMPLEMENTED — 16.4.1, `npm audit` 0 |
| Unit-Tests | IMPLEMENTED — 25 Vitest-Tests für die Legacy-Attention-Regeln |
| Lokale DB | IMPLEMENTED — rekonstruierte Baseline-Migration, synthetischer Seed, pgTAP |
| Auth / Routenschutz | NOT IMPLEMENTED — T8 |
| Mandanten-RLS | NOT IMPLEMENTED — lokale Legacy-Policies spiegeln den unsicheren Live-Stand (T9) |
| Audit / Server-Commands | NOT IMPLEMENTED — T10 |
| `/matching`, `/partners` | Mock; standardmässig ausgeblendet |

Laufende Steuerung: `docs/engineering/` (Backlog, Roadmap, Security, Tech-Debt, Entscheidungen).
```
