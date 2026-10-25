# Remediation plan: CGR-57 (a planned visit without an end counted as one minute in the outside-watched-hours list)

**Written by:** Engineering (`eng`) · 2026-10-25 16:20 (Europe/Zurich) · **Item:** FUP1-1 · **Brief:** `briefs/FUP1.md`
**Finding:** Clinical Governance Report section 2026-10-25 13:26 CET (PR #374), CGR-57, **advisory (S2; before the list counts as SIG1-8 evidence, i.e. before go-live)**. ADR-084, migration 0071, pgTAP 069.

## Risk

`visits_outside_watched_hours` (0068) gave a planned visit without an end time the interval start + 1 minute, while ABS1 (`private.visit_interval`, 0069) gives it start + planned minutes A+B+C, else the rest of its day. A visit at 19:50 without an end and 45 planned minutes (to about 20:35) was not listed under watched hours 07:00-20:00, so the list told the Clinical Owner the plan was covered while a P1 there after 20:00 would reach Operations only in the app (SIG2-12).

## Affected code and data

`private.visit_wall_range` (0068) and `public.visits_outside_watched_hours`. No data change; the live project is not touched.

## Steps

1. IMPLEMENTED (0071): `private.visit_wall_range(care_visits)` reads the length of a visit without an end (or with end = start, as `visit_interval` treats it) from `private.visit_interval` itself: wall start + the interval's elapsed length, and never earlier than the wall reading of its end instant (the longer reading on a clock-change night). Visits with an explicit end keep the 0068 reading.
2. IMPLEMENTED (0071): the list reads the new helper; watched periods are read up to two days after the visit date (a visit of up to 30 planned hours); the one-minute helper is dropped.

## Tests

pgTAP 069 (+10): watched 07:00-20:00; 19:50 without an end and 45 planned minutes → listed; 19:50 without an end and no planned minutes → listed; 08:00 without an end and 20 planned minutes → not listed; 19:30 + 20 minutes → not listed; end = start reads as no end; 06:50 stays listed; the wall end equals `visit_interval`'s end. Every existing 069 assertion unchanged. **CI is the runner.**

## Needs a decision

None. The visit length rule already exists (ABS1, accepted); it is reused, not invented. SIG1-8 stays a go-live condition (Clinical Owner).
