---
id: HAND1
title: Handover without the team meeting
author: po
status: approved
updated: 2026-10-22
---

# HAND1 — Handover without the team meeting: "since you were last here"

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
