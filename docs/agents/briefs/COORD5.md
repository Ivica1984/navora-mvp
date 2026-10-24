---
id: COORD5
title: Decision issues reach a person only with a package
author: po
status: accepted
updated: 2026-10-24
---

# COORD5 — Decision issues reach a person only with a package

## Problem
The coordination watcher turns every open decision owned by `owner`, `legal` or `clinical` into a `human-decision` issue assigned to the owner as soon as it is opened (COORDINATION.md, hand-off `decision:<ID>`). 29 such issues are open; each one asks the owner to analyse a question himself. On 2026-10-24 the owner approved a new process ([`DECISION_PACKAGES.md`](../DECISION_PACKAGES.md)): agents prepare a decision package first, and a person is asked only when the package says approval is required. The watcher still pulls the owner in at the first step.

## Users and journey step
The owner, the named Clinical Owner and legal advisers (fewer, better-prepared requests); the PO, `eng`, `cra` and `lca` agents (a visible queue of packages). Coordination layer, not the care journey.

## Outcome
A person is assigned a decision issue only when its package is `awaiting-approval: <role>`. Until then the issue is the agents' work item.

## Acceptance criteria
- [ ] The watcher reads the *Package status* column of `docs/agents/decisions/INDEX.md` for each decision in *Open*.
- [ ] Status `not-started` or `inputs-requested` (or no INDEX row): the issue carries `agents`, `agent:po` and a new label `decision-package`; **no** `human-decision` label and **no** assignee. Existing issues are updated this way (assignee removed, label swapped) with one comment: "Wird zuerst als Entscheidungspaket vorbereitet (DECISION_PACKAGES.md); du wirst erst bei Freigabebedarf zugewiesen."
- [ ] Status `awaiting-approval: owner`, `awaiting-approval: legal` or `awaiting-approval: clinical`: labels `agents`, `human-decision`; assigned to the owner (until a Clinical Owner and legal advisers have GitHub accounts named in README *Participants*); the issue body links the package and quotes its *Owner approval required?* section.
- [ ] Status `po-decided` or `decided`, or the row moved to *Decided*: the issue closes with the existing close reason.
- [ ] `decision:<ID>` for owner `po` or `eng` keeps today's behaviour.
- [ ] Validator (`scripts/agents-check.mjs`): every decision in *Open* owned by `owner`, `legal` or `clinical` has an INDEX row; the status is one of the values in DECISION_PACKAGES.md; an `awaiting-approval` or `po-decided` status has a file `decisions/<ID>.md`; the INDEX holds no ID that is neither in *Open* nor in *Decided*.
- [ ] Unit tests in `tests/unit/agents-coordination.test.ts` for each status above (labels, assignee, close), including an existing assigned issue being unassigned; `--dry-run` prints the package status per decision.
- [ ] Negative: a decision whose INDEX row says `po-decided` but which is still in *Open* is reported by the validator (warning) and keeps `decision-package`, never `human-decision`.

## Out of scope
Writing packages (the agents do that), changing decision ownership in `OPEN_DECISIONS.md`, notifications other than GitHub's own.

## Constraints and references
`DECISION_PACKAGES.md`, `COORDINATION.md`, `scripts/agents-coordination/plan.mjs`, `run.mjs`, `scripts/agents-check.mjs`. No secrets; the watcher keeps its current token scope.

## Open questions for engineering
- Read INDEX.md in `parse.mjs` next to the three official files, or add it to the layer? Engineering decides.

## PO review — 2026-10-24 10:11: `accepted`

#271 (head b3dace6, merged as ccfc857; ADR-073). CI green on the head (app, db, e2e) and on `recovery/main` 2663934 (runs 40076283093, 40076279857); on the merge commit app and db are green, e2e was cancelled by the next push and is green on the newer base. Read through the GitHub API. **The PO did not run the tests.** The live effect was checked through the API after the watcher's runs on 45f23d2, b7c790a and 2663934 (all `success`).

| Criterion | Result | Evidence |
|---|---|---|
| Watcher reads *Package status* from `decisions/INDEX.md` for each decision in *Open* | met | `parse.mjs` `readPackageIndex`, `packageStatusOf` (link or plain cell); `plan.mjs` `packageById` |
| `not-started` / `inputs-requested` / no row → `agents`, `agent:po`, `decision-package`, no `human-decision`, no assignee; existing issues updated with the one German comment | met | `plan.mjs` else-branch, `nextAssignees`, `packageTransitionComment`; unit tests "status … → agents' work item", "no INDEX row", "existing assigned human-decision issue is unassigned, relabelled and commented once". Live: #71 (D-9) has those three labels, no assignee and the comment of 07:23 UTC by `github-actions` |
| `awaiting-approval: owner/legal/clinical` → `agents`, `human-decision`, owner assigned, body links the package and quotes *Owner approval required?* | met | `plan.mjs` awaiting branch, `packageSection`; unit test per role. Live: 11 `human-decision` issues, each assigned to the owner (D-11, D-12, D-16, D-18, D-22, D-28, D-29, D-3, D-30, D-31, D-33), matching the INDEX |
| `po-decided`/`decided` moved to *Decided* → issue closes with the existing reason | met | `closeReason` unchanged; unit test "po-decided or decided and moved to Decided" |
| `decision:<ID>` for `po`/`eng` unchanged | met | `!human` branch keeps title, labels and body; unit test "agent-owned decisions keep today's behaviour" |
| Validator: INDEX row for every human-owned open decision; status in the allowed list; file for `awaiting-approval`/`po-decided`; no orphan ID | met | `agents-check.mjs` COORD5 block; `agents-layer.test.ts` +71 lines; `node scripts/agents-check.mjs` passes on this branch |
| Unit tests per status incl. unassigning; `--dry-run` prints the package status | met | 10 new cases in `agents-coordination.test.ts`; `run.mjs` dry-run output; test "the plan reports the package status per decision" |
| Negative: `po-decided` still in *Open* → validator warning, keeps `decision-package` | met | warning in `agents-check.mjs`; unit test "negative: po-decided (or decided) while still in Open" |

**Deviation (Engineering, decided by po: accepted).** A `po-decided` package whose row is still in *Open* stays a `decision-package` issue until the row moves to *Decided*. This reconciles two criteria and never hands such an issue to a person.

**Additional safety, accepted:** an `awaiting-approval` status whose package file is missing is not handed to a person (unit test). This is stricter than the brief.

**Business value and care model.** Of 31 open decisions, the owner is now assigned 11, each with a package and a one-line ask, instead of 29 open questions. This is the owner's 2026-10-24 instruction made mechanical: less administration and fewer approvals at the top, and agents carry the preparation. Clinical review gate: not applicable (coordination only).

**Handbook alignment.** Coordination stays in the repository (no new service, no secret). The INDEX stays PO-owned and is read as an optional input, not added to the official layer. This is consistent with COORDINATION.md.

**Non-blocking note (COORD5-M1):** 5 of the 11 owner-assigned issues are `clinical` packages, assigned to the owner only because the Clinical Owner has no account yet (G-1). Once README *Participants* names that account, the watcher should assign it instead. Engineering does this at its next touch of `plan.mjs`; it is not a condition.
