# NAVORA agent collaboration layer

**Official** coordination layer between the **Product Owner**, **Engineering** and any future agent, human or AI (approved by the owner on 2026-10-21). The repository is the one place both sides read and write, so nobody depends on a conversation the other side cannot see.

> **Every agent starts here.** Read the three official files, then the newest entries in `JOURNAL.md`. Write only the sections your role owns. Change these files through a pull request like any other change. CI validates them (`npm run agents:check`).

## The official files

| File | Purpose | Owned by |
|---|---|---|
| [`NEXT_CAPABILITY.md`](NEXT_CAPABILITY.md) | **What** to build next and in which order: the PO's priority queue, each item with a brief | **Product Owner** (`po`) |
| [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md) | **How far** each item is: state, PRs, ADRs, next step, deviations from the brief | **Engineering** (`eng`) |
| [`OPEN_DECISIONS.md`](OPEN_DECISIONS.md) | Questions that block or shape work: owner, options, recommendation, what they block, answer | **anyone** opens; **only the named owner** decides |

Supporting files:
- `briefs/<ID>.md`: one engineering brief per priority (PO), from [`briefs/_TEMPLATE.md`](briefs/_TEMPLATE.md).
- [`JOURNAL.md`](JOURNAL.md): hand-off notes, newest first, never edited afterwards (anyone).
- Technical decisions stay as ADRs in `docs/engineering/DECISIONS.md`. Engineering's internal task list stays in `docs/engineering/BACKLOG.md`.

## Roles

| Role | Who | Decides | Must not |
|---|---|---|---|
| `po` | Product Owner (a person, or an agent acting for them) | **what** is built and its order; accepts or rejects delivered items | edit the engineering state |
| `eng` | Engineering (Lead Engineer agent, future engineering agents) | **how** it is built (ADRs) | reorder or invent priorities; accept its own work |
| `owner` | Company owner | business, financial, regulatory questions; production risk | — |
| `legal`, `clinical` | Advisers named by the owner | legal or clinical questions | — |

## Rules

1. **The PO owns the queue.** Engineering may *propose* an item: it adds a row to `IMPLEMENTATION_STATUS.md` with origin `eng-proposal` and opens a decision for `po`. The item becomes a priority only when the PO adds it to `NEXT_CAPABILITY.md`.
2. **Every priority is acknowledged.** Each ID in the PO queue has a row in `IMPLEMENTATION_STATUS.md` (CI enforces this).
3. **Disagreement is explicit.** If engineering disagrees with a brief, it opens a decision (`owner: po`) with the reason, the risks and an alternative, and lists it under *Blocked by*. If it builds something different from the brief, the *Deviations* column says what and why.
4. **Blocked names its blocker.** State `blocked` requires decision IDs in *Blocked by*, and those decisions must exist in `OPEN_DECISIONS.md`.
5. **Decisions go to the right owner.** Legal, financial, regulatory, clinical and production questions are owned by `owner`, `legal` or `clinical`, never by `eng` (CI enforces this).
6. **Done means accepted.** Engineering sets `delivered` with PR numbers. The PO checks the brief's acceptance criteria and sets *PO status* to `accepted` or `changes-requested`.
7. **Leave a trail.** Every session that changes one of these files adds a `JOURNAL.md` entry.
8. **No personal or health data** in this folder.

## Vocabulary (validated)

- **PO status:** `draft` · `approved` · `accepted` · `changes-requested` · `withdrawn`
- **State:** `not-started` · `analysing` · `in-progress` · `in-review` · `delivered` · `blocked`
- **Origin:** `po` · `eng-proposal`
- **Decision owner:** `po` · `eng` · `owner` · `legal` · `clinical`
- **Decision kind:** `product` · `technical` · `legal` · `financial` · `regulatory` · `clinical` · `production`
- **IDs:** priorities and status share the PO's ID (e.g. `F0`, `J1`). Decisions are `D-n` (owner, legal or clinical), `Qn` (product questions) and `COORD-n` (coordination); the same IDs appear in `docs/engineering/`.

## Table formats

The validator reads the first Markdown table under the named heading. Keep the column order; add rows freely.
- `NEXT_CAPABILITY.md` → `## Priority queue`: `Rank | ID | Capability | PO status | Brief | Why`
- `IMPLEMENTATION_STATUS.md` → `## Items`: `ID | Origin | State | Summary | Next | PRs | ADRs | Blocked by | Deviations`
- `OPEN_DECISIONS.md` → `## Open`: `ID | Owner | Kind | Question | Recommendation | Blocks | Opened`; and `## Decided`: `ID | Owner | Answer | Date`

Multiple values are comma-separated. Use `–` for none. PRs are written as `#23`.

## Participants

| Name | Role | Since |
|---|---|---|
| Lead Engineer (Claude) | `eng` | 2026-10-21 |
| Product Owner | `po` | 2026-10-21 |
| Owner (Ivica1984) | `owner` | 2026-10-21 |

Future agents add themselves here in their first PR.
