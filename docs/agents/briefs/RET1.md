---
id: RET1
title: Returning client returns to her team
author: po
status: approved
updated: 2026-10-22
---

# RET1 — Returning client returns to her team

## Problem
**Challenge finding (PO, 2026-10-22).** Home-care clients go back and forth to hospital. In the traditional model, every discharge is a new intake. A coordinator takes the referral again, a dispatcher looks for capacity, and the client may get a different team and new nurses. The first visits after a hospital stay carry the highest risk, and they are exactly when the client meets strangers.

In NAVORA today:
- J1 creates one case per referral, and J2 offers it to all eligible teams.
- C1 lets a team **pause** a case for a hospital stay. But the discharge referral that ends the pause has no path back to the paused case: it would open a new case and a new matching.
- After a **closed** case, a returning client is matched as if NAVORA had never seen them.

Matching from scratch, when the client's team is known, is manual matching work that destroys continuity.

## Users and journey step
Intake roles (J1), the client's previous team, all other eligible teams (J2). Journey: **Referral → Case → Matching** → Team decision.

## Outcome
A returning client goes back to the team, and if possible the primary nurse, who knew them. A paused case simply resumes. Other teams are asked only if the known team cannot take the client.

## Acceptance criteria
- [ ] **Explicit link, no automatic identity matching.** When recording a referral (J1), the intake role can link it to an existing case of the same organisation that is **paused**, or **closed within the last 180 days** (pilot default, configuration). The link needs a reason and is audited. NAVORA does not search or match client identities automatically: that is a data-protection question (D-9), and REF2 may revisit it.
- [ ] **Linked to a paused case:**
    - the referral **resumes that case** with its team and primary nurse;
    - no new case and no new matching are created;
    - the J1 readiness check runs again on changed funding and order facts;
    - the team gets a non-blocking task: "situation changed after <pause reason>: decide whether to review the care plan".
- [ ] **Linked to a closed case:**
    - a new case is created, with a reference to the previous one (one case per referral stays);
    - the J2 offer goes **first to the previous team only**, labelled "returning client", for a first-refusal window. Pilot defaults: 1 working hour for hospital discharge, 2 working hours otherwise (Q10 working time);
    - the window counts **inside** the existing J2 response deadline, which is not extended;
    - if the team declines (J2 reason codes) or the window passes, all eligible teams get the offer as usual.
- [ ] When the previous team accepts, the previous primary nurse is **proposed** as primary nurse (J6). The team confirms or changes this.
- [ ] If the previous team is inactive, or lacks a qualification the case requires (J2 and J3 rules), the window is skipped and normal J2 matching starts at once.
- [ ] Other teams' offers carry **no identity and no mention of the previous team**, the same as J2.
- [ ] **Measured in AN1:** the share of returning clients served by their previous team, and the time from referral to first visit for returning clients compared with new ones.
- [ ] Negative tests:
    - only intake roles can link;
    - no link across organisations;
    - no link to a case closed longer ago than the configured period;
    - a team never sees another team's earlier case.

## Out of scope
- Automatic recognition of returning clients.
- Hospital-admission or discharge feeds (REF2 and later).
- Linking across organisations.
- Merging case histories.

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | Matching and dispatch for clients NAVORA already knows. The intake coordinator's "find a provider again" work |
| Manual activity removed | Re-matching, re-intake of a paused client, phoning the old team to ask whether they can take the client back |
| Role less necessary | Dispatcher and intake coordinator for re-admissions |
| Continuity of care | Same team, and ideally the same primary nurse, across the hospital stay: the care relationship survives the transition |
| Direct care time | The team does not re-learn a known client. *Hypothesis:* fewer first-visit minutes for returning clients; measured in AN1 |
| Caregiver income potential | The team keeps its client base, and so its stable billable volume across hospital stays |
| Long-term operating model | Continuity across transitions of care (horizon 2), owned by the team rather than the institution. It is the first building block of the integrated-network horizon |

## Constraints and references
J1 (ADR-026, ADR-029), J2 (ADR-027, ADR-033), J6 (ADR-037), C1 pause and close, Q10 working time. Data minimisation (D-9): the link is a human decision at intake, which already sees identity. Whether a care-plan review after a hospital stay is mandatory is a clinical rule: if `clinical` sets one (D-15), it replaces the non-blocking task.

## Open questions for engineering
- Can the first-refusal window be a J2 offer with a restricted eligible set, rather than a new mechanism?
