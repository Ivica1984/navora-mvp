# Remediation plan: CGR-52 (safety alerts on the nights the clock changes)

**Written by:** Engineering (`eng`) · 2026-10-25 05:50 (Europe/Zurich) · **Item:** DST1 (*Next up* 1) · **Brief:** `briefs/DST1.md` (PO 2026-10-25 02:10 CET)
**Finding:** Clinical Governance Report section 2026-10-25 02:26 (open PR #341), CGR-52, **advisory (S3; root cause UNKNOWN)**. ADR-081, migration 0067.

## Risk

On the autumn night (2026-10-25) a visit planned in the repeated hour 02:00-02:59 and not started was raised overdue (CSR1, CR-038) and escalated to P1 (SIG1, CR-066, CR-072) **one hour late**: H-01 (a planned visit nobody notices) for up to one hour, once a year, for visits planned in that hour. On the spring night a planned time that does not exist (02:00-02:59) had no written rule.

## Root cause (IMPLEMENTED in the code before 0067; reproduced, see ADR-081)

- Production code, not only fixtures: every function turned a Zurich local date and time into an instant with PostgreSQL's `at time zone 'Europe/Zurich'`, which resolves an ambiguous local time to the **later** instant (CET). 2026-10-25 02:30 → 01:30 UTC instead of 00:30 UTC.
- The test fixtures stored real "now minus N minutes" as a Zurich local time, exactly as a planned visit is stored, so they showed the production behaviour. Some fixtures also subtracted on the wall clock (`now() at time zone … - interval`), which is wrong across a transition.
- The app's correction input (`zurichLocalToIso`, F3) resolved the repeated hour to the later instant too, although its comment said "earlier": a departure corrected to 02:59 at 02:19 CET was refused as "in the future" (e2e `field.spec.ts` F3, PO journal 02:10 CET).

## Affected code and data

- All 82 functions in `public` and `private` that converted a Zurich local time or read `now()` (re-created from their own definitions, no other change), 49 column defaults (`now()` → `private.now()`), `src/features/field/time.ts`. No data change. The live project is not touched.

## Steps

1. IMPLEMENTED (0067): `private.at_zurich(timestamp)`: ambiguous → earlier instant (CEST); non-existent → standard-time reading (CET), never later than CET; otherwise unchanged. Every conversion uses it.
2. IMPLEMENTED (0067): `private.now()` and the seeded test-clock switch, so pgTAP can run at a pinned clock (DST1-1). Without the seed row it is `now()`.
3. IMPLEMENTED (`time.ts`): the correction input uses the same rule as the database.
4. IMPLEMENTED (tests): fixtures that subtracted on the wall clock now convert explicitly (019, 023, 028, 029, 039, 061, 062, 064, 065, and the two concurrency scripts); 034 no longer uses a fixed calendar date; the e2e F3 corrections pick a number of minutes back that can be typed in the second pass of the repeated hour (20 → 80, 15 → 75), same assertions.
5. IMPLEMENTED (tests, seed, CI): fixtures and seed read `private.now()`; the CI `db` job pins the clock to 10:00 of the Zurich day of the run before seeding, so pgTAP no longer depends on the hour CI runs. The four-clock proof is a local run (ADR-081 table); a CI run at the four clocks is PLANNED if the runner allows it (ADR-081 *Open*).

## Tests

pgTAP 068 (40, every scenario at a pinned clock): conversion at both transitions; the test clock is honoured only with the seeded switch; 02:30 on 2026-10-25 is P2 by 02:40 CEST (CGR-52 remedy) and P1 at 02:35 CET with the P1 time 01:30 UTC, delivered to the responsible member and the team, and to Operations after 15 minutes untaken; the non-existent 02:30 on 2027-03-28 is overdue from 01:30 UTC (CET reading) and P1 one hour later; an ordinary daytime instant; guards against a native conversion or a bare `now()` in any function body or column default. Unit: `field-time.test.ts` (both transitions). No assertion of 038, 046 or 062 changed its meaning (same signal, priority, receivers; fixtures read `private.now()`, the 062 P1-time expectation uses the same conversion); 056 checks the new written form of the same Zurich-date rule.

## Needs a decision

None. The rule is a time-conversion rule (input class *visit/schedule fact*, brief DST1). No threshold, priority, receiver or step changes (D-28 unchanged). `cra` is asked to review the production change (DST1-5).
