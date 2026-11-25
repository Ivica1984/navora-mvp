---
id: ORDER-F1
title: The client order list stays loadable as orders grow; a slow list never breaks /order
author: po
status: approved
updated: 2026-11-25
---

# ORDER-F1 — The client order list stays loadable as orders grow

Order: PO decision 2026-11-25 21:39 (scheduled run, signal (d) #1754). Block HEIM-DP stays the frame. ORDER-F1 is a technical package like PERF1 and is brought forward under the exception of FE-089 (3) («documented, substantial … function defect in the agreed flow»): it blocks the HD-3a acceptance path (`staging-smoke` green incl. path 7). One Engineering PR (`fix/`). Source: `eng` post-merge report #1754 (comment 7173365770) and journal `2026-11-25-2140-eng.md`; first named 2026-11-24 11:39 (PO journal, #1694 7126590724). The PO ran no tests and read no database.

## Problem

IMPLEMENTED state, as measured by `eng` (read-only `EXPLAIN ANALYZE`, warm, staging):

- `public.client_orders()` calls `private.order_client_state` once per order; about 22 ms per order; 225 orders for the demo client = 4.95 s.
- The `authenticated` statement timeout is 8 s. Two parallel renders on the free tier already cross it (`57014`, logged on `/order` at 19:55:10 UTC ×2 and four more times during the next, green run).
- When the list read times out, the re-render of `/order` throws as a whole: after a successful order the client does not see their order (`staging-smoke` 45687575702, path 1 red, order `02771b65` written but not listed).
- Cost grows linearly: each smoke run adds 3–4 orders. `eng` estimates a single warm load fails at about 360 orders (estimate, not measured), i.e. within days. Then `/order` no longer loads for the founder's demo client and smoke paths 1–6 fail permanently.
- This is a client-facing availability defect: a client who cannot see whether their order is «Gedeckt» or «Noch nicht gedeckt» may assume a shift is staffed when it is not. Any home with months of orders reaches the same limit.

## Users and journey step

Client (nursing home, private person) on `/order` (Referral and Case steps; reading cover state); the founder and every reviewer (staging as proof of delivery).

## Outcome

`/order` always renders after a successful command; the order list stays well below the timeout as orders grow; and when the list read still fails, only the list says so and the order form stays usable.

## Scope (PO decision; HOW is `eng`'s)

(a) **Database.** The cover reading for the client list becomes set-based, or otherwise no longer costs one full cover computation per order. Freezing the state of past orders is allowed **only** if the ready report names every input of `order_client_state` and shows that none can change after an order's end; if any can, no freeze. Delivered as a full `create or replace` from the STAB1 sources (`supabase/schema/functions/…`, TESTS 6), keeping `security definer`, `search_path ''`, grants and the LEAVE1 `access_ended` guard.

(b) **App.** A timed-out or failed list read shows only in the list: «Aufträge konnten nicht geladen werden, bitte neu laden» (PERF1 pattern for `/field`); the form and the rest of the page stay usable. Never an empty list that looks like «no orders».

(c) **Smoke.** `staging-smoke` uploads the Playwright `test-results` on red (STG-SMOKE-1-F1, taken in here), so the open path-7 last-step cause can be read on the next red.

## Acceptance criteria

- [ ] **Equivalence (safety).** pgTAP: for a fixture covering every state the current function can return (as named in the code, e.g. «Gedeckt», «Noch nicht gedeckt», «Zurückgezogen»), past and future orders, and `access_ended`, the new reading returns exactly the same rows and states as the current function. A red-before test is not needed for an equivalence test; the guards test must fail if a guard is removed.
- [ ] **Budget.** A `db` test or measurement names the cost for at least 1 000 synthetic orders for one client and shows it well below the 8 s timeout (number in the ready report; target set by `eng`, reported, not invented by the PO).
- [ ] **Negative: isolation.** A client still sees only their own orders; another client, a team or a carer outside the order sees none (existing pgTAP kept green, not weakened).
- [ ] **T-1 «sent = shown».** After a successful order the new order is visible in the list (e2e).
- [ ] **T-2 «one wrong, interrupted or double step».** A failed list read (simulated) shows the list-only error, the form stays usable, no whole-page error (e2e at 390 px).
- [ ] `staging-smoke` on the merge commit: paths 1–7 green, no `57014` on `/order` in the Render log for that run (as read by `eng`).
- [ ] No test skipped or weakened; all CI jobs green on the reported head.

## Rules and their input class

No new rule. The cover state is a *visit/schedule fact*; its meaning must not change (equivalence criterion). No clinical content.

## AI leverage

No AI leverage: this is a performance and availability fix of a deterministic reading. Removed work: the client no longer re-loads or phones to ask whether an order arrived. AI honesty: fixed rules, no model.

## Gates

- No paused role is needed while the equivalence test shows identical output.
- If the ready report names **any** difference in a state the client sees, the PR needs `cra-gate:` on its head (cover state as safety display) before merge.

## Out of scope

No new states or texts in the list beyond the error line; no change to matching, offers, takes or cover rules; no Render or Supabase setting (Free-plan wake-up is a founder setting, FE-058); no pagination redesign unless `eng` shows it is the smallest safe fix.

## Constraints and references

FE-089 (3), FE-105, FE-070/FE-071; PERF1 (`briefs/PERF1.md`, same pattern for `/field`); STAB1 (e) smoke rules; LEAVE1 `access_ended`; D-1 (synthetic data only).

## Open questions for engineering

1. Which inputs of `order_client_state` can change after an order's end (takes withdrawn later, absences, `access_ended`)?
2. Is the cover cost also hit by `derived_exceptions` or other lists for the same client (one root, or several)?
3. After the merge: does path 7 still go red at line 483? Name the cause from the uploaded `test-results`.
