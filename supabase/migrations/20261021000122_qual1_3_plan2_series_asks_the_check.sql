-- QUAL1 part 2, slice 2 (brief docs/agents/briefs/QUAL1.md QUAL1-10; issue #931; ADR-165). Stacked on slice 1 (migration
-- 0121, PR #943). Matrix QAM v0.2, every cell PROPOSED. Passing anything here is NOT a clinical release (CGR-145, FE-039).
--
-- Defect it repairs (IMPLEMENTED in 0121, found 2026-11-07 04:30 on the #943 head `b457329`, reproduced on a local
-- PostgreSQL 16 build of 0001-0121 + seed): the PLAN2 series (`private.generate_case_plan`) still names the primary nurse,
-- else the deputy, by the J3 rule (registered nurse for KLV-B). In a simulation organisation the 0121 backstop then
-- refuses the generated row whenever the QUAL1 check does not confirm every activity of the visit (for example a FaGe
-- primary nurse and any category A minutes, which the CGR-149 fallback checks as A1). The error rolls back the whole
-- statement, so a care-plan change, the page-load refresh (`refresh_team_plans`) and the daily run
-- (`generate_all_plans`, all organisations in one loop) fail instead of planning. Nothing was written wrongly (the
-- backstop held); the series simply did not exist.
--
-- What it adds (IMPLEMENTED in this migration):
--   1. `private.qual_plan2_who(visit, team, who, alternative)`: outside a simulation organisation exactly `who` (the
--      member the J3 rule chose; QUAL1-1, every seed visit compared in pgTAP 122). In a simulation organisation the
--      first of `who`, `alternative` that the one decision function (`private.qual_may_perform_in`, 0121) confirms for
--      the visit as stored; else null.
--   2. The series asks it (patched in place, marker `QUAL1-10 PLAN2`):
--      - the alternative is the deputy, only when the J3 rule chose the primary nurse and the deputy meets the
--        existing deputy conditions unchanged (team member, access, recorded qualification, contract, registered nurse
--        for KLV-B, not absent). No new candidate, no rule relaxed;
--      - a new visit is written without a member in a simulation organisation, then given (1) when (1) names one; so the
--        backstop only ever sees a member the check confirmed. Otherwise the visit stays open in the team: the
--        existing PLAN2 "nobody" outcome (uncovered flag and alert as today);
--      - a regenerated visit likewise (minutes first, member after, because the check reads the stored minutes);
--      - the "has anything changed" comparison uses (1), so a refused primary nurse does not regenerate the visit on
--        every run (no churn in `visit_plan_changes`).
-- Unchanged: every organisation that is not a simulation (the patched expressions return the old value there); the 0121
-- backstop and the start check (no override, no bypass: a hand write of a refused member is still refused); visits the
-- team touched (never overwritten, PLAN2). The generation summary gains no new reason (PLANNED: a QUAL1 reason with the
-- UI slice). No clinical, tariff or legal rule is invented.
-- Idempotent: `create or replace`; the patch is skipped when its marker is present and raises when the text it expects
-- is not found exactly once (fail closed: the migration stops, nothing half-patched).

-- 1. The member the series names --------------------------------------------------------------------------------------------
create or replace function private.qual_plan2_who(p_visit uuid, p_team uuid, p_who uuid, p_alt uuid)
returns uuid language sql stable security definer set search_path = ''
as $$
  select case
    when not private.qual_is_simulation((select v.organization_id from public.care_visits v where v.id = p_visit)) then p_who
    when p_who is not null and private.qual_may_perform_in(p_visit, p_team, p_who) then p_who
    when p_alt is not null and p_alt is distinct from p_who and private.qual_may_perform_in(p_visit, p_team, p_alt) then p_alt
  end
$$;
revoke all on function private.qual_plan2_who(uuid, uuid, uuid, uuid) from public, anon, authenticated;
comment on function private.qual_plan2_who(uuid, uuid, uuid, uuid) is
  'QUAL1-10 / ADR-165: the member a PLAN2 generated visit names. Outside a simulation organisation exactly p_who (the J3 '
  'choice). In a simulation organisation the first of p_who, p_alt (the deputy under the old deputy rule) that '
  'private.qual_may_perform_in confirms for the visit as stored; else null (open in the team). No override.';

-- 2. The series asks it -----------------------------------------------------------------------------------------------------
create or replace function private.qual3_patch(p_fn text, p_pairs text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  src text;
  def text;
  i   int;
  n   int;
begin
  select p.prosrc, pg_get_functiondef(p.oid) into src, def from pg_proc p where p.oid = p_fn::regprocedure;
  if src like '%' || p_marker || '%' then
    return;                                        -- already patched (idempotent)
  end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(def) - length(replace(def, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then
      raise exception 'QUAL1 patch % of %: expected 1 occurrence, found %', i, p_fn, n;
    end if;
    def := replace(def, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute def;
end;
$$;
revoke all on function private.qual3_patch(text, text[], text) from public, anon, authenticated;

select private.qual3_patch('private.generate_case_plan(uuid, uuid)', array[
  -- (a) a variable for the alternative
  E'  who        uuid;\n',
  E'  who        uuid;\n  who_alt    uuid; /* QUAL1-10 PLAN2 */\n',
  -- (b) the alternative: the deputy under the unchanged deputy conditions, only when the J3 rule chose the primary nurse
  E'      if slot.b = 0 and c.medical_order_status is distinct from ''present'' then\n',
  E'      who_alt := case\n'
  || E'        when who is not distinct from c.primary_nurse_id and c.deputy_nurse_id is not null\n'
  || E'             and c.deputy_nurse_id is distinct from c.primary_nurse_id\n'
  || E'             and exists (select 1 from public.team_memberships m where m.team_id = c.assigned_team_id and m.user_id = c.deputy_nurse_id)\n'
  || E'             and not private.access_ended(c.deputy_nurse_id)\n'
  || E'             and private.has_qualification(c.assigned_team_id, c.deputy_nurse_id)\n'
  || E'             and private.adm2_in_contract(c.organization_id, c.deputy_nurse_id, d)\n'
  || E'             and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.deputy_nurse_id))\n'
  || E'             and not private.member_absent_during(c.assigned_team_id, c.deputy_nurse_id,\n'
  || E'                   private.at_zurich((d + slot.window_start)), private.at_zurich((d + slot.window_end))) then c.deputy_nurse_id\n'
  || E'        end; /* QUAL1-10 PLAN2: only used in a simulation organisation */\n'
  || E'      if slot.b = 0 and c.medical_order_status is distinct from ''present'' then\n',
  -- (c) compare with the member the check confirms (no churn)
  E'slot.cc, who, coalesce(slot.services, ''{}'')) then',
  E'slot.cc, private.qual_plan2_who(v.id, c.assigned_team_id, who, who_alt) /* QUAL1-10 PLAN2 */, coalesce(slot.services, ''{}'')) then',
  -- (d) regenerated visit: minutes first, the member after (the check reads the stored minutes)
  E'                responsible_user_id = who, services_provided = coalesce(slot.services, ''{}'')\n            where id = v.id;\n',
  E'                responsible_user_id = case when private.qual_is_simulation(c.organization_id) then null else who end,\n'
  || E'                services_provided = coalesce(slot.services, ''{}'')\n            where id = v.id;\n'
  || E'          if private.qual_is_simulation(c.organization_id)\n'
  || E'             and private.qual_plan2_who(v.id, c.assigned_team_id, who, who_alt) is not null then\n'
  || E'            update public.care_visits set responsible_user_id = private.qual_plan2_who(v.id, c.assigned_team_id, who, who_alt)\n'
  || E'              where id = v.id; /* QUAL1-10 PLAN2 */\n'
  || E'          end if;\n',
  -- (e) new visit: written without a member in a simulation organisation, the member after
  E'slot.a, slot.b, slot.cc, false, who, true, d, slot.window_start)\n        returning id into vid;\n',
  E'slot.a, slot.b, slot.cc, false, case when private.qual_is_simulation(c.organization_id) then null else who end,\n'
  || E'           true, d, slot.window_start)\n        returning id into vid;\n'
  || E'        if private.qual_is_simulation(c.organization_id)\n'
  || E'           and private.qual_plan2_who(vid, c.assigned_team_id, who, who_alt) is not null then\n'
  || E'          update public.care_visits set responsible_user_id = private.qual_plan2_who(vid, c.assigned_team_id, who, who_alt)\n'
  || E'            where id = vid; /* QUAL1-10 PLAN2 */\n'
  || E'        end if;\n'
], 'QUAL1-10 PLAN2');

drop function private.qual3_patch(text, text[], text);
