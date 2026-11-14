# Block rule in the agent prompts (FE-070, FE-071)

**Owner:** Product Owner (`po`) · **Date:** 2026-11-12 15:45 (Europe/Zurich) · **Authority:** the founder reply of 2026-11-12 (FE-071) allows the PO to anchor the rules already decided — one active implementation block, block-level tests and acceptance before the next block — in the PO prompt and the affected agent tasks. Founder decisions, clinical release gates and D-35 stay unchanged.

## 1. Where the rule is anchored

1. **`docs/agents/README.md` rule 12** (read first by every role, every run). This is the binding text for all seven roles.
2. **Scheduled task «NAVORA Product Owner agent»**: the BLOCK RULE paragraph is replaced by the text in §2.
3. **Scheduled task «NAVORA Engineering agent»**: the BLOCK RULE paragraph is replaced by the text in §3, and one sentence is added to its step B.
4. **Not changed:**
   - `cra`, `lca`, `uxa`, `aia`, `csa` and «weekly engineering status». Their prompts contain nothing that contradicts the rule. They read README rule 12 and `FOUNDER_DECISIONS.md`, and each prompt already says that the newest founder decision overrides it. Preparing later blocks stays allowed for them (FE-071 (5)).
   - The disabled task «NAVORA hourly product review» (old PO prompt): left untouched and disabled.

## 2. Wording, PO task (replaces the paragraph «BLOCK RULE (owner, 2026-11-10, FE-054; binding): …»)

> BLOCK RULE (owner, FE-054 2026-11-10, sharpened by FE-070 and FE-071 2026-11-12; binding; README rule 12):
> - **One active block.** Exactly one implementation block or sub-block is active at a time, named in *Active now* of `docs/agents/NEXT_CAPABILITY.md`. When *Active now* says no feature block is active, no feature PR is merged. The only exception is a documented safety fix that *Active now* names (currently SAFE-D11).
> - **Before a block starts**, its brief states:
>   - problem and intended benefit;
>   - scope and explicit non-goals;
>   - roles and views;
>   - owner and contributing roles;
>   - dependencies;
>   - related issues and PRs;
>   - acceptance criteria with positive and negative tests;
>   - the required UX, clinical, legal and security reviews;
>   - a short vision check (the eight questions of FE-070 (7)).
>
>   If a clinical or legal question stays open, cut the block smaller instead of building an unchecked rule.
> - **Merges.** Merge an Engineering PR only for the active block or the named safety fix, only with automated tests for its changed behaviour, and only with green CI on its current head. After the merge, CI on the merge commit must be green; otherwise ask `eng` for a revert PR at once and merge it first.
> - **Acceptance.** A block or sub-block is accepted only on a **named integrated commit**. On it, `ci` must be green and `ci-repeat` 10/10 (`db`, `e2e`), read from the job logs: what ran, what was skipped, expected red, cancelled or flaky. The acceptance also needs the required reviews and a documented decision in `docs/product/ABNAHMEAKTE.md` and the brief.
> - **What does not count:** a merged PR; a CI status that was only read; a run still in progress; a cancelled or contradictory safety test. A total count of passed tests never replaces the block record.
> - **Gate.** Every acceptance names its gate: «Simulation, synthetic data» or «released for real persons and data». These are separate gates.
> - **BD flow.** From BD on, a block is accepted only when its step is green in the BD flow test. A block with only some steps proven is a partial acceptance and is named so.
> - **Preparation.** Clinical, legal, UX and PO preparation of later blocks may run in parallel, never as competing feature merges.
> - **Never** change a clinical or safety release rule, a founder decision or D-35 to get a block accepted.
> - **V1-V14.** Consolidate the team's answers to proposals V1-V14 (`docs/agents/proposals/2026-11-10-konflikte-qualitaet/`, one file per role) once all six exist; rule changes go to the owner as a package.

## 3. Wording, Engineering task

**Replaces the paragraph «BLOCK RULE (owner, 2026-11-10, FE-054; binding): …»:**

> BLOCK RULE (owner, FE-054 2026-11-10, sharpened by FE-070 and FE-071 2026-11-12; binding; README rule 12):
> - **What you work on.** Work only on the active block or sub-block named in *Active now* of `docs/agents/NEXT_CAPABILITY.md`, or on a documented safety fix named there (currently SAFE-D11, brief `docs/agents/briefs/SAFE-D11.md`: red reproduction test first, then the fix; it merges only after its gates).
> - **When no feature block is active**, build no feature. Allowed are docs, the named safety fix, and keeping your open PRs green and free of conflicts.
> - **Preparation** for later blocks (analysis, ADR drafts, red reproduction tests) is allowed only as docs or as unmerged probe branches, never as competing feature PRs.
> - **Every PR** names `Block:` and changes or adds automated tests for every behaviour it changes. Nothing is merged without green CI on the PR head and on the merge commit.
> - **Block acceptance** needs a named integrated commit with `ci` green and `ci-repeat` 10/10 (FE-070). Report per job what ran, skipped, failed or was cancelled. Never report a run that is still in progress as passed.
> - **Never** skip, disable or weaken a test to get green, and never change a clinical or safety release rule to get a block accepted.

**Added to step B (after «Take the one labelled `active`.»):**

> An issue label `active` never overrides *Active now* in `NEXT_CAPABILITY.md`; if they differ, follow *Active now* and say so in your journal entry.

## 4. Conflicts with earlier instructions

| Earlier instruction | Conflict | Resolution |
|---|---|---|
| PO and Engineering prompts: «then B1-B10 in order» (FE-054) | FE-070: B1 is cut into sub-blocks, and the B2 core comes before B1.2 | Replaced by «the block named in *Active now*». The order is set by the PO's block plan, which the founder confirms (Lieferung 4). |
| PO prompt C: «Acceptance activates the next approved item automatically» | FE-070 (9): before the next feature block, the founder deliverables are due | Unchanged in the text. Under README rule 12 and FE-070 the founder decision overrides it; *Active now* names when a block may start. |
| PO prompt H and hard rules: «you never edit scheduled tasks» | FE-071 (5) allows this one change | A one-off authorised change, recorded in FE-071. The hard rule stays in force for everything else. |
| Engineering step B: issue label `active` (e.g. #968 NH-A1) | Label set by the coordination workflow, not by block order | The sentence added in §3. |
| Coordination workflow (`agents-coordination`) sets `active` from `NEXT_CAPABILITY.md` | It cannot read «no feature block active» | OPEN for `eng`: the workflow should set `active` only on the row named in *Active now*. Proposal, not done. |
| BD acceptance, old wording «BD accepted» | FE-071 (1): partial acceptance | Renamed in all files (`ABNAHMEAKTE.md`). |

## 5. Not changed

Founder decisions FE-001 to FE-069, D-27 (clinical release only by the named person), D-35 (no client or staff data to any AI service), the `cra` and `lca` gates, the seven merge conditions (`PO_MERGE_PROCESS.md` §4).

## 6. Update 2026-11-12 22:20 (FE-072)

The founder asked for Rule 12 in the remaining five role tasks as well. Each prompt got one new paragraph «BLOCK RULE (owner, FE-054 …, FE-070, FE-071 and FE-072 …; binding; README rule 12)» after its JOURNAL paragraph. It has the same core as §2 and one role-specific sentence:

> exactly one implementation block or sub-block is active at a time, named in *Active now* of `docs/agents/NEXT_CAPABILITY.md`; no feature PR is merged outside it, except a documented safety fix named there. A block is accepted only on a named integrated commit with `ci` green and `ci-repeat` 10/10 read from the job logs, with the required reviews and a documented decision in `docs/product/ABNAHMEAKTE.md`; a merged PR, a CI status that was only read, a run still in progress, or a cancelled or contradictory safety test is not enough, and no total test count replaces the block record. Every acceptance names its gate («Simulation, synthetic data» or «released for real persons and data»). [role sentence] Never relax a [role gate], a founder decision or D-35 so that a block can be accepted.

| Task | Status | Role sentence |
|---|---|---|
| NAVORA Clinical & Regulatory Architect | **updated** 22:13 | gate lines and reviews first for the active block and the named safety fix; later blocks may be prepared |
| NAVORA UX/UI Design Architect | **updated** 22:16 | the same; preparation = specification reviews, design system, benchmarks |
| NAVORA AI & Automation Architect | **updated** 22:16 | review the active block first; preparation = bottleneck map, automation proposals, AI controls |
| NAVORA Chief Strategy Architect | **updated** 22:16 | the vision check of each active block (FE-070 (7)) belongs in the review |
| NAVORA Legal & Compliance Agent | **not changed:** the session's permission check refused the change («Cowork Scheduled Task Write») | planned: the same as `cra`, with «a legal or data-protection gate» |

Nothing else in the prompts was changed. Until the `lca` task is updated, README Rule 12 binds `lca` too, because its prompt makes the newest founder decision override it.
