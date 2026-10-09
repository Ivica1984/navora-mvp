# NAVORA — Testing and Quality

**Befund:** Spätere Screenshots zeigten erfolgreichen `npm run lint` und `npm run build` nach Korrekturen, Next.js 16.3.4 und `npm audit --omit=dev` = 0 zum damaligen Zeitpunkt. Das bestätigt keine klinische, rechtliche oder Zugriffssicherheit. Testframework/Tests im aktuellen Repo: **VERIFY AGAINST REPOSITORY**. Vitest/Playwright/CI existieren in Entwurfspaketen, nicht nachgewiesen im Produktcode.

## Testpyramide [PLANNED]

1. **Domain unit:** Statusmaschine, Zeitsegmente, Kapazität, Matching-Hard-Filter, Tarife, Freigabe-/Hold- und Rule-Engine-Invarianten.
2. **DB integration:** RLS pro Rolle/Organisation/Team/Fall, FK, Constraints, Transaktionen, Idempotenz, Deduplikation, Migrations-/Rollback-/Backfillfälle.
3. **API/Workflow:** Partneranfrage→Fall; Teamentscheid; Start/Pause/Ende; Berichtfreigabe; Qualitätsereignis; Billing-Gate; Fehler-/Retrypfade.
4. **E2E/mobile:** Pflegekraft sieht nur eigenen Einsatz, offline erfassen/sync, Konflikt, sichere Abmeldung; Teamplanung; Operations-Risiko; Architect-Review.
5. **Fachliche Referenztests:** versionierte autorisierte LTCF/PAG/MQI-Beispielfälle, positive/negative/Grenz-/Widerspruchsfälle, klinische Freigabe.
6. **Performance/Recovery:** aggregierte Operations Queries bei wachsender Teamzahl, Matching-Durchsatz, Job-Retries, Backup/Restore, Incident-Übungen.

## Security ist ein hartes Gate

- Negative Tests: `anon`, fremde Organisation, fremdes Team, ehemals zugeordnete Pflegekraft, technischer Admin ohne Patientenfreigabe, direkte API-/RPC-Umgehung, Service-Key-Leak und Storage-URLs.
- Der alte Screenshot mit `{public}`-SELECT/UPDATE/INSERT auf Pflege-Tabellen ist kritisch: RLS-Zieltests vor echtem Pilot obligatorisch.
- Kein Gesundheitsdateninhalt in Logs, Trace, Crashbericht oder KI-/Geocoding-Payload ohne geprüfte Berechtigung.
- GDPR/DSG/Schweizer Fachrechtsanwendung und Datenresidenz durch Fachpersonen prüfen; Code-Tests ersetzen keine Datenschutz-Folgenabschätzung.

## Fach-Traceability [PLANNED]

Für jede notwendige Regel `source_document/version/page/section → rule_id/version → inputs/dependencies/exceptions → UI/Command → result/explanation → test(s) → approver`. OCR-Konfidenz und fachliche Sichtprüfung erforderlich; keine Regel aus unvalidiertem Scan produktiv. Ziel 100 % notwendige Regeln mit Quelle und Test, 0 bekannte kritische Regressionen; **kein bisher erreichter Wert**.

## KI/Clinical Safety [PLANNED]

Eval-Datensatz ohne reale unautorisierte Daten; Faktentreue, Quellenbindung, fehlende Angaben, Halluzinationen, widersprüchliche Eingaben, menschliche Reviewrate, Sturz-/Dekubitus-Hinweise, False Positives/Negatives, Subgruppenanalyse. Risikohinweis ist keine Diagnose. KI-Vorschlag darf harte Regel nicht überschreiben. Prompt-/Modellversion und Ergebnis reproduzierbar protokollieren, soweit zulässig.

## Matching und Finance [PLANNED]

Kontra-Beispiele: ungeeignet trotz Region; kein nachgewiesener Skill; Null-Kapazität; offener Safety Hold; fehlende Geodaten; gleichzeitige Teamannahmen; mehrfach akzeptierte Fälle und Überlastung. Keine monetäre Entscheidung auf Basis ungenehmigter KI-/PAG-Werte. Billing nur nach Zeit, Leistung, Dokumentation, Verordnung/Tarif und Quality Gate; Lohnzeit unabhängig testen.

## CI-Definition [PLANNED; VERIFY AGAINST REPOSITORY]

Install mit Lockfile → Lint → Typecheck → Unit → Integration/RLS → Build → Security/Supply Chain → Stagingmigration → E2E → manuelle Fachfreigabe für klinische/finanzielle Releases. Nicht nur Build-Grün als Go-Live-Kriterium.
