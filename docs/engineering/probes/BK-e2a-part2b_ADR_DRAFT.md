# BK-e2a part 2b ADR draft (ADR-209 candidate): the AIG1 ledger entry for a model report draft (docs only, no code change)

**Author:** `eng`, scheduled run 2026-11-19 02:10 Europe/Zurich · **Block:** BK, slice BK-e, BK-e2a part 2b (*Active now* 01:39: «then part 2b (AIG1 ledger = standard S1)»). **Base:** `recovery/main` `8352425`; #1494 (`cf1b6e9`, ADR-206) and #1497 (`d254827`, ADR-207) are open and not merged, so this draft reads their code from the branches. ADR number: ADR-206, ADR-207 and ADR-208 (#1503) are taken on open branches; this becomes ADR-209 in `docs/engineering/DECISIONS.md` with the PR that builds it.

Every statement is labelled IMPLEMENTED (in the repository code on `recovery/main` `8352425`, or on the named branch head), PLANNED (this draft proposes it), OPEN (needs another owner) or UNKNOWN.

**Why a draft and not the migration this run:** the ledger is append-only with **no deletion path** (`0097` comment on `ai_suggestions`: «kept for the D-4 final period (no deletion path)»). A wrong payload shape written to `navora-staging` stays there. Three points below (§2) need the views of `aia`, `lca` and `cra` before the shape is fixed. Building around them would mean guessing a governance rule, which the agent rules forbid.

## 1. Code facts this draft builds on

- IMPLEMENTED (`0097`): AIG1 ledger `public.ai_suggestions` (one row per proposed value; `team_id`, `entity_type`, `entity_id` `not null`; `input_refs` checked by `private.aig1_refs_ok`: 1–50 objects `{table, id}` with a uuid id, «never a copy of their content»; `proposed_value jsonb` required unless `not_found`) and `public.ai_confirmations` (one row per value: `confirmed`, `corrected`, `rejected`, `not_found`; `bulk` only with `confirmed`; confirmer and time). Both append-only by trigger, RLS on with no policy, no grant to app roles (AIG1-11).
- IMPLEMENTED (`0097`): `public.ai_agent_definitions` (`kind rule|ai`, `level L|G|H`; `kind = 'ai'` needs `provider` and `region`) and `public.ai_agent_fields` (`target_table`, `target_column`, class `record` by default).
- IMPLEMENTED (`0097` `set_agent_state`): switching on an agent is refused for `kind = 'ai'` with reason `ai_not_allowed` and the text «D-35 Regel A: Kein KI-Dienst in irgendeiner Umgebung, bis der Inhaber Stufe 1 freigibt», and for level G or H with `level_not_allowed` (D-34). No environment or simulation exception exists in the database.
- IMPLEMENTED (#1494 `cf1b6e9`, #1497 `d254827`): whether the model is called is decided only in the app, by environment values (`AI_REPORT_DRAFT_MODE=model`, `AI_KILL_SWITCH`, the staging project ref, never the live project, a simulation organisation, provider, key, model name). No AIG1 table is read or written. `withLedgerGuard(…, MODEL_LEDGER_READY = false)` replaces any model provider by the rule substitute with reason `ledger_missing` (ADR-207 (3)).
- IMPLEMENTED (#1494): draft segments (`s1`, `s2`, …) and facts are ids inside one request; they are **not** database rows. The decided text goes into `public.visit_reports.summary` (`0016`, at most 4000 characters) through the existing F6 commands.
- IMPLEMENTED: the report-draft use case has no row in `ai_agent_definitions` or `ai_agent_fields`.
- Read, not decided by `eng`: `cra` 2026-11-06 reads DOC-AI (report drafting) as **level G** (`CLINICAL_GOVERNANCE.md`, CGR-241 cites it); `lca` 2026-11-18 04:20: the signed version stores lines, sources and decisions, «no second copy of the text in the AIG1 ledger (references only, AUT-138)»; `aia` AUT-138: reuse AIG1, do not rebuild it.

## 2. Deviations and fit gaps (reported, not changed)

1. **Code stricter than the newer founder decision (README rule 10, CLAUDE.md).** FE-094 allows Claude through the Anthropic API for the synthetic data of Phase A on `navora-staging`. The database still refuses every `kind = 'ai'` switch-on «in irgendeiner Umgebung». So an AIG1 agent for the model draft can be registered but never switched on, and the AIG1 stop rule (`aig1_check`) cannot govern it. I do **not** relax this refusal: it is a D-35 safety release rule, and the database cannot tell staging from production. OPEN (`aia`, `lca`, then the PO; the founder if a database exception is wanted).
2. **Level G.** If the model agent is registered as G (the `cra` reading of DOC-AI), the switch-on is refused a second time (D-34). Registering it as L to pass would be the «bypass by registration» `cra` warns about in CGR-241. PLANNED: register it as **G** and never switch it on through `set_agent_state` in Phase A. OPEN: `cra` confirms G for this agent.
3. **Payload versus «references only».** `ai_suggestions.proposed_value` must hold the value. For a report line that value is clinical free text, which `lca` does not want copied into the ledger. Fit gap: the ledger has no reference-only value form. OPEN (`lca`, with `aia`).
4. **Input references.** `input_refs` accepts only `{table, id}` rows. The draft's inputs are the typed notes (not stored, ADR-207 (1)) and the report snapshot. Only `visit_reports.id` and `care_visits.id` can be referenced; the segment a line came from cannot (it is no row). PLANNED below; `aia` to confirm that this meets «ohne Quelle kein Wert» at the ledger level, given that the line-to-segment link is checked in the control layer (`checkDraft`, #1494) and shown on screen.

## 3. Proposed design (PLANNED; option A, recommended for Phase A)

1. **Registration (migration, idempotent):** agent `report_draft_model` (`kind = 'ai'`, level `G`, provider `anthropic`, region = the provider's stated processing region; `0097` requires a value and `eng` will not invent one, so the registration waits for `lca`'s reading of the terms, FE-094 (c)), brief `BK`; field `summary_line` on `visit_reports.summary`, class `record`. The rule substitute gets no ledger row (it is no AI, FE-088 (4)).
2. **One write command:** `public.record_report_draft_proposal(p_visit_id, p_report_id, p_lines jsonb, p_idempotency_key)`, security definer, `search_path = ''`. Refuses unless: caller is the performer of the visit on the open draft (the same check as `field_reports.i_am_performer`), the organisation is a simulation organisation (database check; defence in depth beside the app's staging check), the report is `draft`. Writes one `ai_suggestions` row per accepted line: `proposal_id` one per request, `entity_type = 'visit_reports'`, `entity_id = p_report_id`, `input_refs = [{visit_reports, id}, {care_visits, id}]`, `proposed_value` per §2 (3) once decided. Audit through the existing pattern; the log carries counts only.
3. **One decision command per line:** `Übernehmen` → `confirmed`, edited before taking → `corrected`, `Verwerfen` → `rejected`, each by the performer, `bulk = false` always (no accept-all; the `0097` check already forbids bulk for anything but `confirmed`, and this command never sets it).
4. **Fail closed:** the app calls the model only after `record_report_draft_proposal` is reachable; if the ledger write fails, the screen shows the rule substitute with `ledger_missing` (no model text without its ledger row, AUT-138). `MODEL_LEDGER_READY` becomes a server check of the command's result, not a constant.
5. **The AIG1 switch:** not used for this agent in Phase A (it stays refused, §2 (1)); the environment values and `AI_KILL_SWITCH` remain the switch (FE-094 (d)). This is named as a limit, not hidden: Phase B needs either the D-35 stage-1 release or a different switch decided by the owner.

**Option B (not recommended without an owner decision):** a database exception in `set_agent_state` for `kind = 'ai'` in simulation organisations. It changes a D-35 release rule and the D-34 level refusal; `eng` does not build it on its own.

## 4. Tests to write first (PLANNED, red before the migration)

- pgTAP: no app-role grant on the two tables still holds; `record_report_draft_proposal` refuses a non-performer, a signed report, a non-simulation organisation; one row per line; append-only (update and delete refused); `set_agent_state` on `report_draft_model` still returns `ai_not_allowed` (pins the D-35 refusal); a decision command never writes `bulk = true`; the ledger value carries no character of the typed notes if `lca` chooses the reference-only form.
- vitest: `withLedgerGuard` blocks the model when the ledger write fails; the model text never reaches the screen without a ledger id.
- e2e: unchanged path with the rule substitute (CI has no model and never calls one; S2).

## 5. Questions (one owner each)

- **`aia`:** option A as the AUT-138 reuse in Phase A (ledger yes, AIG1 switch not used)? Is `input_refs` = report plus visit enough, with the segment link checked in the control layer?
- **`lca`:** what may `proposed_value` and `final_value` hold for a report line: the text, or only a digest (for example SHA-256 and length) with the text living only in the signed report? Retention on synthetic staging data with no deletion path (D-4)? The provider region value for the registration (FE-094 (c), terms UNKNOWN).
- **`cra`:** level G for `report_draft_model` confirmed?
- **`po`:** place part 2b after these views; until then `MODEL_LEDGER_READY` stays `false` and every draft is the rule substitute on every environment (IMPLEMENTED on #1497).

Nothing here sets a clinical, legal, documentation or tariff rule.
