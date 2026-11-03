# APP1 implementation plan: the NAVORA app (M2 web app, M6 caregiver app, M8 operations app)

**Owner:** Engineering (`eng`, decides HOW) · **Date:** 2026-11-03 (Europe/Zurich) · **Version:** 1

**Baseline (requested by the owner):** the `uxa` design set on PR #834, head `d811658`:
- `NAVORA_INFORMATION_ARCHITECTURE.md` (**IA**);
- `NAVORA_SCREEN_CATALOG.md` (**SC**), screens A-, C-, O-, L-;
- `NAVORA_DESIGN_SYSTEM_V1.md` (**DS1**), §2 to §5 and §8.

**Also built on:** `docs/product/DELIVERY_PROGRAM.md` (M2, M4, M6, M8), `docs/engineering/IMPLEMENTATION_SEQUENCE.md` (#833, step IDs F-n and B-n), and the code on `recovery/main` `2981ad5`.

**Scope:**
- **In:** one app, one code base, phone and desktop, delivered three ways:
  - M2: the consolidated web app;
  - M6: the caregiver app, installable on `/field`;
  - M8: the operations app on `/operations`.
- **Also in:** M4 screens (C-17, AN3 on O-05), because M6 and M8 build on them.
- **Out:** the family app (F-01 to F-06), which is FROZEN (D-40). Engineering writes the M7 impact section only.

**Labels:** IMPLEMENTED (on `recovery/main`) · IN REVIEW (open PR) · PLANNED · OPEN · UNKNOWN.

**API pattern (IMPLEMENTED, ADR-003):** page (server component) → `src/features/<f>/queries.ts` reader → Postgres function. A user action calls a Server Action in `commands.ts`, which calls an RPC command with an idempotency key; the command checks the source state, mutates and writes the audit in one transaction. "Reads" and "Commands" below name the Postgres functions.

---

## 1. Delivery form (ADR-142, PR #835, ACCEPTED by the owner 2026-11-03; details ADR-143)

**Owner priority 2026-11-03:** 1 M2 Web App · 2 M4 PLAN3/AN3 · 3 M6 Caregiver App · 4 M8 Operations App · 5 M5 Website. Escalation dates: M2 2026-11-27, M4 2026-12-18, M6 2027-01-29, M8 2027-02-19, M9 2027-03-12.


- **Caregiver and operations apps** are one installable web app (PWA) on the UX2 shell. The parts are:
  - web manifest (DS1 §3.4) and `app/manifest.ts`;
  - the existing `public/sw.js`, extended with an app-shell cache (no care data cached);
  - an offline command queue;
  - push (SIG2, IMPLEMENTED, D-33).
- **Native only if M1 shows a requirement the web app cannot meet.** iOS behaviour of installed web apps (push, background retry) is UNKNOWN here and is checked against current platform documentation in M1, not assumed.
- **Offline queue (A-07):** pending commands live in IndexedDB, keyed by idempotency key, and are cleared on sign-out. They are resent with the same key only while the app is in the foreground (ADR-142; no background sync), and a value is never shown as done before the server confirms it.
  - Open for `lca` (SC-2): entered care text sits on the device until it is sent.
  - Open for `cra`: the banner wording.

  The queue is designed now and built only after both answers.

Details recorded as **ADR-143** (PROPOSED): the pending-command store, and C-15/C-17 as routes (a sheet may render on the same URL, D-IA-1).

---

## 2. Shared foundation (built first; every screen depends on it)

| Step | What | DS1 | Depends on | Blocks | Label |
|---|---|---|---|---|---|
| A-03 | App shell: `AppShell`, `TabBar`, `Sidebar`, `MoreMenu` | 1-4 | – | everything | IN REVIEW #799 |
| T-1 | Tokens: DS1 §2.6 into `src/app/globals.css`, body font fix (DS1-3), `border-control` stone-500 (DS1-1) | §2 | #799 merged | T-2 | PLANNED (UX2-3) |
| T-2 | Core components in `src/components/ui/`, each with a vitest/RTL test per state:<br>`PageHeader`, `Button`, `Card`, `Notice`, `ErrorLine`, `EmptyState`, `Section`, `Badge`, `FormField`, `ListRow`, `LoadingLine`, `RetryBlock` | 5, 8, 12, 15-20, 22, 23, 25 | T-1 | every screen port | PLANNED (UX2-3, UX2-14) |
| T-3 | Lint rule: no inline layout `style` under `(protected)` (UX2-4); one `h1` per page (UX2-12); one label per destination (UX2-32) | – | T-2 ports | M2 acceptance | PLANNED |
| A-05 | `error.tsx`, `not-found.tsx`, no-access page inside the shell | 5, 19 | T-2 | M2 (SC-1, PO to add to UX2) | OPEN (PO) |
| UX2-31 | Role's home is its first tab; a focused control is never under the bar | 2 | #799 | M6 start screen | PLANNED |

---

## 3. Per screen

### 3.1 Shared screens (A)

| Screen | Frontend components | Backend dependencies (reads) | API dependencies (commands) | Sequence |
|---|---|---|---|---|
| **A-01 Anmelden** `/login` | `PageHeader`, `FormField` × 2, `Button` primary, `ErrorLine` | Supabase Auth session; `organization_memberships` (own rows) for `homePathForRoles` | Supabase `signInWithPassword` (Server Action `auth/actions.ts`) | M2 port (T-2); M6: session on the installed app (A-06). "Passwort vergessen": UNKNOWN (MOB1) |
| **A-02 Start redirect** `/` | none | `organization_memberships` | none | IMPLEMENTED; D-IA-3 (coach or admin in a team) OPEN for `po` |
| **A-03 Shell** | `AppShell`, `TabBar`, `Sidebar`, `MoreMenu` | `useNavAccess` (own roles, own team memberships) | none | #799 → UX2-31 → UX2-32 |
| **A-04 Meine Einstellungen** `/settings` | `PageHeader` (h1, UX2-12), `Notice(attention)`, `Button` | `my_push_state` | `register_push_subscription`, `unregister_push_subscription`, `set_outside_push` | M2 port |
| **A-05 Error, not found, no access** | `PageHeader`, `EmptyState`, `Button` | none | Next `reset` | M2 (after T-2) |
| **A-06 App installieren** | `InstallPrompt` (`Notice(info)`, dismissible), iOS instruction `BottomSheet` | none (browser `beforeinstallprompt`) | none | M6-1 |
| **A-07 Verbindung unterbrochen** | `ConnectionBanner`, pending state on each card, `role="status"` "Gesendet." | none | **offline queue** around every `/field` command (§1); needs B-7: every command takes a key and answers `duplicate` | M6-2 (after `lca`/`cra`) |

### 3.2 Caregiver app (C): M2 port, M6 app

| Screen | Frontend components | Backend dependencies (reads) | API dependencies (commands) | Sequence |
|---|---|---|---|---|
| **C-01 Heute** `/field` | `PageHeader` + `DateNav`, `SignalCard`, `Notice`, `JumpRow`, `VisitCard`, `Section`, `Dialog`, `EmptyState`, `InstallPrompt` (M6) | `my_signals`, `field_visits`, `field_notes`, `field_reports`, `field_returned_reports`, `field_countersign_queue`, `field_since_last`, `field_door_notes`, `field_safety_alerts`, `field_safety_alert_history`, `field_visit_status_notes`, `field_quality`, `quality_event_types`, `team_absences`, `team_open_visits`, `team_memberships`, `member_profiles`, `cover_offers`, `my_covers`, `team_open_reports`, `team_visit_alerts`, own assessments to confirm | `take_signal`; visit lifecycle (see C-03); `record_absence`, `change_absence`, `take_open_visit`; `accept_cover`, `withdraw_cover` | M2: open UX2 PRs (#804, #800) → T-2 port → UX2-9 signal cards (`cra`), UX2-11, UX2-17, UX2-28. M6: A-06, A-07, C-16 |
| **C-02 Anderer Tag** `/field?datum=` | as C-01 + `Notice(info)` (other day) | as C-01 for the date | `move_visit_to_today` / `reschedule_visit`, `visit_move_leaves_other_visit` | M2 (UX2-18 to -21 on #804) |
| **C-03 Einsatzkarte** | `VisitCard` (extracted from `field-client.tsx`), `Badge`, `Button` (`target-main`), `MoreMenu` (card), `ConfirmStep`, `Notice`/`SignalCard` for alerts | row of `field_visits` (incl. VIS2 overlap), `field_door_notes`, `field_safety_alerts`, `field_visit_status_notes`, `client_visit_overlap` | `depart_visit`, `start_visit`, `pause_visit`, `resume_visit`, `complete_visit`, `correct_visit_time`, `cancel_visit`, `record_no_show`, `record_no_show_outcome`, `end_visit_not_completed`, `set_quality_hold` | M2: extract `VisitCard` on T-2 tokens. M6: offline-safe lifecycle (A-07), anchors `#einsatz-<id>` (C-16) |
| **C-04 Dokumentation** | `Section`, `ListRow` (observations with author line, UX2-27), `FormField` textarea, `ConfirmStep` (signing), `details` (returned version) | `field_notes`, `field_reports` (server draft, versions, return reason) | `record_observation`, `create_report_draft`, `update_report_draft`, `sign_report`, `correct_report`, `withdraw_report_correction` | M2 port. M6: a typed observation survives a lost connection (A-07); anchor `#bericht-<id>`. No AI drafting (D-34, D-35) |
| **C-05 Übergabe** | `details` + `ListRow` per entry; M8: grouped headings (wording `cra`) | `field_since_last` | none (read) | M2 (UX2-27 amendment on #800). M8: HAND2 ordering inside the reader (B-10) |
| **C-06 Ich kann nicht arbeiten** | `Dialog`, `FormField` (period), result `Notice` | `team_absences`, `team_open_visits` | `record_absence`, `change_absence` | M2 port (T-2) |
| **C-07 Offen im Team / Unterstützung** | `Section` with count, `ListRow` + `Button` outline "Übernehmen" | `team_open_visits`, `cover_offers`, `my_covers` | `take_open_visit`, `accept_cover`, `withdraw_cover` (cover stays off, D-3) | M2: UX2-17 (one command, one label) |
| **C-08 Zu erledigen** | three `Section`s via `JumpRow`, `Button`, `PresetReason` (return reason) | follow-ups, `field_returned_reports`, `field_countersign_queue` | `record_interruption_followup`, `sign_report`, `countersign_report`, `return_report` | M2: UX2-11 (returned report stays in her day). M6: two-tap reach |
| **C-09 Ereignis melden** | `Button`, `FormField` (type, description), `ListRow` | `quality_event_types`, `field_quality` | `record_quality_event`, `set_quality_event_status` | M2 port |
| **C-10 Sicherheitshinweis an der Tür** | `SafetyAlertForm`, `details` history | `active_safety_alert_categories`, `field_safety_alerts`, `field_safety_alert_history` | `record_safety_alert_value` | M2 port (presentation `cra`) |
| **C-11 Team** `/team` | `PageHeader` (+ "Vorschläge (n)" `CountChip`, "Tag vorschlagen"), `SignalCard`, `Section`, `Card` (case card), `ListRow`, `ConfirmStep`, `BillingPreview` | `my_signals`, `team_visit_alerts`, `team_push_status`, `visits_outside_watched_hours`, `team_offers`, `team_cases`, `team_case_lifecycle`, `continuity_by_case`, `team_plan_status`, `team_case_assessments`, `assessment_instruments`, `billing_preview`, `case_gp_notices`, `team_admissions`, `contract_end_handover`, `member_open_reports`, `team_successor_items`; M4: open-proposal count (PLAN3-12) | `decide_matching_request`, `add_care_plan_item`, `retire_care_plan_item`, `set_care_plan_schedule`, `set_auto_planning`, `plan_from_care_plan`, `plan_visit`, `remove_planned_visit`, `reschedule_visit`, `set_primary_nurse`, `complete_case_task`, `record_gp_informed`, `record_assessment`, `confirm_assessment`, `review_care_plan_against_assessment`, `pause_case`, `resume_case`, `close_case`, `reopen_case`, `propose_team_candidate`, `decide_team_candidate`, `set_member_contract_end` | M2: #803 (UX2-15/-16/-25), #806 (UX2-30), UX2-13, UX2-24 → T-2 port. M4: PLAN3-10 switch, PLAN3-11/-12 |
| **C-12 Vorschläge** `/team/vorschlaege` | `BackLink`, `PageHeader`, `Section`, `ProposalLine`, `CheckboxRow`, `BulkConfirmBar`, `EmptyState` | `open_suggestions`, `team_cases`, `member_profiles` | `confirm_suggestion`, `confirm_suggestions` | M2: #814 (AIG1-C4 expired not listed) → T-2 port. M4: PLAN3 lines |
| **C-13 Einsatz (record)** `/visits/[visitId]` | `BackLink`, `PageHeader`, facts `dl`, `ProvenanceLine`, `Button` | `care_visits`, `teams`, `member_profiles`, `value_provenance`, `record_lookback_lines` | `confirm_suggestion` (re-confirm, AIG1-C2) | M2: UX2-29 amendment (#800) → port |
| **C-14 Arbeitstag** `/work` | `PageHeader` + `DateNav`, fixed notice (`lca` text), segment list, `Button`, `details` versions | `my_working_time_notice`, `my_working_day`, `my_working_day_versions`, `my_unexported_working_days`, `my_contract_end` | `acknowledge_working_time_notice`, `confirm_working_day`, `export_working_month` | M2 port (texts word for word) |
| **C-15 Assistent** `/field/assistent` | `BackLink`, `PageHeader`, `IntentList`, answer region (`role="status"`), `ProvenanceLine`, `ErrorLine` + `RetryBlock` | existing readers only: `field_visits` + `my_signals`; `field_since_last`; `team_open_visits` + `member_profiles`; `field_reports` | none that write care data. **Recording of the asked intent: OPEN (B-8)**, AIG1 ledger row or own append-only log, `po`/`aia` | M6-4, after B-8 and MOB1 |
| **C-16 Schnellzugriff** | no new screen: 44 px rows on `VisitCard` expand Beobachtungen, Bericht, Übergabe; anchors | none | none | M6-3, e2e counts taps at 390 px |
| **C-17 Tagesvorschlag** `/team/tagesplan?datum=` (M4) | `BackLink`, `PageHeader`, date field, `CheckboxRow` "auch zugewiesene", `Button`, per-member `Section` with minutes before → after, `ProposalLine`, `BulkConfirmBar`, `EmptyState` | PLAN3 tables and readers (B-4a to B-4d, migration 0108 PLANNED) | `request_day_proposal` (PLANNED), team switch command (PLANNED), `confirm_suggestion(s)` | M4 (2026-11-30 → 12-18), after #814 |

### 3.3 Operations app (O): M2 port, M8 app

| Screen | Frontend components | Backend dependencies (reads) | API dependencies (commands) | Sequence |
|---|---|---|---|---|
| **O-01 Ausnahmen** `/operations` | `PageHeader`, `Notice(attention)` (evaluator health, control health), `ExceptionRow` (M8 grouped), `Section`, `BillingPreview`; desktop list-detail `?ausnahme=` | `operations_exceptions`, `sync_exceptions`, `cases`, `teams`, `quality_holds`, `continuity_by_case`, `ops_case_lifecycle`, `billing_preview`, `my_signals`, `signal_evaluator_health`; M8: OPS2 grouping and control-health reads (B-11, PLANNED) | `handle_exception`, `take_signal`, `lift_quality_hold`, `set_quality_hold` | M2: remove inline styles (UX2-4) → T-2 port. M8: OPS2 grouping, next-step text, list-detail |
| **O-02 Assistenten** `/operations/assistenten` | `BackLink`, `PageHeader`, `DataTable` (desktop) / `ListRow` (phone) | `agent_health`; M8: AIO1 evaluations (B-9) | none in M2; M8: none for app roles (orchestrator is system) | M2: #814 expired count → port. M8: AIO1 contract and evaluation columns |
| **O-03 Rückblick nach Stopp** | `BackLink`, `PageHeader`, counts line, `ListRow` (link to C-13) | `agent_stop_lookback` | none | M2 port |
| **O-04 Aufnahme** `/intake` | `PageHeader`, `Section` lists, `Badge` (urgency word), `FormField`s in fieldsets; desktop two columns | `intake_cases`, `linkable_cases`, `partner_requests`, `organization_memberships`, `active_safety_alert_categories` | `record_partner_request`, `convert_partner_request`, `update_case_intake`, `link_returning_referral` | M2 port |
| **O-05 Kennzahlen** `/analytics?monat=` | `PageHeader` + `MonthNav`, `FigureGroup`, `Figure` (value, base, "zu wenig Daten") | `pilot_kpis`, `pilot_hypotheses`; M4: AN3 `pilot_step_spans` (B-5, PLANNED) | none | M2 port. M4: AN3 block (AN3-5: no colour scale, no ranking) |
| **O-06 Administration** `/admin` | `PageHeader`, sticky section nav (desktop), collapsible `Section`s with counts, `ConfirmStep`, `RetryBlock` | `admin_members`, `member_invitations`, `member_access_events`, `admin_exception_rules`, `admin_response_deadlines`, `teams`, `organization_memberships`, `admin_team_admissions`, `member_contract_events`, `contract_end_handover`, `member_open_reports`, `organization_push_settings`, `organization_watched_hours`, `push_vendors`, `signal_evaluator_health`, `visits_outside_watched_hours` | `invite_member`, `revoke_invitation`, `set_member_role`, `set_display_name`, `set_member_qualification`, `add_team_member`, `remove_team_member`, `create_team`, `update_team`, `deactivate_team`, `set_exception_rule`, `reset_exception_rule`, `set_response_deadline`, `set_team_admission`, `record_member_contract`, `prepare_member_access_end`, `end_member_access`, `restore_member_access`, `set_watched_hours`, `set_agent_state` | M2: #809 (UX2-26), #813 (RLS4-C3) → T-2 port |
| **O-07 Kapazität** `/operations/kapazitaet?woche=` (M8) | `PageHeader` + `WeekNav`, `Notice(attention)` per team with gaps, `CapacityGrid` (phone) / `DataTable` (desktop) | **new reader** per team and day: planned minutes, visits without a responsible member, open in team, cover, absences as a count; small-team suppression (B-12, PLANNED; `lca` reads) | none (read only; Operations does not assign) | M8, after OPS2 brief, PLAN3 and `lca` (SC-3) |
| **O-08 Kontrollen** (M8) | `ControlRow` list; top `Notice` on O-01 when a control is unhealthy | `signal_evaluator_health` (exists); push delivery, scheduled jobs, assistant states, expired orders (OPS2 reads, B-11) | none | M8, placement SC-4 (`po`) |

### 3.4 First-MVP pages (UX2-5, decided in the M2 ADR)

| Screen | Engineering proposal (`po` accepts) | Function check |
|---|---|---|
| L-01 `/teams` | **retire**; successors O-01 "Pflegeteams" and O-07 | `assign_team_coach` and `set_team_priority` have no other screen today. Move them to O-06 Teams before retiring (checked in the ADR) |
| L-02 `/visits` | **retire** unless the ADR names a function no other screen has; successor C-11 / O-01 | read-only list; the ADR checks it |
| L-03 `/partners` | **retire** (static demo, no data) | none |

---

## 4. Development order

```text
M2   #799 shell ─► merge queue (#800 #803 #804 #806 #809 #810 #813 #814)
         └─► UX2-31 ─► T-1 tokens ─► T-2 components ─► ports: C-01 C-03 C-04 C-11 O-01 O-06 first (DS1 §8 step 1)
                                                         then C-02 C-05..C-10 C-12..C-14 A-01 A-04 O-02..O-05
                    ─► A-05 error pages ─► T-3 lint + UX2-2/-8/-10 checks ─► UX2-9/-11/-17/-24/-28 ─► cra gate ─► M2
M4   #814 merged ─► PLAN3 DB (0108) ─► C-17 + C-11/C-12 changes ─► AN3 (0109) ─► O-05 block ─► M4
M6   M2 + MOB1 ─► M6-1 manifest + A-06 + session ─► M6-2 offline queue (after lca/cra) ─► M6-3 C-16 two taps
                ─► M6-4 C-15 assistant (after B-8) ─► M6
M8   M4 + briefs ─► B-11 OPS2 ─► O-08 + O-01 grouping ─► B-12 ─► O-07 ─► B-9 AIO1 ─► O-02 ─► B-10 HAND2 ─► C-05 ─► M8
```

**Rules for the order:**
1. Tokens and components (T-1, T-2) come before any new screen. Otherwise every later PR is restyled twice.
2. The ports start with the four screens the design set names first (C-01, C-11, O-01, O-06), because those are where the inline styles and ad-hoc colours sit.
3. Each port PR touches one route, so PRs do not conflict.
4. New M4/M6/M8 screens are new routes or new sections. They do not wait for the full port, only for T-2.
5. Engineering opens no further UX2 part until the PO has merged the open queue (PO order 2026-11-03 06:30, item (0)).

---

## 5. Estimated completion dates

These are estimates, not commitments; the PO re-baselines them in program v2. Each date assumes the predecessors in the "Assumes" column.

| Milestone / step | Estimated done | Assumes | Confidence |
|---|---|---|---|
| Merge queue cleared (PO) | 2026-11-10 | `po` reviews 11 green PRs this week | Medium |
| T-1 + T-2 tokens and components | 2026-11-17 | queue cleared; #834 merged as baseline | Medium |
| Screen ports, A-05, T-3, UX2-9/-11/-17/-24/-28 | 2026-11-24 | `po` merges port PRs within 1-2 days each | Medium |
| **M2 Web app** (`cra` UX2 gate clear) | **2026-11-27** | `cra` gate within 3 days | Medium |
| C-17 + AN3 (M4) | 2026-12-18 | #814 merged; `cra` PLAN3 gate | Medium |
| M6-1 installable app | 2026-12-11 | MOB1 by 2026-11-27; app icon (DS1-4) | Medium |
| M6-2 offline queue | 2026-12-23 | `lca` (device storage) and `cra` (wording) by 2026-12-11 | Low |
| M6-3 two-tap reach | 2027-01-08 | M6-1 | Medium |
| M6-4 assistant C-15 | 2027-01-22 | B-8 decided by 2026-12-11; `cra` C-15 line | Low |
| **M6 Caregiver app** | **2027-01-29** | above | Low-Medium |
| OPS2 (O-01 grouping, O-08) | 2027-02-05 | OPS2 brief by 2026-12-04 | Low |
| O-07 Kapazität | 2027-02-12 | brief (SC-3), `lca` suppression read | Low |
| AIO1 (O-02) + HAND2 (C-05) | 2027-02-12 | AIO1/HAND2 briefs by 2026-12-04 | Low |
| **M8 Operations app** | **2027-02-19** | above; `cra` gate | Low |

---

## 6. Critical path and blockers

**Critical path:**

```text
PO merge queue (#799 first) → T-1/T-2 tokens and components → screen ports → cra UX2 gate → M2 (11-27)
  → MOB1 → M6-1 → [lca/cra on offline storage] → M6-2 → M6 (01-29)
  → [OPS2/AIO1/HAND2 briefs 12-04] → M8 (02-19)
```

On the technical path to Pilot Ready (#833 §7.3), only M2 and the M6 core (M6-1, M6-2) are needed. M4, M6-4 and M8 enter the pilot later as switch-ons (OPEN for `po` and the owner).

| Blocker | Owner | Blocks | Needed by |
|---|---|---|---|
| 11 open green Engineering PRs unmerged | `po` | all of M2; PLAN3 | 2026-11-10 |
| PR #834 (design set) merged as baseline | `po` | T-1/T-2 cite it | 2026-11-10 |
| SC-1 A-05 added to UX2 | `po` | A-05 | 2026-11-13 |
| UX2-5 decision on L-01 to L-03 | `eng` ADR, `po` accepts | M2 | 2026-11-20 |
| MOB1 brief (incl. "Passwort vergessen", C-15 intent labels SC-5) | `po` | M6 | 2026-11-27 |
| App icon and word mark (DS1-4) | `uxa`, `po` | manifest (M6-1) | 2026-12-04 |
| Device storage of pending entries (SC-2) | `lca` | M6-2 | 2026-12-11 |
| Offline banner wording; C-15 "keine medizinische Beratung" line | `cra` | M6-2, M6-4 | 2026-12-11 |
| B-8 intent recording (ledger vs own log) | `po`, `aia` | M6-4 | 2026-12-11 |
| OPS2, AIO1, HAND2 briefs; O-07 brief (SC-3); O-08 placement (SC-4); M8 tab set (D-IA-2) | `po` | M8 | 2026-12-04 |
| Small-team suppression for absence counts on O-07 | `lca` | O-07 | 2027-01-08 |
| Address link to an external maps service (SC-8) | `lca`, `po` | none: not built until decided | – |

## 7. Effort (summary, details in #833 §8)

| Item | PRs | Agent runs | Person-days (human equiv.) | Confidence |
|---|---|---|---|---|
| M2 (T-1 to T-3, ports, A-05, UX2 remainder) | 7-9 | 10-15 | 12-17 | Medium |
| M4 screens (C-17, C-11/C-12, O-05 AN3) | 2-3 (UI share) | 5-8 | 6-9 | Medium |
| M6 (M6-1 to M6-4) | 5-7 | 13-20 | 16-25 | Low-Medium |
| M8 (O-01, O-02, O-07, O-08, C-05) | 6-9 | 18-27 | 20-35 | Low |

## Change log
- 2026-11-03 eng: version 1 (from #834 design set, #832 program, #833 sequence).
- 2026-11-03 eng: owner decisions and priority recorded; queue resend aligned with ADR-142 (foreground only); ADR-143 narrowed to what ADR-142 does not say.
