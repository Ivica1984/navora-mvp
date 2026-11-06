---
id: AN3
title: Where the non-care time goes: per-step spans per team (P-19)
author: po
status: approved
updated: 2026-11-03
---

# AN3 — Where the non-care time goes: per-step spans per team (P-19)

**Status: approved 2026-11-03 14:00 (owner directive: allowed on synthetic data only; Next up 3).** `lca`'s read against D-23 term (b) remains required before any real data (G-19). *Earlier:* draft (po 2026-11-03 06:30). Written from hypothesis P-19 (PO 2026-10-27 15:20: "brief once AIG1 is built"; AIG1 accepted 2026-10-30 22:15) after `aia` AUT-32 (review 18, 2026-11-03 02:40, medium). **Before approval:** `lca` reads it against D-23 term (b) (staff timestamps aggregated per team; no use of the WORK1 tables beyond WORK1-6). `cra` 05:30 caution (countersign latency never a target) is already written in. The PO approves it once `lca` finds it compliant under every plausible interpretation; it then goes to *Next up* after PLAN3, and must be built before G-19 so that the pilot's first month is the baseline.

## Problem
The North Star (WORK1-6) shows per team and month how much confirmed paid time is direct care. It does not show **where the rest goes**. The three largest estimated bottlenecks in `aia`'s map v2 (travel and day order; documentation and countersign; GP orders and referrals) each wait for a decision (Q7 and D-11; D-10 with G-1; D-22, D-9, D-3), and none has a measured before-value. When one of them is unblocked during the pilot, NAVORA cannot show the gain, and the owner's success measure "less administration" has no number per step. Every timestamp needed already exists in NAVORA; nothing new has to be tapped or typed.

## Users and journey step
The team (sees its own figures on `/analytics`), the PO and the owner (decide which bottleneck to unblock first), Operations only as a reader of team aggregates. Journey steps: Referral → Case (J1), Documentation (F6, F7, countersign), Orders (ORD0), Team Decision and Planning (AIG1/PLAN3). Read-only extension of AN1.

## Outcome
`/analytics` shows, per team and month, the median span of each administrative step that NAVORA already timestamps, beside the care share, with the same suppression as AN1. The pilot's first month becomes the baseline for every later decision that removes a step.

## Acceptance criteria
- [ ] **AN3-1 Spans, per team and month, medians with base count.** `pilot_kpis` (or one new read-only function with the same access as AN1) returns, per team and calendar month (Europe/Zurich): (a) visit end → report signed (F6/F7; exists in AN1 as "end of visit to final report": reuse, do not duplicate); (b) report signed → countersigned, for reports that need a countersignature; (c) J1 partner request received → case ready; (d) ORD0 task opened → done, and the number of ORD0 tasks open at month end with their median age; (e) AIG1 proposal created → decided (confirmed, changed or rejected), from the AIG1 ledger, decided proposals only (expired ones counted apart, AIG1-C4). Each figure carries its base count and period. Engineering names the exact source columns in the ADR; **no new column, table, field or tap** is added to any care record.
- [ ] **AN3-2 Travel beside the care share.** The existing AN1 travel share within visits is shown in the same block as the WORK1-6 care share (rank 1 of the map), labelled as travel within visits only (return trips and travel between days are not measured).
- [ ] **AN3-3 Never per person.** No figure is computed or returned per member; no new read has a person key in its result. The catalogue check (as in RLS4 pgTAP 099 / LEAVE1-3) finds no person column in any new read. Negative: a team member, a coordinator, a coach and an administrator each read only team and organisation aggregates.
- [ ] **AN3-4 Suppression.** AN1's rule applies to every new figure: value **and** base hidden below 3 persons in the team, figures from fewer than 5 events marked "zu wenig Daten"; the organisation row follows the AN1 condition (no organisation value that reveals a hidden team). pgTAP: a two-person team returns no value; a team with 4 events of a kind returns "zu wenig Daten".
- [ ] **AN3-5 Countersign latency is a fact, never a target (`cra` 2026-11-03 05:30).** Figure (b) is shown only beside the same team's share of returned reports (F6R-9) and its share of visits with a time correction in the period (*po 2026-11-03 22:00: wording aligned to what is built; time corrections have no open state; `cra` 21:30 confirmed this meets AN3-5*); it has no reference value, colour scale, ranking or goal, and no text calls a shorter span better. String test: the label and its note contain no target word ("Ziel", "Soll", "besser", "zu langsam").
- [ ] **AN3-6 No WORK1 reading beyond WORK1-6 (D-23 term (b)).** No new read touches the WORK1 day or segment tables; the care share stays the WORK1-6 figure as built. pgTAP or catalogue test: the new function's dependencies include no WORK1 table.
- [ ] **AN3-7 Tests on the synthetic seed.** pgTAP returns each span per team for a fixture with known timestamps (exact medians); a test clock (`private.now()`) is used for month boundaries; e2e at 390 px and 1440 px: the block shows each figure with period and base, or "zu wenig Daten".

## Rules and their input class
- AN3-1 spans: *visit/schedule fact* (timestamps NAVORA records when a person acts); display only, no ranking, routing or escalation.
- AN3-4 suppression: reused AN1 rule; no new threshold.
- AN3-5: display constraint, no clinical rule. Whether a countersign span has a clinical target is the Clinical Owner's (D-10); NAVORA sets none.

## AI leverage
- **1 Remove:** no new tap. The spans come from timestamps the record already holds.
- **2 Rules:** medians, base counts and suppression are deterministic (AN1 rule).
- **3 Monitor:** the spans are recomputed continuously per team and month, so no periodic report is compiled by hand.
- **4 AI prepares:** none in this item. AN3 is the baseline every later AI capability is measured against (AI-12). An agent that removes a step is judged by the change in its span.
- **5-7 Human reviews, decides, signs:** the team and the PO read the figures and decide what to change. Nothing is signed.
- **Data:** synthetic only (owner directive 2026-11-03).
- **Never:** a figure per person, a target, or a ranking.

## Out of scope
- Any new timestamp, stopwatch, self-report or "time spent" field; minutes per step inside a working day (stays UNKNOWN until a step is measured by its own events).
- Calls with GPs, hospitals or relatives (not recorded; stays UNKNOWN).
- Any per-person view, export or comparison between members; any target or alert on a span.
- Benchmarks against Buurtzorg or any external figure (no comparable Swiss per-step data found, `aia` [E3]).

## Constraints and references
- P-19 (challenge table, `NEXT_CAPABILITY.md`); `aia` AUT-3, AUT-32 (`reports/AUTOMATION_REVIEW.md` review 18); AN1 (suppression, condition), AN2, WORK1-6 (D-23 option D), AIG1 ledger and AIG1-C4 (expired proposals), F6R-9, ORD0, J1.
- D-23 term (b) (`lca`), D-10 (countersign scope, Clinical Owner), owner rule 2026-10-29 (synthetic data only until D-1 is clarified).
- Balancing measure (P-5): returned-report share (F6R-9) and open time corrections shown beside the documentation spans.

## Open questions for engineering
- Which source column carries each start and end (AN3-1 (a)-(e)); where a step has no reliable start timestamp, say so in the ADR and leave that figure out rather than approximate it.
- Whether AN3 fits into `pilot_kpis` or needs a separate read-only function with the same grants.
