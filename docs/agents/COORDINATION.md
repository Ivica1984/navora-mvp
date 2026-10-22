# Coordination workflow (autonomous PO ↔ Engineering) — COORD-4

Approved by the owner on 2026-10-22: *"The user should no longer be required as a messenger between Product Owner and Engineering."* Architecture decision: ADR-039 in `docs/engineering/DECISIONS.md`.

## Principle

The three official files stay the **single source of truth**. Nothing new is decided anywhere else:

| File | Owner | Signal it carries |
|---|---|---|
| `NEXT_CAPABILITY.md` | PO | what is approved, in which order; `accepted` / `changes-requested` |
| `IMPLEMENTATION_STATUS.md` | Engineering | `in-review` (PR open), `ready-for-review` or `delivered` (= **READY_FOR_REVIEW**: merged, CI green) |
| `OPEN_DECISIONS.md` | named owner | open questions, who must answer, what they block |

A **watcher** turns the state of these files into **hand-off issues** on GitHub. **Scheduled agents** (PO, Engineering) wake up, pick up the issues addressed to them, act through pull requests, and thereby change the files again. People are only pulled in for decisions they own.

```
 PO agent ──PR──▶ NEXT_CAPABILITY.md ─┐                     ┌─▶ [Engineering] issues ──▶ Engineering agent
                                      ├─▶ agents-coordination ├─▶ [PO review] issues   ──▶ PO agent
 Eng agent ─PR──▶ IMPLEMENTATION_     │   (GitHub Action,     └─▶ [Decision …] issues ──▶ owner / clinical / legal
                  STATUS.md ──────────┤    on push + hourly)            (assigned)              or the PO agent
 anyone ────PR──▶ OPEN_DECISIONS.md ──┘
```

## Hand-offs (computed, never typed by hand)

| Key | Opens when | Closes when | Label |
|---|---|---|---|
| `eng:<ID>` | PO status `approved` (queue or *Next up*) and state not `in-review`/`delivered`; or `changes-requested` and the PO spoke after Engineering's last state change | Engineering sets `in-review`/`delivered`, or the PO accepts/withdraws | `agent:eng` (+ `active`, `blocked`) |
| `po:<ID>` | state `ready-for-review` or `delivered` and PO status not `accepted`/`withdrawn` (after `changes-requested`: only when Engineering delivered again later) | PO sets `accepted` or `changes-requested` | `agent:po` |
| `decision:<ID>` | the decision is in *Open* | it moves to *Decided* | `human-decision` (assigned to the owner) or `agent:po` / `agent:eng` |

- **Active capability:** the highest-ranked `eng:` hand-off without open blockers carries the label `active`. When the PO accepts an item, its hand-offs close with a comment, and the next approved item becomes `active` with a comment: **acceptance activates the next capability automatically.**
- **Blockers:** decisions named in the item's *Blocked by* column, plus open decisions whose *Blocks* column names the item. A blocked item is labelled `blocked` and lists the owners; it never becomes active.
- **Who spoke last:** the watcher reads the git history of the two files to know whether the PO's last status change is newer than Engineering's (needed after `changes-requested`).

## Components

| Component | Where | What |
|---|---|---|
| Planner (pure, unit-tested) | `scripts/agents-coordination/plan.mjs`, `parse.mjs` | layer → desired hand-offs; diff against existing issues |
| Watcher | `scripts/agents-coordination/run.mjs` | syncs GitHub issues: create, update labels, comment on activation, close with the reason. `--dry-run` prints the plan |
| Workflow | `.github/workflows/agents-coordination.yml` | runs the watcher on every push that touches the three files, **hourly**, and on demand |
| PO agent | scheduled cloud task "NAVORA PO agent" (hourly) | reviews `agent:po` issues, answers `po` decisions, publishes the queue — through `po/…` PRs |
| Engineering agent | scheduled cloud task "NAVORA Engineering agent" (hourly) | implements the `active` `agent:eng` issue, fixes CI, merges when green, updates status — through `feat/…` PRs |
| Validator | `scripts/agents-check.mjs` (CI) | keeps the files machine-readable; the watcher refuses to run on an invalid layer |

## Rules for agents

1. **Claim before work.** (The watcher manages only its own labels and never removes `claimed`.) Comment `claimed by <role> <session or name> at <time>` on the hand-off issue and add the label `claimed`. Another agent skips an issue claimed less than **3 hours** ago. Remove the label when you stop without finishing.
2. **One open PR per role and item.** If a PR for the item is already open, continue it (fix CI, answer review) instead of starting another.
3. **Write only your own file sections** (README *Roles*). The PO never edits `IMPLEMENTATION_STATUS.md`; Engineering never edits `NEXT_CAPABILITY.md`.
4. **Merge only your own role's PRs, only with green CI.** Documentation PRs of the PO are merged by the PO agent.
5. **Stop rules are unchanged:** legal, compliance, financial, regulatory or irreversible production questions become decisions for their owner; an agent never answers them.
6. **Clinical review gate (owner, 2026-10-22, D-27):** before Engineering delivers, and before the PO accepts, any item affecting patient care, documentation, billing, quality, assessment, LTCF, PAG or MQI, each reads the latest Clinical Governance Report (`reports/CLINICAL_GOVERNANCE.md`), as described in README *Clinical review gate*. The Clinical & Regulatory Architect is a mandatory reviewer. Its findings are recommendations; only the named human clinical owner approves clinical rules. Engineering also checks scope when it claims an item, writes a remediation plan (`clinical/remediation/<finding ID>.md`) before proceeding when a finding creates a safety, billing or regulatory risk, and names the findings in the PR and journal (README *Clinical review gate*).
7. **Leave a trail:** every run that changes the files adds a `JOURNAL.md` entry (Europe/Zurich time).

## Turning it off or changing the pace

- Pause an agent: disable its scheduled task. The watcher keeps the issues current; nothing is lost.
- Run the watcher now: *Actions → agents-coordination → Run workflow*.
- Alternative wake-up (not enabled): the Claude Code GitHub Action can react to `agent:*` issues directly. It needs an `ANTHROPIC_API_KEY` repository secret, an owner decision about credentials and cost.

## Scheduled agents (cloud)

| Task | ID | Schedule | Approvals |
|---|---|---|---|
| NAVORA Engineering agent | `trig_01CGegWNTJx5JxuJNgzAALLv` | hourly at :09 (UTC cron, `9 * * * *`) | automatic |
| NAVORA Product Owner agent | `trig_01U1UUGgFvyWnuuK9a5JpUvr` | hourly at :09 (UTC cron, `9 * * * *`) | automatic |

Their full instructions mirror the rules above. Changing an instruction means updating this file and the task.

## How it is tested

| Level | What | Where |
|---|---|---|
| Unit | approve → active implement hand-off; READY_FOR_REVIEW (`ready-for-review` or `delivered`) → PO review; `in-review` → none; accept → hand-offs close and the next item becomes active; changes-requested with who-spoke-last; *Next up* ranking; blockers; decision routing; draft and withdrawn; idempotent diff; the real files parse | `tests/unit/agents-coordination.test.ts` (CI) |
| Dry run | `node scripts/agents-coordination/run.mjs --dry-run` prints the plan for the current files without touching GitHub | local or CI |
| Live | the workflow runs on every push to the three files and hourly; each run logs the active capability and every hand-off | *Actions → agents-coordination* |
