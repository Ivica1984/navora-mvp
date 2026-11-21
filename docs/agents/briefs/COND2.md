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
- [ ] **COND2-4a, provenance of the requested start in the return task** (*added 2026-10-27 06:10 by po*; `cra` 05:30 CGR-73, advisory S3; PR #502 open). The case may keep its stored date when the new request has none (unchanged), but the return task on `/team` shows "Gewünschter Beginn (laut Zuweiser)" **only from this return's request** (the resume's `referral_links` row and its `partner_requests` row); when this request carried no date it reads "nicht angegeben". No kept date from an earlier referral is shown as this referrer's statement. pgTAP: first return with a date → the task reads that date; second return without a date → the task reads no referrer date ("nicht angegeben"), while the case's stored date is unchanged and the first return's values stay in the trail; a pre-IPA1-7 request without a date → no date. Fits #502 before its merge; COND2 is `delivered` only with it.
- [ ] **COND2-4b, the COND2-4a proof is deterministic** (*added 2026-10-27 10:14 by po*; `cra` 09:30 CGR-74, advisory S3, fix before merge; PR #502 head `10745eb`). pgTAP 088 must prove COND2-4a in every run, not by a random UUID tie-break: the resume links of the test carry distinct, increasing `created_at` (Engineering's choice of means, stated in ADR-102, e.g. `referral_links.created_at` default `private.now()` in 0088 so `pg_temp.age_link` takes effect, or an order key that grows with each resume in one transaction). Add one assertion that fails if the tie-break decides (e.g. the three resume links have three distinct `created_at`). Correct the ADR-102 sentence "created_at defaults to private.now()" to what the code does. Production order unchanged. COND2 is `delivered` only with it.
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
For COND2-4a (06:10): add it to #502 before merge; if #502 is already merged, a third PR under hand-off #491.

**PO note 2026-10-27 06:10 CET (CGR-73).** Decided as COND2-4a rather than "label the kept date with its origin": the team plans a returning client's first visit from what this referrer asked for; a weeks-old date from another referral, even labelled, invites planning from it (the provenance point of CGR-69 and P-14). Showing nothing when nothing was asked is the honest display and costs one join. Display only; no rule.

For COND2-4b (10:14): in #502 before merge, with COND2-4a.

**PO note 2026-10-27 10:14 CET (CGR-74).** Decided as a criterion, not a note: a test that passes by chance is not evidence, and a `db` job that turns red at random on unrelated PRs would invite re-runs that hide a real regression of the provenance rule (the AN2-C1 lesson). Test and ADR only; no rule.

## PO review and acceptance 2026-10-27 13:35 CET: accepted

**Delivered:** #495 (COND2-1 to COND2-3; migration 0087, ADR-101; merged `0aa7f61`) and #502 (COND2-4, -4a, -4b; migration 0088, ADR-102 with amendments 07:40 and 10:20; merged `799700d`). **CI** (check runs read through the GitHub API): `app`, `db`, `e2e` green on the #495 head `1a4e3c8` and merge commit `0aa7f61`; on the #502 head `09f9a26`; on `799700d` `app` and `db` green and `e2e` cancelled (superseded run); on `recovery/main` `da913d5`, which contains both merges, `app`, `db`, `e2e` green. **The PO did not run the tests.** The PO read ADR-101, ADR-102, the pgTAP plans of 087 (36) and 088 (35), the 0088 step 1b, the `/team` and `/field` diffs and the unit test `cond2-operations-payload`.

| Criterion | Result | Evidence |
|---|---|---|
| COND2-1 = COND1-C1 (count only in the access-end path) | met | 0087: `member_unexported_working_days` dropped; `prepare_member_access_end` returns the count only on `ok`, one `audit_events` row per call without the count; pgTAP 087 (old reader gone; RN, Operations, coach, other organisation's administrator get none; no self-prepare; `/work` count unchanged); pgTAP 083 adjusted (deviation 2) |
| COND2-2 = COND1-C2 (take-over of a lapsed claim) | met | 0087: `in_review` → `in_review` only when `quality_claim_lapsed`; permission `can_handle_quality_event` unchanged; pgTAP 087 (a)-(e) one by one (lines 115-161); "Übernehmen" in `field/quality-section.tsx`; e2e `quality.spec` at 390 px |
| COND2-3 = IPA1-C1 (no visit list to `/operations`) | met | `operations/queries.ts`, `types.ts`: `care_visits` read and `visits` key removed; unit `cond2-operations-payload` (no `visits` key, `care_visits` not read, OPS1 calls unchanged); `operations.spec` (IPA1-6) green in CI |
| COND2-4 = IPA1-C2 (resumed case carries the new referral's urgency, source, requested start) | met | 0088 resume step: audited update of the three values (change_log old and new, actor, key; `audit_events`); date never blanked (`coalesce`); `convert_partner_request` untouched; pgTAP 088 (team RN and assistant read; other team and Operations read nothing; `team_offers` output and order unchanged; replay writes nothing); pgTAP 086 allowlist; e2e `intake.spec` at 390 px |
| COND2-4a (requested start only from this return's request) | met | 0088: `return_referrer_requested_start` from the newest `resume` link's `partner_requests` row, only while `review_after_pause` is open; "nicht angegeben" otherwise (`team-client.tsx:529`); pgTAP 088 second return without a date and pre-IPA1-7 return read no date while the case keeps its date |
| COND2-4b (deterministic proof) | met | 0088 step 1b: `referral_links.created_at` default `private.now()`; pgTAP 088:184 three distinct `created_at`, 088:188 default check; ADR-102 sentence corrected (amendment 10:20) |
| Negative (nothing widened) | met | ADR-101 and ADR-102 *No rule*; `READ_PATHS.md` updated in both PRs (only narrowed reads and one display read inside the team's existing case scope); pgTAP 087 "no read widened", 088 negative reads |

**Deviations (all decided):**
- ADR-101 (1) refused rather than null: **accepted** (the brief allowed either; a missing function cannot be mistaken for a zero).
- ADR-101 (2) no count after her access has ended: **accepted** (the count was shown in the end result; nothing to export afterwards).
- ADR-101 (3) the read is recorded in `audit_events`, not `audit_read_log`: **accepted**. A purpose code for this read is not needed while the row names the command; if `lca` at G-19 item 2 asks for a purpose-coded read, it becomes a condition then.
- ADR-101 (4) a restored former owner may take over a still-lapsed claim like any member: **accepted** (same LEAVE1-C3/C5 rule for everyone; she cannot take back a live claim, pgTAP 087 (e)).
- ADR-101 (5) existing QG1 rejection text: **accepted**.
- ADR-101 (6) synthetic leaver `austritt.test` and seed event 704: **accepted** (synthetic, no other seed row changed).
- ADR-102 (1) source and referrer date shown only while the return's review task is open: **accepted**. It is the narrowest read that meets "where it handles the return" and keeps intake facts out of a standing case-card read (ADR-100 (3)).
- ADR-102 (2) the level is recorded with its source: **accepted** (a source without its level would be wrong).
- ADR-102 (3) a later re-matching would read the newest level: **accepted** as "one source". Any future read that orders, filters or routes by it is a new rule of class *care-context fact recorded by a person* and needs the adviser and D-15 (`clinical`); nothing does today (pgTAP 086 allowlist).
- ADR-102 (4) the e2e pauses and resumes seed case Testfall 08 and closes the task: **accepted**.
- COND2-1's withdrawal option (if `lca` found the display-only narrowing sufficient) is **not used**: an accountable read is cheaper than the question.

**Clinical gate:** the `cra` section 2026-10-27 09:30 CET states "COND2 as a whole: clinical gate clear once #502 is merged with CGR-74 fixed". #502 was merged with CGR-74 fixed in 0088 step 1b (above). CGR-70 was closed by `cra` 05:30. CGR-71, CGR-73 and CGR-74 are advisory (S3) and their remedies are on `recovery/main`; `cra` confirms their closure on the merge commit `799700d` in its next section. If `cra` finds the merged code differs from what it read, the PO reopens.

| Finding on this item | Severity | Considered | Decision |
|---|---|---|---|
| CGR-70 (lapsed quality claim can only be closed) | advisory (S3) | yes | closed by `cra` 05:30 (COND2-2) |
| CGR-71 (resumed case keeps the old referral's facts) | advisory (S3) | yes | remedy merged (COND2-4); closure by `cra` on `799700d` expected |
| CGR-73 (kept date shown as this referrer's request) | advisory (S3) | yes | remedy merged (COND2-4a); closure expected |
| CGR-74 (non-deterministic pgTAP proof) | advisory (S3) | yes | fixed before merge (COND2-4b); closure expected |

**Value and care model:** a team can finish a quality review its former colleague started instead of closing it unreviewed (patient safety, team autonomy); the team that keeps a returning client plans from what this referrer asked for (continuity, value 2); a leaver's export habits are no longer a standing administrator view, and Operations' browser no longer receives every visit with the nurse's name (data minimisation, less hierarchy). **Handbook:** reads follow the bounded contexts (Quality inside the team, Referral facts reach the Case where the team decides), no central dispatcher read. No open condition from COND2.

**Decision: COND2 `accepted`.** Next approved item: UX1 (*Next up* 1).

**Challenge (13:35):** the three workflows COND2 touched were checked against the challenge table: the single-person quality claim (P-13), the hand-linked returning referral (P-15) and the leaver's export reminder (P-16) already carry pilot hypotheses that would remove them; COND2 removes the dead ends without settling those questions. No new row.
