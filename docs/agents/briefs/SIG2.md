---
id: SIG2
title: Safety signals reach the nurse's phone, so nobody has to keep a page open
author: po
status: approved
updated: 2026-10-24
---

# SIG2 — Safety signals reach the nurse's phone, so nobody has to keep a page open

## Problem
SIG1 (0060) delivers a P1 visit safety signal to named people, but only **inside** NAVORA: it reaches a nurse only while she has `/field`, `/team` or OPS1 open. So go-live condition SIG1-8 still needs a person with a page open for every planned hour: the screen-watcher NAVORA wants to remove, now in a smaller form. D-32 (decided by the PO 2026-10-24 09:12, option B narrow variant) sets the channel: web push through Google and Microsoft push endpoints only. CGR-41 (`cra` 10:26, advisory S2) found three gaps in that recipient rule; `lca` 10:47 checked them.

**Why does this workflow exist?** Someone watches a screen because the software cannot tap the right person on the shoulder. From scratch: the responsible nurse's phone vibrates; if she is not working, a colleague who is; if nobody is, Operations sees it at once. And a signal that can be foreseen (an uncovered visit tomorrow morning) is raised while people are still working, not at 03:00.

## Users and journey step
Nurses and care assistants of the visit's team (responsible member first), Operations as fallback; Planning → Visit (SIG1 safety signals).

## Outcome
A member who opted in receives one fixed, content-free push message for each P1 delivered to her within her planned working time; her team sees whose outside delivery works; a P1 with nobody to reach outside the app goes to Operations at once; foreseeable look-ahead P1s are raised inside watched hours. SIG1-8 can be lifted later on evidence (Clinical Owner), not before.

## Acceptance criteria
Product decisions: D-32 (po 09:12) and CGR-41 points 1-3 (po 2026-10-24 11:09, recorded in D-32). No threshold, priority, response duty or response time is set here (D-28, `clinical`). SIG1 rules unchanged.

- [ ] **SIG2-1 Opt-in and vendors.** A member can switch on "Benachrichtigung ausserhalb der App" in her own settings. Before the switch, she sees the member information text (DSG Art. 19): what is sent (one fixed text, no client data), when (P1 signals within her planned working time), through which vendor and country (Google LLC or Microsoft Corporation, USA), and how to switch it off. A subscription is stored **only** if its push endpoint belongs to Google (FCM) or Microsoft (Windows push), by an allowlist of endpoint hosts; any other endpoint (Apple, Mozilla, other) is not stored and she is told "auf diesem Gerät nicht verfügbar, du erhältst Signale in der App" (D-33). Switching off deletes the subscription. pgTAP/unit: an Apple or Mozilla endpoint is refused and nothing is stored; a Google endpoint is stored; switching off removes it.
- [ ] **SIG2-2 Test delivery and status.** Opting in sends one test message at once and records its send result. `/team` shows per member "Benachrichtigung ausserhalb der App: aktiv / nicht aktiv" (active = a stored subscription whose last send did not fail). No other member data is shown.
- [ ] **SIG2-3 Switch-on condition (fact check, D-32 item 1).** The channel is off per organisation by default and can be switched on only by an administrator in `/admin`. The SIG2 PR records the official Swiss-U.S. DPF list entries of Google LLC and Microsoft Corporation with status *active* and the date read; if either is not active, its endpoint hosts are not in the allowlist. Nothing is sent for an organisation that has not switched on.
- [ ] **SIG2-4 Outside recipients (D-32 item 2).** For each SIG1 delivery row, a push is sent when the recipient has an active subscription and is **within her planned working time**: the responsible member always when present (SIG1 deviation 1); a team colleague only within the span from the planned start of her first visit that day to the planned end of her last visit that day (Zurich time). Outside that span she receives the signal in the app only. Each delivery row records the outside result: `sent`, `failed`, `not_active`, `outside_working_time`, or `no_outside_recipient`. pgTAP: a colleague inside her span → `sent` (or the test transport's result); outside her span → `outside_working_time`; no subscription → `not_active`.
- [ ] **SIG2-5 Nobody reachable outside the app → Operations at once (CGR-41 point 1).** When, for a new P1 episode, no recipient gets `sent` (or every send fails), the signal is shown to Operations at once as untaken (an `untaken` delivery, without waiting for `signal_untaken`), and the signal records "kein Empfänger ausserhalb der App". pgTAP: an uncovered hospital-discharge visit whose window opens when no colleague has a planned visit that day → zero outside recipients, the row says so, Operations has the delivery immediately; a colleague inside her span → no immediate Operations delivery.
- [ ] **SIG2-6 Foreseeable signals inside watched hours (CGR-41 point 3).** The organisation records its **watched hours** per weekday in the operating rules (`/admin`; the hours SIG1-8 names in the pilot plan). A look-ahead P1 (`visit_uncovered_hospital`) whose window would open outside the watched hours is raised at the **end of the last watched period before the window opens**, i.e. earlier, never later than the effective rule. With no watched hours recorded, nothing changes. pgTAP: watched 07:00-20:00; an unassigned hospital-discharge visit at 08:00 tomorrow (window opens 08:00 today, inside) → as today; one at 22:00 tomorrow whose window opens at 22:00 today (outside) → raised by 20:00 today; with no watched hours → raised at 22:00 as today.
- [ ] **SIG2-7 The untaken step (CGR-41 point 2).** After `signal_untaken`, the step goes to Operations (SIG1-5 as built), outside the app only to Operations members who opted in. **There is no outside step to the whole team** (`lca` 10:47: an expectation to react outside planned working time is in substance Pikett; unresolved). The text in `/team` says so.
- [ ] **SIG2-8 Content and records.** The push payload is one fixed text, the same for every organisation and message: "NAVORA: Ein Sicherheitssignal wartet auf dich." and a link to `/field` (no visit ID, client name, address, visit time or health data in payload or URL). Send time and result are stored on the delivery; a tap on the message opening NAVORA is recorded; **display on the device is never claimed**. Unit test: the payload equals the constant; pgTAP: no free-text column on the push tables.
- [ ] **SIG2-9 Negative cases.** No push for P2/P3, for a removed member, a coach without team, a client or partner account, an organisation with the channel off, or across organisations (RLS); subscriptions are readable only by their owner (RLS, pgTAP); the server secret for sending (VAPID private key) is never sent to the client and never committed.
- [ ] **SIG2-10 Evidence.** AN2 measure 10 gains, per team and organisation (AN1 suppression), the share of P1 signals with at least one `sent` outside delivery and the share taken within the `signal_untaken` threshold. These are the facts the Clinical Owner needs to end SIG1-8; the threshold is the Clinical Owner's.

## Out of scope
- Safari/iOS and Firefox (D-33, `owner`): those members stay in-app only.
- SMS, e-mail, phone calls (need a paid contract, `owner`).
- On-call (Pikett) rosters, response duties and times: the provider's policy and `clinical` (D-28, D-23, D-12). A recorded on-call person as an outside recipient is a later item once the owner names the provider's on-call policy (`lca` 10:47 point 2(c)).
- Lifting SIG1-8: a Clinical Owner decision on AN2 evidence, not this brief.

## Constraints and references
D-32 (po-decided; items 1-8), D-33 (`owner`), CGR-37, CGR-41 (`cra` 10:26, PR #278), `lca` D-32 sections 08:47 and 10:47 (ArGV 1 Art. 14-15 summary by SECO; DSG Art. 16, 19), SIG1 (0060, ADR-074), ADM1 operating rules and range guard (0059), AN1/AN2 suppression. Production: the VAPID key pair is a production secret set by the owner when staging or production exists (D-2); CI uses a generated test key and a test transport (no real push service is called in CI). No personal or health data in payloads, logs or the repository.

## Open questions for engineering
- Web-push library and how to send from the server (Next.js route vs. Edge Function vs. database job); how the writer hands a delivery to the sender without the database holding a secret.
- How to test SIG2-4/SIG2-5 deterministically in pgTAP (test transport, fixed clock as in DAY-1).
- Endpoint-host allowlist: the exact hosts used by FCM and Windows push today; how a changed host is noticed (fail closed).
- Whether SIG2-6 is better built as a shifted window in `derived_exceptions` or as an early raise in the writer; either way stricter only (ADM1-R direction).
