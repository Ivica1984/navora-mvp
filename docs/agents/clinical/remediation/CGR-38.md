# Remediation plan: CGR-38 (an order present without an end date never raises a signal)

**Written by:** Engineering (`eng`) · 2026-10-24 11:35 (Europe/Zurich) · **Item:** ORD0 (issue #247) · **Brief:** `briefs/ORD0.md`
**Finding:** [Clinical Governance Report, section 2026-10-24 02:26](../../reports/CLINICAL_GOVERNANCE.md), CGR-38, **advisory (S2)**. Hazard H-18, safety risk PS-30. Product decision: PO 2026-10-24 03:10 (ORD0-4, ORD0-6).

## Risk

B care continues for any length of time on an order without an end date; nobody is prompted to renew it. Billing already refuses such an order (CR-046). Whether an open-ended B order is ever valid is `legal` (D-22): UNKNOWN.

## Affected code and data

- Readers: `private.derived_exceptions`, `public.operations_exceptions`, `public.team_visit_alerts`, `private.exception_closes_with_cause`; rule row in `public.exception_rules`.
- New data: `private.order_open_end_episodes` (internal; case, team, start, end, ending code). The live project is not touched.
- Unchanged: intake (an order without an end date is still accepted), PLAN2, `order_expiring`, billing.

## Steps

1. IMPLEMENTED (0061): exception `order_without_end_date`, P3, no threshold: running case (lifecycle `active`, a team), order `present`, no end date, an active B item. In OPS1 and on `/team`.
2. IMPLEMENTED (0061): it closes only with its cause (end date entered, order no longer `present`, no active B item, case not active); a hand close returns `cause_persists`; an earlier close never hides it.
3. IMPLEMENTED (0061): each period is recorded with its ending; AN2 measure 10 `order_open_end_ending` per ending code.

## Tests

pgTAP 063: B item + order present without end date → exception (team, case entity); A/C only → none; C item → none; end date entered → gone; B item retired → gone; episodes and endings; OPS1 P3 not closable, hand close `cause_persists`; `/team` shows it; another organisation → none. CI is the runner.

## Needs a decision

- **legal (D-22):** whether an open-ended B order is valid and its duration. No duration is built.
