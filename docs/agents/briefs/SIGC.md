---
id: SIGC
title: Signal conditions SIG1-C2, SIG1-C3, SIG2-C1 (one PR)
author: po
status: approved
updated: 2026-10-25
---

# SIGC — Signal conditions SIG1-C2, SIG1-C3, SIG2-C1 (one PR)

**ID change only (po 2026-10-25 02:10).** This item was approved on 2026-10-24 23:10 under the ID "SIG1-C2, SIG1-C3, SIG2-C1" (*Next up*). That ID contains spaces; the coordination watcher cannot read its own marker for such a key, so every run opened a new hand-off issue (#326, #329, #333, #334, #336, #339) and none was ever updated or closed. The content, the approval and the order are unchanged. This file holds no criterion of its own: the criteria stay where they were approved.

## Problem
See the conditions' own sections: `cra` 22:26 (#321) found CGR-46, CGR-47 and CGR-48 on SIG1 and SIG2.

## Users and journey step
Responsible nurse, her team and Operations; Visit → safety signal (SIG1, SIG2).

## Outcome
The response AN2 counts is the qualified one, the untested take paths are proven, and text and plan are honest outside watched hours, before the push channel is switched on.

## Acceptance criteria
- [ ] **SIG1-C2** and **SIG1-C3** exactly as written in [`SIG1.md`](SIG1.md), section "PO conditions — 2026-10-24 23:10".
- [ ] **SIG2-C1 (1)** and **SIG2-C1 (2)** exactly as written in [`SIG2.md`](SIG2.md), section "PO condition — 2026-10-24 23:10".
- [ ] One PR; the status row uses the ID `SIGC`.

## Rules and their input class
As stated in the SIG1 and SIG2 condition sections: every rule reads visit/schedule facts only (take, role, watched hours, planned interval); no clinical content.

## Out of scope
Any threshold change (D-28), switching the push channel on (owner, D-2, D-26), lifting SIG1-8 (Clinical Owner).

## Constraints and references
[`SIG1.md`](SIG1.md), [`SIG2.md`](SIG2.md); `cra` 22:26 (PR #321).

## PO review 2026-10-25 13:16 CET: criteria met, awaiting clinical review (not accepted)

**Reviewed:** PR #361 merged as `2ad9860` (merge commit; head `a2468b5`): migration 0068, ADR-082, pgTAP 069 (59), unit `signals-rules`, `analytics-hypotheses`, e2e `push.spec.ts` (SIG2-C1 (2)), component `OutsideWatchedVisits`, remediation plans `clinical/remediation/CGR-47.md`, `CGR-48.md`. **CI** `app`, `db`, `e2e` green on head `a2468b5` (run 40187846814); the push run on `2ad9860` was cancelled by the next push; green on `recovery/main` `1e796d2` (run 40188997348, contains `2ad9860`) and `1f3ff8a` (run 40190817363); read through the API. **The PO did not run the tests**; results below are from the code, the test files and CI.

| Criterion | Result | Evidence |
|---|---|---|
| SIG1-C2: for `no_show` and `visit_interrupted` AN2 counts the first take that stops the step | met | `private.signal_qualified_taken_at` (0068); 069:115-125: care assistant +2 min, registered nurse +20 min → median 20 min, taken-within-threshold 0 %; only a care assistant's take → not taken (base still 1) |
| SIG1-C2: first take of any member kept as its own, labelled value | met | `first_take_any_minutes` (069:119, 128), note "Nicht die qualifizierte Antwort" (069:138); no per-person key (069:143-145) |
| SIG1-C2: other kinds unchanged; AN1 suppression applies | met | `visit_overdue` counts its first take (069:131-132); suppression on all four measures (069:135-137) |
| SIG1-C3 (a) covering RN takes → stops, no Operations delivery | met | 069 (a): `stops_escalation` true, qualification read in the cover team, no Operations delivery after `signal_untaken` |
| SIG1-C3 (b) covering care assistant → false, Operations receives | met | 069 (b) |
| SIG1-C3 (c) Operations member who received it takes → true | met | 069 (c) |
| SIG1-C3 (d) care assistant in the owning team, RN only elsewhere → false | met | 069 (d): qualification read in the owning team |
| SIG2-C1 (1) honest text outside watched hours; unit test; pgTAP on the reader flag | met | `takenText` + `OPERATIONS_APP_ONLY` "Operations nur in der App: ausserhalb der überwachten Zeit" (`signals-rules.test.ts`:70-79, both own and other take); `my_signals.watched_now` false without hours, true inside, false outside (069) |
| SIG2-C1 (2) list on `/admin` (organisation) and `/team` (own team), next 7 days | met | `visits_outside_watched_hours` (0068); 069: 21:00-21:30 listed, 19:00-19:30 not, no hours → every planned visit, other organisation never; window today … today + 6; cancelled and suspended not listed; across midnight listed |
| SIG2-C1 (2) no client data beyond what the team reads | met | line = weekday, date, times, team only (e2e regex; component); team view own team only (069; e2e checks every line ends in the own team) |
| SIG2-C1 (2) e2e at 390 px | met | `push.spec.ts` SIG2-C1 (2): no overflow of the list box on `/admin`, no page overflow on `/team` |
| One PR, status row ID `SIGC` | met | #361; row `SIGC` |
| Clinical review gate | **awaiting clinical review** | no `cra` section covers 0068 (newest: 05:30 on `recovery/main`, 09:31 in open #358, both before the merge). CGR-46, CGR-47, CGR-48 (all advisory) are the findings this item answers; whether they are closed is `cra`'s call on `2ad9860` |

**Deviations decided:**
1. **A visit only partly outside the watched hours is listed** (Q14): decided by po, *listed*, as built (OPEN_DECISIONS *Decided*). Reason: the list replaces a manual control (SIG1-8) whose purpose is that no P1 falls into an hour nobody watches; the outside tail of a 19:30-20:30 visit is exactly such an hour. Shorter list is not a reason to miss it.
2. **Operations gets no list; no planning warning.** Accepted: the condition names `/admin` and `/team`; the team that planned the visit is the one that can move it (team autonomy), and the administrator confirms watched hours. A planning-time warning stays a candidate (challenge row 2026-10-25 13:16).
3. **059 count 43 → 44 and 067 catalogue +1 reader:** accepted; counts only, no expected value weakened (diff read).
4. **OPEN from eng 12:20 (not in #361):** `visits_outside_watched_hours` reads periods by the wall clock on the two clock-change nights, so it may list more, never fewer. Accepted as protective; no change requested. If `cra` judges otherwise, it rides with the next change to 0068.

**Business value and care model.** A go-live control that a person did by reading a plan (SIG1-8) is now a list the data computes, and AN2's response measure counts the response that actually stops the escalation, so pilot data cannot overstate how fast a qualified person responds. Less administration, honest evidence, no new role. SIG1-8 remains a go-live condition until the list is empty for the pilot plan.

**Why not accepted yet:** every criterion is met in code, but the item is in clinical scope (safety signals) and no `cra` section covers its merge commit (README *Clinical review gate*). PO status stays `approved`; the next PO run accepts once `cra` has reviewed `2ad9860` without a blocking finding.
