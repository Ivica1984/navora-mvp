---
id: HAND1
title: Handover without the team meeting
author: po
status: approved
updated: 2026-10-22
---

# HAND1 — Handover without the team meeting: "since you were last here"

## PO review — 2026-10-22 18:20: accepted, with one condition

Reviewed on merged evidence: #128 (merge 3a4d691; CI green on the PR head 352862e and on the merge commit: app, db, e2e; also green on `recovery/main` 19381f2), ADR-047, migration 0033, pgTAP 033 (30 assertions), unit `handover-rules.test.ts`, e2e `field.spec.ts` (HAND1 part). **The PO did not run the tests**; results are taken from CI.

| Criterion | Result | Evidence |
|---|---|---|
| Section on the `/field` card, oldest first, every entry after her own last completed visit | met | `since-last-section.tsx`; `private.handover_rule` (rule `since_own_visit`, window from her own completed event); pgTAP 033 "her own last completed visit sets the window", ordering assertion; e2e visit 509 |
| Observations and handovers from other visits | met | `handover_entries` kind `observation`, current versions only; pgTAP 033 old observation before the window excluded, newer one shown with author and source visit |
| Care-plan changes with what and why | met | kinds `care_plan_added`, `care_plan_retired` (reason), `care_plan_schedule` (old → new, audit trigger widened in 0033) |
| Pause, resume, cancellations, no-shows (C1) | met | kinds `case_pause/resume/close/reopen`, `visit_cancelled`, `visit_no_show`; pgTAP 033 pause and resume counted, cancellation with reason code |
| Primary-nurse and deputy changes (J6) | met | kind `primary_nurse` with old → new as member labels and the change-log reason; pgTAP 033 |
| Quality events the team can see, with current status | met | kind `quality_event`, own teams only; pgTAP 033 status `open` shown, an event the team cannot see absent |
| Medical order status changes | met | kind `medical_order` with status, validity and reason; pgTAP 033 (author outside the team shown as "outside") |
| Never visited: last 3 completed visits, configuration, card says which rule | met | `handover_settings` (default 3), rule `last_visits`; pgTAP 033 rule and lookback, "the number of visits is configuration"; `ruleText` on the card |
| What, who (member label), when, which visit; nothing summarised or ranked; no AI | met | `member_code` (no user ids leave the database), `sourceText`; unit test "shows free text exactly as recorded"; order by time only |
| Empty state with the date | met | `emptyText` "Nichts Neues seit deinem letzten Einsatz am …"; pgTAP 033 `no_visits` row; unit test |
| No extra tap; start records what was shown | met | trigger `visit_events_handover_shown` on `started`; `handover_shown` append-only, references only; pgTAP 033 one row, entry count matches, delete refused |
| Access not widened; covering nurse gets nothing until D-3 | met | card requires team membership; case-bound entries only for the assigned team; pgTAP 033 "another team's nurse (also when covering) sees no entries" |
| Phone width, loads with the card, collapsible | met in code; **phone width not asserted for the section** | `<details>`, open before start, `min-h-11` summary; loaded in `field/page.tsx` with the day; e2e asserts open/collapsed state at the default viewport only |
| AN1 share of visits after another nurse with the section shown | met | `handover_shown_before_start` in `pilot_kpis`; pgTAP 033 org-level row |
| Negative: other team, other organisation, invisible quality event, other case of the same client | met | pgTAP 033 four assertions (other team 0, other organisation 0, `d02` absent, "anderer Fall" absent) |

**Why accepted.** Every criterion is met on merged tests. The design is right for the care model: the record, not a meeting or a person, carries what changed, and the nurse reads it at the place of care without a tap. It is one read-only query over the append-only records, with no copy of clinical data and no widened access. This makes a deputy visit as well-informed as a primary-nurse visit, which is the precondition for performing a cover once D-3 allows it.

**Condition (testable, in engineering's next PR that touches `tests/e2e/field.spec.ts`):**
- [ ] An e2e assertion at phone width (390 px) that the "Seit deinem letzten Einsatz" section is visible, open before the start, and causes no horizontal scroll on the card.

**Deviations, decided:**
- "Shown" means present in the section at the start; reading is not recorded: **accepted**. The brief excludes read receipts. AN1 must keep the note that this is not proof of reading (it does).
- Change-log reasons for primary-nurse and medical-order changes are now readable by the case's own team: **accepted**. The assigned team already reads the case and its order data (J1 column rules); the reason is part of that record, and it is not visible to other teams.
- Plan-generator changes appear as their care-plan entry, not as one entry per moved visit: **accepted**. It shows the cause once instead of many derived lines; that is less noise, not less information.
- Schedule changes recorded before migration 0033 show without old/new values: **accepted**. Only synthetic data exists.

**Hypothesis for the pilot (challenge table):** pilot teams record their handover-meeting minutes for two weeks before and after HAND1 is switched on; AN1 `handover_shown_before_start` gives the system side.

## Problem
**Challenge finding (PO, 2026-10-22).** Traditional home care keeps continuity through the daily team handover meeting (*Rapport*), phone calls between colleagues, and a shift lead who knows "what happened with Mrs X". Buurtzorg keeps the meeting inside the team. Why does it exist? Because the nurse arriving at a client does not know what changed since she was last there.

NAVORA already records everything that changed: observations and handovers (F1–F4), care-plan changes with reasons (J3), primary-nurse changes (J6), quality events (QG1), report corrections (F6), and soon pauses, cancellations and no-shows (C1). Today the `/field` card shows only the **last** handover. A nurse who was away for a week sees one note out of ten. She has to ask someone. This is why the meeting and the phone calls survive.

If NAVORA were designed from scratch, the information would come to the nurse at the visit. It would not wait for a meeting.

## Users and journey step
The nurse doing the visit (own team; covering nurse from COVER1 once D-3 allows). Journey: Planning → **Visit**. Feeds Continuity (J6) and Quality (QG1).

## Outcome
Before she starts a visit, the nurse sees everything recorded about this client since she last saw them, in order and with its source. She does not need a meeting or a phone call to be up to date.

## Acceptance criteria
- [ ] The `/field` visit card has a **"since you were last here"** section. It lists, oldest first, every entry recorded for this case after the nurse's own last completed visit with this client:
    - observations and handovers from other visits;
    - care-plan changes from the J3 change log (what changed and the reason);
    - pause, resume, cancellations and no-shows (C1, as soon as C1 is merged);
    - primary-nurse or deputy changes (J6);
    - quality events the team can see (QG1), with their current status;
    - changes to the medical order status (J1, J3).
- [ ] If the nurse has never visited this client, the section covers the case's **last 3 completed visits** and everything recorded since then (pilot default, configuration). The card says which rule applied.
- [ ] Every entry shows **what was recorded, by whom (member label until ADM1 names exist), when, and in which visit**. Nothing is summarised, rephrased, ranked or interpreted: no AI and no clinical logic. AI summaries are Gate 4 and need human review.
- [ ] Empty state: "nothing new since your last visit on <date>".
- [ ] **No extra tap.** When a nurse starts a visit, NAVORA records which entries were shown to her before the start. This is an audit fact. She does not have to acknowledge anything.
- [ ] **Access is not widened:** the section uses exactly the F0/F1–F4 team-scoped rules. A covering nurse (COVER1) sees it for her one visit only, once D-3 allows cross-team context. Until then, a covering nurse sees nothing beyond what COVER1 grants.
- [ ] It works at phone width and loads with the visit card. The section is collapsible, so a nurse who has seen it can get on with the visit.
- [ ] **Measured in AN1:** the share of visits where the previous visit was done by another nurse and the section was shown before the start.
- [ ] Negative tests:
    - another team's nurse sees no entries;
    - another organisation sees nothing;
    - a quality event the team cannot see under QG1 does not appear;
    - entries from a different case of the same client do not appear (no cross-case linking here; see RET1).

## Out of scope
- AI summaries (Gate 4).
- Push notifications.
- Read receipts or acknowledgement taps.
- Sharing with relatives or the GP.
- Ranking entries by clinical importance: that would be a clinical rule, and it needs `clinical`.

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | Coordination layer: the daily team handover meeting and the shift lead or "Tagesverantwortliche" who carries the team's knowledge |
| Manual activity removed | Handover meetings, phone calls between colleagues before a visit, re-reading the whole record |
| Role less necessary | Shift lead and coordinator as knowledge carriers; the coach no longer brokers information between team members |
| Continuity of care | Every nurse arrives informed, so a deputy or cover visit is as safe as a primary-nurse visit. It is the precondition for COVER1 at network scale |
| Direct care time | Meeting and phone time goes back to visits. *Hypothesis:* the pilot asks teams to record their handover-meeting time before and after; there is no system data for it today |
| Caregiver income potential | More billable minutes per paid hour. When D-14 pays for direct care, this time becomes income |
| Long-term operating model | Knowledge belongs to the client's record, not to a person or a meeting. This is what lets teams of any size, cross-team cover (COVER1) and later integrated networks work |

## Constraints and references
`DOMAIN_RULES.md` data minimisation and team-scoped access (F0, ADR-031). F1–F4 handover (ADR-023 to ADR-025), J3 change log (ADR-030), J6 (ADR-037), QG1 visibility (ADR-036), C1. D-3 for cross-team context.

## Open questions for engineering
- Is one read-only query over the existing append-only tables enough, or is a view per case cheaper? No new copy of clinical data.
- How do you record "shown before the start" without extra writes on every card open? Recording it with the start event is enough.
