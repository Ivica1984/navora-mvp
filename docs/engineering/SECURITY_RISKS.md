# NAVORA — Security Risk Register

**Last updated:** 2026-10-21 · **Evidence:** VERIFIED (seen in code/repo/CI) · INFERRED (from code, not executed) · REPORTED (handover docs only) · UNKNOWN.
Severity reflects impact if real patient data were involved.

| ID | Risk | Severity | Evidence | Mitigation / task | Status |
|---|---|---|---|---|---|
| SR-01 | Live DB care tables readable/writable via `{public}` policies | Critical | REPORTED; reproduced locally by `0002_legacy_anon_policies.sql` and asserted by pgTAP | O-E containment now; T9 replaces | OPEN |
| SR-02 | Server pages query as `anon` (module-level client, no session) | Critical | VERIFIED in code | T8 | OPEN |
| SR-03 | Real code not in version control | Critical → Medium | VERIFIED | Transcribed import on `import/project-src-2026-10-21` + `recovery/main`; byte verification O-C, Codespace O-D | MITIGATED (pending O-C) |
| SR-04 | Next.js below fixes for critical RCEs / Server Action DoS | Critical | VERIFIED | Next 16.4.1, sharp 0.35.5 resolved (CI `npm ls`); `npm audit` 0 | CLOSED on `recovery/main` (still open on `main` until M2) |
| SR-05 | Build against a reachable DB embeds care data in artefacts | High | INFERRED | data pages call `connection()`; CI build shows them dynamic (ƒ) with placeholder env | CLOSED |
| SR-06 | Full patient records of all cases serialized to the browser by `/operations` | High | VERIFIED | T10 minimal selects. Removed one unused full-record query (`getCasesWithVisits`) | OPEN |
| SR-07 | No route protection; login page links past login | High | VERIFIED | T8 | OPEN |
| SR-08 | Browser writes to `teams`, `care_visits` without validation, state check or audit | High | VERIFIED | T10 | OPEN |
| SR-09 | Client sets `billable: true` on visit completion | High (domain) | VERIFIED | T10 | OPEN |
| SR-10 | No audit trail for any mutation | High | VERIFIED | T10 | OPEN |
| SR-11 | No migrations; schema only in live DB | High → Medium | VERIFIED | Reconstructed baseline in `supabase/migrations` (CI-applied); live pull O-F | MITIGATED |
| SR-12 | Anon key in any deployed build; with SR-01 = open DB | High | INFERRED; deployment UNKNOWN | O-E; rotate after T9 | OPEN |
| SR-13 | No security headers / CSP | Medium | VERIFIED | T11 | OPEN |
| SR-14 | No branch protection, no required CI, no secret scanning | Medium | VERIFIED (API: "Branch not protected", scanning disabled) | CI exists (T7); protection O-A/O-B | OPEN — owner |
| SR-15 | Invented names/institutions in mock pages | Low–Medium | VERIFIED | hidden by flag (ADR-006) | CLOSED by default config |
| SR-16 | Client-side matching score with demo distances | Medium | VERIFIED | hidden by flag; real engine Gate 4 | CLOSED by default config |
| SR-17 | Secrets in repo | — | VERIFIED: full-history grep for keys / `supabase.co` / `service_role`: none | keep; O-B push protection | CONTROLLED |
| SR-18 | Public repository holds architecture, domain and security-gap documentation | Medium | VERIFIED (`visibility: public`, 0 forks) | Owner decision: make private, or accept; see ADR-016 | OPEN — owner |
| SR-19 | Recovered `src/` is an agent transcription, not a byte copy | Medium (integrity) | VERIFIED (method) | O-C verify script before M2 merge | OPEN |
| SR-20 | Lockfile bot can push to any non-`main` branch | Low | VERIFIED (workflow) | scoped to `package-lock.json`, no install scripts; required review on protected branches (O-A) | CONTROLLED |

## Rules derived from this register
- No real patient data in any environment until SR-01, SR-02, SR-06–SR-10 are closed and PRODUCT_REQUIREMENTS gate 1 is signed off.
- No server deployment of any branch until SR-13 is closed and T8 is merged.
- No build or dev server against the live database (SR-05, SR-12).
