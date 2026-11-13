-- B1.1-1b (CGR-201; brief docs/agents/briefs/B1.1.md §PO 06:39 and 08:39; ADR-187).
--
-- CGR-201: under READ COMMITTED an insert of a case or a team search that carries a legacy region text can race
-- «Zuordnen» of the same text and keep the old text after the mapping committed; «Region nicht zugeordnet» listed only
-- unmapped legacy rows, so such a row was neither rewritten nor shown (probe docs/engineering/probes/CGR-201_MAPPING_RACE.md).
--
-- 1. Lock: the trigger's insert path (and the owner path register_legacy_region) first takes a share lock on the
--    legacy row, then reads the mapping in a second statement (new snapshot after a lock wait; probe variant C). A
--    mapping holds `for update` on the same row, so either the insert waits and takes the mapped name, or the mapping
--    waits for the insert's commit and its rewrite sees the new row.
-- 2. Safety net: `unmapped_regions()` lists every region text in use that is not an active list name, whatever the
--    state of its legacy row, plus unmapped legacy values not in use (as before). A value already mapped is returned
--    with its mapped region (`mapped_region_id`, `mapped_region_name`).
-- 3. «Zuordnen» on such a row (PO 06:39 point 2): only the region already chosen is accepted; it rewrites the remaining
--    rows and writes its own audit row (from, to; who and when by audit_command). Another region stays `already_mapped`
--    (a re-map is CGR-202 (a), real-data gate). A text in use without a legacy row (only possible with triggers
--    disabled) is registered and then mapped like an unmapped value.
-- No change to RLS, grants, audit_command, the list or the eligibility comparison (text, 0017:358-374).
-- Idempotent: `create or replace`, `drop function if exists` before a changed return type.

-- 1. Lock ---------------------------------------------------------------------------------------------------------------
create or replace function private.register_legacy_region(p_org uuid, p_value text)
returns text language plpgsql security definer set search_path = ''
as $$
declare
  listed text;
  auto   public.regions;
begin
  select r.name into listed from public.regions r where r.organization_id = p_org and r.name = p_value;
  if listed is not null then return listed; end if;
  -- CGR-201: wait for a mapping in progress, then read it with a new snapshot (separate statement).
  perform 1 from public.region_legacy_values l
    where l.organization_id = p_org and l.legacy_value = p_value for share;
  select r.name into listed from public.region_legacy_values l join public.regions r on r.id = l.region_id
    where l.organization_id = p_org and l.legacy_value = p_value;
  if listed is not null then return listed; end if;
  select r.* into auto from public.regions r
    where r.organization_id = p_org and r.active and private.region_norm(r.name) = private.region_norm(p_value);
  insert into public.region_legacy_values (organization_id, legacy_value, region_id, mapping_kind, mapped_at)
  values (p_org, p_value, auto.id, case when auto.id is null then null else 'auto' end,
          case when auto.id is null then null else private.now() end)
  on conflict (organization_id, legacy_value) do nothing;
  return coalesce(auto.name, p_value);
end;
$$;
revoke all on function private.register_legacy_region(uuid, text) from public, anon, authenticated;

create or replace function private.region_from_list()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  -- Every API role is an application write (PostgREST sets the role); only the table owner is a migration or seed.
  user_request boolean := coalesce(current_setting('role', true), 'none') in ('authenticated', 'anon', 'service_role');
  mapped       text;
  known        boolean;
begin
  if new.region is null then return new; end if;
  if tg_op = 'UPDATE' and new.region is not distinct from old.region then return new; end if;
  if exists (select 1 from public.regions r
             where r.organization_id = new.organization_id and r.name = new.region and r.active) then
    return new;
  end if;
  if not user_request then
    new.region := private.register_legacy_region(new.organization_id, new.region);
    return new;
  end if;
  if tg_op = 'INSERT' and tg_table_name in ('cases', 'matching_requests') then
    -- CGR-201: the share lock conflicts with the mapping's `for update`. The mapping is read in a second statement so
    -- that, after waiting for a mapping to commit, it is read from a new snapshot (one joined statement would reuse
    -- the old snapshot for `regions`; probe variant B).
    perform 1 from public.region_legacy_values l
      where l.organization_id = new.organization_id and l.legacy_value = new.region for share;
    known := found;
    if known then
      select r.name into mapped
        from public.region_legacy_values l left join public.regions r on r.id = l.region_id
        where l.organization_id = new.organization_id and l.legacy_value = new.region;
      new.region := coalesce(mapped, new.region);
      return new;
    end if;
  end if;
  raise exception 'region_not_in_list' using errcode = '22023';
end;
$$;
revoke all on function private.region_from_list() from public, anon, authenticated;

-- 2. «Region nicht zugeordnet»: every non-listed text in use, and unmapped legacy values ------------------------------
drop function if exists public.unmapped_regions(uuid);
create function public.unmapped_regions(p_organization_id uuid)
returns table (legacy_value text, teams integer, cases integer, referrals integer, open_searches integer,
               mapped_region_id uuid, mapped_region_name text)
language sql stable security definer set search_path = ''
as $$
  with used as (
    select region from public.teams where organization_id = p_organization_id
    union select region from public.cases where organization_id = p_organization_id
    union select region from public.partner_requests where organization_id = p_organization_id
    union select region from public.matching_requests where organization_id = p_organization_id
  ),
  vals as (
    select u.region as v from used u
      where u.region is not null
        and not exists (select 1 from public.regions r
                        where r.organization_id = p_organization_id and r.name = u.region and r.active)
    union
    select l.legacy_value from public.region_legacy_values l
      where l.organization_id = p_organization_id and l.region_id is null
  )
  select x.v,
    (select count(*)::int from public.teams t where t.organization_id = p_organization_id and t.region = x.v),
    (select count(*)::int from public.cases c where c.organization_id = p_organization_id and c.region = x.v),
    (select count(*)::int from public.partner_requests p where p.organization_id = p_organization_id and p.region = x.v),
    (select count(*)::int from public.matching_requests m
      where m.organization_id = p_organization_id and m.region = x.v and m.status = 'open'),
    l.region_id,
    r.name
  from vals x
  left join public.region_legacy_values l on l.organization_id = p_organization_id and l.legacy_value = x.v
  left join public.regions r on r.id = l.region_id
  where (select auth.uid()) is not null
    and private.has_org_role(p_organization_id, array['admin', 'operations'])
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by x.v;
$$;
revoke all on function public.unmapped_regions(uuid) from public, anon;
grant execute on function public.unmapped_regions(uuid) to authenticated;

-- 3. «Zuordnen» -----------------------------------------------------------------------------------------------------------
-- Return: 'ok' | 'duplicate' | 'already_mapped' | 'not_found' | 'rejected'
create or replace function public.map_legacy_region(p_organization_id uuid, p_legacy_value text, p_region_id uuid,
                                                    p_idempotency_key uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare
  l     public.region_legacy_values;
  r     public.regions;
  stray boolean;
begin
  if (select auth.uid()) is null then return 'rejected'; end if;
  if private.begin_command('map_legacy_region', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.has_org_role(p_organization_id, array['admin', 'operations']) then
    return private.end_command('rejected');
  end if;
  select * into r from public.regions
    where id = p_region_id and organization_id = p_organization_id and active;
  if r.id is null then return private.end_command('not_found'); end if;
  select * into l from public.region_legacy_values
    where organization_id = p_organization_id and legacy_value = p_legacy_value for update;
  if l.id is null then
    -- A non-listed text in use without a legacy row (only with triggers disabled): register it, then map it.
    if p_legacy_value in (select name from public.regions where organization_id = p_organization_id and active)
       or not exists (
         select 1 from public.teams where organization_id = p_organization_id and region = p_legacy_value
         union all select 1 from public.cases where organization_id = p_organization_id and region = p_legacy_value
         union all select 1 from public.partner_requests where organization_id = p_organization_id and region = p_legacy_value
         union all select 1 from public.matching_requests where organization_id = p_organization_id and region = p_legacy_value)
    then
      return private.end_command('not_found');
    end if;
    insert into public.region_legacy_values (organization_id, legacy_value)
      values (p_organization_id, p_legacy_value)
      on conflict (organization_id, legacy_value) do nothing;
    select * into l from public.region_legacy_values
      where organization_id = p_organization_id and legacy_value = p_legacy_value for update;
  end if;

  if l.region_id is not null then
    -- CGR-201 safety net (PO 06:39 point 2): rows still on the old text are rewritten to the region already chosen.
    stray := exists (
      select 1 from public.teams where organization_id = p_organization_id and region = l.legacy_value
      union all select 1 from public.cases where organization_id = p_organization_id and region = l.legacy_value
      union all select 1 from public.partner_requests where organization_id = p_organization_id and region = l.legacy_value
      union all select 1 from public.matching_requests where organization_id = p_organization_id and region = l.legacy_value);
    if l.region_id <> r.id or not stray then return private.end_command('already_mapped'); end if;
  else
    update public.region_legacy_values
      set region_id = r.id, mapping_kind = 'manual', mapped_by = (select auth.uid()), mapped_at = private.now()
      where id = l.id;
  end if;
  perform private.rewrite_region(p_organization_id, l.legacy_value, r.name);
  perform private.audit_command(p_organization_id, 'region_legacy_values', l.id,
    jsonb_build_object('from', l.legacy_value, 'to', r.name));
  return private.end_command('ok');
end;
$$;
revoke all on function public.map_legacy_region(uuid, text, uuid, uuid) from public, anon;
grant execute on function public.map_legacy_region(uuid, text, uuid, uuid) to authenticated;
