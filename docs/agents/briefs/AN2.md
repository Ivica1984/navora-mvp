---
id: AN2
title: Pilot hypotheses measured from events, not tallied
author: po
status: approved
updated: 2026-10-23
---

# AN2 — Pilot hypotheses measured from events, not tallied

## PO update — 2026-10-24 00:20: precondition DAY-1 (one calendar day: Europe/Zurich), before CGR-35

**Finding (PO, from CI, not from running tests):** the docs-only PR #238 went red at 22:00 UTC (= 00:00 Europe/Zurich, summer time) in `db` and `e2e` (run 40030758280), while `recovery/main` was green at 21:23 UTC on the same code (runs 40026345400, 40026353505). Failed pgTAP: 008 (5), 015 (11), 043 (14, 16, 21, 23), 044 (23-26, 28-32, 34), 049 (52-53). A docs change cannot cause this; the cause is the time of day. IMPLEMENTED in the repository and read by the PO: (a) tests mix `current_date` (the database day, UTC in CI) with `(now() at time zone 'Europe/Zurich')::date`, and build visits at `now() ± hours` that fall on the previous Zurich day after midnight; (b) live functions mix the two days too: `current_date` in 0013 and 0017 (requested start bounds), 0014 (care-plan review date), 0019 and 0024 (OPS1 `order_expiring`, care-plan review overdue), 0024 and 0031 (C1 pause expected end, visit window), against `Europe/Zurich` in 0012, 0014, 0021. UNKNOWN: the hosted database time zone (Supabase default UTC) and the e2e failure cause (report artifact not read).

**Why it matters:** every night CI is red for two hours (one hour in winter time, from 25 October), so merges stall and a red can be mistaken for a flake; and between 00:00 and 02:00 Zurich time an order that expired "yesterday" or a review date that passed "yesterday" is judged against the UTC day, so the safety exceptions come up to two hours late and a pause end of "today" can be refused. Patient safety is a precondition: this goes first.

**PO decision (product authority, not a clinical rule):** NAVORA's calendar day is the Europe/Zurich day, everywhere, for every "today", "yesterday", date bound and date-based exception. Thresholds and their values are unchanged (D-28 stays `clinical`).

**Acceptance criteria DAY-1** (first change under issue #205, its own small PR, before CGR-35 and ABS1-C7):
- [ ] (1) One server-side source for "today" in Europe/Zurich; no live function or view in the migrated schema compares a date with bare `current_date` or `now()::date`. A check in CI (pgTAP over `pg_proc` bodies, or a script in the `db` job) fails when one is added.
- [ ] (2) pgTAP at a split day (UTC date ≠ Zurich date, e.g. 23:30 UTC in summer time): `order_expiring` and the care-plan review-overdue exception use the Zurich day; a pause with expected end = Zurich today is accepted; the J1/J2 requested-start bounds use the Zurich day. How the clock is set in tests is engineering's choice (ADR).
- [ ] (3) The whole pgTAP suite and the e2e suite pass with the database clock at a split-day time; shown once in CI (for example a second pgTAP pass with the test clock set to 23:30 UTC), not by waiting for the night.
- [ ] (4) No behaviour change outside the split-day window: existing pgTAP passes unchanged in meaning (fixtures may change, assertions may not be weakened).
- [ ] (5) ADR names the helper and the rule, and states the hosted database time zone once staging exists (D-2) as an owner check.

**Order:** DAY-1, then CGR-35 and ABS1-C7, then the AN2 measures. Until DAY-1 is merged, a PR red only in `db`/`e2e` between 22:00 and 24:00 UTC is re-run once after 00:00 UTC before anyone debugs it.

## PO update — 2026-10-23 23:15: AN2 is next; CGR-35 and ABS1-C7 ride with it; measure 8 extended

CSR1 is complete (`briefs/CSR1.md` 23:15), so AN2 is the active capability. **First change, before or inside AN2's first PR (engineering decides the split):** CGR-35 (a flagged past visit moved forward stores `responsible_absent` on its `moved` row) and ABS1-C7 (singular confirmation text), criteria (1)-(5) in `briefs/ABS1.md` 23:15. Measure 8 reads CGR-35's column; without it, moved flagged visits would be undercounted (`cra` 22:30). **Precondition:** CI on `recovery/main` is red since 62609af (`npm audit`: `zod` < 4.6.6, GHSA-mrhx-c7xc-m3w5, high, runtime dependency); engineering fixes that first, since no PR can merge on a red app job. The PO did not run any test.

## Problem
The challenge table in `NEXT_CAPABILITY.md` holds about a dozen hypotheses that decide whether a coordination or administration step can disappear: does Operations still need to see uncovered visits once teams take them; are correction rounds mostly late-typed times; is "Folgeeinsatz geplant" followed by a planned visit; do nurses give away single visits by phone; do coordinators end visits that are in progress. Each one names a measure, and today nobody computes any of them. The pilot would answer them with hand tallies and a monthly compilation by a coach or Operations. That is the administration NAVORA is meant to remove, applied to NAVORA's own learning. Every one of these counts is already in NAVORA's events (field events, report versions, exceptions and their handling, absences, plan changes, billing facts).

## Users and journey step
Teams (their own figures, for their monthly self-review), the coach and the organisation (all teams, never per nurse), the PO and `clinical` (evidence for D-28, D-31, D-10). Journey step: **Analytics**, over Planning → Visit → Documentation → Quality → Billing (`ARCHITECTURE.md` data flow).

## Outcome
`/analytics` gains a section "Pilot-Hypothesen": each row names the hypothesis, the measure, the period and the base count, computed from events, so a hypothesis is confirmed or dropped from data without anyone tallying anything.

## Operating-model impact
- **Replaces:** hand tallies and a monthly report compiled by a coach or Operations for the pilot review.
- **Makes less necessary:** the coach as reporter; meetings to collect counts.
- **Direct care time / continuity / income:** indirect. AN2 decides which of the next removals (Operations as default receiver of uncovered visits, follow-up planning in two steps, the phone round for a single visit, re-signatures for nothing) is built, so the pilot spends its build time where care time is lost.

## Acceptance criteria
- [ ] **Section "Pilot-Hypothesen"** on `/analytics`, same access rule as AN1 (coordination roles of the organisation see all teams; a team member sees her own teams only). Each row shows: the hypothesis (one line, German, linked to its challenge row by ID or title), the value, the period, the base count, and "zu wenig Daten" when the base is below 5.
- [ ] **Never per nurse.** Values per team and per organisation only, with AN1's suppression rule (a team below 3 persons with visits in the period shows "zu wenig Personen"; the organisation row follows AN1's condition for hidden small teams). No client name, no free text, no health data in any value or detail.
- [ ] **Measures (each from existing events; engineering names the source per measure in the PR):**
  1. **Uncovered visits taken by the team:** share of `visit_uncovered` exceptions that ended by a team member's take (ABS1 "Offen im Team") before any Operations action on them; median hours from start of the exception to the take.
  2. **Follow-up after an interrupted visit:** share of `follow_up_planned` decisions (0045) with no planned visit of the same case created within 48 h after the decision; median minutes from the *not completed* end to the decision.
  3. **Coordinator ends:** number of *not completed* ends recorded by a coordination role while the visit was `started` or `paused` (OPS1 condition CGR-26).
  4. **Single visits given away by hand:** J3 moves and responsible-member changes made within 24 h before the planned start, per 100 planned visits (the "Abgeben" hypothesis).
  5. **Correction rounds:** report correction versions per 100 signed reports; median minutes from the signature to the correction version; share of correction versions whose snapshot hash equals the previous version's (signed again with no change).
  6. **Open corrections:** `report_correction_open` signals in the period, median hours open, and the share ended by withdrawal (CSR1 CGR-24-W) versus signature.
  7. **Not-billable facts:** J5 facts not billable per reason, and median days until a later fact of the same visit is billable.
  8. **Absences:** absences recorded per 100 planned visits; share recorded by a colleague; share of those later withdrawn by the member herself; **(PO 2026-10-23 21:17, challenge row "guessed return date")** share of absences shortened, withdrawn, or followed by an adjacent or overlapping new absence of the same member within 48 h; share of absences recorded with a start of yesterday (ABS1-C6); **(PO 2026-10-23 20:15)** past planned visits flagged `responsible_absent` (CGR-32) per 100 absences, and how they ended: started late, cancelled (with the stored CGR-34 mark), or still open at the end of the period; **(PO 2026-10-23 23:15, CGR-35, ABS1-C6)** flagged past visits that were moved (`moved` rows with `responsible_absent = true`) as a fourth ending, and absences whose start is earlier than the day before they were recorded (the form offers yesterday only; such starts come from the command path).
  9. **Long or fragmented visits (CGR-23):** visits with more than two pause/resume cycles, and visits open longer than planned plus the P1 threshold.
  10. **How exceptions end:** for `visit_overdue` and `visit_stuck`, share ended by a visit command (start, cancel, not completed, complete) versus closed by hand in OPS1.
  11. **Quality holds:** median hours from hold to lift.
  12. **Late billing facts (PO 2026-10-23 19:12, challenge row "Billing facts are built in a later batch"):** share of J5 `report` facts built more than 24 h after the visit's end; `basis_changed` facts per 100 facts (payer correction J5-C1 and order catch-up J5-C2 together).
- [ ] **pgTAP per measure** with a synthetic fixture: the expected value and base count for at least one case that counts and one that does not (for example: an uncovered visit taken by the team counts in 1, one taken over by Operations first does not).
- [ ] **Suppression tested:** pgTAP with a two-person team shows "zu wenig Personen" for every AN2 row of that team.
- [ ] **Negative:** a nurse sees no AN2 row of a team she is not in; another organisation's user sees nothing; anonymous gets nothing.
- [ ] **e2e at phone width (390 px):** the section renders with period and base on every row, no horizontal overflow.
- [ ] **Measures without an event source** are not faked: if engineering finds that a measure has no event source today (for example, a refused command that is not logged), the row says "nicht erfasst" and the PR names the missing event; the PO decides whether to add it.

## Out of scope
- Changing any workflow or threshold the measures inform. Each decision comes after data, through its own brief or `clinical` decision (D-28, D-31, D-10).
- Counts of things outside NAVORA (relatives' phone calls, care-plan reviews that changed nothing): they stay manual tallies until a brief makes them events.
- Per-nurse figures of any kind; ranking teams against each other.
- The North Star (direct care share) itself: it waits for recorded working time (D-23).

## Dependencies
- Reads the events of ABS1 part 2 and CSR1 part 9; starts after both are delivered (Next up 2, after CSR1). **2026-10-23 23:15:** both delivered and CSR1 complete; AN2 is Next up 1, with CGR-35 and ABS1-C7 as its first change.
- AN1 (accepted; its suppression condition must be met in the same or an earlier PR that touches `pilot_kpis`).
- No open decision blocks it: it stores nothing new about people and processes no health data.

## Patient safety
Read-only. It changes no visit, alert or record. Measure 3 and 10 make safety-relevant patterns visible to the team and `clinical`; no threshold is invented.

## Constraints and references
`docs/product/CARE_OPERATING_MODEL.md` (North Star, what disappears), the challenge table in `NEXT_CAPABILITY.md`, AN1 (`briefs/AN1.md`, suppression rule), `DOMAIN_RULES.md` data minimisation. Clinical review gate: AN2 reads quality and billing data but changes none; engineering reads the latest Clinical Governance Report and names it in the PR, and the PO considers it before acceptance.

## Open questions for engineering
- One function returning rows (hypothesis, team, value, base, period) or one per measure? Engineering decides; the PO needs the base count and period on every row.
- Can measures 1 and 10 reuse `exception_events` and the derived exception keys, so "Operations action before the take" has one definition?
