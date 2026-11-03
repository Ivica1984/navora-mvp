# D-2 production hosting: Engineering decision support

**Owner:** Engineering (`eng`, decides HOW; **does not decide D-2**) · **Date:** 2026-11-03 15:31 Europe/Zurich · **For:** the owner (D-2 is `awaiting-approval: owner`), `po` (package), `lca` (residency and transfer questions) · **Package:** [`docs/agents/decisions/D-2.md`](../agents/decisions/D-2.md) (*Engineering impact*, production addendum of this date) · **Related:** `DELIVERY_ESTIMATE.md` §2-§3 (PR #835), ADR-011, ADR-142 (PR #835).

**Brief (owner, 2026-11-03, in a Claude session):** prepare decision support for production hosting. Preferred baseline is GitHub, Supabase and Vercel. Do not assume a platform migration. First evaluate whether the current architecture is sufficient for Pilot Readiness (M9) and Production Readiness (M10). Analyse Supabase production readiness, backup strategy, point-in-time recovery, disaster recovery, monitoring, security testing and data residency. The requirements are:
- 99.9 % availability;
- effectively zero data loss through backup and recovery controls;
- data processed and stored in Switzerland or, if that is not technically feasible, in the EU only;
- a security assessment before production readiness.

If a migration away from Supabase is needed, give the reasons, risks, costs and effort. Do not make the decision.

**Labels:** IMPLEMENTED (in this repository) · PLANNED · OPEN (needs a decision) · UNKNOWN (not established). Vendor facts are **as published by the vendor on the date read** (sources at the end, read 2026-11-03), not verified by test. Prices are list prices in USD without VAT, as published; no quote was requested. **Nothing here is legal advice.** Residency and transfer questions are framed for `lca` and the Zurich adviser (D-2 production conditions (a)-(c)).

---

## 0. Summary for the owner

| Question | Engineering answer | Confidence |
|---|---|---|
| Is a migration away from Supabase needed for M9? | **No.** Supabase in Zurich (`eu-central-2`) keeps the database, Auth and backups in Switzerland. It meets the M9 needs once a paid plan with PITR, an off-platform backup copy, outside monitoring and a restore drill are added (§2-§5). | Medium |
| Is a migration away from Supabase needed for M10? | **Not on today's evidence.** Two requirements cannot be fully met on Supabase today on any self-serve plan: (1) a **contractual** 99.9 % (Enterprise only) and (2) **zero** data loss (PITR's worst case is about 2 minutes, and Supabase's synchronous high-availability option is a private alpha, not for production). Both are owner choices: accept them, or buy Enterprise. Neither forces a migration. A migration becomes necessary only if the Zurich adviser rejects Supabase's Singapore/US support and access paths for health data (D-2 condition (a)). | Medium-Low |
| Can Vercel meet "Switzerland, else EU only"? | **Not for Switzerland.** Vercel has no Swiss compute region; the nearest is Frankfurt (`fra1`). The Swiss requirement **is** technically feasible for the app tier with another host, so on a strict reading Vercel does not meet it. Vercel also states it "may transfer data to and in the United States and anywhere else", and its own data plane and backups are globally replicated. Whether that is "EU only" is a question for `lca` and the adviser. | High (facts) / OPEN (reading) |
| Deviation found (not changed) | The **decided staging design** (po 2026-10-24, D-2 *Recommended default* item 2) uses **Render Frankfurt** for the app, not Vercel. Render has no Swiss region either. The owner's stated baseline (Vercel) differs from that decision. See §8. | High |
| Recommended options to decide between | **A** Supabase Zurich plus Vercel Frankfurt (the baseline); **B** Supabase Zurich plus the app in a Swiss region (container), Supabase unchanged; **C** Swiss-operated stack (self-hosted Supabase or Postgres), only if the adviser rejects Supabase's access paths. §7. | Medium |

---

## 1. Requirements and how they are measured

| ID | Requirement (owner) | Engineering reading (measurable) | Label |
|---|---|---|---|
| RQ-1 | Availability 99.9 % | At most about **43.8 minutes** of unplanned unavailability per month, end to end (browser → app host → database, Auth). Two serial services multiply: Vercel Enterprise 99.99 % × Supabase Enterprise 99.9 % = **99.89 %** combined, slightly below 99.9 % even on both vendors' best contract. Scheduled maintenance is excluded by both SLAs. | OPEN (owner: end to end or per service; maintenance in or out) |
| RQ-2 | Data loss effectively zero | Two parts: **RPO** (how much acknowledged data a failure can lose) and **restorability** (backups that are tested). Truly zero RPO needs synchronous replication. Backups alone give an RPO of minutes. | OPEN (owner: is RPO ≤ 2 minutes "effectively zero"?) |
| RQ-3 | CH, else EU only | Per component: where data are **stored**, where they are **processed** (compute, logs, support access), and which **legal entity** can reach them. Today's facts in §6. | OPEN (`lca`, adviser) |
| RQ-4 | Security assessment before M10 | An external test of the app, RLS, Server Actions, push dispatch and the deploy path, with no open high finding (M10 criterion). Supabase permits customer tests (§5). | PLANNED |

---

## 2. Supabase production readiness

| Topic | Fact (vendor, read 2026-11-03) | What it means for NAVORA | Label |
|---|---|---|---|
| Region | Specific region **Central Europe (Zurich) `eu-central-2`** is offered; no plan restriction stated. "General" regions (e.g. "Europe") let Supabase pick the AWS region. | Production uses `eu-central-2` explicitly, never the general region (as decided for staging). | IMPLEMENTED (vendor) |
| Uptime SLA | **99.9 % per product, Enterprise only** (Order Form). Team has **support** SLAs only, no uptime commitment. Credits 10-30 %, capped at 20 % of 12 months' fees. Scheduled maintenance excluded. | On Pro or Team, 99.9 % is a target NAVORA measures, not a contract. A contractual 99.9 % means Enterprise (price UNKNOWN, sales). | OPEN (owner) |
| High availability | No generally available standby or failover for a project. **Multigres** (cluster with automatic failover in seconds, cross-AZ, durable writes) is **private alpha**: not under the SLA, not for production, **no PITR**, chosen at project creation only (Supabase changelog 2026-10-06). | Production is a **single Postgres instance**. An instance failure means downtime until Supabase restores it (duration UNKNOWN). Multigres is not usable for M9 or M10 as published today; worth re-checking at M10. | IMPLEMENTED (vendor) / UNKNOWN (failover time) |
| Compliance | SOC 2 Type 2, ISO 27001, HIPAA (BAA). Reports and certificate downloadable on **Team and Enterprise**. AES-256 at rest, TLS in transit. | The DPIA (G-4) and the partner's sub-processor approval (D-2 (c)) need the SOC 2 report and the ISO certificate, which means **Team** at least. HIPAA is US law and not a Swiss basis. | IMPLEMENTED (vendor) |
| Contracting entity | Supabase DPA v1 (2026-08-01): **Supabase Pte. Ltd (Singapore)**, SCCs with Swiss addendum (`lca` [H4] in D-2). Support, account and usage data processed outside the region; transfers to Singapore and the US under SCCs (`lca` [H3]). | The open legal question of the D-2 package (adviser questions 1-3). Engineering cannot remove it technically: support access is a vendor path. | OPEN (`lca`, adviser) |
| Plan features NAVORA uses | pg_cron (SIG1 every minute, PLAN2, COVER1), pg_net and Vault (push dispatch kick, 0064), Auth, PostgREST `rpc()`; no Supabase Storage objects (no `storage.from` in `src/`). | All available on paid plans. Because NAVORA uses **no Storage objects**, database backups cover all NAVORA data. Supabase backups exclude Storage objects. | IMPLEMENTED (repository) |
| Logs | Retention: Pro 7 days, Team 28 days, Enterprise 90 days. Log drains on Pro, Team, Enterprise (HTTP, OTLP, S3, Datadog, Grafana Loki, Sentry and others; priced separately). | Drains let logs go to a CH/EU-hosted store the owner chooses (§4). | IMPLEMENTED (vendor) |

**Engineering assessment:** Supabase in Zurich is **technically sufficient for M9** on **Team** (or Pro with PITR, see costs §9), provided §3-§5 are added. For **M10** it is sufficient if the owner accepts a measured rather than contractual 99.9 % and an RPO of about 2 minutes, or buys Enterprise for the contractual SLA. Zero RPO is not available on Supabase today (§3.2).

---

## 3. Backup strategy, point-in-time recovery and disaster recovery

### 3.1 What Supabase provides (vendor, read 2026-11-03)

| Control | Fact | Label |
|---|---|---|
| Daily backups | Pro 7 days, Team 14 days, Enterprise up to 30 days. Physical backups on current Postgres versions; they cannot be downloaded directly. Custom-role passwords are not in them. | IMPLEMENTED (vendor) |
| PITR | Add-on on paid plans, **requires at least the Small compute add-on**. Daily physical snapshot plus WAL, WAL archived **every 2 minutes** (sooner when files are large): **worst-case RPO about 2 minutes**. Restore to any second. Retention 7, 14 or 28 days: about $100, $200 or $400 per month. Enabling PITR **replaces** daily backups. | IMPLEMENTED (vendor) |
| Restore in place | Overwrites the project. **The project is unavailable during the restore**; the duration grows with database size. | IMPLEMENTED (vendor) |
| Restore to a new project | From a physical backup or a PITR point. **Same region only** ("the data will remain in the same region as the source project"). Copies the schema, data, roles, Auth users and the Vault root key. Does **not** copy Auth settings, API keys, Edge Functions, extension settings or read replicas. | IMPLEMENTED (vendor) |
| Cross-region restore | Not offered (open community request since 2025-02-10, unanswered). | IMPLEMENTED (vendor, absent) |
| Backup location | "Stored in S3"; the residency FAQ says backups are in the chosen region (`lca` [H3]). | UNKNOWN beyond the FAQ |

### 3.2 Against RQ-2 (data loss effectively zero)

- **Ordinary failures** (instance restart, process crash): committed transactions are on durable storage. Whether Supabase's volume layout loses nothing in every such case is **UNKNOWN**: the vendor does not state it.
- **Storage or instance loss:** up to about **2 minutes** of committed data (WAL interval). NAVORA's design reduces the harm but does not remove it:
  - every write is an idempotent command with its key and audit in one transaction (ADR-003);
  - the planned caregiver command queue (ADR-142, PR #835) keeps a value on the phone until the server confirms it.

  A value the server confirmed in the last two minutes before a storage loss is still lost, and the nurse believes it is saved.
- **Truly zero RPO** needs synchronous replication to a second node. On Supabase that is Multigres (private alpha, no PITR, not for production). Outside Supabase it is, for example, a managed Postgres with a synchronous standby. That would be a database migration (§7, option C).
- **Engineering proposal (OPEN for the owner):** accept **RPO ≤ 2 minutes** for M9 and M10, with the compensating controls in §3.3. Re-check Multigres or an Enterprise HA offer before M10. If the owner reads "effectively zero" as RPO = 0, no Supabase plan meets it today, and §7 option C applies.

### 3.3 Proposed backup and DR design (PLANNED; nothing built)

| Layer | Control | Protects against | Label |
|---|---|---|---|
| L1 | **PITR, 28 days**, production only | operator error, bad migration, corruption: restore to the second before | PLANNED |
| L2 | **Off-platform logical backup:** a nightly `pg_dump` (all schemas including `auth`, plus roles), encrypted with a key the owner holds, written to **object storage in Switzerland with a provider other than Supabase/AWS** (provider OPEN). Run by a scheduled CI job or a small job in CH. The dump credential is a read-only role. | loss of the Supabase account, vendor failure, the same-region restore limit, a Zurich region outage | PLANNED (provider OPEN) |
| L3 | **Restore drills:** monthly PITR restore to a new project (same region), and quarterly restore of an L2 dump into an empty project or a plain Postgres. Each drill runs pgTAP and row counts and records the duration (M9 criterion: one drill within 30 days). | backups that do not restore; an unknown RTO | PLANNED |
| L4 | **Rebuild from code:** migrations and the seed recreate the schema and jobs from CI in one run (IMPLEMENTED for CI). Production config that is not in migrations (Auth settings, API keys, Vault entries, cron check, SMTP) goes in a checklist in the restore runbook, because a restore to a new project does not copy it. | a lost project configuration | IMPLEMENTED (schema) / PLANNED (checklist) |
| L5 | **DR runbook:** declare the incident, freeze writes (maintenance page), restore (L1 or L2), apply the L4 checklist, verify (pgTAP, counts, `signal_evaluator_health`), switch the app's environment, reconcile the queued client commands (idempotency keys make the resend safe). | a disorderly recovery | PLANNED |

**DR targets (UNKNOWN until the first drill, so no number is promised here):** for NAVORA's current size the restore duration is expected to be minutes to an hour. RTO and RPO are owner values (R-3 in `DELIVERY_ESTIMATE.md`). **Residency question for `lca` (OPEN):** after a Zurich-region outage, can the L2 dump be restored into a Frankfurt project as an emergency measure? If not, DR waits for Zurich or for a Swiss host.

**Data-minimisation interaction (from D-2 item 7):** PITR and L2 keep corrected or deleted values (e.g. a corrected `cases.access_notes`) for the retention period. Longer retention means more recovery and longer survival of corrected data. **OPEN for `lca`/owner:** the retention to state in the DPIA and the information texts (28 days PITR, L2 period).

---

## 4. Monitoring

| What | Proposal | Data residency note | Label |
|---|---|---|---|
| P1 signal path | External check on `signal_evaluator_health` (evaluator liveness, IMPLEMENTED in-app since 0064). It alerts on a **missing heartbeat**, not only on errors. Engineering proposes it **before M9** (`DELIVERY_ESTIMATE.md` P-5). | the check reads a boolean and a time, no health data | PLANNED |
| Availability (RQ-1) | Uptime checks every minute on the app and on a minimal database-backed endpoint, from at least two locations; monthly availability report against 99.9 % | no health data | PLANNED |
| Errors | Error tracking for server and browser, with **health data scrubbed** and tested (no request bodies, no free text, IDs only) | the tool is a processor: CH/EU-hosted, `lca` reads it before real data | PLANNED (tool OPEN) |
| Logs | Supabase log drain and Vercel (or Swiss host) logs to a CH/EU store; retention set with `lca` | Supabase keeps logs 28 days (Team) in its own store | PLANNED |
| Jobs | pg_cron job freshness for PLAN2 and COVER1 (a heartbeat like SIG1's) | none | PLANNED |
| Backups | alert when the L2 dump is missing or smaller than expected; drill results in the runbook record | none | PLANNED |

Effort: 4-6 pd (`DELIVERY_ESTIMATE.md` R-1) plus 2-3 pd for P-5.

---

## 5. Security testing

| Layer | Today | Before M10 | Label |
|---|---|---|---|
| CI | pgTAP RLS and grant tests on every PR, anon REST probes on 22 tables and 48 RPCs, `npm audit` (high and critical), CSP and headers, generated-types drift check | unchanged | IMPLEMENTED |
| Repository | branch protection, required checks and secret scanning are **off** (SR-14) | D-7 (owner) before production deploys | OPEN (owner) |
| Staging DAST | none | automated scan of staging (e.g. OWASP ZAP baseline) in CI, synthetic data only | PLANNED |
| External test | none | external tester, scope: app, RLS, Server Actions, `/api/push/dispatch`, Auth, deploy path. **Supabase permits customer tests of one's own project without prior approval**. It excludes DoS, request flooding and cross-tenant tests, and a vulnerability found in a Supabase product must be reported to Supabase within 24 hours. Vercel's customer-test policy: UNKNOWN (not read). | PLANNED (tester: owner) |
| Vendor incident lesson | Vercel's **April 2026 security incident** (Vercel bulletin, closed 2026-10-16): an attacker came in through a third-party AI tool used by a Vercel employee and decrypted customers' **non-sensitive** environment variables. Vercel advises marking secrets "sensitive" and rotating them. | On Vercel: every secret stored as a sensitive variable. `SUPABASE_SERVICE_ROLE_KEY` (used by `src/features/push/dispatch.ts`) is the most powerful secret on the app host; Engineering proposes a dispatch-only database role instead of the service-role key before production (PLANNED, small). Agent connectors hold no production credential (G-22). | PLANNED |

---

## 6. Data residency (facts for `lca`; no legal reading)

| Component | Stored | Processed | Legal entity / access paths | Meets "CH, else EU only"? (Engineering view, for `lca`) |
|---|---|---|---|---|
| Supabase DB, Auth, backups | Zurich (`eu-central-2`) | Zurich | Supabase Pte. Ltd (Singapore); support, account and usage data outside the region; SCCs to Singapore and the US (`lca` [H3], [H4]) | storage and processing in CH; **access paths outside CH/EU**: OPEN (adviser questions 1-3) |
| Vercel (app: Server Actions, rendered pages with health data in transit) | no customer database; logs and metadata: Vercel's "core database and data plane is a globally replicated database"; Vercel's own backups "globally replicated" | the chosen function region, **nearest `fra1` Frankfurt**; default is `iad1` (US) and must be overridden; requests enter at the nearest PoP | Vercel Inc. (US), EU-U.S. DPF certified (Swiss extension: `lca` UNKNOWN in D-2); "may transfer data to and in the United States and anywhere else in the world" | **not CH** (no Swiss region, and CH **is** feasible with another host); EU for compute, **not EU-only** for logs and metadata on the vendor's own statement |
| Render (decided staging host) | as Vercel: no customer database | Frankfurt (regions: Oregon, Ohio, Virginia, Frankfurt, Singapore; **no Swiss region**) | Render (US), DPF incl. Swiss-U.S. per vendor (`lca` [H6]) | not CH; EU compute |
| Swiss-region app host (option B) | as chosen | Zurich (e.g. AWS `eu-central-2`, where ECS, Lambda and CloudFront are listed by a secondary source, to verify; or a Swiss-owned provider) | AWS (US company), or a Swiss company | CH processing; entity question as for Supabase if AWS |
| GitHub | code and CI logs only; CI uses synthetic data (IMPLEMENTED) | US/global | GitHub (US) | no health data: out of scope if the synthetic-only rule holds |
| Auth e-mail (password reset, invites) | — | the SMTP provider | Supabase's built-in SMTP is not for production; a custom SMTP is needed | provider OPEN: choose CH/EU |
| Web push | — | browser vendors' push services (Apple, Google, Mozilla) | as D-32/D-33 | already decided for P1 (D-33); OPEN for the rest |

---

## 7. Options (decision support; Engineering does not choose)

| | **A: baseline** | **B: baseline database, Swiss app host** | **C: Swiss-operated stack** |
|---|---|---|---|
| Database | Supabase Team (or Enterprise), Zurich, PITR 28 d | same as A | self-hosted Supabase (open source) or managed Postgres at a Swiss provider |
| App | Vercel Pro (or Enterprise), `fra1` | Next.js in a container in a Swiss region (`output: 'standalone'`), behind a load balancer and CDN in CH | as B |
| RQ-1 99.9 % | measured; contractual only with Enterprise on both (combined 99.89 %) | measured; app-host SLA depends on the provider | measured; NAVORA or its operator carries HA and on-call |
| RQ-2 zero loss | RPO ≈ 2 min; L1-L5 | as A | RPO 0 possible with a synchronous standby, **if** the provider offers it or NAVORA runs it |
| RQ-3 residency | DB in CH; app compute EU; Vercel logs and metadata global | DB and app in CH; vendor access paths remain (Supabase; AWS if used) | CH; a Swiss legal entity if the provider is Swiss-owned |
| Code change | none (env config, `vercel.json` region) | small: Dockerfile, health endpoint, deploy workflow; no app logic | large if plain Postgres (Auth, PostgREST, CLI); medium if self-hosted Supabase |
| Engineering effort | in T12 plus P-2 (5-8 + 3-5 pd, `DELIVERY_ESTIMATE.md`) | A plus **8-12 pd** (container, CDN/TLS, deploy, scaling, runbook); ops **1-2 pd per month** | **self-hosted Supabase: 25-45 pd** plus ops **2-4 pd per month** (HA, upgrades, patches, backups, on-call); **plain Postgres with own Auth: 60-100 pd** (395 `auth.uid()` uses in migrations, 153 `.rpc()` calls, `auth.users` in 15 places, pg_cron, pg_net, Vault, Supabase CLI in CI) |
| Main risk | Vercel residency reading; no contractual 99.9 % below Enterprise | more operations than Vercel; app-host maturity | operations maturity: NAVORA becomes its own database operator; slower delivery during the migration |
| Confidence | Medium | Medium-Low | Low |

**Engineering view (not a decision):**
- **Migration away from Supabase is not technically necessary** for M9 or M10. The architecture (Postgres, RLS, definer commands, pg_cron) is sound on Supabase Zurich.
- The **app tier** is the only part where the Swiss requirement and the baseline conflict. Option B resolves it without touching the database or the code, at the cost of operating a container.
- Option C is prepared only if the adviser rejects Supabase's access paths. That is the PO's existing default (D-2 addendum 2026-10-27 12:05): "not built speculatively".

---

## 8. Deviation (documented, not changed)

- **What:** the owner's brief names **Vercel** as the preferred baseline. The D-2 package's decided staging design (po 2026-10-24 17:10, *Recommended default* item 2) chose **Render Frankfurt**, "Vercel is not chosen while its Swiss-U.S. DPF coverage is not shown (`lca` note 2); it can replace Render later by a new decision".
- **Likely cause:** the owner's brief restates the target stack. The staging host choice is a later PO design decision the brief does not mention.
- **Answer to the PO's open request of 2026-10-27:** Render offers **no Swiss region** (regions page read 2026-11-03).
- **Engineering impact of either:** none on code. Both run the same Next.js build; only the deploy workflow differs.
- **Proposal (OPEN for `po`/owner):** decide the app host once for staging and production, with the §6 facts, so staging proves the production path.

---

## 9. Costs (list prices read 2026-11-03, USD, excl. VAT; usage on top; no quotes)

| Item | Option A, pilot production | Notes |
|---|---|---|
| Supabase Team | $599 / month | includes $10 compute credit; SOC 2, ISO, 14-day backups, 28-day logs, support SLA |
| Compute Small (needed for PITR) | $15 / month, minus $10 credit = $5 | Medium $60 if load needs it (UNKNOWN until staging) |
| PITR 28 days | about $400 / month ($0.55/h) | 7 days ≈ $100 |
| Supabase staging (Pro, no PITR) | $25 / month | Micro covered by the credit |
| Vercel Pro | $20 platform fee (1 seat, $20 credit) plus $20 per extra deploying seat | Password Protection $20 per protected project (staging); SAML SSO $300 per month optional |
| Off-platform backup (L2) and monitoring tools | UNKNOWN | expected small; depend on the providers chosen |
| **Total, order of magnitude** | **about $1,050-1,150 per month** plus usage | Enterprise (Supabase and/or Vercel) for contractual SLAs: price UNKNOWN (sales) |
| Cheaper variant | Supabase **Pro** plus Small plus PITR 28 d ≈ $430 per month | loses the SOC 2/ISO documents (needed for the DPIA and the partner's approval), the support SLA and 14-day backups: Engineering does not recommend it for health data |
| Option B delta | app container in a Swiss region: UNKNOWN (provider not chosen) | plus 8-12 pd setup, 1-2 pd per month ops |
| Option C | provider costs UNKNOWN | plus 25-100 pd and ongoing ops (§7) |

---

## 10. Questions for the owner (Engineering does not answer them)

1. **RQ-1:** is 99.9 % an end-to-end target that NAVORA measures, or a contractual commitment? (Contractual → Enterprise on Supabase and the app host; combined 99.89 %.)
2. **RQ-2:** is RPO ≤ 2 minutes with tested restores (L1-L5) "effectively zero"? If RPO must be 0, no Supabase plan meets it today (§3.2).
3. **RQ-3, with `lca`:** is Vercel (app compute in Frankfurt, global logs and metadata) acceptable, given Swiss app hosting is technically feasible (option B)? And is an emergency restore into an EU region acceptable for DR (§3.3)?
4. **App host:** Vercel or Render (§8), decided once for staging and production.
5. **Providers:** the Swiss object storage for L2, the monitoring and error-tracking tools, and the SMTP provider (each a processor for `lca`).
6. **Security test:** the tester and the date (before M10; Engineering recommends before the first real client).

## 11. What Engineering does after the decision (PLANNED)

T12 and P-2 as in `DELIVERY_ESTIMATE.md`, plus L2 (2-3 pd), L3/L5 runbooks (in P-3/P-4), the outside monitors (§4) and the dispatch-only role replacing the service-role key on the app host (1-2 pd, ADR to follow).

## 12. Owner planning baseline (2026-11-03, Engineering Directive Response)

The owner set a **planning baseline**. D-2 itself stays `awaiting-approval: owner`, and this section changes no package or decision. Engineering plans T12, P-2 and the M9 runbooks on it. It is read item by item against §1-§9; **no material technical blocker** is found, but there are three gaps the baseline does not close.

| Baseline item (owner) | Engineering reading | What it means for the plan | Label |
|---|---|---|---|
| Source control: GitHub | as today | D-7/D-8 (branch protection, merge to `main`) still needed before production deploys | IMPLEMENTED / OPEN (D-7, D-8) |
| Application backend: Supabase | Supabase in Zurich `eu-central-2` (§2), Team plan for the SOC 2 and ISO documents | no migration; production and staging projects created explicitly in `eu-central-2` | PLANNED |
| **Website hosting: Vercel** | Vercel is named for the **website**. The website holds no health data (ADR-142), so the CH/EU rule does not bind it. Region `fra1`; no cookies or analytics. | fits WEB1 (`WEB1_IMPLEMENTATION_PLAN.md`); no conflict with RQ-3 | PLANNED |
| *(not named)* **care-app hosting** | the baseline does not name the host of the care app (Next.js server: Server Actions, rendered pages with health data in transit). Staging was decided on Render Frankfurt (§8). | **Gap 1, OPEN (owner):** app host for staging and production. Engineering plans with option A (Vercel `fra1` for the app too) **only if** the owner extends "Vercel" to the app and `lca` accepts §6. Otherwise it plans option B (Swiss region container, +8-12 pd). Until then T12 proceeds on Render Frankfurt staging, as decided. | OPEN |
| Availability target 99.9 % | measured end to end (§1 RQ-1) unless the owner buys Enterprise for a contractual SLA | outside monitors and a monthly availability report (§4) are planned for M9 | PLANNED / OPEN (contractual or measured) |
| Point-in-Time Recovery required | PITR 28 days on production (§3 L1); requires the Small compute add-on; replaces daily backups | in T12; plus the L2 off-platform dump and L3 drills (M9 needs one restore drill within 30 days) | PLANNED |
| Health and care data in CH or EU | DB, Auth and backups in Zurich; app compute per gap 1; Supabase support and access paths outside CH/EU stay an `lca`/adviser question (§6) | **Gap 2, OPEN (`lca`, adviser):** vendor access paths; DR restore into an EU region | OPEN |
| Website and care platform separated | ADR-142 (accepted): separate origin, no Supabase key or import in the website (CI check), demo requests to the owner-chosen destination, never the care database | in WEB1 | PLANNED |

**Gap 3, OPEN (owner):** "effectively zero data loss" against PITR's RPO of about 2 minutes (§3.2, question 2 of §10). The baseline asks for PITR, which Engineering reads as accepting RPO ≤ 2 minutes with tested restores. The owner confirms or corrects that reading.

## Sources (read 2026-11-03)

- Supabase, Database Backups: https://supabase.com/docs/guides/platform/backups
- Supabase, Manage Point-in-Time Recovery usage: https://supabase.com/docs/guides/platform/manage-your-usage/point-in-time-recovery
- Supabase, Restore to a new project: https://supabase.com/docs/guides/platform/clone-project
- Supabase, Available regions: https://supabase.com/docs/guides/platform/regions
- Supabase, Service Level Agreement: https://supabase.com/docs/company/sla and https://supabase.com/docs/guides/platform/sla
- Supabase, Pricing: https://supabase.com/pricing
- Supabase, Security: https://supabase.com/security
- Supabase, Security testing of your project: https://supabase.com/docs/guides/security/security-testing
- Supabase, Log Drains: https://supabase.com/docs/guides/telemetry/log-drains
- Supabase, Multigres: https://supabase.com/docs/guides/database/multigres and changelog discussion https://github.com/orgs/supabase/discussions/51363 (2026-10-06)
- Supabase community request, cross-region restore: https://github.com/orgs/supabase/discussions/33483 (unanswered)
- Vercel, Global network and regions (updated 2026-08-11): https://vercel.com/docs/regions
- Vercel, Security & Compliance Measures (updated 2026-09-08): https://vercel.com/docs/security/compliance
- Vercel, Enterprise SLA (updated 2024-07-18): https://vercel.com/legal/sla
- Vercel, Pro plan (updated 2026-09-15): https://vercel.com/docs/plans/pro
- Vercel, April 2026 security incident bulletin: https://examples.vercel.com/kb/bulletin/vercel-april-2026-security-incident (Vercel-hosted copy of the bulletin)
- Render, Regions: https://render.com/docs/regions
- AWS `eu-central-2` service list (secondary, to verify on AWS's own list): https://awsfundamentals.com/regions/eu-central-2
- Earlier `lca` sources [H1]-[H8] in `docs/agents/decisions/D-2.md` (Supabase residency FAQ and DPA, Vercel, Render DPF, BJ adequacy list).

## Change log
- 2026-11-03 15:31 eng: version 1 (owner brief "D-2 Hosting Decision Package").
- 2026-11-03 eng: §12 owner planning baseline (Engineering Directive Response) read against the assessment; gaps 1-3 OPEN.
