-- ORD0-C2 (CGR-44, Q12 (c) widened to (b)+(c)) and SIG1-C1 (CGR-43, including SIG2's immediate step): the PO
-- conditions of 2026-10-24 15:10 and 16:20 (`docs/agents/briefs/ORD0.md`, `docs/agents/briefs/SIG1.md`); `cra` note
-- under CGR-43 (2026-10-24 18:26). ADR-077. Remediation plans `docs/agents/clinical/remediation/CGR-43.md` and
-- `CGR-44.md`. No clinical rule, deadline, response time or threshold is decided here (D-28, D-19, D-22 stay open).
--
-- Before:
--   * CGR-44: once a case has a "Hausärztin/Hausarzt informiert" record, nothing opens `inform_gp` again (0061 §3,
--     Q12 (a)). A client whose A/C care grows months later, or who is reassessed, is never prompted again.
--   * CGR-43: any recipient's "Ich übernehme" stops the SIG1-5 step to Operations (0060, `taken_by is null`) and
--     SIG2's immediate step (`outside_settle`, 0062). A care assistant can take a P1 no-show or a broken-off visit and
--     nobody else, Operations included, is told.
-- Now (IMPLEMENTED in this migration):
--   1. ORD0-C2 (a): when a care-plan item of category A or C becomes active (inserted active, re-activated, or changed
--      to A/C while active) in a case whose medical order is not `present`, and no record is dated on or after that
--      Zurich day, **one** `inform_gp` task opens (the existing one-open-per-kind index; never a second while one is
--      open). A plan refresh, PLAN2 run or `/team` load opens nothing (0061 §3 unchanged: planning only opens the first).
--   2. ORD0-C2 (a′): the same when a needs-assessment visit reaches `completed` (every completed assessment, not
--      `cases.needs_assessment_done_at`, which keeps only the first).
--   3. ORD0-C2 (b), (c): `record_gp_informed` closes the task as before; a B item, an order `present` and a closed case
--      open nothing; a case close still closes the task.
--   4. SIG1-C1: every "Ich übernehme" is one append-only row in `public.signal_takes` (taker, her qualification in the
--      visit's team, or in the cover team for the covering member, and whether it stops the step). For `no_show` and
--      `visit_interrupted` a take stops the SIG1-5 step and SIG2's immediate step only when the taker is a registered
--      nurse of the visit's team, or the covering member and a registered nurse in her cover team, or one of the
--      people that step would reach (Operations; ADR-077, engineering: the step informs them, and they already took
--      it). Every other kind: any take stops the step, as built (SIG1-C1 (c), D-28). `safety_signals.taken_by` stays
--      the first taker (AN2 measure 10 unchanged: time to the first take).
--   5. `take_signal` records a second take (a registered nurse after a care assistant); `my_signals` shows who took it,
--      her qualification, and "Meldung an Operations folgt" while no take stops the step.
-- Unchanged: thresholds and response times (SIG1-C1 (e)), recipients, the ADM1 range guard, SIG1-9, the guard trigger
--   on `safety_signals`, the first opening of `inform_gp` by planning, `complete_case_task` refusing `inform_gp`.

-- 0. Patch helper (string replacement on a function's own definition; each pattern must match the stated number of
--    times; idempotent through a marker in the patched body).
create function private.c63_patch(p_fn text, p_triples text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  for i in 1 .. coalesce(array_length(p_triples, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_triples[i], ''))) / length(p_triples[i]);
    if n <> p_triples[i + 2]::integer then
      raise exception '0063 patch for % must match % time(s), matched %: %', p_fn, p_triples[i + 2], n, p_triples[i];
    end if;
    def := replace(def, p_triples[i], p_triples[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0063 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.c63_patch(text, text[], text) from public, anon, authenticated;

-- 1. ORD0-C2: one inform_gp task per event, never a second while one is open ---------------------------------------------
create or replace function private.open_inform_gp_after_event(p_case_id uuid, p_day date)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
begin
  select * into c from public.cases where id = p_case_id;
  if not found or c.lifecycle = 'closed' or c.medical_order_status = 'present' then
    return;
  end if;
  -- Covered: a record dated on or after the day of the event.
  if exists (select 1 from public.case_gp_notices g where g.case_id = c.id and g.informed_on >= p_day) then
    return;
  end if;
  insert into public.case_tasks (organization_id, case_id, kind)
  values (c.organization_id, c.id, 'inform_gp')
  on conflict (case_id, kind) where status = 'open' do nothing;
end;
$$;
revoke all on function private.open_inform_gp_after_event(uuid, date) from public, anon, authenticated;
comment on function private.open_inform_gp_after_event(uuid, date) is
  'ORD0-C2 (CGR-44): opens one inform_gp task for a case whose order is not present, unless a "doctor informed" record '
  'is dated on or after p_day, a task is already open, or the case is closed.';

create or replace function private.inform_gp_from_plan_item()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.active and new.category in ('A', 'C')
     and (tg_op = 'INSERT' or not old.active or old.category not in ('A', 'C')) then
    perform private.open_inform_gp_after_event(new.case_id, (now() at time zone 'Europe/Zurich')::date);
  end if;
  return null;
end;
$$;
revoke all on function private.inform_gp_from_plan_item() from public, anon, authenticated;

drop trigger if exists ord0c2_inform_gp on public.care_plan_items;
create trigger ord0c2_inform_gp after insert or update of active, category on public.care_plan_items
  for each row execute function private.inform_gp_from_plan_item();

create or replace function private.inform_gp_from_assessment()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.is_needs_assessment and new.status = 'completed' and old.status is distinct from 'completed'
     and new.case_id is not null then
    perform private.open_inform_gp_after_event(new.case_id, (now() at time zone 'Europe/Zurich')::date);
  end if;
  return null;
end;
$$;
revoke all on function private.inform_gp_from_assessment() from public, anon, authenticated;

drop trigger if exists ord0c2_inform_gp_assessment on public.care_visits;
create trigger ord0c2_inform_gp_assessment after update of status on public.care_visits
  for each row execute function private.inform_gp_from_assessment();

-- 2. SIG1-C1: every take is a row; only some takes stop the step to Operations ------------------------------------------
create table if not exists public.signal_takes (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id),
  signal_id        uuid not null references public.safety_signals (id),
  taker_id         uuid not null,
  qualification    text check (qualification in ('registered_nurse', 'care_assistant')),
  stops_escalation boolean not null,
  taken_at         timestamptz not null default now(),
  unique (signal_id, taker_id)
);
create index if not exists signal_takes_signal on public.signal_takes (signal_id) where stops_escalation;
comment on table public.signal_takes is
  'SIG1-C1 (CGR-43): one row per "Ich übernehme" of a safety signal: taker, her qualification in the visit''s team (the '
  'cover team for the covering member) and whether the take stops the SIG1-5 / SIG2-5 step to Operations. Written only '
  'by public.take_signal; never changed or deleted; audited. No client data, no free text.';

alter table public.signal_takes enable row level security;
revoke all on public.signal_takes from public, anon, authenticated;

create or replace function private.guard_signal_take()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'a take of a safety signal is never changed or deleted' using errcode = '42501';
end;
$$;
revoke all on function private.guard_signal_take() from public, anon, authenticated;
drop trigger if exists guard_signal_takes on public.signal_takes;
create trigger guard_signal_takes before update or delete on public.signal_takes
  for each row execute function private.guard_signal_take();
drop trigger if exists audit_signal_takes on public.signal_takes;
create trigger audit_signal_takes after insert on public.signal_takes
  for each row execute function private.write_audit_event('signal_id', 'taker_id', 'qualification', 'stops_escalation');

-- The taker's qualification for this signal: in the visit's (owning) team; for the covering member, in her cover team.
create or replace function private.signal_taker_qualification(p_signal_id uuid, p_user uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select m.qualification from public.safety_signals s
       join public.team_memberships m on m.team_id = s.team_id and m.user_id = p_user
     where s.id = p_signal_id),
    (select m.qualification from public.safety_signals s
       join public.care_visits v on v.id = s.visit_id
       join public.team_memberships m on m.team_id = v.cover_team_id and m.user_id = p_user
     where s.id = p_signal_id and v.covered_by = p_user))
$$;
revoke all on function private.signal_taker_qualification(uuid, uuid) from public, anon, authenticated;

-- SIG1-C1 (a)-(c): does this person's take stop the step to Operations?
create or replace function private.signal_take_stops(p_signal_id uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when s.signal_kind not in ('no_show', 'visit_interrupted') then true                         -- (c) as built (D-28)
    when private.signal_taker_qualification(s.id, p_user) = 'registered_nurse' then true          -- (b)
    when exists (select 1 from private.signal_operations_users(s.organization_id) o where o = p_user) then true  -- ADR-077
    else false end                                                                               -- (a)
  from public.safety_signals s where s.id = p_signal_id
$$;
revoke all on function private.signal_take_stops(uuid, uuid) from public, anon, authenticated;

-- One predicate for both steps: has somebody taken it in a way that stops the step?
create or replace function private.signal_taken_stops_step(p_signal_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.signal_takes t where t.signal_id = p_signal_id and t.stops_escalation)
$$;
revoke all on function private.signal_taken_stops_step(uuid) from public, anon, authenticated;

-- Takes recorded before this migration: one row each, judged by the same rule (protective: an open no-show taken only
-- by a care assistant goes to Operations at the next evaluation). Synthetic data only exists today.
insert into public.signal_takes (organization_id, signal_id, taker_id, qualification, stops_escalation, taken_at)
select s.organization_id, s.id, s.taken_by, private.signal_taker_qualification(s.id, s.taken_by),
       private.signal_take_stops(s.id, s.taken_by), s.taken_at
from public.safety_signals s
where s.taken_by is not null
on conflict (signal_id, taker_id) do nothing;

-- The SIG1-5 step (0060, as patched by 0062) and SIG2's immediate step (0062 §5) read the predicate.
select private.c63_patch('private.evaluate_signals(uuid, boolean)', array[
    's.ended_at is null and s.taken_by is null and s.escalated_at is null',
    's.ended_at is null and not private.signal_taken_stops_step(s.id) /* SIG1-C1 (ADR-077) */ and s.escalated_at is null',
    '1'],
  'SIG1-C1 (ADR-077)');

select private.c63_patch('private.outside_settle(uuid)', array[
    's.ended_at is null and s.taken_by is null',
    's.ended_at is null and not private.signal_taken_stops_step(s.id) /* SIG1-C1 (ADR-077) */',
    '1'],
  'SIG1-C1 (ADR-077)');

-- 3. The command ---------------------------------------------------------------------------------------------------------
-- SIG1-4 with SIG1-C1. Returns {result: ok|duplicate|rejected, reason?, taken_by_name?, operations_follows?}.
create or replace function public.take_signal(p_signal_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  s     public.safety_signals%rowtype;
  stops boolean;
  shown uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_recipient'); end if;
  if private.begin_command('take_signal', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  select * into s from public.safety_signals where id = p_signal_id for update;
  if s.id is null or not exists (select 1 from public.signal_deliveries d where d.signal_id = s.id and d.recipient_id = uid)
     or not private.is_org_member(s.organization_id) then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'not_recipient');
  end if;
  -- Already taken by her, or by somebody whose take stops the step: nothing more to record.
  if exists (select 1 from public.signal_takes t where t.signal_id = s.id and t.taker_id = uid)
     or private.signal_taken_stops_step(s.id) then
    select t.taker_id into shown from public.signal_takes t
    where t.signal_id = s.id order by t.stops_escalation desc, t.taken_at, t.id limit 1;
    return jsonb_build_object('result', private.end_command('duplicate'),
                              'taken_by_name', coalesce(private.member_name(s.organization_id, coalesce(shown, s.taken_by)), 'Teammitglied'));
  end if;
  if s.ended_at is not null then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'signal_ended');
  end if;
  stops := private.signal_take_stops(s.id, uid);
  insert into public.signal_takes (organization_id, signal_id, taker_id, qualification, stops_escalation)
  values (s.organization_id, s.id, uid, private.signal_taker_qualification(s.id, uid), stops);
  if s.taken_by is null then
    update public.safety_signals set taken_by = uid, taken_at = now() where id = s.id;
  end if;
  return jsonb_build_object('result', private.end_command('ok'),
                            'operations_follows', not stops and s.escalated_at is null);
end;
$$;
revoke all on function public.take_signal(uuid, uuid) from public, anon;
grant execute on function public.take_signal(uuid, uuid) to authenticated;
comment on function public.take_signal(uuid, uuid) is
  'SIG1-4 with SIG1-C1 (CGR-43, ADR-077): a recipient takes a P1 safety signal. For no_show and visit_interrupted a '
  'take by someone who is not a registered nurse of the visit''s team (or the covering registered nurse, or Operations) '
  'is recorded and shown but does not stop the step to Operations; a later registered nurse''s take still can.';

-- 4. The reader --------------------------------------------------------------------------------------------------------
-- SIG1-C1 (a): who took it (the take that stops the step, else the first), her qualification, and whether the step to
-- Operations still follows. `taken_by_me`: the caller is the taker shown. The rest is the 0062 body.
drop function if exists public.my_signals();
create function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz, outside_none boolean,
               taken_by_qualification text, taken_awaits_rn boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then return; end if;
  for org in select distinct om.organization_id from public.organization_memberships om where om.user_id = uid loop
    perform private.evaluate_signals(org, false);
  end loop;
  return query
    select s.id, s.signal_kind, s.visit_id, v.visit_date, v.time_start, s.team_id, t.name, d.reason, d.created_at, s.p1_at,
           coalesce(tk.taker_id = uid, false),
           case when tk.taker_id is not null
                then coalesce(private.member_name(s.organization_id, tk.taker_id), 'Teammitglied') end,
           tk.taken_at, s.outside_none_at is not null,
           tk.qualification,
           (tk.taker_id is not null and not tk.stops_escalation)
    from public.signal_deliveries d
    join public.safety_signals s on s.id = d.signal_id
    join public.care_visits v on v.id = s.visit_id
    join public.teams t on t.id = s.team_id
    left join lateral (select x.taker_id, x.taken_at, x.qualification, x.stops_escalation from public.signal_takes x
                       where x.signal_id = s.id order by x.stops_escalation desc, x.taken_at, x.id limit 1) tk on true
    where d.recipient_id = uid and s.ended_at is null and private.is_org_member(d.organization_id)
    order by (tk.taker_id is null or not tk.stops_escalation) desc, d.created_at desc, s.id;
end;
$$;
revoke all on function public.my_signals() from public, anon;
grant execute on function public.my_signals() to authenticated;

drop function private.c63_patch(text, text[], text);
