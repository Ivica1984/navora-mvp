# Produktionsreife: Owner-Antworten vom 2026-11-07 (begleitete Sitzung mit `eng`)

**Quelle:** begleitete Sitzung Owner (Ivica1984) mit dem Engineering-Agenten, 2026-11-07 ca. 14:30–15:30 CET, Frage für Frage.
**Status dieses Dokuments:** Protokoll der Owner-Antworten durch `eng`. Es ändert **keine** Founder-Entscheidung, kein Paket und keine Governance-Regel (README Regel 10, 11). Der PO übernimmt die Antworten in `FOUNDER_DECISIONS.md` (neue FE-Zeilen) und in die Pakete D-2, D-7, D-8, D-41, D-43 und FD-27/FD-28 in seinem nächsten Lauf.
**Labels:** IMPLEMENTED · PLANNED · OPEN · UNKNOWN (CLAUDE.md).

## Antworten

| # | Thema | Owner-Antwort (sinngemäss, Zitate in Anführungszeichen) | Wirkung | Status |
|---|---|---|---|---|
| 1 | Repo-Schutz (D-7, SR-14, SR-18) | „Es braucht die allerhöchste Sicherheit, Repo darf nicht öffentlich sein, keine Konkurrenz darf den Code sehen. Branch-Schutz muss sofort mit höchster Stufe eingerichtet werden. Ein fehlerhafter Agent darf keinen Code direkt in die Hauptversion schreiben. Alles, was in die Hauptversion geschrieben wird, muss zwingend getestet werden. Es braucht zwingend ein Secret Scanning.“ Vorgehen: **Stufenplan** (siehe unten). | D-7 beantwortet: Ruleset, Secret Scanning, Push Protection, Dependabot, dann privat | PLANNED (Owner-Klicks; die Session darf Repo-Einstellungen nicht schreiben: Proxy-Antwort 403 „Repository settings writes are not permitted through this proxy“, 2026-11-07) |
| 1c | Freigabe von PRs | **Eigenes Agenten-Konto.** `eng` präzisiert: zwei Identitäten nötig (`navora-eng` schreibt, `navora-po` genehmigt und merged), Owner einziger Admin; bis dahin *Required approvals* = 0, danach 1. | Neue Arbeitsweise; betrifft alle Agenten-Prompts | PLANNED (Owner legt Konten an) |
| 2 | Altes Supabase-Projekt `jwmfxrmougneeceldhsa` (FD-27, SR-26) | **Ganzes Projekt löschen** (Variante b, unumkehrbar). | FD-27 beantwortet; Schlüsselrotation entfällt | PLANNED (Owner im Supabase-Dashboard; kein Agent berührt das Projekt) |
| 3 | Paketquelle für Agenten-Sessions | **`registry.npmjs.org` freigeben.** | LOCAL TEST RULE wird voll ausführbar | PLANNED (Owner, Netzwerkeinstellungen der Scheduled Tasks) |
| 4 | `main` zusammenführen (D-8) | **Variante B:** zwei `preserve-*`-Tags, dann PR #3 mit grünen Tests mergen, nach dem Ruleset. | D-8 beantwortet | PLANNED |
| 5 | Datenbank (D-2) | **Supabase Team, Zürich `eu-central-2`, PITR 28 Tage.** Staging jetzt (Pro, Kunstdaten), Produktion ca. 1 Monat vor Phase B. | D-2 Datenbankteil beantwortet | PLANNED (T12) |
| 6 | App-Host (D-2) | **Schweizer App-Host** (Variante B, Container in CH-Region). `eng` legt 2–3 Anbieter mit Preis vor. Ersetzt den PO-Staging-Default Render Frankfurt. | D-2 App-Teil beantwortet; `D2_PRODUCTION_HOSTING_ASSESSMENT.md` §8 Abweichung aufgelöst | PLANNED (8–12 PT einmalig, 1–2 PT/Monat) |
| 7 | Verfügbarkeit, Datenverlust (RQ-1, RQ-2) | **99,9 % gemessen (kein Vertrag), RPO ≤ ca. 2 Min. mit getesteten Wiederherstellungen, Papier-Notfallplan.** | D-2 §10 Fragen 1, 2 beantwortet | PLANNED |
| 8 | Zusatzdienste | **Backup in CH, Uptime-Überwachung mit Alarm, Fehler-Tracking ohne Personendaten, E-Mail-Versand CH/EU.** Alle als Auftragsverarbeiter mit Vertrag (`lca`). | D-2 §10 Frage 5 | PLANNED (`eng` Anbietervorschläge) |
| 8c | Bereitschaft | **Owner + Ansprechperson im Pilotteam; Team wechselt bei Ausfall auf Papier-Notfallplan; technische Behebung per Runbook.** | M10.3 | PLANNED |
| 9 | Sicherheitstest | **Red-Team-Agenten** greifen laufend Staging an (nur Kunstdaten, nie Produktion) **+ ein kleinerer externer Test vor echten Daten.** | D-2 §10 Frage 6; neue Fähigkeit (PO platziert) | PLANNED |
| 10 | Klinische Freigabe (D-43) | „…wird diese Informationen bald mitteilen.“ | D-43 bleibt `awaiting approval: owner` | OPEN |
| 11 | Rechtsberatung (FD-28) | **Gebündelt Q1 2027:** `lca` stellt den Fragenkatalog fertig, Offerten bis Dezember, Mandat Januar, Antworten vor M9. (Agenten kontaktieren keine Kanzlei; der Owner versendet die vorbereiteten Anfragen.) | FD-28 Teil 2 Zeitplan | PLANNED |
| 12 | KI und echte Daten (D-41) | „KI ist entscheidend für NAVORA und soll die Daten verarbeiten können, ohne auf Patientendaten zurückzugreifen.“ Gewählt: **Muster 1** (Planung nur mit Kennungen und Planungsfakten), **Muster 2** (nur Team-Kennzahlen), **Muster 3** (strukturierte Erfassung, Bericht per Regel ohne KI) als Kern sofort; **Muster 4** (eigenes Sprachmodell im Schweizer NAVORA-Rechenzentrum) vorbereiten und mit Kunstdaten testen, Einschalten für echte Daten erst nach Rechtsgutachten und DSFA. **Muster 5** (Pseudonymisierung für externe KI) **nicht** gewählt. | D-35 Regel A bleibt in Kraft; Richtung für D-41 | Richtung; PLANNED |

## Stufenplan Repo-Schutz (Antwort 1)

1. **Jetzt, Owner (öffentliches Repo, kostenlos):** Ruleset `Schutz Hauptversion` auf `main` und `recovery/main`, aktiv, Bypass-Liste leer: Löschen und Force-Push gesperrt, PR Pflicht mit gelösten Diskussionen, vier Pflicht-Checks `app (lint · typecheck · unit · audit · build)`, `db (migrations · seed · pgTAP)`, `e2e (auth · protected routes · Playwright)`, `ui-screenshots (390 · 1440 · every role)`. Secret Scanning, Push Protection, Dependabot alerts und security updates an. Zwei-Faktor-Anmeldung (Passkey) auf dem Owner-Konto.
2. **Owner bucht:** GitHub Pro (Branch-Schutz für private Repos) und GitHub Secret Protection (Secret Scanning für private Repos). Preise nach `eng`-Wissensstand ca. 4 USD und ca. 19 USD pro aktivem Committer und Monat: UNKNOWN bis in GitHub geprüft.
3. **`eng` senkt die CI-Minuten** vor dem Umschalten (heute gemessen: ca. 175 Läufe pro Tag, ca. 13 Min. pro Lauf, ca. 70'000 Min. pro Monat; privat inklusive 2'000 bzw. 3'000 mit Pro): Läufe nur für PRs und `recovery/main`/`main`, `concurrency` mit Abbruch überholter Läufe, schwere Jobs (e2e, ui-screenshots) nicht bei reinen Dokumentänderungen. Eigenes ADR und eigener PR. **Achtung:** Ein Pflicht-Check, der bei Doku-PRs übersprungen wird, darf den Merge nicht blockieren und nicht ungeprüft durchlassen: das ADR regelt das (z. B. ein schneller Ersatz-Job mit demselben Namen).
4. **Dann privat schalten** (Owner).

## Was dieses Dokument nicht tut

- Es setzt keine klinische, rechtliche oder Tarif-Regel.
- Es ändert `FOUNDER_DECISIONS.md`, `NEXT_CAPABILITY.md` und die Pakete nicht (PO-Dateien).
- Kosten sind Listenpreise oder Schätzungen und als solche gekennzeichnet; keine Offerte liegt vor.
