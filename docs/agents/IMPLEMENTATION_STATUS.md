# Implementation status: Engineering

**Owned by:** Engineering (`eng`) · **Protocol:** [`README.md`](README.md) · **Last change:** 2026-10-21 23:20
Detailed engineering tasks: `docs/engineering/BACKLOG.md` · Technical decisions: `docs/engineering/DECISIONS.md` · Domain view: `docs/engineering/PLATFORM_MAP.md`

## Items

| ID | Origin | State | Summary | Next | PRs | ADRs | Blocked by | Deviations |
|---|---|---|---|---|---|---|---|---|
| F0 | po | in-progress | Per-criterion report published: [`reports/F0.md`](reports/F0.md). Met: 2 (qualifications as data), 3a (anonymous gets nothing), 6 (synthetic data in repo environments). Partial: 1 (repo reproducible, live is legacy), 3c, 4, 5. Gaps: 3d team-scoped clinical read on legacy tables (SR-22), offer fields (→ J2), a "why" on state changes | next: team-scoped clinical read with negative pgTAP (report step 1); PO to confirm which commands need a mandatory reason | – | ADR-017, ADR-018, ADR-019 | – | partner scope N/A until partners get accounts |
| J1 | po | delivered | PO changes: residence (municipality, canton), insurer and insurance type, medical order status and validity, GP named, other providers, requested start; one case per referral; readiness check with reasons; matching request opened by the server only when ready; non-blocking gaps as case tasks; insurer and order data column-protected (intake roles and assigned team only); audited | PO acceptance against `briefs/J1.md`; clinical sign-off of the checklist (D-15); safety alerts wait for the D-17 list | #23, #30 | ADR-026, ADR-029 | D-15, D-17 | insurance type `unknown` counts as missing for readiness (cannot be billed); safety alerts not built until `clinical` sets the D-17 list; partners have no accounts yet, so referrals are recorded by admin/operations only (F0 question) |
| J3 | po | delivered | PO changes: member qualifications as data; care-plan summary per case (KLV category A/B/C, planned minutes, frequency, review date, care goal); planned minutes per category on every visit; needs assessment first (category A, registered nurse); category B only with a present medical order, flagged after its validity end; B and needs-assessment visits started only by a registered nurse (DB-enforced); A/C without order open an "inform GP" task; review-date and uncovered-24h flags; Operations exception for uncovered visits; plan/move/remove keep the original with who and why; care goals, minutes and needs-assessment marker on the `/field` card | PO acceptance against `briefs/J3.md`; clinical sign-off D-15 | #25, #32 | ADR-028, ADR-030 | D-15 | team chooses the KLV category per service; no automatic service→category mapping until D-15; "assigned to a member" implemented as *responsible member* plus the RN check when starting (team assignment, D-6) |
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
