# Bestätigung der NAVORA-Richtung (Founder-Schreiben vom 6. November 2026)

**Von:** Product Owner (`po`) · **An:** Founder · **Stand:** 2026-11-06 12:00 (Europe/Zurich), `recovery/main` @ `e97e786` · **Status:** Antwort auf das Schreiben „Bitte Verständnis der NAVORA-Richtung bestätigen“, nachgeführt 12:30 auf die überarbeitete Fassung (Punkte 5, 8, 13, 16) und Ihre Wahl für Phase A (FE-031, FE-032). Die bestätigten Punkte sind in [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) als FE-019 bis FE-030 erfasst, der Blueprint ist auf Version 2.1 nachgeführt. Ich habe keine Tests ausgeführt; dies ist reine Dokumentationsarbeit.

**Gelesen für diese Antwort:** die Agenten-Dateien in `docs/agents/` (README, Koordination, Entscheidungsliste, Index, Pakete D-1, D-11, D-12, D-14, D-24, D-25, D-34, D-35, D-36, D-37, SR-26), Blueprint V2, Founder-Bericht, `ARCHITECTURE.md`, `ROADMAP.md`, `CARE_OPERATING_MODEL.md`, `IMPLEMENTATION_SEQUENCE.md`; auf GitHub die offenen Issues und PRs, die Branch-Liste und die gespeicherten Prompts aller geplanten Agenten-Aufgaben.

---

## 1. Geschäftsmodell in eigenen Worten

**So verstehe ich NAVORAs Geschäftsmodell:**

NAVORA ist das digitale Betriebssystem, mit dem Pflege- und Betreuungsteams ihre Arbeit selbst organisieren. Es ist keine Dokumentations-App und kein Planungs- oder Chat-Werkzeug, sondern verbindet die Arbeit vor Ort mit Teamkoordination, Dokumentation, Pflege- und Betreuungsplanung und Abrechnung auf einem gemeinsamen, nachvollziehbaren Datensatz.

- **Hauptproblem:** Pflegefachpersonen verlieren einen grossen Teil ihrer Arbeitszeit an Arbeit ohne die betreute Person: nachträgliches Schreiben, manuelle Planung, Koordinationsanrufe bei Ausfällen, Aufbereitung der Abrechnung und das Korrigieren von Fehlern. Das kostet Pflegezeit, Kontinuität und Arbeitsfreude.
- **Produktnutzen:** NAVORA nimmt diese Arbeit spürbar und **messbar** ab. Die Dokumentation entsteht aus dem, was ohnehin erfasst wird, und wird nur noch geprüft und freigegeben. Planung und Ausfälle laufen nach den Regeln des Teams, nicht über eine Disposition. Die Abrechnung wird aus bestätigten Fakten vorbereitet und vor dem Versand geprüft. Qualität, Kontinuität, Sicherheit und Teamautonomie werden dabei gestützt, nicht geopfert.
- **Rolle der KI:** KI ist der zentrale Hebel, um diese Arbeit tatsächlich zu übernehmen, nicht ein Anzeige- oder Chat-Zusatz. Sie bereitet Arbeitsabläufe vor und hilft sie auszuführen: Dokumentationsentwürfe, Planungsvorschläge, Ausfallkoordination, Abrechnungsvorbereitung, Fehlerprüfung. Das geschieht immer innerhalb von Regeln, Rechten und Kontrollen: KI erfindet keine Tatsachen, Menschen prüfen, entscheiden und unterschreiben, jeder KI-Beitrag steht im Vorschlagsprotokoll.
- **Zielkunden und Nutzer:** Ich trenne fünf Rollen.
  - **Käufer und Zahler der Plattform:** die bewilligte Organisation (Spitex-Organisation, Pflegeheim, später Spital, später teameigene Anbieter).
  - **Nutzer:** die Teammitglieder (Pflegefachpersonen, Pflegeassistenz), Administration und Operations, später lesend die Angehörigen.
  - **Leistungserbringer:** rechtlich die Organisation, tatsächlich die Teams.
  - **Kostenträger der Pflege:** Versicherer, Kanton oder Gemeinde, die betreute Person. Sie zahlen die Pflege, nicht NAVORA.
  - **Betreute Person:** Klient:in oder Bewohner:in.
- **Versorgungskontexte:** ambulante Pflege, Pflegeheime, Spitäler, Privatpersonen. Sie werden nacheinander gebaut, aber die Plattform schliesst keinen davon aus.
- **Erlösmechanismus:** Gebühren für die Nutzung der Plattform, bezahlt von der Organisation. NAVORA verdient nicht an Pflegemenge oder Einstufung. F3 (pro aktivem Teammitglied und Monat) ist eine mögliche Basis; der Vergleich mehrerer Modelle liegt in [`PRICING_MODEL_COMPARISON.md`](PRICING_MODEL_COMPARISON.md).
- **Noch nicht entschieden:** Preis und Preismodell (D-14); was „Privatpersonen“ genau umfasst (O-2);  ob und wann reale Daten an einen KI-Dienst gehen dürfen (D-35 Regel A bleibt, Paket D-41); ob das Ziel „teameigener Anbieter“ auch im Pflegeheim gilt (O-5).

### 1.1 Wirkungsziel: weniger Spitex-Overhead, selbstorganisierte Teams, besserer Verdienst (FE-032)

So verstehe ich das Ziel: In einer klassischen Spitex-Organisation fliesst ein Teil des Ertrags in Arbeit, die keine Pflege ist und die auch die Pflegekräfte belastet. Dazu gehören Disposition und Einsatzplanung durch eine Zentrale, die Vermittlung neuer Klient:innen (Aufnahme, Matching, Zuteilung), Teamleitung als Koordinationsschicht, Telefonketten bei Ausfällen, Rapporte, nachgetragene Dokumentation, manuelle Abrechnungsaufbereitung und Korrekturschleifen.

NAVORA soll den **vermeidbaren** Teil davon in Software und Teamregeln verlagern. Teams organisieren sich selbst: Aufnahme, Planung, Vertretung, Übergabe. Was an Overhead wegfällt, soll den Teams als besserer Verdienst oder als mehr Zeit für Pflege zugutekommen und nicht als zusätzliche Marge bei Dritten verschwinden. Die Selbstorganisation des Teams bleibt dabei erhalten: NAVORA ersetzt eine Hierarchie, setzt keine neue an ihre Stelle.

Diese Wirkung ist **noch nicht nachgewiesen**. Die Annahmen dahinter und ihre Messung:

| # | Annahme (Hypothese) | Wie wir sie prüfen | Wann |
|---|---|---|---|
| H-1 | Ein relevanter Anteil der bezahlten Pflegezeit geht heute an vermeidbare Administration und Koordination | Basismessung der administrativen Minuten pro Einsatz bzw. Bewohnertag (M-15) im simulierten Betrieb; in Phase B beim realen Partner **vor** und nach der Einführung | Phase A (Simulation), Phase B (real) |
| H-2 | Disposition und Vermittlung lassen sich ohne Sicherheitsverlust durch Teamregeln und Software ersetzen | Anteil der Zuteilungen und Vertretungen im Team ohne Operations (M-20), Sicherheitsindikatoren unverändert oder besser (M-21) | Phase A, Phase B |
| H-3 | Weniger Overhead senkt die Kosten pro Pflegestunde der Organisation | Kostenvergleich mit dem Partner in Phase B (Daten des Partners; UNKNOWN) | Phase B |
| H-4 | Eingesparte Kosten können rechtlich und wirtschaftlich als höherer Verdienst an Pflegekräfte gehen | Teamüberschuss-Modelle S1 bis S4 (D-14), `lca` zur Zulässigkeit, Lohnvergleich pro Arbeitsstunde (Gate-8-Kennzahl) | nach Phase A (Modell), Phase B (Messung) |
| H-5 | Die Plattformgebühr ist kleiner als der eingesparte Overhead | Preisvergleich (`PRICING_MODEL_COMPARISON.md`) gegen gemessene Einsparung | nach Phase A |
| H-6 | Selbstorganisierte Teams bleiben stabil (keine neue informelle Hierarchie, keine Überlastung einzelner) | Kontinuität (M-19), Ausfallkoordination (M-17), Teamzufriedenheit (Gate 8) | Phase B |

Keine dieser Annahmen wird im Produkt oder in Texten als Tatsache dargestellt, bevor sie gemessen ist. Insbesondere behauptet NAVORA gegenüber Partnern keine Einsparung und keinen Verdienstzuwachs ohne Messung.

**Annahmen, die ich dafür treffe (bitte korrigieren, falls falsch):**
1. Käufer ist die bewilligte Organisation, nicht das einzelne Teammitglied und nicht die betreute Person.
2. Die Plattformgebühr wird nicht separat der betreuten Person oder dem Versicherer verrechnet. Ob sie aus KVG-finanzierten Erträgen getragen werden darf, prüft `lca` (UNKNOWN).
3. Pflegeheime kaufen NAVORA als Organisation wie Spitex-Organisationen; ihre Pflegefinanzierung ist anders aufgebaut (pro Tag und Pflegestufe statt pro Einsatz; Regeln UNKNOWN, `lca`).
4. Die administrative Entlastung ist das Hauptverkaufsargument; der Nachweis kommt aus den Kennzahlen M-15 bis M-21 (Blueprint §10.2) zuerst im simulierten Test, dann im realen Pilot.
5. KI-Kosten pro Vorgang sind messbar, sobald ein Anbieter für synthetische Daten freigegeben ist (O-4); vorher bleiben sie UNKNOWN.

---

## 2. Punkte 1–22 einzeln

Format je Punkt: **verstanden** · Interpretation · Umsetzung (Datei, Abschnitt, Ticket) · Klärungsbedarf.

### A. Geschäftsmodell

**1. Was NAVORA ist** · verstanden: **ja**
- *Interpretation:* Betriebssystem und KI-gestützte Arbeitsplattform über die ganze Kette Arbeit vor Ort → Koordination → Dokumentation → Planung → Abrechnung; nicht nur App, Planer oder Chatbot.
- *Umsetzung:* Blueprint V2.1 §1 (Vision neu formuliert); FE-023.
- *Klärungsbedarf:* keiner.

**2. Hauptproblem: administrative Entlastung** · verstanden: **ja**
- *Interpretation:* Die zentrale Wirkung ist weniger Zeit für Nachschreiben, manuelle Planung, Koordinationsanrufe, Abrechnungsaufbereitung und Fehlerkorrektur, gemessen und nicht behauptet; Qualität, Kontinuität, Sicherheit und Teamautonomie bleiben Bedingungen.
- *Umsetzung:* Blueprint §1 und §10.2 (neue Kennzahlen M-15 bis M-21); Founder-Bericht.
- *Klärungsbedarf:* keiner. Hinweis: Die North-Star-Kennzahl „direkte Pflegezeit“ bleibt; die administrative Zeit wird daneben direkt gemessen (M-15).

**3. Rolle der KI** · verstanden: **ja**
- *Interpretation:* KI übernimmt Arbeitsabläufe (Dokumentation, Planung, Ausfälle, Abrechnung, Fehlerprüfung) innerhalb klarer Regeln, Rechte und Kontrollen; sie ist nicht nur Anzeige oder Chat.
- *Umsetzung:* Blueprint §1, Tabelle „AI work flows are the core“; Briefs DOC-AI, PLAN4, QUAL1, BILL1 (Entwürfe, M8.1b); FE-028.
- *Klärungsbedarf:* KI auf **realen** Daten ist durch D-35 Regel A gesperrt (Punkt 10). In Phase A kann KI nur auf synthetischen Daten echt getestet werden, und dafür braucht es einen freigegebenen Anbieter (O-4).

**4. Für wen NAVORA gedacht ist** · verstanden: **ja**, mit Klärungsbedarf zu „Privatpersonen“
- *Interpretation:* Ambulante Pflege, Pflegeheime, Spitäler, Privatpersonen; nacheinander gebaut, nie versehentlich ausgeschlossen. Nutzer, Käufer/Zahler, Leistungserbringer, Team und betreute Person werden getrennt (siehe §1).
- *Umsetzung:* Blueprint §1.3 (Matrix der Versorgungskontexte); FE-027.
- *Klärungsbedarf O-2, „Privatpersonen“ hat mehrere mögliche Bedeutungen:*
  - (a) betreute Personen, die Pflege oder Betreuung **selbst bezahlen** und direkt beauftragen;
  - (b) **Angehörige als Anfragende oder Auftraggebende** für eine betreute Person;
  - (c) **Privathaushalte als Arbeitgeber** von Betreuungspersonen (z. B. Betreuung zu Hause rund um die Uhr);
  - (d) **pflegende Angehörige als Nutzer** von NAVORA (ob und wie sie in BS/BL angestellt werden können, ist eine Rechtsfrage, UNKNOWN);
  - (e) die **betreute Person selbst als Nutzer** (heute ausgeschlossen; D-40 erlaubt nur Angehörigen eine lesende Ansicht).
  - Ich lege keine Variante fest. Empfehlung siehe §4.

**5. Wie NAVORA Geld verdient** · verstanden: **ja**
- *Interpretation:* Plattform-Nutzungsgebühren; F3 ist eine mögliche Kalkulationsbasis, kein gewählter Preis. Ich vergleiche einfache, transparente Modelle: wer zahlt, wofür, welche Kosten, Folgen für kleine und grosse Teams.
- *Umsetzung:* [`PRICING_MODEL_COMPARISON.md`](PRICING_MODEL_COMPARISON.md) (F1 bis F7, Rechnung in neutraler Einheit, keine erfundenen Frankenbeträge); D-14 bleibt offen und wird nicht jetzt gefragt; FE-023.
- *Klärungsbedarf:* keiner jetzt. Der Preisentscheid ist erst sinnvoll, wenn Phase A die Kosten pro aktivem Mitglied gemessen hat.

### B. Produktvorgaben

**6. KI-gestützte Dokumentation** · verstanden: **ja**
- *Interpretation:* KI erstellt aus vorhandenen, belegbaren Informationen einen strukturierten Entwurf; ein Teammitglied prüft, korrigiert und gibt frei. Keine erfundenen Beobachtungen, Zeiten, Leistungen oder Ergebnisse. Quellenbezug, Korrektur, Versionierung, Audit.
- *Umsetzung:* Brief **DOC-AI** (Entwurf bis 2026-11-27, Blueprint M8.1b). Heute IMPLEMENTED: der Bericht entsteht serverseitig aus den erfassten Fakten (F6), wird bei Abschluss mit einer Bestätigung signiert (F7), Versionen sind unveränderlich (F6R), Autorschaft je Beobachtung (OBS1), jeder KI-Vorschlag im AIG1-Protokoll. **Abnahmekriterien DOC-AI** (testbar):
  1. jede Aussage des Entwurfs trägt einen Quellbezug auf einen Datensatz (Ereignis, Beobachtung, Leistung);
  2. ein Prüfer verweigert jeden Entwurf, der eine Zeit, Leistung oder Beobachtung ohne Datensatz enthält oder eine Zahl ändert (Unit- und pgTAP-Test mit absichtlich falschen Entwürfen);
  3. die Freigabe zeigt die Unterschiede zwischen Entwurf und freigegebenem Text, und nur die freigebende Person signiert;
  4. jede Korrektur ist eine neue Version mit Grund; frühere Versionen bleiben lesbar;
  5. Korrekturquote je Agent und Feld im AIG1-Protokoll, Stopp-Regel greift (nie pro Person);
  6. auf realen Daten erst nach D-41; vorher nur synthetisch.
- *Klärungsbedarf:* Echter KI-Test in Phase A braucht O-4. `cra` prüft die Gefahren (weggelassene oder erfundene Beobachtung); `lca` prüft, ob der Entwurf die Zweckbestimmung berührt (Punkt 13).

**7. KI-gestützte Einsatzplanung und Ausfälle** · verstanden: **ja**
- *Interpretation:* Fünf Dinge werden getrennt:
  - **Vorschlag:** System schlägt vor, ein Mitglied bestätigt. Gebaut in PLAN3, in offenen PRs mit grüner CI.
  - **Routineautomatik:** Nur mit ausdrücklichem, widerrufbarem Teammandat. Eine vom Team gesetzte, deterministische Regel teilt einen Routinefall zu, wenn alle Bedingungen erfüllt sind: Qualifikation verifiziert, keine Überschneidung, Kontinuität gegeben. Jede Zuteilung wird aufgezeichnet, das Team wird informiert. Das ist der Schritt „Regeln anwenden“ der verbindlichen Reihenfolge, keine KI-Entscheidung.
  - **Teamkontrolle:** Das Team schaltet ein und aus, setzt die Regeln und widerruft das Mandat.
  - **Übersteuerung:** Jedes Mitglied kann eine Zuteilung mit Grund ändern; das wird aufgezeichnet.
  - **Eskalation:** Bei unklarer Qualifikation, Konflikt, Risiko-Hinweis, Regelverletzung oder ohne Kandidat bleibt der Fall offen. Er ist für das Team sichtbar und geht nach der bestehenden OPS1-Regel weiter.
  - KI ist keine Einsatzleitung: keine Rangliste von Personen, keine Bewertung pro Person.
- *Umsetzung:* PLAN3 (Vorschlag, im Bau); Brief **PLAN4** (Routine unter Teammandat, Entwurf bis 2026-12-04); Blueprint SV-7.
- *Klärungsbedarf:* PLAN3 sagt heute „eine Zuteilung entsteht nur durch Bestätigung einer benannten Person“. PLAN4 ändert das nur für vom Team mandatierte Routinefälle. Vor der Freigabe prüfen `cra` (Qualifikation und Sicherheit) und `lca` (automatisierte Einzelentscheidung gegenüber Mitarbeitenden, Datenschutzgesetz). Das ist kein Founder-Entscheid, sondern ein Gate.

**8. Selbstorganisierte Teams und Qualifikationsprofile** · verstanden: **ja**
- *Interpretation und Zuständigkeiten:*
  - **KI:** entwirft das Profil aus vorab geklärten Anforderungen.
  - **Teammitglied:** prüft und bestätigt das eigene Profil.
  - **Team:** nimmt Kolleg:innen auf (ADM2, IMPLEMENTED) und organisiert die Einsätze selbst; ohne Teammandat teilt NAVORA niemanden automatisch zu und schliesst niemanden wegen eines KI-Urteils aus.
  - **Organisation:** prüft die Nachweise (D-29, nur für reale Personen in Phase B). Ein nicht geprüfter Nachweis erscheint als „nicht verifiziert“, nie als verifiziert.
  - **Product Owner (ich):** schreibt den Brief QUAL1 mit testbaren Abnahmekriterien, holt die Gates (`lca`, `cra`) ein, nimmt ab und achtet darauf, dass kein Ablauf die Selbstorganisation durch eine zentrale Zuteilung ersetzt. Ich entscheide nicht, wer qualifiziert ist und wer welchen Einsatz übernimmt.
  - **Legal & Compliance:** Datenschutz der Profildaten, Arbeitsrecht, automatisierte Einzelentscheidung.
  - **Clinical & Regulatory und Clinical Owner:** Welche Qualifikation für welche Aufgabe nötig ist, ist eine klinische Regel; nur der Clinical Owner gibt sie frei.
- *Umsetzung:* Brief **QUAL1** (Entwurf bis 2026-12-04); bestehend: Qualifikation je Mitglied (ADM1, D-5), „Qualifikation erfasst“ bei Beobachtungen (OBS1).
- *Selbstorganisation bleibt erhalten:* bestätigt. Das Team entscheidet über Aufnahme, Einsätze und Mandate; NAVORA schlägt vor, prüft und zeichnet auf.
- *Klärungsbedarf:* keiner für Phase A.

**9. Automatische Abrechnung und Fehlerprüfung** · verstanden: **ja**
- *Interpretation, Verarbeitungskette:*
  1. bestätigte Einsatz- oder Schichtereignisse;
  2. freigegebener Bericht;
  3. abrechenbarer Fakt (J5, IMPLEMENTED, mit Tarifversion);
  4. Prüfung auf Qualitätssperre (QG1);
  5. Rechnungsentwurf nach versionierten Regeln;
  6. Prüfungen vor dem Versand: fehlende Angaben, Duplikate, Widersprüche, Gültigkeit von Verordnung und Kostenträger;
  7. unklare Fälle werden angehalten und gelistet;
  8. eine Person gibt frei;
  9. Versand, erst in Phase B und erst nach den Tarifregeln (D-18) und `lca`.
  - KI erfindet keine abrechenbare Tatsache; sie darf Auffälligkeiten melden, nie Beträge setzen.
- *Sicherer Start:*
  - **Phase A synthetisch:** NAVORA rechnet gegen eine unabhängig berechnete Referenz derselben synthetischen Fälle; jede Abweichung ist ein Testfehler.
  - **Phase B Shadow Mode:** NAVORA rechnet parallel zur bestehenden Abrechnung des Partners, versendet nichts, und die Abweichungen werden wöchentlich geprüft. Umgestellt wird erst nach einer vom Owner gesetzten Zahl aufeinanderfolgender Monate ohne ungeklärte Abweichung (die Zahl ist eine Hypothese).
- *Umsetzung:* Brief **BILL1** (Entwurf bis 2026-12-11); Kennzahl M-18.
- *Klärungsbedarf:* Die Pflegeheim-Finanzierung (pro Tag und Pflegestufe, kantonale Restfinanzierung in BS und BL) unterscheidet sich von der Spitex-Abrechnung pro Einsatz. Die Regeln sind UNKNOWN und werden nicht erfunden; `lca` und `cra` liefern die Quellen.

**10. KI-Governance / D-35** · verstanden: **ja**
- *Interpretation:* D-35 Regel A bleibt in Kraft; ich hebe sie nicht auf. Ich bereite Optionen vor: einen ausdrücklich geprüften und freigegebenen NAVORA-KI-Pfad gegenüber nicht freigegebenen externen Diensten, mit Rechts-, Datenschutz-, Sicherheits- und Architekturfolgen.
- *Umsetzung:* Paket **D-41** ([`../agents/decisions/D-41.md`](../agents/decisions/D-41.md)), Optionen A bis D, Inputs von `eng`, `cra`, `lca` angefragt; FE-024.
- *Klärungsbedarf:* Der genehmigte Stufenpfad (27.10.) sieht Stufe 1 erst nach drei stabilen Pilotmonaten vor, KI-Dokumentation sogar erst in Stufe 2. Wenn KI-Dokumentation schon im realen Pilot laufen soll, braucht es eine frühere, strengere Freigabe. Das wird mit D-41 vorgelegt, nicht jetzt gefragt.

**11. Versorgungskontexte und Produktreihenfolge** · verstanden: **ja**
- *Interpretation:* Langfristige Vision, gemeinsame Plattform, sektorabhängige Abläufe, simulierter Test und realer Pilot werden getrennt. Wiederverwendung heisst: ein gemeinsamer Datensatz; sektorbezogene Regeln sind versionierte Daten oder ein Sektormodul, nie eine Kopie des Datensatzes.
- *Umsetzung:* Blueprint §1.3; Pflegeheim-Briefs NH-A1 bis NH-A5 (M9.0a).
- *Klärungsbedarf:* erledigt; Phase A simuliert ambulante Pflege und eine Pflegeheim-Abteilung (FE-031).

**12. Pflegeheim, Assessment und interRAI** · verstanden: **ja**
- *Interpretation:*
  - Pflegeheime sind im Umfang; der spätere reale Pilotpartner soll ein Pflegeheim sein.
  - Vorher wird mit einem simulierten Pflegeheim und synthetischen Daten getestet.
  - Ein integriertes Assessment- und Care-Planning-Modell gehört zur Vision. Heute gebaut: die unveränderliche Bedarfsabklärung (ASM1, D-13 B), ohne lizenzierte Inhalte.
  - Ob interRAI-Inhalte verwendet werden dürfen, klärt `lca` anhand der Lizenzbedingungen (D-36). Bis dahin gilt D-36 Option A: interRAI nur beim Namen, keine Items, keine Logik.
- *Umsetzung:* D-24 als vom Owner entschieden erfasst (FE-022); D-25 für BS/BL an `lca`; Blueprint M9.0a/M9.0b.
- *Klärungsbedarf:* `lca` braucht die Lizenzbedingungen von Ihnen (FD-16, ein Fakt). STR-21 (`csa`, hoch: „kein Nutzen für die Pflege gezeigt“) beantworte ich mit dem Phase-A-Design. `csa` prüft das neu.

**13. Ziel: kein Medizinprodukt** · verstanden: **ja**
- *Interpretation:* Das ist die gewünschte Richtung, keine bestätigte Einstufung; ich setze den Prüfauftrag nicht mit einer Founder-Entscheidung gleich. D-34 (A plus C, 27.10.) bleibt: Kern ausserhalb, klinische Intelligenz nur als getrenntes Modul.
- *Umsetzung:* FE-025; Blueprint SV-5.
- *Konflikte, sichtbar gemacht:*
  - Die Zweckbestimmung v2 nennt nur die ambulante Pflege und schliesst „Pflegenotizen interpretieren“ aus. Ein KI-Dokumentationsentwurf fasst Beobachtungen zusammen; ob das „interpretieren“ ist, muss `lca` prüfen.
  - Ein integriertes Assessment mit Auswertungen (z. B. Pflegestufen, Hinweise) kann in die Entscheidungsunterstützung reichen.
  - Pflegeheim-Funktionen sind in v2 nicht beschrieben.
  - **`lca` ist beauftragt** (Prüfauftrag im Paket D-34, Notiz vom 2026-11-06 12:30): Zweckbestimmung v2 und reale Funktionen gegen Pflegeheim, DOC-AI, Assessment und PLAN4. Ein Regulierungsberater wird nur vorgeschlagen, wenn `lca` eine Frage nicht sicher klären kann (Punkt 16).

**14. Daten- und Testvorgabe** · verstanden: **ja**
- *Interpretation:* „Keine echten Daten vorhanden“ ist eine beantwortete Sachfrage und wird nicht mehr gestellt. „Hoher Schutzstandard für Testdaten“ ist eine davon getrennte, dauernde Pflicht:
  - nur synthetische Daten;
  - Datenzugriffsregeln (RLS) und Audit wie in Produktion;
  - keine Kopie aus dem Live-System;
  - Geheimnisse nur in geschützten Speichern;
  - kein KI-Agent mit Zugang zu einer Umgebung mit realen Daten (G-22).
- *Umsetzung:* D-1 als beantwortet erfasst (FE-020); Blueprint „Binding rules“; Founder-Bericht.
- *Klärungsbedarf (kein erneutes Fragen von D-1):* Die Prüfung SR-26 hat im selben Live-Projekt eine fremde Tabelle `orders` mit E-Mail-Adressen einer anderen Anwendung gefunden. Bitte sagen Sie, ob Ihre Aussage diese Tabelle einschliesst (FD-17). Schlüsselrotation und Leaked-Password-Schutz bleiben Handlungen, die nur Sie im Live-System ausführen können.

**15. Pilotphasen** · verstanden: **ja**
- *Interpretation:*
  - Pilotregionen Basel-Stadt und Basel-Landschaft.
  - **Phase A:** fiktiver, simulierter Partner mit synthetischen Daten.
  - **Phase B:** später eine reale Pilotorganisation, nach aktueller Richtung ein Pflegeheim, sobald Produkt und Freigaben bereit sind.
  - Kein echter Partner jetzt.
- *Umsetzung:* D-11 entschieden (FE-019), Phasen FE-021; Blueprint M3 (Partner und Gemeinden aus der Liste), M9 neu gefasst (M9.0 simulierter Pilot), kritischer Pfad; `ROADMAP.md` (Gate 8); Owner-Agenda (Partner nicht gefragt).
- *Klärungsbedarf:* O-7: Ich schlage vor, M9 am 12.03.2027 als „Phase A bestanden + Bereitschaftsakte Phase B“ zu fassen.

**16. InterRAI- und Legal-Auftrag** · verstanden: **ja**
- *Interpretation:* `lca` prüft:
  - die Rechtsgrundlagen und D-22, D-18, D-9, D-4;
  - den Pflegeheim-Pilot (D-25 für BS/BL);
  - die interRAI-Nutzungsrechte (D-36);
  - den Vertragsentwurf;
  - die kantonalen Fragen.
  - Externe Beratung ist keine Vorbedingung für den simulierten Test, nur für Fragen, die `lca` nicht sicher klären kann.
- *Umsetzung:* FE-026; D-25 wieder geöffnet; Owner-Agenda (Rechtsberater nicht mehr Vorbedingung). Fragen, die `lca` bisher als „unresolved: needs adviser“ markiert hat:
  - D-22 (Form ärztlicher Verordnungen);
  - D-9 (Rechtsgrundlage bei der Aufnahme);
  - D-34 (Regulierungsberater, Medizinprodukt);
  - D-40 Fragen 1 und 9 (reale Angehörige, Hinweis an die Klientin bei Widerruf durch das Team);
  - D-33 (Push an Safari/Firefox vor realen Klient:innen).
  - Keine davon blockiert Phase A.
- **`lca` ist beauftragt** (2026-11-06 12:30), je mit Notiz im Paket und Kommentar im Issue: D-22, D-18, D-9, D-4, D-29 (Basel-Stadt und Basel-Landschaft, Pflegeheim), D-25 (Leitung im Pflegeheim), D-36 (welche interRAI-Lizenzbedingungen nötig sind), D-34 (Zweckbestimmung), D-41 (KI-Pfad) und **D-42 neu: Vertragsentwurf für den Phase-B-Pilot mit einem Pflegeheim**.
- *Klärungsbedarf:* Der gespeicherte `lca`-Auftrag beschränkt sich auf Entscheidungspakete; deshalb laufen auch Vertragsentwurf und Pflegeheim-Pilot als Pakete. Die Prompt-Ergänzung liegt in §5.3.

### C. Blueprint, GitHub, Arbeitsbuch

**17. Blueprint V2 aktualisieren** · verstanden: **ja**
- *Umsetzung:* Blueprint auf Version 2.1 gebracht:
  - §1: Vision, Geschäftsmodell, KI-Arbeitsabläufe als Kern, Matrix der Versorgungskontexte, Widersprüche SV-1 bis SV-7;
  - §4: M3, M8.1b, M9.0 und M9.0a/b;
  - §6: kritischer Pfad;
  - §7: Decision Board neu;
  - §10.2: Kennzahlen.
- Widersprüchliche Passagen: §3 unten.

**18. Erfolgsmessung erweitern** · verstanden: **ja**
- *Umsetzung:* Blueprint §10.2 M-15 bis M-21:
  - administrative Minuten pro Besuch bzw. pro Bewohnertag;
  - Dokumentations- und Korrekturzeit;
  - Planungs- und Ausfallkoordination;
  - Abrechnungsfehler und manuelle Ausnahmequote;
  - Kontinuität;
  - Teamautonomie;
  - Sicherheitsindikatoren.
  - Ziele ohne Basismessung sind als **Hypothese** markiert; alles pro Team oder Organisation, nie pro Person.
- *Klärungsbedarf:* keiner.

**19. GitHub und Repository abgleichen** · verstanden: **ja**
- *Umsetzung:* Abgleichstabelle in §3.2 (Issues, PRs, Branches, ADRs, Aufgaben-Prompts, Pläne). Keine gemergte Historie umgeschrieben; alle Änderungen in diesem neuen PR.

**20. Arbeitsbuch finden** · verstanden: **ja**, mit Klärungsbedarf
- *Geprüft:*
  - Repository: Suche nach „Arbeitsbuch“ und „workbook“ in allen Markdown-Dateien, keine Treffer;
  - Projekt-Wissensbasis (Suche): keine Treffer;
  - Ihre 35 Artifacts: keines heisst so. Ein Dokument „Unio – Architecture Review & Implementation Blueprint“ (4.11.) trägt einen anderen Produktnamen; ich habe seinen Inhalt nicht geöffnet und setze es nicht mit NAVORA gleich.
  - **Ein kanonisches NAVORA-Arbeitsbuch habe ich nicht gefunden.** Pfad, Besitzer und Version kann ich deshalb nicht nennen, ohne zu raten.
- *Vorschlag:* Wenn es ausserhalb des Repositorys liegt, nennen Sie mir den Pfad (O-3). Wenn nicht, wird **Blueprint V2.1** das Arbeitsbuch:
  - [`ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md`](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md), Besitzer `po`, Version 2.1;
  - daneben [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) für Entscheide und [`FOUNDER_EXECUTIVE_REPORT.md`](FOUNDER_EXECUTIVE_REPORT.md) für Ihre wöchentliche Sicht;
  - `DELIVERY_PROGRAM.md`, `ROADMAP.md` und `NEXT_CAPABILITY.md` verweisen bereits darauf.

**21. Nachvollziehbare Entscheidungsquelle** · verstanden: **ja**
- *Umsetzung:* [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) v1:
  - FE-001 bis FE-030, je mit ID, Datum, Entscheid, Status, Quelle, Folgeaufgaben, Owner, Abhängigkeiten und ersetzter Aussage;
  - ersetzte Zeilen bleiben stehen;
  - README Regel 10: der neueste Founder-Entscheid übersteuert.
- *Klärungsbedarf:* keiner.

**22. Agentenautonomie** · verstanden: **ja**
- *Interpretation:* Autonom innerhalb des Auftrags: planen, recherchieren, umsetzen, testen, dokumentieren; die eigene Aufgabe im Ziel anpassen und protokollieren. Nicht stillschweigend ändern: Founder-Entscheide, Umfang, Governance, fremde Tickets.
- *Umsetzung:* README Regeln 10 und 11 (gilt für alle Rollen); FE-029; Prompt-Ergänzung für alle Agenten in §5.3.
- *Klärungsbedarf:* Die gespeicherten Prompts kann laut Governance nur der Owner ändern. Ich habe sie gelesen, aber nicht geändert. Ihre Freigabe ist FD-01.

---

## 3. Widersprüche und Abgleich

### 3.1 Widersprüche in Blueprint, Plänen und Paketen (mit Korrektur)

| # | Fundstelle | Widerspruch zur bestätigten Richtung | Korrektur |
|---|---|---|---|
| W-1 | Blueprint V2 §1 „Vision“: „home care now, then hospitals, then nursing homes“ | Pflegeheim ist realer Pilotpartner (FE-021) | **korrigiert** in V2.1 §1 |
| W-2 | Blueprint V2 SV-1, FD-04; Owner-Agenda „Approve Zurich“ | D-11 ist Basel (FE-019) | **korrigiert**; D-11 in *Decided* |
| W-3 | Blueprint V2 FD-03, M3.1, CP-4; Founder-Bericht FD-03; D-1-Paket „treat as real“ | D-1-Sachverhalt beantwortet (FE-020) | **korrigiert**; D-1 in *Decided*; nur Sicherheitshandlungen bleiben |
| W-4 | Blueprint V2 FD-05, FD-06, M3.4, M3.10, §6.3 (Partner bis 11.12., Rechtsberater bis 27.11.) | kein Partner jetzt; Berater keine Vorbedingung (FE-021, FE-026) | **korrigiert**; nach Phase B verschoben |
| W-5 | Blueprint V2 SV-2 „Keep D-24 A“; D-24-Empfehlung A | Pflegeheim im Umfang (FE-022) | **korrigiert**; D-24 in *Decided* |
| W-6 | Blueprint V2 M9 „first real client … 2027-03-12“ | realer Pilot erst in Phase B | **Vorschlag** M9-Neufassung (O-7), als PROVISIONAL eingetragen |
| W-7 | Blueprint V2 FD-13; Owner-Agenda „Approve F3 or F4“ | F3 ist nur Kalkulationsbasis (FE-023) | **korrigiert**; D-14 nicht jetzt gefragt; Vergleich erstellt |
| W-8 | `DELIVERY_PROGRAM.md` M3 Kriterien (D-11, D-12 Partner LOI, D-34 Berater) | wie W-2, W-4 | Verweis auf Blueprint V2.1 (dort gilt die neue Fassung) |
| W-9 | `IMPLEMENTATION_SEQUENCE.md` §7 (Engineering) nur ambulant | Pflegeheim-Schicht fehlt | **an `eng`:** Nachtrag zur Sequenz (Pflegeheim-Abteilung, FE-031) (ich ändere Engineering-Dateien nicht) |
| W-10 | `CARE_OPERATING_MODEL.md` G-3 „Legal entity … pilot canton named“ | Partner in Phase B | Gates erhalten im nächsten PO-Lauf eine Phase-Spalte (A oder B) |
| W-11 | D-12 (27.10.): Zürcher Spitex-Partner, Sunset zum teameigenen Anbieter | Basel, Pflegeheim, Phase B | FE-008 als teilweise ersetzt markiert; Zielbild im Pflegeheim ist O-5 |
| W-12 | D-34 Zweckbestimmung v2: nur ambulante Pflege; „interpretiert keine Pflegenotizen“ | Pflegeheim, KI-Dokumentation | an `lca` (SV-5) |
| W-13 | D-35 Stufenpfad: KI-Dokumentation erst Stufe 2 nach drei Pilotmonaten | KI-Dokumentation als Kern (FE-028) | Paket D-41 (Regel A bleibt) |
| W-14 | PLAN3: Zuteilung nur durch Bestätigung einer benannten Person | Routinefälle mit Teammandat (FE-028) | Brief PLAN4 mit `cra`/`lca`-Gate (SV-7) |
| W-15 | `csa` STR-20 „mit einem Kanton beginnen“ | beide Kantone entschieden | als Restrisiko vermerkt, nicht erneut gefragt |
| W-16 | Founder-Bericht 09:05: 20 offene Entscheide inkl. D-1, D-11, Partner, Berater | wie oben | **korrigiert** (Ausgabe 12:00, 15 Entscheide) |
| W-17 | Blueprint V2 und Founder-Bericht (heute 09:05) beschrieben D-1 als „mögliche reale Daten“ | FE-020 | **korrigiert**; ältere Fassungen bleiben in der Git-Historie |

### 3.2 Abgleich GitHub und Repository (Punkt 19)

| Quelle | Aktueller Status | Widerspruch zur Founder-Richtung | Vorgeschlagene Anpassung | Zuständig | Abhängigkeit | Abnahmekriterium |
|---|---|---|---|---|---|---|
| Issue #816 (Basel, D-11) | offen | erledigt durch FE-019 | nach Merge dieses PRs schliessen, mit Verweis; Arbeitsposten 3 (Region als Konfiguration) als Brief | `po` | – | Issue geschlossen; Brief REG1 in *Next up* |
| Issue #818 (All-in-one, Basler Pflegeheim-Regeln) | offen | jetzt Richtung (FE-022) | Kommentar mit Verweis auf NH-A1–A5 und D-25 | `po` | – | Kommentar gesetzt |
| Issue #817 (IoT-Datenmodell) | offen | keiner (D-39 A: nur Spezifikation) | unverändert | `po` | D-39 | – |
| Issue #820 (STR-20 bis -25) | offen | STR-20 überholt, STR-21 durch Phase-A-Design beantwortet | Antwort im Issue; `csa` prüft neu | `po`, `csa` | – | `csa`-Abschnitt mit Neubewertung |
| Issue #539 (STR-15 Übergabebedingungen C) | offen | Phase B; Zielbild offen (O-5) | als „Phase B“ kennzeichnen | `po` | O-5 | Label oder Kommentar |
| Issue #529 (D-37 interRAI) | offen | keiner | wartet auf Lizenzbedingungen | owner (FD-16) | D-36 | `lca`-Abschnitt nach Erhalt |
| Issue #861 (Merge-Pfad) | offen | keiner | löst sich mit FD-01 | owner | FD-01 | erster Merge eines Engineering-PRs in einem geplanten Lauf |
| Issue #793 (AUT-30, hoch) | offen | keiner | Team-Seite in #883, Operations-Seite in #814 (beide ungemergt) | `po` merged | FD-01 | Issue nach Merge geschlossen |
| Issues #506–#510, #515, #548 (UX S1) | offen | keiner; im abgenommenen UX1 (28.10.) referenziert | im nächsten PO-Lauf gegen UX1/UX2 prüfen und mit Beleg schliessen | `po`, `uxa` | – | jedes Issue geschlossen oder mit Restbefund |
| Issue #884 (UXR-102) | offen | keiner | in PLAN3-17 platziert; nach Merge #888/#891 schliessen | `po` | FD-01 | geschlossen |
| PRs: 12 Engineering grün und freigegeben (#800, #803, #804, PLAN3-Stapel #876–#895), M1-Dokumente #835, #837, AIG1 #814, AN3 #841, ASM1-C6 #815, AIR1 #828; Rollen-PRs #892, #860, #850 | offen, rund 35 | keiner; alles synthetisch und ambulant | Merge nach FD-01; #872 (durch #876 ersetzt) schliesst `eng` | `po`, `eng` | FD-01 | Merge-Warteschlange ≤ 3 (M-02) |
| PRs #806, #809, #840 | Konflikte | keiner | `eng` löst Konflikte | `eng` | – | grün und konfliktfrei |
| Branches | 672 entfernte Branches (u. a. 184 `po/`, 94 `docs/`, 91 `feat/`, 82 `gov/`, 89 `lca/`) | keiner | Aufräumen gemergter Branches vorschlagen (nicht gelöscht; Löschen braucht Ihre Freigabe) | `eng` Vorschlag | – | Liste gemergter Branches im Journal |
| ADRs | ADR-001 bis ADR-131 auf `recovery/main`, ADR-132 bis ADR-156 in offenen PRs | ADR-145 ff. (PLAN3 nur Vorschlag) vs. Routine mit Teammandat | neuer ADR mit PLAN4 | `eng` | PLAN4 | ADR akzeptiert |
| Pläne: `DELIVERY_PROGRAM.md`, `IMPLEMENTATION_SEQUENCE.md`, `ROADMAP.md`, `NURSING_HOME_TRANSFORMATION.md`, `CARE_OPERATING_MODEL.md`, `STRATEGY.md` | gemergt | W-8 bis W-11 | `ROADMAP.md` nachgeführt (dieser PR); `NURSING_HOME_TRANSFORMATION.md` (NH0–NH9) wird Eingang für NH-A1–A5; Sequenz-Nachtrag `eng`; `STRATEGY.md` `csa` | `po`, `eng`, `csa` | – | jeder Plan verweist auf Blueprint V2.1 |
| Aufgaben-Prompts (7 geplante Aufgaben) | gelesen, nicht geändert | siehe §5.3 | Ergänzung je Aufgabe | owner (FD-01) | – | Prompts enthalten den Founder-Block |

---

## 4. Offene Entscheidungen (nur echte Founder-Fragen)

| ID | Frage | Optionen | Auswirkungen | Empfehlung |
|---|---|---|---|---|
| ~~O-1~~ **entschieden** (FE-031: ambulant + Pflegeheim) | Was wird in Phase A simuliert? | (a) nur ein simuliertes Pflegeheim; (b) ambulante Pflege (gebaut) **und** eine simulierte Pflegeheim-Abteilung; (c) ambulante Pflege in Phase A, Pflegeheim erst in Phase B | (a) lässt 47 gebaute Fähigkeiten ungeprüft und verlangt die ganze Pflegeheim-Schicht bis Februar; (b) prüft das Gebaute und baut eine Abteilung dazu, grösster Lernwert; (c) schnell, aber der reale Pflegeheim-Pilot startet ungetestet | (b) gewählt am 2026-11-06 |
| **O-2** (FD-24) | Was heisst „Privatpersonen“? | Varianten (a)–(e) in Punkt 4 | bestimmt, ob NAVORA Selbstzahler-Verträge, Haushalte als Arbeitgeber oder Angehörige als Nutzer abbilden muss | (a) Selbstzahlende und (b) Angehörige als Anfragende in die Vision; (c) Haushalte als Arbeitgeber erst nach eigener Rechtsprüfung; nichts davon in Phase A |
| **O-3** (FD-26) | Wo liegt das NAVORA-Arbeitsbuch? | Pfad nennen; oder Blueprint V2.1 ist das Arbeitsbuch | ohne Antwort zwei mögliche Arbeitsstände | Blueprint V2.1 als Arbeitsbuch, falls kein anderes existiert |
| **O-4** (FD-22) | Darf Phase A einen KI-Anbieter **nur mit synthetischen Daten** nutzen? | (a) nein, KI-Abläufe werden mit Regel-Ersatz getestet; (b) ein CH/EU-Anbieter mit Vertrag, nur synthetische Daten, über den NAVORA-Orchestrator; (c) selbst betriebenes Modell | (a) kein echter Test von Dokumentationsentwurf und KI-Prüfung, KI-Kosten bleiben unbekannt; (b) echter Test und Kostenmessung, Vertrag und Kosten nötig, D-35 Regel A unverändert; (c) Betriebsaufwand | **(b)**, mit `lca`-Prüfung des Vertrags vor dem ersten Aufruf |
| **O-5** (FD-25) | Gilt das D-12-Ziel „teameigener Anbieter nach Sunset“ auch im Pflegeheim? | (a) ja, Abteilungen gründen später eigene Träger; (b) nein, das Pflegeheim behält die Bewilligung, die Abteilungen arbeiten selbstorganisiert; teameigene Anbieter bleiben Ziel in der ambulanten Pflege | prägt Vertragsentwurf (D-38) und Phase-B-Gespräche | **(b)**; nicht dringend (vor Phase B) |
| **O-6** (FD-02) | Klinische Fachprüfung schon in Phase A? | (a) Clinical Owner erst vor Phase B; (b) jetzt eine klinische Fachperson (z. B. Pflegeexpertin aus der Langzeitpflege) für die Plausibilität des simulierten Pflegeheims, Clinical Owner bis Phase B | (a) Gefahr, Pflegeheim-Abläufe falsch zu modellieren; (b) Aufwand und Auswahl durch Sie | **(b)** |
| **O-7** (FD-23) | M9 neu fassen? | (a) M9 = Phase A bestanden + Bereitschaftsakte Phase B (12.03.2027); (b) M9 bleibt „erste reale Person“, Datum offen | (b) misst etwas, das nach Ihrer Richtung nicht vor Phase B passiert | **(a)** |
| FD-01 | Prompt-Änderungen (§5.3) inkl. Merge-Schritt | freigeben / nicht freigeben | ohne Freigabe arbeiten die Agenten mit Prompts, die Ihrer Richtung widersprechen | freigeben |

Weitere Owner-Fragen (D-7, D-8, D-2, D-26, SR-26, D-36, Website) bleiben unverändert im Decision Board; sie sind keine Folge dieses Schreibens.

---

## 5. Weiterarbeit

### 5.1 Was ich ohne weitere Bestätigung fortsetze (durch Ihre Richtung gedeckt)

| # | Arbeit | Owner | Abhängigkeit | Abnahmekriterium | Termin |
|---|---|---|---|---|---|
| 1 | Diese Bestätigung, Entscheidungsliste, Blueprint 2.1, Founder-Bericht, Preisvergleich, D-41, Rechtsaufträge | `po` | – | gemergt mit grüner CI | 2026-11-06 |
| 2 | Issues gemäss §3.2 kommentieren oder schliessen (#816, #818, #820, #539; UX S1 prüfen) | `po` | dieser Merge | jedes Issue mit Verweis | 2026-11-13 |
| 3 | Gates G-1 bis G-25 nach Phase A/B kennzeichnen | `po` | – | jede Gate-Zeile mit Phase | 2026-11-13 |
| 4 | Briefs WEB1, AIO1 | `po` | – | genehmigt, Abnahmekriterien testbar | 2026-11-20 |
| 5 | Basel-Prüfung D-18, D-25, D-9, D-4, D-29 | `lca` | – | Abschnitte signiert | 2026-11-20 |
| 6 | D-41 und D-42 Inputs; `lca`-Neuprüfungen D-22, D-18, D-9, D-4, D-29, D-34, D-36 | `eng`, `cra`, `lca` | – | Abschnitte signiert | 2026-11-27 |
| 7 | Brief MOB1; Pflegeheim-Briefs NH-A1 bis NH-A5 (FE-031); Brief DOC-AI | `po` | – | Entwürfe mit `cra`/`lca`-Anfrage | 2026-11-27 |
| 8 | Briefs OPS2, HAND2, PLAN4, QUAL1 | `po` | – | Entwürfe; PLAN4 mit Gate | 2026-12-04 |
| 9 | D-41 an Sie (wenn Inputs da) | `po` | 6 | Paket `awaiting-approval: owner` | 2026-12-04 |
| 10 | Brief BILL1 (synthetisch, dann Shadow Mode) | `po` | Basel-Prüfung | Entwurf | 2026-12-11 |
| 11 | Pflegeheim-Schicht auf synthetischen Daten | `eng` | 7 | Briefs erfüllt, CI grün | 2027-01-29 |
| 12 | Phase A simulierter Pilot (M9.0) | `po`, `eng`, `cra`, `uxa` | 11, M2, M6-Kern | vier synthetische Wochen, Kennzahlen M-15 bis M-21 erhoben | 2027-02-26 |
| 13 | M9 Phase A bestanden + Bereitschaftsakte Phase B | `po` | 12, O-7 | jedes partnerunabhängige Gate geschlossen | 2027-03-12 |

Termine ab Punkt 7 sind PO-Schätzungen (Zuversicht gering). Sie hängen am Merge-Pfad (FD-01). Engineering liefert heute 1–2 PRs pro Stunde; der Engpass ist der Merge.

### 5.2 Was ich anhalte, bis eine Entscheidung oder ein Gate vorliegt

- KI auf realen Daten: gesperrt (D-35 Regel A) bis D-41.
- Echter KI-Test in Phase A: wartet auf O-4.
- PLAN4-Routineautomatik: wartet auf `cra`- und `lca`-Gate.
- interRAI-Inhalte: warten auf die Lizenzbedingungen (FD-16) und `lca`.

### 5.3 Vorgeschlagene Änderungen der Agenten-Prompts (Freigabe FD-01)

**Für alle sieben geplanten Aufgaben** (PO, Engineering, Clinical & Regulatory, Legal & Compliance, UX/UI, AI & Automation, Chief Strategy; dazu der wöchentliche Engineering-Status), nach dem Lesen von `docs/agents/README.md` einzufügen:

> **Founder-Richtung (2026-11-06):** Lies `docs/product/FOUNDER_DECISIONS.md` und `docs/product/ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md`. Der neueste Founder-Entscheid übersteuert ältere Dokumente und diesen Prompt (README-Regel 10). Arbeite autonom innerhalb deines Auftrags (README-Regel 11); ändere nie stillschweigend Founder-Entscheide, Umfang, Governance-Regeln oder fremde Items. Pilotregionen: Basel-Stadt und Basel-Landschaft. Phase A: simulierter Partner (Pflegeheim) mit synthetischen Daten; Phase B: realer Pilot, nach aktueller Richtung ein Pflegeheim. Pflegeheime sind im Umfang. D-35 Regel A gilt: keine Klienten- oder Personaldaten an einen KI-Dienst.

**Gezielte Korrekturen je Aufgabe (Widersprüche zum gespeicherten Prompt):**

| Aufgabe | Gespeicherter Text | Korrektur |
|---|---|---|
| Product Owner | „home care now, then transitions … then nursing homes“; „You run hourly“ (Zeitplan: täglich 06:00); Schritt A ohne Engineering-Merge | Versorgungskontexte gemäss FE-027; Zeitplan oder Text angleichen (Vorschlag: stündlich zu Minute 39); Merge-Absatz aus `PO_MERGE_PROCESS.md` §3 (1); freitags `FOUNDER_EXECUTIVE_REPORT.md` neu schreiben |
| Clinical & Regulatory | „You run every 3 hours“ (Zeitplan: alle 4 Stunden); „nursing homes / LTCF later“ | Text angleichen; Pflegeheim in Phase A simuliert |
| Legal & Compliance | „You run hourly“ (Zeitplan: täglich 04:39); Arbeit nur an Entscheidungspaketen | Text angleichen; Auftrag nach FE-026 (Pflegeheim-Pilot, interRAI-Rechte, Vertragsentwurf, BS/BL), externe Beratung nur für ungelöste Fragen |
| AI & Automation, UX/UI | „nursing homes later“ | Pflegeheim in Phase A simuliert |
| Chief Strategy | letzter Lauf am 2026-11-02 **fehlgeschlagen (Nutzungsgrenze)**, nächster am 2026-11-09; „pilot partner … destination team-owned provider (D-12)“ | Zielbild gemäss O-5; Lauf prüfen |
| Engineering | keine inhaltlichen Widersprüche | nur der gemeinsame Block; Sektorunterschiede als Konfiguration bauen |
| Alle | Supabase- und Render-Konnektoren sind jeder Aufgabe angehängt | entfernen, wo nicht gebraucht (produktionsnaher Schutz, G-22); Agenten berühren das Live-Projekt nie |

Die alte, deaktivierte Aufgabe „NAVORA hourly product review“ bleibt deaktiviert.
