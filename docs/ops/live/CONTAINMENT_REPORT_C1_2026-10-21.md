# Containment C-1 — Live Supabase project

**Project:** "Ivica1984's Project" · ref `jwmfxrmougneeceldhsa` · region eu-west-1
**Date:** 2026-10-21 · **Executed by:** owner (SQL Editor, ~16:12 CEST), after the agent's `apply_migration` attempts were cancelled three times at the connector's confirmation step
**Prepared and verified by:** Lead Engineer (Claude)
**Closes:** D-1 / O-E (containment part) · SR-01 · partly SR-12 (key rotation still open)

## 1. Finding (before)

Verified read-only on 2026-10-21 ~16:03 CEST:

| Item | State before |
|---|---|
| Policies `{public}` with `true` | `cases`: SELECT, INSERT, UPDATE · `care_visits`: SELECT, INSERT, UPDATE · `teams`: SELECT, UPDATE |
| Grants | `anon` **and** `authenticated`: SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on 9 of 10 public tables (`team_locations` had none) |
| Default privileges (owner `postgres`) | new tables granted to `anon` automatically |
| Rows (counts only, contents not read) | cases 6 · care_visits 3 · teams 3 · care_notes 3 · orders 10 · partner_requests 2 · matching_requests 4 · match_candidates 12 · quality_events 3 · team_locations 0 |
| Client traffic, last 24 h (edge logs) | none — only Supabase infrastructure health checks |
| Migration history | empty (schema untracked) |

**Impact:** anyone with the public anon key could read, create and modify cases, visits and teams. RLS was the only thing preventing access to the other tables. **Whether the rows are real people is unknown** (owner question). Earlier access cannot be ruled out: edge logs reach back only 24 h.

## 2. Change

Script: see the containment SQL in this PR's description; backup and exact rollback in [`2026-10-21_backup_and_rollback.sql`](2026-10-21_backup_and_rollback.sql).

- Dropped the 8 `Enable … access for all users` policies.
- `revoke all on all tables in schema public from anon`.
- `revoke truncate, references, trigger … from authenticated`.
- `alter default privileges in schema public revoke all on tables from anon` (owner `postgres`).
- **No data was changed.** Row counts are identical before and after.

## 3. Verification (after, ~16:14 CEST)

| # | Requirement | Method | Result |
|---|---|---|---|
| 1 | Anonymous users cannot read | `set role anon`; `select count(*)` on all 10 tables | **PASS** — 10/10 `42501 permission denied` |
| 2 | Anonymous users cannot write | `set role anon`; `insert … default values` on all 10 tables (each in a forced-rollback sub-block) · `has_table_privilege` for UPDATE/DELETE/TRUNCATE | **PASS** — inserts 10/10 `42501`; UPDATE/DELETE/TRUNCATE privilege false on 10/10 |
| 3 | Authenticated users keep only intended access | `set role authenticated`; select + insert on all 10 tables | **PASS** — select returns 0 rows (RLS, no policies); insert `42501 new row violates row-level security`; TRUNCATE/TRIGGER/REFERENCES revoked. Intended: no access until the scoped RLS from T9 is deployed |
| 4 | Existing functionality remains operational | edge logs (no client traffic 24 h); Render has no NAVORA service; row counts unchanged | **PASS** — nothing in use depended on the removed access |
| — | Supabase security advisor | `get_advisors security` | anon GraphQL exposure (lint 0026) **gone**; remaining: `rls_enabled_no_policy` (expected, INFO), lint 0027 authenticated exposure (WARN, resolved by T9), leaked-password protection off (WARN) |

**Limitation:** a behavioural UPDATE/DELETE probe was cancelled at the connector's confirmation step (it contained `DELETE`). UPDATE/DELETE denial is therefore verified at the privilege level only. That is the same mechanism the behavioural SELECT/INSERT tests proved.

## 4. Remaining owner actions

1. **Is the data real?** If any of the 6 cases / 3 care notes concern real people, the exposure may be a data-protection incident under the revised FADP (DSG). Whether to notify the FDPIC and/or affected persons is a **legal decision**.
2. **Rotate the anon/JWT key** (SR-12), Project Settings → API. Until then the old key remains valid. It now grants nothing on `public`, but it is still a credential.
3. Enable leaked-password protection (Auth settings).
4. Deploy T9 (tenancy + scoped RLS) to this project, or replace the project, once D-2 is decided. Until then signed-in users have no table access (intended).
5. Reconcile migration history: the live project has no migration records; C-1 is documented here, not in `supabase/migrations/`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
