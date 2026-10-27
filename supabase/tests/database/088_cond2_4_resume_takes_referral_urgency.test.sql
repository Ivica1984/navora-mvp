-- COND2-4 = IPA1-C2 (migration 0088, ADR-102; brief `docs/agents/briefs/COND2.md`, added by po 2026-10-27 02:10;
-- `cra` CGR-71): when a returning referral resumes a paused case, the new referral's urgency, its source and the
-- referrer's requested start are recorded on the case (audited), and the team reads them where it handles the return.
-- COND2-4a (po 06:10, `cra` CGR-73): the return task shows the requested start only from THIS return's request.
-- Users: Operations …904 (intake role, org A …011) · nurse …902 and care assistant …906 (Testteam Nord …101) ·
-- here a synthetic nurse …908 in Testteam Mitte …102. Case …208 (Testteam Nord, running) is paused as the table owner.
-- All data synthetic; every other step goes through the real commands.
begin;
create extension if not exists pgtap with schema extensions;

select plan(33);

-- Pinned clock (DST1 pattern): 10:00 Zurich today.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0880000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.c208() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-000000000208'::uuid $$;
create function pg_temp.rec(p_title text, p_urgency text, p_source text, p_start date, p_key integer) returns text
language sql as $$
  select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital COND2', 'Spital', 'Bern West', null,
    p_urgency, null, p_title, 'Synthetischer Bedarf', array['Grundpflege'], pg_temp.k(p_key), p_source, p_start)
$$;
create function pg_temp.req(p_title text) returns uuid language sql stable as $$
  select id from public.partner_requests where request_title = p_title
$$;
create function pg_temp.link(p_title text, p_key integer) returns jsonb language sql as $$
  select public.link_returning_referral(pg_temp.req(p_title), pg_temp.c208(), 'Austritt nach Spitalaufenthalt',
    null, null, true, '{}'::jsonb, pg_temp.k(p_key))
$$;
-- The team's read of the case (the caller must be set before).
create function pg_temp.team_read() returns text language sql stable as $$
  select coalesce(t.urgency, '-') || ':' || coalesce(t.return_urgency_source, '-') || ':'
         || coalesce((t.return_referrer_requested_start - pg_temp.today())::text, '-')
  from public.team_cases() t where t.case_id = pg_temp.c208()
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- As the table owner: pause case …208 (as the pause command would leave it) ------------------------------------------
create function pg_temp.pause() returns void language sql as $$
  insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, actor_id, idempotency_key, created_at)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.c208(), 'pause', 'hospital_stay',
          '00000000-0000-4000-a000-000000000904', gen_random_uuid(), private.now() - interval '2 days');
  update public.cases set lifecycle = 'paused' where id = pg_temp.c208();
$$;
select pg_temp.pause();

-- A synthetic nurse of another team (Testteam Mitte) for the scope check.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values ('00000000-0000-0000-0000-000000000000', pg_temp.k(908), 'authenticated', 'authenticated',
        'mitte.cond2@navora.test', '', private.now(), '{}', '{}', private.now(), private.now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.k(908), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.k(908), 'registered_nurse');

create temp table before_link as
  select (select urgency || ':' || urgency_source || ':' || coalesce(referrer_requested_start::text, '-') from public.cases where id = pg_temp.c208()) as case_values,
         (select count(*) from public.cases) as cases,
         (select md5(coalesce(string_agg(m::text, '|' order by m.id), '')) from public.matching_requests m where m.case_id = pg_temp.c208()) as requests,
         (select md5(coalesce(string_agg(concat_ws(',', v.id, v.visit_date, v.time_start, v.time_end, v.status, v.responsible_user_id,
                                                   v.team_id, v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c), '|' order by v.id), ''))
            from public.care_visits v where v.case_id = pg_temp.c208()) as visits;

select is((select case_values from before_link), 'mittel:unknown:-', 'the paused case carries the first referral''s values');

-- 1. A returning referral with "hoch", stated by the referrer, with a date ------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.rec('COND2 R1', 'hoch', 'referrer_stated', pg_temp.today() + 4, 1), 'ok', 'Operations records the returning referral');
select is(pg_temp.link('COND2 R1', 11) ->> 'kind', 'resume', 'linking it to the paused case resumes the case');
select is(pg_temp.link('COND2 R1', 11) ->> 'result', 'duplicate', 'the same key is a replay');
reset role;
-- The next return happens later (in production each resume is its own transaction, a pause lies between them).
-- referral_links is append-only (forbid_audit_change), so the pinned clock moves on instead; created_at defaults to
-- private.now(). The argument names the return just made (for the reader).
create function pg_temp.age_link(p_title text) returns void language sql as $$
  select set_config('navora.test_now', (private.now() + interval '1 minute')::text, true);
$$;

select is((select urgency || ':' || urgency_source || ':' || (referrer_requested_start - pg_temp.today()) from public.cases where id = pg_temp.c208()),
  'hoch:referrer_stated:4', 'the case now carries the new level, its source and the referrer''s date');
select is((select count(*)::int from public.change_log where entity_id = pg_temp.c208()::text and idempotency_key = pg_temp.k(11)), 1,
  'one change_log row for the resume (the replay wrote none)');
select is((select changes -> 'urgency' ->> 'old' || '>' || (changes -> 'urgency' ->> 'new') || ','
                  || (changes -> 'urgency_source' ->> 'old') || '>' || (changes -> 'urgency_source' ->> 'new') || ','
                  || coalesce(changes -> 'referrer_requested_start' ->> 'old', 'null') || '>'
                  || ((changes -> 'referrer_requested_start' ->> 'new')::date - pg_temp.today())
           from public.change_log where entity_id = pg_temp.c208()::text and idempotency_key = pg_temp.k(11)),
  'mittel>hoch,unknown>referrer_stated,null>4', 'change_log holds old and new values of all three');
select ok((select actor_id = '00000000-0000-4000-a000-000000000904' and reason = 'Austritt nach Spitalaufenthalt' and command = 'update_case_intake'
           from public.change_log where entity_id = pg_temp.c208()::text and idempotency_key = pg_temp.k(11)),
  'with the linking person as actor, the link reason and the resume''s command name');
select ok(exists (select 1 from public.audit_events a
                  where a.table_name = 'cases' and a.entity_id = pg_temp.c208()
                    and a.changed -> 'urgency' ->> 'old' = 'mittel' and a.changed -> 'urgency' ->> 'new' = 'hoch'
                    and a.changed -> 'urgency_source' ->> 'new' = 'referrer_stated'
                    and a.actor_id = '00000000-0000-4000-a000-000000000904'),
  'the audit trail records the update with old and new values and the actor');
select ok((select b.cases = (select count(*) from public.cases) from before_link b), 'no new case');
select is((select md5(coalesce(string_agg(m::text, '|' order by m.id), '')) from public.matching_requests m where m.case_id = pg_temp.c208()),
  (select requests from before_link), 'the case''s matching request is unchanged (no deadline, level or order moves)');
select is((select md5(coalesce(string_agg(concat_ws(',', v.id, v.visit_date, v.time_start, v.time_end, v.status, v.responsible_user_id,
                                                    v.team_id, v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c), '|' order by v.id), ''))
           from public.care_visits v where v.case_id = pg_temp.c208()),
  (select visits from before_link), 'the visits are unchanged (date, time, status, responsible, minutes)');

-- The team reads it where it handles the return; nobody else does ---------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select 'review_after_pause' = any (open_tasks) from public.team_cases() where case_id = pg_temp.c208()),
  'the team has the review task of the return');
select is(pg_temp.team_read(), 'hoch:referrer_stated:4', 'the team reads level, source and the referrer''s date for the case');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team_read(), 'hoch:referrer_stated:4', 'so does the care assistant of the same team');
reset role;
select pg_temp.act_as(pg_temp.k(908)::text);
set local role authenticated;
select is((select count(*)::int from public.team_cases() where case_id = pg_temp.c208()), 0, 'a nurse of another team reads nothing of the case');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.team_cases() where case_id = pg_temp.c208()), 0, 'Operations (no team member) reads nothing through team_cases');
reset role;

-- Once the team has decided, the return fields are no longer shown ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.complete_case_task(pg_temp.c208(), 'review_after_pause', pg_temp.k(12)), 'ok', 'the team closes the review task');
select is(pg_temp.team_read(), 'hoch:-:-', 'then only the level stays (team_cases returns it as before)');
reset role;

-- 2. A second return without a date, assessed at intake: the date is never blanked ------------------------------------------
select pg_temp.age_link('COND2 R1');
select pg_temp.pause();
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.rec('COND2 R2', 'mittel', 'intake_assessed', null, 2), 'ok', 'a second returning referral without a date');
select is(pg_temp.link('COND2 R2', 21) ->> 'kind', 'resume', 'resumes the case again');
reset role;
select is((select urgency || ':' || urgency_source || ':' || (referrer_requested_start - pg_temp.today()) from public.cases where id = pg_temp.c208()),
  'mittel:intake_assessed:4', 'level and source follow the new referral; the referrer''s earlier date stays');
select ok((select not (changes ? 'referrer_requested_start') and changes -> 'urgency' ->> 'old' = 'hoch'
           from public.change_log where entity_id = pg_temp.c208()::text and idempotency_key = pg_temp.k(21)),
  'change_log records no date change, and the level change from hoch');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.team_read(), 'mittel:intake_assessed:-',
  'COND2-4a: the team reads the new level with its source and no referrer date (this request carried none)');
reset role;
select is((select (changes -> 'referrer_requested_start' ->> 'new')::date - pg_temp.today()
           from public.change_log where entity_id = pg_temp.c208()::text and idempotency_key = pg_temp.k(11)), 4,
  'COND2-4a: the first return''s date stays in the trail');

-- 3. A referral recorded before IPA1-7 (no source): shown as "unknown" ---------------------------------------------------------
select pg_temp.age_link('COND2 R2');
select pg_temp.pause();
-- As the table owner: a request as 0010 stored it (urgency_source takes the 0086 default 'unknown').
insert into public.partner_requests (organization_id, partner_name, partner_type, region, urgency, request_title, need_summary, requested_services, status)
values ('00000000-0000-4000-b000-000000000011', 'Spital COND2', 'Spital', 'Bern West', 'niedrig', 'COND2 R3', 'Synthetisch', array['Grundpflege'], 'open');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.link('COND2 R3', 31) ->> 'kind', 'resume', 'an older referral resumes the case');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.team_read(), 'niedrig:unknown:-',
  'its level is shown with "unknown" as the source; COND2-4a: no referrer date (the request has none)');
reset role;
select is((select referrer_requested_start - pg_temp.today() from public.cases where id = pg_temp.c208()), 4,
  'COND2-4a: the case''s stored date is unchanged (only the display follows this return)');
select is((select string_agg((changes -> 'urgency' ->> 'old') || '>' || (changes -> 'urgency' ->> 'new'), ',' order by id)
           from public.change_log where entity_id = pg_temp.c208()::text and changes ? 'urgency'),
  'mittel>hoch,hoch>mittel,mittel>niedrig', 'every earlier level stays in the trail, in order; nothing is rewritten');

-- 4. Unchanged paths and reads ----------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.rec('COND2 R4', 'hoch', 'referrer_stated', pg_temp.today() + 6, 4), 'ok', 'a new referral (no earlier case)');
select ok((public.convert_partner_request(pg_temp.req('COND2 R4'), 'Klient', 'COND2R4', true,
             jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE', 'insurer_name', 'Testkasse',
                                'insurance_type', 'KVG', 'requested_start', pg_temp.today() + 1), pg_temp.k(41)) ->> 'ready')::boolean,
  'converts into a ready case');
reset role;
select is((select c.urgency || ':' || c.urgency_source || ':' || (c.referrer_requested_start - pg_temp.today()) || '/'
                  || m.urgency_source || ':' || (m.referrer_requested_start - pg_temp.today())
           from public.cases c join public.matching_requests m on m.case_id = c.id where c.last_name = 'COND2R4'),
  'hoch:referrer_stated:6/referrer_stated:6', 'convert_partner_request still carries the values to the case and the matching request (0086)');
select ok(
  pg_get_function_result('public.team_offers()'::regprocedure) =
    'TABLE(matching_request_id uuid, team_id uuid, team_name text, request_title text, region text, urgency text, required_services text[], created_at timestamp with time zone, my_team_declined boolean, requested_start date, expected_hours_per_week numeric, required_qualification text, response_due_at timestamp with time zone, returning_client boolean, first_refusal_until timestamp with time zone, urgency_source text, referrer_requested_start date)'
  and pg_get_functiondef('public.team_offers()'::regprocedure)
    ~ 'order by case m\.urgency when ''hoch'' then 0 when ''mittel'' then 1 else 2 end, m\.response_due_at nulls last, m\.created_at;'
  and (select prosrc from pg_proc where oid = 'public.team_cases()'::regprocedure) ~ 'order by c\.last_name nulls last, c\.id;'
  and position('LEAVE1-3' in (select prosrc from pg_proc where oid = 'public.team_cases()'::regprocedure)) > 0,
  'team_offers output and ORDER BY (G3) unchanged; team_cases keeps its name order and the LEAVE1-3 guard');

select * from finish();
rollback;
