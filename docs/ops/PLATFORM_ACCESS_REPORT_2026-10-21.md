# Platform Access Report

**Date:** 2026-10-21 ~16:20 CEST · **Agent:** Lead Engineer (Claude), cloud session
**Method:** one harmless capability test per system. Every claim below was observed in this session.
Labels: **VERIFIED** = tested and worked · **BLOCKED** = tested and refused · **NOT TESTED** = deliberately not tested (reason given) · **UNKNOWN**.

## Summary

| System | Read | Write | Limitation that matters |
|---|---|---|---|
| GitHub `Ivica1984/navora-mvp` | VERIFIED | VERIFIED: push branch, open PR | settings/secrets: secrets API 403; ruleset writes NOT TESTED |
| Supabase `jwmfxrmougneeceldhsa` | VERIFIED | VERIFIED for non-destructive SQL; **BLOCKED for destructive SQL** | `DROP` / `REVOKE` / `DELETE` cancelled at the confirmation step 4 of 4 times → owner runs those in the SQL Editor |
| Render workspace `tea-d5rj9ohr0fns73e6jib0` | VERIFIED | NOT TESTED | there is no NAVORA service; the only service (`Lumena-Health`) belongs to another repo; a "harmless" Render write does not exist |

## GitHub

| Capability | Test | Result |
|---|---|---|
| Clone / fetch | `git clone` | VERIFIED |
| Push branch | pushed `ops/live-containment-c1` (docs only) | VERIFIED |
| Open PR | `POST /repos/…/pulls` → PR #14 into `recovery/main` | VERIFIED |
| Read Actions runs, rulesets | `GET` | VERIFIED (200) |
| Read Actions secrets | `GET /actions/secrets` | **BLOCKED (403)** → agent cannot add the deploy/DB secrets for T12 |
| Repo permission flag | `GET /repos/…` → `permissions.admin = true` | reported by the API |
| Ruleset / protection / security-settings write | — | **NOT TESTED**: not harmless (changes protection on `main`). Earlier attempts (VERIFIED_STATE) returned 403. Owner actions O-A/O-B stay with the owner |
| `gh` CLI | `gh auth status` | **BLOCKED**: token in `GH_TOKEN` invalid; REST via the session proxy works instead |

Repository visibility: **public** (unchanged; see D-7).

## Supabase

| Capability | Test | Result |
|---|---|---|
| List projects, tables, advisors, logs | MCP reads | VERIFIED |
| Read SQL | `execute_sql` select / catalog queries | VERIFIED |
| Session-scoped writes + role switching | temp table, `set role anon/authenticated` probes | VERIFIED (used for C-1 verification) |
| Non-destructive migration | `apply_migration capability_probe_noop_2026_10_21` (`select 1`) | **VERIFIED** — note: this adds one record to the live migration history; it has no schema effect |
| Destructive DDL/DML (`DROP POLICY`, `REVOKE`, `DELETE`) | C-1 via `apply_migration` ×3, `DELETE` probe via `execute_sql` ×1 | **BLOCKED** — cancelled at the confirmation step each time, including after explicit owner approval in chat |
| Projects | `Ivica1984's Project` (ACTIVE, eu-west-1) · `lumena-health` (INACTIVE) | — |

**Consequence:** the agent can create tables, functions, policies and grants, but cannot remove them. Hardening that only *adds* restrictions (e.g. new RLS policies) works. Anything containing `DROP`, `REVOKE`, `DELETE`, `TRUNCATE` goes through the owner, as for C-1.

## Render

| Capability | Test | Result |
|---|---|---|
| List workspaces / services / deploys | MCP reads | VERIFIED |
| Services | `Lumena-Health` (free plan, Frankfurt, repo `Ivica1984/Lumena-Health`, branch `main`, auto-deploy on commit) | not NAVORA |
| Deploy / env vars / create service | — | **NOT TESTED**: every Render write either redeploys an unrelated service or creates a billable resource |

**Consequence for T12:** creating a NAVORA service on Render is technically available to the agent, but plan and region are **financial / data-residency decisions** (D-2). Render regions: Frankfurt is the closest; there is no Swiss region. Once D-2 names Render and a plan, the agent can create the service.

## What this changes in the backlog

- D-2 options gain **Render (Frankfurt)** as a concrete app host alongside Supabase eu-west-1.
- Live-DB hardening: additive changes by the agent; removals by the owner.
- T12 still needs: hosting decision (D-2) and the DB/deploy secrets set by the owner (secrets API 403).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
