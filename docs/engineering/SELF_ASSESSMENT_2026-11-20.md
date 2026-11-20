# Engineering-Selbstbewertung 2026-11-20 (Antwort an den Founder)

**Autor:** `eng` · **Stand:** `recovery/main` `269e4b5`, BK-f offen als #1581 · **Status:** Selbstbewertung, keine Abnahme. Der PO prüft die Belege; der Scorecard-Vorschlag (§4) ist PROPOSED und braucht den PO.

Frage des Founders (Live-Sitzung 2026-11-20 ca. 09:00): Wie zufrieden ist `eng` mit dem Produkt, offen und kritisch, je Bereich 1–5 mit Belegen, «nicht verifiziert», wo nicht selbst geprüft.

## Kurzfassung

Nein, heute würde ich nicht sagen: «Das ist eine gute Grundlage für die Plattform.» Ich würde sagen: **Die Sicherheits- und Datenschicht ist sorgfältig. Das Produkt darüber ist schmal und kaum auf Staging bewiesen. Und die Art, wie wir die Datenbank ändern, wird zur Bremse.** Wir haben viel Sorgfalt in Regeln, Rechte und Nachweise gesteckt und zu wenig in einen Ablauf, den ein Pflegeheim heute von Anfang bis Ende benutzen könnte.

## 1. Bewertung je Bereich

| # | Bereich | Note | Begründung und Belege | Wichtigste Verbesserung |
|---|---|---|---|---|
| 1 | Funktionierendes Produkt | **2** | Auf Staging bewiesen sind (IMPLEMENTED) genau drei Abläufe, alle zum ersten Mal heute: Anmeldung der drei Testkonten; Auftrag → anderes Team sieht ihn nicht → Pflegerin übernimmt → Kunde sieht «Gedeckt»; Nachtschicht als eine Karte auf `/field` bei 390 px. Beleg: `staging-smoke` Run 44699041140, 3/3. Noch nie auf Staging ausgeführt (UNKNOWN dort): Bericht unterschreiben auf `/field`, Bericht-Entwurf, Abwesenheit, J5-Abrechnung, `/operations`, `/admin`, alle Ansichten ausser den drei Pfaden. In CI auf lokalem Stack getestet heisst nicht «auf Staging bedienbar». | Jedes Paket bringt seinen Ablauf als neuen Pfad in `staging-smoke` mit; erst dann gilt es als geliefert. |
| 2 | Codequalität | **2** (SQL) · TypeScript **nicht verifiziert** | Die Geschäftslogik steckt grösstenteils in PL/pgSQL: 38 819 Zeilen Migration gegen 31 897 Zeilen TypeScript. **45 von 151 Migrationen ändern bestehende Funktionen per Textersetzung** (`*_patch`-Hilfsfunktionen auf `pg_get_functiondef`). Damit steht der gültige Text einer Funktion in keiner Datei mehr. Heute selbst erlebt: Meine Kopie von `generate_billable_facts` aus 0051 hat den LEAVE1-3-Schutz verloren, den 0074 hineingepatcht hatte (pgTAP 074 rot, Job 136125670120). Zwei Abrechnungsmodelle nebeneinander (J5/KLV über `cases`, BK über Aufträge ohne Fall); BKF-F1 war genau diese Naht. Den TypeScript-Teil habe ich in diesem Lauf nicht systematisch gelesen. | Eine lesbare Quelle je Funktion: Supabase «declarative schemas» oder ein CI-Schritt, der den aktuellen Funktionstext nach `supabase/schema/` schreibt und Abweichungen anzeigt. Danach keine neuen Text-Patches mehr. |
| 3 | Frontend und Bedienbarkeit | **nicht verifiziert** | Ich habe `/order`, `/team` und `/field` in diesem Lauf nicht selbst bedient, nur über CI-Screenshots, e2e und den Smoke. 22 Seiten unter `src/app`, darunter Module aus der Ausrichtung vor FE-066, einem fallbasierten Modell mit Fallaufnahme und KLV-Abrechnung (`intake`, `visits`, `work`, `analytics`, `partners`), die neben dem BK-Ablauf stehen. NAVORA ist kein Spitex-Ersatz, sondern das Betriebssystem für selbstorganisierte Teams (Blueprint V3.2 §1.1, FE-066); welche davon BK-Rollen brauchen, habe ich nicht geprüft. Meine Vermutung, nicht geprüft: Für eine Pflegende ist nicht klar, welche Teile für sie gelten. | Ein durchgehender Klickweg je Rolle (Kunde, Team, Pflegende) mit `uxa` auf Staging, und nicht benötigte Altseiten für BK-Rollen ausblenden. |
| 4 | Backend und Datenbank | **3** | Stark (IMPLEMENTED): RLS auf jeder Tabelle, Spalten-Grants, Audit-Trigger, idempotente Befehle mit `begin_command`, LEAVE1-Zugriffsende in jedem Lesemodell, Katalog-Tests, die neue Lücken automatisch finden. Schwach: die Text-Patches (Bereich 2); sehr viel Logik in der Datenbank, schwer zu debuggen und zu profilieren; zwei Datenmodelle; `tariff_rates`/`billing_rules` heute für jeden angemeldeten Nutzer lesbar (G-6, wird in BK-f behoben). | Vor BK-d und BK-g: Funktionsquellen konsolidieren (siehe 2) und das J5/KLV-Modell klar vom BK-Modell trennen, mit dokumentierter Grenze. |
| 5 | Tests und Zuverlässigkeit | **3** | Viel und echt (IMPLEMENTED): 153 pgTAP-Dateien mit 5509 Prüfungen, 1598 Unit-Tests, 47 e2e-Dateien, `ci-repeat` 10/10 auf `8155ac6`. Wo Grün täuscht: (a) e2e läuft gegen lokalen Stack und Seed, nicht gegen Staging; (b) Unit-Tests übergeben Objekte und sahen nicht, dass der gebaute Versions-Footer leer war (heute behoben, #1580); (c) Positivlisten-Tests (z. B. pgTAP 144: «keine weitere Spalte auf `order_takes`») schützen gut, brechen aber bei jeder legitimen Erweiterung; (d) noch keine Tests für Last, Offline, langsames Netz oder echte Mobilgeräte. | Staging-Smoke als Pflichtschicht über e2e (siehe 1) und ein Test pro Paket «gebaute App», nicht nur Funktionen. |
| 6 | Staging und Auslieferung | **3** | IMPLEMENTED: Migrationen kommen nur über den CI-Job `staging` nach `navora-staging`; Render baut `recovery/main`; seit heute prüft `staging-version`, ob App und Datenbank zusammenpassen (Run 44689871317 grün: Commit `a04dd77`, Migration 0153). Seit heute läuft der Klicktest. Bis heute Morgen konnte niemand automatisch sagen, ob ein Ablauf auf Staging funktioniert. CI-Infrastruktur bricht oft ab (Docker «Rate exceeded», Port 54322 belegt); `DOCKERHUB_USERNAME` war bis heute leer. | `staging-smoke` automatisch nach jedem Merge und stündlich; rot → Benachrichtigung an PO und `eng`. |
| 7 | KI als Produktkern | **1** | In keiner Umgebung ist ein KI-Modell angeschlossen (IMPLEMENTED als Fakt). Der Bericht-Entwurf auf Staging ist ein Testersatz «regelbasiert, keine KI». Der Claude-Pfad ist gebaut und mit einer Attrappe getestet, aber nicht verbunden. Matching, Planung und Stoppregel sind feste Regeln. Hindernisse (Korrektur 09:40): Der Anbieter ist entschieden (FE-094: Anthropic-API direkt, nur Staging, nur synthetische Daten; FE-097: Berichtsentwurf mit echtem Claude zuerst). Offen sind die `lca`-Lesung der Anbieterbedingungen (FE-094 (c)), die Umgebungswerte auf Render durch den Founder und ein Smoke-Pfad mit gemessener Latenz und Kosten. Technisch steht der Weg bis zum Aufruf. | Den vorhandenen BK-e2-Weg anschliessen (STAB-1-Vorschlag §8–§9): erste echte Funktion Notiz → Berichtsentwurf mit Unterschrift durch die Pflegende, auf synthetischen Daten, mit Kill-Switch, Kosten- und Latenzmessung. |
| 8 | NAVORA-Vision | **2** | Echt neu: Ein Team übernimmt einen Auftrag selbst, ohne Disposition, mit harter Qualifikationsprüfung; mit BK-f schreibt niemand mehr eine Rechnung. Gleichzeitig ist viel aus der Zeit vor FE-066 gebaut, das alte Abläufe nur digital abbildet (KLV-Monatsabrechnung, Fallaufnahme, Arbeitszeit), und vieles davon nutzt heute niemand. Der Nutzen für ein Pflegeheim (Dienstplan, Abwesenheit, Station) ist noch nicht gebaut. | Ab jetzt je Paket eine Zahl, die Arbeit misst: Taps oder Minuten von «Bericht unterschreiben» bis «Rechnung beim Kunden» (Q8). |
| 9 | Entwicklungsgeschwindigkeit | **2** | Schätzung für den Lauf heute 07:11–08:00 (ESTIMATE, nicht gemessen): Programmieren ca. 25 %, CI warten und CI-Folgen beheben ca. 35 %, Lesen von Steuerdokumenten ca. 25 %, Journal und Berichte ca. 15 %. Belege für den Steueraufwand: `docs/` 26 MB, `DECISIONS.md` 1,1 MB, `NEXT_CAPABILITY.md` 0,5 MB, 567 Journaldateien. Sechs BK-f-Pushes, davon drei rot: einmal gewollt (Red-first), einmal mein Fehler (Text-Patch), einmal eine Positivliste. Jede Runde kostet 10–15 Minuten CI. | Grösster vermeidbarer Engpass: die Menge der Steuertexte, die jeder Lauf lesen muss. Vorschlag: eine kurze «Arbeitskarte» je Paket (Vertrag, offene Punkte, letzter CI-Stand, unter 2 Seiten). Die grossen Dateien bleiben Archiv. |
| 10 | Technische Innovation | — | Siehe §3. | — |

## 2. Fünf Fragen

**Worauf bin ich stolz?** Auf die Sicherheits- und Datenschutzschicht: Kein Lesemodell gibt einer ausgeschiedenen Person noch Daten. Das prüft ein Katalog-Test, der auch neue Funktionen automatisch erfasst. Und auf die Haltung «zuerst rot zeigen, dann beheben». BKF-F1 wurde aus Codelesen vorhergesagt und heute in CI genau so rot gezeigt (23502), bevor es einen Kunden erreichen konnte.

**Drei Dinge, die ich anders machen würde:**
1. Keine Funktionsänderungen per Textersetzung. Von Anfang an eine lesbare Quelle je Funktion.
2. Früher auf Staging prüfen. Den Klicktest hätte es mit dem ersten Ablauf geben müssen, nicht nach Block BK-e.
3. Weniger, aber dafür fertige Abläufe. Lieber einen Weg, den ein Pflegeheim durchklicken kann, als viele vorbereitete Module (J5, Fallaufnahme, Analytik), die heute niemand benutzt.

**Grösste technische Sorge für die nächsten BK-Schritte:** Die Text-Patches. BK-d (KI-Erfassung des Auftrags) und BK-g (Szenario-Matrix mit Uhrumstellung) greifen wieder in `order_member_step`, `recheck_member_takes` und die Visit-Funktionen ein, die schon mehrfach gepatcht sind. Jede weitere Änderung riskiert, einen früheren Schutz still zu verlieren, wie heute bei 0154. Die Katalog-Tests fangen das bei LEAVE1, aber nicht bei jeder Regel.

**Was ich brauche:**
- Vom PO: (a) Ein kleines Aufräumpaket vor BK-d, das ich hier begründe: Funktionsquellen konsolidieren, kein neues Verhalten. (b) Kürzere Steuertexte je Paket (Arbeitskarte). (c) Den Staging-Smoke-Pfad als Abnahmebedingung jedes Pakets.
- Vom Founder: (a) Die Umgebungswerte für Claude auf Render `navora-staging`, sobald der PO den Schritt freigibt (Anbieter schon entschieden, FE-094); und ob die `lca`-Lesung der Anbieterbedingungen vorher nötig ist. (b) Bei Bedarf eine Freigabe für einen echten Pflegeheim-Ablauf als nächsten Block (Station, Dienstplan, Abwesenheit). Das entscheidet der PO mit dir. Die Secrets sind seit heute gesetzt, danke.

**Würde ich Staging heute einem Pflegeheim vorführen?** Nein. Heute zeigt Staging einen Ablauf für Haushalte: Schicht bestellen, übernehmen, «Gedeckt». Für ein Pflegeheim müsste vorher funktionieren und auf Staging per Smoke bewiesen sein:
1. eine Station als Kunde (die Sektorkonfiguration `client_kind` existiert, der Ablauf nicht);
2. Schicht → Bericht unterschreiben → Rechnungsentwurf → gesendet (BK-f, in Arbeit);
3. Abwesenheit einer Pflegenden und was dann mit der Schicht passiert (Grundlage CGR-250 gebaut, auf Staging nicht als Smoke-Pfad bewiesen);
4. eine sichtbare KI-Funktion mit menschlicher Unterschrift (Sprache → Bericht);
5. ein Demo-Datensatz mit glaubwürdiger Station und Team, ohne Altseiten, die verwirren.

## 3. Innovationsvorschläge (für den PO, nicht im laufenden PR)

1. **Eine Quelle je Datenbankfunktion** (Plattform-Gesundheit, Voraussetzung für schnelleres Bauen). Nutzen: weniger stille Regressionen, schnellere Reviews. Kosten: ein Paket ohne neues Verhalten, ca. 3–5 Läufe (ESTIMATE). Rückweg: Die Migrationen bleiben unverändert; die Schema-Dateien sind zusätzlich.
2. **Rechnung, die ihren eigenen Beweis trägt:** Jede Zeile verlinkt auf den unterschriebenen Bericht und die erfassten Zeiten. So prüft die Buchhaltung eines Heims ohne Rückfrage. Das kann eine Temporärfirma nicht bieten.
3. **Sprache → Bericht mit Unterschrift** als erste echte KI-Funktion (Anbieter entschieden, FE-094). Grösster sichtbarer Nutzen für Pflegende: weniger Tippen am Ende der Schicht.
4. **Staging-Smoke als lebende Produktliste:** Jeder grüne Pfad ist eine Funktion, die der Founder bedienen kann. Die Liste ersetzt Statusberichte.

## 4. Scorecard je Teilblock (Vorschlag an den PO, PROPOSED)

Die acht Kriterien des Founders halte ich für richtig. Aus Engineering-Sicht fehlen sechs Punkte:

| # | Kriterium | Beleg |
|---|---|---|
| 1 | Der vereinbarte Nutzerablauf funktioniert | e2e-Test benannt |
| 2 | Auf einem benannten Stand der echten Staging-App bedienbar | `staging-smoke` Run-ID, Pfad für dieses Paket |
| 3 | App und Datenbank synchron | `staging-version` grün auf dem Merge-Commit |
| 4 | Positiv-, Negativ- und Zugriffsprüfungen ausgeführt | Job-IDs `db`, `e2e`; `ci-repeat` 10/10 |
| 5 | Fach- und Sicherheitsgates liegen vor | Gate-Zeilen auf dem PR |
| 6 | Bekannte Grenzen offen genannt | Abschnitt im Ready-Bericht |
| 7 | Spart Arbeit nachvollziehbar | gemessene Zahl (Taps, Minuten, wegfallende Eingaben), vorher → nachher |
| 8 | Mindestens ein begründeter Vorschlag, PR nicht vergrössert | Vorschlag als eigene Zeile oder Issue |
| **9 (neu)** | **Frühere Abläufe nicht gebrochen** | alle bisherigen Smoke-Pfade weiter grün |
| **10 (neu)** | **Rückweg dokumentiert und möglich** | «Way back» in der Migration oder ADR |
| **11 (neu)** | **Datenschutz und Least Privilege für neue Daten** | pgTAP als fremde Rolle und als Kunde; keine echten Daten |
| **12 (neu)** | **KI-Kennzeichnung ehrlich** | jede Funktion als feste Regel, Testersatz oder angeschlossenes Modell |
| **13 (neu)** | **Mobil nutzbar** | 390-px-Prüfung des neuen Ablaufs (`uxa`) |
| **14 (neu)** | **Zeit bis Staging gemessen** | Vertrag → Merge → Smoke grün, in Stunden; zeigt Engpässe ehrlich |

Nicht in die Scorecard gehören Anzahl Commits, Zeilen, Tests oder Journaleinträge.

Ich bewerte mich nach dieser Liste. Der PO prüft die Belege und entscheidet über die Abnahme.


**Korrektur 2026-11-20 09:40 (`eng`):** In der ersten Fassung stand, der Anbieter-Entscheid fehle (D-41), und BK-d seien Absenzen. Beides war falsch: Der Founder hat FE-094 und FE-097 entschieden; BK-d ist die KI-Erfassung des Auftrags. Abwesenheit ist in BK-e (CGR-250) schon teilweise gebaut.
