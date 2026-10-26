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
- [ ] Negative: no signal, exception, threshold, priority or read scope changes.

## Rules and their input class
No rule is added or changed. The removed TypeScript filter used **care-context fact recorded by a person** (intake urgency) and visit or schedule facts. It was a ranking in the client, so it is removed rather than marked "for the adviser".

## Out of scope
- The five G rules G1-G5 in SQL stay as built until the regulatory adviser answers (D-34).
- "Sicherheitssignal" stays.

## Constraints and references
D-34 (wording rule 2026-10-24 17:10; statement v2 2026-10-26), `ARCHITECTURE.md` Frontend, ADR-006, OPS1, SIG2.

## Open questions for engineering
Is anything else in the legacy `/operations` client (KPIs, "SLA Monitor") still fed by a client-side rule? If so, list it in the PR and move or remove it the same way.
