# BK-c ADR draft: broadcast take, cover state, latest coverage time, re-coverage (docs only, no code change)

**Author:** `eng`, scheduled run 2026-11-14 19:10 Europe/Zurich · **Block:** BK; slice BK-c is **not active** (*Active now*: BK-b). Preparation as docs only (README rule 12, block rule FE-054/FE-070/FE-071) · **Asked by:** `cra` 17:26 («`eng`: in the BK-c ADR, the coverage-time default, the reopen path and the take race test»), PO amendment 17:40 (owners: `eng` 1, 2, 3), PO amendment 15:00 (5) (cascade assumptions in ADR-191/193 and the BK-b migrations) · **Status:** DRAFT. Nothing here is built. It gets an ADR number when it moves into `docs/engineering/DECISIONS.md` with the first BK-c PR (that file is touched by #1270, #1273 and #1295; a docs-only append now would conflict with all three).

Every statement is labelled IMPLEMENTED (in the repository code today), PLANNED (this draft proposes it), OPEN (needs another owner) or UNKNOWN.

## 1. Code facts this draft builds on

- IMPLEMENTED (`recovery/main` `6b5bfe8`, migration 0130): `confirm_client_order` calls `private.screen_order_reach(order_id)` in the same transaction; every team of the order's organisation gets exactly one row in `public.order_offers` (`organization_id, order_id, team_id, distance_km, limit_km`) or `public.order_exclusions` (`…, reason`). Rows are written once (AUT-117 (b)).
- IMPLEMENTED (0129): `public.client_orders()` returns `cover_state = 'not_covered'` as a constant for every confirmed order (comment: «BK-c derives it from offers»).
- On PR #1273, not merged: `private.order_member_step(order, team, user)` returns 0..4 (4 = one member passes level, activity evidence valid at the slot end, availability for the whole slot); `screen_order_reach` excludes a team none of whose members reaches 4 (CGR-204 (a)).
- IMPLEMENTED precedents reused below: OPS1 derived exceptions (`private.derived_exceptions(org)`, `exception_rules`, read at query time, 0024/0125); COVER1 two-session take test as a `psql` script run by the `db` job (`scripts/db-concurrency/cover-accept.sh`); `cover_settings` with a per-organisation override and a global default row (0028: `offer_lead_hours 24`, `fallback_lead_hours 4` for visit cover); ABS1 release of a member's visits by an absence (0046/0048); pinned clock `private.now()` honouring `navora.test_now` (DST1).

## 2. Cascade check (PO 15:00 (5)) — result

- **ADR-191 (draft) assumes a cascade in two places** (`DECISIONS.md` ADR-191 decisions (4) and (6)): (4) «exact `starts_at`/`ends_at` decide filters, availability, **cascade** and invoice»; (6) «**The cascade** is a new table `matching_offer_steps` (T-3, BK-c), a generalisation of the RET1 window». Both are stale after FE-078 part 2 (README rule 10, the newer founder decision wins). PLANNED: the BK-c ADR supersedes (6): no `matching_offer_steps`, no RET1-style exclusive window (`preferred_team_id`, `first_refusal_until` stay for the referral path they serve today and are not used by orders); and reads (4) as «filters, availability, take and invoice». **ADR-193 (draft):** no cascade assumption found.
- **ADR-195 (3)**, last sentence: «BK-c adds offer state **and cascade** on these rows». This is stale after FE-078 part 2. PLANNED: the BK-c ADR states «BK-c adds take, decline and cover state next to these rows (broadcast, FE-078 (2)); no cascade». The ADR-195 text itself stays as written (accepted ADRs are not rewritten; the new ADR supersedes the sentence and says so).
- **Migrations 0129–0134** (incl. open PRs): no exclusive window, no «next team», no order between offer rows. `order_offers` has no rank or state column. The broadcast needs no change to them.

## 3. Design (PLANNED)

### 3.1 Tables (offers stay a snapshot)

`order_offers` and `order_exclusions` keep «written once». BK-c adds:

- `public.order_offer_rounds (order_id, round, opened_at, cause)`: round 1 at confirmation; a new round only when a take is released (3.4). `order_offers` / `order_exclusions` gain `round integer not null default 1`, unique `(order_id, round, team_id)`. Each round is a fresh hard screening of every team; earlier rounds are never changed (keeps AUT-117 (b) and the audit trail). Backfill: existing rows are round 1.
- `public.order_takes (id, organization_id, order_id, round, team_id, member_id, taken_at, released_at, release_reason)`; partial unique index `on (order_id) where released_at is null` (at most one live take per order, the database backstop for CGR-211). `release_reason` names a step code, never a person's data (P-5): `member_absent`, `member_access_ended`, `member_grade_not_verified`, `member_evidence_not_verified`, `member_open_visit`, `team_released`.
- `public.order_offer_declines (order_id, round, team_id, declined_at, actor)`: a decline hides the offer for that team in that round only (FE-078 (1)).
- No app write grant on any of them; RLS as `order_offers` (operations/admin of the organisation, members of the named team); the client reads none directly. Audit trigger on each; every key classified (AUD1-1).

### 3.2 Take (BK-5a, CGR-211)

`public.take_order(p_order_id, p_team_id, p_member_id, p_idempotency_key)`, security definer, `begin_command`/`end_command`:

1. `select … from partner_requests where id = p_order_id for update` (serialises every take of one order).
2. Caller is an active member of `p_team_id` (LEAVE1-3); the named member is a member of that team. Nobody takes for another team (FE-039, BK-5n).
3. The team has an offer row in the current round and no decline in it.
4. **Fresh hard re-check at that moment:** `order_member_step(order, team, member) = 4` and the team still passes the distance part of the current round. Failure → `refused` with the step code; nothing is written.
5. A live take exists → `refused`, reason `already_taken` («Bereits übernommen», words `uxa`); nothing is written.
6. Insert `order_takes`; one audit row. The partial unique index turns any path that skipped the lock into an error, never a second take.

**AUT-130 (PO 02:40 BK-c criterion; taken into this draft by `eng` 2026-11-15 03:10):** step 4 and the no-double-take rule (CGR-224) use the one function `private.order_member_step`; there is no second eligibility function for the take. The BK-c migration replaces `order_member_step` (`create or replace`, same signature) and adds one more availability source to its step 3: a live take (`released_at is null`) of the same person on **another** order whose slot overlaps `[starts_at, ends_at)`. The own order is excluded (`t.order_id <> p_order_id`), otherwise a live take would make its own member unavailable and `order_cover_state` (3.3) would show `no_longer_covered` for every covered order. Refusal reason is the step code 3, the same as for an absence or an open visit. Tests (PLANNED, red first, pgTAP): member with an accepted take overlapping the slot → `order_member_step` = 3 and `take_order` refused with step 3; member whose take does not overlap (ends exactly at `starts_at`, half-open interval) → passes; member's own live take on this order → still 4 (cover state stays `covered`); a released take → no longer blocks. This is a design rule for one code path, not a clinical rule; `cra` reads the availability sources at the BK-c gate.

Tests (PLANNED, red first): pgTAP single session (each refusal reason; ineligible member refused; take by a non-member refused; idempotent repeat returns the first result); **two-session script** `scripts/db-concurrency/order-take.sh` on the COVER1 pattern: two teams tap at the same time → exactly one live take, the loser gets `already_taken`, no second row; run by the `db` job and by `ci-repeat` (10/10 counts it).

### 3.3 Cover state (BK-6) and the offer list (H-BK-15:39 (i)–(iii))

`private.order_cover_state(order_id, at)` derived at read time (no stored state that can drift), used by `client_orders()` and by the team list:

| state | condition |
| --- | --- |
| `covered` | a live take, and its member still passes `order_member_step` = 4 at `at` |
| `no_longer_covered` | the newest take was released (3.4) and no new live take |
| `not_covered` | no live take and `at >= latest_cover_at` (3.5), or every team of the current round declined or is excluded |
| `not_yet_covered` | otherwise (offers open, before `latest_cover_at`) |

- `client_orders()` returns the state and, for `covered`, the team name only after the take (`lca` G-3 (2), G-5 (e) first-name rule stays OPEN for real use); never a reason or a member before the take.
- Team list (a new team read function; today no app code reads `order_offers`, only the generated types): an order is shown to a team with an offer row in the current round, no decline by that team, and **no committed live take** (reads see committed rows only, so (i) holds by construction); after a release the next round lists it again for every team that passes (ii); after `latest_cover_at` an untaken order stays in every eligible team's list **and** in the Operations exception (iii). Count «noch bei n Teams offen» = offer rows of the round minus declines (BK-6 as adjusted 15:00 (4)).
- Operations exception: new `exception_rules` type `order_not_covered` (derived, as `case_reopened_no_team`), raised when the state is `not_covered` or `no_longer_covered` at or after `latest_cover_at`; ordered by time to start (CGR-215 (c)), never last for empty urgency. Closes only with its cause (a live take, the order withdrawn by the client, or the start passed and the order closed by Operations).

### 3.4 Re-coverage when the named member drops out (CGR-223 (a)–(c), PS-191)

The release follows the ABS1 pattern (an absence releases a member's visits): triggers on the events that can make a passing member fail before `starts_at`:

- `member_absences` insert/update (absence overlapping the slot, in any team, ABS1-C3);
- access end (a LEAVE1 `member_access_events` row of kind `ended`, read by `private.access_ended`);
- grade or activity evidence changed, revoked or shortened so that it is not `verified` at the slot end;
- a new open visit she is responsible for or covers overlapping the slot.

Each calls `private.recheck_order_takes(member_id)`: for every live take of that member with `starts_at > private.now()`, run `order_member_step`; if < 4: set `released_at`, `release_reason` (step code), open round n+1 with a fresh `screen_order_reach` of **every** team (the releasing team included if another member passes), one audit row. Evidence that simply runs out before the slot end is already refused at the take (step 2 checks validity at `ends_at`), so no timer is needed for it. Safety net: `order_cover_state` re-runs the member check on every read, so a missed trigger path shows `no_longer_covered` on the next load instead of a false «gedeckt» (the release row is then written by the next command or by the trigger; the gap is reported as a test, not hidden).

The team may name another member who passes: `public.change_take_member(order, team, new_member, key)` under the same lock and re-check; no one outside the team assigns (FE-039).

Tests (PLANNED, red first, as asked in 17:40 (2)): pgTAP take with member M → absence for M overlapping the slot → state `no_longer_covered`, round 2 rows for the passing teams, client sees it; separately M's grade evidence revoked so that it is not verified at the slot end → same; access ended → same; an absence not overlapping the slot → still `covered`; after `latest_cover_at` the release also raises the exception.

### 3.5 Latest coverage time (CGR-222, CR-224, PS-192)

- `latest_cover_at = starts_at - latest_cover_lead`; the exception and `not_covered` are raised **before** `starts_at` (CGR-222 (b): the client is told before the start, not at it).
- **Simulation default (PROPOSED, eng, not a clinical rule):** `latest_cover_lead = 4 hours`, the same value already in force as `cover_settings.fallback_lead_hours` for visit cover (0028), so NAVORA has one lead time for «nobody holds this yet», not two. It is a value for the synthetic Phase A only; CR-224 lists it PROPOSED; the **Clinical Owner confirms or replaces it before real data (K-8; OPEN)**. Stored as a new column `order_latest_cover_lead_minutes` in `cover_settings` (global row + organisation override), not readable by a client-only user (PO 00:39 (6)).
- Short notice: an order confirmed when `latest_cover_at` is already past raises `not_covered` and the exception at once, while the offers still go out (CGR-222 (c)).
- Tests (pinned clock): one minute before `latest_cover_at` → `not_yet_covered`, no exception; at `latest_cover_at` → `not_covered` plus exception, and `latest_cover_at < starts_at`; short-notice order → both at confirm.

### 3.6 Orders confirmed before the BK-c migration (CGR-215 (b))

Derived state covers them: they have round 1 offer/exclusion rows (if confirmed after 0130) or none (confirmed between 0129 and 0130). The migration screens every confirmed, future, untaken order that has no round 1 rows (one round 1 written by the migration, idempotent: only where none exists). Red test: an order inserted before the migration's backfill is either offered or raised as `order_not_covered`; none stays `not_yet_covered` with no team and no exception.

## 4. Open points for other owners

- OPEN `uxa`: words for `not_yet_covered`, `not_covered` before the start, `no_longer_covered`, «Bereits übernommen», «noch bei n Teams offen».
- OPEN Clinical Owner (K-8): the lead value; whether «D» on a shift order changes the member step (CR-180).
- OPEN `lca`: whether the count «noch bei n Teams offen» shown to the client discloses anything about teams (H-BK-14:39); default in this draft: the count is shown to Operations and teams, the client sees only the state.
- OPEN `aia`: answers to H-BK-15:39; Engine 2 ranking orders the list and never removes an eligible team (FE-078 (1)) — ranking is not part of this draft.
- UNKNOWN: whether the trigger set in 3.4 covers every path that changes evidence state; the BK-c PR lists every writer of the evidence tables before it is built.

## 5. Order (PLANNED)

BK-c starts only when the PO names it in *Active now*. Then: red pgTAP and the two-session script first (alone, CI red as intended), then the migration, then `client_orders` / team list / Operations reads, then the UI. One PR per part if the PO wants smaller gates; gates `cra` (CGR-211, CGR-222, CGR-223, H-BK-15:39), `lca` (G-3, payload), `uxa`, `aia`.
