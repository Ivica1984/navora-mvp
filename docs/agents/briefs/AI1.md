---
id: AI1
title: Erste angeschlossene KI-Funktion — Berichtsentwurf aus den Worten der Pflegenden mit echtem Modell (synthetische Daten, Staging)
author: po
status: approved
updated: 2026-11-20
---

# AI1 — First connected model function: report draft from the carer's own words

**Origin:** founder message 2026-11-20 ca. 09:20 (FE-099 (4)): «PO und AI Architect: Legt mir eine entscheidungsfähige Empfehlung für die erste tatsächlich angeschlossene Modellfunktion mit synthetischen Daten vor. Engineering bewertet ihre technische Integration.» **Status:** PO recommendation for the founder's decision; `aia` reviews it in its next run (13:17), `eng` rates the integration in its next run. Founder decisions §7 answered 2026-11-20 ca. 09:45 (FE-099 (7)); the PO writes the package contract when AI1 becomes active (after STAB1). **Gate:** «Simulation, synthetic data». D-35 rule A unchanged for real persons. PO did not run tests.

## 1. What the AI does for the user

At the end of a shift the carer types (or dictates with her phone keyboard, Phase A only) a few lines in her own words on `/field` → «Bericht». The model turns them into a structured report draft: one line per observation or measure, each line linked to the words it came from, plus a list «nicht gefunden» for report fields her words do not cover. She checks each line, corrects or removes it, and signs. Nothing is binding before her signature; after it, BK-f builds the invoice draft from the signed version.

## 2. Why this is the best first proof

- **Value order 1 and 5:** less typing at the end of every shift, for every carer; the work that takes time away from care (`eng` self-assessment area 7, `aia` bottleneck map row Documentation).
- **Almost built:** the path exists on `recovery/main` and is tested with a fake: provider interface, Claude provider (`src/lib/ai/report-draft/anthropic-provider.ts`), single resolver with kill switch, staging-only and simulation-organisation guards (`config.ts`), source per line and «not found» control (`control.ts`), AIG1 proposal ledger and database gate (0151, 0153), stop rule (AUT-152, `cra` simulation test value). What is missing is the connection, a cost limit and an evaluation against the real model.
- **Safe failure:** if the model is off, slow or wrong, the carer still has today's rule-based draft or an empty form; no care, time or billing fact depends on the model.
- **Not first:** AI order capture (BK-d) changes order data that teams act on; it reuses the same gateway as the second function. Matching stays fixed rules: an AI score never replaces a qualification check.

## 3. Fixed rule, test substitute, connected model

| Part | Today (IMPLEMENTED unless marked) | After AI1 |
|---|---|---|
| Report draft on staging | test substitute «regelbasiert, keine KI» | **connected model** (Claude, as FE-094 decides) for the simulation organisation on `navora-staging` only; label on screen «KI-Entwurf, bitte prüfen» |
| Source per line, «nicht gefunden», no line without a source | fixed rule (`control.ts`) | fixed rule, applied to every model answer; a line without a source is dropped and counted |
| Units and numbers (CGR-261) | open finding | fixed rule: a number or unit not in the carer's words is refused (Q2 item moved here) |
| Stop rule (AUT-152, AUT-160) | fixed rule, simulation value | fixed rule; counts discarded and undecided drafts too (CGR-262/AUT-160, moved here) |
| Signature | human, required | human, required; the model never signs or sets `final` |
| Matching, planning, billing | fixed rules | unchanged |

## 4. Inputs and outputs, and who checks them

- **Input:** only the carer's free text for one visit, plus the visit's ordered activity tags. No name, birth date, address or record history is sent (data minimisation; a test proves the request body holds no such field). Synthetic seed only; the resolver refuses any non-simulation organisation and any host other than staging (IMPLEMENTED guards).
- **Output:** structured JSON (lines, source spans, not-found list). Invalid JSON or a schema violation → no draft, rule draft shown, event logged (fail closed).
- **Checked by:** (1) the fixed validator on every answer; (2) the carer, line by line, before signing; (3) `eng` with an evaluation set of synthetic cases (S2 cases generalised, Q2) run against the real model on staging per prompt version: share of lines with a correct source, invented facts (target 0), missed facts, latency p95, tokens and cost per draft; (4) `aia` reads the evaluation report; `cra` gives the gate line on «no invented or dropped clinical fact» on the reported head (gate start under FE-089 (2)).

## 5. Cost and shut-off limits (proposal; the money amount is the founder's)

- Kill switch `AI_KILL_SWITCH` (IMPLEMENTED): any value except empty or `off` stops every call.
- **New:** a hard cap per day and per month in the gateway, counted in the database, fail closed when reached (300 calls per day; CHF 50 per month, founder FE-099 (7)). At most one model draft per report version and one retry; input capped (proposal 4,000 characters); answer capped (proposal 1,024 tokens instead of today's 4,096); timeout 30 s (IMPLEMENTED).
- Tokens, latency and cost per call recorded (team level, never per person); a cost figure is labelled measured or estimate. Price per call: UNKNOWN until measured.
- Automatic stop: stop rule (AUT-152) or an evaluation run with any invented fact switches the model off for the organisation until `eng` and `cra` clear it.

## 6. Where the founder operates it on staging

In **AI1**, right after STAB1: carer `pflegebs` → `/field` → taken shift → end → «Bericht» → type three lines → «Entwurf erstellen» → draft with source links and «KI-Entwurf» label → correct one line → «Bericht unterschreiben»; then BK-f: the team sees the invoice draft. `staging-smoke` gets this path with the model switched on for the run (and a second path with the kill switch on: rule draft, no call).

## 7. Decisions only the founder makes (answered 2026-11-20 ca. 09:45, FE-099 (7): (1) FE-094 confirmed; (2) CHF 50 per month; (3) the PO starts `lca` as a gate of AI1; (4) unchanged: the founder sets the Render values after the ready report)

1. **Provider for this proof:** FE-094 (2026-11-19) already chose «Anthropic API direct, synthetic data, staging only». The founder's message of 2026-11-20 says he decides the provider on the basis of this paper. **Contradiction, not resolved by the PO:** confirm FE-094, or name another provider. PO recommendation: confirm FE-094 (code, guards and host list are built for it; synthetic data only; for real persons FE-085 (A) CH/EU endpoint and zero retention stays the direction and D-35 rule A stays).
2. **Monthly cost cap** in CHF for staging.
3. **Terms reading:** FE-094 (c) keeps a `lca` reading of the provider terms before the first activation open; `lca` is paused (FE-089). Either the PO starts `lca` for this reading as a gate of AI1 (recommended), or the founder states that it is not needed for synthetic data.
4. **Key:** only the founder sets `AI_MODEL_API_KEY`, `AI_MODEL_PROVIDER=anthropic`, `AI_MODEL_NAME` and `AI_REPORT_DRAFT_MODE=model` in the Render environment of `navora-staging`, after `eng` reports AI1 ready; never in chat, GitHub or a document.

## 8. Not in scope

Audio recorded or processed by NAVORA; any real person; another model function; automatic signature; any change to matching, qualification limits or billing rules; production.
