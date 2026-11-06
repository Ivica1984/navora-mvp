---
id: QUAL1
title: Qualification profile and activity rule on every assignment path, with the nursing-home cover simulation
author: po
status: approved
updated: 2026-11-06
---

# QUAL1 — Qualification profile and activity rule on every assignment path, with the nursing-home cover simulation

**Approved 2026-11-06 22:30 CET by `po` for synthetic data only** (founder decision FE-040; Blueprint §1.4, §1.6; constellations in [`BUSINESS_MODELS_AND_CONSTELLATIONS.md`](../../product/BUSINESS_MODELS_AND_CONSTELLATIONS.md)). Every rule this item builds is **PROVISIONAL**: the matrix cells are PROPOSED ([`QUALIFICATION_MATRIX.md`](../clinical/QUALIFICATION_MATRIX.md) v0.1, CR-174 to CR-178; **v0.2** merged 2026-11-06 22:40 with CR-179 to CR-184, also PROPOSED). **Passing the simulation is not a clinical release** for Phase B or for any real client, resident or employee (CGR-145, CGR-146, FE-039). Build order: after the PLAN3 stack is consolidated (FE-037/FE-038); `eng` may start the database part earlier only if it does not touch a file of an open stack PR.

## Problem
Today NAVORA knows two qualification values (`registered_nurse`, `care_assistant`) and one coarse rule: KLV-B minutes or a needs assessment need a registered nurse (CR-007, CR-164). An order does not name its concrete activities. A nursing home's short-notice absence is therefore covered by phone and by whoever answers, and a proposal cannot say *why* a person is allowed to do the activities, or why nobody is. The founder requires that a self-organised team never gets a suitability claim the evidence does not carry (FE-039) and that no path (manual assignment, take, swap, cover) can bypass a rule the proposal respects (FE-040).

## Users and journey step
Members of a self-organised team (planning, taking, swapping, covering); the delegating nurse (`nurse_hf_fh`); the professional-responsibility role (CR-178, simulated in Phase A); the simulated nursing home that reports an absence (KON-1, KON-2). Journey steps: Referral/order → Matching → Team decision → Planning → Visit.

## Outcome
For every visit, NAVORA knows the activities it requires and, for every candidate, whether each activity is allowed on her own, only with a valid delegation, not allowed, or unresolved, and on which evidence. The same database check decides every assignment path. A nursing-home absence produces either a reasoned proposal that the team confirms, or a visible care gap escalated to the team and the professional role, never a false "geeignet".

## Acceptance criteria

**Profile and evidence**
- [ ] **QUAL1-1 Qualification values.** A member's grade is one of `nurse_hf_fh`, `fage_efz`, `ags_eba`, `pflegehelfer_srk`, `trained_other` (CR-174). The seed's members get explicit synthetic grades. **The matrix rule is active only in an organisation marked as synthetic/simulation;** every other organisation keeps today's rule (CR-007, CR-164) unchanged, because the matrix loosens CR-007 for FaGe (CGR-145). pgTAP proves both: the old rule outside the simulation organisation, the matrix inside it.
- [ ] **QUAL1-2 Evidence states.** Each grade or experience requirement (e.g. A3 "≥ 2 years") carries a state: `missing`, `self_confirmed`, `verified`, `expired`, `contradictory`, plus a validity date where the evidence type has one. Only `verified` with a validity covering the visit counts. In Phase A the seed's verified evidence is labelled `verified (synthetisch)`; no real document, no real register entry is stored (D-29 decides the real verification).
- [ ] **QUAL1-3 Profile draft and member confirmation.** A profile draft may be prepared by a rule from structured synthetic input (and by an AI only on synthetic data, D-35 rule A); the member reviews and confirms each value. Confirmation sets `self_confirmed`, **never** `verified` (FE-039, FE-040). pgTAP: no function or path sets `verified` from a member's own confirmation or from an agent.
- [ ] **QUAL1-4 Expired evidence.** From the instant its validity ends, evidence counts as `expired` and as absent for E/D. Planned visits of the member that relied on it are released to the team as "Voraussetzung abgelaufen" (CR-051 pattern), with the requirement named. A test clock (`private.now()`) proves the boundary minute.
- [ ] **QUAL1-5 Contradictory evidence.** When two records for the same requirement disagree (e.g. two grades, or a verified record and a newer record that says otherwise), the requirement is `contradictory`: the member is not plannable for the activities that depend on it (treated as "?"), the profile shows "Nachweise widersprüchlich", and the professional role gets one notice. Nothing is resolved automatically. *(PROPOSED product default; `cra` confirms.)*

**Activities and the matrix**
- [ ] **QUAL1-6 Activities on the visit.** A visit (and an order line from a partner) carries one or more matrix activity IDs (A1-A4, B1-B13, C1-C3, N1). Existing KLV minutes stay; a visit with KLV-B minutes and no activity ID is treated as B13 ("any Bst. b activity not listed"), a needs assessment as A1. pgTAP on the seed.
- [ ] **QUAL1-7 Matrix as versioned data.** The matrix is stored as data (version, activity, grade, value E/D/–/?, status `PROPOSED`/`APPROVED`, source tag), never as code constants. Every row in Phase A has status `PROPOSED`. The version used is recorded with every check.
- [ ] **QUAL1-8 One decision function.** One database function returns, for (member, visit), per activity: `allowed_own` (E with verified grade), `allowed_delegated` (D with verified grade **and** a valid delegation, QUAL1-9), `not_allowed` (–), `unresolved` (?), or `evidence_missing` / `evidence_expired` / `evidence_contradictory`, with the matrix version and the rule status. "?" is never allowed (strict reading, matrix §3 legend).
- [ ] **QUAL1-9 Delegation record (CR-176).** Recorded only by a member with verified `nurse_hf_fh` of the same team; names activity, case, member, instruction date, a fixed end date, supervising nurse, optional conditions; append-only, revocable, audited. It is valid only for that activity, case and member, between its dates, while the delegating and supervising nurse still hold access. **No agent and no rule creates, extends or infers a delegation** (pgTAP: the AIG1 ledger has no target on the delegation table; AIR1 catalogue test extended).

**Every path**
- [ ] **QUAL1-10 The rule on every path.** A member can be set as responsible for a visit only if every activity is `allowed_own` or `allowed_delegated` (CR-177). The same function is called, and a refusal names the activity and the reason, on: PLAN3 proposal and confirm, PLAN2 series, hand assignment, take (self-assignment), **swap (both sides re-checked)**, cover (COVER1 `accept_cover`), re-assignment after an absence (ABS1), **the NH-EXT offer and its acceptance, and again at visit start** (QUAL1-17). pgTAP proves each path refuses the same (member, visit) the proposal excludes; there is no override parameter.
- [ ] **QUAL1-11 Overlap stays a fact.** A time overlap is shown, not refused (CGR-137, CGR-144, founder decision); but the cover and day-plan proposals never propose a member who overlaps (as today, CR-164). A hand assignment with an overlap shows the fact and still runs QUAL1-10.

**The cover simulation (founder acceptance criterion, FE-040)**
- [ ] **QUAL1-12 Simulation scenario on new synthetic data.** A new, separate synthetic fixture (not the existing seed people): one simulated nursing home (ward "Synthetisch Station A"), one external self-organised team (KON-1) and one home team (KON-2), members with grades and evidence states, delegations, one resident case, one visit window. The home reports a short-notice absence for that visit. NAVORA derives the required activities and the time window, searches within the team's rules, checks per candidate qualification, evidence and delegation, and produces the result below.
- [ ] **QUAL1-13 Expected results (each a pgTAP test and an e2e step at 390 px and 1440 px):**

| Case | Synthetic setup | Expected result | Human decision point |
|---|---|---|---|
| S1 suitable cover | visit needs C1 + B3; candidate FaGe with verified grade and a valid B3 delegation for this case; free, no overlap | proposal "Vorschlag: <Name>" with reason (grade, delegation until <date>, continuity), all requirement states *nachgewiesen (synthetisch)*, rule status *PROPOSED* visible | team confirms (AIG1); member informed; decision recorded |
| S2 missing evidence | best candidate's grade is `self_confirmed` only | candidate **not** proposed; line "kein Vorschlag" names "Nachweis fehlt: Ausbildung"; if nobody else fits → S6 | none possible on that person; escalation |
| S3a missing delegation | FaGe verified, no delegation for B3 on this case | not proposed; reason "Delegation fehlt (B3)" | a `nurse_hf_fh` may record a delegation (human act); the AI never does |
| S3b expired delegation | delegation ended yesterday | not proposed; reason "Delegation abgelaufen am <date>" | as S3a |
| S4 unresolved matrix cell | visit needs B4 insulin for FaGe (matrix "?") | FaGe not proposed; reason "Regel ungeklärt (B4, PROPOSED ?)"; only `nurse_hf_fh` candidates considered | professional role / Clinical Owner (K-2) |
| S5 time overlap | the only qualified member already has an overlapping visit | not proposed by the agent; a hand assignment shows the overlap fact and still runs QUAL1-10 | team decides whether to reorganise |
| S6 no suitable cover | no candidate passes | **no person shown as suitable**; a visible care gap ("Versorgungslücke: Station A, <Zeit>, B3 fehlt") on the team's day plan; escalation to the team and to the professional role (simulated CR-178) through the existing signal path; the visit stays open | team and professional role decide (e.g. reorganise, request help, inform the home) |
| S7 bypass attempts | after S2/S3/S4, a member tries hand assignment, take and swap of the same visit | each refused with the same reason as the proposal (QUAL1-10) | none |
| S8 expired evidence during the day | grade evidence validity ends 10 minutes before the visit start (test clock) | planned assignment released "Voraussetzung abgelaufen"; S6 path if no replacement | team |

- [ ] **QUAL1-14 Expected vs observed table.** Engineering writes the observed result of every case next to the expected one in the ADR and the PR (from the pgTAP and e2e output in CI), and the PO copies it into this brief at acceptance. The screen and the test names show "Simulation · synthetische Daten · Regeln PROPOSED".
- [ ] **QUAL1-15 Recorded decisions.** Every proposal, confirmation, refusal, escalation and delegation in the simulation appears in the AIG1 ledger or the audit trail with time, actor and reason; never per person in any measure (AN1 rule).
- [ ] **QUAL1-16 Negative cases (who must NOT):** an AI or rule sets `verified` or a delegation (refused); a member assigns herself an activity she is not allowed (refused); a member of another team reads the delegation records (refused, RLS); a `fage_efz` records a delegation (refused).

**Added 2026-11-06 22:40 by `po` (matrix v0.2, before any build started; CGR-147, CGR-148)**
- [ ] **QUAL1-17 Check at visit start (CGR-148, CR-183).** The QUAL1-8 function runs again when a visit is started. If a grade evidence, a delegation or the delegating nurse's access has lapsed since planning, the start is refused with the reason, the visit is released to the team as open with a coverage fact (CR-051 pattern), and delegations recorded by a nurse whose own evidence lapsed are marked "Überprüfung nötig" (none is deleted). The four result labels shown are those of CR-183 (`geeignet`, `geeignet mit Delegation`, `nicht geeignet`, `ungeklärt`); only the first two allow responsibility, and `ungeklärt` is never shown as suitable or scored. pgTAP: matrix v0.2 §7 AK-6, AK-7, NT-2, NT-8, NT-10, with the test clock.
- [ ] **QUAL1-18 External team in a nursing home (NH-EXT) in the simulation (CGR-147, CR-180, CR-182, CR-184).** A simulated NH-EXT order is offerable only with a complete structured *Einsatzvereinbarung* (context, canton, activity list, matrix version, who delegates, the home's reachable formal function, start, end); one with a missing field is not offerable and names the field (NT-9). Until `lca` answers L-7, every D cell and every Bst. b E cell counts as `ungeklärt` in NH-EXT (CR-180). An unresolved gap escalates first to the home's formal function named in the *Einsatzvereinbarung*, then to the team's (CR-184). Both delegation variants of matrix v0.2 §2.3 run as separate synthetic fixtures; neither is presented as the lawful one.
- [ ] **QUAL1-19 Matrix v0.2 tests mapped.** Engineering maps every acceptance criterion AK-1 to AK-10 and negative test NT-1 to NT-10 of matrix v0.2 §7 to a pgTAP or e2e test or to a case S1 to S8, and lists any it cannot build on synthetic data with the reason; the PO decides each at acceptance.

## Rules and their input class
- QUAL1-8/-10 activity rule: *care-context fact recorded by a person* (grade, evidence, delegation) gating an assignment; **for the adviser and the Clinical Owner**: built and tested on synthetic data only, not released to real clients before the matrix cells are `APPROVED` (D-43, K-1) and D-29 is decided (CGR-145).
- QUAL1-4/-5 expiry and contradiction defaults: *care-context fact recorded by a person*; PROPOSED product defaults, `cra` confirms.
- QUAL1-11 overlap: *visit/schedule fact*; display only (unchanged).
- QUAL1-13 S6 escalation: reuses SIG1/SIG2 delivery (thresholds PROVISIONAL, D-28).

## AI leverage
1. **Remove:** the phone and message chain to find a cover; manual checking of who may do what; the temp-agency call for a gap the team can cover.
2. **Rules:** the activity rule (QUAL1-8/-10) is deterministic, in the database, versioned.
3. **Monitor:** expiring evidence and delegations (≤ 14 days, placeholder, K-4) and uncovered visits are watched continuously.
4. **AI prepares:** the planning agent (PLAN3 contract, level L) ranks only candidates that pass the rule and writes the reason; on synthetic data it may draft a profile from structured input. Stop rule: no candidate passes → it proposes nobody and states the gap.
5. **Human reviews:** the team sees reason, requirement states and rule status.
6. **Human decides:** the team confirms the cover; a `nurse_hf_fh` records a delegation; the professional role handles escalations.
7. **Human signs:** delegation and confirmation are personal, recorded acts.

Removed step and baseline: time from absence report to confirmed cover, share of absences without a proposal, number of contacts per cover (AN3 span added for the simulation; baseline from the synthetic run only, Phase B baseline from the partner's records, AUT-57). Gate: D-35 rule A (synthetic only), D-34 core (no clinical content: the matrix is a rule set approved by the clinical function, the AI does not judge competence). **The AI must never:** grant or extend a delegation, upgrade an evidence state, propose a member a rule excludes, phrase a missing prerequisite as met, or recommend "trotzdem einsetzen".

## Out of scope
Real evidence verification (D-29), the approval of any matrix cell (K-1 to K-6, D-43), nursing-home shift minimums (K-5, NH-A), billing of the cover (D-44, L-7/L-8), the B2B product packaging (FD-29), any real partner.

## Constraints and references
FE-039, FE-040; CR-007, CR-009, CR-051, CR-164, CR-174 to CR-184; CGR-137, CGR-142, CGR-144, CGR-145, CGR-146, CGR-147, CGR-148; D-27, D-29, D-34, D-35, D-40, D-43, D-44; PLAN3, PLAN2, ABS1, COVER1, AIG1, AIR1, SIG1/SIG2; Blueprint §1.4, §1.6.

## Open questions for engineering
1. Where the activity IDs live (visit row, order line, or a join table) and how the B13/A1 fallback is migrated without changing any existing visit's outcome.
2. Whether the decision function extends `private.may_perform_visit` or replaces it behind the same name (one function on every path is the requirement).
3. How the simulation fixture stays separate from `supabase/seed.sql` (own file, loaded by its tests).
4. The cost of the swap re-check on both sides inside one transaction.
