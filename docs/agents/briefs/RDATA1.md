---
id: RDATA1
title: Aggregated monthly figures of a cooperating Basel nursing home in the Phase A simulation
author: po
status: draft
updated: 2026-11-11
---

# RDATA1 — Aggregated real nursing-home figures for the Phase A comparison (draft)

**Draft 2026-11-11 00:05 CET** under founder decision **FE-055** (6). Stays a draft until (a) `lca` answers L-13, (b) a data agreement with the cooperating home exists (D-42 path), (c) a named home is found by the owner. Built after B0 and BD.

## Problem
The Phase A comparison of temporary costs (`ECONOMICS_COMPARISON.md` §2) rests on secondary sources with a range of 1.1-1.7×. The founder wants NAVORA's simulation compared against a real home's history.

## Users and journey step
Founder, owner, PO (business case); `aia`/`csa` (comparison). Step: Analytics.

## Outcome
The simulation shows, as a labelled scenario, what the home's historical temporary-staff months would have cost with pooled GM-1 teams.

## Acceptance criteria
- [ ] RDATA1-1: only figures per month and home: temporary hours, temporary cost (CHF), number of absences, number of shifts covered by temporary staff. No row about a person, no names, no absence reasons, no dates per person.
- [ ] RDATA1-2: an import refuses any file with columns beyond the agreed list, or with fewer than an agreed minimum count per cell (small-count rule, value set by `lca`).
- [ ] RDATA1-3: the figures are stored apart from synthetic data, labelled "real, aggregated", with source, period and data agreement reference.
- [ ] RDATA1-4: every comparison result is labelled "Szenario, kein Beweis" and lists its assumptions (`ECONOMICS_COMPARISON.md` A1-A5).
- [ ] RDATA1-5: no figure reaches an AI service (D-35 rule A).
- [ ] Negative cases: a person-level file is refused; a team member cannot read the home's figures.

## Rules and their input class
Aggregated institution figures: business data, not personal data, provided RDATA1-1/-2 hold (to be confirmed by `lca`, L-13). No clinical content.

## AI leverage
No AI leverage: the comparison is arithmetic over agreed figures.

## Out of scope
Person-level data of any kind; any use of the figures outside the comparison.

## Constraints and references
FE-021, FE-031 (Phase A synthetic; FE-055 (6) adds only these aggregated figures), D-1, D-35, D-42; L-13.

## Open questions for engineering
None before `lca` answers.
