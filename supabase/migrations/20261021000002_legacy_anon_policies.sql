-- =============================================================================
-- LEGACY — INSECURE BY DESIGN — LOCAL/CI ONLY — REMOVED IN T9
-- =============================================================================
-- Reproduces the documented live state ({public} policies with `true`) so the
-- recovered code, which queries as the anon role (SR-02), runs locally against
-- synthetic data. This file must never be applied to an environment that holds
-- real data. T9 drops every policy below in the same migration that adds the
-- organisation/team-scoped replacements, and pgTAP then proves anon gets nothing.
-- =============================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'teams', 'cases', 'partner_requests', 'matching_requests',
    'match_candidates', 'care_visits', 'care_notes', 'quality_events'
  ]
  loop
    execute format(
      'create policy legacy_public_all on public.%I for all to public using (true) with check (true)',
      t
    );
  end loop;
end
$$;
