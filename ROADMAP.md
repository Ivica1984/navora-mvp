# NAVORA — Product Roadmap

**Stand:** 21. Oktober 2026 (ersetzt die Übergabe-Roadmap vom 9. Oktober 2026). **Owner:** Product Owner (`po`). **Roadmap = PLANNED**, priorisiert nach Umsetzung des Geschäftsmodells: jede Phase schliesst eine Lücke zwischen Zuweisung und abrechenbarer, fachlich sicherer Pflege. Termine, Budget und Personen **OPEN**. Statuslegende: `MASTER_CONTEXT.md`.

**Verbindliche Reihenfolge und Briefs:** `docs/agents/NEXT_CAPABILITY.md` und `docs/agents/briefs/`. **Umsetzungsstand:** `docs/agents/IMPLEMENTATION_STATUS.md` (Engineering). **Offene Entscheide:** `docs/agents/OPEN_DECISIONS.md`. Technische Roadmap: `docs/engineering/ROADMAP.md`. Bei Widerspruch gilt `docs/agents/`.

## Leitlinie

Versorgungskette (`ARCHITECTURE.md`): Zuweisung → Fall → Matching → Teamentscheid → Einsatzplanung → Einsatz → freigegebener Bericht → Quality Gate → Abrechnungsfakten.

Wertlogik (ambulante Pflege Schweiz): Erlös pro Stunde = OKP-Beitrag nach KLV Art. 7a (Kategorien A/B/C) + Patientenbeteiligung + Restfinanzierung (Kanton/Gemeinde). Jede Phase wird daran gemessen, ob sie abrechenbare Minuten pro bezahlter Stunde erhöht oder Erlösverlust durch fehlende Grundlagen verhindert: Bedarfsabklärung, ärztliche Anordnung (für B), Kostenträger, Zulassung.

## Änderungen gegenüber 9. Oktober 2026

- **DECIDED (Owner, PRIO-1):** Reihenfolge F0, J1, J2, J3.
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

- Brief `docs/agents/briefs/F0.md`. T8–T10 geliefert (#7–#9). PO-Prüfung 21.10.2026: **Änderungen verlangt**. Es fehlen Qualifikation je Mitglied als Daten (D-5 entschieden: Verwaltung durch NAVORA-Administratoren; Pilotmodell `registered_nurse`, `care_assistant`; Lieferung mit J3) und teambezogenes Lesen klinischer Daten innerhalb einer Organisation (wartet auf Owner-Entscheid D-3). Partner-Selbsterfassung bis Gate 7 ausser Scope.
- Fertig, wenn alle Negativtests aus F0 bestehen und die Qualifikationen als Daten vorliegen.

## Gate 2: Care Journey MVP

| ID | Fähigkeit | Priorität | Stand |
| --- | --- | --- | --- |
| J1 | Zuweisung → Fall → Matching-Anfrage mit Readiness-Prüfung und Kostenträgerkette | Critical | IMPLEMENTED (#23), Änderungen verlangt |
| J3 | Einsatzplanung mit Kategorie A/B/C, geplanten Minuten, Anordnungsprüfung | High | IMPLEMENTED (#25), Änderungen verlangt |
| F6 | Signierter Einsatzbericht | High | PLANNED |
| J2 | Teamentscheid mit Antwortfrist, Eskalation, Qualifikationsprüfung | High | IMPLEMENTED (#24), Änderungen verlangt |
| F1-F4 | Verified Visit: Tagesansicht, Zustandsmaschine, Zeitkorrekturen, Beobachtung, Übergabe | High | IMPLEMENTED (#19–#22), abgenommen 21.10. (Pflegeziele via J3, Warnhinweise via J1/D-17) |
| QG1 | Qualitätsereignisse, Prüfung, Quality Hold | High | PLANNED (Brief draft) |
| OPS1 | Operations Exception Center über J1–J3, QG1, F6 | High | PLANNED (Brief draft) |

- Fertig, wenn ein synthetischer Fall von Zuweisung bis signiertem Bericht E2E und RLS-negativ getestet ist, ein Qualitätsereignis einen Hold setzt und jede Ausnahme in OPS1 erscheint.

## Gate 3: Erlösnachweis

| ID | Fähigkeit | Priorität | Stand |
| --- | --- | --- | --- |
| J5 | Abrechenbare Leistungsfakten und Monatsvorschau | High | PLANNED (Brief draft) |
| J6 | Kontinuität: Bezugspflegeperson und Kontinuitätsmass | High | PLANNED (Brief draft) |
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
