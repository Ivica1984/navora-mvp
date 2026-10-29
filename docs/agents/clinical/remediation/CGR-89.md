# Remediation plan: CGR-89 (what a move to today leaves behind)

**Finding:** `cra` CGR-89, Clinical Governance Report 2026-10-28 21:30 (PR #623), **advisory S2**. Placed by the PO as **VIS1-8** (`briefs/VIS1.md`, 2026-10-28 22:00). Engineering: ADR-112 (C-2 (b) answered in ADR-111 (6)).

**Risk:** "Heute machen" takes a visit off its planned date. PLAN2 does not re-create it there (ADR-111 (6)), so if it was the client's only visit that day, the day is now without care and no signal fires for it. The nurse is the person who can judge whether that day still needs a visit, but the confirmation did not tell her.

**Affected code and data:** the VIS1-3b confirmation on `/field` (`field-client.tsx`, `features/field/rules.ts`); a new read-only function `public.visit_move_leaves_other_visit` (migration 0090). No data change.

**Steps (IMPLEMENTED in the VIS1 follow-up PR, CI decides):**
1. The server answers one yes/no for a team member of the visit: is another visit of the same client (the case; any team; not cancelled) on the date the visit leaves? Another team's visit counts but is never shown (no time, team, name or count); no new read permission.
2. The confirmation states the fact in one `info` line: "Am <Datum> ist danach kein/noch ein Einsatz bei dieser Person geplant." No block, no extra tap. Without an answer it shows nothing rather than a guess.
3. The move itself and its trail (HAND1, `/team` last change, `moved` row) are unchanged.

**Tests:** pgTAP 090 (none / own team / another team's visit / cancelled / outside the team); vitest `vis1-follow-up` (sentence choice); Playwright `vis1.spec` ("kein Einsatz" and "noch ein Einsatz" at 390 × 844).

**Needs a decision (not coded):** whether a day left without a visit needs a replacement, a threshold or a count rule: Clinical Owner, Clinical Rule Register row first (CGR-89 (3), VIS1-8 (4)). UNKNOWN.
