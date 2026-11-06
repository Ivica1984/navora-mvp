-- CGR-75 (5) (`cra`, PLAN3 acceptance condition; ADR-158; no migration): pins the seed day the e2e `plan3.spec` uses at
-- 390 px, so the e2e cannot pass or fail on a different fixture than this. All data synthetic (seed.sql Testorganisation
-- G, the day after tomorrow: open …5c6 09:00, …5c7 11:00 (Testfall G1, primary bezugg), …5c8 09:15-09:45 and …5c9 14:00
-- category B (Testfall G2); assigned …5ca 14:00 to teamg and …5cb 14:00 to bezugg). No AI service is called.
--   (1) a visit no member may take is proposed as "kein Vorschlag" with its reason, never dropped;
--   (2) in a ticked list, a line made `overlap` by a confirmation after the proposal is refused with its reason, its
--       visit stays unassigned and its line open, the other ticked line is set;
--   (3) a decided "kein Vorschlag" sets nobody; the visit stays in the uncovered path (`team_open_visits`).
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'teamg' then '00000000-0000-4000-a000-0000000009e1' when 'bezugg' then '00000000-0000-4000-a000-0000000009e2'
                 when 'assistg' then '00000000-0000-4000-a000-0000000009e3' end)::uuid
$$;
create function pg_temp.team() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001a1'::uuid $$;
create function pg_temp.vis(s text) returns uuid language sql immutable as $$ select ('00000000-0000-4000-a000-0000000005' || s)::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1170000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create temp table d2 as select visit_date as d from public.care_visits where id = '00000000-0000-4000-a000-0000000005c6';
create function pg_temp.d() returns date language sql stable as $$ select d from d2 $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.lineof(s text) returns jsonb language sql as $$
  select e from jsonb_array_elements(pg_temp.rows('teamg', format('select * from public.day_plan(%L, %L)', pg_temp.team(), pg_temp.d()))) e
  where e ->> 'visit_id' = pg_temp.vis(s)::text $$;
create function pg_temp.sug(s text) returns uuid language sql stable as $$
  select x.id from public.ai_suggestions x where x.entity_id = pg_temp.vis(s) and x.agent_key = 'plan3_day_proposal'
  order by x.seq desc limit 1 $$;
create function pg_temp.resp(s text) returns uuid language sql stable as $$
  select responsible_user_id from public.care_visits where id = pg_temp.vis(s) $$;

-- Fixture: the seed day is the day after tomorrow and holds exactly the six visits above -------------------------------------
select is((select count(*)::int from public.care_visits where team_id = pg_temp.team() and visit_date = pg_temp.d()), 6,
  'fixture: Testteam G has six visits the day after tomorrow (four open, two assigned at 14:00)');

select is(pg_temp.cmd('teamg', format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.team(), pg_temp.k(1))) #>> '{}', 'ok',
  'fixture: a member of Testteam G switches the day proposal on (PLAN3-10)');
select is(pg_temp.cmd('teamg', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.d(), pg_temp.k(2)))
          - 'proposal_id', '{"result":"ok","lines":4,"not_found":1}'::jsonb,
  'CGR-75 (5): four open visits give four lines, one of them "kein Vorschlag"; the two assigned visits are not proposed');

-- (1) the unstaffable visit is a line of its own with its reason ----------------------------------------------------------------
select ok(pg_temp.lineof('c9') ->> 'member_id' is null and pg_temp.lineof('c9') ->> 'not_found_reason' = 'overlap'
          and pg_temp.lineof('c9') ->> 'decision' = 'open',
  'CGR-75 (5) (1): the 14:00 category B visit is listed open as "kein Vorschlag" with reason overlap (both nurses hold 14:00)');
select ok(pg_temp.lineof('c6') ->> 'member_id' = pg_temp.u('bezugg')::text and pg_temp.lineof('c7') ->> 'member_id' = pg_temp.u('bezugg')::text
          and pg_temp.lineof('c6') ->> 'reason' = 'primary_nurse',
  'fixture: 09:00 and 11:00 (Testfall G1) are proposed to the primary nurse');
select ok(pg_temp.lineof('c8') ->> 'member_id' is not null and pg_temp.lineof('c8') ->> 'member_id' <> pg_temp.u('bezugg')::text,
  'fixture: 09:15 overlaps her proposed 09:00, so it is proposed to another member (PLAN3-2)');

-- (2) a ticked list with one line made `overlap` after the proposal ---------------------------------------------------------------
select is(pg_temp.cmd('teamg', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug('c8'), 'corrected',
            to_jsonb(pg_temp.u('bezugg')::text)::text, pg_temp.k(3))) ->> 'result', 'ok',
  'fixture: the 09:15 line is changed to the primary nurse and confirmed (nothing of hers at 09:15 yet)');
select is(pg_temp.cmd('teamg', format('select public.confirm_suggestions(%L::uuid[], %L)',
            array[pg_temp.sug('c6'), pg_temp.sug('c7')], pg_temp.k(4))),
  jsonb_build_object('result', 'ok', 'confirmed', 1,
                     'refused', jsonb_build_array(jsonb_build_object('suggestion_id', pg_temp.sug('c6'), 'reason', 'overlap'))),
  'CGR-75 (5) (2): the ticked 09:00 line is refused overlap with its id; the ticked 11:00 line is set');
select ok(pg_temp.resp('c6') is null and pg_temp.lineof('c6') ->> 'decision' = 'open'
          and not exists (select 1 from public.ai_confirmations where suggestion_id = pg_temp.sug('c6')),
  'CGR-75 (5) (2): the refused visit stays unassigned and its line stays open (no confirmation row)');
select ok(pg_temp.resp('c7') = pg_temp.u('bezugg') and pg_temp.resp('c8') = pg_temp.u('bezugg'),
  'CGR-75 (5) (2): the other ticked visit and the changed visit have their member');
select ok(exists (select 1 from jsonb_array_elements(pg_temp.rows('teamg', format('select * from public.team_open_visits(%L)', pg_temp.d()))) e
                  where e ->> 'visit_id' = pg_temp.vis('c6')::text),
  'CGR-75 (5) (2): the refused visit is in the uncovered path (team_open_visits)');

-- (3) a decided "kein Vorschlag" sets nobody --------------------------------------------------------------------------------------
select is(pg_temp.cmd('teamg', format('select public.confirm_suggestion(%L, %L, null::jsonb, %L)', pg_temp.sug('c9'), 'not_found',
            pg_temp.k(5))) ->> 'result', 'ok',
  'CGR-75 (5) (3): the "kein Vorschlag" line is decided as such');
select ok(pg_temp.resp('c9') is null and pg_temp.lineof('c9') ->> 'decision' = 'not_found'
          and (pg_temp.lineof('c9') ->> 'visit_has_responsible')::boolean = false,
  'CGR-75 (5) (3): its visit still has nobody and day_plan says so (PLAN3-9 (1))');
select ok(exists (select 1 from jsonb_array_elements(pg_temp.rows('teamg', format('select * from public.team_open_visits(%L)', pg_temp.d()))) e
                  where e ->> 'visit_id' = pg_temp.vis('c9')::text),
  'CGR-75 (5) (3): the decided "kein Vorschlag" visit stays in the uncovered path, never dropped');

select * from finish();
rollback;
