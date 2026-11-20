# HEIM1 · Vom Einzelformular zum Heim-Arbeitsbereich: Vorlage für Founder und PO

**Autor:** `eng`, 2026-11-20 ca. 15:05, auf Founder-Auftrag (Live-Sitzung, «Dein Feedback zum Heimportal umsetzen»).
**Status:** Vorschlag. Nichts davon ist gebaut, und nichts davon geht in einen laufenden PR. Umfang und Reihenfolge entscheidet der PO, und jede Entscheidung steht in §8 bei ihrem Owner.
**Kennzeichnung:** IMPLEMENTED (im Code auf `recovery/main` belegt), PLANNED (geplant), OPEN (Entscheid fehlt), UNKNOWN (nicht geprüft). Zeitangaben zum Aufwand sind ESTIMATE.

---

## 1. Überprüfter Ist-Stand des Heimportals auf Staging

**Beleg:**
- Code auf `recovery/main`.
- `staging-smoke` Lauf 44744533079 (4/4, App-Commit `8051283`, Datenbank bis 0157).
- Der Screenshot des Founders vom 2026-11-20 ca. 14:50.

Selbst durchgeklickt habe ich Staging nicht: Die Passwörter der Demo-Konten kennt nur der Founder.

| Was das Heim heute kann | Stand | Wo |
|---|---|---|
| Schicht erfassen: Datum, Beginn/Ende, PLZ Basel-Stadt/-Landschaft, Stufe AGS/FaGe/HF, Tätigkeiten, Distanz | IMPLEMENTED | `/order`, `private.client_order_check` (0129, 0132, 0133) |
| Prüfung vor dem Absenden: Beginn nicht in der Vergangenheit, Region, Stufe passt zu Tätigkeit (Matrix QAM-0.2, PROPOSED) | IMPLEMENTED | `preview_client_order`, `confirm_client_order` |
| Angebot nur an Teams, in denen mindestens **eine** Person Region, Stufe, Tätigkeitsnachweis und freie Zeit für die ganze Schicht erfüllt | IMPLEMENTED | `private.screen_order_reach`, `private.order_member_step` (0130, 0132) |
| Status je Auftrag | IMPLEMENTED | `clientCoverLines`, `public.client_orders` |
| Rechnungen des Teams lesen (simuliert, ohne Zahlung) | IMPLEMENTED | `public.client_invoices` (0156), `/order` «Rechnungen» |
| «Meine Einstellungen» | IMPLEMENTED (Inhalt hier nicht geprüft) | `/settings` |
| Eigene Dienstbezeichnungen («Frühdienst») | IMPLEMENTED, nur Anzeige, steuert nichts | `client_shift_plans` (0129) |

Die Status je Auftrag sind:
- «Noch nicht gedeckt»: an alle passenden Teams gleichzeitig angeboten, oder die benannte Person bestätigt noch.
- «Gedeckt · Person benannt, geprüft für HF».
- «Nicht gedeckt»: kein passendes Team frei, oder die Schicht hat begonnen.
- «Nicht mehr gedeckt»: wieder an alle Teams angeboten.

**Was fehlt (belegt durch Suche im Code):**
- Stornieren oder Ändern durch das Heim: es gibt keinen Befehl dafür.
- Benachrichtigungen an das Heim: Push gibt es nur für Teammitglieder (SIG2).
- Tages- und Wochenansicht.
- Kostenübersicht.
- Planung des eigenen Personals (B2B-Heimsuite, Blueprint §4.2: PLANNED).
- KI im Heimablauf: Der Vertrag K-1 «Erfassung» ist von `aia` unterschrieben, gebaut ist nichts.

**Hinweis zur Liste «Ihre Aufträge (8)»:** Jeder Staging-Testlauf legt synthetische Aufträge an. Die Liste wächst also mit, das ist kein Fehler.

## 2. Ein Wochenablauf des fiktiven Heims

**Synthetische Ausgangslage:**
- Heim: «Testheim Rhein (synthetisch)», Station 2, Woche 48.
- Eigenes Personal: 6 Personen.
- Mittwoch Frühdienst: 1 FaGe fehlt, weil eine eigene Mitarbeiterin abwesend ist (synthetisch).

| # | Schritt | Heute vorhanden | Fehlt | Frontend Heimleitung | Backend | Wer entscheidet |
|---|---|---|---|---|---|---|
| 1 | Woche öffnen | nur Auftragsliste | Wochenansicht: eigene Dienste und externe Aufträge getrennt | `/heim` Woche (neu) | Lesefunktion `client_week()` auf `client_orders` und Eigenplan (neu) | – |
| 2 | Lücke im eigenen Plan erkennen | – | **eigener Dienstplan** (B2B), getrennt vom Auftrag | `/heim` Planung (B2B-Modul) | Plan-Tabelle des Heims, nur eigenes Personal | Heim (Dienstplanerin) |
| 3 | Bedarf prüfen, Anfrage erstellen | Formular `/order` | «Aus Lücke bestellen» übernimmt Datum, Zeit und Stufe aus dem Plan; optional KI-Erfassung aus einem Satz (K-1) | `/order` mit vorausgefülltem Entwurf | `preview_client_order` unverändert | Heim |
| 4 | Gibt es grundsätzlich geeignete Teams? | intern berechnet (`screen_order_reach`), dem Heim nicht gezeigt | ehrliche Vorschau, siehe §4 | Zusammenfassung | dieselbe Prüfung als Vorschau, ohne Schreiben | – (feste Regel) |
| 5 | Absenden nach Bestätigung | IMPLEMENTED | – | «Bestätigen & Absenden» | `confirm_client_order` | Heim |
| 6 | Team übernimmt und besetzt | IMPLEMENTED (`take_order`, Bestätigung der Kollegin) | – | Teamansicht `/team` | `take_order`, `acknowledge…` (0136) | **Team** (FE-039: niemand teilt für ein Team ein) |
| 7 | Status: offen / bestätigt / gefährdet / ausgeführt / abgerechnet | offen und bestätigt IMPLEMENTED | **«gefährdet»** fehlt als Zustand für das Heim; «ausgeführt» und «abgerechnet» stehen nicht am Auftrag | Statuszeile je Auftrag | Ableitung aus Take, Besuch, Bericht, Rechnung (neu, nur lesend) | – (feste Regel; Schwelle «gefährdet» OPEN) |
| 8 | Absage oder Ausfall | Team erfährt es (Signal `take_member_dropped`, 0144); das Heim sieht nur die Statuszeile | **Benachrichtigung an das Heim**, nächste Schritte | Hinweis oben auf `/heim` + Push/E-Mail | SIG1-Weg um Empfängertyp «Auftraggeber» erweitern | Team besetzt neu; Heim entscheidet, ob es selbst handelt |
| 9 | Monatsende: Kosten nachvollziehen | einzelne Rechnungen IMPLEMENTED | Monatssicht in drei getrennten Spalten (siehe §3) und CSV | `/heim` Kosten | Lesefunktion über Take-Snapshot und Rechnungen | – |

**Trennung B2B-Dienstplan und externer Auftrag:**
- Der **Dienstplan** gehört dem Heim und betrifft nur dessen eigenes Personal. NAVORA hat dort keine Teamdaten.
- Der **Auftrag** ist ein Angebot an selbstorganisierte Teams, die selbst entscheiden.
- Verbunden sind beide nur über einen bewussten Schritt des Heims: «Diese Lücke als Auftrag anbieten». Er erzeugt einen Auftrag mit Verweis auf die Lücke. Der Dienstplan ändert dabei kein Team und das Team keinen Dienstplan.
- Technisch sind es zwei Tabellen mit eigenen Rechten (RLS), verbunden durch einen Fremdschlüssel vom Auftrag auf die Lücke.

## 3. Die Heim-Übersicht als technische Grundlage

**Eine Seite `/heim` mit vier Reitern.** Datum und Station bleiben beim Wechsel erhalten, und jede Zahl ist ein Link auf die zugrunde liegenden Aufträge.

1. **Heute / Morgen:**
   - Liste nach Uhrzeit.
   - «Braucht Ihre Handlung» steht immer oben: ungedeckt, gefährdet, Rechnung erhalten.
2. **Woche:** Raster Tag × Dienst, je Zelle die eigenen Dienste und die externen Aufträge, farblich getrennt. Auf dem Handy wird daraus eine Tagesliste.
3. **Aufträge:** heute / kommend / offen / erledigt, gruppiert nach Tag.
4. **Kosten**, mit drei Spalten, die nie zusammengezählt werden:
   - **geschätzt:** bestellte Stunden. Einen Preis gibt es erst nach der Übernahme, weil jedes Team seinen Preis selbst setzt; vor der Übernahme zeigt NAVORA darum **keinen Betrag** und nennt den Grund.
   - **vereinbart:** bestellte Stunden × Preis aus dem Take-Snapshot.
   - **in Rechnung gestellt:** gesendete Rechnungen.

**Herkunft jeder Zahl:** Alle Werte kommen aus bestehenden Tabellen und werden nur gelesen: `client_orders`, Takes, Besuche, Berichte, `team_invoice_drafts`, Rechnungen. Neu ist eine Lesefunktion je Reiter mit RLS auf das eigene Kundenkonto. Es entsteht **keine** neue Zahl ohne Quelle. «Gefährdet» ist ein abgeleiteter Zustand mit Begründungscode:

| Begründungscode | Bedeutung |
|---|---|
| `no_longer_covered` | Übernahme fiel weg |
| `take_member_dropped` | die benannte Person fällt aus |
| `awaiting_acknowledgement` | die benannte Kollegin hat nach der Übernahme noch nicht bestätigt |
| `open_near_start` | noch offen kurz vor Beginn; Schwelle OPEN, Simulationsvorgabe K-8: 240 min, PROPOSED |

**Spital und Privatperson** bekommen nicht dieselbe Seite:
- **Spital:** stationsbezogen und in Stunden statt Wochen; Aufträge für Spitalstationen sind heute bewusst gesperrt (`hosp_in_strict`).
- **Privatperson:** einzelne Einsätze, einfache Sprache, keine Kostenstellen.

Eigener Entwurf je Sektor als Konfiguration auf denselben Daten, kein Fork.

## 4. Kritische Bewertung der Vorschau «Anzahl passender Teams»

**Was die Prüfung heute wirklich prüft** (`screen_order_reach` und `order_member_step`, je Person):
1. aktives Mitglied mit offenem Zugang (LEAVE1);
2. die verifizierte Stufe gilt bis Schichtende;
3. jede verlangte Tätigkeit hat einen verifizierten Nachweis (Matrix PROPOSED);
4. für die ganze Schicht frei **laut NAVORA-Daten**, also keine Abwesenheit und kein anderer Einsatz;
5. Distanz und Region.

**Nicht** geprüft werden:
- die tatsächliche Bereitschaft;
- andere Arbeitgeber oder private Termine;
- Delegationen (Matrix PROPOSED);
- ob ein Team annimmt. Jedes Team kann ablehnen.

**Belastbar ist vor dem Absenden also nur:** «Nach den Daten in NAVORA erfüllt mindestens eine Person in einem Team der Region Stufe, Tätigkeiten und ist eingetragen frei.» Daraus folgt weder Verfügbarkeit noch Zusage.

**Bewertung:**
- Eine Zahl «2 passende Teams» verbessert den Auftrag kaum. Sie wirkt präzise und wird leicht als Zusage gelesen; ich ziehe diesen Teil meines Vorschlags zurück.
- Den echten Nutzen hat **der Nullfall**: Heute erfährt das Heim erst nach dem Absenden «Kein passendes Team ist frei».

**Empfehlung:**
- **Kein Treffer, vor dem Absenden:**
  - Text: «Für diese Zeit findet NAVORA derzeit in Ihrer Region kein Team, das Stufe und Tätigkeiten erfüllt und frei eingetragen ist.»
  - Darunter der Grund aus dem vorhandenen Code: `no_member_with_grade`, `no_member_activity_evidence`, `no_member_available` oder Distanz, ohne Personen.
  - Nächste Schritte: «Trotzdem absenden: Teams sehen den Auftrag, sobald jemand frei wird», «Andere Zeit wählen», «Distanzvorgabe lockern».
  - **NAVORA schlägt nie eine niedrigere Stufe vor.** Die Stufe ist eine fachliche Entscheidung des Heims (Patientensicherheit).
- **Mindestens ein Treffer:** kein Zähler, sondern «Ihr Auftrag geht an alle passenden Teams der Region. Ein Team entscheidet selbst, ob es übernimmt.»
- **Nach dem Absenden ist eine Zahl ehrlich:** «An 3 Teams gesendet · noch keine Übernahme». Das ist ein Fakt, denn die Angebotszeilen existieren.

## 5. Änderung und Stornierung als Ablauf

**Grundsatz:** Ein Auftrag wird nie gelöscht. Eine Änderung ist ein neuer, geprüfter Zustand mit Audit, und Heim und Team lesen dieselbe Wahrheit.

| Zeitpunkt | Folge (technisch) | Wer wird informiert | Offen |
|---|---|---|---|
| vor der Übernahme | Stornierung: Angebot zieht sich bei allen Teams zurück, Status «storniert». Änderung: neue Prüfung, neue Angebotszeilen, alte erlöschen. | Teams, die das Angebot sehen (Hinweis «zurückgezogen») | – |
| nach der Übernahme | Stornierung beendet den Take mit Grund `client_cancelled`, der Besuch wird beendet. Eine Änderung von Zeit, Stufe oder Tätigkeit verlangt eine **neue Eignungsprüfung der benannten Person**; fällt sie durch, entsteht ein neues offenes Angebot. | Team und benannte Person (SIG1-Weg) | Ausfallentschädigung und Vertragsfolgen: **OPEN** (`lca`, `owner`) |
| kurz vor Beginn | wie oben, zusätzlich Kennzeichen «kurzfristig» | Team sofort, Push | was «kurzfristig» heisst und ob Kosten entstehen: **OPEN** (`lca`, `owner`) |
| Einsatz läuft | keine Stornierung durch Knopf. Das Heim meldet «Einsatz beenden»; Team und Pflegekraft schliessen den Besuch fachlich ab, der Bericht bleibt Pflicht. | Pflegekraft direkt | Abbruch eines laufenden Einsatzes: **OPEN** (`clinical`, D-31) |

**Kein «Stornieren»-Knopf ohne diese Zustände.** Abhängig von: Benachrichtigung an Team (vorhanden) und Heim (fehlt), sowie den Entscheiden in der Spalte «Offen».

## 6. Die erste echte KI-Funktion im Heimablauf

**Ehrliche Einordnung:**
- Der Founder hat die erste echte Modellfunktion festgelegt: den Berichtsentwurf mit echtem Claude (FE-097, Paket AI1). Sie ist auf der Teamseite, nicht beim Heim.
- Die Reihenfolge nach FE-099 (7) ist STAB1 → AI1 → BK-d → Absenzen Station → BK-g.

**Empfehlung `eng`:** Die KI-Auftragserfassung **K-1 (BK-d)** kommt **direkt nach AI1**, vor jeder Komfortfunktion des Heims (Übersicht, Storno, Woche kopieren). Begründung:
1. AI1 baut die Infrastruktur, die K-1 wiederverwendet:
   - Anbieter-Anschluss Anthropic (FE-094);
   - Not-Aus;
   - tägliche Kostengrenze;
   - Ledger «vorgeschlagen / entschieden»;
   - Fail-closed.

   K-1 kostet danach nur noch den eigentlichen Anwendungsfall.
2. K-1 nimmt die meiste Arbeit ab: Ein Satz ersetzt acht Formularfelder.
3. Die Sicherheit bleibt unverändert, weil hinter K-1 dieselbe feste Prüfung `client_order_check` steht.

**Zuschnitt K-1, eng begrenzt:**
- **Eingabe:** ein Satz Text, synthetisch, zum Beispiel «Morgen Frühdienst 7 bis 15 Uhr, eine FaGe für Grundpflege, Station 2, 4051». Diktat erst später; die Spracherkennung ist ein zweiter Anbieter.
- **Das Modell schlägt vor:** Datum, Beginn, Ende, PLZ und Tätigkeiten, **je Feld mit der Textstelle als Quelle**. Die Stufe nur, wenn sie wörtlich genannt ist; nie erschlossen.
- **Bleibt feste Regel:** Region, Stufe zu Tätigkeit, Beginn nicht in der Vergangenheit, Eignung der Teams. Das Modell kann keine dieser Prüfungen überspringen.
- **Ungeklärt:** Fehlende oder mehrdeutige Angaben bleiben leer, mit «bitte angeben». Das Modell rät nicht.
- **Kennzeichnung:** Jedes Feld zeigt «vorgeschlagen aus Ihrem Text» oder «von Ihnen bestätigt». Das Muster gibt es schon in AIG1 («vorgeschlagen von», `tests/e2e/aig1.spec.ts`). Abgesendet wird erst, wenn jedes vorgeschlagene Feld bestätigt ist.
- **Tests:**
  - ein synthetischer Satz-Korpus, etwa 30 Sätze mit erwarteten Feldern, und eine Messung je Feld: richtig, leer gelassen oder falsch;
  - der Korrekturaufwand als Anzahl Änderungen bis zum Absenden;
  - Fail-closed bei Zeitüberschreitung oder Modellfehler: Das Formular bleibt manuell nutzbar;
  - Kosten und Latenz je Aufruf gemessen.
- **Zustände, getrennt ausgewiesen:**
  - Testersatz (CI, fester Antworttext);
  - angeschlossenes Modell (nur Staging, synthetisch);
  - feste Regel für alles Übrige.
- **Wann kann der Founder es ausprobieren? ESTIMATE, keine Zusage:**
  - nach STAB1 (2–3 Läufe), AI1 (3–5 Läufe, plus Founder-Einstellung Schlüssel und Kostengrenze auf Render) und K-1 (4–6 Läufe);
  - jeweils plus Gate-Fenster;
  - grob 10–15 Engineering-Läufe ab heute.

## 7. Fünf fehlende Fähigkeiten, Reihenfolge, Innovation

**Die fünf wichtigsten fehlenden Fähigkeiten** (mit Abhängigkeit):

1. **KI-Auftragserfassung K-1.** Braucht AI1.
2. **Heim-Übersicht `/heim` mit «gefährdet» und Kosten in drei Spalten.** Nur lesend, keine neue Fachregel ausser der Schwelle «gefährdet» (OPEN).
3. **Benachrichtigung und Eskalation an das Heim.** Braucht die Erweiterung des SIG1-Wegs und eine `lca`-Prüfung, welche Angaben an ein Kundenkonto gehen dürfen.
4. **Änderung und Stornierung als Zustandsablauf.** Braucht Nummer 3 und Entscheide von `lca`/`owner` (§5).
5. **Eigener Dienstplan (B2B) mit «Lücke als Auftrag anbieten».** Braucht einen eigenen Paketvertrag, Lizenzmodul GM-2 (OPEN) und `lca` zu den Daten des Heimpersonals.

**Empfohlene Reihenfolge kleiner, bedienbarer Pakete.** Jedes Paket hat einen eigenen `staging-smoke`-Pfad; der PO entscheidet.

| # | Paket | Was der Founder danach auf Staging neu tun kann | ESTIMATE |
|---|---|---|---|
| 1 | STAB1 (beschlossen) | nichts Sichtbares; sichere Grundlage für BK-d und BK-g | 2–3 Läufe |
| 2 | AI1 Berichtsentwurf mit echtem Claude (beschlossen) | als Pflegekraft einen Berichtsentwurf von Claude erhalten und vor der Unterschrift ändern | 3–5 Läufe |
| 3 | **K-1 KI-Auftragserfassung** (BK-d, Text) | als Heim einen Bedarf in einem Satz schreiben, die Felder prüfen, bestätigen und absenden | 4–6 Läufe |
| 4 | HEIM-1 Übersicht (nur lesend) + ehrlicher Nullfall (§4) | als Heim die Woche sehen, «braucht Ihre Handlung» zuerst, Kosten in drei Spalten | 3–4 Läufe |
| 5 | Benachrichtigung an das Heim | als Heim eine Nachricht erhalten, wenn eine Übernahme wegfällt | 2–3 Läufe |
| 6 | Änderung und Stornierung | als Heim einen Auftrag ändern; das Team sieht dieselbe Wahrheit | 4–6 Läufe, nach den Entscheiden |
| 7 | B2B-Dienstplan + «Lücke anbieten» | als Dienstplanerin eine Lücke im eigenen Plan sehen und als Auftrag anbieten | eigener Vertrag |

Diese Reihenfolge weicht nur in einem Punkt vom FE-099-Plan ab: HEIM-1 kommt **nach** BK-d und nicht davor. Eine Prüfung der Absenzen auf Station (FE-099 (7)) gehört je nach PO-Schnitt in Paket 5 oder 7.

**Drei Innovationsideen**, je mit kleinstem Test auf synthetischen Daten:

**A · Vorausschauender Handlungsentwurf aus der Planlücke.** NAVORA sieht eine Lücke im eigenen Plan, zum Beispiel aus einer eingetragenen Abwesenheit drei Tage im Voraus. Es legt einen **Auftragsentwurf** bereit: Datum, Zeit, Stufe aus dem Plan, Status «Entwurf, nicht gesendet». Die Heimleitung prüft ihn und sendet ihn mit einem Tipp. Zuerst als feste Regel, die Begründung später auch durch KI.
- Arbeit gespart: Telefonieren und Formular entfallen; das Heim reagiert Tage statt Stunden vorher.
- Selbstorganisation: Teams bekommen Aufträge früher und planen besser.
- Aufwand und Betrieb: mittel, braucht Paket 7; Betriebskosten gering, kein Modell nötig.
- Risiko: Ein Entwurf darf nie automatisch gesendet werden; ein falscher Plan erzeugt nur einen falschen Entwurf.
- Kleinster Test: eine synthetische Woche mit einer eingetragenen Abwesenheit, erwartet wird genau ein Entwurf mit Verweis auf die Lücke; pgTAP und e2e.

**B · Teams melden freie Kapazität («Wir haben Di–Do Nachmittag eine HF frei»).** Bisher zieht das Heim an den Teams. Neu bieten Teams selbst an, und das Heim sieht beim Erfassen «Zu dieser Zeit hat ein Team Kapazität gemeldet», ohne Namen.
- Arbeit gespart: weniger Absagen und weniger Leerlauf beim Team.
- Selbstorganisation: hoch, denn das Team steuert seine Auslastung selbst.
- Aufwand und Betrieb: klein bis mittel (Tabelle, RLS, eine Karte in `/team`, ein Satz in der Vorschau).
- Risiko: Eine gemeldete Kapazität ist keine Zusage und erlischt mit der Zeit; Konkurrenzinformation zwischen Teams (BK-f-F3, WEKO) prüft `lca`.
- Kleinster Test: ein Team meldet ein Zeitfenster, und das Heim erfasst eine Schicht darin; erwartet sind ein Hinweis ohne Teamnamen und keiner ausserhalb.

**C · Ein Ereignis, viele Nutzer: der unterschriebene Bericht als einzige Quelle.** Heute führt der Bericht zu Rechnung und Abrechnungsfakt. Neu bekommt das Heim aus demselben Bericht zusätzlich eine **Leistungsbestätigung** (Zeit, Tätigkeiten, unterschrieben von wem, wann) für die eigene Kontrolle. Pflegedokumentation wird nicht doppelt erfasst und nichts muss abgetippt werden.
- Arbeit gespart: Das Heim prüft die Rechnung gegen die Bestätigung statt gegen Telefonnotizen.
- Selbstorganisation: Das Team belegt seine Leistung selbst.
- Aufwand und Betrieb: klein, nur lesend.
- Risiko: welche Pflegeinhalte das Heim sehen darf, ist eine **Datenschutzfrage, OPEN, `lca`**. Bis dahin nur Zeit und Tätigkeitscodes, kein Freitext.
- Kleinster Test: Nach BK-f-Pfad 3 sieht das Heim zur Rechnung eine Bestätigung mit gleichen Minuten und gleichen Tätigkeiten und ohne Personennamen; pgTAP für die Rechte und ein `staging-smoke`-Schritt.

## 8. Trennung: technische Empfehlung `eng` und Entscheide anderer Rollen

**Technische Empfehlung `eng` (dieses Dokument):**
- Zuschnitt und Datenherkunft von `/heim`.
- «Gefährdet» als abgeleiteter Zustand mit Begründungscode.
- Kosten in drei getrennten Spalten.
- Nullfall statt Zähler.
- Änderung als Zustand, nie als Löschung.
- K-1 auf der AI1-Infrastruktur und direkt nach AI1.
- Dienstplan und Auftrag als getrennte Tabellen mit Verbindungsschritt.

**Entscheide des PO:**
1. Reihenfolge der Pakete 3–7 und ob K-1 direkt nach AI1 kommt.
2. Paketverträge mit Umfang, Abnahme und `staging-smoke`-Pfad.
3. Ob Idee A, B oder C als Folgepaket geprüft wird.

**Entscheide anderer Owner (OPEN, werden nicht von `eng` gesetzt):**
- Schwelle «gefährdet» und Vorlauf K-8: `cra`/`clinical`.
- Folgen kurzfristiger Stornierung und Ausfallentschädigung: `lca`/`owner`.
- Abbruch eines laufenden Einsatzes: `clinical` (D-31).
- Welche Angaben an ein Kundenkonto gehen dürfen (Benachrichtigung, Idee C): `lca`.
- Daten des Heimpersonals im B2B-Plan und Lizenzmodul: `lca`/`owner` (GM-2).
- Wortlaut aller neuen Texte: `uxa`.
- KI-Vertrag K-1, Kontrollen: `aia`.
