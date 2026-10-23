# Clinical Rule Register

**Maintained by:** Clinical & Regulatory Architect (review role) · **Approves rules:** the named, qualified human clinical owner (`clinical`), or `legal` / `owner` for their rules (D-27) · **Last change:** 2026-10-23 06:30 · **Baseline:** `recovery/main` @ `53147cc`

Every rule that encodes a clinical, care-organisation, billing or regulatory judgement is listed here: where it lives, its cited source, who set it, and whether a qualified owner has approved it. **No rule below is clinically or legally approved yet.** Engineering adds a row whenever a migration introduces or changes such a rule; the Architect reviews it.

**Status:** `UNVALIDATED` (in code, no qualified approval) · `PROVISIONAL` (deliberately strict default until a named decision) · `APPROVED` (decision ID + named approver + date) · `DEPRECATED` (removed or to be removed).

**D-27 (owner, 2026-10-22):** until a named, qualified clinical owner is appointed, `APPROVED` is not available for any clinical rule. Every clinical decision stays OPEN and provisional. Engineering may implement safe defaults (status `PROVISIONAL`). The Clinical & Regulatory Architect never sets `APPROVED`.

## Rules

| ID | Rule (as implemented) | Where | Cited source | Set by | Decision | Status | Architect note |
|---|---|---|---|---|---|---|---|
| CR-001 | The team chooses the KLV category (A/B/C) per care-plan service; no service→category mapping | 0014:5-7; `team-client.tsx:658` | – | PO (J3 deviation) | D-15 | UNVALIDATED | category drives qualification gates and billing |
| CR-002 | Needs assessment comes first, is a category A visit, by a registered nurse | 0014:215, 226 | "KLV Art. 8a" (migration header) | PO J3 | D-15 | UNVALIDATED | instrument and validity period undefined (D-13) |
| CR-003 | Category B may be planned only with medical order status `present` | 0014:232 | KLV (J1 brief) | PO J1/J3 | D-15, D-22 | UNVALIDATED | |
| CR-004 | Categories A and C need no medical order; an "inform GP" task is created, never required | 0014:263; `briefs/J1.md:102` | "since 1 July 2024" (PO statement) | PO J1 | D-22 | UNVALIDATED | legal basis to be confirmed |
| CR-005 | A B visit after the order end date is allowed and flagged; PLAN2 drops B after expiry | 0014:148; 0030:103-107 | – | PO J3/PLAN2 | D-15, D-22 | UNVALIDATED | |
| CR-006 | Order `present` with no end date counts as valid indefinitely | 0023:114 | – | eng (implicit) | – | UNVALIDATED | CGR-07 |
| CR-007 | Category B and needs-assessment visits are **started, resumed and completed** by a registered nurse | 0038 §1 (was 0024:125-130) | KLV (J3) | PO J3 | D-15 | UNVALIDATED | every transition into `started` and `completed` since 0038; CGR-12 closed (Architect 2026-10-23 06:30, pgTAP 038:76-109). The rule itself still needs D-15 |
| CR-008 | A case needs a team with a registered nurse when no needs assessment exists yet or an order is present | 0017:301-306 | derived from CR-002/007 | eng J2 | D-15 | UNVALIDATED | |
| CR-009 | Qualifications: `registered_nurse`, `care_assistant`; a member without a value is `care_assistant` | 0018:118, 145 | – | owner D-5 | D-5, D-15 | UNVALIDATED (clinical) | no registration evidence (CGR-16) |
| CR-010 | Whether a care assistant may perform category A work (other than the needs assessment) | not addressed | – | – | D-15 | UNVALIDATED | open question, not a rule |
| CR-011 | Countersignature by another registered nurse whenever the performer is not a registered nurse | 0016:194, 302 | – | eng F6 | D-10 | PROVISIONAL | keep for the pilot |
| CR-012 | The performer (first `started` event) alone drafts and signs the report, including a correction version | 0016:98-105, 184, 262, 343-349 | – | PO Q4 | Q4 | UNVALIDATED | no takeover path (PS-11); permanent after removal (CGR-18, CGR-19) |
| CR-013 | Visit states and transitions (planned, on_the_way, started, paused, completed, cancelled, no_show) | 0024:105-134 | – | PO/eng | D-6 | UNVALIDATED | |
| CR-014 | A no-show can be recorded only from `on_the_way`; outcome list `client_reached`, `emergency_contact_informed`, `emergency_services_called`, `other` | 0024:374, 391 | – | PO C1 | D-19 | UNVALIDATED | no on-site protocol |
| CR-015 | Cancel reasons `client_cancelled`, `client_in_hospital`, `team_cancelled`, `other` | 0024:345 | – | PO C1 | – | UNVALIDATED | |
| CR-016 | Quality event types: list ships empty; recording refused | 0020:6-8, 181-185 | – | eng QG1 | D-16 | PROVISIONAL | blocks escalation of findings |
| CR-017 | Quality severity `low/medium/high/critical`; serious = high or critical | 0020:47, 54-56 | – | eng QG1 | D-16 | UNVALIDATED | |
| CR-018 | A quality hold attaches to one visit and blocks only billing | 0020:92-110; 0022; 0023 | – | eng QG1 | D-16 | UNVALIDATED | CGR-13 |
| CR-019 | A hold is lifted only by a coach or administrator, with a reason | 0020:281-303 | – | eng QG1 | D-16 | PROVISIONAL | |
| CR-020 | OPS1 thresholds: serious quality event P2 → P1 after 4 h; uncovered visit 24 h ahead (P1 hospital discharge); report not final 24 h (P3); order expiring 7 days (P3); no-show P1 | 0019:36-47; 0024:443-447 | – | PO Q9 | – | UNVALIDATED | |
| CR-038 | `visit_overdue`: a planned, not suspended visit not started at its planned start raises P2 at once, P1 one hour later; independent of the responsible person; untimed visits count from 00:00 | 0038 §2-3 | – | eng CSR1 (strict default) | D-28 | PROVISIONAL | listed out of ID order to avoid a merge conflict with #155 |
| CR-039 | `visit_stuck`: a visit `on_the_way`, `started` or `paused` with no status change for 1 h (started: 1 h after the planned end) raises P2, P1 after 3 h | 0038 §2-3 | – | eng CSR1 (strict default) | D-28 | PROVISIONAL | |
| CR-040 | The uncovered exception stays after the planned start while the visit is planned and nobody is responsible | 0038 §3 | – | eng CSR1 (PS-2) | D-28 | PROVISIONAL | |
| CR-041 | A safety exception (effective rule P1 or escalating to P1) cannot be closed by hand; it closes only when its cause is resolved. A serious quality event stays an exception and keeps escalating while `in_review` | 0039 §1-5 | – | eng CSR1 (CGR-05, CGR-06) | D-28 | PROVISIONAL | endorsed as a strict default (Architect 2026-10-23 06:30); which types count follows the configured priorities; residual CGR-20, CGR-22 |
| CR-042 | A `started` or `paused` visit can end as **not completed** (`interrupted`) with a reason from a list (client transferred or taken to hospital, client declined to continue, nurse called away or unwell, started by mistake, other with a note), by any member of the visit's team or a coordination role, whatever the qualification; no billable fact, no report obligation, not counted as completed; it ends `visit_stuck` through its cause | 0042 §1-3 | – | eng CSR1 (CGR-20), PO criterion 2026-10-23 07:10 | D-31 | PROVISIONAL | engineering's interim safe default (2026-10-23, #179); reasons, documentation, billing of minutes already given and who may record it are D-31 (`clinical`, with `legal`) |
| CR-021 | Organisations may override thresholds up to 2× the default; P1 cannot be lowered | 0035:526-536 | – | eng D-21 | – | UNVALIDATED | safety thresholds need clinical approval to change |
| CR-022 | Team response deadlines: hospital discharge 4 working hours, nursing home 1 working day, private 2 working days; working time Mon–Fri 08:00–18:00 | J2 (#36); Q8, Q10 | – | PO | Q8, Q10 | UNVALIDATED | |
| CR-023 | Handover window: 14 days of handover notes; "since your last visit", else the last 3 completed visits | 0009:172; 0033:24-29 | – | PO | – | UNVALIDATED | display default |
| CR-024 | Returning client: link within 180 days of closure; previous team first, 1 h (hospital) / 2 h (other) | 0034:29-30 | – | PO RET1 | – | UNVALIDATED | no reassessment required (C-8) |
| CR-025 | Cross-team cover offered 24 h to 4 h before start; registered nurse only for B and needs assessment | 0028; 0029:74-75 | – | PO D-21 | D-3 | UNVALIDATED | cover switched off |
| CR-026 | PLAN2: rolling 4-week plan, even spread when no weekdays are named | 0025:80-82 | – | PO D-21 | – | UNVALIDATED | organisational, not clinical |
| CR-027 | Primary nurse and deputy per case; a visit by someone else is flagged `not_primary`, never blocked | 0021 | – | PO J6 | D-6 | UNVALIDATED | |
| CR-028 | Insurer rates per hour: A 76.90, B 63.00, C 52.60 CHF, region `CH`, from 2026-01-01 | 0022:52-58 | "KLV Art. 7 Abs. 2"; Kanton Graubünden publication | PO J5 | D-11 | UNVALIDATED | citation differs from J1 brief ("Art. 7a"); canton source seeded as federal |
| CR-029 | Minimum 10 billable minutes per visit, region `CH`; below → not billable | 0022:59-60; 0023:124 | Basel-Stadt Merkblatt 2026 | PO J5 | D-18, D-11 | UNVALIDATED | code reading differs from brief (BL-2) |
| CR-030 | Billable minutes never exceed measured care minutes; below plan, planned split scaled proportionally | 0023:98-110 | – | PO Q11 | D-18 | UNVALIDATED | |
| CR-031 | Care time = started → completed minus pauses; travel and documentation not care time; exact minutes, no rounding | 0023:10-11, 28-50 | – | PO/eng | D-18 | PROVISIONAL | |
| CR-032 | Insurance type `unknown` counts as missing for readiness | 0013:169 | – | eng J1 (PO accepted) | – | UNVALIDATED | |
| CR-033 | Readiness checklist: consent, residence, insurer, insurance type, care need, requested start | 0013:159-172 | – | PO J1 | D-15 | UNVALIDATED | no clinical items |
| CR-034 | Legacy Operations heuristics: team utilisation ≥ 90 % P1, ≥ 80 % or ≤ 1 open slot P2, 24 h → P1 | `src/features/operations/rules.ts` | – | legacy | – | DEPRECATED | removed by #135 (merged `eceac83`); intake alerts remain in OPS1 |
| CR-035 | Removing a member from a team releases her planned visits of that team dated today or later, suspended ones included; earlier and in-progress visits are not touched | 0036:38-71 | – | PO ADM1 | – | UNVALIDATED | care-organisation rule; visits dated before today stay with her (CSR1 / CGR-04) |
| CR-036 | Removal is refused while she is primary nurse or deputy of an open case of the team, responsible for or performer of a team visit `on_the_way`, `started` or `paused`, or performer of a `completed` team visit without a `signed` or `final` report | 0036:100-111; 0037:46-75 | – | PO ADM1, CGR-10, CGR-18 | – | UNVALIDATED | performer check added by 0037 (CGR-18 closed 2026-10-23 06:30); a correction draft does not refuse (CGR-19, D-30) |
| CR-037 | A change of organisation role leaves team membership, qualification and responsible visits unchanged | 0036 header item 2; ADR-046 | – | PO ADM1 | – | UNVALIDATED | organisational, not clinical |

## Not in the code (correct, keep it so)

No interRAI (HC or LTCF) items, scales or CAPs; no PAG items, groups or tariff levels; no MQI definitions; no vital-sign thresholds, medication rules or risk scores. These may only enter through a licensed specification and a named approver (D-13, D-24, D-27).
