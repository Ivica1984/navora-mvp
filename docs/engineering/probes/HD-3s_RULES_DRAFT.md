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
| K3 | A second shift inside the pause | It does not overlap a block, but its rest gap is < 11 h, so it is blocked with `rest`. In a hand assignment: a warning (FE-123 (7)) |
| K4 | Unia 2020 allows reducing rest to 9 h in homes; the founder rule is ≥ 11 h | 11 h stays a parameter of the home; `lca` decides the legal reading before real data |
| K5 | Hand assignment against a rule | Warning plus audit (FE-123 (7)); absence and overlap stay blocked |
| K6 | DST change | Each block is turned into instants on its own (as `at_zurich`/`at_zurich_end`). Blocks in the daytime are unaffected; a block in 02:00–03:00 follows the HD-3a reading |

## 4. OPEN before the HD-3s contract

1. Which shift models allow a split shift (founder, choice question per FE-124).
2. Five working days per week for the daily target, or a field «Arbeitstage pro Woche» per home (founder).
3. Pause as non-working time, and rest after block 2, under the ArG (`lca`, before real data).
