---
id: SEC-DEP1
title: Security dependencies — clear the npm audit / Dependabot alerts without weakening a test
author: po
status: approved
updated: 2026-11-24
---

# SEC-DEP1 — Security dependencies (FE-116, issue #1710)

**Named security fix beside the active package** (pattern SAFE-D11, FE-112 (c)); placed by the PO 2026-11-24 13:39 CET. This brief exists so `eng` can give SEC-DEP1 a status row with origin `po` (asked on #1713); it adds no condition.

## Problem and benefit
Founder issue #1710 reports 33 Dependabot alerts. PO reading (`npm audit --package-lock-only` on `9e80171`, read only): 9 packages, 0 critical, 2 high, 7 moderate, all transitive dev tooling, 0 in runtime dependencies. Benefit: no known vulnerable package on CI runners and developer machines; a clean baseline so new alerts are visible.

## Scope / non-goals
In scope: non-breaking patches (`npm audit fix`), a major bump only after a compatibility check, no test weakened. Non-goals: no application, migration or test change; no new CI gate (proposal for grouped Dependabot PRs is a separate item, PLANNED).

## Acceptance criteria (FE-116 (3))
1. `npm audit` before/after, severity, runtime vs dev named.
2. `app`, `db`, `e2e`, `ui-screenshots` green on the head and on the merge commit.
3. `staging-smoke` green on the merge commit (or an integrated commit after it).
4. Dependabot count 0 or a documented residual risk; read by the founder (agents get 403).

## Evidence (PO, 2026-11-24 14:39 CET; the PO did not run tests locally)

| Criterion | Result | Evidence |
|---|---|---|
| 1 audit before/after | met | ready report [7132950464](https://github.com/Ivica1984/navora-mvp/pull/1713#issuecomment-7132950464): 2 high + 7 moderate → 0; `--omit=dev` 0 before and after; lockfile only, all changed entries `dev: true` |
| 2 CI on head `847148b` | met | `ci` 45402495245: `app`, `db` (pgTAP 6451), `e2e` (215), `ui-screenshots`, `staging` success; `codeql` success |
| 2 CI on merge commit `323e6df` | met | `ci` 45405736532 all jobs success |
| 3 `staging-smoke` on `323e6df` | **not met** | 45405736913, job 138486064329: path 2 tag «Neues Angebot» instead of «Übernommen» (20 s), paths 3-6 not run; Render served `323e6df` before and after. Cause UNKNOWN, asked of `eng` ([7133499504](https://github.com/Ivica1984/navora-mvp/pull/1713#issuecomment-7133499504)); same symptom 2026-11-22 on `ad6aa25` without an app change |
| 4 Dependabot count | OPEN | founder reads the Security tab; expected 0 for npm |

**PO status:** merged (`323e6df`, 2026-11-24 14:39:40 CET; merge actor UNKNOWN, no PO merge record, recorded on #1713), **not accepted**. Acceptance gate when met: «Simulation, synthetic data» (no runtime change). #1710 stays open until criteria 3 and 4 hold.
