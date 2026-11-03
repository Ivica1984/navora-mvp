# NAVORA AI Capability Roadmap

**Author:** Product Owner (`po`) · **Date:** 2026-11-03 (Europe/Zurich) · **Basis:** owner's Strategic Architecture Directive (2026-11-03); [AI-First Architecture Update](AI_FIRST_ARCHITECTURE_UPDATE.md); [AI Opportunity Map](AI_OPPORTUNITY_MAP.md); staged AI path ([Strategic Alignment Review](STRATEGIC_ALIGNMENT_REVIEW.md) §3, owner-approved 2026-10-27). **Status:** PLANNED. Items here become buildable only through an approved brief in `docs/agents/NEXT_CAPABILITY.md`.

---

## 0. Owner directive 2026-11-03 14:00 (post-PR #822)
- **Allowed now, synthetic data only:** PLAN3, AN3, AIO1, OPS2, HAND2. No real patient, employee or production data; compliant with D-1, D-34 and D-35. The PO writes the missing briefs (AIO1, OPS2, HAND2).
- **Frozen, specification only:** D-39 (sensors, IoT) and D-40 (Family Layer, Check-In Services). No implementation, table, migration or production architecture until owner approval. Packages opened 2026-11-03 for decision support.
- **Not in the allowed list:** DOC2. It stays a proposal until the owner adds it.
- **Mandatory sequence** for every item: Remove → Rules → Monitor → AI prepares → Human reviews → Human decides → Human signs (update §0).

## 1. Principle of the sequence

1. **Foundation before agents.**
   - The governance layer (AIG1) is IMPLEMENTED.
   - Next come the orchestrator, the agent contract and the evaluation harness, so every later agent is a configuration plus an evaluation set, not a project.
2. **Rules and monitors before language models.** They run now, on synthetic data and later on real data, without D-35 stage 1.
3. **Baseline before removal.** AN3 measures each administrative step before an AI capability removes it.
4. **Level L before G before H.** Clinical AI (H) runs only in the separately qualified clinical module (D-34 C).
5. **No gate is skipped.** The directive accelerates the order of work; it does not lift D-35 A, D-34, D-1, G-1 or P-1.

## 2. Stages and domains

| Stage | Entry conditions | Domains and capabilities | Status |
|---|---|---|---|
| **0 Foundation (now)** | none beyond the queue; synthetic data | AIG1 governance (IMPLEMENTED; AIG1-C4/-C5 PLANNED); **AIO1** orchestrator, agent contract, evaluation harness; **PLAN3** assignment proposal (domain 5); **AN3** baseline; **OPS2** control health and exception grouping by rule (domain 6); **HAND2** handover ordered by rule (domain 2); **DOC2** proof of delivery from events (domain 1, `cra` on P-2); quality indicators as rules (domain 7, AN2 extension) | AIG1 IMPLEMENTED; rest PLANNED |
| **1 Administrative AI** | owner opens the D-35 stage-1 package (provider with processing in CH/EU, contract, DPIA, sub-processors; `lca` conditions 1-10); 3 stable pilot months | language for L agents: exception explanations (domain 6), order renewal request A2 (after D-22), insurer-dispute and compliance letters (A4, A5), referral completeness questions to the referrer (A1, domain 9), Family Companion logistics answers (domain 3, after D-40), Nurse Assistant intents over L domains (domain 10) | OPEN (owner) |
| **2 Documentation assistance** | regulatory adviser on level G (D-34); the Clinical Owner's one-by-one field list (D-17 part 3); stage-1 correction rates below their thresholds | dictation into structured entries (A7; domains 1 and 10); check-in collection of client-reported logistics facts (domain 4, L part) | OPEN |
| **3 Clinical module** | owner approved the module target (D-34 C, done 2026-10-27); conformity route; Clinical Owner; D-36/D-37 licence; evaluation evidence from stages 0-2 | report and handover drafting (A9; domains 1, 2); intake extraction (A8; domain 9); care-plan review proposals (A10); evidence layer for assessments (A11; domain 8); check-in interpretation and sensor-based risk signals (domain 4; #817, D-39); quality-event clustering (domain 7) | OPEN |

## 3. Recommended roadmap changes

### 3.1 Queue (`NEXT_CAPABILITY.md`)
1. **Unchanged first:** finish the UX2 PRs already cleared, CGR-110, UX2 remainder, AIG1-C4 with AIG1-C5, **PLAN3**. PLAN3 is the first AI-first coordination capability and needs no gate beyond labour-law rules.
2. **New brief AIO1 (approve after PLAN3 is in build):** AI orchestrator and agent contract.
   - One server-side pipeline: scope check, minimisation, model or rule, schema validation, source-per-claim check, ledger write.
   - An agent contract table (§5.1 of the update).
   - An evaluation harness in CI that runs each agent version on its synthetic case set and records correction rates.
   - A provider adapter interface with **no provider configured** (D-35 A). An `ai` agent still refuses to switch on.
   - Level L, synthetic data.
3. **AN3** (draft): approve after `lca`'s read; build before G-19.
4. **New briefs OPS2, HAND2 (owner-approved for synthetic development 2026-11-03), DOC2 (proposal only)** (stage 0, rules only):
   - **OPS2:** control health A6 and exception grouping by rule.
   - **HAND2:** handover entries ordered by rule, unread-before-start fact.
   - **DOC2:** a visit that went as planned produces its proof of delivery from events, and the report asks for text only on deviations. `cra` must confirm P-2 first, with D-10 and documentation duties; `lca` on the canton's documentation rules, after D-11 (#816).
5. **Every brief from now on has the section *AI leverage*** (brief template), answering the six steps of the update §3.

### 3.2 Decisions (packages to open or move)
| Package | Question | Owner | Why now |
|---|---|---|---|
| **D-35 stage 1 (new package)** | provider, model region (CH/EU), contract, DPIA, sub-processors for L agents on staff and administrative data | owner (`lca` conditions 1-10) | without it no language model runs on real data; it is the main blocker of an AI-first pilot |
| **D-34 adviser** | name the regulatory adviser; answer the adviser questions incl. 7 and 8 (EU AI Act) | owner | needed before stage 2 and before the clinical module's design |
| **G-1** | name the Clinical Owner | owner | gates every clinical AI rule, every one-by-one list and nine clinical packages |
| **D-39 (opened 2026-11-03; frozen, specification only)** | sensors in a client's home: legal basis, household consent, retention, device law | owner, `lca`, `cra` | prerequisite for domain 4 with sensors |
| **D-40 (opened 2026-11-03; frozen, specification only)** | client- and relative-facing AI (Family Companion, Check-In): transparency, consent per relative, representation, liability, which answers may be routed or drafted (never clinical advice) | owner, `lca`, `cra` | prerequisite for domains 3 and 4 |

### 3.3 Handbook and documents
- `ARCHITECTURE.md`: new principle block *KI-Säule* (AI-1 to AI-12), an *AI Layer* bounded context, the data flow with the orchestrator, and the target structure with `ai/`.
- `CARE_OPERATING_MODEL.md`: the section *AI-first means graph-first* is replaced by *AI-first operating model* (the six-step method), and three new actors are named (client and relatives, GP, discharge planner as AI-served channels).
- `PRODUCT_REQUIREMENTS.md`: *KI und Automation* rewritten as a core requirement.
- `ROADMAP.md`: an AI track in German.

## 4. What the owner is asked (one line each)
1. **Open the D-35 stage-1 package:** "approve that the PO prepares a provider package (processing in CH/EU) for level-L agents on staff and administrative data."
2. **D-34:** name the regulatory adviser.
3. **G-1:** name the Clinical Owner.
4. **Done 2026-11-03 14:00:** the owner allowed PLAN3, AN3, AIO1, OPS2 and HAND2 on synthetic data. DOC2 is not in that list and waits.

## 5. How progress is measured
- **Administration removed per step:** AN3 spans before and after each capability (per team and month, never per person).
- **North Star:** direct care share (WORK1-6), with its balancing measures (returned reports, corrections, quality events; P-5).
- **Agent evidence:**
  - correction rate and later errors per agent and field;
  - share of proposals confirmed unchanged;
  - expired proposals (AIG1-C4);
  - stops.
- **Continuity:** distinct nurses per client and primary-nurse share (J6), before and after PLAN3.

## Change log
- 2026-11-03 po: created from the owner's Strategic Architecture Directive.
- 2026-11-03 14:00 po: owner directive *post-PR #822 alignment* taken in (§0; D-39, D-40 opened and frozen; allowed list).
