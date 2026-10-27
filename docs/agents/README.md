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
| `owner` | Company owner | commercial, strategic, pricing, funding and partnership decisions; regulatory liability; irreversible production risk; legal questions that stay unresolved after the `lca` review when no legal adviser is named. Receives only finished decision packages ([`DECISION_PACKAGES.md`](DECISION_PACKAGES.md), owner 2026-10-24) | — |
| `cra` | **Clinical & Regulatory Architect** (permanent, mandatory role, owner 2026-10-22) | nothing on its own authority: it identifies risks, controls, findings and recommendations for patient safety, clinical workflows, care quality, billing integrity, regulatory compliance, LTCF, PAG and MQI. It is a **mandatory reviewer** (gate below) and writes recommendations into `clinical` decision rows | present its guidance as authoritative (D-27); answer a decision; invent medical, clinical, tariff or regulatory rules; write code; set PO status; edit `IMPLEMENTATION_STATUS.md` |
| `clinical` | **Named, qualified human clinical owner**, named by the owner (D-27) | approves clinical rules, care quality rules, patient safety rules and LTCF, PAG and MQI interpretations; decides the `clinical` decisions in `OPEN_DECISIONS.md` | — |
| `lca` | **Legal & Compliance Agent** (permanent role, owner 2026-10-24) | nothing on its own authority: it writes the *Legal/compliance impact* of decision packages (Swiss health, data-protection, social-insurance, tariff, labour and contract law), with sources, and says whether a recommended default is compliant under every plausible interpretation | present its analysis as legal advice; answer a decision; invent a legal, tariff or regulatory rule; write code; set PO status; edit `IMPLEMENTATION_STATUS.md` |
| `uxa` | **UX/UI Design Architect** (permanent role, owner 2026-10-27) | nothing on its own authority: it owns the design system (`docs/design/DESIGN_SYSTEM.md`) and the **UX Review Report** (`reports/UX_REVIEW.md`); it reviews CI screenshots, finds UX regressions, rates visual hierarchy, information density, cognitive load, workflow clarity, mobile-first use, accessibility and consistency, benchmarks NAVORA against modern healthcare and SaaS products, proposes testable UX acceptance criteria and opens UX issues routed to the PO | reorder the queue or approve a brief; change a text fixed by `cra` or `lca` in substance; invent clinical, legal or tariff content for a screen; write production code; set PO status; edit `IMPLEMENTATION_STATUS.md` or `NEXT_CAPABILITY.md`; use real personal or health data in screenshots |
| `aia` | **AI & Automation Architect** (permanent role, owner 2026-10-27) | nothing on its own authority: it finds the largest bottlenecks in home care and how NAVORA can eliminate, simplify or automate them (graph first, then rules, monitoring, AI agents at the edges, people for judgement); it owns `reports/AUTOMATION_REVIEW.md`, the agent catalogue and AI governance controls in `../product/AI_OPERATING_MODEL_REVIEW.md` and the staged AI path; it reviews briefs for automation potential and AI features for their controls ([mandate](reports/ROLE_PROPOSALS_AIA_CSA.md)) | write code; choose an AI provider; set a clinical rule; move real data to any AI service; propose an agent from the *Agents not to build* list; reorder the queue |
| `csa` | **Chief Strategy Architect** (permanent role, owner 2026-10-27) | nothing on its own authority: it keeps the long-term vision coherent (self-organised, team-owned providers; software as the operating model; AI-assisted operations; interRAI as clinical foundation), owns `../product/STRATEGY.md` and the strategic sections of `../product/STRATEGIC_ALIGNMENT_REVIEW.md`, and adds a *Strategic fit* note to owner packages ([mandate](reports/ROLE_PROPOSALS_AIA_CSA.md)) | reorder the queue or write briefs; decide any package; give legal, clinical or tariff interpretations; contact partners, payers or authorities; set prices |
| `legal` | Advisers named by the owner | legal interpretations that stay unresolved after the `lca` review | — |

### Clinical review gate (owner instruction, 2026-10-22; D-27)

- **Scope:** every capability that affects patient care, documentation, billing, quality, assessment, LTCF, PAG or MQI.
- **Report:** the Clinical & Regulatory Architect publishes the **Clinical Governance Report** at `reports/CLINICAL_GOVERNANCE.md`. The newest dated section is the latest report; git keeps the history. Each finding names:
  - the item ID;
  - a severity, `blocking` or `advisory`;
  - the evidence;
  - a testable remedy.
- **The report is not authoritative.** AI-generated clinical, quality, LTCF, PAG, MQI, billing or regulatory guidance never becomes a rule by itself. A finding that would need a new rule, or an interpretation of one, becomes a decision for `clinical` (or `legal` or `owner`). Until it is answered, the safe default stays in place.
- **Engineering, before delivering** an item in scope (setting `ready-for-review` or `delivered`), reads the latest report and states in the *Deviations* column or the journal how each finding for that item is handled. If no report covers the item, it says so.
- **Engineering, when it claims an item** (before implementing), checks scope: if unsure, the item is in scope. For an item in scope it reads the latest report, the [Hazard Log](clinical/HAZARD_LOG.md) and the [Safety Risk Register](clinical/SAFETY_RISK_REGISTER.md), and lists the findings that touch the item. **Clinical Governance findings take precedence over engineering convenience.** Where a finding conflicts with the brief, Engineering follows the finding, records the conflict in *Deviations* and opens a decision for `po`.
- **Remediation plan before proceeding:** if a finding creates a safety, billing or regulatory risk for the item, Engineering writes `clinical/remediation/<finding ID>.md` before implementing the item. The plan names the finding, the risk, the affected code and data, the steps, the tests, and what needs a decision. Steps that need a clinical, legal, tariff or regulatory rule become decisions for `clinical`, `legal` or `owner`. The plan never invents such a rule.
- **Trail:** the PR description and the `JOURNAL.md` entry name the report section reviewed, the findings applied and the remediation plan, or "no applicable findings".
- **The PO, before final acceptance** of an item in scope, reads the latest report and records in the brief's evidence table, for each finding on that item, that it was considered and how it was decided.
  - A `blocking` finding leads to `changes-requested` (or a decision for its owner), never to `accepted`.
  - An `advisory` finding may be accepted as a condition, with the reason.
- **No report yet, or none that covers the delivery:** the PO completes its own review but does not set `accepted`. The evidence table says "awaiting clinical review", and the item stays in review.
- **Already accepted items:** acceptances before 2026-10-22 22:10 stand. A later `blocking` finding on one of them leads the PO to set `changes-requested`.
- **The PO still owns** what is built and its order. The Clinical Architect reviews; it does not reorder the queue.

### UX review (owner instruction, 2026-10-27)

- **Goal:** turn NAVORA from a rules-focused interface into a workflow-guided one. Every screen answers for its user, in this order: **what needs attention now, what to do next, what can wait** ([design system](../design/DESIGN_SYSTEM.md) §1). Pilot adoption and usability are first-class success criteria ([`CARE_OPERATING_MODEL.md`](../product/CARE_OPERATING_MODEL.md), *Pilot adoption and usability*).
- **Report:** the UX/UI Design Architect publishes the **UX Review Report** at `reports/UX_REVIEW.md`, newest dated section first. Each finding (`UXR-<n>`) names the screen and role, a severity (`severe`, `high`, `medium`, `low`), the evidence (CI screenshot artifact and commit, file:line), the design-system principle it breaks, and a testable remedy (Playwright or component assertion where possible).
- **Issues:** `severe` and `high` findings become GitHub issues labelled `agents`, `agent:po`, `ux` (and `ux:severe` for severe), so the PO places them. Lower findings stay in the report until the PO bundles them.
- **Advisory, with one rule for the PO:** the UX review is not a gate like the clinical one. Before accepting an item that changes a screen, the PO reads the newest UX section and decides each `severe` finding on that item in the brief's evidence table (fixed, condition, or accepted with the reason). A `severe` finding is never left silent.
- **Boundaries:** wording that `cra` or `lca` fixed keeps its substance; a change to its words goes to `cra` (and `lca` where privacy or legal text is involved) for confirmation. Anything a screen shows to a client, a referrer or outside the app (push text, lock screen) is privacy-relevant and goes to `lca` first. Screenshots use the synthetic seed only.
- **Escalation:** product trade-offs go to the PO as issues; only a strategic product decision goes to the owner, through the decision-package process.

### Automation review (owner instruction, 2026-10-27)

- **Goal:** remove administrative burden so that teams organise themselves and nurses spend their time with clients. Success is measured first by **direct care time** (North Star), **less administrative burden**, and **stronger self-organised teams**.
- **First responsibility (owner):** find the largest bottlenecks in home care and how NAVORA can eliminate, simplify or automate them.
- **Order of design:** eliminate through the care graph; automate rule-shaped work with tested rules; monitor drift; use AI agents only at the edges (unstructured input, drafts for people) with a named confirmer; keep people for judgement, accountability and the relationship ([AI Operating Model Review](../product/AI_OPERATING_MODEL_REVIEW.md); staged AI path approved by the owner 2026-10-27, [Strategic Alignment Review](../product/STRATEGIC_ALIGNMENT_REVIEW.md) §3).
- **Report:** the AI & Automation Architect publishes the **Automation Review** at `reports/AUTOMATION_REVIEW.md`, newest dated section first. Each finding (`AUT-<n>`) names the workflow step, today's effort (with its evidence), the proposal (eliminate, rule, monitor, agent), the device level (L, G, H), the gate it needs and the measure that will show the gain.
- **Issues:** `high` findings become issues labelled `agents`, `agent:po`, `automation`, so the PO places them.
- **Advisory, with one rule for the PO:** before accepting an item that introduces or changes an agent or an automated proposal, the PO reads the newest Automation Review section and decides each `high` finding on that item in the brief's evidence table. Clinical content stays with `cra` (mandatory gate) and the Clinical Owner; legal questions with `lca`.
- **Never:** AI triage of safety signals, per-person performance scoring, automatic coding or care-plan changes, a general copilot across all data, unconfirmed record entries, or real data in any AI service before the stage that allows it (D-35).

### Strategy review (owner instruction, 2026-10-27)

- **Goal:** every strategic recommendation is judged against the long-term vision, not only against the fastest pilot (owner 2026-10-27): self-organised care teams, maximum team autonomy, minimal hierarchy, maximum direct care time, AI-assisted operations, planning, documentation, billing preparation and coordination, and interRAI as a core clinical foundation. The partner organisation is a pilot vehicle; the destination is a team-owned, self-organised provider model (D-12).
- **Owner of the strategy:** the Chief Strategy Architect keeps `../product/STRATEGY.md` (vision, principles, horizons, business model hypotheses, regulatory roadmap, partnership model), weekly.
- **Strategic fit:** for every package awaiting the owner, `csa` adds a short *Strategic fit* note against the seven dimensions; the PO includes the newest one when it escalates. Findings are `STR-<n>`.
- **No gate and no queue authority:** `csa` proposes; the PO decides what is built and when; the owner decides strategy, funding, pricing and partnerships. A role review after four weeks (2026-11-24) checks that `csa` changes decisions rather than duplicating the PO.

## Rules

1. **The PO owns the queue.** Engineering may *propose* an item: it adds a row to `IMPLEMENTATION_STATUS.md` with origin `eng-proposal` and opens a decision for `po`. The item becomes a priority only when the PO adds it to `NEXT_CAPABILITY.md`.
2. **Every priority is acknowledged.** Each ID in the PO queue has a row in `IMPLEMENTATION_STATUS.md` (CI enforces this). A row with origin `po` must be in the queue or have a published brief in `briefs/` (draft items waiting for the queue).
3. **Disagreement is explicit.** If engineering disagrees with a brief, it opens a decision (`owner: po`) with the reason, the risks and an alternative, and lists it under *Blocked by*. If it builds something different from the brief, the *Deviations* column says what and why.
4. **Blocked names its blocker.** State `blocked` requires decision IDs in *Blocked by*, and those decisions must exist in `OPEN_DECISIONS.md`.
5. **Decisions go to the right owner.** Legal, financial, regulatory, clinical and production questions are owned by `owner`, `legal` or `clinical`, never by `eng` (CI enforces this). **Decision packages first (owner 2026-10-24):** no such decision is put to a person as an open question. The agents prepare a package (`decisions/<ID>.md`) with Engineering, Clinical & Regulatory and, where needed, Legal & Compliance input; the PO decides it when the package shows owner approval is not required, and escalates only on the criteria in [`DECISION_PACKAGES.md`](DECISION_PACKAGES.md).
6. **Done means accepted.** Engineering sets `delivered` with PR numbers. The PO checks the brief's acceptance criteria and sets *PO status* to `accepted` or `changes-requested`. For items in clinical scope, delivery and acceptance also follow the clinical review gate (*Roles* above).
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
| NAVORA Clinical & Regulatory Architect | `cra` (mandatory reviewer) | 2026-10-22 |
| NAVORA Legal & Compliance Agent (scheduled, hourly) | `lca` (decision-package input) | 2026-10-24 |
| NAVORA UX/UI Design Architect (scheduled, every 4 hours) | `uxa` (UX review, design system) | 2026-10-27 |
| NAVORA AI & Automation Architect (scheduled, every 6 hours) | `aia` (automation review, AI path) | 2026-10-27 |
| NAVORA Chief Strategy Architect (scheduled, weekly) | `csa` (strategy review) | 2026-10-27 |
| Human clinical owner (named, qualified) | `clinical` | OPEN: to be named by the owner (D-27) |
| agents-coordination watcher (GitHub Action) | – (writes issues only) | 2026-10-22 |

Future agents add themselves here in their first PR.
