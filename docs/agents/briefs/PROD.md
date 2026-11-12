---
id: PROD
title: Produktivbetrieb mit synthetischen Daten (PROD1-PROD3)
author: po
status: draft
updated: 2026-11-12 04:39
---

# PROD — Produktivbetrieb mit synthetischen Daten (PROD1-PROD3)

**Block:** B11 (Integration, Staging, Wiederherstellung) und B12-Teil «Produktion»; **Einordnung unter FE-054 offen** (Owner-Frage in [`../decisions/OWNER_AGENDA.md`](../decisions/OWNER_AGENDA.md) Bundle 1, 2026-11-12 03:39). **Status draft:** wird erst `approved`, wenn der Owner (A), (B) oder (C) beantwortet hat. Bis dahin baut `eng` nichts davon (FE-054).

**Quelle:** Owner-Antworten vom 2026-11-11 in der begleiteten `eng`-Sitzung, Issue #1097 (FE-062 bis FE-067, `FOUNDER_DECISIONS.md` v18). Die drei Teile hat `eng` vorgeschlagen; der PO übernimmt sie als Entwurf und schärft die Kriterien.

## Problem
Der Owner will den Produktivbetrieb jetzt so gebaut haben, «als würden echte Daten darauf laufen», zunächst mit Testdaten (FE-062). Heute gibt es nur Staging (STG1, #1087, noch nicht gemergt). Ohne eigenen Produktivpfad würden Migrationen, Build und Konten später unter Zeitdruck vor Phase B entstehen, wo Fehler echte Daten treffen.

## Users and journey step
Kein Pflegeschritt; Betriebsgrundlage für alle Schritte Anfrage → Abrechnung. Nutzende: Owner (Betrieb), `eng` (CI), später Teams, Heim, Spital, Privatpersonen.

## Outcome
Auf `navora-prod` (Supabase Zürich, Free, FE-063) und Infomaniak Jelastic Cloud (FE-064) läuft NAVORA aus der CI, mit einer eigenen synthetischen Basler Testwelt (FE-066) und ohne Repository-Seed, ohne Management-Token und ohne Service-Role-Schlüssel auf dem App-Server (FE-067).

## Acceptance criteria
**PROD1 Migrationen nach `navora-prod` nur aus der CI**
- [ ] Ein CI-Job wendet die Migrationen nur nach den vier grünen Jobs (`app`, `db`, `e2e`, `ui-screenshots`) auf dem Merge-Commit von `recovery/main` an; nie aus einem PR-Branch (Test: Workflow-Bedingung; Probe-Lauf auf einem PR zeigt den Job `skipped`).
- [ ] Verbindung direkt über den Pooler mit dem DB-Passwort aus einem GitHub-Secret, **ohne** Supabase-Management-Token (Nachweis: Workflow-Datei nennt kein `SUPABASE_ACCESS_TOKEN`; Secret-Liste im PR-Text).
- [ ] Der Repository-Seed wird nie angewendet (negativer Test: der Job ruft kein `seed.sql` auf; ein Prüfschritt bricht ab, wenn er es täte).
- [ ] Fehlt ein Secret, ist der Job rot mit klarer Meldung, nicht grün übersprungen.

**PROD2 Container und Deployment nach Infomaniak aus der CI**
- [ ] Container-Build aus dem Merge-Commit; Deployment nur nach PROD1 grün.
- [ ] Auf dem App-Host liegt nur der anon-Schlüssel; kein Service-Role-Schlüssel (FE-067; Nachweis: Umgebungsvariablen-Liste ohne Werte im PR-Text).
- [ ] HTTPS auf der Standard-Subdomain (FE-065); ein Smoke-Test nach dem Deployment prüft Login-Seite und eine geschützte Route (Weiterleitung ohne Sitzung).
- [ ] Kein Fehler-Tracking und kein Log mit Personendaten (FE-048 Zusatzdienste).

**PROD3 Basler Produktions-Testwelt**
- [ ] Eigener Seed, getrennt vom Repository-Seed; Passwörter nur aus GitHub-Secrets, nie im Code (Test: Suche nach Passwort-Literalen im Seed schlägt fehl).
- [ ] Anbieter sind selbstorganisierte Teams in Basel (BS/BL, FE-019); erster Kunde ein simuliertes Pflegeheim; **keine Rolle, kein Kunde und keine Organisationsart «Spitex» oder «Temporärbüro»** (FE-066; negativer Test).
- [ ] Nur synthetische Daten; keine echte Person, Adresse oder Versicherungsnummer.
- [ ] Konten werden von CI oder vom Owner angelegt (FE-067).
- [ ] **Simulationsorganisationen (`cra` CGR-190, PO 2026-11-12 05:39):** jede PROD3-Organisation ist eine Simulationsorganisation (`organizations.simulation = true`, Phase A, synthetisch, D-29), gesetzt nur durch den PROD3-Seed, damit dieselben QUAL1-Prüfungen laufen wie in CI und Staging. Test im PROD3-Job: nach dem Seed ist die Zahl der PROD3-Organisationen mit `simulation = false` gleich 0, und ein QUAL1-Stoppfall (eine Pflegehilfe als verantwortliche Person eines KLV-B-Einsatzes wird abgewiesen) läuft gegen die Produktion.

**`lca`-Bedingungen (P-a) bis (P-d)** (`lca` 2026-11-12 04:27, PR #1110, D-2: «compliant under every plausible interpretation» für Produktion nur mit synthetischen Daten; beratend, keine Rechtsberatung). Als Kriterien übernommen (PO 2026-11-12 04:39):
- [ ] **(P-a)** Jeder Klientendatensatz ist erfunden; nichts aus `jwmfxrmougneeceldhsa` wird geladen (negativer Test: kein Workflow, Skript oder Seed nennt diese Projekt-ID oder deren URL).
- [ ] **(P-b)** Konten tragen keine echten Namen; wer eine echte E-Mail-Adresse nutzt (Owner, Testperson), wird informiert, was wo gespeichert ist (Nachweis: kurzer Hinweistext im PR und im `OWNER_RUNBOOK`).
- [ ] **(P-c)** Keine echten Personendaten «für einen schnellen Test»: sichtbarer Hinweis «Nur synthetische Daten» auf der Anmeldeseite der Produktion (Test: e2e-Prüfung auf den Hinweis in der Produktions-Konfiguration).
- [ ] **(P-d)** Die Infomaniak-AVV (DPA) wird mit dem Konto akzeptiert und eine datierte Kopie abgelegt (Owner; `eng` nennt im PR Datum und Ablageort, ohne Inhalt).
- [ ] `eng` meldet die Unterauftragsverarbeiter-Liste von Infomaniak für Jelastic Cloud und ob Zugriff von ausserhalb der Schweiz besteht (Eingabe für die Echtdaten-Prüfung; kein Abnahmehindernis für synthetische Daten).

**Für alle drei:** automatisierte Tests für jedes geänderte Verhalten und grüne CI auf PR-Kopf und Merge-Commit (FE-054); Secrets nur als GitHub-Secrets (Sicherheitsfrage, laut `lca` 04:27 keine Rechtsfrage, solange alles synthetisch ist); kein Zugriff der Agenten auf `navora-prod` ausserhalb der CI.

## Rules and their input class
Keine neue Pflege-, Abrechnungs- oder Qualifikationsregel; PROD3 nutzt die bestehende QUAL1-Matrix (QAM-0.2 PROPOSED) nur über das Simulationsmerkmal (CGR-190). **Linie für das Echtdaten-Tor (B12):** keine Organisation mit echten Daten ist eine Simulationsorganisation, und für echte Organisationen gilt die vom Clinical Owner genehmigte Qualifikationsregel (D-43; heute UNKNOWN welche). Betriebsregeln (CI-Bedingungen, Secret-Handhabung) sind technische Regeln, keine Klasse nach D-34.

## AI leverage
Keine KI-Hebelwirkung: Betriebsinfrastruktur. Entfernt wird Handarbeit beim Deployment (Migrationen und Build nur aus der CI, kein Dashboard-Klick). D-35 Regel A gilt: keine Klienten- oder Personaldaten an einen KI-Dienst.

## Out of scope
Echte Daten (FE-021, D-35, D-3, D-43, `lca`-Punkte); Team-Plan mit PITR (vor echten Daten, FE-063); eigene Domain (M3, FE-065); Einladung per E-Mail (D-26, FE-067); AVV Infomaniak (`lca`, vor echten Daten).

## Constraints and references
FE-048, FE-054, FE-057 (STG1-Muster), FE-062 bis FE-067; D-2, D-26; `ARCHITECTURE.md` (RLS, Audit); STG1 (#1087) als Vorlage für PROD1.

## Open questions for engineering
1. Kann PROD1 den STG1-Job wiederverwenden (gleiche Bedingungen, anderes Ziel), damit es nur eine Deploy-Logik gibt?
2. Free pausiert nach 7 Tagen ohne Nutzung: braucht der Smoke-Test einen geplanten Lauf, oder genügt der nächste Merge?
3. Bekannte Abweichung im Repository-Seed (Teams «Ambulante Pflege»/«Übergangspflege», Bern/Zürich statt BS/BL): OPEN, ohne automatische Änderung; Vorschlag von `eng` erwünscht.
