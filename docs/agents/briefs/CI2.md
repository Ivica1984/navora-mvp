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
