# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

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
