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
