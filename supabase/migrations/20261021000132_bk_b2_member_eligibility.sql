-- BK-b2 (brief docs/agents/briefs/BK.md, PO amendment 2026-11-14 09:39 (2); `cra` CGR-204 (a), CGR-216; draft ADR-196):
-- the qualification part of the hard filter BK-2, read per member, and the level-against-activity check.
--
-- 1. CGR-216 (a): `private.client_order_check` (0129 body unchanged otherwise) adds the problem
--    `level_activity_conflict` and the key `conflict_activities` (codes in matrix order, always present) when the
--    QAM-0.2 cell (PROPOSED) for the chosen level is «-», «?», carries an open question (ADR-163 strict default (a)) or
--    is missing. Preview and confirm use it; confirm refuses and writes no order. No mapping between levels (CGR-216 (b)).
-- 2. CGR-204 (a): `private.order_member_step(order, team, user)` returns how far ONE member gets: 0 not an active member
--    (team membership, LEAVE1 access open), 1 the level fails (verified grade equal to the order's grade at the order's
--    end, so expiry inside the slot fails; self_confirmed and contradictory never count, QUAL1-3/-4), 2 an activity
--    fails (own scope «E» with every evidence the cell requires verified; «D» only for an activity the client did not
--    mark required: draft ADR-196 (3), PROPOSED for `cra`), 3 not available for the whole slot [start, end) (an ABS1
--    absence of hers in any team, not withdrawn, or an open visit she is responsible for or covers), 4 eligible.
-- 3. `private.screen_order_reach` (0130) keeps the distance reasons first and then excludes a team none of whose
--    members reaches step 4, with the reason of the furthest step any member reached: `no_active_member`,
--    `no_member_with_grade`, `no_member_activity_evidence`, `no_member_available`. Members are never combined. The
--    reason names a step, never a person (P-5). Rows are still written once (AUT-117 (b)); the re-check at the take
--    and at shift start is BK-c / BK-5a (CGR-204 (b)).
-- 4. `public.confirm_client_order` (0130 body): the refusal also returns `conflict_activities`.
-- No clinical, tariff or legal rule is set here: the cells are QAM-0.2 (PROPOSED, D-43); the reading of «required» and
-- «D» is a strict default for `cra`. Verified evidence exists only as a synthetic fixture in a simulation organisation
-- (0120 guard), so outside a simulation no team passes step 1 (fail-closed). Synthetic data only.
-- Version 0132: 0131 is taken by the open BK-b1s PR #1270 (stacked on the same BK-b1 branch).
-- Idempotent: `create or replace`, `drop constraint if exists`.

-- 1. CGR-216 in the one check for preview and confirm -------------------------------------------------------------------
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
  conflicts text[] := '{}';
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
  -- BK-b2 / CGR-216 (a): the matrix cell (QAM-0.2, PROPOSED) for the chosen level must not be «-» or «?» for any
  -- activity; a cell with an open question counts as «?» (ADR-163 strict default (a)); a missing cell is never allowed.
  -- Read as ordered: no mapping from one level to another (CGR-216 (b), CGR-205 (d)).
  if p_grade in ('ags_eba', 'fage_efz', 'nurse_hf_fh') and not ('tag_unknown' = any (problems)) then
    select coalesce(array_agg(q.code order by q.sort), '{}') into conflicts
    from public.qual_activities q
    left join public.qual_matrix_cells c
      on c.version = private.qual_matrix_version() and c.activity_code = q.code and c.grade = p_grade
    where q.code = any (coalesce(p_activity_tags, '{}') || req)
      and (c.value is null or c.value in ('-', '?') or c.open_question is not null);
    if cardinality(conflicts) > 0 then problems := array_append(problems, 'level_activity_conflict'); end if;
  end if;

  return jsonb_build_object(
    'problems', to_jsonb(problems),
    'conflict_activities', to_jsonb(conflicts),
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


-- 2. One member against one order (CGR-204 (a)) -------------------------------------------------------------------------
create or replace function private.order_member_step(p_order_id uuid, p_team_id uuid, p_user_id uuid)
returns integer language plpgsql stable security definer set search_path = ''
as $$
declare
  o    public.partner_requests;
  g    record;
  ev   record;
  cell public.qual_matrix_cells;
  a    text;
  r    text;
  ver  text := private.qual_matrix_version();
begin
  select * into o from public.partner_requests where id = p_order_id;
  if o.id is null or o.starts_at is null or o.ends_at is null then return 0; end if;
  if not private.user_in_team(p_team_id, p_user_id) or private.access_ended(p_user_id) then return 0; end if;  -- LEAVE1-3

  -- Level: verified, equal to the ordered grade, still valid at the end of the slot (QUAL1-2, -4; CGR-205 (d)).
  select * into g from private.qual_evidence_state(o.organization_id, p_user_id, 'grade', o.ends_at);
  if g.state is distinct from 'verified' or g.grade is distinct from o.grade then return 1; end if;

  -- Activities: own scope with the cell's evidence, or «D» for an activity the client did not mark required.
  foreach a in array coalesce(o.activity_tags, '{}') loop
    cell := null;
    select * into cell from public.qual_matrix_cells c
     where c.version = ver and c.activity_code = a and c.grade = o.grade;
    if cell.value = 'E' and cell.open_question is null then
      foreach r in array coalesce(cell.requires, '{}') loop
        select * into ev from private.qual_evidence_state(o.organization_id, p_user_id, r, o.ends_at);
        if ev.state is distinct from 'verified' then return 2; end if;
      end loop;
    elsif cell.value = 'D' and cell.open_question is null and not (a = any (coalesce(o.required_tags, '{}'))) then
      null;  -- level allowed; a delegation belongs to a case and is checked at the visit (QUAL1). PROPOSED for `cra`.
    else
      return 2;
    end if;
  end loop;

  -- Availability for the whole slot [start, end): her absences in any team, her open visits.
  if exists (select 1 from public.member_absences x
             where x.user_id = p_user_id and x.withdrawn_at is null
               and x.starts_at < o.ends_at and x.ends_at > o.starts_at)
     or exists (select 1 from public.care_visits v
                where (v.responsible_user_id = p_user_id or v.covered_by = p_user_id)
                  and v.status in ('planned', 'on_the_way', 'started', 'paused')
                  and private.visit_interval(v) && tstzrange(o.starts_at, o.ends_at, '[)')) then
    return 3;
  end if;
  return 4;
end;
$$;
revoke all on function private.order_member_step(uuid, uuid, uuid) from public, anon, authenticated;
comment on function private.order_member_step(uuid, uuid, uuid) is
  'BK-b2 / CGR-204 (a) / draft ADR-196: how far one member gets for one order (0 not active, 1 level, 2 activity '
  'evidence, 3 availability for the whole slot, 4 eligible). Private: no app role reads who is eligible.';

-- 3. Screening: distance part (0130) first, then the member part -------------------------------------------------------
alter table public.order_exclusions drop constraint if exists order_exclusions_reason_check;
alter table public.order_exclusions add constraint order_exclusions_reason_check
  check (reason in ('team_not_active', 'no_service_area', 'no_max_distance', 'no_distance', 'outside_radius',
                    'no_active_member', 'no_member_with_grade', 'no_member_activity_evidence', 'no_member_available'));
comment on table public.order_exclusions is
  'BK-b1/BK-b2 / BK-2: a team that failed the hard filter for an order, with its reason (a step, never a person). '
  'Written once at confirmation.';

create or replace function private.screen_order_reach(p_order_id uuid)
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

-- 4. «Bestätigen & Absenden» (0130 body; only the refusal now carries `conflict_activities`).
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
    return jsonb_build_object('result', 'invalid', 'problems', chk -> 'problems',
                              'conflict_activities', coalesce(chk -> 'conflict_activities', '[]'::jsonb));
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

  perform private.screen_order_reach(new_id);  -- BK-b1 distance part + BK-b2 member part, BK-2n

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'order_id', new_id);
end;
$$;
revoke all on function public.confirm_client_order(uuid, date, time, time, text, text, text[], text[], numeric, uuid)
  from public, anon;
grant execute on function public.confirm_client_order(uuid, date, time, time, text, text, text[], text[], numeric, uuid)
  to authenticated;

