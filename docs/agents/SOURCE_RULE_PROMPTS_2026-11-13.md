# Two-source rule in the agent prompts (FE-077)

**Owner:** Product Owner (`po`) · **Date:** 2026-11-13 15:10 (Europe/Zurich) · **Authority:** founder directive FE-077 (2026-11-13): Blueprint V3.2 and Architecture Handbook V2.2 are approved and are the project's only working references; all older versions are archived.

## 1. Where the rule is anchored (IMPLEMENTED in the repository)

1. **`docs/agents/README.md` rule 13.** Every role reads it first, every run. This is the binding text for all seven roles.
2. **`CLAUDE.md`** lists only the two sources to read before any architecture or code change and names the archived documents.
3. **Archive notices** at the top of `ARCHITECTURE.md`, `docs/product/ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md` and the October handover documents in the repository root (`MASTER_CONTEXT.md`, `PRODUCT_REQUIREMENTS.md`, `DOMAIN_RULES.md`, `TECHNICAL_DECISIONS.md`, `CURRENT_IMPLEMENTATION_STATUS.md`, `DATABASE_AND_DATA_MODEL.md`, `INTEGRATIONS.md`, `TESTING_AND_QUALITY.md`).
4. **Blueprint V3.2 and Handbook V2.2** carry «freigegeben (FE-077)» and «einzige Quelle» in their headers.

## 2. Scheduled-task prompts (OPEN: owner step)

Several scheduled-task prompts still name archived documents. For example, the PO prompt names `ARCHITECTURE.md` as the «primary architectural source of truth» and Blueprint V2 as the «execution reference»; others name `MASTER_CONTEXT.md` and `DOMAIN_RULES.md`. Until the prompts change, README rule 13 and rule 10 hold. A role that meets the contradiction follows rule 13 and names it in its journal entry.

The PO does not edit scheduled tasks itself. The founder (or a session he asks to do it) replaces, in **every** NAVORA agent prompt (`po`, `eng`, `cra`, `lca`, `uxa`, `aia`, `csa`, weekly engineering status), every sentence that names `ARCHITECTURE.md`, Blueprint V2, `MASTER_CONTEXT.md`, `PRODUCT_REQUIREMENTS.md`, `ROADMAP.md` as a strategic source, `DOMAIN_RULES.md` or `CURRENT_IMPLEMENTATION_STATUS.md` as a source with this paragraph:

> SOURCES (owner, FE-077, 2026-11-13; binding; README rule 13): The only product source (WHAT, WHY, block order) is `docs/product/ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md` (Blueprint V3.2). The only technical source (HOW: components, engines, data model, RLS, tests) is `docs/architecture/ARCHITECTURE_HANDBOOK_V2.md` (Handbook V2.2). Blueprint V1.x to V3.1, `ARCHITECTURE.md`, the root handover documents, old specifications, chat notes and drafts are archived: never cite them or derive a requirement from them. Newer founder decisions in `docs/product/FOUNDER_DECISIONS.md`, briefs, ADRs, decision packages and `cra` registers stay in force under the two sources. Facts about the code: the repository code wins; document a deviation and fix the Handbook by ADR.

For the PO prompt, the start-of-run reading list then becomes: `CLAUDE.md`, `docs/agents/README.md`, `COORDINATION.md`, `FOUNDER_DECISIONS.md`, Blueprint V3.2, Handbook V2.2, `PO_MERGE_PROCESS.md` §4-9, `DECISION_PACKAGES.md` and `decisions/INDEX.md`, `NEXT_CAPABILITY.md`, `IMPLEMENTATION_STATUS.md`, `OPEN_DECISIONS.md`, `PRODUCT_BLOCKS.md`, the newest journal files, `CARE_OPERATING_MODEL.md`. The PO's «maintain Blueprint as living document» duty moves from V2 to V3.2 (version table), and the Friday founder report is written from Blueprint V3.2 chapter 10 (metrics).

## 3. Claude project knowledge

The project «NAVORA» on claude.ai holds older drafts under `claude/product/…`. These are ignored. The pointer document `claude/SOURCES_FE-077.md` names the two sources, and the PDFs live in the repository under `docs/product/blueprint-v3/pdf/`. Older project docs are not deleted by an agent: they are files the founder uploaded or reviewed, and deleting them stays the founder's call.
