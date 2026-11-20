---
id: QUAL2
title: Quality programme Q1–Q6 as packages in the block chain (founder FE-098)
author: po
status: approved
updated: 2026-11-20
---

# QUAL2 — Quality programme Q1–Q6 as packages in the block chain

**Written 2026-11-20 02:45 CET by `po` (scheduled run), after the merge of #1549, as FE-098 asks («`po`: Brief `QUAL2.md` vor dem ersten Q-Paket, nach dem Merge von #1549»).** WHAT and WHETHER are the founder's (FE-098, issue #1557); HOW is `eng`'s (ADR-218); measure: `docs/engineering/QUALITY_SCORECARD.md`. This brief fixes only the WHEN, the package contracts and what each package needs before it can start. Gate of every Q package: **«Simulation, synthetic data»**. The PO did not run tests.

## Problem

The product is built package by package, but the founder cannot click a package before it merges (no preview), nobody sees errors or latency on staging, the staging smoke test has never been green, AI quality is proven only against hand-written answers (S2), `/field` is not proven offline, two screens exceed 1 280 lines, test strength is not measured, and the GitHub default branch `main` shows 25 alerts on outdated code (scorecard 2026-11-19, read by `eng`). Each of these slows every later package or hides a defect from the founder.

## Users and journey step

Founder (clicks a package before the merge), carers on `/field` (offline, speed at 390 px), team and client (fewer regressions), every role reviewing a gate (evidence in CI instead of reading code). Across the whole journey; no new care step.

## Outcome

Every scorecard area moves towards «sehr gut» with a measurable criterion read from code or CI, without mixing quality work into a BK package (README rule 12, FE-098 (2)).

## Order (PO, FE-098 (3); unchanged except point 3 below)

1. BK-e2 (#1549) — **merged 2026-11-20 02:41** (`9f1d673`). Still open in BK-e before its acceptance: the AUT-152 threshold row (`cra` value 21:45) and `ci-repeat` 10/10 on the acceptance commit.
2. Q1 (b)–(d) → BK-f → Q2 → BK-d → Q3 → BK-g → Q4 (b)–(d) → Q5 → Q6 (b).
3. **Start condition (new, PO 2026-11-20 02:45):** Q1 (b), (c) and (d) each depend on an open founder decision (FE-098 (6)): (b) the safe path for the three staging smoke passwords and the Claude key (contradiction with owner D-2: the founder handles no repository secrets); (c) the cost of preview environments (Supabase branching, Render previews); (d) the provider and data region of error and latency measurement (with `lca`). **If none of the three decisions is recorded in `FOUNDER_DECISIONS.md` when BK-e is accepted, BK-f becomes the active package first and Q1 follows as soon as one decision is in**, starting with the part it unlocks. Reason (value order): BK-f closes the teams' money loop (nurse income, 0 % commission); an active package that can only wait would stop the chain. This is a WHEN change within FE-098 (1); it changes no founder decision.
4. Alongside, without their own package (FE-098 (4)), only while no gate window is open, one Engineering PR per PO run: #1559 Q4 (a) fonts local, #1560 Q6 (a) CodeQL, #1561 Q1 (a) version and staging match check.

## Package contract Q1 (b)–(d) «Jedes Paket vor dem Merge bedienbar»

1. **Flow (visible):** the founder opens a link on a PR, logs in with a synthetic account and clicks the package's demo path before the PO merges; after the merge, staging shows the same commit and migration level as `recovery/main` (Q1 (a)), the staging smoke test is green, and the error count and p95 latency of every server command of the last 24 h are visible to `eng` and the PO.
2. **In scope:** (b) staging smoke test green on every merge (path for the credentials as the founder decides; no secret value in any file, comment or log); (c) per-PR preview: app preview plus a database branch with the synthetic seed only, torn down when the PR closes; (d) error reporting and latency measurement for server commands, data region as decided with `lca`; no personal data in traces by design (synthetic only in Phase A, and a test that a trace carries no field of a care record).
3. **Not in scope:** no product behaviour change; no new screen except a link to the preview on the PR; no real persons; no production project.
4. **Tests:** positive: smoke job green on staging; preview reachable and seeded; a forced server error appears in the error view within minutes. Negative: preview database is never `navora-staging` or production; trace payload contains no care-record field (unit or contract test); smoke job fails red when the app and database versions do not match. Permission: preview accounts are synthetic, no service key in the browser.
5. **Gates on one head, one start (FE-097):** `lca` (provider, region, processor) for (c) and (d); `aia` only if the gateway or a model call is touched; `uxa` not needed (no screen). `cra` not needed (no clinical content).
6. **Ready report:** `Paket prüfbereit:` as in FE-095 (3), with the preview link and cost per month as measured or estimated (labelled).
7. **Acceptance:** `ci` green and `ci-repeat` 10/10 (`db`, `e2e`, 0 skipped) on a named integrated commit; gate «Simulation, synthetic data».

## Packages Q2–Q6 (outline; each gets its full contract here before it starts)

| Package | Content (ADR-218) | Needs before start | Gates |
|---|---|---|---|
| Q2 AI platform | eval harness per AI function (S2 generalised), staging run against the real model with quality, p95 latency and cost per prompt version; structured output; versioned prompts; one model gateway (kill switch per agent, cost limit, ledger, fail closed). PO addition: a test that no field of a real person can pass the gateway (D-35 rule A). | BK-f accepted; founder staging key path (Q1 (b)) | `aia`, `lca` |
| Q3 Mobile and offline | `/field` offline queue with existing idempotency keys, sent once on reconnect; e2e with the network cut; performance budget at 390 px on a throttled network, a breach fails the PR | BK-d accepted | `uxa`, `cra` (no double record of a visit) |
| Q4 (b)–(d) Code structure | split `team-client.tsx`, `field-client.tsx` with `ui-screenshots` proving no visible change; shared UI library from `DESIGN_SYSTEM.md`; CI check: no hand-written file in `src/app` over 400 lines; sector differences as configuration | BK-g accepted | `uxa` |
| Q5 Test quality | coverage per PR; mutation testing on AI control, time across midnight, qualification limits, with a CI floor; property-based tests for Zurich time; generated RLS and grant matrix test | Q4 accepted | `cra` (only for the clinical-limit modules) |
| Q6 (b) Security | grouped dependency updates with full CI; secret scanning; SBOM per release; tested `next` upgrade; default branch as the founder decides (FE-098 (6)) | founder decision on the default branch | `lca` (only if a processor changes) |

**PO additions as innovator (proposals for the scorecard, FE-098 (5); not conditions of any running PR):** Q7 accessibility (automatic WCAG 2.2 AA check in CI for every role at 390 px and 1440 px); Q8 impact measure at team level only, never per person (admin time and taps per report, time to the signed report; North Star direct care time, `CARE_OPERATING_MODEL.md`); Q1 addition: restore drill for `navora-staging` (read a backup, restore into a branch database, compare with the seed).

## Rules and their input class

No rule of care, tariff or law is added. All checks are engineering checks on code, CI and synthetic data. Input class: none of the three classes applies.

## AI leverage

1. **Remove:** the hand check «does staging run what we merged» (Q1 (a)) and the PO's reading of code for gate evidence (Q2 eval, Q5 mutation) disappear. 2. **Rules:** CI checks (version match, file size, budgets, coverage floors). 3. **Monitor:** error and latency view (Q1 (d)). 4. **AI prepares:** only in Q2 (eval of an existing AI function on synthetic data; no new agent). 5–7. Reviews, decisions and signatures stay with `eng`, the gate roles and the PO; no AI decides a merge. **Never:** send any real person's data to a model or a monitoring provider (D-35 rule A); measure or rank a person.

## Out of scope

Choosing providers, paying for services, setting secrets (founder); clinical thresholds (Clinical Owner, D-27); any change to RLS, grants, audit or a clinical rule.

## Constraints and references

FE-095 (package contracts), FE-097 (one gate window), FE-098 (programme and order), FE-089 (gate starts of paused roles), README rule 12, ADR-218, `QUALITY_SCORECARD.md`, owner D-2 (no repository secrets by the founder), D-35 rule A.

## Open questions for engineering

1. For Q1 (c): the cheapest preview that still gives the founder a clickable app with the synthetic seed (estimate per month, labelled). 2. For Q1 (d): can p95 latency per server command be measured without an external provider (e.g. stored in the staging database, synthetic only) until the founder decides the provider? 3. For Q1 (b): which credential path satisfies owner D-2 (no repository secret set by the founder)?
