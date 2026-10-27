---
id: COND2
title: Pre-pilot conditions COND1-C1, COND1-C2, IPA1-C1 and IPA1-C2 under one hand-off
author: po
status: approved
updated: 2026-10-27
---

# COND2 — Pre-pilot conditions COND1-C1, COND1-C2, IPA1-C1 and IPA1-C2

## Problem
Three accepted items left small conditions that must be met before the first real client or employee (G-13, G-19). Without a hand-off, Engineering has no approved item once IPA1 is accepted, and the conditions would wait until a go-live rush:
- **COND1-C1** ([COND1](COND1.md), deviation 16): an administrator can call `member_unexported_working_days` for any member at any time. The promise of WORK1-C3 (b) ("no standing per-person view of export habits") holds by the UI only.
- **COND1-C2** ([COND1](COND1.md), `cra` CGR-70): since LEAVE1-C5 a lapsed `in_review` quality claim can only be closed, which invites closing an event unreviewed (PS-59).
- **IPA1-C1** ([IPA1](IPA1.md), deviation 3): `/operations` still reads every `care_visits` row of the organisation, with the nurse's name, and sends it to the browser, although nothing shows it any more.
- **IPA1-C2** ([IPA1](IPA1.md) *PO acceptance 2026-10-27 02:10*, `cra` CGR-71; *added 2026-10-27 02:10 by po*): when a returning referral resumes a paused case (`link_returning_referral`, 0034:359-391), no case or matching request is inserted, so 0086's insert triggers never carry the new referral's urgency, its source or the referrer's requested start; they stay on `partner_requests`, which the team cannot read. The team keeps reading the first referral's values.

## Users and journey step
Administrators (access end, ADM1/LEAVE1), team members (Quality, QG1; the team that keeps a returning client, RET1), Operations (`/operations`). Journey: Referral/Case (return), Quality, Analytics/Operations, Administration.

## Outcome
A nurse's export habits are readable only in the access-end step; a team can continue a quality review that its former colleague started; Operations' browser receives no visit list it does not show; the team that keeps a returning client reads the referrer's newest urgency, its source and requested start.

## Acceptance criteria
- [ ] **COND2-1 = COND1-C1.** `member_unexported_working_days` returns a count only inside the access-end command path (for example a "prepare access end" call that records the read, or only in the `end_member_access` result and its dry run). pgTAP: an administrator calling the reader outside that path gets no count (refused or null, stated in the ADR); the end step still shows it; `my_unexported_working_days` on `/work` is unchanged for the nurse herself. If `lca` at G-19 item 2 finds the display-only narrowing sufficient, the PO may withdraw this criterion.
- [ ] **COND2-2 = COND1-C2.** `set_quality_event_status(…, 'in_review')` is accepted from `in_review` when, and only when, the current claim has lapsed (`quality_claim_lapsed`, 0085). The caller needs the permission that already allows `open` → `in_review` (no new role). The new owner and the transition are written to `quality_event_log` with `access_seq`; the old claim and its history stay readable; nothing is rewritten. pgTAP: (a) a team member takes over a lapsed claim; (b) a live claim (owner's access not ended) stays refused with `rejected`; (c) a caller without the `open` → `in_review` permission is refused; (d) the log holds both owners in order; (e) a restore of the former owner does not give the claim back. The team view shows "Übernehmen" on a lapsed claim; e2e at 390 px.
- [ ] **COND2-3 = IPA1-C1.** The `/operations` dashboard no longer reads or serialises `care_visits` (`src/features/operations/queries.ts`, `OPERATIONS_VISIT_COLUMNS`). Unit test: the `OperationsDashboard` payload has no `visits` key. The IPA1-6 e2e at 390 px still passes; OPS1 exceptions and signals unchanged.
- [ ] **COND2-4 = IPA1-C2** (*added 2026-10-27 02:10 by po*; `cra` CGR-71 remedy). When `link_returning_referral` resumes a paused case, the new request's `urgency`, `urgency_source` and `referrer_requested_start` are recorded on the resumed case in an audited update (old and new values in `change_log`, actor and idempotency key as in the resume path), or shown to the team in the `review_after_pause` task detail; Engineering states the choice in the ADR (recording on the case is preferred: one source for the team's existing reads). The team sees level with source ("Dringlichkeit: <Stufe> (<Quelle>)") and the requested start for that case where it handles the return. A request recorded before IPA1-7 carries `unknown` and is shown as such (new requests cannot, 0086); a request without `referrer_requested_start` leaves the case's date unchanged (never blanked). pgTAP: pause a case, link a returning referral with `hoch`, `referrer_stated` and a date → the team reads all three for that case; the case's earlier values stay in the audit trail; the new-case path (`convert_partner_request`) unchanged; `team_offers` output and ORDER BY (G3) unchanged; no read for a person outside the case's team. No urgency, date or source changes the visits, deadlines, signals or order of anything (display only, as IPA1-8).
- [ ] Negative: no signal, exception, threshold, quality severity, hold rule or read scope is widened. No person gains a read she did not have.

## Rules and their input class
No rule is added or changed. COND2-1 and COND2-3 only narrow reads. COND2-2 adds one permitted transition for a claim that has lapsed; it uses the existing permission and no threshold (what counts as "too long" in a review stays D-16, `clinical`). COND2-4 carries two facts already recorded at intake (input class: *care-context fact recorded by a person* and an organisational date stated by the referrer) to the team on one more path; it ranks, routes and escalates nothing. Which date or level the care decision relies on stays `clinical` (D-15, P-14).

## Out of scope
- Letting any member continue a live claim (hypothesis P-13, pilot data first).
- Ordering, deadlines or visit changes from the returning referral's urgency or date (display only).
- The employer's final information text (G-19 item 2, D-12).
- Quality event types, severities and holds (D-16).

## Constraints and references
COND1 *PO review 21:10* (deviation 16, COND1-C1) and *PO acceptance 22:10* (CGR-70, COND1-C2); IPA1 *PO review 2026-10-27 01:40* (deviation 3, IPA1-C1) and *PO acceptance 02:10* (CGR-71, IPA1-C2); `lca` D-34 re-check 2026-10-27 01:45 (CGR-71 remedy compliant under every plausible interpretation); RET1 (0034); `cra` CGR-70; WORK1-C3; LEAVE1-C5 (0085); `READ_PATHS.md`; G-13, G-19.

## Open questions for engineering
For COND2-1: does a recorded "prepare access end" read fit the `end_member_access` flow better than returning the count only in its result? State the choice in the ADR.
For COND2-4: if a COND2 PR is already open when this criterion is added, it may ride a second PR under the same hand-off; COND2 is `delivered` only when all four are merged.
