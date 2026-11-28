---
id: SEC1
title: Continuous adversarial testing of staging (red team on synthetic data), external test before real data
author: po
status: approved
updated: 2026-11-07
---

# SEC1 — Continuous adversarial testing of staging (red team on synthetic data), external test before real data

**Approved 2026-11-07 15:39 CET (scheduled PO run)** on the owner's answer FE-049 ("Red-Team-Agenten greifen laufend Staging an (nur Kunstdaten, nie Produktion) + ein kleinerer externer Test vor echten Daten", reported by `eng` in PR #971). Built after T12 (protected staging) exists. Synthetic data only.

## Problem
Every security property of NAVORA today (RLS on every table, column grants, audit triggers, P1 signal paths) is proven only by pgTAP and e2e tests that Engineering writes for its own code. Nobody tries to break the running system the way an outsider would. Before real residents and clients (Phase B), a defect there is a privacy and patient-safety incident, not a test failure.

## Users and journey step
All users indirectly; every journey step that reads or writes care data. The direct users are `eng` (receives findings) and the owner (decides the external test).

## Outcome
A defined attack suite runs against staging on a schedule; every confirmed weakness becomes a dated finding with a severity and a fix owner; before Phase B one small external test confirms there is no open high finding (Blueprint M10.2, moved before Phase B).

## Acceptance criteria
- [ ] **SEC1-1 Scope document.** `docs/engineering/RED_TEAM_SCOPE.md` names the target (staging URL and staging Supabase project only), the forbidden targets (production, the old project, any third party, any real person's account), the allowed accounts (test-domain accounts created by the seed), stop rules (stop and report on any sign of real data; no denial-of-service; no social engineering) and the evidence each finding needs.
- [ ] **SEC1-2 Attack suite as code.** A script suite under `scripts/red-team/` covers at least: (a) cross-team reads and writes through the REST and RPC API with a valid member token of another team (every table in the RLS inventory); (b) anonymous access to every table, view and RPC; (c) role escalation (a `care_assistant` calling a `registered_nurse`-only command, a member calling an operations command); (d) direct object reference by guessed IDs; (e) audit evasion (a write that leaves no audit row); (f) secrets in the client bundle and in public responses; (g) the P1 signal path cannot be silenced by another member. Each case asserts the refusal and fails loudly on success.
- [ ] **SEC1-3 Never production.** The suite refuses to run unless the target host matches the staging allow-list in the scope document; a unit test proves it refuses the production host and the old project ref.
- [ ] **SEC1-4 Findings.** A successful attack writes a finding into `docs/engineering/SECURITY_RISKS.md` (ID, date, severity, reproduction on synthetic data, owner); a high finding blocks the next PO merge of any PR touching the affected table or command until fixed (merge gate condition 7).
- [ ] **SEC1-5 Schedule (owner action, proposed).** The suite runs from CI on a schedule against staging (`eng` proposes the cadence in the ADR). A separate scheduled red-team agent role, if the owner wants one beyond the suite, is created only by the owner; `po` proposes its prompt in the journal and creates no scheduled task.
- [ ] **SEC1-6 External test before real data.** The Phase B gate list (Blueprint §9.1) carries "external security test on staging, no open high finding" with the owner as decider; scope and budget are an owner choice (not decided here).

## Rules and their input class
No care rule. Repository and infrastructure facts only.

## AI leverage
1. Remove: manual security review by reading code. 2. Rules: the attack cases are deterministic assertions. 3. Monitor: the scheduled run watches every deploy. 4. AI prepares: an agent may propose new attack cases from the RLS inventory and the ADRs (input: repository text only, never data from staging responses beyond status codes and synthetic rows; level L). 5. Human reviews: `eng` reviews each proposed case before it enters the suite. 6. Human decides: `eng` fixes, the PO places the fix. 7. Human signs: the owner decides the external test. AI must never attack anything outside the allow-list, read real data, or mark a finding as fixed.

## Out of scope
Production testing; load or denial-of-service tests; social engineering; choosing the external tester (owner).

## Constraints and references
FE-049, FE-048 (staging), FE-020 (strict test-data standard), D-35 rule A (no data to an AI service), `ARCHITECTURE.md` RLS and audit rules, Blueprint M10.2. Blocked by: T12 (staging exists).

## Open questions for engineering
1. Which cases already exist as pgTAP (cross-team RLS) and can be reused against the HTTP API instead of rewritten?
2. Cadence and minutes cost of a scheduled run (with CI2).
