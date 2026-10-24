# Remediation plan: CGR-43 (a care assistant's take of a P1 no-show stops the step to Operations)

**Written by:** Engineering (`eng`) · 2026-10-24 20:40 (Europe/Zurich) · **Item:** SIG1 condition SIG1-C1 (*Next up* 1) · **Brief:** `briefs/SIG1.md` (PO 15:10)
**Finding:** Clinical Governance Report section 2026-10-24 14:27 (PR #294), CGR-43, **advisory (S2)**, decided by the PO as SIG1-C1; `cra` 18:26 (PR #306, not yet merged) adds: SIG2's immediate step (`outside_settle`) must be treated the same way. Related: D-28, D-19.

## Risk

Any recipient can take a P1 signal, and a take stops the SIG1-5 step to Operations (and SIG2's immediate step). A care assistant can take a P1 no-show ("Klientin öffnet nicht") or a broken-off visit, and nobody else is told. Behind a closed door there may be a fall or a deterioration; whether a care assistant may answer that alone is a clinical question (UNKNOWN, D-28).

## Affected code and data

- `public.take_signal`, `public.my_signals`, `private.evaluate_signals` (SIG1-5 loop), `private.outside_settle` (0060, 0062).
- New: `public.signal_takes` (taker, qualification, stops the step or not, time). No client data, no free text. The live project is not touched.

## Steps

1. IMPLEMENTED (0063): every take is a row with the taker's qualification in the visit's team (cover team for the covering member).
2. IMPLEMENTED (0063): for `no_show` and `visit_interrupted`, only a take by a registered nurse of the team, the covering registered nurse, or one of the people the step reaches (Operations) stops the SIG1-5 step and SIG2's immediate step. A care assistant's take is recorded and shown ("übernommen von <Name> (Pflegehilfe), Meldung an Operations folgt").
3. IMPLEMENTED (0063): a registered nurse can still take a signal a care assistant took; that take stops the step.
4. Unchanged (SIG1-C1 (c), (e)): other kinds, thresholds, response times, recipients, ADM1 range guard, SIG1-9.

## Tests

pgTAP 065: care assistant takes a P1 no-show → escalated after `signal_untaken`, Operations has the `untaken` row; registered nurse takes → not escalated; care assistant then registered nurse → not escalated; care assistant takes `visit_overdue` → not escalated; channel on, care assistant takes within the 2 minutes, no outside send succeeds → Operations still receives it (the `cra` note); both takes kept with qualification; guard and audit. Unit `signals-rules`: the text and the banner split. CI is the runner.

## Needs a decision

- **clinical (D-28):** whether other kinds (overdue, stuck, uncovered) need a registered nurse's take; whether Operations' take is enough for a no-show (engineering reading in ADR-077, reported to the PO).
- **clinical (D-19):** the no-show protocol itself.
