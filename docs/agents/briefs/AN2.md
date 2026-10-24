---
id: AN2
title: Pilot hypotheses measured from events, not tallied
author: po
status: approved
updated: 2026-10-23
---

# AN2 — Pilot hypotheses measured from events, not tallied

## PO update — 2026-10-24 02:20: measure 7 labels the 10-minute rule as under review (AN2-M7)

**New evidence (advisory, `lca` 01:50, PR #241, not yet merged; the PO did not verify the sources):** the 10-minute minimum and the 5-minute units are federal (KLV Art. 7a Abs. 2); the literal wording ("Zu vergüten sind mindestens 10 Minuten") reads as a floor on remuneration, whereas CR-029 (UNVALIDATED, `validated = false` since 0043) makes a visit under 10 minutes *not billable*. Which reading applies is open in D-18 (legal). Nothing is invoiced, so no billing change follows. But AN2 measure 7 would count those facts as "not billable" and the pilot could read them as lost revenue or as a reason to stretch visits, which is the wrong incentive for direct care time.

**PO decision (product authority, presentation only, no rule change):** measure 7 shows the reason "below minimum (CR-029)" as its own row, with the fixed note "Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten", and never adds it into a total of not-billable facts or minutes. All other reasons unchanged.

- [ ] **AN2-M7:** measure 7 lists `below_minimum` (or the engineering name of the CR-029 reason) separately with that note; the total of not-billable facts excludes it; a unit or e2e test asserts the note and the exclusion. No change to J5 or CR-029.

## PO review — 2026-10-24 01:15: DAY-1 delivered as #239; safety fix met, proof partly open (remainder rides with CGR-35)

Engineering fixed the cause outside AN2 as an engineering fix: #239 (`fix/zurich-today`, migration 0055, pgTAP 056, ADR-068), merged as 2e79532. CI on the PR head green in app, db and e2e (run 40033219652, started 22:22 UTC = 00:22 Zurich, inside the split-day window). **The PO did not run the tests**; evidence is the diff read by the PO and CI read through the API.

| Criterion | Result | Evidence |
|---|---|---|
| (1) one server-side source for "today"; CI check against bare `current_date` / `now()::date` | **partly met** | 0055 re-creates every `public`/`private` function body with `current_date` replaced by `(now() at time zone 'Europe/Zurich')::date` and fails if one remains; pgTAP 056 refuses `current_date` in function bodies. Open: no single helper (the expression is repeated inline); the guard does not refuse `now()::date`, `current_timestamp::date`, `localtimestamp` or a date in a view. The PO's grep of the migrations finds none of these today |
| (2) pgTAP at a split day: `order_expiring`, review overdue, pause end = Zurich today accepted, J1/J2 requested-start bounds | **not met** | 056 checks function source text only (two `like` checks); no behavioural test at a split-day clock |
| (3) whole pgTAP and e2e suite pass at a split-day clock, shown once in CI | **met by observation** | run 40033219652 ran at 00:22 Zurich (UTC date ≠ Zurich date) and was green in db and e2e. Not repeatable: it depends on when CI runs |
| (4) no behaviour change outside the window; assertions not weakened | **met** | the test diff replaces `current_date` with the Zurich date in fixtures and arguments; assertions unchanged in meaning (PO read 008-021, 044); 044 reads the report on its visit's own Zurich date |
| (5) ADR names helper and rule; hosted DB time zone as an owner check once staging exists (D-2) | **partly met** | ADR-068 names the rule (status PROPOSED). It assumes "UTC on Supabase" and does not state the hosted time zone as an owner check with D-2 |

**PO status for DAY-1: `changes-requested`, non-blocking.** Why: the patient-safety part (OPS1 order-expiring and review-overdue, `pause_case`, `apply_case_facts`, `add_care_plan_item` judged against the Zurich day) is fixed and CI is green at night, so nothing waits on DAY-1 any more. What is missing is the proof that keeps it fixed: a later function written with `now()::date` would pass the guard, and no test pins the behaviour at a split-day clock.

**Deviations decided:**
- Inline expression instead of a helper: **accepted**, if the guard (below) catches every other way to derive a day.
- Proof (3) by a night run instead of a set test clock: **accepted for this delivery**; (2) supplies the repeatable proof.
- Delivered as an engineering fix outside AN2: **accepted** (CI was red every night; speed was right).

**Remaining criteria (DAY-1-R), ride in AN2's first PR together with CGR-35 and ABS1-C7, no separate PR:**
- [ ] R1: pgTAP 056 (or a successor) also fails on `now()::date`, `current_timestamp::date`, `localtimestamp` and `current_date` in a view or materialised view in `public`/`private`.
- [ ] R2: at least one behavioural pgTAP at a split-day clock (UTC date ≠ Zurich date, set by engineering's test-clock method): `private.derived_exceptions` judges an order end date and a care-plan review date against the Zurich day (one case each where the UTC day would give a different result), and `pause_case` accepts an expected end of Zurich today. Thresholds and priorities unchanged (D-28).
- [ ] R3: ADR-068 records the hosted database time zone as an owner check once staging exists (D-2).

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
