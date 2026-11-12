# FE-070 Lieferung 2: Geschäftsmodell in eigenen Worten, kritische B1-Bewertung

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-12 15:39 (Europe/Zurich), geplanter PO-Lauf, einen Tag vor dem Termin aus Lieferung 1 §4 · **Grundlage:** FE-070 (1) und (5) (`FOUNDER_DECISIONS.md` v20); Lieferung 1 ([`FE-070_LIEFERUNG_1.md`](FE-070_LIEFERUNG_1.md)) · **Code-Stand:** `recovery/main` `80643af` (Code wie `4a543c0`, seither nur Dokumente) · **IST-Abgleich:** `eng` 14:22 ([`journal/2026-11-12-1422-eng.md`](../agents/journal/2026-11-12-1422-eng.md)), Stellen unten selbst nachgelesen, wo angegeben · **Kennzeichnung:** IMPLEMENTED / PLANNED / OPEN / UNKNOWN wie in `CLAUDE.md`. Der PO hat keinen Test ausgeführt.

**Grenzen:** Diese Lieferung legt keine Rechtsform, keinen Preis, keine klinische Regel und keine Tarifregel fest. Rechtliche Aussagen sind Fragen an `lca`, klinische an `cra` und die Clinical Owner (D-27). Sie sind keine Feststellungen.

---

## 1. Geschäftsmodell in eigenen Worten

### 1.1 Wer arbeitet, wer zahlt, wer verdient

1. **Die Pflege gehört dem Team.** Ein selbstorganisiertes Team erhält einen Auftrag möglichst direkt: von einem Heim, einem Spital oder einer Privatperson. Es erbringt die Pflege und rechnet sie über eine noch zu bestimmende, rechtlich geeignete Struktur ab (OPEN: D-44, D-12; Rechtsform nicht entschieden, FE-070 (1)). Der Pflegeumsatz ist **Umsatz des Teams**, nie Umsatz von NAVORA.
2. **NAVORA verdient am Team nur eine feste Monatsgebühr.** Sie ist der Preis für die Plattform: Planung, Ausfall, Dokumentation, Abrechnungsvorbereitung, Qualität, KI. Es gibt keine Provision auf Aufträge und keinen Anteil am Pflegeumsatz. Die Gebühr steigt also nicht, wenn das Team mehr Stunden leistet oder eine Person höher eingestuft wird.
3. **B2B ist ein zweites, getrenntes Geschäft.** Ein Heim oder Spital kauft Module für das eigene Personal: KI-Planung und Ausfall, Diktat und Bericht mit Freigabe, Angehörigenkommunikation. Es zahlt eine Softwarelizenz. Ein externes Team ist dabei nicht im Spiel (GM-2, KON-5).

Daraus folgen **drei Geldflüsse, die nie in einer Zahl zusammenlaufen:**

| Geldfluss | Von → an | Gehört wem | Wo NAVORA ihn zeigt |
|---|---|---|---|
| Pflegeumsatz und Kosten | Auftraggeber oder Kostenträger → Team (bzw. seine Struktur) | Team | nur dem Team selbst; der Betreiber sieht ihn nie als eigenen Umsatz |
| Plattformgebühr | Team → NAVORA | NAVORA | Betreiber-Finanzansicht; beim Team als Kostenzeile |
| B2B-Lizenz | Einrichtung → NAVORA | NAVORA | Betreiber-Finanzansicht, eigene Zeile |

### 1.2 Warum dieses Modell die Vision schützt

- **Kein Anreiz gegen die Pflegenden.** Eine Provision würde NAVORA an mehr Stunden oder höheren Stufen verdienen lassen. Damit stünde NAVORA gegen «Einkommen folgt der Pflege, nicht der Einstufung» (D-14). Eine feste Gebühr hat diesen Anreiz nicht.
- **Kein Vermittler, der sich dazwischenschiebt.** Wenn NAVORA am Auftrag nichts verdient, hat NAVORA kein Interesse daran, Aufträge über sich zu leiten. Das Produkt darf deshalb so gebaut werden, dass Auftraggeber und Team sich direkt finden und behalten (§2.1, Option C).
- **Einnahmen, die man planen kann.** Die Gebühr ist für das Team planbar. Für NAVORA wächst sie mit der Zahl der Teams, nicht mit dem Pflegevolumen.

### 1.3 Was ich daraus für das Produkt ableite (PLANNED, als Akzeptanzkriterien künftiger Blöcke)

1. **Keine Datenstruktur rechnet eine NAVORA-Einnahme aus Pflegeumsatz.** Prüfbar: keine Spalte, View oder Funktion, die eine Gebühr als Anteil an Leistungen, Stunden oder Rechnungsbeträgen berechnet (pgTAP/Code-Review in dem Block, der die Gebühr einführt).
2. **Die Betreiber-Finanzansicht hat drei getrennte Quellen.** Plattformgebühren, B2B-Lizenzen und (nur als aggregierte Kennzahl ohne Zuordnung zu NAVORA) Pflegevolumen. Kein Total über alle drei.
3. **Das Team sieht seine Rechnung vollständig.** Pflegeumsatz, eigene Kosten, Plattformgebühr als eine Kostenzeile und was übrig bleibt. Das ist die Grundlage für die Einkommenshypothese (§1.4) und für J7 (draft, D-14).
4. **IST (IMPLEMENTED):** J5 zeigt eine monatliche Umsatzvorschau aus abrechenbaren Fakten des Teams (Referenztarife als «nicht validiert», BD-7). Das ist Pflegeumsatz des Teams. Eine Plattformgebühr, eine B2B-Lizenz und eine Betreiber-Finanzansicht gibt es nicht (OPEN, Lieferung 1 §1).

### 1.4 Höheres Einkommen ist eine Hypothese, kein Versprechen

**Hypothese H-E1:** Ein Team, das direkt beauftragt wird und seine Administration mit NAVORA erledigt, behält von derselben Vergütung einen grösseren Teil für die Pflegenden als eine Organisation mit Vermittlung, Disposition und Leitungsebene.

- **Was sie trägt:** weniger Vermittlungsmarge, weniger Verwaltungsstellen, mehr verrechenbare Pflegezeit (Nordstern: Anteil direkter Pflege, `CARE_OPERATING_MODEL.md`).
- **Was sie gefährdet:**
  - Kosten, die das Team nun selbst trägt: Versicherung, Bewilligung, fachverantwortliche Funktion (R3), Buchhaltung, Ausfallreserve;
  - die Plattformgebühr;
  - eine Rechtsform, die Sozialabgaben verschiebt (Scheinselbständigkeit, OPEN bei `lca`).
- **Wie Phase A sie prüft:** mit synthetischen Zahlen pro Team, die Vergütung, Kosten, Gebühr und Rest getrennt ausweisen (J7 nach D-14, AN1). Ein Ergebnis aus Phase A ist ein Modell, kein Nachweis. Den Nachweis bringt erst Phase B mit realen Kosten.

### 1.5 Abweichungen in eigenen Dokumenten (README-Regel 10)

- **[`PRICING_MODEL_COMPARISON.md`](PRICING_MODEL_COMPARISON.md) §1** nennt als Käufer «die Organisation mit Betriebsbewilligung» und vergleicht F1 (pro Stunde) und F2 (Prozent vom Umsatz). Nach FE-070 zahlt im Teamgeschäft das **Team** (bzw. seine Struktur) eine **feste Monatsgebühr**. F1 und F2 sind damit ausgeschlossen. Ob «fest» eine Pauschale je Team (F5) oder ein fester Betrag je aktivem Mitglied (F3) sein darf, ist eine **Preisfrage** und bleibt beim Founder (D-14). Ich ändere das Dokument heute nicht inhaltlich: Es bekommt einen Hinweis auf FE-070 und wird mit Lieferung 3 überarbeitet.
- **[`BUSINESS_MODELS_AND_CONSTELLATIONS.md`](BUSINESS_MODELS_AND_CONSTELLATIONS.md) §0** stimmt mit FE-070 überein (GM-1, GM-2, drei Positionen). Es bleibt so.

### 1.6 Eine Frage, die FE-070 neu stellt (an `lca`, keine Feststellung)

Wenn NAVORA Anfragen nach Regeln an Teams leitet, kann das rechtlich eine **Vermittlung** sein, auch ohne Provision. Ob dafür eine Bewilligung oder eine bestimmte Vertragsform nötig ist, hängt davon ab, wer die Pflegenden beschäftigt und wer weisungsbefugt ist (Bezug: KON-1, Variante R3-c, D-44, L-7). **Frage L-15 an `lca`:** Welche Rolle hat NAVORA rechtlich, wenn die Plattform eine Anfrage nach festen Regeln an geeignete Teams weiterleitet und das Team selbst zusagt? Welche Ausgestaltung (Auftraggeber wählt selbst, Plattform schlägt nur vor, Plattform leitet weiter) verändert diese Rolle? Bis zur Antwort baut kein Block eine Weiterleitung an Teams ausserhalb der Simulation.

---

## 2. Kritische B1-Bewertung

B1 ist heute **IMPLEMENTED und läuft grün** als Schritte 1-2 des BD-Durchgangs. Die Bewertung fragt nicht, ob der Code tut, was er soll. Sie fragt, ob das, was er tut, das richtige Produkt ist. Jede Frage aus FE-070 (5) bekommt: IST, Problem, Optionen, Empfehlung, wer mitentscheidet.

### 2.1 Zielmodell: direkte Anfragen ohne zentrale Vermittlung

**IST (IMPLEMENTED):** Die einzige Eingangstür ist `/intake` für `admin` und `operations`. Operations erfasst, prüft, überführt und ergänzt (M1-M4). Das ist eine Aufnahmestelle, also genau die zentrale Vermittlung, die FE-070 nicht will. In Phase A ist sie als Platzhalter für den Auftraggeber zulässig.

**Problem:** Jede Anfrage braucht heute 23 von 61 gezählten Handlungen bei der Aufnahme (AUT-88). Skaliert NAVORA so, braucht jede Region eine Aufnahmestelle: eine Hierarchie, die mit jeder Region wächst.

| Option | Inhalt | Wert | Risiko |
|---|---|---|---|
| A | Operations bleibt die Tür (IST) | nichts zu bauen | zentrale Vermittlung bleibt; Operations wächst mit dem Volumen |
| B | Der **Auftraggeber erfasst selbst** in seiner Ansicht. Feste Regeln bestimmen die geeigneten Teams. Ein Mensch sieht nur Ausnahmen: unvollständig, Sicherheitshinweis, keine sichere Zuordnung | Aufnahmestelle entfällt (Wert 5); Team entscheidet (4) | die Ausnahmeliste wird zur neuen Vermittlung, wenn die Regeln zu grob sind |
| C | wie B, dazu **Stammteam:** Ein Auftraggeber, der mit einem Team zufrieden ist, schickt neue Anfragen zuerst diesem Team; erst nach dessen Absage gehen sie an die anderen geeigneten Teams | Kontinuität (2); weniger Abstimmung; nutzt den bestehenden Vorrang (RET1) | Teams ohne Stammkunden kommen schwerer zu Aufträgen; Fairness messen |

**Empfehlung: C**, gebaut auf B. Den Vorrang für ein früheres Team gibt es schon (RET1, `private.set_first_refusal`, 0034:198). C weitet ihn vom Klienten auf den Auftraggeber aus. **Messgrösse:** Anteil der Anfragen, die ohne menschliche Bearbeitung ein zusagendes Team finden. Ziel: wächst von Block zu Block. Fällt er, wird die Ausnahmeliste zur Vermittlung, und der PO prüft die Regeln.

**Mitentscheid:**
- `lca` mit L-15 (§1.6), vor dem Bau von B oder C;
- `cra` für die Ausnahmegründe;
- `uxa` für die Auftraggeber-Ansicht (Lieferung 3).

**Einordnung:** nicht in B1.1. Die Auftraggeber-Ansicht wird ein eigener Plattformteil (Lieferung 4). Bis dahin bleibt `/intake` die Tür, ausdrücklich als Simulation gekennzeichnet.

### 2.2 Was «Fall übernehmen» bedeutet

**IST (IMPLEMENTED):** Ein Klick eines Teammitglieds auf «Zusage», und der erste Zusage-Entscheid gilt (J2). Dabei wird nicht geprüft, ob das Team die Tätigkeiten fachlich darf, ob es Kapazität hat und ob es die Sicherheitshinweise gelesen hat. Danach steht der Fall auf der Fallkarte mit dem nächsten Schritt Bedarfsabklärung.

**Problem:** Für den Auftraggeber heisst «Zusage» heute «versorgt», für das Team eher «wir schauen es an». Diese Lücke ist ein **Sicherheitsrisiko**: Der Auftraggeber sucht nicht weiter, obwohl die Versorgung noch nicht gesichert ist.

| Option | Inhalt | Wert | Risiko |
|---|---|---|---|
| A | ein Klick, wie IST | schnell | Zusage ohne Prüfung; Auftraggeber verlässt sich darauf |
| B | **zwei Stufen:** (a) «Wir prüfen»: unverbindlich, reserviert das Angebot für eine kurze Frist, andere Teams sehen «in Prüfung». (b) «Versorgung zugesagt»: verbindlich, erst nach bestandener Regelprüfung (Tätigkeiten, Qualifikation, Kapazität) | ehrliche Aussage; weniger Rückfragen | eine Frist mehr; Stufe (a) darf nicht zum Parkplatz werden |
| C | wie B, aber Stufe (b) braucht **einen konkreten Termin** für die erste Bedarfsabklärung («Zusage mit Termin») | der Auftraggeber weiss, wann jemand kommt; Kontinuität beginnt mit einer Person | das Team muss beim Zusagen planen können; geht nur mit B3 |

**Empfehlung: B jetzt (B1.2), C als Ausbau mit B3.** Wer im Namen des Teams verbindlich zusagen darf, legt das **Team selbst** in seinen Teamregeln fest, nicht eine Hierarchie. Bis der Qualifikationskern (B2) steht, ist jede Zusage in der Simulation mit «Qualifikation nicht geprüft» gekennzeichnet.

**Mitentscheid:**
- `cra`: ab wann eine Versorgung als zugesagt gilt; was die Regelprüfung mindestens enthält (FE-070 (3); Auftrag an `cra` seit 14:39);
- `lca`: Bindungswirkung der Zusage gegenüber dem Auftraggeber.

**Frist für Stufe (a):** ein Betriebsparameter, kein klinischer Wert. Vorläufig nach D-28 und von `cra` zu bestätigen.

### 2.3 Tätigkeitsbezogener statt grober Filter

**IST (IMPLEMENTED):** Das Angebot geht an jedes aktive Team derselben Region; geprüft wird die Region als exakter Text (0086:205, 0034:217) und, falls verlangt, ob das Team eine diplomierte Pflegefachperson hat (0086:205-212). Die Anfrage trägt zwar `required_services` (aus `care_needs`, 0034:194), und das Team sieht sie im Angebot (0086:197), aber keine Bedingung im Filter liest sie (0086:207-213, selbst nachgelesen). Die tätigkeitsbezogene Prüfung gibt es erst bei der Einsatzzuteilung (QUAL1).

**Problem:** Ein Team kann einen Fall übernehmen und erst bei der Planung merken, dass es eine Tätigkeit nicht ausführen darf. Dann ist der Fall «übernommen» und doch nicht versorgbar, und das ist ein später Fehler beim schwächsten Glied.

| Option | Inhalt | Wert | Risiko |
|---|---|---|---|
| A | grober Filter, Prüfung erst je Einsatz (IST) | nichts zu bauen | später Fehler, siehe oben |
| B | Die Anfrage nennt **konkrete Tätigkeiten**. Ein Team ist geeignet, wenn es für jede Tätigkeit mindestens ein Mitglied hat, das sie nach der geltenden Regel ausführen darf (eigenständig oder mit gültiger Delegation). Die Begründung lautet «geeignet, weil …» oder «keine sichere Zuordnung, weil …» | Sicherheit; weniger Rückfragen; die KI kann erklären statt raten | hängt an der Matrix; in Phase A nur Simulationsregeln (FE-069), gekennzeichnet |
| C | wie B, dazu Kapazität und Wegzeit aus der Planung | weniger Absagen | braucht B3; mehr Daten pro Anfrage |

**Empfehlung: B im Block B1.2, nach dem B2-Kern; C mit B3.** Ein Match-Score gleicht nie eine fehlende Voraussetzung aus (FE-070 (3)). Die Regeln bleiben versioniert und **PROPOSED**, bis die Clinical Owner sie freigibt (D-27). Alle 115 Matrixzellen sind heute PROPOSED.

### 2.4 Pflichtfelder je Zweck

**IST (IMPLEMENTED):** `private.case_readiness` (0013:159-170) verlangt für jeden Fall auch Versicherer und Versicherungsart, bevor die Teamsuche beginnt.

**Problem:** Für einen Auftrag eines Heims (KON-1: Das Heim zahlt das Team) sind das Abrechnungsangaben, die das Team nie braucht. Für einen Spitalaustritt nach Hause braucht das Team sie erst für die Abrechnung, nicht für das Angebot. Die Sperre verzögert also die Versorgung wegen der Abrechnung.

| Option | Inhalt |
|---|---|
| A | eine Liste für alle (IST) |
| B | **drei Stufen mit drei Zeitpunkten:** für das Angebot (vor der Teamsuche), für die sichere Versorgung (vor dem ersten Kontakt), für die Abrechnung (vor der ersten Rechnung). Welche Stufe ein Feld hat, hängt von der Auftragskonstellation ab (KON-1 bis KON-4) |

**Empfehlung: B in B1.1.** Die Feldliste je Stufe und Konstellation lege ich **nicht** selbst fest:
- `cra`: welche Angaben die sichere Versorgung vor dem ersten Kontakt braucht (D-17-Kategorien);
- `lca`: welche Angaben die Abrechnung wann braucht und was minimiert werden muss.

Vorläufig (Simulation) gilt: Was heute Pflicht ist, bleibt Pflicht, bis die beiden Zeilen vorliegen. Nur der **Zeitpunkt** verschiebt sich, keine Angabe fällt weg.

### 2.5 Sichtbarkeit von Freitext

**IST (IMPLEMENTED):**
- Der Titel des Angebots wird als «Teamsuche: » plus der Freitext `bedarf` des Falls gebildet (0034:193) und über `team_offers` (0086:184, 197) für alle angebotenen Teams der Region lesbar.
- Der Text der zuweisenden Stelle (`need_summary`) erreicht den Fall nicht (CGR-193 (4b)).

**Problem:** Das ist zweifach falsch. Teams, die nicht zusagen, lesen Freitext, der identifizierende oder gesundheitsbezogene Angaben enthalten kann. Das Team, das zusagt, liest dagegen nicht, was die zuweisende Stelle wirklich geschrieben hat.

**Empfehlung:** umdrehen.
- **Angebot:** nur strukturierte Angaben (Region, Tätigkeiten, Umfang, Beginn, Dringlichkeit), kein Freitext, kein Name. Der Titel wird aus diesen Angaben gebildet.
- **Nach der verbindlichen Zusage:** Das zusagende Team liest den Text der zuweisenden Stelle unverändert, gekennzeichnet als «Text der zuweisenden Stelle».
- **Bau:** der Angebotsteil in B1.1 (Δ4 erweitert), der Zusageteil nach der `lca`-Zeile zur Minimierung (seit 13:39 angefragt).

### 2.6 Dringliche Anfrage ohne Zusage

**IST (IMPLEMENTED):** Die Anfrage trägt eine Dringlichkeit (`urgency`, 0034:193), aber sie ordnet nur die Liste der Angebote (0086:214). Die Antwortfrist wird ohne sie berechnet (`private.response_due(organization, referral_type, now())`, 0034:195). Eine dringliche Anfrage wartet also gleich lange wie jede andere, auch das Vorrangfenster gilt unverändert (0086:213). Danach erscheint sie als Ausnahme bei Operations (M7). Der Auftraggeber erfährt nichts.

**Problem:** Bei dringlichem Bedarf ist Warten das grösste Risiko, und gerade dann bleibt der Auftraggeber ohne Rückmeldung.

| Option | Inhalt |
|---|---|
| A | wie IST |
| B | Eine dringliche Anfrage geht **gleichzeitig** an alle geeigneten Teams, ohne Vorrangfenster |
| C | Der Auftraggeber sieht laufend den Stand: «angeboten an n Teams, noch keine Zusage, Frist bis …». Läuft die Frist ab, erhält er die klare Meldung «keine Zusage, bitte andere Versorgung sicherstellen» |

**Empfehlung: B und C in B1.3.** Was als dringlich gilt und welche Frist gilt, ist nicht meine Regel: `cra` mit den Fristen nach D-28, vorläufig. NAVORA sagt nie «versorgt», solange keine verbindliche Zusage besteht (§2.2).

### 2.7 Δ11 zuerst

**IST (IMPLEMENTED, Fehler):** Ein Fall, der vor einer Zusage abgeschlossen und später wiedereröffnet wird, findet nie wieder ein Team. Das bestätigen `eng` 14:22 und der rote Test in PR #1133 (pgTAP 129, Prüfungen 5, 8, 10, 11 rot). Er ist eine Sicherheitslücke ohne Signal.

**Empfehlung:** bleibt die dokumentierte Sicherheitsausnahme vor B1.1 (Lieferung 1 §3), Merge nach Founder-Bestätigung. **Produktentscheid des PO zur Frage aus ADR-184:** Ein wiedereröffneter Fall bekommt eine **neue Antwortfrist**, berechnet ab dem Zeitpunkt der Wiedereröffnung nach derselben bestehenden Regel `private.response_due` wie ein neuer Fall. Auch das Vorrangfenster (RET1) wird wie bei einem neuen Fall gesetzt. Begründung: Die alte Frist liegt in der Vergangenheit, und die Anfrage würde sofort eskalieren, ohne dass ein Team sie gesehen hat. Es entsteht keine neue Fristregel. Ob ein bei Wiedereröffnung nicht bereiter Fall als Ausnahme bei Operations erscheint, bleibt `eng`/`cra` (ADR-184, Variante OPEN), mit `cra-gate`.

### 2.8 Ausfall und veränderter Bedarf nach der Zusage

**IST:**
- Kein Befehl «Fall zurückgeben» gefunden (Suche in `supabase/migrations` nach den üblichen Namen; UNKNOWN, ob es einen anderen Weg gibt).
- Ein Ausfall einzelner Einsätze ist gelöst (ABS1, COVER1, IMPLEMENTED).
- Ein veränderter Bedarf läuft über eine neue Bedarfsabklärung (ASM1). Ob die Qualifikationsprüfung danach für die bestehenden Einsätze neu läuft: UNKNOWN.

**Problem:** Kann das Team den Fall als Ganzes nicht mehr tragen (Kapazität, fehlende Qualifikation nach Bedarfsänderung), bleibt nur der Abschluss. Das ist falsch, weil die Klientin weiter Pflege braucht.

**Empfehlung (B1.3):**
- «Fall übergeben»: Das Team gibt den Fall mit einer Übergabe zurück. Der Fall bleibt aktiv, eine neue Teamsuche öffnet sich, die Einsätze bleiben bis zur Übernahme beim alten Team, und es gibt keine Lücke ohne Verantwortung.
- Nach einer Bedarfsänderung prüft dieselbe Regel die geplanten Einsätze erneut und zeigt Konflikte.

Wer bis zur Übernahme verantwortlich bleibt, ist eine klinische Frage an `cra`.

### 2.9 Gesamturteil

**B1 tut zuverlässig, was es tut. Aber es bildet eine Spitex-Aufnahmestelle nach, nicht das Zielmodell.** Drei Dinge machen es zum richtigen Produkt, in dieser Reihenfolge:

1. Sicherheit vor Bequemlichkeit: Δ11, die ehrliche zweistufige Zusage, Dringlichkeit mit Rückmeldung.
2. Der Filter prüft, was ein Team darf, nicht nur, wo es arbeitet: Tätigkeiten statt Region.
3. Der Auftraggeber kommt direkt zum Team, und ein Mensch sieht nur noch Ausnahmen.

Die Teilblockfolge aus Lieferung 1 §3 bleibt richtig. Diese Bewertung ordnet die Empfehlungen ein:

| Empfehlung | Teilblock |
|---|---|
| §2.7 Δ11 (mit neuer Frist) | Sicherheitsausnahme vor B1.1 |
| §2.4 Pflichtfelder in drei Stufen; §2.5 Angebot ohne Freitext | B1.1 |
| §2.3 Tätigkeiten in der Anfrage, Regeln, Begründung | B2-Kern |
| §2.2 zweistufige Zusage; §2.3 tätigkeitsbezogenes Angebot; §2.5 Text der zuweisenden Stelle nach Zusage | B1.2 |
| §2.6 Dringlichkeit; §2.8 Fall übergeben, Bedarfsänderung | B1.3 |
| §2.1 Auftraggeber-Ansicht und Stammteam; §2.2 C «Zusage mit Termin» | neue Plattformteile, Einordnung in Lieferung 4 |

**Steckbrief B1.1, geändert gegenüber Lieferung 1:**
- Umfang: zusätzlich «Angebotstitel aus strukturierten Angaben, ohne Freitext» (§2.5).
- Akzeptanz: zusätzlich der Negativtest «ein angebotenes Team liest keinen Freitext des Falls» (pgTAP).
- Alles andere bleibt.

## 3. Was an dich geht (Founder) und was nicht

- **An dich:** nur die Bestätigungen aus Lieferung 1 (Teilblockfolge, B1.1 als erster Block, Sicherheitsausnahme Δ11). Diese Lieferung braucht keinen neuen Entscheid von dir.
- **Später an dich (Preis, FE-070 (1)):** ob die feste Gebühr eine Pauschale je Team oder ein fester Betrag je aktivem Mitglied ist (D-14). Ich bereite das mit Lieferung 3 vor. Es blockiert heute nichts.
- **Nicht an dich:** Feldlisten (`cra`, `lca`), Fristen (`cra`, D-28), L-15 (`lca`), Freitext-Minimierung (`lca`). Die Antworten trage ich ein, sobald sie vorliegen.

## 4. Nächste Lieferungen

Lieferung 3 (Plattform, Rollen, Geldflüsse, Matching-Entwurf) bis 2026-11-16 und Lieferung 4 (Blockplanung, Differenzierung, Prompt-Wortlaut) bis 2026-11-17 bleiben wie geplant.
