---
id: STAB1
title: Eine lesbare Quelle je Datenbankfunktion und Staging-Nachweis je Ablauf (technisches Stabilisierungspaket)
author: po
status: approved   # ACTIVE package since 2026-11-20 15:39 CET (BK-f accepted on 40a2ce1)
updated: 2026-11-20
---

# STAB1 — One readable source per database function, and staging proof per flow

**Origin:** founder message to `po` and `eng`, live PO session 2026-11-20 ca. 09:20 (FE-099 (1), (2)), answering `docs/engineering/SELF_ASSESSMENT_2026-11-20.md` (#1586). **Status:** PO contract (approved for the order below). Technical plan: `eng` proposal `docs/engineering/probes/STAB-1_PROPOSAL.md` (#1586, 09:40), written in parallel to this brief and accepted by the PO as the HOW: 25 functions of the BK chain (proposal §2), manifest of required properties (§3), source files plus a no-op migration plus drift check (§4), fingerprint, property and grant tests (§5), way back (§6). Where this brief and the proposal differ in the function list, **the proposal's 25 functions plus `may_perform_visit` and `end_member_access` from the table below** are the scope; `eng` confirms these two or says why not. **Gate:** «Simulation, synthetic data». **Place in the order:** after BK-f, before AI1 and BK-d (§Order; confirmed by the founder, FE-099 (7) (d)). PO did not run tests.

## Problem

Business logic lives mostly in PL/pgSQL. Many migrations change an existing function by text replacement on `pg_get_functiondef` (`eng` counts 45 of 151; the PO counts 73 migrations that call `pg_get_functiondef` at all, which includes checks). The valid text of such a function exists in no file. On 2026-11-20 `eng` copied `generate_billable_facts` from 0051 for BK-f and lost the LEAVE1 guard that 0074 had patched in; pgTAP 074 caught it (job 136125670120). The catalogue test catches LEAVE1, not every rule. Every further change to a much-patched function risks losing a guard silently.

Separately, flows were long proven only in CI on the local stack. On staging, exactly three paths are proven (`staging-smoke` run 44699041140, 3/3): sign-in of the three demo accounts; order → take → «Gedeckt»; night shift as one card on `/field` at 390 px. The smoke job runs only when started by hand.

## Facts read from the code by the PO (2026-11-20, `recovery/main` `269e4b5`; counts are grep results, UNKNOWN beyond them)

PO reading before the `eng` proposal arrived (kept as a cross-check; `eng` counted 60 functions with at least one text patch plus 16 in the 0074 loop). Functions the next steps touch, with where their text is today («full» = a migration with the complete `create or replace`; «patched» = later text replacements):

| Function | Needed for | Last full definition | Text patches after it | Guards at risk (PO reading, `eng` to confirm) |
|---|---|---|---|---|
| `generate_billable_facts` | BK-f (J5 skip, BKF-F1) | 0051 | 0074 | LEAVE1 access end (proven lost once, 2026-11-20) |
| `recheck_member_takes` | absence and cover (ward flow) | 0148 | 0139 (before 0148) | person lock (CGR-255), take end reason |
| `order_member_step` | ward order, BK-d | 0135 | 0136, 0138 | eligibility reading (CGR-218/219), take visit link |
| `take_order` | BK-d, ward | 0135 | 0136 | acknowledge/release |
| `record_absence`, `change_absence` | absence (ward flow) | 0048 | 0050, 0053, 0069 / 0069, 0092, 0121 | take visit untouched by absence (CGR-250), audit |
| `take_open_visit` | absence, cover | 0046 | 0092, 0118, 0121, 0142, 0145 | qualification check, refusal audit (CGR-252) |
| `plan_visit`, `reschedule_visit` | visit path, BK-g clock change | 0014 | 7 each (0050 … 0145) | take visit guard (CGR-249), audit of moves |
| `field_visits` | `/field`, AI1 | 0014 | 0031, 0138, 0139, 0140, 0149 | night shift card, LEAVE1 |
| `may_perform_visit` | every visit command | 0091 | 0092, 0121 | qualification limits (hard rule) |
| `end_member_access` | LEAVE1 | 0078 | 0080, 0083 | access end |
| `private.derived_exceptions`, `operations_exceptions`, `team_visit_alerts`, `private.handover_entries` | `/operations`, `/team` alerts | 0024 / 0080 / 0080 / 0033 | 21 / 11 / 7 / 8 | many; highest patch count, but not on the next BK path (tranche 2) |

`confirm_client_order` (BK-d) and `order_take_visit` have full definitions only (0132, 0138): no consolidation needed, listed for the drift check.

## Outcome

For every listed function there is one readable, versioned file that equals what the database runs after all migrations; CI fails when they differ; no new migration changes a listed function by text replacement. After every merge into `recovery/main`, `staging-smoke` runs against `navora-staging` and every proven path stays green.

## Scope (WHAT; HOW is `eng`'s, in an ADR)

1. **(a) Function sources, tranche 1:** the functions of the table except the four of tranche 2. One file per function under a directory `eng` chooses (for example `supabase/schema/functions/<schema>.<name>.sql`), holding the full definition including `security definer`, `search_path`, grants and revokes, generated from the database that CI builds from all migrations (not copied from an old migration file). Options for `eng`'s ADR: Supabase declarative schemas, or a CI dump-and-compare step; the PO has no preference.
2. **(b) Drift check:** a CI step in `db` that rebuilds the files from the migrated database and fails on any difference. Behaviour is unchanged by construction.
3. **(c) Change rule:** from STAB1 on, a change to a listed function is a new migration with the complete `create or replace` taken from its file, edited in the file in the same PR, so the review diff shows exactly the changed lines. A CI check refuses a new migration that calls `pg_get_functiondef`/`replace` on a listed function. Historical migrations are never rewritten.
4. **(d) Permission and audit snapshot:** a pgTAP (or catalogue) test that records, for each listed function, `prosecdef`, `proconfig` (search path), the grants to `anon`, `authenticated` and `service_role`, and that its audit or LEAVE1 calls are present; it fails if any of these changes without the file change in the same PR.
5. **(e) Staging proof per flow:** `staging-smoke` runs automatically after every push to `recovery/main` (after Render serves the merged commit, as `staging-version` already waits) and can still be started by hand; a red run notifies `po` and `eng` (issue or PR comment; no secret in any log). A package with a user flow adds its path to `staging-smoke` in its own PR; all earlier paths must stay green.
6. **Not in scope:** no new product behaviour; no change to RLS, grants, audit, a clinical, tariff or legal rule; tranche 2 (`derived_exceptions`, `operations_exceptions`, `team_visit_alerts`, `handover_entries`) only when a later package touches them, under the same rule; no rewrite of historical migrations; no removal of legacy pages (separate PO decision, §Later).

## Tests (named in the ready report per CI job)

- Positive: full `db` suite green (all 153+ pgTAP files); drift check green on the package head; the permission snapshot (d) green.
- Negative (red first, then green): (i) change one character of a listed function in a test migration without its file → drift check red; (ii) a test migration with a text patch on a listed function → change-rule check red; (iii) a revoked grant in a test migration → snapshot red. These probes may run on a probe branch and be named with run IDs; they are not merged.
- Regression: `ci-repeat` 10/10 (`db`, `e2e`, 0 skipped) on the integrated commit; `staging-smoke` green on the merge commit with all three existing paths.

## Way back

If an applied migration was needed (only if the ADR chooses re-creation from the files): it re-creates identical definitions, so the way back is the previous definition from the dump of the commit before. The checks and files themselves are removed by reverting the PR; no data change. Staging is reached only through the CI `staging` job.

## Gates

`aia`: no (no model). `cra`: no clinical content changes; the PO asks `cra` only if the snapshot (d) shows a changed guard on a clinical function. `lca`: no. `uxa`: no. Security review: the PO reads the permission snapshot in the ready report.

## Estimate

`eng` proposal 09:40: 2–3 runs including CI rounds (ESTIMATE; the self-assessment said 3–5). Measured time from start to `staging-smoke` green is recorded (scorecard criterion 14).

## Order (PO, FE-099 (3); one active package at a time)

1. **BK-f** (active) to acceptance, with its staging-smoke path (sign report → draft → send → client reads «Rechnungen»).
2. **STAB1** (this brief), because BK-d and the ward flow change exactly the much-patched functions above.
3. **AI1** (first connected model, brief `AI1.md`), after the founder decisions named there.
4. **BK-d** «Station bestellt», cut by the PO before it starts (ward as client with AI capture of the request on the AI1 gateway), then absence and cover for a ward, then **BK-g**.
Q3 to Q6 keep their places in `QUAL2.md` relative to BK-d and BK-g.

## Later (proposals, not in scope)

- Hide pages built before FE-066 (`intake`, `visits`, `work`, `analytics`, `partners`) for BK roles (`eng` self-assessment area 3); PO decides with `uxa` after STAB1.
- Separate the J5/KLV billing model from the BK model with a documented boundary (`eng` area 4).
- A short work card per package (`eng` area 9): the PO writes one for each package from STAB1 on (contract, open points, last CI state, under two pages).

## PO amendment 2026-11-20 09:39 (founder FE-100; newest founder decision, README rule 10; not a PO addition)

Second founder message (ca. 09:35, verbatim in issue #1587 comment 7034490863) sharpens this contract. Where it differs from the text above, FE-100 applies:

1. **Directory fixed by the founder:** `supabase/schema/functions/`, one readable file per function (Scope (a): no longer «a directory `eng` chooses»; the file name scheme stays `eng`'s).
2. **One consolidation migration is mandatory:** it re-creates the listed functions once, completely, with `create or replace function` from their files (Way back: the case «only if the ADR chooses re-creation» is now the rule). Behaviour, RLS and grants stay identical; the permission snapshot (d) proves it.
3. **Text patches are refused for good:** Scope (c) applies to every migration from STAB1 on, not only to listed functions. Historical migrations are still never rewritten.
4. **Proof:** the full `db` and unit suites as they stand at the STAB1 start stay green (the founder's figures 5509 / 1598 are his reading; the measure is the suite on the start commit), plus a `staging-smoke` run on the merge commit with every proven path.
5. **Founder count «25 core functions»:** matches the `eng` proposal (25 plus `may_perform_visit`, `end_member_access` to confirm). `eng` names the final list in the ADR.
6. **Direction, not STAB1 scope:** «too much logic in SQL instead of TypeScript». `eng` proposes a documented boundary database/TypeScript as an ADR after STAB1; no business logic moves in STAB1.
7. **Release:** `eng` prepares on `feature/STAB-1` now (allowed: preparation, FE-070 (5)); the PR opens and becomes *Active now* only after BK-f is merged. The order BK-f → STAB1 → AI1 → BK-d is unchanged (FE-099 (7), FE-100 (6)).

## PO review and merge 2026-11-20 17:39 (scheduled PO run, signal FE-105 (1) (a))

Ready report 7043841117 on head `27d1164c`; `eng` independent no-op check 7044492775 (0157 dump byte-identical to the 28 files). Merged as `d3b2233` (merge record 7045122276). The PO did not run tests; everything below is read from GitHub job logs.

| Criterion | Result | Evidence |
|---|---|---|
| (a) one file per function, equal to the database | met | `fn-source` in `db` 136386934504: «29 definitions in 28 files match the database»; `eng` dump comparison against 0157 |
| (b) drift check in `db` (and `ci-repeat`) | met | `.github/workflows/ci.yml`, `ci-repeat.yml` step `fn-source check`; negative probe (i) red: run 44753270244, job 136346314293 |
| (c) no text patch after the cutoff | met | `no-text-patch` in `app` 136386934355; probe (ii) red: run 44761243635, job 136374029152; cutoff 0153 accepted (0154–0157 pass) |
| (d) permission and guard snapshot | met | pgTAP 157 `plan(302)`: 29× empty `search_path`, no PUBLIC, `anon` refused; 28× `security definer`, `field_visits` invoker as before; markers `access_ended`, `begin_command`, `audit_command`, LEAVE1-C3, WORK1-C3, `has_qualification`, `is_registered_nurse`, BKF-F1; probe (iii) red (job 136346314293) |
| (e) `staging-smoke` after every push to `recovery/main` | met | first automatic run 44776130634 on `d3b2233`: «ci: go (staging job success)», «Render serves f7dfd2d…», 4/4 passed incl. path 3 |
| No behaviour change, consolidation migration only | met | 0158: only `create or replace function`, `revoke`, `grant`, `comment`; applied to `navora-staging` by `staging` job 136431540358 («Applying migration 20261021000158…»), job 136432306920 «Remote database is up to date» |
| Positive: full `db` suite green | met | `ci` 44776130676 on `d3b2233`: all jobs `success` |
| Regression: `ci-repeat` 10/10 on the integrated commit | OPEN | run 44778677226 on `f7dfd2d` started 17:5x; read in the next signal run |

**PO decisions on `eng`'s limits:** (1) STAB1-F2: `paths` filter so docs-only merges do not start `staging-smoke` (approved as a follow-up, not a condition). (2) As described, the first automatic run was on the merge commit. (3) Tranche 2 unchanged. (4) Next.js security notice: dependency package after STAB1, together with #1084, to be cut by the PO. STAB1-F1 (`db-lint --fail-on error`, #1620 §4) approved as a follow-up.

## PO acceptance 2026-11-20 ca. 18:40 (PO live session)

**Accepted for the simulation** on `f7dfd2d` (gate «Simulation, synthetic data»). Regression criterion met: `ci-repeat` 44778677226, 20/20, all 20 raw logs read (`db` «Files=157, Tests=5868», «Result: PASS», 0 `# SKIP`, `fn-source` match; `e2e` «193 passed», 0 skipped/flaky/failed; verdict 136442411189 inside the window). `staging-smoke` green on the merge commit `d3b2233` (44776130634, 4/4). Record: `ABNAHMEAKTE.md`. Known defect STAB1-F3 (a later docs-only run 44777149305 red in path 3, probably test-data collision between runs; UNKNOWN until `eng` confirms). Not an exception for HD-1 (FE-109 (C)). PO did not run tests.
