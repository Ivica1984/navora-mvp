-- BK-e, contract point 2 (PO package contract 2026-11-19 16:40; PO residual list 2026-11-20 02:39 (1), brief
-- docs/agents/briefs/BK.md): the AUT-152 stop-rule row for the report-draft model agent, exactly as `cra` gave it at the
-- gate (comment 7021790626, `CLINICAL_GOVERNANCE.md` 2026-11-19 21:45): share 50.00, minimum 10 decided lines, window
-- 30 days. These are the repository's existing synthetic test-agent values (`supabase/seed.sql:477`).
--
-- A SIMULATION TEST PARAMETER, NOT A CLINICAL THRESHOLD. No clinical rule is set here. The gate of 0151
-- (`private.report_draft_model_closed`) still admits simulation organisations only; before any non-simulation
-- organisation can reach the model, a named Clinical Owner sets the real value in its own reviewed migration (CR-239, S1).
--
-- Before (IMPLEMENTED, 0151): `public.report_draft_stop_rules` is empty, so the model is closed (`no_threshold`).
-- Now (IMPLEMENTED in this migration): one row for `report_draft_model`; the gate can open for the performer of an open
-- draft in a simulation organisation until the stop rule is reached. Whether a model is called at all stays with the app
-- configuration (`AI_REPORT_DRAFT_MODE`, provider key; neither is set by this migration).
-- No table, grant, policy or function changes: the table keeps RLS on and no grant for app roles (0151).
-- Idempotent: a repeat writes nothing; an existing row for the agent is never overwritten here.
-- Way back: `delete from public.report_draft_stop_rules where agent_key = 'report_draft_model'` in a reviewed migration
-- closes the model again (fail closed).

insert into public.report_draft_stop_rules (agent_key, stop_share, stop_min_decided, stop_window_days, cra_ref)
values ('report_draft_model', 50.00, 10, 30,
        'cra 2026-11-19 21:45 simulation test parameter (seed.sql:477), not a clinical threshold')
on conflict (agent_key) do nothing;
