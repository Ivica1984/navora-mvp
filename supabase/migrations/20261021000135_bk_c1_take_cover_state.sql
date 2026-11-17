-- BK-c1 (brief docs/agents/briefs/BK.md, slice BK-c; ADR-199; pgTAP 141). Gate «Simulation, synthetic data» only.
-- Broadcast take (FE-078 part 2), decline, the team's offer list, the client's derived cover state, the Operations
-- exception `order_not_covered`, re-coverage by screening rounds when the named member stops passing (CGR-223), and the
-- backfill of confirmed orders without screening rows (CGR-215 (b)).
--
-- No clinical, legal or tariff rule is set here. The coverage lead (240 minutes) is a simulation default, PROPOSED
-- (ADR-199 (7)); the Clinical Owner confirms or replaces it before real data (K-8, OPEN). Nobody assigns an order for a
-- team (FE-039): only an active member of a team takes for it, naming a member of that team.
-- Idempotent: `if not exists`, `create or replace`, patches of current definitions carrying the marker BK-C1, rule row
-- `on conflict do nothing`.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.bk_c1_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0135 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0135 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_c1_patch(text, text[], text) from public, anon, authenticated;

-- 1. Screening rounds (ADR-199 (2)) -------------------------------------------------------------------------------------
alter table public.order_offers     add column if not exists round integer not null default 1 check (round >= 1);
alter table public.order_exclusions add column if not exists round integer not null default 1 check (round >= 1);
alter table public.order_offers     drop constraint if exists order_offers_order_id_team_id_key;
alter table public.order_exclusions drop constraint if exists order_exclusions_order_id_team_id_key;
create unique index if not exists order_offers_order_round_team on public.order_offers (order_id, round, team_id);
create unique index if not exists order_exclusions_order_round_team on public.order_exclusions (order_id, round, team_id);
comment on table public.order_offers is
  'BK-b1 / BK-2n / BK-c1: a team that passed the hard filter for an order in one screening round. Round 1 at '
  'confirmation; a new round only when a take is released (CGR-223). Rows are never changed; a team, never a person.';
comment on table public.order_exclusions is
  'BK-b1/BK-b2 / BK-2 / BK-c1: a team that failed the hard filter for an order in one screening round, with its reason '
  '(a step, never a person). Rows are never changed.';

create or replace function private.order_round(p_order_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select coalesce(greatest((select max(o.round) from public.order_offers o where o.order_id = p_order_id),
                           (select max(x.round) from public.order_exclusions x where x.order_id = p_order_id)), 0)
$$;
revoke all on function private.order_round(uuid) from public, anon, authenticated;

-- 2. Coverage lead (ADR-199 (7), PROPOSED simulation default) -----------------------------------------------------------
alter table public.cover_settings add column if not exists order_latest_cover_lead_minutes integer not null default 240
  check (order_latest_cover_lead_minutes between 0 and 4320);
comment on column public.cover_settings.order_latest_cover_lead_minutes is
  'BK-c1 / CGR-222 / ADR-199 (7): minutes before a shift order''s start at which an untaken order is «nicht gedeckt» and '
  'raised to Operations. 240 = simulation default, PROPOSED (same value as fallback_lead_hours); Clinical Owner before '
  'real data (K-8).';

create or replace function private.order_latest_cover_at(p_order_id uuid)
returns timestamptz language sql stable security definer set search_path = ''
as $$
  select p.starts_at - make_interval(mins => coalesce(
           (select s.order_latest_cover_lead_minutes from public.cover_settings s where s.organization_id = p.organization_id),
           (select s.order_latest_cover_lead_minutes from public.cover_settings s where s.organization_id is null),
           240))
  from public.partner_requests p where p.id = p_order_id
$$;
revoke all on function private.order_latest_cover_at(uuid) from public, anon, authenticated;

-- 3. Takes and declines (ADR-199 (3), (4)) ------------------------------------------------------------------------------
create table if not exists public.order_takes (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  order_id        uuid not null references public.partner_requests (id) on delete cascade,
  round           integer not null check (round >= 1),
  team_id         uuid not null references public.teams (id) on delete cascade,
  member_id       uuid not null,
  taken_by        uuid not null,
  taken_at        timestamptz not null default private.now(),
  released_at     timestamptz,
  release_reason  text check (release_reason in ('step_0', 'step_1', 'step_2', 'step_3')),
  check ((released_at is null) = (release_reason is null))
);
create unique index if not exists order_takes_one_live on public.order_takes (order_id) where released_at is null;
create index if not exists order_takes_member on public.order_takes (member_id) where released_at is null;
comment on table public.order_takes is
  'BK-c1 / BK-5a / CGR-211: the take of a shift order by a team, naming one member who passed the hard re-check. At most '
  'one live take per order. Released (never deleted) when the member stops passing before the start (CGR-223); the '
  'reason is a step code of private.order_member_step, never a person''s data. Written only by commands and triggers.';

create table if not exists public.order_declines (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  order_id        uuid not null references public.partner_requests (id) on delete cascade,
  round           integer not null check (round >= 1),
  team_id         uuid not null references public.teams (id) on delete cascade,
  declined_by     uuid not null,
  declined_at     timestamptz not null default private.now(),
  unique (order_id, round, team_id)
);
comment on table public.order_declines is
  'BK-c1 / FE-078 part 2: a team declined an offer for one screening round. No reason is asked (PO 2026-11-14 21:39 (1)).';

do $$
declare tbl text;
begin
  foreach tbl in array array['order_takes', 'order_declines'] loop
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

drop trigger if exists audit_order_takes on public.order_takes;
create trigger audit_order_takes after insert or update on public.order_takes
  for each row execute function private.write_audit_event('order_id', 'round', 'team_id', 'member_id', 'released_at',
                                                          'release_reason');
drop trigger if exists audit_order_declines on public.order_declines;
create trigger audit_order_declines after insert on public.order_declines
  for each row execute function private.write_audit_event('order_id', 'round', 'team_id');
insert into private.audit_value_classes (table_name, key, class) values
  ('order_takes', 'order_id', 'code'), ('order_takes', 'round', 'code'), ('order_takes', 'team_id', 'code'),
  ('order_takes', 'member_id', 'code'), ('order_takes', 'released_at', 'code'), ('order_takes', 'release_reason', 'code'),
  ('order_declines', 'order_id', 'code'), ('order_declines', 'round', 'code'), ('order_declines', 'team_id', 'code')
on conflict do nothing;

-- 4. The member step: one more availability source (AUT-130, CGR-224); 0133 body otherwise unchanged ---------------------
create or replace function private.order_member_step(p_order_id uuid, p_team_id uuid, p_user_id uuid)
returns integer language plpgsql stable security definer set search_path = ''
as $$
declare
  o    public.partner_requests;
  g    record;
  kind text;
begin
  select * into o from public.partner_requests where id = p_order_id;
  if o.id is null or o.starts_at is null or o.ends_at is null then return 0; end if;
  if not private.user_in_team(p_team_id, p_user_id) or private.access_ended(p_user_id) then return 0; end if;  -- LEAVE1-3

  -- Level: verified, equal to the ordered grade, still valid at the end of the slot (QUAL1-2, -4; CGR-205 (d)).
  select * into g from private.qual_evidence_state(o.organization_id, p_user_id, 'grade', o.ends_at);
  if g.state is distinct from 'verified' or g.grade is distinct from o.grade then return 1; end if;

  -- Activities: the one reading of 0133 (CGR-218 (A), CGR-219), through the client kind of the order's account.
  select a.client_kind into kind from public.client_accounts a where a.id = o.client_account_id;
  if not private.member_activity_ok(o.organization_id, p_user_id, kind, o.grade, o.activity_tags, o.required_tags,
                                    o.ends_at) then
    return 2;
  end if;

  -- Availability for the whole slot [start, end): her absences in any team, her open visits, and (BK-c1, AUT-130,
  -- CGR-224) her live take of ANOTHER shift order whose slot overlaps. The own order never counts.
  if exists (select 1 from public.member_absences x
             where x.user_id = p_user_id and x.withdrawn_at is null
               and x.starts_at < o.ends_at and x.ends_at > o.starts_at)
     or exists (select 1 from public.care_visits v
                where (v.responsible_user_id = p_user_id or v.covered_by = p_user_id)
                  and v.status in ('planned', 'on_the_way', 'started', 'paused')
                  and private.visit_interval(v) && tstzrange(o.starts_at, o.ends_at, '[)'))
     or exists (select 1 from public.order_takes k
                join public.partner_requests q on q.id = k.order_id
                where k.member_id = p_user_id and k.released_at is null and k.order_id <> o.id
                  and q.starts_at < o.ends_at and q.ends_at > o.starts_at) then
    return 3;
  end if;
  return 4;
end;
$$;
revoke all on function private.order_member_step(uuid, uuid, uuid) from public, anon, authenticated;
comment on function private.order_member_step(uuid, uuid, uuid) is
  'BK-b2 / CGR-204 (a) / ADR-196, 0133, BK-c1 0135: how far one member gets for one order (0 not active, 1 level, '
  '2 activity, 3 availability for the whole slot incl. a live take of another overlapping order (AUT-130, CGR-224), '
  '4 eligible). The one eligibility function for screening and take. Private.';

-- 5. Screening by round (0132 body plus the round) ----------------------------------------------------------------------
create or replace function private.screen_order_reach(p_order_id uuid, p_round integer)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  o    public.partner_requests;
  r    record;
  why  text;
  best integer;
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
      -- CGR-204 (a): one and the same member must reach step 4; the furthest step any member reached names the reason.
      select coalesce(max(private.order_member_step(o.id, r.id, m.user_id)), 0) into best
      from public.team_memberships m where m.team_id = r.id;
      why := case best when 4 then null when 3 then 'no_member_available' when 2 then 'no_member_activity_evidence'
                       when 1 then 'no_member_with_grade' else 'no_active_member' end;
    end if;
    if why is null then
      insert into public.order_offers (organization_id, order_id, team_id, distance_km, limit_km, round)
        values (o.organization_id, o.id, r.id, r.dist, r.lim, p_round);
    else
      insert into public.order_exclusions (organization_id, order_id, team_id, reason, round)
        values (o.organization_id, o.id, r.id, why, p_round);
    end if;
  end loop;
end;
$$;
revoke all on function private.screen_order_reach(uuid, integer) from public, anon, authenticated;

-- The one-argument form stays the confirmation's call (0132 confirm_client_order, unchanged): round 1.
create or replace function private.screen_order_reach(p_order_id uuid)
returns void language sql security definer set search_path = ''
as $$ select private.screen_order_reach(p_order_id, 1) $$;
revoke all on function private.screen_order_reach(uuid) from public, anon, authenticated;

-- 6. Cover state, derived on read (ADR-199 (6); BK-6, CGR-222, CGR-225) -------------------------------------------------
create or replace function private.order_cover(p_order_id uuid, p_at timestamptz)
returns table (cover_state text, cover_detail text, take_team_id uuid, taken_at timestamptz, latest_cover_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
declare
  o    public.partner_requests;
  k    public.order_takes;
  rnd  integer;
  lat  timestamptz;
  offs integer;
  decl integer;
begin
  select * into o from public.partner_requests where id = p_order_id;
  if o.id is null or o.order_kind is null then return; end if;
  lat := private.order_latest_cover_at(o.id);
  select * into k from public.order_takes t where t.order_id = o.id and t.released_at is null;
  if k.id is not null and private.order_member_step(o.id, k.team_id, k.member_id) = 4 then
    return query select 'covered'::text, null::text, k.team_id, k.taken_at, lat;
    return;
  end if;
  if k.id is not null then
    -- Safety net (ADR-199 (5)): a live take whose member no longer passes is never shown as covered. For the time-based
    -- states it counts as released (pgTAP 142 §2), so a path no recheck trigger sees still raises the Operations
    -- exception at the latest coverage time (ADR-199 (9)).
    if p_at >= o.starts_at then
      return query select 'not_covered'::text, 'started'::text, null::uuid, null::timestamptz, lat;
    elsif p_at >= lat then
      return query select 'not_covered'::text, 'cover_time_reached'::text, null::uuid, null::timestamptz, lat;
    else
      return query select 'no_longer_covered'::text, null::text, null::uuid, null::timestamptz, lat;
    end if;
    return;
  end if;
  rnd := private.order_round(o.id);
  select count(*) into offs from public.order_offers f where f.order_id = o.id and f.round = rnd;
  select count(*) into decl from public.order_declines d where d.order_id = o.id and d.round = rnd;
  if p_at >= o.starts_at then
    return query select 'not_covered'::text, 'started'::text, null::uuid, null::timestamptz, lat;
  elsif offs = 0 then
    return query select 'not_covered'::text, 'no_team_eligible'::text, null::uuid, null::timestamptz, lat;  -- CGR-225
  elsif decl >= offs then
    return query select 'not_covered'::text, 'all_declined'::text, null::uuid, null::timestamptz, lat;
  elsif p_at >= lat then
    return query select 'not_covered'::text, 'cover_time_reached'::text, null::uuid, null::timestamptz, lat;  -- CGR-222
  elsif exists (select 1 from public.order_takes t where t.order_id = o.id) then
    return query select 'no_longer_covered'::text, null::text, null::uuid, null::timestamptz, lat;  -- CGR-223 (b)
  else
    return query select 'open'::text, null::text, null::uuid, null::timestamptz, lat;
  end if;
end;
$$;
revoke all on function private.order_cover(uuid, timestamptz) from public, anon, authenticated;

-- Own orders only (ADR-192 (3)); the team name only after a take (lca G-3); no team count of any kind (D-44 (2) (a)),
-- no reason, no member. The return type changes, so the 0129 function is dropped and created again.
drop function if exists public.client_orders();
create function public.client_orders()
returns table (id uuid, client_account_id uuid, sentence text, starts_at timestamptz, ends_at timestamptz,
               duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[],
               required_tags text[], radius_km numeric, shift_label text, confirmed_at timestamptz, cover_state text,
               cover_detail text, latest_cover_at timestamptz, covered_team_name text, taken_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.client_account_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, p.radius_km, p.shift_label, p.confirmed_at, c.cover_state, c.cover_detail, c.latest_cover_at,
         (select t.name from public.teams t where t.id = c.take_team_id), c.taken_at
  from public.partner_requests p
  cross join lateral private.order_cover(p.id, private.now()) c
  where p.order_kind is not null and private.is_client_member(p.client_account_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by p.starts_at
$$;
revoke all on function public.client_orders() from public, anon;
grant execute on function public.client_orders() to authenticated;

-- 7. Take (ADR-199 (3); BK-5a, BK-5n, CGR-211, CGR-224) -----------------------------------------------------------------
create or replace function public.take_order(p_order_id uuid, p_team_id uuid, p_member_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  o    public.partner_requests;
  rnd  integer;
  step integer;
  new_id uuid;
begin
  if uid is null or p_order_id is null or p_team_id is null or p_member_id is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if private.begin_command('take_order', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  -- Serialises every take of one order (CGR-211); the partial unique index is the backstop.
  select * into o from public.partner_requests where id = p_order_id and order_kind is not null for update;
  if not private.is_team_member(p_team_id) then  -- FE-039 / BK-5n: own team only (LEAVE1-3 inside)
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'not_team_member');
  end if;
  if not private.user_in_team(p_team_id, p_member_id) or private.access_ended(p_member_id) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'member_not_in_team');
  end if;
  rnd := case when o.id is null then 0 else private.order_round(o.id) end;
  if o.id is null
     or not exists (select 1 from public.order_offers f where f.order_id = o.id and f.round = rnd and f.team_id = p_team_id)
     or exists (select 1 from public.order_declines d where d.order_id = o.id and d.round = rnd and d.team_id = p_team_id) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'not_offered');
  end if;
  if exists (select 1 from public.order_takes t where t.order_id = o.id and t.released_at is null) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'already_taken');
  end if;
  if o.starts_at <= private.now() then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'order_started');
  end if;
  step := private.order_member_step(o.id, p_team_id, p_member_id);  -- CGR-204 (b): the fresh hard re-check
  if step < 4 then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'member_not_eligible', 'step', step);
  end if;
  insert into public.order_takes (organization_id, order_id, round, team_id, member_id, taken_by)
    values (o.organization_id, o.id, rnd, p_team_id, p_member_id, uid)
    returning id into new_id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'take_id', new_id);
end;
$$;
revoke all on function public.take_order(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.take_order(uuid, uuid, uuid, uuid) to authenticated;

-- 8. Decline (ADR-199 (4)) ------------------------------------------------------------------------------------------------
create or replace function public.decline_order(p_order_id uuid, p_team_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  o   public.partner_requests;
  rnd integer;
begin
  if uid is null or p_order_id is null or p_team_id is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if private.begin_command('decline_order', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into o from public.partner_requests where id = p_order_id and order_kind is not null for update;
  if not private.is_team_member(p_team_id) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'not_team_member');
  end if;
  rnd := case when o.id is null then 0 else private.order_round(o.id) end;
  if o.id is null
     or not exists (select 1 from public.order_offers f where f.order_id = o.id and f.round = rnd and f.team_id = p_team_id) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'not_offered');
  end if;
  if exists (select 1 from public.order_declines d where d.order_id = o.id and d.round = rnd and d.team_id = p_team_id) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'already_declined');
  end if;
  if exists (select 1 from public.order_takes t where t.order_id = o.id and t.released_at is null and t.team_id = p_team_id) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'taken_by_us');
  end if;
  insert into public.order_declines (organization_id, order_id, round, team_id, declined_by)
    values (o.organization_id, o.id, rnd, p_team_id, uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.decline_order(uuid, uuid, uuid) from public, anon;
grant execute on function public.decline_order(uuid, uuid, uuid) to authenticated;

-- 9. The team's offer list (ADR-199 (8); V-8, AUT-128, H-BK-15:39) ---------------------------------------------------------
-- Exactly the offer rows of the current round of the caller's own teams, minus own declines, minus orders another team
-- holds. Never another team, a count or a rank (template §2). Committed rows only, so a take is seen once committed.
create or replace function public.team_order_offers()
returns table (order_id uuid, team_id uuid, sentence text, starts_at timestamptz, ends_at timestamptz,
               duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[],
               required_tags text[], distance_km numeric, limit_km numeric, offer_state text, taken_member_id uuid)
language sql stable security definer set search_path = ''
as $$
  select f.order_id, f.team_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, f.distance_km, f.limit_km,
         case when k.id is null then 'open' else 'taken_by_us' end, k.member_id
  from public.order_offers f
  join public.partner_requests p on p.id = f.order_id
  left join public.order_takes k on k.order_id = f.order_id and k.released_at is null
  where private.is_team_member(f.team_id)   -- LEAVE1-3 inside
    and f.round = private.order_round(f.order_id)
    and p.ends_at > private.now()
    and not exists (select 1 from public.order_declines d
                    where d.order_id = f.order_id and d.round = f.round and d.team_id = f.team_id)
    and (k.id is null or k.team_id = f.team_id)
  order by p.starts_at, f.order_id, f.team_id
$$;
revoke all on function public.team_order_offers() from public, anon;
grant execute on function public.team_order_offers() to authenticated;

-- 10. Re-coverage when the named member stops passing (ADR-199 (5); CGR-223) ----------------------------------------------
create or replace function private.recheck_member_takes(p_user uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  k    record;
  step integer;
begin
  if p_user is null then return; end if;
  for k in
    select t.id, t.order_id, t.team_id, t.member_id
    from public.order_takes t join public.partner_requests p on p.id = t.order_id
    where t.member_id = p_user and t.released_at is null and p.starts_at > private.now()
    order by p.starts_at, t.id
  loop
    step := private.order_member_step(k.order_id, k.team_id, k.member_id);
    if step < 4 then
      update public.order_takes set released_at = private.now(), release_reason = 'step_' || step where id = k.id;
      -- CGR-223 (c): back to the broadcast after a fresh hard check of every team (the releasing team included).
      perform private.screen_order_reach(k.order_id, private.order_round(k.order_id) + 1);
    end if;
  end loop;
end;
$$;
revoke all on function private.recheck_member_takes(uuid) from public, anon, authenticated;

create or replace function private.recheck_takes_trigger()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_table_name = 'care_visits' then
    perform private.recheck_member_takes(new.responsible_user_id);
    perform private.recheck_member_takes(new.covered_by);
  elsif tg_table_name = 'team_memberships' then
    -- Writer list (ADR-199 (5), pgTAP 142): `remove_team_member` deletes the row and writes no access event.
    if tg_op in ('DELETE', 'UPDATE') then perform private.recheck_member_takes(old.user_id); end if;
    if tg_op = 'UPDATE' and new.user_id is distinct from old.user_id then
      perform private.recheck_member_takes(new.user_id);
    end if;
  else
    perform private.recheck_member_takes(new.user_id);
  end if;
  return null;
end;
$$;
revoke all on function private.recheck_takes_trigger() from public, anon, authenticated;

-- The sources of order_member_step that can turn a passing member into a failing one (absence, access end, evidence,
-- open visit) and, from the writer list (ADR-199 (5), pgTAP 142), team membership: `remove_team_member` deletes the
-- `team_memberships` row without a `member_access_events` row, so it needs its own trigger.
drop trigger if exists bk_c1_recheck_takes on public.member_absences;
create trigger bk_c1_recheck_takes after insert or update on public.member_absences
  for each row execute function private.recheck_takes_trigger();
drop trigger if exists bk_c1_recheck_takes on public.member_access_events;
create trigger bk_c1_recheck_takes after insert on public.member_access_events
  for each row execute function private.recheck_takes_trigger();
drop trigger if exists bk_c1_recheck_takes on public.member_qualification_evidence;
create trigger bk_c1_recheck_takes after insert on public.member_qualification_evidence
  for each row execute function private.recheck_takes_trigger();
drop trigger if exists bk_c1_recheck_takes on public.care_visits;
create trigger bk_c1_recheck_takes after insert or update of status, responsible_user_id, covered_by, visit_date,
  time_start, time_end on public.care_visits
  for each row execute function private.recheck_takes_trigger();
drop trigger if exists bk_c1_recheck_takes on public.team_memberships;
create trigger bk_c1_recheck_takes after delete or update of team_id, user_id on public.team_memberships
  for each row execute function private.recheck_takes_trigger();

-- 11. Operations exception `order_not_covered` (ADR-199 (9); BK-6, CGR-215 (c), CGR-222, CGR-225) ------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('order_not_covered', 'P2', null, null, null, 'Schichtauftrag nicht gedeckt',
   'Kein Team hat diese Schicht übernommen. Nie einem Team zuweisen: Teams übernehmen selbst.')
on conflict (exception_type) do nothing;

-- `since` is the latest coverage time, so order exceptions sort by time to start within their priority (CGR-215 (c)).
select private.bk_c1_patch('private.derived_exceptions(uuid)', array[
  E'  union all\n  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)\n',
  E'  union all\n'
  || E'  -- BK-C1 (ADR-199 (9)): a confirmed shift order that is not covered (closes with its cause)\n'
  || E'  select ''order_not_covered:'' || p.id, ''order_not_covered'', c.latest_cover_at, null::uuid, null::uuid,\n'
  || E'         ''order'', p.id, c.cover_detail\n'
  || E'  from public.partner_requests p\n'
  || E'  cross join lateral private.order_cover(p.id, private.now()) c\n'
  || E'  join rules r on r.exception_type = ''order_not_covered''\n'
  || E'  where p.organization_id = p_org and p.order_kind is not null and p.confirmed_at is not null\n'
  || E'    and c.cover_state = ''not_covered''\n'
  || E'  union all\n  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)\n',
  '1'], 'BK-C1');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

select private.bk_c1_patch('private.exception_closes_with_cause(uuid, text)', array[
  E'''case_reopened_no_team'', ''case_reopened_team_inactive'' /* SAFE-D11 */)',
  E'''case_reopened_no_team'', ''case_reopened_team_inactive'' /* SAFE-D11 */, ''order_not_covered'' /* BK-C1 */)',
  '1'], 'BK-C1');
revoke all on function private.exception_closes_with_cause(uuid, text) from public, anon, authenticated;

select private.bk_c1_patch('public.operations_exceptions()', array[
  E'''case_reopened_no_team'', ''case_reopened_team_inactive'' /* SAFE-D11 */)',
  E'''case_reopened_no_team'', ''case_reopened_team_inactive'' /* SAFE-D11 */, ''order_not_covered'' /* BK-C1 */)',
  '2'], 'BK-C1');

-- 12. Backfill: confirmed orders without screening rows (ADR-199 (10); CGR-215 (b)) ---------------------------------------
create or replace function private.screen_unscreened_orders()
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select p.id from public.partner_requests p
    where p.order_kind is not null and p.confirmed_at is not null and p.starts_at > private.now()
      and private.order_round(p.id) = 0
    order by p.starts_at, p.id
  loop
    perform private.screen_order_reach(r.id, 1);
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function private.screen_unscreened_orders() from public, anon, authenticated;
select private.screen_unscreened_orders();

drop function private.bk_c1_patch(text, text[], text);
