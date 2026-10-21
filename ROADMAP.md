# NAVORA — Roadmap and Engineering Takeover

**Stand:** 21. Oktober 2026 (ersetzt Stand 9. Oktober 2026). **Owner:** Product Owner. **Roadmap = PLANNED**, priorisiert nach Umsetzung des Geschäftsmodells: jede Phase muss eine Lücke zwischen Zuweisung und abrechenbarer, fachlich sicherer Pflege schliessen. Termine, Budget und Personen **OPEN**. Keine Phase als erledigt aus dem Vorliegen eines Dokuments oder ZIP-Pakets ableiten. Statuslegende siehe `MASTER_CONTEXT.md`.

Detaillierte Spezifikation J1–J3 und Engineering Briefs: Doc „NAVORA Product Plan J1–J3“.

## Leitlinie

Versorgungskette: Zuweisung → Fall → Matching → Teamentscheid → Einsatzplanung → Einsatz → Dokumentation → Qualität → Abrechnung.

Wertlogik (Schweizer ambulante Pflege): Erlös pro Stunde = OKP-Beitrag (KLV Art. 7a, Kategorien A/B/C) + Patientenbeteiligung + Restfinanzierung (Kanton/Gemeinde). Jede Phase wird daran gemessen, ob sie abrechenbare Minuten pro bezahlter Stunde erhöht oder Erlösverlust durch fehlende Grundlagen (Bedarfsabklärung, Anordnung, Kostenträger, Zulassung) verhindert.

## Änderungen gegenüber Stand 9. Oktober 2026

- **DECIDED:** Reihenfolge F0 → J1 → J2 → J3 → J4 freigegeben (21.10.2026).
- **DECIDED:** Assessment-Track wird von interRAI LTCF (stationär) auf interRAI HC (ambulant) neu ausgerichtet; LTCF nur bei beschlossenem stationärem Angebot. Gründer-Bestätigung **OPEN**.
- **NEU:** Geschäftsvoraussetzungen (Rechtsträger, Betriebsbewilligung, OKP-Zulassung, Pilotkanton) als Gate 0 vor jeder Abrechnung.
- **NEU:** Gate 3 „Erlösnachweis“ (J5–J7) vor KI-Dokumentation und Matching-Qualität eingeordnet.
- **NEU (Revision 2, Abgleich ARCHITECTURE.md):** Q1 Quality Signals/Hold und OPS1 Operations Exception Center in Gate 2; J4 um signierten Einsatzbericht ergänzt. Rangliste führt `docs/agents/NEXT_CAPABILITY.md`.
- **Befund Live-Datenbank 21.10.2026:** zehn öffentliche Tabellen leer; RLS aktiv ohne Policies (alles gesperrt); keine versionierten Migrationen ausser einem No-op; Leaked-Password-Schutz aus; GraphQL-Sichtbarkeit für `authenticated`.

## Gate 0: Wahrheit, Geschäftsgrundlage und Rechte

- Repo-Inventar, Git-Status, Live-Schema als versionierte Baseline. **VERIFY AGAINST REPOSITORY**.
- **Gründerentscheide (OPEN, blockierend für Abrechnung):** Pilotkanton und -gemeinden; Rechtsträger für Betriebsbewilligung und OKP-Zulassung; Leistungsauftrag der Gemeinde ja/nein (beeinflusst Restfinanzierung).
- Fachowner klinisch benennen; Lizenzklärung interRAI HC.
- Datenschutz-Folgenabschätzung, Auftragsbearbeiterverträge.
- Fertig, wenn Pilotkanton, Rechtsträger und Zulassungsweg entschieden sind und Staging-Freigabe vorliegt.

## Gate 1: F0 Shared Access Foundation — Priorität CRITICAL

- Organisationen (NAVORA, Partner, Care-Organisation), Teams, Mitgliedschaften, Qualifikationen als Daten.
- Zugriff nach Zuordnung; Partner sieht nur eigene Zuweisungen; angebotenes Team nur Minimalangebot.
- Auditierte, idempotente Commands; synthetische Testdaten.
- Fertig, wenn alle Negativtests aus J1–J4 bestehen.

## Gate 2: Care Journey MVP — J1 bis J4, Q1, OPS1

| Nr. | Fähigkeit | Priorität | Status |
| --- | --- | --- | --- |
| J1 | Zuweisung → Fall → Matching-Anfrage mit Readiness-Checkliste | Critical | DECIDED, PLANNED |
| J2 | Teamentscheid mit Antwortfrist, Begründung, Eskalation | High | DECIDED, PLANNED |
| J3 | Einsatzplanung: Bedarfsabklärung zuerst, Kategorie A/B/C, geplante Minuten, Anordnungsprüfung | High | DECIDED, PLANNED |
| J4 | Verified Visit: Zeitereignisse, Beobachtung, Übergabe, signierter Einsatzbericht | High | DECIDED, PLANNED |
| Q1 | Qualitätsereignisse aus dem Einsatz, Prüfung, Quality Hold | High | PLANNED (neu 21.10.) |
| OPS1 | Operations Exception Center über J1–J3 und Q1 | High | PLANNED (neu 21.10.) |

- Fertig, wenn ein synthetischer Fall von Zuweisung bis signiertem Einsatzbericht E2E und RLS-negativ getestet ist, ein Qualitätsereignis einen Hold auslöst und jede Ausnahme aus J1–J3 und Q1 in OPS1 erscheint.
- Begründung (ARCHITECTURE.md): freigegebener Bericht → Quality Gate → `billable_facts`; Operations als ausnahmebasierter Control Tower.

## Gate 3: Erlösnachweis — J5 bis J7

| Nr. | Fähigkeit | Priorität | Status |
| --- | --- | --- | --- |
| J5 | Abrechenbare Leistungsfakten und Monatsvorschau | High | PLANNED |
| J6 | Kontinuität: Bezugspflegeperson und Kontinuitätsmass | High | PLANNED |
| J7 | Team-Ökonomie-Transparenz | Medium | PLANNED |

- J5 erzeugt Fakten und Vorschau, **keine** Rechnungsstellung vor OKP-Zulassung; nur aus signierten Einsatzberichten ohne offenen Quality Hold.
- Fertig, wenn der Pilot für jedes Team abrechenbare Minuten, geschätzten Erlös nach Kostenträger und Kontinuität pro Klient zeigen kann.

## Gate 4: Dokumentation und Clinical Safety

- Serverbasierter KI-Entwurf aus J4-Beobachtungen; menschliche Freigabe; unveränderliche Version.
- Dokumentationsumfang und Einsichtsrecht der Klientinnen definieren.
- Fertig, wenn kein ungeprüfter Entwurf als final oder abrechenbar erscheint und Safety-Tests bestanden sind.

## Gate 5: Matching-Qualität und Teamautonomie

- Geodaten mehrerer Teamstandorte, Kapazität je Zeitfenster, Kontinuität als Matchingkriterium.
- Ranking im Dry Run evaluieren; Ablehnungsgründe aus J2 als Lernsignal.

## Gate 6: Assessment und Rule-Plattform

- interRAI-HC-Adapter nach Lizenz; Anbindung an J3-Pflegeplan.
- Handbuchmatrix, versionierte Regeln, Explainability, Impact Analysis.
- LTCF-CH/PAG/MQI nur bei beschlossenem stationärem Angebot; vorher OCR und fachliche Prüfung der vier PDF-Teile.

## Gate 7: Abrechnung, Payroll, Partner

- Elektronische Rechnung an Versicherer (mit/ohne ärztliche Anordnung ausweisen); Restfinanzierung an Gemeinden.
- Payroll aus geprüfter Arbeitszeit, strikt getrennt von Abrechnungsfakten.
- Partnerverträge Spital/Heim mit Antwortzeit- und Volumenzusagen.

## Gate 8: Pilot und Skalierung

- Staging-Durchstich, Security Review, Restore, Accessibility, mobile Tests.
- Pilot mit wenigen Teams im Pilotkanton nach Zulassung.
- KPIs: administrative Minuten pro Einsatz; abrechenbare Minuten pro bezahlter Stunde; Zuweisung bis erster Einsatz; Erstangebot-Annahmequote; Kontinuität pro Klient; Berichtfreigabe; Teamzufriedenheit; Entlöhnung pro Arbeitsstunde.

## Nächste Aufgaben des Engineering Agent

1. **VERIFY AGAINST REPOSITORY** und Live-Schema als Migrations-Baseline.
2. F0 auf Branch-Datenbank mit Negativtests.
3. Reihenfolge und aktive Fähigkeit ausschliesslich gemäss `docs/agents/NEXT_CAPABILITY.md`; Status in `docs/agents/IMPLEMENTATION_STATUS.md`; offene Fragen in `docs/agents/OPEN_DECISIONS.md`.
4. Keine Arbeit an Gate 4–7 ohne Product-Owner-Freigabe.
