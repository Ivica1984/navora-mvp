# FE-070 Lieferung 1b: Antwort auf die Founder-Rückmeldung vom 12. November 2026

**Besitzer:** Product Owner (`po`) · **Stand:** Donnerstag, 12. November 2026, 15:45 (Europe/Zurich) · **Grundlage:** FE-070, FE-071 (`FOUNDER_DECISIONS.md` v21) · **Code-Stand:** `recovery/main` `5a01512` (Code wie `4a543c0`) · **Kennzeichnung:** IMPLEMENTED / PLANNED / OPEN / UNKNOWN. Der PO hat keine Tests selbst ausgeführt; Testumgebung ist GitHub Actions.

## 1. Test- und Abnahmestand

Die vollständige Akte steht in [`ABNAHMEAKTE.md`](ABNAHMEAKTE.md).

**Wiederholungslauf abgeschlossen:** `ci-repeat` 43231715012 auf dem benannten Commit `4a543c0` lief von 14:53 bis 15:04 und ist **20 von 20 Jobs `success`**: 10 × Datenbank (je 128 pgTAP-Dateien, 4646 Tests), 10 × Browser (je 163 Tests).
- Übersprungen: 0; instabil: 0 (Playwright ohne Wiederholungen); abgebrochen: 0 Jobs.
- Erwartet rot sind nur zwei Reproduktionsproben, die absichtlich den alten Fehlerstand rot zeigen.
- **Die zuvor auffälligen Sicherheitsprüfungen sind in allen zehn Versuchen stabil:**
  - die SIG1-Sperre (080 wartet und besteht 59/59);
  - der erzwungene Scheduler-Lauf während 062, 078 und 080, ohne verlorene oder doppelte Zustellung;
  - der 079-Schnappschuss.

**B0:** B0 ist **für die Simulation abgenommen, ohne B0-6**.
- B0-6 (Repository-Schutz) war bei der Abnahme ausdrücklich ausgeschlossen und hat ein **eigenes Gate: vor B12 und vor jeden realen Daten**. Bis dahin gilt die Ersatzkontrolle der PO-Merge-Prüfung.
- Der Status ist nicht falsch, aber er war ohne diesen Zusatz missverständlich. Er heisst ab jetzt überall «B0 für die Simulation abgenommen, ohne B0-6».

**BD:** BD ist nur eine **Teilabnahme für die Simulation**.
- Abgenommen sind die ambulanten Schritte 1, 1b, 2, 3, 4, 5, 8 und 9.
- Nicht nachgewiesen sind Schritt 6 Diktat, Schritt 7 KI-Entwurf, drei Stoppfälle mit unbekanntem Sollverhalten und die Pflegeheim-Spalte.
- Ein fertiger Gesamtdurchgang ist BD damit nicht. Der Status heisst überall so.

**AN3 und andere offene Testfälle:** Die Tabelle steht in `ABNAHMEAKTE.md` §3. Die wichtigsten:
- **B10:** AN3 ist im Code integriert, aber nie geprüft; die Zeilen widersprechen sich. Vor der Abnahme von B10 prüfe ich AN3 gegen den Brief, bereinige die Zeile und lasse AN3-C1 bis C3 mit Tests bauen.
- **B5:** braucht noch B5-T7 (10/10 zu zwei Tageszeiten). B5-T9 ist jetzt belegt.
- **B2:** B2-T7 und B2-T8 sind beschrieben, aber nicht geschrieben.
- **B1:** drei e2e-Tests fehlen, und Δ11 hat keinen Test.

**Künftig:** keine Gesamtzahl bestandener Tests mehr als Abnahmebeleg, nur die Blockakte.

## 2. Δ11 zuerst

Brief: [`../agents/briefs/SAFE-D11.md`](../agents/briefs/SAFE-D11.md), genehmigt als dokumentierte Sicherheitsausnahme. Nach einer Wiedereröffnung hat ein Fall ohne Team genau eines von zwei Ergebnissen, nie keines:
- **(A)** eine neue, zulässige Teamsuche, mit denselben Regeln wie die erste; die zurückgezogene Suche bleibt unverändert im Verlauf;
- **(B)** eine sichtbare Ausnahme bei Operations der Organisation: «Wiedereröffneter Fall ohne Team», mit den fehlenden Angaben, Priorität P2. Sie schliesst sich selbst, sobald eine Suche offen, ein Team zugeordnet oder der Fall wieder abgeschlossen ist.

Weiter verlangt der Brief:
- Nie automatische Zuweisung.
- Die normalen Ausnahmen (kein Team, Frist abgelaufen) gelten auch nach der Wiedereröffnung.
- Hat der Fall ein Team, behält er es.

**Reihenfolge:**
1. Roter Reproduktionstest auf einem Probe-Branch.
2. Lösung mit ADR.
3. `cra`-Gate.
4. Grün auf dem PR-Head.
5. Merge.
6. Grün auf dem Merge-Commit und 10/10 im Wiederholungslauf auf der Integrationslinie.
7. Eintrag in die Akte.

Erst danach aktiviere ich B1.1.

## 3. B1.1: Scope- und Gate-Entscheid

**Entscheid:** Zwei Punkte meiner ersten Fassung hängen an offenen Fach- und Rechtsfragen: die Bereitschaftsstufen je Auftragstyp und der Text der zuweisenden Stelle für das Team. **Ich schneide B1.1 kleiner.** Beide Punkte gehen in einen eigenen Teilblock **B1.1b**, der erst nach den Antworten von `cra` und `lca` beginnt. B1.1 baut nur, was ohne ungeprüfte Regel geht.

### 3.1 Bereitschaftsfelder nach Zweck und Auftragstyp

IST: sechs Punkte sperren heute die Teamsuche für **jeden** Auftrag (`private.case_readiness`, 0013:159-170): Einwilligung, Wohngemeinde und Kanton, Krankenversicherer, Versicherungsart, Pflegebedarf, gewünschter Beginn.

| Angabe | Teamangebot | Sichere Versorgung (vor dem ersten Einsatz) | Abrechnung | Klärung vor dem Bau |
|---|---|---|---|---|
| Region, Leistungsart, Umfang, Beginn, Dringlichkeit mit Quelle, Auftragstyp | alle Typen | – | – | keine (IST) |
| Einwilligung bzw. Rechtsgrundlage für die Weitergabe an Teams | alle Typen | – | – | `lca`: Reicht die Rechtsgrundlage des Auftraggebers (Heim, Spital), oder braucht es immer die Einwilligung der Person? |
| Identität, Adresse, Zugang, Kontaktperson, Hausärztin, andere Dienste, Sprache, Sicherheitshinweise (D-17) | – | alle Typen | – | `cra`: Welche davon sperren den ersten Einsatz, welche bleiben Aufgaben? |
| Ärztliche Anordnung (KLV-B) | – | vor B-Leistungen | Voraussetzung | IST (ORD), unverändert |
| Krankenversicherer, Versicherungsart | – | – | **Privatperson (KVG ambulant):** vor der Rechnung; **Heim und Spital mit Auftrag ans Team:** UNKNOWN, Zahler ist nach Vertrag die Einrichtung | `lca` mit Vertragsrolle (FE-040): Braucht das Team diese Angaben je Auftragstyp, und ab wann? |
| Wohngemeinde und Kanton (Restfinanzierung) | – | – | Privatperson ambulant: vor der Rechnung; Heim und Spital: UNKNOWN | `lca`: kantonale Zuständigkeit BS und BL |

**Bis zur Klärung bleibt alles wie heute: alle sechs Punkte sperren die Teamsuche.** Das ist streng, aber sicher. Zuerst lockern wäre eine ungeprüfte Regel.

### 3.2 Information der zuweisenden Stelle

- **Gespeichert (IMPLEMENTED):** Name und Typ der Stelle, Region, Ort, Dringlichkeit, Zeitangabe, Titel und Bedarfstext der Anfrage (`partner_requests`). Daran ändert B1.1 nichts; es werden keine neuen Felder erfasst.
- **Gezeigt heute:** Koordinationsrollen der Organisation sehen alles. Alle angefragten Teams der Region sehen einen Angebotstitel, den Operations aus dem Fallbedarf bildet. Den Bedarfstext der Stelle sieht kein Team.
- **Vorschlag für B1.1b**, braucht `lca` zur Minimierung:
  - angefragte Teams sehen nur strukturierte Angaben und keinen Freitext;
  - erst das Team mit «Versorgung zugesagt» sieht den Text der zuweisenden Stelle, unverändert und markiert (CGR-193 (4b));
  - andere Teams, andere Organisationen und der Coach sehen ihn nie.

### 3.3 Alte Freitext-Regionen

IST im synthetischen Seed: «Bern West» 18, «Bern Ost» 11, «Zürich Pilot» 8, «Basel Pilot» 1, «Basel-Stadt» 1. Die Teamsuche vergleicht den Text exakt.

**Entscheid für B1.1:**
- Es gibt eine Regionsliste. Für Phase A enthält sie Basel-Stadt und Basel-Landschaft (FE-019).
- Neue Anfragen, Fälle und Teams wählen nur aus der Liste.
- Bestehende Einträge behalten ihren Text. Eindeutige Treffer werden zugeordnet. Alles andere erscheint bei Operations als «Region nicht zugeordnet» und wird dort von Hand zugeordnet, mit Protokolleintrag.
- Für nicht zugeordnete Paare bleibt der heutige Textvergleich in Kraft, damit kein synthetischer Fall seine Teamsuche verliert.
- Die Seed-Abweichung (Bern, Zürich statt BS/BL) ändere ich nicht automatisch (FE-066, OFFEN).
- Test: gleiche Zahl Fälle vorher und nachher; jeder Altwert ist zugeordnet oder gelistet.

### 3.4 Zurückweisung, Rückfrage, Bearbeitungsstatus

- **Entscheid:** Eine Anfrage endet nur auf zwei Arten:
  - «in Fall überführt» (IST);
  - «zurückgewiesen» (neu, Δ5), mit Pflichtgrund: Duplikat, ausserhalb der Region, kein passendes Angebot, vom Auftraggeber zurückgezogen, oder anderer Grund mit Text. Bei «Duplikat» wird die andere Anfrage oder der Fall verknüpft.
- Zeit und Person werden protokolliert, **nichts wird gelöscht**, Aufbewahrung nach O-6 bei `lca`.
- **Offene Anfragen zeigen ihr Alter.** Ist eine Anfrage nach der Antwortfrist ihres Auftragstyps noch offen, entsteht eine Operations-Ausnahme P3. Die Frist gibt es schon (Spitalaustritt 4 Arbeitsstunden, Pflegeheim 1 Arbeitstag, Privat 2 Arbeitstage); es kommt keine neue Zahl dazu.
- **Rückfrage baue ich in B1.1 bewusst nicht.** Eine Rückfrage über Operations per Telefon ist genau die Vermittlerrolle, die wir vermeiden wollen. Sie kommt mit der Auftraggeber-Ansicht, als direkter Kanal zwischen Team und Auftraggeber.

### 3.5 Umfang B1.1 (nach dem Schnitt)

1. Regionsliste mit der Behandlung der Altwerte (Δ1).
2. Abschluss einer Anfrage: Zurückweisen mit Grund, Alter und Fristausnahme (Δ5).
3. Statuszeile nach «Fall eröffnen» (Δ7, UXR-165).
4. Die Anfrage zeigt «erfasst durch Operations im Auftrag von <Stelle>». Damit bleibt der Auftraggeber im Datenmodell der Anfragende und Operations nur die Erfassende (siehe §4).

**Nicht-Ziele:** Bereitschaftsstufen (B1.1b), Text der zuweisenden Stelle (B1.1b), Rückfrage, Teamangebot und Zusage (B1.2), Lebenszyklus (B1.3), automatisches Eröffnen.

**Tests auf dem finalen integrierten Commit:**
- pgTAP: Regionsliste und Altwerte, Zurückweisung, kein Löschen, Fristausnahme;
- RLS-Negativfälle: fremdes Team, fremde Organisation, Coach ohne Bearbeitung, `anon`;
- Unit-Tests für Texte und Gründe;
- e2e auf 390 und 1440 px: Erfassen mit Liste, Zurückweisen, Statuszeile;
- der BD-Durchgang bleibt grün;
- `ci` grün und `ci-repeat` 10/10 auf dem letzten B1.1-Merge-Commit; `uxa`-, `cra`- und `lca`-Zeilen je PR.

**Gates vor dem Start von B1.1:**
- SAFE-D11 abgenommen;
- `lca` zu O-6 (Aufbewahrung zurückgewiesener Anfragen). Bis dahin gilt der strengste Stand: nichts wird gelöscht.

## 4. Spätere Übergänge (Skizze)

**Zielmodell:**
1. **Heim, Spital oder Privatperson** erfasst die Anfrage in der eigenen Ansicht. In Phase A übernimmt Operations das stellvertretend, aber im Datenmodell ist die Stelle die Anfragende.
2. Eine **Vollständigkeitsregel** prüft die Angaben für das Teamangebot. Fehlt etwas, geht die Rückfrage direkt an den Auftraggeber.
3. **Regeln** bestimmen die geeigneten Teams und begründen das Ergebnis: Region, Tätigkeiten, Qualifikation, Nachweis, Delegation, Kapazität. Die KI erläutert und ordnet nur unter den Geeigneten.
4. Das **Angebot** geht gleichzeitig an alle geeigneten Teams, mit strukturierten Angaben und ohne Freitext.
5. Das **Team** entscheidet in zwei Stufen (§5). Der Auftraggeber sieht den Stand und das zugesagte Team.
6. **Betreiber-Ausnahme:** NAVORA Platform Operations sieht nur Ausnahmen:
   - unvollständig ohne Antwort;
   - kein geeignetes Team;
   - Frist abgelaufen;
   - dringliche Lücke;
   - Δ11.

   Operations darf klären, informieren und mit dem Auftraggeber Region oder Frist erweitern. **Operations weist nie ein Team zu und sagt nie für ein Team zu** (IMPLEMENTED als Invariante in OPS1).

**Damit die Phase-A-Erfassung nicht zur dauerhaften Vermittlungsstelle wird:**
- Ab B1.1 sind Anfragende und Erfassende im Datenmodell getrennt.
- Die Erfassung durch Operations ist als «Stellvertretung Phase A» beschriftet.
- Gemessen wird, welcher Anteil der Anfragen von Operations erfasst oder angefasst wurde. Ziel: nur noch Ausnahmen, sobald die Auftraggeber-Ansicht da ist.
- Es gibt keine Aktion «Team zuweisen».

Die Auftraggeber-Ansicht ordne ich in Lieferung 4 als eigenen Block ein.

## 5. «Wir prüfen» und «Versorgung zugesagt»

**IST:**
- Ein Klick «Zusage» eines beliebigen Teammitglieds gilt.
- Das Angebot geht parallel an alle Teams der Region; die erste Zusage gilt.
- Fristen je Auftragstyp wie oben.
- Nach der Frist entsteht «Angebot überfällig»; haben alle abgesagt, «kein Team mehr verfügbar».

**Optionen für «Wir prüfen»:**
- **(A) Reservierung mit Sperre:** Andere Teams können während der Prüfzeit nicht zusagen.
- **(B) Sichtbares Signal ohne Sperre:** Andere Teams sehen «1 Team prüft» und können trotzdem verbindlich zusagen. Die erste verbindliche Zusage gilt.
- **(C) Mischform:** Sperre nur bei nicht dringlichen Aufträgen.

**Empfehlung: (B) für Phase A.**
- Eine Sperre kann eine dringliche Versorgung verzögern, das Signal nicht.
- Die Teams bleiben selbständig, und es ist am einfachsten.
- Der Preis ist, dass zwei Teams gelegentlich doppelt prüfen. Das ist sichtbar und messbar.
- Ich wechsle zu (C), wenn die Simulation häufige Doppelprüfungen zeigt.

**Dauer des Signals:** Das Signal erlischt nach der halben verbleibenden Antwortfrist, höchstens bei Fristende, wenn keine Zusage kommt. Das Team bekommt einen Hinweis, ohne Folgen. Die Dauer ist aus der bestehenden Frist abgeleitet; es kommt keine neue Zahl dazu.

**Ausbleibende Antwort:** Bei Fristende entsteht die bestehende Ausnahme «Angebot überfällig» (P2). Das Angebot bleibt für Teams offen. Der Auftraggeber sieht «noch keine Zusage», mit Zeit (Zielmodell).

**Parallele Angebote:**
- Jedes geeignete Team erhält das Angebot zugleich.
- Ein Team kann mehrere Angebote halten.
- Die Kapazitätsprüfung bei der verbindlichen Zusage (B2-Kern, B1.2) verhindert Überbuchung.
- Mit der ersten verbindlichen Zusage schliesst das Angebot für alle anderen.

**Dringliche Versorgungslücken:**
- Bei Dringlichkeit «hoch» und bei Spitalaustritt wirkt nie eine Reservierung.
- Die Ausnahme «dringlich, noch keine Zusage» ist ab Angebotsstart sichtbar.
- Ob sie P1 ist und ab wann, sagt `cra`; bis dahin P2 ab Fristende, wie heute.
- **NAVORA verspricht nie eine Versorgung.** Bis zur Zusage bleibt die Versorgungsverantwortung beim Auftraggeber, und die Ansicht sagt ihm das. Den Wortlaut prüft `lca`.

**«Versorgung zugesagt» heisst:**
- Das Team verpflichtet sich, die Versorgung im beschriebenen Umfang ab dem gewünschten Beginn zu übernehmen.
- Möglich erst nach bestandener Regelprüfung: Tätigkeiten mit Qualifikation, Nachweis und Delegation; Kapazität.
- Nur durch ein Mitglied, das nach den Teamregeln zusagen darf. Das legt das Team in seinen Einstellungen fest; Standard wie heute: jedes Mitglied.
- Zeit und Person werden protokolliert. Ein Rücktritt danach ist eine Übergabe oder Ausnahme (B1.3).
- Ob die Zusage einen Vertrag begründet und mit wem, ist eine Frage für `lca` (FE-040, Rechtsform OFFEN). Bis dahin heisst sie im Produkt nur «Zusage des Teams».

Gebaut wird das in B1.2, nach dem B2-Kern.

**Übergangsregel bis zum Entscheid der Clinical Owner zu CGR-196 (PO, 12.11.2026 17:39):** Das bestehende RET1-Erstrecht-Fenster (0034:146-151) bleibt unverändert; es berücksichtigt die Dringlichkeit heute nicht. Der Satz «bei Dringlichkeit ‹hoch› wirkt nie eine Reservierung» gilt für das neue Signal «Wir prüfen» (B1.2), nicht rückwirkend für RET1. Das ist eine bekannte Lücke der Simulation und steht so in der Abnahmeakte; die Wahl zwischen den drei Optionen von `cra` (CGR-196) trifft die Clinical Owner (D-43). Der PO setzt keine Zahl und keine klinische Regel.

## 6. Prompts und Agentensteuerung

Siehe [`../agents/BLOCK_RULE_PROMPTS_2026-11-12.md`](../agents/BLOCK_RULE_PROMPTS_2026-11-12.md): genauer Wortlaut, geänderte Aufgaben und Konflikte mit bisherigen Anweisungen.

## 7. Termine

- **Lieferung 2:** Freitag, 13. November 2026. Geschäftsmodell in meinen Worten (Teamabo ohne Provision, getrenntes B2B-Geschäft, Ziel für Pflegende als Hypothese) und vollständige kritische Bewertung von B1.
- **Lieferung 3:** Montag, 16. November 2026. Gesamtplattform mit Ansichten, Rollen, Daten- und Geldflüssen, Betreiber-Finanzen, Coach und Angehörigen; dazu der Entwurf des regelbasierten Matchings mit der Rolle der KI.
- **Lieferung 4:** Dienstag, 17. November 2026. Endgültige Blockplanung mit den neuen Plattformteilen und drei priorisierte Differenzierungsideen mit Validierungsschritt.
