---
id: MERGE1
title: Merge mechanics without shared-file conflicts (Blueprint M2.0)
author: po
status: approved
updated: 2026-11-07
---

# MERGE1 — Merge mechanics without shared-file conflicts (Blueprint M2.0)

**Approved 2026-11-07 12:39 CET (scheduled PO run)**, on Engineering's proposal COORD-7 point 1 (issue #960, PR #961) and Blueprint sub-milestone M2.0 (AUT-49, ADR-free so far). Repository and process work only: no product behaviour, no care rule, no data.

## Problem
Every role PR and every Engineering PR writes the same three files: `docs/agents/JOURNAL.md` (about 9 600 lines), `docs/engineering/DECISIONS.md` and `docs/agents/IMPLEMENTATION_STATUS.md`. So each merge makes every other open PR conflict. Evidence:
- **2026-11-07:** the Engineering run at 11:10 did nothing except bring #835 and #837 up to date. Both had been BUILT since 2026-11-03. Their only conflicts were in these files.
- **2026-11-06/07:** role PRs #936, #937 and #954 went `dirty` after merges, on `JOURNAL.md` only.
- **Blueprint metric M-04** (conflicts per merge) is above 0 on almost every merge.

This is time that no care team gets back. M1 (2026-11-13) slipped by days for this reason alone.

## Users and journey step
The agent roles (`po`, `eng`, `cra`, `lca`, `uxa`, `aia`, `csa`) and the owner, who reads the journal. This is not a care journey step. It shortens the path for every capability from BUILT to IMPLEMENTED.

## Outcome
Two PRs from different roles can each add a journal entry, an ADR or a status-row change, and both merge without a conflict in either order. Readers still find the newest entries first, in one place.

## Acceptance criteria
- [ ] **MERGE1-1 Journal per entry.** A new journal entry is a new file, one entry per file, in a directory such as `docs/agents/journal/`. Its name sorts by time and carries the role (for example `2026-11-07-1239-po.md`). No PR needs to edit a shared journal file to add an entry.
- [ ] **MERGE1-2 History kept, never rewritten.** Every entry in today's `JOURNAL.md` stays readable, word for word and newest first. Either the file is frozen as an archive with a one-line header pointing to the new directory, or it is split into per-entry files. A test shows no old entry's text changed: the diff of the old entry text against the archive or split is empty, apart from the added header or front matter.
- [ ] **MERGE1-3 No committed generated file that every PR touches.** If a combined view is generated, PRs do not commit it, so it cannot conflict. Either it is built on demand (`node scripts/<name>.mjs`) or it is not committed at all. No workflow pushes to `recovery/main`: the PO stays the only role that merges there (FE-018).
- [ ] **MERGE1-4 ADRs per file.** A new ADR is a new file, for example `docs/engineering/decisions/ADR-<n>.md`. `DECISIONS.md` becomes an index or archive that a new ADR does not need to edit, or it is generated as in MERGE1-3. ADR numbers stay unique: a check fails on a duplicate number.
- [ ] **MERGE1-5 Status rows without a shared-line conflict.** Changing one item's status in `IMPLEMENTATION_STATUS.md` no longer conflicts with another item's change. One way is a file per item. Another is the PO's 2026-11-06 19:15 proposal, which `aia` supports: status rows change only on `recovery/main` after a merge. `eng` chooses (HOW) and records the choice in an ADR. The PO's rule stands: `IMPLEMENTATION_STATUS.md` remains Engineering's file.
- [ ] **MERGE1-6 `agents-check` enforces it.** `node scripts/agents-check.mjs` fails when:
  - a PR edits an archived journal entry;
  - a journal file name does not match the pattern;
  - a journal file holds more than one entry;
  - an ADR number repeats.
  Unit tests cover each failure and the passing case.
- [ ] **MERGE1-7 No check weakened.** `.github/` keeps every job, test and required step (`PO_MERGE_PROCESS.md` §4 condition 7). `agents-check` keeps every rule it has today.
- [ ] **MERGE1-8 Protocol text.** The same PR updates the README rule that says where a journal entry goes. It also lists, for the owner, each scheduled-task prompt whose wording ("add a `JOURNAL.md` entry") must change. The PO edits no prompt.
- [ ] **MERGE1-9 Transition without a lost entry.** For two weeks after the merge, `agents-check` accepts an entry that a role still adds at the top of `JOURNAL.md` under an old prompt. It shows a warning and the run passes. The PO moves any such entry into a file in its next PO PR. After the two weeks, such an edit fails.
- [ ] **MERGE1-10 Measured.** After the merge, the PO records M-04 (open PRs turned `dirty` by a merge, read from the GitHub API) for the next five merges, in the journal and in Blueprint §10. Target: 0 caused by journal, ADR or status files.
- [ ] **Negative cases:** no role other than `eng` edits Engineering's files. The change touches no `src/`, `supabase/` or `tests/e2e/` product code, beyond tests for the scripts. No real personal or health data. No reference to the live project.

## Rules and their input class
No care rule is added or changed. Every rule here is a repository process rule (file layout and checks). Input class: not applicable. This is not a signal, threshold, gate or priority on care data.

## AI leverage
1. **Remove:** whole agent runs spent only on conflict resolution (the 11:10 `eng` run on 2026-11-07), and the PO's merge-ins of `recovery/main` into its own PRs.
2. **Rules:** deterministic file-name and archive checks in `agents-check`.
3. **Monitor:** M-04 per merge, from the GitHub API.
4. **AI prepares:** no model-based agent. Not needed: this is a file layout and a script.
5. **Human reviews:** the PO reviews the PR under `PO_MERGE_PROCESS.md` §4.
6. **Human decides:** the PO merges.
7. **Human signs:** none.

Administrative step removed: conflict-resolution runs. Baseline: one full Engineering run on 2026-11-07, plus repeated `dirty` role PRs (journal 2026-11-06/07). The AN3 care baseline is not affected. Gate: none (stage 0, no data). AI must never rewrite or summarise past journal entries.

## Out of scope
`scripts/po-merge-gate.mjs` (`PO_MERGE_PROCESS.md` §7, change D) stays part of Blueprint M2.0 but is a separate slice after MERGE1: M2.0 counts IMPLEMENTED only when both are merged.
- Changing the review cadence of other roles (COORD-7 point 4, owner package).
- Changing the `cra` gate (condition 2).
- Changing the Blueprint version rule (FE-035).
- Changing any scheduled task.

## Constraints and references
- Blueprint §4 M2.0 (due 2026-11-13, weight 2).
- AUT-49 (`aia`).
- COORD-7 (#960).
- FE-018 (PO is the only merger).
- FE-035 (Blueprint living document).
- README rules 1, 10 and 11.
- `PO_MERGE_PROCESS.md` §4.

## Open questions for engineering
1. **Journal history (MERGE1-2):** archive, or split into per-entry files? The PO prefers the archive, as the smaller and fully reversible change, unless a split is cheap and keeps the text byte for byte.
2. **Status rows (MERGE1-5):** per-item files, or "rows change only after the merge"? State which keeps the PO's merge gate (condition 4 reads the status row) workable.
3. **Combined view:** is one needed at all? If so, does a 20-line script cover it?

## Order and WIP (COORD-7 points 2 and 3, PO 2026-11-07)
MERGE1 is built after the waiting PRs are merged, in this order:
1. #837 (M1.4);
2. #961 (COORD-7 row, MERGE1 row);
3. #815 (ASM1-C6, needs a `cra` gate line on its head);
4. #907 (weekly status).

This way the change does not make them conflict again. It comes **before** the next QUAL1 part 2 slice (CGR-153). From now on there is at most one open Engineering code PR.
