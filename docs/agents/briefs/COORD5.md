---
id: COORD5
title: Decision issues reach a person only with a package
author: po
status: approved
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
