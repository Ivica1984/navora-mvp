---
id: COORD6
title: Frozen packages stay frozen without anyone watching (agents-check guard, STR-17 F3)
author: po
status: approved
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
