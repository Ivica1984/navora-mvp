---
id: BD
title: Block BD, durchgängiger Ablauf ambulant (die gebauten Teile werden eine zusammenhängende Software)
author: po
status: approved
updated: 2026-11-11
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

### Amendment 2026-11-11 02:39 CET (po, `cra` CGR-175, advisory, condition for BD acceptance)
Taken in as acceptance conditions; product authority, no rule added (BD-6 holds):
- [ ] **BD-1 (amended):** the inventory names for step 1b that the gate `assessment_first` (CR-002, 0014) reads the **completed assessment visit** (J3, F1-F4), not ASM1; ASM1 alone does not open it.
- [ ] **BD-2 (amended):** step 1b completes the assessment **visit** through the screens; only then is a category-A or -B visit planned. Step 5 shows the QUAL1 check **again at visit start** (CR-183, QUAL1-17), not only at planning. Step 9 asserts the fact's billable status **and an empty reason list**; for any B minutes the medical order is recorded through ORD0 **before** the visit date (0051 reads the order as of the visit date).
- [ ] **BD-4 (amended):** negatives in addition: a care visit before the completed assessment visit is refused `assessment_first`; B minutes without a valid order give `b_without_valid_order`; a report not final gives no fact; a visit start by a member whose evidence has lapsed is refused at the door. Stop cases (a), (b), (e) of §5 stay listed "nicht nachgewiesen" and do **not** count toward acceptance.
- **Acceptance text:** BD's acceptance states that it proves the software path, and is **no clinical release** of the flow (CGR-145, CGR-146).

### Amendment 2026-11-11 04:39 CET (po, `uxa` 03:52 PROPOSED gate checklist, UXR-155 to UXR-157; product authority, no rule added)
- [ ] **`uxa` gate = G-1 to G-6** of `reports/UX_REVIEW.md` 2026-11-11 03:52, adopted as BD acceptance conditions: G-1 every step entered by a control on the previous screen or the shell menu, `page.goto` only for `/login` (today `journey.spec.ts:25` and `:111` would fail; the fix is in the test); G-2 the nurse's steps at 390 × 844; G-3 each hand-over asserts what the next person sees first; G-4 every refusal shows its reason sentence and the next possible action; G-5 no dead end; G-6 no internal code (D-, CR-, CGR-, SIG-) in any text the run passes.
- **UXR-155 (no cue on `/field` for a referral offered to the team):** a BD gap (hand-over J1 → J2, continuity and team autonomy). BD-1 names it; its fix is its own PR with its own e2e test (one neutral «Zu erledigen» line with the count and a link to `/team`, no client name, absent at 0; design rule `DESIGN_SYSTEM.md` v63). The decision stays on `/team`.
- **UXR-156 (billable state not visible on the item):** BD-2 step 9 asserts the stored fact per visit (billable, empty reason list). The per-item display is named in BD-1 and built in B8 (billing), not in BD; it does not block BD acceptance.
- **UXR-157 (manual «Abrechnungsfakten erzeugen» button):** BD step 9 may use the existing control (reachable on `/team`, G-1 met). **Challenge, routed to B8:** why does a person have to press a button to turn a signed report into a billable fact? Proposal for B8: the fact is derived when the report is signed (same command, no new rule), with the `lca` gate on step 9. Until B8 decides, the button stays.

### Amendment 2026-11-11 05:39 CET (po: BD-1 merged #1057; answers to Q-BD-1 to Q-BD-3 of `DURCHGANG_INVENTORY.md` §4; `cra` CGR-176, CGR-177; product authority, no rule added, BD-6 holds)
- **BD-1 delivered** (PR #1057, merge `07cb664`). Evidence table below; the criterion is met once CI on the merge commit is green (section 5 of `PO_MERGE_PROCESS.md`).
- **Q-BD-1 (step 9, `below_minimum` in a real-time run): option (A).** The nurse records the visit's start and end through «Zeiten ansehen und korrigieren» (F3) before signing, with the reason «Testlauf: simulierte Einsatzdauer». The test asserts the correction row (actor, reason) and that the original `visit_events` times are unchanged (CGR-176 (1)). **Option (B) is not part of BD:** no BD test asserts `below_minimum` as a correct stop case, because CR-029 reads opposite to KLV Art. 7a Abs. 2 and the BAG commentary on every source `cra` and `lca` read (D-18 template 05:26). The inventory and every test name, comment or text that mentions it call it «heutiges Verhalten von CR-029 (UNVALIDATED, Lesart umstritten, D-18)» (CGR-176 (2)). Option (C), a test clock in the database, is rejected.
- **Q-BD-2 (step 2, QUAL1 matrix): yes.** One synthetic simulation organisation in `supabase/seed.sql`, its own gap PR with pgTAP and a `cra` gate line, under the four conditions of CGR-177: (a) labelled synthetic, evidence written by the fixture path only; (b) pgTAP: exactly one simulation organisation, no role can set `organizations.simulation`; (c) Testorganisation A keeps CR-007/CR-164 (pgTAP 121 stays green); (d) BD's acceptance text says the run proves the QUAL1 **mechanism** with the PROPOSED v0.2 cells, not the cells, and that a non-simulation organisation still runs CR-007/CR-164.
- **Q-BD-3 (region): Basel.** The simulation organisation of Q-BD-2 lies in a synthetic Basel-Stadt region (pilot regions, founder direction 2026-11-06); the BD run uses it. Testorganisation A (Bern West) stays as it is for the existing tests. No tariff rule depends on it (`billing_rule` falls back to `CH`, 0043:58).
- **Order of the BD PRs:** as proposed in the inventory §5: (1) BD-1 done; (2) UXR-155 «Zu erledigen» line on `/field`; (3) Q-BD-2 seed organisation; (4) BD-2 test with the proven steps on `recovery/main` and the full test on `repeat/2/bd-full-…`, BD-4 negatives; (5) BD-5 10/10. One PR per gap, each with its own test (FE-054).
- **Acceptance text additions (for BD acceptance):** «Der abrechenbare Hauptpfad nutzt eine Zeitkorrektur (F3) mit dem Grund ‹Testlauf: simulierte Einsatzdauer›.» and the CGR-177 (d) sentence. **Routed to B8/BILL1 (PLANNED):** a fact whose minutes rest on a corrected event carries a warning, never a reason (CGR-176 (3), D-18 invariant I4).
- **OPEN, not BD:** a positive «geprüft» line for a passed QUAL1 check (inventory §1 step 2) goes to `uxa` as a question; it does not block BD.

| Criterion | Result | Evidence |
|---|---|---|
| BD-1 inventory per step 1-9: screen, command, state from the code, tests, first break | met (docs) | `docs/engineering/DURCHGANG_INVENTORY.md` §0-§1 (#1057, read from `76cef8d`); first break step 2 (no simulation org), second step 9 (`below_minimum`) |
| BD-1 no code change | met | #1057 diff: inventory, `IMPLEMENTATION_STATUS.md`, `eng` journal only |
| BD-1 (amended 02:39): `assessment_first` reads the completed assessment visit, not ASM1 | met | inventory §1 step 1b (0014:52-62, 214-219); confirmed by `cra` (`cra-gate: #1057 0d05266 clear`) |
| BD-1 (amended 04:39): UXR-155 named | met | inventory §0 row 1, §1 step 1 (MISSING, own PR) |
| BD-1 (amended 04:39): UXR-156 per-item billing state named | met | inventory step 9 notes, routed to B8 |
| CI on the PR head | green | `ci` 42958866748 on `0d05266`, 4/4 (`db`, `e2e`, `ui-screenshots` skipped their test steps by the docs-only rule ADR-167) |

The PO did not run the tests.

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
