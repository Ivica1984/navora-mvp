# IMPLEMENTATION_STATUS

**Owner:** Engineering Agent (schreibt). **Leser:** Product Owner. **Stand:** 2026-10-21 (Erstanlage durch Product Owner aus Live-Befund; Engineering übernimmt ab sofort).

## Protokoll

- Engineering aktualisiert diese Datei bei jedem abgeschlossenen Schritt, mindestens am Ende jeder Arbeitssitzung.
- Status nur mit Nachweis: Commit/PR, Testname, Migrationsname oder Befehl mit Ergebnis. Ohne Nachweis bleibt der Status „UNVERIFIED“.
- Statuswerte: `NOT STARTED` · `IN PROGRESS` · `BLOCKED` · `READY FOR REVIEW` · `ACCEPTED` (nur Product Owner setzt `ACCEPTED`).
- Abweichungen von Akzeptanzkriterien, neue Risiken oder fehlende Entscheide → Eintrag in `OPEN_DECISIONS.md`, hier nur verlinken.
- Keine Secrets, keine Patientendaten, keine personenbezogenen Testdaten in dieser Datei.

## Gesamtstatus

| Fähigkeit | Status | Letzte Änderung | Nachweis | Blocker |
| --- | --- | --- | --- | --- |
| Gate 0 Repo-/Schema-Inventar | NOT STARTED | — | — | Repository-Zugriff |
| F0 Shared Access Foundation | NOT STARTED | — | — | OD-E1 |
| J1 Referral Intake → Case → Matching Request | NOT STARTED | — | — | F0, OD-F1, OD-C1 |
| J2 Team Decision Workflow | NOT STARTED | — | — | J1, OD-O1–O3 |
| J3 Visit Planning | NOT STARTED | — | — | J2, OD-C2 |
| J4 Verified Visit | NOT STARTED | — | — | J3 |
| J5 Billable Visit Facts | NOT STARTED | — | — | J4, OD-F1 |
| J6 Continuity of Care | NOT STARTED | — | — | J3, J4 |
| J7 Team Economics | NOT STARTED | — | — | J5, OD-F4 |

## Verifizierter Ausgangszustand

Live-Supabase, read-only geprüft am 2026-10-21 durch Product Owner (Projekt `jwmfxrmougneeceldhsa`, Annahme: NAVORA-Projekt, da Tabellennamen übereinstimmen):

| Befund | Wert |
| --- | --- |
| Öffentliche Tabellen | `orders`, `teams`, `cases`, `care_visits`, `partner_requests`, `matching_requests`, `match_candidates`, `care_notes`, `quality_events`, `team_locations` (neu seit Übergabe) |
| Datenzeilen | 0 in allen öffentlichen Tabellen |
| RLS | aktiv auf allen Tabellen, **keine Policies** → jeder Zugriff über die App gesperrt |
| Frühere `{public}`-Policies | nicht mehr vorhanden |
| Migrationshistorie | nur `20261021141556 capability_probe_noop_2026_10_21`; Schema nicht versioniert |
| Security Advisor | Leaked-Password-Schutz aus; `authenticated` kann alle 9 Fachtabellen im GraphQL-Schema sehen |
| Privat | `private.geocoding_jobs` mit RLS ohne Policies |

Noch nicht verifiziert (aus Übergabe 9.10.2026, **VERIFY AGAINST REPOSITORY**): Next.js-Version, `@supabase/ssr`-Nutzung, Routen `/operations`, `/matching`, `/partners`, `/teams`, `/visits`, Lint/Build-Status, CI, Hosting.

## Aktive Fähigkeit: F0 — Akzeptanznachweis

| Kriterium | Status | Nachweis |
| --- | --- | --- |
| Live-Schema als versionierte Migrationen; frischer Aufbau = Live | NOT STARTED | |
| Organisationen, Teams, Mitgliedschaften, Qualifikationen als Daten | NOT STARTED | |
| Negativtest anonym → nichts | NOT STARTED | |
| Negativtest Partner A ≠ Partner B | NOT STARTED | |
| Negativtest Team X ≠ Team Y | NOT STARTED | |
| Negativtest nicht zugewiesene Pflegekraft → keine Falldetails | NOT STARTED | |
| Audit + Idempotenz für zustandsändernde Commands | NOT STARTED | |
| Synthetische Testdaten, keine realen Personen | NOT STARTED | |
| Leaked-Password-Schutz aktiv; GraphQL-Sichtbarkeit geprüft | NOT STARTED | |

## Änderungslog

| Datum | Wer | Änderung |
| --- | --- | --- |
| 2026-10-21 | Product Owner | Datei angelegt; Live-Befund eingetragen |
