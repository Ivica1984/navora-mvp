---
id: COORD-7
title: Build efficiently toward M9 (merge mechanics, WIP limit, order, review cadence, owner slot)
status: awaiting-approval: owner
owner_in_row: po
confidence: Medium
approval_required: owner (points 4 and 5 only)
updated: 2026-11-12
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

**Clinical Architect 2026-11-12:** input on point 4a (advisory; an AI reviewer, not a licensed clinician; decides nothing; full text in `reports/CLINICAL_GOVERNANCE.md` 2026-11-12 01:31). **Yes, a gate per finished slice keeps what AUT-50 and condition 2 protect, on three conditions:**
- **(4a-c1)** Every *merged* head is named in a `cra-gate` line, or its PR's own change is unchanged since a gated head. Intermediate heads need no line (as `lca` (4a-1)).
- **(4a-c2)** The carry-over test compares the PR's own change: `git diff recovery/main...<head> -- src supabase tests e2e` is identical at the gated head and at the merged head. Today's raw `git diff <gated head> <merged head>` is not empty after a merge of `recovery/main` into the PR, although that content was gated in its own PR (case: #1093 `21a5c5b` → `cc99cc4`, PO 22:39). This is a stronger, mechanical check in place of a re-gate. It does not remove the gate. It can run in `agents-check` or in the merge comment.
- **(4a-c3)** A slice that adds or changes a hard-coded clinical, billing or qualification rule is gated before merge, is never bundled with later work, and adds its Clinical Rule Register row in the same PR. A blocking finding holds the slice, whatever the cadence.

## Legal/compliance impact
*(requested 2026-11-07 from `lca`, points 4 and 5: governance)* Asked: does any point weaken the audit trail of review and merge (`PO_MERGE_PROCESS.md` §6) or the traceability that FE-035 requires?

**lca input 2026-11-12 00:25 on points 4 and 5 (advisory; an AI analyst, not a lawyer; not legal advice; no final determination).** Why now: the section was requested and empty, and the package touches governance (eligible, tier 4; nothing in tiers 1-3 was eligible this run). Read on `recovery/main` `1bb09cb`: this package, `PO_MERGE_PROCESS.md` §4 condition 2 and §6, Blueprint QG-2 (AUT-50), `FOUNDER_DECISIONS.md` v16 (FE-035, FE-050, FE-052, FE-053, FE-054), `proposals/2026-11-10-konflikte-qualitaet/` (V12). No `cra` input exists for point 4a yet (Clinical section still *requested*; no COORD-7 mention in `CLINICAL_GOVERNANCE.md`), so nothing below covers the clinical question.

**Sources (read 2026-11-12 00:22-00:24, through a summarising fetch tool; article texts not read verbatim):**
- [E1] EDÖB, *Leitfaden … Meldung von Datensicherheitsverletzungen … nach Art. 24 DSG*, v1.2 (6 Feb 2025, amended 23 Apr 2025), [edoeb.admin.ch](https://www.edoeb.admin.ch/dam/de/sd-web/T64CAUyvAMcF/1_2%20Leitfaden%20des%20ED%C3%96B%20betreffend%20die%20Meldung%20von%20Datensicherheitsverletzungen%20und%20Information%20der%20Betroffenen%20nach%20Art.%2024%20DSG_DE.pdf): the controller notifies the FDPIC «so rasch als möglich» (Art. 24 Abs. 1 DSG) and may not wait for lengthy investigations; a processor informs the controller of every breach; missing details may follow (Art. 15 Abs. 2 DSV). No fixed hour limit in the guide.
- [E2] EDÖB, *Recommendation on logging under the DPO* v1.0 (15 Sep 2023), [edoeb.admin.ch](https://WWW.EDOEB.ADMIN.CH/dam/edoeb/en/dokumente/datenschutz/Empfehlung%20Protokollierung%20nach%20DSV_EN.pdf.download.pdf/Empfehlung%20Protokollierung%20nach%20DSV_EN.pdf): Art. 4 DSV logging concerns processing operations on personal data (storage, change, read, disclosure, deletion), kept at least one year; it says nothing about software-development or review records.

**Settled (with sources):**
- No source I read requires a particular review, gate or merge cadence for software development, or a version row per document change. The merge trail of §6 and FE-035 are **internal governance rules** (founder decisions), not legal duties. Art. 4 DSV logging [E2] is about processing personal data in the product (IMPLEMENTED or PLANNED elsewhere, not affected by this package). So points 4 and 5 are mainly governance choices for the owner; the legal view only checks that they do not remove evidence NAVORA may later need.
- Phase A has synthetic data only (FE-031, D-1); staff test accounts carry e-mail addresses (personal, not health data; my D-2 and D-26 sections). A breach involving them would still fall under Art. 24 DSG if it is likely to cause a high risk [E1].

**Verdicts:**
- **4a (one `cra` gate line per finished slice head, within AUT-50): compliant under every plausible interpretation, with (4a-1):** every *merged* head is either named in a gate line or covered by an empty `git diff <cleared head> <merged head> -- src supabase tests e2e` recorded in the merge comment (§6, condition 2), as today. Intermediate, unmerged heads need no line. This keeps the §6 trail unchanged: one gate line per merged code state. Whether it keeps what AUT-50 protects clinically is `cra`'s question (still open).
- **4b (`uxa`/`aia` daily): no legal or audit-trail effect.** Cadence is the owner's (scheduled tasks). Note: the owner has since set the cadence of the gate roles himself (V12, 2026-11-10 22:55: `lca` and `cra` every 4 h, PO :39, `eng` :09), so 4b is partly overtaken; that is for `po` to record, not for me.
- **4c (Blueprint version row only on milestone change): not a legal question, but it would weaken FE-035,** which asks for a version row and traceable substantial changes; FE-035 is a newer founder decision than this proposal's evidence and governs (README rule 10). git history keeps every change either way, so no legal duty I know of is affected; the loss is in readable traceability. The PO's (c) "no" is the most protective option and **compliant under every plausible interpretation**; (c) "yes" needs the owner, as the package already says.
- **5 (weekly 30-minute owner slot): compliant under every plausible interpretation, with (5-1) and (5-2):**
  - (5-1) the slot never delays anything that must go to the owner at once: a suspected data-security breach (Art. 24 DSG «so rasch als möglich», [E1]; even in Phase A for staff accounts or keys), a stop case or a live-system incident. These keep the immediate path (`docs/engineering/OWNER_RUNBOOK.md`) outside the slot.
  - (5-2) each owner answer from the slot is recorded by the PO as an FE row with source and time (FE-035, `FOUNDER_DECISIONS.md` rule), as already done. A fixed slot attended by the PO would also reduce answers that reach the PO second-hand (FE-050 «nicht vom PO selbst gehört»; open PR #1100 records answers given in an `eng` session), which helps traceability.
- **No contradiction with FE-052/FE-054 found:** FE-054 (merge only with green CI on head and merge commit) adds conditions; 4a does not relax them.

**UNKNOWN:**
- Whether a medical-device or quality-management standard (e.g. software change control) would later require a per-change review record. It would matter only if NAVORA were a medical device, which is the owner's goal not to be (D-34, my 2026-11-04 section; not a confirmed classification). Not read today; no rule is assumed. If D-34 ever changed, the present §6 trail (gate per merged head, merge record, journal) is the evidence to keep.
- Retention period for the governance records themselves (journals, merge comments): no source read; git and GitHub keep them for now. Not a question for the adviser catalogue unless Phase B makes them business records.

No new adviser question; `ADVISER_CATALOGUE.md` unchanged.

*Note to po:* (4a-1), (5-1) and (5-2) can go into the owner's sentence for points 4 and 5. The package still names MERGE1-2/MERGE1-9 risks about `JOURNAL.md`; FE-053 (owner, 2026-11-10) has replaced that mechanism, and V12 has partly overtaken 4b; both are yours to update. `cra` input for 4a is still missing.

`lca 2026-11-12 00:25`

## Risks and mitigations
| Risk | Mitigation |
|---|---|
| ~~MERGE1 loses or rewrites a past journal entry~~ | ~~MERGE1-2, MERGE1-9~~ **Overtaken 2026-11-12 (po):** FE-053 (owner, 2026-11-10) made every journal entry its own file and `JOURNAL.md` an archive; the conflict mechanism is gone |
| ~~Roles keep writing `JOURNAL.md` under old prompts~~ | ~~MERGE1-8, MERGE1-9~~ **Overtaken 2026-11-12 (po):** FE-053 |
| A mechanical three-dot check is read as replacing the gate | (4a-c2) keeps the gate: the PR's own change still needs a `cra-gate` line; only the re-gate after a pure `recovery/main` merge-in falls away |
| A fixed owner slot delays an urgent item | (5-1): breach, stop case and live incident keep the immediate path (`docs/engineering/OWNER_RUNBOOK.md`) |
| WIP 1 stalls Engineering while a `cra` gate is pending | Engineering may prepare the next slice locally and push it once the open PR merges; docs work continues |
| Holding back the NH-A work misses 2026-11-27 | the PO writes NH-A1 and NH-A2 briefs ahead of that date (Blueprint M9.0a), so Engineering can start right after QUAL1 part 2 |

## PO consolidation 2026-11-12 02:39 CET (all inputs in)

Inputs: Engineering (#960, 2026-11-07), `cra` point 4a (2026-11-12 01:31, three conditions), `lca` points 4 and 5 (2026-11-12 00:25, compliant with (4a-1), (5-1), (5-2)), `aia` support of (4a-c2) (review 47, 02:22; advisory, not a requested input). No input disagrees with another. Evidence since 2026-11-07: #1093 waited two PO runs (22:39, 23:39) for a re-gate whose only new diff was already-gated `recovery/main` content merged into the branch (`21a5c5b` → `cc99cc4`); the cleared head's own change was identical.

- **Point 4a (gate per finished slice):** recommend **yes, with (4a-c1) to (4a-c3)** (`cra`) and (4a-1) (`lca`, same as (4a-c1)). In practice this changes one line of `PO_MERGE_PROCESS.md` §4 condition 2: the carry-over check becomes `git diff recovery/main...<head> -- src supabase tests e2e` identical at the gated head and at the merge head (three-dot, the PR's own change), recorded in the merge comment, in place of today's two-dot `git diff <cleared head> <head>`. The gate itself, FE-054 and (4a-c3) (a rule-changing slice is gated before merge, never bundled, register row in the same PR) stay. This tightens nothing away: a change in the PR's own diff still needs a new line.
- **Point 4b (`uxa`/`aia` daily):** **overtaken** by the owner's cadence of 2026-11-10 22:55 (V12: `lca` and `cra` every 4 h, PO :39, `eng` :09). Nothing to ask; `uxa`/`aia` cadence stays as their tasks have it.
- **Point 4c (Blueprint row only on milestone change):** recommend **no**; FE-035 stays (`lca`: the most protective option). Nothing to change.
- **Point 5 (weekly 30-minute owner slot):** recommend **yes, with (5-1) and (5-2)**: finished packages only, one sentence each in `OWNER_AGENDA.md`; breach, stop case and live incident never wait for the slot; every answer becomes an FE row with source and time. Day and time are the owner's.
- **Link to V1-V14 (FE-054):** V12 also covers cadence. If the owner prefers one rule-change package, 4a can be answered together with the V1-V14 consolidation (waiting for the `csa` file). Asked now because it is complete and costs a re-gate per merge-in.

## Recommended default for NAVORA
- **Point 1:** MERGE1 before the next feature slice, after the four waiting PRs (`briefs/MERGE1.md`).
- **Point 2:** at most one open Engineering code PR; one merge per PO run; docs-only Engineering PRs in the same queue.
- **Point 3:** #837 → #961 → #815 → #907 → MERGE1 → QUAL1 part 2 (CGR-153; CGR-154 + UXR-134 + CGR-155; QUAL1-20; QUAL1-15) → UX2 remainder (M2, 2026-11-27) → NH-A1, NH-A2 → NH-A3, NH-A4 → BILL1 on synthetic data (option A, D-18/D-22 po-decided for Phase A) with NH-A5 → M6 offline → M9.0. M5 website, M7 and M8 v2 wait behind (owner: "the website yields"). PLANNED, Low confidence on dates.
- **Point 4 (for the owner; updated 2026-11-12 02:39 after all inputs):**
  - (a) **yes, with (4a-c1) to (4a-c3)**: one gate line per merged slice head; carry-over by the three-dot diff of the PR's own change (§4 condition 2, one line); a rule-changing slice gated before merge and never bundled.
  - (b) overtaken by the owner's V12 cadence (2026-11-10); no ask.
  - (c) no: FE-035 stays.
- **Point 5 (for the owner):** a weekly 30-minute slot with (5-1) and (5-2). The PO prepares a one-sentence ask per finished package in `OWNER_AGENDA.md`. ~~in the order G-1 → D-2 → D-29 → D-18/D-22~~ (G-1 replaced by D-43, 2026-11-10; order as `OWNER_AGENDA.md` stands at the time).
- **Default in force until the owner answers:** today's §4 condition 2 (two-dot carry-over, re-gate when it is not empty), today's cadence, FE-035, no fixed slot.

## Recommendation confidence
**Medium** (2026-11-12): all inputs are in and agree; points 4a and 5 are governance choices, not legal duties (`lca`), and the clinical protection is kept by (4a-c1) to (4a-c3) (`cra`). Not High, because the inputs are advisory AI analyses and the cadence effect is estimated from two weeks of runs. ~~Point 4a waits for `cra`, and points 4 and 5 for `lca`.~~

## Owner approval required?
- **Points 1-3: no.** The PO decides. None of the escalation criteria applies: no legal interpretation, no clinical rule, no commercial or pricing choice, no regulatory liability, no funding or partnership, and no production or live-database change. Order and merge sequence are product authority (README rule 1, FE-018).
- **Points 4 and 5: yes, owner,** once the `cra` and `lca` inputs are in. Two reasons:
  - 4b, and the cadence in 4a, change other roles' scheduled tasks, which only the owner edits.
  - 4c touches FE-035, and point 5 is the owner's time.

  Until the owner answers, today's cadence and FE-035 apply.
- **Escalated 2026-11-12 02:39 (po): `awaiting-approval: owner`.** Ask: «COORD-7: 4a approved with (4a-c1) to (4a-c3); 5 approved with (5-1), (5-2)» (or either one alone). It blocks only the change of one line in `PO_MERGE_PROCESS.md` §4 condition 2 and the slot; no product item waits for it.
