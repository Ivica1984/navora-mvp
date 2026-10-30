---
id: VIS2
title: A second visit of the same client at the same time is visible before it is saved, and two such cards can be told apart
author: po
status: approved
updated: 2026-10-30
---

# VIS2 — Same-client overlap is visible before saving; same-slot cards are distinguishable

## Problem
`cra` CGR-97 (advisory S3, review 2026-10-29 23:10, PR #696; H-25, PS-86): neither planning (J3, PLAN2) nor VIS1 "Heute machen" (`move_visit_to_today`) checks whether the client already has a visit at an overlapping time on the target day. IMPLEMENTED fact (`cra`: no same-client overlap check in `supabase/migrations`). Two visits of one client at the same time then render as two `/field` cards with the **same accessible name** ("22:40 – 23:10, Testfall 08"); CGR-96 showed this happen in CI (two different synthetic visits, `e2e` red on `recovery/main` `1500cb3`). An intended double visit exists (two people for one transfer), so refusing it would be an invented rule. An unintended duplicate (planned twice, or moved onto an existing visit) gives a nurse two cards she cannot tell apart: one can be documented on the wrong visit, or both performed and recorded, a second billable fact for one service (H-14, H-25).

## Users and journey step
The nurse who moves a visit to today (VIS1) and the team member who plans or reschedules a visit (J3, PLAN2); the nurse reading `/field` on her phone. Journey: Planning → Visit (`ARCHITECTURE.md` data flow).

## Outcome
Whoever is about to put a second visit of the same client into an overlapping time on a day reads one factual sentence before she saves, and decides; nothing is refused. Two cards of the same client and time on `/field` can be told apart by sight and by a screen reader.

## Acceptance criteria
- [ ] **VIS2-1 Overlap fact before saving (planning and "Heute machen").** When a visit is created or rescheduled (J3 planning form, reschedule, VIS1-3b "Heute machen") and the client already has another non-cancelled visit on the target date whose time overlaps the chosen time, the confirmation shows one sentence in style `info` before saving, for example "Bei dieser Person ist am <Datum> um <Zeit> bereits ein Einsatz geplant." (wording `uxa`'s). No refusal, no extra tap, no warning colour above `info`, no reason field. The save goes through unchanged when she confirms.
- [ ] **VIS2-2 Team boundary (as VIS1-8 (2)).** If the overlapping visit belongs to a team the person cannot read, the sentence states only that a visit exists at an overlapping time on that date, with no team, member, service or time of the other visit; it never says "no visit" while one exists that she cannot read. The fact is computed by a SECURITY DEFINER function that returns yes/no (and, for a readable visit, its time) only for a client whose case the caller may already read (RLS2); no new read of another team's visit. Named in `READ_PATHS.md`.
- [ ] **VIS2-3 Distinguishable cards.** On `/field`, two cards of the same client whose times overlap carry different accessible names and a visible distinguishing line (for example the responsible member's display name or the planned service; choice and wording `uxa`'s). One card per visit row, as today.
- [ ] **VIS2-4 Audit.** The command's existing audit row records `overlap_shown: true|false` as a code value (AUD1 classes it `code`); no new audit table.
- [ ] **VIS2-5 The shown fact is the fact at save** (added by po 2026-10-30 00:15 before build; `uxa` UXR-50, medium, PR #685). (1) The sentence is computed for the times in the form, re-read whenever "Von" or "Bis" changes (debounced) and whenever the form is offered again; it appears and disappears with the times and is announced as a polite `role="status"`. (2) The save re-checks on the server; if it finds an overlap the form did not show (edited times not yet re-read, or a visit added meanwhile), the save still goes through and the result notice on the card carries the same sentence. VIS2-4 `overlap_shown` records what the form showed; the command's result states what the server found. Still no refusal and no extra tap. **Tests:** e2e at 390 px: open "Heute machen" on a free slot (no sentence); set "Von"/"Bis" onto the seeded visit's time (the sentence appears); set them back (it disappears); save onto an overlap without waiting for the re-read (the save succeeds and the card's notice contains the sentence). pgTAP: the command's result reports the overlap it found whatever `overlap_shown` says.
- [ ] **Tests (synthetic seed only).** pgTAP: the overlap function returns true for an overlapping same-client visit of the caller's team (with its time), true without detail for an overlapping visit of another team, false for a non-overlapping or cancelled visit and for a different client; a caller who cannot read the case gets nothing; the save of an overlapping visit is not refused (planning and `move_visit_to_today`). Unit: the sentence for the readable and the unreadable case. e2e at 390 px: "Heute machen" onto a slot where the client already has a visit shows the sentence and the move completes; two same-slot cards of one client have different accessible names (this test owns its own client or slot, so it does not depend on another spec's fixtures; see CGR-96).
- [ ] **Negative.** No visit is refused or delayed for an overlap; no reason is required; no colour above `info`; no person or team of a visit she cannot read is shown; nothing is counted per person.

## Rules and their input class
- VIS2-1/-2 overlap fact: *visit/schedule fact* (two recorded visit times of one client); display only, it does not rank, route or escalate. **No rule is set** on whether a same-client overlap is allowed, needs a reason or a second confirmation, or how it is billed: Clinical Owner and billing owner (`cra` CGR-97 asks them; UNKNOWN). If one is ever set, it is a register row with owner `clinical`, PROVISIONAL, raised before build.

## Out of scope
- Any refusal, reason code or second-person confirmation of an overlap.
- Overlap across different clients for one nurse (her own double booking: PLAN3 "within … overlap" covers proposals; a manual check is a later item).
- Billing de-duplication: J5 facts rest on signed reports; whether two overlapping visits of one client are both billable is D-18 / the billing owner's.

## Constraints and references
- `cra` CGR-97 (PR #696), CGR-96 (#693), VIS1-8 pattern (fact sentence, team boundary), RLS2, READ_PATHS, AUD1 code classes. `ARCHITECTURE.md`: the record shows facts, the team decides.
- Synthetic data only (owner rule 2026-10-29, D-1). Before G-23 (first real organisation) and before PLAN3 proposals reach a team.

## Open questions for engineering
- Whether one function can serve the J3 form, reschedule and `move_visit_to_today` (preferred: one read path).
- Overlap definition: half-open time intervals on the same date, the same as PLAN3's member-overlap test, named in the ADR.

## PO notes
- **2026-10-29 23:15 CET, approved** from `cra` CGR-97. **Why:** *Why can the same client get two visits at the same time without anyone seeing it?* Because planning and the move were built per visit and never look at the client's day. From scratch, the record that already holds both visits tells the person deciding, at the moment she decides; that costs no tap and needs no dispatcher to spot duplicates later (value 5, value 2 continuity, safety precondition: one documentation per service). Refusing would invent a clinical rule; showing the fact does not.
- Placed after AIG1 and before PLAN3: PLAN3 proposes assignments for existing visits and must not compound duplicates; small (one function, one sentence, one name change).

## PO note — 2026-10-30 00:15 CET: `uxa` answers taken in; UXR-50 adopted as VIS2-5; invoicing note from `lca`

- **Wording (VIS2-1, `uxa` 23:55, PR #685; `cra` to confirm):** "Bei dieser Person ist <heute | am <Wochentag>, <Datum>> von <hh:mm> bis <hh:mm> bereits ein Einsatz geplant." For a visit she cannot read (VIS2-2): "Bei dieser Person ist <heute | am …> zu einer Zeit, die sich mit diesem Einsatz überschneidet, bereits ein Einsatz geplant." Placed below "Von"/"Bis", tied to the save button. **Cards (VIS2-3):** "<i> von <n> zu dieser Zeit" in the accessible name and one `info` line with the responsible member. Engineering uses these strings.
- **UXR-50 adopted as VIS2-5.** *Why does the sentence exist?* So the person deciding knows the day at the moment she saves. A sentence computed once when the form opens can be false both ways after she edits the time, and then it misleads more than no sentence. Re-reading on change costs no tap; the server re-check covers the race.
- **`lca` 23:45 (D-18 re-check on CGR-97, PR #702, read on its branch):** VIS2 as placed is compliant under every plausible interpretation; `lca` needs no read before merge. Invoicing overlapping facts stays unresolved (adviser question 6); carried to any invoicing brief as a prerequisite (see `briefs/J5.md`, PO note 2026-10-30 00:15). VIS2 sets no billing rule.

## PO review — 2026-10-30 01:45 CET: reviewed, criteria met; acceptance after the `cra` gate

**Delivered:** #707 merged `4c8f2a6` (migration 0098, ADR-121; pgTAP 098 (40) and 050/052/093 adjusted to the new result key and signatures; vitest `vis2-overlap`; Playwright `vis2.spec.ts`). CI green on the PR head `7279b53` (Engineering's report) and on the merge commits `4c8f2a6` and `ec07852` on `recovery/main` (`ci` workflow runs 1837 and 1840, `success`). **The PO did not run the tests**; the evidence below is read from the merged code, the tests and CI results.

| Criterion | Result | Evidence |
|---|---|---|
| VIS2-1 Overlap fact before saving (plan, reschedule, "Heute machen") | met | `public.client_visit_overlap` serves all three forms (ADR-121 decision 2); `uxa` sentence in `OverlapNote.tsx`, `info`, below "Von"/"Bis", tied to the save button (`aria-describedby`); e2e `vis2.spec.ts` (plan and "Heute machen" show the sentence, tone `info`); no field or tap added |
| VIS2-2 Team boundary | met | SECURITY DEFINER with fixed `search_path` (pgTAP 098); another team's visit returns `overlap` true with no time (key-set assertion); coordinator without the case's team, a nurse of another organisation and no signed-in user get null (pgTAP 098); never "kein Einsatz" (vitest); `READ_PATHS.md` names the path |
| VIS2-3 Distinguishable cards | met, deviation 1 | "<i> von <n> zu dieser Zeit" in the accessible name and one `info` line; e2e asserts two cards with two different names; half-open grouping and cancelled visits skipped (vitest) |
| VIS2-4 Audit `overlap_shown` | met | recorded on the existing `care_visits` insert row and `visit_plan_changes` `moved` row only (pgTAP 098: what the form showed, not the server check; no other row carries it; old callers record nothing); AUD1 class `code` (pgTAP 098) |
| VIS2-5 (1) Sentence follows the times | met | re-read 250 ms after "Datum"/"Von"/"Bis" change and when the form is offered again, earlier answers discarded (ADR-121 3); e2e: free slot no sentence, onto the visit sentence appears (`role="status"`), back it disappears |
| VIS2-5 (2) Server re-check at save | met, deviation 6 | every `ok` result carries `overlap` whatever `overlap_shown` says (pgTAP 098, `plan_visit` with `false` returns the overlap); e2e: a visit added meanwhile in a second tab, the move is saved and the moved card's notice states the sentence |
| Tests (synthetic seed only) | met | pgTAP 098 (true with time, true without detail, false for touching, cancelled, other client; nobody else gets an answer; saves not refused); vitest readable and unreadable sentence; e2e at 390 px with its own slots (width assertion) |
| Negative | met | pgTAP 098: `plan_visit`, `reschedule_visit`, `move_visit_to_today` save overlapping visits as chosen; no reason field, no colour above `info`, nothing counted per person (no per-person reader added) |

**Deviations (ADR-121), decided:**
1. Card line says "du" / "Teammitglied" / "noch niemand" instead of the responsible member's name: **accepted.** The cards are told apart by "<i> von <n>" and the times; a name needs a new `field_visits` column, which belongs with RLS4 (who reads assignment facts) and is not needed for the safety goal. `uxa` may propose it in UX2.
2. A previous-day visit running past midnight is not counted: **accepted** as the brief's wording ("on the target date"). It belongs to the open DAY-1 question (a night nurse's day is her shift; challenge row "The working day of a field nurse ends at 00:00"); no criterion now.
3. PLAN2-generated visits are not checked: **accepted** (outside the brief). PLAN3 uses the same half-open definition for member overlap (ADR-121 1). When PLAN2 generation is next changed, its result states same-client overlaps the same way; noted for that brief.
4. No rule on whether an overlap is allowed, needs a reason or is billable: **accepted**; stays with the Clinical Owner and the billing owner (`cra` CGR-97; D-18; `lca` invoicing prerequisite in `briefs/J5.md`).
5. Order (VIS2 merged before the CGR-96 fix): **accepted**; its spec uses its own slots and CI is green. CGR-96 (#693) stays first in *Active now*.
6. VIS2-5 e2e uses "a visit added meanwhile" instead of "save without waiting for the re-read": **accepted.** It tests the same server re-check without a timing race, which is what CGR-96 taught us to avoid.

**UX:** the newest `uxa` section on VIS2 (2026-10-29 23:55) has no `severe` or `high` finding on it; UXR-50 (medium) was built as VIS2-5. **Automation:** VIS2 adds no agent or proposal; no `aia` gate.

**Business and care value:** the person who plans or moves a visit sees a duplicate at the moment she decides; nobody checks plans for duplicates afterwards (no dispatcher, no back-office de-duplication) and nothing is refused (value 2 continuity, value 5 less administration; safety precondition: one documentation per service). Consistent with the Handbook principle "the record shows facts, the team decides".

**Decision:** VIS2 is **reviewed and its criteria are met; no Engineering change requested.** VIS2 is in clinical scope (planning, documentation, billing), so acceptance waits for the `cra` section on the merged build (`4c8f2a6`) with no blocking finding on VIS2; then it is accepted without another PO round. PO status stays `approved` until then.

## PO acceptance — 2026-10-30 02:10 CET: accepted; condition VIS2-C1 (`cra` CGR-99)

**Clinical gate:** `cra` review 2026-10-30 01:45 (`reports/CLINICAL_GOVERNANCE.md`, PR #711, not merged under the owner instruction on #666; read on branch `gov/review-2026-10-30-0145`) read #707 on its merge commit `4c8f2a6`: **CGR-97 closed** (remedy met in 0098, pgTAP 098 and `vis2.spec.ts`; PS-86 closed), `uxa` wording confirmed, ADR-121 deviations 1, 2 and 4 agreed, deviation 3 raised as CGR-99 (advisory S3, "does not block VIS2 acceptance"). No blocking finding on VIS2. **The PO did not run the tests**; CI on `4c8f2a6` and `ec07852` green as recorded at 01:45.

| Acceptance condition (01:45) | Result | Evidence |
|---|---|---|
| Criteria VIS2-1 to VIS2-5, tests, negative | met | PO review 01:45 above |
| `cra` section on `4c8f2a6` with no blocking finding on VIS2 | met | `cra` 01:45 gate table: "VIS2 … **clear**; CGR-97 closed; … CGR-99 (S3) separate, does not block VIS2 acceptance" |
| No `severe`/`high` `uxa` finding open on VIS2 | met | `uxa` 23:55; UXR-50 built as VIS2-5 |

**Decision: VIS2 accepted** (queue rank 45). *Why accept with CGR-99 open?* VIS2 delivered exactly what it promised for the three paths where a person decides; the generation path was outside the brief and creates no false statement, only a missing one. Holding acceptance would add no safety and would block nothing less.

**Condition VIS2-C1 (`cra` CGR-99, advisory S3; not blocking; rides the next PR that touches `plan_from_care_plan` (0025) and at the latest the PLAN3 PR, because PLAN3 proposes members for generated visits):**
- (1) Every visit PLAN2 generation creates or keeps that overlaps another non-cancelled visit of the same client on its date (definition 0098 §1, `private.client_overlap_visits`) shows the VIS2-1/-2 sentence on its `/team` line (same strings, same team boundary, `info`, no refusal).
- (2) The generation result states how many such visits it created, as a number ("<n> Einsätze überschneiden sich mit einem bereits geplanten Einsatz derselben Person"; wording `uxa`'s); the result names no person.
- (3) Generation is **not** changed: it neither skips nor refuses a slot. Whether generation should leave out a window already covered by a hand-planned visit is the Clinical Owner's (UNKNOWN; a register row before any such rule).
- **Tests (synthetic seed only):** pgTAP: a hand-planned visit inside a care-plan window, then generation → the visit is generated and the overlap function returns true for it; the result's count is 1; without the hand-planned visit the count is 0. vitest or e2e: the `/team` line of the generated visit shows the sentence.
- **Why:** the count is also the pilot measurement for the challenge row "two plans of one client's day" (hypothesis H-PLAN-dup in `NEXT_CAPABILITY.md`); without it nobody knows whether hand planning and generation duplicate the team's work.

## PO note — 2026-10-30 04:10 CET: `uxa` 03:50 taken in; VIS2-C1 (2) wording fixed; condition VIS2-C2 (UXR-51)

**VIS2-C1 (2) wording (from `uxa` 03:50, `cra` to confirm as CGR-99 owner; not changed by the PO):** shown only when the count is at least 1, as the last line of the generation result, `info`, after the number of visits created, linked to nothing. n = 1: "1 erstellter Einsatz überschneidet sich zeitlich mit einem bereits geplanten Einsatz derselben Person." n ≥ 2: "<n> erstellte Einsätze überschneiden sich zeitlich mit einem bereits geplanten Einsatz derselben Person." No line for 0, never "keine Überschneidung". Added test: unit 0 → no line, 1 → singular, 3 → plural.

**Condition VIS2-C2 (`uxa` UXR-51, medium; not blocking VIS2's acceptance; rides the VIS2-C1 PR and at the latest the PLAN3 PR).** *Why:* the sentence before a save must state the whole fact. 0098 returns the times of the earliest readable overlapping visit only (`client_overlap_fact`, `limit 1`), so with two overlaps, or one readable plus one of another team, she checks one visit, finds it harmless and saves without knowing of the other. Nothing false is shown, but the statement reads as complete; a missed second visit is a double booking at the client's door.
- (1) `private.client_overlap_fact` additionally returns `count` (number of overlapping visits per `private.client_overlap_visits`, every team) and `unreadable` (true when at least one of them fails `private.reads_visit`). No other field: still no team, member, service or time of a visit she cannot read (VIS2-2 unchanged). No new read permission, no refusal, the three commands unchanged.
- (2) The sentence states the count when it is 2 or more and, when any overlapping visit is unreadable, says so; wording `uxa`'s (its 23:55 plural form and "unreadable wins when mixed" rule are the starting point), `cra` confirms. A single readable overlap keeps today's VIS2-1 sentence word for word.
- (3) VIS2-5 after-save notice and the `/field` `ueberschneidung` parameter carry the same count (no second definition).
- **Tests (synthetic seed only):** pgTAP: two readable overlaps → `count` 2, `unreadable` false; one readable plus one other-team visit → `count` 2, `unreadable` true, times are the readable one's; one other-team only → `count` 1, `unreadable` true, no times; no overlap → `overlap` false, `count` 0. vitest: sentence for 1 readable unchanged; plural for 2; mixed form shows the unreadable clause. Negative: the other team's visit's team, member and times appear in no answer.
- **Inputs:** `lca` to confirm in its next run that a count of another team's visits stays within the VIS2-2 boundary (today the existence is already shown); `cra` to confirm wording. Until both answer, VIS2-C2 is approved as stated and may be built on synthetic data.

`uxa` UXR-52 and UXR-53 (low) go to UX2 as UX2-28 and UX2-29.

## PO note — 2026-10-30 05:10 CET: `lca` 04:47 taken in; VIS2-C2 legal input in; condition VIS2-C3 (direction only, before G-23)

**VIS2-C2:** `lca` 04:47 (D-18, advisory): count and `unreadable`, with nothing else of a visit she cannot read, are **compliant under every plausible interpretation** and stay inside the VIS2-2 boundary. The legal input is in; only `cra`'s wording confirmation is open. VIS2-C2 stands as approved at 04:10 and may be built on synthetic data.

**Residual named by `lca` (pre-existing since 0098, not created by VIS2-C2):** `client_visit_overlap` answers for **any** date and interval of a case the caller reads and is not logged, so a series of calls can narrow down when another team of the same provider visits that client, although no single answer contains its time. With real data `lca` calls this **unresolved: needs owner (DSFA, D-3 gate (ii))** and offers two protective options that narrow only: (a) answer only for an interval that is about to be saved or is the time of a visit of the caller's team; (b) log and review the calls (D-3 gate (i)).

**PO direction (product authority; narrows only; reversible; synthetic pilot unaffected): condition VIS2-C3, option (a), required before G-23 (first real client data), not before.** *Why (a), not (b):* (b) would create a new per-person record of what each nurse looked up while planning, which is a monitoring question of its own (the same pattern the PO refused for PLAN3-10 and RLS4-5); (a) removes the inference path instead of watching it. *Patient safety is not traded:* the sentence before a save (VIS2-1, VIS2-5 (1)) must stay, with the same count and `unreadable` (VIS2-C2).
- (1) The fact about visits she **cannot read** (`overlap`, `count`, `unreadable`) is returned only for (i) the interval of a visit her team holds (move, reschedule, "Heute machen"), or (ii) the interval of a plan form at the moment she is about to save it. For any other interval the function returns the readable visits only, as today.
- (2) The pre-save sentence about an unreadable overlap is still shown **before** the visit is stored. Engineering chooses the mechanism (for example: a save that meets an unreadable overlap the form has not shown returns the sentence and stores only after "Trotzdem speichern"; nothing is refused).
- (3) **Tests (synthetic seed only):** pgTAP: an interval matching no visit of her team and no save returns `unreadable` null/false and `count` of readable visits only, even when another team's visit overlaps; the same interval at save returns `count` and `unreadable` true; e2e: plan form with another team's overlapping visit shows the sentence before the visit exists in the plan.
- **Inputs requested 2026-10-30 05:10:** `eng`: is (1)-(2) feasible without losing the pre-save sentence, and which mechanism (answer in ADR or on issue #65); `uxa`: wording of the save step if one is added; `lca`: confirm the built form in its D-3 gate (ii) list when it exists. If Engineering finds (a) not feasible without weakening the pre-save sentence, the item goes to the DSFA as `lca` worded it and the PO does not choose (b) without a new `lca` read of (b) as employee monitoring.
- **Not in VIS2-C1/-C2's PR unless Engineering chooses so.** Priority: before G-23, after PLAN3; it carries no value on synthetic data except closing the path early.

## PO note — 2026-10-30 06:10 CET: `cra` 05:30 and `lca` 05:55 taken in; VIS2-C1 precision decided; VIS2-C2 wording in; VIS2-C3 (1) aligned; gate G-25

**Gate reference corrected.** VIS2-C3 was written "before G-23". In `CARE_OPERATING_MODEL.md` G-23 is team admission (ADM2). The gate meant is the first real, migrated or imported visit data shown on any screen: new **G-25** (same file). Read every "before G-23" in this brief's 05:10 note as "before G-25".

**VIS2-C1 precision (`cra` 05:30, for the VIS2-C1 PR), decided:** the count covers **every** overlap of a generated visit with another non-cancelled visit of the same client, including visits created in the same run (two care-plan windows with different starts that overlap). *Why:* the planner needs the whole fact (challenge row 04:10); a count that hides overlaps the run itself created would read as complete when it is not. Wording therefore "… mit einem **anderen** geplanten Einsatz derselben Person" (n = 1: "1 erstellter Einsatz überschneidet sich zeitlich mit einem anderen geplanten Einsatz derselben Person."; n ≥ 2: "<n> erstellte Einsätze überschneiden sich zeitlich mit einem anderen geplanten Einsatz derselben Person."); `uxa` may adjust the word order in UX2, not the fact. Added test (pgTAP): two overlapping care-plan windows of one case, no hand-planned visit → count 2 (each generated visit overlaps the other). Whether two overlapping windows are a valid care plan stays with the Clinical Owner (UNKNOWN); nothing is refused.

**VIS2-C2 wording confirmed by `cra` 05:30** (with `lca` 04:47 the inputs are in). Build condition added from `cra`: **no sentence gives the times of one visit while the count is 2 or more**; the vitest asserts it. VIS2-C2 may be built as written.

**VIS2-C3 (1) aligned with `cra` condition (3) and `lca` 05:55 note 2 (product authority; narrows only).** `cra` asks that, for a visit her team holds, the sentence still follows the times live; `lca` shows that a live answer about **unreadable** visits for edited times would reopen the probe path. Both hold with this split:
- (1a) **Live, while she edits the times** (plan form, move, reschedule): the sentence follows the times for **readable** overlapping visits (VIS2-5 (1) unchanged for them), and for an unreadable overlap with the visit's **stored** interval (VIS2-C3 (1)(i)).
- (1b) **At the save step:** an unreadable overlap with the **edited** interval is stated before anything is stored (`cra` condition (1)): the visit is not stored until she has seen the VIS2/VIS2-C2 sentence and chosen to save; closing that step stores nothing and says so; nothing is refused.
- `cra` conditions (2) server re-check after every save and (4) e2e at 390 px (another team's overlapping visit, plan form: sentence shown, visit not in the plan before confirmation, in it after) are part of VIS2-C3.
- **`cra` to confirm (1a)** in its next section: does a live sentence for readable overlaps plus the save step for unreadable ones meet its condition (3)? If not, patient safety wins: (1a) then shows the unreadable fact live too, and the remainder goes to the DSFA as `lca` worded it.

**Remainder (`lca` 05:55, D-3 item 14):** VIS2-C3 narrows the path but does not close it: a save step can be opened and closed repeatedly with nothing stored or recorded. **Option (y)** (record a closed save step) **is not chosen**: it would create a per-person record of what a nurse looked at, the pattern declined for option (b), PLAN3-10 and RLS4-5. **Engineering is asked**, with the feasibility answer on issue #65, whether a mechanism (`lca` (z)) gives the pre-save sentence without a repeatable, unrecorded answer; otherwise the remainder stays on the DSFA list for the owner's weighing at gate (ii) (`lca` (x)). No new owner ask now: real visit data already wait for D-1 and the DSFA.

## PO note — 2026-10-30 08:15 CET: `uxa` 07:50 wording taken in

- **VIS2-C2 mixed case:** the `uxa` sentence set (`reports/UX_REVIEW.md` 07:50) is adopted for the build: count ≥ 2 with any unreadable visit = the plural sentence, then "Nicht alle davon kannst du einsehen."; no number of unreadable visits, no team, no time. It adds nothing beyond `count` and the `unreadable` flag that `lca` 04:47 cleared, so no new legal input is needed; **`cra` confirms the added clause** in its next section (it confirmed the other sentences at 05:30). vitest as `uxa` listed (2 readable → plural, no `hh:mm`; 1 readable + 1 unreadable → plural plus clause, no `hh:mm`; 1 unreadable → VIS2-2).
- **VIS2-C3 save step:** the `uxa` layout is adopted as the default **if** Engineering's feasibility answer (#65) chooses a save step: nothing stored while it shows; "Noch nicht gespeichert."; primary repeats the form's own save label and never sits at the save button's earlier position; secondary "Zurück, nichts speichern" keeps every value; no "trotzdem", warning colour or reason field. Its three e2e tests at 390 × 844 join `cra` condition (4). `cra` confirms wording and position. Nothing else in VIS2-C3 changes; still before G-25, after PLAN3.

