# Remediation plan: CGR-62 (a leaver's take keeps a P1 safety signal from escalating)

**Written by:** Engineering (`eng`) · 2026-10-26 04:40 (Europe/Zurich) · **Item:** LEAVE1-14 · **Brief:** `briefs/LEAVE1.md` (PO 2026-10-26 02:14 CET)
**Finding:** Clinical Governance Report section 2026-10-26 01:26 CET (PR #416, open when this plan was written), CGR-62, **blocking (S1)**. ADR-091, migration 0078, pgTAP 078.

## Risk

`private.signal_taken_stops_step` (0063) was true for any take with `stops_escalation`, whether or not the taker could still act. Both steps read it: SIG1-5 (untaken after the `signal_untaken` threshold → Operations, `evaluate_signals`) and SIG2's immediate step (nobody reached outside the app → Operations, `outside_settle`). LEAVE1 (0074, 0076) removed a leaver from every receiver set and refused her every command, but left her take in force. `my_signals` (0071) then showed every team member "übernommen von <her name>" and sorted the signal below the untaken ones. Example (from the finding): a registered nurse takes a P1 "Klientin öffnet nicht" at 09:50; her access is withdrawn at 10:05; Operations is never reached and the team reads the signal as handled.

## Affected code and data

`private.signal_taken_stops_step`, `public.take_signal` (the "already taken" answer), `public.my_signals` (result gains `taker_access_ended`), `public.end_member_access` (result gains `taken_signals`). Claim inventory (point 5 of LEAVE1-14): `private.may_perform_visit` (ABS1 return), `private.generate_case_plan` (PLAN2 responsible member), `public.set_primary_nurse`, `public.plan_visit`. App: `src/features/signals/rules.ts`, `src/components/signals/SignalBanner.tsx`, `src/features/admin/{rules,commands}.ts`, `/admin`. No data change: takes stay append-only, nothing is rewritten.

## Steps

1. IMPLEMENTED (0078): `signal_taken_stops_step` counts only takes with `not private.access_ended(taker_id)`. Both steps fire as for an untaken signal once her access has ended; a restore before the step makes her take count again (evaluated live). No threshold, receiver or step changes.
2. IMPLEMENTED (0078): `my_signals` prefers a taker with open access; a take of a person whose access has ended reads as untaken (no name, time or qualification; sorted with the untaken signals) and sets `taker_access_ended`, shown as "Übernahme beendet – Zugang beendet" (no reason code, LEAVE1-8). `take_signal`'s "already taken" answer names a taker with open access first.
3. IMPLEMENTED (0078): `end_member_access` returns `taken_signals` (open signals she had taken), also in the change log and the audit row; `/admin` shows "n übernommene Sicherheitssignale sind wieder offen im Team".
4. IMPLEMENTED (by construction): `signal_takes` stays append-only; `safety_signals.taken_by` (first take) and the SIGC/AN2 measure `signal_qualified_taken_at` keep the historical take.
5. IMPLEMENTED (0078): claim inventory in ADR-091. Relations that would hand her new work after the end now refuse or skip her: ABS1 return (`may_perform_visit`), PLAN2 responsible member, `set_primary_nurse` (`not_in_team`), `plan_visit` (`responsible_not_in_team`).
6. OPEN, listed for the PO (ADR-091, no step is stopped by them): an OPS1 exception "take" and a quality event's `owner_id` still show her name (any coordinator can take over; the P2 → P1 escalation clock runs on, CGR-05/-06); a 'sent' SIG2 outside delivery to her phone counts as "reached" until the SIG1-5 threshold (the untaken step then fires); a reopened case whose primary nurse has left keeps her name until the team changes it (planning skips her).

## Tests

pgTAP 078 (46): an RN takes a P1 no-show (step stopped, also past the threshold); her access ends; the predicate is false for her take and true for a colleague's; a colleague's `my_signals` reads it as ended (no name, time, qualification) and sorts it with the untaken signals; a restore before the step makes her take count again (no escalation); ended again → after the threshold since the signal's start `evaluate_signals` sets `escalated_at` and delivers to Operations once (a second evaluation adds nothing); her take, `taken_by` and `signal_qualified_taken_at` unchanged; a colleague can take it and "already taken" names the colleague; SIG2's immediate step fires after the end when nobody was reached outside the app; the end result, change log and audit row carry `taken_signals`; claim inventory: `may_perform_visit` false, `set_primary_nurse` and `plan_visit` refuse her, PLAN2 never names her. Pinned to the DST1 test clock (10:00 Zurich), never skipped. Unit: `signals-rules`, `admin-rules`. Engineering ran 078 and the other pgTAP files on a local PostgreSQL 16 with a role/auth shim and a pgTAP stand-in (76 of 77 files green; 053 needs `trigger_is`, absent from the stand-in, and fails the same way on unchanged `recovery/main`; 078 fails on the database without 0078). **CI is the runner.**

## Needs a decision

None for the clinical rule: no threshold, receiver or step is new (product authority, PO 2026-10-26 02:14). The four display-only relations in step 6 are listed for the PO in ADR-091 and the status row; Engineering recommends the same treatment (a claim by a person whose access has ended reads as unclaimed) in one later PR.
