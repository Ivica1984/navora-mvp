# NAVORA — Architecture Decision Log

**Last updated:** 2026-10-21 (T10) · Complements `TECHNICAL_DECISIONS.md` (product decisions from the handover).
**Status:** PROPOSED (awaiting owner) · ACCEPTED · SUPERSEDED · REJECTED.
Format: context → decision → trade-offs → risks. An entry graduates to `docs/adr/NNN-*.md` if it grows.

---

### ADR-001 — Timebox the Codespace search, then build on the archive
**Status:** PROPOSED · **Context:** a newer Codespace may exist; documented deltas are small.
**Decision:** 48 h from the owner's check (O-D). Without a Codespace, the archive is the base; only the cases type fix is re-done (done in PR #1 by removal, ADR-015), `/matching` is dropped (ADR-006), the version bump is superseded (ADR-004).
**Risks:** a late Codespace goes to its own preservation branch and is diffed.

### ADR-002 — Feature-sliced modular monolith instead of the full layered/hexagonal target
**Status:** PROPOSED · **Context:** ~4k lines, 8 tables, one maintainer; code already uses `src/features/*`.
**Decision:** `features/<f>/{queries,commands,rules,types}.ts` + `components/`; `rules.ts` is pure TS. No orchestrator, DSL or ports until a second implementation exists.
**Evidence so far:** `operations/rules.ts` extracted in PR #1 and unit-tested without any Supabase mock.
**Risks:** cross-feature coupling → ESLint boundary rule (planned with T10).

### ADR-003 — Writes: Server Action → Postgres function (transaction + state check + audit)
**Status:** ACCEPTED in practice (T10), **amended by ADR-019** · Closes ARCHITECTURE "OPEN: Server Action vs Route Handler/Edge/RPC".
**Decision:** each state change is a `SECURITY INVOKER` function that checks membership, source state and idempotency key, mutates and writes `audit_events` in one transaction; Server Actions validate with zod and call it via `rpc`. RLS stays the authority.
**Trade-offs:** some transition logic in SQL (pgTAP-tested); calculations stay in `rules.ts`.

### ADR-004 — Next.js ≥ 16.4.1 as minimum
**Status:** ACCEPTED in practice (PR #1) — owner confirmation pending.
**Decision:** next/eslint-config-next pinned exactly; sharp ≥ 0.35.5 via Next's dependency. Dependabot security updates once O-B is done.

### ADR-005 — Minimal tenancy model first
**Status:** ACCEPTED in practice (T9, PR #8) — owner confirmation pending · **Decision:** `organizations`, `organization_memberships(role)`, `team_memberships`; `organization_id NOT NULL` on care tables. Other identity tables when a use case arrives. Roles are placeholders (Q4).

### ADR-006 — Hide `/matching` and `/partners`; do not repair them
**Status:** ACCEPTED in practice (PR #1) — owner confirmation pending.
**Decision:** both 404 and leave the navigation unless `NEXT_PUBLIC_FEATURE_DEMO_PAGES=true`.

### ADR-007 — After the security foundation, build `/field` before extending Operations
**Status:** PROPOSED.

### ADR-008 — Migrations-first database workflow with local Supabase
**Status:** ACCEPTED in practice (PR #1).
**Decision:** schema only via `supabase/migrations`; local and CI use `supabase start`; staging via CI `db push`; engineering never touches the live project.
**Current state:** baseline is reconstructed (TD-19) until the live pull (O-F).

### ADR-009 — Test stack: Vitest, pgTAP, Playwright
**Status:** ACCEPTED in practice: all three run in CI (Playwright since T8, job `e2e`).

### ADR-010 — No caching of care data
**Status:** ACCEPTED in practice (PR #1): data pages call `connection()`; no `use cache`, ISR or prerender.

### ADR-011 — Separate staging hosting decision from production hosting
**Status:** PROPOSED.

### ADR-012 — GitHub Actions is the verification runner
**Status:** ACCEPTED (supersedes the earlier "pending push access" note).
**Context:** verified 2026-10-21: the agent workspace has no npm registry access and no Docker daemon, but can push branches, open/merge PRs and read check-run annotations; it cannot read raw job logs or dispatch workflows.
**Decision:** every build/test result in a PR comes from CI. `scripts/ci-step.sh` re-emits each stage's output tail as an annotation so it is readable through the checks API. Every stage runs even after an earlier one fails, so one CI round gives the full picture.
**Risks:** annotation size limits truncate long logs → the full log stays in the job; the tail is enough for triage.

### ADR-013 — Import the recovered code from the Project copies instead of waiting for the owner's zip import
**Status:** PROPOSED · **Context:** the plan required the owner to import `src.zip` byte-for-byte (T2). Waiting blocked all of M1. The Project holds copies of the same files.
**Decision:** the agent transcribed the 22 build-relevant files onto `import/project-src-2026-10-21`, records SHA-256 per file, and ships `scripts/verify-against-zip.sh`. The M2 merge to `main` is gated on that script printing `IDENTICAL` (O-C). The two backup UI files are not transcribed.
**Trade-offs:** M1 finished today instead of after owner availability; integrity is verified after the fact instead of before (SR-19).
**Risks:** an undetected transcription slip. One was caught during import and is recorded in `RECOVERY_LOG.md`. The verify script is the control.

### ADR-014 — Lockfile resolved by a CI bot
**Status:** PROPOSED · **Context:** dependency changes require a lockfile, the agent cannot reach npm.
**Decision:** `lockfile-sync.yml` runs `npm install --package-lock-only --ignore-scripts` on pushes that touch `package.json` (not on `main`) and commits the lockfile. `npm ci` in CI then installs strictly from it.
**Trade-offs:** an extra bot commit per dependency change; GITHUB_TOKEN pushes do not trigger CI, so the next push does.
**Risks:** SR-20 (bot write access) — limited to one file, no install scripts, protected branches still need review.

### ADR-015 — Remove broken unused code instead of repairing it
**Status:** PROPOSED · **Context:** `getCasesWithVisits` failed typecheck, had no callers, and fetched full patient records.
**Decision:** during recovery, unused code that fails checks *and* increases data exposure is removed, not fixed. Removal is recorded in `TECH_DEBT.md`. Repairing it would add maintained surface for no user value.

### ADR-016 — The engineering registers live in the repository
**Status:** PROPOSED · **Context:** backlog, debt, security register and decisions existed only as Project documents, outside review and versioning.
**Decision:** `docs/engineering/*.md` in the repo is the source of truth and changes by PR; the Project holds a mirror for reading in claude.ai. Includes a security register that lists open gaps — so the repository's visibility matters (SR-18).
**Owner question:** the repository is **public**. Recommendation: make it private while SR-01/SR-02/SR-07 are open, because the register and code describe exploitable gaps in a system whose live database may still be exposed. If it must stay public, move `SECURITY_RISKS.md` to the Project only.

### ADR-017 — Auth enforced in three layers; no Supabase client or key in the browser
**Status:** PROPOSED · **Task:** T8 · Implements TECHNICAL_DECISIONS "Auth: SSR-Cookie-Sessions und serverseitige Prüfung" (DECIDED).
**Context:** a check in a layout alone does not protect a page's data (layouts and pages render independently). The recovered UI also wrote to the database from the browser with the anon client.
**Decision:**
1. `src/proxy.ts` refreshes the session and redirects requests without one to `/login` (coarse guard, `getClaims`).
2. `(protected)/layout.tsx` calls `requireUser()`.
3. Every query and every Server Action calls `requireUser()` itself (`getUser`, checked against the Auth server) and uses the session-bound client.
The four existing browser writes became Server Actions in T8, ahead of T10, so **no Supabase client exists in the browser** and the env vars are server-only (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, no `NEXT_PUBLIC_`). An e2e test asserts the key and URL appear in no HTML or JS sent to the browser.
**Deviation from plan:** the plan kept a browser client for "auth UI only" and moved writes in T10. Moving the writes now was cheaper than wiring a browser client that T10 would remove again. T10 still adds DB functions, membership checks, audit and idempotency.
**Trade-offs:** each request makes one Auth round-trip in `requireUser()` (plus the proxy's claim check). Accepted for correctness; revisit with request-level memoisation if latency matters.
**Risks:** the anon key still lets anyone call the Supabase REST API directly while `legacy_public_all` exists — T9 closes this at the database (SR-01).

### ADR-018 — How tenancy is enforced in Postgres
**Status:** PROPOSED · **Task:** T9 · Builds on ADR-005.
**Decision:**
1. **Policies** call three `SECURITY DEFINER` helpers in schema `private` (`is_org_member`, `has_org_role`, `is_team_member`) with an empty `search_path`. `private` is not exposed by the Data API; execute is granted to `authenticated` only. This avoids recursive RLS on the membership tables.
2. **Privileges first, policies second:** `anon` has no privileges on any table; `authenticated` has `SELECT` plus column-limited `UPDATE` (`teams.priority, coach_name`; `care_visits.status, billable`). There is no `INSERT`/`DELETE` through the API. A policy mistake therefore cannot expose a column or operation the grants do not allow.
3. **Composite foreign keys** `(x_id, organization_id)` make cross-tenant references impossible at the database level, independent of application code.
4. **Placeholder role rules** (Q4): read = any org member; team settings = `admin`/`coach`; visit transitions = members of the visit's team (Teamautonomie, DOMAIN_RULES DECIDED).
5. Legacy policies are dropped **in the same migration** that adds the replacements; the pgTAP assertions that documented the exposure were inverted in the same PR.
**Trade-offs:** every org member, including `nurse`, can read every case in the organisation, including health fields. Purpose-limited read access (team/case/care-context) is part of the open permission matrix and of SR-06/T10 minimisation.
**Risks:** a wrong helper would affect all tables at once → covered by 38 pgTAP assertions across roles, foreign org, member-of-nothing and anon, plus a CI check against the real REST API.

### ADR-019 — Audit by trigger, state machine by trigger, idempotency through the audit log
**Status:** PROPOSED · **Task:** T10 · Amends ADR-003.
**Context:** ADR-003 put "mutate + audit" into each command function. Those functions run as the caller (RLS stays the authority), so a user who calls the REST API directly can update the same rows with the same rights and would bypass any audit written in the function body.
**Decision:**
1. **Audit is a `SECURITY DEFINER` AFTER UPDATE trigger** on every app-updatable table (`teams`, `care_visits`). Every update is audited, whatever the path. `audit_events` is append-only, also for the owner (UPDATE, DELETE and TRUNCATE are blocked). App users have no INSERT privilege. Only allowlisted columns are recorded, never free text or health data. Only org `admin` reads the log (placeholder, Q4).
2. **Command functions** (`set_team_priority`, `assign_team_coach`, `start_visit`, `complete_visit`) are `SECURITY INVOKER` and require an idempotency key. The key and command name are passed to the trigger through transaction-local settings and **cleared before the function returns**, a defect pgTAP found. A unique index on `(actor_id, idempotency_key)` in the audit log makes a replay return `duplicate` without changing anything.
3. **The visit state machine is a BEFORE UPDATE trigger:** app users may only go `planned→started→completed`, including through direct REST. The wider draft state machine waits for product/clinical confirmation (F2).
4. **`billable` is not writable by app users**, and completion no longer sets it (closes SR-09).
5. **Invariant test:** pgTAP fails if any table app users can UPDATE lacks the audit trigger.
**Trade-offs:** the logic is spread over functions and triggers, which pgTAP has to cover (31 assertions). Direct REST updates skip idempotency, but not RLS, the state machine or the audit.
**Open:** audit retention and access rules are legal/data-protection decisions (Q6).
