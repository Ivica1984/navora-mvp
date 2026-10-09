# NAVORA — Database and Data Model

**Quelle:** älterer Code plus damalige Supabase-SQL-Screenshots. Aktueller Live-Stand **VERIFY AGAINST DATABASE AND REPOSITORY**. Schemata in früheren NAVORA-Dokumenten sind Entwürfe, nicht automatisch angewandte Migrationen.

## Bestätigte Tabellen [IMPLEMENTED im damaligen Datenbankstand]

`public.cases`, `teams`, `partner_requests`, `matching_requests`, `match_candidates`, `care_visits`, `care_notes`, `quality_events`, `orders`. **UNKNOWN:** Zugehörigkeit und Semantik von `orders` (NICHT als NAVORA-Payments annehmen).

## Bestätigte FK-Beziehungen [IMPLEMENTED damals]

```text
cases.assigned_team_id → teams.id
matching_requests.case_id → cases.id
matching_requests.selected_team_id → teams.id
match_candidates.matching_request_id → matching_requests.id
match_candidates.team_id → teams.id
partner_requests.converted_case_id → cases.id
care_visits.case_id → cases.id; care_visits.team_id → teams.id
care_notes.case_id → cases.id; care_notes.visit_id → care_visits.id; care_notes.team_id → teams.id
quality_events.case_id → cases.id; quality_events.visit_id → care_visits.id; quality_events.team_id → teams.id
```

Alte `operations/queries.ts` selektiert u.a. `cases.assigned_team_id`, `teams.utilization/open_slots/coach_name/priority`, `matching_requests.required_services/status`, `care_visits.status/visit_date`, `care_notes.status`, `quality_events.severity/status`. Spätere Korrektur in `cases/queries.ts` ergänzte `assigned_team_id` und entfernte falsch typisierte Relation; **VERIFY AGAINST REPOSITORY**.

## Kandidaten [IMPLEMENTED damals]

Screenshot zeigte `match_candidates`: `id uuid default gen_random_uuid()`, `created_at timestamptz default now()`, `matching_request_id uuid nullable`, `team_id uuid nullable`, `fit_score integer default 0`, `distance_km numeric nullable`, `utilization integer nullable`, `open_slots integer nullable`, `reasons text[] default {}`, `status text default suggested`. FK auf Request/Team und PK auf ID; kein belegter Unique Constraint `(matching_request_id, team_id)`. Zwölf `suggested` Kandidaten für vier offene Requests gesehen. Bereits vorhandene Scores/Distanzen nicht als validiert werten. **OPEN:** Backfill/Unique-Index nach Duplikat- und NULL-Analyse.

## Geodaten [IMPLEMENTED damals]

PostGIS 3.3.7; `cases.location geography(Point,4326)` plus `location_status/accuracy/source/updated_at`; `teams.base_location geography(Point,4326)` plus entsprechende Metadaten und `service_radius_km`. Private Funktion `private.calculate_case_team_distance_km(uuid,uuid)` war `anon=false`, `authenticated=false`, `service_role=true`; fehlende Koordinaten führen zu `NULL`. `private.geocoding_jobs` mit Fall-/Teamziel, Status, Versuchen, Provider, Zeiten, aktiven-job-begrenzenden Indizes. Mehrfachstandorte via `team_locations` wurden als SQL vorgeschlagen, tatsächliche Anlage **UNKNOWN — VERIFY AGAINST DATABASE**. Bei Geocoding-Worker und API-Provider **OPEN**.

## Sicherheit [kritisch]

RLS für bestehende neun Tabellen war aktiviert; Screenshots zeigten aber `{public}`-Policies mit `true` für Lesen/Schreiben von `cases`, `care_visits`, `teams`. Erst neues Rollen-/Organisationsmodell und negative Tests bauen, dann kontrolliert alte Policies ersetzen. RLS `true` bedeutet **nicht** sicher. DB-Migrationen aus SQL-Editor-Verlauf fehlen eventuell im Repository.

## Zielmodell [PLANNED]

- **Identity/Governance:** `organizations`, `legal_entities`, `profiles`, `organization_memberships`, `team_memberships`, `access_grants`, `audit_events`, `break_glass_events`, `retention_policies`.
- **Cases & Care:** `care_needs`, `care_plans`, Verordnungen/Kompetenznachweise nach Fachreview.
- **Teams & Planning:** `team_members`, `team_locations`, `team_availability`, `team_capacity_windows`, `team_decisions`, `team_visit_claims`, `team_agreements`, `coaching_cases`.
- **Field:** `visit_events`, `visit_time_segments`, `visit_observations`, `handover_items`, `offline_sync_receipts`.
- **Documentation/AI:** `documentation_drafts`, `documentation_versions`, `ai_generation_runs`, menschlich freigegebene `care_notes`.
- **LTCF/PAG/MQI:** `ltcf_assessment_instances`, `ltcf_assessment_answers`, `pag_calculation_runs`, `mqi_indicator_versions`, `mqi_measurement_periods`, `mqi_snapshots`, Datenqualitätsprüfungen und Provenienz.
- **Rules/Architect:** `source_documents`, `source_sections`, `rule_definitions`, `rule_versions`, `rule_dependencies`, `rule_test_cases`, `rule_evaluation_runs`, `explanation_traces`, `impact_analysis_runs`.
- **Finance:** `payer_contracts`, `tariff_versions`, `billable_facts`, `billing_holds`, `invoices`, `payroll_time_entries`, `team_revenue`, `team_costs`, `team_surplus_periods`, `platform_fees`.

Einige SQL-Entwürfe liegen in vorherigen Dokumentenpaketen, ohne nachgewiesene Integration. **Keine automatische Ausführung** gegen die Produktionsdatenbank.

## Migrationsregeln

1. Aktuellen Ist-Zustand und FK/Indizes/RLS/Grants erfassen; bestehende Daten klassifizieren.
2. Organisationseinführung und Backfill mit fachlicher Zuordnung und trockenen Testläufen planen.
3. Additive, versionierte Migrationen; bei Feldern mit Gesundheitsdaten Scope/Policy vor Freischaltung testen.
4. Datenbank-Constraints für Zeit, Status, Eindeutigkeit, Gültigkeit; fachliche Transaktionen/Audit separat.
5. Staging, Backup, Rollback/Forward-Fix und negative Berechtigungstests vor Production.
6. Kein `service_role` im Browser; kein Zugriff auf fremde Mandanten oder Fälle aus bloss vorhandener Session.
