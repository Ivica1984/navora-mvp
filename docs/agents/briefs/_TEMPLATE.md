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
For every rule this item adds or changes (a signal, a threshold, a gate, a priority): its **input class**, one of *visit/schedule fact*, *care-context fact recorded by a nurse*, *clinical content* (D-34, po 2026-10-24 19:09). A rule of the class *clinical content* is not built in the core. A brief without this section is `changes-requested`.

## Out of scope
What this item deliberately does not do.

## Constraints and references
Domain rules, legal or clinical constraints, handbook sections, related decisions (`D-…`, `Q…`).

## Open questions for engineering
Anything the PO wants engineering to assess before or during the build.
