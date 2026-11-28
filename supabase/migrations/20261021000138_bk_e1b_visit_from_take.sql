-- BK-e1b database part (brief docs/agents/briefs/BK.md, PO 2026-11-18 02:39 criteria 2–4 and 03:39 (3); ADR-202 (2)–(4),
-- ADR-203; pgTAP 148). Gate «Simulation, synthetic data» only.
-- A take that turns «gedeckt» writes one visit for the named member in the same transaction (BK-7); writing it does not
-- release the take (CGR-232); the writer takes the take's person lock (CGR-233); a release after «gedeckt» and before
-- the start ends the visit as `cancelled` in the same transaction, never deleted, and nothing automatic runs after the
-- start (CGR-242); only the named member reads a take visit on /field, with the order's postcode and place (BK-7,
-- CGR-243 Phase A limit: no street, P-8).
--
-- No clinical, legal or tariff rule is set here; no lead-time rule for a re-opened order (UNKNOWN, Clinical Owner).
-- Never bypasses RLS, the QUAL1/ADM2 guards or the audit triggers on care_visits. Idempotent: `if not exists`,
-- `create or replace`, patches carrying the marker BK-E1B, `on conflict do nothing`.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.bk_e1b_patch(p_fn text, p_pairs text[], p_marker text)
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
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]);
    if n <> p_pairs[i + 2]::integer then
      raise exception '0138 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0138 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_e1b_patch(text, text[], text) from public, anon, authenticated;

-- 1. The visit names its take (ADR-202 (2); one visit per take) ---------------------------------------------------------
alter table public.care_visits add column if not exists order_take_id uuid references public.order_takes (id);
create unique index if not exists care_visits_one_per_take on public.care_visits (order_take_id)
  where order_take_id is not null;
comment on column public.care_visits.order_take_id is
  'BK-e1b / ADR-203: the take of a shift order this visit was written from (one visit per take). Written only by '
  'private.order_take_visit; null for every other visit. The visit is cancelled, never deleted, when the take is released.';
grant select (order_take_id) on public.care_visits to authenticated;

drop trigger if exists audit_care_visits_insert on public.care_visits;
create trigger audit_care_visits_insert
  after insert on public.care_visits
  for each row execute function private.write_audit_event('status', 'team_id', 'case_id', 'visit_date', 'time_start',
                                                          'time_end', 'order_take_id');
insert into private.audit_value_classes (table_name, key, class) values ('care_visits', 'order_take_id', 'code')
on conflict do nothing;

-- 2. CGR-232: the visit written from the same take is not an open visit of another order --------------------------------
select private.bk_e1b_patch('private.order_member_step(uuid, uuid, uuid)', array[
  E'                  and private.visit_interval(v) && tstzrange(o.starts_at, o.ends_at, ''[)''))',
  E'                  and private.visit_interval(v) && tstzrange(o.starts_at, o.ends_at, ''[)'')\n'
  || E'                  -- BK-E1B (CGR-232): the visit written from a take of THIS order never counts.\n'
  || E'                  and not exists (select 1 from public.order_takes vt\n'
  || E'                                  where vt.id = v.order_take_id and vt.order_id = o.id))',
  '1'], 'BK-E1B');
revoke all on function private.order_member_step(uuid, uuid, uuid) from public, anon, authenticated;

-- 3. Write and end the visit of one take (ADR-203 (2), (5)) ------------------------------------------------------------
create or replace function private.write_take_visit(p_take_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  k   public.order_takes;
  o   public.partner_requests;
  vid uuid;
begin
  select * into k from public.order_takes where id = p_take_id;
  if k.id is null or k.released_at is not null or k.acknowledged_at is null then return null; end if;
  select * into o from public.partner_requests where id = k.order_id;
  if o.id is null or o.starts_at is null or o.ends_at is null or o.starts_at <= private.now() then return null; end if;
  -- CGR-233: the same person key as take_order, before any write that names her (re-entrant in the take's session).
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || k.member_id::text, 0));
  select v.id into vid from public.care_visits v where v.order_take_id = k.id;
  if vid is not null then return vid; end if;
  insert into public.care_visits (organization_id, team_id, case_id, visit_date, time_start, time_end, status,
                                  responsible_user_id, order_take_id, services_provided)
    values (k.organization_id, k.team_id, null,
            private.at_zurich(o.starts_at)::date,
            private.at_zurich(o.starts_at)::time,
            private.at_zurich(o.ends_at)::time,
            'planned', k.member_id, k.id, o.activity_tags)   -- BK-7: the order's tags, no retyping
    returning id into vid;
  -- The order's activities, in the matrix catalogue only (QUAL1-6); the QUAL1 recheck on insert stays in force.
  insert into public.visit_activities (organization_id, visit_id, activity_code)
    select k.organization_id, vid, a.code
    from public.qual_activities a
    where a.code = any (coalesce(o.activity_tags, '{}'))
  on conflict do nothing;
  return vid;
end;
$$;
revoke all on function private.write_take_visit(uuid) from public, anon, authenticated;

create or replace function private.end_take_visit(p_take_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  k public.order_takes;
begin
  select * into k from public.order_takes where id = p_take_id;
  if k.id is null or k.released_at is null then return; end if;
  -- CGR-242: never after the start (no automatic release after starts_at); a visit already under way is untouched.
  if exists (select 1 from public.partner_requests p where p.id = k.order_id and p.starts_at <= private.now()) then
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || k.member_id::text, 0));
  update public.care_visits set status = 'cancelled'
    where order_take_id = k.id and status = 'planned';
end;
$$;
revoke all on function private.end_take_visit(uuid) from public, anon, authenticated;

-- The one writer: every path that makes a take «gedeckt» or releases it runs through the take row (ADR-203 (1)).
create or replace function private.order_take_visit()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  -- CGR-233: the person lock first (also taken inside the two helpers; re-entrant).
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || new.member_id::text, 0));
  if new.released_at is not null then
    if tg_op = 'UPDATE' and old.released_at is null then
      perform private.end_take_visit(new.id);
    end if;
  elsif new.acknowledged_at is not null
        and (tg_op = 'INSERT' or old.acknowledged_at is null) then
    perform private.write_take_visit(new.id);
  end if;
  return null;
end;
$$;
revoke all on function private.order_take_visit() from public, anon, authenticated;
drop trigger if exists bk_e1b_take_visit on public.order_takes;
create trigger bk_e1b_take_visit after insert or update of acknowledged_at, released_at on public.order_takes
  for each row execute function private.order_take_visit();

-- 4. /field: a take visit only for its named member, place from the order (BK-7; CGR-243) -------------------------------
create or replace function private.take_visit_place(p_visit_id uuid)
returns table (postcode text, city text)
language sql stable security definer set search_path = ''
as $$
  select q.postcode, q.city
  from public.care_visits v
  join public.order_takes k on k.id = v.order_take_id
  join public.partner_requests q on q.id = k.order_id
  where v.id = p_visit_id and v.responsible_user_id = (select auth.uid())
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
$$;
revoke all on function private.take_visit_place(uuid) from public, anon;
grant execute on function private.take_visit_place(uuid) to authenticated;

select private.bk_e1b_patch('public.field_visits(date)', array[
  E'c.care_needs, c.address, c.plz, c.ort,',
  E'c.care_needs, c.address, coalesce(c.plz, tp.postcode), coalesce(c.ort, tp.city),  -- BK-E1B',
  '1',
  E'  left join public.cases c on c.id = v.case_id\n',
  E'  left join public.cases c on c.id = v.case_id\n'
  || E'  left join lateral private.take_visit_place(v.id) tp on v.order_take_id is not null\n',
  '1',
  E'    and v.visit_date = p_date\n',
  E'    and v.visit_date = p_date\n'
  || E'    and (v.order_take_id is null or v.responsible_user_id = (select auth.uid()))  -- BK-7: the named member only\n',
  '1'], 'BK-E1B');
revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

-- 5. Existing «gedeckt» takes of orders not yet started get their visit (ADR-203 (8)) ------------------------------------
do $$
declare r record;
begin
  for r in
    select t.id from public.order_takes t join public.partner_requests p on p.id = t.order_id
    where t.released_at is null and t.acknowledged_at is not null and p.starts_at > private.now()
      and not exists (select 1 from public.care_visits v where v.order_take_id = t.id)
    order by p.starts_at, t.id
  loop
    perform private.write_take_visit(r.id);
  end loop;
end;
$$;

drop function private.bk_e1b_patch(text, text[], text);
