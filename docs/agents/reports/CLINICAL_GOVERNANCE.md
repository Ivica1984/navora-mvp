# Clinical Governance Report

**Author:** Clinical & Regulatory Architect (review role; an AI agent, not a licensed clinician) · **Approves clinical rules:** a named, qualified person (D-27) · **Protocol:** `README.md` *Clinical review gate*
**Registers:**
- [Hazard Log](../clinical/HAZARD_LOG.md)
- [Clinical Rule Register](../clinical/CLINICAL_RULE_REGISTER.md)
- [Safety Risk Register](../clinical/SAFETY_RISK_REGISTER.md)

**Editable copy:** NAVORA Clinical Governance Baseline Report (Claude Docs). That copy holds the full narrative; this file holds the binding gate findings.

The newest dated section is the latest report. Earlier sections are never edited; a finding changes status only through a later section.

**Severity:**
- `blocking`: the item is not accepted. The PO sets `changes-requested`, or opens a decision for the owner named in the finding.
- `advisory`: may be accepted as a condition, with the reason recorded.

---

## 2026-10-24 10:26: ADM1-R (0059, CGR-39 fix), AN2 part 3 (0058); D-32 decided by the PO, D-4 provisional rule; COORD5

**Scope:** `recovery/main` @ `11202ef`. Changes since the 06:30 section (open PR #259 at `98541a0`; that PR was not merged, because this role's merge of it was refused by the session's permission control at 10:32 (Europe/Zurich) today, and its content is carried unchanged in this PR):
- **Code merged:** #263 (AN2 part 3: migration `0058_an2_pilot_hypotheses_part3`, pgTAP 060, `/analytics`; ADR-071) as `d386a1b`; #268 (ADM1-R, CGR-39: migration `0059_adm1_cgr39_direction_aware_range`, pgTAP 061, pgTAP 035:188-205 rewritten, `/admin` text; ADR-072; remediation plan `clinical/remediation/CGR-39.md`) as `c1bd8cb`, including AN2-C1 (pgTAP 045 fixture made independent of the hour); #271 (COORD5: decision-issue watcher assigns a person only when a package asks; ADR-073) as `ccfc857`.
- **Docs:** PO cycles 07:10, 08:18, 09:12, 10:11: ADM1 set `changes-requested` for CGR-39 (07:10) and accepted after ADM1-R (09:12); SIG1-9 rewritten (the range fix ships with ADM1); ORD0-1 lower bound changed for CGR-40; my *Clinical impact* blocks copied verbatim into D-31, D-3, D-29, D-30, D-16, D-32, D-15; **D-32 decided by the PO** (option B narrow variant, PROVISIONAL); D-33 opened (`owner`); **D-4 provisional rule decided by the PO**; D-28, D-30, D-16, D-31, D-3, D-15 `awaiting-approval: clinical`; D-22, D-18, D-29, D-9, D-11, D-12, D-33 `awaiting-approval: owner`. `lca` inputs #260, #266, #276. **No `clinical`, `legal` or `owner` decision answered.**
- **Open PRs:** #259 (mine, superseded by this PR); #3 (M2, out of scope). No open engineering or PO PR.

I read 0059 and pgTAP 061 in full, the pgTAP 035 and 045 diffs, the `/admin` and `src/features/admin/rules.ts` diffs, the header and every threshold, window and output column of 0058, the briefs ADM1 (R1-R6), SIG1 (SIG1-9) and ORD0 (ORD0-1), and D-32 and D-4 (*Recommended default*). COORD5 changes issue assignment only (`scripts/agents-coordination/`); no care, billing or health data: out of clinical scope. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `d386a1b`, `c1bd8cb` and `11202ef`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-41 | D-32 (decided by the PO 09:12, PROVISIONAL); SIG2 (PLANNED, no brief yet) | advisory (S2; SIG1-8 stays a go-live condition, so no S1 today) | The recipient rule for delivery outside the app can leave a P1 with **no outside recipient at all**: (a) for `visit_uncovered_hospital` and `visit_uncovered` there is, by definition, no responsible member; (b) colleagues receive it only inside the span of their own planned visits that day, so a P1 raised before the first or after the last planned visit of every colleague (a look-ahead P1 is raised up to 24 h ahead, at any hour; an absence recorded at 06:30 releases visits before anyone's first visit) reaches nobody outside the app; Operations stays in-app only. My 06:30 input also asked for **a step to the whole team when nobody has taken it after the SIG1-5 threshold**; D-32 does not adopt or reject it. SIG1-8 names a watcher only "for every hour in which visits are planned", not for the hours in which a look-ahead P1 can arise. Whether a P1 must be answered at night, and by whom, is `clinical` (D-28): UNKNOWN. | D-32 *Recommended default* items 2 and 6; `briefs/SIG1.md` SIG1-5, SIG1-8; look-ahead semantics 0019:175-178, 0038:91-92, 0059 header item 1 | PO decides (product authority; no response time invented), in the SIG2 brief: (1) when the computed outside recipient set is empty, the SIG1 delivery row records "kein Empfänger ausserhalb der App" and the signal is shown at once to Operations as untaken (no 15-minute wait); (2) state whether the SIG1-5 step goes to the whole team outside the app (my 06:30 recommendation) or only to Operations, and record the choice in D-32; (3) SIG1-8 also names who watches during the hours in which a look-ahead P1 can be raised for the next 24 h of planned visits. pgTAP in SIG2: an uncovered hospital-discharge visit whose window opens when no colleague has a planned visit that day → zero outside recipients, the row says so, Operations sees it untaken at once; a colleague inside her span → one outside recipient; a colleague outside her span → in-app only. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-39 | **closed** (IMPLEMENTED) | 0059 §1: `exception_rules.amount_direction`, required whenever an amount exists (constraint `exception_rules_amount_has_direction`), five look-ahead rules (including `cover_without_access`, which Engineering found beyond my four) and four delay rules, each with the reader line. §2: `private.exception_rule_range`: look-ahead from the default up to 4× (cap 720), delay from the floor (0; `visit_stuck` 1 h) up to the default; priority and escalation never later (unchanged); one check `exception_override_in_range`, used by the command and the reset. §3: existing overrides outside the range deleted with one audit row each naming the old values. pgTAP 061: directions for every amount rule and the insert constraint (19-35); with the 24 h default a hospital visit in 36 h raises no P1, with an accepted 48 h override it does (37-53, 106-113); hospital 12 h, 0 h, P2, 97 h → `out_of_range`, 48 h → `ok`; the same pattern for `visit_uncovered`, `order_expiring`, `team_cancellation_late`, `cover_without_access`; delay rules above the default refused (55-87); `/admin` reads direction and bounds (89-104); reset of two out-of-range overrides, the valid one kept, audited, idempotent, not executable by users (115-137). pgTAP 035:191-196: the inverted assertions are replaced (a test change I named, not a skip). `/admin` text no longer promises the opposite (`src/features/admin/rules.ts` `RULES_INTRO`, `stricterHint`). CI green on `c1bd8cb`. PS-31 closed. Residuals: (1) the bounds (4×, 720, `visit_stuck` floor 1 h) are engineering bounds, not clinical values (D-28); (2) `visit_stuck` can no longer be changed in amount at all (range 1 to 1); that is safe, and the value stays D-28 with CGR-23 |
| CGR-40 | open, advisory (S3); **decided by the PO** 2026-10-24 07:10: ORD0-1 lower bound is the case's creation date, with my pgTAP set; PLANNED in ORD0 | `briefs/ORD0.md` ORD0-1. Closes when ORD0 is merged with that pgTAP green |
| CGR-36, CGR-38 | open, advisory (S2); decided, PLANNED in ORD0 (rank 2), unstarted | no change |
| CGR-37 | open, advisory (S2; S1 if visits are planned when nobody watches); SIG1 PLANNED (rank 1), unstarted; SIG1-9 now met by ADM1-R | `briefs/SIG1.md` SIG1-9; outside delivery decided as D-32 (see CGR-41) |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open, unchanged | CGR-23 unchanged by 0059 (the stuck clock still restarts with each status change) |

### Other changes reviewed (no finding)

- **AN2 part 3 (0058, read-only):** no command, visit, signal or record changes; the only new object is the internal marker table `private.an2_capture_starts` (RLS on, no grants). Thresholds are read from `effective_exception_rules`. The 24 h and 48 h windows of measures 2, 4 and 8 are PO analytics parameters, not care rules (new register row CR-069). Absence measures return no person, reason or date, and absences store no reason (0046 header item 7), so no employee health data reaches `/analytics`. The AN1 suppression is unchanged (CR-067). With CGR-39 closed, the distortion I noted on 06:30 for measure 9 (a lowered threshold) can no longer arise; the measure still uses today's threshold for past visits (ADR-070).
- **AN2-C1 (pgTAP 045):** a fixture fix with an added guard assertion; no assertion weakened.
- **D-4 provisional rule (PO 10:11):** no audit row is deleted or anonymised before the final rule. That is the strictest option for documentation integrity. Clinically neutral on the periods (`legal`).
- **D-32 itself:** the narrow variant, the fixed text, opt-in, test delivery, per-member status and SIG1-8 as a go-live condition all follow my 06:30 input. Apart from CGR-41, no objection.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ADM1 operating rules (accepted after ADM1-R) | **no blocking finding**; CGR-39 closed | – |
| AN2 (accepted 08:18; parts 1-3 merged) | **no blocking finding** | – |
| SIG1 (approved, rank 1, unstarted) | **no blocking finding**; SIG1-9 met | CGR-37 |
| SIG2 / D-32 (decided, no brief) | **advisory** before the SIG2 brief is approved | CGR-41 (S2) |
| ORD0 (approved, rank 2, unstarted) | **no blocking finding** | CGR-36, CGR-38, CGR-40 (all decided) |
| COORD5 (accepted) | out of clinical scope | – |
| J5 (accepted) | unchanged | CGR-31 |
| COVER1 | unchanged; cover stays off (D-3 read, D-17, CGR-21, CGR-28, D-29) | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** decide CGR-41 in the SIG2 brief (empty recipient set, the SIG1-5 step, SIG1-8 hours) and record the choice in D-32.
- **owner:** (1) name the Clinical Owner and a deputy (G-1); six packages wait only on that person (D-28, D-30, D-16, D-31, D-3, D-15). (2) The governance PRs of this role cannot be merged by it in this session (permission control); please merge this PR (it contains #259), or grant the self-merge the role prompt describes, or name who merges.
- **eng:** none new.
- **clinical** (once named): unchanged from 06:30; add for D-28/D-32: whether a P1 raised at night must be answered at once, and by whom (CGR-41).

---

## 2026-10-24 06:30: AN2 parts 1-2 (0056 CGR-35, 0057, pgTAP 057-059); briefs SIG1, ORD0 and SIG1-9 (#258); Clinical impact for D-31, D-3, D-29, D-30, D-16, D-32, D-15

**Scope:** `recovery/main` @ `38b986d`. Changes since the 02:26 section (merged as #244):
- **Code merged:** #243 (AN2 part 1: migration `0056_an2_cgr35_moved_keeps_absence`, pgTAP 057 and 058, ADR-069, ADR-068 addendum; HAND1 and `/team` text) as `56c8756`; #255 (AN2 part 2: migration `0057_an2_pilot_hypotheses`, pgTAP 059, fixtures in 027, 030, 032, 033, 034, 048; `/analytics` "Pilot-Hypothesen"; ADR-070) as `c1c58b3`.
- **Docs:** PO cycles 02:20, 03:10, 04:10, 05:15 (#242, #245, #252, #254): briefs **SIG1** (CGR-37) and **ORD0** (CGR-36, CGR-38) approved 03:10, unstarted; CGR-35 met, DAY-1 accepted (04:10); packages D-31, D-3, D-29, D-30, D-16, D-32, D-15 ask `cra` for *Clinical impact*; `lca` inputs #241, #249, #253, #256; eng journal #250, #257. **No `clinical`, `legal` or `owner` decision answered.**
- **Open PR in scope:** #258 (PO 06:10, docs only): D-28 → `awaiting-approval: clinical`, new acceptance criterion **SIG1-9**, Engineering impact drafted by po for D-28, D-31, D-3, draft recommendations for D-31 and D-3. Read; see CGR-39.

I read 0056 and 0057 in full, pgTAP 057 and 058 (headers and every assertion line) and the assertion list of 059, the app diffs (`team-client.tsx`, `handover/rules.ts`, `absence/rules.ts`, `analytics/hypotheses.ts`), the briefs SIG1 and ORD0, the seven packages, and for CGR-39 0035:524-582, 0019:36-47 and 169-177, 0024:443-447, 492-501, 539-546, and pgTAP 035:185-198. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `56c8756`, `c1c58b3` and `38b986d`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-39 | ADM1 operating rules (accepted; CR-021); SIG1-9 (#258, PLANNED) | **blocking (S1)** | The safe-range check for organisation overrides treats every threshold as a **delay** ("a larger amount means a later signal"). Four rules are **look-ahead windows**, where a larger amount means an *earlier* signal and a smaller one a *later* signal: `visit_uncovered_hospital` (P1, signal when an unassigned visit starts within 24 h), `visit_uncovered` (P2, 24 h), `order_expiring` (P3, 7 days before the end date) and `team_cancellation_late` (P2, a team cancellation less than 24 h before the start). For these the check is inverted. An administrator can set the **P1** hospital-discharge rule to 0 hours: the window `between now() and now()` is then empty and the P1 signal **never fires**. At 0 `team_cancellation_late` also never fires, and `order_expiring` fires only on the end date. A stricter value is refused: the P1 rule cannot go above 24 h, and the others cannot go above twice the default. pgTAP 035 asserts the inversion: 12 h for the P1 rule is `ok` with the label "it can come earlier", and 48 h is refused as "later". The `/admin` text promises "Sicherheitsausnahmen (P1) melden sich nie später als der Standard". **SIG1-9 in #258 repeats the inversion** for `visit_uncovered`: it refuses a value above the default, which is stricter, and still allows 0. No clinician approved any of these values (D-28). | range 0035:526-536 (`max_amount` = default for P1, else 2×; minimum 0), check 0035:577-583; look-ahead semantics 0019:175-177 (`between now() and after_threshold(now(), amount)`), 0024:492, 0024:501 (`valid_until <= today + amount`), 0024:543-546 (`start < cancelled_at + amount`); defaults 0019:37, 39, 45, 0024:446; inverted assertions pgTAP 035:191-196; UI `admin-client.tsx:377-378`; #258 `briefs/SIG1.md` SIG1-9 | The range becomes direction-aware, built with SIG1-9 (product authority; no clinical value is set). For the four look-ahead rules an override may not go **below** the default: `out_of_range` for any lower amount, including 0. A higher amount is stricter and stays allowed, under an engineering upper cap. For delay rules SIG1-9 applies as written. A migration reports and resets, audited, any existing look-ahead override below its default. Fix the `/admin` text. pgTAP: `visit_uncovered_hospital` P1 12 → `out_of_range`, 0 → `out_of_range`, 48 → `ok`; `visit_uncovered` 0 → `out_of_range`, 36 → `ok`; `order_expiring` 0 → `out_of_range`, 14 → `ok`; `team_cancellation_late` 0 → `out_of_range`; replace the inverted assertions 035:193-196, a test change named here, not a skip. **PO: set ADM1 `changes-requested` for this condition, and correct SIG1-9 before SIG1 starts.** |
| CGR-40 | ORD0-1 (approved, unstarted) | advisory (S3) | ORD0-1 refuses a "doctor informed" date **before the task was created**. The task is created when an A/C item is planned without an order (0014:263-266), and that is often after the needs assessment, when the doctor may already have been informed. A team that informed the doctor at the assessment can then only record a later, false date. This fact is the evidence D-22 relies on. | `briefs/ORD0.md` ORD0-1; task creation 0014:263-266, 0025:258, 0030:215 | PO decides (product authority). The lower bound is the case's creation date (or its intake date), not the task's creation. Not in the future stays. pgTAP: a date between case creation and task creation → `ok`; a date before case creation → `rejected`; a future date → `rejected`. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-35 | **closed** (IMPLEMENTED) | 0056 §1: `visit_plan_changes.responsible_absent`, check `not responsible_absent or change = 'moved'`, append-only (0014 trigger). §3: set in `reschedule_visit` **before** the move, server-side, from planned + dated before today (Zurich) + `visit_responsible_absent`; no new parameter. §2: one audit row per move. §4: HAND1 detail and `/team` `last_change`. pgTAP 057:45-66 (flagged move → true, typed reason kept, one row, audit row with command); 057:75 (`/team`); 057:87-90 (withdrawal keeps it); 057:95-104 (past visit without absence and future visit → false); 057:109-126 (no write privilege, no parameter, update and non-move insert refused). CI green on `afd1d11` and `56c8756`. Residuals, all acceptable: (1) HAND1 is again asserted by function text (057:80) plus the unit test `handover-rules.test.ts`, as for CGR-34; (2) `/team` shows the fact only while the move is the visit's **last** change, while HAND1 and the table keep it; (3) moves before 0056 are `false`, and AN2-M8a shows them as "vor Erfassung (nicht gezählt)" |
| CGR-36, CGR-38 | open, advisory (S2); **decided by the PO** 2026-10-24 03:10 (ORD0-1 to ORD0-6, which carry my pgTAP set); PLANNED, unstarted | `briefs/ORD0.md`. Close when ORD0 is merged with green pgTAP. ORD0-1 needs CGR-40 |
| CGR-37 | open, advisory (S2; S1 if visits are planned when nobody watches); **decided by the PO** 2026-10-24 03:10 (SIG1-1 to SIG1-8); PLANNED, unstarted | `briefs/SIG1.md`. SIG1-8 (named watcher for every planned hour) is the interim control and stays a go-live condition until SIG1 and D-32 are built and measured (see D-32 below). SIG1-9 needs CGR-39 |
| CGR-31 | open, advisory (S3; S1 before invoicing) | `lca` 05:45 (#256): rates may follow the provider location or the place of care, and the residence municipality pays; palliative contribution versioned from 1 January 2027. This supports a versioned, re-keyable rate lookup. Remedy unchanged; the key is D-18 |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change; see D-3 below |
| CGR-16, CGR-23 | open, unchanged | see D-29 below; CGR-23 is now measured by AN2 measure 9 (0057) |

### Other changes reviewed (no finding)

- **AN2 part 1, DAY-1-R1-R3 (pgTAP 058):** the guard now covers `now()::date`, `localtimestamp`, `date(now())`, `date_trunc('day', now())` and views, and its patterns are first tested against samples (058:37-42). R2 is the behavioural proof I asked for on 02:26: under a session time zone whose date differs from Zurich, `order_expiring`, `care_plan_review_overdue` and `pause_case` give the Zurich answer (058:78-141). CR-064 note updated.
- **AN2 part 2 (0057, read-only):** no table, command or signal changes. Thresholds are read from `effective_exception_rules`, not invented; rows that depend on them carry "Schwelle wie heute eingestellt (provisorisch, D-28)". `below_minimum` is kept out of the not-billable total and has the fixed D-18 note, consistent with CR-029 under legal review. There is no client, person or free text, only counts, medians and reason codes. The organisation row is hidden when it could point at one or two nurses. This closes a privacy gap in AN1 that the PO named on 2026-10-22 and that was open until now. Notes, no finding:
  (a) measure 9 (`visits_open_past_p1`) uses today's threshold for past visits, because no history of rule values exists. With CGR-39 open, a lowered value would distort it. ADR-070 states the limitation.
  (b) A team row with a base of 1-4 shows its value, flagged "zu wenig Daten", as AN1 does. Inside a team of 3 or more, a single correction or hold can be traced to its visit, but team members already read those records (team-scoped read, D-3 option B). Acceptable for synthetic data. Revisit with D-3's real-data gates.
  (c) the 24 h of measure 12 is a PO analytics parameter, not a care rule.
  New register row CR-067.
- **CGR-35 app text:** fixed text `RESPONSIBLE_ABSENT_NOTE`, the same as CGR-34. It is shown only from the server field.
- **ABS1-C7:** singular notice at n = 1, app text only. CR-065 note updated.
- **SIG1 (approved):** it matches my CGR-37 remedy: a delivery row per recipient, exactly once, taken but not closed (CR-041 unchanged), Operations fallback, no health data, interim control SIG1-8. SIG1-5's 15 minutes is PROVISIONAL and D-28. Apart from CGR-39, I support SIG1-9's purpose: it removes an engineering range that no clinician approved.
- **ORD0 (approved):** matches my CGR-36 and CGR-38 remedies and test sets, except CGR-40. ORD0-4 prompts and does not block, which is consistent with `lca`'s reading that some open-ended B orders are lawful. ORD0-6 shows the 7-day share as evidence, not as a deadline. Agreed.

### Clinical impact for decision packages (cra 2026-10-24 06:30)

As on 02:26, **`po`: please copy each block verbatim into the package's *Clinical impact* section, signed "cra 2026-10-24 06:30 (copied from `reports/CLINICAL_GOVERNANCE.md` by po)".** This is confirmed `cra` input. I am not a licensed clinician, and nothing below is a clinical rule. Every rule named here waits for the Clinical Owner (D-27, G-1).

#### D-31: broken-off visit

- **Hazards by reason code** (H-15, H-16):
  - `client_transferred`: care given before the transfer is not documented, and the case's next visits stay planned (CGR-25), so a nurse may go to an empty home or, worse, nobody resumes care after discharge. A medication given and not recorded can be given twice by the next nurse or the hospital.
  - `client_declined`: a refusal is a clinical observation. It can signal deterioration, pain, conflict or a capacity question. Today only the code exists, with no record of what was refused, and repeated refusals are not visible as a pattern.
  - `nurse_unavailable`: the due care was not given and the client still needs it. This is the case where the follow-up is most time-critical.
  - `started_by_mistake`: no care was given. The risk is that a visit that should have taken place disappears into "interrupted" instead of staying overdue. The required follow-up decision (2a) catches this, so keep it.
  - `other`: free-text note. Hazard: health data in free text (privacy) and no structure for follow-up.
- **(1) Documentation of care given.** Where care **was** given, documenting it is not a free product choice. Clinically, undocumented administration is a medication-safety hazard and breaks continuity. Whether it is a legal duty is `legal` under cantonal record-keeping law; `lca` read ZH GesG § 13, and the canton is D-11. Clinical position: 1b, with `started_by_mistake` and a fixed "keine Pflege erbracht" statement as the only ways to record no report. The content of the short report is for the Clinical Owner.
- **(2) A safe follow-up rule must cover:**
  (a) *Folgeeinsatz geplant* names a real planned visit of the same case (2b's server check); an unchecked statement is the CGR-25 residual.
  (b) *nicht mehr nötig* is a care-plan judgement (the care is no longer needed). The conservative default is a registered nurse. Whether a care assistant may decide it is for the Clinical Owner.
  (c) The expected time to the follow-up per reason is UNKNOWN (`clinical`). AN2 measure 2 (no planned visit within 48 h) is evidence, not a rule.
  (d) `client_transferred`: offer `pause_case('hospital_stay')` (exists) as a follow-up, so the next visits stop being planned on purpose and do not just go overdue.
  (e) CGR-35, now IMPLEMENTED: a move records that the care was missed because the responsible member was absent. In my reading a move is a **plan change**, not evidence that the missed care was given. Whether a missed service (e.g. medication, wound care) must be given the same day, or may wait for the next planned visit, depends on the service and is for the Clinical Owner.
- **(4) Correction of an erroneous end.**
  4b reduces PS-22 but needs limits:
  - it only reverts to the previous status, because a reverted visit that was really over raises `visit_stuck` again;
  - it is refused once a follow-up visit of the decision has started;
  - it voids the follow-up decision, audited;
  - it creates no billable fact (none exists for `interrupted`).

  4c removes the cause of PS-22, a coordinator ending another person's visit, but delays the follow-up signal when the performer is unwell. The stuck signal covers that time, so 4c is acceptable clinically, though weaker on continuity. I prefer 4b with the limits above and today's ending rights.
- **Clinical Owner must approve:** the content of the short report (1b); who may decide *nicht mehr nötig*; follow-up expectations per reason; whether missed care must be made up and when. **`legal`:** whether documenting care given is a legal duty, and billing of partial minutes (3b, with D-18). **`po`:** the correction workflow (4), once the limits above are in.

#### D-3: read scope, including the cover read

- **Is B+cover the minimum for a safe visit?** The PO's list is address, care goals, safety alerts and recent HAND1 entries. Missing, and all present in the schema today: the **services planned for this visit** with category and minutes (from the care plan); whether a **B order is present and valid** for it; **access notes** and **language notes** (`cases.access_notes`, `language_notes`, 0013:46-47); the **emergency contact** (`clients.emergency_contact_*`, column-scoped in 0015:68). The C1 no-show outcome `emergency_contact_informed` (CR-014) cannot be done without the emergency contact. "Safety alerts" **do not exist as structured data**: D-17 is not started. The cover read cannot include them until then, which is why PS-12 already needs D-17 before cover is enabled. Superfluous: insurer, billing, order details beyond present/valid, the case's other visits and its full history. How the covering nurse identifies the client at the door is `clinical` (UNKNOWN).
- **Hazards of a cover without the read** (PS-12, S1 if enabled): a B service performed without knowing the order or care goal; no emergency contact on a no-show; access failure; language barrier. Each is a missed or unsafe visit.
- **Do CGR-21, CGR-28 and the `accept_cover` absence check close the known cover hazards?** They close the *signal* hazards: alerts reach the covering nurse, an absence ends her covers, and an absent nurse cannot accept. They do not close the *context* hazard above (D-17 and the read) or the *qualification* hazard: CR-025 limits B covers to a registered nurse, but that rests on an unverified label (D-29, CGR-16). Before cover is enabled, all of D-3 (read), D-17, CGR-21, CGR-28 and D-29 are needed.
- **Clinical Owner must approve:** the field list of the cover read, as clinical minimum content; D-17 (what a safety alert is). The legal basis of the read is `lca`/`legal`. The role matrix itself is `owner`.

#### D-29: verification of qualification

- **What the qualification gates today** (IMPLEMENTED, all UNVALIDATED rules):
  - needs assessment by a registered nurse (CR-002);
  - B and needs-assessment visits started, resumed and completed by a registered nurse (CR-007, every transition since 0038);
  - a team with a registered nurse for a case without an assessment or with an order (CR-008);
  - countersignature by a registered nurse when the performer is not one (CR-011, D-10);
  - B covers only by a registered nurse (CR-025);
  - a downgrade releases her B and assessment visits (CR-052);
  - the matching filter "verified qualification" has the name only (0011).
- **Hazard of an unverified or lapsed qualification:** every gate above trusts a label. A wrong `registered_nurse` label means B care (treatment and examination services) by a person who may not be qualified for it. It also means signatures and countersignatures that attest nothing, and B billing that may be invalid (`legal`). That is H-04, S1 for real clients.
- **Granularity (question for the Clinical Owner and `legal`):** `care_assistant` puts every non-registered member in one class. In Swiss practice that class covers qualifications with very different scopes. Whether NAVORA needs finer qualification classes before CR-010 (care-assistant scope for A) and D-15 can be answered is UNKNOWN. I name no classes.
- **Must a suspension release planned visits immediately?** Yes, as a safety default, through the existing one release rule (CR-051 and CR-052): planned visits are released and appear uncovered (signal), and visits in progress keep her with `visit_stuck`. A suspension that leaves her planned B visits in place recreates H-04. Whether a qualification can **expire** depends on Swiss law (diploma, registration, cantonal practice licence): `lca`/`legal`, UNKNOWN.
- **Clinical Owner must approve:** the mapping of qualification to service (CR-007, CR-010, CR-011, CR-025) and any finer classes. The evidence process (A-D) is `owner`/`legal`. Clinically, C (register check with suspension) or B (second-person check) are safer than D, because the evidence stays in the audit trail.

#### D-30: correcting a report when its author left

- **Hazards.** *A wrong record staying in force* (option A): a wrong observation or a missing administration misleads the next nurse, the doctor and later readers. This is a continuity hazard, and the stranded draft of PS-15 adds a permanent, unresolvable signal. *A correction signed by someone who did not see the visit* (B): the corrected version looks authoritative but attests to facts the corrector did not observe. This is a false-attestation hazard, worse than a visible error if readers cannot tell.
- **Clinical authorship vs administrative fields** (input for C; the Clinical Owner approves the classification): observations, care given and services performed, the narrative summary, and assessment findings are clinical authorship, by the author only. Payer data is administrative. The KLV category split is clinical-billing (D-15). Times are evidence of care and also billing data; they are best corrected by the author, or by another person only from a documented source, recorded as such.
- **Does D (addendum) suffice for clinical safety?** Yes, if three conditions hold:
  1. the addendum is shown **with** the report wherever the report is read (`/field`, HAND1, any export) and marked at the top;
  2. it names its author, and the source when it relays the former author (E′);
  3. it cannot alter the original.

  D does not fix billing, but that is not a safety question. My recommendation to the Clinical Owner: D for clinical content, C for administrative fields, and a team registered nurse may withdraw the stranded draft of PS-15 with a reason, audited.
- **Clinical Owner must approve:** the field classification; whether an addendum by a non-author may state clinical facts (hearsay) and how they are marked.

#### D-16: quality events, holds, lift

- **Are the provisional types and the serious threshold safe interim values?** Only as interim values for synthetic data. The five types (fall, wound, medication, acute decline, social situation) are engineering's seed (0020), not a taxonomy. Severity `low` to `critical` has no definitions, so the serious threshold (`high` or `critical`) depends on the reporter. A medication error rated `medium` never escalates. Gaps the Clinical Owner should consider (not rules): near misses; suspected neglect or abuse, where `lca` names a possible KESB reporting route (ZGB Art. 443); infection; aggression towards staff. The choice of taxonomy (D option) is `clinical`.
- **Does B keep patient safety a precondition?** For the **billing** hold, yes. A hold blocks billing only (CR-018, CR-055), so who lifts it does not change care. Four eyes within the team (not the author, a registered nurse) is adequate for a billing lift. Conditions:
  - the lift never closes the quality event or its escalation (CR-041);
  - for serious events, the review afterwards is an OPS1 item that cannot be closed by hand until a review is recorded, so it cannot be forgotten.
- **Option C (hold governs care):** stopping a service automatically after an event can be more harmful than continuing. Examples: stopping medication administration after a medication error, or wound care after a fall. I do not support an automatic stop. The hazard in PS-5 is not that "care continues" but that "nobody reviews the care after a serious event". The control is a mandatory care-plan review signal for the affected case after a serious event (P2, not closable by hand until a review by a registered nurse is recorded). What the review must cover is clinical.
- **Clinical Owner must approve:** taxonomy and severity definitions; what "serious" means; the review after a serious event (who, content, time); whether any event type changes care.

#### D-32: delivery outside the app

- **Is a content-free text enough?** It is enough to make a member open NAVORA. It does not let her judge urgency without opening it. That is acceptable, because the only thing that leaves the app is a P1, which is urgent by definition. The larger hazard is **alert fatigue**: SIG1-1 sends to every active member of the team, so outside the app every member's phone rings for every P1, including members off duty. Clinically safer:
  - outside the app, first the responsible member and the members on duty;
  - the whole team only when nobody has taken it after the SIG1-5 threshold;
  - Operations as today.

  Who is "on duty" has no data today (PO 05:15: no shift data). The time steps are D-28 (`clinical`).
- **Hazard of a channel that fails silently:** a team that believes it will be called, but whose push is off (permission revoked, browser or OS restrictions; `eng` to confirm iOS and Android behaviour), is less safe than a team that knows it must look. Clinical position:
  - **SIG1-8 stays a go-live condition until delivery is shown to work**: a test delivery when a member opts in, and a per-member indication in `/team` of whether outside delivery is active;
  - SIG1-6 and AN2 measure 10 show the share of P1s taken and the time to taking. The threshold for "works" is for the Clinical Owner.
- **Clinical Owner must approve:** response duties and times (D-28); whether off-duty members are ever called; the evidence threshold that ends SIG1-8. Provider, region and contract are `lca`/`owner`.

#### D-15: readiness checklist, care-plan fields, KLV category

- **Readiness checklist (1).** Today it has no clinical item (CR-033). Before the first real client, items for the Clinical Owner to consider, mostly already in the schema:
  - treating doctor named (`gp_named`, 0013);
  - emergency contact present;
  - access notes;
  - known safety alerts (D-17, not built);
  - the instrument of the needs assessment (D-13).

  I set none of these as a rule.
- **Care-plan fields (2).** Category, minutes, frequency, review date and goal are a minimum for planning and billing. They are not a full care plan: there is no per-service instruction, no link to the assessment finding the service answers, and no statement of the qualification the service needs beyond the category. Whether the pilot needs more is `clinical`.
- **Hazards of A versus C (3).**
  - A: a B service labelled A or C bypasses the registered-nurse gate (CR-007) and the order gate (CR-003). That is care by an unqualified person without a doctor's order, and a billing error (C-1, S1).
  - C: the catalogue default removes most classification, and an override needs a reason and triggers a review. The hazard left is a wrong catalogue entry, which affects every client. That is why the catalogue needs a source and an approver.

  C is safer.
- **Draft service catalogue.** I do not draft one from memory: that would be inventing a billing and clinical mapping. The source is KLV Art. 7 Abs. 2 lit. a, b and c, which enumerates the services per category. Proposal: `lca` extracts that enumeration verbatim from the consolidated text (fedlex, in force on the pilot date) with article and letter per service. `cra` then checks it against what the code can represent, and the Clinical Owner approves it. Until then, A stays with C-1 open.
- **CR-010 (question for the Clinical Owner):** which category A tasks (assessment, advice, coordination), and which C tasks, a member who is not a registered nurse may perform, and under what delegation. This depends on D-29's qualification classes.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ADM1 operating rules (accepted) | **blocking**: changes-requested for CGR-39 | CGR-39 (S1) |
| AN2 (in-progress; parts 1-2 merged) | **no blocking finding**; CGR-35 closed, DAY-1-R1-R3 endorsed | – |
| ABS1 (accepted) | **no blocking finding**; no ABS1 finding open | CGR-28 before cover |
| SIG1 (approved, unstarted) | **no blocking finding** on the brief; SIG1-9 must be corrected before start | CGR-37, CGR-39 |
| ORD0 (approved, unstarted) | **no blocking finding** | CGR-36, CGR-38; CGR-40 (S3) |
| J5 (accepted) | unchanged | CGR-31 |
| COVER1 | unchanged; cover stays off (D-3 read, D-17, CGR-21, CGR-28, D-29) | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:**
  - set ADM1 `changes-requested` for CGR-39 and correct SIG1-9 in #258 or the next cycle (direction-aware range);
  - decide CGR-40 (ORD0-1 lower bound);
  - copy the seven *Clinical impact* blocks into D-31, D-3, D-29, D-30, D-16, D-32, D-15.
- **eng:**
  - CGR-39 with SIG1-9, including the test change to pgTAP 035:191-196;
  - for D-32, the push behaviour on the pilot members' phones (iOS and Android) and a per-member delivery check.
- **lca:** for D-15, the verbatim KLV Art. 7 Abs. 2 enumeration with article references; for D-29, whether and how a nursing qualification or practice licence can lapse.
- **owner (critical path):** name the Clinical Owner and a deputy (G-1). D-28 is now `awaiting-approval: clinical` (#258) and waits only on that person.
- **clinical** (once named): D-28; D-31 (1b content, *nicht mehr nötig*, missed care); D-3 cover field list and D-17; D-29 mapping and classes; D-30 field classification; D-16 taxonomy, severity and review after a serious event; D-32 response duties and the SIG1-8 exit threshold; D-15 checklist, catalogue approval and CR-010.

---

## 2026-10-24 02:26: ABS1-C6 (#234), DAY-1 (0055, #239); Clinical impact for decision packages D-22, D-18, D-28

**Scope:** `recovery/main` @ `35e28a4`. Changes since the 22:30 section (merged as #235):
- **Code merged:** #234 (CSR1 part 12, ABS1-C6: `/field` absence start of yesterday, `past_planned` notice; no migration; ADR-067) as `d31709f`; #237 (`zod` ≥ 4.6.6, GHSA-mrhx-c7xc-m3w5; no product change) as `c2b39e1`; #239 (DAY-1: migration `0055_zurich_today_everywhere`, pgTAP `056`, seed, pgTAP and e2e on the Zurich day; ADR-068) as `2e79532`.
- **Docs:** #236 (eng), #238 (PO 23:15, 00:20, 00:15, 01:15): CGR-35 **decided** by the PO (product authority; PLANNED as AN2's first change with ABS1-C7 and DAY-1-R1-R3); CSR1 complete, AN2 active; decision-package process and new role `lca` (owner, 2026-10-24); packages D-22, D-18, D-28 `inputs-requested`, each asking `cra` for *Clinical impact*. **No `clinical`, `legal` or `owner` decision answered.**
- **Open PRs in scope:** #241 (`lca` input for D-22 and D-18; read, see below); #242 (PO: packages D-31, D-3, D-29; not merged, read; my *Clinical impact* for them follows once it is on `recovery/main`). No open engineering PR.

I read 0055 and pgTAP 056 in full, ADR-067 and ADR-068, the #234 diff (`absence-section.tsx`, `absence/commands.ts`, `absence/rules.ts`, unit tests), the packages D-22, D-18, D-28, the `lca` sections in #241, and, for the packages, 0013:180-205, 0014:140-152, 255-268, 0019/0024 `derived_exceptions` (order expiring, review overdue, late team cancellation), 0030:98-116, 0034:420-443, 0035:524-582, and searched `src/` and the migrations for any other derivation of "today" and for any push or realtime delivery of alerts. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `d31709f`, `2e79532` and `35e28a4`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-36 | J1 / CR-004 (accepted); D-22 (b) | advisory (S2) | The "Hausärztin/Hausarzt informieren (A/C ohne Verordnung)" task can never be completed. It is created when an A/C visit is planned without an order, but no command closes it: `complete_case_task` refuses every kind except `review_after_pause`, `sync_case_tasks` handles four other kinds only, and the task closes only when the whole case closes. NAVORA therefore cannot record **whether, when and by whom** the treating doctor was informed, and the open task is permanent noise that teams learn to ignore. `lca` (#241, D-22 (b)) reads KLV Art. 8a Abs. 1bis as: the needs-assessment result **is** sent promptly to the treating doctor when A/C are given without an order; CR-004 says "never required". Whether the information is a billing condition, and what "promptly" means, is `legal`/`clinical`: UNKNOWN. Clinically it is the only link between home care given without an order and the client's doctor (medication, deterioration, coordination). | created: 0014:263-266, 0025:258, 0030:215; not closable: 0034:428-430 (`complete_case_task` raises for other kinds), 0013:190 (`sync_case_tasks` kinds), only case close: 0024:290, 0031:38; label `src/features/intake/rules.ts:49` | PO decides the workflow (product authority; no deadline or content rule invented): a team command records "Hausärztin/Hausarzt informiert" with the date and a fixed channel code, actor and time server-side, no free text and no health data, audited and idempotent; it closes the `inform_gp` task; nothing else closes it except a case close. pgTAP: A visit planned without an order → task open; a team member records it → `done`, `done_by`, an audit row; a non-member → `rejected`; replay → `duplicate`; `complete_case_task('inform_gp')` still refused if the new command is separate. Deadline, content and billing effect stay D-22 (`legal`, `clinical`). |
| CGR-37 | C1 / CSR1 safety signals (accepted); D-28 recipients | advisory (S2; **S1** if the pilot has visits at times when nobody has `/team` or OPS1 open) | Every visit safety signal (`visit_overdue`, `visit_stuck`, `visit_uncovered`, `visit_interrupted`, no-show) is **pull-only**: it exists only when someone opens `/team` or OPS1. There is no push, e-mail, SMS, realtime subscription or periodic refresh anywhere in `src/` or the migrations, and no on-duty person is named for early mornings, evenings or weekends. A P1 overdue alert at 07:15 reaches nobody until somebody looks. The thresholds (D-28) only matter if the signal reaches a person. Pilot operating hours: UNKNOWN (`owner`, `po`). | search over `src/` and `supabase/migrations/` for push, notification, realtime, channel, `setInterval`, `refetchInterval`, on-call: no hit; alerts read by `public.team_visit_alerts()` (0038:140-175) and `operations_exceptions` on page load only | PO decides delivery (product authority; who must respond, and how fast, is D-28 `clinical`): strict default, a P1 safety signal writes one delivery record per named recipient (the visit's responsible member and the team's members on duty, else Operations), with delivery and acknowledgement audited, and the signal stays open until its cause ends (CR-041 unchanged). pgTAP: a visit overdue past P1 → one delivery record per recipient, no record for another team or organisation, no duplicate on a second evaluation, no record after the cause ends. Until built: the pilot plan names who watches `/team`/OPS1 at every hour visits are planned. |
| CGR-38 | J1/J3 orders (accepted); D-22 | advisory (S2) | A medical order recorded `present` **without an end date** never raises a signal: `order_expiring` requires an end date, the visit flag `order_expired` requires one, and PLAN2 keeps generating B visits for it indefinitely. Billing refuses such an order (CR-046, `order_validity_missing`), so the money is protected but the care is not: B care can continue for any length of time without anyone being prompted to renew the medical order. `lca` (#241) reads KLV Art. 8 Abs. 2-4 as limiting B orders in time (with exceptions); I adopt no duration. Whether an open-ended B order is ever valid is `legal`: UNKNOWN. | `order_expiring` 0024:499-501 (`medical_order_valid_until is not null`); visit flag 0014:147-148; PLAN2 0030:104-107 (`valid_until is null or …`); intake accepts a null end date 0013:143; CR-006 note (planning unchanged) | PO decides (product authority, no duration invented): strict default, a running case with an active B care-plan item and an order `present` without an end date raises a P3 exception "Verordnung ohne Enddatum" for the team and OPS1, not closable by hand while it holds. pgTAP: such a case → exception; end date entered → gone; a case with A/C only → none; another organisation → none. Alternative: intake refuses `present` without an end date when B items exist. The duration rule stays D-22 (`legal`). |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-35 | open, advisory (S3); **decided by the PO** 2026-10-23 23:15 (moved `moved` row stores `responsible_absent`, server-side, immutable; HAND1 text); PLANNED in AN2's first PR | `briefs/ABS1.md` 23:15; not built (no migration after 0055). Closes when the migration and the pgTAP set I named on 22:30 are merged and green |
| CGR-31 | open, advisory (S3; S1 before invoicing); **evidence widened** | `lca` (#241, D-18 (3)) reads KVG Art. 25a Abs. 5 (2017 amendment) as: for home care the residual-financing **rules** are those of the provider's location canton, the residence canton **pays**; the OKP part and the 10-minute rule are federal. If that holds, the residence canton is the wrong key for the minimum and tariff versions, not only a time-rule question. Not a determination; `legal` (D-18). Remedy unchanged in substance; it must follow the key D-18 names |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open, unchanged | no change |

### Other changes reviewed (no finding)

- **ABS1-C6 (#234, met by the PO 23:15):** `earliestAbsenceStart` = yesterday (form `min`, unit tests incl. month, year and leap-day boundaries); `pastPlannedOf` reads `past_planned`, 0 on a replay; the notice is fixed text, no name, no reason, no health data, with a link to `/team`; the visits are not released (CGR-32 unchanged). The notice is transient (gone after a reload or a replay); acceptable, because the persistent signal is the CGR-32 flag on `/team` and OPS1. Lower bound is an app rule only; `record_absence` still accepts earlier starts by command, counted by AN2 measure 8. Rule CR-065 added.
- **DAY-1 (0055, pgTAP 056; ADR-068):** a safety fix I support: for one to two hours each night OPS1 *order expiring* and *care-plan review overdue*, `pause_case`, `apply_case_facts`, `add_care_plan_item` and the late-team-cancellation window used the UTC day. 0055 rewrites every function body in `public`/`private` that contains `current_date`, fails if one remains, and is idempotent. My search of all migrations finds no other derivation of the day (`now()::date`, `current_timestamp::date`, `localtimestamp`, `date(now())`, `date_trunc('day', …)`) and no `current_date` in a view, default, check or policy; in `src/` the day comes from Europe/Zurich (`features/field/rules.ts`, `absence/rules.ts`, `team/auto-plan.tsx:25`) and other date helpers are calendar arithmetic. So the guard's narrow pattern is complete **today**, by reading; it is not complete for the future, which is the PO's DAY-1-R1 (I agree: R1-R3). pgTAP 056 cases 2 and 3 assert function text, not behaviour; R2 (one behavioural run at a split-day clock) is the real proof. Rule CR-064 added.
- **`lca` input (#241), as evidence for my sections below:** (a) KLV sets no form; the 2023 administrative contracts require a signed *Bedarfsmeldung* for B, the doctor's *Kenntnisnahme* for A/C, doctor identified by ZSR/GLN, and "Rückwirkende Verordnungen sind nicht zulässig"; (b) A/C without an order since 1 July 2024 (KLV Art. 7 Abs. 4), result sent promptly to the doctor (Art. 8a Abs. 1bis); (c) KLV Art. 7a Abs. 2: 5-minute units, "mindestens 10 Minuten", which reads as a floor on payment, the opposite of CR-029's "below → not billable". I have not verified these sources; they are `lca` readings, not rules. Register notes on CR-004 and CR-029 updated accordingly; no status changed.
- **zod bump (#237):** no product behaviour; no finding.

### Clinical impact for decision packages (cra 2026-10-24)

The process (`DECISION_PACKAGES.md` step 3) asks for these sections in the package files. My scheduled instructions limit my self-merged PR to the report, the three registers and the journal, so the sections are here. **`po`: please copy each block verbatim into the package's *Clinical impact* section, signed "cra 2026-10-24 02:26 (copied from `reports/CLINICAL_GOVERNANCE.md` by po)". This is confirmed `cra` input, not a PO draft.**

#### D-22: valid medical order and renewal

- **Hazards.**
  (1) *Care continues without medical oversight.* CR-005 lets B visits continue after the order end date with a visit flag (0014:147-148), and OPS1 raises `order_expiring` (P3, 7 days, closable by hand) per case. An order `present` without an end date raises nothing (CGR-38), so B care can continue with no renewal prompt at all.
  (2) *Care stops abruptly.* After expiry PLAN2 leaves B services out of generated visits (`order_missing_or_expired`, 0030:104-116). For B services such as wound care or medication, an unnoticed renewal gap means the care simply stops being planned. The prompt that prevents both is the expiry warning, which is P3 and closable by hand; whether that suffices is `clinical` (D-28, C-9).
  (3) *The doctor is not informed about A/C care.* The `inform_gp` task cannot be completed (CGR-36), so b1 as built has no evidence of the information `lca` reads as required (Art. 8a Abs. 1bis).
  (4) *Back-dating.* Back-dating is a documentation-integrity hazard as well as a billing one. CR-058 measures the order against the moment it was **recorded in NAVORA**. Per `lca`, the contracts measure retroactivity against the order itself, i.e. the doctor's issue date, which NAVORA does not store.
- **Findings that apply.** CGR-07 (closed, strict default CR-046); CGR-33 (closed, order history); CGR-36, CGR-38 (new, advisory); BL-4, BL-15.
- **Does b1 hide a safety-relevant GP notification gap?** Yes, today: CGR-36. b1 is only safe with a recorded, audited "doctor informed" step. b2 (an order or the doctor's *Kenntnisnahme* also for A/C) removes the gap by construction, at the cost of GP work. From a safety view I see no hazard in b2. b1 is acceptable only with CGR-36's remedy, and its legality is `legal`.
- **Sub-question (c).** Clinically neutral between c1 and c2. Back-dating protection matters for documentation integrity; c3 weakens it. If the doctor's issue date is recorded (`lca` note 2), store it as a separate, immutable fact next to the recording time, never overwriting it.
- **Safe default.** a1 (signed order referenced, signer identified) or "no electronic form" as today; b as built **plus** CGR-36; c1 as built (strictest built option); CGR-38 before go-live.
- **What only the Clinical Owner must approve.** Whether an expiry warning of P3, 7 days ahead and closable by hand is sufficient for B care, or must become a stronger signal (D-28). Whether B care may continue on an expired order while renewal is pending, and for how long (CR-005: a clinical and legal rule, not a product choice). The content of the information sent to the doctor for A/C (`clinical`, with `legal` for the duty). The form, the A/C order question and the cut-off are `legal`, not clinical.

#### D-18: billing time rules

- **Does a time rule reward shorter or split visits?** Not as built. Exact minutes, billable never above measured (CR-030, CR-031), and the minimum (CR-029) is used only in fact derivation (0022, 0023, 0043, 0051), never in planning. `/field` shows no billing information (only `/visits` shows "abrechenbar", `visits-client.tsx:305`).
  Hazards to guard when the contract rule is modelled:
  (1) Per-visit rounding up to 5-minute units would reward splitting one visit into several; summing per day before rounding would not. Which applies is UNKNOWN (`lca` question 1).
  (2) If CR-029's reading is right (below 10 minutes → not billable), it rewards stretching a short visit to 10 minutes and penalises a correctly short one. If `lca`'s reading is right (paid as at least 10 minutes), it rewards many very short visits.
  Either way the safeguard is the same: no billing rule may feed back into planned minutes, which must come from the needs assessment (CR-002, D-13). AN2 should measure the distribution of measured minutes around the threshold (5, 10, 15) once real data exists. I propose this as evidence, not a rule.
- **Documentation time.** CR-031 excludes documentation from care time. That creates a documentation-quality hazard: reports written after the visit, from memory, or not at all. The existing controls are sign-at-completion (0026) and the lock on signed reports (CR-043) and `report_not_final` / `report_correction_open` (CR-053). If the contract pays category-a coordination time, documentation done **with** the client (assessment, coordination) should be measurable separately. That is a product question once `lca` question 2 is answered. No finding today.
- **CGR-31.** A billing finding, not a clinical one. Its key may change (see CGR-31 status above).
- **What only the Clinical Owner must approve.** Nothing in D-18 itself. The tariff rules are `legal`/contract. The Clinical Owner should see the AN2 minute distribution before invoicing starts.

#### D-28: thresholds of visit safety signals

- **Hazards per signal** (H-01, H-07, H-15, H-16, H-17):
  - `visit_overdue` (CR-038): a missed visit noticed late, causing missed medication, nutrition, hygiene or wound care, or an unnoticed fall. Untimed visits count from 00:00, so they turn P2 at midnight: a likely source of alert fatigue unless untimed visits get a window.
  - `visit_stuck` (CR-039): a nurse or client in difficulty during a visit. The clock restarts with every pause or resume (CGR-23, PS-19), so a visit paused and resumed repeatedly never escalates.
  - `visit_uncovered` (CR-040/049): nobody goes. It stays P2 with a 24 h window and is not closable by hand.
  - `report_not_final` / `report_correction_open` (CR-053): the next carer works from an incomplete record.
  - `visit_interrupted` (D-31) and the absence flag (CGR-32/CGR-35): missed care that needs a follow-up decision.
- **Evidence for the provisional values.** None. They are strict engineering defaults (CSR1), not clinically derived. NAVORA has no pilot data. AN2 can supply: time from planned start to actual start, how exceptions end, and repeat pauses per visit. I know of no Swiss standard that fixes these values: UNKNOWN; the Clinical Owner may name one.
- **Option C (team choice inside a clinical band).** A mechanism already exists at organisation level: an override cannot lower the priority, cannot set the amount above twice the default, and cannot escalate later than the default (0035:524-535, 575-582; D-21). Those limits are engineering choices, not clinical ones. Option C keeps safety a precondition only if all of these hold:
  (1) the band limits are set by the Clinical Owner, not by engineering;
  (2) the server refuses values outside the band (as 0035 does);
  (3) a team can make a signal stricter, never switch it off or make it closable by hand (CR-041 untouched);
  (4) every change is audited with the actor, and only a registered nurse of the team or the Clinical Owner may change it (UNKNOWN who; `clinical`);
  (5) the value applied is the one of the team that owns the visit, also for a covered visit (CGR-21).
  Under these conditions I see no safety objection to C.
- **Delivery comes before thresholds.** A threshold only helps if the signal reaches a person (CGR-37, new). The package should treat recipients and delivery as part of the decision. Who must respond, and how fast, is clinical. How the signal is delivered is product.
- **CGR-35 and CGR-23.** CGR-35 is a documentation fact, not a threshold. The PO decided it (PLANNED); whether a move counts as making up missed care stays D-31/D-28 `clinical`. CGR-23 (the stuck clock restarts) is a threshold-semantics question the Clinical Owner must answer: does a pause stop the clock?
- **What the Clinical Owner must approve.**
  (1) Per signal: a value or a band (earliest P2, latest P1), and for untimed visits a time window.
  (2) The priorities.
  (3) Who must respond to each priority, and at which hours (with CGR-37).
  (4) Which signals may never be closed by hand (today CR-041, CR-049, CR-053).
  (5) Whether a pause restarts the stuck clock (CGR-23).
  (6) If C is chosen: who in a team may change the value.
  The PO may decide only how the signal is shown and delivered.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ABS1 (accepted; ABS1-C6 met) | **no blocking finding** | CGR-35 PLANNED (AN2); CGR-28 before cover |
| DAY-1 (0055; merged, inside AN2) | **no blocking finding**; safety fix endorsed | DAY-1-R1-R3 (PO) |
| AN2 (active) | first PR to carry CGR-35, ABS1-C7, DAY-1-R1-R3; reviewed when open | CGR-35 |
| J1/J3 orders (accepted) | **no blocking finding**; two advisory gaps | CGR-36, CGR-38 (S2) |
| C1/CSR1 safety signals (accepted) | **no blocking finding**; delivery gap | CGR-37 (S2; S1 depending on pilot hours) |
| J5 (accepted) | unchanged | CGR-31 (key question widened) |
| COVER1 | unchanged: cover stays off until CGR-28, the `accept_cover` absence check, PS-12 and D-3 | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** decide CGR-36, CGR-37, CGR-38 (all product authority; they can ride with AN2 or the next capability that touches the same data, per your 23:15 rule for advisory findings); copy the three *Clinical impact* blocks above into D-22, D-18, D-28; state the pilot's visit hours and who watches `/team`/OPS1 at those hours (CGR-37, with `owner`).
- **owner (critical path):** name the qualified Clinical Owner and a deputy (G-1); D-28 cannot leave `awaiting-approval: clinical` without one. Optional: allow `cra` to write its *Clinical impact* sections into `decisions/*.md` within its self-merged governance PR, so the PO need not copy them.
- **eng:** *Engineering impact* in D-22, D-18, D-28; for D-22, whether the doctor's issue date and ZSR/GLN can be stored apart from the recording time (`lca` note 2).
- **legal** (via `lca` / advisers): D-22 questions 1-3 and D-18 questions 1-3 of #241; additionally whether informing the doctor (Art. 8a Abs. 1bis) is a billing condition and its deadline (CGR-36).
- **clinical** (once named): D-28 (list above), D-31, D-10, D-30, D-16, D-17; for D-22, whether B care may continue on an expired order and whether the expiry prompt suffices.

---

## 2026-10-23 22:30: CSR1 part 11 merged (0053 CGR-32, 0054 CGR-34); PO cycles 20:15, 21:17, 22:15

**Scope:** `recovery/main` @ `dee3891`. Changes since the 19:57 addendum (PR #226, not merged until now: its db job ran into the pgTAP 046 evening failure; this PR carries it):
- **Code merged:** #228 (CSR1 part 11, CGR-32: migration `0053_csr1_cgr32_past_visit_absence_flag`, ADR-065 PROPOSED, pgTAP `054` (34), seed fixture (ended absence, visit 532, synthetic), pgTAP 046 fixtures pinned to today, 004/048/050 adjusted, unit and e2e) as `33112e3`; #230 (CGR-34: migration `0054_csr1_cgr34_cancel_keeps_absence`, ADR-066 PROPOSED, pgTAP `055` (26), 047 column list, unit and e2e) as `673ba50`.
- **Docs:** #227 (PO 20:15: CGR-34 decided), #229, #232 (eng: delivered), #231 (PO 21:17: CGR-32 met; new condition ABS1-C6; challenge row on guessed absence end dates), #233 (PO 22:15: CGR-34 met; CSR1 part 12 = ABS1-C6; challenge row on the reason picker for a flagged past visit; AN2 measure 8 extended). **No decision answered** (no `clinical`, `legal` or `owner` row changed). **No open PR in scope** except my own #226 (only #3, M2 to `main`, otherwise).

I read 0053 and 0054 in full, pgTAP 054 and 055 (fixtures and assertions), the pgTAP 046 diff, the seed diff, the label helpers (`lifecycle/rules.ts`, `operations/exceptions.ts`, `handover/rules.ts`), ADR-065, ADR-066, the PO reviews in `briefs/ABS1.md` (20:15, 21:17, 22:15) and `reschedule_visit` as patched by 0050 and 0052. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `87612aa` (head of #230) and `673ba50` (merge commit; its db job ran at about 21:30 Zurich, so the 046 evening failure is fixed); on `dee3891` app and db are green, e2e was still running at the time of this review.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-35 | ABS1 / CGR-32, CGR-34 (accepted) | advisory (S3) | A flagged past visit (CGR-32: planned, dated yesterday, its responsible member absent at its interval) has a second way out besides `cancel_visit`: `reschedule_visit` to today or later (allowed: `check_visit_slot` accepts yesterday onwards, 0012:59; 0052 refuses only a move that would still leave her absent at the new interval). The move writes a `visit_plan_changes` row `moved` with the old and new slot and a free-text reason (0014:315-316) and ends the overdue alert; the CGR-32 flag is computed and disappears, and unlike CGR-34 nothing stores that the care due on the original date was not given because the responsible member was absent. The record reads as an ordinary planning move. This is the same documentation-integrity gap CGR-34 closed for the cancellation, on the path a team is most likely to choose ("Folgeeinsatz", ADR-065 Consequences). The original date is still reconstructable from the `before` slot plus the absence row, but an absence can later be shortened or withdrawn, which is exactly why CGR-34 stores the fact. Whether missed care must be made up, and whether moving it counts as making it up, is `clinical` (D-28, D-31): UNKNOWN. | 0053:48-56 (flag computed); 0054:61-66 (stored only in `cancel_visit`); `reschedule_visit` 0014:300-316 + 0052:36-55 (no CGR-32 check before the move); ADR-065 Consequences ("follow-up visit, or closed with a reason") | PO decides (product authority), e.g. in CSR1 part 12 with ABS1-C6. Strict default: when `reschedule_visit` moves a visit for which the CGR-32 condition (as in 0054:61-63) holds **before** the move, the `moved` row stores `responsible_absent = true` server-side (immutable; caller cannot set it), shown with the same fixed text on the visit history and HAND1. pgTAP: absence from yesterday recorded today → yesterday's flagged visit moved to tomorrow → its `moved` row has `responsible_absent = true`, the absence then withdrawn → still true; the same move without an absence → `false`. No new reason code, no extra tap. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-32 | **closed** (IMPLEMENTED, PROVISIONAL product rule) | 0053:63-79: `record_absence` returns `past_planned` (planned, dated before today, interval overlapping the absence, naming her; caller's teams only); nothing written for those visits; 0053:48-56, 88-116: `flags = {responsible_absent}` on `visit_overdue` rows of `/team` and OPS1, computed. pgTAP 054:78-89 (recorded, `past_planned` = 2, past visits keep her, today and tomorrow released, no plan change), 054:93-111 (flag on `/team` and OPS1, detail keeps "zuständig", only overdue alerts carry it), 054:116-141 (shorten and withdraw clear it); **my 19:46 case met**: fixture `closed` (overdue alert closed by hand before the absence) is counted in `past_planned` (054:79-80) and listed flagged (054:96-97); helper not executable by app roles (054:145). CI green on `c1b562a`, `33112e3`. Residual: the flag shows the fixed label only, no reason (privacy acceptable) |
| CGR-34 | **closed** (IMPLEMENTED) | 0054:25-31: `responsible_absent` column, check `not responsible_absent or kind = 'cancelled'`, append-only table (0024 trigger); 0054:61-66: set server-side before the status change from planned + dated before today + `visit_responsible_absent`; 0054:36: audited. pgTAP 055:55-66 (true, idempotent replay, reason `team_cancelled` kept, one note, audit row), 055:93-96 (released future visit: false), 055:101-104 (withdrawal keeps it), 055:109-112 (no absence: false), 055:115-128 (no app write privilege, no parameter, update refused, non-cancel insert refused), 055:75-85 (`/field` reader and OPS1 flag `not_done_responsible_absent`). CI green on `87612aa`, `673ba50`. Residuals: (1) HAND1 is asserted only by the function text (055:131), not by reading an entry; the unit test `handover-rules.test.ts` covers the label; acceptable, a behaviour assertion should ride with the next HAND1 change (eng). (2) The stored fact reflects the absence **as recorded** at the time of the cancellation; an absence recorded for the wrong member and withdrawn later leaves the mark (immutable by design, audited). Acceptable: it documents what the team knew when it cancelled. (3) The reschedule path is not covered: CGR-35 |
| CGR-31 | open, advisory (S3; S1 before invoicing), unchanged | no change |
| CGR-28 | open, advisory (S2 if cover is enabled), unchanged | no change |
| CGR-16, CGR-21, CGR-23 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **pgTAP 046 time-of-day fix** (my 19:57 note): `hand`, `later` now `least(now() + 3/4 h, today 23:00)`, `overdue` `greatest(now() - 20 min, today 00:00)` (046:63-67). Green in an evening run (`673ba50`). Between 23:00 and 24:00 `hand` and `later` lie in the past; the assertions on them (release and "Offen im Team" for today) do not depend on the time inside the day, and `visit_overdue` has a 0 h threshold (0038:66), so I expect no new window. Not verified by a run in that window; if the db job turns red only there, it is this fixture (eng).
- **Seed fixture** (ended absence of `assist.test` for yesterday, visit 532): synthetic, local seed only; no personal or health data.
- **ABS1-C6** (PO 21:17, PLANNED): `/field` offers a start of today or yesterday; the confirmation names the number of open past visits with a link to `/team`. Consistent with CGR-32; fixed text, no reason, no health data. I support limiting the app to yesterday (a late report rewrites who was absent). Review when its PR is open.
- **Challenge rows** (PO): (a) *reason codes for facts NAVORA already holds* and (b) *one action "Nicht durchgeführt (abwesend)" on the overdue alert*: I support (b) as a measured hypothesis, with one guard: such an action must close the visit with the stored CGR-34 fact and must **not** imply that the missed care needs no follow-up; the follow-up decision stays visible and separate until `clinical` answers D-28/D-31. (c) *guessed absence end dates*: operational, no finding.
- **AN2 measure 8** extension (flagged past visits per 100 absences and how they ended): useful evidence for D-28/D-31; it should also count flagged visits that were **moved** (CGR-35), otherwise the measure undercounts missed care.
- **Rule register:** two new hard-coded rules added: CR-062 (0053) and CR-063 (0054), both product rules within PO authority, not clinical rules.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ABS1 (accepted) | **no blocking finding**; CGR-32 and CGR-34 closed | CGR-35 advisory (reschedule path); ABS1-C6 PLANNED; CGR-28 before cover |
| CSR1 part 11 (0053, 0054; merged) | **no blocking finding** | – |
| CSR1 part 12 (ABS1-C6; not started) | reviewed when its PR is open; could carry CGR-35 if the PO decides so | CGR-35 |
| J5 (accepted) | unchanged | CGR-31 (before invoicing) |
| COVER1 | unchanged: cover stays off until CGR-28, the `accept_cover` absence check, PS-12 and D-3 | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** decide CGR-35 (whether a move of a flagged past visit keeps the absence fact, as CGR-34 does for a cancellation); extend AN2 measure 8 to moved flagged visits.
- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **eng:** state in the runbook whether any operator procedure writes with `session_replication_role = replica` (BL-15 residual); a HAND1 behaviour assertion for `responsible_absent` with the next HAND1 change.
- **legal:** D-22 (order before the visit; whether A/C need an order; the cut-off); D-18 (incl. CGR-31).
- **clinical** (once named): D-28, D-31 (incl. whether care missed during an absence must be made up, and whether a move counts as making it up), D-10, D-30, D-16, D-17.

---

## 2026-10-23 19:57: addendum to the 19:46 section (CGR-34)

**Scope:** `recovery/main` @ `790ae40`. No code, brief or decision changed since the 19:46 section (`50ee5f5` plus #224, the 19:46 section itself). A second review run read the same changes (pgTAP 053, the PO's CGR-32 decision) and agrees with the 19:46 section on CGR-33 (closed) and CGR-32 (decision endorsed, open until CSR1 part 11). It adds one finding on how a flagged past visit is closed. I read `cancel_visit` (0024), `end_visit_not_completed` (0042, header) and the `visit_overdue` definition (0038). **I did not run the tests.**

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-34 | ABS1 condition CGR-32 (CSR1 part 11, PLANNED) | advisory (S3) | The PO's CGR-32 decision keeps a past planned visit inside a newly recorded absence with its responsible member and flags its overdue alert; the team then closes it "with existing commands". For a planned visit that is `cancel_visit`, whose reasons are `client_cancelled`, `client_in_hospital`, `team_cancelled` or `other` (note). The flag is computed from the absence, not stored (condition (3)), and the overdue alert ends with the cancellation. The closed record then reads as a planned cancellation; that care was due and not given because the responsible member was absent survives only in free text, if at all, and is lost for AN2 and any later quality review. Documentation-integrity gap in a PLANNED rule; no clinical rule is needed to close it. Whether missed care must be made up or reported is `clinical` (D-28, D-31): UNKNOWN. | `cancel_visit` 0024 (reason list; `planned`/`on_the_way` only; any team member); PO condition CGR-32 (2)-(3), `briefs/ABS1.md` 19:12; `visit_overdue` derived from a planned visit past its start, closable by a coordinator with a reason (0038:10, 28) | PO decides (product authority) within CSR1 part 11. Strict default: when a visit is cancelled while the CGR-32 flag holds, the status note records it (for example `responsible_absent` stored on the cancellation, or a fixed reason "nicht durchgeführt: zuständige Person abwesend"), and withdrawing the absence later does not erase it. pgTAP: absence from yesterday recorded today → yesterday's flagged visit cancelled with `team_cancelled` → its status note shows it was not done while the responsible member was absent; the same cancel without an absence does not. |

### Status of earlier findings

Unchanged from the 19:46 section (CGR-33 closed; CGR-32, CGR-31, CGR-28, CGR-16, CGR-21, CGR-23 open).

### Other observation (no finding; for eng)

- **pgTAP 046 test 74 depends on the time of day.** The visit `later` is planned at `now() + interval '4 hours'` (046:66) and is expected to be released as "today" (046:267). Run between 20:00 and 24:00 Europe/Zurich, that instant falls on the next day, the release rule (today only for an absence without dates) correctly leaves it, and the test fails. Seen on this PR's own CI (docs only; db job, run at 20:00): `have 00000000-0000-4000-a000-000000000902, want NULL`. The code behaves correctly; the test needs a fixed time inside today. Not changed here (reviewer does not edit tests); `eng` owns it. Until fixed, a red db job in the evening is this test, not a regression, and must not be waved through as a "flake" for any other failure.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ABS1 (accepted) | **no blocking finding**; CGR-34 advisory, rides with CGR-32 in CSR1 part 11 | CGR-32, CGR-34 |
| CSR1 part 11 (not started) | review when its PR is open; it should carry CGR-34 with the 19:46 pgTAP case | CGR-32, CGR-34 |
| All other items | as in the 19:46 section | – |

### Decisions requested

- **po:** decide CGR-34 within CSR1 part 11 (how a flagged past visit's closing record keeps the absence).
- All other requests as in the 19:46 section (owner G-1; `legal` D-22, D-18; `clinical` D-28, D-31, D-10, D-30, D-16, D-17).

---

## 2026-10-23 19:46: CGR-33 guard (pgTAP 053) merged; PO decisions on ABS1 (CGR-32) and J5

**Scope:** `recovery/main` @ `50ee5f5`. Changes since the 19:00 section:
- **Code merged:** #222 (CGR-33: pgTAP `053_cgr33_order_audit_guard` (21), test only, no migration; ADR-064 PROPOSED) as `d67055b`.
- **Docs:** #221 (PO cycle 19:12: ABS1 accepted with condition CGR-32 and the PO's decision on it; J5-C2 and CGR-33 met; CSR1 part 11 = CGR-32 ordered before AN2; AN2 measure 12 "late billing facts"; challenge row "billing facts are built in a later batch"), #223 (eng: delivered, journal). **No decision answered** (no `clinical`, `legal` or `owner` row changed). **No open PR in scope** (only #3, M2 to `main`).

I read pgTAP 053 in full, ADR-064, the PO's CGR-32 decision and condition (`briefs/ABS1.md` 19:12), the J5 and CSR1 notes, the AN2 diff and the new challenge row. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `4661392` (head of #222), `d67055b` (one e2e run cancelled, a second passed) and `50ee5f5`.

### Findings

No new finding.

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-33 | **closed** (IMPLEMENTED; regression guard) | pgTAP 053:23-37: `audit_cases` exists on `public.cases`, calls `private.write_audit_event`, fires after insert and update for each row, has no `UPDATE OF` list, is enabled (`O`/`A`; a replica-only trigger fails), and names `medical_order_status` and `medical_order_valid_until`; 053:40-79: two order edits leave two `{old, new}` audit rows and `case_order_as_of` reads the order before them at their instant and the live order after; 053:82-92: update, delete and truncate of `audit_events` refused (`42501`) also for the owner, `authenticated` SELECT only, `anon` nothing. CI green on `4661392`, `d67055b`, `50ee5f5`. Residuals: (1) `residence_canton` is not asserted; needed only if D-18 adopts an as-of-visit-date residence rule through the same reconstruction (CGR-31), then 053 must be extended in that PR. (2) A write under `session_replication_role = replica` skips the trigger (superuser only; ADR-064 open): UNKNOWN whether any operator procedure uses it; owner `eng` (runbook) |
| CGR-32 | open, advisory (S3); **remedy decided by the PO** (product authority), build PLANNED (CSR1 part 11) | Decision `briefs/ABS1.md` 19:12: the absence is always recorded; past planned visits inside it keep their responsible member, are counted in `past_planned`, and their `visit_overdue` alert carries the fixed flag "Zuständige Person abwesend gemeldet", computed from the absence. **Architect view:** consistent with the strict default I proposed at 19:00 and safe: nothing is refused, the visit keeps one accountable trail, and no past visit appears in "Offen im Team" where it could be "taken" for a time that has passed. The fixed label carries no reason, so no health data reaches the team view (privacy acceptable). Whether missed care must be made up stays `clinical` (D-28, D-31), correctly not decided. For the pgTAP of part 11 I add one case: the flag is shown while an overdue alert for that visit is **open**; if that alert was already closed by hand before the absence was recorded, the result's `past_planned` still counts the visit (so the recorder sees it). Closes when part 11 is merged with that pgTAP and green CI |
| CGR-31 | open, advisory (S3; S1 before invoicing), unchanged | PO: any invoicing brief must first carry the D-18 answer; the preview keeps "Schätzung". See residual (1) of CGR-33 |
| CGR-28 | open, advisory (S2 if cover is enabled), unchanged | no change |
| CGR-16, CGR-21, CGR-23 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **AN2 measure 12** (share of `report` facts built more than 24 h after the visit end; `basis_changed` facts per 100): an operational measure, not a clinical or tariff rule; the 24 h is a reporting cut, not a billing deadline. No finding. PLANNED.
- **Challenge row "billing facts are built in a later batch"** (PO): I support measuring it first. If an ADR later snapshots the order, payer and residence at visit end, note that "at visit end" and the current cut-off "end of the visit date" (0051, D-22) differ for an order recorded later the same day; which one applies is D-22 (`legal`), UNKNOWN, and must be decided before such an ADR. A snapshot inside the signed report must not let the nurse edit the payer or order basis (intake owns them, J5-C1).
- **Rule register:** no new or changed hard-coded rule (053 is a test). CR-058 note updated.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| J5 (0043, 0049, 0051, pgTAP 053; accepted) | **no blocking finding**; CGR-33 closed | CGR-31 advisory (before invoicing) |
| ABS1 (accepted) | **no blocking finding**; acceptance with condition CGR-32 is consistent with the 19:00 gate | CGR-32 (part 11, PLANNED); CGR-28 before cover |
| CSR1 part 11 (CGR-32) | not started; reviewed when its PR is open | – |
| COVER1 | unchanged: cover stays off until CGR-28, the `accept_cover` absence check, PS-12 and D-3 | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **eng:** CSR1 part 11 with the extra pgTAP case above (CGR-32); state in the runbook whether any operator procedure writes with `session_replication_role = replica` (BL-15 residual).
- **legal:** D-22 (order before the visit; whether A/C need an order; the cut-off, also for any snapshot ADR); D-18 (incl. CGR-31).
- **clinical** (once named): D-28, D-31 (incl. whether care missed during an absence must be made up), D-10, D-30, D-16, D-17.

---

## 2026-10-23 19:00: CSR1 part 10 (0051) and ABS1-C5 (0052) merged

**Scope:** `recovery/main` @ `279d026`. Changes since the 18:30 section:
- **Code merged:** #216 (CSR1 part 10, J5-C2: migration 0051, pgTAP `051_csr1_order_as_of_visit_date` (35); ABS1-C5: migration 0052, pgTAP `052_abs1_c5_no_past_move_into_absence` (12); label `order_recorded_after_visit` in `src/features/billing/rules.ts` with its unit test; move-specific refusal text in `src/features/team/commands.ts`) as `3d48a00`.
- **Docs:** #217 (the 18:30 section), #218 (eng: delivered rows, journal). ADR-062, ADR-063 (PROPOSED). Rule register: CR-058 and CR-061 added by engineering. **No decision answered; no open PR in scope** (only #3, M2 to `main`).

I read 0052 in full, 0051 as merged (unchanged since the head `57d3a3f` I read at 18:30; the only later code is 0052), `case_order_as_of` (0051:57-87), the `audit_cases` trigger (0013:77-82) and `audit_events` (0004:20-31), `record_absence` (0048:89-158), `release_visits_between` (0046:125-160), pgTAP 052 in full and pgTAP 051 (assertion list). **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `9ea3cb3` (head of #216), `3d48a00` and `279d026`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-32 | ABS1 (0046, 0048, 0052) | advisory (S3) | ABS1-C5 refuses a **move** that would leave a past visit with an absent member, but `record_absence` reaches the same end state another way: an absence may **start in the past** (only an end in the past is refused), and the one release rule never touches visits dated before today. A planned visit yesterday inside an absence recorded today ("krank seit gestern") stays planned with her as responsible. `visit_overdue` (0038, independent of the responsible person) still alerts, so this is not a silent miss; the record names an absent member for a visit nobody did, which is the PO's reason for ABS1-C5 (PS-26). Refusing such an absence would be **unsafe** (her visits from today on would not be released), so the ABS1-C5 remedy must not be copied. IMPLEMENTED gap. | `record_absence` 0048:111-113 (start from `p_from`, no lower bound), 0048:127-129 (`in_past` only when the end has passed), 0048:151 (release); `release_visits_between` 0046:139 (`greatest(..., today)`); pgTAP 052:40-44 records exactly such an absence (from yesterday 06:00) | PO decides (product authority) how a past planned visit inside a newly recorded absence is shown; no clinical rule is needed. The absence is always recorded and today's and later visits are released as now. Strict default: the result names the past planned visits it covers (count) and they no longer read as hers (released, or flagged "verantwortliche Person abwesend" in the overdue alert). pgTAP: absence from yesterday 06:00 → yesterday's planned 07:00 visit does not name her as an available responsible member; today's visits released as in 048; the `visit_overdue` alert for yesterday's visit still shows. |
| CGR-33 | J5 (0051) | advisory (S2) | J5-C2 reads a fact's order basis backwards from the live case row through `audit_events`. That is correct only while the `audit_cases` trigger records **every** write of `medical_order_status` and `medical_order_valid_until`, and `audit_events` stays append-only. Both hold today, but no test guards them: a later migration that re-creates `audit_cases` without one of the two columns (it has been re-created twice, 0010 and 0013) would make every earlier visit read today's order, i.e. silently re-open the J5-C2 gap (an order recorded after the visit makes the visit billable). I recommended this assertion at 18:30; it is not in pgTAP 051. IMPLEMENTED dependency, no regression test (BL-15). | 0051:9-11, 57-80 (reconstruction); 0013:77-82 (trigger argument list); 0004:53-63 (append-only); pgTAP 051 has no assertion on `pg_trigger` / the trigger's arguments | pgTAP (in 051 or a new file): `audit_cases` exists on `public.cases`, fires after insert and update, and its arguments include `medical_order_status` and `medical_order_valid_until` (and `residence_canton`, which CGR-31 may rely on); `update`/`delete` on `audit_events` fail. A migration that drops either column from the trigger then fails CI. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| ABS1-C5 (PO condition) | **met in code** | `reschedule_visit` runs the move, its log and the ABS1-C4 release in one subtransaction and refuses with `responsible_absent`, nothing written, when the visit would still name a member absent at its interval (0052:36-55). Tested on the outcome, not on "before today". pgTAP 052 (a) refusal and replay, date/time/responsible unchanged, no plan change of any kind; (b) a move to yesterday outside the absence accepted, still hers; (c) a move into her absence ahead still releases. Residual: CGR-32 (the same end state through `record_absence`) |
| J5-C2 (PO condition) | **met in code** (cut-off PROVISIONAL, D-22) | one cut-off function `private.order_cutoff` (0051:49-54; pgTAP 051:103-105 incl. the day summer time ends); order as of the cut-off from the audit log, ties ordered by the identity `audit_events.id` (0004:21); every build path through `build_billable_fact`; `order_recorded_after_visit` never stands alone; pre-0051 facts re-derived by the next generation or lift. pgTAP 051:109-231. Guard against regression: CGR-33 |
| CGR-31 | open, advisory (S3; S1 before invoicing), unchanged | no change in 0051/0052 for the residence. Note for the PO and `legal`: `residence_canton` is in the `audit_cases` argument list (0013:82), so an "as of the visit date" residence rule could use the same reconstruction as J5-C2; which rule applies stays D-18 (UNKNOWN) |
| CGR-28 | open, advisory (S2 if cover is enabled), unchanged | 0052 leaves covers alone |
| CGR-16, CGR-21, CGR-23 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **A/C-only visit with the order recorded after the visit** reads as `without_order_ac` (ADR-062 consequences). This follows the pre-existing CGR-07 order rules (CR-046), unchanged; whether A and C services need an order and from when is D-22 (`legal`), UNKNOWN. No new finding.
- **CGR-29 build at the lift** does not run when the visit had no fact before the hold (engineering, journal 18:22); the next generation builds it. Nothing is billable without a fact, so this delays, never releases, billing. No finding; the PO decides whether it is wanted at the lift.
- **Cut-off against the transaction start** (ADR-062 open (1)): a change started before midnight and committed after counts for that date, within seconds. Acceptable as a strict-default deviation; D-22 may move the cut-off.
- **Privacy:** `billable_facts.order_recorded` holds the order status and end date only, already readable in the fact's scope (0022 RLS unchanged). The refusal text on `/team` names no person. Acceptable.
- **Rule register:** CR-058 checked against 0051 and CR-061 against 0052 (Architect notes added). No clinical threshold, tariff or KLV rule was invented.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ABS1 (parts 1-3, ABS1-C5; `delivered`) | **no blocking clinical finding**; the PO may accept, with CGR-32 as an advisory condition | CGR-32 new; CGR-28 advisory (before cover) |
| J5 (0043, 0049, 0051; `delivered`) | **no blocking finding**; J5-C2 met; CGR-31 and CGR-33 advisory conditions (CGR-33 before go-live, CGR-31 before invoicing) | CGR-33 new; CGR-31 open |
| COVER1 | unchanged: cover stays off until CGR-28, the `accept_cover` absence check, PS-12 and D-3 | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** accept ABS1 and J5 if you agree; record CGR-32 (ABS1) and CGR-33 (J5) as conditions; decide how a past planned visit inside a newly recorded absence is shown (CGR-32); CGR-31 time rule with `legal`.
- **legal:** D-22 (order before the visit; whether A/C need an order; the cut-off); D-18 (incl. CGR-31).
- **clinical** (once named): D-28, D-31, D-10, D-30, D-16, D-17.

---

## 2026-10-23 18:30: ABS1 parts 2 and 3 (0048, 0050), CSR1 part 9 (0049); open PR #216 (0051)

**Scope:** `recovery/main` @ `be22e2c`. Changes since the 15:00 section (open as #203, not merged; this PR carries it, see below):
- **Code merged:** #206 (ABS1 part 2: CGR-27 / ABS1-C1, ABS1-C2, ABS1-C3, AN1 measures; migration 0048, pgTAP `048_abs1_part2`, `048_abs1_an1_measures`) as `2401a11`; #210 (CSR1 part 9: CGR-24-W, CGR-29, J5-C1; migration 0049, pgTAP 049, 043 adjusted) as `378f811`; #212 (ABS1 part 3: ABS1-C4, ABS1-N1; migration 0050, pgTAP 050, 048 adjusted) as `1f64128`.
- **Docs:** #202, #204-#205, #207-#209, #211, #213, #215 (PO and engineering cycles). PO conditions ABS1-C4, ABS1-C5, J5-C2 and a third COVER1 condition (`accept_cover` refuses an absent nurse) opened; D-22 sharpened. **No decision answered.**
- **Open PR in scope:** #216 (CSR1 part 10, J5-C2; migration 0051, pgTAP 051), head `57d3a3f`. CI on its head: **UNKNOWN** (no workflow run reported by the API at 18:30).
- **Carried sections:** the 14:30 and 15:00 sections were published as #203 (green CI) but #203 conflicts with `recovery/main` (JOURNAL, rule register). This PR merges that branch, resolves both conflicts (journal: all entries kept, newest first; rule register: the Architect's notes on CR-045 to CR-055 and engineering's CR-056, CR-057) and supersedes #203.

I read migrations 0048, 0049 and 0050 in full, the 0051 diff of #216, pgTAP 048, 049 and 050 (assertion lists), every `visit_reports` "latest version" reader after 0049, every command that sets `responsible_user_id`, the `audit_cases` trigger (0013:77-82) and `write_audit_event` (0004:66-93), and `build_billable_fact` and the billing preview (0043). **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `2401a11` (one e2e run cancelled, a second passed), `378f811`, `1f64128` and `be22e2c` (one more e2e run still in progress at 18:30).

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-31 | J5 (0043, 0049) | advisory (S3; S1 before invoicing) | A billing fact takes the case's **residence canton** at build time for the minimum-minutes rule (`billing_rule`, decides `below_minimum`) and the tariff versions it records; the residence (canton, municipality) is also written into `payer_chain`. A later correction of the residence in intake re-derives nothing: J5-C1 fires only on `insurance_type` and `insurer_name`, and `rederive_fact_payer` copies `tariff_versions` and the residence fields. The billing preview, however, prices the same fact with the **live** canton's rates and rule. After a residence correction, the fact's billable flag and recorded tariff versions come from one canton and the estimate from another. The residence also decides who pays the residual financing (BL-2). Nothing is invoiced, so not blocking now. #216 (J5-C2) reads the order as of the visit date, J5-C1 reads the payer as corrected, the residence is read at build time: three different time rules for one fact. IMPLEMENTED gap. | `build_billable_fact` 0043:179, 221, 244 (residence at build time); trigger `billable_facts_follow_payer` 0049:342-346 (`after update of insurance_type, insurer_name` only); `rederive_fact_payer` 0049:303-317 (copies `tariff_versions`, merges only insurer and insurance type into `payer_chain`); billing preview 0043:373-378 (live canton for rates and rule) | PO decides, with `legal` (D-18), whether the residence of a fact is "as of the visit date" (like J5-C2) or "as corrected" (like J5-C1); the rule is not invented here (UNKNOWN). Until decided, the strict default: a residence correction re-derives the fact (cause `basis_changed`) with the new canton's rule, tariff versions and residence, or marks it not billable with a named reason; the preview prices with the canton recorded in the fact, never the live one. pgTAP: fact built in canton X → intake corrects the residence to Y → the head fact's `payer_chain` residence, `tariff_versions` and `below_minimum` match the canton the preview prices with. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-27 | **closed** | One interval for every absence check (0048:29-54): no start time = the whole date (Europe/Zurich); start without end = start + planned minutes A+B+C, else to the end of the date; used by release, take, "Offen im Team", `known_by` and `change_absence` (0048:77-85, 168-257), and by `plan_visit` and `reschedule_visit` since 0050. pgTAP 048:65-72 (the interval itself), 048:77-93 (an absence from 12:00 releases the untimed visit; from 08:30 the visit 08:00 without an end and 60 minutes; a visit that ends before the absence stays hers), 048:100-116 (the absent nurse cannot take either visit; the absent deputy is skipped for "kennt die Klientin"), 048:119-126 (shortened absence: the untimed visit stays open). This is the remedy of the 14:30 section unchanged |
| CGR-29 | **closed** | On the last lift, if the latest final report version has no J5-v3 `report` fact, it is built from that version instead of restoring the pre-hold fact (0049:383-388). pgTAP 049:243-271 (v1 fact → hold → correction v2 final → lift → head fact carries v2's report; no `hold_lifted` copy of v1) |
| CGR-24 residual (withdraw) | **closed** | `withdraw_report_correction`: performer only, draft only, untouched only (no time correction, observation or summary change since it was opened), kept as `withdrawn` with who and when, terminal, audited (0049:38-97, 206-262); every "latest version" reader ignores a withdrawn successor (0049:100-111, 131-141, 146-200, 414-433; I found no other reader that would treat a withdrawn draft as a successor: `field_countersign_queue` 0026 reads only `signed` versions, which never have a withdrawn successor). pgTAP 049:101-183 (withdraw, facts locked again, signal ends, idempotent, immutable, next correction gets version 3), 049:189-201 (observation or summary change → `draft_has_changes`), 049:215 (`not_correction`), 049:230-237 (`awaiting_countersignature`) |
| CGR-28 | open, advisory (S2 if cover is enabled), unchanged | 0048 and 0050 leave covers alone (0050:21). Still a condition before D-3 enables cover, together with the PO's third COVER1 condition (`accept_cover` refuses an absent nurse; 0028:213 sets her responsible without an absence check) |
| CGR-16, CGR-21, CGR-23 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **ABS1-C3** (an absence belongs to the person, every team of hers in the organisation): IMPLEMENTED as one row per team linked by `absence_group`; the overlap check, withdraw and shorten act on the whole group (0048:56-165). pgTAP 048:138-200. Endorsed: it removes the "absent in one team, available in the other" path I named in the 14:30 section.
- **ABS1-C4** (PO condition): `plan_visit` refuses a responsible member absent at the visit's interval (`responsible_absent`, nothing written; 0050:42-58); a move into her absence is logged and then releases the visit with "Abwesenheit" (0050:61-100). pgTAP 050:44-169 covers (a)-(e). Every command that sets `responsible_user_id` is now absence-checked except `accept_cover` (0028:213), which the PO already holds as a COVER1 condition. Endorsed: the safe direction (the visit is open and visible, never silently with an absent nurse).
- **ABS1-N1** (data minimisation): `record_absence` counts only the caller's own teams (0050:103-110; pgTAP 050:127-138). Endorsed.
- **ABS1-C5** (PO, a move into the past inside an absence is refused): not in 0050 and **not in #216** either, although the PO ordered it to ride with CSR1 part 10. OPEN; no clinical consequence beyond what the PO recorded (a past visit nobody goes to is not a live risk; the record would name an absent member).
- **AN1 absence measures** (0048:300-371): aggregates per team and organisation only, no member named. Acceptable.
- **J5-C1** (0049:267-346): IMPLEMENTED as specified; pgTAP 049:279-325. Endorsed, with CGR-31 as its gap.
- **Rule register:** CR-056 and CR-057 (engineering) checked against 0049. New rows CR-059 (ABS1-C3) and CR-060 (ABS1-C4) added by the Architect; CR-051 note updated. CR-058 is taken by #216.

### Open PR #216 (CSR1 part 10, J5-C2; 0051)

Read from the diff, CI **UNKNOWN**. No blocking finding.
- The order basis is reconstructed backwards from the live row through `audit_events`. That is sound only while every write of `medical_order_status` and `medical_order_valid_until` is audited: the `audit_cases` trigger fires after insert or update and lists both columns (0013:77-82), and `audit_events` refuses update, delete and truncate (0004:53-63). Keep a pgTAP assertion that both columns stay in the trigger's argument list, so a later migration that re-creates `audit_cases` without them fails CI instead of silently making old orders look current.
- The cut-off "end of the visit date" is the PO's strict default, not a legal answer. Whether an order must exist **before** the visit, and whether "recorded in NAVORA" stands for "issued by the doctor", are D-22 (`legal`); UNKNOWN. The function `private.order_cutoff` is the single place to change. No finding.
- CGR-31 (residence) is outside #216's scope; it should not be widened for it.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ABS1 (parts 1-3, `delivered`) | **no blocking clinical finding**; CGR-27 closed. The PO may accept once its own condition ABS1-C5 is met | CGR-27 closed; CGR-28 advisory (before cover) |
| F6 / CSR1 part 9 (`delivered`) | **no blocking finding**; the PO may accept | CGR-24 residual closed |
| J5 (0049) | **no blocking finding**; CGR-29 and J5-C1 met; CGR-31 advisory as a new J5 condition before invoicing | CGR-29 closed; CGR-31 new |
| CSR1 part 10 (#216, open) | **no blocking finding** on reading; merge only with green CI on its head; ABS1-C5 missing from it | – |
| COVER1 | unchanged: cover stays off until CGR-28, the `accept_cover` absence check, PS-12 and D-3 | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** accept ABS1 (after ABS1-C5) and CSR1 part 9 if you agree; record CGR-31 as a J5 condition and decide with `legal` which time rule the residence follows; confirm where ABS1-C5 is built now that #216 does not carry it.
- **legal:** D-22 (incl. whether an order must precede the visit and what "recorded" stands for, #216); D-18 (incl. the residence rule of CGR-31).
- **clinical** (once named): D-28, D-31, D-10, D-30, D-16, D-17.

---

## 2026-10-23 15:00: CSR1 part 8 merged (#200, 0047), CGR-30 fix

**Scope:** `recovery/main` @ `20a3566`. Changes since the 14:30 section (open as #201, not yet merged; this PR carries it, see below):
- **Code merged:** #200 (CSR1 part 8: CGR-24, CGR-26, CGR-13; migration 0047, pgTAP 047) as `20a3566`, including commit `1e1d904` (CGR-30, made after the 14:30 section).
- **Docs:** open PR #202 (eng: "CSR1 part 8 delivered", status rows and journal only). No decision answered; no brief changed since the 14:30 section.
- **Carried section:** the 14:30 section and its register changes were published as #201, which has green CI but conflicts with `recovery/main` (JOURNAL, rule register). This PR merges that branch, resolves both conflicts (both journal entries kept; rule register: the Architect's notes on CR-045 to CR-052 and engineering's new CR-053 to CR-055 rows), and supersedes #201.

I read the final 0047 in full (`exception_closes_with_cause`, the `team_visit_alerts` and `operations_exceptions` patches, `field_visit_status_notes`), pgTAP 047, and the UI changes (`visit-lifecycle.tsx`, `quality-section.tsx`, `billing-preview.tsx`, `features/quality/rules.ts`, `features/operations/exceptions.ts`). **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `1e1d904` and on the merge commit `20a3566` (one e2e run on `20a3566` was cancelled, a second one passed).

### Findings

No new findings this run.

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-24 | **closed** (threshold PROVISIONAL, D-28) | `report_correction_open` (P3, not escalating) after the `report_not_final` threshold until the correction is final; a correction awaiting the countersignature keeps it (0047 §1-2). pgTAP 047:101 (23 h: not yet), 047:107 (25 h: Operations sees P3), 047:125 (team sees it), 047:143 (organisation override of the threshold applies), 047:148-155 (final → gone), 047:174-195 (countersigned and final → gone). Billing side closed by 0043 (CGR-03). Residual (OPEN, PO): no command withdraws a correction draft opened in error, so it stays open, and the visit's facts unlocked, until the performer signs it |
| CGR-30 | **closed** | `report_correction_open` is listed in `private.exception_closes_with_cause` (0047 §1b); `operations_exceptions` returns `closable = false` and an earlier close hides nothing (0047 §2c); `team_visit_alerts` ignores an earlier close (0047 §2b). pgTAP 047:26-27 (closes only with its cause, not a safety exception), 047:108-109 (`closable` false), 047:110-111 (hand close → `cause_persists`), 047:119-129 (a close written as table owner hides it neither for the team nor for Operations) |
| CGR-26 | **closed** for the label; the pilot measure is PLANNED (AN2) | `field_visit_status_notes` returns `actor_kind` (me, team, coordination, former) with name, qualification or role, never a user id (0047 §3); `/field` shows "Beendet von …" (`visit-lifecycle.tsx:81`); pgTAP 047 checks the label for the performer, a colleague and Operations (047:211-221 and following). How an end recorded in error is corrected stays D-31 (PS-22) |
| CGR-13 | **closed** for the wording; the clinical meaning of a hold stays D-16 (PS-5, H-06) | "Abrechnungssperre" with `HOLD_MEANING` ("Gesperrt ist nur die Abrechnung …") on `/field`, `/operations` and the billing preview (`quality-section.tsx:49-83`, `billing-preview.tsx:34`, `features/billing/rules.ts`); e2e `quality.spec.ts` updated |
| CGR-27 | open, **blocking (S1)**, unchanged | no change in 0046 since the 14:30 section; ABS1 part 2 not started |
| CGR-16, CGR-21, CGR-23, CGR-28, CGR-29 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **CR-053 to CR-055** (added by engineering 14:40) checked against the merged code; architect notes added. No clinical threshold was invented: `report_correction_open` reuses the existing `report_not_final` threshold and its organisation override (PROVISIONAL, D-28).
- **Privacy of `field_visit_status_notes`:** the label shows a coordinator's display name and role to the visit's team; no user id, no health data beyond what the visit's team already reads. Acceptable.
- **Remaining hint text** in `features/quality/rules.ts` ("bei Bedarf eine Abrechnungssperre setzen" as the interim response to a quality observation): consistent with the wording remedy; whether a quality event needs more than a billing hold is D-16 (`clinical`). No new finding.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| F1-F4, F6 (CGR-24) | **no blocking finding**; the PO may accept | CGR-24, CGR-30 closed |
| OPS1 (CGR-26) | condition **met** for the label; AN2 measure stays a PLANNED condition | CGR-26 closed (label) |
| QG1 (CGR-13) | wording condition **met**; D-16 stays open | CGR-13 closed (wording) |
| ABS1 part 1 | **blocking: CGR-27** (unchanged) | CGR-27, CGR-28 |
| J5, F6 | as in the 14:30 section (no blocking finding; conditions CGR-29, J5-C1) | – |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1).
- **po:** accept F1-F4/F6 (CGR-24), OPS1 (CGR-26) and QG1 (CGR-13) conditions if you agree; decide whether a correction draft must be withdrawable (residual of CGR-24); keep CGR-27 first in ABS1 part 2.
- **clinical** (once named): D-28 (incl. `report_correction_open` priority and threshold), D-31, D-10, D-30, D-16, D-17.
- **legal:** D-18, D-22.

---

## 2026-10-23 14:30: J5 signed billing, CSR1 part 7, ABS1 part 1 (0043-0046); open PR #200 (0047)

**Scope:** `recovery/main` @ `980cdd9`. Changes since the 10:29 section (merged with #184 as `845ae96`):
- **Code merged:** #183 (CSR1 part 6, J5: CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9; migration 0043, pgTAP 043) as `896e943`; #188 (CSR1 part 7: CGR-19, CGR-22; migration 0044, pgTAP 044) as `e215924`; #192 (CSR1 part 7 completion: CGR-25; migration 0045, pgTAP 045) as `7e5013b`; #195 (ABS1 part 1: CGR-11, CGR-15; migration 0046, pgTAP 046, two-session take check) as `a626c30`.
- **Docs:** #185, #187, #189, #191, #193, #194, #196, #198 (PO and engineering cycles). J5, F6 and ABS1 part 1 wait for this section. PO conditions J5-C1 and ABS1-C1 to C3 opened; D-10, D-22, D-28 and D-31 sharpened; none answered.
- **Open PR in scope:** #200 (CSR1 part 8: CGR-24, CGR-26, CGR-13; migration 0047, pgTAP 047), head `023cc1e`. CI on its head: **UNKNOWN** (one run in progress on `61c7d76`, none on `023cc1e`); GitHub reports a merge conflict with `recovery/main`.

I read migrations 0043 to 0047 in full, pgTAP 043 to 047, the cover commands they interact with (0028, 0029), `generate_billable_facts` (0022) and the decision rows. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `896e943`, `e215924` (one e2e run cancelled, a second passed), `7e5013b`, `a626c30` and `980cdd9`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-27 | ABS1 (0046) | **blocking (S1)** | The release rule and every absence check compare the absence with the visit's **planned interval**, and that interval is wrong for two kinds of visit. A visit **without a start time** is 00:00-00:01; a visit **with a start time but no end time** is one minute long. So an absence starting at 12:00 does not release that day's untimed visit, and an absence starting at 08:30 does not release a visit planned 08:00 without an end. The visit stays with the absent nurse, does not appear in "Offen im Team", raises no `visit_uncovered`, and looks covered. Only `visit_overdue` catches it, after the start and with a PROVISIONAL threshold. The same interval decides whether the absent nurse may take a visit and whether a deputy is shown as "kennt die Klientin". This confirms the PO's ABS1-C1 and widens it to visits without an end time. IMPLEMENTED gap. | `private.visit_interval` 0046:90-98; release filter 0046:145; `member_absent_during` 0046:101-108, used in take 0046:351, "Offen im Team" 0046:397-398 and `known_by` 0046:407-411; pgTAP 046 uses timed visits only | A visit without a start time occupies its whole date (Europe/Zurich, 00:00 to 24:00). A visit with a start and no end occupies at least start + its planned minutes (A+B+C); with no planned minutes, to the end of its date. This is arithmetic, not a clinical rule. One interval function for release, take, "Offen im Team", `known_by` and `change_absence`. pgTAP: an absence from 12:00 releases that day's untimed visit; an absence from 08:30 releases a visit 08:00 without an end and with 60 planned minutes; the absent nurse cannot take either one. |
| CGR-28 | ABS1 with COVER1 (0046, 0029) | advisory (S2 if cover is enabled) | An absence releases only visits of **the absence's team** where she is the **responsible member**. A visit she accepted as a **cover** for another team has `covered_by` = her and no responsible member, so the absence does not touch it. It stays "covered": it is excluded from `visit_uncovered`, from new cover offers and from "Offen im Team". From 4 h before the start she cannot hand the cover back either (`too_late`). Only `visit_overdue` catches it. Cover is switched off by default (PS-12, D-3), so this is not blocking today. IMPLEMENTED gap. | release filter 0046:142 (`team_id` and `responsible_user_id`); `accept_cover` sets only `covered_by` 0029:186; `withdraw_cover` refuses within the fallback lead 0029:215-218; "Offen im Team" and take exclude covered visits 0046:388, 344 | Before D-3 enables cover: an absence also ends her covers in the period (as `withdraw_cover`, without the lead-time limit, with the fixed text "Abwesenheit"). The visit is then uncovered again for its own team and Operations. pgTAP: she accepts a cover → records an absence → `covered_by` is empty → `visit_uncovered` for the original team. |
| CGR-29 | J5 (0043) | advisory (S3) | When a quality hold is lifted, the trigger appends the fact that was in force **before** the hold again. If a report correction was signed and became final **during** the hold, no fact was built for it (`build_billable_fact` returns null while a hold is open). After the lift, the preview and AN1 therefore count the **older** signed snapshot as billable until someone runs the generation again. Nothing is invoiced today, so this is not blocking. IMPLEMENTED gap. | `build_billable_fact` returns null under an open hold 0043:166-169; lift appends the pre-hold fact 0043:295-308; `correct_report` has no hold check (0044:28-75); generation runs only on demand (0022:264-289); pgTAP 043:171-212 covers hold and lift without a correction in between | On the last lift, if the visit's latest final report version has no J5-v3 `report` fact, build it from that version (the same function) instead of restoring the old fact. pgTAP: v1 final → fact → hold → correction v2 final → lift → the head fact carries v2's `report_id` and snapshot hash. |
| CGR-30 | CSR1 part 8 (#200, 0047) | advisory (S3) | `report_correction_open` can be closed by hand in OPS1, like `report_not_final`. Its key is the correction's id, so one hand close hides it for good, from Operations and from the team (`team_visit_alerts` does not ignore a close for this type). The correction stays open, the visit's times and observations stay unlocked, and nothing signals it again. That is the CGR-24 hazard, now silenced by a person instead of by a missing signal. The close is attributable and audited. OPEN in the PR (ADR-058). | #200: 0047:17-18 (closable as `report_not_final`), pgTAP 047:24 (`exception_closes_with_cause` false); `team_visit_alerts` patch 0047:77-80 adds the type without the "an earlier close never hides it" clause used for `visit_interrupted` (0045:138-139) | Add `report_correction_open` to `private.exception_closes_with_cause` (as CGR-22 and CGR-25): it ends only when the correction is final. A correction that can never be signed (performer gone, D-30) then stays visible, which is correct. pgTAP: close → `cause_persists`; `closable` false; final → gone. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-03 | **closed** (J5 part now too) | `private.snapshot_times` reads the events of the signed snapshot (0043:66-92); `build_billable_fact` takes times and planned minutes per category only from the final version's snapshot and stores its hash (0043:172-178, 245); a correction version yields a new superseding fact (0043:228-231). pgTAP 043:86-110 (live times and live plan drift after signature; the fact keeps the signed 30 minutes and the snapshot hash), 043:224-247 (correction version → new fact with 45 minutes, superseding). Residual: CGR-24 (open correction, #200), CGR-29 |
| CGR-07 | **closed** (strict default, CR-046 PROVISIONAL; D-18, D-22) | `order_validity_missing`, `order_expired` (A and C too), `payer_not_modelled` for any insurance type other than KVG (0043:198-213). pgTAP 043:113-162. Whether A and C without an order are billable at all stays R-8 / D-22 (pgTAP 043:107 asserts they are; that is the existing PO rule, not a new one) |
| CGR-08 | **closed** | `validated` and `validation_note` on reference rows, seeded rows unvalidated (0043:33-49); fact warning `reference_not_validated` (0043:181, 220-226); preview `reference_validated` (0043:418-426). pgTAP 043:71-75, 108, 164-168, 249-256. Re-seeding waits for D-11 and D-18 (BL-1, BL-2) |
| BL-8, BL-9 | **mitigated-in-code** | BL-8: hold → not-billable fact, last lift → earlier fact again (0043:267-339; pgTAP 043:171-222); residual CGR-29. BL-9: one working-time fact per final version from its snapshot, superseding (0043:248-259; pgTAP 043:110, 242-247) |
| CGR-19 | **closed** (interim, D-30) | `correct_report` refuses `performer_not_in_team` and writes nothing (0044:59-64). pgTAP 044:143. Residual (OPEN, CR-048): a correction draft opened before she left stays open; #200's signal (CGR-24) makes it visible, subject to CGR-30 |
| CGR-22 | **closed** (interim, D-28) | hand close returns `cause_persists` (0044:85-90, 136-138); not closable and an earlier close no longer hides it (0044:165-170). pgTAP 044:71-80, 104-105 |
| CGR-25 | **closed** (interim, D-31) | `visit_interrupted` from the end until one follow-up decision (0045:93-123), not closable by hand (0045:62-67, 127-132), visible to the team and Operations (0045:135-140), audited, idempotent, one decision per visit (0045:49, 161-197); `client_transferred` names the next planned visit (0045:108-117). pgTAP 045:71-87, 105-107, 169. Residual (OPEN, D-31 (c)-(e)): "Folgeeinsatz geplant" is an unchecked statement |
| CGR-11 | **closed** | qualification change from registered nurse to care assistant releases her B and needs-assessment visits from today, not those in progress (0046:478-487, through 0046:125-158). pgTAP 046:321-331 |
| CGR-15 | **closed** | a released visit nobody takes keeps its overdue alert after its start (derivation unchanged). pgTAP 046:251-262 |
| CGR-24 | open (advisory); **remedy in #200** | 0047:58-73 (P3 after the `report_not_final` threshold, until final; signed-awaiting-countersignature counts as open), pgTAP 047:76-179. Closes when #200 is merged with green CI. The billing side was closed by 0043 (CGR-03). Residual CGR-30 |
| CGR-26 | open (advisory); **remedy in #200** | `field_visit_status_notes` returns who ended the visit as a label, no user id (0047:93-127); `/field` shows "Beendet von …". The weekly pilot measure is PLANNED (AN2). Correction of an erroneous end stays D-31 |
| CGR-13 | open (advisory); **wording remedy in #200** | UI label "Abrechnungssperre" with the sentence that the hold blocks billing only. What a hold stops clinically stays D-16 (PS-5) |
| CGR-16, CGR-21, CGR-23 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **ABS1 privacy:** `member_absences` has no reason and no free-text column; only the own team reads it; HAND1 shows a release as a fact without reason or member id (0046:48-72, 491-497). Endorsed (data minimisation).
- **Absence recorded by a colleague** (0046:184-240): allowed without the absent member's confirmation; she can withdraw it (0046:271-273) and her visits return if nobody took them. Acceptable. The PO may add to AN2 how many absences are recorded by a colleague and withdrawn by the member.
- **ABS1-C3** (an absence applies to every team of the member; PO decision 14:16): endorsed. A member of two teams who is absent in one still looks available in the other. Same class as CGR-27; part of the same part-2 test set.
- **PLAN2 with absence** uses the slot window, not `visit_interval`, so CGR-27 does not apply there (0046:462-471).
- **0043 A/C without an order billable** (`without_order_ac`): existing PO rule, unchanged; tracked as R-8 / D-22, `legal`.
- **J5-C1** (PO condition: re-derive the fact when the payer is corrected): endorsed as a billing-integrity condition; the strict default for order changes until D-22 is correct.
- **#200 stricter than asked:** a correction that is signed but awaits the countersignature keeps the signal (0047:12-15). Endorsed.
- **Rule register:** CR-045 to CR-052 (engineering) checked against the code; architect notes added. CR-053 to CR-055 come with #200 and are checked when it merges.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| J5 (#183 merged, `delivered`) | **no blocking finding**; the PO may accept, with CGR-29 and J5-C1 as conditions | CGR-03 (J5 part), CGR-07, CGR-08 closed; BL-8, BL-9 mitigated-in-code; CGR-29 advisory |
| F6 (#188 merged, `delivered`) | **no blocking finding**; the PO may accept, with CGR-24 as condition (remedy in #200) | CGR-19 closed (interim, D-30) |
| OPS1 (accepted) | conditions CGR-22 and CGR-25 **confirmed closed**; CGR-26 remaining (remedy in #200) | – |
| ABS1 part 1 (#195 merged, `delivered`) | **blocking: CGR-27.** Not accepted; the PO's `changes-requested` for part 2 stands and must include CGR-27 | CGR-11, CGR-15 closed; CGR-27 blocking; CGR-28 advisory (before cover is enabled) |
| CSR1 part 8 (#200, open) | **no blocking finding**; CI and the merge conflict are open | CGR-24, CGR-26, CGR-13 remedies present; CGR-30 advisory |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** add CGR-27 to ABS1 part 2 (with ABS1-C1); record CGR-28 as a condition on enabling cover (D-3); record CGR-29 as a J5 condition; decide CGR-30 on #200.
- **clinical** (once named): D-31 (including (c)-(e)), D-28, D-10, D-30, D-16, D-17.
- **legal:** D-18, D-22 (including J5-C1's order question); D-31 with `clinical`.

---

## 2026-10-23 10:29: CSR1 parts 3, 4 and 5 (0040, 0041, 0042)

**Scope:** `recovery/main` @ `50681da`. Changes since the 06:30 section (merged with #167 as `6fc517a`):
- **Code merged:** #171 (CSR1 part 3, F1-F4: CGR-01, CGR-03 F3/F4 part; migration 0040, pgTAP 040) as `bf37957`; #175 (CSR1 part 4, F7/F6: CGR-02; migration 0041, pgTAP 041; pgTAP 016, 019, 022, 026, 037, 038 adapted to the hashed sign) as `479701c`; #179 (CSR1 part 5, OPS1: CGR-20; migration 0042, pgTAP 042, `/field`, HAND1 label, CR-042) as `a78fa7e`.
- **Docs:** #169, #172, #174, #176, #178, #180, #182 (PO and engineering cycles): D-31 opened (CGR-20), CGR-22 added to D-28, countersigner return question added to D-10, CSR1 order (CGR-20, then J5, then CGR-19), WATCH-1, remediation plans CGR-02 and CGR-20.
- **Open PRs:** only #3 (`recovery/main` → `main`), out of scope for this review. No open PR in scope, so no PR comments this run.

I read migrations 0040, 0041 and 0042 in full, pgTAP 040, 041 and 042, the remediation plans, `report-commands.ts`, `report-section.tsx`, and the functions they interact with (0008, 0009, 0016, 0024, 0038, 0039). **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `bf37957`, `479701c` and `a78fa7e` (one e2e run on `a78fa7e` was cancelled and a second one passed). On `50681da` (docs only) app and db are green and e2e was still running.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-24 | F1-F4, F6 (0040) | advisory (S2) | Since 0040 a `signed` or `final` report locks the visit's times and observations, which is correct (CGR-03). The lock is lifted by `correct_report`, which **any team member** may call with a reason, and the correction draft then stays open **with no time limit and no signal**: `report_not_final` looks only for the absence of any `final` version, and the earlier final version still exists. While the draft is open, team members can change times and add observations, handover reads the changed live observations, and J5 still bills from the live times (CGR-03 J5 part, BL-3). A correction that is never signed (performer absent, or gone: CGR-19) therefore reopens the record silently and indefinitely. The changes stay attributable and audited, and nothing becomes signed unseen (0041), so this is not blocking. IMPLEMENTED gap. | `correct_report` 0016:343-349 (team member, no performer check); `private.visit_facts_locked` 0040:24-33 (latest version only); `report_not_final` 0024:519-527 (`not exists ... status = 'final'`); billable facts 0022:278 (any `final` version) | A correction draft older than the `report_not_final` threshold raises a P3 exception (type engineering's choice, e.g. `report_correction_open`) for the team and Operations until it is signed. Its threshold is a provisional default (`PROVISIONAL`, D-28). J5 takes minutes from the latest **final** snapshot, not the live facts, while a correction is open (the J5 part of CGR-03). pgTAP: final → correction draft opened → after the threshold the exception exists → signed → it ends. |
| CGR-25 | OPS1 (0042) | advisory (S2) | Ending a visit as *not completed* removes **every** signal about it: `visit_stuck` ends (correct), and nothing replaces it. Care that was due and not given (medication, wound care, a meal) is visible only passively, on `/field` and in HAND1 at the case's **next** visit. For `nurse_unavailable` (the nurse called away or unwell) the person who knows least about the follow-up may be the one recording it, and nobody else is told. For `client_transferred` the case's later visits stay planned (PO challenge 10:15). Before 0042 the P1 stuck alert at least forced a person to look. Whether a follow-up is required, by whom and at which priority is a clinical rule; it cannot be set here. UNKNOWN; owner `clinical` (D-31). | 0042:129-133 (status `interrupted`, no exception written); derived exceptions read only `on_the_way`, `started`, `paused` for `visit_stuck` (0038 §2); pgTAP 042 checks "no stuck or overdue exception" afterwards; remediation plan CGR-20 step 5 (visibility through `/field` and HAND1 only) | Strict provisional default until D-31: an `interrupted` visit raises an exception for the visit's team and Operations (type and priority engineering's choice, `PROVISIONAL`, e.g. P2 `visit_interrupted`, not escalating), closable by a person with a reason ("Folgeeinsatz geplant", "nicht mehr nötig"), with the reason code and note in its detail; for `client_transferred` the detail names the case's next planned visit. The PO adds the follow-up question to D-31. pgTAP: interrupted → exception visible to team and Operations → closed with a reason → gone. |
| CGR-26 | OPS1 (0042) | advisory (S3) | A coordinator outside the team can end any started or paused visit of the organisation as *not completed*, and the status is terminal. If that is done in error while the nurse is still on site, she can no longer complete the visit or add an observation, and care actually given is recorded as not given. The actor is recorded and audited, so the error is traceable, but it cannot be corrected. Who may record the end is already a D-31 question. | 0042:124-129 (`is_team_member` or `is_coordinator`), 0042:17-19 (no way out of `interrupted`); `record_observation` 0040:144 (no `interrupted`) | Until D-31: show the performer, on `/field`, who ended her visit and why; count coordinator-recorded interruptions of a visit in progress as a weekly pilot measure. If D-31 keeps the coordinator, it also says how an interruption recorded in error is corrected. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-01 | **closed** | `record_observation` refuses a supersede unless `prev.author_id = auth.uid()` (0040:154-163). pgTAP 040:83 (a colleague's supersede is `rejected`); 040:71-73 (the colleague adds her own observation); 040:63-67 (the author still supersedes her own). Only this command writes `visit_observations` (0009:50-61: select-only grants, update and delete refused) |
| CGR-02 | **closed** | `field_reports` shows a draft's live snapshot and its `snapshot_hash` (0041:60-77); `sign_report(report, hash, key)` refuses `facts_changed` and writes nothing when the current facts have another hash, and stores exactly the snapshot whose hash was sent (0041:114-124); the two-argument version is dropped (0041:84); the builder runs in UTC (0041:25). `/field` sends the hash and reloads after a refusal (`report-section.tsx`, `report-commands.ts:73-85, 120-135`). pgTAP 041:75-94 (a colleague's observation after display → `facts_changed`, still a draft), 041:99-115 (sign after reload), 041:119-130 (a corrected time reaches the signed correction version), 041:136 (time-zone independent), 041:148-154 (countersignature of the frozen version). The summary is not hashed; only the performer edits it (0016 `update_report_draft`), so no colleague's text is signed unseen |
| CGR-03 | **closed for F3, F4 and F6**; **open for J5** (billing from the signed snapshot) | `private.visit_facts_locked` true while the latest version is `signed` or `final` (0040:24-33); `correct_visit_time` and `record_observation` return `rejected` under the lock, serialised with the report row lock (0040:80-85, 148-152); `correct_report` reopens through a correction draft (0016:343-349). pgTAP 040:104-124 (after final: time correction, new and superseding observation refused, nothing written), 040:130-147 (correction draft reopens; the signed correction version carries the changes; version 1 unchanged; locked again), 040:158-162 (`signed` awaiting countersignature locks too). J5 still reads live times (0023:28-50); residual CGR-24 |
| CGR-20 | **closed** (interim rule PROVISIONAL, D-31) | terminal status `interrupted` only through `end_visit_not_completed` with a reason from a list, `other` with a note, actor and timeline event, audited, idempotent, row-locked (0042:99-135); a direct update to `interrupted` is refused (pgTAP 042:112-113); a care assistant ends a started B visit (042:130); `visit_stuck` ends without a hand close; no report draft, no billable or working-time fact, no `report_not_final`, no assessment marker (pgTAP 042, remediation plan *Tests*); `/field` and HAND1 show the reason (042:199-204). Residual CGR-25, CGR-26 |
| CGR-19 | open (advisory) | unchanged; next CSR1 part after J5 (PO 09:10) |
| CGR-22 | open (advisory) | not built yet; strict default is a CSR1 criterion (PO 07:10), question in D-28 |
| CGR-07, CGR-08 | open, unchanged | no change in 0022, 0023; J5's CSR1 part (#148) is next |
| CGR-11, CGR-13, CGR-15, CGR-16, CGR-21, CGR-23 | open, unchanged | no change in 0018, 0020, 0029, 0038 |

### Other changes reviewed (no finding)

- **`signed` locks too (0040, ADR-051):** stricter than the report asked. A countersigner who sees an error must countersign and then open a correction. The PO asked `clinical` in D-10 whether she may return the report instead. Endorsed as the strict default; nothing changes silently.
- **0042 is `security definer`** (ADR-053), not invoker as the brief recommended, so the state machine keeps refusing a direct update to `interrupted` and the reason cannot be skipped. Endorsed.
- **Observations after the end refused (0042):** the reason note (up to 1000 characters) carries what happened, and observations recorded during the visit stay. Acceptable until D-31. These observations are never signed, because no report exists for an interrupted visit; whether a report of the care already given is required is already a D-31 question.
- **Time corrections on an interrupted visit** stay possible (remediation plan, UNKNOWN): reasoned, audited, and no fact derives from them today. No finding; it must be re-checked if D-31 makes interrupted minutes billable.
- **Rule register:** CR-042 (engineering, 0042) checked against the code. CR-043 (0040) and CR-044 (0041) added by this review; CR-012 and CR-013 updated.
- **PO challenge (10:15):** after a hospital-transfer interruption, offer "Fall pausieren" in the same step. No safety objection: it only offers an existing, audited command, and the team chooses. It reduces the CGR-25 risk for that reason but does not replace the follow-up signal for the other reasons.
- **WATCH-1 (PO 09:10):** a coordination gap, not clinical. No finding.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| F1-F4 (#171 merged, `delivered`) | **no blocking finding**; the PO may accept | CGR-01 closed; CGR-03 closed for F3 and F4; CGR-24 advisory |
| F7 (#175 merged, `delivered`) | **no blocking finding**; the PO may accept | CGR-02 closed; CGR-03 closed for F6 sign and correction (0040) |
| F6 | **no blocking finding from this review**; D-10 (`clinical`) still blocks it in `OPEN_DECISIONS.md` | CGR-02 and CGR-03 closed for F6; CGR-19 and CGR-24 advisory |
| OPS1 (#179 merged, `delivered`) | **no blocking finding**; the PO may accept, recording CGR-22 and CGR-25 as conditions | CGR-20 closed (interim rule, D-31); CGR-22, CGR-25 advisory (S2); CGR-26 advisory (S3) |
| J5 | changes-requested (unchanged) | CGR-03 (J5 part), CGR-07 blocking; CGR-08, BL-8, BL-9 |
| ABS1 | approved, unstarted | CGR-11, CGR-15; the CGR-20 dependency is met |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** add to D-31: (a) after a visit is ended as not completed, must a follow-up be decided, by whom, by when and at which priority (CGR-25); (b) how an interruption recorded in error is corrected (CGR-26). Add to D-28: how long a report correction may stay unsigned before it is a signal (CGR-24).
- **clinical** (once named): D-31, D-28, D-10, D-30, D-16, D-17.
- **legal:** D-18, D-22; D-31 with `clinical`.

---

## 2026-10-23 06:30: ADM1 CGR-18 fix, CSR1 parts 1 and 2

**Scope:** `recovery/main` @ `8ec3351`, plus #165 at head `74f3acf`. #165 was merged during this run as `c987e83` (tree identical to `74f3acf`), and OPS1 was set `delivered` (#166). Changes since the 02:28 section (`0e90932`):
- **Code merged:** #153 (ADM1 CGR-18 fix, migration 0037, pgTAP 037) as `95ed737`; #161 (CSR1 part 1: CGR-12, CGR-04; migration 0038, pgTAP 038, `/team` alerts) as `74940fb`.
- **Code merged during this run:** #165 (CSR1 part 2, OPS1: CGR-05, CGR-06; migration 0039, pgTAP 039, `/operations`) as `c987e83`.
- **Docs:** #156, #158, #159, #162, #164 (PO and engineering cycles): D-30 opened (CGR-19); CSR1 criterion for CGR-19; ABS1 amended; C1 and J3 met by the PO, waiting for this review; ADM1 waiting for this review.
- #155 (this role's 02:28 section) was green but not merged. This PR carries it (merge commit) so the registers stay in one line of history.

I read migrations 0037, 0038 and 0039 in full, pgTAP 037, 038 and 039, and the functions they interact with (0003, 0007, 0016, 0024, 0028, 0029, 0035). **I did not run the tests.** CI shows app, db (migrations, seed, pgTAP) and e2e green on `95ed737`, `74940fb`, `8ec3351` (as reported in the journal) and on #165 head `74f3acf` (run 39900134825, checked).

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-20 | OPS1 (0039) with C1 (0038) | blocking (S1) for OPS1 acceptance | Since 0039 a `visit_stuck` exception can no longer be closed by hand, which is correct (CGR-06). But a visit that is `started` or `paused` has **no honest way to end except `completed`**. It cannot be cancelled or recorded as a no-show from those states. Pause and resume only restart the clock. So when a visit is really broken off (client taken to hospital during the visit, nurse called away, visit started by mistake), the team must either live with a permanent P1 on `/operations` and `/team`, or record the visit as `completed`. A false completion creates a report obligation for care not given, and its live start and end times feed measured minutes (BL-3, CGR-03). Before 0039 the coordinator closed the exception with a reason, so this pressure did not exist. How an interrupted visit is documented and billed is UNKNOWN; owner `clinical`, with `legal`. IMPLEMENTED gap in the state machine, made acute by 0039. | transitions for app users 0038:38-45 (from `started`/`paused` only to `paused`, `started`, `completed`); `cancel_visit` 0024:353 (`planned`, `on_the_way` only); `record_no_show` 0024:374 (`on_the_way` only); `handle_exception` close → `cause_persists` (0039:132-134); `visit_stuck` key carries the last event (0038:115, 120-121) | An explicit, audited command ends a `started` or `paused` visit as **not completed** (name and status engineering's choice, e.g. `interrupted`), with a reason and the actor, by the performer or a coordinator. It ends `visit_stuck`, produces **no billable fact** and does not count as a completed visit, until `clinical` and `legal` decide how such a visit is documented and billed (new decision). The visit stays visible to the team as interrupted. pgTAP: started → interrupted with reason → no `visit_stuck`, no billable fact, audit row present; paused → interrupted, same; the performer of a B visit can record it whatever her qualification, because it records that care stopped, not care given (who else may record it is part of the decision). |
| CGR-21 | C1 (0038), COVER1 | advisory (S2; dormant while cover is off) | `visit_overdue` and `visit_stuck` reach only the visit's own team and Operations. For a covered visit the covering nurse and her team never see them. The detail "von einem anderen Team übernommen" reads as "someone is going", but under 0029 the covering nurse cannot see or start the visit before D-3. Cover is off (`cover_enabled` false), so no client is affected today. | 0038:102 (detail), 0038:154 (`x.team_id in my_teams`); 0029:185-186 (acceptance sets `covered_by`, not the responsible member) | Before cover is enabled (D-3): the overdue and stuck alerts of a covered visit also reach the covering nurse and her team, and the detail does not imply that someone is on the way. pgTAP in the PR that enables cover. |
| CGR-22 | OPS1 (0039), C1 (0038) | advisory (S2) | `visit_uncovered` (P2, not escalating) remains closable by hand. With 0038 it persists after the planned start, but a hand close made 24 h ahead ("Team kümmert sich") silences it for that visit for good. If nobody is then assigned, the next signal is `visit_overdue` at the planned start, when the visit is already late. Which uncovered visits are safety-relevant is a priority question for `clinical` (D-28); it cannot be set here. | 0039:29-31 (safety = P1 or escalating); pgTAP 039:32-35 and 039:137 (`visit_uncovered` closable) | Either a strict provisional default (the hand close of `visit_uncovered` is refused while the visit is planned and nobody is responsible; it ends by assigning or cancelling), or the PO records why it stays closable. Add the question to D-28. pgTAP for the chosen behaviour. |
| CGR-23 | C1 (0038) | advisory (S3) | The stuck clock restarts with every status change, and any team member may pause or resume. A visit cycling between `started` and `paused` never reaches P1, however long it stays open. | 0038:115 (key includes the last event), 0038:120-128 (reference = last event) | Pilot measure: count of visits with more than two pause and resume cycles, or open longer than the planned duration plus the P1 threshold, reviewed weekly. A threshold change waits for D-28. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-18 | **closed** | `remove_team_member` refuses `has_visit_in_progress` for the performer of a team visit `on_the_way`, `started` or `paused` (0037:57-64) and `has_unsigned_reports` for the performer of a `completed` team visit with no `signed` or `final` report (0037:65-75). pgTAP 037: (1) colleague's visit started and paused → refused, she stays a member, nothing released (037:52-78); (2) completed, no report → refused (037:80-91); (3) draft → refused, nothing released (037:93-104); (4) signed awaiting countersignature → allowed, her planned visit released (037:106-123); final → allowed (037:125-142). A signed report can be countersigned by another registered nurse without the performer (0016:289-306) |
| CGR-12 | **closed** | `private.enforce_visit_transition` checks `private.is_registered_nurse` on every transition into `started` (first start and resume) and `completed` for B and needs-assessment visits (0038:52-58). The commands are `security invoker` (0007:126-165), so the trigger's `current_user = 'authenticated'` guard applies to them. pgTAP 038:76-109: care assistant refused at start, resume and completion (NV001), status unchanged; registered nurse allowed; an A visit stays open to a care assistant (038:118-120) |
| CGR-04 | **closed** (thresholds PROVISIONAL, D-28) | `visit_overdue` and `visit_stuck` derived in `private.derived_exceptions` (0038:89-133); `visit_uncovered` persists after the planned start (0038:91-92, PS-2); `public.team_visit_alerts()` shows them to every member of the visit's team (0038:140-175). pgTAP 038:127-203: P1 at +2 h, P2 at +10 min, not for a visit ahead or suspended, "niemand zuständig", uncovered after start, team view, no cross-team or cross-organisation leak, ends on start, stuck P2 and P1, ends on a new status change, past-dated visit of a removed member shows "zuständige Person nicht mehr im Team". Organisation overrides are bounded: priority cannot be lowered, `visit_overdue` at most +1 h, `visit_stuck` at most +2 h, escalation never later than the default (0035:526-536, 575-582). Residual items: CGR-20 to CGR-23 |
| CGR-05 | **closed** (merged as `c987e83`) | `quality_serious_open` derived while `open` or `in_review`, same key, clock from `created_at` (0039:59-64). pgTAP 039:40-66: stays in review, P1 continues, not closable, ends only on `closed`, then auto-closed |
| CGR-06 | **closed** (merged as `c987e83`) | Safety exception = effective rule P1 or escalating to P1 (0039:25-32); hand close returns `cause_persists` (0039:132-134); legacy closes no longer hide it (0039:73-74, 83-86, 101-104). An organisation cannot turn a safety type into a non-safety type (0035:577-581). pgTAP 039:68-127: no-show P1 not closable, legacy close ignored, outcome ends it; legacy close of `visit_overdue` ignored for Operations and team, cancel ends it; 039:139-145 an override to P1 makes a type safety. Residual: CGR-20, CGR-22 |
| CGR-19 | open (advisory) | interim refusal is a CSR1 criterion (`briefs/CSR1.md`); rule waits for D-30 (`clinical`, with `legal`). Not built yet |
| CGR-01 to CGR-03, CGR-07, CGR-08, CGR-11, CGR-13, CGR-15, CGR-16 | open, unchanged | no change in 0009, 0016, 0018, 0020, 0022, 0023 since `b546299`; carried in CSR1 (#149) or ABS1 (#134) |

### Other changes reviewed (no finding)

- **PO deviation for C1 (06:10):** a coordinator could close a P1 `visit_overdue` until CGR-06. Acceptable as an interim for one cycle; 0039 removed it.
- **CR-041 (0039):** "a safety exception closes only with its cause; a serious event keeps escalating in review", status PROVISIONAL with D-28. Endorsed as a strict provisional default.
- **Rule register CR-007 and CR-036:** updated for 0038 and 0037 (below).
- **PO challenge (06:10):** overdue and stuck visits on `/field` with the resolving actions. No safety objection, provided the alerts stay on `/team` and in OPS1 and still close only with their cause. The resolving actions on `/field` must include the CGR-20 path, or the only button offered for a stuck visit will be "complete".
- **PO challenge (04:17):** team composition proposed by the team, confirmed by the administrator. No safety objection, provided the refusals of 0036 and 0037 apply to the confirming command.
- **ABS1 deviation (03:10):** an absence is never refused; her performed visits stay with her under CSR1's stuck exception. Acceptable with CGR-20: an absent performer's started visit must be endable without a false completion.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ADM1 (#135, #153 merged; `delivered`) | **no blocking finding**; the PO may accept | CGR-18 closed; CGR-19 advisory (interim in CSR1, D-30); CGR-16 advisory until real data (D-29) |
| C1 (0038 merged; `delivered`) | **no blocking finding**; the PO may accept | CGR-12 and CGR-04 closed; CGR-21 (dormant), CGR-23 advisory; thresholds PROVISIONAL (D-28) |
| J3 | **no blocking finding** for CGR-12; the PO may accept | CGR-12 closed |
| OPS1 (#165 merged, `delivered`) | **not acceptable yet**; the PO sets `changes-requested` | CGR-05 and CGR-06 closed. CGR-20 blocking: an honest end for a started or paused visit, as the next CSR1 part. CGR-22 advisory |
| F1-F4, F6, F7, J5 | changes-requested (unchanged) | CGR-01, CGR-02, CGR-03, CGR-07, CGR-08, CGR-19, BL-8, BL-9 |
| ABS1 | approved, unstarted | CGR-11, CGR-15; CGR-20 applies to an absent performer |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** open a decision (`clinical`, with `legal`) for CGR-20: how a visit broken off after its start is documented and billed. Add CGR-22 (is a closed uncovered visit a safety signal?) to D-28.
- **clinical** (once named): D-28, D-30, D-16, D-17.
- **legal:** D-18, D-22.

---

## 2026-10-23 02:28: ADM1 changes on the merge commit (#135)

**Scope:** `recovery/main` @ `0e90932`. Changes since the 23:05 section:
- **Code:** #135 (ADM1 changes) merged as `eceac83`: migration 0036, pgTAP 036, `/admin`, and the removal of the legacy Operations heuristics (`src/features/operations/rules.ts`, CR-034).
- **Docs:** #138 (role reconciliation), #140 (this role's 23:05 section), #152 and #154 (PO cycles: CSR1 criterion for missed visits of removed members; BL-8 and BL-9 added to CSR1). Open: #153 (ADM1 `delivered`, docs only), #3 (`recovery/main` → `main`, out of scope for this review).

I read migration 0036 in full, pgTAP 036, and the report, visit and RLS functions it interacts with (0003, 0007, 0016, 0019, 0024). **I did not run the tests.** CI on `eceac83` and on `0e90932` shows app, db (migrations, seed, pgTAP) and e2e green.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-18 | ADM1 (#135, merged) | blocking (S1) | The CGR-10 refusal checks the **responsible** person only, but documentation belongs to the **performer**. Any team member may start any visit of her team, and the performer is the first `started` actor. Only the performer may draft and sign the report. So removal still goes through, and leaves care that can never be documented, when she is: (a) performing a colleague's visit that is `started` or `paused`, or (b) the performer of a `completed` visit whose report is missing or still `draft`. After removal she fails `is_team_member`, and nobody else may draft or sign for her. The P3 `report_not_final` exception appears but nobody can resolve it except by closing it (CGR-06). Billing stays blocked, which fails safe. Re-adding her to the team is the only way out, and nothing tells the administrator so. IMPLEMENTED gap; this is the H-12 / PS-11 hazard made permanent by a routine admin command. | 0036:107-110 (`v.responsible_user_id = p_user_id`); RLS `team_members_update_visits` 0003:175-178 (no responsibility check); `private.visit_performer` 0016:98-105; `create_report_draft` 0016:184 and `sign_report` 0016:254, 262 (team member **and** performer); pgTAP 036:89-116 tests the responsible person only | `remove_team_member` also refuses (result code engineering's choice, e.g. `has_visit_in_progress` and `has_unsigned_reports`) while she is the performer of a visit of the team that is `started` or `paused`, or of a `completed` visit of the team with no report or a `draft` report. `/admin` shows the reason. pgTAP: (1) member B starts A's visit → removing B is refused, nothing released; (2) B completed a visit, report missing → refused; (3) B's report is `draft` → refused; (4) B's report is `signed` (awaiting countersignature) or `final` → removal allowed. |
| CGR-19 | F6 (report correction) | advisory (S2) | A report correction is drafted by anyone in the team, but it carries the original performer and only she may sign it. Once the performer has left the team, **no correction of her final report can ever become final**, and the correction draft stays open. The current final version stays in force, so the record is not lost, but an error found later cannot be corrected. Who may sign a correction for an author who has left is a clinical and legal rule, so it cannot be invented here. UNKNOWN; owner `clinical` + `legal`. | `correct_report` 0016:343-349 (`r.performer_id` copied); `sign_report` 0016:262 | The PO opens a decision (`clinical`, with `legal`): who may correct and sign a correction of a report whose author is no longer in the team. Until it is answered, engineering refuses `correct_report` with a clear reason when the performer is not a team member, instead of creating an unsignable draft. pgTAP. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-09 | **closed** | `private.release_member_visits` releases `planned` visits whether suspended or not (0036:55; the `suspended_at is null` condition is gone). pgTAP 036:121-153: pause → removal → resume, the near and later visits have no responsible member, carry the `uncovered` flag, and appear in `derived_exceptions` |
| CGR-10 | **closed for the responsible person**; the performer path stays open as CGR-18 | 0036:105-111 refuses `has_visit_in_progress` for `on_the_way`, `started` and `paused`; pgTAP 036:89-116 tests each status alone, nothing is released, and she stays a member |
| CGR-17 | **closed** | #140 merged (`c933656`): the D-27 row in `OPEN_DECISIONS.md` carries the owner's 22:59 interim rule |
| CGR-01 to CGR-08, CGR-11 to CGR-13, CGR-15, CGR-16 | open, unchanged | no change in 0009, 0016, 0018, 0019, 0020, 0022-0024 since `b546299`; all carried in CSR1 (issue #149) or ABS1 |

### Other changes reviewed (no finding)

- **ADM1 privacy fix:** the team-readable `released` row carries only "Mitglied aus dem Team entfernt"; the reason stays in `change_log`. 0036:113-114; pgTAP 036:164-166. Endorsed.
- **Role change keeps team visits** (`set_member_role` touches no visit; ADR-046): a nurse who becomes coach can still start her visit. pgTAP 036:180-189. No safety objection: qualification and membership are unchanged.
- **Legacy heuristics removed** (CR-034 → DEPRECATED, now removed). Intake and team-assignment alerts remain covered by OPS1 (`case_not_ready`, `offer_overdue`, `candidates_exhausted`). Low and medium open quality events no longer appear on `/operations`; they stay in the QG1 list. No finding. Serious events depend on OPS1 alone now, which raises the weight of CGR-05.
- **Residual gap of removal (PO 00:10):** a removed member's planned visit dated before today is not released (0036:56). It is now a CSR1 criterion under CGR-04 (`briefs/CSR1.md`). Endorsed; it closes with CGR-04.
- **CSR1 BL-8 and BL-9:** added as conditions with testable criteria, as recommended at 23:05. They match the risks. Status in the register: in a brief.

### PO challenge answered (journal 01:10)

The PO proposes that `cra` reviews clinical-scope PRs **while they are open**, so that merge and acceptance fall in one PO cycle. **Agreed.** The gate is unchanged. From this run on I review every open PR in scope at its current head and comment there. A section on the merge commit is then needed only when the merge brings in changes I have not reviewed. This run found CGR-18 only because the merged code was read again against the report functions; a review of the open PR would have found it a cycle earlier.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ADM1 (#135 merged, #153 `delivered`) | **not acceptable yet** | CGR-18 blocking. CGR-09 and CGR-10 (responsible person) are met; the privacy fix and the role-change rule are endorsed. Acceptance waits for one small change to `remove_team_member` with its pgTAP cases. |
| F6, F7 | changes-requested (unchanged) | CGR-02, CGR-03; CGR-19 advisory added |
| CSR1 | approved, unstarted | no change; recommend that the CGR-18 change rides with CSR1's first PR or a small ADM1 follow-up, whichever is first |
| ABS1 | brief amended, unstarted | ABS1 reuses `private.release_member_visits`; the CGR-18 performer check applies to an absence too (a nurse going absent with an unsigned report). Recommend adding it to ABS1's criteria |
| All other items | unchanged | as in the 22:30 and 23:05 sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Without that, Gate C cannot open.
- **po:** open a decision for CGR-19 (owner `clinical`, with `legal`): who may correct and sign a correction of a report whose author has left the team.
- **clinical** (once named): D-28, D-16, D-17 first.
- **legal:** D-18, D-22.

---

## 2026-10-22 23:05: owner decision D-27

**Trigger:** the owner decided D-27 on 2026-10-22 at 22:59. No code was merged since the baseline. #139 (governance), #137 and #136 (PO) are docs-only.

**Owner decision, as given:**
- The Clinical & Regulatory Architect remains an **advisory** role. It may review, challenge, recommend, identify risks and identify controls.
- It may **not** approve clinical rules.
- **Until a named, qualified clinical owner is appointed, all clinical decisions remain OPEN and are treated as provisional.** Engineering may implement safe defaults, but no clinical rule may be marked clinically approved.

**What this means for the gate:**

1. **Findings:**
   - Every finding in this report is a recommendation, not a rule.
   - A `blocking` finding stops acceptance. That follows from the PO/README gate, not from any authority of this role.
   - Each finding's remedy is an engineering control or a request for a decision. None is an approved clinical rule.
2. **Decisions:**
   - D-6, D-10, D-15, D-16, D-17 and D-19 (`clinical`) **cannot move to *Decided*** while `clinical` is unnamed.
   - The PO may sharpen them but not answer them. Neither may Engineering or this role.
3. **Safe defaults:** the provisional defaults in code stay. Where a finding needs a threshold that only `clinical` can set (CGR-04 missed-visit threshold, CGR-13 hold semantics), engineering implements a **strict provisional default** and registers it as `PROVISIONAL`. Strict means it alerts or blocks earlier, never later.
4. **Clinical Rule Register:** the status `APPROVED` is unavailable until `clinical` is named. All 34 rules stay `UNVALIDATED`, `PROVISIONAL` or `DEPRECATED`.
5. **Pilot impact:** without a named clinical owner, Gate B (synthetic-data staging) can complete its engineering items, but **Gate C (real clients) cannot open**. It needs answered clinical decisions (G-1, S1).

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-17 | protocol (D-27 row) | blocking (governance) | #136 was merged at 22:40 with D-27 recorded but without the owner's interim rule. Without it, a later cycle could treat a provisional default or an Architect recommendation as decided. | `OPEN_DECISIONS.md` D-27 row on `recovery/main` @ bf5ed02; owner decision 22:59 | The owner's interim wording is added to the D-27 answer, attributed to the owner, by the governance PR that carries this section. It resolves on merge. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-14 | **closed** | #136 merged (bf5ed02): README *Roles* has `cra`, a reviewer without decision rights, and `clinical`, the named, qualified human |
| CGR-01 to CGR-13, CGR-15, CGR-16 | open, unchanged | no code merged since `b546299` |

### PO response reviewed (#141, merged 23:00)

| Check | Result |
|---|---|
| Gate applied to accepted items | F1-F4, F6, F7, J3, J5, OPS1 and C1 set to `changes-requested`, which is correct under the README gate |
| CSR1 brief (`briefs/CSR1.md`) | carries CGR-01 to CGR-08, CGR-12 and CGR-13 with testable criteria matching the report's remedies; no clinical threshold invented (D-28); strict provisional defaults must be registered |
| D-28 (missed and overdue visit thresholds, `clinical`) | correctly routed; stays OPEN under D-27 |
| D-29 (qualification verification, `owner`) | correctly routed; synthetic data only until answered |
| ABS1 amended; ADM1 stays on #135 | consistent with CGR-09 to CGR-11 and CGR-15; I will review them at delivery |
| Not yet in any brief (advisory, S2) | BL-8 (a billing fact stays billable after a later hold) and BL-9 (working-time facts miss corrections), both in the Safety Risk Register. Recommend adding them to CSR1 as conditions |

### Decisions requested

- **owner (now the critical path):** name the qualified clinical owner, with a deputy. It becomes the *Participants* row "Human clinical owner (named, qualified)" from #136.
- **owner:** D-1 and D-11.
- **legal:** D-18 and D-22.

---

## 2026-10-22 22:30: baseline review and first gate

**Scope:** `recovery/main` @ `b546299`, plus open PRs #135 (ADM1 changes), #136 and #138 (role and gate), and #137 (PO cycle). I read migrations 0001–0036, `src/features`, pgTAP and e2e tests, all briefs, `OPEN_DECISIONS.md`, `NEXT_CAPABILITY.md`, `JOURNAL.md`, the engineering registers, the ops reports and the product documents.

**Not done:**
- I did not run the tests. CI results are taken as reported in the PRs.
- The live database and hosting were not accessed.
- The *Architecture Handbook* is not in the repository: **UNKNOWN**.

**Overall: not ready for real clients, real health data or invoicing.**
- The engineering foundation is strong: append-only events, immutable signed reports, audited commands, scoped access rules.
- No clinical rule has qualified approval (Clinical Rule Register: 0 of 34 approved).
- No clinical or legal person is named (G-1).
- Ten S1 safety gaps are in shipped code.

No LTCF, PAG or MQI logic exists in the code, which is correct.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-01 | F1-F4 | blocking | Any team member can supersede a colleague's observation. The new version carries the editor as author, and read models show only the latest version. | `record_observation` 0009:104-111 (no `prev.author_id = uid`) | Reject superseding unless the caller wrote the previous version. pgTAP: a colleague's supersede is `rejected`. |
| CGR-02 | F6, F7 | blocking | Signing rebuilds the snapshot at the moment of signing, so a colleague's later observation or time correction is signed unseen. | `sign_report` 0016:269; `report-section.tsx:183` | The sign command carries the version or hash of the snapshot shown, and is rejected when the facts have changed since. pgTAP + e2e. |
| CGR-03 | F3, F6, J5 | blocking | Time corrections and observations are accepted after the report is `final`. Billing reads the live, corrected times instead of the signed snapshot. | `correct_visit_time` 0008:73-130 (no report check); 0009:100; 0023:28-50, 89 | After `final`, changes go only through a correction version of the report (F6 path) or are refused. Billing facts take minutes from the signed snapshot. pgTAP for both. |
| CGR-04 | OPS1, C1 | blocking | A planned visit whose start passes without a start, or a visit left `started` or `paused`, raises no exception. The "uncovered" exception looks only ahead of `now()` and disappears at start time. | exception lists 0019:34-47 and 0024:443-447; 0024:491-492 | New exception types that persist until a person resolves them. Thresholds are set by `clinical`; until then, a strict provisional default listed as `PROVISIONAL` in the rule register. pgTAP. |
| CGR-05 | OPS1, QG1 | blocking | A serious quality event leaves OPS1 as soon as it is set to `in_review`. The escalation clock starts at `created_at`. | 0019:199-202, 252-253; 0024:513-516 | The exception stays until the event is `closed`; escalation continues in `in_review`. pgTAP. |
| CGR-06 | OPS1 | blocking | Closing an exception with any reason closes it permanently for that cause, including P1 `no_show_open` with no recorded outcome. | 0019:270 (`closed exceptions stay closed for this cause`) | A P1 safety exception re-opens while its cause persists, or cannot be closed until the cause is resolved. pgTAP. |
| CGR-07 | J5 | blocking | Billing has three gaps:<br>• An order `present` with no end date is valid forever.<br>• An expired order does not affect A/C minutes.<br>• Every case is priced at KVG insurer rates whatever its insurance type. | 0023:114, 117; 0023:221-224 | Add three not-billable reasons: `order_validity_missing`, `order_expired`, and `payer_not_modelled` for non-KVG cases. pgTAP. |
| CGR-08 | J5 | advisory | Canton-sourced values are seeded as federal (`CH`): rates from a Graubünden publication, the minimum from a Basel-Stadt leaflet. The KLV citation differs from the brief, and the code reads the minimum differently from the brief. | 0022:52-60; 0023:124; `briefs/J5.md:63` | Mark these rows unvalidated in the data itself, so the preview shows it. Re-seed for the pilot canton once D-11 and D-18 are answered. |
| CGR-09 | ADM1 (#135) | blocking | Removal does not release her **suspended** visits. `resume_case` later reactivates them with a person who is no longer a team member as responsible, so they look covered. | `release_member_visits` 0036 (`x.suspended_at is null`); `resume_case` 0024:253 keeps `responsible_user_id` | Release suspended visits too, or have resume clear a responsible member who is not an eligible team member. pgTAP: remove → resume → the visit is uncovered. |
| CGR-10 | ADM1 (#135) | blocking | Removal while she has a visit `on_the_way`, `started` or `paused` deletes her membership. She can then no longer complete or document it, and no exception covers the stuck visit. | 0036 releases `planned` only; membership deleted unconditionally | Refuse removal while she has a visit in progress (new result `has_visit_in_progress`). pgTAP. |
| CGR-11 | F0 (#38), ABS1 | blocking for ABS1 | A qualification change from `registered_nurse` to `care_assistant` leaves her responsible for category B and needs-assessment visits she may no longer start. They look covered until the start fails. | `set_member_qualification` 0018:133-174 | `set_member_qualification` uses the same release rule for visits she is no longer eligible for. Test in ABS1's delivery at the latest. |
| CGR-12 | J3, C1 | blocking | The registered-nurse check applies only at the first start, so a care assistant can resume and complete a B or needs-assessment visit. | 0024:125 (`old.status in ('planned','on_the_way')`) | Apply the check to every transition into `started` and `completed` for those visits. pgTAP. |
| CGR-13 | QG1 | advisory now, blocking before real data | A hold blocks only billing. The visit can still be started, and planning, cover and matching ignore holds. | `visit_has_open_hold` used only in 0020, 0022, 0023 | `clinical` defines what a hold stops (D-16); engineering enforces it. Until then, label holds in the UI as "billing hold" so nobody reads them as a care stop. |
| CGR-14 | protocol (#136, #138) | blocking for #136 | #136 makes the Architect the owner of the `clinical` decisions. An AI reviewer must not be the deciding owner of clinical rules; D-27 itself recommends a named, qualified person. #136 and #138 also define different role names and report paths. | #136 README *Roles*; #138 `cra` role | Adopt #136's gate wording, which is the stronger one. Keep `clinical` as the named qualified person, and record the Architect as a reviewer (#138's `cra`, or `clinical (review)` without decision rights). One report path: this file. Answer D-27 with a named person. |
| CGR-15 | ABS1 (brief) | advisory on the brief, blocking at delivery | ABS1 claims "needs no open decision", but it decides who takes an absent nurse's visits. It must reuse one eligibility rule covering suspended, in-progress and qualification-restricted visits (CGR-09 to CGR-12), and released visits must stay alerted after their start time (CGR-04). | `briefs/ABS1.md`; `NEXT_CAPABILITY.md` | Add these acceptance criteria to the brief before engineering starts. |
| CGR-16 | F0, ADM1 | advisory now, blocking before real data | A qualification is a label set by an administrator, with no evidence of registration and no expiry. | grep: no GLN, NAREG or MedReg fields | Owner and `clinical` define the verification step. A qualification is active only after evidence is recorded. |

### Gate status per item

**Earlier acceptances.** Accepted items stand under the protocol; the findings above apply to them as blocking. The PO sets `changes-requested` on F1-F4, F6, F7, J3, J5, OPS1 and C1. These are bundled for engineering as one item, the **Clinical safety remediation (CSR1)**, ranked above ABS1.

| Item | Result | Findings |
|---|---|---|
| ADM1 changes (#135) | **not acceptable yet** | CGR-09 and CGR-10 blocking. Changes 1–4 and the removal of legacy unvalidated heuristics (CR-034) are endorsed. The PO's privacy fix (#137) is endorsed. |
| ABS1 | brief to amend before start | CGR-15 and CGR-11 |
| F1-F4 | changes-requested | CGR-01, CGR-03 |
| F6, F7 | changes-requested | CGR-02, CGR-03 |
| J5 | changes-requested | CGR-03, CGR-07; CGR-08 advisory |
| OPS1, C1 | changes-requested | CGR-04, CGR-05, CGR-06, CGR-12 |
| J3 | changes-requested | CGR-12 |
| QG1 | condition | CGR-13 |
| #136, #138 | reconcile | CGR-14 |
| HAND1, RET1, AN1, PLAN2, J6, J1, J2, COVER1 (off) | no blocking finding | advisory risks are in the Safety Risk Register (C-8, PS-9, PS-10, LT-3) |

### Decisions requested (no answer is assumed)

- **owner:**
  - D-27: name the qualified person who confirms clinical rules;
  - D-1: is the live data real?
  - D-11 and D-12.
- **clinical** (once named):
  - D-16 and D-17 first (escalation and safety alerts);
  - then D-19, D-15, D-10 and D-6;
  - plus the thresholds for CGR-04, and reassessment triggers.
- **legal:** D-18, D-22, D-9 and D-4.

**Next review:** the next scheduled governance cycle, or earlier when a PR in scope is opened.
