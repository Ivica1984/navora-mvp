---
id: F6R
title: Return a report instead of countersigning a version known to be wrong
author: po
status: approved
updated: 2026-10-24
---

# F6R — Return a report instead of countersigning a version known to be wrong

**Approved by the PO 2026-10-24 19:09.** Product decision: D-10 sub-question R, decided by po within product authority ([`decisions/D-10.md`](../decisions/D-10.md)): `cra` 18:26 classifies R as a documentation-integrity workflow inside CR-011/CR-043 that the PO may decide under conditions (a)-(d); `lca` 11:55 finds R compliant under every plausible interpretation on the sources read under (a)-(c), to be confirmed against the pilot canton once D-11 is answered. Who must countersign (CR-011, D-10 A vs. B, `clinical`) does not change.

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
