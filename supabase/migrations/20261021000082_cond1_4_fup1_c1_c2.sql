-- COND1-4 (brief docs/agents/briefs/COND1.md): FUP1-C1 (Q16) and FUP1-C2 (CGR-60), specified in
-- docs/agents/briefs/FUP1.md, *PO decision 2026-10-25 18:12 CET*. ADR-095. Builds on 0071 (FUP1-2, the banner forecast),
-- 0080 (LEAVE1-C2 in the made-step branch), 0062/0064/0074 (channel, push_active, Operations recipients).
--
-- Only the NOT-YET-MADE branch of `private.signal_step_outside_app` changes. Before the step to Operations is made,
-- the banner ("Meldung an Operations folgt") now promises the message only when ALL of these hold:
--   FUP1-C1 (Q16): a watched period runs at the instant the step is due AND one evaluator interval later
--     (`private.signal_evaluator_interval()`, one minute: the cadence of the pg_cron job `navora-sig1-signals`,
--     '* * * * *', 0060/0064; an operating fact, not a clinical value). A step due in the last interval before a
--     watched period ends may be made by the next evaluator run, after the end, in the app only (SIG2-12).
--   FUP1-C2 (CGR-60): at the reading instant, the organisation's push channel is on (`organization_push_settings.enabled`,
--     read only after `enabled_since`) AND at least one Operations recipient of the step has an active subscription.
--     The recipients are the step's own set `private.signal_operations_users` (0074: Operations members with open
--     access; admins only when the organisation has no such member) and "active" is the step's own rule
--     `private.push_active` (0062, with LEAVE1-3 from 0074). Both are reused, not copied.
-- The made-step branch is unchanged (it follows the real delivery, LEAVE1-C2 of 0080). The step itself
-- (`outside_classify`, `outside_settle`, `evaluate_all_signals`), thresholds, watched hours and routing are untouched
-- (D-28, D-32). The reader `my_signals.operations_outside_app` keeps its name and type: it calls this function.
--
-- Display narrowing only, protective: a false here makes the banner say "Operations in der App" (the in-app delivery
-- happens either way). No clinical, tariff or legal rule. Idempotent: create or replace; a second run changes nothing.

-- 1. The evaluator interval, named once ---------------------------------------------------------------------------------
create or replace function private.signal_evaluator_interval()
returns interval language sql immutable set search_path = ''
as $$ select interval '1 minute' $$;
comment on function private.signal_evaluator_interval() is
  'FUP1-C1 (Q16, ADR-095): the cadence of the scheduled signal evaluator, the pg_cron job navora-sig1-signals '
  '(''* * * * *'', scheduled in 0060 and 0064). Change it together with that schedule.';
revoke all on function private.signal_evaluator_interval() from public, anon, authenticated;

-- 2. FUP1-C2: an Operations recipient of the step can be reached outside the app ----------------------------------------
create or replace function private.signal_operations_reachable(p_org uuid, p_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.organization_push_settings ps
                 where ps.organization_id = p_org and ps.enabled and ps.enabled_since <= p_at)
     and exists (select 1 from private.signal_operations_users(p_org) o where private.push_active(o))
$$;
comment on function private.signal_operations_reachable(uuid, timestamptz) is
  'FUP1-C2 (CGR-60, ADR-095): at p_at the organisation''s outside channel is on (enabled, after enabled_since) and at '
  'least one Operations recipient of the step (signal_operations_users) has an active subscription (push_active).';
revoke all on function private.signal_operations_reachable(uuid, timestamptz) from public, anon, authenticated;

-- 3. The forecast ------------------------------------------------------------------------------------------------------
create or replace function private.signal_step_outside_app(p_signal_id uuid, p_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when s.escalated_at is not null
         or exists (select 1 from public.signal_deliveries d
                    where d.signal_id = s.id and d.reason in ('operations_fallback', 'untaken'))
      then exists (select 1 from public.signal_deliveries d
                   join public.signal_outside_deliveries o on o.id = d.id
                   where d.signal_id = s.id and d.reason in ('operations_fallback', 'untaken')
                     and o.result in ('pending', 'sent')
                     and not private.access_ended(o.recipient_id))  -- LEAVE1-C2 (CGR-64)
    else coalesce((select private.watched_inside(s.organization_id, due.at)
                          and private.watched_inside(s.organization_id,
                                                     due.at + private.signal_evaluator_interval())  -- FUP1-C1 (Q16)
                   from private.effective_exception_rules(s.organization_id) r
                   cross join lateral (select greatest(p_at, private.after_threshold(s.created_at, r.amount, r.unit)) as at) due
                   where r.exception_type = 'signal_untaken'
                   limit 1), false)
         and private.signal_operations_reachable(s.organization_id, p_at)  -- FUP1-C2 (CGR-60)
  end
  from public.safety_signals s where s.id = p_signal_id
$$;
comment on function private.signal_step_outside_app(uuid, timestamptz) is
  'FUP1-2 (ADR-084) with LEAVE1-C2 (ADR-093) and FUP1-C1/-C2 (ADR-095): whether the step to Operations reaches '
  'Operations outside the app. After the step: an Operations outside delivery is pending or sent and its recipient''s '
  'access is open. Before: a watched period runs when the step falls due and one evaluator interval later, the channel '
  'is on and an Operations recipient of the step has an active subscription (read at p_at).';
revoke all on function private.signal_step_outside_app(uuid, timestamptz) from public, anon, authenticated;
