# NAVORA weekly engineering status

**Owner:** Engineering (`eng`) · **For:** the owner and `po` · **Cadence:** every Friday (Europe/Zurich), newest week first. The first entry was written on Tuesday 2026-11-03, when the owner asked for this report (Engineering Directive Response).

**Each entry covers:** completed work, blocked work, dependency changes, milestone risks, date risks, architecture concerns.

**Labels:** IMPLEMENTED (merged on `recovery/main`) · IN REVIEW (open PR, CI state named) · PLANNED · OPEN · UNKNOWN. "Done" only means merged with green CI. Engineering does not run the tests itself; CI does.

## Escalation rule (owner, 2026-11-03)

Anything that threatens one of these dates is escalated **at once**, not in the weekly report:

| Milestone | Date |
|---|---|
| M2 Web App | 2026-11-27 |
| M4 PLAN3/AN3 | 2026-12-18 |
| M6 Caregiver App | 2027-01-29 |
| M8 Operations App | 2027-02-19 |
| M9 Pilot Readiness | 2027-03-12 |

**How:**
- a push notification to the owner;
- a journal entry;
- a line in `IMPLEMENTATION_STATUS.md`.

Each names the cause, the date at risk, the new estimate and what is needed. M5 (website, priority 5) is reported weekly only.

**"Threatens" means:** the estimated finish moves past the date, or a predecessor's own needed-by date in `APP1_IMPLEMENTATION_PLAN.md` §6 or `IMPLEMENTATION_SEQUENCE.md` §7.1 passes without its input.

**Owner priority:** 1 M2 · 2 M4 · 3 M6 · 4 M8 · 5 M5. Focus: the shortest path to M9.

---

## 2026-W48 (Mon 2026-11-23 to Sun 2026-11-29) · Friday entry, Fri 2026-11-27 13:05

Read at about 11:50–12:05 UTC on `recovery/main` `2ac2cc34` (PO merge #1826), by the GitHub API (PR list, check runs and comments of the open PRs, `ci` push runs on `recovery/main` (300 newest), `staging-smoke` and `staging-version` runs, open `agent:eng` issues, PR search for merges since 20.11. 12:00 UTC), Render (service `navora-staging`, deploy list, read only, FE-132), and Supabase `navora-staging` (`list_migrations`; one read-only count of the AI call reservation and switch-event tables, counts only, no rows). Engineering ran no test for this entry; every CI statement is a read of a named GitHub run. The entry covers Fri 20.11. 12:45 (end of the W47 read) to Fri 27.11. 13:00.

**Headline (date escalation against `BK_ROADMAP.md`, not against Blueprint §10):** the BK windows in `BK_ROADMAP.md` §3 (v2, 18.11.) are **missed**: BK-d «mit Testersatz frühestens Ende KW 48 (ca. 27.11.)» has not started, and BK-g «frühestens 1.–2.12.» cannot be met. **Cause:** founder order FE-109 (20.11.) made **HEIM-DP** the active block; the queue in *Active now* (09:39) is HD-3s-F2-F1 → HD-3a-F1 → HD-3a-F3 → HD-3b-0 → HD-3b → INTAKE-E2E → HD-3c → HD-3d, and BK-d and BK-g are not placed in it. **New estimate:** BK-d and BK-g **not before early to mid January 2027** if they follow HD-3d (Low confidence: eight packages at this week's pace of one package per 0.5 to 2 working days, plus HD-3c and INTAKE-E2E with a model, which are larger; no blocking clinical or legal question assumed). **M9 Phase A 2027-03-12** (Blueprint §10) needs «beide Abläufe (ambulant und Heim) und der BK-Auftragsablauf» on one named commit; 15 weeks remain; there is still no estimate for B2-Kern to B12, so whether M9 is threatened is **UNKNOWN**, not shown safe. **Needed:** the PO re-dates `BK_ROADMAP.md` (v2 is from 18.11.) and places BK-d and BK-g after or inside HEIM-DP; a founder decision only if the order should change.

**Second point (good news, IMPLEMENTED):** eight acceptances for the simulation in the period, each on a named commit with `ci-repeat` green (table below), and staging now runs **nine automated click paths**, the home planning flows among them.

### Contradictions found (README rule 10; documented, nothing changed)
1. **Escalation table at the top of this file** still lists M2 2026-11-27 (today), M4, M6, M8 from pre-FE-077 plans; the same in the header of `IMPLEMENTATION_STATUS.md`. Under FE-077 and README rule 13 they are history; this entry measures only against Blueprint §10 and `BK_ROADMAP.md`. Repeated from W47; proposal for `po` unchanged (mark as archived).
2. **Blueprint §8 body** (table «Status am 2026-11-13» and the diagram) still shows **BK as active**, while version rows 3.2.83 to 3.2.100 (Kap. 14) say «Kap. 8 Block HEIM-DP» and `NEXT_CAPABILITY.md` *Active now* names HEIM-DP. HEIM-DP appears nowhere in the §8 chain. Proposal for `po`: add HEIM-DP to the §8 chain with its place relative to B2-Kern, B3 and BK-g.
3. **`BK_ROADMAP.md` v2 (18.11.) and `FOUNDER_STAGING_UEBERSICHT.md` (18.11. 22:00)** describe BK-e as next and «kein KI-Anbieter gewählt»; both predate FE-094 and FE-109. The current founder view is `FOUNDER_EXECUTIVE_REPORT.md` (KW 48).
4. **`IMPLEMENTATION_STATUS.md` row AI1** says migrations 0166–0170 are «not on `navora-staging`»; `list_migrations` on `navora-staging` shows 0166–0170 applied (up to 0184). `eng` file; this report task does not edit it.
5. **Issue #1723** («codeql red on all runs since 2026-11-24») is still open, while `codeql` is `success` on #1825 (`c790a43b`, job 140479373172) and the fix #1728 is merged. Proposal: close after a check by `eng`.
6. **HD-3s-F2-F1 staging path:** the brief §6 names «bestehende Pfade 8/9 grün», the `eng` prompt STAGING 3a asks for a new path 10; raised by `eng` to `po` on #1825 (7217482763). Open.

### Active block and package
- **Block HEIM-DP** active since 20.11. (FE-109), replacing BK as the active block. **Package now: HD-3s-F2-F1** «the hand path reads a live take window (pause included) as busy and rejects with the take named» (CGR-289), contract `briefs/HD-3s-F2-F1.md`.
- **State: in progress (draft), IN REVIEW not yet.** #1825, branch `fix/hd3s-f2-f1`, head **`c790a43b`**, draft, `ci` run 45991260824 all `success` (`app` 140479374421, `db` 140479374416 «Files=181, Tests=7453, Result: PASS» per the writer's log read, `e2e` 140479374344 «234 passed», `ui-screenshots` 140479373946, `staging` dry run 140485317202), `codeql` 140479373172 `success`. **No `Paket prüfbereit:` comment yet**; the writer (12:10) names one open item (AIG1 apply without day plan, pgTAP assertion) and a PO question on staging path 10 before the ready report. Gate window `cra`, `uxa` not opened.
- **Then (PLANNED, *Active now* 09:39):** HD-3a-F1 (#1745) → HD-3a-F3 (FE-135 Monatssoll option A) → HD-3b-0 → HD-3b → INTAKE-E2E (#1726) → HD-3c (first AI help in planning) → HD-3d.

### Delivered this week
**Acceptances (PO, `ABNAHMEAKTE.md` §2; all gate «Simulation, synthetische Daten», none «released for real persons and data»):**

| Package | Decided | Named commit | `ci-repeat` | Label |
|---|---|---|---|---|
| BK-f invoice draft from the signed report | 20.11. 15:39 run | `40a2ce1` | 44746720886 20/20 | IMPLEMENTED (accepted) |
| STAB1 one readable source per DB function | 20.11. ca. 18:40 | `f7dfd2d` | 44778677226 20/20 | IMPLEMENTED (accepted) |
| HD-1 planning in the home (week, month, per person) | 21.11. 03:39 | `9debf74` | 44852899930 20/20 | IMPLEMENTED (partial acceptance) |
| HD-2 gap → external order → status back | 21.11. 14:39 | `0b8f537` | 44905215040 20/20 | IMPLEMENTED (partial acceptance) |
| PERF1 hint lists degrade visibly | 22.11. 08:39 | `4310526` | 44999346857 20/20 | IMPLEMENTED (accepted) |
| HD-3a optimiser (fixed rules) with ORDER-F1 (F2, F3, F5) | 26.11. 11:39 | `217a9a58` | 45781858795 22/22 | IMPLEMENTED (partial acceptance) |
| HD-3s split shift (two blocks) | 27.11. 03:39 | `5e9a0474` | 45922060591 22/22 | IMPLEMENTED (partial acceptance) |
| HD-3s-F2 external order with two blocks | 27.11. 06:39 | `1aeb5459` | 45944289812 22/22 | IMPLEMENTED (partial acceptance) |

Test guards accepted by the PO without `ci-repeat` (no block acceptance, by their contract): AUT-220 (#1788, `d2e78ace`), STG-SMOKE-3 (b) (#1821, `4130c011`). **Not accepted:** AI1 (#1697 merged 24.11., test substitute only), S-1 (#1677), SEC-DEP1 (#1713), HD-3a register acceptance «KI-gestützt» (OPEN), HEIM-DP register walk-through by the founder on staging (OPEN, `ABNAHMEAKTE.md` §2 HD-1, PERF1).

**Engineering PRs merged into `recovery/main`, Fri 20.11. 12:45 to Fri 27.11. 13:00** (merge commit; `ci` push run on that commit, attempt 1 `success` unless noted):
- **BK-f and STAB1:** #1581 (`e4e02c9`, 44738480843); #1604 tolerance row 0157 (`3d67dd4`, 44742633356); #1619 STAB1 (`d3b2233`, 44776130676).
- **HEIM-DP HD-1, HD-2, PERF1:** #1623 HD-1 (`2378c2a`, 44822518383); #1641 HD-2 (`ca334ce`, 44900259914); #1661 UXR-269 (`cdf7a5e`, 44942246424); #1671 PERF1 (`448e9c4`, 44995151978).
- **AI1:** #1697 (`2f2d785`, 45428323690). Merged with green CI; IMPLEMENTED as built, not accepted.
- **HD-3a and ORDER-F1:** #1729 HD-3a (`4823eee`, 45656780068: **`e2e` `failure`** on the merge commit, job 139355475736; test fix #1752 `b4cb8d3`, 45677677382 `success`); #1760 ORDER-F1 (`992a7e3`, 45715319517); #1765 (`edfacb8`, 45730576487 **attempt 2** `success`); #1770 ORDER-F1-F2 (`00b59f9`, 45750496490 **`cancelled`** by the concurrency group; next push `57d1ae4` #1774, 45756832135 `success`); #1774 F3; #1780 F5 (`661f8cb`, 45777230783); #1788 AUT-220 (`d2e78ac`, 45822152119).
- **HD-3s:** #1790 (`7e48a7a`, 45899843762); #1808 HD-3s-F2 (`d361205`, 45941372007).
- **Safety and security:** #1677 S-1 fail-visible P1 banner (`0194937`, 44977195499 **attempt 2** `success`); #1625 Next.js 16.4.6 (`e853e12`, 44857264639); #1713 SEC-DEP1 (`323e6df`, 45405736532).
- **CI and staging smoke:** #1624, #1644, #1649, #1694, #1754, #1821 (all `success`); #1728 CodeQL permissions (`4869e38`, 45451366479); #1733 artifact retention (`126a410`, 45483233440); #1701 AN2-F1 test (`050f480`, 45377228020).
- **Engineering docs:** #1599 W47 report, #1600, #1605, #1652 (docs only).
- **Red on `recovery/main` in the period (`ci` push, besides #1729):** `3b8c2fc` (22.11.), `09388e4` (24.11.), `ee1c2f0` (25.11., attempt 2); causes not read for this entry (UNKNOWN). Each was followed by green push runs.

**Not Engineering:** 205 PRs were merged into `recovery/main` from 20.11. 13:00 to 27.11. 13:00 CET (GitHub search); 34 carry an Engineering title, the rest are PO cycles and role reviews.

### Operable on staging
- **App:** Render `navora-staging`, deploy `dep-dc4kd10jo6nc73boqj5g`, commit **`2ac2cc34`** (= `recovery/main` head), live since 10:01 CET. Contains every code merge above (`4130c011` is an ancestor).
- **Database:** `navora-staging` (Zurich), highest migration **0184** `hd3s_f2_field_both_blocks` = highest migration in `supabase/migrations` on `recovery/main`. **App and database match: yes**; `staging-version` 45970011270 on `2ac2cc34` `success`.
- **Executed on staging: yes, by automation, no person's click-through recorded.** Newest run with all paths: `staging-smoke` 45960192885 on `4130c011`, «10 passed» (PO reading of the log, *Active now* 09:39; sign-in plus paths 1–9), verdict «green on the first run». The later runs 45960279709 (`581fc2c2`) and 45970011299 (`2ac2cc34`) are `success`; the latter took 14 s, so its paths were scoped out (docs-only change). The PO counts 52 red of 161 smoke runs since 21.11. (`FOUNDER_EXECUTIVE_REPORT.md` §5); STG-SMOKE-3 now separates deploy changes from real failures.

| Newly operable this week (IMPLEMENTED, accepted for the simulation) | Role and click path | Run on staging? |
|---|---|---|
| Invoice draft from the signed report; the team sends it; the client reads it (BK-f) | carer `/field` → «Bericht unterschreiben» → team «Rechnungsentwurf» → «Senden»; client `/order` → «Rechnungen» | **yes** (path 3, 390 px) |
| Week and month plan of the home, plan per person, absence, gap (HD-1) | home lead `/heim` → week or month → assign a person, record an absence → gap shown | **yes** (path 4, 390 px) |
| Order a gap externally; a Basel nurse takes it; the home reads «Gedeckt»; withdraw an order (HD-2) | home lead `/heim` → gap → external order; carer `/team` → take; home `/heim` → «Gedeckt»; withdraw → `/order` «Zurückgezogen» | **yes** (paths 5, 6) |
| Plan proposal by the optimiser, take it over, order the remaining gap (HD-3a, fixed rules) | home lead `/heim` → ask for a plan → «übernehmen» → order for a remaining gap | **yes** (path 7) |
| Split shift with two blocks in the plan (HD-3s) | home lead `/heim` → split shift → «übernehmen» → week shows two times | **yes** (path 8) |
| One external order for a split gap; the nurse sees two block cards (HD-3s-F2) | home `/heim` → order split gap; carer `/team` → take; carer `/field` → two cards | **yes** (path 9) |
| P1 safety signal banner never silently empty (S-1, not accepted) | carer `/field`, `/team`, `/operations` | **no** (not in the smoke; UNKNOWN) |

**Not yet built or not accepted:** HD-3s-F2-F1 hand-path rejection (#1825, draft); HD-3a-F1 server re-check of Pensum and Wochensoll (#1745; executive report: required before real data); Monatssoll HD-3a-F3; HD-3b to HD-3d; AI order capture (BK-d); BK-g end to end; intake with AI extraction (INTAKE-E2E); any connected model; DEMO1 one-click login (#1540) and `/platform` (#1541), both not placed.

### AI
- **Fixed rule (IMPLEMENTED):** home plan optimiser and its checks (HD-3a, greedy solver), split shift and split order (HD-3s, HD-3s-F2), take window (HD-3s-F2-F1, in progress), order list and offer reasons (ORDER-F1), matching and reason line (BK-b, BK-c3), invoice amount, refusals and send (BK-f), stop rule (AUT-152), staging click-path rerun decision (STG-SMOKE-3, a CI decision table).
- **Test substitute (mock) (IMPLEMENTED):** report draft from notes (BK-e2, AI1): in CI a fake provider and the evaluation set; on staging the rule substitute «regelbasiert, keine KI».
- **Connected AI model: none has run.** AI1 (#1697) built the guarded path (DB kill switch, call and money caps, prompt pin, reservation before a proposal; migrations 0166–0170, on `navora-staging`). Read-only count on `navora-staging` this run: **0** model call reservations and **0** switch events, so no model call was made there. Activation waits for AI1-F1 and step (b) (PLANNED). Whether the Render model variables are set: not read (UNKNOWN; values never read). Next AI functions in the queue: INTAKE-E2E extraction and HD-3c planning help (PLANNED).

### In review and gates
| PR | Item | Head | CI on head | Ready report | Gate lines | Waiting |
|---|---|---|---|---|---|---|
| #1825 | HD-3s-F2-F1 (draft) | `c790a43b` | 45991260824 all `success`; `codeql` `success` | none yet | none (window not opened) | open since 09:37; waits for one pgTAP item and the PO answer on path 10 |
| #1794 | probe HD-3a-F1 (draft, do not merge) | `363e50dd` | not read | – | – | open since 26.11.; evidence for #1745 |
| #1767 | probe pgTAP 178 hang (draft, do not merge) | `0fde6be2` | not read | – | – | open since 26.11. |
| #1611, #1612 | HEIM1 proposal, floor plan V1 (docs, PROPOSED) | – | – | – | – | held by the PO since 20.11. |
| #1540, #1541 | DEMO1, PLATFORM1 | `dcfa52c`, `bc2a391` | not read | none | none | open since 19.11.; not in *Active now* |
| #1716 | Dependabot against `main` | `a49b06f` | not read | – | – | targets `main`, not `recovery/main` |
| #3 | M2 `recovery/main` → `main` | `2ac2cc34` | – | – | – | blocked by D-7, D-8 (owner) |

**Measured gate latency (PO, M-03):** HD-3s ready 26.11. 14:41 → merge 22:39 (about 8 h waiting for gate lines) → acceptance 27.11. 03:39. Review and acceptance windows, not build time, set the pace.

**Open `agent:eng` issues: 29** (W47: 21). Stale candidates for `po` to close or relabel (no change by this task): #1230 and #1213 still `active` (B1.1 and BK no longer active), #1465 (answered by `staging-smoke`), #1723 (CodeQL fixed by #1728), #1222, #1211, #1194, #1544, #1626 (closed work).

### Blocked
| Item | Owner | Needed by | Safe path |
|---|---|---|---|
| Staging path 10 for HD-3s-F2-F1 (one synthetic case in Testteam Basel) | `po` decides (a) / (b) / limit; if (a), the founder | before the #1825 ready report (today or Mon 30.11.) | (a) founder signs in as the synthetic Operations demo account in the app, records one intake with a clearly synthetic name and assigns it to Testteam Basel; no secret. (b) a new GitHub secret for that demo account, set only by the founder in GitHub → Settings → Secrets; never in chat or a document |
| AI1 activation (first model call on staging) | founder, after AI1-F1 is ready | when AI1-F1 is ready (not in the queue yet) | Render dashboard → `navora-staging` → Environment: model variables named in `briefs/AI1.md`; spending cap in the provider console. Never in chat, GitHub or a document |
| STG-OBS-1 Render API key as a secret (optional, executive report §8) | founder | no date | GitHub → Settings → Secrets; a read-only key; never in a file |
| Clinical owner named (G-1, D-27) | founder | before Phase B (B12) | name a person; unchanged |
| B0-6 repository protection (D-7 stage 1) | owner | before B12 | GitHub → Settings → Rules; unchanged since W46 |

### Milestone and date risks (read this run)
- **Blueprint §10 M9 2027-03-12:** in progress; 15 weeks left. HEIM-DP has eight packages left; BK-d, BK-g and the blocks B2-Kern to B12 have no estimate. Engineering cannot say M9 is threatened, nor that it is safe (UNKNOWN). The executive report shows the same critical path.
- **Blueprint §10 M10:** OPEN.
- **`BK_ROADMAP.md` §3 windows (v2, 18.11.):** BK-e: met early (accepted 20.11.). BK-f «ca. 25.–27.11.»: **met early** (accepted 20.11. on `40a2ce1`). BK-d «frühestens Ende KW 48»: **missed**, not started. BK-g «frühestens 1.–2.12.»: **will be missed** (headline); new estimate early to mid January 2027 (Low). First live model run «KW 49»: **at risk**; AI1 is merged but AI1-F1 is not in the queue; estimate UNKNOWN.

### Architecture and platform concerns
1. **Staging smoke stability:** about a third of the smoke runs since 21.11. were red, most probably from Render deploy changes during a run (PO, cause not proven). STG-SMOKE-3 (b) reruns only on a proven deploy change. Watch whether real failures now stay red and visible.
2. **Query cost with growing data:** slow queries were found and fixed four times this week (PO count; PERF1 and the ORDER-F1 follow-ups F2, F3, F5). The budget tests (pgTAP 178–181, AUT-220) now guard them; pgTAP 178 still hangs in some runs (probe #1767, UNKNOWN cause).
3. **Uncontrolled React 19 forms reset after a rejected action** (#1825 review 10:10): a lead could lose her entries and save on the wrong day or person. Fixed for the plan and move forms on #1825; the same pattern may exist in other forms. Proposal: one repository-wide check (below).
4. **Two `eng` sessions on one branch:** the writer-line rule (FE-099 2a) worked on #1825: reviews by other sessions, no overwrite. It costs reviewer runs while the writer is away.
5. **Merge commit red after a green head:** #1729 (HD-3a) was green on its head and red in `e2e` on the merge commit (a test race, fixed by #1752). Acceptance on a named commit with `ci-repeat` caught it in time; the merge rule alone would not have.
6. **Throughput of documents:** 205 merges in a week, about 170 of them role and PO documents. The Blueprint §8 body, `BK_ROADMAP.md` and the staging overview went stale at the same time (contradictions 2 and 3).

### Innovation proposals for the PO (PROPOSED, not decided)
1. **Form-reset guard:** a lint rule or unit check that flags `<form action={…}>` with uncontrolled inputs on any path that can return a refusal, plus one e2e pattern «rejected save keeps the inputs». Benefit: removes the class of defect found on #1825 before HD-3b adds more planning forms. Cost: about half a package-day, test and lint only. Way back: remove the rule.
2. **Living roadmap from the queue:** a small script in `agents-check` that warns when `BK_ROADMAP.md` or Blueprint §8 names a block as active that is not *Active now* in `NEXT_CAPABILITY.md`. Benefit: the founder never reads a stale plan; contradictions 2 and 3 would have shown on 20.11. Cost: one script, no product code. Way back: delete the check.
3. **Smoke data fixture for staging:** one documented, synthetic, read-only fixture set per path (for example the case for path 10), created once by a named person and checked by a read-only smoke step. Benefit: new click paths no longer stall on missing staging data. Cost: one founder action and one smoke step. Way back: paths fall back to «in CI only» as today.

---

## 2026-W47 (Mon 2026-11-16 to Sun 2026-11-22) · Friday entry, Fri 2026-11-20 13:00

Read at about 11:50–12:00 UTC on `recovery/main` `e6d8768` (PO merge #1597), by the GitHub API (PR list, PR comments and check runs, Actions runs of `ci`, `staging-smoke`, `staging-version` on `recovery/main`, open `agent:eng` issues), Render (service `navora-staging`, deploy list, read only) and Supabase (`list_migrations` on `navora-staging`, read only). Engineering ran no test for this entry; every CI statement is a read of a named GitHub run. This entry also covers the weekend Sat 14 to Sun 15 Nov, which came after the W46 entry (Fri 13:05).

**Headline: BK-f, the first invoice draft from a signed report, is `Paket prüfbereit:` and waits only for the mandatory `lca` gate line.** `cra` and `uxa` named head `ba19210` `clear` at 11:47; the PO's start of `lca` was refused by its session permission check, so the founder is asked to start «NAVORA Legal & Compliance Agent» by hand («Run now»). Until then nothing more merges on BK-f.

**Second point (date risk, not a Blueprint §10 escalation):** the BK-g window «frühestens 1.–2.12. mit Testersatz» in `BK_ROADMAP.md` §3 (v2, 18.11.) is **threatened**. Cause: the founder orders FE-099 and FE-100 (20.11.) put four packages between BK-f and BK-g: STAB1 → AI1 → BK-d «Station bestellt» → absence and cover for a ward (`NEXT_CAPABILITY.md` *Active now*, `BK.md` §PO amendment 09:30 (2)). New estimate for BK-g: **about 7–11 Dec (KW 50), Low confidence** (assumes one package per one to two working days, the pace of BK-e2 and BK-f this week, and no blocking clinical or legal question). Needed: no founder action for the risk itself; `BK_ROADMAP.md` v2 should be re-dated by the PO. **M9 Phase A 2027-03-12 (Blueprint §10) is not shown to be threatened by this week's facts (UNKNOWN beyond BK; no estimate exists yet for B2-Kern to B12).**

### Contradictions found (README rule 10; documented, nothing changed)
1. **Escalation table at the top of this file** lists M2 2026-11-27, M4, M6, M8 from pre-FE-077 plans. Blueprint V3.2 §10 (running 3.2.79) names only **M9 2027-03-12** and **M10 OPEN**. Under FE-077 and README rule 13 the table is history. This entry measures risk only against Blueprint §10 and `BK_ROADMAP.md`. Proposal for `po`: mark the table as archived. The same stale table is in the header of `IMPLEMENTATION_STATUS.md` (`eng` file; this report task does not edit it).
2. **FE-101 to FE-104** are cited by `eng` (#1596, LEARNINGS.md) and by FE-105 (d), but are **not in `FOUNDER_DECISIONS.md`** (v55, 12:45). Source of FE-101/FE-102: the founder's live session with `eng` (journal `2026-11-20-1209-eng.md`). FE-103 and FE-104: UNKNOWN to Engineering.
3. **FE-105 (2)** asks for «Staging: verifiziert» before the merge, but migrations reach `navora-staging` only after the merge (`ci.yml` job `staging`). The PO's safe reading (FE-105 (b): green dry run before, real apply checked after) is adopted by Engineering.
4. `BK_ROADMAP.md` (v2, 18.11.) §0 and §8 still say «kein KI-Anbieter gewählt»; FE-094 (19.11.) chose Anthropic API direct for synthetic data on staging only. The roadmap is stale, not wrong in direction.

### Active block and package
- **Block BK** active since 13.11. 18:40 (Blueprint §8). **Slice BK-f «Rechnungsentwurf aus dem unterschriebenen Bericht»**, contract `briefs/BK.md` §PO package contract 2026-11-20 06:39 with amendments 08:39, 09:30, 09:39.
- **State: in gates (IN REVIEW).** #1581, head `ba19210`, `Paket prüfbereit:` comment 7037015711 (11:18 CET). CI run 44713939706 on the head: `app` 136218534468, `db` 136218614176 (Files=156, Tests=5565, PASS), `e2e` 136218589319 (193 passed, 0 skipped), `ui-screenshots` 136218531464 (second attempt after a Docker port-bind failure before any test, ADR-174), `staging` 136224749635 (dry run), CodeQL 136212386144: all `success`. Gate window opened ca. 11:47 (FE-097): `cra` clear (comment 7037575054), `uxa` clear (7037583660), **`lca` missing**.
- **Next in order (PLANNED):** tolerance-row PR after the BK-f merge (value from `lca`) → STAB1 → AI1 → BK-d → ward absence → BK-g.

### Delivered this week
**Acceptances (PO, `ABNAHMEAKTE.md` §2; all with gate «Simulation, synthetische Daten», none for real persons and data):**

| Slice | Decided | Named commit | `ci-repeat` | Label |
|---|---|---|---|---|
| BK-b reach and hard filters | 17.11. 02:39 | `ab90875` | 43994886883 20/20 | IMPLEMENTED (accepted) |
| BK-c take, acknowledgement, cover state, reason line | 18.11. 02:39 | `d51d1c1` | 44215240768 20/20 | IMPLEMENTED (accepted) |
| BK-e1 taken shift in `/field`, night across midnight | 18.11. 21:39 run | `3ea17ee` | 44393766620 20/20 | IMPLEMENTED (partial of BK-e) |
| BK-e2 report draft, «nicht übernommen» list, signature; **BK-e as a whole** | 20.11. 05:39 | `8155ac6` | 44669473293 20/20 | IMPLEMENTED (accepted) |

Carried over from after the W46 entry: B1.1 (cut) accepted 13.11. 18:40 on `33523a5` (20/20); BK-a accepted 14.11. 09:39 on `634ccb7` (20/20).

**Engineering PRs merged into `recovery/main`, Mon 16.11. to Fri 20.11. 12:45** (merge commit; `ci` push run on that commit: attempt 1 `success` for every line unless noted):
- **BK-b:** #1295 CGR-220 (`ab90875`); #1335 acceptance commit note (`f50e5fa`); #1337 ADR-198 ci-repeat self-labelling (`abaddca`).
- **BK-c:** #1342 BK-c1 (`781944f`); #1358 BK-c2 (`25d7cdf`); #1381 BK-c3 ADR draft, docs (`23c88f9`); #1388 BK-c3 (`ad21dd2`); #1403 pgTAP 147 (`a71c0bc`).
- **Staging:** #1087 STG1 staging job, owner-directed (`e0b38a1`); #1492 ADR-205 staging smoke (`2201628`).
- **BK-e:** #1417 BK-e1a (`3d9f1e6`); #1421 BK-e1b (`7c04240`); #1476 BK-e1c (`0ca04b6`); #1489 CGR-256 (`8532942`); #1494 BK-e2a part 1 (`e5f138f`); #1497 part 2a (`30bf219`); #1527 part 2b-1 (a) (`a411601`); #1529 (`51011c3`); #1531 (`ef0284d`); #1549 BK-e2 Abschlusspaket (`9f1d673`); #1572 AUT-152 stop-rule row (`8155ac6`).
- **BK measures:** #1503 ADR-208 taps per order, time to «Gedeckt» (`14e16d0`).
- **CI and quality (FE-098 Q1–Q6):** #1460 ADR-204 Docker Hub retry (`09712bb`); #1558 scorecard and ADR-218 (`0446985`); #1559 Q4 (a) local fonts (`2dff1a2`); #1560 Q6 (a) CodeQL (`1646ee0`); #1561 Q1 (a) version in the app, `/api/version`, staging match check (`f0229a4`); #1580 Q1 (a) fix (`8823e2a`).
- **Engineering docs:** #1500 standards S1–S8 PROPOSED (`87f6f8b`); #1504 and #1523 BK-e2 plans (`6b1698c`, `fb4ff32`); #1596 `LEARNINGS.md` (`5e3e27e`; its push run was `in_progress` at read time, the next push `e6d8768` run 44730002691 is `success`).
- **Weekend 14–15 Nov (after W46 entry):** #1238, #1246, #1252, #1257 (BK-a; merge-commit CI not re-read for this entry, UNKNOWN here; BK-a acceptance 20/20 covers `634ccb7`); #1268, #1270, #1273, #1276, #1291 (BK-b; merge-commit `ci` `success`).
- **Red on `recovery/main` this week:** three docs-only PO merges (`f8cab84` #1367, `dfb1ad3` #1458, `31a7e0d` #1518). For #1518 the `e2e` job failed at «Start local Supabase», before any test (infrastructure). Causes of the other two: not read (UNKNOWN). Each was followed by green push runs.

**Not Engineering:** 333 PRs were merged into `recovery/main` from Sat 14.11. 00:00 to Fri 20.11. 12:45 CET (GitHub search). About 50 are Engineering code or docs; the rest are PO cycles and role reviews. FE-105 (today) ends the PO's hourly docs PRs.

### Operable on staging
- **App:** Render `navora-staging`, deploy `dep-dc035267bikc739s0ka0`, commit **`e6d8768`** (= `recovery/main`), live since 12:45 CET. Region Frankfurt, Render free plan.
- **Database:** `navora-staging` (Zurich `eu-central-2`), highest migration **0153** `bk_e_aut152_simulation_stop_rule` = highest migration on `recovery/main`. **App and database match:** yes; `staging-version` run 44730002759 on `e6d8768` `success`.
- **Executed on staging:** **yes for click paths 1 and 2**, by automation: `staging-smoke` run 44699041140 (workflow_dispatch, 09:00 CET, on `269e4b5`), 3 of 3 passed (sign-in of each demo account; path 1; path 2 at 390 px). This is the first green run against `navora-staging` itself. Earlier runs 1–3 (18.11.) failed. No person's click-through is recorded.

| Newly operable this week (IMPLEMENTED, accepted for the simulation) | Role and click path | Run on staging? |
|---|---|---|
| Take an offer for the team, «Bestätigen» or «Ich kann nicht»; the client reads «Gedeckt» or «Noch nicht gedeckt» (BK-c) | client `/order` → order a shift; carer `/team` → «Übernehmen mit Pflegekraft»; client `/order` → «Gedeckt» | **yes** (smoke path 1) |
| Reason line per own team, fixed rule (BK-c3) | carer `/team` → offer card «Empfohlen für euch: …» | partly (path 1 opens the card; the line itself not asserted: UNKNOWN) |
| Taken shift as a card in `/field`, night 22:00–07:00 as one card under «Heute» (BK-e1) | carer `/field?datum=…` | **yes** (smoke path 2) |
| Report draft from the carer's notes, each line decided, signature (BK-e2; rule substitute, labelled) | carer `/field` → «Bericht» → notes → «Entwurf aus Notizen» → decide per line → «Bericht unterschreiben» | **no** (not in the smoke; UNKNOWN) |
| App version and migration level visible (Q1 (a)) | any role, `/api/version` | yes (`staging-version` reads it) |

**Not yet operable:** invoice draft and sending (BK-f, in gates; after merge every draft on staging is refused until the `lca` tolerance row is applied); AI order capture (BK-d); a connected model (AI1); ward view; `/platform`; one-click demo login (#1540, not placed).

### AI
- **Fixed rule:** matching (postcode distance, qualification, availability, BK-b); reason line (BK-c3); stop rule and thresholds (AUT-152, 0153); every BK-f function (amount, refusals, send). IMPLEMENTED.
- **Test substitute (mock):** the report draft from notes (BK-e2) runs in CI with a fake provider and the S2 evaluation set; on staging it runs as the rule substitute «regelbasiert, keine KI», because the model mode is not switched on. IMPLEMENTED.
- **Connected AI model:** **none has run.** The Claude provider path for the report draft is built (#1494, #1527, #1549; host fixed to `api.anthropic.com` by FE-094; refuses outside `navora-staging` and outside simulation organisations; kill switch; ledger without text). It is PLANNED to be enabled in package **AI1** (`briefs/AI1.md`; founder answers 20.11. ca. 09:45: provider FE-094 confirmed, cap CHF 50 per month, `lca` terms reading as a gate). No live model call is recorded on staging; whether the Render model variables are set: not read (UNKNOWN; values never read).

### In review and gates
| PR | Item | Head | CI on head | Ready report | Gate lines | Waiting |
|---|---|---|---|---|---|---|
| #1581 | BK-f | `ba19210` | run 44713939706, all `success` | 7037015711, 11:18 | `cra` clear, `uxa` clear, **`lca` missing** | ca. 1 h 40 min since the ready report at read time; `lca` paused, start needs the founder |
| #1540 | DEMO1 one-click demo login (ADR-212) | `dcfa52c` | not read | none | none | open since 19.11. 16:12; not in *Active now*; base 31 merges behind |
| #1541 | PLATFORM1 `/platform` counts (ADR-213) | `bc2a391` | not read | none | none | same; PO: later, with AUT-164 |
| #3 | M2 `recovery/main` → `main` | `e6d8768` | – | – | – | blocked by D-7, D-8 (B0-6, owner) |

**Follow-ups named in the BK-f window (not merge conditions):** BK-f-F1 (AUT-162), BK-f-F2 (AUT-163), BK-f-F3 (`team_prices_read`, PO), CGR-263 (S2: send ignores a hold opened after the draft), CGR-264 (S3: swallowed void error), UXR-261 to UXR-264.

**Open `agent:eng` issues:** 21. Several are stale: #1230 still carries `active` although B1.1 was accepted on 13.11.; #1465 (staging click path) is answered by `staging-smoke` 44699041140; #1222, #1211, #1194 refer to closed work. Engineering proposes that `po` closes or relabels them (no change by this task).

### Blocked
| Item | Owner | Needed by | Safe path |
|---|---|---|---|
| `lca` gate line on #1581 `ba19210` | founder (start «NAVORA Legal & Compliance Agent» by hand), then `lca` | Mon 23.11. (keeps the BK-f, tolerance row, STAB1 sequence in the week) | claude.ai scheduled tasks → the `lca` task → «Run now». No secret involved |
| Tolerance row value (simulation) for BK-f on staging | `lca` (in the gate line) | same | named in the gate line; `eng` ships it as a one-line PR |
| AI1 activation | founder, after the AI1 ready report | when AI1 is ready (after STAB1) | Render dashboard → `navora-staging` → Environment: set the model variables named in `briefs/AI1.md` §7 (4) and a CHF 50 cap in the provider console. Never in chat, GitHub or a document |
| B0-6 repository protection (D-7 stage 1) | owner | before B12 | GitHub → Settings → Rules (ruleset); unchanged since W46 |

### Milestone and date risks (read this run)
- **Blueprint §10 M9 2027-03-12:** in progress; BK slices a, b, c, e accepted in eight days, f in gates. No estimate exists for B2-Kern, B3, B6, B8, B5, B9, B10, B4-Rest, B1.1-2 to -5, B11, B12 (UNKNOWN). Engineering cannot say M9 is threatened, nor that it is safe.
- **Blueprint §10 M10:** OPEN.
- **`BK_ROADMAP.md` §3 windows:** BK-e with test substitute «Merge ca. 24.–25.11.»: **met early** (accepted 20.11.). BK-f «ca. 25.–27.11.»: **on track** (in gates 20.11.). BK-d with test substitute «frühestens Ende KW 48»: **moved** behind STAB1 and AI1 by FE-099; new estimate early KW 49 (Low). **BK-g «frühestens 1.–2.12.»: threatened** (headline). First live model run «KW 49 if provider and key by ca. 24.11.»: the provider is chosen (FE-094) and the cap is set; the date now depends on STAB1 and AI1; estimate KW 48 end to KW 49 (Low).

### Architecture and platform concerns
1. **Logic by text patch in SQL (IMPLEMENTED, being fixed):** on 20.11. a copied function lost the LEAVE1 guard; pgTAP 074 caught it (job 136125670120). STAB1 (FE-100) is the right next package; it must stay bounded (25 functions, one consolidation migration, drift check in CI).
2. **Shared e2e database:** BD-2 counted a visit left by the new BK-f spec (`ci` 44707414690). Fixed by scoping the query (`986fb0a`); the class of error stays open for every new take spec (`LEARNINGS.md`).
3. **Two `eng` sessions on one branch** (#1581, 08:28): no overwrite, but it cost a run. The writer-claim line is a PROPOSED working rule, not in the README.
4. **CI infrastructure:** Docker port-bind failures (ADR-174) and Docker Hub limits still cause first-attempt failures (BK-f head, #1518). `DOCKERHUB_USERNAME` set 20.11.; effect UNKNOWN.
5. **Staging host:** the app runs on Render Frankfurt, free plan, reachable from anywhere. Fine for synthetic data. If DEMO1 (#1540) is merged, anyone with the URL can sign in as a demo person with a public seed password; that needs an explicit PO and `lca` view before placement, and it must never coexist with real data.
6. **Review latency is now the bottleneck, not build time:** BK-f was built and green in about 5 hours; the merge waits on a paused mandatory role.

### Innovation proposals for the PO (PROPOSED, not decided)
1. **Run `staging-smoke` automatically after every Render deploy of a code commit** (today by hand). Benefit: «executed on staging» answered with a run ID for every merge, as FE-099 (2) asks. Cost: about 3 min of Actions per code merge; the secrets exist. Way back: remove the trigger line.
2. **Gate-window watcher:** a small workflow that, on a `Paket prüfbereit:` comment, posts one status comment and updates it with each gate line and the minutes waited (Blueprint §10 M-02/M-03). Benefit: the founder sees at once which role blocks and for how long. Cost: one workflow, no product code. Way back: delete the workflow.
3. **Per-spec synthetic namespace in e2e:** each spec creates its own simulation team and organisation, so no test can count another test's records. Benefit: removes the BD-2 class of failures before BK-g adds many specs. Cost: about one package-day inside STAB1 or BK-g. Way back: specs keep working on the shared seed.

---

## 2026-W46 (Mon 2026-11-09 to Sun 2026-11-15) · Friday entry, Fri 2026-11-13 13:05

Read at about 12:00 UTC on `recovery/main` `07a5296` (PO merge #1197), using the GitHub API: PR list, `mergeable_state`, check runs on every head and merge commit named below, Actions runs on `recovery/main`, open `agent:eng` issues. Engineering ran no test for this entry; every CI statement is a read of GitHub check runs.

**Headline (escalation): M2 Web App 2026-11-27 is threatened.**
- **Cause:** the founder's block order. FE-054 allows one active block. FE-073 and FE-074 put the core chain first: B1.1 (cut), then BK in seven slices. The UX2 remainder (M2.3: UX2-3, -4, -2, -8, -10, the screen items, UX2-33; due 2026-11-20) is in block B4. B4 is not active and has not started.
- **Second cause:** M2 criterion (6) (`main` equals `recovery/main` after D-8) needs D-7 stage 1, the ruleset. That is B0-6, an owner action, still open. Its latest date is 2026-11-20 (Blueprint §6.3).
- **New estimate:** M2 earliest about **2026-12-18** (Low confidence). This assumes BK finishes in about 3 weeks and UX2 then takes 8-12 runs plus 3-5 review days (`IMPLEMENTATION_SEQUENCE.md` §8).
- **What is needed:** a founder decision to re-baseline M2 (and the M6 dates that follow from it) under the block order, or to make the UX2 remainder an active block. The second option contradicts FE-054 (1) and FE-073, so Engineering does not recommend it.
- **Engineering changes nothing on its own:** FE-073 is the newest founder decision and overrides the older milestone date (README rule 10).

**Otherwise:** merging is no longer the bottleneck. This week the PO merged 44 Engineering or Engineering-documentation PRs. Three blocks or sub-blocks were accepted for the simulation: B0 without B0-6, a BD partial acceptance, and SAFE-D11. The bottleneck is now gate latency and the size of the next block (BK).

### Active block (FE-052, FE-054, README rule 12)
**Active:** **B1.1 «Sichere Anfrage», cut by FE-073 to B1.1-1 … B1.1-1c** (issue #1163, `active`). The next block is **BK** (brief `briefs/BK.md`, approved; issue #1187). BK starts when B1.1 is accepted.

| Criterion (brief `B1.1.md`, cut by FE-073) | State | Evidence |
|---|---|---|
| B1.1-1 region list and legacy values | IMPLEMENTED (merged) | #1164, merge `31bca54` (Fri 07:40), ADR-186; merge-commit `ci` 4/4 success (one earlier run cancelled by concurrency) |
| B1.1-1b CGR-201 share lock and safety net, CGR-202 (b), UXR-187 | IMPLEMENTED (merged) | #1181, merge `4c963f2` (Fri 11:41), ADR-187, pgTAP 133, race script in `db`; merge-commit `ci` 4/4 success; gates `cra`, `lca`, `uxa` on `c0b3728` (PO 12:39) |
| CGR-203 race «Zuordnen» against «Fall eröffnen» (test only) | IN REVIEW | #1184, head `f27d6e2`, 4/4 green. CI ran 09:24-09:31 UTC, while the base was still #1181's branch; it has not run since #1181 merged. `mergeable_state` `clean`. No `cra` gate line |
| B1.1-1c seed only BS/BL with case postcodes; legacy values as fixtures (FE-073 (2)) | IN REVIEW | #1196, head `42f57ea`, 4/4 green, `clean`, stacked on #1184 |
| Negative tests per PR, BD-2 stays green | met per PR on the merged parts | pgTAP 133 and the RLS negatives in #1164 and #1181 (PR descriptions). Block-level evidence is still OPEN |
| Repeatable: `ci` green on the last B1.1 merge commit **and** `ci-repeat` 10/10 with every time-of-day-guarded test passed | OPEN | needs the B1.1-1c merge commit |
| B1.1-2 to B1.1-5 | moved after BK (FE-073) | – |

**B1.1 is not accepted.** A merged PR and a green CI are not a block acceptance (FE-052 (2)).

### Completed (merged on `recovery/main`, CI green on the merge commit)
The check runs `app`, `db`, `e2e` and `ui-screenshots` were read on each merge commit. `cancelled` runs are concurrency cancellations; a later run on the same commit is green.

**Block acceptances this week (PO, `ABNAHMEAKTE.md`):**

| Block | Decision | Named commit and run | Label |
|---|---|---|---|
| B0 | **accepted for the simulation, without B0-6** (repository protection: owner, own gate before B12) | `9bb38d1`, `ci-repeat` 42944657786 20/20 (Wed 03:39) | IMPLEMENTED (accepted) |
| BD | **partial acceptance for the simulation:** home-care steps 1, 1b, 2-5, 8, 9. **Steps 6-7 (dictation, AI draft) not shown**, nor stop cases (a), (b), (e) or BD-H | `4a543c0`, `ci-repeat` 43231715012 20/20 (Thu 14:39) | IMPLEMENTED (partial) |
| SAFE-D11 | **accepted for the simulation** (a reopened case without a team gets a new search or a visible Operations exception) | `29e54ec`, `ci` 43341179263 4/4 and `ci-repeat` 43345332342 20/20 (Fri 02:39) | IMPLEMENTED (accepted) |

**Engineering PRs merged** (Mon 2026-11-09 to Fri 12:41; merge commit, then a CI note only where one applies):
- **B0:**
  - #985 B0-2 repeat check (`407568a`);
  - #991 B0-3 parts 1 and 2 (`a1060cf`);
  - #1002 B0-3 part 3 (`9170d1c`);
  - #1005 B0-3 part 4 (`29b8b83`);
  - #1008 B0-3 part 5 (`966652d`);
  - #1012 runner ports ADR-174 (`3fa8a2c`);
  - #1018 B0-2 evidence (`b520f79`);
  - #1026 B0-8 (`6ddd001`);
  - #1020 B0-7 (`4681eca`);
  - #1032 B0-1 (`22a38f6`);
  - #1039 B0-4 (`dfe4773`);
  - #1052 B0-2 final evidence (`5921473`).
  - CI note: on the merge commits of #991 and #1005, one `e2e` run failed and a re-run was green. These are the B0-3 F1 and VIS1 flakes. B0-3 was accepted under the stability rule (`PRODUCT_BLOCKS.md` §3.5), and the F1 cause stays OPEN.
- **BD:**
  - #1057 BD-1 inventory (`07cb664`);
  - #1060 UXR-155 (`1f2e0b7`);
  - #1062 Q-BD-2 simulation seed (`0c7e38b`);
  - #1064 D-18 (I1) billing-reader guard (`b4f4577`);
  - #1071 seed G-a/G-b (`de196df`);
  - #1072 G-6 gap fix (`42fdccf`);
  - #1069 BD-2 (`dcf7231`);
  - #1093 and #1096 BD-4 stop cases (`836246f`, `c9c83e8`);
  - #1104 CGR-185 (`d938535`);
  - #1109 BD-2 steps 1b, 3-4 (`00432e9`);
  - #1113 and #1119 status rows;
  - #1116 BD-5 evidence;
  - #1127 BD-7 negative reads (`00b4700`).
  - CI note: the merge-commit run of #1069 was lost on GitHub (queued, no jobs). Under **FE-061** the evidence is the later green merge commit with `ci-repeat`; BD's 20/20 on `4a543c0` covers it.
- **SAFE-D11:** #1143 (`c6b0ff8`).
- **B1.1:**
  - #1164 (`31bca54`);
  - #1181 (`4c963f2`);
  - docs only: #1172, #1174, #1177.
- **Engineering documentation:**
  - #907 W45 weekly status;
  - #971 owner answers on production readiness;
  - #1041 position on V1-V14;
  - #1100 owner session record (FE-057 to FE-067);
  - journal entries #1077, #1086, #1089, #1102, #1122, #1131, #1161.

**Not Engineering:** about 135 PO and role PRs (`po`, `cra`, `lca`, `uxa`, `aia`, `csa`). The PO counts 178 merges in total for the week (Blueprint §10.3).

### In review (Engineering)
| PR | Item | Block | Head | CI on head | Mergeable | Waits for |
|---|---|---|---|---|---|---|
| #1184 | CGR-203 race, test only | B1.1 | `f27d6e2` | 4/4 green (before the base change) | clean | `cra` gate line; CI against the new base |
| #1196 | B1.1-1c seed BS/BL + postcodes | B1.1 | `42f57ea` | 4/4 green | clean (base #1184) | #1184; gates |
| #1087 | STG1 migrations to `navora-staging` from CI | B11 (FE-057 exception) | `43a539a` | `app`, `db`, `e2e`, `ui-screenshots`, `sync` green; **`staging` failure** (owner secret `STAGING_DB_URL` missing) | **dirty** | owner secret; Engineering merges in the base |

The following are not Engineering PRs: #3 (D-8, `recovery/main` → `main`, `blocked` by the missing ruleset) and #1084 (Dependabot, base `main`).

### Blocked
| Item | Blocked by | Owner | Needed by |
|---|---|---|---|
| **M2 date under the block order** (UX2 remainder M2.3 = B4) | FE-054 (one active block) and FE-073 (BK first): UX2 cannot start | **founder** (re-baseline) | **2026-11-20** (M2.3 due date) |
| B0-6 / D-7 stage 1 ruleset; then D-8 (#3) | owner clicks (FE-045) | owner | 2026-11-20 (Blueprint §6.3) |
| STG1 #1087 → B11 part 1 (staging, restore test) | secret `STAGING_DB_URL`; base merge | owner (secret), `eng` (base) | about 2026-11-27, for B11 part 1 by 2026-12-04 (`PRODUCT_BLOCKS.md` §6 step 2) |
| BK-d AI capture, BK-e report draft on synthetic data | O-4: no AI provider chosen for synthetic data; D-35 rule A stays | founder | 2026-11-27 (Blueprint §6.3) |
| #1184 merge | `cra` gate line | `cra` | next `cra` run |
| MERGE1 (#964) | labelled `blocked`; FE-053 already removed the journal conflicts | `po` | – (M2 criterion 5) |
| M6.1 MOB1 brief | not written | `po` | 2026-11-27 |
| M8.1 AIO1 brief; M5.1 WEB1 brief | not written | `po` | 2026-11-20 |
| M9.0a NH-A2 to NH-A5 briefs; NH-A1 gate (c) | not written; `lca` | `po`, `lca` | before B9 (step 6, by 2027-02-19) |
| G-1 Clinical Owner | not named | owner | 2027-01-15 for the Phase A review |
| `DELIVERY_ESTIMATE.md` v2 (FE-021, FE-031, FE-036, NH-A; now also BK) | Engineering's own item; not done | `eng` | before M1.5, Tue 2026-11-17 |

### Dependency changes this week
- **FE-052 / FE-054 / FE-070 to FE-072: block by block.**
  - Merges only with tests.
  - Acceptance only on a named commit with `ci-repeat`.
  - The order now comes from blocks, not milestone percentages. This is the root of the M2 escalation above.
- **FE-073 (Fri):** core chain first; the legacy-data topic ends after #1181 and #1184; B1.1 is cut; the new block BK comes next. **FE-074 (Fri):** BK is generic. It has a client view with voice or free-text capture and AI extraction, hard filters before AI ranking, and an offer cascade. Its slices BK-a to BK-g are each one PR with gates.
- **FE-075 (Fri):** Blueprint V3.0 and Architecture Handbook V2.0 are drafts awaiting founder approval. Issue #1194 asks Engineering to check the Handbook against the code and confirm it by ADR. Until approval, V2.x and `ARCHITECTURE.md` lead.
- **FE-062 to FE-067:**
  - production is built now, with synthetic data only;
  - Supabase Free in Zurich for `navora-prod` (not yet created) and `navora-staging`;
  - app host Infomaniak Jelastic (CH);
  - Infomaniak default subdomain;
  - a new synthetic Basel test world;
  - accounts created by hand (D-26 open).
- **FE-056:** GitHub Actions is the only test environment; no npm registry for agent sessions. **FE-061:** rule for a lost merge-commit run. **FE-053:** one journal file per entry, which ended the journal conflicts.
- **FE-069:** D-43 (qualification and activity matrix with release stages) and D-18 (time rules) are built in Phase A as mechanisms, with PROPOSED content only.

### Milestone risks
| Milestone | Risk | Level | Why |
|---|---|---|---|
| **M2 2026-11-27** | block order; D-7 | **High, escalated today** | See the headline. Merged this week: no UX2 item. The UX2 queue #800 to #809 merged on 2026-11-06, which met the 2026-11-10 needed-by date. New estimate about 2026-12-18 (Low confidence). |
| M4 2026-12-18 | acceptance slot | Medium | All M4 build is on `recovery/main`: #814, #934, and AN3 #841 merged 2026-11-06. M4.5 (AN3) waits for the PO's re-check before B10 (FE-072 (1)). B10 re-verification is step 3 in `PRODUCT_BLOCKS.md` §6, by 2026-12-18, now behind B1.1 and BK. UNKNOWN whether AN3-C1 to C3 need build. |
| M6 2027-01-29 | follows M2 | **High, not escalated** | M6.2 (installable `/field`, due 2026-12-18) builds on M2.3. If M2 moves to about 2026-12-18, M6.2 to M6.4 have about 6 weeks for the caregiver core: 3-4 build PRs, 8-12 runs and 2-3 review days (`IMPLEMENTATION_SEQUENCE.md` §8). The offline e2e and the iOS behaviour are UNKNOWN. MOB1 brief due 2026-11-27. Decided with the M2 re-baseline. |
| M8 2027-02-19 | briefs | Medium | AIO1 brief due 2026-11-20, OPS2 and HAND2 due 2026-12-04, none written; not in the block chain yet. |
| **M9 2027-03-12** (Phase A passed + Phase B readiness file; incl. M9.0a/b nursing-home sector layer) | BK size, staging, nursing-home layer | **High, not escalated** | The PO reports "M9 on track: No" (Blueprint §10.3, W46). `PRODUCT_BLOCKS.md` §6 holds M9 only if staging stands by early December (step 2), but STG1 is blocked on the secret. BK (seven slices with AI capture and billing draft) was not in that path. M9.0a: NH-A2 to A5 have no briefs. M9.0b (nursing-home build, `eng`, due 2027-01-29) has not started. Engineering has **no** new estimate: the estimate v2 is its own open item (above). No needed-by date of a predecessor has passed today, so by the rule M9 is not escalated. It will be escalated if O-4 (2026-11-27) or the staging secret (about 2026-11-27) passes without input. |
| M5 (weekly only) | inputs | Low-Medium | WEB1 brief due 2026-11-20; domain at M3 (FE-065); no Engineering work (priority 5). |

### Date risks
- **Passed today:** M1 baseline 2026-11-13. The PO reports 75 %; M1.5 waits for Engineering's estimate v2 (FE-021, FE-031, FE-036, NH-A, now BK). Engineering proposes to deliver it as a docs PR by Tue 2026-11-17. The PO places it, because it is not a feature and needs no active block.
- **2026-11-16 / -17:** founder deliveries 3 and 4 (PO, FE-072 (6)); M1.5 delivery program v2.
- **2026-11-20:**
  - D-7 stage 1 (owner);
  - AIO1 and WEB1 briefs (`po`);
  - M2.3 due (cannot be met, see the escalation).
- **2026-11-27:**
  - O-4 AI provider for synthetic data (founder);
  - MOB1 brief (`po`);
  - staging secret (owner) for B11 part 1 by 2026-12-04.

### Architecture concerns
1. **BK's AI parts have no runtime yet (OPEN, founder).** BK-1a (extraction) and BK-8 (draft report) need a model. D-35 rule A forbids client or staff data in any AI service. FE-051 Muster 4 (an own model in a Swiss data centre) is not built. For Phase A on synthetic data only, the provider is O-4 and still open. Engineering builds BK-a to BK-c (forms, PLZ filters, ranking without AI, cascade) first, and invents no extraction rules.
2. **Handbook V2.0 against the code (IN REVIEW for `eng`, #1194).** The draft names five engines, among them "Matching SQL" and "Voice-to-Report". It also names six portals; only `/team` and `/field` exist (PLANNED for the rest). Engineering confirms or corrects this by ADR before BK-a. T-1 to T-9 are BK ADR inputs.
3. **Staging and production are not running.** `navora-staging` has no deploy from CI: STG1 is `dirty` and lacks its secret. `navora-prod` has not been created (FE-063). The restore test has never run. B11 cannot start, and the PO's statement "production now" (FE-062) is PLANNED, not IMPLEMENTED.
4. **Repository protection (B0-6) is still a substitute control.** The PO merges only with the head SHA and the seven conditions. There is no ruleset, so a faulty agent could push to `recovery/main` (FE-045 (1)). This is an owner action.
5. **Eight runs on `recovery/main` have been `queued` since 2026-11-11 20:41 UTC** (`dcf7231`, `fb25556`, `2909fac`, `fb714b7`). These are the lost runs covered by FE-061. They do not block merging; cancelling them is a repository setting, owner or `po`.
6. **The F1 flake cause stays OPEN** (B0-3 accepted under the stability rule). Two merge commits this week needed an `e2e` re-run (#991, #1005). Since B0's acceptance, no merge-commit failure has been read.
7. **Stacked PRs in B1.1** (#1196 on #1184): merge in order; Engineering re-runs CI on #1184 against the new base before the gate.

### Contradictions found (README rule 10)
- The escalation table (M2 2026-11-27 = UX2-1 to UX2-33) contradicts FE-054 and FE-073, which allow no UX2 work before B1.1 and BK. FE-073 holds. Engineering does not change the date; the founder re-baselines (escalated).
- Blueprint §4 M4.5 still says "BUILT, ready to merge" for AN3 (#841). #841 was merged on 2026-11-06 (`49ab0e0`). This is a PO file; Engineering only names it.

## 2026-W45 (Mon 2026-11-02 to Sun 2026-11-08) · Friday entry, Fri 2026-11-06 13:00

Read at 12:00 UTC on `recovery/main` `051431a` (GitHub API: PR list, check runs and `mergeable_state` on every head named below). This entry replaces the Tuesday entry as the week's report. The Tuesday entry stays below for history.

**Headline:** M2 is at **High risk, not yet escalated**. Only 3 Engineering PRs were merged this week. The open queue grew from 15 to **29 Engineering PRs, all with green CI**. The cause is merging, not building: the PO merges only in attended sessions (FE-018), and the PO's scheduled task has no merge step. The needed-by date for the UX2 queue is **Tue 2026-11-10**. If #800, #803 and #804 are not merged by then, M2 2026-11-27 is escalated that day.

### Completed (merged on `recovery/main`, CI green on the merged head)
| PR | Item | Merged | CI | Label |
|---|---|---|---|---|
| #799 | UX2-1 shell + UX2-31 (ADR-131) | 2026-11-05 | app, db, e2e, ui-screenshots green | IMPLEMENTED |
| #833 | `IMPLEMENTATION_SEQUENCE.md` (M1) | 2026-11-05 | green | IMPLEMENTED (document) |
| #838 | D-2 hosting decision support (no decision) | 2026-11-05 | green | IMPLEMENTED (document) |

- **Not Engineering, merged this week:**
  - PO: #856, #868, #871, #874, #877, #893, #898, #900, #904 (founder decisions FE-001 to FE-030, Blueprint V2.1);
  - `cra`: the review chain up to #879, merged 2026-11-05;
  - `aia`: #854, #858, #863, #866, #869, #889;
  - `lca`: #851.
- **UX2 stays `in-review`.** It is `delivered` only when UX2-1 to UX2-30 hold (brief).

### In review (Engineering, waiting for `po`; CI read 2026-11-06 at about 12:00 UTC on each head)
All 29 have app, db, e2e and ui-screenshots **green on their head**. `dirty` means the PR conflicts with the base, and Engineering merges the base in.

| PR | Item | Milestone | Head | Mergeable |
|---|---|---|---|---|
| #800 | UX2-27, UX2-29 | M2 | `797029c` | clean |
| #803 | UX2-15, -16, -25 | M2 | `8923171` | clean |
| #804 | UX2-18 to -21 | M2 | `5d1cece` | clean |
| #806 | UX2-30 | M2 | `91e7bc9` | **dirty** (since 2026-11-03) |
| #809 | UX2-26 | M2 | `7f74e71` | **dirty** (since 2026-11-03) |
| #810 | CGR-110 pgTAP 062 | M2 | `5074635` | clean |
| #813 | RLS4-C3 | M2 | `d92a2d5` | clean |
| #814 | AIG1-C4/-C5 (0105) | M4 predecessor | `9ee1a34` | clean |
| #815 | ASM1-C6 (0106) | before real assessment data | `81d131b` | clean |
| #828 | AIR1 (0107) | M8 criterion | `e90f2d1` | clean |
| #841 | AN3 (0108) | M4 | `09cdc85` | clean |
| #872 | PLAN3 part (a) (0109) | M4 | `a1880d4` | clean; **superseded by #876** (PO 06:30) |
| #876 → #880 → #882 → #883 → #885 → #886 → #888 → #890 → #891 | PLAN3 stack: PLAN3-14, part (b) slice 1, PLAN3-12, -11, -13, -7, CGR-139, CGR-140, UXR-113 (0110-0114) | M4 | on the heads read | clean |
| #894, #895, #897 | PLAN3-7 (2), PLAN3-9 (1), PLAN3-15 (0115, 0116) | M4 | `1a0799e`, `0c87180`, `6dace1d` | clean |
| #902 | CGR-75 (5) | M4 | `278d3c4` | **dirty** |
| #903 | PLAN3-17 (2) + PLAN3-3 wording | M4 | `c2cc5c3` | **dirty** |
| #906 | PLAN3-9 (2) (0117) | M4 | `d2a6bff` | clean |
| #835 | `DELIVERY_ESTIMATE.md` (M1) | M1 2026-11-13 | `6d0baaa` | clean |
| #837 | WEB1 and APP1 plans, ADR-143 | M1 | `85aa593` | clean |
| #840 | weekly status, first entry | – | `757e513` | dirty; **carried in this PR** |

Note: the PO's merge-ready list (06:30) names #888, #890 and #891 on earlier heads (`4c0ffbc`, `a4b1ce0`, `487c84a`). Those PRs have moved since, so the `cra` gate must be read on the current heads (AUT-50). UNKNOWN whether `cra` has done that: #901 (`cra` 09:30) names #894, #895 and #897 only.

### Blocked
| Item | Blocked by | Owner | Needed by |
|---|---|---|---|
| **Merging in scheduled runs** (all of the queue above) | the PO's scheduled-task prompt has no merge step (FE-018; `OWNER_AGENDA.md` bundle 1). Agents cannot change scheduled-task prompts. | **owner** | **2026-11-10** |
| M2 remainder (UX2-3 tokens and component port, UX2-4/-2/-8/-10, screen items, UX2-33) | PO order item (0): no new UX2 part until #800, #803, #804 are merged | `po` | 2026-11-10 |
| PLAN3 acceptance (M4) | #814 merged "in or before the PLAN3 PR"; the stack merged in order | `po` | 2026-11-27 |
| Own base merges: #806, #809, #902, #903 | Engineering (`dirty`) | `eng` | next hourly runs (before 2026-11-10 for #806 and #809) |
| M1 baseline | #835, #837 merged | `po` | 2026-11-13 |
| T12 staging and production | D-2: the care-app host is not named. FOUNDER_DIRECTION §303 says D-2 is "unchanged". | owner | 2026-12-11 |
| M6 build | MOB1 brief; `lca` SC-2; `cra` CGR-118 | `po`, `lca`, `cra` | 2026-11-27 / 2026-12-11 |
| M8 build | OPS2, AIO1, HAND2 briefs; O-07 brief | `po` | 2026-11-20 (AIO1), 2026-12-04 |
| M5 build | WEB1 brief; domain and demo destination | `po`, owner | 2026-11-20 / 2026-12-11 |

### Dependency changes this week (since Tuesday)
- **FE-021 (owner 2026-11-06): pilot Phase A is a simulated nursing home with synthetic data; no real partner is needed now.** M9 is redefined (FE-014: "M9 durch FE-021 neu gefasst"). Engineering has not re-estimated M9 against Phase A. The scope of Phase A is OPEN (O-1). `DELIVERY_ESTIMATE.md` (#835) still estimates the old M9: earliest technical date 2027-01-15, planning value 2027-01-29. Status: OPEN for `eng`, after O-1.
- **FE-019 D-11 Basel BS/BL; FE-020 D-1 fact answered (no real personal data in the old system); FE-022/D-24 nursing homes in scope.** `IMPLEMENTATION_SEQUENCE.md` §7 covers home care only (W-9). The PO asks `eng` for a nursing-home addendum once O-1 is answered. Status: PLANNED.
- **FE-018: merge authority lies with the PO alone; option C (Engineering merges) rejected.** Merge pace now depends on attended PO sessions until the owner adds a merge step to the scheduled prompt.
- **PLAN3 scope grew** with PO decisions PLAN3-14 to PLAN3-17 (CGR-136 to CGR-140, AUT-51/-52, UXR-102/-103/-113/-114). Engineering built most of them this week as stacked PRs (above).

### Milestone risks
| Milestone | Risk | Level | Why |
|---|---|---|---|
| M2 2026-11-27 | merge throughput | **High** (Tuesday: Medium) | Only 1 UX2 PR was merged this week (#799). 7 M2 PRs wait, two of them `dirty`. The M2 remainder has not started, by PO order. It needs 8-12 runs and 3-5 review days (`IMPLEMENTATION_SEQUENCE.md` §8), which still fits if the queue merges by 2026-11-10. **Not escalated:** the needed-by date has not passed. **Escalated on Tue 2026-11-10** if #800, #803 and #804 are not merged by then. |
| M4 2026-12-18 | stack size and merge order | Medium | PLAN3 build is ahead of the program: 17 PLAN3/AN3 PRs open, all green. Risks: (1) conflicts while 17 PRs merge in order; (2) #814 not merged; (3) `cra` gates on moved heads. Needed by 2026-11-27. |
| M6 2027-01-29 | inputs | Low-Medium | unchanged; MOB1 due 2026-11-27 |
| M8 2027-02-19 | inputs | Low | unchanged; AIO1 brief due 2026-11-20 |
| M9 2027-03-12 | redefinition | Medium, **UNKNOWN direction** | FE-021 changes what M9 is (Phase A, synthetic data). Owner gates that need real data may drop out, and nursing-home scope may be added. No new estimate until O-1 is answered. |
| M5 (weekly only) | inputs | Low-Medium | WEB1 brief due 2026-11-20; no Engineering work this week (priority 5) |

### Date risks
- **None past due today.**
- **Tue 2026-11-10:**
  - UX2 queue merged (#800, #803, #804; #806 and #809 after Engineering's base merge);
  - design set baseline: #834, merged 2026-11-03 (met).
- **Fri 2026-11-13:** M1 baseline. #835 and #837 are green and clean but not merged.
- **Fri 2026-11-20:** AIO1 and WEB1 briefs (`po`).

### Architecture concerns
1. **Large stacked PR chain (OPEN, `po`/`eng`).** PLAN3 now spans migrations 0109 to 0117 in 16 open, cumulative PRs (#906 carries everything back to 0109). Every merge rewrites `JOURNAL.md` and can make the rest `dirty`, as #874 did on 2026-11-05. Proposal: merge the stack in one attended session in stack order, with Engineering standing by for base merges. As long as nothing merges, Engineering should not open further PLAN3 slices.
2. **Care-app host still not named (OPEN, owner).** Unchanged from Tuesday (#838 §6, §12).
3. **Nursing-home scope (UNKNOWN impact).** The data model and the sequence were built for home care (visits, routes). Ward and shift structures are not modelled. Engineering cannot size this until O-1 is answered, and invents no nursing-home rules.
4. **Migration-number discipline.** It held this week: each of 0105 to 0117 has one file name across the open PR branches (checked with `git diff --diff-filter=A` per branch). The rule from Tuesday stands.

## 2026-W45 (Mon 2026-11-02 to Sun 2026-11-08) · first entry, Tue 2026-11-03 16:10

### Completed (merged on `recovery/main` this week)
- **Program and design baseline (not Engineering builds):**
  - #822 AI-first update and the owner directive;
  - #832 Delivery Program;
  - #834 `uxa` design set (IA, screen catalog, design system V1);
  - #836 PO adopts the design baseline and adds UX2-33.
- **Engineering:** no Engineering PR merged since 2026-10-31 (#792). All of this week's Engineering work is IN REVIEW (below).
- **Owner decisions (2026-11-03):**
  - ADR-142 accepted: one installable web app, website separate, demo requests never in the care database;
  - priority order set;
  - D-2 planning baseline set;
  - branding is not a blocker.

### In review (Engineering, waiting for `po`)
| PR | Item | Milestone | CI (last read) |
|---|---|---|---|
| #799 | UX2-1 shell | M2 | green on its head |
| #800 | UX2-27, UX2-29 | M2 | green |
| #803 | UX2-15, -16, -25 | M2 | green |
| #804 | UX2-18 to -21 | M2 | green |
| #806 | UX2-30 | M2 | green |
| #809 | UX2-26 | M2 | green |
| #810 | CGR-110 pgTAP 062 at any hour | M2 | green |
| #813 | RLS4-C3 | M2 | green |
| #814 | AIG1-C4/-C5 (0105) | M4 predecessor | green on its head; **conflicts with the new base** (next hourly run merges the base) |
| #815 | ASM1-C6 (0106) | before real assessment data | green on its head; **conflicts with the new base** |
| #828 | AIR1 AI prohibited targets (0107, #824) | M8 criterion | green |
| #833 | `IMPLEMENTATION_SEQUENCE.md` | M1 | green |
| #835 | `DELIVERY_ESTIMATE.md`, ADR-142 (accepted by the owner) | M1 | updated today; CI to re-run |
| #837 | WEB1 and APP1 implementation plans, ADR-143 | M1 | updated today; CI to re-run |
| #838 | D-2 production hosting decision support; §12 owner baseline | M3 input | updated today |

### Blocked
| Item | Blocked by | Owner | Needed by |
|---|---|---|---|
| M2 remainder (UX2-31 tokens, components, ports, UX2-33) | the open UX2 PRs above (PO order 06:30 item (0): no new UX2 part before they are merged) | `po` | 2026-11-10 |
| PLAN3 (M4) | #814 merged first ("in or before the PLAN3 PR") | `po` | 2026-11-27 (build window starts 2026-11-30) |
| T12 staging and production | D-2 (owner); the **care-app host** is not in the planning baseline | owner | 2026-12-11 |
| M6 build | MOB1 brief; `lca` on device storage (SC-2); `cra` banner wording | `po`, `lca`, `cra` | 2026-11-27 / 2026-12-11 |
| M8 build | OPS2, AIO1, HAND2 briefs; O-07 brief (SC-3) | `po` | 2026-12-04 |
| M5 build | WEB1 brief; domain and demo destination | `po`, owner | 2026-11-20 / 2026-12-11 |

### Dependency changes this week
- The design set (#834) is now the baseline. M2 gains UX2-33 (error, not-found and no-access pages).
- The owner's priority puts the website (M5) last. Its build runs only in slots M2-M8 do not need.
- The D-2 planning baseline is GitHub, Supabase, **Vercel for the website**, 99.9 %, PITR, CH/EU data and a separate website. The website host is settled for planning. The care-app host is not (see concerns).
- ADR-142 was accepted, so `website/` is the website directory. The duplicate draft on #837 was reconciled.

### Milestone risks
| Milestone | Risk | Level | Why |
|---|---|---|---|
| M2 2026-11-27 | review throughput | **Medium** | 15 Engineering PRs open, none merged since 2026-10-31. M2 needs the UX2 queue merged by about 2026-11-10 and then about 7 more PRs reviewed. **Not escalated yet:** the needed-by date (2026-11-10) has not passed. |
| M4 2026-12-18 | PLAN3 start | Medium | needs #814 merged by 2026-11-27; `cra` gate on assignment |
| M6 2027-01-29 | inputs | Low-Medium | MOB1 (2026-11-27) and the `lca`/`cra` answers (2026-12-11); iOS installed-app behaviour UNKNOWN until MOB1 |
| M8 2027-02-19 | inputs | Low | four briefs not written |
| M9 2027-03-12 | owner and clinical decisions | Medium | D-2 app host, G-1, D-12, DPIA; Engineering's technical path is about 2027-01-15 to 2027-01-29 (`DELIVERY_ESTIMATE.md`) |

### Date risks
- **None past due.** The first date to watch is the UX2 queue merged by Tue 2026-11-10. If it is not, M2 2026-11-27 is escalated that day.
- **Still OPEN for the owner (#833 §9 question 1):** whether M9 needs M4 and M8, or only M2, the M6 core and T12. Until answered, Engineering plans to the program, in which M9 depends on M4 and M8.

### Architecture concerns
1. **Care-app host not named (OPEN, owner).** Vercel is named for the website only. The care app carries health data in transit, and Vercel has no Swiss region (nearest is `fra1`); its logs and metadata are global per the vendor (#838 §6). Staging is decided on Render Frankfurt. Engineering needs one host decision for staging and production, or the owner's confirmation that "Vercel" covers the app too.
2. **99.9 % is measured, not contractual,** below the Supabase and Vercel Enterprise plans. Two serial services multiply: 99.9 % × 99.99 % ≈ 99.89 % (#838 §1).
3. **PITR's worst-case data loss is about 2 minutes.** Engineering reads "PITR required" as accepting RPO ≤ 2 minutes with tested restores; the owner confirms (#838 §12 gap 3).
4. **Parallel Engineering sessions.** Two sessions today drafted ADR-142 with different scopes. The duplicate was dropped on #837. **Rule going forward:** before a new ADR or migration number, check every open PR's `DECISIONS.md` and `supabase/migrations`, not only `recovery/main`.

## Change log
- 2026-11-03 eng: file created on the owner's request; first entry 2026-W45.
- 2026-11-06 eng: 2026-W45 Friday entry (scheduled weekly run).
- 2026-11-13 eng: 2026-W46 Friday entry (scheduled weekly run); M2 escalated.
