---
id: AUD1
title: Administrators read the audit log only for a stated purpose, without the team's free text
author: po
status: approved
updated: 2026-10-25
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
- [ ] **AUD1-5 Each read is recorded.** Every call of the purpose reader appends one row (caller, time, entity type and id, purpose code, number of rows returned) to an append-only table that no role can update or delete; administrators read their organisation's rows of it through the same pattern (no table-wide read by other roles). No client field, no free text in it. pgTAP: a call adds one row; update and delete are refused, as for `audit_events` (005:101).
- [ ] **AUD1-6 Inventory and gate.** `READ_PATHS.md`: F-3 marked closed with its pgTAP; D-4 gate (r3) marked met in the status row; r1 (client extract) and r2 (retention class per audited column) stay open.
- [ ] **AUD1-7 No regression.** Every existing pgTAP, unit and e2e test green; `/admin`, `/team`, `/field`, `/operations` show what they show today.

## Rules and their input class
One access rule (who reads which audit row, and which part): *visit/schedule fact* class (organisation, team membership, role, purpose code). The three purpose codes are the D-4 provisional rule, not new. No signal, threshold, priority or clinical content. Not "for the adviser".

## Out of scope
- Retention periods, deletion or anonymisation (D-4 final periods: `owner` with a legal adviser after D-11, D-12).
- Gate r1 (client extract with staff identities masked) and r2 (retention class per audited column): later, after D-11 and D-12.
- The general read log of client data (D-3 gate i) and the DSFA (gate ii). AUD1-5 records reads of the audit log only.
- Who outside the team may read a quality hold's reason for a safety review (the Clinical Owner, G-1; D-16). Until named, nobody outside the team reads it.
- Any `/admin` audit screen.

## Constraints and references
D-3 item 6 (b) and item 7 (gate iv checklist), D-4 provisional rule (po 2026-10-24 10:11; gates r1-r3), Q13 (F-3 route), `READ_PATHS.md` F-3, RLS2/RLS3 patterns (0066, 0070). `lca` 15:41 (advisory, not legal advice): gate (iv) not met while F-1 and F-3 are open. **Clinical gate:** no clinical rule; `cra` is informed (quality hold reasons are clinical free text) and may name a task-bound read for the Clinical Owner, which then goes through this reader with its own purpose, never the table. **Legal:** `lca` re-checks D-3 gate (iv) when AUD1 is delivered. Real data stays blocked by D-1, D-9, D-29 and the other gates regardless.

## Open questions for engineering
- Does any definer function read `audit_events` on behalf of a coordination role and return free text from `changed`? Name it in AUD1-1; if it does, mask it the same way (AUD1-4) in this PR.
- Is `org_admins_read_audit` used by any test fixture or seed script outside pgTAP?
- Estimate: one additive migration (drop the policy, one reader, one append-only read table), about 25-35 pgTAP assertions, an inventory update.
