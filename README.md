# NAVORA

Plattform für selbstorganisierte Pflegeteams in der Schweiz (Next.js · TypeScript · Supabase).

> **Entwicklungsstand — nicht für echte Patientendaten.**
> Dieser Code läuft nur gegen eine lokale Supabase-Instanz mit synthetischen Daten.
> Authentifizierung, mandantenfähige RLS und Audit fehlen noch (Roadmap Gate 1, Meilenstein M3).
> Bekannte Risiken: [`docs/engineering/SECURITY_RISKS.md`](docs/engineering/SECURITY_RISKS.md).

## Status (Stand 2026-10-21)

| Bereich | Status |
|---|---|
| Routen `/operations`, `/teams`, `/visits` mit Supabase-Lesezugriff | IMPLEMENTED (legacy, aus Recovery) |
| `/matching`, `/partners` | IMPLEMENTED als Mock; standardmässig ausgeblendet (`NEXT_PUBLIC_FEATURE_DEMO_PAGES`) |
| Login | IMPLEMENTED im Browser, **ohne** serverseitigen Routenschutz — T8 |
| Mandanten-RLS, Audit, serverseitige Commands | PLANNED — T9, T10 |
| `/field` (mobiles Einsatz-Tool) | PLANNED — M4 |

Herkunft des Codes und Verifikationsstand: [`docs/recovery/RECOVERY_LOG.md`](docs/recovery/RECOVERY_LOG.md).

## Lokale Entwicklung

Voraussetzungen: Node 24 (`.nvmrc`), Docker, [Supabase CLI](https://supabase.com/docs/guides/local-development).

```bash
npm ci
supabase start                 # lokale DB, Auth, API — gibt URL und anon key aus
supabase db reset              # Migrationen + synthetischer Seed
cp .env.example .env.local     # NEXT_PUBLIC_SUPABASE_ANON_KEY aus `supabase start` eintragen
npm run dev
```

Niemals `.env.local` auf das bestehende Live-Projekt zeigen lassen, und niemals gegen das Live-Projekt bauen (SR-05).

## Qualitätschecks

| Befehl | Zweck |
|---|---|
| `npm run lint` | ESLint |
| `npm run typecheck` | Next-Routentypen + `tsc` |
| `npm test` | Vitest (reine Regeln, z.B. `features/operations/rules.ts`) |
| `npm run test:db` | pgTAP gegen lokale Supabase (`supabase test db`) |
| `npm run build` | Produktionsbuild ohne Datenbankzugriff |

CI (`.github/workflows/ci.yml`) führt alle Schritte auf jedem PR aus.

## Struktur

```text
src/app/                 Routen (Server-Pages + Client-Views)
src/features/<feature>/  queries.ts · rules.ts (rein, testbar) · types.ts
src/lib/                 Supabase-Client, Feature-Flags
supabase/                Migrationen, Seed (synthetisch), pgTAP-Tests
tests/unit/              Vitest
docs/engineering/        Backlog, Roadmap, Tech-Debt, Security, Entscheidungen
docs/recovery/           Herkunft und Prüfsummen des wiederhergestellten Codes
```

## Dokumentation

Fachlicher Kontext (Übergabe): `MASTER_CONTEXT.md`, `ARCHITECTURE.md`, `DOMAIN_RULES.md`, `TECHNICAL_DECISIONS.md`, `CURRENT_IMPLEMENTATION_STATUS.md`.
Laufende Engineering-Steuerung: `docs/engineering/`. Bei Widerspruch gilt der Code; Abweichungen werden dokumentiert (`CLAUDE.md`).
