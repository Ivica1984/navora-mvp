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
