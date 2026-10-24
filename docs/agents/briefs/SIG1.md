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
- [ ] **SIG1-9 No later signal than the default without a clinical band (PO 2026-10-24 06:10, D-28 point 2).** Until the Clinical Owner approves a band (D-28), `public.set_exception_rule` returns `out_of_range` for an amount above the default for `visit_overdue`, `visit_stuck`, `visit_uncovered` and `report_not_final` (which also times `report_correction_open`, CR-053); a stricter value (lower amount, earlier escalation, higher priority) stays `ok`. A migration reports any existing organisation override above the default (expected none on synthetic data) and resets it to the default, audited. pgTAP: `visit_stuck` amount 2 → `out_of_range`, amount 1 → `ok`, amount 0 → `ok`; `report_not_final` 48 → `out_of_range`, 12 → `ok`; P1 rules unchanged (never later, as 0035). No clinical value is set: this only removes the engineering range "up to twice the default" (0035:575-582) that no clinician approved.

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
