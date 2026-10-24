---
id: SIG1
title: Safety signals reach a person, nobody watches a screen
author: po
status: approved
updated: 2026-10-24
---

# SIG1 — Safety signals reach a person, nobody watches a screen

## Problem
Every visit safety signal (`visit_overdue`, `visit_stuck`, `visit_uncovered`, `visit_interrupted`, no-show) is pull-only: it exists for a person only when someone opens `/team` or OPS1 (CGR-37, `cra` 2026-10-24 02:26; search over `src/` and the migrations finds no push, notification, realtime subscription or periodic refresh). A P1 overdue alert at 07:15 reaches nobody until somebody looks. The traditional answer is a dispatcher or a coordinator who watches an operations screen all day: exactly the management layer NAVORA removes. The thresholds of D-28 are worthless if the signal reaches nobody.

**Why does this workflow exist?** Watching a screen exists because software could not find the right person. From scratch, the signal goes to the person responsible for the visit and to her team, and the team, not a dispatcher, takes it.

## Users and journey step
Nurses and care assistants of the visit's team (the responsible member first), Operations as the fallback; step Planning → Visit (safety signals of C1/CSR1).

## Outcome
A P1 visit safety signal produces a delivery to named people, shown in the nurse's own tool without reloading, and one team member takes it with one tap. Whether anyone took it, and when, is on the record. Nobody has to keep OPS1 open to be safe.

## Acceptance criteria
Product decision on CGR-37 (PO, 2026-10-24 03:10, product authority). Who must respond, how fast and at which hours is `clinical` (D-28); SIG1 changes no threshold, no priority and no hand-close rule (CR-038 to CR-041, CR-049, CR-053 unchanged).

- [ ] **SIG1-1 Delivery record.** When a visit safety signal reaches P1 (by the effective rule, including no-show), the server writes one delivery row per recipient: the visit's responsible member, and every active member of the team that owns the visit. When the team has no active member other than an absent responsible member (ABS1 absence covering the moment), the recipients are the organisation's Operations users. The row holds signal kind, visit, recipient, created time; no name of the client, no free text, no health data.
- [ ] **SIG1-2 Exactly once.** A second evaluation of the same open signal writes no new row; a signal that ends and later starts again (a new cause) writes new rows. No row is written for another team or another organisation. pgTAP for each.
- [ ] **SIG1-3 Shown without a reload.** `/field` and `/team` show undelivered-to-screen P1 signals of the user at the top within 60 seconds of their creation while the page is open (polling or realtime: Engineering's choice), with fixed text per kind ("Einsatz überfällig", "Einsatz hängt", "Einsatz ohne Zuständige", "Einsatz abgebrochen", "Klientin öffnet nicht") and a link to the visit. e2e: a P1 created while `/field` is open appears without navigation.
- [ ] **SIG1-4 Take it (team autonomy).** Any recipient taps "Ich übernehme". The server records who and when (audited, idempotent: a second tap returns `duplicate`); every other recipient then sees "übernommen von <Mitglied>" and the item leaves their top list. Taking a signal does **not** close it: the signal stays open until its cause ends (CR-041 unchanged). A non-recipient gets `rejected`.
- [ ] **SIG1-5 Not taken.** A P1 delivery that no recipient has taken after the organisation's `signal_untaken` threshold (strict default 15 minutes, PROVISIONAL until D-28) is delivered to Operations as well, once. The threshold sits in the organisation's operating rules (ADM1) and may be set stricter, never above the default. pgTAP: untaken past the threshold → Operations rows; taken before → none.
- [ ] **SIG1-6 Evidence for D-28.** AN2 measure 10 ("how exceptions end") gains two values per team: share of P1 signals taken, median minutes from P1 to taken. Never per nurse; AN1 suppression applies.
- [ ] **SIG1-7 Negative cases.** A coach without team membership receives nothing (only Operations as fallback); a removed member receives nothing for her former team; a client or partner account receives nothing; the delivery table is not readable across organisations (RLS, pgTAP).
- [ ] **SIG1-8 Pilot precondition (until an external channel exists, D-32).** The pilot plan names, for every hour in which visits are planned, the person who has `/field`, `/team` or OPS1 open; visits outside those hours are not planned. This is a go-live condition written into `docs/product/CARE_OPERATING_MODEL.md` by the PO, not a software check.
- [ ] **SIG1-9 No later signal than the default (rewritten by the PO 2026-10-24 07:10 after CGR-39; first written 06:10).** The 06:10 text treated every amount as a delay and so repeated the inversion `cra` found (CGR-39): for `visit_uncovered` it refused a stricter value and still allowed 0. **The range fix now ships with ADM1 (`changes-requested`, ADM1-R1 to ADM1-R6, direction per rule)**, ahead of SIG1. SIG1-9 is met when ADM1-R1 to R6 are merged with green pgTAP; SIG1 adds only: every signal SIG1 delivers reads its threshold from `effective_exception_rules` (no second copy of a threshold), pgTAP named in the SIG1 PR.

## Out of scope
- Delivery outside the app (web push, SMS, e-mail, phone): needs D-32 (provider, region, message content without personal data). SIG1 builds the delivery record so a channel can be added without changing the rule. **PO 2026-10-24 05:15 (D-32, `lca` note 1):** whenever a channel is added, its message is one fixed text, not configurable per organisation or per message, without client name, address, visit time or health data; members receive an information text before it is switched on.
- Response deadlines, on-call rosters, response duties: `clinical` (D-28 items 3 and 6). SIG1 names recipients, not duties.
- P2 and P3 signals: they stay pull-only, by design (alert fatigue); a later change needs AN2 evidence.

## Constraints and references
CGR-37 (S2; S1 if visits are planned when nobody watches), `reports/CLINICAL_GOVERNANCE.md` 2026-10-24 02:26; D-28 (thresholds and response duties, `clinical`); CR-041 (safety signals not closable by hand); ABS1 (absence), CGR-21 (owning team also for a covered visit); ADM1 operating rules; AN1/AN2 (team measures, suppression); Handbook: team autonomy before central dispatch. No personal or health data in delivery rows or messages.

## Open questions for engineering
- Polling vs. Supabase realtime for SIG1-3 under the existing RLS; cost on mobile.
- Where the P1 transition is computed today (derived on read in `derived_exceptions`): a delivery row needs a writer. Is a scheduled evaluation (pg_cron or an Edge Function every minute) acceptable, and how is it tested in CI?
- The owning team for a covered visit (CGR-21): confirm the recipients follow the owning team, plus the covering member as the responsible one.

## PO review — 2026-10-24 11:09: reviewed, **awaiting clinical review** (not accepted)

#279 (head dad4dbe, merged as 7a3fdb5; migration 0060, ADR-074). CI green on the head (app, db incl. pgTAP 062, e2e) and on the merge commit 7a3fdb5 and `recovery/main` a081031 (read through the GitHub API). **The PO did not run the tests.** The status row still says `in-review` although #279 is merged; the review starts on the merge with green CI (PO instruction C). Engineering sets `delivered` at its next run.

**Clinical review gate (README).** SIG1 is in scope (patient safety). The latest merged report (2026-10-24 02:26) and the open `cra` PRs #259 (06:30) and #278 (10:26) all describe SIG1 as *unstarted*: no section covers 0060. So the PO completes its own review and **does not set `accepted`**. Findings considered: CGR-37 (advisory S2): the remedy is built as decided (below); CGR-39: SIG1-9 met (ADM1-R, #268; 0060 reads `effective_exception_rules`); CGR-41 (advisory S2, #278, not merged): concerns SIG2/D-32, not SIG1; decided by the PO in D-32 and the SIG2 brief this cycle. **Asked of `cra`:** review 0060 (writer, recipients, take, untaken step, AN2 rows) and the deviations below in its next section.

| Criterion | Result | Evidence |
|---|---|---|
| SIG1-1 delivery record per recipient (responsible, team members; Operations when nobody of the team is on duty); kind, visit, recipient, time; no client name, free text or health data | met, with deviation 1 | 0060 `signal_deliveries` columns (kind, visit, recipient, reason, created); `private.signal_recipients`; pgTAP 062 "902=responsible,906=team", fallback "904=operations_fallback", org B admin fallback; column list asserted |
| SIG1-2 exactly once; a new cause → new rows; no row for another team or organisation | met | partial unique index `safety_signals_one_open`, `unique (signal_id, recipient_id)`; pgTAP 062 "a second evaluation … writes nothing", "a new cause is a new signal", other-organisation count 0 |
| SIG1-3 shown on `/field` and `/team` within 60 s without reload, fixed text per kind, link to the visit | met | `SignalBanner.tsx` (30-s poll), `signals/rules.ts` fixed texts; writer runs on pg_cron every minute and on each poll (15-s throttle); e2e `signals.spec.ts`: a no-show appears on an open `/field` without navigation, text "Klientin öffnet nicht", link, no client name, no overflow at phone width. `/team` and OPS1 render the same banner (`team-client.tsx`, `operations-client.tsx`); the e2e covers `/field` only, as the criterion asks |
| SIG1-4 "Ich übernehme": audited, idempotent (`duplicate`), others see "übernommen von", signal stays open; non-recipient `rejected` | met | `public.take_signal`; pgTAP 062 ok / duplicate (same key and colleague) / not_recipient / coach rejected / ended_at stays null / audit row with command `take_signal`; e2e: the other open page shows it taken |
| SIG1-5 untaken after `signal_untaken` (15 min PROVISIONAL) → Operations once; stricter only | met | 0060 rule row (`delay`, 15 minutes), loop sets `escalated_at` once; pgTAP 062: 30 → `out_of_range`, 0 → `ok`, untaken → "904=untaken", taken before → none |
| SIG1-6 AN2 measure 10: share taken, median minutes to take, per team and organisation, AN1 suppression | met | 0060 patch of `pilot_hypotheses` (`signal_taken_share`, `signal_minutes_to_take`, grouping sets team/org, never per nurse); pgTAP 062 rows and suppression; 059 measure count 35 → 37 |
| SIG1-7 negative: coach, removed member, client or partner account receive nothing; RLS across organisations | met | pgTAP 062 coach receives nothing, removed member (also as responsible) not a recipient, RLS "only rows addressed to her", no insert privilege, anon no select; client and partner accounts are never team members (recipient rule) |
| SIG1-8 pilot precondition in `CARE_OPERATING_MODEL.md` | met (PO text, 2026-10-24); extended this cycle for look-ahead hours (CGR-41 point 3, SIG2-6) | `docs/product/CARE_OPERATING_MODEL.md` go-live condition |
| SIG1-9 thresholds read from `effective_exception_rules`, no second copy | met | `evaluate_signals` joins `private.effective_exception_rules`; pgTAP 062 "with the stricter effective rule the 30-min visit is P1 and delivered" |
| Test-expectation changes (019, 039, 059, 061) | checked, no assertion weakened | counts 17 → 18 and 35 → 37, lists gain `signal_untaken`; same assertions |

**Deviations (decided by the PO):**
1. *An absent member, also the responsible one, gets no delivery* — **accepted.** An absent member cannot act; delivering to her makes the signal look delivered while nobody can take it. ABS1 already hands her day to the team, and when nobody of the team is present the Operations fallback applies (pgTAP). The brief's "responsible always" is replaced by "responsible when present".
2. *`visit_uncovered_hospital` delivered as "Einsatz ohne Zuständige"* — **accepted**: the brief's fixed-text list has no separate text; the kind is the same.
3. *`cover_without_access` not delivered* — **accepted for now, as a COVER1 enablement condition**: it was not in the brief's list, and cover is switched off. Before COVER1 is switched on for any organisation, `cover_without_access` (P1) is delivered like the other kinds, to the covering member and the owning team (with CGR-21). Recorded on COVER1.
4. *Operations = role `operations`; admins only if none; coach never* — **accepted**: matches the brief (coach receives nothing) and gives an organisation without Operations a named fallback.
5. *`signal_untaken` as a row in `exception_rules` (unit `minutes`)* — **accepted**: one place for operating rules, ADM1 range guard applies.

**Note for `cra` (not a condition):** for a covered visit the covering member is a recipient but her own team is not; CGR-21 asks that alerts of a covered visit reach "the covering nurse and her team". This stays a COVER1 enablement condition (COVER1 is off), not a SIG1 gap.

**Business value and care model.** The P1 now goes to named people in their own tool, one of them takes it in one tap, and AN2 shows how often and how fast. That is the dispatcher's job done by the team and the software. **Until SIG2 the gain is limited**: SIG1-8 still needs a named watcher with a page open. **Handbook alignment:** team autonomy before central dispatch; no new service; no personal data in the new tables; the delivery row is the base SIG2 builds on.

**Result:** every criterion met in code and tests (per CI); five deviations accepted. **PO status stays `approved` (awaiting clinical review)**. Acceptance follows when a `cra` section covers 0060 without a blocking finding.
