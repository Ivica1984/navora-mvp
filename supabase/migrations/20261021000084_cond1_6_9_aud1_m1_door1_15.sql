-- COND1 (brief docs/agents/briefs/COND1.md), ADR-097: COND1-6 = AUD1-M1 and COND1-9 = DOOR1-15. Builds on 0077 (AUD1)
-- and 0073/0080 (DOOR1). Display and read narrowing only; no clinical, tariff or legal rule. Idempotent: create or
-- replace and insert ... on conflict do nothing; a second run changes nothing.
--
-- COND1-6 = AUD1-M1 (AUD1.md, PO acceptance; lca 03:42 point 3). `public.read_audit_record` returns the value of a
--   `free_text` key only when the purpose is not `billing` and the administrator is an active member of the record's
--   team. With purpose `billing` every free-text value is withheld (key present, value null, named in `withheld_keys`,
--   `text_withheld` true), also inside the team: billing needs the fact that a hold was set or lifted, when and by
--   whom, never its reason. `compliance` and `safety_review` are unchanged. Everything else is copied unchanged from
--   0077 (purpose check, one record, administrators of the organisation, LEAVE1-3, AUD1-5 read record).
--   COND1-6's second part (AUD1-M2, the stale F-3 line) is docs only (docs/engineering/READ_PATHS.md).
--
-- COND1-9 = DOOR1-15 (DOOR1.md, PO decision 2026-10-26 14:30, CGR-66). The code guard stays as built
--   (`private.looks_like_code`, 0073; `cases.access_notes` trigger, 0080): a phone number and a postal code stay
--   refused. Only the help text changes, to "Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code".
--   The category list is append-only (0073: a change is a new version), so the text arrives as version 2 of
--   `access_arrangement`, active from 2026-10-26, same label, class, `refuses_codes`. Values keep their category id
--   (version 1 for those recorded before); every reader matches values by code (0073 `field_safety_alerts`, 0080
--   `field_safety_alert_history`), so nothing recorded is hidden or rewritten. The intake form shows the same text
--   from `src/features/door/rules.ts` ACCESS_HELP_TEXT.

-- 1. COND1-6 = AUD1-M1: billing reads codes only ------------------------------------------------------------------------
create or replace function public.read_audit_record(p_entity_type text, p_entity_id uuid, p_purpose text)
returns table (
  occurred_at   timestamptz,
  actor_id      uuid,
  actor_role    text,
  command       text,
  changed       jsonb,
  withheld_keys text[],
  text_withheld boolean
)
language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  team    uuid;
  in_team boolean;
  org     uuid;
  n       integer;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  perform private.assert_access_open();  -- LEAVE1-3: nothing for a person whose access ended
  if p_purpose is null or p_purpose not in ('compliance', 'billing', 'safety_review') then
    raise exception 'purpose must be compliance, billing or safety_review' using errcode = '22023';
  end if;
  if p_entity_type is null or p_entity_type !~ '^[a-z_]{1,63}$' or p_entity_id is null then
    raise exception 'one record (entity type and id) is required' using errcode = '22023';
  end if;

  team := private.audit_record_team(p_entity_type, p_entity_id);
  -- AUD1-M1 (COND1-6): purpose `billing` returns `code` values only, also to an administrator in the record's team.
  in_team := team is not null and private.is_team_member(team) and p_purpose <> 'billing';

  return query
  select a.occurred_at, a.actor_id, a.actor_role, a.command,
         coalesce((select jsonb_object_agg(e.key, case when s.shown then e.value else 'null'::jsonb end)
                   from jsonb_each(a.changed) e
                   left join private.audit_value_classes vc on vc.table_name = a.table_name and vc.key = e.key
                   cross join lateral (select coalesce(vc.class = 'code' or (vc.class = 'free_text' and in_team), false)
                                              as shown) s), '{}'::jsonb),
         coalesce((select array_agg(e.key order by e.key)
                   from jsonb_each(a.changed) e
                   left join private.audit_value_classes vc on vc.table_name = a.table_name and vc.key = e.key
                   where not coalesce(vc.class = 'code' or (vc.class = 'free_text' and in_team), false)), '{}'::text[]),
         exists (select 1
                 from jsonb_each(a.changed) e
                 left join private.audit_value_classes vc on vc.table_name = a.table_name and vc.key = e.key
                 where not coalesce(vc.class = 'code' or (vc.class = 'free_text' and in_team), false))
  from public.audit_events a
  where a.table_name = p_entity_type
    and a.entity_id = p_entity_id
    and private.has_org_role(a.organization_id, array['admin'])
  order by a.occurred_at, a.id;
  get diagnostics n = row_count;

  -- AUD1-5: one row per call, also when nothing was returned (organisation then unknown: null).
  select min(a.organization_id::text)::uuid into org
  from public.audit_events a
  where a.table_name = p_entity_type and a.entity_id = p_entity_id
    and private.has_org_role(a.organization_id, array['admin']);
  insert into public.audit_read_log (organization_id, reader_id, entity_type, entity_id, purpose, rows_returned)
  values (org, uid, p_entity_type, p_entity_id, p_purpose, n);
end;
$$;
revoke all on function public.read_audit_record(text, uuid, text) from public, anon;
grant execute on function public.read_audit_record(text, uuid, text) to authenticated;
comment on function public.read_audit_record(text, uuid, text) is
  'AUD1-3/-4: audit rows of one record for an administrator of its organisation, for compliance, billing or '
  'safety_review only; free text withheld unless the administrator is an active member of the record''s team, and '
  'always for billing (AUD1-M1, COND1-6, 0084). Every call is recorded in audit_read_log.';

-- 2. COND1-9 = DOOR1-15: the help text names the phone number ----------------------------------------------------------
insert into public.safety_alert_categories (code, version, label, class, active_from, source, help_text, refuses_codes)
values ('access_arrangement', 2, 'Schlüssel- und Zugangsregelung', 'organisational', date '2026-10-26',
        'D-17 Teil 2 (po 2026-10-24 23:10), Brief DOOR1-2; Hilfetext DOOR1-15 (po 2026-10-26 14:30, CGR-66)',
        'Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code', true)
on conflict (code, version) do nothing;
