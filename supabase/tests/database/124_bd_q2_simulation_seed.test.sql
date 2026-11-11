-- BD / Q-BD-2 (brief docs/agents/briefs/BD.md amendment 2026-11-11 05:39; `cra` CGR-177 (a)-(c); migration 0124; ADR-180):
-- the one synthetic simulation organisation of the seed (Testorganisation S, Basel-Stadt) and the guard on its flag.
-- Simulation · synthetische Daten · Regeln PROPOSED: the seed people are synthetic; the matrix cells (QAM-0.2) stay
-- UNVALIDATED (D-43). This file proves the QUAL1 MECHANISM reaches the seed accounts, not the cells.
-- Seed: org S …019, Testteam Basel …1b9, opsbs …9e5 (operations), pflegebs …9e6 (registered nurse, nurse_hf_fh + practice
-- licence verified), assistbs …9e7 (care assistant, pflegehelfer_srk verified). Testorganisation A …011, assist.test …906.
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

create function pg_temp.org_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.org_a() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.team_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001b9'::uuid $$;
create function pg_temp.nurse() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e6'::uuid $$;
create function pg_temp.assist() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e7'::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1240000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.c(n int) returns uuid language sql immutable as $$
  select ('a1240000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
-- The refusal of a statement as "<sqlstate> <message>" (null when it runs), run as p_role (null: the table owner).
create function pg_temp.refusal(p_role text, p_sql text) returns text language plpgsql as $$
declare st text; msg text;
begin
  begin
    if p_role is not null then execute format('set local role %I', p_role); end if;
    execute p_sql;
    execute 'reset role';
    return null;
  exception when others then
    get stacked diagnostics st = returned_sqlstate, msg = message_text;
    execute 'reset role';
    return st || ' ' || msg;
  end;
end $$;

-- 1. CGR-177 (b): one simulation organisation, the synthetic Basel one ---------------------------------------------------------
select is((select count(*)::int from public.organizations where simulation), 1,
  'CGR-177 (b): exactly one simulation organisation after the seed');
select is((select id from public.organizations where simulation), pg_temp.org_s(),
  'CGR-177 (b): the simulation organisation is Testorganisation S');
select ok((select name ~* 'synthetisch' and name ~ 'Simulation' from public.organizations where id = pg_temp.org_s()),
  'CGR-177 (a): the simulation organisation is labelled synthetic in its name');
select is((select region from public.teams where id = pg_temp.team_s() and organization_id = pg_temp.org_s()), 'Basel-Stadt',
  'Q-BD-3: Testteam Basel lies in the synthetic region Basel-Stadt');

-- 2. CGR-177 (a): its evidence is the fixture path only -----------------------------------------------------------------------
select is((select count(*)::int from public.member_qualification_evidence
           where organization_id = pg_temp.org_s() and (not synthetic or recorded_by is not null or state <> 'verified')), 0,
  'CGR-177 (a): every evidence row of the simulation organisation is a synthetic fixture (verified, no recorded_by)');
select is((select count(*)::int from public.member_qualification_evidence e
           join public.organizations o on o.id = e.organization_id where not o.simulation), 0,
  'CGR-177 (a): the seed holds no evidence outside the simulation organisation');

-- 3. CGR-177 (b): nobody but a migration or the seed sets the flag -------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.organizations', 'UPDATE')
          and not has_table_privilege('authenticated', 'public.organizations', 'INSERT')
          and not has_column_privilege('authenticated', 'public.organizations', 'simulation', 'UPDATE')
          and not has_table_privilege('anon', 'public.organizations', 'UPDATE'),
  'CGR-177 (b): authenticated may not update organizations (no INSERT, no UPDATE, no column grant; anon neither)');
select pg_temp.act_as(pg_temp.nurse());
select matches(pg_temp.refusal('authenticated',
                 format('update public.organizations set simulation = false where id = %L', pg_temp.org_s())),
  '^42501 ', 'CGR-177 (b): authenticated may not update organizations (refused as the seed nurse)');
select pg_temp.as_owner();
select matches(pg_temp.refusal('service_role',
            format('update public.organizations set simulation = true where id = %L', pg_temp.org_a())),
  '^42501 ',
  'CGR-177 (b): service_role may not set organizations.simulation (Testorganisation A stays a non-simulation)');
select matches(pg_temp.refusal('service_role',
            $$ insert into public.organizations (id, name, simulation) values ('a1240000-0000-4000-b000-000000000002', 'x', true) $$),
  '^42501 ',
  'CGR-177 (b): service_role may not set organizations.simulation on a new organisation either');
select set_config('navora.command', 'bd_q2_probe', true);
select is(pg_temp.refusal(null, format('update public.organizations set simulation = false where id = %L', pg_temp.org_s())),
  '42501 organizations.simulation is set only by a migration or the synthetic seed (QUAL1-1, CGR-177)',
  'CGR-177 (b): no command may set organizations.simulation (a SECURITY DEFINER command runs as the owner)');
select set_config('navora.command', '', true);
select is(pg_temp.refusal(null, $$ update public.organizations set name = name where simulation $$), null,
  'ADR-180: an update that leaves the flag alone is not refused');

-- 4. CGR-177 (c): Testorganisation A keeps CR-007/CR-164 ----------------------------------------------------------------------
select ok((select not simulation from public.organizations where id = pg_temp.org_a()),
  'CGR-177 (c): Testorganisation A is not a simulation');

-- 5. The QUAL1 mechanism reaches the seed accounts (fixture visits as the table owner) -----------------------------------------
-- K1: a synthetic case of Testteam Basel. V1 KLV-B minutes (B13), V2 needs assessment (A1), V3 no minutes (C1).
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id)
values (pg_temp.org_s(), pg_temp.c(1), 'Synth Klientin S1', 'Synth', 'S1', 'Basel-Stadt', 'laufend', 'mittel', pg_temp.team_s());
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b, is_needs_assessment)
select pg_temp.v(n), pg_temp.org_s(), pg_temp.c(1), pg_temp.team_s(), (private.now() at time zone 'Europe/Zurich')::date + 2,
       t0::time, t0::time + interval '20 minutes', 'planned', 0, b, na
from (values (1, '09:00', 20, false), (2, '11:00', 0, true), (3, '13:00', 0, false)) x (n, t0, b, na);

select is(pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                       pg_temp.assist(), pg_temp.v(1))),
  '42501 qualification_not_allowed',
  'CGR-177: a care assistant is refused on a KLV-B visit (qualification_not_allowed, QUAL1-10 backstop)');
select is(pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                       pg_temp.nurse(), pg_temp.v(1))),
  null, 'CGR-177: a registered nurse is not refused on a KLV-B visit');
select is(pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                       pg_temp.assist(), pg_temp.v(2))),
  '42501 qualification_not_allowed',
  'CGR-177: a care assistant is refused on a needs assessment (A1)');
select ok(private.qual_may_perform(pg_temp.v(2), pg_temp.nurse()) and private.qual_may_perform(pg_temp.v(3), pg_temp.assist()),
  'QUAL1 mechanism: the registered nurse may do the needs assessment, the care assistant the visit without KLV-B minutes (C1)');
select is((select count(*)::int from private.qual_check(pg_temp.v(1), pg_temp.assist()) c
           where c.result = 'not_allowed' and c.matrix_version = 'QAM-0.2'), 1,
  'QUAL1 mechanism: the refusal comes from the matrix (one not_allowed row, version QAM-0.2), not from CR-007');

select * from finish();
rollback;
