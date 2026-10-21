# NEXT_CAPABILITY

**Owner:** Product Owner (alleiniger Schreiber). **Leser:** Engineering Agent. **Stand:** 2026-10-21, Revision 2.

## Protokoll

- Diese Datei enthält genau **eine** aktive Fähigkeit („Aktiv“) und eine priorisierte Warteschlange.
- Nur der Product Owner ändert „Aktiv“ und die Reihenfolge. Engineering schlägt Änderungen über `OPEN_DECISIONS.md` vor.
- Engineering startet eine Fähigkeit erst, wenn sie hier „Aktiv“ ist und keine blockierende Entscheidung in `OPEN_DECISIONS.md` offen ist.
- Fortschritt und Nachweise gehören in `IMPLEMENTATION_STATUS.md`, nicht hierher.
- Eine Fähigkeit gilt als abgeschlossen, wenn alle Akzeptanzkriterien in `IMPLEMENTATION_STATUS.md` mit Nachweis abgehakt sind **und** der Product Owner abnimmt. Dann rückt die nächste nach.
- Strategische Primärreferenz: `ARCHITECTURE.md`. Weitere Grundlagen: `PRODUCT_REQUIREMENTS.md`, `ROADMAP.md`, Doc „NAVORA Product Plan J1–J3“.

## Aktiv

### F0 Shared Access Foundation for J1–J4

**Priority:** Critical · **Roadmap:** Gate 1 · **Status:** DECIDED, freigegeben 2026-10-21

**Why:**
Keine Versorgungsreise kann mit echten Partnern oder Teams laufen, solange der Zugriff nicht abgegrenzt ist. Die Live-Datenbank sperrt derzeit alle Zugriffe (RLS ohne Policies) und das Schema ist nicht versioniert. Das Zugriffsmodell wird einmal für J1–J4 entworfen (Architektur: Identity & Governance, serverseitige Autorisierung, Rollen plus tatsächlicher Versorgungskontext).

**Expected user outcome:**
Ein Partner sieht nur eigene Zuweisungen, ein angebotenes Team nur sein Angebot, ein zugewiesenes Team seinen Fall, sonst niemand etwas.

**Acceptance criteria:**
- [ ] Aktuelles Live-Schema als versionierte Migrationen; frisch aufgebaute Datenbank entspricht Live.
- [ ] Organisationen, Teams, Mitgliedschaften und Qualifikationen (dipl. Pflegefachperson, Pflegeassistenz) existieren als Daten.
- [ ] Negativtests bestehen: anonym → nichts; Partner A ≠ Partner B; Team X ≠ Team Y; nicht zugewiesene Pflegekraft → keine Falldetails.
- [ ] Jeder zustandsändernde Command schreibt Audit (wer, wann, was, warum) und ist idempotent bei erneutem Senden.
- [ ] Synthetische Testdaten geladen, keine realen Personen.
- [ ] Leaked-Password-Schutz aktiv; GraphQL-Sichtbarkeit sensibler Tabellen geprüft.

**Dependencies:**
Repository-Inventar (VERIFY AGAINST REPOSITORY); Entscheid Command-Stil (OD-E1).

**Implementation recommendation:**
Branch und Supabase-Branch-Datenbank, nie direkt auf Live. Reihenfolge: Migrations-Baseline → Identitätstabellen → Policies mit Negativtests → wiederverwendbarer Audit-/Idempotenz-Baustein. Deny by default; jede Zugriffsregel auf ein Akzeptanzkriterium aus J1–J4 rückführbar.

## Warteschlange

| Rang | Fähigkeit | Priorität | Roadmap | Bounded Context (ARCHITECTURE.md) | Blockiert durch |
| --- | --- | --- | --- | --- | --- |
| 1 | J1 Referral Intake → Case → Matching Request | Critical | Gate 2 | Partner Intake, Cases | F0; OD-F1; OD-C1 |
| 2 | J2 Team Decision Workflow | High | Gate 2 | Matching, Team Self-Organization | J1; OD-O1–O3 |
| 3 | J3 Visit Planning | High | Gate 2 | Team Self-Organization, Field Operations | J2; OD-C2 |
| 4 | J4 Verified Visit (inkl. signierter Einsatzbericht) | High | Gate 2 | Field Operations, Documentation | J3 |
| 5 | Q1 Quality Signals and Quality Hold **(neu)** | High | Gate 2 | Quality/Clinical Intelligence | J4; OD-C4 |
| 6 | OPS1 Operations Exception Center **(neu)** | High | Gate 2 | Operations | J1–J3, Q1; OD-O4 |
| 7 | J5 Billable Visit Facts and Monthly Revenue Preview | High | Gate 3 | Finance/Payroll | J4, Q1; OD-F1; OD-C3 |
| 8 | J6 Continuity of Care: Primary Nurse | High | Gate 3 | Team Self-Organization | J3, J4 |
| 9 | J7 Team Economics Transparency | Medium | Gate 3 | Finance/Payroll | J5; OD-F4 |

Vollständige Briefs F0, J1–J3: Doc „NAVORA Product Plan J1–J3“. J5–J7: Product-Owner-Antwort vom 2026-10-21. Q1, OPS1 und J4-Ergänzung: unten. Sobald eine Fähigkeit aktiv wird, wird ihr vollständiger Brief in „Aktiv“ übernommen.

## Änderungen Revision 2 (Abgleich mit ARCHITECTURE.md)

| Änderung | Grund laut Architektur |
| --- | --- |
| J4 um signierten Einsatzbericht ergänzt | Datenfluss: „menschlich freigegebener Bericht → Quality Gate → billable_facts“. Ohne freigegebenen Bericht keine Abrechnungsfakten. |
| Q1 neu, vor J5 | Quality Gate und Quality Hold stehen im Datenfluss vor `billable_facts`; Quality/Clinical Intelligence ist nur teilweise umgesetzt (`quality_events` ohne Workflow). |
| OPS1 neu, vor J5 | Operations ist laut Architektur ein ausnahmebasierter Control Tower. J1–J3 erzeugen Ausnahmen (blockierte Fälle, überfällige Angebote, unbesetzte Einsätze), die heute niemand sieht; die alte Operations-Seite liest Tabellen, auf die keine Policy Zugriff gibt. |
| J5 hängt neu von Q1 ab | Keine Abrechnungsfakten bei aktivem Quality Hold. |

## Brief-Ergänzung J4 Verified Visit

Zusätzliche Akzeptanzkriterien:
- [ ] Ein Einsatz endet mit einem Einsatzbericht (Zeiten, Leistungen je Kategorie, Beobachtung, Übergabe), den die durchführende Pflegekraft signiert.
- [ ] Ein nicht signierter Bericht bleibt Entwurf und erscheint nirgends als final oder abrechenbar.
- [ ] Nach der Signatur ist der Bericht unveränderlich; Korrekturen erzeugen eine neue Version mit Grund und Verweis.

KI-Entwürfe bleiben Gate 4; die Signatur gilt dem von Menschen erfassten Inhalt.

## Brief Q1 Quality Signals and Quality Hold

**Capability:** Q1 Quality Signals and Quality Hold
**Priority:** High · **Roadmap:** Gate 2

**Why:**
Qualität ist das Versprechen gegenüber Klientinnen, Partnern und Kanton, und die Architektur setzt ein Quality Gate vor jede Abrechnung. Ohne Weg von der Beobachtung im Einsatz zu Team und Coach gehen Warnsignale (Sturz, Wundverschlechterung, Medikationsproblem, Verdacht auf Verwahrlosung) in Freitext verloren. Ohne Quality Hold würden strittige Einsätze automatisch abgerechnet.

**Expected user outcome:**
Eine Pflegekraft markiert im Einsatz ein Ereignis aus einer kurzen Liste; das Team sieht es sofort am Fall, der Coach bei schweren Ereignissen ebenfalls. Ein Einsatz mit offenem Hold erscheint nicht als abrechenbar, bis eine berechtigte Person ihn prüft und freigibt oder korrigiert.

**Acceptance criteria:**
- [ ] Qualitätsereignis aus J4 erfassbar mit Typ (fachlich freigegebene Liste), Schweregrad, Zeitpunkt, Fall, Einsatz, Erfasserin.
- [ ] Ereignisse sind für das zugewiesene Team sichtbar; schwere Ereignisse zusätzlich für Coach und Qualitätsfachperson; für andere Teams unsichtbar.
- [ ] Jedes Ereignis hat einen Status (offen, in Prüfung, abgeschlossen) mit Verantwortlicher und Abschlussnotiz; Übergänge auditiert.
- [ ] Definierte Ereignistypen oder ein manueller Entscheid setzen einen Quality Hold auf den Einsatz; J5 zählt Einsätze mit offenem Hold nicht als abrechenbar.
- [ ] Hold aufheben nur durch berechtigte Rolle mit Begründung.
- [ ] Keine automatische klinische Bewertung, keine KI-Risikoprognose in Q1.

**Dependencies:** J4; OD-C4 (Ereignistypen, Schweregrade, Hold-Regeln, Rollen).

**Implementation recommendation:**
Bestehende Tabelle `quality_events` gegen Live-Schema prüfen und in den F0-Zugriffsrahmen einbinden. Hold-Regel als deterministische, versionierte Regel im gemeinsamen Regelbaustein, von J5 wiederverwendet.

## Brief OPS1 Operations Exception Center

**Capability:** OPS1 Operations Exception Center
**Priority:** High · **Roadmap:** Gate 2

**Why:**
Selbstorganisation funktioniert nur mit einem Sicherheitsnetz: kein Fall darf still warten, kein Einsatz unbesetzt bleiben. NAVORA Operations greift laut Architektur nur bei Ausnahmen ein, nicht als Disposition. Eine kleine Operations-Gruppe kann so viele Teams begleiten; das ist der Skalierungshebel des Modells. Ohne OPS1 sind die Eskalationskriterien von J2 und J3 nicht erfüllbar.

**Expected user outcome:**
Operations öffnet eine Liste offener Ausnahmen, nach Dringlichkeit sortiert, jede mit Grund, Alter, betroffenem Fall/Team und nächstem Schritt. Wer eine Ausnahme übernimmt, ist sichtbar; erledigte Ausnahmen verschwinden mit Nachweis.

**Acceptance criteria:**
- [ ] Ausnahmen aus: Fall länger als Schwelle nicht „Ready for matching“ (J1); Angebot überfällig oder alle Kandidaten erschöpft (J2); unbesetzter Einsatz innerhalb 24 h, Anordnung abgelaufen, Pflegeplan-Review überfällig (J3); schweres Qualitätsereignis offen (Q1).
- [ ] Jede Ausnahme zeigt Grund, Entstehungszeit, Fall, Team und Link zum Ursprung; Daten nur im Umfang, den Operations sehen darf.
- [ ] Übernehmen, kommentieren, abschliessen sind auditierte Commands; Abschluss erfordert Begründung.
- [ ] Höchstens sechs Kennzahlen (PRODUCT_REQUIREMENTS: Operations); kein Matching-Start, keine Fallbearbeitung aus OPS1.
- [ ] Ausnahmen entstehen aus Zuständen, nicht durch manuelle Eingabe; eine behobene Ursache schliesst die Ausnahme automatisch mit Vermerk.

**Dependencies:** J1–J3, Q1; OD-O4 (Schwellen und Dringlichkeit).

**Implementation recommendation:**
Ausnahmen als abgeleitete Sicht über den Zuständen von J1–J3 und Q1, nicht als zweite Datenhaltung. Bestehende `/operations`-Seite und Query gegen Repository prüfen und auf die neue Sicht umstellen statt neu bauen.

## Nicht starten ohne Freigabe

Gate 4–8: KI-Dokumentation, Matching-Qualität, interRAI-HC-/LTCF-Adapter, Rule-Plattform/Architect Mode, Versicherer-E-Billing, Payroll, Partnerportal.
