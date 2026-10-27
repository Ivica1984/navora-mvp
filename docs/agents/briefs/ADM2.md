---
id: ADM2
title: The team admits its colleagues; the employer records the contract once, and its end date ends access on time
author: po
status: approved
updated: 2026-10-27
---

# ADM2 — The team admits its colleagues; the employer records the contract once

## Problem
IMPLEMENTED (ADM1, 0035:140-333): only an organisation administrator invites a person and adds her to a team (`invite_member`, `add_team_member`, `private.is_org_admin`). In a self-organised team that is a hierarchy step per hire: the team that will work beside the new colleague does not decide, and waits for an administrator to act (challenge row "Central administration admits members to teams", verdict *doubtful*). **D-20 was decided by po on 2026-10-24 (option D sharpened, `lca` 18:47 and 00:50: compliant under every plausible interpretation on the federal and ZH sources read):** the team decides membership, the employer records the contract fact once, the qualification gate does not change.

IMPLEMENTED (LEAVE1-1, 0074): a leaver's access ends only when an administrator runs `end_member_access`. The employer knows the contract end date in advance, yet until someone remembers, a former employee keeps reading client data (challenge row "An administrator must remember to end a leaver's access", proposal 2026-10-26; `lca` residual in D-10 and D-30: "access ends only when an administrator records it").

The D-20 row said the brief would follow once D-29 and D-26 are answered. **PO 2026-10-27 03:10 CET: changed.** Neither blocks a build on synthetic data: this item does not touch how a qualification is verified (the existing administrator path stays the only one that sets it, D-29 replaces that path later) and needs no invitation e-mail (accounts stay manual, D-26 default A, accepted for a pilot of a few teams on 2026-10-22). Both remain gates before a real organisation switches it on (G-23).

## Users and journey step
Team members (nurses, care assistants), the organisation administrator acting for the employer, the candidate. Step: the team itself (`ARCHITECTURE.md`: the self-organised team as the unit that decides on cases, J2, and on its plan, PLAN2). Indirectly every step that reads team membership: planning, cover, signals, LEAVE1.

## Outcome
A team proposes and admits a colleague by its own consent decision; the employer's only step is "Vertrag erfasst" (start, optional end). A recorded contract end releases her later visits to the team at once, shows her open work to the team's registered nurses two weeks before, and ends her access the day after, without anyone having to remember.

## Acceptance criteria

**Part (a): admission by the team** (D-20 points 1, 2, 4, 5, 6; `lca` 00:50 protective shape)

- [ ] **ADM2-1 Switch.** A per-organisation setting, default off, set only by an organisation administrator (audited). Off: the ADM2 commands are refused with one stated code; ADM1 `invite_member` and `add_team_member` work unchanged in both states. pgTAP for both states.
- [ ] **ADM2-2 Proposal.** An active member of a team (access not ended, LEAVE1) proposes a candidate for that team with exactly: display name, the qualification she claims (`registered_nurse` or `care_assistant`) and availability as one fixed choice (Pensum band, for example 20-40 / 40-60 / 60-80 / 80-100 %). No free text, no e-mail, phone, address, date of birth, references, pay or health field exists in the candidate record (schema test). Refused: a member of another team, a coach, operations, an administrator who is not a member of that team, a person whose access has ended.
- [ ] **ADM2-3 Candidate record is deletable; the decision record carries no person.** (`lca` 00:50, binding.) The candidate's data live in a record that can be deleted. The decision record is append-only and holds only: team, a candidate reference that survives deletion (no name), each member's consent or objection with a **reason code** (fixed list, for example `team_full`, `availability_mismatch`, `qualification_mix`, `wants_to_meet_first`; no free text), who and when, and the outcome. `team_decisions` (0011, 0017) is **not** used. pgTAP: no text column on the decision record; deleting the candidate leaves the decision record readable and nameless.
- [ ] **ADM2-4 Reads.** Candidate and decision records are readable only by the active members of the proposing team and the organisation's administrators. pgTAP refusals for: a nurse of another team in the same organisation, a coach, operations, an administrator of another organisation, a member whose access has ended (LEAVE1-3 semantics). No AN1, AN2, OPS1, audit-purpose reader (AUD1) or export reads candidate data; counts only, if any.
- [ ] **ADM2-5 Consent decision.** A proposal is **admitted by the team** when at least two members other than the proposer have consented (all other active members if there are fewer than two) and no objection stands; an objection blocks until its author withdraws it; a proposal with no outcome after 14 days lapses. The proposer cannot consent to her own proposal. Thresholds are one constant each, named in the ADR (organisational product rule, not clinical; measured in the pilot, below). pgTAP: two consents → admitted; one objection → not admitted; withdrawal of the objection → admitted on the next consent; lapse after 14 days (test clock as in DST1); a member who joins after the proposal may take part.
- [ ] **ADM2-6 "Vertrag erfasst" is the only employer step.** Membership exists only after an organisation administrator records the contract fact for an admitted proposal: the user account (created by hand as today, D-26 default), contract start date, optional end date; who and when, audited. The command takes **no** judgement field and cannot change the team's outcome (it can only record or not record). The membership is created with organisation role `nurse` and is active from the start date. The **qualification is set by the existing administrator path only** (`set_member_qualification`, 0018, or the ADM1 equivalent named in the ADR), exactly as today; no ADM2 command writes a qualification, and the candidate's claimed qualification is shown beside it as "angegeben". Until a qualification is set, planning, take and cover refuse her as responsible, as for any member without a qualification today (pgTAP on one planning and one take path).
- [ ] **ADM2-7 No lead role, no role change.** No ADM2 command can create or change an organisation role (`admin`, `coach`, `operations`), a team other than the proposing one, or a primary-nurse or deputy assignment (J6). pgTAP: each refused or impossible by signature.
- [ ] **ADM2-8 Candidate data deleted.** On decline, lapse or "Vertrag erfasst", the candidate record is deleted after a period that is one constant, default 0 days on synthetic data (deleted in the same transaction); the real period is D-4's (`lca`), before release (G-23). pgTAP for decline, lapse and contract recorded.
- [ ] **ADM2-9 Removal for cause stays with the administrator.** `remove_team_member` (ADM1) and `end_member_access` (LEAVE1) are unchanged and remain administrator commands; every admission is listed for administrators with team, outcome and date (no candidate data after deletion). No team command removes a member.
- [ ] **ADM2-10 `/team` at phone width.** "Kollegin vorschlagen", the open proposals with consent count and "Zustimmen" / "Einwand" (code list) / "Einwand zurückziehen", and on `/admin` "Vertrag erfassen" for admitted proposals. e2e at 390 px: propose, two consents, contract recorded, the new member appears in the team list; a nurse of another team does not see the proposal.

**Part (b): the contract end date ends access on time** (challenge row 2026-10-26; LEAVE1 reused, no new access concept)

- [ ] **ADM2-11 End date recorded.** The administrator records or changes a contract end date in "Vertrag erfasst" or later (same role, audited, for ADM1-admitted members too). From that moment: planning, take and cover refuse her as responsible for any visit starting after the end date (Zurich calendar day), and her planned visits after the end date are **released to the team in the same command** by the LEAVE1-13 release rule (no second rule). pgTAP: release on recording; refusal after the date; visits on or before the date unchanged.
- [ ] **ADM2-12 Open work two weeks before.** From 14 days before the end date, the LEAVE1-12 list of her open reports (by kind, visit date and team only) is shown to the team's registered nurses and to administrators, as built for the access-end step. Unit or pgTAP for day 15 (not shown) and day 14 (shown).
- [ ] **ADM2-13 Access ends without a command.** At the start of the Zurich day after the end date her access is ended exactly as `end_member_access` ends it (LEAVE1-1 to -3 and -14: no reads, no commands, no push, signal takes lapse), with actor `system` and reason `contract_end` in the access record; whether this is evaluated at read time or by a job is Engineering's choice, stated in the ADR (a hosted job does not exist yet, D-2). `restore_member_access` works as today. A changed end date before it passes moves the access end with it; visits already released stay released. pgTAP across the boundary with the test clock, including the night the clocks change (DST1).
- [ ] **Negative.** No qualification, signal, threshold, quality rule, billing fact, read scope or role is widened. No person gains a read she did not have. ADM1 and LEAVE1 behaviour with the switch off is unchanged (their pgTAP suites pass unmodified).

## Rules and their input class
- ADM2-5 consent thresholds (two consents, no standing objection, 14-day lapse): **organisational rule** of team self-governance, product authority (D-20 decided by po). Not a clinical rule, not *clinical content*; ranks, routes or escalates no client.
- ADM2-11 to -13 contract end: input class *visit/schedule fact* (a date recorded by the employer); it only narrows access and reuses the LEAVE1 release rule. The 14-day lead time is a product choice (measured below).
- No rule on the team's qualification mix is added: that is the Clinical Owner's (D-10, D-25; `cra` 02:26 on D-20: "D sharpened changes no qualification gate").

## Out of scope
- How a qualification is verified (D-29, `owner`); the administrator path stays the only one until then.
- Invitation e-mails and account creation by the app (D-26); accounts stay manual.
- The candidate entering her own application (needs D-26 self-service); a team member enters the three fields from the application the candidate gave the team.
- Employment terms, pay, working time (D-14, D-23); NAVORA records only that a contract exists and its dates.
- Removal of a member by the team (option C as written; not pursued, needs owner and a legal adviser).

## Constraints and references
D-20 (po-decided, package `decisions/D-20.md`, points 1-6 and the `lca` 00:50 condition), D-29, D-26, D-4, D-11, D-12; ADM1 (0035), J2 (0011, 0017, not reused), LEAVE1 (0074-0078, LEAVE1-1 to -3, -12, -13, -14), DST1 (test clock), RLS2/RLS3 read rules, `cra` 02:26 (D-20 point confirmed). No personal or health data in fixtures beyond synthetic names.

**Release gate G-23 (before a real organisation switches ADM2 on):** D-29 answered (qualification verification); D-26 production path or manual accounts confirmed; D-11 names the canton and `lca` checks its admission and staffing rules (only federal and ZH read); D-4 names the candidate-data period; `lca` look at part (b) (requested 2026-10-27, not awaited for the build).

## Open questions for engineering
1. Read-time evaluation of the contract end in `private.access_ended` (one more index probe) versus a job: which keeps LEAVE1-3's single predicate? State the cost.
2. Whether the consent count needs the J2 idempotency pattern per member (one decision row per member and proposal).
3. Whether `set_member_qualification` can be called for a membership created by ADM2 without change, or needs one guard.

## Pilot measures (AN2 candidates, counts only, never per person)
- Time from proposal to "Vertrag erfasst", and from admission to "Vertrag erfasst" (the employer's remaining step; hypothesis: under 3 working days in the median).
- Share of proposals with an objection, by reason code; share lapsed (if more than 1 in 4 lapse, the 14-day window or the two-consent threshold is wrong).
- Days between a recorded contract end and the access end (target 0) and open reports at access end per leaver (target 0, with LEAVE1-12).
- Balancing measure (P-5): qualification mix per team before and after admissions, shown beside the admission counts; read by the Clinical Owner once named (G-1), no rule set here.

## PO notes
**2026-10-27 03:10 CET, approved (po).** Value order 4 (team autonomy) and 5 (less administration): the team, not an administrator, chooses whom it works with; the administrator's part shrinks to recording one fact. Part (b) is privacy by data instead of by memory (`lca` residual, D-10, D-30) and gives the team two weeks to hand over a leaver's open work. Safe on synthetic data now; not released to a real organisation before G-23.
