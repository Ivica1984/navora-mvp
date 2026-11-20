---
id: HD
title: Heim-Dienstplanung als vollständiges Register (Wochenplan, Abwesenheit, Lücke, externer Auftrag, Statusrückfluss, Ausfall-Optionen)
author: po
status: draft
updated: 2026-11-20
---

# HD — Heim-Register «Dienstplanung» (PO-Produktvertrag, Entwurf)

**Ursprung:** Founder-Nachrichten FE-108 (2026-11-20 ca. 15:15) und Founder-Prüfung des Grundrisses (ca. 16:00, Vermerk unter FE-108). **Status:** `draft` bis der Founder die Baufolge bestätigt (`docs/architecture/PLATFORM_GRUNDRISS.md` §8) und `eng` das WIE (ARCH1, #1614) bestätigt. **Gate:** «Simulation, synthetische Daten». Der PO hat keine Tests ausgeführt.

## Nutzerergebnis (Produktabnahme nur als Ganzes, auf Staging)

Die berechtigte Heimleitung sieht Stationen und synthetische Mitarbeitende mit Namen und Qualifikationsstatus, plant ihre Woche, erkennt eine Abwesenheit und die daraus entstehende Lücke, prüft einen vorbereiteten externen Auftrag, sendet ihn ab und sieht nach der Entscheidung eines selbstorganisierten Teams den zutreffenden Status wieder im Wochenplan, auch nach einem späteren Ausfall.

## Regeln, die dieser Vertrag festlegt (WAS)

1. **Mindestbesetzung je Dienst setzt das Heim als Daten.** NAVORA erfindet keinen Personalschlüssel und keine klinische Regel. Werte im Simulationskonto sind als Beispiel gekennzeichnet.
2. **Qualifikationsstufen** aus `QUALIFICATION_MATRIX.md`, für Phase A nur vorgeschlagene Simulationsgrundlage; keine Freigabe für reale Versorgung.
3. **Interne Planung und externer Auftrag getrennt:** Heimmitarbeitende gehören dem Heim (B2B-Modul 1, eigener Geldstrom); externe Teams organisieren sich selbst; das Heim kann keine bestimmte externe Person einteilen.
4. **Fünf Zustände**, überall gleich (Wochenplan, Externe Aufträge, Team, /field, Mitteilung): Angebot offen · kein passendes Team · Team hat zugesagt, Person bestätigt noch · Besetzung bestätigt («Gedeckt») · Ausfall nach «Gedeckt» («Nicht mehr gedeckt» + nächster Schritt). «Gedeckt» nie ohne geprüfte eingeteilte Person. Die Auftraggeber-Texte bestehen bereits (`src/features/orders/offer-rules.ts`).
5. **Kein leerer Menüpunkt:** das Register ist bis zur Produktabnahme nur für das Simulationskonto freigeschaltet und nicht im Menü.
6. **KI (HD-4):** feste Regel berechnet die erlaubten Optionen (intern: qualifiziert, frei, ohne Überschneidung; extern: Auftrag); das Modell erklärt sie kurz und begründet eine Empfehlung nur aus diesen Daten; die Heimleitung entscheidet; Vorschlagsprotokoll, Not-Aus, nur Staging und Simulation; ohne Modell erscheinen die Optionen mit festem Regeltext, gekennzeichnet «regelbasiert, keine KI».
7. **Daten:** nur synthetische Namen; Heimmitarbeitendendaten sind für NAVORA-Teams, Coach und andere Heime unsichtbar (RLS, pgTAP).

## Technische PR-Folge (Vorschlag PO; `eng` bestätigt oder ersetzt)

| PR | Inhalt | Abhängig | Gate |
|---|---|---|---|
| HD-1 | Datenmodell und Rechte (Standort, Station, Heimmitarbeitende, Qualifikationsstatus, Dienstvorlage, Dienst, Einteilung, Abwesenheit, Mindestbesetzung), RLS, Audit, ganze Funktionen, pgTAP Isolation | STAB1 | `lca` (Personaldaten Heim, Rolle Verantwortliche/Auftragsbearbeiter) und `cra` (Qualifikation) früh auf dem Datenmodell |
| HD-2 | Wochenplan: einteilen, Abwesenheit, Lücke (feste Regel); Tablet und 390 px | HD-1 | gemeinsames Fenster |
| HD-3 | Lücke → vorbefüllter Auftrag über `preview_client_order`/`confirm_client_order`; Statusrückfluss mit den fünf Zuständen; Ausfall → «Nicht mehr gedeckt» mit nächstem Schritt | HD-2 | gemeinsames Fenster |
| HD-4 | Ausfall-Optionen (Regel + Modellerklärung) über das AI1-Gateway | HD-3, AI1 | `cra`, `uxa`, `aia` im gemeinsamen Fenster |

## Gemeinsames Staging-End-to-End-Gate (Produktabnahme)

1. `staging-smoke` Pfad 4 mit synthetischem Heimkonto: anmelden → Station und Mitarbeitende → Abwesenheit → Lücke → vorbereiteten Auftrag senden → Basler Pflegekraft übernimmt → Wochenplan «Team hat übernommen, Person bestätigt noch», dann «Gedeckt».
2. Negativfall auf Staging: bestätigte Person fällt aus → «Nicht mehr gedeckt» mit nächstem Schritt.
3. Negativfälle in CI: fremdes Heim, NAVORA-Team und Coach lesen keine Heimmitarbeitenden; Einteilung ohne passende Stufe abgelehnt; Modell aus → Regeltext.
4. `ci-repeat` 10/10 (`db`, `e2e`) auf dem benannten Commit; alle Gate-Zeilen auf einem Kopf.
5. Meldung an den Founder mit Klickpfad, App-Commit, Migrationsstand, Lauf-ID und Grenzen; erst dann Menüpunkt.

## Nicht in HD

Monatsansicht, Wochenplan-Vorschlag durch KI, Arbeitszeitgesetzprüfung (offen bei `lca`), Mitteilungen als Push, Einstellungen mit Modulbuchung, Dokumentation (Modul 2), Angehörige (Modul 3), Spital, Privatperson, reale Daten.

## Vision-Check (FE-070 (7), kurz)

Mehr direkte Pflegezeit: keine Telefonkette bei Lücken. Kontinuität: ehrlicher Deckungsstatus, Ausfall sofort sichtbar. Einkommen: Heim zahlt den Teampreis direkt, kein Agenturaufschlag, keine Provision. Autonomie: Team entscheidet über die Übernahme. Weniger Verwaltung: Auftrag ohne Abtippen. Geschäftsmodell: Dienstplanung ist getrennter B2B-Umsatz.
