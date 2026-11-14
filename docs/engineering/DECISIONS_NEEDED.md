# NAVORA — Decisions needed from the owner

**Prepared:** 2026-10-21 by the Lead Engineer · Engineering is blocked on these items, or will be soon.
Each item gives options, consequences and a recommendation. Recommendations are engineering advice, not legal or financial advice. Items marked **legal** or **financial** need the responsible person to decide.

Ordered by urgency.

---

## D-1 Live database containment (O-E) — urgent, owner only
**Why:** the handover documents report `{public}` policies with `true` on `cases`, `care_visits` and `teams` in the live Supabase project. Everything engineering built (T8–T11) protects only new environments. The live project is untouched.
**Question:** does the live project hold real people's data, and do anon/public policies exist?
**If both are true:** pause the project, or replace the public policies with `false`, before anything else. Then rotate the anon key (SR-12).
**Effort for you:** about 10 minutes in the Supabase dashboard (`OWNER_RUNBOOK.md` §1).

## D-2 Staging hosting (T12) — **financial** + data residency
**Why:** M3 needs a protected staging URL. Engineering cannot create accounts or spend money.
**Options for staging (synthetic data only):**
| Option | Pros | Cons |
|---|---|---|
| A. Supabase project in a Swiss/EU region + Vercel with password-protected previews | fastest; matches the current stack; CI already uses Supabase tooling | Vercel runs outside CH; production residency needs a separate decision |
| B. Supabase EU/CH + a Swiss VPS/container host running `next start` | data stays closer to CH | more setup and operations work |
| C. Fully self-hosted Supabase + app on a Swiss provider | maximum control | highest effort; ops expertise needed |

**Recommendation:** A for staging, because it holds synthetic data only. Decide production hosting separately, together with the DPIA (ADR-011). Check the available Supabase regions when you create the project.
**What engineering needs afterwards:** the project ref plus two GitHub Actions secrets (DB URL for migrations, host deploy token). Engineering then builds the deploy workflow.

## D-3 Permission matrix (Q4 → SR-22) — product + **data protection**
**Why:** today every organisation member, nurses included, can read every case of the organisation with all health fields (placeholder from T9).
**Options:**
| Option | Rule | Consequence |
|---|---|---|
| A. Organisation-wide read (today) | any member reads everything | simplest; weakest data minimisation |
| B. **Team-scoped clinical read** | `nurse`: only cases of their own team(s), and health fields only there; `coach`/`operations`: organisation-wide, but without health fields | fits Teamautonomie and data minimisation; needs one policy and one column-scoped view |
| C. Purpose-based access with care context and break-glass | access only with an active care relationship; emergency access audited | strongest; needs the care-relationship model and an audit review process |

**Recommendation:** B now, C before production (C needs D-6).
**Also needed:** the final role names (`admin`, `coach`, `operations`, `nurse` are placeholders).

## D-4 Audit log retention and access (Q6) — **legal**
**Why:** `audit_events` is append-only and grows without limit. Who may read it, for how long it is kept, and how it is exported are legal questions (DSG; cantonal health-records rules).
**Engineering default until decided:** keep everything; only org `admin` can read.
**Needed:** a retention period, the roles allowed to read, and an export format for audits.

## D-5 Who manages organisations and memberships (Q5)
**Options:** (A) NAVORA staff through an admin console; (B) organisation admins invite their own users; (C) A first, then B.
**Recommendation:** C. Membership changes must be audited like everything else (TD-25).

## D-6 Field tool foundations (F1/F2) — product + **clinical**
**Why:** M4 (`/field`) is the product core. Two facts are missing:
1. **Visit assignment:** is a visit assigned to the team, to one nurse (user account), or to both? Today `care_visits` holds only a free-text `team_member_name`.
2. **Visit state machine:** the DOMAIN_RULES draft (`planned → assigned → accepted → on_the_way → started ↔ paused → completed`, plus `cancelled`/`no_show`) needs clinical/operational confirmation, including who may cancel and what `no_show` triggers.

**Recommendation:** assign visits to a team, with an optional responsible nurse (`user_id`); the team can reassign within itself (Teamautonomie). Confirm the state list and who may perform each transition, and engineering implements it in the database, as was done for the current three states.

## D-7 Repository and branch protection (O-A, O-B, SR-14, SR-18)
- Branch rulesets on `main` and `recovery/main`, with the CI checks `app`, `db` and `e2e` required.
- Secret scanning with push protection.
- **Visibility:** the repository is public, and the security register describes open gaps. Recommendation: make it private.

## D-8 Merge to `main` (PR #3, M2)
Gated on: zip verification (O-C), the Codespace check (O-D), D-7, and your approval. PR #3 now contains T3–T15. Merge with **"Create a merge commit"**.

---

## What engineering continues with meanwhile
Work that doesn't depend on these decisions: further hardening and tests, structured logging without health data (TD-17), and preparation work for D-2 and D-3 that is easy to change once you decide.

## D-9 Legal basis for processing client data at intake (J1) — **legal**
**Why:** converting a referral into a case starts processing health-related personal data. J1 requires a provisional confirmation that the client's consent is present and records who confirmed it and when (ADR-026).
**Question:** is consent the correct legal basis under the revised FADP (DSG) and the applicable cantonal rules, or does processing rest on the care mandate or contract? What must be documented (form, representative, revocation)?
**Engineering default until decided:** keep the confirmation gate; do not collect more client data at intake than name, region and needs.
