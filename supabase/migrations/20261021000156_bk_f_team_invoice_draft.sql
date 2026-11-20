-- BK-f, contract 2026-11-20 06:39 points 2 (b)–(g), (i), (j) (docs/agents/briefs/BK.md; BK-9, BK-9n, BK-10, CGR-210
-- (a), (b), AUT-119 (b), G-6, FE-078, R-12, D-44): the invoice draft from the team to the client, built from the signed
-- report. Phase A: simulation, synthetic data only. Every function here is a fixed, checkable rule; no AI model.
--
-- Nothing here sets a tariff, a surcharge, a rounding rule, a VAT rule, a time tolerance or a legal rule:
--   * the price is the team's own (0155 snapshot at «Übernehmen»); no price → refused `no_price`;
--   * the time tolerance is a configuration row written only by a reviewed migration with an `lca` reference
--     (pattern AUT-152, 0153). THIS MIGRATION SHIPS NO ROW: every draft is refused `no_tolerance` until `lca` names the
--     simulation test value at the gate (contract point 2 (d));
--   * amount = recorded minutes × price per hour / 60, kept to 2 decimals (`round(…, 2)`; multiply first, BKF-F2);
--     rounding to 5 Rappen or to time units, surcharges and VAT are OPEN (`lca`) and not built.
--
-- Before (IMPLEMENTED, 0001-0155): a signed take report has no invoice path; the J5 path skips take visits (0154).
-- Now (IMPLEMENTED in this migration):
--   1. `public.invoice_time_tolerances` (no row) and `public.team_invoice_drafts` (one row per build attempt: a draft
--      or a visible refusal with its reason; at most one live draft or sent invoice per take). RLS on, no grant for app
--      roles, read only through SECURITY DEFINER functions; audited; no delete; only the transitions draft → sent,
--      draft → void, sent → void. No column for commission, percent, NAVORA fee, IBAN, payment or paid (FE-078).
--   2. When a take report becomes `final` (sign_report, countersign_report), an AFTER trigger on `visit_reports`
--      voids the take's live draft if this version supersedes an earlier one (CGR-210 (b)) and builds the new draft,
--      each step inside its own exception block: the signature is never blocked, delayed or rolled back by billing;
--      a failed build is stored as the refusal `build_failed` and shown (contract point 2 (b)).
--   3. `build_team_invoice_draft(report, key)`: the take team builds again after a refusal (hold lifted, tolerance set).
--   4. `send_team_invoice_draft(draft, key)`: «Bestätigen und senden» by an active member of the take team; the
--      confirming person is recorded. «Gesendet» means the client can read it in the portal; no PDF, no QR-bill, no
--      IBAN, no payment state (R-12).
--   5. Readers: `my_team_invoice_drafts()` (/team), `my_take_invoice_state(visit)` (/field line after signing),
--      `client_invoices()` (/order «Rechnungen»: only sent or voided-after-sending invoices of the caller's own client
--      account; date, hours, price, amount, team name, state; no member name, no tag — CGR-210 (c), UXR-191 (3)).
--   6. G-6: `tariff_rates` and `billing_rules` are read by organisation members only (0022 had `using (true)`), so a
--      client-only user reads no tariff, billing, stop-rule or tolerance configuration row.
-- Not here (contract point 3): price ceiling, `price_above_ceiling`, surcharges, rounding, VAT, PDF, dispute,
-- QR-bill, payment, NAVORA subscription ledger, `/platform` counts, KVG/KLV billing, four-eye confirmation.
-- Idempotent: `if not exists`, `create or replace`, `drop … if exists`, `on conflict do nothing`.
-- Way back: drop the trigger on visit_reports, the functions and the two tables (nothing else reads them), and restore
-- the two `members_read` policies of 0022.

-- 1. Time tolerance configuration (AUT-152 pattern; no row shipped) ---------------------------------------------------
create table if not exists public.invoice_time_tolerances (
  key               text primary key check (key = 'take_invoice'),
  tolerance_minutes integer not null check (tolerance_minutes between 0 and 240),
  lca_ref           text not null check (char_length(btrim(lca_ref)) between 3 and 120),
  created_at        timestamptz not null default private.now()
);
alter table public.invoice_time_tolerances enable row level security;
revoke all on public.invoice_time_tolerances from public, anon, authenticated;
comment on table public.invoice_time_tolerances is
  'BK-f / BK-9n: allowed difference in minutes between the ordered and the recorded duration of a taken shift before '
  'the invoice draft is refused (times_disagree). Written only by a reviewed migration with the lca reference. No row: '
  'every draft is refused (no_tolerance). A simulation test parameter, not a legal or tariff value.';

-- 2. Invoice drafts ---------------------------------------------------------------------------------------------------
create table if not exists public.team_invoice_drafts (
  id                   uuid primary key default gen_random_uuid(),
  seq                  bigint generated always as identity unique,  -- build order (several attempts may share a clock)
  organization_id      uuid not null references public.organizations (id),
  team_id              uuid not null references public.teams (id),
  client_account_id    uuid references public.client_accounts (id),
  order_id             uuid not null references public.partner_requests (id),
  take_id              uuid not null references public.order_takes (id),
  visit_id             uuid not null references public.care_visits (id),
  report_id            uuid not null references public.visit_reports (id),
  report_version       integer not null,
  report_snapshot_hash text not null,
  state                text not null check (state in ('draft', 'sent', 'void', 'refused')),
  refusal_reason       text check (refusal_reason in ('not_signed', 'superseded', 'already_drafted', 'on_hold',
                                                      'no_tolerance', 'no_price', 'no_times', 'times_disagree',
                                                      'build_failed')),
  ordered_minutes      numeric(8, 2),
  recorded_minutes     numeric(8, 2),
  tolerance_minutes    integer,
  price_per_hour       numeric(8, 2),
  amount_chf           numeric(10, 2),
  currency             text not null default 'CHF' check (currency = 'CHF'),
  created_by           uuid,
  created_at           timestamptz not null default private.now(),
  sent_by              uuid,
  sent_at              timestamptz,
  void_reason          text check (void_reason in ('report_corrected')),
  voided_at            timestamptz,
  check ((state = 'refused') = (refusal_reason is not null)),
  check (state = 'refused' or (recorded_minutes is not null and price_per_hour is not null and amount_chf is not null)),
  check ((sent_at is null) = (sent_by is null)),
  check (state <> 'sent' or sent_at is not null),
  check ((state = 'void') = (void_reason is not null)),
  check ((void_reason is null) = (voided_at is null))
);
create unique index if not exists team_invoice_drafts_one_live on public.team_invoice_drafts (take_id)
  where state in ('draft', 'sent');
create index if not exists team_invoice_drafts_team on public.team_invoice_drafts (team_id, seq desc);
create index if not exists team_invoice_drafts_client on public.team_invoice_drafts (client_account_id)
  where sent_at is not null;
create index if not exists team_invoice_drafts_visit on public.team_invoice_drafts (visit_id, seq desc);
comment on table public.team_invoice_drafts is
  'BK-f / BK-9: invoice draft from the take team to the client, built from the final report version (report_id, '
  'report_snapshot_hash) and the take''s price snapshot; or a visible refusal with its reason. Simulated invoice, '
  'synthetic data, no tariff, no payment through NAVORA (FE-078, R-12). Written only by SECURITY DEFINER functions.';
alter table public.team_invoice_drafts enable row level security;
revoke all on public.team_invoice_drafts from public, anon, authenticated;  -- read only through definer functions

-- Only draft → sent, draft → void, sent → void; every other column stays as built; never deleted.
create or replace function private.team_invoice_drafts_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'team_invoice_drafts rows are never deleted' using errcode = '42501';
  end if;
  if not ((old.state = 'draft' and new.state in ('sent', 'void')) or (old.state = 'sent' and new.state = 'void'))
     or (to_jsonb(new) - array['state', 'sent_by', 'sent_at', 'void_reason', 'voided_at'])
        is distinct from (to_jsonb(old) - array['state', 'sent_by', 'sent_at', 'void_reason', 'voided_at'])
     or (old.sent_at is not null and (new.sent_at is distinct from old.sent_at or new.sent_by is distinct from old.sent_by)) then
    raise exception 'team_invoice_drafts: transition not allowed' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function private.team_invoice_drafts_guard() from public, anon, authenticated;
drop trigger if exists team_invoice_drafts_guard on public.team_invoice_drafts;
create trigger team_invoice_drafts_guard before update or delete on public.team_invoice_drafts
  for each row execute function private.team_invoice_drafts_guard();

drop trigger if exists audit_team_invoice_drafts on public.team_invoice_drafts;
create trigger audit_team_invoice_drafts
  after insert or update on public.team_invoice_drafts
  for each row execute function private.write_audit_event('state', 'refusal_reason', 'report_id', 'take_id',
                                                          'amount_chf', 'sent_by', 'void_reason');
insert into private.audit_value_classes (table_name, key, class) values
  ('team_invoice_drafts', 'state',          'code'),
  ('team_invoice_drafts', 'refusal_reason', 'code'),
  ('team_invoice_drafts', 'report_id',      'code'),
  ('team_invoice_drafts', 'take_id',        'code'),
  ('team_invoice_drafts', 'amount_chf',     'code'),
  ('team_invoice_drafts', 'sent_by',        'code'),
  ('team_invoice_drafts', 'void_reason',    'code')
on conflict do nothing;

-- 3. The build rule ---------------------------------------------------------------------------------------------------
-- One attempt for one report version: inserts a draft or a refusal row and returns it; null when the report's visit is
-- not a take visit (no BK path, nothing written). Checks in this order; the first that applies is the reason.
create or replace function private.take_invoice_build(p_report_id uuid, p_actor uuid)
returns public.team_invoice_drafts language plpgsql security definer set search_path = '' set "TimeZone" = 'UTC'
as $$
declare
  r    public.visit_reports;
  v    public.care_visits;
  k    public.order_takes;
  o    public.partner_requests;
  pr   public.order_take_prices;
  tol  public.invoice_time_tolerances;
  t    record;
  row_ public.team_invoice_drafts;
  reason text;
  ordered numeric;
  recorded numeric;
begin
  select * into r from public.visit_reports where id = p_report_id;
  if r.id is null then return null; end if;
  select * into v from public.care_visits where id = r.visit_id;
  if v.order_take_id is null then return null; end if;   -- not a take visit: the BK path does not apply
  select * into k from public.order_takes where id = v.order_take_id;
  select * into o from public.partner_requests where id = k.order_id;
  -- one build per take at a time (trigger and command)
  perform pg_advisory_xact_lock(hashtextextended('take_invoice:' || k.id::text, 0));

  ordered := round((extract(epoch from (o.ends_at - o.starts_at)) / 60)::numeric, 2);
  if r.status = 'final' then
    select * into t from private.snapshot_times(r.snapshot);
    recorded := t.care_minutes_exact;
  end if;
  select * into pr from public.order_take_prices where take_id = k.id;
  select * into tol from public.invoice_time_tolerances where key = 'take_invoice';

  if r.status <> 'final' then
    reason := 'not_signed';
  elsif exists (select 1 from public.visit_reports s
                where s.supersedes_id = r.id and s.status = 'final') then
    reason := 'superseded';
  elsif exists (select 1 from public.team_invoice_drafts d where d.take_id = k.id and d.state in ('draft', 'sent')) then
    reason := 'already_drafted';
  elsif exists (select 1 from public.quality_holds h where h.visit_id = v.id and h.lifted_at is null) then
    reason := 'on_hold';
  elsif tol.key is null then
    reason := 'no_tolerance';
  elsif pr.price_per_hour is null then
    reason := 'no_price';
  elsif recorded is null or ordered is null then
    reason := 'no_times';
  elsif abs(recorded - ordered) > tol.tolerance_minutes then
    reason := 'times_disagree';
  end if;

  insert into public.team_invoice_drafts
    (organization_id, team_id, client_account_id, order_id, take_id, visit_id, report_id, report_version,
     report_snapshot_hash, state, refusal_reason, ordered_minutes, recorded_minutes, tolerance_minutes,
     price_per_hour, amount_chf, created_by)
  values
    (k.organization_id, k.team_id, o.client_account_id, o.id, k.id, v.id, r.id, r.version,
     private.report_snapshot_hash(r.snapshot),
     case when reason is null then 'draft' else 'refused' end, reason, ordered, recorded, tol.tolerance_minutes,
     pr.price_per_hour,
     case when reason is null then round(recorded * pr.price_per_hour / 60, 2) end,
     p_actor)
  returning * into row_;
  return row_;
end;
$$;
revoke all on function private.take_invoice_build(uuid, uuid) from public, anon, authenticated;
comment on function private.take_invoice_build(uuid, uuid) is
  'BK-f / BK-9, BK-9n: one draft or one visible refusal for a take report version (not_signed, superseded, '
  'already_drafted, on_hold, no_tolerance, no_price, no_times, times_disagree). Minutes from the signed snapshot '
  '(snapshot_times, CGR-03), price from the take snapshot (0155), amount = minutes × price / 60, 2 decimals (multiply first, BKF-F2).';

-- Stores the refusal `build_failed` when a build raised; never raises itself.
create or replace function private.take_invoice_build_failed(p_report_id uuid, p_actor uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.team_invoice_drafts
    (organization_id, team_id, client_account_id, order_id, take_id, visit_id, report_id, report_version,
     report_snapshot_hash, state, refusal_reason, created_by)
  select k.organization_id, k.team_id, o.client_account_id, o.id, k.id, v.id, r.id, r.version,
         private.report_snapshot_hash(r.snapshot), 'refused', 'build_failed', p_actor
  from public.visit_reports r
  join public.care_visits v on v.id = r.visit_id
  join public.order_takes k on k.id = v.order_take_id
  join public.partner_requests o on o.id = k.order_id
  where r.id = p_report_id;
exception when others then
  null;  -- the signature is never blocked by billing; the missing row shows as «kein Rechnungsentwurf»
end $$;
revoke all on function private.take_invoice_build_failed(uuid, uuid) from public, anon, authenticated;

-- 4. When a take report becomes final ---------------------------------------------------------------------------------
create or replace function private.take_report_final_invoice()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  take uuid;
  actor uuid := coalesce((select auth.uid()), new.signed_by);
begin
  if new.status <> 'final' or (tg_op = 'UPDATE' and old.status = 'final') then return null; end if;
  select v.order_take_id into take from public.care_visits v where v.id = new.visit_id;
  if take is null then return null; end if;
  -- CGR-210 (b): a correction voids the take's live draft or sent invoice, in this transaction.
  if new.supersedes_id is not null then
    begin
      update public.team_invoice_drafts
        set state = 'void', void_reason = 'report_corrected', voided_at = private.now()
        where take_id = take and state in ('draft', 'sent') and report_id <> new.id;
    exception when others then
      null;  -- the next build then shows already_drafted; the signature stays
    end;
  end if;
  begin
    perform private.take_invoice_build(new.id, actor);
  exception when others then
    perform private.take_invoice_build_failed(new.id, actor);
  end;
  return null;
end $$;
revoke all on function private.take_report_final_invoice() from public, anon, authenticated;
drop trigger if exists take_report_final_invoice on public.visit_reports;
create trigger take_report_final_invoice
  after insert or update of status on public.visit_reports
  for each row execute function private.take_report_final_invoice();

-- 5. Commands ---------------------------------------------------------------------------------------------------------
create or replace function private.take_team_member(p_team_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and private.is_team_member(p_team_id)
         and exists (select 1 from public.teams t where t.id = p_team_id and private.is_org_member(t.organization_id))
$$;
revoke all on function private.take_team_member(uuid) from public, anon, authenticated;

create or replace function public.build_team_invoice_draft(p_report_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r  public.visit_reports;
  d  public.team_invoice_drafts;
begin
  if private.begin_command('build_team_invoice_draft', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into r from public.visit_reports where id = p_report_id;
  if r.id is null or not private.take_team_member(r.team_id)
     or not exists (select 1 from public.care_visits v where v.id = r.visit_id and v.order_take_id is not null) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  d := private.take_invoice_build(r.id, (select auth.uid()));
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'draft_id', d.id, 'state', d.state, 'reason', d.refusal_reason);
end $$;
revoke all on function public.build_team_invoice_draft(uuid, uuid) from public, anon;
grant execute on function public.build_team_invoice_draft(uuid, uuid) to authenticated;
comment on function public.build_team_invoice_draft(uuid, uuid) is
  'BK-f: the take team builds the invoice draft again for a report version (after a hold is lifted or the tolerance '
  'is set). Same rule and refusals as the automatic build.';

create or replace function public.send_team_invoice_draft(p_draft_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  d public.team_invoice_drafts;
begin
  if private.begin_command('send_team_invoice_draft', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into d from public.team_invoice_drafts where id = p_draft_id for update;
  if d.id is null or not private.take_team_member(d.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if d.state <> 'draft' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_draft');
  end if;
  update public.team_invoice_drafts set state = 'sent', sent_by = (select auth.uid()), sent_at = private.now()
    where id = d.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'draft_id', d.id);
end $$;
revoke all on function public.send_team_invoice_draft(uuid, uuid) from public, anon;
grant execute on function public.send_team_invoice_draft(uuid, uuid) to authenticated;
comment on function public.send_team_invoice_draft(uuid, uuid) is
  'BK-f: «Bestätigen und senden» by an active member of the take team; records who confirmed. Sent = the client reads '
  'it in the portal. No PDF, no payment (R-12).';

-- 6. Readers ----------------------------------------------------------------------------------------------------------
-- /team: per take the live draft or sent invoice, invoices voided after sending, and the newest refusal while there is
-- no live row.
create or replace function public.my_team_invoice_drafts()
returns table (id uuid, team_id uuid, team_name text, client_name text, visit_date date,
               state text, refusal_reason text, ordered_minutes numeric, recorded_minutes numeric,
               price_per_hour numeric, amount_chf numeric, currency text, report_id uuid, report_version integer,
               created_at timestamptz, sent_at timestamptz, voided_at timestamptz, void_reason text)
language sql stable security definer set search_path = '' as $$
  select d.id, d.team_id, t.name, ca.display_name, v.visit_date, d.state, d.refusal_reason,
         d.ordered_minutes, d.recorded_minutes, d.price_per_hour, d.amount_chf, d.currency, d.report_id, d.report_version,
         d.created_at, d.sent_at, d.voided_at, d.void_reason
  from public.team_invoice_drafts d
  join public.teams t on t.id = d.team_id
  join public.care_visits v on v.id = d.visit_id
  left join public.client_accounts ca on ca.id = d.client_account_id
  where private.take_team_member(d.team_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
    and (d.state in ('draft', 'sent')
         or (d.state = 'void' and d.sent_at is not null)
         or (d.state = 'refused'
             and not exists (select 1 from public.team_invoice_drafts l
                             where l.take_id = d.take_id and l.state in ('draft', 'sent'))
             and d.seq = (select max(n.seq) from public.team_invoice_drafts n where n.take_id = d.take_id)))
  order by v.visit_date desc, d.seq desc
$$;
revoke all on function public.my_team_invoice_drafts() from public, anon;
grant execute on function public.my_team_invoice_drafts() to authenticated;
comment on function public.my_team_invoice_drafts() is
  'BK-f /team «Rechnungsentwürfe»: drafts, sent invoices, invoices voided after sending and the newest refusal per take '
  'of the caller''s own teams. A former member (LEAVE1-3) reads nothing.';

-- /field: the newest invoice row of the visit's take, for the line after signing.
create or replace function public.my_take_invoice_state(p_visit_id uuid)
returns table (state text, refusal_reason text, amount_chf numeric)
language sql stable security definer set search_path = '' as $$
  select d.state, d.refusal_reason, d.amount_chf
  from public.team_invoice_drafts d
  where d.visit_id = p_visit_id and private.take_team_member(d.team_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by d.seq desc
  limit 1
$$;
revoke all on function public.my_take_invoice_state(uuid) from public, anon;
grant execute on function public.my_take_invoice_state(uuid) to authenticated;

-- /order «Rechnungen»: sent invoices (and those voided after sending) of the caller's own client account only.
-- No member name, no tag (CGR-210 (c), UXR-191 (3)).
create or replace function public.client_invoices()
returns table (id uuid, client_account_id uuid, visit_date date, hours numeric, price_per_hour numeric,
               amount_chf numeric, currency text, team_name text, state text, sent_at timestamptz,
               voided_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select d.id, d.client_account_id, v.visit_date, round(d.recorded_minutes / 60, 2), d.price_per_hour, d.amount_chf,
         d.currency, t.name, d.state, d.sent_at, d.voided_at
  from public.team_invoice_drafts d
  join public.teams t on t.id = d.team_id
  join public.care_visits v on v.id = d.visit_id
  where d.client_account_id is not null and private.is_client_member(d.client_account_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
    and d.sent_at is not null and d.state in ('sent', 'void')
  order by v.visit_date desc, d.seq desc
$$;
revoke all on function public.client_invoices() from public, anon;
grant execute on function public.client_invoices() to authenticated;
comment on function public.client_invoices() is
  'BK-f /order «Rechnungen»: read-only, sent invoices of the caller''s own client account (and those voided after '
  'sending). Date, hours, price, amount, team name, state. No member name, no tag. Simulated invoice.';

-- 7. G-6: configuration rows only for organisation members ------------------------------------------------------------
create or replace function private.is_any_org_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.organization_memberships m where m.user_id = (select auth.uid()))
         and not private.access_ended((select auth.uid()))
$$;
revoke all on function private.is_any_org_member() from public, anon;
grant execute on function private.is_any_org_member() to authenticated;  -- used inside the RLS policies below
drop policy if exists members_read on public.tariff_rates;
create policy members_read on public.tariff_rates for select to authenticated using ((select private.is_any_org_member()));
drop policy if exists members_read on public.billing_rules;
create policy members_read on public.billing_rules for select to authenticated using ((select private.is_any_org_member()));
