---
id: RET1
title: Returning client returns to her team
author: po
status: approved
updated: 2026-10-22
---

# RET1 — Returning client returns to her team

## PO review — 2026-10-22 18:20: accepted, with two conditions

Reviewed on merged evidence: #129 (merge 73eedba, whose own run was cancelled by the next push; CI green on the PR head bbcaa98 and on `recovery/main` 19381f2, which contains it: app, db, e2e), ADR-048, migration 0034, pgTAP 034 (32 assertions), unit `returning-rules.test.ts`. **The PO did not run the tests**; results are taken from CI.

| Criterion | Result | Evidence |
|---|---|---|
| Explicit link by an intake role, same organisation, paused or closed ≤ 180 days (configuration), reason, audited; no automatic identity matching | met | `link_returning_referral`, `linkable_cases` (intake role only), `return_settings` (180), `referral_links` append-only with audit trigger; no search by identity anywhere; pgTAP 034 blank reason refused, audit event present |
| Paused: resumes with team and primary nurse; no new case, no new matching | met | resume branch; pgTAP 034 lifecycle `active`, same `assigned_team_id`, case count unchanged |
| Paused: readiness re-run on changed funding and order facts | met | `apply_case_facts`, change-log diff with the link reason, `case_readiness` returned to intake; pgTAP 034 medical-order change logged |
| Paused: non-blocking task "situation changed after <pause reason>" | met | task `review_after_pause` with the pause reason; `team_cases().review_after_pause_reason`; `complete_case_task` by the team; pgTAP 034 |
| Closed: new case with reference; J2 first to the previous team, labelled, 1 h discharge / 2 h otherwise, inside the deadline | met | `previous_case_id`; `set_first_refusal` (working hours, capped at `response_due_at`); `team_offers.returning_client`; pgTAP 034 preferred team and window, only the previous team sees the offer during the window |
| Decline or window end → all eligible teams | met | `first_refusal_open` ends on any decision of the previous team or at `first_refusal_until`; pgTAP 034 window passed → other team gets the usual offer |
| Previous primary nurse proposed on acceptance; the team confirms | met | trigger `propose_previous_primary` (only if still a member); proposal cleared when the team sets a primary nurse; pgTAP 034 `proposed_primary_nurse_id` |
| Window skipped if the previous team is inactive or lacks a required qualification | met for inactive; **qualification path untested** | `set_first_refusal` checks status, region and `team_has_registered_nurse`; pgTAP 034 covers the inactive team only |
| Other teams see no identity and no previous team | met | `returning_client` false and no window for other teams; pgTAP 034 |
| AN1: share served by the previous team; time to first visit for returning clients vs new | met | `returning_previous_team_share`, `returning_referral_to_first_visit_days` (organisation level, coordination roles), definition names the comparison figure; pgTAP 034 value 100, base 2 |
| Negative: only intake roles link; no cross-organisation link; not past the period; a team never sees another team's earlier case | met | pgTAP 034: non-intake role rejected and sees no linkable cases; other organisation and too-old case `not_linkable`; "a team never sees another team's earlier case" |

**Why accepted.** The returning client goes back to the team that knows her, and a paused case simply resumes: no re-intake, no re-matching, no phone call to the old team. The first-refusal window is a restricted J2 offer, not a second mechanism, and it never lengthens the time a hospital waits for an answer. The link is a human decision at intake, so no identity matching enters through the back door (D-9).

**Conditions (testable, in engineering's next PR that touches migration logic for RET1 or C1 resume, before any real pilot data):**
- [ ] **Resume at the return date, not at the link.** When a referral linked to a paused case carries a requested start, planned visits before that date stay suspended and visits from that date are released; without a requested start the current behaviour (release from today) stays. pgTAP: a link today with a requested start in 3 days leaves the visits of the next 2 days suspended. *Why:* a discharge referral often arrives days before the discharge; releasing the visits at once sends nurses to an empty home, which costs direct care time and raises false no-show P1 exceptions in OPS1.
- [ ] pgTAP: a previous team without a registered nurse, for a case that requires one, gets no window and normal J2 matching starts at once.

**Deviations, decided:**
- The window is also skipped when the previous team is in another region: **accepted**. Region is part of J2 eligibility; a client who moved region is served by a local team, and the change of team is then a real one.
- A resumed case keeps its existing matching history: **accepted**. Nothing is re-matched, so there is nothing to replace.
- No e2e for linking yet: **accepted for now**. The brief asked for no e2e; the database rules carry the safety and are tested. An e2e for the intake link is expected with REF2.

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
