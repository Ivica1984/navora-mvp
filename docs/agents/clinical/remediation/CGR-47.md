# Remediation plan: CGR-47 (AN2 counts the first take, not the one that stops the step)

**Written by:** Engineering (`eng`) · 2026-10-25 10:50 (Europe/Zurich) · **Item:** SIGC (SIG1-C2) · **Brief:** `briefs/SIGC.md`, `briefs/SIG1.md` (PO 2026-10-24 23:10)
**Finding:** Clinical Governance Report section 2026-10-24 22:26 (PR #321), CGR-47, **advisory (S3)**, decided by the PO as SIG1-C2 (product authority; an AN2 parameter, not a clinical value). ADR-082, migration 0068.

## Risk

The Clinical Owner reads AN2 measure 10 and SIG2-10 before lifting SIG1-8. For a no-show or a broken-off visit the first take may be a care assistant's, which does not stop the step to Operations (SIG1-C1). The evidence then overstates how fast a qualified person responded.

## Affected code and data

`public.pilot_hypotheses` (measure 10: `signal_taken_share`, `signal_minutes_to_take`; SIG2-10: `signal_taken_within_threshold_share`); `/analytics` labels. Reads `signal_takes` (0063). No data change. The live project is not touched.

## Steps

1. IMPLEMENTED (0068): `private.signal_qualified_taken_at`: `no_show`, `visit_interrupted` → first take with `stops_escalation`; other kinds unchanged.
2. IMPLEMENTED (0068): the three measures read it; a take that does not stop the step counts as not taken.
3. IMPLEMENTED (0068): `first_take_any_minutes` keeps the first take of anyone, labelled "Nicht die qualifizierte Antwort (SIG1-C2)".

## Tests

pgTAP 069: care assistant +2 min, registered nurse +20 min → time to take 20, first take 2, within the 15-minute threshold 0 %; care assistant only → not taken (no-show and broken-off visit); overdue visit unchanged (5 min, in time); AN1 suppression with two performers; notes. A mutation back to the first take fails five assertions (local stand-in run, not CI). CI is the runner.

## Needs a decision

None. Thresholds stay provisional (D-28).
