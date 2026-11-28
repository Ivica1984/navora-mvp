# Remediation plan: CGR-69 (the intake urgency that orders team offers has a preset value and no recorded source)

**Written by:** Engineering (`eng`) · 2026-10-26 21:40 (Europe/Zurich) · **Item:** IPA1 (IPA1-7, IPA1-8) · **Brief:** `briefs/IPA1.md` (PO addendum 2026-10-26 18:10 CET)
**Finding:** Clinical Governance Report section 2026-10-26 17:26 CET, CGR-69, **advisory (S2)**; Hazard Log H-19; Safety Risk Register PS-58. Written before IPA1-7 is built (README *Clinical review gate*: the finding creates a safety risk for the item).

**Implementation:** 2026-10-26 23:25, PR #487, migration 0086, ADR-100. Steps 1-5 are built. Step 4 uses the column name `referrer_requested_start`, because `cases.requested_start` (0013) is the intake person's own fact (ADR-100 deviation (1)).

## Risk

The intake form preselects "mittel" (`src/app/(protected)/intake/intake-client.tsx`, `defaultValue="mittel"`) and states no criteria. `team_offers` (0017) orders a team's offers `hoch` → `mittel` → `niedrig`. A coordinator who does not touch the select files every referral as "mittel", and the record cannot tell a referrer's statement from an intake person's own reading of the need summary. A wrong level can delay a team's acceptance and so the first visit of a client discharged from hospital (H-19).

## Affected code and data (UNKNOWN until analysed in the IPA1-7 PR; to be confirmed against the code)

- Commands that set an urgency at intake: `public.record_partner_request` (0010) and the case path that copies it (0013, named by the brief); any later redefinition (to be listed in the ADR).
- Tables: the partner request, `cases`, the matching request (each carries `urgency`); `team_offers` (0017 and later redefinitions) returns the level.
- App: `src/app/(protected)/intake/intake-client.tsx`, `src/features/intake/commands.ts` and schema, `/team` offer card.
- Existing synthetic rows: no source recorded.

## Steps (all PLANNED, IPA1-7/-8 PR; no clinical rule is added)

1. Remove the preset from the intake form; the empty choice is refused in the UI (zod) and in every intake command that sets an urgency (`urgency_required`).
2. New required column `urgency_source` with the fixed values `referrer_stated` / `intake_assessed`; existing rows `unknown` ("Quelle nicht erfasst"), never back-filled as either value. Refused when missing (`urgency_source_required`). Column grants and the audit trigger as on the existing columns; the recording person stays the audit actor (no new person field).
3. The source travels with the level from the request to the case and the matching request, and `team_offers` returns it; `/team` shows "Dringlichkeit: <Stufe> (vom Zuweiser angegeben | bei der Aufnahme eingeschätzt | Quelle nicht erfasst)".
4. IPA1-8: optional `requested_start` ("Gewünschter Beginn (laut Zuweiser)"), refused before the request's creation date, carried and shown; never read by any order, filter, escalation or deadline.
5. `team_offers` ordering (G3) unchanged: the ORDER BY is not touched.

## Tests (PLANNED)

pgTAP: a request without urgency, or without source, is refused; source stored on request, case and matching request; `team_offers` returns it; old rows read `unknown`; requested date stored and returned, a date before creation refused; `team_offers` order identical with and without the date and for each source. e2e at 390 px: no preselected urgency; an offer on `/team` shows level and source. CI is the runner.

## Needs a decision

Not for this plan: steps 1-5 are product authority (PO 18:10; `lca` 17:55 compliant under every plausible interpretation). **Whether an intake person may choose "bei der Aufnahme eingeschätzt" at all, and on which criteria, stays with `clinical`** (Clinical Owner, G-1; D-34 question 7). Until answered, both values are offered as the brief says; NAVORA sets no criteria.
