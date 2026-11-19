# NAVORA engineering standards (PROPOSED)

**Owner:** Engineering (`eng`) · **Status:** PROPOSED. The founder asked `eng` on 2026-11-19 to set new standards in how NAVORA is programmed. This file proposes them. It **changes no governance rule, no founder decision and no gate**: the PO places them in the queue, and `aia`, `cra` and `lca` review the parts that touch their fields. Each standard becomes binding only through its own reviewed PR with tests. Sources: Blueprint V3.2 §1.4 (order of values), §1.5 (north star), §3.1 (rules first, then AI, always the human), §6.3 (handgrip target); Handbook V2.2.

Labels: IMPLEMENTED (in the code today), PLANNED (proposed here), OPEN (needs a decision by someone else).

## Why

The Blueprint calls the AI the heart of NAVORA (§1.1, sentence 4). An AI heart in care is trustworthy only if three things hold:
- every value it proposes can be traced back to its source;
- its quality is measured before and after every change;
- a human decides every proposal.

Today NAVORA tests rules thoroughly: 150 pgTAP files, 1508 unit tests, 45 e2e specs, `ci-repeat` 10/10 for block acceptance. It does not yet measure the AI or its own goals, such as handgrips per order or direct care time. The standards below close that gap.

## The standards

| # | Standard | What it means in the code | Stand |
|---|---|---|---|
| S1 | **Provenance of every AI value** | Every proposal stores its source segments, provider, model, version, prompt hash, the control-layer result and the human decision (taken, dropped, inserted, omitted). It must be replayable: the same input and version give the same check result. No model call exists without this record. | Control layer and per-line sources: IMPLEMENTED (#1494, #1497). The ledger guard: IMPLEMENTED (#1497, `ledger_missing`). The ledger record itself: PLANNED (BK-e2a part 2b, AIG1 migration, pgTAP; `aia`). |
| S2 | **AI evaluation gate in CI** | There is a fixed synthetic evaluation set for each AI function (start: 200 synthetic carer notes, with expected sources and one safety sentence per note). In CI, providers run against recorded answers; there is never a live call in CI (D-35 rule A). The job fails if any of these is broken: 100 % of lines have a source; 100 % of segments are placed or listed; 0 lost safety sentences; the rejection rate does not rise compared with `recovery/main`. A live model run on staging is measured with the same set before the founder sees it. | PLANNED. The 40-segment test (ADR-202 (5)) is the seed: IMPLEMENTED. |
| S3 | **The goals are tests** | Handgrips per order (Blueprint §6.3: at most 1 for the client, 1 for the team, 3 for the carer after the shift) are counted in the e2e run of the BK path. A step that adds a click fails the test until the PO accepts the new number. Minutes from order to «Gedeckt» are measured the same way, with synthetic data. | PLANNED. The BK paths exist as e2e: IMPLEMENTED (`bk-c2-take-status`, `bk-e1b-take-card`). |
| S4 | **Invariants, not only examples** | Each safety invariant gets a property test with random synthetic schedules as well as the fixed cases. Examples: «no order is covered without exactly one visit»; «one carer is never in two places at once»; «nothing typed is lost». | Partly IMPLEMENTED as fixed pgTAP cases (pgTAP 148, 150) and two-session race scripts. Property tests: PLANNED. |
| S5 | **Tests that catch faults** | Mutation testing on the safety-critical modules: the control layer, the guards, the overlap and coverage rules, and the report assist. A surviving mutant is a missing test. Target: at least 90 % of mutants killed in these modules; reported per PR that touches them. | PLANNED (needs a dev dependency; registry access works in CI). |
| S6 | **Staging is proven, not claimed** | After every deploy, the staging smoke clicks the founder's paths and records the commit, time and pass or fail per path. A block is shown to the founder only when the smoke on that commit is green. | Smoke job: IMPLEMENTED (ADR-205, #1492). It needs the founder's three repository secrets: OPEN (founder). Running after each deploy: PLANNED. |
| S7 | **The phone is the main device** | Each `/field` and `/team` screen at 390 px has: 0 axe violations (not only color contrast), touch targets of at least 44 px, and a page budget of under 2 s on a simulated slow 4G link, measured in CI. | 390 px screenshots and axe color contrast: IMPLEMENTED (`ui-screenshots`, UX1-18). Full axe and timing budget: PLANNED. |
| S8 | **Explainable to the person who is affected** | Every refusal or suggestion on a screen says why, in plain words, from stored facts. A test checks that no refusal reaches a screen as a bare error code. | Mostly IMPLEMENTED (reason messages, `commands/result.ts`). A test over all refusal codes: PLANNED. |

## What does not change

- Rules first, then AI, always the human. The AI never decides region, qualification, availability, amounts or assignment (Blueprint §1.6, §3.1).
- No real personal data. The model is called only from staging with synthetic data (ADR-206 (8)). D-35 rule A stays in force for real persons.
- The block rule (FE-070/071): the standards are built inside the active block, starting with S1 in BK-e2a part 2b. They are never built as competing feature PRs.
- No test is weakened to reach a target. A target is changed only by the PO, never to make a build green.

## Proposed order

1. **S1** with BK-e2a part 2b: the AI ledger, the next step anyway.
2. **S2**: the evaluation gate, before the first live model draft is shown to the founder.
3. **S6**: the smoke after each deploy, once the founder's secrets are set.
4. **S3**: handgrips in e2e, with BK-g (scenario matrix).
5. **S4**, **S5**, **S7**, **S8**: one at a time, each touching only code of the active block.
