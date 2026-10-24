# Remediation plan: CGR-42 (nobody sees that the signal evaluator stopped)

**Written by:** Engineering (`eng`) · 2026-10-24 21:40 (Europe/Zurich) · **Item:** SIG2 condition SIG2-11 (*Next up* 2) · **Brief:** `briefs/SIG2.md` (PO 15:10)
**Finding:** Clinical Governance Report section 2026-10-24 14:27 (PR #294), CGR-42, **advisory (S2)**, decided by the PO as SIG2-11 (product authority; 5 minutes is an operating limit, not a clinical value). ADR-078, migration 0064.

## Risk

The pg_cron job evaluates P1 signals every minute. If it stops, a signal appears only while somebody has a page open, and `/team` still shows the outside channel as "aktiv". Nobody would know that a nurse's phone will stay silent.

## Affected code and data

- `private.evaluate_all_signals`, `public.my_push_state`, `public.team_push_status` (0060, 0062); `/operations`, `/admin`, `/team`, `/settings`.
- New: `private.signal_scheduler_runs` (organisation, last scheduled run; no client data). The live project is not touched.

## Steps

1. IMPLEMENTED (0064): each run of the scheduled evaluator records its time per organisation; page polls do not.
2. IMPLEMENTED (0064): last run older than 5 minutes, or none → `/operations` and `/admin` of that organisation show "Signalprüfung läuft nicht"; `/team` and `/settings` stop showing "aktiv".
3. IMPLEMENTED (0064): the scheduled run asks the sender to dispatch (pg_net + Vault entries, owner sets them, OWNER_RUNBOOK 5a). Missing → nothing sent, 2-minute timeout, Operations at once (fail closed, unchanged).
4. OPEN (owner): enable pg_cron, pg_net and Vault in the pilot project and record the job there (D-2).

## Tests

pgTAP 064: no run → nobody active; run 1 minute ago → active, no warning for Operations; 6 minutes ago → warning for Operations and `/admin` of the organisation, not for another organisation, nothing for a nurse, `/team` and `/settings` not active; a page-poll evaluation records no scheduled run; the scheduled entry point does; no dispatch request without pg_net and Vault; when pg_cron exists, `cron.job` contains the evaluator job. Unit `signals-rules`; e2e `/admin` shows the evaluator status. CI is the runner.

## Needs a decision

- **owner (D-2):** pilot project set-up (pg_cron, pg_net, Vault, the app URL and dispatch secret).
