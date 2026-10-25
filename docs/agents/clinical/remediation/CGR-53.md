# Remediation plan: CGR-53 (a visit interval ending in the repeated hour was one hour short)

**Written by:** Engineering (`eng`) · 2026-10-25 11:25 (Europe/Zurich) · **Item:** DST1 follow-up (DST1-C1 to DST1-C3, PO `changes-requested` 10:12 CET) · **Brief:** `briefs/DST1.md`
**Finding:** Clinical Governance Report section 2026-10-25 09:31 (open PR #358), CGR-53, **advisory (S3; next repeated hour 2027-10-31)**. Taken up by the PO as DST1-C1. ADR-081 addendum, migration 0069, pgTAP 070.

## Risk

0067 gave the **end** of `private.visit_interval` the earlier instant. On the fall-back night a visit 01:30-02:30 occupied 23:30-00:30 UTC instead of 23:30-01:30 UTC. An absence of its responsible nurse from 01:00 UTC (02:00 CET, second pass) no longer overlapped it, so ABS1 neither released the visit nor flagged `responsible_absent`: H-01 (a visit nobody does) and H-17 (an absent nurse still responsible), once a year, for visits ending in that hour. A behaviour regression of an accepted control (ABS1), introduced by DST1.

## Affected code and data

- `private.visit_interval` (the one interval every absence check reads), `public.record_absence` and `public.change_absence` (absence ends typed as local times). No data change; the live project is not touched.
- Found while doing it: `private.watched_inside` (SIG2 watched hours) disagreed with `watched_raise_at` on the spring night (DST1-7); `private.visit_interval` failed for a visit starting in the spring gap and ending after it (since 0048).

## Steps

1. IMPLEMENTED (0069): the end of `visit_interval` uses `private.at_zurich_end` (later instant); the start stays `private.at_zurich` (earlier instant). A visit starting in the spring gap and ending after it covers both readings instead of failing.
2. IMPLEMENTED (0069): the absence end in `record_absence` and the new end in `change_absence` use `at_zurich_end`; the absence start stays the earlier instant.
3. IMPLEMENTED (0069): `watched_inside` is true when the wall clock or the period instants cover a time (never shorter on either night).
4. Checked, unchanged (ADR-081 addendum table): the CSR1 stuck reference and its AN2 mirror keep the earlier end (an earlier reference raises sooner; accepted deviation (c)); `release_member_visits` ends at midnight; `generate_case_plan` compares wall-clock times; cover reads build no interval of their own.

## Tests

pgTAP 070 (31) at a pinned clock: the 01:30-02:30 visit occupies 23:30-01:30 UTC; an ordinary night unchanged; both ends in the repeated hour; a visit 02:30-03:30 keeps its earlier start; the spring cases. ABS1 on the fall-back night acts as on an ordinary night: an absence from 30 minutes before the visit end flags `responsible_absent` and releases the visit (audited once in `visit_plan_changes`); an absence from the visit end does not release it, on both nights. `record_absence` and `change_absence` ends in the repeated hour take the later instant; an ordinary day is unchanged. The stuck reference keeps the earlier end. DST1-7 and DST1-8 (b) assertions. A local run on a PostgreSQL 16 stand-in (not CI) passed 070, and with the 0069 changes reverted 070 failed (two interval assertions and the spring-gap error). **CI is the runner.**

## Needs a decision

None. A time-conversion rule (input class *visit/schedule fact*), no threshold, release or flag rule changes (D-28 unchanged). One consequence for `cra` and the PO to see: with the later end, an absence typed to start at a time in the repeated hour (read as the earlier instant) overlaps a visit ending in that hour on the wall clock (absence 02:40, visit to 02:30: released; read from the code, not asserted in 070). That is the conservative reading of an ambiguous end, as DST1-C1 asks.
