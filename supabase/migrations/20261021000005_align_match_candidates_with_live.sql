-- TD-19 / ADR-022: adopt the two stricter rules the live schema has and the
-- reconstructed baseline lacked (docs/ops/live/SCHEMA_DRIFT_2026-10-21.md §2).
-- Defaults already exist (0 / 'suggested'); backfill first so the constraint
-- cannot fail on legacy rows.
update public.match_candidates set fit_score = 0 where fit_score is null;
update public.match_candidates set status = 'suggested' where status is null;

alter table public.match_candidates
  alter column fit_score set not null,
  alter column status    set not null;
