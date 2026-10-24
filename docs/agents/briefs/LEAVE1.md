---
id: LEAVE1
title: Access ends when employment ends
author: po
status: approved
updated: 2026-10-25
---

# LEAVE1 — Access ends when employment ends

**Approved by the PO 2026-10-25 01:16** (product authority; protective, additive, reversible per person). Source: `lca` re-check 2026-10-25 00:50 on D-10 and D-30 (note to po 1), F6R deviation (3). No clinical rule: what happens to the leaver's open reports stays D-30 (Clinical Owner); this brief only stops her access and keeps her open work visible.

## Problem
- Since 0037 (CGR-18), and more so since F6R (0065 §8), `remove_team_member` refuses while a member has an unsigned report, a correction draft or a **returned** report she has not signed again (`has_unsigned_reports`). That refusal is clinically right (H-12: removal would strand an unsigned report).
- But no other command ends a person's access: `private.is_team_member` reads only `team_memberships` (0003:133-141), 0035 deactivates teams, not people, and `set_member_role` keeps every role (`lca` 00:50, read, not tested). So a nurse whose employment has ended keeps the team's read access to client health data until she signs, and a colleague's return (F6R) can create that state after her notice was given.
- `lca`: with real data, an access that cannot be ended is **not compliant under every plausible interpretation** (DSG Art. 5 lit. h, 6 Abs. 2, 8 Abs. 1-2 as read; guidance expects a process to withdraw access). Today the administrator has only one lever, the team removal, and the system refuses it for a reason only the leaver can clear.

## Users and journey step
Organisation administrator (ADM1), the team's registered nurses (countersignature queue, HAND1), the leaver herself. Cross-cutting: every journey step that reads client data (Case, Planning, Visit, Documentation, Quality).

## Outcome
When a person's employment ends, an administrator ends her access in one audited step, even while her reports are open. From then on she reads nothing and can do nothing; the team sees which of her reports are still open and handles them on D-30's route.

## Acceptance criteria
- [ ] **LEAVE1-1 Command.** `end_member_access(user, reason_code, idempotency_key)`, organisation administrator only; reason codes `employment_ended`, `access_withdrawn`; no free text. Audited (actor, person, code, time). Refused for: any other role, a person of another organisation, the last administrator (ADM1 rule), the caller herself. pgTAP for each refusal.
- [ ] **LEAVE1-2 Not blocked by what only she can clear.** The command succeeds while she has an unsigned report, a correction draft or a returned report not signed again (the `has_unsigned_reports` cases of 0037 and 0065 §8). It is refused, with the existing reason codes, while she is primary or deputy nurse of a case, is responsible for a planned visit from now on, or has a visit in progress: someone else can clear those (re-assign; the existing close path for a stuck visit). pgTAP: succeeds with each open-report state; refused for each clearable state, and succeeds once it is cleared.
- [ ] **LEAVE1-3 Reads nothing.** After the command, as that user: every table and read model that the `authenticated` role can read returns zero rows except her own access-ended notice; every command is refused with `access_ended`; `private.is_team_member`, the organisation-member helper and `private.cover_team_for` return false for her; she is in no SIG1/SIG2 receiver set and no push is queued for her. pgTAP **catalogue check**: loop over every table and view with a SELECT grant to `authenticated` and assert zero rows for her, so a new table cannot slip through (pattern of RLS2's read-path inventory).
- [ ] **LEAVE1-4 Her history stays.** Her `team_memberships` rows, reports, signatures, audit events and AN1/AN2 contributions are kept unchanged; reports still name her as performer. Nothing is deleted, and the command never deletes the `auth.users` row (whose `on delete cascade` would drop memberships). pgTAP: row counts before and after are equal.
- [ ] **LEAVE1-5 Her open work is visible to the team.** Her unsigned, draft and returned reports appear in the team RNs' countersignature queue and in HAND1 "since you were last here" with the fact "Zugang beendet" (no reason code shown to the team); `report_not_final` keeps raising; they stay not billable. **No correction or signing rule changes**: CR-048 (the interim refusal) and D-30 apply as today. pgTAP: queue row present with the marker; no new command lets anyone sign or change her report.
- [ ] **LEAVE1-6 The leaver's screen.** Signed in after the command, she sees only "Ihr Zugang ist beendet. Bitte wenden Sie sich an Ihre Organisation." on every route; no client data, names or counts. e2e at 390 px. (Sign-in itself may still succeed: no service-role key on the app host, D-26.)
- [ ] **LEAVE1-7 Reversible.** `restore_member_access(user, reason_code, idempotency_key)`, administrator only, audited; restores exactly the access she had (memberships were never removed). pgTAP: reads return again after restore; refused for other roles.
- [ ] **LEAVE1-8 Who sees the record.** The access-ended fact (person, code, time, actor) is readable by organisation administrators; the team sees only "Zugang beendet" with the date. No AN1, AN2, billing, export or push function reads the reason code (catalogue check, as F6R-7).
- [ ] **LEAVE1-9 Real-data gate.** The go-live list (the one that holds D-29's and RLS2's gates) gains: "no real client before LEAVE1 is accepted". Documentation only.
- [ ] **LEAVE1-10 No regression.** pgTAP, unit and e2e green; `remove_team_member` refusals (0037, 0065 §8) unchanged; ADM1 last-administrator rule unchanged; RLS2 narrowing unchanged.

## Rules and their input class
- LEAVE1-1/-2/-3 access end: an organisational fact (an employment status recorded by the administrator); it gates access only and ranks, routes or escalates nothing clinical. Not *clinical content*, not "for the adviser".
- LEAVE1-5 adds a display marker only; no new rule on who may correct or sign (D-30, CR-048 unchanged).

## Out of scope
- Who may correct or complete a leaver's report (D-30, Clinical Owner), and `lca` question 4 (may a former employee keep access to sign?). The default here is **no access** after employment ends.
- Deleting an account, an offboarding checklist, the employment record itself (D-20 employer fact, later ADM2).
- The member's own "Vor dem Teamwechsel offen" list (challenge row, hypothesis; a brief only if refusals recur).

## Constraints and references
- `lca` 2026-10-25 00:50 in [D-10](../decisions/D-10.md) and [D-30](../decisions/D-30.md); `clinical/HAZARD_LOG.md` H-12, `SAFETY_RISK_REGISTER.md` PS-15, CR-048, CGR-18.
- ADM1 (0035) command pattern (`private.begin_command`, idempotency, audit); RLS2 read-path inventory; F6R-7 catalogue check.
- D-26: no service-role key on the app host, so the access end is enforced in the database (RLS and helpers), not by an Auth admin call from the app.

## Open questions for engineering
1. Where the access-ended fact lives (a column on the organisation membership, or its own append-only table) and how every helper reads it at no measurable cost.
2. Whether any `security definer` function bypasses the helpers and needs its own check (catalogue check in LEAVE1-3 should find it).
3. Whether her stored push subscriptions (SIG2) are kept inactive or deleted at access end; either is acceptable if LEAVE1-3 holds; after a restore (LEAVE1-7) the app may ask her to subscribe again.
