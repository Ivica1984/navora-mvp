# NAVORA Geschäftsmodelle, Auftrags- und Betriebskonstellationen

**Besitzer:** Product Owner (`po`) · **Version:** 1.0, 2026-11-06 22:30 (Europe/Zurich) · **Auslöser:** Founder-Nachricht vom 2026-11-06 (begleitete Sitzung), festgehalten als **FE-040** in [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md) · **Arbeitsbuch:** Blueprint §1.5 ([`ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md`](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md)) · **Zahlen:** [`ECONOMICS_COMPARISON.md`](ECONOMICS_COMPARISON.md) · **Rechts- und Vertragsfragen:** Paket [D-44](../agents/decisions/D-44.md)

**Kennzeichnung:** IMPLEMENTED (im Code auf `recovery/main`), PLANNED (Brief oder Paket vorhanden), OPEN (Entscheid oder Antwort fehlt), UNKNOWN (nicht belegt). Eine Aussage über Recht, Abrechnung oder klinische Befugnis ist hier **nie** eine Feststellung: sie ist eine Arbeitshypothese, die `lca` (rechtlich) bzw. `cra` mit der klinischen Freigabefunktion (D-43) prüft. Eine Simulation mit synthetischen Daten ist **keine Freigabe** für reale Pflegeeinsätze.

---

## 0. Bestätigung in eigenen Worten (PO)

NAVORA hat **zwei getrennte Geschäftsmodelle**:

1. **Teamgeschäft (GM-1):** Ein selbstorganisiertes Pflegeteam ist selbst der Leistungserbringer. Ein Pflegeheim, ein Spital oder eine Privatperson erteilt dem Team direkt einen Auftrag, statt über ein Temporärbüro oder eine vermittelnde Organisation zu gehen. Das Team plant, erbringt und rechnet die Leistung über die rechtlich zulässige Struktur ab. Die Vergütung für die Pflege gehört dem Team bzw. seiner Trägerstruktur, **nicht NAVORA**. NAVORA liefert Software und KI und erhält dafür eine **transparente Gebühr**. KI-Planung und Ausfallkoordination sind dabei fester Bestandteil, kein Zusatzverkauf. Ziel ist, vermeidbare Vermittlungs- und Verwaltungskosten zu senken, damit mehr Wertschöpfung bei den Pflegenden bleibt. Ob und wie stark ihr Einkommen steigt, ist eine **Hypothese**, die mit realen Kosten und Tarifen zu prüfen ist (HYP-3, FE-032).
2. **B2B-Softwaregeschäft (GM-2):** Ein Pflegeheim oder Spital kauft NAVORA für **seine eigenen Mitarbeitenden**, ohne ein externes Team zu beauftragen. Angeboten werden die KI-Planung und Ausfallkoordination (dieselbe Fähigkeit wie im Teamgeschäft) und als **separates Add-on** die KI-gestützte Diktat-, Protokoll- und Berichtserfassung mit menschlicher Prüfung und Freigabe. Umsatz ist hier eine Softwarelizenz der Einrichtung an NAVORA. Es gibt keine Teamvergütung.

**Die beiden Umsatzströme werden nie vermischt** (§3): Pflegevergütung (Team), Plattformgebühr (Team an NAVORA) und Softwarelizenz (Einrichtung an NAVORA) sind drei getrennte Positionen mit getrennten Verträgen, Rechnungen und Kennzahlen.

**Konstellationen:** Ein Heim, das ein **externes Team für einzelne Einsätze** beauftragt (KON-1), ist etwas anderes als ein Heim, das **seinen ganzen Pflegealltag** mit NAVORA führt (KON-2), und beides ist etwas anderes als ein Heim oder Spital, das **nur ein Softwaremodul** kauft (KON-5). Beim Spital unterscheide ich den Einsatz im Spital vom **Versorgungsübergang** nach Hause (KON-3). Bei der Privatperson unterscheide ich, **wer beauftragt, wer gepflegt wird und wer zahlt** (KON-4). Dass ein Einsatz im Heim oder Spital zusätzlich bei einer Krankenkasse abgerechnet werden kann, **unterstelle ich nicht** (§2, D-44).

**Selbstorganisation** heisst: Das Team plant und entscheidet seine Einsätze selbst, ohne Dispositionshierarchie. Sie heisst **nicht**, dass jede Person jede Tätigkeit ausführen darf. Fachliche Befugnis je Tätigkeit, eine allenfalls vorgeschriebene fachverantwortliche Funktion, die formelle Verantwortung einer Einrichtung und die Vertrags- und Rechnungsrolle sind **fünf verschiedene Ebenen** (§1). Sie werden nicht durch KI oder Selbstorganisation ersetzt.

Dass Pflegeheime zur Vision gehören, ist entschieden (FE-024, FE-031) und wird nicht erneut gefragt.

---

## 1. Rollenmodell: fünf Ebenen, nie vermischt

| Ebene | Frage | Wer entscheidet | Was NAVORA tut | Status |
|---|---|---|---|---|
| **R1 Operative Planung** | Wer übernimmt welchen Einsatz, wer vertritt bei Ausfall? | das selbstorganisierte Team nach seinen Regeln | KI schlägt innerhalb der Regeln vor (PLAN3, Ausfall), Team bestätigt, ändert oder lehnt ab; alles protokolliert | IMPLEMENTED für den Tagesplan (PLAN3 Teil (a), #872, #876); Ausfall: ABS1, COVER1 IMPLEMENTED; Qualifikationsprüfung je Tätigkeit PLANNED (QUAL1) |
| **R2 Fachliche Befugnis je Tätigkeit** | Darf diese Person **diese Tätigkeit bei diesem Klienten** eigenständig (E), nur mit Delegation (D), nicht (–), oder ist die Regel offen (?)? | eine geprüfte Regel der Qualifikations- und Tätigkeitsmatrix (QAM), vorbereitet von `cra` mit `lca`, freigegeben durch die Funktion aus D-43; die **Delegation** erteilt eine befugte Pflegefachperson, nie die KI | prüft die Regel in der Datenbank auf **jedem** Zuteilungsweg; die KI schlägt nur vor, wer die Regel erfüllt | PROPOSED (Matrix v0.1, CR-174 bis CR-178); im Code heute strenger: Kategorie B und Bedarfsabklärung nur `registered_nurse` (CR-007, CR-164) |
| **R3 Fachlich verantwortliche Person/Funktion** | Verlangt das Recht eine benannte fachverantwortliche Person (z. B. Pflegedienstleitung im Heim BS, pflegefachverantwortliche Person BL)? | `lca` (Pflicht und Inhalt), `cra` (fachlicher Zuschnitt), Owner (Besetzung) | bildet die Funktion ab: genehmigt die Matrixversion der Organisation, liest und widerruft Delegationen, ist Eskalationsstelle; **plant niemanden** | OPEN (CR-178, CGR-146, D-25, L-2) |
| **R4 Formelle Verantwortung der Einrichtung** | Wer trägt die Betriebsbewilligung, die Versorgungs- und Aufsichtspflicht gegenüber Bewohnenden oder Patienten? | Recht und Bewilligung (Kanton); Einrichtung | hält fest, welche Einrichtung im Einsatz die Verantwortung trägt; ändert sie nicht | OPEN je Konstellation (D-25, D-44) |
| **R5 Vertragliche Rolle und Rechnungssteller** | Wer schliesst den Vertrag mit wem, wer stellt wem Rechnung? | die Vertragsparteien in der rechtlich zulässigen Struktur | bereitet Rechnungen aus **bestätigten** Leistungen und geprüften, versionierten Regeln vor; erfindet nichts; Unklares wird angehalten | OPEN (D-44, D-12, D-18) |

**Varianten für R3 (mit `cra` und `lca` zu prüfen, nicht entschieden):**

| Variante | Inhalt | Folge für die Selbstorganisation | Risiko |
|---|---|---|---|
| R3-a | Eine Pflegefachperson HF/FH **im Team** übernimmt die vorgeschriebene Funktion zusätzlich (rotierend oder fest), ohne Dispositionsrecht | Team bleibt autonom; Funktion fachlich, nicht hierarchisch | erfüllt sie die kantonale Anforderung (Erfahrung, Bewilligung, Weisungsbefugnis)? L-2 |
| R3-b | Eine **netzwerkweite** fachverantwortliche Person für mehrere Teams (Coach-Modell, wie Buurtzorg-Regionalcoach, aber fachlich) | Teams autonom; eine Person für viele Teams | Reichweite, Erreichbarkeit, Haftung; reicht eine Person für mehrere Bewilligungen? |
| R3-c | Die **auftraggebende Einrichtung** behält ihre Funktion (Heim-PDL) und das Team arbeitet unter deren Fachaufsicht nur für die vereinbarten Tätigkeiten | Team autonom in der Einsatzplanung, fachlich in die Einrichtung eingebunden | starkes Indiz für **Personalverleih** (Weisungsrecht beim Einsatzbetrieb, D-44 / L-7) |
| R3-d | Externe fachverantwortliche Stelle im Auftrag (Dienstleister) | Team autonom | Zulässigkeit und Qualität UNKNOWN |

---

## 2. Die fünf Konstellationen

**Allgemein für alle Teamkonstellationen (KON-1, KON-3, KON-4):** Welche Rechtsform das Team hat (z. B. eigene GmbH oder Genossenschaft der Pflegenden, Anstellung bei einem bewilligten Leistungserbringer wie im D-12-Partnermodell, oder Selbständigkeit der einzelnen Pflegefachpersonen) ist **OPEN** (D-44, D-12, FD-25). Davon hängen Bewilligung, Sozialversicherung, Haftpflicht, Abrechnungsberechtigung und die Frage der Scheinselbständigkeit ab. Die Tabellen zeigen deshalb Varianten, keine Festlegung.

### KON-1 · Pflegeheim beauftragt ein externes selbstorganisiertes Team für bestimmte Einsätze (z. B. Ausfall überbrücken)

| Aspekt | Inhalt | Status |
|---|---|---|
| Auftraggeber | das Pflegeheim | – |
| Leistungsempfänger | Bewohnende des Heims (die Pflege), das Heim (die Arbeitsleistung bzw. Dienstleistung) | – |
| Leistungserbringer | das externe Team (seine Mitglieder) | – |
| Zahler | das Heim; **nicht** zusätzlich die Krankenkasse | Arbeitshypothese: Im Heim zahlt die OKP Beiträge an das **Heim** nach Pflegebedarfsstufe (KLV Art. 7a Abs. 3); ein externes Team rechnet dieselbe Pflege nicht zusätzlich ab. Zu prüfen: L-8 |
| R2 fachliche Befugnis | Matrix je Tätigkeit; Delegation durch eine befugte Pflegefachperson (des Teams oder des Heims, je Variante) | PROPOSED |
| R3 / R4 | Heim behält Bewilligung und Pflegedienstleitung (BS: PDL mit HF/FH-Abschluss; BL: pflegefachverantwortliche Person) [Matrix Q6, Q7] | belegt für die Bewilligung; Zusammenspiel mit dem Team OPEN (CGR-146) |
| R5 Vertrag | **Variante V-1:** Personalverleih (Team bzw. seine Trägerstruktur verleiht Personal; Weisungsrecht beim Heim): braucht ab Gewerbsmässigkeit eine **Verleihbewilligung** nach AVG und unterliegt dem GAV Personalverleih [W2]. **Variante V-2:** Auftrag/Dienstleistung mit klar umrissenem Leistungsinhalt in eigener fachlicher Verantwortung des Teams (z. B. eine ganze Station oder Schicht mit eigener fachverantwortlicher Person): Abgrenzung nach Weisungsrecht, Eingliederung, Abrechnung nach Stunden oder Pauschale, Risikotragung [W2] | OPEN (L-7) |
| Rechnungsweg | Team (bzw. Trägerstruktur) → Heim; Heim rechnet seine Bewohnenden wie heute ab (OKP-Beitrag nach Stufe, Restfinanzierung, Bewohnerbeitrag) | Arbeitshypothese (L-8) |
| Einnahmen Team | vereinbarter Preis pro Stunde, Schicht oder Pauschale; davon gehen Sozialversicherung, Versicherung, Verwaltung und NAVORA-Gebühr ab | Rechnung in `ECONOMICS_COMPARISON.md` §2 (Annahmen markiert) |
| Einnahmen NAVORA | Plattformgebühr **vom Team** (Modell D-14 offen); **keine** Gebühr vom Heim, **kein** Anteil an der Pflegevergütung | OPEN (D-14) |
| Was NAVORA ersetzt | Vermittlungsmarge des Temporärbüros, Telefon- und Mailkette bei Ausfall, manuelle Suche (Ausfall-Simulationsfall, QUAL1) | Hypothese |

### KON-2 · Pflegeheim nutzt NAVORA für seinen gesamten Pflegealltag (eigene Teams)

| Aspekt | Inhalt | Status |
|---|---|---|
| Auftraggeber | das Heim (Softwarekunde, Gesamtbetrieb) | – |
| Leistungserbringer der Pflege | die **eigenen** Mitarbeitenden des Heims, organisiert als selbstorganisierte Stationsteams | FE-031 (simulierte Station Phase A) |
| Zahler der Pflege | wie heute: OKP-Beitrag nach Stufe an das Heim, Restfinanzierung (Kanton/Gemeinde), Bewohnerbeitrag | bestehende Ordnung; NAVORA ändert sie nicht |
| Zahler NAVORA | das Heim: **Softwarelizenz** für die Betriebsplattform (Planung, Ausfall, Qualifikationsabgleich, Dokumentation, Assessment, Pflegeplanung, abrechnungsrelevante Abläufe) | Preis OPEN (FD-29) |
| R1 | Stationsteams planen selbst | Phase A simuliert (NH-A) |
| R2 | Matrix je Tätigkeit, Delegation intern | PROPOSED |
| R3 / R4 | Heim mit Bewilligung und vorgeschriebener PDL bzw. pflegefachverantwortlicher Person; die PDL ist **fachliche** Funktion (R3), nicht Disposition (R1) | OPEN, ob die kantonale Rolle ohne Dispositionsrecht zulässig ist (D-25, L-2, CGR-146) |
| R5 | Lizenzvertrag Heim ↔ NAVORA; Auftragsbearbeitung nach DSG für Bewohnerdaten | OPEN (D-42 Pilotvertrag, D-41 KI auf echten Daten) |
| Einnahmen Team | **keine** Teamvergütung (Lohn der Mitarbeitenden durch das Heim) | – |
| Einnahmen NAVORA | Lizenz (Betriebsplattform) | OPEN |
| Unterschied zu KON-1 und KON-5 | kein externes Team (anders als KON-1); nicht ein einzelnes Modul, sondern der ganze Pflegealltag (anders als KON-5) | – |

### KON-3 · Spital beauftragt ein selbstorganisiertes Team für einen definierten Einsatz oder Versorgungsübergang

| Aspekt | **KON-3a Einsatz im Spital** | **KON-3b Versorgungsübergang (Austritt nach Hause)** |
|---|---|---|
| Auftraggeber | das Spital | das Spital (Zuweisung), bei ambulanter Pflege zu Hause mit ärztlicher Anordnung bzw. Bedarfsabklärung |
| Leistungsempfänger | Patientin im Spital | Patientin zu Hause |
| Leistungserbringer | externes Team | das Team als **zugelassener** Spitex-Leistungserbringer (oder über einen bewilligten Partner, D-12) |
| Zahler | das Spital (stationäre Vergütung des Spitals nach seiner Tarifstruktur); **keine** zusätzliche OKP-Abrechnung durch das Team unterstellt | OKP nach KLV Art. 7a (a/b/c), Restfinanzierung Kanton/Gemeinde, Patientenbeteiligung; BS-Tarife 2026 in `ECONOMICS_COMPARISON.md` [B1] |
| R3 / R4 | Spital trägt Verantwortung für die stationäre Behandlung | Team bzw. Trägerorganisation trägt die Verantwortung als Spitex-Leistungserbringer (Bewilligung, Art. 51 KVV) |
| R5 | wie KON-1 (Personalverleih oder Auftrag, L-7) | Pflegevertrag mit der Patientin; Rechnung an Versicherer (Tiers payant/garant gemäss Tarifvertrag, D-18) |
| Einnahmen Team | Preis an das Spital | Tarif nach KLV plus Restfinanzierung, abzüglich Kosten und Gebühr |
| Einnahmen NAVORA | Plattformgebühr vom Team | Plattformgebühr vom Team |
| Status | OPEN (L-7, L-8) | OPEN (D-12 Zulassungsweg, D-18 Tarif, D-22 ärztliche Anordnung, D-9 Datengrundlage); REF2 als Entwurf |

### KON-4 · Eine Privatperson beauftragt ein Team direkt

**Drei Rollen getrennt:** *Auftraggeber* (z. B. Tochter oder die Person selbst), *Leistungsempfänger* (die gepflegte Person), *Zahler* (Krankenkasse für KLV-Leistungen, Kanton/Gemeinde für die Restfinanzierung, die gepflegte Person für Patientenbeteiligung und nicht-KLV-Leistungen, ggf. Zusatzversicherung oder Angehörige privat).

| Fall | Auftraggeber | Empfänger | Zahler | Bedingungen | Status |
|---|---|---|---|---|---|
| KON-4a KLV-Pflege (Bedarfsabklärung, Behandlungs-, Grundpflege) | Person selbst oder Angehörige mit Vollmacht | die Person | OKP + Restfinanzierung + Patientenbeteiligung | zugelassener Leistungserbringer (Organisation Art. 51 KVV oder freiberufliche Pflegefachperson Art. 49 KVV), Bedarfsabklärung durch Pflegefachperson, je nach Leistung ärztliche Anordnung | OPEN (D-12, D-22, L-1) |
| KON-4b Betreuung und Haushalt (nicht KLV) | Person oder Angehörige | die Person | privat (ggf. Zusatzversicherung) | Abgrenzung zu KLV-Leistungen; Mindestlöhne für Betreuung im Haushalt je Kanton (UNKNOWN) | OPEN (FD-24 Bedeutung „Privatpersonen“) |
| KON-4c Auftrag durch Angehörige, Person urteilsunfähig | Vertretungsberechtigte Person | die Person | wie 4a/4b | Vertretungsrecht nach ZGB; Einwilligung und Information (D-9, D-40) | OPEN |

Einnahmen Team: Tarif bzw. Privatpreis abzüglich Kosten und Gebühr. Einnahmen NAVORA: Plattformgebühr vom Team; NAVORA stellt der Privatperson **keine** Rechnung.

### KON-5 · Heim oder Spital kauft ausschliesslich NAVORA-Software

| Aspekt | Inhalt | Status |
|---|---|---|
| Kunde | Heim oder Spital | – |
| Module | **M-PLAN** KI-Planung und Ausfallkoordination für eigene Mitarbeitende; **M-DOK** (Add-on) KI-gestützte Diktat-, Protokoll- und Berichtserfassung, Mitarbeitende prüfen, korrigieren und geben frei | M-PLAN baut auf PLAN3/ABS1/COVER1 (IMPLEMENTED Teile); M-DOK = DOC-AI (PLANNED, Umfang FE-028/AUT-54, D-34 Modul) |
| Leistungserbringer der Pflege | die Einrichtung mit eigenen Mitarbeitenden | – |
| R1 bis R4 | vollständig bei der Einrichtung; NAVORA setzt nur deren Regeln um | – |
| R5 | Lizenzvertrag; NAVORA ist Auftragsbearbeiterin nach DSG | OPEN (D-41: KI auf echten Daten erst nach Entscheid; D-35 Regel A bleibt; D-34 Medizinprodukte-Abgrenzung für M-DOK) |
| Einnahmen Team | keine | – |
| Einnahmen NAVORA | Lizenz je Modul, getrennt kalkuliert (`ECONOMICS_COMPARISON.md` §4) | Preis OPEN (FD-29) |

---

## 3. Umsatztrennung (verbindliche Produktregel, PO)

| Umsatzart | Von | An | Grundlage | Gehört | In NAVORA-Kennzahlen |
|---|---|---|---|---|---|
| **U-T Pflegevergütung** | Heim, Spital, Versicherer, Kanton/Gemeinde, Privatperson | Team bzw. seine Trägerstruktur | Auftrag/Pflegevertrag, Tarif | dem Team | nie als NAVORA-Umsatz; nur als Team-Kennzahl (Einkommen, HYP-3) |
| **U-N1 Plattformgebühr** | Team bzw. Trägerstruktur | NAVORA | Nutzungsvertrag, transparente Gebühr (D-14) | NAVORA | Umsatz Teamgeschäft |
| **U-N2 B2B-Lizenz** | Heim, Spital | NAVORA | Lizenzvertrag je Modul (M-PLAN, M-DOK, Betriebsplattform) | NAVORA | Umsatz Softwaregeschäft |

Regeln: (1) NAVORA nimmt **keinen prozentualen Anteil an der Pflegevergütung**, solange `lca` nicht geklärt hat, ob das als Vermittlung (AVG) oder als unzulässige Beteiligung gilt (L-10). (2) Falls Zahlungen technisch über NAVORA laufen, sind sie Durchlaufposten (Treuhand/Zahlungsdienst), nie Umsatz; ob das bewilligungspflichtig ist, ist UNKNOWN (L-10). (3) Ein Heim, das ein Team beauftragt (KON-1), schuldet NAVORA nichts; ein Heim, das Software kauft (KON-2, KON-5), schuldet keinem Team etwas.

---

## 4. Offene Rechts- und Vertragsfragen für `lca` (neu, zusätzlich zu L-1 bis L-6 der Matrix)

| ID | Frage | Konstellation | Paket |
|---|---|---|---|
| L-7 | Ist ein Teameinsatz im Heim oder Spital Personalverleih (AVG, Bewilligung, GAV Personalverleih) oder ein Auftrag? Welche Merkmale (Weisungsrecht, Eingliederung, Abrechnung, Risikotragung) muss der Vertrag erfüllen, damit V-2 zulässig ist? | KON-1, KON-3a | D-44 |
| L-8 | Kann ein externes Team im Heim (OKP-Beitrag nach Stufe an das Heim) oder im Spital überhaupt gegenüber einem Versicherer abrechnen, oder nur gegenüber der Einrichtung? | KON-1, KON-3a | D-44 |
| L-9 | Welche Rechtsform und Zulassung braucht ein Team, um ambulant nach KVG abzurechnen (Organisation Art. 51 KVV, freiberuflich Art. 49 KVV, Partner nach D-12) in BS und BL; gilt die Restfinanzierung gleich wie für öffentliche Spitex? | KON-3b, KON-4 | D-44, D-12 |
| L-10 | Darf NAVORA eine Gebühr in Prozent der Teamvergütung erheben oder Zahlungen durchleiten, ohne als Vermittler (AVG) oder Zahlungsdienst zu gelten? | alle Teamkonstellationen | D-44, D-14 |
| L-11 | Scheinselbständigkeit und Sozialversicherung: Unter welchen Bedingungen gelten Teammitglieder als selbständig, wann als Angestellte (AHV-Statut)? | KON-1, KON-3, KON-4 | D-44 |

---

## 5. Was mit synthetischen Daten jetzt weitergeht (Phase A)

- KON-1 und KON-2 sind im Ausfall-Simulationsfall (Brief [QUAL1](../agents/briefs/QUAL1.md)) mit synthetischen Daten abgebildet: simuliertes Heim meldet Ausfall, das Team erhält einen Vorschlag innerhalb der Matrix, Negativfälle eskalieren.
- Die Rechnungsvorbereitung bleibt bei bestätigten Leistungen und versionierten Regeln (J5, AIR1: keine KI-Werte in Abrechnungstabellen, IMPLEMENTED).
- Keine echte Person, kein echtes Heim, kein echter Vertrag. D-35 Regel A gilt: keine Klient- oder Personaldaten an einen KI-Dienst.

## 6. Quellen

- [W1] Matrix-Quellen Q1-Q9 in [`QUALIFICATION_MATRIX.md`](../agents/clinical/QUALIFICATION_MATRIX.md) §5 (KLV-Auszug, Bewilligungsseiten BS/BL).
- [W2] WEKA, „Personalverleih: Vorsicht beim Outsourcing von Personal“ (Abgrenzung Personalverleih/Auftrag, BGer 2C_470/2020, Bewilligungspflicht ab Gewerbsmässigkeit, Art. 39 AVG): <https://www.weka.ch/themen/recht/arbeitsrecht/schweizer-arbeitsrecht/article/personalverleih-vorsicht-beim-outsourcing-von-personal/> (gelesen 2026-11-06; Sekundärquelle, keine Rechtsauskunft).
- Weitere Zahlenquellen in `ECONOMICS_COMPARISON.md` §6.
