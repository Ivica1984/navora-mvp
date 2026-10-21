# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

## 2026-10-21 23:20 · eng (Lead Engineer)
- **J1 PO changes merged** (#30) and **J3 PO changes merged** (#32), CI green. Both are `delivered` and wait for PO acceptance against their briefs. Open clinical items: D-15 (checklist, care-plan fields, KLV mapping) and D-17 (safety-alert list).
- CI found a real bug on the way: the audit log rejected a second audit row for the same case under one command key. Fixed by dropping that uniqueness; replay protection is unchanged.
- **F0 report** published: `reports/F0.md`. Main gap: nurses can still read clinical fields of other teams' cases in the legacy tables (SR-22). Engineering starts on that next (F0 step 1). **PO question:** which commands need a mandatory reason (criterion 5)?

## 2026-10-21 22:40 · eng (Lead Engineer)
- **J3 changes** in review (ADR-030): care-plan summary with KLV category, planned minutes, frequency, review date and care goal; minutes per category on every visit; needs assessment first; B only with a present order; B and needs-assessment visits started only by a registered nurse (DB-enforced); inform-GP task; reassessment, order-expiry and uncovered flags; Operations exception; change log with reasons; care goals on the `/field` card.
- Stacked on J1 (#30). Next per the PO queue: F0 per-criterion report, then F6.

## 2026-10-21 22:10 · eng (Lead Engineer)
- Read PR #28 (PO briefs, re-ranked queue, decisions). Status rows refreshed: draft items QG1, OPS1, J5, J6, J7 acknowledged as `not-started`; COORD-1, COORD-2 and Q4 no longer listed as blockers. PO: please move them to *Decided*.
- **J1 changes** (residence, insurer, insurance type, medical order status, readiness gate, server-side matching only when ready, tasks, protected insurer data) are in review: ADR-029. Safety alerts wait for the D-17 list.
- **J3 changes** (care-plan billing fields, planned minutes per KLV category, needs-assessment first, B only with an order and a registered nurse) in progress, stacked on J1.
- **F0** per-criterion report follows after J3, because J3 adds member qualifications as data (an F0 criterion).

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
