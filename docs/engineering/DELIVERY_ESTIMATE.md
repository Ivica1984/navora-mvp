# NAVORA delivery estimate (M1 baseline)

**Owner:** Engineering (`eng`, decides HOW and HOW LONG) · **Date:** 2026-11-03 15:14 Europe/Zurich · **Issue:** #830 · **Basis:** `docs/product/DELIVERY_PROGRAM.md` v1 (PO, #832), `recovery/main` at `2981ad5`, `docs/engineering/IMPLEMENTATION_SEQUENCE.md` v1 (PR #833, open), ADR-142 (this PR).

**Status:** version 1, ahead of the due date (Fri 2026-11-13). The PO decides WHAT and WHEN; every date below is an Engineering estimate, not a commitment, and changes nothing in the PO order. The PO publishes plan version 2 on Tue 2026-11-17 and may ask for a version 2 of this file before that.

**Labels:** IMPLEMENTED (on `recovery/main`) · IN REVIEW (open PR) · PLANNED · OPEN (needs a decision or a brief) · UNKNOWN (not established).

**Binding for every item:** synthetic data only (D-1, owner rule 2026-10-29); D-35 A (rule agents only); D-34; D-39 and D-40 frozen; no AI path writes billing or signal priority (#824, ADR-141, IN REVIEW #828); every care-touching item passes the `cra` gate; every migration has RLS, column grants, an audit trigger, idempotent commands and pgTAP; the live Supabase project `jwmfxrmougneeceldhsa` is never touched.

**How this file was made:** read in the repository (files named per row). Nothing was built, deployed or tested for it. No price, contract term, legal rule or clinical rule is stated here; where one is needed it is marked OPEN with its owner.

---

## Where each issue item is answered

| #830 item | Answer | Label |
|---|---|---|
| 1. Implementation sequence M2-M10 | M2-M8: `IMPLEMENTATION_SEQUENCE.md` §1-§7 (PR #833). M9-M10: §2 and §3 below | IN REVIEW (#833) / this PR |
| 2. Effort estimate | M2-M8: `IMPLEMENTATION_SEQUENCE.md` §8 (PR #833). M9-M10 items: §4 below | IN REVIEW (#833) / this PR |
| 3. Pilot readiness estimate | §2 | this PR |
| 4. Production readiness estimate | §3 | this PR |
| 5. App delivery form | §5 and ADR-142 | this PR (PROPOSED) |
| 6. Website approach | §6 and ADR-142 | this PR (PROPOSED) |

---

## 1. Facts this estimate rests on (verified in the repository 2026-11-03)

| Fact | Where | Label |
|---|---|---|
| CI starts a **local** Supabase per run, applies all migrations and the synthetic seed, runs pgTAP, vitest, Playwright and the screenshot job. No workflow deploys anywhere; no deploy secret exists in the workflows. | `.github/workflows/ci.yml`, D-2 *Engineering impact* | IMPLEMENTED |
| No staging, no production for this repository. T12 is blocked by D-2. | `BACKLOG.md` T12, D-2 package | OPEN (D-2) |
| Hosted jobs that only a hosted clock proves: SIG1 evaluator every minute (`navora-sig1-signals`), PLAN2 daily job, COVER1 events job; all scheduled idempotently where pg_cron exists. | migrations 0025, 0029, 0060, 0064 | IMPLEMENTED in code, unverified on a host |
| The evaluator's liveness is recorded (`private.signal_scheduler_runs`) and shown in the app ("Signalprüfung läuft nicht" on `/operations` and `/admin`) while someone looks. Nothing alerts a person **outside** the app when it stops. | 0064 (SIG2-11) | IMPLEMENTED (in-app) / PLANNED (outside alert) |
| Supply-chain audit in CI (`npm audit --omit=dev --audit-level=high`), anon REST probes on 22 tables, CSP and security headers (T11). | `ci.yml`, ADR T11 | IMPLEMENTED |
| No error tracking, uptime monitor or log drain is configured. | `package.json`, repository | IMPLEMENTED fact (absent) |
| No backup or restore procedure exists for a NAVORA-owned database. The only backup file is the 2026-10-21 live containment script. | `docs/ops/live/2026-10-21_backup_and_rollback.sql` | OPEN |
| Runbooks: `OWNER_RUNBOOK.md` holds owner steps, including §5a (signal evaluator and push dispatch in a pilot or staging project) and §5c (legacy nurse name reconciliation, RLS4-C1). There is no incident, deploy/rollback or restore runbook. | `OWNER_RUNBOOK.md` | IMPLEMENTED (§5a, §5c) / PLANNED (rest) |
| Branch protection, required checks and secret scanning are off; `recovery/main` is not merged into `main`. | `SECURITY_RISKS.md` SR-14, D-7, D-8 | OPEN (owner) |
| P1 safety signals stay in-app only for Safari (macOS, iOS, iPadOS) and Firefox until reassessed before the first real client. | D-33 (owner, 2026-10-26), G-20 | IMPLEMENTED (SIG2-1 allow-list) |
| `public/sw.js` handles push. No web manifest, no offline shell, no command queue. | `public/` | IMPLEMENTED (push only) |
| The app's session cookies are set by `@supabase/ssr` with the library's options; no code in `src/lib/supabase/` sets a cookie `Domain`. | `src/lib/supabase/proxy.ts` | IMPLEMENTED |

**Deviation found (documented, not changed):** the go-live gate index in `docs/product/CARE_OPERATING_MODEL.md` (*Go-live gates: one list*) still shows **G-11** (DOOR1-12 to -14), **G-13** (LEAVE1-C2 to -C4) and **G-15** (FUP1-C1/C2 part) as PLANNED, while `IMPLEMENTATION_STATUS.md` records COND1 (COND1-1 = LEAVE1-C2/-C3/-C4, COND1-2 = DOOR1-12/-13/-14, COND1-4 = FUP1-C1/-C2) as **delivered** (all COND1 conditions merged, e.g. #479). Likely cause: the gate index is updated at PO acceptance and was not revisited after COND1. The index is PO-owned, so Engineering does not edit it. **Proposal (OPEN for `po`):** check each gate row against its condition's status when building the M9 readiness file. This estimate counts those Engineering parts as built.

---

## 2. Pilot readiness (M9): earliest technical date

### 2.1 What Engineering owns for M9

| # | Work | What "done" means | Depends on | Label |
|---|---|---|---|---|
| P-1 | **T12 staging** | Supabase project in the D-2 region; protected app host; a deploy workflow on push to `recovery/main` after green CI (`supabase db push`, then the synthetic seed); staging-only users; VAPID and dispatch secrets in Vault; hosted pg_cron jobs shown running (SIG1 every minute, PLAN2, COVER1); hosted database time zone checked (ADR-068 addendum); DST1-C5 check in the workflow | D-2; owner creates projects, tokens and secrets (agents create no account and hold no secret) | OPEN (D-2) |
| P-2 | **Production stack** | Same stack and regions as staging, separate projects (ADR-011); deploys from `main` only, behind a manual approval environment; no seed; paid plan with daily backups and point-in-time recovery; empty until the owner's go | D-2 (production part), D-7/D-8, D-12 (contracting party), G-4 (hosting and DPIA) | OPEN (owner) |
| P-3 | **Restore test** | A production backup restored into a scratch project; schema, row counts per table and pgTAP run on it; the duration recorded; record filed. M9 needs one within the last 30 days, so it is repeated monthly | P-2 | PLANNED |
| P-4 | **Runbooks** | incident (P1 signal path down, deploy failed, suspected data incident → `lca`/owner), deploy and rollback, restore, access end of a leaver; D-1 reconciliation §5c exists | P-1 for the commands; owner for names and phone numbers (not in the repository) | PLANNED (§5c IMPLEMENTED) |
| P-5 | **P1 signal path monitored outside the app** | an external check reads `signal_evaluator_health` (or an equivalent minimal endpoint) and alerts a named person when the evaluator is not live; M10 lists it, Engineering proposes it **before M9** because a dead evaluator is invisible when nobody has the app open | P-1; the alert recipient is the owner's choice | PLANNED (OPEN for `po`: move into M9) |
| P-6 | **Engineering-built gate items** | G-17: DST1-C4 (repeated-hour correction asks which 02:xx) and DST1-C5 (test clock never reaches a shared database, in P-1); G-25 (b): VIS2-C3 after the feasibility answer on #65; G-25 (c): UX2-29 amendment (IN REVIEW #800); ASM1-C6 (IN REVIEW #815); RLS4-C3 (IN REVIEW #813, before G-19); AUD1-M1 (G-7) checked against COND1-6 | PO order | PLANNED / IN REVIEW |
| P-7 | **G-22 environment statement** | for staging and production: deploy credentials exist only as GitHub environment secrets and in the hosts; no agent session, connector or coding assistant holds one; a CI check fails if a workflow other than the deploy workflow references them. The owner removes or confirms the agent connectors (today Supabase and Render connectors are listed in agent sessions) | owner (connectors), `po` (statement) | OPEN |
| P-8 | **Synthetic pilot day** (M9 criterion) | the pilot team runs one full day on staging with the synthetic seed; Engineering prepares the day's data and a reset script | P-1, training (`po`, `uxa`) | PLANNED |

M9 also needs the PO's technical items already in the program (M2; M6 core) and the owner, clinical and legal gates (G-1 to G-6, G-8, …). Those are not Engineering's to estimate; their dates are UNKNOWN.

### 2.2 Assumptions about the M3 owner decisions

| Decision | Assumed for the estimate | If it is later |
|---|---|---|
| **D-2** hosting (staging, and production on the same stack) | answered by M3, Fri 2026-12-11, with production on the same stack as the PO recommends in the D-2 row; the owner creates the projects and secrets within 2 working days | P-1 and everything after it move by the same number of days |
| **D-7 / D-8** branch protection; merge `recovery/main` into `main` | answered by M3; the O-C verify script (SR-19) is run before the merge | production cannot deploy from a protected `main`; P-2 waits; staging is not affected |
| **D-1** live database | answered by M3; the live project stays untouched by every NAVORA migration until then, and NAVORA's production is a **new** project, not the live one | no effect on staging; production with real data waits (G-2) |
| D-12, G-4 (contracting party, DPIA) | decided before the production plan is bought | P-2 waits; staging is not affected |

### 2.3 Earliest technical M9 date

| Step | Working days (Engineering) | Earliest end (assumptions §2.2) | Confidence |
|---|---|---|---|
| P-1 T12 staging | 5-8 after the projects and secrets exist | 2026-12-23 | Low |
| P-4 runbooks (drafted against staging) | 3-4, in parallel with P-1 | 2026-12-23 | Medium |
| P-5 outside alert for the P1 path | 2-3 after P-1 | 2027-01-06 | Medium |
| P-2 production stack | 3-5 after D-2 (production), D-8 and the plan purchase | 2027-01-12 | Low |
| P-3 first restore test | 2-3 after P-2 | 2027-01-15 | Medium |
| P-6, P-7 gate items | 6-10 build runs in total, in the PO order, parallel to P-1 | before 2027-01-15 | Medium |

**Earliest technical M9: Fri 2027-01-15** (Low confidence), matching `IMPLEMENTATION_SEQUENCE.md` §7.3. **Planning value: Fri 2027-01-29**, two weeks of buffer for the holidays (24 Dec to 2 Jan: owner actions and reviews assumed slower) and for the first hosted run of the pg_cron jobs, which has never happened. The program's M9 (Fri 2027-03-12) also needs M4 and M8; on that path Engineering's last item ends with M8 (about 2027-02-19), still before M9.

**Engineering is not the critical path for M9.** The binding limits are D-2 (each week of delay moves P-1 to P-3 by a week), the production purchase, and the owner and clinical gates whose dates are UNKNOWN.

---

## 3. Production readiness (M10): earliest date for the technical criteria

| # | M10 criterion | Engineering part | Owner part | Effort (pd) | Earliest | Label |
|---|---|---|---|---|---|---|
| R-1 | **Monitoring and alerting** | error tracking for the app (server and browser, no health data in events: scrubbing tested), uptime checks on staging and production, P-5 extended to PLAN2 and COVER1 jobs, deploy notifications | choice of tool (a processor: `lca` reads it before real data), alert recipients | 4-6 | 2027-02-05 | PLANNED |
| R-2 | **On-call** | runbooks (P-4), alert routing, a rota template; Engineering agents are not an on-call service and hold no production access (G-22) | who is on call and when (provider staffing, like G-15) | 1-2 | with R-1 | OPEN (owner) |
| R-3 | **Backups and restore within the agreed time** | P-3 repeated monthly; restore duration measured and reported against the target | the restore time and acceptable data loss (RTO, RPO) are a service promise: owner, with the provider | 1 per test | first value 2027-01-15 | OPEN (targets) |
| R-4 | **External security test, no open high finding** | scope document (app, RLS, Server Actions, push dispatch, deploy path), a test account set on staging with synthetic data, fix window | choice and contract of the tester (financial) | 2 (scope) + 5-10 (fixes, UNKNOWN until the report) | about 2027-03-31 if the tester is engaged by mid-January; tester lead time UNKNOWN | OPEN (owner) |
| R-5 | **SLA** | proposes measurable service indicators from what the system already records (app availability from R-1, evaluator liveness from `signal_scheduler_runs`, restore duration from R-3) | the promised values and the contract | 1 | with R-1 | OPEN (owner) |
| R-6 | **P1 signal path monitored with alerting** | P-5 | recipient | (in P-5) | 2027-01-06 | PLANNED |

**Earliest date for the M10 technical criteria: about 2027-03-31** (Low confidence), set by the external security test (R-4), whose lead time and findings are UNKNOWN. Everything else can be ready with M9.

**M10 as a whole cannot be earlier than the pilot start plus three stable pilot months** (program dependency). With a pilot start on or after M9 (2027-03-12), that is 2027-06-12 at the earliest, so the program's **Wed 2027-06-30 is feasible for Engineering**; the risk sits in the tester engagement, the pilot start and the parallel-run evidence (P-1), not in build capacity.

---

## 4. Effort for the M9 and M10 items

Units as in `IMPLEMENTATION_SEQUENCE.md` §8: agent runs and PRs for Engineering build time, person-days (pd) as a human-equivalent comparison, review days as calendar days for `po` (and `cra`/`lca` where named). CI is the test runner.

| Item | Build PRs | Agent runs | pd | Review days | Confidence | Main risk |
|---|---|---|---|---|---|---|
| P-1 T12 staging (incl. DST1-C5) | 2-4 | 6-10 | 5-8 | 2-3 | Low | D-2 timing; first hosted pg_cron run; deploy token scope |
| P-2 production stack | 1-2 | 3-5 | 3-5 | 1-2 | Low | D-8 and the production purchase; manual-approval environment needs D-7 |
| P-3 restore test (first) | 1 (record and script) | 2-3 | 2-3 | 1 | Medium | backup restore of an empty production project proves little: restore the staging copy as well |
| P-4 runbooks | 1-2 | 2-4 | 3-4 | 1-2 (`lca` for the data-incident part) | Medium | names and numbers stay outside the repository |
| P-5 / R-6 outside alert for the P1 path | 1 | 2-3 | 2-3 | 1 (`cra` reads it) | Medium | a check that itself fails silently: it alerts on missing heartbeats, not only on errors |
| P-6 gate items (DST1-C4, VIS2-C3, AUD1-M1 check) | 3-4 | 6-10 | 5-8 | 2-4 (`cra` gate) | Medium | VIS2-C3 feasibility (#65) still unanswered |
| P-7 G-22 statement and CI check | 1 | 1-2 | 1-2 | 1 | High | the connector removal is the owner's |
| P-8 synthetic pilot day support | 1 | 2-3 | 2-3 | 1 | Medium | seed drift from the screens the team uses |
| R-1 monitoring | 1-2 | 3-5 | 4-6 | 1-2 (`lca` processor check) | Medium | health data leaking into error events |
| R-4 security test scope and fixes | 1 + fixes | 3 + UNKNOWN | 7-12 | 2-5 | Low | findings unknown until the report |
| R-2, R-3, R-5 (Engineering part) | 1 | 1-2 | 3-4 | 1 | Medium | targets are the owner's |
| **Total M9-M10 Engineering** | **14-21** | **31-51** | **37-58** | | | |

Together with M2-M8 (`IMPLEMENTATION_SEQUENCE.md` §8: 85-131 pd without T12) the total is **about 117-181 pd** (T12 counted once). As there, calendar time is set by decisions, briefs, designs and review, not by build capacity.

---

## 5. Delivery form of the apps (ADR-142, PROPOSED)

| App | Form | Reason | Label |
|---|---|---|---|
| **Caregiver app** (M6) | installable web app on the one NAVORA app (UX2 shell): web manifest, offline shell, a client-side command queue that resends with the **same idempotency key** | one code base and one permission model (RLS, definer readers) for phone and desktop; every command is already idempotent with a key and an audit in one transaction (ADR-003), so a resend after a lost connection cannot double-write; push already works through `sw.js` | PLANNED |
| **Operations app** (M8) | the same installable web app, desktop-first routes of the same shell | Operations already lives in `/operations`, `/team`, `/admin`; a second client would duplicate every reader | PLANNED |
| **Family app** (M7) | **no build**; specification only | D-40 frozen | — |

**Native only when M1 or MOB1 names a requirement the web app cannot meet.** The usual candidate is outside-app delivery of P1 signals on iOS. That does **not** decide the form here: D-33 keeps P1 in-app only on Safari and iOS until it is reassessed, and a native app's push (through Apple's service) would be the same outside-app channel D-33 is about. So a native app buys nothing for P1 until D-33 is reassessed (G-20). **UNKNOWN, to verify against current platform documentation in MOB1, not assumed:** the current behaviour of installed web apps on iOS for push permission, storage eviction and background work. The command queue is designed **not** to rely on background sync: it resends when the app is in the foreground again and shows what is not yet sent, so a value is never silently lost or silently sent late.

**Effort and sequence** for M6 and M8 are in `IMPLEMENTATION_SEQUENCE.md` §2, §8 (F-12 to F-17, B-7 to B-12).

---

## 6. Website approach (ADR-142, PROPOSED)

| Question | Proposal | Label |
|---|---|---|
| Separate site or public routes in this app? | **Separate static site, separate deployment and origin.** Built from its own directory (`website/`) in this repository with its own package and CI job; a CI check fails if `website/` imports from `src/`, references a Supabase URL or key, or sets a cookie. A separate repository is also fine; it needs the owner to create it | PLANNED (OPEN: `po`/owner, directory or repository) |
| Hosting needs | static hosting with an EU or Swiss region, TLS, the owner's domain; no server runtime except the demo form handler; no analytics or third-party script unless `lca` has read it | OPEN (owner, M3: domain, host) |
| Separation from the app's session and cookies | different origin (e.g. the app on its own subdomain, the site on another); the app's cookies stay host-only (no `Domain` attribute, as today), so the site never receives them; the site sets no cookie; the app's CSP is unchanged | PLANNED (cookie fact IMPLEMENTED) |
| Separation from the care database | the demo form posts to the owner-chosen destination (M3), **never** to a NAVORA Supabase project; the website's deploy holds no care-database credential; spam guard and confirmation e-mail on that destination | PLANNED (destination OPEN: owner; privacy notice and retention: `lca`) |
| Content truth | only IMPLEMENTED features shown as available; PLANNED and frozen features "in Vorbereitung" (program §2); Engineering supplies a per-page list of the IMPLEMENTED facts each page may claim, for the `lca` claims review | PLANNED |

**Effort:** see `IMPLEMENTATION_SEQUENCE.md` §8 (M5: 3-5 PRs, 8-12 pd, Low confidence: no brief, design, host or domain yet). The separation check adds about 1 pd.

---

## 7. Dates at risk (flag duty, program §5)

| Date | Risk | What would move it | Label |
|---|---|---|---|
| M2 2026-11-27 | 11 green Engineering PRs wait for the PO; no new UX2 part may open before they merge (PO order 06:30, item (0)) | PO merge pace | OPEN (`po`) |
| M4 2026-12-18 | PLAN3 needs #814 merged first | PO merge of #814 | OPEN (`po`) |
| M5 2027-01-15 | WEB1 (2026-11-20), designs (2026-12-04/-11), domain and host (M3), `lca` review (2027-01-08) all precede a 3-5 PR build | any input later than planned | OPEN |
| M9 technical | D-2 not answered by 2026-12-11 | one week of D-2 delay = one week | OPEN (owner) |
| M10 technical | security tester not engaged by mid-January | tester lead time UNKNOWN | OPEN (owner) |

---

## 8. Open questions raised by this estimate

1. **`po`:** move P-5 (outside alert for the P1 signal path) from M10 into M9? Engineering recommends it: it is the only way a stopped evaluator is noticed when nobody has the app open.
2. **`po`:** check the go-live gate index against COND1 (deviation in §1) when the M9 readiness file is built.
3. **owner (with D-2):** decide production hosting together with staging, so P-2 does not wait for a second decision.
4. **owner:** RTO, RPO and the SLA values (R-3, R-5); the security tester (R-4); on-call staffing (R-2).
5. **`po`/owner:** website in `website/` of this repository, or a separate repository (ADR-142).

## Change log
- 2026-11-03 15:14 eng: version 1 (items 3-6 of #830; items 1-2 by reference to `IMPLEMENTATION_SEQUENCE.md`, PR #833).
