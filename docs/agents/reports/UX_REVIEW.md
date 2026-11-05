# UX Review Report

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *UX review*. **Reference:** [`../../design/DESIGN_SYSTEM.md`](../../design/DESIGN_SYSTEM.md).

Newest dated section first; never edit an earlier section, correct it in a new one. Each finding: `UXR-<n>` | screen and role | severity (`severe`, `high`, `medium`, `low`) | finding | evidence (CI screenshot artifact and commit, file:line) | principle broken (design system §) | testable remedy | issue.

---

## 2026-11-05 11:50 CET · `uxa`: no screen code changed; `cra` 09:30 (#870) confirms CGR-134 sentence 5 and the reverse-pair line (no example after "unterbrochen"); #868 rebuilt docs-only (my 07:50 note closed); merge path now with the PO (#861, `PO_MERGE_PROCESS.md`); no new finding

**What changed since 07:50.** `recovery/main` moved from `9e3b998` to `aeb566b` with `po` #868 only (`COORDINATION.md` rule 4, `PO_MERGE_PROCESS.md`, `OWNER_AGENDA.md`, `JOURNAL.md`); **no change under `src`, `tests` or `e2e`** (`git diff --stat 9e3b998 aeb566b -- src tests e2e` is empty). No open screen PR head moved since 07:50 (the newest updates are `gov/` #870 and `aia/` #869, docs only). No new UX brief; no `ux` issue changed. New input for me: `cra` 09:30 on #850 and in #870 (`9fc0636`); `po` 10:56 and 11:30 (merged with #868).

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `cra` 09:30 comment on #850; `JOURNAL.md` `po` 10:56 and 11:30; `PO_MERGE_PROCESS.md` (§4 conditions, role docs PRs). No benchmark (made 07:50 today). I ran no test; CI is the test runner. Live project not touched.

### `cra` 09:30 taken (all wording still PROPOSED for the draft FAM1)

- **CGR-134:** sentence 5 of the client information is confirmed on facts as written at 07:50: "Die Ansicht endet spätestens, wenn Sie Ihre Einwilligung zurückziehen; sie endet auch, wenn Ihre Pflege unterbrochen wird oder endet, und beginnt danach nicht von selbst wieder." "unterbrochen" covers all four pause reasons (`hospital_stay`, `rehabilitation`, `client_absence`, `other`; `cra` cites 0024:212). **No example is added** ("zum Beispiel bei einem Spitalaufenthalt" is withdrawn as an option): one example reads as the only case, which is the same narrowing CGR-134 names. Recorded as a general rule in `DESIGN_SYSTEM.md` §4 (v42). Team revocation (FAM1-3) stays with `lca`; how a client learns of a protective revocation is a Clinical Owner procedure, not page text, so the page carries no sentence for it.
- **CGR-132:** the reverse-pair refusal line is confirmed. `cra` does not ask for a hint such as "frage sie selbst" (it would steer a capacity judgement); I add none.

### Closed notes

- **#868 carried the #799 shell code (my 07:50 note to the PO):** closed. `po` 10:56 rebuilt the branch docs-only (CGR-135); #868 merged as `aeb566b` with no file under `src`. #799 (`642edf0`) is unchanged.

### Merge of this PR

`po` 11:30 records the owner's answer on #861: the PO is the only role responsible for merge decisions, and `PO_MERGE_PROCESS.md` lists role docs PRs (`ux/` included) among the PRs the PO merges (CI green, no open comment, own files only, no `src/`, `supabase/`, `tests/`, `e2e/` file). The PO notes the owner can say otherwise. I therefore do **not** self-merge #850; it stays open for the PO, and I keep it green and conflict-free. This PR touches only `UX_REVIEW.md`, `DESIGN_SYSTEM.md` and `JOURNAL.md`. UNKNOWN until the owner changes the PO task: when the PO's first merge run happens.

### Findings

No new finding.

### Status of findings

Unchanged from 07:50 (UXR-97, -95, -96, -94, -93, -92, -91, -88, -89, -90, -84 OPEN; UXR-75, -78 met on #799, close on merge). Closed in this section: none (no screen code merged).

### Requests (OPEN)

- `lca`: whether team revocation must be named in sentence 5 (*informed*); the AUT-46 statement as extended.
- `eng`: once FAM1 is approved, one end-cause constant (no example), and the command refusal for both pairs (pgTAP).
- `po` (FAM1): CGR-131 to CGR-134 into FAM1-2/-3/-4/-6 with `cra` 09:30; CGR-132 both pairs; UXR-97 (a) per `lca`; merge #850 under `PO_MERGE_PROCESS.md` when it runs.

---

## 2026-11-05 07:50 CET · `uxa`: no screen code changed; answers to `cra` 05:30 (#867) CGR-134 (consent as the upper bound, one end-cause sentence) and the widened CGR-132 (refusal line for the reverse pair); `lca` 04:45 AUT-46 addition taken; benchmark: how a proxy-access page says when access stops; #868 carries the #799 shell code (noted for the PO); no new finding

**What changed since 03:50.** `recovery/main` is unchanged at `9e3b998`; **no change under `src`, `tests` or `e2e`**. Every open screen PR head is unchanged (#841 `8907913`, #828 `6e3fc0f`, #815 `4474184`, #814 `3fe219b`, #813 `8e4ab0b`, #809 `7f74e71`, #806 `91e7bc9`, #804 `12d0923`, #803 `f93fc81`, #800 `a3be7db`, #799 `642edf0`); my earlier notes on them stand. My PR #850 (`d86d585`) is green on all four checks after one re-run of the `db` job (pgTAP 064 failed once at 02:49 UTC, not this PR's; `cra` 05:30 traces it to CGR-110); this run continues it. New input for me, all on open PRs read on their branches: `lca` 04:45 (#860 `024b395`, `decisions/D-40.md`: client information confirmed in substance; duration clause proposed; reverse capacity pair refused in every variant; AUT-46 statement extended), `cra` 05:30 (#867 `0c3b3a2`: CGR-133 met at document level; CGR-132 widened to both pairs; new CGR-134), `po` 06:05 (#868 `52d1803`: #861 merge path escalated to the owner, option C).

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `CLINICAL_GOVERNANCE.md` 05:30 on `gov/review-2026-11-05-0530`; `D-40.md` 04:45 on `lca/review-2026-11-04-1655`; `briefs/FAM1.md` FAM1-3, FAM1-4 (lines 33-34); PR #868 commit list. I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for a PLANNED screen (FAM1 draft); nothing may be built before the PO approves FAM1. Whether the client must be told that the team can end the view is `lca`'s (UNKNOWN); I word only what is set.

### Answers (wording PROPOSED; `cra` confirms facts, `lca` *informed*, the PO places them in FAM1-2/-3/-4)

**CGR-134: duration with consent as the upper bound, and the end causes in one sentence.** `cra` is right that "solange Sie einverstanden sind" names withdrawal as the only end, while FAM1-3 and FAM1-4 end the view while consent stands. I do not use that clause. The client information then reads, top to bottom (changes in bold):
1. "Wenn Sie einverstanden sind, kann <Anzeigename der angehörigen Person> in NAVORA **jeweils** Ihre Einsätze der nächsten 7 Tage sehen: das Zeitfenster, «Ihr Pflegeteam» als Zugeteilt und den Stand: <Liste der Statustexte>." ("jeweils" says the seven days move on; `lca` (a))
2. the neutral-state explanation constant (CGR-133, "die Ansicht").
3. the timetable sentence (19:50, unchanged).
4. "Sie können diese Einwilligung jederzeit und ohne Begründung zurückziehen. Sagen Sie es dafür einfach jemandem aus dem Pflegeteam." (unchanged)
5. **new:** "Die Ansicht endet spätestens, wenn Sie Ihre Einwilligung zurückziehen. Sie endet auch, wenn Ihre Pflege unterbrochen wird oder endet, und beginnt danach nicht von selbst wieder."
6. "Wenn Sie nein sagen oder später zurückziehen, ändert das nichts an Ihrer Pflege." (unchanged)

Sentence 5 sits directly after the withdrawal sentence so every end the client is told about is in one place. "spätestens" makes consent the upper bound; "nicht von selbst wieder" carries FAM1-4 (resume does not restore). "unterbrochen" is the plain word for a paused case (C1); `cra` confirms it covers every pause reason and whether an example ("zum Beispiel bei einem Spitalaufenthalt") helps or narrows. **Team revocation (FAM1-3)** is not in sentence 5 until `lca` decides (*informed*, UNKNOWN); if `lca` says it must be named, sentence 5 gains one clause without a reason: "… Sie endet auch, wenn das Pflegeteam sie beendet oder wenn Ihre Pflege …". No sentence says why the team would end it (CGR-126, protective revocation). Vitest on the build: the information contains sentence 5 from one constant; it contains no "solange"; FAM1-3/-4 end causes each map to a phrase in that constant (`cra` remedy).

**CGR-132 widened: the reverse pair.** With `lca` (b) and `cra` 05:30, both contradictory pairs are refused on "Einwilligung speichern", one `info` line under question 2, focus moved there, nothing saved; one constant with two entries of the same form:
- question 1 "Ja", question 2 "Nein" (unchanged, 23:50): "So kann die Einwilligung nicht gespeichert werden: <Name> gibt sie selbst, kann aber nach deiner Antwort nicht selbst darüber entscheiden. Bitte prüfe beide Antworten."
- question 1 "Nein", question 2 "Ja" (new): "So kann die Einwilligung nicht gespeichert werden: <Name> gibt sie nicht selbst, kann aber nach deiner Antwort selbst darüber entscheiden. Bitte prüfe beide Antworten."
Both lines name the two answers, judge nobody and suggest neither answer (no "frage sie selbst"; if `cra` wants the RN pointed to the client, that is a clinical instruction and `cra`'s to add). Under the pilot variant the reverse pair cannot occur (question 1 is not asked, AUT-46). The command refuses both pairs (pgTAP per pair: nothing stored, no view; `eng`); the screen is not the guard. E2e outside the variant: each pair shows its line and no consent record exists afterwards.

**AUT-46 with the `lca` (c) addition (`cra` 05:30 confirmed on facts).** The fixed text directly above the save button becomes: "Mit dem Speichern bestätigst du: <Name> hat die Information oben erhalten und gibt diese Einwilligung selbst." "oben" is true because the information block is on the same screen above the questions, fixed and not collapsed (19:50); at 390 px the block stays above the questions in the one column. No checkbox, button name unchanged. Applies only under the owner's variant.

### #868 carries the shell code (for the PO; not a UX finding)

PO PR #868 (`52d1803`, base `recovery/main`) contains `819c5c6` "Merge branch 'pr-799' into sim" and so the whole of #799 (UX2-1 shell, UX2-31): 32 files, among them `AppShell.tsx`, `shell.ts`, the deletion of `Sidebar.tsx` and `ux2-shell.spec.ts`. Merging #868 as a cycle PR would land the shell on `recovery/main` outside the merge path the PO has just escalated (#861). From the UX side #799 is the right first merge (03:50 note, *Active now* (0)) and its remedies are met on its head, but the route is the owner's and the PO's; I comment once on #868 and propose nothing on the merge rule.

### Benchmark (2026-11-05): telling a person when someone else's access stops

Read the NHS website page on parent and guardian proxy access for GP online services (<https://www.nhs.uk/nhs-services/gps/gp-services-for-someone-else-proxy-access/parent-and-guardian-proxy-access-for-children>, read 2026-11-05). Pattern, in my words: one section titled by the question the reader has ("when your online access will stop") lists each cause that ends access, including the automatic ones, says what restores it, and says what still works afterwards (care at the practice continues as before). What the page does **not** do is mention withdrawal on request, which shows the gap CGR-134 names from the other side: a person told only one end cause assumes the others do not exist.
**Adopt for NAVORA:** (1) every end cause in one place, directly after the withdrawal sentence (sentence 5 above), including the ones that happen without anyone acting; (2) say that it does not restart by itself, so nobody relies on it after a hospital stay (H-28); (3) the "what still works" fact is already in sentence 6 and the relative's access-end sentence (team by phone), so nothing is added. Not adopted: a separate heading on the RN's consent step (it would add a section to a fixed six-sentence block). No design, logo or text copied.

### Findings

No new finding. CGR-134 and the reverse-pair line are answers to `cra`, not defects of a built screen.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-97 | OPEN; `lca` 04:45 recommends (a) one client per sign-in for the pilot; the PO to choose. | `D-40.md` 04:45 (#860 `024b395`) |
| UXR-95 | OPEN; (c) `lca` with `eng` (UNKNOWN). | 23:50 section of 2026-11-04 |
| UXR-96 | OPEN; catalog change still pending (outside this PR's files). | unchanged |
| UXR-94 | OPEN; `eng` to change ADR-143 1c and 6 (#837 `9c2ecc4` unchanged). | 15:50 section of 2026-11-04 |
| UXR-93, -92, -91 | OPEN; unchanged. | as above |
| UXR-88, -89, -90 | OPEN on #841 (`8907913`). | 23:50 section of 2026-11-03 |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section of 2026-11-04 |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section of 2026-11-03 |

Closed in this section: none (no screen code merged). **Confirmed by `cra` 05:30:** the CGR-133 explanation constant; `lca` 04:45 confirmed the client information in substance. They stay PROPOSED until the PO places them in FAM1.

### Requests (OPEN)

- `cra`: confirm sentence 5 (CGR-134) and "unterbrochen" for every pause reason; the reverse-pair line.
- `lca`: whether team revocation must be named in sentence 5 (*informed*); the reverse-pair line; the AUT-46 statement as extended.
- `eng`: once FAM1 is approved, one end-cause constant, and the command refusal for both pairs (pgTAP).
- `po` (FAM1): CGR-131 to CGR-134 into FAM1-2/-3/-4/-6; CGR-132 both pairs; UXR-97 (a) per `lca`; #868 contains #799 (see above).

---

## 2026-11-05 03:50 CET · `uxa`: no screen code changed; answer to `cra` 01:30 (#865) CGR-133: the client information takes the page's explanation of the neutral state from one constant, without "noch"; AUT-48 noted from the UX side; no new finding

**What changed since 23:50.** `recovery/main` is at `9e3b998`: only `aia` #866 (02:25, docs: review 26, AUT-48); **no change under `src`, `tests` or `e2e`**. Every open screen PR head is unchanged (#841 `8907913`, #828 `6e3fc0f`, #815 `4474184`, #814 `3fe219b`, #813 `8e4ab0b`, #809 `7f74e71`, #806 `91e7bc9`, #804 `12d0923`, #803 `f93fc81`, #800 `a3be7db`, #799 `642edf0`); my earlier notes on them stand. My PR #850 (`2cf39ee`) is green on all four checks; this run continues it, no second `ux/…` PR. New input for me: `cra` 01:30 (#865, open) confirms CGR-131, CGR-132 and the AUT-46 placement and raises **CGR-133**.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `cra` 01:30 comment on #850 and its PR #865 (file list); `AUTOMATION_REVIEW.md` 02:25 (AUT-48); issue #861. No benchmark (last made 2026-11-04 03:50; this run is spent on the `cra` answer). I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for a PLANNED screen (FAM1 draft); nothing may be built before the PO approves FAM1.

### Answer to `cra` CGR-133 (wording PROPOSED; `cra` confirms, `lca` for *informed*, the PO places it in FAM1)

`cra` is right. My 23:50 second sentence ("Das Team hat für diesen Einsatz **noch** keinen Abschluss eingetragen.") differs from the page explanation I wrote at 15:50 and `cra` confirmed at 16:45: "noch" suggests the visit happened and only the entry is missing (H-30), and I had written the explanation twice by hand, which is the drift CGR-131 was meant to stop. My error. Replaced by **one explanation constant** (FAM1-6), rendered in both places:

- F-02 statement block: "«Nicht als durchgeführt erfasst» heisst: Das Team hat für diesen Einsatz keinen Abschluss eingetragen. Ob er läuft, stattgefunden hat oder ausgefallen ist, zeigt diese Seite nicht."
- client information before consent: the same constant with one substitution only, "diese Seite" → "die Ansicht": "… zeigt die Ansicht nicht."

The constant holds the text with one placeholder for the subject ("diese Seite" / "die Ansicht"); nothing else differs. The polite form of the client information is unaffected, because the sentence addresses nobody. Vitest: both renderings contain the imported constant's text with the expected subject; neither contains the word "noch"; the status label in the explanation is the F-02 status constant's neutral entry (CGR-131), not a typed copy.

### AUT-48 from the UX side (no new finding, no issue)

`aia` 02:25 and `eng` (#861) report 17 green Engineering PRs waiting for a merge hand-off. Eleven of them change screens and carry remedies I or `cra` found met on their heads (#799 UX2-1 one shell: UXR-75, -78; #800: UXR-79; #813: UXR-73; #803, #804, #806, #809, #814, #815, #841). For nurses these are not yet real: a pilot team still sees the screens on `recovery/main`. Which option to take is the PO's (#861); I add only that, from the UX side, #799 (one shell) first matches *Active now* (0), because the later UX2 parts are reviewed against it. No proposal on the merge rule.

### Findings

No new finding. CGR-133 is a defect in my own 23:50 wording, corrected above rather than numbered again.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-97 | OPEN; `lca` and the PO to choose. | 19:50 and 23:50 sections of 2026-11-04 |
| UXR-95 | OPEN; (c) `lca` with `eng` (UNKNOWN). | as above |
| UXR-96 | OPEN; catalog change still pending (outside this PR's files). | unchanged |
| UXR-94 | OPEN; `eng` to change ADR-143 1c and 6 (#837 head unchanged). | 15:50 section of 2026-11-04 |
| UXR-93, -92, -91 | OPEN; unchanged. | as above |
| UXR-88, -89, -90 | OPEN on #841 (`8907913`). | 23:50 section of 2026-11-03 |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section of 2026-11-04 |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section of 2026-11-03 |

Closed in this section: none (no screen code merged). **Confirmed by `cra` 01:30:** the CGR-131 status list from the F-02 constant, the CGR-132 refusal line, the AUT-46 statement directly above the save button. They stay PROPOSED until the PO places them in FAM1.

### Requests (OPEN)

- `cra`: confirm the CGR-133 constant and its one substitution.
- `lca`: the client information as a whole (*informed*), now with the shared explanation; the 23:50 items.
- `eng`: once FAM1 is approved, one explanation constant beside the status constant, used by F-02 and the consent step.
- `po` (FAM1): CGR-131 to CGR-133 into FAM1-2/-6; AUT-46 only under the owner's variant; #861 (AUT-48).

---

## 2026-11-04 23:50 CET · `uxa`: no screen code changed; answers to `cra` 21:30 (#864): CGR-131 (the client information names all five states, from the page's own list), CGR-132 (one refusal for "gives it herself" with "cannot decide"), AUT-46 form under the pilot variant with `cra`'s two conditions; no new finding

**What changed since 19:50.** My PR #850 (`dc48444`, CI green on all four checks) had a JOURNAL conflict with `recovery/main`; I merged `recovery/main` in (`ca8b67e`, every entry kept, newest first) and continue it, no second `ux/…` PR. `recovery/main` is at `a236c10`: only `aia` #863 (20:20, docs: AUT-44 conditions accepted, AUT-45 inputs, new AUT-46, AUT-47); **no change under `src`, `tests` or `e2e`**. Every open screen PR head is unchanged (#841 `8907913`, #828 `6e3fc0f`, #815 `4474184`, #814 `3fe219b`, #813 `8e4ab0b`, #809 `7f74e71`, #806 `91e7bc9`, #804 `12d0923`, #803 `f93fc81`, #800 `a3be7db`, #799 `642edf0`); my earlier notes on them stand. New input for me: `cra` 21:30 (#864, open, read on `gov/review-2026-11-04-2130`): my 19:50 wordings confirmed, CGR-131 and CGR-132 new, AUT-46 supported with two conditions. FAM1 is still a draft brief. No `ux` issue changed.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `AUTOMATION_REVIEW.md` 20:20 (AUT-46, AUT-47) on `recovery/main`; `CLINICAL_GOVERNANCE.md` 21:30 on #864. No benchmark (made 03:50 today). I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for PLANNED screens (FAM1 draft); nothing may be built before the PO approves FAM1. What the client must be told is `lca`'s; how capacity is judged is the Clinical Owner's (UNKNOWN); I only word what they set.

### Answers (all wording PROPOSED; `cra` confirms facts and placement, `lca` where noted, the PO places them in FAM1)

**CGR-131: the client information names every state the relative will see.** `cra` is right: my 19:50 sentence 1 listed four states and left out "Nicht als durchgeführt erfasst", the one most likely to worry a relative. My error. Sentence 1 is replaced by two sentences, and the states are no longer written into the sentence by hand:
- "Wenn Sie einverstanden sind, kann <Anzeigename der angehörigen Person> in NAVORA Ihre Einsätze der nächsten 7 Tage sehen: das Zeitfenster, «Ihr Pflegeteam» als Zugeteilt und den Stand: <Liste der Statustexte>."
- "«Nicht als durchgeführt erfasst» heisst: Das Team hat für diesen Einsatz noch keinen Abschluss eingetragen."
`<Liste der Statustexte>` is rendered from the **same constant** that F-02 uses for its five status strings (today: «Geplant», «Verschoben», «Abgesagt», «Durchgeführt», «Nicht als durchgeführt erfasst»), joined "a, b, c, d oder e". So a change to FAM1-6 changes both places at once and the two lists cannot drift. The second sentence repeats the meaning of the neutral state in the client's own words (polite form) and adds nothing the page does not say; with sentence 2 of 19:50 ("…wann jemand vom Pflegeteam zu Ihnen kommt und wann nicht") it also tells the client that the relative will see when nothing has been recorded yet. Vitest: the information block contains every string of the F-02 status constant and no other status word; the test imports the constant, never a copied list. The other three 19:50 sentences are unchanged. `lca` confirms the substance (*informed*), `cra` that the list is complete. If the PO takes the display-name variant, only "«Ihr Pflegeteam» als Zugeteilt" changes ("wer zugeteilt ist").

**CGR-132: "gives it herself" together with "cannot decide it" is refused in every variant.** The form already refuses a missing answer under its question (§4). One more refusal, checked on "Einwilligung speichern" and shown as one `info` line under question 2, with focus moved there; nothing is saved:
- "So kann die Einwilligung nicht gespeichert werden: <Name> gibt sie selbst, kann aber nach deiner Antwort nicht selbst darüber entscheiden. Bitte prüfe beide Antworten."
The line names the two answers, not the client: it makes no judgement about her, suggests neither answer and has no button that changes an answer. Under the pilot variant this pair already ends in the confirmed pilot line; to keep one wording per situation (§4), the variant shows **only** the pilot line ("Im Pilot ist die Angehörigen-Ansicht nur möglich, …"), and the line above is used outside the variant. The reverse pair ("Nein", "Ja": a representative consents for a client the RN considers able to decide) is a legal question (`lca`, UNKNOWN); I word nothing for it until `lca` and the PO set a rule. The form refusal is presentation; the rule itself must also be refused by the command (pgTAP: `consent_given_by = client` with capacity `false` raises, `eng`), so the screen is never the only guard. `cra` confirms the facts, `lca` the sentence.

**AUT-46: under the pilot variant the first question becomes a stated fact.** With `cra`'s conditions (i) and (ii), the consent step reads, top to bottom:
1. the client information (four fixed sentences, CGR-131 above);
2. question 2 only: "Hältst du <Name> für fähig, über diese Einwilligung selbst zu entscheiden?" ("Ja" / "Nein", required, no preselection; "Nein" shows the confirmed pilot line and no save);
3. directly above the save button, fixed text, not collapsed: "Mit dem Speichern bestätigst du: <Name> gibt diese Einwilligung selbst."
4. "Einwilligung speichern".
I place the statement above the button, not above the information block as `aia` 20:20 wrote, because `cra` (i) makes the save the RN's attestation and the sentence must be read at the moment of the act. The stored record is unchanged (`consent_given_by = client`, recording RN, time; FAM1-2). The button keeps its name; no checkbox is added (that would be the one-answer question again). Vitest: under the variant question 1 is not rendered and the statement is the last text before the button; e2e: "Nein" on question 2 refuses the save. Applies only if the owner takes the variant; otherwise the 19:50 two-question form with CGR-132 stands. `cra` and `lca` confirm the sentence.

**AUT-47.** No screen wording now: NAVORA sets no re-check until the Clinical Owner decides (`cra` 21:30 condition; UNKNOWN). The primary control on screen stays the revocation reason "Kann diese Einwilligung nicht mehr selbst geben", recordable by any RN at any time. If a rule is set later, its line belongs on the team's existing exception list (§2, one action per line), never as a new screen or a periodic prompt.

### Findings

No new finding. CGR-131 is a defect in my own 19:50 wording, corrected above rather than numbered again.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-97 | OPEN; (a) one client per sign-in **supported by `cra`** 21:30; `lca` and the PO to choose. | `CLINICAL_GOVERNANCE.md` 21:30 (#864) |
| UXR-95 | OPEN; (b) as amended 19:50 (CGR-129) **confirmed by `cra`** 21:30; (c) `lca` with `eng` (UNKNOWN). | as above |
| UXR-96 | OPEN; catalog change still pending (outside this PR's files). | unchanged |
| UXR-94 | OPEN; `eng` to change ADR-143 1c and 6 (#837 head `9c2ecc4` unchanged). | 15:50 section |
| UXR-93, -92, -91 | OPEN; unchanged. | 15:50 section |
| UXR-88, -89, -90 | OPEN on #841 (head unchanged `8907913`). | 23:50 section of 2026-11-03 |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section of 2026-11-03 |

Closed in this section: none (no screen code merged). **Confirmed by `cra` 21:30:** the CGR-128 "Verschoben" line, the CGR-129 resend sentence, the two CGR-130 (1) questions with no preselection, the pilot "Nein" line, the timetable sentence. They stay PROPOSED until the PO places them in FAM1.

### Requests (OPEN)

- `cra`: confirm the amended client information (CGR-131), the CGR-132 refusal line and the AUT-46 statement and its position above the save button.
- `lca`: the two CGR-131 sentences (*informed*); the CGR-132 sentence and a rule for the reverse pair; the AUT-46 statement; the 19:50 items (resend sentence, controller and contact in the information, UXR-97).
- `eng`: once FAM1 is approved, the CGR-132 refusal also in the command (pgTAP), and one status constant shared by F-02 and the consent step.
- `po` (FAM1): CGR-131 (one status constant), CGR-132 in every variant, AUT-46 form if the owner takes the variant; the 19:50 items.

---

## 2026-11-04 19:50 CET · `uxa`: no screen code changed; `cra` 16:45 (#859) confirms my FAM1 wordings; answers to CGR-128 (current-slot "Verschoben" line), CGR-129 (one resend answer, no address field), CGR-130 (capacity fact with no preselection) and the client information before consent (`lca` 16:55 (1), `cra` 17:30); UXR-97 (low) on F-02 without a client name

**What changed since 15:50.** My PR #850 is still open (`2853655`, CI green on all four checks, mergeable); I continue it, no second `ux/…` PR. `recovery/main` is unchanged at `39a4883`; **no change under `src`, `tests` or `e2e`**. Every open screen PR head is unchanged (#841 `8907913`, #815 `4474184`, #814 `3fe219b`, #813 `8e4ab0b`, #809 `7f74e71`, #806 `91e7bc9`, #804 `12d0923`, #803 `f93fc81`, #800 `a3be7db`, #799 `642edf0`, #828 `6e3fc0f`); my earlier notes on them stand. New input for me, all on open, unmerged PRs read on their branches: `cra` 16:45 (#859 `230d6a3`: my 15:50 wordings confirmed; CGR-128, CGR-129), `lca` 16:55 (#860 `68a0a09`, `decisions/D-40.md` re-check: consent requirements, information to the client, pilot variants), `cra` 17:30 (#862 `e041079`: CGR-130; client information wording named as `uxa`'s). FAM1 is still a draft brief. No `ux` issue changed since 14:00.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `CLINICAL_GOVERNANCE.md` 16:45 and 17:30 on `gov/review-2026-11-04-1730`; `D-40.md` 16:55 on `lca/review-2026-11-04-1655`. No benchmark (made 03:50 today). I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for PLANNED screens (FAM1 draft); nothing may be built before the PO approves FAM1. Legal substance (what the information must contain, whether a consent suffices) is `lca`'s and the legal adviser's; capacity is the Clinical Owner's (UNKNOWN). I only word what they set.

### Answers (all wording PROPOSED; `cra` confirms facts and placement, `lca` where noted, the PO places them in FAM1)

**CGR-128: the "Verschoben" card follows the visit's current slot.** I take `cra`'s (1)-(4) as given and amend my 15:50 card: the line always names the visit's current date and window from the visit itself, e.g. "Neuer Termin: Sa 8.11., 09:00–10:00"; when that date lies after the last day shown the line is the same, with the date written out ("Neuer Termin: Mo 17.11., 08:00–09:00"), so the visit never vanishes without a word. No "Verschoben" card when the visit is back on its original slot; a moved-then-cancelled visit shows "Abgesagt" at its current slot and the "Verschoben" line still names that slot (both true). Never "verschoben auf … und erneut …", never how often it moved (not needed; `cra`'s (3) one card per visit). Vitest: the line is built only from the current-slot fields of the read result (no `after` field reaches the client).

**CGR-129: requesting a new sign-in link.** UXR-95 (b) amended to `cra`'s conditions: the page has **no address field**. The request is offered only on the page an expired or used link opens, as one button "Neuen Anmeldelink anfordern"; it goes to the contact stored in the consent record behind that link. After the tap the page shows one sentence, the same for every case (active, ended for any cause, unknown link), and nothing else changes:
- "Danke. Wenn Ihr Zugang besteht, erhalten Sie in den nächsten Minuten einen neuen Anmeldelink an die beim Pflegeteam hinterlegte Adresse."
The sentence states only what NAVORA does in the active case and is true in every case; it never says "gesendet", "beendet" or "kein Konto". A second tap shows the same sentence (no "bereits angefordert"). E2e: the rendered text after the tap is identical across the CGR-129 (2) cases; `lca` confirms the sentence and whether self-service stays at all (identity verification, UNKNOWN). A relative without any link has no request path on the page and keeps the phone route.

**CGR-130 (1): the capacity fact in the consent step (staff screen, "du").** Two required questions on the RN's consent form, each a radio pair "Ja" / "Nein" with **no option preselected**, labelled with the client's display name (§4, no assumed gender):
1. "Gibt <Name> diese Einwilligung selbst?"
2. "Hältst du <Name> für fähig, über diese Einwilligung selbst zu entscheiden?"
The confirming button "Einwilligung speichern" stays enabled; saving without an answer shows the §4 refusal form under the unanswered question ("Bitte beantworte diese Frage."), focus moves there. Nothing on the form is filled from the assessment, a score, a diagnosis or an AI proposal (`cra` (2)); no hint text suggests an answer. If the PO and owner take `lca`'s pilot variant (client consents herself only), a "Nein" on either question shows one `info` line and no save: "Im Pilot ist die Angehörigen-Ansicht nur möglich, wenn <Name> selbst einwilligt und darüber entscheiden kann." The question wording is clinical and legal substance: `cra` and `lca` confirm it; how capacity is judged stays UNKNOWN (Clinical Owner after G-1). **CGR-130 (3):** I have no change to the revocation label "Kann diese Einwilligung nicht mehr selbst geben"; it sits in the team's revocation list with the other reasons, same size and order rule, never shown to the relative.

**Information to the client before consent (`lca` 16:55 (1) *informed*; `cra` 17:30: wording `uxa`'s, never implying safer care).** Shown on the RN's screen in the consent step, above the two questions, in the polite form because the RN reads or shows it to the client (§4 polite form); fixed text, always visible, not collapsed:
- "Wenn Sie einverstanden sind, kann <Anzeigename der angehörigen Person> in NAVORA Ihre Einsätze der nächsten 7 Tage sehen: das Zeitfenster, den Stand (geplant, verschoben, abgesagt, durchgeführt) und «Ihr Pflegeteam» als Zugeteilt."
- "Damit sieht <Anzeigename der angehörigen Person> auch, wann jemand vom Pflegeteam zu Ihnen kommt und wann nicht."
- "Sie können diese Einwilligung jederzeit und ohne Begründung zurückziehen. Sagen Sie es dafür einfach jemandem aus dem Pflegeteam."
- "Wenn Sie nein sagen oder später zurückziehen, ändert das nichts an Ihrer Pflege."
The first line follows the pilot default "Ihr Pflegeteam" (`lca` (3)); if the PO takes the display-name variant, it reads "… und wer zugeteilt ist". No sentence says the view makes care safer, that the relative can reach the team, or that the team watches less without it. Whether the information must also name the controller and contact (DSG Art. 19 as read by `lca`) or what the relative does not see is `lca`'s (UNKNOWN); I add no claim. `lca` confirms the substance, `cra` the timetable sentence (CGR-126).

**Pilot variants (`lca` (2), (3); `cra` 17:30 supported).** From the screen side both simplify: "Ihr Pflegeteam" for every visit makes F-02 cards identical in form and removes the per-person staff switch from the nurse's settings; "client consents herself only" removes a representation form from the admission step. The choice is the owner's through the PO.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-97 | F-02 (relative; phone), FAM1 draft, PLANNED | low | My 15:50 title "Nächste Einsätze" without a client name works only if one sign-in shows one client. FAM1-2 records one consent per relative and client, so one relative (e.g. a daughter of two parents in care) may hold two. If both lists share one page or one sign-in, she cannot tell whose visit a card is and may read one parent's visit as the other's (`cra` 16:45 note to `lca`). The name question is `lca`'s (UNKNOWN), but the page needs a rule either way. | `briefs/FAM1.md` FAM1-2 (`39a4883`); `UX_REVIEW.md` 15:50 *F-02 layout*; `CLINICAL_GOVERNANCE.md` 16:45 *Client's name on F-02* (#859) | §1 the three questions (whose visit is it); §4 one wording per thing | PO states in FAM1 one of: (a) one sign-in per consent record (two clients → two links, each page shows one list; e2e: a relative principal reads exactly one client's visits per session); or (b) if `lca` allows a label, a page per client with a label `lca` sets, chosen before any list is shown. Until then no page shows visits of two clients together (pgTAP on the read function: one client per call). | none (low) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-95 | OPEN; (a), (d) no `cra` objection; (b) amended above to CGR-129 (no address field, one answer sentence); (c) `lca` with `eng` (UNKNOWN). | `cra` 16:45 (#859) |
| UXR-96 | OPEN; catalog change still pending (outside this PR's files). | unchanged |
| UXR-94 | OPEN; `eng` to change ADR-143 1c and 6 (#837 head `9c2ecc4` unchanged). | 15:50 section |
| UXR-93, -92, -91 | OPEN; unchanged. | 15:50 section |
| UXR-88, -89, -90 | OPEN on #841 (head unchanged `8907913`). | 23:50 section |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section |

Closed in this section: none (no screen code merged). **Confirmed by `cra` 16:45:** my 15:50 neutral status text and its explanation, one neutral tone, the access-end sentence, the FAM1-10 block, "Zugeteilt", "Keine Einsätze eingetragen."; the neutral-text share in the measure supported. They stay PROPOSED until the PO places them in FAM1.

### Requests (OPEN)

- `cra`: confirm the amended "Verschoben" line (CGR-128), the two capacity questions and the "Nein" line (CGR-130), the timetable sentence in the client information.
- `lca`: the resend sentence and whether self-service stays (CGR-129); the four client-information sentences and whether controller, contact or a "what is not shown" line must be added; UXR-97 (one client per sign-in or a label); the earlier 15:50 items (second access-end sentence, session length).
- `po` (FAM1): CGR-128 into FAM1-6 with the line above; UXR-95 (b) as amended; CGR-130 form with no preselection; the client information shown before the record is saved; UXR-97 (a) or (b); the two pilot variants to the owner; the earlier 15:50 items.

---

## 2026-11-04 15:50 CET · `uxa`: no screen code changed; new brief FAM1 (draft, owner D-40 minimal option B) read for the relative page F-02; answers to `cra` 13:30 (#857): the neutral status wording (CGR-125), one access-end sentence for every cause (CGR-127 (1)), the FAM1-10 statement on `cra`'s four facts; UXR-95 (medium) on relatives' sign-in effort; UXR-96 (low) on my own F-01 to F-06 catalog lines

**What changed since 11:50.** My PR #850 was still open (CI green on `2f46d28`) and conflicted in `JOURNAL.md` after `po` #856 and `aia` #858 merged; I merged `recovery/main` (`39a4883`) into it, every entry kept, newest first, and continue it here instead of opening a second `ux/…` PR. `recovery/main` moved by `po` #856 (owner decisions D-39 = A and D-40 = minimal option B; new brief **FAM1**, status draft; M7 objective changed to FAM1) and `aia` #858 (AUT-44, AUT-45; FAM1 supported in substance); **no change under `src`, `tests` or `e2e`** (`git diff d1f2771 39a4883`). Every open screen PR head is unchanged (#841 `8907913`, #799 `642edf0`, #800, #803, #804, #806, #809, #813, #814, #815); my earlier notes on them stand. New input for me: `cra` 13:30 on open PR #857 (`0fe2a3b`) confirms my 11:50 lines (shared call sentence, "Entscheid erfassen" line with its last sentence, the AUT-42 hint) and UXR-94, and asks `uxa` for three FAM1 wordings (CGR-125 neutral status, the single access-end sentence, FAM1-10). AUT-44 names `uxa` for the admission step. No `ux` issue changed.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `briefs/FAM1.md` in full; `CLINICAL_GOVERNANCE.md` 13:30 on #857 (CGR-125, -126, -127; FAM1-10 facts); `AUTOMATION_REVIEW.md` 14:20 (AUT-44, AUT-45); my `NAVORA_SCREEN_CATALOG.md:69`, `:435-440` and `NAVORA_INFORMATION_ARCHITECTURE.md:220-225`, `:260`. No benchmark (made 03:50 today). I ran no test; CI is the test runner. Live project not touched. FAM1 is a **draft** brief: everything below is PROPOSED wording and layout for a PLANNED screen; nothing is built and nothing may be built before the PO approves FAM1. The status mapping itself is the PO's (CGR-125) and becomes a Clinical Rule Register row; I only word it. Which numbers the page names beyond 144, whether the organisation's general number may appear (owner), and every consent, identity and staff-name question (`lca`, legal adviser) stay UNKNOWN; no line below answers them.

### Answers to `cra` 13:30 (all wording PROPOSED; `cra` confirms the facts and placement, `lca` where noted, the PO places them in FAM1)

**Register.** The relative page is the first NAVORA surface for people outside the team. It uses the polite form ("Sie", "Ihr"), as FAM1-8 already does with "Ihr Pflegeteam"; staff screens keep "du" (§4, new rule below). Swiss spelling ("ss").

**CGR-125: the neutral status wording (F-02).** Five status texts, each as text with an icon of its own shape, never colour alone, all in the same neutral tone (no green for done, no red for cancelled: on this page colour must not read as an alarm or an all-clear; `cra` confirms):
- "Geplant" (only as `cra` defines it: `planned`, not suspended, window end not passed)
- "Verschoben", with the line "Neuer Termin: Do 6.11., 14:00–15:00" (the moved-to date and window only, CGR-127 (2))
- "Abgesagt" (no reason, no second line, CGR-127 (2))
- "Durchgeführt"
- **neutral:** "Nicht als durchgeführt erfasst"

The neutral text states the one fact `cra` allows (no completion is shown) and nothing else: it does not say the visit took place, is under way, failed or is still to come. I rejected "offen" (reads as "still to come"), "unbekannt" (reads as "something is wrong") and "läuft" (a live state the brief excludes). The page explains it once, in the statement block below, never per card: "«Nicht als durchgeführt erfasst» heisst: Das Team hat für diesen Einsatz keinen Abschluss eingetragen. Ob er läuft, stattgefunden hat oder ausgefallen ist, zeigt diese Seite nicht." The planned window stays on the card under its label "Zeitfenster" (not "geplant", so the word "geplant" never appears beside the neutral text). Vitest: the client renders only these five status strings (as `cra` asks); a test per status that the card has no second line except for "Verschoben".

UX risk for the PO (no rule, a measure): how often a relative sees the neutral text depends on how soon after a visit the team records its completion. If completion is usually recorded hours later, a correct page will show "Nicht als durchgeführt erfasst" for most of today's past visits and may cause the calls FAM1 wants to remove. How soon completion is recorded in practice is UNKNOWN (no pilot data yet; never measured per person). I propose the FAM1 measure also counts, per team and month, the share of past-window visits shown with the neutral text.

**CGR-127 (1): one access-end sentence.** Byte-identical for revocation, withdrawal, pause, close and the FAM1-15 refusal, on the page and after sign-in, with nothing else on the page except the sign-out button:
- "Diese Seite steht Ihnen nicht mehr zur Verfügung. Bei Fragen wenden Sie sich an Ihren bisherigen Kontakt bei der Organisation."

No date, no time, no team or staff name, no "beendet am", no reason, no change in title or layout by cause; the second sentence is the same for every cause, including a protective revocation (CGR-126). `lca` confirms the second sentence, because for a protective revocation it directs the relative to the organisation (whether the organisation answers her is a safeguarding question, Clinical Owner and `lca`, UNKNOWN). Testable as `cra` wrote: pgTAP over the causes returns the same response; e2e compares the rendered page text and the document title across causes.

**FAM1-10: the statement on `cra`'s four facts.** One block directly under the page title, above the list, always visible (not collapsed, not a dismissible banner), `info` tone, 4 short lines at 390 px:
1. "Diese Seite zeigt nur die Einsätze, wie das Pflegeteam sie eingetragen hat. Sie können sich ändern." (fact (i))
2. "Niemand überwacht diese Seite. Über sie erreichen Sie das Team nicht." (fact (ii); it does not say "the team does not see that you opened it", which would be false, reads are audited, FAM1-14)
3. "Im Notfall: 144" with 144 as a `tel:` link of at least 44 px (fact (iii); further numbers UNKNOWN, PO with the Clinical Owner)
4. "Fragen zur Pflege oder zu einem Einsatz: über Ihren bisherigen Kontakt bei der Organisation." (fact (iv); no number until the owner answers)

The explanation of the neutral text sits behind one "Was die Angaben bedeuten" disclosure under line 4 (it is not a safety fact, so it may fold; `cra` confirms). Under the block, before the list, the load time: "Stand: heute, 15:42" (CGR-127 (4)); another day "Stand: Mo 3.11., 22:40"; never a relative age. Without a successful load the page shows the statement block and "Die Einsätze können gerade nicht angezeigt werden." with one button "Erneut laden" and no visit list (no cached list, CGR-127 (4)). Nothing on the page says or suggests that the team will notice a problem because of the page.

**F-02 layout (for the PO's FAM1-16 and the catalog).** The three questions for a relative: now = today's visits first, under "Heute"; next = nothing to do here, except calling 144 in an emergency, so the page has **no primary action** (read-only; "Erneut laden" only when loading failed); can wait = "Morgen" and the following days by date ("Fr 6.11."). Each visit is one card with at most three lines: "Zeitfenster 08:00–09:00", the status, and "Zugeteilt: <Anzeigename>" or "Zugeteilt: Ihr Pflegeteam". The label is "Zugeteilt", never "Es kommt" or "Ihre Pflegefachperson": FAM1-8 shows who is assigned, and `cra` CGR-127 (3) shows that the assigned person is not always the one who comes. A day without visits says "Keine Einsätze eingetragen." (never "kein Besuch", which reads as a fact about the client). Sign-out sits in the page header, 44 px. Whether the client's name appears (a relative with two consented clients needs to tell them apart; a shared phone shows it) is `lca`'s (UNKNOWN); until then the page title is "Nächste Einsätze" with no name.

**AUT-44 (admission step, `aia` names `uxa`).** From the screen side I support one act: the consent form on the admission screen stores the record and issues the sign-in in one confirming step, and its confirmation shows the scope sentence "Einsätze: Zeit, Stand, zugeteilte Person" and who consented, so the RN sees what the relative will see before she confirms. No design before FAM1 is approved and `lca` has answered identity verification. **AUT-45:** option (b) (retrospective answer plus page views) adds no control to any nurse screen; a tap tally (a) would add a counter to `/field` for two weeks. If the PO picks (a), I propose paper, not a screen control.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-95 | F-01 sign-in and F-02 (relative; phone), FAM1 draft, PLANNED | medium | FAM1 sets no criterion on how much effort it takes a relative to get back to the page. A relative opens it occasionally (to check one visit), often on a phone she does not use for work. If every visit needs a new e-mail code or a new link from the team, the call stays cheaper than the page and the FAM1 outcome (fewer schedule calls) is not reached; the team also gets "my link does not work" calls instead. Engineering question 2 (invitation and sign-in) is open, and its answer decides adoption as much as safety. Session length on a possibly shared phone is a privacy trade-off, not mine to set. | `briefs/FAM1.md` FAM1-16, *Open questions for engineering* 2, *AI leverage* measure (`39a4883`) | §1 the three questions (reach the answer at once); §5 phone first; DESIGN_SYSTEM §4 say what happens | PO adds to FAM1-16: (a) a returning relative reaches F-02 from her saved link in at most two steps, measured in e2e at 390 px; (b) when a sign-in link or code has expired, the page says so in one sentence and offers one action to get a new one herself, without calling the team ("Neuen Anmeldecode senden"), unless `lca` rules self-service out; (c) the session length and "remember this device" are decided by `lca` with `eng` (UNKNOWN); (d) the FAM1 measure counts failed or expired sign-ins per team and month (never per person). | none (medium; draft brief) |
| UXR-96 | Design set, F-01 to F-06 (relative, client), my own catalog and IA lines | low | My catalog and information architecture still mark F-01 to F-06 FROZEN and describe F-06 "Team erreichen" (team phone, always visible) and F-03 "Mitteilungen" (push) as part of the family frame. Owner D-40 now puts F-01 and F-02 into the pilot (FAM1, PLANNED once approved) and excludes notifications, messages, check-ins and team contact. F-02 also says "who comes", which CGR-127 (3) shows is not what FAM1-8 shows. A reader of the design set would plan screens the owner excluded. | `NAVORA_SCREEN_CATALOG.md:69`, `:435-440`; `NAVORA_INFORMATION_ARCHITECTURE.md:220-225`, `:260` (on `39a4883`); D-40 | §4 one wording per thing; design set must match the decided scope | In my next catalog change (outside this PR's three files): F-01, F-02 PLANNED (FAM1, draft until approved); F-03 to F-06 "excluded in the pilot (owner D-40)"; F-02 "who is assigned (display name or «Ihr Pflegeteam»)"; layout as in *F-02 layout* above. | none (low) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-94 | OPEN; **`cra` supported** (13:30: tests take names from the button constants); `eng` to change ADR-143 1c and 6. | #837 head `9c2ecc4` |
| UXR-93 | OPEN; `cra` confirmed, in ADR-143; closes on the built queue. | 11:50 section |
| UXR-92 | OPEN; unchanged. | 07:50 section |
| UXR-91 | OPEN; catalog A-07 line still to be corrected with UXR-96 in my next catalog change. | `NAVORA_SCREEN_CATALOG.md:191` unchanged |
| UXR-88, -89, -90 | OPEN on #841 (head unchanged `8907913`). | 23:50 section |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section |

Closed in this section: none (no screen code merged). `cra` 13:30 confirmed my 11:50 wordings (CGR-124 call sentence, "Entscheid erfassen" line, AUT-42 hint); they stay PROPOSED until MOB1 places them.

### Requests (OPEN)

- `cra`: confirm the neutral status text "Nicht als durchgeführt erfasst" and its explanation, the neutral tone for all five statuses, the access-end sentence, the FAM1-10 block (four lines above the list, the explanation behind a disclosure), and the label "Zugeteilt".
- `lca`: the second sentence of the access-end text (protective revocation); whether the client's name may appear on F-02; session length and self-service for an expired sign-in (UXR-95).
- `po` (FAM1): the five status texts and the exhaustive mapping (CGR-125); UXR-95 (a)-(d) into FAM1-16 and the measure; the neutral-text share in the measure; the AUT-45 choice; point 9 explicit act or AUT-42 (unchanged).
- owner (through the PO): whether the organisation's general number may appear on the page (`cra` FAM1-10 (iv)).

---

## 2026-11-04 11:50 CET · `uxa`: no screen code changed; answers to `cra` 09:30 (#855): the no-reception sentence (CGR-124), the offline line for "Entscheid erfassen" (`record_interruption_followup`), the AUT-42 information line; UXR-93 written into ADR-143 by `eng`; UXR-94 (low) on button names in ADR-143 1c and 6

**What changed since 07:50.** My PR #850 was still open (CI green on `c8e416c`) and conflicted in `JOURNAL.md` after `aia` #854 merged; I merged `recovery/main` (`d1f2771`) into it, every entry kept, newest first, and continue it here instead of opening a second `ux/…` PR. `recovery/main` moved by `aia` #854 only (AUT-41, AUT-42, AUT-43; docs); **no change under `src`, `tests` or `e2e`** (`git diff d85f715 d1f2771`). Every open screen PR head is unchanged (#841 `8907913`, #799 `642edf0`, #800, #803, #804, #806, #809, #813, #814, #815); my earlier notes on them stand. New input for me: `cra` 09:30 on open PR #855 (`3df6711`) confirms my 07:50 lines, the read-only absence dialog, the clock-refusal card, the "Stand" lines and the UXR-93 order, with conditions, and asks `uxa` for three things (CGR-124 sentence, the `record_interruption_followup` line, the AUT-42 information line). `eng` #837 (`92d0aba`, docs) wrote `cra` 09:30, AUT-42 (Engineering's choice: one automatic claim-less resend) and UXR-93 into ADR-143 facts, 1c, 1d, 2, 6, 9.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `CLINICAL_GOVERNANCE.md` 09:30 on #855; `git show 92d0aba` (ADR-143, APP1 plan); built labels in `src/app/(protected)/field/visit-lifecycle.tsx:73`, `:108-112`, `:121-133` and `src/components/lifecycle/InterruptionFollowupForm.tsx:12`, `:34-35`. No benchmark (made 03:50 today). I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for a PLANNED screen state (A-07, M6-2, MOB1); nothing is built. Which number "telefonisch" means stays UNKNOWN (Clinical Owner, G-1); no line names one.

### Answers to `cra` 09:30 (all wording PROPOSED; `cra` confirms the safety facts and placement, `lca` where noted, the PO places them in MOB1)

**CGR-124: the no-reception sentence.** One shared call sentence, one constant, used by every 1c line and the absence dialog, so the no-reception case is said the same way everywhere:
- "Melde es jetzt telefonisch. Geht kein Anruf durch, versuch es wieder, sobald du Empfang hast."

It names an action she can check herself (the call does not connect) instead of a state she cannot tell apart ("Verbindung" for data versus "Empfang" for calls). It says nothing about what the team sees in the meantime: the server's `visit_stuck` / `visit_overdue` is a backstop for the team, not a fact she may rely on, and naming it would read as "the team will notice anyway" (`cra` condition: never imply the team already knows). So the 07:50 lines read:
- "Nicht angetroffen" and "Nicht abgeschlossen beenden": "Ohne Verbindung wird «Nicht angetroffen» oder «Nicht abgeschlossen» nicht erfasst, und das Team erfährt nichts davon. Melde es jetzt telefonisch. Geht kein Anruf durch, versuch es wieder, sobald du Empfang hast."
- "Ergebnis erfassen": "Ohne Verbindung wird das Ergebnis nicht erfasst. Melde es jetzt telefonisch. Geht kein Anruf durch, versuch es wieder, sobald du Empfang hast. Erfassen kannst du es, sobald die Verbindung zurück ist."
- absence dialog: "Ohne Verbindung wird deine Abwesenheit nicht erfasst. Deine Einsätze bleiben bei dir, und im Team sieht niemand, dass sie frei werden. Melde dich jetzt telefonisch ab. Geht kein Anruf durch, versuch es wieder, sobald du Empfang hast."
- banner line 3 stays "Neue Sicherheitssignale kommen erst danach an. Dringendes jetzt telefonisch melden." (three lines at 390 px; the card line is where she acts).

When MOB1 names the number, "telefonisch" becomes a `tel:` link of at least 44 px in the same sentence. Vitest: the 1c lines and the dialog text each contain the shared constant exactly once.

**`record_interruption_followup` offline (ADR-143 1d by rule; button "Entscheid erfassen", `InterruptionFollowupForm.tsx:34-35`).** The button follows 1a (`aria-disabled`, in the tab order). Its line, in the line block of the interrupted card under the existing "Entscheid offen: … Bis dahin bleibt der Einsatz im Team und bei Operations sichtbar." (`visit-lifecycle.tsx:110`, IMPLEMENTED, unchanged):
- "Ohne Verbindung wird der Entscheid nicht erfasst. Erfasse ihn, sobald die Verbindung zurück ist. Muss die Pflege früher geklärt werden, melde es jetzt telefonisch."

The fact the team needs (broken off, decision open) was recorded online, so this line does not say "das Team erfährt nichts davon"; it is true because the `visit_interrupted` signal stays open until the decision (0045:61-72, `cra` 09:30). Whether a decision can be urgent enough to require a call is a clinical question; the last sentence leaves it to her judgement and sets no rule (`cra` confirms or removes it). If the form is already open when the connection drops, "Entscheid speichern" follows 1a with the same line; the text she typed stays in the form and is not queued. Playwright offline on an interrupted visit: "Entscheid erfassen" is reached by Tab, is `aria-disabled`, is described by this line only, and a tap creates no pending entry and no request.

**AUT-42 information line (ADR-143 9 as written by `eng`; PO choice still open).** On her card after the automatic resend, never green, `info` tone:
- once, `role="status"`: "Gesendet."
- then the card's information line: "Gerätezeit verworfen: es gilt die Zeit, zu der es beim Team einging (15:20). Ist die Uhrzeit für das Beobachtete wichtig, ergänze eine Beobachtung."
- under it, while the device clock is still wrong (the next refusal would show it again): "Bitte Geräteuhr prüfen."

No button (ADR-143 9 (c)). The first sentence is `cra`'s, with the server time added so she sees which time counts. The second sentence is the reason `cra` gave for condition (c); `cra` confirms it as a hint and not a rule. On the record the two-line display stays "Beim Team eingegangen 15:20" / "Gerätezeit verworfen". If the automatic resend is refused, the card shows that refusal under ADR-143 2 with the existing lines ("Nicht gesendet: …"), plus "Dringendes telefonisch melden."; it never shows "Gesendet.". If the PO keeps the explicit act instead, my 07:50 four-line card stands. `lca` confirms "verworfen" on a care record (open since 07:50).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-94 | A-07 offline, `/field` visit card (nurse; phone), M6-2, PLANNED | low | ADR-143 1c and its tests in point 6 name the no-show button "Klient nicht angetroffen". The built button is "Nicht angetroffen" (`visit-lifecycle.tsx:123`) and the recorded state reads "Klient:in nicht angetroffen" (`:73`). A Playwright test written to the ADR will look for a name that does not exist, and a fix "to the ADR" would bring a non-inclusive label into the product (§4 wording, UXR-81 pattern). | `92d0aba` `DECISIONS.md` ADR-143 1c line block and 6; `visit-lifecycle.tsx:73`, `:123` on `d1f2771` | §4 one wording per thing; §6 accessible name stable | ADR-143 1c and 6 use the built labels ("Nicht angetroffen", "Nicht abgeschlossen beenden", "Ergebnis erfassen", "Entscheid erfassen"); the M6-2 tests take the names from the same constants as the buttons; any rename goes through `uxa` and keeps "Klient:in". | none (low); one comment on #837 |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-93 | OPEN; **`cra` confirmed** (09:30); **written into ADR-143 1c and 6 by `eng`** (`92d0aba`); closes on the built queue. | `DECISIONS.md` ADR-143 1c "Line block per card" |
| UXR-92 | OPEN; unchanged (confirmed, placed in MOB1, in ADR-143 1a, 6). | 07:50 section |
| UXR-91 | OPEN; catalog A-07 line still to be corrected in my next catalog change. | `NAVORA_SCREEN_CATALOG.md:191` unchanged |
| UXR-88, -89, -90 | OPEN on #841 (head unchanged `8907913`). | 23:50 section |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section |

Closed in this section: none (no screen code merged).

### Requests (OPEN)

- `cra`: confirm the shared call sentence (CGR-124), the "Entscheid erfassen" line including whether its last sentence stays, and the AUT-42 information line with its hint sentence.
- `eng` (#837): the built button names in ADR-143 1c and 6 (UXR-94); the shared call constant; "Entscheid speichern" in an open form follows 1a.
- `lca`: "Gerätezeit verworfen" on a care record (unchanged).
- `po`: the explicit act or AUT-42 for point 9; which of my two clock-refusal texts MOB1 carries follows from that.

---

## 2026-11-04 07:50 CET · `uxa`: no screen code changed; answers to `cra` 05:30 (#852, CGR-123) and `eng` ADR-143 1c / 9 (#837 `8142bba`): the offline call lines for no-show, broken-off visit, outcome and absence, the device-clock refusal card with "Ohne Gerätezeit senden", the offline "Stand" line for safety signals; UXR-93 (medium); one correction to my 23:50 example

**What changed since 03:50.** My PR #850 is still open (CI green on `ea9bd1d`; it went out of date with `recovery/main`, so I merged `recovery/main` into it, `JOURNAL.md` only, every entry kept, and continue it here instead of opening a second `ux/…` PR). `recovery/main` is at `d85f715`: `lca` #851 (D-34, D-39, D-40) and `po` #853 (`DELIVERY_PROGRAM.md` §0c: CGR-122 (1) and CGR-123 in force for ADR-143 and M6-2, AUT-41 the target behind a Clinical Owner gate, the offline phone number and UXR-92 placed in MOB1); **no change under `src`, `tests` or `e2e`** (`git diff 50db89d d85f715` touches none). Every open screen PR head is unchanged (#841 `8907913`, #799 `642edf0`, #800, #803, #804, #806, #809, #813, #814, #815); my earlier notes on them stand. New input for me: `cra` 05:30 on open PR #852 (`e787be2`) confirms my 03:50 wording with conditions and asks `uxa` for the no-show and interruption line, the clock-refusal line with an in-app step, and the "Stand" wording; `eng` #837 (`8142bba`) writes CGR-123 into ADR-143 (1c never queued: `record_no_show`, `record_no_show_outcome`, `end_visit_not_completed`, `record_absence`, `change_absence`; 9: "Ohne Gerätezeit senden", "Gerätezeit verworfen") and asks `uxa` for the 1c and 9 wording. No new UX brief; no `ux` issue changed.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `CLINICAL_GOVERNANCE.md` 05:30 on #852; `git show 8142bba` (ADR-143 1c, 1d, 5, 6, 9; APP1 plan); `DELIVERY_PROGRAM.md` §0c; today's button labels in `src/app/(protected)/field/visit-lifecycle.tsx:121-133` ("Nicht angetroffen", "Nicht abgeschlossen beenden", "Ergebnis erfassen") and `absence-section.tsx:106-108`, `:205-208` ("Ich kann nicht arbeiten", "Verkürzen", "Zurückziehen"). No benchmark (made 03:50 today). I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for a PLANNED screen state (A-07, M6-2, MOB1); nothing is built. Which number "telefonisch" means is UNKNOWN (Clinical Owner, G-1; `DELIVERY_PROGRAM.md` §0c (4)); no line below names one.

### Answers (all wording PROPOSED; `cra` confirms safety facts and how a safety line is placed, `lca` where noted, the PO places them in MOB1)

**ADR-143 1c, visit card offline (`record_no_show`, `end_visit_not_completed`, `record_no_show_outcome`).** The buttons keep place and label as `aria-disabled="true"` (UXR-92). Under the action row, first in the card's line block (UXR-93):
- "Nicht angetroffen" and "Nicht abgeschlossen beenden": "Ohne Verbindung wird «Nicht angetroffen» oder «Nicht abgeschlossen» nicht erfasst, und das Team erfährt nichts davon. Melde es jetzt telefonisch."
- "Ergebnis erfassen" (no-show already recorded online, outcome open): "Ohne Verbindung wird das Ergebnis nicht erfasst. Melde es jetzt telefonisch; erfassen kannst du es, sobald die Verbindung zurück ist."
"Melde es jetzt telefonisch" matches the banner ("Dringendes jetzt telefonisch melden") and names no person or number. When MOB1 names the number, the same sentence ends with it as a `tel:` link of at least 44 px, held on the device (`cra` CGR-118 condition). The tone follows the card's own action (`rose` for "Nicht angetroffen" today); a colour never carries the meaning alone. e2e (ADR-143 6): on an `on_the_way` visit with `context.setOffline`, "Nicht angetroffen" is reached by Tab, its accessible description is exactly the first sentence above, a tap creates no pending entry and no request.

**ADR-143 1c, absence offline (`record_absence`, `change_absence`).**
- Header "Ich kann nicht arbeiten" has no card for a line at 390 px. Proposal: the button stays active and opens its dialog in a read-only offline variant: title "Ich kann nicht arbeiten", text "Ohne Verbindung wird deine Abwesenheit nicht erfasst. Deine Einsätze bleiben bei dir, und im Team sieht niemand, dass sie frei werden. Melde dich jetzt telefonisch ab.", one button "Schliessen" (focused); no form, so no pending entry and no request. This deviates from the 1c wording "aria-disabled" for this one control; `eng` and `cra` to confirm (the 1c test then asserts the dialog text and no request instead of `aria-disabled`).
- "Verkürzen" and "Zurückziehen" on her absence card: `aria-disabled`, line "Ohne Verbindung wird die Änderung nicht erfasst; deine Einsätze bleiben, wie sie sind. Ändere es, sobald die Verbindung zurück ist, oder melde es telefonisch."

**ADR-143 9, device-clock refusal (CGR-122 (2), `cra` 05:30 condition met).** On her pending card, replacing my 03:50 line:
1. "Nicht gesendet: die Uhrzeit dieses Geräts stimmt nicht."
2. "Du kannst es ohne Gerätezeit senden. Dann gilt nur die Zeit, zu der es beim Team eingeht."
3. button (the card's one primary action, ≥ 44 px): "Ohne Gerätezeit senden"
4. "Bitte Geräteuhr prüfen. Dringendes zusätzlich telefonisch melden."
While sent: "Wird gesendet …"; then one `role="status"` "Gesendet." On the record, the two-line display of point 8 reads "Beim Team eingegangen 15:20" / "Gerätezeit verworfen" (`eng`'s words, kept), same size, not muted below 4.5:1. Never sent automatically (ADR-143 2). `lca` confirms "verworfen" as text on a care record (D-10, D-11).

**Offline "Stand" line for safety signals (`cra` 05:30, benchmark (3)).** In the signal area at the top of `/field`, offline only, one text line under its heading:
- signals listed: "Stand 14:32 · Neue Sicherheitssignale kommen erst mit Verbindung."
- none listed: "Keine offenen Sicherheitssignale, Stand 14:32. Neue kommen erst mit Verbindung."
- another day: "Stand Mo 3.11., 22:40".
The time is the last successful load of the signal list, not the time the app was opened; whether the client keeps that time today is UNKNOWN (`eng`). Absolute time only, no "vor 5 Min." (a relative age changes while she reads and is not announced). Not a live region. Playwright with `context.setOffline` and an empty seeded list: the text "Keine offenen Sicherheitssignale" never appears without "Stand". Placement `po` (MOB1).

**Correction to my 23:50 section.** The sign-out `alertdialog` example "2 Beobachtungen, 1 Abwesenheit" is no longer possible: an absence is never queued (CGR-123, ADR-143 1c). The example reads "2 Beobachtungen"; the kinds line uses only labels of `QUEUEABLE_FIELD_COMMANDS`. Everything else in that dialog stands.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-93 | A-07 offline, `/field` visit card `on_the_way` or started (nurse; phone), M6-2, PLANNED | medium | ADR-143 1a and 1c each say "one card line" as `aria-describedby`. An offline visit card carries both kinds at once (timeline buttons and "Nicht angetroffen" / "Nicht abgeschlossen beenden"), so either two lines compete or one line serves two reasons; with no order set, the billing sentence ("Ohne Verbindung wird keine Zeit erfasst …") can stand before the safety one, and a screen reader on "Nicht angetroffen" hears the time sentence. | ADR-143 1a, 1c (#837 `8142bba`); `visit-lifecycle.tsx:121-133` (no-show and interrupt buttons on the same card as the timeline) | §1 what needs attention now first; §5 actions unavailable offline; §6 accessible description | One line block per card; the 1c sentence first, the timeline sentence second; each button's `aria-describedby` points only to its own sentence's id. Playwright offline on an `on_the_way` visit: the first sentence of the block is the 1c sentence; "Nicht angetroffen" is described by it, "Einsatz starten" by the timeline sentence. `cra` confirms the order (position of a safety line). | — (medium; PLANNED; comment on #837) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-92 | OPEN; **`cra` confirmed** (05:30, no safety content changed; e2e also shows no request on activation); **placed by `po`** in MOB1 (§0c (5)); in ADR-143 1a, 6 (#837). Closes on the built queue. | `8142bba` |
| UXR-91 | OPEN; catalog A-07 line still to be corrected in my next catalog change. | `NAVORA_SCREEN_CATALOG.md:191` unchanged |
| UXR-88, -89, -90 | OPEN on #841 (head unchanged `8907913`). | 23:50 section |
| UXR-84 | OPEN on #815 (`4474184`). | 03:50 section |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section |

Closed in this section: none (no screen code merged).

### Requests (OPEN)

- `cra`: confirm the 1c lines (visit card and absence), the offline read-only absence dialog (deviation from `aria-disabled`), the clock-refusal card, the "Stand" lines, and the UXR-93 order.
- `eng` (#837): the absence-dialog deviation in 1c and its test; the "last successful load" time for the "Stand" line; one line block per card with per-button sentence ids (UXR-93).
- `lca`: "Gerätezeit verworfen" and the clock-refusal lines as text on a care record; unchanged earlier requests.
- `po`: place the "Stand" line and UXR-93 in MOB1.

---

## 2026-11-04 03:50 CET · `uxa`: no screen code changed; answers to `cra` 01:30 (#848, CGR-122): one pending-card line, the offline line for timeline and claim buttons, the device-time label, the preset reason for the PO option (AUT-41); UXR-92 (medium) on "disabled" buttons; benchmark offline and sync status

**What changed since 23:50.** My PR #847 is merged (`7cbbf7b`). `recovery/main` is at `5fc0d61`: only `aia` #849 (AUT-41, docs) since; **no change under `src`, `tests` or `e2e`** (`git diff 7cbbf7b 5fc0d61` touches none). Every open screen PR head is unchanged (#841 `8907913`, #799 `642edf0`, #800, #803, #804, #806, #809, #813, #814, #815 as at 23:50); my earlier notes on them stand. New input for me: `cra` 01:30 on open PR #848 (`0efc5c2`) gives **CGR-122** (blocking for ADR-143 and M6-2: an entry sent late from the offline queue takes the server time) and asks `uxa` for three things (single card line; the line under disabled timeline buttons; the device-time label); `aia` 02:20 (AUT-41) asks `uxa` for preset-reason words under the PO option. No new UX brief; no `ux` issue changed.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `CLINICAL_GOVERNANCE.md` 01:30 on #848; `AUTOMATION_REVIEW.md` 02:20 (AUT-41); ADR-143 on #837 (`c84296a`) as summarised there; my 23:50 section. I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording for a PLANNED screen (A-07, M6, MOB1); nothing is built. Whether the device time is the documented time is UNKNOWN (Clinical Owner with `lca`, D-10, D-11); no label below calls either time "dokumentiert".

### Answers to `cra` 01:30 and `aia` 02:20 (all wording PROPOSED; `cra` confirms safety facts, `lca` the access and deletion texts, the PO chooses between CGR-122 (1) and the option)

**One pending-card line (CGR-118 (2), `cra` "no list").** I withdraw my two-variant proposal of 23:50. Every pending care entry carries the same `info` line: "Noch nicht beim Team. Wird gesendet, wenn NAVORA offen ist und Verbindung besteht." No kinds constant is needed for the wording; if `eng` keeps one for other reasons, the wording does not read it. "Wird gesendet …", "Gesendet." and the refusal lines stay as at 23:50.

**Offline line under the visit-timeline buttons, CGR-122 (1)** (if the PO chooses (1)). One line per visit card, under the action row, never per button, `info` tone: "Ohne Verbindung wird keine Zeit erfasst. Tippe, sobald die Verbindung zurück ist. Eine falsche Zeit korrigierst du danach mit Begründung." The buttons stay in place and keep their labels ("Losfahren", "Einsatz starten", "Pause", "Weiter", "Einsatz beenden", "Zeit korrigieren") as `aria-disabled="true"` with this line as `aria-describedby` (UXR-92). Vitest: the line is a constant; e2e offline: "Einsatz starten" is focusable, announces the line, and creates no pending entry.

**Offline line under the claim buttons** (`take_signal`, `take_open_visit`, `accept_cover`, `withdraw_cover`; `cra`: online only). Same pattern, one line per card: "Übernehmen geht nur mit Verbindung, damit nicht zwei dasselbe übernehmen. Dringendes jetzt telefonisch melden." For a cover: "Zusagen und Absagen gehen nur mit Verbindung." Per `cra`'s condition the line names no number until MOB1 names one the app holds offline.

**Under the PO option (AUT-41: an offline timeline tap is sent as a reasoned F3 correction).** Buttons stay active; each tap becomes a pending card line "Einsatz gestartet 14:05 (Gerätezeit). Noch nicht beim Team. Wird gesendet, wenn NAVORA offen ist und Verbindung besteht." **Preset reason** stored with the correction: "Ohne Verbindung erfasst (Gerätezeit)". It names a fact, not a judgement, and keeps the word "Gerätezeit" so a countersigner reading the correction list sees where the time came from (`cra` and `lca` confirm; the PO places it). From the UX side the option is the better form: no act after reconnecting and no time typed from memory (AUT-41); the control is `cra`'s to confirm.

**Device-time label, CGR-122 (2).** On the pending card, on the sent entry and in the record, whenever the two times shown differ at the minute shown (whether any tolerance applies is a rule, `cra`, UNKNOWN; none is set here):
- line 1, the record's time as today: "Beim Team eingegangen 15:20"
- line 2, the claim, directly under it, same size, not muted below 4.5:1: "Auf dem Gerät eingegeben 14:05"
- different day: both lines carry the date ("Mo 3.11., 22:40").
Text only, never a colour or an icon alone; neither line says "dokumentiert" or "erfasst um". Session-expiry entries (CGR-121) show the same two lines. **Refused because the device time is later than the receipt** (CGR-122 (2) pgTAP): the entry stays on her card with "Nicht gesendet: die Uhrzeit dieses Geräts stimmt nicht. Bitte Geräteuhr prüfen und das Wichtige telefonisch ans Team weitergeben." (`cra` confirms; never dropped, ADR-143 2).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-92 | A-07 offline state on `/field` visit and signal cards (nurse; phone), M6, PLANNED; CGR-122 (1) and `cra`'s claim-button condition | medium | CGR-122 (1) and the 01:30 claim condition say the buttons stay "visible but disabled". A native `disabled` button is skipped by Tab and screen readers and often greyed below 3:1, so a nurse using a screen reader or in sunlight cannot learn why "Einsatz starten" does nothing, and may read the missing button as a missing visit. | `CLINICAL_GOVERNANCE.md` 01:30, CGR-122 remedy (1) and inputs (#848 `0efc5c2`); ADR-143 (#837) | DESIGN_SYSTEM §5 offline rule; §6 accessibility (keyboard, focus, 3:1 non-text contrast, no meaning only in colour) | Use `aria-disabled="true"` (not the `disabled` attribute), keep the button in the tab order, link the one card line with `aria-describedby`, keep label contrast ≥ 4.5:1 and border ≥ 3:1 (V1 `border-control`); a tap shows the card line focused, never a toast. e2e offline (`context.setOffline`): Tab reaches "Einsatz starten" and "Übernehmen"; their accessible description is the card line; tapping creates no pending entry and no request. | — (medium; PLANNED screen; comment on #837) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-91 | OPEN; remedy **confirmed by `cra`** (01:30: "Wird gesendet …" only in flight); now one card line for every pending entry (above). Catalog line A-07 still to be corrected in my next catalog change. | `NAVORA_SCREEN_CATALOG.md:191` unchanged |
| UXR-88, -89, -90 | OPEN on #841 (head unchanged `8907913`); UXR-89 amended rule met at document level (`cra` 01:30). | 23:50 section |
| UXR-84 | OPEN on #815; CGR-113 sentence meets `cra`'s condition (01:30). | `4474184` |
| UXR-75, -78 | Met on PR head #799 (`642edf0`); close on merge. | 19:55 section |

Closed in this section: none (no screen code merged).

### Benchmark (once today): offline and sync status in a health-worker app

Read 2026-11-04: Google Open Health Stack, *Design Guidelines for Offline & Sync* (https://developers.google.com/open-health-stack/design/offline-sync-guideline). In my words: the offline state is shown where the worker decides (task list, patient card), in a neutral tone rather than as an error, with the reassurance that work continues and is uploaded on reconnect; sync progress is a determinate bar, not a spinner; a "last updated" time sits in context on the list and the record, used sparingly; an error says what failed, what to do, a second step if that fails, and how to get help (including a phone number); offline is never reported as a generic sync failure; a manual "sync now" exists on the record for hand-overs.
**What NAVORA should adopt:** (1) the banner already says work continues (line 2); keep it — its `attention` tone stays because line 3 is a safety fact (`cra`'s to confirm; the guide's neutral tone fits a setting without safety signals). (2) While pending entries are sent, one determinate count line "2 von 5 gesendet", never a spinner. (3) A "Stand" time for safety signals on `/field` while offline ("Sicherheitssignale: Stand 14:32") so the nurse sees how old her picture is — a safety-signal presentation, so `cra` must confirm position and wording before any brief takes it. (4) Refusal lines name the next step and the help route, as the access-end and device-clock lines above do; the phone route waits on MOB1's number (`cra` condition). (5) No "sync now" button: ADR-142 sends in the foreground on reconnect; a manual button would add an act without a gain (`aia` AUT-41 principle). Nothing copied.

### Requests (OPEN)

- `cra`: confirm the claim-button lines, the device-time two-line label, the device-clock refusal line, and the preset reason "Ohne Verbindung erfasst (Gerätezeit)"; confirm UXR-92 does not change the safety content; decide on benchmark point (3).
- `lca`: preset reason and device-time label as text on a care record (D-10, D-11); unchanged 23:50 requests (deletion and access-end sentences).
- `po`: choose CGR-122 (1) or the option (AUT-41); place UXR-92 with CGR-122 in MOB1 / M6-2.

---

## 2026-11-03 23:50 CET · `uxa`: no screen code changed; answers to `cra` 21:30 (#845): CGR-113 sentence with "gelten nicht mehr", UXR-89 amended with `cra`'s card conditions, offline wording for CGR-118 and CGR-121 (a), (b); UXR-91 (medium) on my own catalog line A-07

**What changed since 19:55.** My PR #839 is merged (`c46010a`). `recovery/main` is at `50db89d`: `aia` #844 and `po` #846 (AUT-40 decided: no C-15 screen at stage 0; AN3-5 wording aligned to the built time-correction share), **no change under `src` or `tests`**. Open screen PRs #841 (`8907913`) and #799 (`642edf0`) moved by base merges only (diff of `src`, `tests`, `e2e` against `aeec158` and `12a44f9` is empty); my 19:55 notes on them stand. New input for me: `cra` 21:30 on open PR #845 (`0dd05c5`) asks `uxa` for four things (CGR-113 sentence, UXR-89 cards, CGR-121 (b) wording, CGR-118 banner facts); `eng` #837 (`7458904`, docs) puts the offline queue on ADR-143 with `cra`'s CGR-121 points and leaves the banner wording open for `cra` (`APP1_IMPLEMENTATION_PLAN.md`, *Offline queue (A-07)*). No new UX brief; no `ux` issue changed.

**Sources.** No screen code changed, so no screenshots were needed or downloaded. Read: `CLINICAL_GOVERNANCE.md` 21:30 on #845 (CGR-113, CGR-118, CGR-120, CGR-121, UXR-88/-89 conditions); `step-spans.ts` on `8907913`; `briefs/AN3.md` (AN3-5 as aligned by `po` 22:00); `APP1_IMPLEMENTATION_PLAN.md` offline queue on #837; my `NAVORA_SCREEN_CATALOG.md` A-07. No benchmark (made 03:52 today). I ran no test; CI is the test runner. Live project not touched. Everything below is PROPOSED wording, nothing is built.

### Answers to `cra` (all wording PROPOSED; `cra` confirms the facts, the PO places them)

**CGR-113 (supersede sentence, ASM1-C6 (8), #815).** I take `cra`'s condition as given; the sentence by count from the reader:
- n = 0: no sentence.
- n = 1: "Auch ihre frühere Fassung gilt dann nicht mehr und ist für das Team nicht mehr sichtbar."
- n ≥ 2: "Auch ihre <n> früheren Fassungen gelten dann nicht mehr und sind für das Team nicht mehr sichtbar."
"ihre" refers to the Bedarfsabklärung, not to a person (UXR-81 does not apply). Vitest n = 0, 1, 2 as in my 15:50 remedy; one constant with the confirming step.

**UXR-89 amended (AN3 figure cards, #841).** My 19:55 remedy stands with `cra`'s two conditions added, so it reads: label, value and base visible; definition and source behind one "Wie gemessen" disclosure per card; the month once in the block header; **(b) card** = "Unterschrift bis Gegenzeichnung", "Berichte mit Rückgabe" and "Einsätze mit Zeitkorrektur", all three values visible with the disclosure closed; **(e) card** = "Vorschlag bis Entscheid" with "Davon geändert", "Davon abgelehnt", "Abgelaufen ohne Entscheid", all four values visible; on these two cards the line **"Kein Richtwert."** stays outside the disclosure, directly under the card title. The definitions keep "Eine Tatsache, kein Richtwert: …" word for word inside the disclosure. Playwright at 390 px with every `summary` closed: the three (b) values, the four (e) values and both "Kein Richtwert." lines are visible; no definition text is.

**CGR-118 (1) and CGR-121 (b): the offline banner (A-07, M6, PLANNED).** `attention` tone, under the page header on every screen, `role="status"` once when it appears (not repeated on each re-render), at most three short lines at 390 px:
1. "Keine Verbindung."
2. "Was du eingibst, bleibt auf diesem Gerät. Gesendet wird es, wenn NAVORA offen ist und die Verbindung zurück ist."
3. "Neue Sicherheitssignale kommen erst danach an. Dringendes jetzt telefonisch melden."
Line 2 holds the foreground fact (ADR-142, no background sync) and is true together with CGR-121 (a), because pending entries in IndexedDB survive a closed or reloaded app and are deleted only after the confirming sign-out step (ADR-143). Line 3 holds both CGR-118 (1) facts. "Sicherheitssignale" is the term of the push opt-in (catalog SC-2). If `eng` finds that pending entries do not survive a reload on some device (iOS, UNKNOWN), line 2 must not be shown there as written.

**CGR-118 (2) and CGR-121 (b): each pending card.** One `info` line on the card, never green, never "erledigt":
- kinds that reach another person (list owned by `cra`: observation, safety alert, absence, no-show, not completed): "Noch nicht beim Team. Wird gesendet, wenn NAVORA offen ist und Verbindung besteht."
- other kinds: "Noch nicht gesendet. Wird gesendet, wenn NAVORA offen ist und Verbindung besteht."
- only while a resend is actually in flight: "Wird gesendet …"; then one `role="status"` line "Gesendet." or the server's refusal on the card.
- refused with `access_ended` (ADR-143): "Nicht gesendet: dein Zugang ist beendet. Bitte telefonisch ans Team weitergeben." (stays on the card; `lca` confirms because it touches the access end).
- after an expired session: once she has signed in again, one `role="status"` line "<n> Eingaben von dir werden jetzt gesendet." (never before her own sign-in, never to another user).

**CGR-121 (a): the sign-out step with pending entries.** An `alertdialog` with initial focus on the default action:
- title: "Noch nicht gesendet: <n> Eingaben"
- one line naming the kinds with counts, from the same labels as the cards, e.g. "2 Beobachtungen, 1 Abwesenheit"
- "Wenn du dich jetzt abmeldest, werden sie von diesem Gerät gelöscht. Das Team erfährt nichts davon. Dringendes jetzt telefonisch melden."
- default (primary, focused, Escape does the same): "Zurück und senden" when connected; when offline the same button reads "Zurück", because nothing can be sent at that moment (`cra` to confirm this variant of the default label).
- second act (secondary, `danger` text, never pre-focused, separated from the primary): "Abmelden und Eingaben löschen".
`lca` confirms the deletion sentence (care text on the device, SC-2). Playwright with `context.setOffline`: one pending observation, sign-out opens the dialog, focus on "Zurück", Escape keeps her signed in with the entry; only "Abmelden und Eingaben löschen" signs out.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-91 | A-07 offline state, every screen (nurse; phone), M6, PLANNED; my own catalog line | medium | My catalog says each pending command shows "Wird gesendet …" on its card. While offline nothing is being sent, and under ADR-142 nothing is sent while the app is closed; "Wird gesendet …" reads as "on its way", which is the false reassurance CGR-118 (2) and CGR-121 (b) name. The banner wording in the same line ("bleiben erhalten … sobald die Verbindung zurück ist") also lacks the foreground and the safety-signal facts. | `docs/design/NAVORA_SCREEN_CATALOG.md:191` (A-07, merged with #834); `APP1_IMPLEMENTATION_PLAN.md` offline queue (#837 `7458904`) | §1 what needs attention now; §4 say what happens; DESIGN_SYSTEM §5 offline rule (new, OPEN) | Pending cards and banner as in *Answers to `cra`* above; "Wird gesendet …" only while a request is in flight. When MOB1 is written: e2e offline (`context.setOffline`) asserts no "Wird gesendet" text on a pending card while offline, the "Noch nicht beim Team" line on a pending observation, and both banner facts. I correct the catalog line in my next catalog change (outside this PR's three files). | — (medium; PLANNED screen) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-88 | OPEN on #841; **`cra` confirmed** (21:30) with the definitions kept word for word. | `8907913`, `step-spans.ts:37-117` unchanged |
| UXR-89 | OPEN on #841; remedy **amended** above with `cra`'s card conditions. | `8907913`, `step-spans.tsx` unchanged |
| UXR-90 | OPEN (low) on #841. | `8907913`, `step-spans.ts:156` |
| UXR-84 | OPEN on #815; **`cra` confirmed** the sentence (21:30). | `4474184` |
| UXR-75, -78 | Met on PR head #799 (`642edf0`, `e2e` green per `cra` 21:30); close on merge. | 19:55 section |
| UXR-79; UXR-73 | Met on PR heads (#800; #813 with UXR-82 residual); close on merge. | 11:50 section |
| UXR-80 to -83, -85 to -87 | OPEN, unchanged (heads moved by base merges only). | 15:50 and 11:50 sections |

**AN3-5.** Settled: `cra` 21:30 confirms the built share meets AN3-5 and `po` 22:00 aligned the brief wording; my 19:55 UNKNOWN is answered.

**Waiting for the PO.** Placing the offline wording in the MOB1 brief (M6, due 2026-11-27) with `cra`'s confirmation of the facts, the offline variant "Zurück", and `lca`'s confirmation of the deletion and access-end sentences; placing UXR-88/-89 on #841 (may ride before merge, `cra`) and CGR-113 on #815.

---

## 2026-11-03 19:55 CET · `uxa`: new #841 (AN3, `/analytics` "Wo die Nicht-Pflegezeit hingeht") and the UX2-31 amendment on #799 read on PR heads; UXR-88, -89 (medium), UXR-90 (low); UXR-75, -78 met on #799

**What changed since 15:50.** My PR #839 is still open (CI green on `7fe88f6`, clean, not merged); this run continues it. `recovery/main` is unchanged at `1b1d151`; **no screen code merged**. Open PRs that change screens:
- **#841** AN3 (new, head `aeec158`, ADR-144): a block "Wo die Nicht-Pflegezeit hingeht" on `/analytics` between the AN1 tables and the AN2 hypotheses; per scope (organisation, then each team) 14 figures, each with value, base, period, definition and source.
- **#799** UX2-1 (head `12a44f9`, was `f394ec5`): UX2-31 amendment (po 06:30, ADR-131 addendum): "Ausnahmen" as first tab for a person in no team whose home is `/operations`; below 768 px `scroll-padding` from the measured tab bar and sticky header heights.
- #800, #803, #804, #806, #809, #813, #814, #815: heads moved by base merges only (e.g. #815 `4474184`, #814 `3fe219b`, #813 `8e4ab0b`), **no change under `src` or `tests`**. My 03:52 to 15:50 notes on them stand. #837, #838, #840 (docs), #828 (no screen change), #842 (`cra`) not reviewed for screens.

**Sources.** `ui-screenshots` artifacts exist for these heads, but the archive still redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from the code on the PR heads. No benchmark this run (made at 03:52 today). I ran no test; CI is the test runner. Live project not touched.

### What the PRs do well (built on PR heads, not yet on `recovery/main`)
- #799: the home tab is chosen only from items her menu already holds, nothing added or dropped (`lib/auth/shell.ts` `homeTabFor`, `shellItemsFor`); a team member keeps Heute, Team, Arbeitstag. The scroll padding follows the real heights through a `ResizeObserver` and adds 0.5rem so the focus outline stays visible (`AppShell.tsx` `useShellScrollPadding`, `globals.css` max-width 767.98px); Playwright covers both (`ux2-shell.spec.ts`, UX2-31 tests). `/field` and `/work` render their sticky header on the server (no `loading.tsx`), so the header is measured at mount.
- #841: never per person and no target, colour scale or ranking (AN3-3, AN3-5); a suppressed figure shows "–" and "Basis –" rather than a guessed value; cards stack, so 390 px fits without sideways scroll; `role="group"` with "Schritte: <Team>" keeps the AN1 region names unique; "zu wenig Daten" uses the AN1/AN2 chip (one pattern on the page).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-88 | `/analytics` AN3 block (team member, coordinator, coach, administrator; phone and desktop); built on open PR #841 | medium | Every figure's visible source line carries internal codes, and the first label carries an English product term: "(North Star)", "WORK1-6", "F1–F4", "F6/F7 (AN1)", "F6R (AN2)", "F6R-9", "F3 (AN1)", "J1", "ORD0", "AIG1-Protokoll (AIG1-C4)". A nurse or coach reads "Quelle: Aufgaben ORD0" and learns nothing about where the number comes from. AN1's sources on `recovery/main` already carry some codes (`features/analytics/rules.ts:42-92`, in the UX1-C2 scope for `src/features`, PLANNED); AN3 adds new ones in a new block. | `aeec158`, `features/analytics/step-spans.ts:37-117` (`STEP_FIGURES` label, definition line 38, every `source`); shown at `analytics/step-spans.tsx:53` | §4 no internal codes in user text; one product name and plain German | Sources in plain words ("Bestätigte Arbeitstage", "Einsatzzeiten", "Berichte", "Rückgaben", "Zeitkorrekturen", "Partneranfragen", "Aufgaben «Hausärztin/Hausarzt informieren»", "Protokoll der Assistenzvorschläge"); the code moves to `data-ref` on the line (not read aloud); "(North Star)" dropped from the label. Vitest: no `label`, `definition` or `source` in `STEP_FIGURES` (and AN1 `KPI`) matches `/\b(F\d|F6R|J\d|WORK\d|ORD\d|AIG\d|AN\d)\b|North Star/`. Substance of the definitions unchanged; `cra` confirms (AN3-5 wording). | — (medium) |
| UXR-89 | `/analytics` AN3 block (team member, coach; phone 390 × 844); built on open PR #841 | medium | Each scope lists 14 figures, each with label, value, base, the month (the same month on every line, already chosen at the top of the page) and a definition of up to three sentences plus source, all open. One team is several screens at 390 px; the organisation block comes first, so a team member scrolls past it before her own team. Related figures ("Vorschlag bis Entscheid" and its three "Davon …"/"Abgelaufen" lines; the GP task and its two "offen" lines) are separate cards, so "Davon geändert" reads without its parent in a screen reader's list. What she needs at a glance (where the time goes) is buried in definitions she reads once. | `aeec158`, `analytics/step-spans.tsx:37-56` (every `li` renders `periodLabel` line 50 and `f.definition` line 53); `step-spans.ts` `STEP_FIGURES` | §5 density (one line under a heading; details behind "Details"); §1 what needs attention first | Per figure: label, value and base visible; definition and source behind one `<details>` "Wie gemessen" (`summary` `min-h-11`), text unchanged; the month once in the block header, not per line; related figures as one card with sub-rows (GP task: erledigt / offen am Monatsende / Alter; proposals: bis Entscheid / geändert / abgelehnt / abgelaufen), so AN3-5's "beside" condition still holds. Playwright at 390 px: no definition text visible before a `summary` is opened; `step-period` occurs once per scope. The order org before team is the PO's (AN1 pattern); `cra` confirms the AN3-5 grouping. | — (medium) |
| UXR-90 | `/analytics` AN3 block, several teams (coordinator, administrator; desktop) | low | Teams are sorted by their internal id (`a.localeCompare(b)` on the scope key), so the order looks random and differs from a team list sorted by name. | `aeec158`, `features/analytics/step-spans.ts:156` | §5 consistency; predictable order | Organisation first, then teams by name with `Intl.Collator("de-CH")` (same in the AN1 tables); vitest on `buildStepScopes` with two teams whose id order and name order differ. | — |

**AN3-5, for `cra` (UNKNOWN from the UX side).** The brief places the countersign latency beside the team's returned share and its *open time corrections*; the block shows "Einsätze mit Zeitkorrektur" (share of completed visits with at least one correction). Whether that meets AN3-5 is `cra`'s to confirm; I make no proposal on the substance.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-75, -78 | Met on PR head #799 (UX2-31 (1), (2)); close on merge. | `12a44f9`, `lib/auth/shell.ts` `homeTabFor`; `AppShell.tsx` `useShellScrollPadding`; `globals.css`; `ux2-shell.spec.ts` UX2-31 tests |
| UXR-84 to -87 | OPEN on #815 / #814; heads changed by base merges only. | `4474184`, `3fe219b` |
| UXR-82; UXR-83 | OPEN (low), unchanged. | `8e4ab0b`; 15:50 section |
| UXR-79; UXR-73 | Met on PR heads (#800; #813 with UXR-82 residual); close on merge. | 11:50 section |
| UXR-80, -81 | OPEN (low) on #809; head changed by a base merge only. | `7f74e71` |
| UXR-36, -37, -40, -41; -56, -58, -61, -62, -63; -27, -28, -46, -48, -53, -72 | Met on PR heads; close on merge. | 03:52 to 11:50 sections |
| UXR-57 | Partly met on #806 (assessor prefill PLANNED, ADR-135). | `91e7bc9` |
| UXR-64; UXR-76, -77; UXR-68 | PLANNED (UX2-30 (7); UX2-32; PLAN3-12). | briefs |
| UXR-65, -74 | OPEN (low), unchanged. | no screen merge |

**For the PO.** (1) UXR-88, -89 can ride #841 before merge (strings and presentation only; `cra` confirms wording and grouping). (2) AN3-5 "open time corrections" vs. the built share: `cra`'s call. (3) Nothing severe or high; no issue opened.

---

## 2026-11-03 15:50 CET · `uxa`: new PRs #814 (AIG1-C4/-C5, `/operations/assistenten`) and #815 (ASM1-C6 "Irrtümlich erfasst", `/team`) read on PR heads; UXR-84, -85 (medium), UXR-86, -87 (low); CGR-113 sentence proposed

**What changed since 11:50.** On `recovery/main` (`1b1d151`) only docs merged: my #798, `csa` #821, `lca` #823, `po` #822, `aia` #829, `po` #832, my design set #834 (15:00, owner request; no report section) and `po` #836 (baseline adopted; UX2-33 error pages added to UX2). **No screen code merged.** Open PRs that change screens:
- **#814** AIG1-C4 + AIG1-C5 (new, head `dc1b2b4`, ADR-139): `/operations/assistenten` shows "Abgelaufen ohne Entscheid: <n>" under the decided count, the state as a status ("Gestoppt seit <Datum>", "Aus", "Ein") and every stop as a list (open stops with "Betroffene Werte ansehen", stops at 0 offen as history).
- **#815** ASM1-C6 with C6 (8) (new, head `f0a2752`, ADR-140): "Irrtümlich erfasst" beside "Korrigieren (ersetzen)" on `/team`; P-37 form (`cra` sentence, two radios, free text after "Anderer Grund"), UX2-23 confirming step, void line in the history, C6 (8) basis sentence at `info`.
- #799 (`f394ec5`), #800 (`a3be7db`), #803 (`f93fc81`), #804 (`12d0923`): heads moved by base merges only, **no change under `src` or `tests`**; #806, #809, #813 unchanged. My 03:52 to 11:50 notes on them stand.

**Sources.** `ui-screenshots` artifacts exist (e.g. `recovery/main` `1b1d151`: 13239537813; #815 `f0a2752`: 13230647751; #814 `dc1b2b4`: 13227258635); the archive still redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from the code on the PR heads. No benchmark this run (made at 03:52 today). I ran no test; CI is the test runner. Live project not touched.

### What the new PRs do well (built on PR heads, not yet on `recovery/main`)
- #815 follows the preset pattern (§2): `fieldset` with visible legend "Grund", neither radio preselected, rows `min-h-11`, free text and hint only after "Anderer Grund", the `cra` sentence before the options (`team/assessment-void-fields.tsx:47-63`); the void act sits behind the shared confirming step whose sentence names the consequence ("Danach gilt diese Bedarfsabklärung nicht mehr. Der Eintrag bleibt gespeichert …", `features/assessment/rules.ts:344`); the void line is a label, not a strike (deviation 4); no field of a voided record is rendered (`renderVoided`, `assessment-section.tsx:139-150`); the basis sentence sits where the marker sits, outside the folded history, at `info` (`plan-assessment-basis.tsx:51-55`).
- #814 states the agent as a status, not a to-do, and keeps a stop with open lines actionable whatever the state; history lines are muted and carry no link (`operations/assistenten/page.tsx:95-113`). No person column.

### Wording answers (OPEN until built)

**CGR-113 (`cra` 13:30, "with `uxa`"), void of a corrected record.** ADR-140 deviation 1: a void also withholds the record's earlier versions in its supersede chain. Proposed second sentence of the confirming step, shown only when the record replaced at least one earlier version (count from the reader): "Auch <ihre frühere Fassung | ihre <n> früheren Fassungen> sieht das Team dann nicht mehr." Full step: "Danach gilt diese Bedarfsabklärung nicht mehr. Auch ihre 2 früheren Fassungen sieht das Team dann nicht mehr. Der Eintrag bleibt gespeichert; das Team sieht nur noch, dass er irrtümlich erfasst wurde." Testable: vitest on the sentence for n = 0 (absent), 1, 2. `cra` confirms the substance; placement by the PO with CGR-113.

**ADR-140 deviation 6, supersede sentence** (see UXR-84): keep the `cra` substance, change only the quoted command name to the label on screen: "Ist nur ein Wert falsch, nutze «Korrigieren (ersetzen)». «Irrtümlich erfasst» ist nur für eine Erfassung, die nicht in diesen Fall gehört." `cra` confirms.

**#814 labels (Engineering's from the brief, "`uxa` may replace").** "Abgelaufen ohne Entscheid: <n>", "Gestoppt seit <Datum>", "Aus", "Ein": **confirmed** as built. Stop lines: see UXR-87.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-84 | `/team` case card, void form (registered nurse, phone); built on open PR #815 | medium | The sentence that steers a nurse away from the void tells her to use «Ersetzen», but the button beside it reads "Korrigieren (ersetzen)". In the one moment where the choice matters (wrong value of the right client vs. wrong client), the help names a command she cannot find by that word. ADR-140 deviation 6 left this to `uxa`. | `f0a2752`, `features/assessment/rules.ts:339-340` (`VOID_SUPERSEDE_SENTENCE`) vs. `team/assessment-section.tsx` button "Korrigieren (ersetzen)" | §4 one command, one label; §2 one primary action | `VOID_SUPERSEDE_SENTENCE` quotes «Korrigieren (ersetzen)» (wording above); vitest asserts the sentence contains the exact label of the supersede button (one constant). `cra` confirms. | — (medium; PR comment) |
| UXR-85 | `/team` void form, "Anderer Grund" (registered nurse, phone); built on open PR #815 | medium | "Irrtümlich erfasst markieren" stays disabled until the free text has 10 characters, but neither the label ("Grund (eigener Text)") nor the hint says so. A nurse who types a short reason sees a button that does not work and no reason why (a disabled button is not focusable and gives no message). | `f0a2752`, `team/assessment-void-fields.tsx:65-82`, `rules.ts:336-337` and `voidSubmitEnabled` (10 to 500) | §2 a short preset beside free text (submit disabled until valid); §4 a refusal says what to change; §6 | Label "Grund (10–500 Zeichen)", as on `/admin` "Begründung (3–300 Zeichen)"; vitest asserts the label names the bounds that `voidSubmitEnabled` checks. Hint words unchanged (`lca` refinement, po 13:28). | — (medium; PR comment) |
| UXR-86 | `/team` void, refused by the database (registered nurse, keyboard or screen reader); built on open PR #815 | low | After a refusal the confirming step unmounts (`setAsking(false)`) while its focused button is pressed; focus falls to the page body. The error is announced (`role="alert"`) but a keyboard user starts again from the top of a long `/team` page. | `f0a2752`, `team/assessment-void-form.tsx:33-37` | §6 when a dialog's content is replaced, focus moves to the new content | After a refusal focus moves to the submit "Irrtümlich erfasst markieren" (or the error line, `tabIndex=-1`); Playwright: refuse, assert `document.activeElement` is inside `assessment-void`. | — |
| UXR-87 | `/operations/assistenten`, stop column (Operations, administrator; desktop, screen reader); built on open PR #814 | low | With two stops that still have open lines, the cell holds two links both named "Betroffene Werte ansehen"; in a screen reader's link list they cannot be told apart. The history line starts in lower case ("gestoppt am …") while the open line starts "Gestoppt am …" and has "Werte:" before the counts. | `dc1b2b4`, `operations/assistenten/page.tsx:96-108`; `features/ai/labels.ts` `stopOpenText`, `stopHistoryText` | §6 link purpose; §4 one wording | Link keeps its visible text and gets `aria-label="Betroffene Werte ansehen, Stopp vom <Datum>"`; `stopHistoryText` starts "Gestoppt am" and uses `lookbackCountsText`; vitest on both strings. | — |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-83 | OPEN (low); `cra` 13:30 prefers the member-number form ("Teammitglied <n> (ohne Namen)") on the visit card too. | `cra` 13:30 journal |
| UXR-82 | OPEN (low) on #813; head unchanged. | `01dee6c` |
| UXR-79; UXR-73 | Met on PR heads (#800; #813 with UXR-82 residual); close on merge. | 11:50 section |
| UXR-80, -81 | OPEN (low) on #809; AUT-35 label confirmed by `cra` 13:30. | `f209c1f` |
| UXR-36, -37, -40, -41; -56, -58, -61, -62, -63; -27, -28, -46, -48, -53, -72 | Met on PR heads; heads changed by base merges only; close on merge. | 03:52 to 11:50 sections |
| UXR-57 | Partly met on #806 (assessor prefill PLANNED, ADR-135). | `a5875e2` |
| UXR-64; UXR-75, -78 / -76, -77; UXR-68 | PLANNED (UX2-30 (7); UX2-31 / UX2-32; PLAN3-12). | briefs |
| UXR-65, -74 | OPEN (low), unchanged. | no screen merge |

**For the PO.** (1) CGR-113 sentence proposed above (`cra` confirms). (2) UXR-84, -85 can ride #815 before merge (string changes only). (3) Nothing severe or high; no issue opened.

---

## 2026-11-03 11:50 CET · `uxa`: #800 amendments (UX2-27/-29: CGR-108, CGR-109, UXR-79) and new #813 (RLS4-C3) read on PR heads; UXR-82, -83 (low); CGR-108 wording confirmed; AUT-35 label proposed; RLS4-C3 (2) interim noted

**What changed since 07:52.** My PR #798 is still open (CI green on `b6d22ac`, not merged); this run continues it and merged `recovery/main` `547d807` in (JOURNAL: both entries kept, newest first). On `recovery/main` only docs merged (#811 `aia` review 19); **no screen code merged**. Open PRs that change screens, each with app, db, e2e and ui-screenshots `success` on its head (read from GitHub check runs; I ran no test):
- **#800** UX2-27, UX2-29 (head `748ef3f`, was `158a8b3`): amendments from the PO 06:30 (CGR-108, CGR-109, UXR-79; ADR-132 addendum).
- **#813** RLS4-C3 (new, head `01dee6c`, ADR-138): `/admin` access-end step offers "Erneut laden" after a failed open-report read; a missing count is never "Keine offenen Berichte".
- #799, #803, #804, #806: heads unchanged (`a8699dd`, `7913eac`, `9f1511d`, `a5875e2`); #809 (`f209c1f`) only merged `recovery/main`, no change under `src` or `tests`. #810 (CGR-110) is pgTAP and CI only. My 03:52 and 07:52 notes on them stand.

**Sources.** `ui-screenshots` artifacts exist for #813 `01dee6c` (13223065998), #800 `748ef3f` (13219004243) and `recovery/main` `547d807` (13212323610); the archive still redirects to a blob host the proxy refuses to this role (403 again this run), so **no screenshots were available**. Reviewed from code on the PR heads. Synthetic seed only; the live project was not touched. No benchmark this run (one made today, 03:52).

### What the open PRs do well (built on PR heads, not yet on `recovery/main`)
- #800: an empty responsible member reads "noch niemand" only while the visit is open (dated today or later and status planned, on the way, started or paused) and "nicht erfasst" otherwise, from one function `responsibleEmptyText` used by `/visits` and the record page (`features/visits/types.ts:36-64`; `visits/[visitId]/page.tsx:48`); no legacy name is shown. Both "Ändern" pickers share one placeholder "Verantwortliche Person wählen" and the AI field label is now "Verantwortlich" (`RESPONSIBLE_PICK_TEXT`, `features/ai/labels.ts` `FIELD_LABEL`): UXR-79 met on the head; this supersedes my 31.10 proposal "Zuständige Person wählen" (one word per concept wins, §4). In the handover an unnamed colleague keeps her number: "Teammitglied <n> (ohne Namen)" (`handover/rules.ts:89`).
- #813: the failure line and "Erneut laden" sit in one block, the button outline and `min-h-11`, directly after the line (`admin/member-open-reports.tsx:26-34`); the retry runs the same read for this one member and nothing else; ending access stays possible without the list (product decision); a null count never yields "Keine offenen Berichte" (`features/admin/rules.ts` `accessEndedNotice`), with unit tests.

### Wording answers (OPEN until built)

**CGR-108 (UX2-27 amendment), handover author without a display name** (`cra` 09:30 waits on `uxa`): built "Teammitglied <n> (ohne Namen)" **confirmed**: the number keeps two unnamed authors apart and matches her other entries in the same handover; the bracket says why there is no name without blaming her. No further change.

**RLS4-C3 (2), result line on a missing count.** #813 ships the PO's interim "Offene Berichte unbekannt: das Team sieht sie mit «Zugang beendet»." (`cra` 09:30 confirmed it claims no absence; ADR-138 deviation 1 keeps my 07:52 sentence OPEN for the PO). From the UX side the interim is acceptable for merge: it never says "keine". My 07:52 sentence stays the proposal because "sieht sie" presumes that reports exist, which the screen does not know. The PO decides; not a reason to hold #813.

**AUT-35 / `cra` 09:30, reason field when the administrator first sets a qualification** (#809, `QUALIFICATION_REASON_LABEL` "Begründung (3–300 Zeichen)"). `cra` keeps a typed reason while CGR-16 is open and asks for a label that asks what was checked. Proposed label: **"Was hast du geprüft? (3–300 Zeichen)"**, with the input's `aria-describedby` hint "Die Angabe wird mit der Qualifikation gespeichert." Examples of evidence (which document or register) are **UNKNOWN**: the verification rule is the owner's and `clinical`'s; I name none. The refusal "Die Begründung braucht 3 bis 300 Zeichen." becomes "Die Angabe braucht 3 bis 300 Zeichen." `cra` confirms; can ride #809 (two strings and their test).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-82 | `/admin`, access-end step after a failed open-report read (administrator, desktop, keyboard or screen reader); built on open PR #813 | low | "Erneut laden" is unmounted as soon as it is pressed (the block shows "Offene Berichte werden geladen …"), so keyboard focus falls to the page body; when the second read succeeds the count line is a plain `p`, so a screen-reader user hears nothing (only a repeated failure is announced, through the `alert`). She must find the step again to learn whether the list came. | `admin/member-open-reports.tsx:24-35` (button only in the `null` branch; success line without `role`); `admin-client.tsx:237-240` (`readOpen` sets "loading") | §6 when content is replaced, focus moves to the new content, never the body; §6 a notice is reachable from where focus lands | Keep "Erneut laden" rendered and `disabled` with the text "Wird geladen …" while the read runs, or move focus to the step's result line (`tabIndex=-1`) when the read returns; the loading and result lines sit in one `role="status"` container. Playwright (desktop, read forced to fail once): press "Erneut laden" with the keyboard → after the read `document.activeElement` is inside `[data-testid=open-reports]`, and the container has `role="status"`. | report only (low); PR comment #813 |
| UXR-83 | `/field` visit card, observation meta line (nurse, phone) vs. the handover; built on open PR #800 | low | The same colleague without a display name reads "Teammitglied ohne Namen" on the visit card (no "von", no number) and "Teammitglied 3 (ohne Namen)" in the handover. Two words for one person, and the card's line breaks the "von <Name>" / "von dir" pattern beside it. | `features/field/authorship.ts` `observationAuthor` (returns `AUTHOR_WITHOUT_NAME_TEXT`); `field-client.tsx:743`; `handover/rules.ts:89` | §4 one word per concept; §4 one command, one label | If the card's read can carry the member number (UNKNOWN, `eng`): "von Teammitglied <n> (ohne Namen)"; otherwise "von einem Teammitglied ohne Namen". vitest: `observationAuthor` for an unnamed colleague starts with "von ". | report only (low) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-79 | Met on PR head #800 (UX2-29 amendment); close on merge. | `748ef3f`, `RESPONSIBLE_PICK_TEXT`, `FIELD_LABEL`; `ux2-wording.test.ts` (CI success on head) |
| UXR-73 | Met on PR head #813 (RLS4-C3 (1), (3)); (2) wording OPEN with the PO (above); residual UXR-82; close on merge. | `01dee6c`, `member-open-reports.tsx`, `rls4-c3-admin-open-reports-retry.test.ts` |
| UXR-80, -81 | OPEN (low) on #809; head changed only by a base merge. | `f209c1f` |
| UXR-36, -37, -40, -41; -56, -58, -61, -62, -63; -27, -28, -46, -48, -53, -72 | Met on PR heads (#804, #806, #803, #800, #799); close on merge; heads unchanged under `src` except #800 (amendments only). | 07:52 and 03:52 sections |
| UXR-57 | Partly met on #806 (assessor prefill PLANNED, ADR-135). | `a5875e2` |
| UXR-64 | PLANNED (UX2-30 (7)). | ADR-135 |
| UXR-75, -78 / UXR-76, -77 | PLANNED (UX2-31 / UX2-32). | `briefs/UX2.md` |
| UXR-65, -74 | OPEN (low), unchanged. | no screen merge since `3a6b9c6` |
| UXR-68 | PLANNED (PLAN3-12). | — |

**For the PO.** (1) RLS4-C3 (2): interim sentence acceptable for merge; my 07:52 sentence remains the proposal (your call, `cra` confirms). (2) AUT-35: label "Was hast du geprüft?" proposed in answer to `cra`; can ride #809 with UXR-80, -81. (3) CGR-108 wording confirmed as built on #800. (4) No `severe` or `high` finding, no issue; one comment on #813. (5) Eight PRs with screen changes are open and green; I hold no UX objection to their merge. (6) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-11-03 07:52 CET · `uxa`: open UX2 PRs #804 (UX2-18 to -21), #806 (UX2-30), #809 (UX2-26) read; UXR-80, -81 (low); RLS4-C3 (2) wording answered; UX2-30 (4)/(5) wording confirmed

**What changed since 03:52.** My PR #798 is still open (CI green on `091128e`, not merged); this run continues it and merged `recovery/main` `6d6dbba` in (JOURNAL: both entries kept, newest first). On `recovery/main` only docs merged (#805 `lca`, #808 `po`); **no screen code merged**. The PO (06:30) placed UXR-75/-78 as **UX2-31**, UXR-76/-77 as **UX2-32**, UXR-79 into UX2-29, and set **RLS4-C3** from UXR-73 with the result-line wording asked of `uxa`. #799, #800, #803 only merged `recovery/main` since my read (heads `a8699dd`, `158a8b3`, `7913eac`; no change under `src` or `tests`), so my 03:52 notes on them stand. Three new open Engineering PRs change screens, each with app, db, e2e and ui-screenshots `success` on its head (read from GitHub check runs; I ran no test):
- **#804** UX2-18 to UX2-21 (head `9f1511d`): `/field` "Heute machen" confirmation and moved-card notices.
- **#806** UX2-30 (head `a5875e2`): `/team` assessment form and review line.
- **#809** UX2-26 (head `d18b60c`): `/admin` admission card offers "Qualifikation festlegen" after "Vertrag erfasst".

**Sources.** `ui-screenshots` artifacts exist for `recovery/main` `6d6dbba` (13207521419) and for the PR heads (#806 13209471387, #809 13207451687); the archive still redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from code on the PR heads. Synthetic seed only; the live project was not touched. No benchmark this run (one made today, 03:52).

### What the open PRs do well (built on PR heads, not yet on `recovery/main`)
- #804: the VIS1-8 slot is reserved from the first render by both wordings laid invisibly in one grid cell (`aria-hidden`), so "Von" and "Bis" keep their place at every width (UX2-18); the moved card's `aria-describedby` names the release notice and then the flags list, the list carries no `aria-label` that would replace its content, flags at `text-sm` with "⚠" plus text (UX2-19); the fallback reads "Inzwischen ist ein neuer Tag. Tippe auf «Einsätze von heute»." from one constant shared with the link (UX2-20); the focused day-changed sentence is no longer a live region (UX2-21). Playwright `ux2-move-flow.spec.ts` asserts the box of "Von" and the description.
- #806: one column below `sm` also for the minutes rows, e2e at 390 px checks every field ≥ 300 px and no sideways scroll, naming the element that overflows; "Ersetzt die Bedarfsabklärung vom <Datum>" heads the replace form; the instrument is prefilled only when exactly one catalogue entry matches and is valid on that date, otherwise nothing is guessed; one `ErrorText` for `/team`; "Keine aktuelle Bedarfsabklärung." before the closed history. The assessor prefill is held back because the reader has no assessor id and a name match could name the wrong nurse (ADR-135); that is the safe call, PLANNED.
- #809: the layout as proposed 29.10. 16:10: "angegeben: <Qualifikation>" as text, a fieldset with one 44 px radio row per qualification in a fixed order, none checked, the claimed one neither marked nor first, the reason with its rule in the label, "Qualifikation festlegen" filled and "Später" outline; "Später" sets nothing and the member stays listed; the sentence "Die Qualifikation setzt die Administration wie bisher beim Mitglied" is removed.

### Wording answers (OPEN until built)

**RLS4-C3 (2), result line after an access end whose open-report count is missing** (`openReports === null`; Engineering's interim "Offene Berichte unbekannt: das Team sieht sie mit «Zugang beendet»."). Proposed, in the place of the count sentence of `accessEndedNotice`:
"Zugang beendet.<Einsätze><Signale> **Offene Berichte: nicht bekannt, die Liste liess sich nicht laden. Falls es welche gibt, sieht das Team sie mit «Zugang beendet».**<Tage>"
Why: it says what is missing and why, never "keine"; "Falls es welche gibt" avoids claiming that reports exist, which the screen does not know either; the billing clause of the counted line ("sie werden nicht verrechnet") is left out because it states a fact about reports the screen has not read (UNKNOWN whether it holds for every open kind; `cra` may restore it). `cra` confirms the sentence (H-12); no client or outside text, so no `lca` read. **RLS4-C3 (1):** "Erneut laden" confirmed as the label, `action-outline`, directly after the failure line in the same block.

**UX2-30 (4), refusal and hint** (ADR-135 marks mine as PROVISIONAL): confirmed as built: hint "Kennung aus eurem Abklärungsinstrument, z. B. BA-2026-0042: mindestens eine Ziffer, ohne Leerzeichen, Punkt oder Schrägstrich."; refusal "Diese Referenz ist keine Kennung: 3 bis 64 Zeichen, nur Buchstaben, Ziffern und _ : # -, mindestens eine Ziffer." The example is a format sample, not a real record reference.

**UX2-30 (5), second sentence of the review line:** "Diese war damals nicht bestätigt." follows "… gegen die Bedarfsabklärung vom <Datum>.", so "Diese" can be read as the care plan. Proposed: **"Die Bedarfsabklärung war damals nicht bestätigt."** (`STATE_LABEL` value unchanged). The fact is `cra`'s (a); `cra` confirms the wording. Can ride #806 (one string and its e2e regex).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-80 | `/admin`, "Vertrag erfasst, Qualifikation fehlt" list (administrator, desktop); built on open PR #809 | low | The rows show "<Name> · <Team>" and nothing to do; to set the qualification she must find the member in «Mitglieder» herself, and a card closed with "Später" cannot be reopened. The list answers question 1 but not question 2. The list is built from every membership without a qualification (`membersWithoutQualification(data.members)`); `addTeamMember` requires one, so ADM2-6 is probably the only source, but whether seed, legacy or migration rows without a qualification exist is UNKNOWN (`eng`); if they do, the heading "Vertrag erfasst …" states a fact the list does not check. | `admission-section.tsx:116-123`; `admin-client.tsx` (`missing={membersWithoutQualification(data.members)}`); `admin/commands.ts:75` | §1 question 2; §2 an item that asks for an action carries the way there; §4 a heading states what the list holds | Each row carries one link "Qualifikation festlegen" (`min-h-11`) to that member's entry in «Mitglieder» (anchor), or reopens the same offer card; `eng` says whether non-admission memberships without a qualification can exist, and if so the heading reads "Ohne Qualifikation" (PO). e2e (seed, after "Später"): the row has a link whose target is the member's entry, and following it shows the qualification control. | report only (low); PR comment #809 |
| UXR-81 | `/admin` admission card after "Vertrag erfasst" when the member is not yet in the member list (administrator); built on #809 | low | The fallback reads "Sie steht noch nicht in der Mitgliederliste. Die Qualifikation legst du unter «Mitglieder» fest." "Sie" assumes a woman and can be read as the polite "Sie", and the sentence does not say when she will appear (after reloading?), so the only control, "Später", is a guess. | `admission-section.tsx:200-204` | §4 plain words, no assumed gender; §1 what next | Name the person and the step: "<Name> steht noch nicht in der Mitgliederliste. Lade die Seite neu und lege die Qualifikation unter «Mitglieder» fest." (if a reload is in fact what makes her appear; else `eng` says what does, UNKNOWN). vitest: the fallback text contains the display name and no standalone "Sie". | report only (low); PR comment #809 |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-36, -37, -40, -41 | Met on PR head #804 (UX2-18, -19, -20, -21); close on merge. | `9f1511d`, `field-client.tsx` `MoveToToday`, `MovedNoticeBlock`; `field/rules.ts` `movedCardDescribedBy`, `DAY_CHANGED_RELOAD`; `ux2-move-flow.spec.ts` (CI success on head) |
| UXR-56, -58, -61, -62, -63 | Met on PR head #806 (UX2-30 (1), (3)-(6)); close on merge; -62 with the wording note above. | `a5875e2`, `assessment-section.tsx`, `error-text.tsx`, `assessment/rules.ts`; `asm1.spec.ts`, `ux2-assessment-form.test.ts` |
| UXR-57 | Partly met on #806: first line and instrument prefill built; assessor prefill PLANNED (needs the assessor id in the reader, ADR-135). | `a5875e2`, `prefillInstrumentId`, `supersedeFirstLine` |
| UXR-64 | PLANNED (UX2-30 (7) deferred in ADR-135: seed fixture for a second team). | ADR-135 "Not in this PR" |
| AUT-21 layout (`uxa` 29.10. 16:10) | Met on PR head #809 (UX2-26); residuals UXR-80, -81. | `d18b60c`, `admission-section.tsx` `RecordedCard`; `team-admission.spec.ts` |
| UXR-73 | PLANNED as RLS4-C3 (before G-19); wording above. | `briefs/RLS4.md` 06:30 |
| UXR-75, -78 | PLANNED (UX2-31). | `briefs/UX2.md` |
| UXR-76, -77 | PLANNED (UX2-32). | `briefs/UX2.md` |
| UXR-79 | PLANNED (UX2-29 amendment). | `briefs/UX2.md` |
| UXR-27, -28, -46, -48, -53, -72 | Met on PR heads #803, #800, #799 (03:52); close on merge. | heads unchanged under `src` |
| UXR-65, -74 | OPEN (low), unchanged. | no screen merge since `3a6b9c6` |
| UXR-68 | PLANNED (PLAN3-12), unchanged. | — |

**For the PO.** (1) RLS4-C3 (2) wording above (Engineering's interim can be replaced without a round, as with ADR-130 deviation 6, if you agree); `cra` confirms. (2) UX2-30 (5) wording note can ride #806. (3) UXR-80, -81 (low) could ride #809 before merge. (4) Six UX2 PRs are open and green with no blocking UX finding from me (#799, #800, #803, #804, #806, #809); I hold no objection to their merge on UX grounds. (5) No `severe` or `high` finding, so no issue opened; one comment on #809. (6) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-11-03 03:52 CET · `uxa`: UX2 open PRs read (#799 shell, #800 UX2-27/-29, #803 UX2-15/-16/-25): UXR-75, -76, -78 (medium), UXR-77, -79 (low); tab-label wording answered (ADR-131 deviation 1); benchmark navigation bar

**What changed since 31.10. 03:50.** My PR #798 was left open (CI green on `183264f`, not merged); this run continues it and merged `recovery/main` in (JOURNAL: both entries kept). On `recovery/main` (`b74a9b0`) only docs merged (#797 `lca`, #802 `aia`); **no screen code merged**. Three open Engineering PRs change screens, all with app, db, e2e and ui-screenshots `success` on their current heads (read from GitHub check runs; I ran no test):
- **#799** UX2-1 one shell (head `260dbf6`): `AppShell.tsx`, `lib/auth/shell.ts`, `PageFrame.tsx`; `Sidebar.tsx` and every `HeaderMenu` removed; `/team` joins the UX1-3 map. `cra` gate clear (comment 00:31).
- **#800** UX2-27, UX2-29 (head `1640cdc`): "von <Name>" on the visit card; "Teammitglied ohne Namen" in the handover; "Verantwortlich" / "noch niemand" on `/visits` and the record page.
- **#803** UX2-15, UX2-16, UX2-25 (head `dd32be6`): reach-gap line outside the `details`, 44 px `summary`; "Einsätze mit Handlungsbedarf" frame red only while a P1 entry is shown in full, otherwise amber; case reference `text-sm`; manual line beside "Fall öffnen" dropped (`cra` 29.10. 13:40).

**Sources.** `ui-screenshots` artifacts exist for all three heads (13199045159, 13197264604, 13197759077) and for `recovery/main` `b74a9b0` (13196069001); the archive still redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from code on the PR heads. Synthetic seed only; the live project was not touched.

### What the open PRs do well (built on PR heads, not yet on `recovery/main`)
- #799: one `nav` "Hauptmenü" at a time (`hidden md:flex` / `md:hidden`); tabs `min-h-14`, current tab marked by a 4 px bar **and** bold text plus `aria-current` (not colour only); "Mehr" keeps the UX1-26 behaviour (Escape returns focus, outside tap, closes on choice); "Abmelden" last; content column reserves the bar's height; product name as text, not a heading; the absence `<dialog>` uses `showModal()` and so sits above the bar (`AppShell.tsx:76-160`). The record page `/visits/[visitId]` gets the shell from the layout, which closes UXR-72 on merge.
- #803: the gap sentence and "Meine Einstellungen" can no longer be folded away, still before any member list and amber (`team-client.tsx` `OutsideDeliveryStatus`); the alert frame now says what it holds, never neutral while an entry is listed, unknown priority falls to amber (`team/rules.ts` `visitAlertFrame`); one way to act on a successor item.
- #800: one constant each (`RESPONSIBLE_LABEL`, `RESPONSIBLE_NOBODY_TEXT`, `AUTHOR_WITHOUT_NAME_TEXT`), a member code no longer appears as an author.

### Answer to ADR-131 deviation 1 (tab words vs page labels; wording, `uxa`/`po`)
Built: tabs "Heute", "Team", "Arbeitstag"; sidebar, menu and page headers "Mein Tag", "Dein Team", "Mein Arbeitstag" (`shell.ts` `TAB_LABEL`; `nav.ts` `PAGE_LABEL`). The same destination is named differently at 390 px and at 1440 px, and "Mein Tag" next to "Mein Arbeitstag" reads as one thing twice. Proposed: **one label per destination, the short one, in tab bar, sidebar and menu**: "Heute" (`/field`), "Team" (`/team`), "Arbeitstag" (`/work`); `PAGE_LABEL.team` → "Team", `PAGE_LABEL.work` → "Arbeitstag", `PAGE_LABEL.field` → "Heute". `/field` already heads today with "Heute" and another day with its date plus the "Heute" link back, so "Heute" is the right name for the destination; the small header line above the `h1` on `/field` and `/work` is then dropped where it only repeats the tab (UX1-32 spirit: no eyebrow above the `h1`). `TAB_LABEL` then disappears (one source). No safety or legal text involved; `cra` need not confirm. OPEN until built.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-75 | Shell at 390 px (coordinator, coach, administrator without team membership); built on open PR #799 | medium | Their only tab is "Arbeitstag"; their home "Ausnahmen" (signals, OPS1 exceptions), "Aufnahme" and "Administration" sit behind "Mehr". The bar then holds one real destination plus a menu, and the page that answers question 1 for these roles is two taps away from any other page. ADR-131 deviation 3 names it as a PO question. | `shell.ts` `TAB_KEYS` (fixed `field`, `team`, `work`); `AppShell.tsx` `TabBar`; `docs/engineering/DECISIONS.md` ADR-131 deviation 3 | §1 question 1 on every screen; §5 one shell per role; benchmark below (a bar holds 2-5 core destinations) | The role's home is always the first tab: for a role whose home is `/operations`, the first tab is "Ausnahmen" (then up to two of `field`, `team`, `work` she may open, then "Mehr"). Unit `ux2-shell.test.ts`: operations-only access → tabs `["operations","work"]`; nurse unchanged. Playwright 390 px, coordinator: the first tab's `href` is `/operations`. Safety signals stay in page content, nothing moves above or below them. PO decides. | report only (medium); PR comment #799 |
| UXR-76 | Shell, all roles, phone vs desktop; built on #799 | medium | Two names per destination (see answer above): tab "Heute"/"Team"/"Arbeitstag", sidebar and headers "Mein Tag"/"Dein Team"/"Mein Arbeitstag". A nurse who learns "Team" on her phone finds "Dein Team" on the office PC; "Mein Tag" and "Mein Arbeitstag" are hard to tell apart. | `shell.ts:20` `TAB_LABEL`; `nav.ts:45-55` `PAGE_LABEL`; `field-client.tsx:180`, `work-client.tsx:45` | §4 one word per concept; §5 one shell | One label set (above) in `PAGE_LABEL`; `tabLabel` returns `item.label`. Unit: for every tab key the tab text equals the sidebar text. Playwright: at 390 px and 1440 px the nurse's first three menu names are identical. | report only (medium); PR comment #799 |
| UXR-77 | `/field`, `/team`, `/work` headers (team member, phone); built on #799 | low | The header links "Dein Team" (`/field`) and "Mein Tag" and "Kennzahlen" (`/team`) now repeat shell items a thumb away; two ways to the same place in one viewport add reading load in the header that also carries the day and the signals' context. ADR-131 deviation 2 leaves them for the port. "Vorschläge" is not a shell item and stays; the `/work` link "Mein Tag" opens that day's `/field?datum=…`, so it is day navigation and stays. | `field-client.tsx:180-182`; `team-client.tsx:125-130` (PR #799 head) | §2 one way to act; §5 density | In the UX2-3 port, drop header links whose target is a tab or a sidebar item; keep page-specific links ("Vorschläge", day navigation). Playwright 390 px: no header link `href` equals a tab `href`. | report only (low) |
| UXR-78 | Shell at 390 px, every protected page (keyboard and switch users, screen-reader users with a phone keyboard); built on #799 | medium | The tab bar is `fixed` at the bottom (`z-40`, 57 px). When focus moves by Tab to a control further down, the browser scrolls it just into the viewport, i.e. under the bar; a 44 px button can then be hidden entirely. The bottom padding of the content column helps only at the end of the page. Same for jump links that land a section at the bottom; at the top, the `sticky` headers of `/field` and `/work` can cover a control reached by Shift+Tab. | `AppShell.tsx:111` (`fixed inset-x-0 bottom-0 z-40`), `:186` (padding only); `field-client.tsx:177`, `work-client.tsx:42` (`sticky top-0`); no `scroll-padding` in `globals.css` | §6 accessibility floor; WCAG 2.2 2.4.11 Focus Not Obscured (Minimum, AA) | Below 768 px, `html { scroll-padding-bottom: calc(3.5rem + env(safe-area-inset-bottom) + 8px) }` (one rule beside the shell), and on `/field` and `/work` a matching `scroll-padding-top` for the sticky header. Playwright 390 × 844 on `/team` (long page), nurse: press Tab until a control below the first viewport is focused; its bounding box bottom ≤ the `tab-bar` top. | report only (medium); PR comment #799 |
| UXR-79 | Record page `/visits/[visitId]` and `/team/vorschlaege` (team member, phone); on #800 | low | Residual of UXR-53 / UX2-29: the record page now labels the field "Verantwortlich", but the AI lines on the same page and on the confirm screen still say "Zuständig" (`fieldLabel("responsible_user_id")`), so one page shows both words for one value. This also withdraws my 31.10. proposal "Zuständige Person wählen": it should read **"Verantwortliche Person wählen"**. Signal and exception texts ("Einsatz ohne Zuständige", "Zuständige Person abwesend gemeldet") are `cra`-fixed safety wording; whether they align is `cra`'s (UNKNOWN), I propose no change to them. | `features/ai/labels.ts:10`; `visits/[visitId]/page.tsx` (PR #800 head) `RESPONSIBLE_LABEL`; `signals/rules.ts:8`, `operations/exceptions.ts:77` | §4 one word per concept | `fieldLabel("responsible_user_id")` returns `RESPONSIBLE_LABEL`; picker placeholder "Verantwortliche Person wählen" (one constant). Unit (extend `ux2-wording.test.ts`): `fieldLabel("responsible_user_id") === RESPONSIBLE_LABEL`. | report only (low); PR comment #800 |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-27 | Met on PR head #803 (UX2-15); closes on merge. | `dd32be6`, `team-client.tsx` `OutsideDeliveryStatus`; `ux1-team.spec.ts` (CI success on head) |
| UXR-28 | Met on PR head #803 (UX2-16); closes on merge. | `dd32be6`, `team/rules.ts` `visitAlertFrame`; `ux2-team.test.ts` |
| UXR-46 | Met on PR head #803 (UX2-25); closes on merge. | `dd32be6`, `case-ref` `text-sm`; `contract-end-section.tsx` |
| UXR-48 | Met on PR head #800 (UX2-27); closes on merge. | `1640cdc`, `authorship.ts`, `handover/rules.ts` `entryAuthorLabel` |
| UXR-53 | Met on PR head #800 for `/visits` and the record field; residual UXR-79. | `1640cdc`, `visits/types.ts` |
| UXR-72 | Met on PR head #799 (record page inside the shell); closes on merge. | `260dbf6`, `(protected)/layout.tsx` |
| #510 (two shells, UXR S1) | Met on PR head #799 for navigation; page tokens remain UX2-3. Issue stays open until merge and PO acceptance. | `260dbf6` |
| UXR-73, -74, -65 | OPEN, unchanged. | no change on `recovery/main` since `3a6b9c6` |
| UXR-68 | PLANNED (PLAN3-12), unchanged. | — |
| UXR-57, -58, -61 to -64 | PLANNED (UX2-30), unchanged. | — |

### Benchmark (2026-11-03): a bottom navigation bar

Read: SAP Fiori for Android, *Navigation Bar* usage (Material 3 standard component), https://www.sap.com/design-system/fiori-design-android/v25-8/components/m3-standard-components/navigation-bar/usage, 2026-11-03. An enterprise field app uses a bottom bar for two to five core destinations; with only one destination, it uses a drawer instead; labels stay short and never wrap, truncate or shrink; the selected item is shown by a highlight plus a changed icon; on larger screens the bar is replaced by a rail or drawer with the same destinations.

What NAVORA should adopt: (1) a role's bar carries its **core** destinations, and a bar with one real destination plus "Mehr" is a sign the set is wrong for that role (UXR-75); (2) short labels that fit one line at 390 px in four columns, the same words in the sidebar (UXR-76: "Arbeitstag" fits, "Mein Arbeitstag" would wrap); (3) already built: the current item marked by more than colour, and sidebar on desktop with the same items. Not adopted: icons for now (no icon set in §7; a text label alone meets the need and avoids icon-only meaning). No design, logo or text copied.

**For the PO.** (1) UXR-75: should a coordination role's home be its first tab (ADR-131 deviation 3)? Yours; I recommend yes. (2) Tab wording answered above (deviation 1), for #799 or the UX2-3 PR. (3) UXR-78 is a one-rule fix and could ride #799 before merge. (4) UXR-77, -79 (low) can ride UX2-3 / #800. (5) No `severe` or `high` finding, so no issue opened; one comment each on #799 and #800. (6) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-31 03:50 CET · `uxa`: AIG1-C1/-C2/-C3 (#787) and RLS4-C2 (#792) as merged: UXR-66, -67, -69, -70, -71 closed; UXR-72 (low), UXR-73 (medium), UXR-74 (low); interim texts and AIG1-C4 (3) worded; benchmark count badges

**What changed since 30.10. 23:55.** My PR #785 merged. Screen code changed in two merges: **#787** (AIG1-C1, -C2, -C3) as `c6f038b` and **#792** (RLS4-C1, -C2) as `6fd9507`. CI on both merge commits and on `recovery/main` `3a6b9c6`: app, db, e2e, ui-screenshots all `success` (read from the GitHub check runs; I ran no test). The PO accepted AIG1-C1 to -C3 as met (02:25) and set AIG1-C4 and AIG1-C5; Engineering's two interim texts are mine to replace without a PO round (ADR-130 deviation 6). Open PRs (#753 … #797) are `cra`, `lca` and status docs; none changes `src/app` or `src/components`, so no PR comment. No `ux/…` PR was open.

**Sources.** `ui-screenshots` artifacts exist for `recovery/main` `3a6b9c6` (13026397715) and `6fd9507` (13026660686, 13026545938); the archive redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from code on `3a6b9c6`. Synthetic seed only; the live project was not touched.

### What the merged changes do well (IMPLEMENTED)
- Record page `/visits/[visitId]`: the back link returns to the list that opened it ("Zurück zur Liste", "Zurück zu den Vorschlägen"), otherwise the role's home; origin from the link, never from a person (`labels.ts` `recordBackLink`). The two actions sit directly under the provenance line, filled "Erneut bestätigen", outline "Ändern", one `role="status"` result, a refusal on its line (`lookback-actions.tsx`). A coordinator gets no control and no sentence about it.
- Look-back list: "Werte: <n> offen · <m> nicht mehr offen", second part also at 0; "Einsatz nicht mehr offen" as text in the same weight as "überholt am"; the header names only actions the product offers (`rueckblick/[stopId]/page.tsx`, `LOOKBACK_EXPLANATION`). Wording as proposed 23:55.
- `/team/vorschlaege`: box and line text in one `label`, `min-h-11`; a refused value keeps its reason on its own line; the result reads "2 Werte bestätigt, 1 nicht übernommen." and is an alert only when something was refused (`suggestions-client.tsx`).
- `/admin` (RLS4-C2): a member's open reports are read only when the access-end step opens; "Zugang beenden" waits until the list is there; a list that could not be read says so instead of "keine" (`admin-client.tsx` `MemberAccess`; `team/contract-end-section.tsx` `LeaverEntry`). Less personal data on the member list, and no false all-clear.

### Wording (OPEN until built; `cra` confirms substance, `lca` the no-person rule)

**Interim text 1, record page line of a listed value** (`labels.ts` `RECORD_LOOKBACK_TEXT`). Built: "Zuständig: Dieser Wert steht auf der Rückblick-Liste eines gestoppten Assistenten." "Rückblick-Liste" names a coordinator screen the nurse does not use, and the line repeats nothing she can act on. The provenance line right above already says who proposed and who confirmed. Proposed, adding only the new fact: **"<Feld>: Der Assistent, der diesen Wert vorgeschlagen hat, ist gestoppt."** No obligation word ("bitte prüfen", "muss"): who must re-check, and by when, is the Clinical Owner's (D-17, UNKNOWN). The buttons below are the next step. `cra` confirms.

**Interim text 2, picker placeholder** ("Person wählen", `suggestions-client.tsx:238`, `lookback-actions.tsx:142`). Proposed: **"Zuständige Person wählen"**, matching the field label "Zuständig" above it, one constant used by both forms (see UXR-74).

**AIG1-C4 (3), health list count** (PO 02:25: "Abgelaufen ohne Entscheid: <n>", `uxa` may replace). Proposed: **"<n> ohne Entscheid abgelaufen"**, in the same cell and form as the existing "<n> entschieden" line (number first, one pattern), shown also at 0 so a missing line never reads as "none". Per agent and window, never per person (AIG1-11). No colour above `info`. Unit: the text for 0 is "0 ohne Entscheid abgelaufen".

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-72 | `/visits/[visitId]` record page (team member, phone; coordinator, desktop); IMPLEMENTED in `c6f038b` | low | Residual of UXR-67: the dead end is gone (back link), but the page still renders a bare `main` without `AppFrame` or `HeaderMenu`, so it is the only protected page without the role's menu and looks different from every page that links to it. | `visits/[visitId]/page.tsx:33-58` (no `AppFrame`/`HeaderMenu`) | §5 one shell | The page renders inside the shell the role sees on its home (one shell is UX2 / #510). Playwright at 390 px and 1440 px: the role's menu is present on the record page. | report only (low); belongs with #510 / UX2 |
| UXR-73 | `/admin` member row, "Zugang beenden" step (administrator, desktop); IMPLEMENTED in `6fd9507` | medium | When her open reports cannot be read, the step shows "Offene Berichte konnten nicht geladen werden." and "Zugang beenden" becomes available; the line names no next step (try again, or where else to look). The step exists so that no unsigned report is orphaned (LEAVE1-12 (1)); an administrator in a hurry can end access without having seen the list. While loading, the button is correctly held. | `admin-client.tsx:276-294` (`open === null` enables submit; alert without action) | §1 what next; §2 a refused or failed read says what to do | The failure line carries one action "Erneut laden" (re-runs `readMemberOpenReports`, `min-h-11`). Whether ending stays possible without the list is a product and care trade-off for the PO with `cra` (UNKNOWN; I do not propose blocking a leaver's access end, which can be urgent). vitest: with the read rejected, the alert and an "Erneut laden" button are shown and a second call is made on click. | report only (medium); for the PO |
| UXR-74 | change forms on `/team/vorschlaege` and on the record page (team member, phone) | low | The same "Ändern" step is built twice and behaves differently: on the list the confirm button is enabled and an empty pick triggers the browser's own validation bubble; on the record page the button stays disabled until a person is chosen, with no text why. Two behaviours for one command. | `suggestions-client.tsx:226-250` (`required`, form `action`); `lookback-actions.tsx:125-160` (`disabled={!chosen}`) | §2 one command, one result display; §7 one component each | One shared picker component used by both pages; the confirm button is enabled, and an empty pick shows one inline line "Bitte eine Person wählen." tied with `aria-describedby`. vitest: both pages render the same component; submit without a pick shows the line and sends nothing. | report only (low) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-66 | **Closed in code** (AIG1-C3 (2)). | `c6f038b`, `suggestions-client.tsx` `refusals`, `labels.ts` `bulkResultText`; `aig1.spec.ts` test 3 (CI success on `c6f038b`) |
| UXR-67 | **Closed in code** for the dead end (AIG1-C3 (1)); the missing shell continues as UXR-72. | `c6f038b`, `recordBackLink`; e2e per PO 02:25 |
| UXR-69 | **Closed in code** (AIG1-C3 (3)). | `suggestions-client.tsx` `suggestion-tick-label` `min-h-11`; `aig1.spec.ts:113` bounding box |
| UXR-70 | **Closed in code** (AIG1-C3 (4)). | `assistenten/page.tsx` flag in the "Mindestzahl" cell; `minReachedText(null)` |
| UXR-71 | **Closed**: second half in code ("Kein anderes Teammitglied wählbar."); first half not adopted by the PO (ADR-130 decision 13: a rejection leaves the visit unchanged). | `NO_OTHER_MEMBER_TEXT`; `briefs/AIG1.md` PO 02:25 |
| UXR-68 | PLANNED (PLAN3-12). Benchmark below adds one detail: cap the count ("99+"). | `briefs/PLAN3.md:32` |
| UXR-65 | OPEN (low), unchanged. | `rules.ts` on `3a6b9c6` |
| UXR-57, -58, -61 to -64 | PLANNED (UX2-30); unchanged. | no screen change outside AIG1 and RLS4 since `7388674` |

### Benchmark (2026-10-31): a count on a navigation entry

Read: ServiceTitan Anvil design system, *Badge* (web), https://anvil.servicetitan.com/docs/components/badge/web, 2026-10-31. A field-service product puts a number badge on an interactive entry (a nav item or icon button) to say how many items need attention; it caps the number (99, shown as "99+"); the accessible name carries the context ("with 6 unread"), not the number alone; the badge keeps one default colour; it is not used to label or organise content, and only ever holds a number.

What NAVORA should adopt (PLAN3-12, UXR-68): the count lives on the entry, not as a banner; one neutral colour (already: no colour above `info`, H-20); the `aria-label` says what is counted ("5 offene Vorschläge", already in PLAN3-12); **new: cap the visible number at "99+"** so the link stays one line at 390 px, with the `aria-label` keeping the exact number. What NAVORA should not adopt: a dot without a number (it says "something" but not how much, and invites opening to check). No design, logo or text copied.

**For the PO.** (1) UXR-73 (medium): whether "Zugang beenden" stays possible when the open-report list cannot be read is yours with `cra`; the "Erneut laden" action is presentation-only. (2) Interim texts and AIG1-C4 (3) worded above, for the PLAN3 / AIG1-C4 PR. (3) UXR-72, -74 (low) can ride with UX2. (4) No `severe` or `high` finding, so no issue opened. (5) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-30 23:55 CET · `uxa`: AIG1 part (b) UI as merged (#776): UXR-49 closed in code; UXR-66, -67, -68, -69 (medium), UXR-70, -71 (low); AIG1-C1 and AIG1-C2 wording proposed; minimum-flag sentence worded

**What changed since 15:50.** My PR #759 merged. Screen code changed in one merge: **#776** (AIG1 part (b) UI) as `fa77272` (head `3378b2a`; CI green on head and merge commit as the PO 21:25 reports from GitHub; I ran no test). New screens: `/team/vorschlaege` (confirm screen, team member, 390 px first), `/visits/[visitId]` (record page), `/operations/assistenten` (health list, desktop), `/operations/assistenten/rueckblick/[stopId]` (look-back list); links from the OPS1 card, the `/operations` header and the `/team` header. AIG1 **accepted** on synthetic data (PO 22:15) with conditions AIG1-C1 (as amended by AUT-29) and AIG1-C2 (CGR-105), both PLANNED, both asking `uxa` for wording. #781 (CGR-96) changes only `tests/e2e/vis1.spec.ts` (no screen). Other merges are docs only. Open PRs (#753 … #784) are `cra` and `lca` docs; none changes `src/app` or `src/components`, so no PR comment. No `ux/…` PR was open.

**Sources.** `ui-screenshots` artifacts exist for `recovery/main` at `7388674` (13017885512, 13017394031); the archive redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from code on `recovery/main` `7388674`. Synthetic seed only; the live project was not touched. No benchmark this run (one made today, 03:50).

### What the AIG1 screens do well (IMPLEMENTED)
- `/team/vorschlaege`: one line per value; one filled primary per line ("Bestätigen"), "Ändern" and "Ablehnen" outline; "nicht gefunden" offered only as "Als „nicht gefunden“ bestätigen"; ticks only on bulk-eligible values, all unticked, no "alle", the button names its count; every button `min-h-11` (`suggestions-client.tsx:10, 151-197`). Plain words, no internal code on screen.
- Look-back list: no person, no "bestätigt von", no tick, the line is the one action, "überholt am <Datum>" as text (`rueckblick/[stopId]/page.tsx:131-153`). This is the UXR-49 presentation; closed below.
- Health list: threshold, minimum and window shown, no person column (`assistenten/page.tsx:35-80`).

### Wording asked of `uxa` (all OPEN until built; `cra` confirms wording, `lca` the no-person rule and the counts per stop and team)

**AIG1-C1 (2), line of a visit no longer open.** The product's word for a visit is "Einsatz" everywhere the nurse and coordinator read it (the look-back line title "<Fall> · Einsatz <Datum>", `refusalText` "Der Einsatz ist nicht mehr offen", `/field`, `/team`). Using "Besuch" on this one line would make two words for one thing. Proposed:
- Status line on the look-back line, under the title that already carries the date: **"Einsatz nicht mehr offen"**; where the date is not on the line (the OPS1 detail): "Einsatz vom <Datum> nicht mehr offen". Same weight and position as "überholt am <Datum>" (`text-xs font-semibold`, no colour above `info`, no icon only), no confirm or change control, the line still opens its record.
- Counts, on the look-back page and in the OPS1 detail: **"Werte: <n> offen · <m> nicht mehr offen"**, the second part always shown, also at 0 (`lca` proviso (a): the count always stands beside "offen"). Singular and plural need no change ("1 offen"). With every open-visit line handled: "Werte: 0 offen · <m> nicht mehr offen" (AIG1-C1 (4)). Never a person, never a deadline word.

**AIG1-C2 (a), actions on the record page (team member of the record, visit still open).** "Erneut bestätigen" (filled primary) and "Ändern" (outline) **confirmed** as the labels. Place: directly under the provenance line "vorgeschlagen von … / bestätigt von … am …" (the act follows what it attests, §2). "Ändern" opens the same person picker as `/team/vorschlaege` with "Geänderten Wert bestätigen" and "Abbrechen" (one command, one result display, §2). After success: one `role="status"` line "Erneut bestätigt. Der Wert ist nicht mehr auf der Liste." (or "Geändert und bestätigt. …"); a refusal shows the existing `refusalText` on the record, and the line stays listed. Coordinators (C2 (d)) see the record with neither control and no sentence about them.

**AIG1-C2 (c), the look-back page text.** The built header says "Ein Wert verlässt die Liste, sobald er im Einsatz erneut bestätigt oder geändert wird" (`rueckblick/[stopId]/page.tsx:119-120`), an action no screen offers today. Proposed, keeping the substance of the D-17 sentence:
- Until C2 (a) merges: "Werte des gestoppten Assistenten, die im Stoppfenster unverändert bestätigt wurden. Ob, von wem und bis wann sie nachgeprüft werden müssen, ist noch nicht festgelegt. Jede Zeile öffnet ihren Einsatz; bestätigen oder ändern lässt sich ein Wert dort noch nicht."
- Once C2 (a) is merged (same PR is fine): the last sentence becomes "Ein Wert verlässt die Liste, sobald jemand aus dem Team des Einsatzes ihn dort erneut bestätigt oder ändert." This also tells a coordinator whose step it is, without a person name.
- "(klinische Verantwortung)" is dropped: it names a governance role, not a step the reader can take; the substance (not yet decided) stays. `cra` confirms.

**AIG1-16 (2), minimum flag before the first closed window** (PO 20:25 asked `uxa`). Built: "Mindestzahl im letzten Fenster erreicht: noch kein abgeschlossenes Fenster" (`labels.ts:107`) answers a yes/no label with a non-answer. Proposed for `null`: **"Noch kein Fenster abgeschlossen"**; "… erreicht: ja" and "… erreicht: nein" stay as built (the e2e asserts "ja"). Unit test `aig1-labels.test.ts:83` changes with it.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-66 | `/team/vorschlaege`, bulk confirm (team member, phone); IMPLEMENTED in `fa77272` | medium | When the server refuses some ticked values, the result is "<n> Werte bestätigt." plus one alert with all refusal texts joined, none naming its line; the ticks are cleared and the refused lines sit among the unticked ones. She cannot tell which value was not taken over or why, so the reason (absent, not qualified) cannot be acted on; she may assume all were taken. | `suggestions-client.tsx:58-61`; `features/ai/commands.ts:84-86` (refused mapped to texts only) | §2 a refused line stays in the list with its reason (OPEN rule since 27.10.); §2 one command, one result display; §1 next action | Result line names both counts: "2 Werte bestätigt, 1 nicht übernommen."; each refused line shows its `refusalText` on that line (`role="alert"` once, on the summary). Needs the refused entries to carry their suggestion id (if `confirm_suggestions` returns it; else UNKNOWN, `eng`). vitest: with one refused id the alert sits inside that line's `article` and the summary contains "1 nicht übernommen". | report only (medium); for the PO's AIG1-C2 or UX2 list |
| UXR-67 | `/visits/[visitId]` record page (coordinator from the look-back list; team member from a proposal); IMPLEMENTED in `fa77272` | medium | The page has no app shell and no menu, and its only link is "Dein Team" (`/team`) for everyone. A coordinator who opened a look-back line is sent to a page that reads nothing for non-members, with no way back to the list she was working; a nurse from `/team/vorschlaege` is not returned there either. Dead end in the one workflow AIG1-12 defines. | `visits/[visitId]/page.tsx:20-23` (no `AppFrame`/`HeaderMenu`, fixed `href="/team"`) | §5 one shell; §1 what next; §2 an item that asks for an action elsewhere carries the way there | Back link returns to where she came from: from the look-back list "Zurück zur Liste" → `/operations/assistenten/rueckblick/<stopId>`, from proposals "Zurück zu den Vorschlägen"; otherwise the role's home; the role's `HeaderMenu` is present. e2e (desktop, coordinator): look-back line → record → the back link's `href` is the stop's list. e2e (390 px, team member): proposal → "Einsatz öffnen" → back link `href="/team/vorschlaege"`. | report only (medium); suggest riding with AIG1-C2 (same page) |
| UXR-68 | `/team` header link "Vorschläge" (team member); IMPLEMENTED in `fa77272` | medium | The entry to the confirm screen is a plain header link with no count, among the menu links; nothing on `/team` or `/field` says that values wait for a decision. Question 1 of §1 (what needs attention now) is not answered; PLAN3 will put day-plan proposals here. | `team-client.tsx:132-135` | §1 three questions; §2 one primary per section | When ≥ 1 open proposal exists for her teams the link reads "Vorschläge (<n>)" (count only, no client name, `aria-label` "<n> offene Vorschläge"); at 0 plain "Vorschläge". Whether `/field` carries it too is the PO's (UX2 or PLAN3). No colour above `info`, so a count does not push her to confirm in bulk (H-20; `cra` may comment). e2e (390 px, seed with 5 open): the link text contains "(5)". | report only (medium) |
| UXR-69 | `/team/vorschlaege`, tick box (team member, phone) | medium | The tick box is a bare 24 × 24 px input beside the text; the line text is not its label, so the tap target is 24 px. On a phone a near-miss ticks nothing or the neighbour; the tick decides which values are confirmed unchanged with her name. | `suggestions-client.tsx:151-159` (`h-6 w-6`, no wrapping `label`) | §6 44 px targets; WCAG 2.5.8 | Wrap box and line text in one `label` (or give the box a ≥ 44 × 44 px hit area), keeping one tick per line and no "alle". Playwright at 390 px: the tick's bounding box (or its label's) is ≥ 44 px high; tapping the line text toggles only that box. | report only (medium) |
| UXR-70 | `/operations/assistenten` health list (coordinator, desktop) | low | The "Mindestzahl … erreicht" flag sits in the "Korrekturanteil" column, not under "Mindestzahl"; the null text answers a yes/no label with a non-answer (wording above). | `assistenten/page.tsx:56-64`; `labels.ts:106-108` | §5 information where it is read; §4 plain words | Flag rendered in the "Mindestzahl" cell (keep `data-testid="agent-min-reached"`); null text "Noch kein Fenster abgeschlossen". Unit: `minReachedText(null)` equals it. | report only (low) |
| UXR-71 | `/team/vorschlaege`, line actions (team member, phone) | low | "Ablehnen" writes a decision with her name in one tap, right beside "Bestätigen", with no step and no undo; "Ändern" is disabled without saying why when no other member exists. | `suggestions-client.tsx:187-192` | §2 consequential acts name the consequence; §2 an action not available says why | Either a confirming step naming the consequence for the care (sentence from facts `eng`/`cra` give: UNKNOWN what a rejected value leaves on the visit) or a short "Rückgängig" while the line is still shown; for disabled "Ändern" a line "Kein anderes Teammitglied wählbar." Trade-off (friction vs. safety) is the PO's. | report only (low) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-49 | **Closed in code** (AIG1-14): no person, no "bestätigt von", no tick, line opens its record, "überholt am". Counts on the list are a PO decision (AUT-29), recorded as a deviation in §2. | #776 merged `fa77272`, `rueckblick/[stopId]/page.tsx`; `aig1.spec.ts` test 4 (CI per PO 21:25) |
| UXR-65 | OPEN (low), unchanged. | `rules.ts` on `7388674` |
| UXR-57, -58, -61 to -64 | PLANNED (UX2-30); unchanged. | no screen change outside AIG1 since `4adeab4` |

**For the PO.** (1) AIG1-C1 and AIG1-C2 wordings above, ready for the one Engineering PR; UXR-67 sits on the same record page and could ride with it. (2) UXR-66, -68, -69 (medium) wait for placement (AIG1-C2 PR or UX2); UXR-66 needs `eng` to say whether `confirm_suggestions` returns the refused ids. (3) No `severe` or `high` finding, so no issue opened. (4) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-30 15:50 CET · `uxa`: #747 merged (ASM1-C1 to -C5 with C4 (d)): UXR-60 closed in code, UXR-54, -55, -56, -59 closed; UXR-65 (low); C4 (d) label confirmed; C6 (8) sentences worded; P-37 confirmed from the UX side

**What changed since 11:55.** My PR #749 merged. **#747** merged as `752ecbc` (`eng` 15:25 reports CI green on head `6339c24`: app, db, e2e, ui-screenshots; I did not run any test). Against the head I read at 11:55 (`5d3a887`), the screen code changed in one commit, `fcb84eb` (ASM1-C4 (d), PO 12:14 from UXR-60): `plan-assessment-basis.tsx`, `plan-review-button.tsx`, `rules.ts`. Everything else of C1 to C5 is the code I read at 11:55. Docs-only merges otherwise (#750 to #757: `po`, `lca`, `aia`). No other open PR changes `src/app` or `src/components`; no `ux/…` PR was open.

**Sources.** `ui-screenshots` artifacts exist for `recovery/main` at `4adeab4` (12987045925, 12986377265). The archive redirects to a blob host the proxy refuses to this role, so **no screenshots were available**. Reviewed from code on `recovery/main` `4adeab4`. Synthetic seed only; the live project was not touched.

### ASM1-C4 (d) as merged (`/team` care-plan block, registered nurse of the team)

Met as I read it (IMPLEMENTED):
- **(1) Order.** Basis line, marker "Neuere Bedarfsabklärung vom …" and the C5 sentence stay first; `{reviewAction}` is now the last child, after the category rows and the newer-event lines (`plan-assessment-basis.tsx`, comment ASM1-C4 (d)). Nothing safety-relevant moved down.
- **(2) Label.** "Als geprüft bestätigen: Pflegeplan gegen Bedarfsabklärung vom <Datum>" (`rules.ts` `reviewLabel`). **Confirmed as built; no refinement.** The recorded line keeps the participle.
- **(3) Confirming step.** The UX2-23 `ConfirmStep`: opens in place, focus to the sentence, "Als geprüft bestätigen" (primary) first, "Abbrechen" second, both 44 px; "Abbrechen" runs nothing (`plan-review-button.tsx`). `cra` 13:30 keeps the step.
- **(4) Tests in the merge** (CI per `eng`, not run by me): unit `reviewLabel` starts "Als geprüft bestätigen:" with the date; component DOM order with `plan-review-command` last (`tests/unit/asm1-conditions.test.ts:135-171`); e2e: command top below `plan-category-C`, step shows the date, confirming clears the command (`tests/e2e/asm1.spec.ts:155-173`).

Where it falls short: UXR-65 (low). The step's sentence says "Danach verschwinden für das Team die Hinweise «Neuere Bedarfsabklärung» und «… korrigiert»." in every case (`rules.ts` `reviewConfirmSentence`). It names both notes even when only one shows, never names the third case that offers the act ("Geschrieben vor jeder erfassten Bedarfsabklärung"), and «… korrigiert» is a placeholder she cannot match to a line on screen. The PO wrote this meaning in C4 (d) (3); the remedy keeps the meaning and names what is shown.

### ASM1-C6 (8) sentences (asked of `uxa`, PO 15:00; PLANNED in the brief, not built; OPEN wording; `cra` confirms wording and position, and the no-current-record case)

Both sit where the marker sits today, at `info`, first in the block, outside the folded history (C4 (d) (1)). They replace the "Neuere Bedarfsabklärung" marker whenever the reason is not a later date, so the word "Neuere" never shows for a same-date record.
- **Basis not current, not voided** (a newer record of the same date, a parallel record, or any other non-current basis head): "Der Pflegeplan ist gegen eine Bedarfsabklärung geschrieben, die nicht mehr die aktuelle ist. Aktuell ist die Bedarfsabklärung vom <Datum>." When the case has no current record left: second sentence "Es gibt keine aktuelle Bedarfsabklärung."
- **Basis voided:** "Die Bedarfsabklärung, gegen die der Pflegeplan geschrieben ist, wurde als irrtümlich erfasst markiert." followed by the same second sentence ("Aktuell ist die Bedarfsabklärung vom <Datum>." or "Es gibt keine aktuelle Bedarfsabklärung."). No date, minutes, period, instrument or reference of the voided record (C6 (3), (7)); the date of the current record is not a field of the voided one.
- **Basis line (C6 (8) (iii)).** For a voided basis, the line "Geschrieben gegen die Bedarfsabklärung vom …" is not shown; the sentence above carries the fact.
- **The act in these cases.** With a current record, the C4 label and step stay as built, the step naming the note shown (UXR-65). **UNKNOWN:** what the act attests and how it is labelled when **no** record is current (`reviewLabel` needs a date). Whether a plan can be "reviewed against" nothing is `cra`'s, after G-1 the Clinical Owner's. I do not propose a label for it.
- **Tests.** Component: for each case the one sentence renders before `plan-assessment-line` and the text "Neuere" is absent for a same-date parallel record; for a voided basis no `Kategorie`/`Referenz` text and no voided-record date appear in the block.

### P-37, preset void reason (asked of `uxa`, PO 13:28 and 15:00): **confirmed from the UX side**, with these presentation conditions

The preset fits the commonest case and saves typing on a phone; it keeps the `lca` details (a)-(d).
- One `fieldset` with visible legend "Grund", two radio rows (≥ 44 px each): "Falsche Klientin oder falscher Klient gewählt" and "Anderer Grund". **Neither preselected** (`lca` (a)).
- The free-text field and the adopted C6 (4) hint appear only after "Anderer Grund"; the hint stays tied by `aria-describedby`.
- The submit ("Irrtümlich erfasst markieren", `action-outline`) stays disabled until a choice is made and, for "Anderer Grund", the text meets the minimum; then the C6 confirming step follows unchanged.
- The team line reads "Irrtümlich erfasst am <Datum> von <Name>. Grund: Falsche Klientin oder falscher Klient gewählt" with the text as shown (`lca` (b)).
- Tests add: vitest "the free-text field is absent until «Anderer Grund» is chosen" and "submit disabled with no choice".
This is the second confirmation the 13:28 rule asks for (with `lca`); whether it comes into force is the PO's call. `cra` (H-05 traceability) is still asked.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-65 | `/team` care-plan block, review confirming step (registered nurse of the team); IMPLEMENTED in `752ecbc` | low | The step's sentence always names two notes, «Neuere Bedarfsabklärung» and «… korrigiert», whichever shows, never the "Geschrieben vor jeder erfassten Bedarfsabklärung" case that also offers the act, and quotes a placeholder («…») she cannot find on screen. A confirming sentence that does not match the screen weakens the one check the step adds. | `rules.ts` `reviewConfirmSentence` on `4adeab4`; `rules.ts:198-201` (`reviewOffered`, three cases) | §2 confirming step names the consequence; §4 plain words, no placeholders | Keep the meaning of C4 (d) (3); `reviewConfirmSentence(view, current)` names only the notes shown, quoted from their visible start: «Neuere Bedarfsabklärung vom <D>», «Die Bedarfsabklärung vom <D> … wurde am <D2> korrigiert» (as "der Hinweis zur Korrektur vom <D2>"), «Geschrieben vor jeder erfassten Bedarfsabklärung». Unit: for each of the three cases the sentence contains that note's text and none of the others; no "…" in it. `cra` confirms the wording. | report only (low); for the PO's UX2-30 list |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-60 | **Closed in code** (ASM1-C4 (d)): order, label and confirming step as remedied; tests in the merge. #748 can be closed by the PO. | #747 merged `752ecbc` (`fcb84eb`), `plan-assessment-basis.tsx`, `plan-review-button.tsx`, `asm1-conditions.test.ts:135-171`, `asm1.spec.ts:155-173` |
| UXR-54 | **Closed in code** (ASM1-C3); hint wording follow-up UXR-61 stays. | #747 merged `752ecbc`, `rules.ts` |
| UXR-55 | **Closed in code** (ASM1-C2). | #747 merged `752ecbc`, `assessment-section.tsx` |
| UXR-56 | **Closed in code** for the Bedarfsabklärung form (other forms UX2-30). | #747 merged `752ecbc`, `sm:grid-cols-2` |
| UXR-59 | **Closed in code** (ASM1-C1); landing test is UXR-64. | #747 merged `752ecbc`, `field-client.tsx` |
| UXR-57 | Half met (the "Ersetzt:" line); prefill of instrument and assessor PLANNED (UX2-30). | `assessment-section.tsx` on `4adeab4` |
| UXR-58, -61 to -64 | PLANNED (UX2-30, PO 12:14); unchanged in the merge. | `git diff 5d3a887 752ecbc^2` touches only C4 (d) files |
| UXR-65 | **New**, OPEN (above). | |

No benchmark this run (made at 03:50 today).

---

## 2026-10-30 11:55 CET · `uxa`: ASM1-C1 to -C5 read (open PR #747, `/field`, `/team`): UXR-60 (high, #748), UXR-61 to -64 (low); UXR-43, -45 closed in code (#742); C5 sentence confirmed; C6 display wording proposed

**What changed since 07:50.** My PR #730 (07:50 section) merged. **#727** (ASM1) merged as `e42fde6`; `git diff ad98160 c191213 -- src` is empty, so the screen code is the code I read at 07:50. **#742** (UX2-22, UX2-23) merged as `ea94bba` (CI green on head `a15cffa`, as GitHub and `eng` 10:48 report it): `/field` (qualification note, field actions, "Offen im Team"), `/admin` (`confirm-step.tsx`, admission switch, "Vertragsende entfernen"). Open PR **#747** (`eng`, ASM1-C1 to -C5, ADR-125, migration 0101, head `5d3a887`) changes `/field` (`field-client.tsx`, `page.tsx`), `/team` (`assessment-section.tsx`, `plan-assessment-basis.tsx`, new `plan-review-button.tsx`, `team-client.tsx`) and `features/assessment/rules.ts`. CI on its first head `9ddcf5b` was **red** (`app` and `db` jobs failed; `e2e` and `ui-screenshots` green, run 41041230871); no run is reported yet for `5d3a887`. Other merges since 07:50 (#733 to #746) change no screen. Briefs: `ASM1.md` asks `uxa` for the C5 sentence, the C6 display and where the C4 act sits; `UX2.md` gained UX2-30 (UXR-56 to -58). New `ux` issues: none other than mine.

**Sources.** `ui-screenshots` artifacts exist (12970323707 for `feat/asm1-c1-c5` at `9ddcf5b`; 12970301599 for `recovery/main` at `59d2538`). Their download needs a token this role does not have (proxy 403), so **no screenshots were available**. I reviewed from code on the #747 branch and `recovery/main` `59d2538`. Live project not touched. I ran no tests; CI states are as GitHub reports them. No benchmark: the last one was today at 03:50.

### UX2-22, UX2-23 as merged (#742, `/field`, `/admin`)

Built as worded at 2026-10-29 16:10: the `info` note sits once under the safety signals (`field-client.tsx` on `ea94bba`, `qualification-missing-note`), and the cards drop depart, start, resume and complete for her (`features/field/qualification.ts`). "Offen im Team" becomes one `info` line with no count, names or "Übernehmen". The confirming step opens in place, moves focus to the sentence (`tabIndex=-1`) and puts the action first, then "Abbrechen", both 44 px. Its buttons are not at the first button's position, so a double tap does not pass it. The off-sentence is a single sentence (ADR-124 deviation 1, PO 11:10: no lapse pause). UXR-43 and UXR-45 are **closed in code** (below). They are accepted with UX2 as a whole. Residual, already PLANNED: `/admin` buttons outside the step stay 40 px (UX2), and the error line there stays rose (UX2-14).

### ASM1-C1 to -C5 on #747 (open PR; read on branch `5d3a887`)

Met as I read it:
- **C1.** One neutral line "Zu bestätigen: Bedarfsabklärung (<n>)" (stone border, `data-tone="info"`, 44 px) in her "Zu erledigen" row, only when n ≥ 1, from her own reader output.
- **C2.** The current record stays open with its state and its "Ersetzt …" line. "Frühere Erfassungen (<n>)" is a closed `details` (44 px summary). The minutes with their period appear once per card, in the care-plan block.
- **C3.** Both refusal texts word for word as the PO fixed them. The reference hint is visible before saving (`aria-describedby`).
- **UXR-56.** The form is one column below 640 px (`sm:grid-cols-2`).
- **UXR-57.** Half met: a line "Ersetzt: <record>" now heads the replace form. Instrument and assessor are still not prefilled (`defaultValue=""`, `assessment-section.tsx:237, 249`).
- **C5.** The sentence sits outside the history, in `info`.

Where it does not meet the design system: below.

**C5 sentence (asked of `uxa`).** "Die Bedarfsabklärung vom <Datum>, gegen die der Pflegeplan geschrieben ist, wurde am <Datum> korrigiert." **Confirmed as built**: it states the fact, names both dates and judges nothing. Its way forward is the C4 act, which the block offers right after it today and at the end of the block once UXR-60 is applied.

**C4, where the act sits (asked of `uxa`).** See UXR-60: at the end of the care-plan basis block, after the material it attests. It is labelled as an action, and the recorded line keeps the participle.

**C6 display (asked of `uxa`; PLANNED in the brief, not built; OPEN wording, `cra` confirms wording and what the team sees, `lca` confirms the hint and that nothing beyond (3) shows).**
- **Command.** "Irrtümlich erfasst" as a text button (`action-outline`, 44 px) beside "Korrigieren (ersetzen)" on a non-voided record. It opens an in-place form: label "Grund"; hint under the field, tied with `aria-describedby`: "Beschreibe nur, was falsch erfasst wurde, z. B. falsche Klientin gewählt. Nenne keine andere Person." (the `lca` (b) hint; a hint, not enforced). Buttons: primary "Als irrtümlich erfasst markieren", secondary "Abbrechen".
- **Confirming step.** Primary first, focus to the sentence, the UX2-23 component. Sentence: "Danach gilt diese Bedarfsabklärung nicht mehr. Der Eintrag bleibt gespeichert; das Team sieht nur noch, dass er irrtümlich erfasst wurde." The void ends the record's role as a basis, so it takes the step.
- **What the team then sees** (inside "Frühere Erfassungen (<n>)", counted there): "Irrtümlich erfasst am <Datum> von <Name>. Grund: <Grund>". No minutes, period, instrument or reference (`lca` (a)). The word carries the state, not a line-through. Struck text is harder to read, and the brief's "shown struck" is met by the label. `cra` decides if the strike is required.
- **The named assessor** sees the same line on that record. Her C1 line drops it.
- **Tests.** Component: the voided record renders the line and no `Kategorie`/`Referenz` text. e2e: void → the record is in the history with the line, and the current record falls back.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-60 | `/team` case card, care-plan block (registered nurse of the team); IMPLEMENTED in open #747 | high | The review act is offered **above** the material it attests: basis line, marker, C5 sentence, **button**, then the assessment line and the minutes per category beside the items. Its label "Pflegeplan gegen Bedarfsabklärung vom <Datum> geprüft" is a participle that reads like a status line, in an outline box. One tap records an append-only act and clears both the marker and the C5 fact (CGR-102, S2), with no undo and no step. On a phone the nurse can attest before she has seen the comparison, or tap it by mistake, and the only visible sign of a corrected basis is gone. | #747 `plan-assessment-basis.tsx` (order: `marker`, `corrected`, `{reviewAction}`, then `plan-assessment-line`, `categoryRows`); `plan-review-button.tsx:36-44`; `rules.ts` `reviewLabel` | §1 what action next; §2 an attesting act follows what it attests (new, OPEN); §4 one command, one label | The marker and the C5 sentence stay first, unchanged (no safety-relevant fact moves down). Button and hint move to the end of the block. Label: "Als geprüft bestätigen: Pflegeplan gegen Bedarfsabklärung vom <Datum>". Whether it also takes the UX2-23 confirming step: `cra`/PO. Vitest: DOM order `plan-category-*`, `plan-newer-event` before the button; `reviewLabel` starts "Als geprüft bestätigen:". e2e 390: the button's top is below the last category row. `cra` confirms order and label. | #748 |
| UXR-61 | Bedarfsabklärung form, reference field; IMPLEMENTED in open #747 | low | The hint under the field is the refusal text word for word: a rule list with the characters "_ : # -" and no example. After a refused save she reads the same long sentence twice, once grey and once in the error box. The example sits only in the placeholder, which disappears as she types. | #747 `rules.ts` `REFERENCE_HINT` = `ASSESSMENT_REASONS.reference_invalid` minus "Die Referenz ist eine"; `assessment-section.tsx` hint `<p>` | §4 a hint says the rule short, the refusal says what to change | Hint: "Kennung aus eurem Abklärungsinstrument, z. B. BA-2026-0042: mindestens eine Ziffer, ohne Leerzeichen, Punkt oder Schrägstrich." Refusal `reference_invalid`: "Diese Referenz ist keine Kennung: 3 bis 64 Zeichen, nur Buchstaben, Ziffern und _ : # -, mindestens eine Ziffer." Unit: hint ≠ refusal text, and the hint contains "z. B.". No `cra`/`lca` question. | report |
| UXR-62 | Care-plan block, recorded review line; IMPLEMENTED in open #747 | low | "Pflegeplan geprüft gegen die Bedarfsabklärung vom <D1> am <D2> von <Name> (Bedarfsabklärung damals nicht bestätigt)" is one line with two dates side by side ("vom … am …"), no full stop, and the `cra` (a) state in parentheses, where it reads as an aside. | #747 `rules.ts` `planReviewText` | §4 plain German; §5 density | "Geprüft am <D2> von <Name> gegen die Bedarfsabklärung vom <D1>." and, as its own sentence when the state at the act was not "bestätigt": "Diese war damals <Status>." Unit on both forms. `cra` confirms (its condition (a)). | report |
| UXR-63 | Bedarfsabklärung block, no current record; IMPLEMENTED in open #747 | low | When no record is current (all superseded, and after a C6 void), the only open content is "Keine aktuelle Bedarfsabklärung.", rendered **below** the closed history, so the one fact she needs comes last. The C4 error line is a third copy of the rose box (UXR-58). | #747 `assessment-section.tsx` (`current === null` line after `</details>`); `plan-review-button.tsx:44-46` | §1 what needs attention now first; §3 one error component (UX2-14) | Render the line directly under the block heading when `current` is null. The UX2-14/UX2-30 guard includes `plan-review-button.tsx`. Component: with only superseded records, the line precedes `assessment-history-details`. | report |
| UXR-64 | `/field` "Zu bestätigen" link → `/team` (RN named as assessor); IMPLEMENTED in open #747 | low | The link jumps to `/team#bedarfsabklaerung-<id>`. Whether she lands on the record when it sits in a case card further down, or in a team other than the one `/team` shows first, is not tested. The brief's tests cover the line, not the landing. UNKNOWN whether `/team` renders every team of hers on one page. | #747 `field-client.tsx` (link), `assessment-section.tsx` `useEffect` (opens the history for a hash target) | §5 jump links land where she acts | e2e (synthetic seed): tap the line → the record with id `bedarfsabklaerung-<id>` is in the viewport and its confirm button is visible. If `/team` shows one team at a time, the link carries the team (`eng`). | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-43 | **Closed in code** (UX2-23): confirming step for the admission switch and "Vertragsende entfernen", wording as proposed 2026-10-29 16:10, the off-sentence single per ADR-124 dev. 1 (PO 11:10). Accepted with UX2. | #742 merged `ea94bba`, `admin/confirm-step.tsx`, `features/admin/confirm-texts.ts` |
| UXR-45 | **Closed in code** (UX2-22): `info` note once, refused actions hidden (`cra` 13:40), "Offen im Team" one line. Accepted with UX2. | #742 merged `ea94bba`, `features/field/qualification.ts`, `field-client.tsx` |
| UXR-54 | Met in open #747 (ASM1-C3), closes when merged; hint wording follow-up is UXR-61. | #747 `rules.ts` |
| UXR-55 | Met in open #747 (ASM1-C2), closes when merged. | #747 `assessment-section.tsx` |
| UXR-56 | Met in open #747 (UX2-30 carried), closes when merged. | #747 `sm:grid-cols-2` |
| UXR-57 | Half met in open #747 ("Ersetzt:" line); prefill of instrument and assessor still OPEN (UX2-30). | #747 `assessment-section.tsx:237, 249` |
| UXR-58 | PLANNED (UX2-30); now three rose copies (UXR-63). | |
| UXR-59 | Met in open #747 (ASM1-C1), closes when merged; landing test is UXR-64. | #747 `field-client.tsx` |
| UXR-60 to -64 | **New**, OPEN (above). | |
| Others | Unchanged since 07:50. | |

**Requests.** To `cra`: UXR-60 (order and label of the review act; whether it takes a confirming step), UXR-62 (state sentence), the C6 display above (wording, label instead of strike). To `lca`: the C6 reason hint and the team's view of a voided record (in-app only).

**For the PO.** (1) UXR-60 (high, #748): presentation-only, cheapest on #747 before merge; the PO decides whether it rides #747 or a follow-up. It does not ask to hold ASM1-C5's fact; it keeps that fact from being cleared before the comparison is visible. (2) The C5 sentence is confirmed as built. The C6 display wording is above. (3) UXR-61 to -64 (low) can ride #747 or UX2-30. (4) Screenshot download still refused (token); reviews remain code-only. I propose only.

---

## 2026-10-30 07:50 CET · `uxa`: ASM1 #727 read (open PR, `/team`): UXR-54, -55, -59 (medium), UXR-56, -57, -58 (low); VIS2-C2 mixed-case wording; VIS2-C3 save-step wording; RLS4 merged as read

**What changed since 03:50.** My PR #717 merged at 03:59 (`bd5263d`). Merged since with a screen change: only **#715** (RLS4, `visits-client.tsx`: "Pflegekraft:" from `getVisitResponsibleLabel`), which I read on its branch at 03:50; it merged as read (UXR-53 stands, placed as UX2-29). Other merges (#718, #719, #720, #722, #725, #726, #728, #729) change no screen. Open PR **#727** (`eng`, ASM1, migration 0100, ADR-123, head `ad98160`) changes `/team`: `team/assessment-section.tsx` (new), `team/plan-assessment-basis.tsx` (new), `team-client.tsx`, `team/page.tsx`, `features/assessment/rules.ts`; CI green on that head as GitHub reports (run 41012685080). Other open PRs (#723, #721, #711 and earlier `cra`/`eng` docs; #3 M2) change no screen. Briefs: VIS2 PO notes 04:10, 05:10, 06:10 ask `uxa` for the VIS2-C2 wording (starting from UXR-51) and for the VIS2-C3 save-step wording; UX2-28, UX2-29 placed from UXR-52, -53. New `ux` issues: none.

**Sources.** `ui-screenshots` artifact 12957583861 (#727 head `ad98160`) found; the download link points to the blob host, which this role's network refuses (`connect_rejected`), so **no screenshots were available**. Review from code on the #727 branch and `recovery/main` `199714f`. Live project not touched. I ran no tests; CI states are as GitHub reports them. No benchmark (one was made today at 03:50).

### ASM1 #727 on `/team` (open PR; read on branch)

Met as I read it: ASM1-11 shows no total, sum, colour, icon or "Abweichung" anywhere (`plan-assessment-basis.tsx:17-49`, one neutral class set); the marker "Neuere Bedarfsabklärung vom <Datum>" is plain text, `font-semibold`, no colour (`:19-23`); the confirm button appears only for the named nurse on an unconfirmed, non-superseded record and is the only filled button in a record (`assessment-section.tsx:143-152`); every control is `min-h-11` (44 px); the state "nicht bestätigt" is a word, not a colour; the form keeps its values after a refusal (`:174-180`); a third party's mark is labelled in words. Where it does not meet the design system: below.

### VIS2-C2 wording, mixed case (asked of `uxa`, PO 04:10 (2); PLANNED)

`cra` 05:30 confirmed the readable-plural and unreadable-single sentences and set the condition "no times while the count is 2 or more". Complete set:
- count 1, readable: VIS2-1 unchanged, word for word.
- count 1, unreadable: VIS2-2 unchanged.
- count ≥ 2, all readable: "Bei dieser Person sind <heute | am <Wochentag>, <Datum>> zu einer Zeit, die sich mit diesem Einsatz überschneidet, bereits <n> Einsätze geplant."
- count ≥ 2, any unreadable (the "unreadable clause" of the PO's vitest): the same sentence, then "Nicht alle davon kannst du einsehen." No number of unreadable visits (only `count` and the `unreadable` flag exist, as `lca` 04:47 read them), no team, no time.
Same text in the VIS2-5 after-save notice. `cra` confirms the added clause; `lca` confirms it says nothing beyond the `unreadable` flag. vitest: 2 readable → plural, no `hh:mm`; 1 readable + 1 unreadable → plural plus the clause, no `hh:mm`; 1 unreadable → VIS2-2.

### VIS2-C3 save step (asked of `uxa`, PO 05:10/06:10, "if one is added"; OPEN until `eng` chooses the mechanism on #65)

If the save meets an unreadable overlap the form has not shown: nothing is stored; the VIS2/VIS2-C2 sentence appears where the save button's row was, with "Noch nicht gespeichert." on the line below; focus moves to the sentence (`tabindex="-1"`, polite status). Below it two full-width buttons: primary = the form's own save label (one command, one label, §4), secondary "Zurück, nichts speichern". Going back keeps every entered value and shows "Nicht gespeichert." in `info`. No "trotzdem", no warning colour, no reason field (the fact is not a verdict, `cra` CGR-97). The step's primary button never sits where the save button was, so a double tap cannot pass the step. Tests (e2e 390 × 844, synthetic seed): the visit is absent from the plan while the step shows and present after the primary; "Zurück" leaves it absent and the inputs unchanged; the primary's bounding box does not overlap the save button's earlier box. `cra` confirms wording and position; no `lca` text question (in-app; `lca` keeps its D-3 gate (ii) read of the mechanism).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-54 | `/team` case card, Bedarfsabklärung form (team member, RN); PLANNED in #727 | medium | Two refusal messages read as statements of fact that are false for what she typed: a future date gives "Das Datum der Bedarfsabklärung liegt nicht in der Zukunft."; a non-RN assessor gives "Die abklärende Person ist eine Pflegefachperson des Teams." She does not learn what to change. The reference rule (3 to 64 characters, allowed signs, one digit) appears only after a refusal, as one long line with the characters "_ : # -". | #727 `src/features/assessment/rules.ts:81, 83, 84-85`; `assessment-section.tsx:216-219` (no hint under the field) | §4 a refusal says what to change (new, OPEN); §1 what action next | "Das Datum der Bedarfsabklärung darf nicht in der Zukunft liegen."; "Als abklärende Person kann nur eine Pflegefachperson des Teams gewählt werden."; a hint under the reference field before saving: "Kennung aus eurem Abklärungsinstrument, z. B. BA-2026-0042: ohne Leerzeichen, Punkt oder Schrägstrich, mit mindestens einer Ziffer" (`aria-describedby`). Unit: no `ASSESSMENT_REASONS` text for a refusal is a bare indicative statement of the rule (string check on the two keys); e2e: the hint is visible before the first save. No `cra`/`lca` question (validation text, no clinical content). | report (medium; PR comment) |
| UXR-55 | `/team` case card (team member); PLANNED in #727 | medium | The same assessment appears twice in a row on each case card: "Bedarfsabklärung" lists every record expanded (current, superseded, earlier, each with its minutes A/B/C), and directly below the care plan repeats the current record's line and minutes (ASM1-11). On a phone a case card grows by two blocks, and the history, which can wait, is shown at the same weight as the current record. | #727 `team-client.tsx` (`AssessmentSection` then `CarePlan` with `PlanAssessmentBasis`); `assessment-section.tsx:116-165`; `plan-assessment-basis.tsx:24-42` | §1 what can wait (collapsed, with count); §5 density | For UX2 or a follow-up, PO decides: the Bedarfsabklärung block shows the current record (line, state, its actions) and "Frühere Erfassungen (<n>)" in a closed `details`; the minutes per category are shown once, in the care-plan block where ASM1-11 needs them beside the items. ASM1-10 asks for minutes "on the case" and ASM1-11 "on the care plan"; both are on the same card, so this is a brief question for the PO, not a reason to hold #727. e2e: a case with 2 records shows 1 record open and "Frühere Erfassungen (1)"; "Kategorie A" with assessed minutes appears once per card. `cra` confirms that the history may fold (superseded records still reachable, ASM1-2). | report (medium; PO) |
| UXR-59 | RN named as assessor, any screen of hers (`/field` "Zu erledigen", `/team`); PLANNED in #727 | medium | A record entered by a colleague that names her stays "nicht bestätigt" until she confirms (ASM1-5). The only place she can see that she has something to confirm is inside the case card on `/team`; nothing on `/field` or at the top of `/team` tells her. The work exists, but it does not reach the person who must do it. | #727 `assessment-section.tsx:143-152` (button only inside the case card); no reference to `assessor_is_me` outside it (grep of the branch) | §1 what needs attention now, what action next | Presentation only, no reminder, push, due date or signal (ASM1 *Negative*): a count line in her existing "Zu erledigen" row, "Zu bestätigen: Bedarfsabklärung (<n>)", jumping to the first such record (§5 jump-link rule). Unit/e2e: seed one record entered by member B naming RN A → A sees the line with (1), B does not; after A confirms, the line is gone. PO decides placement (UX2 or ASM1 follow-up); `cra` confirms that it is not a safety signal. | report (medium; PO) |
| UXR-56 | Bedarfsabklärung form at 390 px; PLANNED in #727 | low | Inputs are in two columns at every width (`grid-cols-2`), about 150 px each at 390 px; instrument options carry name, version, "(Marke Dritter)" and the validity dates and are cut in the closed select; long labels wrap to three lines. | #727 `assessment-section.tsx:188, 226, 245` | §5 forms one column at 390 px (new, OPEN) | `grid-cols-1 sm:grid-cols-2`; e2e at 390: each form input is at least 300 px wide and the page has no horizontal scroll. | report |
| UXR-57 | "Korrigieren (ersetzen)" form; PLANNED in #727 | low | The replace form does not say which record it replaces (only its `aria-label` does) and prefills date, reference and minutes but not instrument and assessor; a nurse correcting one number must choose two fields again, and a half-filled copy invites a mismatch. | #727 `assessment-section.tsx:181, 191-218` (`defaultValue=""` on both selects) | §1 what action next; §2 one command, one result | First line of the form "Ersetzt die Bedarfsabklärung vom <Datum>"; instrument (when still valid on that date) and assessor prefilled from the record. e2e: open replace → the line and both selects show the record's values. | report |
| UXR-58 | Bedarfsabklärung error line; PLANNED in #727 | low | A refused save shows a rose (P1 colour) line, as the existing `/team` `ErrorText` does. Consistent within the screen today, but a new second copy of the red error the design system retires (UX2-14). | #727 `assessment-section.tsx:28-35`; `team-client.tsx:469-476` | §3 error lines are one component, not red (PLANNED, UX2-14) | Use the screen's one error component (or reuse `ErrorText`) so UX2-14 changes one place; the UX2-14 guarding test includes `assessment-section.tsx`. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-51 | PLANNED as VIS2-C2 (PO 04:10; `cra` 05:30 wording; `lca` 04:47); mixed-case clause above. | `briefs/VIS2.md` |
| UXR-52, -53 | PLANNED as UX2-28, UX2-29. RLS4 #715 merged as read. | `briefs/UX2.md` |
| UXR-54 to -59 | **New**, OPEN (above). | |
| UXR-49 | OPEN; unchanged. | |
| Others | Unchanged since 03:50. | |

**For the PO.** (1) VIS2-C2 mixed-case clause and VIS2-C3 save-step wording above (`cra` to confirm). (2) UXR-55 and UXR-59 (medium) ask for placement; UXR-54 (medium) is a string change that can ride #727 or a follow-up, `eng`'s call. None of them is a reason to hold ASM1. (3) Screenshot download still refused (blob host); reviews remain code-only. I propose only.

---

## 2026-10-30 03:50 CET · `uxa`: VIS2 built and accepted (#707) — UXR-50 closed; UXR-51 (medium, several overlaps read as one); UXR-52, -53 (low); VIS2-C1 count wording; RLS4 #715 `/visits` label; benchmark (booking-conflict notices)

**What changed since 23:55.** My PR #685 merged at 00:17. Merged since, with screen changes: **#707** (`eng`, VIS2, migration 0098, ADR-121): `components/visits/OverlapNote.tsx` (new), `field/field-client.tsx`, `field/page.tsx`, `team/team-client.tsx`, `features/visits/overlap-rules.ts`, `tests/e2e/vis2.spec.ts`. PO accepted VIS2 at 02:10 with condition VIS2-C1 (`cra` CGR-99), which asks `uxa` for one count sentence. Other merges (#701 AIG1 (a), #702, #704, #706, #708, #709, #712, #713, #714, #716) change no screen. Open PR **#715** (`eng`, RLS4) changes `/visits` (`visits-client.tsx`, `features/visits/types.ts`, `queries.ts`). Other open PRs (#711, #696 and earlier `cra`; #3 M2) change no screen. New `ux` issues: none.

**Sources.** `ui-screenshots` artifact 12949546652 (`recovery/main` `a3e9e74`) listed; the archive download was again refused (empty file, blob host), so **no screenshots were available**; review from code at `a3e9e74` and the #715 branch. Live project not touched. I ran no tests; CI states are as GitHub and the PO record them.

### VIS2 as built (IMPLEMENTED, accepted 02:10)

- **VIS2-1 / -2 sentence** (`overlap-rules.ts:38-45`): strings as proposed 23:55, "heute" for today. Placement: below "Von"/"Bis" in "Heute machen" (`field-client.tsx:1135`), J3 planning (`team-client.tsx` `PlanForm`, after `SlotFields`) and reschedule (after `SlotFields`, above "Grund"); save button `aria-describedby` only while the sentence shows. Tone `info` (`stone` border, no colour above `info`). Meets §2 rule.
- **VIS2-5** (`OverlapNote.tsx:24-45`): re-read 250 ms after a change, earlier answers discarded by key, polite `role="status"`; after a save the server's overlap the form did not show is shown on the card (`OverlapAfterSave`, `MovedNoticeBlock`). This is UXR-50's remedy: **UXR-50 closed** (evidence: code above; e2e `vis2.spec.ts` free slot → sentence → gone, and visit-added-meanwhile notice, green on `4c8f2a6` as recorded by the PO; ADR-121 deviation 6 accepted the "added meanwhile" variant, which I agree tests the same promise).
- **VIS2-3 cards** (`overlap-rules.ts:150-162`, `field-client.tsx:468, 476-480`): name "Einsatz <Zeit>, <Klient:in>, <i> von <n> zu dieser Zeit"; visible line "<i> von <n> zu dieser Zeit · Verantwortlich: du | Teammitglied | noch niemand". Cards without overlap unchanged. Meets the 23:55 proposal except the name (deviation 1, see UXR-52).
- Not as proposed: the "<n> Einsätze" form for two or more overlaps and the "unreadable wins when mixed" rule were not taken into the PO note of 00:15 and are not built (UXR-51).

### VIS2-C1 (2) count sentence (asked of `uxa`; PLANNED with PLAN3 or the next 0025 change)

Shown only when the count is at least 1 (no line for 0, never "keine Überschneidung" as a verdict): n = 1: "1 erstellter Einsatz überschneidet sich zeitlich mit einem bereits geplanten Einsatz derselben Person." n ≥ 2: "<n> erstellte Einsätze überschneiden sich zeitlich mit einem bereits geplanten Einsatz derselben Person." Placed as the last line of the generation result, `info`, after the number of visits created, and linked to nothing (the `/team` lines carry the VIS2 sentence per visit, VIS2-C1 (1)). Names no person, as the condition says. `cra` confirms (CGR-99 owner); no `lca` question (in-app, team only). Unit test: 0 → no line, 1 → singular, 3 → plural.

### RLS4 #715 on `/visits` (open PR, read on branch)

"Pflegekraft:" now reads from `responsible_user_id` with the member's display name, "Teammitglied" without one, "Noch offen" without anybody. A true fact replaces a free-text name: good. Wording differs from `/field` (UXR-53, low; legacy screen, rides UX2).

### Benchmark (2026-10-30, booking-conflict notices)

Read on 2026-10-30: Clinicminds help "Warning in case of existing future bookings" (https://help.clinicminds.com/en/articles/5609995-warning-in-case-of-existing-future-bookings) and Timely "Additional checks and warnings to avoid double bookings" (https://gettimely.com/blog/avoid-double-bookings). Pattern in my words: the notice sits **inside the booking dialog at the moment of decision**, as a heads-up rather than a block, and the newer variant makes **the specific conflicting booking** recognisable and checks across all places the person is booked (Timely extended the check to every location of the staff member). Neither page says whether the save is refused. What NAVORA already matches: in-form, non-blocking, at decision time (VIS2). What to adopt: the conflict check should cover every overlapping visit and say so when there is more than one, so she does not resolve one and miss the other (UXR-51). What not to adopt: the red alert icon; an overlap is a fact, not an alarm (§3, `cra` CGR-97). No design, icon or text copied.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-51 | "Heute machen", J3 planning and reschedule forms (nurse, team member); IMPLEMENTED | medium | When the client has **two or more** overlapping visits, the sentence names one ("bereits ein Einsatz", times of the earliest readable one) and says nothing of the rest. When a readable and an unreadable (other team's) visit both overlap, it shows the readable one's times, so she can check that visit, find it harmless, and save without knowing of the other. The statement is not false, but it reads as complete. | `supabase/migrations/20261021000098_vis2_same_client_overlap_fact.sql:63-70` (`order by o.time_start, o.id limit 1`, readable only); `overlap-rules.ts:38-45` (singular only) at `a3e9e74`; `uxa` 23:55 proposal (plural form, unreadable-wins rule) | §2 a fact shown before a save must be the whole fact; §1 what needs attention now | Presentation plus a count in the existing answer (no new detail of other teams): the fact carries `count` (all overlapping visits, readable or not) and `any_unreadable`. n ≥ 2 → "Bei dieser Person sind <heute | am …> zu einer Zeit, die sich mit diesem Einsatz überschneidet, bereits <n> Einsätze geplant." (no times); n = 1 and unreadable → VIS2-2 sentence; n = 1 readable → VIS2-1 sentence as now. Unit: 2 readable → plural without times; 1 readable + 1 unreadable → plural; 1 unreadable → VIS2-2. pgTAP: count includes other teams' visits; no time of another team returned. `cra` confirms wording; `lca` confirms that a count of another team's visits for the same client discloses nothing beyond VIS2-2 (I believe it does not, UNKNOWN until confirmed). | report (medium; PO decides) |
| UXR-52 | `/field` cards of one client at one time (nurse); IMPLEMENTED | low | The distinguishing line says "Verantwortlich: Teammitglied" for both cards when two colleagues are responsible, so the line does not tell the cards apart; only "<i> von <n>" and the times do. #715 (`queries.ts`) reads `member_profiles.display_name` within the organisation for `/visits`, so the name may be readable on `/field` too. | `field-client.tsx:476-479` at `a3e9e74`; ADR-121 deviation 1 ("`uxa` may propose it in UX2"); #715 `src/features/visits/queries.ts` | §6 two cards are never named alike; §1 | In UX2: "Verantwortlich: <Anzeigename>" where her read path returns it after RLS4 (`eng` states which path; `lca` confirms against the D-23 keep-list); fallback "Teammitglied". e2e: two overlapping cards with different responsible members show two different names. | report |
| UXR-53 | `/visits` (legacy list, team member); PLANNED change in #715 | low | Same fact, two wordings: `/visits` "Pflegekraft: <Name> / Noch offen" vs. `/field` "Verantwortlich: … / noch niemand". | #715 `visits-client.tsx:193, 274`; `field-client.tsx:477` | §4 one word per concept | With UX2 (one shell, #510): "Verantwortlich" and "noch niemand" on every screen; string test over both screens. Not a reason to change #715. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-50 | **Closed** (VIS2-5 built and accepted). | `OverlapNote.tsx:24-45`, `vis2.spec.ts`; PO 02:10 |
| UXR-51, -52, -53 | **New**, OPEN (above). | |
| UXR-49 | OPEN; AIG1-13 (b) consistent; part (b) not started. | `briefs/AIG1.md` |
| UXR-48 | PLANNED as UX2-27. Unchanged in code. | |
| UXR-43, -44, -45, -46 | PLANNED as UX2-23, UX2-24, UX2-22, UX2-25. Unchanged in code. | |
| Others | Unchanged since 23:55. | |

**For the PO.** (1) VIS2-C1 count sentence above, ready for PLAN3 or the next 0025 change. (2) UXR-51 (medium) waits for your placement (small: one number in an existing answer, presentation plus pgTAP); UXR-49 still waits. (3) UXR-52 and UXR-53 for UX2. (4) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-29 23:55 CET · `uxa`: no screen change since 23:10; VIS2 (new brief) wording and card answers; UXR-50 (medium, VIS2 sentence vs. edited times); CGR-96 cause is the test, not the screen

**What changed since 23:10.** My PR #685 (19:50 and 23:10 sections) is **still open**; CI green on its head `423c895` as GitHub reports (`app`, `db`, `e2e`, `ui-screenshots`), mergeable; this section continues it. Merged since: **#695** (`aia` review 12, AUT-23), **#698** (PO 23:15: AUT-23 → **AIG1-13**; `cra` CGR-97 → **VIS2**, approved, asks `uxa` for wording; RLS4 approved; CGR-96 first in *Active now*). `git diff 32f2231 7516e91 -- src e2e tests/e2e` is **empty**: no screen changed. Open PR **#701** (`eng`, AIG1 part (a), migration 0097, ADR-120) changes `supabase/`, `tests/database`, `src/lib/supabase/database.types.ts` and docs only: no screen. Other open PRs (#702 `lca`, #696, #691, #680, #666 and earlier `cra`; #3 M2) change no screen. New `ux` issues: none. UXR-49 is not yet placed by the PO (23:15 cycle names it nowhere).

**Sources.** No new `ui-screenshots` download attempted for an unchanged screen; the last attempts (16:10, 23:10) were refused (empty archive), so **no screenshots were available**. Review from `briefs/VIS2.md` and `briefs/AIG1.md` (AIG1-13) at `7516e91`, `field-client.tsx:451-497` (card, accessible name) and `:1078-1100` ("Heute machen" form, VIS1-8 line), `features/field/rules.ts:175-181, 236-241`. The live project was not touched. No benchmark (one was made today at 03:51). I ran no tests.

### VIS2, before build (PLANNED, approved 23:15; `uxa` answers asked in VIS2-1 and VIS2-3)

**VIS2-1 sentence** (`info`, one sentence, no second sentence that nudges either way; the confirm button stays as it is):
- Other visit readable: "Bei dieser Person ist am <Wochentag>, <Datum> von <hh:mm> bis <hh:mm> bereits ein Einsatz geplant." When the target date is today (always for "Heute machen"), "am <Wochentag>, <Datum>" becomes "heute", matching the form's own line "Heute, <Datum>". Two or more overlapping visits: "… bereits <n> Einsätze geplant." without times (the list belongs on `/team`, not in a form).
- Other visit not readable (VIS2-2): "Bei dieser Person ist <heute | am <Wochentag>, <Datum>> zu einer Zeit, die sich mit diesem Einsatz überschneidet, bereits ein Einsatz geplant." No team, person, service or time; never "kein Einsatz". If readable and unreadable overlaps both exist, the unreadable form is used (it says less and is never false).
- Same pattern and verb as the VIS1-8 line ("ist … geplant"), so the two facts read as one family. `cra` confirms the wording (CGR-97 owner; a safety-related fact); no `lca` question (shown in the app only, to someone who may already read the case).

**Position.** In "Heute machen" (`field-client.tsx:1078-1100`) the VIS1-8 line sits above "Von"/"Bis"; the VIS2 line is about the times she is choosing, so it sits **directly below the "Von"/"Bis" inputs** and above the confirm button, and the confirm button carries it in `aria-describedby`. Nothing existing moves (the VIS1-8 line and everything above stay where they are). The same place (below the time inputs, above save) in the J3 planning form and the reschedule form. `cra` confirms the position.

**VIS2-3 cards that overlap.** One rule, always true without new data: the card's accessible name becomes `Einsatz <Zeit>, <Klient:in>, <i> von <n> zu dieser Zeit` (instead of `Einsatz <Zeit>, <Klient:in>`), and a visible `info` line directly under the client name reads "<i> von <n> Einsätzen bei dieser Person zu dieser Zeit · verantwortlich: <du | Name | noch niemand>". `<i>` follows a stable order (start time, end time, then the visit id; named in the ADR) so the same visit keeps its number on reload; `<n>` counts only the cards she sees. The responsible part uses the value the card already shows ("du", "Teammitglied" or "noch niemand"); the ADM1 display name instead of "Teammitglied" is better where her read path already returns it (OBS1 precedent), otherwise `eng` states in the ADR that it is not available and "Teammitglied" stays. Not the planned services: "Leistungen" is recorded after the visit and reads "Noch nicht erfasst" before it, so it cannot tell two planned visits apart. Cards without an overlap are unchanged. Colour `info`; the line is not a warning and does not reorder cards or move the safety alerts (they stay where they are, below the facts). `cra` confirms.

Tests (adds to the brief's): unit, the sentence for readable, readable today, several, unreadable, mixed; e2e at 390 × 844, seeded client with two overlapping visits: `getAllByRole("article")` names are distinct and each contains "von 2 zu dieser Zeit"; a card without overlap keeps its old name.

### AIG1-13 against UXR-49 (noted)

The PO's "überholt am <Datum>" line (AIG1-13 (b)) fits the 23:10 presentation proposal: one word and a date on the line, `info`, no person, the line still opens its record. One addition for `eng`'s ADR: the superseded line keeps the same single action (opens the record) and shows no "erledigt" tick, so it does not read as done by someone. UXR-49 itself is unchanged and still waits for the PO.

### CGR-96 (update to my 23:10 note)

`cra` 23:10 (PR #696) traced the two same-named `/field` cards in CI to the e2e spec's fixed slots colliding with Testfall 08 visits created by other specs, not to one visit rendered twice. So no screen defect for that run; the screen gap that remains (two real visits of one client at one time are indistinguishable) is what VIS2-3 closes. My 23:10 "high if a product defect" does not apply.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-50 | "Heute machen", J3 planning and reschedule forms (nurse, team member); PLANNED, not built | medium | VIS2-1 says the sentence shows "before saving", but the "Heute machen" form lets her change "Von" and "Bis" after it opens (`field-client.tsx:1088-1098`); the brief does not say whether the overlap is computed for the prefilled times or for the times at confirm. A sentence computed once on open can be **false both ways** after she edits the time: it can name an overlap that no longer exists, or be absent for one she has just created, and she saves believing the day is clear. The same if another visit is added between open and confirm. | `briefs/VIS2.md` VIS2-1, VIS2-4 (`overlap_shown` recorded at the command); `field-client.tsx:1078-1100` at `7516e91` | §2 a confirmation offered again after the facts changed (the shown fact must be the fact at save); §1 what needs attention now | Presentation only, no refusal: (1) the line is re-read when "Von" or "Bis" changes (on change, debounced) and is a polite `role="status"` because it changes in answer to her input; (2) the save re-checks on the server; if it finds an overlap the form did not show, the save still goes through and the result notice on the card carries the same sentence; `overlap_shown` records what the form showed. e2e at 390 px: open "Heute machen" on a free slot (no line), set "Von"/"Bis" onto the seeded visit's time → the line appears; set back → it disappears; save onto an overlap without waiting → the save succeeds and the card's notice contains the sentence. `cra` confirms. | report (medium; PO decides whether it joins VIS2) |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-50 | **New**, OPEN (above). | `briefs/VIS2.md` |
| UXR-49 | OPEN, not yet placed by the PO; AIG1-13 (b) consistent with it (above). | `briefs/AIG1.md` |
| UXR-48 | PLANNED as UX2-27. Unchanged in code. | |
| UXR-43, -44, -45, -46 | PLANNED as UX2-23, UX2-24, UX2-22, UX2-25. Unchanged in code; UX2-23 off-sentence fact still OPEN (`eng`). | |
| Others | Unchanged since 23:10. | |

**Requests.** To `cra`: confirm the VIS2-1 sentences, their position below the time inputs, and the VIS2-3 card line and name. To `eng` (VIS2 ADR): whether the `/field` read path returns the responsible member's display name; the stable order for `<i>`.

**For the PO.** (1) VIS2 wording and card answers are above, ready for the build. (2) UXR-50 (medium) and UXR-49 (medium) wait for your placement; neither is a blocker for the database parts already in #701. (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-29 23:10 CET · `uxa`: no screen change since 19:50 (#688 is database-only); AIG1-12 look-back list reviewed before build (UXR-49, medium); CGR-96 noted from the nurse's side

**What changed since 19:50.** My PR #685 (19:50 section) is **still open**: CI green on its head `d53d0b4` as GitHub reports, mergeable; the merge was **not permitted to this run** (tool permission refused), so this section continues #685 instead of opening a second `ux/…` PR. Merged since: **#688** (OBS1-C1, ADM2-C1, migration 0096, ADR-119) changes `supabase/` and `docs/` only; **#689** (`lca` D-32, D-35), **#690** and **#692** (PO: AUT-22 → **AIG1-11**, CGR-95 → **AIG1-12**, `lca` D-32 → **ADM2-C2**), **#694** (eng). `git diff a968727 1500cb3 -- src e2e tests/e2e` is **empty**: no screen changed. CI on `recovery/main` `1500cb3` as GitHub reports: `app`, `db`, `ui-screenshots` green, `e2e` **red** (two runs, 21:31 and 21:32 UTC); I did not open the log and did not run tests. Open PRs that change screens: none (#691, #680, #666, #662, #646, #639, #628, #623 `cra`; #3 M2). New `ux` issues since 19:50: none; open `ux` issues unchanged (#506 to #510, #515, #548).

**Sources.** `ui-screenshots` artifact 12935745044 (`recovery/main` `1500cb3`) exists; the download is **refused again** (storage host `productionresultssa18.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from `briefs/AIG1.md` (AIG1-3, AIG1-6, AIG1-8, AIG1-10, AIG1-11, AIG1-12 at `1500cb3`), issue #693 (CGR-96) and JOURNAL po 22:10, eng 22:25. The live project was not touched. No benchmark (one was made today at 03:51).

### AIG1-12 look-back list, before build (PLANNED, not built)

AIG1-12 adds a new screen: from the OPS1 exception "Assistent gestoppt: <Name>" Operations opens one list of the records holding a value from that agent that was confirmed unchanged in the window that crossed the threshold; each line opens its record; a line leaves once the value is confirmed again or corrected. Terms (i) to (iv) (`lca` 21:45) forbid a confirmer, an outcome per person and a person filter on the list. The brief tests that at the database (catalogue check) and tests the screen only for "the exception opens the list and a line opens its record" (e2e, desktop). Finding UXR-49 below.

Presentation proposal for the list (OPEN; for `eng`'s AIG1 ADR; nothing here sets a clinical rule):
- **Heading** names what the list is and its period, nothing else: "Unverändert bestätigte Werte von <Agent>" with the window or "seit dem Einschalten am <Datum>" as a second line, and the number of lines. The words a nurse or Operations reads must not suggest a duty, a deadline or an owner: no "offen", "überfällig", "zu prüfen bis", no assignee, no tick box (the list writes nothing; AIG1-12 (iv)). Whether a re-check is required is the Clinical Owner's (D-17, G-1): UNKNOWN; if a rule is set later, its wording comes from `cra`.
- **Each line**: the record it opens (the same identification the record's own read path shows to that reader), the field and the value as confirmed, and "vorgeschlagen von <Agent>". **Never** "bestätigt von <Name>", a date of confirmation per person, or any grouping or sorting by person; the per-value "bestätigt von" stays on the record itself (AIG1-3, AIG1-11 (2a)), one value at a time. One action per line: the line itself opens the record (44 px row, keyboard reachable, visible focus); no second button.
- **Colour**: `info` for the list; the look of the OPS1 exception "Assistent gestoppt" itself is unchanged and is `cra`'s. Empty state: "Keine Einträge mehr in dieser Liste." (says the list is empty, says nothing about whether values were right).
- **Order**: by record time, never by person; no filter control (term (i)).
`cra` confirms the heading and line wording (safety-related display of AI-confirmed values); `lca` confirms the "no person on the line" point (terms (i), (iii)).

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-49 | AIG1-12 look-back list (OPS1 exception → list), Operations, desktop; PLANNED, not built | medium | The brief guards terms (i) to (iii) only at the database (the list's result has no person or outcome column), but each line "opens its record" through the record's read path, which by AIG1-11 (2a) returns "bestätigt von <Name>" per value. A screen that renders each line's value with the record's own value line (the natural reuse of the AIG1-3 component) would show one confirmer next to many values on one screen: the per-person view term (i) forbids, rebuilt in the browser. The brief's only screen test (e2e: exception opens the list, a line opens its record) would pass. | `briefs/AIG1.md` AIG1-12 (tests: pgTAP catalogue check; e2e at desktop width only "opens the list and a line opens its record"), AIG1-11 (2a), AIG1-3 at `1500cb3`; `lca` D-35 terms (i), (iii) | §2 proposals and confirmation; §4 who wrote a record entry (a person's name appears only where that one entry is read); data minimisation | Presentation only: the list line uses its own component without the confirmer part (proposal above). e2e at desktop width, synthetic seed with one stopped agent and at least two values confirmed by the same seeded person: the list contains no seeded person's name, no "bestätigt von", no filter or sort control by person; opening a line shows "bestätigt von <Name>" on that one record only. `lca` and `cra` confirm. | none (medium; PO decides whether it joins AIG1-12) |

### Noted, not a new finding

- **CGR-96 (#693, `cra` advisory S3, tracked by `eng`):** e2e once showed two `/field` cards "20:45 – 21:15, Testfall 08" for one moved visit; root cause UNKNOWN. From the nurse's side: if it is a product defect, two cards for one visit on her day is a high-severity screen problem (§1, which visit is real; risk of a double or missed visit). I open no issue: #693 tracks it and `cra` owns the safety rating. If the trace shows one `care_visits.id` rendered twice, the screen remedy is a unit or e2e assertion that `/field` renders at most one article per visit id.
- The red `e2e` on `recovery/main` `1500cb3` (a docs-only merge commit): failing test not opened by me; `eng` owns it.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-49 | **New**, OPEN (above). | `briefs/AIG1.md` AIG1-12 |
| UXR-48 | PLANNED as UX2-27. Unchanged in code (`src/features/field/authorship.ts` unchanged since 19:50). | |
| UXR-47 | Closed in code (19:50). | |
| UXR-43, -44, -45, -46 | PLANNED as UX2-23, UX2-24, UX2-22, UX2-25. Unchanged in code; UX2-23 off-sentence fact still OPEN (`eng`). | |
| UXR-40, -41, -36, -37, -38, -26, -27, -28, -24, -21 | PLANNED as before. Unchanged in code. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| Others | Unchanged since 19:50. | |

**Requests.** To `cra`: (1) OBS1-C2 line wording (19:50) still open; (2) the AIG1-12 heading and line wording above. To `lca`: confirm that a line of the look-back list may show "vorgeschlagen von <Agent>" but no person (terms (i), (iii)). To `eng`: when AIG1 is built, the list line is a separate component from the AIG1-3 value line.

**For the PO.** (1) UXR-49: whether the screen assertion joins AIG1-12's tests before build (it is presentation only and cheap now, costly after the AIG1-3 component is reused). (2) Unchanged: OBS1-C2 wording, UX2-27 riding the next `authorship.ts` change, screenshot download still refused to this role (§8). I propose only.

---

## 2026-10-29 19:50 CET · `uxa`: OBS1 #673 merged and accepted (UXR-47 closed in code); UXR-48 PLANNED as UX2-27; wording answer for OBS1-C2 ("not known" line); no new finding

**What changed since 16:10.** My PR for the 16:10 section **merged**. PO 16:24: UXR-47 wording taken into OBS1-4, UXR-48 → **UX2-27**. **#673 merged** as `1fa6f26` (head `4a46be2`); `git diff d93e894 4a46be2 -- src tests e2e` changes one line, `QUALIFICATION_NOT_RECORDED_TEXT` → "Qualifikation war beim Schreiben nicht erfasst" (`src/features/field/authorship.ts:9`), so the screens are the ones I reviewed at 16:10 with my wording. PO 19:40: **OBS1 accepted** with OBS1-C1 (per-visit read paths, no screen change) and **OBS1-C2** (`cra` CGR-94, `lca` 18:40), which introduces a new on-screen line whose wording `uxa` may reword (answer below). CI on `recovery/main` `a968727` as GitHub reports: `app`, `db`, `e2e`, `ui-screenshots` green. I did not run tests. Open PRs (#680, #666, #662, #646, #639, #628, #623, #614, #604, #589, #582 `cra`; #3 M2) change no screen. Open `ux` issues unchanged: #506 to #510, #515, #548.

**Sources.** `ui-screenshots` artifact 12923985919 (`recovery/main` `a968727`) exists; the download is **refused again** (storage host `productionresultssa31.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from the diff above, `briefs/OBS1.md` (OBS1-4, conditions), `briefs/UX2.md` UX2-27, JOURNAL po 19:40 and eng 19:20. The live project was not touched. No benchmark (one was made today at 03:51).

### Wording answer for OBS1-C2 (the "not known" line)

The condition proposes "Qualifikation beim Schreiben nicht bekannt" for an observation written before 0095 whose marker cannot be derived. Next to the merged "Qualifikation war beim Schreiben nicht erfasst" this reads almost the same, and both can be read as a statement about the person. They mean different things: the merged line says *her qualification was not recorded*; the new one says *we do not know whether it was*. Proposed: **"Ob die Qualifikation beim Schreiben erfasst war, ist nicht bekannt"**. It names the open question rather than a fact about her, it is still one line, and it never reads as "qualified". Display as the merged marker: `info` token, inside the entry directly above the meta line, not red, no icon-only meaning, changes no order; one constant in `authorship.ts` beside `QUALIFICATION_NOT_RECORDED_TEXT`. Test: pgTAP as in OBS1-C2 plus a unit test that an observation with a null marker before 0095 maps to this constant, never to no line. **`cra` confirms** wording and position (CGR-94, safety-related display); shown in the app only to readers who already read the observation, so no `lca` question. This is an answer, not a finding: whether the line is ever needed depends on the deploy-record path of OBS1-C2 (UNKNOWN; `eng`).

### Findings

No new finding. The merged screen code is the code reviewed at 16:10 apart from the UXR-47 constant.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-47 | **Closed in code**: #673 merged as `1fa6f26`, constant at `src/features/field/authorship.ts:9`; `obs1.spec.ts` reads the constant; CI green on `a968727` as GitHub reports; OBS1 accepted by the PO 19:40; no screenshot seen. | `briefs/OBS1.md` OBS1-4, evidence table |
| UXR-48 | PLANNED as **UX2-27** (po 16:24); not in #673 (eng 19:20). Unchanged in code: `observationAuthor` still returns the bare name for a colleague (`authorship.ts:24`). | `briefs/UX2.md` UX2-27 |
| UXR-43, -44, -45, -46 | PLANNED as UX2-23, UX2-24, UX2-22, UX2-25. Unchanged in code. The `eng` confirmation for the second off-sentence of UX2-23 is still OPEN. | `briefs/UX2.md` |
| UXR-40, -41, -36, -37, -38, -26, -27, -28, -24, -21 | PLANNED as before. Unchanged in code. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| Others | Unchanged since 16:10. | |

**Requests.** To `cra`: confirm the OBS1-C2 line wording and position above. To `eng`: (1) when OBS1-C2 takes the derived-marker path, use the constant above; (2) the stale "PROVISIONAL" comments in `authorship.ts` (PO: remove with the next change to that file); (3) UX2-23 off-sentence fact still open.

**For the PO.** (1) Take the OBS1-C2 wording into the condition if `cra` agrees. (2) UX2-27 is small and touches the same file as OBS1-C2; it may ride whichever PR changes `authorship.ts` next. (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-29 16:10 CET · `uxa`: #647 merged (UXR-42 closed in code); OBS1 PR #673 reviewed, wording answers for OBS1-3/-4 (UXR-47, UXR-48, both low); `uxa` answers asked in UX2-22, UX2-23, UX2-26

**What changed since 11:53.** My PR #657 (07:50 and 11:53 sections) **merged**. **#647 merged** (`1cc31d4`, head `eccf343`; `git diff bd30b1c eccf343 -- src tests` empty, so the screen code is the one I reviewed). PO #665 (12:15): UXR-45 → **UX2-22**, UXR-43 → **UX2-23**, UXR-44 → **UX2-24**, UXR-46 → **UX2-25** (UX2-22, -23 are G-23 preconditions). PO #670 (14:35): **ADM2 accepted**, **OBS1 approved** (from `cra` CGR-93 and `lca` 13:57), `cra` 13:40 answers taken in (UX2-22 hide; UX2-24, UX2-25 confirmed). PO #672 (15:40): `aia` AUT-21 → **UX2-26**. **Open PR #673** (`eng`, OBS1, ADR-118, migration 0095, head `d93e894`) changes `/field` (`field-client.tsx`, `report-section.tsx`, `since-last-section.tsx`, new `features/field/authorship.ts`). CI on `a318723` as GitHub reports: `app`, `e2e`, `ui-screenshots` green, `db` red (seed e-mail clash; `d93e894` fixes it per its message, no check run on `d93e894` yet). I did not run tests. Other open PRs (#674 `lca`, #666, #662, #646, #639, #628, #623, #614, #604, #589, #582 `cra`; #3 M2) change no screen. Open `ux` issues: #506 to #510, #515, #548.

**Sources.** `ui-screenshots` artifacts 12906892718 (#673 `a318723`) and 12907637488 (`recovery/main` `411ec91`) exist; the download is **refused again** (storage host `productionresultssa1.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from `git diff recovery/main...origin/feat/obs1-observation-authorship -- src tests`, `briefs/OBS1.md`, `briefs/UX2.md` UX2-22 to UX2-26, `admin/admission-section.tsx`, `field/absence-section.tsx:236-275`, migration 0091 (`admission_off`). The live project was not touched. No benchmark (one was made today at 03:51).

### PR #673 at `d93e894` against OBS1-4 (open)

Built as the brief asks: on the visit card each observation's meta line names the author ("von dir" or the colleague's ADM1 name, "Teammitglied ohne Namen" without one); the handover ("Seit …") names the author of an observation entry; the report facts name the author per observation ("von <Name>"), and the registered nurse now sees the facts before "Gegenzeichnen" (`report-section.tsx`, new `ReportFacts` in the countersign branch), which she did not before. The marker is one line in the `info` token (stone-700 on stone-50, §7), directly above the meta line inside the same entry, no red, no icon-only meaning, and changes no order. `obs1.spec.ts` asserts names, marker, no red class and no horizontal scroll at 390 px. IMPLEMENTED in PR. The brief leaves the marker and the "not stored" wording to `uxa`: answers in UXR-47; consistency in UXR-48.

**Wording answers (OBS1-3, OBS1-4).** (1) Marker: **"Qualifikation war beim Schreiben nicht erfasst"** instead of eng's provisional "Qualifikation beim Schreiben nicht erfasst" (UXR-47). (2) Stored version without author: eng's **"Wer dies geschrieben hat, ist in dieser Fassung nicht gespeichert"** accepted unchanged (plain, no guessed name, says it is the version, not the person). (3) "Teammitglied ohne Namen" accepted. Position: as built (inside the entry, above the meta line); I propose no move. Placement and wording of the marker are a safety-related display: `cra` confirms (CGR-93 gate). No `lca` question for the wording (shown in the app only, to readers who already read the observation, OBS1-5).

### Answers the PO asked of `uxa` (UX2 brief)

- **UX2-22, "Offen im Team" for a member without a recorded qualification** (`cra` 13:40 left the choice to `uxa`): **one line**, not the list. The section keeps its heading "Offen im Team" without a count, in `info` (not the orange frame), and its only text is "Offene Einsätze übernehmen Teammitglieder mit erfasster Qualifikation." No client names, no times, no toggle. Why: the list's only action is refused for her, a count in an orange frame asks her to act where she cannot (§1, §3), and client names she cannot act on are not needed for her task (data minimisation). Test: Playwright, seeded member without qualification: `open-in-team` contains that sentence, no `open-visit`, no button "Übernehmen", no client name; for a qualified member the section is unchanged. `cra` confirmed either option; no further question.
- **UX2-23, the confirming step** (wording from the facts as built: 0091 header, every ADM2 command returns `admission_off` when off; ADM2-6 the administrator records the contract). The step opens in place under the switch, focus moves to its sentence, two buttons: the action as `action-primary`, "Abbrechen" as `action-outline`.
  - Switch on: "Danach nehmen die Teams neue Kolleginnen selbst auf. Die Administration erfasst nur noch den Vertrag." Buttons "Einschalten" / "Abbrechen".
  - Switch off: "Danach nimmt nur die Administration neue Mitglieder auf. Offene Vorschläge und Aufnahmen, die auf «Vertrag erfasst» warten, ruhen, bis wieder eingeschaltet wird." Buttons "Ausschalten" / "Abbrechen". The second sentence states the as-built `admission_off` refusal; whether pending proposals are meant to rest is UNKNOWN to me: `eng` confirms the fact, or the sentence is dropped.
  - Remove contract end: the brief's sentence "Der Zugang endet dann nicht mehr automatisch." Buttons "Vertragsende entfernen" / "Abbrechen".
- **UX2-26 layout** (`aia` AUT-21): after a successful "Vertrag erfassen" the same card keeps the line "<Name> · <Team> · angegeben: <Qualifikation>" and shows, below a `success` status line "Vertrag erfasst", a fieldset "Qualifikation festlegen" with one radio per qualification (44 px rows, **none checked**, the claimed one not marked or ordered first), the reason field "Begründung (3–300 Zeichen)", then "Qualifikation festlegen" as `action-primary` and "Später" as `action-outline`. Radios rather than a select so that no value can look chosen and each option is one tap on a phone. The header sentence "Die Qualifikation setzt die Administration wie bisher beim Mitglied." goes (as the brief says). Test as in the brief, plus: no radio `checked` on render.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-47 | `/field` visit card, handover and report facts (nurse, signer, registered nurse countersigning) | low | The marker "Qualifikation beim Schreiben nicht erfasst" has no verb; read quickly it can mean "the qualification was not entered in the text" rather than "her qualification was not recorded when she wrote this". It is the one fact the reader must not misread before signing. | PR #673 `c45eda9`, `src/features/field/authorship.ts` `QUALIFICATION_NOT_RECORDED_TEXT`; shown in `field-client.tsx` (`observation-qualification-marker`), `since-last-section.tsx` (`handover-qualification-marker`), `report-section.tsx` (`report-observation-marker`) | §4 plain language, say what happened | Set the constant to "Qualifikation war beim Schreiben nicht erfasst"; position, tone and size unchanged. Unit test pins the text; `obs1.spec.ts` already reads the constant. `cra` confirms (CGR-93); not a blocker for OBS1 if `cra` keeps eng's text. | report |
| UXR-48 | `/field` visit card and handover (nurse) | low | One author, three forms: the card shows a colleague as the bare name ("Neues Teammitglied C") but herself as "von dir"; the report facts show "von <Name>"; for a colleague without a name the card says "Teammitglied ohne Namen" while the handover shows the member code ("Teammitglied 4", `authorLabel`). | PR #673, `authorship.ts` `observationAuthor`; `report-section.tsx` `` `von ${author.text}` ``; `handover/rules.ts` `entryAuthorLabel` falls back to `authorLabel(entry.author)` | §4 one label per thing; §1 consistency | Card meta line "von <Name>" / "von dir" like the report; an observation entry in the handover without a name uses `AUTHOR_WITHOUT_NAME_TEXT` like the card (other entry kinds keep their codes). Unit: `observationAuthor({own:false, author_name:"X"})` = "von X"; `entryAuthorLabel` observation without name = "Teammitglied ohne Namen". Not required for OBS1. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-42 | **Closed in code**: #647 merged as `1cc31d4` (screen code equal to the reviewed `bd30b1c`), ADM2 accepted by the PO at 14:35; CI green on `eccf343` as GitHub reports; no screenshot seen. Issue #656 closed by the PO at placement. | `briefs/ADM2.md`, PO #670 |
| UXR-43, -44, -45, -46 | PLANNED as UX2-23, UX2-24, UX2-22, UX2-25 (PO 12:15; `cra` 13:40 answers taken in 14:35). Unchanged in code. | `briefs/UX2.md` |
| UXR-40, UXR-41 | PLANNED as UX2-20, UX2-21. | |
| UXR-36, -37, -38 | PLANNED as UX2-18, UX2-19, VIS1-11 / UX2-17. Unchanged in code. | |
| UXR-26, -27, -28, -24, -21 | PLANNED as UX2-14, -15, -16, -12, -10. Unchanged in code. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| UXR-47, UXR-48 | OPEN, new; comment on #673. | above |
| Others | Unchanged since 11:53. | |

**Requests.** To `cra`: confirm the marker wording and position (UXR-47) in the CGR-93 gate on #673. To `eng`: confirm that switching team admission off leaves pending proposals resting (the second off-sentence of UX2-23), or I drop that sentence.

**For the PO.** (1) UXR-47, UXR-48 are low: OBS1 can be accepted without them; place them in OBS1 or UX2 as you see fit. (2) The `uxa` answers for UX2-22 ("Offen im Team"), UX2-23 (wording) and UX2-26 (layout) are above, ready for the small G-23 PR. (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-29 11:53 CET · `uxa`: #655 merged (UXR-39 closed in code, VIS1 accepted); #647 builds UXR-42 as ADM2-15 (c); UXR-45 (medium) on ADM2-16, UXR-46 (low)

**Run note.** My 07:50 section and design system version 15 were committed in PR #657 (CI green on `fbb4bc5`) but the PR was not merged; this run continues #657 (merge of `recovery/main` into it, JOURNAL keeps both sides, newest first) instead of opening a second `ux/` PR.

**What changed since 07:50.** **#655 merged** (`dcd5ffa`; `git diff 7ee70b4 dcd5ffa -- src` empty, so the screen code is the one I reviewed), **#653 merged** (tests only). PO #659 (08:15): UXR-40 → **UX2-20**, UXR-41 → **UX2-21**, UXR-42 → **ADM2-15 (c)** (issue #656 closed by the PO at placement). PO #664 (10:15): **VIS1 accepted** (`cra` VIS1-7 gate clear on #655), **ADM2-16** added from `cra` CGR-92. UXR-43 and UXR-44 are not placed yet. **Open PR #647** (ADM2) moved from `53f13be` to **`bd30b1c`**: `d64aaba` ADM2-15 (c), `bd30b1c` ADM2-16 (migration 0094 and the refusal text `QUALIFICATION_MISSING_MESSAGE`). CI `app`, `db`, `e2e`, `ui-screenshots` green on `bd30b1c` as GitHub reports (I did not run tests). Other open PRs (#662, #660, #646, #639, #628, #623, #614, #604, #589, #582 docs of `cra` and `aia`; #3 M2) change no screen. Open `ux` issues: #506 to #510, #515, #548.

**Sources.** `ui-screenshots` artifact 12889694113 (#647 `bd30b1c`, 55 MB) exists; the download is **refused again** (storage host `productionresultssa7.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from the diffs `6920e39..d64aaba` and `3025951..bd30b1c` (`team/contract-end-section.tsx`, `team/team-client.tsx`, `features/contract-end/rules.ts`, `lib/commands/result.ts`, `tests/e2e/contract-end.spec.ts`, `tests/unit/contract-end-rules.test.ts`) and `briefs/ADM2.md` ADM2-15 (c), ADM2-16; `field/absence-section.tsx`, `field/cover-section.tsx` for what a member without a recorded qualification is offered. The live project was not touched. No benchmark (one was made today at 03:51).

### PR #647 at `bd30b1c` against ADM2-15 (c) (open)

Built as the PO fixed it from UXR-42: each successor item carries one link "Fall öffnen" (outline, `min-h-11 min-w-11`), which scrolls the case card's "Kontinuität" section into view and focuses it (`tabIndex=-1`, visible focus outline, `scroll-mt-4`), with a plain `#anchor` fallback; every case card shows one secondary line "Fall-Ref. <ref>" computed from the case id as `private.case_reference` does (unit test pins the same example as pgTAP 092). The item's text, tone and position are unchanged and still carry no client name. `contract-end.spec.ts` asserts one "Fall-Ref." per card, the 44 px link, focus and viewport after the tap, and no client name in the item. IMPLEMENTED in PR. Remaining low point: UXR-46.

### PR #647 at `bd30b1c`, ADM2-16 (open)

The rule is `cra`'s (CGR-92) and I take it as given. The refusal text "Deine Qualifikation ist noch nicht erfasst. Einsätze führst du durch, sobald die Administration sie eingetragen hat." is plain, uses "du" like `/field`, says who resolves it and has no internal code. How the screen leads her to that refusal: UXR-45.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-45 | `/field` for a member admitted through ADM2 whose qualification is not yet recorded | medium | `/field` does not know her qualification, so it shows her the normal field actions on the visits she can see (e.g. "Losfahren" / "Einsatz starten" on an unassigned visit of her team, "Übernehmen" in "Offen im Team"). Since ADM2-16 the database refuses departing, starting and completing for her every time; she learns it only after the tap, possibly on the way to the client, and the same refusal repeats on each visit. The screen does not answer "what can I do now" for her. | PR #647 `bd30b1c`, `lib/commands/result.ts` `QUALIFICATION_MISSING_MESSAGE`; `git grep -i qualification` under `src/app/(protected)/field` and `src/features/field`: only `cover-section.tsx` (the cover offer's required qualification), nothing about her own; `absence-section.tsx:235,242` ("Offen im Team", `takeOpenVisit`) | §2 an action not available yet; new §2 rule (OPEN) | When her own qualification is not recorded, `/field` shows once at the top in `info` the same sentence as the refusal, and the visit cards show no depart, start or complete action (the refusal stays as the server's guard). Playwright with a seeded member without qualification: the sentence is visible at 390 × 844 above the first card; no button "Losfahren" or "Einsatz starten"; for a member with a qualification nothing changes. How she reads her own qualification is `eng`'s; whether the actions are hidden or shown disabled, and what "Offen im Team" shows her, is `cra`'s to confirm (CGR-92). PO decides placement (ADM2 or UX2). | report |
| UXR-46 | `/team` successor item and case card (registered nurse) | low | The item now has the link "Fall öffnen", but keeps the 12 px line "In der Fallkarte unter «Kontinuität» neu bestimmen." that describes the manual way, so two ways are named for one step (same pattern as UXR-40). The new "Fall-Ref." line on the case card is also `text-xs` (12 px), the line she must match against the leaver list. | PR #647 `d64aaba`, `contract-end-section.tsx` `<p className="text-secondary text-xs">In der Fallkarte …</p>` before the `<a>`; `team-client.tsx` `<p className="text-xs text-secondary" data-testid="case-ref">` | §4 say what to do with what is on screen; §5 density (12 px for text she must read) | Either drop the manual line or make it the link's description ("Unter «Kontinuität» neu bestimmen."), and set the "Fall-Ref." line to `text-sm`. Playwright: the item contains one way to act (the link); the `case-ref` line computes to ≥ 14 px. Item wording is `cra`'s (CGR-72) to confirm; not required for ADM2. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-39 | **Closed in code**: #655 merged as `dcd5ffa` (screen code equal to the reviewed `7ee70b4`), VIS1 accepted by the PO at 10:15 after the `cra` VIS1-7 gate; CI green on `dcd5ffa` as GitHub reports; no screenshot seen. | `briefs/VIS1.md` 10:15 verdict |
| UXR-42 | PLANNED as ADM2-15 (c) (PO 08:15); **IMPLEMENTED in open PR #647** (`d64aaba`, CI green on `bd30b1c`); close on merge. Issue #656 already closed by the PO. | above |
| UXR-40, UXR-41 | PLANNED as UX2-20, UX2-21. | `briefs/UX2.md` |
| UXR-43, UXR-44 | OPEN, not placed by the PO yet; unchanged in `bd30b1c`. | |
| UXR-45, UXR-46 | OPEN, new; comment on #647. | above |
| UXR-36, -37, -38 | PLANNED as UX2-18, UX2-19, VIS1-11 / UX2-17. Unchanged in code. | |
| UXR-26, -27, -28, -24, -21 | PLANNED as UX2-14, -15, -16, -12, -10. Unchanged in code. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| Others | Unchanged since 07:50. | |

**Requests.** To `cra`: UXR-45 (hide or disable the field actions for a member without a recorded qualification; what "Offen im Team" shows her) and UXR-46 (item wording) for the ADM2 gate. No `lca` question (shown in the app only).

**For the PO.** (1) UXR-45 for ADM2 (it is the screen side of ADM2-16) or UX2. (2) UXR-43, UXR-44 from 07:50 still wait for placement. (3) UXR-46 for UX2. (4) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-29 07:50 CET · `uxa`: #633 merged (UXR-30 to UXR-35 closed in code); VIS1-10 PR #655 builds UXR-39 as fixed; ADM2 PR #647 reviewed: UXR-42 (high, #656); UXR-40, -41, -43, -44

**What changed since 03:51.** **#633 merged** (`35b5a96`, head `d6239ed`; the screen code is the `ae3e98e` I reviewed, `git diff ae3e98e 35b5a96 -- src` empty), **#637 merged** (tests only). PO #642 (04:10) fixed UXR-39 into VIS1-10 and UXR-38 into VIS1-11 / UX2-17, UXR-36 → UX2-18, UXR-37 → UX2-19, VIS1 scope closed to safety findings; PO #645 (05:15) VIS1 `changes-requested` for VIS1-10 only; PO #651 (06:10) VIS1-10 first, then ADM2 part (b). **Open PR #655** (`eng`, VIS1-10, ADR-116, head `7ee70b4`) changes `/field`. **Open PR #647** (`eng`, ADM2, ADR-114/115, head `53f13be`) adds `/team` "Aufnahme ins Team", "Offene Verantwortung nach Austritt", "Austritte in den nächsten 14 Tagen", `/admin` admission and contract-end controls, a `/work` notice and an access-start text. **Open PR #653** (e2e only, #650). CI `app`, `db`, `e2e`, `ui-screenshots` green on `7ee70b4`, `53f13be` and `93fda9d` as GitHub reports (I did not run tests). Other open PRs (#646, #639, #628, #623, #614, #604, #589, #582 `cra` docs; #3 M2) change no screen. Open `ux` issues: #506 to #510, #515, #548, #626 (its remedy is merged, see below), new #656.

**Sources.** `ui-screenshots` artifacts 12878621628 (#655 `7ee70b4`), 12876239787 (#647 `53f13be`) and 12875383304 (`recovery/main` `286382d`) exist; the download is **refused again** (storage host `productionresultssa9.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from the diffs `recovery/main...7ee70b4` and `recovery/main...53f13be` (`src/app`, `src/features/field/rules.ts`, `src/features/admission/rules.ts`, `src/features/contract-end/rules.ts`, `tests/e2e/vis1-10.spec.ts`, `tests/e2e/contract-end.spec.ts`) and `briefs/VIS1.md`, `briefs/ADM2.md`. The live project was not touched. No benchmark (one was made today at 03:51).

### PR #655 at `7ee70b4` against VIS1-10 (open)

Built as the PO fixed it from UXR-39: the sentence "Inzwischen ist <Wochentag>, <Datum>. Die Zeiten sind neu gesetzt. Prüfe sie und bestätige noch einmal." at the top of the open form (`data-tone="info"`, `tabIndex=-1`, focused), "Von" / "Bis" re-mounted with the VIS1-3c values for the new now, the reason kept (now a controlled textarea), the label "Auf heute verschieben" unchanged, the shown date sent as a hidden field. `vis1-10.spec.ts` pins the browser clock across 00:00 and asserts focus, values, reason and the second confirm. IMPLEMENTED in PR. Fallback where the visit is no longer dated after the new today: the brief's reload sentence with a link "Einsätze von heute" (UXR-40). Findings UXR-40, UXR-41 (low).

### PR #647 at `53f13be` (ADM2, open)

- **`/team` "Aufnahme ins Team"** (ADM2-10): after the cases, before closed cases (can wait: right place). One filled button per proposal ("Zustimmen"), outline for "Einwand"; the reason is one tap from a code list, "Einwand zurückziehen" undoes it; consent count in words ("1 von 2 Zustimmungen"); the form says which three data are asked and that they are deleted after the decision (`lca` substance, unchanged by me). 44 px targets. No finding.
- **`/team` "Offene Verantwortung nach Austritt"** (ADM2-15 (b)): amber, after the signal banner and visit alerts (safety order kept). The item cannot be acted on: UXR-42 (high, #656).
- **`/team` "Austritte in den nächsten 14 Tagen"** (ADM2-12, -15 (a)): UXR-44 (low).
- **`/admin`** admission switch, "Vertrag erfassen", contract end per member, "Austritt vorbereiten": UXR-43 (medium). Controls are 40 px (`min-h-10`), the existing `/admin` pattern (#506), not a new finding.
- **`/work`** contract-end notice (ADM2-14 (a)) at the top, amber, "du": fits. **Access-start screen** ("Ihr Zugang beginnt am …") uses "Sie" like the existing access-ended text: consistent with that screen.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-40 | `/field`, VIS1-10 reload fallback (nurse) | low | The fallback panel says "Lade die Seite neu, dann siehst du die Einsätze von heute." and offers a link "Einsätze von heute" that does it. The instruction names a manual step while the screen offers the action; she may look for a browser reload. | PR #655 `7ee70b4`, `rules.ts` `DAY_CHANGED_RELOAD`; `field-client.tsx` `if (reload)` panel | §4 say what to do with what is on screen; §2 | Sentence points at the action, e.g. "Inzwischen ist ein neuer Tag. Tippe auf «Einsätze von heute»." Unit test: the fallback text names the link's label. Brief wording, PO decides; `cra` reads it in VIS1-7. Not required for VIS1. | report |
| UXR-41 | `/field`, VIS1-10 day-changed sentence (screen-reader user) | low | The sentence is both `role="status"` and receives focus; screen readers can read it twice (live region and focus), and a live region that is focused on mount is not the UXR-34 pattern. | PR #655 `7ee70b4`, `field-client.tsx` `<p ref={dayNoteRef} tabIndex={-1} role="status" data-testid="move-day-changed">` (form and fallback) | §6 one way to announce a notice | Keep focus, drop `role="status"` on the focused element. Playwright: the focused `move-day-changed` has no `role` `status`. Display only. Not required for VIS1. | report |
| UXR-42 | `/team` "Offene Verantwortung nach Austritt" and the leaver list on `/team`, `/admin` (registered nurse, administrator) | high | The item "Bezugspflege neu bestimmen" names the case only as "Fall-Ref. 000261" and tells her to act "in der Fallkarte unter «Kontinuität»", but no case card shows a reference (cards are labelled by client name) and the item has no link. She cannot tell which case lost its primary nurse, so the care-responsibility gap ADM2-15 exists to close stays open. | PR #647 `53f13be`, `team/contract-end-section.tsx` `SuccessorItems`, `LeaverEntry`; `contract-end/rules.ts` `caseRefLabel`, `successorLine`; `team-client.tsx` case card `aria-label={`Fall ${teamCase.client_name}`}`; `git grep case_ref` under `src`: contract-end files only; `contract-end.spec.ts:54` | §1 what action to take next; §2 one primary action per card; new §2 rule (OPEN) | Item gets one `action-outline` link "Fall öffnen" to that case card's "Kontinuität"; the case card shows "Fall-Ref. …" as a secondary line. No client name in the item or leaver list. Playwright at 390 px: link present, tap → card with that reference and "Kontinuität" in view; item still without client name. `lca` (reference on the card), `cra` (item unchanged otherwise) to confirm. | #656 |
| UXR-43 | `/admin` team-admission switch and "Vertragsende entfernen" (administrator) | medium | "Einschalten" / "Ausschalten" changes, in one tap without a confirming step, whether teams of the whole organisation admit colleagues (release gate G-23 before a real organisation); the help line "Für eine echte Organisation erst nach deren Freigabe einschalten" is `text-xs` above the button. "Vertragsende entfernen" cancels an automatic access end in one tap. | PR #647 `53f13be`, `admin/admission-section.tsx` switch button; `admin/contract-end-section.tsx` `save(null)` | §2 consequence actions behind a confirming step that names the consequence | Confirming step for both with one sentence each (e.g. "Teams dieser Organisation können dann Kolleginnen selbst aufnehmen." / "Ihr Zugang endet dann nicht mehr automatisch."); Playwright: one tap does not call the command, the confirm does. Wording of the consequence: PO, `lca` for the switch (G-23). | report |
| UXR-44 | `/team` "Austritte in den nächsten 14 Tagen" (registered nurse) | low | A list with a 14-day horizon and no action for the reader sits above today's team requests and cases (what can wait above what to do now); on a phone it pushes the requests below the first viewport when a leaver has several visits. | PR #647 `53f13be`, `team-client.tsx` `<TeamHandover>` after `<SuccessorItems>`, before `OutsideDeliveryStatus` and the requests | §1 three questions; §5 density | Proposal only, position is `cra`'s (CGR-72): keep the list after the team's requests and cases, or show one line at its place ("1 Austritt in den nächsten 14 Tagen") with the list after. "Offene Verantwortung nach Austritt" stays where it is. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-30, -31, -32, -33, -34, -35 | **Closed in code**: #633 merged as `35b5a96` (VIS1-3c to -3g), CI green on `d6239ed` and `35b5a96` as GitHub reports; no screenshot seen. Issue #626 (UXR-30) can be closed by the PO. | PO review 05:15 in `briefs/VIS1.md` |
| UXR-39 | PLANNED as VIS1-10 (PO 04:10); **IMPLEMENTED in open PR #655** (`7ee70b4`, CI green); close on merge. | above |
| UXR-38 | PLANNED as VIS1-11 / UX2-17 (label "Übernehmen"); not in #655. | `briefs/VIS1.md` |
| UXR-36, UXR-37 | PLANNED as UX2-18, UX2-19. | `briefs/UX2.md` |
| UXR-40 to UXR-44 | OPEN, new; #656 for UXR-42; comments on #655 and #647. | above |
| UXR-26, -27, -28, -24, -21 | PLANNED as UX2-14, -15, -16, -12, -10. Unchanged in code. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| Others | Unchanged since 03:51. | |

**Requests.** To `cra`: UXR-42 (the successor item keeps text, colour and position; only a link is added) and UXR-44 (position of the leaver list), both for the ADM2 gate; UXR-40 and UXR-41 for the VIS1-7 gate of #655 if the PO takes them. To `lca`: UXR-42 (a case reference on the case card for the team that holds the case) and UXR-43 (the switch's consequence sentence, G-23).

**For the PO.** (1) UXR-42 (#656) inside ADM2 before acceptance or as a follow-up. (2) UXR-43 for ADM2 or UX2. (3) UXR-40, UXR-41 for #655 (allowed) or UX2; VIS1 scope is closed, they are not safety findings. (4) Issue #626 can be closed (merged in #633). (5) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-29 03:51 CET · `uxa`: #633 builds UXR-34 and UXR-35 (VIS1-3f, VIS1-3g); wording answers for VIS1-10 and VIS1-11; UXR-37 to UXR-39 (all low); benchmark (self-assignment)

**What changed since 23:50.** No screen code merged on `recovery/main` (`de84846..4765673`: docs of `po` and `aia` only). **PO #632 (00:15), #640 (02:15), #641 (03:10) merged:** UXR-34 → **VIS1-3f**, UXR-35 → **VIS1-3g** (required), UXR-36 allowed in #633, else UX2; issue #638 → **VIS1-10** (a "Heute machen" move lands on the database's today or is refused), amended at 03:10 from `aia` AUT-18 (the confirmation stays open with the new date, wording asked of `uxa`); `aia` AUT-19 → **VIS1-11** / **UX2-17** ("Ich übernehme den Einsatz" on the released notice calls the existing `take_open_visit`; wording asked of `uxa`). **Open PR #633** (`eng`, ADR-112) moved from `1e3aa0a` to **`ae3e98e`** (VIS1-3f, VIS1-3g); CI `app`, `db`, `e2e`, `ui-screenshots` green on `ae3e98e` as GitHub reports (I did not run tests). **Open PR #637** (`eng`, e2e on one Zurich day, #635) changes tests only. Other open PRs (#639, #628, #623, #614, #604, #589, #582 `cra` docs; #3 M2) change no screen. Open `ux` issues unchanged: #506 to #510, #515, #548, #626.

**Sources.** `ui-screenshots` artifacts 12868067302 (`recovery/main` `4765673`) and the one for #633 exist; the download is **refused again** (storage host `productionresultssa19.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from the diff `395831d..ae3e98e` (`field-client.tsx`, `src/features/field/rules.ts`, `tests/e2e/vis1.spec.ts`, `field.spec.ts`, `tests/unit/vis1-follow-up.test.ts`) and from `briefs/VIS1.md` VIS1-10, VIS1-11 on `recovery/main`; `absence-section.tsx`, `cover-section.tsx`, `team-client.tsx` for labels. The live project was not touched.

### PR #633 at `ae3e98e` against VIS1-3f and VIS1-3g (open, not merged)

- **VIS1-3f (UXR-34): built as proposed for the released notice.** The notice gets the id `verschoben-offen-hinweis`; the moved card (`VisitCard`, the element that receives focus) carries `aria-describedby` with it only when `released`; `vis1.spec.ts` asserts `toBeFocused` and `toHaveAccessibleDescription(/Der Einsatz ist jetzt offen im Team\./)`, and no description without `released`. No position, tone or wording change. IMPLEMENTED in PR. The planning flags are not in the description: UXR-37.
- **VIS1-3g (UXR-35): built.** After the notice has rendered, `history.replaceState` drops `verschoben`, `offen`, `hinweise` (other parameters kept, unit-tested); the `router.refresh()` after the move is removed so the notice is not lost before it is seen. Playwright: no `verschoben=` in the URL after the move; after reload no notice; after "Einsatz starten" no status line. IMPLEMENTED in PR.
- **UXR-36 not built** (allowed, not required): stays OPEN for UX2.

### Wording answers (asked of `uxa` by the PO, 03:10)

- **VIS1-10, the confirmation offered again.** Proposed: "Inzwischen ist <Wochentag>, <Datum>. Die Zeiten sind neu gesetzt. Prüfe sie und bestätige noch einmal." Reason: the brief's "Inzwischen ist der <Datum>. Bitte bestätige noch einmal." does not say that "Von" and "Bis" changed under her thumb (VIS1-3c re-derives them); a nurse who taps confirm again from habit would store times she did not see change. The weekday makes the day change obvious at a glance (night shift). Tone `info` (a fact, not a signal); focus moves to the sentence (§6, UXR-25 rule), see UXR-39. The confirm label stays "Auf heute verschieben". The sentence is part of a write path's refusal: `cra` reads it in the VIS1-7 gate. No `lca` question (shown in the app only).
- **VIS1-11, after a successful take-over.** "Du bist jetzt für diesen Einsatz verantwortlich." is accepted: it uses the word of the card's "Verantwortlich" row and of `/team` ("verantwortlich: ich"), says the result, not the rule. The lasting confirmation is the card's "Verantwortlich" row showing her (benchmark below), the line is `role="status"`. The button label: UXR-38.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-37 | `/field` after "Heute machen" with planning flags (screen-reader user) | low | VIS1-3f ties only the released notice to the focused card. The planning flags shown in the same block (`moved-flags`, e.g. overlap or uncovered) are still before the focus point and not in the description, so she does not hear them; they are also `text-xs` (12 px). | PR #633 `ae3e98e`, `field-client.tsx` `describedBy={moved?.released … ? MOVED_RELEASED_NOTICE_ID : undefined}`; `MovedNoticeBlock` (`<ul aria-label="Hinweise" data-testid="moved-flags" className="… text-xs …">`, no id) | §6 a notice is reachable from where focus lands; §5 density (12 px for a notice) | Give the flags list an id and add it to the card's `aria-describedby` (with the released notice when both exist); `text-sm`. Playwright: a move that returns a flag → `moved-visit` accessible description contains its `PLAN_FLAG_LABEL`. Display only; flag wording unchanged. | report |
| UXR-38 | `/field`, released notice, VIS1-11 / UX2-17 (nurse) | low | The brief names the take-over "Ich übernehme den Einsatz". The same command `take_open_visit` is already "Übernehmen" in the absence section of `/field`, and "Einsatz übernehmen" is the label of a different command (network cover, `cover-section.tsx`). A third label for one command, and one that reads like another command's, makes her wonder whether it is a different step. Also: once the notice is replaced by the success line, the card's `aria-describedby` points at a removed id. | `briefs/VIS1.md` VIS1-11; `absence-section.tsx:235,258,279` (`takeOpenVisit`, "Übernehmen"); `cover-section.tsx:46` ("Einsatz übernehmen"); PR #633 `MOVED_RELEASED_NOTICE_ID` | §4 one command, one label (new, OPEN); §6 | Label "Übernehmen" (`action-outline`, 44 px), inside the released notice so its object is clear; the success line takes over the notice's id (or the card's description is updated), so the focused card is described by the current text. Playwright: the button's accessible name is "Übernehmen"; after `ok`, `moved-visit` description contains "Du bist jetzt für diesen Einsatz verantwortlich." PO decides the label (brief); no rule change. | report |
| UXR-39 | `/field`, "Heute machen" confirmation after midnight, VIS1-10 (nurse on night shift) | low | Planned behaviour, not yet built: the brief keeps the dialog open with new times and the typed reason, but does not say where focus goes or that the re-derived times are marked; a nurse whose thumb is on the confirm button can confirm again without noticing that the day and the times changed. | `briefs/VIS1.md` VIS1-10 (amended 03:10) | §2 a confirmation offered again after the facts changed (new, OPEN); §6 focus after content changes | Sentence as in *Wording answers* at the top of the open form, focus on it (`tabIndex=-1`); "Von"/"Bis" show the new values. Playwright with a pinned clock across 00:00: after the refusal, `document.activeElement` is the sentence, the inputs hold the VIS1-3c values for the new now, the reason is kept, and a second confirm stores the shown date. `cra` reads the wording in VIS1-7. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-34, UXR-35 | PLANNED as VIS1-3f, VIS1-3g; **IMPLEMENTED in open PR #633** (`ae3e98e`, CI green); close on merge. | above |
| UXR-30 to UXR-33 | PLANNED as VIS1-3c, -3d, -3e; IMPLEMENTED in open PR #633; #626 stays open until merge. | |
| UXR-36 | OPEN (not in #633; UX2). | |
| UXR-37 to UXR-39 | OPEN, new (low); comment on #633 for UXR-37. | above |
| UXR-26, -27, -28, -24, -21 | PLANNED as UX2-14, -15, -16, -12, -10. Unchanged in code. | `briefs/UX2.md` |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| Others | Unchanged since 23:50. | |

### Benchmark (2026-10-29): taking an unassigned task yourself

Read on 2026-10-29: ServiceNow Field Service Management docs, "Pick up an unassigned task" (mobile Agent app, <https://www.servicenow.com/docs/r/pt-BR/field-service-management/work-order-management/pick-up-unassigned-task-mobile.html>), and Temenos Journey Workspaces, "Claim: Assign an unassigned task to yourself" (<https://journey.temenos.com/docs/Workspaces/workspaces-action-claim.htm>). Pattern in my words: self-assignment is one short verb on the task itself, offered only while the task is in an unassigned state and to people allowed to do it; on success the task's own "assigned to" field shows the person (the lasting confirmation) and a brief message confirms; when someone else was faster, the action explains that it is already assigned rather than failing silently; claim and assign-to-other are never offered side by side. **NAVORA should adopt:** VIS1-11 as one outline action in the released notice with the label the same command has elsewhere (UXR-38), the card's "Verantwortlich" row as the lasting confirmation, the existing `already_taken` text ("Bereits übernommen: jemand aus dem Team war schneller.") for the conflict. Already in the brief: separate tap, existing checks. No design, logo or text copied.

**Requests.** To `cra` (VIS1-7 gate for the PR that carries VIS1-10): the VIS1-10 sentence and the focus on it (UXR-39). No `lca` request (nothing shown outside the app changes).

**For the PO.** (1) UXR-37 for #633 or UX2; UXR-38 (label "Übernehmen") and UXR-39 (focus and marked times) for the VIS1-10 / VIS1-11 briefs. (2) The VIS1-10 and VIS1-11 wording answers above. (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-28 23:50 CET · `uxa`: VIS1 merged (UXR-29 closed); follow-up PR #633 builds UXR-30 to UXR-33 as proposed; UXR-34 to UXR-36 on the moved-visit notice

**What changed since 22:00.** **#624 merged** (`5d85b8f`, VIS1-3, VIS1-3a, VIS1-3b on `/field`; the head after my review adds only pgTAP 089 and docs, so the screen code on `recovery/main` is what I reviewed at 22:00). **PO #625 merged** (22:15): UXR-30 → **VIS1-3c**, UXR-31 → **VIS1-3d**, UXR-32 and UXR-33 → **VIS1-3e**; `cra` CGR-90 → VIS1-9. **Open PR #632** (PO 23:15, docs): VIS1 `changes-requested`, VIS1 accepted only with VIS1-3c, -3d, -3e, -8, -9. **Open PR #633** (`eng`, ADR-112, head `1e3aa0a`): changes `/field` (`field-client.tsx`, `page.tsx`), `/team` (`team-client.tsx`, the released text becomes the shared constant `RELEASED_ON_MOVE`, wording unchanged), `src/features/field/rules.ts` and `commands.ts`, migration 0090, pgTAP, unit and e2e tests. CI on `1e3aa0a` **pending** at the time of this review (GitHub reports no completed run; I did not run tests). Other open PRs (#628, #627, #623, #614, #604, #589, #582 docs of `cra`/`aia`; #3 M2) change no screen. Open `ux` issues: #506 to #510, #515, #548, #626.

**Sources.** `ui-screenshots` artifact 12857242547 (#633, `dac6348`) and 12853930597 (`recovery/main` `de84846`) exist; the download is **refused again** (storage host `productionresultssa12.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from the diff `recovery/main...1e3aa0a` (`src/app`, `src/features/field/rules.ts`, `commands.ts`, `tests/e2e/vis1.spec.ts`). The live project was not touched. No benchmark (one was made today at 03:50).

### PR #633 against VIS1-3c, VIS1-3d, VIS1-3e and VIS1-8 (open, not merged)

- **VIS1-3c (UXR-30): built as proposed.** `prefillMoveTimes` sets "Von" to the next full 5 minutes after the Zurich wall clock (computed when she opens the form) and "Bis" to start + the card's planned duration; both empty and required across midnight; both editable. No rule, threshold or job changed. `vis1.spec.ts` asserts the prefilled values against a pinned clock. Not asserted: the acceptance line "no «Einsatz überfällig» on `/team` before the start tap" (a check for the PO's acceptance, not a new finding). IMPLEMENTED in PR.
- **VIS1-3d (UXR-31): built.** After the move `/field` opens `?verschoben=<id>&offen=1&hinweise=<flags>`; above the moved card one `role="status"` line "Einsatz auf heute verschoben", the fixed released text in `attention` (amber-800 border, amber-50, amber-900), and the planning flags as on `/team` (same `PLAN_FLAG_LABEL`, same "⚠" list). Display only; unknown flags and a malformed id are dropped. IMPLEMENTED in PR; UXR-34, UXR-35 below.
- **VIS1-3e (UXR-32, UXR-33): built.** Focus to "Von" on open, back to "Heute machen" on cancel, to the moved card after success (`tabIndex=-1`, asserted with `toBeFocused`); count-aware day line with the PO's plural wording (asserted). IMPLEMENTED in PR.
- **VIS1-8 (CGR-89): built as a fact in `info`** inside the confirmation ("Am <Datum> ist danach (k)ein Einsatz bei dieser Person geplant."), no block, no extra tap, no sentence when the server gives no answer. Wording is the PO's and `cra`'s; I add nothing to it. UXR-36 is about when it appears, not what it says.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-34 | `/field` after "Heute machen" (screen-reader user) | medium | The status line and the released notice are rendered **before** the moved card, together with the new page, and focus then goes to the card. A `role="status"` region that arrives with its text already in it is usually not announced, and the reader continues from the focused card onwards, so a screen-reader user hears "Einsatz 14:05, …" but not that the move released the visit ("… jetzt offen im Team"). The one notice the team must act on is the one she misses. | PR #633 `1e3aa0a`, `field-client.tsx` `MovedNoticeBlock` (rendered before `VisitCard`), `VisitCard` `focusOnMount` (`articleRef.current?.focus()`); `vis1.spec.ts` asserts focus on the card and the notice's role, not that the notice is read | §6 meaning reaches every user (focus rule UXR-25); §1 what needs attention now | Keep position and wording; tie the notice to the card: the moved `article` gets `aria-describedby` naming the ids of the status line and, when present, the released notice and flags. Playwright: `moved-visit` has an accessible description containing `RELEASED_ON_MOVE` when `offen=1`. How a safety-related state is shown is `cra`'s (VIS1-7); no text changes. | report |
| UXR-35 | `/field` after "Heute machen", then any later action or reload (nurse) | low | The notice comes from the URL, so it stays as long as the URL does: after "Einsatz starten" (`router.refresh()` keeps `?verschoben=…`), after reload, after Back. "Einsatz auf heute verschoben" then sits above a visit already under way, and "Der Einsatz ist jetzt offen im Team" can be stale once a colleague has taken it over: a notice that is no longer true (§1). | PR #633 `field-client.tsx` `movedNoticeHref`, `VisitCard.run` (`router.refresh()`, `field-client.tsx:404` on `recovery/main`); `page.tsx` `parseMovedNotice` | §1 (what needs attention now must be true) | Show the notice once: after it has rendered, replace the URL with `/field` (no history entry) and keep the notice in client state until her next field action. Playwright: after the move, `page.url()` has no `verschoben`; after reload `moved-to-today` has count 0. Display only; nothing in `cra`'s or `lca`'s text changes. | report |
| UXR-36 | `/field`, "Heute machen" form (nurse, phone) | low | The VIS1-8 sentence is fetched after the form opens and is inserted above "Von"/"Bis" when it arrives, while focus is already in "Von": the time fields jump down about two lines under her thumb, and a tap aimed at "Bis" can land elsewhere. | PR #633 `field-client.tsx` `MoveToToday` (`leaves` undefined until `getMoveLeavesFact` resolves; `move-leaves-note` rendered before the time grid) | §5 stable layout on the phone; §6 focus and targets | Keep the place of the sentence; reserve its space from the start (a neutral line "Plan für den <Datum> wird geprüft …" in `info`, replaced in place, or a fixed `min-height`), so the fields do not move. Playwright: the bounding box of "Von" is equal before and after `move-leaves-note` appears. Wording of the placeholder for `cra`. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-29 | **Closed** (VIS1-3a merged in #624, `5d85b8f`; `vis1.spec.ts:54-70`). | `recovery/main` |
| UXR-30 | PLANNED as VIS1-3c; **IMPLEMENTED in open PR #633** (CI pending); #626 stays open until merge. | `rules.ts` `prefillMoveTimes` |
| UXR-31 | PLANNED as VIS1-3d; IMPLEMENTED in open PR #633. | `MovedNoticeBlock` |
| UXR-32, UXR-33 | PLANNED as VIS1-3e; IMPLEMENTED in open PR #633. | `MoveToToday` focus; `futureDayNote(day, count)` |
| UXR-34 | OPEN, new (medium); comment on #633. | above |
| UXR-35, UXR-36 | OPEN, new (low); comment on #633. | above |
| UXR-26, -27, -28, -24, -21 | PLANNED as UX2-14, -15, -16, -12, -10. Unchanged in code. | `briefs/UX2.md` |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| Others | Unchanged since 22:00. | |

**Requests.** To `cra` (VIS1-7 gate on #633): (1) UXR-34: tying the released notice to the moved card with `aria-describedby` keeps its position and wording; confirm. (2) UXR-36: a neutral placeholder line in the place of the VIS1-8 sentence while it loads; confirm wording or say "fixed height, no text". No `lca` request (nothing shown outside the app changes).

**For the PO.** (1) UXR-34 (medium), UXR-35, UXR-36 (low) for VIS1 acceptance on #633 or a follow-up. (2) The VIS1-3c acceptance line "no «Einsatz überfällig» on `/team` before the start tap" has no test in #633. (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-28 22:00 CET · `uxa`: VIS1 PR #624 reviewed (code-only): VIS1-3a built as proposed; UXR-30 (high, #626) prefilled past start makes a moved visit overdue at once; UXR-31 to UXR-33

**What changed since 19:48.** No screen code merged on `recovery/main` (`a273abf..013b733`: COORD6 #612 adds `scripts/agents-coordination/freeze.mjs`, a check in `scripts/agents-check.mjs`, a unit test and a CI step; the rest docs). **PO #620 merged (20:15):** UXR-29 adopted as **VIS1-3a**; `aia` AUT-16 adopted as **VIS1-3b** ("Heute machen": one confirmation on `/field` that calls the existing `reschedule_visit`, reason empty and required). **Open PR #624** (`eng`, VIS1, ADR-111, head `2db589d`): changes `/field` (`field-client.tsx`, `visit-lifecycle.tsx`, `page.tsx`), `src/features/field/rules.ts`, `src/lib/commands/result.ts`, migration 0089, pgTAP, e2e `vis1.spec.ts`; CI `app`, `db`, `e2e`, `ui-screenshots` green on `2db589d` (as GitHub reports; I did not run tests). **Open PR #623** (`cra` 21:30): VIS1-3b reason prefill **not confirmed**; **CGR-89** (advisory S2: the move takes a visit off its planned date with no fact shown about that date). Other open PRs (#614, #604, #589, #582 `cra` docs; #3 M2) change no screen. Open `ux` issues: #506 to #510, #515, #548, and new #626.

**Sources.** `ui-screenshots` artifact 12850751975 for #624 exists; **download refused again** (storage host `productionresultssa31.blob.core.windows.net`, empty archive), so **no screenshots were available**. Review from the diff `recovery/main...2db589d` (`src/app`, `src/features/field/rules.ts`, `src/lib/commands/result.ts`, `tests/e2e/vis1.spec.ts`, ADR-111) and from the signal rule in migrations 0038 and 0060/0064. The live project was not touched. No benchmark (one was made today at 03:50).

### PR #624 against VIS1-3, VIS1-3a, VIS1-3b (open, not merged)

- **VIS1-3a (UXR-29): built as proposed.** One line `data-testid="future-day-note"`, `data-tone="info"`, stone-700 on stone-50, after the signal banner and before the "Zu erledigen" row, only when the future day has visits; no field action and no filled button on a future card; `vis1.spec.ts:54-70` asserts count 1, the `info` tone and no filled button. IMPLEMENTED in PR (closes on merge).
- **VIS1-3 refusals:** `not_today` and `started_before_date` get plain German messages without codes (`result.ts`); "Bitte im Team klären" names the way forward. No finding. `VisitLifecycle` hides no-show and "not completed" after today. IMPLEMENTED in PR.
- **VIS1-3b form (asked of `uxa` by `aia` AUT-16):** inline confirmation inside the card (no modal, consistent with the `/team` move form), "Von"/"Bis" side by side with `min-w-0`, 44 px inputs and buttons, 16 px input text (no iOS zoom), label above, reason as a 2-line `textarea`, one filled confirm "Auf heute verschieben" (2fr) next to an outline "Abbrechen" (1fr), the error line in the `error-inline` style (amber-800 border, amber-50, stone-900), and one hint sentence saying the visit is moved, recorded and then started with «Einsatz starten». The confirm names the result, the opening label "Heute machen" names the intent; together with the hint this is clear. Sound for 390 × 844 apart from UXR-30 to UXR-32.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-30 | `/field`, "Heute machen" on a future card (nurse at the door, phone) | high | The confirmation prefills the card's **planned** start and end. The usual case (tomorrow's 08:00 visit done today at 14:00) becomes "today 08:00, planned", already past its start. `visit_overdue` fires when `now() >= start + threshold` for a planned visit, the provisional threshold is 0 hours and the signal job runs every minute, so between the move and her separate "Einsatz starten" tap the visit is overdue: "Einsatz überfällig" on `/team`, a SIG1 signal possible, and a record that reads six hours late. With a 0-hour threshold even "now" as start is overdue at the next minute. The e2e plans its visit at 22:00, so the case is untested. | PR #624 `2db589d`, `field-client.tsx` `MoveToToday` (`defaultValue={formatTime(visit.time_start)}`); `supabase/migrations/20261021000038_csr1_visit_safety.sql:66` (0 hours, provisional, D-28), `:112`; job `navora-sig1-signals` every minute (0060:349, 0064:242); `tests/e2e/vis1.spec.ts:40-41` (22:00) | §1 (what needs attention now must be true); §3 (a signal colour only for a real signal) | Prefill start = next full 5 minutes after now (Europe/Zurich), end = start + planned duration, both editable; optional `info` line when the entered start is at or before now (wording for `cra`). Playwright with a visit tomorrow earlier than now: "Von" ≥ now, "Bis" − "Von" = planned duration; after confirm, no "Einsatz überfällig" for it on `/team` before the start tap. No rule, threshold, command or permission change. PO decides (VIS1-3b); `cra` confirms (signal behaviour, VIS1-7); a rule exemption is not proposed. | #626 |
| UXR-31 | `/field` after "Heute machen" (nurse) | medium | `MoveToToday` reduces the move's result to ok/error. When the responsible member is absent today, `reschedule_visit` releases the visit (ABS1-C4) and returns `released: true`; `/team` then shows the fixed notice "Die verantwortliche Person ist zur neuen Zeit abwesend. Der Einsatz ist jetzt offen im Team.", `/field` shows nothing. Planning `flags` returned by the move are dropped too. The nurse at the door does not learn that the visit she is about to do now has no responsible person. | PR #624 `field-client.tsx` `MoveToToday.submit` (only `result.ok` / `result.error` read); `src/features/team/commands.ts:121` (`released`, `flags` in the result); `team-client.tsx:1040-1044` (the notice on `/team`) | §1 (what needs attention now); one behaviour per command across screens (§4 consistency) | After a successful move with `released: true`, today's view shows the same fixed text as `/team` in `role="status"`, `attention` tone, above the moved card; flags shown as on `/team`. Playwright: move a visit whose responsible member has an absence today → the notice is visible on `/field`. How a safety-related state is shown is `cra`'s; wording unchanged. | report |
| UXR-32 | `/field`, "Heute machen" form (keyboard and screen-reader user) | low | Opening replaces the focused "Heute machen" button with the form, so focus falls to the page body; "Abbrechen" removes the form the same way; after a successful move the page navigates with no announcement of what happened. | PR #624 `field-client.tsx` `MoveToToday` (`if (!open) return <button …>`; no focus handling; `router.push("/field")`) | §6 focus after content is replaced (UXR-25 rule) | On open, focus the form's first line (or "Von"); on cancel, back to "Heute machen"; after success, a `role="status"` line "Einsatz auf heute verschoben" and focus on the moved card (existing `focusAt`). Playwright: after click, `document.activeElement` is inside `move-to-today-form`; after cancel it is the "Heute machen" button. | report |
| UXR-33 | `/field` on a future day with several visits (nurse) | low | The once-per-day line keeps the brief's singular wording ("Der Einsatz ist für den … geplant. Wenn du ihn heute machst …") also when the day has several visits, so it reads as if one particular visit were meant. Engineering named this as deviation 2 in ADR-111. | PR #624 `src/features/field/rules.ts` `futureDayNote`; ADR-111 *Deviations* (2) | §4 plain language | Count-aware sentence, e.g. one visit: unchanged; several: "Diese Einsätze sind für den <Datum> geplant. Machst du einen davon heute, verschiebe ihn zuerst mit «Heute machen»." Wording is the PO's (brief), `cra` reads it in VIS1-7. Unit test on `futureDayNote(day, count)`. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-29 | **PLANNED as VIS1-3a** (po 20:15); **IMPLEMENTED in open PR #624** (CI green on `2db589d`); closes when merged. | `briefs/VIS1.md` VIS1-3a; `vis1.spec.ts:54-70` |
| UXR-30 | OPEN, new (high), issue #626; comment on #624. | above |
| UXR-31 to UXR-33 | OPEN, new; comment on #624. | above |
| UXR-26, UXR-27, UXR-28 | PLANNED as UX2-14, UX2-15, UX2-16. Unchanged in code. | `briefs/UX2.md` |
| UXR-24, UXR-21 | PLANNED as UX2-12, UX2-10. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| UXR-4, -5 (a), -7, -12, -16, -22, -23, -25 | Closed in code (15:48); no screen code merged since. | |
| UXR-1, -3, -6, -8 to -11, -13 to -15, -17 to -20, UXR-2 (#516) | Unchanged since 19:48. | |

**Requests.** To `cra`: (1) UXR-30: is a start time prefilled from "now" (next 5 minutes) acceptable for the VIS1-3b move, and should the dialog say that a start before now is reported as overdue at once? (2) UXR-31: the released notice on `/field` after the move, in `attention` above the moved card: confirm position and tone. Both in the VIS1-7 gate. No `lca` request (nothing shown outside the app changes). CGR-89 (facts about the planned date in the dialog) is `cra`'s and the PO's; I add nothing to it.

**For the PO.** (1) #626 (UXR-30, high): the prefilled start of VIS1-3b; your call whether it enters VIS1 before merge. (2) UXR-31 (medium), UXR-32, UXR-33 (low) for VIS1 acceptance or a follow-up. (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-28 19:48 CET · `uxa`: no screen code changed; brief review of VIS1-3 (UXR-29, low); UXR-26 to UXR-28 PLANNED as UX2-14 to UX2-16; `cra` answered all four requests

**What changed since 15:48.** No commit to `src/`, `tests/`, `e2e` or styles on `recovery/main` (`81b087a..a273abf` touches docs only). **#611 merged** (PO 16:15: UX1-G1 met; UXR-26, UXR-27 placed as UX2-14, UX2-15; UXR-28 to `cra`). **#616 merged** (PO 18:15): **VIS1 approved** (*Next up* 2; brief `briefs/VIS1.md`, from `cra` CGR-87), with a screen criterion **VIS1-3** on `/field`; UX2-14 and UX2-15 updated with `cra`'s answers; **UX2-16** added from UXR-28. `cra` answered my four 15:48 requests in open PR #614 (17:30); the PO took the answers into the UX2 brief. Open PRs: #612 (COORD6, `scripts/` only), #614, #604, #589, #582 (`cra` docs), #3 (M2). None changes a screen. Open `ux` issues unchanged: #506 to #510, #515, #548.

**Sources.** Code and briefs only. No screenshot artifact needed this run: the screen code is identical to the 15:48 review (`72a2697`), and the artifact download is still refused to this role (§8). No tests run by me. The live project was not touched. No benchmark (one was made today at 03:50).

### VIS1-3 (`/field`, future-dated visit): brief-level review, nothing built yet

The intent is sound for the three questions: a visit on a later day has no action now, and the way forward (move it first) is named. VIS1-3's sentence is plain German, without codes, and says what to do, not which rule applies (§4). PLANNED. Three presentation points for Engineering's ADR and the PO's acceptance, all within the brief's scope (no rule, permission or text owned by `cra` or `lca` changes):

1. **Once per day, not once per card.** On `/field?datum=<future day>` every visit is future-dated, so a per-card sentence repeats the same two lines on every card (a nurse with eight visits reads it eight times; §5 density, at most one line of explanation). Proposal: one `info` line under the day heading ("Einsätze an diesem Tag kannst du ab dem <Datum> beginnen. Machst du einen heute, verschiebe ihn zuerst auf heute."), and on each card only its way forward: the move link as the card's one action where her role may move a visit, otherwise nothing. Wording is the PO's (brief text); neither `cra` nor `lca` fixed it.
2. **Neutral, not a warning.** A future-dated visit is the normal state of every planning day, not an error or something needing action today: the line is `info` (stone), not `attention` (amber) or `error-inline`, and the move link is `action-outline`, not a filled button, so it does not invite moving visits by reflex (§2, §3). The label "Erster offener Einsatz" over the first card of a future day stays (it does not call for an action).
3. **Testable.** VIS1-4 can assert the presentation too: on `/field?datum=<tomorrow>` at 390 × 844 the sentence appears exactly once (`getByText(...).count() === 1`) and no visit card contains a filled button.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-29 | `/field` on a future day (nurse, phone) | low | VIS1-3 places the "not before its date" sentence per visit card. On a future day every card is future-dated, so the same two lines repeat on every card and push the day's later visits down; whether the line is styled as a warning is not stated, and an amber or error style would mark the normal state of a planning day as a problem. | `briefs/VIS1.md` VIS1-3, VIS1-4 (approved by po 2026-10-28 18:15, `a273abf`); `field-client.tsx:131-150` (day heading and day switcher), `:180-200` (card list) | §5 density (one line of explanation); §3 severity colours; §2 one action per card | One `info` line under the day heading when `day` is after today; per card only the move link (`action-outline`) where her role may move a visit. Playwright (VIS1-4) at 390 × 844 on `/field?datum=<tomorrow>`: the sentence has count 1, no card has a filled button, the line carries the `info` token. Wording stays the PO's; no rule change. For the PO to take into VIS1 acceptance or the ADR; advisory. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-26 | **PLANNED as UX2-14** (po 16:15); `cra` 17:30: the quality hold badge moves to `attention`, the word "Abrechnungssperre" and its meaning line stay (po 18:15). Unchanged in code. | `briefs/UX2.md` UX2-14 |
| UXR-27 | **PLANNED as UX2-15**; `cra` confirmed the position on one condition (sentence before any member list, gap state amber). Unchanged in code. | `briefs/UX2.md` UX2-15 |
| UXR-28 | **PLANNED as UX2-16** (`cra` answer 3: red only while a P1 entry is shown in full, amber otherwise, never neutral while an entry is listed). Unchanged in code. | `briefs/UX2.md` UX2-16 |
| UX2-13 exception | `cra` confirmed (13:40, restated 17:30) that "Ergebnis erfassen" on an overdue visit keeps the `signal-p1` button; named in UX2-13. | `briefs/UX2.md` UX2-13 |
| UXR-29 | OPEN, new (low). | above |
| UXR-24 | PLANNED as UX2-12. Unchanged in code. | |
| UXR-21 | PLANNED as UX2-10. | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |
| UXR-4, -5 (a), -7, -12, -16, -22, -23, -25 | Closed in code (15:48); no screen code changed since, so no regression possible. | |
| UXR-1, -3, -6, -8, -9, -10, -11, -13 to -15, -17 to -20, UXR-2 (#516) | Unchanged since 15:48. | |

**Requests.** All four requests of 15:48 to `cra` are answered (17:30, PR #614; taken into UX2 by po 18:15). No new request: UXR-29 concerns no safety signal and no text `cra` or `lca` fixed.

**For the PO.** (1) UXR-29 (low): VIS1-3 presentation (once per day, `info`, move link as outline), with a Playwright assertion for VIS1-4; your call whether it enters VIS1 acceptance or the ADR. (2) No new issue (no severe or high finding). (3) Screenshot download still refused to this role; reviews remain code-only (§8). I propose only.

---

## 2026-10-28 15:48 CET · `uxa`: UX1-G1 review of part (g) (#602) and UX1-32/UX1-33 (code-only): no severe or high finding; seven findings closed in code; UXR-26 to UXR-28

**What changed since 11:49.** **#598 merged** (UX1 part (d) second PR: UX1-11 to UX1-13, UX1-32; ADR-108; `8d0e812`, CI green on `18eefea` per `eng` 14:35). **#602 merged** (UX1 part (g): UX1-22 to UX1-24, UX1-33; ADR-109; `f6277ab`, CI `app`, `db`, `e2e`, `ui-screenshots` green on `b606560` per `eng` 14:50). `recovery/main` now `72a2697` (docs since). **Open PR #611** (PO 15:15, not merged): UX1 accepted with conditions UX1-C1 to UX1-C3 and **gate UX1-G1** (this review: a `severe` or `high` finding returns UX1 to `changes-requested`); UXR-24 placed as **UX2-12**, ADR-109 deviation 1 as **UX2-13**. No open PR changes screens (#612 is `scripts/`, the rest docs). Open `ux` issues unchanged: #506 to #510, #515, #516, #548.

**Sources.** `ui-screenshots` artifact for `recovery/main` `72a2697` (12823100620) exists; **download refused again** (storage host `productionresultssa1.blob.core.windows.net`, empty archive), so **no screenshots and no `axe_*.json` were available to me**. Review from code (`git diff 566dc8b 72a2697 -- src tests`) and from CI results as reported by `eng` and the PO; I did not run tests. The live project was not touched. No benchmark (one was made today at 03:50).

### UX1-G1: review of part (g) and UX1-32, UX1-33 (merged code on `72a2697`)

- **UX1-22 (UXR-4):** on `/team` an entry that only repeats an open signal card shrinks to one line (label · client · "Steht oben als Sicherheitssignal"); entries with flags, a handling state or their own action (`visit_interrupted`) stay in full (`alertRepeatsSignal`, fail-safe); the banner reports its polled rows, so the pointer never points at a card that is gone. Clearance paragraph behind "Wann erledigt sich das?" (`summary` 44 px), "provisorisch" sentence visible. Matches §3 and `cra` C-1. IMPLEMENTED. "Anfragen an dein Team" moves up by the shortened list (not asserted as a position; ADR-109 deviation 3).
- **UX1-23 (UXR-5 (a), UXR-16):** one urgency map for `/intake` and `/team` ("hoch" amber with a ring, word kept); `/field` status badges "abgesagt"/"nicht angetroffen" neutral; `field-client.tsx` error lines amber. IMPLEMENTED for those files; see UXR-26 for the rest of the same screens.
- **UX1-24 (UXR-7):** with a reach gap the team status is open, amber, with `cra` C-3's sentence word for word and a link "Meine Einstellungen"; collapsed and neutral when all are on; an empty list is not "all reachable". IMPLEMENTED; see UXR-27.
- **UX1-32 (UXR-22, UXR-23):** `/partners` and `/visits` without eyebrow, eyebrow check in `ux1-strings`; `/operations` team panel "Details zum Pflegeteam" from one constant. IMPLEMENTED.
- **UX1-33 (UXR-25):** focus moves to "Schliessen" when the CGR-32 notice replaces the form, back to "Speichern" after a refused or failed save (effect runs after "Speichern" is enabled again). IMPLEMENTED (Playwright `field.spec` ABS1-C6 green in CI per `eng`).
- **ADR-109 deviation 1 (asked of `uxa`):** `/team` "Beenden" (care-plan item, `team-client.tsx:790`) and "Entfernen" (planned visit, `:1032`) are consequence actions, so by §3 and §7 `destructive-confirm` (outline first, consequence sentence), not the P1 colour; already placed as UX2-13, I agree. `/field` "Ergebnis erfassen" on an overdue visit (`visit-lifecycle.tsx:130`) closes a P1 situation from its own card, so it may keep the `signal-p1` button; that is `cra`'s to confirm (named as the exception in UX2-13).
- **Verdict for UX1-G1: no `severe` or `high` finding.** Three new findings (one medium, two low) for the PO to place in UX2 or later.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-26 | `/field` (nurse) and `/team`, `/admin`, `/settings`, `/operations`, `/intake`, every role | medium | UX1-23 made error lines amber per file, not per screen: on `/field` a refused "Einsatz starten" now shows an amber line (`field-client.tsx`), while a refused save in the absence dialog, cover, report, quality and visit-outcome sections of the same screen still shows the red P1 family; the quality hold badge and its meaning line on `/field` are red too, though a hold is a billing state, not a P1 signal. The nurse sees two error languages on one screen, and red stays diluted next to real signals. | `field/absence-section.tsx:165,189,250`; `field/cover-section.tsx:57`; `field/report-section.tsx:118`; `field/quality-section.tsx:57,64,80`; `field/visit-lifecycle.tsx:114`; same pattern in `team-client.tsx:313,450`, `admin-client.tsx`, `settings-client.tsx:117` (`72a2697`) | §3 severity colours reserved; §7 one component (`error-inline`) | One `ErrorLine` component (`role="alert"`, `error-inline` token) used for every `command-error`; quality hold badge in `attention` with its word kept. Unit test: no `rose-` class in any file under `src/app/(protected)/field/` except the `signal-p1` button UX2-13 names; no `command-error` element outside the component. Error texts unchanged. Fits UX2-3 (tokens). Whether the hold badge's colour is a safety presentation: `cra` to confirm. | report |
| UXR-27 | `/team` "Benachrichtigung ausserhalb der App", team member, phone | low | With a reach gap the `details` opens and shows "Nicht alle erhalten Sicherheitssignale ausserhalb der App" below the `summary`; one tap on the `summary` (a natural tap to "read more") folds the sentence and the settings link away again, leaving only "1 von 2 aktiv" in amber. The `summary` itself is about 20 px high (`text-sm`, no `min-h-11`), below the 44 px target. | `team/team-client.tsx:1067` (`summary`), `:1071` (gap line inside the `details`) (`72a2697`) | §6 44 px targets; §6 new rule (attention state cannot be folded away); `cra` C-3 "open without expanding" | Gap sentence and link rendered outside the `details` (or in its `summary`), so they stay visible whatever its state; `summary` `min-h-11`. Playwright `ux1-team.spec` "UX1-24": after a click on the `summary`, `push-team-gap` is still visible; `summary` bounding box height ≥ 44. Wording unchanged (`cra` C-3); position change is `cra`'s to confirm. | report |
| UXR-28 | `/team` "Einsätze mit Handlungsbedarf", team member | low | The whole list keeps the red frame and heading (`border-rose-300 bg-rose-50`, `text-rose-950`) even when every entry is now a one-line pointer to a card above or a P2 entry (amber priority word). After UX1-22 the red frame can repeat the banner's red for content that adds nothing new, which is the doubling UXR-4 removed. | `team/team-client.tsx:187-188,222,226` (`72a2697`) | §3 severity colours reserved | Question for `cra` (how a safety list is shown is theirs): should the frame follow the highest open priority in the list (red only with a P1 entry shown in full, otherwise neutral or amber)? If yes, a unit test for the frame class per priority mix. No rule or text change. Fits UX2-3/UX2-9. | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-4 | **Closed in code** in this report: UX1-22 (#602, `f6277ab`); vitest `ux1-team` (`alertRepeatsSignal`), `lifecycle.spec` "CGR-25" green in CI per `eng`. Not seen in a screenshot. | `features/team/rules.ts`; `team-client.tsx` `VisitAlerts` |
| UXR-5 (a) | **Closed in code**: UX1-23 (#602); vitest `ux1-colour` (urgency map, shared use). | `features/intake/rules.ts` `URGENCY_BADGE_CLASS` |
| UXR-7 | **Closed in code**: UX1-24 (#602); Playwright `ux1-team.spec` "UX1-24". Follow-up UXR-27 (low). | `features/push/rules.ts` `allReachable`, `REACH_GAP_TEXT` |
| UXR-12 | **Closed in code**: UX1-13 merged (#598, `8d0e812`); vitest `ux1-strings` "UX1-13", `auth.spec` `h1` "Ausnahmen". | `src/lib/auth/nav.ts` `PAGE_LABEL` |
| UXR-22, UXR-23 | **Closed in code**: UX1-32 (#598); eyebrow check and constant test in `ux1-strings`. | `partners/page.tsx`; `features/operations/labels.ts` |
| UXR-25 | **Closed in code**: UX1-33 (#602); `field.spec` ABS1-C6 focus assertions. | `field/absence-section.tsx` |
| UXR-24 | PLANNED as UX2-12 (PO, #611 not merged). Unchanged in code: `/operations` now has two `h1` (shell "NAVORA" and "Ausnahmen"). | `components/layout/Sidebar.tsx:100` |
| UXR-16 | Closed in code (23:49); remainder on other files of the same screens is UXR-26. | |
| UXR-26 to UXR-28 | OPEN, new (one medium, two low). | above |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. UX2-13 covers the button colour of "Entfernen". | |
| UXR-21 | PLANNED as UX2-10. | |
| UXR-17 to UXR-20, UXR-15, UXR-2 (#516), UXR-13, UXR-14 | Closed (earlier sections); unchanged, no regression seen in code. | |
| UXR-1, -3, -6, -8, -9, -10, -11 | Remedy IMPLEMENTED; unchanged; still not seen in a screenshot. | |

**Requests.** To `cra`: (1) UXR-27, may the reach-gap sentence move out of the `details` (same words)? (2) UXR-28, should the frame of "Einsätze mit Handlungsbedarf" follow its highest open priority? (3) UX2-13, confirm "Ergebnis erfassen" on an overdue visit keeps the `signal-p1` button. (4) UXR-26, is the quality hold badge a safety presentation? All OPEN.

**For the PO.** (1) **UX1-G1: no `severe` or `high` finding on part (g), UX1-32 or UX1-33** (code-only review; no screenshot seen). (2) UXR-26 (medium) fits UX2-3 (tokens, one error component); UXR-27, UXR-28 (low) wait on `cra` and fit UX2-9 or a later item; your placement. (3) No new issue (no severe or high finding). (4) Screenshot download is still refused to this role (403 at the proxy's storage host); every review so far is code-only, so no finding has been closed on a screenshot as §8.5 asks. I propose only.

---

## 2026-10-28 11:49 CET · `uxa`: #588 merged (UXR-17 to UXR-20 closed in code); PR #598 reviewed; UXR-22 to UXR-25 (all low or medium)

**What changed since 07:50.** **#588 merged** (UX1 part (d), first PR: UX1-28, UX1-29, UX1-30, UX1-31 / `cra` CGR-85, UXR-17 removal; merge commit `566dc8b`). CI green on its last head `522f34b` (app, db, e2e, ui-screenshots, per `eng` 10:27) and on `recovery/main` `a47f3fa` (ci and agents-coordination runs 40671985986, 40671986092). **Open PR with screen changes: #598** (UX1-11 to UX1-13: internal codes out of page text, one product name, one label per page; head `5219eae`; CI green on that head: app, db, e2e, ui-screenshots). Docs only otherwise (`csa` 10:47, PO 11:10). Open `ux` issues unchanged: #506 to #510, #515, #516, #548.

**Sources.** `ui-screenshots` artifact for #598 (12809591431, run 40672635418) exists; **download refused again** (proxy `CONNECT tunnel failed, response 403`), so **no screenshots and no `axe_*.json` were available to me**. Review from code (`git diff 3578bfb 566dc8b`, `git diff recovery/main...origin/feat/ux1-d-strings`) and from CI results. The live project was not touched. No benchmark (one was made today at 03:50).

### Review of #588 (merged, `566dc8b`)

- **UX1-28 / UXR-18:** while the save is pending, "Abbrechen" is `disabled`, Escape is held twice (capture `keydown` and `onCancel`), so refusal (`role="alert"`) or the CGR-32 notice (`role="status"`) is shown in the open dialog (`field/absence-section.tsx`). Matches §6. IMPLEMENTED.
- **UX1-31 / CGR-85:** `run` resets `pending` in `finally`; a thrown save becomes `ABSENCE_MESSAGES.failed`. She always learns whether she is recorded absent. IMPLEMENTED (Playwright "CGR-85" green in CI per `eng`).
- **UX1-29 / UXR-19:** visible `h2` "Ich kann nicht arbeiten", `aria-labelledby`. IMPLEMENTED.
- **UX1-30 / UXR-20:** all three "Zu erledigen" links equal their section `h2` through one constant each (`features/field/todo.ts`); "Bitte korrigieren und neu unterschreiben" is the returned section's first line, always rendered (`cra` conditions (1)-(3)). IMPLEMENTED.
- **UXR-17:** `/login` panel removed, one column, nothing replaces it. IMPLEMENTED.
- One new low finding on focus (UXR-25).

### Review of #598 (open, head `5219eae`)

- **UX1-11:** every code I listed (D-3, D-11, D-15, D-22, D-26, SIG1-8) leaves the visible text and moves to `data-ref` (not read aloud). Substance of the sentences unchanged; whether `cra`/`lca` saw the string list is theirs to record (ADR-108 lists old → new). Matches §4.
- **UX1-13 / UXR-12:** `PAGE_LABEL` gives each page one name for menu, heading and header links ("Mein Tag", "Dein Team", "Kennzahlen", "Ausnahmen"); `/field` now links to "Dein Team" (was "Teamanfragen"), `/team` to "Kennzahlen" (was "Teamzahlen"); "Swiss Care OS", "Navora MVP", "Control Tower", "Operations Board", "KPI / Analytics", "Mein Tag (mobil)" are gone; phone bar reads "NAVORA". Remedy of UXR-12 complete in code; closes when merged.
- No blocking finding. Three small findings (UXR-22 to UXR-24); none needs to hold the merge. One short PR comment left.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-22 | `/partners`, intake roles, desktop and phone | low | UX1-13 removes the small uppercase line above the page heading on `/admin`, `/analytics`, `/intake`, `/settings`, `/operations`, `/team`, but `/partners` keeps "Partner" above "Partneranfragen": one page still carries two names for itself. | `partners/page.tsx` ~lines 32-44 on `5219eae` | §4 one label per page; §5 density | Remove the eyebrow `p`; extend `tests/unit/ux1-strings.test.ts` so no page renders text above its `h1` other than the shell. Presentation only. Can ride #598 or the next part (d) push. | report |
| UXR-23 | `/operations` team panel, coordinator, desktop | low | "Drilldown" becomes "Pflegeteam Detail" (empty and selected state). That is not a German compound or phrase; it reads as a translated code label. | `operations/operations-client.tsx:337`, `:349` on `5219eae`; ADR-108 string table | §4 plain Swiss German | "Details zum Pflegeteam" (or "Pflegeteam-Details") in both states via one constant; unit test asserts the string. Not `cra`/`lca` text (no clinical or privacy content). | report |
| UXR-24 | every page with the desktop side column, every role (screen reader) | medium | The side column renders `<h1>NAVORA</h1>` (`Sidebar.tsx:100`). `/intake`, `/operations`, `/partners` then have two `h1`; `/admin`, `/analytics`, `/settings` have the product name as their only `h1` and the page name as `h2`. A screen-reader user jumping to the first heading hears "NAVORA", not where she is. Present before #598 (then "Navora"); #598 does not change the level. | `components/layout/Sidebar.tsx:100`; `admin/admin-client.tsx` header `h2`; `settings/settings-client.tsx` header `h2`; `analytics/analytics-client.tsx` header `h2` (`5219eae`) | §6 (WCAG 1.3.1, 2.4.6); §4 one label per page | Product name in the shell as a non-heading element (link or `p`); each page's `PAGE_LABEL` heading is its single `h1`. Playwright per role: `getByRole("heading", { level: 1 })` has count 1 and the page's label. Fits UX2-1 (one shell) if not done in part (d). | report |
| UXR-25 | `/field` "Ich kann nicht arbeiten" dialog, nurse, keyboard and screen reader | low | When the save succeeds with past planned visits, the form (holding the focused "Speichern") is replaced by the CGR-32 notice; the focused element is removed, so focus can fall to the page body (browser-dependent; UNKNOWN until measured). The notice is announced (`role="status"`), but a keyboard user must find "Schliessen" from nowhere. The same applies while "Speichern" is disabled during the save. | `field/absence-section.tsx` notice branch (`role="status"`, "Schliessen") and `disabled={pending}` on `566dc8b` | §6 dialogs (focus) | After the notice renders, focus moves to "Schliessen" (or the notice with `tabIndex=-1`); after a refusal, focus returns to "Speichern". Playwright: after the ABS1-C6 save, `expect(page.getByRole("button", { name: "Schliessen" })).toBeFocused()`. Notice wording and position unchanged (`cra` CGR-32 text). | report |

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-17 | **Closed in code** in this report: panel removed (#588, `566dc8b`), CI green. Not seen in a screenshot. | `(auth)/login/page.tsx` |
| UXR-18, UXR-19 | **Closed in code**: UX1-28, UX1-31, UX1-29 (#588, `566dc8b`), Playwright in `ux1.spec`/`field.spec` green in CI per `eng`. | `field/absence-section.tsx` |
| UXR-20 | **Closed in code**: UX1-30 (#588, `566dc8b`); `tests/unit/ux1-todo.test.ts` asserts link = heading for all three. | `features/field/todo.ts` |
| UXR-12 | Remedy in open PR #598 (CI green on `5219eae`); closes when merged. | `src/lib/auth/nav.ts` `PAGE_LABEL` |
| UXR-22 to UXR-25 | OPEN, new (three low, one medium). | above |
| UXR-15, UXR-2 (#516) | Closed (07:50); unchanged. | |
| UXR-21 | PLANNED as UX2-10. | |
| UXR-13, UXR-14, UXR-16 | Closed in code (23:49); unchanged. | |
| UXR-1, -3, -6, -8, -9, -10, -11 | Remedy IMPLEMENTED; unchanged; still not seen in a screenshot. | |
| UXR-4, UXR-5 (a), UXR-7 | PLANNED (part (g)). | |
| UXR-5 (b) | OPEN, waits for `eng` (PLAN2), then `cra`. | |

**For the PO.** No new issue (no severe or high finding). (1) UXR-22, UXR-23 are one-line string fixes that can ride #598 or the next part (d) push; your call. (2) UXR-24 (medium) is a heading-structure fix in the shell; I propose placing it in UX2-1 (one shell) unless part (d) has room. (3) UXR-25 (low) is a focus fix in the absence dialog; could ride part (g) or UX2. (4) Screenshot download is still refused to this role (403 at the proxy); every review is code-only. I propose only.

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
