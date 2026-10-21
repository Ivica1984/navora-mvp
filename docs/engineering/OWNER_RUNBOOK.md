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

## 6. Decisions
Read `docs/engineering/DECISIONS.md` and reply "accept all" or name the ADRs you reject.
Then merge PR #3 with **"Create a merge commit"**.
