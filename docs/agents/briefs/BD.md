---
id: BD
title: Block BD, durchgängiger Ablauf ambulant (die gebauten Teile werden eine zusammenhängende Software)
author: po
status: approved
updated: 2026-11-10
---

# BD — Durchgang ambulant (Phase A, synthetisch)

**Approved 2026-11-10 22:50 CET** under Founder decision **FE-054** (owner, live session): after B0, the next block is the end-to-end flow; every later block is accepted only when its step runs green in this flow. Block table: [`PRODUCT_BLOCKS.md`](../../product/PRODUCT_BLOCKS.md) §2 (row BD) and §5 (steps).

## Problem
Much of NAVORA is built (J1-J3, QUAL1, PLAN3, VIS1/VIS2, F1-F7, J5, SIG1/2, ASM1 …) but tested item by item. Only one end-to-end test exists: `tests/e2e/journey.spec.ts`, referral → team decision → planned visit (J1-J3). Nobody has shown that a referral can travel through assessment, qualification check, planning, the visit, documentation and a billable fact **in one run**. Until that is shown, NAVORA is a set of features, not software a team can work with.

## Users and journey step
A synthetic home-care team (nurses, one operations account) in a simulation organisation, steps 1 to 9 of `PRODUCT_BLOCKS.md` §5, column *ambulant*. The nursing-home flow (column *Pflegeheim*) is part 2 (BD-H), opened by the PO once BD is accepted.

## Outcome
One automated run proves that a referral becomes a planned, executed, documented and billable (or explicitly stopped) visit, with the team deciding at every point and no step reached by typing a URL.

## Acceptance criteria
- [ ] **BD-1 Inventory (eng, docs, first PR):** `docs/engineering/DURCHGANG_INVENTORY.md`: for each step 1 to 9 (ambulant): screen and command used, state IMPLEMENTED / PARTIAL / MISSING (read from the code, not assumed), the tests that cover it today, and the first point where the chain breaks. No code change in this PR.
- [ ] **BD-2 One continuous e2e test:** `tests/e2e/durchgang-ambulant.spec.ts` (name by `eng`), synthetic local accounts only. In one sequence: referral recorded → case → team takes over (J1/J2) → assessment completed and care plan (ASM1) → visit planned and the qualification check passes for the planned nurse (QUAL1) → PLAN3 day proposal confirmed by the team (AIG1, per value) → visit started and ended at 390 px (F1-F4, VIS1) → report written, returned or signed (F6/F6R/F7) → billable fact exists for the signed report (J5), or the documented stop case. Each hand-over asserts both what the next screen shows and the stored fact.
- [ ] **BD-3 No faked step:** no step is skipped, mocked, seeded past or reached by a direct URL that the previous screen does not offer. Until a gap is closed, the test on `recovery/main` contains only the steps proven to run; the **full** test runs on a probe branch (`repeat/2/bd-full-…`, as for the B0-7 negative case) and the PR names where it turns red. A gap fix is its own PR with its own unit, pgTAP or e2e test.
- [ ] **BD-4 Stop cases on the way:** for each step, every stop case in §5 that is IMPLEMENTED gets a negative step (pgTAP or e2e): e.g. missing evidence refuses the assignment (B2), no completed assessment refuses a non-assessment visit (`assessment_first`), a report not final gives no billable fact (H-05). PLANNED stop cases stay listed as "nicht nachgewiesen".
- [ ] **BD-5 Repeatable:** the test is green on the PR head, on the merge commit, and 10/10 in `ci-repeat` on the merge commit (B0-2 rule; an `infrastructure:` attempt counts as not run).
- [ ] **BD-6 No new rule:** where a step needs a rule that is not decided (billing release after a late assessment D-22, clinical rules D-43), the step ends in today's safe behaviour (refusal, hold, visible fact) and the inventory names the decision. Nothing invented.
- [ ] **Negative:** a nurse of another team, or `anon`, cannot read or act on any record of the run (one assertion per step type, reusing RLS2 accounts).

## Rules and their input class
BD adds **no rule**. It exercises existing IMPLEMENTED rules (CR-002 `assessment_first`, QUAL1 checks, H-05, AIG1 confirmation) on one path.

## AI leverage
1. **Remove:** the manual hand-over checks between features disappear: the test shows the hand-over works. 2. **Rules:** existing rules only. 3. **Monitor:** the test runs on every merge commit and 10/10 in `ci-repeat`. 4. **AI prepares:** PLAN3 proposal only (no client data to any AI service, D-35 rule A). 5-7. The team confirms each value; the nurse signs the report.

## Gates
`cra` (clinical steps 1b, 2, 5, 8; stop cases), `lca` (step 9 billable fact, data visibility of the negative case), `uxa` (no dead end, each step reachable from the previous screen, 390 px). Gate lines on the PR head as for B0.

## Dependencies
B0 accepted (trustworthy CI, final B0-2 10/10). Synthetic data only; live project never touched.

## Priority
First block after B0 (FE-054). Then B1 to B10 in order; each block's acceptance adds its own criteria to its step of this test.
