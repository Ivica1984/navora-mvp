---
id: CI2
title: CI minutes fit a private repository without weakening any required check (D-7 stage 3)
author: po
status: approved
updated: 2026-11-07
---

# CI2 — CI minutes fit a private repository without weakening any required check (D-7 stage 3)

**Approved 2026-11-07 15:39 CET (scheduled PO run)** on the owner's D-7 answer (FE-045, stage 3: "`eng` senkt die CI-Minuten vor dem Umschalten", reported by `eng` in PR #971). Repository work only: no product behaviour, no care rule, no data.

## Problem
The owner wants the repository private (FE-045 stage 4). `eng` measured on 2026-11-07: about 175 CI runs a day, about 13 minutes each, about 70 000 minutes a month, against 2 000 (free) or 3 000 (Pro) included minutes for a private repository. Switching today would stop CI within about a day, and then no PR could meet `PO_MERGE_PROCESS.md` condition 1. IMPLEMENTED today (`.github/workflows/ci.yml`): CI runs on `pull_request` and on pushes to `main` and `recovery/main`, with `concurrency` cancelling superseded runs on the same ref. Most runs are role docs PRs (only `docs/` changed) that still run `db`, `e2e` and `ui-screenshots`.

## Users and journey step
Every agent role and the owner. Not a care journey step: it keeps the merge gate (and so every capability's path to IMPLEMENTED) working after FE-045 stage 4.

## Outcome
The repository can go private on GitHub Pro without CI stopping, and no PR that changes code, migrations, tests or workflows merges with less checking than today.

## Acceptance criteria
- [ ] **CI2-1 Measured baseline and target.** An ADR records the measured runs per day, minutes per run and minutes per month (source: the Actions API, date range named), and the projected minutes per month after CI2, which must be at most the included minutes of the plan the owner books (GitHub Pro, FE-045 stage 2), or the ADR states the paid overage in CHF per month as UNKNOWN or a list price, for the owner.
- [ ] **CI2-2 Same check names, never skipped silently.** The four required checks keep their exact names (`app (lint · typecheck · unit · audit · build)`, `db (migrations · seed · pgTAP)`, `e2e (auth · protected routes · Playwright)`, `ui-screenshots (390 · 1440 · every role)`). On a PR that changes only files under `docs/` (path list in the ADR), each heavy job is replaced by a fast job with the same name that **succeeds only after it has verified** that the diff against the base touches no path outside that list; otherwise it fails. A test PR shows both outcomes.
- [ ] **CI2-3 Negative cases.** A PR that changes any file under `src/`, `supabase/`, `tests/`, `e2e/`, `scripts/`, `.github/`, `package.json` or the lockfile runs every full job; a test proves that a docs-only PR plus one changed `src/` file runs the full `db`, `e2e` and `ui-screenshots` jobs.
- [ ] **CI2-4 Docs checks stay.** `node scripts/agents-check.mjs` (the agents-coordination workflow) still runs on every PR that touches `docs/agents/`, unchanged.
- [ ] **CI2-5 Push to the protected branches stays full.** Every push to `recovery/main` and `main` (that is, every merge commit) runs the full four jobs, so section 5 acceptance on the merge commit is unchanged.
- [ ] **CI2-6 No check weakened.** The diff of `.github/` removes no job, test or required step for code changes (merge gate condition 7); the ADR lists every changed trigger.
- [ ] **CI2-7 Measured after.** For the first 7 days after the merge, the PO records runs per day and minutes per day from the Actions API in the journal and in Blueprint §10.

## Rules and their input class
No care rule. The only rule is a path filter (*visit/schedule fact* does not apply; class: repository fact).

## AI leverage
No AI leverage: a deterministic path filter removes the work (step 1, Remove). AI must never decide whether a change is "docs only".

## Out of scope
Switching to private (owner, FE-045 stage 4); booking plans (owner); the ruleset (owner, stage 1); self-hosted runners.

## Constraints and references
FE-045; D-7; `PO_MERGE_PROCESS.md` §4 conditions 1 and 7; MERGE1 (fewer conflict merge-ups also mean fewer runs). Order: after MERGE1, before the owner switches to private.

## Open questions for engineering
1. Is GitHub's documented handling of a required check whose workflow is skipped by a path filter ("pending" forever) avoided by the same-name fast job? Cite the GitHub docs page and date in the ADR.
2. Would cancelling superseded runs per PR across pushes of several roles save more than the path filter? Measure, then choose.

## PO review 2026-11-07 19:39 CET (scheduled PO run): merged as B0 work, not yet accepted

**Merged** as `75ff53a` (PR #980, head `9433c23`), under FE-052 / `PRODUCT_BLOCKS.md` §8 (1): B0 work merges one PR at a time once its evidence is in. The merge record is on #980. **The PO ran no test.** Every result below was read through the GitHub Actions API. Under FE-052, *merged* is not *accepted*. CI2 stays **in review** until CI2-5 and CI2-7 are shown on `recovery/main`.

| Criterion | Result | Evidence |
|---|---|---|
| CI2-1 baseline and target | **shown, target not met** | ADR-167: 2026-11-06 measured at 212 runs and 4 015 billed job-minutes. Projection about 35 000 min/month after CI2, against 3 000 on Pro. The overage in CHF is UNKNOWN, for the owner. Allowed by the criterion's "or" clause |
| CI2-2 same names, verified fast path | **shown** | Probe #981 (docs only), run 42401936057: db, e2e and ui-screenshots each 5 to 8 s; the log shows `full=false: 1 files, all under docs/: verified docs-only` |
| CI2-3 negative cases | **shown** | Probe #982 (docs plus `src/app`), run 42401937641: db 3m14s, e2e 9m21s, ui-screenshots 4m01s, all `success`. #980 itself logs `full=true: changes outside docs/` (run 42403021994). Unit tests `tests/unit/ci2-scope.test.ts` passed in the `app` job |
| CI2-4 docs checks stay | **shown** | `app` is unchanged in the diff (agents-check, lint, typecheck, unit, audit, build), and it ran on #981 (1m28s) |
| CI2-5 pushes stay full | **open** | The configuration is merged: a concurrency group per SHA, no cancel on push. Evidence needed: the push run on `75ff53a` and the next merges complete all four jobs in full (this is also B0-1) |
| CI2-6 no check weakened | **shown (PO diff read)** | No job, test or step removed; no `paths` filter; no job-level `if`; triggers unchanged. The only changed setting is `concurrency` (ADR-167 no. 4) |
| CI2-7 measured after | **open** | The PO records runs and minutes a day from 2026-11-08 to 2026-11-14 |

**Deviations decided:**
1. The work was built before MERGE1. **Accepted:** MERGE1 was blocked, and the two do not conflict.
2. The B0-1 configuration ships in the same PR. **Accepted:** CI2-5 depends on it. B0-1 stays *open* until its test case is shown.
3. Brief question 1 was answered from GitHub documentation that was not re-read. **Accepted for Phase A.** The probes show the behaviour directly: no check stayed pending.

**What this does not solve (for the owner, FE-045 stage 4):** going private still costs about 32 000 minutes a month over the included minutes. The largest single lever named in ADR-167 is PR #3, which re-runs every push to `recovery/main` (about 717 min/day, 18 %). The PO proposes it under D-8 (#68). See the journal entry of 19:39.
