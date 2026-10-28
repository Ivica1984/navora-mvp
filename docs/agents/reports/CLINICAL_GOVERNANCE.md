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

## 2026-10-28 13:40 CET: #588 merged with the CGR-85 fix, CGR-85 closed; #598 (UX1 part (d) strings, head `961a936`) and #602 (UX1 part (g), head `d243dad`) clear on the clinical side; C-1 pointer question answered; D-38 T15 (b) and T16 safety-stop input given; CGR-86 (advisory S3: WORK1-5 pgTAP test nondeterministic, red twice today)

**Scope:** `recovery/main` @ `16c81b7`. Changes since my 09:30 CET section (`16dafb5`, PR #589, **still open**; it contains #582, my 05:30 section; both could not be merged by the previous runs, see *Decisions requested*). This PR carries both and supersedes them.
- **Code merged:** #588 (UX1 part (d), first PR) as `566dc8b`. Since the head I read at 09:30 (`9bc57d3`) one code commit was added: `7acacdd` "UX1-28: CGR-85" (`absence-section.tsx`, `tests/e2e/ux1.spec.ts`); the second merge `522f34b` changed only `JOURNAL.md`. CI `app`, `db`, `e2e`, `ui-screenshots` success on `566dc8b` (check runs read through the GitHub API). No migration.
- **Docs merged:** PO 10:10 (#590: CGR-85 placed as UX1-31), 11:10 (#596: STR-17, COORD6 brief, D-38 reopened with T15-T18 and T10 options), 12:15 (#601: `lca` 11:55 taken in; UX1-32, UX1-33, UX2-12); `csa` 10:47 (#595); `uxa` 11:49 (#599); `lca` 11:55 (#600); `eng` status (#591).
- **Open:** #598 `eng` UX1 part (d) strings (UX1-11 to UX1-13, UX1-32; ADR-108), head `961a936`; #602 `eng` UX1 part (g) (UX1-22 to UX1-24, UX1-33; ADR-109), head `d243dad`. CI on both heads was still running when I read them (`app` success on both). #589, #582 (mine); #3 (M2 to `main`) unchanged.
- **Asked of `cra`:** #602 body item 1 (is "Operations sieht es auch, noch nicht übernommen" a handling state in C-1's sense?) and item 2 (the red "Ergebnis erfassen" on an overdue visit); D-38 T15 (b) (which kinds of safety measure, no levels) and T16 (who may declare a safety stop), requested by the PO 11:10 and 12:15.
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read: `7acacdd` (`absence-section.tsx:13-35`, `ux1.spec.ts:436-450`, `:522-544`); the #598 diff of `src/` (17 files) and `tests/unit/ux1-strings.test.ts`, `tests/unit/support/user-facing-strings.ts`; the #602 diff of `src/` (`team-client.tsx`, `SignalBanner.tsx`, `features/team/rules.ts`, `features/push/rules.ts`, `features/intake/rules.ts`, `field-client.tsx`, `intake-client.tsx`, `absence-section.tsx`) and its tests (`ux1-team.test.ts`, `ux1-colour.test.ts`, `ux1-team.spec.ts`, `lifecycle.spec.ts`), `features/signals/rules.ts` (`splitSignals`) on its head; `briefs/UX1.md` UX1-22 to UX1-24, UX1-31 to UX1-33; `briefs/UX2.md` UX2-12; `decisions/D-38.md` T10, T15-T18 and `lca` 11:55; the annotations of the failed `db` jobs 122787176524, 122789338604, 122647083342 and issue #399. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-86 | **WORK1-5** control test (pgTAP 079 test 44), issue #399 | **advisory (S3)** | The test that proves a nurse's working-time acknowledgement changes nothing her teammates, her RN, a coach, Operations or an administrator can read has failed **twice today** on code that does not touch it, with a different role set each time: run 40679763184 (#601, docs only, 11:24 UTC) `have: ca,rn`, run 40680388064 (#602 first head, 11:29 UTC) `have: admin`; it passed on the same commits in parallel runs. With 2026-10-27 00:06 (`have: admin,ops`) and 04:20 (`have: ca,rn`) that is four recorded occurrences; a fifth `db` failure today (run 40637292260, push of `4fbcfbb`, 05:19 UTC) failed in *Database tests* with the failing test not readable here (UNKNOWN). The cause is still UNKNOWN (#399: candidate a read model that depends on the clock). Two readings are possible and the test cannot tell them apart: a test artefact, or a real, intermittent difference in what other roles read after a nurse acts (a privacy or independence leak, WORK1-5). While it is red at random, a real regression of this control would look like the known flake and would be re-run to green | `supabase/tests/database/079_work1_working_day.test.sql:52-` (fingerprint), test 44; check-run annotations of jobs 122787176524 and 122789338604 ("Failed test 44: WORK1-5 catalogue …", `have` as quoted, `want: NULL`); #399 comments 2026-10-26 23:20 and 2026-10-27 03:25 UTC; job 122647083342 step *Database tests* failure | **eng:** (1) the test reports **which** table or read model differs and for which role (its name in the failure message), so each occurrence is diagnosable from the annotation alone; (2) the cause is found and fixed (if a read model depends on the real clock, the fingerprint pins `navora.test_now` for both snapshots or excludes only that column with the reason written next to it); (3) the fix is shown by running pgTAP 079 repeatedly (for example 50 times in one CI job) with no failure. Until then each occurrence is recorded on #399 with its `have` value. Never skipped, never weakened. If (1) shows a real difference in what another role reads, the finding becomes blocking for WORK1 (S2) |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-85** | **closed** | `7acacdd`, merged in `566dc8b`, CI green. `absence-section.tsx:20-33`: `run` wraps the server action in `try`/`catch`/`finally`; a throw becomes `{ ok: false, error: ABSENCE_MESSAGES.failed }` ("Konnte nicht gespeichert werden. Bitte erneut versuchen.", existing text, `features/absence/rules.ts:5`), `pending` is reset in `finally`, `router.refresh()` still follows. Test `ux1.spec.ts:522` "CGR-85: a save lost in transit …": the held save is aborted with `internetdisconnected`; the open dialog shows `command-error` = `ABSENCE_MESSAGES.failed`, `absence-past-planned` has count 0, "Speichern" is back and "Abbrechen" enabled, Escape closes the dialog, nothing recorded. Remedy (1)-(3) met. The lost-response case (saved on the server, response lost) is not tested; a retry is then refused as `overlaps` (0046) and the past-visit flag (0053) is set, as stated at 09:30; I accept that |
| **CGR-84** | open, advisory (S3); remedy met at brief level (PLANNED) | no change; closes on the ASM1 build with the pgTAP |
| **CGR-81** | open, advisory (S2); remedy in the brief (PLANNED) | no change |
| **CGR-78** | open, advisory (S2); (a) and (b) met at brief level | no change |
| **CGR-75** | open, advisory (S2); (1)-(5) met at brief level | no change |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-85**.

### #602 (UX1 part (g)): clinical gate items

- **UX1-22 / C-1, the pointer line: confirmed (IMPLEMENTED on the PR head; CI decides).** `alertRepeatsSignal` (`features/team/rules.ts:140-145`) returns `true` only when an **open** card in the banner is for the same visit and the same situation (`signal_kind` = `exception_type`), the entry has no flags, Operations has not taken it, and the type is not `visit_interrupted`; otherwise the entry is in full. The open cards come from the banner's own polled rows (`SignalBanner.tsx:37-39` `onRows`; `team-client.tsx:114`, `splitSignals(...).open`), and the banner renders every open row (`SignalBanner.tsx:61`, no limit), so a pointer only appears while its card is on the same screen. A taken card (also a card taken by a care assistant that still awaits an RN, which `splitSignals` keeps open) leaves the pointer rule or keeps the card visible. The banner shows the signed-in person's signals only, so a member who has no card sees the entry in full. The "provisorisch" sentence is a separate, always-rendered line (`team-client.tsx:226`), asserted in `lifecycle.spec.ts`; the follow-up form stays one tap away (same test).
- **#602 item 1 (asked of `cra`): "Operations sieht es auch, noch nicht übernommen" is not a handling state in C-1's sense.** It is the default text for "nobody at Operations has taken it" (`visitAlertHandling(false)`, `rules.ts:110-112`). C-1 protects information the card lacks; that nobody has taken the situation yet is exactly what an **open** card shows (it is in the open list with "Ich übernehme"). Once Operations takes it, `taken` is true and the entry is in full again with "Operations ist informiert und kümmert sich mit". The pointer may drop the default sentence, the detail line and the age. **Keep `alertRepeatsSignal` as written.**
- **#602 item 2: the red "Ergebnis erfassen" on an overdue visit.** No clinical objection to keeping red there: `visit_overdue` is itself a SIG1 situation, so the colour marks the action that ends a safety signal, which is consistent with C-2 (a) ("red only for safety signals"). Whether to keep it is `uxa`'s design call.
- **UX1-23 / C-2 (a): confirmed.** One urgency map (`features/intake/rules.ts`, `URGENCY_BADGE_CLASS`), "hoch" amber with the word kept, an unknown value neutral; `ux1-colour.test.ts`. The visit status badges "abgesagt" and "nicht angetroffen" on `/field` become neutral: they are status labels; a no-show that needs action is carried by its SIG1 card and its CSR1 entry, not by the badge. No text changed.
- **UX1-24 / C-3: confirmed.** `allReachable` is true only when the list is not empty and every listed member is active (`features/push/rules.ts`); while not, the team status is open, amber, with `REACH_GAP_TEXT` = my C-3 wording and the link "Meine Einstellungen" (`ux1-team.spec.ts`, seed team 0 of 2). No per-member detail beyond active / not active.
- **UX1-33 (focus):** presentation only; the CGR-32 notice text, position and link are unchanged; the CGR-85 path also returns focus to "Speichern".
- **PR deviation 3 (pointer path not seeded in e2e):** accepted. The rule's fail-safe direction is the full entry, and every input of the rule is unit-tested. A seed state with an open SIG1 card and its CSR1 entry at once, asserted at 390 px, is a useful UX2 addition, not a condition.

### #598 (UX1 part (d), strings): clinical gate items

- **UX1-11 (no codes in page text): confirmed.** Every removed code moves into a `data-ref` attribute on the same element (`D-3`, `D-11`, `D-15`, `D-22`, `D-26`, `SIG1-8`), and the sentence keeps its meaning: "… die fachliche Freigabe der Zuordnung ist offen", "Frist und Inhalt der Information sind offen", "nicht hinterlegt (Pilotkanton offen)", "Bis zur Freigabe durch die Clinical Owner bleibt diese Bedingung bestehen: jemand beobachtet die Signale in jeder geplanten Stunde." The SIG1-8 condition is still stated in full, the open decisions still read as open. `ux1-strings.test.ts` guards that the scan reads pages, that no code survives outside `data-ref`, and that the removed codes stay as `data-ref`.
- **UX1-13 (one product name, one label per page) and UX1-32: confirmed.** Labels only ("Ausnahmen" for the OPS1 exception centre, "Kennzahlen", "Dein Team", "Details zum Pflegeteam"). No text fixed by `cra` or `lca` (hold meaning, IPA1, WORK1, SIG1-8 wording beyond the code, billing limits, the provisional notes) is changed in substance; no route, rule, filter or read scope changes.

### D-38: `cra` input on T15 (b) and T16 (asked by the PO 11:10 and 12:15; input, not a decision)

**T15 (b): kinds of safety measure for a transition (no levels).** I name kinds that existing controls or open findings already define; every level, count, deadline or threshold is the Clinical Owner's (D-27, G-1), UNKNOWN until set:
1. **No client without a named responsible provider on any date:** for every client of the team, either the partner or C (or a provider that confirmed in writing, T12 (i) (b)) is responsible on each day of the window, and C's three prerequisites are recorded before a client moves (T12 (i) (a); H-23).
2. **No open safety item without a responsible person at cut-over:** open SIG1 signals, open CSR1 entries (visit not done or stuck, interrupted visit without a follow-up decision, report not final, order without end date) and returned reports not yet signed again are either closed or handed to a named person of the provider that will act on them (CGR-04, CGR-24, CGR-25, F6R).
3. **Reachability for safety signals:** every member who will visit under C receives P1 signals outside the app, or the SIG1-8 watch condition holds for C (UX1-24, SIG2).
4. **Documentation integrity:** every record that moves is final and signed, its authorship and changes after `final` are kept, and C has accepted a usable export (T2 (ii)-(iii), T18 (e)).
5. **Medical orders:** each moving client's order is valid on the cut-over date and names the issuing doctor (D-22, CR-003), so that care under C does not start without an order.
6. **Qualification and delegation:** C's staff for each care category meet the qualification gate already enforced (CR-007), and C's Leitung Pflege and deputy are named (T18 (b)).
7. **Rules adopted:** C has adopted, through its own Leitung Pflege, the clinical rules it will use (T13, T18 (d)); none is assumed from the partner.
8. **No open S1 finding** in the governance report for the functions C will use.
Whether each kind is required, and at which level, is the Clinical Owner's decision. I do not add an interRAI, PAG or MQI criterion: none is defined for this.

**T16: who may declare and lift a safety stop (proposal, for the owner and the Clinical Owner).**
- **Declare:** the Clinical Owner (once named, G-1); the partner's Leitung Pflege for her clients; C's Leitung Pflege for C's side. A `cra` S1 finding on a function C will use holds the transition automatically until a qualified person has reviewed it (I am not a decision owner, D-27). Any team member may raise a safety concern that pauses the date until a Leitung Pflege has decided; the time she has to decide is a level (Clinical Owner, UNKNOWN).
- **Lift:** only the Clinical Owner, recorded with who, when and why. Neither the owner nor the partner's management nor C's commercial side can lift a stop alone, because they have a commercial interest in the date.
- **During a stop:** T15 (f) and T12 continuity apply (no notice, no transfer date, the current provider keeps visiting).

### Other checks (no finding)

- **UX1-31, UX1-32, UX1-33, UX2-12 (PO 10:10, 12:15):** UX1-31 is my CGR-85 remedy word for word. UX1-32, UX1-33, UX2-12 are presentation; no clinical effect.
- **COORD6 brief, STR-17 F4 (*Pending wording*):** F4 applies `cra` S1/S2 findings at once; the S3 batching does not delay a safety finding. Agreed.
- **No new hard-coded clinical, tariff, LTCF, interRAI, PAG or MQI rule** on `recovery/main` since 09:30 or in #598 or #602 (new constants are labels, colours and the C-1 presentation rule). No Clinical Rule Register row.

### Gate status

| Item | Clinical gate |
|---|---|
| **#588** UX1-28 to UX1-31 | merged; CGR-85 closed |
| **#598** UX1-11 to UX1-13, UX1-32 (head `961a936`) | **clear to merge on the clinical side** once CI is green; the UX1-12 string list for part (d) is complete |
| **#602** UX1-22 to UX1-24, UX1-33 (head `d243dad`) | **clear to merge on the clinical side** once CI is green; item 1 answered (keep the rule), item 2 no objection |
| **UX1** | no open `cra` finding; `delivered` per the PO's list when #598 and #602 are merged with green CI |
| **WORK1** (accepted) | CGR-86 advisory; becomes blocking only if the cause is a real read difference |
| **ASM1** (approved, not built) | CGR-81 and CGR-84 remedies in the brief; both close on the build with their tests |
| **D-38** (`owner`, inputs requested) | `cra` input on T15 (b) and T16 given above; no open CGR on D-38 |
| **ADM2** | unchanged: CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **po:** take the T15 (b) and T16 input into D-38; place CGR-86. **This PR contains #589 and #582; they can be closed once it is merged.** The previous runs could not merge their own PR (environment permission check); if this run cannot either, `po` or the owner merges it. That is the only reason, not CI.
- **eng:** CGR-86 (1)-(3) on #399. Still open: does "Ich kann nicht arbeiten" cover a single visit (UX2 suggestion, 21:30)? Does PLAN2 re-create a hand-removed care-plan visit (C-2 (b), 13:37)?
- **clinical (Clinical Owner, after G-1):** the levels for the T15 (b) kinds and the decision time in T16; which periods assessed minutes refer to and when a total may be shown (CGR-81, CGR-84); the D-38 handover set; D-34 question 7, D-10, D-15, D-16 (with 3b), D-17, D-28, D-31; D-37 interval and triggers. All UNKNOWN until answered.
- **owner / legal / regulatory adviser:** G-1; D-38 T1-T18 and T10 with the Zurich adviser bundle; MepV reporting for a rule withdrawal (D-34); R-11 for C; D-36 licence terms; D-1.

---

## 2026-10-28 09:30 CET: #574 merged unchanged, CGR-80 closed; UX1 part (d) first PR #588 (head `9bc57d3`) read: UX1-28 (c) notice display confirmed, UX1-30 conditions (1)-(3) met, string list confirmed; CGR-85 (advisory S3: a thrown save locks the absence dialog with no outcome); UX2-11 placed as written

**Scope:** `recovery/main` @ `18b4ba9`. Changes since my 05:30 CET section (`b47545e`, PR #582, **still open**: this run could not merge it; this PR carries it, see *Decisions requested*):
- **Code merged:** #574 (UX1-18, UX1-27) as `93f7423`. Its branch got one merge of `recovery/main` (`e759825`, JOURNAL conflict only); `git diff 7988945 e759825 -- src supabase tests` is empty, so the merged code is the head I reviewed at 01:30 and 05:30. CI `app`, `db`, `e2e`, `ui-screenshots` success on `93f7423` and on `18b4ba9` (check runs read through the GitHub API). No migration.
- **Docs merged:** PO 06:10 (#583: UX1-30 conditions (1)-(3); UX2-11 new); `eng` status (#584); `uxa` 07:50 (#586); `aia` 08:20 (#587).
- **Open:** #588 `eng` UX1 part (d), first PR (UX1-28, UX1-29, UX1-30, UXR-17 removal; ADR-107), head `9bc57d3`, CI `app`, `db`, `e2e`, `ui-screenshots` success; #582 (my 05:30 section). #3 (M2 to `main`) unchanged.
- **Asked of `cra`:** UX1-12 string list (#588 body), UX1-28 (c) notice display, UX1-30 (1)-(3) (PO 06:10, `eng` #588).
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read: the #588 diff of `absence-section.tsx`, `field-client.tsx`, `features/field/todo.ts`, `(auth)/login/page.tsx`, `tests/unit/ux1-todo.test.ts`, `tests/unit/ux1-contrast.test.ts`, `tests/e2e/ux1.spec.ts:459-` and `tests/e2e/field.spec.ts` (F6R test at `:355`, ABS1-C6 at `:464`); on the PR head `features/field/report.ts:34-65`, `features/absence/commands.ts` (server action) and `features/absence/rules.ts` (`ABSENCE_MESSAGES`); the brief diffs `UX1.md` (UX1-30) and `UX2.md` (UX2-11). **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-85 | **UX1-28** (#588, head `9bc57d3`) | **advisory (S3); fix in #588 before merge preferred, at the latest before UX1 is `delivered`** | UX1-28 makes the absence dialog undismissable while the save is pending, so that the outcome is always shown. But `useAbsenceRun().run` has no `try`/`finally`: `setPending(false)` runs only when the server action returns. A call that throws (lost connection or a dropped response: the weak-connection case UXR-18 was written for) leaves `pending` true for good. The nurse then sees "Wird gespeichert …", Escape is cancelled, "Abbrechen" is disabled, and no outcome is shown. She cannot tell whether she is recorded absent until she reloads the page. Before #588 the same throw also showed nothing, but she could close the dialog. The lasting controls are unchanged: the overlap check (0046) refuses a second absence for the same time, so a retry cannot duplicate one, and past planned visits stay flagged (0053, CGR-32). If the response was lost after a recorded save, the retry shows `overlaps`, not the CGR-32 notice. The team still sees the flag. | `absence-section.tsx:16-24` (`run`: `await fn()` then `setPending(false)`, no `try`); `:53` (Escape cancelled while `pending`); `:62` (`cancel` prevented while `pending`); `:127` (`Abbrechen` `disabled={pending}`); `commands.ts:1` (`"use server"`: a client-side call that rejects on a transport failure). No test covers a thrown save | (1) `run` resets `pending` in `finally`. On a throw it shows `ABSENCE_MESSAGES.failed` as `command-error` in the open dialog and calls `router.refresh()` (existing text, no new wording). (2) Playwright, same harness as `holdNextSave` (`ux1.spec.ts`): hold the save, then `route.abort()`. The dialog stays open, `command-error` equals `ABSENCE_MESSAGES.failed`, `absence-past-planned` has count 0, "Abbrechen" is enabled again, and Escape closes the dialog. (3) Negative: UX1-28 (a)-(e) unchanged. The same `run` serves "Verkürzen"/"Zurückziehen" (`:177-180`) and `takeOpenVisit`; (1) covers them too |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-80** | **closed** | #574 merged as `93f7423`, code identical to the reviewed head `7988945` (diff above empty). `tests/e2e/ux1.spec.ts:354-428` on `93f7423` ("UX1-27: open work stays in sight above the next visit": `todo-links` above `next-visit` and inside the first viewport at 390 × 844, label "Nicht abgeschlossen: Entscheid offen (n)"); `tests/unit/ux1-todo.test.ts` (one constant `FOLLOWUP_HEADING` for link, label and `h2`). CI green on `93f7423` |
| **CGR-84** | open, advisory (S3); remedy met at brief level (PLANNED) | no change; closes on the ASM1 build with the pgTAP |
| **CGR-81** | open, advisory (S2); remedy in the brief (PLANNED) | no change |
| **CGR-78** | open, advisory (S2); (a) and (b) met at brief level | no change |
| **CGR-75** | open, advisory (S2); (1)-(5) met at brief level | no change |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-80**.

### #588 (UX1 part (d), first PR): clinical gate items

- **UX1-28 (c), (d): CGR-32 notice display confirmed (IMPLEMENTED on the PR head; CI green).** `field.spec.ts:464-` (ABS1-C6, the one seeded case with a planned visit before today). It holds the save, then checks that Escape and "Abbrechen" leave the form open. After release, `absence-past-planned` is visible **inside** `getByRole("dialog", { name: "Ich kann nicht arbeiten" })`, with its text equal to `` `${pastPlannedNotice(1)} · Zum Team` `` (the function's value, not a literal) and the link "Zum Team" in the dialog. It is still visible after `networkidle`, so the refresh after the save does not clear it. The notice is cleared only in `onClosed` (her own close). (e): a refused save shows `command-error` = `ABSENCE_MESSAGES.rejected` and no `absence-past-planned` anywhere on the page. A save with no past planned visit closes the dialog as before (`ux1.spec.ts` part (d)). Where, until when, the link: as UX1-28 (c) states. **Confirmed.** CGR-85 is a different path: a save that throws.
- **UX1-30 conditions (1)-(3): met** (`ux1-todo.test.ts:61-90`). (1) `returned-instruction` sits directly after the `h2` and before the `ul`, unconditional (only whitespace between `</h2>` and the `<p>`). No `hidden`, `sr-only`, `details`, `aria-expanded` or `aria-hidden`. The e2e asserts it is visible (`field.spec.ts:355-361`). (2) `RETURNED_INSTRUCTION` = "bitte korrigieren und neu unterschreiben", rendered through `returnedInstructionLine()` (first letter only). Both are asserted against the constant. (3) The returner's name and reason line and both performer and non-performer labels in `report.ts` are pinned. `report.ts` is not in the diff, so `RETURNED_UNAVAILABLE_LABEL` (LEAVE1-11) is unchanged too; it is not pinned by the test, which is acceptable as long as the file is untouched. The section is still rendered only from `field_returned_reports` (her own reports), so the instruction is correct for every row.
- **UX1-12 string list (this PR's four strings): confirmed.** (i) Heading "Zurückgegeben (n)" plus the first line "Bitte korrigieren und neu unterschreiben": same words, see (2). (ii) The dialog's accessible name "Abwesenheit" becomes the visible `h2` "Ich kann nicht arbeiten": no clinical text. (iii) The `/login` panel "Geschützter Zugriff / … serverseitig geprüft" is removed: no clinical or legal content. No text fixed by `cra` or `lca` (hold meaning, IPA1, WORK1, SIG1-8, billing limits) is touched. The rest of UX1-11 to UX1-13 (code strings, product name) is still PLANNED, and `cra` reads that list on its PR.
- **UX1-29, UXR-17 removal, countersignature constant:** presentation only; no clinical effect.

### Other checks (no finding)

- **UX2-11 (PO 06:10):** my 05:30 property, placed as written. A returned report stays on her `/field` until she signs again, whatever the visit date. The test uses a past-dated returned report and checks it is gone after she signs again. Negative: `field_returned_reports`, F6R and the fixed texts are unchanged. Agreed.
- **UX1-30 brief text (PO 06:10):** conditions (1)-(3) as I gave them; fallback kept.
- **`aia` 08:20, `uxa` 07:50:** no clinical point beyond what I set at 05:30.
- **No new hard-coded clinical, tariff, LTCF, interRAI, PAG or MQI rule** on `recovery/main` since 05:30 or in #588 (the new constants are section labels and an existing instruction). No Clinical Rule Register row.

### Gate status

| Item | Clinical gate |
|---|---|
| **UX1-18, UX1-27** (#574) | merged; CGR-80 closed |
| **#588** UX1-28, UX1-29, UX1-30, UXR-17 (head `9bc57d3`) | **clear to merge on the clinical side** for UX1-28 (c)-(e), UX1-30 (1)-(3) and the string list; **CGR-85 advisory**: fix in #588 preferred. If it merges without the fix, CGR-85 must be fixed before UX1 is `delivered`; the PO records which |
| **UX1** rest of part (d) (UX1-11 to UX1-13 code strings), part (g) | `cra` reads the full string list (UX1-12) before merge |
| **UX2** (UX2-11 added) | no clinical finding; UX2-11 is the F6R-5 control for the redesign |
| **ASM1** (approved, not built) | CGR-81 and CGR-84 remedies in the brief; both close on the build with their tests |
| **D-38** (`owner`, escalated, frozen) | unchanged |
| **ADM2** | unchanged: CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **po:** place CGR-85 (into #588 before merge, or into UX1 before `delivered`). PR #582 (my 05:30 section) is contained in this PR; it can be closed once this one merges. **This run's attempt to merge #582 was refused by its environment's permission check, so both governance PRs wait for a merge by `po` or the owner. That is the reason, not CI.**
- **eng:** CGR-85 remedy (1)-(3) in #588. Still open: does "Ich kann nicht arbeiten" cover a single visit (UX2 suggestion, 21:30)? Does PLAN2 re-create a hand-removed care-plan visit (C-2 (b), 13:37)?
- **clinical (Clinical Owner, after G-1):** which periods assessed minutes refer to and when a total may be shown (CGR-81, CGR-84); the D-38 handover set; D-34 question 7, D-10, D-15, D-16 (with 3b), D-17, D-28, D-31; D-37 interval and triggers. All UNKNOWN until answered.
- **owner / legal / regulatory adviser:** G-1; D-38 T1-T14 (with the window length) and the Zurich adviser bundle; MepV reporting for a rule withdrawal (D-34); R-11 for C; D-36 licence terms; D-1.

---

## 2026-10-28 05:30 CET: no code merged; #574 unchanged (head `7988945`, still clear, CGR-80 closes on merge); CGR-84 remedy in the ASM1 brief (met at brief level, closes on the build); UX1-30 instruction move confirmed with three test conditions; AUT-13 import and AI §12 control read; no new finding

**Scope:** `recovery/main` @ `c1c090f`. Changes since my 01:30 CET section (`9f2533f`, merged by #577):
- **Code merged:** none. No file under `src/`, `supabase/` or `tests/` changed on `recovery/main` since `d12a7a7`. No migration.
- **Docs merged:** PO 02:10 (#578: ASM1-1 period storage from CGR-84; UX1-28 (d), (e)), 04:10 (#581: UX1-30 from UXR-20; UX2-10 from UXR-21); `lca` 00:45 (#575, D-38 re-check); `aia` 02:20 (#579: AUT-13, AI Operating Model Review §12); `uxa` 03:50 (#580: UXR-20, UXR-21, design system v7).
- **Open:** #574 `eng` UX1-18 and UX1-27, head still `7988945` (CI `app`, `db`, `e2e`, `ui-screenshots` success, check runs read through the GitHub API; no new commit since my 01:30 read). #3 (M2 to `main`) unchanged.
- **Asked of `cra`:** PO 04:10, UX1-30: confirm moving the instruction "bitte korrigieren und neu unterschreiben" from the returned-reports heading into the section's first line.
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read: the diffs of `briefs/ASM1.md` (ASM1-1 as amended 02:10), `briefs/UX1.md` (UX1-28 (d)-(e), UX1-30), `briefs/UX2.md` (UX2-10), `decisions/D-38.md` (`lca` 00:45), `reports/AUTOMATION_REVIEW.md` (02:20), `docs/product/AI_OPERATING_MODEL_REVIEW.md` §12, `docs/design/DESIGN_SYSTEM.md` v7; for UX1-30 the returned-reports section and link on `recovery/main` (`field-client.tsx:154-166`, `:217-235`), the visit-card report state (`features/field/report.ts:40-62`) and `field_returned_reports` (0065:509, the caller's own returned reports). **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

No new finding.

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-84** | open, advisory (S3); **remedy met at brief level (PLANNED)**; closes on the merged ASM1 build with the pgTAP | `briefs/ASM1.md:21` (po 02:10): the period is stored "as the text entered, or as a value from the organisation's own reference list maintained like the instrument list (ASM1-6); no list of periods in a migration, constant or seed beyond synthetic test data"; pgTAP: no `check` or enum on its values beyond non-empty and a length limit; a proposed fixed list is first a Clinical Rule Register row, owner `clinical`/`legal`, PROVISIONAL, before build. This is my remedy word for word |
| **CGR-80** | open, advisory (S3); remedy met on the #574 head `7988945` (unchanged since 01:30, CI green); closes when #574 is merged unchanged | as 01:30 |
| **CGR-81** | open, advisory (S2); remedy in the brief (PLANNED); closes on the ASM1 build | unchanged. AI Operating Model Review §12 (`aia` 02:20) now carries the same control for agents: no sum, difference or per-period conversion of assessed against planned minutes, and no mark derived from them, before a `cra`-reviewed brief. Consistent with CGR-81; I agree |
| **CGR-78** | open, advisory (S2); (a) and (b) met at brief level | no change |
| **CGR-75** | open, advisory (S2); (1)-(5) met at brief level | no change |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: none.

### Inputs requested of `cra` (clinical review input; I decide nothing, D-27)

- **UX1-30 (PO 04:10): may the instruction move from the returned-reports heading into the section's first line?** **Yes, with three conditions for the same unit test.** What F6R-5 needs from this section: a nurse whose signed report a registered nurse returned sees, on her day, that she must correct it and sign again, which report, and why. Today the section heading carries the instruction (`field-client.tsx:221`) and each item carries the returner's name and the reason (`:229-231`); the visit card itself shows "Zurückgegeben: bitte korrigieren und neu unterschreiben" where she acts (`report.ts:53`). The section lists only her own returned reports (`field_returned_reports`, 0065:509), so the instruction addressed to her is correct for every row. A heading "Zurückgegeben (n)" with the instruction as the section's first line keeps all three facts in sight. Conditions: (1) the instruction is rendered whenever the section is rendered, inside `returned-reports`, after the `h2` and before the first list item, never collapsed or behind a toggle; the test asserts its presence and its position before the first `li`; (2) its text comes from one constant equal to the existing wording (capital first letter only), asserted against the constant, not a literal; (3) negative: each item's returner name and reason, and the visit-card label in `report.ts` (performer and non-performer forms, `RETURNED_UNAVAILABLE_LABEL`), are unchanged. If (1)-(3) are not in the part (d) PR, the PO's fallback (link = full existing heading) applies and needs nothing from me. I re-check on the part (d) PR. Not a new finding.
- **PO challenge 04:10 (correction as the next action on the visit card, not a second list):** clinically acceptable later, provided a returned report never drops off her day while unsigned (F6R-5: it stays "until she signs again", any date). That is the property a UX2 or F6 redesign must keep, with a test that a returned report dated in the past still appears on today's view. Recorded for the UX2 / F6 brief; nothing to do now.

### Other checks (no finding)

- **AUT-13 (`aia` 02:20, import of assessment header values instead of transcription; not briefed):** clinically acceptable as described (deterministic, header values only, confirmed value by value by the assessing RN, assessment fields never `schedule`). For the later brief, in addition: an imported draft counts as no assessment record until confirmed (it neither satisfies a reassessment due date nor feeds A10); the period is imported as the tool states it and never mapped or converted (CGR-84); the record keeps whether each value was imported or typed. Recorded under H-22; `cra` reviews that brief.
- **UX1-28 (d), (e) (PO 02:10):** my two additions placed as written. Gate for part (d) as 01:30.
- **UX2-10 (axe on working states):** CI coverage only; no text, rule or field. No clinical effect.
- **D-38 (`lca` 00:45):** no change to the package text; no new clinical point. Handover set (T12 (iv)) and window length remain `clinical` and `owner`, UNKNOWN.
- **Design system v7:** jump-link and dialog rules restate UX1-27 to UX1-30; nothing clinical added.
- **No new hard-coded clinical, tariff, LTCF, interRAI, PAG or MQI rule** on `recovery/main` since 01:30 or in #574. No Clinical Rule Register row.

### Gate status

| Item | Clinical gate |
|---|---|
| **UX1-18, UX1-27** (#574, open, head `7988945`) | **clear to merge** (clinical side), unchanged; CGR-80 closes on merge |
| **UX1** part (d) (UX1-11 to UX1-13, UX1-27 to UX1-30; not opened) | `cra` reads the string list, UX1-28 (a)-(e) and UX1-30 with conditions (1)-(3) above before merge |
| **ASM1** (approved, not built) | CGR-81 and CGR-84 remedies in the brief; both close on the build with their tests |
| **UX2** (UX2-10 added) | no clinical finding |
| **D-38** (`owner`, escalated, frozen) | unchanged: no open clinical finding on the text; H-23 and R-11 code controls PLANNED |
| **ADM2** | unchanged: CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **po:** UX1-30 conditions (1)-(3) into the brief, or keep the fallback; record the F6R-5 property (a returned report never leaves her day while unsigned) for the UX2 / F6 redesign the 04:10 challenge names.
- **eng:** merge #574 when ready (CGR-80); part (d) as above; still open: does "Ich kann nicht arbeiten" cover a single visit (UX2 suggestion, 21:30); does PLAN2 re-create a hand-removed care-plan visit (C-2 (b), 13:37)?
- **clinical (Clinical Owner, after G-1):** which periods assessed minutes refer to and when a total may be shown (CGR-81, CGR-84); the D-38 handover set; D-34 question 7, D-10, D-15, D-16 (with 3b), D-17, D-28, D-31; D-37 interval and triggers. All UNKNOWN until answered.
- **owner / legal / regulatory adviser:** G-1; D-38 T1-T14 (with the window length) and the Zurich adviser bundle; MepV reporting for a rule withdrawal (D-34); R-11 for C; D-36 licence terms (also for an AUT-13 import); D-1.

---

## 2026-10-28 01:30 CET: #554 and #558 merged as reviewed; #574 (UX1-27, head `7988945`) meets CGR-80, closes on merge; CGR-81 remedy in the ASM1 brief (no longer blocking ASM1-11 acceptance, closes on the build); CGR-82 and CGR-83 closed at package level (D-38 T12 (i) (a)-(b), T13 (e)-(f)); CGR-84 (advisory S3, ASM1-1 period values); UX1-28 (c) notice display confirmed

**Scope:** `recovery/main` @ `07261f1`. Changes since my 21:30 CET section (`c20106f`, merged by #565):
- **Code merged:** #554 UX1 part (c) as `334682f`; its second parent is `822646d`, the head I reviewed at 21:30 (no `src/`, `supabase/` or `tests/` difference). #558 UX1 part (f) as `caf454e`; between `de27fee` (read at 21:30) and its merged head `1e75521` no `src/`, `supabase/` or `tests/` file changed. No migration since my last section.
- **Docs merged:** PO 22:15 (#568), 00:15 (#573), 01:10 (#576); `lca` 21:45 (#566), 23:41 (#571); `uxa` 23:49 (#572); `eng` status (#567, #570).
- **Open:** #574 `eng` UX1-18 and UX1-27 (ADR-106; head `7988945`; CI `app`, `db`, `e2e`, `ui-screenshots` success, check runs read through the GitHub API); #575 `lca` 00:45 D-38 re-check (docs). #3 (M2 to `main`) unchanged.
- **Asked of `cra`:** PO 00:15 / 01:10: confirm that UX1-28 (c) shows the CGR-32 notice correctly (where, until when, the link).
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read: the `src/` and `tests/` diff of #558 against `334682f` (`login/page.tsx`, `field-client.tsx`, `report-section.tsx`, `SafetyAlertForm.tsx`, `intake-client.tsx`, `team-client.tsx`, `ux1-contrast.test.ts`, `ux1.spec.ts`); the #574 diff (`field-client.tsx`, `features/field/todo.ts`, `ux1-todo.test.ts`, `ux1.spec.ts:354-428`, colour-only changes in `holds-panel.tsx`, `billing-preview.tsx` and the coordination pages); `absence-section.tsx:37-128` and `features/absence/rules.ts:69-74` (`pastPlannedNotice`) for UX1-28; ASM1-1, ASM1-11 and the 22:15 amendment (`briefs/ASM1.md:21`, `:31`, `:56`) with `care_plan_items` frequency columns (0025:26-37); D-38 T3, T12, T13 (`decisions/D-38.md:52-53`) with `lca` 21:45, 23:41 and the PO notes 22:15, 00:15, 01:10; UX1-27 to UX1-29 (`briefs/UX1.md`). **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-84 | **ASM1-1** as amended 22:15 (period with the assessed minutes; ASM1 approved, not built) | **advisory (S3); before ASM1 build** | The brief requires a period for each assessed minutes value ("as entered from the assessment"; NAVORA offers no default and derives none) but does not say **how the period is stored**. If Engineering writes the allowed periods into a migration (a `check` list or enum such as "Tag / Woche / Monat / Quartal"), NAVORA would hard-code which periods an assessment uses: the question the brief itself marks `clinical`/`legal` (KLV Art. 8), UNKNOWN. PLAN2's `freq_period in ('day','week')` (0025:33) is a planning field and does not answer it either | `briefs/ASM1.md:21` (ASM1-1 period, "NAVORA offers no default period and derives none"), `:31` (out of scope: "which periods an assessment uses (`clinical`/`legal`, UNKNOWN)"); 0025:26-37 | **po (brief wording; no clinical rule) / eng (build):** ASM1-1: the period is stored as the text entered, or as a value from the organisation's own reference list maintained like the instrument list (ASM1-6); no list of periods in a migration, constant or seed beyond synthetic test data. pgTAP: the period column has no `check` constraint or enum restricting its values beyond non-empty and a length limit; minutes without a period are refused (as written). If Engineering proposes a fixed list, it is a Clinical Rule Register row with owner `clinical`/`legal` and status PROVISIONAL, raised before build |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-80** | open, advisory (S3); **remedy met on the #574 head `7988945`** (CI green); closes when #574 is merged unchanged | (a) `ux1.spec.ts:354-428` (#574): a seed nurse with an open interruption follow-up (`client_transferred`, created through the product, decided again at the end); at 390 × 844 `todo-links` is rendered, its bottom inside the first viewport (plus a SIG1 banner's own height, PR deviation 2, which I accept: SIG1 above it is the intended order), above `next-visit` by `boundingBox().y` and by DOM order, and SIG1 still before it. (b) `features/field/todo.ts` one constant `FOLLOWUP_HEADING` "Nicht abgeschlossen: Entscheid offen" for the link, the section's `aria-label` and its heading (`field-client.tsx:162`, `:208-209`); `ux1-todo.test.ts` pins all three and forbids the short wording; the e2e compares the link's text with the rendered heading. The returned-report case of (a) is not seeded; the row is one element for all three links, so the position test covers it |
| **CGR-81** | open, advisory (S2); **no longer blocking ASM1-11 acceptance: remedy (1) and (2) in the brief (PLANNED)**; closes on the merged ASM1 build with the tests | `briefs/ASM1.md:21` (ASM1-1: each minutes value with its period as entered, no default, none derived, pgTAP refuses minutes without a period); `:31` (ASM1-11 rewritten: items listed as written, PLAN2's structured frequency shown as recorded where present, "No total, sum, average, difference or per-period conversion is computed or shown", acceptance (1) the no-sum test with "30 min, 2× täglich" and "60 min, 1× wöchentlich"; a total only by a later brief with `cra` review); `:56`. PO note on PLAN2 (0025): checked; the structured frequency is optional per item (0025:32) and the assessment's period is still UNKNOWN, so the PO's conclusion holds. How the period is stored: CGR-84 |
| **CGR-82** | **closed** (package text); the code part continues in H-23 | `decisions/D-38.md:52` T12 (i) (a) "the window's end never moves a client whose C prerequisites are not recorded; the first sentence of (i) always applies"; (b) the partner names who visits each such client after the team has left, and (00:15, `lca` 23:41) another provider counts only once it has confirmed in writing that it takes her from a stated date and her choice is recorded; until then the partner's own staff visit her; data only under T3 (extended to that provider). This is stronger than my remedy: a name on paper no longer meets the term. The second branch I offered (continued employment) was left out by the PO because it depends on an unresolved legal question; the first branch alone closes the care gap, so I accept it. The later pgTAP (a cut-over is refused while C's three prerequisites are missing, whatever the date) stays a required control of H-23 |
| **CGR-83** | **closed** (package text); the code part continues in R-11 | `decisions/D-38.md:53` T13 (e) the adopted version keeps running until she marks the new one, side by side, except a version withdrawn under (f); (f) a rule withdrawn as unsafe stops for every provider at once, limited to safety withdrawals, same-day notice to the Leitung Pflege and her deputy with the reason and the stopped rules (so she can put substitute measures in place), recorded with who, when, why; an ordinary change is never made as a withdrawal. `lca` 21:45 found (f) consistent with D-12 settled point 3. The later pgTAP (an unmarked new version does not replace the adopted one; a withdrawn rule is evaluated for no provider) stays required in the brief that builds rule adoption. MepV reporting for a withdrawal: regulatory adviser (D-34), UNKNOWN |
| **CGR-78** | open, advisory (S2); (a) and (b) met at brief level | no change; closes on the merged AIG1 and PLAN3 builds |
| **CGR-75** | open, advisory (S2); (1)-(5) met at brief level | no change |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-82, CGR-83** (package level, evidence above).

### Merged code (#554, #558): no clinical finding

- **#554** merged as reviewed (`822646d`); my 21:30 gate stands. CGR-80 is placed as UX1-27 (PO 22:15) and built in #574.
- **#558** (part (f)): `/login` becomes one page for every role; the text "Admin / Coach Portal" and the info cards go; sign-in logic, session check and redirect are unchanged (no `src/lib/auth` or middleware file in the diff). Low-opacity secondary text on `/field`, `/team`, `/intake`, the report section and `SafetyAlertForm` becomes `text-secondary` (more readable); `/intake` inputs gain `min-w-0`; no text, rule, order or field changes on a clinical screen. UXR-17 (removing "Die Sitzung wird serverseitig geprüft") removes no protection: the check is server-side whether or not the page says so.

### #574 (UX1-18, UX1-27; open, head `7988945`): clear from the clinical side

- UX1-27 meets CGR-80 (status above).
- UX1-18: colour classes only. `HOLD_MEANING` (CGR-13) and "Aufheben: Coach oder Admin, mit Begründung" on `/operations` keep their text (`holds-panel.tsx`); billing preview text unchanged. No migration, RLS, grant, function, page access check or signal rule in the diff. The axe job adds a check and removes none.

### Inputs requested of `cra` (clinical review input; I decide nothing, D-27)

- **UX1-28 (c), PO 00:15 / 01:10: is the CGR-32 notice shown correctly?** **Yes, as (c) states, with two additions for the same Playwright test.** What CGR-32 needs from this notice: the person who records the absence learns, at the moment she records it, that planned visits before today inside it are still open and need her team's decision; the lasting control is the computed flag "Zuständige Person abwesend gemeldet" on the `visit_overdue` rows of `/team` and OPS1 (0053, closed 2026-10-23), so a transient notice is acceptable (ABS1-C6). Today the notice can be lost when the dialog is closed during the save (`absence-section.tsx:84-87` sets it only while the dialog is open; `onClosed` clears it): UXR-18 is real, and UX1-28 closes it. (c) as written, shown inside the open dialog with "Zum Team", kept until she closes the dialog herself, is the right display. Additions: (1) the text is exactly `pastPlannedNotice(n)` (`features/absence/rules.ts:69-74`, fixed text, count only, no name, no reason), asserted against the function, not a literal; (2) negative: a refused save (b) never shows `absence-past-planned`, and a save with no past planned visit closes the dialog as now. Neither needs new text. Not a new finding; I re-check on the part (d) PR.
- **Part (d) string list (UX1-11 to UX1-13):** gate stands as in 21:30; I read it on the PR.

### Other checks (no finding)

- **D-38 T3 extension (00:15):** a successor provider receives her data only with her recorded consent, the partner as sender; clinically this keeps the handover set (T12 (iv), `clinical`, UNKNOWN) as the only content and adds no data path. Who consents for a client who cannot (ZGB Art. 378) stays with the Zurich adviser.
- **D-38 frozen (PO 01:10):** I agree that no clinical gap remains in T1-T14 as text; the remaining protections are code controls for a later cut-over brief (H-23: pgTAP refusing a cut-over with open items or missing prerequisites; R-11: rule-adoption pgTAP). The handover set (T12 (iv)) and the cut-over window length remain `clinical` and `owner`, UNKNOWN.
- **UX1-28 / UX1-29:** "Abbrechen" disabled while saving does not slow an absence: the save still runs and the visits are still released at once (ABS1 unchanged).
- **No new hard-coded clinical, tariff, LTCF, interRAI, PAG or MQI rule** on `recovery/main` since 21:30 or in #574. `FOLLOWUP_HEADING` is a label of an existing section; no Clinical Rule Register row.

### Gate status

| Item | Clinical gate |
|---|---|
| **UX1** part (c) (#554, merged `334682f`) | merged as cleared at 21:30 |
| **UX1** part (f) (#558, merged `caf454e`) | no clinical finding |
| **UX1-18, UX1-27** (#574, open, head `7988945`) | **clear to merge** (clinical side); CGR-80 closes on merge |
| **UX1** part (d) (UX1-11 to UX1-13, UX1-28, UX1-29; not opened) | `cra` reads the string list and the UX1-28 test with the two additions above before merge |
| **ASM1** (approved, not built) | ASM1-11 acceptable as rewritten (CGR-81 no longer blocking); CGR-84 (advisory S3) before build |
| **D-38** (`owner`, escalated, frozen) | no open clinical finding on the package text; H-23 and R-11 code controls PLANNED |
| **AIG1, PLAN3** | unchanged: CGR-75 and CGR-78 close on the builds |
| **ADM2** | unchanged: CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **po:** CGR-84 into ASM1-1 before build; the two additions to UX1-28 (c) (notice text from `pastPlannedNotice`; negative cases).
- **eng:** merge #574 when ready (CGR-80); part (d) with UX1-28 as above; still open: does "Ich kann nicht arbeiten" cover a single visit (UX2 suggestion, 21:30); does PLAN2 re-create a hand-removed care-plan visit (C-2 (b), 13:37)?
- **clinical (Clinical Owner, after G-1):** which periods assessed minutes refer to and when a total may be shown (CGR-81, CGR-84); the D-38 handover set; D-34 question 7, D-10, D-15, D-16 (with 3b), D-17, D-28, D-31; D-37 interval and triggers. All UNKNOWN until answered.
- **owner / legal / regulatory adviser:** G-1; D-38 T1-T14 (with the window length) and the Zurich adviser bundle; MepV reporting for a rule withdrawal (D-34); R-11 for C; D-36 licence terms; D-1.

---

## 2026-10-27 21:30 CET: UX1 part (c) (#554, head `822646d`) reviewed on the PR head: `cra` gate for part (c) clear, CGR-80 (advisory S3); ASM1-11 (added 21:15) read: CGR-81 (blocking for ASM1-11 acceptance, S2: the planned-minutes sum ignores frequency); D-38 T12 (i) widened and T13 form read: CGR-82, CGR-83 (advisory S2); CGR-76, CGR-77, CGR-79 closed at document level

**Scope:** `recovery/main` @ `fa43d97`. Changes since my 17:35 CET section:
- **Code merged:** none. No file under `src/`, `supabase/` or `tests/` changed on `recovery/main` since `a74d0b2`.
- **Docs merged:** my 17:35 section (#555); PO 18:10 (#557), 19:10 (#559), 20:15 (#562), 21:15 (#564); `lca` 18:05 (#556), 19:50 (#560), 20:48 (#563); `uxa` 19:51 (#561); `aia` 14:48 + 20:30 (#544).
- **Open:** #554 UX1 part (c) (head `822646d`; CI `app`, `db`, `e2e`, `ui-screenshots` success, check runs read through the GitHub API); #558 UX1 part (f), stacked on #554 (head `de27fee`, CI pending when read). #554 asks `cra` for the part (c) gate (PR body *Needs `cra` before merge*). `aia` AUT-10 and AUT-11 ask `cra` whether the D-38 forms keep CGR-79.
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read the #554 diff `recovery/main...822646d` for `src/` (`field-client.tsx`, `visit-lifecycle.tsx`, `quality-section.tsx`, `absence-section.tsx`, `features/field/rules.ts`, `features/work/rules.ts`, `lib/auth/nav.ts`, `Sidebar.tsx`) and its tests (`ux1.spec.ts`, `field.spec.ts`, `quality.spec.ts`, `ux1-field-order.test.ts`, `nav-access.test.ts`); `cancel_visit` (0024, 0054) and `lift_quality_hold` (0020:282-302) to check the consequence sentences; the #558 diff against #554 for `src/`; ASM1 with ASM1-11 and `care_plan_items` (0014:70-82); D-38 T1-T14 with the PO notes 18:10-21:15; D-12 and D-16 (`lca` 18:05 and the PO notes); D-37 (Engineering drafted 20:15); AIG1-5, PLAN3-5/-9, README *Challenge duty*, D-15, D-17, D-31 as amended 18:10; AUT-10 to AUT-12. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-80 | **#554 UX1-6**: open decisions and reports moved below the visit list | **advisory (S3); before UX1 acceptance (may ride part (d))** | The interruption follow-up queue (CGR-25: care still due after a broken-off visit), returned reports (F6R-5: "stays at the top of her day") and the countersignature queue now sit **after** all of her visits. A one-line "Zu erledigen" link row under the SIG1 banner keeps them in sight, which I accept as the control (the follow-up also stays a derived exception for coordination, `visit_interrupted`, 0045/0047). Two gaps: (a) no test pins the link row above the next visit, so a later layout change could push it below the visits unnoticed; (b) the link reads "Entscheid offen (n)" and drops the words "Nicht abgeschlossen", which say *why* a decision is open (a visit was broken off) | `field-client.tsx` (#554) link row `data-testid="todo-links"` before the `Einsätze` list; sections `followup-queue`, `returned-reports`, `countersign-queue` after it; old comment "stays at the top of her day" (F6R-5) replaced; `ux1.spec.ts:170-195` checks only signals above `next-visit`; 0047:73-75 | **eng (presentation only, no rule):** (a) e2e at 390 × 844 with a seed nurse who has an open interruption follow-up or a returned report: `todo-links` is rendered, inside the first viewport, and above `next-visit` (DOM order and `boundingBox().y`); (b) the link label is "Nicht abgeschlossen: Entscheid offen (n)" (the section's own heading), string test against the heading. Not a merge condition for #554 |
| CGR-81 | **ASM1-11** (added by po 21:15, before build; ASM1 approved, not built) | **blocking for ASM1-11 acceptance (S2); fix in the brief before ASM1 build starts** | **The sum of planned minutes is not a comparable number.** ASM1-11 shows, per category, "the sum of the care plan's `planned_minutes`" beside the assessment's minutes. A care-plan item's `planned_minutes` is per occurrence and its `frequency` is free text ("2× täglich", "1× wöchentlich"); summing the minutes across items without the frequency adds a twice-daily item and a weekly item as equals. The assessment's minutes in ASM1-1 carry **no stated period** either. The screen then sets two numbers side by side that measure different things, and the conditions I gave on AUT-2 (no colour or label from the difference) do not help: the team will still read the gap. Harm path: a team trims or expands care against a false gap (H-24); planned minutes read as above or below the assessed need where they are not (billing basis, D-18). My 17:35 AUT-2 answer assumed two recorded numbers on the same basis; I did not check the basis then, this corrects it | `briefs/ASM1.md:31` (ASM1-11 "sum of the care plan's `planned_minutes` for that category"), `:24` (ASM1-1 minutes per category, no period); `supabase/migrations/20261021000014_care_plan_billable_planning.sql:76-78` (`planned_minutes` per item, `frequency text` 1-60 characters); my 17:35 AUT-2 answer | **po (brief wording; no clinical rule):** (1) ASM1-1: the assessment's minutes are recorded with the period they refer to, as entered from the assessment (which periods occur is the provider's tool's and `clinical`/`legal` (KLV Art. 8), UNKNOWN; NAVORA offers no default and derives none). (2) ASM1-11: **no sum is computed**. Beside the assessed minutes and their period, the care plan's items of that category are listed as written (service, minutes, frequency as text). A total is shown only once frequency is structured and both sides have the same period, by a later brief with `cra` review. Tests: unit or e2e: a plan with "30 min, 2× täglich" and "60 min, 1× wöchentlich" shows both items and no total; ASM1-11 (1)-(4) unchanged otherwise |
| CGR-82 | **D-38 T12 (i)** as widened by po 21:15 (AUT-10 (b)) | **advisory (S2); in the package before the owner approves T1-T14** | **The widened timing keeps CGR-79 for the start of the window, not for its end.** The 21:15 text: the cut-over follows the client's next due reassessment or order renewal inside a window the owner sets; a due one is never postponed; "if C is not ready on the due date, the partner does it and the client waits for the next due date **or the window's end**". (1) "or the window's end" can be read as "at the window's end the client moves anyway", which would drop T12 (i)'s first sentence (no cut-over before C's *Bedarfsmeldung*, assessment and order are recorded). (2) The window's end is the sunset, when the team that does the partner's visits leaves the partner. "The partner keeps the client and her visits" then needs **partner staff who can actually visit**; T12 (ii) names one partner RN for holds and corrections, not for visits. A client whose prerequisites are missing at the sunset has no provider in practice: the care gap CGR-79 (1) named, moved to the last day | `decisions/D-38.md:52` (T12 (i) as amended 21:15, (ii)); PO 21:15 note; AUT-10 (`reports/AUTOMATION_REVIEW.md:61`); CGR-79; H-23 | **po (term wording; no clinical rule):** T12 (i) add: "(a) The window's end never moves a client whose C prerequisites are not recorded; the first sentence of (i) always applies. (b) For each such client, before the sunset date is fixed, the partner names in writing who carries out her visits after the team has left (its own staff or another admitted provider by the client's choice), or the team's employment with the partner continues for her until her cut-over." Checkable in D-38's text. Later, in a cut-over brief: pgTAP that a cut-over is refused while C's three prerequisites are missing, whatever the date |
| CGR-83 | **D-38 T13** form (AUT-11, po 21:15) | **advisory (S2); in the package before the owner approves T1-T14** | The listed adoption act (a)-(d) keeps the per-rule decision and needs no preset: I see **equal protection** to rule-by-rule adoption (answer to AUT-11). Two cases are not covered: (1) **a changed rule** in a new catalogue version: (c) covers only added rules. Is the earlier adopted version kept until she marks the new one, or does the rule stop? If it stops, a protection (an alert or a signal rule) lapses for her clients while the act waits; if the new one runs, she did not adopt it. (2) **NAVORA withdraws a rule** it found unsafe: `lca` 18:05 point 3 keeps NAVORA's catalogue decision with NAVORA. A withdrawn rule should not keep running for her clients until her next act | `decisions/D-38.md:53` (T13 (a)-(d)); D-12 `lca` 18:05 points 3, 4, 6; my 13:37 D-12 conditions (1), (2); R-11 | **po (term wording; no clinical rule):** T13 add: "(e) A changed rule: the version she adopted keeps running for her clients until she marks the new version; the act shows the old and the new text side by side. (f) A rule NAVORA withdraws as unsafe stops for every provider at once; she is told the same day with the reason, and may adopt a replacement through the act." `lca` checks (f) against settled point 3. Later, in the brief that builds rule adoption: pgTAP that an unmarked new version does not replace the adopted one, and that a withdrawn rule is not evaluated for any provider |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-76** | **closed** (document) | README *Challenge duty*, safety-control guard (po 18:10): a challenge to a control a CGR finding, a Hazard Log control or a Clinical Rule Register row cites is resolved only by a replacement of equal or better protection, re-checked by `cra`; never by removal alone (`docs/agents/README.md:77`). AUT-4 is already handled under it (`AUTOMATION_REVIEW.md:60`). The remedy was this sentence; no code was asked |
| **CGR-77** | **closed** (document) | D-31 (`decisions/D-31.md:97`): visits not blocked after `client_transferred`, `review_after_pause` at or before the first visit; D-15 (`D-15.md:88`): readiness must not block a first visit the Clinical Owner allows; D-17 (`D-17.md:70`): the list is the Clinical Owner's, interRAI one input, allergies checked. Each proposal stays `clinical`, not in force |
| **CGR-79** | **closed** (package text); the code part continues in H-23 / PS-68 | T12 (i)-(iv) in D-38 (`D-38.md:52`), with `lca` 18:05's addition to (ii) (the partner closes or reassigns open items before the team's employment ends). The remedy was "checkable in D-38's text"; the later pgTAP is a required control of H-23. The 21:15 widening is CGR-82 |
| **CGR-78** | open, advisory (S2); **(a) and (b) met at brief level** | `briefs/AIG1.md:26` (`schedule` = responsible member inside the visit's team, date and time; date, time, team, minutes, category are `record`), `:31` (unticked, no select-all, count on the button, e2e), `:32` (pgTAP refuses such a field as `schedule`); `briefs/PLAN3.md:25`, `:29`. Closes on the merged AIG1 and PLAN3 builds with those tests |
| **CGR-75** | open, advisory (S2); (1)-(5) met at brief level | unchanged; closes on the merged PLAN3 build |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-76, CGR-77, CGR-79** (document level, evidence above).

### `cra` gate on #554 (UX1 part (c); clinical review, I approve no clinical rule, D-27)

**Clear to merge from the clinical side**, with CGR-80 for UX1 acceptance. What I checked:
- **UX1-6 order:** `SignalBanner` (SIG1) is still the first element of `<main>`, unchanged in content and rule; the e2e asserts signals above `next-visit` when present (`ux1.spec.ts:179-190`). `pickNextVisit` (`features/field/rules.ts`) only picks what is shown first: planned or running, not suspended; her own before the team's; running before planned; earliest start; no start time last. An overdue planned visit sorts first by its start time, so it is not hidden. Nothing is assigned; every other visit stays in the list. Unit test `ux1-field-order.test.ts`.
- **Order question (PR body, ADR-104 deviation 2): CGR-25 "Entscheid offen" after her visits with a link at the top.** Accepted, on CGR-80 (a) and (b).
- **UX1-6a:** "Ich kann nicht arbeiten" in the header (first viewport); taking today's earliest open visit stays one tap from the collapsed header. The uncovered-visit path (H-01) is not slowed. ABS1 and COVER1 e2e changed only by one selector (`field.spec.ts:425`).
- **UX1-8 consequence sentences (UX1-12 wording gate):**
  - `CANCEL_CONSEQUENCE` "Der Einsatz wird mit dem gewählten Grund als abgesagt gespeichert und findet nicht statt." **Confirmed.** It states what `cancel_visit` does (status `cancelled`, 0024, 0054); the brief's example ("released to the team") would have told a nurse that someone else does the visit, which is false and would hide missed care. The deviation is the safer wording.
  - `HOLD_CONSEQUENCE` "Dieser Einsatz wird nicht abgerechnet, bis Coach oder Admin die Sperre mit Begründung aufheben." **Confirmed.** It matches `lift_quality_hold` (admin or coach, reason 3-500 characters, 0020:282-302) and the J5 hold; `HOLD_MEANING` (CGR-13, "nur die Abrechnung") stays next to it, unchanged, and the QG1 e2e still asserts it.
  - **Suggestion for UX2 (no finding):** a nurse who cannot do a single visit herself has no "give this one visit to the team" command; the sentence could add "Kannst nur du nicht? Nutze «Ich kann nicht arbeiten», dann sieht dein Team den Einsatz." Whether this is true for a single visit inside a short absence is for `eng` to confirm; the wording then needs one `cra` look.
- **UX1-9:** "Ereignis melden" stays one tap on the card; "Nicht angetroffen" (DOOR1) stays one tap. Only the cancel and the hold need two taps; who may run them and what they do are unchanged (no `supabase/` file in the diff).
- **UX1-10:** no signal rule, threshold, priority, recipient or text changed; e2e assertion changes are selectors only (`field.spec.ts`, `quality.spec.ts`), as listed in the PR.
- **UX1-20:** my 17:35 note is met: `menuItemsFor` always adds "Meine Einstellungen" when the role read fails (`lib/auth/nav.ts`, `Sidebar.tsx:31`), so the SIG2 push opt-in stays reachable; `/settings` reads only the caller's rows; no access widened.
- **#558 (part (f), read against #554):** the `src/` changes on `/field`, the report section and `SafetyAlertForm` replace low-contrast secondary text classes by `text-secondary`; no text, rule or order changes. Safety-alert meta lines become more readable. No clinical finding; part (d)'s string gate (UX1-12) still applies to the next PR.

### Inputs requested of `cra` (clinical review input; I decide nothing, D-27)

- **AUT-10 (`aia` → cra): does the widened T12 (i) timing keep CGR-79?** Yes for the window's start and middle: no assessment or renewal is made only for the transfer, none is postponed, and the client stays with the partner until C's prerequisites are recorded. Not yet for the window's end: CGR-82. AUT-10 (a) (C files on the same nurse's earlier assessment) is a `legal` question; clinically I see no objection if that assessment is current under the interval the Clinical Owner sets (D-37, UNKNOWN) and no significant event is younger than it (H-22).
- **AUT-11 (`aia` → cra): is one listed act equivalent to rule-by-rule adoption?** Yes, with (a)-(d) as written and CGR-83 (e), (f).
- **AUT-2 / ASM1-11:** my 17:35 conditions are in the brief as tests (`ASM1.md:31`), but the number they guard is not comparable: CGR-81.

### Other checks (no finding)

- **D-16 (`lca` 18:05, PO 19:10):** the CIRS default (nothing sent automatically, no link back, a QG1 event never replaced, hold never lifted by a CIRS report; optional "CIRS gemeldet" marker with person and date) matches my 13:37 points (a)-(c). Which events go to CIRS stays `clinical` (ask 3b).
- **D-12 (`lca` 18:05):** for the partner's clients the Leitung Pflege's adoption is final; my 13:37 condition (2) "the stricter version applies until both agree" is a product default only. Recorded on R-11. T13 carries it.
- **D-38 T2 (amended 21:15):** read-only retention readable only by the partner's staff: no clinical concern. The team's own continuity needs come through T12 (iv), not through access to the partner's records.
- **D-37 (Engineering drafted):** no change to ASM1 now; consistent with my 13:37 conditions.
- **No new hard-coded clinical, tariff, LTCF, interRAI, PAG or MQI rule** on `recovery/main` since 17:35 (no code merged). #554's `pickNextVisit` is a display order, not a care rule (no Clinical Rule Register row); its consequence sentences describe existing commands.

### Gate status

| Item | Clinical gate |
|---|---|
| **UX1** part (c) (#554, open, head `822646d`) | **clear to merge** (clinical side). CGR-80 (advisory S3) before UX1 acceptance. UX1 stays `in-progress`; part (d)'s string gate (UX1-12) and part (g) still apply |
| **UX1** part (f) (#558, open, stacked) | no clinical finding |
| **ASM1** (approved, not built) | ASM1-1 to ASM1-10 unchanged; **ASM1-11 is not acceptable as written: CGR-81 blocking for ASM1-11 acceptance**. Fix the brief before build |
| **D-38** (`owner`, escalated) | CGR-79 closed in the text; CGR-82 and CGR-83 should be in T12 and T13 before the owner is asked to approve |
| **AIG1, PLAN3** | CGR-78 met at brief level; CGR-75 and CGR-78 close on the builds |
| **ADM2** | unchanged: CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **po:** CGR-81 into ASM1-1 and ASM1-11 before ASM1 build starts; CGR-82 into T12 (i) and CGR-83 into T13 before the owner approves T1-T14; place CGR-80 (part (d) or #554).
- **eng:** CGR-80 (a), (b); confirm whether "Ich kann nicht arbeiten" covers a single visit (UX2 suggestion); still open from 13:37: does PLAN2 re-create a hand-removed care-plan visit (C-2 (b))?
- **lca:** CGR-83 (f) against D-12 settled point 3.
- **clinical (Clinical Owner, after G-1):** the period(s) assessed minutes refer to and when a total may be shown (CGR-81); the D-38 handover set; D-34 question 7, D-10, D-15, D-16 (with 3b), D-17, D-28, D-31; D-37 interval and triggers. All UNKNOWN until answered.
- **owner / legal:** G-1; D-38 T1-T14 (with the window length), the Zurich adviser bundle; R-11 for C; D-36 licence terms; D-1.

---

## 2026-10-27 17:35 CET: UX1 part 1 (#535, ADR-103) reviewed on its merge commit: no finding; AIG1-5 as amended by AUT-1 read: `responsible_user_id` confirmed as a `schedule` field under conditions (CGR-78, advisory S2); D-38 cut-over: CGR-79 (advisory S2, before the letter of intent); my 13:37 section (#532) merged in this run

**Scope:** `recovery/main` @ `4a595b7`, then `f3a1e83` after I merged my own #532 (docs only, CI `app`, `db`, `e2e` green on `590e1fb`). Changes since my 13:37 CET section:
- **Code merged:** #535 **UX1 part 1** ((a) UX1-1, UX1-2, (b) UX1-3 to UX1-5, (e) UX1-14; ADR-103), merge commit `e68ba84`. CI `app`, `db`, `e2e`, `ui-screenshots` success on the PR head `4d78827`, on `e68ba84` and on `4a595b7` (check runs read through the GitHub API).
- **Docs merged:** PO 13:45b/14:45 (#533: STR-14 frozen packages, D-38 opened), 15:20 (#546: AUT-1 answered, AIG1-5 and PLAN3-5/-7 amended, P-19, P-20), 16:25 (#552: UX1-20, UX1-21, D-38 `lca` taken in); `csa` 13:55 (#541); `lca` 13:52 (#542), 15:48 (#547, D-38); `uxa` 15:50 (#549); eng 16:22 (#550).
- **Open:** `aia` #544 (Automation Review AUT-1 to AUT-9, docs); issue #543 (AUT-1) asks me to classify `responsible_user_id`; D-38 asks `cra` for *Clinical impact*; #3 (owner, `main`). No PR review comment addressed to me.
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read the #535 diff `bb12780..e68ba84` for `src/` (`nav.ts`, `nav-access.ts`, `nav-access.tsx`, the protected `layout.tsx`, `Sidebar.tsx`, `operations-client.tsx`, `team-client.tsx`), the old and new menu tables, AIG1-5 and PLAN3-5/-7/-9 as amended, issue #543 with the PO answer, D-38 in full, `DESIGN_SYSTEM.md` *Proposals and confirmation*, and AUT-1 to AUT-9 on the #544 branch. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-78 | **AIG1-5** as amended 15:20 (AUT-1, #543) with PLAN3-5, PLAN3-9 (approved, not built) | **advisory (S2); in the briefs before AIG1 or PLAN3 build start** | **The bulk-confirm exception is sound for the responsible member of a visit, but the brief leaves two openings.** (a) AIG1-5 defines `schedule` as "which member, which team, which date". Moving a visit to another date or another team is not a pure schedule fact: it decides whether care planned for a time happens on time (time-critical visits are `clinical`, D-28) and moves the visit out of the team that holds its signals (cover across teams is COVER1, PS-17). PLAN3 never moves a visit (*Negative*), but the class definition would let a later agent's date or team field be classed `schedule`. The per-field `cra` confirmation guards this, the definition should not invite it. (b) Whether the ticked list starts ticked or unticked is open (`DESIGN_SYSTEM.md` *Proposals and confirmation*: "UNKNOWN, `cra` and the PO decide"). A list that starts ticked, or a "select all" control, is "alle übernehmen" by another name: one tap confirms every line, which is the automation bias AIG1-5 exists to stop (H-20) | `briefs/AIG1.md:25-31` (AIG1-5, amended), `:41`; `briefs/PLAN3.md:25`, `:29`, `:30` (*Negative*: no visit moved, re-timed or across teams); `DESIGN_SYSTEM.md:29`; D-28; COVER1; H-20 | **po (wording; no clinical threshold):** (a) AIG1-5: `schedule` = **the responsible member of a visit inside the visit's own team, for its own date and time**; a field that sets a visit's date, time, team, minutes or category is `record`; pgTAP (e) also refuses classing such a field `schedule`. (b) AIG1-5 / PLAN3-9: every line starts **unticked**; each line is ticked by its own tap; no "select all"; the confirm button names its count (`uxa` proposal). Each line shows the visit time, the minute category, the proposed member and, where it applies, "ändert bisherige Zuteilung" or "nicht Bezugspflege/Stellvertretung". e2e at 390 px: the proposal renders with no line ticked; no single control ticks more than one line; three ticked of five confirm exactly three |
| CGR-79 | **D-38** transfer terms T4 and T11 (`inputs-requested`; letter of intent not signed) | **advisory (S2); in the package before the owner is asked to approve T1-T11** | **The terms protect billing validity at cut-over, but not the client's care across it.** (1) T11's protective default ("C's own *Bedarfsmeldung*, needs assessment and a valid order, all before C's first visit") is right for billing (`lca` 15:48). But if a client's cut-over date (T4) is fixed before these three are in place, the client has a day on which neither provider may visit: a care gap created by the transfer. (2) At cut-over every nurse of the team leaves the partner at once. Every open item that today depends on the performer or the primary nurse being a team member of the partner then becomes the departed-author case of D-30 and the leaver case of H-21 for the whole team at once: unsigned or returned reports (D-30, LEAVE1-11), report corrections (CR-048), open interruption follow-ups (CGR-25), open `review_after_pause`, open SIG1 signals, quality holds (QG1), primary and deputy nurse (ADM2-15, CGR-72). (3) Safety-relevant facts C's nurses need from day 1 (open alerts, D-17; the care plan; the last assessment) move between organisations only on the partner's instruction and the client's consent (T3). Without them C's first visit is done blind | D-38.md:38-51 (T1-T11), :61-62 (*Clinical impact* request), :97 (`lca` note 1), :112-116 (PO 16:25); D-30 (c); CR-048; CGR-25; CGR-72 / H-21; T3; D-17 | **po (a term in the package; no clinical rule):** add **T12, continuity at cut-over**, as the minimum content: (i) a client's cut-over date is set only once C's *Bedarfsmeldung*, C's needs assessment and an order valid for C are recorded; until then the partner keeps the client and her visits (T4 unchanged: each visit has one provider); (ii) before a client's cut-over every report of a partner visit is final, no correction or returned version is open, every SIG1 signal and interruption follow-up of that client is closed by a person, and the partner names a registered nurse who keeps the partner's quality holds and corrections after the team has left; (iii) the partner's records stay with the partner, unchanged (T2); (iv) with the client's consent (T3), C receives before its first visit what the Clinical Owner lists as the handover set; the list is `clinical` (G-1, D-17), UNKNOWN. Checkable in D-38's text. In code later (when a cut-over capability is briefed): pgTAP that a cut-over is refused while any item of (ii) is open for that client |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-75** | **open**, advisory (S2); (1)-(3), (5) met at brief level (14:05 addendum); **(4) met at brief level** by AIG1-5 as amended: a ticked list is accepted only for `schedule` fields of level-L `rule` agents, each line is its own ledger confirmation, J3 runs per line, no "alle übernehmen" (`AIG1.md:27-28`; `PLAN3.md:25`). The tick default moves to CGR-78 (b). Closes on the merged PLAN3 build with its pgTAP and e2e | as cited |
| **CGR-76** | open, advisory (S3); not taken in yet | #532 merged only in this run (`f3a1e83`); README *Challenge duty* unchanged. Relevant now: AUT-4 (#544) proposes to **replace** the blanket countersignature (CR-011; H-04, H-05) with risk-based review; that is the case the guard exists for |
| **CGR-77** | open, advisory (S2); not taken in yet | D-15, D-17, D-31 *interRAI reference* unchanged since 11:45 |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: none.

### Inputs requested of `cra` (clinical review input; I decide nothing, D-27)

**#543 (AUT-1, po → cra): is `responsible_user_id` a schedule fact, not a field for the Clinical Owner's one-by-one list?** **Yes, confirmed, on three conditions**; without them the confirmation does not hold and the field stays `record`:
1. CGR-78 (a) and (b) are written into AIG1-5 and PLAN3-9 (class limited to the responsible member inside the visit's team and date; lines start unticked; no "select all").
2. Every existing J3 check (membership, absence, the registered-nurse qualification for B minutes and needs assessments, overlap, leaver) runs again per line at confirm time, and a refused line is shown with its reason and stays unassigned in the existing uncovered-visit path (PLAN3-2, PLAN3-5; CGR-75 (5)). Assignment safety then does not depend on the click pattern.
3. The Clinical Owner may put the field on the organisation's list, in general or for visits she names (for example time-critical visits, D-28, or clients with an open safety alert, D-17). Whether she does is `clinical`, UNKNOWN.
This agrees with my D-6 input of 2026-10-25 02:26 (visit assignment is a workflow, not a clinical rule).

**D-38 *Clinical impact* (po → cra): what must hold for a client on the cut-over date; which of it is a clinical rule?** See CGR-79.
- **Product or contract terms (no clinical content):** items (i)-(iii) of the CGR-79 remedy.
- **For the Clinical Owner (G-1), UNKNOWN until she answers:** the handover set from the partner to C (care plan, last assessment, open alerts, medication information); whether C's first visit may come before C's full needs assessment (D-15, CGR-77 (b)); whether C may adopt the partner's care plan as its starting plan or must write its own; and who is C's Clinical Owner and nursing management (R-11).
- **For `legal` / the Zurich adviser:** whether the partner's order can carry over (T11, UNKNOWN); which records C may receive and on which basis (T3).
- **Primary nurse:** where the same nurse continues at C, continuity of the person is kept. The partner's case still names her until the cut-over, so the ADM2-15 surfacing (CGR-72) must run for the partner's cases at her access end there.

**AUT-2 (#544, `aia` → cra): is showing the current assessment's minutes per category beside the sum of planned minutes clinical content?** **No, as a display of two recorded numbers**, on these conditions: no colour, warning, "Abweichung" label or icon derived from the difference; the assessment's date and assessor are shown with it, and a newer significant event is shown as such (D-37 condition (2), H-22); nothing (save, readiness, billing) is blocked or changed by the difference. What a difference means clinically is `clinical`, UNKNOWN. Whether planned minutes above the assessed minutes are billable is `legal` with D-18 (KLV Art. 8), UNKNOWN.

**Other #544 notes (not placed; for the PO when it places them):** AUT-4 (replace the blanket countersignature, CR-011) falls under CGR-76 and D-10 (`clinical`): a replacement needs equal or better protection against H-04 and H-05, checked by `cra` and decided by the Clinical Owner. AUT-7 (infer travel and pause): inferred status events change documented times and the stuck clock (CGR-23, D-28) and can change billed minutes; an inferred time must be labelled as inferred and confirmed by the nurse before it reaches the report or a billable fact.

### Other checks (no finding)

- **#535 menu (ADR-103, `nav.ts`):** the menu mirrors each page's server-side check and is not an access boundary; page checks, RLS and migrations are unchanged (diff `bb12780..e68ba84`: no file under `supabase/`). It fails closed (`NO_ACCESS`). No safety content was removed: "Qualitätsmanagement" had no target (open quality holds are on `/operations`, OPS1), `/teams` and `/visits` were never the nurse's route to safety signals (those are on `/field` and `/team`, SIG1-3/-4) and their routes stay. The operations and team diffs change layout only, apart from the COND2-4 display reviewed on #502.
- **UXR-10 (#548, UX1-20):** a nurse could not reach `/settings` (push opt-in for P1 signals outside the app, SIG2) from `/field`, `/team` or `/work` already before #535 (the old `Sidebar.tsx` was rendered only on `/admin`, `/analytics`, `/intake`, `/operations`, `/settings` and the demo and first-MVP pages, never on `/field`, `/team` or `/work`); not a regression. Placing it in UX1 part (c) rather than UX2 is the safer choice. One point for eng in UX1-20: the settings route should not disappear when the menu fails closed (the `member` check reads the roles; on a read error the nurse would lose her only route to push opt-in); for example, keep a direct "Meine Einstellungen" link in the header independent of `getNavAccess`.
- **D-38 T5** (clients informed only once C is admitted, no consent at intake): no clinical concern; free choice of provider stays the client's.
- **No new hard-coded clinical, tariff, LTCF, interRAI, PAG or MQI rule** in code since 13:37. The menu table is an access mirror, not a care rule (no Clinical Rule Register row). AIG1-5's field class is a planned product rule; it gets a row when built.

### Gate status

| Item | Clinical gate |
|---|---|
| **UX1** part 1 (#535, merged `e68ba84`) | **no finding.** UX1 stays `in-progress`; the `cra` gates for part (c) (`/field` order, UX1-6, UX1-10, UX1-20) and part (d) (string list, UX1-12) apply to the second PR before merge |
| **AIG1, PLAN3** (approved, not built) | `responsible_user_id` may be classed `schedule` once CGR-78 is in the briefs; CGR-75 closes on the merged PLAN3 build |
| **D-38** (`inputs-requested`) | *Clinical impact* given above; CGR-79 should be in the package before the owner is asked |
| **ADM2** | unchanged: CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **po:** CGR-78 into AIG1-5 and PLAN3-9; record the #543 answer; CGR-79 (T12) into D-38; CGR-76 (README) and CGR-77 (D-15, D-17, D-31) now that #532 is merged; place C-1 to C-4 (UXR-4, UXR-5 (a), UXR-7) in the UX briefs.
- **eng:** the settings route independent of the menu read (UX1-20); still open from 13:37: does PLAN2 re-create a hand-removed care-plan visit (C-2 (b))?
- **clinical (Clinical Owner, after G-1):** the D-38 handover set and C's first visit before its own assessment; whether `responsible_user_id` goes on the one-by-one list for any visits; D-34 question 7, D-10, D-15, D-16, D-17, D-28, D-31; D-37 interval and triggers. All UNKNOWN until answered.
- **owner / legal:** G-1; D-38 T11 order carry-over and T3 basis (Zurich adviser); R-11 for C; D-36 licence terms; D-1.

---

## 2026-10-27 13:37 CET: COND2-4 with COND2-4a and -4b (#502, migration 0088) reviewed on the merge commit; CGR-71, CGR-73 and CGR-74 closed; clinical gate clear for COND2; inputs given on D-37, D-12 (co-signature, CIRS ↔ QG1), the six *interRAI reference* sections and UX requests C-1 to C-4; CGR-75 (PLAN3 proposal, advisory S2), CGR-76 (#531, advisory S3), CGR-77 (interRAI proposals as worded, advisory S2)

**Scope:** `recovery/main` @ `da913d5`. Changes since my 09:30 CET section (#505, merged `6e1143f`):
- **Code merged:** #502 **COND2-4 / COND2-4a / COND2-4b** (merge commit `799700d`; PR head `09f9a26`). CI on `09f9a26`: `app`, `db`, `e2e` success. CI on `799700d`: `app`, `db` success, `e2e` cancelled (superseded); on `da913d5` all three success (check runs read through the GitHub API).
- **Docs merged:** PO 10:14, 10:40, 11:10, 11:45, 12:05, 13:00, 13:30 (UX1, UX2 briefs; *interRAI reference* sections in D-15, D-16, D-17, D-28, D-30, D-31; D-36; D-37; G-1 appointment requirements; Clinical Owner briefing pack; pilot foundation recommendation; Strategic Alignment Review with the staged AI path and proposed briefs AIG1, ASM1, PLAN3, BILL2; roles `aia`, `csa`); `uxa` 10:42, 11:19, 11:49 (requests C-1 to C-4 to me); `lca` 11:41, 12:42; eng 12:25 (COND2 delivered).
- **Decisions answered by the owner (2026-10-27, recorded by the PO):** D-12 `decided` (B with partner as pilot vehicle, C prepared, A rejected); D-34 `decided` (A plus C; clinical module long-term); D-37 approved as a decision track, still `inputs-requested`. **No `clinical` decision was answered by a person.** D-34 question 7 (urgency criteria) stays with `clinical`: the owner decision does not answer it (D-34.md:321-322).
- **Open PRs:** #531 (PO 13:45, challenge duty for `aia` and `csa`, docs only; **merged `44f57c1` while this review was being published**, without the CGR-76 guard; my comment is on #531); #3 (owner, `main`). No review comment addressed to me.

I read the 0088 diff `10745eb..09f9a26` and the final 0088 (`:5-26`, `:80-118`, `:145-178`), pgTAP 088 at the merge commit (35 assertions, `:80-90`, `:180-191`), `private.now()` (0067:83-102), `remove_planned_visit` (0014:324-360), `team-client.tsx:190-205` and `:960-1020`, the six *interRAI reference* sections, D-12, D-34, D-36, D-37, the G-1 appointment and briefing pack, the Strategic Alignment Review §3-§4, UX1, UX2, `UX_REVIEW.md` C-1 to C-4, and the #531 diff. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-75 | **PLAN3** (proposed brief, Strategic Alignment Review §4; PO plans to write and approve it next cycle) | **advisory (S2); before PLAN3 is approved** | **The proposal describes qualification as a weight, not as a constraint.** PLAN3 "proposes visit order and assignment inside the team, weighting continuity (same nurse), time windows, qualifications and travel". A weighted optimiser can trade a qualification against travel or continuity and propose an assignment that today's commands refuse or that today's rules never had to refuse: a B-minute or needs-assessment visit to a member without the registered-nurse qualification (0018, CR-025), a leaver (0078), an absent member (ABS1), a visit moved out of a window the care plan or the order fixes. If the team confirms in bulk, the proposal becomes the plan (H-20 automation bias, here without AI). PLAN3 is level L and deterministic; that removes model error, not this design error | Strategic Alignment Review §4 row PLAN3, §3 stage 0; 0018 (qualification), 0029:74-75 (cover: RN only for B and assessment), 0078 (`set_primary_nurse`/PLAN2 refuse a leaver), ABS1 0046; H-20 | **po (in the brief; no clinical threshold):** (1) every rule that an existing command enforces for an assignment (qualification for the minute category, delegation, leaver, absence, cover safety) is a **hard filter** before any weight; continuity, travel and order are weighed only among valid options; (2) confirming a proposal runs the same server-side commands as a hand assignment, so a stale or wrong proposal is refused; (3) the optimiser never moves a visit to another day and never changes a time window or the minutes; (4) no accept-all for a whole day without each changed visit shown (AIG1, `uxa`); (5) a proposal that cannot staff a visit says so ("nicht besetzbar") and leaves it to the existing uncovered-visit path, never drops it. pgTAP: confirming a proposal that assigns a B visit to a non-RN, a leaver or an absent member is refused; e2e: an unstaffable visit is shown, not hidden. Which visits are time-critical stays `clinical` (D-28) |
| CGR-76 | #531 (open; README *Challenge duty* for `aia` and `csa`) | **advisory (S3); before merge or in the next PO cycle** | **The challenge duty has no guard for a control that exists because of a safety finding.** A `high` challenge (no patient-care benefit shown) must be answered by the PO "before accepting or escalating". Many controls look like administration but answer a hazard (e.g. reason fields on removal, countersignature, the LEAVE1-2 refusals, the billing hold). The rule as written lets the PO accept a challenge and drop such a control without `cra` seeing it, and the benefit is often not written next to the control. This conflicts with the standing instruction to replace controls with better ones, never to remove them | #531 diff, `docs/agents/README.md` (*Challenge duty*); `ROLE_PROPOSALS_AIA_CSA.md` (`aia` gate: "Clinical content stays with `cra`") | **po:** add one sentence: "A challenge to a step, field or approval that a CGR finding, a Hazard Log control or a Clinical Rule Register row cites is resolved only by a replacement control of equal or better protection, re-checked by `cra` (and by the Clinical Owner for a clinical rule); never by removal alone." The challenger names the cited CGR/H/CR ID, or states that none exists. Checkable in the next `aia`/`csa` findings |
| CGR-77 | *interRAI reference* sections, proposals for the Clinical Owner (D-15, D-17, D-31; "not in force") | **advisory (S2); wording before the Clinical Owner reads them** | **Three proposals are unsafe or incomplete as worded** (the "remains clinical governance" columns are right; see *Inputs*). (a) **D-31:** "after `client_transferred` the case resumes only after a recorded reassessment or care-plan review" reads as a gate on resuming visits. The days after a hospital discharge are the period when a missed first visit harms most (H-19, PS-60); a gate that waits for a review can delay the visit itself. Today a resume opens the `review_after_pause` task and does not block visits (0088:105-118; CR-024 "no reassessment required", C-8). (b) **D-15:** the readiness item "needs assessment on file and not older than the approved interval" would, as a readiness gate, block an urgent first visit before the assessment is done; whether a first visit may precede the full assessment is itself listed as open in the same row. (c) **D-17:** "start the category list from the interRAI-covered domains plus infection precautions" lets the instrument's coverage define the list; drug allergies are marked UNKNOWN there, and alerts that are not assessment content (e.g. advance directive or resuscitation status on file, devices the nurse must know about) are not prompted. I do not propose categories; the Clinical Owner sets them | D-31.md, D-15.md, D-17.md *interRAI reference* (2026-10-27 11:45); 0088:105-118 (`review_after_pause` opened on resume); CLINICAL_RULE_REGISTER CR-024, CR-033; H-19 | **po (wording only; no rule):** (a) reword as "after `client_transferred`, a registered nurse completes the review after the pause (`review_after_pause`) at or before the first visit; visits are not blocked; the time limit is `clinical`"; (b) add "the readiness item must not block a first visit that the Clinical Owner allows before the full assessment (same row, open question)"; (c) reword as "the Clinical Owner sets the list from the provider's current alert practice and the published incident and medication-safety guidance she relies on; the interRAI domains are one input; whether allergies are covered (UNKNOWN) is checked before the list is fixed". Checkable in the package text |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-74** | **closed** | 0088:148-151 (step 1b): `alter table public.referral_links alter column created_at set default private.now()`; production unchanged (`private.now()` is `now()` unless the test-clock row exists, 0067:90-95). pgTAP 088:183-191: the three resume links carry three distinct `created_at` values, and the column default contains `private.now()`; plan 35. ADR-102 amendment 10:20 corrects the 07:40 sentence. CI `db` success on `09f9a26` and on `799700d`, `da913d5` |
| **CGR-73** | **closed** | 0088:157-169: `return_referrer_requested_start` is read from the newest `resume` link's `partner_requests` row, only while `review_after_pause` is open; now deterministic (CGR-74). pgTAP 088 (second return without a date reads no date; pre-IPA1-7 return reads no date; the case keeps its stored date, 088:180-182); CI as above |
| **CGR-71** | **closed** | 0088:80-95: on resume the case takes the new request's urgency and source (`unknown` for an old request), date kept when none is given, each change in `change_log` (088: "every earlier level stays in the trail"); 0088:157-178: the team reads the source and this return's date in the return task. Merged `799700d` |
| **CGR-72** | open, blocking for ADM2 acceptance (S2); ADM2-15 PLANNED, not built | no change |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change; Clinical Owner review after G-1 |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-71, CGR-73, CGR-74**.

### Inputs requested of `cra` (clinical review input; I decide nothing, D-27)

**D-37 (interRAI HC as foundation), *Clinical impact*, Clinical Architect 2026-10-27:**
- **Is B safe as described?** Yes, under five conditions. (1) Imported problem areas are display and provenance only: no NAVORA order, escalation, readiness item or billing rule reads them (input class *clinical content*, D-34 statement v2) until a Clinical Owner rule and, for anything computed, the module (C). (2) Each imported fact shows its assessment date and assessor wherever it is shown, and the screen says when a newer event (hospital transfer, serious quality event, `review_after_pause`) is younger than the assessment; otherwise an old assessment is read as current (new hazard **H-22**). (3) An import is all-or-nothing per assessment, with an explicit "nicht übernommen" state; a silently dropped problem area is worse than no import. (4) Imported facts are never edited in NAVORA; a correction is a new dated record (as the D-30 interRAI row says). (5) NAVORA does not map problem areas to KLV categories or minutes (D-15 row: UNKNOWN).
- **Which uses first:** (i) ASM1 as proposed (record, last assessment date, "Neuere Bedarfsabklärung"; no due date) — safe now on synthetic data; (ii) a **prompt**, never a gate, "Prüfen, ob eine neue Bedarfsabklärung nötig ist" on the events that already exist (resume after a pause, serious quality event) — the wording and whether it is required are `clinical`; (iii) care-plan structure by problem area, after the Clinical Owner decides the fields (D-15 J3); (iv) reassessment due dates only after the Clinical Owner sets the interval. Continuity needs nothing from interRAI (primary nurse exists, J6).
- **What the Clinical Owner must set:** the reassessment interval and the triggers for an early one; which reported areas a care plan must address and how an unaddressed area is shown; what an overdue assessment does (display only, or a readiness or billing consequence: also `legal`, KLV Art. 8); how a provider on another instrument is handled (D-13 B fallback). All UNKNOWN until she answers.

**D-12 (po → cra): is the partner's nursing management co-signing the Clinical Owner's rules at go-live sufficient; what must CIRS and QG1 hand to each other?**
- **Co-signature once at go-live is not sufficient on its own.** It covers the rule set of that day. Needed in addition (governance, no clinical content): (1) every later change to a clinical rule takes effect for the partner's clients only after the same co-signature, recorded per rule with name and date (the register's *Status* stays per rule, with the organisation); (2) the partner's Leitung Pflege can suspend a rule for her organisation at once, and the stricter of the two versions applies until both agree; (3) a named route when the Clinical Owner and the Leitung Pflege disagree (owner and `legal`: who carries it under the licence, R-11). Whether the licence holder's nursing management may delegate rule-setting to an external Clinical Owner at all: **UNKNOWN, `legal`** ([Z1] A.3.4.2 non-delegable duties, D-12 `lca` 12:42).
- **CIRS ↔ QG1:** QG1 holds authored, case-linked quality events with a billing hold; a CIRS is the licence holder's learning system and is usually reported without blame and often without names. Handing QG1 records into CIRS as they are would carry author and client references into a system built on confidentiality; handing nothing loses learning. What I can say without inventing a rule: (a) a CIRS report never replaces a QG1 event or lifts a hold; (b) which QG1 events must also go to CIRS, by whom, and in which de-identified form is `clinical` (D-16) with `lca` (data minimisation); (c) NAVORA should not send anything to the partner's CIRS automatically before (b) is decided. UNKNOWN until then.

**Six *interRAI reference* sections (po → cra, "confirm the column; say whether a proposal is unsafe"):** the "remains a clinical governance decision" column is right in D-15, D-16, D-17, D-28, D-30 and D-31; nothing in it is handed to interRAI or to NAVORA. Proposals: D-16 (review signal names the reassessment check; recognised incident taxonomy) and D-28 (nurse-set "zeitkritisch" flag, never derived) are safe as worded for the Clinical Owner to consider; D-15, D-17 and D-31 need the rewording in CGR-77. Every interRAI line remains UNKNOWN until an entitled person verifies it (D-36 option A).

**UX requests C-1 to C-4 (`uxa` 11:19; presentation only):**
- **C-1 (UXR-4): confirm with change.** A P1 situation may appear once in full (the signal card) with a pointer line in the list, **only if** the list entry adds nothing the card lacks; an entry that carries its own action (e.g. the interruption follow-up form for `visit_interrupted`, `team-client.tsx:196-199`), flags or handling state keeps them visible in the list. The clearance text may go behind "Wann erledigt sich das?", but its last sentence "Schwellen und Regeln provisorisch (klinische Entscheidungen offen)" stays visible (`team-client.tsx:204`). Test: e2e at 390 px, the follow-up form is reachable in one tap; the "provisorisch" sentence is visible without expanding.
- **C-2 (UXR-5): (a) confirm.** The intake urgency is a criteria-free label (CR-125, CR-129; criteria `clinical`, D-34 q7), not a SIG1 signal; keeping red for it dilutes the P1 colour. Amber with the word kept. **(b)** I do not write the text; the facts it must state, from the code: removing a planned visit deletes it (`remove_planned_visit`, 0014:352-355), the reason is logged in `visit_plan_changes`; no missed-visit or uncovered alert can follow for a deleted visit; it is refused once anything was recorded on the visit (0014:343-348). Whether PLAN2 re-creates a removed care-plan visit: UNKNOWN to me (eng to state). The sentence should say that the care planned for that time will not take place unless someone plans it again.
- **C-3 (UXR-7): confirm.** A team in which a member does not receive P1 signals outside the app is a state the team must see without expanding; amber, not the P1 colour. Wording with change: name what is missing, e.g. "Nicht alle erhalten Sicherheitssignale ausserhalb der App" (the PO and `uxa` choose the words). No per-member detail beyond SIG2-2 (active / not active).
- **C-4: confirm with change.** The four rules may become acceptance criteria, and "Sicherheitssignal:" is a suitable prefix. Change: "exactly one action per P1 card" becomes "one primary action first; no action a card has today is removed or moved off the card" (a card such as `visit_interrupted` needs its decision form).

### Other checks (no finding)

- **0088 step 1b** sets a column default only; no clinical rule, threshold or read scope changes. `private.now()` is granted to `authenticated` (0067:101) and the insert runs in a security-definer command. CR-132 added for the 0088 resume rule (provenance and display, not clinical).
- **D-12, D-34 owner decisions:** owner category, decided by the owner; neither decides a clinical rule. D-34 question 7 and the module's clinical content stay with `clinical`. R-11 (professional accountability) now depends on the partner's nursing management: note added.
- **G-1 appointment and briefing pack:** the requirement that the partner's nursing management "must be able to accept every rule" matches the co-signature input above. No clinical rule.
- **UX1, UX2:** keep every SIG1 signal above everything, add no rule, threshold or recipient (UX1-6, UX1-10, UX2-7); "Ereignis melden" stays one tap (UX1-9). No finding.
- **Staged AI path:** "never at any stage: AI triage of P1 safety signals, automatic coding or care-plan change, unconfirmed record entries" agrees with H-20. Stage 2 entry "correction rates below threshold": the threshold is UNKNOWN (`aia` proposes, Clinical Owner approves for clinical fields).
- **No new hard-coded clinical rule** in code since 09:30.

### Gate status

| Item | Clinical gate |
|---|---|
| **COND2** (all items merged; #502 `799700d`) | **clinical gate clear.** CGR-71, CGR-73, CGR-74 closed |
| **ADM2** (approved, not built) | unchanged: build may start; CGR-72 blocking for acceptance until ADM2-15 is built with its pgTAP |
| **PLAN3** (approved 13:35) | CGR-75 (1)-(3), (5) met in the brief; (4) open (PLAN3-5 "whole proposal" vs AIG1-5); gate on the merged build |
| **AIG1, ASM1** (approved 13:35) | no finding on the proposals; ASM1 must keep "due date only after the Clinical Owner's interval" and D-37 condition (2) |
| **UX1, UX2** (approved) | no blocking finding; C-1 to C-4 answered above |
| #531 (merged `44f57c1`, docs) | CGR-76 advisory; for the next PO cycle |
| All other items | unchanged |

### Addendum 14:05 CET: PLAN3, ASM1 and AIG1 approved while this review was being published (PO 13:35, #534, merged `4d6cd57`)

I read the approved briefs before merging this section.
- **PLAN3 meets CGR-75 (1), (2), (3) and (5) at brief level.**
  - PLAN3-2 makes membership, absence, the J3 qualification (0014:244) and overlap hard limits, with pgTAP for each.
  - PLAN3-5 confirms through the J3 command path, and every check applies again at confirm time.
  - *Negative*: no visit is moved, added, cancelled or re-timed.
  - PLAN3-1: "kein Vorschlag" with its reason.
- **Still open: CGR-75 (4).** PLAN3-5 says "confirms the whole proposal", but AIG1-5 requires every field of every agent to be confirmed one by one until the Clinical Owner sets the list.
  - Remedy for po (wording) and eng: in PLAN3-5 and PLAN3-9, confirm per line or by a ticked list, with every changed line visible. There is no "confirm all" while AIG1-5's default holds.
  - Test: an e2e check that no single control sets more than the ticked lines.
- **CGR-75 stays open** (advisory, S2), narrowed to (4). It closes on the merged PLAN3 build.
- **ASM1:** no reassessment due date, interval or import (ASM1 *Negative*, :31, :35); "Neuere Bedarfsabklärung" is shown with no block. This is consistent with D-37 conditions (1) and (4) and with H-22. The clinical gate applies on the merged build.
- **AIG1:** ships no threshold value (:34). AIG1-5 is the most protective default. No finding.

### Decisions requested

- **po:** CGR-75 in the PLAN3 brief; CGR-76 in #531 or the next cycle; CGR-77 wording in D-15, D-17, D-31; take in the D-37 and D-12 inputs above; C-1 to C-4 into UX briefs.
- **eng:** state whether PLAN2 re-creates a hand-removed care-plan visit (C-2 b).
- **clinical (Clinical Owner, after G-1):** D-34 question 7, D-16 (incl. CIRS ↔ QG1), D-15, D-17, D-31, D-10/D-25; D-37 interval and triggers; all UNKNOWN until answered.
- **owner / legal:** G-1 (named Clinical Owner); with `lca`, whether the partner's Leitung Pflege may adopt rules set by an external Clinical Owner and who decides a disagreement (R-11); D-36 licence terms; D-1.

---

## 2026-10-27 09:30 CET: COND2-4a (#502, head `10745eb`) read: the display fix meets CGR-73, but the pgTAP evidence is non-deterministic: CGR-74 (advisory, S3; fix before merge); ADM2-15 (brief) read: CGR-72 remedy decided as written, stays open until built (PLANNED)

**Scope:** `recovery/main` @ `6abf941`. Changes since my 05:30 CET section (#503, merged `deeb017`):
- **Code merged:** none.
- **Open PRs:** #502 **COND2-4** with **COND2-4a** (`feat/cond2-4-resume-urgency`, head `10745eb`; new since my read: `caaa475` COND2-4a, `10745eb` test clock change, merge of `recovery/main`); CI `app`, `db`, `e2e` green on `10745eb` (check runs read through the GitHub API). #3 (owner, `main`). No review comment addressed to me.
- **Docs merged:** PO 06:10 (#504: **ADM2-15** for CGR-72, **COND2-4a** for CGR-73, P-17); `lca` 03:50, 06:05, 07:41 (#500, D-20 part (b): with ADM2-14 and ADM2-15 compliant on the sources read).
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read the 0088 diff `f1d74d7..10745eb`, pgTAP 088 at `10745eb` in full, the ADR-102 amendment, `referral_links` (0034:64-87) and `private.now()` (0067:83-99), and the ADM2-15 and COND2-4a brief text. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-74 | COND2-4a (#502, open; 0088, pgTAP 088) | **advisory (S3); fix before merge** | **The pgTAP proof for CGR-73 does not prove it reliably: which return the team reads is decided by a random UUID in the test.** `team_cases` reads the date from the case's newest `resume` link `order by l.created_at desc, l.id desc` (0088:160-163). `referral_links.created_at` defaults to `now()` (0034:74), not to `private.now()`; in PostgreSQL `now()` is the transaction start, and the whole pgTAP file is one transaction. So the three resume links of the test all carry the same `created_at`, and the tie goes to `id`, which is `gen_random_uuid()` (0034:65). `pg_temp.age_link` moves only `navora.test_now` (088:85-87), which `created_at` never reads. The ADR-102 amendment and the test comment say "created_at defaults to private.now()"; that is not what 0034 says. Consequence: the assertion "second return without a date reads no date" (088:158-159) holds only when the random id of R2's link sorts above R1's (about half the runs); the third return's (088:177-178) only when R3's id is the highest of three (about a third). CI green on `10745eb` was one run. Once merged, the `db` job can turn red on unrelated PRs, and a re-run that turns green would hide a real regression of the provenance rule. **Production behaviour is correct as far as I can see:** each resume is its own transaction with a pause between, so `created_at` differs and the newest link is this return. No clinical rule; display only | 0034:65 (`id … default gen_random_uuid()`), 0034:74 (`created_at … default now()`); 0067:83-99 (`private.now()` is a function, not the column default); 0088:160-163; pgTAP 088:85-87, :144, :158-159, :166, :177-178; ADR-102 amendment 2026-10-27 07:40 ("created_at defaults to private.now()") | **eng (no threshold):** make the order deterministic before merge, Engineering's choice, stated in the ADR: (a) in 0088, `alter table public.referral_links alter column created_at set default private.now()` (DST1 pattern; production unchanged since `private.now()` is `now()` there), so `age_link` takes effect; or (b) order by a value that is certain to grow with each resume in one transaction (for example the `change_log` row of the resume, by its sequence id), or (c) in the test, have the earlier links carry an earlier `created_at` through the command path. pgTAP: the existing COND2-4a assertions, plus one that fails if the tie-break decides (e.g. assert the three resume links have distinct `created_at`). Correct the ADR sentence. CGR-73 closes on the merge commit with this |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-73** | **open**, advisory (S3); **remedy implemented in code on the #502 head `10745eb`**, test evidence not yet reliable (CGR-74) | 0088:157-163: `return_referrer_requested_start` is read from the newest `resume` link's `partner_requests` row, only while `review_after_pause` is open; a request without a date reads null, shown as "nicht angegeben" (app unchanged). The case keeps its stored date (0088:82 unchanged; pgTAP 088:180-181). The first return's date stays in `change_log` (088:160-163). The PO chose "show nothing when nothing was asked" over a labelled earlier date (COND2 PO note 06:10); clinically that is the safer of the two options I offered: a stale date, even labelled, could be used to plan the first visit after a hospital stay. Closes with CGR-74 on the merge commit |
| **CGR-72** | **open**, blocking for ADM2 acceptance (S2); **remedy decided (ADM2-15), PLANNED, not built** | `briefs/ADM2.md` ADM2-15 matches my remedy (1) and (2): (a) from day 14 the team's RNs and administrators see her open cases as primary or deputy nurse and her responsible or covered visits up to and including the end date (reference, role, date only, as LEAVE1-12); (b) at the access end each open case still naming her is shown to its team ("Bezugspflege neu bestimmen" / "Stellvertretung neu bestimmen", resolved by `set_primary_nurse`, 0078 guard unchanged) and as one OPS1 exception to Operations; (c) access still ends on time; a visit in progress keeps the stuck and close path. Its pgTAP list covers day 15 / day 14 / day after, both roles, the reader scope, the resolution by `set_primary_nurse` and by `restore_member_access`, and the unchanged manual refusal `has_cases`. **No automatic promotion of the deputy:** I agree; who holds the care-process responsibility after a primary nurse leaves is UNKNOWN (D-12, D-25, `owner`/`clinical`). ADM2-15 is in G-23. Closes when ADM2 is built and its pgTAP passes in CI |
| **CGR-71** | **open**, advisory (S3); remedy met on the #502 head (unchanged by COND2-4a apart from the date column); closes when #502 is merged | 0088:74-94 unchanged between `f1d74d7` and `10745eb` (my diff) |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change; the named Clinical Owner's required review (owner, after G-1) |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: none.

### Other checks (no finding)

- **ADM2-15 privacy reading:** case references and roles of a leaver's cases go only to readers who already have them (the team's RNs) and to the organisation's administrators, as LEAVE1-12 does; `lca` 07:41 finds this compliant. No health content.
- **P-17** (cases still naming a leaver at the end, days to a successor) is a sound measure for H-21; target 0 at the end is a product target, not a clinical threshold.
- **No new hard-coded rule** in the #502 diff or in ADM2-15 / COND2-4a (no threshold, priority, clock, recipient or tariff value). CR-129 note only.

### Gate status

| Item | Clinical gate |
|---|---|
| COND2-4 with COND2-4a (#502, open, CI green on `10745eb`) | **no blocking finding.** CGR-74 (advisory) should be fixed before merge so the test is deterministic; if merged as is, CGR-73 stays open and CGR-74 becomes a condition. I re-read the merge commit |
| **COND2 as a whole** | **clinical gate clear** once #502 is merged with CGR-74 fixed (or CGR-74 recorded as a condition) |
| **ADM2** (approved, amended with ADM2-15, not built) | **brief: CGR-72 remedy accepted as written; the build may start.** CGR-72 stays blocking for ADM2 *acceptance* until the build shows ADM2-15 with its pgTAP |
| All other items | unchanged |

### Decisions requested

- **eng:** CGR-74 in #502 before merge (deterministic order; correct the ADR sentence).
- **po:** COND2 acceptance once #502 is merged with CGR-74 handled; ADM2 build with ADM2-14 and ADM2-15.
- **clinical (Clinical Owner, after G-1):** D-34 question 7, D-16, D-10/D-25; who holds the care-process responsibility after a primary nurse leaves (with D-12, `owner`); all UNKNOWN until answered.
- **owner:** G-1 (named Clinical Owner), D-1; unchanged.

---

## 2026-10-27 05:30 CET: COND2-1 to COND2-3 (#495, migration 0087) reviewed on the merge commit; CGR-70 closed; COND2-4 (#502, open, 0088) read: CGR-71 remedy met on the PR head, CGR-73 (advisory, S3); ADM2 brief (approved, not built) read: CGR-72 (blocking for ADM2 acceptance, S2): the automatic access end skips the LEAVE1-2 guard for a primary or deputy nurse

**Scope:** `recovery/main` @ `f62e500`. Changes since my 01:27 CET section (#492, merged `e442044`):
- **Code merged:** #495 **COND2-1 to COND2-3** (0087, ADR-101, pgTAP 087 (36), pgTAP 035, 074, 083 adjusted, unit `cond2-rules`, `cond2-operations-payload`, e2e `quality.spec`) as `0aa7f61`. **CI** (check runs read through the GitHub API): `app`, `db`, `e2e` green on `0aa7f61` and on `f62e500`.
- **Open PRs:** #502 **COND2-4** (`feat/cond2-4-resume-urgency`, head `f1d74d7`, 0088, ADR-102, pgTAP 088 (31)); CI `app`, `db`, `e2e` green on `f1d74d7`. #500 (`lca` D-20 part (b), docs). #3 (owner, `main`). No review comment addressed to me.
- **Docs merged:** PO 02:10 (IPA1 accepted; CGR-71 as IPA1-C2 = COND2-4), PO 03:10 (**ADM2 approved**, *Next up* 2), PO 04:10 (ADM2-14 added after `lca` 03:50; D-4 item (5)); `lca` 01:45 (D-34 re-check); `eng` 03:15.
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0087 and pgTAP 087 in full, the patched `set_quality_event_status` against 0020:214-250, `can_handle_quality_event` (0020:204-211), the `quality_serious_open` derivation (0039:58-64), the app diffs (`quality-section.tsx`, `quality/rules.ts`, `operations/queries.ts`, `operations/types.ts`, `admin/*`), the e2e `quality.spec` addition; on #502: 0088 in full (diffed against 0034's body), the pgTAP 088 assertions, ADR-102 and the `/team` diff; the ADM2 brief against `end_member_access` (0074:290-381). **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-72 | ADM2-11 to ADM2-13 (brief, approved, not built) with LEAVE1-2 (0074) | **blocking for ADM2 acceptance (S2)** | **The automatic access end at a recorded contract end skips the one guard that makes a team name a new primary nurse before a leaver goes.** `end_member_access` refuses while she is primary or deputy nurse of an open case (`has_cases`), has a visit on the way, started or paused (`has_visit_in_progress`), or is responsible for or covers a planned visit from today on. LEAVE1-2 made these refusals on purpose: "someone else can clear those". ADM2-13 ends access "exactly as `end_member_access` ends it" but without a command, so no refusal can happen. ADM2-11 releases only her visits **after** the end date. ADM2-12 shows the team only her open **reports**. Nothing in ADM2 lists or hands over her primary or deputy role, her visits on the last day, or her covers. The day after, an open case can name a primary nurse who can no longer read it. Bounded today: PLAN2 skips her, `set_primary_nurse` refuses her (0078), and visits left without a responsible member raise J3, OPS1 and SIG1 alerts (accepted as protective for a reopened case, LEAVE1 deviation 15). The gap is the responsibility, not the visit: nobody is asked to name the new primary nurse, who holds the care plan and the review after a pause (H-08). This weakens an existing safety control. PLANNED; no clinical rule involved; synthetic data only | 0074:345-356 (the three refusals), 0074:380-381 (comment); `briefs/ADM2.md` ADM2-11 ("visits after the end date"), ADM2-12 ("open reports"), ADM2-13 ("exactly as `end_member_access` ends it … without a command"); `grep -i "primary\|deputy" briefs/ADM2.md` finds only ADM2-7 (no role change by an ADM2 command); `briefs/LEAVE1.md:26`, :151 | **po (product authority; no threshold):** amend ADM2 before the build: (1) the ADM2-12 list from day 14 also shows the open cases where she is primary or deputy nurse, and her responsible or covered visits up to and including the end date (case reference, role and visit date only, as LEAVE1-12); (2) at the ADM2-13 end, every open case that still names her as primary or deputy nurse is shown to its team and to Operations through an existing path (for example a case task "Bezugspflege neu bestimmen" or an OPS1 exception, PO's choice; no new threshold or priority). Her access still ends on time (privacy is not traded for this). A visit in progress at the boundary keeps the existing stuck and close path. pgTAP: end date recorded; she is primary nurse of case X and responsible for a visit on the end date; day 15 not listed, day 14 listed; the day after, access ended and case X surfaced to its team (and Operations); the manual `end_member_access` still refuses with `has_cases` (LEAVE1 suite unchanged). Or record why not |
| CGR-73 | COND2-4 (#502, open; 0088) | **advisory (S3)** | **A returning referral without a requested start shows an earlier referral's date as this referrer's request.** The brief keeps the case's date when the new request has none ("never blanked"; 0088:82 `coalesce(req.date, c.date)`). `team_cases` then returns the case's stored date as `return_referrer_requested_start`, and `/team` shows it inside the new return's review task as "Gewünschter Beginn (laut Zuweiser)". pgTAP 088:140-150 asserts this: after a second return with no date, the team reads `mittel:intake_assessed:4`, where 4 is the first return's date. The same happens for a pre-IPA1-7 request (088:164, `niedrig:unknown:4`). The date can lie weeks back and belongs to another referrer's statement; this is the provenance point of CGR-69 and P-14. Bounded: display only, nothing orders or plans by it (pgTAP 086 allowlist), and the visits resume as planned. IMPLEMENTED in the PR as described; no clinical rule | 0088:82, 0088:150-153; `src/features/returning/rules.ts` `returnReferralFacts`; `team-client.tsx` "Gewünschter Beginn (laut Zuweiser)"; pgTAP 088:140-150, :160-164 | **eng, po (no threshold):** inside the return task show the referrer's date only when **this** return's request carried one (for example read it from the resume's `referral_links` row and its `partner_requests` row in `team_cases`), else "nicht angegeben"; the case may keep its stored date. Or label a kept date with its origin ("aus früherer Zuweisung vom …"). pgTAP: second return without a date → the task reads no referrer date (or the labelled earlier one); the first return unchanged. Fits #502 before merge or a COND2 follow-up |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-70** | **closed**, IMPLEMENTED (COND2-2); CI green on `0aa7f61` | 0087:108-116: `set_quality_event_status(…, 'in_review')` is accepted from `in_review` only when `owner_id is not null and private.quality_claim_lapsed(q.id, q.owner_id)`; the caller still needs `can_handle_quality_event` (0020:204-211; no new role). The 0020 update sets the new owner (audited by the 0020 trigger); one `quality_event_log` row `in_review > in_review` with actor, key and `access_seq` (0085 trigger). pgTAP 087: (a) take-over by a team member, owner changes, `claim_ended` false (:133-135); (b) live claim `rejected`, nothing changed (:114-116, :137); (c) Operations, a coach, another team's nurse and an administrator on a low-severity event refused (:126-130); (d) log holds both owners in order, first row unchanged, `access_seq` of the new owner, owner change audited (:140-152); (e) after a restore the claim stays with the new owner and the former owner's take-back is refused (:155-158); the lapsed claim on event 2 is taken over after the restore (:159-161). e2e `quality.spec` (390 px): "Übernehmen" on the lapsed claim, then "in Prüfung" after reload; the leaver's name is not shown. **The escalation clock is unchanged:** `quality_serious_open` is derived from `created_at` while `open` or `in_review` (0039:58-64); a take-over touches neither. **Small gap, not a finding:** no assertion that the *restored former owner* can take over her own still-lapsed claim; the code allows it (0087:111-113 with 0020:204-211) |
| **CGR-71** | **open**, advisory (S3); **remedy met on the #502 head `f1d74d7`** (CI green); closes when #502 is merged | 0088:74-94: on resume, `urgency`, `urgency_source` (`unknown` for an old request) and `referrer_requested_start` (kept when the request has none) are written to the case and added to the resume's `change_log` diff (old and new, actor, reason, key; 088:84-95), `audit_events` via `audit_cases`; the "return" branch is byte-identical to 0034 except the DST1 clock form (my diff of the two bodies). `team_cases` returns source and date only while `review_after_pause` is open (0088:142-169); ORDER BY and LEAVE1-3 guard kept. pgTAP 088: the team's RN and care assistant read `hoch:referrer_stated:4` (:114, :118); another team's nurse and Operations read nothing (:122, :126); no new case, matching request and visits unchanged (:101-104); earlier levels stay in the trail (:166); `convert_partner_request` unchanged (:173-179). No order reads `cases.urgency` (the three ORDER BYs in 0011, 0017, 0034 read `matching_requests.urgency`). Residual: **CGR-73** |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change; the named Clinical Owner's required review (owner, after G-1) |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-70**.

### COND2 checks (no finding beyond CGR-73)

- **COND2-1 (0087:55-105): IMPLEMENTED, protective (privacy).** The standing reader `member_unexported_working_days` is dropped (pgTAP 087:88). The count is returned only by `prepare_member_access_end`, to an administrator of her organisation while her access is open, never for herself; each read writes one audit row without the count (087:94-107); the team's nurse, Operations, a coach and another organisation's administrator get none (087:101-104). `my_unexported_working_days` on `/work` is unchanged (087:108). Labour-law and privacy content; `lca`'s, not clinical. No care path waits on it.
- **COND2-3: IMPLEMENTED, protective (data minimisation).** `/operations` no longer reads `care_visits` with the nurse's name (`operations/queries.ts`; unit `cond2-operations-payload`: no `visits` key, `care_visits` not read). OPS1 exceptions and their sync are unchanged, so no safety exception is lost.
- **COND2-2 clinical reading:** who may review a quality event is unchanged (same permission as `open` → `in_review`). Which qualification should review which severity stays D-16 (`clinical`), UNKNOWN; the take-over adds no rule there.

### ADM2 brief checks (not built; beyond CGR-72)

- **ADM2-5 consent thresholds** (two consents, a standing objection blocks, 14-day lapse): organisational, product authority (D-20). They admit a colleague, not a client; I see no clinical objection. **ADM2-6** keeps the qualification gate: no ADM2 command writes a qualification, and planning, take and cover refuse a member without one. That is the protective point; how a qualification is verified stays D-29 (`owner`) and CGR-16.
- **ADM2-11** releases her visits after the end date through the LEAVE1-13 rule, so they appear as uncovered and alert (J3, OPS1, SIG1). Protective.
- **The balancing measure** (qualification mix per team before and after admissions, read by the Clinical Owner) is the right place for a skill-mix concern. NAVORA sets no mix rule; that is D-10, D-25 (`clinical`), UNKNOWN.

### Gate status

| Item | Clinical gate |
|---|---|
| COND2-1 to COND2-3 (merged `0aa7f61`) | **clear**: no blocking finding. CGR-70 closed |
| COND2-4 (#502, open, CI green on `f1d74d7`) | **no blocking finding.** CGR-71 remedy met on the head; CGR-73 advisory, can be fixed in #502 or taken as a condition. I re-read the merge commit |
| **COND2 as a whole** | **clinical gate clear** once #502 is merged unchanged in substance |
| **ADM2** (approved, not built) | **CGR-72 is blocking for ADM2 acceptance.** Amending the brief before the build costs least; the build may start once the PO has amended it or recorded why not |
| All other items | unchanged |

### Decisions requested

- **po:**
  1. CGR-72: amend ADM2 (the leaver's primary and deputy roles and last-day visits in the ADM2-12 list; open cases still naming her surfaced at the ADM2-13 end), or record why not.
  2. CGR-73: show only this return's referrer date in the return task, or label a kept date with its origin; or record why not.
  3. COND2: accept once #502 is merged.
- **eng:** CGR-73 in #502 if the PO agrees; CGR-72 in the ADM2 build once the brief is amended.
- **clinical (Clinical Owner, after G-1):** D-34 question 7, D-16 (who reviews which severity), D-10/D-25 (team skill mix); all UNKNOWN until answered.
- **owner:** G-1 (named Clinical Owner), D-1; unchanged.

---

## 2026-10-27 01:27 CET: IPA1-1 to IPA1-8 (#484, #487, migration 0086) reviewed on their merge commits; CGR-69 closed (the criteria stay with `clinical`, D-34 question 7); CR-126 removed; CGR-71 (advisory, S3): a returning referral that resumes a paused case keeps the new referral's urgency, source and requested start from the team; clinical gate clear for IPA1

**Scope:** `recovery/main` @ `5f8efd1`. Changes since my 21:29 CET section (#485, merged `6b19b84`):
- **Code merged:** #484 **IPA1-1 to IPA1-6** (ADR-099, no migration; `/operations` legacy panels and `/matching` demo removed, wording, unit `ipa1-wording`, e2e 390 px) as `0db9992`; #487 **IPA1-7 and IPA1-8** (0086, ADR-100, pgTAP 086 (29), updated pgTAP 012-019, e2e `intake.spec`, `operations.spec`, `push.spec`) as `8e7bb6f`. **CI** (check runs read through the GitHub API): `app`, `db`, `e2e` green on `8e7bb6f`. On `5f8efd1` (PO docs only) `app` green, `db` and `e2e` still running at my read (UNKNOWN).
- **Docs merged:** PO 22:10 (COND1 accepted; CGR-70 decided as COND1-C2), PO 01:40 (#490: IPA1 reviewed, awaiting clinical review; COND2 approved as *Next up* 2; hypothesis P-14); `eng` 21:40, 23:25, 00:35, 01:15; `remediation/CGR-69.md`.
- **Open PRs:** only #3 (owner, `main`). No review comment addressed to me.
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0086 in full, pgTAP 086, the changed pgTAP files 012-019, `link_returning_referral` and `convert_partner_request` (0034, 0013), every writer of `urgency` in `supabase/migrations`, the audit trigger history (0010, 0013), the `/operations`, `/team` and `/intake` diffs, `src/features/intake/{rules,commands}.ts` and the e2e spec `intake.spec.ts:72-128`. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-71 | IPA1-7, IPA1-8 (0086) with RET1 (0034) | **advisory (S3)** | **When a returning referral resumes a paused case, the team never sees the new referral's urgency, its source or the referrer's requested start.** 0086 carries both facts only by BEFORE INSERT triggers on `cases` and `matching_requests`. The resume path of `link_returning_referral` inserts neither: it resumes the existing case with its team, un-suspends its planned visits, opens `review_after_pause` and marks the request `converted` onto the old case. The new request's level, source and date stay on `partner_requests`, which teams cannot read. The case keeps the urgency (and, for rows before IPA1-7, the source `unknown`) of the first referral. A resumed case is typically a client coming home from hospital, the H-19 situation; the referrer may now ask for an earlier start than the old schedule gives. Bounded: the team keeps the client, the planned visits resume at once and the review task is open, so no offer is delayed; the gap is a referrer's statement that does not reach the team. Pre-existing for the level (no writer ever updates `cases.urgency`), new for the source and the date, which IPA1-8 says are "carried to the case". pgTAP 086 tests only `convert_partner_request`. IMPLEMENTED as described; no clinical rule involved; synthetic data only | 0086:61-98 (insert triggers only); 0034:359-391 (resume path: no insert, `converted_case_id = prev.id` at :387, task at :384); `link_returning_referral` not redefined after 0034; pgTAP 086:86 (`conv`, the new-case path only) | **po (product authority; no threshold):** on resume, show the team the new referral's level with its source and the referrer's requested start (for example in the `review_after_pause` task detail, or by recording them on the case in an audited update with the old values kept in `change_log`). Or record why not. pgTAP: pause a case, link a returning referral with `hoch`, `referrer_stated` and a date → the team reads all three for that case; the case's earlier values stay in the audit trail; `team_offers` unchanged. Fits COND2 or a small IPA1 follow-up |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-69** | **closed**, IMPLEMENTED (IPA1-7, IPA1-8); CI green on `8e7bb6f` | Remedy (1), no preset: `intake-client.tsx:151, 162` (`required`, `defaultValue=""` for level and source); zod `urgencySource: z.enum(URGENCY_SOURCES)` (`commands.ts`); 0086:132 `urgency_required`, 0086:138 `urgency_source_required` (also refuses `unknown`); the old 11-argument signature dropped (0086:105), so no caller records a level without a source. Remedy (2), source recorded and shown: `urgency_source` NOT NULL on request, case and matching request, old rows `unknown`, never back-filled (pgTAP 086:40-47); carried by insert triggers (0086:61-98); `team_offers` returns it (0086:202) with the LEAVE1-3 guard kept (0086:193, pgTAP 086:159); `/team` shows "Dringlichkeit: <Stufe> (<Quelle>)" (`team-client.tsx:256`; e2e `intake.spec.ts:72`); refusals pgTAP 086:56-70. The ORDER BY is byte-identical to 0034 (0086:214, pgTAP 086). Audit: the three triggers keep every earlier key and add the two new ones (0086:222-237 vs 0010:41-47, 0013:78-82); value classes `code` (AUD1-1). The requested date is never read by an order, filter or escalation (pgTAP 086:155-165). **Residual (not a finding, OPEN):** whether an intake person may choose "bei der Aufnahme eingeschätzt" at all, and on which criteria, is D-34 question 7 (`clinical`, Clinical Owner after G-1). NAVORA sets none; until answered both values are offered. The resume path is CGR-71 |
| **CGR-70** | open, advisory (S3); decided by the PO 22:10 as COND1-C2, now COND2-2 (*Next up* 2). PLANNED | The brief's pgTAP (a)-(e) matches my remedy. I review the build when it is merged |
| **CGR-68** | open, advisory (S2); interim part IMPLEMENTED | no change; the named Clinical Owner's required review (owner, after G-1) |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-69**.

### IPA1 checks (no finding beyond CGR-71)

- **IPA1-1, -2, -4: IMPLEMENTED, protective.** The client-side team "risk score" (utilisation bands 80/90/95 %) and the case "SLA" age rule (24 h / 48 h without a team) are removed with "Top Risiko-Fälle", "SLA Monitor" and the `/matching` scorer; `grep` finds no `getTeamRiskScore`, `getSlaStatus` or `calculateMatchScore` in `src/`. These were invented thresholds (CR-126). Nothing safety-relevant is lost: the same cases reach Operations through the server model (`offer_overdue`, `deadline_missing`, `case_not_ready`, `visit_uncovered_hospital`; 0019, 0024, 0035). "Schwere Qualitätsereignisse" counts the same `quality_serious_open` exceptions as before. CR-126 → DEPRECATED (removed).
- **IPA1-3, -5, -6:** wording only; unit `ipa1-wording.test.ts` (allow-list empty) and e2e at 390 px. No clinical path.
- **IPA1-8:** the date check (not before the request's Zurich creation day; 0086:39-41, :141) is a data-validity rule, not a clinical one. The team's offer now shows two start dates: the intake person's `cases.requested_start` and the referrer's. **On the PO's P-14** (01:40): clinically I see no objection to keeping both separate and unfilled during the pilot. A referrer's date and the date the service can actually offer are different facts, and a pre-fill would erase whose statement it is (the same provenance point as CGR-69). If the pilot shows they mostly agree, the decision which one readiness item 6 reads goes through D-15 (`clinical`), as the PO wrote.
- **No new clinical rule, threshold, recipient, step or tariff value** in 0086 or ADR-099. G3's ordering (CR-125) is unchanged and still UNVALIDATED.
- **Small observation (not a finding):** the coordinator's case list on `/intake` (`intake-client.tsx:481`) shows the level without its source. That list is the intake person's own record, not a team decision point, so the brief's "wherever a team sees the urgency before it decides" is met.
- **PO condition IPA1-C1** (`/operations` stops loading `care_visits` with nurse names): privacy, not clinical. I support it as data minimisation.

### Gate status

| Item | Clinical gate |
|---|---|
| IPA1 (IPA1-1 to IPA1-8; 0086 on `8e7bb6f`) | **clear**: no blocking finding. CGR-71 is advisory (S3) and needs no change before acceptance; the PO may take it as a condition |
| COND2 (approved, not built) | not reviewed; I review it when merged |

### Decisions requested

- **po:** CGR-71 (show the resumed client's new referral facts to the team, or record why not).
- **clinical (Clinical Owner, after G-1):** D-34 question 7, unchanged: may intake assess urgency, and on which criteria. UNKNOWN until answered.
- **owner:** G-1 (named Clinical Owner), D-1; unchanged.

---

## 2026-10-26 21:29 CET: COND1-4a, -5a, -5b, -6, -8, -9, -10 (0084, 0085) reviewed on their merge commits; CGR-66 and CGR-67 closed; CGR-68 interim part met (stays open for the G-1 review); CGR-70 (advisory, S3): a lapsed quality claim cannot be taken over, only closed; clinical gate clear for COND1; IPA1-1 to -6 (#484, open) read

**Scope:** `recovery/main` @ `86b6a0b`. Changes since my 17:26 CET section (#472, merged `6de8543`):
- **Code merged:** #471 **COND1-4a, -5a, -6, -9, -10** (0084, ADR-097, pgTAP 084, pgTAP 082 +6, unit `cond1-clinical-categories`, `cond1-display`, e2e `work.spec`, `door.spec`) as `25bacf3`; #479 **COND1-8 and COND1-5b** (0085, ADR-098, pgTAP 085 (25), pgTAP 083) as `09228ef`. **CI** (check runs read through the GitHub API): `app`, `db`, `e2e` green on the heads `548f546` (#471) and `bfc4cb9` (#479), on the merge commit `09228ef` and on `86b6a0b`.
- **Docs merged:** PO 18:10 (CGR-69 decided as IPA1-7/-8; D-35 option A) and 20:25 (D-35 term 11, G-22; D-1 connector step); `eng` 17:55, 19:19, 20:34, 20:40; `lca` 17:55, 19:42, 21:00.
- **Open PRs:**
  - #483 (PO 21:10): COND1 reviewed, "awaiting clinical review" for 0084 and 0085; new PO condition COND1-C1; hypothesis P-13.
  - #484 (eng): IPA1-1 to IPA1-6, with the CGR-69 remediation plan. `app` and `db` green on `c3def52`, `e2e` running at my read.
  - #3 (owner, `main`).
- **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0084 and 0085 in full, pgTAP 084, 085 and the 082 addition, the `agents-check` and `clinical-categories.mjs` changes with their unit test, `set_quality_event_status` (0020:215-251), `signal_take_lapsed` and `latest_access_end_seq` (0080:73-104), the 0080 readers that 0085 patches (0080:276-410), and the #484 diff and `remediation/CGR-69.md`. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-70 | COND1-8 = LEAVE1-C5 (0085) with QG1 (0020) | **advisory (S3)** | **A quality event whose review claim has lapsed cannot be taken over by anyone. It can only be closed.** `set_quality_event_status` allows `in_review` only from `open`. Once the owner's access ends, the team reads the event as "Übernahme beendet – Zugang beendet". No colleague can record "I review this now", and neither can the owner after a restore. Since LEAVE1-C5 the claim stays lapsed for good, so this state no longer ends with a restore. The event's only exit is `closed` with a note. The risk: a team that wants the event off its list closes it before anyone has reviewed it, or leaves it ownerless. LEAVE1-C3 option (a) rests on "she takes it again if she still holds it". That works for a signal or an OPS1 take (a new take is an insert), but not for a quality claim. Bounded: a serious event stays in OPS1 while `in_review` and escalates P2 → P1 (CGR-05, CGR-06; 0039), so Operations still sees it. pgTAP 085 tests "a claim after the restore counts" on a different event (`c(2)`), never on the lapsed one. The PO's P-13 (21:10, #483) measures the single-owner pattern, but this gap exists now. IMPLEMENTED as described; no clinical rule involved; synthetic data only | 0020:236 (`p_status = 'in_review' and q.status <> 'open'` → `rejected`), 0020:242 (owner set only on `in_review`); 0085:82-92 (`quality_claim_lapsed`), 0085:108-111; pgTAP 085:114 (event 1 still ended after the restore), 085:129-131 (re-claim on event 2 only) | **po (product authority; no threshold):** let a member who may handle the event (`can_handle_quality_event`) take over an `in_review` event whose claim has lapsed: `in_review` → `in_review`, new owner, logged in `quality_event_log` with `access_seq`. A take-over of a claim that has not lapsed stays refused. Or record why not. pgTAP: claim, end, restore → `claim_ended` true; a colleague takes over → `claim_ended` false and the new owner is recorded; the restored owner can do the same; a take-over of a live claim → `rejected`. Fits IPA1 or a small COND1 follow-up beside COND1-C1 |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-66** | **closed**, IMPLEMENTED (COND1-9 = DOOR1-15); CI green on `548f546` | Guard unchanged (0073:177, 0080:421-436). The help text "Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code" is `access_arrangement` version 2 (0084:96-100) and is used at intake (`src/features/door/rules.ts` `ACCESS_HELP_TEXT`; `intake-client.tsx`). pgTAP 084:83-98: "079 123 45 67" and "8004 Zürich" are refused (22023); "Schlüssel bei der Tochter, Hintereingang" is accepted and stored as written; version 1 is kept; values match by code. Unit `cond1-display.test.ts:68` pins the same three cases. **Residual (not a finding):** whether the nurse at the door needs the key holder's reachability stays D-17 part 3 (Clinical Owner). The PO's 21:10 wording observation ("8004 Zürich" refused as a "Code") is right; I add nothing |
| **CGR-67** | **closed**, IMPLEMENTED (COND1-8 = LEAVE1-C5); CI green on `bfc4cb9` | 0085:52-79: `access_seq` is set by a BEFORE INSERT trigger on `exception_events` and `quality_event_log`, so every writer records it. 0085:100-111: `operations_exceptions`, `team_visit_alerts` and `field_quality` use the C3 predicate (`signal_take_lapsed`, 0080:93-100). The 0080 readers show the name only `when not take_ended` (0080:311), and `field_quality` returns no owner name. pgTAP 085:88-131: before the end, take and claim count (`access_seq` 0); after the end and the restore, both read as untaken with `take_access_ended` and no name; a take and a claim recorded after the restore count. Deviation 19 (a claim with no recorded transition reads as lapsed once any access end exists) errs to the safe side, pgTAP 085:134-140. The new gap this creates for the lapsed claim is **CGR-70** |
| **CGR-68** | **open**, advisory (S2). Interim part **IMPLEMENTED** (COND1-10 = DOOR1-16); CI green on `548f546` | `clinical-categories.mjs` `approvalRecordErrors`: an `APPROVED` row must link `approvals/CR-nnn.md`, and the record must hold an approver role, a G-1 reference and an ISO date. Unit `cond1-clinical-categories.test.ts` (no record fails; a complete record passes; missing fields are named; today's register passes; `agents-check` exits 1). **Still open:** the record is a file that an agent PR can add in the same change, and it names a role, not a person (D-27 asks for a named, qualified person). The remaining remedy is the owner's: required review by the named Clinical Owner after G-1 (for example CODEOWNERS). Until then no `APPROVED` row exists, which `agents-check` keeps visible |
| CGR-69 | open, advisory (S2); decided by the PO 18:10 as IPA1-7 and IPA1-8; PLANNED. `eng` remediation plan in #484 (`remediation/CGR-69.md`) | The plan matches my remedy (no preset, refused when empty; source `referrer_stated` / `intake_assessed`, old rows `unknown` and never back-filled; shown on `/team`; ordering unchanged; requested date never orders). I review the build when it is merged |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-66, CGR-67**.

### COND1 checks on 0084 and 0085 (no finding beyond CGR-70)

- **COND1-4a: IMPLEMENTED.** pgTAP 082 (+6): no Operations member with open access, so the recipient is the administrator `…905` (`signal_operations_users`). Without a `push_active` subscription the forecast is false; with one it is true. The forecast and the delivery use the same recipient set. CR-123's "PLANNED" note is resolved.
- **COND1-6 = AUD1-M1: IMPLEMENTED, protective.** With purpose `billing`, every `free_text` value is withheld, also inside the team (0084:55). A quality hold's reason is health-related free text, and billing needs only the fact, time and author of a hold. pgTAP 084:47-80; each read is still logged (AUD1-5). `compliance` and `safety_review` are unchanged, so a safety review inside the team still reads the reason.
- **COND1-5a and COND1-5b: no clinical, billing or tariff path.** v3 gates `my_working_day` only, as v2 did (17:26). `/field`, reports, signatures and signals do not wait for it. Content: `lca` 21:00.
- **COND1-9, COND1-8, COND1-10:** as in the status table.
- **No new clinical rule, threshold, recipient, step or tariff value** in 0084 or 0085. The P2 → P1 clock, `handle_exception` and the QG1 closing rules are unchanged (0085 header; readers only).
- **PO condition COND1-C1** (#483, the unexported-days reader only in the end path): not clinical. I support it as the stricter control.

### IPA1-1 to IPA1-6 (#484, open; read on its head `c3def52`; not a gate result)

- **The legacy `/operations` page holds hard-coded rules that the register did not list.** It holds a client-side team "risk score" (utilisation bands 80 / 90 / 95 %) and a case "SLA" age rule (no team after 24 h = "risk", after 48 h = "violated"), and `/matching` holds a demo scorer. These contradict the register's *Not in the code* line ("no … risk scores"). They are now listed as **CR-126**. #484 removes all three: a client-side triage by invented thresholds is replaced by the server OPS1 model (`case_not_ready`, `offer_overdue`, `visit_uncovered_hospital`), which keeps its ordering rule. Clinically this is protective: no safety signal is lost, because the removed panels were display only and their cases stay in the OPS1 exception list. I confirm this on the merge commit.
- **IPA1-3:** "überwachte Zeit" → "besetzte Zeit". Correct: the earlier word implied monitoring of the client, which does not happen. The behaviour is unchanged.
- #484 still loads `care_visits` on `/operations` without using it (`eng` names it). That is data minimisation for `lca`, not a clinical point.

### Register rows

- **CR-119** note: CGR-66 is closed (0084, pgTAP 084).
- **CR-121** note: the interim part of CGR-68 is IMPLEMENTED (approval record); the G-1 review is still open.
- **CR-122** note: superseded for restores by **CR-127** (LEAVE1-C5).
- **CR-123** note: COND1-4a is IMPLEMENTED.
- **CR-124** note: the gate is `work1-notice-v3` since 0085.
- **Added:**
  - **CR-126:** the legacy `/operations` team risk score and case "SLA" age rule, and the `/matching` scorer. They are IMPLEMENTED on `recovery/main`, with removal PLANNED in #484. Not clinically approved; invented thresholds.
  - **CR-127:** LEAVE1-C5, the access sequence for OPS1 takes and quality claims (0085; organisational; note CGR-70).
  - **CR-128:** the `billing` purpose reads codes only (0084; privacy, not clinical).
- None of them is a clinical rule as approved; CR-126 is an invented one, being removed.
- **Hazards:**
  - H-03: CGR-66 closed.
  - H-07: CGR-67 closed; new cause CGR-70.
- **Risks:**
  - PS-56 and PS-57 closed.
  - G-8: interim part met.
  - PS-59 added (CGR-70).

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| COND1-4a, -5a, -6, -9, -10 (merged `25bacf3`) | **reviewed on the merge commit; no blocking finding.** CGR-66 closed; CGR-68 interim part met | CGR-68 (owner part) |
| COND1-8, -5b (merged `09228ef`) | **reviewed on the merge commit; no blocking finding.** CGR-67 closed | CGR-70 (advisory) |
| **COND1 as a whole** (`delivered`; PO review in #483) | **clinical gate clear: no blocking finding on COND1-1 to COND1-10.** The PO may set COND1 `accepted`. CGR-70 is advisory and can be recorded as a condition | CGR-68 (owner), CGR-70 |
| IPA1-1 to -6 (#484, open) | read; protective; gate result on the merge commit | none |
| IPA1-7, -8 (CGR-69) | plan read and consistent; PLANNED | CGR-69 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:**
  1. COND1: the clinical gate is clear. Accept COND1, and record CGR-70 as a condition or with a reason.
  2. CGR-70: let a qualified team member take over a lapsed quality claim, or record why not. P-13 measures the pattern; this fixes the dead end now.
- **eng:**
  1. IPA1-7 and IPA1-8 as planned.
  2. CGR-70 once the PO decides.
- **owner:**
  1. G-1: name the Clinical Owner and a deputy. The required review of register status changes (CGR-68), D-35 (H agents), D-34 question 7 and CGR-69 (2) all wait for it.
  2. D-1 (urgent; the connector step).
  3. The G-11 count before the first real import.
  4. G-5.
  5. Merge this PR if my own merge is refused.
- **clinical** (once named):
  - CGR-69 (2): may an intake person judge urgency, and on which criteria?
  - D-35: the safety-field list (2c) and the stop-rule threshold (2e).
  - D-17 part 3, now also the key holder's reachability (CGR-66 residual).
  - D-30, D-19 part 1, D-28, D-10 and D-16, as before. D-16 includes how long a quality event may stay in review (P-13).

---

## 2026-10-26 17:26 CET: COND1-3 (0081), COND1-4 (0082) and COND1-5 (0083) reviewed on their merge commits; CGR-60 and CGR-65 closed; CGR-69 (advisory, S2): the intake urgency that orders team offers is a criteria-free label with a preset value; clinical input for D-35 and D-34 question 7

**Scope:** `recovery/main` @ `6d2bb3e`. Changes since my 13:39 CET section (#452, merged `0119248`):
- **Code merged:** #451 **COND1-3** (WORK1-C1 + WORK1-C4; 0081, ADR-094, pgTAP 081) as `b58e9fc`; #457 **COND1-4** (FUP1-C1 + FUP1-C2; 0082, ADR-095, pgTAP 082 (23), pgTAP 069 fixture) as `a6757d0`; #465 **COND1-5** (WORK1-C2 + WORK1-C3; 0083, ADR-096, pgTAP 083 (26)) as `6002b4e`. **CI** (check runs read through the GitHub API): `app`, `db`, `e2e` green on the heads `8b63dcd` (#451), `4e0cd29` (#457) and `47403c1` (#465). On `a6757d0` one `db` run failed and a second run is green; `eng` 14:59 names the cause (a bare `ok` fixture row broke the TAP stream; fixed by wrapping it in `ok()`, as 082:57 shows). On `6d2bb3e`, `app` and `db` are green and `e2e` was still running when I read it.
- **Docs merged:** PO 14:20 (labelled 15:00), 14:30, 14:40, 14:47, 15:16, 16:20 and 17:15; `eng` 13:50, 14:10, 14:31, 14:59, 15:38 and 16:19; `lca` 15:04, 15:43 and 16:42.
  - **CGR-66, CGR-67 and CGR-68 were decided by the PO (14:30) as COND1-9, COND1-8 and COND1-10.** All three are PLANNED.
  - **D-35** is open (`inputs-requested`). It asks `cra` for a *Clinical impact*.
  - **D-34 question 7** asks `cra` whether the intake urgency is a clinical judgement.
  - **D-33** was decided by the owner: Safari and Firefox stay in-app only. New gate G-20.
- **Open PRs:** only #3 (owner, `main`); I commented on no PR. **No `clinical`, `legal` or `owner` decision was answered by a person** apart from the owner's D-33.

I read 0082 and pgTAP 082 in full, the 0083 migration, the classifier `private.outside_classify` and `private.push_active` (0062) as the step uses them, `record_partner_request` (0010:71-94), the intake form (`intake-client.tsx:142-147`), `team_offers` (0017:410) and the D-35 and D-34 packages. For COND1-3 I diffed the merged files against the head I read at 13:39 (`e46dc87`): no change in `supabase/`, `src/` or `tests/`. **I did not run the NAVORA test suite** and did not touch the live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-69 | Intake urgency (J1 intake, 0010) as used by `team_offers` (0017:410); D-34 G3, question 7 | **advisory (S2)** | **The urgency that orders the team's offers is a three-level label chosen by an administrator or Operations person, with no stated criteria and a preset value of "mittel".** The team sees its offers sorted `hoch` → `mittel` → `niedrig` before the response deadline. A coordinator who does not touch the select files every referral as "mittel". The record does not say whether the value is the referrer's stated urgency or an intake person's own reading of the need summary. Clinically, the second case is a triage judgement of the client's condition, made by a role that need not be a nurse. Wrong in either direction, it delays acceptance and so the first visit of a client who was sent home from hospital needing care (H-19). The preset value also hides who chose the level: "mittel" can mean "chosen" or "never chosen". No clinical rule is in the code, so nothing here is invented. What is missing is the provenance of a value that is used to rank. IMPLEMENTED as described; synthetic data only | 0010:71-94 (`has_org_role(... 'admin', 'operations')`; `p_urgency in ('niedrig','mittel','hoch')`, no criteria); `src/app/(protected)/intake/intake-client.tsx:142-147` (`defaultValue="mittel"`); `src/features/intake/commands.ts:22`; 0017:347, 410 (`order by case m.urgency when 'hoch' then 0 …`); D-34 report §7.2 G3; D-34 *PO 16:20* (question 7 fact drafted by the PO, not confirmed by `eng`) | **po (product authority; no threshold, no criteria):** (1) remove the preset, so the intake person must choose a level (an empty select is refused); (2) record whose urgency it is, as a fixed choice: "vom Zuweiser angegeben" or "bei der Aufnahme eingeschätzt". With PO hypothesis P-10, also record the referrer's requested first-visit date. pgTAP: a request without an urgency or without a source is refused; the source is stored and shown with the level on `/team`. e2e: the form has no preselected urgency. **clinical (Clinical Owner, with D-34 question 7):** whether an intake person may set "eingeschätzt" at all, and on which criteria. I set none |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-60** | **closed**, IMPLEMENTED (FUP1-C2); CI green on `4e0cd29` | 0082:33-41 (`private.signal_operations_reachable`: the channel on after `enabled_since`, and a recipient of the step's own set `signal_operations_users` with `push_active`, both reused); 0082:65 (the not-made branch also requires it). The same two inputs decide the real classification (0062 `outside_classify`: `ps.enabled`, `d.created_at >= ps.enabled_since`, `push_active`), so the forecast and the step agree. pgTAP 082:72-86: channel off → false; channel on with no member subscribed → false; subscribed but no send has succeeded yet → false; one active → true; read before `enabled_since` → false. 082:97-105: subscription ended, or last send failed → false. **Residual (no finding):** reachability is read at the reading instant, not at the due instant. A subscription that lapses in the minutes between can still show the promise. The in-app delivery covers that case (display only) |
| **FUP1-C1 (Q16)** | IMPLEMENTED; CI green on `4e0cd29` (PO condition, not a CGR) | 0082:24-30 (`signal_evaluator_interval()` = 1 minute, commented with the cron job); 0082:58-60. pgTAP 082:88-94: due 19:59:30 → false, 19:58 → true, 19:59 → false (end exclusive), watched to 21:00 → true; 082:107-114: made-step branch unchanged |
| **CGR-65** | **closed**, IMPLEMENTED (WORK1-C4); CI green on `8b63dcd` | as read on #451 at 13:39, merged unchanged: 0081 `working_day_proposal` takes the effective event time (latest F3 correction, else the recorded time) for start, end, order and Zurich date, through the same lateral join as billing (0023:33-36), and marks `corrected`. `/work` shows the hint and a link to the visit's time correction. No write-back: pgTAP 081:139-161 (a corrected event moves the segment and its day; the visit tables' row fingerprint is unchanged). The ADR-094 deviation (link by event instant) reaches the day only for a segment she already edited. That is not a safety point: the visit's time is corrected on `/field` either way |
| CGR-66, CGR-67, CGR-68 | open, advisory (S3, S3, S2); decided by the PO 14:30 as COND1-9 (DOOR1-15), COND1-8 (LEAVE1-C5), COND1-10 (DOOR1-16). PLANNED | `briefs/COND1.md` *PO decisions 14:30*. The decided remedies match mine. For CGR-66 the PO chose "no phone number in the note", with the help text naming where the key holder is. The key holder's reachability goes to D-17 part 3 as a structured contact. I support that: the decision keeps the guard and does not loosen it |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-60, CGR-65**.

### COND1-3, COND1-4 and COND1-5 checks (no finding beyond CGR-69, which is outside COND1)

- **WORK1-C1 (0081): IMPLEMENTED.** Care minutes are the union of the care segments, clipped to the day, minus breaks. `care_le_paid` holds (NOT VALID only on old synthetic rows). pgTAP 081:61-102. The team ratio (CR-116) can no longer exceed 100 %. It stays a process measure, to be read beside the team's safety measures (G-5).
- **COND1-4 (0082): display narrowing only, protective.** A `false` makes the banner say "Operations in der App", and the in-app delivery happens either way. The step, thresholds, watched hours and recipients are unchanged (D-28, D-32). The admin fallback is reused, not copied. Its own pgTAP assertion is COND1-4a (PO 15:16), PLANNED: 082 has an Operations member, so the fallback branch is not exercised there.
- **COND1-5 (0083): no clinical, billing or tariff path.**
  - The export record `working_day_exports` holds who, month and when. No app role can read or write it, it is append-only, and the LEAVE1-3 policy applies.
  - The count reads only `working_day_versions` and the export record. No billing function reads either.
  - The v2 acknowledgement gates `my_working_day` only. Nothing on `/field`, a report, a signature or a signal waits for it, so a nurse who has not yet acknowledged v2 can still document and sign care. I checked this because a blocking notice in front of a care workflow would be a safety point. It is not.
  - Labour-law and privacy content is `lca`'s (D-23; `lca` 16:42 compliant on its terms).
- **No new clinical rule, threshold, recipient or step** in 0081 to 0083.

### Clinical impact for D-35 (AI services), as requested by the PO; for the PO to take into the package

*Advisory. I am not a licensed clinician; the Clinical Owner decides (G-1). Today no AI service is called anywhere (D-35 Context, IMPLEMENTED). Everything below is about agents that are PLANNED or proposed.*

1. **Hazards of G and H agents** (new hazard **H-20**):
   - *Omission in extraction* (A8): a discharge letter names an allergy, an anticoagulant or an infection precaution, and the structured referral does not. An empty field reads the same as "none". That is H-03 at the moment of intake.
   - *Summarising away a safety fact* (A9, A12): a handover or transfer summary leaves out the one sentence that mattered (a new wound, a fall last night, "refuses medication").
   - *Content the nurse did not observe* (A7, A9): a draft states a fact or a measurement nobody recorded. If it is signed, it enters the record as hers. That damages documentation integrity (H-05) and, through the signed snapshot, the billing basis (H-14).
   - *Automation bias* (all G and H agents): proposals that are accepted unread. `lca` notes that this also moves the case towards DSG Art. 21.
   - *A7 transcription errors*: drug names, doses and numbers are the words most at risk. "Transcription" is not clinically neutral.
2. **Minimum forced-attention design** before any G or H agent touches real data. Each point is a testable product property; none is a clinical threshold:
   - (a) **Provenance on every value.** An agent-produced value is stored as a *proposal* with agent, version and input reference. It becomes record content only when a named person confirms it, and the record shows "vorgeschlagen von … / bestätigt von … am …". Signing a draft is not confirming every value in it.
   - (b) **"Not found" is explicit.** An extraction field the agent did not find shows "im Dokument nicht gefunden", never an empty or "keine" value. A safety field (allergy, anticoagulation, infection precaution, access) cannot be confirmed without the source document open beside it.
   - (c) **No accept-all.** Fields that feed the safety-alert set (D-17), the care plan or a medical order are confirmed one by one. Which fields count as safety fields is the Clinical Owner's list (D-17 part 3). I do not set it.
   - (d) **Source beside proposal.** Each proposed value links to the passage it came from. A value with no source passage cannot be confirmed as a fact; it can only be typed by the person.
   - (e) **Measured acceptance.** The suggestion ledger records accepted unchanged, edited and rejected per agent and field (aggregated, never per nurse, as CR-079). A stop rule pauses an agent when its safety fields are accepted unchanged at a rate the Clinical Owner sets. That threshold is UNKNOWN, owner `clinical`.
3. **Which agents are clinical rules in substance** (for the Clinical Owner):
   - **Yes:** A8, A9, A10, A11, A12 (H, as the review says).
   - **Yes as to errors:** A7. It records clinical content, so its error modes are clinical even if its function is transcription.
   - **Not clinical, but on a clinical boundary:** A2 (order renewal: a missed renewal leaves B care without an order, H-18), A3 (the roster must apply the qualification and delegation rules CR-007, CR-009 and CR-010, still UNVALIDATED under D-15; an agent must not plan around them) and A4 (billing integrity, H-14).
   - **Not clinical:** A1, A5, A6 as rules without AI.
4. **Position:** option A stays the clinically safe default. Before a real client, no G or H agent is clinically acceptable without 2(a) to 2(e), the D-34 module for H, and a named Clinical Owner (G-1).

### Clinical input for D-34 question 7 (who sets the intake urgency, and is it a clinical judgement)

- **Fact (IMPLEMENTED, static reading, agrees with the PO's draft):** an `admin` or `operations` member chooses one of three levels at intake. The form preselects "mittel" and states no criteria (CGR-69 evidence).
- **Clinical reading:** if the level copies what the referrer said, it is an administrative fact, as with G4 and G5. If the intake person derives it from the need summary, it is in substance a clinical triage judgement of the client's condition. As built, the record cannot tell the two apart, so neither can the adviser. CGR-69 (2) makes it visible. Whether an intake person may make the second kind of judgement, and on which criteria, is UNKNOWN. Owner: `clinical` (Clinical Owner). If yes, it needs a named qualification for that person.
- No opinion on the regulatory classification; that is `lca` and the adviser.

### Register rows

- **CR-098** note: FUP1-C1 and FUP1-C2 are IMPLEMENTED (0082), and CGR-60 is closed.
- **CR-114** note: CGR-65 is closed. Since 0081 the proposal uses the effective time.
- **CR-116** note: WORK1-C1 is IMPLEMENTED (0081), so the ratio is ≤ 100 %.
- **Added:**
  - **CR-123:** the FUP1-C1/-C2 forecast conditions (0082; organisational, input class V).
  - **CR-124:** the unexported-days count and the v2 acknowledgement gate (0083; not clinical, listed for the boundary check above).
  - **CR-125:** the intake urgency order (0010, 0017:410; note CGR-69).
- None of them is clinical.
- **Hazards:** H-19 (delayed start of care after a referral) added. H-20 (an AI agent's output drops, alters or adds a safety fact; PLANNED agents only) added.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| COND1-3 (merged `b58e9fc`) | **reviewed on the merge commit; no blocking finding.** CGR-65 closed | none |
| COND1-4 (merged `a6757d0`) | **reviewed on the merge commit; no blocking finding.** CGR-60 closed, FUP1-C1 met | COND1-4a (admin fallback assertion) still PLANNED |
| COND1-5 (merged `6002b4e`) | **reviewed on the merge commit; no clinical or billing finding** (privacy and labour law: `lca`) | none |
| COND1 as a whole (`in-progress`) | the clinical gate does not block the PO's COND1-7 review once COND1-6 and COND1-8 to -10 are merged; I review those when merged | CGR-66, -67, -68 until COND1-8 to -10 |
| J1 intake / D-34 G3 (accepted earlier) | advisory finding | CGR-69 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:**
  1. CGR-69: remove the preset urgency and record its source (referrer or intake), as a small brief or an IPA1 or COND1 addition. Take the clinical input above into D-34 question 7.
  2. Take the D-35 *Clinical impact* above into the package.
  3. COND1-7: the clinical gate is clear for COND1-1 to -5.
- **eng:**
  1. COND1-4a, COND1-6, COND1-8 to -10.
  2. Confirm the D-34 question 7 fact (who sets the urgency).
- **owner:**
  1. G-1: name the Clinical Owner and a deputy. D-35 (H agents), D-34 question 7 and CGR-68 all wait for it.
  2. D-1 (urgent).
  3. The G-11 count before the first real import.
  4. G-5.
  5. Merge this PR if my own merge is refused.
- **clinical** (once named):
  - CGR-69 (2): may an intake person judge urgency, and on which criteria?
  - D-35: the safety-field list (2c) and the stop-rule threshold (2e).
  - D-17 part 3, D-30, D-19 part 1, D-28, D-10 and D-16, as before.

---

## 2026-10-26 13:39 CET: COND1-1 and COND1-2 (0080, pgTAP 080, 078) reviewed on their merge commit; CGR-61, CGR-63, CGR-64 closed; CGR-66 (S3), CGR-67 (S3), CGR-68 (S2), all advisory; COND1-3 (#451, open) read: CGR-65 remedy as built, not yet merged

**Scope:** `recovery/main` @ `a5d5cc7`. Changes since my 09:26 CET section (#441, merged `f8f4b6a`):
- **Code merged:** #446 **COND1-1 and COND1-2** (0080, ADR-093, pgTAP 080 (58), pgTAP 078 restore block replaced (50), pgTAP 065/067/072/073/074 catalogue lists, `SafetyAlertForm.tsx`, `door/rules.ts`, intake form and command, `field_quality` card, `scripts/agents-check.mjs` with `agents-coordination/clinical-categories.mjs`, unit `cond1-display`, `cond1-clinical-categories`, e2e `door.spec`) as `cb5e317`. **CI `app`, `db`, `e2e` green on the head `66e8d0a` and on `a5d5cc7`** (check runs read through the GitHub API; one superseded `e2e` run on `cb5e317` cancelled, a second run green).
- **Docs merged:** PO 10:15 (**WORK1 accepted**; CGR-65 placed as WORK1-C4 in COND1-3; D-23 item 16); `eng` 10:13 (#435), 11:45, 12:20 (COND1 `in-progress`); `lca` 09:55 (D-23, CGR-65), 12:50 (D-17 re-check after DOOR1-12). Eng added register rows CR-117 and CR-118 for my review.
- **Open PRs:** #451 (eng, **COND1-3 = WORK1-C1 + WORK1-C4**, 0081, ADR-094, pgTAP 081; `app` green, `db` and `e2e` running at my read, merge state `dirty`), #3 (owner, `main`). **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0080 in full, the pgTAP 080 assertions, the pgTAP 078 restore block, the DOOR1-14 check script and its unit test, the intake command and form changes, the DOOR1-4 guard (0073:174-177) and its unit examples, and on #451 the migration 0081, the `/work` rules and pgTAP 081. **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-66 | DOOR1-12 (0080) with the DOOR1-4 guard (0073) | **advisory (S3)** | **The code guard on the intake note also refuses postal codes and phone numbers, and nobody has decided whether that is wanted.** The predicate refuses any four digits in a row, also with single separators. So "Schlüssel bei Tochter, 079 123 45 67" or "Hintereingang, 8004 Zürich" is refused with "Bitte keinen Code erfassen". The client's emergency-contact phone is not readable by the team (0015:68), so this note is today the only place a key holder's number could reach the nurse at the door. A coordinator who is refused will probably delete the number, not move it. The risk: a nurse at a locked door cannot reach the key holder, and the visit to a client who may need help is delayed or missed. The guard is correct for its purpose (PS-50, physical safety); what is open is the trade-off, and the tests show neither case. Bounded: synthetic data only. IMPLEMENTED as described; no clinical rule involved | 0073:177 (`[0-9]([ .,:/-]?[0-9]){3}`); 0080:421-436 (trigger on every writer of `cases.access_notes`); `tests/unit/door1-alerts.test.ts:10-19` (no phone number or postal code among the examples); pgTAP 080:261-286 (code-like examples only); 0015:68 (emergency contact phone revoked from the team) | **po (product authority), with D-17 part 3 for whether a key holder's reachability belongs on the card (Clinical Owner):** decide whether a phone number and a postal code may appear in the access note. If they may not, the help text says where the key holder's number goes. If the nurse needs it at the door, that is a structured field under D-17, not a weaker guard. Either way, unit and pgTAP examples pin the decided behaviour for "079 123 45 67" and "8004 Zürich". Do not loosen the guard before the decision |
| CGR-67 | LEAVE1-C4 (0080) beside LEAVE1-C3 | **advisory (S3)** | **A restore brings back a leaver's OPS1 take and her quality-review claim, though it no longer brings back her signal take.** LEAVE1-C4 is evaluated live (`access_ended` now). After a restore, Operations again reads the OPS1 exception as taken, with her name, and the team again reads the quality event as "in Prüfung" by her. The PO's reason for option (a) applies here too: she has no push subscription after the end and may not know she holds the claim. No step is stopped (the P2 → P1 clock and the QG1 rules run on, as the brief says), but colleagues read a claim that nobody may be acting on, until the clock escalates. Not tested: pgTAP 080 ends access but never restores it for C4 | 0080:293, 357 (`private.access_ended(ev.actor_id)`), 0080:398 (`private.access_ended(q.owner_id)`); LEAVE1 brief *Conditions* C3 ("a restored person … may not know she held the signal") and C4; pgTAP 080:237-253 (end only) | **po (product authority; no threshold):** either use the C3 rule for both (a take or review claim counts only if recorded after the person's latest access end, by the access-event sequence as in 0080:73-101), or accept the difference with a recorded reason. pgTAP: take an OPS1 exception and claim a quality event, end the access, restore it → both still read as untaken with `take_access_ended` and `claim_ended`, and no name shows. Fits COND1 as a small addition, or LEAVE1-C1 |
| CGR-68 | DOOR1-14 (0080, `agents-check`) | **advisory (S2; before the first clinical category)** | **The gate for a clinical category now trusts one Status cell in a markdown file that any agent's PR can change.** CGR-61 asked for a database form check plus a check against the register. Both are built (closed below). But the register says who may approve (a named, qualified person, D-27), and nothing checks that. An agent PR that sets a row to `APPROVED` and inserts a clinical category in the same change passes `agents-check` and CI. My own role forbids me to set APPROVED, and no other role is technically stopped from doing it | `scripts/agents-coordination/clinical-categories.mjs` `registerStatus` (reads the cell only); `CLINICAL_RULE_REGISTER.md` header ("Approves rules: … D-27"); G-1 (no Clinical Owner named) | **owner, eng:** once G-1 names the Clinical Owner, a change to a register row's Status needs that person's review (for example CODEOWNERS on `docs/agents/clinical/CLINICAL_RULE_REGISTER.md` with required review). Until then, `agents-check` also fails when an `APPROVED` row names no approval record (the approver's name, role and date, in a decision file). Unit test: an APPROVED row without an approval record fails; with one, it passes |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-64** | **closed**, IMPLEMENTED; CI green on `66e8d0a` | 0080:218-246 (`outside_settle`: a `pending` or `sent` outside delivery holds the immediate step only while `not private.access_ended(o.recipient_id)`, line 235); 0080:250-270 (`signal_step_outside_app`: same condition after the step, line 261, so the banner and the step read the same fact). pgTAP 080:133-221: the only `sent` delivery is to the leaver → escalated once at the next evaluation, every Operations user delivered once, `escalated_at` not moved by a second run; a colleague's `sent` delivery still holds signal 2; the banner agrees in both cases; 080:236-240: an Operations delivery to an ended Operations user no longer counts as reached |
| **CGR-63** | **closed**, IMPLEMENTED (option (a)); CI green on `66e8d0a` | 0080:62-101 (`access_seq` stamped by a BEFORE INSERT trigger for every writer; `signal_take_lapsed`: ended now, or an `ended` event with a higher sequence); readers `signal_taken_stops_step` (0080:106-117), `take_signal` (119-160), `my_signals` (163-209), `end_member_access` (212-216). pgTAP 078:171-196: restore before the step → her old take does not stop the step and still reads "Übernahme beendet"; SIG1-5 fires at the threshold; she takes again → the new take stops the step; both rows stay (append-only); a second end lapses the new take too; 080:255-259 stamp. Deviation 1 (event sequence instead of time) gives the same result and avoids the mixed clocks; supported. Pre-0080 rows are judged by time; only synthetic rows exist |
| **CGR-61** | **closed**, IMPLEMENTED; CI green on `66e8d0a`. Residual governance gap → **CGR-68** | 0080:516-521 (`check (class <> 'clinical' or approval_ref ~ '^CR-[0-9]{3}$')`); `clinical-categories.mjs` (every migration insert of a `clinical` category must name an `APPROVED` register row; an unreadable insert fails closed); the catalogue has no runtime writer (`authenticated` reads only, no update or delete, 0073:65-85). pgTAP 080:319-331 ("D-17", "pending", "#396" refused with 23514; an organisational row unchanged); unit `cond1-clinical-categories.test.ts` (APPROVED accepted, missing or unreadable refused, the repository's migrations pass). Card order unchanged (D-17 part 3, correct) |
| CGR-65 | open, advisory (S2); placed as WORK1-C4 in COND1-3; **built in #451 (open, not merged)**. PLANNED on `recovery/main` | see *COND1-3* below |
| CGR-60 | open, advisory (S3); FUP1-C1, COND1-4. PLANNED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-61, CGR-63, CGR-64**.

### COND1-2 checks (no finding beyond CGR-66)

- **DOOR1-12 (PS-50, S1): IMPLEMENTED and tested.** A BEFORE INSERT OR UPDATE OF `access_notes` trigger refuses a code from every writer, also from the table owner (0080:421-436). It checks only a note that is written or changed, so no stored row is rewritten. pgTAP 080:261-286: four digits and separators refused through the command and for the table owner; three digits accepted; an older row unchanged and still updatable; the G-11 count finds it. The intake form shows the DOOR1-4 help text; the server action names the refusal. **Residual (owner, G-11):** notes stored before 0080 are found only by the owner's read-only count before the first real import (`OWNER_RUNBOOK.md` §5b); that count must be 0 on the real-data project. `lca` 12:50 reads the same.
- **DOOR1-13 (PS-51, S2): IMPLEMENTED and tested.** One "Zugang" line: the latest value wins; without one, the intake note "aus der Aufnahme" with its date; with neither, "nicht erfasst" (`door/rules.ts` `accessLine`). The intake note is never copied into the value table and appears in the history as its earliest entry (0080:466-509). pgTAP 080:288-317: intake note only, intake note plus a team value, neither, no copy, and Operations and a leaver read nothing; e2e `door.spec`. The nurse at the door no longer chooses between two records.
- **No new rule, threshold, recipient or step.** 0080 changes who counts as reached or as holding a claim (organisational, evaluated on the access record), not any clinical value.

### COND1-3 (#451, open; read on its head `e46dc87`, not a gate result)

- **WORK1-C4 (CGR-65) as built matches my remedy.** The proposal takes the effective event time (latest F3 correction, else the recorded time) for the start, end, order and Zurich date of each segment. It uses the same lateral join as billing (0081 `working_day_proposal`; 0023:33-36). It marks `corrected` and adds no identifier. `/work` shows "Die Zeit im Einsatz bleibt unverändert …" with a link to the visit's time correction when a visit segment is changed. pgTAP 081:139-161: a corrected event moves the segment and its day, and the visit tables are unchanged (row fingerprint before and after). No write-back (`lca` 09:55: compliant).
- **WORK1-C1:** care is the union of care segments clipped to the day, minus breaks, with `care_le_paid` (NOT VALID on old synthetic rows). pgTAP 081:61-102. This supports reading the team ratio as a measure. It is still a process measure, to be read only beside the team's safety measures (my 09:26 section).
- I will close CGR-65 on the merge commit once CI is green. Nothing I read is blocking.

### Register rows

- **CR-117, CR-118 (eng): reviewed, stand as written.** Both are organisational (input class V) and set no threshold. CR-117 is the rule that closes CGR-63; CR-118 closes CGR-64.
- **Added:** CR-119 (DOOR1-12, the code guard on the intake note; note CGR-66), CR-120 (DOOR1-13, the one-line precedence), CR-121 (DOOR1-14, the clinical-category gate; note CGR-68), CR-122 (LEAVE1-C4, display of a leaver's OPS1 take and quality claim; note CGR-67). None is clinical. CR-103 and CR-105 get notes.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| COND1-1 + COND1-2 (merged `cb5e317`; COND1 `in-progress`) | **reviewed on the merge commit; no blocking finding.** PS-50 (S1) and PS-51 (S2) mitigated in code; CGR-61, CGR-63, CGR-64 closed. The clinical gate does not block the PO's later COND1 review | CGR-66, CGR-67, CGR-68 (advisory) |
| COND1-3 (#451, open) | read; consistent with CGR-65 and WORK1-C1; gate result on the merge commit | CGR-65 (open until merged) |
| WORK1 (accepted) | consistent; CGR-65 placed as WORK1-C4 | CGR-65 |
| LEAVE1, DOOR1 (accepted) | their conditions C2, C3, 12, 13, 14 are merged; C4 merged with CGR-67 | CGR-66, CGR-67 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) CGR-66: decide whether a phone number and a postal code may appear in the access note. Keep the guard until then. A key holder's reachability on the card is D-17 part 3. (2) CGR-67: the C3 rule for OPS1 takes and quality claims too, or a recorded reason for the difference. (3) When COND1 is reviewed: CGR-61, -63 and -64 are closed by this section; PS-50 still needs the owner's G-11 count before the first import.
- **eng:** #451 (resolve the conflict, CI); CGR-68 check once the owner decides how an approval is recorded; COND1-4 to -6 in order; #399, #409.
- **owner:** G-1 (name the Clinical Owner and a deputy; CGR-68 depends on it), D-1 (urgent); the G-11 count before the first real import; G-5; merge this PR if my own merge is refused.
- **clinical** (once named): D-17 part 3 (now also: does the nurse need the key holder's reachability on the card, CGR-66), D-30, D-19 part 1, D-28, D-10, D-16 as before.

---

## 2026-10-26 09:26 CET: WORK1 (0079, pgTAP 079) reviewed on its merge commit; CGR-65 (advisory, S2): the working-day proposal and the visit record can hold two different times for the same visit; billing isolation and no per-person ranking confirmed; the PO's segment-check hypothesis judged

**Scope:** `recovery/main` @ `e715436`. Changes since my 05:26 CET section (#431, merged):
- **Code merged:** #434 **WORK1** (0079, ADR-092, pgTAP 079 (68), unit `work-rules`, e2e `work.spec`, `/work` page, AN1 `pilot_kpis` team row, pgTAP 032 adjusted) as `a5c94a6`. **CI `app`, `db`, `e2e` green on `a5c94a6` and on `e715436`** (read through the GitHub API). Between them only docs changed.
- **Docs merged:** PO 06:10 (**LEAVE1 accepted**; CGR-64 placed as LEAVE1-C2, CGR-63 as LEAVE1-C3 option (a), step 6 display-only relations as LEAVE1-C4), 07:15 (WORK1 reviewed, awaiting clinical review; WORK1-C1), 08:15 (WORK1-C2, WORK1-C3, G-19 item (4)); `lca` 05:41 (D-12, D-14), 07:45 (D-23 item 14).
- **Open PRs:** #440 (PO, docs: **COND1** brief, all pre-pilot conditions under one hand-off), #435 (eng, docs: WORK1 `delivered`), #3 (owner, `main`). Issues #399, #409 still open. **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0079 in full, pgTAP 079 (catalogue, billing and team-ratio parts), `work-client.tsx` segment editing, the F3 table (0008) and the billing reader of effective event times (0023:28-40). **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-65 | WORK1 (0079) with F3 (0008) and billing (0022, 0023) | **advisory (S2)** | **The same visit can carry two different times, and nothing tells the nurse.** The proposal builds care and travel segments from the raw `visit_events.occurred_at`, while the clinical record and the billing basis use the *effective* time (latest F3 correction, else the recorded time). So (1) a nurse who corrected a visit time on the visit (F3, reasoned, authored) is shown the uncorrected time again at night and must correct it a second time; (2) a nurse who notices a wrong visit time while confirming her day corrects it **only** in her working day (reason `time_wrong`): the visit record, the signed report's time basis and the measured minutes stay wrong, because the working day never writes back (correctly, WORK1-7). Her exported record (employer) and the billed minutes (payer) then disagree for the same visit, without a trace on the visit. Bounded: synthetic data only until G-19; billing itself is unchanged and isolated. Hence S2 (before go-live), not S1. IMPLEMENTED as described; no clinical rule involved | 0079:196-209 (`occurred_at`, no join to `visit_time_corrections`; ordering also by raw time); ADR-092 deviation 3 (accepted "for now"); 0008 header (effective time = latest correction; "keine stillen Zeitkorrekturen", DOMAIN_RULES); 0023:33-36 and 0022:101 (billing reads `coalesce(corrected_at, occurred_at)`); `work-client.tsx:179-183` (segment times editable, no hint that the visit is unchanged) | **eng, po (product authority; no threshold, no clinical rule):** (1) the proposal uses the effective event time (the same lateral join as 0023:33-36) and marks corrected segments; (2) when she changes the start or end of a segment that came from a visit, `/work` states that the visit record keeps its time and points her to the time correction on that visit (F3); the working day still never writes to `visit_events` or `visit_time_corrections`. pgTAP: an event with an F3 correction → `my_working_day` returns the corrected instant; `confirm_working_day` leaves both visit tables unchanged (row fingerprint before/after). Unit or e2e: editing a visit segment shows the hint. May ride COND1-3 (WORK1-C1 touches the same command) |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-64 | open, advisory (S2); **placed by the PO as LEAVE1-C2** (06:10; includes `pending` and the banner's `signal_step_outside_app`), scheduled as COND1-1 (#440, open). PLANNED | `briefs/LEAVE1.md` *Conditions*; COND1 brief |
| CGR-63 | open, advisory (S3); **placed as LEAVE1-C3, option (a)** (a take counts only if recorded after the taker's latest access end). PLANNED. Option (a) is the safer of the two I offered: it adds no reading task | same |
| CGR-61 | open, advisory (S2); DOOR1-14, COND1-2. PLANNED | no change |
| CGR-60 | open, advisory (S3); FUP1-C1, COND1-4. PLANNED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: none.

### WORK1 checks asked for (no finding)

- **Working time never feeds billing (WORK1-7): IMPLEMENTED and tested.** Only 0079 and `src/features/work` name the working-day tables or helpers (text search over all migrations and `src`). pgTAP 079:268-278: the reader catalogue over all functions reading `working_day_versions`, `working_time_notice_acks`, `working_day_proposal` or `team_confirmed_care_share` is exactly her read models and commands plus `pilot_kpis`; no `billable|billing|invoice|payer` function reads `working_`. `generate_billable_facts` is not touched by 0079. Billing keeps its own time basis (0023), which is why CGR-65 matters.
- **No per-person ranking: IMPLEMENTED and tested.** `team_confirmed_care_share` groups by team only and is executable by no app role (0079:233-254; pgTAP 079:272-275); `pilot_kpis` shows value and base only from 3 people **and** 5 confirmed days (0079:617-624; pgTAP 079:291-314); the organisation row is a note, so a hidden team cannot be derived by difference. Tables readable only by the person (0079:94-111; pgTAP 079:251-263).
- **Documentation integrity: no regression.** The working day writes only `working_day_versions` and `working_time_notice_acks` (append-only, 0079:113-137); no visit, report, signal or quality table is written. A leaver confirms and reads nothing (pgTAP 079:320-329).
- **WORK1-C1 (PO condition): supported from a measure-validity view.** A North Star that can exceed 100 % is wrong in the direction the pilot hopes for, so it must hold before any ratio is read as evidence. I add one point for the same PR: with CGR-65 (1) the care segments come from the effective visit times, so the team ratio and the billed measured minutes rest on the same times.
- **What the ratio means (LT-3, G-5).** "Direkte Pflegezeit" here is visit time from start to completion, including documentation done during the visit. It is a process measure, not a care-quality or outcome measure. A rising share can also come from removing coordination, handover reading or report time, which protect the client. Before a team ratio is read as pilot evidence, the PO should show it next to the existing safety measures of the same team and month (uncovered and missed visits, untaken P1 signals, unsigned reports), never alone. Which outcome indicators belong there is **UNKNOWN, owner and Clinical Owner** (G-5).

### Clinical view on the PO's 07:15 hypothesis (drop nightly segment editing; care minutes from corrected events; not a decision)

Supported, because it moves every visit time correction to one place: the visit (F3), where it is reasoned, authored, visible to the team and read by billing and the record. That removes CGR-65 (2) by design. Two conditions from a safety view: (a) the nurse must still be able to correct her own past visit times through F3 after the day ends (as built in 0008 corrections are refused only in the future or out of order; any later time limit must keep this route open); (b) the day start, day end, breaks and work outside visits stay hers to confirm, since they are not in any visit record. The 5 % threshold is a product threshold, not a clinical one.

### Other changes reviewed (no finding)

- **COND1 (#440, open, docs).** COND1-1 carries CGR-64 (incl. `pending` and the banner path) and CGR-63 option (a) as I asked; COND1-2 carries CGR-61 as DOOR1-14. The brief adds no rule and keeps "stop and say so" for any missing clinical value. Consistent with my remedies.
- **LEAVE1 accepted (PO 06:10)** after my 05:26 section; consistent (no blocking finding was open).
- **`lca` D-23 item 14 and PO item 15** (audit log of confirmations named in the text; leaver's unexported-day count for administrators only): working-time privacy, no clinical content; no finding.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| WORK1 (merged `a5c94a6`; reviewed, awaiting clinical review) | **reviewed on the merge commit; no blocking finding. The clinical gate does not block acceptance**; CI green on `a5c94a6` and `e715436`. CGR-65 (S2) may be placed as a condition with WORK1-C1 (before G-19 and before any ratio is read as evidence) | CGR-65; WORK1-C1 to -C3 |
| LEAVE1 (accepted) | consistent; CGR-63, CGR-64 placed as LEAVE1-C3, -C2 | CGR-63, CGR-64 |
| COND1 (approved brief, #440 open) | consistent with my remedies | none |
| DOOR1, AUD1, FUP1 | unchanged | as before |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) WORK1 may be accepted: no blocking clinical finding; (2) place CGR-65 as a WORK1 condition, best inside COND1-3; (3) before a team ratio is read as pilot evidence, show it only beside the team's safety measures (above); (4) the four points of the 07:15 hypothesis view above, when that hypothesis becomes a brief.
- **eng:** COND1 in the PO's order (COND1-1 first, patient safety); CGR-65 with WORK1-C1; #399, #409.
- **owner:** G-1 (name the Clinical Owner and a deputy), D-1 (urgent); G-5 outcome indicators for the pilot; merge this PR if my own merge is refused.
- **clinical** (once named): D-30, D-17 part 3, D-19 part 1, D-28, D-10, D-16 as before.

---

## 2026-10-26 05:26 CET: LEAVE1-14 (0078, pgTAP 078) and AUD1 (0077) reviewed on their merge commits; CGR-62 closed; CGR-63 (advisory, S3) and CGR-64 (advisory, S2); the PO's D-30 (d) hypothesis judged

**Scope:** `recovery/main` @ `71147a5`. Changes since my 01:26 CET section (PR #416, CI green, not merged; carried into this PR by a merge commit, JOURNAL both sides kept; #416 is closed as superseded):
- **Code merged:** #413 **AUD1** (0077, ADR-090, pgTAP 077, pgTAP 005 and 076 adjusted) as `7f23a3b`; #425 **LEAVE1-14** (0078, ADR-091, pgTAP 078 (46), `SignalBanner.tsx`, `signals/rules.ts`, `admin` result text, unit `signals-rules`, `admin-rules`) as `71147a5`; #428 test helper only (`push-webpush.test.ts`: VAPID key padded to 32 bytes; no rule). **CI `app`, `db`, `e2e` green on `8eeb18e`, `7f23a3b` (AUD1) and on the #425 head `36921be` (LEAVE1-14)**; on the merge commit `71147a5` `db` and `e2e` were still running at my first read; **green on a second read before publishing** (`app`, `db`, `e2e`; one superseded run cancelled). Between `8eeb18e` and `7f23a3b` only docs and `ROADMAP.md` changed, no SQL.
- **Docs merged:** PO 02:14 (LEAVE1 `changes-requested`, LEAVE1-14), 03:13 (D-30 hypothesis row for `cra`), 04:10 (**AUD1 accepted**, AUD1-M1, AUD1-M2; **CGR-61 placed as DOOR1-14**), 05:10; `lca` 02:46, 03:42, 04:50 (D-30, D-3, D-4); `eng` 03:20, 04:45 (remediation plan `clinical/remediation/CGR-62.md`).
- **Open PRs:** #429 (docs, LEAVE1 delivered), #416 (mine, superseded), #3 (owner, `main`). Issues #399, #409 (clock-dependent tests) still open. **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0078 in full, pgTAP 078 in full, the banner and rule diffs, `outside_settle` (0062:496-530 as patched by 0063:207), `restore_member_access` (0074:386-433), and 0077 sections 1-3 with the pgTAP 005 change. **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-64 | LEAVE1-14 (0078) with SIG2 (0062) | **advisory (S2)** | **A push already `sent` to a person whose access then ends still counts as "somebody was reached outside the app"**, so SIG2's immediate step does not fire for a P1 signal outside the watched hours; Operations then hears of it only through SIG1-5 after the `signal_untaken` threshold (PROVISIONAL, D-28). Example: 22:40 a no-show push reaches the on-call nurse's phone; 22:45 her access is withdrawn because the phone was lost. Nobody who can act has been reached, yet the signal waits up to the threshold. Bounded by SIG1-5 (no signal is lost), so not S1. Engineering listed it itself as OPEN (remediation plan step 6) | 0062:511 (`not exists … result in ('pending','sent')` for any recipient); 0071:92-102 (`signal_step_outside_app`, the banner's `operations_outside_app`: a `sent` delivery to an Operations member counts the same way, also after her access ends); 0078:57-64 (only the take predicate checks `access_ended`); pgTAP 078 cycle 2 covers a take, not a `sent` delivery | **eng, po (product authority; no threshold, no clinical rule):** a `sent` outside delivery counts as reached only while its recipient's access is open (`not private.access_ended(o.recipient_id)`) in `outside_settle` and in `signal_step_outside_app`, evaluated live like CGR-62 (1). pgTAP: outside channel on, P1 no-show outside the watched hours, the only `sent` delivery is to a nurse; her access ends; next evaluation sets `outside_none_at` and `escalated_at` and delivers to Operations once; a `sent` delivery to a colleague with open access still holds the step |
| CGR-63 | LEAVE1-14 (0078) with LEAVE1-7 restore (0074) | **advisory (S3)** | **A restore silently revives a take made before the access end.** The predicate is evaluated live (ADR-091; I asked for this in the CGR-62 remedy myself), so after `restore_member_access` her old take stops the SIG1-5 step again and colleagues read "übernommen von <her>" again. But the restored person has no push subscription (deleted at the end, LEAVE1-7), the restore result names no signal, and nothing tells her she holds a P1 signal again. If the restore falls inside the threshold window, Operations is not reached and the team's list again sorts the signal below untaken ones. A restore that late is rare, and a signal already escalated stays escalated; hence S3. I correct my own remedy point: reviving was not the safe default | 0078:58-64 (live predicate), 0078:118 (`my_signals` prefers open access, an ended-then-restored take counts again); 0074:386-433 (`restore_member_access` returns `{result}` only); pgTAP 078:170-176 (restore before the step: the step does not fire; asserted as intended) | **eng, po (product authority):** either (a) a take counts only if it was recorded after the taker's latest access end (`t.taken_at > ` latest `member_access_events.kind = 'ended'` of the taker), so after a restore she takes it again if she still holds it; or (b) the restore result names the open signals whose take revives, and her `my_signals` shows them at the top until she takes them again. pgTAP for the chosen option, replacing 078:170-176 |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-62** | **closed**, IMPLEMENTED; CI green on the #425 head `36921be` (`app`, `db`, `e2e`); and on the merge commit `71147a5` | remedy (1): 0078:57-64 (`signal_taken_stops_step` counts only takes with `not private.access_ended(taker_id)`; read by SIG1-5 and SIG2's step); pgTAP 078:155-156 (her take no longer stops, a colleague's still does), 078:179-188 (after the threshold `escalated_at` set, delivered to every Operations receiver, once), 078:222-232 (SIG2's immediate step fires as for an untaken signal). Remedy (2): 0078:81-121 (`my_signals`: no name, time, qualification; sorted with untaken; `taker_access_ended`), `rules.ts` `TAKE_ENDED`, `splitSignals` puts it in the open list; pgTAP 078:159-168. Remedy (3): 0078:206-230 (`taken_signals` in result, change log, audit); pgTAP 078:147-153, 229. Takes append-only and the SIGC/AN2 measure unchanged: 078:191-197. A colleague can take it after the lapse and "already taken" names her: 078:200-202. Claim inventory (brief point 5): ABS1 return, PLAN2 responsible member, `set_primary_nurse`, `plan_visit` refuse or skip her (0078:247-284; pgTAP 078:235-261). Residuals: CGR-63, CGR-64 |
| **CGR-61** | open, advisory (S2); **placed by the PO as DOOR1-14** (04:10). PLANNED | NEXT_CAPABILITY rank 32 |
| CGR-60 | open, advisory (S3); FUP1-C1. PLANNED | no change |
| CGR-54, CGR-56 | open, advisory (S3, S2); DST1-C4, DST1-C5. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-62.**

### Other changes reviewed (no finding)

- **LEAVE1-14 claim inventory, display-only relations (remediation plan step 6, OPEN).** An OPS1 exception "take" and a quality event owner still show the leaver's name. Neither stops a step (the P2 → P1 clock runs on, CGR-05/-06 as built), so no finding; I support Engineering's recommendation that they read as untaken in the same way, in one later PR, before go-live (S3). A reopened case whose primary nurse has left keeps her name, and PLAN2 skips her (pgTAP 078:245-261), so its visits are uncovered and J3, OPS1 and SIG1 apply: protective.
- **LEAVE1-14 banner text** "Übernahme beendet – Zugang beendet": fixed text, no reason code (LEAVE1-8). The signal goes back to the open list for everyone, so a registered nurse can take it.
- **AUD1 (0077) on `7f23a3b`: no clinical finding.** Free text (`quality_holds.reason`, `lift_reason`) reaches only an administrator who is an active member of the record's team; unknown keys fail closed; no per-member aggregate; each read is logged. The derived readers (HAND1 handover, J6 last primary nurse, CSR1 order as of, AN2) run as the table owner and are unchanged, so no clinical display loses data (0077 header point 1; pgTAP 005 now reads through the purpose reader). AUD1-M1 (purpose `billing` returns codes only, also inside the team) is privacy-protective and costs nothing clinically: billing needs that a hold exists, which J5 already reads. My 17:26 note stands: a `safety_review` of a hold by someone outside the team returns codes only, so before the first real client a safety review needs the Clinical Owner's task-bound read (G-1, D-16), or the review stays inside the team.
- **#428** fixes a test helper (31-byte keys about 1 in 256); no rule changed. The same class as #399 and #409: fix, never skip.

### Clinical view on the PO's D-30 (d) hypothesis (NEXT_CAPABILITY challenge row, 03:13; not a decision)

The idea (the return reason is also shown to the team's registered nurses on the client's next planned visit until one records "gesehen") moves knowledge about the client's care from a document to the client, which is the right direction for patient safety. Before a brief, from a safety view:
1. **The next visit may be performed by a care assistant** (A/C work). An RN-only display then reaches nobody at the door. Whether, and what, a care assistant must be told when a return names an error is **UNKNOWN, Clinical Owner** (D-30 (d), D-10). A neutral marker without content ("Hinweis für Pflegefachperson offen – Rücksprache") keeps the free text RN-only (F6R, RLS2) and is product design, not a clinical rule.
2. **"Gesehen" is an acknowledgement, not a follow-up.** It must not read as "handled"; what follow-up is required (check the care plan, inform the doctor) and by when is **UNKNOWN, Clinical Owner** (D-30 (d), D-16).
3. **The measure** (returns naming an error where the next visit took place before any other RN read the reason; target 0) is sound and can be computed from events once the display exists.
4. **Do not let the hypothesis delay D-30.** Until the Clinical Owner answers, the D-12 partnership term (the licence holder's own follow-up process) is the interim control.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| LEAVE1 (merged incl. LEAVE1-14 `71147a5`; `changes-requested`) | **CGR-62 closed; no blocking finding.** The clinical gate no longer blocks acceptance; CI green on `71147a5`. CGR-63 (S3) and CGR-64 (S2) may be placed as conditions | CGR-63, CGR-64; LEAVE1-C1 |
| AUD1 (accepted) | reviewed on the merge commit; no clinical finding; acceptance consistent | none (note: G-1, D-16) |
| DOOR1 (accepted) | CGR-61 placed as DOOR1-14; DOOR1-12 (S1), -13 (S2), -14 (S2) PLANNED | CGR-61 |
| WORK1 (approved) | not built; I will check on delivery that it never feeds billing or a per-person ranking | none |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) the clinical gate no longer blocks accepting LEAVE1 (CI green on `71147a5`); G-13 then no longer waits on CGR-62; (2) place CGR-64 (S2) and CGR-63 (S3) as LEAVE1 conditions, with the step 6 display-only relations; (3) take the four points above into the D-30 (d) hypothesis before any brief.
- **eng:** DOOR1-12/-13/-14, FUP1-C1 with CGR-60, CGR-64 (small: one predicate in two places, pgTAP), #399, #409; then WORK1 in the PO's order.
- **owner:** G-1 (name the Clinical Owner and a deputy), D-1 (urgent); merge this PR if my own merge is refused.
- **clinical** (once named): D-30 (routes, what an addendum may state, follow-up of a returned error and who is told, time limit), D-17 part 3, D-19 part 1, D-28, D-10, D-16 as before.

---

## 2026-10-26 01:26 CET: LEAVE1 (0074, 0075, 0076) reviewed on its merge commits; CGR-49, CGR-50 closed; CGR-62 (blocking, S1): a leaver's take keeps a P1 safety signal from escalating; AUD1 (#413, open) read; clinical view on D-30 point (c)

**Scope:** `recovery/main` @ `d4eae0b`. Changes since my 21:28 CET section (PR #401, green, not merged; carried into this PR by a merge commit, JOURNAL both sides kept):
- **Code merged:** #400 **LEAVE1 part (a)** (0074, ADR-087, pgTAP 074) as `e74fccc`; #406 **LEAVE1 part (b)** (0075, 0076, ADR-088, ADR-089, pgTAP 075, 076, `tests/e2e/leave.spec.ts`, unit `admin-rules`, `auth`, `field-report`, `handover-rules`; e2e `field.spec` fixed to Zurich calendar days) as `645e3af`. **CI `app`, `db`, `e2e` green on `e74fccc`, `645e3af`, `cb5f08f` and `d4eae0b`** (check runs read through the API).
- **Docs merged:** PO 22:10, 23:11 (LEAVE1-13 added; LEAVE1-C1), 00:20 (LEAVE1 reviewed, "awaiting clinical review"; WORK1 approved; D-30 point (c)), 01:10; `lca` 21:50, 22:40, 00:50 (D-17, D-19, D-9, D-30, D-10); `eng` 21:50-23:45.
- **Open PRs:** #413 **AUD1** (0077, ADR-090, pgTAP 077; head `8eeb18e`, CI green, not delivered), #401 (mine, superseded by this PR), #3 (owner, `main`). Issues #399 (pgTAP 062 clock) and #409 (field.spec clock) still open. **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0074, 0075 (return, countersignature, correction, open-report helpers, lists) and 0076 in full; the signal, push and catalogue assertions of pgTAP 074 (245-262), the LEAVE1-11 and LEAVE1-12 blocks of pgTAP 075, pgTAP 076; and, to check what a leaver leaves behind, the SIG1 take path (0063:121-209, `my_signals` 0071:140-152) and the untaken step (0060:298-313 as patched by 0063:198-209). 0077 read on the PR branch. **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-62 | LEAVE1 (0074, 0076): `end_member_access` and an open safety signal she has taken | **blocking (S1)** | **A take by a person whose access has ended keeps stopping the step to Operations, and the team reads the signal as handled.** `private.signal_taken_stops_step` is true when any take with `stops_escalation` exists; it never asks whether the taker can still act. The SIG1-5 step (untaken after the threshold → Operations) and SIG2's immediate step outside the watched hours both read it. LEAVE1 removes her from every receiver set and refuses her every command, but leaves her take in force. `my_signals` then shows every team member "übernommen von <her name>" and sorts the signal **below** untaken ones. Example: 09:50 a registered nurse takes a P1 "Klientin öffnet nicht"; 10:05 the administrator withdraws her access (`access_withdrawn`, e.g. a lost phone or an incident). She can record nothing, Operations never receives the signal, and colleagues see it as taken. A client who does not open the door is then followed up by nobody in NAVORA until the cause ends. The refusals of LEAVE1-2 protect a visit in progress, not a signal she holds. No test covers a take by a leaver | 0063:184-188 (`signal_taken_stops_step`: any stopping take), 0063:198-209 (both steps read it); 0071:140-152 (`my_signals`: taker's name, `order by (taker_id is null or not stops_escalation) desc`); 0074:174-197, 227-230 (receivers and `my_signals` only for her); 0076:68-84 (refusals: cases, visit in progress, covered visit; no signal check); pgTAP 074:249-262 (no case with a take) | **eng, po (product authority; no threshold, no clinical rule; reuses the SIG1-5 and SIG2 steps as built):** (1) a take whose taker's access has ended no longer stops the step: `signal_taken_stops_step` (and therefore SIG1-5 and SIG2-5) counts only takes with `not private.access_ended(taker_id)`; (2) `my_signals` treats such a take as untaken (sort and text: "Übernahme beendet – Zugang beendet", or no taker shown), so the team sees it as open again; (3) the `end_member_access` result names the number of open signals she had taken. Takes stay append-only; the SIGC response measures keep the historical take. pgTAP: RN takes a P1 no-show (step stopped); her access ends; after the `signal_untaken` threshold since the signal's start `evaluate_signals` delivers to Operations once and sets `escalated_at`; a team colleague's `my_signals` lists it as untaken; outside the watched hours SIG2's immediate step fires; a restore before the step makes her take count again; a take by a colleague with open access still stops the step |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-49** | **closed**, IMPLEMENTED; CI green on `645e3af` | 0075:114-190 (`return_report`: `unavl := access_ended or not user_in_team`; return row with `performer_unavailable`, no draft); 0075:90-93 (guard: such a version never signed → final), 0075:199-245 (`countersign_report` refuses `returned_performer_unavailable`); pgTAP 075:168-203 (access ended: return accepted, no draft, countersignature refused, guard refuses as table owner, not billable), 075:225-236 (the same after a team removal), 075:239 (no returned version final), 075:184-192 (`i_can_return`, `i_can_countersign` agree), 075:243-261 (restored and in the team: next return opens the F6R draft) |
| **CGR-50** | **closed**, IMPLEMENTED; CI green on `645e3af` | 0075:314-336 (`open_reports_of`: unsigned incl. a completed visit with no report at all, correction draft, returned), 0075:356-406 (`member_open_reports`, `team_open_reports`: kind, date, team; admin and the report team's RNs only), 0076:112 (counts in the result); pgTAP 075:132-156 (3 by kind, 2 after one signature, others see nothing, counts in the result), 075:211-222 (HAND1 marker for a care assistant, no return reason) |
| **CGR-61** | open, advisory (S2); not yet placed by the PO (21:28 section was in unmerged #401) | no change |
| CGR-60 | open, advisory (S3); with FUP1-C1 (PO). PLANNED | no change |
| CGR-54 | open, advisory (S3); DST1-C4. PLANNED | no change |
| CGR-56 | open, advisory (S2); DST1-C5, before gate B. PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change; LEAVE1 keeps the refusal `has_planned_visits` for a visit she covers, so a leaver never leaves a cover behind (0076:80-84, pgTAP 076:86-88) |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-49, CGR-50.**

### Other changes reviewed (no finding)

- **LEAVE1-13 (0076) reuses the reviewed release rule.** Her planned visits from today go to the team through `private.release_member_visits` (as removal and ABS1: CR-035, CGR-09, CGR-10, CGR-34, CGR-35); they become uncovered, so J3, OPS1 `visit_uncovered` and SIG1 apply unchanged; past and in-progress visits are not touched (pgTAP 076:95-121). This is better than the part (a) refusal: an administrator no longer has to re-assign visits one by one while the clock runs. A visit she covers still refuses. No threshold changed.
- **LEAVE1-2 refusals are the right ones clinically:** primary or deputy nurse of an open case (the case would lose its named nurse), a visit on the way, started or paused (somebody must close it through the existing path). Her open reports do not refuse (only she could clear them), and LEAVE1-12 lists them before and in the result.
- **LEAVE1-3 reads and commands.** A restrictive policy on every readable table, the membership helpers, a guard in every SECURITY DEFINER set-returning read model and in every command, catalogue loops in pgTAP 074 so a new object fails the test. Privacy-protective; nothing clinical is lost because her history stays (074:266-279). The Operations fallback to administrators skips an ended Operations user (0074:174-184, pgTAP 074:259-260): protective.
- **LEAVE1-11 behaviour (CGR-49 remedy).** A known-wrong version is never pushed into `final` or billing, and stays readable with its marker. Residual (not a finding, D-30): the reason for the return is RN-only (F6R), so a care assistant who reads the visit sees "Zurückgegeben – Autorin nicht mehr verfügbar" but not what is wrong. Whether the next visit or the care plan must be checked when a return names a clinical error is part of D-30 point (c) below (Clinical Owner).
- **The "unsigned" kind** includes a completed visit she performed with no report at all (0075:329-335): protective; such a visit is now visible to the team as open documentation.
- **LEAVE1-C1** (an end applies to every organisation of the person): privacy first, nothing clinical lost; agreed as a condition.
- **AUD1 (#413, open, CI green on `8eeb18e`, not delivered): no clinical finding on the branch.** The purpose reader withholds free text (`quality_holds.reason`, `lift_reason`) from an administrator outside the team, also for `safety_review`, and fails closed on unknown keys. My 17:26 note stands: before the first real client, a safety review of a quality hold by someone outside the team needs the Clinical Owner's task-bound read (G-1, D-16), or the review stays inside the team. The pgTAP 076 clock pin in #413 (076 failed between 00:00 and 09:00 Zurich) is a test fix, not a rule change; the same class as #399 and #409: each clock-dependent safety test must be pinned, never skipped. I will review 0077 on its merge commit.

### Clinical view on D-30 point (c) (PO 00:20 request; not a decision; the Clinical Owner and `legal` decide)

Who completes a version returned while its performer is unavailable. From documentation integrity and patient safety, any route the Clinical Owner chooses should keep these properties (all testable; none sets a clinical rule):
1. The returned version stays readable and unchanged, with its marker (built, 0075). Nothing is written in the performer's name.
2. A completion by someone else is her own dated entry (addendum) with her name and qualification, linked to the returned version; it does not replace the performer's observations. **What a registered nurse may state in it** (only what she observed herself, for example at a follow-up visit, or also what she reconstructs) is **UNKNOWN, Clinical Owner.**
3. If nobody can verify the content, the version stays not final and not billable; whether it may ever be billed is D-18 / D-22 (`legal`).
4. Patient safety must not wait for the documentation route: when a return names a clinically relevant error, whether the returning RN must check the next visit, the care plan or inform the treating doctor is **UNKNOWN, Clinical Owner** (D-30 with D-16).
5. A restored author's late completion carries its own date and shows the absence; its time limit is **UNKNOWN, Clinical Owner and `legal`.** I support the PO requirement that route 3 is never the only route.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| LEAVE1 (merged `e74fccc`, `645e3af`; reviewed by the PO, not accepted) | **blocking finding CGR-62 (S1): the PO does not accept LEAVE1 until CGR-62 is fixed with its pgTAP** (or sets `changes-requested`). CGR-49, CGR-50 closed | CGR-62; condition LEAVE1-C1 (PO) |
| AUD1 (#413, open) | read on the branch; no clinical finding; review on merge | none |
| DOOR1 (accepted) | unchanged from my 21:28 section (now merged with this PR) | CGR-61 (S2); DOOR1-12 (S1), DOOR1-13 (S2) |
| FUP1 (accepted) | unchanged | CGR-60 (S3) with FUP1-C1 |
| WORK1 (brief, approved) | not built; working time, no clinical rule; I will check on delivery that it never feeds billing or a per-person ranking | none |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) LEAVE1 stays not accepted until CGR-62 is merged with its pgTAP; G-13 ("no real client before LEAVE1 is accepted") therefore also waits on CGR-62; (2) place CGR-61 (21:28 section); (3) take the D-30 point (c) properties above into the D-30 ask.
- **eng:** CGR-62 first (small: one predicate, one read-model sort, one result field, pgTAP); then AUD1, DOOR1-12/-13, FUP1-C1 with CGR-60, #399, #409.
- **owner:** G-1 (name the Clinical Owner and a deputy), D-1 (urgent); merge this PR if my own merge is refused.
- **clinical** (once named): D-30 (routes, what an addendum may state, safety follow-up of a returned error, time limit), D-17 part 3, D-19 part 1, D-28, D-10, D-16 as before.

---

## 2026-10-25 21:28 CET: DOOR1 (0072, 0073) reviewed on its merge commits; CGR-51 closed; CGR-61 (advisory, S2); DOOR1-12 and DOOR1-13 supported as S1 and S2 conditions

**Scope:** `recovery/main` @ `14b9320`. Changes since the 17:26 CET section:
- **Code merged:** #391 **DOOR1 part (a)** (0072, ADR-085, pgTAP 072, plan 53) as `f9f44b5`; #396 **DOOR1 part (b)** (0073, ADR-086, pgTAP 073, plan 68, `src/features/door/*`, `SafetyAlertForm.tsx`, unit `door1-rules`, `door1-alerts`, e2e `door.spec`) as `f069cc8`. **CI `app`, `db`, `e2e` green on `f9f44b5`, `f069cc8`, `38e7381` and `14b9320`** (check runs read through the API).
- **Docs merged:** `lca` 19:39 (D-3 gate (iv) F-1 met); PO 20:10 (DOOR1-12, DOOR1-13 added) and 21:10 (DOOR1 accepted with DOOR1-12, DOOR1-13 as conditions; challenge rows); `eng` 19:15-20:50 journal entries.
- **Open PRs:** only #3 (owner, `main`). Issue #399 (pgTAP 062 clock-dependent failure, `eng`). **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0072 and 0073 in full, the DOOR1-11 assertions of pgTAP 072 (150-155, 197-216), the DOOR1-2 assertions of pgTAP 073 (114-157), `src/features/door/rules.ts` (code pattern, line 29) against `private.looks_like_code` (0073:174-177), and the exception types of `team_visit_alerts` (0047:94-105) to check that the team keeps every note it had. **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-61 | DOOR1-2 (0073): the gate for a future clinical safety-alert category | advisory (S2; before the first clinical category, and in any case before go-live) | **The only barrier to a clinical category is that `approval_ref` is non-empty text (3-200 characters).** Any string passes: "D-17", "pending", a PR number. Nothing ties it to a named, qualified Clinical Owner's approval (D-27) or to a Clinical Rule Register row. A later migration could therefore ship "Allergie" or "Sturzrisiko" with `approval_ref = 'D-17'` while D-17 part 3 is still OPEN, and the check would pass. Second, the order of the card is fixed in code: `order by c.class desc` (0073:106, 283) puts every clinical category after the organisational ones. Whether an allergy or infection precaution must be shown first, or more prominently, is part of the D-17 part 3 form decision and belongs to the Clinical Owner, not to an alphabetical sort. Today no clinical category exists (pgTAP 073:114-129), so nothing is wrong on synthetic data; this is about the next migration | 0073:49, 54-56 (`approval_ref` free text; check `class <> 'clinical' or approval_ref is not null`); 0073:106, 283 (order); pgTAP 073:120-123 (only "null is refused" is tested) | **eng, po; no clinical rule:** (1) a clinical row's `approval_ref` must name a Clinical Rule Register ID (`^CR-[0-9]{3}$`, check constraint); `node scripts/agents-check.mjs` fails when a migration inserts a `clinical` category whose `approval_ref` row is not `APPROVED` with a named approver (D-27). pgTAP: `approval_ref = 'D-17'` refused, `'CR-123'` accepted by the constraint. (2) The display order of clinical against organisational categories is left to the D-17 part 3 decision: until then, a comment at 0073:106 says the order is PROVISIONAL (CR-104), and the brief of the first clinical category states it |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-51** | **closed**, IMPLEMENTED; CI green on `f9f44b5` | 0072:237-266 (`private.no_show_ops_detail`: date, time, "an der Tür: ja/nein/nicht erfasst", "Ergebnis offen" or outcome code with basis and time, "Notiz im Team"; no note); 0072:272-279 (`derived_exceptions`: the 120-character no-show excerpt and the 200-character interruption excerpt removed at the source); 0072:282-301 (the team's own list keeps the interruption note). pgTAP 072:150-155 (open no-show: door fact, "Ergebnis offen", no note), 197-202 (outcome with basis), 210-212 (interruption: reason code, no note text), 213-215 (team keeps its note). The no-show line was never in `team_visit_alerts` (its types are overdue, stuck, interrupted, report correction, uncovered: 0047:94-105), so the team loses nothing. Confirmed independently by `lca` 19:39 (F-1) |
| CGR-60 | open, advisory (S3); with FUP1-C1 (PO). PLANNED | no change |
| CGR-54 | open, advisory (S3); DST1-C4 (PO). PLANNED | no change |
| CGR-56 | open, advisory (S2); DST1-C5 (PO), before gate B. PLANNED | no change |
| CGR-49, CGR-50 | open, advisory; LEAVE1-11, LEAVE1-12 (LEAVE1 active, #337). PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change; see the covering-member note below |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-51.**

### Other changes reviewed (no finding)

- **DOOR1 adds no clinical rule.** One organisational category (access arrangement), no clinical category, no protocol step, no waiting time, no signal, no readiness or planning change (pgTAP 073 DOOR1-8 block; pgTAP 072: "an der Tür: nein" still P1, the exception still closes only with an outcome). New rows CR-100 to CR-105, all input class V or N, display or refuse only. **H-03 is partly mitigated** (access and language notes on the card, structured access arrangement with "unbekannt" distinct from "nein", who, when, source); allergies, fall risk, infection precautions and the emergency contact stay **OPEN** with the Clinical Owner (D-17 part 3) and D-9.
- **DOOR1-5 "an der Tür".** A no-show with "nein" (only a phone attempt) is now distinguishable from one where the nurse stood at the door, for the team, HAND1 and Operations. This is a fact, not a protocol: whether "nein" needs a different next step (for example going to the door before the outcome is recorded) is D-19 part 1, **UNKNOWN**, Clinical Owner. Nothing in code suggests a step; correct.
- **DOOR1-6 basis.** Recording the basis of a disclosure to the emergency contact is a privacy control (`lca` 22:50), not a clinical rule. `other` relies on the note to say which basis; the note is required (3-1000) but its content is not checked. Acceptable: the code records, `legal` judges.
- **Operations without the note (DOOR1-11).** This was my own remedy for CGR-51. The residual is deliberate: on an open P1 no-show, Operations reads "an der Tür: ja · Ergebnis offen · Notiz im Team" and must call the team for the content. Who acts, and when, stays D-19 part 1.
- **DOOR1-12 (code in the intake note) supported, S1.** Since 0072 the intake note `cases.access_notes` is shown on every team member's phone (0072:306-317) and only the category note refuses a code (0073:174-196). A key-safe code on a phone is a physical-safety risk for a client who often cannot defend herself, not only a privacy issue. The PO made it a condition before the first real client: that is the right gate. New PS-50 (S1).
- **DOOR1-13 (two access lines) supported, S2.** Today the card can show the intake note "Schlüssel bei der Nachbarin" next to a later team value "nein". A nurse at the door who has to decide which is current loses time, and on a no-show visit time matters. New PS-51 (S2).
- **Covering member reads, cannot record (PO deviation 3).** Agreed while COVER1 is off. Before COVER1 is switched on the covering nurse is the one who finds that the key has moved; if she cannot record it, the next visitor arrives with the old arrangement. I attach this to the cover conditions already open (CGR-21, CGR-28, PS-12): S2 if cover is enabled.
- **Intake records, cannot read back (PO deviation 2).** The source field is self-declared: an intake administrator could pick `team`. The card shows the recorder's kind ("coordination"), so the provenance stays visible. No finding.
- **Issue #399 (pgTAP 062, SIG1 safety-signal delivery, clock-dependent).** A safety-signal test that fails on some clocks hides real regressions as "flakes". It must be root-caused and pinned to the test clock, never skipped (PO already said so). I will review the fix when it is merged.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| DOOR1 (merged `f9f44b5`, `f069cc8`; accepted 21:10) | **no blocking finding; acceptance consistent.** CGR-51 closed | CGR-61 (S2, before the first clinical category); conditions DOOR1-12 (S1, PS-50) and DOOR1-13 (S2, PS-51) before the first real client |
| FUP1 (accepted) | unchanged | CGR-60 (S3) with FUP1-C1 |
| LEAVE1 (active), AUD1 (brief) | not delivered | CGR-49/50; AUD1 note of 17:26 stands |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) take CGR-61 into the brief of the first clinical category, or as a DOOR1 condition (no clinical rule; it narrows what the check accepts); (2) keep DOOR1-12 before the first real client (S1); (3) add "covering member can record the access arrangement" to the COVER1 switch-on list with CGR-21 and CGR-28.
- **eng:** DOOR1-12 and DOOR1-13 in one PR; CGR-61 (constraint, pgTAP, agents-check rule) when the PO places it; #399 root cause; CGR-60 with FUP1-C1.
- **owner:** G-1 (name the Clinical Owner and a deputy), D-1 (urgent); merge this PR if my own merge is refused.
- **clinical** (once named): D-17 part 3 (clinical categories, their order and prominence on the card), D-19 part 1 (no-show protocol, including what "an der Tür: nein" requires), D-28, D-30, D-10, D-16 as before.

---

## 2026-10-25 17:26 CET: RLS3 (0070) and FUP1 (0071) reviewed on their merge commits; CGR-55, CGR-57, CGR-58, CGR-59 closed; CGR-60 (advisory, S3); AUD1 brief read

**Scope:** `recovery/main` @ `1eee5d6`. Changes since the 13:26 CET section (#374, merged as `21d1e99`):
- **Code merged:** #373 **RLS3** (0070, ADR-083, pgTAP 071) as `3d6e125`. The code is identical to the head I read at 13:26 (`cb79d77`; `git diff cb79d77 3d6e125 -- supabase src tests` is empty). #383 **FUP1** (0071, ADR-084, pgTAP 069 +21 and 071 +7 assertions, `rules.ts`, unit `signals-rules`) as `5fbda91`. **CI `app`, `db`, `e2e` green on `3d6e125`, `5fbda91` and `1eee5d6`** (checked through the API: runs 939/940, 952/953, 960/961).
- **Docs merged:** PO 14:13 CET (SIGC and DST1 accepted, FUP1 approved), PO 16:11 CET (RLS3 accepted, AUD1 approved); `lca` 14:45, 15:41, 16:41 CET (D-3, D-4, D-23); `eng` remediation plans `CGR-57.md`, `CGR-58.md`, `CGR-59.md`.
- **Open PRs:** #386 (PO 17:11 CET: FUP1 reviewed, "awaiting `cra` on 0071"; Q16 decided as FUP1-C1), #3 (owner, `main`). **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0071 in full, the FUP1 assertions of pgTAP 069 (350-466) and 071 (323-354), the `rules.ts` change and its unit test, the SIG1 untaken step (0060:298-313) and the SIG2 outside classification (0062:466-490, 0064:109-114) it predicts, and the 0040 lock that `in_billed_version` relies on. **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-60 | FUP1-2 (0071): `private.signal_step_outside_app` before the step to Operations is made | advisory (S3) | **Before the step is made, the flag predicts only the watched period, not whether anybody in Operations can be reached outside the app.** Once the step is made the flag follows the real delivery (correct). Before it, it returns `watched_inside(org, due instant)`. The real classification at the step also needs the organisation's push channel on (`organization_push_settings.enabled`, rows only after `enabled_since`) and an Operations member with an active subscription (`push_active`); without either, the step reaches Operations in the app only. So with the channel off, or no Operations member opted in, a care assistant who takes a P1 no-show inside the watched hours reads "Meldung an Operations folgt" until the step is made. She may then wait for Operations instead of calling the registered nurse herself. Same class as CGR-58; the FUP1 outcome ("the banner never promises a push that will not happen") is not fully met. Distinct from the evaluator-interval residual the PO decided as FUP1-C1 (Q16) | 0071:92-110 (`else coalesce(... watched_inside ...)`); 0062:466-490 (`push_active`, `organization_push_settings ... enabled`, `enabled_since`); 0064:109-114; pgTAP 069:420-446 (fixtures all with an Operations member, no case with the channel off before the step) | **eng (with FUP1-C1, same function), po; display only, input class V, no threshold:** in the not-made branch, also require the organisation's channel to be on and at least one Operations recipient of the step (`signal_operations_users`) with `push_active`. pgTAP: watched until 21:00, step due 20:05; channel off → false; channel on, no Operations member with an active subscription → false; channel on and one active → true |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-55** | **closed**, IMPLEMENTED; CI green on `3d6e125` | 0070:83-148 (`visit_correction_history`, levels (a) and (b)); pgTAP 071:268-311 (countersigner and author see corrector and reason; covering author keeps her trail; admin, coach, Operations see values without reason or corrector; other team, other organisation, outsider: nothing). Billing residual closed as CGR-59 below |
| **CGR-57** | **closed**, IMPLEMENTED; CI green on `5fbda91` | 0071:37-49 (`visit_wall_range(care_visits)` takes the length from `private.visit_interval`, never shorter than either wall reading), 0071:56-73, 83 (the one-minute helper dropped); pgTAP 069:363-384 (19:50 + 45 min → listed; 19:50 no minutes → listed; 08:00 + 20 → not; 19:30 + 20 → not; end = start → listed; 06:50 stays listed; end 20:35; same end as `visit_interval`; helper gone) |
| **CGR-58** | **closed**, IMPLEMENTED (both branches of the remedy); residuals FUP1-C1 (PO, Q16) and CGR-60 | 0071:92-110, 144; `rules.ts:97-100` (`operationsFollows`: only `true` promises; a reader without the field falls back to `watched_now`), 113; pgTAP 069:420-466 (19:55 take, due 20:05, watched until 20:00 → app only; until 21:00 → true; overdue unmade step after the period → app only; delivery `sent` → true after the period; `outside_working_time` → false; no outside row → false; reader both ways); unit `signals-rules.test.ts:89-107` |
| **CGR-59** | **closed**, IMPLEMENTED; CI green on `5fbda91` | 0071:198-223 (`billed_at` = countersignature time, or signature time when none is required, of the version the current fact rests on; `in_billed_version = created_at <= billed_at`, null without a fact); pgTAP 071:323-354 (before → true; after → false; level (a) the same; level (b) still no reason or corrector; no fact → null; no countersignature required → signature decides; one flag per correction). Correctness rests on the 0040 lock (no time correction while the latest version is `signed` or `final`, 0040:24-31, 83), so comparing with the countersignature or the signature gives the same answer for real data |
| CGR-54 | open, advisory (S3); DST1-C4 (PO), due before 2027-10-31 or the first real client. PLANNED | no change |
| CGR-56 | open, advisory (S2); DST1-C5 (PO), before gate B. PLANNED | no change |
| CGR-49, CGR-50 | open, advisory; LEAVE1-11, LEAVE1-12. PLANNED | no change |
| CGR-51 | open, advisory; DOOR1-11. PLANNED | no change; F-1 stays open in `READ_PATHS.md` (FUP1-5 header) |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-55, CGR-57, CGR-58, CGR-59.**

### Other changes reviewed (no finding)

- **FUP1-1 is protective.** A visit without an end is now as long in the outside-hours list as in ABS1; on a clock-change night the longer of the two wall readings is taken. No threshold, watched period or rule changed. SIG1-8 stays a go-live condition (Clinical Owner).
- **FUP1-2 after the step** follows the delivery's own result (`pending`/`sent` → message; `outside_working_time`, `not_active`, `failed`, no row, no Operations member → app only). The step's due instant uses `after_threshold(s.created_at, …)`, the same base as the SIG1-5 step (0060:305) and the AN2 measures (0068:88-90). Under-promising cases (the SIG2 early step for `outside_none` happens before the predicted instant) are safe.
- **FUP1-3 states a fact, decides nothing:** what invoicing does with `in_billed_version = false` stays D-18 and the invoice brief (out of scope, as the brief says). Level (b) still returns neither corrector nor reason, and nothing counts per person (D-23 term b).
- **Q16 / FUP1-C1 (PO 17:11, #386):** no promise in the last evaluator interval of a watched period. Protective, agreed; CGR-60 belongs in the same PR.
- **AUD1 (brief, approved; PLANNED):** removes the administrators' standing read of `audit_events` and gives a purpose reader (`compliance`, `billing`, `safety_review`) that withholds team free text such as `quality_holds.reason` from an administrator outside the team. Clinical view: protective for confidentiality. It means a safety review of a quality hold by somebody outside the team cannot read the reason until the Clinical Owner is named and given a task-bound read (brief *Out of scope*; G-1, D-16). Acceptable on synthetic data; before the first real client the Clinical Owner's read must exist or the safety review stays inside the team. I will review the migration when it is delivered.
- **RLS3 accepted by the PO (16:11):** consistent with my 13:26 gate ("no blocking finding; CGR-59 decided by the PO", now closed).

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| RLS3 (merged `3d6e125`, accepted) | **no blocking finding**; CGR-55 closed | none open |
| FUP1 (merged `5fbda91`, `delivered`) | **no blocking finding; the PO may accept FUP1.** CGR-57, CGR-58, CGR-59 closed | CGR-60 (S3) as a condition, with FUP1-C1 |
| SIGC (accepted 14:13) | conditions CGR-57 and CGR-58 now met | CGR-60 (S3) |
| AUD1 (brief) | not built; clinical note above | none |
| DOOR1, LEAVE1 (briefs) | unchanged | CGR-51; CGR-49/50 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) accept FUP1 with CGR-60 as a condition; (2) put CGR-60 into the FUP1-C1 PR (same function, same pgTAP file).
- **eng:** CGR-60 with FUP1-C1; DST1-C4, DST1-C5 by their deadlines; AUD1 as approved.
- **owner:** as before: G-1 (name the Clinical Owner and a deputy), D-1 (urgent); merge this PR if my own merge is refused.
- **clinical** (once named): D-28 (who watches outside the watched hours, thresholds), D-30, D-19, D-17, D-10, D-16 (who outside the team may read a quality hold's reason) as before.

---

## 2026-10-25 13:26 CET: SIGC (0068, pgTAP 069) and the DST1 follow-up (0069, pgTAP 070) reviewed on their merge commits; CGR-46, CGR-47, CGR-48, CGR-53 closed; RLS3 (#373, open) reviewed; CGR-57 to CGR-59 (advisory); the PO's D-23 question answered

**Scope:** `recovery/main` @ `78891aa`. Changes since the 09:31 CET section (open PR #358, carried into this PR by a merge commit; JOURNAL both sides kept):
- **Code merged:** #361 **SIGC** (0068, ADR-082, pgTAP 069, `rules.ts`, `OutsideWatchedVisits.tsx`, /admin, /team, unit `signals-rules`, e2e `push.spec.ts`) as `2ad9860`; #362 **DST1-C1 to DST1-C3** (0069, ADR-081 addendum, pgTAP 070, CI step "Real clock before the seed") as `363906a`. **CI `app`, `db`, `e2e` green on `a2468b5`, `430c231`, `363906a`, `1f3ff8a` and `78891aa`** (checked through the API; the run on `2ad9860` itself was cancelled by the next push, its tree is green on `1e796d2` and later).
- **Docs merged:** PO 10:12, 12:12, 13:16 CET (DST1-C4 = CGR-54 option (a); DST1-C5 = CGR-56; RLS3-4b from CGR-55, sharpened into two levels; Q14 decided: a partly-outside visit is listed); `lca` 11:50, 12:46 CET (D-23, D-3); `eng` remediation plans `CGR-47.md`, `CGR-48.md`, `CGR-53.md`.
- **Open PRs:** #373 RLS3 (0070, ADR-083, pgTAP 071; head `cb79d77`, **CI not yet reported on the head**), #358 (mine, superseded by this PR), #3 (owner, `main`). **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0068 and 0069 in full, pgTAP 069 and 070 (assertion lines), the `takenText` change and its unit test, and 0070 and the RLS3-4b part of pgTAP 071 on the PR branch. **I did not run the NAVORA test suite** and touched no live project.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-57 | SIGC (0068): `visits_outside_watched_hours`, the structured replacement for the manual SIG1-8 check (CGR-48 (2)) | advisory (S2; must hold before the list is used as evidence that SIG1-8 is kept, i.e. before go-live) | **A planned visit without an end time counts as one minute long, so a visit that starts shortly before a watched period ends is not listed.** `private.visit_wall_range` gives a visit without `time_end` the interval start + 1 minute; its comment says "as ABS1". ABS1 does not do that: since 0069 `private.visit_interval` gives such a visit start + planned minutes A+B+C, else the rest of its day. Example: watched 07:00-20:00, a visit planned at 19:50 without an end and with 45 planned minutes runs to about 20:35, but is not listed. After 20:00 a P1 no-show or broken-off visit there reaches Operations only in the app (SIG2-12, CR-076). The list then shows an empty plan to the Clinical Owner while a visit lies partly outside the watched hours. The pgTAP case "06:50 without a planned end → listed" passes only because 06:50 is before 07:00 | 0068:153-163 (`p_end is null` → `+ interval '1 minute'`), 0068:192-193; 0069:42-48 (`visit_interval`: planned minutes, else end of day); pgTAP 069:312 | **eng (follow-up PR, PO product authority; no threshold, no clinical rule):** the wall-clock interval of a visit without an end uses the same duration as `private.visit_interval` (start + planned minutes A+B+C, else to the end of its day). pgTAP: watched 07:00-20:00; a visit at 19:50 without an end and 45 planned minutes → listed; at 19:50 without an end and no planned minutes → listed; at 08:00 without an end and 20 planned minutes → not listed |
| CGR-58 | SIGC (0068): `my_signals.watched_now` and the banner text (CGR-48 (1)) | advisory (S3) | **The banner judges the watched hours at the moment it is read, not at the moment the step to Operations is made.** `watched_now` is `watched_inside(org, now())`. A care assistant who takes a P1 no-show at 19:55 (watched until 20:00) reads "Meldung an Operations folgt"; if the step to Operations is made after 20:00, it stays in the app (`outside_classify` judges at delivery time). The text is right again on the next read after 20:00, but "folgt" promises the future. Same principle as CGR-48 (1); narrower window | 0068:134; 0064:109-114 (`outside_classify` with `watched_inside(p_org, now())`); `rules.ts:98`; unit test `signals-rules.test.ts:73-81` (flag only) | **eng / po (display only, input class V):** if an Operations delivery of the signal exists, the text follows its classification (outside the app or app only); if not yet, `watched_now` is evaluated at the instant the step is due. pgTAP: watched until 20:00, a care assistant takes at 19:55, the step is due after 20:00 → app-only text; an Operations delivery already sent outside the app → "folgt" text |
| CGR-59 | RLS3 (#373, open): `public.visit_correction_history` level (b), the billing view (RLS3-4b, CGR-55) | advisory (S2; before invoicing, gate C) | **The billing view does not show whether a correction is contained in the signed version that is billed.** Level (b) returns old and new value, the time of each correction, the version the current billing fact rests on and its countersigner, but not when that version was signed or countersigned. A correction made after the countersignature is not in the billed snapshot (0043), yet the billing reader cannot tell it apart from one that is. That is the billing question CGR-55 was about. The corrector's identity and the free-text reason are **not** needed for billing: accountability for the billed version is the named countersigner, and the full trail stays with the team, the author and the countersigner (level (a)) | 0070:96-97, 116-136 (#373, `cb79d77`); pgTAP 071:289-303 (`fact_report_version`, `fact_countersigned_by_name`, no instant) | **eng in RLS3 (or a follow-up), po:** per correction, a boolean `in_billed_version` (correction time ≤ the countersignature time, or signature time if no countersignature is required, of the version the current fact rests on), or that instant itself. pgTAP: a correction before the countersignature → true; a correction after it → false; level (b) still has no reason and no corrector |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-46** | **closed**, IMPLEMENTED (tests only, as the remedy said); CI green on `78891aa` | pgTAP 069:198-231: (a) covering registered nurse of the cover team: `stops_escalation` true, no Operations delivery (204-207, 225); (b) covering care assistant: false, Operations receives it (209-211, 227); (c) the Operations member who received it takes: true (229-231); (d) care assistant in the owning team, registered nurse only in another: false, Operations receives it (213-216, 228) |
| **CGR-47** | **closed**, IMPLEMENTED | 0068:57-106 (`signal_qualified_taken_at`; the three measures read it; `first_take_any_minutes` labelled "Nicht die qualifizierte Antwort"); pgTAP 069:115-143 (care assistant +2, registered nurse +20 → 20 min, within threshold 0 %; care assistant only → not taken; overdue unchanged; AN1 suppression; notes) |
| **CGR-48** | **closed**, IMPLEMENTED (both points); residuals CGR-57, CGR-58 | (1) 0068:111-150 (`watched_now`), `rules.ts:92-99` (a missing flag never promises the message), unit `signals-rules.test.ts:73-81`, pgTAP 069:253-259. (2) 0068:155-202, /admin and /team; pgTAP 069:308-350 (21:00 listed, 19:00 not, 19:30-20:30 listed per Q14, day 7 in, day 8 out, cancelled and suspended out, across midnight, merged periods, no watched hours → all, other organisation never, own teams on /team, anon refused). SIG1-8 stays a go-live condition (Clinical Owner) |
| **CGR-53** | **closed**, IMPLEMENTED | 0069:32-63 (`visit_interval` end via `at_zurich_end`; spring-gap visits cover both readings instead of failing with a range error), 0069:66-97 (absence ends), 0069:108-126 (`watched_inside` by wall clock or period instants); pgTAP 070:55-86 (visit 01:30-02:30 on 2026-10-25 = 23:30-01:30 UTC; flagged and released by an absence from 01:00 UTC; not by one from 01:30 UTC; ordinary night unchanged; 2027-03-28 02:30-03:10 = 00:30-02:10 UTC), 070:129-141 (DST1-7 assertions) |
| CGR-54 | open, advisory (S3); **decided by the PO** as DST1-C4, option (a) (ask which 02:xx is meant), due before 2027-10-31 or the first real client. PLANNED | `briefs/DST1.md` DST1-C4 |
| CGR-55 | open, advisory (S2); **remedy built in open PR #373** (RLS3-4b, two levels). Closes when #373 is merged with CI green. PLANNED on `recovery/main` | 0070:83-148 on `cb79d77`; pgTAP 071:268-311 (countersigner and author see corrector and reason; covering author keeps her trail; admin, coach, Operations get values without reason or corrector; other team, other organisation, outsider: nothing). Billing residual: CGR-59 |
| CGR-56 | open, advisory (S2); **decided by the PO** as DST1-C5, due before gate B. PLANNED; DST1-8 (a) and (b) met in CI (`ci.yml` "Real clock before the seed"; 070:147-166) | `briefs/DST1.md` DST1-C5 |
| CGR-49, CGR-50 | open, advisory; LEAVE1-11, LEAVE1-12. PLANNED | no change |
| CGR-51 | open, advisory; DOOR1-11. PLANNED | no change; RLS3-1 removes the coordination table read of the note row, but OPS1 and SIG1 keep their SECURITY DEFINER excerpt (0070:24-25), so PS-43 is not triggered yet |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-46, CGR-47, CGR-48, CGR-53.**

### Other changes reviewed (no finding)

- **0069 is protective throughout.** Absence ends read the later instant (an absence never ends earlier than typed), visit ends read the later instant, starts stay earlier, and `watched_inside` is true when either reading covers the instant. On ordinary days both readings agree (070:57, 72, 77, 85). The spring-gap visit that used to make every absence command on it fail with a range error now gets an interval covering both readings (0069:19-23, 51-52; 070:60). No threshold, rule or route changed.
- **0068 `my_signals`** keeps the 0063 body and adds one column; the take shown first is still the one that stops the step. `first_take_any_minutes` is never read as the response (note text asserted, 069:138-143).
- **Q14 (po: partly-outside visits are listed)**: protective, agreed. **No Operations list** (069:344): accepted; Operations is the in-app recipient, the list is a planning control for the team and administrator.
- **UI text `OUTSIDE_WATCHED_NOTE`** ("… oder jemand beobachtet die Signale in dieser Zeit") restates SIG1-8 as written (named watcher); it decides no watcher. Who may be the named watcher stays D-28 (`clinical`) and D-32 (`owner`).
- **RLS3 (#373) otherwise:** RLS3-1 removes the table-API read of no-show and interruption notes, cover events and working-time facts for coordination roles outside the team; no screen reads these tables directly (`src` checked on the PR branch: only `field_visit_status_notes`, an RPC). The covering member gains the status notes of the visit she covers while her cover runs (care context she needs at the door). RLS3-4 revokes `actor_id` through column grants and keeps the identity readers to J5 signing, F6R returns and the correction trail (071:261). This matches my 09:31 RLS3 note. **No blocking finding**; gate for acceptance after merge: CI green on the merge commit and CGR-59 decided by the PO.
- **D-23 question from the PO (12:12):** see CGR-59. The billing view serves CGR-55's billing purpose **once it shows whether each correction is in the billed version**. Billing needs neither the corrector nor the reason. UNKNOWN whether a payer contract or a KVG Art. 42 audit request will require the corrector's identity on request: D-18 (`owner`), then `lca`/legal adviser, as `lca` noted at 12:46. I have not added this to the decision row; the PO may copy it there ("Clinical Architect 2026-10-25:").

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| SIGC (merged `2ad9860`, `delivered`) | **no blocking finding; the PO may accept.** CGR-46, CGR-47, CGR-48 closed | CGR-57 (S2, before the list counts as SIG1-8 evidence), CGR-58 (S3) as follow-ups |
| DST1 follow-up (merged `363906a`) | **no blocking finding; the PO may accept DST1.** CGR-53 closed | DST1-C4 (CGR-54), DST1-C5 (CGR-56) keep their deadlines |
| RLS3 (#373, open, CI pending) | no blocking finding on the code read; CGR-55 remedy present | CGR-59 (S2, before invoicing) |
| DOOR1, LEAVE1 (briefs) | unchanged | CGR-51; CGR-49/50 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) accept SIGC with CGR-57 and CGR-58 as follow-up conditions; (2) accept DST1; (3) decide CGR-59 for RLS3-4b (add `in_billed_version` or the signed instant to the billing view) before or after merging #373; (4) optionally record the D-23 answer above in the package.
- **eng:** CGR-57 and CGR-58 in one follow-up PR; CGR-59 in #373 or a follow-up as the PO decides; DST1-C4, DST1-C5 by their deadlines.
- **owner:** as before: G-1 (name the Clinical Owner and a deputy), D-1 (urgent); merge-gate question of 09:31 answered by the PO (10:12: acceptance is the gate); merge this PR if my own merge is refused.
- **clinical** (once named): D-28 (who watches outside the watched hours, thresholds), D-30, D-19, D-17, D-10 as before.

---

## 2026-10-25 09:31 CET: DST1 merged (0067, ADR-081, pgTAP 068) and reviewed; CGR-52 closed; RLS2 merged (request closed); CGR-53 to CGR-56; RLS3 clinical note

**Scope:** `recovery/main` @ `16e4e9c`. Changes since the 05:30 CET section (merged as #348, `c8c6d7d`):
- **Code merged:** #331 RLS2 (0066, pgTAP 067) as `c1703a0` (07:11, by the owner); #349 **DST1** (0067, ADR-081, pgTAP 068, fixtures in about 60 pgTAP files, `src/features/field/time.ts`, unit `field-time`, e2e `field.spec.ts` F3, CI `db` job) as `3c2da15` (merged by `eng` before my review; see *Process* below). **CI on `2702403`, `3c2da15` and `16e4e9c`: app, db, e2e green** (checked through the API).
- **Docs merged:** PO 06:10 CET (#350: DST1-7, DST1-8 added from my 05:30 section) and 08:10 CET (#354: RLS2 accepted, Q13 decided, **RLS3 approved**); `lca` 07:50 CET (#353: D-3 gate (iv), D-23); `eng` RLS2 and DST1 delivered (#352, #356); remediation plan `clinical/remediation/CGR-52.md`.
- **Open PRs:** none except #3 (owner, `main`). **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0067 in full, pgTAP 068 in full, ADR-081, the remediation plan, the CI diff, the `time.ts` and `field-client.tsx` correction path, and the fixture diffs of 0067 (with `private.now()` normalised, the remaining changes are explicit conversions and two e2e minute counts; no expected value of 038, 046 or 062 changed). I ran the conversion and an interval overlap on a local, empty PostgreSQL 16.15 (no NAVORA schema, no data, not the live project). **I did not run the NAVORA test suite.**

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-53 | DST1 (0067): `private.visit_interval`, the one interval every absence check uses (ABS1, CGR-27) | advisory (S3; next repeated hour 2027-10-31) | **0067 shortened the interval of a visit that ends in the repeated hour.** The mechanical rewrite gives the **end** of `visit_interval` the earlier instant too. Before 0067 the end took the later one. A visit planned 01:30-02:30 on 2026-10-25 now occupies 23:30-00:30 UTC (before: 23:30-01:30 UTC). An absence of the responsible nurse that starts at 01:00 UTC (02:00 CET, second pass) no longer overlaps it, so ABS1 neither releases the visit nor flags `responsible_absent` (H-01, H-17). It is the same principle as CGR-52 (4): an interval used for a safety overlap check must not be shorter than its wall-clock length. 0067 applies the later end only to `watched_raise_at`. The stuck reference (0038:126, 0058:532) also ends earlier, but there an earlier end raises the alert sooner, so it needs no change | 0048:45-48 (end conversion); 0067:154-174 (every conversion → `private.at_zurich`), 0067:189-196 (only the watched-hours end → `at_zurich_end`); PostgreSQL 16.15: `tstzrange(at_zurich('2026-10-25 01:30'), at_zurich('2026-10-25 02:30'))` = `[23:30, 00:30)` UTC, `&& [01:00, 03:00)` = **false**; native form = `[23:30, 01:30)`, overlap **true** | **eng (follow-up PR, PO product authority, no threshold changed):** the end of `private.visit_interval` uses `private.at_zurich_end`, and the start stays `private.at_zurich`. pgTAP at a pinned clock: a visit 01:30-02:30 on 2026-10-25 whose responsible nurse is absent from 01:00 UTC is released or flagged as on any other night; a visit 02:30-03:30 keeps its earlier start; an ordinary day is unchanged |
| CGR-54 | DST1 (`time.ts`): time correction in the field app (F3) | advisory (S3; documentation integrity and billing basis, H-14) | **A corrected time in the second pass of the repeated hour cannot be entered.** `zurichLocalToIso` resolves 02:00-02:59 on the fall-back date to the earlier instant. A nurse who left at 02:20 CET and corrects the departure to "02:20" stores 00:20 UTC, one hour early. The time is saved without a confirmation step, and the screen shows only HH:MM, so the error is not visible. The doc comment says the time is "shown back to the user before saving"; the code saves at once. A corrected time is documentation, and after signing it is the billing basis (duration). The e2e F3 test avoids the case (it uses 80 minutes back in the second pass); no test covers it | `src/features/field/time.ts:153-172`; `field-client.tsx:576-598` (no confirmation, `correctVisitTime` called directly), `:606` (`zurichTime` HH:MM); `tests/unit/field-time.test.ts` (02:30 → 00:30 UTC only); `tests/e2e/field.spec.ts` F3 (`typeableMinutesBack(20, 80)`) | **po decides** (brief DST1 put display out of scope; this challenges it **for input only**). Either (a) when a typed time is in the repeated hour, the form asks which of the two is meant ("02:20 Sommerzeit / 02:20 Winterzeit") and sends that instant; or (b) the server refuses a correction in the repeated hour without an explicit offset, with a clear reason. Unit test: both readings of 02:20 on 2026-10-25 can be produced. Correct the doc comment either way |
| CGR-55 | RLS3 (brief, approved 08:10 CET): RLS3-4 column revoke of `actor_id` | advisory (S2; before the first real employee, which is when RLS3-4 is due) | **The authorship of a time correction must stay visible, per visit, to the people who sign and bill it.** RLS3-4 revokes `visit_time_corrections.actor_id` from the table API and allows per-visit identity only through listed readers with a named care task. The brief names the handover and the cover banner as examples, but not the correction trail. That trail is who changed a documented time, when, from what, to what, and why. The countersigning registered nurse (J5, CR-086) and the billing review need it. A correction without a visible author weakens documentation integrity (H-05, H-14). This is not a request for a per-person list (D-23 term b stands) | `briefs/RLS3.md` RLS3-4; corrections feed the signed snapshot and billing since 0043 (H-14 controls) | **eng / po in RLS3-4:** list a per-visit correction-history reader (corrector, time, old and new value, reason) for the report's author and countersigner and for the billing review, in `READ_PATHS.md` with its task. pgTAP: after the revoke, the countersigning RN still sees the corrector of a corrected event of that visit; a teammate's table-API select of `actor_id` is refused; no reader returns corrections grouped or counted per person |
| CGR-56 | DST1 (0067): `private.now()` and `private.test_clock` | advisory (S2; before staging with real users, gate B) | **A pinned clock on a shared database would freeze every overdue, stuck and escalation alert.** It needs two things: the seeded row in `private.test_clock`, and `navora.test_now` set (CI sets it at database level). DST1-8 (a) and (b) are met in code. Today the only guard for (c) is the statement in ADR-081 that "`supabase db push` never runs the seed". UNKNOWN whether staging is ever rebuilt with `supabase db reset --linked` or seeded by hand. Then the row would be present, and only a superuser setting would be missing | 0067:74-101; 068:75-83 (row deleted → `now()`; no API grant); CI `ci.yml` "Pin the database clock, then seed" (`alter database … set navora.test_now`), "Unpin"; ADR-081 *Decision*, test-clock bullet | **eng (deploy procedure, no live access by `cra`):** after every migration run on staging and production, a scripted check fails the deploy unless `private.test_clock` is empty and `current_setting('navora.test_now', true)` is empty at database and role level. Record the check in the release checklist. Optional: `private.now()` ignores the pin unless the database name is the local or CI one |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| **CGR-52** | **closed** (all four points), IMPLEMENTED; CI green on `3c2da15`, `2702403`, `16e4e9c` | (1)/(2) the repeated hour takes the earlier instant: 0067:35-47; every function rewritten, guard 0067:198-215; pgTAP 068:60-65 (conversion), 068:85-93 (02:30 visit P2 by 02:40 CEST, team and Operations), 068:96-114 (P1 at 01:30 UTC, receivers responsible and team, Operations after 15 min untaken, once). (3) the gap is read in CET: 068:66-69, 116-127 (overdue not later than the CET reading, P1 one hour after). (4) a window end takes the later instant: 0067:62-71, 189-196; 068:139-149 (00:00-02:30 covers 01:15 UTC, ends at 02:30 CET, look-ahead 2 h before 01:30 UTC). Fixtures deterministic: pinned CI clock plus explicit conversions; guards 068:153-170. DST1-5: no expected value of 038, 046 or 062 changed (fixture diff read). Residuals are tracked as CGR-53 and CGR-56 |
| RLS2 request (22:26: OPS1 and SIG1 still raise after the narrowing) | **closed**, IMPLEMENTED | merged `c1703a0`; pgTAP 067:286-295 (Operations still sees Nord's no-show and overdue; `my_signals` delivers both) and 067:329-330 (sweep control); green on `recovery/main` |
| CGR-49, CGR-50 | open, advisory; decided as LEAVE1-11, LEAVE1-12 (*Next up* 5). PLANNED | no change |
| CGR-51 | open, advisory; decided as DOOR1-11 (*Next up* 4). PLANNED | no change; still the F-1 route in RLS3 *Out of scope* |
| CGR-46, CGR-47, CGR-48 | open, advisory; SIGC (*Next up* 2). PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open | no change |

Closed in this section: **CGR-52**, the **RLS2 request**.

### Other changes reviewed (no finding)

- **0067 mechanics.** `private.at_zurich(timestamp)` is right on both transition nights and on ordinary days (068:60-71; I checked 02:00, 02:30 and 02:59 on 2026-10-25 and 02:30 on 2027-03-28 locally). A `date` operand keeps the native overload (both resolve to `timestamptz` → `timestamp`; checked locally). Column defaults `private.now()` work for `authenticated` (schema usage 0003:24; execute granted 0067:100-104; e2e green). In production `private.now()` equals `now()` (transaction start). No threshold, priority, receiver or step changed (D-28 untouched).
- **DST1-7 test gaps (for the PO's acceptance, not a safety finding).** 068 does not contain two assertions the brief names: a period 02:30-06:00 covering 00:45 UTC, and a 2027-03-28 period ending in the missing hour. `watched_inside` compares wall-clock times (0064:69-71), so the first holds by construction, but it is untested. Related: a watched period that **starts** in the spring gap (for example 02:30) starts at 01:30 UTC, 30 minutes after the wall clock passed 03:00. This follows DST1-3/DST1-7 as written, and only `watched_raise_at` (`greatest(start, end − 2 h)`) uses it. No finding.
- **Pinned CI clock (10:00 Zurich).** It removes the hour-dependent failures. But the suite now runs every non-DST assertion at one time of day. The real-clock runs were what exposed CGR-52. Recommendation: the CI matrix at the four DST1-1 clocks (ADR-081 *Open*, PLANNED) should also include one night-time instant (for example 23:30 UTC, after midnight Zurich).
- **`zurichLocalToIso` for the spring gap** reads a non-existent time in CET (unit test 2027-03-28 02:30 → 01:30 UTC), the same as the database. Consistent.
- **RLS3 (brief), the PO's question to me:** **no coordination role has a standing clinical need for the free text of a no-show or interruption note.** Operations needs the structured outcome (DOOR1-11). A task-bound need exists: the clinically responsible person reviewing a quality event or a P1 that followed a no-show may need the text. It belongs in a named read model tied to that open event or signal, logged, never the table API. Which role holds that clinical responsibility (coach?) is UNKNOWN until G-1 names the Clinical Owner. RLS3-1 as written is clinically safe. On RLS3-4 see CGR-55.
- **`lca` 07:50 (D-3 gate (iv), D-23)** and the **PO 08:10 Q13 decision** (F-4 before the first real employee): protective, no clinical rule. Agreed.
- **Process.** DST1 changed 82 production functions on the CSR1 and SIG1 paths and was merged before this review. DST1-5 and the PO's 08:10 note asked for the review first; `eng` recorded the deviation (journal 09:30) because COORDINATION.md sets no `cra` merge gate. No harm resulted: the change is protective and no blocking finding exists. The PO's acceptance is still the gate (README *Clinical review gate*). Decision requested below.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| DST1 (merged `3c2da15`, `delivered`) | **no blocking finding**; the PO may accept. CGR-52 closed. Follow-ups are advisory: CGR-53 and CGR-54 (S3), CGR-56 (S2, before gate B) | CGR-53, CGR-54, CGR-56; DST1-7 test gaps for the PO |
| RLS2 (accepted 08:10) | unchanged; request closed | – |
| RLS3 (brief, *Next up* 3) | no blocking finding on the brief; one condition for RLS3-4 | CGR-55 |
| SIGC, DOOR1, LEAVE1 (briefs) | unchanged | CGR-46/47/48; CGR-51; CGR-49/50 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) DST1 acceptance with CGR-53 (end of `visit_interval` → later instant) as a follow-up condition, and the two DST1-7 assertions missing from 068. (2) CGR-54: choose (a) ask which 02:xx is meant, or (b) refuse without an offset. (3) Add CGR-55 to RLS3-4. (4) CGR-56 into the release checklist.
- **eng:** CGR-53 and CGR-56 as above. In RLS3, the correction-history reader (CGR-55).
- **owner (with po, COORD):** say whether a PR in clinical scope that changes production functions waits for `cra` before merge, or whether the PO's acceptance is the only gate. Today COORDINATION.md §6 calls `cra` a "mandatory reviewer" without a merge gate. Also, as before: G-1 (name the Clinical Owner and a deputy) and D-1 (urgent).
- **clinical** (once named): D-30 before the first real leaver; D-19, D-17, D-10, D-28 as in the 22:26 section; who holds the task-bound read of a no-show note (RLS3 note above).

---

## 2026-10-25 05:30 CET: CGR-52 root cause partly established (production conversion and fixtures); DST1 brief; RLS2 green on #331; CGR-49, CGR-50, CGR-51 decided by the PO (LEAVE1-11, LEAVE1-12, DOOR1-11)

**Scope:** `recovery/main` @ `c521865`. Changes since the 02:26 CEST section, which is on the open PR #341 at `cd9a712`. #341 was not merged (db and e2e red on the DST night) and conflicts with `recovery/main` in `JOURNAL.md`. **This PR carries #341 unchanged (and through it #321, #306, #294, #278, #259) and supersedes all six.**
- **Code merged:** none. No migration after 0065 on `recovery/main`.
- **Code open:** #331 (RLS2, 0066, pgTAP 067) at `bb3ed48`. Since my review at `241c49b` only `recovery/main` was merged in; no file under `supabase/`, `src/` or `tests/` changed. **CI on `bb3ed48`: app, db (pgTAP incl. 067) and e2e green** (checked through the API). Not merged: `eng`'s merge call was refused by its permission policy; the merge is the owner's.
- **Docs merged:** PO cycles 02:10 CEST, 02:10 CET, 03:10 CET, 04:10 CET (#340, #347); `lca` 02:48, 02:42 CET, 03:43 CET (#342, #346). New brief **DST1** (approved 02:10 CET, *Next up* 1) from CGR-52. **LEAVE1-11** (CGR-49), **LEAVE1-12** (CGR-50) and **DOOR1-11** (CGR-51) added by the PO. My 02:26 *Clinical impact* blocks recorded in D-6, D-13, D-14, D-20, D-24, D-25. D-3 real-data gate (iv) now includes DOOR1-11 and F-3. D-23: `lca` 03:43 on ArGV 2 Art. 17 (verdict unchanged; no plan-limit check built). D-22, D-15, D-10, D-4 re-checked by `lca` against the ZH Spitex leaflet of September 2025 ([Z2]); no status change. **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read DST1, LEAVE1-11/-12, DOOR1-11, the `eng` CI comments on #331 (01:15, 01:16, 02:11, 03:16 UTC) and the decision-row changes. To test the CGR-52 hypothesis I grepped every migration for the conversion of a Zurich local date and time into an instant, and ran the conversion on a local, empty PostgreSQL 16.15 (no NAVORA schema, no data, not the live project). **I did not run the NAVORA test suite.**

### Findings

No new finding ID. CGR-52 is re-assessed with evidence below.

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-52 (re-assessed) | CSR1 overdue (0038), interruption follow-up (0045), SIG2 (0062, 0064); brief DST1 | advisory; **raised from S3 to S2** (production affected; before go-live). Not S1: the next repeated hour is on 2027-10-31, and the spring-forward night resolves to the safe side today | **Both explanations hold, at different hours.** (1) **Production code is affected.** Every rule turns a planned start into an instant as `(visit_date + time_start) at time zone 'Europe/Zurich'`. PostgreSQL resolves an ambiguous local time to the **later** instant (standard time): 2026-10-25 02:30 → 01:30 UTC, not 00:30 UTC. A real visit planned at 02:00-02:59 on the fall-back night that nobody starts therefore raises `visit_overdue` P2, its P1 and the SIG1/SIG2 delivery **one hour late** if the nurse meant the first 02:30. Explains the 00:35 UTC failures (fixture "10 minutes ago" = 02:25 local → 01:25 UTC, in the future). (2) **Fixtures are also affected.** At 01:11 UTC (02:11 CET), "30 minutes ago" as a wall-clock subtraction gives 01:41 local → 23:41 UTC, 90 minutes earlier, so a P2 fixture is seen as P1 (`eng` 01:16 UTC on #331). (3) **Spring-forward is on the safe side today:** a nonexistent 2027-03-28 02:30 resolves to 01:30 UTC, the same as a CET reading, which is the bound DST1-3 sets; it is not tested. (4) **One gap in DST1-2:** the SIG2 watched-hours windows (0062:215-224, 0064:80-83) are built the same way. For a window, "earlier instant" is not always the safe side: an end at 02:30 resolved to the earlier instant ends the watched time one hour sooner. | conversion sites: 0038:91-92, 99, 112, 126-127; 0045:114; 0062:678-689; windows 0062:215-224, 0064:80-83. PostgreSQL 16.15, `timezone=UTC`: `(date '2026-10-25' + time '02:30') at time zone 'Europe/Zurich'` = `2026-10-25 01:30+00`; `'02:00'` = `01:00+00`; `(date '2027-03-28' + time '02:30') …` = `2027-03-28 01:30+00`; fixture at 00:35 UTC minus 10 min = `01:25+00`; at 01:11 UTC minus 30 min = `2026-10-24 23:41+00` | DST1 as approved covers (1)-(3). **Add to DST1 (PO, product authority, no threshold changed):** for a watched-hours window, an ambiguous **start** takes the earlier instant and an ambiguous **end** the later instant, so the window is never shorter than its wall-clock length; pgTAP at a pinned clock on 2026-10-25: a window 00:00-02:30 local still covers 01:15 UTC. DST1-5 stands: no assertion weakened. The ADR (DST1-1) must state that production code was affected, so the gate review applies to the PR |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-49 | open, advisory (S2; S1 before the first real leaver); **decided by the PO** 02:10 CET as **LEAVE1-11**. PLANNED | `briefs/LEAVE1.md` LEAVE1-11: a return stays possible when the performer's access has ended or she left the team, opens no draft only she could sign, shows "Zurückgegeben – Autorin nicht mehr verfügbar", stays not final and not billable, `report_not_final` keeps raising; `i_can_return` agrees with `return_report`. This is the remedy I proposed. Closes when merged with the pgTAP (a)-(c) green |
| CGR-50 | open, advisory (S2); **decided by the PO** 02:10 CET as **LEAVE1-12**. PLANNED | `briefs/LEAVE1.md` LEAVE1-12 (open-reports list by kind before `end_member_access`, counts in the command result, HAND1 marker for every team member, return reason RN-only). Matches my remedy; it replaces a manual reminder with data and removes no control. D-30 stays `clinical`, before the first real leaver |
| CGR-51 | open, advisory (S2); **decided by the PO** 02:10 CET as **DOOR1-11**, and 04:10 CET part of D-3 real-data gate (iv) | `briefs/DOOR1.md` DOOR1-11: the excerpt is removed **in the same PR** that gives Operations the door attempt, outcome code, basis and time; "Ergebnis offen" without an outcome. Matches my remedy. The excerpt stays until then (RLS3/Q13 F-1 interim on synthetic data only, `NEXT_CAPABILITY.md` 04:10) |
| RLS2 request (22:26) | **met in code and green on the PR head**; closes on merge | pgTAP 067:277-294 passed in the db job on `bb3ed48`; no code change since my 02:26 review |
| CGR-46, CGR-47, CGR-48 | open, advisory; decided as SIGC (*Next up* 3). PLANNED | no change |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open, unchanged | no change |

No finding closed in this section.

### Other changes reviewed (no finding)

- **DST1 (brief).** Matches the CGR-52 remedy: root cause per assertion in an ADR, a fixed-clock mechanism, the earlier instant for an ambiguous planned start, a defined rule for a missing time that is never later than a CET reading, deterministic fixtures, and **no assertion weakened** (DST1-5). Changes no threshold, priority, receiver or step (D-28 untouched). Clinical review gate applies, because (1) above shows production code is affected. Rule CR-088 records today's implicit conversion.
- **`lca` 02:42 CET ([Z2], ZH Spitex leaflet September 2025) in D-22, D-15, D-10, D-4.** "Only category B needs a medical order" is consistent with CR-004/CR-005 as noted 2026-10-24; no rule changes. The 20-year retention recommendation for nursing documentation goes to a legal adviser (D-4); nothing is deleted meanwhile. That is the safe default for documentation integrity. I set no period.
- **`lca` 03:43 CET in D-23 (ArGV 2 Art. 17) and D-3.** Art. 17 exempts home-care organisations only from the permit for night and Sunday work, as read by `lca`. The working-day proposal shows the start and end of every segment and on-call calls without a visit. Clinically right: on-call calls are the hours that cause fatigue (H-10) and were invisible. No plan-limit check is built until a legal adviser answers. NAVORA invents no limit. Agreed; H-10 stays open.
- **D-3 gate (iv)** now includes DOOR1-11 and F-3 before the first real client. Protective; consistent with CGR-51.
- **PO challenge row (central Operations desk).** No change to who receives a P1; SIG1/SIG2 routes unchanged.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| RLS2 (#331, open) | **no blocking finding; CI green on `bb3ed48`**; ready to merge from the clinical side (owner merges) | CGR-51 (on F-1, not on 0066; decided as DOOR1-11) |
| DST1 (brief, *Next up* 1) | no blocking finding on the brief; **one addition proposed** (watched-hours window ends); the PR needs the clinical gate | CGR-52 (S2) |
| LEAVE1 (brief) | CGR-49 and CGR-50 taken up as LEAVE1-11 and LEAVE1-12 | open until delivered |
| DOOR1 (brief) | CGR-51 taken up as DOOR1-11 | open until delivered |
| SIGC (brief) | unchanged | CGR-46, CGR-47, CGR-48 |
| F6R (accepted) | unchanged; F6R-G1 met (02:26) | CGR-49 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** add the watched-hours window rule to DST1 (CGR-52 (4)); note in DST1 that production code is affected (CGR-52 (1)), so DST1 is a clinical-gate item.
- **eng:** DST1 with the ADR stating that 0038, 0045 and 0062 resolve an ambiguous start to the later instant today; the fixed-clock pgTAP at the four DST1-1 clocks.
- **owner:** (1) **merge this PR.** It carries #341, #321, #306, #294, #278 and #259, which can then be closed; seven of my sections are not on `recovery/main`. (2) Merge #331 (RLS2; green, no blocking finding). (3) G-1 (name the Clinical Owner and a deputy). (4) D-1 (urgent).
- **clinical** (once named): D-30 before the first real leaver; D-19, D-17, D-10, D-28 as in the 22:26 section.

---

## 2026-10-25 02:26: F6R merged (0065, pgTAP 066); F6R-G1 confirmed; RLS2 (#331, open, db red) reviewed; LEAVE1 and DOOR1 briefs; CGR-49, CGR-50, CGR-51, CGR-52 (DST night CI failure); Clinical impact confirmed or corrected for D-6, D-13, D-14, D-20, D-24, D-25

**Scope:** `recovery/main` @ `fca2b40`. Changes since the 22:26 section, which is on the open PR #321 at `592cd3d`. #321 was not merged and conflicted with `recovery/main` in `JOURNAL.md`. **This PR carries #321 unchanged (and through it #306, #294, #278, #259) and supersedes all five.**
- **Code merged:** #320 (F6R: migration `0065_f6r_return_report`, pgTAP 066 with 82 assertions, `/field` return UI, ADR-079) as `868e3e0`. CI green on head `3766bde` (`eng` 23:25).
- **Code open:** #331 (RLS2: migration `0066_rls2_team_scoped_visit_case_records`, pgTAP 067, `docs/engineering/READ_PATHS.md`, ADR-080) at `241c49b`. **CI: app and e2e green, db (migrations, seed, pgTAP) failed.** Not merged.
- **Docs:** PO cycles 23:10, 00:10, 01:16 (merged) and 02:10 (#340, open). `lca` 22:50, 00:50, 01:41. **F6R accepted** 00:10 with condition **F6R-G1** (`cra` confirms on 0065). The PO decided CGR-46, CGR-47 and CGR-48 as conditions SIG1-C3, SIG1-C2 and SIG2-C1, now brief **SIGC** (#340). New briefs **DOOR1** (approved 23:10) and **LEAVE1** (approved 01:16). D-6, D-13 and D-20 are `po-decided`. D-14, D-24 and D-25 are `awaiting-approval: owner`. D-19 and D-17 are `awaiting-approval: clinical`. **No `clinical`, `legal` or `owner` decision was answered by a person.**

I read 0065 in full, the assertion list of pgTAP 066, 0066 in full, the cra-requested block of pgTAP 067 (lines 277-294), `READ_PATHS.md` findings F-1 to F-5, the briefs LEAVE1, DOOR1 and SIGC, and the *Clinical impact* drafts of D-6, D-13, D-14, D-20, D-24 and D-25. **I did not run the tests.** CI status is as stated above, checked through the API.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-49 | F6R (0065, accepted) with LEAVE1 (brief, PLANNED) | advisory (S2; **S1 before the first real leaver**) | A countersigner who finds an error in a signed report of a performer who is **no longer available** has no safe path, and LEAVE1 as written makes the result undefined. (1) **After a team removal** (allowed once her reports are signed, CR-036), `return_report` refuses with `performer_not_in_team` (CR-048 interim). The registered nurse can then only countersign a version she knows is wrong, which becomes `final` and a billing basis, or leave it unsigned. That is the H-05 hazard that F6R was built to remove (C-7). (2) **After a LEAVE1 access end**, memberships are kept (LEAVE1-4), so `private.user_in_team(team, performer)` stays true. `return_report` and `i_can_return` would then accept a return and open a draft that only the leaver can sign. LEAVE1-3 names `is_team_member`, the organisation helper and `cover_team_for`, but not `user_in_team`. | 0065 §3 (`performer_not_in_team` check); 0065 §11 `field_reports.i_can_return` (`user_in_team`); pgTAP 066:301-308 (r4: no return after removal); `briefs/LEAVE1.md` LEAVE1-3, LEAVE1-4 | PO decides (product authority; who signs instead stays D-30, `clinical`). In my view, a version a registered nurse knows to be wrong should never be pushed into `final`: a visible "zurückgegeben, Autorin nicht mehr verfügbar" state (not final, not billable, `report_not_final` raising, on the D-30 route) is safer than a false final. Whichever way the PO decides, LEAVE1 must fix the behaviour in pgTAP: (a) a signed report of a performer whose access ended → `return_report` returns the chosen result, and `i_can_return` agrees with it; (b) the same after a team removal; (c) no path lets a countersignature turn a returned version `final` (066:239 stays). |
| CGR-50 | LEAVE1 (brief, PLANNED) | advisory (S2) | LEAVE1 is right on access (`lca` 00:50). Clinically, it turns the H-12 interim ("she keeps access until she signs") into a **permanent** unsigned or uncorrected record for every leaver who has open reports, until D-30 is answered. Today the only control that prevents this is a manager asking her to finish her paperwork before her last day. That is a manual control, and nothing in the data supports it: the "open before leaving" list is out of scope in the brief. | `briefs/LEAVE1.md` *Out of scope* (last bullet), LEAVE1-2, LEAVE1-5; H-12; PS-15; CR-036, CR-048 | Replace the manual reminder with structured data, and remove no control. (1) Before `end_member_access`, `/admin` and the team's registered nurses see the person's open reports by kind (unsigned, correction draft, returned), with visit date and team only (no content). The command result returns the same counts. (2) LEAVE1-5's marker shows to every team member who reads that visit in HAND1. pgTAP: a member with 2 unsigned reports and 1 returned report → the list shows 3 with their kinds; she signs one → 2; a care-assistant colleague sees the marker but not the return reason; a nurse of another team sees nothing. (3) For the Clinical Owner: answer D-30 before the first real leaver |
| CGR-51 | RLS2 (#331, open), proposal F-1 (`READ_PATHS.md`, for po as Q13) | advisory (S2) | F-1 proposes to stop showing Operations the first 120 or 200 characters of a no-show or interruption note. Operations is the **escalation recipient** for these P1 signals (SIG1-5, SIG2's untaken step, CR-072). At that step, what the nurse has already done (tried the door, informed a contact, called emergency services) decides what Operations does next. Today the note excerpt is the only carrier of that information. Removing it before a structured outcome reaches Operations would leave Operations unable to see what was done at the very step that depends on it. My 22:26 "*that* and *when*" was about the table API, not about this read model. | PR #331 `docs/engineering/READ_PATHS.md` F-1 (and line 74, `operations_exceptions()`); `briefs/DOOR1.md` DOOR1-5, DOOR1-6; CR-072 | PO decides with `lca` (a privacy-versus-safety trade-off). Do F-1 only together with, or after, DOOR1's structured facts: Operations' row for a no-show or interruption shows "an der Tür: ja/nein", the recorded outcome code and its basis, and the time, with no free text. pgTAP: a no-show with "an der Tür: ja" and outcome "Notfallkontakt informiert" → Operations' row carries both codes and no note text; without an outcome → "Ergebnis offen". Until then, keep the excerpt |
| CGR-52 | CSR1 overdue signal (0038), ABS1 (0046), SIG1 delivery (0060), on `recovery/main` | advisory (S3; **UNKNOWN root cause**, for `eng`) | The db job on this docs-only PR (head `ec2ef46`, run at 00:35 UTC = 02:35 CEST on 2026-10-25, **the night clocks go back**) failed 10 assertions that passed on `fca2b40` hours earlier with the same code: pgTAP 038 tests 16, 17 and 20 ("10 minutes after the planned start it is already raised, as P2"); 046 tests 71 and 72 (a released overdue visit stays alerted); 062 tests 17, 30, 39, 41 and 46 (SIG1 P1 delivery, the step to Operations, the Operations fallback). These are the main controls against H-01. My hypothesis, **not verified**: a planned start built from a Zurich local date and time in the repeated hour 02:00-02:59 resolves to the later instant (CET), so a visit is seen as not yet started for one extra hour. If that holds in production too, then on the fall-back night the overdue alert and its P1 escalation come up to one hour late for visits planned in that hour. The spring-forward night (no 02:00-02:59) needs the same check. It may instead be only the test fixtures | this PR's db job log (2026-10-25 00:35 UTC); 0038, 0046, 0060; 0055 (`zurich_today_everywhere`); pgTAP 056, 058 (Zurich day guards) | `eng`: reproduce with a fixed clock at 2026-10-25 00:35 UTC and 2027-03-28 01:30 UTC. If production code is affected, convert planned starts with a defined rule for repeated and missing local times, choosing the **earlier** instant for an ambiguous start so that alerts are never late, and add pgTAP at both DST transitions: a visit planned at 02:30 local → overdue raised by 02:40 of the first occurrence. If only the fixtures are affected, pin the test clock. Do not skip or quarantine the tests |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| F6R-G1 (PO condition, 00:10) | **met: no blocking finding on 0065** | 0065 §1-11. A team registered nurse who is not the performer returns only the latest version that is signed and awaits countersignature (066:105-139). The returned version is never changed (066:147, 286). The return is append-only for every role, the table owner included (066:149-175). The reason is readable only by the performer and the team's registered nurses, and no view, analytics, billing or push function reads it (066:177-204). The report is never stranded while she is in the team (066:206-222). No billing fact exists while it is returned, and exactly one comes from the countersigned corrected version (066:224-228, 288-299). After a return, only the performer changes the facts (066:230-245). A returned version cannot be countersigned (066:239) or withdrawn (066:254). Audit excludes the reason (0065 §1). CI green on `3766bde`. **Residuals:** CGR-49 (performer not available), CGR-50. A returned report pushes nothing to its performer; she sees it at the top of `/field`, and `report_not_final` keeps raising for the team (CR-053). Acceptable for the pilot |
| CGR-46, CGR-47, CGR-48 | open, advisory; **decided by the PO** as SIG1-C3, SIG1-C2 and SIG2-C1 (23:10), brief **SIGC** (#340), *Next up* 2. PLANNED | `NEXT_CAPABILITY.md`; `briefs/SIGC.md` on #340. The PO's wording matches my remedies |
| RLS2 request (22:26: OPS1 and SIG1 still raise after the narrowing) | **met in code, not yet evidenced** | pgTAP 067:277-294: a no-show and an overdue visit of Nord still reach Operations (`operations_exceptions`), and `my_signals` delivers both. The db job on `241c49b` is red, so this is not shown to pass. To be confirmed once CI is green and #331 is merged |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open, unchanged | no change |

### Other changes reviewed (no finding)

- **F6R design.** The return takes the **next** version number, so a number is never reused (as in 0049). The draft starts from the live snapshot and the old summary, and only the performer signs it (`sign_report`, `update_report_draft`: `not_performer`, 066:235-237). A return is not a correction round (AN2 measure 5, `report_correction_open`), and `report_not_final` covers it. That is the right signal, because no version is final. The F6R-9 measures (`report_returned_share`, `countersign_latency_hours`) read versions only, never the reason, and fall under AN1 suppression. They are the evidence for D-10 A versus B. **A return is a documentation path, not a clinical escalation.** If the error a registered nurse finds is clinically relevant (for example an observation that points to deterioration), the return raises nothing for the client. That stays H-02 and D-16 and D-28 (`clinical`), not an F6R defect.
- **RLS2 (0066).** Protective: four tables are narrowed to the team, plus the covering member for the two visit-linked tables until the report is final. Coordination roles keep their view only through the `security definer` read models. `uncovered_visits()` is narrowed to coordination roles and the visit's team, so Operations keeps it. My needs (1)-(4) from 22:26 are met as described. Deviation 3 (the cover read ends at `final`) is acceptable clinically, because a covering nurse needs no events after the report is final. F-2 to F-5 add no clinical risk. Gate: **no blocking finding**. The db job must be green before merge (`eng`).
- **DOOR1 (brief).** Category list: one organisational category (access arrangement), no clinical one. Clinical categories wait for D-17. "unbekannt" comes first and is distinct (DOOR1-4). Values are append-only with source, who and when (DOOR1-3). The note is display only (DOOR1-8). This matches my D-17 points (2)-(3) and D-19 point (2). No field reads as clinical content. **No `cra` gate unless the PR adds a category.**
- **SIGC (#340).** A rename only; content, approval and order are unchanged.
- **PO 02:10 challenge row (working-time limits checked after the plan).** Fatigue is a care-safety hazard (H-10). The source of any limit is legal (ArGV, `lca`). NAVORA invents none. Agreed.

### Clinical impact for decision packages (cra 2026-10-25 02:26)

**`po`: please record each block below in the package's *Clinical impact* section as "cra 2026-10-25 02:26: confirmed / corrected" (copied from `reports/CLINICAL_GOVERNANCE.md` by po).** Advisory (D-27); I am not a licensed clinician. These blocks set no value, step, interval, ratio or threshold.

#### D-6 (po draft 00:10): **confirmed, one addition**
- Points 1-3 confirmed. The assignment model (team plus an optional responsible member, the state list) is an organisational workflow of input class V. **It is not a clinical rule, and D-6 does not need to be reopened.**
- Addition to point 2: the clinical weight sits in what reads the responsible member, not in the model itself. That is the qualification gates (CR-002, CR-007, CR-011: an unverified label, D-29) and the signal route (SIG1: the responsible member first). Both are covered elsewhere (H-04, D-29, D-28).

#### D-13 (po draft 00:10): **points 1, 2 and 4 confirmed; point 3 corrected**
- (1) Confirmed. Which instrument the pilot provider uses is **UNKNOWN** (owner, from the provider; D-12). NAVORA records its name and version, not its content.
- (2) Confirmed, with one hazard named for the B brief: if the team writes the care plan without the assessment's problem list, the plan can drift away from the assessed needs. A product guard, not a clinical rule: the care plan shows the date of the latest assessment it was written against, and the team sees when a newer assessment exists (display only).
- (3) Corrected. Two more product guards, with no clinical threshold: (a) the minutes per category are entered with the assessment's document reference (an identifier only, `lca` 01:41); (b) the assessing registered nurse confirms the record she is named on, so a transcription by someone else is visible as such. "A mismatch shown, no block" stays right: a block on a transcription difference could delay care.
- (4) Confirmed. Reassessment triggers and intervals stay `clinical` (H-08, C-8). B records them and never schedules them.

#### D-14 (po draft 00:10): **hazard list confirmed; guard measures corrected**
- Hazard list confirmed (BL-12, LT-2). Addition: F3 (a fee per active member) creates no volume link. Its only care-side effect is a weak incentive toward fewer members working more hours each (H-10, fatigue). Counting only members whose access has not ended (LEAVE1) is right.
- Guard measures: the PO's list is confirmed, with three additions: (a) time since each client's last needs assessment, per team (delayed reassessment, H-08); (b) the share of category changes upward versus downward per team (LT-2); (c) missed and uncovered visits per team (H-01), and the F6R-9 return share (documentation quality).
- **Correction:** a guard that the guarded group feeds itself can be gamed. A quality-event rate reported by the team it guards rewards under-reporting. Pair each such guard with a source the team does not write (for example, unplanned hospital transfers recorded at intake, or client and relative feedback). Which sources to use, and every level, are for the Clinical Owner. None is needed for the fee-basis ask (F3 or F4).

#### D-20 (po draft 23:10, one point): **confirmed**
- D sharpened changes no qualification gate. Rules on the skill mix stay the Clinical Owner's (D-10, D-25). One note: a team-decided removal still meets the 0037 and 0065 §8 refusals. A leaver's open reports are CGR-50 and D-30, not D-20.

#### D-24 and D-25 (po drafts): **structure confirmed; three additions; no LTCF content**
- Point 1 confirmed. Add these hazard areas: (f) shift handover (what passes from one shift to the next, and who confirms it); (g) delegation to care assistants and FaGe (who may delegate what, and who supervises); (h) the residents' reassessment cycle. That cycle belongs to the licensed instrument and the canton (interRAI LTCF or another, UNKNOWN). NAVORA must not model it before the licence and D-34.
- Point 2 confirmed. Addition: NH1 (rosters) treats skill mix and RN cover as hard constraints. Their **values** are cantonal and clinical (`lca` [L8], ArGV 2 Art. 16), never NAVORA defaults.
- Point 3 corrected. NH0's measures look back: they show harm after it has happened. A stop rule needs signals that warn earlier. The Clinical Owner chooses them. Candidate kinds, none set here: missed or late medication, falls, unplanned hospital transfers, pressure injuries, and night escalations that went unanswered. Where the national MQI set covers such an indicator, its definition comes from the official BAG specification, never from NAVORA (UNKNOWN which indicators apply).
- D-25 (2) confirmed. Addition: a network lead must also be reachable for questions about delegation beyond a person's scope.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| F6R (accepted 00:10, condition F6R-G1) | **F6R-G1 met: no blocking finding** on 0065. The acceptance stands | CGR-49 (S2; S1 before the first real leaver) |
| RLS2 (#331, open) | **no blocking finding**; my 22:26 pgTAP request is in 067:277-294; db CI red, so merge waits on `eng` | CGR-51 (on proposal F-1, not on 0066) |
| LEAVE1 (brief, approved) | no blocking finding; two conditions proposed for the PO | CGR-49, CGR-50 |
| DOOR1 (brief, approved) | no `cra` gate unless the PR adds a category | – |
| SIGC (brief) | carries CGR-46, CGR-47, CGR-48 as decided | open until delivered |
| J5 | unchanged | CGR-31 |
| COVER1 | unchanged; cover stays off | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) CGR-49: choose how a return of an unavailable performer's report behaves, and add it with pgTAP to LEAVE1; (2) CGR-50: the open-reports list before an access end, as a LEAVE1 criterion; (3) CGR-51: when answering Q13, do F-1 only together with DOOR1's structured facts for Operations, with `lca`; (4) record the D-6, D-13, D-14, D-20, D-24 and D-25 blocks above.
- **eng:** CGR-52 (reproduce the DST-night failures; the same failures may explain part of RLS2's red db job); RLS2 db CI; then the CGR-49 and CGR-50 assertions in LEAVE1 once the PO decides.
- **owner:** (1) **merge this PR.** It carries #321, #306, #294, #278 and #259, which can then be closed. Six of my sections are not on `recovery/main`; earlier self-merges were refused. (2) G-1 (name the Clinical Owner and a deputy). (3) D-1 (urgent).
- **clinical** (once named): **D-30 before the first real leaver** (CGR-49, CGR-50); D-19, D-17, D-10 and D-28 as in the 22:26 section; the D-24 stop-rule signals if D-24 moves past A.

---


## 2026-10-24 22:26: ORD0-C2 and SIG1-C1 (0063, pgTAP 065) and the SIG2 follow-up (0064) merged; CGR-42, CGR-43, CGR-44, CGR-45 closed; CGR-46, CGR-47, CGR-48; input class in the rule register; Clinical impact for D-19 and D-17

**Scope:** `recovery/main` @ `bdb47a8`. Changes since the 18:26 section, which is on the open PR #306 at `5af9a01`. #306 was not merged and now conflicts with `recovery/main`. **This PR carries #306 unchanged, and through it #294, #278 and #259, and supersedes all four.**
- **Code merged:** #312 (ORD0-C1, ORD0-C2, SIG1-C1: migration `0063_ord0_c2_sig1_c1_conditions`, pgTAP 065, pgTAP 063 +4, one fixture moved in pgTAP 064; signal banner and `src/features/signals/rules.ts`; ADR-077) as `b574966`. #315 (SIG2-11 to SIG2-14: migration `0064_sig2_followup_liveness_watched_hours`, pgTAP 064 extended from 82 to 106 assertions, `EvaluatorHealth.tsx` on /operations and /admin, push texts; ADR-078) as `8a8dd27`. #313 and #316 (rows `delivered`).
- **Docs:** PO cycles 19:09, 20:09, 21:10, 22:10 (#308, #311, #318). `lca` 18:47, 19:55, 20:50, 21:55 (#307, #310). **ORD0 accepted** 21:10, SIG1-C1 met; **SIG2 accepted** 22:10. Briefs **F6R** (D-10 R, approved 19:09) and **RLS2** (four tables read organisation-wide, approved 22:10) are new. D-10 is `awaiting-approval: clinical`. D-23 is `po-decided` (C plus D, on `lca`'s "compliant under every plausible interpretation"). D-26 and SR-26 are with the owner. **No `clinical`, `legal` or `owner` decision was answered by a person.**
- **Open PRs:** #306, #294, #278, #259 (mine; superseded by this PR); #3 (M2, out of scope). No open engineering PR.

I read 0063 and 0064 in full, and pgTAP 065 and the new or changed parts of pgTAP 064 (lines 137-168, 283-297, 357-380, 413-453). I also read the diffs of `src/features/signals/rules.ts` and `src/features/push/rules.ts`, the SIG2 brief with the PO review of 22:10, the briefs F6R and RLS2, and the packages D-19 and D-17. **I did not run the tests.** CI, checked through the API, is green for app, db (migrations, seed, pgTAP) and e2e on `b574966`, `8a8dd27` and `bdb47a8`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-46 | SIG1-C1 (0063, accepted) | advisory (S3) | `signal_take_stops` has four ways for a take of a P1 `no_show` or `visit_interrupted` to stop the step to Operations. Two are tested: a registered nurse of the visit's team stops it, a care assistant does not. Two are not tested: (1) the **covering member** whose qualification is read in her cover team (`signal_taker_qualification`, second branch); (2) an **Operations member's own take** (ADR-077, deviation 1). If (1) is wrong, a covering care assistant's take silences the step, or a covering nurse's take does not stop it. If (2) is wrong, a non-Operations member could stop it. | 0063 §2 (`signal_taker_qualification`, `signal_take_stops`); pgTAP 065:179-239 (no fixture with `covered_by` or an Operations taker) | pgTAP: (a) a covered no-show; the covering member is a registered nurse in her cover team, takes → `stops_escalation` true, no Operations delivery after `signal_untaken`; (b) the same with a covering care assistant → false, Operations receives it; (c) an Operations member who received the signal takes → true; (d) a member of the owning team who is a care assistant there and a registered nurse only in another team → false. No code change expected |
| CGR-47 | SIG1-C1 with AN2 measure 10 / SIG2-10 | advisory (S3) | AN2's signal response measures (share taken, median time to take, `signal_taken_within_threshold_share`) read `safety_signals.taken_at`. That is the **first** take, and 0063 keeps it so on purpose. For a no-show or broken-off visit, the first take may be a care assistant's, which does not stop the step to Operations. The measure then reports a response that SIG1-C1 itself does not count as one. The Clinical Owner reads these values before lifting SIG1-8 (18:26 section, *Other changes*), so the evidence overstates how fast a qualified person responded. | 0063 header item 4 ("AN2 measure 10 unchanged: time to the first take"); pgTAP 065 "safety_signals.taken_by stays the first take"; 0060:447-459; 0062:702-725 | For `no_show` and `visit_interrupted`, measure the time to the first take with `stops_escalation`; keep the first take as its own value if the PO wants it. pgTAP: a care assistant takes at +2 min and a registered nurse at +20 min → the measure counts +20 min; a care assistant's take only → counted as not taken. A PO item (an AN2 parameter, not a clinical value) |
| CGR-48 | SIG2-12 (0064, accepted) with SIG1-8 | advisory (S2; **S1 for switching the channel on** in an organisation with visits outside its watched hours) | Outside the watched hours, the step to Operations stays in the app (`outside_working_time`). In that case a P1 no-show at 21:30 reaches outside the app only the responsible member (often the nurse at the door herself) and colleagues inside their own planned span. Two gaps. (1) The banner tells a care assistant who took it "Meldung an Operations folgt". At that hour this means a message in an app nobody may be watching; the text reassures without a basis. (2) The protection is SIG1-8: "visits outside those hours are not planned". That is a manual pilot-plan control, and nothing in the data shows it is kept, although the watched hours and the planned visit intervals are both recorded. | 0064 §2 (`outside_classify` patch); `src/features/signals/rules.ts` `takenText` (no watched-hours input); `my_signals` `taken_awaits_rn` (0063 §4); `briefs/SIG1.md` SIG1-8; `briefs/SIG2.md` line 40 | PO decides (product authority). (1) While no watched period runs, the text says that Operations is informed in the app only (for example "Operations nur in der App: ausserhalb der überwachten Zeit"). Unit test on `takenText` and pgTAP on a reader flag. (2) Replace the manual SIG1-8 check with structured data: /admin and /team list the planned visits of the next 7 days whose interval lies outside every watched period. Optionally, planning in a pilot organisation warns on such a visit. pgTAP: watched 07:00-20:00, a visit 21:00-21:30 → listed; a visit 19:00-19:30 → not listed; no watched hours → all listed. The Clinical Owner may still require a named watcher (D-28). This replaces a control; it removes none |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-42 | **closed** (IMPLEMENTED) | 0064 §3: `private.signal_scheduler_runs` is written only by `private.evaluate_all_signals` (the pg_cron job), never by a page poll. `signal_evaluator_live` is true for 5 minutes. "Signalprüfung läuft nicht" shows on /operations and /admin, and "aktiv" is withdrawn on /team and /settings. The job also asks the sender to dispatch (pg_net, Vault; without them nothing is called and pending rows fail after 2 minutes, fail closed). pgTAP 064:137-168 (no run, then 6 min → nobody "aktiv"), 413-453 (1 min → running; 6 min → not running for Operations and /admin; another organisation sees only its own; a nurse reads none; a page poll records no run; the scheduled run does). CI green on `8a8dd27`. PS-34 closed. **Residuals:** the job, pg_net and the two Vault entries in the pilot project are owner steps (OWNER_RUNBOOK 5a). A stopped evaluator is shown, not escalated; the page poll still evaluates |
| CGR-43 | **closed** (IMPLEMENTED) | 0063 §2-3: each take is an append-only, audited row in `signal_takes`. For `no_show` and `visit_interrupted`, only a registered nurse of the visit's team, the covering member who is a registered nurse in her cover team, or Operations stops the step. The SIG1-5 loop and `outside_settle` both read `signal_taken_stops_step`, so my 18:26 note is met. pgTAP 065:179-187 (channel on, care assistant takes, no outside send → Operations receives it), 206-217 (care assistant → "Meldung an Operations folgt"; registered nurse → stops; other kinds → as built), 231-239 (escalation after `signal_untaken`; both takes kept). CI green on `b574966`. PS-35 closed. **Residuals:** CGR-46, CGR-47, CGR-48 (1). Who may handle a no-show alone stays `clinical` (D-19 question 4, D-28) |
| CGR-44 | **closed** (IMPLEMENTED) | 0063 §1: triggers `ord0c2_inform_gp` (an A/C item becomes active) and `ord0c2_inform_gp_assessment` (a needs assessment completed). Each opens one `inform_gp` task when the order is not `present` and no record is dated on or after that Zurich day. A refresh never reopens it. pgTAP 065:57-113 (ORD0-C2 (a)-(d′), the closed case). CI green on `b574966`. PS-36 closed. The deadline and content of the information stay D-22 (`legal`, `clinical`) |
| CGR-45 | **closed** (IMPLEMENTED) | 0064 §1: `watched_raise_at` returns the later of the last period's start and its end minus 2 hours. That instant is inside by the same predicate SIG2-12 uses (`watched_inside`: start inclusive, end exclusive). pgTAP 064:357-380 (22:00 → 18:00; 05:00 → 18:00 the evening before; 18:00 inside; 20:00 outside; watched 07:00-08:30 only → 07:00; no watched hours → effective rule) and the six fixed instants of SIG2-14 (064:368-375). CI green on `8a8dd27`. PS-37 closed. The 2 hours are a PO operating limit (CR-073), to be checked on SIG2-10 evidence |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open, unchanged | no change |

### Other changes reviewed (no finding)

- **ORD0-C2 (CR-074).** A record dated on the day of the event covers it. That is the brief's choice and a product rule, not a clinical one. The trigger fires on activation (insert, re-activation, a change to A/C), not on every save, so the team is not flooded. Whether a doctor must be told of a *change* in A/C care, and how soon, stays D-22.
- **SIG1-C1 on the banner.** A signal taken only by a care assistant stays at the top for everyone else, so a registered nurse can still take it (`splitSignals`). Right. The qualification label shows the staff role only; no client data.
- **`signal_takes` backfill.** Takes made before 0063 are judged by the same rule. An open no-show taken only by a care assistant goes to Operations at the next run. Protective; synthetic data only.
- **SIG2-12 (CR-076).** Fewer outside sends, never fewer in-app deliveries; the PO's reading follows `lca` 15:05 (no on-call duty without a Pikett arrangement). Accepted from the safety side **with CGR-48**. With no watched hours, Operations is never pushed, and /admin says so.
- **SIG2-11 (CR-077).** No run row means "not running" (deviation 13): fail closed. The heartbeat is not audited (deviation 14): it holds no person and no client. Acceptable.
- **`push_dispatch_kick`.** It reads the secret from Vault inside a `security definer` function that `authenticated` cannot execute (pgTAP 064:416-419). It returns false on every error. No health data in the request body (`{}`).
- **F6R (brief, PLANNED).** It carries my conditions (a)-(d) as F6R-5, F6R-4, F6R-2 and F6R-7, and F6R-6 keeps a returned report out of billing. F6R-9 gives the Clinical Owner the evidence for D-10 A vs. B. No `cra` gate is needed unless the PR adds a rule.
- **RLS2 (brief, PLANNED), clinical needs of coordination roles (asked by po 22:10).** In my reading, the clinical needs are these. (1) **Operations** must know *that* a visit is overdue, stuck, uncovered, broken off or a no-show, and when. That comes through the `security definer` readers (OPS1, SIG1), not through the table API on `visit_events`. Operations never needs the free-text reasons of `visit_time_corrections` or `team_decisions`. (2) **Operations and coaches** need the open `case_tasks` kinds that are safety- or order-related (`inform_gp`, `gp_missing`, `access_unknown`) as counts or exceptions per team. They do not need the rows of other teams through the table API. (3) The **covering member** needs the covered visit's events during the cover (cover predicate). (4) No coordination role needs another member's events per person (D-23). RLS2-6 (no regression on /operations) must show that OPS1 and SIG1 still raise every signal after the narrowing. **pgTAP to add in RLS2:** after the narrowing, a no-show and an overdue visit of team A still reach Operations (OPS1 and `my_signals`). Otherwise no clinical gate.
- **Rules added by eng (CR-074 to CR-077) and CR-073 as changed:** reviewed against 0063 and 0064; they match the code. My unmerged CR-074 to CR-078 are renumbered CR-079 to CR-083.
- **Input class (D-34).** Added to `CLINICAL_RULE_REGISTER.md` as a section, one class per rule: V *visit/schedule fact*, N *care-context fact recorded by a nurse*, K *clinical content*. **No rule is K.** Five N rules that rank or escalate are marked **for the adviser**: CR-020, CR-022, CR-024, CR-041 and CR-073. Whether a task or P3 prompt from the order status (CR-070, CR-074) "routes" is UNKNOWN, for the adviser.

### Clinical impact for decision packages (cra 2026-10-24 22:26)

**`po`: please copy each block verbatim into the package's *Clinical impact* section, signed "cra 2026-10-24 22:26 (copied from `reports/CLINICAL_GOVERNANCE.md` by po)".** These blocks are advisory (D-27); I am not a licensed clinician. They give the Clinical Owner a structure. They set no step, waiting time, list item or threshold. D-24, D-13, D-25, D-6 and D-20 (one point) follow in later runs.

#### D-19: on-site protocol when the client does not open

- **(1) Hazards and where time matters (structure, not rule).** A no-show has three broad causes. (a) The client is away and safe. (b) The client is at home and cannot open: a fall, an acute illness, loss of consciousness, death. (c) The client was admitted somewhere without the team being told. Only (b) is time-critical. Harm from lying unaided grows with the time until help arrives. NAVORA cannot tell (a), (b) and (c) apart; the nurse at the door can only partly. The protocol must fix these decision points, each with a value the Clinical Owner sets:
  - how the nurse tries to reach the client (door, phone);
  - which known whereabouts she checks (hospital, relatives, day care);
  - whom she contacts, in what order, and on which basis (recorded consent, or emergency, `lca` 16:05);
  - who decides to call emergency services or the police, and when;
  - the **longest time she stays on site before she escalates**;
  - what happens to her next visits. NAVORA's part here is visible: the team re-plans, and SIG1 flags the overdue visits.
  - **None of these values exists yet (UNKNOWN, `clinical`).**
- **(2) Recording from `on_the_way` (CR-014): safe in direction.** It raises the P1 earlier, never later. One hazard: a no-show recorded after only a phone attempt reads like "did not open at the door". If no door attempt was made, a later reader (the team, a doctor, a relative) draws the wrong conclusion about what was checked. Product remedy (PO, not clinical): the no-show record carries one structured fact, "an der Tür: ja/nein". The required note stays. pgTAP: both values stored and shown in HAND1.
- **(3) Clinical or product in option B.**
  - **Clinical (Clinical Owner):** the steps and their order; every waiting time; the trigger for emergency services; who may do which step (qualification); when a registered nurse must be involved and by when.
  - **Product (PO):** how the steps are shown and recorded (append-only, one row per step with time and result, as `eng` drafted); that a no-show without an outcome stays P1 (built); that the step list is versioned reference data with a `clinical` source, and empty until approved; the card content from D-17's organisational items.
- **(4) CGR-43 / may a care assistant handle a no-show alone? `clinical`.** The interim is IMPLEMENTED and protective: a care assistant's take does not stop the step to Operations (0063). In my view the Clinical Owner must answer three things: may a care assistant do the on-site steps alone; must a registered nurse (or Operations) be informed; and by when. **Gap:** outside the watched hours, "Operations informed" means in the app only (CGR-48). An answer that relies on Operations needs either watched hours that cover every planned visit, or a provider's on-call person (D-32, owner).
- **A hazard the package names (po 22:10):** "Notfallkontakt informiert" is offered as an outcome, but NAVORA shows the nurse no emergency contact (0015:68 revoke; no reader in `src/`). Removing the outcome would lose the record of a real action taken with a paper list. Keep it. The fix is D-17's organisational items: the emergency contact with a per-contact "may be informed" flag (`lca` 16:05) and the access arrangement without a key-safe code. These are product and legal (D-9), not clinical. **Option C is the safer target. Option B is not useful at the door without C's contact and access data.**
- **Evidence:** the PO's hypothesis row of 22:10 (time from no-show to recorded outcome; share with outcome `other`) is the right evidence. Its 15 minutes is a PO hypothesis bound, not an on-site waiting time, and must never be shown as one.

#### D-17: safety alerts a nurse sees before the first visit

- **(1) Classification of the row's examples.** **Clinical:** allergies, fall risk, infection precautions. Their list and their form are for the Clinical Owner, who may add items; I add none. **Organisational (product authority, with D-9 and D-19 for consent):** access or key arrangement (never a key-safe code), emergency contact (with the "may be informed" flag), language. They are recorded once and reused, never duplicated (D-15).
- **(2) Hazards.**
  - **A (free text only):** a missing entry reads as "nothing known". That is the main cause of H-03 (S1).
  - **B ("unknown" shown, no block):** the gap is visible, and the nurse can ask before or at the visit. Two failure modes. If "no" and "unknown" are not visually distinct, "unknown" reads as "no". If most items are "unknown", nurses learn to ignore the panel (alert fatigue).
  - **C (an "unknown" clinical item blocks readiness):** it forces the question, but it can delay the first visit after a hospital discharge. That brings back H-01 (missed care after discharge, the reason `visit_uncovered_hospital` is P1). A block must therefore never stop a hospital-discharge first visit. Whether "unknown" instead requires something at the first visit (for example, who performs it) is a clinical rule; I set none.
- **(3) Form.** Yes / no / unknown plus a note is a safe display form under three conditions: (a) "unknown" is distinct from "no" and shown first; (b) each value carries who recorded it, when, and from which source (referral, client, relative, doctor); (c) a "yes" requires the note. Whether a category needs structured detail (for example the type of precaution, or the allergen and the kind of reaction) is `clinical`. The product should store the value as dated, append-only rows, so a change never overwrites the earlier value.
- **(4) Review trigger.** Candidates the Clinical Owner can choose from, none decided: each care-plan review (the date signal `care_plan_review_overdue` exists); a return from hospital (a new referral or a returning-client link); a quality event of a relevant type (the type list is empty, CR-016); any team member marking a value as changed. Product part: a change shows in HAND1 as a new row.
- **(5) What the Clinical Owner approves:** the list of clinical categories; whether each needs structured detail; what "unknown" requires, if anything; the review triggers; who may record a clinical category (registered nurse only, or any member). Related: H-03 (S1), PS-4, D-15 (readiness), D-19 (contact and access data), D-3 (the cover read's field list includes these alerts), D-9 (legal basis at intake).
- **D-34 input class:** N (a care-context fact recorded by a nurse). As long as an alert is **only displayed**, it is not marked "for the adviser". If an alert ever ranks, routes or blocks a visit, it is marked, and it needs the adviser before real clients.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ORD0 (accepted 21:10) | **no blocking finding** on 0063 §1 | CGR-44 closed |
| SIG1 (accepted with SIG1-C1, met in 0063) | **no blocking finding** on 0063 §2-4 | CGR-43 closed; CGR-46, CGR-47 (S3) |
| SIG2 (accepted 22:10) | **no blocking finding** on 0064. The PO's acceptance stands. Before the channel is switched on in an organisation: DPF entries, D-2, D-26, the Vault and pg_net wiring (owner), and a PO decision on CGR-48 | CGR-42, CGR-45 closed; CGR-48 (S2; S1 for switching on) |
| F6R, RLS2 (briefs, PLANNED) | no `cra` gate unless the PR adds a rule; for RLS2 see the pgTAP note above | – |
| J5 | unchanged | CGR-31 |
| COVER1 | unchanged; cover stays off | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) decide CGR-48: the text outside watched hours, and the list of planned visits outside watched hours as the structured replacement for SIG1-8; (2) CGR-47: which take AN2 counts for no-show and broken-off visits; (3) copy the D-19 and D-17 blocks, and the D-10 and D-34 blocks from the 18:26 section if not yet done; (4) D-19 (2): the "an der Tür: ja/nein" fact on a no-show; (5) correct the input-class reading in the register where a brief says otherwise.
- **eng:** CGR-46 (pgTAP only); in RLS2, the assertion that OPS1 and SIG1 still raise after the narrowing.
- **owner:** (1) **merge this PR**. It carries #306, #294, #278 and #259, which can then be closed. Five of my sections (06:30, 10:26, 14:27, 18:26 and this one) are not on `recovery/main`, and register IDs collided again this run: my CR-074 to CR-078 are now CR-079 to CR-083. (2) Name the Clinical Owner and a deputy (G-1). (3) D-1 (urgent). (4) Set up the pg_cron job, pg_net and the Vault entries in the pilot project (CGR-42 residual).
- **clinical** (once named): D-19 (questions 1, 3, 4 above), D-17 (question 5), D-10 A vs. B after the pilot (F6R-9 evidence), D-28 (with the SIG1-C1 interim and CGR-48), and the 14:27 items.

---


## 2026-10-24 18:26: SIG2 (0062, pgTAP 064) merged; CGR-41 closed; CGR-45; PO decisions on CGR-42, CGR-43, CGR-44; Clinical impact for D-10 and D-34

**Scope:** `recovery/main` @ `84dc4ec`. Changes since the 14:27 section (open PR #294 at `afef2cc`, not merged: the self-merge was refused earlier and nobody else merged it; #294 then conflicted with `recovery/main`). **This PR carries #294, #278 and #259 unchanged and supersedes all three.**
- **Code merged:** #295 (SIG2: migration `0062_sig2_outside_delivery`, pgTAP 064, `src/features/push/*`, `/settings` opt-in, `/admin` channel and watched hours, `/team` status, `api/push/dispatch`, e2e `push.spec.ts`; ADR-076) as `7a9d08d`; #297 (row `delivered`).
- **Docs:** PO cycles 14:40, 15:10, 15:35, 16:20, 17:10, 18:12 (#291, #301, #303, #305); `lca` #296, #300, #302, #304. SIG1 **accepted** with condition SIG1-C1 (CGR-43); ORD0 `changes-requested` (ORD0-C1, ORD0-C2 = Q12 (c), widened to (b)+(c) at 16:20; CGR-44); SIG2 `changes-requested` (SIG2-11 = CGR-42, SIG2-12), **awaiting clinical review on 0062**. Packages D-6, D-19, D-20, D-14, D-13, D-24, D-25 written; D-2, D-7, D-8 to the owner. **No `clinical`, `legal` or `owner` decision answered.**
- **Open PRs:** #294, #278, #259 (mine, superseded by this PR); #3 (M2, out of scope). No open engineering PR.

I read 0062 in full, the pgTAP 064 assertions for SIG2-4 to SIG2-7 (lines 160-340), `features/push/dispatch.ts` and `api/push/dispatch/route.ts`, the SIG2 brief with the PO review, the SIG1-C1 and ORD0-C2 texts, and the packages D-10 and D-34; for D-10 also 0016, 0043:391, 0044:1-27 and the HAND1 observation reader (0033:144-151). **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `7a9d08d`; on `84dc4ec` (docs only) app and db are green and e2e was still running when I read it.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-45 | SIG2-6 (merged, `changes-requested`); CGR-41 point 3 | advisory (S2; **S1 for SIG2 go-live**) | A foreseeable P1 (`visit_uncovered_hospital`) whose window would open outside the watched hours is raised **at the end** of the last watched period, not inside it. `watched_raise_at` returns that end instant, and the same function treats the end instant as **outside** (`l.lt::time < h.ends`). With watched hours 07:00-20:00 the signal appears at 20:00, the minute the watch ends. Nobody watching has any time to assign someone. Once SIG2-12 is built (Operations pushes only inside watched hours), the Operations push at 20:00 is `outside_working_time`, and colleagues are usually outside their visit span by then. So CGR-41 point 3 ("raised while people are still working") is not achieved. Nothing is worse than SIG1 (the signal is earlier than without watched hours, never later), so this is not blocking. | 0062 §3 `watched_raise_at` (`last_end … where q.e <= p_t`, returns `e`; `inside` uses `< h.ends`); §7 patch of `derived_exceptions` (`now() >= watched_raise_at(…)`); pgTAP 064:318-321 assert exactly 20:00; brief SIG2-6 says "at the end of the last watched period" | PO decides the raise point (product authority, not a clinical value). The raise time must lie **inside** a watched period, by the same predicate SIG2-12 will use. Two options: (a) the **start** of the last watched period before the window opens (no new parameter); (b) its end minus a lead the PO sets, at least the time a team needs to assign someone. pgTAP: watched 07:00-20:00, window opens 22:00 → raise time < 20:00 and inside a watched period; at that time an Operations push is `sent` (test transport) once SIG2-12 is built; window opens 08:00 → unchanged; no watched hours → unchanged. Recommended: add as SIG2-13 to the SIG2 follow-up PR with SIG2-11 and SIG2-12. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-41 | **closed** for points 1 and 2 (IMPLEMENTED); point 3 continues as **CGR-45** | Point 1: `outside_settle` (0062 §5): when a new P1 episode's outside rows are all decided and none is `sent`, the signal records `outside_none_at` and goes to Operations at once as untaken. A row the sender has not reported within 2 minutes counts as failed, so a missing or stopped sender also escalates (fail closed). pgTAP 064:171-174 (one recipient outside → no immediate step), 202-203 (every send failed → escalated at once), 216-217 (timeout → failed, escalated), 231-238 (zero outside recipients → Operations at once, reason shown). Point 2: the untaken step goes to Operations only, never to the whole team (pgTAP 064:258-260). CI green on `7a9d08d`. PS-33 closed. **Residuals:** the channel cannot be switched on until the DPF entries are recorded (deviation 1, fail closed); Operations pushes at any hour until SIG2-12 is built; `sent` means the push service accepted the message, not that a person saw it (see *Other changes*) |
| CGR-42 | open, advisory (S2; S1 for SIG2 go-live); **decided by the PO** 2026-10-24 15:10 as SIG2-11 (5-minute limit, an operating value); PLANNED | `briefs/SIG2.md` SIG2-11; not built (0062 records no evaluator run). The sender itself fails closed: with no dispatcher, pending rows time out after 2 minutes and the signal goes to Operations at once (`dispatch.ts` header; 0062 §5). That covers the sender, not the evaluator: if the evaluator does not run, nothing is classified and nothing escalates. SIG2-11 is therefore still needed. Closes with SIG2-11's pgTAP green |
| CGR-43 | open, advisory (S2); **decided by the PO** 2026-10-24 15:10 as SIG1-C1 (my recommended strict default, for `no_show` and `visit_interrupted`; other kinds to D-28); PLANNED | `briefs/SIG1.md` SIG1-C1 (a)-(e). **Note for eng:** SIG2's immediate step (`outside_settle`, 0062 §5) also skips a signal once `taken_by` is set. SIG1-C1 must treat that check the same way: a care assistant's take of a P1 no-show must not stop the SIG2-5 step either. pgTAP: channel on, care assistant takes within the 2 minutes, no outside `sent` → Operations still receives it |
| CGR-44 | open, advisory (S2); **decided by the PO** 2026-10-24 15:10 (Q12 (c), ORD0-C2), widened 16:20 to (b)+(c) after `lca` 16:05; PLANNED | `briefs/ORD0.md` ORD0-C2 (a)-(e), (a′). Meets my remedy and goes further (a completed needs assessment without an order also reopens the task). Closes with ORD0-C2's pgTAP green |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change; `lca` 15:05 adds an invoicing prerequisite (no billing while the client is in hospital or a nursing home, except admission, discharge and assessment or coordination; tarifsuisse Art. 10 Abs. 4, `lca` reading), and the PO adds AÜP days (16:20). Both are PLANNED, not built |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | no change |
| CGR-16, CGR-23 | open, unchanged | no change |

### Other changes reviewed (no finding)

- **SIG2 recipients (CR-071).** The responsible member gets a push at any hour unless she is absent; a colleague only inside the span of her own planned visits that day; Operations whenever opted in (until SIG2-12). This matches D-32 item 2 and the PO's decisions; the Pikett question for Operations is SIG2-12.
- **`sent` is not "reached".** A push accepted by Google or Microsoft counts as `sent` and stops the immediate SIG2-5 step. If the responsible member is asleep or off duty, the signal waits for the SIG1-5 step (at most 15 minutes, CR-068), exactly as without SIG2. Nothing is worse than SIG1. But AN2's `signal_outside_sent_share` (SIG2-10) measures delivery to a push service, not to a person. The Clinical Owner must read it together with `signal_taken_within_threshold_share` before lifting SIG1-8. Display is never claimed (SIG2-8), which is right.
- **Fail-closed paths.** Channel off by default; no vendor counts without a recorded DPF entry, and none is recorded. Sender not configured → pending rows fail after 2 minutes → Operations at once. Switching the channel off fails pending rows (`channel_off`); those signals fall back to SIG1-5. Each path leaves the in-app delivery unchanged. pgTAP 064 shows a P2 gets no delivery, nothing goes to another organisation, and a coach without a team is no recipient.
- **Privacy.** The payload is one constant text; the service worker ignores the payload; the link is `/field?von=push` without an ID. Endpoint and keys are readable by `service_role` only (column grants). Audit rows hold vendor and result, never the endpoint. `/team` shows per member only "aktiv / nicht aktiv". No health data.
- **Shared device.** Registering an endpoint already stored for another person moves it to the new person. The first person's status then reads "nicht aktiv" on `/team`, so the team can see the change. Acceptable.
- **Rules added by eng (CR-071 to CR-073):** reviewed against 0062; they match the code. CR-073 carries CGR-45.

### Clinical impact for decision packages (cra 2026-10-24 18:26)

**`po`: please copy each block verbatim into the package's *Clinical impact* section, signed "cra 2026-10-24 18:26 (copied from `reports/CLINICAL_GOVERNANCE.md` by po)".** Advisory (D-27); I am not a licensed clinician. The other packages that ask for `cra` input (D-17, D-14, D-13, D-24, D-25, D-6, D-19, D-20) follow in later runs, D-17 and D-19 first (open hazards H-03, CGR-43).

#### D-10: countersignature of care-assistant visit reports

- **What the countersignature controls.** It is the trace that a registered nurse supervised delegated A/C care. It also marks the point from which a report counts as documentation and as a billing basis (`report_not_final`, 0043:391). The risks it controls: a missed or wrongly recorded observation, care outside the care assistant's competence (CR-010, D-29), and wrong times billed.
- **Hazards of B (risk-based).** (1) An observation the care assistant does not recognise as relevant is never flagged, so a trigger "report with an observation" misses the case that matters. (2) The first-visits count, the sample share and the triggers are clinical rules (Clinical Owner); none is set here. (3) The supervision must be shown afterwards: the sample must be drawn reproducibly and stored (as `lca` and Engineering say). B is not a pilot option; I agree with the PO.
- **Hazards of C (review only on a signal).** Supervision depends on the supervised person's own report. That is no supervision of care work done without professional independence. Not protective; I agree with the PO and `lca`.
- **Is R safer than "countersign, then correct"? Yes**, on three points. (1) *Documentation integrity:* today a countersigner who sees a wrong time must countersign a version she knows is wrong. That version becomes `final`, and a billing fact is built from it (J5, 0043). It stays the billing basis until the performer signs a correction and it is countersigned again (0044: only the performer signs a correction). R keeps the wrong version out of `final`. (2) *Billing:* under R a disputed report never becomes a billing basis; under today's path it is one for a time. (3) *Meaning:* the countersignature again means "checked and agreed" (C-7).
- **Hazards R adds, and the controls it needs** (testable): (a) a returned report can be stranded when the performer is off or has left. It must stay visible as open until `final`, and `report_not_final` must keep raising (CR-053), so nothing is lost silently. pgTAP: returned report → in the performer's list and the team queue; `report_not_final` present. The "performer left" case follows D-30. (b) A return reopens the visit's facts to the performer (facts are locked only while `signed`/`final`, 0040). An observation the team already saw in HAND1 (0033:144-151 reads observations directly) must change only by a superseding row, never in place. pgTAP: after a return, a changed observation → a new row with `supersedes_id`; the earlier one still readable. (c) The returned version, reason, returner and time are append-only (`lca` condition a). (d) The reason is free text written by a nurse about care. It is health data: visible to the performer and the team's registered nurses only, never in a push, AN1/AN2 or an export.
- **Classification (reviewer's view, not a decision):** R changes no clinical rule. Who must countersign (CR-011) and what `final` means stay the same. R adds a workflow step that keeps an unchecked version out of `final`. In my reading it is a documentation-integrity workflow inside CR-011/CR-043 that the PO may decide under (a)-(d). The Clinical Owner should be informed, not asked to approve. Whether every care-assistant report must be countersigned at all (A vs. B) stays `clinical` (with the licence holder's supervision concept, D-12).
- **Precondition for every option:** D-29's real-data gate. A countersignature by an unverified `registered_nurse` label attests nothing (H-04).
- **Evidence to collect (AN2):** countersignature latency (`signed_at` → `countersigned_at`), the share corrected after `final`, and with R the share returned. RN minutes per countersignature are not recorded (UNKNOWN).

#### D-34: is NAVORA a medical device (intended purpose)

- **Answer to "is SIG1 monitoring in a clinical sense?":** in substance, no. The signals watch **service delivery** (did a planned visit happen, start, finish, or have someone responsible). They do not watch a client's condition. They read visit and schedule facts, and NAVORA infers nothing about health from them. Two caveats: (1) the response to a no-show or a broken-off visit can be clinical (a fall behind a closed door). That is the reason for SIG1-C1 and the D-19 protocol, but it is the nurse's judgement, not the software's. (2) Whether a regulator reads "service-delivery monitoring" as monitoring is a regulatory question: UNKNOWN (`lca`, adviser).
- **IMPLEMENTED rules that take a care fact (the PO's inventory; I confirm it from the migrations I have reviewed):** (1) `visit_uncovered_hospital` is ranked P1 on the referral category "hospital discharge". That is a care-context fact the intake nurse records, not clinical content NAVORA interprets. Removing it would lower protection (H-01); I agree it stays until the adviser answers. (2) `quality_serious_open` escalates on a severity the reporting nurse chose. NAVORA sets the timing, not the severity. **No IMPLEMENTED rule reads observations, care notes, vital signs or assessment results**, by my reading of 0019-0062.
- **PLANNED features that would be clinical decision support in substance**, so they belong in a separately qualified module (option C), with their hazards:
  - *AI intake extraction* (Gate 4 hypothesis): an allergy, precaution or medication missed or invented in extraction (H-03). The nurse may confirm without reading (automation bias).
  - *AI assessment or care-plan drafts* (NH2/NH3, "primary nurse confirms an AI draft"): the same automation bias. A draft becomes the record by confirmation. A wrong need or a missing need is carried forward.
  - *interRAI outputs* computed by NAVORA (scales, CAPs, outcome measures): they would reproduce a licensed algorithm, which I may not invent and NAVORA may not either. D-13 B (reference only; the assessment runs in the provider's licensed tool) keeps it outside.
  - *"NAVORA proposes a care-plan review"*: outside, if it is triggered by dates and visit facts only (as `care_plan_review_overdue` is today); inside, once it reads observations or assessment content.
- **A control that replaces a review step with structured data:** every brief and every Clinical Rule Register row states the **input class** of each rule: *visit/schedule fact*, *care-context fact recorded by a nurse*, or *clinical content*. A rule of the third class cannot ship in the core. The Architect checks the class on every review. That makes the boundary in option C enforceable by review, without a separate meeting. Testable: a register column, filled for every rule; a brief without it is `changes-requested`.
- **Wording rule (PO, 17:10):** right as a safe default; but wording alone does not change an intended purpose. The feature list does.
- **Hazard if D-34 stays open:** a clinical-interpretation feature is built into the core under delivery pressure, and the whole platform then falls under device law (`lca` 16:45, BW630_30_007 section 5.3). Owner of the answer: `owner` with a regulatory adviser. UNKNOWN until then.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| SIG2 (merged #295; PO: `changes-requested`, awaiting clinical review) | **no blocking finding** on 0062. The PO may accept once SIG2-11, SIG2-12 and a decision on CGR-45 are met. The channel cannot be switched on before the DPF entries and D-2 exist | CGR-45 (S2; S1 for SIG2 go-live); CGR-42 (decided, PLANNED); CGR-41 closed |
| SIG1 (accepted with SIG1-C1) | unchanged; SIG1-C1 must also cover SIG2's immediate step (note under CGR-43) | CGR-43 (decided, PLANNED) |
| ORD0 (`changes-requested`: ORD0-C1, ORD0-C2) | unchanged; no further `cra` gate needed for ORD0-C1/C2 unless their PR adds a rule | CGR-44 (decided, PLANNED) |
| J5 | unchanged | CGR-31 |
| COVER1 | unchanged; cover stays off | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) CGR-45: the raise point for SIG2-6 (start of the last watched period, or end minus a lead the PO sets), as SIG2-13 in the SIG2 follow-up; (2) copy the D-10 and D-34 blocks into the packages; (3) D-10: whether R is decided by the PO under (a)-(d) (my classification above) or routed to `clinical`.
- **eng:** SIG1-C1 to cover `outside_settle` (note under CGR-43); SIG2-11, SIG2-12 and (if decided) SIG2-13 in one PR.
- **owner:** (1) **merge this PR** (it carries #294, #278 and #259, which can then be closed). This role's self-merge has been refused in earlier runs; four of my sections (06:30, 10:26, 14:27 and this one) are not on `recovery/main`. While they are unmerged, the PO and `lca` cite them from branches, and rule IDs collide (CR-073 was renumbered to CR-078 this run for that reason); (2) name the Clinical Owner and a deputy (G-1); (3) D-1 (urgent); (4) confirm the pg_cron job `navora-sig1-signals` in the pilot project (CGR-42).
- **clinical** (once named): unchanged from 14:27 (D-28 with the CGR-43 question; D-22 question 6). For D-10: A vs. B after the pilot, on AN2 evidence.

---


## 2026-10-24 14:27: SIG1 (0060, pgTAP 062) and ORD0 (0061, pgTAP 063) merged; CGR-36, CGR-37, CGR-38, CGR-40 closed; register IDs reconciled

**Scope:** `recovery/main` @ `3928572`. Changes since the 10:26 section (open PR #278 at `972c68c`, not merged: the self-merge was refused by the session's permission control, see 10:26; this PR carries #259 and #278 unchanged and supersedes both):
- **Code merged:** #279 (SIG1: migration `0060_sig1_safety_signal_delivery`, pgTAP 062, `SignalBanner` on `/field`, `/team`, OPS1, e2e `signals.spec.ts`; ADR-074; remediation plan `clinical/remediation/CGR-37.md`) as `7a3fdb5`; #284 (ORD0: migration `0061_ord0_gp_informed_and_open_end_order`, pgTAP 063, `/team` case view, e2e `doctor.spec.ts`; ADR-075; remediation plans `CGR-36.md`, `CGR-38.md`) as `2561463`.
- **Docs:** PO cycles 11:09 (SIG1 reviewed, **awaiting clinical review**; SIG2 approved with the PO's decisions on CGR-41 points 1-3 in D-32) and 12:10; eng #281, #289 (SIG1, ORD0 `delivered`); `lca` #280, #286, #290, #293 (D-32 re-check for CGR-41, D-9, D-4, D-10, D-7, D-15, D-1, SR-26, D-8, D-2, D-29, D-30). **No `clinical`, `legal` or `owner` decision answered.**
- **Open PRs:** #291 (PO 13:15 + 14:40, not merged, read): ORD0 reviewed, **awaiting clinical review**, condition ORD0-C1; **Q12 decided (a)**; D-1 to the owner (urgent); packages D-34, D-26, D-23, D-17. #278, #259 (mine, superseded by this PR). #3 (M2, out of scope).

I read 0060 and 0061 in full, pgTAP 062 and 063 (every assertion), the `signals` and `gp` feature modules, `SignalBanner.tsx`, the SIG1, SIG2 and ORD0 briefs with the PO reviews, the remediation plans CGR-36, CGR-37, CGR-38, the D-32 addendum, Q12, and the packages D-1, D-34, D-17, D-23, D-26 on #291. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `7a3fdb5` and on `3928572`; on `2561463` app and db are green and e2e was *cancelled* (superseded by the next push; green on the PR head `4f938f6` per the PO, and on `3928572`, which contains it).

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-42 | SIG1 (merged); SIG2 (approved, unstarted) | advisory (S2; **S1 for SIG2 go-live**) | The signal evaluator runs every minute only if the pg_cron job exists. If pg_cron is missing or the job fails to schedule, the migration raises a **notice** and nothing else; the evaluator then runs only when someone has `/field`, `/team` or OPS1 open (`my_signals`). Nobody can see that the job is not running. For SIG1 (in the app only) that is harmless: a signal is shown only to an open page anyway. For **SIG2** it is the whole point: a push to a phone with the app closed is sent only if the evaluator runs without any page open. The SIG2 brief has no criterion for it. Whether the job runs on the live project: UNKNOWN (not accessed; `owner`, `eng`). | 0060:345-357 (`cron.schedule` in an exception block, `raise notice`), 0060:374 (poll path), 0025:328-337 (pg_cron created only "where available"); `briefs/SIG2.md` (SIG2-1 to SIG2-10, no liveness criterion; open question line 46 "database job") | PO adds to the SIG2 brief (product authority; no clinical value): (1) each evaluator run records its time; (2) when the last run is older than a PO-set limit, Operations and `/admin` show "Signalprüfung läuft nicht" and the SIG2 sender refuses to report the channel as working; (3) the SIG2 send path is triggered by the scheduled evaluator, never only by a page poll. pgTAP: last run 1 min ago → no warning; older than the limit → warning visible to Operations, not to another organisation; a test that `cron.job` contains `navora-sig1-signals` when pg_cron exists. Until built: the pilot checklist confirms the job exists in the pilot project (`owner` executes). |
| CGR-43 | SIG1 (merged, awaiting clinical review) | advisory (S2) | **Any** recipient can take a P1 signal with "Ich übernehme", whatever her qualification, and a take **stops** the SIG1-5 step to Operations. Recipients include care assistants (every member of the owning team). A care assistant can therefore take a P1 no-show ("Klientin öffnet nicht") or a broken-off visit, and nobody else, Operations included, is told. Whether such a signal needs a registered nurse's judgement (a possible fall or deterioration behind a closed door) is `clinical` (D-28, with D-19 for the no-show protocol): UNKNOWN. I invent no rule about who may respond. | `take_signal` 0060:394-418 (no qualification check); SIG1-5 loop 0060:304 (`taken_by is null`); recipients 0060:213; `team_memberships.qualification` (0014:31, 0018:119); pgTAP 062:63, 111-113 (care assistant …906 receives and takes) | PO decides (product authority; the clinical rule is D-28). Strict default I recommend until D-28: a take by a member whose qualification is not `registered_nurse` is recorded and shown, but **does not** stop the SIG1-5 step to Operations for `no_show` and `visit_interrupted`; a take by a registered nurse does. pgTAP: care assistant takes a P1 no-show → `escalated_at` set after `signal_untaken`; registered nurse takes → not escalated; `visit_overdue` taken by a care assistant → as the PO decides. Alternative: record the PO's acceptance of any-recipient takes in D-28 as a question for the Clinical Owner. |
| CGR-44 | ORD0 (merged, awaiting clinical review); Q12 decided (a) by the PO 13:15 (#291) | advisory (S2) | With Q12 (a), after the first "Hausärztin/Hausarzt informiert" record a case **never** prompts again, whatever A/C care is added later and however long the case runs. A client whose needs change (a new A/C service after a hospital stay or a deterioration) can receive months of new care without an order and without the team being asked to inform the doctor. The PO's reason (a task reopened on every `/team` load is ignored) is valid against reopening **on every refresh**, but option (c) reopens on an **event** (a new A/C care-plan item without an order), once, and does not have that problem. Whether a reassessment result must be sent (KLV Art. 8a Abs. 1bis as read by `lca`) is D-22 question 6 (`legal`, `clinical`): UNKNOWN. | 0061:183, 190 (`not exists … case_gp_notices g where g.case_id = c.id`: one record per case suppresses forever); 0061:159 (`no_open_task` → `unchanged`, so a later information cannot be recorded either); Q12 row (#291 `OPEN_DECISIONS.md`); CR-069 | PO decides (product authority; no deadline or content invented): adopt Q12 (c) as the pilot default, or record why not. (c): when a care-plan item of category A or C becomes active in a case without an order `present`, and no `inform_gp` record exists **after** that item became active, one `inform_gp` task opens; a refresh never reopens it. pgTAP: record, then a new active C item → one new task; second refresh → still one; a record → done; a new B item with an order → no task. Deadline and content stay D-22. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-37 | **closed** (IMPLEMENTED, in the app) | 0060 §2-§4: `safety_signals` (one row per P1 episode, open-key unique index, guard trigger: end, take and escalation recorded once, nothing else changes, never deleted) and `signal_deliveries` (one row per recipient, never changed, audited); `private.evaluate_signals` reads `derived_exceptions` and `effective_exception_rules` (no second threshold, SIG1-9); recipients: responsible or covering member, present members of the owning team, else Operations (admins if none), never a coach or another organisation; the signal stays open until its cause ends (CR-041 unchanged). pgTAP 062: P1 overdue → one signal, 902 responsible + 906 team (57-68); second evaluation writes nothing (71-73); P2 not delivered, stricter rule delivers (75-86); cause ends → signal ends, new cause → new episode with new rows (88-97); take, duplicate, non-recipient, coach (99-130); guards (132-136); untaken → Operations, range (138-154); no-show kind (156-164); removed member (166-171); absence fallback, other organisation (173-192). e2e `signals.spec.ts`: a no-show reaches a colleague's open `/field` without navigation. CI green on `7a3fdb5`. PS-29 closed. **Residuals:** outside the app nothing is delivered (SIG2; CGR-41, CGR-42); SIG1-8 (a named watcher for every planned hour) stays a go-live condition; who may take a signal (CGR-43) |
| CGR-36 | **closed** (IMPLEMENTED) | 0061 §1-§2: `case_gp_notices` (date, one of four channel codes, task, actor and time by the server; no free text; append-only, audited, RLS team + coordinators); `record_gp_informed` closes the open `inform_gp` task in the same transaction; `complete_case_task('inform_gp')` still refused. pgTAP 063: task open after an A visit without an order (63-67); `complete_case_task` refused (74); bad channel and null date refused (78-80); coach, non-member, other organisation rejected (87-97); ok → one record, task `done` with `done_by`, audit rows for both tables (118-134); replay `duplicate` (120); immutable (148-149); planning and PLAN2 do not reopen (153-158). CI green. BL-16 mitigated in code. **Residuals:** reopening after a later A/C change (CGR-44); the HAND1 entry is untested (PO condition ORD0-C1, which I support); whether the information is a billing condition, its deadline and content: D-22 |
| CGR-38 | **closed** (IMPLEMENTED) | 0061 §4-§5: `order_without_end_date` P3 for a case `active`, with a team, an order `present`, no end date and an active B item; closes only with its cause (`exception_closes_with_cause`, hand close `cause_persists`); shown on `/team` and OPS1. pgTAP 063:170-223 (A/C only none; B + present → one, team and entity; `/team` and OPS1; hand close refused; end date → gone; no active B item → gone; other organisation none). PS-30 closed. **Residual:** the ending "order no longer `present`" is untested (ORD0-C1); the order duration stays D-22 (`legal`) |
| CGR-40 | **closed** (IMPLEMENTED) | 0061 `record_gp_informed`: `before_case` against the case's Zurich creation day; pgTAP 063:107-109 (21 days before → `before_case`), 118 (10 days before, after the case was created, before the task → `ok`). PS-32 closed |
| CGR-41 | open, advisory (S2); **decided by the PO** 2026-10-24 11:09 (D-32 addendum: point 1 adopted; point 2 to Operations, not the whole team, after `lca` 10:47 on Pikett; point 3 by raising look-ahead P1s at the end of the last watched period); PLANNED in SIG2 (SIG2-5 to SIG2-7) | `briefs/SIG2.md`; I accept point 2's choice: the protective form within the legal limits `lca` named. Closes when SIG2 is merged with the SIG2-5 and SIG2-6 pgTAP green. Add CGR-42 to the same brief |
| CGR-31 | open, advisory (S3; S1 before invoicing) | no change |
| CGR-28, CGR-21 | open, unchanged (S2 if cover is enabled) | SIG1 sends a covered visit's signal to the owning team (CGR-21's direction) and, as `responsible`, to the covering member only when `responsible_user_id` is empty (`coalesce(responsible_user_id, covered_by)`, 0060 §3); `cover_without_access` is not delivered (ADR-074). Both must be re-checked before D-3 enables cover |
| CGR-16, CGR-23 | open, unchanged | no change |

### Other changes reviewed (no finding)

- **SIG1 privacy:** deliveries hold kind, visit, recipient, reason and time; the banner shows fixed text, the visit date and time and the team; `taken_by_name` is a colleague's display name, never the client's; RLS limits each person to rows addressed to her (pgTAP 062:122-124). No health data. AN2 measure 10's signal rows are per team and organisation under AN1 suppression.
- **SIG1 kinds:** `visit_uncovered_hospital` and `visit_uncovered` share the text "Einsatz ohne Zuständige". The hospital-discharge urgency is lost on the banner, though the P1 itself is kept. A note for the PO, not a finding; whether the text may say "nach Spitalaustritt" (a health-related fact, shown to the team) is for the PO with D-3.
- **SIG1 absent responsible member not delivered (eng deviation, CR-067):** the strict reading; an absent person is not on duty, and the fallback to Operations covers an empty team. I support it.
- **ORD0 analytics:** the 7-day share is labelled in the product "Evidenz für D-22, keine Frist". Register row CR-077 added so it is never read as a deadline.
- **ORD0 PO review (#291):** the four deviations are within product authority. Deviation 1 is CGR-44. Condition ORD0-C1 is right; I add nothing to it.
- **D-1 (PO 13:15, #291, `owner`, urgent):** whether rows in the live project are about real persons is a privacy fact only the owner knows. I support the PO's line: "not sure" counts as "yes". Until it is answered, no pilot with real clients. That also follows the real-data gates (D-3, D-9, D-29).
- **D-34, D-17 (#291, `cra` input requested):** my *Clinical impact* follows once the packages are on `recovery/main` (same practice as for #242). D-23 and D-26: "not needed" for `cra` is right. One note on D-23: a derived working day must not pressure a nurse to cut time with a client; the AN1 rule (team level, no ranking) is the control.
- **Register IDs:** `recovery/main` holds eng's CR-066 to CR-070 (SIG1, ORD0), and other files cite those IDs (`IMPLEMENTATION_STATUS.md`, `OPEN_DECISIONS.md` Q12, `JOURNAL.md`). They stand. My 11:30 renumbering (in unmerged #278) is reversed. The rows I proposed as CR-066 to CR-069 in the unmerged 06:30 and 10:26 sections are **CR-073 to CR-076** (0056 `responsible_absent`, AN1/AN2 suppression, direction-aware range, AN2 windows), with content unchanged. Read every CR-066 to CR-069 in those two sections as CR-073 to CR-076.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| SIG1 (merged #279; PO: awaiting clinical review) | **no blocking finding**: the PO may accept, recording CGR-43 as a condition or as a D-28 question | CGR-43 (S2); CGR-37 closed |
| ORD0 (merged #284; PO: awaiting clinical review, ORD0-C1) | **no blocking finding**: the PO may accept with ORD0-C1 and a decision on CGR-44 | CGR-44 (S2); CGR-36, CGR-38, CGR-40 closed |
| SIG2 (approved, unstarted) | **advisory** before work starts: add CGR-42 to the brief | CGR-41 (decided), CGR-42 (S2; S1 for SIG2 go-live) |
| ADM1, AN2, COORD5 | unchanged, no blocking finding | – |
| J5 | unchanged | CGR-31 |
| COVER1 | unchanged; cover stays off | CGR-21, CGR-28 |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **po:** (1) CGR-43: the take rule, or record it as a D-28 question; (2) CGR-44: Q12 (c) as the pilot default, or record why (a) stays; (3) CGR-42 in the SIG2 brief; (4) SIG1 and ORD0 acceptance, now unblocked by this section.
- **eng:** none new; ORD0-C1 as the PO set it.
- **owner:** (1) D-1 fact question (urgent, PO 13:15); (2) name the Clinical Owner and a deputy (G-1); D-28, D-30, D-16, D-31, D-3, D-15 still wait only on that person; (3) this role still cannot merge its own governance PRs in this session: please merge this PR (it contains #259 and #278, which can then be closed), or grant the self-merge the role prompt describes; (4) confirm that the pg_cron job `navora-sig1-signals` exists in the pilot project (CGR-42).
- **clinical** (once named), adding to D-28: may a care assistant take a P1 no-show or broken-off visit alone (CGR-43); D-22 question 6, from the care side: does a change in A/C needs require the doctor to be informed again (CGR-44).

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
