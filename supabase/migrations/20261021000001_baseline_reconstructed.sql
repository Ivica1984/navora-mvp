-- =============================================================================
-- NAVORA baseline schema — RECONSTRUCTED, VERIFY AGAINST LIVE
-- =============================================================================
-- Source: columns selected by the recovered code (src/features/*/queries.ts),
-- foreign keys and match_candidates columns from DATABASE_AND_DATA_MODEL.md.
-- Column types are inferred where the code gives no type information.
--
-- Deliberately NOT reconstructed (no evidence of shape or not used by code):
--   * public.orders                      — purpose UNKNOWN (backlog O4)
--   * PostGIS location columns, private.calculate_case_team_distance_km,
--     private.geocoding_jobs             — documented, not used by the app
--
-- When the owner's schema-only pull of the live project arrives (O1), it
-- replaces this file through a reviewed PR (ADR-008).
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

-- teams ----------------------------------------------------------------------
create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  name        text not null,
  region      text,
  care_focus  text,
  status      text,                      -- legacy values: active | building | paused | closed
  open_slots  integer,
  utilization integer,                   -- percent
  lead_name   text,
  next_step   text,
  priority    boolean default false,     -- "Coach-Fokus"
  coach_name  text
);

-- cases ----------------------------------------------------------------------
create table public.cases (
  id                      uuid primary key default gen_random_uuid(),
  created_at              timestamptz not null default now(),
  name                    text,
  region                  text,
  status                  text,          -- legacy values: neu | teampruefung | laufend
  bedarf                  text,
  urgency                 text,          -- legacy values: niedrig | mittel | hoch
  time_info               text,
  first_name              text,
  last_name               text,
  date_of_birth           date,
  gender                  text,
  address                 text,
  plz                     text,
  ort                     text,
  phone                   text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  mobility_status         text,
  cognitive_status        text,
  diagnosis_tags          text[],
  care_needs              text[],
  care_level              text,
  referral_source         text,
  insurance_provider      text,
  start_date              date,
  next_step               text,
  notes                   text,
  assigned_team           text,          -- legacy free-text team name
  assigned_team_id        uuid references public.teams (id)
);

-- partner_requests -----------------------------------------------------------
create table public.partner_requests (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  partner_name       text not null,
  partner_type       text,
  region             text not null,
  city               text,
  urgency            text not null,
  time_info          text,
  request_title      text not null,
  need_summary       text not null,
  requested_services text[],
  status             text not null default 'open',  -- open | ready_to_convert | converted | ...
  converted_case_id  uuid references public.cases (id),
  notes              text
);

-- matching_requests ----------------------------------------------------------
create table public.matching_requests (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  case_id           uuid references public.cases (id),
  request_title     text not null,
  region            text not null,
  urgency           text not null,
  required_services text[],
  status            text not null default 'open',
  selected_team_id  uuid references public.teams (id),
  notes             text
);

-- match_candidates (columns from documented screenshot) ----------------------
create table public.match_candidates (
  id                  uuid primary key default gen_random_uuid(),
  created_at          timestamptz not null default now(),
  matching_request_id uuid references public.matching_requests (id),
  team_id             uuid references public.teams (id),
  fit_score           integer default 0,
  distance_km         numeric,
  utilization         integer,
  open_slots          integer,
  reasons             text[] default '{}',
  status              text default 'suggested'
);

-- care_visits ----------------------------------------------------------------
create table public.care_visits (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  case_id           uuid references public.cases (id),
  team_id           uuid references public.teams (id),
  visit_date        date,
  time_start        time,
  time_end          time,
  team_member_name  text,
  services_provided text[],
  notes             text,
  billable          boolean default false,
  status            text default 'planned'
);

-- care_notes -----------------------------------------------------------------
create table public.care_notes (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  visit_id    uuid references public.care_visits (id),
  case_id     uuid references public.cases (id),
  team_id     uuid references public.teams (id),
  author_name text,
  note_type   text not null,
  content     text not null,
  status      text not null default 'draft'   -- draft | submitted | approved | ...
);

-- quality_events -------------------------------------------------------------
create table public.quality_events (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  case_id     uuid references public.cases (id),
  visit_id    uuid references public.care_visits (id),
  team_id     uuid references public.teams (id),
  event_type  text not null,
  severity    text not null,                  -- low | medium | high | critical
  title       text not null,
  description text,
  status      text not null default 'open'
);

-- Indexes on foreign keys (absent in the documented live state; harmless additions)
create index on public.cases (assigned_team_id);
create index on public.partner_requests (converted_case_id);
create index on public.matching_requests (case_id);
create index on public.matching_requests (selected_team_id);
create index on public.match_candidates (matching_request_id);
create index on public.match_candidates (team_id);
create index on public.care_visits (case_id);
create index on public.care_visits (team_id);
create index on public.care_notes (visit_id);
create index on public.care_notes (case_id);
create index on public.care_notes (team_id);
create index on public.quality_events (case_id);
create index on public.quality_events (visit_id);
create index on public.quality_events (team_id);

-- RLS on, matching the documented live state. Policies follow in 0002.
alter table public.teams             enable row level security;
alter table public.cases             enable row level security;
alter table public.partner_requests  enable row level security;
alter table public.matching_requests enable row level security;
alter table public.match_candidates  enable row level security;
alter table public.care_visits       enable row level security;
alter table public.care_notes        enable row level security;
alter table public.quality_events    enable row level security;
