# NAVORA Architecture Blueprint V3.0

**Status: ENTWURF zur Freigabe durch den Founder.** Bis zur Freigabe gelten der Blueprint V2.x ([`ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md`](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md)) und `ARCHITECTURE.md` weiter. Ab der Freigabe ist V3.0 das führende Arbeitsbuch; V2.x wird Archiv.

| Feld | Wert |
|---|---|
| Version | 3.0-Entwurf, 2026-11-13 |
| Auftrag | Founder-Anweisung vom 2026-11-13 (FE-074): Blueprint V3.0 und Architecture Handbook V2.0 neu erstellen |
| Verfasst von | Product Owner (`po`) |
| Mitwirkung | `csa` (Strategie, Kapitel 1 bis 3) und `eng` (Abgleich mit dem Code, Kapitel 5 und 7): Review nach dem Entwurf, über Review-Issues |
| Technische Verfassung | [`docs/architecture/ARCHITECTURE_HANDBOOK_V2.md`](../architecture/ARCHITECTURE_HANDBOOK_V2.md) (WIE gebaut wird) |
| Vorrang | Neueste Founder-Entscheidung in [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) vor diesem Dokument (README Regel 10). Repository-Code vor Dokumentation (CLAUDE.md). |

**Statuskennzeichen** (CLAUDE.md): **IMPLEMENTED** = im Code auf `recovery/main` vorhanden; **PLANNED** = beschlossen, nicht gebaut; **OPEN** = Entscheid fehlt; **UNKNOWN** = nicht belegt. Wo ein Kapitel ein Ziel beschreibt, ist es PLANNED, auch wenn es im Präsens steht.

**Grundlage des Entwurfs:** Code-Inventar von `recovery/main` auf `7d886b6` (2026-11-13), `FOUNDER_DECISIONS.md` (Änderungsprotokoll v24, FE-001 bis FE-074), `PRODUCT_BLOCKS.md`, Brief `briefs/BK.md`, `OPEN_DECISIONS.md`, `QUALIFICATION_MATRIX.md`. Der PO hat keine Tests ausgeführt.

---

## Inhalt

0. Was sich gegenüber V2.x ändert
1. Vision, Disruption und Werteordnung
2. Finanz- und Geschäftsmodell
3. Das modulare B2B-Portfolio
4. Die sechs Plattform-Portale
5. Die verbindliche Block-Lieferkette
6. Harte Gate-Kriterien, Phase A und Phase B
7. Ist-Stand gegen Zielbild
8. Offene Entscheide, die dieses Dokument nicht trifft
9. Pflege dieses Dokuments

---

## 0. Was sich gegenüber V2.x ändert

1. **Ein geschlossenes Gesamtbild statt Meilenstein-Prozenten.** V2.x hat M1 bis M10 mit Erfüllungsgraden geführt. V3.0 führt ein Zielbild (Kapitel 1 bis 4), eine Lieferkette (Kapitel 5) und harte Gates (Kapitel 6). Die Meilensteindaten (M9 am 2027-03-12) bleiben als Termine bestehen.
2. **Altdaten sind kein Thema mehr** (FE-073 (1)). Regionen-Freitext, Zuordnungs- und Race-Verfahren erscheinen nur noch als Abschluss von B1.1.
3. **Der Kernablauf zuerst** (FE-073 (3)): ein Auftrag läuft vom Auftraggeber bis zur Rechnung durch, bevor Sonderfälle gebaut werden.
4. **Sechs Portale als Produktstruktur** (Kapitel 4), mit ehrlichem Ist-Stand: drei der sechs Routen existieren heute nicht.
5. **Fünf Engines** als technische Gliederung; ihre Beschreibung steht im Handbook V2.0, hier nur ihre Produktaufgabe.

**Abweichungen von der Founder-Anweisung, die der PO bewusst so schreibt** (vom Founder am 2026-11-13 in der PO-Sitzung auf vier Rückfragen bestätigt, festgehalten in FE-074):

| Anweisung | So im Entwurf | Grund |
|---|---|---|
| Block BK «Lehenmatt-Logik» | BK heisst «Universeller Schicht- und Auftragsdurchstich» (Titel aus der Anweisung; bisher «Durchgehender Kern «Schichtauftrag Heim»», Kennung BK und Brief unverändert), Referenzfall «synthetisches Pflegeheim 4052 Basel, Spätschicht Demenz» | «Lehenmatt» ist der Name eines realen Basler Alterszentrums. In Phase A gibt es keinen realen Partner (FE-021); ein realer Name erst mit einer Vereinbarung in Phase B. |
| Engine 2 (KI-Profilabgleich) und Engine 3 (Voice-to-Report) | Zielarchitektur; in Phase A ausschliesslich mit synthetischen Daten | D-35 Regel A (FE-024): keine Klienten- oder Personaldaten an einen KI-Dienst. Reale Daten erst nach Entscheid D-41. |
| Handbook ersetzt `ARCHITECTURE.md` | erst ab Freigabe des Founders | bis dahin gelten die bisherigen Dokumente |

**Weitere Spannungen, die der PO meldet, aber nicht selbst auflöst** (Kapitel 8): Tiers payant in Engine 4 (D-22, D-18, D-44 offen); «automatische Rechnungsstellung» gegen das Verbot automatischer Abrechnungsentscheide (`ARCHITECTURE.md`, KI-Säule); ein gemeinsames Cockpit für Betreiber und Coach gegen die Funktionstrennung von FE-070 (2); die Lieferkette nennt B4, B5, B7 und B9 bis B12 nicht.

---

## 1. Vision, Disruption und Werteordnung

### 1.1 Das Problem, das NAVORA löst

Ambulante Pflege und Personalverleih in der Schweiz finanzieren eine Schicht zwischen Auftraggeber und Pflegekraft: Disposition, Einsatzleitung, Vermittlungsmarge, Verwaltung. Ein Heim, das um 14:15 eine Spätschicht verliert, telefoniert Temporärbüros ab. Der Founder nennt als Beispiel rund 75 CHF/h, die das Heim zahlt, und rund 28 CHF/h, die bei der Pflegekraft ankommen (Founder-Zahlen, **UNKNOWN**: nicht verifiziert, nur zur Veranschaulichung, Brief BK).

### 1.2 Die Disruption

**NAVORA ersetzt diese Zwischenschicht durch Software, nicht durch eine neue Zentrale.** Selbstorganisierte Pflegeteams nehmen Aufträge direkt von Heimen, Spitälern und Privatpersonen an, erbringen die Pflege und rechnen über eine rechtlich geeignete Struktur selbst ab (FE-040 (1), FE-070 (1)). Die Rechtsform (zum Beispiel Genossenschaft) ist **OPEN** (D-44) und wird nicht stillschweigend festgelegt.

Was wegfällt (Ziel, PLANNED): Telefonketten, zentrale Disposition, Einsatzleitung als Hierarchie, abgetippte Berichte, manuell geschriebene Rechnungen.

Was nicht wegfällt (FE-039, FE-070 (1)): fachliche Verantwortung je Tätigkeit, gesetzlich verlangte Funktionen je Organisation (zum Beispiel die pflegeverantwortliche Fachperson nach kantonalem Recht), Bewilligungen, notwendige Administration.

**Benchmark:** Buurtzorg ist die Basis, die NAVORA übertreffen soll: Buurtzorg nimmt die Hierarchie aus den Teams, behält aber Koordinationsarbeit bei Menschen. NAVORA soll diese Koordinationsarbeit (Matching, Planung, Ausfall, Dokumentation, Abrechnungsvorbereitung) in Software verlagern, unter menschlicher Entscheidung.

### 1.3 Die KI als operatives Rückgrat

KI ist bei NAVORA keine Zusatzfunktion, sondern bereitet jeden Verwaltungsschritt vor (KI-Säule, Owner 2026-11-03). Die verbindliche Reihenfolge bleibt:

> Unnötige Arbeit entfernen → Regeln anwenden → überwachen → KI bereitet vor → Mensch prüft → Mensch entscheidet → Mensch unterschreibt.

| Aufgabe | Was die KI tut (PLANNED) | Was sie nie tut |
|---|---|---|
| Matching | ordnet nur Teams, die alle harten Regeln erfüllen; erklärt in Worten, warum | ein Team hinzufügen, eine fehlende Qualifikation, Lizenz oder Delegation ausgleichen (FE-073 (3)) |
| Planung und Ausfall | schlägt Tagespläne und Vertretungen nach Teamregeln vor | einen Einsatz zuteilen; das Team entscheidet (FE-039) |
| Diktat und Bericht | macht aus Diktat oder Notiz einen Entwurf mit Quellenbezug | etwas erfinden; unterschreiben; ohne Signatur einen verbindlichen Bericht erzeugen |
| Abrechnung | bereitet Rechnungspositionen aus signierten Fakten vor, hält unklare Fälle an | einen Abrechnungsentscheid treffen; einen Preis setzen |
| Sicherheit | — | P1-Sicherheitssignale priorisieren (AI-10: bleiben deterministisch) |

**Datenregel (D-35 Regel A, FE-024, in Kraft):** In Phase A laufen alle KI-Funktionen nur auf synthetischen Daten. Ob und wie reale Klienten- oder Personaldaten einen KI-Dienst erreichen, entscheidet der Founder in D-41.

**Ist-Stand:** Das KI-Governance-Gerüst ist **IMPLEMENTED** (Agentenregister, unveränderliches Vorschlagsprotokoll, Bestätigung je Wert, Stopp, Rückblick; Migration 0097 ff.). Ein Agent der Art `ai` lässt sich heute nicht einschalten (`set_agent_state` verweigert es). Die vorhandenen Agenten sind regelbasiert (`plan3_day_proposal`). **Ein Aufruf eines KI- oder Spracherkennungsdienstes existiert im Code nicht** (kein SDK, keine `/api/ai`-Route).

### 1.4 Werteordnung

Patientensicherheit ist Vorbedingung und wird nie gegen etwas getauscht. Danach gilt diese Reihenfolge bei jeder Priorisierung:

1. mehr direkte Pflegezeit
2. bessere Versorgungskontinuität
3. höheres Nettoeinkommen der Pflegenden (Zwischenmarge entfällt)
4. Teamautonomie
5. weniger Administration
6. bessere Ergebnisse für Patientinnen und Patienten
7. betriebliche Skalierbarkeit
8. Vollständigkeit der Plattform
9. Umsatz
10. Bequemlichkeit für Engineering

**Nordstern:** Anteil direkter Pflegezeit je Team und Monat (Metrik M-13). **Hypothese**, kein gemessener Zielwert: ≥ 60 % (Buurtzorg-Benchmark), 75 % als NAVORA-Hypothese. Der Nordstern ist heute **nicht messbar** (D-23): AN1 zeigt nur den Pflegeanteil innerhalb eines Einsatzes und darf nicht mit den 60 % von Buurtzorg verglichen werden. Ein realer Wert entsteht erst in Phase B. Eine Einkommenssteigerung ist zu belegen, nicht zu versprechen (FE-040 (1), FE-070 (1)).

### 1.5 Unverrückbare Produktinvarianten

1. **Kein Score ersetzt eine Regel.** Harte Voraussetzungen werden deterministisch geprüft (Qualifikation, Nachweis, Delegation, Region, Zeit), auf jedem Zuteilungsweg und bei jeder Übernahme erneut (FE-070 (3)).
2. **Niemand teilt einem Team einen Auftrag zu.** Das Team entscheidet; NAVORA bereitet vor (FE-039).
3. **Nicht gedeckt bleibt sichtbar.** Ein offener Bedarf verfällt nie still (BK-6, SAFE-D11).
4. **Kein Bericht ohne Signatur, keine Rechnung ohne signierten Bericht** (BK-8, BK-9).
5. **NAVORA verdient nie an der Pflegevergütung** (Kapitel 2).
6. **Keine Leistungsbewertung je Person.** Kennzahlen gelten je Team oder Organisation (AI-9).
7. **Keine erfundenen Regeln.** Eine klinische Regel gilt erst mit Freigabe durch den Clinical Owner (D-27, D-43). Die Qualifikationsmatrix v0.1/v0.2 ist **PROPOSED** und nur für die Simulation zugelassen.

---

## 2. Finanz- und Geschäftsmodell

### 2.1 Zwei Geschäftsmodelle (FE-040, FE-055)

| | GM-1 Teamgeschäft | GM-2 B2B-Software |
|---|---|---|
| Kunde | selbstorganisiertes Team | Pflegeheim, Spital |
| Was NAVORA liefert | Plattform und KI für Aufträge, Planung, Einsatz, Bericht, Abrechnungsvorbereitung | Module für das eigene Personal der Einrichtung (Kapitel 3) |
| Erlös NAVORA | feste monatliche Plattformgebühr je Teammitglied oder Team | Softwarelizenz je Modul |
| Pflegeerlös | gehört dem Team | gehört der Einrichtung |
| Status | Richtung in Kraft; Preis **OPEN** (D-14) | Richtung in Kraft; Preise **OPEN** (FD-29) |

**Gebühr (FE-055 (3)):** verboten sind eine Gebühr je Stunde (F1) und ein Umsatzprozent (F2). Die Gebühr ist eine Variante von F3/F6, **gewichtet nach effektivem Pensum (VZE)**, damit kleine und teilzeitstarke Teams nicht benachteiligt werden. Die Preishöhe ist OPEN (D-14, Gate PB-7).

**Demand-Pooling (FE-055 (4)):** Ein Einsatz eines Teams in einem Heim, das NAVORA als B2B-Software nutzt, ist immer ein eigener GM-1-Auftrag mit eigenem Vertrag und eigener Rechnung. Das Heim gibt Bedarf freiwillig frei, das Team entscheidet, das Team sieht keine internen Daten des Heims.

### 2.2 Keine Provision, nie

NAVORA nimmt **keinen Prozentsatz und keinen Betrag** auf Aufträge, Pflegeumsätze oder Pflegerechnungen (FE-055 (1), FE-070 (1)). Auf einer Pflegerechnung erscheint keine NAVORA-Position (BK-9).

**Ist-Stand:** Rechnungstabellen existieren noch nicht (**PLANNED**, Block BK Schritt 5 und B8). Provisionsfelder existieren nicht. Vorhanden sind `tariff_rates`, `billing_rules`, die unveränderlichen `billable_facts` und eine Umsatzvorschau (**IMPLEMENTED**, synthetische Daten).

### 2.3 Strikte Trennung der drei Geldströme

| Strom | Gehört | Hauptbuch | Wer sieht ihn |
|---|---|---|---|
| A Pflegeerlös und Kosten des Teams | Team | Team-Ledger | das Team; der Auftraggeber nur seine Rechnungen |
| B NAVORA-Plattformgebühr (GM-1) | NAVORA | Plattform-Ledger | Betreiber/Finanzen; das Team nur seine eigene Gebühr |
| C NAVORA-B2B-Softwareumsatz (GM-2) | NAVORA | B2B-Ledger | Betreiber/Finanzen; die Einrichtung nur ihre eigene Lizenz |

**Regeln (PLANNED, technisch zu erzwingen und zu testen, FE-055 (2)):**

- Getrennte Tabellen je Strom; keine gemeinsame «Umsatz»-Tabelle mit Typfeld.
- Kein Fremdschlüssel von einer NAVORA-Rechnung (B, C) auf eine Pflegerechnung (A) und umgekehrt.
- Das Betreiber-Dashboard zeigt A nie als NAVORA-Umsatz. Es zeigt A höchstens als aggregierte Zahl der Plattformaktivität, wenn die Rechtsprüfung das erlaubt (OPEN, `lca`).
- Ein pgTAP-Test beweist für jede der drei Trennungen, dass sie nicht unterlaufen werden kann.

### 2.4 Abrechnungswege für Pflegeleistungen

| Weg | Beispiel | Status |
|---|---|---|
| Dienstleistungsrechnung an eine Einrichtung | Team stellt dem Heim eine Schicht in Rechnung (BK-9: 5,0 h × 52.00 CHF = 260.00 CHF, synthetischer Beispielwert) | PLANNED in BK, Phase A, synthetisch |
| Rechnung an eine Privatperson | Einsatz bei einer Privatperson | PLANNED, nach BK |
| Krankenversicherung nach KVG/KLV (Tiers payant oder Tiers garant) | ambulante Pflege mit OKP-Pflichtleistung | **OPEN**: braucht D-22 (ärztliche Anordnung), D-18 (Zeitregeln Tarifvertrag), D-44 (Vertrag und Rechtsform), Zulassung als Leistungserbringer. Wird nicht vor diesen Entscheiden gebaut. |

Ob die Schicht eines externen Teams in einem Heim Personalverleih oder Dienstleistung ist, ist **OPEN** (D-44, CGR-147).

---

## 3. Das modulare B2B-Portfolio (GM-2)

Für Heime und Spitäler, für ihr eigenes Personal, ohne externes Team (FE-040 (2)). Der B2B-Umsatz ist strikt vom Teamgeschäft getrennt (Kapitel 2.3).

| Modul | Inhalt | Grenzen | Status |
|---|---|---|---|
| **1 Kern: KI-Planung** | vorausschauende Dienstplanung, Schichtplanung, Abwesenheits- und Ausfallkoordination für das eigene Personal | KI schlägt vor, die Einrichtung entscheidet; Abwesenheitsgründe erscheinen nie in Vorschlägen oder Aufträgen (Einordnung als Gesundheitsdaten des Personals: Frage an `lca`) | teilweise vorhanden als Teamplanung (PLAN2, PLAN3, ABS1, COVER1; **IMPLEMENTED** für Teams, synthetisch). Als Heimmodul mit eigenem Mandanten **PLANNED** (B9). |
| **2 Add-on: KI-Protokoll** | Diktat → strukturierter Berichts- oder Protokollentwurf → Prüfung → Signatur durch eine qualifizierte Person | Pflicht-Signatur; Entwurf nennt seine Quelle; reale Daten erst nach D-41; **D-34 (Owner 2026-10-27, A plus C):** der Kern bleibt ausserhalb des Medizinprodukt-Bereichs, ein KI-Dokumentationsentwurf darf nur als separat qualifiziertes Modul mit eigener Zweckbestimmung und eigenem Konformitätsweg gebaut werden; Regulierungsberatung offen | Bericht, Rückgabe, Signatur **IMPLEMENTED** (F6, F6R, F7). Diktat und KI-Entwurf **PLANNED** (B6). |
| **3 Add-on: Angehörigenportal** | strukturierte, freigegebene Updates und Fotos an berechtigte Angehörige | getrennt von der klinischen Akte; Zugang und Widerruf je Person; KI-Entwurf nur auf bestätigter Information, mit Freigabe; keine 24-h-Erreichbarkeit ohne Entscheid (OPEN, FE-070 (4)); schützt Pflegende vor Unterbrechung; geplante Gabe ≠ dokumentierte Verabreichung ≠ bestätigte Einnahme (FE-070 (4)); minimale Option B (D-40) | **PLANNED** (FAM1, M7). Im Code gibt es keine Angehörigenrolle und keine Angehörigenansicht. |

**Innovationshypothese (PO 2026-11-13, keine Entscheidung):** Modul 1 und das Teamgeschäft sind an einer Stelle verbunden. Wenn eine Heimmitarbeiterin sich krank meldet und eine Schicht ungedeckt bleibt, kann das Heim mit einem Klick einen vorausgefüllten Schichtauftrag an Teams freigeben (Demand-Pooling, FE-055 (4)). Der Auftrag trägt nur «Schicht ungedeckt», nie den Grund. Das macht aus einem Telefonat einen bestätigten Klick. Prüfung durch `aia`, `lca`, `uxa` (Challenge-Zeile 11:39 in `NEXT_CAPABILITY.md`).

---

## 4. Die sechs Plattform-Portale

Jedes Portal ist eine eigene, rollengetrennte Sicht. Kein Portal ist ein Adminzugang auf alles (FE-070 (2)). Die genauen Leserechte je Rolle sind **OPEN** (D-3, Berechtigungsmatrix).

| # | Portal | Route (Ziel) | Für wen | Kernaufgabe | Ist-Stand im Code |
|---|---|---|---|---|---|
| P1 | Auftraggeber-Portal | `/order` | Heim, Spital, Privatperson | Auftrag mit PLZ, Zeit, Qualifikation, Tätigkeits-Tags erfassen; Status «noch nicht gedeckt / gedeckt / nicht gedeckt» live sehen; eigene Rechnungen | **nicht vorhanden.** Heute erfasst Personal eine Anfrage über `/intake` (Rollen admin, operations). Eine Auftraggeber-Rolle und ein Auftraggeber-Login fehlen. |
| P2 | Team-Dashboard | `/team` | selbstorganisiertes Team | Angebote sehen und mit einem Tipp übernehmen, Planung, Tagesvorschlag, Pflegeplanung, Teamfinanzen | **teilweise vorhanden:** Angebote und Entscheid (J2), Besuchsplanung (J3), `/team/tagesplan`, `/team/vorschlaege`. Teamfinanzen fehlen. |
| P3 | Caregiver Mobile View | `/field` | Pflegekraft | nächster Einsatz, Zeit, Aufgaben, Diktat, Bericht prüfen und signieren | **vorhanden** (F1 bis F4, F6, F7, 390 px). Offline-Fähigkeit und Diktat fehlen. |
| P4 | B2B-Heimsuite | `/b2b-institution` | Heim oder Spital für eigenes Personal | Modul 1 bis 3 (Kapitel 3) | **nicht vorhanden** |
| P5 | Angehörigen-Ansicht | `/family` | berechtigte Angehörige | freigegebene Updates, keine klinische Akte | **nicht vorhanden** |
| P6 | Betreiber- und Coach-Cockpit | `/platform` | NAVORA-Betrieb, Finanzen, Support, Coach/Mediator | SaaS-Kennzahlen, Teamgesundheit, Systemausnahmen; Coach: Konflikte und Kapazitätsengpässe | **nicht vorhanden.** Es gibt `/operations` (Ausnahmezentrum P1/P2/P3 für Koordinatoren einer Organisation), `/admin` und `/analytics` (Aggregate). |

**Regeln für die Portale (PLANNED):**

- **P1:** Ein Auftraggeber sieht keine Aufträge eines anderen Auftraggebers (BK-1n). Vorschlag des PO darüber hinaus: von einem Team nur «gedeckt durch Team X» und die eigene Rechnung.
- **P2:** Vor der Übernahme sieht ein Team Bedarf, Region, Dringlichkeit und Leistungen, nicht den Namen der betreuten Person. Heute PARTIAL: `team_offers()` hat keine Namensspalte, gibt aber den Freitext `request_title` aus der Erfassung weiter, in den ein Name getippt werden könnte (Frage an `eng`, `lca`).
- **P6 Funktionstrennung (FE-070 (2)):** Betrieb, Finanzen, Support und Coach sind **getrennte Rollen** im selben Portal. Der Coach/Mediator hat **keine Einsatzleitung und keinen allgemeinen Zugriff auf Gesundheitsdaten**. Er sieht Kapazitätsengpässe und Konfliktmeldungen, die ein Team ihm freigibt. Der Betrieb sieht Zählungen, nicht Inhalte (BK: «sieht nur, dass die Kette lief»).
- **Was mit `/operations` geschieht:** Heute ist es das Ausnahmezentrum einer Organisation. Im Zielbild ist es kein Dispositionsplatz. Ausnahmen gehen zuerst an das zuständige Team oder den Auftraggeber; zum Betrieb nur, wenn niemand zuständig ist. Wie `/operations` in P2 und P6 aufgeht, ist **OPEN**: Vorschlag des PO an `eng` und `uxa`, kein Entscheid.

**Rollen im Code heute (IMPLEMENTED):** `admin`, `coach`, `operations`, `nurse` (`organization_memberships.role`). Es gibt keine Rollen für Auftraggeber, Angehörige oder Plattformbetreiber. `src/lib/auth/paths.ts` nennt die Rollennamen Platzhalter bis D-3.

---

## 5. Die verbindliche Block-Lieferkette

Regel (FE-054, FE-070 (6), FE-071, README Regel 12): **genau ein aktiver Block.** Vorbereitung späterer Blöcke (Briefs, ADRs, rote Tests auf Branches) ist erlaubt; ein Feature-Merge ausserhalb des aktiven Blocks ist verboten, ausser einer benannten Sicherheitskorrektur.

### 5.1 Reihenfolge

| Schritt | Block | Inhalt | Status am 2026-11-13 |
|---|---|---|---|
| 0a | **SAFE-D11** | Ein wiedereröffneter Fall ohne Team erhält eine neue zulässige Teamsuche oder eine sichtbare, zugewiesene Ausnahme, nie nichts | **abgenommen** (Simulation, synthetische Daten) |
| 0b | **B1.1 Abschluss** | #1181 (CGR-201) und #1184 (CGR-203) mit Gates mergen; B1.1-1c: Seed nur Basel-Stadt / Basel-Landschaft mit PLZ, ohne Altwert | **aktiv**; #1181 wartet auf `lca`- und `uxa`-Gate |
| 1 | **BK Universeller Schicht- und Auftragsdurchstich** | Auftrag mit PLZ → harte Filter → erklärte Angebotskarte → Teamentscheid mit einem Tipp → `/field` → Diktat → Entwurf → Signatur → Rechnungsentwurf ohne NAVORA-Position | **freigegeben, nicht begonnen** (Brief `briefs/BK.md`) |
| 2 | **B2-Kern Qualifikationsmatrix** | Matrix als versionierte Regel, Nachweise, Delegation, Prüfung auf jedem Zuteilungsweg | Teile IMPLEMENTED (QUAL1-Tabellen `qual_*`); Matrixwerte **PROPOSED**, Clinical Owner offen |
| 3 | **B3 Planung** | Team- und KI-Einsatzplanung, Ausfallkoordination | Teile IMPLEMENTED (PLAN2, PLAN3, ABS1, COVER1), «nicht ausreichend getestet» |
| 4 | **B6 Diktat** | Diktat → KI-Entwurf → Prüfung → Signatur | Bericht und Signatur IMPLEMENTED; Diktat und KI-Entwurf PLANNED; reale Daten erst nach D-41 |
| 5 | **B8 Finanzen und Abrechnung** | Rechnungsentwurf, Validierung, Doppelabrechnung, getrennte Ledger (Kapitel 2.3) | abrechenbare Fakten IMPLEMENTED; Rechnungen PLANNED; KVG-Weg OPEN |

### 5.2 Was BK konkret umfasst

BK ist der erste Durchstich durch alle Portale, die schon existieren, und legt die Bausteine für P1 an. Massgeblich ist der Brief `briefs/BK.md` (Akzeptanzkriterien BK-1 bis BK-11, positive und negative Tests). Kurzfassung:

1. **Bedarf erfassen (Heim):** PLZ aus der BS/BL-Liste, Datum, Zeit, Qualifikationsstufe, Tags, Preis je Stunde.
2. **Prüfen und empfehlen:** harte Filter in der Datenbank (PLZ-Distanz, Qualifikation nach Matrix, Verfügbarkeit, bestätigte Pflicht-Merkmale); jedes ausgeschlossene Team mit Grund; Ranking ordnet nur die Zulässigen; Angebotskarte begründet in Worten, **ohne Prozentscore**.
3. **Teamentscheid:** ein Tipp, Regelprüfung im Moment des Tipps erneut; das Heim sieht «gedeckt»; «nicht gedeckt» bleibt sichtbar.
4. **Einsatz und Bericht:** `/field`, Zeit über F1 bis F4, Entwurf aus Diktat oder Text, Signatur nur durch die Pflegekraft der Schicht.
5. **Abrechnung:** ein Rechnungsentwurf des Teams an das Heim, keine NAVORA-Position, keine KVG/KLV-Abrechnung.

**Ziel für die menschlichen Handgriffe (BK-11):** höchstens 1 für das Heim, 1 für das Team, 3 für die Pflegekraft nach der Schicht.

**Vorgeschlagener Zuschnitt (Brief, Frage an `eng`):** BK-a Auftrag, PLZ-Liste, harte Filter · BK-b Angebotskarte, Teamentscheid, Deckungsstatus · BK-c `/field` und Berichtsentwurf · BK-d Rechnungsentwurf · BK-e durchgehender e2e-Test. Ein PR je Teil, ADR zuerst.

### 5.3 Blöcke, die die Anweisung nicht nennt

Die Founder-Anweisung nennt B4, B5, B7 und B9 bis B12 nicht. Der PO liest das so: **diese Blöcke fallen nicht weg**, sondern laufen als Teil der genannten Blöcke oder danach. Bestätigung durch den Founder offen.

| Block | Wo er in der Kette steckt (Vorschlag) |
|---|---|
| B4 Mobile Besuchsausführung | in BK Schritt 4 genutzt (F1 bis F4 vorhanden); Rest (Offline) nach B6 |
| B5 Sicherheitssignale und Eskalation | Grundlage von Engine 5; bestehend, deterministisch; Testfehler offen; vor Phase B Pflicht |
| B7 Assessment, Pflegeplanung, ärztliche Anordnung | Voraussetzung für den KVG-Weg in B8 (D-22); nach B8-Teil «Dienstleistungsrechnung» |
| B9 Simulierter Pflegeheim-Betrieb | nach B3; Grundlage für Modul 1 (P4) |
| B10 Kennzahlen | laufend; Nordstern M-13 |
| B11 Integration, Staging, Wiederherstellung | vor Phase B Pflicht; Staging-PR #1087 offen |
| B12 Voraussetzungen Phase B | Gates PB-1 bis PB-12 (Kapitel 6.3) |

---

## 6. Harte Gate-Kriterien, Phase A und Phase B

### 6.1 Abnahme eines Blocks (FE-070 (6), FE-071, README Regel 12)

Ein Block oder Teilblock ist **nur** abgenommen, wenn alle diese Punkte auf einem **benannten integrierten Commit** auf `recovery/main` belegt sind:

1. `ci` grün: alle vier Jobs `app`, `db`, `e2e`, `ui-screenshots`.
2. `ci-repeat` **10 von 10** grün für `db` und `e2e` auf genau diesem Commit, aus den Rohlogs gelesen: was lief, was übersprungen wurde, was erwartet rot war, was abgebrochen oder instabil war.
3. Automatische Tests für jedes geänderte Verhalten, positive und negative.
4. Die im Brief verlangten Reviews (`cra`, `lca`, `uxa`, `aia`) als Gate-Zeilen auf dem jeweiligen PR-Kopf.
5. Ein dokumentierter Abnahmeentscheid mit der Gate-Stufe: **«Simulation, synthetische Daten»** oder **«freigegeben für reale Personen und Daten»**.

Nicht genügend: ein gemergter PR, eine nur gelesene CI-Anzeige, ein laufender Wiederholungstest, eine Gesamtzahl bestandener Tests (FE-071 (2)).

### 6.2 Phase A und Phase B

| | Phase A (jetzt bis M9, 2027-03-12) | Phase B (später) |
|---|---|---|
| Partner | simuliert; synthetisches Pflegeheim und ambulante Pflege in Basel-Stadt und Basel-Landschaft | reale Pilotorganisation, nach heutiger Richtung ein Pflegeheim |
| Daten | nur synthetisch; Testumgebungen trotzdem produktionsnah geschützt (FE-020) | reale Daten erst nach allen Gates PB-1 bis PB-12 |
| KI | nur auf synthetischen Daten (D-35 Regel A) | nach Entscheid D-41 |
| Klinische Regeln | Matrix PROPOSED, als Simulationsregel gekennzeichnet | nur vom Clinical Owner freigegebene Regeln (D-27, D-43) |
| Abnahmestufe | «Simulation, synthetische Daten» | «freigegeben für reale Personen und Daten» |

**Ein Simulationsergebnis schliesst nie ein klinisches oder rechtliches Gate.**

### 6.3 Gates vor Phase B (übernommen aus V2.x §9.1)

| # | Gate | Entscheid durch | Status |
|---|---|---|---|
| PB-1 | Mandat für die klinische Regelfreigabe (D-43) | Founder | wartet auf Freigabe |
| PB-2 | Matrixzellen für die Pilot-Tätigkeiten freigegeben | Clinical Owner aus PB-1 | OPEN |
| PB-3 | Rechtliche Lesung der Matrix (L-1 bis L-6) | `lca` | OPEN |
| PB-4 | Prüfung der Qualifikationsnachweise (D-29) | Founder | wartet auf Freigabe |
| PB-5 | Erforderliche Fachfunktion je Konstellation, Heimbewilligung (D-25) | `lca`, Founder | OPEN |
| PB-6 | Vertrag, Rechtsform, Abrechnungsweg je Konstellation (D-44) | Founder nach `lca` | wartet auf Freigabe; Rechtsweg A bis D ungelöst |
| PB-7 | Plattformgebühr (D-14), B2B-Preise (FD-29) | Founder | wartet auf Freigabe |
| PB-8 | KI auf realen Daten (D-41); Konformitätsweg des separaten Dokumentationsmoduls (D-34 entschieden A plus C, Weg offen) | Founder | OPEN |
| PB-9 | Rechtsgrundlage Klienten- und Bewohnerdaten (D-9, D-3) | Founder (D-9); Clinical Owner (D-3) | wartet auf Freigabe |
| PB-10 | Pilotvertrag mit dem Heim (D-42), DSFA | Founder, Partner | OPEN |
| PB-11 | Technik: M2 konsolidiert, CI stabil grün (#919 geschlossen), M9.1 bis M9.3, QUAL1-Simulation bestanden (Wortlaut V2.x); Vorschlag V3: zusätzlich Staging und geprüfte Wiederherstellung (B11) | `eng`, `po` | in Arbeit |
| PB-12 | Go / No-Go mit der Bereitschaftsakte (G-1 bis G-25) | Founder | PLANNED |

---

## 7. Ist-Stand gegen Zielbild (Kette vom Auftrag bis zur Kennzahl)

Gelesen aus dem Code auf `recovery/main`, 2026-11-13. Engineering bestätigt oder korrigiert im Review.

| Schritt | Ziel | Ist | Status |
|---|---|---|---|
| Auftrag | Auftraggeber erfasst selbst, mit PLZ | Personal erfasst über `/intake`; `cases.plz` nur zur Anzeige | teilweise |
| Fall | Fall mit Lebenszyklus | `cases`, `case_lifecycle_events` | IMPLEMENTED |
| Matching | harte Filter inkl. PLZ-Distanz, Qualifikation, Verfügbarkeit, Merkmale; dann Ranking | exakter Regionsvergleich und Prüfung «diplomierte Pflegefachperson nötig»; keine Distanz, kein Ranking, keine Verfügbarkeitsprüfung im Angebot | teilweise; Rest PLANNED (BK) |
| Teamentscheid | ein Tipp, atomar | erstes Team übernimmt atomar mit Zeilensperre | IMPLEMENTED |
| Planung | Vorschlag, Teamentscheid, Ausfall | PLAN2, PLAN3, ABS1, COVER1 | IMPLEMENTED, nicht ausreichend getestet |
| Einsatz | mobil, offline | F1 bis F4, Zeitkorrektur | IMPLEMENTED; offline PLANNED |
| Dokumentation | Diktat → Entwurf → Signatur | Bericht, Rückgabe, Signatur; kein Diktat | teilweise |
| Qualität | Signale, Halte | `quality_events`, `quality_holds`, Sicherheitssignale P1 | IMPLEMENTED |
| Abrechnung | Rechnungsentwurf je Weg, drei Ledger | `billable_facts`, Tarife, Vorschau; keine Rechnung, keine Ledger | teilweise |
| Kennzahlen | Nordstern je Team | AN1 bis AN3, `/analytics`; der Nordstern selbst ist nicht messbar (D-23) | teilweise, nicht ausreichend getestet |

---

## 8. Offene Entscheide, die dieses Dokument nicht trifft

| Frage | Paket | Wer entscheidet |
|---|---|---|
| Rechtsform der Teams, Vertrag je Konstellation, Personalverleih oder Dienstleistung | D-44 | Founder nach `lca` |
| Höhe der Plattformgebühr; B2B-Preise | D-14, FD-29 | Founder |
| KI auf realen Daten, Anbieter, Region | D-41 (D-35 Regel A bis dahin) | Founder |
| KVG/KLV-Abrechnung, ärztliche Anordnung, Zeitregeln | D-22, D-18 | `lca`, Founder |
| Klinisches Freigabemandat, Matrixwerte | D-43, D-27 | Founder, Clinical Owner |
| Berechtigungsmatrix je Rolle | D-3 | wartet auf Freigabe durch den Clinical Owner (noch nicht benannt, G-1) |
| Engine 4 «automatische Rechnungsstellung»: Der PO liest sie als automatische **Vorbereitung** mit menschlicher Freigabe, weil automatische Abrechnungsentscheide verboten sind (`ARCHITECTURE.md`, KI-Säule) | — | Founder bestätigt die Lesart |
| Ein Portal P6 für Betreiber und Coach mit getrennten Rollen statt zwei Portalen | — | Founder bestätigt |
| Blöcke B4, B5, B7, B9 bis B12 laufen weiter wie in Kapitel 5.3 | — | Founder bestätigt |

---

## 9. Pflege dieses Dokuments

- Der PO führt V3.x als lebendes Arbeitsbuch: jede inhaltliche Änderung erhält eine Zeile in der Versionstabelle (Grund, Kapitel).
- Ein Widerspruch zu einer neueren Founder-Entscheidung wird im Journal gemeldet und hier nachgeführt, nicht still übergangen.
- Statusaussagen über Code werden von `eng` bestätigt; der PO schreibt keinen Code und führt keine Tests aus.
- Jeden Freitag aktualisiert der PO die Kennzahlen und `FOUNDER_EXECUTIVE_REPORT.md`.

### Versionstabelle

| Datum (Europe/Zurich) | Version | Was | Warum | Kapitel |
|---|---|---|---|---|
| 2026-11-13 | 3.0-Entwurf | Neufassung als geschlossenes Zielbild mit sechs Portalen, fünf Engines (Handbook), Lieferkette SAFE-D11 → B1.1-Abschluss → BK → B2 → B3 → B6 → B8, harten Gates; Ist-Stand aus dem Code | Founder-Anweisung FE-074 | alle |

Keine personenbezogenen oder Gesundheitsdaten in diesem Dokument. Alle Namen in Beispielen sind synthetisch.
