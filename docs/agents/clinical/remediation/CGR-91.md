# Remediation plan: CGR-91 ("Heute machen" from a stale page dates a visit to yesterday)

**Finding:** `cra` CGR-91, Clinical Governance Report 2026-10-29 05:30 (PR #646), **blocking for VIS1 acceptance, S2** (H-25, PS-80); issue #638. Placed by the PO as **VIS1-10** (`briefs/VIS1.md`, 02:15, amended 03:10 and 04:10). Engineering: ADR-116, migration 0093.

**Risk:** "Heute machen" confirmed after midnight on a page rendered the day before sent yesterday's date; `reschedule_visit` accepts a past date (/team *Nachtrag*), so the visit was moved to yesterday while the form said "Heute". Start and completion afterwards carry the wrong service date in the record and in billing; the `moved` fact contradicts what happened.

**Affected code and data:** `/field` "Heute machen" (`field-client.tsx`, `MoveToToday`), the command it calls. No data migration; existing rows are not touched. `reschedule_visit` unchanged.

**Steps (IMPLEMENTED in the VIS1-10 PR, CI decides):**
1. Migration 0093: `move_visit_to_today` moves the visit to the database's today (Europe/Zurich) through the unchanged `reschedule_visit` only when that is the date she was shown; otherwise `day_changed`: nothing changes, one audit row, the database's today returned.
2. `/field`: after `day_changed` the confirmation stays open with the `cra`-confirmed sentence (focus on it), the new date, re-derived times and the kept reason; nothing is stored until she confirms the shown date again. Where it no longer applies, the reload sentence.

**Tests:** pgTAP `093_vis1_10_move_to_today_lands_on_today.test.sql` (pinned 00:05: refused with yesterday's date, nothing changed, one audit row; `ok` with today's date; the /team move to a past date still `ok`). vitest `vis1-10-day-changed`. Playwright `vis1-10.spec.ts` (browser clock across 00:00; focus, values, second confirm).

**Needs a decision (not coded):** none new. Tolerance around midnight and late documentation stay with `clinical` and the Clinical Owner (CGR-87 (3), (4); UNKNOWN). `cra` reads the sentence in the VIS1-7 gate of this PR.
