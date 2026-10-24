# Remediation plan: CGR-37 (visit safety signals are pull-only)

**Written by:** Engineering (`eng`) · 2026-10-24 10:20 (Europe/Zurich) · **Item:** SIG1 (issue #246) · **Brief:** `briefs/SIG1.md`
**Finding:** [Clinical Governance Report, section 2026-10-24 02:26](../../reports/CLINICAL_GOVERNANCE.md), CGR-37, **advisory (S2; S1 if visits are planned when nobody watches)**. Hazard H-01, safety risk PS-29. Product decision: PO 2026-10-24 03:10 (SIG1).

## Risk

A P1 overdue, stuck, uncovered, interrupted or no-show visit exists only when someone opens `/team` or OPS1. A client who did not receive a planned visit can go unnoticed for hours.

## Affected code and data

- Readers: `private.derived_exceptions` (0019 … 0049), `public.team_visit_alerts`, `public.operations_exceptions`; rules `public.exception_rules` / `private.effective_exception_rules` (0059).
- New data: `public.safety_signals`, `public.signal_deliveries` (no client name, no free text, no health data). The live project is not touched.
- App: `/field`, `/team`, OPS1.

## Steps

1. IMPLEMENTED (0060): a server writer records each P1 episode and one delivery per recipient (responsible member, present members of the owning team; Operations when nobody of the team is on duty), exactly once; pg_cron every minute and the page poll.
2. IMPLEMENTED (0060, app): the three pages show open P1 signals at the top within 60 s without a reload; "Ich übernehme" records who and when; the signal stays open until its cause ends (CR-041 unchanged).
3. IMPLEMENTED (0060): untaken after `signal_untaken` (15 min, PROVISIONAL) → Operations once; stricter only.
4. IMPLEMENTED (0060): AN2 measure 10 shows the share taken and the median minutes to take, per team.
5. NOT software (SIG1-8, PO): the pilot plan names, for every hour with planned visits, the person who has a NAVORA page open. Outside the app nothing is delivered until SIG2 (D-32, D-33).

## Tests

pgTAP 062 (recipients, exactly once, new episode, P2 not delivered, stricter rule delivers sooner, take and duplicate, non-recipient, coach, removed member, absence fallback, other organisation, RLS, guards, untaken threshold and range, no-show kind, removed visit, AN2 rows); e2e `signals.spec.ts` (a no-show reaches a colleague's open `/field` without navigation; take; the other sees who). CI is the runner.

## Needs a decision

- **clinical (D-28):** who must respond and how fast; the `signal_untaken` threshold (PROVISIONAL 15 min).
- **po:** whether an absent responsible member should still receive the delivery (built: she does not); whether `cover_without_access` is delivered (built: not, not in the brief's list).
