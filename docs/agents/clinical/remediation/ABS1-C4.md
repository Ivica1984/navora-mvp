# Remediation plan: ABS1-C4 (a visit planned for, or moved into the absence of, an absent member)

**Written by:** Engineering (`eng`) · 2026-10-23 17:30 (Europe/Zurich) · **Item:** ABS1 · part 3, built under issue #149 (migration 0050, ADR-061)
**Finding:** PO review 2026-10-23 16:18 in [`briefs/ABS1.md`](../../briefs/ABS1.md), condition ABS1-C4 (patient safety), with ABS1-N1 (privacy). Not a Clinical Governance Report finding: no `cra` section covers it yet (the newest, 14:30 and 15:00 on PR #203, predate it). Same class as CGR-27 and CGR-28.

## Risk

The absence was checked when it was recorded, at take, in "Offen im Team" and in PLAN2, but not when a visit was given to her afterwards by hand. `plan_visit` with her as responsible, or `reschedule_visit` moving her visit into her absence, left the visit with her: it looked covered, was missing from "Offen im Team" and raised no `visit_uncovered` until `visit_overdue` after its start.

## Affected code and data

- `public.plan_visit` (0014): new refusal `responsible_absent`.
- `public.reschedule_visit` (0014): release after the move through `private.release_visits_between` (0046), linked in `absence_releases`.
- `public.record_absence` (0048): `released` counts the caller's teams only (ABS1-N1).
- `/team`: German text for `responsible_absent`; a notice after a move that released the visit.
- No data is rewritten. Visits given by hand to an absent member before 0050 are not searched for: no real client data exists in the pilot database (D-1), so none can exist outside test data.

## Steps

1. IMPLEMENTED: `plan_visit` refuses a responsible member absent at the visit's interval (`private.visit_interval`, the person in the organisation).
2. IMPLEMENTED: `reschedule_visit` into her absence releases the visit (fixed text `Abwesenheit`, J3 log), never refuses the move.
3. IMPLEMENTED: ABS1-N1.
4. PLANNED (COVER1 condition, D-3): `accept_cover` refuses a nurse absent at the visit's interval.

## Tests

- pgTAP `050_abs1_part3` (31): (a) plan with an absent responsible → `responsible_absent`, no row; (b) the same visit uncovered → ok, in "Offen im Team"; (c) her visit moved into her absence → nobody responsible, log `moved` then `released:Abwesenheit`, linked, listed; withdrawing the absence returns it; (d) the same move outside her absence keeps her; (e) absent via team Nord, she cannot be made responsible in team Mitte (joined later, and as a member of both teams when it was recorded); a Mitte visit moved into that absence is released, not linked; ABS1-N1: a colleague of one team gets `released` for her team only, the member herself for both.
- `048_abs1_part2`: the two-team assertion now expects `released: 1` (ABS1-N1).
- CI runs them; nothing is claimed as passed before CI.

## Needs a decision (not built here)

- None for a clinical, legal or tariff rule: the check is the existing absence and interval arithmetic. UNKNOWN for the PO: whether a move to yesterday inside her absence should be refused (the release rule never touches past visits; ADR-061 deviation 2).
