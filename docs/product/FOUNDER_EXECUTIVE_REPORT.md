# NAVORA Founder Executive Report

**Für:** den Owner (Founder) · **Verfasst von:** Product Owner (`po`) · **Ausgabe:** KW 47, Stand Freitag, 20. November 2026, 09:39 (Europe/Zurich), geplanter PO-Lauf 09:39 · **Vorausgabe:** KW 46 (13.11.2026, in der Git-Historie) · **Nächste Ausgabe:** Freitag, 27. November 2026 · **Rhythmus:** jeden Freitag neu (Prompt `po`)

**Dieses Dokument ist das primäre Entscheidungsdokument des Owners.** Quellen: [Blueprint V3.2](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md) §8 (Blockkette), §10 (Meilensteine und Kennzahlen), §11 (Entscheidungsboard); [`ABNAHMEAKTE.md`](ABNAHMEAKTE.md) §2; [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) v53. Der PO hat keine Tests selbst ausgeführt; alle Nachweise sind aus CI-Job-Protokollen gelesen. Jede Aussage ist gekennzeichnet: IMPLEMENTED, PLANNED, OPEN, UNKNOWN.

## Auf einen Blick (1 Minute)

- **Die Woche des Kernablaufs.** Block BK (der durchgehende Auftragsablauf) hat diese Woche vier Teilstücke für die Simulation abgenommen: **BK-b** (harte Prüfung, 17.11.), **BK-c** (Übernahme und Deckungsstand, 18.11.), **BK-e1** (Einsatz in `/field`, 18.11.) und **BK-e2**, damit **BK-e als Ganzes** (Berichtsentwurf und Unterschrift, 20.11.). Jede Abnahme auf einem benannten Commit mit `ci-repeat` 20/20. Gate jeweils: «Simulation, synthetische Daten», keine Freigabe für reale Personen.
- **Staging lebt.** Am 20.11. um ca. 09:05 lief `staging-smoke` zum ersten Mal grün gegen `navora-staging` (Lauf 44699041140, 3 von 3): Anmeldung, Auftrag bis «Gedeckt», Nachtschicht in `/field`. Die Datenbank auf Staging steht auf Migration 0153; App und Datenbank passen zusammen (`staging-version` grün). IMPLEMENTED.
- **Aktiv jetzt: BK-f «Rechnungsentwurf aus dem unterschriebenen Bericht»** (#1581, Entwurf). Ein Rundungsfehler von 1 Rappen wurde gefunden und behoben (BKF-F2). Noch nicht prüfbereit; offen ist der Klickpfad bei 390 px. PLANNED bis zum Merge.
- **Ihr Grundsatzentscheid dieser Woche (FE-099, FE-100):** keine Textflicken an Datenbankfunktionen mehr. Nach BK-f kommt **STAB1** (eine lesbare Datei je Kernfunktion, Drift-Wächter in der CI), dann **AI1** (erste echte KI-Funktion), dann BK-d, BK-g.
- **KI-Ehrlichkeit:** In keiner Umgebung ist heute ein KI-Modell angeschlossen. Der Berichtsentwurf auf Staging ist ein Testersatz mit festen Regeln («regelbasiert, keine KI»). Alle BK-f-Funktionen sind feste Regeln.

## 1. Abgeschlossene Lieferungen

### 1.1 Teilstücke von Block BK (für die Simulation abgenommen)

| Teilstück | Was eine Person jetzt tun kann (Simulation) | Commit, Nachweis |
|---|---|---|
| BK-b Harte Prüfung | Ein Auftrag geht nur an Teams, die Distanz, Stufe und Verfügbarkeit erfüllen | `ab90875`, `ci-repeat` 20/20 (17.11.) |
| BK-c Übernahme | Ein Mitglied übernimmt für sein Team, genau eine Übernahme gewinnt; die Auftraggeberin sieht «Gedeckt» erst nach Bestätigung, nie eine Teamzahl | `d51d1c1`, `ci-repeat` 20/20 (18.11.) |
| BK-e1 Einsatz in `/field` | Die benannte Pflegekraft sieht die übernommene Schicht; eine Nacht 22:00–07:00 ist ein Einsatz unter «Heute» | `3ea17ee`, `ci-repeat` 20/20 (18.11.) |
| BK-e2 Bericht | Notizen tippen → Entwurf mit Quellsatz je Zeile → jede Zeile einzeln entscheiden → unterschreiben | `8155ac6`, `ci-repeat` 20/20 (20.11.) |

Nicht Teil der Abnahmen: Freigabe für reale Personen und Daten, klinische Freigabe (D-27), echter KI-Entwurf. Die Liste der Punkte vor realen Personen steht je Teilstück in `ABNAHMEAKTE.md` §2 (OPEN).

### 1.2 Staging (Founder-Priorität FE-090)

- `staging-smoke` erster grüner Lauf gegen die echte Staging-Website: 20.11., Lauf 44699041140 (IMPLEMENTED).
- Migrationen bis 0153 auf `navora-staging` eingespielt, aus dem `staging`-Job-Protokoll gelesen (IMPLEMENTED).
- Versionsanzeige und `/api/version` auf Staging (#1561, #1580), App-Commit und Datenbankstand abgleichbar (IMPLEMENTED).

### 1.3 Ihre Entscheide diese Woche (FE-080 bis FE-100)

Wichtigste: FE-080 «Werkzeug-Modell» (NAVORA ist Software, kein Vermittler); FE-082/FE-083 Pflege-Genossenschaft als Zielform; FE-089 Bauphase mit pausierten Prüfrollen und Gate-Starts; FE-094 Claude über die Anthropic-API direkt, nur Staging, nur synthetisch; FE-095 «prüfbereites Paket statt Stundentakt»; FE-097 ein Freigabefenster je Paket; FE-098 Qualitätsprogramm Q1–Q6; FE-099 drei Engineering-Verbesserungen, Kostendeckel AI1 CHF 50 je Monat und 300 Aufrufe je Tag; **FE-100** STAB-1-Masterplan (heute ca. 09:35). Volltext: `FOUNDER_DECISIONS.md`.

## 2. Laufende Arbeit

| Paket | Stand | Kennzeichnung |
|---|---|---|
| **BK-f** Rechnungsentwurf (#1581) | Datenbank und drei Ansichten gebaut, pgTAP 156 grün; offen: e2e 390 px, Umstellung Migration 0154 auf vollständige Definitionen (FE-100), Bereitbericht, Gate `lca` (Pflicht), `cra`, `uxa` | Code auf Branch; PLANNED bis Merge |
| Toleranzzeile für Staging | Wert nennt `lca` im Gate; eigener einzeiliger PR nach dem BK-f-Merge; ohne sie zeigt Staging «Der Zeitabgleich ist noch nicht eingerichtet» | PLANNED |
| **STAB1** eine Quelle je Funktion | Vertrag geschrieben, nach FE-100 geschärft; `eng` bereitet auf `feature/STAB-1` vor, PR erst nach BK-f | PLANNED |
| **AI1** erste echte KI-Funktion | Berichtsentwurf aus den Worten der Pflegenden mit Claude, Staging, synthetisch; von Ihnen am 20.11. bestätigt | PLANNED |

## 3. Owner Decision Board (offen)

| # | Frage | Dringlichkeit |
|---|---|---|
| AI1 Render-Werte | Sie setzen API-Schlüssel und Schalter auf Render nach dem AI1-Bereitbericht (FE-099 (7) (4)) | hoch, nach STAB1 |
| G-1 / D-43 | Ernennung einer Clinical Owner (klinische Regeln, Matrix, Schwellen) | hoch vor Phase B |
| D-44 | Rechtsform und Vertragsweg der Teams (Genossenschaft gewählt als Ziel, Details offen); wer stellt die Rechnung: Team oder Genossenschaft | hoch vor realer Rechnung |
| D-14 | Höhe der Plattformgebühr | mittel |
| D-41 | KI-Pfad für reale Daten (Rechenzentrum, Gutachten, DSFA) | vor Phase B |
| D-2 | Auftragsverarbeitungsvertrag Hosting, Upgrade vor realen Daten | vor Phase B |
| B0-6 | Repository-Schutz (Ruleset) | mittel |
| GM-2 | Preis und Reihenfolge der B2B-Module | mittel |

## 4. Kritischer Pfad

BK-f (aktiv) → Toleranzzeile → BK-f-Abnahme → STAB1 → AI1 → BK-d «Station bestellt» → Abwesenheit für die Station → BK-g Szenario-Matrix → Abnahme Block BK → B2-Kern … → B11 Gesamttest → **M9 Phase A am 2027-03-12** (in Arbeit). Engpass dieser Woche: Wartezeit auf Gate-Zeilen pausierter Rollen und ein fehlender Konfigurationswert auf Staging.

## 5. Die nächsten 7 Tage (21.–27. November 2026)

1. BK-f prüfbereit, Gate-Fenster, Merge, Toleranzzeile, `staging-smoke` mit Rechnungspfad grün, Abnahme mit `ci-repeat`.
2. STAB1 starten (25 Kernfunktionen als Dateien, Konsolidierungs-Migration, Drift-Wächter).
3. **Bis 25.11.:** PO-Empfehlung zum Prüfrhythmus aus den realen Wartezeiten (FE-089 (6)).

## 6. Risiken

| Risiko | Wirkung | Gegenmassnahme |
|---|---|---|
| Geflickte Datenbankfunktionen (60 laut `eng`) | Schutzprüfungen können unbemerkt verloren gehen | STAB1 nach FE-100; Drift-Wächter |
| Wartezeit auf pausierte Prüfrollen | Pakete stehen fertig, aber ungeprüft | ein Gate-Fenster je Paket (FE-097); Empfehlung bis 25.11. |
| Staging-Konfiguration fehlt (Toleranz) | Klickpfad Rechnung auf Staging nicht bedienbar | einzeiliger PR nach `lca`-Wert |
| Kein KI-Modell angeschlossen | Kernversprechen «KI-first» noch nicht sichtbar | AI1 direkt nach STAB1 |
| Reale Daten | Clinical Owner, Rechtsform, Gutachten offen | Phase-B-Tor B12; D-35 Regel A bleibt |

## 7. Founder Actions

1. Keine Handlung sofort nötig.
2. Nach dem AI1-Bereitbericht: Render-Werte setzen (Klickpfad in `docs/agents/briefs/AI1.md`).
3. Optional: Kandidatin für die Clinical Owner benennen (G-1).

## Pflege dieses Berichts

- Der PO schreibt diesen Bericht jeden Freitag neu, aus Blueprint V3.2 §8, §10, §11. Die Vorwoche bleibt in der Git-Historie.
- Ein beantworteter Entscheid verschwindet aus §3 und erscheint in §1 der nächsten Ausgabe.
- Unbekannte Werte stehen als UNKNOWN da und werden nie stillschweigend geschätzt. Die Kennzahlen aus Blueprint §10 (M-13 Nordstern usw.) sind in Phase A noch nicht gemessen (UNKNOWN); erste Zählung «Taps vom Unterschreiben bis gesendet» kommt mit BK-f.
- Keine Personen- oder Gesundheitsdaten in diesem Dokument.
