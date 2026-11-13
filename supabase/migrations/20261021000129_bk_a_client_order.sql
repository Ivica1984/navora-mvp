-- BK-a (brief docs/agents/briefs/BK.md, slice BK-a; ADR-191, ADR-192 as built in ADR-194): the client's shift order.
--
-- 1. `public.client_accounts` and `public.client_account_members`: the client is a separate account, never an
--    organisation member (ADR-192 (1), (2)); a trigger on both sides refuses one person in both within one organisation.
-- 2. `public.client_shift_plans`: the client's own shift labels (PO 2026-11-13 18:40 (2)); display only, steers nothing.
-- 3. `public.postcodes`: the BS/BL postcode list (ADR-193 (1), list only; distances are BK-b). Reference data.
-- 4. `public.partner_requests`: shift columns (ADR-191 (1)) without a price column (AUT-119 (a)); urgency may be empty
--    on a client order (no preset, IPA1-7; the window by start time is BK-c); status `client_confirmed` keeps the row
--    off the Operations intake list and out of «Fall eröffnen».
-- 5. `public.preview_client_order` (pure read, writes nothing), `public.confirm_client_order` (the only write, by a
--    member of the client account), `public.my_client_accounts`, `public.client_orders`.
-- No clinical, tariff or legal rule: the grade codes and the activity list are the existing ones (QUAL1, PROPOSED);
-- nothing here decides eligibility. Idempotent: `if not exists`, `create or replace`, `drop ... if exists`.

-- 1. Client accounts ---------------------------------------------------------------------------------------------------
create table if not exists public.client_accounts (
  id              uuid not null default gen_random_uuid() primary key,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  display_name    text not null check (char_length(btrim(display_name)) between 2 and 120),
  client_kind     text not null check (client_kind in ('home', 'hospital_ward', 'household')),
  created_at      timestamptz not null default private.now(),
  unique (id, organization_id)
);
comment on table public.client_accounts is
  'BK-a / ADR-192: an ordering client (home, hospital ward, private household) of one network. Not an organisation '
  'member. Phase A: synthetic seed accounts only. Read only through my_client_accounts() and client_orders().';
alter table public.client_accounts enable row level security;
revoke all on public.client_accounts from public, anon, authenticated;

create table if not exists public.client_account_members (
  client_account_id uuid not null references public.client_accounts (id) on delete cascade,
  user_id           uuid not null references auth.users (id) on delete cascade,
  created_at        timestamptz not null default private.now(),
  primary key (client_account_id, user_id)
);
comment on table public.client_account_members is
  'BK-a / ADR-192: who may order for a client account. Never also an organisation member of the same network.';
alter table public.client_account_members enable row level security;
revoke all on public.client_account_members from public, anon, authenticated;

-- One person is never orderer and team member of the same network (ADR-192 (2), BK-1n).
create or replace function private.client_member_not_org_member()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_table_name = 'client_account_members' then
    if exists (select 1 from public.client_accounts a
               join public.organization_memberships m on m.organization_id = a.organization_id
               where a.id = new.client_account_id and m.user_id = new.user_id) then
      raise exception 'client_is_not_member' using errcode = '23514';
    end if;
  else
    if exists (select 1 from public.client_account_members cm
               join public.client_accounts a on a.id = cm.client_account_id
               where cm.user_id = new.user_id and a.organization_id = new.organization_id) then
      raise exception 'client_is_not_member' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.client_member_not_org_member() from public, anon, authenticated;
drop trigger if exists client_account_members_not_org_member on public.client_account_members;
create trigger client_account_members_not_org_member before insert or update on public.client_account_members
  for each row execute function private.client_member_not_org_member();
drop trigger if exists organization_memberships_not_client on public.organization_memberships;
create trigger organization_memberships_not_client before insert or update of user_id, organization_id
  on public.organization_memberships
  for each row execute function private.client_member_not_org_member();

drop trigger if exists audit_client_accounts on public.client_accounts;
create trigger audit_client_accounts after insert or update on public.client_accounts
  for each row execute function private.write_audit_event('display_name', 'client_kind');

-- 2. The client's own shift plan (labels only) -------------------------------------------------------------------------
create table if not exists public.client_shift_plans (
  client_account_id uuid not null references public.client_accounts (id) on delete cascade,
  label             text not null check (char_length(btrim(label)) between 1 and 40),
  starts_at         time not null,
  ends_at           time not null,
  source            text not null check (source in ('synthetic')),
  primary key (client_account_id, label),
  check (starts_at <> ends_at)
);
comment on table public.client_shift_plans is
  'BK-a / PO 2026-11-13 18:40 (2): the client''s own shift labels (start, end). Display only: no filter, window, '
  'availability or amount reads it. NAVORA sets no shift boundaries. Phase A: synthetic seed values.';
alter table public.client_shift_plans enable row level security;
revoke all on public.client_shift_plans from public, anon, authenticated;

-- 3. Postcode list (BS/BL) -----------------------------------------------------------------------------------------------
create table if not exists public.postcodes (
  postcode       text not null primary key check (postcode ~ '^[0-9]{4}$'),
  place_name     text not null check (char_length(btrim(place_name)) between 2 and 80),
  region_name    text not null check (region_name in ('Basel-Stadt', 'Basel-Landschaft')),
  source         text not null,
  source_version text not null
);
comment on table public.postcodes is
  'BK-a / ADR-193 (1): postcode list for orders (places only, no address, P-8). Phase A: source = synthetic (seed), '
  'not checked against the official directory. Distances: BK-b.';
alter table public.postcodes enable row level security;
revoke all on public.postcodes from public, anon, authenticated;
grant select on public.postcodes to authenticated;
drop policy if exists postcodes_read on public.postcodes;
create policy postcodes_read on public.postcodes for select to authenticated using (true);
drop policy if exists leave1_access_open on public.postcodes;
create policy leave1_access_open on public.postcodes as restrictive for all to authenticated
  using (not (select private.access_ended((select auth.uid()))));  -- LEAVE1-3

-- 4. The order on partner_requests (ADR-191 (1); no price column, AUT-119 (a)) ------------------------------------------
alter table public.partner_requests
  add column if not exists order_kind        text,
  add column if not exists client_account_id uuid,
  add column if not exists starts_at         timestamptz,
  add column if not exists ends_at           timestamptz,
  add column if not exists postcode          text references public.postcodes (postcode),
  add column if not exists grade             text,
  add column if not exists activity_tags     text[],
  add column if not exists required_tags     text[],
  add column if not exists radius_km         numeric,
  add column if not exists shift_label       text,
  add column if not exists confirmed_at      timestamptz,
  add column if not exists confirmed_by      uuid;

-- A client order has no preset urgency (IPA1-7); the intake path still requires one (record_partner_request).
alter table public.partner_requests alter column urgency drop not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'partner_requests_client_account_same_org') then
    alter table public.partner_requests add constraint partner_requests_client_account_same_org
      foreign key (client_account_id, organization_id) references public.client_accounts (id, organization_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'partner_requests_order_shape') then
    alter table public.partner_requests add constraint partner_requests_order_shape check (
      (order_kind is null and urgency is not null and client_account_id is null and starts_at is null and ends_at is null)
      or (order_kind in ('shift', 'household')
          and client_account_id is not null and starts_at is not null and ends_at is not null and ends_at > starts_at
          and postcode is not null and grade in ('ags_eba', 'fage_efz', 'nurse_hf_fh')
          and cardinality(activity_tags) > 0 and required_tags is not null and required_tags <@ activity_tags
          and (radius_km is null or radius_km > 0)
          and notes is null and confirmed_at is not null and confirmed_by is not null));
  end if;
end;
$$;
create index if not exists partner_requests_client_account on public.partner_requests (client_account_id)
  where client_account_id is not null;

drop trigger if exists audit_partner_requests on public.partner_requests;
create trigger audit_partner_requests
  after insert or update on public.partner_requests
  for each row execute function private.write_audit_event('status', 'urgency', 'region', 'converted_case_id',
                                                          'urgency_source', 'referrer_requested_start',
                                                          'starts_at', 'ends_at', 'postcode', 'grade', 'confirmed_at');

-- AUD1-1: every audited column is classified (0086 list kept above, five order columns added).
insert into private.audit_value_classes (table_name, key, class) values
  ('partner_requests', 'starts_at', 'code'), ('partner_requests', 'ends_at', 'code'),
  ('partner_requests', 'postcode', 'code'), ('partner_requests', 'grade', 'code'),
  ('partner_requests', 'confirmed_at', 'code'),
  ('client_accounts', 'display_name', 'free_text'), ('client_accounts', 'client_kind', 'code')
on conflict do nothing;

-- 5. Commands and reads -----------------------------------------------------------------------------------------------
create or replace function private.is_client_member(p_client_account_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.client_account_members m
                 where m.client_account_id = p_client_account_id and m.user_id = (select auth.uid()))
         and not private.access_ended((select auth.uid()));
$$;
revoke all on function private.is_client_member(uuid) from public, anon, authenticated;

-- German labels of the form (UXR-196): never a code in the sentence.
create or replace function private.order_grade_label(p_grade text)
returns text language sql immutable set search_path = ''
as $$ select case p_grade when 'ags_eba' then 'AGS' when 'fage_efz' then 'FaGe' when 'nurse_hf_fh' then 'HF' end $$;
revoke all on function private.order_grade_label(text) from public, anon, authenticated;

create or replace function private.order_local_text(p_at timestamptz)
returns text language sql stable set search_path = ''
as $$
  select (array['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])[extract(isodow from private.at_zurich(p_at))::int]
         || ' ' || to_char(private.at_zurich(p_at), 'DD.MM.YYYY HH24:MI')
$$;
revoke all on function private.order_local_text(timestamptz) from public, anon, authenticated;

create or replace function private.order_duration_text(p_minutes integer)
returns text language sql immutable set search_path = ''
as $$
  select '(' || (p_minutes / 60) || ' Std.' || case when p_minutes % 60 > 0 then ' ' || (p_minutes % 60) || ' Min.' else '' end || ')'
$$;
revoke all on function private.order_duration_text(integer) from public, anon, authenticated;

-- One check for preview and confirm. Every required field must be passed; no default fills one (BK-1b).
create or replace function private.client_order_check(
  p_client_account_id uuid, p_start_date date, p_start_time time, p_end_time time, p_postcode text, p_grade text,
  p_activity_tags text[], p_required_tags text[], p_radius_km numeric)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  problems text[] := '{}';
  acct     public.client_accounts;
  pc       public.postcodes;
  s        timestamptz;
  e        timestamptz;
  minutes  integer;
  lbl      text;
  req      text[] := coalesce(p_required_tags, '{}');
begin
  if p_client_account_id is null or not private.is_client_member(p_client_account_id) then
    return jsonb_build_object('problems', jsonb_build_array('not_client'));
  end if;
  select * into acct from public.client_accounts where id = p_client_account_id;

  if p_start_date is null then problems := array_append(problems, 'missing_start_date'); end if;
  if p_start_time is null then problems := array_append(problems, 'missing_start_time'); end if;
  if p_end_time is null then problems := array_append(problems, 'missing_end_time'); end if;
  if nullif(btrim(p_postcode), '') is null then problems := array_append(problems, 'missing_postcode'); end if;
  if nullif(btrim(p_grade), '') is null then problems := array_append(problems, 'missing_grade'); end if;
  if coalesce(cardinality(p_activity_tags), 0) = 0 then problems := array_append(problems, 'missing_activity_tags'); end if;

  if p_start_date is not null and p_start_time is not null and p_end_time is not null then
    if p_end_time = p_start_time then
      problems := array_append(problems, 'end_equals_start');
    else
      -- Zurich wall clock → instant (DST1); an end not after the start is the next day (one order, BK-1c).
      s := private.at_zurich(p_start_date + p_start_time);
      e := private.at_zurich_end(case when p_end_time > p_start_time then p_start_date else p_start_date + 1 end + p_end_time);
      minutes := (extract(epoch from (e - s)) / 60)::int;
      if s < private.now() then problems := array_append(problems, 'starts_in_past'); end if;
      select p.label into lbl from public.client_shift_plans p
        where p.client_account_id = p_client_account_id and p.starts_at = p_start_time and p.ends_at = p_end_time
        order by p.label limit 1;
    end if;
  end if;

  if nullif(btrim(p_postcode), '') is not null then
    select * into pc from public.postcodes where postcode = btrim(p_postcode);
    if not found then
      problems := array_append(problems, 'postcode_not_in_list');
    elsif not exists (select 1 from public.regions r
                      where r.organization_id = acct.organization_id and r.name = pc.region_name and r.active) then
      problems := array_append(problems, 'postcode_outside_regions');
    end if;
  end if;
  if nullif(btrim(p_grade), '') is not null and p_grade not in ('ags_eba', 'fage_efz', 'nurse_hf_fh') then
    problems := array_append(problems, 'grade_unknown');
  end if;
  if exists (select 1 from unnest(coalesce(p_activity_tags, '{}') || req) t
             where not exists (select 1 from public.qual_activities q where q.code = t)) then
    problems := array_append(problems, 'tag_unknown');
  elsif not (req <@ coalesce(p_activity_tags, '{}')) then
    problems := array_append(problems, 'required_tag_not_in_tags');
  end if;
  if p_radius_km is not null and p_radius_km <= 0 then problems := array_append(problems, 'radius_not_positive'); end if;

  return jsonb_build_object(
    'problems', to_jsonb(problems),
    'organization_id', acct.organization_id,
    'display_name', acct.display_name,
    'client_kind', acct.client_kind,
    'starts_at', s,
    'ends_at', e,
    'duration_minutes', minutes,
    'postcode', pc.postcode,
    'place_name', pc.place_name,
    'region_name', pc.region_name,
    'shift_label', lbl,
    'weekend', case when s is null then null
                    else extract(isodow from private.at_zurich(s)) in (6, 7)
                      or extract(isodow from private.at_zurich(e)) in (6, 7) end,
    'sentence', case when cardinality(problems) = 0 then
                  'Schichtauftrag · ' || private.order_grade_label(p_grade) || ' · ' || private.order_local_text(s)
                  || ' – ' || private.order_local_text(e) || ' ' || private.order_duration_text(minutes)
                  || ' · ' || pc.postcode || ' ' || pc.place_name end);
end;
$$;
revoke all on function private.client_order_check(uuid, date, time, time, text, text, text[], text[], numeric)
  from public, anon, authenticated;

-- Pure read for the form and the summary (BK-1d): writes nothing.
create or replace function public.preview_client_order(
  p_client_account_id uuid, p_start_date date, p_start_time time, p_end_time time, p_postcode text, p_grade text,
  p_activity_tags text[], p_required_tags text[], p_radius_km numeric)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select r - 'organization_id' from private.client_order_check(p_client_account_id, p_start_date, p_start_time,
    p_end_time, p_postcode, p_grade, p_activity_tags, p_required_tags, p_radius_km) r
$$;
revoke all on function public.preview_client_order(uuid, date, time, time, text, text, text[], text[], numeric)
  from public, anon;
grant execute on function public.preview_client_order(uuid, date, time, time, text, text, text[], text[], numeric)
  to authenticated;

-- «Bestätigen & Absenden»: the only write. No free-text parameter (ADR-191 (3)).
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

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'order_id', new_id);
end;
$$;
revoke all on function public.confirm_client_order(uuid, date, time, time, text, text, text[], text[], numeric, uuid)
  from public, anon;
grant execute on function public.confirm_client_order(uuid, date, time, time, text, text, text[], text[], numeric, uuid)
  to authenticated;

create or replace function public.my_client_accounts()
returns table (id uuid, display_name text, client_kind text)
language sql stable security definer set search_path = ''
as $$
  select a.id, a.display_name, a.client_kind from public.client_accounts a
  where private.is_client_member(a.id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by a.display_name
$$;
revoke all on function public.my_client_accounts() from public, anon;
grant execute on function public.my_client_accounts() to authenticated;

-- Own orders only (ADR-192 (3)); no team, reason or member name. Cover state: BK-c derives it from offers; until then
-- every confirmed order reads «noch nicht gedeckt» (BK-6: never silent).
create or replace function public.client_orders()
returns table (id uuid, client_account_id uuid, sentence text, starts_at timestamptz, ends_at timestamptz,
               duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[],
               required_tags text[], radius_km numeric, shift_label text, confirmed_at timestamptz, cover_state text)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.client_account_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, p.radius_km, p.shift_label, p.confirmed_at, 'not_covered'::text
  from public.partner_requests p
  where p.order_kind is not null and private.is_client_member(p.client_account_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by p.starts_at
$$;
revoke all on function public.client_orders() from public, anon;
grant execute on function public.client_orders() to authenticated;
