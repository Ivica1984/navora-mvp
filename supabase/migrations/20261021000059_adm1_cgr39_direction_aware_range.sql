-- ADM1 changes (PO 2026-10-24 07:10, docs/agents/briefs/ADM1.md, ADM1-R1 to R6): CGR-39 (`cra` 2026-10-24 06:30,
-- blocking S1). ADR-072. Remediation plan docs/agents/clinical/remediation/CGR-39.md. Product authority (PO); no
-- clinical value is set here: every bound below only removes an engineering range no clinician approved (D-28).
--
-- Before (0035:526-583): `private.exception_rule_range` treated every threshold as a delay (larger = later signal)
--   and `set_exception_rule` accepted any amount from 0 up to the default (P1) or twice the default. For look-ahead
--   rules (larger = EARLIER signal) the check was inverted: the P1 hospital-discharge rule could be set to 0 h (its
--   window `between now() and now()` is empty, the signal never fires) while a stricter 48 h was refused.
-- Now (IMPLEMENTED in this migration):
--   1. ADM1-R1: `exception_rules.amount_direction` ('look_ahead' | 'delay'), required for every rule with an amount
--      (check constraint: a new amount-bearing rule without a direction cannot be inserted). Per rule, with the line
--      of the reader that proves it:
--        look_ahead  visit_uncovered_hospital, visit_uncovered  start `<= after_threshold(now(), amount)`
--                                                                 (0019:175-178, patched to `<=` by 0038:91-92)
--                    order_expiring                             `valid_until <= current_date + amount` (0024:501)
--                    team_cancellation_late                     start `< after_threshold(cancelled_at, amount)` (0024:543-546)
--                    cover_without_access                       start `<= after_threshold(now(), amount)` (0029:259-261;
--                                                                 found by Engineering, not named in the brief)
--        delay       case_not_ready                             `now() >= after_threshold(created_at, amount)` (0019:155, 0024:469)
--                    report_not_final (also times report_correction_open, CR-053, 0047:84-87)
--                                                               `now() >= after_threshold(ended_at, amount)` (0024:526)
--                    visit_overdue                              `now() >= after_threshold(start, amount)` (0038:112)
--                    visit_stuck                                `now() >= after_threshold(state_since, amount)` (0038:131, 0045:95)
--      Rules without an amount (quality_serious_open, no_show_open, candidates_exhausted, offer_overdue,
--      deadline_missing, care_plan_review_overdue, visit_interrupted, report_correction_open) carry no direction.
--   2. ADM1-R2: an override never makes a signal later than the platform default (until D-28 sets a band):
--        look_ahead  amount from the default up to 4× the default (cap 720; a bound against alert floods, not a
--                    clinical value). Below the default, 0 included: out_of_range.
--        delay       amount from the floor up to the default. Above the default: out_of_range. Floor 0 (in every delay
--                    reader 0 means "at once": `after_threshold` returns its start), except visit_stuck: floor 1 h,
--                    because at 0 every visit on the way, started or paused would be "stuck" the moment it starts (the
--                    rule would no longer separate stuck from in progress).
--      Priority never below the default and escalation hours never later than the default: unchanged (0035).
--      One check function, used by the command and by the reset in 3.
--   3. ADM1-R3: every existing override the new check refuses is reset to the platform default (deleted), with one
--      audit row per reset naming the old values. The number is raised as a NOTICE (expected 0 on synthetic data).
--   4. `admin_exception_rules` also returns the direction and the lower bound, so `/admin` can say which way is
--      stricter (ADM1-R5).
--   5. `private.effective_exception_rules` returns `setof public.exception_rules`, so it is recreated with the new
--      column appended (same rows and values otherwise; the direction is never overridden).
-- Unchanged (ADM1-R6): `private.derived_exceptions`, `operations_exceptions` and every default value; only the
--   admissible overrides change.

-- 1. Direction per rule ---------------------------------------------------------------------------------------------
alter table public.exception_rules add column if not exists amount_direction text;
alter table public.exception_rules drop constraint if exists exception_rules_amount_direction_check;
alter table public.exception_rules add constraint exception_rules_amount_direction_check
  check (amount_direction is null or amount_direction in ('look_ahead', 'delay'));
update public.exception_rules set amount_direction = 'look_ahead'
  where exception_type in ('visit_uncovered_hospital', 'visit_uncovered', 'order_expiring', 'team_cancellation_late',
                           'cover_without_access');
update public.exception_rules set amount_direction = 'delay'
  where exception_type in ('case_not_ready', 'report_not_final', 'visit_overdue', 'visit_stuck');
-- Fails the migration if any amount-bearing rule was missed above.
alter table public.exception_rules drop constraint if exists exception_rules_amount_has_direction;
alter table public.exception_rules add constraint exception_rules_amount_has_direction
  check ((amount is null) = (amount_direction is null));
comment on column public.exception_rules.amount_direction is
  'ADM1 / CGR-39: how the amount works in the reader. look_ahead: a larger amount means an EARLIER signal (a window '
  'ahead of an event); delay: a larger amount means a LATER signal (time after an event). Required when amount is set.';

-- The row type of exception_rules gained a column: the effective rules carry it too (never overridden).
create or replace function private.effective_exception_rules(p_org uuid)
returns setof public.exception_rules
language sql stable security definer set search_path = ''
as $$
  select r.exception_type, coalesce(o.priority, r.priority), coalesce(o.amount, r.amount), r.unit,
         case when o.id is null then r.escalate_to_p1_after_hours else o.escalate_to_p1_after_hours end,
         r.label, r.next_step, coalesce(o.updated_at, r.updated_at), r.amount_direction
  from public.exception_rules r
  left join public.exception_rule_overrides o on o.organization_id = p_org and o.exception_type = r.exception_type
$$;
revoke all on function private.effective_exception_rules(uuid) from public, anon, authenticated;

-- 2. Direction-aware safe range ---------------------------------------------------------------------------------------
drop function if exists public.admin_exception_rules(uuid);
drop function if exists private.exception_rule_range(text);

create function private.exception_rule_range(p_type text)
returns table (min_priority_rank integer, amount_direction text, min_amount integer, max_amount integer, max_escalate integer)
language sql stable security definer set search_path = ''
as $$
  select case r.priority when 'P1' then 1 when 'P2' then 2 else 3 end,
         r.amount_direction,
         case when r.amount is null then null
              when r.amount_direction = 'look_ahead' then r.amount
              when r.exception_type = 'visit_stuck' then least(1, r.amount)
              else 0 end,
         case when r.amount is null then null
              when r.amount_direction = 'look_ahead' then least(720, greatest(r.amount * 4, r.amount))
              else r.amount end,
         r.escalate_to_p1_after_hours
  from public.exception_rules r where r.exception_type = p_type
$$;
revoke all on function private.exception_rule_range(text) from public, anon, authenticated;
comment on function private.exception_rule_range(text) is
  'ADM1 / CGR-39 (ADR-072): safe range of an organisation override. Never later than the platform default: look_ahead '
  'from the default up to 4x; delay from the floor (0, visit_stuck 1) up to the default. Priority never lower, '
  'escalation never later. Engineering bounds, not clinical values (D-28).';

-- true when the override is inside the safe range of its rule (false for an unknown type).
create function private.exception_override_in_range(p_type text, p_priority text, p_amount integer, p_escalate integer)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select case p_priority when 'P1' then 1 when 'P2' then 2 when 'P3' then 3 end <= g.min_priority_rank
       and (d.amount is null) = (p_amount is null)
       and (p_amount is null or p_amount between g.min_amount and g.max_amount)
       and (case when d.escalate_to_p1_after_hours is null then p_escalate is null
                 else p_escalate is not null and p_escalate between 0 and g.max_escalate end)
    from public.exception_rules d
    cross join lateral private.exception_rule_range(d.exception_type) g
    where d.exception_type = p_type), false)
$$;
revoke all on function private.exception_override_in_range(text, text, integer, integer) from public, anon, authenticated;

-- Return: 'ok' | 'out_of_range' | 'duplicate' | 'rejected' (signature and order of checks as in 0035)
create or replace function public.set_exception_rule(p_organization_id uuid, p_exception_type text, p_priority text,
                                                     p_amount integer, p_escalate_to_p1_after_hours integer, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then return 'rejected'; end if;
  if not exists (select 1 from public.exception_rules where exception_type = p_exception_type)
     or p_priority is null or p_priority not in ('P1', 'P2', 'P3') then
    raise exception 'known exception type and priority (P1, P2, P3) required' using errcode = '22023';
  end if;
  if private.begin_command('set_exception_rule', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then
    return private.end_command('rejected');
  end if;
  if not private.exception_override_in_range(p_exception_type, p_priority, p_amount, p_escalate_to_p1_after_hours) then
    return private.end_command('out_of_range');
  end if;
  insert into public.exception_rule_overrides (organization_id, exception_type, priority, amount, escalate_to_p1_after_hours, updated_by)
  values (p_organization_id, p_exception_type, p_priority, p_amount, p_escalate_to_p1_after_hours, uid)
  on conflict (organization_id, exception_type) do update
    set priority = excluded.priority, amount = excluded.amount,
        escalate_to_p1_after_hours = excluded.escalate_to_p1_after_hours, updated_by = uid, updated_at = now();
  return private.end_command('ok');
end;
$$;

create function public.admin_exception_rules(p_organization_id uuid)
returns table (exception_type text, label text, unit text,
               priority text, amount integer, escalate_to_p1_after_hours integer, is_default boolean,
               default_priority text, default_amount integer, default_escalate integer,
               max_amount integer, max_escalate integer, updated_by_name text, updated_at timestamptz,
               amount_direction text, min_amount integer)
language sql stable security definer set search_path = ''
as $$
  select r.exception_type, r.label, r.unit,
         coalesce(o.priority, r.priority), coalesce(o.amount, r.amount),
         case when o.id is null then r.escalate_to_p1_after_hours else o.escalate_to_p1_after_hours end,
         o.id is null, r.priority, r.amount, r.escalate_to_p1_after_hours,
         g.max_amount, g.max_escalate,
         case when o.id is not null then coalesce(private.member_name(p_organization_id, o.updated_by), 'Administration') end,
         o.updated_at,
         g.amount_direction, g.min_amount
  from public.exception_rules r
  cross join lateral private.exception_rule_range(r.exception_type) g
  left join public.exception_rule_overrides o on o.organization_id = p_organization_id and o.exception_type = r.exception_type
  where private.is_org_admin(p_organization_id)
  order by r.priority, r.exception_type;
$$;
revoke all on function public.admin_exception_rules(uuid) from public, anon;
grant execute on function public.admin_exception_rules(uuid) to authenticated;

-- 3. ADM1-R3: reset every existing override outside the new range, audited ------------------------------------------
-- Maintenance path (no user): audit row with actor_id null and the executing database role, command 'adm1_range_reset'.
create function private.adm1_reset_out_of_range_overrides()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  o public.exception_rule_overrides;
  n integer := 0;
begin
  for o in
    select * from public.exception_rule_overrides x
    where not private.exception_override_in_range(x.exception_type, x.priority, x.amount, x.escalate_to_p1_after_hours)
    order by x.organization_id, x.exception_type
  loop
    delete from public.exception_rule_overrides where id = o.id;
    insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
    values (o.organization_id, null, current_user, 'exception_rule_overrides', o.id, 'adm1_range_reset', null,
            jsonb_build_object('reset', true, 'reason', 'CGR-39: later than the platform default',
                               'exception_type', o.exception_type, 'priority', o.priority, 'amount', o.amount,
                               'escalate_to_p1_after_hours', o.escalate_to_p1_after_hours,
                               'updated_by', o.updated_by, 'updated_at', o.updated_at));
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function private.adm1_reset_out_of_range_overrides() from public, anon, authenticated;

do $$
declare
  n integer := private.adm1_reset_out_of_range_overrides();
begin
  raise notice 'ADM1-R3 (CGR-39): % organisation override(s) outside the safe range reset to the platform default', n;
end;
$$;
