# NAVORA — Architecture Decision Log

**Last updated:** 2026-10-21 (T14) · Complements `TECHNICAL_DECISIONS.md` (product decisions from the handover).
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

### ADR-020 — Nonce-based CSP issued by the proxy; every page renders per request
**Status:** PROPOSED · **Task:** T11 · Closes SR-13 in code.
**Context:** Next.js App Router ships page data in inline scripts. A static CSP would need `script-src 'unsafe-inline'`, which removes most XSS protection.
**Decision:** `src/proxy.ts` creates a fresh nonce for each request. It sets the CSP on the request (Next.js applies the nonce to its own scripts) and on the response. Production `script-src` is `'self' 'nonce-…' 'strict-dynamic'`, with no `unsafe-inline` and no `unsafe-eval`. The other directives are `connect-src 'self'` (the browser never talks to Supabase, ADR-017), `frame-ancestors 'none'`, `object-src 'none'`, and `'self'` for `form-action`/`base-uri`. Static headers live in `next.config.ts`: HSTS, nosniff, `X-Frame-Options: DENY`, `Referrer-Policy: same-origin`, a restrictive `Permissions-Policy`, and COOP; `poweredByHeader` is off. The root layout calls `connection()`, so every page carries a nonce (consistent with ADR-010).
**Trade-offs:** `style-src 'unsafe-inline'` stays while the legacy UI uses inline style attributes (TD-01, removed with the design system). No static page optimisation, which the app does not need.
**Verification:** e2e asserts the headers, a new nonce per request, the CSP on redirects, a nonce on every script, and zero CSP violations during sign-in and navigation.
**Revisit:** `Permissions-Policy` must allow `geolocation=(self)` when the field tool needs it (M4), with a documented purpose.

### ADR-021 — Database types are generated from the migrations and checked in CI
**Status:** PROPOSED · **Task:** T14 · Closes TD-05.
**Decision:** `src/lib/supabase/database.types.ts` is generated by `supabase gen types` (pinned CLI 2.121.0). The `db-types-sync` workflow regenerates it on feature branches when migrations change (bot-commit pattern of ADR-014); the CI `db` job fails on drift. The server client is `createServerClient<Database>`, feature row types are `Pick`/`Omit` of the generated rows, and queries assign results without casts. `tests/types/db-types.check.ts` uses `@ts-expect-error` to prove that unknown columns, unknown tables and wrong RPC arguments fail the build.
**Trade-offs:** the generated file is committed (reviewable diffs) and excluded from ESLint; CLI upgrades are manual (TD-29).

### ADR-022 — The repository schema is the target; the live project is legacy
**Status:** PROPOSED · **Task:** TD-19 / O-F · Evidence: `docs/ops/live/SCHEMA_DRIFT_2026-10-21.md`.
**Context:** the baseline was reconstructed from code because live access was missing (ADR-008 planned to replace it with a live pull). A read-only comparison on 2026-10-21 showed that live is a prototype: it has unused PostGIS/geocoding objects, cascading deletes on care documentation, defaults outside its own value sets (`'geplant'`, `'normal'`), a column named `"assigned team"`, and a foreign `orders` table (Stripe test-mode checkouts, probably another app).
**Decision:** the migrations in `supabase/migrations/` define NAVORA's schema. Live is not pulled into the baseline. Only stricter rules found in live are adopted (`match_candidates.fit_score`/`status` NOT NULL, migration 0005). Deliberate deviations from live are pinned by pgTAP `007`. New environments start from the migrations, never from a dump of live. Location features (`team_locations`, PostGIS, geocoding, team capacity limits) need a product decision first (Q7).
**Trade-offs:** if the live data is ever migrated, a mapping step is needed (status `'geplant'`→`'planned'`, urgency `'normal'`→?, `bigint`→`integer`). That is cheaper than importing weaker rules.
**Supersedes:** the "replace with live pull" part of ADR-008.

### ADR-023 — Field tool scope before the assignment decision (F1/F2)
**Status:** PROPOSED · **Tasks:** F1, F2 · ROADMAP Gate 2.
**Context:** the field tool is the product core, but who a visit is assigned to (team, nurse, both — D-6) and the full state list (incl. `assigned`, `accepted`, `cancelled`, `no_show`) need an owner/clinical decision.
**Decision:**
- *Own visits* = visits of the caller's teams (`public.field_visits(date)`, SECURITY INVOKER, minimal client context, no health/billing fields). This matches Teamautonomie and the T9 write rule.
- The **linear part of the documented DOMAIN_RULES draft** is implemented now: `planned → on_the_way → started ↔ paused → completed`, plus the existing `planned → started`. Each transition is an audited, idempotent command. The database trigger enforces the allowed pairs for every write path.
- Every status change writes one row in append-only `visit_events` (actor, time, command, key), by trigger. App users cannot write events. Travel, care and pause are derived from events in pure TypeScript and shown to the team, but they are **not** payroll or billing facts.
- Nurses (only role `nurse`) land on `/field`; other roles land on `/operations`. Derived from database roles, not from the request.
**Not decided here:** assignment model, `assigned/accepted/cancelled/no_show`, who may correct times (F3 will require a reason and keep the original).
**Trade-offs:** if D-6 picks per-nurse assignment, `field_visits()` gains one filter and the e2e/pgTAP fixtures change. The event model stays.

### ADR-024 — Time corrections are append-only records with a reason (F3)
**Status:** PROPOSED · **Task:** F3 · DOMAIN_RULES "keine stillen Zeitkorrekturen", ROADMAP Gate 2 "Zeitsegmente mit Korrekturevents".
**Decision:** a visit event is never edited. A correction is a row in `visit_time_corrections` (event, corrected time, reason of 5–500 characters, actor, time, idempotency key). The effective time is the latest correction; the recorded time and the reason stay visible to the team. The database refuses corrections in the future and corrections that would put the timeline out of order, so durations are never negative. Team members may correct (Teamautonomie).
**Implementation note:** `correct_visit_time()` is `SECURITY DEFINER` because app users have no INSERT privilege on the table. It checks organisation and team membership with the caller's `auth.uid()`, has an empty `search_path`, and is pgTAP-tested for coach, foreign organisation and direct-insert paths (same pattern as SR-23).
**Open:** whether corrections need a second person's confirmation (review/approval) before they count for payroll. That is a Q4/D-6 question and is not modelled. Corrections are not payroll facts today.

### ADR-025 — Observations: free text with provenance, versioned, team-only (F4)
**Status:** PROPOSED · **Task:** F4 · ROADMAP Gate 2 item 3; DOMAIN_RULES "Dokumentation".
**Decision:**
- `visit_observations` stores free text with author (`auth.uid()`), server time and source (`direct`; voice/AI sources arrive with Gate 3). There are no clinical categories, scores or rules until a validated source exists.
- Observations are immutable. A change is a new version that supersedes exactly one previous version (`supersedes_id`, one successor); only the latest version is shown, and older versions stay for audit.
- **Visibility is the visit's team only.** That is stricter than the organisation-wide read of the legacy care tables (SR-22) and applies option B of D-3 to new health data. A coach of the same organisation outside the team cannot read observations.
- Recording is possible from departure on (`on_the_way`, `started`, `paused`, `completed`), for team members only. It goes through `record_observation()` (SECURITY DEFINER, explicit org and team checks; same pattern as ADR-024).
- **Handover:** observations marked for handover are shown on the same client's visits of the same team for 14 days. 14 days is a display default, not a clinical rule; product can change it.
- `field_notes()` returns `own` (written by the caller) instead of author IDs.
**Open:** whether coaches or quality roles may read observations (D-3/Q4), and whether handover should also reach other teams that care for the same client (care-relationship model, D-3 option C).

### ADR-026 — Referral intake creates the case and an open matching request; teams pull (J1)
**Status:** PROPOSED · **Task:** J1 · ARCHITECTURE.md data flow `partner_requests → cases → matching_requests`; DOMAIN_RULES "Fall/Matching".
**Decision:**
- Organisation roles `admin` and `operations` record referrals and convert them after review (placeholder roles, Q4). Coaches are excluded (they coach, they don't dispatch).
- Conversion is one atomic, idempotent command. It creates the case (status `neu`, **no team**) and an **open matching request** for the case's region and services, and marks the referral `converted`. It does not select, rank or notify teams. The team decision belongs to the teams (J2). This reads "Operations löst Matching nicht aus" as "Operations does not choose the team". Q3 stays open for the dashboard wording.
- **Consent gate (provisional):** conversion requires an explicit confirmation that the client's consent to processing is present. Who confirmed and when is stored on the case. Whether consent is the right legal basis, and what must be documented, is a **legal decision** (DECISIONS_NEEDED D-9).
- Inserts and status changes on `partner_requests`, `cases` and `matching_requests` are now audited, with allowlisted columns only (no names or need text).
**Trade-offs:** intake stores client names at conversion time, the minimum needed to deliver care. Contact and health details (phone, address, diagnoses) are not collected by this flow.

### ADR-027 — Team decision by team pull, with honest hard filters (J2)
**Status:** PROPOSED · **Task:** J2 · ARCHITECTURE workflow *Matching → Teamentscheid*; DOMAIN_RULES Teamautonomie and matching hard filters; ROADMAP Gate 4 "atomarer Teamentscheid".
**Decision:**
- An open matching request is offered to **active teams in the same region**. These are the only documented hard filters today's data can evaluate. Competence, verified qualification, actual capacity and safety holds are **not evaluated** and are shown as "nicht automatisch geprüft". There is no ranking or fit score (legacy scores are DEPRECATED).
- Before acceptance, teams see title, region, urgency and services, but **no client identity** (data minimisation).
- Any member of an offered team may accept or decline for the team. Decisions go into append-only `team_decisions`, with at most one decision per team and request. The first acceptance assigns the case atomically (row lock): the case becomes `laufend` with the team and the request becomes `accepted`. A later acceptance gets `taken`. A decline doesn't block other teams.
- Audited through the J1 audit triggers (`decide_matching_request`).
**Not decided:** whether a team decision needs more than one member (team-internal decision rules: team agreements, Gate 4); how offers reach other regions or a matching engine (Gate 4 dry run).

### ADR-028 — The team plans its own visits; no dispatcher role (J3)
**Status:** PROPOSED · **Task:** J3 · ARCHITECTURE workflow *Teamentscheid → Teamplanung → Einsatz*; DOMAIN_RULES Teamautonomie ("kein Linienvorgesetzter durch UI-/Rollenmodell").
**Decision:**
- Members of the team a case is assigned to may plan, move and remove **planned** visits of that case. Coaches, operations and admins cannot plan for a team. The data model and commands contain no dispatcher path.
- Planned visits belong to the team (assignee = team until D-6).
- Validation is about typing errors, not care rules: end after start, dates from yesterday to 366 days ahead (Swiss calendar).
- Started or completed visits are facts and cannot be moved or removed. A planned visit with events, observations, notes or quality events cannot be removed either. Removing a plan is a delete, audited with the command. Cancelling a confirmed visit with consequences for the client is D-6.
- Visit inserts and deletes are now audited too (updates since T10).
- `team_cases()` shows the team its running cases with name, region, needs and upcoming visits, and no health fields.
**Open:** team-internal planning rules (who in the team plans, conflicts, substitution) are team agreements (Gate 4). Capacity per time window is J4.

### ADR-029 — Intake funding facts, readiness gate and protected insurer data (J1, PO changes)
**Status:** PROPOSED · **Task:** J1 (brief `docs/agents/briefs/J1.md`, PO changes-requested 2026-10-21).
**Decision:**
- The case stores the funding facts the brief lists: residence municipality and canton (validated against the 26 cantons), insurer and insurance type (`KVG, IV, UV, MV, private, unknown`), medical order status (`present, requested, not-required-A/C-only`) with validity end, GP named, other providers active, requested start, and language and access notes. Each case links to exactly one source referral (unique).
- **Readiness** is computed by the database (`private.case_readiness`). It returns the missing blocking items with German reasons: consent, residence, insurer, insurance type, care need, requested start. The **matching request is opened only by the server when the case is ready** (conversion or later completion), never from Operations. Insurance type `unknown` counts as missing because such a case cannot be billed; the PO may overrule.
- Missing **non-blocking** items (GP, other providers, language, access) become `case_tasks` that close automatically once the fact is recorded.
- **Insurer and medical-order columns are not readable through the table API.** `authenticated` gets column-level SELECT on all other case columns. Funding facts are read only through `case_funding_facts()`, for intake roles and the case's assigned team. New `cases` columns are default-deny until a migration grants them (TD-31).
- Audited: readiness, canton, insurance type and order status (no names or free text).
**Open:** clinical sign-off of the checklist (D-15); the safety-alert list (D-17); the legal basis for collecting insurer data at intake (D-9). Partners have no accounts; referrals are recorded by admin/operations.
