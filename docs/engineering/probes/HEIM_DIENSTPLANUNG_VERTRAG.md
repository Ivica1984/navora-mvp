# Paketvertrag «Pflegeheim-Dienstplanung» (HEIM-DP): Entwurf `eng`, Produktentscheid beim PO

**Stand:** 2026-11-20 ca. 15:50, `eng`. Anlass ist der Founder-Brief «Korrektur zu HEIM – kein isoliertes H1-Dashboard; baut das vollständige Pflegeheim-Register Dienstplanung». Er **ersetzt** die Empfehlung «H1 zuerst» aus `HEIM_NAECHSTES_PAKET.md`.
**Status:** Vertragsentwurf. Nichts davon ist gebaut.
- Der **PO** trifft den Produktentscheid (Umfang, Abnahme, Reihenfolge) und übernimmt den Text als Brief `docs/agents/briefs/HEIMDP.md`. Erst dann ist es die gemeinsame Antwort.
- `eng` verantwortet das WIE.

**Kennzeichnung:**
- **gebaut** (auf `recovery/main`);
- **feste Regel** (deterministische Berechnung);
- **Testersatz** (feste Beispielantwort, nur CI);
- **KI-Modell** (angeschlossenes Modell, nur Staging, synthetische Daten).

ESTIMATE ist eine Schätzung, OPEN ein fehlender Entscheid.

---

## 1. So sieht das fertige Register «Dienstplanung» aus

```
 NAVORA · Testheim Rhein (synthetisch)        Dienstplanung     [Station: Rhein 2 ▾]   Woche 48 ◂ ▸
 ─────────────────────────────────────────────────────────────────────────────────────────────────
 Diese Woche: 21 Dienste · 18 besetzt · 2 offen · 1 gefährdet                  [+ Notiz an NAVORA]
 ─────────────────────────────────────────────────────────────────────────────────────────────────
           Mo 23.     Di 24.     Mi 25.               Do 26.     Fr 27.     Sa 28.      So 29.
 Früh      Anna HF    Anna HF    Anna HF              …          …          ⚠ 1 offen   …
 07–15     Ben FaGe   Ben FaGe   Ben FaGe                                    (FaGe)
           Carla FaGe Carla FaGe ✖ Carla abwesend
                                 ▶ Lücke: 1 FaGe/AGS
                                   intern: David (AGS) frei
                                   [Intern besetzen] [Extern anfragen]
 Spät      …          …          ◷ extern angefragt   ✔ besetzt extern · Testteam Basel
 15–23                           (Angebot an 3 Teams)
 Nacht     …          …          …
 23–07
 ─────────────────────────────────────────────────────────────────────────────────────────────────
 Personal Rhein 2: Anna Muster (HF, vom Heim bestätigt) · Ben Beispiel (FaGe) · Carla Test (FaGe) · David Probe (AGS)
```

**Zustände je Dienst:**
- besetzt (eigenes Personal);
- offen (Lücke, mit Grund);
- intern in Klärung (mit Name der zuständigen Heimnutzerin);
- extern angefragt;
- extern übernommen, Person bestätigt noch;
- besetzt extern (Team);
- gefährdet (belegter Grund, z. B. Besetzung weggefallen).

«Soll 3 · besetzt 2» steht nur als Zusammenfassung in der Kopfzeile und in jeder Zelle.

## 2. Diesen Ablauf kann Ivica nach der Abnahme auf Staging durchklicken

**Rolle:** Heimleitung «Testheim Rhein», synthetisch.

1. Station «Rhein 2» wählen.
2. Personal mit Namen und bestätigter Stufe sehen.
3. Woche 48 öffnen. Früh, Spät, Nacht und Wochenende sind aus den Dienstvorlagen erzeugt.
4. Ben am Samstag einem Dienst zuteilen. Eine unpassende Zuteilung, etwa AGS in einen Dienst, der HF verlangt, wird mit Grund abgelehnt.
5. Carla für Mittwoch abwesend melden. Das geht als Formular oder als **Notiz in eigenen Worten**: «Carla fällt Mi und Do aus».
   - Bei einer Notiz schlägt die KI die Abwesenheit vor; die Heimleitung bestätigt.
6. Die Lücke Mi früh erscheint. «Kann intern besetzen: David (AGS)» wird angezeigt, mit dem Hinweis «Arbeitszeit nicht geprüft».
7. «Extern anfragen». Ein Auftragsentwurf ist vorausgefüllt: Datum, Zeit, Station, Einsatzort, Stufe, Tätigkeiten aus der Vorlage.
   - Eine Ergänzung in eigenen Worten wird von der KI in markierte Felder überführt.
   - Die Heimleitung prüft und sendet.
8. Mi früh zeigt «extern angefragt (Angebot an N Teams)».
9. *(Zweites Fenster, Pflegekraft des Testteams Basel)* Das Team übernimmt.
10. Zurück in der Dienstplanung: «extern übernommen, Person bestätigt noch», dann «besetzt extern · Testteam Basel».
11. *(Pflegekraft meldet sich ab.)* Die Zelle wird «gefährdet · Angebot läuft wieder».

## 3. Wer macht was: feste Regel, echte KI, Mensch

| Arbeitsschritt | Feste Regel | Echtes KI-Modell | Mensch bestätigt | Heimleitung sieht | Heute |
|---|---|---|---|---|---|
| Woche aufbauen | Woche aus Dienstvorlagen erzeugen; Zuteilung prüfen: Person in der Station, nicht abwesend, Stufe erfüllt die **vom Heim festgelegte** Anforderung | – (erster Stand) | Heim teilt zu | Raster mit Namen | fehlt |
| Konflikt erklären | Konfliktcode: doppelt eingeteilt, abwesend, Stufe fehlt; fester Text je Code | – (feste Texte reichen und sind prüfbar) | – | «Ben ist Mi schon im Spätdienst» | fehlt |
| Abwesenheit erfassen | Abwesenheit von–bis, ohne Grund; Lücke wird berechnet | **Notiz in eigenen Worten → Vorschlag** (Person, Tage, Dienste), mit Textstelle als Quelle | **Heim bestätigt jeden Vorschlag** | Vorschlag markiert «KI-Vorschlag aus Ihrer Notiz» | fehlt |
| Lücke erkennen | Vorlage − Zuteilung − Abwesenheit; Frühwarnung für die nächsten 14 Tage | – | – | «1 FaGe/AGS fehlt» | fehlt |
| Umplanungsoptionen | Rangliste aus eigenem Personal: Stufe passt, frei, nicht eingeteilt; ohne Arbeitszeitprüfung (OPEN) | – (erster Stand); später Erklärung von Zielkonflikten | Heim wählt | «kann intern besetzen: David» | fehlt |
| Externer Auftrag | Entwurf aus der Lücke übernehmen; Auftragsprüfung (Region, Stufe zu Tätigkeit, Zeit) | **Ergänzung in eigenen Worten → markierte Auftragsfelder** | **Heim bestätigt und sendet** | Felder mit Herkunft: Vorlage / KI / geprüft | Prüfung **gebaut**, Entwurf fehlt |
| Teamentscheid | Angebot nur an geeignete Teams (Person je Team erfüllt Stufe, Nachweis, freie Zeit) | – | **Team entscheidet** | «extern angefragt» | **gebaut** (Staging) |
| Status zurück | Zustand des eigenen Auftrags in die Zelle | – | – | «besetzt extern · Team» | Status **gebaut**, Rückweg fehlt |
| Ausfall extern | Signal «Person fällt aus» → Zelle «gefährdet» | – | Team besetzt neu; Heim entscheidet intern | «gefährdet · Angebot läuft wieder» | Signal ans Team **gebaut**, Heimseite fehlt |

**Empfehlung `eng` zur Rolle der KI im ersten nutzbaren Stand:**

Ein Sprachmodell ist stark bei **Sprache**, schwach bei **Optimierung und Garantien**. Darum:
1. **Dazu gehört:** Notiz in eigenen Worten → Vorschlag einer Planänderung (Abwesenheit, Zusatzbedarf, Tausch). Ebenso Freitext → Auftragsfelder. Hier entsteht der Alltag einer Heimleitung: «Carla hat angerufen, sie fällt bis Donnerstag aus». Das Modell spart das Suchen nach dem richtigen Formular und das Abtippen. Jede Angabe wird bestätigt, die feste Prüfung läuft danach.
2. **Nicht im ersten Stand, bewusst später:**
   - **Ganzen Dienstplan automatisch erstellen.** Das ist ein Optimierungsproblem mit harten Grenzen. Ein Sprachmodell würde dabei raten. Richtig ist ein deterministischer **Planvorschlag** (Regelsuche über Vorlage, Personal und Abwesenheit), ehrlich als «automatischer Vorschlag», **nicht KI** bezeichnet. Ein Modell kann später die Begründung in Sprache fassen.
   - **Arbeitszeitregeln** (ArG, Ruhezeiten): OPEN `lca`, nicht erfunden.
3. **Konflikte erklären** braucht keine KI: Feste Texte je Konfliktcode sind verständlich und prüfbar. Eine KI-Formulierung würde hier nur Fehlerfläche hinzufügen.

Die harten Grenzen von Stufe, Berechtigung und Sicherheit sind immer feste Regeln in der Datenbank. Kein Modellvorschlag wird wirksam, bevor ein Mensch ihn bestätigt und die Regel ihn angenommen hat.

## 4. Technischer Aufbau und Rollen

**Getrennte Daten** (B2B, Mandant = Heim):
- Stationen, Personal, vom Heim bestätigte Qualifikationen, Dienstvorlagen mit Anforderung, Zuteilungen, Abwesenheiten (ohne Grund);
- Lücken-Bearbeitung mit Zustand und Zuständigkeit;
- KI-Vorschlagsprotokoll (vorgeschlagen / bestätigt / verworfen).

Alles ist neu, als lesbare Funktionsdateien (FE-100), mit RLS, Audit und pgTAP.

**Rollen:**
- **Heimleitung:** alle Stationen.
- **Planerin:** zugewiesene Stationen.
- Mitarbeitende und externe Teams sehen **nichts** davon.
- Eine Selbstansicht der Mitarbeitenden kommt später.

**Brücke zur Teamplattform:**
1. Der Befehl «Extern anfragen» erzeugt einen Auftragsentwurf mit Station und Lückenbezug, ohne Personalnamen und ohne Abwesenheitsgrund.
2. Gesendet wird über den gebauten Weg «Prüfen → Bestätigen & Absenden».
3. Eine Lesefunktion liefert den Zustand zurück in die Zelle.

**STAB1 gezielt:** nur für die Auftragsfunktionen, die Station und Lückenbezug bekommen. Die Liste steht im PR-D-Vertrag. Es ist kein eigenes Vorpaket.

**KI-Anschluss:**
- Er ist **gebaut mit Testersatz** (`src/lib/ai/report-draft/`: Anthropic-Anbieter, Not-Aus, Staging- und Simulationsgrenzen).
- HEIM-DP verallgemeinert ihn auf zwei neue Aufgaben, Notiz und Auftragsfelder, und ergänzt die Kostengrenze in der Datenbank (300 Aufrufe pro Tag, CHF 50 pro Monat, FE-099 (7)).
- AI1 nutzt danach denselben Anschluss.

**Fremdkomponenten:** keine; nur der vorhandene Stack.

## 5. Zwischen-PRs, Abhängigkeiten, Aufwand

Die PRs sind technische Schritte und **kein** eigenes «fertiges Register».

| PR | Inhalt | Braucht | ESTIMATE (Läufe) |
|---|---|---|---|
| A | Datenmodell, RLS, Audit, synthetische Seed-Daten (2 Stationen, 8 Personen, 3 Dienste + Wochenende) | – | 3–4 |
| B | Wochenansicht und Personalansicht, Zuteilen mit Konfliktcodes, 390 px und Desktop | A | 3–5 |
| C | Abwesenheit, Lücke, Frühwarnung, «kann intern besetzen», Zuständigkeit je Lücke | B | 2–4 |
| D | STAB1 gezielt + Brücke (Entwurf aus Lücke, Station und Lückenbezug am Auftrag, Status zurück, «gefährdet») | C | 3–5 |
| E | KI: Notiz → Planvorschlag, Freitext → Auftragsfelder; Kostengrenze; Evaluationssatz; Not-Aus | D | 3–5 |
| F | `staging-smoke`-Pfad des ganzen Ablaufs (§2), Abschluss und Abnahmebericht | E | 1–2 |

**Gesamt ESTIMATE: 15–25 Engineering-Läufe plus Gate-Fenster.**

**Tragbar als ein Entwicklungsziel?** Ja, wenn der Umfang in §2 fest bleibt.

**Bewusst später**, mit Begründung, ohne stille Kürzung:
- automatischer Gesamt-Planvorschlag (deterministisch, siehe §3);
- Monatsansicht;
- Selbstansicht der Mitarbeitenden;
- Arbeitszeitprüfung (OPEN `lca`);
- Mitteilungen per Push und E-Mail an das Heim. Bis dahin ist der Zustand in der Zelle und in der Kopfzeile sichtbar.
- Ändern und Stornieren eines gesendeten externen Auftrags (OPEN `lca`/`owner`).

**Ohne diese Punkte erhält Ivica bereits** den ganzen Wochenablauf aus §2: planen, Ausfall, Lücke, intern oder extern, Status zurück.

## 6. Tests und Abnahme

- **Positiv:** Ablauf §2 als e2e bei 390 und 1440 px.
- **Negativ:**
  - eine Zuteilung trotz Abwesenheit oder ohne Stufe wird abgelehnt;
  - ein KI-Vorschlag wirkt nie ohne Bestätigung;
  - Not-Aus schaltet die KI ab, und das Formular bleibt nutzbar.
- **Rechte (pgTAP):**
  - Team, Pflegekraft, anderes Heim und Privatkunde sehen kein Heimpersonal;
  - der Auftrag enthält keinen Personalnamen und keinen Abwesenheitsgrund;
  - Audit für jede Planänderung.
- **KI:** Evaluationssatz von etwa 30 synthetischen Notizen und Bedarfssätzen. Gemessen werden der Anteil richtig erkannter Felder, Felder ohne Quelle (Ziel 0), Korrekturen bis zum Absenden, Kosten und Dauer je Aufruf.
- **Staging:** `staging-smoke`-Pfad «Dienstplanung Ende zu Ende» auf dem Merge-Commit, alle früheren Pfade grün.

**Gates:**
- `lca`: Personaldaten und Abwesenheit;
- `cra`: Stufenanforderungen, Wortlaut der Zustände;
- `uxa`;
- `aia`: KI-Kontrollen.

**Abnahmekriterium für das ganze Register:**
- Ivica klickt den Ablauf §2 auf Staging als Heimleitung durch;
- `staging-smoke` ist grün auf dem integrierten Commit;
- `ci-repeat` 10/10.

Gate «Simulation, synthetische Daten».

## 7. Zwei KI-Meilensteine, getrennt

| Meilenstein | Was das Modell tut | Wer bestätigt | Wann auf Staging (ESTIMATE) |
|---|---|---|---|
| **Erste echte KI in NAVORA insgesamt** | **Variante 1, AI1 zuerst:** Berichtsentwurf aus den Worten der Pflegekraft. **Variante 2, HEIM-DP zuerst:** die Heim-Notiz aus PR E | Pflegekraft bzw. Heimleitung | Variante 1: nach 3–5 Läufen. Variante 2: nach etwa 13–23 Läufen (PR A bis E) |
| **Erste echte KI im Pflegeheim-Register** | Notiz → Planvorschlag, Freitext → Auftragsfelder (PR E) | Heimleitung | nach PR E von HEIM-DP |

**Nachweis der Entlastung:** Für denselben Ausfall wird gemessen, wie viele Eingaben und Klicks es von der Meldung bis zur besetzten Zelle braucht: mit Notiz und KI gegen das reine Formular, synthetisch. Dazu der Anteil der KI-Vorschläge, die ohne Korrektur bestätigt werden.

## 8. Empfehlung `eng`: wie NAVORA stärker entlastet als ein übliches Dienstplanprogramm

1. **Der Alltag kommt als Satz, nicht als Formular.** Ausfälle und Zusatzbedarf werden in eigenen Worten notiert, und NAVORA macht daraus prüfbare Vorschläge.
2. **Die Lücke endet nicht im Plan.** Mit einem Klick wird sie ein geprüfter externer Auftrag, und der echte Status kommt zurück. Übliche Programme hören bei der roten Zelle auf.
3. **Eine Zuständigkeit je Lücke.** Niemand löst sie doppelt, und keine bleibt liegen.
4. **Ehrliche Zustände.** «Angefragt» ist nicht «gedeckt», und «Team prüft» wird nie erfunden.
5. **Ein Datenstrang** von Plan über Einsatz und Bericht bis zur Rechnung. Später entstehen daraus die Kosten je Station ohne Abtippen.

## 9. Entscheide

**Beim PO:**
- Umfang §2 als Vertrag übernehmen;
- Brief `HEIMDP.md` schreiben;
- *Active now* setzen;
- BK-f auf dem benannten Commit abnehmen (`ci-repeat` 44746720886, 22/22 grün).

**Beim Founder, nur einer:**
- **Variante 1:** AI1 (Berichtsentwurf, 3–5 Läufe) kommt vor HEIM-DP, als erste echte KI überhaupt.
- **Variante 2:** HEIM-DP startet sofort. AI1 folgt danach auf dem dann fertigen Anschluss in etwa 2–3 Läufen.
- `eng` empfiehlt **Variante 2**, weil du das Heim-Register als nächstes Ziel gesetzt hast und der KI-Anschluss in PR E ohnehin fertig gebaut wird.
