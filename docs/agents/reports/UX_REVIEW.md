# UX Review Report

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *UX review*. **Reference:** [`../../design/DESIGN_SYSTEM.md`](../../design/DESIGN_SYSTEM.md).

Newest dated section first; never edit an earlier section, correct it in a new one. Each finding: `UXR-<n>` | screen and role | severity (`severe`, `high`, `medium`, `low`) | finding | evidence (CI screenshot artifact and commit, file:line) | principle broken (design system §) | testable remedy | issue.

---

## 2026-10-28 07:50 CET · `uxa`: #574 merged; UXR-15 and UXR-2 closed on CI evidence; no new finding

**What changed since 03:50.** **#574 merged** (UX1-18 axe `color-contrast`, UX1-27; merge commit `93f7423`, then docs `3578bfb`). Its branch got one merge of `recovery/main` (`e759825`, JOURNAL conflict only): `git diff 7988945 93f7423 -- src tests .github` is empty, so the merged screen code is exactly the head I reviewed at 03:50. CI green on `e759825` and on `recovery/main` `93f7423` and `3578bfb`: app, db, e2e, ui-screenshots (the last includes the axe check). Docs only otherwise: PO 04:10 (UXR-20 → **UX1-30**, part (d); UXR-21 → **UX2-10**) and 06:10 (`cra` 05:30 conditions (1)-(3) on UX1-30; new **UX2-11**: a returned report stays on her day until she signs again). No open PR changes screens. Open `ux` issues unchanged: #506 to #510, #515, #516, #548.

**Sources.** `ui-screenshots` artifact for `recovery/main` `3578bfb` (12797247537) exists; **download refused again** (storage host `productionresultssa5.blob.core.windows.net`, empty archive), so **no screenshots and no `axe_*.json` were available to me**. Review from code on `3578bfb` and from CI results. The live project was not touched. No benchmark (one was made today at 03:50).

### Checks on `recovery/main` `3578bfb`

- `git grep` over `src/` for `#6b8075`, `#5f766d`, `#6d857c`, `#6B7280`, `text-stone-500`, `text-gray-500`: only the comment in `src/lib/ui/colors.ts:3-4`. No regression of UXR-15 or UXR-2 (IMPLEMENTED).
- `/field` "Zu erledigen": "Entscheid offen" link equals its heading (UX1-27, IMPLEMENTED). "Zurückgegeben (n)" link (`field/field-client.tsx:165`) still differs from its heading "Zurückgegeben: bitte korrigieren und neu unterschreiben (n)" (`:224`): UXR-20, PLANNED as UX1-30, expected, not a regression.
- `/login` panel text (UXR-17) unchanged, PLANNED (part (d)).
- **UX2-11 read from a UX view:** consistent with §1 (what needs attention now stays on the day screen) and with the NHS task-list pattern noted at 03:50 (open work stays listed until done). No UX objection; the rule itself is `cra`'s (F6R-5), not mine to change. Recorded in the design system §5 as PLANNED.

### Findings

No new finding.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-15, UXR-2 (#516) | **Closed** in this report: remedy on `recovery/main` (#574, `93f7423`); `tests/unit/ux1-contrast.test.ts` and the axe check in `tests/screenshots/capture.spec.ts` green in CI on `e759825`, `93f7423`, `3578bfb`. Not seen in a screenshot or axe JSON (download refused). Closing #516 is the PO's. | `src/lib/ui/colors.ts`; CI runs on `3578bfb` |
| UXR-20 | PLANNED as UX1-30 (part (d)), with `cra`'s conditions (1)-(3). | `briefs/UX1.md` |
| UXR-21 | PLANNED as UX2-10. | `briefs/UX2.md` |
| UXR-18, UXR-19 | PLANNED as UX1-28 and UX1-29 (part (d)). | `briefs/UX1.md` |
| UXR-17 | PLANNED (part (d)); still at `(auth)/login/page.tsx`. | `3578bfb` |
| UXR-13, UXR-14, UXR-16 | Closed in code (23:49); unchanged. | |
| UXR-1, -3, -6, -8, -9, -10, -11 | Remedy IMPLEMENTED (#554, #558); unchanged; still not seen in a screenshot. | |
| UXR-4, UXR-5 (a), UXR-7 | PLANNED (part (g)). | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| UXR-12 | PLANNED (part (d)). | |

**For the PO.** No new issue (no severe or high finding). (1) UXR-15 and UXR-2 are closed on CI evidence; #516 can be closed by you if you accept CI without a screenshot. (2) Nothing new waits on you from me; part (d) (UX1-11 to UX1-13, UX1-28 to UX1-30, UXR-17) is the next screen change I will review. (3) Screenshot and axe-JSON download is still refused to this role's session; every review so far is code-only. I propose only.

---

## 2026-10-28 03:50 CET · `uxa`: UX1-18 / UX1-27 PR #574 reviewed; UXR-20, UXR-21; benchmark (task lists)

**What changed since 23:49.** No screen code merged on `recovery/main` (now `16c706e`); merges were docs only (PO 00:15, 01:10, 02:10; `cra` 01:30; `lca` 23:41, 00:45; `aia` 02:20). The PO placed UXR-18 as **UX1-28** (with `cra`'s (c) confirmed and (d), (e) added 02:10) and UXR-19 as **UX1-29**, both in part (d), and decided UXR-17 (the `/login` panel text goes, no new text; rides part (d)). **Open PR with screen changes: #574** (UX1-18 axe `color-contrast` plus UX1-27, ADR-106; head `7988945`; CI green on that head: app, db, e2e, ui-screenshots, the last now including axe). Open `ux` issues: #506 to #510, #515, #516, #548; none closed by me (acceptance is the PO's).

**Sources.** `ui-screenshots` artifacts exist for `recovery/main` on `16c706e` (12785451603) and for #574 (12779014203, run 40602317771). **Downloading was again refused** (storage host `productionresultssa19.blob.core.windows.net`, empty archive), so **no screenshots and no `axe_*.json` were available to me in this run**. Review from code (`git diff recovery/main...origin/feat/ux1-18-27`) and from CI results: the ui-screenshots job on `7988945` fetched axe-core 4.10.2 (`AXE_CORE_PATH` set in the job log) and passed, which by the test's design means no serious or critical `color-contrast` violation on any captured page (every role, 390 and 1440 px, `/login`, dark `/field`). The live project was not touched.

### Review of #574 (head `7988945`)

- **UX1-18 / UXR-15 / UXR-2:** every inline grey I listed (`#6b8075`, `#5f766d`, and also `#6d857c`, `#6B7280`) is gone from `src/` on the branch (`git grep`, only the comment in `src/lib/ui/colors.ts` mentions them); `/teams`, `/visits`, `/partners`, `/operations` use one constant `SECONDARY_TEXT` (stone-700, the `text-secondary` value); every `text-stone-500` became `text-secondary`; the pending sign-in button moved from `#6b8075` to `#37554a` (white on it about 7.9:1, calculated; UNKNOWN until measured, axe does not capture the pending state). Matches §6. One constant is the right interim step before UX2's tokens (§7).
- **UX1-27 (CGR-80):** the "Zu erledigen" link now carries the section's own heading through one constant (`features/field/todo.ts`); Playwright asserts link text equals heading, the row inside 390 × 844 above `next-visit`, and SIG1 still first (negative). Matches §1 (what needs attention now, in the first viewport) and §4 (one label per thing). No safety signal moved.
- No blocking finding on #574. Two low findings below; neither needs to hold the merge.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-20 | `/field` "Zu erledigen" row, nurse, phone | low | UX1-27 makes the "Entscheid offen" link equal its section heading, but the neighbouring link "Zurückgegeben (n)" leads to a section headed "Zurückgegeben: bitte korrigieren und neu unterschreiben (n)". The link says what happened, not what she must do, and the two names differ for one thing; "Zur Gegenzeichnung (n)" already equals its heading. | `field/field-client.tsx` on `7988945`: link `href="#zurueckgegeben"` (~line 165) vs `section#zurueckgegeben` `h2` (~line 224) | §1 what to do next; §4 one label per thing | Presentation only: either the link text equals the section heading (as UX1-27 does for "Entscheid offen") or both use one constant; unit test like `ux1-todo` asserts link text = `h2` text for all three links. The heading text is fixed product text: if it is shortened instead, `cra` confirms (it concerns returned documentation that must be corrected). Can ride part (d) with UX1-13's string list. | report |
| UXR-21 | every captured route, all roles | low | The UX1-18 axe run judges only each page at rest and keeps only `violations`; axe's `incomplete` results (text over gradients, overlapping or partly hidden elements, which axe cannot decide) are dropped, and states a nurse sees while working are never measured: the open "Ich kann nicht arbeiten" dialog, the "Mehr" menu, a refused command's inline error, the pending sign-in button. A contrast regression there passes CI. | `tests/screenshots/capture.spec.ts` on `7988945`: `resultTypes: ["violations"]`, `flatMap` over `violations` only; capture loop visits routes only | §6 contrast on every surface; §8 review on every state that matters | (a) write axe `incomplete` nodes for `color-contrast` into `axe_<role>_<viewport>.json` (no fail, for `uxa` review); (b) capture and axe-check at 390 × 844 the open absence dialog and the open "Mehr" menu on `/field` for the nurse. Test: the JSON has an `incomplete` key; two extra screenshots `nurse_field_dialog_390x844.png`, `nurse_field_more_390x844.png` exist. Order and placement are the PO's (part (g) or UX2-8). | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-15, UXR-2 (#516) | Remedy IMPLEMENTED in open PR #574 (CI green on `7988945`, axe passed). Stays OPEN in this report until #574 is merged; closes then on CI evidence. | `src/lib/ui/colors.ts`; `tests/screenshots/capture.spec.ts` |
| UXR-18, UXR-19 | PLANNED as UX1-28 (with (d), (e)) and UX1-29 in part (d); not in a PR yet. | `briefs/UX1.md` |
| UXR-17 | PLANNED (PO 00:15: text removed, no replacement; rides part (d)). Still on `recovery/main` and on #574: `(auth)/login/page.tsx:32`. | `16c706e`, `7988945` |
| UXR-13, UXR-14, UXR-16 | Closed in code (23:49); unchanged. | |
| UXR-1, -3, -6, -8, -9, -10, -11 | Remedy IMPLEMENTED (#554, #558); unchanged; still not seen in a screenshot. | |
| UXR-4, UXR-5 (a), UXR-7 | PLANNED (part (g)). | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| UXR-12 | PLANNED (part (d)). | |
| UXR-20, UXR-21 | OPEN, new (low). | above |

### Benchmark (once today): task list with written status (NHS service manual)

Read 2026-10-28: NHS digital service manual, *Task list* component ([service-manual.nhs.uk/design-system/components/task-list](https://service-manual.nhs.uk/design-system/components/task-list)); see also the GOV.UK *Complete multiple tasks* pattern. The pattern in my words: each open task is one short row whose whole area is the link; its status is a word in a tag ("Incomplete", "Completed"), colour only reinforces the word; tasks that cannot be started are plain text without a link; the link is tied to its status and any hint by `aria-describedby`; task names stay short because screen reader users move from link to link.

**Compare NAVORA `/field` "Zu erledigen":** already good: one row per kind of open work, word plus count, 44 px targets, colour not the only carrier (IMPLEMENTED). **Adopt:** (1) link name = destination heading, for every link (UXR-20; UX1-27 does it for one); (2) keep names short: the row is a list of links a screen reader reads one by one, so the full fixed sentence belongs in the section, not the link; where (1) and (2) conflict, the short form becomes the section heading and the instruction moves into the section's first line, which `cra` confirms for clinical wording; (3) when UX2 brings a status tag component, the words follow the pattern (state in words, the colour from `attention` or `info`, never blue as a third accent: §3). No proprietary design or text copied.

**For the PO.** No new issue (no severe or high finding). (1) #574 has no blocking UX finding from me; once merged, UXR-15 and UXR-2 close on its CI evidence. (2) UXR-20 is cheapest in part (d) (same file as UX1-27, same string list); UXR-21 is a CI coverage trade-off for part (g) or UX2-8, yours to place. (3) Screenshot and axe-JSON access is still refused to this role's session (artifact storage host); every review so far is code-only. I propose only.

---

## 2026-10-27 23:49 CET · `uxa`: UX1 parts (c) #554 and (f) #558 merged; UXR-13, UXR-14, UXR-16 closed in code

**What changed since 19:51.** Merged into `recovery/main` (now `e5dfad0`, CI green: app, db, e2e, ui-screenshots): **#554** UX1 part (c) with UX1-20, UX1-21 and the PO 20:15 merge condition UX1-25, UX1-26 and the UXR-16 fix (`334682f`, CI green on `822646d`, `cra` gate cleared 21:30), and **#558** UX1 part (f) (`caf454e`, CI green on `1e75521`). The screen code that changed after my 19:51 review heads (`19ec040`, `c661cc6`) is only `field/absence-section.tsx` (UX1-25), `components/layout/Sidebar.tsx` (UX1-26) and three lines in `field/field-client.tsx` (UXR-16); I reviewed those diffs. Other merges were docs only (PO, `cra`, `lca`, `aia`, `gov`). **Open PRs with screen changes: none** (open: #571 `lca`, docs). Open `ux` issues: #506 to #510, #515, #516, #548; none closed (acceptance is the PO's). No benchmark this run (made 10:42 today).

**Sources.** `ui-screenshots` artifacts exist for `recovery/main` on `e5dfad0` (12776390119, 22:29 UTC) and `caf454e`. **Downloading was again refused** (storage host `productionresultssa16.blob.core.windows.net`, empty archive), so **no screenshots were available to me in this run**; review from code (`git diff 19ec040 822646d`, `git diff ddc62cd e5dfad0`) and from the Playwright assertions that CI ran green. The live project was not touched.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-18 | `/field` "Ich kann nicht arbeiten" dialog, nurse, phone | medium | IMPLEMENTED defect (present since the overlay in #554; the dialog of UX1-25 keeps it). While "Speichern" is in flight, "Abbrechen" stays enabled and Escape closes the dialog, but the request is not stopped. Afterwards (a) a save that succeeds records the absence although she pressed "Abbrechen"; (b) a refusal (`command-error`) is rendered only inside the closed dialog, so she never sees that she is **not** recorded absent; (c) the notice that the absence covers planned visits before today, which the team must decide on (CGR-32, `absence-past-planned`, link "Zum Team"), is set on a closed dialog and cleared on the next open, so she never sees it. The window is one network round trip, longer on a weak mobile connection. | `field/absence-section.tsx:16-23` (`run`, no abort), `:47-49` (`close`, `onClosed` clear the notice), `:81-86` (`setNotice` after the await), `:114` (Abbrechen not disabled), `:122` (error inside the dialog) on `e5dfad0` | §6 dialogs; §2 say what happens | Presentation only: while `pending`, "Abbrechen" is disabled and the dialog's `cancel` event is prevented (Escape does nothing), so the outcome always appears in the open dialog. Playwright at 390 × 844 with the save request delayed (`page.route`): after "Speichern", Escape and "Abbrechen" leave the dialog open; a refused save shows `command-error` inside it; a save covering a past planned visit shows `absence-past-planned`. Command, fields and texts unchanged. How the CGR-32 notice is shown is `cra`'s to confirm. | report |
| UXR-19 | `/field` "Ich kann nicht arbeiten" dialog, nurse, phone and screen reader | low | The dialog has no visible heading: it opens on the field "Wer"; its accessible name "Abwesenheit" differs from the button "Ich kann nicht arbeiten" that opened it. A nurse who opened it by mistake has to read the fields to know where she is. | `field/absence-section.tsx:68-71`, `:89-90` (`e5dfad0`) | §6 dialogs (heading); §4 one label per thing | A visible `h2` "Ich kann nicht arbeiten" as the dialog's first element, referenced by `aria-labelledby`. Component or Playwright assertion: `getByRole("dialog", { name: "Ich kann nicht arbeiten" })` is visible after the tap; first focus stays on "Wer" (UX1-25 unchanged). Can ride part (d) or UX2. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-13 | **Closed in code.** Native `<dialog>` with `showModal()`, `autoFocus` on "Wer", Tab wrapped at both ends, Escape closes without sending, focus back on the trigger. Playwright UX1-25 asserts all four; CI e2e green on `822646d` and `e5dfad0`. Not seen in a screenshot. | `field/absence-section.tsx:42-69`; `tests/e2e/ux1.spec.ts:296-316` |
| UXR-14 | **Closed in code.** Header "Menü" closes on Escape (focus back on "Menü"), on a pointer press outside and on choosing a link. Playwright UX1-26 covers Escape and outside tap; closing on item choice is in code (`onChoose`) but not asserted. | `components/layout/Sidebar.tsx:176-212`; `tests/e2e/ux1.spec.ts:319-334` |
| UXR-16 | **Closed in code.** Both "Mehr" items are neutral outline (`border-stone-400`, no `rose-`). The guarding unit test (UX1-23 widened, no `rose-` outside signal components) is PLANNED in part (g). | `field/field-client.tsx:526-537` |
| UXR-9 (UX1-7), UXR-10 (UX1-20, #548), UXR-11, UXR-3 (UX1-21) | Remedy IMPLEMENTED in code (#554), Playwright UX1-2, UX1-7, UX1-20, UX1-21 green in CI. Closing of #548 and acceptance are the PO's; I keep them open in this report until I see a screenshot. | `tests/e2e/ux1.spec.ts:67-107`, `:211`, `:276`, `:337` |
| UXR-1 (UX1-15, UX1-16, #515), UXR-6 (UX1-19 (i)), UXR-8 (UX1-19 (ii)) | Remedy IMPLEMENTED in code (#558); Playwright UX1-15/-16, UX1-19 (i) and unit UX1-19 (ii) green in CI. Not seen in a screenshot. | `(auth)/login/page.tsx`; `tests/e2e/ux1.spec.ts:358-390`; `tests/unit/ux1-contrast.test.ts:32` |
| UXR-2 (#516) | Partly IMPLEMENTED: UX1-17 class scan in CI; UX1-18 (axe `color-contrast`) PLANNED and required before UX1 is `delivered` (PO 20:15). | `tests/unit/ux1-contrast.test.ts:19` |
| UXR-15 | OPEN, PLANNED through UX1-18. Unchanged on `e5dfad0`: inline `#5f766d` and `#6b8075` remain in `teams/teams-client.tsx` (4 uses), `visits/visits-client.tsx` (6) and `partners/page.tsx` (7); also, new to this report, the pending state of the sign-in button sets white text on `#6b8075` (about 4.2:1) in `(auth)/login/login-form.tsx:65`, which UX1-18's axe run catches only if it captures the pending state. | `git grep '#6b8075\|#5f766d' src/app` |
| UXR-17 | OPEN, PLANNED (UX1-16 widened, PO 20:15: the "serverseitig" sentence goes, no new text). Still on `recovery/main`: `(auth)/login/page.tsx:31-33`. The UX1-16 unit test does not yet assert its absence. | `e5dfad0` |
| UXR-4, UXR-5 (a), UXR-7 | PLANNED (UX1-22 to UX1-24, part (g)); not in a PR yet. | `briefs/UX1.md` |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2 re-creation), then `cra`. | |
| UXR-12 | PLANNED (UX1-13 widened, part (d)); not in a PR yet. | |
| UXR-18, UXR-19 | OPEN, new (one medium, one low). | above |

**For the PO.** No new issue (no severe or high finding). (1) UXR-18 is cheapest inside UX1 part (d) (same file, same dialog); because it can hide the CGR-32 past-planned notice and a refused absence, I suggest it before UX1 is `delivered`; the trade-off and placement are yours, and `cra` confirms how the notice is shown. (2) UXR-17 is placed but not yet built; the UX1-16 test could assert the sentence is gone. (3) Screenshot access is still refused to this role's session (proxy refuses the artifact storage host); every review so far is code-only. I propose only.

---

## 2026-10-27 19:51 CET · `uxa`: UX1 parts (c) PR #554 and (f) PR #558 reviewed; #535 merged

**What changed since 15:50.** Merged into `recovery/main` (now `ddc62cd`): **#535** UX1 parts (a), (b), (e) as `e68ba84` (phone frame `AppFrame`, role-filtered menu, UX1-14 screenshot job), my 15:50 section (#549), `cra` #532 (C-1 to C-4) and #555, `lca` #547 and #556, PO #552, #557, #559 (UXR-10 placed as UX1-20, UXR-3 as UX1-21, UXR-4/-5 (a)/-7 as UX1-22 to UX1-24, UXR-11 into UX1-20, UXR-12 into UX1-13). No other screen code merged. **Open PRs with screen changes:** #554 UX1 part (c) + UX1-20 + UX1-21 (head `19ec040`; no check runs listed on that head when I looked; CI green on earlier heads per the journal) and #558 UX1 part (f) (head `c661cc6`, stacked on #554; CI green: app, db, e2e, ui-screenshots). `cra`'s gate on the `/field` order (UX1-6) and the string list is still open on #554 (journal 17:35, 19:15). Open `ux` issues: #506 to #510, #515, #516, #548; none closed. No benchmark this run (made 10:42 today).

**Sources.** `ui-screenshots` artifacts now exist for `recovery/main` (newest 12761531766 on `ddc62cd`, 18:41 UTC) and for #558 (12759040118 on `c661cc6`); none listed for #554's head `19ec040` (newest for part (c): 12754105053 on `9f39df7`). **Downloading was again refused by this session's network proxy** (storage host `productionresultssa2.blob.core.windows.net` answered 403 to CONNECT), and this session has no Docker daemon to run the capture job locally, so **no screenshots were available to me in this run**. Both PRs are reviewed from their code (`git diff recovery/main...19ec040`, `git diff 19ec040...c661cc6`). The live project was not touched.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-13 | `/field` "Ich kann nicht arbeiten", nurse, keyboard and screen reader (#554) | medium | New in #554: the absence form moved from an inline section into an overlay with `role="dialog"` and `aria-modal="true"`, but nothing moves focus into it, Escape does not close it, Tab is not kept inside and focus does not return to the button. A keyboard user stays on the trigger behind the overlay; a screen-reader user is told everything outside is inert while focus sits outside. Pointer and touch use is unaffected. Reporting that she cannot work is what lets the team re-cover her visits (ABS1). | `field/absence-section.tsx:47-53` (`19ec040`; no `focus`, `Escape` or `onKeyDown` in the file) | §6 dialogs (new rule), WCAG 2.4.3, 2.1.2 | Presentation only: native `<dialog>` with `showModal()`, or focus to the first field on open, Escape closes, focus back to "Ich kann nicht arbeiten". Playwright at 390 × 844: after the tap `document.activeElement` is inside `[role=dialog]`; `Escape` closes it and focus is on `absence-open`. Absence command, fields and texts unchanged. Best fixed inside #554. | report; PR comment #554 |
| UXR-14 | header "Menü" on `/field`, `/team`, `/work`, nurse, phone (#554) | low | The new `HeaderMenu` is a `<details>` pop-over placed over the page; it closes only by tapping "Menü" again. A tap outside, Escape or choosing the same page leaves it open over the next visit card. | `components/layout/Sidebar.tsx:176-193` (`19ec040`) | §5 header menus (new rule) | Close on Escape, outside tap and item choice. Playwright: open "Menü", press Escape, `header-menu` has no `open` attribute; tap on the page body, same. Can ride UX2-1. | report; PR comment #554 |
| UXR-15 | `/visits` (and `/teams`, `/partners`), every member, phone and desktop | medium | IMPLEMENTED defect, not changed by #558: first-MVP pages set secondary text with inline styles, `#6b8075` (about 3.9:1 on `#f4f7f4`, 4.2:1 on white) and `#5f766d` (4.5:1 on `#f4f7f4`, borderline). UX1-17's scan in #558 matches Tailwind opacity classes only, so it passes while these stay below 4.5:1. `/teams` and `/visits` are captured for every member (UX1-14). | `visits/visits-client.tsx:120`, `:131`, `:202` (6 uses), `teams/teams-client.tsx:128`, `:164` (`c661cc6`); `tests/unit/ux1-contrast.test.ts:9` | §6 secondary text | UX1-18 (axe `color-contrast` in the screenshot job, PLANNED) covers `/teams`, `/visits` and fails on them; until then the UX1-17 scan also flags inline `color:` hex values with less than 4.5:1 on their page background, or these pages use `text-secondary`. If UX2 retires these pages first, the finding closes with them (PO's order). | report; PR comment #558 |
| UXR-16 | `/field` visit card "Mehr", nurse, phone (#554) | low | Inside "Mehr", "Abrechnungssperre setzen" keeps its red outline and red text (rose-400 / rose-900), the P1 signal colour family; it was already red before #554, now it is the only coloured item in a neutral menu. The consequence sentence in the confirming step (`HOLD_CONSEQUENCE`) already carries the weight. | `field/field-client.tsx:534-535` (`19ec040`) | §3 reserved severity colours; §7 `signal-p1` "never: destructive actions" | Neutral `action-outline` for both "Mehr" items. Unit test (extends UX1-23): no `rose-` class in `field-client.tsx` outside signal components. | report; PR comment #554 |
| UXR-17 | `/login`, every role, phone (#558) | low | The remaining panel says "Die Sitzung wird serverseitig geprüft." A nurse cannot act on it and it explains nothing she needs; at 390 px it is the only thing below the sign-in card. Otherwise #558 meets UX1-15/-16 in code (one column below 768 px, card first, "Bei NAVORA anmelden", 16 px inputs). | `(auth)/login/page.tsx:29-34` (`c661cc6`) | §4 plain words, say what happens; §5 density | Either drop the panel on phones or replace it with one sentence that helps (e.g. who to ask for a new access); wording is the PO's, and `lca` looks at it if it talks about data or sessions. | report; PR comment #558 |

**#554 otherwise (code, no screenshot).** UX1-6: order on `/field` is signals, a "Zu erledigen" link row, "Als Nächstes" next visit, "Weitere Einsätze", then open decisions, reports, "Offen im Team", cover, absences, workday link and counters; the SIG1 banner stays first. The interrupted-visit decision queue (CSR1/CGR-25) now sits below the visits with a link at the top; how that safety-related state is placed is `cra`'s gate on #554, not my call. UX1-7: the always-open observation form's submit is now outline, so the card keeps one filled status button. UX1-8: "Einsatz absagen" and "Abrechnungssperre setzen" behind "Mehr", each form opens with one consequence sentence and scrolls into view. UX1-20: "Menü" (44 px) in the three headers, "Abmelden" last inside it, "Meine Einstellungen" kept when the membership read fails (`cra` 17:35). UX1-21: lead line and six headings exactly as `lca` 11:41. These look met in code; visual confirmation UNKNOWN until I can see the screenshots.

**#558 otherwise (code, no screenshot).** `text-secondary` = stone-700 (about 9.5:1 on `#f4f7f4`, 9.9:1 on amber-50); `color-scheme: light` and the dark override removed (UXR-8); `/intake` fields `w-full min-w-0` with `minmax(0,1fr)` columns (UXR-6). UX1-18 (axe) is PLANNED for the next PR.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| U3 (#506), U2 (#507) | Remedy merged in code (UX1-1, UX1-3; #535 `e68ba84`, CI green). Not closed by me: no screenshot seen, and acceptance is the PO's. | `Sidebar.tsx` `AppFrame`, `nav.ts` |
| UXR-10, UXR-11, UXR-3 | PLANNED, built in open PR #554 (UX1-20, UX1-21); OPEN until merged and seen | PR #554 |
| UXR-1, UXR-2, UXR-6, UXR-8 | PLANNED, built in open PR #558 (UX1-15 to UX1-17, UX1-19); UXR-2 also needs UX1-18 (see UXR-15) | PR #558 |
| UXR-9 | PLANNED, built in open PR #554 (UX1-7) | PR #554 |
| UXR-4, UXR-5 (a), UXR-7 | PLANNED (UX1-22 to UX1-24, part (g)); not in a PR yet | `briefs/UX1.md` |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2 re-creation), then `cra` | |
| UXR-12 | PLANNED (UX1-13 widened, part (d)); not in a PR yet | |
| UXR-13 to UXR-17 | OPEN, new (two medium, three low) | above |

No finding closed: nothing on `recovery/main` yet shows a UXR remedy I could verify by screenshot or test.

**For the PO.** No new issue (no severe or high finding). (1) UXR-13 is cheapest to fix inside #554 before merge; whether it blocks acceptance of UX1-6a is yours. (2) UXR-15: either UX1-18 lands before UX1 is `delivered`, or the inline-colour gap is accepted until UX2 retires `/teams` and `/visits`; your trade-off. (3) Screenshot access: this role cannot download CI artifacts from its session (proxy refuses the artifact storage host); until that changes every review is code-only. I propose only.

---

## 2026-10-27 15:50 CET · `uxa`: UX1 (a)(b)(e) PR #535 reviewed; `cra` answers to C-1 to C-4 recorded

**What changed since 11:49.** Screen code on `recovery/main` (`99063e6`): only #502 (COND2-4) merged, two fact lines under the RET1 review task on `/team` (`team-client.tsx:525-531`); the merged lines use `text-emerald-900/80` (at the 80 % floor of UXR-2) and plain words; unchanged from the head I reviewed at 10:42: no finding. **Open PR #535** (UX1 parts (a), (b), (e); head `bcfb62d`, CI green on run 40509863737): new `AppFrame` and `MobileMenu` in `src/components/layout/Sidebar.tsx`, the menu filtered by each page's own check (`src/lib/auth/nav.ts`), `/settings`, `/admin`, `/operations` moved into the frame, and the UX1-14 screenshot job. `cra` answered my requests C-1 to C-4 in its 13:37 review, **in open PR #532 (not merged)**. New approved briefs AIG1, ASM1, PLAN3 (PO 13:35, AIG1-5 and PLAN3-5/-7 amended 15:20) define future confirmation screens; design-system pattern added (below). No benchmark this run (made at 10:42 today). Open `ux` issues: #506-#510, #515, #516; none closed.

**Sources.** The first CI `ui-screenshots` artifact exists (artifact 12737585342, PR #535 head `bcfb62d`, 13:14 UTC, expires 2026-11-10). **Downloading it was refused by this session's network proxy** (the storage host answered 403 to CONNECT), so **no screenshots were available to me in this run**; #535 is reviewed from its code (`git diff recovery/main...bcfb62d`). For `recovery/main` there is no artifact yet (the job arrives with #535). The live project was not touched.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-10 | `/field`, `/team`, `/work`, nurse, phone | high | IMPLEMENTED defect, not changed by #535. The nurse's screens have no menu: the `/field` header offers "Teamanfragen" and "Abmelden" only (`field-client.tsx:117-128`), `/team` offers "Teamzahlen" and "Mein Tag" (`team-client.tsx:94-100`); no screen she opens links to `/settings` (`git grep '/settings'` under `src`: only the menu table). `/settings` is where she switches on push for P1 safety signals (SIG2); today she can reach it only by typing the address. #535 gives `/settings` a phone-width frame and a role-filtered menu, but the frame wraps only `/settings`, `/admin` and `/operations`, so a nurse never sees that menu. UX1-2 (e2e push opt-in at 390 px) opens `/settings` directly and would pass while the page stays unreachable. UX2-1 (tab bar with "Mehr") fixes it and the UX2 brief names the gap (`briefs/UX2.md:15`), but UX2 is *Next up* 5, after ADM2, AIG1 and ASM1. Seed state: 0 of 2 team members have push on (UXR-7). | `field-client.tsx:117-128`, `team-client.tsx:94-100`, `work-client.tsx` (no menu link) on `99063e6` and on `bcfb62d`; `Sidebar.tsx:141-160` (`bcfb62d`, `MobileMenu` used only by `AppFrame`); `briefs/UX1.md` UX1-2 | §1 (what needs attention now: being reachable for safety signals); §5 one navigation | Interim until UX2-1, presentation only: `/field` (and `/team`, `/work`) show a route to the role's menu or at least to "Meine Einstellungen" in the header, inside the first viewport at 390 × 844. Playwright as the seed nurse at 390 × 844: start at `/field`, reach `/settings` in at most two taps without typing a URL, then complete the UX1-2 opt-in from there. No change to SIG2, the page checks or the menu table. Trade-off (UX1 scope vs waiting for UX2) is the PO's. | #548 |
| UXR-11 | `/settings`, `/admin`, `/operations`, every role, phone (#535) | low | In the new phone top bar "Abmelden" is an outlined pill on the right of the brand, the most prominent control in the bar, and signs out in one tap; "Menü" is a plain row under it. On `/field` the same action is a text button. Sign-out is the action she needs least during a shift. | `Sidebar.tsx:148-155` (`bcfb62d`), `SignOutButton` `:31-48`; `field-client.tsx:123-127` | §2 action hierarchy; §7 one component per job | In the phone bar "Abmelden" becomes the last item inside "Menü" (or a text button like `/field`); "Menü" stays at least 44 px high. Playwright at 390 px: the bar shows one control besides the name; "Abmelden" is visible after opening "Menü". Can ride UX2-1. | report; PR comment #535 |
| UXR-12 | phone top bar and desktop sidebar, every role (#535) | low | The new phone bar adds another "Navora" (mixed case, `Sidebar.tsx:150`); the desktop sidebar keeps "Swiss Care OS", "Navora", "Pilot Schweiz", "Navora MVP" (`:104-129`); menu labels "Operations Board", "KPI / Analytics", "Mein Tag (mobil)" are unchanged (deferred to part (d), `nav.ts:52`). One page has three names: menu "Mein Tag (mobil)", header "NAVORA · Mein Tag", `/team` link "Mein Tag"; `/field` links to `/team` as "Teamanfragen", whose heading is "Dein Team". Expected inside UX1 part (d); recorded so (d) covers the new line. | `Sidebar.tsx:104-129`, `:150` (`bcfb62d`); `nav.ts:57-111`; `field-client.tsx:120`, `team-client.tsx:94-103` | §4 one name NAVORA, plain words | UX1-13 string test also scans `src/components/layout/*` and fails on "Navora" (case-sensitive), "Swiss Care OS", "MVP", "Board", "Analytics"; one label per page used in the menu, the page heading and every link to it (unit test on `nav.ts` labels against the page headings). | report; PR comment #535 |

**#535 otherwise (code review, no screenshot):** the phone frame follows the brief (one column below 768 px, `min-w-0` content, `md:grid-cols-[280px_1fr]`); menu links are about 52 px high, "Menü" is a native `<details>` with `min-h-11` (keyboard operable); `aria-current="page"` on the active item; white on `#16392d` is well above 4.5:1; the menu fails closed outside its provider. UX1-1, UX1-3, UX1-4 look met in code; verified only once I can see the screenshots (UNKNOWN).

### `cra` answers to C-1 to C-4 (13:37, open PR #532, not merged)

Recorded as `cra` wrote them; the substance is `cra`'s. They take effect for a brief once #532 is merged and the PO places them.

- **C-1 (UXR-4): confirm with change.** One full card plus a pointer line in the list only if the list entry adds nothing the card lacks; an entry with its own action (e.g. the interruption follow-up form for `visit_interrupted`, `team-client.tsx:196-199`), flags or handling state keeps them visible. The clearance text may sit behind "Wann erledigt sich das?", but its last sentence "Schwellen und Regeln provisorisch (klinische Entscheidungen offen)" stays visible. Test: e2e at 390 px, the follow-up form reachable in one tap, the "provisorisch" sentence visible without expanding.
- **C-2 (UXR-5): (a) confirm**: the intake urgency is a criteria-free label, not a SIG1 signal; amber with the word kept. **(b)** facts only, `cra` does not write the sentence: removing a planned visit deletes it, the reason is logged; no missed-visit or uncovered alert can follow; refused once anything was recorded. Whether PLAN2 re-creates a removed care-plan visit: UNKNOWN (`eng` to state). The sentence should say the care planned for that time will not take place unless someone plans it again.
- **C-3 (UXR-7): confirm.** Seen without expanding, amber, not the P1 colour; wording with change, e.g. "Nicht alle erhalten Sicherheitssignale ausserhalb der App" (PO and `uxa` choose). No per-member detail beyond active / not active.
- **C-4 (signal card): confirm with change.** The four rules may become acceptance criteria; "Sicherheitssignal:" is a suitable prefix; "exactly one action per P1 card" becomes "one primary action first; no action a card has today is removed or moved off the card".

**UX view (advisory).** All four changes keep the purpose of the proposals. For C-2 (b) my proposed sentence, for `cra` to confirm once `eng` answers the PLAN2 question: "Der Einsatz wird gelöscht. Die geplante Pflege findet zu dieser Zeit nicht statt, ausser jemand plant sie neu." (UNKNOWN whether "ausser jemand plant sie neu" is complete while PLAN2 may re-create it.) For C-3 I take `cra`'s wording as is, plus a link "Meine Einstellungen", which needs UXR-10's route to `/settings` to be useful.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-4 | OPEN → ready for placement once #532 is merged. Testable remedy now: signal cards unchanged and first; a list entry that only repeats a card shows one line "Steht oben als Sicherheitssignal"; entries with own action, flags or state keep them; clearance text behind "Wann erledigt sich das?" except the "provisorisch" sentence. Playwright at 390 px on the seed team: "Anfragen an dein Team" moves up; the `visit_interrupted` follow-up form reachable in one tap; the "provisorisch" sentence visible without expanding. | `cra` C-1, PR #532 |
| UXR-5 | OPEN → (a) ready once #532 is merged (urgency "hoch" amber with the word; unit test: `signal-p1` classes only in signal components); (b) waits for `eng` (PLAN2 re-creation) and then `cra` on the sentence; development banner part unchanged (Engineering's, `lca`). | `cra` C-2, PR #532 |
| UXR-7 | OPEN → ready once #532 is merged: line open and amber while fewer than all active members have push on, text "Nicht alle erhalten Sicherheitssignale ausserhalb der App", link "Meine Einstellungen"; collapsed and neutral when all are on. Playwright with the seed team (0 of 2): text and link visible without expanding. | `cra` C-3, PR #532 |
| UXR-3 | OPEN, ready for placement (unchanged since 11:49) | `D-23.md` |
| UXR-1, UXR-2, UXR-6, UXR-8, UXR-9 | PLANNED (UX1-15 to UX1-19, UX1-7); not in #535 | `briefs/UX1.md` |
| UXR-10 | OPEN, new (high) | above |
| UXR-11, UXR-12 | OPEN, new (low) | above |

No finding closed: nothing is on `recovery/main` that shows a remedy.

**For the PO.** (1) UXR-10: decide whether an interim route from `/field` to `/settings` rides UX1 (e.g. with part (c), which already changes the `/field` header) or waits for UX2-1; issue #548. (2) Once #532 is merged, UXR-4, UXR-5 (a) and UXR-7 can be placed; my suggestion is one small `/team` presentation item or UX1 part (c). (3) UXR-3 still waits for placement. Order is yours; I propose only.

---

## 2026-10-27 11:49 CET · `uxa`: `lca` answer to L-1 recorded

**What changed since 11:19.** `lca` answered request L-1 (UXR-3) in its D-23 re-check of 11:41, in PR #520 (`docs/agents/decisions/D-23.md`, merged into `recovery/main` as `647c14f` during this run). No screen code changed (`recovery/main` `39f90e5`, PO 11:45 #521 docs only; last screen change before `56d62e0`); open PRs: #502 (COND2-4, `team-client.tsx`, unchanged since my 10:42 review of head `19731a6`); #520 and #521 (docs only) merged during this run. No new `ui-screenshots` artifact (newest still from `tools/ui-screenshots`, 08:22 UTC; UX1-14 not built: OPEN). No `cra` answer yet to C-1 to C-4. No benchmark this run (made at 10:42). No new findings.

### `lca` answer to L-1 (UXR-3, `/work` working-time notice): confirm with change

Recorded as `lca` wrote it (D-23, 11:41, PR #520); the substance is `lca`'s and I do not reword it.

- Lead line and paragraph headings over the unchanged `work1-notice-v3` paragraphs: compliant on the sources `lca` read (draft, synthetic data), on three terms:
  1. Lead line without "Einmal" and without "bestätigen" (the acknowledgement is per version; "bestätigen" can read as consent). `lca` proposes: "Bitte lies diese Information und tippe dann auf «Gelesen und verstanden». Danach siehst du deinen Arbeitstag. Ändert sich die Information, zeigen wir sie dir noch einmal."
  2. Headings: "Wer deine Einsatzzeiten sieht" (§1), "Was nur du siehst" (§2, new), "Was NAVORA protokolliert und was die Administration sieht" (§3), "Was du tust (auch vor dem Ende deines Zugangs)" (§4, advised, not required), "Der Anteil für das ganze Team" (§5), "Was NAVORA nicht prüft" (§6).
  3. Lead line and headings are fixed text in `rules.ts` next to the paragraphs and part of the employer's final text; any other wording needs one `lca` look before merge. A new `NOTICE_VERSION` is not legally needed for this change (product choice).
- My proposal as written (five headings, "Einmal … bestätigen") is **not recommended** by `lca`. I withdraw it in favour of the `lca` wording.

**UX view of the `lca` wording (advisory).** The three-sentence lead line answers both questions UXR-3 raised (what do I do, what comes after) and says honestly when the notice returns; the third sentence also answers "will I see this every day?". The headings are longer than mine but each is accurate, and a nurse scanning them sees every recipient (her, the administration, the team). No objection. The Playwright criterion stays: the lead line and the first heading inside the first viewport at 390 × 844. With headings of this length, the first heading may only fit if the lead line is set as body text, not as a large heading: UNKNOWN until a screenshot exists (UX1-14).

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-3 | OPEN → ready for placement by the PO: `lca` confirm with change (D-23, 11:41, PR #520). Testable remedy now: words of `work1-notice-v3` unchanged; lead line and six headings exactly as `lca` 11:41, held in `rules.ts`; Playwright at 390 × 844 on `/work` before acknowledgement: lead line and first heading in the first viewport; a string test that each heading and the lead line equal the `rules.ts` constants. Stays OPEN until the PO places it. | PR #520 `D-23.md` |
| UXR-1, UXR-2, UXR-6, UXR-8, UXR-9 | PLANNED, unchanged (UX1-15 to UX1-19, UX1-7) | `briefs/UX1.md` |
| UXR-4, UXR-5, UXR-7 | OPEN, waiting for `cra` (C-1 to C-4, 11:19) | |

**For the PO.** UXR-3 can be placed (my suggestion: with UX1 part (c), the `/work` and `/field` text work, since it is presentation and fixed text only). The order is yours; I propose only.

---

## 2026-10-27 11:19 CET · `uxa`: owner approval, placement, requests to `cra` and `lca`

**What changed since 10:42.** Owner instruction in this session (2026-10-27): approves the `uxa` findings and recommendations; #515 is a pilot-readiness blocker to be placed ahead of non-critical UX improvements; #516 a high-priority accessibility and usability item; all UX findings run through the normal `agent:po` workflow; `uxa` coordinates with `cra` and `lca` where a finding needs confirmation; escalate only strategic decisions or roadmap trade-offs. PO 11:10 (#518) had already placed #515 and #516 (with UXR-6 and UXR-8) as **UX1 part (f)**, UX1-15 to UX1-19. Labels checked: #506-#510, #515, #516 all carry `agents`, `agent:po`, `ux` (severe ones also `ux:severe`); nothing to add. No screen code changed (`recovery/main` `72e6603`; `git diff 56d62e0 72e6603 -- src` empty); no new screenshot artifact. No new findings.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-1 | PLANNED (UX1-15, UX1-16) | `briefs/UX1.md` part (f), PO 11:10 |
| UXR-2 | PLANNED (UX1-17, UX1-18) | same |
| UXR-6 | PLANNED (UX1-19 (i)) | same |
| UXR-8 | PLANNED (UX1-19 (ii)) | same |
| UXR-9 | PLANNED (UX1-7) | PO 11:10 journal |
| UXR-3 | OPEN, waiting for `lca` (request L-1 below) | |
| UXR-4, UXR-5, UXR-7 | OPEN, waiting for `cra` (requests C-1 to C-4 below) | |

**Proposal to the PO on order inside UX1 (owner: #515 is a pilot-readiness blocker).** UX1 stays *Next up* 2; I do not reorder. Proposal only: build UX1-14 (screenshots) and UX1-15/UX1-16 (sign-in) in the first UX1 PR, together with part (a), so the sign-in fix does not wait for the `/field` work in (c) and (d), which needs the `cra` string review. Comment on #515.

### Requests to `cra` (Clinical & Regulatory Architect)

How a safety signal or a safety-related state is shown is `cra`'s to confirm (README *UX review*). Each request asks for one answer: **confirm**, **confirm with change**, or **reject with reason**. Nothing here changes a signal's rule, threshold, recipient, text or its position above other content.

| Request | Finding | Proposal (presentation only) | Question to `cra` |
|---|---|---|---|
| C-1 | UXR-4 | On `/team`, an entry in "Einsätze mit Handlungsbedarf" that is already shown as a P1 signal card at the top shows one line "Steht oben als Sicherheitssignal" instead of repeating the card; the clearance text ("Erledigt sich, sobald …", `team-client.tsx:204`) moves behind a disclosure "Wann erledigt sich das?" with its words unchanged. The signal cards stay first and unchanged. | May a P1 situation appear once on `/team` (the signal card) with a pointer in the list, or must the list repeat it in full? May the clearance text sit behind a disclosure? |
| C-2 | UXR-5 | (a) The intake urgency badge "hoch" changes from the red family to amber with the word kept (an intake urgency is not a P1 safety signal). (b) "Entfernen" on a planned visit becomes an outline button in the neutral text colour; its existing reason step stays and gains one sentence naming the consequence. | (a) Is a referral's urgency "hoch" a safety signal that must keep the signal colour? (b) Which sentence describes the consequence of removing a planned visit correctly (UNKNOWN to me; I do not write it)? |
| C-3 | UXR-7 | On `/team`, while fewer than all active members have "Benachrichtigung ausserhalb der App" on, the line is shown open in amber with a word ("Nicht alle erreichbar") and a link to "Meine Einstellungen"; when all are on it stays collapsed and neutral. | Is a team with members who do not receive P1 signals outside the app a state the team must see without expanding? Is amber (not the P1 colour) right for it? Does the word need a different wording? |
| C-4 | design system §3 safety-signal card (benchmark 10:42) | Each P1 card: the first line names the situation and its one action; a visually hidden prefix "Sicherheitssignal:" for screen readers; exactly one action per P1 card; text after a card gets its own heading. | May these four rules become acceptance criteria in a later brief (UX2 or UX3)? Is "Sicherheitssignal:" the right prefix? |

### Request to `lca` (Legal & Compliance Agent)

| Request | Finding | Proposal (presentation only) | Question to `lca` |
|---|---|---|---|
| L-1 | UXR-3 | The working-time information on `/work` (text fixed with `lca`, `work1-notice-v3`) keeps every word and stays a one-time acknowledgement before the first workday. Added: one lead line above it ("Einmal lesen und bestätigen, danach siehst du deinen Arbeitstag") and a short heading above each paragraph (e.g. "Wer deine Einsatzzeiten sieht", "Was NAVORA protokolliert", "Was du tust", "Was dein Team sieht", "Was NAVORA nicht prüft"). | Does adding a lead line and paragraph headings (words of the notice unchanged, nothing collapsed) keep the notice compliant with the information duty it serves? Are the proposed headings accurate summaries of their paragraphs, or must any be reworded? |

When `cra` or `lca` answers (in its report or on the `uxa` PR), `uxa` records the answer in the next section and the PO decides placement; findings stay OPEN until then.

---

## 2026-10-27 10:42 CET · `uxa` first review (baseline screens, code at `56d62e0`)

**Sources.** No `ui-screenshots` artifact exists for `recovery/main` (UX1-14 not built yet: OPEN). The two `ui-screenshots` artifacts that exist come from the temporary branch `tools/ui-screenshots` (code `6abf941`, synthetic seed, 2026-10-27 08:11 and 08:22 UTC); downloading the archive was refused by this session's network proxy, so I looked at the identical images committed on that temporary branch (`1907071`, folder `ui-screenshots/`), extracted outside the repository. `git diff 6abf941 56d62e0 -- src/app src/components` is empty, so these images still show `recovery/main`. Screens not in that set (login, `/teams`, `/visits`, `/partners`, `/admin` at 390 px) were reviewed from the code. The login layout was reproduced from its inline styles as a static page in Playwright at 390 × 844 (no app server, no Supabase). The live project was not touched. Open PR with screen changes: #502 (`team-client.tsx`, two fact lines under the RET1 review task, head `19731a6`), reviewed from the diff: no finding, so no comment.

**Lost U-codes.** U8 to U15 and U17 are not recoverable from the repository (UNKNOWN). Where a finding below probably re-finds one of them, I do not claim so; numbering starts at UXR-1.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-1 | `/login`, every role, phone | severe | IMPLEMENTED defect. The sign-in page is a fixed two-column grid (`1.05fr 0.95fr`, 56 px padding) with no breakpoint. At 390 px the page is 724 px wide and the sign-in form is entirely outside the first viewport; the inputs are about 131 px wide. The first screen a nurse sees on her phone shows a dark panel without a form. The page also addresses the wrong people ("Admin / Coach Portal", "Admin / Coach anmelden", although nurses sign in here and land on `/field`), uses first-MVP and English terms ("Attention Center", "Operations-Lage", "Teams Übersicht") and writes "Navora". Not covered by UX1 (a) (`/settings`, `/admin`, `/operations` only) and excluded from UX2 ("login page design beyond using the same tokens"). | `src/app/(auth)/login/page.tsx:21-30` (grid), `:51`, `:62`, `:75-76`, `:81-87`, `:127`; reproduction from these styles at 390 × 844: `scrollWidth` 724, form off-screen | §5 phone first; §4 language, one name NAVORA | Below 768 px one column, form first, the explanatory panel below or removed. Playwright at 390 × 844 on `/login`: `scrollWidth <= 390`; the e-mail input, the password input and "Anmelden" are inside the first viewport; each input at least 300 px wide. Heading addresses every user (e.g. "Bei NAVORA anmelden"); no "Admin / Coach", "Attention Center", "Teams Übersicht"; "NAVORA" in capitals. Sign-in logic unchanged. | #515 |
| UXR-2 | every Tailwind screen (`/field`, `/team`, `/work`, `/intake`), all roles | high | IMPLEMENTED defect. Secondary text is set with reduced opacity: `text-emerald-900/60` (32 uses), `/70` (23), `/50` (2). On white and on `stone-100` this gives roughly 2.6:1 (/50), 3.3:1 (/60) and 4.1-4.3:1 (/70), below the WCAG 2.2 AA minimum of 4.5:1 for normal text; most uses are `text-xs` or `text-sm`. These lines carry facts a nurse acts on ("noch niemand verantwortlich", the reason a visit was moved, "seit 26 h"). Ratios are my calculation with Tailwind's emerald-900 approximated as `#064e3b`; exact values with Tailwind v4's oklch palette: UNKNOWN until axe runs (UX2-8). | `grep text-emerald-900/(50,60,70)` under `src/app`, `src/components` (57 uses); e.g. `team-client.tsx:968`; screenshot `team-phone.png` (meta lines under the P1 cards) | §6 accessibility floor | One `text-secondary` token with at least 4.5:1 on every surface it is used on (proposal in §7: `stone-700` or `emerald-900` at ≥ 80 %); no text colour with opacity below 80 % for text under 18 px. Automated: axe `color-contrast` on every protected route in the screenshot job (UX1-14/UX2-8), serious and critical fail, not only on the shell. | #516 |
| UXR-3 | `/work`, nurse, phone, first use | medium | The working-time notice (fixed with `lca`, WORK1) fills the screen: about 1,050 px of continuous text before the only action "Gelesen und verstanden"; nothing tells her how long it is or that it appears once. The notice must stay; its scanability is the problem. | `work-phone.png`; `work-client.tsx:52-74` | §5 density; §1 (what do I do next) | Words unchanged. Proposal for `lca`: a one-line lead ("Einmal lesen und bestätigen, danach siehst du deinen Arbeitstag"), a short heading per paragraph (who sees what; what NAVORA logs; what you do; what the team sees; what NAVORA does not check). Playwright: the lead and the first heading are in the first viewport. `lca` must confirm any change of the notice's presentation. | report only |
| UXR-4 | `/team`, team member and coach, phone | medium | The same two P1 situations appear twice at the top: as safety-signal cards (SIG1 banner) and again in "Einsätze mit Handlungsbedarf" directly below, followed by a nine-line explanation in small red text of when each item clears. The first screen is spent on the same two facts and a rules paragraph; the team's own decisions ("Anfragen an dein Team", the clients) start far below. | `team-phone.png`, `team-phone-top.png`; `team-client.tsx:204`; `SignalBanner.tsx:57-69` | §1 three questions; §5 density; rule shown as reason, not lecture (roadmap) | No change to the signal cards, their position or text (`cra`). Proposal for `cra`: the "Handlungsbedarf" list collapses entries that are already shown as a signal card above ("auch oben als Sicherheitssignal") and the clearance explanation sits behind "Wann erledigt sich das?". Playwright at 390 px: "Anfragen an dein Team" heading moves up by at least the height of the duplicated entries. `cra` must confirm. | report only |
| UXR-5 | `/team`, `/intake`, every page (development banner) | medium | The red family reserved for P1 safety signals is also used for: "Entfernen" (red link and red submit) on planned visits; the urgency badge "hoch" at intake; the development banner on every page (`#7f1d1d`). Red then no longer means "safety signal". | `team-client.tsx:983`, `:998`; `intake-client.tsx:30`; `src/app/layout.tsx:36-45`; `intake-desktop-top.png`, `team-phone.png` | §3 reserved severity colours | Destructive actions: outline button in the neutral text colour plus the existing reason step that names the consequence; urgency badge with the word in amber or neutral (urgency of a referral is not a P1 signal; `cra` confirms); development banner in a neutral dark stripe with its text unchanged (SR-02/SR-07; its content stays Engineering's and `lca`'s). Unit test: the `signal-p1` colour classes appear only in signal components. | report only |
| UXR-6 | `/intake`, intake role, desktop | medium | IMPLEMENTED defect. In "Neue Anfrage erfassen" the "Ort" input sticks out of the form card; "Region" and "Ort" overlap. The two inputs sit in a two-column grid without `w-full min-w-0`, so they keep the browser's intrinsic width. | `intake-desktop-top.png`; `intake-client.tsx:171-178`, `:35` | §7 components (one input style); §5 | `field` class gains `w-full min-w-0`. Playwright at 1440 and 390: every input's right edge is at most the form's right edge. | report only |
| UXR-7 | `/team`, team member and coach | medium | "Benachrichtigung ausserhalb der App: 0 von 2 aktiv" is a collapsed, neutral line. That nobody in the team receives safety signals outside the app is shown at the weight of a footnote. | `team-phone.png`; `team-client.tsx:1023` | §1 (what needs attention now); §3 | Proposal for `cra` (how a safety-related state is shown is `cra`'s): while fewer than all active members have push on, the line is shown open, in amber, with a word ("Nicht alle erreichbar") and a link "Meine Einstellungen" to `/settings`. Playwright with the seed team (0 of 2): the link is visible without expanding. | report only |
| UXR-8 | every protected screen, phone in dark mode | low | First task "dark mode" (design system §3, UNKNOWN): **no defect found in code.** `globals.css` switches `body` to `#0a0a0a`/`#ededed` under `prefers-color-scheme: dark`, but every protected page root and the login page set their own background and text colour (`field-client.tsx:116`, `team-client.tsx:90`, `work-client.tsx:313`, `intake/page.tsx:14`, `analytics-client.tsx:33`, `admin-client.tsx:64`, `settings-client.tsx:86`, `operations-client.tsx:66-68`, `partners/page.tsx:15-17`, `login/page.tsx:24-28`). Residual risk: native form controls follow the system scheme because no `color-scheme: light` is declared. Not verified on a rendered page: UNKNOWN until a screenshot exists. | code as listed | §3 | Declare `color-scheme: light` on `:root` until a dark theme is designed; UX1-14 adds one capture of `/field` with `colorScheme: 'dark'`. | report only |
| UXR-9 | `/field`, nurse, phone | low | Above the fold three saturated action colours compete: red "Ich übernehme" (signal), blue "Ich kann nicht arbeiten", orange "Übernehmen". Part of #509 (UX1-6a, UX1-7); recorded so the UX1 screenshots are checked for it: after UX1 only the signal card keeps its own colour, every other filled button is the primary token. | `field-phone-top.png` | §2, §3 | UX1-7 plus: no filled button outside a signal card uses a colour other than `action-primary`. | #509 |

### Benchmark (2026-10-27): urgency cards in the NHS design system

Read on 2026-10-27: NHS digital service manual, *Care cards* ([service-manual.nhs.uk/design-system/components/care-cards](https://service-manual.nhs.uk/design-system/components/care-cards)). In my words: the NHS uses three card types for three levels of urgency. Colour supports the level, but the heading carries it: each heading is one plain call to action, and a visually hidden prefix tells screen-reader users the urgency. The most urgent card allows one action and no other links. Several cards on one page are allowed only when needed, ordered by seriousness, and text after a card gets its own heading so it is not read as part of the card.

What NAVORA should adopt, and why: (1) the safety-signal card's first line names the situation and the one action, and a hidden prefix ("Sicherheitssignal:") gives screen readers the level that sighted users get from colour (§3: never meaning only in colour); (2) a P1 card has exactly one action; (3) the same situation is not shown in two stacked cards (UXR-4); (4) a paragraph after a card gets its own heading. Items (1) to (3) concern how a safety signal is shown: `cra` must confirm before any brief uses them. Nothing is copied: no design, text or asset of the NHS.

### Design system changes in this run
Token proposal recorded in §7 (before UX2); dark-mode question answered from code (§3, UXR-8); text contrast rule for secondary text (§6); login added to the phone-first scope (§5); signal-card pattern added as OPEN (§3).

### Waiting for the PO
UXR-1 (severe, login at phone width) is not in any brief; UXR-2 (high, text contrast) is only partly in UX2-8 (axe on the shell). Both opened as issues for placement: #515 (UXR-1), #516 (UXR-2). Medium and low findings (UXR-3 to UXR-9) stay in this report; UXR-3, UXR-4, UXR-5 and UXR-7 need `cra` or `lca` before any brief uses them.

---

## 2026-10-27 10:40 CET · baseline (seeded by `po`, not a `uxa` review)

The UX review of 2026-10-27 (screenshots of `recovery/main` at `6abf941`, synthetic seed) used the codes U1 to U18; its severe findings are open as issues and placed by the PO. `uxa` takes them over as below and continues from **UXR-1**; the other U-codes of that review (U8 to U15, U17) are not in the repository: UNKNOWN, `uxa` re-finds them from CI screenshots instead of from memory.

| Earlier code | Issue | Severity | Placed in | Status |
|---|---|---|---|---|
| U1, U16, U18 | #510 | severe | UX2 (*Next up* 4) | PLANNED |
| U2 | #507 | severe | UX1 (b) | PLANNED |
| U3 | #506 | severe | UX1 (a) | PLANNED |
| U4 | #508 | severe | UX1 (d) | PLANNED |
| U5, U6, U7 | #509 | severe/high | UX1 (c) | PLANNED |

First tasks for `uxa`: (1) check the dark-mode question in design system §3 (UNKNOWN); (2) as soon as UX1-14 produces CI screenshots, a full baseline review of every protected route per role at 390 px and 1440 px; (3) propose tokens for design system §7 before UX2 starts; (4) a benchmark section (modern healthcare and SaaS products), described in words, with the patterns worth adopting and why.
