# Remediation plan: CGR-51 (Operations saw the nurse's note excerpt; removing it alone would hide what was done at the door)

**Written by:** Engineering (`eng`) · 2026-10-25 19:05 (Europe/Zurich) · **Item:** DOOR1-11 (with DOOR1-5, DOOR1-6) · **Brief:** `briefs/DOOR1.md`
**Finding:** Clinical Governance Report section 2026-10-25 02:26 (CGR-51, **advisory, S2**), decided by the PO 02:10 CET as DOOR1-11; PS-43; `READ_PATHS.md` F-1. ADR-085, migration 0072, pgTAP 072.

## Risk

`operations_exceptions()` showed Operations the first 120 (no-show) or 200 (interruption) characters of the nurse's free-text note, which can carry health data (F-1). Removing it without a structured replacement would leave Operations, the escalation recipient of the P1 no-show, unable to see whether the nurse was at the door.

## Affected code and data

`private.derived_exceptions` (no-show and interruption lines), `public.team_visit_alerts` (team view), new `private.no_show_ops_detail`, `public.record_no_show`, `public.record_no_show_outcome`, `public.visit_status_notes` (two new nullable columns). No data migration: rows recorded before 0072 read "nicht erfasst".

## Steps

1. IMPLEMENTED (0072): `record_no_show` requires "an der Tür: ja/nein"; `record_no_show_outcome` requires the basis for "Notfallkontakt informiert" and refuses one for every other outcome.
2. IMPLEMENTED (0072), same PR as step 1: the no-show line Operations reads is codes only: date, time of the no-show, "an der Tür: ja/nein/nicht erfasst", "Ergebnis offen" (or the outcome, its basis and its time) and "Notiz im Team". The interruption line keeps its reason label and says "Notiz im Team". The excerpt is removed at the source (`derived_exceptions`), so no Operations reader carries it.
3. IMPLEMENTED (0072): the team keeps its note: `/field` status notes, HAND1, and the team alert list (`team_visit_alerts` puts the interruption excerpt back, text unchanged).

## Tests

pgTAP 072: Operations' open no-show row reads "an der Tür: ja · Ergebnis offen · Notiz im Team" and no note text; "an der Tür: nein" and "nicht erfasst" (old row) are shown; both stay P1; with "Notfallkontakt informiert" (basis "Notfall") the line carries door fact, outcome, basis and time and no note text; an interruption row carries its reason label and no note text; the team alert list still shows the note. 045 (team detail unchanged) re-run. **CI is the runner.**

## Needs a decision

None for this finding. Residual, recorded as a deviation: the P1 no-show exception closes when the outcome is recorded (C1, unchanged by DOOR1-10), so Operations' **open** row always reads "Ergebnis offen"; the outcome form of the line is proven on `private.no_show_ops_detail`, which `operations_exceptions` uses. Whether Operations should keep a closed no-show visible with its outcome is a product question (`po`), not decided here.
