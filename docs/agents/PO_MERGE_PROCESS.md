# Product Owner merge process (proposal)

**Owner:** `po` · **Status:** IN FORCE since 2026-11-05 12:00 CET (owner decision in the PO session, section 0a); first merges #799, #833, #838; scheduled runs: the PO's own docs PR #874 merged at 16:35, an Engineering PR refused at 14:46 (section 0a) · **Written:** 2026-11-05 (Europe/Zurich), after the owner's decision on #861.

## 0. Owner decision (2026-11-05, recorded as given)

- **Option C rejected.** Engineering gets no merge authority.
- The Product Owner is the only role responsible for review, acceptance, merge decisions and delivery governance.
- The PO merges Engineering PRs on its own, with no further owner approval, when **all seven conditions** in section 4 hold. It then reviews, accepts, merges and updates the milestone status.
- Engineering keeps implementing. Merge authority stays with the PO.

## 0a. Owner decision (2026-11-05, second message, recorded as given)

- The PO remains the only role authorized to merge pull requests; Engineering gets no merge authority.
- The PO may autonomously review, accept and merge completed sprint work once the seven conditions of section 4 hold (the owner's wording: CI green; no blocking Clinical & Regulatory finding; no blocking Legal & Compliance finding; belongs to an approved brief, milestone or roadmap item; no unresolved review comments; matches the approved architecture; matches the approved roadmap and current milestone plan). **No further owner approval is required.**
- After every merge the PO carries out section 9 (post-merge responsibilities and agent communication) and verifies roadmap, milestone and dependency alignment; any deviation is documented and communicated.
- Objective: Engineering builds; the PO reviews, accepts, merges and coordinates the team.
- **Effect on section 3:** the merge call was accepted in the PO session on 2026-11-05 (#868, #799, #833, #838). Whether the *scheduled* PO task's permission check accepts it is UNKNOWN until its next run; asks 3 (1)-(3) stay on the owner agenda as optional operational settings, no longer as a precondition.
- **Scheduled run, 2026-11-05 14:46 CET (IMPLEMENTED fact): refused.** The scheduled PO task's permission check refused the merge call for #800 (head `7d286e8`, all seven conditions met) as "merge without review", the same refusal as at 06:05. The PO did not work around it. So the PO merges only in an owner-attended PO session; scheduled runs prepare the merge record and stop. **Ask 3 (1), and (2) if (1) is not enough, is again a precondition for scheduled merges** (`OWNER_AGENDA.md` bundle 1, "Merge in scheduled runs").
- **Scheduled run, 2026-11-05 16:35 CET (IMPLEMENTED fact): accepted for the PO's own docs PR.** The merge call for PO PR #874 (head `ccac0f4`, conditions 1 and 5: 4/4 green, `clean`, no review thread) succeeded (`7cc0f9f`). Whether the scheduled check also accepts an Engineering PR is **UNKNOWN**: after #874 merged, no Engineering PR met condition 1, so none was tried. The next scheduled run that finds one conflict-free tries it once (with the merge record comment first); a refusal is recorded and not worked around. The bundle 1 ask stays until that is known.

## 0b. Owner approval and merge test run (2026-11-06, IMPLEMENTED facts)

- **Owner approval (FE-033):** the merge paragraph of section 3 (1) is now in the scheduled PO task's prompt, together with the founder block for all agent tasks; the PO task runs hourly at minute 39 (Europe/Zurich). **Condition set by the owner:** run the merge process once as a complete test on exactly one suitable change, document it, and only then apply it to further PRs.
- **Test run, attended session 2026-11-06:** PR **#800** (UX2-27 + UX2-29, head `797029c`, no migration). Section 4: all seven conditions met (merge record comment on #800 with evidence). Merge commit `30de12f` with the head SHA passed to the merge call. Section 5: CI on the merge commit (push run) green: `app`, `db`, `e2e`, `ui-screenshots`. Acceptance of UX2 waits for the remaining UX2 parts (UX2 is one brief). **Result: passed.**
- **From now on:** the scheduled PO task merges one Engineering PR per run under section 4, then role docs PRs, then its own PR. The stop rule "one Engineering PR per run" stays in force (conflicts).

## 1. Why nothing merged until 2026-11-05 (IMPLEMENTED facts, checked 2026-11-05) (IMPLEMENTED facts, checked 2026-11-05)

| # | Cause | Evidence | Effect |
|---|---|---|---|
| 1 | **The PO's merge call is refused before it reaches GitHub.** The scheduled PO session runs with an automatic permission check. That check refused `PUT /pulls/799/merge` and `PUT /pulls/868/merge` as "merge without review". GitHub never answered; the token itself can push and open PRs. | PO journal 2026-11-05 06:05; PR #868 comment 05:19 UTC | Nothing merges, not even the PO's own docs PR. `aia` reports the same refusal for its docs PRs (10:56 entry). |
| 2 | **The PO task's stored prompt does not tell it to merge Engineering PRs.** It says "merge PO PRs" (step A) and assumes Engineering PRs arrive merged (step C: "`in-review` once its PR is merged with green CI"). The Engineering task says the opposite: "DO NOT merge … for the Product Owner to review and merge". | Both scheduled-task prompts, read 2026-11-05 | The permission check has no stored owner instruction to rely on, so it treats the merge as unrequested. |
| 3 | **The PO runs once a day.** The task's schedule is 06:00 Europe/Zurich daily; its prompt says "you run hourly". | Scheduled task "NAVORA Product Owner agent" | At most one merge a day against 17 waiting. |
| 4 | **Every merge makes the other PRs conflict.** Each Engineering PR edits `IMPLEMENTATION_STATUS.md`, `docs/engineering/DECISIONS.md` and `JOURNAL.md`. A trial merge: #799 merges cleanly, all seven later ones conflict. The PO may not resolve Engineering's files. | Trial merge 2026-11-05 06:05 | Merges are serial: one per PO run, then Engineering resolves the conflicts in its next run. |
| 5 | **Nothing tells the PO that a PR is ready.** The watcher opens a `po:<ID>` hand-off only for `ready-for-review`/`delivered` on `recovery/main`; an unmerged PR sets `in-review` only on its own branch. | `eng` analysis on #861 (`plan.mjs` l. 59-61) | The PO has to find green PRs itself. |

## 2. What changes (summary)

| Change | Who | Kind |
|---|---|---|
| A. PO task prompt: add the merge step and the seven-condition gate (section 4), in the owner's words | **owner** (agents never edit scheduled tasks) | scheduled-task prompt |
| B. PO task permission: allow the merge call for the PO task | **owner** | scheduled-task setting |
| C. PO task schedule: hourly, at minute 39 (Engineering runs at :09, so conflicts are resolved before the PO looks) | **owner** | scheduled-task schedule |
| D. `scripts/po-merge-gate.mjs`: reports conditions 1-6 per PR as data, with unit tests | `eng` builds it after the owner's go; the PO specifies it (section 5) | code, one PR |
| E. Fewer conflicts: one journal file per entry (AUT-49, adopted as direction 10:56) and one file per ADR | `eng`, together with D | code and docs |
| F. Branch ruleset on `recovery/main`: PR required; `app`, `db`, `e2e` required checks; no force-push (D-7, already on the owner agenda) | **owner** | GitHub setting, backstop |

A, B and C unblock delivery. D, E and F make it safe and fast; they are not preconditions for the first merges.

## 3. The permission or workflow change required (the ask)

1. **Prompt (A).** Add this paragraph to the PO task's stored prompt, in place of step A's first sentence. Suggested wording:

   > "A. Merges. You are the only role that merges into `recovery/main`. Each run, merge (merge commit) the next Engineering PR (branch `feature/`, `feat/`, `fix/`) in *Active now* order, and any open role docs PR (`po/`, `gov/`, `lca/`, `ux/`, `aia/`, `csa/`), when every condition of `docs/agents/PO_MERGE_PROCESS.md` section 4 holds for its current head. Record the merge as section 6 says. If any condition fails or is in doubt, do not merge; comment once naming the condition."

2. **Permission (B).** The refusal comes from the scheduled session's automatic permission check, not from GitHub. Whether the stored instruction in (1) is enough for that check to let the merge through is **UNKNOWN**. If it is not, the owner allows the merge call (`PUT /repos/Ivica1984/navora-mvp/pulls/{n}/merge`) for the PO task in that task's permission settings. The exact settings screen is UNKNOWN to the PO; nothing else in the session needs to change.

3. **Schedule (C).** Set the PO task to hourly at minute 39 (`CRON_TZ=Europe/Zurich 39 * * * *`), as its prompt already says.

Until the owner has done 1-3, the safe default holds: nothing merges, Engineering keeps its PRs green and free of conflicts, and no new UX2 part starts.

## 4. The merge gate: seven conditions, how each is checked

All seven conditions must hold **for the head commit being merged**. The PO writes down that SHA, and the merge call passes it (`sha` parameter) so GitHub refuses the merge if the head moved.

| # | Owner's condition | How the PO checks it | Source |
|---|---|---|---|
| 1 | All CI checks green | Every check run on the head is `completed` / `success` (today: `app`, `db`, `e2e`, `ui-screenshots`); none pending, skipped or cancelled; no bot run waiting for approval. `mergeable_state` = `clean`. | `GET /commits/{sha}/check-runs`, `GET /pulls/{n}` |
| 2 | No blocking Clinical & Regulatory finding | No open `cra` finding marked blocking, or marked advisory "before merge", that names this PR, its item or a file it changes. Read in the newest `CLINICAL_GOVERNANCE.md` section on `recovery/main` **and** on open `gov/` branches. If `cra` cleared an earlier head, `git diff <cleared head> <head> -- src supabase tests e2e` must be empty (AUT-50); otherwise wait for `cra`. Items in the clinical review gate (README rule 6) need an explicit `cra` gate line for the PR. | `cra` reports, PR comments |
| 3 | No blocking Legal & Compliance finding | No package that the item depends on has an `lca` verdict "unresolved" that the PR's content relies on; no open `lca` comment on the PR asking for a stop. A legal question with no signed `lca` section counts as unresolved. | `decisions/*.md`, PR comments |
| 4 | Belongs to an approved brief, milestone or roadmap item | The PR names an item ID; the item has a status row and an approved brief (`briefs/<ID>.md`, status not draft), and is in the queue, *Next up* or *Active now* of `NEXT_CAPABILITY.md`, or is a finding remedy (`CGR-`, `AUT-`, `UXR-`) the PO placed there. | `NEXT_CAPABILITY.md`, brief |
| 5 | No unresolved review comments | Unresolved review threads = 0; no review in state "changes requested" still standing; every PR comment from `cra`, `lca`, `uxa`, `aia` or `csa` with a finding ID is answered or closed. | `GET /pulls/{n}/ccr/review_threads`, `GET /pulls/{n}/reviews`, comments |
| 6 | Introduces no blocked capability or decision package | Every decision listed under the item's "Blocked by" is decided. The diff adds nothing a frozen or undecided package excludes (for example D-39: no sensor or device data intake). No real personal or health data; no reference to the live project. | `OPEN_DECISIONS.md`, `decisions/INDEX.md`, diff |
| 7 | Consistent with the approved architecture and roadmap | The PO reads the diff against the brief and `ARCHITECTURE.md`: RLS, column grants and audit trigger on every new table or command; no bypass of RLS or audit logging; a migration only adds or tightens, or its ADR says why not; a `.github/` change weakens no check (no job, test or required step removed); scope matches the brief, and listed deviations are decided. | PR diff, ADR |

**Extra stop rules (all stage 0, synthetic data only):**

- Never merge into `main`, never force-push, never resolve conflicts in Engineering's files. A conflicting PR waits for Engineering.
- One Engineering PR per run; the next waits for its conflicts to be resolved.
- Order within a run (PO, 2026-11-05 16:30): the next Engineering PR first, then role docs PRs, the PO's own open PR last. Every PR edits `JOURNAL.md`, so the first merge makes the rest conflict; the Engineering PR is the one that must not wait.
- G-3 is not decided by this process: before real data, a named human approves each migration that touches clinical or billing logic.
- Role docs PRs: conditions 1 and 5 apply, plus "the PR touches only that role's own files and no `src/`, `supabase/`, `tests/` or `e2e/` file" (CGR-135). Conditions 2-4, 6 and 7 do not apply to them.
- The PO never merges its own code (it writes none) and never accepts its own work: a PO docs PR is merged on conditions 1 and 5 alone, and acceptance does not apply.

## 5. After the merge: acceptance and milestone status

1. Wait for CI on the merge commit.
2. **Green:** write the evidence table in the brief (criterion | result | evidence), stating that the PO did not run the tests; set `accepted` in `NEXT_CAPABILITY.md`, or `changes-requested` with testable reasons; decide every listed deviation; update `ROADMAP.md` and the milestone in `DELIVERY_PROGRAM.md`. Acceptance activates the next approved item.
3. **Red on the merge commit:** `changes-requested`, naming the failing check; Engineering fixes forward. The PO opens a revert PR only when the red check is a patient-safety test (for example SIG1 delivery), and merges it under this same gate.
4. If the merge-commit CI does not finish within the run, acceptance happens in the next run.

## 6. Audit trail for every merge

- **Merge record comment on the PR before the merge:** head SHA, the seven conditions with result and evidence link each, the `cra` gate line, and "PO merge under `PO_MERGE_PROCESS.md` section 4".
- **Merge commit title:** `PO merge #<n>: <item> (head <short sha>)`.
- **Journal entry** for the run, listing merged PRs and, for each PR not merged, the failed condition.
- **Brief evidence table** after acceptance (section 5).
- GitHub keeps the merge actor, time and SHA. With F, the ruleset also proves the checks were required.

## 7. `scripts/po-merge-gate.mjs` (specification for `eng`, change D)

- Input: a PR number. Output: JSON `{pr, head, conditions: {1..6: {result: pass|fail|unknown, evidence}}}` plus a list of open findings that name the PR, item or files. It never merges and never writes to GitHub.
- `unknown` counts as fail. Condition 7 and the review stay with the PO.
- Unit tests (vitest) with fixtures for: a pending check; a blocking `cra` finding on an unmerged `gov/` branch; a cleared head followed by a code push; an unresolved thread; an item whose "Blocked by" decision is open; a role docs PR touching `src/`.
- Built in one PR with the CGR-135 role-scope check and AUT-49 (one journal file per entry), as adopted on 2026-11-05 10:56.

## 8. What happens first once A-C are in place

The first runs merge in *Active now* order: #799, #800, #803, #804 (UX2), then #810 (CGR-110; `cra` widened the remedy to pgTAP 064, so a follow-up stays open), #814, #815, #813, then the remaining green PRs, including the role docs PRs and the FAM1 inputs (`lca` #860, `cra` #862-#867). At one Engineering PR per hour, the 17 waiting PRs take about a day.

## 9. Post-merge responsibilities and agent communication (owner, 2026-11-05)

After every merge, in the same run, the PO:

1. updates the roadmap status (`ROADMAP.md`, German);
2. updates milestone progress (`docs/product/DELIVERY_PROGRAM.md`, newest status section);
3. updates sprint status (*Active now* in `NEXT_CAPABILITY.md`);
4. records completed deliverables (journal entry; brief evidence table on acceptance);
5. records dependency changes (what is unblocked, which PRs now conflict);
6. records new blockers;
7. notifies every relevant agent in the journal entry, one line each:
   - `eng`: what was merged, what is unblocked, what starts next (including which open PRs must merge `recovery/main` in);
   - `cra`: which workflows changed, whether a new review is required;
   - `lca`: whether a new regulatory review is required;
   - `uxa`: whether the build differs from the approved design, which screens are now implemented;
   - `aia`: whether AI-related capabilities became available, new automation opportunities;
   - `csa`: milestone progress, roadmap changes, delivery risks, deviations from strategic direction.

For every merged sprint the PO checks roadmap alignment, milestone alignment and dependency alignment and writes any deviation into the journal entry and the milestone status.
