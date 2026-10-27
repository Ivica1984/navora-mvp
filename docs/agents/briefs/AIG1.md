---
id: AIG1
title: AI governance foundation — every proposal is recorded, confirmed value by value, measured per agent and stoppable
author: po
status: approved
updated: 2026-10-27
---

# AIG1 — AI governance foundation

## Problem
The owner's direction (2026-10-27) makes planning, documentation, billing preparation and coordination increasingly AI-assisted, through the staged path approved the same day (D-35 stages 0-3). Today NAVORA has no place where a machine proposal is recorded, no way to tell a proposed value from a confirmed one, no correction measure and no stop. Every later assistant (PLAN3, A1 referral completeness, A4 invoice draft, A7 dictation) would have to invent these controls on its own, or run without them. The Strategic Alignment Review (dimension 2) rates AI-assisted operations *partial* with "no AI governance infrastructure"; the AI Operating Model Review §8 lists the controls; `cra` D-35 2(a)-(e) and `lca` D-35 terms set their protective shape. Stage 0 is "now, synthetic only": this item is stage 0.

## Users and journey step
Every confirmer of a proposal: the team (PLAN3 day plan), the primary nurse, the referrer, the licence holder. Operations and administrators see the agent health list. Journey: cross-cutting; first consumer Planning (PLAN3). `ARCHITECTURE.md`: minimisation → provider → schema → validation → human review → immutable approved state.

## Outcome
Any NAVORA assistant, rule-based or AI, can propose values; a named person confirms each value before it becomes record content; the record says who proposed and who confirmed; each agent's correction rate is visible per team and field, and the agent stops by itself when it crosses its written threshold. No AI service is called and no real data is used.

## Acceptance criteria
- [ ] **AIG1-1 Agent register.** A table of agents: key, name, level (`L`, `G`, `H`; D-34), kind (`rule` or `ai`), version, provider and region (null for `rule`), state (`off`, `on`, `stopped`), the written stop threshold (below) and who switched it on. Only an administrator of the organisation switches an agent on or off (audited). An agent of kind `ai` cannot be switched on in any environment while D-35 rule A holds: the switch refuses with a stated reason (pgTAP). An agent of level `G` or `H` cannot be switched on (D-34; the clinical module is a separate product, D-34 C).
- [ ] **AIG1-2 Suggestion ledger, append-only.** One row per proposal: agent key and version, the case or team it concerns, the input reference (identifiers of the rows read, never a copy of their content), the proposed values, the time. Update and delete are refused for every role, including the service role used by the app (pgTAP). Retention follows D-4 (no deletion before the final period).
- [ ] **AIG1-3 Provenance per value.** A proposed value becomes record content only through a confirm command by a named person, value by value or by an explicit list of values, each audited with confirmer and time. Each confirmed value carries its suggestion row; the record shows "vorgeschlagen von <Agent> / bestätigt von <Name> am <Datum>". A value the confirmer changes is stored as hers, with the proposal kept in the ledger as `corrected`. Signing a later document (F6) does not confirm a proposed value (pgTAP: a signed report with an unconfirmed proposal still shows it unconfirmed).
- [ ] **AIG1-4 "Not found" is explicit.** An agent that finds no value for a field returns `not_found` with the field name; the screen shows "nicht gefunden", never an empty value, "keine" or a default (unit and pgTAP: `not_found` can be confirmed only as "nicht gefunden", never turned into an empty value).
- [ ] **AIG1-5 No accept-all on listed fields.** A per-organisation list of fields that must be confirmed one by one. **Until the Clinical Owner sets this list (D-17 part 3, G-1), every field of every agent is confirmed one by one** (the most protective default; no list is invented). Test: a bulk confirm containing a listed field is refused; with the default, every bulk confirm of more than one value is refused.
- [ ] **AIG1-6 Scope inheritance.** An agent reads only through the confirmer's own access (RLS2, RLS3): proposals are computed in a call made as the confirming person, or by a job that reads only rows that person may read. pgTAP: a proposal for a case outside the caller's team is refused and writes no ledger row. No new read path; `READ_PATHS.md` updated.
- [ ] **AIG1-7 Correction rate per agent, field and team, never per person.** A read returns, per agent, field and team and per month: proposals, confirmed unchanged, corrected, rejected, `not_found`. No column, filter or export identifies the confirming person (pgTAP: the reader has no person column; a team with fewer than three confirmers in the month is suppressed, as AN1). Readable by the team for its own rows and by Operations for all teams of the organisation.
- [ ] **AIG1-8 Stop rule (P-6).** Each agent carries a written threshold: the correction share above which it stops, over a stated minimum number of proposals, and a window. An agent cannot be switched on without one (refused). When a closed window crosses the threshold, or when its version, provider or region changes without a new switch-on, the agent's state becomes `stopped`, it proposes nothing more, and one OPS1 exception "Assistent gestoppt: <Name>" reaches Operations (existing exception path; no new signal class). Restarting is a new audited switch-on. pgTAP: threshold crossed → `stopped` and no new ledger row; version changed → `stopped`.
- [ ] **AIG1-9 Evaluation harness on synthetic cases.** A test fixture of synthetic cases per agent with expected values; CI runs every switched-on-capable agent against it and fails when the share of matching values falls below the agent's stated evaluation bar. An agent without a fixture cannot be switched on. A synthetic test agent of kind `rule` (for example: propose the case's existing primary nurse for an unassigned visit) proves AIG1-1 to AIG1-9 end to end.
- [ ] **AIG1-10 Agent health list.** Operations and administrators see one list: agent, state, last proposal, last window's correction share, and why it stopped. e2e at 390 px for the confirm screen (one proposed value, "vorgeschlagen von", confirm, change, "nicht gefunden") and at desktop width for the health list.
- [ ] **Negative.** No AI service is called in any test or environment; no client or staff data leaves the database; no person gets a read she did not have; no measure per person; nothing changes an existing record without a confirm command.

## Rules and their input class
- The stop threshold, the minimum number and the window are **per-agent configuration written by the person who switches the agent on**, not a NAVORA default. AIG1 ships no threshold value. For a `rule` agent of level L these are product settings; for anything touching clinical content they are not reachable (level G and H refused, AIG1-1).
- The list of one-by-one fields (AIG1-5) is a clinical safety list owned by the Clinical Owner (D-17 part 3); until named, all fields are one by one.
- AIG1 adds no rule that ranks, routes or escalates a client. The only escalation is "agent stopped" to Operations, input class *visit/schedule fact* (a system state), not a client fact.

## Out of scope
- Any AI service, provider contract or model (D-35 stage 1 needs a new `owner` package: provider, region, contract, DPIA).
- Real data of any kind.
- The agents themselves beyond the synthetic test agent (PLAN3 is the first real consumer).
- Clinical drafting (A7-A10), interRAI content (D-36 A), per-person performance views (never, *Agents not to build*).

## Constraints and references
`docs/product/AI_OPERATING_MODEL_REVIEW.md` §7, §8; `docs/product/STRATEGIC_ALIGNMENT_REVIEW.md` §3 (stage 0), §4; D-35 (rule A in force; `cra` 2(a)-(e); `lca` terms, in particular term 9 no per-person measure); D-34 statement v2 and levels L/G/H; D-17 part 3 (field list, Clinical Owner); D-4 (retention); RLS2, RLS3, `READ_PATHS.md`; AN1 suppression of small teams; OPS1 exception path; hypothesis P-6.

## Open questions for engineering
- Ledger shape: one generic table with typed value payloads, or one table per consuming record type? State the choice in the ADR; whatever is chosen must keep AIG1-2 (append-only) and AIG1-3 (one confirmation per value) testable in pgTAP.
- Where does the evaluation harness live (pgTAP fixtures, vitest, or both)? It must run in CI on every PR that changes an agent.
- Is the AN1 small-team suppression reusable as is for AIG1-7?

**Clinical review gate:** applies (assisted values may later reach documentation and billing). `cra` reviews the merged build; AIG1 itself carries no clinical content.
