-- =============================================================================
-- NAVORA synthetic seed — NO REAL DATA
-- =============================================================================
-- Every person, case and partner here is invented. Names follow obvious test
-- patterns ("Testfall NN", "Testpartner X", "Pflegekraft Test N").
-- No date of birth, address, phone, diagnosis or insurance is seeded: the app
-- does not display them and the seed should not model them (data minimisation).
--
-- Coverage goal (T5): every legacy attention rule in
-- src/features/operations/queries.ts fires at least once, plus one entity of
-- each kind that does NOT fire. Region names match the two regions hard-coded
-- in the Teams page (TD-13), otherwise teams would not render there.
-- =============================================================================

-- Test clock (DST1 / ADR-081) — LOCAL / CI ONLY ----------------------------------
-- Enables the test clock: private.now() honours the setting navora.test_now only while this row exists. It comes
-- first so that a pinned clock (CI db job) also dates the seed rows. `supabase db push` never runs this file, so
-- staging and production never hold the row and private.now() is private.now() there. Seed times read private.now().
insert into private.test_clock (enabled) values (true) on conflict do nothing;

-- Organisations (T9) ------------------------------------------------------------
-- A holds all synthetic care data. B exists only to prove tenant isolation.
insert into public.organizations (id, name) values
  ('00000000-0000-4000-b000-000000000011', 'Testorganisation A'),
  ('00000000-0000-4000-b000-000000000012', 'Testorganisation B');

-- Teams ----------------------------------------------------------------------
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101', private.now() - interval '90 days', 'Testteam Nord',  'Bern West',    'Ambulante Pflege', 'active',   0, 95, 'Leitung Test A', 'Kapazität klären',     true,  'Coach Test 1'), -- P1 overload
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000102', private.now() - interval '80 days', 'Testteam Mitte', 'Bern West',    'Ambulante Pflege', 'active',   2, 84, 'Leitung Test B', 'Einsatzplan prüfen',   false, null),           -- P2 utilization >= 80
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000103', private.now() - interval '70 days', 'Testteam Süd',   'Zürich Pilot', 'Übergangspflege',  'building', 1, 55, 'Leitung Test C', 'Onboarding',           false, 'Coach Test 2'), -- P2 open_slots <= 1
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000104', private.now() - interval '60 days', 'Testteam West',  'Zürich Pilot', 'Ambulante Pflege', 'active',   4, 60, 'Leitung Test D', 'Keine Massnahme',      false, 'Coach Test 2'), -- no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000105', private.now() - interval '50 days', 'Testteam Ost',   'Basel Pilot',  'Übergangspflege',  'active',   5, 40, 'Leitung Test E', 'Keine Massnahme',      false, null);           -- third region (TD-13), no attention

-- Cases ----------------------------------------------------------------------
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000201', private.now() - interval '2 hours',  'Testfall 01', 'Testfall', '01', 'Bern West',    'neu',          'hoch',    'Grundpflege',     array['Grundpflege'],                'Team anfragen',       null, null),                                     -- P1: no team, urgency hoch
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000202', private.now() - interval '3 hours',  'Testfall 02', 'Testfall', '02', 'Zürich Pilot', 'neu',          'mittel',  'Medikamentengabe', array['Medikamentengabe'],          'Team anfragen',       null, null),                                     -- P2: no team, fresh
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000203', private.now() - interval '30 hours', 'Testfall 03', 'Testfall', '03', 'Bern West',    'neu',          'niedrig', 'Hauswirtschaft',  array['Hauswirtschaft'],             'Team anfragen',       null, null),                                     -- P1: no team >= 24 h; SLA risk
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000204', private.now() - interval '60 hours', 'Testfall 04', 'Testfall', '04', 'Zürich Pilot', 'neu',          'mittel',  'Wundversorgung',  array['Wundversorgung'],             'Team anfragen',       null, null),                                     -- P1: no team; SLA violated (>48 h)
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000205', private.now() - interval '30 hours', 'Testfall 05', 'Testfall', '05', 'Bern West',    'teampruefung', 'mittel',  'Grundpflege',     array['Grundpflege', 'Mobilisation'], 'Teamentscheid',       'Testteam Mitte', '00000000-0000-4000-a000-000000000102'), -- P1: Teamentscheid >= 24 h
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000206', private.now() - interval '4 hours',  'Testfall 06', 'Testfall', '06', 'Zürich Pilot', 'teampruefung', 'niedrig', 'Begleitung',      array['Begleitung'],                 'Teamentscheid',       'Testteam Süd',   '00000000-0000-4000-a000-000000000103'), -- P2: Teamentscheid fresh
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000207', private.now() - interval '5 hours',  'Testfall 07', 'Testfall', '07', 'Bern West',    'teampruefung', 'mittel',  'Grundpflege',     array['Grundpflege'],                'Teamentscheid',       null, null),                                     -- duplicate pair: no team AND teampruefung (TD-09)
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', private.now() - interval '20 days',  'Testfall 08', 'Testfall', '08', 'Bern West',    'laufend',      'mittel',  'Grundpflege',     array['Grundpflege'],                'Laufende Versorgung', 'Testteam Nord',  '00000000-0000-4000-a000-000000000101'), -- no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000209', private.now() - interval '15 days',  'Testfall 09', 'Testfall', '09', 'Zürich Pilot', 'laufend',      'niedrig', 'Medikamentengabe', array['Medikamentengabe'],          'Laufende Versorgung', 'Testteam West',  '00000000-0000-4000-a000-000000000104'), -- no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000210', private.now() - interval '10 days',  'Testfall 10', 'Testfall', '10', 'Bern West',    'laufend',      'hoch',    'Wundversorgung',  array['Wundversorgung'],             'Laufende Versorgung', 'Testteam Mitte', '00000000-0000-4000-a000-000000000102'); -- no attention

-- Partner requests -----------------------------------------------------------
insert into public.partner_requests (organization_id, id, created_at, partner_name, partner_type, region, city, urgency, time_info, request_title, need_summary, requested_services, status, converted_case_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000301', private.now() - interval '1 hour',   'Testpartner A', 'Spital',       'Bern West',    'Teststadt', 'hoch',    'Heute', 'Austritt Testfall', 'Synthetischer Bedarf A', array['Grundpflege'], 'open',             null), -- P1 urgent
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000302', private.now() - interval '2 hours',  'Testpartner B', 'Pflegeheim',   'Zürich Pilot', 'Teststadt', 'mittel',  '48h',   'Übergang Test',     'Synthetischer Bedarf B', array['Begleitung'],  'ready_to_convert', null), -- P2 fresh
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000303', private.now() - interval '36 hours', 'Testpartner C', 'Hausarzt',     'Bern West',    'Teststadt', 'niedrig', 'Woche', 'Abklärung Test',    'Synthetischer Bedarf C', null,                 'open',             null), -- P1 >= 24 h
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000304', private.now() - interval '5 days',   'Testpartner D', 'Spital',       'Bern West',    'Teststadt', 'mittel',  null,    'Erledigt Test',     'Synthetischer Bedarf D', null,                 'converted',        '00000000-0000-4000-a000-000000000208'); -- no attention

-- Matching request (read by Operations, not acted on) -----------------------
insert into public.matching_requests (organization_id, id, created_at, case_id, request_title, region, urgency, required_services, status, selected_team_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000401', private.now() - interval '4 hours', '00000000-0000-4000-a000-000000000206', 'Teamsuche Testfall 06', 'Zürich Pilot', 'niedrig', array['Begleitung'], 'open', null);

-- Care visits ----------------------------------------------------------------
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end, team_member_name, services_provided, notes, billable, status) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000501', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date,     '08:00', '08:45', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000502', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date,     '10:00', '10:30', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'started'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000503', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', (private.now() at time zone 'Europe/Zurich')::date,     '11:00', '11:30', 'Pflegekraft Test 2', array['Medikamentengabe'], null,                false, 'on_the_way'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000504', private.now() - interval '2 days', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', (private.now() at time zone 'Europe/Zurich')::date - 1, '09:00', '09:30', 'Pflegekraft Test 2', array['Medikamentengabe'], 'Synthetische Notiz', false, 'completed'), -- approved note → no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000505', private.now() - interval '2 days', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', (private.now() at time zone 'Europe/Zurich')::date - 1, '14:00', '14:45', 'Pflegekraft Test 3', array['Wundversorgung'],   null,                false, 'completed'), -- no note → P2
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000506', private.now() - interval '2 days', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', (private.now() at time zone 'Europe/Zurich')::date - 1, '16:00', '16:30', 'Pflegekraft Test 3', array['Wundversorgung'],   null,                false, 'completed'), -- draft note → P2
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000507', private.now() - interval '3 days', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date - 2, '08:00', '08:30', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'cancelled'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000508', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date + 1, '09:00', '09:45', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'planned'), -- F2 e2e: full field path tomorrow
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000509', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date + 2, '18:00', '18:30', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'planned'); -- F7 e2e: run by the care assistant, countersigned by the nurse

-- Care notes -----------------------------------------------------------------
insert into public.care_notes (organization_id, id, created_at, visit_id, case_id, team_id, author_name, note_type, content, status) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000601', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000504', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', 'Pflegekraft Test 2', 'visit_report', 'Synthetischer Bericht.', 'approved'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000602', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000506', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', 'Pflegekraft Test 3', 'visit_report', 'Synthetischer Entwurf.', 'draft');

-- Quality events -------------------------------------------------------------
insert into public.quality_events (organization_id, id, created_at, case_id, visit_id, team_id, event_type, severity, title, description, status) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000701', private.now() - interval '6 hours', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000505', '00000000-0000-4000-a000-000000000102', 'documentation', 'high', 'Testereignis hoch',    'Synthetisches Ereignis.', 'open'),   -- P1
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000702', private.now() - interval '1 day',   '00000000-0000-4000-a000-000000000208', null,                                   '00000000-0000-4000-a000-000000000101', 'process',       'low',  'Testereignis niedrig', null,                       'open'),   -- P2
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000703', private.now() - interval '5 days',  '00000000-0000-4000-a000-000000000209', null,                                   '00000000-0000-4000-a000-000000000104', 'process',       'medium', 'Testereignis erledigt', null,                    'closed'); -- no attention

-- Auth test users (T8) — LOCAL / CI ONLY ------------------------------------
-- Synthetic accounts for sign-in tests. The password is public in this repo
-- and must never exist in staging or production: `supabase db push` does not
-- run seed.sql, and staging users are created separately (T12).
-- Password for all test users: navora-local-only
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000901', 'authenticated', 'authenticated',
   'coach.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000902', 'authenticated', 'authenticated',
   'pflege.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000903', 'authenticated', 'authenticated',
   'fremd.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000904', 'authenticated', 'authenticated',
   'ops.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000905', 'authenticated', 'authenticated',
   'admin.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000906', 'authenticated', 'authenticated',
   'assist.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  ('00000000-0000-4000-a000-000000000911', '00000000-0000-4000-a000-000000000901', '00000000-0000-4000-a000-000000000901',
   '{"sub":"00000000-0000-4000-a000-000000000901","email":"coach.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-000000000912', '00000000-0000-4000-a000-000000000902', '00000000-0000-4000-a000-000000000902',
   '{"sub":"00000000-0000-4000-a000-000000000902","email":"pflege.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-000000000913', '00000000-0000-4000-a000-000000000903', '00000000-0000-4000-a000-000000000903',
   '{"sub":"00000000-0000-4000-a000-000000000903","email":"fremd.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-000000000914', '00000000-0000-4000-a000-000000000904', '00000000-0000-4000-a000-000000000904',
   '{"sub":"00000000-0000-4000-a000-000000000904","email":"ops.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-000000000915', '00000000-0000-4000-a000-000000000905', '00000000-0000-4000-a000-000000000905',
   '{"sub":"00000000-0000-4000-a000-000000000905","email":"admin.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-000000000916', '00000000-0000-4000-a000-000000000906', '00000000-0000-4000-a000-000000000906',
   '{"sub":"00000000-0000-4000-a000-000000000906","email":"assist.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now());

-- Testorganisation B (T9) — isolation fixture --------------------------------
-- Same region name as org A on purpose: isolation must come from the
-- organisation, not from a different region filter.
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000151', private.now() - interval '30 days', 'Fremdteam B', 'Bern West', 'Ambulante Pflege', 'active', 3, 70, 'Leitung Fremd', 'Keine Massnahme', false, 'Coach Fremd');

insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id) values
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000251', private.now() - interval '3 days', 'Testfall B1', 'Testfall', 'B1', 'Bern West', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Fremdteam B', '00000000-0000-4000-a000-000000000151');

insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end, team_member_name, services_provided, notes, billable, status) values
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000551', private.now() - interval '1 day', '00000000-0000-4000-a000-000000000251', '00000000-0000-4000-a000-000000000151', (private.now() at time zone 'Europe/Zurich')::date, '09:00', '09:30', 'Pflegekraft Fremd', array['Grundpflege'], null, false, 'planned');

-- Memberships (T9) — placeholder roles (ADR-005, BACKLOG Q4) --------------------
--   coach.test  : org A, role coach — may change team settings, is in no team
--   pflege.test : org A, role nurse — member of Testteam Nord (101), may move its visits
--   fremd.test  : org B, role admin — must see nothing of org A
--   ops.test    : org A, role operations — referral intake (J1)
--   admin.test  : org A, role admin — pilot administration (ADM1)
--   assist.test : org A, role nurse — care assistant in Testteam Nord (F7 countersignature path)
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000901', 'coach'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'nurse'),
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000903', 'admin'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000904', 'operations'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000905', 'admin'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000906', 'nurse');

insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902', 'registered_nurse'),
  -- F7: a care assistant of Testteam Nord, so the countersignature path runs end to end
  ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'care_assistant');

-- J3 (PO brief): running seed cases already had their needs assessment.
update public.cases set needs_assessment_done_at = created_at + interval '1 day'
where status = 'laufend';

-- CSR1 part 11 / CGR-32, part 12 / ABS1-C6 (e2e): assist.test's planned visit yesterday 07:00 was never started. The
-- e2e (field.spec "ABS1-C6") records her absence from yesterday through /field as a colleague, so the confirmation
-- counts this visit (past_planned = 1); it then keeps her as responsible, and its overdue alert on /team carries
-- "Zuständige Person abwesend gemeldet". Until then the seed holds no absence (ABS1-C6 replaced the seeded one).
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000532', private.now() - interval '3 days',
   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   (private.now() at time zone 'Europe/Zurich')::date - 1, '07:00', '07:30', array['Grundpflege'], false, 'planned', 30, 0,
   '00000000-0000-4000-a000-000000000906');

-- COND1-5 / WORK1-C2 (e2e work.spec): assist.test acknowledged the first information text (work1-notice-v1) before
-- 0083. A v1 acknowledgement does not carry over, so /work shows her the v2 text first. Written as the table owner:
-- acknowledge_working_time_notice accepts only the current version.
insert into public.working_time_notice_acks (organization_id, user_id, text_version, acknowledged_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000906', 'work1-notice-v1', private.now() - interval '2 days');

-- COND2-2 (e2e quality.spec, ADR-101): a quality claim whose owner left. austritt.test (…907) is a synthetic nurse of
-- org A in no team who once took event 704 (Testteam Nord, visit 502 today) in review; her access was then ended by
-- the administrator. Her claim has lapsed (0085), so the team sees "Übernahme beendet – Zugang beendet" and can take
-- it over ("Übernehmen", 0087). She never signs in (no password, e-mail unconfirmed, no identity row). Written as the
-- table owner, in the order the commands would write it: the claim, then the access end.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000907', 'authenticated', 'authenticated',
   'austritt.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000907', 'nurse');
-- ADM2-10 (e2e, 0091): an account made by hand (D-26 default A) for a colleague the team admits; no membership, no
-- identity, e-mail unconfirmed, no password. "Vertrag erfassen" on /admin names it by its e-mail.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000958', 'authenticated', 'authenticated',
   'aufnahme.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into public.quality_events (organization_id, id, created_at, case_id, visit_id, team_id, event_type, severity, title, description, status, owner_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000704', private.now() - interval '3 hours', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000502', '00000000-0000-4000-a000-000000000101', 'process', 'low', 'Testereignis Übernahme', null, 'in_review', '00000000-0000-4000-a000-000000000907');
insert into public.quality_event_log (organization_id, event_id, from_status, to_status, note, actor_id, idempotency_key, created_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000704', 'open', 'in_review', null,
   '00000000-0000-4000-a000-000000000907', '00000000-0000-4000-a000-000000000781', private.now() - interval '2 hours');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id, created_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000907', 'ended', 'employment_ended',
   '00000000-0000-4000-a000-000000000905', private.now() - interval '1 hour');


-- ADM2 part (b) (e2e contract-end.spec, ADR-115): contract ends in their own organisation, so no org-A or org-B count
-- changes (the ADM1 and LEAVE1 suites stay unmodified). Testorganisation C has one team and one case; all synthetic.
--   teamc.test   (…960): registered nurse of Testteam C who signs in; her contract ends in 14 days (ADM2-14 (a): /work
--                        shows her the date her access ends).
--   vertrag.test (…959): registered nurse of Testteam C, primary nurse of Testfall C1; her contract ended the day
--                        before yesterday, so her access ended at the start of yesterday without a command (ADM2-13):
--                        /team shows "Bezugspflege neu bestimmen" (ADM2-15 (b)).
--   bald.test    (…961): registered nurse of Testteam C, deputy nurse of Testfall C1; her contract ends in 10 days, so
--                        the team's registered nurses see her handover list (ADM2-12, ADM2-15 (a)).
-- vertrag.test and bald.test never sign in (no password, e-mail unconfirmed, no identity row). Written as the table
-- owner, in the order the commands would write it: memberships, the J6 assignment, then the contracts (actor: the nil
-- UUID, as for a system row; the organisation has no administrator).
insert into public.organizations (id, name) values ('00000000-0000-4000-b000-000000000013', 'Testorganisation C');
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000161', private.now() - interval '200 days', 'Testteam C', 'Bern West', 'Ambulante Pflege', 'active', 2, 60, 'Leitung Test C3', 'Keine Massnahme', false, null);
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id, needs_assessment_done_at) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000261', private.now() - interval '100 days', 'Testfall C1', 'Testfall', 'C1', 'Bern West', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam C', '00000000-0000-4000-a000-000000000161', private.now() - interval '99 days');
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000960', 'authenticated', 'authenticated',
   'teamc.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000959', 'authenticated', 'authenticated',
   'vertrag.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000961', 'authenticated', 'authenticated',
   'bald.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  ('00000000-0000-4000-a000-000000000970', '00000000-0000-4000-a000-000000000960', '00000000-0000-4000-a000-000000000960',
   '{"sub":"00000000-0000-4000-a000-000000000960","email":"teamc.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now());
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000960', 'nurse'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000959', 'nurse'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000961', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000161', '00000000-0000-4000-a000-000000000960', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000161', '00000000-0000-4000-a000-000000000959', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000161', '00000000-0000-4000-a000-000000000961', 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000960', 'Pflegekraft Team C', '00000000-0000-4000-a000-000000000960'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000959', 'Pflegekraft Vertragsende', '00000000-0000-4000-a000-000000000960'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000961', 'Pflegekraft Bald', '00000000-0000-4000-a000-000000000960');
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000959', deputy_nurse_id = '00000000-0000-4000-a000-000000000961'
where id = '00000000-0000-4000-a000-000000000261';
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id, created_at) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000960',
   (private.now() at time zone 'Europe/Zurich')::date - 200, (private.now() at time zone 'Europe/Zurich')::date + 14,
   '00000000-0000-0000-0000-000000000000', private.now() - interval '30 days'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000959',
   (private.now() at time zone 'Europe/Zurich')::date - 120, (private.now() at time zone 'Europe/Zurich')::date - 2,
   '00000000-0000-0000-0000-000000000000', private.now() - interval '30 days'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000961',
   (private.now() at time zone 'Europe/Zurich')::date - 60, (private.now() at time zone 'Europe/Zurich')::date + 10,
   '00000000-0000-0000-0000-000000000000', private.now() - interval '30 days');

-- OBS1 (e2e obs1.spec, migration 0095, ADR-118): an observation written before the author's qualification was recorded.
--   notiz.test (…962): a member of Testteam C admitted by her team; she wrote an observation on today's completed visit of
--                    Testfall C1 while her qualification was not yet recorded, then the administrator path recorded it.
--                    The OBS1-1 marker stays on that observation (fixed when written). She never signs in (no password,
--                    e-mail unconfirmed, no identity row), so the counts of pgTAP 002 stay.
--   teamc.test performed the visit (started and completed it) and wrote an observation too; she drafts and signs the report.
-- Written as the table owner, in the order the commands would write it: membership without qualification, the visit and
-- its events, the observations (the 0095 trigger records the marker), then the qualification (as set_member_qualification
-- would; no member stays without one, pgTAP 018).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000962', 'authenticated', 'authenticated',
   'notiz.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000962', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000161', '00000000-0000-4000-a000-000000000962', null);
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000962', 'Neues Teammitglied C', '00000000-0000-4000-a000-000000000962');
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, responsible_user_id) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000562', private.now() - interval '2 days',
   '00000000-0000-4000-a000-000000000261', '00000000-0000-4000-a000-000000000161',
   (private.now() at time zone 'Europe/Zurich')::date, '07:00', '07:30', array['Grundpflege'], false, 'completed', 30,
   '00000000-0000-4000-a000-000000000960');
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, occurred_at, actor_id, command) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000562', '00000000-0000-4000-a000-000000000161',
   'started', 'planned', 'started', ((private.now() at time zone 'Europe/Zurich')::date + time '07:02') at time zone 'Europe/Zurich',
   '00000000-0000-4000-a000-000000000960', 'start_visit'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000562', '00000000-0000-4000-a000-000000000161',
   'completed', 'started', 'completed', ((private.now() at time zone 'Europe/Zurich')::date + time '07:31') at time zone 'Europe/Zurich',
   '00000000-0000-4000-a000-000000000960', 'complete_visit');
insert into public.visit_observations (organization_id, visit_id, case_id, team_id, author_id, recorded_at, content, for_handover, idempotency_key) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000562', '00000000-0000-4000-a000-000000000261',
   '00000000-0000-4000-a000-000000000161', '00000000-0000-4000-a000-000000000962',
   ((private.now() at time zone 'Europe/Zurich')::date + time '07:10') at time zone 'Europe/Zurich',
   'Synthetisch: Klientin am Morgen müde, trinkt wenig', true, '00000000-0000-4000-a000-000000000963'),
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000562', '00000000-0000-4000-a000-000000000261',
   '00000000-0000-4000-a000-000000000161', '00000000-0000-4000-a000-000000000960',
   ((private.now() at time zone 'Europe/Zurich')::date + time '07:20') at time zone 'Europe/Zurich',
   'Synthetisch: Haut an den Fersen intakt', false, '00000000-0000-4000-a000-000000000964');
update public.team_memberships set qualification = 'care_assistant'
where team_id = '00000000-0000-4000-a000-000000000161' and user_id = '00000000-0000-4000-a000-000000000962';
-- F7: completion opened the draft (as complete_visit does); the draft shows the facts fresh until she signs.
insert into public.visit_reports (organization_id, visit_id, case_id, team_id, version, status, snapshot, summary,
                                  performer_id, countersign_required, created_by) values
  ('00000000-0000-4000-b000-000000000013', '00000000-0000-4000-a000-000000000562', '00000000-0000-4000-a000-000000000261',
   '00000000-0000-4000-a000-000000000161', 1, 'draft', private.visit_report_snapshot('00000000-0000-4000-a000-000000000562'), null,
   '00000000-0000-4000-a000-000000000960', false, '00000000-0000-4000-a000-000000000960');

-- ASM1-6 (migration 0100, ADR-123): the instrument reference list of Testorganisation A. Synthetic names only: no real
-- instrument is named, none is designated (D-37). "Testmarke HC" stands for a name that is a third party's mark, so the
-- list shows it as such (D-36 A). "Testinstrument alt" ended before today (an entry valid only in its period).
-- No assessment record is seeded: the e2e (asm1.spec) and pgTAP 100 write their own through the commands.
insert into public.assessment_instruments (id, organization_id, name, version, valid_from, valid_to, third_party_mark, created_by) values
  ('00000000-0000-4000-a000-000000000971', '00000000-0000-4000-b000-000000000011', 'Testinstrument Bedarf', '1.0', date '2020-01-01', null, false,
   '00000000-0000-4000-a000-000000000905'),
  ('00000000-0000-4000-a000-000000000972', '00000000-0000-4000-b000-000000000011', 'Testmarke HC', '9.1', date '2020-01-01', null, true,
   '00000000-0000-4000-a000-000000000905'),
  ('00000000-0000-4000-a000-000000000973', '00000000-0000-4000-b000-000000000011', 'Testinstrument alt', '0.9', date '2019-01-01', date '2020-12-31', false,
   '00000000-0000-4000-a000-000000000905');

-- UX2-22 / UX2-23 (e2e ux2-gates.spec, ADR-124): Testorganisation D, its own organisation, so no org-A, org-B or org-C
-- fixture or count changes. All synthetic.
--   admind.test   (…980): administrator of Testorganisation D; team admission is on for D (as set_team_admission
--                          would write it), so /admin shows the switch and the contract-end controls (UX2-23).
--   ohnequal.test (…981): member of Testteam D admitted by her team; "Vertrag erfasst", qualification not yet recorded
--                          (the ADM2-6 state). She signs in: /field offers her no depart, start or completion control and
--                          "Offen im Team" shows one line (UX2-22). The only seeded member without a qualification
--                          (pgTAP 018 names her).
--   vertragd.test (…982): registered nurse of Testteam D whose contract ends in 30 days (UX2-23 "Vertragsende entfernen");
--                          never signs in (no password, e-mail unconfirmed, no identity row).
-- One planned visit of Testfall D1 today at 21:00 with nobody responsible: on her day and in "Offen im Team".
-- Written as the table owner, in the order the commands would write it.
insert into public.organizations (id, name) values ('00000000-0000-4000-b000-000000000014', 'Testorganisation D');
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000171', private.now() - interval '200 days', 'Testteam D', 'Bern Ost', 'Ambulante Pflege', 'active', 2, 60, 'Leitung Test D', 'Keine Massnahme', false, null);
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id, needs_assessment_done_at) values
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000271', private.now() - interval '100 days', 'Testfall D1', 'Testfall', 'D1', 'Bern Ost', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam D', '00000000-0000-4000-a000-000000000171', private.now() - interval '99 days');
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000980', 'authenticated', 'authenticated',
   'admind.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000981', 'authenticated', 'authenticated',
   'ohnequal.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000982', 'authenticated', 'authenticated',
   'vertragd.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  ('00000000-0000-4000-a000-000000000990', '00000000-0000-4000-a000-000000000980', '00000000-0000-4000-a000-000000000980',
   '{"sub":"00000000-0000-4000-a000-000000000980","email":"admind.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-000000000991', '00000000-0000-4000-a000-000000000981', '00000000-0000-4000-a000-000000000981',
   '{"sub":"00000000-0000-4000-a000-000000000981","email":"ohnequal.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now());
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000980', 'admin'),
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000981', 'nurse'),
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000982', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000171', '00000000-0000-4000-a000-000000000981', null),
  ('00000000-0000-4000-a000-000000000171', '00000000-0000-4000-a000-000000000982', 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000980', 'Administration Test D', '00000000-0000-4000-a000-000000000980'),
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000981', 'Neues Teammitglied D', '00000000-0000-4000-a000-000000000980'),
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000982', 'Pflegekraft Vertrag D', '00000000-0000-4000-a000-000000000980');
insert into public.team_admission_settings (organization_id, enabled, updated_by) values
  ('00000000-0000-4000-b000-000000000014', true, '00000000-0000-4000-a000-000000000980');
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id, created_at) values
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000981',
   (private.now() at time zone 'Europe/Zurich')::date - 1, null,
   '00000000-0000-4000-a000-000000000980', private.now() - interval '1 day'),
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000982',
   (private.now() at time zone 'Europe/Zurich')::date - 100, (private.now() at time zone 'Europe/Zurich')::date + 30,
   '00000000-0000-4000-a000-000000000980', private.now() - interval '30 days');
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, responsible_user_id) values
  ('00000000-0000-4000-b000-000000000014', '00000000-0000-4000-a000-000000000572', private.now() - interval '2 days',
   '00000000-0000-4000-a000-000000000271', '00000000-0000-4000-a000-000000000171',
   (private.now() at time zone 'Europe/Zurich')::date, '21:00', '21:30', array['Grundpflege'], false, 'planned', 30, null);

-- AIG1 part (b) (e2e aig1.spec, ADR-129): the proposal screens on synthetic data only. Two organisations of their own,
-- so no org-A to org-D fixture or count changes; the synthetic test agent `aig1_test_primary_nurse` (rule, level L,
-- migration 0097) is the only agent. Written as the table owner, in the order the commands would write it.
--
-- Testorganisation E: the agent is on (as set_agent_state would write it; threshold written by the switch-on, a test
-- value, not a NAVORA default). Eight open proposals of Testteam E for tomorrow, none decided:
--   teame.test (…9a1): registered nurse of Testteam E who signs in and confirms at 390 px (AIG1-3/-4/-5).
--   bezuge     (…9a2): registered nurse of Testteam E, primary nurse of Testfall E1, the proposed value; never signs in.
--   visits …5a1-…5a6 (Testfall E1, nobody responsible): the agent proposes Bezug E (schedule field, bulk-eligible).
--   visit  …5a7 (Testfall E2, no primary nurse): the agent found no value ("nicht gefunden", AIG1-4).
--   assiste   (…9a3): care assistant of Testteam E, primary nurse of Testfall E3; never signs in.
--   visit  …5a8 (Testfall E3, 14:00, category B minutes): the agent proposes Assistenz E; a ticked confirm refuses it
--                not_qualified and keeps the reason on its line (AIG1-C3 (2), UXR-66).
insert into public.organizations (id, name) values ('00000000-0000-4000-b000-000000000015', 'Testorganisation E');
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-000000000181', private.now() - interval '200 days', 'Testteam E', 'Bern Ost', 'Ambulante Pflege', 'active', 2, 60, 'Leitung Test E', 'Keine Massnahme', false, null);
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id, needs_assessment_done_at) values
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-000000000281', private.now() - interval '100 days', 'Testfall E1', 'Testfall', 'E1', 'Bern Ost', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam E', '00000000-0000-4000-a000-000000000181', private.now() - interval '99 days'),
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-000000000282', private.now() - interval '100 days', 'Testfall E2', 'Testfall', 'E2', 'Bern Ost', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam E', '00000000-0000-4000-a000-000000000181', private.now() - interval '99 days'),
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-000000000283', private.now() - interval '100 days', 'Testfall E3', 'Testfall', 'E3', 'Bern Ost', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam E', '00000000-0000-4000-a000-000000000181', private.now() - interval '99 days');
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009a1', 'authenticated', 'authenticated',
   'teame.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009a2', 'authenticated', 'authenticated',
   'bezuge.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009a3', 'authenticated', 'authenticated',
   'assiste.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  ('00000000-0000-4000-a000-0000000009b1', '00000000-0000-4000-a000-0000000009a1', '00000000-0000-4000-a000-0000000009a1',
   '{"sub":"00000000-0000-4000-a000-0000000009a1","email":"teame.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now());
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-0000000009a1', 'nurse'),
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-0000000009a2', 'nurse'),
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-0000000009a3', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000181', '00000000-0000-4000-a000-0000000009a1', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000181', '00000000-0000-4000-a000-0000000009a2', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000181', '00000000-0000-4000-a000-0000000009a3', 'care_assistant');
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-0000000009a1', 'Pflegekraft Team E', '00000000-0000-4000-a000-0000000009a1'),
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-0000000009a2', 'Pflegekraft Bezug E', '00000000-0000-4000-a000-0000000009a1'),
  ('00000000-0000-4000-b000-000000000015', '00000000-0000-4000-a000-0000000009a3', 'Pflegekraft Assistenz E', '00000000-0000-4000-a000-0000000009a1');
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-0000000009a2'
where id = '00000000-0000-4000-a000-000000000281';
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-0000000009a3'
where id = '00000000-0000-4000-a000-000000000283';
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000015', v.id::uuid, private.now() - interval '2 days', v.case_id::uuid,
       '00000000-0000-4000-a000-000000000181', (private.now() at time zone 'Europe/Zurich')::date + 1,
       v.t0::time, v.t0::time + interval '30 minutes', array['Grundpflege'], false, 'planned',
       case when v.t0 = '14:00' then 0 else 30 end, case when v.t0 = '14:00' then 30 else 0 end, null
from (values ('00000000-0000-4000-a000-0000000005a1', '00000000-0000-4000-a000-000000000281', '08:00'),
             ('00000000-0000-4000-a000-0000000005a2', '00000000-0000-4000-a000-000000000281', '09:00'),
             ('00000000-0000-4000-a000-0000000005a3', '00000000-0000-4000-a000-000000000281', '10:00'),
             ('00000000-0000-4000-a000-0000000005a4', '00000000-0000-4000-a000-000000000281', '11:00'),
             ('00000000-0000-4000-a000-0000000005a5', '00000000-0000-4000-a000-000000000281', '12:00'),
             ('00000000-0000-4000-a000-0000000005a6', '00000000-0000-4000-a000-000000000281', '13:00'),
             ('00000000-0000-4000-a000-0000000005a8', '00000000-0000-4000-a000-000000000283', '14:00'),
             ('00000000-0000-4000-a000-0000000005a7', '00000000-0000-4000-a000-000000000282', '15:00')) v(id, case_id, t0);
insert into public.ai_agent_settings (organization_id, agent_key, state, stop_share, stop_min_proposals, stop_window_days,
                                      switched_on_by, switched_on_at, on_version, on_provider, on_region)
select '00000000-0000-4000-b000-000000000015', d.key, 'on', 50, 10, 30, '00000000-0000-4000-a000-0000000009a1',
       private.now() - interval '1 day', d.version, d.provider, d.region
from public.ai_agent_definitions d where d.key = 'aig1_test_primary_nurse';
insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                   entity_type, entity_id, input_refs, not_found, proposed_value, created_at)
select gen_random_uuid(), v.organization_id, v.team_id, v.case_id, d.key, d.version, 'responsible_user_id',
       'care_visits', v.id,
       jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', v.id), jsonb_build_object('table', 'cases', 'id', v.case_id)),
       c.primary_nurse_id is null,
       case when c.primary_nurse_id is null then null else to_jsonb(c.primary_nurse_id::text) end,
       private.now() - interval '2 hours'
from public.care_visits v
join public.cases c on c.id = v.case_id
cross join public.ai_agent_definitions d
where v.team_id = '00000000-0000-4000-a000-000000000181' and d.key = 'aig1_test_primary_nurse'
order by v.time_start;

-- Testorganisation F: the agent stopped by its threshold (AIG1-8, -10, -12, -13, -14, -16). Switched on 10 days ago
-- with a written threshold of 20 % over at least 5 decided proposals in a 7-day window (test values). In that window
-- six proposals were decided: four confirmed unchanged, two corrected (share 33.33 % > 20 %, minimum reached), so the
-- stop check stopped it at the window's end (as private.aig1_stop would write it). Afterwards the value of one of the
-- four was replaced, so its look-back line reads "überholt am <Datum>" (AIG1-13 (b)).
-- AIG1-C1 / AIG1-C2 (ADR-130): of the three lines still holding their value, visit …5b1 is dated yesterday (no longer
-- open: "Besuch nicht mehr offen", counted apart), …5b2 is open with a valid member (re-confirmed in e2e), and …5b3
-- (Testfall F2, category B minutes) holds a member whose qualification was changed to care assistant after the stop
-- (re-confirmation refused not_qualified).
-- The stop has a fixed id so the team member's e2e opens its look-back list directly (her team's entry point is PLAN3-11).
--   opsf.test (…9c1): operations of Testorganisation F who signs in (health list, OPS1 exception, look-back list).
--   bestf     (…9c2): registered nurse of Testteam F who confirmed the six values; her name must never appear on the
--                     look-back list (AIG1-14). Never signs in.
--   bezugf    (…9c3): registered nurse, primary nurse of Testfall F1, the proposed value. Never signs in.
--   anderf    (…9c4): registered nurse, the corrected value and the later replacement. Never signs in.
--   teamf.test(…9c5): registered nurse of Testteam F who signs in at 390 px (AIG1-C2: re-confirm on the record page).
--   assistf   (…9c6): primary nurse of Testfall F2, the value of …5b3; registered nurse at the confirmation, recorded as
--                     care assistant after the stop (so she may no longer perform …5b3's category B minutes).
insert into public.organizations (id, name) values ('00000000-0000-4000-b000-000000000016', 'Testorganisation F');
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-000000000191', private.now() - interval '200 days', 'Testteam F', 'Bern Ost', 'Ambulante Pflege', 'active', 2, 60, 'Leitung Test F', 'Keine Massnahme', false, null);
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id, needs_assessment_done_at) values
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-000000000291', private.now() - interval '100 days', 'Testfall F1', 'Testfall', 'F1', 'Bern Ost', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam F', '00000000-0000-4000-a000-000000000191', private.now() - interval '99 days'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-000000000292', private.now() - interval '100 days', 'Testfall F2', 'Testfall', 'F2', 'Bern Ost', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Testteam F', '00000000-0000-4000-a000-000000000191', private.now() - interval '99 days');
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009c1', 'authenticated', 'authenticated',
   'opsf.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009c2', 'authenticated', 'authenticated',
   'bestf.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009c3', 'authenticated', 'authenticated',
   'bezugf.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009c4', 'authenticated', 'authenticated',
   'anderf.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009c5', 'authenticated', 'authenticated',
   'teamf.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), private.now(),
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000009c6', 'authenticated', 'authenticated',
   'assistf.test@navora.test', '', null,
   '{"provider":"email","providers":["email"]}', '{}', private.now(), private.now(), '', '', '', '');
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  ('00000000-0000-4000-a000-0000000009d1', '00000000-0000-4000-a000-0000000009c1', '00000000-0000-4000-a000-0000000009c1',
   '{"sub":"00000000-0000-4000-a000-0000000009c1","email":"opsf.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now()),
  ('00000000-0000-4000-a000-0000000009d5', '00000000-0000-4000-a000-0000000009c5', '00000000-0000-4000-a000-0000000009c5',
   '{"sub":"00000000-0000-4000-a000-0000000009c5","email":"teamf.test@navora.test","email_verified":true}', 'email', private.now(), private.now(), private.now());
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c1', 'operations'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c2', 'nurse'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c3', 'nurse'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c4', 'nurse'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c5', 'nurse'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c6', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000191', '00000000-0000-4000-a000-0000000009c2', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000191', '00000000-0000-4000-a000-0000000009c3', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000191', '00000000-0000-4000-a000-0000000009c4', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000191', '00000000-0000-4000-a000-0000000009c5', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000191', '00000000-0000-4000-a000-0000000009c6', 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c1', 'Operations Test F', '00000000-0000-4000-a000-0000000009c1'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c2', 'Pflegekraft Bestätigt F', '00000000-0000-4000-a000-0000000009c1'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c3', 'Pflegekraft Bezug F', '00000000-0000-4000-a000-0000000009c1'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c4', 'Pflegekraft Andere F', '00000000-0000-4000-a000-0000000009c1'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c5', 'Pflegekraft Team F', '00000000-0000-4000-a000-0000000009c1'),
  ('00000000-0000-4000-b000-000000000016', '00000000-0000-4000-a000-0000000009c6', 'Pflegekraft Assistenz F', '00000000-0000-4000-a000-0000000009c1');
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-0000000009c3'
where id = '00000000-0000-4000-a000-000000000291';
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-0000000009c6'
where id = '00000000-0000-4000-a000-000000000292';
-- Six visits, …5b1 yesterday and the others in the coming days; each holds the value its confirmation applied (…5b1,
-- …5b2, …5b4 the proposed primary nurse of Testfall F1, …5b3 that of Testfall F2, …5b5 and …5b6 the corrected one).
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000016', v.id::uuid, private.now() - interval '9 days',
       case when v.id = '00000000-0000-4000-a000-0000000005b3' then '00000000-0000-4000-a000-000000000292'
            else '00000000-0000-4000-a000-000000000291' end::uuid,
       '00000000-0000-4000-a000-000000000191', (private.now() at time zone 'Europe/Zurich')::date + v.d,
       time '09:00', time '09:30', array['Grundpflege'], false, 'planned',
       case when v.id = '00000000-0000-4000-a000-0000000005b3' then 0 else 30 end,
       case when v.id = '00000000-0000-4000-a000-0000000005b3' then 30 else 0 end, v.who::uuid
from (values ('00000000-0000-4000-a000-0000000005b1', -1, '00000000-0000-4000-a000-0000000009c3'),
             ('00000000-0000-4000-a000-0000000005b2', 2, '00000000-0000-4000-a000-0000000009c3'),
             ('00000000-0000-4000-a000-0000000005b3', 3, '00000000-0000-4000-a000-0000000009c6'),
             ('00000000-0000-4000-a000-0000000005b4', 4, '00000000-0000-4000-a000-0000000009c3'),
             ('00000000-0000-4000-a000-0000000005b5', 5, '00000000-0000-4000-a000-0000000009c4'),
             ('00000000-0000-4000-a000-0000000005b6', 6, '00000000-0000-4000-a000-0000000009c4')) v(id, d, who);
insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                   entity_type, entity_id, input_refs, not_found, proposed_value, created_at)
select gen_random_uuid(), v.organization_id, v.team_id, v.case_id, d.key, d.version, 'responsible_user_id',
       'care_visits', v.id,
       jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', v.id), jsonb_build_object('table', 'cases', 'id', v.case_id)),
       false, to_jsonb(c.primary_nurse_id::text), private.now() - interval '9 days'
from public.care_visits v join public.cases c on c.id = v.case_id cross join public.ai_agent_definitions d
where v.team_id = '00000000-0000-4000-a000-000000000191' and d.key = 'aig1_test_primary_nurse'
order by v.visit_date;
insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, confirmed_by, confirmed_at)
select s.id, s.organization_id, s.team_id,
       case when to_jsonb(v.responsible_user_id::text) = s.proposed_value then 'confirmed' else 'corrected' end,
       to_jsonb(v.responsible_user_id::text), '00000000-0000-4000-a000-0000000009c2', private.now() - interval '9 days' + interval '1 hour'
from public.ai_suggestions s join public.care_visits v on v.id = s.entity_id
where s.team_id = '00000000-0000-4000-a000-000000000191'
order by s.seq;
insert into public.ai_agent_stops (id, organization_id, agent_key, reason, window_from, window_to, decided, share,
                                   suggestion_seq, confirmation_seq, created_at)
values ('00000000-0000-4000-a000-0000000006f1', '00000000-0000-4000-b000-000000000016', 'aig1_test_primary_nurse', 'threshold',
        private.now() - interval '10 days', private.now() - interval '3 days', 6, 33.33,
        (select max(seq) from public.ai_suggestions), (select max(seq) from public.ai_confirmations),
        private.now() - interval '3 days' + interval '1 hour');
insert into public.ai_agent_settings (organization_id, agent_key, state, stop_share, stop_min_proposals, stop_window_days,
                                      switched_on_by, switched_on_at, on_version, on_provider, on_region, last_stop_id)
select '00000000-0000-4000-b000-000000000016', d.key, 'stopped', 20, 5, 7, '00000000-0000-4000-a000-0000000009c1',
       private.now() - interval '10 days', d.version, d.provider, d.region,
       (select st.id from public.ai_agent_stops st where st.organization_id = '00000000-0000-4000-b000-000000000016')
from public.ai_agent_definitions d where d.key = 'aig1_test_primary_nurse';
-- After the stop the team gave visit …5b4 to another member (audited as a responsible_user_id change, AIG1-13 (b)).
update public.care_visits set responsible_user_id = '00000000-0000-4000-a000-0000000009c4'
where id = '00000000-0000-4000-a000-0000000005b4';
-- After the stop Pflegekraft Assistenz F was recorded as care assistant (AIG1-C2 e2e: not_qualified for the
-- category B visit …5b3). No member is left without a qualification (pgTAP 018: null only on the ADM2 path).
update public.team_memberships set qualification = 'care_assistant'
where team_id = '00000000-0000-4000-a000-000000000191' and user_id = '00000000-0000-4000-a000-0000000009c6';
