---
id: COORD6
title: Frozen packages stay frozen without anyone watching (agents-check guard, STR-17 F3)
author: po
status: accepted
updated: 2026-10-28
---

# COORD6 — Frozen packages stay frozen without anyone watching

**Approved by po 2026-10-28 11:10 CET.** Origin: `csa` STR-17 F3 (issue #593), after the owner approved STR-14 on 2026-10-28 and asked for an implementation: *"agent time is spent creating new value, not repeatedly reviewing unchanged material."*

## Problem
The freeze rule (README rule 9, `DECISION_PACKAGES.md` *Frozen packages*) exists only as text. On its first day it was broken ten times by "no new evidence" journal lines (7 `lca`, 3 `po`), and D-38 was amended in four rounds after escalation. Each re-check costs an agent run that produces nothing for a nurse, a team or a client, and each amendment re-opens a question the owner was already asked (`csa` STR-17, evidence in `docs/product/STRATEGIC_ALIGNMENT_REVIEW.md`). A rule that depends on every agent remembering it is coordination work that a check can do.

## Users and journey step
All agent roles and the owner. Not a care-journey step: it governs the decision-package process that gates the journey (Referral → … → Billing) through the owner and Clinical Owner asks.

## Outcome
A change to a frozen package that names no unfreeze trigger, or a "no new evidence" line about one, is caught by `agents-check` in CI before it is merged, so the owner's one-page agenda only changes when something real changed.

## Acceptance criteria
- [ ] **COORD6-1 (marking):** `agents-check` fails when a row in `decisions/INDEX.md` has status `awaiting-approval: <role>` and its *Package status* cell does not contain `frozen since YYYY-MM-DD HH:MM` directly after the status link. Unit test: one row with and one without the marker.
- [ ] **COORD6-2 (unfreeze line):** given a base revision (env `AGENTS_BASE_REF`, default `origin/recovery/main`), `agents-check` fails when the diff from the base changes `decisions/<ID>.md` for an `<ID>` whose INDEX status **on the base** is `awaiting-approval: <role>`, unless the change adds at least one line matching `^Unfreeze: [1-5] \S` to that file. Unit tests: (a) changed frozen package without the line → error naming the ID; (b) with the line → ok; (c) a package that is not `awaiting-approval` on the base → ok without the line; (d) a package newly escalated in the same diff (not awaiting on the base) → ok.
- [ ] **COORD6-3 (rows):** the same rule as COORD6-2 for a change to that ID's INDEX row or its `OPEN_DECISIONS.md` *Open* row: the changed row text must contain `Unfreeze: [1-5] ` (an `Unfreeze:` line in the package file in the same diff also satisfies it). Unit test for each file.
- [ ] **COORD6-4 (journal):** a `JOURNAL.md` entry added in the diff whose text contains "no new evidence" (case-insensitive) together with a package ID that is `awaiting-approval` on the base produces a **warning** until 2026-11-04 00:00 Europe/Zurich and an **error** from then on. The clock is injectable (env `AGENTS_NOW`) for the test; unit tests on both sides of the date.
- [ ] **COORD6-5 (no base):** when the base revision cannot be resolved (shallow clone, local run without the remote), COORD6-2 to COORD6-4 are skipped with one printed warning naming the reason; COORD6-1 still runs. CI fetches enough history for the base to resolve, so the checks run on every PR.
- [ ] **COORD6-6 (no false stop on decisions):** a change that moves a package out of `awaiting-approval` (to `decided`, `po-decided` or `inputs-requested`) is accepted when it carries an `Unfreeze:` line; trigger 1 (the person answered) is the normal case. Unit test.
- [ ] **COORD6-7 (negative):** no check reads any file outside `docs/agents/`; nothing in `src/` or `supabase/` changes; `npm run agents:check` on `recovery/main` at merge time passes.
- [ ] **COORD6-8 (docs):** `DECISION_PACKAGES.md` *Frozen packages* and README rule 9 name the check and its env variables in one line each (Engineering may edit those two lines for this purpose).

## Rules and their input class
None. This item adds no care, signal, threshold, gate or priority rule; it checks the format of coordination documents only. No *clinical content*, no *care-context fact*.

## Out of scope
- Judging whether a stated trigger is true: the check enforces that a trigger is named, the reviewer judges it.
- Editing scheduled tasks or their prompts (F7, owner only).
- The `csa` weekly measure (F6).
- Any change to package content, defaults or statuses.

## Constraints and references
- README rule 9; `DECISION_PACKAGES.md` *Frozen packages* (F1, F2, F4, F5 adopted by po 2026-10-28 11:10); `csa` STR-17 (issue #593), STR-14 (issue #540).
- COORD5 (`scripts/agents-coordination/parse.mjs`: `readPackageIndex`, `packageStatusOf`, `AWAITING`) is the parser to extend; ADR as Engineering sees fit.
- Value: 5 (less administration, here for the agents and the owner) and 7 (scalability of the agent organisation); owner-requested. Patient safety: unchanged; F4 keeps `cra` S1/S2 and `lca` non-compliant findings applied at once, and a CGR naming a package is trigger 3.

## Open questions for engineering
- If `git diff` against the base is not available in the `agents-check` job, propose the smallest CI change (fetch depth) in the PR.
- If COORD6-4's phrase match gives false positives on existing entries, it applies to entries added in the diff only (as written); say so if another heuristic is safer.

## PO review and acceptance 2026-10-28 20:15 CET: accepted

**Delivered:** PR #612 (ADR-110), merged `785278e` on `recovery/main` 2026-10-28 20:11 CET by `eng`. Files: `scripts/agents-coordination/freeze.mjs` (new), `scripts/agents-check.mjs`, `tests/unit/coord6-freeze.test.ts` (new), `.github/workflows/ci.yml` (`fetch-depth: 0`, `AGENTS_BASE_REF`), one line each in README rule 9 and `DECISION_PACKAGES.md` *Frozen packages*. No file in `src/` or `supabase/` changed. CI on the #612 head: `app`, `db`, `e2e`, `ui-screenshots` green; on the merge commit `785278e`: `app` (lint, typecheck, unit, audit, build, agents-check) green, the other jobs were still running when this review was written and are re-checked before this PO PR merges. **The PO did not run the tests.** The PO ran `node scripts/agents-check.mjs` on `recovery/main` `785278e` (ok, base resolved) and read the code and the test names.

| Criterion | Result | Evidence |
|---|---|---|
| COORD6-1 marking | met | `frozenMarkerErrors` with `FROZEN_MARKER` (status link, optional ` · `, `frozen since YYYY-MM-DD HH:MM`); unit tests "an awaiting-approval row without the marker is an error, with it ok" and "the marker must follow the status link directly" |
| COORD6-2 unfreeze line in the package file | met | `freezeFindings`: frozen = `awaiting-approval` on the base; an *added* line `^Unfreeze: [1-5] \S` required (multiset difference); tests (a), (b), (c), (d) plus "an Unfreeze line already on the base does not unfreeze a new change" and "a malformed line … does not count" |
| COORD6-3 rows | met, stricter (deviation 1) | INDEX row and `OPEN_DECISIONS.md` *Open* row need a **new** `Unfreeze: n ` reference or the package line; tests per file, via the package line, and a negative for unfrozen packages |
| COORD6-4 journal | met | entries added in the diff (`## ` heading not on the base), "no new evidence" (any case) plus a frozen ID as a whole token; warning before `2026-11-03T23:00Z` (= 2026-11-04 00:00 Europe/Zurich, CET), error from then; `AGENTS_NOW` injectable, invalid value is an error; tests on both sides of the date and negatives (old entry, other ID, `D-3` vs `D-38`) |
| COORD6-5 no base | met | `readBase` returns `skip` with the reason; one `console.warn`, check 1 still runs; tests "an unresolvable base …" and "a folder outside git …"; CI `fetch-depth: 0` and `AGENTS_BASE_REF = origin/<base_ref>` on `pull_request` |
| COORD6-6 no false stop | met | moving out of *Open* is satisfied by the package line or a new reference in the *Decided* row; tests "to decided with an Unfreeze line → ok", "… without any Unfreeze line → errors", "po-decided and inputs-requested by row references" |
| COORD6-7 negative | met | `readBase` runs only `git rev-parse`, `git merge-base` and `git show <rev>:<docs/agents path>`; nothing in `src/` or `supabase/` changed (PR file list); `agents-check` on `785278e`: ok (run by the PO) |
| COORD6-8 docs | met | README rule 9 and `DECISION_PACKAGES.md` *Frozen packages* name the check, `AGENTS_BASE_REF` and `AGENTS_NOW` |

**Deviations (ADR-110), decided:** (1) COORD6-3 requires a *new* reference, not one already present: **accepted**; a row that once carried `Unfreeze:` would otherwise let every later edit through, which is the failure the brief exists to stop. (2) an added journal entry is a `## ` heading the base lacks: **accepted**; entries are never edited (README rule 7), so the heading identifies the entry.

**Noted, no change asked:** on a push to `recovery/main` the base is `HEAD`, so the guard runs only on pull requests; a direct push to `recovery/main` is not checked. Every role publishes through a PR (README), so this is accepted as is; if a direct push ever bypasses the freeze, the PO will ask for branch protection, not more code.

**Business and care-model value:** value 5 and 7. The freeze rule broke ten times on its first day while it lived only in text; the owner's agenda now changes only when something real changes, and agent runs go to new value (owner, 2026-10-28). Patient safety unchanged: an S1/S2 `cra` finding or an `lca` "non-compliant" still unfreezes through trigger 3 with one named line. **Architecture:** a format check on the coordination layer only, reusing COORD5's parser; no product code, no data. Aligned.
