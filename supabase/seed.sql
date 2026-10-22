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

-- Organisations (T9) ------------------------------------------------------------
-- A holds all synthetic care data. B exists only to prove tenant isolation.
insert into public.organizations (id, name) values
  ('00000000-0000-4000-b000-000000000011', 'Testorganisation A'),
  ('00000000-0000-4000-b000-000000000012', 'Testorganisation B');

-- Teams ----------------------------------------------------------------------
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101', now() - interval '90 days', 'Testteam Nord',  'Bern West',    'Ambulante Pflege', 'active',   0, 95, 'Leitung Test A', 'Kapazität klären',     true,  'Coach Test 1'), -- P1 overload
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000102', now() - interval '80 days', 'Testteam Mitte', 'Bern West',    'Ambulante Pflege', 'active',   2, 84, 'Leitung Test B', 'Einsatzplan prüfen',   false, null),           -- P2 utilization >= 80
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000103', now() - interval '70 days', 'Testteam Süd',   'Zürich Pilot', 'Übergangspflege',  'building', 1, 55, 'Leitung Test C', 'Onboarding',           false, 'Coach Test 2'), -- P2 open_slots <= 1
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000104', now() - interval '60 days', 'Testteam West',  'Zürich Pilot', 'Ambulante Pflege', 'active',   4, 60, 'Leitung Test D', 'Keine Massnahme',      false, 'Coach Test 2'), -- no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000105', now() - interval '50 days', 'Testteam Ost',   'Basel Pilot',  'Übergangspflege',  'active',   5, 40, 'Leitung Test E', 'Keine Massnahme',      false, null);           -- third region (TD-13), no attention

-- Cases ----------------------------------------------------------------------
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000201', now() - interval '2 hours',  'Testfall 01', 'Testfall', '01', 'Bern West',    'neu',          'hoch',    'Grundpflege',     array['Grundpflege'],                'Team anfragen',       null, null),                                     -- P1: no team, urgency hoch
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000202', now() - interval '3 hours',  'Testfall 02', 'Testfall', '02', 'Zürich Pilot', 'neu',          'mittel',  'Medikamentengabe', array['Medikamentengabe'],          'Team anfragen',       null, null),                                     -- P2: no team, fresh
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000203', now() - interval '30 hours', 'Testfall 03', 'Testfall', '03', 'Bern West',    'neu',          'niedrig', 'Hauswirtschaft',  array['Hauswirtschaft'],             'Team anfragen',       null, null),                                     -- P1: no team >= 24 h; SLA risk
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000204', now() - interval '60 hours', 'Testfall 04', 'Testfall', '04', 'Zürich Pilot', 'neu',          'mittel',  'Wundversorgung',  array['Wundversorgung'],             'Team anfragen',       null, null),                                     -- P1: no team; SLA violated (>48 h)
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000205', now() - interval '30 hours', 'Testfall 05', 'Testfall', '05', 'Bern West',    'teampruefung', 'mittel',  'Grundpflege',     array['Grundpflege', 'Mobilisation'], 'Teamentscheid',       'Testteam Mitte', '00000000-0000-4000-a000-000000000102'), -- P1: Teamentscheid >= 24 h
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000206', now() - interval '4 hours',  'Testfall 06', 'Testfall', '06', 'Zürich Pilot', 'teampruefung', 'niedrig', 'Begleitung',      array['Begleitung'],                 'Teamentscheid',       'Testteam Süd',   '00000000-0000-4000-a000-000000000103'), -- P2: Teamentscheid fresh
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000207', now() - interval '5 hours',  'Testfall 07', 'Testfall', '07', 'Bern West',    'teampruefung', 'mittel',  'Grundpflege',     array['Grundpflege'],                'Teamentscheid',       null, null),                                     -- duplicate pair: no team AND teampruefung (TD-09)
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', now() - interval '20 days',  'Testfall 08', 'Testfall', '08', 'Bern West',    'laufend',      'mittel',  'Grundpflege',     array['Grundpflege'],                'Laufende Versorgung', 'Testteam Nord',  '00000000-0000-4000-a000-000000000101'), -- no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000209', now() - interval '15 days',  'Testfall 09', 'Testfall', '09', 'Zürich Pilot', 'laufend',      'niedrig', 'Medikamentengabe', array['Medikamentengabe'],          'Laufende Versorgung', 'Testteam West',  '00000000-0000-4000-a000-000000000104'), -- no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000210', now() - interval '10 days',  'Testfall 10', 'Testfall', '10', 'Bern West',    'laufend',      'hoch',    'Wundversorgung',  array['Wundversorgung'],             'Laufende Versorgung', 'Testteam Mitte', '00000000-0000-4000-a000-000000000102'); -- no attention

-- Partner requests -----------------------------------------------------------
insert into public.partner_requests (organization_id, id, created_at, partner_name, partner_type, region, city, urgency, time_info, request_title, need_summary, requested_services, status, converted_case_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000301', now() - interval '1 hour',   'Testpartner A', 'Spital',       'Bern West',    'Teststadt', 'hoch',    'Heute', 'Austritt Testfall', 'Synthetischer Bedarf A', array['Grundpflege'], 'open',             null), -- P1 urgent
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000302', now() - interval '2 hours',  'Testpartner B', 'Pflegeheim',   'Zürich Pilot', 'Teststadt', 'mittel',  '48h',   'Übergang Test',     'Synthetischer Bedarf B', array['Begleitung'],  'ready_to_convert', null), -- P2 fresh
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000303', now() - interval '36 hours', 'Testpartner C', 'Hausarzt',     'Bern West',    'Teststadt', 'niedrig', 'Woche', 'Abklärung Test',    'Synthetischer Bedarf C', null,                 'open',             null), -- P1 >= 24 h
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000304', now() - interval '5 days',   'Testpartner D', 'Spital',       'Bern West',    'Teststadt', 'mittel',  null,    'Erledigt Test',     'Synthetischer Bedarf D', null,                 'converted',        '00000000-0000-4000-a000-000000000208'); -- no attention

-- Matching request (read by Operations, not acted on) -----------------------
insert into public.matching_requests (organization_id, id, created_at, case_id, request_title, region, urgency, required_services, status, selected_team_id) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000401', now() - interval '4 hours', '00000000-0000-4000-a000-000000000206', 'Teamsuche Testfall 06', 'Zürich Pilot', 'niedrig', array['Begleitung'], 'open', null);

-- Care visits ----------------------------------------------------------------
insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end, team_member_name, services_provided, notes, billable, status) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000501', now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', current_date,     '08:00', '08:45', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000502', now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', current_date,     '10:00', '10:30', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'started'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000503', now() - interval '1 day', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', current_date,     '11:00', '11:30', 'Pflegekraft Test 2', array['Medikamentengabe'], null,                false, 'on_the_way'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000504', now() - interval '2 days', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', current_date - 1, '09:00', '09:30', 'Pflegekraft Test 2', array['Medikamentengabe'], 'Synthetische Notiz', false, 'completed'), -- approved note → no attention
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000505', now() - interval '2 days', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', current_date - 1, '14:00', '14:45', 'Pflegekraft Test 3', array['Wundversorgung'],   null,                false, 'completed'), -- no note → P2
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000506', now() - interval '2 days', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', current_date - 1, '16:00', '16:30', 'Pflegekraft Test 3', array['Wundversorgung'],   null,                false, 'completed'), -- draft note → P2
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000507', now() - interval '3 days', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', current_date - 2, '08:00', '08:30', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'cancelled'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000508', now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', current_date + 1, '09:00', '09:45', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'planned'), -- F2 e2e: full field path tomorrow
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000509', now() - interval '1 day', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', current_date + 2, '18:00', '18:30', 'Pflegekraft Test 1', array['Grundpflege'],      null,                false, 'planned'); -- F7 e2e: run by the care assistant, countersigned by the nurse

-- Care notes -----------------------------------------------------------------
insert into public.care_notes (organization_id, id, created_at, visit_id, case_id, team_id, author_name, note_type, content, status) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000601', now() - interval '1 day', '00000000-0000-4000-a000-000000000504', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', 'Pflegekraft Test 2', 'visit_report', 'Synthetischer Bericht.', 'approved'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000602', now() - interval '1 day', '00000000-0000-4000-a000-000000000506', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', 'Pflegekraft Test 3', 'visit_report', 'Synthetischer Entwurf.', 'draft');

-- Quality events -------------------------------------------------------------
insert into public.quality_events (organization_id, id, created_at, case_id, visit_id, team_id, event_type, severity, title, description, status) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000701', now() - interval '6 hours', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000505', '00000000-0000-4000-a000-000000000102', 'documentation', 'high', 'Testereignis hoch',    'Synthetisches Ereignis.', 'open'),   -- P1
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000702', now() - interval '1 day',   '00000000-0000-4000-a000-000000000208', null,                                   '00000000-0000-4000-a000-000000000101', 'process',       'low',  'Testereignis niedrig', null,                       'open'),   -- P2
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000703', now() - interval '5 days',  '00000000-0000-4000-a000-000000000209', null,                                   '00000000-0000-4000-a000-000000000104', 'process',       'medium', 'Testereignis erledigt', null,                    'closed'); -- no attention

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
   'coach.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000902', 'authenticated', 'authenticated',
   'pflege.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000903', 'authenticated', 'authenticated',
   'fremd.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000904', 'authenticated', 'authenticated',
   'ops.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000905', 'authenticated', 'authenticated',
   'admin.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000906', 'authenticated', 'authenticated',
   'assist.test@navora.test', extensions.crypt('navora-local-only', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  ('00000000-0000-4000-a000-000000000911', '00000000-0000-4000-a000-000000000901', '00000000-0000-4000-a000-000000000901',
   '{"sub":"00000000-0000-4000-a000-000000000901","email":"coach.test@navora.test","email_verified":true}', 'email', now(), now(), now()),
  ('00000000-0000-4000-a000-000000000912', '00000000-0000-4000-a000-000000000902', '00000000-0000-4000-a000-000000000902',
   '{"sub":"00000000-0000-4000-a000-000000000902","email":"pflege.test@navora.test","email_verified":true}', 'email', now(), now(), now()),
  ('00000000-0000-4000-a000-000000000913', '00000000-0000-4000-a000-000000000903', '00000000-0000-4000-a000-000000000903',
   '{"sub":"00000000-0000-4000-a000-000000000903","email":"fremd.test@navora.test","email_verified":true}', 'email', now(), now(), now()),
  ('00000000-0000-4000-a000-000000000914', '00000000-0000-4000-a000-000000000904', '00000000-0000-4000-a000-000000000904',
   '{"sub":"00000000-0000-4000-a000-000000000904","email":"ops.test@navora.test","email_verified":true}', 'email', now(), now(), now()),
  ('00000000-0000-4000-a000-000000000915', '00000000-0000-4000-a000-000000000905', '00000000-0000-4000-a000-000000000905',
   '{"sub":"00000000-0000-4000-a000-000000000905","email":"admin.test@navora.test","email_verified":true}', 'email', now(), now(), now()),
  ('00000000-0000-4000-a000-000000000916', '00000000-0000-4000-a000-000000000906', '00000000-0000-4000-a000-000000000906',
   '{"sub":"00000000-0000-4000-a000-000000000906","email":"assist.test@navora.test","email_verified":true}', 'email', now(), now(), now());

-- Testorganisation B (T9) — isolation fixture --------------------------------
-- Same region name as org A on purpose: isolation must come from the
-- organisation, not from a different region filter.
insert into public.teams (organization_id, id, created_at, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, priority, coach_name) values
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000151', now() - interval '30 days', 'Fremdteam B', 'Bern West', 'Ambulante Pflege', 'active', 3, 70, 'Leitung Fremd', 'Keine Massnahme', false, 'Coach Fremd');

insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id) values
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000251', now() - interval '3 days', 'Testfall B1', 'Testfall', 'B1', 'Bern West', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'Fremdteam B', '00000000-0000-4000-a000-000000000151');

insert into public.care_visits (organization_id, id, created_at, case_id, team_id, visit_date, time_start, time_end, team_member_name, services_provided, notes, billable, status) values
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000551', now() - interval '1 day', '00000000-0000-4000-a000-000000000251', '00000000-0000-4000-a000-000000000151', current_date, '09:00', '09:30', 'Pflegekraft Fremd', array['Grundpflege'], null, false, 'planned');

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
