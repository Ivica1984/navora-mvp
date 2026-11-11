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
| CI on the merge commit | green | `ci` (push) 42960813630 on `07cb664`: app, db, e2e, ui-screenshots `success`; the cancelled run 42960820758 is the `pull_request` run of PR #3, superseded |

**BD-1: met** (2026-11-11 05:39 run). BD as a block stays in progress (BD-2 to BD-6 open).

The PO did not run the tests.

### Amendment 2026-11-11 06:39 CET (po: UXR-155 merged #1060; product authority, no rule added, BD-6 holds)
- **UXR-155 delivered** (PR #1060, head `9458752`, merge `1f2e0b7`, ADR-179). The nurse's `/field` «Zu erledigen» row shows one neutral link «Anfragen an dein Team (n)» to `/team#anfragen` while her teams have an open, not declined offer; count only, no client name; the decision stays on `/team`. No migration, same read as `/team` (`team_offers()`, 0086).
- **BD review (care model):** the hand-over J1 → J2 now starts where the nurse starts her day. That removes one phone call or message per referral («hast du die Anfrage gesehen?») and keeps the decision with the team, not a dispatcher (value order 4, 5; continuity 2 because a slow team answer lets the referral go elsewhere). No new urgency colour: the deadline stays on the card, so the cue does not create pressure where no clinical rule says so.
- **Next BD PR:** the Q-BD-2 seed organisation (Basel-Stadt, CGR-177 (a)-(c) pgTAP, `cra` gate line), then BD-2 with option (A) of Q-BD-1.

| Criterion | Result | Evidence |
|---|---|---|
| UXR-155 (amendment 04:39): one neutral «Zu erledigen» line with the count and a link to `/team`, no client name | met | `src/app/(protected)/field/field-client.tsx` (`todo-team-offers`, `data-tone="info"`), `src/features/field/todo.ts`; unit `tests/unit/bd-uxr155-team-offer-todo.test.ts` |
| UXR-155: own e2e test | met | `tests/e2e/journey.spec.ts`: 390 × 844, link visible with count ≥ 1 and no client name, one tap to `/team#anfragen` with the offer card, count one less after «Fall übernehmen» |
| No new read scope (data minimisation) | met | `getOpenTeamOfferCount()` calls `team_offers()`; only a number is passed to the client (unit test) |
| CI on the PR head | green | `9458752`: `app` 130343493311, `db` 130343493258, `e2e` 130343493011, `ui-screenshots` 130343493283 `success` |
| CI on the merge commit | green | `ci` (push) 42967398866 on `1f2e0b7`: app, db, e2e, ui-screenshots `success`; `agents-coordination` 42967398925 `success`; the parallel `pull_request` run 42967405582 is PR #3's |

**UXR-155: met** (2026-11-11 06:39 run). BD as a block stays in progress (BD-2 to BD-6 open). The PO did not run the tests.

### Amendment 2026-11-11 08:39 CET (po: role reviews #1063 `uxa`, #1065 `aia`, #1066 `lca` merged; product authority, no rule added, BD-6 holds)
- **No BD merge this run.** #1062 (Q-BD-2 seed, order step (3), CI 4/4 green on `087c060`) still has no `cra` gate line (condition 2). #1064 (D-18 (I1) test) waits for an answer to `aia` AUT-87 (condition 5); PO asks for a fail-closed app guard.
- **BD-2 additions (adopted):**
  1. **G-2 covers the take-over tap at 390 × 844** (`uxa` 07:52): the BD-2 test taps «Fall übernehmen» on the phone viewport, not on desktop (`journey.spec.ts:82` returns to desktop today). G-6 is asserted in BD-2.
  2. **AUT-88:** the BD-2 run counts the human acts per step (taps, form submits, sign-ins), and tags each act that exists only for the test (for example the F3 «Testlauf» correction) as `test-only`. The count is written to the BD-2 PR as a table. It is the first measured baseline for value order 5 (less administration); it is not a target and is not asserted as a limit.
- **D-18 effect on BD:** M3 is decided for Phase A (`decisions/D-18.md` 08:39) but built in B8 as `J5-v4`. BD keeps Q-BD-1 (A) and does not assert `below_minimum` as a stop (`lca` note (2)).
- **To `cra`:** UXR-158 (the jump to `/team#anfragen` passes over the out-of-hours list and the delivery status) and AUT-90 (the billing preview on the planning page, hazard (h2)): is either acceptable for BD? `cra` answers. Neither blocks #1062.
- **QUAL1 «geprüft» (PO 05:39 ask, `uxa` 07:52):** adopted as direction for B2 (PROPOSED): no standing «geprüft» line on cards. A positive statement belongs at the point of choice (the plan dialog offers only allowed members, `aia` supports it). A detail line on the visit record comes only once a stored fact exists. Words: `cra`.

### Amendment 2026-11-11 10:39 CET (po: #1062 merged; #1068 `cra` merged; answers to #1069 (G-a), (G-b); product authority, no rule added, BD-6 holds)
- **Merged:** **#1062** (Q-BD-2 seed, Testorganisation S, guard 0124; order step (3)), head `087c060`, merge `0c7e38b`, `cra-gate: #1062 087c060 clear`. CGR-177 (a)-(c) are met in pgTAP 124; **(d) is checked at BD acceptance:** the BD acceptance text must state that every result of the run on Testorganisation S is a synthetic simulation result and proves mechanisms, not clinical or billing rules (QAM-0.2 cells stay PROPOSED, D-43).
- **Next BD merge:** #1064 (D-18 (I1) guard, `cra-gate: #1064 31f17d0 clear`, AUT-87 answered by the deny-by-default guard 09:13); then #1069 (BD-2). One Engineering merge per run.
- **#1069 (G-b), PO choice: a seeded setting** for Testorganisation S, as for Testorganisation H (`plan3_day_proposal` on), not an administrator in the run. Reason: BD proves the care flow (referral to billing fact), not organisation set-up; adding an administrator would put a management act into the baseline act count (AUT-88) that a self-organised team should not need. The seed setting is fixture data, labelled synthetic, with a pgTAP or unit assertion that only org S and org H have it. Steps 3 and 4 then run through the day proposal, not hand planning, and BD-2 is accepted only once they do.
- **#1069 (G-a), PO choice:** seed the same synthetic ASM1 instrument for Testorganisation S as for Testorganisation A (fixture only, no new instrument, no item changed), so BD-2 records an ASM1 assessment. Own PR before or with the (G-b) PR; pgTAP that org S has exactly the instruments of org A.
- **Challenge (G-b):** why is the day proposal an organisation setting switched by an administrator at all? Hypothesis H-BD-1 (PROPOSED, decided by pilot data, not assumed): the team switches its own proposals on and off (team setting, audit-logged), and no administrator role is needed for it. Written to B2 as a question, not built in BD.
- **`cra` answers (09:32) taken in:** UXR-158 closed from the clinical side. AUT-90 is acceptable for BD on synthetic data only; CGR-178 and CGR-179 go to B8 (brief J5 amendment 10:39).

### Amendment 2026-11-11 17:39 CET (po: (G-b) owner answer reported by `eng`; product authority, no rule added, BD-6 holds)

- **(G-b) reported owner answer «A»** (synthetic administrator in Testorganisation S, `/admin` screen path; `eng` comments on #1069, 16:54 and 17:04 CET). The PO did not hear it and could not verify it from the repository; it is **not yet recorded in `FOUNDER_DECISIONS.md`**. Until a recorded owner decision exists, the PO choice of 10:39 (seeded setting, merged with #1071) stays the state on `recovery/main`; `eng` may prepare the «A» gap PR, it merges once the answer is recorded. Owner asked to confirm (journal 17:39).
- **If «A» is confirmed:** the administrator act is counted in the AUT-88 act table as its own row («Organisationseinstellung durch Admin»), not hidden in the baseline, so hypothesis H-BD-1 (team switches its own proposals) keeps a measured counter-case.

### Amendment 2026-11-11 18:39 CET (po: G-6 merged; AUT-88 baseline adopted; product authority, no rule added)

- **G-6 gap fix merged:** #1072 (head `74ee68c`, merge `42fdccf`; CI `ci` 43036745745 4/4 green after the runner outage; `cra-gate` clear). Post-merge CI on `recovery/main` is checked in the next run (FE-054). BD is not accepted by this merge; acceptance comes with the BD flow test (#1069).
- **AUT-88 baseline adopted** (`eng` table on #1069, run 43037240509, synthetic seed of Testorganisation S): 83 acts, 22 of them test-only (Q-BD-1 (A) corrections), **61 product acts** for steps 1 to 9. It is the BD reference count; each later block reports its change against it in the same table form. It is a measurement, not a limit, and no test asserts it.
- **Challenge (reading of the baseline):** 23 of 61 acts (38 %) are step 1 at Operations, 18 of them typed fields. That is the intake coordinator NAVORA wants to remove. Covered by REF2 (draft, D-9, D-3) and the intake hypothesis rows of the challenge table; no new row. The baseline gives those rows a measured starting point.
- **Next:** #1069 (BD-2) merges next when its head is still `1baafa3`, CI green and `clean` against `recovery/main`; the `cra` advisory (stale header comment, spec 40-43) is not a merge stop and goes into the steps 3-4/ASM1 change.

### Amendment 2026-11-11 21:39 CET (po: BD-2 merged; `cra` 21:27 CGR-185; `uxa` UXR-163 placed; product authority, no rule added)

- **BD-2 merged:** #1069 (head `2c5149a`, merge `dcf7231`). Seven conditions held: `ci` 43075612468 4/4 green; `clean`; `cra-gate: #1069 2c5149a clear` (21:27, #1094); 0 review threads; test-only diff. Merge record comment on the PR. The 19:39 attempt on the same head had been refused by that run's session permission layer, not by a condition.
  - The merge-commit CI (`ci` 43097499942) was still queued at publishing; the FE-054 post-merge check falls to the next run. A red result means a revert PR from `eng` first.
  - **BD is not accepted by this merge.** Open before acceptance:
    - steps 3-4 and ASM1 in the run (CGR-175; the stale header comment, spec 40-43, goes with that change);
    - steps 6-7 (B6, PLANNED, «nicht nachgewiesen»);
    - BD-4 negatives;
    - BD-5 10/10 in `ci-repeat` on a merge commit.
- **Evidence table (BD-2 slice, proven steps; the PO did not run the tests):**

| Criterion | Result | Evidence |
|---|---|---|
| BD-2 one continuous e2e on synthetic accounts | met for the proven steps (1, 1b, 2 at planning and start, 5, 8, 9); steps 3-4 by hand planning, 6-7 not in the run | `tests/e2e/durchgang-ambulant.spec.ts` on `2c5149a`; e2e job 130714504213 `success` |
| BD-2 stored facts asserted per hand-over (two visits, two `final` reports, four corrections with originals, two facts `billable` with empty reasons) | met | spec (supabase-js as the nurse, RLS); `cra` 17:27 and 21:27 |
| BD-2 (amended 02:39): QUAL1 shown again at visit start; empty reason list at step 9 | met | spec; `cra-gate` 1baafa3 / 2c5149a |
| BD-2 (amended 02:39): ORD0 order before the visit date for B minutes | not applicable in this slice (category-A care visit); open for the full run | spec, care-plan item C |
| CGR-180 (1) corrections form a possible sequence | met; closes with this merge (`cra` 21:27) | unit «CGR-180 (1)» in `tests/unit/bd2-durchgang-time.test.ts`; spec 342-348 |
| BD-3 no faked step (`page.goto` only `/login`, G-1 to G-3, G-6) | met for the slice | spec; `uxa` 19:53 (no `src` diff) |
| Negative: org A nurse reads no row of the run | met | spec negative block |
| CI on the PR head | green | `ci` 43075612468, 4/4 |
| CI on the merge commit | pending | `ci` 43097499942 queued at 21:39 |

- **Next BD Engineering merge: #1093** (BD-4 stop cases, pgTAP 127, head `21a5c5b`, `cra-gate: #1093 21a5c5b clear`). It merges once all four checks are green on its head (`app`, `db`, `e2e` were still running at 21:39) and it is `clean` against `recovery/main`. **CGR-185 (advisory, not a merge stop):** the two QUAL1 stop cases of S3 assert set membership (`rn_required` or `42501 qualification_not_allowed`) instead of `isnt(…, 'ok')`. This comes with the next BD-4 change, and BD acceptance needs it. CGR-175's remaining negatives (`b_without_valid_order` at the fact, «report not final gives no fact», start refused at the door after an evidence lapse) are either added to the BD case shape, or the BD acceptance text names the file where each is proven.
- **UXR-163 (`uxa`, UX1-C2 still unmet; five code-bearing strings on `/field`):**
  - **Decision:** UX1-C2 stays what it is: a condition of the accepted UX1, due before UX2 is delivered and before the first real user. It is not a new item and not a BD criterion, since G-6 covers only the texts the run passes.
  - **Placement under FE-054:** where a BD-4 negative step shows one of these strings (the cover refusal D-3, the lifecycle notices D-31/D-19, the quality notice D-16), G-4/G-6 apply, and the string is fixed in that BD PR as a gap with its own unit test. The rest of UX1-C2 goes with the first block that changes `/field` (B6).
  - The widened scan of `src/features/**` (`uxa` remedy) is its acceptance test; #508 stays open.

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
