# Plattform-Rahmen (gilt für jeden Block)

**Stand:** Entwurf 2026-11-12 13:30 (`po`, FE-068) · **Code-Stand:** `recovery/main` `4891ac3` · **Prüfung:** `uxa` (Abschnitte 2 bis 5), `lca` (Abschnitt 6), `cra` (Abschnitt 7) angefragt 2026-11-12

Kennzeichnung: siehe [`README.md`](README.md) (IST, SOLL Δ, OFFEN, UNKNOWN, SIM).

## 1. Der durchgehende Ablauf und wem welcher Block gehört

| Schritt | Ambulant (Phase A) | Heimstation, simuliert (Phase A) | Block |
|---|---|---|---|
| 1 Anfrage | Zuweisung → Fall → Teamsuche | Aufnahme einer Bewohnerin | B1, B9 |
| 2 Tätigkeiten und Qualifikation | Prüfung je Tätigkeit (QAM, D-43 als SIM) | dieselbe Prüfung je Schicht | B2 |
| 3 Planung | Team plant, KI schlägt vor, Team bestätigt | Schichtplan | B3, B9 |
| 4 Besuch | losfahren, Tür, starten, abschliessen | Schicht, Übergabe | B4, B9 |
| 5 Sicherheit | Signal, Eskalation, Rückmeldung | dasselbe | B5 |
| 6 Dokumentation | Bericht, Diktat, KI-Entwurf, Unterschrift | dasselbe | B6 |
| 7 Assessment und Pflegeplan | Bedarfsabklärung, Pflegeplan, Anordnung | Heim-Assessment | B7 |
| 8 Abrechnung | abrechenbare Fakten, Vorschau, Zeitregeln (D-18 als SIM) | je Bewohnertag | B8, B9 |
| 9 Kennzahlen | je Team und Monat, nie je Person | dasselbe | B10 |

BD prüft die Schritte 1 bis 9 als einen e2e-Lauf (`tests/e2e/durchgang-ambulant.spec.ts`).

## 2. Rollen und Einstiegsseiten

**IST** (`src/lib/auth/nav.ts:16-21, 70-140`, `src/lib/auth/shell.ts`).

| Rolle (Organisation) | Darf öffnen | Startseite |
|---|---|---|
| `admin` | Ausnahmen, Aufnahme, Kennzahlen, Administration, Mein Arbeitstag, Meine Einstellungen; Team-Seiten nur mit Teammitgliedschaft | Ausnahmen |
| `operations` | Ausnahmen, Aufnahme, Kennzahlen, Mein Arbeitstag, Meine Einstellungen | Ausnahmen |
| `coach` | Ausnahmen, Kennzahlen (ohne Aufnahme) | Ausnahmen |
| Teammitglied (Pflegefachperson `registered_nurse` oder Assistenz `care_assistant`) | Mein Tag (`/field`), Dein Team (`/team`), Mein Arbeitstag, Kennzahlen, Meine Einstellungen | Mein Tag |

- Seitennamen sind fest (`PAGE_LABEL`, `nav.ts:38-48`): «Ausnahmen», «Aufnahme», «Mein Tag», «Dein Team», «Mein Arbeitstag», «Kennzahlen», «Meine Einstellungen», «Administration».
- «Partneranfragen» (`/partners`) ist eine statische Demo (ADR-006). Sie ist nicht Teil einer Spezifikation, bis REF2 entschieden ist (D-9, D-3; OFFEN).

**Navigation IST** (UX2-1, `shell.ts:11-59`):

- Handy (unter 768 px): untere Tab-Leiste mit höchstens vier Tabs, nämlich der Startseite, zwei weiteren Tabs und «Mehr». Teammitglieder haben «Heute», «Team», «Arbeitstag» und «Mehr». Was nicht als Tab erscheint, steht unter «Mehr»; dort sind auch «Meine Einstellungen» und «Abmelden».
- Desktop: Seitenleiste mit denselben Einträgen in derselben Reihenfolge.

**Regel G-1 (für jede Spezifikation):** Jeder Schritt wird über ein Bedienelement auf dem vorherigen Screen oder über das Menü erreicht. Es gibt keinen Schritt, den man nur per URL erreicht.

## 3. Bildschirmbreiten und Bedienung

- **Handy 390 × 844** für alle Pflegenden. **Desktop 1440** für Aufnahme und Ausnahmen. Die Aufnahme muss trotzdem auch bei 390 bedienbar sein.
- Kein seitliches Scrollen bei 390 px. Ziele mindestens 44 × 44 px. Jedes Bedienelement ist per Tastatur erreichbar und zeigt einen sichtbaren Fokus (B1-UX-7).
- Je Karte oder Formular höchstens **eine** gefüllte Hauptaktion. Weitere Aktionen sind Outline oder liegen in «Mehr».

## 4. Globale Zustände (gelten auf jedem Screen, sofern der Block nichts anderes sagt)

| Zustand | IST | SOLL |
|---|---|---|
| **Laden einer Seite** | Unter `src/app` gibt es kein `loading.tsx`. Die Seite rendert serverseitig erst, wenn alle Daten da sind; bis dahin bleibt der Bildschirm leer. | **Δ P-1:** Jede geschützte Route bekommt ein `loading.tsx`. Es zeigt einen Platzhalter je Abschnitt in der endgültigen Reihenfolge (Überschrift als Text, Karten als graue Flächen) und `aria-busy="true"`. Abnahme: e2e mit gedrosseltem Netz; der Platzhalter ist sichtbar und die Überschrift ist früher da als die Daten. |
| **Ladefehler einer Seite** | Ein Fehler beim Lesen wirft z. B. «Anfragen konnten nicht geladen werden.». Angezeigt wird die Standard-Fehlerseite von Next.js. | **Δ P-2:** Jede geschützte Route bekommt ein `error.tsx` mit der Überschrift der Seite, dem Satz «<Bereich> konnte nicht geladen werden.», dem Hinweis «Bitte erneut laden. Bleibt der Fehler, ist die Verbindung oder der Dienst gestört.» und der Schaltfläche «Erneut laden» (`reset()`). Die Seite zeigt keinen technischen Text und keinen internen Code. Abnahme: Unit-Test für die Komponente und e2e mit einem erzwungenen Lesefehler. |
| **Speichern läuft** | Die Schaltfläche zeigt «Wird gespeichert …» und ist gesperrt. Ein zweiter Tipp tut nichts. Befehle sind idempotent (`begin_command`). | unverändert. Abnahme B1-UX-2: e2e mit Doppeltipp bei 390 px. |
| **Befehl abgelehnt** | Der Text steht in `role="alert"` (`command-error`) direkt über der Schaltfläche. Die Texte sind je Befehlsergebnis fest (`ok`, `duplicate`, `rejected`, `taken`, `wrong_state`, `invalid`, …). | unverändert. Jeder Ablehnungstext nennt den Grund und den nächsten möglichen Schritt (G-4). |
| **Erfolg** | uneinheitlich: einige Befehle schreiben eine Statuszeile («Anfrage gespeichert.»), andere aktualisieren still. | **Δ P-3:** Nach jedem Befehl, der etwas an andere Personen weitergibt, erscheint eine `role="status"`-Zeile. Sie sagt, was gespeichert wurde und wer jetzt dran ist. Sie verschwindet nach 8 Sekunden oder beim nächsten Befehl und nennt keinen Klientennamen. |
| **Leere Liste** | Ein fester Satz je Liste, z. B. «Keine offenen Anfragen.». | unverändert. Jede Liste nennt in ihrem Leersatz, was sie zeigen würde. |
| **Keine Berechtigung** | Ein Satz an Stelle des Inhalts, z. B. «Die Aufnahme ist Admin- und Operations-Rollen vorbehalten.». | unverändert. |
| **Zugang beendet (LEAVE1)** | Jeder Befehl gibt `42501 access_ended` zurück, und jede Lesesicht liefert keine Zeilen (0074:125-133, 197-223). | **Δ P-4:** Die Seite zeigt einmal «Dein Zugang zu dieser Organisation ist beendet.» statt leerer Listen. Abnahme: e2e mit einem Konto, dessen Zugang beendet ist. |
| **Viele Einträge** | Die meisten Listen sind ohne Grenze und ohne Seitenaufteilung (z. B. `queries.ts:52-59`). | **Δ P-5:** Jede Liste zeigt zuerst 25 Einträge in der Reihenfolge des Blocks und darunter «Weitere 25 anzeigen (noch n)». Über 25 Einträgen erscheint ein Suchfeld («Suchen»), das in Titel, Region und Fallreferenz sucht. Abnahme: pgTAP oder e2e mit 60 synthetischen Einträgen. |
| **Lange Texte** | Freitexte stehen ungekürzt (`whitespace-pre-wrap`). | **Δ P-6:** Auf Karten wird ein Freitext nach 4 Zeilen abgeschnitten, mit «Mehr anzeigen» / «Weniger anzeigen» (Schaltfläche mit `aria-expanded`). Titel umbrechen, werden nie abgeschnitten. Ein Wort ohne Leerzeichen bricht hart um (`overflow-wrap:anywhere`). Abnahme: e2e bei 390 px mit 2000 Zeichen und einem Wort mit 120 Zeichen; kein seitliches Scrollen. |

## 5. Texte

- Deutsch (Schweiz), ohne «ß».
- In keinem sichtbaren Text steht ein interner Code (D-…, CR-…, CGR-…, SIG-…; G-6, Muster `tests/e2e/support/durchgang-time.ts:121`).
- Eine Pflicht steht nur dort, wo sie wirklich gilt (DESIGN_SYSTEM §4).
- Eine vorläufige Regel wird als solche bezeichnet: «Regel vorläufig, nicht fachlich freigegeben» (SIM, FE-069).
- Zeitangaben in Europe/Zurich. «heute» bedeutet den heutigen Tag in Zürich (0055).

## 6. Datenschutz und Sichtbarkeit (alle Blöcke)

- Jede Tabelle hat RLS. Alles läuft über `is_org_member`, also sieht eine andere Organisation nie etwas (IST).
- Gesundheits- und Versicherungsspalten sind für App-Benutzer gesperrt und nur über benannte Lesesichten lesbar (IST, 0013:63-74, 0015:66-69).
- Jeder Befehl schreibt Audit. Wer, was und wann wird nie gelöscht (append-only).
- Kein Klientenname in Statuszeilen, Benachrichtigungen, Ausnahmen oder Kennzahlen. Ausserhalb des zuständigen Teams stehen nur Fallreferenz, Datum und Grund (Richtung B8, L-3; OFFEN für `lca`).
- Keine Klienten- oder Personaldaten an einen KI-Dienst (D-35 Regel A). Phase A läuft nur mit synthetischen Daten (D-1, FE-066).

## 7. Regeln

Jede Regel, die eine Spezifikation nennt, hat eine ID im Register (`docs/agents/clinical/CLINICAL_RULE_REGISTER.md`) und einen Status. Heute ist keine Regel freigegeben (D-27). In Phase A laufen sie als SIM (FE-069). Eine Spezifikation erfindet keine Regel. Wo eine fehlt, steht OFFEN und wer entscheidet.

## 8. Abnahme je Block

Je Block gilt:

- Alle SOLL-Zeilen sind gebaut, jede mit ihrem Test.
- CI ist grün auf dem PR-Head und auf dem Merge-Commit (FE-054).
- Der Schritt des Blocks ist im BD-Lauf grün.
- Die Gate-Zeilen von `uxa`, `cra` und `lca` liegen vor, soweit der Block sie nennt.
