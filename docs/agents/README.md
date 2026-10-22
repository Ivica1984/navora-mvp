# NAVORA agent collaboration layer

**Official** coordination layer between the **Product Owner**, **Engineering** and any future agent, human or AI (approved by the owner on 2026-10-21). The repository is the one place both sides read and write, so nobody depends on a conversation the other side cannot see.

> **Autonomous coordination:** the files below drive hand-off issues and scheduled PO and Engineering agents. See [`COORDINATION.md`](COORDINATION.md).
>
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
| `clinical` | **Clinical & Regulatory Architect** (permanent role, owner 2026-10-22), together with clinical advisers named by the owner | authoritative **review** of patient safety, clinical workflows, care quality, billing integrity, regulatory compliance, LTCF, PAG and MQI; owns the `clinical` decisions in `OPEN_DECISIONS.md` | invent medical, clinical, tariff or regulatory rules (sources or a named qualified person; who signs off is D-27); write code; set PO status; edit `IMPLEMENTATION_STATUS.md` |
| `legal` | Advisers named by the owner | legal questions | — |

### Clinical review gate (owner instruction, 2026-10-22)

- **Scope:** every capability that affects patient care, documentation, billing, quality, assessment, LTCF, PAG or MQI.
- **Report:** the Clinical & Regulatory Architect publishes the **Clinical Governance Report** at `reports/CLINICAL_GOVERNANCE.md`. The newest dated section is the latest report; git keeps the history. Each finding names the item ID, a severity (`blocking` or `advisory`), the evidence and a testable remedy.
- **Before final acceptance** of an item in scope, the PO reads the latest report and records in the brief's evidence table, per finding for that item: considered, and how it was decided.
  - A `blocking` finding leads to `changes-requested` (or a decision for its owner), never to `accepted`.
  - An `advisory` finding may be accepted as a condition, with the reason.
- **No report yet, or none that covers the delivery:** the PO completes its own review but does not set `accepted`; the evidence table says "awaiting clinical review", and the item stays in review.
- **Already accepted items:** acceptances before 2026-10-22 22:10 stand. A later `blocking` finding on one of them leads the PO to set `changes-requested`.
- **The PO still owns** what is built and its order. The Clinical Architect reviews; it does not reorder the queue.

## Rules

1. **The PO owns the queue.** Engineering may *propose* an item: it adds a row to `IMPLEMENTATION_STATUS.md` with origin `eng-proposal` and opens a decision for `po`. The item becomes a priority only when the PO adds it to `NEXT_CAPABILITY.md`.
2. **Every priority is acknowledged.** Each ID in the PO queue has a row in `IMPLEMENTATION_STATUS.md` (CI enforces this). A row with origin `po` must be in the queue or have a published brief in `briefs/` (draft items waiting for the queue).
3. **Disagreement is explicit.** If engineering disagrees with a brief, it opens a decision (`owner: po`) with the reason, the risks and an alternative, and lists it under *Blocked by*. If it builds something different from the brief, the *Deviations* column says what and why.
4. **Blocked names its blocker.** State `blocked` requires decision IDs in *Blocked by*, and those decisions must exist in `OPEN_DECISIONS.md`.
5. **Decisions go to the right owner.** Legal, financial, regulatory, clinical and production questions are owned by `owner`, `legal` or `clinical`, never by `eng` (CI enforces this).
6. **Done means accepted.** Engineering sets `delivered` with PR numbers. The PO checks the brief's acceptance criteria and sets *PO status* to `accepted` or `changes-requested`. For items in clinical scope, acceptance also needs the clinical review gate (*Roles* above).
7. **Leave a trail.** Every session that changes one of these files adds a `JOURNAL.md` entry.
8. **No personal or health data** in this folder.

## Vocabulary (validated)

- **PO status:** `draft` · `approved` · `accepted` · `changes-requested` · `withdrawn`
- **State:** `not-started` · `analysing` · `in-progress` · `in-review` (PR open) · `ready-for-review` / `delivered` (merged with green CI = **READY_FOR_REVIEW**: the PO review starts automatically) · `blocked`
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
| NAVORA PO agent (scheduled, hourly) | `po` | 2026-10-22 |
| NAVORA Engineering agent (scheduled, hourly) | `eng` | 2026-10-22 |
| NAVORA Clinical & Regulatory Architect | `clinical` | 2026-10-22 |
| agents-coordination watcher (GitHub Action) | – (writes issues only) | 2026-10-22 |

Future agents add themselves here in their first PR.
