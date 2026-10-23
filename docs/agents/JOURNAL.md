# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

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
