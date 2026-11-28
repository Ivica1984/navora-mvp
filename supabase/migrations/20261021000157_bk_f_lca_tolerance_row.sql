-- BK-f, contract 2026-11-20 06:39 point 2 (d); PO answer 7034703327 (2) on #1581: the time-tolerance row for the take
-- invoice draft, exactly as `lca` gave it at the gate (`lca-gate: #1581 ba19210 clear`, comment 7039866370, point 2;
-- journal `docs/agents/journal/2026-11-20-1343-lca.md`): 15 minutes.
--
-- A SIMULATION TEST PARAMETER, NOT A LEGAL OR TARIFF VALUE. Synthetic data only. For real data the value is OPEN
-- (owner, D-42). Note (`lca`): inside the tolerance the recorded minutes are billed, so a simulated invoice can run up to
-- 15 minutes above the ordered duration.
--
-- Before (IMPLEMENTED, 0156): `public.invoice_time_tolerances` is empty, so every draft is refused `no_tolerance`.
-- Now (IMPLEMENTED in this migration): one row for `take_invoice`; drafts inside 15 minutes of the ordered duration are
-- built from the recorded minutes, drafts outside are refused `times_disagree`.
-- No table, grant, policy or function change (table keeps RLS on and no grant for app roles, 0156). Idempotent: a repeat
-- writes nothing; an existing row is never overwritten here. Way back:
-- `delete from public.invoice_time_tolerances where key = 'take_invoice'` in a reviewed migration (every draft refused).

insert into public.invoice_time_tolerances (key, tolerance_minutes, lca_ref)
values ('take_invoice', 15,
        'lca 2026-11-20 13:43 #1581: simulation test value, synthetic data, not a legal or tariff value')
on conflict (key) do nothing;
