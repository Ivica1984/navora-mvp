---
id: ORDER-F1
title: The client order list stays loadable as orders grow; a slow list never breaks /order
author: po
status: approved
updated: 2026-11-26
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

## PO merge note (2026-11-25 23:39 CET, scheduled run)

Merged #1760 at head `d634d9a` → `992a7e3c`. Not yet accepted. The PO ran no tests locally; evidence is from CI raw logs and the ready report 7176298540.

| criterion | result | evidence |
|---|---|---|
| Equivalence (safety) | met on head | pgTAP 178 (21 assertions, lemmas, function equivalence frozen vs new); `db` 139544530770 «Result: PASS» |
| Budget ≥ 1 000 orders | met on head | 2 120 ms for 1 000 orders (ready report; target set by `eng` < 4 s) |
| Isolation | met on head | pgTAP 135/147 unchanged green; 178 one assertion |
| T-1 «sent = shown» | met on head | `bk-a-order.spec.ts` green in `e2e` 139544531663 |
| T-2 list-only error | met on head | `order-f1-list-degrade.spec.ts` 390/1440 px green |
| `staging-smoke` paths 1–7 on merge commit, no `57014` | partly met (2026-11-26 00:39) | 0178 applied to `navora-staging` by `staging` job 139573817375 (run on `0accd105`, contains `992a7e3c`: «Applying migration 20261021000178…», «Finished supabase db push»); `staging` job on `992a7e3c` then «Remote database is up to date». Smoke 45715319587 on `992a7e3c`: red at sign-in, Render switched `0accd105`→`89fe091e` during the run (deploy swap, warning in log), no app finding. Smoke 45719590699 attempt 2 on `89fe091e` (contains ORDER-F1, later commits docs only): Render served `89fe091e` before and after; **paths 1–6 green** (incl. path 1 `/order` order listed, path 6 `/order` «Zurückgezogen»); **path 7 red** at line 483 as before (`heim-draft-summary` not found), screenshot artifact 15072658034. `57014` check in the Render log: OPEN (`eng`). |
| `staging-smoke` paths 1–7 on the integrated commit, `ci-repeat` 10/10 | met (2026-11-26 09:39) | `staging-smoke` 45779137337 (job 139770939063) on `217a9a58` (contains ORDER-F1, F2, F3, F5), Render served `217a9a58` before and after: «8 passed». `ci-repeat` 45781858795 on `217a9a58`: 22/22 `success`, PO read all 20 raw logs (`db` «Files=178, Tests=7060», «Result: PASS» ×10; `e2e` «227 passed» ×10). `57014` in the Render log: met 2026-11-26 11:39 (next row). PO did not run tests locally. |
| No `57014` on `/order` in the Render log (as read by `eng`) | met (2026-11-26 11:39) | `eng` [#1780 7188943285](https://github.com/Ivica1984/navora-mvp/pull/1780#issuecomment-7188943285), read-only with founder approval for the workspace: positive control 6 × `orders.load_failed` `57014` on 25.11. 19:55–20:06 UTC; ORDER-F1 live 22:42:39 UTC (`dep-dc3m80g473hc738htocg`); none after, window to 26.11. 09:45 UTC; no `error`/`warn*`/`fatal` in the green smoke window on `217a9a58` (`dep-dc3ucjl9el5s73aopga0`). Not read by the PO in Render itself. |
| No test skipped or weakened; CI green on head | met | diff read by the PO; all check runs `success` |

Freeze of past orders: not done (inputs can change after end, ready report); brief rule held. Follow-ups: STG-SMOKE-1-F2, ORDER-F1-F1.

## PO acceptance 2026-11-26 11:39 (scheduled run, signal (d))

**Accepted for the simulation** (gate «Simulation, synthetic data») together with HD-3a, on the named commit `217a9a58` (ORDER-F1 incl. F2, F3, F5). All rows of the table above are met. Record: `docs/product/ABNAHMEAKTE.md` §2 «HD-3a … mit ORDER-F1». Probable, not proven: F2 and F3 removed the two team `57014` entries of 26.11. 00:15 UTC. Follow-ups (not conditions): ORDER-F1-F1, ORDER-F1-F3-UX, ORDER-F1-F4, ORDER-F1-F6, AUT-220 (brief `AUT-220.md`), STG-SMOKE-3, STG-OBS-1 (needs a Render API key as a GitHub secret; founder decision). Fixed rules only; no AI model. The PO did not run tests locally.
