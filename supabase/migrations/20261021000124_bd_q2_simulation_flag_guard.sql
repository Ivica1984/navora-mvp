-- BD / Q-BD-2 (brief docs/agents/briefs/BD.md amendment 2026-11-11 05:39; `cra` CGR-177 (b); ADR-180). Database guard only:
-- no product behaviour, no care rule, no data, no new column, no grant.
--
-- `organizations.simulation` (0120:51-53, QUAL1-1) switches the PROPOSED qualification matrix on for an organisation. 0120
-- says it is "set only by a migration or a test fixture": `authenticated` has no INSERT or UPDATE on organizations (0003),
-- but nothing stopped a SECURITY DEFINER command (it runs as the table owner) or `service_role` (Supabase default table
-- privileges, used by the push dispatcher) from setting it. CGR-177 (b) asks that no role or command can set it once the
-- seed holds a simulation organisation.
--
-- What it adds (IMPLEMENTED in this migration):
--   `private.organizations_simulation_guard()`, a BEFORE INSERT OR UPDATE OF simulation trigger on public.organizations:
--   a row inserted with simulation = true, or an update that changes the flag, is refused (42501) when there is a request
--   user (auth.uid()), a running command (navora.command, private.begin_command) or the current role is an API role
--   (authenticated, anon, service_role). A migration, the seed and a pgTAP fixture run as the table owner without either
--   and keep working (pgTAP 120-122 create their own simulation organisation that way). Same test as the 0120 guard for
--   `verified` evidence (private.qual_guard_evidence).
-- SECURITY INVOKER with search_path = '' (pgTAP 123 rules); EXECUTE revoked from PUBLIC, anon, authenticated.
-- Idempotent: `create or replace`, `drop trigger if exists`.

create or replace function private.organizations_simulation_guard()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if (tg_op = 'INSERT' and coalesce(new.simulation, false))
     or (tg_op = 'UPDATE' and new.simulation is distinct from old.simulation) then
    -- Checked one after the other (no reliance on OR evaluation order): the API role first, so a role without access to
    -- auth.uid() is still refused with this message.
    if current_user in ('authenticated', 'anon', 'service_role')
       or nullif(current_setting('navora.command', true), '') is not null then
      raise exception 'organizations.simulation is set only by a migration or the synthetic seed (QUAL1-1, CGR-177)'
        using errcode = '42501';
    end if;
    if (select auth.uid()) is not null then
      raise exception 'organizations.simulation is set only by a migration or the synthetic seed (QUAL1-1, CGR-177)'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.organizations_simulation_guard() from public, anon, authenticated;
comment on function private.organizations_simulation_guard() is
  'BD Q-BD-2 / CGR-177 (b) / ADR-180: no request user, command or API role may set or change organizations.simulation.';

drop trigger if exists organizations_simulation_guard on public.organizations;
create trigger organizations_simulation_guard
  before insert or update of simulation on public.organizations
  for each row execute function private.organizations_simulation_guard();
