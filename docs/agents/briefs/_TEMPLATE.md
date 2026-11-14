---
id: X0                # same ID as in NEXT_CAPABILITY.md
title: Short name
author: po
status: draft          # draft | approved
updated: YYYY-MM-DD
---

# X0 — Short name

## Problem
Who is blocked or under-served today, and how do we know?

## Users and journey step
Which users (nurse, team, operations, coach, partner, …) and which step of the care journey (`ARCHITECTURE.md` data flow).

## Outcome
What is different for the user when this is done. One or two sentences.

## Acceptance criteria
- [ ] Observable, testable statements (Given / When / Then is fine).
- [ ] Include the negative cases (who must NOT be able to do it).

## Rules and their input class
For every rule this item adds or changes (a signal, a threshold, a gate, a priority): its **input class**, one of *visit/schedule fact*, *care-context fact recorded by a person* (a nurse or intake staff; renamed 2026-10-26, D-34 assessment F-2), *clinical content* (D-34, po 2026-10-24 19:09). A rule of the class *clinical content* is not built in the core. A rule of the class *care-context fact recorded by a person* that ranks, routes or escalates (not only displays) is marked **for the adviser**: it may be built and tested on synthetic data, and is not released to real clients before the regulatory adviser's answer (D-34, po 2026-10-24 20:09, after `lca` 19:55). A brief without this section is `changes-requested`.

## AI leverage
*(Required from 2026-11-03, owner directives "AI-first" and "human-in-the-loop is mandatory"; method in `docs/product/AI_FIRST_ARCHITECTURE_UPDATE.md` §0 and §3.)*

Follow the mandatory sequence: **Remove unnecessary work → Apply rules → Monitor continuously → AI prepares → Human reviews → Human decides → Human signs.** Answer each step:
1. **Remove:** which work disappears through the care graph?
2. **Rules:** what is decided by a deterministic, approved rule?
3. **Monitor:** what is watched continuously instead of checked periodically?
4. **AI prepares:** which agent drafts, summarises, prioritises, extracts or suggests? Give its contract: input scope, output and field class, sources, level L/G/H, stop rule.
5. **Human reviews:** who reviews the prepared output, with its sources and "not found" items in view?
6. **Human decides:** who takes the accountable decision?
7. **Human signs:** which signature or required approval stays?

Also state:
- the administrative step removed and its baseline measure (AN3);
- the gate (D-35 stage, D-34 level, Clinical Owner);
- the data used (synthetic only until D-1, D-34 and D-35 allow more);
- what the AI must never do in this item.

**Level H (clinical decision support territory, `cra` CGR-119, 2026-11-03):** a brief with an agent at level H carries the line "D-34 classification: <regulatory adviser's answer, date>" and is not approved while it reads UNKNOWN.

**A brief in which AI makes an accountable decision, replaces a signature or a required approval, or executes clinical judgement is rejected.** "No AI leverage" is valid only with a reason.

## Out of scope
What this item deliberately does not do.

## Constraints and references
Domain rules, legal or clinical constraints, handbook sections, related decisions (`D-…`, `Q…`).

## Open questions for engineering
Anything the PO wants engineering to assess before or during the build.
