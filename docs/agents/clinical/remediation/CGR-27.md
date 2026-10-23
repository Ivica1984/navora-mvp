# Remediation plan: CGR-27 (the visit interval of visits without a start or without an end time)

**Written by:** Engineering (`eng`) · 2026-10-23 (Europe/Zurich) · **Item:** ABS1 · delivered under issue #199, ABS1 part 2 (migration 0048)
**Finding:** [Clinical Governance Report, section 2026-10-23 14:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-27, blocking (S1); confirmed unchanged in the 15:00 section (PR #203, not merged when this was written). Same gap as the PO's ABS1-C1 (brief, PO review 2026-10-23 14:16), widened to visits without an end time.

## Risk

A visit without a start time counted as 00:00-00:01 and a visit with a start but no end as one minute. An absence starting later that day, or during such a visit, did not release it: it stayed with the absent nurse, did not appear in "Offen im Team", raised no `visit_uncovered` and looked covered. The same interval decided whether the absent nurse could take a visit and whether a deputy was shown as "kennt die Klientin".

## Affected code and data

- Migration 0048 §1: `private.visit_interval` (one function, used by the release rule, `take_open_visit`, `team_open_visits` `may_take` and `known_by`, `change_absence`).
- Migration 0048 §5: the overlap label in `team_open_visits` needs a start time on both visits.
- No data is rewritten; visits released before 0048 are unaffected.

## Steps

1. IMPLEMENTED: no start time = the whole date (00:00 to 24:00, Europe/Zurich).
2. IMPLEMENTED: start without end (or end equal to start) = start + planned minutes A+B+C; without planned minutes, to the end of the date.
3. IMPLEMENTED: start and end unchanged (an end before the start runs past midnight).
4. IMPLEMENTED (no change needed): PLAN2 checks the slot window; scheduled care plan items always have one (0025 check), as the `cra` noted.

## Tests

- pgTAP `048_abs1_part2` §0-§2: the interval values; an absence from 10:00 releases that day's untimed visit; an absence from 08:30 releases a visit 08:00 without an end and with 60 planned minutes, and one without minutes; a visit 07:00 without an end and 30 minutes stays; the absent nurse is neither offered nor able to take them; a member absent tomorrow from 15:00 is not offered an untimed visit of tomorrow; `known_by` skips both absent nurses; shortening keeps an untimed visit open while she is still absent that day.
- CI runs them; nothing is claimed as passed before CI.

## Needs a decision (not built here)

- None. The rule is arithmetic (the `cra` recommendation), not a clinical rule. CGR-28 (covers) stays PLANNED as a condition on D-3.
