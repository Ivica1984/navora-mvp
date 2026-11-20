-- BK-f, contract 2026-11-20 06:39 point 2 (a) (AUT-119 (b) first half; docs/agents/briefs/BK.md): the team's own
-- standing price per hour, set by the team itself (same team right as its service area, AUT-117 (a), 0130), append-only
-- and audited, currency CHF. NAVORA ships no reference value: no row → no price (the invoice draft of 0156 is then
-- refused with `no_price`). Seed values are synthetic and labelled «Beispielwert, kein Tarif» (W-7).
-- The price is copied at «Übernehmen» into `order_take_prices` (AFTER INSERT trigger on `order_takes`, same
-- transaction) and never updated afterwards (append-only). `take_order` (0135/0136) and the columns of `order_takes`
-- are unchanged.
-- Not here (contract point 3): client price ceiling, `price_above_ceiling`, surcharges, rounding, VAT.
-- No commission, percent or fee field anywhere (FE-078). Idempotent. Way back: drop the triggers, the functions and
-- the two tables (no other object reads them before 0156).

-- 1. Table (append-only; the current price is the newest row) --------------------------------------------------------
create table if not exists public.team_prices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id) on delete cascade,
  price_per_hour  numeric(8,2) not null check (price_per_hour > 0 and price_per_hour < 1000),
  currency        text not null default 'CHF' check (currency = 'CHF'),
  set_by          uuid not null,
  set_at          timestamptz not null default private.now(),
  note            text check (note is null or length(note) <= 80)
);
create index if not exists team_prices_current on public.team_prices (team_id, set_at desc, id desc);
comment on table public.team_prices is
  'BK-f / AUT-119 (b): the team''s own standing price per hour (CHF), set by the team. Append-only; the newest row is '
  'the current price. NAVORA sets no value; seed rows are synthetic «Beispielwert, kein Tarif». Written only by '
  'set_team_price. No commission, percent or fee (FE-078).';

alter table public.team_prices enable row level security;
revoke all on public.team_prices from public, anon, authenticated;
grant select on public.team_prices to authenticated;
drop policy if exists team_prices_read on public.team_prices;
create policy team_prices_read on public.team_prices for select to authenticated
  using (private.is_org_member(organization_id));  -- the team's organisation only; a client-only user reads nothing
drop policy if exists leave1_access_open on public.team_prices;
create policy leave1_access_open on public.team_prices as restrictive for all to authenticated
  using (not (select private.access_ended((select auth.uid()))));  -- LEAVE1-3

create or replace function private.team_prices_append_only()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'team_prices is append-only' using errcode = '42501';
end $$;
revoke all on function private.team_prices_append_only() from public, anon, authenticated;
drop trigger if exists team_prices_append_only on public.team_prices;
create trigger team_prices_append_only before update or delete on public.team_prices
  for each row when (pg_trigger_depth() < 1) execute function private.team_prices_append_only();

insert into private.audit_value_classes (table_name, key, class) values
  ('teams', 'price_per_hour', 'code')
on conflict do nothing;

create or replace function private.team_current_price(p_team_id uuid)
returns public.team_prices language sql stable security definer set search_path = '' as $$
  select p.* from public.team_prices p where p.team_id = p_team_id order by p.set_at desc, p.id desc limit 1
$$;
revoke all on function private.team_current_price(uuid) from public, anon, authenticated;

-- 2. Command: the team sets its price (AUT-117 (a) right) ------------------------------------------------------------
create or replace function public.set_team_price(p_team_id uuid, p_price_per_hour numeric, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  t   public.teams;
  cur public.team_prices;
  new_id uuid;
begin
  if private.begin_command('set_team_price', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into t from public.teams where id = p_team_id for update;
  if uid is null or t.id is null
     or not (private.is_team_member(t.id)
             or (private.has_org_role(t.organization_id, array['admin'])
                 and not exists (select 1 from public.team_memberships m
                                 where m.team_id = t.id and not private.access_ended(m.user_id)))) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_price_per_hour is null or p_price_per_hour <= 0 or p_price_per_hour >= 1000
     or p_price_per_hour <> round(p_price_per_hour, 2) then
    perform private.end_command('invalid');
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('price_not_valid'));
  end if;
  cur := private.team_current_price(t.id);
  if cur.id is not null and cur.price_per_hour = p_price_per_hour then
    perform private.end_command('ok');
    return jsonb_build_object('result', 'ok', 'changed', false, 'price_id', cur.id);
  end if;
  insert into public.team_prices (organization_id, team_id, price_per_hour, set_by)
    values (t.organization_id, t.id, p_price_per_hour, uid)
    returning id into new_id;
  perform private.audit_command(t.organization_id, 'teams', t.id,
    jsonb_build_object('price_per_hour', jsonb_build_object('old', to_jsonb(cur.price_per_hour), 'new', to_jsonb(p_price_per_hour))));
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'changed', true, 'price_id', new_id);
end;
$$;
revoke all on function public.set_team_price(uuid, numeric, uuid) from public, anon;
grant execute on function public.set_team_price(uuid, numeric, uuid) to authenticated;

-- 3. Snapshot of the price at «Übernehmen», never updated -----------------------------------------------------------
-- Its own table, so `order_takes` keeps exactly its columns (pgTAP 144, lca PO 08:39 (2)): one row per take, written by
-- an AFTER INSERT trigger in the take's transaction; append-only. Read only through SECURITY DEFINER functions.
create table if not exists public.order_take_prices (
  take_id         uuid primary key references public.order_takes (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id) on delete cascade,
  price_id        uuid references public.team_prices (id),
  price_per_hour  numeric(8,2) check (price_per_hour is null or price_per_hour > 0),
  currency        text not null default 'CHF' check (currency = 'CHF'),
  recorded_at     timestamptz not null default private.now(),
  check ((price_id is null) = (price_per_hour is null))
);
comment on table public.order_take_prices is
  'BK-f / AUT-119 (b): the take team''s price per hour (CHF) at the moment of the take; price null when the team had '
  'none (no NAVORA default). Written only by the order_takes insert trigger; never updated or deleted.';
alter table public.order_take_prices enable row level security;
revoke all on public.order_take_prices from public, anon, authenticated;  -- read only through definer functions

drop trigger if exists order_take_prices_append_only on public.order_take_prices;
create trigger order_take_prices_append_only before update or delete on public.order_take_prices
  for each row when (pg_trigger_depth() < 1) execute function private.team_prices_append_only();

create or replace function private.order_take_price_snapshot()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  p public.team_prices;
begin
  p := private.team_current_price(new.team_id);
  insert into public.order_take_prices (take_id, organization_id, team_id, price_id, price_per_hour)
    values (new.id, new.organization_id, new.team_id, p.id, p.price_per_hour)
    on conflict (take_id) do nothing;
  return null;
end $$;
revoke all on function private.order_take_price_snapshot() from public, anon, authenticated;
drop trigger if exists order_take_price_snapshot on public.order_takes;
create trigger order_take_price_snapshot after insert on public.order_takes
  for each row execute function private.order_take_price_snapshot();

-- 4. The team reads its own current price (pattern of my_team_reach, 0131) ------------------------------------------
create or replace function public.my_team_prices()
returns table (team_id uuid, team_name text, price_per_hour numeric, currency text, set_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select t.id, t.name, p.price_per_hour, p.currency, p.set_at
  from public.teams t
  left join lateral (select * from private.team_current_price(t.id)) p on p.id is not null
  where (select auth.uid()) is not null
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
    and private.is_team_member(t.id)
  order by t.name, t.id
$$;
comment on function public.my_team_prices() is
  'BK-f / AUT-119 (b): the current price per hour of the caller''s own teams only (null when the team set none); a '
  'former member (LEAVE1-3) reads nothing. Written only by set_team_price.';
revoke all on function public.my_team_prices() from public, anon;
grant execute on function public.my_team_prices() to authenticated;
