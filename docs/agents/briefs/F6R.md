---
id: F6R
title: Return a report instead of countersigning a version known to be wrong
author: po
status: approved
updated: 2026-10-25
---

# F6R — Return a report instead of countersigning a version known to be wrong

**Accepted by the PO 2026-10-25 00:10** (#320, condition F6R-G1; evidence table at the end). **Approved by the PO 2026-10-24 19:09.** Product decision: D-10 sub-question R, decided by po within product authority ([`decisions/D-10.md`](../decisions/D-10.md)): `cra` 18:26 classifies R as a documentation-integrity workflow inside CR-011/CR-043 that the PO may decide under conditions (a)-(d); `lca` 11:55 finds R compliant under every plausible interpretation on the sources read under (a)-(c), to be confirmed against the pilot canton once D-11 is answered. Who must countersign (CR-011, D-10 A vs. B, `clinical`) does not change.

## Problem
A registered nurse (RN) who countersigns a care assistant's report and sees a wrong time or a wrong service today has one path: countersign the version she knows is wrong, then wait for the performer to open a correction (F6, 0040, 0044: only the performer signs a correction). Between those steps the wrong version is `final`: the team reads it as the record, and a billing fact is built from it (J5, 0043; `report_not_final` only guards non-final reports). The countersignature no longer means "checked and agreed" (`SAFETY_RISK_REGISTER.md` C-7). Evidence: `cra` 18:26 (D-10 block), `lca` 11:55 (D-10), the PO note 2026-10-23 08:20 that introduced "countersign, then correct" as the strict default.

**Why does this workflow exist?** Because the only states were "frozen" and "final". From scratch, a reviewer sends a draft back with a reason, the author fixes it, and only the agreed version becomes the record and the billing basis. That removes one round of correction paperwork per error and keeps a wrong version out of billing.

## Users and journey step
Care assistants (performers of A/C visits), the team's registered nurses (countersigners); Visit → Documentation → Billing (F6 signed report, J5 billing facts).

## Outcome
An RN of the team can return a signed, awaiting-countersignature report to its performer with a reason. The performer corrects and signs again; only then can it be countersigned and become `final`. The returned version and the reason are kept. A returned report is never lost: it stays open for the performer and the team until `final`.

## Acceptance criteria
- [ ] **F6R-1 Return command.** `return_report(report_id, reason, idempotency_key)` is allowed only to a registered nurse of the report's team who is not the performer, only on a report in `signed` with `countersign_required`. It moves the report back to `draft` for its performer. A reason of at least 10 characters is required. pgTAP: an RN of the team returns → state `draft`; the performer herself, a care assistant, an RN of another team, an admin without team membership, a coach, a client or partner account → refused (named reason); a report in `draft`, `final` or `withdrawn`, or one with `countersign_required = false` → refused; the same idempotency key twice → one return.
- [ ] **F6R-2 Append-only return record (condition c).** Each return stores the report, the returned version and its snapshot hash, the reason, the returner and the time, in a row that no role can update or delete (trigger refusal, pgTAP for each role including the service role path used by the app). The returned version stays readable to the performer and the team's registered nurses.
- [ ] **F6R-3 Only the performer changes the content.** After a return, only the performer may change the visit's facts and sign again (the existing sign path); the returner and every other member are refused on the fact and sign commands. pgTAP: returner edits a time → refused; performer edits and signs → `signed`, a new version; then countersign → `final`.
- [ ] **F6R-4 Superseding, never in-place (condition b).** An observation that was already visible to the team (HAND1 reads observations, 0033:144-151) changes after a return only through a new row with `supersedes_id`; the earlier row stays readable. pgTAP: after a return, a changed observation → a new row referencing the earlier one, the earlier row unchanged and visible in the history.
- [ ] **F6R-5 Never stranded (condition a).** A returned report appears as open in the performer's `/field` list ("Zurückgegeben: bitte korrigieren und neu unterschreiben", with the reason) and in the team's countersignature queue as "zurückgegeben", until it is `final`. `report_not_final` keeps raising for it exactly as before (CR-053; same threshold). pgTAP: returned report → present in both lists; `report_not_final` present after the threshold; final → gone from both. The performer-left case follows D-30's interim rule (CR-048), unchanged.
- [ ] **F6R-6 Billing.** A returned report produces no billing fact until it is `final` again; the billing fact is built from the countersigned version only. pgTAP: return → no billing fact for that visit; re-sign and countersign → one billing fact with the corrected minutes.
- [ ] **F6R-7 Reason is health data (condition d).** The reason is visible only to the performer and the team's registered nurses (RLS, pgTAP for a care-assistant colleague, another team, an admin without membership: not visible). It never appears in a push payload (SIG2-8 constant unchanged), AN1, AN2 or any analytics, billing or team export. **Exception (PO 2026-10-24 20:09, after `lca` 19:55):** a client's own access extract (DSG Art. 25 Abs. 2 lit. b; D-4 gate r1), when one is built, includes the returned versions and their reasons; F6R builds no extract. Unit/pgTAP: no AN1/AN2 view and no billing or analytics export reads the reason column.
- [ ] **F6R-8 UI.** Next to "Gegenzeichnen" the countersigner sees "Zurückgeben" with a required reason field; the confirmation names what happens ("Der Bericht geht an <Name> zurück und wird erst nach erneuter Unterschrift und deiner Gegenzeichnung gültig"). e2e: an RN returns a care assistant's report with a reason; the care assistant sees it in `/field`, corrects a time, signs; the RN countersigns; the report is `final`. Phone width.
- [ ] **F6R-9 Evidence.** AN2 gains, per team and organisation (AN1 suppression, no per-person figures): the share of countersign-required reports returned at least once, and the median `signed_at` → `countersigned_at` (countersignature latency) with returns included. These are the facts the Clinical Owner needs for D-10 A vs. B after the pilot.

## Rules and their input class
- `return_report` permission: *visit/schedule fact* (role, team, report state). No clinical content is read.
- `report_not_final` on a returned report: *visit/schedule fact* (unchanged rule).

## Out of scope
- Who must countersign, any sample or risk-based scheme (D-10 A vs. B, `clinical`); B is reconsidered after the pilot on F6R-9 evidence.
- Who corrects when the performer has left (D-30, `clinical`).
- A return of a `final` report (that stays a correction, F6/0044).
- A countersigner writing into another's report.

## Constraints and references
D-10 (package, R decided by po 2026-10-24 19:09), CR-011, CR-043, CR-048, CR-053, CR-056; F6 (0016, 0026, 0040, 0044, 0049), J5 (0043), HAND1 (0033); `SAFETY_RISK_REGISTER.md` C-7; H-04: a countersignature attests only as much as the `registered_nurse` label is verified (D-29 real-data gate, unchanged). The Clinical Owner is informed (`cra`), not asked to approve. ROADMAP: Dokumentation.

## Open questions for engineering
- Whether `draft` after a return reuses the version number or opens the next one (either is acceptable if F6R-2 keeps the returned snapshot hash and F6R-3 produces a new signed version).
- Confirm or correct the po estimate in D-10 (one additive migration, about 15 pgTAP assertions).

## PO review 2026-10-25 00:10 (accepted, condition F6R-G1)

Delivered in #320 (merged as 868e3e0; migration `20261021000065_f6r_return_report.sql`; pgTAP `066_f6r_return_report.test.sql`, plan 82; unit `field-report`; e2e `tests/e2e/field.spec.ts`; ADR-079). CI green on the PR head 3766bde (app, db, e2e) and on `recovery/main` d293062 (app, db, e2e, sync); the runs on the merge commit 868e3e0 were cancelled by the next push to `recovery/main`, which is green. **The PO did not run the tests**; the evidence is the merged tests, green CI read through the GitHub API, and the PO's reading of the migration and pgTAP 066.

| Criterion | Result | Evidence |
|---|---|---|
| F6R-1 return command | met | 0065:198-271 `return_report`: refusals `own_report`, `rn_required`, `not_team_member` (another team's RN, admin without membership, coach, Operations, an account without membership), `reason_too_short` (< 10, null), `not_awaiting_countersignature` (final, draft), `not_latest`, `performer_not_in_team`; reason over 500 → 22023; same key → `duplicate`. pgTAP 066 lines 105-148 |
| F6R-2 append-only record | met | `visit_report_returns` (version, `snapshot_hash`, reason, `returned_by`, `returned_at`); no grant beyond `select` for `authenticated`, none for `service_role`; trigger refuses update, delete and truncate for the table owner, the service role and an app user; audited without the reason. pgTAP 066 lines 149-176. The returned version stays `signed` and readable through `report_returns` for the performer |
| F6R-3 only the performer changes the content | met | 0065 patches of `correct_visit_time` and `record_observation` (`visit_open_return_performer`); returner and colleague refused on time, observation, summary and sign; the returned version cannot be countersigned (`not_latest`). pgTAP 066 lines 230-258 |
| F6R-4 superseding, never in place | met | pgTAP 066 lines 259-287: a changed observation is a new row with `supersedes_id`; the earlier row unchanged and in the history |
| F6R-5 never stranded | met | `field_returned_reports` (performer, any date, with reason), `field_countersign_queue.returned`; `report_not_final` raises after the unchanged threshold, no `report_correction_open`. pgTAP 066 lines 206-223. The performer-left case keeps CR-048: return refused while she is not in the team, and her removal refused while a returned report is not signed again (deviation 3) |
| F6R-6 billing | met | pgTAP 066 lines 224-229 (no billing fact while returned) and 288-312 (one fact from the countersigned version with the corrected minutes) |
| F6R-7 reason is health data | met | RLS `performer_and_team_rn_read`; a care-assistant colleague, another team's RN and an admin without membership read nothing; a colleague sees on `/field` that it was returned, not why; catalogue check: only the command and the four `/field` read models read the table, no view reads it (pgTAP 066 lines 177-205). Push constant (SIG2-8) not touched by the diff. The client access extract exception is documented on the column; F6R builds no extract |
| F6R-8 UI | met | "Zurückgeben" next to "Gegenzeichnen" (`src/app/(protected)/field/report-section.tsx`), confirmation text in `src/features/field/report.ts:148` as the brief words it; e2e `field.spec.ts` at 390 px: RN returns with a reason, the care assistant corrects and signs, the RN countersigns, `final` |
| F6R-9 evidence | met | AN2 `report_returned_share`, `countersign_latency_hours`, per team and on the organisation row under AN1 suppression, no per-person figure (pgTAP 066 lines 313-333) |
| Clinical gate (README) | condition F6R-G1 | No `cra` section covers 0065 (the newest merged report section is 2026-10-24 02:26; the sections 06:30 to 22:26 are in open PRs #259, #278, #294, #306, #321). `cra` 22:26 (#321, line 56 and table line 102) reviewed the brief: conditions (a)-(d) are carried by F6R-5, -4, -2, -7, and **"no `cra` gate is needed unless the PR adds a rule"**. The PO checked the diff for added rules: it adds permissions on role, team and report state (input class *visit/schedule fact*, as the brief names), excludes a return version from `report_correction_open` while `report_not_final` keeps raising unchanged (F6R-5 required exactly that signal), and extends the existing `has_unsigned_reports` refusal of `remove_team_member`. No clinical, quality, billing or tariff rule is added. **F6R-G1:** `cra` confirms in its next section that 0065 adds no rule needing its gate; a `blocking` finding returns F6R to `changes-requested` |
| H-04 / D-29 | unchanged | a countersignature or a return attests only as much as the `registered_nurse` label is verified; the D-29 real-data gate stays |

**Deviations (IMPLEMENTATION_STATUS), decided:**
1. Reason at most 500 characters: **accepted** (a bound protects the read models; 500 is enough for a reason; no rule).
2. A return version raises no `report_correction_open`: **accepted** (it is not a correction; `report_not_final` covers it with the same threshold, as F6R-5 requires; two signals for one open report would be noise).
3. `remove_team_member` refuses to remove a performer while a returned report of hers is not signed again, and a return is refused while the performer is not in the team: **accepted** (keeps CR-048 / D-30's interim rule and F6R-5; a report never strands). Team autonomy cost is one signature before a removal; ABS1 absence is unaffected.
4. AN1 `pilot_kpis` takes the first final version's time: **accepted** (identical without returns; a returned version was never final).
5. The countersignature queue shows a returned report without the reason: **accepted** (minimisation; the reason stays on the card and in the performer's list).
6. Clinical gate handled as above: **accepted** with F6R-G1.

**Business and care-model value:** a registered nurse who sees an error no longer has to sign it into the record and the billing basis; one correction round per error disappears (less administration, value 5), the record stays true for the next nurse (continuity, value 2), and only the agreed version is billed. F6R-9 gives the Clinical Owner the evidence for D-10 A vs. B, the decision that can remove the countersignature of every care-assistant visit. **Architecture Handbook:** Documentation context, append-only, audited commands, RLS on the team; no new bounded context; aligned.
