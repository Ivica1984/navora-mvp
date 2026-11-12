# FE-070 Lieferung 2: Geschäftsmodell in eigenen Worten, kritische B1-Bewertung

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-12 15:39 (Europe/Zurich), geplanter PO-Lauf, veröffentlicht 16:05 nach der PO-Sitzung 15:45; vor dem Termin Freitag, 13. November 2026 (FE-071 (7)) · **Grundlage:** FE-070 (1) und (5), FE-071 (`FOUNDER_DECISIONS.md` v21); Lieferung 1 ([`FE-070_LIEFERUNG_1.md`](FE-070_LIEFERUNG_1.md)) und Lieferung 1b ([`FE-070_LIEFERUNG_1B.md`](FE-070_LIEFERUNG_1B.md), PO-Sitzung 15:45) · **Code-Stand:** `recovery/main` `80643af` (Code wie `4a543c0`, seither nur Dokumente) · **IST-Abgleich:** `eng` 14:22 ([`journal/2026-11-12-1422-eng.md`](../agents/journal/2026-11-12-1422-eng.md)), Stellen unten selbst nachgelesen, wo angegeben · **Kennzeichnung:** IMPLEMENTED / PLANNED / OPEN / UNKNOWN wie in `CLAUDE.md`. Der PO hat keinen Test ausgeführt.

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
- **Kein Vermittler, der sich dazwischenschiebt.** Wenn NAVORA am Auftrag nichts verdient, hat NAVORA kein Interesse daran, Aufträge über sich zu leiten. Das Produkt darf deshalb so gebaut werden, dass Auftraggeber und Team sich direkt finden und behalten (§2.1, Stammteam).
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

**Verhältnis zu Lieferung 1b:** Lieferung 1b (15:45) hat auf die Founder-Rückmeldung FE-071 schon entschieden:
- SAFE-D11 als Sicherheitsausnahme zuerst;
- B1.1 kleiner geschnitten (Regionsliste, Abschluss einer Anfrage, Statuszeile, Anfragende getrennt von Erfassenden);
- B1.1b für die Bereitschaftsstufen und den Text der zuweisenden Stelle, nach `cra` und `lca`;
- die Skizze der Übergänge (§4);
- «Wir prüfen» als Signal ohne Sperre (§5).

Diese Lieferung wiederholt das nicht. Sie bewertet B1 als Produkt, prüft die Empfehlungen gegen den Code und ergänzt, was in 1b fehlt. **Wo sich diese Lieferung und 1b widersprechen, gilt 1b.** Ein Widerspruch ist mir nicht bekannt.

### 2.1 Gesamturteil

**B1 tut zuverlässig, was es tut, aber es bildet eine Spitex-Aufnahmestelle nach, nicht das Zielmodell.** Operations ist die einzige Eingangstür (`/intake`); jede Anfrage braucht 23 von 61 gezählten Handlungen bei der Aufnahme (AUT-88). Das Team entscheidet heute über ein Angebot, das nur Region und «hat eine diplomierte Pflegefachperson» prüft. Es sagt mit einem Klick zu, und der Auftraggeber erfährt nichts. Drei Dinge machen B1 zum richtigen Produkt, in dieser Reihenfolge:

1. **Sicherheit:** SAFE-D11; eine ehrliche Zusage (1b §5); bei Dringlichkeit keine Wartezeit (§2.4 unten).
2. **Eignung nach Tätigkeit statt nach Ort** (§2.3).
3. **Der Auftraggeber kommt direkt zum Team**, und ein Mensch sieht nur noch Ausnahmen (1b §4; Ergänzung §2.2).

### 2.2 Ergänzung zum Zielmodell: Stammteam und die Rolle von NAVORA

- **Stammteam (neu, Empfehlung):** Ein Auftraggeber, der mit einem Team zusammenarbeitet, schickt neue Anfragen zuerst diesem Team. Erst nach dessen Absage oder nach dem Vorrangfenster gehen sie gleichzeitig an alle geeigneten Teams.
  - **IMPLEMENTED als Grundlage:** der RET1-Vorrang für das frühere Team einer Klientin (`private.set_first_refusal`, 0034:125-153). Der Vorrang würde vom Klienten auf den Auftraggeber ausgeweitet.
  - **Wert:** Kontinuität (2), weniger Abstimmung (5), eine direkte Beziehung ohne Vermittler.
  - **Risiko:** Teams ohne Stammkunden kommen schwerer zu Aufträgen. Gemessen wird der Anteil der Aufträge je Team, im Vergleich.
  - **Einordnung:** mit der Auftraggeber-Ansicht (Lieferung 4); bei Dringlichkeit gilt §2.4.
- **Messgrösse für «keine Vermittlung»** (ergänzt 1b §4): Anteil der Anfragen, die ohne eine menschliche Handlung bei NAVORA ein verbindlich zusagendes Team finden. Er soll von Block zu Block wachsen. Fällt er, wird die Ausnahmeliste zur Vermittlung, und der PO prüft die Regeln.
- **L-15 an `lca`** (§1.6): Welche rechtliche Rolle hat NAVORA, wenn Regeln eine Anfrage an geeignete Teams leiten? Vor dem Bau der Auftraggeber-Ansicht.

### 2.3 Eignung nach Tätigkeit: Befund im Code

- **IST (IMPLEMENTED, vom PO nachgelesen):** `team_offers` zeigt dem Team die angefragten Leistungen (`required_services`, 0086:197). Keine Bedingung im Filter liest sie aber (0086:207-213). Geprüft werden nur Organisation, Region als exakter Text (0086:205), aktives Team, offener Fall ohne Team, «hat eine diplomierte Pflegefachperson» falls verlangt (0086:212) und das Vorrangfenster (0086:213).
- **Folge:** Ein Team kann zusagen und erst bei der Einsatzplanung erfahren, dass ein Mitglied eine Tätigkeit nicht ausführen darf (QUAL1). Der Fall gilt dann als übernommen, ist aber nicht versorgbar.
- **Empfehlung (bestätigt 1b §4 Punkt 3):** Ein Team ist geeignet, wenn für jede angefragte Tätigkeit mindestens ein Mitglied sie nach der geltenden Regel ausführen darf: eigenständig oder mit gültiger Delegation, mit gültigem Nachweis. Das Ergebnis trägt seine Begründung. Gebaut im B2-Kern und in B1.2. Die Regeln sind in Phase A Simulationsregeln (FE-069), gekennzeichnet und **PROPOSED**, bis die Clinical Owner sie freigibt (D-27). Ein Score gleicht nie eine fehlende Voraussetzung aus.

### 2.4 Dringlichkeit: neuer Befund im Code

- **IST (IMPLEMENTED, vom PO nachgelesen):**
  - `urgency` ordnet nur die Angebotsliste (0086:214).
  - Die Antwortfrist hängt vom Auftragstyp ab, nicht von der Dringlichkeit (`private.response_due(organization, referral_type, now())`, 0034:195).
  - Das RET1-Vorrangfenster hat für den Spitalaustritt eine eigene Dauer, prüft aber die Dringlichkeit nicht (0034:147-149). Bei einer rückkehrenden Klientin mit Dringlichkeit «hoch», die nicht aus dem Spital kommt, sehen die anderen Teams das Angebot also erst nach dem Fenster (0086:213).
- **Widerspruch zum Grundsatz aus 1b §5** («Bei Dringlichkeit ‹hoch› und bei Spitalaustritt wirkt nie eine Reservierung»): Das bestehende Vorrangfenster ist eine solche Reservierung.
- **Ich entscheide das nicht selbst**, weil Kontinuität und Schnelligkeit hier fachlich gegeneinander stehen. **Frage an `cra`:** Gilt das RET1-Vorrangfenster bei Dringlichkeit «hoch» weiter, wird es verkürzt, oder läuft das Angebot sofort parallel an alle geeigneten Teams, mit dem früheren Team an erster Stelle? Bis zur Antwort bleibt der Code unverändert (IST ist streng begrenzt: das Fenster endet spätestens mit der Antwortfrist, 0034:150-151).
- **Einordnung:** B1.3 («dringliche Anfrage ohne Zusage»), zusammen mit der Ausnahme «dringlich, noch keine Zusage» aus 1b §5.

### 2.5 Freitext im Angebotstitel

- **IST (IMPLEMENTED, vom PO nachgelesen):** Der Angebotstitel ist «Teamsuche: » plus der Freitext `bedarf` des Falls (0034:193). Alle angefragten Teams der Region lesen ihn über `team_offers` (0086:197).
- **Folge:** Was Operations in den Fallbedarf schreibt, lesen auch Teams, die nie zusagen. 1b §3.2 erfasst das als «Angebotstitel, den Operations aus dem Fallbedarf bildet» und legt die Lösung nach B1.1b.
- **Ergänzung:** B1.1b bildet den Titel aus strukturierten Angaben (Leistungsart, Umfang, Beginn, Region). Negativtest (pgTAP): Ein angebotenes Team, das nicht zugesagt hat, liest keinen Freitext des Falls. Bis B1.1b gilt die bestehende Regel Δ4 («Titel ohne Personenangaben»), und die Statuszeile von B1.1 erinnert beim Eröffnen daran (Text: `uxa`).

### 2.6 Zusage: was in 1b noch fehlt

1b §5 legt die zwei Stufen fest. Zwei Ergänzungen, beide für später:

- **«Zusage mit Termin»** (Idee, Ausbau mit B3): Die verbindliche Zusage nennt den Termin der ersten Bedarfsabklärung. Der Auftraggeber weiss dann, wann jemand kommt, und die Bezugsperson steht ab dem ersten Kontakt fest. Validierung in der Simulation: Wie oft kann ein Team beim Zusagen einen Termin nennen?
- **Fall übergeben** (B1.3, bestätigt 1b §5 «Rücktritt ist Übergabe oder Ausnahme»):
  - Kann ein Team den ganzen Fall nicht mehr tragen, gibt es ihn mit einer Übergabe zurück.
  - Der Fall bleibt aktiv, eine neue Teamsuche öffnet sich, und bis zur Übernahme bleibt das alte Team verantwortlich.
  - **IST:** kein Befehl dafür gefunden. Gesucht wurde in `supabase/migrations` nach den üblichen Namen. Ob ein anderer Weg existiert, ist UNKNOWN.
  - Wer bis zur Übernahme verantwortlich bleibt, ist eine Frage an `cra`.
  - Nach einer Bedarfsänderung (ASM1) prüft dieselbe Regel die geplanten Einsätze erneut. Ob das heute geschieht, ist UNKNOWN.

### 2.7 SAFE-D11: Produktantwort an `eng` (ADR-184)

`eng` fragt in #1133, ob ein wiedereröffneter Fall die alte Antwortfrist erbt oder eine neue bekommt. **Antwort (Produktbefugnis):** eine **neue Frist ab der Wiedereröffnung**, nach der bestehenden Regel `private.response_due`; dazu das RET1-Vorrangfenster wie bei einer ersten Suche. Das entspricht dem SAFE-D11-Kriterium «response deadline and RET1 first refusal are derived exactly as for a first search» (Brief SAFE-D11). Begründung: Die alte Frist liegt in der Vergangenheit, und die Anfrage würde eskalieren, bevor ein Team sie gesehen hat. Es entsteht keine neue Fristregel.

### 2.8 Einordnung in die Teilblöcke (nach FE-071)

| Ergänzung dieser Lieferung | Teilblock | Gate |
|---|---|---|
| §2.7 neue Frist bei Wiedereröffnung | SAFE-D11 | `cra`, `uxa` |
| §2.5 Angebotstitel ohne Freitext, Negativtest | B1.1b | `lca` (Minimierung) |
| §2.3 Eignung nach Tätigkeit mit Begründung | B2-Kern, B1.2 | `cra`, D-27 (Simulationsregeln FE-069) |
| §2.4 Dringlichkeit und Vorrangfenster | B1.3 | `cra` (Frage oben) |
| §2.6 Fall übergeben, Bedarfsänderung | B1.3 | `cra` |
| §2.2 Stammteam; §2.6 «Zusage mit Termin» | Auftraggeber-Ansicht, B3; Einordnung in Lieferung 4 | `lca` L-15 |

**B1.1 bleibt unverändert, wie in 1b §3.5 geschnitten.**

## 3. Was an dich geht (Founder) und was nicht

- **An dich:** nichts Neues. Diese Lieferung braucht keinen Entscheid.
- **Später an dich (Preis, FE-070 (1)):** ob die feste Gebühr eine Pauschale je Team oder ein fester Betrag je aktivem Mitglied ist (D-14). Ich bereite das mit Lieferung 3 vor. Es blockiert heute nichts.
- **Nicht an dich:**
  - die Feldlisten und Minimierung (`cra`, `lca`, schon in 1b);
  - L-15 (`lca`);
  - das Vorrangfenster bei Dringlichkeit (`cra`);
  - die Verantwortung beim Übergeben (`cra`).

  Die Antworten trage ich ein, sobald sie vorliegen.

## 4. Nächste Lieferungen

Lieferung 3 (Plattform, Rollen, Geldflüsse, Matching-Entwurf) am Montag, 16. November 2026, und Lieferung 4 (Blockplanung, Differenzierung, Prompt-Wortlaut) am Dienstag, 17. November 2026 (FE-071 (7)).
