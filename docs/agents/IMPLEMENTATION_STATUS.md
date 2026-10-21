# Implementation status: Engineering

**Owned by:** Engineering (`eng`) · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 22:10
Detailed engineering tasks: `docs/engineering/BACKLOG.md` · Technical decisions: `docs/engineering/DECISIONS.md` · Domain view: `docs/engineering/PLATFORM_MAP.md`

## Items

| ID | Origin | State | Summary | Next | PRs | ADRs | Blocked by | Deviations |
|---|---|---|---|---|---|---|---|---|
| F0 | po | analysing | Acceptance frame over T8–T10 plus J1–J3 access rules; per-criterion evidence report in progress | report each F0 criterion here (tests that cover it, gaps, new tests); first gap known: member qualifications as data, delivered with J3 | – | ADR-017, ADR-018, ADR-019 | – | – |
| J1 | po | in-review | PO changes: residence (municipality, canton), insurer and insurance type, medical order status and validity, GP named, other providers, requested start; one case per referral; readiness check with reasons; matching request opened by the server only when ready; non-blocking gaps as case tasks; insurer and order data column-protected (intake roles and assigned team only); audited | CI and PO acceptance against `briefs/J1.md`; clinical sign-off of the checklist (D-15); safety alerts wait for the D-17 list | #23 | ADR-026, ADR-029 | D-15, D-17 | insurance type `unknown` counts as missing for readiness (cannot be billed); safety alerts not built until `clinical` sets the D-17 list; partners have no accounts yet, so referrals are recorded by admin/operations only (F0 question) |
| J3 | po | in-progress | PO changes: care-plan summary per case (category A/B/C, planned minutes, frequency, review date, goals); planned minutes per category on each visit; needs-assessment visit first; category B only with a valid medical order and only performed by a registered nurse; A/C without order create an "inform GP" task; review-date flags; care goals on the `/field` card | finish on top of J1, then CI | #25 | ADR-028 | D-15 | – |
| F6 | po | not-started | Signed visit report (performing nurse signs; countersignature rule D-10) | after J1/J3 per queue rank 4 | – | – | D-10 | – |
| J2 | po | not-started | PO changes: response time per referral type, escalation, decline reasons, qualification check | after F6 per queue rank 5; values from Q8 | #24 | ADR-027 | Q8 | – |
| F1-F4 | po | delivered | Field tool slice: own-team day view, state machine with append-only events, time corrections, observations and handover. **Accepted by the PO 2026-10-21** | care goals (J3) and safety alerts (J1, D-17) on the card follow | #19, #20, #21, #22 | ADR-023, ADR-024, ADR-025 | – | – |
| QG1 | po | not-started | Quality signals and quality hold (draft brief) | waits for the PO queue | – | – | D-16 | – |
| OPS1 | po | not-started | Operations exception center (draft brief) | waits for the PO queue | – | – | Q9 | – |
| J5 | po | not-started | Billable visit facts and monthly revenue preview (draft brief) | waits for the PO queue; needs F6 and QG1 | – | – | D-12 | – |
| J6 | po | not-started | Continuity of care: primary nurse (draft brief) | waits for the PO queue | – | – | D-6 | – |
| J7 | po | not-started | Team economics transparency (draft brief) | waits for the PO queue; needs J5 | – | – | D-14 | – |
| J4 | eng-proposal | not-started | Team availability and capacity windows | deferred by the PO to Gate 5 | – | – | – | – |
| T12 | eng-proposal | blocked | Protected staging (Supabase EU/CH + app host), migrations from CI, synthetic data only | deploy workflow once hosting and secrets exist | – | – | D-2 | – |
| M2 | eng-proposal | blocked | Merge `recovery/main` into `main`; the claude.ai Project syncs `main` | merge commit after branch protection | #3 | – | D-7, D-8 | – |
