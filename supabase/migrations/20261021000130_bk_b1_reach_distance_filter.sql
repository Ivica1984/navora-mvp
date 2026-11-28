-- BK-b1 (brief docs/agents/briefs/BK.md, PO amendment 2026-11-14 09:39 (2); ADR-193 as aligned by ADR-195): postcode
-- distances, the team's own reach and the hard distance filter, written as offer and exclusion rows at confirmation.
--
-- 1. `public.postcode_distances`: reference data, one row per ordered pair of listed postcodes (symmetric, 0 to
--    itself). Places and kilometres only, no street or coordinate column (P-4, P-8). Phase A: seed values, `synthetic`.
-- 2. `public.team_service_postcodes`, `teams.max_distance_km`, `teams.reach_changed_at`: the team's reach. No write
--    grant; the only app writer is `public.set_team_reach` (AUT-117 (a): an active member of that team; an
--    organisation `admin` only for a team without active members). One audit row per accepted change with old and new
--    values (AUT-117 (d)).
-- 3. `public.order_offers`, `public.order_exclusions`: written once by `confirm_client_order` in the same transaction,
--    one row per team of the order's organisation (Phase A: own organisation only, PO 09:39 (4)). Hard filter BK-2
--    (distance part): reasons `team_not_active` (PO 09:39 (3)), `no_service_area`, `no_max_distance`,
--    `no_distance` (a pair missing from the table: fail-closed), `outside_radius`. Limit = the smaller of the team's
--    maximum and the order's optional radius (PO 18:40 (1)(c)). A team, never a person (P-5). The client reads none
--    (ADR-192 (3)). A later reach or shift-plan change never rewrites these rows (AUT-117 (b), PO 09:39 (7)).
-- 4. CGR-217: `preview_client_order` returns `info` (never a problem): `same_order_already_confirmed`.
-- No clinical, tariff or legal rule; distances are synthetic fixture values and state nothing about real travel.
-- Idempotent: `if not exists`, `create or replace`, `drop ... if exists`, `on conflict do nothing`.

-- 1. Distance table -----------------------------------------------------------------------------------------------------
create table if not exists public.postcode_distances (
  from_postcode  text not null references public.postcodes (postcode) on delete cascade,
  to_postcode    text not null references public.postcodes (postcode) on delete cascade,
  distance_km    numeric not null check (distance_km >= 0),
  source         text not null,
  source_version text not null,
  primary key (from_postcode, to_postcode),
  check ((from_postcode = to_postcode) = (distance_km = 0))
);
comment on table public.postcode_distances is
  'BK-b1 / ADR-193 (1), (2): distance between two listed postcodes (places only, P-8). Phase A: source = synthetic '
  '(seed fixture values, not road distances). Reference data; no app write. Data source for Phase B: lca P-5.';
alter table public.postcode_distances enable row level security;
revoke all on public.postcode_distances from public, anon, authenticated;
grant select on public.postcode_distances to authenticated;
drop policy if exists postcode_distances_read on public.postcode_distances;
create policy postcode_distances_read on public.postcode_distances for select to authenticated using (true);
drop policy if exists leave1_access_open on public.postcode_distances;
create policy leave1_access_open on public.postcode_distances as restrictive for all to authenticated
  using (not (select private.access_ended((select auth.uid()))));  -- LEAVE1-3

-- 2. The team's reach ---------------------------------------------------------------------------------------------------
alter table public.teams
  add column if not exists max_distance_km  numeric,
  add column if not exists reach_changed_at timestamptz;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'teams_max_distance_positive') then
    alter table public.teams add constraint teams_max_distance_positive
      check (max_distance_km is null or max_distance_km > 0);
  end if;
end;
$$;
comment on column public.teams.max_distance_km is
  'BK-b1 / PO 2026-11-13 18:40 (1)(a), AUT-117: the team''s own maximum travel distance (km). No NAVORA default. '
  'Written only by set_team_reach.';

create table if not exists public.team_service_postcodes (
  team_id    uuid not null references public.teams (id) on delete cascade,
  postcode   text not null references public.postcodes (postcode),
  created_at timestamptz not null default private.now(),
  primary key (team_id, postcode)
);
comment on table public.team_service_postcodes is
  'BK-b1 / ADR-193 (3), AUT-117: the team''s service postcodes. Written only by set_team_reach.';
alter table public.team_service_postcodes enable row level security;
revoke all on public.team_service_postcodes from public, anon, authenticated;
grant select on public.team_service_postcodes to authenticated;
drop policy if exists team_service_postcodes_read on public.team_service_postcodes;
create policy team_service_postcodes_read on public.team_service_postcodes for select to authenticated
  using (private.is_org_member(private.team_organization(team_id)));  -- app roles read no teams row directly
drop policy if exists leave1_access_open on public.team_service_postcodes;
create policy leave1_access_open on public.team_service_postcodes as restrictive for all to authenticated
  using (not (select private.access_ended((select auth.uid()))));  -- LEAVE1-3

-- set_team_reach writes its own audit row (old and new postcodes are not a column of teams); the row trigger on teams
-- stays as it is for every other path and is skipped only inside this one command, so a reach change is one row.
drop trigger if exists audit_teams on public.teams;
create trigger audit_teams
  after update on public.teams
  for each row
  when (coalesce(current_setting('navora.command', true), '') <> 'set_team_reach')
  execute function private.write_audit_event('priority', 'coach_name', 'status', 'open_slots', 'utilization', 'region');

insert into private.audit_value_classes (table_name, key, class) values
  ('teams', 'max_distance_km', 'code'), ('teams', 'service_postcodes', 'code')
on conflict do nothing;

create or replace function public.set_team_reach(
  p_team_id uuid, p_postcodes text[], p_max_distance_km numeric, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  t        public.teams;
  problems text[] := '{}';
  new_pcs  text[];
  old_pcs  text[];
  diff     jsonb := '{}'::jsonb;
begin
  if private.begin_command('set_team_reach', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into t from public.teams where id = p_team_id for update;
  -- AUT-117 (a): an active member of this team; an organisation admin only while the team has no active member.
  if uid is null or t.id is null
     or not (private.is_team_member(t.id)
             or (private.has_org_role(t.organization_id, array['admin'])
                 and not exists (select 1 from public.team_memberships m
                                 where m.team_id = t.id and not private.access_ended(m.user_id)))) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;

  new_pcs := coalesce((select array_agg(distinct btrim(x) order by btrim(x)) from unnest(p_postcodes) x
                       where nullif(btrim(x), '') is not null), '{}');
  if cardinality(new_pcs) = 0 then
    problems := array_append(problems, 'missing_service_postcode');
  elsif exists (select 1 from unnest(new_pcs) x where not exists (select 1 from public.postcodes p where p.postcode = x)) then
    problems := array_append(problems, 'postcode_not_in_list');
  end if;
  if p_max_distance_km is null or p_max_distance_km <= 0 then
    problems := array_append(problems, 'max_distance_not_positive');
  end if;
  if cardinality(problems) > 0 then
    perform private.end_command('invalid');
    return jsonb_build_object('result', 'invalid', 'problems', to_jsonb(problems));
  end if;

  old_pcs := coalesce((select array_agg(s.postcode order by s.postcode) from public.team_service_postcodes s
                       where s.team_id = t.id), '{}');
  if t.max_distance_km is distinct from p_max_distance_km then
    diff := diff || jsonb_build_object('max_distance_km',
                                       jsonb_build_object('old', to_jsonb(t.max_distance_km), 'new', to_jsonb(p_max_distance_km)));
  end if;
  if old_pcs is distinct from new_pcs then
    diff := diff || jsonb_build_object('service_postcodes',
                                       jsonb_build_object('old', to_jsonb(old_pcs), 'new', to_jsonb(new_pcs)));
  end if;
  if diff = '{}'::jsonb then
    perform private.end_command('ok');
    return jsonb_build_object('result', 'ok', 'changed', false);
  end if;

  delete from public.team_service_postcodes s where s.team_id = t.id and not (s.postcode = any (new_pcs));
  insert into public.team_service_postcodes (team_id, postcode)
    select t.id, x from unnest(new_pcs) x on conflict do nothing;
  update public.teams set max_distance_km = p_max_distance_km, reach_changed_at = private.now() where id = t.id;
  perform private.audit_command(t.organization_id, 'teams', t.id, diff);

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'changed', true);
end;
$$;
revoke all on function public.set_team_reach(uuid, text[], numeric, uuid) from public, anon;
grant execute on function public.set_team_reach(uuid, text[], numeric, uuid) to authenticated;

-- 3. Offer and exclusion rows -----------------------------------------------------------------------------------------
create table if not exists public.order_offers (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  order_id        uuid not null references public.partner_requests (id) on delete cascade,
  team_id         uuid not null references public.teams (id) on delete cascade,
  distance_km     numeric not null check (distance_km >= 0),
  limit_km        numeric not null check (limit_km > 0),
  created_at      timestamptz not null default private.now(),
  unique (order_id, team_id),
  check (distance_km <= limit_km)
);
create table if not exists public.order_exclusions (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  order_id        uuid not null references public.partner_requests (id) on delete cascade,
  team_id         uuid not null references public.teams (id) on delete cascade,
  reason          text not null check (reason in ('team_not_active', 'no_service_area', 'no_max_distance',
                                                  'no_distance', 'outside_radius')),
  created_at      timestamptz not null default private.now(),
  unique (order_id, team_id)
);
comment on table public.order_offers is
  'BK-b1 / BK-2n: a team that passed the hard filter for an order. Written once at confirmation; a team, never a '
  'person (P-5). Offer state and cascade: BK-c.';
comment on table public.order_exclusions is
  'BK-b1 / BK-2: a team that failed the hard filter for an order, with its reason. Written once at confirmation.';

do $$
declare tbl text;
begin
  foreach tbl in array array['order_offers', 'order_exclusions'] loop
    execute format('alter table public.%I enable row level security', tbl);
    execute format('revoke all on public.%I from public, anon, authenticated', tbl);
    execute format('grant select on public.%I to authenticated', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_read', tbl);
    execute format('create policy %I on public.%I for select to authenticated using '
                   '(private.has_org_role(organization_id, array[''operations'', ''admin'']) '
                   'or private.is_team_member(team_id))', tbl || '_read', tbl);
    execute format('drop policy if exists leave1_access_open on public.%I', tbl);
    execute format('create policy leave1_access_open on public.%I as restrictive for all to authenticated '
                   'using (not (select private.access_ended((select auth.uid()))))', tbl);  -- LEAVE1-3
    execute format('create index if not exists %I on public.%I (team_id)', tbl || '_team', tbl);
  end loop;
end;
$$;

-- The distance part of BK-2 for one order: every team of the order's organisation lands in exactly one table.
create or replace function private.screen_order_reach(p_order_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  o public.partner_requests;
  r record;
  why text;
begin
  select * into o from public.partner_requests where id = p_order_id;
  for r in
    select t.id, t.status, t.max_distance_km,
           exists (select 1 from public.team_service_postcodes s where s.team_id = t.id) as has_area,
           (select min(d.distance_km) from public.team_service_postcodes s
              join public.postcode_distances d on d.from_postcode = s.postcode and d.to_postcode = o.postcode
             where s.team_id = t.id) as dist,
           case when o.radius_km is null then t.max_distance_km
                else least(t.max_distance_km, o.radius_km) end as lim
    from public.teams t
    where t.organization_id = o.organization_id   -- Phase A: own organisation only (PO 09:39 (4))
  loop
    why := case when r.status is distinct from 'active' then 'team_not_active'
                when not r.has_area then 'no_service_area'
                when r.max_distance_km is null then 'no_max_distance'
                when r.dist is null then 'no_distance'
                when r.dist > r.lim then 'outside_radius' end;
    if why is null then
      insert into public.order_offers (organization_id, order_id, team_id, distance_km, limit_km)
        values (o.organization_id, o.id, r.id, r.dist, r.lim);
    else
      insert into public.order_exclusions (organization_id, order_id, team_id, reason)
        values (o.organization_id, o.id, r.id, why);
    end if;
  end loop;
end;
$$;
revoke all on function private.screen_order_reach(uuid) from public, anon, authenticated;

-- «Bestätigen & Absenden» (0129) plus the screening in the same transaction.
create or replace function public.confirm_client_order(
  p_client_account_id uuid, p_start_date date, p_start_time time, p_end_time time, p_postcode text, p_grade text,
  p_activity_tags text[], p_required_tags text[], p_radius_km numeric, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  chk jsonb;
  new_id uuid;
begin
  if uid is null or p_client_account_id is null or not private.is_client_member(p_client_account_id) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if private.begin_command('confirm_client_order', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  chk := private.client_order_check(p_client_account_id, p_start_date, p_start_time, p_end_time, p_postcode, p_grade,
                                    p_activity_tags, p_required_tags, p_radius_km);
  if jsonb_array_length(chk -> 'problems') > 0 then
    perform private.end_command('invalid');
    return jsonb_build_object('result', 'invalid', 'problems', chk -> 'problems');
  end if;

  insert into public.partner_requests
    (organization_id, partner_name, partner_type, region, city, urgency, urgency_source, request_title, need_summary,
     status, order_kind, client_account_id, starts_at, ends_at, postcode, grade, activity_tags, required_tags,
     radius_km, shift_label, confirmed_at, confirmed_by)
  values
    ((chk ->> 'organization_id')::uuid, chk ->> 'display_name', chk ->> 'client_kind', chk ->> 'region_name',
     chk ->> 'place_name', null, 'unknown', chk ->> 'sentence', chk ->> 'sentence',
     'client_confirmed', 'shift', p_client_account_id, (chk ->> 'starts_at')::timestamptz,
     (chk ->> 'ends_at')::timestamptz, chk ->> 'postcode', p_grade,
     (select array_agg(distinct t order by t) from unnest(p_activity_tags) t),
     coalesce((select array_agg(distinct t order by t) from unnest(p_required_tags) t), '{}'),
     p_radius_km, chk ->> 'shift_label', private.now(), uid)
  returning id into new_id;

  perform private.screen_order_reach(new_id);  -- BK-b1: BK-2 distance part, BK-2n

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'order_id', new_id);
end;
$$;
revoke all on function public.confirm_client_order(uuid, date, time, time, text, text, text[], text[], numeric, uuid)
  from public, anon;
grant execute on function public.confirm_client_order(uuid, date, time, time, text, text, text[], text[], numeric, uuid)
  to authenticated;

-- 4. CGR-217: the same order twice is an information item, never a problem ---------------------------------------------
create or replace function public.preview_client_order(
  p_client_account_id uuid, p_start_date date, p_start_time time, p_end_time time, p_postcode text, p_grade text,
  p_activity_tags text[], p_required_tags text[], p_radius_km numeric)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select (r - 'organization_id')
         || jsonb_build_object('info', case when same.sentence is null then '[]'::jsonb
                                            else '["same_order_already_confirmed"]'::jsonb end,
                               'same_order_sentence', same.sentence)
  from private.client_order_check(p_client_account_id, p_start_date, p_start_time, p_end_time, p_postcode, p_grade,
                                  p_activity_tags, p_required_tags, p_radius_km) r
  left join lateral (
    select p.request_title as sentence from public.partner_requests p
    where jsonb_array_length(r -> 'problems') = 0
      and p.client_account_id = p_client_account_id and p.status = 'client_confirmed'
      and p.starts_at = (r ->> 'starts_at')::timestamptz and p.ends_at = (r ->> 'ends_at')::timestamptz
      and p.grade = p_grade and p.postcode = r ->> 'postcode'
    order by p.confirmed_at limit 1) same on true
$$;
revoke all on function public.preview_client_order(uuid, date, time, time, text, text, text[], text[], numeric)
  from public, anon;
grant execute on function public.preview_client_order(uuid, date, time, time, text, text, text[], text[], numeric)
  to authenticated;
