# Proposal: ward and shift screens for the simulated nursing-home ward (NH-A1, NH-A3, NH-A4)

**Author:** UX/UI Design Architect (`uxa`) · **Date:** 2026-11-07 12:10 CET · **Status:** **PROPOSED**, for the PO's review. This is not a brief, and it does not approve, order or change one. The PO decides whether to use it in the NH-A briefs (due 2026-11-27, `uxa` gate); `eng` decides how to build it.
**Why now:** the owner said on 2026-11-07: where the Blueprint and the founder say nothing, `uxa` works out solutions proactively and hands them to the PO for review. The ward screens are such a gap: the Blueprint (M9.0a, CGR-142 conditions) names the NH-A briefs, and `DESIGN_SYSTEM.md` §5 has an OPEN rule for ward screens, but there is no screen in `NAVORA_SCREEN_CATALOG.md` and no brief yet.
**Limits:** presentation only. This proposal invents no clinical rule, staffing level, skill mix, care-need level, instrument, tariff or legal role. Each of these is marked **UNKNOWN**, with the role that must answer it. Data is the synthetic seed only (Phase A, FE-031). No client or staff data goes to an AI service (D-35 rule A).

---

## 1. What exists and is reused (IMPLEMENTED in home care)

| Home-care pattern | Where | Reused on the ward as |
|---|---|---|
| One shell, tokens, `SignalCard`, `VisitCard`, `Section`, `JumpRow`, `Notice`, `EmptyState` | A-03, `DESIGN_SYSTEM.md` §2, §3, §7 | the same components; no second design language (§5 ward rule) |
| The three questions per day (Jetzt / Als Nächstes / Später) | C-01 `/field` | the same three questions **per shift** |
| Handover "Seit deinem letzten Einsatz" (HAND1) | C-05 | "Seit deiner letzten Schicht" per resident (NH-A3) |
| "Ich kann nicht arbeiten", "Offen im Team", "Übernehmen" (ABS1) | C-06, C-07 | the same dialog and commands for a shift (NH-A4); a different command keeps its own label (§4 *one command, one label*) |
| Refusal texts from one label function (QUAL1-21) | `features/qualification/refusals.ts` | the same texts; only subject and context change (UXR-134, UXR-138) |

## 2. Proposed screens

Route names and German labels are PROPOSED. The PO decides them, and `cra` confirms every word that names care or a person's role.

### N-01 Meine Schicht · PROPOSED route `/field` with a shift view (no new tab)
- **User:** a ward team member, on a phone (390 × 844) or a ward tablet.
- **Why on `/field`:** the nurse keeps one "Heute" place, whether she works visits or shifts. A member who works in both settings sees her visits and her shift in one list ordered by time. One tab means no second app to learn (pilot adoption).
- **Layout (top to bottom, §1):**
  1. Header: h1 "Heute", then one line naming the shift and its times, e.g. "Frühdienst · 07:00–15:30 · Wohnbereich 2". Shift names and times come from the organisation's data and are never written into code (**UNKNOWN** per organisation, NH-A1). A synthetic banner is shown as in QUAL1 ("Simulation · synthetische Daten").
  2. **Jetzt:** her P1 signals (`SignalCard`, content and order owned by `cra`), then the line **"Nicht überwacht auf dem Wohnbereich (n)"**. That line links to the list of reused controls that have no trigger on the ward (CGR-142 (1)). It is never shown as empty or green, and it is never hidden because the count is high.
  3. **Als Nächstes:** the next care task in her shift, as one card with one primary action. **UNKNOWN (NH-A1, `po` with `cra`):** whether ward care is planned as timed tasks per resident (one card per task) or as residents assigned to her for the shift (one card per resident with that resident's open items). The layout works for both; the brief must choose.
  4. **Später:** the rest of her shift, collapsed. Below it: "Andere Schichten heute" (closed `details`), each shift named with its times; then "Offen im Team (n)".
- **Primary action:** with a P1 signal, the signal's own action. Otherwise, the next card's action.
- **Testable:** Playwright at 390 × 844 on the synthetic ward seed. The shift line is the first text after the h1. With no P1 signal, the next card's primary button is inside the first viewport. "Nicht überwacht" shows its count and is not styled as success (`data-tone` ≠ `ok`). "Andere Schichten heute" is closed by default.

### N-02 Schichtplan Wohnbereich · PROPOSED route `/team/schichten?datum=…`
- **User:** the member who coordinates the ward team (self-organised; no head-of-unit role is assumed, FE-040 (4) role model **UNKNOWN**).
- **Question (1) first:** **"In dieser Schicht noch ohne Zuständige (n)"**: residents, or tasks, with nobody responsible in the current or next shift, each with one action "Zuständige wählen". The picker lists only members the QUAL1 check confirms, and every refusal comes from the shared label function.
- **Then:** one row per shift of the day (Früh / Spät / Nacht as defined by the organisation). Each row shows the planned members by display name and a **count of planned members only**. **No target, minimum or "unterbesetzt" judgement** while staffing per shift and skill mix are **UNKNOWN** (`cra`, `lca`, Clinical Owner D-43). A shift with nobody planned reads "Noch niemand geplant", never red unless a `cra` rule says so.
- **Desktop (≥ 1024 px):** a shifts × days grid (seven days). Each cell shows the count and names. A cell with an uncovered resident or task carries the text "ohne Zuständige", never colour only (§6).
- **Testable:** a shift with zero planned members shows "Noch niemand geplant" and no "unterbesetzt". The uncovered list is above the shift rows in DOM order. The grid has row and column headers (`th scope`). It is reachable by keyboard. The 44 px targets keep it usable at 390 px by switching to the list.

### N-03 Schichtübergabe · in N-01 (NH-A3, HAND1 reuse)
- On each resident's card: `details` "Seit deiner letzten Schicht (n)", open when n ≥ 1. Entries keep the HAND1 order and the author line ("von <Name>", UX2-27).
- At the start of a shift, one `JumpRow` line: "Übergabe: n Bewohnende mit neuen Einträgen". It jumps to the first such card. Nothing is "applied" by reading.
- **UNKNOWN (`cra`):** whether a handover must be confirmed as read, by whom, and whether a verbal handover is recorded. No confirm button is designed until `cra` answers; a confirm button would read as an attestation (§2 *an attesting act follows what it attests*).
- **Testable:** with two residents changed since her last shift, the line says "2 Bewohnende" and focus moves to the first card. No button labelled "bestätigen" in the handover.

### N-04 Ausfall in der Schicht · dialog on N-01 (NH-A4, ABS1 reuse)
- "Ich kann nicht arbeiten" is unchanged (same dialog, same command). The result names the shift: "Deine Schicht Spätdienst 15:00–23:30 ist jetzt offen im Team."
- An open shift appears in "Offen im Team" as one row ("Spätdienst · 15:00–23:30 · Wohnbereich 2 · Übernehmen"), with the same "Übernehmen" label.
- **UNKNOWN (NH-A4, `po`):** whether a shift is taken whole or per resident or task. **UNKNOWN (`lca`):** working-time rules across shifts (rest periods). Until `lca` names them, the screen shows no refusal for a rest-period breach; a rule the system does not check is not implied.
- **Testable:** after an absence for one shift, the team's "Offen im Team" shows exactly one row for it, with the shift name and times. The take refusal texts come from `refusals.ts` (Vitest).

### N-05 Bewohnerin / Bewohner · PROPOSED `/visits/[id]` pattern for a resident (NH-A2)
- This reuses the record page pattern (C-13): name, ward and room as recorded, the care plan items as entered, and observations with authors.
- **No score, level, alert or traffic light** derived from resident data (CGR-142 (4)). The care-need level (NH-A5) shows only as a recorded fact with author, source and date ("Pflegestufe erfasst: <Wert> · von <Name> · Quelle … · <Datum> · nur Schattenbetrieb"). It is never computed. An upward change shows its author and the second person's review, or "Zweite Prüfung offen".
- **Testable:** the record page contains no element with a `data-score` or colour-only level badge. A care-need entry without a second review shows "Zweite Prüfung offen".

## 3. Shared rules for every ward screen (proposed additions to `DESIGN_SYSTEM.md` §5, OPEN until the PO accepts)

1. **The shift is the unit of "now".** Every ward view opens on the current shift, names it with its times, and makes another shift one tap away. A list never mixes shifts without a shift heading.
2. **Uncovered before covered.** Residents or tasks without a responsible person in this shift come before everything except safety signals (§1, never above a safety signal).
3. **Counts, not judgements, until a rule exists.** Staffing shows counts and names. Words like "unterbesetzt", "zu wenig" or "Skill-Mix" and red tones appear only when a `cra`-confirmed rule supplies them.
4. **"Nicht überwacht" is a visible state.** Every reused control without a ward trigger (CGR-142 (1)) is listed under that heading on N-01 and N-02 (wording `cra`).
5. **Shared device (privacy, `lca`).** A ward tablet or station PC may be used by several people. **UNKNOWN (`lca`, `eng`):** whether shared devices are allowed in Phase A, the sign-out timeout, and what the lock screen shows. Until then, the design assumes a personal sign-in per person and shows no resident name on any lock or idle screen.
6. **Words.** "Bewohnende" / "Bewohnerin" / "Bewohner" for residents; "Wohnbereich" or "Station" as the organisation names it (data, not code); shift names from data. `cra` confirms the care words and `lca` the privacy texts (README, *UX review*).

## 4. Not invented (CGR-142 (2)): UNKNOWN, with owners

| Topic | Owner |
|---|---|
| Shift names, times and count per day | organisation data; seed values by `po` (synthetic) |
| Staffing per shift, minimum staffing, skill mix | `cra`, Clinical Owner (D-43); `lca` for any legal minimum |
| Care-need level, instrument, re-assessment cycle | `cra` (D-36: no interRAI content) |
| Rest periods and working time across shifts | `lca` |
| Whether a handover is confirmed, and by whom | `cra` |
| Unit of planning on the ward (task or resident) | `po` with `cra` (NH-A1) |
| Shared devices on the ward | `lca`, `eng` |
| Who carries formal responsibility in the home (KON-2) | `lca`, owner (FE-040 (4)) |

## 5. Questions for the PO

1. Accept N-01 inside `/field` (one "Heute" place), or keep a separate ward tab?
2. Should the NH-A1 brief state the planning unit (task or resident) now? N-01 and N-02 are designed to work with either, but the screen catalog entry needs the choice.
3. Should the NH-A briefs carry this proposal's acceptance criteria (sections 2 and 3), or may `uxa` add the screens to `NAVORA_SCREEN_CATALOG.md` as PROPOSED entries once you accept?
4. Who answers the shared-device question (§3 (5)) before M9.0b? It changes the sign-in screen.

## Change log
- 2026-11-07 12:10 CET (`uxa`): version 1, written on the owner's instruction of 2026-11-07 (proactive proposals where the Blueprint and the founder say nothing).
