# NAVORA — Product Roadmap

**Stand:** 21. Oktober 2026 (ersetzt die Übergabe-Roadmap vom 9. Oktober 2026). **Owner:** Product Owner (`po`). **Roadmap = PLANNED**, priorisiert nach Umsetzung des Geschäftsmodells: jede Phase schliesst eine Lücke zwischen Zuweisung und abrechenbarer, fachlich sicherer Pflege. Termine, Budget und Personen **OPEN**. Statuslegende: `MASTER_CONTEXT.md`.

**Verbindliche Reihenfolge und Briefs:** `docs/agents/NEXT_CAPABILITY.md` und `docs/agents/briefs/`. **Umsetzungsstand:** `docs/agents/IMPLEMENTATION_STATUS.md` (Engineering). **Offene Entscheide:** `docs/agents/OPEN_DECISIONS.md`. Technische Roadmap: `docs/engineering/ROADMAP.md`. Bei Widerspruch gilt `docs/agents/`.

## Leitlinie

Versorgungskette (`ARCHITECTURE.md`): Zuweisung → Fall → Matching → Teamentscheid → Einsatzplanung → Einsatz → freigegebener Bericht → Quality Gate → Abrechnungsfakten.

Wertlogik (ambulante Pflege Schweiz): Erlös pro Stunde = OKP-Beitrag nach KLV Art. 7a (Kategorien A/B/C) + Patientenbeteiligung + Restfinanzierung (Kanton/Gemeinde). Jede Phase wird daran gemessen, ob sie abrechenbare Minuten pro bezahlter Stunde erhöht oder Erlösverlust durch fehlende Grundlagen verhindert: Bedarfsabklärung, ärztliche Anordnung (für B), Kostenträger, Zulassung.

## Änderungen gegenüber 9. Oktober 2026

- **DECIDED (Owner, PRIO-1):** Reihenfolge F0, J1, J2, J3.
- **Stand 22.10. 22:15:** ADM1-Nachbesserung (#135) vorgeprüft: die vier Änderungen sind erfüllt. Vor dem Merge noch eine Datenschutz-Korrektur: Das Team sieht bei freigegebenen Einsätzen nur „Mitglied aus dem Team entfernt", nicht die Begründung der Administration. HAND1 zeigt freigegebene Einsätze künftig als Tatsache ohne Grund (mit ABS1).
- **Stand 22.10. 20:15:** ADM1 (#101) geprüft: **changes-requested**. Alle Kriterien erfüllt, aber wer aus einem Team entfernt wird, bleibt für künftige Einsätze eingetragen; diese wirken abgedeckt und erreichen weder J3, OPS1 noch COVER1. Sie müssen im selben Schritt ans Team zurückgehen (gleiche Regel wie ABS1).
- **Stand 22.10. 18:20:** HAND1 (#128) und RET1 (#129) geprüft und **abgenommen**, mit Auflagen (HAND1: e2e-Test in Handybreite; RET1: Fortsetzung erst ab dem gewünschten Starttermin, Test für fehlende Qualifikation). Neu freigegeben: **ABS1** Abwesenheit ohne Telefonkette.
- **Stand 22.10. 17:15:** AN1-Nachbesserung geprüft und **abgenommen** (#124), mit Auflage: keine Rückschlüsse auf ausgeblendete Kleinteams über die Organisationszahl. In Arbeit: HAND1 (#128), RET1 (#129).
- **Stand 22.10. 16:15:** Nachbesserungen geprüft und **abgenommen**: COVER1 (bleibt bis D-3 abgeschaltet), PLAN2, C1 (Auflage: instabilen e2e-Test beheben), F7. AN1 in Prüfung (#124). Nächste Punkte: HAND1, RET1.
- **Stand 22.10. 14:50:** Analyse Pflegeheim-Transformation (`docs/product/NURSING_HOME_TRANSFORMATION.md`): selbstorganisierte Abteilungsteams statt Stationsleitung und LTCF-Hierarchie; Vorschläge NH0–NH9, nicht freigegeben; Entscheide D-24 (Owner), D-25 (legal).
- **Stand 22.10. 14:30:** C1, PLAN2, F7, AN1, COVER1 umgesetzt und geprüft: alle **changes-requested** (Begründungen in den Briefs). COVER1 bleibt bis D-3 abgeschaltet; D-21 entschieden.
- **Stand 22.10. 13:30:** Challenge-Modus: HAND1 und RET1 freigegeben, ORD1 Entwurf (D-22).
- **Stand 22.10. 12:00:** abgenommen F0, J1, J2, J3, F1-F4, F6, QG1, OPS1, J6; J5 mit einer Änderung. Neu: C1, ADM1, AN1.
- **IMPLEMENTED (Engineering, #7–#25):** SSR-Auth, Tenancy/RLS, auditierte idempotente Commands, Field-Slice F1–F4, J1, J2, J3. PO-Abnahme: J1, J2, J3 **changes-requested** (es fehlen Wohnort, Versicherer, Anordnungsstatus, KLV-Kategorie, geplante Minuten); F1-F4 abgenommen; F0 in Abnahmeprüfung.
- **NEU:** F6 signierter Einsatzbericht vor allem Nachgelagerten (Architektur: freigegebener Bericht → Quality Gate → billable_facts).
- **NEU:** QG1 Quality Hold und OPS1 Exception Center vor dem Erlösnachweis.
- **NEU:** Geschäftsvoraussetzungen (Pilotkanton D-11, Rechtsträger und OKP-Zulassung D-12) als Gate 0 vor jeder Abrechnung.
- **Vorschlag an Owner (D-13):** Assessment-Track von interRAI LTCF (stationär) auf interRAI HC (ambulant) umstellen; LTCF nur bei beschlossenem stationärem Angebot.
- **Verschoben:** Engineering-Vorschlag J4 (Teamkapazität) nach Gate 5.

## Gate 0: Wahrheit, Geschäftsgrundlage und Rechte

- Live-Schema gegen Migrationen (TD-19, ADR-022); Containment C-1; D-1, SR-26.
- **Owner-Entscheide, blockierend für Abrechnung:** D-11 Pilotkanton und -gemeinden; D-12 Rechtsträger für Betriebsbewilligung und OKP-Zulassung; Leistungsauftrag der Gemeinde ja/nein (beeinflusst Restfinanzierung).
- Klinische Fachverantwortung benennen (D-10, D-15, D-16); Lizenzklärung interRAI HC (D-13); Rechtsgrundlage Intake (D-9).
- Fertig, wenn Pilotkanton, Rechtsträger und Zulassungsweg entschieden sind.

## Gate 1: F0 Shared Access Foundation — Critical

- Brief `docs/agents/briefs/F0.md`, Engineering-Bericht `docs/agents/reports/F0.md`. Geliefert in #7–#9, #32, #34, #38. **Abgenommen 22.10.** Live-Reproduzierbarkeit bleibt Owner-Entscheid (T12, M5).
- Fertig, wenn alle Negativtests aus F0 bestehen und die Qualifikationen als Daten vorliegen.

## Gate 2: Care Journey MVP

Reihenfolge der offenen Punkte: ADM1-Nachbesserung → ABS1. Leitbild und North Star (direkter Pflegeanteil): `docs/product/CARE_OPERATING_MODEL.md` (Rangliste in `docs/agents/NEXT_CAPABILITY.md`).

| ID | Fähigkeit | Priorität | Stand |
| --- | --- | --- | --- |
| J1 | Zuweisung → Fall → Matching-Anfrage mit Readiness-Prüfung und Kostenträgerkette | Critical | IMPLEMENTED (#23, #30), **abgenommen** 21.10.; Warnhinweise warten auf D-17 |
| J3 | Einsatzplanung mit Kategorie A/B/C, geplanten Minuten, Anordnungsprüfung | High | IMPLEMENTED (#25, #32), **abgenommen** 21.10.; Kategorie-Mapping wartet auf D-15 |
| F6 | Signierter Einsatzbericht | High | IMPLEMENTED (#35), **abgenommen** 21.10. |
| J2 | Teamentscheid mit Antwortfrist, Eskalation, Qualifikationsprüfung | High | IMPLEMENTED (#24, #36), **abgenommen** 22.10. |
| F1-F4 | Verified Visit: Tagesansicht, Zustandsmaschine, Zeitkorrekturen, Beobachtung, Übergabe | High | IMPLEMENTED (#19–#22), abgenommen 21.10. (Pflegeziele via J3, Warnhinweise via J1/D-17) |
| QG1 | Qualitätsereignisse, Prüfung, Quality Hold | High | IMPLEMENTED (#41), **abgenommen** 22.10.; in Betrieb, sobald `clinical` die Ereignisliste (D-16) liefert |
| OPS1 | Operations Exception Center über J1–J3, QG1, F6 | High | IMPLEMENTED (#39), **abgenommen** 22.10. |
| C1 | Fall- und Einsatz-Lebenszyklus: pausieren, abschliessen, wiedereröffnen, absagen, Klient nicht angetroffen | High | IMPLEMENTED (#83, #120), PO: **abgenommen** 22.10. 16:15 (Auflage: instabilen e2e-Test beheben); Vor-Ort-Protokoll D-19 |
| ADM1 | Pilot-Administration: Mitglieder mit Namen, Qualifikationen, Teams, Fristen, Schwellen | High | IMPLEMENTED (#101), PO: **changes-requested** 22.10. 20:15 (entfernte Mitglieder geben ihre künftigen Einsätze ans Team zurück); Nachbesserung #135 am 22.10. 22:15 vorgeprüft, eine Datenschutz-Korrektur offen |
| PLAN2 | Selbstplanung: Einsätze folgen dem Pflegeplan (rollierende 4 Wochen, Bezugspflegeperson) | High | IMPLEMENTED (#92, #118), PO: **abgenommen** 22.10. 16:15; täglicher Job auf Staging prüfen (D-2) |
| F7 | Unterschrift beim Abschluss: Einsatz endet mit finalem Bericht | High | IMPLEMENTED (#94, #122), PO: **abgenommen** 22.10. 16:15 |
| COVER1 | Teamübergreifende Vertretung ohne Disposition | High | IMPLEMENTED (#99, #114), PO: **abgenommen** 22.10. 16:15, bis D-3 abgeschaltet; Durchführung der Übernahme nach D-3 |
| REF2 | Spitalzuweisung ohne Intake-Koordination | High | DRAFT; wartet auf D-9, D-3 |
| HAND1 | Übergabe ohne Rapport: „seit Ihrem letzten Besuch“ auf jeder Einsatzkarte | High | IMPLEMENTED (#128), PO: **abgenommen** 22.10. 18:20 (Auflage: e2e-Test in Handybreite); Voraussetzung für sichere Vertretung (COVER1) |
| RET1 | Wiederkehrende Klientin kehrt zu ihrem Team zurück (pausierter Fall wird fortgesetzt) | High | IMPLEMENTED (#129), PO: **abgenommen** 22.10. 18:20 (Auflagen: Fortsetzung ab gewünschtem Start, Test Qualifikation) |
| ABS1 | Abwesenheit ohne Telefonkette: Einsätze gehen sofort ans eigene Team, Stellvertretung bzw. Bezugspflegeperson zuerst | High | PLANNED (Brief approved), Challenge-Befund; schliesst eine Sicherheitslücke (Einsätze bleiben sonst einer abwesenden Pflegeperson zugewiesen) |
| ORD1 | Verordnungserneuerung ohne Nachtelefonieren beim Hausarzt | Medium | DRAFT; wartet auf D-22 (legal), D-9 |

- Fertig, wenn ein synthetischer Fall von Zuweisung bis signiertem Bericht E2E und RLS-negativ getestet ist, ein Qualitätsereignis einen Hold setzt und jede Ausnahme in OPS1 erscheint.

## Gate 3: Erlösnachweis

| ID | Fähigkeit | Priorität | Stand |
| --- | --- | --- | --- |
| J5 | Abrechenbare Leistungsfakten und Monatsvorschau | High | IMPLEMENTED (#43, #75), **abgenommen** 22.10.; nie mehr als gemessene Pflegeminuten; Restfinanzierung braucht D-11 |
| J6 | Kontinuität: Bezugspflegeperson und Kontinuitätsmass | High | IMPLEMENTED (#42), **abgenommen** 22.10.; Namen der Mitglieder via ADM1 |
| AN1 | Pilot-Wirkungsdashboard: Start der Versorgung, Administrationszeit, Kontinuität, abrechenbarer Anteil | High | IMPLEMENTED (#97, #124), PO: **abgenommen** 22.10. 17:15 als „Pflegeanteil im Einsatz“ (Auflage: Organisationszahl schützt ausgeblendete Kleinteams); North Star erst mit erfasster Arbeitszeit (D-23); Evidenz für D-14 |
| J7 | Team-Ökonomie-Transparenz | Medium | PLANNED (Brief draft), wartet auf D-14 |

- J5 nur aus signierten Berichten ohne offenen Quality Hold; **keine** Rechnung vor OKP-Zulassung (D-12).
- Fertig, wenn der Pilot pro Team abrechenbare Minuten, geschätzten Erlös nach Kostenträger und Kontinuität pro Klient zeigen kann.

## Gate 4: Dokumentation und Clinical Safety

- Serverbasierter KI-Entwurf aus F1–F4-Beobachtungen; menschliche Freigabe über F6; unveränderliche Version.
- Dokumentationsumfang und Einsichtsrecht der Klientinnen definieren.

## Gate 5: Matching-Qualität und Teamautonomie

- J4 Teamverfügbarkeit und Kapazitätsfenster (Engineering-Vorschlag); Standorte, Radius, Geocoding nach Datenschutzprüfung (Q7); Kontinuität als Matchingkriterium; Ablehnungsgründe aus J2 als Lernsignal.

## Gate 6: Assessment und Rule-Plattform

- interRAI-HC-Adapter nach Lizenz (D-13), angebunden an den J3-Pflegeplan.
- Handbuchmatrix, versionierte Regeln, Explainability, Impact Analysis.
- LTCF-CH/PAG/MQI nur bei beschlossenem stationärem Angebot; vorher OCR und fachliche Prüfung der vier PDF-Teile.

## Gate 7: Abrechnung, Payroll, Partner

- Elektronische Rechnung an Versicherer (mit/ohne ärztliche Anordnung ausweisen); Restfinanzierung an Gemeinden.
- Payroll aus geprüfter Arbeitszeit, strikt getrennt von Abrechnungsfakten.
- Partnerverträge Spital/Heim mit Antwortzeit- und Volumenzusagen.

## Gate 8: Pilot und Skalierung

- Geschützte Staging-Umgebung (T12, D-2), Security Review, Restore, Accessibility, mobile Tests.
- Pilot mit wenigen Teams im Pilotkanton nach Zulassung.
- KPIs: administrative Minuten pro Einsatz; abrechenbare Minuten pro bezahlter Stunde; Zuweisung bis erster Einsatz; Erstangebot-Annahmequote; Kontinuität pro Klient; Berichtfreigabe; Teamzufriedenheit; Entlöhnung pro Arbeitsstunde.
