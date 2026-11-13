# NAVORA Architecture Blueprint V3.0

**Das verbindliche Arbeitsbuch für Produkt und Blockumsetzung**

| | |
|---|---|
| **Version** | 3.0 (Entwurf zur Founder-Freigabe), 2026-11-13 |
| **Verantwortlich** | Product Owner (`po`); Beiträge: Chief Strategy Architect (`csa`, Kap. 1-3), Engineering (`eng`, Kap. 4-7) |
| **Auftrag** | Founder-Anweisung vom 2026-11-13 (FE-075) |
| **Grundlage** | `FOUNDER_DECISIONS.md` FE-001 bis FE-075; Code-Inventar von `recovery/main` am 2026-11-13 (Kapitel 4-6); Blueprint V2.92 |
| **Geltung** | Bis zur Freigabe durch den Founder gilt Blueprint V2.x weiter. Nach der Freigabe ist V3 das führende Arbeitsbuch und V2 wird Archiv. Bei einem Widerspruch gilt die neueste Founder-Entscheidung (README Regel 10). |
| **Schwesterdokument** | [Architecture Handbook V2.0](../architecture/ARCHITECTURE_HANDBOOK_V2.md): WIE gebaut wird |

**Kennzeichnung.** Jede Zustandsaussage trägt eine der vier Marken:

- **IMPLEMENTED:** im Code auf `recovery/main` vorhanden.
- **PLANNED:** beschlossen, aber nicht gebaut.
- **OPEN:** Entscheidung ausstehend.
- **UNKNOWN:** nicht geprüft.

«Gebaut» ist nicht «abgenommen». Abgenommen ist nur, was nach Kapitel 7 auf einem benannten Commit belegt ist.

---

## 1. Vision, Disruption und Werteordnung

### 1.1 Was NAVORA ist

NAVORA ist das Betriebssystem für **selbstorganisierte Pflegeteams**. Heime, Spitäler und Privatpersonen geben ihren Bedarf direkt an ein Team. Das Team entscheidet selbst, pflegt, dokumentiert und rechnet ab. NAVORA liefert Software und KI und erhält dafür eine feste Abonnementsgebühr.

Damit löst NAVORA zwei Vermittlungsapparate ab:

- **die Spitex-Verwaltung:** Disposition, Hierarchie, Dokumentationslast;
- **das Temporärbüro:** Marge auf jeder Stunde, Telefonketten.

**Spitex-Organisationen und Temporärbüros sind weder Rolle noch Kunde noch Organisationsart in NAVORA** (FE-066). Der Anbieter ist das Team.

### 1.2 Wie die Disruption wirkt (Referenzfall, Hypothese)

Founder-Fallsimulation (FE-073 (5)): Pflegeheim in 4052 Basel, Krankmeldung um 14:15 für die Spätschicht 16:30–21:30 auf der Demenzabteilung.

| | Heute (Temporärbüro) | NAVORA |
|---|---|---|
| Erfassen | Stationsleitung telefoniert drei Büros ab | ein Satz oder Diktat; das Heim prüft die erkannten Felder und bestätigt |
| Zuordnen | das Büro entscheidet | harte Prüfung (Ort, Qualifikation, Verfügbarkeit, bestätigte Demenzerfahrung), dann Empfehlung an das passende Team |
| Zusage | Rückruf | das Team übernimmt mit einem Tipp; das Heim sieht sofort «gedeckt» |
| Bericht | von Hand | 30 Sekunden Diktat; die KI erstellt einen Entwurf; die Pflegekraft prüft und signiert |
| Preis | Founder-Beispiel 75 CHF/h, davon 28 CHF/h an die Pflegekraft | Founder-Beispiel 52 CHF/h, ganz an das Team, 0 CHF Provision |

**Die Zahlen sind Founder-Beispielwerte und keine Tarife.** Dass Pflegende mehr verdienen und Heime weniger zahlen, ist die zentrale **Hypothese**. Sie wird mit realistischen Kosten- und Vergütungsmodellen geprüft und **nicht als bewiesen dargestellt** (FE-040 (1), FE-032). Abzüge des Teams (Sozialversicherungen, Versicherung, Abo, Steuern) sind in den 52 CHF nicht berücksichtigt. Das Kostenmodell erarbeiten `csa` und `lca`.

### 1.3 Werteordnung (verbindlich)

**Patientensicherheit ist Voraussetzung und wird nie verrechnet.** Danach gilt diese Reihenfolge:

1. mehr direkte Pflegezeit
2. bessere Kontinuität der Versorgung
3. höheres Nettoeinkommen der Pflegenden
4. Teamautonomie
5. weniger Administration
6. bessere Patientenergebnisse
7. operative Skalierbarkeit
8. Plattformvollständigkeit
9. Umsatz
10. Bequemlichkeit für Engineering

### 1.4 Nordstern und Massstab

- **Nordstern:** Anteil direkter Pflegezeit je Team und Monat (Kennzahl M-13).
- **Hypothesen:** Buurtzorg-Massstab mindestens 60 %, NAVORA-Ziel 75 %. Ein echter Wert entsteht erst in Phase B.
- **Buurtzorg** ist die Messlatte, die NAVORA übertreffen will: KI übernimmt die Koordination, die dort noch Menschen leisten.

### 1.5 Was NAVORA nie baut

- **keine zentrale Disposition und kein «für das Team zuteilen»** (Produkt-Invariante, FE-039). Die KI schlägt vor, das Team entscheidet.
- **keine hierarchische Aufsicht.** Der Coach vermittelt bei Konflikten und Engpässen und hat keinen allgemeinen Zugriff auf Gesundheitsdaten.
- **keine Provision auf Pflegeumsätze**, weder als Prozentsatz noch je Stunde (FE-055 (3)).
- **keine erfundenen medizinischen, rechtlichen oder tariflichen Regeln.** Eine klinische Regel gibt nur der Clinical Owner frei (D-27, D-43).

---

## 2. Die KI als operatives Rückgrat

### 2.1 Grundsatz: zuerst deterministisch, dann KI, immer der Mensch

Jeder KI-gestützte Ablauf folgt derselben Reihenfolge (`AI_FIRST_ARCHITECTURE_UPDATE.md`):

**Unnötiges entfernen → Regeln anwenden → laufend überwachen → KI bereitet vor → Mensch prüft → Mensch entscheidet → Mensch signiert.**

| Bereich | Regeln (deterministisch) | KI bereitet vor | Mensch entscheidet oder signiert |
|---|---|---|---|
| **Erfassung** | Pflichtfelder, PLZ-Liste, Schichtlogik (auch über Mitternacht) | Felder aus Sprache oder Freitext erkennen | der Auftraggeber bestätigt |
| **Matching** | PLZ-Distanz, Qualifikation nach Matrix, Verfügbarkeit, bestätigte Merkmale | Rangfolge **nur unter den Geeigneten**, Begründung in Worten | das Team übernimmt |
| **Koordination** (statt Disposition) | Kontinuitäts-Standard, Lücken, Ausfälle | Tagesvorschlag, Vertretungsvorschlag | das Team bestätigt jeden Wert (AIG1) |
| **Dokumentation** | Pflichtteile, Signaturstatus | Berichtsentwurf aus dem Diktat, jeder Satz mit Quelle | die Pflegekraft signiert |
| **Abrechnung** | Stunden × Preis, Doppelabrechnung, Zeitkonflikte | Erklärung der Abweichungen | das Team gibt die Rechnung frei |
| **Sicherheit** | Signale, Fristen, Eskalation | – | die zuständige Person handelt |

**Ein KI-Score überspielt nie eine fehlende Qualifikation, Lizenz oder Delegation.** Die KI kann eine Rangfolge ordnen, aber kein Team hinzufügen.

### 2.2 KI und Daten (verbindlich)

- **D-35 Regel A gilt:** Keine Klienten- oder Personaldaten gehen an einen KI-Dienst (FE-024).
- **Gewählte Muster** (FE-051):
  - Muster 1: Planung nur mit Kennungen.
  - Muster 2: nur Team-Kennzahlen.
  - Muster 3: strukturierte Erfassung, Bericht per Regel.
  - Muster 4: eigenes Sprachmodell im Schweizer NAVORA-Rechenzentrum. Wird mit synthetischen Daten vorbereitet und getestet; für echte Daten erst nach Rechtsgutachten und DSFA.
  - Muster 5 (Pseudonymisierung für externe KI) ist **nicht** gewählt.
- **Phase A:** Jede KI arbeitet ausschliesslich mit synthetischen Daten.
- **Stand heute:** Es gibt im Code keinen Aufruf eines KI- oder Sprachdienstes. Beide registrierten «Agenten» sind regelbasiert. Die Governance (Vorschlagsbuch, Bestätigung je Wert, Stopp, Rückblick) ist **IMPLEMENTED** (AIG1).

---

## 3. Das NAVORA-Finanz- und Geschäftsmodell

### 3.1 Zwei Geschäftsmodelle (FE-040, FE-055)

| | **GM-1 Teamgeschäft** | **GM-2 B2B-Software** |
|---|---|---|
| Kunde | Heim, Spital oder Privatperson erteilt einem Team einen Auftrag | Heim oder Spital für die eigene Belegschaft |
| Leistung | das Team pflegt und rechnet über eine rechtlich geeignete Struktur ab | Module (3.2) |
| NAVORA-Erlös | **feste monatliche Plattformgebühr je Teammitglied oder Team**, gewichtet nach effektivem Pensum (VZE); **Höhe OPEN** (D-14; Founder-Beispiel 120 CHF/Monat) | Softwarelizenz je Modul; **Preis OPEN** |
| Verboten | Provision in Prozent, Betrag je Stunde, jeder Anteil an der Pflegevergütung | – |
| Rechtsform | **OPEN** (D-44; z. B. Genossenschaft; Entscheid des Founders) | – |

### 3.2 Modulares B2B-Portfolio (GM-2)

| Modul | Inhalt | Status |
|---|---|---|
| **1 Kern: KI-Planung** | vorausschauende Schicht- und Einsatzplanung, Ausfallkoordination; das Team bestätigt | Planung und Ausfall ambulant **IMPLEMENTED** (PLAN3, ABS1, COVER1); Schichtmodell Heim **PLANNED** (NH-A1) |
| **2 Add-on: KI-Protokoll** | Diktat → konformer Berichtsentwurf → zwingende menschliche Signatur | Signatur und Rückgabe **IMPLEMENTED** (F6, F6R, F7); Diktat und KI-Entwurf **PLANNED** (B6) |
| **3 Add-on: Angehörigenportal** | berechtigte, strukturierte Updates und Fotos an Angehörige; nicht laufend; schützt die Pflegenden vor Unterbrechungen; getrennt von der klinischen Akte; keine ungeprüften medizinischen Aussagen | **PLANNED** (kein Brief) |

### 3.3 Strikte Trennung der drei Erlösströme

| Strom | Gehört | Beleg | Ledger | Dashboard |
|---|---|---|---|---|
| **Pflegeerlös** | dem Team | Rechnung des Teams an den Auftraggeber | Team-Ledger | Team-Dashboard |
| **NAVORA-Abo-Umsatz** | NAVORA | Abo-Rechnung an das Team | NAVORA-Ledger A | Betreiber-Cockpit |
| **NAVORA-B2B-Umsatz** | NAVORA | Lizenzrechnung an das Heim oder Spital | NAVORA-Ledger B | Betreiber-Cockpit |

- Die Trennung ist im Datenmodell erzwungen und getestet (FE-055 (2), Brief GMSEP).
- Eine Pflegerechnung enthält nie eine NAVORA-Position.
- Kein Betreiber-Dashboard zeigt Pflegeerlöse einzelner Teams, nur aggregierte Zählwerte.

**Stand:** Abrechenbare Fakten und eine Umsatzvorschau sind **IMPLEMENTED** (J5). Rechnungen, Abo-Ledger und B2B-Ledger sind **PLANNED**.

---

## 4. Die sechs Plattform-Portale

| Portal | Route (Ziel) | Nutzende | Zweck | Heute im Code | Status |
|---|---|---|---|---|---|
| **Auftraggeber-Portal** | `/order` | Heim, Spital, Privatperson | Bedarf per Sprache oder Text, erkannte Felder bestätigen, Stand «gedeckt / nicht gedeckt», Rechnungen | `/partners` und `/intake` werden von Operations bedient; keine Auftraggeber-Rolle | **PLANNED** (BK) |
| **Team-Dashboard** | `/team` | selbstorganisiertes Team | Angebote mit Begründung, Teamentscheid, Planung, Kontinuität, Team-Finanzen | `/team`, `/team/tagesplan`, `/team/vorschlaege`, `/teams` | **IMPLEMENTED** (Angebotskarte BK **PLANNED**) |
| **Caregiver Mobile** | `/field` | Pflegekraft | nächster Einsatz, Zeit, Aufgaben, Diktat, Signatur; offline-first | `/field`, `/work`, `/visits` | **IMPLEMENTED** (Diktat **PLANNED**; offline-first **UNKNOWN**) |
| **B2B-Heimsuite** | `/b2b-institution` | Heim oder Spital für die eigene Belegschaft | Schichtplanung, Ausfall, Protokoll (GM-2-Module) | – | **PLANNED** (B9, GM-2) |
| **Angehörigen-Ansicht** | `/family` | berechtigte Angehörige | strukturierte Updates, keine klinische Akte | – | **PLANNED** |
| **Betreiber- und Coach-Cockpit** | `/platform` | NAVORA-Betrieb, Coach | SaaS-Kennzahlen, Teamgesundheit (aggregiert), Systemausnahmen; der Coach vermittelt ohne Aufsicht und ohne Akteneinsicht | `/operations` (Ausnahmen), `/analytics`, `/admin` | **PLANNED** als Zusammenführung; Teile **IMPLEMENTED** |

**Rollentrennung.** Jedes Portal sieht nur seine Daten (Handbook §6):

- Kein Team sieht die Daten eines anderen Teams.
- Ein Auftraggeber sieht seine eigenen Aufträge und deren Stand.
- Angehörige sehen nur freigegebene Updates.
- Betrieb und Coach sehen Zählwerte und Ausnahmen, keine Pflegeinhalte.

**Operations** bleibt in Phase A eine **Ausnahmestelle** (nur was niemand übernimmt) und kein Disponent. Ziel ist, dass im Normalfall niemand bei Operations eingreift (Kennzahl M-12).

---

## 5. Der durchgehende Kernablauf

Der Kernablauf gilt für jeden Auftrag, nicht für einen Einzelfall (FE-074). Brief: [`briefs/BK.md`](../agents/briefs/BK.md).

| # | Schritt | Wer | Engine | Status |
|---|---|---|---|---|
| 1 | Bedarf erfassen (Sprache oder Text) → KI erkennt Felder → Auftraggeber bestätigt | Auftraggeber | E2 (Erfassung) | **PLANNED** (BK-1) |
| 2 | Harte Prüfung: PLZ-Distanz, Qualifikation nach Matrix, Verfügbarkeit, bestätigte Merkmale | System | E1 | Region und Pflichtqualifikation **IMPLEMENTED**; PLZ-Distanz, Matrix im Matching und Merkmale **PLANNED** |
| 3 | Rangfolge unter den Geeigneten, Begründung in Worten | System | E2 | **PLANNED** (BK-3, BK-4) |
| 4 | Angebot zuerst an das beste Team (Kaskade mit exklusivem Zeitfenster), nie stilles Warten | System → Team | E1, E5 | heute sehen alle geeigneten Teams das Angebot (**IMPLEMENTED**); Kaskade **PLANNED** (BK-5) |
| 5 | Teamentscheid mit einem Tipp; der Auftraggeber sieht «gedeckt» | Team | E1 | Teamentscheid **IMPLEMENTED** (J2); Anzeige für den Auftraggeber **PLANNED** |
| 6 | Einsatz: Zeit, Aufgaben | Pflegekraft | – | **IMPLEMENTED** (F1-F4) |
| 7 | Diktat → KI-Berichtsentwurf | Pflegekraft | E3 | **PLANNED** (B6, BK-8) |
| 8 | Prüfung und Signatur | Pflegekraft | – | **IMPLEMENTED** (F6, F7) |
| 9 | Rechnung des Teams an den Auftraggeber, ohne Provision | Team | E4 | Fakten **IMPLEMENTED** (J5); Rechnung **PLANNED** (BK-9) |
| ∞ | Nicht gedeckt, überfällig, Sicherheitssignal → Eskalation | System | E5 | Signale **IMPLEMENTED** (SIG1, SIG2, OPS1); «nicht gedeckt» je Auftrag **PLANNED** (BK-6) |

---

## 6. Die verbindliche Block-Lieferkette (sequenzieller Masterplan)

**Es ist genau ein Block aktiv** (README Regel 12). Vorbereitung, also Briefs, ADRs und rote Tests auf Branches, läuft parallel. Konkurrierende Feature-Merges sind verboten.

| Schritt | Block | Inhalt | Status am 2026-11-13 |
|---|---|---|---|
| 0 | **SAFE-D11** | ein wiedereröffneter Fall ohne Team geht nie verloren | **abgenommen** für Simulation, synthetische Daten (`29e54ec`, 20/20) |
| 0b | **B1.1 (verkürzt)** | Regionsliste, Altwert-Absicherung (#1181, #1184), Seed nur BS/BL mit PLZ | **aktiv**; #1181 wartet auf die Gates `lca` und `uxa`; Abnahme auf dem Merge-Commit von B1.1-1c |
| 1 | **BK** | universeller Auftragsdurchstich: Erfassung → Prüfung → Empfehlung → Teamentscheid → `/field` → Bericht → Rechnung; Szenario-Matrix | **genehmigt**, startet nach B1.1 |
| 2 | **B2-Kern** | Qualifikationsmatrix auf jedem Zuteilungsweg, Nachweise, Delegation | QUAL1 Teil 1-2 **IMPLEMENTED** (nur Simulation); Matrix **PROPOSED** |
| 3 | **B3** | Team- und KI-Planung, Ausfallkoordination, Kontinuität | **IMPLEMENTED**, nicht als Block abgenommen |
| 4 | **B6** | Diktat, KI-Dokumentationsentwurf, menschliche Freigabe | Signatur **IMPLEMENTED**; Diktat und Entwurf **PLANNED** |
| 5 | **B8** | Finanzen: Rechnung, Validierung, Doppelabrechnung, drei getrennte Ledger | **PLANNED** (BILL1, GMSEP) |
| danach | B5 Sicherheitssignale · B9 Pflegeheim-Betrieb · B10 Kennzahlen · B4-Rest · B1.1-2 bis -5 | Vertiefung und Sonderfälle (FE-073 (4)) | gemäss `PRODUCT_BLOCKS.md` |
| Abschluss Phase A | **B11** | Staging, Wiederherstellung, Gesamttest beider Abläufe | **PLANNED** (D-2; Staging wartet auf ein Owner-Secret) |
| Tor zu Phase B | **B12** | Clinical Owner, Rechtsgutachten, Pilotvertrag, externer Sicherheitstest, KI-Pfad, Produktion | **OPEN**, Founder |

**Hinweis zur Kette (PO).** BK nimmt von B2, B3, B6 und B8 je einen dünnen, durchgehenden Schnitt vorweg. Diese Blöcke vertiefen danach, was BK erstmals verbindet. B5 bleibt bestehen, weil die Eskalation ungedeckter Schichten patientensicherheitskritisch ist. Ihr Kern liegt schon in BK (BK-6).

---

## 7. Harte Gate-Kriterien

### 7.1 Merge und Abnahme (FE-071, README Regel 12)

1. **Spezifikation vor Bau.** Jeder Brief nennt:
   - Problem und Nutzen;
   - Umfang und Nicht-Ziele;
   - Rollen und Ansichten;
   - Abhängigkeiten;
   - positive und negative Abnahmetests;
   - nötige Prüfungen (UX, klinisch, rechtlich, Sicherheit);
   - die acht Fragen der Vision.
2. **Merge** eines Engineering-PR nur:
   - für den aktiven Block oder eine benannte Sicherheitsausnahme;
   - mit automatisierten Tests für das geänderte Verhalten;
   - mit grüner CI auf dem aktuellen Kopf;
   - mit den Gate-Zeilen der Rollen.
   CI auf dem Merge-Commit muss grün sein, sonst folgt ein Revert-PR.
3. **Abnahme** nur auf einem **benannten integrierten Commit**: `ci` grün und **`ci-repeat` 10/10** (`db`, `e2e`). Belegt wird aus den Roh-Logs; übersprungene oder abgebrochene Läufe zählen nicht.
4. **Jede Abnahme nennt ihr Gate:** «Simulation, synthetische Daten» oder «freigegeben für reale Personen und Daten».

### 7.2 Phase A und Phase B (strikt getrennt)

| | Phase A (jetzt bis M9, 2027-03-12) | Phase B (später) |
|---|---|---|
| Partner | simuliert: Pflegeheim-Abteilung, ambulante Teams, Auftraggeber in Basel-Stadt und Basel-Landschaft | reale Pilotorganisation, nach heutiger Richtung ein Pflegeheim |
| Daten | **nur synthetisch** (FE-021, FE-066); Testumgebungen auf Produktionsniveau geschützt | reale Daten erst nach allen Toren |
| KI | nur synthetische Eingaben | erst nach D-41 (Muster 4, Rechtsgutachten, DSFA) |
| Regeln | Matrix und klinische Regeln PROPOSED | vom Clinical Owner freigegeben (D-43) |

**Tore vor realen Daten (B12):**

- Clinical Owner ernannt (G-1, D-43);
- Rechtsgutachten Q1 2027 (FE-050: D-18, D-22, D-42, D-44, D-41);
- Pilotvertrag;
- externer Sicherheitstest (FE-049);
- Repository privat (D-7);
- Staging und belegte Wiederherstellung (B11);
- DSFA.

---

## 8. Meilensteine und Termine

| Meilenstein | Ziel | Stand |
|---|---|---|
| Lieferung 2 / 3 / 4 | 13.11. / 16.11. / 17.11.2026 (FE-072 (6)) | Lieferung 2 ist dieses Dokumentpaar |
| M9 Phase A bestanden | **2027-03-12**: beide Abläufe (ambulant und Heim) und der BK-Auftragsablauf auf einem benannten Commit im Staging, alle Stoppfälle belegt | in Arbeit |
| M10 Produktionsbereitschaft | Tore aus §7.2 | **OPEN** |

Die Prozentwerte je Meilenstein (Formel V2 §4.0) führt der PO wöchentlich weiter. Die Detailtabellen M1 bis M10 bleiben bis zur Übernahme in V3.1 in V2 §4.

---

## 9. Wirkungs- und Steuerungskennzahlen (wöchentlich, freitags 12:00)

| Kennzahl | Was | Wert |
|---|---|---|
| M-13 Nordstern | Anteil direkter Pflegezeit je Team und Monat | 1 |
| M-15 / M-16 | Administrationsminuten je Einsatz; Zeit bis zum finalen Bericht | 1, 5 |
| M-11 / M-17 | menschliche Handlungen je Planung und Ausfall | 4, 5 |
| M-12 / M-20 | Eingriffe von Operations; Entscheide im Team | 4 |
| M-19 | Kontinuität (Bezugspflege-Anteil) | 2 |
| M-18 | Abrechnungsfehler und manuelle Ausnahmen | 5, 9 |
| M-21 / M-10 | Sicherheitsindikatoren; offene blockierende Befunde | Sicherheit |
| M-02 / M-03 / M-14 | Merge-Warteschlange, Durchlaufzeit, CI-Gesundheit | 8 |
| **neu (BK)** | Minuten von der Erfassung bis «gedeckt»; Anteil gedeckter Aufträge; Handlungen je Auftrag (Auftraggeber, Team, Pflegekraft) | 1, 4, 5 |

Alle Werte gelten je Team und nie je Person. In Phase A sind es synthetische Werte.

---

## 10. Founder-Entscheidungsboard (offen)

| # | Frage | Wirkt auf |
|---|---|---|
| D-14 | Höhe der Plattformgebühr (Variante F3/F6 nach VZE) | Kap. 3, Abo-Ledger |
| D-44 | Rechtsform und Vertragsweg je Auftragskonstellation (Genossenschaft? Personalverleih?) | GM-1, BK-Rechnung, Phase B |
| D-41 | KI-Pfad für reale Daten (Muster 4: Rechenzentrum, Gutachten, DSFA) | E2, E3 |
| D-2 | Hosting-Wahl für Staging und Produktion | B11 |
| STG1 | Owner-Secret `STAGING_DB_URL` für das Staging | B11 |
| B0-6 | Repository-Schutz (Ruleset) | B12 |
| G-1 / D-43 | Ernennung des Clinical Owners | Matrix, klinische Regeln, Phase B |
| GM-2 | Preis und Reihenfolge der B2B-Module; Angehörigenportal-Brief | Kap. 3.2 |

---

## 11. Rollen

| Rolle | Verantwortung |
|---|---|
| `po` | WAS, WARUM, WANN; einzige Merge-Instanz; Abnahme mit Belegen; dieses Dokument |
| `eng` | WIE; Code, Migrationen, Tests, ADRs; Architecture Handbook |
| `cra` | klinische Sicherheit und Dokumentation; Gate je PR |
| `lca` | Recht, Datenschutz, Tarife, Verträge; Gate je PR |
| `uxa` | UX, Texte, 390/1440 px; Gate je PR |
| `aia` | KI-Verträge (Eingabe, Ausgabe, Stopp-Regel) |
| `csa` | Strategie, Geschäftsmodell, Markt; Kapitel 1-3 |
| Founder | Strategie, Preis, Recht, Verträge, Einstellungen, Freigabe dieses Dokuments |

---

## 12. Pflege dieses Dokuments

- Der PO hält das Dokument lebendig:
  - Versionszeile je Änderung;
  - Grund und betroffene Kapitel;
  - Abgleich mit `FOUNDER_DECISIONS.md`, `PRODUCT_BLOCKS.md`, `NEXT_CAPABILITY.md`.
- **Kein Inhalt wird still geändert.** Eine Founder-Entscheidung wird nur durch eine neuere ersetzt.
- Freitags schreibt der PO aus Kapitel 9 den `FOUNDER_EXECUTIVE_REPORT.md`.

### Versionen

| Datum | Version | Änderung | Grund |
|---|---|---|---|
| 2026-11-13 | 3.0 Entwurf | Neufassung von Grund auf: Vision, Geschäftsmodell, sechs Portale, Kernablauf, Lieferkette, Gates | Founder-Anweisung FE-075 |
