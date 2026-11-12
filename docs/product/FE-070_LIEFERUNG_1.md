# FE-070 Lieferung 1: Bestätigung, Bestandsaufnahme, erster Teilblock

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-12 14:39 (Europe/Zurich), geplanter PO-Lauf; die Founder-Nachricht kam während des Laufs · **Grundlage:** Founder-Entscheid FE-070 (`FOUNDER_DECISIONS.md` v20) · **Code-Stand:** `recovery/main` `4a543c0` · **Kennzeichnung:** IMPLEMENTED / PLANNED / OPEN / UNKNOWN wie in `CLAUDE.md`. Der PO hat keinen Test selbst ausgeführt. Alle Testläufe liefen in GitHub Actions (FE-056); die Zahlen unten stammen aus den Job-Protokollen, nicht nur aus der Statusanzeige.

## 0. Die acht Aufträge, in meinen Worten

1. **Geschäftsmodell schützen.** Teams erhalten Aufträge direkt und rechnen über eine Struktur ab, die noch nicht entschieden ist. Ich lege keine Rechtsform fest. NAVORA verdient an Teams nur über eine feste Monatsgebühr, nie über eine Provision. Pflegeumsatz der Teams, Plattformumsatz NAVORA und B2B-Umsatz trenne ich in Daten, Ansichten und Berichten; ein höheres Einkommen ist eine zu prüfende Hypothese.
2. **Ganze Plattform denken.** Für jede Rolle beschreibe ich Aufgabe, Sichtbarkeit, Entscheidungen, benötigte Daten und Übergaben: Auftraggeber, Team, Pflegende mobil, B2B-Einrichtung, Angehörige, Coach, Operations/Support, Betreiber-Finanzen. Coach, Support, Plattformadministration und Finanzen bleiben getrennte Berechtigungen, auch wenn eine Person mehrere Funktionen hat.
3. **KI nimmt nachweislich Arbeit ab.** Harte Voraussetzungen (Qualifikation, Nachweis, Delegation, Sicherheit) prüfen versionierte Regeln auf jedem Zuteilungsweg. Die KI erklärt und ordnet nur innerhalb dieser Grenzen; ein Score gleicht nie eine fehlende Voraussetzung aus. Ich kläre mit `cra` und `lca`, was «Fall übernehmen» bedeutet und ab wann eine Versorgung verbindlich zugesagt ist.
4. **B2B-Produktlinie.** Ich entwerfe drei Module: Planung und Ausfall, Diktat und Bericht mit Freigabe, Angehörigenkommunikation. Für die Angehörigen beschreibe ich den ganzen Ablauf: Zugang und Widerruf, Adressat einer Frage, KI-Entwurf nur auf bestätigter Information, Freigabe, Fotos und Schutz vor Unterbrechung. Geplante Gabe, dokumentierte Verabreichung und bestätigte Einnahme sind drei verschiedene Aussagen. Rund-um-die-Uhr-Erreichbarkeit verspreche ich nicht. D-35 bleibt in Kraft.
5. **B1 kritisch bewerten.** Ich bewerte B1 als Produkt, nicht nur als Abbild des Codes, mit Optionen und Empfehlung. An dich gebe ich nur Fragen zu Vision, Geschäftsmodell, Budget, Rechtsform oder wesentlichem Risiko.
6. **Ein Block nach dem anderen.** Vor dem Start ist jeder Block vollständig beschrieben (die neun Punkte aus FE-070 (6)). Abgenommen wird nur auf einem benannten integrierten Commit mit ausgeführten, reproduzierbar grünen Tests, den Reviews und einem dokumentierten Entscheid. Jede Abnahme nennt ihr Gate: «Simulation, synthetische Daten» oder «reale Personen». Ein Sicherheitsfix ist eine dokumentierte Einzelausnahme. B1 wird in Teilblöcke geschnitten.
7. **Vision-Check je Block.** Jeder Block beantwortet die acht Fragen aus FE-070 (7). Dazu kommen eigene Differenzierungsideen, nach Entlastung, Nutzen, Sicherheit, wirtschaftlichem Potenzial und Machbarkeit geordnet.
8. **Blueprint und Prompts.** Ich verankere die Regeln im Blueprint mit vollständigem Changelog und gleiche Entscheidungsregister, Clinical Rule Register, Roadmap und GitHub ab. Für den PO-Prompt und die Agenten-Aufträge schreibe ich den neuen Wortlaut. Freigaberegeln ändere ich nicht, um schneller fertig zu werden.

**Ausdrücklich bestätigt:** Wir haben **noch keinen nachweislich tragfähigen Pilot**. Phase A ist eine Simulation mit synthetischen Daten. Wir arbeiten auf diesen Nachweis hin: mit eigenständiger Produktführung und mit einzeln geprüften, einzeln abgenommenen Blöcken.

## 1. Bestandsaufnahme: integriert, getestet, abgenommen

Drei verschiedene Tatsachen, nie gleichgesetzt.

**Integriert (IMPLEMENTED auf `recovery/main`):** 49 Zeilen der PO-Warteschlange tragen den Status `accepted`. Das ist eine **Abnahme auf Brief-Ebene** (Kriterien eines Einzelauftrags auf synthetischen Daten), **keine Blockabnahme**. Dass integriert nicht richtig heisst, zeigt Δ11: ein integrierter, getesteter Ablauf verliert einen wiedereröffneten Fall ohne jedes Signal.

**Auf dem aktuellen Stand getestet:** Lauf `ci` 43229659680 auf dem Merge-Commit `00b4700`, alle vier Jobs grün. Seither kamen nur Dokumente hinzu.
- `app`: 110 Testdateien, 1203 Unit-Tests bestanden.
- `db`: 128 pgTAP-Dateien, 4646 Tests, «All tests successful».
- `e2e`: 163 Playwright-Tests bestanden, 34 Spezifikationen.
- Reproduzierbarkeit: der Wiederholungslauf `ci-repeat` 43231715012 (10 × `db`, 10 × `e2e`) auf dem benannten Commit `4a543c0` läuft (Stand bei Abschluss siehe Journal 14:39).

Grenzen dieses Nachweises:
- Kein Agent kann lokal testen.
- `uxa` hat keine Screenshots gesehen (Download vom Proxy abgelehnt).
- Einige Tests sind als erwartet rot geführt oder fehlen (Tabelle).
- Ein grüner Lauf beweist nur, was die Tests prüfen.

**Als Produktblock abgenommen:**

| Block | Integriert | Getestet auf `00b4700` | Blockabnahme | Gate |
|---|---|---|---|---|
| B0 Technische Basis | ja | ja | **abgenommen 11.11.** | Simulation; B0-6 Repository-Schutz offen (Owner) |
| BD Durchgang ambulant | ja | ja, Schritte 1-5, 8, 9; 6-7 nicht nachgewiesen | **abgenommen 12.11. 14:39, wirksam mit 20/20 auf `4a543c0`** | nur Simulation; keine klinische Freigabe, kein Tarifnachweis |
| B1 Anfrage, Fall, Teamentscheid | ja (J1, J2, C1, RET1, J6) | teilweise; kein e2e für 390 px/Doppeltipp, Ablehnung, Sicherheitshinweise; Δ11-Fehler ungetestet | nein | – |
| B2 Qualifikation, Nachweise, Delegation | teilweise (QUAL1 Teil 1, Teil 2 offen) | teilweise; B2-T7/T8 erwartet rot | nein | alle 115 Matrixzellen PROPOSED |
| B3 Planung, Ausfall | ja (PLAN3, AIG1) | teilweise | nein | – |
| B4 Mobile Ausführung | teilweise | teilweise | nein | – |
| B5 Sicherheitssignale | ja | **Testfehler offen** (B5-T7, B5-T9) | nein | – |
| B6 Diktat, KI-Dokumentation | teilweise; Diktat und KI-Entwurf PLANNED | nein für Schritte 6-7 | nein | D-35 |
| B7 Abklärung, Pflegeplan, Verordnung | ja (ASM1, ORD) | teilweise | nein | Fach-/Legal-Gate offen |
| B8 Abrechnung | teilweise (Fakt aus signiertem Bericht) | teilweise | nein | D-18, D-22 offen; FE-069 Simulationsregel |
| B9 Pflegeheim (simuliert) | nur Brief NH-A1 | nein | nein | – |
| B10 Kennzahlen | ja (AN1-AN3) | teilweise; AN3-Status widersprüchlich | nein | – |
| B11/B12 Staging, Phase B | Staging-Migration offen (#1087, fehlendes Secret) | nein | nein | – |

**Nicht vorhanden (OPEN):** Auftraggeber-Portal (Heim, Spital, Privatperson), Betreiber-Finanzansicht mit getrennten Umsätzen, Plattformgebühr als Abo, B2B-Mandant, Angehörigenablauf über die D-40-Leseansicht hinaus, getrennte Rollen für Support, Plattformadministration und Finanzen (heute: `admin`, `operations`, `coach`).

## 2. Erste Befunde zu B1 (vorläufig; die vollständige Bewertung folgt in Lieferung 2)

- **Start bei Operations:** Der Start bei Operations ist im heutigen Code die einzige Eingangstür; für Phase A ist das eine Simulation. **Zielmodell (Empfehlung):** Der Auftraggeber erfasst selbst, in seiner eigenen Ansicht. Feste Regeln (Region, Tätigkeiten, Qualifikation, Kapazität) bestimmen die geeigneten Teams, und diese Teams entscheiden. Ein Mensch sieht nur Ausnahmen: unvollständige Anfragen, Sicherheitshinweise, keine sichere Zuordnung. Ohne diese Ausnahmegrenze entsteht die zentrale Vermittlung neu.
- **Grober Filter (IMPLEMENTED):** `team_offers` prüft nur die Region als exakten Text und, falls verlangt, «Team hat eine diplomierte Pflegefachperson» (0086:205-212). Der Grund: Anfragen beschreiben keine konkreten Tätigkeiten, und die Matrix ist nicht freigegeben. Die tätigkeitsbezogene Prüfung gibt es erst bei der Einsatzzuteilung (QUAL1).
- **«Fall übernehmen» (IMPLEMENTED):** ein Klick eines Teammitglieds, der erste Zusage-Entscheid gilt. Kompetenz, Kapazität und Sicherheitsvorbehalte werden dabei nicht geprüft. **Empfehlung:** zwei Stufen. (a) «Wir prüfen»: unverbindlich, sperrt das Angebot für eine kurze Frist. (b) «Versorgung zugesagt»: verbindlich, erst nach bestandener Regelprüfung, und nur durch eine Person, die nach den Teamregeln im Namen des Teams zusagen darf.
- **Pflichtfelder (IMPLEMENTED):** Versicherer und Versicherungsart sperren heute die Teamsuche für jeden Auftrag (`private.case_readiness`, 0013:159-170). Für einen Auftrag eines Heims oder Spitals sind das Abrechnungsangaben, keine Angaben für Angebot oder Sicherheit. **Empfehlung:** drei Stufen, je mit eigenem Zeitpunkt: für das Angebot, für die sichere Versorgung, für die Abrechnung.
- **Freitext:** Titel und Bedarf können identifizierende Angaben enthalten. Heute sehen alle Teams der Region den Titel des Angebots (O-1 bei `lca`). **Empfehlung:** Angefragte Teams sehen Tätigkeiten, Umfang und Region, ohne Freitext. Erst das zusagende Team sieht den Text der zuweisenden Stelle (CGR-193 (4b)).
- **Δ11** bleibt die erste Sicherheitslücke (siehe §3).

## 3. Block- und Abhängigkeitsplanung (Vorschlag) und erster Teilblock

**Reihenfolge (Vorschlag, wartet auf deine Bestätigung).** Die Abhängigkeit von der Qualifikationsprüfung ist abgebildet: Ein sicheres Teamangebot braucht vorher Tätigkeiten in der Anfrage, Profile und versionierte Regeln.

0. **Sicherheitsausnahme Δ11** (dokumentierte Einzelausnahme, FE-070 (6)): Ein wiedereröffneter Fall ohne Team findet wieder ein Team, oder Operations sieht ihn als Ausnahme. Ein pgTAP-Test, der heute rot ist und danach grün; `cra`-Gate, ADR. `eng` darf den roten Test und das ADR schon jetzt auf einem Branch vorbereiten, ohne Merge.
1. **B1.1 Sichere Anfrage, Fall und Bereitschaft:** **erster aktiv umzusetzender Teilblock** (Steckbrief unten).
2. **B2-Kern Tätigkeiten, Profile, Regeln:** konkrete Tätigkeiten in der Anfrage; Mitgliedsprofil mit Nachweis und Delegation; versionierte Simulationsregeln nach FE-069 (QAM v0.2, gekennzeichnet «Simulationsregel – nicht fachlich freigegeben»); die Begründung «geeignet, weil …» bzw. «keine sichere Zuordnung, weil …».
3. **B1.2 Qualifikationsgesichertes Teamangebot und verbindliche Zusage:** Angebot nur an Teams, die die Regeln erfüllen; Zusage in zwei Stufen; dieselbe Prüfung bei Zusage, Einzelzuweisung, Übernahme, Tausch und Vertretung (in B3 wiederverwendet).
4. **B1.3 Lebenszyklus und Ausnahmen:** dringliche Anfrage ohne Zusage, Abschluss mit offenen Aufgaben (Δ14), ausgesetzte Einsätze (Δ17, Δ18), Rückkehr mit verändertem Bedarf.
5. **B1-Gesamtabnahme:** integrierte Demonstration im BD-Durchgang auf einem benannten Commit mit 10/10.

Danach: B3, B4, B5, B6, B7, B8, B9 (mit BD-H), B10, B11. Die neuen Plattformteile (Auftraggeber-Ansicht, Betreiber-Finanzen, B2B-Mandant, Angehörige) ordne ich in Lieferung 4 ein. Wo PROD hinkommt, bleibt deine Frage (OWNER_AGENDA, Standard C).

**Steckbrief B1.1 (nach FE-070 (6)):**

| Punkt | Inhalt |
|---|---|
| Problem und Nutzen | Eine Anfrage kann heute an Tippfehlern scheitern (Region als freier Text). Sie wartet auf Angaben, die nur die Abrechnung braucht. Sie verliert den Text der zuweisenden Stelle. Sie lässt Operations ohne Rückmeldung. Nutzen: Jede vollständige Anfrage wird ohne Nacharbeit bereit; Sicherheitswörter der zuweisenden Stelle gehen nicht verloren (Werte: Sicherheit, 2, 5). |
| Umfang | M1 bis M4: Region als Auswahl (Δ1); Bereitschaft nach Zweck gestuft (Angebot, Sicherheit, Abrechnung; die genaue Feldliste geben `cra` und `lca` frei); Text der zuweisenden Stelle für das künftige zusagende Team gespeichert und markiert (CGR-193 (4b), Bau erst nach der `lca`-Zeile); Statuszeile nach «Fall eröffnen» (Δ7, UXR-165); doppelte Anfrage zurückweisen, ohne etwas zu löschen (Δ5, O-6). |
| Nicht-Ziele | Teamangebot und Zusage (B1.2), Qualifikationsprüfung (B2-Kern), Auftraggeber-Portal, automatisches Eröffnen, REF2, Pflegeheim-Aufnahme (B9). |
| Rollen und Ansichten | Operations `/intake` (in Phase A als Platzhalter für den Auftraggeber), Coach nur lesend; andere Teams und Organisationen sehen nichts. |
| Owner, Mitwirkende | `po` (Abnahme), `eng` (Bau), `uxa` (Texte, 390/1440 px), `cra` (Sicherheitsfelder), `lca` (Minimierung, Aufbewahrung). |
| Abhängigkeiten | BD für die Simulation abgenommen; Δ11 vorher gemergt. |
| Issues, PRs | Spezifikation `specs/B1.md` M1-M4; UXR-165; CGR-193; offene Engineering-PRs #1131, #1102 (nur Journal). |
| Akzeptanz und Tests | Positiv: vollständige Anfrage → Fall → bereit, ohne Abrechnungsangaben, wenn der Auftragstyp sie nicht braucht (pgTAP, e2e). Negativ: unbekannte Region nicht wählbar; bestehender Freitextwert wird Operations angezeigt, nicht verworfen; fremdes Team, fremde Organisation und `anon` lesen nichts; Zurückweisen löscht nichts. BD Schritte 1-2 bleiben grün. |
| Prüfungen | `uxa` G-1 bis G-6, `cra`-Gate auf jedem Head, `lca` vor dem Bau von (4b) und der Feldstufen, Sicherheitsprüfung (RLS). |
| Visionsbeitrag | Messung: AUT-88-Handlungen bei der Aufnahme (heute 23 von 61) und Anteil der Fälle, die ohne Nacharbeit bereit werden. |
| Abnahme | benannter Commit, `ci` grün und `ci-repeat` 10/10, Gate «Simulation». |

## 4. Plan der übrigen Lieferungen

| Lieferung | Inhalt | Termin |
|---|---|---|
| 2 | Geschäftsmodell in eigenen Worten (Abo ohne Provision, B2B getrennt, Ziel für Pflegende als Hypothese); vollständige kritische B1-Bewertung mit Optionen | 2026-11-13 |
| 3 | Gesamtplattform: Rollen, Ansichten, Berechtigungen, Daten- und Geldflüsse, Betreiber-Finanzen, Coach, Angehörige; Matching-Entwurf mit Regeln, Grenzen und Rolle der KI (mit `cra`, `lca`) | 2026-11-16 |
| 4 | Endgültige Blockplanung mit neuen Plattformteilen; drei Differenzierungsideen mit Validierungsschritt; Wortlaut für PO-Prompt und Agenten-Aufträge | 2026-11-17 |

**Verankerung bis jetzt:**
- `FOUNDER_DECISIONS.md` FE-070 (v20);
- Blueprint v2.68 (Versionszeile, §0);
- `PRODUCT_BLOCKS.md` §9;
- `briefs/BD.md` Nachtrag 14:39;
- `briefs/B1.md` zurück auf Entwurf.

**Prompts:** Ich lege den neuen Wortlaut in Lieferung 4 vor. Auf die geplanten Aufgaben übertrage ich ihn erst, wenn du ihn bestätigt hast, weil er alle Agenten bindet.

**Bis zu deiner Bestätigung** wird kein Feature-PR gemergt. Gemergt werden nur Dokumente und, nach deinem Ja, die Ausnahme Δ11.
