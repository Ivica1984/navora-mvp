-- BK-b2, merge conditions of PR #1273 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-14 13:39 (2), (3); `cra`
-- 13:30 CGR-218, CGR-219; ADR-196 amendment 14:10).
--
-- 1. CGR-218 (A): `private.qual_cell_for_client(kind, grade, activity)` reads the QAM-0.2 cell (PROPOSED) in the
--    strictest context that fits the client kind, until the Clinical Owner decides CR-180 (PROPOSED):
--      `household`     the plain table;
--      `home`          NH-EXT (QUALIFICATION_MATRIX.md §4.2 «Context modifiers»): every «D» and every «E» in a row B*
--                      reads «?»;
--      `hospital_ward` HOSP-IN: every row reads «?»;
--      any other kind  «?» (fail-closed).
--    A missing cell or a cell with an open question reads «?» (ADR-163 (a)). A «?» counts as «-» (CR-179).
--    `private.qual_reading(kind)` names the reading for the client's words: plain, nh_ext_strict, hosp_in_strict.
-- 2. CGR-219: ONE reading for confirm and member step. `private.qual_activity_orderable(kind, grade, activity,
--    required)`: «E» → true (the member step then checks the cell's evidence), «D» → only when not required (ADR-196 (3),
--    plain table only), otherwise false. `client_order_check` refuses an activity that is not orderable
--    (`level_activity_conflict`, named in `conflict_activities`), so a required «D» is refused at confirm instead of
--    being sent and then excluded everywhere. `private.member_activity_ok(org, user, kind, grade, tags, required, at)`
--    is the activity step of `order_member_step` and uses the same function.
-- 3. `client_order_check` also returns `conflict_reading`. Everything else in 0132 is unchanged.
-- The PO adopted the stricter of two `cra` review positions (D-27); no clinical rule is created or confirmed here, the
-- cells and CR-180 stay PROPOSED. Consequence for Phase A (PO 13:39 (2)): no `hospital_ward` order is confirmable, and
-- on `home` orders every «D» and every row-B* «E» is refused. Synthetic data only.
-- Idempotent: `create or replace`.

-- 1. The reading through the client kind ------------------------------------------------------------------------------
create or replace function private.qual_reading(p_client_kind text)
returns text language sql immutable set search_path = ''
as $$
  select case p_client_kind when 'household' then 'plain' when 'home' then 'nh_ext_strict'
                            when 'hospital_ward' then 'hosp_in_strict' else 'unknown' end
$$;
revoke all on function private.qual_reading(text) from public, anon, authenticated;

create or replace function private.qual_cell_for_client(p_client_kind text, p_grade text, p_activity text)
returns text language sql stable security definer set search_path = ''
as $$
  select case
           when c.value is null or c.open_question is not null then '?'           -- ADR-163 (a), missing cell
           when p_client_kind = 'household' then c.value                          -- plain table
           when p_client_kind = 'home' then                                       -- NH-EXT (CR-180, PROPOSED)
             case when c.value = 'D' then '?'
                  when c.value = 'E' and p_activity like 'B%' then '?'
                  else c.value end
           else '?'                                                               -- HOSP-IN, unknown kind
         end
  from (select 1) one
  left join public.qual_matrix_cells c
    on c.version = private.qual_matrix_version() and c.activity_code = p_activity and c.grade = p_grade
$$;
revoke all on function private.qual_cell_for_client(text, text, text) from public, anon, authenticated;
comment on function private.qual_cell_for_client(text, text, text) is
  '0133 / CGR-218 (A): the QAM-0.2 cell read in the strictest context for the client kind until CR-180 is decided.';

create or replace function private.qual_activity_orderable(p_client_kind text, p_grade text, p_activity text,
                                                           p_required boolean)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case private.qual_cell_for_client(p_client_kind, p_grade, p_activity)
           when 'E' then true
           when 'D' then not coalesce(p_required, true)
           else false end
$$;
revoke all on function private.qual_activity_orderable(text, text, text, boolean) from public, anon, authenticated;
comment on function private.qual_activity_orderable(text, text, text, boolean) is
  '0133 / CGR-219: the one reading confirm and member step share. E → orderable (evidence checked per member); '
  'D → only when not required; -, ? → never.';

-- 2. The activity step of one member, on the same reading --------------------------------------------------------------
create or replace function private.member_activity_ok(p_org uuid, p_user_id uuid, p_client_kind text, p_grade text,
                                                      p_tags text[], p_required text[], p_at timestamptz)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare
  a    text;
  r    text;
  cell public.qual_matrix_cells;
  ev   record;
begin
  foreach a in array coalesce(p_tags, '{}') loop
    if not private.qual_activity_orderable(p_client_kind, p_grade, a, a = any (coalesce(p_required, '{}'))) then
      return false;
    end if;
    if private.qual_cell_for_client(p_client_kind, p_grade, a) = 'E' then
      cell := null;
      select * into cell from public.qual_matrix_cells c
       where c.version = private.qual_matrix_version() and c.activity_code = a and c.grade = p_grade;
      foreach r in array coalesce(cell.requires, '{}') loop
        select * into ev from private.qual_evidence_state(p_org, p_user_id, r, p_at);
        if ev.state is distinct from 'verified' then return false; end if;
      end loop;
    end if;
    -- «D» (household, not required): level allowed; a delegation belongs to a case and is checked at the visit
    -- (QUAL1). For a shift order nothing checks it yet (`cra` 13:30; Clinical Owner, CR-180: UNKNOWN).
  end loop;
  return true;
end;
$$;
revoke all on function private.member_activity_ok(uuid, uuid, text, text, text[], text[], timestamptz)
  from public, anon, authenticated;

-- 3. The confirm check on the same reading (0132 body otherwise unchanged) ------------------------------------------
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
  -- BK-b2 / CGR-216 (a): no activity may read «-» or «?» for the chosen level; an open question counts as «?» (ADR-163
  -- strict default (a)); a missing cell is never allowed. Read as ordered: no mapping (CGR-216 (b), CGR-205 (d)).
  -- 0133 / CGR-218 (A), CGR-219: the same reading as the member step (`private.qual_activity_orderable`), through the
  -- client kind; a required activity needs own scope. Not computed while the tags themselves are malformed.
  if p_grade in ('ags_eba', 'fage_efz', 'nurse_hf_fh')
     and not ('tag_unknown' = any (problems)) and not ('required_tag_not_in_tags' = any (problems)) then
    select coalesce(array_agg(q.code order by q.sort), '{}') into conflicts
    from public.qual_activities q
    where q.code = any (coalesce(p_activity_tags, '{}'))
      and not private.qual_activity_orderable(acct.client_kind, p_grade, q.code, q.code = any (req));
    if cardinality(conflicts) > 0 then problems := array_append(problems, 'level_activity_conflict'); end if;
  end if;

  return jsonb_build_object(
    'problems', to_jsonb(problems),
    'conflict_activities', to_jsonb(conflicts),
    'conflict_reading', private.qual_reading(acct.client_kind),
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

-- 4. The member step on the same reading (0132 body otherwise unchanged) -----------------------------------------------
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
  'BK-b2 / CGR-204 (a) / ADR-196, 0133: how far one member gets for one order (0 not active, 1 level, 2 activity '
  '(private.member_activity_ok, the reading of CGR-218 (A) and CGR-219), 3 availability for the whole slot, '
  '4 eligible). Private: no app role reads who is eligible.';
