# BK-c3 ADR draft: ranking and reasons under the broadcast (docs only, no code change)

**Author:** `eng`, scheduled run 2026-11-17 17:12 Europe/Zurich · **Block:** BK, slice BK-c, sub-slice BK-c3 (*Active now* 16:40: BK-c in three PRs, BK-c2 #1358 waiting for the `cra` and `uxa` gate lines). BK-c2 and BK-c3 go **one at a time** (PO 03:39 (1)), so this is preparation as docs only (README rule 12): no migration, no feature PR, no change on the #1358 head. The ADR number is taken when the BK-c3 PR opens (expected ADR-201).

Every statement is labelled IMPLEMENTED (in the repository code on `recovery/main` `13c6d68`, or on the #1358 head `9a7fc56` where named), PLANNED (this draft proposes it), OPEN (needs another owner) or UNKNOWN.

## 1. Code facts this draft builds on

- IMPLEMENTED (0135): `public.team_order_offers()` returns one row per (order, own team) with an offer row in the current round, not declined by the team, and either open or taken by the own team. Columns: order facts, `distance_km`, `limit_km`, `offer_state`, `taken_member_id`. **Ordered by `starts_at`**, then ids. No rank, no reason, no other team, no count (ADR-199 (8), template §2).
- IMPLEMENTED (0129): the order lives on `partner_requests` with `client_account_id`, `starts_at`, `ends_at`, `postcode`, `grade`, `activity_tags`, `required_tags`, `radius_km`. **No price column** (AUT-119 (a)), **no language field**, no preferred-team field.
- IMPLEMENTED (0135): `order_takes` keeps every take with `team_id`, `member_id`, `taken_at`, `released_at`; a take whose slot has ended and was never released is the only stored fact on the order path that «this team has worked for this client account».
- IMPLEMENTED (0133/0135): `private.order_member_step` is the one eligibility function (AUT-130); step 2 `member_activity_ok` checks **every** activity tag of the order (not only the required ones) against the matrix and evidence. UNKNOWN until read line by line in the BK-c3 PR: whether a non-required tag is checked for evidence or only for orderability; this decides whether «hält auch …» can be a reason clause.
- IMPLEMENTED: no table holds a member's or a team's languages. A language clause has **no source** today.
- IMPLEMENTED (`#1358`, not merged): the BK-c2 card on `/team` shows the order facts and states; the «Warum empfohlen» line and the price line were placed in BK-c3 (PO 11:39 (4)).

## 2. The deviation this draft must report first (document against FE-078)

BK-3 (written for the cascade) ranks **teams** for an order: «the best-ranked team receives the offer first». FE-078 part 2 replaced the cascade by the broadcast: every eligible team sees the offer at the same time, and ADR-199 (8) and the BK-5 template forbid showing another team, a count or a rank. Under the broadcast a ranking **between teams for one order has no reader**: no team sees it, the client must not (D-44 (2) (a)), and no step waits for it. FE-078 (1) keeps the ranking as «orders the list and explains it («Empfohlen für euch, weil …»)».

**PLANNED reading (needs the PO, README rule 11; not changed silently):** BK-c3 delivers, per (order, own team), (a) a **reason line built only from stored facts** and (b) at most a **reordering of the team's own offer list**; it never ranks teams against each other in any stored or shown value. If the PO wants a between-team ranking kept for a later consumer (Operations, notification order), that is a separate item and is not built in BK-c3.

## 3. Design (PLANNED)

### 3.1 Reason clauses, each from one stored fact (BK-4, AUT-113 (2), K-2)

`private.order_offer_reasons(p_order_id, p_team_id) returns text[]` of **clause codes** (never words, never a number that reads as a score). A clause appears only when its fact exists; no fact → no clause (stop rule K-2). Candidate codes:

| Code | Stored fact | Status |
|---|---|---|
| `within_reach` | the offer row's `distance_km` ≤ `limit_km` (always true on an offer row; shown with the km value) | buildable |
| `member_free` | at least one active member of the team reaches `order_member_step = 4` now | buildable (same function, AUT-130) |
| `knows_client` | an earlier take by this team for the same `client_account_id`, slot ended, never released | buildable; the window (all time vs. a period) is OPEN (PO; `cra` CGR-196 for continuity versus distance) |
| `holds_all_tags` | every activity tag held with evidence by one member who reaches step 4 | UNKNOWN (see §1, step 2 detail) |
| `language` | none | **OPEN**: no source; adding member languages is new staff data (`lca` Annex C) and a PO scope question; not built, no clause |

Words per code: `uxa` (the existing «passt: FaGe, … frei, kennt diese Einrichtung» example in BK-4 is the starting point). Clause order in the line: fixed by code order, published.

### 3.2 Order of the team's own list

- **Proposal A (default, safest):** keep `starts_at` first (the earliest shift is read first; a fit reordering could push a near shift below a later one). The reasons only explain.
- **Proposal B:** lexicographic AUT-113 (1) inside the same start day: `knows_client`, then `holds_all_tags`, then distance, then a stable tie-break. Never a weighted sum, never a percentage.
- Choice: **OPEN, PO** (product rule; AUT-113 (1)); continuity versus distance and whether B is safe for short-notice shifts: **OPEN, `cra`** (CGR-196). `eng` builds A unless the PO decides B.

### 3.3 Price line

**OPEN, not built:** no price exists on the order (AUT-119 (a)); price setting is `lca` AUT-119 (c), and ArG night/Sunday surcharges are open (PO 17:00). BK-c3 shows no price line and no placeholder amount. If the PO wants the line in BK-c3, it waits for AUT-119 (c).

### 3.4 Read model and guards

- `team_order_offers()` gains `reasons text[]` (drop and create; return type changes, as 0135 did for `client_orders()`).
- `client_orders()` unchanged: the client reads no reason, no rank, no team count (D-44 (2) (a)).
- Engine 2 stays `kind = 'rule'` (AUT-115); no AI call, no `ai_suggestions` row in BK-c3 (stage 0, D-35 rule A).

## 4. Tests (PLANNED, red first)

- pgTAP 146: (1) each clause appears with its fact and is absent without it; (2) **AUT-128 / V-8**: the set of (order, team) rows of `team_order_offers()` equals the current-round `order_offers` rows minus declines, before and after the reasons exist (ranking or reasons never add or remove a row); (3) no `rank`, `score` or count column in the result type; (4) a member of another team sees no reason row; (5) the client reads none; (6) list order as decided in §3.2.
- vitest: clause code → `uxa` words mapping, unknown code shows nothing.
- Playwright 390/1440: the reason line on the `/team` card of the seeded Basel team that has an earlier take for the same synthetic client.
- CGR-235 (c) and UXR-229 to UXR-232 follow-up items (PO 16:40 (2)) go into the same PR if `cra`/`uxa` keep them as BK-c3 items.

## 5. Questions this draft asks (no rule set by `eng`)

1. **PO:** confirm the reading in §2 (reasons and own-list order per team; no between-team ranking stored or shown in BK-c3).
2. **PO:** list order A or B (§3.2); and the continuity window for `knows_client`.
3. **`cra`:** CGR-196 continuity versus distance, only if the PO picks B.
4. **PO / `lca`:** language as a clause needs new staff data; keep out of BK-c3 (proposal) or open a scope item.
5. **PO:** price line out of BK-c3 until AUT-119 (c) (proposal).
