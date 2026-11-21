# Remediation plan: CGR-58 (the banner judged the watched hours when read, not when the step to Operations is made)

**Written by:** Engineering (`eng`) · 2026-10-25 16:20 (Europe/Zurich) · **Item:** FUP1-2 · **Brief:** `briefs/FUP1.md`
**Finding:** Clinical Governance Report section 2026-10-25 13:26 CET (PR #374), CGR-58, **advisory (S3)**. ADR-084, migration 0071, pgTAP 069, unit `signals-rules.test.ts`.

## Risk

`my_signals.watched_now` is `watched_inside(org, now)` at the reader's instant. A care assistant who takes a P1 no-show at 19:55 (watched until 20:00) read "Meldung an Operations folgt", although the step, due after 20:00, stays in the app (`outside_classify` judges at delivery time). The text promised a push that does not happen.

## Affected code and data

`public.my_signals`, `src/features/signals/rules.ts` (`takenText`). No data change.

## Steps

1. IMPLEMENTED (0071): `private.signal_step_outside_app(signal, at)`. Step made (an Operations delivery exists, or the signal is escalated): true only for an Operations delivery handed to the sender or sent (`pending`, `sent`). Not made: `watched_inside` at the instant the step is due (the episode's untaken threshold, never earlier than `at`); no threshold → false.
2. IMPLEMENTED (0071): `my_signals` gains `operations_outside_app`; `watched_now` unchanged.
3. IMPLEMENTED: `takenText` promises the message only on `operations_outside_app === true` when the row carries it; only a row without the field (an older reader) falls back to `watched_now`. A null flag never promises.

## Tests

pgTAP 069 (+11): watched until 20:00, care assistant takes at 19:55, step due 20:05 → app only; watched until 21:00 → follows; an Operations delivery already sent → follows, also read after the period; `outside_working_time` → app only while a watched period runs; step made without an outside delivery → app only; the reader with `watched_now` true but the step made in the app → false. Unit: `takenText` for both cases and the null flag. **CI is the runner.**

## Needs a decision

None (display of a delivery classification; no threshold or watched period changes, D-28 and D-32 untouched). Residual, UNKNOWN in practice: a step due within the minute before a watched period ends is classified by the scheduled evaluator up to one run later, possibly after the period; the text then says "folgt" for a step that stays in the app. Read from the code, not asserted; a margin would be a new rule (`po`).
