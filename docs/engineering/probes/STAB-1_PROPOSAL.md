# STAB-1: eine lesbare Quelle je BK-Datenbankfunktion (Vorschlag von `eng` an `po`)

**Datum:** 2026-11-20 09:40 CET · **Status:** PROPOSED (Paketvorschlag; kein Code auf einem Feature-Zweig, kein PR mit Verhalten) · **Anlass:** Founder-Brief 2026-11-20 (Live-Sitzung, Punkt 1; wörtlich im Issue für `po`) und Selbstbewertung `docs/engineering/SELF_ASSESSMENT_2026-11-20.md` · **Entscheidet:** `po` (WAS, WANN, Abnahme); `eng` (WIE).

## 1. Befund (IMPLEMENTED, aus dem Code von `recovery/main` `269e4b5` gezählt)

- **60 Funktionen** wurden mindestens einmal per Textersetzung geändert (`private.*_patch(...)` auf `pg_get_functiondef`). Dazu kommen 16 Funktionen, die 0074 in einer Schleife mit dem LEAVE1-3-Schutz versehen hat.
- Die gültige Definition einer solchen Funktion steht **in keiner Datei**. Sie entsteht erst in der Datenbank, aus einer `create`-Migration plus allen späteren Patches. Beispiel `private.derived_exceptions`: 2 `create` und 19 Patches zwischen 0035 und 0144.
- **Heute belegt:** In BK-f habe ich `generate_billable_facts` aus 0051 kopiert. Dabei ging der LEAVE1-3-Schutz aus 0074 verloren. pgTAP 074 hat es gefangen (Job 136125670120); die Korrektur 0154 patcht jetzt die Live-Definition. Der Katalog-Test schützt **nur** LEAVE1-3. Andere Regeln (Sperren, Prüfspur, Take-Schutz) haben keinen solchen Fänger.

## 2. Umfang: nur die Funktionen der BK-Kette (erste Welle)

BK-d ist die KI-Erfassung des Auftrags (BK-1a/b), BK-g die Szenario-Matrix (u. a. Uhrumstellung), BK-f der laufende Rechnungsentwurf. Diese Teilstücke berühren:

| Gruppe | Funktionen | Wo der Text heute entsteht | Gebraucht von |
|---|---|---|---|
| Auftrag und Prüfung | `private.client_order_check`, `public.confirm_client_order`, `public.preview_client_order`, `private.screen_order_reach` | je 3 `create` (0129–0135) | BK-d, BK-g |
| Übernahme | `public.take_order`, `private.order_member_step`, `private.recheck_member_takes`, `private.recheck_takes_trigger` | 0132–0148; `order_member_step` 3 `create` + 2 Patches | BK-d, BK-g |
| Einsatz aus der Übernahme | `private.order_take_visit`, `private.end_take_visit`, `public.field_visits` | `field_visits` 9 `create` (0006–0149) | BK-g |
| Schutz des Übernahme-Einsatzes (CGR-249) | `public.reschedule_visit`, `public.move_visit_to_today`, `public.remove_planned_visit`, `public.propose_visit_responsible`, `public.take_open_visit` | 2–5 Patches je, zuletzt 0145 | BK-g |
| Abwesenheit → Übernahme (CGR-250) | `public.record_absence`, `public.change_absence` | 3 `create` + 2 Patches | BK-g |
| Hinweise und Operations | `private.derived_exceptions`, `public.operations_exceptions`, `private.signal_recipients`, `public.take_signal` | 19, 10, 2, 2 Patches | BK-g |
| Bericht und Abrechnung | `public.sign_report`, `public.correct_report`, `private.build_billable_fact`, `public.generate_billable_facts` | 0016–0154, 0074-Schleife | BK-f, BK-g |

Das sind **25 Funktionen**. Alle übrigen der 60 (Fallplanung, Pilot-KPIs und Ähnliches) bleiben in dieser Welle unberührt (Rest-Welle PLANNED, nur bei Bedarf).

## 3. Welche Regeln still verloren gehen können

Je Funktion hält das Manifest (§4) die Pflichtmerkmale fest. Mindestens:

- LEAVE1-3 (`assert_access_open` oder `access_ended`)
- `begin_command`/`end_command` mit Idempotenzschlüssel; Prüfspur über `navora.command`
- die Personensperre `order_take_member:` (CGR-233)
- der Take-Schutz CGR-249/CGR-252 (0145)
- BKF-F1 (0154)
- `SECURITY DEFINER` mit `search_path = ''`
- die Rechte (`revoke … from public, anon`, `grant execute … to authenticated` bzw. keiner App-Rolle)

## 4. Bauweise (WIE, `eng`)

1. **Lesbare Quelle:** `supabase/schema/functions/<schema>.<name>.sql` enthält je eine Datei mit dem vollständigen aktuellen `create or replace function …` aus `pg_get_functiondef`, dazu Kommentar und Rechte. Erzeugt wird sie von `scripts/fn-dump.mjs` nach `supabase db reset` in CI, nicht von Hand.
2. **Manifest:** `supabase/schema/functions/MANIFEST.json` listet die 25 Funktionen, je mit Pflichtmerkmalen (§3) und dem erwarteten Rechte-Satz.
3. **Herstellung per neuer Migration, ohne alte umzuschreiben:** Migration `…_stab1_function_sources.sql` führt jede der 25 Dateien unverändert aus. Das Ergebnis ist textgleich mit dem heutigen Stand, also kein Verhaltenswechsel. Ab dann ist die letzte Migration einer Funktion ihr vollständiger Text.
4. **Neue Regel:** Wer eine Manifest-Funktion ändert, ändert ihre Quelldatei. `scripts/fn-migrate.mjs <name>` schreibt daraus die Migration mit dem ganzen Text. Neue `*_patch`-Hilfsfunktionen lehnt `scripts/migration-order.mjs` ab (CI-Schritt rot).
5. **Drift-Prüfung in CI (Job `db`, wie T14 bei den Typen):** Nach den Migrationen wird der Text aller Manifest-Funktionen ausgegeben und mit `supabase/schema/functions/` verglichen. Jede Abweichung ist rot.

## 5. Tests, die «kein Verhaltenswechsel» beweisen

- **Fingerabdruck vorher = nachher:** pgTAP `157_stab1_function_fingerprint`. Für jede Manifest-Funktion stimmen `md5(prosrc)`, `prosecdef`, `proconfig`, `proacl` und die Signatur vor und nach der Migration überein. Rot zuerst: Ein absichtlich geänderter Fingerabdruck auf dem ersten Commit zeigt, dass der Test greift.
- **Pflichtmerkmale:** pgTAP prüft je Funktion die Merkmale aus dem Manifest. So fängt ein Test künftig auch andere verlorene Regeln, nicht nur LEAVE1.
- **Rechte-Matrix:** `has_function_privilege` für `anon` und `authenticated` je Funktion, unverändert.
- **Volle Suite:** alle pgTAP-Dateien, `e2e`, `ui-screenshots`; `ci-repeat` 10/10 (`db`, `e2e`) auf dem integrierten Commit; `staging-smoke` grün nach dem Merge. Die drei bestehenden Pfade dürfen nicht brechen.

## 6. Rückweg

Die Migration erzeugt textgleiche Definitionen. Schlägt sie fehl, rollt sie in ihrer Transaktion zurück (`supabase db push` je Datei). Nach dem Merge ist der Rückweg das Entfernen von Drift-Schritt und Quelldateien. Die Datenbank bleibt unverändert richtig, weil keine Funktion anders ist als vorher. Keine Daten, keine Tabellen, keine Rechte ändern sich.

## 7. Aufwand und Platz in der Reihenfolge

- **Schätzung (ESTIMATE):** 2–3 stündliche Läufe inklusive CI-Runden. Keine Fach-Gates nötig, weil sich kein Verhalten ändert. Der PO entscheidet, ob `cra` die Merkmalsliste lesen soll.
- **Vorschlag:** direkt nach dem Ready-Bericht von BK-f und vor dem nächsten Paket, das eine der 25 Funktionen ändert. Das ist voraussichtlich die KI-Funktion im Bericht (Punkt 8) oder BK-d.

## 8. Reihenfolge bis zum nächsten vollständigen Staging-Ablauf (Sicht `eng`; der PO entscheidet)

1. **BK-f fertig bauen** (aktiv, #1581) und einen neuen Smoke-Pfad hinzufügen: Pflegekraft unterschreibt → Rechnungsentwurf → Team sendet → Kunde sieht «Rechnungen».
2. **STAB-1** (§4–§7).
3. **Erste echte KI-Funktion: Berichtsentwurf mit Claude.** Technisch am nächsten, weil der Weg seit BK-e2 gebaut ist:
   - Prüfungen in `resolveReportDraftProvider`: Ausschalter, nur Staging, nur Simulationsorganisation, Host-Prüfung
   - Prüfspur-Ledger (0151) und Stoppregel (0153)
   - Unterschrift durch die Pflegekraft
   - Anbieter ist entschieden (FE-094: Anthropic-API, nur Staging, nur synthetische Daten)

   Offen: `lca`-Lesung der Anbieterbedingungen (FE-094 (c)), die Umgebungswerte auf Render durch den Founder, und ein Smoke-Pfad «Notiz → Entwurf von Claude → geprüft → unterschrieben» mit gemessener Latenz und Kosten.
4. **BK-d** (KI-Erfassung des Auftrags) als zweite Modellfunktion, dann **BK-g**.

## 9. Was `eng` für die erste KI-Funktion technisch bewertet (Founder Punkt 4, Teil `eng`)

- **Was die KI tut:** Aus den Stichworten der Pflegekraft am Ende des Einsatzes schreibt Claude einen Berichtsentwurf. Die Pflegekraft prüft jede Zeile, ändert oder streicht sie und unterschreibt. Erst die Unterschrift macht den Bericht verbindlich.
- **Heute (IMPLEMENTED):**
  - Entwurf regelbasiert (Testersatz «regelbasiert, keine KI»)
  - Claude-Provider gebaut und nur mit Attrappe getestet
  - Matching, Übernahme und Stoppregel sind feste Regeln
- **Geprüfte Ein- und Ausgaben:**
  - Eingabe: nur Notiztext und Einsatzzeiten des synthetischen Einsatzes, nie Namen aus einer realen Quelle.
  - Ausgabe: Zeilen mit Quellbezug (Vertrag BK-e2; in diesem Lauf nicht erneut im Code nachgelesen).
  - Prüfung: Zeilen ohne Quelle verwirft die Validierung (fail closed). Die Pflegekraft entscheidet je Zeile; das Ledger hält Vorschlag und Entscheid fest.
- **Grenzen:**
  - Stoppregel 50 % verworfene Zeilen bei mindestens 10 Entscheiden in 30 Tagen (`cra`-Simulationswert, 0153)
  - Ausschalter `AI_KILL_SWITCH`
  - Kostengrenze je Tag: noch nicht gebaut (OPEN). Vorschlag: ein Tageszähler mit fester Obergrenze; den Wert setzt der Founder.
- **Was Claude nie darf:** Eine fehlende Qualifikation ausgleichen oder Zeiten, Pflege- oder Abrechnungstatsachen erfinden. Die Zeiten kommen aus F1–F4, nicht aus dem Modell.
