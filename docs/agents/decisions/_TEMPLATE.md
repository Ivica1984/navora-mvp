---
id: D-0            # the decision ID in OPEN_DECISIONS.md
title: Short name
status: not-started  # see DECISION_PACKAGES.md
owner_in_row: owner  # owner | legal | clinical (the row's current owner)
confidence: Low      # High | Medium | Low
approval_required: UNKNOWN  # no (po decides) | owner | clinical | legal
updated: YYYY-MM-DD
---

# D-0 — Short name

## Decision summary
One paragraph: what is decided, the recommendation, and who approves it.

## Context and problem statement
Why the question exists, what it blocks (briefs, status rows, findings), what NAVORA does today (IMPLEMENTED) and the safe default in force.

## Options considered
| Option | What it means | For | Against |
|---|---|---|---|
| A | | | |

## Engineering impact
*(eng <date>)* What is built today (files, migrations, tests); cost and reversibility of each option.

## Clinical impact
*(cra <date>, or "not needed: <reason>")* Hazards and findings; what is a clinical rule here; what only the Clinical Owner can approve.

## Legal/compliance impact
*(lca <date>, or "not needed: <reason>")* Sources; what is settled; what is UNKNOWN; whether the recommended default is compliant under every plausible interpretation.

## Risks and mitigations
| Risk | Mitigation |
|---|---|

## Recommended default for NAVORA
The option, stated so it can be built and tested. Labelled PROVISIONAL where a later answer may change it.

## Recommendation confidence
High / Medium / Low, and why.

## Owner approval required?
**no** (the PO decides: give the reason against each escalation criterion in DECISION_PACKAGES.md) **or yes: <role>**, with exactly what is asked of them and what applies until they answer.
