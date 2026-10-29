# UX Review Report

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *UX review*. **Reference:** [`../../design/DESIGN_SYSTEM.md`](../../design/DESIGN_SYSTEM.md).

Newest dated section first; never edit an earlier section, correct it in a new one. Each finding: `UXR-<n>` | screen and role | severity (`severe`, `high`, `medium`, `low`) | finding | evidence (CI screenshot artifact and commit, file:line) | principle broken (design system §) | testable remedy | issue.

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
