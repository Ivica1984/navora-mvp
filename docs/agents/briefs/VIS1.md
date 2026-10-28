---
id: VIS1
title: Field actions happen on the visit's day
author: po
status: approved
updated: 2026-10-28
---

# VIS1 — Field actions happen on the visit's day

**Approved by po 2026-10-28 18:15 CET** from `cra` CGR-87 (section 2026-10-28 17:30, PR #614; advisory for every current item, **S1 before a pilot with real clients**). *Next up* 2, after COORD6 (already in PR #612).

## Problem
IMPLEMENTED defect (`cra` CGR-87, read from code; the PO did not run anything). Nothing ties a visit's field actions to its date: `start_visit`, `depart_visit` and `complete_visit` change status by state only (0007:120-170, `private.transition_visit`), `end_visit_not_completed` (0042) and `record_no_show` (0024, 0072) do the same, and `/field` offers "Einsatz starten" on any `planned` visit because `fieldActions(status)` takes no date (`features/field/rules.ts:61-72`, `field-client.tsx:346`). The UX1-27 e2e starts and completes a visit planned eight days ahead (`ux1.spec.ts:366-384`), so CI exercises the path every run.

Three consequences, each named by `cra`:
1. **A missed visit is masked.** On its real date the visit is no longer `planned`, so no overdue or missed signal (CSR1, SIG1, H-01) is raised and nobody learns the client was not seen.
2. **The record states care on a date it was not given** (H-05): the visit date and the event times disagree.
3. **Billing:** billable facts and measured minutes follow `visit_date` (0022:279-280, 331; 0023:190-201), so a service can be billed for a date on which it was not given.

A visit legitimately done earlier already has an audited route: move it (`reschedule_visit`, J3, 0056), then start it.

## Users and journey step
Nurse at the door (`/field`), the team that relies on its overdue signals, and the billing preview. Journey step **Visit → Documentation → Billing** (`ARCHITECTURE.md` data flow).

## Outcome
A visit can only be worked on its own day or after it. A visit done early is first moved, with its audit trail, so signals, the record and billing all name the day care was given.

## Acceptance criteria
- [ ] **VIS1-1 (database):** `depart_visit`, `start_visit`, `record_no_show` and `end_visit_not_completed` refuse a visit whose `visit_date` is **after** today (Europe/Zurich, the DAY-1 rule) with the named outcome `not_today` (name may differ; listed in the ADR): status unchanged, no visit event row, one audit row with the outcome. `complete_visit` refuses a visit that was started on a calendar day (Europe/Zurich) before its `visit_date`.
- [ ] **VIS1-2 (pgTAP):** a visit dated tomorrow: `start_visit` and `depart_visit` refused, status still `planned`, no event row, audit row present. The same visit moved to today with `reschedule_visit`: `start_visit` returns `ok`. A visit dated today and one dated yesterday: unchanged behaviour (both may start).
- [ ] **VIS1-3 (`/field`):** a visit dated after today shows no field action (depart, start, no-show, end not completed; e.g. "Losfahren", "Einsatz starten") and one plain sentence why, with the way forward ("Der Einsatz ist für den <Datum> geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute."). Wording in German, no internal codes (UX1-11). Where the nurse's role can move a visit, the sentence links to the existing move route; where it cannot, it says who can (Engineering names which in the ADR; no new permission).
- [ ] **VIS1-4 (Playwright, phone 390 × 844):** on `/field?datum=<tomorrow>` no "Einsatz starten" is shown; the sentence of VIS1-3 is visible.
- [ ] **VIS1-3a (presentation, po 2026-10-28 20:15 from `uxa` UXR-29):** on a day after today the VIS1-3 sentence appears **once**, under the day heading, styled as `info` (a planned future day is the normal state, not a warning or an error); a card shows no filled button, only the move link as `action-outline` where the nurse's role may move a visit. VIS1-4 additionally asserts: the sentence has count 1, no card on that day has a filled action button, and the line carries the `info` token.
- [ ] **VIS1-5 (tests that start visits):** the UX1-27 e2e and every other test that starts, completes or ends a visit use a visit dated today (or move it to today first). **No guard is weakened, skipped or bypassed to keep a test green** (`cra` CGR-87 test note). This is also how UX1-C1 is closed: the UX1-C1 fix may not rely on starting a future visit.
- [ ] **VIS1-6 (negative):** past-dated visits keep today's behaviour (a forgotten tap can still be recorded); F3 corrections unchanged (CGR-65 condition (a)); no tolerance before the date is coded (see *Rules*).
- [ ] **VIS1-7 (gate):** clinical review gate (README): `cra` reads the migration and tests before merge.

## Rules and their input class
- **"No field action on a visit dated after today"**: input class *visit/schedule fact* (the visit date and the Zurich calendar day). It refuses an action; it does not rank, route or escalate a care-context fact. Built in the core.
- **Any tolerance before the date** (for example a visit planned just after midnight): a level, UNKNOWN. Not built. If one is ever wanted it is set by a named person and entered in the Clinical Rule Register before it is coded (`cra` CGR-87 (4)).
- **Late documentation of a past visit** (whether and how a visit from an earlier day may still be started or completed): Clinical Owner and PO, UNKNOWN (`cra` CGR-87 (3)). VIS1 does not change it.

## Out of scope
- Any rule for past-dated visits (VIS1-6).
- A new move flow or a new permission to move visits; VIS1 links to what exists.
- The billing rules themselves (D-18); VIS1 only keeps the date that feeds them true.

## Constraints and references
`cra` CGR-87 (`reports/CLINICAL_GOVERNANCE.md`, 2026-10-28 17:30); H-01, H-05; CSR1, SIG1 (overdue and missed signals); J3 (`reschedule_visit`, 0056); DAY-1 (Zurich calendar day); J5 (billable facts by `visit_date`); UX1-C1 and UX1-27; D-28 (thresholds PROVISIONAL). Synthetic data only; the live project is not touched (D-1).

## Open questions for engineering
- Does any existing command or job (PLAN2 generation, COVER1, ABS1 release) call `start_visit` or `depart_visit` on a future visit? If yes, name it in the ADR before the guard lands.
- Which roles can move a visit today from a screen a nurse reaches (`/field`, `/team`)? Answer decides the VIS1-3 link or sentence.

## Why now (PO, value order)
Patient safety is a precondition: a masked missed visit is the hazard the whole signal chain (CSR1, SIG1) exists to prevent, and real clients must not meet it. It also protects continuity (value 2: the record says when the client was seen) and nurse income indirectly (value 3: a billing date that cannot be defended endangers the team's revenue). Small: one guard in existing commands, one sentence on `/field`, tests. Placed before ADM2 because it is cheaper than every item behind it and it closes UX1-C1 the right way.

**Challenge (po):** "Why can a nurse start next week's visit at all?" Because the state machine knew status, not time. "Why not let her, and fix the date afterwards?" Because a correction after the fact is administration, and a signal that never fired cannot be recovered. Moving the visit first is one audited step the team already owns; no approval, no coordinator.

## PO decisions 2026-10-28 20:15 CET (`uxa` 19:48, UXR-29)

- **UXR-29 adopted as VIS1-3a** (above): one `info` sentence per future day instead of one per card, the move link per card as outline, and three more assertions in VIS1-4. Reason: on a future day every card is future-dated, so a per-card sentence repeats the same two lines on every card and pushes the day's later visits down; an amber or red style would mark a normal planning day as a problem. The wording of VIS1-3 is unchanged; no rule changes. `cra` reviews the sentence and its style in the VIS1-7 gate as before.
- **Open question "which roles can move a visit"** — PO reading, Engineering confirms in the ADR: `reschedule_visit` checks team membership (`private.is_team_member(v.team_id)` in its first version, migration 0012, line 134; the later versions in 0050 to 0069 were not re-read for this note), so a member of the visit's team can move it herself. If that holds, the VIS1-3 sentence links to the move for her, and no coordinator is needed (value 4). If the ADR finds a nurse who cannot move a visit she sees on `/field`, that is a PO question before merge, not a new permission in this PR.
