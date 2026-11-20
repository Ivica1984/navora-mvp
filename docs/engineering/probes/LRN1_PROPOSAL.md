# LRN1: small quality check for `LEARNINGS.md` (PROPOSED, decision `po`, LRN-1)

Founder 2026-11-20 (live, after PR #1596): `eng` submits the proposal to `po`; **not** part of the BK-f PR; built only **after BK-f**, when `po` places it. This file is a proposal, not a decision. Every estimate below is an ESTIMATE.

## Goal

The founder allowed two automatic checks:
- **Format:** `LEARNINGS.md` keeps its format.
- **Test references:** every test it names as protection exists.

Relevant lessons are to be recorded without turning every small fix into an extra documentation PR or a false alarm. This is quality assurance of the repository, not training of the coding agent.

## Scope (proposed)

1. **Format check:** a new function in `scripts/agents-check.mjs`. It already runs in CI and locally as `npm run agents:check`, so no new workflow is needed. Every entry under «Lektionen» must have:
   - a heading `### [<date>/<ID>] Gelernte Lektion: <title>`;
   - the four lines «Fehlerbild», «Ursache», «Lösungsregel» and «Abgesichert durch»;
   - dates in descending order.

   Missing or garbled lines fail the check.
2. **Test-reference check:** every path in «Abgesichert durch» must exist on the checked commit, for example `supabase/tests/database/156_….test.sql` or `tests/e2e/….spec.ts`. The value `OPEN` is allowed. A lesson whose protecting test is deleted or renamed then turns CI red, so a lesson cannot point at a test that no longer exists.
3. **Relevance instead of «every fix»:** no blanket rule that every `fix(...)` commit needs a new lesson.
   - A lesson is needed only when at least one of these holds:
     - a defect reached `recovery/main`, or a head with a `Paket prüfbereit:` report;
     - a CI job was red on a cause that is not a plain typo in the PR itself;
     - a safety, privacy, RLS, audit or LEAVE1 guard was affected;
     - a merge conflict happened in a shared file.
   - The lesson goes into the same PR as the fix, never into a separate documentation PR.
   - **Proof without a hard gate:** the package handover (`Paket prüfbereit:`) carries one line «Lektionen:». It names the lessons applied, each with its protecting test, or says «keine einschlägig» (founder rule 2026-11-20, see `LEARNINGS.md` Pflicht 6). `po` checks this line in its review.
   - **Optional, only if `po` wants it:** a non-blocking CI notice on PRs whose diff touches `supabase/migrations/` or `supabase/schema/functions/` and whose `LEARNINGS.md` is unchanged. It is a reminder, never red.
4. **Tests for the check itself:** unit tests with a good file, missing lines, a wrong date order, a missing test path, and `OPEN`.

## Not in scope

- A CI gate on commit messages.
- A check that a session «has read» the file. That cannot be proven technically; it is shown by the handover line and by review.
- An evaluation course for `eng` and `po`. The founder named it as a separate proposal for `po`, not part of LRN1.

## Estimate (ESTIMATE)

About one hourly run: about 60–90 lines in `agents-check.mjs`, about 6 unit tests and one CI run. No migration, no user flow, so no `staging-smoke` path.

## Way back

Remove the function from `agents-check.mjs`; the data are not touched.

## Weaknesses named openly

- The check proves form and existence, not that a test really protects the stated property. That stays a review question.
- The relevance criterion is a judgement call. Wrong calls are caught by the PO's review, not by CI.
