-- B1.1-1 (a, Δ1) region list and legacy values (brief docs/agents/briefs/B1.1.md; ADR-186).
--
-- 1. `public.regions`: the organisation's list (Basel-Stadt, Basel-Landschaft; FE-019), read by members, written only
--    by migrations and by the trigger for a new organisation.
-- 2. `public.region_legacy_values`: every region text in use that is not on the list, per organisation; mapped
--    automatically only for a normalised exact match, otherwise by hand by Operations.
-- 3. `private.region_from_list()`: one trigger on teams, cases, partner_requests and matching_requests. A request of a
--    signed-in user (database role `authenticated`) can only write a listed region; an unchanged legacy value stays;
--    a legacy value copied into a case or a team search is kept (no loss). Database roles (migration, seed, fixtures)
--    register a non-listed value as legacy.
-- 4. `public.unmapped_regions()` and `public.map_legacy_region()` for «Region nicht zugeordnet» on /operations.
-- The region columns stay text and the eligibility comparison is unchanged (no new rule).
-- Idempotent: `if not exists`, `create or replace`, `on conflict do nothing`.

-- 1. The list ----------------------------------------------------------------------------------------------------------
create table if not exists public.regions (
  id              uuid not null default gen_random_uuid() primary key,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (char_length(btrim(name)) between 2 and 80),
  sort_order      integer not null default 0,
  active          boolean not null default true,
  created_at      timestamptz not null default private.now(),
  unique (organization_id, name),
  unique (id, organization_id)
);
comment on table public.regions is
  'B1.1-1: the region list of an organisation (FE-019 pilot regions). Written only by migrations and the new-organisation trigger.';

alter table public.regions enable row level security;
revoke all on public.regions from public, anon, authenticated;
grant select on public.regions to authenticated;
drop policy if exists regions_read on public.regions;
create policy regions_read on public.regions for select to authenticated
  using (private.is_org_member(organization_id));

create or replace function private.seed_region_list(p_org uuid)
returns void language sql security definer set search_path = ''
as $$
  insert into public.regions (organization_id, name, sort_order)
  values (p_org, 'Basel-Stadt', 1), (p_org, 'Basel-Landschaft', 2)
  on conflict (organization_id, name) do nothing;
$$;
revoke all on function private.seed_region_list(uuid) from public, anon, authenticated;

select private.seed_region_list(o.id) from public.organizations o;

create or replace function private.organization_region_list()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.seed_region_list(new.id);
  return new;
end;
$$;
revoke all on function private.organization_region_list() from public, anon, authenticated;
drop trigger if exists organizations_region_list on public.organizations;
create trigger organizations_region_list after insert on public.organizations
  for each row execute function private.organization_region_list();

-- 2. Legacy values -----------------------------------------------------------------------------------------------------
create table if not exists public.region_legacy_values (
  id              uuid not null default gen_random_uuid() primary key,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  legacy_value    text not null,
  region_id       uuid,
  mapping_kind    text check (mapping_kind in ('auto', 'manual')),
  mapped_by       uuid,
  mapped_at       timestamptz,
  first_seen_at   timestamptz not null default private.now(),
  unique (organization_id, legacy_value),
  foreign key (region_id, organization_id) references public.regions (id, organization_id),
  check ((region_id is null) = (mapping_kind is null))
);
comment on table public.region_legacy_values is
  'B1.1-1: region texts in use that are not on the list. No free text about a person; read only through unmapped_regions().';
alter table public.region_legacy_values enable row level security;
revoke all on public.region_legacy_values from public, anon, authenticated;

-- Normalised comparison for the automatic mapping only (case, spaces, hyphens, dots).
create or replace function private.region_norm(p text)
returns text language sql immutable set search_path = ''
as $$ select lower(regexp_replace(coalesce(p, ''), '[[:space:].-]', '', 'g')) $$;
revoke all on function private.region_norm(text) from public, anon, authenticated;

-- Registers a non-listed value; returns the text to store (the list name when the value maps, else the value).
create or replace function private.register_legacy_region(p_org uuid, p_value text)
returns text language plpgsql security definer set search_path = ''
as $$
declare
  listed text;
  auto   public.regions;
begin
  select r.name into listed from public.regions r where r.organization_id = p_org and r.name = p_value;
  if listed is not null then return listed; end if;
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

-- 3. The write path ----------------------------------------------------------------------------------------------------
create or replace function private.region_from_list()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  user_request boolean := coalesce(current_setting('role', true), 'none') in ('authenticated', 'anon');
  mapped       text;
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
    select r.name into mapped
      from public.region_legacy_values l left join public.regions r on r.id = l.region_id
      where l.organization_id = new.organization_id and l.legacy_value = new.region;
    if found then
      new.region := coalesce(mapped, new.region);
      return new;
    end if;
  end if;
  raise exception 'region_not_in_list' using errcode = '22023';
end;
$$;
revoke all on function private.region_from_list() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['teams', 'cases', 'partner_requests', 'matching_requests'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_region_from_list', t);
    execute format('create trigger %I before insert or update of region on public.%I '
                   'for each row execute function private.region_from_list()', t || '_region_from_list', t);
  end loop;
end;
$$;

-- Backfill: register every value in use; rewrite the rows of automatically mapped values to the list name.
do $$
declare v record;
begin
  for v in
    select distinct organization_id, region from (
      select organization_id, region from public.teams
      union all select organization_id, region from public.cases
      union all select organization_id, region from public.partner_requests
      union all select organization_id, region from public.matching_requests) x
    where region is not null and organization_id is not null
  loop
    perform private.register_legacy_region(v.organization_id, v.region);
  end loop;
end;
$$;

create or replace function private.rewrite_region(p_org uuid, p_from text, p_to text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  update public.teams             set region = p_to where organization_id = p_org and region = p_from;
  update public.cases             set region = p_to where organization_id = p_org and region = p_from;
  update public.partner_requests  set region = p_to where organization_id = p_org and region = p_from;
  update public.matching_requests set region = p_to where organization_id = p_org and region = p_from;
end;
$$;
revoke all on function private.rewrite_region(uuid, text, text) from public, anon, authenticated;

select private.rewrite_region(l.organization_id, l.legacy_value, r.name)
  from public.region_legacy_values l join public.regions r on r.id = l.region_id
  where l.mapping_kind = 'auto';

-- The team region becomes audited like the other three tables (0004:100 did not list it).
drop trigger if exists audit_teams on public.teams;
create trigger audit_teams
  after update on public.teams
  for each row execute function private.write_audit_event('priority', 'coach_name', 'status', 'open_slots', 'utilization', 'region');

-- 4. «Region nicht zugeordnet» -----------------------------------------------------------------------------------------
create or replace function public.unmapped_regions(p_organization_id uuid)
returns table (legacy_value text, teams integer, cases integer, referrals integer, open_searches integer)
language sql stable security definer set search_path = ''
as $$
  select l.legacy_value,
    (select count(*)::int from public.teams t where t.organization_id = l.organization_id and t.region = l.legacy_value),
    (select count(*)::int from public.cases c where c.organization_id = l.organization_id and c.region = l.legacy_value),
    (select count(*)::int from public.partner_requests p where p.organization_id = l.organization_id and p.region = l.legacy_value),
    (select count(*)::int from public.matching_requests m
      where m.organization_id = l.organization_id and m.region = l.legacy_value and m.status = 'open')
  from public.region_legacy_values l
  where l.organization_id = p_organization_id and l.region_id is null
    and (select auth.uid()) is not null
    and private.has_org_role(p_organization_id, array['admin', 'operations'])
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by l.legacy_value;
$$;
revoke all on function public.unmapped_regions(uuid) from public, anon;
grant execute on function public.unmapped_regions(uuid) to authenticated;

-- Return: 'ok' | 'duplicate' | 'already_mapped' | 'not_found' | 'rejected'
create or replace function public.map_legacy_region(p_organization_id uuid, p_legacy_value text, p_region_id uuid,
                                                    p_idempotency_key uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare
  l public.region_legacy_values;
  r public.regions;
begin
  if (select auth.uid()) is null then return 'rejected'; end if;
  if private.begin_command('map_legacy_region', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.has_org_role(p_organization_id, array['admin', 'operations']) then
    return private.end_command('rejected');
  end if;
  select * into l from public.region_legacy_values
    where organization_id = p_organization_id and legacy_value = p_legacy_value for update;
  select * into r from public.regions
    where id = p_region_id and organization_id = p_organization_id and active;
  if l.id is null or r.id is null then return private.end_command('not_found'); end if;
  if l.region_id is not null then return private.end_command('already_mapped'); end if;

  update public.region_legacy_values
    set region_id = r.id, mapping_kind = 'manual', mapped_by = (select auth.uid()), mapped_at = private.now()
    where id = l.id;
  perform private.rewrite_region(p_organization_id, l.legacy_value, r.name);
  perform private.audit_command(p_organization_id, 'region_legacy_values', l.id,
    jsonb_build_object('from', l.legacy_value, 'to', r.name));
  return private.end_command('ok');
end;
$$;
revoke all on function public.map_legacy_region(uuid, text, uuid, uuid) from public, anon;
grant execute on function public.map_legacy_region(uuid, text, uuid, uuid) to authenticated;
