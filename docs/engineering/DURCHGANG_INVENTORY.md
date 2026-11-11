# Durchgang ambulant: inventory of steps 1 to 9 (BD-1)

**Author:** `eng` · **Block:** BD (brief [`docs/agents/briefs/BD.md`](../agents/briefs/BD.md), criterion BD-1 with the amendments of 2026-11-11 02:39 and 04:39) · **Written:** 2026-11-11 05:20 CET · **Read from:** `recovery/main` at `76cef8d` (PO merge #1053).

**What this is:** for each step 1 to 9 of [`PRODUCT_BLOCKS.md`](../product/PRODUCT_BLOCKS.md) §5, column *ambulant*: the screen and the command used, the state read **from the code** (IMPLEMENTED / PARTIAL / MISSING, with file and line), the tests that cover it today, and where the chain breaks. **No code change** in this PR (BD-1). Nothing here is a clinical, tariff or legal rule; where a step needs an undecided rule, the decision is named (BD-6). This inventory proves nothing by itself: the proof is the BD-2 run. Labels: IMPLEMENTED, PLANNED, OPEN, UNKNOWN as in `CLAUDE.md`.

**Not a clinical release.** BD proves a software path, not a clinical release of the flow (CGR-145, CGR-146; brief amendment 02:39).

## 0. Summary

| # | Step (ambulant) | Screen → command | State | First break for BD-2 |
|---|---|---|---|---|
| 1 | Anfrage → Fall → Team übernimmt (J1, J2) | `/intake` (menu item for intake roles) → `record_partner_request`, `convert_partner_request`; `/team` → `decide_matching_request` | IMPLEMENTED | none in the product; **test**: `journey.spec.ts:25` `page.goto("/intake")` breaks G-1 (the menu offers `/intake`); **UXR-155** cue on `/field` MISSING |
| 1b | Abklärungsbesuch → abgeschlossen → Pflegeplan (J3, F1-F4, ASM1) | `/team` «Abklärungsbesuch planen» → `plan_visit` (needs_assessment); `/field` → `depart_visit`, `start_visit`, `complete_visit`; `/team` → `record_assessment`, `confirm_assessment`, `add_care_plan_item` | IMPLEMENTED | the existing journey plans the assessment for **tomorrow** (form default); `/field` offers only «auf heute verschieben» for a future visit (VIS1-4), so the run must plan it for today or move it (UNKNOWN which, see §3) |
| 2 | Tätigkeiten, Qualifikation (QUAL1) | no own screen; asked inside `plan_visit` (0121 backstop), `take_open_visit`, PLAN3 lines, start | **PARTIAL** | **first product break:** the QUAL1 matrix rule runs only in an organisation with `organizations.simulation = true` (0120:51, 0121 `qual_may_perform_in`); **no seeded organisation is a simulation** and no login account exists in one (only pgTAP fixtures 120-122 set it). In Testorganisation A the check is the old `private.may_perform_visit` (CR-007/CR-164) plus ADM2-16 `qualification_missing`. A passing check writes no fact and no screen shows it (`visit_qualification_check` has no caller in `src/`) |
| 3 | PLAN3-Tagesvorschlag | `/team` link «Tagesvorschlag» → `/team/tagesplan` → `set_team_day_proposal`, `propose_day_plan` | IMPLEMENTED (in Testorganisation H in e2e) | the team switch must be set on for Testteam Nord through the screen (PLAN3-10); a proposal only covers visits **without** a responsible member, so the care visit must be planned «Team (noch niemand)» |
| 4 | Entscheid des Teams je Wert (AIG1) | `/team/tagesplan` ticks → `confirm_suggestions`; `/team/vorschlaege` → `confirm_suggestion` | IMPLEMENTED | none known; existing tests reach `/team/tagesplan` and `/visits/<id>` by `page.goto` (G-1 to be met in the BD test) |
| 5 | Einsatz: Losfahren, Start, Ende at 390 px (F1-F4, VIS1) | `/field` (tab «Heute») → `depart_visit`, `start_visit`, `complete_visit` | IMPLEMENTED | QUAL1-17 re-check at start runs only in a simulation organisation (same break as step 2) |
| 6 | Diktat oder strukturierte Eingabe | `/field` observation → `record_observation` (F4, OBS1) | PARTIAL: structured observation IMPLEMENTED, dictation PLANNED (B6) | not required by BD-2 |
| 7 | KI-Dokumentationsentwurf | – | **PLANNED** (path after E-3, B6) | not required by BD-2; listed «nicht nachgewiesen» |
| 8 | Bericht, Rückgabe, Unterschrift (F6, F6R, F7) | `/field` report section → `create_report_draft`, `update_report_draft`, `sign_report`, `return_report`, `countersign_report` | IMPLEMENTED | none known |
| 9 | Abrechenbarer Fakt (J5) oder Stoppfall | `/team` «Abrechnungsvorschau» → «Abrechnungsfakten erzeugen» → `generate_billable_facts(month)` | IMPLEMENTED | **second product break:** a visit started and ended within seconds has measured care minutes ≈ 0, so `build_billable_fact` (0051:212-216) adds `below_minimum` (seeded minimum 10 min) and the fact is **not billable with a non-empty reason list**. BD-2 asks for billable and an empty list. Decision for `po` (§4, Q-BD-1) |

**Where the chain breaks first:** step 2 (QUAL1 runs nowhere a login account exists). Then step 9 (`below_minimum` in a real-time run). Everything else exists and is reachable from a screen; the remaining work in the test is G-1 (no `page.goto` except `/login`) and the stored-fact assertions (§3).

## 1. Steps in detail

### Step 1 — Anfrage → Fall → Matching → Team übernimmt (J1, J2)

- **Screen and command:** Operations opens «Anfragen» (`/intake`) from the menu (`src/lib/auth/nav.ts` item `intake`, check `is_intake_role`). Form «Neue Anfrage» → `record_partner_request`; card «Prüfen und in Fall überführen» → «Fall eröffnen» → `convert_partner_request` (the server opens the team search). The nurse opens «Dein Team» (`/team`, menu and tab «Team»); the offer «Anfrage Teamsuche: …» (no client name) → «Fall übernehmen» → `decide_matching_request`.
- **State:** IMPLEMENTED.
- **Tests today:** e2e `journey.spec.ts` (J1-J3 front half), `intake.spec.ts`, `team-admission.spec.ts`; pgTAP 012, 013, 017, 086, 088.
- **Breaks:**
  - G-1: `journey.spec.ts:25` `page.goto("/intake")` and `:111` `page.goto("/field?datum=…")`. Product not affected: the menu offers `/intake`; `/field` has the day controls (`/field?datum=${nextDay}` links in `field-client.tsx`). Fix is in the BD test (brief amendment 04:39).
  - **UXR-155 (MISSING):** `/field` shows no line when the nurse's team has an offer waiting. The «Zu erledigen» nav (`field-client.tsx:234`, `src/features/field/todo.ts`) has three entries (Entscheid offen, Zurückgegeben, Zur Gegenzeichnung), none for team offers (`team_offers`). Gap fix: own PR with its own e2e test (count + link to `/team`, no client name, absent at 0; brief amendment 04:39). PLANNED.
  - Region: the journey uses Bern West / canton BE (seed Testorganisation A). The pilot regions are Basel-Stadt and Basel-Landschaft (founder direction). Synthetic data, no rule depends on it here; OPEN for `po` whether the BD run should use a Basel region (Testteam Ost is «Basel Pilot» in the seed).

### Step 1b — Abklärungsbesuch → abgeschlossen → Pflegeplan

- **Gate `assessment_first` (CR-002, migration 0014):** `plan_visit` refuses every visit that is not the needs assessment while `cases.needs_assessment_done_at` is null (`20261021000014_care_plan_billable_planning.sql:214-219`). That column is set **only** by the trigger `private.mark_needs_assessment_done` when a visit with `is_needs_assessment` reaches `completed` (same file :52-62). So the gate reads the **completed assessment visit** (J3, F1-F4), **not** ASM1; an ASM1 record alone does not open it (brief amendment 02:39, confirmed from the code). Also used by self-planning (0025) and PLAN2 (0030, 0050).
- **Screen:** `/team` case card «Abklärungsbesuch planen» (`team-client.tsx:1002`); the form disables B and C until the assessment is done (`team-client.tsx:1025-1033`) and pre-fills A 45. `/field` start and complete as in step 5. ASM1: `/team` assessment section (`assessment-section.tsx`) → `record_assessment`, `confirm_assessment` (named nurse), `review_care_plan_against_assessment`; display only, blocks nothing (ADR-123, CGR-81). Care plan: «Leistung hinzufügen» → `add_care_plan_item`.
- **State:** IMPLEMENTED.
- **Tests today:** e2e `journey.spec.ts` (plans the assessment and adds a plan item, does **not** start or complete the assessment visit), `asm1.spec.ts`, `field.spec.ts` (F2 path on seeded visits); pgTAP 014, 025 (`assessment_first`), 100, 101, 107 (ASM1).
- **Breaks:** the plan form's date defaults to tomorrow (`journey.spec.ts:66` reads it); a future visit offers only «auf heute verschieben» on `/field` (VIS1-4, pgTAP 089/093). The BD run has to plan the assessment for today (type today's date) or use «auf heute verschieben»; which one the test uses is an `eng` test choice (§3). Late in the day a slot «today» may lie in the past; whether start is allowed before the planned time: UNKNOWN until the probe run.

### Step 2 — Tätigkeiten, Qualifikation (QUAL1)

- **Code:** `private.qual_check(visit, user)` and `private.qual_may_perform` (0120), `private.qual_may_perform_in` (0121:41-55), backstop trigger on `care_visits` (0121, `qualification_not_allowed`, 42501), start re-check (0121 item 5, `qualification_lapsed`). Screen texts for both refusals: `src/features/qualification/refusals.ts`, `src/lib/commands/result.ts:34-56`.
- **State:** **PARTIAL.**
  - IMPLEMENTED: the matrix check on every assignment path and at start, **in a simulation organisation**.
  - Not active anywhere a person can sign in: `organizations.simulation` has no grant, «set only by a migration or a test fixture» (0120:51-53); `supabase/seed.sql` sets it for no organisation (grep: 0 hits); only pgTAP 120-122 set it. In Testorganisation A the answer is `private.may_perform_visit` (CR-007/CR-164: registered nurse for B and for the assessment) and ADM2-16 `qualification_missing` (0094).
  - MISSING: a positive display of the check (`public.visit_qualification_check` has no caller in `src/`); a stored fact of a passed check (none; the start refusal writes nothing, its audit row is PLANNED in 0121 item 5).
- **Tests today:** pgTAP 094 (ADM2-16), 120, 121, 122; e2e none for the matrix.
- **Break for BD-2:** «the qualification check passes for the planned nurse (QUAL1)» and «step 5 shows the QUAL1 check again at visit start» cannot run in the e2e seed. **Proposed gap fix (PLANNED, own PR, `eng` how; `cra` gate):** a synthetic **simulation organisation** in `supabase/seed.sql` with an operations account, one home-care team, a registered nurse and a care assistant, and evidence written by the synthetic fixture path only (`verified` is fixture-only by D-29, 0120 item 3), labelled synthetic; pgTAP proving the seed org is the only simulation org and that Testorganisation A keeps the fallback (pgTAP 121 already proves the fallback on the seed). Testorganisation A is **not** switched to simulation: that would change every existing e2e path there. What the test can then assert: no refusal on plan and start for the qualified nurse; refusal with its sentence for the care assistant on a category-B or assessment visit; the stored fact is the visit's `responsible_user_id` (the backstop guarantees she passed). A positive «geprüft» line on the screen is a UX question, not BD (OPEN for `po`/`uxa`).

### Step 3 — PLAN3-Tagesvorschlag

- **Screen and command:** `/team` header link «Tagesvorschlag» (`team-client.tsx:150`) → `/team/tagesplan`: team switch (`set_team_day_proposal`, PLAN3-10), date field and «Tag vorschlagen» (`day-plan-client.tsx:197-226`) → `propose_day_plan`. Lines only for visits of that day **without** a responsible member; QUAL1-10 drops a member who may not perform (simulation only, otherwise `needs_rn`, ADR-164 deviation). No client data to any AI service: PLAN3 is a rule-based proposal (D-35 rule A).
- **State:** IMPLEMENTED.
- **Tests today:** e2e `plan3.spec.ts` (Testorganisation H, 390 px; reaches pages by `page.goto`), pgTAP 110-119.
- **Break for BD-2:** the switch is off for Testteam Nord unless the test sets it on through the screen; the care visit must be planned «Team (noch niemand)» (`team-client.tsx:1039`). Other open visits of the same team and day (seed) can appear in the proposal; the test ticks only its own line.

### Step 4 — Entscheid des Teams je Wert (AIG1)

- **Screen and command:** `/team/tagesplan` lines start unticked; ticked lines → `confirm_suggestions` (AIG1-5, CGR-78 (b)); one value at a time on `/team/vorschlaege` → `confirm_suggestion`. Nothing becomes effective without confirmation (AIG1, «KI-Vorschlag ohne menschliche Bestätigung» stop case IMPLEMENTED).
- **State:** IMPLEMENTED.
- **Tests today:** e2e `aig1.spec.ts`, `plan3.spec.ts`; pgTAP 097, 103, 104, 106, 108.
- **Break:** none known. Stored fact to assert: the visit's responsible member equals the confirmed line, and the suggestion is `confirmed` (read under RLS as the nurse, §3).

### Step 5 — Einsatz und Zeiterfassung at 390 px (F1-F4, VIS1)

- **Screen and command:** `/field` (tab «Heute»): card actions → `depart_visit`, `start_visit`, `pause_visit`, `resume_visit`, `complete_visit` (`src/features/visits/commands.ts:19-60`, state machine 0007); field actions only on the visit day (VIS1, 0089/0090). Time correction with reason → `correct_visit_time` (F3). Working day `/work` (WORK1) is not part of BD-2.
- **State:** IMPLEMENTED. QUAL1-17 start re-check: only in a simulation organisation (step 2).
- **Tests today:** e2e `field.spec.ts` (F2 full path, F3, 390 px no horizontal scroll), `vis1.spec.ts`, `vis1-10.spec.ts`, `vis2.spec.ts`, `door.spec.ts`; pgTAP 008-010, 038, 089, 090, 093, 094, 121.

### Step 6 — Diktat oder strukturierte Eingabe

- **State:** PARTIAL. Structured observation on the visit card → `record_observation` (F4, OBS1 authorship) IMPLEMENTED (e2e `field.spec.ts` F4, `obs1.spec.ts`; pgTAP 011, 095, 096). Dictation: PLANNED (B6). Not required by BD-2.

### Step 7 — KI-Dokumentationsentwurf

- **State:** PLANNED (B6, path after E-3). The report draft today comes from the visit data, not from an AI (F7 «Entwurf aus den Einsatzdaten»). Listed «nicht nachgewiesen». D-35 rule A unchanged.

### Step 8 — Bericht, Rückgabe, Unterschrift (F6, F6R, F7)

- **Screen and command:** `/field` report section (`report-section.tsx`) at completion: draft from the visit data → `create_report_draft`/`update_report_draft` → `sign_report` (one confirmation); a care assistant's report → «Zur Gegenzeichnung» for a registered nurse → `countersign_report` or `return_report` (F6R), corrected and signed again. Commands in `src/features/field/report-commands.ts`.
- **State:** IMPLEMENTED.
- **Tests today:** e2e `field.spec.ts` (F6, F7, F6R end to end with `assist.test`); pgTAP 016, 026, 041, 047, 049, 066.

### Step 9 — Abrechenbarer Fakt (J5) oder Stoppfall

- **Screen and command:** `/team` region «Abrechnungsvorschau» (`src/components/billing/billing-preview.tsx`) → «Abrechnungsfakten erzeugen» → `generate_billable_facts(p_month)` (per month, the caller's scope) → `private.build_billable_fact` per final report (0051:142-260). Only a **final** report without an open quality hold gives a fact (0051:175-180; H-05). The fact stores `billable`, `reasons` (non-billable) and `warnings` separately (0022:124-147). The button stays until B8 (UXR-157, brief amendment 04:39).
- **State:** IMPLEMENTED. Per-item billable state on the visit: MISSING, built in B8 (UXR-156), does not block BD.
- **Tests today:** e2e `billing.spec.ts` (button and preview on seeded data, no per-visit assertion); pgTAP 022, 023, 043, 049, 051, 059.
- **Break for BD-2 (`below_minimum`):** billable minutes are the planned minutes scaled down to the measured care time of the signed snapshot (0051:186-205); `below_minimum` is added when they are below the seeded billing rule's minimum (10 min, J5 seed «from the PO brief», 0051:191-192, 215-216). A Playwright run starts and ends a visit within seconds, so the fact is **not billable** with `reasons = {below_minimum}`. See Q-BD-1 (§4). Other reasons the run must avoid: `payer_not_modelled` (insurance type not KVG), `no_insurer`, `no_planned_minutes`, `b_without_valid_order` (any B minutes need the order recorded **before** the visit date, 0051 `order_basis_as_of`; the journey records `present` with a valid-until date at intake; with A and C minutes only, no B order is needed). The warnings `reference_not_validated` (CGR-08) and `scaled_to_measured` are warnings, not reasons.

## 2. Stop cases on the way (BD-4)

| Stop case | Expected | Code | Test today | BD-4 |
|---|---|---|---|---|
| Care visit before the completed assessment visit | refused `assessment_first` | 0014:214-219; screen: B, C disabled before (`team-client.tsx:1025-1033`) | pgTAP 014, 025 | IMPLEMENTED → negative step: pgTAP on the BD case shape, e2e asserts the disabled B/C controls and the label «Abklärungsbesuch planen» |
| B minutes without a valid order | fact not billable, `b_without_valid_order` | 0051 `order_basis_as_of` | pgTAP 022, 049, 051 | IMPLEMENTED → negative step (pgTAP or e2e) |
| Report not final | no billable fact | 0051:175 | pgTAP 022, 043 | IMPLEMENTED → negative step |
| Correction open | no new fact, `report_correction_open` | 0047/0049 | pgTAP 047, 049, 066 | IMPLEMENTED |
| Missing or expired evidence / delegation | assignment and start refused (`evidence_missing`, `evidence_expired`, `delegation_missing`, `delegation_expired`, `qualification_lapsed`) | 0120, 0121 | pgTAP 120, 121, 122 | IMPLEMENTED **in a simulation organisation only**; e2e negative needs the seed org of §1 step 2 |
| No recorded qualification | field actions hidden, server refuses `qualification_missing` | 0094; `src/features/field/qualification.ts` | pgTAP 094; e2e `ohnequal.test` | IMPLEMENTED |
| Overlap | fact before saving, never a refusal (VIS2, PLAN3-16) | 0098, 0118 | pgTAP 098, 119; e2e `vis2.spec.ts` | IMPLEMENTED |
| AI proposal without confirmation | nothing becomes effective | AIG1 | pgTAP 097, 108 | IMPLEMENTED |
| (a) start refused for qualification, (b) evidence lapses while resuming, (e) nursing-home resident without responsible member | UNKNOWN until the Clinical Owner's rule (CGR-154, CGR-155, CGR-159) | – | – | **nicht nachgewiesen**, does not count toward acceptance (brief amendment 02:39) |
| (f) no completed assessment | only the assessment visit plannable | 0014 | pgTAP 014, 025 | IMPLEMENTED; block test B7-T1 missing |
| (g) care-plan review date passed | marker `reassessment_due`, no stop | 0024, 0019 P3 | – | IMPLEMENTED as marker; B7-T2, B7-T3 missing |
| Possible double billing | stop, visible error | – | – | PLANNED (BILL1, B8) |

## 3. What the BD-2 test needs (PLANNED, `eng` how)

- **No `page.goto` except `/login` (G-1):** every step through the shell menu or a control on the previous screen. Today's journey uses `page.goto` twice (`journey.spec.ts:25`, `:111`); the BD test does not copy that.
- **390 × 844 for the nurse's steps (G-2):** `test.use({ viewport })` or a separate context per person; the default project is Desktop Chrome (`playwright.config.ts`).
- **Stored facts (BD-2 «both what the next screen shows and the stored fact»):** no e2e spec reads the database today. Proposal: a small helper that signs in with supabase-js as the same synthetic account (local URL and anon key of the CI stack, RLS applies, no service role) and reads the rows the person may read: `partner_requests`/`cases` (step 1), `care_visits` (`is_needs_assessment`, `status`, `responsible_user_id`), `cases.needs_assessment_done_at` if readable under RLS (else the screen label «Bedarfsabklärung erfolgt», `team-client.tsx:534`), the AIG1 suggestion state, `visit_reports.status`, `billable_facts` (`billable`, `reasons`; policy `scoped_read`, 0022:172). Which columns each role may read under the column grants: UNKNOWN until the helper is written; a column that is not readable is asserted on the screen instead, never by widening a grant. ADR with the BD-2 PR.
- **Fresh data only:** the run creates its own referral (as the journey does); it reads seeded rows only to name the accounts and the team.
- **Today's date:** the assessment visit and the care visit are planned for today (Europe/Zurich) so that `/field` offers start; time slots relative to the run time. UNKNOWN: whether a slot already in the past today can be planned and started (check on the probe branch).
- **Full test on a probe branch first (BD-3):** `repeat/2/bd-full-…`; `recovery/main` carries only the steps proven green.

## 4. Decisions this needs (no rule invented)

| ID | Owner | Question | Today's safe behaviour |
|---|---|---|---|
| Q-BD-1 | `po` (product, test design; `lca` for step 9 if the fact's meaning changes) | Step 9 in a real-time e2e run gives `below_minimum`. Options: (A) the nurse records the real start and end through «Zeiten ansehen und korrigieren» (`field-client.tsx:844`) with a reason (F3, an existing screen path; the corrected times are in the signed snapshot) before signing, so the fact is billable with an empty reason list; (B) the run accepts the documented stop case «not billable, `below_minimum`» as step 9's result and asserts that reason; (C) a test-only clock in the database: **not recommended** (a time source that differs between test and product). `eng` recommendation: (A) for the main path, plus (B) as an extra negative step. | fact not billable, reason visible in the preview (`not_billable`) |
| Q-BD-2 | `po` with `cra` gate | Step 2: a synthetic simulation organisation in the seed for the BD run (§1 step 2) instead of Testorganisation A. `eng` recommendation: yes, as its own gap PR with pgTAP; Testorganisation A unchanged. | QUAL1 matrix untested end to end; fallback CR-007/CR-164 in Testorganisation A |
| Q-BD-3 | `po` | Region of the run: Bern West (seed A, as the journey) or a Basel region (pilot regions). | synthetic, no rule depends on it |

These are proposals for the PO; they become decisions only when the PO records them (README rules 1, 3). Nothing in `OPEN_DECISIONS.md` is changed by this PR.

## 5. Order of the BD PRs (PLANNED, proposal)

1. **This PR:** BD-1 inventory (docs only).
2. UXR-155: «Zu erledigen» line on `/field` for team offers (own e2e test).
3. Q-BD-2 seed simulation organisation (pgTAP), if the PO agrees.
4. BD-2 test with the steps proven to run (1, 1b, 3, 4, 5, 8, 9 per Q-BD-1) on `recovery/main`; the full test on `repeat/2/bd-full-…` naming where it turns red; BD-4 negatives.
5. BD-5: 10/10 `ci-repeat` on the merge commit.
