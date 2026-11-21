# NAVORA — Platform map (domains, dependencies, implementation state)

**Date:** 2026-10-21 · **Basis:** `ARCHITECTURE.md` (bounded contexts, data flow, target model), `MASTER_CONTEXT.md`, `PRODUCT_REQUIREMENTS.md`, `DOMAIN_RULES.md`, `INTEGRATIONS.md`, and the code on `recovery/main` plus open PRs.
**Limit:** the *Architecture Handbook* the owner refers to is **not in the repository or the Project**. This map is derived from the handover documents above and must be re-checked against the handbook once it is provided.
**State labels:** IMPLEMENTED (works end to end, tested) · PARTIAL (some of it works) · MISSING (nothing usable) · BLOCKED (cannot proceed without an owner, legal or clinical decision).

## 1. What the complete platform is

NAVORA is an operating system for **self-organised ambulatory nursing teams in Switzerland**. Teams take on clients, plan and deliver care, and document it without line managers. NAVORA supplies the platform and a neutral coach. Around that core sit:
- **intake** from hospitals, nursing homes, GPs and relatives;
- **matching** of clients to teams;
- the **field tool**;
- **documentation** with human-approved AI drafts;
- **quality** and clinical safety;
- **regulated assessment** (interRAI LTCF-CH, PAG, MQI);
- a **rule platform** that makes handbook and regulatory rules versioned and explainable;
- **finance**: billing to payers, payroll, and transparent team economics.

Everything is multi-tenant, audited, and privacy-first.

## 2. Domains and dependencies

| # | Domain (ARCHITECTURE.md) | Depends on | Unlocks |
|---|---|---|---|
| D1 | Identity & Governance | — | everything (tenancy, roles, audit, access to health data) |
| D2 | Partner Intake | D1 | D3 |
| D3 | Cases & Care (needs, care plans, prescriptions) | D1, D2 | D4, D6, D7, D9, D11 |
| D4 | Matching | D3, D5 (capacity, competence, locations), D10 (validated weights) | D5 team decision |
| D5 | Team Self-Organisation & Planning (decision, availability, capacity, calendar, substitution, planning) | D1, D4 | D6 (planned visits), D4 (capacity data), D12 (real capacity), D11 (team economy) |
| D6 | Field Operations | D1, D5 | D7, D8, D11 (time facts) |
| D7 | Documentation & AI | D6 | D8, D11 (approved documentation) |
| D8 | Quality & Clinical Intelligence | D6, D7, D9 | D11 (quality holds), D12 |
| D9 | Assessment / LTCF / PAG / MQI | D3, D7, D10, licence | D8 (MQI), D11 (PAG) |
| D10 | Rule Engine / Architect Mode | source documents, clinical sign-off | D4, D9, D11, D12 (attention rules) |
| D11 | Finance (billing facts, tariffs, payroll, team economy) | D6, D7, D8, D9, D10, legal | — (end of value chain) |
| D12 | Operations Control Tower | D3–D8 | exception handling |
| X1 | Platform & Security (CI, auth, CSP, logging, staging, restore, incident) | — | real-data readiness |
| X2 | Integrations (EPD/FHIR, geocoding, AI provider, payers) | per domain | — |

## 3. Implementation state

| Domain | State | What exists | What is missing |
|---|---|---|---|
| D1 Identity & Governance | **PARTIAL** | organisations, org and team memberships, RLS per organisation and team, append-only audit log, SSR auth, role-based landing | profiles, legal entities, access grants, break-glass, retention (Q6), MFA, membership admin (Q5), final role matrix (Q4/D-3) |
| D2 Partner Intake | **PARTIAL** (J1 in review) | record referral, review, convert with consent gate | partner self-service, purpose binding, contracts, D-9 legal basis |
| D3 Cases & Care | **PARTIAL** | case record, created through intake | care needs model, care plans, prescriptions, case view for teams |
| D4 Matching | **PARTIAL** | open matching request per case; team pull (J2, in progress) | engine (hard filters on real data, ranking, dry run, versioning), competence and location data |
| D5 Team Self-Organisation & Planning | **MOSTLY MISSING** | team master data, coach focus; team decision (J2, in progress) | availability, capacity windows, team calendar, visit planning and claims, substitution, team agreements; capacity today is two manually entered numbers |
| D6 Field Operations | **IMPLEMENTED (MVP slice)** | own-team day view, state machine, append-only events, time and corrections, observations, handover (F1–F4) | offline sync, assignment model (D-6), Gate 2 exit suite (F5) |
| D7 Documentation & AI | **PARTIAL** | observations with provenance and versions | report drafts, human approval, immutable versions, AI drafts (provider = Gate 3) |
| D8 Quality | **PARTIAL** | quality events shown as attention items | raising events from the field, review workflow, safety holds, risk signals |
| D9 Assessment / LTCF / PAG / MQI | **MISSING · BLOCKED** | — | licence, specifications, reference cases |
| D10 Rule Engine / Architect | **MISSING · BLOCKED** | attention thresholds hard-coded (legacy, not validated) | source matrix, versioned rules, explanation, impact analysis; needs validated sources |
| D11 Finance | **MISSING · BLOCKED** | — | tariffs, payers, billing facts, payroll, team economy; legal decisions (Gate 6) |
| D12 Operations | **PARTIAL** (legacy) | attention centre, KPIs, team health | KPIs on real capacity and documentation state; Q3 wording |
| X1 Platform & Security | **PARTIAL** | CI (lint, types, unit, pgTAP, e2e), CSP, safe logging, live DB contained | staging (D-2), restore test, incident runbook, branch protection (owner) |
| X2 Integrations | **MISSING** (except Supabase) | — | EPD/FHIR, geocoding worker, AI provider, payer interfaces |

## 4. Largest value increase: D5 Team Self-Organisation & Planning

**Why D5 and not another domain**
1. **It is the business model.** MASTER_CONTEXT's mission is self-organised teams without line managers that plan, accept cases and organise substitution themselves. Without D5 the platform has a field tool and an operations dashboard, which is what every Spitex software has. D5 is what makes NAVORA different, and it is the least implemented of the core domains.
2. **It is the dependency hub of the buildable part of the platform.**
   - **D4 Matching** needs real capacity: the hard filter *tatsächliche Kapazität* has no data today.
   - **D6 Field** needs planned visits: today every visit is seed data.
   - **D12 Operations** shows capacity that is typed in by hand (`utilization`, `open_slots`); D5 replaces it with derived capacity.
   - **D11 Finance** (team economy, payroll) later needs D5's team and time data.

   Value created in D5 therefore shows up in four other domains at once.
3. **It is buildable now.** Unlike D9, D10 and D11, it needs no licence, no clinical validation and no tariff law. The decisions it touches are already documented as DECIDED (Teamautonomie, team decision audited, capacity per time window), or are product choices with safe defaults (D-6 assignment).
4. **It completes the journey.** With J1 (intake) and the field tool done, D5 is the missing middle. After it, a referral travels to a delivered, documented visit without anyone dispatching it.

**Why not the alternatives (now)**
- **D1 Identity & Governance** is the gate for real patient data, but its remaining parts are mostly owner decisions: role matrix (Q4/D-3), retention (Q6), membership administration (Q5). Engineering defaults already protect synthetic staging.
- **D7 Documentation & AI** brings high value per visit, but the approval role (Q4) and the AI provider (Gate 3) are open. Report drafts without AI follow right after D5.
- **D10 Rule Engine** has the largest long-term leverage (matching weights, assessment, billing), but it is blocked by the requirement for validated sources and would produce rules nobody may switch on yet.
- **D9 Assessment and D11 Finance** are blocked by licence and legal decisions.

**D5 slices, in order**
1. Team decision (J2, in progress).
2. Team planning: visits for the team's cases, visible in `/field` (J3).
3. Team availability and capacity windows. These derive the capacity that feeds Operations and the matching filter, replacing the hand-entered numbers.
4. Substitution and claims within the team (the D-6 assignment model).
