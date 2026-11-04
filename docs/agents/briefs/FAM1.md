---
id: FAM1
title: Consented relatives see the next visits (read-only, no AI, no messaging)
author: po
status: draft
updated: 2026-11-04
---

# FAM1 — Consented relatives see the next visits

**Source:** owner decision on D-40, 2026-11-04 ([package](../decisions/D-40.md)): "Reject option A. D-40 included in the pilot in a minimal and legally compliant form." Scope and exclusions below are the owner's; everything else in this brief is the PO's specification.

**Status: draft.** It is approved (and Engineering may add a `not-started` row) only when (1) `lca` has answered the two questions the owner named (consent of relatives; representation of a client who cannot consent) and the staff-name question below, and (2) `cra` has reviewed the visibility rules, information boundaries and safety implications. Their answers may change criteria FAM1-3, -6, -8, -11. Until then nothing is built.

## Problem
A relative who wants to know when the nurse comes, or whether today's visit was moved, has one way to find out: phoning the team. Every such call interrupts a nurse during care or between visits (value order 1, more direct care time; 5, less administration) and makes the team a call centre for its own schedule. NAVORA already knows the answer: the planned window, the responsible member and every recorded change are facts the team records anyway (D-6, PLAN2, VIS1). Nothing new has to be documented to answer the relative.

How we know: challenge-review row on relatives' calls (HYPOTHESIS, not measured). Baseline: UNKNOWN; NAVORA records no phone calls. The pilot measure is in *AI leverage* below.

## Users and journey step
- **Relative named by the client** (or by her representative): new external user, read-only. Journey step: **Planning → Visit**, shown after the team has planned or changed a visit.
- **Team member** (registered nurse of the client's team): records and revokes the relative's access with the consent fact.
- **Client:** gives or withdraws consent; never sees anything new in this item.

## Outcome
A consented relative opens one page on her phone and sees, for the next seven days, when each visit is planned, whether it was moved or cancelled, and who from the team is assigned, without calling anyone. Nothing about the client's care, health or documentation is visible.

## Acceptance criteria

**Access and consent**
- [ ] **FAM1-1** A relative is a separate kind of principal, not a member of any team or organisation. Given a relative's session, every select on every care and staff table and every existing command is refused; the only reads that answer are the FAM1 read function(s) (pgTAP over the full table and function catalogue, following the RLS2/RLS4 inventory in `docs/engineering/READ_PATHS.md`).
- [ ] **FAM1-2** No access without an active consent record. The record names: the client (one case), the relative (one person, one sign-in), who gave consent (the client herself, or a representative with the kind of representation as recorded), who recorded it (a registered nurse of the client's team), when, and the fixed scope "Einsätze: Zeit, Stand, zugeteilte Person". One record per relative and client; no record covers two relatives or two clients (pgTAP). **Form of consent and who may give it for a client who cannot consent: `lca` (requested).**
- [ ] **FAM1-3** Revocation by a team member ends the relative's access at her next request, with no grace period; the revocation keeps the record (who, when, why preset) and the relative sees one sentence that access has ended, nothing else (pgTAP, e2e). A client's or representative's withdrawal is recorded the same way.
- [ ] **FAM1-4** Access also ends, without anyone acting, when the case is paused or closed (C1) or the consent record's client has no active case; resuming a case does not restore access by itself (pgTAP).
- [ ] **FAM1-5** Negative cases: a relative of client X never sees anything about client Y, another team, another organisation or any staff member except FAM1-8; a team member of another team cannot record or revoke consent for this client; `coach`, `operations` and `admin` cannot record consent on behalf of the team (pgTAP).

**What is shown (allow-list)**
- [ ] **FAM1-6** For each visit of the consented client from today 00:00 to today + 7 days (Europe/Zurich), the relative sees exactly: date, planned time window, status, and FAM1-8. Status is one of four words derived only from recorded facts (input class *visit/schedule fact*): **"geplant"**, **"verschoben"** (with the new date and window), **"abgesagt"**, **"durchgeführt"** (completed). The live states (`on_the_way`, `started`, `paused`) and `no_show` are **not shown** in this draft; whether and how a visit whose window has passed without a recorded outcome is shown is `cra`'s (requested; protective default: it keeps showing the planned window with no claim that the visit took place). A vitest pins the response shape to these fields and nothing else.
- [ ] **FAM1-7** A change is shown only after the team has recorded it: the page reads recorded schedule and visit facts only, never a forecast, a SIG1 signal, an OPS1 exception or a cover offer. An uncovered visit shows as "geplant" until the team records a change; the page never says "nicht besetzt" (`cra` 2026-11-03: no relative learns first) (pgTAP on the read function's sources; e2e).
- [ ] **FAM1-8** "Who is assigned" is the responsible member's display name exactly as the team view shows it (ADM1 profile), or "Ihr Pflegeteam" when none is set; never "noch niemand". Never shown: a staff member's phone, e-mail, photo, qualification, location, departure or arrival time, or any per-person figure (labour law, AI-9). **Whether the display name may be shown to relatives without the staff member's own information or consent: `lca` (requested).**
- [ ] **FAM1-9** Never shown, in any field, link or error text: visit type, services, care-plan items, KLV category, minutes, observations, reports, safety alerts, quality events, assessments, address, insurer, diagnosis, or any free text a team member wrote (vitest on the response shape; e2e on the rendered page).
- [ ] **FAM1-10** The page states once, visibly, that it shows the schedule only, is not an emergency or communication channel, and where to turn in an emergency. Wording `uxa`; facts `cra` (requested). No team phone number or message entry point in this draft (owner: no direct communication with care teams in the pilot).

**Excluded (owner decision; each is a negative test)**
- [ ] **FAM1-11** No write path for the relative other than sign-in and sign-out; no messaging, chat, comment, reply, rating, upload or request (pgTAP: the relative principal has no insert, update or delete on any table and no command besides the read function).
- [ ] **FAM1-12** No AI of any kind: no agent definition, `ai_suggestions` row or AIG1 path references the relative principal or the FAM1 read function (pgTAP catalogue guard, AIR1 pattern).
- [ ] **FAM1-13** No push, e-mail or SMS notification to relatives in the pilot (none is in the owner's scope).

**Audit, data, release**
- [ ] **FAM1-14** Every relative read is recorded (relative, client, time; AUD1 pattern); the record is readable by `admin` of the organisation, never by the relative and never as a per-person figure about staff. Retention follows D-4.
- [ ] **FAM1-15** Built and tested on synthetic data only. The read function refuses for any organisation that holds real client data until the legal adviser has answered `lca` questions 1-2 (with D-9) and D-1 allows real data (owner rule 2026-10-29). The refusal is tested (pgTAP).
- [ ] **FAM1-16** Sign-in for relatives is separate from staff sign-in and never lands on a staff route; at 390 px the page is usable without horizontal scroll, every control 44 px, the status is text, not colour alone (e2e at 390 px; DESIGN_SYSTEM V1).

## Rules and their input class
- Status mapping (FAM1-6): *visit/schedule fact*; displays only, never ranks, routes or escalates.
- Visibility window (today + 7 days): a product choice, not a clinical rule.
- No rule of class *care-context fact recorded by a person* or *clinical content* is added. If `cra` proposes a rule for a visit whose window passed without an outcome, it is recorded in the Clinical Rule Register (owner `clinical`, PROVISIONAL) before build.

## AI leverage
**No AI leverage, by owner decision** (2026-11-04: AI functionality excluded from the pilot). The work removed is removed by rules alone.
1. **Remove:** the relative's phone call to ask about the schedule, and the nurse's interruption to answer it.
2. **Rules:** the status mapping and allow-list above; consent and revocation as recorded facts.
3. **Monitor:** nothing new is watched; the page reads what the team already recorded.
4. **AI prepares:** nothing (excluded).
5-7. **Human reviews, decides, signs:** a registered nurse of the team records and revokes consent; the client or her representative gives it.
- **Measure (pilot):** per team and month, the number of consented relatives and of relative page views, and, in the team retrospective, whether schedule calls from relatives fell (counted by the team, never per person). Baseline UNKNOWN.
- **Gate:** legal adviser (consent, representation) before real data; D-1; no D-35 or D-34 gate applies (no AI, no clinical content).
- **AI must never** read, summarise or answer anything on this path.

## Out of scope
- AI, chat or messaging, direct communication with care teams, clinical information, assessments, documentation, medical recommendations (owner decision).
- Notifications (F-03), message to the team (F-04), check-ins (F-05), team contact (F-06) of the design set; only F-01 (consent and access) and F-02 (next visits) are in scope.
- Client self-access; sensors (D-39 A).

## Constraints and references
- D-40 (owner decision 2026-11-04), D-9 (legal basis and consent texts at intake), D-3 (read scope), D-4 (retention), D-1 (no real data), D-6 (responsible member), C1 (pause/close), AUD1, RLS2/RLS4 read-function pattern, AIR1 catalogue guard.
- `lca` 2026-11-04 05:20 protective variant of option B: logistics only; shown after the team knows; relatives named one by one by a client with capacity or her representative in her interest; revocable at once; reads audited; information to the relative on what is processed.
- Design set: `docs/design/NAVORA_INFORMATION_ARCHITECTURE.md` F-01, F-02 (frame only until this brief is approved).

## Open questions for engineering
1. Which principal model fits Supabase Auth without letting a relative's session reach a staff policy by accident (separate role claim, separate schema, or Edge Function only)? Propose in an ADR; FAM1-1 is the test.
2. How a relative is invited and signs in (link from the team, e-mail one-time code); `lca` checks identity verification once proposed.
3. Effort estimate in days, so that `DELIVERY_PROGRAM.md` M7 can be re-dated.
