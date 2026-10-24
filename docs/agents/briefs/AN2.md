---
id: AN2
title: Pilot hypotheses measured from events, not tallied
author: po
status: approved
updated: 2026-10-24
---

# AN2 — Pilot hypotheses measured from events, not tallied

## PO review — 2026-10-24 08:18: part 3 (#263) meets its measures; **AN2 accepted** with two conditions (AN2-C1, AN2-M4a)

**Delivery reviewed:** #263 (`eng`, migration `0058_an2_pilot_hypotheses_part3`, pgTAP `060_an2_pilot_hypotheses_part3` (48 assertions), pgTAP 059 catalogue count 17 → 35, unit and e2e updated, ADR-071), merged as `d386a1b`. CI green on head `8058531` (run 40067193832: app, db incl. pgTAP 060, e2e) and on the merge commit `d386a1b` (runs 40067597514, 40067600140), read through the GitHub API. Parts 1 (#243) and 2 (#255) were reviewed at 04:10 and 07:10 above. **The PO did not run the tests**; evidence is the CI result, the assertion labels of pgTAP 060 and the migration and ADR text, read in the repository.

**CI finding after the merge (not caused by the docs change):** the next commit on `recovery/main`, `9a9e8db` (merge of #264, docs only: `IMPLEMENTATION_STATUS.md`, `JOURNAL.md`), was **red in `db` in both runs at 05:51 UTC** (push run 40067901155, pull-request run 40067898560); the same code was green at 05:47 UTC (`d386a1b`, `3158d89`). The PO re-ran the failed job of 40067898560 once: **green** (attempt 2). The job log could not be read (the log storage host is blocked from this session); the check annotation is cut off after "059 … ok", so the failing file is **probably 060** (UNKNOWN). A failure on identical code in two runs at the same minute points to a dependence on the clock, not to chance. Recorded as **AN2-C1**.

| Criterion | Result | Evidence |
|---|---|---|
| Measure 1 uncovered visits taken by the team: share, median hours to the take | met | 0058 replays the responsible member from `visit_plan_changes` (`released`, `taken`, `returned`); "taken by the team" = a `taken` with no OPS1 `take`/`close` on the key before it, the same definition as AN1 `cover_without_operations` (the brief's question 2: yes). 060 "U1 … counts; U2 (Operations took the exception over first) does not", "U3 … never had one", median 2 h, organisation row agrees, threshold named provisional (D-28) |
| Measure 2 follow-up after an interrupted visit: share without a planned visit within 48 h, median minutes to the decision | met, with a stated limit | 060 "F2 has no visit of the case planned within 48 h …; F1 has one" (50 %), median (30, 120) = 75; the row note says a moved existing visit does not count and that the decision is a statement, not a check (D-31) |
| Measure 4 single visits given away by hand: moves and responsible-member changes within 24 h before the planned start, per 100 visits | **met in form, not in meaning** (AN2-M4a) | 060 "one move less than 24 h before … (M1) per ten visits", "U1's release and take … count". The second row counts only `released`/`taken`/`returned`, which are ABS1 absence releases and team takes; a J3 `reschedule_visit` that changes the responsible member is a `moved` row and is counted only as a move (0058:355-366). So the row the hypothesis needs (a visit handed to a colleague by hand) is mixed into "moves", and the "responsible changes" row measures the absence path, which is the opposite of what the "Abgeben" row asks |
| Measure 8 absences: all sub-measures of the brief, incl. the four endings of flagged past visits | met | 060: per 100 visits (62.5), by a colleague (20 %), withdrawn by the member herself (100 % of 1), revised within 48 h (60 %: withdrawn, shortened per the `ends_at` audit, adjacent new absence), start yesterday (20 %), start before yesterday (1, command path), flagged past visits per 100 absences, endings started late / cancelled with the CGR-34 mark / moved / still open / cancelled without the mark, "every ending has its row (fixed codes), also with value 0", organisation counts each absence once |
| **AN2-M8a** moves only from `responsible_absent`; moves before the capture start as "vor Erfassung (nicht gezählt)", never "nicht abwesend" | met | 060 "a move counts only from the stored responsible_absent (P3), not P4", "P4 … is in its own row", "that row says vor Erfassung (nicht gezählt)", "no move is shown as an ending other than moved or vor Erfassung", "the capture start is recorded once" (`private.an2_capture_starts`, RLS on, no grants) |
| Measure 10 how `visit_overdue` and `visit_stuck` end: by a visit command vs. closed by hand | met | 060 "three overdue visits", O1 by its start 33.3 %, O2 closed by hand 33.3 %, O3 still open (in the base); S1 by its completion 50 %, S2 closed by hand on its event key 50 %; threshold named provisional |
| **AN2-M9a** measure 9 names the threshold used | met | 060 exact note "Schwelle heute: geplantes Ende + 1 Std. + 3 Std. bis P1. Wie heute eingestellt (provisorisch, D-28)." |
| pgTAP per measure, one case that counts and one that does not | met for all twelve measures | 059 (parts 1-2, reviewed 07:10) and 060 (above) |
| Section, access, "zu wenig Daten", never per nurse, suppression, negative | met | 059 (07:10); 060 "a base below 5 says zu wenig Daten", "details are fixed codes only", "the eighteen measures of part 3 appear in a month without events", "a nurse of another organisation sees no row of this team" |
| e2e at 390 px with 12 hypothesis cards | met | `tests/e2e/analytics.spec.ts` updated in #263; e2e green on head and merge commit |
| Measures without an event source are not faked ("nicht erfasst") | met (none needed) | every measure has a named source (0058 header, ADR-071); no row claims data it does not have |
| Clinical review gate | met | PR names report sections 02:26 and `cra` 06:30 (#259): no blocking finding for AN2; note (a) on today's thresholds stated in ADR-071 |

**Known limits in ADR-071, decided:**
1. *Thresholds are today's values* (measures 1, 9, 10). **Accepted.** Once ADM1-R is merged no override can make a look-ahead window shorter than the default, so measure 1 can no longer be shrunk silently; measure 9 names its value (M9a).
2. *Suspension and cover history are not replayed for measure 1.* **Accepted for the pilot.** COVER1 is switched off (D-3), so no cover can distort it today; when cover is enabled, the PO re-reviews measure 1 in that brief.
3. *A visit removed from the plan drops out of every measure.* **Accepted.** Removals are rare and their history row stays; no measure here is about removals.
4. *Measure 8's flag uses today's responsible member.* **Accepted.** It undercounts only flagged visits later handed to someone else; the row is a lower bound, which is the safe reading for a hypothesis that asks whether absences strand visits.
5. *pgTAP 059 catalogue count changed (17 → 35).* **Accepted:** a named count change, no assertion weakened.

**Conditions (ride in the next engineering PR; AN2-C1 first):**
- [ ] **AN2-C1 (CI determinism, precondition for every later merge):** engineering finds the cause of the red `db` job on `9a9e8db` at 05:51 UTC (runs 40067901155, 40067898560) and fixes it at the root (fixture or reader), not by a re-run. Proof: the failing file and test number named in the PR; if the cause is the clock, a pgTAP that sets the session clock (as 058 does for the day) to the failing minute and passes. No assertion weakened, none skipped. If the cause cannot be found from the log, say so in the PR with the log excerpt.
- [ ] **AN2-M4a (measure 4 means what its hypothesis asks):** `late_responsible_changes_per_100` counts **hand handovers**: `moved` rows (J3 `reschedule_visit`) whose responsible member changes, less than 24 h before the planned start; `late_moves_per_100` counts only moves with an unchanged responsible member. ABS1 releases, team takes and returns (`released`, `taken`, `returned`) get their own row ("über Abwesenheit / Offen im Team") and are not in either hand row. pgTAP: a `moved` row 12 h before with a changed responsible member counts in the hand row and not in moves; U1's release and take count only in the ABS1 row.

**PO status for AN2: `accepted`.** Why: the pilot now has its twelve hypotheses as numbers computed from events, with base, period, suppression and honest limits, so a coordination layer can be removed (or kept) on evidence and nobody tallies anything. Measure 4's mix-up does not invalidate the others and is a small reader change; the CI dependence on the clock is a test defect, not a product defect, and the merge commit was green. Neither touches patient safety: AN2 is read-only.

**Business and care value.** AN2 is NAVORA's own instrument for "what can disappear": measures 1 and 10 decide whether Operations stays the default receiver of uncovered and overdue visits (SIG1-6 reads measure 10), measure 2 decides D-31's follow-up design, measure 8 decides the open-ended absence. It replaces the coach as reporter and the monthly count meeting. Alignment with the Architecture Handbook: one read model over the event history, team-scoped, no new product state (the capture marker is internal).

## PO review — 2026-10-24 07:10: part 2 (#255) meets its measures; AN1 condition met; AN2 stays approved, part 3 after ADM1-R

**Delivery reviewed:** #255 (`eng`, migration `0057_an2_pilot_hypotheses`, pgTAP `059_an2_pilot_hypotheses` (57 assertions), unit `analytics-hypotheses`, e2e `tests/e2e/analytics.spec.ts:38-72`, ADR-070), merged as `c1c58b3`. CI green on head `88eeaeb` (run 40061316499) and on the merge commit `c1c58b3` (run 40061609501: app, db incl. pgTAP, e2e), read through the GitHub API. **The PO did not run the tests**; evidence is the CI result, the assertion labels of pgTAP 059 and the e2e spec, read in the repository. The engineering row stays `in-progress` (part 3 PLANNED), so this is a part review, not acceptance of AN2.

| Criterion | Result | Evidence |
|---|---|---|
| Section "Pilot-Hypothesen", same access as AN1, value, period, base, "zu wenig Daten" below 5 | met for part 2 | one read model `public.pilot_hypotheses(p_month)` (0057); pgTAP 059 "3: a base below 5 says zu wenig Daten", "5: a base of 5 is enough"; every measure in every scope, base 0 without events (059 "every measure of this part appears, also in a month without events") |
| Never per nurse; AN1 suppression; no client, free text or health data | met | 059 "a two-person team shows zu wenig Personen on every AN2 row, with neither value nor base", "and so does a one-person team", "the read model has no per-person, client or visit columns", "details are fixed reason codes only", "no report text, hold reason or correction reason reaches a row" |
| Measure 3 coordinator ends | met | 059 "3: base = not-completed ends from started or paused", organisation base 3 |
| Measure 5 correction rounds | met | 059 "80 per 100", "median ... = 25", "one has the same snapshot hash and summary (signed again with no change)" |
| Measure 6 open corrections | met | 059 "three corrections stayed open past the report_not_final threshold", median 15 h, "one ended by withdrawal (CGR-24-W)", "one ended by signature", threshold named provisional (D-28) |
| Measure 7 not-billable facts, with AN2-M7 | met | 059 "7 / AN2-M7: the total counts f1 and f3; f2, not billable only below the minimum, is not in it", "below_minimum has its own row", "with the fixed note", "f1 became billable 2 days later" |
| Measure 9 long or fragmented visits (CGR-23) | met, with a limitation | 059 "9: one visit with more than two pauses", "l1 was open past planned end + visit_stuck threshold + P1 escalation"; uses **today's** threshold for past visits (no history of rule values; ADR-070) |
| Measure 11 holds | met | 059 "11: median hours from hold to lift (5, 9) = 7", "one hold still open" |
| Measure 12 late billing facts | met | 059 "12: one basis_changed fact per six facts" and the late-share assertion |
| pgTAP per measure (counts and does not count) | met for 3, 5, 6, 7, 9, 11, 12 | 059 assertion list above |
| Suppression tested | met | 059 two- and one-person team rows; January organisation rows hidden |
| Negative (other team, other organisation, anon) | met | 059 "a nurse sees no organisation row", "and no row of a team she is not in", "a user of another organisation sees nothing of org B", "anon cannot execute the read model", "anon gets nothing" |
| e2e at 390 px, base and period on every row, no overflow | met | `analytics.spec.ts:39-60` (viewport 390, `scrollWidth - innerWidth <= 0`), :63-72 (nurse sees own team only) |
| Measures 1, 2, 4, 8 (with AN2-M8a), 10 | open | PLANNED, part 3 |
| **AN1 condition (PO 2026-10-22 17:15):** organisation row suppressed when it would reveal a hidden team of one or two persons | **met** | 0057; pgTAP 059 "AN1: one visible three-person team and one hidden one-person team: no organisation value", "two hidden teams of two persons each: the organisation value shows", "open P1 exceptions ... are not hidden" |

**Deviations (decided):**
1. *Suppressed AN2 rows hide the base too* (brief: base on every row). **Accepted:** a base of 1 or 2 on a hidden team is itself the information suppression protects.
2. *pgTAP 032's last assertion replaced, fixtures of 027, 030, 033, 034, 048 widened to three performers.* **Accepted:** 032 asserted the opposite of the PO's AN1 condition; the fixture change keeps those files testing what they tested.
3. *The AN1 condition was due in 0043 and 0048 and came only now.* **Accepted as closed;** no rework.
4. *Measure 9 uses today's threshold for past visits.* **Accepted for the pilot, with a condition:** while CGR-39 is open an organisation could have lowered the threshold; **AN2-M9a** (with ADM1-R): the measure-9 row names the threshold value used ("Schwelle heute: … h") so a reader can see it. Rides in part 3.

**Business and care value.** Part 2 turns seven hypotheses from the challenge table into numbers without anybody tallying: correction rounds (administration), coordinator ends (hierarchy), hold to lift (who waits on whom), late billing facts. This is the evidence base for removing coordination layers, which is the product. The AN1 privacy gap is closed. Alignment with the Architecture Handbook: one read model from events, read-only, team-scoped; no new state.

**Order:** ADM1-R (CGR-39, S1) goes first; AN2 part 3 (measures 1, 2, 4, 8 with AN2-M8a, 10, and AN2-M9a) follows.

## PO review — 2026-10-24 04:10: DAY-1-R1–R3 met (#243); DAY-1 accepted; AN2 measures next; AN2-M8a

Reviewed #243 (AN2 part 1, head afd1d11, CI run 40049445817 green; merged as 56c8756, CI run 40053036646 green on the merge commit, checked through the API). The PO read pgTAP 058 (15 assertions) and the ADR-068 addendum. **The PO did not run the tests.** CGR-35 and ABS1-C7 are reviewed in `briefs/ABS1.md` 04:10.

| Criterion | Result | Evidence |
|---|---|---|
| R1: guard also fails on `now()::date`, `current_timestamp::date`, `localtimestamp` and on day derivations in a view or materialised view in `public`/`private` | met | 058 tests its day patterns against bad samples (all match) and good samples (none match) first, then refuses them in function bodies and in views/materialised views, `current_date` included for views; ADR-068 addendum lists the patterns |
| R2: behavioural pgTAP at a split day: `derived_exceptions` judges an order end and a review date against the Zurich day; `pause_case` accepts Zurich today | met | 058 sets a transaction-local session time zone whose date differs from Zurich (asserted: `current_date`, `now()::date` differ by exactly one day); pairs of cases where only the Zurich day gives the expected result for `order_expiring` and `care_plan_review_overdue` through `derived_exceptions` and OPS1 `operations_exceptions`; `pause_case` refuses Zurich yesterday and accepts Zurich today. Thresholds read from `exception_rules` (D-28 unchanged). Runs in every CI run |
| R3: ADR-068 names the hosted DB time zone as an owner check once staging exists (D-2) | met | ADR-068 addendum: `show timezone;` as the API roles on staging, recorded in the ADR; the live project is never touched |
| No weakening of existing assertions | met | no existing test changed in #243 except the ABS1-C7 text |

**Deviation decided:** *R2's test clock is the session time zone, not a moved instant* (ADR-068 addendum): **accepted**. It reproduces exactly the failure UTC caused (session day ≠ Zurich day) without a clock hook inside product functions that a caller might reach; the asserted precondition proves the test is in the split state at any hour.

**PO status for DAY-1: `accepted`** (01:15 `changes-requested` resolved). Why: the safety fix was met at 01:15; the proof that keeps it fixed is now in every CI run.

**New criterion (PO, product authority, presentation only):**
- [ ] **AN2-M8a:** measure 8 counts moved flagged visits only from `visit_plan_changes.responsible_absent` (migration 0056) and shows moves recorded before 0056 was applied as "vor Erfassung (nicht gezählt)", never as "nicht abwesend". Unit or pgTAP test for both rows. Why: an honest measure says what it cannot know; a pilot reading zero would otherwise conclude that absences never strand visits.

**Next:** the measures (section "Pilot-Hypothesen"), in engineering's order; COORD5 may be built in parallel.

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
