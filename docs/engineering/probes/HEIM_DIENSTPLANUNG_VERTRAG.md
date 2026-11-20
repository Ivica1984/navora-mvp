# Paketvertrag «Pflegeheim-Dienstplanung» (HEIM-DP): Entwurf `eng`, Version 2

**Stand:** 2026-11-20 ca. 15:55, `eng`. Version 2 setzt den **Founder-Entscheid zur Heim-Baufolge** um («zuerst funktionierende Register, Dashboard danach», ca. 15:52). Sie ersetzt Version 1 (15:50) und `HEIM_NAECHSTES_PAKET.md`.
**Status:** Vertragsentwurf, nichts gebaut. Den verbindlichen Umfang und die Abnahmekriterien legt der **PO** im Brief `docs/agents/briefs/HEIMDP.md` fest; `eng` verantwortet das WIE.
**Kennzeichnung:**
- **gebaut** (auf `recovery/main`);
- **feste Regel** (deterministisch);
- **Testersatz** (feste Beispielantwort, nur CI, nie «KI» genannt);
- **KI-Modell** (angeschlossenes Modell, nur Staging, synthetische Daten).

ESTIMATE ist eine Schätzung, OPEN ein fehlender Entscheid.

## 0. Die Reihenfolge, in den Worten von `eng`

1. Erst nimmt der PO **BK-f** formell auf dem benannten Commit ab. Der Wiederholungslauf `ci-repeat` 44746720886 ist grün (22/22); offen ist nur noch die Eintragung durch den PO.
2. Danach wird **genau ein Register** gebaut, **«Dienstplanung»**: Stationen, Personal mit Namen und Stufe, Wochenplan mit allen Diensten, Abwesenheiten, interne Vertretung und sichtbare Lücken. Nach dem Login landet die Heimleitung direkt dort.
   - Fertig gemeldet wird es erst, wenn der vereinbarte Wochenablauf (§2) auf Staging funktioniert und getestet ist.
3. **Dann das Register «Externe Aufträge»** mit der Verbindung: Aus der Lücke wird ein prüfbarer Auftrag, und die Entscheidung des Teams sowie der echte Deckungsstatus kommen zurück in den Plan.
4. **Dann** Kosten & Rechnungen, Mitteilungen & Ausnahmen und gebuchte B2B-Funktionen, jedes Register vollständig.
5. **Zuletzt** das Heim-Dashboard. Es führt die Zustände der fertigen Register zusammen und verlinkt dorthin. Es gibt keine leere Fassade davor.
6. **Schon jetzt** modellieren wir alle späteren Zustände getrennt (§4), damit Register und Dashboard später dieselbe Wahrheit lesen.

## 1. Das Register «Dienstplanung» im fertigen Zustand

```
 NAVORA · Testheim Rhein (synthetisch)    Dienstplanung    [Station: Rhein 2 ▾]   Woche 48 ◂ ▸   [Notiz an NAVORA]
 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Woche: 21 Dienste · 18 besetzt · 2 offen · 1 in Klärung
          Mo 23.      Di 24.      Mi 25.                    Do 26.   Fr 27.   Sa 28.        So 29.
 Früh     Anna HF     Anna HF     Anna HF                   …        …        ▶ 1 offen     …
 07–15    Ben FaGe    Ben FaGe    Ben FaGe
          Carla FaGe  Carla FaGe  ✖ Carla abwesend
                                  ▶ Lücke: 1 FaGe/AGS fehlt
                                    kann intern besetzen: David Probe (AGS) · Arbeitszeit nicht geprüft
                                    [David einteilen]  [In Klärung übernehmen]
 Spät 15–23 · Nacht 23–07 · Wochenende analog
 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Personal Rhein 2: Anna Muster (HF) · Ben Beispiel (FaGe) · Carla Test (FaGe) · David Probe (AGS) — «vom Heim bestätigt»
```

## 2. Abnahme-Ablauf, den Ivica auf Staging bedient

**Rolle:** Heimleitung «Testheim Rhein», synthetisch.

1. Anmelden. Die Seite **Dienstplanung** öffnet sich direkt.
2. Station «Rhein 2» wählen. Das Personal erscheint mit Namen und «vom Heim bestätigt: HF / FaGe / AGS».
3. Woche 48 öffnen. Früh-, Spät-, Nacht- und Wochenenddienste sind aus den Dienstvorlagen erzeugt.
4. Ben am Samstag in den Frühdienst einteilen. Eine unpassende Einteilung wird mit Grund abgelehnt:
   - doppelt eingeteilt;
   - abwesend;
   - Stufe erfüllt die Anforderung des Heims nicht.
5. Carla für Mittwoch und Donnerstag abwesend melden, auf einem von zwei Wegen:
   - **a) Formular**;
   - **b) Notiz in eigenen Worten:** «Carla hat angerufen, sie fällt Mi und Do aus». NAVORA zeigt den Vorschlag «Abwesenheit Carla Test, 25.–26.11.», markiert **«KI-Vorschlag aus Ihrer Notiz»**, mit der Textstelle als Quelle. Die Heimleitung **bestätigt**.
6. Mi früh zeigt **«Lücke: 1 FaGe/AGS fehlt»** und «kann intern besetzen: David Probe (AGS)», mit dem Hinweis «Arbeitszeit nicht geprüft».
7. David einteilen. Die Lücke schliesst sich.
8. Do früh ebenfalls als Lücke: «In Klärung übernehmen». Die Zelle zeigt «in Klärung · <Name der Heimnutzerin>».
9. Kopfzeile und Zellen stimmen: offen, besetzt, in Klärung.

Der Übergang «Extern anfragen» gehört zum **nächsten** Register und ist in diesem Register noch nicht sichtbar. Es gibt keinen toten Knopf.

## 3. Feste Regel, echte KI, Mensch

| Schritt | Feste Regel | Echtes KI-Modell | Mensch | Heimleitung sieht |
|---|---|---|---|---|
| Woche erzeugen | aus Dienstvorlagen je Station | – | Heim legt Vorlagen und Anforderung fest | Raster |
| Einteilen | Person in Station, nicht abwesend, nicht doppelt, Stufe erfüllt die **vom Heim festgelegte** Anforderung | – | **Heim teilt ein** | Name in der Zelle oder Ablehnung mit Grund |
| Abwesenheit | von–bis, ohne Grund; Lücke wird berechnet | **Notiz → Vorschlag** (Person, Tage, betroffene Dienste) mit Quelle | **Heim bestätigt jeden Vorschlag** | «KI-Vorschlag aus Ihrer Notiz» → nach Bestätigung «abwesend» |
| Weitere Notizen | Vorschlag wird gegen dieselben Regeln geprüft | **Notiz → Tausch- oder Zusatzbedarf-Vorschlag** («Ben und Carla tauschen Fr») | **Heim bestätigt** | Vorschlag markiert, Ablehnung mit Regelgrund möglich |
| Lücke | Vorlage − Einteilung − Abwesenheit; Frühwarnung 14 Tage | – | – | «Lücke: …» |
| Interne Vertretung | Liste aus eigenem Personal: Stufe passt, frei, nicht eingeteilt; **Arbeitszeit nicht geprüft** (OPEN `lca`) | – | **Heim wählt** | «kann intern besetzen: …» |
| Konflikte | Code und fester Text | – (feste Texte sind prüfbar) | – | «Ben ist Mi schon im Spätdienst» |

**Die echte KI in diesem Register** ist die Notiz-Funktion. Sie nimmt der Heimleitung das Übersetzen eines Anrufs oder einer Nachricht in Formularfelder ab:
- Person, Tage und Dienste finden;
- Abwesenheit, Tausch oder Zusatzbedarf erkennen.

Das Modell **schlägt nur vor**. Die feste Prüfung und die Bestätigung der Heimleitung entscheiden. Fällt das Modell aus oder ist der Not-Aus aktiv, bleibt das Formular vollständig nutzbar.

**Nicht KI und nicht so benannt:**
- Lückenberechnung, Vertretungsliste und Konflikttexte sind feste Regeln.
- Ein späterer automatischer Gesamt-Planvorschlag ist deterministisch und heisst «automatischer Vorschlag».
- In der CI läuft ein Testersatz.

**KI-Klickpfad für Ivica:**
1. Dienstplanung → «Notiz an NAVORA».
2. «Carla hat angerufen, sie fällt Mi und Do aus» eingeben.
3. Es erscheint ein Vorschlag mit Quelle und der Markierung «KI-Vorschlag».
4. Bestätigen; die Lücke erscheint.

**Voraussetzungen:**
- Die `lca`-Lesung der Anbieterbedingungen (FE-094 (c)) ist vor der ersten Einschaltung abgeschlossen.
- Der Founder setzt danach in Render den Schalter für diese Funktion. Der Schlüssel ist derselbe wie für AI1, niemals im Chat.

## 4. Zustandsmodell, schon jetzt vollständig

**Ein Zustand je Dienstplatz, aus einer Datenbankfunktion gelesen.** Register und späteres Dashboard lesen dieselbe Funktion; kein Zustand wird im Frontend berechnet.

| Zustand | Bedeutung | Erreichbar ab |
|---|---|---|
| `besetzt_intern` | eigene Person eingeteilt | Dienstplanung |
| `offen` | Lücke, mit Grund (abwesend, nie eingeteilt) | Dienstplanung |
| `in_klaerung` | Heimnutzerin X kümmert sich | Dienstplanung |
| `angebot_versandt` | externer Auftrag gesendet, keine Übernahme | Externe Aufträge |
| `team_uebernommen` | ein Team hat übernommen, Person bestätigt noch | Externe Aufträge |
| `besetzung_bestaetigt` | Person benannt, bestätigt und für die Stufe geprüft | Externe Aufträge |
| `gefaehrdet` | Besetzung weggefallen oder Person fällt aus (mit Grund) | Externe Aufträge |
| `erbracht` | Einsatz durchgeführt, Bericht unterschrieben | Externe Aufträge |
| `abgerechnet` | Rechnung des Teams erhalten | Kosten & Rechnungen |

**Die Zustände sind getrennt und werden nie vermischt:**
- `angebot_versandt` ist nicht `team_uebernommen`;
- `team_uebernommen` ist nicht `besetzung_bestaetigt`;
- `erbracht` ist nicht `abgerechnet`.

## 5. Technik, Rollen und PR-Schnitt

**Daten:**
- neue B2B-Tabellen je Heim: Stationen, Personal, vom Heim bestätigte Qualifikationen, Dienstvorlagen mit Anforderung, Einteilungen, Abwesenheiten ohne Grund, Lücken-Bearbeitung, KI-Vorschlagsprotokoll;
- jede Funktion als lesbare Datei (FE-100), mit RLS, Audit und pgTAP;
- **kein STAB1 nötig**, denn keine bestehende Funktion wird geändert. STAB1 gezielt erst im Register «Externe Aufträge».

**Rollen:**
- **Heimleitung:** alle Stationen;
- **Planerin:** zugewiesene Stationen;
- Mitarbeitende, Teams, Pflegekräfte, andere Heime und Privatkunden sehen nichts davon.

**Login:** Eine Heimnutzerin mit B2B-Recht landet auf `/dienstplanung`; die heutige Seite `/order` bleibt erreichbar.

**KI:**
- Der gebaute Anschluss (`src/lib/ai/report-draft/`, mit Testersatz) wird zu einem gemeinsamen Anschluss verallgemeinert.
- Neu: Kostengrenze in der Datenbank (300 Aufrufe pro Tag, CHF 50 pro Monat, FE-099 (7)), Eingabe- und Antwortgrenze, Not-Aus.
- AI1 nutzt denselben Anschluss danach.

**Fremdkomponenten:** keine.

**PR-Schnitt.** Jeder Schritt ist auf Staging sichtbar, aber erst der letzte ist «Register fertig».

| PR | Inhalt | Danach auf Staging bedienbar (Zwischenstand, nicht «fertig») | ESTIMATE |
|---|---|---|---|
| **1** | Stationen, Personal, Qualifikation, Rollen und Rechte, Seed (2 Stationen, 8 Personen), Login → `/dienstplanung`, Personalansicht | anmelden, in der Dienstplanung landen, Station wählen, Personal mit Namen und Stufe sehen | 2–3 |
| 2 | Dienstvorlagen, Wochenansicht (Früh, Spät, Nacht, Wochenende), Einteilen mit Konfliktcodes, 390 px und Desktop | Woche sehen und planen | 3–4 |
| 3 | Abwesenheit (Formular), Lücke, Frühwarnung, interne Vertretung, «in Klärung», Zustandsfunktion §4 | Abwesenheit, Lücke, Vertretung | 3–4 |
| 4 | KI-Notiz → Vorschlag (echtes Modell), Anschluss mit Kostengrenze, Evaluationssatz, Not-Aus | Notiz → KI-Vorschlag → bestätigen | 3–5 |
| 5 | `staging-smoke`-Pfad des ganzen Ablaufs §2 (Formular- und Notizweg, mit und ohne Not-Aus), Abschluss | **Register «Dienstplanung» fertig** (nach Abnahme) | 1–2 |

**Gesamt ESTIMATE: 12–18 Engineering-Läufe plus Gate-Fenster.**

**Bewusst nicht in diesem Register:**
- «Extern anfragen» kommt im nächsten Register.
- Automatischer Gesamt-Planvorschlag und Monatsansicht.
- Selbstansicht der Mitarbeitenden.
- Arbeitszeitprüfung (OPEN `lca`).

Der PO bestätigt diese Liste.

## 6. Tests, Gates, Abnahme

- **Positiv:** Ablauf §2 als e2e bei 390 und 1440 px.
- **Negativ:**
  - Ablehnungen nach Konfliktcode;
  - ein KI-Vorschlag wirkt nie ohne Bestätigung;
  - ein Vorschlag, der eine Regel verletzt, wird mit Grund abgelehnt;
  - Not-Aus: das Formular bleibt nutzbar.
- **Rechte (pgTAP):**
  - niemand ausser den Heimrollen sieht Personal;
  - eine Planerin sieht nur ihre Stationen;
  - Audit für jede Änderung;
  - jeder Zustand aus §4 ist eindeutig.
- **KI:**
  - Evaluationssatz von etwa 30 synthetischen Notizen;
  - gemessen werden richtige Felder, Felder ohne Quelle (Ziel 0), Korrekturen bis zur Bestätigung, Kosten und Dauer je Aufruf;
  - in der CI nur ein Testersatz.
- **Staging:** `staging-smoke` Pfad «Dienstplanung» grün auf dem integrierten Commit; alle früheren Pfade grün.
- **Gates:**
  - `lca`: Personaldaten, Abwesenheit ohne Grund, Anbieterbedingungen;
  - `cra`: Stufenanforderung des Heims, Wortlaut der Zustände;
  - `uxa`;
  - `aia`: KI-Kontrollen.
- **Abnahme:**
  - Ivica bedient §2 auf Staging als Heimleitung;
  - `staging-smoke` grün;
  - `ci-repeat` 10/10;
  - Gate «Simulation, synthetische Daten».

## 7. KI-Meilensteine, getrennt

- **Erste echte KI im Pflegeheim:** die Notiz-Funktion in PR 4 der Dienstplanung. ESTIMATE 11–16 Läufe ab dem Start von HEIM-DP, plus Gates und die Render-Einstellung durch den Founder.
- **Erste echte KI in NAVORA insgesamt:** dieselbe, weil HEIM-DP nach dem Founder-Entscheid vor AI1 kommt.
- **AI1, Berichtsentwurf der Pflegekraft:** folgt danach auf demselben Anschluss, ESTIMATE 2–3 Läufe. Er gilt nie als Beleg für Heim-KI.
- **Nachweis der Entlastung:** Eingaben und Klicks vom Anruf bis zur eingetragenen Abwesenheit und Lücke, mit Notiz gegenüber dem Formular, synthetisch gemessen. Dazu der Anteil der KI-Vorschläge, die ohne Korrektur bestätigt werden.

## 8. Erster Bauschritt nach der Abnahme von BK-f

**PR 1:** Stationen, Personal mit Namen und vom Heim bestätigter Stufe, Rollen und Rechte, synthetische Seed-Daten, Login direkt in die Dienstplanung.

**Danach auf Staging als Heimleitung bedienbar** (Zwischenstand, nicht «Register fertig»): anmelden, direkt in «Dienstplanung» landen, eine der zwei Stationen wählen und deren Personal mit Namen und Stufe sehen.

**Belegt durch:**
- pgTAP: Team, Pflegekraft und anderes Heim sehen kein Personal; eine Planerin sieht nur ihre Station;
- e2e bei 390 und 1440 px;
- `staging-smoke` Pfad «Dienstplanung: Personal».

## 9. Entscheide

**Beim PO:**
- BK-f abnehmen;
- Brief `HEIMDP.md` mit Umfang §2, Abnahme §6 und der Liste «nicht in diesem Register» schreiben;
- *Active now* setzen;
- die Rollen Heimleitung und Planerin benennen.

**Beim Founder:** keiner offen. Einzige Handlung später: nach dem Abschluss von PR 4 den Render-Schalter für die Notiz-Funktion setzen.
