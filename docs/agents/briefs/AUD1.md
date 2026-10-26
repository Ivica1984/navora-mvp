---
id: AUD1
title: Administrators read the audit log only for a stated purpose, without the team's free text
author: po
status: approved
updated: 2026-10-26
---

# AUD1 — Administrators read the audit log only for a stated purpose, without the team's free text

## Problem
`audit_events` is readable row by row through the table API by every administrator of the organisation, for every team (policy `org_admins_read_audit`, 0004:44, marked "Placeholder (Q4)"). Its `changed` column carries the audited values, including free text such as `quality_holds.reason`, which can describe a client's health. This is finding **F-3** in `docs/engineering/READ_PATHS.md`, the last open line of D-3 real-data gate (iv) besides F-1 (DOOR1-11). How do we know:
- `lca` 2026-10-25 03:43, 07:50, 15:41 (advisory): with real data this is the same free-text gap gate (iv) forbids; "waits for D-4" is fine on synthetic data only; item 6 (b) makes it a condition before the first real client, independent of D-4's timing; **F-3 has no brief yet** (15:41).
- D-4 provisional rule (po 2026-10-24 10:11, in force): admins read the log for compliance, billing and safety review only, through a reader that records the purpose (gate r3); no per-member performance reading.
- No screen reads `audit_events` (`grep` in `src/`: only the generated types); security-definer readers (HAND1, RET1, the order history after CGR-33) read it for derived facts and are not affected.

## Users and journey step
Administrators (compliance, billing, safety review); every client and member whose actions are audited. Steps: Quality, Billing (`ARCHITECTURE.md` data flow). Completes D-3 gate (iv) line F-3 and D-4 gate (r3).

## Outcome
No administrator can list the audit log of every team through the table API. An administrator reads the audit rows of one record for a named purpose, every such read is itself recorded, and free text written by a team stays in that team.

## Acceptance criteria
- [ ] **AUD1-1 Inventory of audited free text.** `READ_PATHS.md` lists every audited column whose value in `audit_events.changed` is free text (at least `quality_holds.reason`; Engineering finds the rest from the audit triggers) and every security-definer function that reads `audit_events`, with its task. pgTAP fixes the free-text list: a new audited free-text column fails CI until it is listed.
- [ ] **AUD1-2 No standing table read.** `authenticated` (any role, including administrators) reads 0 rows of `audit_events` through the table API; `anon` is refused. The existing definer readers (HAND1, RET1, the order history, any other found in AUD1-1) return the same rows and values on the seed as before (their pgTAP unchanged and green). pgTAP 005 tests 71, 78-98 and 121, which read the log as a role, are replaced by the narrower assertion or read through the purpose reader, and named in the status row; none is removed without a replacement.
- [ ] **AUD1-3 Purpose reader.** One function returns the audit rows of **one** record (entity type and id) to an administrator of the record's organisation, only with a purpose code from the fixed list of the D-4 provisional rule: `compliance`, `billing`, `safety_review`. Without a valid code, for another organisation, for a non-administrator, or for a list of records, it refuses or returns 0 rows. It never groups, counts or ranks rows per member (D-4: no per-member performance reading; D-23 term b).
- [ ] **AUD1-4 Free text stays in the team.** For a free-text value from AUD1-1, the purpose reader returns the text only when the administrator is also an active member of the record's team; otherwise the key is present with the value withheld and a flag `text_withheld = true`. The fact that the value changed, when, and the command stay visible. pgTAP: an administrator outside the team reads a quality hold's audit rows with `reason` withheld and the change time present; an administrator who is a member of the team reads the text.
- [ ] **AUD1-5 Each read is recorded.** Every call of the purpose reader appends one row (caller, time, entity type and id, purpose code, number of rows returned) to an append-only table that no role can update or delete; administrators read their organisation's rows of it through the same pattern (no table-wide read by other roles). No client field, no free text in it. **Added by the PO 2026-10-25 17:11 CET (`lca` 16:41 note 2, narrows only):** no reader groups, counts or ranks the purpose-read rows per administrator; they are evidence of purpose, never a rating of the person who read (counts per organisation and purpose only). pgTAP: the reader of the purpose-read rows has no per-person aggregate (argument and column catalogue check). pgTAP: a call adds one row; update and delete are refused, as for `audit_events` (005:101).
- [ ] **AUD1-6 Inventory and gate.** `READ_PATHS.md`: F-3 marked closed with its pgTAP; D-4 gate (r3) marked met in the status row; r1 (client extract) and r2 (retention class per audited column) stay open.
- [ ] **AUD1-7 No regression.** Every existing pgTAP, unit and e2e test green; `/admin`, `/team`, `/field`, `/operations` show what they show today.

## Rules and their input class
One access rule (who reads which audit row, and which part): *visit/schedule fact* class (organisation, team membership, role, purpose code). The three purpose codes are the D-4 provisional rule, not new. No signal, threshold, priority or clinical content. Not "for the adviser".

## Out of scope
- Retention periods, deletion or anonymisation (D-4 final periods: `owner` with a legal adviser after D-11, D-12).
- Gate r1 (client extract with staff identities masked) and r2 (retention class per audited column): later, after D-11 and D-12.
- The general read log of client data (D-3 gate i) and the DSFA (gate ii). AUD1-5 records reads of the audit log only. It is **not** gate (i) evidence and is never counted as the DSV Art. 4 log (`lca` 16:41 note 1: same database, readable by administrators). The client's own extract (D-4 r1, which must return her own free text, `lca` 16:41 note 3) is out of scope too.
- Who outside the team may read a quality hold's reason for a safety review (the Clinical Owner, G-1; D-16). Until named, nobody outside the team reads it.
- Any `/admin` audit screen.

## Constraints and references
D-3 item 6 (b) and item 7 (gate iv checklist), D-4 provisional rule (po 2026-10-24 10:11; gates r1-r3), Q13 (F-3 route), `READ_PATHS.md` F-3, RLS2/RLS3 patterns (0066, 0070). `lca` 15:41 (advisory, not legal advice): gate (iv) not met while F-1 and F-3 are open. **Clinical gate:** no clinical rule; `cra` is informed (quality hold reasons are clinical free text) and may name a task-bound read for the Clinical Owner, which then goes through this reader with its own purpose, never the table. **Legal:** `lca` re-checks D-3 gate (iv) when AUD1 is delivered. Real data stays blocked by D-1, D-9, D-29 and the other gates regardless.

## Open questions for engineering
- Does any definer function read `audit_events` on behalf of a coordination role and return free text from `changed`? Name it in AUD1-1; if it does, mask it the same way (AUD1-4) in this PR.
- Is `org_admins_read_audit` used by any test fixture or seed script outside pgTAP?
- Estimate: one additive migration (drop the policy, one reader, one append-only read table), about 25-35 pgTAP assertions, an inventory update.

## PO review 2026-10-26 04:10 CET: accepted

**Delivered in:** PR #413 (migration 0077, ADR-090, pgTAP 077 with 44 assertions, `docs/engineering/READ_PATHS.md`), merged 2026-10-26 03:11 CET as 7f23a3b. **CI:** `app`, `db`, `e2e` green on the PR head 8eeb18e, on the merge commit 7f23a3b and on `recovery/main` 88b9abc (read from the check runs at 04:10). **The PO did not run the tests;** the evidence is the merged code, the pgTAP text and the CI conclusions.

| Criterion | Result | Evidence |
|---|---|---|
| AUD1-1 Inventory of audited free text | met | 0077 §2: `private.audit_value_classes`, non-text trigger columns classed `code` from the catalogue, every text column and direct-writer key by hand; ten `free_text` keys (`quality_holds.reason`, `lift_reason`; `teams.coach_name`, `name`, `region`; `cases.region`; `matching_requests.region`; `partner_requests.region`; `member_profiles.display_name`; `member_invitations.email`). The PO checked every `write_audit_event(...)` trigger in 0004-0075: no text column is missing; `visit_report_returns` audits no reason (0065:119), the return reason stays out of the log. 077: "the audited free-text keys are exactly the listed ten", "the readers of audit_events are exactly the listed SECURITY DEFINER functions", catalogue completeness and "no freely writable text column classed code". `READ_PATHS.md` §"Audit log: free text and readers" lists keys and readers |
| AUD1-2 No standing table read | met | 0077 §1: `org_admins_read_audit` dropped, RLS on, no policy; `anon` revoked. 077: admin of org A and org B, coach, nurse, Operations read 0 rows through the table; anon refused; no permissive policy. Definer readers unchanged (their pgTAP green in CI with no assertion changed). pgTAP 005: test 31 (line 121) replaced by two assertions; 71 and 78-98 unchanged because they read as the table owner, named in the status row |
| AUD1-3 Purpose reader | met | `read_audit_record(entity_type, entity_id, purpose)`: one record; purpose outside `compliance`/`billing`/`safety_review` or null → 22023; malformed or missing record → 22023; another organisation, coach, nurse → 0 rows; access-ended caller refused. 077 argument and output catalogue: no aggregate column; no grouping or ranking |
| AUD1-4 Free text stays in the team | met | `private.audit_record_team` (holds, teams, cases, matching requests); value shown only when `is_team_member` (active, LEAVE1-3). 077: outside the team the hold reason is null with key, `text_withheld`, time, command and actor present and the text nowhere in the row; a team member who is administrator reads it; a key missing from the catalogue is withheld even in the team (fail closed) |
| AUD1-5 Each read is recorded | met | `audit_read_log` append-only by trigger (update, delete, truncate refused, also for the owner), RLS on, no app grant; no client field, no free text. `org_audit_read_log(org)`: rows only, 077 asserts no count, rank or grouping in arguments, output and body. 077: one row per completed call, purpose recorded, a 0-row call recorded with organisation null |
| AUD1-6 Inventory and gate | met, one stale line | `READ_PATHS.md` F-3 row and the status row: F-3 closed, D-4 r3 met, r1, r2 open. The F-3 row still reads "CLOSED in PR … closed on merge" (written before the merge): correction asked as **AUD1-M2** (docs only, no reason to hold acceptance) |
| AUD1-7 No regression | met | CI green on 8eeb18e, 7f23a3b, 88b9abc. No file in `src/` changed except `database.types.ts`; no screen read `audit_events` before (brief) |

**Engineering's answers to the open questions:** no definer function returns free text from `changed` to a coordination role; `org_admins_read_audit` was used by no fixture or script outside pgTAP. Taken as answered.

**Deviations (decided):**
1. Names, regions and the invitation email classed `free_text` although not health data: **accepted**. They are typed by people with no closed set; withholding them from an administrator outside the team costs no task (she reads teams and members in `/admin` through their own readers). Reclassing needs a PO decision, one catalogue row each.
2. Records without a resolvable team (member profiles, invitations, referrals) never show free text through this reader: **accepted** (protective). The client's own extract (D-4 r1) gets its own path, never this reader widened (`lca` 03:42, D-4 note 2).
3. A 0-row call is recorded with organisation null, so no administrator reads it through `org_audit_read_log`: **accepted**. Nothing was disclosed by such a call; the row stays as evidence for the operator (`lca` 03:42: no objection).
4. Reading the read record needs no purpose: **accepted**. The rows are staff data about reads, not client content, and are never grouped per administrator (AUD1-5; D-4 no-per-member line).
5. `quality_holds.reason` enters `changed` once, when the hold is set (guard trigger): **accepted**, information only.
6. pgTAP 076 test clock pinned to 10:00 Zurich (time-of-day dependence found while running the suite): **accepted**. It makes the test independent of when CI runs; no assertion was weakened or skipped.
7. A call refused for a bad purpose rolls back and records nothing (ADR-090): **accepted**. A refused call returns nothing; AUD1-5 is about reads that happen.

**Clinical gate:** the latest merged Clinical Governance section (2026-10-25 17:26) has a note on AUD1, no finding: a safety review of a hold by someone outside the team needs the Clinical Owner's task-bound read (G-1, D-16), not built. `cra` 01:26 (open PR #416, read on its branch): no clinical finding on AUD1. AUD1 carries no clinical rule; nobody outside the team reads a hold's reason, which is the protective outcome. Gate passed; a later `cra` finding on 0077 would reopen AUD1.

**Legal:** `lca` 03:42 (advisory, not legal advice): F-3 met by D-3 item 6 (b), first branch, compliant under every plausible interpretation on the federal sources read; D-4 r3 met; no legal objection to deviations (1)-(4).

**Non-blocking follow-ups (product authority, narrow only):**
- **AUD1-M1 (before the first real client, with the DSFA, D-3 gate ii):** purpose `billing` returns `code` values only, also to an administrator who is a member of the record's team. Billing needs the fact that a hold was set or lifted, when and by whom, never its reason; a team member reads the reason as a nurse in the team's own view. pgTAP: an administrator in the team reading a hold with purpose `billing` gets `reason` null and `text_withheld = true`; with `compliance` she reads it. (From `lca` 03:42 point 3; challenge row 2026-10-26 04:10.)
- **AUD1-M2 (docs, next Engineering PR that touches `READ_PATHS.md`):** the F-3 row and the header say "closed" without "in PR … on merge".

**Why accepted:** no login can browse the audit log of every team any more. An administrator reads one record, for a named purpose, and her read is itself recorded; a team's free text, including a quality hold's reason that can describe a client's health, stays in the team. With it, the last open line of D-3 gate (iv) (F-3) is met, so every read path for client-linked rows is now team-scoped and tested, and D-4 gate (r3) is met. Real client data stay blocked by gates (i)-(iii), D-1, D-9, D-29 and the other go-live conditions.
