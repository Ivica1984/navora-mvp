# OPEN_DECISIONS

**Owner:** gemeinsam. Product Owner und Engineering tragen Fragen ein; die genannte Entscheidungsinstanz entscheidet. **Stand:** 2026-10-21.

## Protokoll

- Jede Frage, die Umfang, Priorität, Fachregel, Recht oder Architektur betrifft und nicht im Brief beantwortet ist, kommt hierher. Nicht im Code raten.
- ID-Präfix nach Entscheidungsinstanz: `OD-F` Gründer · `OD-C` klinische Fachverantwortung · `OD-O` Operations · `OD-P` Product Owner · `OD-E` Engineering.
- Jeder Eintrag nennt: Frage, Optionen, Empfehlung, Entscheidungsinstanz, was er blockiert.
- Engineering arbeitet bei „blockiert“ an der nächsten nicht blockierten Aufgabe der aktiven Fähigkeit weiter.
- Nach dem Entscheid: Eintrag mit Datum, Entscheid und Begründung nach „Entschieden“ verschieben. Gelöschte Einträge gibt es nicht.

## Offen

| ID | Frage | Optionen | Empfehlung Product Owner | Entscheidet | Blockiert |
| --- | --- | --- | --- | --- | --- |
| OD-F1 | Pilotkanton und Pilotgemeinden? | Basel-Stadt · anderer Kanton | Ein Kanton, wenige Gemeinden; bestimmt Restfinanzierung, Bewilligung, Qualitätsvorgaben | Gründer | J1 Payer-Regeln, J5, gesamte Abrechnung |
| OD-F2 | Rechtsträger für Betriebsbewilligung und OKP-Zulassung? | Plattform-AG + Care-Organisation/Genossenschaft · eine Gesellschaft | Entscheiden vor Pilot; ohne Zulassung kein abrechenbarer Einsatz | Gründer | Abrechnung, Pilot |
| OD-F3 | Assessment-Track: interRAI HC (ambulant) statt LTCF (stationär)? | interRAI HC · LTCF beibehalten · beides | interRAI HC; LTCF nur bei beschlossenem stationärem Angebot | Gründer | Gate 6, Lizenzklärung |
| OD-F4 | Plattformgebühr und Modell Teamüberschuss? | prozentual · pro Stunde · fix | Offen; zuerst J5-Daten aus Pilot | Gründer | J7 |
| OD-F5 | Leistungsauftrag einer Gemeinde anstreben? | ja · nein | Prüfen mit OD-F1; beeinflusst Restfinanzierung und ggf. Versorgungspflicht | Gründer | J5-Erlösmodell |
| OD-C1 | Klinische Fachverantwortung benennen; Readiness-Checkliste J1 freigeben | — | Person benennen vor J1-Abnahme | Gründer / Fachverantwortung | J1 |
| OD-C2 | Pflegeplanfelder J3 freigeben (Leistung, Kategorie A/B/C, Minuten, Frequenz, Review-Datum) | — | Wie im Brief J3 | Fachverantwortung | J3 |
| OD-C3 | Zuordnung Leistungen → KLV-Kategorie A/B/C bestätigen | — | Freigabe vor J5 | Fachverantwortung | J5 |
| OD-C4 | Qualitätsereignistypen, Schweregrade, welche einen Quality Hold auslösen, wer Holds aufheben darf | — | Kurze Liste (Sturz, Wunde, Medikation, akute Verschlechterung, Sozialsituation); schwere Ereignisse → Coach + Qualitätsfachperson | Fachverantwortung | Q1, J5 |
| OD-O1 | Antwortfristen Teamangebot je Zuweisungsart (Spitalaustritt, Heim, privat) | — | Spitalaustritt kürzeste Frist | Operations | J2 |
| OD-O2 | Standard-Entscheidungsregel Team | ein Mitglied · zwei Mitglieder | Ein Mitglied entscheidet, Team wird informiert | Operations | J2 |
| OD-O3 | Liste Ablehnungsgründe | Kapazität, Qualifikation, Distanz, Sonstiges | Diese vier für v1 | Operations | J2 |
| OD-O4 | Schwellen und Dringlichkeit der Ausnahmen in OPS1 | — | Spitalaustritt höchste Dringlichkeit; Schwellen konfigurierbar, nicht im Code | Operations | OPS1 |
| OD-E1 | Command-Stil serverseitig | Server Action · Supabase RPC · Route Handler | Engineering entscheidet; Kriterien: atomar, auditierbar, idempotent, testbar | Engineering | F0 |
| OD-E2 | Hosting und Umgebungen (Staging/Produktion) | Render · andere | Engineering schlägt vor; Render nicht als bestehend annehmen | Engineering, Freigabe Gründer | Gate 8 |

## Entschieden

| ID | Datum | Entscheid | Begründung |
| --- | --- | --- | --- |
| D-001 | 2026-10-21 | Reihenfolge F0 → J1 → J2 → J3 → J4, danach J5 → J6 → J7 | Versorgungskette bis zur abrechenbaren Leistung schliessen |
| D-002 | 2026-10-21 | Zugriffsmodell einmal für J1–J4 entwerfen | Vermeidet Nacharbeit pro Bildschirm |
| D-003 | 2026-10-21 | Verified Visit v1 nur online mit sicheren Wiederholungen; Offline-Queue in v1.1 | Offline-Sync von Gesundheitsdaten braucht eigene Sicherheitsprüfung |
| D-004 | 2026-10-21 | Minimaler Fallkontext auf dem Handy: Name, Adresse, Pflegeziele, Warnhinweise, letzte Übergabe | Datenminimierung |
| D-005 | 2026-10-21 | Übergabe für das ganze zugewiesene Team sichtbar | Selbstorganisation |
| D-006 | 2026-10-21 | Nur synthetische Daten bis Abnahmegate 1 aus `PRODUCT_REQUIREMENTS.md` | Sicherheit und Datenschutz |
| D-007 | 2026-10-21 | J5 erzeugt Fakten und Vorschau, keine Rechnung vor OKP-Zulassung | Zulassung offen (OD-F2) |
| D-008 | 2026-10-21 | Jede Product-Owner-Empfehlung endet mit Engineering Brief | Einheitliche Übergabe |
| D-009 | 2026-10-21 | Rangliste Revision 2: J4 mit signiertem Bericht; Q1 und OPS1 vor J5 | ARCHITECTURE.md: Quality Gate vor `billable_facts`; Operations ausnahmebasiert |
| D-010 | 2026-10-21 | Product Owner ist alleiniger Schreiber von `NEXT_CAPABILITY.md`; Engineering von `IMPLEMENTATION_STATUS.md` | Koordinationsmodell freigegeben |
