# BK-f ADR draft (probe): invoice draft from the signed report

**Date:** 2026-11-20 06:10 CET · **Status:** PROPOSED (probe draft, `eng` input for the PO package contract; not an ADR in `DECISIONS.md` yet, no code on a feature branch) · **Owner:** `eng` · **Block:** BK, slice BK-f (named «next» in *Active now* 2026-11-20 05:39; **not active** until the PO writes the contract, FE-095) · **Reads:** BK brief BK-9, BK-9n, BK-10, CGR-210 (a)–(c), AUT-119 (a)–(c), amendment (e) on surcharges, G-6 least privilege; FE-078, FE-080, FE-084 R-12, D-44; ADR-038/040 (J5), ADR-191, ADR-202; PO hypothesis H-BK-05:39.

Nothing below sets a tariff, a surcharge, a rounding rule, a tolerance or a legal rule. Where the build needs a value, the draft names the owner and uses a **synthetic test parameter** in a configuration row (pattern of AUT-152, 0153).

## 1. Finding before BK-f: BKF-F1 (J5 generation reaches BK take visits)

- **What the code says (IMPLEMENTED, read on `recovery/main` `6dc0670`):**
  - 0138 writes a take visit with `case_id = null` (`private` take-visit writer, line 84–90).
  - 0051 `public.generate_billable_facts(month)` loops over every `final` report of the caller's team in the month, with no filter on `order_take_id` or `case_id`, and calls `private.build_billable_fact`.
  - `build_billable_fact` reads `public.cases` by `v.case_id` (null → empty row), computes KLV category minutes and tariff versions, and inserts into `public.billable_facts`, whose `case_id` is `not null` (0022).
  - The team page `/team` calls `generate_billable_facts` (`src/features/billing/commands.ts`).
- **Expected effect (UNKNOWN until run):** once a carer of the take team signs a take report that becomes `final`, «Abrechnung erzeugen» for that month on `/team` fails for the whole month (SQLSTATE 23502), and the J5 preview of that team stops working. If a helper raises earlier, the SQLSTATE differs; the month still fails. Synthetic data only; the J5 preview is a revenue estimate, not an invoice; no patient-safety effect.
- **Why it matters for BK-f:** the KLV-modelled J5 path must never touch a BK shift (D-44, BK-10: «no KVG/KLV billing in BK»). BK-f needs its own path, and the J5 path must skip take visits explicitly.
- **Red reproduction (written, NOT run):** `supabase/tests/database/154_probe_bk_f_j5_caseless_visit.test.sql` on the unmerged branch `probe/bk-f-j5-caseless-20261120` (`910b5ed`). It has not run anywhere: this session has no Supabase stack or pgTAP, and probe branches get no CI without a PR. 
- **Proposal (decision for `po`, WHEN):** either (a) the first commit of the BK-f package shows this test red in CI, then patches `generate_billable_facts` and `build_billable_fact` to skip `order_take_id is not null` (and `case_id is null`) with a reason; or (b) the PO names it as a safety fix in *Active now*, and `eng` delivers it as its own small PR with the same test. `eng` recommends (a): there is no real data and the effect is a failed estimate, not a wrong amount.

## 2. Proposed shape of BK-f (HOW; the PO decides WHAT and the cut)

### 2.1 Cut proposal (two parts, one branch `feature/bk-f`, one PR per part)

- **BK-f1 price:** AUT-119 (b): team standing price per hour, optional client ceiling per order, snapshot at «Übernehmen». It touches the BK-b filter and the BK-c take, so it is its own part with its own `cra`/`uxa` lines.
- **BK-f2 invoice draft:** BK-9, BK-9n, BK-10, CGR-210 (a), (b), BKF-F1 fix, client read, H-BK-05:39 one-tap confirm.
- If the PO prefers one PR, both fit one migration pair; the estimate in §6 is for both.

### 2.2 Data model (new, additive; RLS on, no direct grant to app roles, audit trigger, idempotent)

- `public.team_prices`: `team_id`, `price_per_hour numeric(8,2) check (> 0)`, `currency text check (= 'CHF')`, `valid_from`, `set_by`, `set_at`. Append-only; the current price is the newest row. Written only by `set_team_price(...)` (team lead role as today's team settings; the role is the PO's choice). Seed: one synthetic example value per test team, labelled «Beispielwert, kein Tarif» (FE-078 (3), UWG Art. 3). NAVORA never ships a reference value.
- `public.partner_requests.price_ceiling_per_hour numeric(8,2) null` (client, optional, empty by default; AUT-119 (b)).
- Engine 1: a team whose current price is above the ceiling fails a new hard step with the reason code `price_above_ceiling` (fact, not a choice; AUT-133). Ranking unchanged.
- `public.order_takes.price_per_hour_snapshot numeric(8,2)` and `price_id`: copied at `take_order` in the same transaction; never updated (the client confirms nothing after the take).
- `public.team_invoice_drafts`: `organization_id`, `team_id`, `client_account_id`, `order_id`, `order_take_id`, `visit_id`, `report_id` (the `final` version it was built from, CGR-210 (a)), `report_snapshot_hash`, `ordered_minutes`, `recorded_minutes` (exact, from the signed snapshot, never live times, CGR-03), `price_per_hour` (from the take snapshot), `amount_chf numeric(10,2)`, `state text check (state in ('draft','confirmed','sent','void'))`, `void_reason`, `confirmed_by/at`, `sent_at`, `superseded_by`. Unique: one non-void draft per `order_take_id` (BK-9n «second invoice refused»).
- **What the table must not have (negative schema test):** no column matching `commission|percent|fee|navora_|iban|payment|paid`. The NAVORA subscription lives in its own ledger (not built in BK-f; FE-078, three separate revenue streams).

### 2.3 Commands and rules

- `build_team_invoice_draft(p_take_id)`: called by the team (or by a trigger when the take report becomes `final`; the PO chooses: trigger = zero taps, command = one tap more). Refuses with a visible reason, never silently:
  - report not `final` → `not_signed` (BK-8n holds);
  - a non-void draft exists → `already_drafted`;
  - recorded vs ordered disagree → `times_disagree` (BK-9n). **«Disagree» needs a value** (exact equality fails almost every real shift by seconds): a configuration row `invoice_time_tolerance_minutes` with a synthetic test parameter, owner `po`/`lca` before real data (OPEN). Proposal for the meaning: the draft uses the **recorded** minutes when inside the tolerance, and is refused outside it; the team then corrects F3 or writes to the client.
  - open quality hold on the visit → `on_hold` (BL-8 pattern).
- `amount_chf = recorded_minutes / 60 × price_per_hour`, kept exact to 2 decimals with `round(..., 2)`. **Rounding to 5 Rappen or to time units:** OPEN (`lca`, D-18 for later); not built.
- **Surcharges:** none (BK brief (e), OPEN for `lca`). The draft shows the line «Keine Zuschläge (noch nicht geklärt)» only if `uxa` wants it.
- **Correction voids the draft (CGR-210 (b)):** a new `final` version superseding the report sets the draft to `void` (`report_corrected`) in the same transaction; a new draft may then be built. A `sent` draft is also voided and the team sees «Korrektur nach Versand: dem Auftraggeber eine korrigierte Rechnung senden» (wording `uxa`/`lca`).
- `confirm_team_invoice_draft(id)` and `mark_team_invoice_sent(id)`: team members of the take team only. «Versandt» means the team says it sent it (PDF download or the client reads it in the portal); NAVORA moves no money and holds no account (R-12). No payment integration, no QR-bill (it would need the team's IBAN, which is an account number: `lca`, later).
- `client_invoices()`: `SECURITY DEFINER`, `search_path = ''`, filters on the caller's `client_account_members`; returns only `sent` drafts of the caller's account: date, hours, price, amount, team name, state. No member name unless `lca` (UXR-191 (3)); no tag on a private-person invoice unless `lca` says so (CGR-210 (c)).

### 2.4 Least privilege (G-6, PO direction «at BK-f at the latest")

- **Fact (IMPLEMENTED):** 0022 grants `select` on `tariff_rates` and `billing_rules` to `authenticated` with policy `using (true)`. A client-only user can therefore read the KLV reference rows today.
- **Proposal:** in the BK-f migration replace the policy by «member of an organisation» (`private.is_org_member(...)`-style check for any org), so client-only accounts read no tariff, billing or exception configuration row; pgTAP permission test as a client user. Same review for `report_draft_stop_rules` and the new `invoice_time_tolerance_minutes` row.

### 2.5 Views and data flow (FE-095 (1))

| View | Works after BK-f | Data in / out | Still missing |
|---|---|---|---|
| `/field` (carer) | unchanged; after «Bericht unterschreiben» a line «Rechnungsentwurf für das Team erstellt» (or the reason it was not) | reads draft state of her take | nothing new to type (goal: 0 extra taps) |
| `/team` (team) | list «Rechnungsentwürfe»: hours, price, amount, reason if refused; «Bestätigen und senden» one tap (H-BK-05:39) | writes confirm/sent | PDF layout (`uxa`), team price form (BK-f1) |
| `/order` (client) | «Rechnungen» list, read-only | `client_invoices()` | download as PDF (PLANNED), dispute flow (OPEN) |
| `/platform` (operator, PR #1541 if merged) | counts only: drafts built, sent, refused by reason; never amounts (FE-078) | aggregate function | — |
| J5 `/team` Abrechnung | unchanged for cases; skips take visits (BKF-F1) | — | — |

Sector difference: home, nursing home and hospital use the same tables; `client_accounts.client_kind` (home, hospital_ward, household; 0129) only changes wording (configuration), never the record.

### 2.6 Tests the contract should name

- **Positive (pgTAP):** final take report → one draft, minutes from the signed snapshot, price from the take snapshot, amount exact; confirm and sent by a take-team member; client reads its sent draft.
- **Negative (pgTAP):** unsigned or `signed`-awaiting-countersign → `not_signed`; second draft → `already_drafted`; outside tolerance → `times_disagree`; open hold → `on_hold`; correction → old draft `void`, new one allowed; schema has no commission/percent/payment column; J5 generation skips take visits (BKF-F1, red first); team above ceiling excluded with `price_above_ceiling`.
- **Permission (pgTAP):** another team, another organisation, the client before `sent`, another client account: nothing; client-only user reads no `tariff_rates` row (G-6).
- **e2e (Playwright, 390 px):** carer signs → team sees draft → one tap «Bestätigen und senden» → client sees it in «Rechnungen». Measure (Q8): taps from «Bericht unterschreiben» to «Rechnung versandt».
- `ci-repeat` 10/10 on the integrated commit as for every slice.

### 2.7 AI label

Every function in BK-f is a **fixed, checkable rule**. No model is used; no AI proposes an amount or a time (AI never invents billing facts). Nothing here is a test substitute for AI.

## 3. Gates and review questions

- **`lca` (mandatory):** (1) Is «invoice from the team to the client, drafted by software, sent by the team» compatible with R-12 and the Genossenschaft structure (who is the invoicing party: team cell or cooperative, G-3)? (2) Surcharges and the ArG night definition (amendment (e)). (3) Rounding and time units. (4) Mandatory invoice content in CH (VAT status of a team: UNKNOWN; MWST number field?) — `eng` builds no VAT line until answered. (5) Member name and tags on a private-person invoice (CGR-210 (c), UXR-191 (3)).
- **`cra`:** the invoice is built only from the signed version; a correction voids it; a quality hold blocks it. No clinical rule involved.
- **`uxa`:** draft list and one-tap confirm at 390 px; wording of refusal reasons; client «Rechnungen».
- **`aia`:** none required (no model); `aia` may confirm the «fixed rule» label.

## 4. Innovation answers (FE-096 engineering point 2)

- **Steps that disappear:** the manual invoice entirely; the carer types nothing after signing; the team taps once.
- **Double documentation avoided:** times come only from F1–F4 via the signed snapshot; the price only from the take snapshot.
- **Earlier help:** the time-disagreement reason appears on `/field` at signing, while the carer still remembers the shift, not at month end.
- **Mobile limits:** none new; the PDF is generated server-side on demand, not on the phone.
- **Safe operation:** amounts are numeric with checks; every state change audited; counts-only platform view; the configuration rows are owner-set and audited.
- **Distinguishing idea (proposal for later, not BK-f):** an invoice that carries its own proof: each line links (for the client) to the signed report version hash and the recorded times, so a home's accounting can check an invoice without asking anyone. This is what a temporary agency's invoice cannot offer.

## 5. Dependencies

- PO contract (FE-095); `lca` answers (1) before the client sees an invoice, (2)–(4) may stay OPEN with the shown limits.
- Builds on the accepted BK-c take and BK-e report (`8155ac6`). PR #1541 (`/platform`) only for the counts view; if not merged, that row waits.

## 6. Estimate (ESTIMATE, not a commitment)

BK-f1 about 3–4 hourly runs; BK-f2 about 5–7 hourly runs including CI rounds; plus gate rounds. Migrations: two (0154 BK-f1, 0155 BK-f2), both additive; staging effect only through the CI `staging` job (ADR-190).
