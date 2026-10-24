# Remediation plan: CGR-45 (the look-ahead raise time is the end instant of the watched period)

**Written by:** Engineering (`eng`) · 2026-10-24 21:40 (Europe/Zurich) · **Item:** SIG2 condition SIG2-13 (*Next up* 2) · **Brief:** `briefs/SIG2.md` (PO 19:09)
**Finding:** Clinical Governance Report section 2026-10-24 18:26 (PR #306), CGR-45, **advisory (S2; S1 for go-live)**, decided by the PO as SIG2-13 (product authority; 2 hours is an operating limit, not a clinical value). ADR-078, migration 0064.

## Risk

A look-ahead `visit_uncovered_hospital` whose window opens outside the watched hours was raised at the end instant of the last watched period (e.g. 20:00 for 07:00-20:00). At that instant nobody watching has time to act, and the same code treats 20:00 as outside, so the SIG2-12 Operations push would be `outside_working_time`.

## Affected code and data

- `private.watched_raise_at`, `private.derived_exceptions` (0062). New: `private.watched_inside`, `private.lookahead_raised`. No data change. The live project is not touched.

## Steps

1. IMPLEMENTED (0064): raise time = the later of the start of the last watched period that ends at or before the window opens and that period's end minus 2 hours; inside by the start-inclusive, end-exclusive predicate; never later than before or than the effective rule.
2. IMPLEMENTED (0064): the predicate takes the instant as an argument, so pgTAP checks it at fixed times (SIG2-14).

## Tests

pgTAP 064: watched 07:00-20:00, window 22:00 → 18:00, inside; window 05:00 next day → 18:00 the evening before; 07:00-08:30 only, window 22:00 → 07:00; window 08:00 → unchanged; no watched hours → unchanged; 20:00 is outside; fixed instants 03:00, 12:00, 17:59 (not yet) and 18:00, 19:30, 22:30 (raised); an Operations push inside a watched period is sent (test transport). CI is the runner.

## Needs a decision

None for this step. The 2 hours may change on SIG2-10 evidence (PO).
