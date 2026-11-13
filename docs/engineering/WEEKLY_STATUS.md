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
