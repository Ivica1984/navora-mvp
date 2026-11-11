# Owner-Antworten vom 2026-11-11 (begleitete Sitzung mit `eng`, ca. 23:50 CET)

**Quelle:** Owner (Ivica1984) live in der Sitzung des Engineering-Agenten, 2026-11-11 ca. 23:50–23:58 CET. Der Owner fragte, welche Informationen noch fehlen, auch für die Abrechnung, und bat um konkrete Fragen. `eng` stellte vier Auswahlfragen; die Antworten stehen unten wörtlich (gewählte Option).
**Status dieses Dokuments:** Protokoll der Owner-Antworten durch `eng`. Es ändert **keine** Founder-Entscheidung, keinen Brief, kein Paket und keine Governance-Regel (README Regel 10, 11). `FOUNDER_DECISIONS.md` gehört dem PO: er übernimmt die Antworten als neue FE-Zeilen in seinem nächsten Lauf (wie FE-045 bis FE-051 aus `PRODUCTION_READINESS_OWNER_SESSION_2026-11-07.md`).
**Labels:** IMPLEMENTED · PLANNED · OPEN · UNKNOWN (CLAUDE.md).

## Antworten

| # | Frage (wie gestellt) | Owner-Antwort (gewählte Option) | Wirkung | Status |
|---|---|---|---|---|
| 1 | STG1 (PR #1087) migriert die Datenbank aus der CI nach `navora-staging` (Zürich). FE-054 erlaubt normalerweise nur Merges im aktiven Block BD. Darf STG1 als Ausnahme ausserhalb von BD gemergt werden? | **„Ja, als Ausnahme“** | Die vom PO seit 17:39 verlangte Owner-Aufzeichnung (FE-057) liegt vor. STG1 darf ausserhalb von BD gemergt werden; alle übrigen FE-054-Bedingungen bleiben (grüne CI auf PR-Kopf und Merge-Commit, Tests für jedes geänderte Verhalten). | PLANNED (PO: FE-Zeile, dann Merge-Prüfung von #1087) |
| 2 | Seed Testorganisation S, Frage (G-b): Wer schaltet den PLAN3-Tagesvorschlag ein? Variante A: ein synthetischer Administrator über `/admin` (als eigener Akt in der Akttabelle gezählt). Oder der Seed wie heute auf `recovery/main`. | **„A: synth. Admin“** | Bestätigt die von `eng` am 11.11. ~16:50 gemeldete Antwort. Nach Brief BD Amendment 17:39: `eng` bereitet den Lücken-PR «A» vor; der Admin-Akt wird in der AUT-88-Tabelle als eigene Zeile «Organisationseinstellung durch Admin» gezählt. | PLANNED (PO: FE-Zeile; `eng`: Lücken-PR im Block BD) |
| 3 | FE-048 sagt «Pro» für `navora-staging`, das Projekt läuft aber im Supabase-Free-Tarif. Was gilt? | **„Free reicht (Phase A)“** | Löst den vom PO 18:39 gemeldeten Widerspruch FE-048 «Pro» vs. Free: Staging bleibt Free, solange nur synthetische Daten (Phase A). Vorschlag für die FE-Zeile: «Free bis Phase B». | PLANNED (PO: FE-Zeile, FE-048 im Feld *Ersetzt* teilweise) |
| 4 | Abrechnung Phase B (Tarif-Zeitregeln D-18, ärztliche Verordnung D-22, Restfinanzierung BS/BL): Was ist schon vorhanden? (Mehrfachauswahl: Tarifvertrag · Rechtsberatung · Pflegeheim-Partner · noch nichts) | **„Noch nichts davon“** | Kein Tarifvertrag, keine Rechtsberatung, kein Pflegeheim-Partner vorhanden. Phase A läuft weiter mit synthetischen Tarifen (J5, D-18 Phase-A-Teil M3). D-18, D-22, D-44 und die kantonale Restfinanzierung bleiben OPEN; Zeitplan Rechtsberatung Q1 2027 (FE-050) unverändert. Nichts wird erfunden. | OPEN |
| 5 | (Nachfrage ca. 00:05, 12.11.) FE-054 verlangt grüne CI auf jedem Merge-Commit. Der Lauf auf dem BD-2-Merge-Commit `dcf7231` ging bei GitHub verloren (queued ohne Jobs, nie ausführbar). Was gilt künftig als Nachweis, wenn GitHub einen solchen Lauf verliert? (Dauerregel · nur einmalig · strenger mit 10/10) | **„Strenger: 10/10 nötig“** | Dauerregel mit Zusatzbedingung. Geht ein Merge-Commit-Lauf ohne Jobs verloren (Infrastruktur, nicht ausführbar), dann gilt als Nachweis ein späterer Merge-Commit auf `recovery/main`, der ihn enthält. Dieser muss die volle `ci` grün haben **und** 10/10 grün in `ci-repeat` (B0-2-Regel, ein `infrastructure:`-Versuch zählt als nicht gelaufen). Der Nachweis gilt für alle Merges dazwischen. Erst danach kommt der nächste Block-Merge. Ist der spätere Lauf rot, werden alle Merges seit dem letzten grünen Merge-Commit geprüft (FE-054: Revert-PR zuerst). Kein leerer Commit, kein Abschwächen eines Tests. Für BD-2 heisst das: `c96bff9` oder `1bb09cb` (beide enthalten `dcf7231`), `ci` grün plus `ci-repeat` 10/10, dann #1093 und #1096. | PLANNED (PO: FE-Zeile zu FE-054 und Prüfung des Ergebnisses). **Ausgelöst von `eng` 12.11. 00:10**, damit es nicht doppelt geschieht: Branch `repeat/bd2-proof-1bb09cb` zeigt auf den aktuellen Kopf `1bb09cb` von `recovery/main` (enthält `dcf7231`), 10 Versuche `ci-repeat`; die `ci` auf `1bb09cb` (Lauf 43115909170) lief zu dem Zeitpunkt. Ergebnis: Kommentar auf #1100. |

## Was der Owner später liefern muss (Abrechnung, Phase B; OPEN)

Aus der Frage 4 und `OPEN_DECISIONS.md`. Hier wird keine neue Frage gestellt; die Liste hält nur fest, was vor der ersten echten Rechnung fehlt:

- Tarif- bzw. Administrativvertrag, der für die Pilotorganisation gilt (Pflegeheim, BS/BL), als Quelle für D-18 (`lca` prüft).
- Rechtsberatung für D-22 (Form der Verordnung) und D-44 (Abrechnungsweg je Auftragsart), gebündelt nach FE-050.
- Kantonale Regeln zur Restfinanzierung und Patientenbeteiligung BS/BL aus offizieller Quelle.
- Partnerheim für Phase B (D-42) mit seinen Tarifpartnern und seiner ZSR.
- D-14 Preishöhe (Richtung FE-055 (3) steht).

## Nicht gefragt (bleibt wie berichtet)

D-7 Stufe 1 erledigt, Stufen 2/4 zurückgestellt; FD-27 ausgeführt: in dieser Sitzung nicht erneut gefragt. Die PO-Bitte um Bestätigung (Journal 18:39) bleibt für diese Punkte offen.
