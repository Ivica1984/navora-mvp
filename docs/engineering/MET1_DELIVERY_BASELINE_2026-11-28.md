# MET-1 · Read-only baseline of the NAVORA delivery flow (2026-11-21 to 2026-11-28)

Issue #1873 (MET-1). Author: `eng`, scheduled run 2026-11-28 15:10–15:45 CET. **This document measures the current state. It changes no process rule, workflow, test, permission, schedule or product code** (acceptance criterion 6).

All statements carry one label: IMPLEMENTED (measured from a source named here), UNKNOWN (cannot be derived, with the reason), BLOCKED (a source could not be read).

## 1. Sources, window, retrieval

| Item | Value |
|---|---|
| Window | 2026-11-21 00:00 to 2026-11-28 24:00 Europe/Zurich (CET, UTC+1 throughout; no DST change in the window) = `2026-11-20T23:00:00Z` to `2026-11-28T23:00:00Z` exclusive |
| Retrieval | `2026-11-28T14:16:01Z` (15:16 CET). Cases still open at that moment are censored (see #1872) |
| Ref | `origin/recovery/main` at `1638ba2c` |
| Script | [`scripts/met1-delivery-baseline.mjs`](../../scripts/met1-delivery-baseline.mjs), started by hand, GET requests and local `git log`/`git show` only |
| Raw result | [`MET1_DELIVERY_BASELINE_2026-11-28.json`](MET1_DELIVERY_BASELINE_2026-11-28.json) (events, durations and anomalies for each case; no personal data, no comment bodies) |
| Scanned | 177 PRs updated since the window start that have at least one comment |
| Cases | 29 PRs whose **first** `Paket prüfbereit` comment lies in the window (28 merged, 1 open) |

**Reproduce:** `node scripts/met1-delivery-baseline.mjs --from 2026-11-21 --to 2026-11-28 --ref 1638ba2c --json out.json`. The script needs `gh` (authenticated) or `GITHUB_TOKEN`. A later run gives the same events for these cases unless someone edits or deletes a comment. Comment edits do not change `created_at`; deletions would remove a marker. If a comment were deleted, the JSON snapshot here remains the record.

### 1.1 Event markers found in the repository (IMPLEMENTED)

I read the markers from the comments before defining them. The PO hint in [7239662695](https://github.com/Ivica1984/navora-mvp/issues/1873#issuecomment-7239662695) lists them. Nothing below assumes a label or an API field that is not present.

| Marker | Source | Rule used by the script | Variants seen |
|---|---|---|---|
| OPENED | PR `created_at` | as is | – |
| READY | PR issue comment | text starts with `Paket prüfbereit:` or `Paket prüfbereit (` (leading `**`/`` ` `` ignored) | `**Paket prüfbereit (Nachtrag, neuer Kopf):**` (#1649) |
| WINDOW | PR issue comment by the PO | starts with `PO`, and its first 400 characters say `gate window … opened` or `Gate-Fenster … geöffnet` | From 2026-11-26 the PO writes `**PO: Gate-Fenster X geöffnet**`. Before that, one run comment ends its first paragraph with «Gate window HD-3a opened» (#1729). Most earlier PRs have no window comment |
| GATE | PR issue comment | starts with `<role>-gate: #<pr> <sha> <verdict>`, with role `cra`, `uxa`, `lca`, `aia` or `csa` | with or without backticks; `<sha>` 7 or 8 characters |
| MERGE | PR `merged_at` | as is; cross-checked with the first-parent commit `PO merge #<pr>` on the ref | the older subjects `Merge pull request #<pr> …` (5 cases) and `Merge PR #<pr>: …` (1 case) |
| ACCEPT_C | PR issue comment | starts with `PO acceptance` or `PO-Abnahme` | – |
| ACCEPT_A | `docs/product/ABNAHMEAKTE.md` §2, status line of each block | the first `YYYY-MM-DD HH:MM` after `Entscheid`; the case is linked when the status line names `#<pr>` | this is a **PO run label** (minute `:39`), not the moment the text was written; one line says «ca. 18:40», one «21:39-Lauf (geschrieben ca. 22:10)» |

**Limit (IMPLEMENTED fact):** every comment and merge is made by the same GitHub account (`Ivica1984`). The author field therefore cannot tell `po`, `eng`, `cra` or `uxa` apart. The role is known only from the text of the marker. A marker written by the wrong role would not be detected.

## 2. KPIs

Each KPI is the difference in hours between two markers of the same case. The script reports n, median, min and max. **No value is imputed.** A case without one of the two markers is listed as excluded. A negative difference would be listed apart and never used; there was none. With n ≤ 14, the median and the range are given; a mean is not.

For the per-case cycle, the script reads these markers:
- **R:** the last READY before the merge.
- **R₁:** the first READY.
- **G:** the first WINDOW after R.
- **L:** the latest of the first `clear` line per role that names the PR's final head and lies after G.
- **M:** MERGE.
- **A_c:** ACCEPT_C.
- **A_a:** ACCEPT_A.

| KPI | Formula | Denominator | n | median h | min h | max h | Excluded (reason) |
|---|---|---|---|---|---|---|---|
| K1 ready → gate window | G − R | cases with R and G | 8 | 0.37 | 0.09 | 0.99 | 21 cases: no WINDOW marker (all 21 before 2026-11-26 or packages without a gate window) |
| K2 gate window → last gate line | L − G | cases with G and L | 8 | 0.11 | 0.07 | 6.17 | same 21 cases |
| K3 last gate line → merge | M − L | cases with L and M | 12 | 0.86 | 0.02 | 0.94 | 16 merged cases without a final-head gate line; #1872 not merged |
| K4 first ready → merge | M − R₁ | merged cases | 28 | 0.95 | 0.10 | 7.99 | #1872 (open, censored) |
| K5c merge → acceptance (comment) | A_c − M | cases with M and A_c | 6 | 1.08 | 1.04 | 3.05 | 22 merged cases without an acceptance comment; #1872 |
| K5a merge → acceptance (Akte) | A_a − M | cases with M and A_a | 14 | 2.47 | 0.90 | 17.95 | 14 merged cases not named in ABNAHMEAKTE §2; #1872 |
| K6 first ready → acceptance (comment) | A_c − R₁ | cases with R₁ and A_c | 6 | 2.36 | 2.04 | 4.14 | as K5c |
| K7 PR opened → acceptance (comment) | A_c − OPENED | cases with A_c | 6 | 4.85 | 2.71 | 11.10 | as K5c |

How to read them (IMPLEMENTED unless marked):
- **K5a is counted per PR, not per acceptance.** HD-3a was accepted once (2026-11-26 11:39) over five PRs (#1729, #1760, #1770, #1774, #1780). HD-3a-F1 was accepted over two (#1838 and the test follow-up #1848). The 17.95 h maximum is #1729, which waited for its four follow-up PRs. In the window there are 9 distinct acceptances (ABNAHMEAKTE headings), linked to 14 PRs.
- **HD-1** (accepted 2026-11-21 03:39 on `9debf74`) lies in the window but is **not** a case. Its READY comments (#1623, #1624) are from 2026-11-20, so the script's case rule (first READY inside the window) excludes it. This is a choice of the case rule; any other rule would change n.
- **K7 is a proxy.** The issue asks for «package start → acceptance». No marker records when a package became *Active now* on the PR: that moment is in `NEXT_CAPABILITY.md` and the PO journal, as prose. The PR's `created_at` is used instead. It is often earlier than the activation (a draft PR) or later (work began on a branch first). **«Package start → acceptance» as the issue defines it is UNKNOWN**: there is no machine-readable start marker.
- **Time resolution (IMPLEMENTED fact):** WINDOW, MERGE and ACCEPT_C are written inside hourly PO runs, and the ABNAHMEAKTE time is the run's label. A difference below about one hour therefore mostly measures the run cadence, not the work. For example, K3 shows a median of 0.86 h and a maximum of 0.94 h: every merge came in the next PO run after the last gate line. This report only describes that pattern. It does not judge it.

### 2.1 Case table (Europe/Zurich, minute resolution; seconds in the JSON)

| PR | READY₁ (n) | WINDOW | last gate (roles) | MERGE | ACCEPT_C | ACCEPT_A |
|---|---|---|---|---|---|---|
| #1644 | 11-21 06:13 (1) | – | – | 11-21 06:41 | – | – |
| #1649 | 11-21 08:43 (2) | – | – | 11-21 09:40 | – | – |
| #1641 | 11-21 09:53 (1) | – | 11-21 11:44 (cra, uxa) | 11-21 12:40 | – | 11-21 14:39 |
| #1661 | 11-21 14:00 (1) | – | 11-21 20:34 (uxa, cra) | 11-21 20:41 | – | – |
| #1677 | 11-22 02:15 (1) | – | 11-22 02:44 (cra, uxa) | 11-22 03:40 | – | – |
| #1671 | 11-22 06:49 (1) | – | 11-22 07:43 (uxa, cra) | 11-22 07:45 | – | 11-22 08:39 |
| #1694 | 11-22 09:30 (1) | – | – | 11-22 09:40 | – | – |
| #1713 | 11-24 14:31 (1) | – | – | 11-24 14:39 | – | – |
| #1697 | 11-24 16:18 (1) | – | 11-24 16:31 (cra) | 11-24 16:40 | – | – |
| #1728 | 11-24 18:35 (1) | – | – | 11-24 18:41 | – | – |
| #1733 | 11-24 21:17 (1) | – | – | 11-24 21:40 | – | – |
| #1729 | 11-25 15:50 (1) | 11-25 16:42 | 11-25 16:59 (cra, aia, uxa) | 11-25 17:42 | – | 11-26 11:39 |
| #1752 | 11-25 18:42 (1) | – | – | 11-25 19:41 | – | – |
| #1754 | 11-25 19:32 (1) | – | – | 11-25 20:40 | – | – |
| #1760 | 11-25 23:23 (1) | – | – | 11-25 23:41 | – | 11-26 11:39 |
| #1765 | 11-26 01:22 (1) | – | – | 11-26 01:41 | – | – |
| #1770 | 11-26 03:42 (1) | – | – | 11-26 04:41 | – | 11-26 11:39 |
| #1774 | 11-26 05:18 (1) | – | – | 11-26 05:41 | – | 11-26 11:39 |
| #1780 | 11-26 08:07 (1) | – | – | 11-26 08:41 | – | 11-26 11:39 |
| #1788 | 11-26 12:47 (1) | – | – | 11-26 13:42 | – | – |
| #1790 | 11-26 14:41 (1) | 11-26 15:41 | 11-26 21:51 (lca, cra, uxa) | 11-26 22:41 | – | 11-27 03:39 |
| #1808 | 11-27 04:02 (1) | 11-27 04:41 | 11-27 04:47 (lca, uxa, cra) | 11-27 05:41 | 11-27 06:44 | 11-27 06:39 |
| #1821 | 11-27 07:57 (1) | – | – | 11-27 08:41 | 11-27 09:59 | – |
| #1825 | 11-27 18:25 (1) | 11-27 18:41 | 11-27 18:47 (uxa, cra) | 11-27 19:41 | 11-27 20:44 | 11-27 20:39 |
| #1838 | 11-28 00:35 (1) | 11-28 00:40 | 11-28 00:44 (cra, uxa) | 11-28 01:41 | 11-28 04:43 | 11-28 04:39 |
| #1848 | 11-28 02:45 (1) | – | – | 11-28 03:41 | – | 11-28 04:39 |
| #1854 | 11-28 06:35 (1) | 11-28 06:41 | 11-28 06:45 (cra, lca, uxa) | 11-28 07:41 | 11-28 08:46 | 11-28 08:39 |
| #1863 | 11-28 10:22 (1) | 11-28 10:41 | 11-28 10:59 (cra, uxa) | 11-28 11:41 | 11-28 12:46 | 11-28 12:39 |
| #1872 | 11-28 14:15 (1) | 11-28 14:40 | 11-28 14:45 (uxa, cra) | open at retrieval | – | – |

## 3. Missing, duplicate and contradictory markers (acceptance criterion 3)

The script reported 55 anomaly lines across the 29 cases (JSON field `anomalies`). Grouped:

| Finding | Cases | Meaning |
|---|---|---|
| No WINDOW after the last READY | 21 (#1644 … #1788, #1821, #1848) | The gate-window comment is a marker only from 2026-11-25 (#1729) and as a fixed heading from 2026-11-26 (#1790). K1 and K2 cannot be computed for earlier cases: UNKNOWN |
| No `clear` gate line naming the final head | 16 | By title, 12 of the 16 are CI, e2e, smoke or dependency fixes. The other four are the code fixes ORDER-F1 #1760, -F2 #1770, -F3 #1774 and -F5 #1780, accepted with HD-3a. Either the package had no gate, or the gate ran elsewhere. Which gates a package required is in its brief, and the script does not read briefs: **UNKNOWN per case** |
| Acceptance in ABNAHMEAKTE, no acceptance comment on the PR | 9 (#1641, #1671, #1729, #1760, #1770, #1774, #1780, #1790, #1848) | The acceptance comment on the PR became a habit from 2026-11-27. Earlier acceptances exist only in the Akte and the PO journal |
| Acceptance comment, PR not in ABNAHMEAKTE §2 | 1 (#1821, STG-SMOKE-3 (b) «accepted as test guard») | Two acceptance records do not agree: either the Akte is missing a block, or a test-guard acceptance is not an Akte acceptance. Not resolved here |
| ACCEPT_A earlier than ACCEPT_C | 5 (#1808 6 min, #1825 5, #1838 5, #1854 7, #1863 7) | This is not a contradiction. ACCEPT_A is the run label (`:39`) and the comment is written a few minutes into the run. The 5–7 minutes are that offset |
| Approximate Akte times | 2 blocks outside the window (STAB1 «ca. 18:40», BK-e1 «geschrieben ca. 22:10») | No case in the window is affected |
| Two READY comments | #1649 (07:43, then the Nachtrag 07:59 on a new head) | K4 uses the first, K1 the last READY |
| Two WINDOW comments | #1790 | K1 uses the first after the last READY |
| Merge subject not `PO merge #…` | 6 (#1641, #1661, #1677, #1713, #1733: `Merge pull request #…`; #1649: `Merge PR #…`) | The merge commit exists on the first-parent line in every merged case. Subject format only |
| Gate line `blocked`, or a gate line naming an earlier head | 0 | – |
| Merge commit time vs `merged_at` | 0 differences > 2 min | – |

## 4. Manual check of raw timestamps (acceptance criterion 5)

Three cases were re-read with separate `gh api` calls, outside the script, and compared with the JSON values:

| Case | Checked | Script (JSON) | Separate read | Result |
|---|---|---|---|---|
| #1863 | opened, READY 7237198017, WINDOW 7237401875, cra 7237426357, uxa 7237600865, merged, merge commit `ed7759e8`, ACCEPT_C 7238771312 | 08:24:01Z, 09:22:33Z, 09:41:23Z, 09:43:41Z, 09:59:51Z, 10:41:23Z, 10:41:22Z, 11:46:17Z | identical | match |
| #1729 | opened, READY 7165910009, WINDOW 7167253359 (old form), cra 7167315918, aia 7167436021, uxa 7167494472, merged, `4823eee5` | 2026-11-24 16:22:20Z, 14:50:56Z, 15:42:19Z, 15:47:18Z, 15:55:37Z, 15:59:28Z, 16:42:11Z, 16:42:10Z | identical | match |
| #1649 | opened, READY 7059439636 and Nachtrag 7059614005, merged, `05443987` (`Merge PR #1649`) | 07:17:07Z, 07:43:13Z, 07:59:42Z, 08:40:56Z, 08:40:55Z | identical | match |

There was no difference. The sample is small: 3 of 29 cases and 21 timestamps.

## 5. The two proposal PDFs (acceptance criterion 4): BLOCKED

The founder attached the PDFs to #1873 in comment 7240380925 (14:03 CET). This session cannot read them: both `user-attachments` URLs return HTTP 403 from the session's GitHub proxy («sessions are bound to their configured repositories»). Only repository-scoped API paths are reachable. I tried once and did not try any other route.

So I cannot explain the differences between the two documents from their definitions. **AC 4 is unresolved (BLOCKED).** Their numbers are not used anywhere in this report.

One concrete question to the founder or PO: could the two PDFs be committed to the repository, for example under `docs/product/` on a docs PR, or their KPI definitions, time windows and sample sizes pasted into #1873 as text? Then a follow-up can compare them with sections 1.1 and 2 here.

## 6. What this report does not do

It changes no process rule (FE-071, FE-089, FE-099, FE-105, FE-137), role right, schedule, workflow, CI, staging, gate, merge or app. It adds no test and starts no polling. It makes no recommendation for optimisation; per the issue, that needs a separate pilot issue released by the PO. The only files are this report, its JSON snapshot, the read-only script and the `eng` journal entry.
