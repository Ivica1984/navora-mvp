---
id: AIR1
title: AI restrictions enforced in code (owner directive 2026-11-03, #824)
author: po
status: accepted
updated: 2026-11-06
---

# AIR1 — AI restrictions enforced in code (acceptance record)

**Origin:** owner directive 2026-11-03 14:00, relayed by `po` on issue #824 (full text: `docs/product/AI_FIRST_ARCHITECTURE_UPDATE.md` §0, §6.1; `NEXT_CAPABILITY.md` *Owner directives 2026-11-03*). There was no separate PO brief: the directive's five numbered duties are the acceptance criteria. Engineering proposed the build (`eng-proposal`, ADR-141). This file records the PO review.

## Acceptance criteria (from #824)
1. Enforce in code: no automatic billing decision; no automatic clinical recommendation to patients or relatives; no automatic clinical prioritisation of safety signals; no unrestricted general-purpose copilot on production data; no AI replacing an accountable human decision.
2. Flag every proposal, ADR or PR that violates them.
3. Pin each testable guard with a test; name which guards already had tests and which are new.
4. D-39 and D-40 frozen: no code, table, migration or production architecture.
5. Synthetic data only.

## Review 2026-11-06 19:39 CET (scheduled PO run)

Reviewed on merged evidence: #828 (merge commit `bdf42bd`, head `9ef6327`), migration `20261021000107_aig1_prohibited_targets.sql`, pgTAP `108_ai_prohibited_targets` (22 assertions), vitest `tests/unit/ai-prohibited-targets.test.ts` (5 cases), ADR-141. CI: PR run on head `9ef6327` green (`app`, `db`, `e2e`, `ui-screenshots`). The push run on the merge commit `bdf42bd` was **cancelled** by the next push (concurrency group); the next commit `9a15f98` changes only docs files against `bdf42bd` (`git diff --name-only bdf42bd 9a15f98`: 11 files, all under `docs/` or `ROADMAP.md`), and its push run 42270491204 and PR run 42270504568 are **success** on all four jobs. The PO takes that as CI on the merged code. `cra` gate: `cra-gate: #828 e90f2d1 clear` (`CLINICAL_GOVERNANCE.md`), own code identical on `9ef6327` (merge record on #828). **The PO did not run the tests**; results come from reading the diff, the tests, the ADR and the CI check runs.

| Criterion | Result | Evidence |
|---|---|---|
| 1 Billing: no AI path decides or writes billing | **met** | `private.aig1_prohibited_target` names `billable_facts`, `billing_rules`, `tariff_rates`, `quality_holds`; trigger on `ai_agent_fields` refuses them for any class with 42501 (pgTAP 108 `throws_ok` lines 45-52, insert and update); pg_proc catalogue check: no AIG1 ledger, confirm or apply function writes these tables |
| 1 Safety-signal priority: no AI path sets or changes it | **met** | same classifier for `safety_signals`, every `signal_*` table, `exception_rules`, `exception_rule_overrides`; pgTAP 108 refusal and catalogue check; vitest "covers every billing, tariff or signal table any migration creates" |
| 1 Clinical recommendations to patients or relatives | **met (nothing to guard)** | no route or role for clients or relatives exists (ADR-141 *Not done*); D-40 frozen |
| 1 General-purpose copilot on production data | **met** | no AI service is called; kind `ai` refused at switch-on (pgTAP 097, D-35 rule A) and none registered (pgTAP 108) |
| 1 AI replacing an accountable decision | **met** | a value reaches a record only through `confirm_suggestion(s)` with a named confirmer (AIG1-3, pgTAP 097, existing) |
| 2 Flag violations | **met** | ADR-141 *Review of existing paths*: AIG1 and SIG1 compliant; J5 flagged for `po` (decided below) |
| 3 Tests, existing vs new named | **met** | ADR-141 *Guards with tests before this ADR* (097) and *New here* (items 1-5) |
| 4 D-39, D-40 frozen | **met** | no file of either package touched; no sensor, device or family table in 0107 |
| 5 Synthetic data only | **met** | pgTAP fixtures only; no live-project reference in the diff |

### Deviations and flags, decided by `po`
- **No runtime trigger on `billable_facts` or `safety_signals` keyed on the AIG1 context (ADR-141 *Not done* 1): accepted.** The register is the only entry for an assistant's value; the catalogue check turns CI red if a later AIG1 function writes a listed table. A context trigger could refuse a correct SIG1 rule write in the same transaction. Not requested.
- **J5 flag (automatic billable fact from a signed report): no change, no owner question.** The directive prohibits AI deciding billing. J5 is a fixed rule on a report that a nurse signed, with no open hold, and it sends no invoice: step 2 "Apply rules" of the owner's mandatory sequence, not an assistant's decision. D-18 (billing time rules) stays `awaiting-approval: owner` and is not changed by this answer.
- **CGR-115 (`cra` advisory S3) becomes condition AIR1-C1:** before the first register field other than the synthetic test agent's, the guard also covers the settings and inputs that decide when a signal or escalation fires and what billing is computed from (`cra` 2026-11-03 17:30 list: `organization_watched_hours`, `cover_settings`, `case_safety_alert_values` and the others named there), **preferably as an allow-list** (a register field is accepted only for a column that has a `cra` row), or ADR-141 names the reason per table. pgTAP: one refusal per added table. `eng` decides how.

**PO status: `accepted`** (2026-11-06 19:39 CET). AIR1-C1 open, not in the queue until a second register field is proposed.
