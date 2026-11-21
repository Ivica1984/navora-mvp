# CGR-201 probe: «Zuordnen» racing a new case or team search (analysis, no code change)

**Author:** `eng`, scheduled run 2026-11-13 06:10 Europe/Zurich · **Block:** B1.1 (B1.1-1 follow-up; CGR-201 is a condition of the B1.1 block acceptance, PO 05:39, brief `docs/agents/briefs/B1.1.md` line «CGR-201») · **Status:** analysis and reproduction IMPLEMENTED as this document; the fix is PLANNED (own PR after #1164 is merged); nothing here changes the application or the database.

## The race (from the code on #1164 head `3467d7a`)

Migration `20261021000127_b1_1_1_region_list.sql`:

- `private.region_from_list()` (section 3), insert path of `cases` and `matching_requests` for a signed-in user: reads `region_legacy_values` **without a lock** and keeps the legacy text when `region_id` is still null.
- `public.map_legacy_region()` (section 4): locks the legacy row `for update`, sets `region_id`, then `private.rewrite_region()` rewrites every row that carries the legacy text.

Under READ COMMITTED (the PostgREST default) both interleavings leave a row on the old text while the legacy row is already mapped, so «Region nicht zugeordnet» (`unmapped_regions`, `where l.region_id is null`) no longer shows it:

1. **map first:** the mapping has updated the legacy row but not committed; the insert's trigger still sees `region_id is null` (no wait, no lock) and keeps the old text; the mapping's rewrite never sees the new row.
2. **insert first:** the insert has run its trigger (old text) but not committed; the mapping takes its `for update` lock without waiting (the insert holds no lock on the legacy row), and its rewrite `update` does not see the uncommitted row.

## Reproduction (minimal model, vanilla PostgreSQL 16, run in this session)

Not the NAVORA schema (the agent session has no Supabase CLI and no pgTAP); a three-table model of the same statements: `regions`, `legacy(v, region_id)`, `cases(region)` with a `before insert` trigger shaped like the insert path of `region_from_list`. Two `psql` sessions, the first holds its transaction open 2 s, the second starts 0.7 s later. Result = the region stored on the new case after both committed.

| Trigger variant | map first | insert first |
| --- | --- | --- |
| A. as on #1164 (plain `select`) | `Altregion` (**stray**) | `Altregion` (**stray**) |
| B. one statement, `select … left join regions … for share of l` | `Altregion` (**stray**) | `Basel-Stadt` |
| C. two statements: `perform 1 from legacy where v = new.region for share;` then the plain `select … left join regions` | `Basel-Stadt` | `Basel-Stadt` |

Why B is not enough: after waiting for the lock, READ COMMITTED re-checks only the locked row (EvalPlanQual); the null-extended row of the outer-joined `regions` is reused from the old snapshot, so `mapped` stays null. In C the second statement takes a new snapshot after the lock wait and sees the committed mapping. In the «insert first» order the share lock makes the mapping's `for update` wait for the insert's commit, and its rewrite `update` (a new statement, new snapshot) then sees the row.

These results are from a model, not from the NAVORA database: UNKNOWN until the fix PR shows them in CI on the real schema.

## Proposed fix (PLANNED, ADR in the fix PR; HOW is `eng`'s per the brief)

1. **Lock (closes the race):** new migration with `create or replace function private.region_from_list()`: in the insert path take `perform 1 from public.region_legacy_values where organization_id = new.organization_id and legacy_value = new.region for share;` and read the mapping in a **separate** statement (variant C). Same two-step read in `private.register_legacy_region()` (database-role path, migration and seed only). No change to who may write what, to RLS, to grants or to `audit_command`.
2. **Safety net (meets the pgTAP criterion «rewritten or listed with its count»):** `unmapped_regions()` also lists a legacy value that is mapped while any team, case, referral or open search of the organisation still carries its text, with its counts. What «Zuordnen» then does for such a row is OPEN: proposal, the command rewrites the remaining rows to the region already chosen and writes its own audit row; choosing a different region stays refused (`already_mapped`), because a re-map is CGR-202 (a), a condition of the real-data gate and outside FE-072 (3). The texts for that row are `uxa`'s.
3. **Tests (written first, red on `recovery/main` after #1164):**
   - pgTAP (single session, deterministic): fixture = a case carrying a legacy text whose legacy row is mapped (set as table owner without rewrite); `unmapped_regions` lists the value with `cases >= 1`; after the command the case carries the list name and one audit row exists.
   - Two-session race test on the real schema (the table above, variants map first and insert first): needs two connections, which pgTAP inside one transaction cannot give. Proposal: a small `psql` script run by the `db` job after pgTAP. That is a change to `.github/workflows/ci.yml` and `ci-repeat.yml`; it needs no new tool (the job already has the Supabase CLI and its Postgres).

## Order and gates

- The fix needs the migration of #1164 on `recovery/main`, so it is its own PR after #1164 is merged (one PR each, brief «Gates per PR»), before B1.1-2 or in parallel with it as the PO decides. Gates `cra`, `uxa` (texts of step 2), `lca` (migration touches section 3) per PR.
- Not started as a feature PR this run: #1164 is the open B1.1-1 PR and its head carries the `cra` gate line; pushing to it would move the gated head.
