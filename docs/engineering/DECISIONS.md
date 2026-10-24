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

### ADR-030 — Visit planning with billable basis (J3, PO changes)
**Status:** PROPOSED · **Task:** J3 (brief `docs/agents/briefs/J3.md`, PO changes-requested 2026-10-21).
**Decision:**
- **Member qualification is data** (`team_memberships.qualification`: `registered_nurse` | `care_assistant`). This also covers an F0 criterion.
- **Care-plan summary** (`care_plan_items`), maintained by the assigned team: service, KLV category A/B/C, planned minutes per visit, frequency, review date and an optional care goal. Items are retired with a reason, never deleted. Readable by the team only. The team chooses the category; there is **no automatic service→category mapping** until `clinical` approves one (D-15).
- **Each visit stores planned minutes per category** (A, B, C), never only a total. The total cannot exceed the time window.
- **Needs assessment first** (KLV Art. 8a). The first visit of a case is the needs assessment, category A only. Until it is completed it is the only visit that can be planned, and completing it marks the case.
- **Category B** is planned only when the case's medical order status is `present`. A B visit after the order's validity end is allowed but flagged `order_expired`.
- **Registered nurse:** a responsible member for a B or needs-assessment visit must be a registered nurse. *Whoever starts* such a visit must be a registered nurse of the team; the database refuses otherwise (SQLSTATE `NV001`), on every write path.
- A/C visits without an order open an **"inform GP"** case task. Visits after the earliest active review date are flagged `reassessment_due`.
- **Plan, move and remove keep the original:** `visit_plan_changes` is append-only (before, after, reason, actor). Moves and removals require a reason.
- A planned visit in the next 24 h without a responsible member is **uncovered**. The team sees the flag, and Operations gets a P2 exception without client identity (`uncovered_visits()`, thresholds Q9).
- `/field` shows minutes per category, the needs-assessment marker, responsibility and the case's care goals.
**Open:** D-15 (clinical sign-off of fields and category mapping), D-6 (assignment model), D-10 (countersignature), Q9 (exception thresholds).

### ADR-031 — Team-scoped clinical read; health fields off the table API (F0 step 1)
**Status:** PROPOSED · **Task:** F0 criteria 3c/3d (`docs/agents/briefs/F0.md`, report `docs/agents/reports/F0.md`). Supersedes the T9 placeholder "any org member reads all" (ADR-018) for the legacy care tables, and closes SR-22.
**Why:** the approved F0 brief requires that "a team member not on the case's team cannot read its clinical data". That is D-3 option B, now a product requirement.
**Decision:**
- **Rows:** members without a coordination role (nurses) read `cases`, `care_visits`, `care_notes` and `quality_events` only for their own teams. Coordination roles (`admin`, `coach`, `operations`; placeholders) keep organisation-wide read for Operations and intake. `partner_requests`, `matching_requests` and `match_candidates` are readable by coordination roles only; teams see offers through `team_offers()`.
- **Columns:** health fields of `cases` (date of birth, gender, phone, emergency contacts, mobility and cognitive status, diagnosis tags, care level, legacy insurance field, notes) and `care_notes.content` are not readable through the table API by anyone. No screen used them. A team-only read model follows when a screen needs them.
- Read models used by teams keep working: they read granted columns (`field_visits`) or are SECURITY DEFINER with membership checks.
**Benefits:** a nurse who joins a second team does not gain the organisation's clinical history. Operations dashboards cannot leak health fields even through a mistaken select.
**Migration plan:** migration 0015 only (no data change). Rollback: recreate `org_members_read` policies and the column grants.
**Open:** final role names and matrix (D-3/Q4); break-glass (out of F0 scope).

### ADR-032 — Signed visit report as its own versioned lifecycle (F6)
**Status:** PROPOSED · **Task:** F6 (`docs/agents/briefs/F6.md`, queue rank 4). Handbook chain: "… → menschlich freigegebener Bericht → Quality Gate → billable_facts".
**Why:** the brief requires that a report be built from the field data without re-entry, signed by the performing nurse, immutable once signed, corrected only as a new version, and that only a final report counts. The legacy `care_notes` table (free-text content, status draft/submitted/approved, no signer) cannot express that safely.
**Decision:**
- New table `visit_reports`, one row per **version** (`visit_id`, `version`, `supersedes_id`, `correction_reason`). The visit itself stays a fact ending at `completed`; the report has its own states: `draft` → `signed` → `final`, or `draft` → `final` when no countersignature is needed.
- The draft is a **server-built snapshot** (jsonb): planned slot and minutes per KLV category, the needs-assessment flag, services, effective event times (latest correction plus reason), and the current observations with their handover flag. The nurse adds an optional summary. The snapshot is refreshed when the draft is edited and frozen at signing.
- **Performing nurse** = actor of the visit's first `started` event (F2). Only she creates and edits the draft and signs it. A visit without a recorded start cannot get a report (`no_performer`).
- **Countersignature (provisional until D-10):** required whenever the performer is not a registered nurse of the team. This is stricter than the D-10 recommendation (B and needs assessment, C to be confirmed). Care assistants cannot start B or needs-assessment visits anyway (NV001), so today it covers their A and C visits. A registered nurse of the team other than the performer countersigns.
- **Immutability** is enforced by a trigger for every role, including roles that bypass RLS. A final row never changes; a signed row may only gain the countersignature; no row is ever deleted. A correction is a new draft version (reason 3–300 characters, any team member), signed again by the performer. Only the latest version can be corrected. Until the correction is final, the previous final version stays the valid report.
- **Scope:** read, sign, countersign and correct are limited to members of the visit's team (RLS plus explicit checks in SECURITY DEFINER commands). Operations gets only `final_report_visits()` (visit ids, no content), and the "report missing" attention item closes when a final report exists.
- Commands are idempotent (`begin_command`/`end_command`) and audited (status, version, signed_by, countersigned_by, countersign_required).
**Benefits:** billing and the quality gate can later rely on "final report exists", with signer, time and version history, without trusting free text.
**Migration plan:** migration 0016 adds objects only (no data change). Rollback: drop the commands, read models, trigger and `visit_reports`. Legacy `care_notes` stay read-only for history, and an approved legacy note still closes the Operations item.
**Open:** D-10 (countersignature scope, `clinical`); whether a registered nurse other than the performer may sign when the performer has left the team (owner/clinical; today: not possible); report export/PDF (not in the brief).

### ADR-033 — Team decision workflow: eligibility, reasons, deadlines as configuration, escalation (J2 changes)
**Status:** PROPOSED · **Task:** J2 PO changes (`docs/agents/briefs/J2.md`, queue rank 5) plus F0 criterion 4. Extends ADR-027.
**Why:** #24 had team pull and atomic acceptance but no qualification check, no decline reasons, no response time and no escalation. The brief requires that no case wait silently and that nothing be auto-assigned.
**Decision:**
- **Offer fields** before acceptance: care need, region, requested start (J1), expected hours per week (new optional intake fact), required qualification, and response deadline. Still no identity or funding data.
- **Required qualification is derived, not invented:** a registered nurse is required while the needs assessment is not done (J3: only a registered nurse starts it, NV001) or when a medical order is present (J3: category B needs an order and a registered nurse). Otherwise no particular qualification. The clinical sign-off belongs to D-15.
- **Eligibility** = active team, same region, and a registered-nurse member when required. A team that is not eligible neither sees the offer nor can accept (`not_qualified`).
- **Decline** needs a reason code from the brief's v1 list (`capacity`, `qualification`, `distance`, `other`); `other` needs a short text. The old 5-argument command is replaced by one with an optional sixth argument, so an acceptance call is unchanged.
- **Response deadline** = configuration `response_deadlines(organization or platform, referral type, amount, unit)`. Platform rows hold the **PO pilot defaults (Q8)**: hospital discharge 4 working hours, nursing home 1 working day, private 2 working days. Type `other` has no default. Admins override per organisation through `set_response_deadline` (audited, idempotent), and open requests are recalculated. Referral type is derived from the J1 partner type (Spital → hospital discharge, Pflegeheim → nursing home, Privat / Angehörige → private, otherwise other).
- **Working time** = a one-row calendar `working_time`, **provisionally** Monday–Friday 08:00–18:00 Europe/Zurich without public holidays (Q10 asks the PO). `private.add_working_time` starts at the next opening when a request arrives outside working time; working days keep the clock time.
- **Escalation** is a read model `matching_escalations()` for coordination roles: no eligible team, all eligible teams declined, deadline passed, or deadline not configured, each with all decline reasons. Operations shows these as P1 (P2 for "not configured"). Nothing is assigned automatically; the request stays open.
- **Scope:** `team_decisions` is readable by the deciding team and by coordination roles only (it was organisation-wide).
**Benefits:** partners get a dependable answer path; Operations sees every stuck search with reasons; teams keep their autonomy.
**Migration plan:** migration 0017 adds columns, configuration tables (with the PO defaults) and functions, and backfills derived facts and deadlines on open requests. The decline-code constraint is `NOT VALID`, so older declines without a code stay readable. Rollback: restore the 0011 command and `team_offers`, drop the new objects.
**Open:** Q10 (working-time definition, holidays), D-15 (clinical confirmation of the qualification derivation), an admin screen for deadlines (today command only).

### ADR-034 — Mandatory reasons and qualification administration (F0 remainder, D-5)
**Status:** PROPOSED · **Task:** F0 (`docs/agents/briefs/F0.md`, PO update 22:20 item 2 and the D-5 criteria).
**Why:** the PO rule says a reason is mandatory when a command changes or undoes something already recorded, or overrides a safety or billing rule. D-5 (owner): only NAVORA administrators manage member qualifications, and each member has exactly one.
**Decision:**
- **Reasons already enforced:** time corrections, plan move and remove, care-plan retirement, team decline, report correction.
- **Added:**
  - `update_case_intake` requires a reason when insurer, insurance type or medical-order status changes on a case that is already ready for matching. Adding other facts needs none.
  - New `set_member_qualification` requires a reason.
- **`change_log`:** a new append-only table storing old → new values with the reason. It complements `audit_events` (who, when, what). Coordination roles read it.
- **Not built yet, so nothing to enforce today:** case pause, close and reopen; visit cancellation and no-show; lifting a quality hold (QG1). A structural pgTAP guard fails if a future public function with such a name lacks a `p_reason` argument. A second guard lists every command on the PO list.
- **Qualification:** `team_memberships.qualification` is NOT NULL, `registered_nurse` or `care_assistant`. It is changed only by `set_member_qualification` (admin of the team's organisation, reason required, audited, idempotent; returns `unchanged` for the same value). It is read by the member's own team and the organisation's coordination roles; nobody outside the organisation reads it. A nurse has no update privilege on memberships.
- **One shared rule:** `private.is_registered_nurse(team, user)` is the only reader of the qualification. J2's `team_has_registered_nurse` now calls it.
**Migration plan:** migration 0018; rows without a qualification would be set to `care_assistant`, the less privileged value. There are none in the seed. Rollback: drop the new function, table and policies; restore the 3-argument `update_case_intake`.
**Open:** an admin screen for qualifications (D-5 says NAVORA administrators; today command only); reasons on case and visit lifecycle commands when those commands are built.

### ADR-035 — Operations exception center: exceptions derived in the database, handling as events (OPS1)
**Status:** PROPOSED · **Task:** OPS1 (`docs/agents/briefs/OPS1.md`; thresholds Q9).
**Why:** J1–J3 and F6 create exceptions, but the attention list derived some of them in TypeScript, without configuration, handling or a trace. The brief asks for one list derived from state, with take-over, comments and closing with a reason, and auto-close when the cause is fixed.
**Decision:**
- **`exception_rules`** (configuration) holds type, priority, threshold (hours, days or working days) and an optional P1 escalation, with the Q9 pilot defaults. Its ten types: case not ready for matching after 1 working day; offer past its deadline; candidates exhausted; no deadline for the referral type; uncovered visit within 24 h (P1 for a hospital-discharge case, else P2); order expiring within 7 days or expired; care-plan review overdue; serious quality event open (high or critical; shown at once as P2, P1 after 4 h); report not final 24 h after the visit ended.
- **`private.derived_exceptions(org)`** derives every open cause from state. Each has a stable key `<type>:<entity>[:<cause>]`, so a new cause, such as a new order date, is a new exception.
- **`public.operations_exceptions()`** (coordination roles only) adds priority, label, next step, case label, region, team, handling state and comments. It shows no health fields, and there are no assignment or case-editing actions.
- **`exception_events`** (append-only): `take`, `comment`, `close` (reason required) through `handle_exception`; `auto_close` with a note through `sync_exceptions()`, which the Operations page calls on load. A closed exception stays closed for that cause.
- **Moved out of the TypeScript attention list:** missing report (now "not final 24 h after the end", using the F6 final report), uncovered visits, J2 escalations and serious quality events. The remaining legacy heuristics (team load, cases without a team, open referrals, minor quality events) stay below as "Weitere Hinweise", marked unvalidated.
**Deviation for the PO:** a serious quality event shows immediately, as P2, and becomes P1 after 4 h (Q9). Hiding it for 4 hours would be less safe.
**Migration plan:** migration 0019 (new tables and functions only). Rollback: drop them and restore the TypeScript rules from #36.
**Open:** an admin screen for rule configuration (today by migration); QG1 replaces the legacy quality source.

### ADR-036 — Quality events and quality holds: mechanism now, clinical list after D-16 (QG1)
**Status:** PROPOSED · **Task:** QG1 (`docs/agents/briefs/QG1.md`).
**Why:** ARCHITECTURE puts a Quality Gate before any billing fact. The brief needs a clinically approved event list (D-16), but everything around it is mechanism and must not wait.
**Decision:**
- **Event types:** `quality_event_types` holds code, label, `sets_hold`, `serious_default` and the approval reference. It **ships empty**, so no clinical content is invented. Until D-16 fills it by migration, recording is refused (`type_not_approved`) and `/field` explains why.
- **Severity:** the existing four values (low, medium, high, critical). Serious = high or critical, the same rule as OPS1.
- **Recording:** `record_quality_event` stores type, severity, time, case, visit and author. It is idempotent and audited, and it sets a hold when the type has `sets_hold`.
- **Visibility:** the assigned team; serious events also coach and admin; other teams never. Operations reads no event content and sees serious events as OPS1 exceptions. The brief's "quality specialist" role does not exist yet (D-3).
- **Status:** open → in_review (the caller becomes owner) → closed (closing note required). Transitions go to the append-only `quality_event_log`.
- **Holds:** `quality_holds` allows one open hold per visit. A hold is set by a flagged type or manually by the team, coach or admin, with a reason. It is lifted only by coach or admin with a reason; this is provisional and stricter until D-16 names the role. Holds are immutable apart from the single lift, never deleted, and audited.
- **Billing rule:** `private.visit_has_open_hold(visit)` is the single check J5 must use: a held visit never counts.
**Side effect:** coordination roles other than coach and admin no longer read minor quality events through the table. The Operations quality KPI now counts serious-event exceptions.
**Migration plan:** migration 0020; new tables and functions, `NOT VALID` checks on the legacy status and severity values, and a tightened read policy. Rollback: drop the new objects and restore the 0015 policy.
**Open:** D-16 (types, hold rules, who lifts); D-3 (quality specialist role).

### ADR-037 — Primary nurse per case and a per-client continuity measure (J6)
**Status:** PROPOSED · **Task:** J6 (`docs/agents/briefs/J6.md`). Builds on J3's accepted model (team plus responsible member, D-6).
**Answer to the brief's question:** the responsible member (D-6) is per **visit**, and J6's primary nurse is per **case**. They complement each other: the visit's responsible member is compared against the case's primary nurse and deputy.
**Decision:**
- **Primary nurse and deputy:** `cases.primary_nurse_id` and the optional `deputy_nurse_id`, both members of the assigned team and different from each other. They are set by a member of that team through `set_primary_nurse`. The first assignment needs no reason; a change needs one (F0 rule), stored in `change_log` and audited. An active case without a primary nurse is shown on the team card.
- **Planning flag:** `visit_flags` adds `not_primary` when the visit's responsible member is neither the primary nurse nor the deputy. It never blocks planning.
- **Measure:** `continuity_by_case(month)` returns, per client, the completed visits, the distinct performing nurses (from the F2 start events) and the primary nurse's share. Teams see their cases and coordination roles see the organisation. **No per-nurse figures are returned**, so the measure cannot become a ranking.
**Migration plan:** migration 0021 (new columns and functions, `visit_flags` and `team_cases` redefined). Rollback: restore both functions from 0014 and drop the rest.
**Open:** whether a hard continuity limit is ever wanted (out of scope until pilot data); names for members once profiles exist (D-5).

### ADR-038 — Billable facts and an estimate preview, driven by versioned reference data (J5)
**Status:** PROPOSED · **Task:** J5 (`docs/agents/briefs/J5.md`). No invoice: D-12 gates real invoicing, which is out of scope.
**Decision:**
- **Reference data:** `tariff_rates` (region CH or canton, payer, KLV category, amount, unit, validity, version, source) and `billing_rules` (minimum billable minutes, dated, per region). A canton row overrides the federal one. **Shipped:** the federal insurer contributions per hour, A 76.90 / B 63.00 / C 52.60 CHF valid from 2026-01-01, with the source cited, and the 10-minute minimum from the brief. **Not shipped:** patient contribution and residual financing, which are cantonal and wait for D-11. The preview says "not on file".
- **Facts:** `billable_facts` holds one immutable fact per final report version, created only when the report is final (F6) and the visit has no open quality hold (QG1). Each fact records planned minutes per category, measured care minutes (from the F2 events, with F3 corrections), the payer chain, the order basis (with order / without order A/C / B without a valid order), the tariff version per category, the billable flag with reasons (B without a valid order, no insurer, below minimum, no planned minutes, no measured time) and warnings. A corrected report creates a new fact that references the old one.
- **Working time:** `working_time_facts` is a separate type (travel, care and pause per visit and performer).
- **Generation:** `generate_billable_facts(month)` is idempotent and can be run by the team or coordination roles.
- **Preview:** `billing_preview(month)` gives, per team, billable minutes per category, the insurer estimate (only from rates on file; incomplete coverage is marked) and every completed visit that is not billable, with its reason. A hold set after the fact stops the visit from counting.
- **Read scope:** facts carry insurer data, so they are readable by the team and intake roles only (J1). The preview carries no insurer data.
**Provisional (Q11, PO):** the billable minutes are the **planned minutes per category** of the signed report, because actual time is measured per visit, not per category. Measured care minutes below the planned total raise the warning `actual_below_planned`.
**Migration plan:** migration 0022 (new tables and functions plus reference rows). Rollback: drop them.
**Open:** Q11 (which minutes count), D-11 (cantonal rates and the minimum per canton), D-15 (KLV category mapping).

### ADR-039 — Autonomous PO ↔ Engineering coordination through GitHub
**Status:** ACCEPTED (owner request 2026-10-22: "the user should no longer be required as a messenger"). Details: `docs/agents/COORDINATION.md`.
**Decision:**
- **Source of truth:** the three official files remain it; GitHub issues are derived from them and never edited by hand.
- **Watcher:** a pure planner (`scripts/agents-coordination/plan.mjs`, unit-tested) computes hand-offs: implement or address changes (`agent:eng`, highest-ranked unblocked = `active`), review (`agent:po`, on `delivered`), and decisions (`human-decision` assigned to the owner, or the owning agent).
- **Sync:** a GitHub Action (`agents-coordination.yml`) runs it on every push to the files, hourly and on demand. It syncs issues idempotently with the repository `GITHUB_TOKEN` (issues: write only).
- **Agents:** two scheduled cloud tasks, a PO agent and an Engineering agent (hourly), pick up their issues and act through pull requests. A claim label prevents two sessions from working on one item.
**Why this design:** state-based reconciliation is robust against missed events and reruns. Agents need no new credentials. The only humans contacted are decision owners.
**Alternatives:** Claude Code GitHub Action triggered by issue labels (needs an API-key secret: owner decision); webhooks to an external service (more infrastructure, no benefit for a pilot).
**Rollback:** disable the workflow and the two scheduled tasks. The files keep working as before.

### ADR-040 — Billable minutes follow measured care time (J5 change, answers Q11)
**Status:** PROPOSED · amends ADR-038 · **Task:** J5 changes-requested (PO review 2026-10-22 12:00).
**Decision:**
- **Measured below planned:** billable minutes per category = planned minutes per category × (measured ÷ planned) when measured care time is below the planned total (warning `scaled_to_measured`). The sum never exceeds the measured minutes.
- **Measured above planned:** the planned minutes are billed, never more; warning `above_plan` so the team reviews the care plan (J3).
- **Minimum duration:** checked on the billable minutes after the rule.
- **Exact minutes:** measured from second-precise effective event times (F3 corrections, pauses removed), two decimals. No rounding or time units until D-18 is answered.
- **Rule versions:** facts carry `rule_version` (`J5-v1` before, `J5-v2` now). Facts are still immutable: a v1 fact is not rewritten, generation adds a v2 fact that references it. Uniqueness is now (report, rule version).
- **Preview:** uses the billable minutes. Facts that predate the rule fall back to planned minutes until they are recalculated, which happens on the next generation.
**Migration plan:** migration 0023 (columns, constraint swap, two functions). Rollback: restore the 0022 builder and preview; new columns stay unused.

### ADR-041 — Case and visit lifecycle (C1)
**Status:** PROPOSED · **Task:** C1 (`docs/agents/briefs/C1.md`).
**Decision:**
- **Case lifecycle:** `cases.lifecycle` (active, paused, closed) plus the append-only `case_lifecycle_events` (reason code, note, expected end, actor). Legacy `cases.status` follows (closed = `abgeschlossen`), so existing read models keep working.
- **Pause (answer to the brief's question):** a reversible marker `care_visits.suspended_at`, not a visit state, because resume must restore the visits. Planned visits inside the pause are suspended. Suspended visits cannot start (transition trigger) and are not "uncovered" (OPS1 and `visit_flags`). They never complete, so they produce no report or billing fact. Resume reactivates the suspended visits that still lie ahead.
- **Close:** cancels all future planned visits with the close reason, closes open case tasks, ends the primary-nurse assignment and withdraws open matching requests. Reports, quality events and facts are untouched.
- **Reopen** (team or Operations, with a reason): sets `reopened_at`. A planning guard on `care_visits` insert refuses new visits for paused or closed cases (NV002) and, after a reopen, until the J1 readiness check passes (NV003).
- **Visit end states:** `cancelled` (before start: planned or on the way) and `no_show` (after arrival: on the way) are visit events. Reasons and outcomes go to the append-only `visit_status_notes`.
- **OPS1:** a no-show is a P1 exception immediately, open until the team records the outcome. A team cancellation within 24 h of the visit is a P2 exception (configurable rule). The app gives no on-site instructions until D-19 is answered.
- **Rules applied throughout:** every command takes a reason where the F0 rule requires one (the ADR-034 guard checks the signatures), and is audited and idempotent. Pause, resume, cancel and no-show are for the assigned team; close and reopen for the team or Operations (admin or operations role).
**Migration plan:** migration 0024. Rollback: drop the new objects and restore the 0014 transition trigger, the 0021 `visit_flags` and the 0019 exception derivation.
**Open:** D-6 (clinical confirmation of the visit states), D-19 (on-site no-show protocol). The suspended state is not yet shown on `/field`: starting a suspended visit is refused with a message.

### ADR-042 — Self-planning: visits follow the care plan (PLAN2)
**Status:** PROPOSED · **Task:** PLAN2 (`docs/agents/briefs/PLAN2.md`).
**Decision:**
- **Structured frequency** on `care_plan_items` (a planning field, not a clinical one): once a day, or 1–7 times a week with optional ISO weekdays (exactly one per visit), plus a time window. The free text stays as a note. Without a rhythm and a window an item is not planned automatically, and the team sees it listed. A second daily visit is a second item with its own window, which keeps the rule simple and visible. Without named weekdays a weekly rhythm is spread evenly (2× → Mo, Do; 3× → Mo, Mi, Fr). This is a planning default, not a clinical rule.
- **Rolling window:** tomorrow plus 27 days, so four weeks. Items due on the same day in the same window form one visit, with minutes summed per KLV category. A day whose minutes do not fit the window is not planned, and the team gets a reason.
- **Responsibility:** the primary nurse; if she may not do the work (category B needs a registered nurse), the deputy under the same rule; otherwise nobody, which raises the existing `uncovered` flag.
- **J3 rules unchanged:**
  - nothing is generated before the needs assessment;
  - B minutes only with a present order and never after its validity end (they are left out, with a reason);
  - an A/C visit without an order opens the inform-GP task.
- **The team stays in charge:**
  - a generated visit that was moved, started, cancelled or suspended is "touched" and never overwritten;
  - a slot the team removed is remembered (`plan_slot_skips`) and not recreated;
  - only future untouched generated visits are regenerated or dropped;
  - every generated, regenerated or dropped visit is in `visit_plan_changes` with the reason "care plan" (new change type `regenerated`).
- **C1:** nothing is generated for a paused or closed case, or for a reopened case that is not ready. Switching the series off (`set_auto_planning`, with a reason) drops the future untouched visits.
- **Reliability (answer to the brief's question):** generation runs
  - in triggers on care-plan and relevant case changes (primary nurse, deputy, lifecycle, order, needs assessment, series switch);
  - on the team action "Jetzt planen";
  - on every `/team` load for cases not yet generated today (`refresh_team_plans`, the OPS1 sync-on-load pattern);
  - daily through `pg_cron` where the extension can be enabled (job `navora-plan2-daily`, 01:15 UTC). Without pg_cron, the migration logs a notice and the other three paths keep the window current.

  The system actor for unattended runs is the nil UUID.
- **AN1 can measure:** `care_visits.plan_generated` (share of visits created automatically) and `visit_plan_changes` by team members (planning actions per client and week).
**Migration plan:** migration 0025. New columns, one table, functions and triggers; the `visit_plan_changes.change` check is widened; `team_cases` care-plan and visit JSON gain the rhythm and a `generated` flag.
**Rollback:**
1. Run `cron.unschedule('navora-plan2-daily')` if the job exists.
2. Drop the triggers `care_plan_items_regenerate`, `cases_regenerate_plan` and `care_visits_remember_removed_slot`.
3. Drop the new functions.

Generated visits stay ordinary planned visits.
**Open:** the evenly spread default weekdays and the four-week horizon are engineering defaults for the PO to confirm. Absences are not modelled, so "cannot do the work" means qualification only.

### ADR-043 — Sign at completion (F7)
**Status:** PROPOSED · **Task:** F7 (`docs/agents/briefs/F7.md`).
**Decision (answer to the brief's question):** no new report state.
- **Completion opens the draft.** Completing a visit on `/field` creates the F6 draft from the visit data immediately (`create_report_draft` right after `complete_visit`). The card then shows "Bericht prüfen und unterschreiben" with:
  - the facts the draft took over (time, planned minutes per category, services, number of observations);
  - the optional summary;
  - one "Bericht unterschreiben" button.
- **One confirmation.** If the nurse changed the summary, it is saved to the draft first (`update_report_draft`), then the report is signed (`sign_report`). Both are the unchanged F6 commands: idempotent, audited, performer only.
- **Signing later is unchanged:** the draft stays open, and the OPS1 "report not final" exception applies.
- **Countersignature:** `field_countersign_queue()` lists, for a registered nurse, every signed report of her teams that waits for her countersignature, on any date. `/field` shows it at the top. The D-10 rule is unchanged.
- **AN1 can measure:** time from visit end to final report (`visit_events` completed → `visit_reports.signed_at` / `countersigned_at`), and the share signed within 10 minutes.
**Migration plan:** migration 0026 (one read function). Rollback: drop it; the app falls back to the F6 buttons.
**Open:** if the draft cannot be created (no recorded start), the F6 "create" step stays on the card with its message.

### ADR-044 — Pilot impact dashboard, computed live (AN1)
**Status:** PROPOSED · **Task:** AN1 (`docs/agents/briefs/AN1.md`).
**Decision:**
- **One read model:** `pilot_kpis(month)` returns aggregates per team and for the organisation. Each row has its base count and a "too few data" mark below 5. It is never per nurse and has no client identity or health data; a guard test checks that it has no person columns.
- **Scope:** coordination roles see the organisation and every team. A team member sees only her own teams. The exception KPIs are coordination figures.
- **Live, not nightly (answer to the brief's question):** every KPI is computed from the source tables for one month on request. Pilot volumes are small. A nightly aggregate becomes worthwhile only when one month takes too long to compute; measuring that is the trigger.
- **Definitions** are shown on the page with their source; engineering defaults go to the PO as D-21:
  - **direct care share** = care minutes ÷ (travel + care + pause minutes) of completed visits. Working time outside visits is not recorded, so the figure is an upper bound and is marked as an approximation.
  - **first-offer acceptance** = requests of the month accepted by a team within the response deadline (organisation only).
  - **report final** = from visit end to the signature, or the countersignature where required, of the first version.
- **Not measurable yet** (shown with a note, no value):
  - time to close a P1 exception: the time an exception first appears is not stored. A follow-up would record a `seen` event in `sync_exceptions`.
  - COVER1: not built yet.
**Migration plan:** migration 0027 (one function). Rollback: drop it.

### ADR-045 — Cross-team cover without a dispatcher (COVER1)
**Status:** PROPOSED · **Task:** COVER1 (`docs/agents/briefs/COVER1.md`).
**Decision:**
- **J2 pattern, own tables (answer to the brief's question).** Offers are derived from state, carry no client identity, and the first decision wins atomically. A visit offer has no matching request, so offers are derived per visit and decisions go to the append-only `cover_events` (`offered` when first seen, `accepted`, `expired`).
- **Window:** a planned visit of an active case, with no responsible member and not suspended, whose start is between the fallback lead and the offer lead. Defaults are 4 h and 24 h, in `cover_settings`; an organisation override is possible later through ADM1.
- **Eligible:** members of another active team in the same organisation and region. Category B work and needs assessments go to registered nurses only.
- **Acceptance:** `accept_cover` assigns that one visit atomically (responsible member, `covered_by`, `cover_team_id`). It logs a plan change, so PLAN2 never overwrites the cover. The case, its team and its primary nurse stay unchanged. J6 counts the visit as `not_primary`; J5 and F6 apply as usual.
- **Context access waits for D-3.** RLS keeps the visit with its team. The covering nurse sees her covers with the offer's minimal facts, but she cannot run the visit in the app until the owner decides D-3. The case's team sees which team covered.
- **After the fallback lead** nobody can accept. `sync_cover_offers` (called on `/field` load, the OPS1 sync pattern) records the expiry. The OPS1 uncovered-visit exception is unchanged.
- **AN1:** `cover_without_operations` (offered visits that a neighbouring team accepted) and `cover_median_hours`.
**Migration plan:** migration 0028. Rollback: drop the new objects and the columns, restore `team_cases` and `pilot_kpis` from 0025/0027.
**Open:** D-3 (cross-team context access); notifying nurses outside the app (push, SMS) is not built; the lead times are engineering defaults (D-21).

### ADR-046 — Pilot administration: profiles, invitations, teams and operating rules (ADM1)
**Status:** PROPOSED · **Task:** ADM1 (`docs/agents/briefs/ADM1.md`). Built under D-5 (administrators manage members); D-20 may move admission to the teams.
**Decision:**
- **Profiles (answer to the brief's question):** a separate `member_profiles` table, keyed by organisation and user and bound to the membership. It holds the display name only, never health data. Members of the same organisation can read it; it is written only by commands (an administrator, or the member for her own name). No name is invented: without a profile the neutral labels stay.
- **Names where people appear:** team view (members, primary nurse, deputy, responsible member), report signature and countersignature, quality-event author, the person who took over an exception. A private `member_name()` is called only by readers that already scope the caller.
- **Invitations:** an administrator records email, role, display name, and optionally team and qualification. The invitation expires after 14 days and can be revoked. On sign-in with the confirmed email, `accept_my_invitations()` creates the memberships. Creating the Auth account and sending the e-mail stays outside the app until D-26: sign-up is disabled, and the app holds no service-role key.
- **Members and teams:**
  - Role change, with a reason; the last administrator is kept.
  - Team membership: add, or remove with a reason. Removal is refused while the person is primary nurse or deputy of an open case.
  - Qualification: the existing F0 command.
  - Teams: create, rename, set the region, and deactivate with a reason. Deactivation is refused while the team has open cases, and sets `status = 'closed'`, which J2 already excludes.
- **Operating rules:**
  - Response deadlines use the existing J2 command; the page shows who changed what and when.
  - Exception thresholds and priorities are organisation overrides within safe ranges (D-21): never a lower priority; a P1 alert never later; other thresholds at most twice the default; escalation never later.
  - The OPS1 readers use the effective rules.
- **Tariffs and reference data stay migration-only.** A test proves that no command writes them.
**Migration plan:** migration 0035. The readers are regenerated from their current definitions by checked text patches, so the migration fails loudly if a reader changed. Rollback: drop the new objects and restore the readers from 0019–0028.

#### ADR-046 amendment — ADM1 changes (PO review 2026-10-22 20:15)
- **Removal releases her visits (IMPLEMENTED, migration 0036).** `remove_team_member` now releases, in the same command, every visit of that team where she is the responsible member and that is `planned` (also when suspended by a case pause, CGR-09) and dated today (Europe/Zurich) or later. The responsible member becomes null, so the J3 `uncovered` flag, the OPS1 uncovered-visit exception and (once D-3 allows it) COVER1 see the visit again. Started, on-the-way, paused, completed, cancelled and past visits and other teams' visits are not touched.
- **One release rule:** `private.release_member_visits(team, member, from, until, reason, actor)`, not executable by app roles. ABS1 calls it for an absence period (PLANNED). Each release is one `visit_plan_changes` row (new change type `released`, before/after responsible member, fixed reason "Mitglied aus dem Team entfernt"). The care_visits audit trigger records it under the calling command and key.
- **Privacy (PO pre-review 22:15, IMPLEMENTED):** `visit_plan_changes` is readable by every team member, so the release row carries only the fixed text. The administrator's reason is an employment matter: it stays in `change_log` and the audit, which only the organisation administration reads.
- **CGR-09 (Clinical Governance Report 22:30, blocking, IMPLEMENTED):** suspended visits are released too. Before, `resume_case` reactivated suspended visits with her still responsible, so after a pause they looked covered by a non-member. Chosen remedy: release at removal (one rule, one place). The alternative, `resume_case` clearing an ineligible responsible member, is not built; it would only matter if a membership could disappear another way, and `remove_team_member` is the only command that deletes memberships.
- **CGR-10 (blocking, IMPLEMENTED):** removal returns `has_visit_in_progress` while a visit of that team with her as responsible member is `on_the_way`, `started` or `paused`. She must be able to complete and document it. `/admin` explains the refusal. Residual (OPEN, low): a visit she departs for between the check and the commit of the removal; the release locks her planned visits, and a later start needs her membership.
- **Result:** `remove_team_member` returns jsonb `{result, released}` (was text). `/admin` shows "n Einsätze sind jetzt offen im Team". The `released` change type is not counted in AN1 planning actions or shown in HAND1 "since your last visit", which both list explicit change types. Whether HAND1 should show it is OPEN for the PO.
- **Role change does not touch visits (decided here, the PO's option "she can still start it").** The organisation role and the team membership with its qualification are separate. A nurse who becomes coach or operations keeps her team membership and qualification, so she can still start the visits assigned to her. Removing her from the team is the step that releases them. pgTAP 036 asserts both.
- **Not covered (OPEN, COVER1 off until D-3):** an accepted cover (`covered_by`) by a nurse removed from her own team is not withdrawn. While cover is off, no visit can be covered.
- **Legacy prototype hints removed:** "Weitere Hinweise" on `/operations`, `src/features/operations/rules.ts` and its unit test. The partner-request and quality-event reads that only fed them are gone from the Operations dashboard. The OPS1 exception list is the validated source.
- **Tests:** pgTAP 036 (39 assertions: release set, flag, OPS1, change log with the fixed text, reason only in `change_log`, audit, duplicate, foreign admin; CGR-10 refusal for on the way, started and paused, each alone, nothing released; CGR-09 pause → removal → resume leaves the visits uncovered; role change; report and quality names, another organisation's profile never shown). pgTAP 035 reads `->> 'result'`. Unit `admin-rules.test.ts` (result reader, notice). e2e `admin.spec.ts` (removal notice).

#### ADR-046 amendment — CGR-18: removal checks the performer (Clinical Governance Report 2026-10-23 02:28)
- **Problem (CGR-18, blocking S1):** documentation belongs to the **performer** (first `started` actor, `private.visit_performer`), not the responsible member. Any team member may start any visit of her team, and only the performer, as a team member, may draft and sign the report. 0036 checked only the responsible member, so removing a member who performs a colleague's visit, or whose completed visit has no report or only a draft, left that care permanently undocumentable.
- **Decision (IMPLEMENTED, migration 0037, `create or replace`, same signature and return shape):** `remove_team_member` also refuses
  - `has_visit_in_progress` while she is the performer of a visit of the team that is `on_the_way`, `started` or `paused`;
  - `has_unsigned_reports` (new code) while she is the performer of a `completed` visit of the team with no report in `signed` or `final`.
  `signed` (awaiting countersignature) allows removal, because the countersignature is another registered nurse's step. A correction draft of a final report does not refuse: the final version stays in force.
- **Why refuse, not reassign:** handing the report to someone else is a delegated takeover (PS-11, H-12) and a clinical and legal rule (CR-012). Not invented here. Refusal keeps the safe default and tells the administrator what to wait for.
- **`/admin`:** new message for `has_unsigned_reports` (unit test). The existing `has_visit_in_progress` message covers the performer case.
- **Not built (OPEN):** CGR-19, signing a correction of a departed author's report, waits for a decision (`clinical` + `legal`). ABS1 should apply the same performer check to an absence (PLANNED, ABS1 brief). Residual race as for CGR-10 (OPEN, low): drafting, signing and starting all require the membership row that removal locks and deletes.
- **Tests:** pgTAP 037 (24 assertions) runs the four report cases through the real commands: a care assistant starts a colleague's visit → refused while started and paused, nothing released, she stays a member; completed without a report → `has_unsigned_reports`; draft → refused; signed (awaiting countersignature) → removed and her planned visit released; a registered nurse's final report → removed. pgTAP 035 and 036 unchanged (their removed members performed nothing).

#### ADR-045 amendment — COVER1 safety changes (PO review 2026-10-22 14:30)
- **Cover is off until D-3:** `cover_settings.cover_enabled`, platform default false. While it is off, no visit is open for cover and `accept_cover` returns `disabled`.
- **Acceptance no longer sets the responsible member.** The covering nurse cannot see or start the visit before D-3, so the case team keeps the `uncovered` flag. OPS1 replaces the plain uncovered-visit exception for that visit with `cover_without_access` ("Übernahme ohne Zugriff"): P2, escalating to P1 from 4 h before the start.
- **Withdraw:** `withdraw_cover` (covering nurse, with a reason, up to the fallback lead) offers the visit again and writes the reason into the case team's plan change log.
- **Events at the right time:** `private.sync_all_cover_events()` runs every 10 minutes through pg_cron, where available. The page-load sync stays as a backup. Events are ordered by a sequence, not by the transaction time.
- **Regions:** two empty regions never match.
- **Concurrency:** `scripts/db-concurrency/cover-accept.sh` runs in the CI db job. It has two psql processes accept the same visit at the same time, and exactly one wins. pgTAP runs inside one transaction and cannot open a second session on Supabase, because dblink needs credentials there.
- **Not built yet:** performing the visit as covering nurse (context access, F1–F4, F6/F7). It waits for D-3. Until then cover stays off.

#### ADR-042 amendment — PLAN2 changes (PO review 2026-10-22 14:30)
- **No double planning:** generation never adds a visit next to a non-cancelled visit of the case in the same day and time window (planned by hand, moved there, or covered). The slot is logged once as `skipped` with the reason "care plan: already planned", and an untouched generated double is dropped. The plan log gains the change type `skipped`.
- **Withdrawn preconditions** drop future untouched generated visits, each logged with its reason: case closed, reopened and not ready, needs assessment no longer done (`private.drop_generated_visits`). A paused case keeps them, because C1 suspends and restores them.
- **Plan status** counts upcoming visits with B minutes after the order end (the J3 `order_expired` flag), and the team card shows the count.
- **AN1:** `planning_actions_per_client_week` = the team's own plan changes (planned, moved, removed; not "care plan", not cover) ÷ clients ÷ weeks of the month.
- **Tests:** pgTAP 030 covers no double, the daily job run twice, another team of the same organisation, the order flag, the uncovered path, the needs assessment, close, reopen-not-ready and the KPI.

#### ADR-041 amendment — C1 changes (PO review 2026-10-22 14:30)
- **Close withdraws matching:** it also marks the candidate rows `withdrawn`. pgTAP proves that no team is offered the request any more.
- **Late team cancellation:** the P2 exception stays open until Operations closes it with a reason, or the team plans a replacement for the case on that day. It no longer disappears after a day.
- **`/field` marks suspended visits:** `field_visits` returns `suspended` and the pause reason category. The card shows "pausiert · …" and has no buttons. e2e at phone width.
- **Tests added (pgTAP 031):**
  - another team of the same organisation for pause, resume, cancel, no-show and reopen;
  - another organisation for cancel, close and reopen;
  - no report draft and no billing fact after a no-show;
  - audit with the reason for pause, close and no-show;
  - close leaves final reports, quality events and billing facts unchanged and closes open tasks.

#### ADR-043 amendment — F7 changes (PO review 2026-10-22 14:30)
- **She sees what she signs:** the sign form lists every observation and handover note of the snapshot in full, with its time and kind, before the confirm button.
- **A failed draft is visible:**
  - right after completion, the card says the report could not be created and why;
  - afterwards, a completed visit without a report reads "Bericht nicht automatisch erstellt", with a hint and the create step.
- **Seed:** `assist.test@navora.test`, a care assistant of Testteam Nord, and visit 509, so that the countersignature path runs end to end in e2e: the care assistant runs and signs the visit, and the registered nurse countersigns from her queue.

#### ADR-044 amendment — AN1 changes (PO review 2026-10-22 14:30)
- **Named honestly:** the measured figure is `care_share_in_visits` ("Pflegeanteil im Einsatz"), shown without a reference line. Its definition says what is not included: documentation, the return trip and time outside visits.
- **Incomplete visits:** visits without a departure or a completion time are excluded and counted separately (`incomplete_visits`).
- **North Star placeholder:** `direct_care_share` stays "noch nicht messbar" until paid working time is recorded (D-23).
- **No per-nurse inference:** team figures appear only when at least 3 persons in the team had visits in the period. Otherwise the team row shows no value and "zu wenig Personen", and only the organisation figure is shown.
- **COVER1 figures:**
  - `cover_without_operations` counts only covers accepted before anyone in a coordination role took over or closed the visit's exception;
  - `cover_median_hours` runs from the moment the visit entered the offer window: the later of the start minus the offer lead, and the visit's creation.
- **Every row shows its period;** open P1 exceptions say "Stand jetzt" and use all open exceptions as their base.
- `pilot_kpis` is now defined in full in migration 0032; the patches in 0028 and 0030 are superseded.

### ADR-047 — Handover without the team meeting: "since you were last here" (HAND1)
**Status:** PROPOSED · **Task:** HAND1 (brief `docs/agents/briefs/HAND1.md`, PO approved 2026-10-22). Migration 0033, pgTAP 033. (ADR-046 stays reserved for ADM1.)
**Decision:**
- **One read model over the existing append-only records** (`public.field_since_last(date)`), no copy of clinical data and no new view per case. Sources:
  - observations and handovers of other visits (current versions);
  - care plan: items added, items retired with the reason, schedule changes;
  - visit plan changes (moved, removed) with the reason;
  - C1 case pause, resume, close and reopen; cancellations and no-shows of other visits;
  - J6 primary-nurse and deputy changes with the reason;
  - J1/J3 medical order status and validity changes with the reason;
  - QG1 quality events with their current status.
- **Window:**
  - entries recorded after the nurse's own last completed visit of the case (its completion time);
  - if she never completed one: the case's last N completed visits on her teams (N = 3, `handover_settings`, per organisation) and everything since;
  - with no completed visit at all: everything recorded so far.

  The card states which rule applied. The empty state reads "Nichts Neues seit deinem letzten Einsatz am …".
- **Nothing is summarised, ranked or interpreted.** Entries are ordered oldest first and free text is shown as recorded. Codes become labels. Authors and persons are member labels: "Ich", "Teammitglied n" (numbered as on `/team`), "Automatisch", or "Person ausserhalb des Teams". No user ids leave the database.
- **Access stays team-scoped (F0, ADR-031):**
  - the card's visit must belong to one of the caller's teams;
  - visit-bound entries come only from her teams' visits;
  - case-bound entries require membership of the case's assigned team;
  - quality events must be of her teams;
  - the same case only, so no cross-case linking (RET1).

  A covering nurse is not a member of the visit's team, so she sees nothing until D-3.
- **Reasons from the change log reach the case's team.** The reasons for a primary-nurse change and for an order-status change become visible to the assigned team. Until now only coordination roles read `change_log`. The brief asks for them; it is limited to the team's own case. This is flagged for the PO review.
- **No extra tap:**
  - A trigger on the `started` visit event records in `handover_shown` the entries the section held at that moment: kind and id only, the rule, and the window start. It is append-only.
  - Opening a card writes nothing.
  - "Shown" means "present at the start". Reading is not recorded, and there is no read receipt.
- **Schedule changes are now audited old → new:** the audit trigger of `care_plan_items` includes the frequency fields. Changes made before 0033 show as "values not recorded".
- **Plan generator entries:** changes the plan generator derives from a care-plan change are represented by that care-plan entry, so they do not flood the section.
- **AN1:** `handover_shown_before_start` (patched into `pilot_kpis`) is the share of completed visits, among those whose previous completed visit of the case was done by another nurse, where the section was present at the start. It follows the 3-person team rule.
- **UI:** `/field` shows the section collapsible, open before the start and closed afterwards. It replaces the former 14-day "Übergabe aus dem Team" box. `field_notes` is unchanged.
**Rollback:** drop the trigger `visit_events_handover_shown`, the functions and the two tables, then restore the previous `audit_care_plan_items` trigger and the 0032 `pilot_kpis`. No existing data is changed.
**Open:** D-3 (cover context); the PO may change N or the plan-generator exclusion; member names come with ADM1.

### ADR-048 — Returning client returns to her team (RET1)
**Status:** PROPOSED · **Task:** RET1 (brief `docs/agents/briefs/RET1.md`, PO approved 2026-10-22). Migration 0034, pgTAP 034.
**Decision:**
- **Explicit link at intake** (`link_returning_referral`). An intake role links a referral to a case of the same organisation that is paused, or closed within the period in `return_settings` (pilot default 180 days).
  - The link needs a reason. It is recorded in `referral_links` (append-only, audited).
  - Nobody searches or matches identities: `linkable_cases` lists only the organisation's paused and recently closed cases, for intake roles (D-9).
- **Linked to a paused case:**
  - the case resumes (lifecycle event `resume` with the link reason) with its team and primary nurse;
  - future suspended visits are reactivated, and no new case or matching is created;
  - funding and order facts from the referral are applied. Changes to insurer, insurance type or order are logged with the link reason, and the readiness check runs again;
  - the referral is converted into that case;
  - the team gets the non-blocking task `review_after_pause` with the pause reason. The team closes it with `complete_case_task`.
- **Linked to a recently closed case:**
  - a new case (one case per referral) with `previous_case_id`;
  - when its J2 request opens, `set_first_refusal` reserves it for the previous team for 1 working hour (hospital discharge) or 2 working hours (otherwise), on the Q10 calendar;
  - the window is capped at the response deadline, which is never extended.
- **One eligibility predicate:** the window is a restriction inside the existing J2 rule (`request_offered_to_team`, mirrored in `team_offers`). Other teams neither see nor can accept the request while the window is open and the previous team has not decided. After a decline or the end of the window, J2 applies unchanged.
  - The previous team sees `returning_client` and its window end.
  - Other teams see neither, and no reference to an earlier case.
- **Window skipped:** when the previous team is not eligible under the J2/J3 rules (inactive, other region, or no registered nurse when one is required), normal matching starts at once. Region is included because it is part of J2 eligibility.
- **Primary nurse:** when the previous team accepts, the last primary nurse of the previous case is proposed as `proposed_primary_nurse_id`, but only if she is still in the team. She is taken from the audit trail, because closing a case clears the primary nurse. The proposal is never assigned: the team confirms it with `set_primary_nurse`, which clears the proposal.
- **Visibility:** cases keep the team-scoped read (ADR-031), so a team never sees another team's earlier case. `previous_case_id` is not exposed to teams.
- **AN1** (coordination roles, organisation level):
  - `returning_previous_team_share`: resumed cases plus new cases already assigned, with the share kept by the previous team;
  - `returning_referral_to_first_visit_days`: median from the link to the first started visit, shown next to the existing all-cases figure.
**Rollback:** drop the triggers and functions added here, `referral_links` and `return_settings`, and the added columns. Then restore the 0017 `open_matching_if_ready`, `request_offered_to_team` and `team_offers`, the earlier `team_cases` and the 0033 `pilot_kpis`, and the previous `case_tasks` check.
**Open:**
- D-9 / REF2 (automatic recognition stays out of scope);
- D-15 (if `clinical` makes a care-plan review after a hospital stay mandatory, it replaces the non-blocking task);
- the PO may change the period or the windows in `return_settings`.

### ADR-049 — CSR1 clinical safety remediation, part 1: qualification for the whole visit; missed and stuck visits stay visible (C1)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), first PR, closing C1's clinical-gate findings CGR-12 and CGR-04 (Clinical Governance Report 2026-10-22 22:30; issue #143). Migration 0038, pgTAP 038.
**Decision:**
- **CGR-12:** `private.enforce_visit_transition` applies the registered-nurse check (`private.is_registered_nurse`, NV001) to **every** transition into `started` (first start and resume from `paused`) and into `completed`, for category B and needs-assessment visits. One trigger, one rule, every write path of app users (the field commands are `security invoker`, so the trigger sees `authenticated`). Category A is unchanged. Pausing is not checked: only someone who could start the visit holds it in `started`.
- **CGR-04, derived, no job** (answer to the brief's question): two exception types in `private.derived_exceptions`, like the existing uncovered exception, so they exist exactly as long as their cause and need no scheduler.
  - `visit_overdue`: `planned`, not suspended, planned start passed (+ threshold). Independent of the responsible person; the detail says `niemand zuständig`, `zuständige Person nicht mehr im Team` (removed member, CSR1 addition 00:10), `von einem anderen Team übernommen` or the responsible member's display name. Key `visit_overdue:<visit>`.
  - `visit_stuck`: `on_the_way`, `started` or `paused`, measured from the last visit event; for `started` not before the planned end (an end before the start counts on the next day). Key `visit_stuck:<visit>:<last event id>`, so a person's close ends only that state: the next status change that again stalls raises a new exception.
  - PS-2: `visit_uncovered` / `visit_uncovered_hospital` lose their lower bound `now()`: they stay while the visit is planned and nobody is responsible, also after the planned start.
  - Resolution: the cause goes away (visit moves on, cancelled, no-show, suspended), or a coordinator closes it with a reason in OPS1 (existing `handle_exception`). CGR-06 (P1 that cannot be silenced while its cause persists) is a later CSR1 PR.
- **Thresholds PROVISIONAL (D-28, `clinical`), strict on purpose:** `visit_overdue` P2 at the planned start (0 h), P1 one hour after it; `visit_stuck` P2 after 1 h, P1 after 3 h. A visit without a planned time counts from 00:00 of its day (same convention as the uncovered exception). Organisations may change them only within the existing safe range (CR-021). Rule register CR-038 to CR-040.
- **Team visibility:** `public.team_visit_alerts()` (security definer, read-only) returns `visit_overdue` and `visit_stuck` for the caller's own teams, with the same priority, escalation and close state as OPS1, the client name the team already sees, and no free text. `/team` shows them at the top ("Einsätze mit Handlungsbedarf"). Coordinators outside the team keep OPS1 as their list.
- **Patch, not copy:** `derived_exceptions` is regenerated from its current definition (`private.csr1_patch`, each find must match exactly once; dropped after use), as in ADR-046.
**Rollback:** restore the 0024 `enforce_visit_transition`; delete the two `exception_rules` rows (and overrides); regenerate `derived_exceptions` without the two branches and with the `between now() and …` bound; drop `team_visit_alerts`.
**Open:** D-28 thresholds and who is alerted (`clinical`); CGR-06; whether the team (not only Operations) may close an alert with a reason (PO, after CGR-06).

### ADR-050 — CSR1 part 2: a serious quality event stays escalated until closed; safety exceptions close only with their cause (OPS1)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), second PR, closing OPS1's clinical-gate findings CGR-05 and CGR-06 (Clinical Governance Report 2026-10-22 22:30; issue #144). Migration 0039, pgTAP 039 (and 019, 038 adjusted).
**Decision:**
- **CGR-05:** `quality_serious_open` is derived while the event is `open` **or** `in_review`; only `closed` ends it. Same key, so take-over and notes carry over, and the escalation clock (from `created_at`, CR-020) keeps running in review. The detail says "in Bearbeitung".
- **CGR-06, option chosen: "cannot be closed until the cause is resolved"** (the brief let engineering choose between that and "re-opens while the cause persists"). A re-opening close is a button that seems to work and does not; a refused close says what is true. So:
  - A **safety exception** is one whose *effective* rule (platform default plus the organisation's ADM1 override) is P1 **or escalates to P1**. Escalating types are included because closing one while it is still P2 would silence the P1 it becomes. Pilot defaults: `no_show_open`, `visit_uncovered_hospital`, `quality_serious_open`, `visit_overdue`, `visit_stuck`, `cover_without_access` (COVER1, off). One helper: `private.exception_is_safety(org, type)`.
  - `handle_exception(…, 'close', …)` returns the new result **`cause_persists`** for a safety exception (nothing is written). Take over and notes are unchanged. Each one ends by an auto close when its cause is resolved: outcome recorded, visit started/cancelled/suspended, someone responsible, quality event closed.
  - **Legacy closes do not silence:** for safety exceptions, `operations_exceptions()`, `team_visit_alerts()` and `open_exception_org` treat any earlier `close` or `auto_close` as "open, not taken". This covers closes written before 0039 and a cause that returns after an auto close. Non-safety exceptions keep the 0019 rule ("closed for this cause").
  - `operations_exceptions()` gains `closable boolean`; `/operations` shows "Schliessen" only when it is `true`, and otherwise "schliesst automatisch, sobald die Ursache behoben ist". The UI never decides safety itself.
- **No rule invented:** no threshold, priority or escalation changes. Which types are safety exceptions follows from the configured priorities (Q9, D-28 PROVISIONAL). Rule register CR-041.
- **Patch, not copy:** `derived_exceptions`, `operations_exceptions` and `team_visit_alerts` are regenerated from their current definitions (`private.csr1b_patch`, every find must match exactly once, dropped after use). `handle_exception` and `open_exception_org` are replaced whole (unchanged since 0019).
**Consequences:** a coordinator can no longer clear a stale P1 by hand. If the data is wrong (a visit happened but was not recorded), the team must record it. That is intended: the list shows the recorded truth. The PO may later want the team, not only Operations, to resolve the cause from the alert (ADR-049 open point).
**Rollback:** restore 0019 `handle_exception` and `open_exception_org`; regenerate the three readers without the `or r.priority = 'P1' or r.escalate_to_p1_after_hours is not null` clause, without `closable` and with `q.status = 'open'`; drop `private.exception_is_safety`.
**Open:** D-28 (`clinical`) thresholds and who is alerted; whether `clinical` wants other types treated as safety exceptions.

### ADR-051 — CSR1 part 3: only the author supersedes her observation; signed means fixed for times and observations (F1-F4)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), third PR, closing F1-F4's clinical-gate findings CGR-01 and the F3/F4 part of CGR-03 (Clinical Governance Report 2026-10-22 22:30; issue #145). Migration 0040, pgTAP 040.
**Decision:**
- **CGR-01:** `record_observation` refuses a supersede unless the caller wrote the superseded version (`prev.author_id = auth.uid()`); result `rejected`, nothing written. A colleague adds her own observation; both stay current side by side. `/field` already offered "Ändern" only on own notes; the database now enforces it.
- **CGR-03 (F3/F4 part), option chosen: "only through a correction version of the report"** (the report allowed that or a plain refusal). The visit's facts are locked while its **latest** report version is `signed` or `final` (`private.visit_facts_locked`, internal, not callable by app users). `correct_visit_time` and `record_observation` then return `rejected`. `correct_report` (F6, unchanged) opens a correction draft, which is the latest version, so the facts open again; `update_report_draft` and `sign_report` rebuild the snapshot, so the next signed version carries the changed facts and the earlier signed version stays as it was. No new command and no new report state.
  - **`signed` (awaiting countersignature) locks too**, stricter than the report's "after `final`": the countersigner signs the snapshot frozen at signing, so a live change in between is also a silent change after signature. A wrong time noticed then is corrected after the countersignature through a correction version.
  - Both commands lock the visit's report rows (`for update`) before the check, so a correction cannot slip in between a concurrent `sign_report` and its snapshot.
- **Contract unchanged:** both commands keep their signature and `'ok' | 'duplicate' | 'rejected'` (the report's pgTAP wording). `/field` hides "Korrigieren", "Ändern" and the new-observation form while locked and says that changes go through "Bericht korrigieren" (`visitFactsLocked`, `FACTS_LOCKED_HINT`); the server messages name both reasons.
- **Not here:** the J5 part of CGR-03 (billing facts take minutes from the signed snapshot) is J5's (#148), with BL-8 and BL-9. CGR-02 (sign carries the version of the snapshot shown) is F6/F7's (#146, #147).
**Consequences:** after signing, a nurse can no longer fix a typo in a time directly; she opens a correction version with a reason, which a registered nurse countersigns again where required. That is the F6 rule applied to the facts behind the report. Observations by a colleague who left the team cannot be superseded by anyone; the team adds a new one.
**Rollback:** restore `correct_visit_time` (0008) and `record_observation` (0009) as they were; drop `private.visit_facts_locked`.
**Open:** none of engineering's. Whether `clinical` wants other facts (quality events, handover marks) locked the same way is not decided; they are not report facts today.

### ADR-052 — CSR1 part 4: she signs what she saw (F6, F7)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), fourth PR, closing CGR-02 for F7 (issue #147) and F6 (Clinical Governance Report 2026-10-22 22:30). Migration 0041, pgTAP 041. Remediation plan `docs/agents/clinical/remediation/CGR-02.md`.
**Decision:**
- **Hash, not version number.** The brief allowed "the version or hash of the snapshot shown". A draft's facts change without a new report version (observations, time corrections), so a version number cannot tell what was shown. The sign command carries the sha256 of the snapshot shown: `sign_report(p_report_id, p_snapshot_hash, p_idempotency_key)`.
- **One builder for display and signature** (answers the brief's question): `field_reports` returns, for a `draft`, the snapshot built from the live facts by `private.visit_report_snapshot`, the same function `sign_report` uses, plus `snapshot_hash` of exactly that JSON. Signed and final versions show their stored, frozen snapshot and its hash.
- **Refuse, write nothing.** `sign_report` rebuilds the snapshot after the performer and draft checks. When the hash differs (or is missing) it returns `rejected` / `facts_changed`. The stored snapshot of a signed version is the one whose hash she sent. `/field` reloads the card after any refusal and explains the reason; she checks and signs again.
- **The old `sign_report(uuid, uuid)` is dropped**, so there is no path that signs without naming what was shown.
- **Deterministic text:** `private.visit_report_snapshot` runs with `timezone = UTC`, because `jsonb` renders `timestamptz` with the session's offset. Values are unchanged; new snapshots carry `+00:00`, which the UI already parses.
- **Unchanged:** countersignature (the signed snapshot is immutable, so the countersigner signs the frozen version), correction versions (0040 lock), the summary (the nurse's own text, not part of the hashed facts; F7 saves it first and then signs), idempotency and audit.
**Consequences:** a nurse whose screen is out of date sees one refusal and the current facts instead of signing them unseen. Callers must read `field_reports` before signing; tests use the same read model.
**Rollback:** restore `sign_report(uuid, uuid)` and `field_reports` from 0016/0035; reset the snapshot builder's `timezone`; drop `private.report_snapshot_hash`.
**Open:** UNKNOWN whether any command changes services or planned minutes of a completed visit after signature (not a CGR-02 question; see the remediation plan). CGR-19 (F6, advisory) is not in this PR.

### ADR-053 — CSR1 part 5: a broken-off visit ends as *not completed* (OPS1, C1, ABS1)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), fifth PR, closing CGR-20 (Clinical Governance Report section 2026-10-23 06:30, blocking S1 for OPS1). Delivered under issue #148 at the PO's request. Migration 0042, pgTAP 042. Remediation plan `docs/agents/clinical/remediation/CGR-20.md`. Interim safe default until D-31 (`clinical`, with `legal`).
**Decision:**
- **A new terminal visit status `interrupted`** (UI: "Nicht abgeschlossen"), not a flag on `completed`. Every reader that must not count the visit (F6 report draft, `report_not_final`, J5, J6, AN1, HAND1's window, the needs-assessment marker) already filters on `status = 'completed'`, so the new state is excluded everywhere without touching them; a flag on `completed` would have had to be added to each of them, and a missed one would bill or report care not given. `visit_stuck` is derived from `on_the_way` / `started` / `paused` and ends with its cause; no hand close.
- **One dedicated command, `end_visit_not_completed(visit, reason_code, note, idempotency_key)`**, security definer like the other C1 reason commands (`cancel_visit`, `record_no_show`), with its own access check. The brief's recommendation said security invoker; definer is used because the state machine trigger must keep refusing `started` → `interrupted` for app users, otherwise a direct update could skip the reason. The reason sits in `visit_status_notes` (append-only, audited, read by `/field` and HAND1), the actor in the note and the `interrupted` timeline event.
- **Reasons** exactly as the CSR1 criterion lists them: `client_transferred`, `client_declined`, `nurse_unavailable`, `started_by_mistake`, `other` (with a note). A table check keeps an `interrupted` note to these codes.
- **Who:** any member of the visit's team or a coordination role (`admin`, `coach`, `operations`, `private.is_coordinator`), whatever the qualification. The performer is always a team member (0037 refuses her removal while the visit runs). No registered-nurse check: the command records that care stopped, not care given (CGR-12 still covers every transition into `started` and `completed`).
- **No way out:** `interrupted` is terminal; complete, resume, start and cancel are refused, and the transition list for app users is unchanged.
- **Row lock** on the visit, so a completion and an interruption at the same time cannot both apply.
- **Not changed:** observations already recorded stay; new observations are refused as for any visit outside the four observable states (D-31 may change that). `correct_visit_time` keeps its rules.
**Consequences:** a team ends a broken-off visit in one tap with a reason instead of a false completion or a permanent P1; OPS1 can be re-accepted. Minutes already given are shown on the card but produce no fact until D-31. A coordinator can end a team's visit from the database command; the UI offers it on `/field`, which shows only the coordinator's own teams.
**Rollback:** drop `public.end_visit_not_completed`; restore `private.write_visit_event` and the three checks from 0024. Rows already `interrupted` would need a data decision (they must not become `completed`).
**Open:** D-31 (reasons, report, billing of given minutes, who records). Operations has no `/operations` action for it yet (UNKNOWN whether coordinators need one; the PO's `/field` hypothesis points to the team).

### ADR-054 — CSR1 part 6: billing reads the signed snapshot; no bill on an unmodelled basis; holds and corrections reach the facts (J5)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), sixth PR: J5's part, closing CGR-03 (J5 part) and CGR-07 (blocking, report 2026-10-22 22:30), CGR-08 (advisory, condition), BL-8 and BL-9 (advisory, conditions added 2026-10-23 01:10). Delivered under issue #148. Migration 0043, pgTAP 043, rule J5-v3. Remediation plans `docs/agents/clinical/remediation/CGR-03.md` and `CGR-07.md`. Amends ADR-038 and ADR-040.
**Decision:**
- **Times and plan from the signed snapshot (CGR-03).** `build_billable_fact` no longer reads `visit_times` / `visit_care_minutes_exact` (live events + corrections) or the live planned minutes of `care_visits`. It reads the stored snapshot of the final report version: `private.snapshot_times(snapshot)` applies the same arithmetic as the two live functions to the events the snapshot lists, and the planned minutes per category come from `snapshot.planned`. The fact stores `snapshot_hash` (the 0041 hash), so every fact names the exact signed facts it was built from. A correction exists only as a report correction version (0040 lock), whose final snapshot yields a new fact superseding the old one.
- **Rule version J5-v3.** Existing J5-v2 facts are not rewritten; the next generation adds a J5-v3 fact per final report that supersedes them (the ADR-040 pattern). AN1's "billable minutes per care minute" reads J5-v2 and J5-v3 (both measured), patched in place like COVER1 and PLAN2 did (`pg_get_functiondef`, refuses to run when the text does not match).
- **Refuse, do not estimate (CGR-07).** New not-billable reasons: `order_validity_missing` (order `present` without an end date), `order_expired` (end date before the visit date, for A and C minutes too), `payer_not_modelled` (insurance type not `KVG`, including missing or `unknown`). Existing reasons stay, so a B visit without a valid order keeps `b_without_valid_order` as well. No tariff rule is added; these visits simply produce no estimate until the rule is modelled (D-18, D-22).
- **Validation in the data (CGR-08).** `tariff_rates` and `billing_rules` get `validated` (default false) and `validation_note`; the seeded rows stay unvalidated with a note naming their canton source. A fact using an unvalidated rate (for a category with minutes) or minimum gets the warning `reference_not_validated`; `billing_preview` returns `reference_validated` (per team: the rates and minimum its priced facts used; with no priced fact, whether any unvalidated reference row is valid in the month). `/team` and `/operations` show "Tarife und Mindestdauer nicht validiert". No app path sets `validated`; it changes only by migration after D-11 / D-18 (no organisation column, so no audit trigger: reference data is not tenant data and is versioned in git).
- **Holds supersede the fact (BL-8), not a derived flag.** A derived flag would have to be repeated by every reader, and a forgotten one (an invoice export) would bill a held visit. Instead, a trigger on `quality_holds` appends a fact with `cause = quality_hold`, `billable = false`, reason `quality_hold` and `hold_id` whenever a hold opens on a visit whose latest fact is billable; when the visit's last open hold is lifted and the latest fact is that hold fact, the fact before it is appended again (`cause = hold_lifted`, billable as before). Facts stay immutable; the chain keeps the history. The unique key "one fact per report and rule" now applies to `cause = report` only. Holds already open when 0043 runs get their hold fact in the migration. Generation and the hold trigger lock the visit row, so a fact built at the moment a hold is set cannot stay billable.
- **Working time follows the signed truth (BL-9).** `working_time_facts` loses its one-per-visit key: one fact per final report version (`report_id`, `source = signed_snapshot`), from the same snapshot as the billing fact; a new one supersedes the visit's previous one (`supersedes_id`). Earlier rows stay (`source = live`). The latest fact is the one without a successor, as for billing facts.
**Consequences:** billing and working time can no longer differ from what the nurse signed; non-KVG cases, undated and expired orders show as not billable with a reason, so the preview total falls for such teams (correct: the rule is not modelled). The preview shows that the rates and minimum are not validated until D-11 / D-18. A hold now visibly changes the fact history.
**Rollback:** restore `build_billable_fact` and `billing_preview` from 0023, drop the hold triggers and `snapshot_times`, restore the two unique keys (only possible while each report and visit has one fact), revert the AN1 patch. Facts already written stay.
**Open:** D-11, D-18 (re-seed and validate the reference data), D-22 (order forms and validity), D-12 (real invoicing). CGR-13 (the UI calls a hold "Abrechnungssperre") and CGR-19 are later CSR1 parts.

### ADR-055 — CSR1 part 7: no unsignable correction; an uncovered visit closes only with its cause (F6, OPS1)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), seventh PR: the PO's interim criteria for CGR-19 (F6, advisory S2, report 2026-10-23 02:28; criterion 03:10) and CGR-22 (OPS1, advisory S2, report 06:30; criterion 07:10). Delivered under issue #149. Migration 0044, pgTAP 044. Remediation plans `docs/agents/clinical/remediation/CGR-19.md` and `CGR-22.md`. Amends ADR-032 and ADR-050.
**Decision:**
- **CGR-19: refuse, do not create an unsignable draft.** `correct_report` checks, after the existing team, `final` and latest checks, that the report's performer is still a member of the report's team (`private.user_in_team`, 0033). Otherwise it returns `rejected` / `performer_not_in_team` and writes nothing. The final version stays in force, readable, and keeps the visit's facts locked (0040). The check follows the membership, not a mark on the report: if she rejoins, a correction is possible again. Same signature and return shape. `/field` shows a German message that the final report stays valid and that the case is not yet regulated. Who may correct and sign instead is D-30 (`clinical`, with `legal`); nothing about authorship is invented.
- **CGR-22: `visit_uncovered` closes only with its cause, without becoming a safety exception.** A new internal `private.exception_closes_with_cause(org, type)` is true for safety exceptions (0039, unchanged) and for `visit_uncovered`. `handle_exception` and `open_exception_org` use it instead of `exception_is_safety`; `operations_exceptions()` returns `closable = false` for it and no longer lets an earlier close hide it (the CGR-06 pattern, patched in place from `pg_get_functiondef` with exact-once matching). Its priority stays P2 and its 24 h window stays; `exception_is_safety` and the analytics count of safety exceptions do not change, because whether an uncovered visit is a safety signal is D-28 (`clinical`). The exception is derived exactly while the visit is planned, nobody is responsible, it is not suspended and not covered, so it ends when someone starts it, becomes responsible (planning with a responsible member, the plan regeneration through primary or deputy nurse), or the visit is cancelled, removed, suspended or covered.
- Why a list in a function rather than a priority change: raising the priority would be a clinical threshold (D-28). A named list keeps the strict default visible in one place (rule register CR-049) and is removed or widened by migration once D-28 is answered.
**Consequences:** a correction can no longer leave an open draft nobody can sign (and, since 0040, an open draft that unlocks the visit's facts with no end). Operations cannot silence an uncovered visit a day ahead; it stays listed until it is covered or cancelled. The `/operations` note for a non-closable exception no longer calls every one a safety exception.
**Rollback:** restore `correct_report` from 0016, `open_exception_org` and `handle_exception` from 0039, and the two `operations_exceptions` expressions; drop `private.exception_closes_with_cause`. No data changes to undo.
**Open:** D-30 (who corrects and signs when the performer has left), D-28 (is an uncovered visit a safety signal, its priority, and may a hand close silence it). OPEN, not changed: a correction draft opened while the performer was a member stays open and unsignable if she leaves afterwards (0037 does not refuse the removal for a correction draft, CR-036), and an open correction draft has no time limit (CGR-24, waits for D-28). OPEN: no command assigns a responsible member to an existing hand-planned visit; today the cause ends by a start, a cancellation or removal, or planning anew with a responsible member (visit assignment is D-6).

### ADR-056 — CSR1 part 7 (completion): an interrupted visit keeps a signal until a person decides (OPS1)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), eighth PR: the PO's strict provisional default for CGR-25 (OPS1, advisory S2, `cra` section 2026-10-23 10:29; criterion 11:25). Completes CSR1 part 7 with CGR-22 (ADR-055). Delivered under issue #149. Migration 0045, pgTAP 045. Remediation plan `docs/agents/clinical/remediation/CGR-25.md`. Amends ADR-053 and ADR-055.
**Decision:**
- **The decision is a status note, the signal a derived exception.** The follow-up decision is a new `visit_status_notes` kind `interruption_followup` (reason codes `follow_up_planned`, `no_longer_needed`, `other` with a note), the same append-only, RLS-scoped, audited table that carries the interruption reason (0042) and the no-show outcome (0024). A partial unique index allows one decision per visit. A new exception type `visit_interrupted` (P2, no threshold, not escalating; PROVISIONAL) is derived in `private.derived_exceptions` from `status = 'interrupted'` without such a note: no job, no stored state, the pattern of `no_show_open` (0024) and `visit_stuck` (0038).
- **One command for team and Operations.** `public.record_interruption_followup(visit, decision, note, idempotency_key)`: security definer like `end_visit_not_completed` (0042), allowed for a member of the visit's team or a coordination role of the organisation, whatever the qualification (it records a decision about care, not care given). It locks the visit row, refuses a visit that is not `interrupted` (`wrong_state`) and a second decision (`already_decided`), and is idempotent (`begin_command`). Who may finally decide is D-31.
- **It closes only with its cause.** `private.exception_closes_with_cause` (0044) now lists `visit_interrupted`; OPS1's generic close returns `cause_persists`, `closable = false`, and an earlier close never hides it, in `operations_exceptions` and in `team_visit_alerts`. So the only way to close it is one of the listed reasons. Take over and notes stay.
- **Detail:** date and time of the visit, the interruption reason and note, and for `client_transferred` the case's next planned visit after the end (or "kein weiterer Einsatz geplant"). It is shown to the team on `/field` (new queue section and on the visit's card) and `/team` (visit alerts), and to Operations, each with the same decision form. HAND1 shows the decision automatically as "Nicht abgeschlossen: Entscheid".
- Why not reuse `handle_exception(close)`: it is coordinator-only and takes free text, while the criterion asks for team members too and a reason from a short list. Why P2 and not escalating: the PO's example; the priority is a clinical threshold (D-28/D-31), so organisations may only raise it (existing safe range).
**Consequences:** a visit ended as not completed can no longer disappear from every list; someone has to say whether the care still due is followed up. "Folgeeinsatz geplant" is a person's statement; nothing checks that a visit was actually planned (OPEN, D-31). Existing interrupted visits (from 0042 on) raise the exception once 0045 runs; no data migration.
**Rollback:** drop `public.record_interruption_followup`, delete the `visit_interrupted` rule, restore `exception_closes_with_cause` from 0044, `derived_exceptions`, `operations_exceptions` and `team_visit_alerts` from their 0044/0039/0038 definitions, the two `visit_status_notes` checks from 0042, and drop the index and the follow-up check. Decision rows written meanwhile would have to be kept (append-only audit) or the kind kept in the check.
**Open:** D-31 (`clinical`, with `legal`): what a follow-up decision must contain, who may decide, whether a decision can be corrected, and whether "Folgeeinsatz geplant" must be linked to a planned visit. CGR-26 (the performer sees who ended her visit) is CSR1 part 8.

### ADR-057 — ABS1 part 1: absence hands the day to the team; one release rule; "Offen im Team" with one tap
**Status:** PROPOSED · **Task:** ABS1 (brief `docs/agents/briefs/ABS1.md`, PO approved, amended 2026-10-23 12:15), first PR, migration 0046. Clinical gate: CGR-15 and CGR-11 (report 2026-10-22 22:30; the 2026-10-23 10:29 section lists both for ABS1), reusing CGR-09, CGR-10, CGR-12, CGR-18 and CGR-22. Remediation plans `docs/agents/clinical/remediation/CGR-11.md`, `CGR-15.md`.
**Decision:**
- **An absence is a row with a time range, release in the same command (no job).** `public.member_absences` (team, member, `[starts_at, ends_at)`, recorded_by, withdrawn_at). No reason column and no text column at all; `record_absence` has no such parameter. Overlaps of one member in one team are refused (`overlaps`) under a lock on her membership row, which is cheaper and clearer than an exclusion constraint (no `btree_gist`). An absence belongs to one team: a colleague of that team records it, and only that team learns of it (privacy over convenience; a nurse in two teams records it in each, OPEN whether that is wanted).
- **One release rule** (CGR-15): `private.release_visits_between(team, member, from, until, reason, actor, rn_only)` releases planned visits (suspended included, CGR-09) of that team and member, dated today or later, whose planned interval overlaps the period; never visits on the way, started or paused (CGR-10, CGR-18), which keep her as responsible and performer under `visit_stuck`. ADM1's `release_member_visits` (0036) delegates to it with whole days (same signature and result, pgTAP 036/037 unchanged). Each release is a `visit_plan_changes` row `released` with a fixed team-readable text: `Abwesenheit`, `Mitglied aus dem Team entfernt`, `Qualifikation geändert`.
- **Never refused because of her work in progress** (PO 2026-10-23 03:10): an absence with a paused visit or a draft report is accepted; the report stays hers (she stays a member).
- **Withdraw or shorten** (`change_absence`): only the absent member or the colleague who recorded it. Visits released by this absence (internal `absence_releases`), still planned, untaken, uncovered, now outside the absence, and that she may still perform, return to her (`returned`, `Abwesenheit beendet`). Taken visits stay with the taker.
- **"Offen im Team" is a reader over the J3 model, not a new read model:** `public.team_open_visits(p_from)` returns every planned, not suspended, not covered visit of the caller's teams with nobody responsible, 14 days from `p_from` (PO amendment 12:15: whatever made it uncovered). It adds `known_by` (deputy, then primary nurse, if in the team and not absent then; a label), `may_take` and the caller's overlapping own visit. The J3 `uncovered_visits` reader was not reused: it is organisation-wide, only 24 h ahead and has no team facts.
- **One tap, first wins:** `public.take_open_visit` locks the visit row; the second caller gets `already_taken`. J3 qualification rule through one helper `private.may_perform_visit` (same rule as CR-007 and `plan_visit`); not while she is absent at the visit's time (`absent`). The taker becomes responsible, the time stays (move with the existing J3 move-with-reason), a `taken` row is written, and the OPS1 `visit_uncovered` exception ends with its cause (CGR-22). Verified with two real sessions (`scripts/db-concurrency/open-visit-take.sh`, in CI).
- **PLAN2:** `generate_case_plan` skips a primary or deputy absent during the slot (deputy if she may perform it, else uncovered). A `taken` change makes a generated visit "touched" (`plan_visit_untouched`), so regeneration never reassigns it.
- **CGR-11:** `set_member_qualification` from registered nurse to care assistant releases her category B and needs-assessment visits from today on (`rn_only`).
- **HAND1:** `handover_entries` now lists `released` changes as `visit_released`, without the reason and without `responsible_id` (no user ids leave the database); the UI shows "Einsatz <Datum Zeit> wieder offen im Team".
- **Privacy:** `member_absences` is readable by members of the same team only (RLS, column grants without organisation id); `team_absences()` the same. Operations sees only uncovered and overdue visits ("niemand zuständig"), never who is absent. AN1 does not read absences yet.
- Patches of existing functions are regenerated from their current definitions with an exact-match helper (as 0038–0045), dropped after use.
**Consequences:** an absent nurse's visits never look covered; nobody phones anyone; Operations and COVER1 see what the team has not taken. A colleague can see who is absent in her own team (from–to only).
**Rollback:** drop the five public functions and two tables; restore `release_member_visits` (0036), `generate_case_plan` (0030), `plan_visit_untouched` (0025), `set_member_qualification` (0018) and `handover_entries` (0033) from their previous definitions; the `visit_plan_changes` check loses `taken`, `returned` (rows would have to be deleted first).
**Open:** PLANNED (ABS1 part 2): AN1 measures (taken before the COVER1 lead time, median time to the last take, share taken by deputy or primary nurse, small-team rule). OPEN: an absence spanning several teams; whether a care assistant who becomes a registered nurse should get visits back (nothing is reassigned automatically).

### ADR-058 — CSR1 part 8: an open report correction keeps a signal; the performer sees who ended her visit; a hold reads as a billing hold (F1-F4, F6, OPS1, QG1)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO approved), part 8: CGR-24 (strict provisional default, threshold D-28), CGR-26 and CGR-13, all advisory, from the `cra` section 2026-10-23 10:29 (CGR-13 from QG1). Delivered under issue #149. Migration 0047, pgTAP 047. Remediation plans `docs/agents/clinical/remediation/CGR-24.md` (also CGR-30), `CGR-26.md`, `CGR-13.md`. Amends ADR-055 (correction drafts) and ADR-056 (interrupted visits). J5-C1 does **not** ride along: this PR does not touch billing generation (the J5 brief ties J5-C1 to the next such PR); it stays PLANNED.
**Decision:**
- **CGR-24 is a derived exception, no job and no stored state.** `report_correction_open` (P3, not escalating; PROVISIONAL) is derived in `private.derived_exceptions` for every correction version (`supersedes_id` set) that is not `final` and older than the **effective `report_not_final` threshold** of the organisation. The brief names that threshold, so it is read from that rule instead of a second number that could drift; the new rule row has no amount, so an organisation cannot set one apart (it may raise the priority, existing safe range). Key `report_correction_open:<correction id>`, so a later correction of the same visit is a new signal and an earlier close does not hide it.
- **Stricter than the brief's wording (recorded deviation):** a correction that is `signed` but waits for the countersignature also keeps the signal. Until it is `final` the old version stays in force and billing reads only final versions (0043), so the correction is still not done. The detail says which: "nicht unterschrieben" or "unterschrieben, Gegenzeichnung offen". No clinical text (no reason, no summary) is in the detail.
- **No withdraw path:** the brief mentions "or the draft is withdrawn", but there is no command to withdraw a correction draft (UNKNOWN whether the PO wants one; not built). Today the signal ends only when the correction becomes final.
- **Who sees it:** the team through `team_visit_alerts` (`/team`, "Einsätze mit Handlungsbedarf") and Operations through `operations_exceptions`. **It closes only with its cause** (CGR-30, advisory S3 from the `cra` section 2026-10-23 14:30 on this PR): `private.exception_closes_with_cause` lists it, so OPS1's hand close returns `cause_persists`, `closable = false`, and an earlier close never hides it for the team or Operations (as `visit_interrupted`, ADR-056). Otherwise one close would silence it for good while the visit's facts stay unlocked. It is not made a safety exception; its priority stays D-28.
- **CGR-26 is a label in the reader, never an id.** `public.field_visit_status_notes(date)` is dropped and recreated with `actor_kind` (`me`, `team`, `coordination`, `former`), `actor_name` (ADM1 member profile of the same organisation, only for `team` and `coordination`), `actor_qualification` (`team`) and `actor_role` (`coordination`). It stays security definer and team-scoped as before. The app formats it (`recordedByLabel`, `src/features/lifecycle/rules.ts`) and the `/field` card of an interrupted visit shows "Beendet von <label> · <time>", emphasised when it was not the reader. The reason was already shown. A user id would have been simpler but would hand coordinators' ids to every team member; the label is enough for the criterion.
- **CGR-13 is wording only:** every UI text that said "Qualitäts-Stopp" now says "Abrechnungssperre", with one shared sentence (`HOLD_MEANING`): "Gesperrt ist nur die Abrechnung; ob und wie gepflegt wird, regelt die Sperre nicht." This describes what the system does and gives no care instruction. Database names (`quality_holds`, `set_quality_hold`) are unchanged.
**Consequences:** a correction left half done becomes visible after one day (PROVISIONAL) instead of never; while open it still unlocks the visit's facts (0040), now with a signal. A nurse whose visit was ended by a colleague or by Operations sees it on her card. Nobody reads a billing hold as a stop of care.
**Rollback:** delete the `report_correction_open` rule; restore `exception_closes_with_cause`, `derived_exceptions`, `operations_exceptions` and `team_visit_alerts` from 0045 and `field_visit_status_notes` from 0024 (drop and recreate with five columns); revert the UI texts. No data is written by 0047.
**Open:** D-28 (`clinical`): the threshold and the priority (closing only with its cause is the strict default, CGR-30). D-31: how an end recorded in error is corrected. D-16: the quality event list and who lifts a hold. UNKNOWN: whether a correction draft should be withdrawable. PLANNED: J5-C1 with the next PR that touches billing generation; AN2 measure "ends recorded by a coordination role while the visit was in progress" (CGR-26) with AN2.

### ADR-059 — ABS1 part 2: one visit interval for every absence check; an absence belongs to the person; three AN1 measures
**Status:** PROPOSED · **Task:** ABS1 (brief `docs/agents/briefs/ABS1.md`, PO review 2026-10-23 14:16: `changes-requested` with ABS1-C1, C2, C3 and the AN1 criterion), part 2, issue #199. Migration 0048, pgTAP `048_abs1_part2` and `048_abs1_an1_measures`. Clinical gate: CGR-27 (blocking, S1, `cra` section 2026-10-23 14:30, unchanged in the 15:00 section on PR #203). Remediation plan `docs/agents/clinical/remediation/CGR-27.md`. Amends ADR-057.
**Decision:**
- **One interval function (ABS1-C1, CGR-27).** `private.visit_interval` is redefined; every absence check already goes through it (release, `take_open_visit`, `team_open_visits.may_take` and `known_by`, `change_absence`). No start time: the whole date, 00:00 to 24:00 Europe/Zurich. Start without end (or end = start): start + planned minutes A+B+C; without planned minutes, to the end of the date. Start and end: as before (an end before the start runs past midnight). This is arithmetic from the `cra` recommendation, not a clinical rule, so no rule-register entry. A care assistant's or nurse's *own* untimed visit therefore blocks her for that day in "Offen im Team" only where an absence exists; the interval is not used for anything else.
- **PLAN2 keeps the slot window.** Scheduled care plan items must have a window (`care_plan_items` check, 0025), so a generated visit always has a start and an end; the `cra` confirms CGR-27 does not apply there. Nothing changed.
- **Overlap label needs a time on both visits (ABS1-C2).** An untimed visit has no time to clash at; without this, an untimed open visit would be marked as overlapping every visit of the day. pgTAP asserts set and not set.
- **An absence belongs to the person (ABS1-C3, PO decision).** One row per team of the member in the organisation, linked by a new column `absence_group` (not granted to the app; a before-insert trigger makes a row without a group its own group). Chosen over one row with a team list because RLS, `team_absences` and the release stay per team, so each team still reads only its own row and its own released visits. `record_absence` keeps its signature: the caller and the member must share the named team; it locks all her memberships in the organisation in a fixed order, checks overlaps across them, inserts one row per team and releases in each (`teams` added to the result). `change_absence` locks the group, changes every row first, then returns untaken visits in each team (changing first matters: the absent check asks about the person, so a row still unchanged would keep her absent). `member_absent_during` now asks about the person in the organisation, not the team. `team_absences` shows an absence once to a caller who shares several teams with the member.
- **AN1, three measures in `pilot_kpis`, aggregates only.** Base: visits released by absences recorded in the month (`absence_releases`), without cancelled visits and without those that returned to her untaken. `absence_taken_before_cover_lead`: share taken (first `taken` after the absence) no later than the planned start minus the COVER1 offer lead time (`cover_window`; computed even while cover is off, D-3). `absence_last_take_minutes`: median minutes from recording to the last take, only absences whose released visits are all taken, counted per team row. `absence_taken_by_known_share`: share of taken released visits whose taker is the case's deputy or primary nurse **as recorded now** (no history of those fields exists). Team rows follow the existing small-team rule (no figure under three nurses with visits); organisation rows only for coordination roles. No column names a member.
**Consequences:** an absence from 10:00 no longer leaves that day's untimed visit looking covered; a nurse in two teams says once that she cannot work; AN1 shows whether the team, and the people who know the client, pick up the day.
**Rollback:** restore `visit_interval`, `member_absent_during`, `record_absence`, `change_absence`, `team_absences` from 0046 and `team_open_visits`, `pilot_kpis` from their definitions before 0048; drop the trigger, its function, the two indexes and `absence_group` (rows recorded for several teams stay as separate one-team absences).
**Open:** PLANNED: CGR-28 (an absence also ends her accepted covers), advisory while cover is off; a condition on D-3. Deviation: a team she joins after the absence was recorded respects it (she is not offered or planned its visits) but its visits are not released and it does not see the absence. UNKNOWN: whether the PO wants the "known" measure to use the nurses at the time of the take (needs a history that does not exist).

### ADR-060 — CSR1 part 9: an untouched correction draft can be withdrawn; a correction final during a hold is the fact after the lift; a payer correction re-derives the fact (F6, J5)
**Status:** PROPOSED · **Task:** CSR1 (brief `docs/agents/briefs/CSR1.md`, PO 2026-10-23 15:25), part 9: CGR-24-W (PO decision on the residual of CGR-24), CGR-29 (advisory S3, `cra` section 2026-10-23 14:30) and J5-C1 (J5 condition, PO 2026-10-23 11:25; `briefs/J5.md`). Delivered under issue #149. Migration 0049, pgTAP 049 (043 adjusted). Remediation plan `docs/agents/clinical/remediation/CGR-29.md`. Rule register CR-056 (UNVALIDATED), CR-057 (PROVISIONAL, D-22). Amends ADR-032 (report versions), ADR-054 (J5-v3 facts) and ADR-058 ("no withdraw path").
**Decision:**
- **Withdrawn is a terminal status of the version, not a deletion.** `visit_reports.status` gains `withdrawn` with `withdrawn_by` and `withdrawn_at` (checked together; only a correction, never signed). The guard (0016) refuses every change of a withdrawn row and lets a draft become withdrawn only with snapshot, summary, version and links unchanged. The audit trigger adds `withdrawn_by`. The row keeps its `supersedes_id`, so the history shows what was opened and withdrawn.
- **"Latest version" ignores a withdrawn successor.** Readers that took "no successor" as latest now take "no successor that is not withdrawn": `visit_facts_locked` (so the facts lock again), `field_reports` (never shows a withdrawn row), `correct_report` (`not_latest`), `generate_billable_facts`; `report_correction_open` counts only `draft` and `signed` corrections. The unique "one successor" index excludes withdrawn rows. A new correction takes the next free version number (`max + 1`), so a withdrawn number is never reused and the gap stays visible. Readers that select `status = 'final'` (billing, preview, report-not-final, AN1) were already correct.
- **`withdraw_report_correction(report, key)`**, security definer, idempotent (begin/end command): `not_team_member`, `not_performer`, `not_correction` (a first draft: the visit would have no report), `awaiting_countersignature` (D-10), `not_draft`, `draft_has_changes`; an already withdrawn draft answers `ok` with `already_withdrawn` and writes nothing. **Untouched** = no `visit_time_corrections` row and no `visit_observations` row for the visit since the draft's `created_at` (the only facts the draft unlocks, 0040), **and the summary equals the corrected version's**. The summary condition is stricter than the criterion (recorded deviation): a summary she typed lives only in the draft and would vanish without a signed version; she signs it or leaves it. Its rows lock the visit's report rows like the other commands.
- **CGR-29 in the lift branch of the hold trigger.** On the last lift, if the visit's latest final version has no J5-v3 `report` fact, `build_billable_fact` builds it (same function, signed snapshot, lifter as `created_by`); otherwise the pre-hold fact is restored as before. Wider than the finding: this also runs when the fact before the hold was not billable (then no hold fact existed and the old branch did nothing).
- **J5-C1 as a copy with recomputed payer reasons, not a rebuild.** `private.rederive_fact_payer(visit, actor)` copies the visit's head J5-v3 fact, recomputes only `payer_not_modelled` and `no_insurer` (the same tests as `build_billable_fact`) and the `insurer` and `insurance_type` keys of `payer_chain`, and appends it as cause `basis_changed` (new value of the cause check; `hold_id` only for hold causes) superseding the head. A rebuild was rejected: it would re-read the case's order and so make an earlier visit billable through a later order end date, which D-22 (`legal`) has not allowed. Fired by an `after update of insurance_type, insurer_name` trigger on `cases` (whatever command writes them) with `auth.uid()` as `created_by`; without a signed-in user nothing happens at once and `generate_billable_facts` re-derives later (catch-up, the generating user is recorded). Not under an open hold; the last lift re-derives after restoring.
**Consequences:** a correction opened by mistake no longer stays open or forces a signature for nothing; the record and the signed snapshot still never diverge. After a hold, billing follows the last signed version. An intake fix of the payer reaches billing without a nurse's signature. pgTAP 043 changed where it assumed that payer edits leave earlier facts alone (assertions now reflect J5-C1; plan unchanged at 49).
**Rollback:** drop `withdraw_report_correction`, the `cases` trigger, its function and `rederive_fact_payer`; restore `guard_visit_report`, `visit_facts_locked`, `field_reports`, `correct_report`, `derived_exceptions`, `billable_fact_follow_hold`, `generate_billable_facts` from 0016/0040/0041/0044/0047/0043/0043; withdrawn rows would need a status before the original checks return (data decision, not automatic).
**Open:** D-10 (`clinical`): whether a countersigner may return a signed correction. D-22 (`legal`): order changes; also UNKNOWN for the PO whether D-22 covers a fact built for a **new** report version (a correction, or CGR-29's build), which reads the case's order at build time as in 0043. AN2 measure 6 can now count how corrections end (final or withdrawn).

### ADR-061 — ABS1 part 3: no hand command gives a visit to an absent member; a move into her absence releases the visit; `released` counts only the caller's teams
**Status:** PROPOSED · **Task:** ABS1 (brief `docs/agents/briefs/ABS1.md`, PO review 2026-10-23 16:18: `changes-requested` with ABS1-C4 and ABS1-N1), part 3, built under the active CSR1 issue #149 (PO 16:55; no `eng:ABS1` hand-off, WATCH-1). Migration 0050, pgTAP `050_abs1_part3` (31), `048_abs1_part2` adjusted (one assertion, ABS1-N1). Remediation plan `docs/agents/clinical/remediation/ABS1-C4.md`. Clinical gate: no Clinical Governance Report section covers ABS1-C4 (the newest, 14:30 and 15:00 on PR #203, predate it). Amends ADR-057 and ADR-059.
**Decision:**
- **`plan_visit` refuses `responsible_absent`.** After the team and qualification checks, the visit's interval is computed with the one interval function of 0048 (`private.visit_interval` over a record built from the arguments with `jsonb_populate_record`, so there is no second copy of the arithmetic) and checked with `member_absent_during` (the person in the organisation, 0048). Refused before anything is written; the command log records `rejected`. Planning the same visit without a responsible member is unchanged and lists it in "Offen im Team". Chosen over leaving the visit planned and releasing it at once: the planner is in front of the screen, and a refusal with the reason tells her what to do instead.
- **`reschedule_visit` into her absence releases, never refuses** (PO: the move itself is legitimate). The move is written and logged first (`moved`, with its reason), then the visit goes through the one release rule (`private.release_visits_between`, fixed text `Abwesenheit`, `released` in the J3 log), so the team sees the move and then the release, HAND1 shows "wieder offen im Team", and `visit_uncovered` applies. The release window is the part of the visit's interval that lies inside the absence; any other visit of hers in that window lies inside the absence as well, so the shared rule releases nothing that the absence itself would not. The release is linked in `absence_releases` to the absence row **of the visit's team**, so withdrawing or shortening returns the visit untaken (as for visits released when the absence was recorded) and AN1 counts it. The result carries `released` (true/false); `/team` says "Der Einsatz ist jetzt offen im Team".
- **`record_absence` counts `released` over the caller's own teams only (ABS1-N1).** The release itself is unchanged (all her teams). `teams` (how many teams the absence applies to) stays; it is not a visit count.
- Both commands are changed by a checked patch of their current definitions (each find must match once, as in 0046/0048); signatures and grants are unchanged, so the generated types do not change.
**Consequences:** every path that makes a member responsible for a planned visit now checks her absence: `record_absence` (release), PLAN2, `take_open_visit`, `plan_visit`, `reschedule_visit`. Not yet `accept_cover` (cover is off, D-3; it is a COVER1 condition).
**Rollback:** re-run the definitions of `plan_visit` and `reschedule_visit` from 0014 and `record_absence` from 0048. Visits already released stay released (open in the team), which is the safe side.
**Open / deviations:** (1) a visit moved into her absence in a team that has **no** row for that absence (she joined after it was recorded) is released but not linked, so withdrawing the absence leaves it open in the team rather than returning it (safe side; pgTAP asserts it). (2) The release rule never touches visits dated before today (0046), so a move to **yesterday** (allowed by `check_visit_slot`) inside her absence is not released (`released: false`); such a visit is already past and is caught by `visit_overdue` (CSR1). UNKNOWN whether the PO wants that move refused instead. (3) A visit covered by another team's nurse is released like any other when moved into its responsible member's absence (cover is off, D-3).

### ADR-062 — CSR1 part 10: a fact's order basis is the order as recorded at the end of the visit date (J5-C2)
**Status:** PROPOSED · **Task:** CSR1 part 10 (brief `docs/agents/briefs/CSR1.md`, PO review 2026-10-23 16:55, condition J5-C2; `docs/agents/briefs/J5.md`), active issue #149. Migration 0051, pgTAP `051_csr1_order_as_of_visit_date` (35). Rule register CR-058 (PROVISIONAL, D-22).
**Context:** facts are built when `generate_billable_facts` runs, for a correction version, or at the last lift (CGR-29), and `build_billable_fact` (0043) read the case's order at that moment. An order end date entered after the visit therefore made the earlier visit billable whenever its fact was built later (engineering's UNKNOWN, ADR-060).
**Decision:**
- **Cut-off:** `private.order_cutoff(visit_date)` = the first instant of the next day in Europe/Zurich. A change recorded before it counts; at or after it, not. It is the one function D-22 changes.
- **Reconstruction from the audit log, backwards from the live row:** `private.case_order_as_of(case, at)` takes, per column (`medical_order_status`, `medical_order_valid_until`), the `old` value of the earliest audited change at or after the cut-off, else the live value. The 0013 trigger `audit_cases` (after insert or update, both columns allowlisted, SECURITY DEFINER, no app path can skip it) records every write since the columns exist, so the history is complete. A case taken on after the visit date reads as "nothing on file". No separate "history missing" reason is needed (deviation from the brief's wording, which allowed one).
- **Rules unchanged:** the CGR-07 order rules of 0043 are moved, unchanged, into `private.order_reasons(status, end date, visit date, B minutes)` and applied to the order as of the cut-off. `private.order_basis_as_of` adds **`order_recorded_after_visit`** when that order yields an order reason and the live order would yield none, so the team sees why a visit with a valid order today is not billable. It never stands alone.
- **The fact records what it used:** `billable_facts.order_as_of` (the cut-off) and `order_recorded` (`{"status", "valid_until"}`). Table-level select (0022) and RLS (`scoped_read`) unchanged; facts stay immutable.
- **One path for every build:** first generation, a correction version and CGR-29's build all go through `build_billable_fact`, so criterion (c) holds without a second rule.
- **Catch-up of facts built before 0051** (`order_as_of` null): `private.rederive_fact_order` re-derives the order part of the visit's latest J5-v3 fact from the same snapshot when it differs (new fact, cause `basis_changed`, created by the generating or lifting user), in `generate_billable_facts` and after the last lift. Hold facts are skipped (the lift handles them). No catch-up in the migration itself: no signed-in user to attribute it to (same as J5-C1, 0049).
- **J5-C1 and the hold trigger** are re-created only so their copies carry the two new columns; the payer re-derivation still never recomputes the order.
**Consequences:** the order basis of a fact no longer depends on when it is built. An A/C-only visit whose order was recorded after the visit date is read as "without order" (`without_order_ac`, billable as before 0043 allowed for A/C), not as `order_validity_missing` from the later order: the visit is judged as it stood on its date.
**Rollback:** re-run `build_billable_fact` from 0043, `rederive_fact_payer`, `billable_fact_follow_hold` and `generate_billable_facts` from 0049; the two columns can stay (nullable). Facts written meanwhile stay (immutable).
**Open / deviations:** (1) the cut-off compares with `audit_events.occurred_at`, which is the transaction start: a change started before midnight and committed just after counts for that date (seconds). (2) A pre-0051 fact stays as it was until the next generation or lift of its visit (no real data, D-1). (3) Planning flags (0014, 0030) still read the live order; that is planning, not billing, and unchanged. (4) D-22 (`legal`) may move the cut-off (e.g. to the billing date) or require the order on file before the visit; only `order_cutoff`, and for the latter `case_order_as_of`'s time argument, change.

### ADR-063 — ABS1-C5: a move that would leave a visit with an absent member is refused and writes nothing
**Status:** PROPOSED · **Task:** ABS1 (brief `docs/agents/briefs/ABS1.md`, PO review 2026-10-23 18:15, condition ABS1-C5, patient safety), riding along with CSR1 part 10 in #216 under the active issue #149 (WATCH-1). Migration 0052, pgTAP `052_abs1_c5_no_past_move_into_absence` (12).
**Context:** ADR-061 open point (2): the release rule (0046) never touches visits dated before today, so `reschedule_visit` to yesterday inside the responsible member's absence wrote the move and left the visit with her. PO decision 18:15 (product authority, strict default): refuse it.
**Decision:**
- `reschedule_visit` (patched once more on its current definition, each find matching exactly once, as 0050) runs the move, its `moved` log row and the ABS1-C4 release in one subtransaction. If afterwards the visit still names a responsible member absent at its interval (`member_absent_during` over `visit_interval`, 0048), it raises an internal SQLSTATE `NVC05`, caught in the same function: everything in the block, audit rows included, is undone and the command returns `{"result": "rejected", "reason": "responsible_absent"}`.
- The check is on the outcome ("still hers while absent"), not on "date before today", so any other gap in the release rule is refused the same way.
- A refusal writes no audit row, so a replay with the same key is evaluated again (as every rejection; idempotency is keyed on audit rows, 0004).
- `/team` shows a move-specific text for this refusal (the plan text offers "without responsible member", which the move form does not).
**Consequences:** a move into her absence today or later still releases (ABS1-C4 (c), pgTAP 050 and 052 (c)); a move to yesterday outside any absence is unchanged.
**Rollback:** re-run the 0050 definition of `reschedule_visit`.
**Open:** whether a planned visit may be moved into the past at all is not decided (PO, brief 18:15).

### ADR-064 — CGR-33: a pgTAP guard keeps the order history that J5-C2 reads complete
**Status:** PROPOSED · **Task:** CGR-33 (Clinical Governance Report 2026-10-23 19:00, advisory S2; Safety Risk Register BL-15, owner eng), under the active issue #149 (CSR1). Test only: pgTAP `053_cgr33_order_audit_guard` (21). No migration, no rule.
**Context:** ADR-062 reconstructs a fact's order basis backwards from the live case row through `audit_events`. That holds only while `audit_cases` records every insert and update of `medical_order_status` and `medical_order_valid_until`, and `audit_events` stays append-only. `audit_cases` was re-created twice (0010, 0013); nothing failed if a third re-creation dropped a column.
**Decision:** one pgTAP file asserts, from the catalog, that `audit_cases` exists on `public.cases`, calls `private.write_audit_event`, fires after insert and update for each row with no `UPDATE OF` column list, is enabled, and names both order columns among its arguments; and, by behaviour, that two order edits leave two audit rows in the `{old, new}` shape that `private.case_order_as_of` reads back (before the edits at their instant, live after). It also asserts that update, delete and truncate of `audit_events` are refused with `42501` for the table owner, that `authenticated` holds only `SELECT` and `anon` nothing.
**Consequences:** a migration that weakens either premise of J5-C2 turns CI red. No behaviour changes.
**Rollback:** delete the test file.
**Open:** none. The guard does not cover a write with `session_replication_role = replica` (superuser only, not an app path; UNKNOWN whether any operator procedure uses it).

### ADR-065 — CGR-32: a past planned visit inside a newly recorded absence keeps its member and is flagged, not released
**Status:** PROPOSED · **Task:** CSR1 part 11 = CGR-32 (ABS1 acceptance condition, PO 2026-10-23 19:12 in `docs/agents/briefs/ABS1.md`; `cra` 19:00 advisory S3, endorsed 19:46), under the active issue #149. Migration 0053, pgTAP `054_csr1_cgr32_past_visit_absence_flag` (34), unit test (label), e2e `field.spec.ts` (CGR-32, phone width).
**Context:** an absence may start in the past. The one release rule (0046) acts from today on, so her planned visits dated before today inside the new absence kept her as responsible, and their `visit_overdue` alert read "zuständig: <Name>" as if she had simply not started. PO decision (product authority, not a clinical rule): keep them with her, count them, flag the alert; never release them, never refuse the absence.
**Decision:**
- `record_absence` (patched on its current definition, each find matching once) returns `past_planned`: planned visits dated before today (Europe/Zurich) whose interval (`private.visit_interval`, 0048) overlaps the new absence and that name the absent member, summed over the caller's own teams only (ABS1-N1). Nothing is written for them. `change_absence` only withdraws or shortens (the start never moves earlier), so it cannot add such visits and returns no `past_planned`.
- One helper `private.visit_responsible_absent(visit_id)` (not executable by app roles): planned, a responsible member, and `member_absent_during` at the visit's interval. Computed at read time from the absence, never stored: withdrawing or shortening clears it.
- `team_visit_alerts()` (/team) and `operations_exceptions()` (OPS1) gain `flags text[]`; a `visit_overdue` row carries `responsible_absent` when the helper is true. A new return column needs drop and create: both readers are regenerated from their current definitions (no hand copy), grants and comments restated. `pilot_kpis` reads `operations_exceptions()` by count only (asserted in 054).
- The app shows the fixed label "Zuständige Person abwesend gemeldet" (`alertFlagLabels`, unit-tested), once per alert, on `/team` and in OPS1. No reason and no free text exist to show.
- Generic on purpose (as ADR-063): the flag tests "planned visit names a member absent at its interval", not "before today". From today on the release rule leaves no such visit, so in practice it marks exactly CGR-32's visits.
**Consequences:** the visit keeps one accountable trail and stays an open exception until the team decides (follow-up visit, or closed with a reason: existing commands). Whether the missed care must be made up stays with `clinical` (D-28, D-31). Result shape of `record_absence` gains a key (pgTAP 048 and 050 exact-match assertions updated).
**Test fixtures:** the seed gains an ended absence of `assist.test` for all of yesterday and her planned visit 532 yesterday 07:00 (e2e); pgTAP 004 (visit count 9 → 10) and 046 (absence row count limited to rows of the test transaction) adjusted. pgTAP 046's `hand`, `overdue` and `later` fixtures now stay on today's date at any time of day (they rolled to tomorrow after 20:00/21:00 Zurich and turned CI red in the evening; found running the suite locally at 20:25).
**Rollback:** re-run the 0050 definition of `record_absence` and the 0047 definitions of both readers; drop the helper.
**Open:** the `/field` absence form allows a start from today only (`min={today}`), so "krank seit gestern" can be recorded only through the command today (UI change not ordered; PO). The OPS1 flag shows a coordinator that the named member was reported absent (no reason): as ordered by the PO 19:12.

### ADR-066 — CGR-34: the cancellation of a flagged past visit stores that its responsible member was absent
**Status:** PROPOSED · **Task:** CSR1 part 11 remainder = CGR-34 (ABS1 condition with CGR-32; PO decision 2026-10-23 20:15 in `docs/agents/briefs/ABS1.md`, PR #227, not yet merged when this was built; `cra` addendum 19:57, PR #226, advisory S3), under the active issue #149. Migration 0054, pgTAP `055_csr1_cgr34_cancel_keeps_absence` (26), unit tests (labels), e2e `field.spec.ts` (CGR-34, phone width).
**Context:** a past planned visit flagged by CGR-32 (ADR-065) is closed with `cancel_visit` (0024). The flag is computed from the absence, so after the cancellation the record read as an ordinary cancellation; that the care was due and not given because the responsible member was absent was lost for the team, HAND1, OPS1 and AN2. PO decision (product authority, documentation integrity, not a clinical rule): NAVORA records what it already knows; no new reason code, no extra tap.
**Decision:**
- `visit_status_notes.responsible_absent boolean not null default false`, with a check that only a `cancelled` note can carry true. The table stays append-only (0024 trigger), so the fact is immutable; `authenticated` has no write privilege on the table and `cancel_visit` has no parameter for it. Existing rows get false (nothing was recorded before).
- `cancel_visit` (same signature and grants, full definition restated from 0024, the only definition so far) sets it when, at the moment of the cancellation, the visit is `planned`, dated before today (Europe/Zurich) and `private.visit_responsible_absent` (0053) is true. An `on_the_way` visit, a future visit and a past visit without an absence store false.
- The audit trigger on the table now also records `responsible_absent`.
- Readers: `field_visit_status_notes` returns the column (drop and create; grants and comment restated); HAND1 `private.handover_entries` adds it to the detail of a status-note entry (patched on its current definition, the find must match once); `operations_exceptions` gives a `team_cancellation_late` row the flag `not_done_responsible_absent` when its cancellation stored the fact (a team cancellation of a past visit is listed there by the 0024/0031 rule; return type unchanged, patched in place).
- The app shows the fixed text "nicht durchgeführt: zuständige Person abwesend gemeldet": on the `/field` card as "Abgesagt (<reason>) · nicht durchgeführt: …" (`cancellationText`, `RESPONSIBLE_ABSENT_NOTE`), in HAND1 as a line of the "Einsatz abgesagt" entry, in OPS1 via `alertFlagLabels`. No reason for the absence exists to show.
**Consequences:** the stored fact survives a later withdrawal or shortening of the absence (asserted in 055). The overdue flag of CGR-32 stays computed. Whether missed care must be made up or reported stays with `clinical` (D-28, D-31). The `/field` cancellation line changes from "Abgesagt: <reason>" to "Abgesagt (<reason>)" for every cancellation (the PO's wording).
**Test fixtures:** none added to the seed. The e2e cancels the seed's CGR-32 visit 532 after the CGR-32 test in the same file (one worker, declared order); later specs do not depend on 532 being planned.
**Rollback:** re-run the 0024 definition of `cancel_visit` and the 0047 definition of `field_visit_status_notes`, re-run the 0053 definition of `operations_exceptions` and the 0046 definition of `handover_entries`, recreate the audit trigger with `kind`, `reason_code`; the column can stay (default false).
**Open:** UNKNOWN whether the PO wants the HAND1 entry and the OPS1 flag worded exactly as on the card (implemented with the same fixed text). The PO decision is read from PR #227, which was not merged at build time; if it changes before merging, this ADR follows it.

### ADR-067 — ABS1-C6: "krank seit gestern" from the app; the confirmation names open past visits
**Status:** PROPOSED · **Task:** CSR1 part 12 remainder = ABS1-C6 (PO decision 2026-10-23 21:17 in `docs/agents/briefs/ABS1.md`, PR #231, not yet merged when this was built), under the active issue #149. PR #234. No migration.
**Context:** the `/field` absence form set `min={today}`, so an absence from yesterday could be recorded only through the command, and CGR-32's `past_planned` (ADR-065) and its overdue flag never appeared from the app (ADR-065 *Open*). PO decision (product authority, not a clinical rule): offer yesterday, no earlier, and name the open past visits.
**Decision:**
- "Von" gets `min` = yesterday (`earliestAbsenceStart(today)`, Europe/Zurich day from the page). "Bis" keeps `min` = today: an absence that has already ended is refused `in_past` by `record_absence`. `record_absence` is unchanged and still accepts what it accepted before; the lower bound is an app rule only.
- `recordAbsence` returns `{ ok: true, pastPlanned }` (`pastPlannedOf`, 0 on a replay or when the field is missing). The section shows `pastPlannedNotice(n)`, the fixed text "<n> vergangene Einsätze sind noch offen: bitte im Team entscheiden", with a link to `/team`, when n > 0; nothing at 0. No reason, no free text, no name. The visits are not released (CGR-32 unchanged).
**Consequences:** the CGR-32 flag on `/team` and in OPS1 is now reachable from the app. AN2 measure 8 can count absences started yesterday from `member_absences.starts_at` vs. `created_at`; nothing new is stored.
**Test fixtures:** the seed no longer holds the ended absence of `assist.test` (ADR-065); the e2e "ABS1-C6" records it on `/field` as a colleague, before the CGR-32 and CGR-34 tests in the same file, which run on that state. Visit 532 stays seeded; pgTAP assertions filter by visit id or `created_at`, so they do not depend on the seeded absence.
**Rollback:** revert the PR (UI only) and restore the seeded absence.
**Open:** the text is literal from the PO decision, so n = 1 reads "1 vergangene Einsätze …"; whether a singular form is wanted is a `po` question (UNKNOWN).

### ADR-068 — One calendar "today" for the database: Europe/Zurich
**Status:** PROPOSED · **Task:** engineering fix (no capability), found by CI on PO PR #238 (run 40030758280, 2026-10-24 00:03 Zurich). Migration 0055, pgTAP 056.
**Context:** most commands derive today as `(now() at time zone 'Europe/Zurich')::date`; five function bodies used `current_date`, which follows the session time zone (UTC on Supabase and in CI). The seed, 16 pgTAP files and two e2e specs also used the UTC date, while seed visit 532 (ADR-067) and the app use the Zurich date. Between 00:00 and 02:00 Zurich (summer; 00:00–01:00 in winter) the two differ by a day: CI went red in pgTAP 008, 015, 043, 044, 049 and e2e field F1. In the product (IMPLEMENTED before this ADR, now corrected): OPS1 "order expiring" and "care-plan review overdue", `pause_case` (expected end not in the past), `apply_case_facts` (requested-start window) and `add_care_plan_item` (review date not in the past) judged dates against yesterday during that hour or two.
**Decision:**
- Migration 0055 re-creates every function in `public`/`private` (extension functions excluded) whose body mentions `current_date` from its own current definition, with `current_date` replaced by the Zurich date; signatures, grants, owner, security and search_path unchanged; it fails if one remains; idempotent. No threshold, rule or text changes.
- pgTAP 056 guards it: no function body in `public`/`private` may use `current_date`.
- Seed and pgTAP use the Zurich date everywhere; e2e `field.spec.ts` and `quality.spec.ts` derive the seed day from the Zurich calendar (`zurichDay`). pgTAP 044 reads a report on its visit's own Zurich date (a visit 2–3 hours ago is yesterday shortly after midnight).
**Consequences:** the product behaves the same at every hour; CI is no longer red between 00:00 and 02:00 Zurich. Remaining wall-clock dependency (OPEN): tests that place visits at `now() ± N hours` still assume the offset stays inside one Zurich day where they query by date; only 044 failed and is fixed.
**Rollback:** revert the PR. The migration has no data effect; a revert leaves the corrected functions in place until a later migration redefines them (functionally harmless).
**Addendum 2026-10-24 (DAY-1-R1–R3, PO review 01:15 in `docs/agents/briefs/AN2.md`; AN2 first PR, migration-free, pgTAP 058):**
- **R1 guard widened** (pgTAP `058_zurich_day_guard_and_split_day`): besides `current_date` (056), no function body in `public`/`private` may derive a day from the session time zone: `now()`/`transaction_timestamp()`/`statement_timestamp()`/`clock_timestamp()` cast to `date`, `current_timestamp::date`, `localtimestamp`, `localtime`, `cast(… as date)`, `date(now())`, `date_trunc('day', now())`. Views and materialised views in those schemas may use none of them, nor `current_date` (none exist today). The patterns are tested against good and bad samples first, so the guard cannot pass by matching nothing. Still no single helper: the inline expression stays (deviation accepted by the PO on the condition of this guard).
- **R2 test clock = the session time zone, set per transaction.** pgTAP cannot move `now()`, and a clock override inside product functions would be a hook a caller might reach. Instead the test sets `timezone` (transaction-local) to a zone whose calendar date differs from the Zurich date at the moment the test runs: `Pacific/Pago_Pago` (UTC-11) before 12:00 Zurich, `Pacific/Kiritimati` (UTC+14) from 12:00. `current_date`, `now()::date` and `localtimestamp` then give another day than Zurich, which is exactly the failure UTC causes between 00:00 and 02:00 Zurich. Every check uses a pair of values whose expected result holds only with the Zurich day (with the session day one earlier or one later both give a different result): order end = today + threshold vs. + threshold + 1 (`order_expiring`), review date yesterday vs. today (`care_plan_review_overdue`), both through `private.derived_exceptions` and OPS1 `operations_exceptions`; `pause_case` refuses an expected end of Zurich yesterday and accepts Zurich today. Thresholds are read from `exception_rules` (D-28 unchanged). The test runs in every CI run, at any hour. Verified locally (plain PostgreSQL 16 with all migrations and the seed, a minimal stand-in for the pgTAP functions used, not pgTAP itself): it passes on the current functions and fails (7 of 15) when `derived_exceptions` and `pause_case` are put back to `current_date`.
- **R3 hosted database time zone: an owner check once staging exists (D-2).** The product no longer depends on it (R1, R2), but it is UNKNOWN for the hosted project: Supabase's default is UTC, and a project or role setting can change it. When staging exists (D-2, `owner`), the owner (or engineering with the owner's access) runs `show timezone;` and `select current_setting('TimeZone');` as the API roles on the staging database and records the result here; a value other than UTC is not an error, but any difference from CI's UTC is written down so test results transfer. Engineering never touches the live project `jwmfxrmougneeceldhsa` for this.

### ADR-069 — CGR-35: a move of a flagged past visit stores that its responsible member was absent
**Status:** PROPOSED · **Task:** AN2 first change (issue #205): CGR-35 (PO decision 2026-10-23 23:15 in `docs/agents/briefs/ABS1.md`; `cra` 22:30, advisory S3, PS-28) with ABS1-C7 and DAY-1-R1–R3 in the same PR. Migration 0056, pgTAP `057_an2_cgr35_moved_keeps_absence` (24), unit tests (HAND1 line, singular text), e2e text update.
**Context:** a past planned visit flagged by CGR-32 (ADR-065) is most often moved forward ("Folgeeinsatz") with `reschedule_visit`. The `moved` row read as an ordinary planning change; once the absence was shortened or withdrawn, the fact that care due on the original date was not given because the responsible member was reported absent was lost. ADR-066 closed the same gap for `cancel_visit`. Same answer (product authority, documentation integrity, not a clinical rule): store what NAVORA already knows; no new reason code, no extra tap.
**Decision:**
- `visit_plan_changes.responsible_absent boolean not null default false`, check: only a `moved` row can carry true. The table stays append-only (0014 trigger), `authenticated` keeps select only, `reschedule_visit` has no parameter for it. Existing rows get false.
- `reschedule_visit` (patched on its current definition; every find must match exactly once; idempotent through a marker) reads, before the update, `planned` and dated before today (Europe/Zurich) and `private.visit_responsible_absent` (0053), and stores the result on its `moved` row. The read sits inside the ABS1-C5 subtransaction, so a refused move writes neither the row nor its audit.
- Audit: `visit_plan_changes` had no audit trigger and its id is a bigint, so the generic `write_audit_event` (entity_id uuid) does not fit. A dedicated insert trigger `audit_visit_plan_moves` (only `change = 'moved'`) writes one `audit_events` row with entity = the visit, table `visit_plan_changes`, `changed = {change, responsible_absent}`, command and idempotency key of the calling command. It also audits the `moved` rows written by `accept_cover` and `withdraw_cover` (always false); cover moves are out of CGR-35's scope.
- Readers of a `moved` row: HAND1 `private.handover_entries` adds `responsible_absent` to the detail of plan-change entries; `/team` `team_cases().upcoming[].last_change` returns it. The app shows the fixed text "nicht durchgeführt: zuständige Person abwesend gemeldet" as a line of the HAND1 "Einsatz verschoben" entry (`entryLines`) and after the "Verschoben …: <reason>" line on `/team`. OPS1 lists no moves, so nothing changes there. No reason for the absence exists to show.
- ABS1-C7 (decides ADR-067 *Open*): `pastPlannedNotice(1)` reads "1 vergangener Einsatz ist noch offen: bitte im Team entscheiden"; n ≥ 2 unchanged.
**Consequences:** the stored fact survives a later withdrawal of the absence (asserted in 057). AN2 measure 8 counts moved flagged visits from this column. Whether missed care must be made up, and whether a move counts as making it up, stays `clinical` (D-28, D-31).
**Rollback:** re-run the definitions of `reschedule_visit` (0052 patch on 0050), `handover_entries` (0054) and `team_cases` from before 0056, drop the trigger and its function; the column can stay (default false).
**Open:** none for engineering. `cra` look at 0056 requested with the PR.

### ADR-070 — AN2 part 2: Pilot-Hypothesen as one read model; AN1 organisation-level suppression
**Status:** PROPOSED · **Task:** AN2 (issue #205, `docs/agents/briefs/AN2.md`), part 2; with the AN1 condition of the PO review 2026-10-22 17:15 (due "in engineering's next PR that touches `pilot_kpis`"; 0043 and 0048 touched it without it: recorded deviation, closed here). Migration 0057, pgTAP `059_an2_pilot_hypotheses` (57), fixtures of pgTAP 027, 030, 032, 033, 034, 048 adjusted, unit `analytics-hypotheses`, e2e in `analytics.spec.ts`.
**Context:** the brief asks for about a dozen measures, each from existing events, per team and organisation, never per nurse, with AN1's access and suppression rules; its open questions: one function or one per measure; can measures 1 and 10 reuse `exception_events`.
**Decision:**
- **One function** `public.pilot_hypotheses(p_month date)` returning `(organization_id, team_id, team_name, measure, detail, value, base, too_few, suppressed, note)`, `stable security definer`, `search_path = ''`, execute for `authenticated` only. Access exactly as `pilot_kpis` (coordination roles: organisation + all teams; members: their teams). One function keeps one access rule and one suppression rule; a measure is a CTE. `detail` carries a fixed code only (J5 reason codes for measure 7).
- **Period** = the visits dated in the month (calendar dates, Europe/Zurich by construction of `visit_date`), with their later events up to now. One cohort for every measure, so a figure never mixes "facts created in October" with "visits of September".
- **Every measure in every scope**: a catalogue cross-joined with the scopes, so a measure without events shows base 0 ("zu wenig Daten") instead of disappearing.
- **Suppression (AN1 rule, one definition):** `private.pilot_team_people` (distinct performers of completed visits in the period, AN1's `team_people`) and `private.pilot_org_suppressed` (fewer than 3 persons in the organisation, or the persons of all hidden teams together number 1 or 2). AN2 rows of a hidden team or organisation show **neither value nor base** (`suppressed = true`, note "Zu wenig Personen …"): the base is an inference channel too (the PO's AN1 review named it). `pilot_kpis` gets the organisation rule, patched on its current definition (every find must match exactly once); its existing behaviour (base shown on suppressed rows) is otherwise unchanged; `open_p1_exceptions` stays visible ("Stand jetzt", shown in OPS1 anyway, no person behind it).
- **Measures in this part:** 3, 5, 6, 7, 9, 11, 12 (sources and definitions in the migration header and on the page). Choices: measure 3 "coordination role" = the CGR-26 `coordination` label (admin/coach/operations of the organisation, not in the visit's team); measure 5 counts withdrawn correction drafts as versions, and "signed again with no change" requires the same snapshot hash **and** the same summary (the summary is not in the snapshot; a summary-only change is a change); measure 6 re-derives the `report_correction_open` window from the effective `report_not_final` threshold (0047), ends at final (signature or countersignature) or withdrawal; measure 7 (AN2-M7) keeps `below_minimum` on its own row with the fixed note and leaves facts whose *only* reason is `below_minimum` out of the total and of the days-to-billable median (a fact with another reason as well stays in the total); measure 9 "P1 threshold" = planned end + `visit_stuck` amount + its P1 escalation hours; measure 12 "visit end" = the last `completed` event with time corrections (AN1's `ended_at`).
- Thresholds are read as they are now (`private.effective_exception_rules`); no history of rule values exists, so a changed override re-colours past months. Stated on the page ("Schwelle wie heute eingestellt (provisorisch, D-28)").
- **UI:** `/analytics` section "Pilot-Hypothesen", one block per scope (`role="group"`, so AN1's region names stay unique), one card per hypothesis (the brief's number, a German one-liner, the challenge row it tests by title, the source), one line per measure with value, "Basis", period. At phone width the sidebar is hidden and AN1 tables scroll in their own box; the page never scrolls sideways.
**Consequences:** AN1's organisation rows are now hidden in small pilots (the seed shows "zu wenig Personen" everywhere). Six existing pgTAP files got a fixture (three more synthetic performers in two small teams, or a reshaped first team) so their organisation figures stay visible; pgTAP 032's last assertion ("the organisation figure stays") is replaced by the PO's condition, which says the opposite for that fixture.
**Not built (PLANNED, next part):** measures 1, 2, 4, 8 (with AN2-M8a), 10. Measures 1 and 10 will reuse `exception_events` with the derived exception keys, as `cover_without_operations` does (answer to the brief's second question: yes).
**Rollback:** drop `public.pilot_hypotheses(date)`; re-run `pilot_kpis` from before 0057 (0048 state); drop the two helpers.
**Open:** none for engineering. The `cra` 02:26 proposals (minute distribution around the minimum duration; planned to actual start) are not in the brief and not built: PO.

### ADR-071 — AN2 part 3: measures 1, 2, 4, 8 (AN2-M8a) and 10 replayed from logs
**Status:** PROPOSED · **Task:** AN2 (issue #205, `docs/agents/briefs/AN2.md`), part 3; completes the brief's measure list. Migration 0058, pgTAP `060_an2_pilot_hypotheses_part3` (48), pgTAP 059 count 17 → 35 (catalogue grew; no assertion weakened), unit `analytics-hypotheses`, e2e `analytics.spec.ts` (12 hypothesis cards, AN2-M8a row).
**Context:** the five remaining measures need the *history* of an exception, a responsible member or an absence, while exceptions are derived from current state (ADR-035) and only their handling is logged.
**Decision:**
- **Same read model** `public.pilot_hypotheses(p_month)` (ADR-070), re-created with the same signature, access, suppression and period; one CTE per measure. Every 0057 measure is unchanged (copied verbatim; the diff adds CTEs, catalogue rows and notes only).
- **Measure 1** replays the responsible member from `visit_plan_changes` (`released`, `taken`, `returned`; before the first change its `before`, else today's value). The `visit_uncovered[_hospital]` exception starts at the first moment inside its window (planned start minus the effective threshold; kept after the start, 0038 PS-2) with nobody responsible, and ends with the next change of the responsible member. "Taken by the team" = that change is a `taken` (ABS1 "Offen im Team") with no OPS1 `take`/`close` on the key before it: one definition with AN1 `cover_without_operations` (the brief's second question: yes, `exception_events` and the derived keys are reused).
- **Measure 2:** `follow_up_planned` decisions (0045) with no visit of the same case *created* within 48 h (a `planned` row in `visit_plan_changes`, or a new `care_visits` row). Decisions younger than 48 h without a visit are not judged yet. A moved existing visit does not count (the brief says "created"); the row says so.
- **Measure 4:** `moved` rows, and `released`/`taken`/`returned` rows that change the responsible member, less than 24 h before the start **as planned at the change** (the row's `before` slot), per 100 visits of the month. Absence releases are included (the brief names all responsible-member changes).
- **Measure 8:** absences whose start (Europe/Zurich date) is in the month; team rows count the team's rows, the organisation row each `absence_group` once (ABS1-C3). "Revised within 48 h" = shortened (the `ends_at` audit row with an old value) or withdrawn within 48 h of recording, or followed within 48 h by a new absence of the same member adjacent to or overlapping the period as first recorded. Past flagged visits are replayed as CGR-32 saw them at recording time (planned, no visit event before the recording, dated before the recording day, naming her, interval as planned then — a later move's `before` slot — inside the absence as first recorded); their first ending is one fixed code: `started_late`, `cancelled` (CGR-34 mark), `cancelled_without_mark`, `moved` (CGR-35 mark), `moved_before_capture`, `still_open`, `other`.
- **AN2-M8a:** a move counts as `moved` only when its row stores `responsible_absent = true`. 0056 recorded no time, so 0058 stores a capture start in `private.an2_capture_starts` (RLS on, no grants): the earlier of the migration time and the first stored `true`, a safe lower bound. A flagged visit moved before it shows `moved_before_capture` with the note "vor Erfassung (nicht gezählt)", never "nicht abwesend".
- **Measure 10:** `visit_overdue` (one per visit: planned start + effective threshold, while still planned) and `visit_stuck` (one per status change into on the way, started or paused, key `visit_stuck:<visit>:<event>`, reference as in 0038). Ended by the next visit event (a command) or closed by hand first (`exception_events` `close` on the key). Base = every such exception in the period, also those still open. Since CSR1 (0044, CGR-06) these escalating exceptions cannot be closed by hand, so "closed by hand" measures the time before that rule and confirms it after.
- Rows that depend on a threshold carry "Schwelle wie heute eingestellt (provisorisch, D-28)" (1, 10), as in 0057.
- **AN2-M9a** (PO 2026-10-24 07:10, with ADM1-R): the measure-9 row `visits_open_past_p1` names the value it used, from the organisation's effective `visit_stuck` rule today: "Schwelle heute: geplantes Ende + <n> Std. + <m> Std. bis P1. Wie heute eingestellt (provisorisch, D-28)."
**Known limits (stated, not hidden):** thresholds are today's values (no history; with CGR-39 open, a lowered look-ahead override such as 0 h for `visit_uncovered` would shrink measure 1's window); historical suspension and cover state are not replayed for measure 1; a visit removed from the plan has left `care_visits` and every measure (its history row stays); measure 8's flag uses today's responsible member, and the moved slot only from the first move after the recording.
**Not built:** nothing from the brief's measure list remains. The `cra` 02:26 proposals (minute distribution, planned-to-actual start) stay with the PO.
**Rollback:** re-run `public.pilot_hypotheses(date)` from 0057; drop `private.an2_capture_starts`.
**Open:** none for engineering.

### ADR-072 — ADM1-R (CGR-39): a direction per exception rule; an override is never later than the default
**Status:** PROPOSED · **Task:** ADM1 changes (issue #262, `docs/agents/briefs/ADM1.md`, PO 2026-10-24 07:10, ADM1-R1 to R6); finding CGR-39 (`cra` 2026-10-24 06:30, blocking S1); remediation plan `docs/agents/clinical/remediation/CGR-39.md`. Migration 0059, pgTAP `061_adm1_cgr39_direction_aware_range` (49), pgTAP 035 (the inverted assertions replaced, count unchanged), unit `admin-rules`, e2e `admin.spec.ts`. Amends ADR-046 (safe ranges).
**Context:** ADR-046 bounded every threshold override from 0 to the default (P1) or twice the default, as if a larger amount always meant a later signal. Five readers use the amount as a **look-ahead window** (larger = earlier signal), so the bound was inverted for them: the P1 hospital-discharge rule could be set to 0 h and never fire.
**Decision:**
- `public.exception_rules.amount_direction` ∈ {`look_ahead`, `delay`}; a check constraint makes it required exactly when the rule has an amount, so a new amount-bearing rule cannot be added without a direction. Values with the reader lines that prove them are in the migration header: look-ahead `visit_uncovered_hospital`, `visit_uncovered`, `order_expiring`, `team_cancellation_late`, `cover_without_access`; delay `case_not_ready`, `report_not_final` (also times `report_correction_open`), `visit_overdue`, `visit_stuck`.
- **Never later than the default** (until D-28 sets a clinical band): look-ahead from the default up to 4× (cap 720); delay from a floor up to the default. Floor 0 (0 means "at once" in every delay reader), except `visit_stuck` with 1 h: at 0 every visit would be "stuck" the moment it starts, so the rule would no longer mean anything. 4× and the floor are engineering bounds against floods and meaningless rules, not clinical values. Priority never lower and escalation never later: unchanged.
- One check, `private.exception_override_in_range`, used by `set_exception_rule` and by the one-time reset; `private.exception_rule_range` and `public.admin_exception_rules` return the direction and the lower bound.
- **Existing overrides** outside the new range are deleted (= back to the platform default) by `private.adm1_reset_out_of_range_overrides()`, one `audit_events` row each (`command = 'adm1_range_reset'`, old priority, amount, escalation, who set it and when; actor null = maintenance). The migration raises the count as a NOTICE. On a fresh database it is 0 (the seed has no override and runs after the migrations).
- `/admin` shows a fixed general text ("Sicherheitsausnahmen melden sich nie später als der Standard"), the range per rule ("7 bis 28") and which way is stricter ("Früher melden = mehr Tage Vorlauf" / "weniger Stunden Wartezeit"); the client check mirrors the database and names both.
- `private.effective_exception_rules` returns `setof public.exception_rules`, so it is re-created with the new column; every reader and every default keeps its result (ADM1-R6).
**Not chosen:** a table-level guard on `exception_rule_overrides` (only the security-definer commands write it; pgTAP 047 writes one directly as the owner to test a reader, and R6 forbids editing it); clamping overrides inside `effective_exception_rules` (would silently change what an organisation sees configured).
**Rollback:** re-create `exception_rule_range`, `set_exception_rule` and `admin_exception_rules` from 0035, drop `exception_override_in_range`, `adm1_reset_out_of_range_overrides`, the two constraints and the column (re-creating `effective_exception_rules` from 0035). Reset overrides are not restored (their old values are in the audit rows). Rollback would reopen CGR-39 and needs a PO decision.
**Open:** the clinical band per rule (D-28, `clinical`); team-level overrides (D-28 option C) out of scope.

### ADR-073 — COORD5: the watcher asks a person only when the decision package does
**Status:** PROPOSED · **Task:** COORD5 (issue #240, `docs/agents/briefs/COORD5.md`, PO 2026-10-24); process `docs/agents/DECISION_PACKAGES.md` (owner, 2026-10-24). Amends ADR-039 (coordination watcher). Files: `scripts/agents-coordination/parse.mjs`, `plan.mjs`, `run.mjs`, `scripts/agents-check.mjs`, `.github/workflows/agents-coordination.yml`; tests `tests/unit/agents-coordination.test.ts`, `tests/unit/agents-layer.test.ts`.
**Context:** the watcher assigned every open `owner`/`legal`/`clinical` decision to the owner on creation (29 issues). Since 2026-10-24 the agents first prepare a package; `decisions/INDEX.md` is the authoritative package state.
**Decision:**
- **Where INDEX is read (brief's open question):** in `parse.mjs`, next to the three official files, as an optional input of `readLayerTexts` (`index`, `packageFiles`). INDEX is **not** added to the official layer: it stays PO-owned under the decision-package process, and the planner stays pure (run.mjs does the file I/O). INDEX has no `## ` heading, so a heading-less first-table reader (`parseFirstTable`) is added; the status is the link text of the *Package status* cell (`[awaiting-approval: owner](D-22.md) (…)`) or its first word.
- **Routing for owners `owner`, `legal`, `clinical`:** `awaiting-approval: owner|legal|clinical` **and** a linked package file → labels `agents`, `human-decision`, assigned to `OWNER_LOGIN` (until README *Participants* names other GitHub accounts); the body links the package (GitHub blob URL on `recovery/main`) and quotes its *Owner approval required?* section (capped at 4000 characters). Every other state (`not-started`, `inputs-requested`, no INDEX row, an unknown value, a status without a linked file) → `agents`, `agent:po`, `decision-package`, nobody assigned. Fail-safe direction: when in doubt, the agents keep the item; nobody is pulled in by a malformed row (the validator turns it red instead).
- **`po-decided`/`decided` while the row is still in *Open*:** stays a `decision-package` issue and the validator warns (brief, negative criterion). The issue closes only when the row leaves *Open* (moved to *Decided*), with the existing close reason. This reconciles the two criteria "po-decided → closes" and "po-decided in Open keeps decision-package": closing waits for the record in `OPEN_DECISIONS.md`, which is what the README requires anyway.
- **Existing issues:** the diff now also compares whether the owner is assigned (decision issues only). An update removes **only** `OWNER_LOGIN` from the assignees (others stay) or adds it; `decision-package` is a managed label, so it is swapped with `human-decision` both ways; `claimed` and other unmanaged labels survive. The German comment is posted once, on the sync that moves an issue from `human-decision` (label or owner assigned) to `decision-package`; the next sync finds nothing to change.
- **`po`/`eng` decisions:** unchanged (labels `agent:po` / `agent:eng`, nobody assigned).
- **Validator:** every *Open* decision owned by `owner`/`legal`/`clinical` has an INDEX row; status in the DECISION_PACKAGES.md list; `awaiting-approval:*` and `po-decided` need `decisions/<ID>.md`; an INDEX ID must be in *Open* or *Decided*; `po-decided`/`decided` still in *Open* is a warning. `--dry-run` prints the package status per decision issue and one summary line.
- The workflow also runs on pushes to `docs/agents/decisions/**`, so a status change reaches GitHub at once, not only at the hourly reconciliation.
**Not chosen:** reading the package's front matter (`status:`) instead of INDEX (two sources of truth; DECISION_PACKAGES.md names INDEX); closing an issue as soon as INDEX says `po-decided` (the row would still be open and nobody would see the missing record).
**Rollback:** revert the PR; the next watcher run re-labels every human-owned decision `human-decision` (no data lost; the comments stay). The old diff does not compare assignees, so the owner is **not** re-assigned on existing issues by a revert; re-assign by hand if needed.
**Open:** assigning legal advisers and the Clinical Owner directly once README *Participants* names their GitHub accounts (PLANNED, needs those names, owner).
