---
id: IPA1
title: Intended-purpose alignment of the as-built texts
author: po
status: approved
updated: 2026-10-26
---

# IPA1 — Intended-purpose alignment of the as-built texts

## Problem
The D-34 Intended Purpose Assessment ([report](../reports/D34_INTENDED_PURPOSE_ASSESSMENT.md), F-1, F-5) found that legacy texts and logic contradict the intended-purpose statement and the D-34 wording rule:
- The pre-recovery `/operations` dashboard shows "Top Risiko-Fälle", "Keine Risikofälle.", "Nach Risiko sortiert, nicht alphabetisch.", "Qualitätsrisiken", "Kapazitätsmonitor", "SLA Monitor" and "24–48h gefährdet".
- It filters and sorts client cases in TypeScript (`src/app/(protected)/operations/operations-client.tsx` 131-138, 182-195, 595). The Handbook's frontend rule says React components contain no scoring rule.
- SIG2 texts say "überwachte Zeit(en)" for staffed hours.
- The deprecated `/matching` demo still has a team-request scorer (`matching-demo.tsx` 76-134; ADR-006).

UI and product texts count as use-related information for the intended purpose (CJEU C-427/24, `lca` 19:55). The adviser must assess a product whose texts match its statement.

## Users and journey step
Operations, administrators, every member who reads signal texts. Journey: Operations exceptions, Signals.

## Outcome
No UI text presents an organisational fact as a client risk or as monitoring. No client case is filtered or ranked in a React component.

## Acceptance criteria
- [ ] **IPA1-1** The "Top Risiko-Fälle" panel is removed from `/operations`, or replaced by a list read from the existing server exception model (OPS1). The heading names the organisational fact ("Fälle ohne Team", "Fälle mit offener Teamentscheidung"). No React component filters or sorts cases by `urgency` or by age as a "risk". If a list stays, it comes from a server read model with the same ordering rule as OPS1, and an ADR names it. Renaming the panel while keeping the client-side filter or sort does not satisfy this criterion (*amended 2026-10-26 16:20 by po*, D-34 `lca` 15:04 note 2).
- [ ] **IPA1-2** The team "risk score" is renamed to what it measures ("Auslastung") or removed; no team or case is labelled "Risiko".
- [ ] **IPA1-3** "überwachte Zeit(en)" becomes "besetzte Zeit(en)" in every UI text (`src/features/signals/rules.ts`, `src/features/push/rules.ts`, `src/app/(protected)/admin/outside-section.tsx` and any other hit). Behaviour unchanged.
- [ ] **IPA1-4** The `/matching` demo scorer is removed, or shown not to be reachable in any build that is deployed by an automated check (a test or build assertion that fails if the route or the scorer is in the production bundle). An ADR alone does not satisfy this criterion (*amended 2026-10-26 16:20 by po*, D-34 `lca` 15:04 note 2: a function that exists counts for the intended purpose even when renamed).
- [ ] **IPA1-5** A unit or lint check fails when a UI string in `src/` contains "Risiko", "Überwachung", "überwacht", "Gesundheitszustand" or "Diagnose" outside an allow-list. "Rettungsdienst alarmiert" (a no-show outcome) and "Sicherheitssignal" stay allowed (organisational wording, `lca` 19:55).
- [ ] **IPA1-6** e2e at 390 px: `/operations` renders without the removed panel; the existing OPS1 exceptions and signals are unchanged.
- [ ] **IPA1-7** (*added 2026-10-26 18:10 by po*, `cra` CGR-69 remedies (1) and (2); D-34 question 7) **The intake urgency has no preset and a recorded source.** The intake form preselects no urgency; submitting without one is refused in the UI and in `record_partner_request` (and in every other command that sets an urgency at intake, e.g. the case path of 0013). A new required field records the source as a fixed choice: `referrer_stated` ("vom Zuweiser angegeben") or `intake_assessed` ("bei der Aufnahme eingeschätzt"). The source travels with the value to the case and the matching request and is shown beside the level wherever a team sees the urgency before it decides (`/team` offers). The person who recorded it is the actor already in the audit trail; no new person field. Existing synthetic rows: source `unknown` ("Quelle nicht erfasst"), shown as such, never back-filled as either value. pgTAP: a request without urgency or without source is refused; the source is stored on the request, the case and the matching request; `team_offers` returns it. e2e at 390 px: the form has no preselected urgency; an offer on `/team` shows level and source. The ordering of `team_offers` (G3) is unchanged.
- [ ] **IPA1-8** (*added 2026-10-26 18:10 by po*, hypothesis P-10) **The referrer's requested first-visit date is recorded.** Optional date field "Gewünschter Beginn (laut Zuweiser)" at intake; stored with the request, carried to the case and the matching request, shown on the `/team` offer. It is **not** used to order, filter, escalate or set a deadline. pgTAP: stored and returned; a date before the request's creation date is refused; `team_offers` ordering unchanged with and without it.
- [ ] Negative: no signal, exception, threshold, priority or read scope changes.

## Rules and their input class
No rule is added or changed. IPA1-7 and IPA1-8 add two recorded facts (input class: *care-context fact recorded by a person*, and an organisational date stated by the referrer); neither ranks, routes or escalates anything new. G3 keeps its "for the adviser" mark. The removed TypeScript filter used **care-context fact recorded by a person** (intake urgency) and visit or schedule facts. It was a ranking in the client, so it is removed rather than marked "for the adviser".

## Out of scope
- The five G rules G1-G5 in SQL stay as built until the regulatory adviser answers (D-34). IPA1-7 adds provenance to G3's input; it does not change G3's ordering.
- Criteria for choosing an urgency, and whether an intake person may choose "bei der Aufnahme eingeschätzt" at all: `clinical` (Clinical Owner, G-1; CGR-69 (2)). NAVORA sets none.
- Ordering offers by the requested date (P-10): only after the pilot compares both values.
- "Sicherheitssignal" stays.

## Constraints and references
D-34 (wording rule 2026-10-24 17:10; statement v2 2026-10-26; question 7 (a)-(c), `lca` 17:55), CGR-69 (`cra` 17:26), P-10 (challenge review), `ARCHITECTURE.md` Frontend, ADR-006, OPS1, SIG2.

## Open questions for engineering
Is anything else in the legacy `/operations` client (KPIs, "SLA Monitor") still fed by a client-side rule? If so, list it in the PR and move or remove it the same way.

## PO addendum 2026-10-26 18:10 CET
- **Why IPA1-7 and IPA1-8 join IPA1** rather than a new brief: IPA1 is approved and unstarted (#456), it is the brief that makes the as-built product match the intended-purpose statement before the adviser sees it, and CGR-69 is the same kind of gap: as built, the record cannot show whether a value that ranks offers is a referrer's statement or a person's own judgement (`lca` 17:55: that is the fact adviser question 7 needs).
- **Value:** continuity (value 2) and patient safety: a preset "mittel" can delay a team's acceptance of a discharged client (H-19); the team sees whose urgency it is when it decides. Administration does not grow: one required choice replaces a silent default, and the date is optional.
- **`lca` 17:55:** remedies (1), (2) and P-10 compliant under every plausible interpretation (accuracy and provenance; no new recipient or purpose).

## PO review 2026-10-27 01:40 CET: every criterion met in code and CI, awaiting clinical review of IPA1-7/-8 (migration 0086)

**Delivered:** #484 (IPA1-1 to -6, ADR-099, no migration) merged 0db9992 and #487 (IPA1-7, -8, migration 0086, ADR-100, pgTAP 086 (29)) merged 8e7bb6f on `recovery/main`, 2026-10-27 01:12. CI `app`, `db`, `e2e` on 8e7bb6f read through the GitHub API (results below). **The PO did not run any test**; the PO read the diff 6b19b84..8e7bb6f, the migration, pgTAP 086, the unit test and the e2e specs.

| Criterion | Result | Evidence |
|---|---|---|
| IPA1-1 risk panel removed, no client-side case ranking | met (by removal) | `operations-client.tsx`: "Top Risiko-Fälle", "SLA Monitor", KPI "SLA-Verletzungen" and the urgency/age filter and sort deleted; remaining case filters count by `status` and `assigned_team_id` only (organisational facts, no ranking); cases needing a decision come from the OPS1 server list (ExceptionCenter). No replacement list, so no second ordering rule and no ADR for a read model needed (ADR-099 records the removal) |
| IPA1-2 no team or case labelled "Risiko" | met | team risk score removed; teams sorted by name (`localeCompare`, de-CH) as "Pflegeteams" with "Auslastung"; e2e asserts no "Risk" column header |
| IPA1-3 "besetzte Zeit(en)" | met | `signals/rules.ts` 101, 140-144; `push/rules.ts` 37, 69, 75; `admin/outside-section.tsx` 28; unit tests `signals-rules`, `push-rules` updated; constants renamed in text only, behaviour unchanged |
| IPA1-4 `/matching` scorer removed | met (by removal, with an automated proof) | `src/app/(protected)/matching/` deleted (516 lines); Sidebar link and flag removed; `tests/unit/ipa1-wording.test.ts` fails if either route directory exists or any source file carries `calculateMatchScore`, `getMatchSignals`, `teamFit` or a `"/matching"` link |
| IPA1-5 wording check | met | same unit test: fails on "Risiko", "Überwachung", "überwacht", "Gesundheitszustand", "Diagnose" in any `src/` string; allow-list empty and self-checking for stale entries; "Rettungsdienst alarmiert" and "Sicherheitssignal" pass (asserted). Comments skipped: deviation (4) |
| IPA1-6 e2e at 390 px | met | `tests/e2e/operations.spec.ts` 60-73: none of the nine removed texts present; OPS1 exceptions and signals specs in the same file unchanged |
| IPA1-7 no preset, recorded source | met | intake `<select>` urgency and source `required`, `defaultValue=""` (e2e 390 px asserts both empty); 0086: `urgency_required`, `urgency_source_required` (also refuses `unknown`), the old 11-argument signature dropped; `urgency_source` on request, case, matching request with `unknown` default for existing rows (not back-filled), copied by BEFORE INSERT triggers; `team_offers` returns it; `/team` and `/intake` show "Dringlichkeit: <Stufe> (<Quelle>)" (e2e 390 px); pgTAP 086 refusals (56-70) and carry-through (80-141); actor stays the audit actor, no person field |
| IPA1-8 referrer's requested date | met | optional field "Gewünschter Beginn (laut Zuweiser)"; refused before the request's creation day (pgTAP 68, table check on `created_at` in Zurich time); carried and returned by `team_offers` (pgTAP 133); shown on `/team` (e2e 124); pgTAP 155-165 assert that no other function reads the column |
| G3 ordering unchanged | met | pgTAP 086 asserts the `team_offers` ORDER BY text equals the 0034 rule and the order with and without source and date; LEAVE1-3 guard kept (CI round 1 caught its loss; fixed and asserted) |
| Negative: no signal, exception, threshold, priority or read scope change | met | no signal or exception function touched; `cases` gets no column grant for the new columns (pgTAP 48); offers still carry no client identity (pgTAP 148) |

**Deviations decided:**
- (1) IPA1-1 by removal, no replacement list: **accepted.** OPS1 already lists every case that needs a decision; a second list would be a second ordering rule.
- (2) colour thresholds left on team and organisation KPI cards: **accepted.** They colour counts of organisational facts (unassigned cases, utilisation), not a client. They are named in ADR-099 for the adviser.
- (3) `/operations` still loads `care_visits` (every visit of the organisation with the nurse's name, now unused): **accepted for synthetic data, with condition IPA1-C1** (below). Data minimisation before comfort; the payload is serialised to the browser.
- (4) the wording check skips comments: **accepted.** Comments are not use-related information.
- (5) `referrer_requested_start` kept separate from `cases.requested_start` (0013): **accepted; no pre-fill.** Pre-filling the intake person's field from the referrer's date would blur whose fact it is, the gap CGR-69 named. Both stay labelled by source. Whether the intake field is needed at all is hypothesis P-14 (challenge table).
- (6) date rule only "not before the creation day", no upper bound: **accepted.** An upper bound would be an invented rule.
- (7) no column grant on `cases` for the new columns: **accepted** (teams read through `team_offers`; narrower).
- (8) the old 11-argument `record_partner_request` dropped: **accepted.** Keeping it would leave a path that records an urgency without a source.

**Condition IPA1-C1** (before the first real client, G-13; with COND2, see [COND2](COND2.md)): the `/operations` dashboard no longer reads or serialises `care_visits` (`src/features/operations/queries.ts` 38, `OPERATIONS_VISIT_COLUMNS`). A unit test asserts that the `OperationsDashboard` payload has no `visits` key, and the e2e of IPA1-6 still passes. *Why:* the visits are no longer shown, so sending every visit with the nurse's name to every Operations browser serves no purpose (privacy before comfort).

**Clinical gate:** IPA1-7 changes what a team sees before it accepts a client (intake, J1/J2), so it is in scope. `cra` 21:29 read IPA1-1 to -6 (#484) as protective and IPA1-7/-8 only as a plan (PLANNED). **IPA1 is accepted without another PO round once a `cra` section on the merge commit 8e7bb6f (migration 0086) holds no blocking finding**; a blocking finding returns it to `changes-requested` with the gap. CGR-69 (2) (whether intake may assess urgency, and on which criteria) stays with `clinical` (G-1); NAVORA sets no criteria.
