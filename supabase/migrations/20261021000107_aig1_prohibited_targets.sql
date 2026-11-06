-- Owner directive 2026-11-03 (#824, relayed by `po`; ADR-141): no automatic billing decision and no automatic
-- prioritisation of safety signals through an assistant. Enforced at the AIG1 field register, the only place an agent's
-- value can be aimed at a record (AIG1-2/-3/-5, 0097).
--
-- Before (IMPLEMENTED, read in a database built from 0001-0104): `ai_agent_fields` accepts a `record`-class field on
-- any table; only `schedule` is narrowed (private.aig1_guard_field_class). A value reaches a record only through
-- private.aig1_apply, which has one branch (care_visits.responsible_user_id) and refuses every other target (0A000).
-- So no billing or signal write exists today, but nothing in the register stops a later migration from aiming an agent
-- at one.
-- Now (IMPLEMENTED in this migration):
--   1. `private.aig1_prohibited_target(table, column)`: 'billing' for billable_facts, billing_rules, tariff_rates and
--      quality_holds (visit_has_open_hold is the single billing rule, QG1); 'safety_signal' for safety_signals, every
--      signal_* table and the exception rules and overrides that make a signal P1 (SIG1, OPS1); null otherwise.
--   2. A second trigger on `ai_agent_fields` refuses such a target on insert and update, whatever the class (42501).
--      The existing class trigger is not replaced (no change to 0097's functions).
--   3. A check at migration time that no field already in the register points at such a target.
-- Not changed: no command, read path, grant, RLS policy, audit trigger or seed row. No clinical, billing or tariff rule
-- is added or changed; the list names tables, not rules.
-- Idempotent: `create or replace`, `drop trigger if exists`.

create or replace function private.aig1_prohibited_target(p_table text, p_column text)
returns text language sql immutable set search_path = ''
as $$
  select case
    when p_table in ('billable_facts', 'billing_rules', 'tariff_rates', 'quality_holds') then 'billing'
    when p_table = 'safety_signals' or p_table like 'signal\_%' then 'safety_signal'
    when p_table in ('exception_rules', 'exception_rule_overrides') then 'safety_signal'
  end
$$;
revoke all on function private.aig1_prohibited_target(text, text) from public, anon, authenticated;
comment on function private.aig1_prohibited_target(text, text) is
  'Owner directive 2026-11-03 (#824, ADR-141): targets no assistant may ever propose a value for, whatever the class: '
  'billing (billable facts, billing rules, tariff rates, quality holds) and safety-signal priority (safety signals, '
  'their deliveries and takes, the exception rules and overrides that make a signal P1).';

create or replace function private.aig1_guard_prohibited_target()
returns trigger language plpgsql set search_path = ''
as $$
declare why text;
begin
  why := private.aig1_prohibited_target(new.target_table, new.target_column);
  if why is not null then
    raise exception 'no assistant may propose a % value (owner directive 2026-11-03, #824)', why
      using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.aig1_guard_prohibited_target() from public, anon, authenticated;
drop trigger if exists ai_agent_fields_prohibited_guard on public.ai_agent_fields;
create trigger ai_agent_fields_prohibited_guard before insert or update on public.ai_agent_fields
  for each row execute function private.aig1_guard_prohibited_target();

do $$
declare n integer;
begin
  select count(*) into n from public.ai_agent_fields f
  where private.aig1_prohibited_target(f.target_table, f.target_column) is not null;
  if n > 0 then
    raise exception '0107: % register field(s) point at billing or a safety signal; remove them first', n;
  end if;
end;
$$;
