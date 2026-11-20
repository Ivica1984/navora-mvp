# HEIM1 · Der Arbeitsplatz der Heimleitung: Vorlage für Founder und PO (Version 2)

**Autor:** `eng`, 2026-11-20 ca. 15:20. Version 2 ersetzt Version 1 von 15:05 und beantwortet den Founder-Brief «Pflegeheimansicht grundlegend weiterentwickeln» Punkt für Punkt.
**Status:** Vorschlag. **Nichts davon ist gebaut, nichts geht in einen laufenden PR.** Der PO entscheidet Umfang und Reihenfolge. Seine Sicht fehlt in dieser Fassung noch (Abschnitte mit **PO:** markiert).
**Lesart:** Der Haupttext ist ohne Code-Kenntnisse lesbar; technische Belege stehen im Anhang.

| Kennzeichnung | Bedeutung |
|---|---|
| **auf Staging nachgewiesen** | in der echten Staging-App automatisch durchgeklickt |
| **nur im Code** | gebaut und in der CI getestet, auf Staging nicht durchgeklickt |
| **fehlt** | nicht gebaut |
| ESTIMATE | eine Schätzung, keine Zusage |
| OPEN | ein Entscheid fehlt |

---

## 1. Ist-Stand: Was ein Heim heute kann

**Auf Staging nachgewiesen** (Prüflauf vom 20.11., 14:27, 4 von 4 grün):
- Als Heim einen Dienst bestellen (Datum, Zeit, Postleitzahl, Stufe, Tätigkeiten).
- Ein anderes, nicht passendes Team sieht den Auftrag nicht.
- Ein passendes Team übernimmt, und das Heim liest «Gedeckt · Person benannt, geprüft für HF».
- Ein Nachtdienst 22–07 Uhr erscheint bei der Pflegekraft als ein Einsatz.
- Die Pflegekraft unterschreibt den Bericht, das Team sendet die Rechnung, und das Heim liest sie unter «Rechnungen».

**Nur im Code**, in der CI geprüft, auf Staging nicht durchgeklickt:
- Ein Team lehnt ab.
- Eine benannte Kollegin muss die Übernahme bestätigen.
- «Ich kann nicht» gibt den Dienst wieder frei; das Heim liest «Nicht mehr gedeckt».
- Eine Pflegekraft fällt nach der Zusage aus. Dann wird nur das Team benachrichtigt, das Heim sieht nur die geänderte Statuszeile.
- Weitere Prüfungen, jede mit eigener Meldung:
  - Beginn in der Vergangenheit;
  - Postleitzahl ausserhalb der Region;
  - Stufe passt nicht zur Tätigkeit;
  - Distanzvorgabe.
- Korrektur eines Berichts: Die Rechnung wird ungültig.

**Fehlt:**
- Startseite, Wochenansicht, Stationen, eigener Dienstplan;
- Ändern und Stornieren;
- Benachrichtigungen an das Heim;
- Kosten- und Monatsübersicht, Export;
- Vorlagen für wiederkehrende Dienste;
- mehrere Personen für einen Dienst in einem Schritt;
- jede KI im Heimablauf.

**Wichtig:** Das Datenmodell kennt heute **keine Station**. Ein Auftrag gehört zum Heim als Ganzes. Alles «nach Station» braucht diese Grundlage zuerst. Sie ist im Paket BK-d «Station bestellt» vorgesehen.

## 2. Zielnavigation und Startseite

### Zielnavigation

Neun Register sind das Zielbild. Gebaut wird eines nach dem anderen, und nur wenn es eine Aufgabe löst.

| Register im Zielbild | Empfehlung `eng` | Begründung |
|---|---|---|
| **Übersicht** (Startseite) | **zuerst** | beantwortet «wo muss ich handeln?»; nutzt die vorhandenen Daten |
| **Externe Aufträge** | **zuerst**, mit «Auftrag erfassen» als Aktion | ersetzt die heutige Einzelformular-Seite |
| **Kosten & Rechnungen** | früh | die Rechnungsdaten gibt es seit BK-f |
| **Einstellungen** | vorhanden | später Stationen und Nutzer |
| **Mitteilungen & Ausnahmen** | zunächst **in der Übersicht** («Jetzt zu entscheiden») | ein eigenes Register lohnt sich erst bei vielen Meldungen |
| **Dienstplanung** (eigenes Personal) | später, eigener Vertrag; **vorher** ein schlanker Bedarfsplan (§3, Idee 1) | eigenes B2B-Produkt, mit Personaldaten des Heims |
| **Teams & Kompetenzen** | **nicht als eigenes Register**, sondern im Auftrag selbst | ein Register mit Teamfähigkeiten verrät kleine Teams und Preise anderer Teams (Wettbewerb, Datenschutz) |
| **Pflegedokumentation**, **Angehörige** | nur sichtbar, wenn das Modul gebucht ist | eigene B2B-Module mit eigenen Regeln |

### Startseite

Die Startseite folgt deinem Entwurf, mit zwei Korrekturen.

- **Heute und nächste 7 Tage**
  - Je Dienst ein Zustand aus der Statusleiter in §5.
  - Zahlen sind immer Links auf die Aufträge dahinter.
- **Jetzt zu entscheiden**
  - Nur Fälle, die das Heim lösen kann, jeweils mit einem Knopf:
    - ungedeckt und Beginn naht;
    - Besetzung fiel weg;
    - Rechnung erhalten.
- **Externe Aufträge:** offen · Angebot gesendet · Person bestätigt noch · gedeckt · durchgeführt · abgerechnet.
- **Kosten dieses Monats:** in Spalten getrennt (§7), nie zusammengezählt.

**Korrektur 1:** Den Zustand «**Team prüft**» aus deinem Entwurf kennt NAVORA nicht. Wir wissen, dass ein Angebot gesendet wurde, aber nicht, ob ein Team es gerade ansieht. Ihn anzuzeigen hiesse, einen Zustand zu erfinden. Ehrlich ist «Angebot an 3 Teams gesendet, noch keine Übernahme».

**Korrektur 2:** «**Gefährdet**» zeigen wir nur, wo es einen belegten Grund gibt:
- die Übernahme fiel weg;
- die benannte Person fällt aus;
- die Kollegin hat nicht bestätigt;
- der Auftrag ist kurz vor Beginn noch offen.

Ab wann «kurz vor Beginn» gilt, ist OPEN (`cra`; Simulationsvorgabe heute 240 Minuten, nicht freigegeben). Ohne belegten Grund gibt es keine Warnfarbe und keine beruhigende Kennzahl.

## 3. Wochenablauf: von der Planlücke bis zur Rechnung

**Fall (synthetisch):**
- «Testheim Rhein», Station 1 und Station 2, Früh-, Spät- und Nachtdienst.
- Für Station 2 ist am Mittwochfrüh eine Soll-Besetzung von 3 Personen eingetragen, eingeplant sind 2, weil eine Mitarbeiterin abwesend ist.

| # | Was passiert | Was die Heimleitung sieht | Was im Hintergrund geschieht | Wer entscheidet | Stand |
|---|---|---|---|---|---|
| 1 | Wochenplan öffnen | Raster Tag × Dienst je Station: eigene Besetzung und externe Aufträge getrennt | Lesen aus Bedarfsplan und Aufträgen | – | fehlt |
| 2 | Lücke wird sichtbar | Mi früh, Station 2: «Soll 3 · geplant 2 · 1 offen» | feste Regel: Soll minus geplant | – | fehlt |
| 3 | Anforderungen des Dienstes | Zeit, Station, typische Tätigkeiten und Stufe aus der hinterlegten Dienstvorlage | Vorlage je Dienst und Station | Heim hat sie früher festgelegt | fehlt |
| 4 | «Externen Bedarf prüfen» | Auftragsentwurf mit allen bekannten Angaben vorausgefüllt; nichts muss neu getippt werden | Entwurf mit Verweis auf die Lücke, **nicht gesendet** | – | fehlt |
| 5 | Ergänzung in eigenen Worten | Feld «Was ist sonst wichtig?» → KI schlägt Felder vor, jedes markiert «aus Ihrem Text vorgeschlagen» | Modell strukturiert, feste Regeln prüfen danach | – | fehlt (geplant BK-d) |
| 6 | Harte Voraussetzungen | «Geprüft: Region, Stufe, Tätigkeitsnachweis, eingetragene freie Zeit», oder ehrlicher Nullfall mit Grund | feste Regel (vorhanden) | – | nur im Code (intern), Anzeige fehlt |
| 7 | Bestätigen & Absenden | Zusammenfassung, dann «Angebot an 3 Teams gesendet» | Angebote an passende Teams | **Heim** | nachgewiesen (ohne Anzahl) |
| 8 | Team übernimmt | «Ein Team hat übernommen; Person bestätigt noch», dann «Gedeckt» | Übernahme, Bestätigung der Person | **Team** (niemand teilt für ein Team ein) | nachgewiesen / nur im Code |
| 9 | Im Plan aktualisiert | Mi früh, Station 2: «Soll 3 · 2 eigene · 1 extern gedeckt» | Plan liest den Auftragsstatus | – | fehlt |
| 10 | Ausfall | Startseite: «Mi früh Station 2: Besetzung weggefallen, Angebot geht wieder an Teams» + Mitteilung | vorhandenes Signal, neu auch an das Heim | Team besetzt neu; **Heim** entscheidet, ob es selbst handelt | Signal nur ans Team |
| 11 | Durchgeführt | «Durchgeführt · Bericht unterschrieben 15:32» | Bericht | Pflegekraft | nachgewiesen |
| 12 | Rechnung | Rechnung beim ursprünglichen Dienst, Monatsübersicht | Rechnung des Teams | **Team** sendet | nachgewiesen (ohne Bezug zum Plan) |

## 4. Das Auftragsformular einfacher machen

Bewertung deiner Vorschläge:

- **«Was benötigen Sie und wann?» als erste Eingabe: ja.** Zuerst Tag, Zeit und Station, dann «Freitext oder Formular». Stufe und Tätigkeiten kommen danach, aber nicht versteckt.
- **KI-Entwurf aus Text, später Diktat: ja.** Jedes vorgeschlagene Feld ist markiert und muss bestätigt werden. Fehlendes bleibt leer mit «bitte angeben»; das Modell rät nicht. Diktat braucht einen zweiten Anbieter für die Spracherkennung und kommt darum später (Founder-Entscheid, §10).
- **Stufe:** NAVORA rät die Stufe nie, weder per KI noch durch eine «niedrigere Stufe genügt»-Empfehlung.
  - Eine feste Regel kann zeigen: «Für die gewählten Tätigkeiten verlangt die Qualifikationsmatrix mindestens FaGe.»
  - Die Matrix ist aber noch **nicht klinisch freigegeben**. Ob sie dafür als Hinweis dienen darf, entscheidet `cra` beziehungsweise der Clinical Owner (OPEN).
- **Tätigkeitsliste:** nach Aufgabenbereichen gruppiert und aufklappbar, gewählte Tätigkeiten immer sichtbar in der Zusammenfassung. Die Gruppierung selbst ist eine fachliche Frage (`cra`), der Wortlaut gehört `uxa`.
- **Mehrere Personen** («2× FaGe»): technisch als **2 verbundene Aufträge**, damit jede Übernahme und jede Rechnung sauber einer Person gehört. Das Heim sieht einen Dienst mit «1 von 2 gedeckt».
- **Vorlagen für wiederkehrende Dienste: ja.** Die heutigen Dienstbezeichnungen («Frühdienst») sind ein Anfang; sie dienen bisher nur der Anzeige.
- **Zusammenfassung vor dem Absenden:** Datum, Zeit, Station, Anzahl Personen, Tätigkeiten, Stufe, offene Angaben.
  - **Preisgrundlage:** Vor der Übernahme gibt es **keinen Preis**, denn jedes Team setzt seinen eigenen.
  - Die Zusammenfassung sagt das offen: «Preis legt das übernehmende Team fest; Sie sehen ihn bei der Übernahme.»

## 5. Teamverfügbarkeit ehrlich darstellen: die Statusleiter

Jeder Auftrag steht auf genau einer Stufe, und jede Stufe hat einen belegten Grund in den Daten:

1. **Geprüft beim Absenden.** «Region, Stufe, Tätigkeitsnachweis und eingetragene freie Zeit geprüft, Stand 20.11. 14:31.»
   - Der Zeitstempel ist der wirkliche Prüfzeitpunkt; NAVORA speichert das Prüfergebnis schon heute einmal beim Absenden.
   - Eine spätere Regeländerung kann so nicht nachträglich das Bild verändern.
2. **Angebot gesendet**, an 3 Teams; noch keine Übernahme.
3. **Übernommen, Person bestätigt noch.**
4. **Gedeckt**, Person benannt und geprüft für die Stufe.
5. **Gefährdet / nicht mehr gedeckt**, mit Grund.
6. **Durchgeführt**, Bericht unterschrieben.
7. **Abgerechnet**, Rechnung erhalten.

**Kein Treffer:**
- «Derzeit findet NAVORA in Ihrer Region kein Team, das Stufe und Tätigkeiten erfüllt und für diese Zeit frei eingetragen ist.»
- Dazu der Grund ohne Personen, zum Beispiel «keine Person mit Nachweis für Wundversorgung frei».
- Danach: Der Bedarf **bleibt als ungedeckt auf der Startseite stehen**. Teams sehen ihn, sobald jemand frei wird. Das Heim kann eine andere Zeit wählen.

**Kompetenzen verständlich, ohne Personaldaten:** Das Heim sieht, **was geprüft wurde**, nicht wer. Keine Lebensläufe, keine Namen vor der Übernahme, keine Prozentzahl. Nach der Übernahme sieht es Team und benannte Person, wie heute.

## 6. Aufträge, Änderungen und Benachrichtigungen

- **Ordnung:** Heute / Kommend / Offen / Erledigt; Filter nach Station (sobald es Stationen gibt), Datum und Status. Das ist eine reine Anzeige der vorhandenen Daten.
- **Benachrichtigungen an das Heim:**
  - «übernommen»;
  - «Besetzung weggefallen»;
  - «bald beginnender Dienst noch offen», wobei die Schwelle OPEN ist.

  Der Weg dafür besteht schon für Teams und wird um den Empfänger «Heim» erweitert. Welche Angaben eine Mitteilung an ein Heim enthalten darf, prüft `lca`.
- **Ändern und Stornieren** als Ablauf mit vier Zeitpunkten. Ein Auftrag wird nie gelöscht; Heim und Team sehen immer denselben Zustand.

| Zeitpunkt | Was geschieht | Wer erfährt es | Offen |
|---|---|---|---|
| vor der Zusage | Angebot wird bei allen Teams zurückgezogen; eine Änderung wird neu geprüft und neu angeboten | Teams mit dem Angebot | – |
| nach der Zusage | Übernahme endet mit Grund «vom Heim storniert». Ändert sich Zeit, Stufe oder Tätigkeit, wird **die benannte Person neu geprüft**; besteht sie nicht, entsteht ein neues offenes Angebot | Team und Person | Ausfallentschädigung, Vertragsfolge: `lca`/`owner` |
| kurz vor Beginn | wie oben, Kennzeichen «kurzfristig», sofort Mitteilung | Team und Person sofort | was «kurzfristig» heisst, ob Kosten anfallen: `lca`/`owner` |
| nach Einsatzbeginn | kein Stornieren; das Heim meldet «Einsatz beenden», die Pflegekraft schliesst fachlich ab, der Bericht bleibt Pflicht | Pflegekraft direkt | Abbruch eines laufenden Einsatzes: `clinical` |

## 7. Kosten und Rechnungen

Die Monatsübersicht hat fünf Spalten, die nie zusammengezählt werden:

| Spalte | Woher | Vorhanden? |
|---|---|---|
| **bestellt (Stunden)**: ohne Betrag, weil vor der Übernahme kein Preis existiert | Aufträge | Daten ja, Anzeige fehlt |
| **vereinbart**: Stunden × Preis des übernehmenden Teams | Übernahme (Preis wird dort festgehalten) | Daten ja (BK-f), Anzeige fehlt |
| **durchgeführt, bestätigt**: Minuten aus dem unterschriebenen Bericht | Bericht | Daten ja, Anzeige fehlt |
| **in Rechnung gestellt** | gesendete Rechnungen des Teams | **nachgewiesen** (Einzelliste) |
| **Klärung / Korrektur**: ungültig nach Berichtskorrektur, angehalten, Zeiten weichen ab | Rechnungsstatus aus BK-f | Daten teilweise, Anzeige fehlt |

- **Export:** eine CSV-Datei je Monat für die Buchhaltung des Heims.
- **Geldflüsse bleiben getrennt.** Diese Ansicht zeigt nur die Beträge der Teams. NAVORA erscheint hier nicht: keine Provision, kein Zahlungsweg (FE-078). Plattformgebühr und B2B-Lizenzen haben eigene Abrechnungen.

## 8. Innovationsvorschläge, priorisiert

Massstab: weniger Aufwand bei verlässlicheren Entscheidungen.

**1 · Schlanker Bedarfsplan ohne Personaldaten: Soll und geplant je Station und Dienst.** *(stärkste Wirkung, neu)*
- **Idee:** Das Heim trägt je Dienst und Station nur Zahlen ein: «Soll 3, geplant 2». Daraus entstehen Lücken und mit einem Tipp ein Auftragsentwurf. Erst später kommt die volle Dienstplanung mit Namen.
- **Was entfällt:** das Abtippen der Lücke ins Formular und das Suchen, wo es fehlt; das gilt für Heimleitung und Dienstplanerin.
- **Selbstorganisation:** Teams sehen Bedarf früher.
- **Aufwand:** mittel (zwei Tabellen, eine Wochenansicht, ein Knopf). Betriebskosten gering, keine KI nötig.
- **Neue Fehlerquelle:** falsche Zahlen erzeugen falsche Entwürfe. Es wird darum nie automatisch gesendet.
- **Warum zuerst:** Wochenansicht, «Lücken», «Lücke → Entwurf» und die Vorausschau brauchen alle diese Grundlage. Ohne Namen gibt es kaum Personaldaten des Heims; der Datenschutzaufwand ist klein (`lca` bestätigt).
- **Kleinster Test:** eine synthetische Woche, zwei Stationen, eine Lücke. Erwartet sind genau ein Entwurf mit Verweis auf die Lücke und keiner bei voller Besetzung.

**2 · Vorlagen aus wiederkehrenden Diensten.**
- **Idee:** Bestellt ein Heim denselben Dienst mehrmals (gleicher Wochentag, gleiche Zeit, gleiche Anforderungen), bietet NAVORA ihn als Vorlage an. Daraus wird «Woche kopieren».
- **Was entfällt:** wöchentliches Neuerfassen.
- **Aufwand:** klein, feste Regel, keine KI.
- **Neue Fehlerquelle:** eine veraltete Vorlage. Jede Vorlage zeigt deshalb, wann sie zuletzt bestätigt wurde.
- **Kleinster Test:** drei gleiche synthetische Aufträge ergeben einen Vorlagenvorschlag; zwei ergeben keinen.

**3 · Leistungsbestätigung aus dem unterschriebenen Bericht.**
- **Idee:** Zur Rechnung sieht das Heim: Zeit, Tätigkeiten, unterschrieben wann, ohne Pflegetext.
- **Was entfällt:** Telefonnachfragen und manuelles Abgleichen von Rechnung und Einsatz.
- **Aufwand:** klein, nur lesend.
- **Neue Fehlerquelle:** welche Pflegeinhalte das Heim sehen darf. Bis `lca` entscheidet: nur Zeit und Tätigkeitscodes.
- **Kleinster Test:** nach dem Rechnungspfad stimmen Minuten und Tätigkeiten der Bestätigung mit dem Bericht überein, ohne Personennamen.

**4 · Freiwillig gemeldete Teamkapazität.**
- **Idee:** Ein Team meldet «Di–Do nachmittags 1 HF frei»; beim Erfassen sieht das Heim «zu dieser Zeit hat ein Team Kapazität gemeldet», ohne Namen.
- **Was entfällt:** Absagen und Leerlauf.
- **Selbstorganisation:** hoch.
- **Aufwand:** klein bis mittel.
- **Neue Fehlerquelle:** eine gemeldete Kapazität wird als Zusage missverstanden. Sie erlischt darum automatisch, und der Text sagt «keine Zusage». Wettbewerbsfrage zwischen Teams: `lca`.
- **Kleinster Test:** eine Meldung im Zeitfenster ergibt den Hinweis; ausserhalb keinen.

**5 · Live-Status ohne Neuladen.**
- Erst sinnvoll, wenn die Statusleiter (§5) stimmt.
- Aufwand mittel; der Datenbankanbieter bietet das an, es kostet aber dauerhaft Verbindungen.
- Kleinster Test: Ein Team übernimmt, und die offene Startseite zeigt es ohne Neuladen.

## 9. Empfohlene Baufolge

Ein abnahmefähiges Paket nach dem anderen, jedes mit eigenem Staging-Prüfpfad.

**Kritik an deinem Reihenfolge-Vorschlag:**
- Deine Schritte 2 (Wochenansicht mit **Lücken nach Station**) und 3 (**Lücke → Entwurf**) hängen von zwei Dingen ab, die in deiner Liste erst am Ende kommen:
  - **Stationen**, die es im Datenmodell heute nicht gibt;
  - eine **Planung des eigenen Personals**.
- Ohne sie kann eine Wochenansicht nur externe Aufträge zeigen, keine Lücken.
- Darum ziehe ich Stationen (BK-d) und den schlanken Bedarfsplan (Idee 1) **vor** die Wochenansicht.

| # | Paket | Neu auf Staging bedienbar (Rolle) | Abhängigkeit | ESTIMATE |
|---|---|---|---|---|
| – | STAB1 (beschlossen) | nichts Sichtbares; sichere Grundlage | – | 2–3 Läufe |
| – | AI1 (beschlossen): KI-Berichtsentwurf | **Pflegekraft:** Berichtsentwurf von Claude, vor der Unterschrift ändern | Founder-Einstellung Schlüssel und Kostengrenze | 3–5 Läufe |
| 1 | **BK-d: Station + Auftrag aus einem Satz** | **Heim:** Station wählen, Bedarf in einem Satz schreiben, vorgeschlagene Felder prüfen, bestätigen, senden. **Erste echte KI im Heimablauf.** | AI1 | 4–6 Läufe |
| 2 | **HEIM-1: Startseite + Register «Externe Aufträge»** | **Heim:** Startseite mit «Jetzt zu entscheiden», Statusleiter, ehrlicher Nullfall, Ordnung und Filter | BK-d (Stationen) | 3–4 Läufe |
| 3 | **Mitteilungen an das Heim** | **Heim:** Mitteilung bei Übernahme und bei weggefallener Besetzung | HEIM-1; `lca` zum Inhalt | 2–3 Läufe |
| 4 | **Bedarfsplan + Wochenansicht + Lücke → Entwurf** (Idee 1, mit Vorlagen Idee 2) | **Heim:** Woche sehen, Lücke erkennen, mit einem Tipp Entwurf; nach Zusage aktualisiert | HEIM-1, Stationen | 4–6 Läufe |
| 5 | **Kosten & Rechnungen** | **Heim:** Monatsübersicht in fünf Spalten, CSV | – | 2–3 Läufe |
| 6 | **Ändern und Stornieren** | **Heim:** Auftrag ändern oder stornieren; Team sieht dasselbe | Mitteilungen; Entscheide `lca`/`owner` | 4–6 Läufe |
| 7 | **KI-Dienstplanung für eigenes Personal** (B2B) | **Dienstplanerin:** Plan mit Namen, KI-Vorschläge | Bedarfsplan; Lizenzmodul; `lca` | eigener Vertrag |

**Das nächste kleinste Paket nach BK-f** ist nach dem bestehenden Founder-Entscheid **STAB1**. Für das Heim bringt es nichts Sichtbares. Das erste für das Heim sichtbare Paket ist **BK-d** (Nummer 1), frühestens nach STAB1 und AI1: grob 10–15 Engineering-Läufe ab heute plus die Gate-Fenster (ESTIMATE). Wer früher etwas Sichtbares für das Heim will, muss die Reihenfolge ändern; das ist Entscheid 1 in §10.

**Erste echte KI im Heimablauf** (Paket 1, BK-d):
- **Was sie tut:** Aus «Morgen Frühdienst 7–15 Uhr Station 2, eine FaGe für Grundpflege» schlägt sie Datum, Zeit, Station, Tätigkeit und Stufe vor. Die Stufe nur, wenn sie wörtlich genannt ist. Jedes Feld nennt die Textstelle als Quelle.
- **Was feste Regel bleibt:** Region, Stufe zu Tätigkeit, Zeit, Eignung der Teams.
- **Sichtbarer Unterschied:**
  - «KI-Vorschlag aus Ihrem Text»: angeschlossenes Modell, nur Staging, synthetische Daten;
  - «geprüft nach Regel»: feste Regel;
  - in der CI ein Testersatz mit festem Antworttext, nie als KI bezeichnet.
- **Messung:** Anteil richtig erkannter Felder auf einem synthetischen Satzkorpus, Anzahl Korrekturen bis zum Absenden, Kosten und Dauer je Aufruf. Fällt das Modell aus, bleibt das Formular vollständig nutzbar.

## 10. Offene Founder-Entscheide

Nur Punkte, die PO und `eng` nicht selbst entscheiden können:

1. **Reihenfolge:** Bleibt es bei STAB1 → AI1 → BK-d (FE-099)? Oder soll ein kleines, nur lesendes HEIM-1 «Startseite + Aufträge geordnet» (ESTIMATE 2–3 Läufe, ohne Stationen) **vor AI1** kommen, damit das Heim früher einen Arbeitsplatz sieht? Das würde die erste echte KI um diese Läufe verschieben.
2. **Geschäftsmodell Bedarfsplan:** Gehört der schlanke Bedarfsplan (Idee 1) zur Grundplattform oder schon zum bezahlten B2B-Modul Dienstplanung (GM-2)?
3. **Diktat:** Ob und mit welchem Anbieter Sprache in Text umgewandelt wird. Anbieterwahl ist dein Entscheid.

**Nicht bei dir, sondern bei den Fachrollen (OPEN):**
- Schwelle «gefährdet» und Matrix-Hinweis zur Stufe: `cra` / Clinical Owner.
- Folgen kurzfristiger Stornierung: `lca` / `owner`.
- Inhalt von Mitteilungen und Leistungsbestätigung: `lca`.
- Gruppierung der Tätigkeiten: `cra`; Wortlaut: `uxa`.
- KI-Kontrollen für die Auftragserfassung: `aia`.

**PO:** Bitte ergänze deine Sicht zu §2 (welches Register zuerst), §9 (Reihenfolge) und §10 (welche Entscheide wirklich beim Founder liegen) direkt im PR oder in einem eigenen Abschnitt. Danach ist diese Vorlage die gemeinsame.

---

## Anhang: technische Belege

- **Staging-Nachweis:** `staging-smoke` Lauf 44744533079, Job 136316309345, App-Commit `8051283`, Datenbank bis Migration 0157. Pfade 1–3 in `tests/staging-smoke/founder-click-paths.spec.ts`.
- **Eignungsprüfung je Person:** `private.order_member_step` (0132), Stufen 0–4: aktiv und Zugang offen / Stufe verifiziert / Tätigkeitsnachweis / frei für die ganze Schicht laut Abwesenheiten und Einsätzen / geeignet.
  - Gesamtprüfung: `private.screen_order_reach` (0130, 0132).
  - Das Ergebnis wird einmal beim Absenden gespeichert (AUT-117 (b)).
- **Statustexte heute:** `clientCoverLines` in `src/features/orders/offer-rules.ts`. Ausfall-Signal an das Team: Migration 0144 `take_member_dropped`. Bestätigung und Freigabe: 0136.
- **Rechnungen:** `team_invoice_drafts` mit den Zuständen Entwurf / gesendet / ungültig, `public.client_invoices` (0156); Preis-Snapshot bei der Übernahme (0155).
- **Fehlt im Code:**
  - keine Tabelle für Station oder Standort;
  - kein Befehl zum Stornieren oder Ändern durch das Heim;
  - keine Benachrichtigung an Kundenkonten (SIG2 nur für Mitglieder);
  - `client_shift_plans` nur zur Anzeige.
- **Geplante Grundlage für KI:** `docs/agents/briefs/AI1.md` (Anschluss, Not-Aus, Kostengrenze, Quelle je Zeile); BK-d laut `docs/agents/briefs/BK.md` §PO amendment, «Station bestellt» auf dem AI1-Anschluss.
