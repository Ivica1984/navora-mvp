# Bestandsaufnahme PRs und Issues, Stand 2026-11-07 18:50 (Europe/Zurich)

**Besitzer:** `po` · **Grundlage:** FE-052 · **Quelle:** GitHub REST API (PRs, Check-Runs, Kommentare, Issues), gelesen 2026-11-07 ~18:45-19:30; `git` für den Gate-Abgleich. **Der PO hat keine Tests ausgeführt.** Die Klassifizierung ist **automatisch** aus Dateipfaden, Titeln und Kommentaren erzeugt und in Stichproben geprüft (Abschnitt *Methode*); sie ist ein Arbeitsstand, kein Abnahmebeleg.

## Methode und Begriffe

- **Änderungsart** aus den Dateipfaden: *Code* (`src/`), *DB* (`supabase/migrations`), *Tests* (`supabase/tests`, `tests/`, `*.test.*`, `*.spec.*`), *CI/Werkzeug* (`.github/`, `scripts/`, Paket- und Testkonfiguration), *Governance* (`docs/agents`, Founder-Entscheide, Blueprint), *Doku* (alles andere).
- **Block:** führender Produktblock aus dem Brief-Kürzel in Titel, Branch oder Beschreibung (Zuordnung in `PRODUCT_BLOCKS.md` §2). Reine Doku-/Governance-PRs: `G`.
- **CI Head:** Jobs `app`, `db`, `e2e`, `ui-screenshots` auf dem Head-Commit des PRs (vor dem Merge).
- **CI integriert:** dieselben Jobs auf dem **Merge-Commit** in `recovery/main` (Push-Lauf und Lauf für PR #3). *grün* = jeder Job mindestens einmal erfolgreich und keiner rot; *abgebrochen* = durch den nächsten Merge abgebrochen (Concurrency), auf diesem Commit **nicht nachgewiesen**; *kein Lauf* = Merge-Commit wurde nie getestet (z. B. Stapel-PRs vor der Sammel-PR #934).
- **cra-Gate:** eine Zeile `cra-gate: #<n> <sha> clear` in den PR-Kommentaren. Liegt sie auf einem früheren Head, wurde verglichen, ob die eigenen Code-, DB- und Testdateien des PRs (`git diff M^1 M`) zwischen Gate-Commit und gemergtem Head blob-gleich sind. *Nicht im PR nachgewiesen* heisst: kein Gate im PR (die Gate-Zeile gibt es erst seit 2026-11-06 13:00; frühere `cra`-Prüfungen stehen in `docs/agents/reports/CLINICAL_GOVERNANCE.md` ohne Zuordnung zum gemergten Commit); eine `cra`-Prüfung kann im `cra`-Bericht stehen, ist aber hier nicht dem gemergten Stand zugeordnet. **Eine `cra`-Prüfung ist eine beratende Vorbereitung, keine qualifizierte klinische Freigabe (D-27; kein Clinical Owner ernannt, G-1).**
- **Fehlender Beleg = „nicht nachgewiesen“.** Ein grünes CI belegt nur die Tests dieses Commits, keine Blockabnahme.

## 1. Zusammenfassung

- Gemergte PRs in `recovery/main` seit 2026-10-21: **701**. Davon mit Produktcode, Datenbank, Tests oder CI: **167**; reine Doku/Governance: **534**.
- Produkt-/Test-/CI-PRs, CI auf dem integrierten Merge-Commit: grün 131, abgebrochen 21, kein Lauf 8, rot 7. **36 von 167 haben auf ihrem eigenen integrierten Stand keinen grünen Nachweis** (spätere Commits von `recovery/main` enthalten sie und sind grün; das belegt den Gesamtstand, nicht den einzelnen Merge).
- Produktcode-/DB-PRs (149): cra-Gate auf dem gemergten Head 6; auf früherem Head 17 (davon 8 mit abweichenden eigenen Code-Dateien); nicht im PR nachgewiesen 126.
- **Kein Block ist nach FE-052 abgenommen.** Frühere PO-Vermerke „accepted“ bedeuten: PO-Prüfung gegen die Brief-Kriterien mit CI auf dem PR; sie sind keine Blockabnahme.

### Je Block (nur Produkt-, Test- und CI-PRs)

| Block | PRs | CI integriert grün | ohne grünen integrierten Nachweis | cra-Gate auf gemergtem Stand nachgewiesen |
|---|---|---|---|---|
| B0 Technische Basis und Datenbank-Sicherheit | 43 | 35 | 8 | 0 von 31 Code-/DB-PRs |
| B1 Anfrage, Fall und Teamentscheid | 8 | 5 | 3 | 0 von 8 Code-/DB-PRs |
| B2 Qualifikation, Tätigkeitsregeln, Nachweise, Delegation | 11 | 8 | 3 | 4 von 11 Code-/DB-PRs |
| B3 Team- und KI-Einsatzplanung, Ausfallkoordination | 41 | 31 | 10 | 7 von 41 Code-/DB-PRs |
| B4 Mobile Besuchsausführung, Zeit- und Leistungserfassung | 38 | 34 | 4 | 3 von 34 Code-/DB-PRs |
| B5 Sicherheitssignale und Eskalation | 8 | 6 | 2 | 0 von 7 Code-/DB-PRs |
| B6 Diktat, KI-Dokumentation, menschliche Freigabe | 5 | 3 | 2 | 0 von 5 Code-/DB-PRs |
| B7 Assessment, Pflegeplanung, ärztliche Anordnung | 5 | 3 | 2 | 1 von 5 Code-/DB-PRs |
| B8 Abrechnung, Validierung, Fehlerfälle | 3 | 3 | 0 | 0 von 2 Code-/DB-PRs |
| B10 Kennzahlen und Wirkungsmessung | 5 | 3 | 2 | 0 von 5 Code-/DB-PRs |


### Gate-Abgleich: eigene Code-Dateien zwischen Gate-Commit und gemergtem Head abweichend

| PR | Gate auf | gemergter Head | abweichende Datei(en) | Einordnung |
|---|---|---|---|---|
| #813 | 8e4ab0b | 2cc0db3 | `admin/admin-client.tsx` (5/5 Zeilen) | Konfliktauflösung mit UX2; für gemergten Stand nicht nachgewiesen |
| #806 | 91e7bc9 | 6cca2a0 | `team/team-client.tsx` (34/27) | dto. |
| #809 | 7f74e71 | 823a25f | `admin/admin-client.tsx` (3/3) | dto. |
| #814 | 3fe219b | c31c5f9 | `operations/assistenten/page.tsx`, `ai/labels.ts`, `tests/e2e/aig1.spec.ts` | dto. |
| #841 (AN3) | 09cdc85 | 802987f | `lib/supabase/database.types.ts` (1 Zeile, generiert) | inhaltlich unkritisch, formal nicht nachgewiesen |
| #876 | b5ddc86 | d28017a | `ai/labels.ts` (+57), `database.types.ts` | direkt gemergt (vor #934); für gemergten Stand nicht nachgewiesen |
| #880 | 12f0b0d | 59e1bc2 | 5 Dateien | durch #934 abgedeckt |
| #885 | f37180d | 619d7b9 | 4 Dateien | durch #934 abgedeckt |

## 2. Gemergte PRs mit Produktcode, Datenbank, Tests oder CI (je PR)

### B0 Technische Basis und Datenbank-Sicherheit

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #1 | 2026-10-21 10:23 | CI | CI/Werkzeug, Code, DB, Doku, Tests | grün (nur Teil der Jobs) | grün (nur Teil der Jobs) | nicht im PR nachgewiesen | M1: buildable recovery — CI, Next 16.4.1, local Supabase, green build (T3–T7) |
| #7 | 2026-10-21 11:28 | infra | CI/Werkzeug, Code, Doku, Tests | grün | grün | nicht im PR nachgewiesen | T8: SSR authentication, protected routes, server-side writes |
| #8 | 2026-10-21 11:47 | infra | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | T9: tenancy and row-level security — legacy public policies removed |
| #9 | 2026-10-21 12:12 | infra | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | T10: audited idempotent commands, DB state machine, billable locked, data minimisation |
| #10 | 2026-10-21 12:25 | infra | Code, Doku, Tests | grün | grün | nicht im PR nachgewiesen | T11: nonce-based CSP and security headers |
| #11 | 2026-10-21 12:44 | infra | CI/Werkzeug, Code, Doku, Tests | grün | grün | nicht im PR nachgewiesen | T14: generated database types with drift check |
| #12 | 2026-10-21 12:56 | CI | CI/Werkzeug, Code, Doku, Tests | grün | grün | nicht im PR nachgewiesen | Robustness: inline command errors, all regions on Teams, memoised auth check, bots off rec |
| #15 | 2026-10-21 14:43 | infra | Tests | grün | abgebrochen (nicht nachgewiesen) | – | test(db): T13 seed coverage for every attention branch |
| #17 | 2026-10-21 14:55 | infra | Code, Doku, Tests | grün | grün | nicht im PR nachgewiesen | feat(logging): TD-17 structured logging without personal/health data |
| #18 | 2026-10-21 15:30 | infra | Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | TD-19: live schema verified, drift report, ADR-022 |
| #26 | 2026-10-21 16:37 | infra | CI/Werkzeug, Doku, Governance, Tests | grün | grün | – | feat(agents): official PO/engineering collaboration layer (docs/agents) |
| #29 | 2026-10-21 17:04 | infra | Tests | grün | grün | – | test(agents): queue fixture independent of PO ranking |
| #34 | 2026-10-21 20:25 | F0 | DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | feat(F0): team-scoped clinical read on legacy care tables (closes SR-22) |
| #38 | 2026-10-21 21:12 | F0 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | F0 remainder: mandatory reasons (PO rule) and qualification administration (D-5) |
| #46 | 2026-10-22 10:17 | infra | CI/Werkzeug, Doku, Governance, Tests | grün | grün | – | COORD-4: autonomous PO ↔ Engineering coordination through GitHub (watcher, hand-off issues |
| #82 | 2026-10-22 10:50 | infra | CI/Werkzeug, Governance, Tests | grün | grün | – | fix(agents): watcher keeps claim labels across syncs |
| #237 | 2026-10-23 21:22 | infra | CI/Werkzeug, Governance | grün | grün | – | fix(deps): zod >= 4.6.6 (GHSA-mrhx-c7xc-m3w5), recovery/main audit red |
| #271 | 2026-10-24 07:22 | COORD5 | CI/Werkzeug, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | – | COORD5: decision issues reach a person only with a package (ADR-073) |
| #331 | 2026-10-25 06:11 | RLS2 | DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | RLS2: team-scoped visit and case records, read-path inventory (0066, ADR-080) |
| #373 | 2026-10-25 14:16 | RLS3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | RLS3: coordination roles and teammates read no more than their task needs (0070, ADR-083) |
| #383 | 2026-10-25 15:40 | RLS3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | FUP1: follow-ups of SIGC and RLS3 (0071, ADR-084) |
| #400 | 2026-10-25 20:45 | LEAVE1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | LEAVE1 part (a): access ends when employment ends (0074, ADR-087) |
| #406 | 2026-10-25 22:42 | LEAVE1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | LEAVE1 part (b): open work stays visible; a wrong report of an unavailable performer never |
| #413 | 2026-10-26 02:11 | AUD1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AUD1: purpose reader for the audit log, free text stays in the team (0077) |
| #425 | 2026-10-26 04:23 | LEAVE1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | LEAVE1-14: a leaver's safety-signal take stops nothing; claim inventory (CGR-62) |
| #446 | 2026-10-26 11:18 | LEAVE1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COND1-1/-2: LEAVE1-C2/-C3/-C4 and DOOR1-12/-13/-14 (migration 0080) |
| #451 | 2026-10-26 13:06 | COND1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COND1-3: WORK1-C1 + WORK1-C4 (care ≤ paid; effective visit event times) — migration 0081,  |
| #457 | 2026-10-26 13:59 | COND1 | DB, Doku, Governance, Tests | grün | **rot** | nicht im PR nachgewiesen | COND1-4: FUP1-C1 + FUP1-C2 (banner forecast: last evaluator interval, reachable Operations |
| #465 | 2026-10-26 15:19 | COND1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COND1-5: WORK1-C2 information text v2, WORK1-C3 unexported days (0083, ADR-096) |
| #471 | 2026-10-26 18:18 | COND1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | **rot** | nicht im PR nachgewiesen | COND1-4a, -5a, -6, -9, -10: fallback test, unexported count only at access end, billing co |
| #479 | 2026-10-26 19:34 | LEAVE1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COND1-8 (LEAVE1-C5) and COND1-5b: C3 rule for OPS1 takes and quality claims; work1-notice- |
| #484 | 2026-10-27 00:12 | IPA1 | Code, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | IPA1-1 to IPA1-6: no client risk wording, no client ranking in React, /matching scorer rem |
| #487 | 2026-10-27 00:12 | IPA1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | IPA1-7, IPA1-8: intake urgency without preset and with a recorded source; referrer's reque |
| #495 | 2026-10-27 02:10 | COND1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COND2: pre-pilot conditions COND1-C1, COND1-C2, IPA1-C1 (0087, ADR-101) |
| #502 | 2026-10-27 11:19 | COND2 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | COND2-4 (IPA1-C2, CGR-71): resumed case records the returning referral's urgency, source a |
| #612 | 2026-10-28 19:11 | COORD6 | CI/Werkzeug, Doku, Governance, Tests | grün | grün | – | COORD6: agents-check keeps frozen decision packages frozen (ADR-110) |
| #637 | 2026-10-29 03:18 | infra | CI/Werkzeug, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | – | e2e on one Zurich day: run-day guard before the seed, calendar days in work.spec (#635) |
| #715 | 2026-10-30 04:25 | RLS4 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | RLS4: act columns read per record only, assignments stay visible (0099, ADR-122) |
| #722 | 2026-10-30 04:37 | RLS4 | Doku, Governance, Tests | grün | grün | – | RLS4 delivered (#715 merged); RLS4-5 (c) evidence: pilot_kpis never reads cover_events.nur |
| #792 | 2026-10-31 02:10 | RLS4 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | RLS4-C1 runbook check + RLS4-C2 /admin open reports in the access-end step only |
| #810 | 2026-11-06 16:30 | CGR-110 | CI/Werkzeug, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – eigene Code-Dateien identisch | CGR-110 (#399): pgTAP 062 owns the SIG1 evaluation lock of org A and org B; two-session ev |
| #813 | 2026-11-06 16:54 | RLS4 | Code, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – **1 von 5 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | RLS4-C3: "Erneut laden" after a failed open-report read in the access-end step; a missing  |
| #922 | 2026-11-06 20:54 | CGR-110 | Doku, Governance, Tests | grün | **rot** | auf früherem Head (clear) – eigene Code-Dateien identisch | CGR-110 remainder (#919): every pgTAP file that calls the SIG1 evaluator owns org A's lock |

### B1 Anfrage, Fall und Teamentscheid

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #23 | 2026-10-21 16:22 | J1 | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | feat(journey): J1 — referral intake → case + open matching request |
| #24 | 2026-10-21 16:29 | J2 | CI/Werkzeug, Code, DB, Doku, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | feat(teams): J2 — team decision (team pull, atomic acceptance) |
| #30 | 2026-10-21 20:09 | J1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | feat(intake): J1 per PO brief — funding facts, readiness, matching only when ready |
| #36 | 2026-10-21 21:07 | J2 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | J2 changes: qualification eligibility, decline reasons, response deadlines as configuratio |
| #42 | 2026-10-22 08:50 | J6 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | J6: primary nurse per case and continuity measure |
| #83 | 2026-10-22 11:19 | C1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | C1: case and visit lifecycle (pause, resume, close, reopen, cancel, no-show) |
| #120 | 2026-10-22 13:33 | C1 | Code, DB, Doku, Governance, Tests | grün | **rot** | nicht im PR nachgewiesen | C1: changes from the PO review (matching, late cancel, /field marker, Operations, tests) |
| #129 | 2026-10-22 15:47 | RET1 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | RET1: returning client returns to her team (ADR-048) |

### B2 Qualifikation, Tätigkeitsregeln, Nachweise, Delegation

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #101 | 2026-10-22 18:11 | ADM1 | Code, DB, Doku, Governance, Tests | grün | **rot** | nicht im PR nachgewiesen | ADM1: pilot administration — members, names, teams, operating rules |
| #135 | 2026-10-22 22:20 | ADM1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ADM1 changes: member removal releases future visits; role change; names; legacy hints remo |
| #153 | 2026-10-23 02:11 | ADM1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ADM1 CGR-18: removal checks the performer (migration 0037); ADM1 back to in-review |
| #268 | 2026-10-24 06:37 | ADM1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ADM1-R (CGR-39): direction-aware safe range for exception overrides |
| #647 | 2026-10-29 13:31 | ADM2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ADM2: the team admits its colleagues; the contract end ends access on time; no visit witho |
| #673 | 2026-10-29 18:21 | OBS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | OBS1: every observation shows who wrote it and whether her qualification was recorded (cra |
| #688 | 2026-10-29 21:23 | ADM2 | DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | OBS1-C1 (OBS1-7) + ADM2-C1: authorship/signer columns only through per-visit read paths; s |
| #939 | 2026-11-07 05:40 | QUAL1 | Code, DB, Doku, Governance, Tests | grün | grün | auf Head (clear) | QUAL1 part 1 (#931): qualification matrix as data, evidence states, delegation record, one |
| #945 | 2026-11-07 06:41 | QUAL1 | Code, DB, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – eigene Code-Dateien identisch | QUAL1 part 2 slice 2 (#931): PLAN2 series asks the one decision function (repairs #943 def |
| #943 | 2026-11-07 06:41 | QUAL1 | DB, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – eigene Code-Dateien identisch | QUAL1 part 2 slice 1 (#931): one decision function on every assignment path, care_visits b |
| #953 | 2026-11-07 08:37 | QUAL1 | Code, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | auf Head (clear) | QUAL1 part 2 slice 3 (#931): one text per QUAL1 reason on every path, no verdict on a pers |

### B3 Team- und KI-Einsatzplanung, Ausfallkoordination

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #25 | 2026-10-21 16:29 | J3 | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | feat(teams): J3 — team planning (the team plans its own visits) |
| #32 | 2026-10-21 20:13 | J3 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | feat(teams): J3 per PO brief — visit planning with billable basis |
| #39 | 2026-10-22 08:25 | OPS1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | OPS1: Operations exception center (derived exceptions, Q9 rules, handling with reasons) |
| #92 | 2026-10-22 11:45 | PLAN2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | PLAN2: self-planning — visits follow the care plan |
| #99 | 2026-10-22 12:20 | COVER1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COVER1: cross-team cover without a dispatcher |
| #114 | 2026-10-22 13:14 | COVER1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | COVER1: safety changes from the PO review (cover off until D-3) |
| #118 | 2026-10-22 13:21 | PLAN2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | PLAN2: changes from the PO review (no double planning, dropped preconditions, KPI) |
| #165 | 2026-10-23 04:28 | OPS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 2 (OPS1): CGR-05 serious event stays escalated in review; CGR-06 safety exceptio |
| #179 | 2026-10-23 07:39 | OPS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 5 (CGR-20): a broken-off visit ends as not completed (OPS1) |
| #195 | 2026-10-23 11:49 | ABS1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ABS1 part 1: absence hands the day to the team; one release rule; "Offen im Team" (0046) |
| #206 | 2026-10-23 13:40 | ABS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ABS1 part 2: one visit interval (CGR-27, C1), overlap (C2), absence per person (C3), AN1 m |
| #212 | 2026-10-23 15:34 | ABS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ABS1 part 3: no hand command gives a visit to an absent member (ABS1-C4, ABS1-N1) |
| #216 | 2026-10-23 16:43 | ABS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 10: order basis as at the visit date (J5-C2); ABS1-C5 rides along |
| #234 | 2026-10-23 20:50 | ABS1 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 12: ABS1-C6 — /field absence from yesterday; open past visits named |
| #239 | 2026-10-23 23:10 | OPS1 | DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | fix(db): one calendar today (Europe/Zurich) in functions, seed and tests |
| #243 | 2026-10-24 02:10 | ABS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AN2 part 1: CGR-35 (moved flagged visit keeps the absence fact), ABS1-C7, DAY-1-R1–R3 |
| #701 | 2026-10-29 23:06 | AIG1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AIG1 part (a): AI governance foundation in the database (0097, ADR-120) |
| #707 | 2026-10-30 00:16 | VIS2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | VIS2: same-client overlap shown before saving; same-slot cards told apart (0098, ADR-121) |
| #770 | 2026-10-30 18:11 | AIG1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AIG1-15/-16: look-back re-confirmation runs first-confirmation checks; threshold 100 refus |
| #776 | 2026-10-30 19:50 | AIG1 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AIG1 part (b) UI: confirm screen with ticked list, health list, look-back list, record lin |
| #787 | 2026-10-31 00:36 | AIG1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AIG1-C1 + AIG1-C2 + AIG1-C3: past-visit look-back lines refused not_open and counted apart |
| #814 | 2026-11-06 17:13 | AIG1 | Code, DB, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – **3 von 11 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | AIG1-C4 + AIG1-C5: expired proposals are not listed or decided and are counted apart; a st |
| #828 | 2026-11-06 17:51 | AIG1 | DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | auf früherem Head (clear) – eigene Code-Dateien identisch | AIR1 (#824): the AIG1 register refuses billing and safety-signal-priority targets; catalog |
| #872 | 2026-11-06 20:27 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – eigene Code-Dateien identisch | PLAN3 part (a) (#538): day-plan proposal in the database: agent, team switch, rule, lines, |
| #876 | 2026-11-06 20:38 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – **2 von 6 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | PLAN3-14 (#538): busy across every team, overlap re-checked at confirm (ADR-146, migration |
| #895 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | nicht im PR nachgewiesen | PLAN3-9 (1) (#538): a decided day-plan line never reads as a covered visit (ADR-156, migra |
| #934 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | auf Head (clear) | FE-041: PLAN3 stack consolidated in one PR (#880 to #910, merge commits, conflict resoluti |
| #891 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UXR-113 (#538): the /team new-visit "Verantwortlich" picker names every member with the CG |
| #903 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | PLAN3-17 (2) + PLAN3-3 wording (#538): one member label on /team and /visits/<id>; "kennt  |
| #888 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | CGR-139 (#538): one member label for every picker that assigns a visit; two unnamed member |
| #886 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | auf früherem Head (clear) – eigene Code-Dateien identisch | PLAN3-7 (#538): day-plan measures per team and month, never per person (ADR-151, migration |
| #890 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CGR-140 (#538): the PLAN3-7 measure counts a rejected line in its own share "Abgelehnt" (A |
| #894 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | nicht im PR nachgewiesen | PLAN3-7 (2) (#538): the team sees its own day-plan numbers under its switch on /team/tages |
| #882 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | auf früherem Head (clear) – eigene Code-Dateien identisch | PLAN3-12 (#538): "Vorschläge (<n>)" on /team, counted from the proposals the member alread |
| #897 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | PLAN3-15 (#538): a fresh day-plan request closes the earlier undecided lines; no open_prop |
| #902 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CGR-75 (5) (#538): an unstaffable visit is shown; a ticked line refused 'overlap' keeps it |
| #883 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | auf früherem Head (clear) – eigene Code-Dateien identisch | PLAN3-11 (#538): the team finds its own look-back lines on /team (ADR-149, migration 0111) |
| #885 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | auf früherem Head (clear) – **4 von 4 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | PLAN3-13 (#538): the look-back measure per stop and team, never per person (ADR-150, migra |
| #906 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | PLAN3-9 (2) (#538): one place decides a day-plan line; /team/vorschlaege shows one row per |
| #910 | 2026-11-07 00:40 | PLAN3 | Code, DB, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | auf Head (clear) | PLAN3-16 (#538): a hand assignment says when the member already has a visit at that time ( |
| #880 | 2026-11-07 00:40 | PLAN3 | Code, Doku, Governance, Tests | grün | kein Lauf (nicht nachgewiesen) | auf früherem Head (clear) – **5 von 13 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | PLAN3 part (b) slice 1 (#538): /team/tagesplan: ask, list per member, ticked confirm, team |

### B4 Mobile Besuchsausführung, Zeit- und Leistungserfassung

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #19 | 2026-10-21 15:35 | F1 | CI/Werkzeug, Code, DB, Tests | grün | grün | nicht im PR nachgewiesen | feat(field): F1 — nurse day view /field |
| #20 | 2026-10-21 15:45 | F2 | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | feat(field): F2 — field state machine, visit events, travel/care/pause |
| #21 | 2026-10-21 15:55 | F3 | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | feat(field): F3 — reasoned, append-only time corrections |
| #22 | 2026-10-21 16:08 | F4 | CI/Werkzeug, Code, DB, Doku, Tests | grün | grün | nicht im PR nachgewiesen | feat(field): F4 — observations, team-only visibility, handover |
| #161 | 2026-10-23 03:29 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 1 (C1): qualification for the whole visit (CGR-12); missed and stuck visits stay |
| #171 | 2026-10-23 05:26 | F1-F4 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 3 (F1-F4): only the author supersedes; signed means fixed (CGR-01, CGR-03) |
| #175 | 2026-10-23 06:44 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 4 (CGR-02): she signs what she saw (F7, F6) |
| #183 | 2026-10-23 08:50 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 6 (J5): bill from the signed snapshot; refuse unmodelled bases; holds and correc |
| #188 | 2026-10-23 09:45 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 7: CGR-19 no unsignable correction; CGR-22 uncovered visit closes only with its  |
| #192 | 2026-10-23 10:51 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 7 (completion): CGR-25, an interrupted visit keeps a signal until a person decid |
| #200 | 2026-10-23 12:52 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 8: open correction signal (CGR-24), who ended the visit (CGR-26), "Abrechnungssp |
| #210 | 2026-10-23 14:33 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 9: withdraw an untouched correction draft (CGR-24-W), CGR-29, J5-C1 (migration 0 |
| #228 | 2026-10-23 18:48 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 11 (CGR-32): past planned visit inside a new absence keeps her, is counted and f |
| #230 | 2026-10-23 19:29 | CSR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | CSR1 part 11 remainder: CGR-34 a cancelled flagged past visit keeps that its responsible m |
| #391 | 2026-10-25 18:15 | DOOR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | DOOR1 (a): door facts, codes-only Operations line, door notes on /field (0072, ADR-085) |
| #396 | 2026-10-25 19:48 | DOOR1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | DOOR1 part (b): safety-alert category list and append-only values (0073, ADR-086) |
| #434 | 2026-10-26 06:04 | WORK1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | WORK1: working day proposed from the visits, confirmed and exported by the nurse (0079, AD |
| #535 | 2026-10-27 15:20 | UX1 | CI/Werkzeug, Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX1 (a)(b)(e): phone-width frame, menu by role, CI screenshots |
| #554 | 2026-10-27 21:12 | WORK1 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX1 part (c) + UX1-20 + UX1-21: next visit first, one filled button per card, "Mehr" for c |
| #558 | 2026-10-27 22:19 | UX1 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX1 part (f): one sign-in page for every role, readable secondary text, /intake inputs ins |
| #574 | 2026-10-28 06:23 | UX1 | CI/Werkzeug, Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX1-18 axe colour-contrast and UX1-27 open work above the next visit (ADR-106) |
| #588 | 2026-10-28 09:26 | UX1 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX1 part (d), first PR: UX1-28, UX1-29, UX1-30, UXR-17 removal (ADR-107) |
| #598 | 2026-10-28 13:20 | UX1 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX1 part (d): no internal codes in page text, one product name, one label per page (UX1-11 |
| #602 | 2026-10-28 13:36 | UX1 | Code, Doku, Governance, Tests | grün | **rot** | nicht im PR nachgewiesen | UX1 part (g): one pointer line for repeated signals, red only for safety signals, team pus |
| #624 | 2026-10-28 21:19 | VIS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | VIS1: field actions happen on the visit's day (CGR-87) |
| #633 | 2026-10-29 03:25 | VIS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | VIS1 follow-up: day rule on every write path, move fact, move at the door (VIS1-3c, -3d, - |
| #655 | 2026-10-29 07:13 | VIS1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | VIS1-10: Heute machen lands on the database's today, or is refused and offered again (CGR- |
| #653 | 2026-10-29 07:13 | VIS1 | Tests | grün | abgebrochen (nicht nachgewiesen) | – | fix(e2e): vis1.spec finds the moved visit by date and times (#650) |
| #742 | 2026-10-30 09:44 | UX2 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | UX2-22, UX2-23 (G-23 preconditions): no field action she cannot perform; switches with org |
| #761 | 2026-10-30 15:45 | WORK1 | CI/Werkzeug, Doku, Governance, Tests | grün | **rot** | – | WORK1-C5: test 44 names role and object; pgTAP 079 at one snapshot; 50-run evidence (ADR-1 |
| #764 | 2026-10-30 16:27 | VIS1 | Doku, Governance, Tests | grün | grün | – | CGR-96: vis1.spec owns its moved card; pgTAP 102 shows one move never yields two visits (A |
| #781 | 2026-10-30 22:24 | VIS1 | Doku, Governance, Tests | grün | grün | – | CGR-96: vis1.spec /team item by unique move reason (remedy (a)-(d)) |
| #799 | 2026-11-05 10:56 | UX2 | Code, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | UX2-1: one shell for every protected route (phone tab bar, desktop sidebar), ADR-131 |
| #800 | 2026-11-06 12:59 | UX2 | Code, Doku, Governance, Tests | grün | grün | auf Head (clear) | UX2-27, UX2-29: one author line for an observation; Verantwortlich / noch niemand on /visi |
| #803 | 2026-11-06 15:19 | UX2 | Code, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – eigene Code-Dateien identisch | UX2-15, UX2-16, UX2-25: reach gap outside the fold; alert frame follows what it shows; rea |
| #804 | 2026-11-06 15:37 | UX2 | Code, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – eigene Code-Dateien identisch | UX2-18 to UX2-21: the move-to-today fact keeps its place, flags describe the moved card, t |
| #806 | 2026-11-06 15:52 | UX2 | Code, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – **1 von 8 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | UX2-30: assessment form at phone width; replace form names its record and prefills the ins |
| #809 | 2026-11-06 16:10 | UX2 | Code, Doku, Governance, Tests | grün | grün | auf früherem Head (clear) – **1 von 5 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | UX2-26: the qualification in the same sitting as the contract on /admin (existing command, |

### B5 Sicherheitssignale und Eskalation

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #279 | 2026-10-24 08:54 | SIG1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | SIG1: safety signals reach a person (migration 0060, ADR-074) |
| #295 | 2026-10-24 13:17 | SIG2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | SIG2: safety signals reach the nurse's phone (0062, ADR-076) |
| #312 | 2026-10-24 18:44 | SIG1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ORD0-C1, ORD0-C2, SIG1-C1 (Next up 1): inform_gp opens again on an event; a care assistant |
| #315 | 2026-10-24 19:39 | SIG2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | SIG2 follow-up: SIG2-11, -12, -13 (+ SIG2-14): evaluator liveness, Operations in watched h |
| #349 | 2026-10-25 08:17 | DST1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | DST1: safety alerts on time on the clock-change nights (0067, ADR-081, pgTAP 068) |
| #361 | 2026-10-25 11:17 | SIGC | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | SIGC: AN2 counts the take that stops the step; honest text and list outside watched hours  |
| #362 | 2026-10-25 11:34 | DST1 | CI/Werkzeug, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | DST1-C1..C3: interval ends take the later instant; DST1-7 assertions; real clock before th |
| #428 | 2026-10-26 04:23 | push | Tests | grün | abgebrochen (nicht nachgewiesen) | – | test(push): pad generated VAPID private key to 32 bytes (unit flake) |

### B6 Diktat, KI-Dokumentation, menschliche Freigabe

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #35 | 2026-10-21 20:43 | F6 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | F6: signed visit report (performer signs, countersignature provisional D-10, immutable ver |
| #94 | 2026-10-22 11:59 | F7 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | F7: sign at completion — the visit ends with a final report |
| #122 | 2026-10-22 13:55 | F7 | Code, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | F7: changes from the PO review (see what you sign, failed draft visible, countersign e2e) |
| #128 | 2026-10-22 15:15 | HAND1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | HAND1: since you were last here (ADR-047) |
| #320 | 2026-10-24 21:22 | F6R | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | F6R: return a report instead of countersigning a version known to be wrong (migration 0065 |

### B7 Assessment, Pflegeplanung, ärztliche Anordnung

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #41 | 2026-10-22 08:43 | QG1 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | QG1: quality events and quality holds (clinical type list waits for D-16) |
| #284 | 2026-10-24 10:16 | ORD0 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | ORD0: doctor informed closes the task; open-ended B order is a P3 exception (0061, ADR-075 |
| #727 | 2026-10-30 08:25 | ASM1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | ASM1: assessment record, care plan against its assessment (0100, ADR-123) |
| #747 | 2026-10-30 14:21 | ASM1 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | ASM1-C1 to ASM1-C5: confirmation line, folded history, refusal texts, review act, correcte |
| #815 | 2026-11-07 16:40 | ASM1 | Code, DB, Doku, Governance, Tests | grün | grün | auf Head (clear) | ASM1-C6 with C6 (8): "Irrtümlich erfasst" void act with the P-37 preset; voided fields wit |

### B8 Abrechnung, Validierung, Fehlerfälle

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #43 | 2026-10-22 09:11 | J5 | CI/Werkzeug, Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | J5: billable facts and monthly estimate preview |
| #75 | 2026-10-22 10:43 | J5 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | J5 change: billable minutes follow measured care time (Q11) |
| #222 | 2026-10-23 17:20 | J5 | Doku, Governance, Tests | grün | grün | – | CGR-33: pgTAP guard for the order history J5-C2 reads |

### B10 Kennzahlen und Wirkungsmessung

| PR | gemergt (UTC) | Item | Änderung | CI Head | CI integriert | cra-Gate | Titel |
|---|---|---|---|---|---|---|---|
| #97 | 2026-10-22 12:06 | AN1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AN1: pilot impact dashboard |
| #124 | 2026-10-22 14:17 | AN1 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | nicht im PR nachgewiesen | AN1: changes from the PO review (honest care share, 3-person rule, cover KPIs) |
| #255 | 2026-10-24 04:15 | AN1 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AN2 part 2: Pilot-Hypothesen from events (measures 3, 5, 6, 7, 9, 11, 12); AN1 organisatio |
| #263 | 2026-10-24 05:46 | AN2 | Code, DB, Doku, Governance, Tests | grün | grün | nicht im PR nachgewiesen | AN2 part 3: measures 1, 2, 4, 8 (AN2-M8a) and 10 in Pilot-Hypothesen |
| #841 | 2026-11-06 19:40 | AN3 | Code, DB, Doku, Governance, Tests | grün | abgebrochen (nicht nachgewiesen) | auf früherem Head (clear) – **1 von 10 eigenen Code-Dateien abweichend: für gemergten Stand nicht nachgewiesen** | AN3 (#825): where the non-care time goes: per-step spans per team and month, never per per |

## 3. Gemergte Doku- und Governance-PRs (je PR, kurz)

Kein Produktcode, keine Datenbank, keine Tests. Fachliche Gates entfallen; massgeblich ist, dass keine personenbezogenen Daten enthalten sind und `agents-check` läuft (in CI-Job `app`).

| PR | gemergt (UTC) | Rolle (Branch) | CI Head | CI integriert | Titel |
|---|---|---|---|---|---|
| #4 | 2026-10-21 10:28 | docs | grün (nur Teil der Jobs) | grün (nur Teil der Jobs) | Docs: M2 readiness — README, engineering registers, status proposal |
| #5 | 2026-10-21 10:32 | docs | grün (nur Teil der Jobs) | grün (nur Teil der Jobs) | Docs: owner runbook |
| #6 | 2026-10-21 11:28 | docs | grün (nur Teil der Jobs) | abgebrochen (nicht nachgewiesen) | Docs: verified state report (pre-T8) |
| #13 | 2026-10-21 13:04 | docs | grün | grün | Docs: owner decision brief (D-1…D-8) |
| #14 | 2026-10-21 14:43 | ops | grün | grün | docs(ops): live containment C-1 report |
| #16 | 2026-10-21 14:49 | docs | grün | grün | docs(backlog): C-1 containment and T13 done |
| #28 | 2026-10-21 17:08 | po | grün | grün | docs(agents): PO briefs, re-ranked queue, decisions and product roadmap |
| #33 | 2026-10-21 20:17 | docs | grün | grün | docs(agents): F0 per-criterion report; J1 and J3 delivered |
| #31 | 2026-10-21 20:45 | po | grün | **rot** | docs(agents): PO cycle — F0 review, D-5, J1/J3 accepted, F6 next, queue extended |
| #37 | 2026-10-21 20:59 | po | grün | grün | docs(agents): PO cycle — F6 accepted; OPS1 next after J2 |
| #40 | 2026-10-22 08:31 | docs | grün | grün | docs(agents): OPS1 delivered (#39) |
| #44 | 2026-10-22 09:17 | docs | grün | grün | docs(agents): J5 delivered (#43) |
| #45 | 2026-10-22 10:36 | po | grün | grün | docs(agents): PO cycle — accept F0, J2, OPS1, QG1, J6; J5 minutes rule; C1 next |
| #84 | 2026-10-22 10:56 | po | grün | grün | docs(agents): PO cycle — accept J5; challenge review: PLAN2 and F7 |
| #87 | 2026-10-22 11:10 | po | grün | grün | docs(product): care operating model beyond Buurtzorg; COVER1, REF2; re-rank by d |
| #90 | 2026-10-22 11:25 | docs | grün | grün | docs(agents): C1 delivered; status rows for the re-ranked queue |
| #91 | 2026-10-22 12:39 | po | grün | grün | PO cycle 2026-10-22 13:30: challenge mode, HAND1 and RET1 approved, ORD1 draft |
| #105 | 2026-10-22 12:46 | po | grün | grün | PO cycle 2026-10-22 14:30: C1, PLAN2, F7, AN1, COVER1 reviewed (changes-requeste |
| #113 | 2026-10-22 12:54 | po | grün | grün | PO 2026-10-22 14:50: Nursing Home Transformation Report; D-24, D-25 |
| #117 | 2026-10-22 13:08 | po | grün | grün | PO 2026-10-22 15:05: review addenda C1, PLAN2, COVER1; D-14 nursing-home guardra |
| #126 | 2026-10-22 18:21 | po | grün | grün | PO 2026-10-22 16:15–20:15: COVER1, PLAN2, C1, F7, AN1, HAND1, RET1 accepted; ABS |
| #137 | 2026-10-22 20:21 | po | grün | grün | PO 22:15: ADM1 changes pre-reviewed (#135); one privacy fix; HAND1 shows release |
| #139 | 2026-10-22 20:43 | gov | grün | grün | Clinical governance: baseline report, hazard log, rule and risk registers |
| #136 | 2026-10-22 21:01 | po | grün | grün | PO 22:40: Clinical & Regulatory Architect role, clinical review gate, D-27 decid |
| #141 | 2026-10-22 21:08 | po | grün | grün | PO 23:00: clinical gate applied, seven items reopened, CSR1 approved, ABS1 amend |
| #140 | 2026-10-22 21:25 | gov | grün | grün | Clinical governance 23:05: owner decision D-27 recorded; CGR-17 |
| #138 | 2026-10-22 22:12 | docs | grün | grün | Agents: Clinical & Regulatory Architect role and clinical governance gate |
| #152 | 2026-10-22 22:28 | po | grün | grün | PO 00:10: ADM1 changes pre-reviewed; CSR1 sharpened |
| #154 | 2026-10-22 23:22 | po | grün | grün | PO 01:10: ADM1 reviewed on merge commit; BL-8, BL-9 added to CSR1 |
| #156 | 2026-10-23 01:23 | po | grün | grün | PO 03:10: ADM1 changes-requested (CGR-18); CGR-19 interim in CSR1, D-30; ABS1 am |
| #158 | 2026-10-23 02:15 | docs | grün | grün | ADM1 delivered: #153 merged (CGR-18 fix) |
| #159 | 2026-10-23 02:27 | po | grün | grün | PO 04:10: ADM1 CGR-18 change pre-reviewed on #153 (met); challenge row |
| #162 | 2026-10-23 03:40 | docs | grün | grün | C1 delivered: #161 merged (CSR1 part 1, CGR-12 and CGR-04) |
| #164 | 2026-10-23 04:16 | po | grün | grün | PO cycle 06:10: CSR1 part 1 reviewed (C1, J3 met; await cra on 0038) |
| #166 | 2026-10-23 04:35 | docs | grün | grün | OPS1 delivered: #165 merged (CSR1 part 2) |
| #167 | 2026-10-23 04:50 | gov | grün | grün | Governance 06:30: CGR-18, CGR-12, CGR-04 closed; CGR-20 blocking for OPS1 |
| #155 | 2026-10-23 04:50 | gov | grün | kein Lauf (nicht nachgewiesen) | Governance 02:28: ADM1 merge-commit review (CGR-18 blocking) |
| #169 | 2026-10-23 05:19 | po | grün | grün | PO cycle 2026-10-23 07:10: ADM1, C1, J3 accepted; OPS1 changes-requested (CGR-20 |
| #172 | 2026-10-23 05:30 | docs | grün | grün | F1-F4 delivered: #171 merged (CSR1 part 3, migration 0040) |
| #174 | 2026-10-23 06:25 | po | grün | grün | po 08:20: F1-F4 reviewed (CSR1 part 3, #171), awaiting clinical review; D-10 ret |
| #176 | 2026-10-23 06:53 | docs | grün | grün | F7 delivered: #175 merged (CSR1 part 4, migration 0041) |
| #178 | 2026-10-23 07:24 | po | grün | grün | PO cycle 2026-10-23 09:10: F7 reviewed (CGR-02 met), CSR1 order, WATCH-1 |
| #180 | 2026-10-23 07:45 | docs | grün | grün | OPS1 delivered: #179 merged (CSR1 part 5, CGR-20) |
| #182 | 2026-10-23 08:20 | po | grün | grün | PO cycle 10:15: OPS1 reviewed (CGR-20 met, awaiting cra); next CSR1 part J5 |
| #184 | 2026-10-23 08:35 | gov | grün | grün | gov: clinical review 2026-10-23 10:29 (CSR1 parts 3-5: 0040, 0041, 0042) |
| #185 | 2026-10-23 08:56 | docs | grün | grün | J5 delivered: #183 merged (CSR1 part 6, migration 0043) |
| #187 | 2026-10-23 09:21 | po | grün | grün | PO cycle 2026-10-23 11:25: F1-F4, F7, OPS1 accepted; J5 reviewed; CSR1 part 7 ne |
| #189 | 2026-10-23 09:49 | docs | grün | grün | F6 and OPS1 delivered: #188 merged (CSR1 part 7) |
| #191 | 2026-10-23 10:19 | po | grün | grün | PO cycle 2026-10-23 12:15: F6 CGR-19 met, OPS1 CGR-22 met, ABS1 amended |
| #193 | 2026-10-23 10:56 | docs | grün | grün | OPS1 delivered: #192 merged (CSR1 part 7 completion, CGR-25, migration 0045) |
| #194 | 2026-10-23 11:23 | po | grün | grün | PO cycle 2026-10-23 13:20: OPS1 CGR-25 met, CSR1 part 7 complete |
| #196 | 2026-10-23 12:05 | docs | grün | grün | ABS1 delivered (part 1): #195 merged (migration 0046) |
| #198 | 2026-10-23 12:23 | po | grün | grün | PO cycle 2026-10-23 14:16: ABS1 part 1 reviewed |
| #202 | 2026-10-23 12:57 | docs | grün | grün | CSR1 part 8 delivered: #200 merged (migration 0047), journal |
| #204 | 2026-10-23 13:28 | po | grün | abgebrochen (nicht nachgewiesen) | PO cycle 2026-10-23 15:25: CSR1 part 8 met; F6, J5 accepted; ABS1 CGR-27; AN2 ap |
| #207 | 2026-10-23 13:45 | docs | grün | grün | ABS1 delivered: #206 merged (migration 0048) |
| #211 | 2026-10-23 14:48 | docs | grün | grün | CSR1 part 9 delivered: #210 merged (migration 0049), journal |
| #209 | 2026-10-23 15:16 | po | grün | grün | PO cycle 2026-10-23 16:55: ABS1 part 2 and CSR1 part 9 met (await cra); ABS1-C4, |
| #213 | 2026-10-23 15:48 | docs | grün | grün | ABS1 delivered: #212 merged (migration 0050) |
| #215 | 2026-10-23 16:21 | po | grün | grün | PO cycle 18:15: ABS1 part 3 reviewed; ABS1-C5 rides with CSR1 part 10 |
| #217 | 2026-10-23 16:35 | gov | grün | grün | Clinical governance review 2026-10-23 18:30: 0048-0050, #216; CGR-27 and CGR-29  |
| #218 | 2026-10-23 16:47 | docs | grün | grün | CSR1 part 10 and ABS1-C5 delivered: #216 merged |
| #220 | 2026-10-23 17:07 | gov | grün | grün | Clinical governance review 2026-10-23 19:00: 0051, 0052; CGR-32, CGR-33 |
| #223 | 2026-10-23 17:25 | docs | grün | grün | J5 delivered: #222 merged (CGR-33) |
| #221 | 2026-10-23 17:33 | po | grün | grün | PO cycle 19:12: ABS1 accepted (condition CGR-32); J5-C2 met; CSR1 part 11 before |
| #224 | 2026-10-23 17:54 | gov | grün | grün | Clinical governance review 2026-10-23 19:46: CGR-33 closed (pgTAP 053); CGR-32 r |
| #229 | 2026-10-23 19:02 | docs | grün | grün | docs: ABS1 delivered (CGR-32, #228 merged) |
| #227 | 2026-10-23 19:16 | po | grün | grün | PO cycle 2026-10-23 20:15: CGR-34 decided; CSR1 part 11 = CGR-32 + CGR-34 |
| #232 | 2026-10-23 19:44 | docs | grün | grün | docs: CGR-34 delivered (#230 merged), journal |
| #231 | 2026-10-23 20:15 | po | grün | grün | PO cycle 2026-10-23 21:17: CGR-32 met; ABS1-C6; CSR1 part 12 ordered |
| #233 | 2026-10-23 20:20 | po | grün | grün | PO cycle 2026-10-23 22:15: CGR-34 met; CSR1 part 12 = ABS1-C6 |
| #235 | 2026-10-23 20:34 | gov | grün | grün | Clinical governance review 2026-10-23 22:30: CGR-32, CGR-34 closed; CGR-35 (advi |
| #236 | 2026-10-23 20:55 | docs | grün | **rot** | docs: ABS1-C6 delivered (#234 merged) |
| #238 | 2026-10-23 23:21 | po | grün | grün | PO: ABS1-C6 met, CSR1 complete; decision packages and lca; DAY-1 reviewed; packa |
| #242 | 2026-10-24 00:27 | po | grün | grün | PO cycle 2026-10-24 02:20: packages D-31, D-3, D-29; AN2-M7 |
| #244 | 2026-10-24 00:42 | gov | grün | grün | gov: clinical review 2026-10-24 02:26 (CGR-36, CGR-37, CGR-38; Clinical impact D |
| #241 | 2026-10-24 01:10 | lca | grün | grün | lca review 2026-10-24 01:50 + 02:52: legal/compliance input for D-22, D-18, D-31 |
| #245 | 2026-10-24 01:21 | po | grün | grün | PO cycle 2026-10-24 03:10: SIG1, ORD0 approved; packages D-30, D-16, D-12; D-32 |
| #249 | 2026-10-24 02:03 | lca | grün | grün | lca review 2026-10-24 03:53: D-22, D-18 re-check; D-30 |
| #250 | 2026-10-24 02:14 | docs | grün | grün | eng 04:10: #243 merged — ABS1 delivered, AN2 stays in-progress |
| #252 | 2026-10-24 02:24 | po | grün | grün | PO cycle 2026-10-24 04:10: #243 reviewed, DAY-1 accepted; packages D-32, D-11, D |
| #253 | 2026-10-24 02:58 | lca | grün | grün | lca review 2026-10-24 04:50: legal/compliance input D-16, D-32, D-12 |
| #254 | 2026-10-24 03:20 | po | grün | grün | PO cycle 2026-10-24 05:15: D-22 and D-18 to owner; D-32 notes; packages D-9, D-4 |
| #256 | 2026-10-24 03:51 | lca | grün | grün | lca review 2026-10-24 05:45: re-check D-22, D-18; legal/compliance input for D-1 |
| #257 | 2026-10-24 04:19 | docs | grün | grün | AN2: record #255 merge (status row, journal) |
| #258 | 2026-10-24 04:27 | po | grün | grün | PO cycle 2026-10-24 06:10: D-28 escalated to clinical (SIG1-9); Engineering impa |
| #260 | 2026-10-24 04:54 | lca | grün | grün | lca review 2026-10-24 06:55: D-15 input; D-3, D-29 re-check |
| #261 | 2026-10-24 05:22 | po | grün | grün | PO cycle 2026-10-24 07:10: ADM1 changes-requested (CGR-39, S1); AN2 part 2 revie |
| #264 | 2026-10-24 05:51 | docs | grün | **rot** | AN2: delivered (#243, #255, #263) |
| #267 | 2026-10-24 06:28 | po | grün | grün | po cycle 2026-10-24 08:18: AN2 accepted; D-30, D-16 awaiting clinical; D-32 draf |
| #269 | 2026-10-24 06:42 | docs | grün | grün | ADM1: delivered (#268), journal |
| #266 | 2026-10-24 06:56 | lca | grün | grün | lca review 2026-10-24 07:40 + 08:47: D-9, D-4 input; D-31, D-32, D-30 re-checks |
| #273 | 2026-10-24 07:27 | docs | grün | grün | COORD5 delivered (#271) |
| #272 | 2026-10-24 07:31 | po | grün | grün | po cycle 2026-10-24 09:12: ADM1 accepted; D-32 decided; D-11, D-12, D-33 to owne |
| #276 | 2026-10-24 07:59 | lca | grün | grün | lca review 2026-10-24 09:53: D-12, D-11, D-33 re-checks |
| #277 | 2026-10-24 08:22 | po | grün | grün | po cycle 2026-10-24 10:11: COORD5 accepted; D-15, D-9 escalated; D-4 provisional |
| #280 | 2026-10-24 08:59 | lca | grün | grün | lca review 2026-10-24 10:47: re-check D-32 (CGR-41), D-9, D-4 |
| #282 | 2026-10-24 09:23 | po | grün | grün | po cycle 2026-10-24 11:09: SIG1 reviewed (awaiting clinical review); SIG2 approv |
| #281 | 2026-10-24 09:36 | docs | grün | grün | SIG1 delivered (#279 merged, CI green) |
| #286 | 2026-10-24 10:00 | lca | grün | grün | lca review 2026-10-24 11:55: legal/compliance input for D-10, D-7; re-check D-15 |
| #287 | 2026-10-24 10:20 | po | grün | grün | po cycle 2026-10-24 12:10: lca 11:55 taken up (D-10, D-7, D-15); packages D-1, S |
| #290 | 2026-10-24 11:07 | lca | grün | grün | lca review 2026-10-24 12:55: legal/compliance input for D-1, SR-26, D-8 |
| #289 | 2026-10-24 11:22 | docs | grün | grün | docs: ORD0 delivered (#284 merged) |
| #293 | 2026-10-24 11:50 | lca | grün | grün | lca review 2026-10-24 13:50: legal/compliance input for D-2; re-check D-29, D-30 |
| #296 | 2026-10-24 12:58 | lca | grün | grün | lca review 2026-10-24 15:05: D-22, D-18 (tarifsuisse contract), D-32 (SIG2 Opera |
| #297 | 2026-10-24 13:23 | docs | grün | **rot** | docs: SIG2 delivered (#295 merged) |
| #291 | 2026-10-24 13:39 | po | grün | grün | po cycles 2026-10-24 13:15 + 14:40 + 15:10: SIG1 accepted (SIG1-C1); ORD0 change |
| #300 | 2026-10-24 14:02 | lca | grün | grün | lca review 2026-10-24 16:05: D-22, D-18 re-check; D-19 input |
| #301 | 2026-10-24 14:20 | po | grün | grün | po cycle 2026-10-24 16:20: packages D-14, D-13, D-24; ORD0-C2 widened (lca 16:05 |
| #302 | 2026-10-24 15:04 | lca | grün | grün | lca review 2026-10-24 16:45: D-16, D-3 re-check; D-34 (MepV) input |
| #303 | 2026-10-24 15:22 | po | grün | grün | po cycle 2026-10-24 17:10: D-2 design decided, D-7 to owner, D-34 inventory, D-1 |
| #304 | 2026-10-24 16:05 | lca | grün | grün | lca review 2026-10-24 17:57: D-23, D-14, D-17 (first lca sections) |
| #305 | 2026-10-24 16:26 | po | grün | grün | po cycle 2026-10-24 18:12: D-8 to owner, D-10 E drafted, D-25 package; lca 17:57 |
| #307 | 2026-10-24 16:54 | lca | grün | grün | lca review 2026-10-24 18:47: D-13, D-20, D-25 |
| #308 | 2026-10-24 17:21 | po | grün | grün | po cycle 2026-10-24 19:09: SIG2-13 (CGR-45), F6R approved, D-10 to clinical, D-3 |
| #313 | 2026-10-24 18:49 | docs | grün | grün | docs(agents): ORD0 delivered (#312 merged, CI green) |
| #311 | 2026-10-24 19:25 | po | grün | grün | po cycles 2026-10-24 20:09 + 21:10: ORD0 accepted, SIG1-C1 met; SIG2-14; D-26 to |
| #316 | 2026-10-24 19:45 | docs | grün | grün | docs(agents): SIG2 delivered (#315 merged, CI green) |
| #310 | 2026-10-24 19:59 | lca | grün | grün | lca review 2026-10-24 19:55 + 20:50 + 21:55: D-26, D-10, D-34; D-1, SR-26; D-24; |
| #318 | 2026-10-24 20:22 | po | grün | grün | po cycle 2026-10-24 22:10: SIG2 accepted; RLS2 approved; D-19, D-3, D-23 package |
| #322 | 2026-10-24 20:53 | lca | grün | grün | lca review 2026-10-24 22:50: D-19, D-17 |
| #323 | 2026-10-24 21:24 | po | grün | grün | po cycle 2026-10-24 23:10: D-19, D-17 awaiting clinical; D-20 decided (D sharpen |
| #325 | 2026-10-24 21:35 | docs | grün | grün | F6R delivered (#320 merged, CI green) |
| #332 | 2026-10-24 22:56 | lca | grün | grün | lca review 2026-10-25 00:50: D-10 (F6R delivered, leaver access), D-30, D-20 (AD |
| #330 | 2026-10-24 23:16 | po | grün | grün | po cycle 2026-10-25 00:10: F6R accepted; D-6, D-13 decided by po; D-14 to owner |
| #335 | 2026-10-24 23:26 | po | grün | grün | po cycle 2026-10-25 01:16: LEAVE1 approved; D-24, D-25 to owner |
| #338 | 2026-10-24 23:50 | lca | grün | grün | lca review 2026-10-25 01:41 (D-14, D-13, D-24) |
| #342 | 2026-10-25 01:48 | lca | grün | grün | lca review 2026-10-25 02:48 CEST + 02:42 CET (D-25; D-10, D-15) |
| #340 | 2026-10-25 02:20 | po | grün | grün | po cycles 2026-10-25 02:10 CEST + 02:10 CET + 03:10 CET: SIGC rename; DST1 appro |
| #346 | 2026-10-25 02:50 | lca | grün | grün | lca review 2026-10-25 03:43 CET: D-23 (ArGV 2 Art. 17), D-3 (Q13 F-1 interim) |
| #347 | 2026-10-25 03:20 | po | grün | grün | po cycle 2026-10-25 04:10 CET: lca 03:43 in D-3, D-23, D-32 |
| #321 | 2026-10-25 04:38 | gov | grün | kein Lauf (nicht nachgewiesen) | gov review 2026-10-24 22:26: 0063 + 0064 reviewed; CGR-42/43/44/45 closed; CGR-4 |
| #278 | 2026-10-25 04:38 | gov | grün | grün | gov review 2026-10-24 10:26: CGR-39 closed (0059); CGR-41 on D-32; supersedes #2 |
| #259 | 2026-10-25 04:38 | gov | grün | grün | gov review 2026-10-24 06:30: CGR-35 closed; CGR-39 blocking (S1); Clinical impac |
| #348 | 2026-10-25 04:38 | gov | grün | grün | gov review 2026-10-25 05:30 CET: CGR-52 re-assessed (S2, production affected); D |
| #294 | 2026-10-25 04:38 | gov | grün | kein Lauf (nicht nachgewiesen) | gov review 2026-10-24 14:27: SIG1 + ORD0 reviewed; CGR-36/37/38/40 closed; CGR-4 |
| #306 | 2026-10-25 04:38 | gov | grün | grün | gov review 2026-10-24 18:26: SIG2 reviewed; CGR-41 closed; CGR-45; Clinical impa |
| #341 | 2026-10-25 04:38 | gov | **rot** | kein Lauf (nicht nachgewiesen) | gov review 2026-10-25 02:26: F6R-G1 met (0065); RLS2 reviewed; CGR-49/50/51; Cli |
| #350 | 2026-10-25 05:17 | po | grün | grün | po cycle 2026-10-25 06:10 CET |
| #353 | 2026-10-25 06:59 | lca | grün | grün | lca review 2026-10-25 07:50 CET (D-3, D-23) |
| #354 | 2026-10-25 07:20 | po | grün | grün | po cycle 2026-10-25 08:10 CET: RLS2 accepted, RLS3 approved |
| #352 | 2026-10-25 08:10 | docs | grün | grün | RLS2 delivered (#331 merged c1703a0) |
| #356 | 2026-10-25 08:23 | docs | grün | grün | DST1 delivered (#349 merged 3c2da15) |
| #359 | 2026-10-25 09:19 | po | grün | grün | po cycle 2026-10-25 10:12 CET: DST1 changes-requested, RLS3-4b |
| #363 | 2026-10-25 10:50 | lca | grün | grün | lca review 2026-10-25 11:50 CET: D-23, D-3 re-checked (RLS3-4b billing-review re |
| #364 | 2026-10-25 11:20 | po | grün | grün | po cycle 2026-10-25 12:12 CET: RLS3-4b sharpened (lca 11:50) |
| #366 | 2026-10-25 11:28 | docs | grün | grün | SIGC delivered (#361 merged 2ad9860) |
| #368 | 2026-10-25 11:40 | docs | grün | grün | DST1 follow-up delivered (#362 merged 363906a) |
| #371 | 2026-10-25 11:54 | lca | grün | grün | lca review 2026-10-25 12:46 CET: D-23 item 10, D-3 item 8 re-checked |
| #372 | 2026-10-25 12:24 | po | grün | grün | po cycle 2026-10-25 13:16 CET: SIGC and DST1 follow-up reviewed (awaiting cra);  |
| #374 | 2026-10-25 12:39 | gov | grün | grün | gov review 2026-10-25 13:26 CET: SIGC and DST1 follow-up reviewed; CGR-46, -47,  |
| #358 | 2026-10-25 12:39 | gov | grün | kein Lauf (nicht nachgewiesen) | gov review 2026-10-25 09:31 CET: DST1 reviewed, CGR-52 closed; CGR-53 to CGR-56 |
| #375 | 2026-10-25 13:30 | po | grün | grün | po cycle 2026-10-25 14:13 CET: SIGC and DST1 accepted; Q15 decided; FUP1 approve |
| #377 | 2026-10-25 13:59 | lca | grün | grün | lca review 2026-10-25 14:45 CET (D-23) |
| #378 | 2026-10-25 14:24 | docs | grün | grün | eng 2026-10-25 15:20 CET: RLS3 delivered (#373) |
| #380 | 2026-10-25 14:59 | lca | grün | grün | lca review 2026-10-25 15:41 CET (D-3 gate iv, D-23 after RLS3 merge) |
| #381 | 2026-10-25 15:20 | po | grün | grün | po cycle 2026-10-25 16:11 CET (RLS3 accepted; AUD1 approved) |
| #385 | 2026-10-25 15:51 | lca | grün | grün | lca review 2026-10-25 16:41 CET (D-3, D-4) |
| #384 | 2026-10-25 16:16 | docs | grün | grün | eng 2026-10-25 16:45 CET: FUP1 delivered (#383 merged 5fbda91) |
| #386 | 2026-10-25 16:29 | po | grün | grün | po cycle 2026-10-25 17:11 CET: FUP1 reviewed, Q16 |
| #388 | 2026-10-25 16:42 | gov | grün | grün | gov review 2026-10-25 17:26 CET (RLS3, FUP1) |
| #389 | 2026-10-25 16:59 | lca | grün | grün | lca review 2026-10-25 17:39 CET (D-4) |
| #390 | 2026-10-25 17:20 | po | grün | grün | po cycle 2026-10-25 18:12 CET: FUP1 accepted (FUP1-C2 from CGR-60); lca 17:39 in |
| #392 | 2026-10-25 18:22 | docs | grün | grün | eng: DOOR1 part (a) merged (#391); row in-progress until part (b) |
| #394 | 2026-10-25 18:48 | lca | grün | grün | lca review 2026-10-25 19:39 CET: D-3 gate (iv) F-1 after DOOR1 part (a) |
| #397 | 2026-10-25 19:54 | docs | grün | grün | eng: DOOR1 delivered (#391, #396 merged) |
| #395 | 2026-10-25 20:21 | po | grün | grün | po cycles 2026-10-25 20:10 and 21:10 CET: D-3 F-1 met; DOOR1 accepted (condition |
| #403 | 2026-10-25 20:56 | docs | grün | grün | eng: LEAVE1 part (a) merged, row in-progress |
| #402 | 2026-10-25 21:05 | lca | grün | grün | lca review 2026-10-25 21:50: re-check D-17 and D-19 after DOOR1 |
| #405 | 2026-10-25 21:32 | po | grün | grün | po cycle 2026-10-25 22:10 CET: LEAVE1 questions answered, LEAVE1-13, go-live gat |
| #407 | 2026-10-25 21:47 | lca | grün | grün | lca review 2026-10-25 22:40: D-9 re-check (g4 per-contact consent) |
| #410 | 2026-10-25 22:48 | docs | grün | grün | eng: LEAVE1 delivered (#400 + #406) |
| #408 | 2026-10-25 23:23 | po | grün | grün | po cycle 2026-10-25 23:11 + 2026-10-26 00:20 CET: D-9 g4 criteria; LEAVE1 review |
| #414 | 2026-10-25 23:56 | lca | grün | grün | lca review 2026-10-26 00:50 CET: D-30 and D-10 re-check after LEAVE1 |
| #415 | 2026-10-26 00:18 | po | grün | grün | po cycle 2026-10-26 01:10 CET: lca 00:50 taken in (D-30, D-10, D-12, D-18) |
| #417 | 2026-10-26 01:19 | po | grün | grün | po cycle 2026-10-26 02:14 CET: LEAVE1 changes-requested (CGR-62 → LEAVE1-14); D- |
| #419 | 2026-10-26 01:56 | lca | grün | grün | lca review 2026-10-26 02:46 CET: D-30 (4), (5), (d) |
| #420 | 2026-10-26 02:18 | docs | grün | grün | eng 2026-10-26 03:20 CET: AUD1 delivered (#413) |
| #421 | 2026-10-26 02:43 | po | grün | **rot** | po cycle 2026-10-26 03:13 CET: D-30 lca 02:46 taken in; D-12 follow-up term; cha |
| #423 | 2026-10-26 02:49 | lca | grün | grün | lca review 2026-10-26 03:42 CET: D-3 gate (iv) F-3 met after AUD1; D-4 r3 met |
| #424 | 2026-10-26 03:18 | po | grün | grün | po cycle 2026-10-26 04:10 CET: AUD1 accepted; D-3 gate (iv) met; D-4 r3 met |
| #426 | 2026-10-26 03:59 | lca | grün | grün | lca review 2026-10-26 04:50 CET: amended DSV Art. 4; D-3 gate (i), D-4 question  |
| #427 | 2026-10-26 04:18 | po | grün | grün | po cycle 2026-10-26 05:10 CET: lca 04:50 taken in (D-3 gate (i) unchanged; D-4 q |
| #429 | 2026-10-26 04:30 | docs | grün | grün | LEAVE1 delivered: LEAVE1-14 (#425 merged 71147a5, #428) |
| #431 | 2026-10-26 04:43 | gov | grün | grün | cra review 2026-10-26 05:26 CET: LEAVE1-14 and AUD1 reviewed; CGR-62 closed; CGR |
| #432 | 2026-10-26 04:48 | lca | grün | grün | lca review 2026-10-26 05:41 CET: D-12 partnership terms, D-14 constraint 7 |
| #433 | 2026-10-26 05:19 | po | grün | grün | po cycle 2026-10-26 06:10 CET: LEAVE1 accepted; conditions LEAVE1-C2 to C4; D-12 |
| #436 | 2026-10-26 06:23 | po | grün | grün | po cycle 2026-10-26 07:15 CET: WORK1 reviewed (awaiting clinical review), WORK1- |
| #438 | 2026-10-26 06:49 | lca | grün | **rot** | lca 2026-10-26 07:45 CET: D-23 item 14 re-check |
| #439 | 2026-10-26 07:29 | po | grün | grün | po cycle 2026-10-26 08:15 CET: D-23 item 15, WORK1-C2/-C3 |
| #440 | 2026-10-26 08:30 | po | grün | **rot** | po cycle 2026-10-26 09:15 CET: COND1 approved (conditions under one hand-off) |
| #441 | 2026-10-26 08:42 | gov | grün | grün | cra review 2026-10-26 09:26 CET: WORK1 reviewed (no blocking finding); CGR-65 (a |
| #443 | 2026-10-26 08:58 | lca | grün | grün | lca review 2026-10-26 09:55 CET: D-23 re-check on CGR-65 |
| #435 | 2026-10-26 09:13 | docs | grün | **rot** | WORK1 delivered: status row and journal |
| #445 | 2026-10-26 09:21 | po | grün | grün | po 2026-10-26 10:15: WORK1 accepted; CGR-65 as WORK1-C4; D-23 item 16 |
| #447 | 2026-10-26 11:26 | docs | grün | grün | eng: #446 merged; COND1 in-progress (COND1-1/-2 merged) |
| #449 | 2026-10-26 11:53 | lca | grün | grün | lca review 2026-10-26 12:50: D-17 after DOOR1-12 |
| #450 | 2026-10-26 12:35 | po | grün | grün | po cycle 2026-10-26 13:15: lca 12:50 into D-17, D-12, D-2 |
| #452 | 2026-10-26 12:48 | gov | grün | grün | cra review 2026-10-26 13:39: COND1-1/-2 (0080) reviewed; CGR-61, -63, -64 closed |
| #454 | 2026-10-26 13:13 | docs | grün | grün | eng 14:10: #451 merged; COND1 in-progress (COND1-1 to -3 merged) |
| #453 | 2026-10-26 13:25 | po | grün | grün | po 2026-10-26 15:00: D-34 assessment, transformation alignment, IPA1, D-33 decid |
| #458 | 2026-10-26 13:36 | po | grün | grün | po: journal time correction |
| #459 | 2026-10-26 13:53 | po | grün | grün | po 2026-10-26 14:47: AI Operating Model Review; D-35 opened |
| #461 | 2026-10-26 14:11 | docs | grün | **rot** | eng: #457 merged; COND1 in-progress (COND1-1 to -4 merged) |
| #462 | 2026-10-26 14:22 | lca | grün | grün | lca 2026-10-26 15:04: D-34 re-check (statement v2, G3-G5, questions 7-9); D-35 f |
| #466 | 2026-10-26 15:05 | lca | grün | grün | lca review 2026-10-26 15:43: D-33 re-check (G-20), D-2 confirmation |
| #467 | 2026-10-26 15:26 | docs | grün | **rot** | eng 2026-10-26 16:19: #465 merged; COND1 in-progress (COND1-1 to -5 merged) |
| #464 | 2026-10-26 15:40 | po | grün | grün | po 2026-10-26 15:16 + 16:20: ADR-095/096 deviations decided (COND1-4a, COND1-5a) |
| #469 | 2026-10-26 15:54 | lca | grün | grün | lca review 2026-10-26 16:42: D-23 re-check (WORK1-C2, WORK1-C3, ADR-096); D-12 s |
| #470 | 2026-10-26 16:23 | po | grün | grün | po cycle 2026-10-26 17:15: COND1-5b (text v3), lca 16:42 taken in, D-35 eng draf |
| #472 | 2026-10-26 16:36 | gov | grün | grün | cra review 2026-10-26 17:26: COND1-3/-4/-5 reviewed; CGR-60, CGR-65 closed; CGR- |
| #473 | 2026-10-26 16:50 | lca | grün | grün | lca review 2026-10-26 17:55: D-23 (P-11), D-34 Q7, D-35 |
| #474 | 2026-10-26 17:32 | po | grün | grün | po cycle 2026-10-26 18:10: CGR-69 as IPA1-7/-8, D-35 po-decided (A), D-34 tier 2 |
| #475 | 2026-10-26 18:24 | docs | grün | grün | eng 2026-10-26 19:19: #471 merged; COND1 in-progress |
| #477 | 2026-10-26 18:48 | lca | grün | grün | lca 2026-10-26 19:42: D-35 check of decided option A |
| #478 | 2026-10-26 19:23 | po | grün | grün | po 2026-10-26 20:25: D-35 term 11, D-1 connector step, D-12 AI-tool policy term |
| #480 | 2026-10-26 19:44 | docs | grün | grün | eng: COND1 delivered (#479 merged) |
| #481 | 2026-10-26 20:00 | lca | grün | grün | lca 2026-10-26 21:00: D-23 (work1-notice-v3), D-35 (term 11 as adopted) |
| #483 | 2026-10-26 20:28 | po | grün | grün | po 2026-10-26 21:10: COND1 reviewed (awaiting clinical review), D-23/D-35/D-1 lc |
| #485 | 2026-10-26 20:40 | gov | grün | grün | cra review 2026-10-26 21:29: COND1 0084/0085 reviewed; CGR-66, CGR-67 closed; CG |
| #486 | 2026-10-26 21:38 | po | grün | grün | po 2026-10-26 22:10: COND1 accepted; CGR-70 as COND1-C2; IPA1 Next up 1 |
| #488 | 2026-10-27 00:19 | docs | grün | grün | eng 2026-10-27 01:15: IPA1 delivered (#484, #487 merged) |
| #490 | 2026-10-27 00:26 | po | grün | grün | po 2026-10-27 01:40: IPA1 reviewed (awaiting cra on 0086); COND2 approved; P-14 |
| #492 | 2026-10-27 00:34 | gov | grün | grün | cra review 2026-10-27 01:27: IPA1 reviewed; CGR-69 closed; CGR-71 (advisory) |
| #493 | 2026-10-27 00:57 | lca | grün | grün | lca review 2026-10-27 01:45: D-34 re-check on IPA1 as built |
| #494 | 2026-10-27 01:19 | po | grün | grün | po 2026-10-27 02:10: IPA1 accepted; CGR-71 → COND2-4; D-34 lca re-check taken in |
| #496 | 2026-10-27 02:17 | docs | grün | grün | eng 03:15: #495 merged; COND2 in-progress (COND2-4 PLANNED) |
| #497 | 2026-10-27 02:35 | po | grün | grün | po 2026-10-27 03:10: ADM2 approved (Next up 2); G-23; D-20 lca request |
| #501 | 2026-10-27 03:25 | po | grün | grün | po cycle 2026-10-27 04:10: ADM2-14, D-4 item (5), G-23, P-16 |
| #503 | 2026-10-27 04:36 | gov | grün | grün | cra review 2026-10-27 05:30: CGR-70 closed; CGR-72 (ADM2, blocking for acceptanc |
| #504 | 2026-10-27 05:20 | po | grün | grün | po 2026-10-27 06:10: ADM2-15 for CGR-72; CGR-73 as COND2-4a; P-17 |
| #500 | 2026-10-27 07:40 | lca | grün | grün | lca review 2026-10-27 03:50 + 06:05 + 07:41: D-20 ADM2 part (b); CGR-72; ADM2-15 |
| #505 | 2026-10-27 08:41 | gov | grün | grün | cra review 2026-10-27 09:30: CGR-74 (COND2-4a pgTAP non-deterministic, advisory) |
| #511 | 2026-10-27 09:22 | po | grün | grün | po 2026-10-27 10:14: UX1 and UX2 approved from the UX review (#506-#510); CGR-74 |
| #514 | 2026-10-27 09:36 | po | grün | grün | po 2026-10-27 10:40: UX/UI Design Architect (uxa), design system v0, UX modernis |
| #517 | 2026-10-27 09:59 | ux | grün | grün | uxa 2026-10-27 10:42: first UX review, design system v1 |
| #518 | 2026-10-27 10:17 | po | grün | grün | po 2026-10-27 11:10: uxa findings #515 and #516 placed in UX1 part (f) |
| #519 | 2026-10-27 10:35 | ux | grün | grün | uxa 2026-10-27 11:19: owner approval; requests to cra (C-1 to C-4) and lca (L-1) |
| #520 | 2026-10-27 10:49 | lca | grün | grün | lca review 2026-10-27 11:41: D-23 answer to uxa L-1 (work notice headings) |
| #521 | 2026-10-27 10:58 | po | grün | grün | po 2026-10-27 11:45: interRAI references, D-36 licence scope, Clinical Owner bri |
| #522 | 2026-10-27 11:05 | ux | grün | grün | uxa 2026-10-27 11:49: lca answer to L-1 recorded; design system v3 |
| #524 | 2026-10-27 11:17 | po | grün | abgebrochen (nicht nachgewiesen) | po 2026-10-27 12:05: concrete recommendations on D-11, D-12, D-2 |
| #525 | 2026-10-27 11:25 | docs | grün | grün | eng 2026-10-27 12:25: COND2 delivered (#502 merged, CI green) |
| #527 | 2026-10-27 11:49 | lca | grün | grün | lca review 2026-10-27 12:42: D-11 [Z1], D-12 C fallback, D-36 interRAI licence |
| #528 | 2026-10-27 12:09 | po | grün | grün | po 2026-10-27 13:00: strategic direction, alignment review, D-37, role proposals |
| #530 | 2026-10-27 12:24 | po | grün | grün | po 2026-10-27 13:30: owner decisions; roles aia and csa integrated |
| #531 | 2026-10-27 12:36 | po | grün | grün | po 2026-10-27 13:45: challenge duty for aia and csa |
| #534 | 2026-10-27 12:47 | po | grün | grün | po 2026-10-27 13:35: COND2 accepted; AIG1, ASM1, PLAN3 approved; D-36 awaiting o |
| #541 | 2026-10-27 12:56 | csa | grün | abgebrochen (nicht nachgewiesen) | csa review 2026-10-27 13:55: strategic fit notes, roadmap, business model, bench |
| #542 | 2026-10-27 13:04 | lca | grün | grün | lca review 2026-10-27 13:52: D-37 interRAI foundation, D-12 sunset and transfer, |
| #533 | 2026-10-27 13:53 | po | grün | grün | po 2026-10-27 13:50 + 14:45: aia bottleneck verdicts; STR-14 frozen packages and |
| #546 | 2026-10-27 14:34 | po | grün | grün | po 2026-10-27 15:20: AUT-1 answered (AIG1-5 scoped by field class), PLAN3 amende |
| #547 | 2026-10-27 14:55 | lca | grün | grün | lca 2026-10-27 15:48: D-38 legal section (T5, T6 route, T9) |
| #549 | 2026-10-27 15:18 | ux | grün | abgebrochen (nicht nachgewiesen) | uxa 2026-10-27 15:50: UX1 PR #535 reviewed (UXR-10 to UXR-12); cra C-1 to C-4 re |
| #550 | 2026-10-27 15:35 | docs | grün | grün | eng 2026-10-27 16:22: UX1 in-progress (#535 merged e68ba84) |
| #552 | 2026-10-27 15:50 | po | grün | grün | po 2026-10-27 16:25: UXR-10 into UX1 (c), UXR-3 placed, D-38 lca in |
| #532 | 2026-10-27 16:33 | gov | grün | **rot** | cra review 2026-10-27 13:37: COND2 gate clear (CGR-71/73/74 closed); CGR-75, CGR |
| #555 | 2026-10-27 16:53 | gov | grün | grün | cra review 2026-10-27 17:35: UX1 part 1 no finding; CGR-78 (AIG1-5 schedule clas |
| #556 | 2026-10-27 17:21 | lca | grün | grün | lca review 2026-10-27 18:05: D-12, D-16, D-38 |
| #557 | 2026-10-27 17:55 | po | grün | grün | po 2026-10-27 18:10: cra 17:35 taken in (#543 closed, UX1 part (g), D-38 T12) |
| #559 | 2026-10-27 18:27 | po | grün | grün | po 2026-10-27 19:10: lca 18:05 taken in (D-38 T1-T13, D-16 CIRS, D-12 R-11) |
| #561 | 2026-10-27 18:58 | ux | grün | grün | uxa review 2026-10-27 19:51: UX1 (c) #554 and (f) #558; UXR-13 to UXR-17; design |
| #560 | 2026-10-27 19:12 | lca | grün | grün | lca 2026-10-27 19:50: D-38 re-check (T11 KLV; C needs cantonal Leistungsauftrag  |
| #562 | 2026-10-27 19:25 | po | grün | grün | po cycle 2026-10-27 20:15: UX1-25/-26, D-38 to the owner (T1-T14), D-37 Engineer |
| #544 | 2026-10-27 19:41 | aia | grün | grün | aia reviews 2026-10-27 14:48 + 20:30: bottleneck map v1, AUT-1 to AUT-12 (AUT-1, |
| #563 | 2026-10-27 19:57 | lca | grün | grün | lca review 2026-10-27 20:48: D-38 re-check (T2, T4, T14; AUT-10/11/12) |
| #564 | 2026-10-27 20:23 | po | grün | grün | po 2026-10-27 21:15: ASM1-11 (AUT-2); D-38 terms amended (lca 20:48); P-24 |
| #565 | 2026-10-27 20:39 | gov | grün | grün | cra review 2026-10-27 21:30: #554 gate clear (CGR-80); ASM1-11 sum (CGR-81, bloc |
| #566 | 2026-10-27 20:47 | lca | grün | grün | lca review 2026-10-27 21:45: D-38 T13 (e)/(f) and T12 (i) window end |
| #567 | 2026-10-27 21:20 | docs | grün | grün | eng 22:12: UX1 part 2 merged (#554), status in-progress; CGR-80 to part (d) |
| #568 | 2026-10-27 21:32 | po | grün | grün | po 2026-10-27 22:15: ASM1-11 no sum (CGR-81); UX1-27 (CGR-80); D-38 T12/T13 (CGR |
| #570 | 2026-10-27 22:25 | docs | grün | grün | eng 2026-10-27 23:25: UX1 status after #558 merged |
| #572 | 2026-10-27 22:57 | ux | grün | **rot** | uxa review 2026-10-27 23:49: UX1 (c)/(f) merged; UXR-18, UXR-19 |
| #571 | 2026-10-27 23:13 | lca | grün | grün | lca review 2026-10-27 23:41: D-38 re-check (po 22:15 amendments) |
| #573 | 2026-10-27 23:21 | po | grün | grün | po cycle 2026-10-28 00:15: UX1-28/-29 (UXR-18/-19), UXR-17, D-38 T12 (i) (b) and |
| #576 | 2026-10-28 00:19 | po | grün | grün | po cycle 2026-10-28 01:10: D-38 lca 00:45 re-check taken in; D-38 frozen |
| #577 | 2026-10-28 00:38 | gov | grün | **rot** | cra review 2026-10-28 01:30: #574 meets CGR-80; CGR-82/-83 closed; CGR-81 in bri |
| #575 | 2026-10-28 00:48 | lca | grün | grün | lca review 2026-10-28 00:45: D-38 re-check |
| #578 | 2026-10-28 01:19 | po | grün | grün | po cycle 2026-10-28 02:10: UX1-28 (d)/(e); ASM1-1 period storage (CGR-84) |
| #579 | 2026-10-28 01:38 | aia | grün | grün | aia review 2026-10-28 02:20: AUT-2/-10/-11/-12 closed; AUT-13 (ASM1 transcriptio |
| #580 | 2026-10-28 03:02 | ux | grün | **rot** | uxa review 2026-10-28 03:50: #574 reviewed; UXR-20, UXR-21 (low); design system  |
| #581 | 2026-10-28 03:23 | po | grün | grün | po cycle 2026-10-28 04:10: UXR-20 → UX1-30; UXR-21 → UX2-10 |
| #583 | 2026-10-28 05:19 | po | grün | **rot** | po cycle 2026-10-28 06:10: UX1-30 conditions (cra 05:30); UX2-11 |
| #584 | 2026-10-28 06:32 | docs | grün | grün | UX1 status: #574 merged (UX1-18, UX1-27); UX1 stays in-progress |
| #586 | 2026-10-28 06:58 | ux | grün | grün | uxa 2026-10-28 07:50: #574 merged; UXR-15, UXR-2 closed; design system v8 |
| #587 | 2026-10-28 07:27 | aia | grün | grün | aia review 2026-10-28 08:20: AUT-13 import conditions; no new finding |
| #590 | 2026-10-28 09:19 | po | grün | grün | po cycle 2026-10-28 10:10: CGR-85 placed as UX1-31; no delivery to review |
| #591 | 2026-10-28 09:33 | docs | grün | grün | UX1 status: #588 merged (566dc8b); UX1 stays in-progress |
| #595 | 2026-10-28 09:56 | csa | grün | grün | csa 2026-10-28 10:47: owner instructions; freeze implementation (STR-17); D-38 g |
| #596 | 2026-10-28 10:25 | po | grün | grün | po cycle 2026-10-28 11:10: STR-17 adopted, COORD6 approved, D-38 reopened for T1 |
| #599 | 2026-10-28 11:00 | ux | grün | grün | uxa review 2026-10-28 11:49: #588 merged (UXR-17 to UXR-20 closed in code); #598 |
| #600 | 2026-10-28 11:09 | lca | grün | grün | lca 2026-10-28 11:55: D-38 re-analysis on STR-18 (T15-T18, T10 options, STR-17 F |
| #601 | 2026-10-28 11:24 | po | grün | **rot** | po cycle 2026-10-28 12:15: D-38 lca 11:55 taken in; STR-17 F4 in force; UXR-22 t |
| #605 | 2026-10-28 12:54 | po | grün | **rot** | po 2026-10-28 13:35: ROADMAP.md synced with the agent registers |
| #606 | 2026-10-28 13:28 | po | grün | grün | po cycle 2026-10-28 14:20: D-38 cra input taken in; CGR-86 → WORK1-C5 |
| #607 | 2026-10-28 13:44 | docs | grün | grün | eng status 2026-10-28 14:50: UX1 delivered (#598, #602 merged with green CI) |
| #608 | 2026-10-28 13:55 | aia | grün | grün | aia review 2026-10-28 14:41: from-scratch bottleneck map; AUT-14, AUT-15 |
| #610 | 2026-10-28 14:05 | lca | grün | grün | lca 2026-10-28 14:56: D-38 re-check (T15 (b), T16 safety stop, AUT-14, AUT-15) |
| #613 | 2026-10-28 14:58 | ux | grün | grün | uxa review 2026-10-28 15:48: UX1-G1 clear (no severe/high); UXR-26 to UXR-28; de |
| #611 | 2026-10-28 15:23 | po | grün | grün | po 2026-10-28 15:15: UX1 accepted with conditions; D-38 escalated to the owner |
| #615 | 2026-10-28 17:01 | lca | grün | grün | lca 2026-10-28 17:41: D-38 T16 fall-back period re-check on CGR-88 |
| #616 | 2026-10-28 17:29 | po | grün | grün | po 2026-10-28 18:15: VIS1 approved (CGR-87); UX2-16; D-38 T16 fall-back period p |
| #618 | 2026-10-28 18:57 | ux | grün | grün | uxa review 2026-10-28 19:48: VIS1-3 brief review (UXR-29, low); UXR-26 to UXR-28 |
| #619 | 2026-10-28 19:18 | docs | grün | grün | eng status 2026-10-28 20:15: COORD6 delivered (#612 merged) |
| #622 | 2026-10-28 19:26 | aia | grün | grün | aia review 2026-10-28 20:19: VIS1 reviewed (AUT-16); lca conditions on AUT-14/15 |
| #620 | 2026-10-28 19:37 | po | grün | grün | po 2026-10-28 20:15: COORD6 accepted (ADR-110); VIS1 Next up 1 with VIS1-3a (UXR |
| #629 | 2026-10-28 21:10 | ux | grün | grün | uxa review 2026-10-28 22:00: VIS1 PR #624 reviewed; UXR-30 (high, #626) to UXR-3 |
| #630 | 2026-10-28 21:26 | docs | grün | abgebrochen (nicht nachgewiesen) | VIS1 delivered: status row and journal (#624 merged) |
| #625 | 2026-10-28 21:27 | po | grün | grün | po cycle 2026-10-28 22:00/22:15: VIS1-8 (CGR-89), VIS1-3c (UXR-30), VIS1-3d/-3e, |
| #632 | 2026-10-28 23:19 | po | grün | grün | po cycles 2026-10-28 23:15 and 2026-10-29 00:15: VIS1 changes-requested; VIS1-3f |
| #640 | 2026-10-29 01:22 | po | grün | grün | po cycle 2026-10-29 02:15: VIS1-10 placed from #638; challenge row |
| #627 | 2026-10-29 01:34 | aia | grün | grün | aia reviews 7 + 8 (2026-10-28 22:00, 2026-10-29 02:45): AUT-16 closed; AUT-17, A |
| #641 | 2026-10-29 02:19 | po | grün | grün | po cycle 2026-10-29 03:10: AUT-18 into VIS1-10; AUT-19 as VIS1-11 / UX2-17; P-30 |
| #634 | 2026-10-29 02:58 | ux | grün | grün | uxa reviews 2026-10-28 23:50 and 2026-10-29 03:51: UXR-29 closed; #633 builds UX |
| #642 | 2026-10-29 03:19 | po | grün | abgebrochen (nicht nachgewiesen) | po cycle 2026-10-29 04:10: VIS1-10 wording/focus (UXR-39); VIS1-11 label "Überne |
| #643 | 2026-10-29 03:33 | docs | grün | grün | VIS1 delivered: #633 merged (35b5a96), CI green on d6239ed; #637 merged |
| #645 | 2026-10-29 04:19 | po | grün | **rot** | po cycle 2026-10-29 05:15: VIS1 re-review, changes-requested for VIS1-10 only; P |
| #648 | 2026-10-29 04:50 | lca | grün | **rot** | lca review 2026-10-29 05:42: D-37 re-check (KLV Art. 8/8a reassessment; cra cond |
| #651 | 2026-10-29 05:23 | po | grün | grün | po cycle 2026-10-29 06:10: ADM2 ADR-114 OPEN points answered; VIS1-10 first; e2e |
| #658 | 2026-10-29 07:21 | docs | grün | grün | VIS1 stays in-review: #655 and #653 merged; #655 merged before the cra VIS1-7 ga |
| #659 | 2026-10-29 07:33 | po | grün | grün | po cycle 2026-10-29 08:15: VIS1-10 met; acceptance waits for cra gate on #655; A |
| #661 | 2026-10-29 08:20 | po | grün | grün | po cycle 2026-10-29 09:10: no delivery; aia AUT-20 adopted into P-30 |
| #664 | 2026-10-29 09:22 | po | grün | grün | po cycle 2026-10-29 10:15: VIS1 accepted; ADM2-16 from CGR-92 |
| #663 | 2026-10-29 09:48 | lca | grün | grün | lca review 2026-10-29 09:45: D-29 re-check on CGR-92 |
| #657 | 2026-10-29 11:00 | ux | grün | grün | uxa review 2026-10-29 07:50 + 11:53: UXR-42 (high, #656) → ADM2-15 (c) built in  |
| #665 | 2026-10-29 11:35 | po | grün | grün | po cycle 2026-10-29 12:15: UXR-43/-44/-45/-46 → UX2-22 to UX2-25 (UX2-22, -23 G- |
| #667 | 2026-10-29 13:06 | lca | grün | grün | lca review 2026-10-29 13:57: D-15 re-check on CGR-93 (authorship of record entri |
| #668 | 2026-10-29 13:40 | docs | grün | grün | eng 2026-10-29 14:35: ADM2 delivered (#647 merged after the cra gate, CI green) |
| #670 | 2026-10-29 13:57 | po | grün | grün | po cycle 2026-10-29 14:35: ADM2 accepted (ADM2-C1); OBS1 approved from CGR-93 an |
| #660 | 2026-10-29 14:10 | aia | grün | grün | aia reviews 2026-10-29 08:25 and 14:55: AUT-18 closed; AUT-20 (P-30); AUT-21 (on |
| #672 | 2026-10-29 15:01 | po | grün | grün | po cycle 2026-10-29 15:40: aia AUT-21 placed as UX2-26; hypothesis P-33 |
| #674 | 2026-10-29 15:14 | lca | grün | grün | lca review 2026-10-29 16:05: D-23 re-check on OBS1 (#673) |
| #675 | 2026-10-29 15:22 | ux | grün | grün | uxa review 2026-10-29 16:10: UXR-42 closed; OBS1 #673 wording (UXR-47, UXR-48);  |
| #678 | 2026-10-29 15:36 | po | grün | grün | po cycle 2026-10-29 16:24: OBS1-7 from lca D-23 re-check (not escalated); uxa an |
| #677 | 2026-10-29 15:46 | po | grün | grün | po 2026-10-29 17:00: owner D-1 precaution recorded; no real client data until cl |
| #679 | 2026-10-29 16:16 | lca | grün | grün | lca 2026-10-29 17:00: D-1 facts dossier for question (b) |
| #681 | 2026-10-29 17:32 | po | grün | grün | po 2026-10-29 18:12: D-1 lca facts dossier taken in; ask gains review date and k |
| #682 | 2026-10-29 17:48 | lca | grün | **rot** | lca 2026-10-29 18:40: D-1 re-check on CGR-94 (live-project migrations; marker ga |
| #683 | 2026-10-29 18:34 | po | grün | grün | po 2026-10-29 19:40: OBS1 accepted with conditions OBS1-C1, OBS1-C2; D-1 default |
| #687 | 2026-10-29 19:29 | aia | grün | **rot** | aia review 2026-10-29 20:20: AUT-22 (high, AIG1 confirmer read per value only);  |
| #690 | 2026-10-29 20:24 | po | grün | grün | po 2026-10-29 21:15: AUT-22 adopted as AIG1-11 before build start |
| #689 | 2026-10-29 20:52 | lca | grün | grün | lca review 2026-10-29 20:40 + 21:45: D-35 term 9 for AIG1 (AUT-22); D-35 CGR-95  |
| #692 | 2026-10-29 21:22 | po | grün | abgebrochen (nicht nachgewiesen) | po 2026-10-29 22:10: CGR-95 adopted as AIG1-12 before build; lca D-32 taken in a |
| #694 | 2026-10-29 21:30 | docs | grün | **rot** | eng 22:25: OBS1-C1 + ADM2-C1 delivered (#688 merged); CGR-96 tracked in #693 |
| #695 | 2026-10-29 22:17 | aia | grün | grün | aia 2026-10-29 23:15: review 12; AUT-23 (AIG1-12 look-back exit); AUT-22 adopted |
| #698 | 2026-10-29 22:30 | po | grün | grün | po 2026-10-29 23:15: OBS1-C1, ADM2-C1 met; RLS4, VIS2 approved; AIG1-13; CGR-96  |
| #703 | 2026-10-29 23:14 | docs | grün | abgebrochen (nicht nachgewiesen) | eng 2026-10-30 00:10: AIG1 part (a) delivered (#701 merged) |
| #685 | 2026-10-29 23:17 | ux | grün | grün | uxa review 2026-10-29 19:50 + 23:10 + 23:55: UXR-47 closed; OBS1-C2 wording; UXR |
| #702 | 2026-10-29 23:28 | lca | grün | abgebrochen (nicht nachgewiesen) | lca 2026-10-29 23:50: D-18 CGR-97 overlapping visits; D-35 AIG1-13 and PR #701 l |
| #704 | 2026-10-29 23:33 | po | grün | grün | po 2026-10-30 00:15: AIG1 part (a) reviewed; AIG1-14, VIS2-5, PLAN3-10 before bu |
| #706 | 2026-10-29 23:49 | lca | grün | grün | lca 2026-10-30 00:40: D-35 re-check on AIG1-14 and PLAN3-10 |
| #709 | 2026-10-30 00:24 | docs | grün | grün | eng: VIS2 delivered (#707 merged, CI green) |
| #708 | 2026-10-30 00:51 | po | grün | grün | po 2026-10-30 01:45: VIS2 reviewed (criteria met, acceptance after cra gate); lc |
| #713 | 2026-10-30 01:22 | po | grün | grün | po 2026-10-30 02:10: VIS2 accepted (VIS2-C1 from CGR-99); AIG1-15/-16 from CGR-9 |
| #714 | 2026-10-30 01:36 | aia | grün | grün | aia review 13 (2026-10-30 02:18): AIG1 part (a) §8 readiness, AUT-22 closed; AUT |
| #712 | 2026-10-30 01:54 | lca | grün | grün | lca 2026-10-30 01:50 + 02:45: D-35 (CGR-98, CGR-100), D-18 (CGR-99), D-23 (RLS4  |
| #716 | 2026-10-30 02:20 | po | grün | grün | po 03:10: RLS4 amended after lca 02:45 (RLS4-5, RLS4-6, AUT-24 addendum); PLAN3- |
| #717 | 2026-10-30 02:59 | ux | grün | grün | uxa 2026-10-30 03:50: VIS2 as built, UXR-50 closed, UXR-51 (medium), VIS2-C1 cou |
| #718 | 2026-10-30 03:24 | po | grün | grün | po 04:10: VIS2-C2 (uxa UXR-51), VIS2-C1 (2) wording, UX2-28/-29 |
| #719 | 2026-10-30 03:56 | lca | grün | grün | lca 2026-10-30 04:47: D-18 VIS2-C2 overlap count; D-23 RLS4-5/-6 (#715) |
| #720 | 2026-10-30 04:22 | po | grün | abgebrochen (nicht nachgewiesen) | po 05:10: VIS2-C3 direction (overlap inference path, before G-23); RLS4-5 (c) ch |
| #725 | 2026-10-30 04:54 | lca | grün | **rot** | lca 2026-10-30 05:55: D-3 VIS2-C3 (a) narrows only; D-23 note closed; D-1 CGR-10 |
| #726 | 2026-10-30 05:25 | po | grün | grün | po cycle 2026-10-30 06:10: RLS4 accepted (RLS4-C1 from CGR-101); G-25; VIS2-C3 ( |
| #728 | 2026-10-30 05:53 | lca | grün | **rot** | lca 2026-10-30 06:41: D-23 LEAVE1 open-work readers (ADR-122 deviation 4) |
| #729 | 2026-10-30 06:28 | po | grün | grün | po 2026-10-30 07:20: RLS4-C2 (LEAVE1 admin open-report list end-only), G-19 (k) |
| #730 | 2026-10-30 07:09 | ux | grün | grün | uxa 2026-10-30 07:50: ASM1 #727 read (UXR-54..59), VIS2-C2/-C3 wording, design s |
| #731 | 2026-10-30 07:21 | po | grün | grün | po 2026-10-30 08:15: ASM1-C1..C3 from uxa 07:50 (UXR-59, -55, -54); UX2-30; VIS2 |
| #733 | 2026-10-30 07:39 | aia | grün | grün | aia 2026-10-30 08:25: review 14; AUT-26 (high, #732), AUT-27 (medium); AUT-24 cl |
| #734 | 2026-10-30 07:51 | lca | grün | grün | lca review 2026-10-30 08:42: D-4 item (6), D-3 save step (docs only) |
| #735 | 2026-10-30 08:23 | po | grün | abgebrochen (nicht nachgewiesen) | po 2026-10-30 09:15: ASM1-C4 (AUT-26), AUT-27 in RLS4-C1, lca 08:42 on D-4/D-3 |
| #736 | 2026-10-30 08:36 | docs | grün | grün | ASM1 delivered (#727 merged) |
| #739 | 2026-10-30 09:04 | lca | grün | grün | lca review 2026-10-30 09:40: D-13 (CGR-102, CGR-103, ASM1-C4), D-1 (AUT-27) |
| #740 | 2026-10-30 09:23 | po | grün | grün | po 2026-10-30 10:15: ASM1 reviewed, changes-requested (ASM1-C5, ASM1-C6); D-13 t |
| #744 | 2026-10-30 09:51 | docs | grün | grün | UX2 part 1 merged (#742): status in-progress, journal |
| #743 | 2026-10-30 10:05 | lca | grün | **rot** | lca 2026-10-30 10:45: D-13 ASM1-C6 voider set compliant on sources read (cantona |
| #746 | 2026-10-30 10:22 | po | grün | grün | po 2026-10-30 11:10: ADR-124 deviation 1 answered; lca 10:45 on D-13 taken in; c |
| #749 | 2026-10-30 11:00 | ux | grün | grün | uxa 2026-10-30 11:55: ASM1-C1..C5 read (UXR-60 high #748, UXR-61..64); UXR-43, - |
| #750 | 2026-10-30 11:21 | po | grün | grün | po 2026-10-30 12:14: UXR-60 placed as ASM1-C4 (d); UXR-61..64 in UX2-30; challen |
| #751 | 2026-10-30 11:56 | lca | grün | grün | lca 2026-10-30 12:50: D-13 ASM1-C6 display (uxa 11:55) compliant on sources read |
| #752 | 2026-10-30 12:40 | po | grün | **rot** | po 2026-10-30 13:28: lca 12:50 on D-13 taken in (ASM1-C6), D-4 item (7) question |
| #754 | 2026-10-30 12:52 | lca | grün | grün | lca 2026-10-30 13:42: D-13 P-37 preset void reason compliant on sources read |
| #755 | 2026-10-30 14:07 | po | grün | **rot** | po 2026-10-30 15:00: CGR-104 as ASM1-C6 (8); lca 13:42 on P-37 taken in; P-36 wi |
| #756 | 2026-10-30 14:22 | aia | grün | grün | aia 2026-10-30 15:04: review 15, AUT-26 met in code on #747, AUT-28 (low), P-37  |
| #757 | 2026-10-30 14:38 | docs | grün | grün | eng: ASM1 delivered (#747 merged as 752ecbc) |
| #760 | 2026-10-30 15:00 | po | grün | grün | po 2026-10-30 15:55: ASM1 accepted (#747); WORK1-C5 to Active now (0); P-38 |
| #759 | 2026-10-30 15:15 | ux | grün | grün | uxa review 2026-10-30 15:50: #747 merged read; UXR-60 closed in code; UXR-65 (lo |
| #762 | 2026-10-30 15:54 | docs | grün | **rot** | eng: WORK1 delivered (#761 merged; WORK1-C5 (a), (c) in, (b) OPEN) |
| #763 | 2026-10-30 16:15 | po | grün | grün | po 2026-10-30 16:55: WORK1-C5 reviewed; (b) in watch mode |
| #765 | 2026-10-30 16:36 | docs | grün | grün | CGR-96: #764 merged; VIS1 row note, journal |
| #767 | 2026-10-30 16:51 | po | grün | **rot** | po 2026-10-30 17:45: CGR-96 test fix reviewed; AIG1 part (b) to Active now (0) |
| #768 | 2026-10-30 18:04 | lca | grün | **rot** | lca 2026-10-30 17:45: D-13 ASM1-C6 (8) and P-37 presentation |
| #771 | 2026-10-30 18:20 | docs | grün | grün | AIG1 delivered: #770 merged (part (b), database half; UI half PLANNED) |
| #773 | 2026-10-30 19:01 | lca | grün | grün | lca 2026-10-30 19:45: D-35 AIG1-15/-16 as built compliant on sources read; close |
| #769 | 2026-10-30 19:25 | po | grün | grün | po 2026-10-30 18:25 + 20:25: CGR-96 back to (0); P-37 in force; AIG1 part (b) da |
| #775 | 2026-10-30 19:37 | aia | grün | **rot** | aia review 16 (2026-10-30 20:18): AUT-29 (high, #774); AUT-26 closed; AUT-28 ado |
| #778 | 2026-10-30 19:59 | docs | grün | **rot** | AIG1 delivered: #776 merged (part (b) UI half; part (b) complete) |
| #780 | 2026-10-30 20:24 | po | grün | grün | po 2026-10-30 21:25: AIG1 part (b) UI reviewed; AUT-29 adopted into AIG1-C1; PLA |
| #777 | 2026-10-30 20:49 | lca | grün | grün | lca review 2026-10-30 20:41 + 21:45: D-13 addendum compliant; D-35 AIG1-C1, AUT- |
| #783 | 2026-10-30 21:23 | po | grün | grün | po 2026-10-30 22:15: AIG1 accepted; CGR-105 adopted as AIG1-C2 |
| #784 | 2026-10-30 23:06 | lca | grün | grün | lca review 2026-10-30 23:40: D-35 AIG1-C2 (CGR-105) compliant as written; past-v |
| #786 | 2026-10-30 23:21 | po | grün | grün | po 2026-10-31 00:10: CGR-96 second fix reviewed; AIG1-C1/-C2 wording; AIG1-C3; P |
| #785 | 2026-10-30 23:46 | ux | grün | grün | uxa review 2026-10-30 23:55: AIG1 part (b) UI; UXR-49 closed; UXR-66 to -71; AIG |
| #789 | 2026-10-31 00:43 | docs | grün | grün | AIG1-C1/-C2/-C3 delivered (#787 merged as c6f038b): status row and journal |
| #790 | 2026-10-31 01:12 | lca | grün | grün | lca review 2026-10-31 01:40: D-35 AIG1-C1/-C2/-C3 as merged (#787) compliant on  |
| #794 | 2026-10-31 01:30 | aia | grün | grün | aia review 17 2026-10-31 02:40: AUT-29, AUT-23 closed; AUT-30 (high, #793); AUT- |
| #791 | 2026-10-31 01:41 | po | grün | grün | po cycle 2026-10-31 02:25: AIG1-C1/-C2/-C3 met (#787); AIG1-C4 (CGR-107, CGR-106 |
| #795 | 2026-10-31 02:20 | docs | grün | grün | RLS4: #792 merged, status delivered (READY_FOR_REVIEW) |
| #797 | 2026-10-31 02:51 | lca | grün | grün | lca review 2026-10-31 03:50: D-1 RLS4-C1, D-23 RLS4-C2 as built (#792) |
| #802 | 2026-11-03 01:30 | aia | grün | grün | aia review 18 2026-11-03 02:40: bottleneck map v2; AUT-27 closed; AUT-32 (medium |
| #805 | 2026-11-03 03:52 | lca | grün | grün | lca review 2026-11-03 04:45: D-1 re-check on CGR-109 |
| #808 | 2026-11-03 05:28 | po | grün | grün | po cycle 2026-11-03 06:30: RLS4-C1/-C2 met; RLS4-C3; CGR-108/-109 into UX2; UX2- |
| #811 | 2026-11-03 07:29 | aia | grün | grün | aia review 19 2026-11-03 08:20: AN3 supported; AUT-33 (medium), AUT-34, AUT-35 ( |
| #798 | 2026-11-03 11:00 | ux | grün | grün | uxa reviews 2026-10-31 03:50, 2026-11-03 03:52, 07:52 and 11:50: AIG1/RLS4 UI as |
| #821 | 2026-11-03 12:46 | csa | grün | grün | csa review 2026-11-03 13:33: STR-20 to STR-25 (Basel, all-in-one, IoT/AI, interR |
| #823 | 2026-11-03 13:02 | lca | grün | grün | lca review 2026-11-03 13:55: Basel-Stadt checks for D-2, D-4, D-9, D-29 |
| #822 | 2026-11-03 13:17 | po | grün | grün | AI-first architecture update + human-in-the-loop directive (owner 2026-11-03): h |
| #829 | 2026-11-03 13:35 | aia | grün | grün | aia review 2026-11-03 14:40: AI-first update reviewed; AUT-36 to AUT-39; AUT-32  |
| #832 | 2026-11-03 13:46 | po | grün | grün | Delivery program M1-M10 (owner Executive Delivery Directive 2026-11-03) |
| #834 | 2026-11-03 14:29 | ux | grün | **rot** | uxa 2026-11-03 15:00: design system for M2-M8 (information architecture, screen  |
| #836 | 2026-11-03 14:38 | po | grün | grün | po 2026-11-03 15:30: UX/UI baseline adopted (PR #834); Delivery Program dependen |
| #839 | 2026-11-03 19:01 | ux | grün | grün | uxa review 2026-11-03 15:50 and 19:55: #814, #815, #841, #799; UXR-84 to UXR-90; |
| #844 | 2026-11-03 19:36 | aia | grün | grün | aia review 2026-11-03 20:30: Delivery Program and UX baseline reviewed; AUT-40 ( |
| #846 | 2026-11-03 21:16 | po | grün | grün | po cycle 2026-11-03 22:00: AUT-40 decided (no C-15 assistant screen at stage 0); |
| #847 | 2026-11-03 23:07 | ux | grün | grün | uxa review 2026-11-03 23:50: answers to cra 21:30 (CGR-113, UXR-89, offline word |
| #849 | 2026-11-04 01:29 | aia | grün | grün | aia review 2026-11-04 02:20: AUT-40 closed; AUT-41 (offline visit times through  |
| #851 | 2026-11-04 04:08 | lca | grün | grün | lca review 2026-11-04 05:20: D-34 detailed AI assessment (owner directive); D-39 |
| #853 | 2026-11-04 05:16 | po | grün | grün | po cycle 2026-11-04 06:10: D-39, D-40 escalated (approve A each); D-34 AI assess |
| #854 | 2026-11-04 07:27 | aia | grün | grün | aia review 2026-11-04 08:18: AUT-41 target behind gate; AUT-42, AUT-43 |
| #856 | 2026-11-04 11:53 | po | grün | grün | po 2026-11-04 12:45: owner decisions D-39 (A) and D-40 (minimal read-only relati |
| #858 | 2026-11-04 13:48 | aia | grün | grün | aia review 2026-11-04 14:20: FAM1 supported; AUT-44, AUT-45 (medium); AUT-39 clo |
| #863 | 2026-11-04 19:30 | aia | grün | grün | aia review 2026-11-04 20:20: AUT-44/-45 gate inputs; AUT-46, AUT-47 (low) |
| #866 | 2026-11-05 01:29 | aia | grün | grün | aia review 2026-11-05 02:25: AUT-46 form confirmed; AUT-48 (merge hand-off, #861 |
| #868 | 2026-11-05 10:26 | po | grün | grün | po 2026-11-05: #861 owner decision (option C rejected) and PO merge process prop |
| #833 | 2026-11-05 10:57 | feature | grün | kein Lauf (nicht nachgewiesen) | docs: IMPLEMENTATION_SEQUENCE.md for M2-M8: build order, API and database depend |
| #838 | 2026-11-05 10:57 | feature | grün | grün | D-2: production hosting decision support: Supabase readiness, backups/PITR/DR, m |
| #871 | 2026-11-05 11:16 | po | grün | grün | po 2026-11-05 12:00: PO merge authority in force; #799, #833, #838 merged; post- |
| #874 | 2026-11-05 15:32 | po | grün | grün | po 2026-11-05 14:50: scheduled merge refused; PLAN3-14 (CGR-136) |
| #877 | 2026-11-05 15:43 | po | grün | grün | po 2026-11-05 16:30: #874 merged in a scheduled run; merge order within a run |
| #845 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-03 21:30: #799 gate clear; CGR-113/UXR-84/UXR-88/-89/AN3-5 in |
| #878 | 2026-11-05 16:44 | gov | kein Lauf (nicht nachgewiesen) | kein Lauf (nicht nachgewiesen) | cra review 2026-11-05 17:00: #876 PLAN3-14 gate clear, CGR-136 met on head; CGR- |
| #696 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 23:10: #688 merged as read; CGR-95 as AIG1-12; CGR-96 root |
| #807 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-03 05:30: #803, #804 no finding; UX2-20 confirmed; CGR-110, C |
| #639 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 01:30: CGR-87 closed (#624 merged); #633 VIS1-7 gate clear |
| #875 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-05 15:00: CGR-136 remedy in brief (PLAN3-14); AUT-51 conditio |
| #859 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-11-04 16:45: uxa FAM1 wordings confirmed; CGR-128 (verschoben de |
| #865 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-05 01:30: uxa 23:50 CGR-131/-132/AUT-46 confirmed; CGR-133 (n |
| #812 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-03 09:30: #806, #809, #810 no finding; CGR-110 met on #810; C |
| #604 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-28 13:40: CGR-85 closed; #598/#602 clinical gate clear; D-38  |
| #848 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-04 01:30: CGR-122 (blocking for ADR-143 / M6-2, late-sent off |
| #753 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-30 13:30: #747 clear to merge (CGR-102 met); CGR-104 (S2, bas |
| #737 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-30 09:30: ASM1 #727 read; CGR-81, CGR-84 closed; CGR-102, CGR |
| #782 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-30 21:40: AIG1 part (b) no blocking finding; CGR-98, CGR-100, |
| #589 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-28 09:30: CGR-80 closed; #588 clinical gate clear; CGR-85 (ad |
| #628 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-10-28 22:00: VIS1 #624 gate clear; CGR-90 (advisory S2, direct s |
| #879 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-11-05 17:30: #876 and #800 base merges checked, gates carried to |
| #623 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-10-28 21:30: VIS1 read; VIS1-3b reason prefill not confirmed; CG |
| #873 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-11-05 13:30: #872 PLAN3 (a) gate clear; CGR-136 (overlap scope,  |
| #662 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 09:25: VIS1 gate clear, CGR-91 closed (#655); ADM2 #647 CG |
| #867 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-11-05 05:30: CGR-133 met at document level; CGR-132 both pairs;  |
| #711 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-30 01:45: CGR-97 closed (VIS2 #707); AIG1 part (a) #701 read; |
| #801 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-03 01:30: CGR-105, CGR-101 closed; #799 gate clear; #800 CGR- |
| #864 | 2026-11-05 16:44 | gov | grün | grün | cra review 2026-11-04 21:30: uxa 19:50 FAM1 wordings confirmed; AUT-46/-47 suppo |
| #855 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-04 09:30: CGR-123 met at document level; CGR-124 (advisory S2 |
| #582 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-28 05:30: #574 still clear; CGR-84 in brief; UX1-30 confirmed |
| #852 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-04 05:30: CGR-122 met at document level; CGR-123 (blocking fo |
| #614 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-28 17:30: CGR-87 (S1 before pilot, visit date not checked on  |
| #857 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-04 13:30: FAM1 reviewed: CGR-125 (blocking for FAM1 approval, |
| #862 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-04 17:30: lca #860 read; FAM1 pilot variants supported; CGR-1 |
| #766 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-30 17:35: CGR-102, CGR-96 closed; P-37 confirmed with one con |
| #723 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-30 05:30: RLS4 #715 gate clear; CGR-101 (advisory S2, legacy  |
| #819 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-03 13:30: #815, #814, #813, #800 no blocking finding; seven r |
| #666 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 13:40: ADM2 #647 gate clear to merge (CGR-92 met in 0094); |
| #842 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-03 17:30: #841, #828 no blocking finding; CGR-112 met on #841 |
| #691 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 21:30: CGR-93 closed (#673 merged); #688 gate clear (OBS1- |
| #646 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 05:30: CGR-89, CGR-90 closed; CGR-91 (blocking for VIS1 ac |
| #788 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-31 01:30: #787 no blocking finding; CGR-105 and AIG1-C1 met o |
| #870 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-05 09:30: CGR-134 sentence 5 met at document level; option C  |
| #680 | 2026-11-05 16:44 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-10-29 17:30: CGR-92, CGR-72 closed (#647 merged); OBS1 #673 meet |
| #869 | 2026-11-05 19:29 | aia | grün | grün | aia review 2026-11-05 08:20 … 20:20: AUT-49, AUT-50, AUT-51; AUT-48 closed; PLAN |
| #889 | 2026-11-06 01:27 | aia | grün | grün | aia review 2026-11-06 02:15: PLAN3 stack; AUT-25 met on #886; CGR-140 (a); AUT-5 |
| #893 | 2026-11-06 07:16 | po | grün | grün | po cycle 2026-11-06 06:30: PLAN3 decisions (PLAN3-15 to -17, PLAN3-7/-9 amended) |
| #898 | 2026-11-06 07:54 | po | grün | grün | po 2026-11-06 08:40: Architecture Review and Implementation Blueprint V2 (execut |
| #900 | 2026-11-06 08:13 | po | grün | grün | po 2026-11-06 09:05: Founder Executive Report (owner's primary decision document |
| #904 | 2026-11-06 11:08 | po | grün | grün | po 2026-11-06 12:00: founder direction confirmed; D-11, D-1, D-24 decided by the |
| #908 | 2026-11-06 12:16 | po | grün | grün | po 2026-11-06 12:30: Phase A = home care + simulated nursing-home ward; lca comm |
| #896 | 2026-11-06 13:44 | aia | grün | grün | aia reviews 2026-11-06 08:25 + 14:40: AUT-51 met on #897, AUT-52 met on #894, AU |
| #913 | 2026-11-06 13:59 | po | grün | grün | po 2026-11-06 14:45: FE-033 to FE-036; merge test run passed (#800); SR-26 decid |
| #914 | 2026-11-06 14:49 | po | grün | grün | po 2026-11-06 15:30: founder cleanup FE-037, issue matrix and PR map |
| #892 | 2026-11-06 15:09 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-06 05:30: CGR-139 met on #888 + #891, CGR-140 met on #890; PL |
| #901 | 2026-11-06 15:09 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-06 09:30: #894, #895, #897 gates clear; CGR-138 met on #895;  |
| #887 | 2026-11-06 15:09 | gov | grün | kein Lauf (nicht nachgewiesen) | cra review 2026-11-06 01:30: PLAN3 stack #882-#886 gates clear; CGR-139 (S2), CG |
| #911 | 2026-11-06 15:09 | gov | grün | **rot** | cra review 2026-11-06 13:30: CGR-75 met on #902; #903, #906 gates clear; CGR-142 |
| #881 | 2026-11-06 15:09 | gov | grün | grün | cra review 2026-11-05 21:30: #880 gate clear after #876; CGR-138 (advisory S3);  |
| #915 | 2026-11-06 17:53 | gov | grün | grün | cra review 2026-11-06 17:30: #910 gate clear, CGR-137 narrowed, CGR-144, CGR-108 |
| #916 | 2026-11-06 18:24 | po | grün | grün | po cycle 2026-11-06 18:39: #828 and #915 merged; RLS4-C3, AIG1-C4/C5 accepted; B |
| #860 | 2026-11-06 19:41 | lca | grün | abgebrochen (nicht nachgewiesen) | lca review 2026-11-04 16:55 … 2026-11-06 16:10: D-40 / FAM1; D-35 PLAN3-14; D-22 |
| #899 | 2026-11-06 19:41 | csa | grün | abgebrochen (nicht nachgewiesen) | csa 2026-11-06 08:57: execution tracking (STRATEGY §9), brand decision KEEP NAVO |
| #918 | 2026-11-06 19:42 | aia | grün | **rot** | aia review 2026-11-06 20:20: governance layer on recovery/main; AUT-59, AUT-60 |
| #917 | 2026-11-06 19:58 | po | grün | grün | po cycles 2026-11-06 19:39 + 20:39: AIR1 accepted; #841 AN3 and role PRs merged; |
| #850 | 2026-11-06 20:15 | ux | grün | abgebrochen (nicht nachgewiesen) | uxa review 2026-11-04 03:50 … 2026-11-06 19:50: offline wording, FAM1 page, PLAN |
| #921 | 2026-11-06 20:18 | gov | grün | grün | cra review 2026-11-06 21:10: #919 answered, CGR-137 corrected, three findings cl |
| #923 | 2026-11-06 21:05 | gov | grün | grün | cra review 2026-11-06 21:30 + 21:50: CGR-110 remainder met on #922; qualificatio |
| #920 | 2026-11-06 21:15 | po | grün | grün | po 2026-11-06 21:10 + 21:55: founder decisions FE-038 and FE-039 (qualification  |
| #929 | 2026-11-06 21:40 | gov | grün | grün | cra 2026-11-06 22:35: Qualification and Activity Matrix v0.2 (founder letter); C |
| #930 | 2026-11-06 21:54 | po | grün | grün | po 2026-11-06 22:30: FE-040 business models and constellations, economics, matri |
| #933 | 2026-11-06 22:31 | po | grün | grün | po 2026-11-06 23:10: FE-041 PLAN3 stack as one consolidation PR (one cra gate, o |
| #938 | 2026-11-07 00:58 | po | grün | grün | po 2026-11-07 00:39 + 01:39: D-22, D-18 Basel take-in; #934 merged, PLAN3 accept |
| #941 | 2026-11-07 01:42 | aia | grün | grün | aia review 2026-11-07 02:20: PLAN3 closes AUT-25/-30/-31/-51/-52; QUAL1: AUT-61  |
| #942 | 2026-11-07 01:56 | po | grün | grün | po 2026-11-07 02:45: #941 merged; #939 waits for cra gate; QUAL1-20 (AUT-61); Bl |
| #936 | 2026-11-07 03:40 | ux | grün | grün | uxa review 2026-11-06 23:50 + 2026-11-07 03:50: #934 check, UXR-129 to -133 (#93 |
| #946 | 2026-11-07 03:51 | po | grün | grün | po cycle 2026-11-07 04:39: #936 merged; QUAL1-21 (UXR-129 to -133); Blueprint v2 |
| #947 | 2026-11-07 04:41 | lca | grün | grün | lca review 2026-11-07 04:56: D-43, D-44, D-42 legal sections |
| #948 | 2026-11-07 04:55 | po | grün | grün | po cycle 2026-11-07 05:39: #947 merged; D-43, D-42, D-44 escalated; Blueprint v2 |
| #949 | 2026-11-07 06:02 | po | grün | grün | po cycle 2026-11-07 06:39: #939 merged (QUAL1 part 1), part 1 reviewed; Blueprin |
| #952 | 2026-11-07 07:06 | po | grün | grün | po cycle 2026-11-07 07:39: #945 merged incl. #943 (QUAL1 part 2 slices 1+2); rev |
| #951 | 2026-11-07 07:40 | ux | grün | grün | uxa review 2026-11-07 07:50: UXR-132 closed in code; UXR-134 (high, #950), UXR-1 |
| #955 | 2026-11-07 07:56 | po | grün | grün | po cycle 2026-11-07 08:39: #951 merged; #953 waits for cra gate; QUAL1 findings  |
| #937 | 2026-11-07 08:41 | gov | grün | grün | cra review 2026-11-07 00:10 + 01:35 + 05:45 + 09:25: #934, #939, #945 clear (mer |
| #956 | 2026-11-07 09:01 | po | grün | grün | po cycle 2026-11-07 09:39: #953 and #937 merged; QUAL1 slice 3 reviewed; CGR-155 |
| #954 | 2026-11-07 09:45 | aia | grün | abgebrochen (nicht nachgewiesen) | aia review 2026-11-07 08:20: QUAL1 read; AUT-67, AUT-68 |
| #957 | 2026-11-07 09:50 | po | grün | grün | po 2026-11-07 10:40: FE-042 (owner): structured milestone work; cra research for |
| #958 | 2026-11-07 10:07 | po | grün | grün | po cycle 2026-11-07 10:39 |
| #835 | 2026-11-07 11:42 | feature | grün | grün | M1 (#830): DELIVERY_ESTIMATE.md v1 — pilot and production readiness, app deliver |
| #959 | 2026-11-07 11:56 | ux | grün | grün | uxa review 2026-11-07 11:50 + proposal 12:10: QUAL1-21 merged; UXR-137, -138; UX |
| #963 | 2026-11-07 12:08 | po | grün | grün | po cycle 2026-11-07 12:39: #835 merged (M1.3), MERGE1 approved, COORD-7 points 1 |
| #961 | 2026-11-07 12:41 | feature | grün | grün | docs: MERGE1 proposed (Blueprint M2.0 merge mechanics), COORD-7 for po (#960) |
| #967 | 2026-11-07 12:57 | po | grün | **rot** | po cycle 2026-11-07 13:39: #961 merged, #837 held (UXR-94), NH-A1 brief approved |
| #837 | 2026-11-07 13:40 | feature | grün | grün | docs: WEB1 and APP1 implementation plans on the uxa design set (#834); ADR-142,  |
| #965 | 2026-11-07 14:01 | gov | grün | grün | cra review 2026-11-07 13:25: FE-042 templates D-43, D-22; CGR-156, CGR-157; #815 |
| #970 | 2026-11-07 14:11 | aia | grün | grün | aia review 2026-11-07 14:20: NH-A1 and MERGE1 reviewed; AUT-69 (high, #969), AUT |
| #972 | 2026-11-07 14:23 | po | grün | grün | po cycle 2026-11-07 14:39: #837 merged, M1.4 accepted (M1 75 %); NH-A1 amended ( |
| #974 | 2026-11-07 16:49 | ux | grün | grün | uxa review 2026-11-07 15:50: NH-A1 gate line, UXR-139 to -142 |
| #975 | 2026-11-07 16:59 | gov | grün | grün | cra review 2026-11-07 17:29: NH-A1 gate line (condition CGR-158 (1)); CGR-158, C |
| #973 | 2026-11-07 17:11 | po | grün | grün | po 2026-11-07 15:39: owner answers FE-045 to FE-051; CI2 and SEC1 approved; Blue |


## 4. Offene PRs

| PR | Branch | Block | Stand | Abnahmestatus |
|---|---|---|---|---|
| #907 | `feature/weekly-status-2026-W45` | G | Doku (Wochenstatus Engineering); `dirty` | nicht gemergt; Merge-Freeze (FE-052) betrifft es als Doku nicht, wartet auf Merge-up durch `eng` |
| #971 | `feature/hourly-update-2026-11-07-owner-production-readiness` | B0/B11 | Doku (Owner-Antworten Produktionsreife, Quelle von FE-045 bis FE-051); `dirty` | nicht gemergt; Inhalt bereits in FE-045 bis FE-051 übernommen |
| #978 | `po/founder-reorg-2026-11-07-1840` | G | diese Neuordnung (FE-052) | offen |
| #3 | `recovery/main` → `main` | B0 | Zusammenführung nach `main` (D-8 B entschieden, Ruleset ausstehend) | offen; erzeugt bei jedem Merge den zweiten CI-Lauf |

## 5. Issues (alle, je Issue)

Klassifizierung automatisch aus Status, Labels und den letzten drei Kommentaren: *geschlossen: PR/Commit und Test genannt* · *geschlossen: PR genannt, kein Testbeleg* · *geschlossen: kein Beleg im Issue* (= **nicht nachgewiesen**) · *überholt (begründet)* · *offen* · *Entscheid offen* · *blockiert*. „Testbeleg genannt“ heisst, der Schlusskommentar nennt einen Test oder CI-Lauf; ob er die Anforderung auf dem integrierten Stand prüft, ist für die Blockabnahme erneut zu belegen.

| Status | Anzahl |
|---|---|
| geschlossen: kein Beleg im Issue | 95 |
| geschlossen: PR/Commit und Test genannt | 78 |
| Entscheid offen | 30 |
| geschlossen: PR genannt, kein Testbeleg | 20 |
| offen | 17 |
| überholt (begründet) | 15 |
| blockiert | 1 |

### 5.1 Offen, Entscheid offen, blockiert

| Issue | Block | Art | Status | geschlossen | Titel |
|---|---|---|---|---|---|
| #64 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-2: Staging and production hosting provider and region |
| #67 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-7: Branch protection, secret scanning, repository visibility (public → pri |
| #68 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-8: Merge `recovery/main` into `main` |
| #70 | B0 | Entscheid | Entscheid offen | – | [Decision legal] D-4: Audit log retention and access |
| #71 | B0 | Entscheid | Entscheid offen | – | [Decision legal] D-9: Legal basis for processing client data at intake (consent vs. care mandat |
| #80 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-18: Billing time rules in the applicable tariff contract (time units and r |
| #104 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-22: What form of medical order and order renewal is valid for OKP billing  |
| #116 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-25: What do the pilot canton's licensing rules require of nursing-home lea |
| #151 | B0 | Entscheid | Entscheid offen | – | [Decision owner] D-29: CGR-16: how is a member's qualification verified before it is active (re |
| #157 | B0 | Entscheid | Entscheid offen | – | [Decision clinical] D-30: CGR-19 (with `legal`): who may correct a visit report, and sign that  |
| #170 | B0 | Entscheid | Entscheid offen | – | [Decision clinical] D-31: CGR-20 (with `legal`): how is a visit documented and billed that was  |
| #523 | B0 | Entscheid | Entscheid offen | – | [Decision legal] D-36: Does NAVORA's interRAI licence permit using the licensed material for pr |
| #529 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-37: Should NAVORA designate interRAI HC as its clinical foundation for car |
| #545 | B0 | Entscheid | Entscheid offen | – | [Decision owner] D-38: Which transfer terms must the partnership letter of intent contain so th |
| #824 | B0 | Arbeit | offen | – | [Engineering] Owner directive 2026-11-03: enforce AI restrictions in code and architecture; D-3 |
| #905 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-41: Approved NAVORA AI path for real data: when and how may client or staf |
| #909 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-42: Phase B pilot agreement with a nursing home: minimum content of the co |
| #925 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-43: Mandate for clinical rule approval (named professional, review board o |
| #932 | B0 | Entscheid | Entscheid offen | – | [Decision package] D-44: Contract, legal form and billing path per order constellation (KON-1 t |
| #964 | B0 | Arbeit | blockiert | – | [Engineering] Implement MERGE1 Merge mechanics without shared-file conflicts: journal entry, AD |
| #966 | B0 | Entscheid | Entscheid offen | – | [Decision po] COORD-7: Engineering proposal (issue #960, owner request 2026-11-07): (1) place M |
| #976 | B0 | Arbeit | offen | – | [Engineering] Implement CI2 CI minutes fit a private repository without weakening any required  |
| #977 | B0 | Arbeit | offen | – | [Engineering] Implement SEC1 Continuous adversarial testing of staging (red team on synthetic d |
| #61 | B1 | Entscheid | Entscheid offen | – | [Decision clinical] D-15: Approve the J1 readiness checklist, the J3 care-plan fields and the m |
| #66 | B1 | Entscheid | Entscheid offen | – | [Decision clinical] D-17: Which safety alerts must a nurse see before the first visit (e.g. all |
| #81 | B1 | Entscheid | Entscheid offen | – | [Decision clinical] D-19: What must a nurse do on site when a client does not open the door (C1 |
| #926 | B12 | Entscheid | Entscheid offen | – | FE-040: contract, legal form and billing path per order constellation (D-44, L-7 to L-11) and t |
| #676 | B2 | Entscheid | Entscheid offen | – | [Decision owner] D-26: ADM1 invitations: may the app server hold the Supabase service-role key  |
| #924 | B2 | Entscheid | Entscheid offen | – | FE-039: Qualification and Activity Matrix (QAM) and package D-43 (clinical rule-approval mandat |
| #927 | B2 | Arbeit | offen | – | FE-040: matrix use on every assignment path (QUAL1), expired/contradictory evidence defaults, c |
| #928 | B2 | Arbeit | offen | – | QUAL1 (approved, synthetic only): qualification profile and activity rule on every assignment p |
| #940 | B2 | Automation | offen | – | AUT-61 (high): QUAL1 stores a visit's activities per visit, so a team would tag every visit of  |
| #944 | B2 | UX | offen | – | UX: QUAL1 refusals (qualification_not_allowed/_lapsed) shown as "konnte nicht …" or a wrong cau |
| #950 | B2 | UX | offen | – | UX: QUAL1 "lapsed" refusal shows "Nicht begonnen … bleibt geplant" on Losfahren and Fortsetzen  |
| #65 | B3 | Entscheid | Entscheid offen | – | [Decision owner] D-3: Permission matrix: read scope of health data per role |
| #60 | B4 | Entscheid | Entscheid offen | – | [Decision owner] D-14: Platform fee and team surplus model |
| #150 | B4 | Entscheid | Entscheid offen | – | [Decision clinical] D-28: CSR1 / CGR-04: when must NAVORA raise an exception for a planned visi |
| #603 | B4 | Arbeit | offen | – | [Engineering] pgTAP 079 WORK1-5 catalogue (test 44) red on recovery/main since about 12:25 CET: |
| #654 | B4 | Arbeit | offen | – | [Engineering] Coordination: a PO re-review that keeps `changes-requested` reopens `[PO review]` |
| #508 | B5 | UX | offen | – | UX S1: internal decision and brief codes shown to users (D-11, D-18, SIG1-8, F1–F4 …) |
| #56 | B6 | Entscheid | Entscheid offen | – | [Decision clinical] D-10: Must a registered nurse countersign visit reports when a care assista |
| #912 | B6 | Automation | offen | – | AUT-54 (high): DOC-AI as framed re-drafts a report NAVORA already builds from the recorded fact |
| #62 | B7 | Entscheid | Entscheid offen | – | [Decision clinical] D-16: Quality event types, severities, which ones set a quality hold, and w |
| #968 | B9 | Arbeit | offen | – | [Engineering] Implement NH-A1 Ward and 24-hour shift model on the shared team records (simulate |
| #510 | G | UX | offen | – | UX S1: two app shells and two design languages (nurse screens vs. legacy MVP sidebar) |
| #539 | G | Strategie | offen | – | [Strategy] STR-15: write the C-transfer terms before the partner's letter of intent (proposed o |
| #820 | G | Strategie | offen | – | [Strategy] STR-20 to STR-25: Basel, all-in-one and IoT directions need the open gates first (pr |
| #830 | G | Arbeit | offen | – | [Engineering] M1 delivery baseline: implementation sequence, effort, pilot and production readi |

### 5.2 Geschlossen

| Issue | Block | Art | Status | geschlossen | Titel |
|---|---|---|---|---|---|
| #47 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] F0 Shared access foundation for the care journey is delivered |
| #53 | B0 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-22 | [Decision po] Q7: Do location features (team bases, service radius, geocoding) belong in NAVORA |
| #57 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [Decision owner] D-11: Pilot canton and municipalities |
| #58 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-10-27 | [Decision owner] D-12: Legal entity that holds the cantonal operating licence and the OKP admis |
| #59 | B0 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-24 | [Decision package] D-13: Assessment instrument: interRAI HC (home care) instead of interRAI LTC |
| #63 | B0 | Entscheid | geschlossen: kein Beleg im Issue | 2026-11-06 | [Decision owner] D-1: Live database: are the 6 cases / 3 care notes real people? Rotate the ano |
| #69 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [Decision owner] SR-26: Move or delete the foreign `orders` table (Stripe test checkouts with e |
| #72 | B0 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-24 | [Decision package] D-6: Visit assignment (team / nurse / both) and full state list (assigned, a |
| #89 | B0 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-24 | [Decision package] D-20: Who admits members to a team? D-5 gives NAVORA administrators all memb |
| #111 | B0 | Entscheid | überholt (begründet) | 2026-10-24 | [Decision package] D-23: Can the working-time record that Swiss labour law requires for employe |
| #115 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [Decision owner] D-24: Enter nursing homes (Horizon 3)? With which design-partner home, and can |
| #240 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [Engineering] Implement COORD5 Decision issues reach a person only with a package |
| #274 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [PO review] COORD5 Decision issues reach a person only with a package is delivered |
| #319 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement RLS2 Visit and case records are read only by the people who care for th |
| #337 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement LEAVE1 Access ends when employment ends |
| #351 | B0 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-25 | [Decision po] Q13: RLS2 inventory findings (READ_PATHS.md F-1 to F-5, PR #331): should coordina |
| #355 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement RLS3 Coordination roles and teammates read no more than their task need |
| #376 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement FUP1 Follow-ups of SIGC and RLS3: the outside-hours list counts the pla |
| #379 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [PO review] RLS3 Coordination roles and teammates read no more than their task needs is deliver |
| #382 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Implement AUD1 Administrators read the audit log only for a stated purpose, witho |
| #387 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-25 | [PO review] FUP1 Follow-ups of SIGC and RLS3: the outside-hours list counts the planned length, |
| #404 | B0 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-25 | [Engineering] Implement LEAVE1 Access ends when employment ends |
| #411 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-26 | [PO review] LEAVE1 Access ends when employment ends is delivered |
| #418 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Address PO changes for LEAVE1 Access ends when employment ends |
| #422 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [PO review] AUD1 Administrators read the audit log only for a stated purpose, without the team' |
| #430 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [PO review] LEAVE1 Access ends when employment ends is delivered |
| #442 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-26 | [Engineering] Implement COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with D |
| #448 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Implement COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with D |
| #455 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Implement COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with D |
| #456 | B0 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-27 | [Engineering] Implement IPA1 Intended-purpose alignment of the as-built texts: no "Risiko" or " |
| #460 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-10-26 | [Decision package] D-35: AI services: may client or staff data reach an AI service, and on what |
| #463 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-26 | [Engineering] Implement COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with D |
| #468 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Implement COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with D |
| #476 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Implement COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with D |
| #482 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-26 | [PO review] COND1 Pre-pilot conditions under one hand-off (LEAVE1-C2/-C3/-C4 with DOOR1-12/-13/ |
| #489 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-27 | [PO review] IPA1 Intended-purpose alignment of the as-built texts: no "Risiko" or "überwacht" w |
| #491 | B0 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-27 | [Engineering] Implement COND2 Pre-pilot conditions under one hand-off: COND1-C1 (unexported-day |
| #498 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-27 | [Engineering] Implement COND2 Pre-pilot conditions under one hand-off: COND1-C1 (unexported-day |
| #515 | B0 | UX | geschlossen: PR/Commit und Test genannt | 2026-11-06 | UX: sign-in page unusable on a phone and addressed to admins and coaches only (UXR-1) |
| #516 | B0 | UX | geschlossen: PR/Commit und Test genannt | 2026-10-28 | UX: secondary text below WCAG AA contrast on nurse and team screens (UXR-2) |
| #526 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-27 | [PO review] COND2 Pre-pilot conditions under one hand-off: COND1-C1 (unexported-days count only |
| #597 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-28 | [Engineering] Implement COORD6 Frozen packages stay frozen without anyone watching: `agents-che |
| #621 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-28 | [PO review] COORD6 Frozen packages stay frozen without anyone watching: `agents-check` requires |
| #635 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-29 | CI: e2e suite fails on runs late in the Zurich evening and across midnight (clock-dependent tes |
| #700 | B0 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-30 | [Engineering] Implement RLS4 Who did what is read per record, never listed per person; who is r |
| #724 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [PO review] RLS4 Who did what is read per record, never listed per person; who is responsible s |
| #826 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-11-04 | [Decision owner] D-39: Sensors in a client's home (IoT inbound) and sensor-based AI risk predic |
| #827 | B0 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-11-04 | [Decision owner] D-40: Client- and relative-facing AI (Family Companion Layer, Check-In Service |
| #843 | B0 | Automation | geschlossen: PR/Commit und Test genannt | 2026-11-03 | AUT-40 (high): the M6 caregiver "Assistent" (C-15) answers only what the start screen already s |
| #884 | B0 | UX | geschlossen: PR/Commit und Test genannt | 2026-11-07 | UX: day-plan picker and member cards cannot tell unnamed members apart (UXR-102) |
| #919 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-07 | pgTAP 080 (COND1/LEAVE1-C2 signal delivery) failed in one of two CI runs on the same recovery/m |
| #935 | B0 | UX | geschlossen: PR/Commit und Test genannt | 2026-11-07 | UX: one qualification rule, four refusal texts on four paths; "darf nicht" on an unverified val |
| #960 | B0 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-07 | [Engineering proposal] COORD-7: build efficiently toward M9: remove the shared-file conflicts f |
| #48 | B1 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] J2 Team decision workflow is delivered |
| #51 | B1 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] J6 Continuity of care: primary nurse is delivered |
| #54 | B1 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-10-22 | [Decision po] Q8: Team response time per referral type and decline-reason list for J2 |
| #73 | B1 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-22 | [Decision po] Q10: What counts as working time for J2 response deadlines ("4 working hours", "1 |
| #77 | B1 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-22 | [Engineering] Implement C1 Case and visit lifecycle: pause, close, reopen, cancel, no-show |
| #93 | B1 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] C1 Case and visit lifecycle: pause, close, reopen, cancel, no-show is delivered |
| #103 | B1 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-22 | [Engineering] Implement RET1 Returning client returns to her team |
| #108 | B1 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [Engineering] Address PO changes for C1 Case and visit lifecycle |
| #123 | B1 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] C1 Case and visit lifecycle is delivered |
| #131 | B1 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] RET1 Returning client returns to her team is delivered |
| #143 | B1 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [Engineering] Address PO changes for C1 Case and visit lifecycle |
| #163 | B1 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-23 | [PO review] C1 Case and visit lifecycle is delivered |
| #79 | B10 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-22 | [Engineering] Implement AN1 Pilot impact dashboard with the direct-care-share North Star |
| #100 | B10 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] AN1 Pilot impact dashboard with the direct-care-share North Star is delivered |
| #110 | B10 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [Engineering] Address PO changes for AN1 Pilot impact dashboard |
| #127 | B10 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] AN1 Pilot impact dashboard is delivered |
| #205 | B10 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [Engineering] Implement AN2 Pilot hypotheses measured from events, not tallied |
| #265 | B10 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [PO review] AN2 Pilot hypotheses measured from events, not tallied is delivered |
| #825 | B10 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [Engineering] Implement AN3 Where the non-care time goes: per-step spans per team and month fro |
| #78 | B2 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-22 | [Engineering] Implement ADM1 Pilot administration: members, qualifications, operating rules |
| #132 | B2 | Entscheid | geschlossen: PR genannt, kein Testbeleg | 2026-10-29 | [Decision owner] D-26: ADM1 invitations: may the app server hold the Supabase service-role key  |
| #133 | B2 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [Engineering] Address PO changes for ADM1 Pilot administration: members, qualifications, operat |
| #160 | B2 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [PO review] ADM1 Pilot administration: members, qualifications, operating rules is delivered |
| #262 | B2 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [Engineering] Address PO changes for ADM1 Pilot administration: members, qualifications, operat |
| #270 | B2 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [PO review] ADM1 Pilot administration: members, qualifications, operating rules is delivered |
| #499 | B2 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-29 | [Engineering] Implement ADM2 The team admits its colleagues by consent; the employer records "V |
| #656 | B2 | UX | geschlossen: kein Beleg im Issue | 2026-10-29 | UX: ADM2 'Bezugspflege neu bestimmen' names the case only by a Fall-Ref. that no case card show |
| #669 | B2 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-29 | [PO review] ADM2 The team admits its colleagues by consent; the employer records "Vertrag erfas |
| #671 | B2 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-29 | [Engineering] Implement OBS1 Every observation shows who wrote it in the handover and in the si |
| #684 | B2 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-29 | [PO review] OBS1 Every observation shows who wrote it in the handover and in the signed report, |
| #931 | B2 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-11-07 | [Engineering] Implement QUAL1 Qualification profile and activity rule (matrix E/D/–/?, evidence |
| #49 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] OPS1 Operations exception center is delivered |
| #55 | B3 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-10-22 | [Decision po] Q9: Thresholds and urgency for Operations exceptions (OPS1) |
| #85 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [Engineering] Implement PLAN2 Self-planning: visits follow the care plan |
| #88 | B3 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-22 | [Engineering] Implement COVER1 Cross-team cover without a dispatcher |
| #95 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] PLAN2 Self-planning: visits follow the care plan is delivered |
| #96 | B3 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-22 | [Decision po] D-21: Confirm the engineering defaults: PLAN2 spreads a weekly rhythm evenly when |
| #106 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [Engineering] Address PO changes for COVER1 Cross-team cover without a dispatcher |
| #107 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [Engineering] Address PO changes for PLAN2 Self-planning: visits follow the care plan |
| #119 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] COVER1 Cross-team cover without a dispatcher is delivered |
| #121 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] PLAN2 Self-planning: visits follow the care plan is delivered |
| #134 | B3 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-23 | [Engineering] Implement ABS1 Absence without the phone chain: "I can't work" hands the day to t |
| #142 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for J3 Visit planning with billable basis |
| #144 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for OPS1 Operations exception center |
| #168 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [PO review] OPS1 Operations exception center is delivered |
| #181 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [PO review] OPS1 Operations exception center is delivered |
| #197 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [PO review] ABS1 Absence without the phone chain: "I can't work" hands the day to the team is d |
| #199 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for ABS1 Absence without the phone chain: "I can't work" hands |
| #208 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [PO review] ABS1 Absence without the phone chain: "I can't work" hands the day to the team is d |
| #214 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [PO review] ABS1 Absence without the phone chain: "I can't work" hands the day to the team is d |
| #219 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [PO review] ABS1 Absence without the phone chain: "I can't work" hands the day to the team is d |
| #299 | B3 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-27 | [Decision owner] D-34: Is NAVORA a medical device under the Swiss MepV? Its intended purpose, a |
| #409 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-06 | e2e field.spec ABS1-C6, CGR-32, CGR-34 red on a docs-only PR at 23:12 CET (clock-dependent?) |
| #536 | B3 | Arbeit | überholt (begründet) | 2026-10-29 | [Engineering] Implement AIG1 AI governance foundation: every proposal is recorded in an append- |
| #538 | B3 | Arbeit | überholt (begründet) | 2026-11-06 | [Engineering] Implement PLAN3 Day-plan and continuity proposal: for one day the team gets a pro |
| #543 | B3 | Automation | geschlossen: PR/Commit und Test genannt | 2026-10-27 | [Automation] AUT-1: AIG1-5's "every field one by one" default turns PLAN3's day plan into one c |
| #686 | B3 | Automation | geschlossen: PR/Commit und Test genannt | 2026-10-29 | [Automation] AUT-22: AIG1 has no criterion that keeps the per-value confirmer out of direct tab |
| #699 | B3 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-30 | [Engineering] Implement VIS2 A second visit of the same client at an overlapping time is shown  |
| #705 | B3 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-30 | [PO review] AIG1 AI governance foundation: every proposal is recorded in an append-only ledger, |
| #710 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [PO review] VIS2 A second visit of the same client at an overlapping time is shown as a fact be |
| #772 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [PO review] AIG1 AI governance foundation: every proposal is recorded in an append-only ledger, |
| #774 | B3 | Automation | geschlossen: PR/Commit und Test genannt | 2026-10-31 | AUT-29 (high): under AIG1-C1 a look-back line of a past visit can never leave "offen", so a sto |
| #779 | B3 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [PO review] AIG1 AI governance foundation: every proposal is recorded in an append-only ledger, |
| #793 | B3 | Automation | geschlossen: PR/Commit und Test genannt | 2026-11-07 | AUT-30 (high): a stop's look-back is tied to the agent's state, so switching a stopped assistan |
| #145 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for F1-F4 Verified visit (field tool slice) |
| #149 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [Engineering] Implement CSR1 Clinical safety remediation: no visit looks safe when it is not; s |
| #173 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [PO review] F1-F4 Verified visit (field tool slice) is delivered |
| #327 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement DOOR1 What the nurse needs at the door |
| #393 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement DOOR1 What the nurse needs at the door |
| #398 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [PO review] DOOR1 What the nurse needs at the door is delivered |
| #412 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [Engineering] Implement WORK1 The working day is proposed from the visits; the nurse confirms i |
| #437 | B4 | Arbeit | überholt (begründet) | 2026-10-26 | [Engineering] Implement – *empty (2026-10-26 07:15 CET): WORK1 moved to the queue, rank 35; the |
| #444 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-26 | [PO review] WORK1 The working day is proposed from the visits; the nurse confirms it instead of |
| #512 | B4 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-27 | [Engineering] Implement UX1 The nurse's phone shows her next visit first, one clear action per  |
| #513 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-30 | [Engineering] Implement UX2 One NAVORA app on phone and desktop: one shell, one navigation, one |
| #553 | B4 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-27 | [Engineering] Implement UX1 The nurse's phone shows her next visit first, one clear action per  |
| #569 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-28 | [Engineering] Implement UX1 The nurse's phone shows her next visit first, one clear action per  |
| #585 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-28 | [Engineering] Implement UX1 The nurse's phone shows her next visit first, one clear action per  |
| #592 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-28 | [Engineering] Implement UX1 The nurse's phone shows her next visit first, one clear action per  |
| #609 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-28 | [PO review] UX1 The nurse's phone shows her next visit first, one clear action per card, a menu |
| #617 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-28 | [Engineering] Implement VIS1 Field actions happen on the visit's day: depart, start, no-show an |
| #626 | B4 | UX | geschlossen: PR/Commit und Test genannt | 2026-10-29 | UXR-30: "Heute machen" (VIS1-3b) prefills the planned start time, so a visit moved to today lat |
| #631 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-28 | [PO review] VIS1 Field actions happen on the visit's day: depart, start, no-show and "not compl |
| #636 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-29 | [Engineering] Address PO changes for VIS1 Field actions happen on the visit's day: depart, star |
| #638 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-29 | /field fixes "today" at render: "Heute machen" after midnight moves the visit to yesterday |
| #644 | B4 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-29 | [PO review] VIS1 Field actions happen on the visit's day: depart, start, no-show and "not compl |
| #649 | B4 | Arbeit | überholt (begründet) | 2026-10-29 | [PO review] VIS1 Field actions happen on the visit's day: depart, start, no-show and "not compl |
| #650 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-29 | [Engineering] e2e red on recovery/main: vis1.spec.ts:150 matches Testfall 08's planned list by  |
| #652 | B4 | Arbeit | überholt (begründet) | 2026-10-29 | [PO review] VIS1 Field actions happen on the visit's day: depart, start, no-show and "not compl |
| #693 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-06 | CGR-96: vis1.spec.ts:41 showed two /field cards for one moved visit (root cause UNKNOWN) |
| #745 | B4 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-05 | [Engineering] Implement UX2 One NAVORA app on phone and desktop: one shell, one navigation, one |
| #246 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [Engineering] Implement SIG1 Safety signals reach a person, nobody watches a screen |
| #248 | B5 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [Decision po] D-32: CGR-37 / SIG1: may a P1 visit safety signal be delivered outside the app (w |
| #275 | B5 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-26 | [Decision owner] D-33: CGR-37 / SIG2: may the fixed P1 safety-signal push also go to Safari (ma |
| #283 | B5 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [Engineering] Implement SIG2 Safety signals reach the nurse's phone, so nobody has to keep a pa |
| #285 | B5 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [PO review] SIG1 Safety signals reach a person, nobody watches a screen is delivered |
| #292 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [PO review] ORD0 The doctor link that must not get lost: conditions ORD0-C1, ORD0-C2, with SIG1 |
| #298 | B5 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [PO review] SIG2 Safety signals reach the nurse's phone, so nobody has to keep a page open is d |
| #314 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [PO review] ORD0 The doctor link that must not get lost: conditions ORD0-C1, ORD0-C2, with SIG1 |
| #317 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [PO review] SIG2 Safety signals reach the nurse's phone, so nobody has to keep a page open is d |
| #326 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #329 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #333 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #334 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #336 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #339 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #343 | B5 | Arbeit | überholt (begründet) | 2026-10-25 | [Engineering] Implement SIG1-C2, SIG1-C3, SIG2-C1 Signal conditions: the qualified response is  |
| #344 | B5 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-25 | [Engineering] Implement DST1 Safety alerts are on time on the nights the clock changes |
| #345 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Implement SIGC Signal conditions SIG1-C2, SIG1-C3, SIG2-C1: the qualified respons |
| #357 | B5 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-25 | [PO review] DST1 Safety alerts are on time on the nights the clock changes is delivered |
| #360 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [Engineering] Address PO changes for DST1 Safety alerts are on time on the nights the clock cha |
| #365 | B5 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-25 | [Decision po] Q14: SIGC / SIG2-C1 (2): "planned visits whose interval lies outside every watche |
| #367 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [PO review] SIGC Signal conditions SIG1-C2, SIG1-C3, SIG2-C1: the qualified response is what AN |
| #370 | B5 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-25 | [PO review] DST1 Safety alerts are on time on the nights the clock changes is delivered |
| #399 | B5 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-11-07 | [Engineering] pgTAP 062 (SIG1 delivery) failed on a docs-only PR: tests 47 and 50 look clock-de |
| #548 | B5 | UX | geschlossen: PR/Commit und Test genannt | 2026-11-06 | UX: a nurse cannot reach push opt-in (/settings) from /field, /team or /work (UXR-10) |
| #86 | B6 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-22 | [Engineering] Implement F7 Sign at completion |
| #98 | B6 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] F7 Sign at completion is delivered |
| #102 | B6 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-22 | [Engineering] Implement HAND1 Handover without the team meeting: "since you were last here" |
| #109 | B6 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [Engineering] Address PO changes for F7 Sign at completion |
| #125 | B6 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-22 | [PO review] F7 Sign at completion is delivered |
| #130 | B6 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] HAND1 Handover without the team meeting: "since you were last here" is delivered |
| #146 | B6 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for F6 Signed visit report |
| #147 | B6 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for F7 Sign at completion |
| #177 | B6 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [PO review] F7 Sign at completion is delivered |
| #190 | B6 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [PO review] F6 Signed visit report is delivered |
| #309 | B6 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-24 | [Engineering] Implement F6R Return a report instead of countersigning a version known to be wro |
| #328 | B6 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-24 | [PO review] F6R Return a report instead of countersigning a version known to be wrong is delive |
| #50 | B7 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] QG1 Quality signals and quality hold is delivered |
| #247 | B7 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-24 | [Engineering] Implement ORD0 The doctor link that must not get lost (GP informed, order without |
| #288 | B7 | Entscheid | geschlossen: kein Beleg im Issue | 2026-10-24 | [Decision po] Q12: ORD0-2: after the team recorded "Hausärztin/Hausarzt informiert" for a case, |
| #537 | B7 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-30 | [Engineering] Implement ASM1 Assessment record (D-13 B): the needs assessment is one append-onl |
| #732 | B7 | Automation | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [aia AUT-26, high] ASM1: clearing "Neuere Bedarfsabklärung" needs retire-and-retype of every ca |
| #738 | B7 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [PO review] ASM1 Assessment record (D-13 B): the needs assessment is one append-only, signed re |
| #741 | B7 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-30 | [Engineering] Address PO changes for ASM1 Assessment record (D-13 B): the needs assessment is o |
| #748 | B7 | UX | geschlossen: PR/Commit und Test genannt | 2026-10-30 | [uxa UXR-60, high] /team care plan: "… geprüft" review act sits above what it attests and reads |
| #758 | B7 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-30 | [PO review] ASM1 Assessment record (D-13 B): the needs assessment is one append-only, signed re |
| #52 | B8 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-22 | [PO review] J5 Billable visit facts and monthly revenue preview is delivered |
| #74 | B8 | Entscheid | geschlossen: PR/Commit und Test genannt | 2026-10-22 | [Decision po] Q11: J5: which minutes are billed per KLV category? Actual time is measured per v |
| #76 | B8 | Arbeit | geschlossen: PR genannt, kein Testbeleg | 2026-10-22 | [Engineering] Address PO changes for J5 Billable visit facts and monthly revenue preview |
| #148 | B8 | Arbeit | geschlossen: kein Beleg im Issue | 2026-10-23 | [Engineering] Address PO changes for J5 Billable visit facts and monthly revenue preview |
| #186 | B8 | Arbeit | geschlossen: PR/Commit und Test genannt | 2026-10-23 | [PO review] J5 Billable visit facts and monthly revenue preview is delivered |
| #962 | B9 | UX | geschlossen: PR/Commit und Test genannt | 2026-11-07 | UX proposal for PO review: ward and shift screens (NH-A); owner instruction on proactive propos |
| #969 | B9 | Automation | geschlossen: PR genannt, kein Testbeleg | 2026-11-07 | AUT-69 (high): NH-A1-6 asks the ward team to confirm the continuity default every shift, and do |
| #506 | G | UX | geschlossen: PR/Commit und Test genannt | 2026-11-07 | UX S1: /settings, /admin and /operations are broken at phone width (fixed sidebar column) |
| #507 | G | UX | geschlossen: PR/Commit und Test genannt | 2026-11-06 | UX S1: navigation shows every item to every role; dead and legacy menu items |
| #509 | G | UX | geschlossen: PR/Commit und Test genannt | 2026-11-06 | UX S1: /field has no action hierarchy; next visit starts ~1,100 px down on a phone |
| #540 | G | Strategie | geschlossen: PR/Commit und Test genannt | 2026-10-27 | [Strategy] STR-14 (challenge, high): freeze packages awaiting a person; one-page owner agenda i |
| #593 | G | Strategie | geschlossen: PR genannt, kein Testbeleg | 2026-10-28 | [Strategy] STR-17: implement the package freeze for every role (owner approved STR-14, 2026-10- |
| #594 | G | Strategie | geschlossen: PR/Commit und Test genannt | 2026-10-28 | [Strategy] STR-19: write the first C transition as a reusable provider kit, so the partner rout |
| #816 | G | Strategie | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [Owner direction] D-11: pilot market Basel (Basel-Stadt and Basel-Landschaft): region configura |
| #817 | G | Strategie | überholt (begründet) | 2026-11-06 | [Owner direction] Backlog spec (draft): `iot_sensor_streams` and `ki_prediction_audit_logs`, da |
| #818 | G | Strategie | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [Owner direction] D-24/D-25: one platform for home care and nursing homes (all-in-one); Basel n |
| #831 | G | UX | geschlossen: PR/Commit und Test genannt | 2026-11-06 | [UX/UI] M1 design baseline for `uxa`: screen inventory, navigation map, component inventory, im |
| #861 | G | Arbeit | überholt (begründet) | 2026-11-07 | [Coordination] 17 green Engineering PRs wait for a PO merge the PO cannot see: `in-review` live |

