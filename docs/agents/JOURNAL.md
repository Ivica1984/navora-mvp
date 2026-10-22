# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

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
