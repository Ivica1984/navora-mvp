# NAVORA — Security Risk Register

**Last updated:** 2026-10-21 (after T11) · **Evidence:** VERIFIED (seen in code/repo/CI) · INFERRED (from code, not executed) · REPORTED (handover docs only) · UNKNOWN.
Severity reflects impact if real patient data were involved.

| ID | Risk | Severity | Evidence | Mitigation / task | Status |
|---|---|---|---|---|---|
| SR-01 | Care tables readable/writable via `{public}` policies | Critical | Live: REPORTED. Local: was reproduced by `0002` | **Local/CI: CLOSED by T9** (policies dropped, anon privileges revoked; pgTAP + REST check). **Live project: still OPEN** — engineering cannot touch it; O-E containment | CLOSED in code · OPEN on live |
| SR-02 | Server pages query as `anon` (module-level client, no session) | Critical | VERIFIED in code | T8: all queries run through `requireUser()` with the session client; anon client deleted | CLOSED on `feat/auth-ssr` (PR #7) |
| SR-03 | Real code not in version control | Critical → Medium | VERIFIED | Transcribed import on `import/project-src-2026-10-21` + `recovery/main`; byte verification O-C, Codespace O-D | MITIGATED (pending O-C) |
| SR-04 | Next.js below fixes for critical RCEs / Server Action DoS | Critical | VERIFIED | Next 16.4.1, sharp 0.35.5 resolved (CI `npm ls`); `npm audit` 0 | CLOSED on `recovery/main` (still open on `main` until M2) |
| SR-05 | Build against a reachable DB embeds care data in artefacts | High | INFERRED | data pages call `connection()`; CI build shows them dynamic (ƒ) with placeholder env | CLOSED |
| SR-06 | Full patient records serialized to the browser by `/operations` | High | VERIFIED | T10: every Operations select is minimal; DOB, address, phone, contacts, diagnoses, insurance, mobility/cognition, note content are never selected; e2e asserts their absence in the page payload. `/visits` still shows visit notes to every org member (see SR-22) | MITIGATED (PR #9) |
| SR-07 | No route protection; login page links past login | High | VERIFIED | T8: proxy + layout + per-query guard; bypass link removed; e2e covers 6 routes | CLOSED on `feat/auth-ssr` (PR #7) |
| SR-08 | Writes without validation, state check, authorisation or audit | High | VERIFIED | T8 validation · T9 RLS · T10 DB commands with idempotency, DB-enforced state machine, trigger audit on every update path | CLOSED (PR #9) |
| SR-09 | Client sets `billable: true` on visit completion | High (domain) | VERIFIED | T10: `billable` not updatable by app users; `complete_visit` does not set it; pgTAP + e2e | CLOSED (PR #9) |
| SR-10 | No audit trail for any mutation | High | VERIFIED | T10: append-only `audit_events` via trigger on all app-updatable tables; invariant test for future tables. Retention/access rules = Q6 (legal) | CLOSED in code (PR #9) · retention OPEN |
| SR-11 | No migrations; schema only in live DB | High → Medium | VERIFIED | Reconstructed baseline in `supabase/migrations` (CI-applied); live pull O-F | MITIGATED |
| SR-12 | Anon key usable against an open DB (SR-01) | High | INFERRED; deployment UNKNOWN | T8: key not shipped to browsers. T9: anon key reads/writes nothing locally (CI REST check). Live: unchanged until O-E; rotate the live key | CLOSED in code · OPEN on live |
| SR-13 | No security headers / CSP | Medium | VERIFIED | T11: nonce CSP (no unsafe-inline scripts), HSTS, nosniff, DENY framing, Referrer/Permissions-Policy, COOP, no X-Powered-By; e2e: 0 CSP violations. Residual: `style-src 'unsafe-inline'` (TD-01) | CLOSED (PR #10) |
| SR-14 | No branch protection, no required CI, no secret scanning | Medium | VERIFIED (API: "Branch not protected", scanning disabled) | CI exists (T7); protection O-A/O-B | OPEN — owner |
| SR-15 | Invented names/institutions in mock pages | Low–Medium | VERIFIED | hidden by flag (ADR-006) | CLOSED by default config |
| SR-16 | Client-side matching score with demo distances | Medium | VERIFIED | hidden by flag; real engine Gate 4 | CLOSED by default config |
| SR-17 | Secrets in repo | — | VERIFIED: full-history grep for keys / `supabase.co` / `service_role`: none | keep; O-B push protection | CONTROLLED |
| SR-18 | Public repository holds architecture, domain and security-gap documentation | Medium | VERIFIED (`visibility: public`, 0 forks) | Owner decision: make private, or accept; see ADR-016 | OPEN — owner |
| SR-19 | Recovered `src/` is an agent transcription, not a byte copy | Medium (integrity) | VERIFIED (method) | O-C verify script before M2 merge | OPEN |
| SR-21 | Local Auth config had the email provider disabled; sign-in impossible, masked by a test that passed without a session | Low (local only) | VERIFIED in CI (422 `email_provider_disabled`) | fixed config; e2e now asserts sign-in success; CI asserts signup is rejected | CLOSED |
| SR-22 | Every org member, including nurses, reads all cases of the organisation with health fields | High | VERIFIED (T9 policy design, ADR-018) | Q4 permission matrix + T10 minimal selects / column scoping | OPEN |
| SR-23 | `SECURITY DEFINER` helpers bypass RLS on membership tables | Medium | VERIFIED (design) | empty `search_path`, schema not exposed, execute only for `authenticated`, read-only `exists` queries; covered by pgTAP | CONTROLLED |
| SR-24 | Command context in transaction-local settings could leak to later statements in the same transaction (wrong audit attribution, false "duplicate") | Medium | VERIFIED by pgTAP test 28 before merge | `private.end_command()` clears it; test kept as regression | CLOSED |
| SR-20 | Lockfile and types bots can push to feature branches | Low | VERIFIED (workflows) | each bot touches one file, no install scripts; excluded from `main` and `recovery/main` (PR #12); protected branches need review (O-A) | CONTROLLED |

## Rules derived from this register
- No real patient data in any environment until SR-01 (live) and SR-22 are closed, Q4 and Q6 are decided, and PRODUCT_REQUIREMENTS gate 1 is signed off.
- No server deployment of any branch until T11 is merged and the staging host is decided (T12). Staging holds synthetic data only.
- No build or dev server against the live database (SR-05, SR-12).
