# NAVORA Founder Executive Report

**Für:** den Owner (Founder) · **Verfasst von:** Product Owner (`po`) · **Ausgabe:** KW 48, Stand Freitag, 27. November 2026, 03:39 (Europe/Zurich), geplanter PO-Lauf 03:39 · **Vorausgabe:** KW 47 (20.11.2026, in der Git-Historie) · **Nächste Ausgabe:** Freitag, 4. Dezember 2026 · **Rhythmus:** jeden Freitag neu, im ersten Signal-Lauf des Freitags (FE-105)

**Dieses Dokument ist das primäre Entscheidungsdokument des Owners.** Quellen: [Blueprint V3.2](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md) §8 (Blockkette), §10 (Meilensteine und Kennzahlen), §11 (Entscheidungsboard), Stand 3.2.96; [`ABNAHMEAKTE.md`](ABNAHMEAKTE.md) §2; [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) v88 (bis FE-136). Der PO hat keine Tests selbst ausgeführt; alle Nachweise sind aus CI-Job-Protokollen gelesen. Jede Aussage ist gekennzeichnet: IMPLEMENTED, PLANNED, OPEN, UNKNOWN.

## Auf einen Blick (1 Minute)

- **Die Woche der Heim-Dienstplanung.** Der Block HEIM-DP (Dienstplanung im Heim, `/heim`) hat diese Woche fünf Pakete für die Simulation abgenommen: **HD-1** Planen im Heim (21.11.), **HD-2** Lücke → externer Auftrag → Status zurück (21.11.), **PERF1** sichtbare Hinweise statt kaputter Seiten (22.11.), **HD-3a** «Plan vorschlagen» nach festen Pflichtregeln mit der schnellen Auftragsliste **ORDER-F1** (26.11.) und heute Nacht **HD-3s** geteilter Dienst (27.11.). Gate jeweils: «Simulation, synthetische Daten», keine Freigabe für reale Personen.
- **Was eine Heimleitung heute auf Staging bedienen kann (IMPLEMENTED, getestet):** Planungswerte eingeben → Monatsplan vorschlagen lassen → übernehmen (die Datenbank prüft jede Zeile erneut) → verbleibende Lücke als externen Auftrag senden → ein Team übernimmt → Status kommt zurück. Neu seit heute: auch Dienste mit zwei Blöcken (z. B. 07:00–11:30 und 16:00–20:00) als ein Arbeitstag. Staging-Klickpfade 1–8 grün; Datenbank `navora-staging` auf Migration 20261021000182.
- **Aktiv jetzt: HD-3s-F2** «Externer Auftrag mit zwei Blöcken» (#1808, im Bau). Bis dahin ist die bekannte Grenze sichtbar: «Geteilter Dienst: noch kein externer Auftrag möglich» (fail closed).
- **Ihre Richtungsentscheide dieser Woche:** Ziel ca. 80 % der heutigen Planungsarbeit durch NAVORA (FE-125); «Das Rechenwerk plant, die Heimleitung entscheidet, die KI hilft» (FE-126); neuer Löser erst nach Benchmark (FE-134); **ein verbundenes Planungs- und Betriebssystem** mit Integrationspflicht für jeden Planungsvertrag (FE-136); Gebührenbasis nach Vollzeit-Äquivalent, nie Provision (FE-115, D-14).
- **KI-Ehrlichkeit:** In keiner Umgebung ist ein KI-Modell in einem getesteten Pfad aktiv. AI1 (Kostenbremse, Notschalter, feste Prompt-Version) ist seit 24.11. gemergt, der Berichtsentwurf auf Staging bleibt Testersatz «regelbasiert, keine KI»; Abnahme AI1 erst nach AI1-F1. Alle Planungsfunktionen sind **feste, prüfbare Regeln**.

## 1. Abgeschlossene Lieferungen

### 1.1 Für die Simulation abgenommen (KW 48)

| Paket | Was eine Person jetzt tun kann (Simulation) | Commit, Nachweis |
|---|---|---|
| HD-1 Planen im Heim | Heimleitung pflegt Stationen, Dienstarten, Personal und Wochenplan auf `/heim` | `9debf74`, `ci-repeat` 20/20 (21.11.) |
| HD-2 Lücke → Auftrag | Aus einer Planlücke wird ein vorausgefüllter externer Auftrag; der Status kommt in den Plan zurück | `0b8f537`, `ci-repeat` 20/20 (21.11.) |
| PERF1 | `/field` und `/team` bleiben bedienbar, wenn eine Hinweisliste nicht lädt, mit sichtbarem Hinweis | `4310526`, `ci-repeat` 20/20 (22.11.) |
| HD-3a + ORDER-F1 | «Plan vorschlagen» nach Ruhezeit, Tagen in Folge, Schichtmodell, Abwesenheit, Pensum; «übernehmen» mit erneuter Prüfung; `/order` lädt auch mit vielen Aufträgen | `217a9a58`, `ci-repeat` 22/22, `staging-smoke` 8 passed (26.11.) |
| AUT-220 (Testwächter) | Keine Produktänderung: die Tempotests der Auftragslisten prüfen auch unter erzwungenen Abfrageplänen | `d2e78ace` (26.11.) |
| **HD-3s** geteilter Dienst | Dienstart mit zwei Blöcken anlegen, planen, übernehmen; Pause zählt nicht als Arbeitszeit, Ruhezeit erst nach Block 2, ein Arbeitstag | `5e9a0474`, `ci-repeat` 22/22 im Fenster, `staging-smoke` 9 passed (27.11.) |

Sicherheits- und Stabilitätsfixes gemergt: UXR-269 («Senden» sendet genau, was angezeigt ist, 21.11.), S-1 (fehlende Sicherheitssignale sind rot sichtbar statt «kein Signal», 22.11.), SEC-DEP1 (Abhängigkeiten, nur Entwicklungswerkzeuge, 24.11.). IMPLEMENTED.

Nicht Teil der Abnahmen: Freigabe für reale Personen und Daten, klinische Freigabe (D-27), Arbeitsgesetz-Lesart, echter KI-Entwurf. Die Liste je Paket steht in `ABNAHMEAKTE.md` §2 (OPEN).

### 1.2 Ihre Entscheide diese Woche (FE-101 bis FE-136)

Wichtigste: FE-105 ereignisgesteuertes Prüfen; FE-109/FE-110 HEIM-DP jetzt bauen; FE-111 «Stabil zuerst»; FE-115 D-14 Gebührenbasis; FE-117/FE-119 automatische Dienstplanung, Absenzen ohne Gesundheitsgrund; FE-121 D-15 Option C (vorläufig); FE-122 Spitalaustritts-Flow (INTAKE-E2E); FE-125 bis FE-127 Planungsziel und Paketfolge; FE-130 D-16 Option B (vorläufig); FE-131 kleinstes sicheres Paket zuerst; FE-133 bis FE-136 geteilter Dienst, Monatssoll Option A, Löser-Benchmark, verbundenes System. Volltext: `FOUNDER_DECISIONS.md`.

## 2. Laufende Arbeit

| Paket | Stand | Kennzeichnung |
|---|---|---|
| **HD-3s-F2** externer Auftrag mit zwei Blöcken (#1808) | Auf dem Branch: Auftrag mit beiden Blöcken, Pause besetzt, zwei Einsätze je Übernahme, `/field` zeigt «Teil 1 von 2 · Geteilter Dienst …»; pgTAP 183 70/70 lokal; CI auf dem Kopf läuft; noch kein Bereitbericht; Gates `cra`, `uxa`, `lca` danach | PLANNED bis Merge |
| HD-3a-F1 | Pensum/Wochensoll zwischen Vorschlag und Übernahme ohne Wochenstunden-Prüfung (bekannte Grenze FE-129); Pflicht vor realen Daten | PLANNED |
| HD-3a-F3 Monatssoll | Option A gewählt (FE-135); Vertrag `draft`, offene Schwellen (siehe §3) | PLANNED |
| HD-3b-0 Löser-Benchmark | erst nach HD-3a-F3; Greedy bleibt bis dahin (FE-134) | PLANNED |
| AI1-F1 | Bewertungsset und Messung, dann AI1-Abnahme | PLANNED |

## 3. Owner Decision Board (offen)

| # | Frage | Dringlichkeit |
|---|---|---|
| G-1 / D-43 | Ernennung einer Clinical Owner (D-15, D-16 sind nur vorläufig entschieden) | hoch vor Phase B |
| D-44 | Rechtsform und Vertragsweg der Teams (Genossenschaft als Ziel); wer stellt die Rechnung | hoch vor realer Rechnung |
| D-14 | Höhe der Monatsgebühr je VZE und Umsetzung S4 (Basis entschieden, FE-115) | mittel |
| HD-3s-F1 | Startwerte für 50 h/Woche (R-i) und 14-h-Tagesspanne (R-j): bleiben «leer, nicht geprüft», bis `lca` liest und Sie wählen | mittel, vor realen Daten |
| HD-3a-F3 | Schwelle «wesentlich abweichend», Bezug zum Wochensoll, Planungsperiode, Verhalten ohne Monatssoll | mittel, vor dem Bau von F3 |
| STG-OBS-1 | Render-API-Schlüssel als GitHub-Secret, damit der Staging-Test das Render-Protokoll lesen kann | niedrig |
| D-41 / D-2 | KI-Pfad und Hosting-Vertrag für reale Daten | vor Phase B |
| B0-6, GM-2, PLZ-Quelle | Repository-Schutz; Preis und Reihenfolge B2B-Module; swisstopo-Bestätigung | mittel |

## 4. Kritischer Pfad

HD-3s-F2 (aktiv) → HD-3a-F1 → HD-3a-F3 → HD-3b-0 → HD-3b → INTAKE-E2E → HD-3c (erste KI-Hilfe in der Planung) → HD-3d (Ausfall-Umplanung) → … → **M9 Phase A am 2027-03-12** (in Arbeit; 15 Wochen). Engpass dieser Woche: **instabiler Staging-Test** (siehe §6) und die Wartezeit von der Prüfbereit-Meldung bis zur letzten Gate-Zeile.

## 5. Kennzahlen (Blueprint §10)

| Kennzahl | Wert KW 48 | Kennzeichnung |
|---|---|---|
| M-13 Nordstern (direkte Pflegezeit), M-15/M-16, M-11/M-17, M-19, M-18 | in Phase A noch nicht gemessen; keine echten Teams | UNKNOWN |
| M-14 CI-Gesundheit `recovery/main` | `ci` auf Push seit 21.11.: 151 grün, 4 rot, 4 abgebrochen | IMPLEMENTED (aus der Actions-Liste gezählt) |
| Staging-Test `staging-smoke` | seit 21.11.: 81 grün, **52 rot**, 28 abgebrochen; Ursache meist Render-Wechsel während des Laufs (wahrscheinlich, nicht bewiesen), Folgepunkt STG-SMOKE-3 | IMPLEMENTED (Zählung); Ursache UNKNOWN |
| M-03 Durchlaufzeit (Beispiel HD-3s) | Prüfbereit 26.11. 14:41 → Merge 22:39 (≈ 8 h, Warten auf Gate-Zeilen) → Abnahme 27.11. 03:39 (≈ 5 h, Abnahmefenster ab 02:20) | IMPLEMENTED |
| Merges auf `recovery/main` seit 21.11. | 161 Merge-Commits, davon über 20 Engineering-PRs mit Code oder Tests (aus den Merge-Titeln gezählt), der Rest Rollen-Dokumente und PO-Läufe | IMPLEMENTED |
| neu (BK) Minuten bis «gedeckt», Handlungen je Auftrag | nicht gemessen | UNKNOWN |

## 6. Risiken

| Risiko | Wirkung | Gegenmassnahme |
|---|---|---|
| Staging-Test rot bei Deploy-Wechsel | Echte Fehler können in Rauschen untergehen; Abnahmen verzögern sich | STG-SMOKE-3 (einmal wiederholen nur wenn der Commit wechselte, sonst rot bleiben); STG-OBS-1 |
| Langsame Datenbankabfragen mit wachsender Datenmenge | Seiten überschreiten das Zeitlimit (in dieser Woche viermal gefunden und behoben) | AUT-220-Testwächter, Budget-Tests je Liste |
| Arbeitszeitwerte ohne Rechtslesart | Plan wirkt «konform», ist es aber nicht geprüft | Marke «Arbeitszeitgesetz nicht abschliessend geprüft»; `lca` vor realen Daten |
| Kein KI-Modell im getesteten Pfad | Kernversprechen «KI-first» noch nicht sichtbar | AI1-F1; HD-3c nach dem Löser |
| Reale Daten | Clinical Owner, Rechtsform, Gutachten offen | Phase-B-Tor B12; D-35 Regel A bleibt |

## 7. Die nächsten 7 Tage (28. November – 4. Dezember 2026)

1. HD-3s-F2 prüfbereit, Gate-Fenster, Merge, Staging-Pfad 9, Abnahme mit `ci-repeat` im Fenster.
2. HD-3a-F1 bauen und abnehmen (Pflicht vor realen Daten).
3. HD-3a-F3-Vertrag mit Ihren Antworten auf die offenen Schwellen freigeben.

## 8. Founder Actions

1. Keine Handlung sofort nötig.
2. Optional: Auswahlfragen zu HD-3a-F3 beantworten, sobald sie auf #1790/#1712 gestellt sind.
3. Optional: Entscheid STG-OBS-1 (Render-API-Schlüssel als Secret).
4. Optional: Kandidatin für die Clinical Owner benennen (G-1).

## Pflege dieses Berichts

- Der PO schreibt diesen Bericht jeden Freitag neu, aus Blueprint V3.2 §8, §10, §11. Die Vorwoche bleibt in der Git-Historie.
- Ein beantworteter Entscheid verschwindet aus §3 und erscheint in §1 der nächsten Ausgabe.
- Unbekannte Werte stehen als UNKNOWN da und werden nie stillschweigend geschätzt. Engineering-Zahlen in §5 sind aus der GitHub-Actions-Liste gezählt, nicht aus jedem Protokoll gelesen.
- Keine Personen- oder Gesundheitsdaten in diesem Dokument.
