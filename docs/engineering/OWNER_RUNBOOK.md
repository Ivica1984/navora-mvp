# NAVORA — Owner runbook (steps only the owner can do)

**Updated 2026-10-21.** Supersedes the earlier T1/T2 runbook: the code is already imported
(`import/project-src-2026-10-21`) and builds green in CI. What remains needs your accounts.
Order = priority. None of these steps changes `main`.

## 1. Live database containment check (O-E) — today
In the Supabase dashboard of the **live** project:
1. Table editor → `cases`, `care_visits`: are any rows real people? (yes/no is enough)
2. Authentication → Policies: do `cases`, `care_visits`, `teams` have policies for `public`/`anon` with `true`?
3. Is anything deployed (Vercel/Render/other) that uses this project's anon key?

If **real data + anon access**: tell the Lead Engineer immediately. Containment (disable the anon
policies or pause the project) comes before all code work and needs your decision.

## 2. Verify the transcribed import (O-C) — gates the M2 merge
```bash
git clone https://github.com/Ivica1984/navora-mvp.git && cd navora-mvp
git switch import/project-src-2026-10-21
bash scripts/verify-against-zip.sh /path/to/src.zip
```
Expected last line: `IDENTICAL …`. Otherwise paste the diff into the PR #3 conversation.

## 3. Codespace check (O-D)
```bash
gh codespace list
```
If one is listed, follow "T1" in `claude/engineering/RECOVERY_RUNBOOK.md` (Project) to push it to
`preserve/codespace-<date>`. If none: write "no Codespace" on PR #3.

## 4. Protect the repository (O-A, O-B)
GitHub → Settings:
- **Rules → Rulesets → New branch ruleset** "protect-main": target `main` and `recovery/main`;
  require a pull request; require status checks `app (lint · typecheck · unit · audit · build)`
  and `db (migrations · seed · pgTAP)`; block force pushes; restrict deletions.
- Second branch ruleset "preserve": target `import/**` and `preserve/**`; block force pushes and deletions.
- **Code security**: enable secret scanning, push protection, Dependabot alerts and security updates.
- **Visibility (ADR-016):** recommended to set the repository to **private** while the security gaps are open.

## 5. Schema-only pull of live (O-F) — when convenient
```bash
supabase login
supabase link --project-ref <live-ref>
supabase db dump --schema public,private --file live_schema.sql   # schema only, no data
```
Send `live_schema.sql` (contains no data). Never use `--data-only` or a full dump.

## 5a. Signal evaluator and push dispatch in a pilot or staging project (SIG2-11, ADR-078) — before the outside channel is switched on
Only in a **non-live** project (never `jwmfxrmougneeceldhsa`). PLANNED until D-2 is answered; nothing here is needed for CI.
1. Dashboard → Database → Extensions: enable `pg_cron`, `pg_net` and `supabase_vault`. Then run `supabase db push` again (0064 re-schedules the job `navora-sig1-signals` by name).
2. SQL editor (one statement each; the values never go into the repository):
   `select vault.create_secret('<https URL of the deployed app>/api/push/dispatch', 'navora_push_dispatch_url');`
   `select vault.create_secret('<the same value as PUSH_DISPATCH_SECRET on the app host, 32+ characters>', 'navora_push_dispatch_secret');`
3. Check: `select jobname, schedule from cron.job;` shows `navora-sig1-signals` every minute; after two minutes `/admin` shows "Signalprüfung läuft." and not "Signalprüfung läuft nicht".
Without step 2 nothing leaves the app from the scheduler; pending pushes fail after 2 minutes and Operations gets the signal at once (fail closed).

## 5b. No code in the intake notes before the first real import (DOOR1-12, G-11, ADR-093) — before the first real client
Only in the project that will receive the first real data (never `jwmfxrmougneeceldhsa` for tests). Read-only; nothing is changed.
Since migration 0080 every write of `cases.access_notes` refuses a door or key-safe code ("Bitte keinen Code erfassen"), but a
note written before the guard stays as it is (no migration rewrites it). Run in the SQL editor:
`select count(*) from public.cases where private.looks_like_code(access_notes);`
Go-live needs **0** (gate G-11). If it is not 0, the team or intake edits those notes in the app (the guard then refuses the code);
nobody copies the note text out of the database. pgTAP 080 holds the same query on a synthetic fixture.

## 5c. Legacy nurse name without a responsible member (RLS4-C1, `cra` CGR-101, ADR-122 addendum) — before real, migrated or imported visit data is shown (G-25)
Why: since 0099 no screen shows the legacy free-text `care_visits.team_member_name`; `/visits` names the responsible member
from `responsible_user_id` only and says "Noch offen" when it is empty. A visit whose nurse is recorded **only** in the old
name would read as unassigned while the name is visible nowhere (H-10 two nurses go, H-01 nobody goes).

**When:** on the live project only **after the D-1 review result is recorded**, like every other write there (D-1 default:
no repository migration or write on the live project before it). In any project that receives migrated or imported visits:
after the import, before the data is shown to anyone. Never on `jwmfxrmougneeceldhsa` for tests. Nothing here is a migration.

1. **Count (read-only, SQL editor).** Keep this text identical to `supabase/tests/database/105_rls4_c1_legacy_name_check.test.sql`
   (a unit test compares them):
   ```sql
   -- RLS4-C1 check begin
   select count(*)::int as unmapped
   from public.care_visits v
   where v.status <> 'cancelled'
     and v.visit_date >= (private.at_zurich(private.now()))::date
     and v.team_member_name is not null
     and v.responsible_user_id is null;
   -- RLS4-C1 check end
   ```
   Write the count down (the reconciliation record, step 6). 0: nothing to do.
2. **Review list (live project only, on screen; never copied into the repository, an issue or a chat):** grouped by team and name.
   ```sql
   select t.id as team_id, t.name as team, v.team_member_name as legacy_name, count(*) as visits,
          min(v.visit_date) as first_day, max(v.visit_date) as last_day
   from public.care_visits v join public.teams t on t.id = v.team_id
   where v.status <> 'cancelled' and v.visit_date >= (private.at_zurich(private.now()))::date
     and v.team_member_name is not null and v.responsible_user_id is null
   group by t.id, t.name, v.team_member_name order by t.name, v.team_member_name;
   ```
3. **A person decides, once per legacy name and team:** a member of that team, or unassigned. A name two members could
   carry, or one the person is unsure of, is decided **visit by visit** (add `and v.id = '<visit id>'` to step 4).
   **NAVORA does no automatic name-to-member matching**, and nobody writes a matching rule: every name is decided by a person.
   Unassigned: nothing is written; the visit stays "Noch offen" and the team plans it (it stays in the count of step 1).
4. **Apply one decision, in one transaction**, by the person who decided:
   ```sql
   begin;
   set local navora.command = 'rls4_c1_legacy_mapping';
   update public.care_visits v set responsible_user_id = '<member user id>'
   where v.team_id = '<team id>' and v.team_member_name = '<legacy name as listed in step 2>'
     and v.responsible_user_id is null and v.status <> 'cancelled'
     and v.visit_date >= (private.at_zurich(private.now()))::date
     and exists (select 1 from public.team_memberships m
                 where m.team_id = v.team_id and m.user_id = '<member user id>');
   -- the row count must equal the visits of step 2 for this name and team; otherwise: rollback; and decide again
   commit;
   ```
   The membership guard maps nothing to a person outside the visit's team. The database also refuses a member without a
   qualification (ADM2-6) and a visit outside her recorded contract (ADM2-11): `rollback;` and decide again. Each mapped
   visit gets one `audit_events` row with `command = 'rls4_c1_legacy_mapping'` and `responsible_user_id` old and new only.
5. **Never:** edit, blank or drop `team_member_name` (a wrong legacy name is answered by a new, attributed entry or a dispute
   note, D-4); map past visits; map by a rule. `team_member_name` **stays**, unreadable to every app role (0099), for past
   and future visits until D-4's final retention rule. "Kept until the D-1 live reconciliation" does **not** mean
   "dropped after it".
6. **Reconciliation record** (with the D-1 review record): count before (step 1), count after (step 1 again), how many of
   the remaining were confirmed unassigned, who decided and applied, when. No names, no ids and no mapping in the repository.
   The database audit rows name the step but not the person in the SQL editor (`actor_id` is empty there), so "who" is in
   this record.

pgTAP 105 holds the same check and mapping on a synthetic fixture (Testteam Mitte, "Pflegekraft Test 3").

## 6. Decisions
Read `docs/engineering/DECISIONS.md` and reply "accept all" or name the ADRs you reject.
Then merge PR #3 with **"Create a merge commit"**.
