# Remediation plan: CGR-92 (a member without a recorded qualification can start and complete visits)

**Finding:** `cra` CGR-92, Clinical Governance Report 2026-10-29 09:25 (PR #662, comment on #647), **blocking for ADM2 acceptance, S2; does not block the merge**. Placed by the PO as **ADM2-16** (`briefs/ADM2.md`, 10:15; rides #647). `lca` 09:45 (PR #663): the remedy is compliant under every plausible interpretation. Engineering: ADR-117, migration 0094.

**Risk:** 0091 lets a member admitted by her team exist without a recorded qualification. She is never responsible or covering (ADM2-6), but `start_visit` and `complete_visit` run as her, any team member may write the visit status, and the state machine checked qualification only for category B and needs assessments (CGR-12). She could perform and complete category A/C visits of her team before anyone has checked her qualification.

**Affected code and data:** `private.transition_visit` (0007, patched by 0089), `private.enforce_visit_transition` (0090), `toCommandResult` (`src/lib/commands/result.ts`). No data migration; seeded members all have a qualification.

**Steps (IMPLEMENTED in #647, CI decides):**
1. `private.actor_may_perform_visit`: the caller has a recorded qualification in the visit's team, or in the cover team when she is the covering nurse.
2. Command path: depart, start, resume and complete refused with `qualification_missing`, nothing changed, one audit row.
3. Direct path: the state machine refuses the same transitions (42501 `qualification_missing`).
4. App: one sentence for the outcome.

**Tests:** pgTAP `094_adm2_16_no_visit_without_qualification.test.sql` (32), brief (i)-(iii); (iv) pgTAP 038 and 090 unmodified. vitest `command-result`.

**Needs a decision (not coded):** billability of a visit already performed by such a member: **D-29** (owner, legal adviser; unchanged). OPEN for `cra` (ADR-117 deviation 1): whether `record_no_show` and `end_visit_not_completed` also need a recorded qualification; today they are not gated (they record that care did not happen or was interrupted).
