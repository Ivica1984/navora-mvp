-- BK-c2 database part (brief docs/agents/briefs/BK.md, PO 2026-11-17 04:39 (3), 05:39 (3), 08:39 (2)-(4), 09:39 (2);
-- ADR-200; pgTAP 144). Gate «Simulation, synthetic data» only.
-- A take naming a colleague needs her acknowledgement (CGR-230) and lapses at the latest coverage time without it;
-- «Ich kann nicht» releases at once with its own code (UXR-222, CGR-234); the client reads one neutral zero state
-- (F-1) and «noch nicht gedeckt» before the acknowledgement (UXR-223); the team reads its take, the release and the
-- caller's own «frei» (UXR-221, CGR-234 (d), AUT-132).
--
-- No clinical, legal or tariff rule is set here. The coverage lead stays the PROPOSED 240 min simulation default (K-8).
-- Nobody assigns for a team (FE-039). Idempotent: `if not exists`, `create or replace`, patches carrying the marker
-- BK-C2, `on conflict do nothing`.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.bk_c2_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0136 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0136 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_c2_patch(text, text[], text) from public, anon, authenticated;

-- 1. Acknowledgement and the person's release on the take (ADR-200 (1), (3); CGR-230, CGR-234 (a)) -------------------
alter table public.order_takes add column if not exists acknowledged_at timestamptz;
alter table public.order_takes add column if not exists released_by uuid;
alter table public.order_takes drop constraint if exists order_takes_release_reason_check;
alter table public.order_takes add constraint order_takes_release_reason_check
  check (release_reason in ('step_0', 'step_1', 'step_2', 'step_3', 'member_cannot', 'not_acknowledged'));
alter table public.order_takes drop constraint if exists order_takes_released_by_check;
alter table public.order_takes add constraint order_takes_released_by_check
  check ((release_reason is not distinct from 'member_cannot') = (released_by is not null));
comment on column public.order_takes.acknowledged_at is
  'BK-c2 / CGR-230 / ADR-200 (1): when the named member acknowledged the take. Set at the take when she is the caller; '
  'null until she acknowledges otherwise. A take never acknowledged by the latest coverage time lapses (not_acknowledged).';
comment on column public.order_takes.released_by is
  'BK-c2 / CGR-234 (a): the named member who said «Ich kann nicht» (release_reason member_cannot). No reason is stored.';
-- Self-named takes count as acknowledged. Takes naming a colleague are NOT backfilled (ADR-200 (1)): lapse is safe.
update public.order_takes set acknowledged_at = taken_at
  where acknowledged_at is null and member_id = taken_by;

drop trigger if exists audit_order_takes on public.order_takes;
create trigger audit_order_takes after insert or update on public.order_takes
  for each row execute function private.write_audit_event('order_id', 'round', 'team_id', 'member_id', 'released_at',
                                                          'release_reason', 'acknowledged_at', 'released_by');
insert into private.audit_value_classes (table_name, key, class) values
  ('order_takes', 'acknowledged_at', 'code'), ('order_takes', 'released_by', 'code')
on conflict do nothing;

-- 2. «Ich kann nicht» is a non-availability for that one order (ADR-200 (4); PO 08:39 (2)) ------------------------------
select private.bk_c2_patch('private.order_member_step(uuid, uuid, uuid)', array[
  E'                  and q.starts_at < o.ends_at and q.ends_at > o.starts_at) then\n    return 3;',
  E'                  and q.starts_at < o.ends_at and q.ends_at > o.starts_at)\n'
  || E'     -- BK-C2 (ADR-200 (4)): she said «Ich kann nicht» for THIS order; never re-offered as the going person.\n'
  || E'     or exists (select 1 from public.order_takes c\n'
  || E'                where c.order_id = o.id and c.member_id = p_user_id and c.release_reason = ''member_cannot'') then\n'
  || E'    return 3;',
  '1'], 'BK-C2');
revoke all on function private.order_member_step(uuid, uuid, uuid) from public, anon, authenticated;

-- 3. Lapse at the latest coverage time (ADR-200 (2); CGR-230) ----------------------------------------------------------
-- The caller holds the order row lock (commands) or takes it (sweep). Never after the start (CGR-234 (c)).
create or replace function private.lapse_unacknowledged_take(p_order_id uuid)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare
  kid uuid;
begin
  if p_order_id is null then return false; end if;
  select t.id into kid
  from public.order_takes t join public.partner_requests p on p.id = t.order_id
  where t.order_id = p_order_id and t.released_at is null and t.acknowledged_at is null
    and private.now() >= private.order_latest_cover_at(p_order_id) and p.starts_at > private.now();
  if kid is null then return false; end if;
  update public.order_takes set released_at = private.now(), release_reason = 'not_acknowledged' where id = kid;
  perform private.screen_order_reach(p_order_id, private.order_round(p_order_id) + 1);  -- ADR-199 release path
  return true;
end;
$$;
revoke all on function private.lapse_unacknowledged_take(uuid) from public, anon, authenticated;

create or replace function private.lapse_unacknowledged_takes()
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select t.order_id from public.order_takes t join public.partner_requests p on p.id = t.order_id
    where t.released_at is null and t.acknowledged_at is null and p.starts_at > private.now()
      and private.now() >= private.order_latest_cover_at(t.order_id)
    order by p.starts_at, t.order_id
  loop
    perform 1 from public.partner_requests where id = r.order_id for update;
    if private.lapse_unacknowledged_take(r.order_id) then n := n + 1; end if;
  end loop;
  return n;
end;
$$;
revoke all on function private.lapse_unacknowledged_takes() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      execute $cron$select cron.schedule('navora-bk-c2-lapse', '* * * * *', 'select private.lapse_unacknowledged_takes()')$cron$;
    exception when others then
      raise notice 'BK-c2: lapse job not scheduled (%); every order command lapses its own order first', sqlerrm;
    end;
  else
    raise notice 'BK-c2: pg_cron not available; every order command lapses its own order first';
  end if;
end;
$$;

-- 4. Take and decline lapse their order first; a self-named take is acknowledged at once (ADR-200 (1), (2)) ----------
select private.bk_c2_patch('public.take_order(uuid, uuid, uuid, uuid)', array[
  E'order_kind is not null for update;\n',
  E'order_kind is not null for update;\n'
  || E'  perform private.lapse_unacknowledged_take(o.id);  -- BK-C2 (ADR-200 (2))\n',
  '1',
  E'insert into public.order_takes (organization_id, order_id, round, team_id, member_id, taken_by)\n'
  || E'    values (o.organization_id, o.id, rnd, p_team_id, p_member_id, uid)',
  E'insert into public.order_takes (organization_id, order_id, round, team_id, member_id, taken_by, acknowledged_at)\n'
  || E'    values (o.organization_id, o.id, rnd, p_team_id, p_member_id, uid,\n'
  || E'            case when p_member_id = uid then private.now() end)  -- CGR-230: self-named needs no acknowledgement',
  '1'], 'BK-C2');
revoke all on function public.take_order(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.take_order(uuid, uuid, uuid, uuid) to authenticated;

select private.bk_c2_patch('public.decline_order(uuid, uuid, uuid)', array[
  E'order_kind is not null for update;\n',
  E'order_kind is not null for update;\n'
  || E'  perform private.lapse_unacknowledged_take(o.id);  -- BK-C2 (ADR-200 (2))\n',
  '1'], 'BK-C2');
revoke all on function public.decline_order(uuid, uuid, uuid) from public, anon;
grant execute on function public.decline_order(uuid, uuid, uuid) to authenticated;

-- 5. Cover state: a take awaiting acknowledgement never covers (ADR-200 (2); CGR-230, UXR-223) -------------------------
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
    if k.acknowledged_at is not null then
      return query select 'covered'::text, null::text, k.team_id, k.taken_at, lat;
    elsif p_at >= o.starts_at then
      return query select 'not_covered'::text, 'started'::text, null::uuid, null::timestamptz, lat;
    elsif p_at >= lat then
      -- CGR-230: not acknowledged by the latest coverage time → counts as released (the commands materialise it).
      return query select 'not_covered'::text, 'not_acknowledged'::text, null::uuid, null::timestamptz, lat;
    else
      return query select 'pending_acknowledgement'::text, null::text, k.team_id, k.taken_at, lat;
    end if;
    return;
  end if;
  if k.id is not null then
    -- Safety net (ADR-199 (5)), unchanged: a live take whose member no longer passes is never shown as covered.
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

-- 6. Client read model (ADR-200 (5); F-1, UXR-223, UXR-225/F-2). Same columns as 0135; only the mapping changes. ---------------------
create or replace function public.client_orders()
returns table (id uuid, client_account_id uuid, sentence text, starts_at timestamptz, ends_at timestamptz,
               duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[],
               required_tags text[], radius_km numeric, shift_label text, confirmed_at timestamptz, cover_state text,
               cover_detail text, latest_cover_at timestamptz, covered_team_name text, taken_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.client_account_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, p.radius_km, p.shift_label, p.confirmed_at,
         case when c.cover_state = 'pending_acknowledgement' then 'open'
              -- UXR-225 (a) with `lca` F-2 (PO 12:39 (2)): «nicht mehr gedeckt» only if the client was ever shown
              -- «gedeckt», i.e. some take of this order was acknowledged (self-named takes are acknowledged at once).
              when c.cover_state = 'no_longer_covered' and not ever_covered.yes then 'open'
              else c.cover_state end,
         case when c.cover_state = 'pending_acknowledgement' then 'awaiting_acknowledgement'
              when c.cover_state = 'no_longer_covered' and not ever_covered.yes then 'take_fell_away'
              when c.cover_detail in ('no_team_eligible', 'all_declined') then 'no_team_free'   -- F-1
              when c.cover_detail = 'not_acknowledged' then 'cover_time_reached'
              else c.cover_detail end,
         c.latest_cover_at,
         case when c.cover_state = 'covered' then (select t.name from public.teams t where t.id = c.take_team_id) end,
         case when c.cover_state = 'covered' then c.taken_at end
  from public.partner_requests p
  cross join lateral private.order_cover(p.id, private.now()) c
  cross join lateral (select exists (select 1 from public.order_takes t
                                     where t.order_id = p.id and t.acknowledged_at is not null) as yes) ever_covered
  where p.order_kind is not null and private.is_client_member(p.client_account_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by p.starts_at
$$;
revoke all on function public.client_orders() from public, anon;
grant execute on function public.client_orders() to authenticated;

-- 7. «Bestätigen» (ADR-200 (1); CGR-230) --------------------------------------------------------------------------------
create or replace function public.acknowledge_take(p_order_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  o   public.partner_requests;
  k   public.order_takes;
begin
  if uid is null or p_order_id is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if private.begin_command('acknowledge_take', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into o from public.partner_requests where id = p_order_id and order_kind is not null for update;
  if o.id is not null and o.starts_at <= private.now() then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'order_started');
  end if;
  perform private.lapse_unacknowledged_take(o.id);
  select * into k from public.order_takes t where t.order_id = o.id and t.released_at is null;
  if k.id is null then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'no_live_take');
  end if;
  if k.member_id <> uid or not private.user_in_team(k.team_id, uid) or private.access_ended(uid) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'not_named');
  end if;
  if k.acknowledged_at is not null then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'already_acknowledged');
  end if;
  update public.order_takes set acknowledged_at = private.now() where id = k.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.acknowledge_take(uuid, uuid) from public, anon;
grant execute on function public.acknowledge_take(uuid, uuid) to authenticated;

-- 8. «Ich kann nicht» (ADR-200 (3); UXR-222, CGR-234) --------------------------------------------------------------------
create or replace function public.release_named_take(p_order_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  o   public.partner_requests;
  k   public.order_takes;
begin
  if uid is null or p_order_id is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if private.begin_command('release_named_take', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into o from public.partner_requests where id = p_order_id and order_kind is not null for update;
  if o.id is not null and o.starts_at <= private.now() then  -- CGR-234 (c): refused, never a silent release
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'order_started');
  end if;
  perform private.lapse_unacknowledged_take(o.id);
  select * into k from public.order_takes t where t.order_id = o.id and t.released_at is null;
  if k.id is null then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'no_live_take');
  end if;
  if k.member_id <> uid or not private.user_in_team(k.team_id, uid) or private.access_ended(uid) then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'not_named');
  end if;
  if k.member_id = k.taken_by then  -- no un-take in BK-c (UXR-221)
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'self_named');
  end if;
  if k.acknowledged_at is not null then
    perform private.end_command('refused');
    return jsonb_build_object('result', 'refused', 'reason', 'already_acknowledged');
  end if;
  update public.order_takes
    set released_at = private.now(), release_reason = 'member_cannot', released_by = uid
    where id = k.id;
  perform private.screen_order_reach(o.id, private.order_round(o.id) + 1);  -- ADR-199 release path
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.release_named_take(uuid, uuid) from public, anon;
grant execute on function public.release_named_take(uuid, uuid) to authenticated;

-- 9. The colleague list (ADR-200 (6); AUT-132): members at step 4 only, never a step ---------------------------------
create or replace function public.order_take_candidates(p_order_id uuid, p_team_id uuid)
returns table (user_id uuid, is_caller boolean)
language sql stable security definer set search_path = ''
as $$
  select m.user_id, m.user_id = (select auth.uid())
  from public.team_memberships m
  where m.team_id = p_team_id
    and private.is_team_member(p_team_id)   -- LEAVE1-3 inside
    and exists (select 1 from public.order_offers f
                where f.order_id = p_order_id and f.team_id = p_team_id and f.round = private.order_round(p_order_id))
    and private.order_member_step(p_order_id, p_team_id, m.user_id) = 4
  order by m.user_id <> (select auth.uid()), m.user_id
$$;
revoke all on function public.order_take_candidates(uuid, uuid) from public, anon;
grant execute on function public.order_take_candidates(uuid, uuid) to authenticated;

-- 10. The team's offer list (ADR-200 (6); UXR-221, CGR-234 (d), AUT-132). The return type grows, so drop and create. ---
drop function if exists public.team_order_offers();
create function public.team_order_offers()
returns table (order_id uuid, team_id uuid, sentence text, starts_at timestamptz, ends_at timestamptz,
               duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[],
               required_tags text[], distance_km numeric, limit_km numeric, offer_state text, taken_member_id uuid,
               taken_by uuid, taken_at timestamptz, acknowledged_at timestamptz, latest_cover_at timestamptz,
               caller_free boolean, release_kind text, released_member_id uuid)
language sql stable security definer set search_path = ''
as $$
  with last_release as (
    select distinct on (x.order_id) x.order_id, x.team_id, x.member_id, x.taken_by, x.taken_at, x.acknowledged_at,
           case x.release_reason when 'member_cannot' then 'member_cannot' when 'not_acknowledged' then 'not_acknowledged'
                else 'no_longer_eligible' end as kind
    from public.order_takes x
    where x.released_at is not null
    order by x.order_id, x.released_at desc, x.id desc
  )
  select f.order_id, f.team_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, f.distance_km, f.limit_km,
         case when k.id is null then 'open' else 'taken_by_us' end, k.member_id,
         k.taken_by, k.taken_at, k.acknowledged_at, private.order_latest_cover_at(p.id),
         private.order_member_step(p.id, f.team_id, (select auth.uid())) = 4,
         case when k.id is null and r.team_id = f.team_id then r.kind end,
         case when k.id is null and r.team_id = f.team_id then r.member_id end
  from public.order_offers f
  join public.partner_requests p on p.id = f.order_id
  left join public.order_takes k on k.order_id = f.order_id and k.released_at is null
  left join last_release r on r.order_id = f.order_id
  where private.is_team_member(f.team_id)   -- LEAVE1-3 inside
    and f.round = private.order_round(f.order_id)
    and p.ends_at > private.now()
    and not exists (select 1 from public.order_declines d
                    where d.order_id = f.order_id and d.round = f.round and d.team_id = f.team_id)
    and (k.id is null or k.team_id = f.team_id)
  union all
  -- CGR-234 (d): the own team's take was released and the new round offers it nothing: it still sees the release.
  select r.order_id, r.team_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, null::numeric, null::numeric, 'released', null::uuid,
         r.taken_by, r.taken_at, r.acknowledged_at, private.order_latest_cover_at(p.id), false, r.kind, r.member_id
  from last_release r
  join public.partner_requests p on p.id = r.order_id
  where private.is_team_member(r.team_id)
    and p.ends_at > private.now()
    and not exists (select 1 from public.order_takes t where t.order_id = r.order_id and t.released_at is null)
    and not exists (select 1 from public.order_offers f
                    where f.order_id = r.order_id and f.team_id = r.team_id and f.round = private.order_round(r.order_id))
  order by 4, 1, 2
$$;
revoke all on function public.team_order_offers() from public, anon;
grant execute on function public.team_order_offers() to authenticated;

drop function private.bk_c2_patch(text, text[], text);
