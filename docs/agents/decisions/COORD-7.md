---
id: COORD-7
title: Build efficiently toward M9 (merge mechanics, WIP limit, order, review cadence, owner slot)
status: inputs-requested
owner_in_row: po
confidence: Medium
approval_required: owner (points 4 and 5 only)
updated: 2026-11-07
---

# COORD-7 — Build efficiently toward M9

## Decision summary
Engineering proposed five points (issue #960, row in PR #961). **Points 1 to 3 are decided by `po` (product authority, 2026-11-07 12:39):**
- **(1)** MERGE1 (= Blueprint M2.0) has an approved brief and comes before the next feature slice.
- **(2)** At most one open Engineering code PR at a time. The waiting PRs merge in the order #837 → #961 → #815 → #907.
- **(3)** The order follows the M9 path. M2 UX2 stays, because of the owner's implementation priority.

**Points 4 and 5 change other roles' scheduled tasks and the owner's time.** Points 4b and 4c also change FE-035. They go to the owner once `cra` and `lca` have given their inputs.

## Context and problem statement
Engineering's evidence (#960) has four parts:
- Shared files make every merge conflict the rest (AUT-49, Blueprint RC-2).
- Four Engineering PRs had been waiting for 4 to 5 days.
- The nursing-home layer (NH-A1 to NH-A5) and BILL1 that M9 needs are not yet built.
- Decisions, not code, gate M9 (Blueprint M3, 30 %).

IMPLEMENTED today:
- The PO is the only merger (FE-018).
- One open dependent chain (FE-041 (5)).
- The `cra` gate per head, with AUT-50 carry-over when `src`, `supabase`, `tests` and `e2e` are unchanged.
- A Blueprint version row for every content change (FE-035).

## Options considered
| Point | Option | For | Against |
|---|---|---|---|
| 1 | A: MERGE1 now (brief approved) · B: after QUAL1 | A removes the largest recurring waste (value 10, but it gates all other values reaching `recovery/main`) | A delays CGR-153 by about 1-2 Engineering days; synthetic data only, so no patient is exposed |
| 2 | A: one open code PR · B: one chain (FE-041 as is) | A: lead time < 24 h, nothing goes stale | none found; docs-only Engineering PRs still count under the one-merge-per-run rule |
| 3 | A: Engineering order as proposed (UX2 held back) · B: same order, but UX2 remainder kept for M2 | B keeps the owner's priority 1 (M2 web app, escalation date 2026-11-27, owner response 2026-11-03) | B leaves less Engineering time for NH-A before 2026-11-27 |
| 4 | (a) `cra` gate per finished slice · (b) `uxa`/`aia` daily · (c) Blueprint row only on milestone change | fewer review rounds and re-gates | (a) partly exists through AUT-50; (b) changes other roles' tasks (owner); (c) contradicts FE-035 (owner, 2026-11-06) |
| 5 | weekly 30-minute owner decision slot, finished packages only | G-1, D-2 and D-29 are on the M9 critical path (Blueprint §6) | owner time; scheduling is the owner's |

## Engineering impact
*(eng 2026-11-07, #960)* MERGE1: about 1-2 Engineering days (Low confidence). It is reversible. No product code. Points 2 and 3: Engineering limits its own open code PRs from its next run.

## Clinical impact
*(requested 2026-11-07 from `cra`, point 4a only)* Asked: does a gate per finished slice (one-day slices, WIP 1) keep everything that AUT-50 and condition 2 protect today? Specifically: no unreviewed code change in `src`, `supabase`, `tests` or `e2e` between the gated head and the merged head.

## Legal/compliance impact
*(requested 2026-11-07 from `lca`, points 4 and 5: governance)* Asked: does any point weaken the audit trail of review and merge (`PO_MERGE_PROCESS.md` §6) or the traceability that FE-035 requires?

## Risks and mitigations
| Risk | Mitigation |
|---|---|
| MERGE1 loses or rewrites a past journal entry | MERGE1-2 (text unchanged, tested), MERGE1-9 (transition window) |
| Roles keep writing `JOURNAL.md` under old prompts | MERGE1-8: prompt list for the owner; MERGE1-9: two-week warning, PO moves stray entries |
| WIP 1 stalls Engineering while a `cra` gate is pending | Engineering may prepare the next slice locally and push it once the open PR merges; docs work continues |
| Holding back the NH-A work misses 2026-11-27 | the PO writes NH-A1 and NH-A2 briefs ahead of that date (Blueprint M9.0a), so Engineering can start right after QUAL1 part 2 |

## Recommended default for NAVORA
- **Point 1:** MERGE1 before the next feature slice, after the four waiting PRs (`briefs/MERGE1.md`).
- **Point 2:** at most one open Engineering code PR; one merge per PO run; docs-only Engineering PRs in the same queue.
- **Point 3:** #837 → #961 → #815 → #907 → MERGE1 → QUAL1 part 2 (CGR-153; CGR-154 + UXR-134 + CGR-155; QUAL1-20; QUAL1-15) → UX2 remainder (M2, 2026-11-27) → NH-A1, NH-A2 → NH-A3, NH-A4 → BILL1 on synthetic data (option A, D-18/D-22 po-decided for Phase A) with NH-A5 → M6 offline → M9.0. M5 website, M7 and M8 v2 wait behind (owner: "the website yields"). PLANNED, Low confidence on dates.
- **Point 4 (PROPOSED for the owner, after `cra`/`lca`):**
  - (a) yes, within AUT-50: one gate line per finished slice head; any code change after it needs a new line.
  - (b) owner's choice.
  - (c) no: FE-035 stays. The PO keeps the version table, but writes one row per run (not per change), which already holds.
- **Point 5 (PROPOSED for the owner):** a weekly 30-minute slot. The PO prepares a one-sentence ask per finished package in `OWNER_AGENDA.md`, in the order G-1 → D-2 → D-29 → D-18/D-22.

## Recommendation confidence
Medium. Points 1 to 3 rest on repository evidence (journal, PR history). Point 4a waits for `cra`, and points 4 and 5 for `lca`.

## Owner approval required?
- **Points 1-3: no.** The PO decides. None of the escalation criteria applies: no legal interpretation, no clinical rule, no commercial or pricing choice, no regulatory liability, no funding or partnership, and no production or live-database change. Order and merge sequence are product authority (README rule 1, FE-018).
- **Points 4 and 5: yes, owner,** once the `cra` and `lca` inputs are in. Two reasons:
  - 4b, and the cadence in 4a, change other roles' scheduled tasks, which only the owner edits.
  - 4c touches FE-035, and point 5 is the owner's time.

  Until the owner answers, today's cadence and FE-035 apply.
