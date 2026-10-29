-- ADM2 part (b): the recorded contract end ends access on time (PO brief docs/agents/briefs/ADM2.md, ADM2-11 to ADM2-15;
-- `cra` CGR-72 remediation plan docs/agents/clinical/remediation/CGR-72.md; ADR-115). Part (a) is migration 0091 (ADR-114).
--
-- Design (ADR-115):
-- * The contract record (`member_contract_events`, 0091; append-only, dates only, the newest row per organisation
--   membership is current) is the only input. `set_member_contract_end` (administrator, audited, idempotent, switch on)
--   records or changes the end date "in Vertrag erfasst or later", for ADM1 members too (ADM2-11).
-- * ADM2-13, engineering question 1: evaluated at READ TIME in `private.access_ended` (one more index probe on
--   member_contract_events_user_idx). From the start of the Zurich day after the end date (`private.at_zurich`, DST-safe:
--   00:00 local is never ambiguous) she is treated exactly as after `end_member_access`: every LEAVE1-3 guard (RLS
--   restrictive policy, membership helpers, read models, begin_command, push_active, SIG1 receiver sets) already reads
--   `private.access_ended`, so no job is needed (D-2) and the end is never late. A `member_access_events` row created at
--   or after that instant (a `restore_member_access`) takes precedence, so restore works as today; a changed end date
--   before the instant moves it. The same predicate withholds access before the contract start date (ADM2-6 "active from
--   the start date", PLANNED in ADR-114). The access record itself gets no row (deviation 1 in ADR-115: a writer of that
--   table would be a new function in LEAVE1's catalogue, pgTAP 074, which must stay unmodified).
-- * ADM2-11: from the moment the end date is recorded, planning, take, cover, the ABS1 return and PLAN2 generation refuse
--   her as responsible for a visit dated after the end date (`private.adm2_in_contract`), and the BEFORE trigger of 0091
--   refuses every other path (`outside_contract`). Her planned visits after the end date are released in the same command
--   by the one release rule (`private.release_member_visits`, LEAVE1-13), fixed text "Vertragsende".
-- * ADM2-12 / ADM2-15 (a): `contract_end_handover()`: from 14 Zurich days before the end date until her access ends, the
--   registered nurses of her teams and the organisation's administrators see her end date, her open cases as primary or
--   deputy nurse (case reference and role only) and her responsible or covered visits up to the end date (case
--   reference, visit date and role only). Her open reports by kind come from the existing LEAVE1-12 list
--   (`member_open_reports`, unchanged, same readers). No client name, address or health content; no count.
-- * ADM2-14: (a) `my_contract_end()`: in the same window she reads her end date and the date her access ends; /work shows
--   it beside her own `my_unexported_working_days` (unchanged) and the existing export prompt. (b) the administrator's
--   entry in the ADM2-12 list opens the recorded `prepare_member_access_end` read (0087, unchanged). Recording the end
--   date returns no count; no other reader of the count is added.
-- * ADM2-15 (b): `team_successor_items()`: from the access end, every open case of the caller's teams that still names a
--   person whose access ended as primary or deputy nurse ("Bezugspflege neu bestimmen" / "Stellvertretung neu bestimmen"),
--   resolved by `set_primary_nurse` (J6, unchanged). OPS1: one exception `successor_needed` per case and role in
--   `private.derived_exceptions`, so take, comment, close and the sync's auto close apply unchanged; it disappears with
--   its cause (team names someone else, or restore). No threshold, ordering or escalation clock; NAVORA names nobody.
-- * ADM2-15 (c): nothing above conditions the access end.
-- No clinical, tariff or legal rule. The 14-day window is a product choice (brief); the OPS1 priority P2 is OPS1's own
-- continuity class (ADR-115, OPEN for po). Idempotent: create or replace, if not exists, on conflict, marker-checked patches.

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.adm2b_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0092 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0092 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.adm2b_patch(text, text[], text) from public, anon, authenticated;

-- 1. Constant and helpers -----------------------------------------------------------------------------------------------
create or replace function private.adm2_handover_days() returns integer language sql immutable set search_path = ''
as $$ select 14 $$;
revoke all on function private.adm2_handover_days() from public, anon, authenticated;
comment on function private.adm2_handover_days() is
  'ADM2-12/-14/-15 (a): Zurich calendar days before the recorded end date from which her open work is shown (product '
  'choice of the brief, measured in the pilot).';

-- The current contract of one organisation membership: the newest row (no row: no contract recorded).
create or replace function private.adm2_contract(p_org uuid, p_user uuid)
returns table (start_date date, end_date date)
language sql stable security definer set search_path = ''
as $$
  select e.start_date, e.end_date from public.member_contract_events e
  where e.organization_id = p_org and e.user_id = p_user
  order by e.seq desc limit 1
$$;
revoke all on function private.adm2_contract(uuid, uuid) from public, anon, authenticated;

-- The instant her access ends for a contract end date: the start of the Zurich day after it.
create or replace function private.adm2_access_end_instant(p_end date)
returns timestamptz language sql immutable set search_path = ''
as $$ select case when p_end is null then null else private.at_zurich((p_end + 1) + time '00:00') end $$;
revoke all on function private.adm2_access_end_instant(date) from public, anon, authenticated;

-- ADM2-11: may she be responsible for (or cover) a visit on this date? True without a contract record (ADM1 members).
create or replace function private.adm2_in_contract(p_org uuid, p_user uuid, p_date date)
returns boolean language sql stable security definer set search_path = ''
as $$
  select p_user is null or p_date is null or coalesce(
    (select (c.start_date is null or p_date >= c.start_date) and (c.end_date is null or p_date <= c.end_date)
     from private.adm2_contract(p_org, p_user) c), true)
$$;
revoke all on function private.adm2_in_contract(uuid, uuid, date) from public, anon, authenticated;
comment on function private.adm2_in_contract(uuid, uuid, date) is
  'ADM2-11 (ADR-115): the date lies inside her recorded contract (start and end inclusive); true when none is recorded.';

-- Her recorded end date while it lies ahead or is today (null otherwise), and the newest such contract's organisation.
create or replace function private.adm2_pending_end(p_user uuid)
returns table (organization_id uuid, end_date date)
language sql stable security definer set search_path = ''
as $$
  select m.organization_id, c.end_date
  from public.organization_memberships m
  cross join lateral private.adm2_contract(m.organization_id, m.user_id) c
  where m.user_id = p_user and c.end_date is not null and c.end_date >= (private.at_zurich(private.now()))::date
  order by c.end_date, m.organization_id
$$;
revoke all on function private.adm2_pending_end(uuid) from public, anon, authenticated;

-- The instant her contract end took effect, when it has (null otherwise). Reads the contract only.
create or replace function private.adm2_contract_ended_at(p_user uuid)
returns timestamptz language sql stable security definer set search_path = ''
as $$
  select max(private.adm2_access_end_instant(c.end_date))
  from public.organization_memberships m
  cross join lateral private.adm2_contract(m.organization_id, m.user_id) c
  where m.user_id = p_user and c.end_date is not null and private.adm2_access_end_instant(c.end_date) <= private.now()
$$;
revoke all on function private.adm2_contract_ended_at(uuid) from public, anon, authenticated;

-- Her contract has not started yet (start date after today): no access before it (ADM2-6).
create or replace function private.adm2_contract_not_started(p_user uuid)
returns date language sql stable security definer set search_path = ''
as $$
  select min(c.start_date)
  from public.organization_memberships m
  cross join lateral private.adm2_contract(m.organization_id, m.user_id) c
  where m.user_id = p_user and c.start_date is not null and c.start_date > (private.at_zurich(private.now()))::date
$$;
revoke all on function private.adm2_contract_not_started(uuid) from public, anon, authenticated;

-- A short case reference for the handover lists (no client name): the last six hex digits of the case id.
create or replace function private.case_reference(p_case uuid)
returns text language sql immutable set search_path = ''
as $$ select case when p_case is null then null else upper(right(replace(p_case::text, '-', ''), 6)) end $$;
revoke all on function private.case_reference(uuid) from public, anon, authenticated;
comment on function private.case_reference(uuid) is
  'ADM2-15 (ADR-115): a case reference without client data (last six hex digits of the id), shown as "Fall-Ref.".';

-- 2. ADM2-13: the access predicate reads the contract (LEAVE1-3 keeps its single predicate) -----------------------------
create or replace function private.access_ended(p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select p_user is not null and (
    exists (
      select 1 from public.member_access_events e
      where e.user_id = p_user and e.kind = 'ended'
        and not exists (select 1 from public.member_access_events l
                        where l.user_id = e.user_id and l.organization_id = e.organization_id and l.seq > e.seq))
    -- ADM2-13 (ADR-115): from the start of the Zurich day after her recorded contract end, unless an access event of
    -- that membership was recorded at or after that instant (restore_member_access); ADM2-6: before the start date.
    or exists (
      select 1 from public.organization_memberships m
      cross join lateral private.adm2_contract(m.organization_id, m.user_id) c
      where m.user_id = p_user
        and ((c.end_date is not null
              and private.adm2_access_end_instant(c.end_date) <= private.now()
              and not exists (select 1 from public.member_access_events a
                              where a.user_id = m.user_id and a.organization_id = m.organization_id
                                and a.created_at >= private.adm2_access_end_instant(c.end_date)))
             or (c.start_date is not null and c.start_date > (private.at_zurich(private.now()))::date))))
$$;
revoke all on function private.access_ended(uuid) from public, anon;
grant execute on function private.access_ended(uuid) to authenticated;
comment on function private.access_ended(uuid) is
  'LEAVE1: true while the newest access event of any of the person''s organisation memberships is `ended`. ADM2-13 '
  '(ADR-115): also from the start of the Zurich day after her recorded contract end (unless an access event of that '
  'membership is at or after that instant), and before her recorded contract start.';

-- When her current access end took effect: the newer of the recorded end and the contract end.
create or replace function private.access_ended_at(p_user uuid)
returns timestamptz
language sql stable security definer set search_path = ''
as $$
  select case when private.access_ended(p_user) then
    nullif(greatest(coalesce((select max(e.created_at) from public.member_access_events e
                              where e.user_id = p_user and e.kind = 'ended'), '-infinity'::timestamptz),
                    coalesce(private.adm2_contract_ended_at(p_user), '-infinity'::timestamptz)), '-infinity'::timestamptz)
  end
$$;
revoke all on function private.access_ended_at(uuid) from public, anon, authenticated;
comment on function private.access_ended_at(uuid) is
  'LEAVE1-5: when the person''s current access end took effect (ADM2-13: or her contract end); null while her access '
  'is open. Never the reason code.';

-- Her own state (LEAVE1-6): {ended, ended_at, starts_on}; starts_on only before her contract start (ADM2-6).
create or replace function public.my_access_state()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'ended', private.access_ended((select auth.uid())),
    'ended_at', case when private.access_ended((select auth.uid())) then
                  nullif(greatest(coalesce((select max(e.created_at) from public.member_access_events e
                                            where e.user_id = (select auth.uid()) and e.kind = 'ended'), '-infinity'::timestamptz),
                                  coalesce(private.adm2_contract_ended_at((select auth.uid())), '-infinity'::timestamptz)),
                         '-infinity'::timestamptz) end,
    'starts_on', private.adm2_contract_not_started((select auth.uid())))
$$;
revoke all on function public.my_access_state() from public, anon;
grant execute on function public.my_access_state() to authenticated;
comment on function public.my_access_state() is
  'LEAVE1-6: {ended, ended_at, starts_on} for the signed-in person; no reason code, no names, no counts. ADM2-13: '
  'ended_at is the contract end when that ended it; ADM2-6: starts_on while her contract has not started.';

-- LEAVE1-14 / LEAVE1-C5: a signal or quality take of hers lapses when her contract end passed after the take, too.
create or replace function private.signal_take_lapsed(p_taker uuid, p_access_seq bigint, p_taken_at timestamptz)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.access_ended(p_taker)
      or exists (select 1 from public.member_access_events e
                 where e.user_id = p_taker and e.kind = 'ended'
                   and case when p_access_seq is null then e.created_at >= p_taken_at else e.seq > p_access_seq end)
      -- ADM2-13 (ADR-115): her contract end took effect after the take
      or coalesce(private.adm2_contract_ended_at(p_taker) > p_taken_at, false)
$$;
revoke all on function private.signal_take_lapsed(uuid, bigint, timestamptz) from public, anon, authenticated;

-- 3. ADM2-11: record or change the end date -------------------------------------------------------------------------------
-- p_end_date null removes the end date. Return jsonb {result: 'ok'|'unchanged'|'admission_off'|'no_contract'|'in_past'|
--   'access_ended'|'self'|'last_admin'|'has_planned_visits'|'duplicate'|'rejected', released?: {team_id: n},
--   access_ends_on?: date}. Never a count.
create or replace function public.set_member_contract_end(p_user_id uuid, p_end_date date, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  org      uuid;
  role_    text;
  today    date := (private.at_zurich(private.now()))::date;
  cur      record;
  t        record;
  n        integer;
  released jsonb := '{}'::jsonb;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('set_member_contract_end', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_user_id is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if p_user_id = uid then
    return jsonb_build_object('result', private.end_command('self'));
  end if;
  org := private.leave1_org_for(p_user_id);  -- an organisation of hers that the caller administers
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if not private.team_admission_on(org) then
    return jsonb_build_object('result', private.end_command('admission_off'));
  end if;
  select m.role into role_ from public.organization_memberships m
    where m.organization_id = org and m.user_id = p_user_id for update;
  if private.access_ended(p_user_id) then
    return jsonb_build_object('result', private.end_command('access_ended'));
  end if;
  if p_end_date is not null and p_end_date < today then
    return jsonb_build_object('result', private.end_command('in_past'));
  end if;
  select * into cur from private.adm2_contract(org, p_user_id);
  if p_end_date is not null and cur.start_date is not null and p_end_date < cur.start_date then
    raise exception 'the end date is before the start date' using errcode = '22023';
  end if;
  if found and cur.end_date is not distinct from p_end_date then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;
  if not found and p_end_date is null then
    return jsonb_build_object('result', private.end_command('no_contract'));
  end if;
  -- ADM1 rule (as end_member_access): the organisation keeps at least one administrator with access.
  if p_end_date is not null and role_ = 'admin'
     and (select count(*) from public.organization_memberships m
          where m.organization_id = org and m.role = 'admin' and m.user_id <> p_user_id
            and not private.access_ended(m.user_id)) < 1 then
    return jsonb_build_object('result', private.end_command('last_admin'));
  end if;
  -- As LEAVE1-13: a planned visit she covers for another team after the end date still refuses (COVER1 off).
  if p_end_date is not null and exists (
       select 1 from public.care_visits v
       where v.organization_id = org and v.status = 'planned' and v.visit_date > p_end_date and v.covered_by = p_user_id) then
    return jsonb_build_object('result', private.end_command('has_planned_visits'));
  end if;

  insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id)
  values (org, p_user_id, cur.start_date, p_end_date, uid);
  -- ADM2-11: her planned visits after the end date go to the team now, by the one release rule (LEAVE1-13), inside this
  -- command's context, so the visit audit rows carry this command and key. Team-readable text only.
  if p_end_date is not null then
    for t in select distinct v.team_id from public.care_visits v
             where v.organization_id = org and v.responsible_user_id = p_user_id and v.status = 'planned'
               and v.visit_date > p_end_date and v.visit_date >= today
             order by v.team_id loop
      n := private.release_member_visits(t.team_id, p_user_id, p_end_date + 1, null, 'Vertragsende', uid);
      if n > 0 then released := released || jsonb_build_object(t.team_id::text, n); end if;
    end loop;
  end if;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'organization_memberships', p_user_id::text, 'set_member_contract_end',
          jsonb_build_object('contract_end_date', jsonb_build_object('old', cur.end_date, 'new', p_end_date),
                             'released_visits', released),
          'contract_end', uid, p_idempotency_key);
  perform private.audit_command(org, 'organization_memberships', p_user_id,
          jsonb_build_object('contract_end_date', p_end_date, 'released_visits', released));
  return jsonb_build_object('result', private.end_command('ok'), 'released', released,
                            'access_ends_on', p_end_date + 1);
end;
$$;
revoke all on function public.set_member_contract_end(uuid, date, uuid) from public, anon;
grant execute on function public.set_member_contract_end(uuid, date, uuid) to authenticated;
comment on function public.set_member_contract_end(uuid, date, uuid) is
  'ADM2-11: an organisation administrator records or changes a member''s contract end date (null removes it); for ADM1 '
  'members too; team admission switched on. Releases her planned visits after the end date to the team (release rule '
  'of LEAVE1-13, text "Vertragsende"). Her access ends at the start of the Zurich day after it (ADM2-13). Dates only; '
  'no reason or author field; never a count. Returns {result, released, access_ends_on}.';

-- 4. ADM2-11: refused as responsible after the end date ---------------------------------------------------------------------
select private.adm2b_patch('private.generate_case_plan(uuid, uuid)', array[
  E'and private.has_qualification(c.assigned_team_id, c.primary_nurse_id) /* ADM2-6 */',
  E'and private.has_qualification(c.assigned_team_id, c.primary_nurse_id) /* ADM2-6 */\n'
  || E'             and private.adm2_in_contract(c.organization_id, c.primary_nurse_id, d) /* ADM2-11 */',
  '1',
  E'and private.has_qualification(c.assigned_team_id, c.deputy_nurse_id) /* ADM2-6 */',
  E'and private.has_qualification(c.assigned_team_id, c.deputy_nurse_id) /* ADM2-6 */\n'
  || E'             and private.adm2_in_contract(c.organization_id, c.deputy_nurse_id, d) /* ADM2-11 */',
  '1'], 'ADM2-11');

select private.adm2b_patch(
  'public.plan_visit(uuid, date, time without time zone, time without time zone, integer, integer, integer, boolean, uuid, uuid)',
  array[
    E'    -- ABS1-C4: never to a member absent',
    E'    -- ADM2-11: never for a date outside her recorded contract (ADR-115).\n'
    || E'    if not private.adm2_in_contract(c.organization_id, p_responsible_user_id, p_visit_date) then\n'
    || E'      perform private.end_command(''rejected'');\n'
    || E'      return jsonb_build_object(''result'', ''rejected'', ''reason'', ''outside_contract'');\n'
    || E'    end if;\n'
    || E'    -- ABS1-C4: never to a member absent',
    '1'], 'ADM2-11');

select private.adm2b_patch('public.take_open_visit(uuid, uuid)', array[
  E'    return jsonb_build_object(''result'', private.end_command(''not_qualified''));\n  end if;\n',
  E'    return jsonb_build_object(''result'', private.end_command(''not_qualified''));\n  end if;\n'
  || E'  -- ADM2-11 (ADR-115): never for a date outside her recorded contract.\n'
  || E'  if not private.adm2_in_contract(v.organization_id, uid, v.visit_date) then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''outside_contract''));\n'
  || E'  end if;\n',
  '1'], 'ADM2-11');

select private.adm2b_patch('public.team_open_visits(date)', array[
  E'private.may_perform_visit(o.team_id, (select uid from me), o.planned_minutes_b, o.is_needs_assessment)\n',
  E'private.may_perform_visit(o.team_id, (select uid from me), o.planned_minutes_b, o.is_needs_assessment)\n'
  || E'           and private.adm2_in_contract(o.organization_id, (select uid from me), o.visit_date) /* ADM2-11 */\n',
  '1'], 'ADM2-11');

select private.adm2b_patch('public.change_absence(uuid, boolean, date, time without time zone, uuid)', array[
  E'and private.may_perform_visit(g.team_id, g.user_id, x.planned_minutes_b, x.is_needs_assessment)\n',
  E'and private.may_perform_visit(g.team_id, g.user_id, x.planned_minutes_b, x.is_needs_assessment)\n'
  || E'        and private.adm2_in_contract(x.organization_id, g.user_id, x.visit_date) /* ADM2-11 */\n',
  '1'], 'ADM2-11');

select private.adm2b_patch('private.cover_team_for(public.care_visits, uuid)', array[
  E'and m.qualification is not null /* ADM2-6 */',
  E'and m.qualification is not null /* ADM2-6 */ and private.adm2_in_contract(p_visit.organization_id, p_user, p_visit.visit_date) /* ADM2-11 */',
  '1'], 'ADM2-11');

-- Backstop (0091 trigger): no other path makes her responsible or covering outside her contract.
create or replace function private.adm2_guard_responsible()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.responsible_user_id is not null
     and (tg_op = 'INSERT' or new.responsible_user_id is distinct from old.responsible_user_id)
     and exists (select 1 from public.team_memberships m
                 where m.team_id = new.team_id and m.user_id = new.responsible_user_id and m.qualification is null) then
    raise exception 'qualification_missing' using errcode = '42501',
      detail = 'ADM2-6: a member without a qualification is not responsible for a visit.';
  end if;
  if new.covered_by is not null
     and (tg_op = 'INSERT' or new.covered_by is distinct from old.covered_by)
     and exists (select 1 from public.team_memberships m
                 where m.team_id = new.cover_team_id and m.user_id = new.covered_by and m.qualification is null) then
    raise exception 'qualification_missing' using errcode = '42501',
      detail = 'ADM2-6: a member without a qualification does not cover a visit.';
  end if;
  -- ADM2-11 (ADR-115): never for a visit dated outside her recorded contract.
  if new.responsible_user_id is not null
     and (tg_op = 'INSERT' or new.responsible_user_id is distinct from old.responsible_user_id
          or new.visit_date is distinct from old.visit_date)
     and not private.adm2_in_contract(new.organization_id, new.responsible_user_id, new.visit_date) then
    raise exception 'outside_contract' using errcode = '42501',
      detail = 'ADM2-11: a member is not responsible for a visit dated outside her recorded contract.';
  end if;
  if new.covered_by is not null
     and (tg_op = 'INSERT' or new.covered_by is distinct from old.covered_by or new.visit_date is distinct from old.visit_date)
     and not private.adm2_in_contract(new.organization_id, new.covered_by, new.visit_date) then
    raise exception 'outside_contract' using errcode = '42501',
      detail = 'ADM2-11: a member does not cover a visit dated outside her recorded contract.';
  end if;
  return new;
end;
$$;
revoke all on function private.adm2_guard_responsible() from public, anon, authenticated;
drop trigger if exists care_visits_adm2_qualification on public.care_visits;
create trigger care_visits_adm2_qualification
  before insert or update of responsible_user_id, covered_by, visit_date on public.care_visits
  for each row execute function private.adm2_guard_responsible();

-- 5. ADM2-12 / ADM2-14 (b) / ADM2-15 (a): the handover list -------------------------------------------------------------------
-- For each person with a recorded end date in the next ADM2_HANDOVER_DAYS (inclusive) whose access is still open: to the
-- organisation's administrators, and to the registered nurses of a team she belongs to (entries of that team only).
-- [{user_id, member_name, end_date, access_ends_on, teams: [name], cases: [{case_id, case_ref, team, role}],
--   visits: [{case_ref, visit_date, team, role}]}]. No client name, no address, no health content, no count.
create or replace function public.contract_end_handover()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  today date := (private.at_zurich(private.now()))::date;
begin
  if uid is null or private.access_ended(uid) then return '[]'::jsonb; end if;  -- LEAVE1-3
  return coalesce((
    with leavers as (
      select m.organization_id, m.user_id, c.end_date, private.is_org_admin(m.organization_id) as as_admin
      from public.organization_memberships m
      cross join lateral private.adm2_contract(m.organization_id, m.user_id) c
      where c.end_date is not null and today between c.end_date - private.adm2_handover_days() and c.end_date
        and m.user_id <> uid and not private.access_ended(m.user_id)
        and private.is_org_member(m.organization_id)),
    -- the teams whose entries the caller reads: every team of the organisation for an administrator, otherwise the teams
    -- where she is a registered nurse and the leaver a member
    seen as (
      select l.user_id, t.id as team_id, t.name
      from leavers l join public.teams t on t.organization_id = l.organization_id
      where l.as_admin
         or (private.is_team_member(t.id) and private.is_registered_nurse(t.id, uid)
             and exists (select 1 from public.team_memberships x where x.team_id = t.id and x.user_id = l.user_id)))
    select jsonb_agg(jsonb_build_object(
             'user_id', l.user_id,
             'member_name', private.member_name(l.organization_id, l.user_id),
             'end_date', l.end_date,
             'access_ends_on', l.end_date + 1,
             'teams', coalesce((select jsonb_agg(t.name order by t.name) from public.team_memberships tm
                                join public.teams t on t.id = tm.team_id
                                where tm.user_id = l.user_id and t.organization_id = l.organization_id
                                  and exists (select 1 from seen s where s.user_id = l.user_id and s.team_id = t.id)), '[]'::jsonb),
             'cases', coalesce((select jsonb_agg(jsonb_build_object(
                                         'case_id', c.id, 'case_ref', private.case_reference(c.id), 'team', s.name,
                                         'role', case when c.primary_nurse_id = l.user_id then 'primary' else 'deputy' end)
                                       order by s.name, private.case_reference(c.id))
                                from public.cases c join seen s on s.user_id = l.user_id and s.team_id = c.assigned_team_id
                                where c.lifecycle <> 'closed' and l.user_id in (c.primary_nurse_id, c.deputy_nurse_id)), '[]'::jsonb),
             'visits', coalesce((select jsonb_agg(jsonb_build_object(
                                          'case_ref', private.case_reference(v.case_id), 'visit_date', v.visit_date, 'team', s.name,
                                          'role', case when v.responsible_user_id = l.user_id then 'responsible' else 'covering' end)
                                        order by v.visit_date, v.time_start nulls first, v.id)
                                 from public.care_visits v
                                 join seen s on s.user_id = l.user_id and s.team_id = coalesce(case when v.covered_by = l.user_id
                                                                                                    then v.cover_team_id end, v.team_id)
                                 where v.organization_id = l.organization_id
                                   and v.status in ('planned', 'on_the_way', 'started', 'paused')
                                   and v.visit_date between today and l.end_date
                                   and l.user_id in (v.responsible_user_id, v.covered_by)), '[]'::jsonb))
           order by l.end_date, private.member_name(l.organization_id, l.user_id))
    from leavers l
    where exists (select 1 from seen s where s.user_id = l.user_id)), '[]'::jsonb);
end;
$$;
revoke all on function public.contract_end_handover() from public, anon;
grant execute on function public.contract_end_handover() to authenticated;
comment on function public.contract_end_handover() is
  'ADM2-12/-15 (a): from 14 Zurich days before a recorded contract end until the access end, the leaver''s end date, '
  'her open cases as primary or deputy nurse (case reference, role) and her visits up to the end date (case reference, '
  'date, role), for the organisation''s administrators and the registered nurses of her teams. Her open reports come '
  'from member_open_reports (LEAVE1-12, same readers). No client name, no health content, no count.';

-- ADM2-14 (a): her own end date and access-end date, in the same window (null outside it).
create or replace function public.my_contract_end()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select case when private.access_ended((select auth.uid())) then null  -- LEAVE1-3
    else (select jsonb_build_object('end_date', p.end_date, 'access_ends_on', p.end_date + 1)
          from private.adm2_pending_end((select auth.uid())) p
          where (private.at_zurich(private.now()))::date >= p.end_date - private.adm2_handover_days()
          order by p.end_date limit 1) end
$$;
revoke all on function public.my_contract_end() from public, anon;
grant execute on function public.my_contract_end() to authenticated;
comment on function public.my_contract_end() is
  'ADM2-14 (a): {end_date, access_ends_on} for the signed-in person from 14 Zurich days before her recorded contract '
  'end; null otherwise. No count (her unexported days stay my_unexported_working_days).';

-- 6. ADM2-15 (b): open cases still naming a person whose access ended --------------------------------------------------------
-- [{case_id, case_ref, team_id, team, role: primary|deputy, member_name, contract_end_date}] for the active members of the
-- team that holds the case. Resolved by set_primary_nurse (J6) or restore_member_access; nothing is chosen here.
create or replace function private.successor_needed(p_org uuid)
returns table (case_id uuid, team_id uuid, role text, user_id uuid)
language sql stable security definer set search_path = ''
as $$
  select c.id, c.assigned_team_id, x.role, x.uid
  from public.cases c
  cross join lateral (values ('primary', c.primary_nurse_id), ('deputy', c.deputy_nurse_id)) x(role, uid)
  where c.organization_id = p_org and c.assigned_team_id is not null and c.lifecycle <> 'closed'
    and x.uid is not null and private.access_ended(x.uid)
$$;
revoke all on function private.successor_needed(uuid) from public, anon, authenticated;

create or replace function public.team_successor_items()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare uid uuid := (select auth.uid());
begin
  if uid is null or private.access_ended(uid) then return '[]'::jsonb; end if;  -- LEAVE1-3
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'case_id', s.case_id, 'case_ref', private.case_reference(s.case_id), 'team_id', s.team_id, 'team', t.name,
             'role', s.role, 'member_name', private.member_name(t.organization_id, s.user_id),
             'access_ended_on', (private.at_zurich(private.adm2_contract_ended_at(s.user_id)))::date)
           order by t.name, private.case_reference(s.case_id), s.role desc)
    from (select distinct om.organization_id from public.organization_memberships om where om.user_id = uid) o
    cross join lateral private.successor_needed(o.organization_id) s
    join public.teams t on t.id = s.team_id
    where private.is_org_member(t.organization_id) and private.is_team_member(t.id)), '[]'::jsonb);
end;
$$;
revoke all on function public.team_successor_items() from public, anon;
grant execute on function public.team_successor_items() to authenticated;
comment on function public.team_successor_items() is
  'ADM2-15 (b): open cases of the caller''s teams that still name a person whose access ended as primary or deputy '
  'nurse ("Bezugspflege / Stellvertretung neu bestimmen"). Resolved by set_primary_nurse or restore_member_access.';

-- OPS1: one exception per case and role, closes with its cause (sync_exceptions auto close).
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step)
values ('successor_needed', 'P2', null, null, null, 'Bezugspflege ohne Zugang',
        'Team informieren: Die Bezugspflege oder Stellvertretung dieses Falls hat keinen Zugang mehr. Das Team bestimmt, '
        || 'wer übernimmt (J6); NAVORA wählt niemanden. Schliesst, sobald das Team jemanden bestimmt oder der Zugang '
        || 'wiederhergestellt ist.')
on conflict (exception_type) do nothing;

select private.adm2b_patch('private.derived_exceptions(uuid)', array[
  E'  where c.organization_id = p_org and private.order_without_end_date_holds(c.id)\n',
  E'  where c.organization_id = p_org and private.order_without_end_date_holds(c.id)\n'
  || E'  union all\n'
  || E'  -- ADM2-15 (b) (CGR-72): an open case still names a primary or deputy nurse whose access ended (closes with its cause)\n'
  || E'  select ''successor_needed:'' || s.case_id || '':'' || s.role || '':'' || s.user_id, ''successor_needed'',\n'
  || E'         coalesce(private.adm2_contract_ended_at(s.user_id), private.now()), s.case_id, s.team_id, ''case'', s.case_id,\n'
  || E'         case s.role when ''primary'' then ''Bezugspflege'' else ''Stellvertretung'' end || '' · Zugang beendet''\n'
  || E'  from private.successor_needed(p_org) s\n'
  || E'  join rules r on r.exception_type = ''successor_needed''\n',
  '1'], 'ADM2-15');

-- ADM2-13: restore_member_access (LEAVE1-7) restores an access that her contract end ended, exactly as a recorded one: the
-- `restored` row is at or after the contract instant, so the contract no longer ends her access. Otherwise unchanged.
select private.adm2b_patch('public.restore_member_access(uuid, text, uuid)', array[
  E'         where e.organization_id = org and e.user_id = p_user_id order by e.seq desc limit 1) <> ''ended'' then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''unchanged''));\n  end if;\n',
  E'         where e.organization_id = org and e.user_id = p_user_id order by e.seq desc limit 1) <> ''ended'' then\n'
  || E'    -- ADM2-13 (ADR-115): an access her contract end ended (no access event since that instant) is restored too.\n'
  || E'    if not (private.access_ended(p_user_id) and exists (\n'
  || E'              select 1 from private.adm2_contract(org, p_user_id) c\n'
  || E'              where c.end_date is not null and private.adm2_access_end_instant(c.end_date) <= private.now()\n'
  || E'                and not exists (select 1 from public.member_access_events a\n'
  || E'                                where a.organization_id = org and a.user_id = p_user_id\n'
  || E'                                  and a.created_at >= private.adm2_access_end_instant(c.end_date)))) then\n'
  || E'      return jsonb_build_object(''result'', private.end_command(''unchanged''));\n'
  || E'    end if;\n  end if;\n',
  '1'], 'ADM2-13');

-- 7. ADM2-8 clarified (po 2026-10-29 06:10, answer 3 to ADR-114): an admitted proposal without "Vertrag erfasst" lapses
-- ADM2_LAPSE_DAYS Zurich calendar days after its admission (same constant, same sweep), and its candidate data are
-- deleted in the same transaction; the team may propose her again. Open proposals lapse as before.
create or replace function private.adm2_sweep(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n integer := 0;
  cmd text := current_setting('navora.command', true);
  key text := current_setting('navora.idempotency_key', true);
begin
  -- The lapse is the system's act, not the caller's command: no command context on its rows.
  perform set_config('navora.command', '', true);
  perform set_config('navora.idempotency_key', '', true);
  for r in select p.id from public.team_admission_proposals p
           where p.organization_id = p_org
             and ((private.adm2_outcome(p.id) is null and private.adm2_lapse_at(p.created_at) <= private.now())
                  -- ADM2-8 (po 06:10): admitted, no contract recorded, 14 Zurich days after the admission
                  or (private.adm2_outcome(p.id) = 'admitted'
                      and private.adm2_lapse_at((select max(e.created_at) from public.team_admission_events e
                                                 where e.proposal_id = p.id and e.kind = 'admitted')) <= private.now()))
           for update of p loop
    perform private.adm2_close(r.id, 'lapsed', '00000000-0000-0000-0000-000000000000');
    n := n + 1;
  end loop;
  perform set_config('navora.command', coalesce(cmd, ''), true);
  perform set_config('navora.idempotency_key', coalesce(key, ''), true);
  return n;
end;
$$;
revoke all on function private.adm2_sweep(uuid) from public, anon, authenticated;
comment on function private.adm2_sweep(uuid) is
  'ADM2-5/-8: lapses an open proposal 14 Zurich days after it was made, and an admitted one without a recorded contract '
  '14 Zurich days after its admission (po 2026-10-29); deletes the candidate data in the same transaction.';

-- 8. AUD1-1 value catalogue ---------------------------------------------------------------------------------------------------
insert into private.audit_value_classes (table_name, key, class) values
  ('organization_memberships', 'contract_end_date', 'code')
on conflict (table_name, key) do nothing;

drop function private.adm2b_patch(text, text[], text);
