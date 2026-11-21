# Remediation plan: CGR-48 (outside the watched hours the banner reassures without a basis; SIG1-8 is a manual check)

**Written by:** Engineering (`eng`) · 2026-10-25 10:50 (Europe/Zurich) · **Item:** SIGC (SIG2-C1 (1), (2)) · **Brief:** `briefs/SIGC.md`, `briefs/SIG2.md` (PO 2026-10-24 23:10)
**Finding:** Clinical Governance Report section 2026-10-24 22:26 (PR #321), CGR-48, **advisory (S2; S1 for switching the channel on** in an organisation with visits outside its watched hours), decided by the PO as SIG2-C1 (product authority; display only, input class visit/schedule fact). ADR-082, migration 0068.

## Risk

(1) A care assistant who takes a P1 no-show at 21:30 reads "Meldung an Operations folgt", although the Operations push stays in the app at that hour (SIG2-12). (2) SIG1-8 ("visits outside the watched hours are not planned") is a manual pilot-plan control; nothing in the data shows it is kept.

## Affected code and data

`public.my_signals` (new column `watched_now`); `takenText` (`src/features/signals/rules.ts`); new reader `public.visits_outside_watched_hours`; `/admin`, `/team`. No data change. The live project is not touched.

## Steps

1. IMPLEMENTED (0068): `watched_now` = the SIG2-12 predicate at the reader's instant; no watched hours → false.
2. IMPLEMENTED: `takenText` says "Operations nur in der App: ausserhalb der überwachten Zeit" unless `watched_now` is true (a missing flag never promises the message).
3. IMPLEMENTED (0068): the list of planned visits of the next 7 days not wholly inside the watched periods; `/admin` (organisation) and `/team` (own teams); date, times and team only.
4. PLANNED (Q14, `po`): confirm the protective reading for a visit that is partly outside.

## Tests

pgTAP 069: `watched_now` false without watched hours, true inside, false outside; list: watched 07:00-20:00 → 21:00-21:30 listed, 19:00-19:30 not, 19:30-20:30 listed, no end at 06:50 listed, across midnight listed, day 7 in, day 8 out, cancelled and suspended out, adjacent periods merged, no watched hours → every planned visit, another organisation never, own teams only on `/team`, no client column, anon refused. Unit `signals-rules` (`takenText` with the flag, the line format). e2e `push.spec.ts` at 390 px. CI is the runner.

## Needs a decision

Q14 (`po`, not blocking). SIG1-8 stays a go-live condition until the list is empty for the pilot plan (Clinical Owner); a named watcher stays with D-28 (`clinical`) and D-32 (`owner`).
