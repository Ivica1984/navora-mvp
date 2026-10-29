-- AUD1: administrators read the audit log only for a stated purpose, without the team's free text.
-- Brief docs/agents/briefs/AUD1.md, migration 0077, ADR-090. Synthetic data only (seed users and teams; one quality
-- hold set by the seed nurse inside this rolled-back test).
-- Users: admin …905 (org A, member of no team) · coach …901 · nurse …902 (Testteam Nord …101) · operations …904 ·
-- admin …903 (org B).
begin;
create extension if not exists pgtap with schema extensions;

select plan(44);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select '00000000-0000-4000-a000-000000000' || n
$$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Privileges and catalogue
-- ---------------------------------------------------------------------------------------------------------------------
select function_privs_are('public', 'read_audit_record', array['text', 'uuid', 'text'], 'anon', array[]::text[],
  'AUD1-3: anon cannot execute the purpose reader');
select function_privs_are('public', 'read_audit_record', array['text', 'uuid', 'text'], 'authenticated', array['EXECUTE'],
  'AUD1-3: authenticated can execute the purpose reader (the function decides)');
select function_privs_are('public', 'org_audit_read_log', array['uuid'], 'anon', array[]::text[],
  'AUD1-5: anon cannot read the purpose-read record');
select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'audit_events'
           and permissive = 'PERMISSIVE'), 0,
  'AUD1-2: no permissive policy on audit_events (the placeholder org_admins_read_audit is gone; no standing table read)');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_events'::regclass), 'AUD1-2: RLS stays on for audit_events');
select ok(not has_table_privilege('anon', 'public.audit_events', 'select'), 'AUD1-2: anon has no read grant on audit_events');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_read_log'::regclass), 'AUD1-5: RLS is on for audit_read_log');
select is((select count(*)::int from unnest(array['anon', 'authenticated']) r(role)
           cross join unnest(array['select', 'insert', 'update', 'delete', 'truncate']) p(priv)
           where has_table_privilege(r.role, 'public.audit_read_log', p.priv)), 0,
  'AUD1-5: anon and authenticated hold no table privilege on audit_read_log');
select ok(not has_table_privilege('authenticated', 'private.audit_value_classes', 'select'),
  'AUD1-1: the value catalogue is not readable by app roles');

-- AUD1-1: every column the audit trigger records is classified; a new audited column fails here until it is listed.
select is(
  (select string_agg(distinct c.relname || '.' || a.col, ', ')
   from pg_trigger t
   join pg_proc p on p.oid = t.tgfoid and p.proname = 'write_audit_event'
   join pg_class c on c.oid = t.tgrelid
   cross join lateral unnest(string_to_array(rtrim(encode(t.tgargs, 'escape'), '\000'), '\000')) a(col)
   where not t.tgisinternal
     and not exists (select 1 from private.audit_value_classes v where v.table_name = c.relname and v.key = a.col)),
  null, 'AUD1-1: every audited column is in the value catalogue (code or free_text)');
-- AUD1-1: the free-text list is fixed (READ_PATHS.md, AUD1 inventory).
select is(
  (select string_agg(table_name || '.' || key, ', ' order by table_name collate "C", key collate "C")
   from private.audit_value_classes where class = 'free_text'),
  'cases.region, matching_requests.region, member_invitations.email, member_profiles.display_name, '
  'partner_requests.region, quality_holds.lift_reason, quality_holds.reason, teams.coach_name, teams.name, teams.region',
  'AUD1-1: the audited free-text keys are exactly the listed ten');
-- AUD1-1: every text-typed audited column classified as code has a closed value set or is written by commands only
-- (no app column grant); a typed column cannot slip in as code.
select is(
  (select string_agg(distinct c.relname || '.' || a.col, ', ')
   from pg_trigger t
   join pg_proc p on p.oid = t.tgfoid and p.proname = 'write_audit_event'
   join pg_class c on c.oid = t.tgrelid
   cross join lateral unnest(string_to_array(rtrim(encode(t.tgargs, 'escape'), '\000'), '\000')) a(col)
   join information_schema.columns ic on ic.table_schema = 'public' and ic.table_name = c.relname and ic.column_name = a.col
   join private.audit_value_classes v on v.table_name = c.relname and v.key = a.col and v.class = 'code'
   where not t.tgisinternal and ic.data_type in ('text', 'character varying')
     and not exists (select 1 from pg_constraint k join pg_attribute at on at.attrelid = k.conrelid and at.attnum = any (k.conkey)
                     where k.conrelid = c.oid and at.attname = a.col and k.contype in ('c', 'f'))
     and (has_column_privilege('authenticated', c.oid, a.col, 'update') or has_column_privilege('authenticated', c.oid, a.col, 'insert'))
     and not (c.relname = 'care_visits' and a.col = 'status')),   -- status changes only by the 0004 state machine
  null, 'AUD1-1: no text column the app can write freely is classified as code');
-- AUD1-1: every function that reads audit_events is known (definer, its task named in READ_PATHS.md).
select is(
  (select string_agg(x, ', ' order by x collate "C")
   from (select n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || '):' || p.prosecdef as x
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'private') and p.prosrc ~ 'public\.audit_events'
     and p.proname not in ('write_audit_event', 'write_audit_delete', 'audit_visit_plan_move', 'audit_command',
                           'set_member_qualification', 'plan_from_care_plan', 'set_auto_planning',
                           'adm1_reset_out_of_range_overrides', 'write_visit_refusal',
                           'adm2_end_push_subscriptions', 'aig1_audit_system')) f),
  'private.aig1_superseded_at(p_entity_type text, p_entity_id uuid, p_field text, p_value jsonb):true, '
  'private.begin_command(p_command text, p_key uuid):true, '
  'private.case_order_as_of(p_case_id uuid, p_at timestamp with time zone):true, '
  'private.handover_entries(p_visit uuid, p_user uuid):true, private.last_primary_nurse(p_case uuid):true, '
  'public.pilot_hypotheses(p_month date):true, '
  'public.read_audit_record(p_entity_type text, p_entity_id uuid, p_purpose text):true',
  'AUD1-1: the readers of audit_events are exactly the listed SECURITY DEFINER functions');
-- AUD1-3: one record, never a list; the reader returns no count, rank or per-member column.
select is((select array_to_string(proargnames, ',') || '|' || array_to_string(proargtypes::regtype[], ',')
           from pg_proc where oid = 'public.read_audit_record(text,uuid,text)'::regprocedure),
  'p_entity_type,p_entity_id,p_purpose,occurred_at,actor_id,actor_role,command,changed,withheld_keys,text_withheld|text,uuid,text',
  'AUD1-3: arguments are one entity type, one id and a purpose; output has no aggregate column');
-- AUD1-5: the reader of the read record has no per-person argument or aggregate.
select is((select array_to_string(proargnames, ',') from pg_proc where oid = 'public.org_audit_read_log(uuid)'::regprocedure),
  'p_organization_id,read_at,reader_id,entity_type,entity_id,purpose,rows_returned',
  'AUD1-5: one organisation argument; rows only (no count, rank or grouping per administrator)');
select ok((select prosrc !~* '(count\(|rank\(|group\s+by|sum\(|row_number)' from pg_proc
           where oid = 'public.org_audit_read_log(uuid)'::regprocedure),
  'AUD1-5: the read-record reader neither groups nor counts');

-- ---------------------------------------------------------------------------------------------------------------------
-- Fixture: a quality hold on a Testteam Nord visit, set by the nurse (free-text reason, audited)
-- ---------------------------------------------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.u('902'));
set local role authenticated;
select is(public.set_quality_hold('00000000-0000-4000-a000-000000000502', 'Synthetischer Haltegrund AUD1',
                                  'a0770000-0000-4000-8000-000000000001'), 'ok', 'fixture: the nurse sets a hold with a reason');
reset role;
create temp table fx as
  select h.id as hold_id from public.quality_holds h
  where h.visit_id = '00000000-0000-4000-a000-000000000502' and h.lifted_at is null;
grant select on fx to authenticated;
select is((select count(*)::int from public.audit_events a join fx on a.entity_id = fx.hold_id
           where a.changed -> 'reason' ->> 'new' = 'Synthetischer Haltegrund AUD1'), 1,
  'fixture: the reason text is in audit_events.changed (read as the table owner)');

-- ---------------------------------------------------------------------------------------------------------------------
-- AUD1-2: no standing table read, for any role
-- ---------------------------------------------------------------------------------------------------------------------
create function pg_temp.table_rows(uid text) returns int language plpgsql as $$
declare n int;
begin
  perform pg_temp.act_as(uid);
  set local role authenticated;
  select count(*)::int into n from public.audit_events;
  reset role;
  return n;
end $$;
select is(pg_temp.table_rows(pg_temp.u('905')), 0, 'AUD1-2: the org-A administrator reads 0 audit rows through the table');
select is(pg_temp.table_rows(pg_temp.u('903')), 0, 'AUD1-2: the org-B administrator reads 0 audit rows through the table');
select is(pg_temp.table_rows(pg_temp.u('901')) + pg_temp.table_rows(pg_temp.u('902')) + pg_temp.table_rows(pg_temp.u('904')), 0,
  'AUD1-2: coach, nurse and operations read 0 audit rows through the table');
set local role anon;
select throws_ok($$ select count(*) from public.audit_events $$, '42501', null, 'AUD1-2: anon is refused');
reset role;

-- ---------------------------------------------------------------------------------------------------------------------
-- AUD1-3: purpose reader, one record, administrators of the record's organisation only
-- ---------------------------------------------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.u('905'));
set local role authenticated;
select throws_ok($$ select * from public.read_audit_record('quality_holds', (select hold_id from fx), 'curiosity') $$,
  '22023', null, 'AUD1-3: an unknown purpose code is refused');
select throws_ok($$ select * from public.read_audit_record('quality_holds', (select hold_id from fx), null) $$,
  '22023', null, 'AUD1-3: no purpose is refused');
select throws_ok($$ select * from public.read_audit_record('quality_holds', null, 'compliance') $$,
  '22023', null, 'AUD1-3: no record is refused');
select throws_ok($$ select * from public.read_audit_record('quality_holds; drop', (select hold_id from fx), 'compliance') $$,
  '22023', null, 'AUD1-3: an entity type that is not a table name is refused');

-- AUD1-4: the administrator outside the team: reason withheld, the change, its time and command visible.
select is((select count(*)::int from public.read_audit_record('quality_holds', (select hold_id from fx), 'safety_review')), 1,
  'AUD1-3: the org-A administrator reads the hold''s one audit row for safety_review');
select is((select r.changed -> 'reason' from public.read_audit_record('quality_holds', (select hold_id from fx), 'compliance') r),
  'null'::jsonb, 'AUD1-4: outside the team the reason value is withheld (key present, value null)');
select is((select r.changed ? 'reason' and r.text_withheld and 'reason' = any (r.withheld_keys)
                  and r.occurred_at is not null and r.command = 'set_quality_hold'
                  and r.actor_id = pg_temp.u('902')::uuid
           from public.read_audit_record('quality_holds', (select hold_id from fx), 'compliance') r), true,
  'AUD1-4: the key, text_withheld, the change time, the command and the actor stay visible');
select is((select r.changed::text ~ 'Synthetischer Haltegrund'
           from public.read_audit_record('quality_holds', (select hold_id from fx), 'billing') r), false,
  'AUD1-4: the text appears nowhere in the returned row');
-- Codes are shown: a team record's priority flag.
reset role;
update public.teams set priority = not priority, coach_name = 'Coach AUD1' where id = '00000000-0000-4000-a000-000000000104';
select pg_temp.act_as(pg_temp.u('905'));
set local role authenticated;
select is((select r.changed -> 'priority' is not null and r.changed -> 'priority' <> 'null'::jsonb
                  and r.changed -> 'coach_name' = 'null'::jsonb and r.withheld_keys = array['coach_name']
           from public.read_audit_record('teams', '00000000-0000-4000-a000-000000000104', 'compliance') r
           where r.changed ? 'coach_name'), true,
  'AUD1-4: a code (priority) is shown, a typed name (coach_name) is withheld outside the team');
reset role;

-- Other organisation, non-administrators: 0 rows.
select pg_temp.act_as(pg_temp.u('903'));
set local role authenticated;
select is((select count(*)::int from public.read_audit_record('quality_holds', (select hold_id from fx), 'compliance')), 0,
  'AUD1-3: the org-B administrator reads 0 rows of an org-A record');
reset role;
select pg_temp.act_as(pg_temp.u('901'));
set local role authenticated;
select is((select count(*)::int from public.read_audit_record('quality_holds', (select hold_id from fx), 'compliance')), 0,
  'AUD1-3: the coach (no administrator) reads 0 rows');
reset role;
select pg_temp.act_as(pg_temp.u('902'));
set local role authenticated;
select is((select count(*)::int from public.read_audit_record('quality_holds', (select hold_id from fx), 'safety_review')), 0,
  'AUD1-3: the nurse who wrote the reason reads 0 rows here (the team reads the hold itself)');
reset role;

-- AUD1-4: an administrator who is an active member of the team reads the text.
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u('905')::uuid, 'registered_nurse');
select pg_temp.act_as(pg_temp.u('905'));
set local role authenticated;
select is((select (r.changed -> 'reason' ->> 'new') || '|' || r.text_withheld::text
           from public.read_audit_record('quality_holds', (select hold_id from fx), 'safety_review') r),
  'Synthetischer Haltegrund AUD1|false', 'AUD1-4: an administrator who is a member of the team reads the text');
reset role;

-- An unclassified key is withheld for everyone (fail closed), also inside the team.
insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, changed)
values ('00000000-0000-4000-b000-000000000011', null, 'postgres', 'quality_holds', (select hold_id from fx), 'aud1_test',
        '{"unlisted_key": {"old": null, "new": "x"}}');
select pg_temp.act_as(pg_temp.u('905'));
set local role authenticated;
select is((select r.changed -> 'unlisted_key' = 'null'::jsonb and r.text_withheld
           from public.read_audit_record('quality_holds', (select hold_id from fx), 'compliance') r
           where r.command = 'aud1_test'), true,
  'AUD1-4: a key missing from the value catalogue is withheld even inside the team (fail closed)');
reset role;

-- ---------------------------------------------------------------------------------------------------------------------
-- AUD1-5: every call is recorded, append-only; administrators read their organisation's rows
-- ---------------------------------------------------------------------------------------------------------------------
select is((select count(*)::int from public.audit_read_log l join fx on l.entity_id = fx.hold_id), 9,
  'AUD1-5: each completed call on the hold added one row (6 by the org-A administrator, 1 each by org B, coach, nurse); refused calls add none');
select is((select string_agg(distinct l.purpose, ',' order by l.purpose) from public.audit_read_log l join fx on l.entity_id = fx.hold_id),
  'billing,compliance,safety_review', 'AUD1-5: the purpose code is recorded');
select is((select l.rows_returned || '|' || (l.organization_id is null)::text from public.audit_read_log l join fx on l.entity_id = fx.hold_id
           where l.reader_id = pg_temp.u('903')::uuid),
  '0|true', 'AUD1-5: a call that returned nothing is recorded with 0 rows and no organisation');
select throws_ok($$ update public.audit_read_log set purpose = 'billing' $$, '42501', null,
  'AUD1-5: the read record is append-only (update refused, even for the owner)');
select throws_ok($$ delete from public.audit_read_log $$, '42501', null,
  'AUD1-5: the read record is append-only (delete refused, even for the owner)');

select pg_temp.act_as(pg_temp.u('905'));
set local role authenticated;
select is((select count(*)::int from public.org_audit_read_log('00000000-0000-4000-b000-000000000011') r
           join fx on r.entity_id = fx.hold_id), 6,
  'AUD1-5: the org-A administrator reads her organisation''s purpose-read rows');
select is((select count(*)::int from public.org_audit_read_log('00000000-0000-4000-b000-000000000012')), 0,
  'AUD1-5: and none of another organisation');
reset role;
select pg_temp.act_as(pg_temp.u('901'));
set local role authenticated;
select is((select count(*)::int from public.org_audit_read_log('00000000-0000-4000-b000-000000000011')), 0,
  'AUD1-5: a coach reads no purpose-read row');
reset role;

select * from finish();
rollback;
