---
id: CSR1
title: Clinical safety remediation
author: po
status: approved
updated: 2026-10-23
---

# CSR1: Clinical safety remediation (Clinical Governance Report, 2026-10-22 22:30)

## PO review — 2026-10-23 22:15: CGR-34 met (#230); part 12 = ABS1-C6 only, then AN2

Engineering delivered CGR-34 as the part 11 remainder (#230, migration 0054, ADR-066; merged as 673ba50, CI green). Evidence table in `briefs/ABS1.md` 22:15. **The PO did not run the tests.** **Part 12 is now ABS1-C6 only** (`briefs/ABS1.md` 21:17: a start of yesterday on `/field`, and the `past_planned` confirmation with a link to `/team`). Then AN2 (#205).

## PO review — 2026-10-23 21:17: part 11 met (CGR-32, the `cra` 19:46 case, the 046 fix); part 12 ordered (CGR-34, ABS1-C6), then AN2

#228 (merged as 33112e3, CI green on its head and the merge commit) carried CGR-32 and the `cra` 19:46 case; it was built before the 20:15 decision merged, so **CGR-34 is not in it**. Evidence table in `briefs/ABS1.md` 21:17. The pgTAP 046 time-of-day fault is fixed (fixtures pinned to today's date; the PO's own #227 turned green after merging `recovery/main`). **The PO did not run the tests.** Awaiting a `cra` section on 0053.

**Part 12 (small, same functions and the same `/field` section):** CGR-34 (criteria (1)-(3) in `briefs/ABS1.md` 20:15) and ABS1-C6 (`briefs/ABS1.md` 21:17: a start of yesterday on `/field`, and the `past_planned` confirmation). Then AN2 (#205).

## PO update — 2026-10-23 20:15: part 11 = CGR-32 + CGR-34 (+ the `cra` 19:46 case)

Part 11 (not started; no PR yet) now carries three things, all small and in the same functions: **CGR-32** (ABS1 condition, `briefs/ABS1.md` 19:12), **CGR-34** (PO decision 20:15 on the `cra` 19:57 addendum: a cancellation of a flagged past visit stores, server-side and immutably, that the responsible member was absent; no new reason code), and the `cra` 19:46 pgTAP case (a hand-closed overdue alert still counts in `past_planned`). Criteria in `briefs/ABS1.md` 20:15. Then AN2.

**CI note (not a PO criterion, an order):** pgTAP 046 test 74 depends on the time of day (`cra` 19:57: `now() + 4 h` crosses midnight between 20:00 and 24:00 Europe/Zurich) and makes every PR's db job red in the evening. Engineering fixes it first, in part 11's PR or a separate one; a red db job from any other test is not this.

## PO review — 2026-10-23 19:12: part 10 met (J5-C2, ABS1-C5); part 11 ordered (CGR-32, CGR-33), then AN2

Reviewed CSR1 part 10: #216 (head 9ea3cb3, CI run 39988490243 green: app, db incl. pgTAP `051_csr1_order_as_of_visit_date` (35), e2e; merged as 3d48a00, CI runs 39989101189 and 39989106823 green on the merge commit; checked through the API). The PO read migration 0051 (header, cut-off, reconstruction) and the pgTAP 051 assertion list. **The PO did not run the tests.**

| Criterion | Result | Evidence |
|---|---|---|
| J5-C2: the order basis is the order as recorded at the end of the visit date, never at build time | met | 0051: `private.order_cutoff` (first instant of the next day, Europe/Zurich; one place D-22 changes) and the reconstruction from `audit_events` (old value of the earliest change at or after the cut-off, else the live value); every build path through `build_billable_fact`; facts record `order_as_of` and `order_recorded` |
| (a) order without end date on day 1, end date entered day 3, first generation later → not billable | met | pgTAP 051 (a): `order_validity_missing` plus `order_recorded_after_visit`, although the live order is valid |
| (b) order valid on the visit date → billable whenever built | met | pgTAP 051 (b), also after the end date is removed again |
| (c) correction v2 of (a) signed after the order fix → still not billable | met | pgTAP 051 (c) |
| (d) J5-C1 payer correction unchanged | met | pgTAP 051 (d): IV → `payer_not_modelled`, KVG → billable again; order part copied |
| CGR-29's build at the lift reads the same order | met | pgTAP 051 (lift section) |
| No regression | met | CI green (all pgTAP files, unit, e2e) |
| **Clinical gate** | passed | `cra` 19:00: J5-C2 met in code (cut-off PROVISIONAL, D-22), no blocking finding; CGR-33 and CGR-31 advisory |

**Deviations, decided:**
- No separate "history missing" reason, because the audit history is complete backwards from the live row: **accepted on condition CGR-33**, the test that keeps it complete.
- An A/C-only visit whose order was recorded after the visit reads as `without_order_ac`: **accepted**; it is the existing CGR-07 rule, unchanged; whether A/C need an order is D-22 (`legal`).
- No catch-up inside the migration (no user to attribute it to); pre-0051 facts re-derive at the next generation or lift: **accepted**; no real data (D-1), nothing is invoiced.
- Cut-off compared with the audit row's transaction start: **accepted** (seconds around midnight; D-22 may move the cut-off).
- CGR-29's build at the lift does not run when the visit had no fact before the hold; the next generation builds it: **accepted**. It delays a fact, never releases billing (`cra` 19:00 agrees). No change.

**Part 11 (ordered now, small, before AN2):** CGR-32 (ABS1 condition, text in `briefs/ABS1.md`, review 19:12). CGR-33 (J5 condition, `briefs/J5.md`) was delivered by engineering in the same hour (#222, pgTAP 053) and is met (PO 19:30).

## PO review — 2026-10-23 16:55: part 9 met in code; awaiting clinical review; part 10 ordered (J5-C2)

Reviewed CSR1 part 9: PR #210 (CI run 39969893133 green on its head: app, db incl. pgTAP 049, e2e; merged as 378f811, CI runs 39970600351 and 39970609212 green on the merge commit, checked through the API). The PO read migration 0049 in full, the pgTAP 049 assertions, and searched every migration for "latest version" checks that a `withdrawn` successor could break. **The PO did not run the tests.** Evidence is merged code and tests plus green CI.

| Criterion | Result | Evidence |
|---|---|---|
| CGR-24-W: the performer withdraws an untouched correction draft; kept as `withdrawn` with who and when; final v1 in force; facts locked again; `report_correction_open` ends; idempotent | met in code | 0049 §1 (status, constraints, guard: a withdrawn row is immutable), §2 (`visit_facts_locked`, `field_reports`, the signal and `correct_report` ignore a withdrawn successor; the next correction takes the next free number), §3 (`withdraw_report_correction`). pgTAP 049: withdraw → `withdrawn` with `withdrawn_by`; latest is `1/final`; `visit_facts_locked` true; no Operations exception; audit row; `duplicate` on the same key, `already_withdrawn` on a new key; the row cannot be reset; a later correction is v3 |
| Refused: colleague (`not_performer`), draft with changes (`draft_has_changes`), signed correction awaiting countersignature | met in code | pgTAP 049: colleague → `not_performer`, nothing written; time correction, observation and an edited summary → `draft_has_changes`, stays a draft; signed v2 → `awaiting_countersignature`, stays `signed` |
| CGR-29: on the last lift, a final version without a J5-v3 fact is built from that version | met in code | 0049 §5; pgTAP 049 k1: v1 fact → hold → correction v2 final → no fact while held → lift → head fact carries v2's `report_id`, no `hold_lifted` copy of the v1 fact |
| J5-C1: a payer correction re-derives from the same snapshot; no report version; order change not re-derived | met in code | 0049 §4 (`rederive_fact_payer`, trigger on `insurance_type`, `insurer_name`), §6 catch-up in `generate_billable_facts`. pgTAP 049 j1: IV `payer_not_modelled` → KVG → billable `basis_changed`, same snapshot hash, one report version; j2: order end date entered later → still not billable with the order reasons; insurer removed → `no_insurer` after the next generation |
| Other readers of "the latest version" | checked | the remaining unfiltered successor checks are `field_countersign_queue` (only signed versions, which cannot have a correction) and `pilot_kpis` (counts a version that is final itself): no effect |
| Clinical gate | **awaiting clinical review** | no `cra` section covers 0049 (newest: 15:00 on PR #203) |

**Deviations, decided:** an edited summary counts as a change (stricter; a typed summary would otherwise vanish unsigned): accepted. `not_correction` (a first draft cannot be withdrawn, a completed visit would have no report): accepted. CGR-29's build also runs when the pre-hold fact was not billable: accepted (it builds the version in force). pgTAP 043's three adapted assertions: accepted (they assumed the J5 gap that J5-C1 closes).

**Engineering's UNKNOWN (order at build time), decided within product authority as the strict default, not as a legal answer:** facts are built only when `generate_billable_facts` runs (or on the last lift), and `build_billable_fact` reads the case's order **at that moment** (0043:198-211). So an order end date entered after the visit makes the visit billable whenever its fact is first built later, or when a correction version is built: the opposite of the strict default the PO set with J5-C1 ("a later order change never makes an earlier visit billable until D-22"). New condition **J5-C2** (CSR1 part 10). No real data exists (D-1), so nothing is billed wrongly today.

- **J5-C2 (billing integrity; strict default until D-22, `legal`):** the order basis of a fact does not depend on when the fact is built. A fact's order basis is the case's order as recorded **at the end of the visit date** (Europe/Zurich), taken from the case's audited history; an order or order end date recorded later never makes that visit billable. If the history cannot show the order as of that date, the fact is not billable with a new reason (engineering names it, e.g. `order_recorded_after_visit`). The same for a correction version's fact and CGR-29's build. pgTAP: (a) visit day 1 with order `present` and no end date → end date entered on day 3 → first generation on day 4 → not billable (`order_validity_missing`); (b) order valid on day 1 → fact billable regardless of when it is generated; (c) correction v2 of (a) signed final after the order fix → v2's fact still not billable; (d) payer correction (J5-C1) unchanged. When D-22 is answered, only this one rule changes.

**PO status:** F6 and J5 stay `accepted` (their acceptances stand): CGR-24-W, CGR-29 and J5-C1 are met in code and await a `cra` section on 0049; J5 carries the new condition J5-C2. **Order:** ABS1 part 3 (ABS1-C4) → CSR1 part 10 (J5-C2) → AN2.

## PO review — 2026-10-23 15:25: part 8 met; part 9 ordered (CGR-24-W, CGR-29, J5-C1)

Reviewed CSR1 part 8: PR #200 (head 1e1d904, CI green on app, db incl. pgTAP 047, e2e; merged as 20a3566, CI green on the merge commit (one e2e run cancelled, the second green) and on 81f1a47, checked through the API). The PO read migration 0047 in full, the assertions of pgTAP 047, the new e2e test in `lifecycle.spec.ts`, and searched `src/` for the hold label. Clinical gate: Clinical Governance Report section 15:00 in PR #203 (head 31a6a16, CI green): no new finding; CGR-24, CGR-30, CGR-26 (label) and CGR-13 (wording) closed. **The PO did not run the tests.**

| Criterion | Result | Evidence |
|---|---|---|
| CGR-24: an unsigned correction raises a P3 exception for the team and Operations after the `report_not_final` threshold, until signed | met (stricter) | 0047 §1 (`report_correction_open`, P3, not escalating, no own threshold), §2a (derived from `visit_reports.supersedes_id` not null and status not `final`, after the effective `report_not_final` threshold), §2b team view, §2c Operations; pgTAP 047: fresh draft → nothing; 23 h → nothing; 25 h → P3 for Operations and for every member of the team; organisation override to 48 h → not listed; signed and final → gone for team and Operations; a care assistant's correction signed but not countersigned keeps it until countersigned |
| CGR-30 (`cra` 14:30 advisory on #200): the signal closes only with its cause | met | 0047 §1b (`exception_closes_with_cause`), §2b-c; pgTAP 047: `closable` false, hand close → `cause_persists`, a close written as table owner hides it neither for the team nor for Operations |
| CGR-26: the performer sees who ended her visit and why | met | 0047 §3 (label, no user id); `/field` "Beendet von …"; e2e at 390 px with two sessions; pgTAP 047 label cases |
| CGR-13: "Abrechnungssperre" everywhere in the UI | met | no "Qualitäts-Stopp" in `src/`; label and meaning in six files; e2e `quality.spec.ts` |
| Privacy | met | no user id returned; detail of the exception carries date, time, version and countersignature state only (no clinical text); `cra` 15:00 "acceptable" |
| No regression; rule register; gate trail | met | CI green as above; CR-053 (PROVISIONAL, D-28), CR-054, CR-055; ADR-058; PR names the 10:29 section and CGR IDs |

**Deviations, decided:**
- A signed correction awaiting the countersignature keeps the signal (stricter than the wording): **accepted** (the old version is in force until the correction is final).
- Operations sees the signal but cannot act on it (only the performer can sign): **accepted for now**; challenge row added (an Operations signal for a performer-only action is coordination without a lever), measured in AN2.
- **No withdraw command for a correction draft** (engineering's UNKNOWN; `cra` residual): **decided by the PO, criterion CGR-24-W below**.
- J5-C1 did not ride along (#200 did not touch billing generation): accepted; it moves into part 9.

**Part 9 (next CSR1 part, after ABS1 part 2):** CGR-24-W, CGR-29, J5-C1. Why together: all three keep "signed means fixed" true for billing and for the record without costing a nurse a signature for nothing.

## Problem
The first Clinical Governance Report (`reports/CLINICAL_GOVERNANCE.md`, 22:30) found blocking safety gaps in capabilities the PO had already accepted. The PO spot-checked two of them against the code and confirmed them:
- CGR-01: `record_observation` in migration 0009 does not check the author of the superseded version.
- CGR-12: the registered-nurse check in migration 0024 applies only to `planned`/`on_the_way` → `started`.

Each of these gaps lets a visit look safe when it is not, or lets a signed record change after signature:
- a visit that never started;
- a care assistant completing a registered-nurse visit;
- a colleague rewriting another nurse's observation;
- a report signed over facts the nurse never saw;
- a bill computed from times changed after signature.

Under the clinical review gate (README; D-27), these items are no longer accepted. The PO set them to `changes-requested`: F1-F4, F6, F7, J3, J5, OPS1 and C1. CSR1 is the one item that carries their remedies.

## Users and journey step
Nurses and teams (Visit, Documentation), operations (exceptions), and billing preparation (J5). Journey steps: Visit → Documentation → Quality → Billing.

## Outcome
No visit looks covered, started or documented when it is not. A signed report is exactly what the nurse saw, and billing reads only what was signed.

## Acceptance criteria
Order of work: patient safety first.
- [x] **CGR-12 (J3, C1): the qualification rule holds for the whole visit.** For category B or needs-assessment visits, the registered-nurse check applies to **every** transition into `started` (including resume from `paused`) and into `completed`. pgTAP: a care assistant cannot resume or complete such a visit (`NV001`), and a registered nurse can.
- [x] **CGR-04 (OPS1, C1): a visit that did not happen stays visible.** Two new exception types:
  - a planned visit whose start time has passed without a start;
  - a visit left `on_the_way`, `started` or `paused`.

  Both stay open until a person resolves them, even after the planned start has passed. Thresholds are a `clinical` decision (D-28). Until it is answered, engineering uses a strict provisional default, listed as `PROVISIONAL` in `clinical/CLINICAL_RULE_REGISTER.md`. The provisional default is safer to raise early than late. pgTAP for both types, including that the existing "uncovered" exception no longer simply disappears at start time.
  - **Added 2026-10-23 00:10 (ADM1 pre-review):** the overdue exception does not depend on who is responsible. A missed planned visit whose responsible person is no longer a member of the visit's team (removed under ADM1, or with no responsible person) is raised the same way, is visible to every member of the team, and says "zuständige Person nicht mehr im Team" or "niemand zuständig". pgTAP: remove a member who has a planned visit dated yesterday → an overdue exception for that visit is returned to another member of the team.
- [x] **CGR-05 (OPS1, QG1): a serious quality event stays escalated until closed.** The exception stays while the event is `in_review`, and escalation continues. pgTAP.
- [x] **CGR-06 (OPS1): P1 safety exceptions cannot be silenced while their cause persists.** A P1 exception either re-opens while the cause persists or cannot be closed until the cause is resolved (engineering chooses; ADR). That includes `no_show_open` without a recorded outcome. pgTAP.
- [x] **CGR-20 (OPS1, C1; blocking S1, added 2026-10-23 07:10): a broken-off visit has an honest end.** Today a `started` or `paused` visit can only become `completed`, and since 0039 its `visit_stuck` alert cannot be closed, so a visit that really stopped (client taken to hospital, nurse called away, started by mistake) ends either as a permanent P1 or as a false completion. Change:
  - a new audited, idempotent command ends a `started` or `paused` visit as **not completed** (status name engineering's choice, e.g. `interrupted`; ADR), with a mandatory reason from a list (client transferred or taken to hospital, client declined to continue, nurse called away or unwell, started by mistake, other with a note) and the actor;
  - allowed for the performer, any member of the visit's team (an absent or removed performer must not leave it stuck, ABS1), or a coordination role; whatever her qualification, because it records that care stopped, not care given. Who may finally record it is part of D-31;
  - it ends `visit_stuck` through its cause (no hand close); it produces **no billable fact** (J5), no F6 report obligation, no `report_not_final`, and does not count as a completed visit in AN1 or J6, until D-31 is answered;
  - the visit stays visible to its team as "nicht abgeschlossen · <Grund>" on `/field` and in HAND1's "Seit deinem letzten Einsatz"; already recorded observations stay unchanged;
  - `/field` offers it next to "Abschliessen" on a started or paused visit, so the only button on a stuck visit is never "complete".

  pgTAP: started → not completed with reason → no `visit_stuck`, no billable fact, audit row present; paused → not completed, same; a care assistant who performs a B visit can record it; another team member can record it; someone outside the team or organisation cannot; without a reason → refused; a not-completed visit cannot be completed or restarted. e2e at phone width: the action on a started visit. Rule register: one `PROVISIONAL` row referring to D-31. *(Met by part 5, #179, migration 0042, PO 2026-10-23 10:15; evidence in `OPS1.md`.)*
- [x] **CGR-22 (OPS1, advisory, strict provisional default 2026-10-23 07:10):** the hand close of `visit_uncovered` is refused (`cause_persists`) while the visit is planned and nobody is responsible; it ends by assigning someone or cancelling the visit. pgTAP for both endings and the refused close. The priority of uncovered visits stays with D-28 (`clinical`). May ride a later CSR1 PR; OPS1 does not wait for it. *(Met by part 7, #188, 0044, PO 12:15.)*
- [x] **CGR-01 (F1-F4): only the author supersedes her observation.** A colleague's supersede is `rejected`. A colleague adds her own observation instead. pgTAP.
- [x] **CGR-02 (F6, F7): she signs what she saw.** The sign command carries the version or hash of the snapshot shown. It is rejected (`facts_changed`, and the screen reloads the snapshot) when observations or times changed since. pgTAP + e2e. *(Met by part 4, #175, migration 0041, PO 2026-10-23 09:10; evidence in `F7.md`.)*
- [x] **CGR-03 (F3, F6, J5): signed means fixed.** After a report is `final`, time corrections and observations are refused, or go only through the F6 correction-version path. J5 billing facts take minutes from the signed snapshot, never from live times. pgTAP for both. *(F3/F4 part met by part 3, #171, migration 0040, PO 2026-10-23 08:20; J5 part met by part 6, #183, migration 0043, PO 2026-10-23 11:25; evidence in `J5.md`.)*
- [x] **CGR-07 (J5): no bill on a missing, expired or unmodelled basis.** Three new not-billable reasons:
  - `order_validity_missing`: an order without an end date;
  - `order_expired`: this also applies to A and C minutes;
  - `payer_not_modelled`: any case that is not KVG.

  pgTAP. This adds no tariff rule: it refuses to estimate where the rule is not modelled. *(Met by part 6, #183, 0043, PO 11:25.)*
- [x] **CGR-08 (J5, advisory, accepted as a condition):** canton-sourced rates and minimums are marked as unvalidated in the data, and the J5 preview shows "nicht validiert". Re-seeding waits for D-11 and D-18.
- [x] **CGR-13 (QG1, advisory, accepted as a condition):** until `clinical` answers D-16, the UI labels a hold "Abrechnungssperre" (billing hold), so nobody reads it as a care stop.
- [x] **BL-8 (J5, advisory, accepted as a condition 2026-10-23 01:10):** a billing fact never stays billable under a later hold. When a quality hold opens on a visit that already has a billable fact, the fact is superseded by a not-billable fact with reason `quality_hold` (or an equivalent derived flag; engineering chooses, ADR); lifting the hold produces a new billable fact. The J5 preview and AN1 "billable minutes per care minute" read the same rule. pgTAP: fact → hold → not billable; lift → billable again; history kept.
- [x] **BL-9 (J5, AN1, advisory, accepted as a condition 2026-10-23 01:10):** working-time facts follow the signed truth. When a report correction version (F6 path, CGR-03) supersedes a billing fact, the working-time fact of that visit is replaced from the same corrected snapshot, with a link to the old values; never updated silently. pgTAP: correction version with changed times → working-time fact shows the corrected minutes and references the earlier ones.
- [x] **CGR-25 (OPS1, advisory S2, strict provisional default 2026-10-23 11:25; `cra` section 10:29):** a visit ended as *not completed* keeps a signal until a person has decided about the care still due. An `interrupted` visit raises an exception for the visit's team (on `/field` and `/team`) and for Operations (type and priority engineering's choice, `PROVISIONAL`, for example P2 `visit_interrupted`, not escalating), closed by a team member or a coordination role with a reason from a short list ("Folgeeinsatz geplant", "nicht mehr nötig", other with a note); its detail shows the interruption reason and note, and for `client_transferred` the case's next planned visit. Rule register: one `PROVISIONAL` row referring to D-31. pgTAP: interrupted → exception visible to the team and to Operations → closed with a reason → gone; a close without a reason is refused. *(Met by part 7 completion, #192, 0045, PO 13:20.)*
- [x] **CGR-24 (F1-F4, F6, advisory S2, strict provisional default 2026-10-23 11:25):** a report correction draft that stays unsigned longer than the `report_not_final` threshold raises a P3 exception (type engineering's choice, e.g. `report_correction_open`) for the team and Operations until the correction version is signed or the draft is withdrawn; threshold `PROVISIONAL` (D-28). Billing already reads only `final` snapshots (0043). pgTAP: final → correction draft → after the threshold the exception exists → signed → gone.
- [x] **CGR-26 (OPS1, advisory S3, 2026-10-23 11:25):** `/field` shows the performer of an interrupted visit who ended it (member label) and why, so an end recorded by someone else is seen at once; the count of ends recorded by a coordination role while the visit was in progress is an AN2 measure. How an end recorded in error is corrected waits for D-31; nothing is built for it now. e2e at phone width: another member ends the visit → the performer's card shows who and why.
- [x] (met in code 16:55, #210, 0049; awaits `cra`) **CGR-24-W (PO decision 2026-10-23 15:25; residual of CGR-24 in the `cra` 15:00 section):** the performer can **withdraw her own correction draft while it is untouched**: status `draft`, and no time correction, observation or other change recorded on the visit since the draft was opened. One tap with a confirmation, no reason field (nothing changed, so nothing to explain). The draft row is kept with a terminal status (e.g. `withdrawn`) and who and when, never deleted; the last final version stays in force; the visit's times and observations are locked again exactly as before the draft; `report_correction_open` ends. Refused: by anyone other than the draft's performer (`not_performer`); for a draft with changes since it was opened (`draft_has_changes`: those changes must be signed, so the record and the signed snapshot never diverge); for a `signed` correction awaiting the countersignature (whether a countersigner may return a report is D-10). Idempotent. pgTAP: untouched draft → withdraw → `withdrawn`, final v1 in force, `visit_facts_locked` true, no signal, audit row; draft with a time correction → `draft_has_changes`, nothing written; a colleague → refused; signed correction → refused; second call → same result. This invents no clinical rule: a withdrawn draft never took effect.
- [x] (met in code 16:55, #210, 0049; awaits `cra`) **CGR-29 (J5, advisory S3, `cra` 14:30):** on the last lift of a quality hold, if the visit's latest final report version has no J5-v3 `report` fact, the fact is built from that version (the same function) instead of restoring the pre-hold fact. pgTAP: v1 final → fact → hold → correction v2 final → lift → the head fact carries v2's `report_id` and snapshot hash.
- [x] (met in code 16:55, #210, 0049; awaits `cra`) **J5-C1 (J5 condition, PO 2026-10-23 11:25; text in `briefs/J5.md`):** a payer correction in intake re-derives the fact from the same signed snapshot (no report version); a later order change does not make an earlier visit billable until D-22. pgTAP as in `J5.md`.
- [x] (met 19:12, #216, 0051; `cra` 19:00) **J5-C2 (PO 2026-10-23 16:55, part 10; billing integrity, strict default until D-22):** a fact's order basis is the order as recorded at the end of the visit date (audited history), never the order at build time; else not billable with a named reason. pgTAP (a)-(d) in the 16:55 review.
- [x] **CGR-19 (F6, advisory, interim safe default 2026-10-23 03:10):** `correct_report` is refused with a clear reason (for example `performer_not_in_team`) while the report's performer is not a member of the visit's team, instead of creating a correction draft that nobody can ever sign. The current final version stays in force and readable. The rule for who may correct and sign in that case is D-30 (`clinical`, with `legal`); this criterion is replaced when D-30 is answered. pgTAP: performer removed → correction refused, no draft row; performer still a member → correction allowed as today. *(Met by part 7, #188, 0044, PO 12:15; delivered ahead of the 11:25 order, deviation accepted.)*
- [ ] **CGR-34 (ABS1 condition, PO 2026-10-23 20:15, part 11):** a cancellation of a flagged past visit stores `responsible_absent` server-side and immutably and shows "nicht durchgeführt: zuständige Person abwesend gemeldet". pgTAP, unit and e2e in `briefs/ABS1.md` (20:15).
- [ ] **CGR-32 (ABS1 condition, PO 2026-10-23 19:12, part 11):** a past planned visit inside a newly recorded absence keeps its responsible member, is counted in `past_planned` and its overdue alert carries "Zuständige Person abwesend gemeldet"; the absence is never refused. pgTAP and e2e in `briefs/ABS1.md` (19:12).
- [x] (met 19:30, #222, pgTAP 053) **CGR-33 (J5 condition, PO 2026-10-23 19:12):** pgTAP guards that both order columns are audited with their old value and that `audit_events` is append-only (`briefs/J5.md`, 19:12).
- [ ] **No regression:** all existing pgTAP, unit and e2e tests stay green. The Clinical Rule Register lists every provisional default CSR1 introduces.
- [ ] **Clinical gate trail:** each PR names the report section it addresses and the CGR IDs it closes (README *Clinical review gate*).

Build order: the two BL conditions come after every blocking criterion above; they may ship in a later CSR1 PR. J5 is re-accepted only with them; the other reopened items do not wait for them.

Progress (PO, 2026-10-23 06:10): CGR-12 and CGR-04 met by part 1 (#161, migration 0038); evidence tables in `C1.md` and `J3.md`.
Progress (PO, 2026-10-23 07:10): CGR-05 and CGR-06 met by part 2 (#165, migration 0039); evidence in `OPS1.md`. C1, J3 and ADM1 accepted after the `cra` section 06:30. **Next part: CGR-20** (blocking for OPS1), after the part engineering already has in progress (F1-F4, CGR-01, if started); then F6/F7, J5.
Progress (PO, 2026-10-23 08:20): CGR-01 and the F3/F4 part of CGR-03 met by part 3 (#171, migration 0040); evidence in `F1-F4.md`. F1-F4 is accepted after a `cra` section on 0040 without a blocking finding. Condition for the CGR-02 PR: pgTAP that a time corrected in a correction draft reaches the signed correction version. **Next part: CGR-20** (blocks OPS1), then F6/F7 (CGR-02, CGR-19), J5.

Progress (PO, 2026-10-23 09:10): CGR-02 met by part 4 (#175, migration 0041), including the 08:20 condition; evidence in `F7.md`. F7 is accepted after a `cra` section on 0041 without a blocking finding. **Order of the remaining parts (PO decision):** 1. **CGR-20** (an honest *not completed* end; blocks OPS1 and is needed by ABS1), 2. J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9), 3. CGR-19 (F6), with CGR-22 in any part. CGR-20 goes before J5 because it keeps the care record truthful today, while J5's billing gaps cannot cause a real invoice before D-12 and D-18. The watcher currently labels J5 (#148) `active` (see the 09:10 journal entry); engineering builds CGR-20 first and may deliver it under #149 or #148.
Progress (PO, 2026-10-23 10:15): CGR-20 met by part 5 (#179, migration 0042); evidence in `OPS1.md`. OPS1 is accepted after a `cra` section on 0042 without a blocking finding. Deviation accepted: `security definer` (the reason cannot be skipped). **Next part: J5** (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9), then CGR-19 (F6); CGR-22 in any part.
Progress (PO, 2026-10-23 11:25): the J5 part (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9) met by part 6 (#183, migration 0043); evidence in `J5.md`; J5 is accepted after a `cra` section on 0043 without a blocking finding. F1-F4, F7 and OPS1 **accepted** after the `cra` section 10:29. Its advisory findings CGR-24, CGR-25 and CGR-26 are new criteria above. **Order of the remaining parts (PO decision):** part 7 = **CGR-25 and CGR-22** (both keep a visit that needs a person from going silent; both in OPS1's exception derivation); then **ABS1** (Next up 2); then part 8 = CGR-19, CGR-24, CGR-26 and CGR-13 (report correction and labels). Why: CGR-25 and CGR-22 are the remaining S2 patient-safety gaps where care that is due can disappear from every list; ABS1 removes a daily safety gap (visits assigned to an absent nurse) and the morning phone chain; part 8 closes gaps that are visible and attributable today.
Progress (PO, 2026-10-23 12:15): CGR-22 and CGR-19 met by part 7 (#188, migration 0044, merged as e215924, CI green); evidence in `OPS1.md` and `F6.md`. **Deviation accepted:** CGR-19 came before its ordered part 8 (it was already built and tested; one revertable section; no risk added). **Remaining order:** part 7 completes with **CGR-25**; then **ABS1** (amended 12:15: "Offen im Team" covers every uncovered visit of the team, which gives CGR-22 a team-side ending); then part 8 = CGR-24, CGR-26, CGR-13, with J5-C1 riding along. OPS1's CGR-22 condition and F6's CGR-19 wait only for a `cra` section on 0044.
Progress (PO, 2026-10-23 13:20): CGR-25 met by the part 7 completion (#192, migration 0045, merged as 7e5013b, CI green); evidence in `OPS1.md`. **CSR1 part 7 is complete.** OPS1's CGR-22 and CGR-25 conditions wait only for a `cra` section on 0044 and 0045. **Next: ABS1** (#134, with the 12:15 criterion), then part 8 = CGR-24, CGR-26, CGR-13, with J5-C1 riding along.

Progress (PO, 2026-10-23 15:25): **part 8 met** (#200, migration 0047, merged as 20a3566, CI green): CGR-24 (with CGR-30), CGR-26, CGR-13; `cra` 15:00 (PR #203) closes all four. F6 and J5 accepted; F1-F4, OPS1 and QG1 conditions met. **Remaining: part 9 = CGR-24-W, CGR-29, J5-C1**, after ABS1 part 2 (which now includes CGR-27).

## Out of scope
- Defining clinical thresholds, escalation chains or what a quality hold stops. Those are `clinical` decisions (D-28, D-16).
- Tariff rules (D-18), order forms (D-22), and qualification verification (CGR-16, D-29).
- ADM1 findings CGR-09 and CGR-10 (they stay in #135) and ABS1 findings CGR-11 and CGR-15 (they are in the ABS1 brief).

## Constraints and references
- `reports/CLINICAL_GOVERNANCE.md` (2026-10-22 22:30), `clinical/HAZARD_LOG.md`, `clinical/CLINICAL_RULE_REGISTER.md`, `clinical/SAFETY_RISK_REGISTER.md`.
- Decisions: D-27 (the Architect recommends; a named human clinical owner approves), D-28 (exception thresholds), D-16.
- No new clinical rule is invented: where a threshold is needed, CSR1 ships a strict, labelled provisional default.

## Delivery
Engineering may deliver CSR1 in one PR or in several, and decides how. Each reopened item goes back to `delivered` when its CGR findings are merged with green CI. The PO then re-accepts it against this brief and the latest Clinical Governance Report.

## Open questions for engineering
- Is a persistent "visit overdue" exception cheaper as a derived view over `visits` and `now()` (no job), like the existing uncovered exception?
- Can the snapshot hash for CGR-02 reuse the F6 snapshot builder, so sign and display share one function?

## Findings considered (PO, 2026-10-22 23:00)

The PO did not run tests. "Confirmed" means the PO read the cited code and found the gap as described.

| Finding | Item | Severity | PO decision |
|---|---|---|---|
| CGR-01 | F1-F4 | blocking | confirmed (0009: supersede has no author check); CSR1 |
| CGR-02 | F6, F7 | blocking | considered; CSR1 |
| CGR-03 | F3, F6, J5 | blocking | considered; CSR1 |
| CGR-04 | OPS1, C1 | blocking | considered; CSR1, thresholds D-28 (`clinical`) |
| CGR-05 | OPS1, QG1 | blocking | considered; CSR1 |
| CGR-06 | OPS1 | blocking | considered; CSR1 |
| CGR-07 | J5 | blocking | considered; CSR1 |
| CGR-08 | J5 | advisory | accepted as a condition; CSR1 |
| CGR-09, CGR-10 | ADM1 (#135) | blocking | changes on #135 (`briefs/ADM1.md`) |
| CGR-11, CGR-15 | F0, ABS1 | blocking for ABS1 | ABS1 brief amended |
| CGR-12 | J3, C1 | blocking | confirmed (0024: check only on the first start); CSR1 |
| CGR-13 | QG1 | advisory now | condition on QG1; UI label in CSR1; D-16 |
| CGR-14 | protocol | blocking for #136 | resolved in #136 (merged): `cra` is a reviewer without decision rights; `clinical` is the named human; one report path |
| CGR-16 | F0, ADM1 | advisory now, blocking before real data | D-29 (`owner`) |
| BL-8 | J5 | advisory (S2), recommended as a condition in the 23:05 section | **added 2026-10-23 01:10** as a CSR1 condition; confirmed by PO reading 0023: the preview filters `visit_has_open_hold`, but the fact itself stays `billable`, so any later reader of `billable_facts` (insurer invoices after D-12/D-18) would bill a held visit |
| BL-9 | J5, AN1 | advisory (S2), recommended as a condition in the 23:05 section | **added 2026-10-23 01:10** as a CSR1 condition; confirmed by PO reading 0023: `working_time_facts` insert `on conflict (visit_id) do nothing`, so a corrected visit keeps its first times. Working-time facts are the base for the North Star and fair pay (D-23, J7) |
| CGR-18 | ADM1 (merged) | blocking (S1), section 02:28 | confirmed (0036 checks the responsible person only; 0016 lets only the performer draft and sign); **ADM1 changes-requested 2026-10-23 03:10**, one small PR (`briefs/ADM1.md`); not part of CSR1, but may ride as the first commit of CSR1's first PR. ABS1: absence never refused, see `briefs/ABS1.md` |
| CGR-20 | OPS1, C1 | blocking (S1) for OPS1, section 06:30 | confirmed (0038:38-45 allows `started`/`paused` → `completed` only; 0024:353 `cancel_visit` only before start); criterion added 2026-10-23 07:10; **met** by #179 (0042), PO 10:15; documentation and billing rule to **D-31** (`clinical`, with `legal`) |
| CGR-21 | C1, COVER1 | advisory (S2), dormant while cover is off | condition of the COVER1 delta review after D-3: overdue and stuck alerts of a covered visit reach the covering nurse and her team, and the detail does not imply that someone is on the way |
| CGR-22 | OPS1 | advisory (S2) | strict provisional default added as a CSR1 criterion 2026-10-23 07:10; question added to D-28 |
| CGR-23 | C1 | advisory (S3) | pilot measure (AN1): visits with more than two pause/resume cycles or open longer than planned plus the P1 threshold, reviewed by the team; threshold change waits for D-28 |
| CGR-24 | F1-F4, F6 | advisory (S2), section 10:29 | accepted as a condition on F1-F4 (accepted 11:25); criterion CGR-24 (P3 signal for an open correction draft); threshold to D-28; billing side met by 0043 |
| CGR-25 | OPS1 | advisory (S2), section 10:29 | accepted as a condition on OPS1 (accepted 11:25); criterion CGR-25 (strict default: an interrupted visit keeps a signal until someone decides about care still due); the follow-up rule to D-31 |
| CGR-26 | OPS1 | advisory (S3), section 10:29 | accepted as a condition on OPS1; criterion CGR-26 (the performer sees who ended her visit; AN2 measure); correction of an end recorded in error to D-31 |
| CGR-27 | ABS1 (0046) | **blocking (S1)**, section 14:30 | confirmed by the PO reading `private.visit_interval` 0046:90-98 (untimed 00:00-00:01; start without end one minute); it widens ABS1-C1: **ABS1 part 2 criterion CGR-27** (`briefs/ABS1.md`) |
| CGR-28 | ABS1 with COVER1 | advisory (S2 if cover is enabled), section 14:30 | condition on enabling cover (D-3, with CGR-21): an absence also ends her covers in the period; recorded in `briefs/COVER1.md` and D-3 |
| CGR-29 | J5 (0043) | advisory (S3), section 14:30 | J5 accepted with it as a condition; criterion CGR-29 (part 9) |
| CGR-30 | CSR1 part 8 (#200) | advisory (S3), section 14:30 | fixed in #200 before merge (1e1d904); closed in the 15:00 section |
| CGR-19 | F6 | advisory (S2), section 02:28 | confirmed (0016 `correct_report` copies `r.performer_id`; `sign_report` requires the performer); interim refusal added to CSR1 2026-10-23 03:10; rule to D-30 (`clinical`, with `legal`) |

The report found no blocking finding for HAND1, RET1, AN1, PLAN2, J6, J1, J2 or COVER1 (switched off). Their acceptances stand; its advisory risks are tracked in `clinical/SAFETY_RISK_REGISTER.md`.
