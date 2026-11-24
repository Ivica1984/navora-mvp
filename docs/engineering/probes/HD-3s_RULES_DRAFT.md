# HD-3s «geteilter Dienst»: rules, order, limits, invalid inputs, conflicts (DRAFT, `eng` 2026-11-24 ca. 23:40 CET)

**Status:** PLANNED. This is preparation on the unmerged probe branch `probe/hd3s-split-shift-red` (FE-099 WORKING MODE 7: at most one ADR draft and one red probe for the next package). The founder chose this live at about 23:30 («Prepare rules + tests»). Order per the founder at about 23:00 (#1712 7145527628): HD-3a → **HD-3s** → HD-3b → INTAKE-E2E → HD-3c → HD-3d. Code follows only after HD-3a and only on a contract from `po`. Fixed, checkable rules; no AI model. Simulation with synthetic data only; «Arbeitszeitgesetz nicht abschliessend geprüft»; `lca` checks the reading before real data.

**Sources:**
- Founder rules, 23:10 (#1712 7145634673): (1) the pause is not working time; (2) rest starts after the 2nd block; (3) one working day, «Zählen, nicht erzwingen».
- FE-119 / FE-123: rest ≥ 11 h, ≤ 6 days in a row, Pensum × weekly target hours, hand assignment gives a warning.
- HD-3a model `draft.ts` (`feature/hd3a`, `e509c95`).

**Red tests:** `tests/unit/hd3s-split-shift.test.ts`. The interface is `src/features/home-plan/split.ts`, a stub that throws.

## 1. Inputs and invalid inputs (V, checked in this order; the first failing check is the reason)

| # | Check | Reason code |
|---|---|---|
| V1 | all four times are `HH:MM` and lie between 00:00 and 23:59 | `time_format` |
| V2 | every block has a length > 0 | `zero_length` |
| V3 | no block crosses midnight (`ends_at > starts_at`) | `block_crosses_midnight` |
| V4 | block 2 starts after block 1 has started and does not overlap it | `block_order` |
| V5 | pause > 0 (block 2 starts after block 1 ends) | `no_pause` |

The database refuses the same values with a check constraint. The screen and the database use the same codes. NAVORA sets no minimum or maximum pause (PLANNED only if the founder or `lca` names one; not invented).

## 2. Rules (the HD-3a order, extended for two blocks)

| Order | Rule | Split shift |
|---|---|---|
| 1 | R-b Pensum entered | unchanged |
| 2 | R-c shift model | new class `split`. **OPEN (founder):** which models allow it. Until decided: only `any` (fail closed, like an unclassified type, FE-123 (2)) |
| 3 | R-d absence | the work_date only (S3) |
| 4 | R-e overlap | each block separately against every other shift |
| 5 | R-f rest | S4: from the end of block 2 to the next shift; from the end of the previous shift to the start of block 1 |
| 6 | R-g days in a row | S3: counts as **one** day |
| 7 | R-h Pensum per ISO week | S2: minutes of both blocks, without the pause, in the week of the work_date |
| 8 | S5 daily target | **hint only**, never a block, shown after the checks |

**S5 daily target:** `weekly_target_hours / workDaysPerWeek`. The default is 5 (the `eng` reading, **OPEN** for the founder). Examples: 42 h → 504 min; the founder's example of 39.5 h → 474 min. No weekly target entered → no hint.

## 3. Conflicts and their deterministic resolution

| # | Conflict | Resolution |
|---|---|---|
| K1 | Rest ≥ 11 h against a pause of, for example, 4 h 30 | The rest rule applies only between **different** shifts, never between the two blocks of one split shift (founder (2)) |
| K2 | «One full working day» against times the home sets freely | Hint, no block (founder (3) «Zählen, nicht erzwingen») |
| K3 | A second shift inside the pause | It lies inside the working day of the split shift, so it is blocked with `busy` (R-e), before the rest rule is checked. In a hand assignment: a warning (FE-123 (7)) |
| K4 | Unia 2020 allows reducing rest to 9 h in homes; the founder rule is ≥ 11 h | 11 h stays a parameter of the home; `lca` decides the legal reading before real data |
| K5 | Hand assignment against a rule | Warning plus audit (FE-123 (7)); absence and overlap stay blocked |
| K6 | DST change | Each block is turned into instants on its own (as `at_zurich`/`at_zurich_end`). Blocks in the daytime are unaffected; a block in 02:00–03:00 follows the HD-3a reading |

## 4. OPEN before the HD-3s contract

1. Which shift models allow a split shift (founder, choice question per FE-124).
2. Five working days per week for the daily target, or a field «Arbeitstage pro Woche» per home (founder).
3. Pause as non-working time, and rest after block 2, under the ArG (`lca`, before real data).

## 5. Researched working-time rules for homes and hospitals (addendum 2026-11-25 ca. 00:00, on the founder's request)

**Status:** research only. These are public implementation aids, not legal checks:
- [A] Basel-Stadt, «Merkblatt Arbeitszeiten für Heime», as of 12.06.2025 (Art. 16 Abs. 2 ArGV 2);
- [B] SECO guidance ArGV 2 Art. 15, hospitals and clinics (2017, excerpt);
- [C] BAG page on the BGAP (draft law, Botschaft 21.05.2025, business 25.054; status in parliament today UNKNOWN).

NAVORA takes no legal reading from them. Each value becomes a **parameter of the home** with the mark «Arbeitszeitgesetz nicht abschliessend geprüft», and `lca` checks it before real data. Home care (Spitex) is not covered by these sources (UNKNOWN).

| # | Rule (source) | In NAVORA | Proposal (PLANNED) |
|---|---|---|---|
| A1 | Daily rest ≥ 11 h (Art. 15a ArG) [A p. 6] | IMPLEMENTED in HD-3a (R-f, `min_rest_hours`) | unchanged. Reduction to 9 h when the 2-week average is ≥ 12 h (Art. 9 ArGV 2) is **not** built; the founder rule ≥ 11 h stays hard (K4) |
| A2 | ≤ 6 working days in a row (Art. 21 ArGV 1) [A p. 6]; 7 only with ≤ 9 h per day, the weekly limit kept on the 2-week average and ≥ 83 h free right after (Art. 7 Abs. 2 ArGV 2) [A p. 4, B] | IMPLEMENTED (R-g, `max_consecutive_days` 6) | the 7-day model is not built; the home can raise the parameter only once all three conditions are checked (later package) |
| A3 | Maximum weekly working time 50 h (Art. 9 ArG) [A p. 4, B]; BGAP draft 45 h [C] | not built (only the Pensum cap R-h) | **R-i**: minutes per ISO week ≤ `max_weekly_hours` of the home (default 50, «Beispielwert»), checked on top of R-h |
| A4 | Individual working day **including pauses** within **14 h** (Art. 10 Abs. 3 ArG) [A p. 4] | not built | **R-j, important for the split shift:** start of block 1 to end of block 2 ≤ `max_day_span_hours` (default 14). The test home's 07:00–20:00 is 13 h, so it is allowed; 06:00–20:30 is refused |
| A5 | Day and evening work 06:00–23:00 [A p. 4]; night 23:00–06:00, night work at most 9 h within 10 h including pauses (Art. 17a ArG) [A p. 5] | not built | **R-k**: a shift that touches 23:00–06:00 has ≤ 9 h of work within ≤ 10 h. The 10-h-in-12-h variant (Art. 10 Abs. 2 ArGV 2) is **not** built: [A] and [B] describe it differently (OPEN, `lca`) |
| A6 | Pauses 15/30/60 min at > 5.5/7/9 h (Art. 15 ArG) [A p. 6]; a pause counts as working time if the person may not leave [A p. 7] | not built | **S6 hint**: a block over 5.5 h without a pause shows a hint. The split-shift pause is not working time (founder (1)); whether the person may leave during it is the home's responsibility (shown as a hint, OPEN `lca`) |
| A7 | ≥ 12 free Sundays per year (Art. 12 Abs. 2 ArGV 2) [A p. 6, B] | not built | later package (HD-3b fairness/weekends) |
| A8 | Normal weekly working time 40–42 h (BGAP draft) [C]; per house, e.g. the founder's examples 39.5 h and 42 h | IMPLEMENTED as `weekly_target_hours` per home (1–80) | unchanged |

**Order with the new rules (deterministic):** R-b → R-c → R-d → R-e → **V/R-j (span)** → R-f → R-g → **R-k (night)** → R-h (Pensum) → **R-i (50 h)** → hints S5, S6. Shape checks come before limits on hours; the first rule that fails is the reason the screen shows.

**Conflicts:**
- **K7:** [A] and [B] contradict each other on the 10-h-in-12-h night variant. The variant is not built until `lca` reads the original.
- **K8:** the Pensum cap R-h and the 50 h rule R-i both apply. The smaller limit binds, and the reason shown is the one of the rule that failed first in the order above.

## 6. Status of the implementation (2026-11-25 ca. 00:15, founder live: «Setze alle definierten Regeln im Algorithmus um»)

**IMPLEMENTED on the probe branch, not merged:** `src/features/home-plan/split.ts` `evaluateShift()` checks one or two blocks against every rule of §2 and §5. The order is:
1. shape V1–V5, then the limits of the home (fail closed; `pensum_reference_missing` when no weekly target is entered);
2. R-b → R-c → R-d → R-e → R-j → R-f → R-g → R-k → R-h → R-i;
3. then the hints S5 and S6.

The tests are `tests/unit/hd3s-split-shift.test.ts`, 50 tests, green locally.

**Not yet in the plan proposal or the database (PLANNED, after HD-3a):**
- `draft.ts` (HD-3a, other writer) calls these rules;
- the shift type gets a second block (migration, `create or replace` from the function source files, TESTS 6);
- the database repeats the check under the person lock;
- the screen shows the reasons and hints.

**OPEN:**
- which shift models allow a split shift (until then only `any`);
- 5 working days per week;
- the ArG reading of the pause, rest after block 2, 50 h, 14 h and the night rule (`lca`);
- the 7-day model and the 9-h rest reduction (not built, K4/A2).

**Founder decisions, live 2026-11-25 ca. 00:20 (choice questions under FE-124):**
1. Split shift for the shift models «alle Dienste» (`any`) and «keine Nacht» (`no_night`); never for «nur Früh/Spät/Nacht».
2. Daily target = weekly target hours ÷ working days per week, as a field per home with default 5.

Both are IMPLEMENTED on the probe (`modelAllows`, `Limits.workDaysPerWeek`). The OPEN points 1 and 2 of §4 are settled; the `lca` reading stays OPEN.
