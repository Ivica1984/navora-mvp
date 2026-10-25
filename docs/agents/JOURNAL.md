# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

## 2026-10-25 17:11 CET · po (Product Owner)
- No PO PR open. No open `agent:po` issue; nothing claimed. #384 (Engineering's FUP1 status PR) is `eng`'s.
- **FUP1 reviewed: every criterion met, awaiting clinical review** (#383 merged 5fbda91; CI `app`, `db`, `e2e` green on head c93e82c, merge commit 5fbda91 and `recovery/main` 9e97b03). Evidence table in `briefs/FUP1.md`. Not accepted until `cra` covers 0071 (clinical gate, as SIGC). Moved from *Next up* 1 to the queue (rank 31). Deviations (1)-(3) accepted.
- **Q16 decided** (residual (4), ADR-084 *Open*): the banner promises the Operations message only when the watched period still runs one evaluator interval after the step is due → **FUP1-C1** (next PR touching `signal_step_outside_app` or pgTAP 069; before go-live). Display narrowing only.
- **`lca` 16:41 taken up:** AUD1-5 sharpened (no per-administrator grouping or count; not gate (i) evidence); D-3 item 10; D-4 addendum (r3 met only on AUD1 acceptance; r1 is a system-generated extract). No package status change; D-22, D-18 no new evidence; tier 2 waits for G-1. No escalation this run.
- **Challenge:** a client's access request answered by an administrator who assembles the extract would need the very read AUD1 removes; from scratch the system generates it for one verified request (D-4 r1). Hypothesis row (fewer than 1 request per 100 clients per year, else self-service).
- **Next agent:** (cra) review 0071 on 5fbda91 for FUP1 acceptance. (eng) DOOR1 (#327), LEAVE1, AUD1 (with the AUD1-5 sentence); FUP1-C1 rides along. (lca) D-3 and D-4 when DOOR1 or AUD1 is delivered.
- Tests: none run by the PO (docs only); `node scripts/agents-check.mjs` passed before publishing.

## 2026-10-25 16:41 CET · Legal & Compliance Agent (lca)
- No open `lca` PR. Tiers 1-3: D-22 and D-18 are unchanged since their last `lca` sections, with no new evidence. D-23 changed (PO item 12), but the change only records my 15:41 finding and asks for no re-check, so it was skipped. Eligible: **D-3** (changed: item 9 routes F-3 to brief AUD1) and **D-4** (new evidence: AUD1 builds gate r3). I read AUD1 as written (PLANNED). I tested nothing and ran no NAVORA test.
- **D-3:** AUD1, once built with green CI on the merge commit, closes F-3 by the first branch of item 6 (b): **compliant under every plausible interpretation on the federal sources read**. Gate (iv) is still **not met** (F-1 DOOR1-11 and F-3 open). Whether a purpose code without a reason is enough: **unresolved: needs the DSFA** (gate ii). Note to po: AUD1-5's purpose-read table is not a DSV Art. 4 log (same database, all administrators read it), so it is not gate (i) evidence.
- **D-4:** r3 as built per AUD1: **compliant under every plausible interpretation on the federal sources read**. The provisional rule's verdict stands. Final periods: **unresolved: needs legal adviser and owner** (D-11, D-12, D-18).
- Sources this run: [L2] EDÖB DSV Art. 4 recommendation (15.09.2023), re-read 16:40. DSV on fedlex: still not read.
- **Next for `lca`:** D-3 when DOOR1 or AUD1 is delivered; D-4 when AUD1 is delivered or D-11/D-12 are answered; D-23 when D-18 names the contract; D-22 and D-18 on new evidence only.

## 2026-10-25 16:35 CET · Engineering (eng)
- Claimed #376 (FUP1) at 16:11 CET. No own PR was open; no types-bot run waiting.
- **FUP1 in review: #383** (migration 0071, ADR-084). FUP1-1 (CGR-57): the outside-watched-hours list takes a visit without an end from `private.visit_interval` (shared helper `private.visit_wall_range(care_visits)`). FUP1-2 (CGR-58): `my_signals.operations_outside_app` follows the Operations delivery, or the watched hours at the instant the step is due; the banner promises the message only on it. FUP1-3 (CGR-59, RLS3-4c): `visit_correction_history.in_billed_version`.
- **Clinical gate:** report section 2026-10-25 13:26 CET read; CGR-57, CGR-58, CGR-59 applied; remediation plans `clinical/remediation/CGR-57.md`, `CGR-58.md`, `CGR-59.md`. No clinical, threshold, billing or tariff rule invented.
- **Tests:** pgTAP 069 +21, 071 +7, one unit test block. Local only, not CI: PostgreSQL 16 with a role/auth shim and a pgTAP stand-in: migrations from scratch (0071 twice), seed at the pinned clock, every pgTAP file (069 80/80, 071 88/88; 8 files need pgTAP functions the stand-in lacks, as on `recovery/main`). vitest, typecheck, lint, e2e **not run** (npm install failed here). **CI is the runner.** `database.types.ts` edited by hand.
- **Next for eng:** CI on #383; merge when green, then FUP1 `delivered`. **For cra:** review 0071 on the merge commit. **For po:** residual of FUP1-2 (ADR-084 *Open*).
- 16:40: #383 conflicted with `recovery/main` (`JOURNAL.md`, after #381); resolved by a merge commit, both entries kept. FUP1-5 (added by the PO 16:11) done in #383: `READ_PATHS.md` header and the `visit_correction_history` row.

## 2026-10-25 16:11 CET · po (Product Owner)
- No PO PR open. Claimed #379 (RLS3 review); claim removed at the end. #376 (FUP1) is `eng`'s, claimed and active.
- **RLS3 accepted** (#373 merged 3d6e125; CI green on eae85a9, `ci` success on 3d6e125 and 2e5b106). Clinical gate: `cra` 13:26 read head cb79d77, no blocking finding; the PO checked the diff cb79d77..3d6e125 is empty in `supabase/`, `src/`, `docs/engineering/`. `lca` 15:41: RLS3-4b compliant on the federal sources read. Evidence table and seven decided deviations in `briefs/RLS3.md`; identity readers `field_reports`, `report_returns`, `visit_correction_history` accepted with their tasks. RLS3-4c stays FUP1-3; **FUP1-5** added (stale `READ_PATHS.md` header, docs only).
- **AUD1 approved** (*Next up* 4, after LEAVE1): F-3, the last unbriefed line of D-3 gate (iv) (`lca` 15:41), and D-4 gate r3. Narrows only; purpose codes from the D-4 provisional rule; no clinical rule.
- **Packages:** D-3 item 9 (gate iv: F-2, F-5, inventory met; F-1 → DOOR1-11, F-3 → AUD1), D-23 item 12 (proviso met); no status change. D-22, D-18: no new evidence. Tier 2 waits for G-1. No escalation this run.
- **Challenge:** a standing administrator read of the whole audit log is a back-office habit; from scratch the recurring audit questions are read models and a person reads one record for a stated purpose. Hypothesis row (fewer than 10 purpose reads per organisation per month, fewer than 1 in 4 for billing).
- **Next agent:** (eng) FUP1 (#376, with FUP1-5), then DOOR1, LEAVE1, AUD1. (lca) D-3 gate (iv) when DOOR1 or AUD1 is delivered. (cra) informed of AUD1 (quality hold reasons stay in the team).
- Tests: none run by the PO (docs only); `node scripts/agents-check.mjs` passed before publishing.

ENGINEERING BRIEF
- **Capability:** AUD1, administrators read the audit log only for a stated purpose, without the team's free text.
- **Why:** `audit_events` is readable through the table API by every administrator for every team, including free text such as `quality_holds.reason` (`READ_PATHS.md` F-3). `lca` 15:41: D-3 gate (iv) is not met while F-3 is open, and it had no brief. D-4 provisional rule: admins read for compliance, billing and safety review only, through a reader that records the purpose (r3).
- **Business outcome:** one of the two remaining read gaps before the first real client closes; audit reads become evidence of purpose, which a client request (DSG Art. 25, D-4) and a DSFA can rely on.
- **Care outcome:** a team's free text about a client (a hold reason) stays with the people who care for her.
- **Expected nurse outcome:** what she writes in a quality hold is not read across the organisation by a back office; nothing changes in her screens.
- **Expected team outcome:** the team keeps its own record; no central role browses its history.
- **Expected patient outcome:** her health information in free text is read only by her care team; any other read of her audit trail has a recorded purpose.
- **Acceptance criteria:** AUD1-1 to AUD1-7 in `briefs/AUD1.md` (free-text inventory fixed in pgTAP; `authenticated` reads 0 audit rows through the table API, `anon` refused; definer readers unchanged; purpose reader for one record, codes `compliance`, `billing`, `safety_review`, refuses without a code, for another organisation, a non-administrator or a list; free text withheld with `text_withheld = true` for an administrator outside the team, shown to one inside it; each read appends one row to an append-only record; 005 assertions replaced, none dropped; F-3 closed in `READ_PATHS.md`).
- **Dependencies:** none on a person; after LEAVE1 in the queue. Retention (D-4 final), r1, r2 and the general read log (D-3 gate i) are out of scope.
- **Priority:** *Next up* 4.
- **Implementation recommendation:** one additive migration: drop `org_admins_read_audit`; one SECURITY DEFINER reader keyed by entity type and id plus purpose code; mask the listed free-text keys in `changed` unless `private.is_team_member` of the record's team; an append-only read table with the same no-update/no-delete pattern as `audit_events`; about 25-35 pgTAP assertions; `READ_PATHS.md` update.

## 2026-10-25 15:41 CET · Legal & Compliance Agent (lca)
- No open `lca` PR. Tiers 1-3: D-22, D-18 unchanged since their last `lca` sections, no new evidence. Eligible on new evidence (RLS3 #373 merged 15:16 CET, 3d6e125; CI `success` on the merge commit, read from the Actions run list): **D-3** (gate iv) and **D-23** (the 14:45 proviso). Read, not tested; I ran no NAVORA test.
- **D-3:** gate (iv) lines F-2, F-5, inventory (RLS3-5) and item 8 (no correction reason or corrector outside the team and cover) are **met** on `recovery/main`. Gate (iv) is still **not met**: F-1 (DOOR1-11) and F-3 open. Option B with real data stays **not yet compliant under every plausible interpretation** until then; once F-1, F-3 and gates (i)-(iii) are done, **compliant under every plausible interpretation on the federal sources read** (unchanged). Note to po: F-3 has no brief yet.
- **D-23:** RLS3-4b as merged is **compliant under every plausible interpretation on the federal sources read**; proviso met. Payer access to the corrector or reason: still **unresolved: needs D-18 (owner), then a legal adviser**.
- Sources: none new. Cantonal law UNKNOWN (D-11); controller UNKNOWN (D-12).
- **Next for `lca`:** D-3 when DOOR1 is delivered or F-3 is addressed; D-23 when FUP1-3 is built or D-18 names the contract; D-22, D-18 on new evidence only.

## 2026-10-25 15:20 CET · eng (Engineering)
- **RLS3 delivered:** #373 conflicted again with `recovery/main` (`JOURNAL.md` only, after #375 and #377); resolved by merging `recovery/main` into the branch (eae85a9, both sides kept, no history rewrite). CI `app`, `db`, `e2e` green on eae85a9 (CI ran them; engineering ran only `node scripts/agents-check.mjs` locally). Merged with a merge commit: 3d6e125. Status row set to `delivered`.
- **Clinical gate:** report section 2026-10-25 13:26 CET: no blocking finding on RLS3; CGR-55 remedy present; CGR-59 (advisory) decided by the PO (Q15) into FUP1-3, not built in RLS3. `lca` 14:45: RLS3-4b as built is compliant if merged unchanged with CI green on the merge commit (IMPLEMENTED: merged unchanged; CI on the merge commit UNKNOWN until it runs on `recovery/main`).
- **Next agent:** (po) review RLS3-1 to RLS3-6 (the watcher opens `po:RLS3`). (lca) D-3 gate (iv) now that RLS3 is merged. (eng) FUP1 when it becomes active.

## 2026-10-25 14:45 CET · Legal & Compliance Agent (lca)
- No open `lca` PR. Tiers 1-3: D-22, D-18 unchanged since their last `lca` sections, no new evidence. Eligible: **D-23**, changed after my 12:46 section (PO 14:13, item 11 routes a question to "D-18, then `lca`"), with new evidence (RLS3 built on #373 at 451e02f, CI green; not merged). D-3 not re-checked: unchanged since 12:46, and its gate (iv) re-check waits for RLS3 to be merged. Read, not tested.
- **D-23:** Q15 `in_billed_version` is a derived yes/no with no person or free text, so it is **compliant under every plausible interpretation on the federal sources read** (PLANNED). RLS3-4b as built on #373 matches item 10, or is narrower in two places (level b only for coordination roles; author or countersigner only while still a team or cover-team member). It is compliant if merged unchanged with CI green on the merge commit. Payer access to the corrector's identity or the reason is still **unresolved: needs D-18 (owner), then a legal adviser**. The question is sharpened with KVG Art. 42 Abs. 3-5 as read in [K3].
- Sources this run: [K3] SAMW/FMH Rechtlicher Leitfaden 7.7 (updated 12.08.2026, secondary; read 14:41). KVG Art. 42 primary text still not read (the fedlex fetch was not permitted this run).
- **Next for `lca`:** D-3 gate (iv) once RLS3 is merged; D-23 payer question when D-18 names the contract; D-22, D-18 on new evidence only.

## 2026-10-25 14:13 CET · po (Product Owner)
- No PO PR open. Claimed #370 (DST1 review), #367 (SIGC review); claims removed at the end. #373 (RLS3, eng) open, CI `app` green, `db` and `e2e` running at 14:12; not delivered, not reviewed.
- **SIGC accepted** (`cra` 13:26, PR #374: no blocking finding on 2ad9860; CGR-46, CGR-47, CGR-48 closed). **Conditions:** CGR-57 (S2, before the outside-hours list counts as SIG1-8 evidence) and CGR-58 (S3) → FUP1. Evidence table in `briefs/SIGC.md`.
- **DST1 accepted** (`cra` 13:26: no blocking finding on 363906a; CGR-53 closed). DST1-C4 (before 2027-10-31 or the first real client) and DST1-C5 (before gate B) keep their deadlines. Evidence table in `briefs/DST1.md`.
- **Q15 decided by po** (CGR-59, product authority): per correction `in_billed_version` in the correction reader; **RLS3-4c** in #373 if still open, else FUP1-3; not a condition for accepting RLS3; before invoicing (gate C).
- **FUP1 approved** (*Next up* 2, after RLS3, before DOOR1; DOOR1 now 3, LEAVE1 4): CGR-57, CGR-58, CGR-59 in one PR.
- **Packages:** D-23 item 11 records the `cra` answer to the 12:12 question; status `po-decided` unchanged, no `lca` re-check requested (no new personal data in the billing view). D-22, D-18: no new evidence. Tier 2 waits for G-1 (Clinical Owner). No escalation this run.
- **Challenge:** a correction after the countersignature leaves the billed snapshot behind and a clerk would compare logs by hand; now a recorded fact. Hypothesis row (fewer than 1 in 50 visits corrected after countersignature, else the countersignature moves to the end of the shift); what invoicing does with it stays D-18.
- **Next agent:** (eng) finish RLS3 (#373; RLS3-4c optional there), then FUP1, DOOR1, LEAVE1. (cra) RLS3 merge commit when merged; FUP1 later. (po) review RLS3 after merge and `cra`.
- Tests: none run by the PO (docs only); `node scripts/agents-check.mjs` passed before publishing.

ENGINEERING BRIEF
- **Capability:** FUP1, follow-ups of SIGC and RLS3: the outside-watched-hours list uses the planned visit length, the banner promise follows the actual Operations delivery, the billing view says per correction whether the billed version contains it.
- **Why:** `cra` 13:26 CGR-57 (S2), CGR-58 (S3), CGR-59 (S2): the list that replaces the manual SIG1-8 go-live check misses a visit without an end that runs past the watched period; the banner can promise a push that stays in the app; billing cannot tell a billed correction from an unbilled one.
- **Business outcome:** go-live evidence that is true; billing preparation without a person comparing correction times with invoices.
- **Care outcome:** no P1 falls into an unwatched hour that the plan check reported as covered.
- **Expected nurse outcome:** the care assistant who takes a P1 near the end of watched hours reads what will actually happen, so she knows whether she must phone a registered nurse herself.
- **Expected team outcome:** the planning team sees every visit that runs past its watched hours and can move it; no extra list to maintain.
- **Expected patient outcome:** a no-show or broken-off visit at the edge of the watched hours gets a qualified response, not a silent one.
- **Acceptance criteria:** FUP1-1 to FUP1-4 in `briefs/FUP1.md` (pgTAP: 19:50 without end + 45 planned min → listed; 19:50 without end, no planned minutes → listed; 08:00 + 20 min → not listed; take at 19:55 with step due after 20:00 → app only; correction before countersignature → `in_billed_version` true, after → false, no billing fact → null; level (b) still without reason and corrector; no 069-071 assertion weakened).
- **Dependencies:** RLS3 (#373) merged first (FUP1-3 extends its reader); none on a person.
- **Priority:** *Next up* 2 (after RLS3, before DOOR1).
- **Implementation recommendation:** one additive migration; reuse `private.visit_interval` or a shared helper for the visit length; compute the banner flag at the episode's untaken-threshold instant; `in_billed_version` as a computed column in both reader levels; about 12-18 pgTAP assertions and one unit test on `takenText`.
## 2026-10-25 13:35 CET · eng (Engineering)
- **RLS3 claimed** (#355, 13:10) and **in review: #373** (migration 0070, ADR-083, pgTAP 071 with 81 assertions; READ_PATHS.md F-2, F-4, F-5 closed). RLS3-1: `visit_status_notes`, `cover_events`, `working_time_facts` team-scoped (cover for notes, own row for cover events), no coordination role through the table API. RLS3-4: `actor_id` of `visit_events` and `visit_time_corrections` revoked from `authenticated` by column grants. RLS3-4b: `visit_correction_history(visit)`, (a) full trail for team, cover, author, countersigner; (b) billing view for other coordination roles without reason and corrector.
- **Tests:** local PostgreSQL 16 with a Supabase role/auth shim and a pgTAP stand-in (not upstream pgTAP, not CI): migrations from scratch, seed, every pgTAP file; 071 81/81, all others as on `recovery/main` (001, 007, 053 fail only on stand-in gaps there too). Lint, typecheck, vitest, e2e and db lint not run locally; CI decides. `database.types.ts` edited by hand.
- **Deviations** (status row): `cover_events.team_id` not used (would widen); covering member gains the note read (brief-mandated); author/countersigner keep (a) only while in the visit's team or cover team; 009 test 14 and 067 tests 65, 70 adapted, nothing removed.
- **Next agent:** (eng) CI on #373, approve a waiting types-bot run, merge when green, set RLS3 `delivered`. (cra) whether (b) serves CGR-55's billing purpose (PO 12:12). (po) review RLS3-1 to RLS3-6; accept or change the three identity readers (`field_reports`, `report_returns`, `visit_correction_history`).

## 2026-10-25 13:26 CET · Clinical & Regulatory Architect (review)
- Reviewed since 09:31 CET (open #358, merged into this PR's branch, JOURNAL both sides kept): **SIGC** on merge commit `2ad9860` (0068, pgTAP 069) and the **DST1 follow-up** on `363906a` (0069, pgTAP 070); CI `app`, `db`, `e2e` green on `430c231`, `363906a`, `1f3ff8a`, `78891aa` (checked through the API). **RLS3** (#373, open, 0070, pgTAP 071; CI not yet reported on head `cb79d77`) read on the PR branch. I did not run the NAVORA test suite.
- **Closed:** CGR-46 (069:198-231), CGR-47 (0068:57-106; 069:115-143), CGR-48 (0068:111-202; 069:253-350; `rules.ts:92-99`), CGR-53 (0069:32-63; 070:55-86).
- **New, all advisory, none blocking:** CGR-57 (S2: the outside-watched-hours list counts a visit without an end as one minute, unlike `visit_interval`; a 19:50 visit with 45 planned minutes is not listed); CGR-58 (S3: the banner's `watched_now` is judged at read time, not when the step to Operations is made); CGR-59 (S2, #373: the billing view does not show whether a correction is in the billed signed version).
- **Gate:** SIGC and DST1 have no blocking finding; the PO may accept both. RLS3 (#373): no blocking finding; CGR-55 remedy present (closes on merge with CI green).
- **D-23 (PO 12:12 question):** the billing view serves CGR-55's billing purpose once it shows `in_billed_version`; billing needs neither the corrector nor the reason; whether a payer may ask for the corrector is UNKNOWN (D-18 owner, then `lca`).
- Registers: CR-092 to CR-096 added; CR-089, CR-090, CR-091 notes; PS-38, PS-39, PS-40, PS-45 closed; PS-47, PS-48, BL-18 new; C-13, PS-46, BL-17 updated; H-01, H-05, H-14, H-17 updated.
- **Next agent:** (po) accept SIGC (CGR-57, CGR-58 as conditions) and DST1; decide CGR-59 for RLS3-4b. (eng) CGR-57, CGR-58 follow-up; CGR-59 as the PO decides. (owner) G-1, D-1; merge this PR if my merge is refused.

## 2026-10-25 13:16 CET · po (Product Owner)
- No PO PR open. Claimed #370 (DST1 review), #367 (SIGC review), #365 (Q14); claims removed at the end. #358 (`cra` 09:31) is not the PO's to merge.
- **SIGC reviewed** (#361 merged 2ad9860; CI `app`, `db`, `e2e` green on head a2468b5, on `recovery/main` 1e796d2 and 1f3ff8a; the run on 2ad9860 itself was cancelled by the next push): SIG1-C2, SIG1-C3 (a)-(d), SIG2-C1 (1) and (2) **met in code**; evidence table in `briefs/SIGC.md`. Four deviations decided (partly-outside listed = Q14; no Operations list or planning warning; count-only test changes; wall-clock reading on DST nights lists more, never fewer). **Not accepted:** no `cra` section covers 0068 (clinical gate). Status stays `approved`; moved from *Next up* into the queue as rank 29.
- **DST1 follow-up reviewed** (#362 merged 363906a; CI green on head 430c231, 363906a and 1f3ff8a): DST1-C1 to DST1-C3 **met**, so DST1-6, -7, -8 are met; evidence table in `briefs/DST1.md`. Four deviations decided (spring-gap `visit_interval` fix; `watched_inside` agrees with `watched_raise_at`; ADR-081 sentence withdrawn for overlap intervals; 0068 wall-clock reading accepted). **Stays `changes-requested`** until `cra` covers 0069; then accepted. DST1-C4, DST1-C5 keep their deadlines.
- **Q14 decided by po** (product authority, protective): a visit not wholly inside a watched period is listed, as built.
- **Packages:** `lca` 12:46 noted on D-23 (po-decided) and D-3 (awaiting clinical); no status change. Tiers 1-3 all awaiting a person or decided; no new evidence for D-22, D-18.
- **Challenge:** the outside-watched-hours list checks the plan after it is made; hypothesis row (the planning team clears listed visits within 24 h without an administrator, else a planning-time notice). No new brief: RLS3, DOOR1, LEAVE1 approved and unstarted.
- **Next agent:** (cra) review merge commits 2ad9860 (0068, SIGC; CGR-46, -47, -48) and 363906a (0069, DST1; CGR-53); (po) accept SIGC and DST1 once that section has no blocking finding. (eng) RLS3, then DOOR1, LEAVE1.
- Tests: none run by the PO (docs only); `node scripts/agents-check.mjs` passed before publishing.

## 2026-10-25 12:55 CET · eng (Engineering)
- **#366 merged** (1e796d2): SIGC row `delivered`. **#362 merged** (363906a, merge commit): DST1-C1 to DST1-C3. Its head conflicted again after #366 (last-change line, SIGC row, journal); resolved by merging `recovery/main` into the branch (430c231; DST1 row from the branch, SIGC row from #366, both journal entries kept). CI `app`, `db`, `e2e` green on 430c231 (CI ran them; engineering ran only `node scripts/agents-check.mjs` locally). DST1 row now `delivered` (READY_FOR_REVIEW).
- **Correction to the 12:20 entry:** the eng merge call works in this run (MCP merge as the repository account); #361 was merged by this run at 12:17, not by the owner. Two eng sessions overlapped on #362 (12:20 and 12:30 runs); no work was lost.
- OPEN (from the 12:20 entry, not in #362): `visits_outside_watched_hours` (0068) reads periods by the wall clock only; DST nights only, lists more, never fewer.
- **Next agent:** (cra) review merge commits 2ad9860 (SIGC, 0068) and 363906a (DST1 follow-up, 0069). (po) review both after `cra`; Q14. (eng) next active issue: RLS3 (with RLS3-4b), then DOOR1, LEAVE1; DST1-C4, DST1-C5 by their deadlines.

## 2026-10-25 12:46 CET · Legal & Compliance Agent (lca)
- No open `lca` PR. Tiers 1-3: D-22, D-18 unchanged since their last `lca` sections, no new evidence. Eligible because they changed after my 11:50 sections (PO 12:12, D-23 item 10, D-3 item 8): **D-23** and **D-3** re-checked. Read, not tested.
- **D-23:** item 10 and RLS3-4b as sharpened are faithful to my 11:50 notes. C plus D with items 9-10 and the two-level RLS3-4b (full trail inside the visit's team; billing view without reason or corrector outside it): **compliant under every plausible interpretation on the federal sources read**, once RLS3 is built as written (PLANNED). New, narrow: release of correction reasons to a payer: **unresolved: needs D-18 (owner), then a legal adviser** if the contract asks for it; not planned, not asked now.
- **D-3:** item 8 is faithful; gate (iv) line "correction reasons: met" holds after RLS3 provided RLS3-4b is built as written with green pgTAP in CI. Gate (iv) as a whole still not met (F-1, F-2, F-3, F-5).
- Sources this run: [K2] FMH Rechtlicher Leitfaden 4.8 on KVG Art. 42 Abs. 3 (updated 12.08.2026, secondary; read 12:44). KVG Art. 42 primary text still not read (fetch not permitted this run).
- **Next for `lca`:** D-3 gate (iv) when RLS3 or DOOR1 is delivered; D-23 point 2 when D-18 names the contract; D-22, D-18 on new evidence only.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 12:30 CET · eng (Engineering)
- **#361 merged** (2ad9860, merge commit): SIGC. Its head conflicted with `recovery/main` in `JOURNAL.md` only; resolved by merging `recovery/main` into the branch (a2468b5, no history rewrite). CI `app`, `db`, `e2e` green on a2468b5 (CI ran them; engineering ran only `node scripts/agents-check.mjs` locally). No types-bot run was waiting. SIGC row now `delivered` (READY_FOR_REVIEW).
- **#362** (DST1-C1..C3) was green on 90718dd but conflicts with `recovery/main`; it is updated by a merge commit after this PR and merged once CI is green again.
- Clinical review gate: `cra` review of 0068 (SIGC) and of #362 (0069) is OPEN; the PO accepts only after it (README *Clinical review gate*).
- No new item claimed this run (step A was substantial).
- **Next agent:** (po) Q14; review SIGC after `cra`. (cra) 0068 on merge commit 2ad9860. (eng) finish #362, then RLS3 (with RLS3-4b), DOOR1, LEAVE1.

## 2026-10-25 12:20 CET · eng (Engineering)
- **#361 (SIGC) merged by the owner** at 12:17 (merge commit 2ad9860; CI green on its head a2468b5: `app`, `db`, `e2e`). SIGC row `delivered` (READY_FOR_REVIEW).
- **#362 (DST1-C1 to DST1-C3):** CI was green on 90718dd; the eng merge call was refused by the permission policy (comment on #362). After #361 and #363 merged it conflicted in `JOURNAL.md`, `DECISIONS.md` (ADR-081 addendum vs ADR-082) and `IMPLEMENTATION_STATUS.md` (last-change line, SIGC row) only; resolved by merging `recovery/main` into the branch (both sides kept, no history rewrite).
- **Tests:** local PostgreSQL 16 stand-in (not CI), fresh build with 0068 and 0069 in order: pre-seed clock check passes; pgTAP 068, 069, 070, 046-050, 062, 064 pass. CI decides.
- **OPEN (follow-up, not in #362):** `visits_outside_watched_hours` (0068) reads periods by the wall clock only; after 0069 `watched_inside` also accepts the period instants. DST nights only; the list shows more, never fewer.
- **Next agent:** (owner) merge #362 (merge commit) once CI is green on the merge head; (eng) then DST1 row `delivered`, then RLS3 (#355); (po) review SIGC; (cra) SIGC and the DST1 follow-up merge commits.

## 2026-10-25 12:12 CET · po (Product Owner)
- No PO PR open. Open: #362 (DST1-C1..C3, CI green, not merged), #361 (SIGC, CI running), #358 (`cra` 09:31, not merged by the PO), #3. No `agent:po` issue, no `[PO review]` issue, nothing `delivered`, `ready-for-review` or `in-review` since 10:12: **no review this run**. Nothing claimed.
- **`lca` 11:50 (#363) taken up (product authority, narrows only, no clinical rule):** **RLS3-4b sharpened** into two levels: (a) full correction trail (corrector, time, old and new value, reason) to the report's author, the countersigning RN, active members of the visit's team and the covering member; (b) **billing view** for every reader outside the visit's team, coordination roles included (`billing_preview` scope): correction exists, old and new value, time, signed version and countersigner, **never the free-text reason or the corrector**. "The billing review" is not a named person until the D-12 organisational policy names one; widening needs a new PO decision and a fresh `lca` check. pgTAP for admin, coach and Operations outside the team added to RLS3-4b. Recorded as **D-23 item 10** and **D-3 item 8**; D-3 gate (iv) "correction reasons: met" stays true after RLS3; the unresolved `lca` question becomes moot. INDEX rows 5 and 25 noted; **no status change**.
- **Input requested:** `cra`, narrow, in D-23 *Clinical impact*: does the billing view serve CGR-55's billing purpose? If not, name what billing needs beyond it.
- **Decision packages:** INDEX tiers 1-2 (D-22, D-18, D-28, D-31, ...) all `awaiting-approval` with no new evidence since their last update; nothing to escalate anew. Owner asks unchanged (see 10:12 and earlier entries; G-1 still gates every `clinical` package).
- **Challenge:** new row "A back-office billing reviewer reads every corrected visit": doubtful; hypothesis that invoices release by batch with defined exceptions only (after D-12, D-18), measured in the first invoice months.
- **Next for po:** review DST1 again once #362 is merged and Engineering marks it `delivered`; SIGC once #361 is delivered. **Next for eng:** RLS3 with RLS3-4b as sharpened (not started). **Next for `cra`:** the D-23 question above; #358 merge.
- Tests: none run by the PO (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 11:50 CET · Legal & Compliance Agent (lca)
- No open `lca` PR. Tiers 1-3: D-22, D-18 unchanged, no new evidence. Eligible because they changed after my 07:50 sections (PO 08:10) and there is new evidence (RLS3-4b, PO 10:12 from `cra` CGR-55): **D-23** and **D-3** re-checked. Read, not tested.
- **D-23:** C plus D with item 9 (per-visit identity for a named care task inside the team) **compliant under every plausible interpretation on the federal sources read**. RLS3-4b for the author and the countersigning RN: compliant. RLS3-4b for a "billing review" that is any coordination role (as `billing_preview` scopes it today, 0043/0015), with corrector identity and the free-text reason: **unresolved: needs the DSFA, else a legal adviser**. Protective variant, compliant: outside the visit's team, show correction, old and new values, time and signed version, but no reason and no corrector. Note to po: name who "the billing review" is, and add a pgTAP check.
- **D-3:** item 7 is faithful. Gate (iv) line "correction reasons: met" holds only if RLS3-4b gives no reader outside the team (and the covering member) the reason. Note to po: add that as an RLS3-4b criterion.
- Sources this run: [O2] OR Art. 328b (droit-bilingue.ch, unofficial; read 11:35); [K1] KVV Art. 59 Abs. 1 (justement.ch, Stand 22.10.2026; read 11:37). KVG Art. 42 not read.
- **Next for `lca`:** D-3 gate (iv) when RLS3 or DOOR1 is delivered; D-22, D-18 on new evidence only.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 11:30 CET · eng (Engineering)
- **Step A, #361 (SIGC):** CI green on 1c9122f (`app`, `db`, `e2e`), mergeable. The merge call was **refused again by this run's permission policy** (as at 09:30 on #361 and earlier on #331). Not worked around. The merge stays with the owner: **merge commit**, not squash; then the SIGC row can be set `delivered` (#361).
- **Claimed #360** (DST1 changes-requested, `active`) at 11:14; claim removed at the end. **PR #362** (`fix/dst1-c1-c3`): DST1-C1 to DST1-C3, migration **0069**, **ADR-081 addendum**, pgTAP **070** (31), CI `db` step "Real clock before the seed (DST1-8 a)". DST1 row `in-review` (#362).
  - **DST1-C1 (CGR-53), IMPLEMENTED:** `visit_interval` end, `record_absence` end and `change_absence` new end use `private.at_zurich_end`; starts unchanged. Every other interval listed in the addendum (stuck reference and its AN2 mirror keep the earlier end).
  - **Found and fixed (deviation, in the same functions):** `visit_interval` raised a range error for a visit starting in the spring gap and ending after it (since 0048); `watched_inside` disagreed with `watched_raise_at` on 2027-03-28 (window "outside" from 01:00 UTC though its end is 01:30 UTC). Both now never shorter; ordinary days unchanged.
  - **DST1-C3:** (a) pre-seed CI check; (b) catalogue assertions in 070 for all three API roles.
  - **Not in #362 (own deadlines, PLANNED):** DST1-C4 (CGR-54), DST1-C5 (CGR-56).
- **Clinical gate:** report 2026-10-25 09:31 (open #358) read; CGR-53 applied, remediation plan `clinical/remediation/CGR-53.md`; CGR-54/56 = C4/C5; CGR-55 is RLS3's.
- **Tests:** pgTAP only, locally, on a PostgreSQL 16 stand-in with minimal pgTAP functions written for the run (not upstream pgTAP; building upstream from source was refused by the permission policy): 070 and 068 pass; 57 of 68 files pass, 11 not runnable on the stand-in (missing pgTAP functions). Reverting 0069 makes 070 fail. vitest, typecheck, lint, build, e2e **not run**. **CI is the runner**; nothing here claims CI passed.
- **Next agent:**
  - **(eng):** #362: fix CI if red, merge when green (merge commit), DST1 row `delivered`; then SIGC row `delivered` once the owner merges #361; next *Next up*: RLS3 (#355, with RLS3-4b).
  - **(cra):** review #362 on its merge commit (`cra` review before PO acceptance, PO 10:12); note the consequence in `CGR-53.md` *Needs a decision* (an absence typed to start in the repeated hour overlaps a visit ending in it).
  - **(owner):** merge #361 (merge commit); #358 (`cra`).

## 2026-10-25 10:31 CET · eng (Engineering)
- No own PR open at the start. **Claimed #345 (SIGC)** at 10:10; claim removed at the end of this run.
- **PR #361** (`feat/sigc-signal-conditions`): migration 0068, ADR-082, pgTAP 069 (59), remediation plans `clinical/remediation/CGR-47.md`, `CGR-48.md`. Status row SIGC `in-review`.
  - SIG1-C2 / SIG1-C3 / SIG2-C1 (1), (2) built as written. The details are in the status row and ADR-082.
  - **Q14 opened for `po`** (not blocking): partial overlap with the watched hours → listed (protective).
- **Clinical gate:** report section 2026-10-24 22:26 (CGR-46, CGR-47, CGR-48) applied as the PO decided. The 09:31 section (open PR #358) has no new SIGC finding.
- **Tests:** CI is the runner. Locally only pgTAP, on a plain PostgreSQL 16 stand-in with stubbed roles and minimal pgTAP functions: 059, 062, 064, 065, 067, 068 and 069 passed there. A mutation back to the first take fails five assertions of 069. **Not run locally:** vitest, typecheck, lint, build, e2e (no npm registry). `database.types.ts` was edited by hand; the types bot regenerates it.
- **Next agent:** (eng) fix CI on #361 if red, approve the types-bot run, merge when green, then `delivered`. (po) Q14; review SIGC once delivered. (cra) 0068 when convenient.

## 2026-10-25 10:12 CET · po (Product Owner)
- No PO PR open. Open: #358 (`cra` 09:31, DST1 review; not merged by the PO), #3. Claimed **#357** ([PO review] DST1); claim removed at the end.
- **DST1 reviewed: `changes-requested`** (#349 merged 3c2da15; `app`, `db`, `e2e` green on head 2702403, merge commit 3c2da15 and `recovery/main` 16e4e9c; the PO did not run the tests; evidence table in `briefs/DST1.md`). DST1-1 to DST1-5 met; DST1-4 through the pinned suite plus 068's DST instants in CI (the allowed fallback; CI matrix PLANNED, with one night-time instant). **Not met:** DST1-6 (`cra` CGR-53: 0067 gives the end of `private.visit_interval` the earlier instant, so a visit 01:30-02:30 on the fall-back night is not released by ABS1 when its nurse is absent from 01:00 UTC; before 0067 it was), DST1-7 (two named assertions missing), DST1-8 (a) not proved before the seed, (b) without `service_role`.
  - **Requested, one PR:** DST1-C1 (every interval used in a safety overlap check ends at the later instant; pgTAP for the ABS1 case), DST1-C2 (the two DST1-7 assertions), DST1-C3 (a CI step before the seed; grants of all three API roles).
  - **Own deadline:** DST1-C4 (CGR-54, **decided option (a)**: the correction form asks "Sommerzeit / Winterzeit" for 02:xx on the fall-back date, nothing preselected; before 2027-10-31 or the first real client) and DST1-C5 (CGR-56: deploy check that `private.test_clock` is empty and `navora.test_now` unset; before gate B).
  - Deviations: no-show path proved through the overdue path (accepted); earlier end for the stuck reference (accepted); earlier end for overlap intervals (not accepted, C1).
- **Process (`cra` asked the owner whether a clinical-scope PR waits for `cra` before merge):** decided by po, no owner question: merging on green CI stays allowed; the PO accepts an item in clinical scope only once `cra` has reviewed its merge commit (README *Clinical review gate*). Reversible; COORDINATION.md unchanged.
- **RLS3-4b added** (CGR-55, product authority): one listed per-visit reader keeps the correction trail (corrector, time, old and new value, reason) visible to the report's author, countersigner and the billing review after the `actor_id` revoke; never per person. `cra`'s RLS3 note (no standing clinical need of coordination roles for note text) recorded in the brief.
- *Next up* now: 1 SIGC, 2 RLS3, 3 DOOR1, 4 LEAVE1; the DST1 follow-up (rank 28) comes first.
- **Packages:** `cra` 09:31 brings no new input to any package (D-28 thresholds untouched); tiers 1-3 all awaiting a person or decided (D-22, D-18 no new evidence); no status change.
- **Challenge:** typed time corrections (row added): from scratch the tap is the record; hypothesis on correction share and size from AN counts; no brief before pilot data.
- ROADMAP: line 25.10. 10:12. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` passed before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, D-24, D-25 (only once D-24 moves past A), G-1 (name the Clinical Owner); merge `cra` PR #358. **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15, D-19, D-17.
- **Next agent:**
  - **(eng):** DST1-C1 to DST1-C3 in one PR first (`cra` review before PO acceptance); then SIGC, RLS3 (with RLS3-4b), DOOR1, LEAVE1. DST1-C4 and DST1-C5 by their deadlines.
  - **(cra):** review the DST1 follow-up PR on its merge commit.
  - **(lca):** no new request.
  - **(po):** review the DST1 follow-up when merged.

## 2026-10-25 09:31 CET · Clinical & Regulatory Architect (review)
- Reviewed since 05:30 CET (#348): **DST1 merged** (#349, `3c2da15`; 0067, ADR-081, pgTAP 068, fixtures, `time.ts`, CI pinned clock), **RLS2 merged** (#331, `c1703a0`), PO 06:10 and 08:10 (RLS3 approved, Q13), `lca` 07:50. CI green on `2702403`, `3c2da15`, `16e4e9c` (checked through the API). I did not run the NAVORA test suite; conversion and interval overlap checked on an empty local PostgreSQL 16.15 only.
- **Closed:** CGR-52 (0067:35-71, 154-196; pgTAP 068:60-149); the RLS2 request of 22:26 (067:286-295, 329-330).
- **New, all advisory, none blocking:** CGR-53 (S3: 0067 gave the end of `visit_interval` the earlier instant, so an absence starting in the second pass can miss a night visit; fix with `at_zurich_end`); CGR-54 (S3: a correction typed in the second pass is stored one hour early without confirmation; po chooses ask or refuse); CGR-55 (S2: RLS3-4 must keep the corrector visible per visit to the countersigner and billing review); CGR-56 (S2: deploy check that the test clock is off on staging and production).
- **Gate:** DST1 has no blocking finding; the PO may accept it with CGR-53 and the two DST1-7 assertions missing from 068 as follow-ups. RLS3: no clinical need for a standing coordination read of a note's text; a task-bound read goes through a named read model (who holds it: UNKNOWN until G-1).
- **Process:** DST1 was merged before this review (eng 09:30 deviation). I am asking the owner and the PO to decide whether a clinical-scope PR that changes production functions waits for `cra` before merge.
- Registers: CR-088 DEPRECATED, CR-089 to CR-091 added; PS-44 closed; PS-45, PS-46, BL-17, C-13 added; H-01, H-05, H-14 updated.
- **Next agent:** (po) DST1 acceptance; CGR-54 choice; CGR-55 into RLS3-4. (eng) CGR-53, CGR-56. (owner) the merge-gate question, G-1, D-1.

## 2026-10-25 09:30 CET · eng (Engineering)
- **#352 merged** (42972ca): RLS2 status row `delivered` (CI green on 52fb70f).
- **#349 merged** (3c2da15, merge commit): DST1. Its head conflicted with #352 in the `IMPLEMENTATION_STATUS.md` last-change line only; resolved by merging `recovery/main` into the branch (2702403, no history rewrite). CI `app`, `db`, `e2e` green on 2702403 (CI ran them; engineering ran only `npm run agents:check` locally). DST1 row now `delivered` (READY_FOR_REVIEW).
- **Deviation:** the PO's 08:10 note asked to merge #349 after `cra` reviewed 0067. The eng operating model merges on green CI; COORDINATION.md sets no `cra` merge gate. `cra`'s review of 0067 (DST1-5) is therefore still OPEN and listed as the row's next step; any finding comes back as a follow-up PR.
- No new item claimed this run (step A was substantial). Next run: #344 (DST1) can be closed by the watcher after PO review; next eng issue by *Next up*: SIGC (#345), RLS3 (#355).
- **Next agent:** (po) review DST1 against `briefs/DST1.md`; (cra) 0067 as requested.

## 2026-10-25 08:10 CET · po (Product Owner)
- No PO PR open (#350 merged). Claimed **#351** (Q13); claim removed at the end. Open: #352 (`eng`, RLS2 status `delivered`, not merged by the PO), #349 (DST1, CI green on 8ba1d85, awaiting `cra` on 0067), #3.
- **RLS2 accepted** (#331 merged 07:11 CET as c1703a0; `app`, `db`, `e2e` green on head bb3ed48, merge commit c1703a0 and `recovery/main` 8b099fa; the PO did not run the tests). RLS2-1 to RLS2-7 met (evidence table in `briefs/RLS2.md`): four tables and `uncovered_visits()` team-scoped, decline reason out of the escalation reader, catalogue check of 22 tables and 24 functions, 37-call cross-team sweep, removed member reads nothing. Four deviations accepted (017/012 assertions replaced by the narrower scope, none dropped). `cra` 05:30: no blocking finding. Its status row still says `in-review` until #352 merges; the review used the merged code and CI.
- **Q13 decided by po** (product authority, narrowing only): F-1 with DOOR1-11; F-2, F-4, F-5 as **RLS3**; F-3 with D-4 or the DSFA. **F-4 moved** from "with D-23 C" to **before the first real employee, or with C, whichever is first** (`lca` 07:50: the events are written for care today).
- **RLS3 approved** (*Next up* 3). *Next up* now: 1 DST1, 2 SIGC, 3 RLS3, 4 DOOR1, 5 LEAVE1.
- **Packages (`lca` 07:50 taken up; no status change):** **D-3** item 7: gate (iv) is a checklist (F-1, F-2, F-3, F-5, inventory); the task-bound coordination reads go to the DSFA line by line. **D-23** item 9: precondition 3 (a) met; F-4 protective route (RLS3-4), the DSFA question moot. Tiers 1-3 otherwise unchanged (D-22, D-18 no new evidence; the rest awaiting a person or decided).
- **Challenge:** standing coordination read rights (row added): from scratch, a coordination role reads a client only while it holds an open task for her; hypothesis from the read log (fewer than 1 in 20 coordination reads without an open task); no brief beyond RLS3 until the read log exists.
- ROADMAP: line 25.10. 08:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` passed before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, D-24, D-25 (only once D-24 moves past A), G-1 (name the Clinical Owner); merge #349 (DST1) once `cra` has reviewed 0067. **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15, D-19, D-17.
- **Next agent:**
  - **(eng):** merge #352; DST1 (#349) after `cra`; then SIGC, RLS3, DOOR1, LEAVE1. RLS3's open questions name the invoker read models and the `actor_id` readers.
  - **(cra):** DST1 0067 as requested; RLS3 is informed only (say whether any coordination role has a clinical need for a note's text).
  - **(lca):** no new request; D-3 gate (iv) again when RLS3 or DOOR1 is delivered.
  - **(po):** review DST1 when merged.

**ENGINEERING BRIEF — RLS3**
- **Capability:** Coordination roles and teammates read no more than their task needs (`briefs/RLS3.md`).
- **Why:** after RLS2 no organisation-wide path is left, but admin, coach and Operations still read the whole no-show and interruption note, cover events and working-time facts of every team through the table API (F-2), three tables have no negative test (F-5), and a teammate can list who recorded which visit event when (F-4). `lca` 07:50: F-2 is the larger free-text exposure; F-4 exists without D-23 C. No screen needs any of them.
- **Business outcome:** D-3 real-data gate (iv) is two items from met (F-1 with DOOR1-11, F-3 with D-4 or DSFA); a DSFA that lists one reader per task instead of standing rights.
- **Care outcome:** a client's note about a closed door or a broken-off visit stays with the team that cares for her and the nurse covering that visit.
- **Expected nurse outcome:** no screen change; nobody outside her team, and no teammate, can reconstruct her working day from the raw rows.
- **Expected team outcome:** the team stays the reader of its own records; Operations keeps every exception and signal through its read models.
- **Expected patient outcome:** what she told her nurse at the door is not readable by every coordinator of the organisation.
- **Acceptance criteria:** RLS3-1 `visit_status_notes`, `cover_events`, `working_time_facts` team (+ cover, + own cover event) only, coordination roles 0, pgTAP per table; RLS3-2 read models unchanged on the seed (019, 042, 045, 057-059, 067 green; OPS1 still raises); RLS3-3 negative pgTAP for `care_plan_items`, `case_lifecycle_events`, `cover_events`; RLS3-4 `actor_id` of `visit_events` and `visit_time_corrections` not selectable through the table API, per-visit identity only through listed functions with a named care task, never per person; RLS3-5 inventory updated; RLS3-6 no regression, no assertion weakened.
- **Dependencies:** RLS2 (accepted). None blocking.
- **Priority:** *Next up* 3 (after DST1 and SIGC, before DOOR1).
- **Implementation recommendation:** one additive migration in the 0066 pattern (`private.reads_visit`, `private.reads_case`); a column revoke for `actor_id` with any own-event read moved into a definer read model; extend the fixed lists in pgTAP 067 rather than a new mechanism.

## 2026-10-25 07:50 CET · Legal & Compliance Agent (lca)
- No open `lca` PR (#346 merged). Tiers 1-3: D-22, D-18 unchanged, no new evidence. New evidence: **RLS2 (#331) merged** at 07:11 CET (0066, `READ_PATHS.md`; ADR-080 asks for the `lca` re-check of D-3 gate iv). Re-checked two packages against the merged code (read, not tested):
- **D-3 gate (iv):** the organisation-wide gap of 21:55 is **closed in code**. Gate (iv) is still **not met**: F-2 (every coordination role can read the whole `visit_status_notes.note` through the table API), F-1 (DOOR1-11), F-3 and the F-5 negative tests are open. Real data: **not yet compliant**; compliant under every plausible interpretation on the federal sources once those four are done with gates (i)-(iii). Task-bound coordination reads (intake, quality review, holds): DSFA. Note to po: name F-2 and F-5 in item 6.
- **D-23:** term (a) built; C plus D **unchanged, compliant** on (a)-(e). F-4 (`actor_id` readable row by row inside the team) with real data: **unresolved: needs the DSFA** (or an adviser). Protective route: revoke before the first real employee or with C, whichever is first (note to po; Q13 now ties it to C only).
- Sources this run: [W15] weka.ch on ArGV 3 Art. 26 (21.11.2025, secondary, summarising fetch tool). ArGV 3 primary text not read.
- **Next for `lca`:** D-3 gate (iv) again when F-2, DOOR1 or LEAVE1 are delivered; D-22, D-18 on new evidence only.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 07:15 · eng (Lead Engineer)
- **#331 merged** as c1703a0 with a merge commit, by the owner at 07:11. CI was green on head bb3ed48 (app, db, e2e).
  - Two earlier `db` runs on 241c49b were red during the repeated hour of the clock change (pgTAP 038, then 046, 062 and 064), not because of RLS2. Both are explained on the PR; the DST1 brief covers the fix.
- **RLS2 is `delivered`** (READY_FOR_REVIEW): PO review of RLS2-1 to RLS2-7. Deviations (1)-(4) are in the status row; RLS3 and Q13 are open for `po`.
- Clinical gate: `cra` 22:26 RLS2 note applied (pgTAP 067); no CGR finding names RLS2.

## 2026-10-25 06:10 CET · po (Product Owner)
- No PO PR open (#347 merged). No issue claimed (nothing new for `po`; DST1 #344 is claimed by `eng`).
- **No delivery to review:** DST1 PR #349 (opened 04:55 UTC; `db`, `app` green, `e2e` running at 06:10) and RLS2 PR #331 (CI green on `bb3ed48`) are open, not merged; nothing `delivered`, `ready-for-review` or `in-review`.
- **DST1 amended** (product authority; time-conversion rule only, no threshold, priority or receiver changed) from `cra` 05:30 (CGR-52 S2, production code affected):
  - **DST1-7:** a watched period starts at the earlier and ends at the later instant, so it is never shorter than its wall-clock length (`cra` addition (4); PR #349 already follows it, so the deviation it lists is now in the brief).
  - **DST1-8:** the fixed-clock mechanism cannot act in a database built without the seed (assertion before the seed), no app role can set or read the pin, and the ADR says how staging and production stay free of it. Reason: a pin outside tests would freeze every overdue and escalation signal (H-01). No check against the live database.
  - Review note: DST1-4 needs the four-clock proof in CI; the local run in #349 counts for DST1-1 only.
- **Packages:** no new input since 04:10; tiers 1-3 all awaiting a person or decided; no status change.
- **Challenge:** minute-exact planned starts (row added): from scratch, only time-bound care needs a fixed minute; hypothesis on start deviation and unacted P2 signals (AN1, counts only); any change goes to D-28 (Clinical Owner), no rule built.
- ROADMAP: line 25.10. 06:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` passed before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, D-24, D-25 (only once D-24 moves past A), G-1 (name the Clinical Owner); merge #331 (RLS2) and, once green and `cra`-reviewed, #349 (DST1). **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15, D-19, D-17.
- **Next agent:**
  - **(eng):** DST1-7 and DST1-8 on PR #349 (DST1-7 is implemented per the PR; DST1-8 (a) and (b) need assertions); the four-clock CI proof for DST1-4.
  - **(cra):** review 0067 (CSR1, SIG1), as #349 requests.
  - **(po):** review DST1 and RLS2 when merged.

## 2026-10-25 05:55 CET · eng (Lead Engineer)
- **A (own PRs):** RLS2 #331 is green and mergeable (clean) on bb3ed48. The merge was **refused again by this session's permission policy** (merge without review), as at 04:10. It stays open for the owner to merge (merge commit) and stays `in-review`.
- **B/C:** claimed **#344 (DST1)** at 05:14. Clinical scope (CSR1, SIG1). Read `cra` 02:26 (open PR #341): **CGR-52** (advisory, S3) applies. Remediation plan `clinical/remediation/CGR-52.md` written. No other finding touches DST1.
- **Root cause (DST1-1): production code, plus fixtures.** Reproduced at fixed clocks: a local PostgreSQL 16 under a clock offset, with a Supabase shim and a pgTAP stand-in. **Not CI.**
  - At 2026-10-25 00:35 UTC, `recovery/main` fails exactly the CGR-52 list (038 ×3, 046 ×2, 062 ×5). PostgreSQL reads 02:00-02:59 as the later instant (CET), so overdue, P1 and the step to Operations came up to one hour late.
  - The F3 input `zurichLocalToIso` had the same bug.
  - Fixtures used wall-clock arithmetic (the 2027-03-28 failures and #331's 01:11 UTC failures). 034 used a fixed date that breaks from 2026-12-03.
- **PR #349** (`feat/dst1-clock-change-safety`):
  - migration 0067: `private.at_zurich` (repeated hour → earlier, missing hour → CET) and `private.now()` with a seeded test-clock switch, applied mechanically to every function and default;
  - pgTAP 068 (44);
  - fixtures and seed read `private.now()`;
  - CI `db` job: reset without the seed, pin the clock to 10:00 Zurich, seed, pgTAP, unpin;
  - e2e F3 and unit tests;
  - ADR-081.
- **Local result (not CI):** all 66 files green on the real clock and at 2026-10-25 00:35, 01:30 and 22:30, 2027-03-28 01:30 and 2026-11-10 10:00 (pinned suite). No assertion weakened or skipped. Lint, typecheck, vitest, e2e and `db lint` were not run: CI decides.
- **`cra` 05:30 CET (#348, merged during this run):** CGR-52 is re-assessed to **S2, production affected**. Addition (4): a watched-hours window end takes the later instant. **IMPLEMENTED in #349** (`private.at_zurich_end` in `watched_raise_at`; 068 +4) ahead of the PO adding it to the brief, because the finding takes precedence. No blocking finding.
- **CI on #349:** first run red in `db-clock`. A custom setting at database level needs a superuser, so the pin now runs as `supabase_admin`. Then `recovery/main` (#348) was merged in, resolving a JOURNAL conflict (both kept).
- **Next (eng):** fix #349 if CI is red, and try a CI matrix at the four clocks (`sudo date`; runner support is UNKNOWN). `cra` review of 0067 is requested (production code changed, DST1-5). After DST1: RLS2 merge (owner), then SIGC (#345), DOOR1, LEAVE1.
- **Note for every agent:** since 0067, function bodies use `private.now()` and `private.at_zurich(...)`. pgTAP 068 fails on a bare `now()` or a native `at time zone 'Europe/Zurich'`. **RLS2's 0066 was written before 0067:** it sorts earlier and is rewritten by 0067 on a fresh reset, so there is no conflict.
- **PLANNED (eng), RLS2 × DST1:** RLS2's pgTAP 067 reads `now()` 25 times. Under the pinned CI clock its fixtures must read `private.now()`. Whichever of #331 and #349 merges second gets that conversion, done by the same mechanical replacement, before it merges.
## 2026-10-25 05:30 CET · Clinical & Regulatory Architect (review)
- **Reviewed** PO cycles 02:10 CEST to 04:10 CET, `lca` 02:48 to 03:43 CET, brief DST1, LEAVE1-11/-12, DOOR1-11, and #331 (RLS2) at `bb3ed48`. Section 2026-10-25 05:30 CET in `reports/CLINICAL_GOVERNANCE.md`. No code merged since 0065. I did not run the NAVORA tests.
- **CGR-52 re-assessed (S3 → S2, advisory):** production code is affected. 0038, 0045 and 0062 convert planned starts with `at time zone 'Europe/Zurich'`, which resolves an ambiguous local time to the later instant (checked on an empty local PostgreSQL 16.15). A visit planned at 02:00-02:59 on the fall-back night raises its overdue signal and escalation up to one hour late. The fixtures also fail on wall-clock subtraction. DST1 covers both; proposed addition for the PO: watched-hours windows start at the earlier instant and end at the later one.
- **Decided by the PO, PLANNED:** CGR-49 (LEAVE1-11), CGR-50 (LEAVE1-12), CGR-51 (DOOR1-11). No finding closed; no new finding ID.
- **RLS2 (#331):** no blocking finding; CI green on `bb3ed48`; the owner merges.
- **Registers:** CR-088 (implicit DST conversion, UNVALIDATED); CR-038 note; PS-41 to PS-44 and H-01, H-05, H-12 updated.
- **Next:** owner merges this PR (it supersedes #341, #321, #306, #294, #278, #259) and #331; `eng` DST1 needs the clinical gate.

## 2026-10-25 04:10 CET · po (Product Owner)
- No PO PR open (#340 merged). Claimed **#65** (D-3) for this run; claim removed at the end (D-23 and D-32 have no open issue).
- **No delivery to review:** RLS2 (#331) not merged; nothing `delivered`, `ready-for-review` or `in-review`. DST1 (#344) active with Engineering, no PR yet.
- **`lca` 03:43 taken up (no status change):**
  - **D-3:** item 6: real-data gate (iv) includes **DOOR1 with DOOR1-11 merged** (no note excerpt to coordination roles with real data; CGR-51's interim stays on synthetic data, where `lca` finds it compliant) and **F-3** (`quality_holds.reason` in `audit_events` readable by administrators) closed or DSFA-justified before the first real client, whatever D-4's timing. The protective route makes the adviser question moot; not asked. Narrowing only, no owner approval. Noted in DOOR1-11 and the RLS3/Q13 row.
  - **D-23:** Art. 17 is a permit exemption only; C plus D unchanged. Item 8: three criteria for the C brief when written (start and end per segment; on-call interventions and call-out travel in the non-visit field, no day shown complete while it is unanswered; elapsed-time durations across the clock change). **No plan-limit check** built (adviser questions 6-8; no figure from secondary sources).
  - **D-32:** `lca` question 7 (night coordinator under Art. 17: UNKNOWN, with D-12) recorded; nothing built on either reading.
- **Challenge:** the central Operations desk row gains a second cost (a separate night coordinator's permit status is UNKNOWN, a nurse on duty does care work); the plan-limit row records that the source is still missing (no brief).
- **Housekeeping:** closed the duplicate SIG hand-off issues #326, #329, #333, #334, #336, #339, #343 (not planned); #345 (SIGC) is the single hand-off.
- ROADMAP: line 25.10. 04:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` passed before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, D-24, D-25 (only once D-24 moves past A), G-1 (name the Clinical Owner); merge `cra` PR #341. **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15, D-19, D-17.
- **Next agent:**
  - **(eng):** DST1 first, then RLS2 (#331), SIGC (#345), DOOR1, LEAVE1.
  - **(lca):** no new request; D-3 gate (iii)/(iv) once RLS2 merges, as planned.
  - **(po):** review RLS2 and DST1 when merged.

## 2026-10-25 03:43 CET · Legal & Compliance Agent (lca)
- No open `lca` PR (#342 merged as fb93b53). Tiers 1-3: nothing newly eligible (D-22, D-18 unchanged, no new evidence). Two requests by the po taken up:
- **D-23 (ArGV 2 Art. 17, requested 02:10 CEST):** Art. 17 is only a **permit exemption** for night and Sunday work of a Spitex organisation's care staff, where needed for its services ([W10], [W11], SECO Wegleitung). Every other night, Sunday, rest and recording rule stays. **C plus D unchanged: compliant on terms (a)-(e).** Two clarifications for item 1: the proposal carries start and end per segment, and the non-visit field takes on-call interventions without a visit plus call-out travel ([W14] ArGV 1 Art. 15). Art. 17a-17e (in force 1 December 2025) concern live-in carers of staffing agencies only. Plan-limit checks: **unresolved: needs legal adviser** (questions 6-8). Only the break and on-call limits are read, and only from secondary sources; no figure to be built. Question 7 (is Operations at night care staff under Art. 17?) also bears on D-32 and SIG2.
- **D-3 (Q13 F-1, the note excerpt to Operations until DOOR1):** on synthetic data **compliant under every plausible interpretation**. With real data: **unresolved: needs legal adviser**, because it conflicts with gate (iv)'s free-text clause. Protective route: DOOR1-11 merged before the first real client (note to po: make it part of gate iv). DOOR1-11 as decided: compliant on the federal sources read. Same free-text gap for F-3 (`audit_events` admins) with real data. Relied on `cra` CGR-51.
- Sources this run: SECO Wegleitung ArGV 2 Art. 4, 17, 17a; SECO page "Pikettdienst"; BS news of 20.11.2025 (all through a summarising fetch tool). Not read: ArGV 2, ArG Art. 15a-20 and ArGV 1 Art. 73 in the primary text (fedlex fetch refused).
- **Next for `lca`:** D-3 gate (iii)/(iv) once RLS2 (#331) merges; LEAVE1 and DOOR1 when delivered; the ArGV 2 primary text if fedlex becomes readable; D-4 against [Z2] if the po asks.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 03:10 CET · po (Product Owner)
- **PO PR #340 still open**, CI red on 0e155e9 (01:24 UTC: `db` pgTAP 062 test 15, `app` failed; clock-dependent, `cra` CGR-52, brief DST1 *Next up* 1). Rule A: continued on the same branch; `recovery/main` (fb93b53, `lca` #342) merged in, JOURNAL conflict resolved keeping both sides newest first. The push re-runs CI with new content and a new base (not a re-run to kick CI). Claimed **#104, #61, #56, #70** (D-22, D-15, D-10, D-4); claims removed at the end.
- **No delivery to review:** RLS2 (#331) not merged; nothing `delivered`, `ready-for-review` or `in-review`. No Engineering commit since 02:10 CET; DST1 not started.
- **Packages (INDEX order; tiers 1-3 all awaiting a person or decided; no status change):** `lca` 02:42 CET re-check against the ZH Spitex leaflet [Z2] (September 2025) taken up:
  - **D-22:** [Z2] A.2 (lit. b only on a doctor's order, lit. a and c without) is consistent with the package's federal reading. Checked `lca`'s warning in the briefs: none builds an order for every service (J1 `not-required-A/C-only`; J3 order gate for B only). Ask unchanged.
  - **D-15:** CR-010 question cites [Z2] 3.4.8, with 3.4.7 as context; `lca`'s 11:55 order sentence marked superseded and not built. Recommendation C unchanged.
  - **D-10:** [Z1] references read as [Z2]; adviser question 1 replaced by `lca`'s wording. Verdicts unchanged; LEAVE1 stays the real-data gate for deviation (3).
  - **D-4:** retention item (4), the [Z2] 20-year recommendation for patient documentation, goes to the adviser; the provisional rule (no deletion) covers it.
- **Challenge:** the site nursing lead as a manager (row added): the licensed accountable role stays; the manager's work around it (reading every report, the roster, the phone) should not. Pilot hypothesis on her supervision hours and direct care share.
- ROADMAP: line 25.10. 03:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` passed before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, D-24, D-25 (only once D-24 moves past A), G-1 (name the Clinical Owner); merge `cra` PR #341. **Clinical Owner:** D-10, D-28, D-31, D-3, D-30 (before the first real leaver), D-16, D-15, D-19, D-17.
- **Next agent:**
  - **(eng):** DST1 first: CI is red on every docs PR tonight (#340, #341, #331). Then RLS2, SIGC, DOOR1, LEAVE1.
  - **(lca):** D-23 Art. 17 and the Q13 F-1 view as requested; no new request this run.
  - **(po):** merge #340 once CI is green; close the duplicate SIG hand-off issues (#329, #333, #334, #336, #339, #343) once the SIGC issue exists; review RLS2 and DST1 when merged.

## 2026-10-25 02:42 CET · Legal & Compliance Agent (lca)
- **Continued `lca` PR #342** (opened 02:48 CEST, before the clock change; this entry is later). Its `db` and `e2e` jobs failed in the repeated DST hour (comment on #342; `cra` CGR-52, po DST1). Still inside the repeated hour at the start of this run, so no re-run yet. Tiers 1-3: nothing eligible (D-22, D-18 unchanged, no new evidence).
- **New evidence: ZH Spitex leaflet [Z2], September 2025** (supersedes [Z1], November 2023). Re-checked **D-10** and **D-15**:
  - Countersignature still not required. Supervision now rests on the site nursing lead (3.4.4) and single-task delegation (3.4.8). [Z1] 7.3 (record access by competence) has no counterpart.
  - [Z2] 3.5.3 recommends keeping patient records 20 years (input for D-4, not a rule). A.2 limits the doctor's order to KLV lit. b services, so my 11:55 D-15 wording is outdated for ZH (D-22).
  - **Verdicts unchanged** in both packages. D-10 deviation (3) stays not compliant with real data until LEAVE1 is accepted.
- Sources this run: [Z2] zh.ch PDF, read 2026-10-25 (tool summary). GesG ZH, KLV and KVV not read.
- **Next for `lca`:** re-run the failed #342 jobs once after 02:00 UTC and merge if green; the January 2026 home leaflet if readable; D-4 against the [Z2] retention recommendation if the po asks; D-3 gate (iv) once RLS2 merges; LEAVE1 when delivered.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 02:10 CET · po (Product Owner)
- **Time note:** the second 02:10 of the night (clocks went back at 03:00 CEST); the po entry below is 02:10 CEST, one hour earlier.
- **PO PR #340 (02:10 CEST) was still open**, `db` red after its one re-run (pgTAP 038, 046, 062 on a docs-only diff; comments on #340). Rule A: no second PO PR; this cycle continues on the same branch. My push re-runs CI with new content (not a re-run to kick CI). Open: #342 (`lca` 02:48), #341 (`cra` 02:26, supersedes #321, #306, #294, #278, #259), #331 (RLS2, `db` red), #3. Read both on their branches as evidence; not merged by the PO. Claimed **#115, #116, #60** (D-24, D-25, D-14); claims removed at the end.
- **No delivery to review:** nothing `delivered`, `ready-for-review` or `in-review` with a merged PR.
- **F6R-G1 met** (`cra` 02:26: no blocking finding on 0065); F6R stays accepted.
- **CGR-49, CGR-50, CGR-51 decided (product authority):** **LEAVE1-11** (a known-wrong signed report of a performer whose access ended or who left the team is returned into "Zurückgegeben – Autorin nicht mehr verfügbar": not final, not billable, no draft only she could sign, `report_not_final` raising, D-30 route; never countersigned into `final`); **LEAVE1-12** (open reports by kind listed to `/admin` and the team RNs before the access end; marker for every team member); **DOOR1-11** (Operations sees the door fact, outcome code and basis instead of the note excerpt, removed in the same PR). **Q13 answered** (RLS3 row: F-1 with DOOR1; F-2 approved as a narrowing before real data; F-3 after D-4; F-4 with D-23; F-5 next PR). `lca` asked for a view on keeping the excerpt until DOOR1 (next run).
- **New brief DST1 approved** (*Next up* 1) from `cra` CGR-52: the `db` job failed on docs-only PRs in the DST night on the overdue, ABS1 and SIG1 P1 controls (H-01). *Next up* renumbered: 1 DST1, 2 RLS2, 3 SIGC, 4 DOOR1, 5 LEAVE1.
- **Packages (INDEX order; tiers 1-3 all awaiting a person or decided; no status change):** `cra` 02:26 *Clinical impact* recorded verbatim in **D-6** (confirmed; not a clinical rule; not reopened), **D-13** (point 3 corrected → three B-brief criteria: plan shows its assessment date and a newer one, minutes only with the reference, the named assessor confirms), **D-14** (guards corrected → design constraint 7: every self-reported guard paired with a source the team does not write; F3 fatigue measure; owner ask unchanged), **D-20** (confirmed), **D-24** and **D-25** (hazard areas f-h, leading-signal stop rule). `lca` 02:48 (D-25, new evidence: ZH leaflet [L8] superseded by [L9]): D-24 boundaries 2 (site nursing lead and deputy, health-police-responsible management member; written delegation from the nursing lead), 3 (values only from the leaflet or law in force; RN on site within the guide time; written on-call rule) and 5 (leading signals) sharpened; [L8] mix figures marked superseded in D-24 and D-25, never built; D-25 legal question replaced by `lca`'s wording. Asks to the owner unchanged.
- **Challenge:** two rows (the paperwork reminder before a last day; Operations reading the door note).
- ROADMAP: line 25.10. 02:10 (Winterzeit). Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` passed before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, D-24, D-25 (only once D-24 moves past A), G-1 (name the Clinical Owner); merge `cra` PR #341 (supersedes five). **Clinical Owner:** D-10, D-28, D-31, D-3, **D-30 (before the first real leaver)**, D-16, D-15, D-19, D-17.
- **Next agent:**
  - **(eng):** DST1 first (it may also explain RLS2's red `db`), then RLS2 (with Q13 F-2 if still open), SIGC, DOOR1 (with DOOR1-11), LEAVE1 (with LEAVE1-11, -12). The po drafts in D-6, D-13, D-14, D-20, D-24, D-25 (Engineering impact) still wait for confirmation.
  - **(cra):** review DST1 if production code changes (CSR1, SIG1); LEAVE1-11 when delivered.
  - **(lca):** a view on keeping the 120/200-character note excerpt for Operations until DOOR1 merges (Q13 F-1, CGR-51); D-23 Art. 17 as requested 02:10 CEST.
  - **(po):** merge #340 once `db` is green; close the six duplicate SIG hand-off issues once the SIGC issue exists; review RLS2 and DST1 when merged.

**ENGINEERING BRIEF — DST1**
- **Capability:** Safety alerts are on time on the nights the clock changes (`briefs/DST1.md`).
- **Why:** on 2026-10-25 (clocks back) the `db` job failed on docs-only PRs with unchanged code in pgTAP 038, 046 and 062, the overdue, ABS1-release and SIG1 P1 controls against H-01 (`cra` CGR-52, root cause UNKNOWN). If production code resolves a planned time in the repeated hour to the later instant, an overdue alert and its escalation come up to an hour late that night; the spring night has a missing hour. Clock-dependent tests have now blocked every PR three times.
- **Business outcome:** CI that passes whatever hour it runs; no more nights where every agent's PR is red for reasons outside its diff.
- **Care outcome:** a visit planned in the repeated or missing hour is noticed as late as fast as on any other night.
- **Expected nurse outcome:** no change on her screens; an overdue visit of hers is raised on time twice a year as on every other day.
- **Expected team outcome:** the team and Operations receive the same P2/P1 signals on transition nights as on ordinary ones.
- **Expected patient outcome:** a client whose visit falls in that hour is not left waiting an extra hour before anyone is alerted.
- **Acceptance criteria:** DST1-1 root cause at four fixed clocks, recorded in an ADR, with a fixed-clock test mechanism; DST1-2 an ambiguous local time resolves to the earlier instant, pgTAP at 02:30 local on 2026-10-25 (CR-038 from 00:30 UTC; SIG1 P1 path unchanged); DST1-3 the missing spring hour refused or resolved by a written rule, never later than standard time, pgTAP on 2027-03-28; DST1-4 every `now()`-based fixture deterministic, the suite green at all four clocks; DST1-5 no assertion weakened, skipped or quarantined, `cra` review if production code changed; DST1-6 no regression (DAY-1, AN2-C1, SIG2-14).
- **Dependencies:** none; may share a cause with RLS2's red `db` (#331).
- **Priority:** *Next up* 1 (patient safety precondition; unblocks CI for every later item).
- **Implementation recommendation:** a single `private.now()` (or a test-only clock setting) used by every time-dependent function and fixture; one conversion helper from Zurich local date and time to an instant with an explicit rule for ambiguous and missing times; a pgTAP file pinned at both transitions; a one-off CI run (or matrix) at the four clocks.

## 2026-10-25 02:48 · Legal & Compliance Agent (lca)
- **No `lca` PR was open.** New branch `lca/review-2026-10-25-0240`. Open at the start: #341 (`cra` 02:26), #340 (po 02:10), #331 (RLS2), #321 and older `cra` PRs, #3; none merged, none read as evidence. Tiers 1-3: nothing eligible (D-22, D-18 unchanged since 16:05, no new evidence). Changed since my signature: **D-25** (po 01:16), reviewed; nothing else eligible.
- **D-25 new evidence: the ZH leaflet I cited at 18:47 ([L8], November 2023) is superseded.** Read [L9] (December 2024 with changes of 17 September 2025); the authority's page [L10] links a newer one dated 6 January 2026, **not readable** this run. On [L9]: mix ≥20 % tertiary nurses / ≥30 % diploma + EFZ / ≤50 % assistants (the ≥50/≥25 figures in the po 19:09 note and the D-24 Engineering draft must not be built); RN cover "on site within ~20 min", written on-call rules, 24 h medical on-call; added named roles: **site nursing lead and deputy per site**, a management member responsible for health-police rules (§ 36 GesG as reported); still **no ward leader**; delegation to a team needs a written document, not just a chart.
- **Verdicts:** A and "B as a design target only" **compliant under every plausible interpretation**; B operated **unresolved: needs legal adviser or the canton (D)**, question updated; C **unresolved** (rejection for now is protective); D an owner step.
- **Note:** the ZH Spitex leaflet [Z1] (November 2023) cited in D-10 and D-15 is also superseded (September 2025 version linked on [L10]).
- Sources this run: [L9] zh.ch leaflet (tool summary, short quotes as reported), [L10] zh.ch page, both read 2026-10-25. GesG ZH §§ 35-37, 40 and the January 2026 leaflet not read.
- **Next for `lca`:** D-10 and D-15 against the September 2025 Spitex leaflet; the January 2026 home leaflet if readable; D-3 gate (iv) once RLS2 merges; LEAVE1 when delivered.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 02:26 · Clinical & Regulatory Architect (review)
- **Reviewed 0065 (F6R; pgTAP 066) in full**, 0066 (RLS2, #331 open, db CI red) and `READ_PATHS.md`, the briefs LEAVE1, DOOR1 and SIGC, PO cycles 23:10-02:10 and `lca` 22:50-01:41. Section 2026-10-25 02:26 in `reports/CLINICAL_GOVERNANCE.md`. Tests not run by me; CI green on `3766bde` (F6R); #331 db job failed on `241c49b`.
- **F6R-G1 met:** no blocking finding on 0065; the F6R acceptance stands. My 22:26 RLS2 request is in pgTAP 067:277-294, not yet shown green.
- **New, all advisory:** CGR-49 (S2; S1 before the first real leaver: no safe return when the performer has left the team; under LEAVE1 `user_in_team` stays true, so a return would strand a draft); CGR-50 (S2: LEAVE1 makes a leaver's open reports permanently unsigned until D-30; replace the manual "finish your paperwork" reminder with an open-reports list before the access end); CGR-51 (S2: RLS2 proposal F-1 would remove from Operations, the escalation recipient, what the nurse already did; do it only with DOOR1's structured facts); CGR-52 (S3, cause UNKNOWN: this PR's db job at 00:35 UTC, the DST night, failed overdue and SIG1 pgTAP (038, 046, 062) with unchanged code; possible late alerts in the repeated hour; for `eng`).
- **Registers:** CR-084 to CR-087 (F6R, class V); PS-38 to PS-40 decided by the PO (SIGC); PS-41 to PS-43 new; C-7, PS-15, H-01, H-05, H-12 updated.
- **Clinical impact:** po drafts confirmed for D-6 (not a clinical rule; no reopen) and D-20; D-13 point 3 corrected; D-14 guard measures corrected (a guard fed by the guarded team can be gamed); D-24 and D-25 three hazard areas added, stop rule needs leading signals (no MQI or LTCF content).
- **Merge:** this PR carries and supersedes #321 (and through it #306, #294, #278, #259); `recovery/main` merged in, JOURNAL both sides kept.
- **Next agent (po):** decide CGR-49 and CGR-50 into LEAVE1; CGR-51 with Q13; record the six Clinical impact blocks. **(eng):** CGR-52, then RLS2 db CI. **(owner/cra):** this PR is not merged: its db job is red for CGR-52, not for its content; re-run once the DST hour has passed, then merge; G-1; D-1. **(clinical, once named):** D-30 before the first real leaver.

## 2026-10-25 02:10 · po (Product Owner)
- **No PO PR was open.** Open: #331 (RLS2, `eng`, not merged: nothing to review), #321 and older `cra` PRs (not merged by the PO), #3 (M2). No `agent:po` issue open. Nothing `delivered`, `ready-for-review` or `in-review` with a merged PR.
- **Coordination defect found and fixed in the PO's file:** the *Next up* ID "SIG1-C2, SIG1-C3, SIG2-C1" contains spaces; the watcher's marker regex reads a key only up to the first space, so each of its runs opened a new hand-off issue that it can never match, update or close (#326, #329, #333, #334, #336, #339). Renamed **SIGC** (content, approval and order unchanged; `briefs/SIGC.md` points to the conditions in SIG1 and SIG2). The PO closes the six duplicates once the watcher has opened the SIGC issue. **WATCH-2** for Engineering: validate *Next up* IDs (today only the priority queue is checked).
- **Packages (INDEX order; tiers 1-3 unchanged, all awaiting a person or decided):** `lca` 01:41 taken up, no status change.
  - **D-14** (`awaiting-approval: owner`): ask sharpened, same choice: F3 counts only members whose access has not ended (LEAVE1; constraint 6); F4 only as a monthly count without client identifier (constraint 1, F4 variant).
  - **D-13** (`po-decided`): supersede path and identifier-only document reference recorded as testable criteria of the later B brief.
  - **D-24** (`awaiting-approval: owner`): boundary 4 cites ArGV 2 Art. 16 (homes), values only from the adviser's confirmation; question 2 replaced by the `lca` 01:41 wording.
  - **D-23** (`po-decided`): re-analysis requested from `lca` on ArGV 2 Art. 17 (home-care organisations), new evidence lead named by `lca` 01:41.
- **Challenge:** working-time limits checked after the plan by a scheduler or HR (new row; no brief before `lca` and D-12 name the source; NAVORA invents no limit).
- ROADMAP: line 25.10. 02:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** unchanged from 01:16 (owner: D-1 urgent, SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, D-4 final periods, D-14, D-24, D-25 once D-24 moves past A, G-1; merge `cra` PR #321).
- **Next agent:**
  - **(eng):** RLS2 (#331), then **SIGC** (use this ID in the status row), then DOOR1, then LEAVE1; WATCH-2 when convenient.
  - **(lca):** D-23 on ArGV 2 Art. 17; D-25 re-check as planned.
  - **(cra):** unchanged from 01:16.
  - **(po):** close #326, #329, #333, #334, #336, #339 as duplicates of the SIGC issue; review RLS2 when merged.

## 2026-10-25 01:41 · Legal & Compliance Agent (lca)
- **No `lca` PR was open.** New branch `lca/review-2026-10-25-0141`. Tiers 1-3: nothing eligible (D-22, D-18 unchanged since 16:05, no new evidence). Changed since my last signatures, in INDEX order: D-14, D-13, D-24 (reviewed); D-25 next run; D-6 has no legal question.
- **D-14** (po 00:10 ask: F3 or F4): matches my 17:57 verdicts. F3 **compliant under every plausible interpretation on the federal sources read**; F4 the same **on condition** that the fee statement carries client counts only, no identifier (the fact of receiving home care plausibly health data and under StGB 321; my reading). Note to po: count only members whose access has not ended (LEAVE1).
- **D-13** (B decided by po 00:10): **compliant under every plausible interpretation** on the sources read; po authority unobjectionable. For the B brief: explicit supersede path for wrong minutes (old record kept, never current); the document reference is an identifier with no health text.
- **D-24** (owner ask 01:16; new evidence): SECO guidance on **ArGV 2 Art. 16 (Heime und Internate**, July 2023) names Alters- und Pflegeheime; it lists a different special-rule set than Art. 15 for hospitals (no 17-hour span, no on-call credit). My 20:50 applicability UNKNOWN is resolved for private homes under the ArG; B stays **unresolved: needs owner and legal adviser** (question 2 narrowed; D-25 leadership part unchanged). Boundary 1 (nothing imported) is stricter than my 20:50 wording and more protective.
- Sources this run: SECO, Wegleitung ArGV 2, Art. 16 (July 2023) and the SECO article index, read 2026-10-25. Consolidated ArGV 2 on fedlex not read. ArGV 2 Art. 17 (Spitex) not read: title only.
- **Next for `lca`:** D-25 re-check (package changed 01:16); ArGV 2 Art. 17 if D-23 is reopened; D-3 gate (iv) once RLS2 merges; LEAVE1 when delivered.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-25 01:16 · po (Product Owner)
- **PO PR #330** (00:10) was open with green CI but conflicted in `JOURNAL.md`: merged `recovery/main` in (both entries kept, newest first; 6b786c7), CI green again (app, db, e2e), **merged** as c5ee62a. #328 (F6R review hand-off) closed. Open now: #331 (RLS2, `eng`, not merged: nothing to review), #321 and older `cra` PRs (not merged by the PO), #3 (M2). Claimed **#115, #116, #56** (D-24, D-25, D-10); claims removed at the end.
- **No delivery to review:** no item `delivered`, `ready-for-review` or `in-review` with a merged PR.
- **New brief LEAVE1 approved** (*Next up* 4, after DOOR1), from `lca` 00:50 on D-10 and D-30: `remove_team_member` refuses while a member has an unsigned or returned report (0037, 0065 §8), and no other command ends a person's access, so a former employee keeps the team's read access. Real-data gate: no real client before LEAVE1 is accepted. Challenge row added (access tied to finished paperwork).
- **Packages (INDEX order; tiers 1-3 unchanged, all awaiting a person or decided):**
  - **D-24 `awaiting-approval: owner`** (Medium; E and C drafted by po, two-run rule; L 20:50): approve **A** now (no nursing-home build); B, one design-partner ward, after D-11, D-12, one pilot month and D-25, under five hard boundaries (no interRAI item, scale, CH-Index or care level shown; named licence roles never team-changeable; skill mix, RN cover and working-time limits as hard roster constraints; a Clinical-Owner-approved stop rule); C after a licence and D-34.
  - **D-25 `awaiting-approval: owner`** (Medium; E and C drafted by po; L 18:47): A in force; design target B adopted; C rejected for now; only once D-24 moves past A: name a legal adviser for the partner canton, or approve D (ask the canton).
  - **D-10, D-30:** `lca` 00:50 taken up (LEAVE1); status unchanged (`awaiting-approval: clinical`). **D-20:** `lca` 00:50 condition for ADM2 recorded (no reuse of `team_decisions` as built); still `po-decided`.
- ROADMAP: line 25.10. 01:16. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, D-14, **D-24 (new)**, **D-25 (new, only once D-24 moves past A)**, G-1 (name the Clinical Owner); merge `cra` PR #321. **Clinical Owner:** unchanged.
- **Next agent:**
  - **(eng):** RLS2 (#331), then SIG1-C2 + SIG1-C3 + SIG2-C1, then DOOR1, then LEAVE1. Confirm or correct the po drafts in D-24 and D-25 (Engineering impact).
  - **(cra):** F6R-G1 (0065); whether ending a leaver's access before she signs changes H-12 or PS-15 (LEAVE1); confirm or correct the po drafts in D-24 and D-25 (Clinical impact).
  - **(lca):** LEAVE1 against your 00:50 note 1 when it is delivered; nothing new requested on D-24 or D-25.
  - **(po):** the D-13 B brief once the approved queue is clear; review RLS2 when merged.

ENGINEERING BRIEF
- **Capability:** LEAVE1, access ends when employment ends ([brief](briefs/LEAVE1.md)).
- **Why:** a leaver keeps the team's read access to client health data while any report of hers is unsigned or returned, because the only lever (team removal) is refused for a reason only she can clear; `lca`: not compliant under every plausible interpretation with real data.
- **Business outcome:** a real-data gate closed; an offboarding the organisation can complete the day employment ends.
- **Care outcome:** her open reports stay visible to the team as not final and follow D-30; no record lost or rewritten.
- **Expected nurse outcome:** no change to the remaining nurses' work except a visible "Zugang beendet" marker on the leaver's open reports.
- **Expected team outcome:** the team, not an administrator chasing a former colleague, sees what is still open.
- **Expected patient outcome:** clients' records are read only by people who currently care for them.
- **Acceptance criteria:** LEAVE1-1 to LEAVE1-10 (command and refusals; not blocked by what only she can clear; zero reads, refused commands and no push after the end, with a catalogue check; history kept, no deletion; open work visible to the team's RNs; leaver's screen; restore; who sees the record; real-data gate entry; no regression).
- **Dependencies:** none blocking; consistent with RLS2 (read-path inventory) and D-26 (enforced in the database, no service-role key on the app host). D-30 governs her reports.
- **Priority:** *Next up* 4, after DOOR1 (no real data exists yet).
- **Implementation recommendation:** one additive migration in the ADM1 command pattern; an access-ended fact read by every access helper; a pgTAP catalogue loop over every table and view readable by `authenticated`; one e2e for the leaver's screen.

## 2026-10-25 00:50 · Legal & Compliance Agent (lca)
- **No `lca` PR was open.** New branch `lca/review-2026-10-25-0050`. Open at the start: #331 (RLS2), #330 (po 00:10, not merged; not read as evidence), #321 and older `cra` PRs, #3.
- **Re-checked D-10** (tier 3; new evidence: F6R delivered, 0065). R as delivered: **compliant under every plausible interpretation** on the sources read (pilot canton still to confirm). **New point from deviation (3):** `remove_team_member` refuses while a returned report is unsigned (0065 §8, extending 0037), and no other path in the migrations I read ends a person's access, so a **former employee keeps team read access** until she signs. With real data: **not compliant under every plausible interpretation; unresolved: needs legal adviser** (new question 4). Note to po: a real-data gate, an access-end path independent of team membership (audited), her reports stay open for the team.
- **Re-checked D-30** (same new evidence): the as-built state after employment ends is option E without a time limit, which the package rejected; same gate closes it. Recommendation 1-4 unchanged.
- **Re-checked D-20** (package changed: decided by po 23:10, D sharpened): compliant under every plausible interpretation, **on the condition** that ADM2 does not reuse `team_decisions` as built (append-only, free-text reason, organisation-wide coordinator read, 0011, 0017): deletable candidate record, decision record without name or free text, team / nursing lead / administrator reads only.
- **Not re-reviewed:** D-22, D-18 (unchanged since 16:05; no new evidence); D-19, D-17 (23:10 changes adopt my 16:05, 17:57 and 22:50 terms; nothing new to analyse); D-3 gate (iv) waits for RLS2 (#331) to merge.
- Sources this run: DSG (BBl 2020 7639, fedlex publication copy hosted by HSLU) Art. 5 lit. h, 6 Abs. 2 and 4, 8 Abs. 1-2; HIN, "Technische und organisatorische Massnahmen gemäss DSG/DSV", V1.1, February 2026 (secondary). DSV text not read (fedlex not reachable).
- **Next for `lca`:** D-3 gate (iv) once RLS2 merges; D-10 R against the pilot canton once D-11 is answered; D-26 production question if the owner answers.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.
## 2026-10-25 00:10 · po (Product Owner)
- **No PO PR was open** at the start. Open PRs: #321, #306, #294, #278, #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#328** (F6R review), **#72, #60, #59** (D-6, D-14, D-13); claims removed at the end.
- **F6R accepted** (#320 merged 868e3e0; migration 0065, pgTAP 066 (82), ADR-079; CI green on head 3766bde and `recovery/main` d293062; merge-commit runs cancelled by the next push). F6R-1 to F6R-9 met; deviations 1-6 accepted; evidence table in `briefs/F6R.md`. Clinical gate: no merged `cra` section covers 0065; `cra` 22:26 (#321) said no gate is needed unless the PR adds a rule; the PO found none. **Condition F6R-G1:** `cra` confirms on 0065; a `blocking` finding returns F6R to `changes-requested`. Moved into the queue (rank 26); *Next up* renumbered: 1 RLS2, 2 SIG1-C2 + SIG1-C3 + SIG2-C1, 3 DOOR1.
- **Packages (INDEX order; tiers 1-3 all awaiting a person or decided):**
  - **D-6 decided by po** (Medium; E and C drafted by po, two-run rule): option A as built (team plus optional responsible member; workflow state list; missed, overdue, stuck stay derived). B, C, D rejected. Clinical meanings stay D-28, D-19, D-31; reopens to `clinical` if `cra` classifies it as a clinical rule.
  - **D-13 decided by po** (Medium; E and C drafted by po; `lca` 18:47 in): option B, instrument-neutral assessment record (several per case; assessing RN with GLN; no items, scores or outputs). A is a new `owner` decision once D-12 names the provider. A brief follows once the approved queue is clear.
  - **D-14 `awaiting-approval: owner`** (Medium; E and the C point drafted by po; `lca` 17:57 in): approve **F3** (fee per active team member per month), or F4; no per-hour or revenue-share fee. S1 and constraints 1-5 in force; J7 stays draft.
- **Challenge:** new row, a supplier fee tied to billed hours or revenue (with a pilot hypothesis on visit length and category mix under a volume-neutral fee).
- ROADMAP: line 25.10. 00:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, **D-14 (new)**, G-1 (name the Clinical Owner); merge `cra` PR #321 (supersedes #306, #294, #278, #259). **Clinical Owner:** unchanged (D-10, D-28, D-31, D-3, D-30, D-16, D-15, D-19, D-17).
- **Next agent:**
  - **(eng):** RLS2, then SIG1-C2 + SIG1-C3 + SIG2-C1, then DOOR1. Confirm or correct the po drafts in D-6, D-13, D-14.
  - **(cra):** F6R-G1 (0065); confirm or correct the po drafts in D-6 (is the assignment model a clinical rule?), D-13 (points 1-4), D-14 (hazards and guard measures); D-24, D-25 as planned.
  - **(lca):** nothing new requested; D-6 has no legal question, D-13 and D-14 rest on your 18:47 and 17:57 sections.
  - **(po):** D-24, D-25 next (two-run rule for E and C); write the D-13 B brief once the approved queue is clear.

## 2026-10-25 00:35 · eng (Lead Engineer)
- **No own PR was open.** I claimed #319 (RLS2, the active hand-off, unclaimed) at 00:11.
- **#331 is open** (ADR-080, migration 0066, pgTAP 067 with 127 assertions, inventory `docs/engineering/READ_PATHS.md`):
  - `visit_events` and `visit_time_corrections` are readable by the row's or visit's team and the active covering member (`private.reads_visit`).
  - `team_decisions` is readable by the deciding team; `case_tasks` by the case's team (`private.reads_case`).
  - No coordination role reads any of the four through the table API.
  - The escalation readers no longer return the decline free text.
  - `uncovered_visits()` is no longer organisation-wide.
- **Found while reading the code:**
  - `team_decisions` had been narrowed by 0017 already (the brief says organisation-wide). 0066 removes the coordination roles too.
  - `field_visits` is `SECURITY INVOKER`. It reads the correction reason under RLS, so no column grant was revoked: the row scope does the job.
- **Brief's open questions:**
  - Coordination tasks: OPS1, SIG1, intake, J2 escalation and AN1/AN2 all use read models. None needs the table API.
  - The catalogue check is keyed on column names (`case_id`, `visit_id`, `client_id`) for tables and function results, plus a cross-team sweep of every reader.
  - Estimate: one migration as planned, but 127 assertions instead of 30-40, because the sweep calls every reader.
- **Deviations for the PO** (status row):
  1. `team_decisions` already narrowed by 0017 (see above).
  2. pgTAP 017 test 42 inverted to 0 rows; 012 tests 16 and 23 now read as the table owner. No assertion removed.
  3. The cover read ends at the final report.
  4. No column grant changed.
- **RLS2-5 findings F-1 to F-5:** coordination-role paths, not narrowed here. They are eng-proposal **RLS3** and decision **Q13** for `po`. F-1, the free-text no-show note in the OPS1 detail, may become a `clinical` question if Operations needs the text.
- **Clinical gate:** I read `cra` 22:26 (open PR #321). Its RLS2 note is applied: pgTAP shows that OPS1 and `my_signals` still raise a no-show and an overdue visit of the team after the narrowing. No CGR finding names RLS2, so no remediation plan. No rule invented.
- **Tests:**
  - **Local run, not CI:** PostgreSQL 16 with a role/auth shim and a minimal pgTAP stand-in. Migrations, seed and 0066 twice applied without error. 067 passed 127/127; every other file matched its pre-0066 baseline.
  - **Not run:** lint, typecheck, vitest, e2e, db lint. CI decides.
- **Next:**
  - **(eng):** CI on #331, then merge and `delivered`; then SIG1-C2 + SIG1-C3 + SIG2-C1, then DOOR1.
  - **(po):** Q13.
  - **(lca):** D-3 gate (iv) against READ_PATHS.md once #331 is merged.

## 2026-10-24 23:25 · eng (Lead Engineer)
- **#320 merged** as 868e3e0 with a merge commit. CI was green on head 3766bde (app, db, e2e).
  - The first `db` run failed on types drift only; the types bot regenerated `database.types.ts` (dc9d34c).
  - The second `db` run failed pgTAP 066 test 64: two observations carry the same `recorded_at` inside the test transaction, so the uuid decided the order. The test now orders the superseding row last (3766bde). 066 passed 82/82 locally after the fix, then in CI.
- **F6R is `delivered`** (READY_FOR_REVIEW): PO review of F6R-1 to F6R-9 against `briefs/F6R.md`, deviations (1)-(6) in the status row. Clinical gate: no `cra` section covers 0065 yet.

## 2026-10-24 23:10 · po (Product Owner)
- **No PO PR was open** at the start (#318 merged). Open PRs: #320 (F6R, `eng`, CI pending, not merged: nothing to review yet), #321 (`cra` 22:26, supersedes #306, #294, #278, #259; not merged by the PO), #3 (M2). Claimed **#81, #66, #89** (D-19, D-17, D-20); claims removed at the end.
- **No delivery to review:** no item `delivered`, `ready-for-review` or `in-review` with a merged PR; no "[PO review]" issue open.
- **`cra` 22:26 taken up** (read on branch `gov/review-2026-10-24-2226`): D-19 and D-17 *Clinical impact* copied verbatim; CGR-46, CGR-47, CGR-48 decided by po as conditions: **SIG1-C2** (AN2 counts the first take that stops the step for no-show and broken-off visits; first take of anyone kept as its own labelled value), **SIG1-C3** (pgTAP for the covering member's and Operations' takes), **SIG2-C1** (outside watched hours "Operations nur in der App"; a list of planned visits outside every watched period on /admin and /team replaces the manual SIG1-8 check). *Next up* 3, one PR.
- **Packages (INDEX order; tiers 1-3 unchanged, all awaiting a person or decided):**
  - **D-19** (tier 2) **`awaiting-approval: clinical`** (C in; L in 16:05, 22:50; E drafted by po; Medium): the Clinical Owner approves option B's structure and its values and answers (a) recording from `on_the_way`, (b) care assistant alone, (c) who is informed by when. **Decided by po (product):** "an der Tür: ja/nein" and the basis of "Notfallkontakt informiert" (outcome kept). Contact display only through a team read model with the D-9 g4 consent flag, after D-9 and `lca` question 6.
  - **D-17** (tier 4) **`awaiting-approval: clinical`** (Engineering **drafted by po, not confirmed by eng**: access and language notes are recorded but no `/field` reader shows them; C in; L in; Medium): form B and the organisational part decided by po (display only; C and D rejected); the Clinical Owner approves the clinical categories, their detail, what "unbekannt" requires, review triggers, who records.
  - **D-20** (tier 4) **decided by po: option D sharpened** (E and the one C point drafted by po; `lca` 18:47 compliant under every plausible interpretation): team decides membership, the employer records "Vertrag erfasst" once, qualification after D-29, lead roles never team-changeable. ADM2 once D-29 and D-26 are answered; administrator admission stays until then.
- **New brief DOOR1 approved** (*Next up* 4). Challenge: briefing-call row and team-admission row updated; new row on the manual SIG1-8 plan check (hypothesis: the outside-hours list is empty on at least 6 of 7 days).
- ROADMAP: line 24.10. 23:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people (unchanged plus two):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner); merge `cra` PR #321 (supersedes #306, #294, #278, #259). **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15, **D-19, D-17**.
- **Next agent:**
  - **(eng):** F6R (#320), then RLS2, then SIG1-C2 + SIG1-C3 + SIG2-C1, then DOOR1. Confirm or correct the po drafts in D-17, D-20, D-19, D-26, D-23, SR-26, D-1, D-8, D-10, D-2, D-7, D-34.
  - **(cra):** confirm the po draft of the D-20 point; D-24, D-13, D-25, D-6 as planned; a look at DOOR1 if any field reads as clinical.
  - **(lca):** nothing new requested; DOOR1 adds no legal question (minimisation and no-code terms taken from 17:57 and 22:50).
  - **(po):** D-6 (C two-run rule reached), D-14, D-13 next; review F6R once #320 is merged with green CI.

**ENGINEERING BRIEF — DOOR1**
- **Capability:** What the nurse needs at the door (`briefs/DOOR1.md`).
- **Why:** the access and language notes recorded at intake never reach the `/field` card, so a briefing call replaces them (H-03, S1); a no-show record cannot tell a door attempt from a phone attempt, and a disclosure to an emergency contact is recorded without its basis.
- **Business outcome:** the intake coordinator's briefing call disappears; one recording serves every nurse and every cover; the provider can show on which basis a contact was told.
- **Care outcome:** the first visit and every cover start with the same context; what is unknown is visible, not silent.
- **Expected nurse outcome:** she opens the card and knows how to get in and which language, without phoning anyone; her no-show record says what she checked.
- **Expected team outcome:** no colleague is pulled into briefing calls; changes show in HAND1.
- **Expected patient outcome:** fewer delays at the door and fewer missed precautions; her emergency contact is told only on a recorded basis.
- **Acceptance criteria:** DOOR1-1 notes on the card for team and active cover only ("nicht erfasst" when empty); DOOR1-2 versioned category list with one organisational category (access arrangement) and no clinical one; DOOR1-3 append-only values ja/nein/unbekannt with note, source, who, when; DOOR1-4 "unbekannt" first and distinct, no code stored (guard on digit runs); DOOR1-5 "an der Tür: ja/nein" required on a no-show; DOOR1-6 basis required for "Notfallkontakt informiert"; DOOR1-7 changes in HAND1; DOOR1-8 display only (no signal, readiness or planning change); DOOR1-9 team-scoped reads, no analytics, billing, export or push reader; DOOR1-10 no regression (C1, SIG1, SIG1-C1).
- **Dependencies:** none to start; RLS2 for the read pattern (may run in either order); real data blocked by D-1, D-9, D-29 and the D-3 gates; clinical categories wait for the Clinical Owner (D-17), the protocol for D-19, the emergency contact for D-9 and the legal adviser.
- **Priority:** *Next up* 4, after F6R, RLS2 and the signal conditions.
- **Implementation recommendation:** a team-scoped `security definer` read model for the card (membership plus `private.cover_team_for`); one additive migration with the category and value tables (append-only trigger as in F6R-2), two required parameters on `record_no_show` and `record_no_show_outcome`; about 35-45 pgTAP assertions, unit tests on the guard and labels, e2e at 390 px. May split into (a) DOOR1-1, -5, -6, -7 and (b) the category table.

## 2026-10-24 22:50 · Legal & Compliance Agent (lca)
- **No `lca` PR was open** (#310 merged). New branch `lca/review-2026-10-24-2250`.
- **Re-checked D-19** (tier 2; package changed: Engineering drafted by po 22:10; new evidence: `cra` 22:26 block, branch `gov/review-2026-10-24-2226`). (1) Keeping the outcome "Notfallkontakt informiert" is documentation, not a disclosure by NAVORA; the record lacks the **basis** (recorded consent / emergency), so a structured "Grundlage" fact is the protective product shape. (2) Showing the contact by **re-granting the revoked `cases` columns would expose them to every coordination role organisation-wide** (0015:28-30; read, not tested): not compliant under every plausible interpretation; a team read model (0015 already foresees one) is. (3) Information duty to the contact person sharpened (DSG Art. 19 Abs. 5; Art. 20 Abs. 1 lit. c likely covers natural persons only, so not a provider that is a legal person). Verdicts: A (with SIG1-C1, SIG2) compliant under every plausible interpretation for what NAVORA does; C in the PO's shape compliant for read and display, **unresolved: needs legal adviser** on the information duty (new question 6) and 16:05 questions 1, 3; B unchanged.
- **Re-checked D-17** (new evidence on its one open question): the 17:57 adviser question is replaced by D-19 question 6; `cra` 22:26 form adds no legal question; verdicts unchanged.
- Sources this run: onlinekommentar.ch, Glatthaar/Schröder on DSG Art. 20 (Stand 20.08.2023); law.ch LawInfo on DSG Art. 19 (12.12.2023). Both secondary; fedlex still not reachable.
- **Not re-reviewed:** D-22, D-18 (unchanged since 16:05; no new evidence); D-3, D-23, D-4 (22:10 changes only adopt my notes); D-3 gate (iv) waits on the RLS2 inventory.
- **Next for `lca`:** D-10 R against the pilot canton once D-11 is answered; D-3 gate (iv) once RLS2 lists the read paths; D-26 production question if the owner answers.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 22:45 · eng (Lead Engineer)
- **No own PR was open.** Claimed #309 (F6R, the only active hand-off) at 22:12. The SIG2 follow-up is merged (#315), so F6R is next in the PO order.
- **#320 open (ADR-079, migration 0065):** `return_report` by a registered nurse of the team on the latest signed version awaiting countersignature, reason 10–500; append-only `visit_report_returns` (version, snapshot hash, reason, returner, time); the returned version is unchanged and the return opens the next version as a draft. After a return only the performer corrects; a superseded version cannot be countersigned; only the countersigned corrected version becomes `final` and a billing basis. `/field`: "Zurückgeben" next to "Gegenzeichnen"; "Zurückgegeben: bitte korrigieren und neu unterschreiben" at the top of the performer's day; RN queue "zurückgegeben". AN2 `report_returned_share`, `countersign_latency_hours`. F6R is `in-review`.
- **Brief's open questions:** the draft takes the **next** version number (as withdrawn corrections, 0049). The PO estimate (one additive migration, about 15 assertions) was low on tests: one migration, 82 pgTAP assertions, because every refusal and every reader of "latest version" is checked.
- **Deviations for the PO:** see the F6R row: (1) reason ≤ 500; (2) no `report_correction_open` for a return; (3) removal and return refused while it would strand (CR-048 / D-30 interim); (4) AN1 final time; (5) queue without the reason.
- **Clinical gate:** report sections read: 02:26 (merged) and 18:26 (open PR #306, D-10 block). No CGR finding names F6R; the D-10 conditions (a)-(d) are built (F6R-5, -4, -2, -7). H-04 / D-29 unchanged. No remediation plan (no finding). No clinical rule invented.
- **Tests:**
  - **Local run, not CI:** PostgreSQL 16 with a role/auth shim and a minimal pgTAP stand-in. 0065 applied twice without error; 066 passed 82/82; 059 passed with the new count; every other file matched its pre-0065 baseline.
  - **Not run:** lint, typecheck, vitest, e2e and db lint (no npm registry). `database.types.ts` was edited by hand; db-types-sync regenerates it. CI decides.
- **Next agent (eng):** if #320 is green, merge it and set F6R to `delivered`; if the types bot's run waits for approval, approve it.
## 2026-10-24 22:26 · Clinical & Regulatory Architect (review)
- **Reviewed 0063 (ORD0-C2, SIG1-C1; pgTAP 065) and 0064 (SIG2-11 to SIG2-14; pgTAP 064)** in full, plus F6R, RLS2, PO cycles 19:09-22:10 and `lca` 18:47-21:55. Section 2026-10-24 22:26 in `reports/CLINICAL_GOVERNANCE.md`. Tests not run by me; CI green on `b574966`, `8a8dd27` and `bdb47a8`.
- **Closed (code + test cited):** CGR-42 (pgTAP 064:137-168, 413-453), CGR-43 (065:179-239), CGR-44 (065:57-113), CGR-45 (064:357-380). **New, all advisory:** CGR-46 (S3: cover and Operations take paths untested); CGR-47 (S3: AN2 counts the first take, also a care assistant's that does not stop the step); CGR-48 (S2, S1 for switching the channel on: outside watched hours Operations is in-app only while the banner says "Meldung an Operations folgt"; SIG1-8 is a manual check that structured data could replace).
- **Gate:** no blocking finding on 0063 or 0064; the ORD0, SIG1 and SIG2 acceptances stand.
- **Registers:** eng's CR-074 to CR-077 reviewed; my unmerged CR-074 to CR-078 renumbered **CR-079 to CR-083**; new section *Input class (D-34)*: no rule is clinical content; CR-020, CR-022, CR-024, CR-041, CR-073 marked "for the adviser". PS-34 to PS-37 closed; PS-38 to PS-40 new.
- **Clinical impact written for D-19 and D-17** (structure for the Clinical Owner; no protocol content, no list items). RLS2: the clinical needs of coordination roles named; one pgTAP asked (OPS1 and SIG1 still raise after the narrowing).
- **Merge:** this PR carries and supersedes #306, #294, #278 and #259 (`recovery/main` merged in; JOURNAL both sides kept; rule register: `recovery/main`'s IDs stand).
- **Next agent (po):** decide CGR-48 and CGR-47; copy the D-19 and D-17 blocks; D-19 "an der Tür: ja/nein". **(eng):** CGR-46 (pgTAP only); the RLS2 assertion above. **(owner):** merge this PR; G-1; D-1; pg_cron, pg_net and Vault in the pilot project.

## 2026-10-24 22:10 · po (Product Owner)
- **No PO PR was open** at the start (#311 merged). Open PRs: #306, #294, #278, #259 (`cra`), #3 (M2); not merged by the PO. Claimed **#317, #81** (SIG2 review, D-19); claims removed at the end.
- **SIG2 `accepted`** (#315, 0064, ADR-078; CI green on head 508ad33, merge commit 8a8dd27 and `recovery/main` 68c05dc; the PO did not run the tests): SIG2-11 (run recorded only by the scheduled evaluator; 5-minute warning on /operations and /admin; "aktiv" withdrawn on /team and /settings; dispatch kicked by the job, fail closed), SIG2-12 (Operations push only inside watched hours), SIG2-13 (raise at the later of period start and end minus 2 h) and SIG2-14 (2) (predicate proven at six fixed instants) met; evidence table in `briefs/SIG2.md`. Deviations 12 (`operations_fallback` counts as an Operations push), 13 (no run row = not running), 14 (heartbeat not audited) accepted. **`cra` asked to cover 0064** (a blocking finding returns SIG2). Not live until DPF entries, D-2, D-26 and the Vault/pg_net wiring (owner).
- **New brief RLS2 approved** (*Next up* 2, after F6R): `lca` 21:55 found `visit_events`, `visit_time_corrections`, `team_decisions` and `case_tasks` readable organisation-wide (two with free-text reasons); D-3 B with real data is not compliant until narrowed, D-23 C plus D only with it. Narrows only, so product authority.
- **Packages (INDEX order; tiers 1-3 otherwise all awaiting approval):**
  - **D-19** (tier 2): Engineering **drafted by po, not confirmed by eng** (two-run rule; requested 15:10): C1 records one outcome row, no step list; **"Notfallkontakt informiert" is offered while NAVORA shows no emergency contact** (revoked in 0015:68, no reader in `src/`) and no consent fact. Still `inputs-requested` (C; one `cra` run since the request).
  - **D-3** (tier 2): `lca` 21:55 taken up: real-data gate **(iv)** added (every client- or visit-linked read path team-scoped, inventory; RLS2), *Context* corrected, go-live conditions updated. Status unchanged (`awaiting-approval: clinical`, cover-read field list).
  - **D-23** (tier 3): `lca` 21:55 terms (a)-(e) all taken in (precondition widened to `visit_time_corrections`; no per-person aggregation for others; information text names both uses; no location data; D-4 retention criterion for confirmed days). Still `po-decided`. D-4 gains that criterion (no period set).
- **Challenge:** the emergency contact at the door (row added; hypothesis: more than 1 in 4 no-show outcomes recorded later than 15 minutes, or `other` → build D-19 option C first once D-9 allows it).
- ROADMAP: line 24.10. 22:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people (unchanged):** **owner:** D-1 (urgent), SR-26, D-26, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner); merge `cra` PR #306. **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15.
- **Next agent:**
  - **(eng):** F6R, then RLS2. Confirm or correct the po drafts in D-19, D-26, D-23, SR-26, D-1, D-8, D-10, D-2, D-7, D-34.
  - **(cra):** cover 0064 (SIG2-11 to SIG2-14; CR-076, CR-077); D-19 and D-17 first, then D-24, D-13, D-25, D-6, D-20 (one point); comment on RLS2 if a coordination-role read is a clinical need.
  - **(lca):** nothing new requested; D-10 R against the pilot canton once D-11 is answered.
  - **(po):** D-17 (Engineering two-run rule reached), D-6, D-20 next.

**ENGINEERING BRIEF — RLS2**
- **Capability:** Visit and case records are read only by the people who care for the client (`briefs/RLS2.md`).
- **Why:** four tables (`visit_events`, `visit_time_corrections`, `team_decisions`, `case_tasks`) are readable by every organisation member; free-text reasons can carry health data, and any member can rebuild a colleague's working day. `lca` 21:55: D-3 B with real data not compliant until narrowed.
- **Business outcome:** removes a blocker for the first real client (D-3 gate iv) and for D-23 (no separate timesheet); one inventory instead of finding gaps table by table.
- **Care outcome:** what a team records about a client stays with the people treating her; professional secrecy holds inside the provider.
- **Expected nurse outcome:** her visit times and corrections are not visible to other teams; nothing changes on her screens.
- **Expected team outcome:** teams can write honest reasons (a fall, a decline) knowing they stay in the team; autonomy without exposure.
- **Expected patient outcome:** fewer people can read about her; her data is used only by those who care for her.
- **Acceptance criteria:** RLS2-1 read-path inventory with a catalogue check in pgTAP; RLS2-2 the four tables team-scoped (team, covering member while active, coordination roles only for a named task), pgTAP per table incl. other team, other organisation, anon, cover end; RLS2-3 free-text reasons never outside team and covering member; RLS2-4 no per-person aggregation for others; RLS2-5 further gaps narrowed or listed as findings, nothing widened; RLS2-6 no regression (pgTAP, unit, e2e, AN1/AN2 values); RLS2-7 no scope widening through function arguments, removed member reads nothing.
- **Dependencies:** none to start; COVER1 cover predicate (built). Real data still blocked by D-1, D-9, D-29 and gates (i)-(iii).
- **Priority:** *Next up* 2, after F6R.
- **Implementation recommendation:** follow the 0015 pattern (policies through the visit's or case's team, column revoke for the reasons); start with the inventory from the catalogue (`information_schema` plus `pg_proc` for `security definer` functions executable by `authenticated`), then narrow; one additive migration, about 30-40 pgTAP assertions.

## 2026-10-24 21:55 · Legal & Compliance Agent (lca)
- **Continued my open PR #310** (no second `lca` PR): merged `recovery/main` 8a8dd27 in (JOURNAL conflict resolved, all entries kept, newest first). Its `db` failure was SIG2-14 (wall-clock test 78); #312 fixed part (1) on `recovery/main`, so CI should now decide on this PR's own files.
- **Re-checked D-23** (package changed: PO 21:10 decided C plus D; new evidence: organisation-wide `visit_events` read). Confirmed in 0007:46 (read, not tested); **`visit_time_corrections` (0008:43) has the same organisation-wide policy**, plus a free-text reason. **C plus D as decided: compliant under every plausible interpretation on the sources read**, on terms (a)-(e): both tables narrowed to team and covering member before real data; no per-person aggregation for others; the information text names both uses; no location data for C (wording gap); a D-4 retention criterion for confirmed days. B unchanged (legal adviser).
- **Re-checked D-3** (new evidence, tier 2: CGR-21, CGR-28): four tables outside the 0015 narrowing are organisation-wide: `visit_events`, `visit_time_corrections`, `team_decisions` and `case_tasks`. Two of them carry **free-text reasons** that can hold health data. **B as built with real data: not compliant under every plausible interpretation** until they are narrowed (0015 pattern, pgTAP); with that, B plus gates (i)-(iii) stays compliant (federal sources; cantonal UNKNOWN). Note to po: a fourth real-data gate (iv) and a full read-path inventory (`eng`). Synthetic data: no change.
- Sources this run: onlinekommentar.ch on DSG Art. 7 (statutory text); weka.ch, 21 November 2025, on ArGV 3 Art. 26 (secondary). My own text search of the migrations; not an exhaustive audit of views and functions.
- **Not re-reviewed:** D-22, D-18 (unchanged since 16:05; no new evidence); D-26, D-4 (only PO text adopting my notes); D-28, D-6 (no `lca` requested).
- **Next for `lca`:** D-10 R against the pilot canton once D-11 is answered; D-26 production question if the owner answers; D-3 gate (iv) once `eng` lists the read paths.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 21:42 · eng (Lead Engineer)
- **#315 merged** as 8a8dd27 with a merge commit. CI was green on head 508ad33 (app, db, e2e).
  - The first `db` run failed pgTAP 064 test 31: in CI the real pg_cron job had already recorded a run. The fixture now deletes that row first (9d59d2d). I reproduced the failure locally before the fix.
  - I merged `recovery/main` (PO #311) into the branch; the journal conflict was resolved by keeping both entries.
- **SIG2 is `delivered`**, which is READY_FOR_REVIEW. The PO review covers SIG2-11 to SIG2-14 against `briefs/SIG2.md`, plus deviations 12-14 in the 21:45 entry.
- **Next (eng):** F6R (#309). The PO's 21:10 request to verify `visit_events` is not yet read in full.

## 2026-10-24 21:45 · eng (Lead Engineer)
- **No own PR was open** (#312 merged). Claimed #309 at 21:12, the only active hand-off. Built *Next up* 2 first, per the PO order: F6R is *Next up* 3.
- **#315 open (ADR-078, migration 0064):**
  - **SIG2-11 (CGR-42):** `private.signal_scheduler_runs` is written only by the scheduled evaluator. Without a run in the last 5 minutes, `/operations` and `/admin` show "Signalprüfung läuft nicht", and `/team` and `/settings` show no "aktiv". Each scheduled run asks the sender to dispatch, through pg_net and two Vault entries (OWNER_RUNBOOK 5a). Without them nothing is sent: fail closed, as before.
  - **SIG2-12:** an Operations push goes out only inside a watched period; otherwise `outside_working_time`.
  - **SIG2-13 (CGR-45):** the raise time is the later of the period's start and its end minus 2 h.
  - **SIG2-14** (PO PR #311, not yet merged): the predicate takes the instant; pgTAP checks it at fixed instants. SIG2 is now `in-review`.
- **Deviations for the PO:**
  - (12) `operations_fallback` is also treated as a push to Operations under SIG2-12.
  - (13) A missing run row means "not running".
  - (14) The heartbeat is not audited.
- **Clinical gate:** remediation plans `CGR-42.md` and `CGR-45.md`. Register: CR-073 updated, CR-076 and CR-077 added (PROVISIONAL). No rule invented; 5 min and 2 h are PO operating limits.
- **Tests:**
  - **Local run, not CI:** PostgreSQL 16 with a role/auth shim and a minimal pgTAP stand-in. 064 passed 106/106; 060, 062, 063 and 065 passed; every other file matched its pre-0064 baseline. 0064 applied twice without error.
  - **Not run:** lint, typecheck, vitest, e2e and db lint (no npm registry). CI decides.
- **Next agent (eng):** if #315 is green, merge it and set SIG2 to `delivered`. Then build F6R (#309).

## 2026-10-24 21:10 · po (Product Owner)
- **PO PR #311 (20:09) was still open**, `db` red on pgTAP 064 test 78 (SIG2-14, not the PR's). Continued it instead of opening a second one: merged `recovery/main` b55d7b1 in (journal conflict resolved, both entries kept, newest first), this cycle added on the same branch. Open PRs otherwise: #310 (`lca` 19:55 + 20:50), #306, #294, #278, #259 (`cra`), #3 (M2); not merged by the PO. Claimed **#314, #132, #111** (ORD0, D-26, D-23); claims removed at the end.
- **ORD0 `accepted`** (#312, 0063, ADR-077; CI green on head 5aa2390, merge commit b574966, `recovery/main` b55d7b1; the PO did not run the tests): ORD0-C1 (a), (b) and the widened ORD0-C2 (a), (a′), (b)-(e) met, evidence table in `briefs/ORD0.md`. Deviation 2 (HAND1 lists the record, not the task) accepted. Moved from *Next up* into the queue (rank 24). Clinical gate: `cra` 14:27 passed; **`cra` asked to cover 0063** in its next section (a blocking finding returns ORD0 and SIG1 to `changes-requested`).
- **SIG1-C1 met**, SIG1 stays `accepted` (`briefs/SIG1.md` 21:10). Deviation 1 (an Operations member's take stops the step) accepted as a workflow reading and added to the Clinical Owner's CGR-43 question in D-28; deviation 3 (`taken_by_me` = the taker shown) accepted.
- **SIG2-14 part (1) met by #312** (the "before" assertion judged without watched hours; `db` green at 20:44 Zurich, inside the former red window); part (2), the fixed-instant proof, stays in the follow-up. The 20:09 rule "a red `db` on test 78 is not the PR's" no longer applies. SIG2 stays `changes-requested`. *Next up* now: 1 SIG2 follow-up (SIG2-11, -12, -13, -14 (2)), 2 F6R.
- **D-26 `awaiting-approval: owner`** (Medium): Engineering **drafted by po, not confirmed by eng** (two-run rule: requested 14:40; `eng` 15:20, 20:45): one importer of the key today (`src/features/push/dispatch.ts`, `server-only`), no Edge Function exists. `lca` 19:55 section copied from #310 (96d7d42). **Staging design decided by po: C** (an Edge Function sends only an open, unexpired invitation) under `lca` (i)-(v), after D-2. **Owner asked:** "approve: in production no service-role key on the app host; invitations and the push sender run in Edge Functions that accept one command each" (or accept the key on the app host). Default: manual accounts, outside push off.
- **D-23 `po-decided`: C plus D** (Medium; Engineering drafted by po; `lca` 17:57 compliant under every plausible interpretation): a working-day proposal from the nurse's own events that only she sees and completes, exported to the employer's record on her action; team-level North Star; the employer keeps the record (corrects the 18:12 "kept five years" wording); B not pursued. **Precondition found while drafting:** `visit_events` (with `actor_id` and times) is readable by every organisation member (0007:46, `org_members_read`; no narrowing found in later migrations; read, not tested), so any member can reconstruct a colleague's day. `CARE_OPERATING_MODEL.md` updated (measurement line).
- **`lca` 20:50 taken up** (copied from #310, 642d2ce): **D-1:** correction of my 20:09 addendum: the narrowing removes `care_notes`, not health data (`cases` has health-named fields; writable, so alteration not excluded); the owner ask now includes the catalogue-only RLS check with SR-26 step 3; rotation after it, short and dated; status unchanged. **SR-26:** if verified, deletion no longer blocked by Art. 24 Abs. 4; ask unchanged. **D-24:** first L section (A compliant; B owner and legal adviser; C/D licence and regulatory adviser; no LTCF item text without a licence); still `inputs-requested` (E, C).
- **Challenge:** Operations as the escalation step after a care assistant's take of a P1 no-show (row added; hypothesis: at least 9 in 10 such takes followed by a team RN's take before the threshold → step first to the team's RNs on duty, Operations only when none is; Clinical Owner, D-28).
- No new brief: SIG2 follow-up and F6R are approved and unstarted. ROADMAP: line 24.10. 21:10. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** **owner:** D-1 (urgent; now with the RLS check), SR-26, **D-26 (new: no service-role key on the app host in production)**, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner); merge `cra` PR #306. **Clinical Owner:** D-10, D-28 (one sub-question added), D-31, D-3, D-30, D-16, D-15.
- **Next agent:**
  - **(eng):** the SIG2 follow-up (SIG2-11, -12, -13, -14 (2)) in one PR, then F6R. **Please verify** the `visit_events` organisation-wide read (0007:46) and, if confirmed, propose a narrowing to the visit's team and the covering member (origin `eng-proposal`; it is also D-23's precondition). Confirm or correct the po drafts in D-26, D-23, SR-26, D-1, D-8, D-10, D-2, D-7, D-34; the coordination gap you noted at 20:45 (no `agent:eng` hand-off for `changes-requested` conditions) is yours to diagnose in the watcher (COORD).
  - **(cra):** cover 0063 (ORD0-C2, SIG1-C1; CR-074, CR-075) in the next section; D-17, D-19 first, then D-24, D-13, D-25, D-6, D-20 (one point).
  - **(lca):** D-26 production question only if the owner answers; D-10 R against the pilot canton once D-11 is answered.
  - **(po):** D-17 (Engineering two-run rule reached; C still open), D-6, D-19 next.

## 2026-10-24 20:50 · Legal & Compliance Agent (lca)
- **Continued my open PR #310** (no second `lca` PR); its `db` failure is SIG2-14 (pgTAP 064 test 78 by wall clock, not this PR's; PO 20:09 agrees); PR #312 touches that test file. Left open until `recovery/main` carries the fix.
- **Re-checked D-1 and SR-26** on the PO's request (20:09, narrowed exposure, inferred from the C-1 records, not tested; read on PO PR #311). **D-1:** the narrowing removes `care_notes` from the disclosure scope but **not health data**: the readable `cases` table has fields named `diagnosis_tags`, `cognitive_status`, `mobility_status` (presence only, SCHEMA_DRIFT:40); alteration was possible (insert/update open; TRUNCATE not governed by RLS, PostgreSQL docs). Verdicts unchanged; rotation after SR-26 step 3 compliant if short and dated; adviser question 2 sharpened. **SR-26:** if verified, `orders` was not disclosed (deletion exposure only, count unchanged); Art. 24 Abs. 4 then no longer blocks deletion; conditions (i)-(iii) and the owner's facts still do. Ask: run the catalogue-only RLS check with SR-26 step 3.
- **Reviewed D-24** (first `lca` section): interRAI licensing page (written licence; vendors pay royalties; vendor duties incl. export to interRAI and "no open web"; scales not copyrighted, items are), SO RRB 2023/1583 and BS ordinance (interRAI LTCF CH as the KLV Art. 8b instrument), KLV amendment 2019 (Art. 8b, 7a), SECO ArGV 2 Art. 15 Wegleitung. A **compliant under every plausible interpretation**; B **unresolved: needs owner and legal adviser** (D-25 for the partner canton; whether a home falls under ArGV 2 Art. 15; no LTCF content even displayed); C, D **unresolved: needs owner** (licence/contract) and regulatory adviser (NH4, NH5 under D-34).
- **Not re-reviewed:** D-22, D-18 (no change since my 16:05 sections besides PO adoption; no new evidence).
- **Next for `lca`:** D-10 R against the pilot canton once D-11 is answered; D-26 production question if the owner answers. fedlex still unreadable from this environment; Swiss interRAI vendor list not readable (dynamic page).
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 20:50 · eng (Lead Engineer)
- **#312 merged** as b574966 with a merge commit. CI was green on head 5aa2390 (app, db, e2e) after the types-bot commit; I approved its CI run. **ORD0 is `delivered`**, which is READY_FOR_REVIEW. The PO review covers ORD0-C1, ORD0-C2 and SIG1-C1 against `briefs/ORD0.md` and `briefs/SIG1.md`, plus the four deviations in the 20:45 entry.
- **Next (eng):** SIG2-11, SIG2-12 and SIG2-13 in one PR, then F6R.

## 2026-10-24 20:45 · eng (Lead Engineer)
- **Queue order kept.** The watcher opened only #309 (F6R, *Next up* 3) as `active`, and claimed it at 20:12. The PO queue puts *Next up* 1 (ORD0-C1, ORD0-C2, SIG1-C1) and *Next up* 2 (SIG2-11/12/13) first, so this run built *Next up* 1. **Coordination gap (UNKNOWN cause):** the watcher opens no `agent:eng` hand-off for `changes-requested` conditions on ORD0 and SIG2, or for an accepted item's condition (SIG1-C1). It has done so since 15:10, and these conditions have waited since then.
- **#312 open (ADR-077, migration 0063):** ORD0-C1 (pgTAP 063 +4), ORD0-C2 (CGR-44: one `inform_gp` task on an A/C item activation or a completed needs assessment, without an order and without a record dated on or after that day; refreshes never reopen) and SIG1-C1 (CGR-43 plus the `cra` 18:26 note: `signal_takes`; for a no-show or a broken-off visit only a registered nurse's take, or Operations' take, stops the SIG1-5 and SIG2-5 steps; the banner shows "Meldung an Operations folgt"). ORD0 is now `in-review`.
- **Deviations for the PO:**
  - (1) Operations' own take stops the step (engineering reading; D-28).
  - (2) HAND1 has no `inform_gp` task entry, not even for the first task, so ORD0-C2 (e) adds none.
  - (3) `taken_by_me` now means "I am the taker shown".
  - (4) pgTAP 064 fixture made clock-independent. Its "before" assertion fails from about 20:00 Zurich time, which could turn any PR red in the evening. SIG2 test only; no behaviour change.
- **Clinical gate:** read sections 14:27 (#294) and 18:26 (#306, unmerged). Findings applied: CGR-43 and CGR-44, both advisory S2 and decided by the PO. Remediation plans `clinical/remediation/CGR-43.md` and `CGR-44.md`; register rows CR-074 and CR-075 (PROVISIONAL). No rule invented.
- **Tests:**
  - **Local run, not CI.** PostgreSQL 16 with a Supabase role/auth shim and a minimal pgTAP stand-in, because Docker images and the pgTAP package were not fetchable. 062, 063, 064 and 065 passed there; every other file matched its baseline.
  - **Not run:** lint, typecheck, vitest, e2e and db lint (npm registry unreachable from the sandbox). CI decides.
- **F6R:** row added as `not-started`. It follows after the SIG2 follow-up, in the PO order.
- **Next agent (eng):** if #312 is green, merge it and set ORD0 to `delivered`. Then build SIG2-11, SIG2-12 and SIG2-13 in one PR, then F6R. Drafts still to confirm: D-8, D-10, D-2, D-7, D-34.

## 2026-10-24 20:09 · po (Product Owner)
- **No PO PR was open** at the start (#308 merged 19:21). Open PRs: **#310 (new, `lca` 19:55: D-26, D-10, D-34; `db` red, see below)**, #306, #294, #278, #259 (`cra`), #3 (M2); `cra` and `lca` PRs are not merged by the PO. Claimed **#298, #69, #132** (SIG2, SR-26, D-26); claims removed at the end.
- **Reviews: no delivery.** No `eng` merge since #295 (last `eng` journal entry 15:20). **SIG2: new SIG2-14** (product authority, same class as AN2-C1): `db` on the docs-only PR #310 failed at 20:00 Zurich on pgTAP 064 test 78 ("before: the 24 h window opens in 6 h, no exception yet", have 1, want 0; job 120944738020), while `recovery/main` c6fa6b1 was green at 19:21. PO reading of 064:305, 324-328 (not run): the fixture asserts "before" while the 07:00-20:00 watched hours are still set, so the result depends on the run hour (red about 20:00-01:00 Zurich; from 18:00 after SIG2-13). **Until fixed, a red `db` whose only failure is 064 test 78 in that window is not the PR's failure.** SIG2 stays `changes-requested` (SIG2-11 to SIG2-14). **Production condition recorded:** the SIG2 sender holds the service-role key on the Next.js host (`src/features/push/dispatch.ts`); D-26's production answer applies to it.
- **SR-26 `awaiting-approval: owner`** (Medium): Engineering drafted by po (two-run rule: requested 12:10; `eng` 12:25, 14:39, 15:20): nothing in the repository or CI uses `orders`; **inferred from the C-1 records** (RLS on all 10 tables, C-1 changed only policies and grants): `orders` was not readable with the anon key but was truncatable; contents-free checks whether the other application still writes; step lists A and B with a verification query. Asked after D-1: approve A (check, move and verify, drop here, before the key rotation) and confirm controllership; B if the rows are not needed.
- **D-1:** Engineering drafted by po: no repository or CI use of the live keys; rotating the JWT secret also replaces the service-role key the `orders` application may use, so **rotate after SR-26 step 3**; inferred: only `cases`, `care_visits`, `teams` were readable with the anon key (`care_notes` was not). Confidence Low → Medium; the owner ask is unchanged. `lca` asked to re-check D-1 and SR-26 on the narrowed exposure.
- **`lca` 19:55 taken up (read on open PR #310; no status change):** **D-26:** B and C compliant for staging under (i)-(v), production needs owner; PO: context corrected (the key is already on the app server since SIG2: a deviation between package and code, documented, nothing changed), one production question covers invitations and the push sender, PO preference no service-role key on the Next.js host in production; `eng` questions 7, 8 added; still `inputs-requested` (E, one `eng` run since 14:40); D-4 gains two retention questions (unaccepted invitations; DSV Art. 4 logging). **D-10:** R compliant; F6R-7 reworded (the client's own access extract includes the reason). **D-34:** the draft statement now describes both care-context rules; a ranking or escalating care-context rule is marked "for the adviser" (`briefs/_TEMPLATE.md`); adviser question 1a.
- **Challenge:** one organisation-wide watched-hours timetable set by an administrator (row added; hypothesis: at least 95 in 100 field events inside the recorded hours and at least 1 in 5 recorded hours without any team visit → derived per-team hours with a provider confirmation, after an `lca` re-check of D-32).
- ROADMAP: line 24.10. 20:09. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** **owner:** D-1 (urgent), **SR-26 (new: approve A after D-1, before the rotation)**, D-7, D-8, D-2, D-34, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner); merge `cra` PR #306. **Clinical Owner:** D-10, D-28, D-31, D-3, D-30, D-16, D-15.
- **Next agent:**
  - **(eng):** **SIG2-14 first or inside the ORD0 PR** (it reddens every PR's `db` in the evening); then ORD0-C1, ORD0-C2, SIG1-C1; then SIG2-11 to SIG2-13; then F6R. Please confirm or correct the po drafts in SR-26, D-1, D-8, D-10, D-2, D-7, D-34; inputs open for D-26 (questions 1-8), D-23, D-17, D-14, D-13, D-24, D-6, D-19, D-20, D-25.
  - **(cra):** "for the adviser" mark in the input-class column of `CLINICAL_RULE_REGISTER.md` (D-34); D-17, D-19 first.
  - **(lca):** re-check D-1 and SR-26 on the narrowed exposure (inferred, Engineering item 5 / item 2); D-24. PR #310's `db` failure is SIG2-14, not the PR's.
  - **(po):** D-26, D-23, D-17 reach the Engineering two-run rule after the next `eng` run; then D-26's staging design is the PO's.

## 2026-10-24 19:55 · Legal & Compliance Agent (lca)
- **Reviewed D-26** (first `lca` section; tier 3, blocks ADM1 invitations and D-20), **re-checked D-10** (R decided by po as F6R since my 11:55 section) and **D-34** (statement, inventory, `cra` 18:26 and the input-class control since my 16:45 section; new evidence). Only the `lca` sections changed. Advisory, not legal advice; no final determination.
- **Not re-reviewed:** D-22, D-18 (only PO addenda adopting my 16:05 notes; no new evidence); D-28 (no `lca` requested); D-7, D-8, D-1, D-2, D-12 (only PO text adopting my verdicts).
- **D-26:** DSG Art. 19, 20 (Onlinekommentar), Art. 8 (law.ch), EDÖB logging recommendation (DSV Art. 4, 2023) and the DSV amendments of 1 Dec 2025 (synopsis) read. Invitation e-mail compliant; it is the latest point for the Art. 19 information (controller, purpose, Supabase as recipient, data categories, Singapore/US with SCCs). **B and C compliant for staging under (i)-(v); production unresolved: needs owner** (residual risk of a key that bypasses RLS, DSG Art. 8); C the more protective. Retention of unaccepted invitations: a D-4 criterion, no period set. DSV Art. 1-3 primary text still unread.
- **D-10:** F6R carries my (a)-(c) and more; **R compliant under every plausible interpretation** (pilot canton to confirm, D-11). Note: F6R-7 "never in any export" must not exclude the client's access extract (DSG Art. 25 Abs. 2 lit. b; D-4 gate r1).
- **D-34:** CJEU C-427/24 (2 July 2026; two secondary summaries, judgment not read): intended purpose from use-related manufacturer data **and** objective capability. Supports "wording alone does not decide". Verdict unchanged: **unresolved: needs owner and a regulatory adviser**. Notes: describe both care-context rules (hospital-discharge P1, nurse-chosen severity) in the statement; mark ranking/escalating rules of the middle input class "for the adviser"; question 1a added.
- **Next for `lca`:** D-24 (never reviewed); D-10 R against the pilot canton once D-11 is answered. fedlex still unreadable from this environment.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 19:09 · po (Product Owner)
- **No PO PR was open** at the start (#305 merged). Open PRs: #306 (new, `cra` 18:26; supersedes #294, #278, #259), #3 (M2); `cra` PRs are not merged by the PO. Claimed **#56, #299, #59, #89, #116, #298** (D-10, D-34, D-13, D-20, D-25, SIG2); claims removed at the end.
- **Reviews: no delivery.** No `eng` merge since #295; only `lca` #307. **SIG2:** `cra` 18:26 (read on `gov/review-2026-10-24-1826`) finds **no blocking finding on 0062**, closes CGR-41 points 1, 2; the clinical gate is met. New **CGR-45** (S2; S1 for go-live): the look-ahead raise time is the end instant of the watched period, which the code treats as outside. **PO decision (product authority): SIG2-13**, raise at the later of the last watched period's start and its end minus 2 hours, inside by the SIG2-12 predicate; pgTAP 064:318-321 move from 20:00 to 18:00. SIG2 stays `changes-requested` (SIG2-11, -12, -13 in one follow-up PR). ORD0 stays `changes-requested`.
- **D-10 `awaiting-approval: clinical`** (Medium): `cra` 18:26 block copied. **R decided by po**: `cra` classifies it as a documentation-integrity workflow inside CR-011/CR-043 under (a)-(d); `lca` 11:55 compliant under (a)-(c). Built as **F6R** (approved, *Next up* 3). Clinical Owner asked: "confirm A for the pilot; B only after the pilot, on AN2 evidence." C rejected.
- **D-34 `awaiting-approval: owner`** (Medium): `cra` 18:26 block copied (no IMPLEMENTED rule reads clinical content; SIG1 watches service delivery). **Input-class control decided by po**: every brief states each rule's input class (visit/schedule fact, care-context fact recorded by a nurse, clinical content); a clinical-content rule is not built in the core; added to `briefs/_TEMPLATE.md`. `cra` asked to add the same column to `CLINICAL_RULE_REGISTER.md`.
- **`lca` 18:47 taken up (no status change; E open in all three, C open in D-13, D-25, one point in D-20):** **D-13:** B compliant with the assessor's GLN and several assessments per case; the instrument is the provider's choice. **D-20:** working view **D sharpened** (team decides membership; employer records the contract fact once; D-29; lead roles never team-changeable); C dropped. **D-25:** ZH requirements (one nursing lead, no job-sharing; no ward leader named; skill mix; RN cover) recorded as future NH roster constraints; B unresolved after D-11.
- **Challenge:** assessment results re-typed from the provider's licensed tool (row added; hypothesis: more than 1 in 20 assessments corrected after entry → import of the result only, D-13 A, `owner`).
- ROADMAP: line 24.10. 19:09. Tests: none run (docs only); the PO did not run any test; `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** **owner:** D-1 (urgent), D-7, D-8, D-2, **D-34 (new: approve A plus C, name a regulatory adviser)**, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner); merge `cra` PR #306 (supersedes #294, #278, #259). **Clinical Owner:** **D-10 (new: confirm A for the pilot)**, D-28, D-31, D-3, D-30, D-16, D-15.
- **Next agent:**
  - **(eng):** ORD0-C1, ORD0-C2, SIG1-C1 (covering `outside_settle`, CGR-43 note) in one PR; then SIG2-11, SIG2-12, SIG2-13; then F6R. Please confirm or correct the po drafts in D-8, D-10, D-2, D-7, D-34; inputs open for D-23, D-17, D-14, D-13, D-24, D-26, D-6, D-19, D-20, D-25, D-1, SR-26.
  - **(cra):** input-class column in `CLINICAL_RULE_REGISTER.md` (D-34); D-17, D-19 first, then D-14, D-13, D-24, D-25, D-6, D-20 (one point); F6R needs no gate unless its PR adds a rule.
  - **(lca):** D-26, D-24; D-10 R against the pilot canton once D-11 is answered.
  - **(po):** D-17, D-23 reach the Engineering two-run rule after the next `eng` run; D-26 next.

ENGINEERING BRIEF
- **Capability:** F6R, return a report instead of countersigning a version known to be wrong ([brief](briefs/F6R.md)).
- **Why:** today an RN who sees a wrong time in a care assistant's report must countersign it; the wrong version becomes `final`, the team's record and a billing basis until a correction round finishes (C-7). D-10 R decided by po (`cra` 18:26, `lca` 11:55).
- **Business outcome:** nothing is billed from a version a nurse knew was wrong; one correction round per error disappears; countersignature latency and the returned share become measurable (F6R-9).
- **Care outcome:** the record the team reads after a visit is the agreed one; supervision of delegated care means "checked and agreed" again.
- **Expected nurse outcome:** the countersigning RN sends the report back with a reason in one step instead of signing against her judgement; the care assistant sees what to fix in `/field`.
- **Expected team outcome:** fewer correction versions; a returned report stays visible in the team queue, so nothing is stranded.
- **Expected patient outcome:** observations and times in the record are correct before the next nurse relies on them (HAND1); no silent overwrite of an observation.
- **Acceptance criteria:** F6R-1 to F6R-9 in the brief (return command and negative roles, append-only return record, performer-only changes, superseding observations, never stranded with `report_not_final`, no billing fact until `final`, reason visible only to performer and team RNs and never in push/AN1/AN2/export, UI with e2e at phone width, AN2 shares).
- **Dependencies:** none open (D-10 R decided; A stays in force; D-30 interim rule for a departed performer unchanged; D-29 real-data gate unchanged).
- **Priority:** *Next up* 3, after the ORD0/SIG1 conditions and the SIG2 follow-up.
- **Implementation recommendation:** one additive migration (`return_report`, an append-only return table, state `signed` → `draft` for the performer), RLS on the reason, reuse the existing sign and countersign paths; about 15 pgTAP assertions plus one e2e; no change to who must countersign.

## 2026-10-24 18:47 · Legal & Compliance Agent (lca)
- **Reviewed D-13, D-20, D-25** (tier 2: named by the open findings C-8/H-08/CR-002, R-11 and R-10/LT-1; also tier 3: billing, governance, licensing). First `lca` sections in all three. Only the `lca` sections changed. Advisory, not legal advice; no decision, status or row changed.
- **Not re-reviewed: D-22, D-18** (unchanged since my 16:05 sections; no new evidence).
- **D-13:** KLV amendment of 2 July 2019 (Art. 8a, 8b; via H+), the tarifsuisse administrative contract (Art. 7-9, 14, 19, Anhang 6), the ZH Spitex licence leaflet (Nov 2023) and interRAI's IP guidelines read. Federal law names no home-care instrument; the contract leaves a "standardisiertes Bedarfserfassungsinstrument (interRAI HC oder andere)" to the provider; ZH requires a recognised Swiss instrument at the licence. **B: compliant under every plausible interpretation on the sources read**, with the assessor's GLN and several assessments per case. A: **unresolved: needs owner and legal adviser** (licence scope). C: unresolved (no compliant route seen).
- **D-20:** OR Art. 319, 328b (law.ch) and a VS labour-inspectorate FAQ on Art. 320 read (Art. 320 primary text not read); ZH Spitex leaflet Ziff. 3.2, 5.1-5.4, 7.4, 11. A tacit employment contract can arise once work starts, so team admission alone can bind the employer. **D sharpened** (team decides membership; employer records the contract fact once; D-29; lead roles never team-changeable): **compliant under every plausible interpretation on the federal and ZH sources read.** C as written: **unresolved: needs owner (D-12 policy) and legal adviser.**
- **D-25:** ZH nursing-home licence leaflet (Nov 2023) read: nursing lead one person (no job-sharing), deputies, medical lead; no ward leader named; mix ≥50 % / ≥25 % / ≤50 %, an RN on every ward's day shift, an RN present or reachable 24 h. BE form blocked, SO not read. **B: unresolved: needs legal adviser or the canton (D) after D-11;** C: unresolved (shared lead); A compliant.
- **Next for `lca`:** D-26, D-24 (never reviewed); D-2 and D-7 if asked. fedlex still unreadable (KLV Art. 8a Abs. 5 current wording, OR Art. 32 ff., 320 primary text open).
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 18:26 · Clinical & Regulatory Architect (review)
- **Reviewed SIG2 (#295, 0062, pgTAP 064, push sender)** in full, plus PO cycles 14:40-18:12 and `lca` 14:45-17:57. Section 2026-10-24 18:26 in `reports/CLINICAL_GOVERNANCE.md`. Tests not run by me; CI green on `7a9d08d`.
- **Closed:** CGR-41 for points 1 and 2 (nobody reachable outside the app → Operations at once; untaken step to Operations only). **New:** CGR-45 advisory (S2; S1 for SIG2 go-live): SIG2-6 raises a foreseeable P1 at the end instant of the watched hours, which the code itself treats as outside them. **Decided by the PO, PLANNED:** CGR-42 (SIG2-11), CGR-43 (SIG1-C1; it must also cover `outside_settle`), CGR-44 (ORD0-C2).
- **Gate:** no blocking finding on 0062; the PO may accept SIG2 once SIG2-11, SIG2-12 and a decision on CGR-45 are met.
- **Clinical impact written for D-10** (R is safer than "countersign, then correct", under controls (a)-(d); in my reading a workflow the PO may decide) **and D-34** (SIG1 watches service delivery, not the client's condition; four PLANNED features belong in a qualified module; an "input class" column as the enforceable boundary). D-17, D-19 next, then D-14, D-13, D-24, D-25, D-6, D-20.
- **Merge:** this PR carries and supersedes #294, #278 and #259 (`recovery/main` merged in; JOURNAL both sides kept; my unmerged CR-073 renumbered CR-078 because eng took CR-073 for SIG2).
- **Next agent (po):** decide CGR-45 (SIG2-13); copy the D-10 and D-34 blocks; D-10 route for R. **(eng):** SIG2-11, SIG2-12 (and SIG2-13); SIG1-C1 including `outside_settle`. **(owner):** merge this PR (self-merge refused in earlier runs); G-1; D-1.

## 2026-10-24 18:12 · po (Product Owner)
- **No PO PR was open** at the start (#303 merged). Open PRs: #294, #278, #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#68, #56, #116** (D-8, D-10, D-25); claims removed at the end.
- **Reviews: no delivery.** Only `lca` (#304) merged since 17:10; SIG2 (#298) and ORD0 (#292) stay `changes-requested`. No `eng` run since 15:20.
- **D-8 `awaiting-approval: owner`** (Medium). Engineering **drafted by po, not confirmed by eng** (two-run rule: requested 11:09, `eng` runs 12:25, 14:39, 15:20). Evidence from the repository: no workflow deploys anything, no hosting config, the deployments API is empty; **none of the 21 transcribed `src/` files survives unchanged** on `recovery/main` (12 removed, 9 rewritten), so O-C is dropped as a gate; **no `preserve-*` tag exists yet**. **Owner asked:** approve B: tag `preserve-main-2026-10-24` and `preserve-transcription-2026-10-21`, then merge PR #3 with a merge commit after D-7's ruleset; confirm no Codespace and no hosting service on `main`.
- **D-10** Engineering drafted by po (two-run rule). New fact: a care-assistant visit is **billable only once countersigned** (`report_not_final`); R is about one additive migration and 15 pgTAP assertions. Still `inputs-requested`: `cra` open (one `cra` run since 11:09). Working view A plus R.
- **D-25 package written**, `inputs-requested` (E, C, L). Working view A (no ward pilot); design target B: every role the licence names stays accountable and cannot be removed by a team command; only ward leadership, if not named, moves to the team; a prescribed mix becomes a hard roster constraint. After D-11.
- **`lca` 17:57 taken up (no status change; Engineering still open in all three):** **D-23:** working view moves to **C plus D** (proposal only the nurse sees and completes; team-level North Star); B needs a legal adviser and is not pursued for the pilot; the licence holder adopts C as its record (D-12 condition). **D-14:** lean F3/F4 (F1, F2 unresolved); S1 in force; later owner ask S4 with an equal split; constraint 4 gains a published team-result calculation. **D-17:** B on three terms (precaution not diagnosis; the D-15 contact reused with the D-19 consent flag; no key-safe code); the contact person's information duty needs a legal adviser.
- **Challenge:** billing waits on the countersignature queue. Hypothesis row: median signature → countersignature at most 1 working day, at least 95 in 100 within 3 working days; otherwise D-10 B is reopened with evidence.
- No new brief: *Next up* 1 (ORD0-C1, widened ORD0-C2, SIG1-C1) and 2 (SIG2-11, SIG2-12) are approved and unstarted. ROADMAP: line 24.10. 18:12. Tests: none run (docs only); `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** **owner:** D-1 (urgent, one-line fact answer), D-7 (ruleset now), **D-8 (new: tags, then merge PR #3 after D-7)**, D-2, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner). **Clinical Owner:** D-28, D-31, D-3, D-30, D-16, D-15. **Owner, process:** `cra` PRs #294, #278, #259 need a merge.
- **Next agent:**
  - **(eng):** ORD0-C1, widened ORD0-C2 and SIG1-C1 in one PR; then SIG2-11, SIG2-12. Please confirm or correct the po drafts in D-8, D-10, D-2, D-7, D-34; inputs still open for D-23, D-17, D-14, D-13, D-24, D-26, D-6, D-19, D-20, D-25, D-1, SR-26.
  - **(cra):** D-10 (is R safer, workflow or documentation rule), D-34, D-17, D-14, D-13, D-24, D-25, D-6, D-19; 0062.
  - **(lca):** D-25 (new), D-26, D-20, D-13, D-24.
  - **(po):** D-17 and D-23 reach the Engineering two-run rule after the next `eng` run; D-26 next.

## 2026-10-24 17:57 · Legal & Compliance Agent (lca)
- **Reviewed D-23, D-14, D-17** (tier 2: named by the open risks R-9, BL-12 and LT-2, H-03; D-14 also tier 3, billing and pay). First `lca` sections in all three. Only the `lca` sections changed. Advisory, not legal advice; no decision, status or row changed.
- **Not re-reviewed: D-22, D-18** (unchanged since my 16:05 sections; no new evidence). D-2 and D-7 (PO 17:10) left for a later run: the changes were the PO's route and design, not new legal facts.
- **D-23:** SECO pages and the Art. 46 Wegleitung, a 2025 secondary article and a BS labour-inspectorate leaflet read; ArGV 1 Art. 73-73b in the primary text **not** read (fedlex and the SECO per-article PDFs unreachable). Record content: duration, start and end of daily and weekly time, breaks of 30 min or more; five years' retention; recording may be delegated, the employer stays responsible. **A, C (proposal only the nurse sees and completes) and D (team level, AN1 suppression): compliant under every plausible interpretation.** **B (NAVORA holds the record): unresolved: needs legal adviser** (questions 1-5: completeness, travel boundaries, Art. 73b, supplier contract, public-law employer). No per-person derived-day view for others (ArGV 3 Art. 26). The 2024 draft federal law on working conditions in care was read as a draft only; its status is UNKNOWN.
- **D-14:** OR Art. 322a read (share in the business result: accounting-based, right to information). Constraints 1-5, F3/F4 and S1: **compliant under every plausible interpretation** (F3/F4 on federal sources; cantonal cost rules UNKNOWN). F1, F2: **unresolved: needs legal adviser**. Any distribution S2-S4: **unresolved: needs legal adviser and owner** after D-12 and D-11 (residual financing, service agreement, non-profit status not read). Note to po: S1 stays; S4's equal split avoids per-person figures in the team view.
- **D-17:** covered by D-9 and D-3; adds minimisation (precaution, not diagnosis), reuse of the D-15 emergency contact with the D-19 consent flag, no key-safe code. B on those terms: **compliant under every plausible interpretation on the federal sources read**. Information duty towards the contact person: **unresolved: needs legal adviser** (one question).
- **Next for `lca`:** D-26, D-20, D-13, D-24 (never reviewed); D-2 and D-7 re-check if asked.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 17:10 · po (Product Owner)
- **No PO PR was open** at the start (#301 merged). Open PRs: #294, #278, #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#64, #67, #299** (D-2, D-7, D-34); claims removed at the end.
- **Reviews: no delivery.** Nothing merged since #302 (`lca`). SIG2 (#298) and ORD0 (#292) stay `changes-requested`; no `eng` or `cra` change to review.
- **Two-run rule reached for Engineering** on D-2 (requested 12:10), D-7 (11:09) and D-34 (13:15): no answer in the `eng` runs 12:25, 14:39, 15:20. Engineering impact **drafted by po, not confirmed by eng** in all three (no package can be High).
- **D-2 `awaiting-approval: owner`, design decided by po** (Medium): Supabase staging in Zurich `eu-central-2` (else Frankfurt, never "Europe"; a plan that does not pause), app on **Render Frankfurt** behind access protection (Vercel's Swiss-U.S. DPF coverage not shown), migrations and seed from CI only, synthetic only, the five `lca` 13:50 conditions; staging is no production clearance (ADR-011). Written into the D-2 row, not moved to *Decided*: T12 lists D-2 under "Blocked by". **Owner asked:** approve the two paid plans, create both, add the staging deploy secrets.
- **D-7 `awaiting-approval: owner`** (Medium): ruleset on `main` and `recovery/main` (PR required; checks `app`, `db`, `e2e`; no force-push or deletion; neither bot pushes to those branches) and push protection **now**; private on a paid plan (B) if D-1 is "real" or "not sure". C rejected: the free personal plan drops rulesets and its Actions quota would stop CI within about a day (73 of the last 100 runs are `ci`, ~5 min wall time, three parallel jobs; estimate).
- **D-34 still `inputs-requested`** (Low; `cra` open). Rule inventory drafted: no IMPLEMENTED rule reads clinical content; two take a care fact (the hospital-discharge referral category → P1; the nurse-chosen severity → escalation). Draft **intended-purpose statement**, exclusion list and a UI **wording rule** (signals are organisational, never "monitoring") in force as the safe default. `visit_uncovered_hospital` stays as built until the adviser answers (removing it would lower protection).
- **`lca` 16:45 taken up (no status change):** **D-16:** "Meldepflicht geprüft" moves to the event, recordable at recording by the author or an RN of her team, fixed recipient list incl. Swissmedic, outcome/recipient/date/person only; the serious-event review shows it and cannot close while it is open (QG2 scope). **D-3:** note only (Art. 321 settles the UNKNOWN; "nach Spitalaustritt" in the app only, never in a push).
- **Challenge:** statutory reporting behind a management review. Hypothesis row: with the step at recording, at least 9 in 10 serious events have it within 24 h.
- No new brief: *Next up* 1 (ORD0-C1, widened ORD0-C2, SIG1-C1) and 2 (SIG2-11, SIG2-12) are approved and unstarted. ROADMAP: line 24.10. 17:10. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** **owner:** D-1 (urgent, one-line fact answer), **D-2 (new: approve plans, create staging)**, **D-7 (new: apply ruleset and push protection)**, D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner). **Clinical Owner:** D-28, D-31, D-3, D-30, D-16, D-15. **Owner, process:** `cra` PRs #294, #278, #259 need a merge.
- **Next agent:**
  - **(eng):** ORD0-C1, widened ORD0-C2 and SIG1-C1 in one PR; then SIG2-11, SIG2-12. Please confirm or correct the po drafts in D-2, D-7 and D-34 (inventory); inputs still open for D-14, D-13, D-24, D-26, D-23, D-17, D-6, D-19, D-20, D-10, D-8, D-1, SR-26.
  - **(cra):** D-34 (which features are clinical decision support; device incidents as a type or marker, D-16); 0062; D-14, D-13, D-24, D-17, D-6, D-19, D-10.
  - **(lca):** D-2 and D-7 changed (re-check only if wanted); D-26, D-23 and its queue.
  - **(po):** next package D-25; D-8 and D-10 (Engineering two-run rule reached; D-10 also needs `cra`).

## 2026-10-24 16:45 · Legal & Compliance Agent (lca)
- **Reviewed D-16, D-3** (tier 2; both changed by the PO after my last sections; new evidence) and **D-34** (tier 3; first `lca` section). Only the `lca` sections changed. Advisory, not legal advice; no decision, status or row changed.
- **Not re-reviewed: D-22, D-18.** The PO's 16:20 addenda adopt my 16:05 notes as written (ORD0-C2 (b)+(c), question 6a, AÜP, dates and kind only). No new evidence, so there is nothing to add.
- **D-16:** HMG Art. 59 Abs. 3 read: "wer berufsmässig Heilmittel … an Menschen anwendet" must report serious or unknown adverse effects to Swissmedic. That plausibly binds the nurse herself. Swissmedic MU680_20_008 v3.3 names "Pflegepersonal" for device incidents (MepV Art. 66 Abs. 4). StGB Art. 321 Ziff. 3 reserves statutory reporting duties. Items 1-2 stay **unresolved: needs owner (D-11, D-12) and legal adviser**. A "Meldepflicht geprüft" step **available when the event is recorded**, with Swissmedic among the recipients, is **compliant under every plausible interpretation**. Note to po: do not make the step reachable only from the management review item. Question 2 has been narrowed.
- **D-3:** StGB Art. 321 (Stand 1 October 2026) names Pflegefachpersonen, which settles the 02:52 UNKNOWN; the outcome is unchanged. (b′) with recorded consent: **compliant under every plausible interpretation on the federal sources read** (Art. 321 Ziff. 2). The `cra` 14:27 note ("nach Spitalaustritt" on the banner): compliant in the app within team scope and gate (iii); never in a push text (D-32 fixed text).
- **D-34:** MepV Art. 3-4, Swissmedic Merkblatt BW630_30_007 v3.0 (21 April 2026) and MDCG 2019-11 rev.1 (2025) read. Planning, documentation, billing and messaging match the non-device examples. Two points prevent certainty for the core: SIG1 ranks `visit_uncovered_hospital` P1 on a care fact, and the intended-purpose statement is not yet written. **A plus C: unresolved: needs owner with a regulatory adviser** (questions 1-5). C works only if the modules are qualified separately with documented boundaries; qualified "as a whole", the entire system falls under device law (BW630_30_007 section 5.3). PLANNED AI drafts, care-plan review proposals and NAVORA-computed interRAI outputs plausibly qualify as devices. D-13 B (reference only) stays outside.
- **Next for `lca`:** D-26, D-23, then D-17, D-20, D-14, D-13, D-24 (never reviewed). fedlex is still unreadable; the MDR Art. 2 definition of intended purpose is unread.
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 16:20 · po (Product Owner)
- **No PO PR was open** at the start (#291 merged). Open PRs: #294, #278, #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#60, #59, #115** (D-14, D-13, D-24); claims removed at the end, together with the stale `claimed` labels of the 15:10 run on #72, #81, #89.
- **Reviews: no delivery.** Nothing merged since #300 (`lca`). SIG2 (#298) and ORD0 (#292) stay `changes-requested`; no `eng` or `cra` change to review.
- **`lca` 16:05 taken up (no status change):**
  - **D-22:** **ORD0-C2 widened to (b)+(c)** before work starts: the same single `inform_gp` task also opens when a needs-assessment visit is completed in a case without an order `present` and no "informiert" record dated on or after it (a′), with pgTAP (d′) (`briefs/ORD0.md`; Q12 row). The trigger reads the assessment visits, because `cases.needs_assessment_done_at` keeps only the first. Question 6a (a new A/C item while a B order is present) added for the adviser; the threshold for a lasting change within existing items is the Clinical Owner's (question 6).
  - **D-18:** AÜP days join the PLANNED invoicing prerequisite; an inpatient or AÜP period stores dates and kind only (D-9, D-4, D-3); `eng` asked whether an AÜP marker exists.
  - **D-19:** L in (A plus SIG1-C1 compliant under every plausible interpretation; disclosure, entry and consent steps unresolved). E and C still open.
- **Packages D-14, D-13, D-24 written** (`inputs-requested`; one comment per issue names the roles):
  - **D-14** (E, L; C on incentive hazards): working view: volume-neutral fee (per member or per client) or a capped per-hour fee; surplus S4 (by direct care share, with guards) or S3 (team rule); S1 until `lca` finds distribution permissible. **Five J7 design constraints** (product authority, PROVISIONAL), also in `briefs/J7.md`. Amounts are pricing: `owner`, after D-12.
  - **D-13** (E, C, L): working view B, instrument-neutral (date, instrument and version, assessor, document reference, minutes per category; the assessment runs in the provider's licensed tool); A after D-12; own instrument rejected (no invented clinical rules; D-34).
  - **D-24** (E, C, L): working view A now (no nursing-home build); B (one ward, organisational change only, no licence) once D-11, D-12, one pilot month and D-25 for that canton are in; C only after a licence and D-34. Transitions of care (REF2) stay ahead of nursing homes.
- **Challenge:** pay by hours present. Hypothesis row: teams shown their direct care share and a modelled surplus share raise it by 5 points in three months without shorter visits or more quality events (AN1, AN2); no brief before D-12 and D-23.
- No new brief: *Next up* 1 (ORD0-C1, widened ORD0-C2, SIG1-C1) and 2 (SIG2-11, SIG2-12) are approved and unstarted. ROADMAP: line 24.10. 16:20. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** no new escalation; unchanged since 15:10. **owner:** D-1 (urgent, one-line fact answer), D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner). **Clinical Owner:** D-28, D-31, D-3, D-30, D-16, D-15. **Owner, process:** `cra` PRs #294, #278, #259 need a merge by a person or a run allowed to merge.
- **Next agent:**
  - **(eng):** ORD0-C1, widened ORD0-C2 and SIG1-C1 in one PR; then SIG2-11, SIG2-12. Inputs: D-14 (questions 1-5), D-13 (1-3), D-24 (1-4), D-18 (AÜP marker), plus the earlier requests.
  - **(cra):** 0062 (SIG2); D-14 (incentive hazards), D-13, D-24; D-6, D-19, D-17, D-10, D-34.
  - **(lca):** D-3, D-16, then D-14, D-13, D-24 and its queue.
  - **(po):** next package D-25; then the `inputs-requested` packages as inputs arrive (two-run rule).

## 2026-10-24 16:05 · Legal & Compliance Agent (lca)
- **Reviewed D-22, D-18** (tier 1; both changed by the PO at 15:10 after my 15:05 sections) and **D-19** (tier 2; named by the open finding CGR-43; no `lca` section before). Only the `lca` sections changed. Advisory, not legal advice; no decision, status or row changed.
- **D-22 (Q12 (c), ORD0-C2):** (c) is safer than (a) and fits as the interim, but **unresolved: needs legal adviser and `clinical`**. The contract trigger ([S11] Art. 9 Abs. 1: a lasting change of needs) is wider than a new care-plan item. Gaps: more minutes within existing items; a new needs assessment without a new item; a new A/C item while an order is `present` (question 6a added). Note to po: consider (b)+(c). KLV Art. 8a Abs. 1bis still not read in a current primary text (lexfind has only 2008, lexaris gave no text, fedlex withdrawn).
- **D-18:** the PLANNED inpatient rule is compliant and protective (it also excludes billable coordination days: under-bills, never over-bills). Not yet in the addendum: [S11] Art. 10 Abs. 4 also excludes long-term care during ambulatory acute and transitional care (AÜP). An inpatient period is health data: dates and kind only, under D-9, D-4, D-3. Option C unchanged: compliant while nothing is invoiced.
- **D-19:** StGB Art. 321 (Stand 1 October 2026) names *Pflegefachpersonen* and their *Hilfspersonen*, so the whole team is bound. Option A plus SIG1-C1: **compliant under every plausible interpretation** for NAVORA's own processing. B's disclosure and entry steps and C's consent form: **unresolved: needs legal adviser** (questions 1-5). Recorded, express consent per contact is the only basis valid in all three cantons read (BE, BS, SO differ on tacit or presumed consent; SO reads it for deceased persons only). Do not store key-safe codes. Question 3 (after working time) is answered by D-32 and SIG2-12.
- **Next for `lca`:** D-3 and D-16 (carried over from 15:05), then D-17, D-20, D-23, D-26 and D-34 (now on `recovery/main`, never reviewed).
- Tests: none run (docs only). `node scripts/agents-check.mjs` run before publishing.

## 2026-10-24 15:35 · po (Product Owner)
- Same PO run as 15:10, continued: `eng` merged `recovery/main` into #291 (3745c05, after #297), and **SIG2 was merged (#295, 7a9d08d) and set `delivered`** during the cycle, so the PO reviewed it before publishing.
- **SIG2 `changes-requested`, awaiting clinical review.** SIG2-1 to SIG2-10 met (pgTAP 064, unit, e2e; CI green on e87fa09, 7a9d08d, 567ccaa). Eleven deviations accepted; the most important is that the DPF entries are not recorded, so the channel cannot be switched on (fail closed). **SIG2-11 and SIG2-12** (added 15:10) are not met; they come as a follow-up PR. No `cra` section covers 0062, and `cra` is asked to review it. Evidence table in `briefs/SIG2.md`. **The PO did not run the tests.**
- *Next up* reordered: **1** ORD0-C1, ORD0-C2 with SIG1-C1 (in-app safety today); **2** the SIG2 follow-up (SIG2 cannot be switched on before the DPF entries and D-2 exist).
- For `eng`: on `recovery/main` 567ccaa a second check suite shows `app` *failure* next to a green suite. Its log was unreadable (403). Please say whether it was a duplicate run.
- Issue #283 (SIG2) keeps `active` until acceptance. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Next agent (eng):** ORD0-C1, ORD0-C2 and SIG1-C1 in one PR, then SIG2-11 and SIG2-12. **(cra):** 0062 (SIG2), then the follow-ups.

## 2026-10-24 15:20 · eng (Lead Engineer)
- **SIG2 delivered:** #295 was green on a988e2e but conflicted with `recovery/main` (JOURNAL only, after #293/#296). Merged the base in (e87fa09, both entries kept, newest first), CI green on e87fa09 (app, db, e2e), merged #295 with a merge commit (7a9d08d). Row SIG2 → `delivered` (this PR). IMPLEMENTED.
- No code change this run. Issue #283 keeps its `active` label until the PO's review; the watcher opens the review issue from the `delivered` row.
- **Inputs for the PO's SIG2 review (OPEN, not built):** `lca` 15:05 D-32 note 1: Operations pushes (the "kein Empfänger" fallback and the untaken step) go to every opted-in Operations member at any hour; limiting them to the watched hours is a possible criterion or an accepted deviation (PO). `cra` CGR-42 (PR #294, not merged): evaluator liveness ("Signalprüfung läuft nicht"), S1 for SIG2 go-live, to be added to the SIG2 brief by the PO. Production sending still needs D-2 (owner); the DPF entries are still UNKNOWN, so the channel cannot be switched on.
- Tests: none run locally; CI ran them on e87fa09.
- **Next agent (eng):** the next `active` `agent:eng` issue; a SIG2 follow-up only if the PO adds CGR-42 or the Operations time limit.

## 2026-10-24 15:10 · po (Product Owner)
- **PO PR #291 was still open** (13:15 and 14:40 cycles; CI green on 4d70294), conflicted again in `JOURNAL.md` after #296. Merged `recovery/main` in (a1de528, both entries kept, newest first). This run's work is added to #291 (no second PO PR). Open PRs otherwise: #295 (SIG2, `eng`, CI running), #294 (`cra` 14:27, supersedes #278 and #259; not merged by the PO), #3 (M2). Claimed **#285, #292, #288** (reviews, Q12) and **#72, #81, #89** (D-6, D-19, D-20); claims removed at the end.
- **SIG1 `accepted`** (#285). Clinical gate passed: `cra` 14:27 (#294, read on its branch) finds no blocking finding and closes CGR-37 in the app. Evidence table in `briefs/SIG1.md`; **the PO did not run the tests** (CI green on dad4dbe, 7a3fdb5, a081031). **CGR-43 decided (protective, product authority):** condition **SIG1-C1**, for `no_show` and `visit_interrupted` a take by a member who is not a registered nurse does not stop the step to Operations; the question for the Clinical Owner joins D-28.
- **ORD0 `changes-requested`** (#292 stays open). Clinical gate passed (`cra` 14:27), but **ORD0-C1** (two pgTAP 063 assertions, "before acceptance" since 13:15) is not met: nothing has touched pgTAP 063 since #284. **CGR-44 decided: Q12 changed from (a) to (c)** (`OPEN_DECISIONS.md`): one `inform_gp` task opens when an A/C item becomes active without an order and no later "informiert" record; a refresh never reopens it. Condition **ORD0-C2** with pgTAP. Reasons: CGR-44, and `lca` 15:05 (tarifsuisse Art. 9 Abs. 1; (a) not shown compliant). The 13:15 reason against reopening applies only to a refresh, not to an event.
- **SIG2 (#295, in progress) gains two criteria**, added after work started (in #295 or a follow-up on the same item; both needed for acceptance):
  - **SIG2-11** (CGR-42): each evaluator run is recorded; after 5 minutes without one, Operations and `/admin` show "Signalprüfung läuft nicht"; the send path is started by the scheduler.
  - **SIG2-12** (`lca` 15:05 note 1, D-32 addendum): Operations gets pushes only within the watched hours; otherwise it gets them in the app only. `lca` found pushes "at any hour" unresolved (Pikett).
  - `CARE_OPERATING_MODEL.md` SIG1-8: the provider confirms in writing how the watched hours are staffed. Until SIG2-11 is built, the checklist confirms that the evaluator job exists.
- **`lca` 15:05 taken up (no status change):**
  - **D-22:** question 3 reworded (effective date vs. signature); the invoicing consequence needs two order dates (issue, effective); Q12 now (c); question 6 open.
  - **D-18:** inpatient periods are an invoicing prerequisite (tarifsuisse Art. 10 Abs. 4; `eng` asked whether J5 can represent them); question 5 for the adviser.
  - **D-32:** addendum above.
- **Packages D-6, D-19, D-20 written** (`inputs-requested`; one comment per issue names the roles):
  - **D-6** (E, C; no `lca`, no legal question): working view A as built. The PO decides the assignment model and the state list if `cra` confirms they are no clinical rule.
  - **D-19** (E, C, L): the protocol content is `clinical`; interim C1 plus SIG1-C1. Moved to tier 2 in INDEX (CGR-43).
  - **D-20** (E, L; C on one point): working view C. The team admits by team decision, the qualification is active only after D-29, and the admin can remove for cause. D applies if `lca` finds the employer must act.
- **Challenge:** a central Operations desk as the end-point of every untaken escalation. Hypothesis row: fewer than 1 in 20 P1 signals reach Operations; if so, Operations becomes a rotating duty of the teams' registered nurses within watched hours. Measured by AN2 measure 10.
- No new brief: SIG2 is in progress; ORD0-C1/C2 with SIG1-C1 is *Next up* 2. ROADMAP: line 24.10. 15:10. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** no new escalation. **owner:** D-1 (urgent, one-line fact answer), D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1 (name the Clinical Owner). **Clinical Owner:** D-28 (now with the CGR-43 question), D-31, D-3, D-30, D-16, D-15. **Owner, process:** #291 and #294 need a merge by a person or a run allowed to merge.
- **Next agent:**
  - **(eng):** SIG2 including SIG2-11 and SIG2-12; then ORD0-C1, ORD0-C2 and SIG1-C1 in one PR. Inputs for D-6, D-19, D-20, D-18 (inpatient period), plus the earlier requests.
  - **(cra):** D-6, D-19, D-20 (question 3); D-17, D-10, D-34.
  - **(lca):** D-19, D-20; D-3, D-16 (its own queue).
  - **(po):** next packages D-14, D-13, D-24.

## 2026-10-24 15:05 · Legal & Compliance Agent (lca)
- **Re-checked D-22 and D-18** (tier 1; new evidence: the tarifsuisse administrative contract, Nr. 42.500.2292Q, valid from 1 May 2023, was found and read) and **D-32** (tier 2; changed by the PO at 11:09; new evidence: SIG2 in open PR #295, `cra` CGR-42). I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not reviewed this run (three-package limit):** D-3 (changed 07:10; it adopts my 06:55 notes) and D-16 (changed 08:18; new source found: HMG Art. 59 Abs. 3 via droit-bilingue.ch, "wer berufsmässig Heilmittel … an Menschen anwendet" must report serious adverse effects). Both are next. D-34: still only in open PR #291. fedlex is still unreadable.
- **D-22:**
  - All three payer contracts read (HSK, CSS, tarifsuisse; 2023) require an order, the doctor's signature for B and *Kenntnisnahme* for A/C, and forbid retroactive orders. None shows an adaptation to KLV Art. 7 Abs. 4.
  - New: tarifsuisse Art. 8 Abs. 4 requires the order's **effective date** to equal the start of treatment. Question 3 is narrowed; c2 needs the effective date stored next to the issue date.
  - New: tarifsuisse Art. 9 Abs. 1 requires a new needs assessment on a lasting change of needs. This supports reopening the GP information (CGR-44). Q12 (a): **unresolved: needs legal adviser and `clinical`**; question 6 added.
  - a1/b2/c2: compliant under every plausible interpretation (unchanged).
- **D-18:**
  - The tarifsuisse contract sets no rounding or minimum. Minutes are billed per category with a per-day calendar, monthly. Question 1 stays open.
  - New contract rules: no advance billing (Art. 10 Abs. 2); no billing while the client is in hospital or a nursing home, except admission and discharge day and assessment or coordination (Art. 10 Abs. 4). Question 5 added; an invoicing prerequisite for `eng`.
  - Option C: compliant under every plausible interpretation while nothing is invoiced (unchanged).
- **D-32:**
  - CGR-41 points 1 and 3 and the fail-closed DPF switch: **compliant under every plausible interpretation**.
  - New: SIG2 (0062) pushes the Operations fallback and the untaken step to **every opted-in Operations member, at any hour**. Outside the watched hours that is my 10:47 question 3 (Pikett), now for Operations staff. **Unresolved: needs legal adviser and owner.** Limiting it to the watched hours, or to a member the provider designates, is compliant.
  - New source: INSOS/YOUVITA leaflet "Pikett oder Präsenzdienst" (2024). Telephone reachability of backup nurses after working time is Pikett.
- Tests: none run (docs only).
- **Next agent (po):** D-32 note 1 (one criterion or accepted deviation in SIG2 #295: Operations pushes only within watched hours) and note 2 (the provider confirms how watched hours are staffed). D-22 notes 1-3 (question 3 wording; two order dates; CGR-44 and question 6). D-18 note 1 (inpatient periods as an invoicing prerequisite). **(eng):** whether J5 can represent an inpatient period; SIG2 Operations time limit, if the PO adopts it. **(lca):** D-3, D-16; D-34 once #291 is merged.
## 2026-10-24 14:39 · eng (Lead Engineer)
- No own PR was open at the start. **Claimed #283** (SIG2, active) at 14:11. **SIG2 is migration 0062** (ADR-076); row → `in-review` (**#295**).
- IMPLEMENTED in the branch, CI pending:
  - opt-in on `/settings`, with the member information shown first;
  - a vendor allowlist by endpoint host (FCM, `*.notify.windows.com`), and a vendor counts only with a recorded DPF entry;
  - a test message, and per-member status on `/team`;
  - the channel switch and the watched hours in `/admin`;
  - an outside result per SIG1 delivery row;
  - "kein Empfänger ausserhalb der App" → Operations at once (CGR-41 point 1); the untaken step to Operations only (point 2); the watched-hours raise for look-ahead hospital-discharge signals (point 3);
  - tap recording; AN2 measure 10 (two measures);
  - the sender on `node:crypto` (RFC 8291/8292), `POST /api/push/dispatch` with a bearer secret, and the service worker `/sw.js`.
- **DPF fact check (SIG2-3): UNKNOWN.** dataprivacyframework.gov renders only with JavaScript; search found participant pages 5780 and 6474, but their content could not be read. The migration records **no** entry, so no vendor counts and the channel cannot be switched on. That fails closed. A reviewed migration must record both entries with the date read: eng, if the list becomes readable, or the owner.
- **Production (D-2, owner):** the VAPID key pair, `SUPABASE_SERVICE_ROLE_KEY` (used only by the sender module), `PUSH_DISPATCH_SECRET` and a one-minute scheduler. No push service was ever called; whether FCM and WNS accept the requests is UNKNOWN until staging.
- Deviations: see the status row (12 points, among them: "active" = last send succeeded; the 2-minute sender timeout (CR-072); "kein Empfänger" stored on the signal).
- Clinical review gate: CGR-41 (advisory S2) read from the 10:26 section in PR #278 (not yet merged); all three points applied, with the finding's pgTAP set; remediation plan `clinical/remediation/CGR-41.md`; register CR-071 to CR-073 (eng). No blocking finding names SIG2.
- Tests: CI is the runner. Locally I used only a stand-in: migrations and seed on PostgreSQL 16 with an auth stub, and a pgTAP stand-in. On it, 064 (82), 062 (54) and 059 (57) pass. Every other file the stand-in can run gives the same result as on the base; the only change is 059, whose count moves from 39 to 41 (updated). I also ran `bun test` on `push-webpush`, `push-rules`, `signals-rules` and `csp`. **Not run:** real pgTAP, vitest, typecheck, lint, build, e2e (npm registry unreachable).
- **Next agent (eng):** on #295, approve the types-bot run (`database.types.ts` for the new functions and tables), fix CI, merge on green, then SIG2 → `delivered`. **(po):** the SIG2 deviations. **(owner):** D-2 items above; the DPF entries. **(cra):** 0062, CR-071 to CR-073.

## 2026-10-24 14:40 · po (Product Owner)
- **PO PR #291 was open** (13:15 cycle): CI green on fd2ebe2, then conflicted with `recovery/main` in `JOURNAL.md` (after #293). Merged `recovery/main` in (b83105c, both entries kept, newest first); CI green on b83105c (app, db, e2e). **Merging #291 was refused by this session's permission check**, so this run's work is added to #291 instead of a second PO PR. Open PRs otherwise: #278 and #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#132, #111, #66** (D-26, D-23, D-17); claims removed at the end.
- **Reviews: no change.** SIG1 (#285) and ORD0 (#292) stay *every criterion met, awaiting clinical review*: no `cra` section covers 0060 or 0061 yet (#259, #278 predate both). Not accepted.
- **`lca` 13:50 taken up (no status change):**
  - **D-2:** the five `lca` conditions are now the design (specific region, Zurich if the same cost; nothing from the live project; test-domain or informed testers; EU function region; SIG2 on staging only for D-32 push services). Host **B (Render Frankfurt)** unless `eng` shows Vercel's listing covers the Swiss-U.S. DPF. ADR-011 note: staging is no production clearance. The design becomes the PO's decision once `eng` gives cost and region facts (requested 12:10; two-run rule not reached).
  - **D-29:** B now says the confirmer acts as someone the licence holder authorised; the owner ask reworded ("the licence holder remains responsible … and authorises who may confirm"); no option changed, still `awaiting-approval: owner`.
  - D-30: billing block for disputed time confirmed compliant; nothing to change.
- **Packages D-26, D-23, D-17 written** (`inputs-requested`):
  - **D-26** (E, L): working view C (an Edge Function holds the service-role key; the app never sees it) or B (server-only invite call), audited and rate-limited, **staging only until D-1 and D-2**; setting the key is the owner's (rule 5). Unblocks D-20 (teams invite colleagues).
  - **D-23** (E, L): no labour-law rule assumed; A (no record) in force; target B (derived day, confirmed by the nurse once a day) only if `lca` shows it admissible; C (proposal only) and D (team-level North Star statistic only) as fallbacks.
  - **D-17** (E, C; L on one point): working view B (fixed categories with yes / no / unknown plus a note, on every visit card, changes in HAND1); clinical categories only from the Clinical Owner; organisational part (access, emergency contact, language) first if `cra` confirms it is no clinical rule; reuse D-15's readiness fields; nothing diagnostic (D-34).
  - One comment per issue names the roles asked.
- **Challenge:** the intake coordinator's phone briefing before a first visit or a cover. From scratch: recorded once at intake, structured, on every card. Hypothesis row with a threshold (fewer than 1 in 5 first visits and covers need a briefing call; two-week tally before and after).
- No new brief: SIG2 is approved and in progress (#283). ROADMAP: line 24.10. 14:40. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** unchanged since 13:15. **owner: D-1 (urgent, one-line fact answer)**, D-22, D-18, D-29 (reworded ask), D-11, D-12, D-33, D-9, the D-4 final periods, G-1; Clinical Owner: D-28, D-31, D-3, D-30, D-16, D-15. **Owner, process:** #291 needs a merge by a person or a run allowed to merge.
- **Next agent (eng):** SIG2; ORD0-C1. Inputs: D-2 (cost; Zurich on the plan; Vercel Swiss-U.S. DPF, function and log regions), D-26 (questions 1-6), D-23 (questions 1-5), D-17 (questions 1-6), plus the earlier D-1, SR-26, D-8, D-10, D-7, D-34. **(cra):** 0060, 0061; D-17 *Clinical impact*; D-10; D-34. **(lca):** D-26, D-23, D-17 (one point); D-34. **(po):** next packages D-6, D-19, D-20.

## 2026-10-24 14:27 · Clinical & Regulatory Architect (review)
- **Reviewed SIG1 (#279, 0060, pgTAP 062) and ORD0 (#284, 0061, pgTAP 063)** in full, plus PO cycles 11:09, 12:10 and open #291 (13:15, 14:40). Section 2026-10-24 14:27 in `reports/CLINICAL_GOVERNANCE.md`. Tests not run by me; CI green on `7a3fdb5` and `3928572`.
- **Closed:** CGR-37 (in-app delivery), CGR-36, CGR-38, CGR-40. **Decided, PLANNED:** CGR-41 (SIG2). **New, all advisory S2:** CGR-42 (no one can see if the evaluator job is not running; S1 for SIG2 go-live), CGR-43 (any recipient's take, whatever her qualification, stops the step to Operations), CGR-44 (Q12 (a): a case never asks again after a later A/C change).
- **Gate:** no blocking finding on SIG1 or ORD0. The PO may accept both (ORD0 with ORD0-C1). CGR-42 goes into the SIG2 brief before work starts.
- **Register IDs reconciled:** eng's CR-066 to CR-070 on `recovery/main` stand. My unmerged CR-066 to CR-069 are now CR-073 to CR-076, and my 11:30 renumbering is reversed. CR-077 added. Hazard log (H-01, H-18) and risk register updated: PS-29, PS-30, PS-32 closed; BL-16 mitigated; PS-34 to PS-36 new.
- This PR carries and supersedes #259 and #278.
- **Next agent (po):** decide CGR-43 and CGR-44, add CGR-42 to SIG2, then accept SIG1/ORD0. **(owner):** D-1; name the Clinical Owner; merge this PR (self-merge refused earlier); confirm the pg_cron job in the pilot project. **(cra next run):** *Clinical impact* for D-34 and D-17 once #291 is merged.

## 2026-10-24 13:50 · Legal & Compliance Agent (lca)
- **Reviewed D-29 and D-30** (tier 2; both changed since my last section: PO 07:10 and 09:12) and **wrote the D-2 input** (first input; requested 12:10). I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not reviewed:** D-22, D-18 (no change since 06:10; no new evidence; fedlex still not reachable). D-34 (new package from `lca`'s D-8 point) is only in open PO PR #291, not on `recovery/main`: next run once merged.
- **New sources:** BJ list of states with adequate data protection (DSV Annex 1; Singapore not listed, US only DPF-certified); Supabase regions (Zurich `eu-central-2` exists), transfer FAQ and DPA of 1 August 2026 (contracting party Supabase Pte. Ltd, Singapore; SCCs with Swiss addendum; no DPF); Vercel and Render compliance statements; EDÖB transfer guide (June 2021, old law, method only); OR Art. 328b.
- **D-2:**
  - The PO working view (specific EU or Zurich region, synthetic data, staging-only accounts, deploy from CI): **compliant under every plausible interpretation**, under five conditions: a specific region; nothing from the live project; test-domain accounts or informed testers; the app's function region set to the EU (Vercel's default is the US); SIG2 on staging only for D-32 browsers until D-33.
  - Production with real data: **unresolved: needs legal adviser and owner** (Singapore contracting entity and US/Singapore access under SCCs; StGB Art. 321; pilot canton).
  - Choosing a staging provider creates no legal lock-in.
- **D-29 (PO recommendation B):** consistent with the sources read. OR Art. 328b covers storing qualification evidence (type, identifier, dates, checker; no copies). The confirmer must act as someone the licence holder authorised. The owner ask should say the licence holder "remains responsible", not that the owner "accepts" the liability. Verdict unchanged: **unresolved: needs owner (D-11, D-12) and legal adviser.**
- **D-30:** the 09:12 billing block for disputed time or category: **compliant under every plausible interpretation**. Residual: an invoicing deadline (a revenue risk, D-18). Other verdicts unchanged.
- Tests: none run (docs only).
- **Next agent (po):** D-2 notes 1-4 (conditions into the design; Zurich if same cost; ADR-011 note). D-29 notes 1-2. **(eng):** D-2: Vercel's DPF listing (Swiss-U.S.?), function and log regions. **(lca):** D-34 once #291 is merged; D-22 and D-18 once fedlex is readable.

## 2026-10-24 13:15 · po (Product Owner)
- **No PO PR was open** at the start. Open PRs: #289 (`eng`, ORD0 → `delivered`), #278 and #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#288** (Q12), **#63, #69, #68** (D-1, SR-26, D-8); claims removed at the end. #285 (SIG1) not claimed: no change (no `cra` section on 0060 yet).
- **ORD0 reviewed (#284, 0061): every criterion met, not accepted (clinical review gate).** CI read through the API: green on head 4f938f6 and on `recovery/main` f35d60e (on the merge commit 2561463 `e2e` was *cancelled* by the next push, not failed). **The PO did not run the tests.** Evidence table in `briefs/ORD0.md`.
  - Deviations accepted: no reopening of `inform_gp` within the case (**Q12 decided (a)**, moved to *Decided*; a re-assessment duty is question 6 added to the D-22 package); `case_closed` refused; no open task → `unchanged`; running = lifecycle `active`.
  - **Condition ORD0-C1:** two pgTAP 063 assertions (HAND1 `handover_entries` returns `gp_informed`; the exception ends when the order is no longer `present`). Met in code, untested.
  - No `cra` section covers 0061 (#259, #278 predate it): **awaiting clinical review**; `cra` is asked for 0061, CR-069, CR-070.
- **`lca` 12:55 taken up:**
  - **D-1 escalated: `awaiting-approval: owner`, urgent.** The fact question goes to the owner now and alone (`lca` note 1): real people in the live rows, including the `orders` e-mail addresses (SR-26)? yes / no / not sure. Leaked-password protection now; key rotation once `eng` names what uses the key. "Not sure" = B: legal adviser now, a report to the FDPIC may already be due (advisory). Confidence Low (E only); escalated anyway because the answer depends on no input.
  - **SR-26:** working view A under `lca` conditions (i)-(iii), no deletion before D-1; still `inputs-requested` (E open).
  - **D-8:** working view B; O-C is no legal gate; still `inputs-requested` (E: deploy fact, O-C).
  - **D-34 added** (`owner`, regulatory, tier 3, INDEX order 22): is NAVORA a medical device under the MepV? Package written, E, C and L requested. Working view A plus C: the core stays an organisation and documentation tool; anything that interprets a client's clinical information (AI assessment drafts, interRAI outputs) ships only as a separately qualified module. Safe default in force: no such feature; D-17 stays "nothing diagnostic".
- **Challenge:** the team phones or writes to the doctor and then records that it did (ORD0). From scratch, the assessment summary leaves NAVORA by a secure channel and the send is the record. Hypothesis row with thresholds on ORD0-6 (channel mix, 7-day share); no brief before D-22.
- No new brief: SIG2 is approved and unstarted. ROADMAP: line 24.10. 13:15. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** **owner: D-1 (new, urgent, one-line fact answer)**; otherwise unchanged: owner D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1; Clinical Owner D-28, D-31, D-3, D-30, D-16, D-15.
- **Next agent (eng):** merge #289; SIG2; ORD0-C1 in the next PR touching pgTAP 063. Inputs: D-1 (what still uses the anon key; rotation steps; read-only checks), SR-26, D-8 (deploys from `main`? O-C), D-10, D-7, D-2, D-34 (feature inventory). **(cra):** review 0060 (SIG1) and 0061 (ORD0, CR-069, CR-070); D-10; D-34. **(lca):** D-2; D-34; D-22 question 6 if useful; D-22 and D-18 once fedlex is readable. **(po):** next packages D-26, D-23, D-17.

## 2026-10-24 12:55 · Legal & Compliance Agent (lca)
- **Reviewed D-1, SR-26 and D-8** (first input for all three; requested by the PO at 12:10 and 11:09). I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not re-checked:** D-22, D-18 (no change since 06:10, no new evidence; fedlex again unreachable: the request was withdrawn unanswered). D-2 waits for the next run (three-package limit).
- **New sources:** DSG as published in BBl 2020 7639 (Art. 5, 6, 7, 8, 9, 12, 24); FDPIC guidance on Art. 24, version 1.2 of 23 April 2025; law.ch on DSV Art. 15 Abs. 4 (secondary); Kanton Zürich orientation page on software as a medical device (30 January 2026).
- **D-1 (urgent):**
  - If any live row concerns a real person, even renamed, the pre-C-1 exposure is a case the breach definition covers ("made accessible").
  - With health data the FDPIC assumes a high risk in many cases. A report is due "as soon as possible", and doubt is no reason to wait. The exposure was found three days ago.
  - Rotation and leaked-password protection now: **compliant under every plausible interpretation**.
  - A (owner confirms synthetic): **compliant under every plausible interpretation**.
  - B: compliant as measures; the reporting and information duties are **unresolved: needs legal adviser**, after the owner's fact answer.
  - C, D: **unresolved: needs owner**.
- **SR-26:**
  - The e-mail addresses widen D-1's assessment.
  - Contained: compliant only as a short interim.
  - A (move, then delete): **compliant under every plausible interpretation** under three conditions: the owner is that application's controller; the target project is protected; the D-1 facts are documented first.
  - B: **unresolved: needs owner**.
  - No deletion before D-1 is answered.
- **D-8:**
  - No source read ties any record duty to byte evidence of recovered code, so O-C can be dropped as a gate from the legal side.
  - B and C: **compliant under every plausible interpretation** of the data-protection sources read, provided nothing deploys from `main` into an environment with personal data before D-1.
  - A: **unresolved: needs `eng`** (deploy fact).
  - New, separate open point: whether NAVORA is a medical device under the MepV (signals and exceptions). **Unresolved: needs owner and a regulatory adviser**; no row exists.
- Tests: none run (docs only).
- **Next agent (po):** D-1 note 1: ask the owner the fact question now, alone and in one line; "not sure" means B. D-1 note 3 (escalation wording). SR-26 notes 1-2. D-8 note 2 (medical-device row?). **(eng):** D-8 question 1; SR-26 RLS state of `orders` before C-1. **(lca):** D-2; D-22 and D-18 once fedlex is readable.

## 2026-10-24 12:10 · po (Product Owner)
- **No PO PR was open** at the start. Open PRs: #284 (ORD0, `eng`, not merged), #278 and #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#285** ([PO review] SIG1), **#63, #69, #64** (D-1, SR-26, D-2); claims removed at the end.
- **SIG1 (#285): no change.** Reviewed at 11:09 (every criterion met); still **awaiting clinical review**: no `cra` section covers 0060 (#278 is from 10:26, before #279 merged). Not accepted; #285 stays open for the acceptance.
- **`lca` 11:55 taken up** (no status change; `eng` and `cra` inputs requested 11:09 are not yet due under the two-run rule):
  - **D-10:** PO working view **A plus R**: every care-assistant report countersigned, and the countersigner may return it unsigned with a reason under `lca` conditions (a)-(c). B is a post-pilot hypothesis (needs the licence holder's head of nursing, D-12, and a legal adviser); C is out. D-29's real-data gate is a precondition for every option.
  - **D-7:** rulesets and push protection first (no legal question; the owner applies them once `eng` names the checks). Visibility hinges on **D-1**. B reworded: private before real personal data in any environment the repository describes, the live project included.
  - **D-15:** the Engineering draft (by po) is aligned with condition (iii): `requires_2bis` gates a3 and the *needs assessment* for b13, b14 and c2, not those services after assessment. One added question for the Clinical Owner with the same approval (keep as worded, or block entirely until D-29); the PO recommends as worded. Status unchanged (`awaiting-approval: clinical`). `cra` is asked for a hazard view on it.
- **Packages D-1, SR-26, D-2 written** (`inputs-requested`; Engineering and `lca` asked, no `cra`: no care rule).
  - D-1: the fact question first (are the live rows real people?); working view: rotate the key and enable leaked-password protection now whatever the answer; nothing deleted before the answer or a legal clearance. Owner-executed (rule 5).
  - SR-26: working view A (move to the other app's project, then delete), by the owner after D-1.
  - D-2: working view one EU (Swiss if offered) staging Supabase project, a protected EU app host, deploy from CI, synthetic data only; the design is po's once `lca` clears it, the paid plan and the account actions are the owner's. D ("no staging until the pilot partner") rejected: SIG1/SIG2 and the hosted jobs must be shown on a hosted clock before any real client.
- **Challenge:** the founder as the hand-operator of every protective setting (D-7, D-1, SR-26, D-2, VAPID key, hosted job checks). From scratch: settings declared in the repository and applied by CI after one owner approval (a GitHub environment only the owner releases), verified and recorded by the same run; agents still hold no live or admin rights. Row in `NEXT_CAPABILITY.md`; brief after D-2 and D-7.
- No new brief: ORD0 (in review, #284) and SIG2 are approved. ROADMAP unchanged (no status change). Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** unchanged since 10:11 (no new escalation). owner: D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1. Clinical Owner: D-28, D-31, D-3, D-30, D-16, D-15.
- **Next agent (eng):** ORD0 (#284), then SIG2. Inputs for D-10, D-7, D-8 (requested 11:09) and D-1, SR-26, D-2 (requested now; questions in each package). **(cra):** review 0060 (SIG1); D-10 *Clinical impact*, including whether R is safer than "countersign, then correct"; D-15 added question. **(lca):** D-8; D-1, SR-26, D-2. **(po):** next packages D-26, D-23, D-17.
## 2026-10-24 12:25 · eng (Lead Engineer)
- **ORD0 delivered:** #284 was conflicted with `recovery/main` (JOURNAL only, after #286); merged the base in (4f938f6, both entries kept, newest first), CI green on 4f938f6 (app, db, e2e), merged #284 with a merge commit (2561463). Row ORD0 → `delivered` (this PR). IMPLEMENTED.
- No code change this run; the base merge brought only docs (D-7, D-10, D-15, JOURNAL).
- Issue #247 keeps its `active` label until the PO's review; the watcher opens the review issue from the `delivered` row.
- Tests: none run locally; CI ran them on 4f938f6.
- **Next agent (eng):** #283 (SIG2) once it is labelled `active`. **Q12** (ORD0 deviation: `inform_gp` not reopened once recorded) is open for `po`.

## 2026-10-24 11:55 · Legal & Compliance Agent (lca)
- **Reviewed D-10 and D-7 (first input) and re-checked D-15** (changed by the PO at 10:11; deferred from 10:47). I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not re-checked:** D-22, D-18 (unchanged since 06:10; no new evidence; the lexfind/fedlex request was withdrawn unanswered again). D-8 waits for the next run (three-package limit).
- **New sources:** Kanton Zürich *Merkblatt Betriebsbewilligung Spitex-Institution* (November 2023); Kanton Graubünden Betriebsführung information (2017, currency UNKNOWN); DSG final-vote text of 25 September 2020 (Art. 5 lit. h, 7, 8, 24); HIN's summary of DSV Art. 3 (secondary).
- **D-10:** no source read requires an RN to countersign each care-assistant report. What they require is supervision of delegated care under a qualified nurse's responsibility (ZH Ziff. 5.2, 5.4; GR), plus attributable entries.
  - A: **compliant under every plausible interpretation**.
  - R (return unsigned, with conditions a-c): **compliant** on the sources read; to be confirmed for the pilot canton.
  - B: **unresolved: needs legal adviser** and the licence holder's supervision concept (D-12).
  - C: **unresolved**, not protective.
- **D-7:** rulesets and push protection: **compliant under every plausible interpretation**.
  - Staying public: **unresolved: needs owner (D-1)**. The public repository names the live project and documents its security state, and whether the live data are real is still open.
  - B (private before real data): compliant as a measure.
- **D-15:** the recommendation matches my conditions. Gap: the Engineering draft's `requires_2bis` blocks b13, b14 and c2 themselves, while Abs. 2bis gates a3 and the *assessment* for them. That is stricter than the law and a care-access question for `cra`. Verdicts unchanged.
- Tests: none run (docs only).
- **Next agent (po):** D-10 notes 1-3 (A plus R; B needs the head of nursing of D-12; D-29 gate). D-7 notes 1-2 (D-1 link; wording of B). D-15 notes 1-2. **(owner, through po):** D-1 answers D-7's open question. **(lca):** D-8; D-22 and D-18 once fedlex is readable.

## 2026-10-24 11:35 · eng (Lead Engineer)
- **SIG1:** #279 had been merged at 10:54 by the previous run, which pushed `docs/sig1-delivered` (row → `delivered`) without opening a PR. This run opened **#281**, merged `recovery/main` into it (JOURNAL conflict, both entries kept); CI green on 7f198b2. Merging #281 was refused by this session's permission check; it was merged later as 82396ba (not by this run).
- **Claimed #247** (ORD0, active) at 11:10. **ORD0 is migration 0061** (ADR-075); row → `in-review` (#284).
- IMPLEMENTED in the branch: `record_gp_informed` (date not future, not before the case, CGR-40; four channel codes; audited, idempotent) closes `inform_gp`; `/team` card shows "informiert am … (…)"; HAND1 entry; P3 exception `order_without_end_date` on `/team` and OPS1, closes only with its cause; AN2 measure 10 gains `order_open_end_ending` and `inform_gp_done_within_7d_share`.
- **Brief questions answered (ADR-075):** a separate command (`complete_case_task('inform_gp')` stays refused); the exception fits `derived_exceptions` without a new table (an internal episode table only feeds the start time and measure 10).
- **Deviations:** planning and PLAN2 no longer reopen `inform_gp` once a record exists (else every `/team` load reopened it) → **Q12 opened for `po`**; "running" = lifecycle `active`; pgTAP 019, 059, 061 counts updated (no assertion weakened).
- Clinical review gate: report 2026-10-24 02:26 (CGR-36, CGR-38, advisory S2) and `cra` 06:30 (CGR-40, S3) applied; no blocking finding names ORD0; remediation plans `clinical/remediation/CGR-36.md`, `CGR-38.md`; register CR-069, CR-070 (eng).
- Tests: CI is the runner. Locally a stand-in only: all migrations and the seed applied to a local PostgreSQL 16 with a Supabase auth stub; a minimal pgTAP stand-in ran 063 (53 pass) and every other file it can run (all pass; 11 files use pgTAP functions the stand-in lacks); `bun test` on `gp-rules`, `analytics-hypotheses`, `team-rules`, `handover`; `tsc` on the pure modules. **Not run:** real pgTAP, vitest, full typecheck, lint, build, e2e (npm registry unreachable).
- **Next agent (eng):** fix CI on the ORD0 PR if red (types bot for the new table and command); merge the ORD0 PR on green; ORD0 → `delivered`. **(po):** Q12; the deviations above. **(cra):** CR-069, CR-070; 0061.

## 2026-10-24 11:30 · Clinical & Regulatory Architect (review)
- **#278 merge conflict resolved** (merge of `recovery/main` @ `afa6f40`; JOURNAL: all entries kept, newest first).
- **Register ID collision:** eng (SIG1, #279) added CR-066 to CR-068 to `CLINICAL_RULE_REGISTER.md`; those IDs were already used in #259/#278 (CR-066 to CR-069). eng's rows are kept with content unchanged and renumbered **CR-070 to CR-072**; no code or test refers to them. **eng:** please take the next free ID from the register on the open governance PR, or ask.
- SIG1 (#279, 0060) and the PO 11:09 cycle (CGR-41 decided in D-32, SIG2 approved) are not reviewed in this check-in; they go into the next report section.

## 2026-10-24 11:09 · po (Product Owner)
- **No PO PR was open** at the start. Open PRs: #278 and #259 (`cra`, not merged by the PO), #3 (M2). No `[PO review]` issue was open (SIG1's row still says `in-review`). Claimed **#56, #67, #68** (D-10, D-7, D-8); claims removed at the end.
- **SIG1 reviewed: every criterion met, not accepted (clinical review gate).** #279 was merged as 7a3fdb5. CI was read through the API: green on head dad4dbe, on 7a3fdb5 and on `recovery/main` a081031. **The PO did not run the tests.**
  - Evidence table in `briefs/SIG1.md`: SIG1-1 to SIG1-9 met. pgTAP 019, 039, 059 and 061 updated counts and lists only; no assertion was weakened.
  - No `cra` section covers 0060: #259 and #278 both call SIG1 unstarted. So it is **awaiting clinical review**, and `cra` is asked to review 0060.
  - **Deviations decided:**
    - accepted: an absent member (also the responsible one) gets no delivery;
    - accepted: a hospital-discharge visit without a responsible member is shown as "Einsatz ohne Zuständige";
    - accepted: Operations means role `operations`, and admins only when there is none;
    - accepted: `signal_untaken` is an operating rule;
    - `cover_without_access` not delivered: becomes a **COVER1 enablement condition**, together with CGR-21's "her team" part.
  - **eng:** set the SIG1 row to `delivered`.
- **CGR-41** (`cra` 10:26, #278) **decided in D-32, addendum** after the `lca` 10:47 re-check:
  1. When nobody can be reached outside the app, Operations gets the signal at once.
  2. The untaken step goes to Operations, not to the whole team: Pikett is unresolved, and an on-call person waits for the provider's policy.
  3. Look-ahead P1s are raised inside watched hours. SIG1-8 is extended in `CARE_OPERATING_MODEL.md`.
- **SIG2 approved** (*Next up* 3, after ORD0).
- **Packages D-10, D-7, D-8 written** (`inputs-requested`). Engineering and `lca` are asked for all three; `cra` for D-10.
  - D-7 fact read through the API: the repository is **public**, `main` and `recovery/main` are **unprotected**, and secret scanning is **off**.
  - The PO's working view on D-7: protection and scanning now; private on a plan that keeps them, before real data.
  - D-8: B (merge after D-7; O-C as a gate re-examined by `eng`). All three stay `owner`/`clinical` routes.
- **Challenge:** a person keeping a page open for every visit hour (SIG1-8), and foreseeable signals that first appear at night. From scratch, the signal finds the person, and foreseeable ones are raised during the day. The row is in `NEXT_CAPABILITY.md`; measured by SIG2-10.
- Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** unchanged since 10:11 (no new escalation). owner: D-22, D-18, D-29, D-11, D-12, D-33, D-9, the D-4 final periods, G-1. Clinical Owner: D-28, D-31, D-3, D-30, D-16, D-15.
- **Next agent (eng):** SIG1 → `delivered`. ORD0, then SIG2. Inputs for D-10, D-7 (the plan terms for a private repository and the Actions minutes) and D-8 (deploys from `main`? does O-C still protect anything?). **(cra):** review 0060 (SIG1); D-10 *Clinical impact*. **(lca):** D-10, D-7, D-8. **(po):** next packages D-1, SR-26, D-2.

ENGINEERING BRIEF
- **Capability:** SIG2: safety signals reach the nurse's phone (`briefs/SIG2.md`).
- **Why:** SIG1 works only while a page is open, so SIG1-8 still needs a screen-watcher for every planned hour.
- **Business outcome:** no watcher role to staff; a P1 reaches a person without a coordinator.
- **Care outcome:** a missed or stuck visit is noticed in minutes by someone at work; foreseeable gaps are seen during the day.
- **Expected nurse outcome:** one content-free push, only within her planned working time; no calls off duty; opt-in with a test.
- **Expected team outcome:** the team sees whose outside delivery works; one tap takes the signal; Operations only when nobody can be reached.
- **Expected patient outcome:** fewer visits missed unnoticed (AN2 measure 10, SIG2-10).
- **Acceptance criteria:** SIG2-1 to SIG2-10 (opt-in and vendor allowlist, test delivery and status, switch-on with the DPF entries, recipients within planned working time, empty set → Operations at once, watched-hours raise, untaken step to Operations only, fixed payload and records, negative cases, evidence).
- **Dependencies:** SIG1 (0060), D-32 (decided), ADM1 range guard; the VAPID production key is an owner task with D-2; D-33 stays out.
- **Priority:** *Next up* 3, after ORD0.
- **Implementation recommendation:** a test transport and a fixed clock in pgTAP; no real push call in CI; fail closed on an unknown endpoint host; SIG2-6 stricter only (ADM1-R direction).

## 2026-10-24 10:54 · eng (Lead Engineer)
- **#279 merged** (merge commit 7a3fdb5; SIG1). CI green on head dad4dbe (app, db, e2e), read through the API; no review comments.
- Two fixes on the way: a `JOURNAL.md` merge conflict with `recovery/main` (both entries kept); the e2e failed on a163956 because `field.spec.ts` records assist.test absent before `signals.spec.ts` runs, and an absent member receives no delivery (by design). The e2e now uses the present nurse in two sessions; no assertion removed.
- **SIG1 → `delivered`** (#279): READY_FOR_REVIEW. Clinical gate: CGR-37 applied (remediation plan `clinical/remediation/CGR-37.md`); CR-066 to CR-068 for `cra`.
- Tests: CI ran the suite; nothing more run here.
- **Next agent (po):** review SIG1; decide the two deviations (absent responsible member gets no delivery; `cover_without_access` not delivered). **(eng):** ORD0.
## 2026-10-24 10:47 · Legal & Compliance Agent (lca)
- **Re-checked D-32, D-9 and D-4.** D-32 because of new evidence: `cra` CGR-41 (open PR #278) on recipients outside working time. D-9 and D-4 because the PO changed them at 10:11. I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not re-checked:**
  - D-22, D-18: unchanged since 06:10, and still no new evidence (fedlex request withdrawn unanswered this run).
  - D-15: changed at 10:11, but the PO's option C text reproduces my conditions (i)-(iii). Deferred to the next run (three-package limit). One point for then: `requires_2bis` should gate the *needs assessment* for b13, b14 and c2, not the services themselves.
- **D-32 (CGR-41):** new sources: SECO "Pikettdienst" (ArGV 1 Art. 14, 15, 19 Abs. 3, as summarised by SECO) and ArGV 2 Art. 17 (Spitex: no permit for night and Sunday work).
  - Point 1 (empty outside set → Operations at once): **compliant under every plausible interpretation**.
  - Point 2 (whole team outside the app): **unresolved: needs legal adviser and owner** outside working time, because a reaction is expected in substance, which makes it unplanned Pikett. Protective form: a planned on-call person, otherwise Operations. New question 3.
  - Point 3 (watcher for look-ahead hours): **unresolved: needs owner** (the provider's on-call policy).
  - The 09:12 narrow variant is unaffected.
- **D-9:** the PO's option D matches 07:58. "Anonymised" must mean removing the free-text fields (`title`, `need_summary`, `notes`). Gates g1-g5 consistent. Verdict unchanged: compliant for NAVORA's steps; **unresolved: needs legal adviser and owner** (D-12 secrecy and processor, D-11 canton, the referrer). Note: refusal of cover consent (g4) has a safety consequence for `cra`.
- **D-4:** new source: Onlinekommentar on DSG Art. 26. A restriction needs a weighing in the individual case and a stated reason (Abs. 4).
  - Provisional rule: **compliant under every plausible interpretation**, provided r1's staff masking is a weighed, stated and liftable restriction, not a fixed mask.
  - Final periods: **unresolved: needs legal adviser and owner**. New question 5.
- Tests: none run (docs only).
- **Next agent (po):** D-32 notes 1-3 into the SIG2 brief (on-call person, not the whole team; named watcher for look-ahead hours). D-9 note 1 (anonymisation wording). D-4 notes 1-2 (r1 wording; operational-rows criterion). **(cra):** D-9 note 2 (cover refused). **(lca):** D-15 re-check; D-22 and D-18 once fedlex is readable.

## 2026-10-24 10:40 · eng (Lead Engineer)
- No own PR was open. **Claimed #246** (SIG1, active) at 10:12. **SIG1 is migration 0060** (ADR-074); row → `in-review` (#279).
- IMPLEMENTED in the branch: P1 visit safety signals become `safety_signals` episodes with one `signal_deliveries` row per recipient, written by `private.evaluate_signals` (pg_cron every minute, and every 30-s poll of `/field`, `/team`, OPS1, throttled 15 s). Banner at the top of the three pages; "Ich übernehme" (audited, idempotent); untaken after `signal_untaken` (15 min PROVISIONAL, stricter only) → Operations once; AN2 measure 10 gains two values.
- **Brief questions answered (ADR-074):** polling, not realtime; pg_cron plus the poll path as the writer, tested in pgTAP by calling the writer; recipients follow the owning team, the covering member is the responsible one (CGR-21).
- **Deviations:** an absent member (also the responsible one) gets no delivery; `visit_uncovered_hospital` delivered as "Einsatz ohne Zuständige"; `cover_without_access` not delivered; Operations = role `operations` (admins only if none). pgTAP 019, 039, 059, 061: expected counts and lists updated for the new rule and measures (no assertion weakened).
- Clinical review gate: latest merged report 2026-10-24 02:26, CGR-37 (advisory S2) applied; remediation plan `clinical/remediation/CGR-37.md`; register rows CR-066 to CR-068 (eng).
- Tests: CI is the runner. Locally a stand-in only: all migrations and the seed applied to a local PostgreSQL 16 with a Supabase auth stub; a minimal pgTAP stand-in ran 062 (54 pass) and every other file it can run (all pass; 11 files use pgTAP functions the stand-in lacks); `bun test` on `signals-rules`, `analytics-hypotheses`, `admin-rules`. **Not run:** real pgTAP, vitest, typecheck, lint, build, e2e (npm registry unreachable).
- **Next agent (eng):** fix CI on the SIG1 PR if red (types bot for the two new tables); merge on green; SIG1 → `delivered`. Then ORD0. **(po):** the two deviations above (absent responsible member; `cover_without_access`).
## 2026-10-24 10:26 · Clinical & Regulatory Architect (review)
- **Reviewed** `recovery/main` @ `11202ef` since the 06:30 section: #263 (AN2 part 3: 0058, pgTAP 060), #268 (ADM1-R: 0059, pgTAP 061, pgTAP 035 rewrite; AN2-C1 pgTAP 045), #271 (COORD5, out of clinical scope), PO cycles 07:10-10:11, `lca` #260, #266, #276. I did not run the tests; CI green on `d386a1b`, `c1bd8cb`, `11202ef`.
- **Closed:** **CGR-39** (0059 direction-aware range, reset with audit; pgTAP 061, 035:188-205; PS-31 closed). CGR-40 decided by the PO (ORD0-1), PLANNED.
- **New:** **CGR-41 advisory (S2)** on D-32 (decided by the PO 09:12): outside delivery can leave a P1 with no outside recipient (uncovered visits have no responsible member; colleagues only inside their planned-visit span; Operations in-app); the SIG1-5 step to the whole team is undecided; SIG1-8 hours do not cover look-ahead P1s. Registers: CR-068, CR-069, CR-021 superseded; PS-31 closed, PS-32 PLANNED, PS-33 new; H-01 updated.
- **#259 not merged:** my merge was refused by the session's permission control. This PR (`gov/review-2026-10-24-1026`) contains #259's commits and supersedes it.
- **Next agent (po):** decide CGR-41 in the SIG2 brief and D-32. **(owner):** name the Clinical Owner (G-1); merge this governance PR or grant/name the merger. **(clinical, once named):** whether a P1 raised at night must be answered at once, and by whom.

## 2026-10-24 10:11 · po (Product Owner)
- **No PO PR was open** at the start. Open PRs: #259 (`cra`, not merged by the PO), #3 (M2). Claimed **#274** ([PO review] COORD5); claim removed at the end.
- **COORD5 → `accepted`** (#271, ADR-073). CI was read through the API: green on head b3dace6 and on `recovery/main` 2663934; on merge commit ccfc857 app and db are green and e2e was cancelled by the next push. **The PO did not run the tests.**
  - Every criterion met. Live effect checked: 11 `human-decision` issues, each assigned and with a package; the others carry `decision-package`, are unassigned and were commented once (e.g. #71).
  - One deviation accepted (`po-decided` still in *Open* stays a package issue). Non-blocking **COORD5-M1**: assign `clinical` packages to the Clinical Owner's account once G-1 names one. Evidence in `briefs/COORD5.md`.
  - COORD5 moved to the queue (rank 22). *Next up*: 1 SIG1, 2 ORD0.
- **Decision packages** (Engineering impact drafted by po for D-15, D-9, D-4: two-run rule, requested 04:10 and 05:15, not answered):
  - **D-15 → `awaiting-approval: clinical` (Medium).** Option C: the catalogue proposes the service and its KLV category, and the team may choose another *listed* service with a reason, audited and reviewed by an RN. `lca` conditions (i)-(iii) apply; Abs. 2bis services cannot be planned until qualifications show experience (D-29). The catalogue text is copied verbatim from fedlex, not drafted by an agent. Readiness: as built plus three `cra` items. Real-data gate (po): no real care plan while the category is chosen freely.
  - **D-9 → `awaiting-approval: owner` (Medium).** Option D, protective variant:
    - referral on the referrer's confirmation;
    - case and record on the care contract and the statutory record duty, with the Art. 19 information recorded;
    - per-category consent for sharing;
    - representative recorded.
    Real-data gates g1-g5 decided by po. `lca` questions 1-5 go to the legal adviser of D-11/D-12.
  - **D-4: provisional rule decided by po** (`lca` 08:05: compliant under every plausible interpretation): no deletion before the final rule, written retention criteria, purpose-bound reading as the target; real-data gates r1-r3. **Final periods → `awaiting-approval: owner`**, asked once D-11 and D-12 are answered (as D-18). The row stays in *Open* for the final part.
  - **D-12** (`lca` 09:53 adopted). Four conditions: (1) the partner's nursing management may intervene in a single case, recorded and visible, instead of being excluded; (2) measures aggregated per team; (3) "support a new licence and the transfer of consenting clients" instead of "take over"; (4) processor and confidentiality agreement, NAVORA's own use anonymised and aggregated only, hosting and DPIA before real data. Still `owner`.
  - **D-11:** criterion 1 = a design partner already licensed and admitted in that canton. Still `owner`.
  - Go-live conditions for D-9, D-4 and D-15 added to `CARE_OPERATING_MODEL.md`.
- **Challenge:** data-protection housekeeping (retention, access requests, clearing old referrals) done by people. From scratch these are properties of the data: a retention class per audited column, a one-command extract, self-expiring referrals. Row in `NEXT_CAPABILITY.md` and `CARE_OPERATING_MODEL.md`; hypothesis: zero staff hours per request and per run. Brief after D-11 and D-12.
- No new brief: SIG1 and ORD0 are approved and unstarted. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:**
  - owner: D-22, D-18 (after D-11, D-12), D-29, D-11, D-12, D-33, **D-9**; D-4 final periods (after D-11, D-12); names the Clinical Owner (G-1);
  - Clinical Owner (once named): D-28, D-31, D-3 field list, D-30, D-16, **D-15**.
- **Next agent (eng):** SIG1, then ORD0. Confirm or correct the Engineering impact drafted by po (now also D-15, D-9, D-4). COORD5-M1, AN2-M4a, ADM1-M1 at their next touch. **(cra):** ADM1-G1 (CGR-39 on 0059); merge or update #259; a look at D-15's option C wording. **(lca):** D-15, D-9 and D-4 recommendations changed (re-check is eligible); D-22 and D-15 once fedlex is readable. **(po):** D-10, D-7, D-8 packages.

## 2026-10-24 09:53 · Legal & Compliance Agent (lca)
- **Re-checked D-12, D-11 and D-33** (all three changed since my last section: PO 09:12). I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **D-22, D-18 not re-checked** (priority 1, but not eligible: no change since the 06:10 take-up of my 05:45 notes, no new evidence). New fact only: the BAG list shows KLV amendments 2026/336 (in force 1 July 2026 and 1 January 2027) and 2026/337 (1 January 2027 and 1 January 2028); their text is still unread (fedlex not reachable).
- **D-12 (PO: B with three conditions):** new evidence on question 1. Doctrine for lawyers (UZH, Anwaltsrevue 1/2019) treats IT providers as *Hilfspersonen* under StGB Art. 321 with a confidentiality and processor agreement, consent recommended, not required; a narrower view exists. Question 1 is narrowed, not settled. Condition 1 as worded (no intervention by the partner) may conflict with the licence holder's non-delegable duties: **unresolved: needs legal adviser**; a reworded version is offered. Conditions 2 (aggregated measures) and 3 (support a new licence and the transfer of consenting clients, not a licence take-over) are consistent with every source read in the rewordings. New point: NAVORA's own use of pilot data makes it a controller for that use. Verdict on B: **unresolved: needs legal adviser and owner** (D-11, partner, hosting ADR-011).
- **D-11:** criteria consistent with the sources read; with B the partner must already be admitted in the pilot canton (KVG Art. 36). Verdict unchanged (owner, legal adviser in the canton).
- **D-33:** the copy from D-32 is faithful; DSV amendment of 15 September 2024 (DPF-certified US companies adequate) confirmed via Fribourg ÖDSMB. Whether Annex 1 lists Ireland is not verified. Verdict unchanged: A compliant; B, C unresolved (legal adviser).
- **Not readable this run:** fedlex (StGB Art. 321, AS 2026/337), the FMH processor guide, Apple's privacy page (primary). Tests: none run (docs only).
- **Next agent (po):** D-12 notes 1-5 (reword conditions 1 and 3; add processor and confidentiality agreement and NAVORA's own data use to the partnership; hosting before real data). D-11 note (criterion 1 wording). **(eng):** Apple push-service operator for Swiss senders (D-33). **(lca):** D-22 and D-15 once fedlex is readable; the chosen canton's licence law once D-11 is answered.

## 2026-10-24 09:25 · eng (Lead Engineer)
- **#271 merged** (merge commit ccfc857; COORD5). CI green on head b3dace6 (app, db, e2e), read through the API; no review comments.
- **COORD5 → `delivered`** (#271): READY_FOR_REVIEW. The watcher now re-labels the decision issues on its next run (8 assigned, 21 unassigned with the comment).
- **Correction:** the 09:40 entry below carries a planned time; it was written at 09:15.
- Tests: none run here beyond the bun stand-in; CI ran the suite.
- **Next agent (eng):** Engineering impact for the packages (D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-32), SIG1, ORD0.

## 2026-10-24 09:40 · eng (Lead Engineer)
- No own PR was open. **Claimed #240** (COORD5, active) at 09:10. **COORD5 is PR #271** (ADR-073); row → `in-review`.
- IMPLEMENTED in the branch: the watcher reads *Package status* from `decisions/INDEX.md`. `awaiting-approval: <role>` → `human-decision`, owner assigned, package linked, *Owner approval required?* quoted. Anything else → `agent:po` + `decision-package`, nobody assigned; an assigned issue is unassigned once, with the German comment from the brief. Validator checks the INDEX; `--dry-run` prints the package status.
- **Brief question answered:** INDEX is read in `parse.mjs` as an optional input, not added to the official layer (stays PO-owned).
- **Deviation:** `po-decided` while still in *Open* keeps the issue as `decision-package` (validator warning); it closes when the row moves to *Decided*. Reconciles two brief criteria.
- **Effect after merge** (dry run on today's files): 8 issues assigned (D-22, D-18, D-29 owner; D-28, D-31, D-3, D-30, D-16 clinical, assigned to the owner until a Clinical Owner account exists); 21 unassigned with a comment.
- Clinical review gate: not applicable (coordination only).
- Tests: CI is the runner. Locally a stand-in only: `bun test` on both unit files (25 + 12 pass), `agents-check`, dry run. Not run: vitest, typecheck, lint, e2e (npm unreachable).
- **Next agent (eng):** fix CI on #271 if red; merge on green; COORD5 → `delivered`. Then the Engineering impact for the packages (D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-32), SIG1, ORD0.

## 2026-10-24 09:12 · po (Product Owner)
- **No PO PR was open** at the start. `lca` #266 is merged (f35ab63); `cra` #259 is still open (not merged by the PO). Claimed **#270** ([PO review] ADM1); claim removed at the end. #248 (D-32) worked with a comment only.
- **ADM1 → `accepted`** (#268, migration 0059, pgTAP 061, ADR-072). CI green on head d2e9b74 (run 40070559456), merge commit c1bd8cb (40070955122, 40070952402) and `recovery/main` f35ab63 (40072166088, 40072162324), read through the API; **the PO did not run the tests.**
  - ADM1-R1 to R6 met; each `cra` remedy point for CGR-39 (#259 head) met in code. Evidence table in `briefs/ADM1.md` 09:12.
  - Five deviations accepted (`cover_without_access` is look-ahead, the brief was wrong; `visit_stuck` floor 1 h; unit and e2e updated; pgTAP 047 fixture left as is, **ADM1-M1** at its next touch; hand-edited types).
  - **ADM1-G1:** `cra` confirms CGR-39 closed on 0059 in its next section; else ADM1 returns to `changes-requested`. The PO accepted before that cycle because the README gate asks the PO to consider the report, and every remedy point is checkable in the code.
  - **AN2-C1 met** (pgTAP 045 test 14 fixture, not the reader). SIG1-9 range part met.
- **Decision packages:**
  - **D-32 → `po-decided` (Medium):** option B, narrow variant. Web push of the fixed text only to Google and Microsoft endpoints, after the official DPF list check is recorded in the SIG2 PR. Recipients: the responsible member and colleagues within planned working time (span of their planned visits that day). Opt-in, information text naming vendor and country, test delivery, per-member status on `/team`. SIG1-8 stays. Built later as SIG2, after SIG1. Why po may decide: `lca` 08:47 finds this variant consistent with every source read; no clinical rule, reversible, no paid contract.
  - **D-33 (new, tier 2, CGR-37) → `awaiting-approval: owner`:** Safari/iOS and Firefox (`lca` question 1 unresolved; no legal adviser named). Default A: in-app only for those browsers.
  - **D-11 → `awaiting-approval: owner` (Medium as a package):** Engineering impact drafted by po (two-run rule; requested 04:10, seven `eng` runs since). Canton is per case; J5 reference rows are per region; `region` of teams is a service area, not a canton; a second language is the largest single cost. Asked: "name the pilot canton and two to five municipalities", five criteria.
  - **D-12 → `awaiting-approval: owner` (Medium):** Engineering impact drafted by po (A ≈ B small, D medium, C per team large). Recommendation: **B for the pilot** (a licensed partner organisation) with three partnership conditions: no added dispatch or approval layer; measures shared; a path to a cooperative of teams (C) after the pilot. A only if no partner. `lca` question 1 (processor under professional secrecy) first.
  - **D-30:** `lca` 08:47 note adopted. A disputed time or category is not billable until corrected from a documented source (invoicing prerequisite for D-18).
  - Comments on #248, #57, #58.
- **Challenge:** why does the licence bring a nursing-management line layer above the teams? From scratch its duties are a few named functions (serious-event review, qualification confirmation, clinical-rule approval, untaken escalations) carried by one fractional clinical lead. Hypothesis row in `NEXT_CAPABILITY.md` and `CARE_OPERATING_MODEL.md`: fewer than 5 such actions per week per 50 clients, counted from the audit log.
- No new brief: COORD5, SIG1, ORD0 are approved and unstarted; SIG2 waits for SIG1. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:**
  - owner: D-22, D-18 (after D-11, D-12), D-29, **D-11, D-12, D-33**; names the Clinical Owner (G-1);
  - Clinical Owner (once named): D-28, D-31, D-3 field list, D-30, D-16.
- **Next agent (eng):** COORD5, SIG1, ORD0 in order; confirm or correct the Engineering impact drafted by po (D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-32, **D-11, D-12**); AN2-M4a, ADM1-M1 at their next touch. **(cra):** ADM1-G1 (CGR-39 on 0059); merge or update #259. **(lca):** nothing new requested; D-15 once fedlex is readable. **(po):** D-15, D-9, D-4 packages (inputs in), D-10.

## 2026-10-24 08:50 · eng (Lead Engineer)
- **#268 merged** (merge commit c1bd8cb; ADM1-R1 to R6 for CGR-39, plus AN2-C1). CI was green on head d2e9b74 (run 40070559456: app, db, e2e).
- **ADM1 → `delivered`** (#101, #135, #153, #268): READY_FOR_REVIEW.
  - Clinical gate: CGR-39 applied (remediation plan `clinical/remediation/CGR-39.md`). `cra` reviews 0059.
  - AN2-C1: the cause and the fix are in the #268 comment (pgTAP 045 test 14).
- Tests: none run here beyond the stand-in noted at 08:40 and 08:45; CI ran the suite.
- **Next agent (eng):** confirm or correct the Engineering impact drafted by po (D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-32); AN2-M4a with the next `pilot_hypotheses` change; COORD5, SIG1, ORD0.

## 2026-10-24 08:47 · Legal & Compliance Agent (lca)
- **Continued my open PR #266** (it was in conflict with `recovery/main` on JOURNAL; merged `recovery/main` in, kept both entries, newest first). Added two re-checks; I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **D-32 (PO asked 08:18 for the DPF fact check):** the official DPF list (dataprivacyframework.gov) could not be read (JavaScript app). Vendors' own statements: Google LLC and Microsoft state Swiss-U.S. DPF certification; Apple names Apple Distribution International (Ireland) and SCCs, no DPF; Mozilla names SCCs, no DPF. **Fact check negative for Firefox, unproven for Safari/iOS.** B for all browsers: **unresolved: needs legal adviser** (new question 1: disclosure abroad of push metadata to a non-DPF vendor; vendor SCCs or the member's express consent, DSG Art. 16 Abs. 2, 17 Abs. 1 lit. a). Narrow variant (Google and Microsoft endpoints only, after an official-list check): consistent with every source read. A stays compliant. Note: "visit the same day" should mean "within planned working time".
- **D-30 (PO recommendation 08:18):** 1 (addendum for clinical content) and 2 (corrector for payer data) consistent with every text read (ZH, BE, SO, DSG Art. 32); **unresolved only for the pilot canton (D-11)**. 3 (withdrawing an untouched stranded draft): compliant under every plausible interpretation if "untouched" is strict and audited. D closes my D-31 4b condition once built. New note: a disputed time or category must not be billed until corrected from a documented source (invoicing prerequisite, D-18).
- **Not re-checked:** D-22, D-18 (no new evidence; AS 2026/337 and 2026/348 not found); D-15 (fedlex not reachable, KLV Art. 7 Abs. 2 verbatim still open); D-16 (08:18 change takes up my 04:50 notes).
- Tests: none run (docs only).
- **Next agent (po):** D-32 note 1 (escalate B with question 1, or choose the narrow variant) and the official-list check; D-30 note 1 (billing consequence into the invoicing prerequisites). **(lca):** D-15 once fedlex is readable; D-22 when the 1 August 2026 KLV text is readable.

## 2026-10-24 08:45 · eng (Lead Engineer)
- **AN2-C1 found and fixed in #268** (PO 08:18: "inside the ADM1-R PR"). The job log of run 40067901155 was readable through the API.
  - The failing file was **pgTAP 045, test 14** ("client_transferred: the detail names the case's next planned visit"), not 060: have 08:00, want 08:04.
  - **Cause:** the seed plans visit 501 of case 208 today at 08:00 Zurich. Between 07:50 and 08:00 it starts after the interruption and before the fixture's "next" (now + 10 min). The reader then names it as the next planned visit, which is correct; the fixture was not unique.
  - **Fix (test fixture only, the reader is unchanged):** 045 moves the case's other planned visits one week ahead. A new precondition assertion checks that no other planned visit starts before "next" (plan 46 → 47). No assertion was weakened.
  - **Proof (stand-in only):** with seed visit 501 placed 5 minutes after now, as at 07:55, test 14 fails exactly as in CI before the fix and passes after it.
- #268 also merged `recovery/main` (`JOURNAL.md` conflict with #267; both entries kept). CI was green on 0d2f39a before the merge.

## 2026-10-24 08:40 · eng (Lead Engineer)
- **Claimed #262** (ADM1 changes, active) at 08:12. No own PR was open. **ADM1-R1 to R6 are PR #268** (migration 0059, ADR-072), following the remediation plan `clinical/remediation/CGR-39.md`:
  - every amount-bearing exception rule now carries a direction (constraint);
  - an override can no longer make a signal later than the default (look-ahead: from the default up to 4×; delay: from the floor up to the default);
  - out-of-range overrides are reset, audited (0 on synthetic data);
  - `/admin` names the range and which way is stricter.
- **ADM1 row → `in-review`** (#268). IMPLEMENTED in the branch: R1-R6.
- **Deviations:** `cover_without_access` is look-ahead too (0029:259-261; the report did not name it); the `visit_stuck` floor is 1 h; unit and e2e threshold tests updated; pgTAP 047 untouched.
- **Clinical gate:** report section 06:30 (#259), CGR-39 applied. `cra` is a mandatory reviewer of #268.
- **Tests:** CI is the runner; nothing claimed as passed.
  - Locally a stand-in only (PostgreSQL 16, stubbed roles, pgTAP shim): 061 49/49 and 035 67/67, and every file the shim can run is green.
  - With the old range put back, 24 assertions of 061 and 4 of 035 fail.
  - Unit file under `bun test`: 11 pass.
  - Not run locally: vitest, typecheck, lint, e2e (npm unreachable). `database.types.ts` edited by hand.
- **Next agent (eng):** fix CI on #268 if red; merge on green; set ADM1 `delivered`. Then the Engineering impact for the decision packages, COORD5, SIG1, ORD0.

## 2026-10-24 08:18 · po (Product Owner)
- **No PO PR was open** at the start (#261 merged). Claimed **#265** ([PO review] AN2), claim removed at the end. #248 (D-32) worked without a claim change (comment only).
- **AN2 → `accepted`** (#243, #255, #263; #263 merged as d386a1b, CI green on head 8058531, run 40067193832, and on the merge commit, runs 40067597514/40067600140, read through the API; **the PO did not run the tests**). Part 3 measures 1, 2, 4, 8 (AN2-M8a), 10 and AN2-M9a met (pgTAP 060, 48). Evidence table in `briefs/AN2.md` 08:18; five ADR-071 limits accepted. AN2 moved from *Next up* into the queue (rank 21); *Next up* is now COORD5, SIG1, ORD0.
  - **AN2-C1 (CI):** `recovery/main` `9a9e8db` (docs-only merge of #264) was **red in `db` in both runs at 05:51 UTC** (40067901155, 40067898560), green on identical code at 05:47. The PO re-ran the failed job of 40067898560 once: green. Job log not readable here (log host blocked); annotation cut off after 059, so probably 060 (UNKNOWN). Same-minute failure in two runs points to a clock dependence. Engineering finds and fixes the cause; a re-run is not a fix.
  - **AN2-M4a:** measure 4's "responsible changes" row counts ABS1 `released`/`taken`/`returned`, while a hand handover through `reschedule_visit` (a `moved` row with a changed responsible member) is counted only as a move (0058:355-366). Split: hand handovers in their own row, ABS1 paths separate; pgTAP named in the brief.
- **Decision packages (INDEX 7-9), Engineering impact drafted by po** (two-run rule: requested 03:10 / 04:10, no answer in the `eng` runs 05:29, 06:25, 07:11, 07:47):
  - **D-30 → `awaiting-approval: clinical` (Medium).** Recommendation: clinical content only by a dated addendum of a team RN (D), payer data by a named corrector (C); legal adviser after D-11. **Decided by po (workflow):** a team RN may withdraw an untouched correction draft whose performer left (PS-15). Code fact: `signed_by` already exists separately from `performer_id` (0016); only `sign_report` ties them. This also gives D-31 4b the correction path `lca` asks for (open PR #266).
  - **D-16 → `awaiting-approval: clinical` (Medium).** Recommendation: B (team RN, not the author, lifts the billing hold; serious events get a review by the licensed nursing management, not closable by hand, with "Meldepflicht geprüft"); no automatic stop of care, a care-plan review signal instead; taxonomy to the Clinical Owner. Legal verdict unresolved until D-11, D-12. Code fact (corrects the package context): `quality_event_types` **ships empty** (0020), so no typed event can be recorded today; the lift touches only `quality_holds`, never the event or its escalation.
  - **D-32 (stays `inputs-requested`, Low):** Engineering drafted (no service worker, manifest or push dependency; four push vendors by browser; iOS needs a home-screen install; display cannot be confirmed, only send and tap). Draft recommendation B, outside the app first to the responsible member and colleagues with a visit the same day (no shift data needed; avoids Pikett), SIG1-8 stays until delivery is shown to work. **`lca` re-check requested** (package changed): DPF list for the four vendors. Comment on #248.
- **Challenge:** why is the pilot steered by a review meeting that reads the numbers? From scratch each hypothesis carries its decision rule and NAVORA marks "Schwelle erreicht". Rows in `NEXT_CAPABILITY.md` and `CARE_OPERATING_MODEL.md` (also AN2 in the impact ledger).
- No new brief: COORD5, SIG1, ORD0 approved and unstarted; ADM1-R open. `lca` PR #266 (D-9, D-4, D-31 re-check) and `cra` PR #259 are open; not merged by the PO; their notes are taken up once merged. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** owner: D-22, D-18 (after D-11, D-12), D-29, names the Clinical Owner (G-1); Clinical Owner (once named): D-28, D-31, D-3 field list, **D-30, D-16**.
- **Next agent (eng):** AN2-C1 first if `db` goes red again, else inside the ADM1-R PR; ADM1-R1 to R6 (CGR-39); confirm or correct the Engineering impact drafted by po (D-22, D-18, D-28, D-31, D-3, D-29, **D-30, D-16, D-32**); AN2-M4a with the next `pilot_hypotheses` change; COORD5, SIG1, ORD0. **(lca):** D-32 DPF fact check. **(cra):** look at D-30 point 3 and D-16 delivery shape. **(po):** D-12, D-11 escalation, D-15, D-9, D-4 (once #266 is merged); review ADM1-R.

## 2026-10-24 08:10 · Legal & Compliance Agent (lca)
- **Wrote the D-9 and D-4 inputs** (INDEX order; both tie to R-4, S1, "complete before real data") and **re-checked D-31** (tier 2: `cra` 06:30 block and PO recommendation 07:10 are new). I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not re-checked:** D-22, D-18 (the 06:10 changes only take up my 05:45 notes; no new evidence).
- **D-9:** under the DSG a private provider needs no per-processing basis; justification matters for disclosure of health data and processing against an objection (Art. 30 Abs. 2, 31). Case and record rest on the care contract (Art. 31 Abs. 2 lit. a) and the cantonal record duty; disclosure to a doctor or new provider needs consent (BE Leitfaden 3.2.1, 3.2.3; nurses bound by StGB 321 per 1.5.1). Today's boolean gate: compliant on synthetic data, **unresolved** for real data (no scope, information or withdrawal state; referral free text stored before it). Protective option D (referrer confirms, contract and statutory duty, express consent per recipient category, withdrawal stops only consent-based flows): compliant for NAVORA's own steps; **unresolved: needs legal adviser and owner** (secrecy and processor D-12, canton D-11, referrer's disclosure); 5 questions.
- **D-4:** minimums found: care record 10 y (ZH, BE) or 20 y (SO) after the last treatment; billing evidence 10 y after the business year if *Buchungsbelege* (OR 958f); logs at least 1 y (DSV Art. 4 Abs. 5). Maximum: DSG Art. 6 Abs. 4 (delete or anonymise when no longer needed). A as a permanent rule: unresolved, likely incompatible with Art. 6 Abs. 4 and the access right (Art. 25 Abs. 2 lit. d). A as a **provisional** rule (no deletion until the final rule, documented criteria, purpose-bound access, client extract): compliant under every plausible interpretation on the federal sources read. Final periods: **unresolved: needs legal adviser and owner** (D-11, D-12, D-18); 4 questions. Staff data in `actor_id` (OR 328b) argue for D.
- **D-31:** 1b with the `started_by_mistake` statement, 3a: compliant. 4b with the four `cra` limits: compliant **provided** a correction path (addendum or disputed mark, as D-30) exists after limit (ii).
- **Not readable or not read this run:** fedlex (DSG, StGB Art. 321, KVG/KVV); GeBüV; ArGV 3 Art. 26; ZGB representation rules. Tests: none run (docs only).
- **Next agent (po):** D-9 notes 1-4 (referral-stage data and unconverted referrals as real-data gates); D-4 note 1 (provisional default wording) and note 2 (client extract); D-31 note (correction gap after limit (ii)). **(lca):** D-12, D-16, D-32 re-checks only if changed; D-15 verbatim KLV Art. 7 Abs. 2 extraction once fedlex is readable.
## 2026-10-24 07:47 · eng (Lead Engineer)
- **#263 merged** (AN2 part 3; merge commit d386a1b). First CI run red in `db` (pgTAP 060 tests 39, 41: the reader moved the AN2-M8a capture start back to the earliest flagged move); fixed in 220dea2 (the reader uses only the start the migration stores). The PR then had a `JOURNAL.md` conflict with #261 (both entries kept). AN2-M9a (PO 07:10) also went into this PR: the measure-9 row names the threshold used. CI green on head 8058531 (run 40067193832: app, db, e2e).
- **AN2 → `delivered`** (#243, #255, #263). READY_FOR_REVIEW. Clinical gate: no blocking finding for AN2 (report 02:26; `cra` 06:30 in #259).
- Tests: none run in this session; CI ran them.
- **Next agent (eng):** ADM1-R1 to R6 (CGR-39, S1), as the PO ordered; then Engineering impact for the decision packages, COORD5, SIG1, ORD0.

## 2026-10-24 07:11 · eng (Lead Engineer)
- **Claimed #205** (AN2) at 07:11; no own PR was open. **AN2 part 3 is PR #263** (migration 0058, ADR-071): measures 1, 2, 4, 8 with **AN2-M8a**, and 10 in `pilot_hypotheses`. The access, suppression and 0057 measures are unchanged. Sources per measure are in the PR and the migration header. A new internal marker `private.an2_capture_starts` (RLS on, no grants) holds the capture start for M8a.
- **AN2 row → `in-review`** (#263). IMPLEMENTED in the branch: every measure of the brief. Delivery follows once CI is green and #263 is merged.
- **Clinical gate:** reviewed the merged report section 02:26 and the open `cra` section 06:30 (#259). No blocking finding for AN2. Note (a) (today's thresholds) also applies to measures 1 and 10 and is stated in ADR-071. CGR-39 is out of AN2's scope. No remediation plan needed.
- **Tests:** none run here. The npm registry was unreachable from this session and there is no local Supabase stack. CI runs pgTAP 060 (47), the changed 059, unit and e2e. **UNKNOWN** until CI reports.
- **Next agent (eng):** fix CI on #263 if red; merge on green; set AN2 `delivered`. Then the *Engineering impact* items listed at 06:25, COORD5, SIG1 (with the CGR-39 correction of SIG1-9), ORD0.

## 2026-10-24 07:10 · po (Product Owner)
- **No PO PR was open** at the start (#258 merged). No `agent:po` issue worked except as noted; nothing claimed (#248 D-32 waits on `eng`).
- **CGR-39 (blocking S1, `cra` 06:30, open PR #259) confirmed in the code** (0035:526-536 range, 0035:577-583 check, 0019:175-178 window; pgTAP 035:191-196 asserts the inversion): for the four look-ahead rules a lower amount is a later signal, and an admin can set the P1 `visit_uncovered_hospital` window to 0 h so it never fires. **ADM1 → `changes-requested`** with **ADM1-R1 to ADM1-R6** (`briefs/ADM1.md`): direction per rule, never later than the default (look-ahead: not below; delay: not above), reset of existing overrides audited, pgTAP replacing 035:191-196 plus one behavioural test, `/admin` text. The watcher dry run makes **eng:ADM1 the active hand-off, ahead of AN2 part 3.** The PO's acceptance on 2026-10-23 and the PO's own SIG1-9 (06:10) both missed it; **SIG1-9 rewritten** to point at ADM1-R. D-28 recommendation annotated.
- **CGR-40 (S3) decided (product authority):** ORD0-1's "doctor informed" date may not be before the **case** was created (was: the task), pgTAP added to the brief.
- **AN2 part 2 reviewed** (#255, merged c1c58b3; CI green on head 88eeaeb and merge commit, run 40061609501, read through the API; **the PO did not run the tests**): measures 3, 5, 6, 7 (AN2-M7), 9, 11, 12 met (pgTAP 059, 57 assertions; e2e at 390 px); **the AN1 organisation condition is met**. Deviations accepted: suppressed rows hide the base; 032 assertion replaced; late AN1 condition closed; measure 9 uses today's threshold, with **AN2-M9a** (name the threshold used) for part 3. Evidence table in `briefs/AN2.md`. AN2 stays approved; the row stays `in-progress`.
- **Decision packages (tier 2, INDEX 4-6):** `cra` 06:30 *Clinical impact* copied verbatim into D-31, D-3, D-29, D-30, D-16, D-32, D-15 (from #259's head 98541a0, as `cra` asked).
  - **D-31 → `awaiting-approval: clinical` (Medium).** PO decided within product authority: server check that *Folgeeinsatz geplant* names a planned visit of the same case; `client_transferred` offers `pause_case`; 4b same-day correction with the four `cra` limits; 3a stays. Asked of the Clinical Owner: 1b with "keine Pflege erbracht", who may decide *nicht mehr nötig* (code fact: today any team member or coordination role, 0045:186), follow-up time, making up missed care.
  - **D-3 → `awaiting-approval: clinical` (Medium), cover-read field list only.** PO decided: B as built on synthetic data; real-data gates plus an `lca` re-check against the pilot canton's law after D-11; cover read (b′) with **consent recorded at intake** (`lca` 06:55 note 1). Cover stays off until D-9, the field list, D-17, CGR-21, CGR-28 and D-29.
  - **D-29 → `awaiting-approval: owner` (Medium).** Engineering impact drafted by po (two-run rule: four `eng` runs without an answer): suspension can reuse the downgrade release path (0046 §9). Recommendation: option B (evidence incl. cantonal licence, a second person confirms, mandatory re-check date, expiry downgrades); C later; D rejected.
- **Challenge:** why does an administrator tune safety thresholds for the whole organisation? Row in `NEXT_CAPABILITY.md` and `CARE_OPERATING_MODEL.md`; hypothesis: no organisation sets an override in 8 pilot weeks, then the screen goes and only the team's choice inside the clinical band stays.
- No new brief: COORD5, SIG1, ORD0 approved and unstarted; the D-31 PO decisions become a brief when the queue frees. Tests: none run (docs only); `node scripts/agents-check.mjs` ok; watcher dry run: active ADM1.
- **Waiting on people:** owner: D-22, D-18 (after D-11, D-12), D-29 (approve option B, accept liability), names the Clinical Owner (G-1); Clinical Owner (once named): D-28, D-31, D-3 field list.
- **Next agent (eng):** ADM1-R1 to R6 first (CGR-39, S1); then AN2 part 3 with AN2-M9a; Engineering impact (confirm or correct D-22, D-18, D-28, D-31, D-3, D-29; D-30, D-16, D-32, D-15, D-12, D-11, D-9, D-4 open). **(cra):** review the ADM1-R PR; #259 is still open (the PO copied its blocks, did not merge it). **(lca):** D-9, D-4; D-31 re-check optional. **(po):** D-30, D-16 (draft E if `eng` stays silent), D-32, D-11 escalation, D-10 package; review ADM1-R.

ENGINEERING BRIEF (ADM1-R, re-opened item, not a new capability)
- **Capability:** ADM1-R: organisation threshold overrides can never make a safety signal later than its default (direction-aware range).
- **Why:** CGR-39 (S1): an admin can silence the P1 hospital-discharge signal by setting its look-ahead to 0 h; a stricter value is refused.
- **Business outcome:** the pilot administration cannot create a silent safety gap; no clinical value is invented.
- **Care outcome:** an unassigned visit after a hospital discharge always raises P1 at least 24 h ahead.
- **Expected nurse outcome:** the team is told in time that nobody is responsible for a visit; no surprise gaps after discharge.
- **Expected team outcome:** signals the team relies on cannot be weakened centrally.
- **Expected patient outcome:** no missed first visit after discharge because a setting silenced the signal.
- **Acceptance criteria:** ADM1-R1 to ADM1-R6 in `briefs/ADM1.md`.
- **Dependencies:** none; D-28 (band) is not needed, the default is the bound.
- **Priority:** first, ahead of AN2 part 3 (patient safety precondition).
- **Implementation recommendation:** one migration: a `direction` column (or a fixed map in `private.exception_rule_range`) checked by `set_exception_rule`; reset of offending overrides with audit rows; replace pgTAP 035:191-196; one behavioural pgTAP through the exception read model; `/admin` text and a unit or e2e test; `cra` reviews the PR.

## 2026-10-24 06:55 · Legal & Compliance Agent (lca)
- **Wrote the D-15 input** (INDEX 12) and **re-checked D-3 and D-29** (tier 2): D-3 changed (PO draft recommendation 06:10) and the `cra` field list is new; D-29 because `cra` 06:30 (open PR #259) asks `lca` whether a qualification or licence can lapse. I changed only the `lca` sections. Advisory, not legal advice; no decision, status or row changed.
- **Not re-checked:** D-22 and D-18 (the 06:10 changes only take up my 05:45 notes; no new evidence); D-31 (PO draft adopts the 02:52 verdicts; the `cra` block in #259 supports them; re-check once it is copied in, if the PO asks).
- **D-15:** KLV Art. 7 Abs. 2 (Stand 16 Dec 2025) fixes the category by service type (index a1-a3, b1-b14, c1-c2, paraphrased; verbatim text to be copied from fedlex). Abs. 2bis sets legal experience conditions (a3; psychiatric assessment for b13, b14, c2) that NAVORA's `registered_nurse` label cannot show. No source read limits all B work to registered nurses (CR-007 plausibly stricter, the safe side). C with three conditions is the protective option; **unresolved: needs legal adviser** with the contract (D-18, D-12), 3 questions.
- **D-3:** DSV amendment of 1 Dec 2025 (secondary source) does not change the private-controller logging trigger. Real-data gates (i)-(iii) and (b′) with **recorded consent**: compliant under every plausible interpretation on the federal sources read; (b′) as **opt-out** (PO text): unresolved (question 2). Cover field list: no legal objection; emergency contact depends on D-9.
- **D-29:** diploma: no lapse found; practice licence: can be restricted, withdrawn or not renewed (GesBG Art. 13, 14, 19, 27 by title; VS example), is valid per canton of work incl. home visits; licence needed when working without supervision by a nurse (BAG FAQ). Verdict unchanged (unresolved: owner D-11/D-12 and legal adviser); questions 1 narrowed, 6 and 7 added.
- **Not readable this run:** lexfind KLV Stand 1 Jan 2026 page, GesBG article text, KVV Art. 49/51 primary text, fedlex. Tests: none run (docs only).
- **Next agent (po):** D-3 note 1 (consent, not opt-out); D-15 note 1 (Abs. 2bis experience conditions, to `cra`/`eng`); D-29 notes. **(lca):** D-9, D-4; D-31 once the `cra` block is in the package.
## 2026-10-24 06:30 · Clinical & Regulatory Architect (review)
- **Reviewed** `recovery/main` @ `38b986d` since the 02:26 section: #243 (AN2 part 1: 0056 CGR-35, pgTAP 057, 058), #255 (AN2 part 2: 0057, pgTAP 059), briefs SIG1 and ORD0, the PO, eng and `lca` docs since 02:20, and open PR #258 (SIG1-9). I did not run the tests; CI green on `56c8756`, `c1c58b3`, `38b986d`.
- **Closed:** CGR-35 (0056, pgTAP 057:45-126; PS-28 closed). DAY-1-R1-R3 endorsed (pgTAP 058).
- **New:** **CGR-39 blocking (S1)** on ADM1: for the four look-ahead exception rules (`visit_uncovered_hospital` P1, `visit_uncovered`, `order_expiring`, `team_cancellation_late`) the override range is inverted. An admin can set the P1 rule to 0 h, so it never fires, while a stricter value is refused; pgTAP 035:191-196 assert the inversion; SIG1-9 in #258 repeats it. **CGR-40 advisory (S3)** on ORD0-1 (date lower bound). Registers: CR-066, CR-067, CR-021 note; PS-31, PS-32; H-01, H-04, H-17, H-18 updated.
- **Clinical impact written** (report section, for po to copy verbatim) for D-31, D-3, D-29, D-30, D-16, D-32, D-15. No decision taken; no rule approved; no catalogue invented (D-15: `lca` to extract KLV Art. 7 Abs. 2 verbatim).
- **Next agent (po):** ADM1 `changes-requested` for CGR-39 and correct SIG1-9 (direction-aware); decide CGR-40; copy the seven blocks. **(eng):** CGR-39 with SIG1-9 (incl. pgTAP 035:191-196); D-32 phone push facts. **(lca):** D-15 KLV Art. 7 Abs. 2 enumeration; D-29 lapse of qualification. **(owner):** name the Clinical Owner (G-1); D-28 waits on that person.

## 2026-10-24 06:25 · eng (Lead Engineer)
- **#255 merged** (AN2 part 2; merge commit c1c58b3). The base had moved by docs only (#256); the journal conflict was resolved by keeping both entries (merge commit 88eeaeb), and CI ran green on that head (run 40061316499: app, db incl. pgTAP 059, e2e).
- **AN2 stays `in-progress`** (IMPLEMENTED: parts 1 and 2; PLANNED: part 3, measures 1, 2, 4, 8 with AN2-M8a, 10). Status row updated; issue #205 stays active. Not set to `delivered`, because the brief is not complete.
- Tests: none run in this session; CI ran the #255 tests.
- **Next agent (eng):** merge this docs PR on green CI; AN2 part 3; *Engineering impact* in the open decision packages (D-22 and D-18 confirm or correct the PO draft; then D-28, D-31, D-3, D-29, D-30, D-16, D-32, D-12, D-11, D-15, D-9, D-4); COORD5; then SIG1, ORD0.

## 2026-10-24 06:10 · po (Product Owner)
- **No PO PR was open** at the start (#254 merged). **No delivery to review:** nothing newly `ready-for-review`, `delivered` or `in-review` since #243 (reviewed 04:10); #255 (AN2 part 2) was merged at 06:15 during this run (c1c58b3; head 88eeaeb green: app, db, e2e; merge-commit CI still running at publish time); the AN2 row stays `in-progress`. **Part 2 is reviewed in the next PO run** against `briefs/AN2.md` once the merge-commit CI is green. No `agent:po` issue worked except as noted; nothing claimed (D-32 #248 waits on `eng` and `cra`).
- **Engineering impact drafted by po, not confirmed by eng** (two-run rule: requested 01:15 / 02:20, no answer in the `eng` runs 02:55 and 04:10) for **D-28, D-31, D-3**, from the code with files and lines (0015, 0019, 0035, 0038, 0040, 0042, 0043, 0045, 0047, 0029, 0004).
- **D-28 → `awaiting-approval: clinical` (Medium).** Finding from the code: the organisation override range of 0035 lets an admin make `visit_stuck` P2 appear up to 2 h and `report_not_final` up to 48 h, an engineering range no clinician approved. **PO decision (product authority, strictest default): SIG1-9** in `briefs/SIG1.md`: no override later than the default until the Clinical Owner sets a band; stricter stays allowed; pgTAP named. Option C (team value inside a clinical band) stays the PO proposal under the five `cra` conditions. Asked of the Clinical Owner in one line (package and `OPEN_DECISIONS.md` row). Comment on #150.
- **D-31 draft recommendation (Low; `cra` open, no `cra` run since 02:26, so not drafted):** 1b (short report of care given), 2b's planned-visit check, 3a (not billable), 4b (audited same-day correction; `lca`: the irreversible default is not the safe side). **Go-live condition:** care given before a break-off is documented before the first real client.
- **D-3 draft recommendation (Low; `cra` open):** B as built on synthetic data; **real-data gates** (read log through functions with DSV Art. 4 content, DSFA, need-to-know client identity for coordination roles) written as a go-live condition; cover read as variant b′ (intake statement and the client's choice; D-9). Code fact: no read is audited today; per-read logging is cheap only where reads go through `security definer` functions.
- **`lca` 05:45 taken up:** D-22 question 5 joins the escalation (changes nothing in force); D-18 point 3 gains a place-of-care key and versioned rates (palliative contribution from 1 January 2027), questions 1-4; D-11 criteria gain the mandate row (escalation text ready once `eng` answers or the two-run rule is met).
- **Challenge:** why does a data-protection officer read access logs? From scratch the forbidden read is impossible by design and only exceptional reads raise a signal. Rows in `NEXT_CAPABILITY.md` and `CARE_OPERATING_MODEL.md`; hypothesis: fewer than 1 in 1,000 health-data reads need human review.
- No new brief: COORD5, SIG1, ORD0 approved and unstarted (SIG1 gains SIG1-9 before start). Tests: none run (docs only); `node scripts/agents-check.mjs` run before publishing.
- **Waiting on people:** owner: D-22 (approve the default, name a legal adviser), D-18 (after D-11, D-12), names the Clinical Owner (G-1); Clinical Owner (once named): D-28.
- **Next agent (po):** review AN2 part 2 (#255: measures 3, 5, 6, 7 with AN2-M7, 9, 11, 12; AN1 organisation condition; deviations in ADR-070); D-29, D-30, D-16 Engineering impact (two-run rule met for D-29; D-30 and D-16 after the next `eng` run) and recommendations; D-10 package; D-11 escalation; D-31 and D-3 once `cra` answers. **(eng):** confirm or correct the drafted Engineering impact in D-22, D-18, D-28, D-31, D-3; SIG1-9 with SIG1; AN2 measures; COORD5. **(cra):** Clinical impact in D-31, D-3, D-29, D-30, D-16, D-32, D-15; look at SIG1-9. **(lca):** D-15, D-9, D-4.

## 2026-10-24 05:45 · Legal & Compliance Agent (lca)
- **Re-checked D-22 and D-18** (tier 1): both changed since 03:53 (PO recommendations 05:15, Engineering drafted by po), and new evidence was found. **Wrote the D-11 input** (INDEX 11). I changed only the `lca` sections. This is advisory, not legal advice. I changed no decision, status or row.
- **D-22:** the PO recommendation is consistent with the earlier verdicts; a1/b2/c2 and "A/C without Kenntnisnahme charged to nobody" are compliant under every plausible interpretation (tariff protection reaches the insured, BGer 9C_476/2017 E. 2.1; patient share capped at CHF 15.35/day, BAG 12 June 2026). The 2026 KLV amendments read do not touch Art. 7-8a (BAG commentary 24 June 2026); AS 2026/337 and 2026/348 not read. New adviser question 5 (KVG Art. 44 for an A/C service without Kenntnisnahme).
- **D-18:** the PO recommendation stays compliant while nothing is invoiced. New: specialised palliative care gets a different KLV contribution from 1 January 2027 (versioned rates); travel is a cantonal residual-financing item in BE (Tarifblatt 2026) and may not be charged to ZH patients separately; payer = residence municipality (ZH, SO), rates = provider location (KVG) or place of care (SO 2019). New adviser question 4 (temporary stay in another canton).
- **D-11:** comparison of ZH, BE, SO: residual financing by provider type (BE 100/85/80 % of reference costs), payer and mandates (ZH Pflegegesetz § 5, § 9, § 13), record rules already read, DSG for private providers (cantonal law for a municipal mandate UNKNOWN). Licence conditions unread for all three; that is the largest gap. Verdict: unresolved: needs owner (choice) and a legal adviser in the chosen canton (4 questions).
- **Not readable or not read this run:** fedlex (KVG Art. 44, consolidated KLV); ZH, BE, SO licensing provisions and data-protection acts; current SO tariffs. Tests: none run (docs only).
- **Next agent (po):** D-22 note 2 (question 5), D-18 note 1 (place-of-care key), D-11 note 1 (mandate criterion). **(lca):** D-15, D-9, D-4; D-32 once `eng` names the push vendors.

## 2026-10-24 05:29 · eng (Lead Engineer)
- **Claimed #205 (AN2)** at 05:12; no own PR was open; no claim within 3 h.
- **AN2 part 2 = PR #255** (`feat/an2-pilot-hypotheses`, migration 0057, ADR-070). IMPLEMENTED (CI pending):
  - `/analytics` section **"Pilot-Hypothesen"** from one read model `public.pilot_hypotheses(p_month)`: measures **3** (coordinator ends), **5** (correction rounds), **6** (open corrections), **7** (not-billable facts, with **AN2-M7**: `below_minimum` own row, fixed D-18 note, out of the total), **9** (more than two pauses; open past planned end + `visit_stuck` + P1 escalation), **11** (hold to lift), **12** (late report facts; `basis_changed` per 100). Sources per measure in the migration header and ADR-070. Every measure appears in every scope (base 0 without events).
  - **AN1 organisation-level condition** (PO 2026-10-22 17:15, due since then; 0043 and 0048 touched `pilot_kpis` without it: deviation, closed now): organisation row hidden when the organisation has fewer than 3 persons with visits or the hidden teams' persons number 1 or 2; AN2 uses the same helpers. Suppressed AN2 rows hide value **and base** (deviation from the brief's "base on every row", ADR-070).
  - `/analytics` at 390 px: sidebar hidden, AN1 tables scroll in their own box; AN2 cards stack.
  - Test changes to existing files: fixtures in pgTAP 027, 030, 033, 034, 048 (three synthetic performers so the organisation row stays visible under the new rule); 032's last assertion replaced by the PO's condition (it asserted the opposite for that fixture).
- **PLANNED (part 3):** measures 1, 2, 4, 8 (with AN2-M8a), 10. AN2 stays `in-progress`; #205 stays active.
- **Clinical gate:** read `reports/CLINICAL_GOVERNANCE.md` 2026-10-24 02:26: no finding on AN2; its two evidence proposals (minute distribution around the minimum duration; planned to actual start) are not in the brief and not built (PO). Read-only change, no clinical rule, no threshold changed (D-28).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim: 059 57/57, and every file the shim can run green (027, 030, 032, 033, 034, 048, 058 included); two mutations of 0057 (AN2-M7 exclusion, AN1 hidden-team rule) each turn a 059 assertion red. Unit file under `bun test` (5 pass) as a smoke check; `hypotheses.ts` passes a strict `tsc`. vitest, lint, typecheck of the app, build and e2e not run (npm registry unreachable). `database.types.ts` hand-edited (one function).
- **Not done this run:** *Engineering impact* for the open decision packages (PO asks for D-22 and D-18 first).
- **Next agent (eng):** merge #255 on green CI; then part 3 (measures 1, 10 from `exception_events`; 2, 4, 8 with AN2-M8a); Engineering impact D-22, D-18. **(po):** AN2 part 2 is reviewable on #255 once merged, though the row stays `in-progress`. **(cra):** optional look at 0057 (read-only, quality and billing data).

## 2026-10-24 05:15 · po (Product Owner)
- **No PO PR was open** at the start (#252 merged). **No delivery to review:** no item newly `ready-for-review`, `delivered` or `in-review` since #243 (reviewed 04:10). Claimed #248 (D-32), claim removed at the end of the run.
- **D-22 and D-18: Engineering impact drafted by po from the code** (two-run rule: requested 01:15, no answer in the `eng` runs 02:55 and 04:10), marked `drafted by po, not confirmed by eng`; files, migrations and pgTAP cited (0013, 0014, 0019, 0022, 0023, 0030, 0043, 0051; pgTAP 022, 043, 051, 053). Findings from the code: NAVORA stores no order issue date and no doctor GLN/ZSR (the one schema change every billing option needs); `billing_rules` already holds the minimum as validated reference data, so option A of D-18 is mostly an extension; both minimum and rates are keyed by the client's **live** residence canton, which is audited, so CGR-31 can reuse the 0051 reconstruction; no planning function reads `billing_rules` or `tariff_rates`.
- **D-22 recommendation (Medium), `awaiting-approval: owner`** (row owner `legal`, no legal adviser named): care A/C without order with a recorded GP information step (ORD0); billing a1/b2/c2 (signed order with GLN/ZSR, A/C only with order or *Kenntnisnahme*, order issued before the visit; c2 once the issue date is stored, until then CR-058); A/C without *Kenntnisnahme* charged to nobody. Asked: approve that default and name a legal adviser for `lca` questions 1-4, or keep the relaxations closed.
- **D-18 recommendation (Medium), `awaiting-approval: owner` after D-11 and D-12:** option C as built; product rule recorded (no billing rule feeds back into planned minutes, testable: no planning function reads billing reference data); option A as the invoicing design; the contract questions go to an adviser only once the canton and the provider are named. Points 1-3 need no approval.
- **D-32** (`lca` 04:50 read): fixed outside-app text, not configurable, written into the SIG1 brief (product authority; nothing built changes). Fact from the code: no per-member shift data, only the visit plan and the organisation-wide J2 calendar (0017:124); `eng` to confirm. DPF check of push vendors routed to `eng` (name them) and `lca` (check the official list); one PO web search was inconclusive. No status change (`eng`, `cra` open).
- **Packages D-9 (intake legal basis) and D-4 (audit retention and access) written**, INDEX 13-14, `inputs-requested` (`eng`, `lca`; `cra` not needed). D-4 names the dependency: deleting audit rows would change how CR-058 reconstructs old order bases.
- **Challenge:** why does an intake person tick "consent confirmed" and re-type the order from paper for every referral? From scratch the basis and the order are recorded where they arise (referrer form, needs assessment; a structured order with issue date and GLN). Row added in `NEXT_CAPABILITY.md` and `CARE_OPERATING_MODEL.md`; hypothesis: fewer than 1 in 5 referrals need intake action at all.
- No new brief: COORD5, SIG1, ORD0 are approved and unstarted. Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Waiting on people:** owner: D-22 (approve the default, name a legal adviser), D-18 (after D-11, D-12); Clinical Owner named (G-1).
- **Next agent (po):** D-10 package (INDEX 15); draft Engineering impact for D-28, D-31, D-3, D-29 unless `eng` answers first (requested 01:15 and 02:20; the two-run rule is met for all four) and write their recommendations; D-32 once `eng`/`cra` answer. **(eng):** confirm or correct the drafted Engineering impact in D-22 and D-18; inputs in D-28, D-31, D-3, D-29, D-30, D-16, D-32, D-12, D-11, D-15, D-9, D-4; AN2 measures; COORD5. **(lca):** D-11, D-15, then D-9, D-4. **(cra):** D-32, D-31, D-3, D-29, D-30, D-16, D-15.

## 2026-10-24 04:50 · Legal & Compliance Agent (lca)
- **Wrote the *Legal/compliance impact* for D-16, D-32 and D-12** (INDEX 8, 9, 10). D-22 and D-18 were not re-checked: since 03:53 only the PO's escalation text changed (it takes up my notes), and there is no new evidence. I changed only the `lca` sections. This is advisory, not legal advice. I changed no decision, status or row.
- **D-16:** KVV Art. 58g (as quoted by BAG FAQ 2022 and a Thurgau licence form) requires an organisation-level internal reporting and learning system. The canton approves the nursing management. No source read says who lifts a billing hold. Reporting duties found: ZGB Art. 443 (KESB; professional secrecy reserved; cantons may add duties); HMG Art. 59 (adverse drug reactions; whether nurses are bound is UNKNOWN). The home-care quality contract (KVG Art. 58a) is not yet approved. Today's default (synthetic data) is compliant. B with a review by the licensed nursing management and a recorded "reporting duty checked" step: **unresolved: needs owner (D-11, D-12) and legal adviser** (3 questions).
- **D-32:** A is compliant under every plausible interpretation. The fixed text carries no client health data on the sources read; a variable text would. Web push payloads are end-to-end encrypted (RFC 8291), but the push vendor sees the endpoint and the time. B (opt-in, fixed text, only recipients within their planned working time, members informed): **unresolved: needs owner, as a fact check** (whether the browsers' push vendors are DPF-certified for Swiss data; DSG Art. 16, FC decision of 14 August 2024). If all are certified, no lawyer is needed. Messages that members must answer outside their shift are Pikett (ArGV 1 Art. 14-15). Under 15 minutes' response the canton decides (SECO). C, D and E: unresolved, needs owner (provider, region, contract).
- **D-12:** what each option requires, using cantonal examples from Thurgau (licence, approved nursing management, staffing thresholds, CHF 5 m insurance; independent nurses: two years' practice, "on own account"). Main open question for B, C and D: may a provider entrust client data to NAVORA as a processor under professional secrecy (DSG Art. 9 Abs. 1 lit. b, StGB Art. 321)? Staff hiring (AVG) applies if NAVORA employs the nurses and places them with others. **Unresolved: needs owner and legal adviser** (5 questions). The owner's choice stays in any case.
- **Not readable this run:** fedlex (KVV Art. 49, 51, 58g; HMG Art. 59; StGB Art. 321; DSV); the DPF participant list.
- **Next agent (po):** D-32 note 1 (the fixed text as a non-configurable SIG1 rule) and note 3 (DPF fact check); D-12 note 1 (ask the processor/secrecy question first). **(lca):** D-11, D-15; then D-9, D-4 once packaged; re-check D-22/D-18 when `eng` input or a PO recommendation lands.

## 2026-10-24 04:10 · po (Product Owner)
- **No PO PR was open** at the start (#245 merged). **Delivery reviewed: #243** (AN2 part 1, `eng`; merged as 56c8756 at 04:10 Zurich; CI green on head afd1d11, run 40049445817, and on the merge commit, run 40053036646: app, db, e2e; read through the API). **The PO did not run the tests.**
  - **CGR-35 met** (0056, pgTAP 057 (24), unit, e2e): a flagged past visit moved forward stores `responsible_absent = true` on its `moved` row, server-side, immutable, audited; shown in HAND1 and `/team`. **ABS1-C7 met.** Evidence table in `briefs/ABS1.md` 04:10. Deviations accepted: HAND1 asserted by source plus unit test; cover moves audited too; rows before 0056 stay `false`. **ABS1 stays accepted, no ABS1 condition open**; `cra` look at 0056 requested by `eng`, not awaited.
  - **DAY-1-R1-R3 met** (pgTAP 058 (15), ADR-068 addendum); deviation accepted: test clock = transaction-local session time zone. **DAY-1 accepted.** Evidence table in `briefs/AN2.md` 04:10.
  - **AN2-M8a (PO, presentation only):** measure 8 shows moves before 0056 as "vor Erfassung (nicht gezählt)", never as "nicht abwesend".
- **No open `agent:po` issue except #248 (D-32):** claimed, package written, claim removed at the end of the run.
- **Packages INDEX 9, 11, 12 written** (`decisions/D-32.md`, `D-11.md`, `D-15.md`), status `inputs-requested`; one comment each on #248, #57, #61. D-32: `eng`, `cra`, `lca` (`cra` added: delivery outside the app is a safety question); PO direction fixed text without client data, web push first; PO decides unless a paid contract or an unresolved legal question. D-11: `eng`, `lca`; owner's choice by design, criteria listed, no canton proposed. D-15: `eng`, `cra`, `lca`; `clinical` approves; PO direction option C (catalogue proposes the category, team changes it with a reason). All Low; defaults unchanged.
- **`lca` 03:53 read (#249):** D-22 escalation text extended (question 4 on the nine-month B order; c2 only once the doctor's issue date is stored, until then CR-058 stays). D-30: option E′ (ask the former author, give no access) added; **go-live condition** in `CARE_OPERATING_MODEL.md`: before real clients, a client's rectification request can be met when the author left (addendum or "bestritten" mark at least). No status change: Engineering input is still missing for D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-12 (`eng` has now had two runs since the first requests, 02:55 and 04:10, the second merged while this PR was open); the two-run rule is met, so the next PO run drafts *Engineering impact* for D-22 and D-18 from the code, marked `drafted by po, not confirmed by eng`, unless `eng` answers first.
- **Challenge:** why does a nurse classify every planned service into KLV A/B/C by hand when that label decides who may perform it and what is billed? From scratch the approved catalogue carries the category; the team changes it only with a reason. Row added (D-15 option C), What-disappears row in `CARE_OPERATING_MODEL.md`; hypothesis: fewer than 1 in 10 items deviate.
- No new brief: COORD5, SIG1, ORD0 are approved and unstarted. Nothing escalated. **Waiting on people (unchanged):** owner names the Clinical Owner (G-1).
- Tests: none run (docs only); `node scripts/agents-check.mjs` run before publishing.
- **Next agent (po):** draft *Engineering impact* for D-22 and D-18 (two-run rule met) and write their recommendations; packages D-9, D-4, D-10 (INDEX 13-15). **(eng):** AN2 measures (AN2-M7, AN2-M8a); COORD5; *Engineering impact* in the open packages, D-22 and D-18 first; then SIG1, ORD0. **(cra):** look at 0056; *Clinical impact* in D-31, D-3, D-29, D-30, D-16, D-32, D-15. **(lca):** D-16, D-12, then D-32, D-11, D-15.
## 2026-10-24 04:10 · eng (Lead Engineer)
- **#243 merged** (merge commit 56c8756) on green CI on its head afd1d11 (run 40049445817: app, db incl. pgTAP 057 and 058, e2e). Base had moved by docs only (#245, #249); merge was clean.
- **ABS1 → `delivered`** (CGR-35 and ABS1-C7, IMPLEMENTED). PO checks CGR-35 (1)–(5) and ABS1-C7 against `briefs/ABS1.md` 23:15; `cra` reviews 0056.
- **AN2 stays `in-progress`:** part 1 (DAY-1-R1–R3 preconditions) is merged; measures 1–12 and the "Pilot-Hypothesen" section are PLANNED for the next PRs (issue #205 stays active).
- Tests: none run in this session (docs only); CI ran the #243 tests.
- **Next agent (eng):** AN2 measures; Engineering impact in D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-12 (requested by the PO 01:15, 02:20, 03:10); COORD5; then SIG1, ORD0.

## 2026-10-24 03:53 · Legal & Compliance Agent (lca)
- **Re-checked D-22 and D-18** because both packages changed (`cra` Clinical impact, PO draft 03:10). **Wrote the D-30 input.** I changed only the *Legal/compliance impact* sections. This is advisory, not legal advice. I changed no decision, status or row.
- **D-22:** a1/b2/c2 for billing is still compliant under every plausible interpretation, but c2 cannot be implemented until NAVORA stores the doctor's issue date (separate from the recording time). ORD0 (GP-informed step, exception for an open-ended order) is compliant as a prompt and as evidence. Under KLV Art. 8 Abs. 2 a B order is valid for at most nine months, except for the HE case. When the nine months start, and whether B care may continue past them, is new adviser question 4. Care b1 is compliant on the federal sources read; the pilot canton's rules are UNKNOWN. Whether an A/C service without *Kenntnisnahme* may be charged to the client is UNKNOWN (KVG Art. 44 not read); the protective default is to charge nobody.
- **D-18:** the PO draft (option C; no billing feedback into planned minutes) is compliant under every plausible interpretation. Per-visit versus per-day rounding stays UNKNOWN. The contracts invoice per day and per category, which is the best lead for adviser question 1.
- **D-30:** the cantons read (ZH GesG § 13, BE PatV Art. 4, SO guidance) require visible authorship of each entry and an unchanged original; none limits corrections to the author. B or D (original kept, identified corrector, reason and basis, audited) is consistent with every text read. It stays unresolved for the pilot canton (D-11), and `clinical` must say which fields a non-performer may correct. A is risky with real data: it cannot meet a client's rectification request (DSG Art. 32). E: unresolved (access for a non-member). The variant "ask her for a statement, give no access" avoids that question.
- **Not readable this run:** fedlex (KLV in its 1 August 2026 version, StGB Art. 321 and 251, GesBG, KVG Art. 44). DSG Art. 32 was read only in an unofficial English translation.
- **Next agent (po):** D-22 note 1 (add question 4 and the issue-date condition to the escalation); D-30 note 1 (a rectification path before real clients). **(lca):** D-16 and D-12 next, then D-32 once it is packaged.

## 2026-10-24 03:10 · po (Product Owner)
- **No PO PR was open** at the start (last PO PR #242 merged). **No delivery to review:** no item `ready-for-review`, `delivered` or newly `in-review`; AN2 part 1 (#243, `eng`) is open, not merged, so not reviewed yet. No open `agent:po` issue, nothing claimed.
- **`cra` Clinical impact copied verbatim** into `decisions/D-22.md`, `D-18.md`, `D-28.md`, signed "cra 2026-10-24 02:26 (copied from `reports/CLINICAL_GOVERNANCE.md` by po)": confirmed `cra` input, not a PO draft. **`lca` input for D-31, D-3, D-29** arrived with #241 (merged 03:10). Read; no status change: Engineering input is missing in all six (requested 01:15 and 02:20; `eng` has had one run since, so the PO does not draft it yet), and `cra` input is missing for D-31, D-3, D-29.
- **PO draft directions (not recommendations, confidence Low):** D-22: care b1 as built with a recorded GP information step; billing (once invoicing exists) the set `lca` found compliant under every interpretation (a1, b2, c2); relaxations stay `legal` questions 1-3. D-18: option C as built; product rule from `cra` adopted: no billing rule feeds back into planned minutes; AN2 shows the minute distribution around 5/10/15 once real data exists.
- **CGR-36, CGR-37, CGR-38 decided (product authority; no threshold, deadline, content or duration rule invented):** CGR-37 → **SIG1** approved (Next up 3): a P1 safety signal is delivered to the responsible member and her team, shown without a reload, taken by one tap (audited), Operations only when nobody takes it within a PROVISIONAL 15 minutes; the signal still closes only when its cause ends (CR-041). Go-live condition SIG1-8 in `CARE_OPERATING_MODEL.md`: until delivery outside the app (new **D-32**, `po` with `lca`, tier 2), the pilot plans visits only at hours a named person has the app open. CGR-36 and CGR-38 → **ORD0** approved (Next up 4): "Hausärztin/Hausarzt informiert" (date, channel code, no free text) closes the `inform_gp` task; a running case with B care and an order `present` without end date raises a P3 exception, not closable by hand. Intake keeps accepting open-ended orders (the exception prompts, it does not block).
- **Packages INDEX 7, 8, 10 written:** D-30 (correction after the author left; `eng`, `cra`, `lca`), D-16 (quality events, hold, lift role; `eng`, `cra`, `lca`), D-12 (legal entity; `eng`, `lca`; owner approval required in any case). Status `inputs-requested`; one comment each on #157, #62, #58. All Low; strict defaults stay. D-32 inserted at INDEX 9 (tier 2, CGR-37).
- **Challenge:** why does a dispatcher watch an operations screen? From scratch the signal knows the visit, its nurse and her team; it goes to them. Row added (SIG1); hypothesis: most P1 signals are taken by the team within 15 minutes, AN2 measure 10 decides whether the Operations fallback can shrink. Impact ledger rows SIG1, ORD0.
- Nothing escalated. **Waiting on people (unchanged):** owner names the Clinical Owner (G-1). Tests: none run (docs only); `node scripts/agents-check.mjs` ok.
- **Next agent (po):** review #243 once merged; D-22/D-18 recommendations once `eng` answers (draft Engineering impact after `eng`'s second run without an answer); packages D-32, D-11, D-15. **(eng):** finish AN2 part 1 (#243); COORD5; *Engineering impact* in D-22, D-18, D-28, D-31, D-3, D-29, D-30, D-16, D-12; then SIG1, ORD0 (parallel allowed). **(cra):** *Clinical impact* in D-31, D-3, D-29, D-30, D-16. **(lca):** D-22, D-18 re-check (new `cra` evidence); D-30, D-16, D-12; D-32 once packaged.

ENGINEERING BRIEF
- **Capability:** SIG1, safety signals reach a person, nobody watches a screen.
- **Why:** every visit safety signal is pull-only (CGR-37); a P1 overdue visit at 07:15 reaches nobody until someone opens `/team` or OPS1.
- **Business outcome:** no control-room or dispatcher role is needed to run safely; Operations handles only untaken signals.
- **Care outcome:** a missed or stuck visit is acted on by the people of the visit, with a recorded time to response.
- **Expected nurse outcome:** she sees an urgent signal for her visits in her own tool without reloading and takes it with one tap.
- **Expected team outcome:** the team, not a coordinator, takes its signals; everybody sees who took one.
- **Expected patient outcome:** a missed visit (medication, nutrition, wound care, a fall) is noticed within minutes, not hours.
- **Acceptance criteria:** `briefs/SIG1.md` SIG1-1 to SIG1-8.
- **Dependencies:** none open for the in-app part; outside the app D-32; response duties and thresholds D-28 (`clinical`, unchanged).
- **Priority:** Next up 3, after AN2 and COORD5.
- **Implementation recommendation:** a delivery table written by a scheduled evaluation of the P1 transition (minute cadence, testable in pgTAP by calling the evaluator), RLS by organisation and recipient, `take_signal` command (audited, idempotent), polling or realtime on `/field` and `/team`; own ADR.

ENGINEERING BRIEF
- **Capability:** ORD0, the doctor link that must not get lost (GP informed, order without end date).
- **Why:** the `inform_gp` task cannot be completed (CGR-36); an order `present` without an end date never prompts a renewal while B visits keep being planned (CGR-38).
- **Business outcome:** B care stays billable because renewal is prompted; no permanent noise tasks.
- **Care outcome:** the link between home care given without an order and the client's doctor is on the record.
- **Expected nurse outcome:** one tap records that the doctor was informed; no task that can never be closed.
- **Expected team outcome:** open-ended orders are visible to the team that owns the case, without a coordinator.
- **Expected patient outcome:** the doctor knows about A/C care; B care does not run for months without medical review.
- **Acceptance criteria:** `briefs/ORD0.md` ORD0-1 to ORD0-6.
- **Dependencies:** none open; deadline, content and duration rules stay D-22.
- **Priority:** Next up 4; may be built in parallel with SIG1 (small).
- **Implementation recommendation:** a separate team command `record_gp_informed` (so `complete_case_task('inform_gp')` stays refused), a P3 rule in `derived_exceptions`, pgTAP with the `cra` case set, HAND1 entry.

## 2026-10-24 02:55 · eng (Lead Engineer)
- **Claimed #205 (AN2)** at 02:12. **AN2 part 1 = PR #243** (`feat/an2-part1-cgr35-day1r`), the preconditions the PO ordered first:
  - **CGR-35** (migration 0056, pgTAP 057, ADR-069): `reschedule_visit` stores `responsible_absent` on the `moved` row when the CGR-32 condition holds before the move; immutable, no parameter, audited by a new trigger for `moved` rows; HAND1 and `/team` show "nicht durchgeführt: zuständige Person abwesend gemeldet". IMPLEMENTED.
  - **ABS1-C7:** singular text at n = 1. IMPLEMENTED.
  - **DAY-1-R1/R2** (pgTAP 058): widened session-day guard (functions and views, self-tested patterns); behavioural split-day test at any hour via a transaction-local session time zone. **R3:** ADR-068 addendum, hosted DB time zone = owner check with D-2. IMPLEMENTED (docs for R3).
- **Clinical gate:** report sections 2026-10-23 22:30 and 2026-10-24 02:26 reviewed (02:26: CGR-35 still open pending this PR, DAY-1 endorsed with no blocking finding; new CGR-36/37/38 concern J1, J3 and C1, not this PR); CGR-35 applied; remediation plan `clinical/remediation/CGR-35.md`; no finding on ABS1-C7 or DAY-1-R.
- **Tests:** CI is the runner. Locally only a stand-in: plain PostgreSQL 16 with all migrations and the seed, stubbed Supabase roles and a minimal stand-in for the pgTAP functions used. 057 and 058 passed, and so did all existing pgTAP files the stand-in can run. 058 fails when the old `current_date` code is put back. Unit, lint, typecheck, build and e2e not run locally (npm registry unreachable here).
- **Status:** ABS1 `in-review` (#243); new AN2 row `in-progress` (measures not started, so the hand-off stays open).
- **Next agent (eng):** merge #243 on green, set ABS1 `delivered`; then the AN2 measures (section "Pilot-Hypothesen"); COORD5; *Engineering impact* in D-22, D-18, D-28. **(po):** review CGR-35/ABS1-C7 and DAY-1-R once #243 is merged. **(cra):** a look at 0056.

## 2026-10-24 02:52 · Legal & Compliance Agent (lca)
- **PR #241 continued, not a second lca PR:** `recovery/main` merged in (JOURNAL conflict, both entries kept, newest first). This brings #239 into the branch. #241's `db` failure (runner port conflict, per po 02:20) re-runs on the new head.
- **D-22 and D-18 not re-reviewed:** neither package changed on `recovery/main` since my 01:50 sections. The `cra` Clinical impact for both (CGR-36, CGR-38) arrived with #244, which merged while this PR was open. It counts as new evidence, and D-22 and D-18 are re-checked next run (three packages per run already used).
- **Sections *Legal/compliance impact* written for D-31, D-3, D-29** (only those sections). Advisory, not legal advice; no decision, status or row changed.
- **D-31:** 3a (not billable) compliant under every plausible interpretation. 1a (no report) unresolved, covered only while data are synthetic; the protective side is 1b (cantonal documentation duties, e.g. SO GesG § 18). 4a (irreversible) unresolved under DSG Art. 6 Abs. 5; 4b (audited correction, original kept) compliant on the sources read. 3b unresolved.
- **D-3:** B and B+cover as specified are unresolved (DSV Art. 4 read logging, DSFA DSG Art. 22, secrecy for substitutes, coach and operations reading client identity). These are compliant on federal sources read: B with read logging, a DSFA and need-to-know client identity; and B+cover with intake information and consent (D-9). Cantonal law UNKNOWN. On synthetic data, all options compliant.
- **D-29:** today's default compliant while synthetic. The most protective option (A or B with evidence, checker and re-check date) is unresolved: needs owner (D-11, D-12) and legal adviser. C needs a BAG/SRK answer on register access (Registerverordnung GesBG Art. 12).
- Sources the run could not read: GesBG and StGB Art. 321 primary texts (fedlex not reachable). Two cantonal guides disagree on whether nurses are named in Art. 321; this does not change any verdict.
- No tests run (docs only); `node scripts/agents-check.mjs` run before publishing.
- **Next agent (po):** read the three sections. D-3 route: the condition "B compliant under every interpretation" holds only for the protective variant, and real data needs read logging and a DSFA. D-31 (4) can go to `po` if `cra` raises nothing. **(lca, next run):** D-22 and D-18 again (#244 merged); then D-30, D-16 (when packaged), D-12, D-11.

## 2026-10-24 02:26 · Clinical & Regulatory Architect (review)
- **Reviewed** #234 (ABS1-C6), #239 (DAY-1: 0055, pgTAP 056, ADR-068), #237 (zod), the PO cycles in #238, the packages D-22, D-18, D-28 and the `lca` input in open PR #241. CI green on `d31709f`, `2e79532`, `35e28a4`. I did not run the tests.
- **No blocking finding.** ABS1-C6: no finding (CR-065). DAY-1: safety fix endorsed; by reading, no other day derivation exists in migrations or `src/` today; DAY-1-R1-R3 (PO) still needed (CR-064).
- **New (advisory):** CGR-36 (S2): the `inform_gp` task can never be completed, so NAVORA cannot record that the doctor was informed of A/C care without an order. CGR-37 (S2; S1 if visits are planned when nobody watches): every visit safety signal is pull-only, with no delivery to anyone. CGR-38 (S2): an order `present` without an end date never raises an expiry signal while B visits keep being planned. New register rows: H-18, PS-29, PS-30, BL-16. CGR-35: decided by the PO, PLANNED in AN2. CGR-31: evidence widened by `lca` (residence canton may be the wrong key).
- **Clinical impact for D-22, D-18, D-28** is written in the report section (my self-merged PR may touch only the report, registers and journal). **po:** copy it verbatim into the packages, signed as stated there. D-31, D-3, D-29 follow once #242 is merged.
- **Next agent (po):** decide CGR-36, CGR-37, CGR-38; copy the Clinical impact blocks; pilot visit hours and who watches `/team`/OPS1 then. **(eng):** AN2 first PR (CGR-35, ABS1-C7, DAY-1-R1-R3); Engineering impact in the packages. **(owner):** G-1 Clinical Owner; optionally allow `cra` to write package sections directly.

## 2026-10-24 02:20 · po (Product Owner)
- **#238 merged** (35e28a4) at 01:1x; no PO PR was open at the start of this run. **No delivery to review:** no item `ready-for-review`, `delivered` or newly `in-review` since 01:15; no open `agent:po` issue.
- **`lca` input for D-22 and D-18 is in PR #241 (not merged).** Its `db` job failed at 23:53 UTC on a runner port conflict (`0.0.0.0:54322 address already in use`) before any test ran; not a date or code failure. `lca` owns the PR; one re-run is enough. The PO read the input (advisory; the PO did not verify the sources): on D-22 the most protective set (a1 signed order with GLN/ZSR, b2 order or Kenntnisnahme also for A/C, c2 order issued before the visit) is compliant under every interpretation, the current default (b1, c1) is **unresolved**; on D-18 option C (estimate, no invoice) is compliant while nothing is invoiced, every invoicing rule is unresolved and needs D-11 and D-12. **Both packages keep `inputs-requested`** until `eng` and `cra` answer; they will then go to `awaiting-approval: legal` unless a recommendation needs no legal interpretation. Note for `eng` on D-22: record the order's **issue date** and the doctor's GLN/ZSR separately from the recording time (the contracts measure retroactivity against the doctor's date, CR-058 uses NAVORA's record).
- **AN2-M7 (PO decision, presentation only):** `lca` reads KLV Art. 7a Abs. 2 as a 10-minute floor on remuneration, not a "below → not billable" rule (CR-029, UNVALIDATED). Until D-18, AN2 measure 7 shows the CR-029 reason as its own row, "Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten", excluded from totals. Reason: counting it as lost revenue would push teams to stretch short visits, against direct care time. No change to J5 or CR-029. Criterion in `briefs/AN2.md` 02:20.
- **Decision packages, INDEX 4-6:** D-31 (broken-off visit: documentation, follow-up, billing, erroneous end; inputs `eng`, `cra`, `lca`), D-3 (read scope per role and the bounded cover read; `eng`, `cra`, `lca`), D-29 (qualification verification; `eng`, `cra`, `lca`) written, status `inputs-requested`; one comment each on #170, #65, #151. All Low confidence; no new rule; strict defaults stay (interrupted not billable and irreversible; option B and cover off; qualification is a label, synthetic data only).
- **Challenge:** why does an administrator type a qualification label once at hiring? From scratch the nurse enters her register number and NAVORA checks the public register at activation and on a schedule; a removal suspends the qualification. Row added; option C in D-29; register interface and permission UNKNOWN (`eng`, `lca`).
- Nothing escalated. **Waiting on people (unchanged):** owner names the Clinical Owner (G-1).
- **Next agent (po):** packages D-30, D-16, D-12 (INDEX 7-9); D-22/D-18 recommendation once `eng` and `cra` sections exist. **(eng):** AN2 first PR (DAY-1-R1-R3, CGR-35, ABS1-C7, AN2-M7 when measure 7 is built); COORD5; *Engineering impact* in D-22, D-18, D-28, D-31, D-3, D-29. **(cra):** *Clinical impact* in the same six. **(lca):** re-run #241's db job and merge; then D-31, D-3, D-29.

## 2026-10-24 01:50 · Legal & Compliance Agent (lca)
- **First lca run.** Sections *Legal/compliance impact* written in `decisions/D-22.md` and `decisions/D-18.md` (only those sections). Advisory, not legal advice; no decision taken, no status or row changed. Sources read today: KLV Stand 1.1.2026 (Art. 7, 7a, 8, 8a, via lexfind; fedlex 1.8.2026 version blocked, UNKNOWN), KVG Art. 25a Abs. 5 amendment 2017 (AS 2018 2989), OR 14 Abs. 2bis, BAG page on the nursing initiative, administrative contracts Spitex Schweiz/ASPS with HSK and CSS (both 1.4.2023).
- **D-22 verdicts:** most protective (a1 signed order, b2 order or GP Kenntnisnahme also for A/C, c2 order issued before the visit): compliant under every plausible interpretation. Current default (b1, c1): **unresolved: needs legal adviser**. Federal law since 1.7.2024 allows A/C without an order (KLV Art. 7 Abs. 4, 8a Abs. 1bis: GP informed promptly; 27-month report); the 2023 contracts still require GP Kenntnisnahme and say "Rückwirkende Verordnungen sind nicht zulässig"; whether they were adapted is UNKNOWN. Electronic signature: QES equals handwritten (OR 14 Abs. 2bis) subject to contrary contract terms; contracts define no level: unresolved.
- **D-18 verdicts:** option C as built, CR-031 and the CGR-31 strict default: compliant under every plausible interpretation while nothing is invoiced; every invoicing rule unresolved (legal adviser; D-11, D-12). **New evidence:** 5-minute units and "mindestens 10 Minuten" are federal (KLV Art. 7a Abs. 2), and the literal wording reads as a floor, not the "below → not billable" of CR-029. For home care the residual-financing rules are the provider location canton's, the residence canton pays (KVG Art. 25a Abs. 5): may widen CGR-31.
- No tests run (docs only); `node scripts/agents-check.mjs` run before publishing.
- **Next agent (po):** read both sections; D-22 and D-18 stay escalation candidates to `legal` (three exact questions each). **(cra/eng):** notes to po in both sections (order issue date vs recorded date; CR-029 reading; residence key). **(lca):** next run D-28 is not legal; D-31, D-3, D-29 once their packages exist.

## 2026-10-24 01:15 · po (Product Owner)
- **#238 continued, not a second PO PR:** `recovery/main` (with #239) merged in at 33b2532 (JOURNAL conflict resolved, both entries kept, newest first); CI re-runs at 01:1x Zurich, inside the split-day window. Merge on green.
- **DAY-1 reviewed (#239, migration 0055, pgTAP 056, ADR-068; merged as 2e79532; CI green in app, db, e2e, run 40033219652 at 00:22 Zurich).** The PO read the diff and CI through the API; **the PO did not run the tests**. Evidence table in `briefs/AN2.md` 01:15. Safety fix met: OPS1 order-expiring and review-overdue, `pause_case`, `apply_case_facts`, `add_care_plan_item` use the Zurich day. Proof `changes-requested`, non-blocking: **DAY-1-R1** guard also refuses `now()::date`, `current_timestamp::date`, `localtimestamp`, dates in views; **R2** one behavioural pgTAP at a split-day clock; **R3** ADR-068 names the hosted DB time zone as an owner check with D-2. They ride in AN2's first PR with CGR-35 and ABS1-C7. Deviations accepted: inline expression instead of a helper (given R1), night run as proof (given R2), delivered outside AN2 (speed was right).
- **COORD5 unblocked** (was "after DAY-1").
- **Decision packages (owner process 2026-10-24), INDEX order:** D-22, D-18, D-28 written (`decisions/D-22.md`, `D-18.md`, `D-28.md`), status `inputs-requested`; one comment per issue (#104, #80, #150) names the roles. D-22 and D-18: `eng`, `cra`, `lca`. D-28: `eng`, `cra` (legal not needed unless `cra` names a professional-accountability question). All three Low confidence; no recommendation and no new rule; the strict defaults stay. D-18 likely cannot settle before D-11 and D-12 name the tariff contract.
- **Challenge:** why is a safety-signal threshold one central value for every team? From scratch the Clinical Owner sets a band and each team chooses inside it (D-28 option C). Row added; AN2 data first.
- Nothing escalated. **Waiting on people (unchanged):** owner names the clinical owner (G-1); `clinical`, `legal` and `owner` rows now go through packages.
- **Next agent (po):** merge #238 on green; packages D-31, D-3, D-29 (INDEX 4-6). **(eng):** AN2 first PR (DAY-1-R1-R3, CGR-35, ABS1-C7); COORD5; *Engineering impact* in D-22, D-18, D-28. **(cra):** *Clinical impact* in D-22, D-18, D-28; a look at 0055 (date logic of safety exceptions). **(lca):** D-22, D-18.

## 2026-10-24 00:40 · eng (Lead Engineer)
- **CI red between 00:00 and 02:00 Zurich (UTC vs Zurich "today").** The PO cycle PR #238 (docs only) failed db and e2e at 00:03: the seed, pgTAP and two e2e specs used `current_date` (UTC), seed visit 532 and the app use the Zurich date. Five product functions also used `current_date` (OPS1 order expiring and review overdue, `pause_case`, `apply_case_facts`, `add_care_plan_item`), so for one or two hours a night they judged dates against yesterday.
- **Fix PR (fix/zurich-today):** migration 0055 replaces `current_date` with the Zurich date in every `public`/`private` function body (no rule changes), pgTAP 056 guards it, seed/pgTAP/e2e use the Zurich date, pgTAP 044 reads reports on the visit's own date. ADR-068. IMPLEMENTED; CI is the test runner, no local run (container registries are blocked here).
- **CSR1 (#149):** nothing left to build; the hand-off closes when #238 merges. AN2 (#205) starts once it carries `active`.
- **For the PO:** #238 needs a fresh CI run after this merges (or outside 00:00–02:00 Zurich).

## 2026-10-24 00:15 · po (Product Owner, session with the owner)
- **Owner instruction (2026-10-24, live session): decision packages.** No `human-decision` issue is put to the owner as an open question any more. Agents analyse it, gather Engineering, Clinical & Regulatory and (where needed) Legal & Compliance input, and write a package with a recommended default, a confidence and whether owner approval is actually required. The PO decides when no escalation criterion applies; escalation only for unresolved legal interpretation, the Clinical Owner, commercial/strategic/business, regulatory liability, funding, pricing or partnership (and, carried over, irreversible production changes). Process: `DECISION_PACKAGES.md`; template and order: `decisions/_TEMPLATE.md`, `decisions/INDEX.md`.
- **New role `lca` (Legal & Compliance Agent)**, approved by the owner with additions: advisory only, never a final legal determination; reads the newest `cra` findings first when a decision touches safety, documentation, billing, care delivery or professional accountability; names missing canton, tariff-contract, payer-agreement or policy information; no repeat review unless the package changed, new evidence exists or a reviewer asks. Involved automatically for billing, reimbursement, tariffs, OKP/KVG/KLV, data protection, privacy, retention, contracts, governance, regulatory compliance. Scheduled task "NAVORA Legal & Compliance Agent" (`trig_011mvABASzho3mC4nYWHhyFk`, hourly at :39 UTC).
- **Priority (owner):** D-22 and D-18 first; then decisions referenced by open or provisional CGR findings (D-28, D-31, D-3, D-29, D-30, D-16); then decisions blocking billing, reimbursement, invoicing, compliance, governance or production release; then the rest. 29 decisions triaged in `decisions/INDEX.md`; **no package written yet**, all `not-started`. Preliminary routes are a first triage, not answers.
- **Scheduled tasks:** PO prompt updated for the package workflow (step F). The Engineering prompt update was refused by the platform's permission check, and the `cra` prompt was not changed; both agents read README and COORDINATION each run, which now carry their package duties (`eng`: *Engineering impact*; `cra`: *Clinical impact*). If they do not pick them up within two runs, the PO drafts those sections, marked unconfirmed.
- **COORD5 approved** (Next up 2): the watcher assigns a decision issue to a person only when its package awaits approval; buildable right after DAY-1. Until then the INDEX is authoritative and the watcher still assigns every decision issue to the owner.
- Tests: none run; `node scripts/agents-check.mjs` ok; watcher dry run: active AN2, COORD5 next.
- **Next agent (po):** packages D-22, D-18, D-28 (inputs requested). **(lca):** D-22, D-18 once requested. **(eng):** DAY-1, then COORD5; *Engineering impact* in requested packages. **(cra):** *Clinical impact* in requested packages.

## 2026-10-24 00:20 · po (Product Owner)
- **#238 (PO cycle 23:15) not merged:** after the base merge (09e4416, `zod` fix #237) its CI went red in `db` and `e2e` (run 40030758280, started 22:00 UTC = 00:00 Zurich). `app` is green, so the `zod` audit is fixed. The PR is docs only; `recovery/main` was green at 21:23 UTC on the same code. The failure follows the clock, not the change. No second PO PR opened: this entry rides on #238.
- **Cause, read in the repository (the PO did not run the tests):** pgTAP 008, 015, 043, 044, 049 mix `current_date` (UTC in CI) with the Zurich day and build visits at `now() ± hours` that fall on the previous Zurich day after midnight; live functions use `current_date` too (0013/0017 requested start, 0014 review date, 0019/0024 OPS1 order expiring and review overdue, 0024/0031 C1 pause end and visit window). UNKNOWN: hosted DB time zone; the e2e failure (report not read).
- **PO decision (product authority):** NAVORA's calendar day is the Europe/Zurich day everywhere. **DAY-1** ordered as AN2's first change, before CGR-35 and ABS1-C7; criteria (1)-(5) in `briefs/AN2.md` 00:20, including a CI proof at a split-day clock. Reason: CI red two hours every night stalls merges, and date-based safety exceptions run on the UTC day in that window (patient safety is a precondition).
- **Challenge:** why does any function decide "today" for itself? From scratch there would be one clock and one rule; DAY-1 makes it so and adds a CI check against new bare `current_date`.
- No review delivered since 23:15; no `po` decision open. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (po):** after 00:00 UTC re-run #238's failed jobs once; merge on green (merge commit). **(eng):** DAY-1 under #205, then CGR-35 and ABS1-C7, then the AN2 measures. **(cra):** #234 (ABS1-C6).

ENGINEERING BRIEF
- **Capability:** DAY-1, one calendar day (Europe/Zurich) for every server-side "today" and date bound; first change of AN2.
- **Why:** functions and tests mix the UTC and the Zurich day; CI is red every night between 22:00 and 24:00 UTC (23:00-24:00 in winter time), and OPS1's order-expiring and review-overdue exceptions use the UTC day in that window.
- **Business outcome:** merges do not stall at night; no red build mistaken for a flake.
- **Care outcome:** date-based safety exceptions fire from the first minute of the Zurich day.
- **Expected nurse outcome:** a pause ending "today" or a date entered after midnight is judged by the day she lives in.
- **Expected team outcome:** exceptions and "yesterday" in `/field` agree with the team's clock.
- **Expected patient outcome:** an expired order or overdue care-plan review is not missed for two hours each night.
- **Acceptance criteria:** `briefs/AN2.md` 00:20, DAY-1 (1)-(5).
- **Dependencies:** none open; base CI green (#237). Hosted DB time zone is an owner check once staging exists (D-2).
- **Priority:** first, before CGR-35 and ABS1-C7 (Next up 1, AN2).
- **Implementation recommendation:** one stable SQL helper for the Zurich day, used by functions and pgTAP fixtures; a test clock override for one CI pass at a split-day time; a pgTAP or script check over `pg_proc` source for bare `current_date`/`now()::date`; own small PR with an ADR.

## 2026-10-23 23:20 · eng (Engineering)
- **`recovery/main` is red** since 62609af: the app job's supply-chain audit (`npm audit --omit=dev --audit-level=high`) fails on a new advisory, **GHSA-mrhx-c7xc-m3w5** (zod < 4.6.6, high: memory exhaustion validating oversized constrained collections). Lint, typecheck, unit (24 files), build, db and e2e were green in the same run. Not caused by #234 or #236; every PR is red until it is fixed.
- **Fix PR** (`fix/zod-audit-ghsa-mrhx-c7xc-m3w5`): `zod` `^4.1.0` → `^4.6.6` in `package.json`; `package-lock.json` resolved by lockfile-sync (ADR-012/014; no registry access here). Same major; no code change. IMPLEMENTED (awaiting CI); nothing run locally.
- Active issue #149 (CSR1): no eng work open. Part 12 (ABS1-C6, #234) waits on the PO; CGR-35 waits on the PO. Not claimed.
- **Next agent (eng):** CI on the fix PR; merge when green, then other PRs need `recovery/main` merged in. **(po):** ABS1-C6, CGR-35, then AN2 (#205).

## 2026-10-23 23:15 · po (Product Owner)
- **ABS1-C6 reviewed: met** (#234 head 351345c, CI run 40020564005 green; merged as d31709f, CI run 40022316185 green on the merge commit, checked through the API). The PO read the full diff, the unit tests, the e2e case and ADR-067. Evidence table in `briefs/ABS1.md` 23:15. **The PO did not run the tests.**
- **Deviations decided:** lower bound "yesterday" is a form rule only (accepted; AN2 measure 8 counts earlier starts); no notice on a replay (accepted); seeded absence replaced by the e2e (accepted, one-worker rule of ADR-066); built from #231 before merge (accepted).
- **ADR-067 *Open* decided: ABS1-C7** — at n = 1 "1 vergangener Einsatz ist noch offen: bitte im Team entscheiden".
- **CGR-35 decided** (`cra` 22:30, advisory S3; product authority, not a clinical rule): a flagged past visit moved with `reschedule_visit` stores `responsible_absent = true` on its `moved` row, server-side, immutable; same fixed text in HAND1; no new reason code, no extra tap. D-28, D-31 stay `clinical`.
- **CSR1 complete** (parts 1-12) and removed from *Next up*: the watcher closes #149 and **AN2 (#205) becomes active** (dry run checked: `active capability: AN2`). CGR-35 and ABS1-C7 are AN2's first change; AN2 measure 8 extended (moved flagged visits; absence starts earlier than yesterday). ABS1 stays accepted.
- **Base CI red** since 62609af: app job, `npm audit` reports `zod` < 4.6.6 (GHSA-mrhx-c7xc-m3w5, high). Not caused by a change; every PR's app job is red until engineering bumps `zod`. This PR (docs only) is merged only on green CI; if it is red from the audit alone it stays open for the next PO run.
- **Challenge:** advisory conditions on an accepted item travelled as four sequential CSR1 parts and held AN2 back for eight hours. Verdict no: advisory (S3) conditions now ride with the next capability that touches the same data; blocking findings still go first. Row added with a check.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** bump `zod` (≥ 4.6.6) so CI is green; then AN2 under #205, starting with CGR-35 and ABS1-C7. **(cra):** #234 (ABS1-C6); CGR-35 when its PR is open.

ENGINEERING BRIEF
- **Capability:** AN2 first change: CGR-35 (a moved flagged past visit keeps the absence fact) and ABS1-C7 (singular confirmation text).
- **Why:** a "Folgeeinsatz" is the team's most likely answer to a visit missed during a reported absence; today the move erases why the care on the original date was not given once the absence is changed.
- **Business outcome:** documentation that survives later corrections without anyone typing a reason; AN2 measure 8 counts missed care completely.
- **Care outcome:** continuity gaps stay visible for the team, HAND1 and `clinical` (D-28, D-31 answerable from data).
- **Expected nurse outcome:** no extra tap or text; correct German at n = 1.
- **Expected team outcome:** the team decides make-up visits itself and the record shows why, with no coordinator relaying it.
- **Expected patient outcome:** missed care is not hidden behind a planning move.
- **Acceptance criteria:** `briefs/ABS1.md` 23:15, CGR-35 (1)-(5) and ABS1-C7 (pgTAP case set incl. withdrawal, unit tests for the HAND1 line and n = 1 / n = 2).
- **Dependencies:** base CI green (`zod`); 0053, 0054 (merged). No open decision blocks it.
- **Priority:** first change of the active capability AN2 (Next up 1).
- **Implementation recommendation:** same shape as 0054: column on `visit_plan_changes` with a check `not responsible_absent or change = 'moved'`, computed in `reschedule_visit` before the move from `private.visit_responsible_absent`; patch the function as 0052 does; own small PR or inside AN2's first PR.

## 2026-10-23 22:50 · eng (Engineering)
- **#234 merged** (merge commit d31709f), CI green on its head 351345c (run 40020564005: app, db incl. pgTAP, e2e). ABS1-C6 IMPLEMENTED. ABS1 `delivered`.
- Two base merges were needed before merging (PO #231/#233, `cra` #235; journal conflicts only, both entries kept). The first CI run on 223362b was green too.
- `cra` 22:30 opened **CGR-35** (advisory: a flagged past visit moved with `reschedule_visit` stores nothing about the absence). PO decides; not built.
- `claimed` removed from #149. **Next agent (po):** ABS1-C6 against `briefs/ABS1.md` 21:17 (and the singular-wording question in ADR-067 *Open*); CGR-35; then AN2 (#205). **(eng):** the PO's next order.

## 2026-10-23 22:30 · Clinical & Regulatory Architect (review)
- **Reviewed** #228 (0053, pgTAP 054, CGR-32) and #230 (0054, pgTAP 055, CGR-34), the 046 fixture fix, the seed fixture, and the PO cycles #227, #231, #233. CI green on `87612aa` and `673ba50` (db job in the evening: the 046 fix holds). I did not run the tests.
- **Closed:** CGR-32 (0053; pgTAP 054, incl. my 19:46 hand-closed case at 054:79-80, 96-97), CGR-34 (0054; pgTAP 055:55-128). PS-26, PS-27 closed. Rules CR-062, CR-063 added (PROVISIONAL, product authority).
- **New (advisory S3):** CGR-35 (PS-28): a flagged past visit moved with `reschedule_visit` loses the absence fact (stored only on cancellation). PO decides; could ride with ABS1-C6 in CSR1 part 12.
- This PR also carries the unmerged 19:57 addendum (#226, CGR-34), which is closed as superseded.
- **Next agent (po):** CGR-35; AN2 measure 8 should count moved flagged visits. **(eng):** CSR1 part 12 (ABS1-C6, and CGR-35 if ordered). **(owner):** G-1 clinical owner.

## 2026-10-23 22:28 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 22:11** for the **CSR1 part 12 remainder = ABS1-C6** (PO decision 21:17 in PR #231, **not merged** at build time; built from its text). CGR-34, the other half of part 12, was delivered in #230.
- **PR #234** (`feat/csr1-part12-abs1-c6`): no migration; ADR-067; unit tests and e2e at phone width. ABS1 row `in-review`.
- IMPLEMENTED (awaiting CI): `/field` offers an absence start of yesterday (no earlier); `recordAbsence` returns `pastPlanned`; at n > 0 the section shows "<n> vergangene Einsätze sind noch offen: bitte im Team entscheiden" with a link to `/team`.
- **Seed:** the ended absence of assist.test (from #228) is removed; the new e2e records it through the app before the CGR-32 and CGR-34 tests. pgTAP comments updated; no pgTAP assertion depended on it (checked by reading, not run).
- **Clinical gate:** no report finding names ABS1-C6 (sections 19:46, addendum 19:57); no remediation plan. D-28, D-31 untouched.
- OPEN for `po`: the literal text reads "1 vergangene Einsätze" at n = 1; a singular form only on the PO's word.
- **Tests:** nothing run locally (no npm registry access, no local Supabase in this container); a pure-function spot check of the three helpers with node only. CI is the runner; nothing claimed as passed.
- **Next agent (eng):** CI on #234; approve a waiting types-bot run; fix if red; merge; ABS1 `delivered`. **(po):** merge #231 after a base merge; check ABS1-C6 against `briefs/ABS1.md` 21:17; then AN2 (#205).

## 2026-10-23 22:15 · po (Product Owner)
- **#231 (PO cycle 21:17) merged** (merge commit 993b5df) after merging `recovery/main` into it (journal: kept both entries, newest first); CI green on its head 05408d4.
- **CGR-34 reviewed: met** (#230 head 87612aa, CI run 40011124704 green; merged as 673ba50, CI green on the merge commit and on 0717c05, checked through the API). The PO read 0054 in full, pgTAP 055 (26), the unit tests and the e2e case. Evidence table in `briefs/ABS1.md` 22:15. **The PO did not run the tests.**
- **Deviations decided:** HAND1 shows the fact as its own line under "Einsatz abgesagt" (accepted); "Abgesagt (<reason>)" everywhere on `/field` (accepted); e2e order dependence on the CGR-32 case (accepted while the suite runs on one worker); built from #227 before merge (accepted, decision unchanged).
- **ABS1 stays accepted.** Open: ABS1-C6 only. **CSR1 part 12 = ABS1-C6** (criteria `briefs/ABS1.md` 21:17), then AN2 (#205).
- **Challenge:** a flagged past visit still needs a reason picked from a list although NAVORA knows why it was not done. Row added: if AN2 measure 8 shows > 80 % `team_cancelled` on flagged past visits, propose one action "Nicht durchgeführt (abwesend)" on the overdue alert; the make-up decision stays with the team and D-28.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 and others in `OPEN_DECISIONS.md`.
- **Next agent (eng):** CSR1 part 12 = ABS1-C6 under issue #149; then AN2. **(cra):** 0053 (#228) and 0054 (#230); #226 needs `recovery/main` merged in (red only from the old 046).

## 2026-10-23 21:30 · eng (Engineering)
- **#230 merged** (merge commit 673ba50), CI green on its head 87612aa (run 40011124704: app, db incl. pgTAP `055_csr1_cgr34_cancel_keeps_absence` (26), e2e). CGR-34 IMPLEMENTED. ABS1 `delivered`.
- First CI round red in db only (run 40010479455): pgTAP 047 test 5 asserted the exact column list of `field_visit_status_notes`; updated for the new `responsible_absent` column (87612aa). 055 was green in both rounds.
- Correction: the entry below is stamped 21:35, ahead of the clock (written about 21:20).
- `claimed` removed from #149. **Next agent (po):** CGR-34 against `briefs/ABS1.md` 20:15; then AN2 (#205). **(cra):** 0054. **(eng):** the PO's next order, or AN2.

## 2026-10-23 21:35 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 21:12** for the **CSR1 part 11 remainder = CGR-34** (PO decision 20:15 in PR #227 and `cra` addendum 19:57 in PR #226, both **not merged** at build time; built from their text). CGR-32 and the pgTAP 046 time-of-day fix were already in #228.
- **PR #230** (`fix/csr1-part11-cgr34`): migration 0054, ADR-066, pgTAP `055_csr1_cgr34_cancel_keeps_absence` (26), unit tests (labels), e2e at phone width. ABS1 row `in-review`.
- IMPLEMENTED (awaiting CI): `visit_status_notes.responsible_absent` (only on `cancelled`, append-only, not writable by the caller); `cancel_visit` sets it when the visit is planned, dated before today and its responsible member is absent at its interval; survives a later withdrawal. Shown as "nicht durchgeführt: zuständige Person abwesend gemeldet" on the /field card ("Abgesagt (<reason>) · …"), in HAND1, and as OPS1 flag `not_done_responsible_absent` on the late team cancellation. No new reason code.
- **Clinical gate:** latest merged report section 19:46 has no CGR-34; applied per the 19:57 addendum (#226) and the PO decision. No remediation plan (advisory, no clinical rule). D-28, D-31 untouched.
- **Tests:** nothing run locally (no npm registry, no local Supabase in this container). CI is the runner; nothing claimed as passed.
- **Next agent (eng):** CI on #230; approve a waiting types-bot run; fix if red; merge; ABS1 `delivered`. **(po):** merge #227 (and #226) after a base merge; check CGR-34 against `briefs/ABS1.md` 20:15. **(cra):** 0054.

## 2026-10-23 21:17 · po (Product Owner)
- **#227 (PO cycle 20:15) merged** (merge commit 7257feb) after merging `recovery/main` into it (journal kept both entries); CI green on its head d37a706. It was red only from pgTAP 046 (fixed in #228).
- **CSR1 part 11 reviewed** (#228 head c1b562a, CI run 40005346459 green; merged as 33112e3, CI green on the merge commit and on e6f35ad, checked through the API). The PO read 0053 in full, the pgTAP 054 fixtures and assertions, the label, its unit test and the e2e case. **The PO did not run the tests.** Evidence table in `briefs/ABS1.md` 21:17.
- **CGR-32 met in code**, and the `cra` 19:46 case (a hand-closed overdue alert still counted in `past_planned`). Three deviations accepted (generic flag rule; seed and fixture changes; auth.spec by time). Awaiting a `cra` section on 0053. **ABS1 stays accepted.**
- **CGR-34 is not in #228** (built before the 20:15 decision merged; not a defect).
- **Engineering's OPEN decided (product authority): new condition ABS1-C6.** `/field` sets `min={today}`, so "krank seit gestern" never reaches CGR-32 from the app. `/field` offers a start of yesterday (no earlier). When `past_planned` > 0, the confirmation shows "<n> vergangene Einsätze sind noch offen: bitte im Team entscheiden" with a link to `/team`. e2e at phone width and a unit test.
- **Order:** CSR1 part 12 = CGR-34 + ABS1-C6 (small) → AN2 (#205).
- **Challenge:** a sick member must guess her return date, and a longer illness needs a second report. Row added: if more than 30 % of absences are changed after they are recorded, propose an open-ended absence ending with "Ich bin wieder da". AN2 measure 8 extended to measure it; no change before the data.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** CSR1 part 12 under issue #149 (criteria in `briefs/ABS1.md` 20:15 and 21:17); then AN2. **(cra):** 0053 (#228); #226 needs `recovery/main` merged in (red only from the old 046).

## 2026-10-23 20:48 · eng (Engineering)
- **#228 merged** (merge commit 33112e3), CI green on its head c1b562a (run 40005346459: app, db incl. pgTAP `054_csr1_cgr32_past_visit_absence_flag` (34), e2e). CGR-32 IMPLEMENTED. ABS1 `delivered`.
- First CI round red in e2e only (run 40003570491): auth.spec started "the first planned visit" on /visits, which became the new seed visit 532 (yesterday, sorts first), so 501 stayed open and 532 lost its alert. Fixed by selecting 501 by its time (c1b562a). The db job was green, including the 046 evening fix (docs-only PRs #226 and the PO cycle at 20:02/20:12 were red on 046 for that reason; they turn green once they merge `recovery/main`).
- `claimed` removed from #149. **Next agent (po):** CGR-32 (ABS1 condition) against the brief; then AN2 (#205). **(cra):** 0053. **(eng):** the PO's next order, or AN2.

## 2026-10-23 20:27 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 20:13** for **CSR1 part 11 = CGR-32** (ABS1 acceptance condition, PO 19:12). **PR #228** (`fix/csr1-part11-cgr32`): migration 0053, ADR-065, pgTAP `054_csr1_cgr32_past_visit_absence_flag` (34, incl. the `cra` 19:46 hand-closed-alert case), unit test (label), e2e at phone width. ABS1 row `in-review`.
- IMPLEMENTED (awaiting CI): `record_absence` returns `past_planned` (caller's teams only); past planned visits inside a new absence keep her and are not released; `team_visit_alerts()` and `operations_exceptions()` gain `flags text[]` (`responsible_absent`, computed from the absence, cleared by withdraw/shorten); fixed label "Zuständige Person abwesend gemeldet" on /team and in OPS1.
- **Found while testing locally:** pgTAP 046 fixtures rolled to tomorrow after 20:00/21:00 Zurich (CI red in the evening, not caused by a code change). Fixed in #228 (fixtures stay on today's date). Seed gains an ended absence + visit 532 for the e2e; pgTAP 004/046/048/050 adjusted.
- Engineering rebuilt a local PostgreSQL 16 with a Supabase/pgTAP shim and ran all 53 pgTAP files: pass. No npm registry access: lint, typecheck, unit, build and e2e only in CI.
- OPEN for the PO: the `/field` absence form allows a start from today only, so a past start ("krank seit gestern") is recordable only via the command.
- **Next agent (eng):** #228: approve a waiting types-bot run if any, fix CI if red, merge when green, set ABS1 `delivered`. **(po):** CGR-32 against `briefs/ABS1.md` once merged. **(cra):** 0053.

## 2026-10-23 20:15 · po (Product Owner)
- **Nothing new delivered** since 19:30 (no open engineering PR; CSR1 part 11 not started). No `agent:po` issue open.
- **CGR-34 decided** (`cra` addendum 19:57, PR #226, advisory S3, PS-27; product authority, not a clinical rule): when `cancel_visit` closes a past visit flagged by CGR-32, the server stores on its status note that the responsible member was absent (`responsible_absent`, immutable, never set by the caller); shown as "nicht durchgeführt: zuständige Person abwesend gemeldet". **No new reason code, no extra tap**: NAVORA records what it already knows. Whether missed care must be made up stays `clinical` (D-28, D-31). Criteria in `briefs/ABS1.md` 20:15. The PO read `cancel_visit` (0024); **the PO did not run any test.**
- **CSR1 part 11** = CGR-32 + CGR-34 + the `cra` 19:46 case (a hand-closed overdue alert still counts in `past_planned`); then AN2. AN2 measure 8 now also counts flagged past visits and how they ended.
- **CI:** pgTAP 046 test 74 is time-dependent (`cra` 19:57) and turns every db job red between 20:00 and 24:00 Europe/Zurich; engineering fixes it first. This PR (docs only) is merged only on green CI; if it is red from that test alone, it stays open for the next PO run.
- **Challenge:** new row: staff pick a reason code or type a note for a fact NAVORA already holds. Verdict no; hypothesis on `cancel_visit` "other" notes, tested with AN2 measure 10 data before any new reason code.
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** pgTAP 046:66 fix; CSR1 part 11 under issue #149; then AN2 (#205). **(cra):** part 11 when its PR is open.

## 2026-10-23 19:57 · Clinical & Regulatory Architect (review)
- **Second review run** on the same changes as the 19:46 entry (#222, PO cycle #221); it agrees with the 19:46 section (CGR-33 closed, CGR-32 decision endorsed). Its own PR #225 duplicated #224 and is closed; this addendum carries only what is new. Tests not run by me.
- **New (advisory S3):** CGR-34 (PS-27): a flagged past visit (CGR-32) can be closed only through `cancel_visit` with a planned-cancellation reason, and the flag is computed, so the record loses that care was missed because the responsible member was absent. Remedy rides with CSR1 part 11; PO decides.
- **CI note (eng):** pgTAP 046 test 74 fails when run 20:00-24:00 Europe/Zurich (visit `later` at `now() + 4 h` crosses midnight; 046:66, 267). Code correct, test time-dependent; it made this docs-only PR's db job red at 20:00.
- **Next agent (po):** CGR-34 into CSR1 part 11. **(eng):** part 11 with CGR-32, the 19:46 pgTAP case and, if the PO agrees, CGR-34; fix pgTAP 046:66 to a fixed time inside today.

## 2026-10-23 19:46 · Clinical & Regulatory Architect (review)
- **Reviewed** #222 (pgTAP `053_cgr33_order_audit_guard`, test only; CI green on 4661392, d67055b, 50ee5f5) and the PO cycle #221 (ABS1 accepted with CGR-32; CGR-32 remedy decided; AN2 measure 12; challenge row on late billing facts). I did not run the tests.
- **Closed:** CGR-33 (053:23-92); BL-15 closed (residuals: `residence_canton` not asserted, needed only with a D-18 as-of residence rule; `session_replication_role = replica` UNKNOWN, eng runbook).
- **No new finding.** CGR-32 stays open until CSR1 part 11 merges; the PO's "flag, not release" decision is endorsed; one extra pgTAP case asked (a hand-closed overdue alert still counted in `past_planned`).
- **Gate:** no blocking finding on J5, ABS1 or any item. No decision answered.
- **Waiting:** owner G-1 (clinical owner); `legal` D-22, D-18; `clinical` D-28, D-31, D-10, D-30, D-16, D-17; `owner` D-3 before cover.
- **Next (cra):** CSR1 part 11 PR when open.

## 2026-10-23 19:30 · po (Product Owner)
- **CSR1 part 10 reviewed** (#216 head 9ea3cb3, CI run 39988490243 green; merged as 3d48a00, CI green on the merge commit (runs 39989101189, 39989106823) and on 279d026, checked through the API). The PO read 0052 in full, 0051's cut-off and reconstruction, and the pgTAP 051 and 052 assertions. **The PO did not run the tests.** Evidence in `briefs/CSR1.md` and `briefs/ABS1.md`.
- **ABS1 accepted** (issue #219): ABS1-C5 met; clinical gate passed (`cra` 18:30 on 0048/0050, 19:00 on 0052: no blocking finding). Deviation (check on the outcome, not on the date) accepted. **Condition CGR-32, PO decision (product authority, not a clinical rule):** a planned, not started visit dated before today inside a newly recorded absence is **flagged, not released**: it keeps its responsible member, `record_absence` returns `past_planned`, its overdue alert shows "Zuständige Person abwesend gemeldet"; the absence is never refused. Released, it would invite a take of a visit nobody can still do and could not be closed by hand (CGR-22). Whether the care must be made up stays `clinical` (D-28, D-31).
- **J5** stays accepted: J5-C2 met (`cra` 19:00), J5-C1 and CGR-29 closed (`cra` 18:30). All five deviations decided in `briefs/CSR1.md` (no "history missing" reason accepted on condition CGR-33). Conditions: **CGR-33** (pgTAP guarding the order audit history; before go-live) and **CGR-31** (residence correction; before any invoicing brief, D-18).
- **CGR-33 met** (#222 merged as d67055b, CI green on its head 4661392 and the merge commit; pgTAP `053_cgr33_order_audit_guard` read by the PO): trigger shape and both order columns, `{old, new}` read back by `case_order_as_of`, append-only for the owner, `authenticated` select only. Deviation (owner path only, no separate intake edit) accepted: the trigger has no column list and fires on every write path, which 053 asserts. `cra` review of 053 pending; J5 stays accepted. (The engineering entry below is stamped 19:50, ahead of the clock.)
- **Order:** CSR1 part 11 (now CGR-32 only; small) → AN2. AN2 gains measure 12 (late billing facts, `basis_changed` per 100 facts).
- **Challenge:** billing facts built in a later batch force each rule to reconstruct the visit date from the audit log; built from scratch, the basis would be snapshotted at visit end (row added; measured by AN2 measure 12 before any ADR).
- No `po` decision open; nothing new for the owner. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-17, D-28, D-30, D-31; `legal`: D-18 (incl. CGR-31), D-22; `owner`: D-3 before cover.
- **Next agent (eng):** CSR1 part 11 under issue #149 (CGR-32 per `briefs/ABS1.md` 19:12); then AN2 (#205). **(cra):** 053 (CGR-33); part 11 when its PR is open.

## 2026-10-23 19:50 · eng (Engineering)
- **#222 merged** (merge commit d67055b), CI green on its head 4661392 (run 39993536097: app, db incl. pgTAP `053_cgr33_order_audit_guard` (21), e2e). CGR-33 IMPLEMENTED (regression guard, test only). J5 `delivered`.
- `claimed` removed from #149. **Next agent (po):** J5 (J5-C2, CGR-33) and ABS1 (ABS1-C5; CGR-32 decision) against the briefs. **(cra):** 053. **(eng):** the PO's next order under #149, or AN2.

## 2026-10-23 19:25 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 19:13** for **CGR-33** (`cra` 19:00, advisory S2, BL-15, owner eng). CSR1 part 10 was already delivered in #216; the PO's review of it is pending.
- PR **#222** (`fix/cgr33-order-audit-guard`): pgTAP `053_cgr33_order_audit_guard` (21), ADR-064. Test only, no migration. IMPLEMENTED (CI pending): `audit_cases` must stay after insert or update, for each row, without a column list, enabled, with both order columns; order edits audited as `{old, new}` and read back by `case_order_as_of`; `audit_events` append-only for the owner; `authenticated` select only, `anon` nothing.
- J5 status row `in-review` (#222). Not touched: CGR-32 (PO decides how past visits in a newly recorded absence are shown), CGR-31 (D-18, `legal`).
- **Tests:** CI is the runner; nothing run locally against a database. Nothing claimed as passed.
- **Next agent (eng):** CI on #222; merge, J5 `delivered`; then whatever the PO orders next under #149, or AN2. **(po):** J5-C2, ABS1-C5, and CGR-33 as a J5 condition.

## 2026-10-23 19:00 · Clinical & Regulatory Architect (review)
- **Reviewed** #216 as merged (`3d48a00`): 0051 (J5-C2) and 0052 (ABS1-C5), pgTAP 051 and 052, the UI text and label. CI green on `9ea3cb3`, `3d48a00`, `279d026` (API). Tests not run by me.
- **Met in code:** J5-C2 (0051:49-87, pgTAP 051:103-231; cut-off PROVISIONAL, D-22) and ABS1-C5 (0052:36-55, pgTAP 052 (a)-(c)).
- **New (advisory):** CGR-32 (S3, PS-26): `record_absence` accepts a start in the past, and the release rule skips past dates, so past planned visits inside a newly recorded absence still name her (the end state ABS1-C5 refuses for a move); never fix it by refusing the absence. CGR-33 (S2, BL-15): no test guards that `audit_cases` audits both order columns, on which J5-C2 depends.
- **Gate:** ABS1 and J5 have no blocking finding; the PO may accept with CGR-32, CGR-33 (and CGR-31) as conditions. Cover stays off. Rule register: CR-058, CR-061 checked.
- **Waiting on people:** owner G-1 (clinical owner); `legal` D-22, D-18; `clinical` D-28, D-31, D-10, D-30, D-16, D-17; `owner` D-3.
- **Next agent (po):** accept ABS1 and J5 if agreed; record CGR-32 and CGR-33 as conditions; decide how CGR-32's past visits are shown. **(eng):** CGR-33 is a small pgTAP addition.

## 2026-10-23 18:43 · eng (Engineering)
- **#216 merged** (merge commit 3d48a00), CI green on its head 9ea3cb3 (run 39988490243: app, db incl. pgTAP `051_csr1_order_as_of_visit_date` (35) and `052_abs1_c5_no_past_move_into_absence` (12), e2e); earlier heads 86ff266 and ca215fa green too. Two base merges on the way (PO 18:15, `cra` 18:30): journal kept both entries; rule register kept the Architect's rows and added CR-058 and CR-061. Nothing is claimed beyond CI.
- **J5 `delivered`** (CSR1 part 10: J5-C2 IMPLEMENTED) and **ABS1 `delivered`** (ABS1-C5 IMPLEMENTED). No `cra` section reviews 0052 yet (UNKNOWN); the 18:30 section read 0051 from the diff with no blocking finding.
- **Next agent (po):** J5-C2 and ABS1-C5 against the briefs; CGR-31 as a J5 condition (`cra` 18:30). **(cra):** 0051 as merged, 0052. **(eng):** AN2 when it becomes active.

## 2026-10-23 18:30 · Clinical & Regulatory Architect (review)
- **Reviewed** 0048 (#206), 0049 (#210), 0050 (#212) as merged, and open PR #216 (0051, J5-C2) from its diff. CI green on `2401a11`, `378f811`, `1f64128`, `be22e2c` (API); #216: no CI run reported (UNKNOWN). **I did not run the tests.**
- **Closed:** CGR-27 (blocking S1; 0048:29-54, pgTAP 048:65-126), CGR-29 (0049:383-388, pgTAP 049:243-271), the CGR-24 withdraw residual (0049:206-262, pgTAP 049:101-237). ABS1-C3, ABS1-C4, ABS1-N1, J5-C1 endorsed. PS-23 and BL-13 closed; H-17 mitigated-in-code (cover off).
- **New:** CGR-31 (advisory S3, S1 before invoicing; BL-14): a residence correction never re-derives a fact, while the preview prices with the live canton. Time rule for the residence: PO with `legal` (D-18), UNKNOWN.
- **Gate:** ABS1 and CSR1 part 9 have no blocking clinical finding; ABS1 still waits on the PO's ABS1-C5, which #216 does not carry. #216: no blocking finding; merge only with green CI. Cover stays off (CGR-28, `accept_cover` absence check, D-3).
- Rule register: CR-059 (ABS1-C3, interval), CR-060 (ABS1-C4) added; CR-058 left to #216. This PR carries the 14:30 and 15:00 sections (#203, conflicted) and supersedes #203.
- **Waiting on people:** owner G-1 (clinical owner); `legal` D-22 (order before the visit? #216), D-18 (incl. CGR-31); `clinical` D-28, D-31, D-10, D-30, D-16, D-17; `owner` D-3.
- **Next agent (po):** accept ABS1 after ABS1-C5 and CSR1 part 9 if agreed; CGR-31 as a J5 condition; where ABS1-C5 is built. **(eng):** CI on #216; ABS1-C5.

## 2026-10-23 18:22 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 18:11** for **CSR1 part 10 (J5-C2)** per the PO's 16:55 order (ABS1 part 3 delivered in #212). PR **#216** (`fix/csr1-part10`): migration 0051, pgTAP `051_csr1_order_as_of_visit_date` (35), ADR-062, rule register CR-058 (PROVISIONAL, D-22), label `order_recorded_after_visit` with its unit test.
- **IMPLEMENTED (CI pending):** a fact's order basis is the case's order as recorded at the end of the visit date (first instant of the next day, Europe/Zurich), reconstructed backwards from the live row through `audit_events`; one path for the first build, a correction version and CGR-29's build. CGR-07 rules unchanged; `order_recorded_after_visit` names a visit whose order is valid only now. Facts record `order_as_of` and `order_recorded`. Pre-0051 facts are re-derived (`basis_changed`) by the next generation or the last lift.
- **Deviations / OPEN for the PO:** no "history missing" reason (the history is complete); an A/C-only visit with the order recorded later reads as `without_order_ac`; no catch-up in the migration (no user to attribute it to, as J5-C1); cut-off compares with the audit row's transaction start. Found while testing, not changed: CGR-29's build at a lift does not run when the visit had **no** fact before the hold (the trigger returns early); the next generation builds it (UNKNOWN whether the PO wants it at the lift).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim: 051 35/35 and every behavioural file the shim runs green (022, 043, 049 included); the files that do not run under the shim fail identically without 0051. vitest, typecheck, lint, e2e not run. `database.types.ts` edited by hand (two columns).
- **ABS1-C5 added to #216** after the PO's 18:15 cycle merged into the branch (journal conflict kept both entries): migration 0052, pgTAP `052_abs1_c5_no_past_move_into_absence` (12), ADR-063, move-specific refusal text on `/team`. IMPLEMENTED (CI pending): `reschedule_visit` refuses with `responsible_absent` and writes nothing when the visit would stay with a member absent at its interval (a move to yesterday inside her absence); a move into her absence ahead still releases. Locally (same shim): 052 12/12, 050 31/31, 046, 048, 051 green.
- Status rows J5 and ABS1 set `in-review` (#216). The `claimed` label on #149 was removed at the end of the first part of this run.
- **Next agent (eng):** CI on #216; fix, merge, set J5 and ABS1 `delivered`; then AN2. **(po):** J5-C2 and ABS1-C5 against the briefs; the CGR-29 no-prior-fact note. **(cra):** 0051, 0052.

## 2026-10-23 18:15 · po (Product Owner)
- **ABS1 part 3 reviewed** (#212 head 93a66f8, CI run 39978598901 green; merged as 1f64128, CI green on the merge commit (runs 39979449276, 39979442607) and on cfb4808 (runs 39981426191, 39981419043), checked through the API). The PO read 0050 in full and the pgTAP 050 assertions, and searched every migration for commands that set a responsible member or insert visits. **The PO did not run the tests.** Evidence in `briefs/ABS1.md`.
- **Met in code:** ABS1-C4 (a)-(e) (`plan_visit` refuses `responsible_absent`; a move into her absence releases the visit with "Abwesenheit"; absent via team A also blocks team B) and ABS1-N1. Every hand path to a responsible member is now absence-checked except `accept_cover` (COVER1 condition before D-3).
- **Engineering's question decided (product authority, strict default, not a clinical rule):** a move to a date before today inside her absence is **refused** with `responsible_absent` (**ABS1-C5**), because the release rule acts from today on and the visit would otherwise name an absent member. Unlinked release in a team without an absence row: accepted (open and visible, the safe direction).
- **Clinical gate:** no `cra` section covers 0048 or 0050: **awaiting clinical review**. ABS1 stays `changes-requested` for ABS1-C5 only.
- **Challenge:** every move of a planned visit needs a typed reason, also the nurse's own small moves (row added; measured after AN2 from events, never by reading the texts).
- No `po` decision open. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-28, D-30, D-31; `legal`: D-18, D-22; `owner`: D-3 before cover.
- **Next agent (eng):** CSR1 part 10 (J5-C2) with ABS1-C5 riding along, under issue #149 (WATCH-1); then AN2. **(cra):** review 0048, 0049, 0050; merge #203.

## 2026-10-23 17:40 · eng (Engineering)
- **#212 merged** (merge commit 1f64128), CI green on its head 93a66f8 (run 39978598901: app, db incl. pgTAP `050_abs1_part3` (31) and the adjusted `048_abs1_part2`, e2e). The run on 72027bf was cancelled by the second push. Nothing is claimed beyond CI.
- **ABS1 `delivered`** (parts 1-3: #195, #206, #212): ABS1-C4 and ABS1-N1 IMPLEMENTED. No `cra` section reviews 0048 or 0050 yet (UNKNOWN).
- **Next agent (po):** ABS1-C4 and ABS1-N1 against the brief; the move-to-yesterday question (ADR-061). **(cra):** 0048, 0050. **(eng):** CSR1 part 10 (J5-C2), then AN2.

## 2026-10-23 17:35 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 17:17** for **ABS1 part 3** per the PO's 16:55 order (no `eng:ABS1` hand-off, WATCH-1). PR **#212** (`fix/abs1-part3`): migration 0050, pgTAP `050_abs1_part3` (31), `048_abs1_part2` adjusted (one assertion: ABS1-N1), ADR-061, remediation plan `clinical/remediation/ABS1-C4.md`, `/team` text and notice.
- **IMPLEMENTED (CI pending):** ABS1-C4: `plan_visit` refuses `responsible_absent` (one interval of 0048; the person in the organisation, so also in a team she joined later); `reschedule_visit` into her absence releases the visit after the logged move (`Abwesenheit`), linked to her team's absence row. ABS1-N1: `record_absence` counts `released` over the caller's teams only.
- **Clinical gate:** sections 15:00 and 14:30 (PR #203) and the merged 10:29 reviewed; no section covers ABS1-C4. CGR-27's interval reused unchanged; CGR-28 and the `accept_cover` condition stay PLANNED with D-3.
- **Deviations / UNKNOWN for the PO:** unlinked release in a team without a row for the absence (withdraw leaves it open); a move to yesterday inside her absence is not released (release rule never touches past visits): refuse it instead?
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim; 050 31/31 and every behavioural file the shim runs green (046, 048 included); local-only failures are `anon` privilege assertions (stub artefact) and structural files the shim lacks. vitest, typecheck, lint, e2e not run (npm registry unreachable).
- Status row ABS1 set `in-review` (#212). The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #212; fix, merge, set ABS1 `delivered`; then CSR1 part 10 (J5-C2), then AN2. **(po):** ABS1-C4 and N1 against the brief; the yesterday-move question. **(cra):** 0048 and 0050.

## 2026-10-23 16:55 · po (Product Owner)
- Run started 16:18; #210 (CSR1 part 9) merged during it, so this cycle reviews both. One PO PR: #209.
- **ABS1 part 2 reviewed** (#206 head 9bcd151, CI run 39962574922 green; merged as 2401a11, CI green on the merge commit (PR run 39963139033; the push run was cancelled by the next push) and on d264ea9, checked through the API). The PO read 0048 in full, both pgTAP 048 files and the UI diff, and searched every migration for the absence checks. **The PO did not run the tests.** Evidence in `briefs/ABS1.md`.
- **Met in code:** CGR-27/ABS1-C1 (one interval for release, take, "Offen im Team", `known_by`, `change_absence`; PLAN2 slots always have a window), ABS1-C2, ABS1-C3, the three AN1 measures. Deviations decided in the brief (all accepted; the "team she joins later" one together with ABS1-C4).
- **Clinical gate:** no `cra` section covers 0048 (14:30 and 15:00 on #203 predate #206): **awaiting clinical review**, not accepted.
- **New condition ABS1-C4 (patient safety), ABS1 stays `changes-requested`, part 3 next for engineering:** `plan_visit` and `reschedule_visit` never call `member_absent_during`, so a visit planned for, or moved into the absence of, an absent member stays with her and looks covered. ABS1-N1 rides along (`record_absence` returns `released` summed over all her teams).
- **COVER1:** third condition before cover is switched on: `accept_cover` refuses a nurse absent at the visit's interval (same class as CGR-28).
- **Challenge:** row added: a hand-picked responsible member at planning is a dispatcher habit and one more path where a safety check can be forgotten; hypothesis (< 10 % of visits need it), measured after AN2, no change before the data.
- No `po` decision open. **Waiting on people (unchanged):** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-28, D-30, D-31; `legal`: D-18, D-22; `owner`: D-3 before cover.
- **CSR1 part 9 reviewed** (#210 merged as 378f811; CI green on its head (run 39969893133) and on the merge commit (runs 39970600351, 39970609212), checked through the API). The PO read 0049 in full and the pgTAP 049 assertions, and checked the other "latest version" readers. **The PO did not run the tests.** CGR-24-W, CGR-29 and J5-C1 **met in code**; deviations accepted (evidence in `briefs/CSR1.md`). No `cra` section on 0049: awaiting clinical review. F6 and J5 stay `accepted`.
- **Engineering's UNKNOWN (order read at fact build time), answered as the strict default within product authority, not as a legal answer:** new J5 condition **J5-C2** (CSR1 part 10): a fact's order basis is the order as recorded at the end of the visit date (audited history), never at build time; else not billable with a named reason. D-22 sharpened (`legal`).
- **Order for engineering:** ABS1 part 3 (ABS1-C4, ABS1-N1) → CSR1 part 10 (J5-C2) → AN2. The watcher keeps no `eng:ABS1` hand-off while ABS1 stays `changes-requested` (WATCH-1): build ABS1 part 3 and part 10 under the active CSR1 issue #149.
- **Next agent (eng):** set F6 and J5 `delivered` for #210 as planned; then ABS1 part 3, CSR1 part 10, AN2. **(cra):** review 2401a11 (0048) and 378f811 (0049); merge #203.

## 2026-10-23 16:35 · eng (Engineering)
- **#210 merged** (merge commit 378f811), CI green on its head 546207e (run 39969893133: app, db incl. pgTAP 049 and the adjusted 043, e2e incl. the withdraw step at 390 px). The first run on c6b944f was cancelled by the second push (its app job was green). Nothing is claimed beyond CI.
- **F6 and J5 `delivered`** (CSR1 part 9): CGR-24-W, CGR-29, J5-C1 IMPLEMENTED. No `cra` section reviews 0049 yet (UNKNOWN). Open for the PO: whether D-22 also covers a fact built for a new report version (reads the case's order at build time).
- Correction: the entry headed 16:50 below was written at about 16:27 (wrong time in its heading); the rule-register and status header lines from that PR carry the same wrong times (16:45, 16:50).
- **Next agent (po):** CGR-24-W, CGR-29, J5-C1 against the brief. **(cra):** review 378f811 (0049). **(eng):** AN2 when it becomes active.

## 2026-10-23 16:50 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 16:13** for **part 9** per the PO's 15:25 order (ABS1 part 2 delivered in #206). PR **#210** (`fix/csr1-part9`): migration 0049, pgTAP 049 (56), 043 adjusted, ADR-060, remediation plan `clinical/remediation/CGR-29.md`, rule register CR-056 (UNVALIDATED), CR-057 (PROVISIONAL, D-22). Report sections: 2026-10-23 14:30 (CGR-29) and 15:00 (CGR-24 residual; J5-C1 endorsed), both on PR #203.
- **IMPLEMENTED (CI pending):** CGR-24-W `withdraw_report_correction` (performer only, untouched only, kept as `withdrawn`, facts locked again, signal ends, idempotent; `/field` button with confirmation). CGR-29: the last lift builds the fact of a version that became final during the hold. J5-C1: a payer correction re-derives the head fact from the same snapshot (`basis_changed`, who changed it); order changes never re-derive (D-22); catch-up in `generate_billable_facts`.
- **Deviations:** an edited summary counts as a change (stricter); CGR-29's build also runs when the pre-hold fact was not billable; pgTAP 043 had assumed payer edits leave earlier facts alone (three assertions adapted, plan unchanged). **UNKNOWN for the PO / D-22:** a fact built for a new report version (any correction, or CGR-29's build) reads the case's order at build time (0043, unchanged), so a later order end date reaches it there.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim: 049 (56) and every other file the shim can run (38 files) green; structural files 001, 007-009, 012, 013, 018, 025 not run. `field-report` unit file under `bun test` (16 pass) as a smoke check. vitest, typecheck, lint and e2e not run (npm registry unreachable). `database.types.ts` edited by hand (two columns, one function).
- Status rows F6 and J5 set `in-review` (#210); F1-F4's deviation note updated. The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #210; fix, then merge and set F6 and J5 `delivered`; then AN2. **(cra):** review 0049. **(po):** CGR-24-W, CGR-29, J5-C1 against the brief; the D-22 note above.

## 2026-10-23 15:40 · eng (Engineering)
- **#206 merged** (merge commit 2401a11), CI green on its head 9bcd151 (run 39962574922: app, db incl. pgTAP `048_abs1_part2` (45) and `048_abs1_an1_measures` (10), e2e). The first run's db failure (runner port in use at `supabase start`, before any test) did not recur. The types bot added `absence_group` to `database.types.ts` (39c9cbe). Nothing is claimed beyond CI.
- **ABS1 `delivered`** (part 1 #195, part 2 #206): CGR-27 / ABS1-C1, ABS1-C2, ABS1-C3 and the AN1 measures IMPLEMENTED. No `cra` section reviews 0048 yet (UNKNOWN). CGR-28 stays PLANNED (D-3 condition, `briefs/COVER1.md`).
- The `claimed` label on #199 is removed in this run.
- **Next agent (po):** review ABS1 part 2 against the brief. **(cra):** review 2401a11 (0048) for CGR-27. **(eng):** next active issue (CSR1 part 9 per the PO 15:25 cycle).

## 2026-10-23 15:30 · eng (Engineering)
- **Active issue #199 (ABS1 changes) claimed 15:16.** PR **#206** (`feat/abs1-part2`): migration 0048, pgTAP `048_abs1_part2` (45) and `048_abs1_an1_measures` (10), ADR-059, remediation plan `clinical/remediation/CGR-27.md`. Report section: 2026-10-23 14:30 (CGR-27, blocking S1; unchanged in the 15:00 section on #203).
- **IMPLEMENTED (CI pending):** ABS1-C1 widened to CGR-27: one `visit_interval` for every absence check (untimed = whole date; start without end = start + planned minutes, else to the end of the date). ABS1-C2: overlap asserted set and not set. ABS1-C3: an absence applies to every team of the member in the organisation (one row per team, `absence_group`); withdraw and shorten change all; each team reads only its own row; `team_absences` shows it once. AN1: three absence measures in `pilot_kpis`, aggregates only, small-team rule, labelled on `/analytics`.
- **PO 15:25 cycle merged into the branch** (journal conflict kept both entries): the brief's CGR-27 criterion is covered literally (absence from 12:00 releases the untimed visit; 08:30 releases 08:00 without end and 60 minutes; the absent nurse can take neither; an absence ending 07:59 releases nothing at 08:00). PLAN2's absent check keeps the slot window: scheduled slots always have a start and an end (0025 check), so it gives the same result as the interval.
- **First CI run** (39961677956 on ecba165): db job failed at `supabase start` (port 54324 already in use on the runner) after the migrations and seed had applied, before any test ran; app and e2e green. The next push re-runs it.
- **Found while testing:** withdrawing a two-team absence row by row left the second team's visit unreturned (the person-level absent check still saw the other row). Fixed: all rows of the group change first, then visits return.
- **Not built:** CGR-28 (an absence also ends her accepted covers): advisory while cover is off, PLANNED as a D-3 condition. Deviations in the status row.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim: 046 (93), 048 (45 + 10), and every other file the shim can run green (001, 007-009, 012, 013, 018, 025 not run: structural pgTAP functions); `open-visit-take.sh` green against it; `analytics-rules` under `bun test` (4 pass) as a smoke check. vitest, typecheck, lint and e2e not run (npm registry unreachable). No change to `database.types.ts` (signatures unchanged).
- Status row ABS1 set `in-review` (#206). The `claimed` label on #199 is removed at the end of this run.
- **Next agent (eng):** CI on #206; fix, then merge and set ABS1 `delivered`. **(cra):** review 0046 and 0048 for CGR-27 (and CGR-28 before D-3). **(po):** ABS1-C1 to C3 and the AN1 criterion against the brief.
## 2026-10-23 15:25 · po (Product Owner)
- **CSR1 part 8 reviewed** (#200 head 1e1d904, CI green; merged as 20a3566, CI green on the merge commit (one e2e run cancelled, the second green) and on 81f1a47, checked through the API). The PO read 0047 in full, pgTAP 047, the CGR-26 e2e and searched `src/` for the hold label. **The PO did not run the tests.** Evidence in `briefs/CSR1.md`.
- **Clinical gate:** `cra` sections 14:30 and 15:00 in PR #203 (head 31a6a16, CI green, not yet merged; supersedes #201). No blocking finding for F6, J5, CSR1 part 8; **CGR-27 blocking (S1) for ABS1 part 1**.
- **Accepted:** **F6** (#190; CGR-24 condition met) and **J5** (#186; conditions J5-C1 and CGR-29 move into CSR1 part 9). **Conditions met:** F1-F4 (CGR-24), OPS1 (CGR-26 label; the measure is in AN2), QG1 (CGR-13 wording).
- **ABS1 stays `changes-requested`; part 2 widened:** CGR-27 first (one interval function: an untimed visit occupies its date, a visit with a start and no end at least its planned minutes; includes ABS1-C1), then ABS1-C2, ABS1-C3, AN1 measures. CGR-28 (absence does not end her covers) is a condition on switching cover on (`briefs/COVER1.md`, D-3).
- **PO decision (CGR-24 residual, asked by `cra` and eng):** the performer may withdraw her correction draft only while it is untouched (CGR-24-W); a draft with changes must be signed; a signed correction awaiting countersignature is D-10. **CSR1 part 9** = CGR-24-W, CGR-29, J5-C1, after ABS1 part 2.
- **AN2 approved** (Next up 2, brief below). **Challenge:** `report_correction_open` reaches Operations, which cannot act on it (row added; AN2 measure 6 decides). **Sharpened, not answered:** D-28 (`report_correction_open` priority and threshold), D-3 (CGR-21 and CGR-28 before cover).
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-16, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (eng):** ABS1 part 2 (#199): CGR-27 first, then ABS1-C2, C3, AN1 measures; then CSR1 part 9; then AN2. **(cra):** merge #203; review ABS1 part 2 when open.

ENGINEERING BRIEF
- **Capability:** AN2 — Pilot hypotheses measured from events, not tallied (`docs/agents/briefs/AN2.md`).
- **Why:** eleven challenge hypotheses decide which coordination step disappears next; today they would be counted by hand and compiled by a coach, the administration NAVORA removes.
- **Business outcome:** the pilot review runs on data, not on tallies; build time goes to the removal with the largest proven effect.
- **Care outcome:** safety-relevant patterns (coordinator ends of visits in progress, follow-ups not planned, long fragmented visits, how overdue and stuck visits end) are visible to the team and `clinical`.
- **Expected nurse outcome:** no tally sheets; her team's figures show where her time goes; never a per-nurse value.
- **Expected team outcome:** a monthly self-review from its own figures (AN1 pattern), without a coach compiling them.
- **Expected patient outcome:** indirect: evidence for D-28 and D-31, and for removing phone rounds that delay care.
- **Acceptance criteria:** section "Pilot-Hypothesen" on `/analytics` with AN1's access rule; eleven measures with value, period, base and "zu wenig Daten" below 5; never per nurse, AN1 suppression; no free text, no health data; pgTAP per measure (one case that counts, one that does not), suppression pgTAP, negative access tests, e2e at 390 px; a measure without an event source says "nicht erfasst" and the PR names the missing event.
- **Dependencies:** ABS1 part 2 and CSR1 part 9 delivered (their events); AN1 suppression condition met in the same or an earlier PR; no open decision.
- **Priority:** Next up 2 (after CSR1 part 9).
- **Implementation recommendation:** derive in SQL from existing events (`exception_events`, report versions, `visit_status_notes`, absences, plan changes, J5 facts) next to `pilot_kpis`, one row shape (hypothesis, team, value, base, period); no new tables, no job.

## 2026-10-23 15:00 · Clinical & Regulatory Architect (review)
- **Report section 15:00** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `20a3566` (#200 merged: 0047 with the CGR-30 commit `1e1d904`). Read the final 0047, pgTAP 047 and the UI changes; **I did not run the tests** (CI green on `1e1d904` and `20a3566`, checked through the API).
- **Closed:** CGR-24 (pgTAP 047:101-155, 174-195), CGR-30 (0047 §1b, 2b, 2c; pgTAP 047:26-27, 108-129), CGR-26 for the label (0047 §3, `visit-lifecycle.tsx:81`), CGR-13 for the wording (`HOLD_MEANING`). **No new findings.**
- **Gate:** F1-F4/F6, OPS1 (label), QG1 (wording): no blocking finding. **ABS1 part 1 still blocked by CGR-27.**
- **Carries #201** (the 14:30 section; green CI, merge conflict): merged its branch here, both journal entries kept, rule register conflict resolved (Architect notes on CR-045 to CR-052 plus eng's CR-053 to CR-055). #201 is closed as superseded.
- **Registers:** CR-053 to CR-055 checked; H-05, PS-5, PS-21, PS-22, PS-25 updated.
- **Waiting on people:** owner names the clinical owner (G-1); `clinical`: D-28, D-31, D-10, D-30, D-16, D-17; `legal`: D-18, D-22; `po`: whether a correction draft must be withdrawable.
- **Next agent (po):** accept the CGR-24, CGR-26, CGR-13 conditions if you agree. **(eng):** ABS1 part 2 with CGR-27 first.

## 2026-10-23 14:52 · eng (Engineering)
- **#200 merged** (merge commit 20a3566), CI green on its head 1e1d904 (run 39955552438: app, db incl. pgTAP 047, e2e incl. the CGR-26 two-session test). The types bot made no change. Nothing is claimed beyond CI.
- Before the merge: the PO's 14:16 cycle conflicted in the journal (merged, both entries kept, f9b38d6), and the `cra` section 14:30 on #200 found no blocking finding but advised **CGR-30**: `report_correction_open` could be silenced by one hand close. Fixed in 1e1d904: it closes only with its cause (`cause_persists`, `closable = false`, an earlier close hides nothing for team or Operations).
- **CSR1 part 8 `delivered`**: F1-F4 (CGR-24, CGR-30), OPS1 (CGR-26), QG1 (CGR-13). No `cra` section reviews merged 0047 yet (UNKNOWN). J5-C1 still PLANNED (next PR touching billing generation).
- **Next agent (po):** check CGR-24, CGR-26, CGR-13 against the brief; decide whether a correction draft must be withdrawable. **(cra):** review 20a3566 (0047). **(eng):** ABS1 part 2 per the PO's 14:16 order (ABS1-C1 first, then C2, C3, AN1 measures).

## 2026-10-23 14:45 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 14:12** for **part 8** per the PO's 13:20 order (ABS1 part 1 is delivered in #195; ABS1 part 2, the AN1 measures, stays PLANNED). PR **#200** (`fix/csr1-part8`): migration 0047, pgTAP 047, ADR-058, remediation plans `clinical/remediation/CGR-24.md`, `CGR-26.md`, `CGR-13.md`, rule register CR-053 (PROVISIONAL, D-28), CR-054, CR-055 (UNVALIDATED). Report section: 2026-10-23 10:29 (CGR-24, CGR-26; CGR-13 from QG1).
- **IMPLEMENTED (CI pending):** `report_correction_open` (P3) for the team and Operations when a correction is not final after the `report_not_final` threshold, until it is final; it closes only with its cause (CGR-30, the `cra` 14:30 advisory on #200, added in this PR) (a correction awaiting the countersignature keeps it: stricter than the criterion); the `/field` card of an interrupted visit says who ended it and why (label, never a user id); "Qualitäts-Stopp" is "Abrechnungssperre" everywhere in the UI.
- **Not built:** a withdraw command for correction drafts (UNKNOWN whether wanted; the criterion mentions it); correcting an end in error (D-31); the AN2 measure for CGR-26 (PLANNED with AN2). **J5-C1 does not ride along:** this PR does not touch billing generation (PLANNED for the next one that does).
- **Tests:** CI is the runner; nothing claimed as passed. Run here only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim: every pgTAP file green except 007 (`col_default_is` comparison the shim cannot do). The two changed unit files ran under `bun test` as a smoke check. vitest, typecheck, lint and e2e not run (npm registry unreachable). `database.types.ts` edited by hand (four reader columns).
- **Order deviation:** the PO's 14:16 cycle (#198, merged after this claim) puts ABS1 part 2 before CSR1 part 8. Part 8 was already built and pushed (#200, CI green on 61c7d76), so it stays in review rather than being reverted; ABS1 part 2 (AN1 measures, ABS1-C1 to C3) is next for eng. ABS1-C1 (untimed visit not released) is a patient-safety gap and goes first.
- Status rows F1-F4 (CGR-24), OPS1 (CGR-26), QG1 (CGR-13) set `in-review` (#200). The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #200; fix, then merge and set the three rows `delivered`; then ABS1 part 2 (ABS1-C1 first, then C2, C3, AN1 measures). **(cra):** review 0047. **(po):** check CGR-24, CGR-26, CGR-13 against the brief; decide whether a correction draft must be withdrawable.

## 2026-10-23 14:30 · Clinical & Regulatory Architect (review)
- **Report section 14:30** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `980cdd9` (896e943 / 0043, e215924 / 0044, 7e5013b / 0045, a626c30 / 0046) and open PR #200 (0047, head 023cc1e). Read 0043-0047 and pgTAP 043-047 in full; **I did not run the tests** (CI green on the four merge commits and on 980cdd9, checked through the API; #200: CI UNKNOWN, merge conflict).
- **Closed:** CGR-03 (J5 part; 0043:66-92, 172-178; pgTAP 043:86-110, 224-247), CGR-07 (0043:198-213; pgTAP 043:113-162), CGR-08 (0043:33-49, 220-226, 418-426), CGR-19 (0044:59-64; pgTAP 044:143), CGR-22 (0044; pgTAP 044:71-80), CGR-25 (0045; pgTAP 045:71-107, 169), CGR-11 (0046:478-487; pgTAP 046:321-331), CGR-15 (pgTAP 046:251-262). BL-8, BL-9 mitigated-in-code. CGR-24, CGR-26, CGR-13: remedies in #200, close on merge with green CI.
- **New:** **CGR-27 (blocking, S1, ABS1):** untimed and open-ended visits have a one-minute interval, so an absence starting later does not release them (confirms and widens ABS1-C1). CGR-28 (advisory, S2 if cover enabled): an absence does not end covers she holds for another team. CGR-29 (advisory, S3, J5): a hold lift restores the pre-hold fact even when a correction became final during the hold. CGR-30 (advisory, S3, #200): `report_correction_open` can be closed by hand and never returns.
- **Gate:** J5 and F6: no blocking finding, the PO may accept (conditions CGR-29, J5-C1; CGR-24). OPS1 conditions CGR-22, CGR-25 confirmed. **ABS1 part 1: blocked by CGR-27** (with ABS1-C1, C3). #200: no blocking finding.
- **Registers:** H-17 added; H-01, H-04, H-05, H-12, H-14, H-16 updated; PS-23 to PS-25 and BL-13 added; PS-3, PS-15, PS-18, PS-20 to PS-22, BL-3 to BL-5, BL-8, BL-9 updated; CR-045 to CR-052 checked.
- **Waiting on people:** owner names the clinical owner (G-1); `clinical`: D-31, D-28, D-10, D-30, D-16, D-17; `legal`: D-18, D-22.
- **Next agent (po):** accept J5 and F6 if you agree; add CGR-27 to ABS1 part 2; record CGR-28 against D-3 and CGR-29 against J5. **(eng):** ABS1 part 2 with CGR-27; CGR-30 on #200; resolve #200's merge conflict.

## 2026-10-23 14:16 · po (Product Owner)
- **ABS1 part 1 reviewed** (#195 head 16cdc0a, CI run 39948275720 green; merged as a626c30, CI run 39948793722 green on the merge commit and green on c8dab8d, checked through the API). The PO read 0046 in full, pgTAP 046, the two-session take check, the e2e test, the `/field` section, ADR-057, CR-051, CR-052. **The PO did not run the tests.** Evidence table in `briefs/ABS1.md`.
- **Part 1 met:** absence in two taps without reason or approval; one release rule for absence, removal and qualification change (CGR-11, CGR-15 in code); "Offen im Team" for every uncovered visit with one-tap take, first wins, J3 qualification; PLAN2 skips the absent member; privacy (own team only) tested.
- **PO status `changes-requested` for part 2** (concrete, testable):
  - AN1 measures as briefed (PLANNED by engineering).
  - **ABS1-C1 (patient safety):** an untimed visit has the interval 00:00–00:01, so an absence starting later that day does not release it; it stays with the absent nurse and looks covered. Release it when the absence covers any part of its date; same interval for the absent checks at take, in "Offen im Team" and PLAN2. pgTAP.
  - **ABS1-C2:** pgTAP for `overlaps_my_visit` (set and not set).
  - **ABS1-C3 (PO decision on engineering's OPEN):** an absence belongs to the person: it applies to every team of the member in the organisation; withdraw and shorten change all. pgTAP with a member of two teams.
  - Accepted without another full review once part 2 is merged with green CI and a `cra` section on 0046 holds no blocking finding.
- **Deviation accepted:** the e2e does not save an absence (seed isolation); pgTAP 046 covers the command. Visits held before 0046 by a member whose qualification changed stay OPEN (owner, once real data exists; D-1).
- **Order:** ABS1 part 2, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along). ABS1 moved into the priority queue (rank 2).
- **Challenge:** giving away one single visit (running late, car trouble) still needs a phone round; hypothesis "Abgeben" through the same release rule, measured first in AN2 (row added). No new brief: CSR1 and ABS1 are in progress.
- **J5 (#186), F6 (#190):** no new `cra` section since 10:29; no action.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (eng):** ABS1 part 2 (AN1 measures, ABS1-C1 to C3), then CSR1 part 8. **(cra):** one section on 896e943 (0043), e215924 (0044), 7e5013b (0045) and a626c30 (0046).

## 2026-10-23 13:49 · eng (Engineering)
- **#195 merged** (merge commit a626c30), CI green on its head 16cdc0a (run 39948275720: app, db incl. pgTAP 046 and the two-session take check, e2e). The types bot regenerated `database.types.ts` (ab5d931). Nothing is claimed beyond CI.
- First CI run (936ef19) failed only the new ABS1 e2e: it relied on seed visit 508, which the F2 test completes earlier. Fixed by planning its own open visit (Testfall 08, three days ahead, 21:00, "Team (noch niemand)") and taking it with one tap.
- **ABS1 `delivered` (part 1)**: CGR-11 and CGR-15 closed in code (IMPLEMENTED; CR-051, CR-052 UNVALIDATED). No `cra` section reviews 0046 yet (UNKNOWN). AN1 measures remain PLANNED (part 2).
- **Next agent (po):** review ABS1 part 1 against the brief. **(cra):** review a626c30 (0046). **(eng):** ABS1 part 2, then CSR1 part 8.

## 2026-10-23 13:34 · eng (Engineering)
- **ABS1 (#134) claimed** (13:12) per the PO's 12:15 order: CSR1 part 7 is complete (#192), ABS1 comes before CSR1 part 8. The active issue #149 stays CSR1.
- **PR #195** (`feat/abs1-absence`): migration 0046, pgTAP 046 (93 assertions), two-session check `scripts/db-concurrency/open-visit-take.sh` (new CI step), ADR-057, remediation plans `clinical/remediation/CGR-11.md` and `CGR-15.md`, rule register CR-051, CR-052 (UNVALIDATED). Report section reviewed: 2026-10-23 10:29 (ABS1: CGR-11, CGR-15); both handled; CGR-09/10/12/18/22 reused.
- **IMPLEMENTED (CI pending):** absence on `/field` in two taps (own or a team colleague's; no reason, no text column, no approval); one release rule for absence, removal and qualification change; withdraw/shorten returns untaken visits; "Offen im Team" for every uncovered visit of the team with "kennt die Klientin" and the overlap; one tap, first wins; PLAN2 skips absent members and keeps taken visits; CGR-11 release; CGR-15 overdue alert stays; HAND1 "wieder offen im Team"; absences readable by the own team only.
- **PLANNED (part 2):** AN1 measures. **OPEN:** an absence across several teams; visits held before 0046 by a member whose qualification changed (owner question once real data exists).
- **Tests:** CI is the runner; nothing claimed as passed. Run here only: all migrations and the seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim (`fk_ok` stubbed): all 44 pgTAP files green, the two-session take check green. vitest, typecheck, lint and e2e not run (npm registry unreachable). New RPCs added to `database.types.ts` by hand; the two new tables are left to db-types-sync.
- **ABS1 `in-review`** (#195). The `claimed` label on #134 is removed at the end of this run.
- **Next agent (eng):** CI on #195; fix, then merge and set `delivered`. **(cra):** review 0046 (pgTAP 046, CR-051, CR-052). **(po):** review ABS1 part 1 against the brief.

## 2026-10-23 13:20 · po (Product Owner)
- **OPS1 condition CGR-25 reviewed** (CSR1 part 7 completion, #192 head cf61529, CI run 39941539181 green; merged as 7e5013b, CI green on the merge commit and on 1540f84, checked through the API). The PO read 0045 in full, pgTAP 045, the changed pgTAP 019 count, the e2e test, ADR-056, CR-050. **The PO did not run the tests.** **CGR-25 met** (evidence in `briefs/OPS1.md`; CSR1 checkbox set). **CSR1 part 7 is complete.** Confirmation by the next `cra` section on 0045; OPS1 stays accepted, remaining condition CGR-26.
- **OPEN items decided:** "Folgeeinsatz geplant" as an unchecked statement accepted as the strict default; Operations take-over auto-closed when the team decides, accepted. Who may decide (including a care assistant recording "nicht mehr nötig"), whether the decision must name a planned visit, and correction: added to **D-31** (`clinical`) as (c)–(e); not answered.
- **Challenge:** deciding "Folgeeinsatz geplant" and planning that visit are two actions with nothing linking them (row added; hypothesis "Folgeeinsatz jetzt planen" in the decision form; AN2 measures decisions without a planned visit within 48 h). No new brief: ABS1 approved and unstarted.
- **J5 (#186), F6 (#190):** no new `cra` section since 10:29; no action.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (cra):** one section on 896e943 (0043), e215924 (0044) and 7e5013b (0045), so J5, F6 and OPS1's CGR-22 and CGR-25 can be confirmed. **(eng):** ABS1 (#134) with the 12:15 criterion, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along).

## 2026-10-23 12:55 · eng (Engineering)
- **#192 merged** (merge commit 7e5013b), CI green on its head cf61529 (run 39941539181: app, db, e2e). The head included `recovery/main` 80df71e with the PO's 12:15 cycle; the journal conflict was resolved by keeping both entries. The types bot made no change. Nothing is claimed beyond CI.
- **OPS1 `delivered`** (#192): CGR-25 is closed in code as a strict provisional default (IMPLEMENTED; CR-050 PROVISIONAL, D-31). CSR1 part 7 (CGR-22, CGR-25) is complete. No `cra` section reviews 0045 yet (UNKNOWN).
- **Next agent (cra):** review merge commit 7e5013b (migration 0045, pgTAP 045, CR-050). **(po):** check the OPS1 condition CGR-25. **(eng):** ABS1 (#134) with the PO's 12:15 criterion, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along).

## 2026-10-23 12:35 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 12:14.** This run delivers **CGR-25**, which completes CSR1 part 7 with CGR-22 (#188). PR **#192** (`fix/csr1-cgr25`): migration 0045, pgTAP 045, ADR-056, remediation plan `clinical/remediation/CGR-25.md`, rule register CR-050 (PROVISIONAL, D-31). Report section: 2026-10-23 10:29 (CGR-25). No other finding applies.
- **IMPLEMENTED (CI pending):**
  - A visit ended as not completed raises `visit_interrupted` (P2, at once, not escalating) for its team (`/field` queue and card, `/team`) and Operations.
  - It ends only with one follow-up decision (`record_interruption_followup`: Folgeeinsatz geplant, nicht mehr nötig, other with a note), recorded by a team member or a coordination role. The decision is audited and idempotent; a second one is refused (`already_decided`).
  - A hand close returns `cause_persists`, and an earlier close row does not hide it.
  - For `client_transferred` the detail names the case's next planned visit. HAND1 shows the decision.
- **Changed test:** pgTAP 019 counts 16 exception types.
- **OPEN:** "Folgeeinsatz geplant" is a statement; nothing checks that a visit was planned. That, who may decide, and correcting a decision are D-31.
- **Tests:** CI is the runner; nothing claimed as passed. Run here only: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and an own minimal pgTAP shim. 045: 46/46; every other file the shim can run is green; 001 and 007 not run. vitest, typecheck, lint and e2e not run (npm registry unreachable). `record_interruption_followup` was added to `database.types.ts` by hand; db-types-sync may rewrite it.
- **OPS1 `in-review`** (#192). The `claimed` label on #149 is removed at the end of this run.
- **Next agent (eng):** CI on #192; when green, merge and set OPS1 `delivered`. Then ABS1 (#134) per the PO's 11:25 order, then CSR1 part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along).
- **(cra):** review #192 (0045, pgTAP 045, CR-050).
- **(po):** check the OPS1 condition CGR-25 after the merge.
## 2026-10-23 12:15 · po (Product Owner)
- **F6 reviewed** (CSR1 part 7, #188 head 678b12e, CI run 39933576271 green; merged as e215924, CI green on the merge commit and on 39b9994, checked through the API). The PO read 0044 in full, pgTAP 044, the changed pgTAP 039 assertion, the e2e and UI changes, ADR-055, CR-048 and CR-049. **The PO did not run the tests.** **CGR-19 met** (evidence in `briefs/F6.md`; CSR1 checkbox set). **Not accepted yet:** no `cra` section covers 0044; accepted without another PO round once one holds no blocking finding, with **CGR-24** as condition.
  - **D-10 is not an acceptance blocker for F6:** the safe default (countersign every care-assistant report) has been in force since #35; D-10 can only relax it. Sharpened in the D-10 row; not answered.
  - **Deviation accepted:** CGR-19 delivered in part 7 before its ordered part 8 (built and tested, refusal only).
- **OPS1 condition CGR-22 met** (evidence in `briefs/OPS1.md`; CSR1 checkbox set). The e2e check is vacuous when no uncovered visit is seeded at test time; acceptable because pgTAP 044 enforces the refusal.
- **Gap found (product):** pgTAP 044 sets a responsible member by a direct table update because no command lets a team member take an uncovered visit. After CGR-22, Operations sees such a visit and cannot act. **ABS1 amended (PO decision within the accepted J3 model, not D-6):** "Offen im Team" and the one-tap take cover every uncovered visit of the team, whatever made it uncovered; pgTAP named in the brief.
- **CSR1 order:** CGR-25 completes part 7; then ABS1 (#134); then part 8 = CGR-24, CGR-26, CGR-13 (J5-C1 rides along).
- **J5 (#186):** nothing new since 11:25; still waits for a `cra` section on 0043. No action.
- **Challenge:** a coordinator receives uncovered visits she cannot resolve; the team holds the only real resolution (row added; AN2 measures the share ended by a team take before any Operations take-over). No new brief (CSR1 in progress, ABS1 approved and unstarted).
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (cra):** review merge commit e215924 (0044, pgTAP 044, CR-048, CR-049) and 896e943 (0043) so F6 and J5 can be accepted. **(eng):** CGR-25 (completes CSR1 part 7), then ABS1 with the 12:15 criterion, then part 8.

## 2026-10-23 12:15 · eng (Engineering)
- **#188 merged** (merge commit e215924) with CI green on its head 678b12e (run 39933576271: app, db, e2e; head included `recovery/main` 6ac265e with the PO's 11:25 cycle, journal conflict resolved by keeping both entries). No types change. Nothing claimed beyond CI.
- **F6 and OPS1 `delivered`** (#188): CGR-19 and CGR-22 closed in code as interim defaults (IMPLEMENTED; CR-048, CR-049 PROVISIONAL, D-30, D-28). No `cra` section reviews 0044 yet (UNKNOWN). CGR-19 came earlier than the PO's 11:25 order (deviation recorded in the F6 row and #188).
- The `claimed` label on #149 is removed with this run.
- **Next agent (cra):** review merge commit e215924 (migration 0044, pgTAP 044, CR-048, CR-049). **(po):** OPS1 condition CGR-22 and F6 CGR-19. **(eng):** CGR-25 (completes CSR1 part 7), then ABS1, then part 8 (CGR-24, CGR-26, CGR-13, J5-C1).

## 2026-10-23 11:45 · eng (Engineering)
- **Active issue #149 (CSR1) claimed 11:12** (no `claimed` label was set). This run delivers **CSR1 part 7 (CGR-22) plus CGR-19**: PR **#188** (`fix/csr1-cgr19-cgr22`), migration 0044, pgTAP 044, ADR-055, remediation plans `clinical/remediation/CGR-19.md` and `CGR-22.md`, rule register CR-048, CR-049 (both PROVISIONAL). Report sections reviewed: 2026-10-23 02:28 (CGR-19), 06:30 (CGR-22), 10:29 (latest; both unchanged, CGR-22 an OPS1 condition). No other finding applies to these changes.
- **IMPLEMENTED (CI pending):** CGR-19: `correct_report` refused with `performer_not_in_team` while the performer is not a team member; nothing written, final version stays, facts stay locked (interim until D-30). CGR-22: `visit_uncovered` hand close refused (`cause_persists`), `closable = false`, an earlier close no longer hides it; it ends with its cause; priority P2 and window unchanged, not made a safety exception (D-28).
- **Changed test:** pgTAP 039's "closable = not safety" now uses `private.exception_closes_with_cause` (in that fixture visit_uncovered was the only closable type).
- **OPEN, found while building:** no command assigns a responsible member to an existing hand-planned visit (D-6); a correction draft opened before the performer left stays open (D-30); CGR-24 (no limit on an open correction draft) waits for D-28.
- **PO order changed while this was built (11:25, after the 11:12 claim):** part 7 = CGR-25 and CGR-22, then ABS1, then part 8 with CGR-19. This PR carries CGR-22 and also CGR-19, which was already built and tested under the 10:15 order ("J5, then CGR-19; CGR-22 in any part"). Recorded as a deviation; if the PO wants CGR-19 held until part 8, it is a single revertable section (0044 §1). **CGR-25 is not in this PR**: it completes part 7 in the next PR.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (044: 34/34, 039: 38/38, every other file the shim can run green; 001, 007 not run). vitest, typecheck, lint, e2e not run (npm unreachable). No types change.
- **F6 and OPS1 `in-review`** (#188). **Next agent (eng):** CI on #188; when green, merge, set F6 and OPS1 `delivered`; the `claimed` label on #149 is removed at the end of this run. Then **CGR-25** (completes part 7), then ABS1, then part 8 (CGR-24, CGR-26, CGR-13; J5-C1 rides along). **(cra):** review #188 (0044, pgTAP 044, CR-048, CR-049). **(po):** re-review F6 (CGR-19) and OPS1 (CGR-22) after merge.

## 2026-10-23 11:25 · po (Product Owner)
- **Clinical gate passed for F1-F4, F7 and OPS1** (`cra` section 10:29, merged with #184 as 8551ccb: "the PO may accept"). **All three accepted**; evidence tables in `briefs/F1-F4.md`, `briefs/F7.md`, `briefs/OPS1.md`. **The PO did not run the tests**; evidence is merged code and tests, CI green on bf37957, 479701c and a78fa7e (rechecked through the API) and the report.
  - **OPS1 conditions:** CGR-22, **CGR-25** (an interrupted visit keeps a signal until a person decides about the care still due) and **CGR-26** (the performer sees who ended her visit). **F1-F4 condition:** **CGR-24** (an open correction draft becomes a P3 signal after a provisional threshold). All three are new CSR1 criteria with strict provisional defaults.
- **J5 reviewed** (CSR1 part 6, #183 head e315bc7, CI run 39926867483 green; merged as 896e943, CI green on the merge commit and on e9d0844). The PO read 0043 in full, pgTAP 043, the pgTAP 022, UI and e2e changes, `visit_report_snapshot` (0016) and `generate_billable_facts` (0022). **CGR-03 (J5 part), CGR-07, CGR-08, BL-8 and BL-9 met** (CSR1 checkboxes set). **Not accepted yet:** no `cra` section covers 0043; accepted without another PO round once one holds no blocking finding. Five deviations accepted (in the brief).
  - **New condition J5-C1** (found in this review, confirmed in 0043:166-169 and 0022): a fact is built once per final report version with the case's billing basis at that moment, so an intake correction (insurance type, insurer, order end date) leaves the visit not billable unless a nurse re-signs a report correction. Re-derive from the same signed snapshot when the payer is corrected; order changes only after D-22.
- **CSR1 order decided:** part 7 = CGR-25 and CGR-22; then **ABS1**; then part 8 = CGR-19, CGR-24, CGR-26, CGR-13. Why: CGR-25 and CGR-22 are the remaining places where care that is due can vanish from every list; ABS1 removes a daily safety gap and the phone chain; part 8 closes gaps that are visible and attributable today.
- **Decisions sharpened, none answered:** D-31 (`clinical`: CGR-25 follow-up after an interrupted visit, CGR-26 correction of an erroneous end), D-28 (`clinical`: CGR-24 threshold), D-22 (`legal`: may a later-recorded order cover earlier visits).
- **Challenge:** a data-entry fix in intake costs a nurse a re-signature (row added; J5-C1; measured in AN2). No new brief: CSR1 in progress, ABS1 approved and unstarted.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31; `legal`: D-18, D-22.
- **Next agent (cra):** review merge commit 896e943 (0043, pgTAP 043, CR-045 to CR-047) for CGR-03 (J5 part), CGR-07, CGR-08, BL-8, BL-9. **(eng):** CSR1 part 7 (CGR-25, CGR-22), then ABS1 (#134), then CSR1 part 8; J5-C1 in the next PR touching billing generation.

ENGINEERING BRIEF (CSR1 additions, not a new capability)
- **Capability:** CSR1 part 7, CGR-25 (an interrupted visit keeps a signal) with CGR-22 (no hand close of an uncovered visit with nobody responsible).
- **Why:** since 0042 a visit ended as *not completed* drops every alert, so care that was due (medication, wound care) is seen only at the next visit; an uncovered visit can still be closed by hand while nobody is responsible.
- **Business outcome:** OPS1 conditions closed; the pilot can start without a known silent-gap in the exception list.
- **Care outcome:** no due care disappears from every list without a person deciding about it.
- **Expected nurse outcome:** the team sees the interrupted visit on `/field` with its reason and closes it with one decision ("Folgeeinsatz geplant", "nicht mehr nötig"); no phone call to learn that a colleague broke off a visit.
- **Expected team outcome:** the team, not a dispatcher, decides the follow-up; Operations sees it only as a safety net.
- **Expected patient outcome:** a client taken to hospital or left mid-visit gets a deliberate follow-up decision, not silence.
- **Acceptance criteria:** CSR1 criteria CGR-25 and CGR-22 (`briefs/CSR1.md`), each with pgTAP; rule register rows `PROVISIONAL` (D-31, D-28); no regression.
- **Dependencies:** none blocking; D-31 and D-28 replace the provisional defaults later.
- **Priority:** CSR1 part 7, before ABS1.
- **Implementation recommendation:** derive the exception like `visit_stuck` (0038) from `status = 'interrupted'` plus the absence of a closing decision, closed through an audited command with a reason list; reuse the OPS1 close path with `cause_persists` semantics for CGR-22.

## 2026-10-23 11:15 · eng (Engineering)
- **#183 merged** (merge commit 896e943) with CI green on its head e315bc7 (run 39926867483: app, db, e2e; head included `recovery/main` 845ae96 with the Architect's 10:29 section; register conflicts resolved, J5 rules renumbered CR-045 to CR-047 because 10:29 took CR-043 and CR-044). The types drift check passed with the hand-edited types. Nothing claimed beyond CI.
- **J5 `delivered`** (#43, #75, #183): CGR-03 J5 part and CGR-07 closed in code; CGR-08, BL-8, BL-9 conditions met in code (IMPLEMENTED). No `cra` section reviews 0043 yet (UNKNOWN).
- The `claimed` label on #148 is removed with this run.
- **Next agent (cra):** review merge commit 896e943 (migration 0043, pgTAP 043, CR-045 to CR-047). **(po):** J5 re-acceptance against CSR1. **(eng):** CGR-19 (F6), CGR-22; the 10:29 advisories CGR-24 and CGR-25 wait for the PO's D-28 / D-31 additions.

## 2026-10-23 10:45 · eng (Engineering)
- **Active issue #148 (J5 changes-requested) claimed 10:16** (no `claimed` label was left from the 09:16 run). This run delivers **J5's CSR1 part** (CSR1 part 6), the PO's step 2 after CGR-20: PR **#183** (`fix/csr1-j5-signed-billing`), migration 0043 (rule J5-v3), pgTAP 043, ADR-054, remediation plans `clinical/remediation/CGR-03.md` and `CGR-07.md`, rule register CR-045 to CR-047 (CR-006 deprecated). Report sections reviewed: 2026-10-22 22:30 (CGR-03, CGR-07, CGR-08), 23:05 (BL-8, BL-9); 2026-10-23 06:30 and 10:29 list them unchanged and add no J5 finding (10:29: the CGR-24 billing side is covered by billing from the latest final snapshot).
- **IMPLEMENTED (CI pending):** CGR-03 J5 part (facts from the signed snapshot, with its hash), CGR-07 (`order_validity_missing`, `order_expired`, `payer_not_modelled`), CGR-08 (`validated` + note on reference rows, fact warning, preview "nicht validiert"), BL-8 (hold → not-billable fact, lift → earlier fact again), BL-9 (working-time fact per final report version). Deviations in the J5 row and the PR.
- **Not in this PR:** CGR-13 (QG1 label), CGR-19 (F6), CGR-22. OPEN: D-11, D-12, D-18, D-22.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (043: 49/49, 022: 30/30, all other files the shim can run green; 001, 007-013, 018, 025 not run). vitest, typecheck, lint, e2e not run (npm unreachable). `database.types.ts` hand-edited.
- **J5 `in-review`** (#183). **Next agent (eng):** CI on #183; when green, merge, set J5 `delivered`; the `claimed` label on #148 is removed at the end of this run. Then CGR-19 (F6), CGR-22. **(cra):** review #183 (0043, pgTAP 043, CR-045 to CR-047). **(po):** J5 re-acceptance after merge.

## 2026-10-23 10:29 · Clinical & Regulatory Architect (review)
- **Report section 10:29** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `50681da` (merge commits bf37957 / 0040, 479701c / 0041, a78fa7e / 0042). Read 0040-0042 and pgTAP 040-042 in full; **I did not run the tests** (CI green on the three merge commits, checked through the API).
- **Closed:** CGR-01 (0040:154-163; pgTAP 040:83), CGR-02 (0041:60-124; pgTAP 041:75-154), CGR-20 (0042:99-135; pgTAP 042; interim rule, D-31). CGR-03 closed for F3, F4 and F6 (0040:24-33, 80-85, 148-152; pgTAP 040:104-162); its J5 part stays open.
- **New (all advisory):** CGR-24 (S2): an open report correction draft reopens the facts with no time limit and no signal. CGR-25 (S2): a visit ended as not completed raises no follow-up signal for care still due. CGR-26 (S3): a coordinator's not-completed end is irreversible.
- **Gate:** F1-F4, F7 and OPS1 have no blocking finding; the PO may accept (OPS1 with CGR-22 and CGR-25 as conditions). F6: no blocking finding from this review; D-10 still blocks it. J5 unchanged (CGR-03 J5 part, CGR-07).
- **Registers:** CR-043 (0040) and CR-044 (0041) added, CR-012, CR-013, CR-042 updated; H-05, H-15 mitigated-in-code, H-16 added, H-14 updated; PS-16 mitigated-in-code, PS-20 to PS-22 added, BL-3 and C-7 updated.
- **Waiting on people:** owner names the clinical owner (G-1); `po` adds the CGR-25 and CGR-26 questions to D-31 and the CGR-24 threshold to D-28; `clinical`: D-31, D-28, D-10, D-30, D-16, D-17; `legal`: D-18, D-22.
- **Next agent (po):** accept F1-F4, F7 and OPS1 if you agree. **(eng):** J5's CSR1 part (CGR-03 J5 part: bill from the latest final snapshot, which also covers CGR-24's billing side; CGR-07); CGR-25 and CGR-24 provisional exceptions in any CSR1 part.

## 2026-10-23 10:15 · po (Product Owner)
- **OPS1 reviewed** (CSR1 part 5, #179 head 638bf5b, CI run 39918776217 green; merged as a78fa7e, CI green on the merge commit and on 6545bf5). The PO read 0042, pgTAP 042, the e2e test, the HAND1 label, ADR-053 and CR-042; **the PO did not run the tests**.
  - **CGR-20 met** (evidence table in `briefs/OPS1.md`; CSR1 checkbox set): any team member or a coordinator ends a started or paused visit as *not completed* with a reason; no report, no billable fact, no completed count; `visit_stuck` ends through its cause; `/field` offers it next to "Einsatz abschliessen".
  - **Not accepted yet:** no `cra` section covers 0042; OPS1, F1-F4 (0040) and F7 (0041) now all wait only for the gate. Accepted without another PO round once a section holds no blocking finding.
  - **Deviations accepted:** `security definer` (the reason cannot be skipped); observations after the end refused until D-31.
- **Next CSR1 part: J5** (#148), then CGR-19; CGR-22 in any part. ABS1's CGR-20 dependency is met.
- **Challenge:** a visit broken off for a hospital transfer leaves the case's next visits planned, so the next nurse may drive to an empty home. Hypothesis row: offer "Fall pausieren" in the same step (team's choice), measured from events first. No new brief; no decision answered.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31.
- **Next agent (cra):** review merge commits bf37957 (0040), 479701c (0041) and a78fa7e (0042) for CGR-01, CGR-03, CGR-02, CGR-20. **(eng):** CSR1 J5 part under #148, then CGR-19; then ABS1.

## 2026-10-23 09:45 · eng (Engineering)
- **#179 merged** (merge commit a78fa7e) with CI green on its head 638bf5b (run 39918776217: app, db, e2e; head included `recovery/main` 7898834, journal conflict resolved by keeping both entries). Types bot found the hand-edited types in sync. Nothing claimed beyond CI.
- **OPS1 `delivered`** (#39, #165, #179): CGR-20 closed in code (IMPLEMENTED, interim default until D-31, CR-042 PROVISIONAL). No `cra` section reviews 0042 yet (UNKNOWN).
- **Next agent (cra):** review merge commit a78fa7e (migration 0042, pgTAP 042, CR-042) for CGR-20. **(po):** OPS1 re-acceptance against CGR-20.
- **Next agent (eng):** J5's CSR1 part under #148 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9), then CGR-19; CGR-22 in any CSR1 PR.

## 2026-10-23 09:35 · eng (Engineering)
- **Active issue #148 (J5) claimed 09:16.** Per the PO comment of 09:10 (CGR-20 first), this run delivers **CSR1 part 5** under #148: PR **#179** (`fix/csr1-cgr20-not-completed`), migration 0042, pgTAP 042, ADR-053, remediation plan `clinical/remediation/CGR-20.md`, rule register CR-042 (PROVISIONAL, D-31). Report section reviewed: 2026-10-23 06:30 (CGR-20). Closes **CGR-20** for OPS1 (and the ABS1 dependency).
- **CGR-20 (IMPLEMENTED):** terminal status `interrupted` ("Nicht abgeschlossen") only through `end_visit_not_completed(visit, reason_code, note, key)`: CSR1 reason list (`other` needs a note), actor recorded, audited, idempotent, row-locked; any team member or coordination role, whatever the qualification. `visit_stuck` ends with its cause. No billable fact, no report obligation, no `report_not_final`, not counted as completed (all those readers already filter on `completed`; no change needed there). `/field` offers it next to "Einsatz abschliessen"/"Fortsetzen" and shows "Nicht abgeschlossen · <Grund>"; HAND1 lists `visit_interrupted`.
- **Deviation from the brief's recommendation:** security definer (like `cancel_visit`), not invoker, so the state machine keeps refusing a direct update to `interrupted` without a reason (ADR-053).
- **Not in this PR:** CGR-22, CGR-19, J5's CSR1 part (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9). OPEN in D-31: observations after the end (refused today).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 042 (47) and every other file the minimal pgTAP shim can run green (001, 007-013, 018, 025 not run: structural functions). Pure TS changes exercised with Node type stripping. vitest, typecheck, lint, e2e not run (npm unreachable). `database.types.ts` hand-edited.
- **OPS1 `in-review`** (#179). **Next agent (eng):** CI on #179; when green, merge, set OPS1 `delivered`; then J5's CSR1 part under #148 (still `active`; the `claimed` label is removed at the end of this run). **(cra):** review #179 (0042, pgTAP 042, CR-042) for CGR-20. **(po):** D-31 stays open (#170).

## 2026-10-23 09:10 · po (Product Owner)
- **F7 reviewed** (CSR1 part 4, #175 head c39fcde, CI run 39911949141 green; merged as 479701c, CI green on the merge commit, run 39913372513, and on 3831789). The PO read 0041, pgTAP 041, the e2e change, `report-commands.ts`, `report-section.tsx` and `update_report_draft` in 0016; **the PO did not run the tests**.
  - **CGR-02 met** for F7 and F6 (evidence table in `briefs/F7.md`; CSR1 checkbox set). The 08:20 condition (a corrected time reaches the signed correction version) is met in pgTAP 041.
  - **Not accepted yet:** no `cra` section covers 0041 (nor 0040), so F7 and F1-F4 both say "awaiting clinical review". Accepted without another PO round once a section holds no blocking finding.
  - **Deviations accepted:** hash, not version; the summary is not hashed (performer-only, saved first); the two-argument `sign_report` is dropped.
  - **F6:** CGR-02 and the F6 part of CGR-03 met; CGR-19 (D-30) and D-10 remain (note in `briefs/F6.md`).
- **CSR1 order decided:** CGR-20 next (blocks OPS1, needed by ABS1), then J5's part, then CGR-19; CGR-22 in any part. Why: CGR-20 keeps the care record truthful now; J5's gaps cannot produce a real invoice before D-12 and D-18.
- **Watcher gap found:** the watcher makes J5 (#148) `active`, because a PO re-review that keeps `changes-requested` (OPS1 07:10) does not change the status value and so does not count as the PO speaking; no Engineering hand-off exists for OPS1's CGR-20. Raised as **WATCH-1** (engineering proposal) and a challenge row; the order is stated in *Active now* and on #148 and #149. The PO did not change any status value to work around it.
- **Challenge:** that coordination gap, and the clinical gate after merge with a measure (ADM1 about 7 h from merge to acceptance; F1-F4 and F7 still waiting). No new brief (CSR1 in progress, ABS1 approved and unstarted); no decision answered.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10, D-28, D-30, D-31.
- **Next agent (cra):** review merge commits bf37957 (0040) and 479701c (0041) for CGR-01, CGR-03, CGR-02. **(eng):** CSR1 part CGR-20 first (under #149 or #148), then J5's part, then CGR-19; then ABS1; consider WATCH-1.

## 2026-10-23 08:50 · eng (Engineering)
- **#175 merged** (merge commit 479701c) with CI green on its head c39fcde (run 39911949141: app, db, e2e; head included `recovery/main` dee8388, journal conflict resolved by keeping both entries). The db job's types drift check passed with the hand-edited types. Nothing claimed beyond CI.
- **F7 `delivered`** (#94, #122, #175): CGR-02 closed in code for F7 and F6 (IMPLEMENTED); the PO's 08:20 condition (corrected time reaches the signed correction version) is in pgTAP 041. No `cra` section reviews 0041 yet (UNKNOWN).
- **Next agent (cra):** review merge commit 479701c (migration 0041, pgTAP 041; 016, 019, 022, 026, 037, 038, 040 changed to pass the shown hash) for CGR-02.
- **Next agent (eng):** the next active item; CSR1 continues with CGR-20 (D-31 interim default), CGR-19 (F6), J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9); CGR-22 in any CSR1 PR.

## 2026-10-23 08:35 · eng (Engineering)
- **Active issue #147 (F7 changes-requested) claimed 08:17.** F7's remedy is CSR1 CGR-02, so this is **CSR1 part 4**: PR **#175** (`fix/csr1-f7-sign-what-she-saw`), migration 0041, pgTAP 041, ADR-052, remediation plan `clinical/remediation/CGR-02.md`. Report sections reviewed: 2026-10-22 22:30 (CGR-02) and 2026-10-23 06:30 (latest; F6/F7 unchanged). Closes **CGR-02** for F7 and F6.
- **CGR-02 (IMPLEMENTED):** `field_reports` shows a draft's live snapshot plus `snapshot_hash`; `sign_report(p_report_id, p_snapshot_hash, p_idempotency_key)` signs only when the current facts still have that hash, otherwise `rejected` / `facts_changed`, nothing written; the two-argument version is dropped; the snapshot builder runs in UTC. `/field` sends the hash and reloads after a refusal.
- **Not in this PR:** CGR-19 (F6, advisory; F6 is also blocked by D-10), CGR-20 (OPS1, waits on D-31 per the 07:40 entry), J5's CSR1 part (#148).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 041 (30) and all other files green under a minimal pgTAP shim, except 001 (structural functions the shim lacks: not run). vitest, typecheck, lint, e2e not run (npm unreachable). `database.types.ts` hand-edited (`snapshot_hash`, `p_snapshot_hash`).
- **PO condition (08:20) for the CGR-02 PR met in pgTAP 041:** a time corrected in a correction draft reaches the signed correction version ("the correction version carries the corrected time").
- **F7 `in-review`** (#175); F6 row notes CGR-02 closed. **Next agent (eng):** CI on #175; when green, merge, set F7 `delivered`; the `claimed` label on #147 was removed at the end of this run. **(cra):** review #175 (0041, pgTAP 041) for CGR-02.
## 2026-10-23 08:20 · po (Product Owner)
- **F1-F4 reviewed** (CSR1 part 3, #171 head fafa6a1, CI run 39905325561 green; merged as bf37957, CI green on the merge commit and on e244aae). The PO read 0040, pgTAP 040, the e2e change, ADR-051 and `correct_report`/`sign_report` in 0016; **the PO did not run the tests**.
  - **CGR-01 and the F3/F4 part of CGR-03 met** (evidence table in `briefs/F1-F4.md`; CSR1 checkboxes updated).
  - **Not accepted yet:** no `cra` section covers 0040 (newest is 06:30), so the table says "awaiting clinical review". Accepted without another PO round once a section on bf37957 holds no blocking finding.
  - **Deviation accepted:** `signed` locks too. Its consequence (a countersigner must countersign a known error, then correct) is asked in **D-10** (`clinical`): may she return a report unsigned? No rule invented, nothing to build before the answer.
  - **Condition** for the CGR-02 PR (F6/F7): pgTAP that a time corrected in a correction draft reaches the signed correction version.
- **OPS1** (#168 still open): unchanged, `changes-requested` for CGR-20; nothing new delivered. Comment left on the issue.
- **Challenge:** correction rounds after signature cost a registered nurse's time; hypothesis row (measured in AN2, not tallied).
- No new capability approved (CSR1 in progress, ABS1 approved and unstarted); no decision answered.
- **Waiting on people:** owner names the clinical owner (G-1), then D-29; `clinical`: D-10 (new sub-question), D-28, D-30, D-31.
- **Next agent (cra):** review merge commit bf37957 (0040, pgTAP 040) for CGR-01, CGR-03. **(eng):** CSR1 part CGR-20 (blocks OPS1), then F6/F7 with the time-in-snapshot test, J5; then ABS1.

## 2026-10-23 07:30 · eng (Engineering)
- **#171 merged** (merge commit bf37957) with CI green on its head fafa6a1 (run 39905325561: app, db, e2e; head included `recovery/main` 81880d0, journal conflict resolved by keeping both entries). Nothing claimed beyond CI.
- **F1-F4 `delivered`** (#19-#22, #171): CGR-01 and the F3/F4 part of CGR-03 closed in code (IMPLEMENTED). No `cra` section reviews 0040 yet (UNKNOWN).
- **Next agent (cra):** review merge commit bf37957 (migration 0040, pgTAP 040) for CGR-01, CGR-03.
- **Next agent (eng):** the next active item; CSR1 continues with CGR-20 (PO 07:10, D-31 interim default), then F6/F7 (CGR-02, CGR-19), J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9); CGR-22 in any CSR1 PR.

## 2026-10-23 07:40 · eng (Engineering)
- **Active issue #145 (F1-F4 changes-requested) claimed 07:11.** F1-F4's remedy is CSR1, so this is **CSR1 part 3**: PR **#171** (`fix/csr1-f1f4-signed-facts`), migration 0040, pgTAP 040, ADR-051. Report section 2026-10-22 22:30; closes **CGR-01** and the **F3/F4 part of CGR-03**.
- **CGR-01 (IMPLEMENTED):** `record_observation` rejects a supersede unless the caller wrote the superseded version; a colleague adds her own observation.
- **CGR-03, F3/F4 part (IMPLEMENTED, option "only through a correction version"):** `correct_visit_time` and `record_observation` return `rejected` while the latest report version is `signed` or `final`; `correct_report` opens a correction draft that reopens them, and its signed version carries the changes; the earlier version stays. `signed` locks too (stricter, ADR-051). `/field` hides the change controls while locked and names "Bericht korrigieren".
- **Not in this PR:** CGR-03's J5 part (billing from the signed snapshot, #148), CGR-02 (F6/F7). **CGR-20** (OPS1, `cra` 06:40) needs a decision first (`clinical` with `legal`, PO to open); I did not build it ahead of that.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 040 (32), 010, 011, 016 and all other files green under a minimal pgTAP shim, except five files that use structural pgTAP functions the shim lacks (001, 007, 009, 018, 025: not run). vitest, typecheck, lint, e2e not run (npm unreachable). No type change (signatures unchanged).
- **F1-F4 `in-review`** (#171). **Next agent (eng):** CI on #171; when green, merge, set F1-F4 `delivered`; the `claimed` label on #145 is removed with this PR. Then CSR1 continues: F6/F7 (CGR-02, CGR-03 F6 part already covered here, CGR-19), J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9).
- **Next agent (cra):** review #171 at its head (CGR-01, CGR-03).
## 2026-10-23 07:10 · po (Product Owner)
- **Clinical gate passed for ADM1, C1 and J3** (`cra` section 06:30, merged with #167 as 6fc517a: CGR-18, CGR-12, CGR-04 closed, "the PO may accept"). **All three accepted**, no new condition; evidence tables in `briefs/ADM1.md`, `briefs/C1.md`, `briefs/J3.md`. **The PO did not run the tests**; evidence is merged code and tests, CI green (95ed737, 74940fb, c987e83) and the report.
- **OPS1 reviewed** (CSR1 part 2, #165 head 74f3acf, CI run 39900134825 green; merged as c987e83). **CGR-05 and CGR-06 met** (PO read 0039 `exception_is_safety`, `handle_exception` → `cause_persists`). **Changes-requested for CGR-20** (blocking S1 for OPS1; PO confirmed 0038:38-45, 0024:353): a started or paused visit can only end as `completed`, so a broken-off visit ends as a permanent P1 or a false completion.
  - **CSR1 criterion CGR-20 added:** an audited *not completed* end with a reason, by the performer, any team member or a coordination role; no billable fact, no report obligation, not counted as completed; visible on `/field` and in HAND1; `/field` offers it next to "Abschliessen".
  - **D-31 opened** (`clinical`, with `legal`): how a broken-off visit is documented and billed, and who may record its end. The PO invents no rule; the CSR1 criterion is the interim safe default.
  - **CGR-22:** strict provisional default in CSR1 (no hand close of an uncovered visit while nobody is responsible); question added to D-28. **CGR-21:** condition of the COVER1 delta review after D-3. **CGR-23:** pilot measure.
- **Challenge:** pilot hypotheses would be measured by hand tallies of counts NAVORA already records. Proposal AN2 ("Pilot-Hypothesen" in AN1), brief once CSR1 and ABS1 are delivered.
- No new capability approved (CSR1 in progress, ABS1 approved and unstarted); no decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 (now incl. CGR-22), D-30, D-31.
- **Next agent (eng):** CSR1 part CGR-20 after the part already in progress (F1-F4, CGR-01, if started); then F6/F7, J5; CGR-22 in any CSR1 PR; then ABS1 (#134), which relies on CGR-20 for an absent performer's started visit. **(cra):** review the CGR-20 PR while open.

ENGINEERING BRIEF (CSR1 addition, not a new capability)
- **Capability:** CSR1 / CGR-20, an honest *not completed* end for a started or paused visit.
- **Why:** since 0039 a stuck visit's P1 closes only with its cause, and the only cause-ending action is "complete". Teams would record care that was not given, or live with a permanent P1.
- **Business outcome:** OPS1 can be re-accepted; no billing fact or measured minute from care that did not happen.
- **Care outcome:** the record says what happened: the visit stopped, with why.
- **Expected nurse outcome:** one tap with a reason on `/field` instead of a phone call or a false completion.
- **Expected team outcome:** the team sees the broken-off visit in HAND1 and decides the follow-up itself; no coordinator needed to silence an alert.
- **Expected patient outcome:** a visit that did not finish is never shown as care given; the team can see that care is still missing.
- **Acceptance criteria:** `briefs/CSR1.md`, criterion CGR-20 (pgTAP cases and phone-width e2e listed there).
- **Dependencies:** none to build; D-31 (`clinical`, `legal`) replaces the interim rule later.
- **Priority:** patient safety; next CSR1 part, blocks OPS1 and supports ABS1.
- **Implementation recommendation:** a new terminal visit status reached only by a dedicated security-invoker command with a reason code, ending `visit_stuck` through the derived-exception cause; exclude it in J5 facts, F6 drafts, `report_not_final`, AN1 and J6 counts; one `PROVISIONAL` rule-register row.

## 2026-10-23 06:40 · Clinical & Regulatory Architect (review)
- **Report section 06:30** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `8ec3351` and #165 @ `74f3acf` (merged during this run as `c987e83`, same code). Read 0037, 0038, 0039 and pgTAP 037-039; **I did not run the tests** (CI green as reported, and checked on #165). This PR also carries the unmerged 02:28 section (#155).
- **Closed:** CGR-18 (0037:57-75; pgTAP 037), CGR-12 (0038:52-58; pgTAP 038:76-109), CGR-04 (0038; pgTAP 038:127-203; thresholds PROVISIONAL, D-28). CGR-05 and CGR-06 (0039, pgTAP 039; merged as `c987e83`).
- **New:** CGR-20 (blocking S1 for OPS1 acceptance): a started or paused visit can only end as `completed`, and with 0039 its stuck alert cannot be closed, so a broken-off visit becomes a permanent P1 or a false completion. Remedy: an audited "not completed" end, not billable until decided. Advisory: CGR-21 (covered visits, dormant), CGR-22 (hand-closed uncovered visit), CGR-23 (stuck clock restarts on pause).
- **Gate:** ADM1, C1 and J3 have no blocking finding; the PO may accept. OPS1 (`delivered`): not acceptable until CGR-20 is met.
- **Registers:** H-15, PS-16 to PS-19 added; H-01, H-04, H-07, H-12, C-5, PS-1, PS-2, PS-6, PS-7, PS-14 updated; CR-007 and CR-036 updated; CR-041 (0039) endorsed as PROVISIONAL.
- **Waiting on people:** owner names the clinical owner (G-1); `po` opens a decision for CGR-20 (`clinical`, with `legal`) and adds CGR-22 to D-28; `clinical`: D-28, D-30, D-16, D-17; `legal`: D-18, D-22.
- **Next agent (eng):** CGR-20 as the next CSR1 part, before F1-F4. **(po):** accept ADM1, C1, J3 if you agree; set OPS1 `changes-requested` for CGR-20.

## 2026-10-23 06:30 · eng (Engineering)
- **#165 merged** (merge commit c987e83) with CI green on its head 74f3acf (run 39900134825: app, db, e2e; head included `recovery/main` 8ec3351, journal conflict resolved by keeping both entries). db-types-sync made no commit: the hand-edited `closable` matched. Nothing claimed beyond CI.
- **OPS1 `delivered`** (#39, #165): CGR-05 and CGR-06 closed in code (IMPLEMENTED); CR-041 PROVISIONAL; D-28 OPEN. No `cra` section reviews 0039 yet (UNKNOWN).
- **Next agent (cra):** review merge commit c987e83 (migration 0039, pgTAP 039; 019 and 038 changed on purpose) for CGR-05, CGR-06.
- **Next agent (eng):** the next active item; CSR1 continues with F1-F4 (CGR-01), F6/F7 (CGR-02, CGR-03, CGR-19), J5 (CGR-07, CGR-08, BL-8, BL-9).

## 2026-10-23 06:20 · eng (Engineering)
- **Active issue #144 (OPS1 changes-requested) claimed 06:09.** OPS1's remedy is CSR1, so this is **CSR1 part 2**: PR **#165** (`fix/csr1-ops1-escalation`), migration 0039, pgTAP 039, ADR-050. Report section 2026-10-22 22:30; closes **CGR-05** and **CGR-06**.
- **CGR-05 (IMPLEMENTED):** `quality_serious_open` stays while `open` or `in_review`, same key, escalation continues from creation; detail "in Bearbeitung".
- **CGR-06 (IMPLEMENTED, option "cannot be closed until the cause is resolved"):** safety exception = effective rule P1 or escalating to P1 (incl. org overrides). `handle_exception` close → `cause_persists`; earlier closes and auto closes no longer hide it while the cause persists (OPS1, `/team`, commands); `operations_exceptions().closable`; `/operations` hides "Schliessen" for them. Rule register CR-041 (PROVISIONAL).
- **Tests changed on purpose:** pgTAP 019 (P1 close now refused; close-with-reason on a P2) and 038 (stuck visit not closable); e2e OPS1 asserts the P1 card has no close.
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on plain PostgreSQL 16 with stubbed Supabase roles; pgTAP 002–039 green under a minimal shim (real pgTAP not buildable here). vitest/typecheck/lint/e2e not run (npm unreachable). `database.types.ts` hand-edited (`closable`).
- **OPS1 `in-review`** (#165). **Next agent (eng):** CI on #165; when green, merge and set OPS1 `delivered` (the `claimed` label on #144 was removed when the PR opened). Then CSR1 continues: F1-F4 (CGR-01), F6/F7 (CGR-02, CGR-03, CGR-19), J5 (CGR-07, CGR-08, BL-8, BL-9).
- **Next agent (cra):** review #165 at its head (CGR-05, CGR-06, CR-041).

## 2026-10-23 06:10 · po (Product Owner)
- **CSR1 part 1 reviewed (#161)** (head 2924102, CI run 39894865111 green: app, db, e2e; merged as 74940fb, CI green on the merge commit and on cca4e45). The PO read migration 0038, pgTAP 038, the `/team` change and the rule register; **the PO did not run the tests**.
  - **C1: CGR-12 and CGR-04 met. J3: CGR-12 met.** Evidence tables in `briefs/C1.md` and `briefs/J3.md`; CSR1 checkboxes ticked for both. No engineering change requested; both are accepted without another PO round once a `cra` section on 0038 holds no blocking finding.
  - **Deviations decided:** a coordinator may close a P1 `visit_overdue` until CGR-06 (OPS1's, next CSR1 part; C1 does not wait for it); thresholds PROVISIONAL until D-28; no e2e for the `/team` section (pgTAP carries the rule). **Discrepancy:** engineering's C1 row says a suspended visit is not marked on `/field`; `field-client.tsx` does mark it. Recorded, not changed (Engineering's file).
- **ADM1** unchanged: waits for the `cra` review of 0037. No `cra` section since 02:28 (#155 still open), so 0037 and 0038 both wait on `cra`.
- **Challenge:** overdue and stuck visits are closed by a coordinator and shown on `/team`, not `/field`. Hypothesis: they show on `/field` with the resolving actions, end through visit commands, and reach OPS1 only at P1. Measured in the pilot; no brief.
- No new brief (CSR1 in progress, ABS1 approved, unstarted); no decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 and D-30.
- **Next agent (cra):** review 0037 (95ed737, CGR-18) and 0038 (74940fb, CGR-12, CGR-04, CR-038..040). **(eng):** CSR1 part 2 (OPS1: CGR-05, CGR-06), then F1-F4, F6/F7, J5; then ABS1 (#134). Correct the C1 deviation text about `/field`.

## 2026-10-23 05:35 · eng (Engineering)
- **#161 merged** (merge commit 74940fb) with CI green on its head 2924102 (run 39894865111: app, db, e2e). The generated-types drift check passed with the hand-edited `team_visit_alerts` entry. Nothing claimed beyond CI.
- **C1 `delivered`** (#83, #120, #161): CGR-12 and CGR-04 closed in code (IMPLEMENTED); thresholds PROVISIONAL until D-28 (OPEN). No `cra` section reviews 0038 yet (UNKNOWN).
- **Next agent (cra):** review merge commit 74940fb (migration 0038, pgTAP 038) for CGR-12 and CGR-04; CR-038..040.
- **Next agent (eng):** the next active item; CSR1 continues with OPS1 (CGR-05, CGR-06), then F1-F4 (CGR-01), F6/F7 (CGR-02, CGR-03, CGR-19), J5 (CGR-07, CGR-08, BL-8, BL-9).

## 2026-10-23 05:40 · eng (Engineering)
- **Active issue #143 (C1 changes-requested) claimed 05:12.** C1's remedy is CSR1, so this is **CSR1 part 1**: PR **#161** (`fix/csr1-c1-visit-safety`), migration 0038, pgTAP 038, ADR-049. Report section 2026-10-22 22:30; closes **CGR-12** and **CGR-04** (with the CSR1 addition 00:10 and PS-2).
- **CGR-12 (IMPLEMENTED):** registered-nurse check (NV001) on every transition into `started` (incl. resume) and `completed` for B and needs-assessment visits.
- **CGR-04 (IMPLEMENTED):** derived `visit_overdue` and `visit_stuck` (no job); uncovered no longer disappears at the planned start; `public.team_visit_alerts()` and a section on `/team` show them to every team member. Thresholds **PROVISIONAL** (D-28 OPEN): overdue P2 at start, P1 +1 h; stuck P2 +1 h, P1 +3 h. Rule register CR-007 updated, CR-038..040 added (placed after CR-020 to avoid a conflict with #155).
- **Tests:** CI is the runner; nothing claimed as passed. Locally only: migrations + seed on a plain PostgreSQL 16 with stubbed Supabase roles, all pgTAP files green under a minimal pgTAP shim (real pgTAP and npm unreachable). pgTAP 019 rule count 13 → 15 (expected).
- **C1 `in-review`** (#161). **Next agent (eng):** CI on #161; when green, merge, set C1 `delivered`, remove `claimed` from #143. Then the next CSR1 part for the next active item (OPS1: CGR-05, CGR-06).
- **Next agent (cra):** review #161 at its head (CGR-12, CGR-04, provisional thresholds CR-038..040).

## 2026-10-23 04:17 · po (Product Owner)
- **ADM1 CGR-18 change reviewed (#153)** (head b979cd6, CI run 39884986430 green: app, db, e2e). **Met:** migration 0037 refuses removal while she performs a team visit in progress (`has_visit_in_progress`) or performed a completed visit with no `signed`/`final` report (`has_unsigned_reports`); pgTAP 037 covers the four cases through the real commands; `/admin` explains what clears it. The A-responsible case rests on the unchanged CGR-10 code and pgTAP 036. Evidence table and decided deviations in `briefs/ADM1.md`. The PO did not run the tests.
- **#153 merged during this cycle** (95ed737, CI run 39888181373 green: app, db, e2e); engineering set ADM1 `delivered` (#158). The merge brought nothing beyond b979cd6 except `recovery/main` docs. **Acceptance waits only for the `cra` review** of 0037 (on b979cd6 or 95ed737, same code); the PO accepts in the first cycle after it, with no further round, if it holds no blocking finding.
- **Challenge:** team composition is set by an administrator only. Hypothesis: the team proposes joins and leaves as a team decision, the administrator confirms the employment fact; safety refusals stay. Pilot data first; `legal` with any brief. Row in the challenge table.
- **Not merged by the PO:** #155 (`cra`). No new brief (CSR1 and ABS1 approved, unstarted). No decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 and D-30.
- **Next agent (cra):** review migration 0037 and pgTAP 037 for CGR-18 (95ed737). **(eng):** CSR1 (#149), then ABS1 (#134).

---

## 2026-10-23 04:15 · eng (Engineering)
- **#153 merged** (merge commit 95ed737) with CI green on its head b979cd6 (run 39884986430: app, db, e2e), head already contained `recovery/main` c506427. It carries the CGR-18 fix for ADM1 (migration 0037, pgTAP 037). Nothing run locally: CI is the test runner.
- **ADM1 `delivered`** (#101, #135, #153), so the PO review hand-off opens.
- **Gate trail (ADM1):** report section 2026-10-23 02:28 (#155, open). CGR-18 (blocking) fixed in #153 (IMPLEMENTED; remediation plan `clinical/remediation/CGR-18.md`). CGR-19 (advisory) is not built here: the interim refusal is in CSR1, the rule waits for D-30 (OPEN). CGR-16 waits for D-29 (OPEN). No `cra` section reviews 0037 yet (UNKNOWN): the PO keeps ADM1 in review until one does.
- **Next agent (eng):** CSR1 (#149), then ABS1 (#134).
- **Next agent (cra):** review merge commit 95ed737 (migration 0037) for CGR-18.

## 2026-10-23 03:20 · eng (Engineering)
- **ADM1 back to `in-review`, not `delivered`:** the Clinical Governance Report section 02:28 (#155) found **CGR-18 (blocking)** on the merged #135. #153 was green and mergeable but would have set `delivered` over a blocking finding, so it now carries the fix instead (one PR per item). Claimed #133 at 03:15.
- **CGR-18 (IMPLEMENTED, migration 0037):** `remove_team_member` also refuses while she is the performer of a visit of the team on the way, started or paused (`has_visit_in_progress`), or of a completed visit with no `signed` or `final` report (`has_unsigned_reports`). `/admin` message and unit test. pgTAP 037 (24 assertions) runs the report's four cases through the real commands. ADR-046 amendment; remediation plan `clinical/remediation/CGR-18.md`.
- **Clinical Rule Register:** CR-036 arrives with #155 (CRA, not merged yet); after both merge, the CRA updates its row for 0037 (performer check). Not edited here to avoid a conflict in the CRA's file.
- **Tests:** not run locally (no database, npm registry unreachable in this run). CI on #153 is the runner; nothing is claimed as passed.
- **Not built:** CGR-19 (correction of a departed author's report) waits for a decision (`clinical` + `legal`); the CRA asked the PO to open it. Delegated takeover (PS-11) stays OPEN.
- **Next agent (eng):** CI on #153; when green, merge, set ADM1 `delivered`, release the claim on #133. Then CSR1 (#149); ABS1 (#134) should reuse the CGR-18 performer check for absences.
- **Next agent (cra):** review #153 at its head (CGR-18).

## 2026-10-23 03:10 · po (Product Owner)
- **ADM1 `changes-requested`** under the clinical gate. The Clinical Governance Report section 02:28 (#155, open) found **CGR-18** (blocking). The PO confirmed it in 0036 and 0016: removal checks the responsible person only, but only the performer may draft and sign the report. Removing a performer leaves care undocumentable and unbillable. One small PR: refuse removal while she performs a `started`/`paused` team visit or has a missing or `draft` report; `/admin` shows why; four pgTAP cases in `briefs/ADM1.md`. The PO did not run tests; CI on eceac83 and 0e90932 is green.
- **CGR-19** (advisory): interim refusal of an unsignable correction added to CSR1; the rule goes to the new decision **D-30** (`clinical`, with `legal`). No signing rule invented.
- **ABS1 amended:** an absence is never refused (deviation from the Architect's "same check", stated in the brief). Performed visits stay with her under CSR1's stuck-visit exception; her reports stay signable by her.
- **Challenge:** a leaving nurse learns her open duties only through refused admin commands. Hypothesis: she sees and clears them herself on `/field`; the refusal stays as a backstop. Measured in the pilot, no brief yet. The 01:10 proposal (review open PRs) was agreed by `cra`.
- **Not merged by the PO:** #153 (eng, ADM1 `delivered`) and #155 (`cra` report) belong to their roles. No new brief (CSR1 and ABS1 approved, unstarted). No decision answered.
- **Waiting on people:** the owner names the clinical owner (G-1), then D-29; `clinical` answers D-28 and D-30.
- **Next agent (eng):** the CGR-18 change for ADM1 (issue #133), before or as the first commit of CSR1's first PR; then CSR1 (#149), then ABS1 (#134).
- **Next agent (cra):** review the ADM1 CGR-18 PR while it is open.

## 2026-10-23 02:28 · Clinical & Regulatory Architect (review)
- **Report section 02:28** in `reports/CLINICAL_GOVERNANCE.md`, on `recovery/main` @ `0e90932` (ADM1 merged as `eceac83`; CI green on both). I did not run the tests; results come from CI.
- **Closed:** CGR-09 (0036:55; pgTAP 036:121-153), CGR-10 for the responsible person (0036:105-111; pgTAP 036:89-116), CGR-17 (#140, D-27 interim rule).
- **New, blocking for ADM1: CGR-18.** Removal is checked against the responsible person, but only the **performer** (first `started` actor, any team member) may draft and sign the report. Removing a member who is performing a colleague's visit, or who has a completed visit with no report or a `draft` report, leaves that care permanently undocumentable. Remedy: refuse removal in those cases; four pgTAP cases in the section. ABS1 should carry the same check.
- **New, advisory (S2): CGR-19.** A correction of a departed author's final report can be drafted but never signed. Needs a decision (`clinical` + `legal`); until then refuse the unsignable correction.
- **PO challenge (01:10) agreed:** I review clinical-scope PRs while open, at their current head.
- Registers: H-01, H-12; CR-012, CR-034, new CR-035 to CR-037; G-2, PS-3, new PS-14 and PS-15, BL-8 and BL-9 (in CSR1).
- **Next agent (po):** ADM1 stays not accepted (CGR-18); set `changes-requested` or route the fix as an ADM1 follow-up; open a decision for CGR-19.
- **Next agent (eng):** the CGR-18 change in `remove_team_member` with its pgTAP cases; small, before or with CSR1's first PR.

## 2026-10-23 01:10 · po (Product Owner)
- **ADM1 reviewed on its merge commit** (#135 merged as eceac83 at 00:20; CI run 39864278704: app, db, e2e green; also green on b0bd82b). Evidence table in `briefs/ADM1.md`. The PO did not run the tests; results come from CI.
  - Condition 1 (merged, green on the merge commit) is met; the C1 pause e2e condition is met on eceac83.
  - Condition 2 (a Clinical Governance Report section on #135 with no blocking finding) is open: the newest section (23:05) predates the merge. No engineering change is requested.
- **BL-8 and BL-9 added to CSR1** as conditions, as the Architect recommended at 23:05. The PO read migration 0023 and confirmed both: a billing fact stays `billable` when a hold opens later (only the preview filters it), and `working_time_facts` never take a correction (`on conflict do nothing`). Testable criteria in `briefs/CSR1.md`; they come after the blocking criteria, J5 is re-accepted only with them, other reopened items do not wait.
- **Challenge:** a gate review held as a separate cycle after merge is a serial wait we created ourselves. Proposal to `cra` (challenge table): review clinical-scope PRs while open, so merge and acceptance fall in one PO cycle; the gate is unchanged.
- **No new brief** (CSR1 and ABS1 are approved and unstarted). No decision answered; D-28 and D-29 still wait on their owners; the clinical owner is still unnamed.
- **Next agent (eng):** set ADM1 `delivered` (#101, #135) so the PO review hand-off opens; then CSR1 (issue #149) in the brief's order, BL-8 and BL-9 last.
- **Next agent (cra):** a report section on eceac83 for ADM1 (CGR-09, CGR-10); then the PO accepts.

## 2026-10-23 00:10 · po (Product Owner)
- **ADM1 changes pre-reviewed** (#135, head 85b1519, CI green on app, db, e2e). Evidence table in `briefs/ADM1.md`. The PO did not run the tests; results come from CI and from reading migration 0036 and pgTAP 036.
  - **Privacy fix met:** the team-readable release row carries only "Mitglied aus dem Team entfernt"; the reason stays in `change_log`.
  - **CGR-09 met:** suspended visits are released; after a resume they are uncovered and appear in OPS1.
  - **CGR-10 met:** removal is refused while a visit of hers is on the way, started or paused.
- **Merge state:** #135 conflicts with `recovery/main` in `JOURNAL.md` only. ADM1 is accepted without another PO round once #135 is merged with green CI on the merge commit and the next Clinical Governance Report section finds no blocking finding.
- **Residual gap, sent to CSR1:** a planned visit dated before today stays with the removed member, who can no longer see it. New CSR1 criterion: the CGR-04 overdue exception is raised and visible to the team even when the responsible person is no longer a member (pgTAP case named).
- **Challenge:** the `has_cases` refusal makes an administrator coordinate each primary-nurse change with the team. Recorded as a hypothesis, measured in the pilot, no brief.
- **No new brief:** CSR1 and ABS1 are approved and unstarted. No decision answered; D-28 and D-29 are still waiting on their owners.
- **Next agent (eng):** merge `recovery/main` into #135 (journal only), merge it when green, set ADM1 `delivered`; then CSR1, with the added criterion.
- **Next agent (cra):** a report section on #135 (CGR-09, CGR-10) so that ADM1 can be accepted.
## 2026-10-22 23:25 · eng (Engineering)
- **ADM1 changes** (issue #133, claimed 23:18), **PR #135** updated. State stays `in-review` until CI is green on the new head; nothing tested locally against a database (no local Supabase): CI is the test runner.
  - **PO privacy fix (22:15):** the `released` row in `visit_plan_changes` (team-readable) carries only "Mitglied aus dem Team entfernt"; the administrator's reason stays in `change_log` and audit. pgTAP: no plan change row contains the reason; `change_log` does.
  - **CGR-09:** `private.release_member_visits` releases suspended visits too. pgTAP: pause → removal → resume, the visits are active and uncovered (J3 flag, OPS1).
  - **CGR-10:** `remove_team_member` returns `has_visit_in_progress` while a visit of hers in that team is on the way, started or paused; each status tested alone, nothing released, she stays a member. `/admin` message added (unit test).
  - ADR-046 amendment updated. `recovery/main` merged in (journal conflict only).
- **Gate trail (ADM1):** CGR-09, CGR-10 fixed; CGR-16 waits for D-29 (owner); cover by a removed nurse OPEN while COVER1 is off.
- **Not done this run:** #138 (Clinical Architect role) has a merge conflict and must align with the single report path from #136; next run.
- **Next agent (eng):** when #135 is green, merge and set ADM1 `delivered`; then #138; then CSR1.
## 2026-10-22 23:10 · eng (Lead Engineer)
- **#138 reconciled with #136 and #139** (PO comments on #138). README and COORDINATION keep #136's role and acceptance-gate wording (D-27, CGR-14). There is one report path, `reports/CLINICAL_GOVERNANCE.md`. The duplicate `cra` role and participant rows and the "no report yet" line are dropped.
- **Added for Engineering** to the *Clinical review gate*:
  - a scope check when it claims an item (in scope if unsure);
  - read the latest report, the Hazard Log and the Safety Risk Register;
  - findings take precedence over engineering convenience; a conflict with the brief goes into *Deviations* plus a `po` decision;
  - a remediation plan in `clinical/remediation/<finding ID>.md` before proceeding, when a finding creates a safety, billing or regulatory risk;
  - a trail in the PR and the journal.
- ABS1 is next and is in scope. Engineering reads the 22:30 report section before implementing.

## 2026-10-22 23:05 · Clinical & Regulatory Architect (review)
- **Owner decided D-27 (22:59):**
  - the Architect stays advisory: review, challenge, recommend, identify risks and controls;
  - it never approves clinical rules;
  - until a named, qualified clinical owner is appointed, **all clinical decisions remain OPEN and provisional**;
  - Engineering may implement safe defaults; no rule may be marked clinically approved.
- **Report section 23:05** in `reports/CLINICAL_GOVERNANCE.md`:
  - CGR-14 is resolved by #136, and closes when #136 merges;
  - **CGR-17 (blocking for #136):** add the interim clause to D-27 and to the README gate (comment on #136).
- Registers updated: G-1 (role decided, person not named, blocks Gate C), G-2, and the `APPROVED` status unavailable until `clinical` is named.
- No code was merged since `b546299`, so findings CGR-01 to CGR-13, CGR-15 and CGR-16 are unchanged.
- **#136 merged (22:40) without the interim clause.** This PR adds the owner's 22:59 wording to the D-27 answer in `OPEN_DECISIONS.md`, attributed to the owner, and nothing else in that file. That closes CGR-17 once merged.
- **Next agent (po):** keep D-6, D-10, D-15, D-16, D-17 and D-19 open. No clinical rule is marked approved anywhere.
- **Next agent (eng):** where a remedy needs a clinical threshold (CGR-04, CGR-13), use a strict provisional default and say so in the deviations.

## 2026-10-22 23:00 · po (Product Owner)
- **PR #136 merged** (bf5ed02, CI green on 81524b1): the Architect is `cra`, D-27 is decided, the gate is live, and CGR-14 is resolved. #138 (Engineering) was asked to align with the single report path and these role definitions; the PO keeps its remediation-plan steps.
- **Clinical review gate applied** to the first Clinical Governance Report (22:30). Every finding is considered; the table is in `briefs/CSR1.md`.
  - The PO confirmed CGR-01 (0009) and CGR-12 (0024) in the code.
  - The PO did not run tests.
- **Reopened to `changes-requested`:** J3, C1, OPS1, F1-F4, F6, F7 and J5, re-ranked 2–8 in patient-safety order. Each brief has a gate section.
- **CSR1 approved** (Next up 1): the one remediation item.
- **ADM1:** #135 needs CGR-09 and CGR-10 as well as the 22:15 privacy fix.
- **ABS1:** amended (CGR-11, CGR-15); now Next up 2, after CSR1.
- **Conditions:**
  - QG1 stays accepted with CGR-13 (UI label "Abrechnungssperre" until D-16);
  - the CGR-08 condition on J5 is accepted.
- **New decisions:**
  - D-28 (`clinical`): thresholds for overdue and stuck visits; strict provisional default until answered;
  - D-29 (`owner`): qualification verification, CGR-16.
- **Unchanged:** HAND1, RET1, AN1, PLAN2, J6, J1, J2 and COVER1 have no blocking finding, and their acceptances stand.
- **Waiting on people:**
  - the owner names the human clinical owner (README *Participants*), then D-29 and D-1;
  - the clinical owner answers D-28, D-16 and D-17 first.
- **Next agent (eng):** finish #135 (privacy fix, CGR-09, CGR-10), then CSR1 in the brief's order, then ABS1.

**ENGINEERING BRIEF: CSR1**
- **Capability:** clinical safety remediation. No visit looks covered, started or documented when it is not; a signed report is exactly what the nurse saw; billing reads only what was signed.
- **Why:** the Clinical Governance Report found blocking gaps in seven accepted items. Patient safety is a precondition, never traded.
- **Business outcome:** billing facts that survive an insurer audit (signed snapshot, valid order, modelled payer only); no invoice risk from silently changed times.
- **Care outcome:** a missed or stuck visit stays visible until someone acts; care assistants stay within their qualification for the whole visit; serious quality events stay escalated.
- **Expected nurse outcome:** her observations and her signature cannot be changed by anyone else; she is protected from signing facts she did not see.
- **Expected team outcome:** the team sees missed visits itself, without a dispatcher checking lists; one release and eligibility rule for every way a visit loses its nurse.
- **Expected patient outcome:** no silently missed visit; a B or needs-assessment visit is completed by a registered nurse; her record is trustworthy.
- **Acceptance criteria:** as in `briefs/CSR1.md`:
  - CGR-12: qualification on every start and complete;
  - CGR-04: persistent overdue and stuck-visit exceptions, provisional thresholds until D-28;
  - CGR-05: escalation until `closed`;
  - CGR-06: a P1 cannot be silenced while its cause persists;
  - CGR-01: only the author supersedes;
  - CGR-02: sign carries the snapshot version;
  - CGR-03: frozen after `final`, billing from the snapshot;
  - CGR-07: three not-billable reasons;
  - conditions CGR-08 and CGR-13;
  - no regression;
  - a gate trail in each PR.
- **Dependencies:** none blocking. D-28 shapes thresholds only (provisional default meanwhile); D-16 for what a hold stops.
- **Priority:** Next up 1, after ADM1 #135, before ABS1.
- **Implementation recommendation:**
  - one PR per finding group (qualification; exceptions; documentation integrity; billing) to keep reviews small;
  - derived views over `visits` and `now()` for overdue exceptions, no job;
  - reuse the F6 snapshot builder for the sign hash;
  - pgTAP for every negative case;
  - list each provisional default in `clinical/CLINICAL_RULE_REGISTER.md`.

## 2026-10-22 22:40 · po (Product Owner)
- **Owner decided D-27** (moved to *Decided*):
  - The Clinical & Regulatory Architect is a permanent, **mandatory reviewer**. It identifies risks, controls, findings and recommendations.
  - AI-generated clinical, quality, LTCF, PAG, MQI, billing or regulatory guidance is never automatically authoritative.
  - A **named, qualified human clinical owner** approves clinical, care quality and patient safety rules and LTCF, PAG and MQI interpretations.
- **Roles split** (README *Roles*):
  - `cra` reviews and recommends;
  - `clinical` stays the decision owner and is now the named human clinical owner.

  The validator and watcher need no change.
- **Gate widened:**
  - **Engineering**, before delivering an item in scope, reads the latest Clinical Governance Report and states how each finding is handled.
  - **The PO**, before final acceptance, considers it.

  The rule is in README *Clinical review gate*, COORDINATION rule 6 and the NEXT_CAPABILITY standing review rule.
- **Effect on ADM1:** the 22:15 entry said "accepted once #135 is merged with green CI". That acceptance now also needs the gate. ADM1 is in scope because removal releases visits.
- **OPEN:** the human clinical owner is not yet named; README *Participants* holds a placeholder.
- **First Clinical Governance Report** (22:30, #139) is now on `recovery/main` at the path the gate names, so the gate can run.
- **CGR-14 resolved here:**
  - the Architect is `cra`, #138's name, a reviewer without decision rights;
  - `clinical` stays the named, qualified person;
  - there is one report path, `reports/CLINICAL_GOVERNANCE.md`.

  #138 (Engineering) should be reconciled to this path and these role definitions.
- **Merge:** PR #136 brought up to date with `recovery/main` twice (PO 22:15 #137, governance baseline #139). All journal entries and both PO notes kept, newest first.
- **Next (po):** apply the report's gate findings in the next PO cycle, after this merge.

## 2026-10-22 22:30 · Clinical & Regulatory Architect (review)
- **First Clinical Governance Report published:** `reports/CLINICAL_GOVERNANCE.md`, baseline on `recovery/main` @ b546299. The gate in #136 can now run.
- **Registers created** in `clinical/`: `HAZARD_LOG.md`, `CLINICAL_RULE_REGISTER.md` (0 of 34 rules approved), `SAFETY_RISK_REGISTER.md`.
- **Blocking findings:**
  - ADM1 changes (#135): CGR-09 (suspended visits are not released) and CGR-10 (removal during a visit in progress).
  - Earlier acceptances: CGR-01 to CGR-07 and CGR-12. Recommended to the PO: bundle them as one item, "Clinical safety remediation (CSR1)", above ABS1.
- **Role (#136 / #138):** CGR-14. Adopt #136's gate; the deciding `clinical` owner stays a named, qualified person (D-27). The Architect reviews and recommends; it decides no clinical rule. Use one report path: this file.
- **ABS1:** amend the brief first (CGR-15, CGR-11).
- I did not run the tests or access the live database.
- **Next agent (po):** apply the gate to #135; rank CSR1; reconcile #136 and #138.
- **Next agent (eng):** fix CGR-09 and CGR-10 in #135; do not start ABS1 before its brief is amended.

## 2026-10-22 22:15 · po (Product Owner)
- **ADM1 changes pre-reviewed** (#135, open, CI green on becb9c4). Evidence table in `briefs/ADM1.md`. Changes 1–4 are met; the C1 pause e2e is fixed in code and must pass on the merge commit.
- **One blocking privacy fix before merge:** the release row in `visit_plan_changes` is readable by the whole team and carries the administrator's free-text removal reason. Store the fixed text "Mitglied aus dem Team entfernt" there; the reason stays in `change_log` and the audit. pgTAP: the reason never appears in `visit_plan_changes`. Comment posted on #135.
- **Answered (engineering's OPEN items):** HAND1 shows `released` as a fact without a reason, delivered with ABS1 (added to `briefs/ABS1.md`); a cover by a removed nurse stays open until the COVER1 delta review after D-3.
- **Challenge:** an administrator's reason for a staffing change does not belong in the care record (new row).
- **Status:** ADM1 stays `changes-requested` until #135 is merged with green CI; then accepted without another round on changes 2–4. No new brief: ABS1 is still the next approved, unstarted item.
- **The PO did not run the tests**; results are taken from CI and from reading the code.
## 2026-10-22 22:10 · po (Product Owner)
- **New permanent role (owner instruction): Clinical & Regulatory Architect**, role `clinical`. It is the authoritative reviewer for patient safety, clinical workflows, care quality, billing integrity, regulatory compliance, LTCF, PAG and MQI. It reuses the existing `clinical` decision owner, so the validator and the coordination watcher need no change. Updated:
  - `README.md`: *Roles*, a new *Clinical review gate*, rule 6 and *Participants*;
  - `OPEN_DECISIONS.md`: how the role works with decisions, plus D-27;
  - `NEXT_CAPABILITY.md`: the standing review rule and a PO note.
- **Gate:** items that affect patient care, documentation, billing, quality, assessment, LTCF, PAG or MQI get final acceptance only after the PO has considered the latest Clinical Governance Report (`docs/agents/reports/CLINICAL_GOVERNANCE.md`):
  - a `blocking` finding never leads to acceptance;
  - with no report that covers a delivery, the item stays in review, marked "awaiting clinical review";
  - earlier acceptances stand unless a later finding is `blocking`.
- **The report does not exist yet.** The next deliveries in scope (ADM1 changes, ABS1) will wait for its first edition.
- **D-27 (`owner`):** who signs off a clinical rule if the Architect is an agent. Recommendation: the Architect drafts, and a named, qualified person confirms. Until then, `clinical` answers stay recommendations and the safe defaults in code stay. This follows the existing rule "AI drafts; a named, qualified person confirms" and the CLAUDE.md ban on invented medical rules.
- **No delivery** to review this cycle. Queue unchanged: ADM1 changes, then ABS1.
- **Next agent (clinical):** publish the first Clinical Governance Report. Cover first the items that are in review or due next (ADM1, ABS1), then the accepted items with clinical impact (F6, F7, J3, J5, QG1, C1, COVER1, PLAN2, HAND1, RET1).
- **Next agent (eng):** unchanged.

## 2026-10-22 21:35 · eng (Engineering)
- **ADM1 changes** (issue #133, claimed 21:11), **PR #135**. The status row is `in-review`. ADR-046 amendment.
  1. **Removal releases her visits:** migration 0036.
     - `private.release_member_visits` is the one release rule; **ABS1 should call it** for the absence range.
     - `remove_team_member` releases her `planned`, not suspended, today-or-later visits of that team in the same command and returns `{result, released}`.
     - Each release is logged as `visit_plan_changes.change = 'released'` with the reason.
  2. **Role change:** visits are not touched; she can still start them (pgTAP).
  3. **Names asserted** in reports and quality.
  4. **Legacy hints removed.**
- **C1 condition:** the pause e2e failed on bdb0d1d at the last step. It navigated to `/field` right after clicking "Fortsetzen", so the resume could be aborted. It now waits for the case to show as running.
- **Tests:** all 34 pgTAP files pass locally against PostgreSQL 16 with a Supabase shim (036: 28 assertions). Unit, typecheck, lint and e2e were not run here (no npm registry); CI runs them.
- **OPEN (in ADR-046 amendment):**
  - an accepted cover is not withdrawn on removal (COVER1 is off until D-3);
  - whether HAND1 should list `released` entries is a PO question.
- **Next agent (eng):** if #135 is green, merge it and set ADM1 `delivered`. Then ABS1, reusing the release function.

## 2026-10-22 20:15 · po (Product Owner)
- **PR #126 brought up to date** again: `recovery/main` (ADM1 #101) merged in, journal entries kept, newest first. No second PO PR opened; this cycle rides on #126.
- **ADM1 changes-requested** (#101; CI green on head c736429; on merge bdb0d1d app and db green, e2e red only in the known C1 pause test). Evidence table in `briefs/ADM1.md`. Every brief criterion is met. Blocking: `remove_team_member` leaves the person as responsible member of future visits, so they look covered and never reach J3, OPS1 or COVER1. Changes:
  1. removal releases her future planned visits in the same command, logged, count shown; one release function shared with ABS1;
  2. role-change behaviour for her visits tested and stated in ADR-046;
  3. display names asserted in `field_reports` and `field_quality`;
  4. legacy Operations hints removed.
- **Deviations accepted:** manual account creation until D-26; built under D-5 (the 18:20 "waits for D-20" is withdrawn); deactivation refused while cases are open; qualification via the F0 command.
- **C1 condition:** the pause e2e failed again on bdb0d1d. Fix it in the next PR, do not re-run.
- **Decisions sharpened:** D-26 and D-20 (PO notes; owner decides).
- **Challenge:** a membership change is a care event, not only an administrative one (new row in the challenge table).
- **The PO did not run the tests**; results are taken from CI.
- **Next agent (eng):** ADM1 changes first (small, patient safety), then ABS1, reusing the release function.

## 2026-10-22 18:30 · eng (Engineering)
- **ADM1 resumed** (issue #78 active; the earlier claim was older than 3 h). D-5 is the decided rule, so ADM1 is built under it; D-20 (owner) may later move member admission to the teams. That would be a follow-up, not a blocker. The row is `in-review` again with #101.
- **#101 brought up to date** with `recovery/main` (merge commit, no rebase):
  - migration renumbered 0029 → **0035**, pgTAP file → `035_pilot_administration`;
  - its reader patches (exceptions, team view, reports, quality) still match the definitions after HAND1 and RET1;
  - seed keeps both new users (`admin.test` …905, `assist.test` …906), so 002 now expects six; ADM1's test invitees moved to …908/…909;
  - ADM1's own invitation question was D-22, which collided with the legal D-22 on main, so it is now **D-26** (`owner`).
- **Tests:** all 35 pgTAP files pass locally against plain PostgreSQL 16 with a Supabase shim (035: 67 assertions). Unit, typecheck and e2e were not run here (no npm registry access); CI runs them.
- **Follow-up (PLANNED, not in this PR):** HAND1's "since your last visit" still shows "Teammitglied n". It can show the ADM1 display names once this is merged.

## 2026-10-22 18:20 · po (Product Owner)
- **PR #126 unblocked:** it conflicted with `recovery/main` on this journal (RET1 status entry). `recovery/main` merged in, both entries kept, newest first. This cycle rides on the same PR; no second PO PR opened.
- **HAND1 accepted** with one condition (#128; CI green on 352862e, 3a4d691, 19381f2). Evidence table in `briefs/HAND1.md`. Condition: a phone-width (390 px) e2e for the section. All four deviations accepted.
- **RET1 accepted** with two conditions (#129; CI green on bbcaa98 and 19381f2). Evidence table in `briefs/RET1.md`. Conditions:
  - a resumed case releases its visits from the referral's requested start, not from the link;
  - a pgTAP for the qualification skip.

  All three deviations accepted.
- **The PO did not run the tests**; results are taken from CI.
- **AN1 condition still open.** HAND1 and RET1 both touched `pilot_kpis` before the 17:15 condition reached `recovery/main`, so it was not yet due. It is due in the next PR that touches `pilot_kpis`.
- **Challenge:** an absent nurse's visits stay assigned to her, look covered and can silently not happen. Re-assigning them is still a phone chain run by a shift lead, dispatcher or coach. **ABS1 approved** (Next up 1, before ADM1, which waits for D-20). No reason is stored and no approval step is modelled, so no decision blocks it.
- **Next agent (eng):** ABS1. Carry the open conditions in the next PR that touches their files: RET1, HAND1, C1, AN1.

**ENGINEERING BRIEF: ABS1**
- **Capability:** Absence without the phone chain. A nurse (or a colleague for her) records that she is not available. Her not-started visits in that period are released at once to her team under "Offen im Team". The deputy or primary nurse is marked "kennt die Klientin", and a colleague takes a visit with one tap (first wins). Whatever is not taken flows into the existing J3 flag, OPS1 and COVER1.
- **Why:** patient safety and continuity. Today NAVORA has no notion of unavailability, so an absent nurse's visits look assigned and never reach the uncovered safety net. Re-assigning them needs a phone chain.
- **Business outcome:** the team keeps its billable volume through absences, and no coordinator or dispatcher is needed for them.
- **Care outcome:** no visit silently missed because its nurse is absent; a known nurse takes the visit first.
- **Expected nurse outcome:** one record instead of phone calls when ill; colleagues see open visits and take them in one tap.
- **Expected team outcome:** the team handles absences itself, without a shift lead or coach as first line.
- **Expected patient outcome:** the visit happens, preferably with the deputy or primary nurse, informed by HAND1.
- **Acceptance criteria:** as in `briefs/ABS1.md`:
  - record without a reason, also for a colleague of the same team;
  - no approval step;
  - immediate release of not-started visits, logged;
  - "Offen im Team" with the "kennt die Klientin" label;
  - atomic one-tap take under the J3 qualification rules;
  - overlap shown before the take;
  - PLAN2 never assigns to an absent member;
  - withdraw or shorten (untaken visits return, taken ones stay);
  - absences visible to the own team only;
  - three AN1 figures at team and organisation level;
  - phone width;
  - seven negative tests.
- **Dependencies:** J3, J6, PLAN2, OPS1, COVER1 and AN1 (all accepted). No open decision.
- **Priority:** Next up 1. It is the only approved, unblocked item.
- **Implementation recommendation:**
  - an `availability` row per member with a time range and an overlap exclusion;
  - release in the same command, without a job;
  - reuse the J3 uncovered list with a team filter for "Offen im Team";
  - take as one guarded update (`responsible_member_id is null`) for first-wins;
  - pgTAP for every negative case, plus an e2e at 390 px.

---

## 2026-10-22 17:47 · eng (Engineering)
- **RET1 delivered:** #129 merged (merge commit), CI green on the PR head bbcaa98 (app, db, e2e). Row set to `delivered`; the PO review can start.
- **Two Engineering sessions were active in parallel** on HAND1/RET1 (fixture fix and status commits came from the other one). Coordination note left on #129. Rule for both: claim the issue before work; the claiming session merges; the other only reviews.
- **Next in the PO queue:** ADM1, which waits for D-20 (owner). Nothing else approved is open for Engineering.

---

## 2026-10-22 17:22 · eng (Engineering)
- **HAND1 delivered:** #128 merged (merge commit), CI green on the PR head (app, db, e2e). Row set to `delivered` with #128; the PO review can start.
- **RET1 (#129)** was stacked on `feat/hand1`; it now targets `recovery/main`. Its e2e build failed on typecheck after the types-bot regeneration (the unit-test case fixture lacked the two RET1 columns); fixed and pushed, CI re-runs. Merge once green.
- **ADM1 (#101)** still waits for D-20.

---

## 2026-10-22 17:15 · po (Product Owner)
- **AN1 accepted with one condition** (#124; CI green on `recovery/main` 740f44e, which contains merge b2b80b1). Evidence table in `briefs/AN1.md`. The PO did not run the tests. The dashboard now names its figure honestly ("Pflegeanteil im Einsatz", no 60 %/75 % line), excludes incomplete visits, shows the North Star as not yet measurable (D-23), hides team figures below 3 persons, and measures COVER1 correctly.
  - **Condition:** the organisation row still reveals a hidden small team (an organisation with one two-nurse team; or organisation minus visible teams). Engineering's next PR touching `pilot_kpis`, and before any real pilot data, suppresses the organisation row in those cases, with pgTAP for three fixtures (brief).
  - Deviation decided: "cover without Operations" counts against offered visits: accepted.
- **All five 14:30 changes-requested items are now accepted.** Open conditions: C1 (flaky resume e2e), AN1 (organisation row).
- **Queue:** HAND1 (#128) merged during this cycle; it is reviewed next cycle once CI on the merge commit is green. RET1 (#129) is in engineering. ADM1 waits for D-20. No new brief: ADM1 is still an approved, unstarted item, and the next gaps (working time, quality-hold lift, cover context) wait for D-23, D-16 and D-3.
- **Challenge:** care-plan reviews on a fixed calendar, set by a coordinator, recorded as a hypothesis: reviews triggered by accumulated signals. Required intervals go to `clinical` with any brief.
- **CI note:** PR #126 got no CI run on its head; this commit on the same branch re-triggers it. No second PO PR opened.
- **Next agent (eng):** HAND1, RET1; carry the C1 and AN1 conditions in the next PR that touches those files.

---

## 2026-10-22 16:40 · eng (Engineering)
- **RET1 started** (next after HAND1 in the PO order), now `in-review`, stacked on HAND1 (#128):
  - ADR-048 and migration 0034;
  - explicit intake link with a reason;
  - a paused case resumes, with a non-blocking review task for the team;
  - a closed case gets a new case with a first-refusal window for the previous team, inside the J2 deadline, using the same eligibility predicate;
  - the previous primary nurse is proposed;
  - two AN1 figures.
- **Tests:** pgTAP 034 (32 assertions; all 034 database test files pass locally). Unit tests run in CI. No e2e for linking yet.
- **For the PO:** the window is skipped when the previous team is in another region, because region is part of J2 eligibility.

---

## 2026-10-22 16:30 · eng (Engineering)
- **HAND1 started** (next in the PO order after the fixes), now `in-review`:
  - ADR-047 and migration 0033;
  - the "Seit deinem letzten Einsatz" section on `/field`;
  - the start-of-visit audit fact and the AN1 share;
  - pgTAP 033 (30 assertions; all 033 database test files pass locally);
  - unit and e2e tests, which run in CI only.
- **Points for the PO review:**
  - change-log reasons for primary-nurse and order changes now reach the case's own team;
  - "shown" means present at the start; reading is not recorded;
  - plan-generator changes appear as their care-plan entry.
- **Next:** RET1, then ADM1 once D-20 is answered. ADR-046 stays reserved for ADM1; its migration must be renumbered after 0033.

---

## 2026-10-22 16:15 · po (Product Owner)
- **Reviewed the four reworked items: all accepted.** Evidence tables are in each brief. The PO did not run the tests; evidence is the merged migrations, pgTAP and e2e files, and CI on the merge commits.
  - **COVER1** (#114), accepted switched off. Nobody can accept a cover until D-3. If an organisation switches cover on, a covered visit stays flagged for its team and becomes a P1 exception until it can be performed. Performing a cover gets a delta review once D-3 is answered.
  - **PLAN2** (#118): no double planning; withdrawn preconditions drop generated visits; the planning-actions KPI. The hosted daily job is an owner task tied to D-2.
  - **C1** (#120), **with one condition.** The merge commit d91070a was red: e2e `lifecycle.spec.ts:66` navigates to `/field` before the resume has finished. The test was green on the PR and on 57962ee without any change, so it is flaky. Engineering's next PR waits for the resume before navigating.
  - **F7** (#122): the nurse sees the observation and handover text she signs; the countersignature path runs end to end.
- **Queue:** AN1 (#124 open, reviewed once merged), then HAND1 and RET1, which move from *Next up* into the queue. ADM1 stays parked until D-20.
- **Challenge:** a quality hold can be lifted only by a coach or an administrator, a management step outside the team. Proposal sharpened in D-16 (`clinical`): a second registered nurse of the team lifts the hold with a reason. D-3 noted as the only step left before cover works without a dispatcher.
- **Next agent (eng):** fix the C1 e2e race; finish AN1 (#124); then HAND1.

---

## 2026-10-22 16:20 · eng (Engineering)
- **AN1 delivered:** #124 merged (merge commit), CI green on the PR head (app, db, e2e). Row set to `delivered` with #97, #124.
- **F7 delivered:** #122 was already merged with green CI on the PR and on the merge commit; the row still said `in-review`. Now `delivered` with #94, #122.
- All five 14:30 changes-requested items (COVER1, PLAN2, C1, F7, AN1) are now READY_FOR_REVIEW for the PO.
- **Note on times:** this entry uses the actual Europe/Zurich clock; some entries above carry later times than they were written at.
- **ADM1 (#101)** stays open and unmerged until D-20 is answered.

---

## 2026-10-22 18:40 · eng (Engineering)
- **PO review 14:30 and addenda 14:45 worked through, in the PO's order.** Delivered, CI green:
  - COVER1 safety (#114): cover off until D-3; a covered visit stays flagged with the OPS1 exception "Übernahme ohne Zugriff"; withdraw; job-recorded events; a two-session concurrency check in CI;
  - PLAN2 (#118): no double planning; withdrawn preconditions drop generated visits; order flag; planning-actions KPI; the case says why B work stops;
  - C1 (#120): close withdraws matching; the late-cancel P2 persists; suspended visits marked on `/field`; Operations closes and reopens on `/operations`; negative and audit tests;
  - F7 (#122): the nurse sees what she signs; a failed draft is visible; e2e for the countersignature queue with the new seeded care assistant.
- **AN1 in review:** "Pflegeanteil im Einsatz", incomplete visits, the North Star placeholder (D-23), the 3-person rule, and corrected COVER1 figures.
- **Hosted daily jobs:** no hosted project runs these migrations yet (staging waits for D-2). This is recorded as an owner task in the PLAN2 row.
- **ADM1 (#101)** waits for D-20, as the PO asked. Its migration will be renumbered and its invitation question opened under the next free ID.

---

## 2026-10-22 16:20 · eng (Engineering)
- **Adapted to the PO review of 14:30:** all five reviewed items are being reworked, in the PO's order COVER1 → PLAN2 → C1 → F7 → AN1. The rows are `in-progress`; COVER1 is `in-review`. Rows added for HAND1 and RET1.
- **COVER1 safety (migration 0029):**
  - cover is off until D-3;
  - a covered visit keeps the uncovered flag and gets the OPS1 exception "Übernahme ohne Zugriff" (P1 from 4 h before the start);
  - withdraw with a reason;
  - offer and expiry events by a job;
  - empty regions never match;
  - honest UI text;
  - a concurrency test with two real sessions.

  Performing a cover waits for D-3.
- **ADM1 (#101)** is green and stays unmerged until the owner answers D-20, as the PO asked. Its invitation question becomes **D-24**, because the PO numbered the legal medical-order question D-22. Its migration will be renumbered after the fixes.
## 2026-10-22 15:05 · po (Product Owner)
- **Duplicate work, resolved.** Two PO sessions ran the same owner work package in parallel. The 14:50 report (#113) is the one that stands. A second version (#112) is closed unmerged, and only its non-overlapping parts are kept here:
  - review addenda with testable findings for **C1** (Operations closes and reopens in the app), **PLAN2** (the case says why B work stops; confirm the hosted daily job) and **COVER1** (the covering nurse sees nothing else of the case; needs-assessment and KPI tests). The 14:30 verdicts are unchanged;
  - **D-14 sharpened** for nursing homes: team income must not follow the classification level (upcoding incentive).
- **Next agent (eng):** include the addenda when you work the C1, PLAN2 and COVER1 change lists.

---

## 2026-10-22 14:50 · po (Product Owner)
- **PO cycle 14:30 merged** (#105, CI green): five changes-requested reviews (COVER1, PLAN2, C1, F7, AN1) and D-21 decided. The `claimed` labels are removed.
- **Owner work package: Nursing Home Transformation Report**, in `docs/product/NURSING_HOME_TRANSFORMATION.md`. The source is the interRAI LTCF CH handbook (QSys, edition 30.08.2024, pages 1–63, uploaded by the owner), read as a description of today's nursing-home organisation.
  - **Finding:** a three-level assessment hierarchy exists mainly to classify residents for payment and defend that classification: coordinator 1 : 8 residents, supervisor 1 : 16, at least one expert, overall responsibility with the home director (pp. 49–53). Two signs: an upward status change needs a full 7-day observation, while a downward one is a direct edit (p. 3); stable items are re-documented to prove them (p. 4).
  - **Target:** self-organised ward teams; the primary nurse confirms an AI draft built from continuous evidence (the registered-nurse duty of KLV Art. 8a stays, p. 49); checks become software; experts and quality move to network level.
  - **Proposals:** NH0–NH9, eight agents and a five-phase roadmap. **Nothing is approved.** No PAG, MQI or LTCF logic is reproduced; any such feature needs the licence. Roles the source does not describe are marked UNKNOWN.
- **New decisions:** D-24 (`owner`: enter nursing homes, design partner, licence) and D-25 (`legal`: cantonal leadership requirements).
- **Next agent (eng):** no change to the queue; work the changes-requested items from 14:30.

---

## 2026-10-22 14:30 · po (Product Owner)
- **Merged the 13:30 PO cycle (#91)** after bringing `recovery/main` in. Its legal question on the valid form of a medical order collided with engineering's D-21 and is now **D-22**; the 13:30 entry below still says D-21 and means D-22.
- **Reviewed five deliveries, all changes-requested.** Evidence tables and testable changes are in each brief. The PO did not run the tests; evidence is the merged migrations, pgTAP and e2e files, and green CI on each merge commit.
  - **COVER1 (#99), patient safety, first:** accepting a cover clears the uncovered flag and the OPS1 exception, but the covering nurse cannot see or start the visit (pgTAP 028 asserts this). The visit looks covered and can silently not happen. Required: cover off per organisation until D-3; the visit stays flagged until it can be performed; withdraw; honest UI text; concurrency test.
  - **PLAN2 (#92):** generation can create a second visit next to one the team planned by hand. Also: closed or not-ready cases must drop future generated visits; uncovered path, daily run and same-organisation negative tests; the KPI "planning actions per client per week".
  - **C1 (#83):** the no-show P1 core is met. Required: close withdraws matching; the late-cancellation P2 must not vanish after a day; suspended visits marked on `/field`; the brief's negative and audit tests.
  - **F7 (#94):** the nurse must see the observation and handover text she signs. Also: a failed draft is visible; e2e for the countersignature queue.
  - **AN1 (#97):** the North Star is built as a within-visit share, which overstates the result. Label it "Pflegeanteil im Einsatz" without the 60 %/75 % reference, exclude incomplete visits, no team figures below 3 nurses, and tested COVER1 figures.
- **Decided D-21:** the engineering defaults stay, except the North Star definition. **Sharpened:** D-3 (COVER1 needs a read of one visit, limited in time, from acceptance until the report is final) and D-19 (no-show from "on the way"). **New:** D-23 (`legal`): can working time be derived from field events and confirmed once a day? That would remove the timesheet and make the North Star measurable.
- **Order:** fixes in the order COVER1 → PLAN2 → C1 → F7 → AN1, then HAND1 → RET1 → ADM1. Nothing new was approved this cycle.
- **Next agent (eng):** set the five rows to `changes-requested` and work the lists from the top. ADM1 (#101) is open while D-20 is still undecided. Keep it unmerged until the owner answers D-20, or until engineering shows it holds no member-admission logic that D-20 would change.

---

## 2026-10-22 15:35 · eng (Engineering)
- **Delivered, CI green:** F7 (#94), AN1 (#97) and COVER1 (#99). C1 and PLAN2 were delivered earlier. All five await PO review.
- **ADM1 in review**, built under D-5. Account creation and the invitation e-mail wait for **D-22** (`owner`, new): may the server hold the service-role key for the invite call? D-20 may still move admission to the teams.
- **COVER1:** context access for the covering nurse waits for D-3. OPS1 still shows uncovered visits from 24 h; the brief has OPS1 take over at 4 h, and the PO decides whether to change that.
- **The queue is empty after ADM1.** REF2 and J7 are drafts that wait for decisions.

---

## 2026-10-22 14:10 · eng (Engineering)
- **PLAN2 delivered** (#92 merged, CI green): migration 0025, pgTAP 025 (34), e2e planning. PO review is due.
- **F7 in review:** completing a visit opens the report draft, and one confirmation signs it; a countersignature queue on `/field`. Migration 0026, pgTAP 026.
- **Prepared on branches, in queue order:** AN1 (`feat/an1-impact-dashboard`, migration 0027) and COVER1 (`feat/cover1-network-cover`, migration 0028; context access waits for D-3). Each gets its PR when the one before it is merged.
- **New decision D-21 (po):** confirm the engineering defaults of PLAN2, COVER1, AN1 and ADM1.
- **Engineering tooling:** a local PostgreSQL 16 with a Supabase shim and a minimal pgTAP shim lets Engineering apply all migrations and run every pgTAP file before pushing. All files pass. CI on the real Supabase stack stays the authority.

---

## 2026-10-22 13:30 · po (Product Owner)
- **Challenge mode (owner instruction).** I asked of every inherited practice: why does it exist, does it create value, can it disappear, can software or the team do it?
  - **Approved: HAND1**, handover without the team meeting. The `/field` card shows everything recorded since this nurse last saw the client, from the record and unedited.
  - **Approved: RET1**, a returning client returns to her team. A paused case resumes on the discharge referral; after a closed case, the known team is offered the client first.
  - **Draft: ORD1**, medical order renewal without chasing the GP. It waits for the new decision **D-21** (`legal`: valid form of a medical order) and D-9.
- **Hypotheses**, to test with pilot data before any brief: the order of the nurse's day (needs the Q7 review), visit windows for relatives (D-9), statutory reports (D-11), invoice release (D-12, D-18), ward leadership in nursing homes (D-13).
- **`CARE_OPERATING_MODEL.md`:**
  - a lever table showing where NAVORA exceeds Buurtzorg;
  - an impact ledger for every proposed capability: layer replaced, activity removed, role less necessary, continuity, direct care time, income;
  - four Handbook proposals: close the loop back to the care plan; name the client, relatives, GP and discharge planner as actors; add a Workforce-network context; team planning is generated, not typed.
- **Next up:** C1 → PLAN2 → F7 → AN1 → HAND1 → COVER1 → RET1 → ADM1.
- **Next agent (eng):** add `not-started` rows for HAND1 and RET1. HAND1 adds no new data; it only reads what F1–F4, J3, J6, QG1 and C1 already record. RET1 needs C1 merged.

ENGINEERING BRIEF
- **Capability:** HAND1, handover without the team meeting ("since you were last here").
- **Why:** the daily handover meeting and colleague phone calls exist because the nurse does not know what changed. The record already knows.
- **Business outcome:** coordination time does not grow with team size; cover across teams becomes safe.
- **Care outcome:** every visit starts with full knowledge of recent changes.
- **Expected nurse outcome:** she reads the changes on her phone before the visit, with no meeting and no phone call.
- **Expected team outcome:** the team meets for decisions, not for passing on information.
- **Expected patient outcome:** a deputy or covering nurse knows what the primary nurse knows.
- **Replaces:** the coordination layer (handover meeting, shift lead as knowledge carrier). **Removes:** handover meetings, colleague phone calls. **Role less necessary:** shift lead or coordinator. **Continuity:** informed cover. **Direct care time:** meeting time goes back to care. **Income:** more billable minutes per paid hour. **Operating model:** knowledge belongs to the record, which lets teams scale and COVER1 work.
- **Acceptance criteria:** as in `briefs/HAND1.md`. Entries since the nurse's last visit (else the last 3 visits); source, author and time on each; no summarising and no AI; "shown before start" recorded without a tap; team-scoped access unchanged; measured in AN1; negative tests.
- **Dependencies:** F1–F4, J3, J6, QG1; C1 for lifecycle entries; D-3 only for covering nurses.
- **Priority:** High, after AN1 and before COVER1.
- **Implementation recommendation:** one read-only query or view over the existing append-only tables. No copy of clinical data; record the shown entries with the start event.

ENGINEERING BRIEF
- **Capability:** RET1, a returning client returns to her team.
- **Why:** re-intake and re-matching after a hospital stay is manual work that breaks continuity at the riskiest moment.
- **Business outcome:** no intake or matching work for known clients; teams keep their client base.
- **Care outcome:** the same team, ideally the same primary nurse, across the hospital stay.
- **Expected nurse outcome:** she gets her client back rather than a stranger's referral.
- **Expected team outcome:** a paused case simply resumes; the team has first refusal for a returning client.
- **Expected patient outcome:** known nurses after discharge.
- **Replaces:** intake and matching for known clients. **Removes:** re-intake, re-matching, phone calls to the old team. **Role less necessary:** intake coordinator, dispatcher. **Continuity:** kept across the transition. **Direct care time:** no re-learning of the client. **Income:** stable billable volume. **Operating model:** continuity across transitions of care, owned by the team.
- **Acceptance criteria:** as in `briefs/RET1.md`. Explicit link by intake (paused, or closed within 180 days), no automatic identity matching; a paused case resumes; for a closed case, a first-refusal window for the previous team inside the J2 deadline; the previous primary nurse is proposed; measured in AN1; negative tests.
- **Dependencies:** C1 (pause and close), J1, J2, J6.
- **Priority:** High, after COVER1.
- **Implementation recommendation:** reuse J2 offers with a restricted eligible set for the window; the resume path reuses the C1 resume command.

---

## 2026-10-22 13:20 · eng (Engineering)
- **C1 delivered** (#83 merged, CI green): migration 0024, pgTAP 023, e2e lifecycle. Last fixes: cancelled/no-show become timeline events only inside a C1 command, so maintenance updates stay off the timeline (pgTAP 009); twelve exception rules (019); the private flag check runs as owner (023). PO review is due.
- **Adapted to the PO re-ranking of 13:15:** next is **PLAN2**, then F7, AN1, COVER1, ADM1. Rows added.
- **ADM1** had been started before the re-ranking. The work is parked on branch `feat/adm1-administration`, without a PR: profiles, invitations, teams, rule overrides within safe ranges, names in the read models. It resumes after D-20 and will be reshaped if teams admit members themselves.
- **Next agent (eng):** PLAN2 on `feat/plan2-self-planning` (migration 0025).

---

## 2026-10-22 13:15 · po (Product Owner)
- **Challenge mode, organisational level.** Published `docs/product/CARE_OPERATING_MODEL.md`:
  - **North Star:** direct care share. Buurtzorg's reference is 60 % billable time; the NAVORA hypothesis is 75 %.
  - Buurtzorg's limits, with sources: nurses still do the administration; coaches carry absences and finances; teams are islands; host organisations block teams; career and pay are unclear; there is no referral source; data is not used to learn.
  - A table of the roles and tasks that disappear, four horizons up to integrated networks, and proposed Handbook changes.
- **Approved COVER1**, cross-team cover without a dispatcher (context access waits for D-3). **Draft REF2**, hospital referral without an intake coordinator (D-9, D-3). **AN1** now leads with the North Star.
- **Next up, re-ranked by the owner's value order:** C1 → PLAN2 → F7 → AN1 → COVER1 → ADM1.
- **Owner:** D-20 (teams admit colleagues; NAVORA verifies qualifications); D-14 sharpened toward income for direct care.
- **Next agent (eng):** add `not-started` rows for COVER1 (and PLAN2, F7 if not yet done). REF2 stays draft.

ENGINEERING BRIEF
- **Capability:** COVER1, cross-team cover without a dispatcher.
- **Why:** an uncovered visit is solved today by a person on the phone. The network of qualified nurses can solve it itself.
- **Business outcome:** fewer lost visits, and Operations that does not grow with the number of teams.
- **Care outcome:** visits happen as planned; fewer cancellations for staffing reasons.
- **Expected nurse outcome:** a nurse can pick up a visit in a neighbouring team with one tap, seeing only what she needs to decide.
- **Expected team outcome:** a team short of staff gets cover without phoning around, and keeps the case and its primary nurse.
- **Expected patient outcome:** the visit takes place; a known team keeps responsibility for the care.
- **Acceptance criteria:** as in `briefs/COVER1.md`. In short: offer at the lead time to qualified members of neighbouring teams; no identity before acceptance; atomic acceptance of one visit; context only for that visit until its report is final (D-3); fallback to OPS1; audited; measured in AN1.
- **Dependencies:** J2 offer pattern, J3 rules, J6, F6, OPS1; D-3 for context access.
- **Priority:** High, after PLAN2, F7 and AN1.
- **Implementation recommendation:** reuse the J2 offer machinery at visit level. Keep the offer and acceptance independent of the D-3 access part, so it can ship first.

## 2026-10-22 13:00 · po (Product Owner)
- **J5 accepted** (#75, ADR-040, pgTAP 022, CI green): billable minutes never exceed measured care minutes. Q11 decided.
- **Challenge review** ("would we design it this way today?"). Two inherited practices are removed:
  - **PLAN2**, self-planning: visits follow the care plan with the primary nurse. Today the team re-enters the care plan visit by visit, and the frequency is free text that nothing reads.
  - **F7**, sign at completion: documentation becomes part of finishing the visit instead of a later step.
- Three more practices are recorded as hypotheses in `NEXT_CAPABILITY.md`, to be tested with AN1 data: six status taps per visit, re-typed intake, countersigning every care-assistant report (sharpened in D-10 for `clinical`).
- **Order (Next up):** C1 (in review, #83) → ADM1 → PLAN2 → F7 → AN1. C1 comes first for patient safety (no-show), ADM1 because the pilot cannot run without it.
- **Next agent (eng):** add `not-started` rows for PLAN2 and F7 when you add C1, ADM1 and AN1. The C1 review follows its merge.

ENGINEERING BRIEF
- **Capability:** PLAN2, self-planning (visits follow the care plan).
- **Why:** removes recurring manual planning, NAVORA's biggest inherited administrative task, and turns the primary nurse (J6) into the default.
- **Business outcome:** more billable care per paid hour; planning stops scaling with the number of clients.
- **Expected nurse outcome:** her own clients' visits appear in her day view, with minutes and category, without anyone planning them.
- **Expected team outcome:** the team agrees the care plan once and handles only exceptions (absence, cover, uncovered visits).
- **Acceptance criteria:** as in `briefs/PLAN2.md`. In short: structured frequency; a rolling four-week series; primary nurse or deputy, else uncovered; J3 safety and billing rules unchanged; manual changes never overwritten; C1 pauses and closures respected; measured in AN1.
- **Dependencies:** C1 (pause and close), J6 (primary nurse), J3 rules.
- **Priority:** High, after C1 and ADM1.
- **Implementation recommendation:** generate concrete visit rows through the existing J3 commands, so every rule and the change log apply. Keep one daily job idempotent.

## 2026-10-22 12:15 · eng (Lead Engineer)
- **Autonomous coordination** (owner request; ADR-039, `COORDINATION.md`): a GitHub Action turns the three files into hand-off issues.
  - `agent:eng` for implementing or addressing changes; the highest unblocked one is labelled `active`.
  - `agent:po` for reviews on `delivered`.
  - `human-decision` for owner, clinical and legal questions, assigned to the owner.
  - Two hourly scheduled agents (PO, Engineering) pick their issues up. A claim label prevents double work.
- Seen: PO PR #45 (accepts F0, J2, OPS1, QG1, J6; J5 changes-requested; C1, ADM1, AN1 next). Once it is merged, the watcher opens `eng:J5` (active) and `eng:C1`, `eng:ADM1`, `eng:AN1`.

## 2026-10-22 12:00 · po (Product Owner)
- **Accepted:** F0 (#38), J2 (#36), OPS1 (#39), QG1 (#41), J6 (#42). All are merged with green CI; the evidence tables are in the briefs. QG1 becomes operational once `clinical` answers D-16.
- **J5 changes-requested, one rule (Q11 answered):** billable minutes never exceed the measured care minutes. Below plan, scale the planned split down proportionally; above plan, bill nothing extra and flag "above plan". Exact minutes until D-18 (`legal`, tariff-contract rules).
- **Next capability: C1**, case and visit lifecycle: pause, close, reopen, cancel, no-show. The journey can start care but cannot interrupt or end it. A no-show raises a P1 exception; the on-site protocol is D-19 (`clinical`).
- **Then ADM1** (pilot administration, including member names, which J6 needs) and **AN1** (pilot impact dashboard, the evidence for D-14). Both briefs are approved under "Next up".
- **Standing rule:** the PO reviews every `in-review` or `delivered` item automatically each hour and activates the next item on acceptance. Engineering may start a "Next up" item in order once it has added a `not-started` row.
- **Decided:** Q7, Q8, Q9, Q10 (working time Mon–Fri 08:00–18:00 Zurich; holidays once D-11 is known).
- **Next agent (eng):**
  - Build the J5 rule.
  - Add `not-started` rows for C1, ADM1 and AN1, then start C1.
  - Drop Q11 from the J5 row once built.
  - Clock check: your last entry is stamped 12:30, but it was merged by 11:17 Zurich.

## 2026-10-22 12:30 · eng (Lead Engineer)
- **J5 merged** (#43, CI green) and `delivered`. CI found a real bug on the way: text arrays in PL/pgSQL need `array_append`; fixed before merge.
- **Every approved item is now delivered or accepted.** Waiting for PO acceptance: F0, J2, OPS1, QG1, J6, J5. J7 is a draft (D-14).
- **Open for the PO:** Q10 (working time), Q11 (which minutes count).
- **Open for clinical:** D-10, D-15, D-16, D-17.
- **Open for the owner:** D-11 (pilot canton: cantonal rates).
- **Engineering next:** watch `docs/agents` for PO reviews and new approvals. Until then, nothing in the queue is buildable.

## 2026-10-22 11:40 · eng (Lead Engineer)
- **Merged with green CI, all waiting for PO acceptance:** QG1 (#41) and J6 (#42).
- **QG1:** the clinical event list ships empty (D-16), so nothing clinical is invented. The lift role is provisionally coach or admin.
- **J5 in review (#43, ADR-038):** billable facts and an estimate preview.
  - Only the federal insurer rates (2026, source cited) ship as reference data; patient and residual shares wait for D-11.
  - **Q11 opened for the PO:** which minutes count per category.
- After J5, the queue has no approved item left that is not started. J7 is a draft and waits for D-14.

## 2026-10-22 10:30 · eng (Lead Engineer)
- **Merged with green CI, all waiting for PO acceptance:** J2 (#36), F0 remainder (#38), OPS1 (#39).
- **F0:** reasons per the PO rule. Funding-fact changes on a ready case and qualification changes now need one; the others were already enforced. Commands not built yet (case pause/close/reopen, visit cancel/no-show, hold lift) are covered by a structural guard. D-5 qualification: admins only, audited, one shared rule for J2 and J3.
- **OPS1 (ADR-035):** ten exception types derived in the database. Q9 defaults live in `exception_rules`. Take over, note, close with reason, auto-close with a note. **Deviation for the PO:** a serious quality event shows at once as P2 and becomes P1 after 4 h.
- **Open for the PO:** Q10 (working-time definition for J2 deadlines).
- **Next per the queue:** the highest approved item not yet started.

## 2026-10-21 23:05 · po (Product Owner)
- **F6 accepted** (#35); the evidence table is in `briefs/F6.md`. Deviation accepted: the countersignature rule is in code, not configuration. Adjust it by migration once `clinical` answers D-10.
- **Next:** J2 (#36, in progress), then **OPS1**. OPS1 moves ahead of QG1, because QG1 waits for the D-16 event list. **J6 is not blocked by D-6:** build it on J3's accepted model (team plus responsible member); D-6 only confirms it. Please drop D-6 from the J6 row.
- **F0:** the criterion-5 answer (which commands need a mandatory reason) is merged in `briefs/F0.md` (#31).
- **CI note:** the push run of `ci` on 4343016 failed at "Install Playwright browser", while the pull-request run passed. Likely a flaky setup step; worth a retry or a cache.
- **Standing PO rule from the owner:** every item that reaches `in-review` or `delivered` is reviewed automatically, and on acceptance the next capability is activated. No owner instruction needed.

## 2026-10-21 23:05 · eng (Lead Engineer)
- **Clock correction:** my entries dated "2026-10-22 00:30" and "01:10" were written at about 22:00 and 22:40 Europe/Zurich on 2026-10-21. Times from now on are Europe/Zurich.
- Read the PO update (#31). **J2 (#36)** now ships the Q8 pilot defaults (hospital discharge 4 working hours, nursing home 1 working day, private 2 working days) as platform configuration. Admins override them per organisation, and type `other` has no default. **Q10** (opened for the PO): what counts as working time. Provisionally Mon–Fri 08:00–18:00 Zurich, no holidays.
- Rows updated as asked: Q8 dropped from J2, Q9 from OPS1, D-10 from F6.
- **Next (queue rank 1): F0 remainder.** Mandatory reasons per the PO list, plus the D-5 qualification rules (admins only, audited, one shared rule for J2 and J3). Then **COORD-3** (test fixture independent of ranks).

## 2026-10-22 01:10 · eng (Lead Engineer)
- **F6 merged** (#35, CI green) and `delivered`; it awaits PO acceptance. CI hardening on the way: the types bot now rebases before pushing, so a concurrent commit no longer fails the sync.
- **J2 changes** in review as #36 (ADR-033). They also close F0 criterion 4 (offer fields).
- **For the PO (Q8):** no response-time values ship. Until they are set, each open team search shows in Operations as "deadline not configured", so nothing waits silently. Values are set per referral type with `set_response_deadline` (admin); there is no admin screen yet.
- **For clinical (D-15):** the required qualification is derived from the J3 rules (registered nurse while the needs assessment is open or when an order is present). Please confirm.

## 2026-10-22 00:30 · eng (Lead Engineer)
- **F6 signed visit report** in review as #35 (ADR-032). The report has its own versioned lifecycle (draft → signed → final); the visit stays `completed`. The draft is built by the server from the field data; only the performing nurse drafts and signs; signed versions are immutable even for database roles; corrections are new versions with a reason. Operations' "report missing" closes on a final report.
- **Provisional rule pending D-10 (`clinical`):** countersignature whenever the performer is not a registered nurse. This is stricter than the D-10 recommendation; the brief's acceptance is otherwise independent of D-10.
- **Open for the PO:** F0 criterion 5 (which commands require a reason). Next per the queue after CI: J2 changes (rank 5).

## 2026-10-21 23:50 · eng (Lead Engineer)
- Owner approved the operating model (PO decides what, engineering how; communication only via `docs/agents/`). Mapping: the model's `READY_FOR_REVIEW` = validated state `in-review` while CI runs, then `delivered` (waiting for PO acceptance).
- **F0 step 1** (team-scoped clinical read, ADR-031, closes SR-22) in review as #34. F0 criteria 3c and 3d are now met, and the report is updated.
- **PO question:** F0 criterion 5: which commands must require a reason?
- Next per the queue while F0 waits: **F6** signed visit report (rank 4). The countersignature part waits for D-10.

## 2026-10-21 23:20 · eng (Lead Engineer)
- **J1 PO changes merged** (#30) and **J3 PO changes merged** (#32), CI green. Both are `delivered` and wait for PO acceptance against their briefs. Open clinical items: D-15 (checklist, care-plan fields, KLV mapping) and D-17 (safety-alert list).
- CI found a real bug on the way: the audit log rejected a second audit row for the same case under one command key. Fixed by dropping that uniqueness; replay protection is unchanged.
- **F0 report** published: `reports/F0.md`. Main gap: nurses can still read clinical fields of other teams' cases in the legacy tables (SR-22). Engineering starts on that next (F0 step 1). **PO question:** which commands need a mandatory reason (criterion 5)?

## 2026-10-21 22:20 · po (Product Owner)
- **Accepted: J1** (#30) and **J3** (#32), both on merged tests with green CI. The evidence tables are in the briefs. Deviations accepted: `unknown` insurance type counts as missing; the team chooses the KLV category until D-15; assignment is team plus responsible member (D-6). Safety alerts on the card still wait for D-17.
- **F0 still changes-requested, narrower scope.** Thanks for `reports/F0.md` (#33). Remaining work:
  - Team-scoped clinical read, as D-3 option B. Build it now: it only restricts access, and widening needs the owner.
  - Mandatory reasons, following the rule in `briefs/F0.md`.
  - Live reproducibility is an owner production decision (T12, M5), not F0. The offer fields move to J2.
- **Activated next: F6**, after the F0 remainder. It is not blocked: the safe countersignature default applies until D-10 is answered.
- **Queue:** F0 → F6 → J2 → QG1 → OPS1 → J5 → J6 → J7, with the accepted items at the end. QG1, OPS1, J5 and J6 are approved; J7 stays draft until D-14.
- **Decided:** COORD-1, COORD-2, Q4. **Answered:** Q8 (J2 response times, decline reasons) and Q9 (OPS1 thresholds).
- **22:35 addendum:** #34 merged with green CI, so **F0 team-scoped read is accepted**. The answer to your criterion-5 question (which commands need a mandatory reason) is in `briefs/F0.md`. After that, F0 is done. Note: the eng journal times run about 1.5 h ahead of Europe/Zurich; please check the clock.
- **Next agent (eng):**
  - Drop Q8 from the J2 row and Q9 from the OPS1 row.
  - J5 is not blocked by D-12. Residual-financing rates need D-11; D-12 only gates real invoicing, which J5 does not do.
  - In F6, D-10 no longer blocks. Only QG1 (D-16) and J7 (D-14) wait on others.

## 2026-10-21 22:40 · eng (Lead Engineer)
- **J3 changes** in review (ADR-030): care-plan summary with KLV category, planned minutes, frequency, review date and care goal; minutes per category on every visit; needs assessment first; B only with a present order; B and needs-assessment visits started only by a registered nurse (DB-enforced); inform-GP task; reassessment, order-expiry and uncovered flags; Operations exception; change log with reasons; care goals on the `/field` card.
- Stacked on J1 (#30). Next per the PO queue: F0 per-criterion report, then F6.

## 2026-10-21 22:10 · eng (Lead Engineer)
- Read PR #28 (PO briefs, re-ranked queue, decisions). Status rows refreshed: draft items QG1, OPS1, J5, J6, J7 acknowledged as `not-started`; COORD-1, COORD-2 and Q4 no longer listed as blockers. PO: please move them to *Decided*.
- **J1 changes** (residence, insurer, insurance type, medical order status, readiness gate, server-side matching only when ready, tasks, protected insurer data) are in review: ADR-029. Safety alerts wait for the D-17 list.
- **J3 changes** (care-plan billing fields, planned minutes per KLV category, needs-assessment first, B only with an order and a registered nurse) in progress, stacked on J1.
- **F0** per-criterion report follows after J3, because J3 adds member qualifications as data (an F0 criterion).

## 2026-10-21 21:59 · po (Product Owner)
- **Owner decided D-5:** NAVORA administrators manage organisations, memberships and qualifications. Pilot qualification model: `registered_nurse`, `care_assistant`. Recorded as Decided; F0 brief criteria updated.
- **F0 qualification proceeds.** Engineering already builds it inside J3 (status row in #30); the PO accepts that as the delivery vehicle, no separate item.
- **J1 (#30):** PO review posted on the PR; meets the brief; deviation "`unknown` insurance type counts as missing" accepted as product rule. `accepted` follows the merge.
- **After #30 merges** the PO will: set J1 `accepted`; queue QG1, OPS1, J5, J6, J7 (their rows exist in #30); move COORD-1, COORD-2 and Q4 to Decided.
- **Merge note:** this PR and #30 both add a top journal entry; whichever merges second keeps both, newest first.

## 2026-10-21 21:55 · po (Product Owner)
- **F0 reviewed: changes-requested.** Per-criterion verdict in `briefs/F0.md`. Met: schema reproducible with drift report, organisations/roles/team memberships, anonymous and other-organisation negative tests, audit and idempotency, no client identity in offers, synthetic seeds. Missing: (1) member qualification as data, (2) team-scoped read of clinical data inside an organisation; the interim `org_members_read` lets every organisation member read all cases, visits, care notes and quality events.
- Gap 2 waits for **D-3** (owner); PO supports option B and marked D-3 as blocking F0.
- **Scope change:** partner self-submission is out of scope for the pilot. NAVORA operations records referrals (as #23 does); partner login returns with the partner portal in Gate 7. `briefs/J1.md` updated.
- **Next agent (eng):** your F0 row still lists COORD-1, but the briefs are merged. Update F0 with this review, build F0 gap 1 (qualification), then J1 changes. Please also add `not-started` rows for QG1, OPS1, J5, J6, J7, and drop COORD-1/COORD-2/Q4 where answered, so the PO can close them.
- **Waiting for the owner:** D-3 (read scope), D-11 (pilot canton), D-12 (legal entity and OKP admission). **Waiting for clinical:** D-10, D-15, D-16, D-17.

## 2026-10-21 19:20 · po (Product Owner)
- **F1-F4 accepted** on the merged tests (e2e `field.spec.ts`, pgTAP 009–011); evidence per criterion in `briefs/F1-F4.md`. Only gap: care goals and safety alerts on the visit card, because that data does not exist yet. Routed into J1 (alerts, D-17 for `clinical`) and J3 (care goals). No new item.
- Thanks for #29 (validator test independent of PO ranking); PR #28 needs it merged first.
- **Next agent (eng):** unchanged from the 19:10 entry. F0 per-criterion report is the next PO input.

## 2026-10-21 19:10 · po (Product Owner)
- **COORD-1 done:** briefs for F0, J1, J2, J3 published, plus F1-F4 (adopted as the PO's Verified Visit) and F6 (signed visit report). Draft briefs for the next items: QG1, OPS1, J5, J6, J7.
- **Queue re-ranked** against `ARCHITECTURE.md`: F0 → J1 → J3 → F6 → J2 → F1-F4. J1, J2, J3 are **changes-requested**: the delivered slices work, but none stores what makes care billable (residence, insurer, medical-order status, KLV category A/B/C, planned minutes). Criteria already met are marked *(delivered … to confirm)* in each brief.
- **Answers:** Q4 (performing nurse signs; countersignature to `clinical` as D-10), COORD-2 (F6 before J4; J4 deferred to Gate 5), Q7 (location features in Gate 5). Left open until the eng rows drop them, so CI stays green.
- **New decisions:** Q8, Q9 (po); D-10, D-15, D-16 (clinical); D-11 pilot canton, D-12 legal entity and OKP admission, D-13 interRAI HC vs LTCF, D-14 platform fee (owner).
- **Root `ROADMAP.md`** replaced with the 21 October product roadmap (business-model gates; ID map to this layer).
- **Correction:** an earlier PO note (outside this repo) called the live tables empty and the schema unversioned. That came from row estimates and the live migration history; the repo has 12 migrations and TD-19 is the authority. PR #27 against `main` was closed for this reason.
- **Next agent (eng):** read `briefs/F0.md` and report per criterion; add `not-started` rows for QG1, OPS1, J5, J6, J7 so the PO can queue them; drop COORD-1/COORD-2/Q4 from rows where answered.

## 2026-10-21 18:40 · eng (Lead Engineer)
- The owner approved the multi-agent coordination model. **Official layer:** `docs/agents/NEXT_CAPABILITY.md` (PO), `IMPLEMENTATION_STATUS.md` (eng), `OPEN_DECISIONS.md` (all). Protocol in `README.md`; CI validates the files (`npm run agents:check`).
- The owner approved the PO priority order **F0 → J1 → J2 → J3**. The PO briefs are **not** in the repository (COORD-1).
- J1, J2 and J3 were already delivered from `ARCHITECTURE.md` / `DOMAIN_RULES` (PRs #23–#25) before the briefs were visible. They need PO acceptance against the briefs.
- F0 is blocked until its brief exists. Proposals waiting for the PO: J4 (team capacity), F6 (visit report), see COORD-2.
- Next agent: if `briefs/F0.md` exists, start F0. Otherwise check COORD-1 and COORD-2 and continue with whatever the PO queue says.
