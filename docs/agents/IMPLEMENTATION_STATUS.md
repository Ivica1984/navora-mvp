# Implementation status: Engineering

**Owned by:** Engineering (`eng`) · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 18:40
Detailed engineering tasks: `docs/engineering/BACKLOG.md` · Technical decisions: `docs/engineering/DECISIONS.md` · Domain view: `docs/engineering/PLATFORM_MAP.md`

## Items

| ID | Origin | State | Summary | Next | PRs | ADRs | Blocked by | Deviations |
|---|---|---|---|---|---|---|---|---|
| F0 | po | blocked | Not started: the F0 brief is not in the repository, so its content is unknown to engineering | read `briefs/F0.md` when published, propose the approach, build | – | – | COORD-1 | – |
| J1 | po | delivered | `/intake`: admin/operations record referrals, review and convert them into a case (no team) plus an open matching request; provisional consent gate; audited | PO acceptance against `briefs/J1.md` | #23 | ADR-026 | – | built from `ARCHITECTURE.md`/`DOMAIN_RULES` before the brief was visible; to be compared with the brief |
| J2 | po | delivered | `/team`: active teams of the request's region see open requests without client identity; first acceptance assigns the case atomically; declines recorded | PO acceptance against `briefs/J2.md` | #24 | ADR-027 | – | built before the brief was visible; only the hard filters *active team* and *region* are evaluated (no data for the others) |
| J3 | po | delivered | `/team`: members of the case's team plan, move and remove planned visits; visible in `/field`; no dispatcher role | PO acceptance against `briefs/J3.md` | #25 | ADR-028 | – | built before the brief was visible |
| F1-F4 | eng-proposal | delivered | Field tool slice: own-team day view, state machine with append-only events, time corrections, observations and handover | PO decides whether to adopt | #19, #20, #21, #22 | ADR-023, ADR-024, ADR-025 | – | – |
| J4 | eng-proposal | not-started | Team availability and capacity windows; derived capacity replaces the hand-entered `utilization`/`open_slots` (PLATFORM_MAP D5) | waiting for PO prioritisation | – | – | COORD-2 | – |
| F6 | eng-proposal | not-started | Visit report draft → submitted → approved; closes Operations' "report missing" item | needs the approver role and PO prioritisation | – | – | Q4, COORD-2 | – |
| T12 | eng-proposal | blocked | Protected staging (Supabase EU/CH + app host), migrations from CI, synthetic data only | deploy workflow once hosting and secrets exist | – | – | D-2 | – |
| M2 | eng-proposal | blocked | Merge `recovery/main` into `main`; the claude.ai Project syncs `main` | merge commit after branch protection | #3 | – | D-7, D-8 | – |
