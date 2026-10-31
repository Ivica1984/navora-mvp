# Remediation plan: CGR-41 (outside delivery can leave a P1 with no outside recipient)

**Written by:** Engineering (`eng`) · 2026-10-24 14:38 (Europe/Zurich) · **Item:** SIG2 (issue #283) · **Brief:** `briefs/SIG2.md`
**Finding:** Clinical Governance Report section 2026-10-24 10:26 (PR #278, not yet merged into `recovery/main`), CGR-41, **advisory (S2)**. Product decisions: D-32 (po 09:12) and its addendum for CGR-41 points 1-3 (po 11:09). Related: CGR-37, PS-29, H-01.

## Risk

With outside delivery only to the responsible member and to colleagues inside their planned working time, a P1 raised when nobody is in a span (an uncovered hospital-discharge visit by definition has no responsible member; a look-ahead P1 can be raised at night) reaches nobody outside the app. If nobody watches a page either, a client can miss a visit unnoticed.

## Affected code and data

- Writer `private.evaluate_signals` (0060), now followed by `private.outside_after_evaluate` (0062).
- `private.derived_exceptions` (uncovered branch, 0019 … 0061) for the watched-hours raise.
- New data: `signal_outside_deliveries` (result per SIG1 delivery row), `safety_signals.outside_none_at`, `organization_watched_hours`. No client data, no free text. The live project is not touched.

## Steps

1. IMPLEMENTED (0062, CGR-41 point 1): when every outside row of a new P1 episode is decided and none is `sent` (not active, outside working time, failed, or not reported by the sender within 2 minutes), the signal records `outside_none_at` ("kein Empfänger ausserhalb der App") and Operations gets the `untaken` delivery at once (the SIG1-5 step, without the 15-minute wait). OPS1 shows "an Operations: kein Empfänger ausserhalb der App".
2. IMPLEMENTED (0062, point 2): the untaken step goes to Operations only; outside the app only to Operations members who opted in. No outside step to the whole team (`lca` 10:47: Pikett unresolved). `/team` says so.
3. IMPLEMENTED (0062, point 3, software part): watched hours per weekday in `/admin`; a look-ahead `visit_uncovered_hospital` whose window would open outside them is raised at the end of the last watched period before (earlier, never later). With no watched hours nothing changes.
4. NOT software: the pilot plan (SIG1-8) names who watches in the recorded watched hours; SIG1-8 stays a go-live condition until the Clinical Owner lifts it on AN2 evidence (SIG2-10).

## Tests

pgTAP 064: the CGR-41 set (uncovered hospital-discharge visit with zero outside recipients → `outside_none_at`, Operations delivery at once; a colleague inside her span → handed to the sender, no immediate Operations delivery; outside her span → in the app only); every send failed and the sender timeout → Operations at once; the untaken step only to Operations; watched hours 07:00-20:00 (08:00 inside as today, 22:00 → 20:00, 05:00 → 20:00 the evening before, no hours → unchanged) and one integration through `derived_exceptions`. CI is the runner.

## Needs a decision

- **clinical (D-28):** whether a P1 raised at night must be answered at once and by whom (CGR-41, UNKNOWN); the 2-minute sender timeout is an engineering parameter (fail closed), not a response time.
- **owner (D-2):** VAPID key pair, service-role key, dispatch secret and the one-minute scheduler in staging/production; until then nothing leaves the app and step 1 applies to every P1 of an organisation that switched on.
- **po:** the deviations recorded in `IMPLEMENTATION_STATUS.md` (SIG2).
