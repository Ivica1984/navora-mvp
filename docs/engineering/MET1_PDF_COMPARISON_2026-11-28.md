# MET-1 · Acceptance criterion 4: the two founder PDFs next to the baseline

Issue #1873 (MET-1), PO order [7242433741](https://github.com/Ivica1984/navora-mvp/issues/1873#issuecomment-7242433741). Author: `eng`, scheduled run 2026-11-28 18:10–18:40 CET. Supplement to [`MET1_DELIVERY_BASELINE_2026-11-28.md`](MET1_DELIVERY_BASELINE_2026-11-28.md) (the «baseline»). **Read-only comparison. It changes no process rule, workflow, test, permission, schedule or product code, and it decides none of the proposals in the PDFs** (V1–V7, Vorschläge 1–9, Hebel 1–3; they touch FE-089/FE-105 and need their own released pilot issue).

## 0. Sources and method

| Item | Value |
|---|---|
| PDF A | `docs/engineering/NAVORA Lieferfluss Leerlauf auf null, KPIs.pdf` (8 pages; «Kurzfassung», 9 Vorschläge, 12 KPIs; its own source line: GitHub API read 2026-11-28 12:40–13:10) |
| PDF B | `docs/engineering/NAVORA Lieferfluss Leerlauf auf null und KPIs.pdf` (6 pages; V1–V7, KPI groups Fluss / Wächter / Produkt) |
| Text extraction | `pdftotext -layout` (poppler); tables read from the layout text, so a cell split across lines was re-joined by hand |
| Baseline data | `MET1_DELIVERY_BASELINE_2026-11-28.json` (retrieval `2026-11-28T14:16:01Z`, ref `1638ba2c`), per-case timestamps recomputed to the minute |
| Additional reads (this run) | `docs/product/ABNAHMEAKTE.md` §2 at `948bc380`; Actions API `ci-repeat.yml` runs since 2026-11-20; `ci.yml` push runs on `recovery/main` and `staging-smoke.yml` runs, both `created` 2026-11-20T23:00Z..2026-11-28T12:10Z (the PDFs' stated reading time); `docs/agents/journal/` file names. Read at about `2026-11-28T17:10Z` |

Each PDF value gets one verdict:
- **reproduced (IMPLEMENTED):** I recomputed it from the baseline JSON or a source named above and got the same number (rounding as in the PDF).
- **differs (IMPLEMENTED):** the PDF and the baseline measure different things; the cause is named from the definitions and shown by recomputation.
- **not reproduced (UNKNOWN):** I could not get the PDF's number from any definition I can see; the measured value is given instead. No cause is invented.
- **outside the baseline (UNKNOWN):** the baseline has no such KPI and this run did not re-measure it.

No PDF number is taken over into the baseline. All times Europe/Zurich (CET).

## 1. Definitions side by side

| Concept | Baseline (§1.1, §2) | PDF A | PDF B | Consequence |
|---|---|---|---|---|
| Package start | **no machine-readable marker → UNKNOWN**; K7 uses PR `created_at` as a proxy | «Abnahme des Vorgängers» | «aktiv = Abnahme des Vorgängerpakets» | Both PDFs use the previous ABNAHMEAKTE acceptance as start. That is a definable marker (an Akte line), but it is the end of the *predecessor*, not the start of *this* package's work: a PR can be opened before it (#1808, #1838) or about 40–180 min after it. It measures the interval between consecutive acceptances |
| Ready | first / last `Paket prüfbereit` comment (R₁ / R) | «Paket prüfbereit» comment | «Fertigmeldung» | same marker |
| Gate time | K1 = R → window, K2 = window → last final-head `clear` line | «Gates» = **ready → last gate line** (R → L) | «Gates antworten» = **window → last gate line** (= K2) | A and B start the gate clock at different markers (§3, row 6) |
| Acceptance | ACCEPT_C (PR comment) and ACCEPT_A (Akte run label `:39`) | «PO-Abnahme» | «Abnahme in ABNAHMEAKTE.md» | A's figures reproduce with ACCEPT_C; B's «241 min» also with ACCEPT_C |
| Case selection | every PR whose first READY lies in 2026-11-21..28 (29 PRs), per PR | «kleine Pakete», five or six named PRs | three named PRs (#1838, #1854, #1863) for the timeline | A excludes the test guard #1821 and (in the headline) HD-3s #1790; the baseline includes both |
| Build time / waiting share | not defined (no start marker, no «working» marker) | «gebaut je etwa 1 h», Flusseffizienz 25 % | Wartezeitanteil 44–48 % «Schätzung» | not derivable from repository markers (§3, rows 12–13) |

## 2. Event cases used below (minutes, recomputed from the baseline JSON)

| PR | Package | R₁ → M | R → G | G → L | R → L | L → M | M → A_c | R₁ → A_c | PR opened | Akte acceptance |
|---|---|---|---|---|---|---|---|---|---|---|
| #1790 | HD-3s | 479 | 59 | 370 | 429 | 50 | – | – | 11-26 13:26 | 11-27 03:39 |
| #1808 | HD-3s-F2 | 99 | 39 | 6 | 45 | 54 | 64 | 162 | 11-27 00:25 | 11-27 06:39 |
| #1821 | STG-SMOKE-3 (b) | 44 | – | – | – | – | 79 | 122 | 11-27 07:17 | – (see baseline §3) |
| #1825 | HD-3s-F2-F1 | 76 | 16 | 6 | 22 | 54 | 63 | 138 | 11-27 09:37 | 11-27 20:39 |
| #1838 | HD-3a-F1 | 66 | 5 | 4 | 9 | 57 | 183 | 249 | 11-27 20:29 | 11-28 04:39 |
| #1854 | HD-3a-F3 | 66 | 6 | 4 | 10 | 56 | 65 | 130 | 11-28 05:33 | 11-28 08:39 |
| #1863 | HD-PEN-HAND | 79 | 19 | 19 | 37 | 42 | 65 | 144 | 11-28 09:24 | 11-28 12:39 |
| #1872 | HD-3s-F2-F1-F1 | open at retrieval | 25 | 5 | 30 | – | – | – | 11-28 13:24 | 11-28 16:39 (after retrieval) |

#1790 per-role gate lines (JSON `gate_final_clear`): `lca` 15:47, `cra` 21:32, `uxa` 21:51 (CET, 2026-11-26).

## 3. Point by point

| # | PDF | Statement | Baseline / recomputation | Verdict and cause |
|---|---|---|---|---|
| 1 | A | Ready → acceptance, «letzte fünf kleine Pakete» 2.2–4.1 h, median 2.4 h | K6 (R₁ → A_c): n 6, median 2.36 h, 2.04–4.14. Without #1821: #1808 2.70, #1825 2.31, #1838 4.14, #1854 2.17, #1863 2.40 → **2.17–4.14, median 2.40** | **reproduced** for those five. **Differs** from K6 only by case selection: K6 includes the test-guard acceptance #1821 (2.04 h) |
| 2 | A | Of that, median 0.5 h gates | R → L of the same five: 0.15, 0.16, 0.37, 0.62, 0.74 → median **0.37 h**. With #1790 (7.16 h) added: six values, median **0.50 h** | **reproduced only with #1790 included**, which A's headline («ohne HD-3s») excludes. A mixes two samples. Also A's «gates» start at READY (= K1 + K2), not at the window |
| 3 | A | Median 0.9 h waiting for the merge | L → M of the five: 0.69–0.94, median **0.90 h** (also 0.90 with #1790). K3 over all 12 cases: 0.86 | **reproduced**; differs from K3 only by sample |
| 4 | A | Median 1.1 h merge → acceptance | M → A_c of the five: median **1.08 h**; K5c (n 6): 1.08 | **reproduced** (with ACCEPT_C; with the Akte label K5a it would be 2.47 h per PR, baseline §2) |
| 5 | A | 0.5 + 0.9 + 1.1 explain the 2.4 h | the three are medians of different samples (rows 2–4) | Not an error in the parts, but **medians do not add up**: 2.5 ≠ 2.4. The sum is no decomposition of one case |
| 6 | A vs B | HD-3s gate window: A «Ausreisser 7,2 h», «cra brauchte 6,8 h»; B «6,2 h» | #1790: R → L **7.16 h**, R → `cra` **6.85 h**; G → L **6.17 h** (= K2 max) | **all three reproduced**; the PDFs **differ from each other by start marker**: A counts from READY, B from the window comment (59 min later). B's value equals baseline K2 |
| 7 | A, B | HD-3a-F3 and HD-PEN-HAND each 4.0 h «aktiv → abgenommen»; B: HD-PEN-HAND 241 min | Akte labels 04:39 → 08:39 → 12:39 = 4.0 h each; comments 04:43 → 08:46 → 12:46 = 4.05 h and 4.00 h (≈ 240 min) | **reproduced**. **Differs** from baseline K7 (median 4.85 h) by start marker (predecessor acceptance vs PR opened). The baseline still calls «package start → acceptance» UNKNOWN, because the predecessor's acceptance is not this package's start (a PR may exist before it) |
| 8 | A | Durchlaufzeit baseline 26.–28.11: median 7.3 h (4.0–16.0 h, 6 packages) | Consecutive Akte acceptances in 26.–28.11: HD-3s 16.0, HD-3s-F2 3.0, HD-3s-F2-F1 14.0, HD-3a-F1 8.0, HD-3a-F3 4.0, HD-PEN-HAND 4.0 → **median 6.0 h, 3.0–16.0** | **not reproduced (UNKNOWN).** A's minimum 4.0 excludes the 3.0 h interval of HD-3s-F2, but no selection of these six intervals gives a median of 7.3. Which six packages or which start times A used is not stated |
| 9 | A | «Abgenommene Pakete 26.11 11:46 bis 28.11 12:46: 6 in 49 h» | Akte: HD-3s, HD-3s-F2, HD-3s-F2-F1, HD-3a-F1, HD-3a-F3, HD-PEN-HAND after the HD-3a acceptance; 49 h interval | **reproduced** (the start point HD-3a itself not counted) |
| 10 | B | Durchsatz «9 (21.–28.11.), davon 3 am 28.11.» | Akte §2 decisions in 2026-11-21 00:00..28.11 13:10: HD-1, HD-2, PERF1, HD-3a, HD-3s, HD-3s-F2, HD-3s-F2-F1, HD-3a-F1, HD-3a-F3, HD-PEN-HAND = **10**; 3 on 28.11 (04:39, 08:39, 12:39). Baseline: 9 acceptances *linked to cases* (HD-1 is in the window but not a case, baseline §2) | «3 am 28.11.» **reproduced**. 9 vs 10: **UNKNOWN** whether B left out HD-1 (as the baseline's case rule does) or counted otherwise |
| 11 | B | V6: «vom 21.11. bis 26.11. kein Paket abgenommen (4,5 Tage)» | Akte: HD-2 on 21.11 14:39, PERF1 on 22.11 08:39; next HD-3a on 26.11 11:39 → gap **4.1 days** (22.11 08:39 → 26.11 11:39) | **contradicted by ABNAHMEAKTE** for 21.–22.11. The measured gap without an acceptance is 4.1 days, not 4.5. Cause of B's figure UNKNOWN |
| 12 | A | «gebaut je etwa 1 h», Flusseffizienz 25 %, Leerlauf Engineering ≈ 3 h je Paket | no marker for «building starts/stops» in comments, commits or Akte | **UNKNOWN** (A says itself that «Bauen» includes CI wait and that pure coding time is not measured). Commit timestamps could bound it per PR; the baseline does not do that |
| 13 | B | Wartezeitanteil 44–48 % (HD-PEN-HAND 106 of 241 min) | no marker for «no role works and no test runs» | **UNKNOWN** (B calls it an estimate). A (≈ 75 % waiting) and B (44–48 %) **differ from each other by definition**: A counts CI time as building but ties waiting to «not building»; B counts test runtime as non-waiting. Neither is reproducible from markers |
| 14 | B | Gate lines → merge 42–56 min (#1838, #1854, #1863) | L → M: 57, 56, 42 min | **reproduced** (rounding: 56.5 min) |
| 15 | B | Gates answer in 4–18 min | G → L: 4, 4, 19 min (18.5) | **reproduced**; equals K2 per case |
| 16 | B | V1: «Fertigmeldung → Merge 1 h 06 bis 1 h 19 bei den letzten fünf Paketen» | R₁ → M: #1808 1:39, #1825 1:16, #1838 1:06, #1854 1:06, #1863 1:19 → last five **1:06–1:39** | **not reproduced (UNKNOWN)** for five; it fits the last **four** (#1825–#1863). Which fifth case B used is not stated. Baseline K4 over 28 cases: median 0.95 h |
| 17 | B | Merges always at xx:41 | baseline case table: every merge from #1752 (11-25 19:41) to #1863 at minute :40–:42 | **reproduced** (consistent with baseline §2 «time resolution») |
| 18 | B | Merge → `ci-repeat` start 30 min, «5 von 5 Paketen = 30 min»; elsewhere «HD-3a-F1 150 min» | `ci-repeat` acceptance runs start at :11: #1808 → 45944289812 30 min, #1825 → 46054928186 30, #1838 → 46101633614 **150**, #1854 → 46120023950 30, #1863 → 46138674419 30 | 30 min and 150 min **reproduced**; «5 von 5 = 30 min» (V3 table) **contradicts** B's own text: it is 4 of 5. Not in the baseline (no `ci-repeat` marker) |
| 19 | A, B | `ci-repeat` runs 14–20 min (B); ≈ 20 min, 46138674419 12:11–12:31 (A) | run start → update over the six acceptance runs since 27.11: 12.8 (`…-w2`), 13.7, 13.9, 14.5, 17.6, 20.4 min; 46138674419 11:11:10Z → 11:31:36Z | **reproduced** for the five first-window runs (13.7–20.4); the HD-3s second window took 12.8 min. Outside the baseline KPIs |
| 20 | A vs B | `ci-repeat` first attempt: A «6 von 6 seit 27.11.»; B «7 von 8 seit 26.11.» | runs on `repeat/accept-*` since 27.11 00:00: 6, all `success` (incl. `…-w2`, the second window for HD-3s). Since 26.11 00:00: 9 runs, 8 `success` (`…d92cbd0` 45759933656 `failure`); per acceptance: HD-3a 2 runs, HD-3s 2 runs, five others 1 run | A **reproduced**. B **not reproduced (UNKNOWN)**: 8 of 9 runs, or 5 of 7 acceptances in one attempt, depending on whether runs or acceptances are counted; neither gives 7 of 8. The two PDFs **differ** by window start (26.11 vs 27.11) |
| 21 | B | `staging-smoke` 54 of 220 runs red since 21.11 (25 %) | `staging-smoke.yml` runs created in the window: **220**, `failure` **54**, `cancelled` 39, `success` 127 | **reproduced** (24.5 %; «red» = `failure`; the 39 cancelled runs are neither) |
| 22 | B | `ci` push runs on `recovery/main` red: 3 of 79 since 21.11 | `ci.yml`, `event=push`, branch `recovery/main`, same window: **219** runs, `failure` 7, `cancelled` 4 | **not reproduced (UNKNOWN)**: different count and denominator; B's filter is not stated |
| 23 | A | 62 `eng` journals 26.–28.11, 16 pure review runs | files `2026-11-26-*-eng.md` … `2026-11-28-*-eng.md` up to 13:10: **62** | 62 **reproduced**; «16 review runs» **UNKNOWN** (needs reading each journal; not a marker) |
| 24 | B | «Erster Lauf grün» 100 % (last 20 packages): no second ready report on a new head | baseline `ready_count`: only #1649 (11-21) has 2; the last 20 cases have 1 each | **reproduced** for PRs (B says «Pakete»; one package can span several PRs) |
| 25 | B | Abnahme → nächster PR 38–50 min, einmal 3 h | PR opened minus predecessor acceptance comment (for HD-3s, which has none, the Akte label): #1854 50, #1863 38, #1872 38 min; #1825 2 h 53; #1808 and #1838 were opened **before** their predecessor's acceptance (−3 h 14, −15 min) | **reproduced** for the cases B evidently used; B's range leaves out the two PRs opened early. «Next PR opened» is not «build started» (UNKNOWN, see row 12) |
| 26 | A | 491 merged PRs in 11.5 days, 80 `feature/`/`fix/`; ≈ 84 % coordination PRs; PO alone 185; `ci` median 11.3 min (1.4–15.1) over 76 green runs since 26.11; `staging-smoke` ≈ 20 min (13 min Render), job 140952514335; follow-up fixes 3 of 8 / 2 of 7 | – | **outside the baseline (UNKNOWN)**, not re-measured in this bounded comparison. Note: A gives «3 von 8» (table and Leitplanke) and «2 von 7» (text) for the same idea |
| 27 | B | Vertragsbereite Briefs 1; Entscheid-Wartezeit; Rückläufer; Späte Befunde (HD-PEN-HAND 4 UX + 1 wording); Bedienbare Kette (11 click paths) | – | **outside the baseline (UNKNOWN)**; B marks two of them «nicht gemessen» itself |

## 4. What this means for the baseline (no process conclusion)

IMPLEMENTED facts from the comparison:
1. Every PDF number that overlaps a baseline KPI reproduces from the same raw timestamps (rows 1, 3, 4, 6, 7, 14, 15). The differences come from three definitional choices: **case selection** (test guard #1821 and HD-3s #1790 in or out), **start marker** (READY vs gate window; predecessor acceptance vs PR opened) and **acceptance marker** (PR comment vs Akte run label).
2. Five PDF numbers do not reproduce from any definition visible to me (rows 8, 10, 16, 20 B, 22) and one is contradicted by the ABNAHMEAKTE (row 11). They stay **UNKNOWN**; I did not adjust them.
3. The two PDFs disagree with each other in four places (rows 6, 13, 20, and the start-of-package wording vs build time), each explained by a different definition or window.
4. Build time and waiting share (rows 12, 13) cannot be measured from the markers the baseline uses. «Package start → acceptance» stays UNKNOWN in the baseline. Using «predecessor acceptance» as start, as both PDFs do, would be a new definition; the PO decides whether MET-1 should add it as K8. That is a question, not a change made here.

## 5. Reproduce

All recomputations use the baseline JSON (fields `events.*`) and these read-only calls (no write call was made):

```
gh api "repos/Ivica1984/navora-mvp/actions/workflows/ci-repeat.yml/runs?per_page=50&created=>=2026-11-20"
gh api --paginate "repos/Ivica1984/navora-mvp/actions/workflows/ci.yml/runs?branch=recovery/main&event=push&per_page=100&created=2026-11-20T23:00:00Z..2026-11-28T12:10:00Z"
gh api --paginate "repos/Ivica1984/navora-mvp/actions/workflows/staging-smoke.yml/runs?per_page=100&created=2026-11-20T23:00:00Z..2026-11-28T12:10:00Z"
pdftotext -layout "docs/engineering/NAVORA Lieferfluss Leerlauf auf null, KPIs.pdf" -
```

Counts read from the Actions API can change if runs are deleted or re-run; the figures above are as read at about `2026-11-28T17:10Z`.
