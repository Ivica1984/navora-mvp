# Decision packages: agents prepare, people approve only what is theirs

**Approved by the owner on 2026-10-24** (session with the PO): *"The owner is not expected to be the subject matter expert. The objective is that agents produce a recommendation that is ready for approval."* Applies to every current and future decision in [`OPEN_DECISIONS.md`](OPEN_DECISIONS.md) owned by `owner`, `legal` or `clinical` (the `human-decision` issues). Owner of this process: `po`.

## Principle

No decision reaches a person as an open question. Before anyone is asked, the agents analyse it, gather Engineering, Clinical & Regulatory and Legal & Compliance input, and write a **decision package**: one file `decisions/<ID>.md` from [`decisions/_TEMPLATE.md`](decisions/_TEMPLATE.md), ending in a recommended default and the answer to one question: **does a person actually have to approve this?** If not, the PO decides it. If yes, the person gets a recommendation that is ready to approve or reject.

Until a decision is taken, the safe default already written in its row stays in force. A package never loosens a safe default on its own.

## Workflow

| Step | Who | What | Package status after the step |
|---|---|---|---|
| 1 Analyse | `po` | Read the row, the briefs and code it names, the `cra` findings and the journal. Write *Decision summary*, *Context*, *Options*, a first *Risks* list. Classify which inputs are needed (Engineering always; Clinical when it touches care, documentation, quality, safety or billing; Legal when it touches law, privacy, billing, contracts, labour or compliance) | `inputs-requested` |
| 2 Engineering input | `eng` | Fill *Engineering impact*: what is built today (cite files, migrations, tests), what each option costs, what is reversible | — |
| 3 Clinical input | `cra` | Fill *Clinical impact*: hazards, findings (CGR, PS, H), what a safe default is, what only the Clinical Owner can approve | — |
| 4 Legal check | `po` | Decide whether legal, regulatory, privacy, billing, contractual or compliance questions are involved, and say so in the package | — |
| 5 Legal & Compliance input | `lca` | When step 4 says yes, or the decision touches a topic listed under *When `lca` is involved*: fill *Legal/compliance impact* with the sources it relies on (law, ordinance, tariff contract, guidance), what is settled, what is UNKNOWN, and whether the recommended default is compliant **under every plausible interpretation** | — |
| 6 Recommend | `po` | Fill *Recommended default*, *Confidence*, *Owner approval required* and the reason; then decide or escalate (below) | `po-decided` or `awaiting-approval` |

Inputs are written into the package file itself, each section signed `<role> <date>`. The PO may draft a section from the code and the reports when the input role has not answered within **two of its runs**; it marks the section `drafted by po, not confirmed by <role>` and the package cannot reach confidence *High*.

### When `lca` is involved (owner, 2026-10-24)

The PO requests Legal & Compliance input **automatically** whenever a decision touches billing, reimbursement, tariffs, OKP/KVG/KLV questions, data protection, privacy, retention obligations, contracts, governance or regulatory compliance; and whenever step 4 finds any other legal question.

Rules for the `lca` section:
- **Advisory only.** `lca` never makes a final legal determination. Its verdict is either "compliant under every plausible interpretation" (shown from cited sources) or "unresolved", with the exact question for a legal adviser.
- **Clinical findings first.** When a decision affects clinical safety, documentation, billing, care delivery or professional accountability, `lca` reads the newest Clinical & Regulatory Architect findings (CGR, hazard and risk registers) before drafting, and names the findings it relied on.
- **Missing facts are named.** When compliance depends on the canton, the tariff contract, a payer agreement or an organisational policy, the section says so and names the missing information (for example: pilot canton, D-11; the tariff contract the organisation signs, D-18; the OKP admission, D-12).
- **No repeat reviews.** `lca` reviews a package again only when the package changed since its last signed section, new evidence is available (a decision answered, a source published or found), or another reviewer explicitly asks for a re-analysis in the package or on its issue.

## Priority

The PO works packages in the order of [`decisions/INDEX.md`](decisions/INDEX.md), which follows these tiers (owner, 2026-10-24), ahead of any other ordering:
1. **D-22** (valid medical order) and **D-18** (tariff time rules);
2. every decision referenced by an open or provisional clinical finding (CGR);
3. every decision blocking billing, reimbursement, invoicing, compliance, governance or a production release;
4. all others. Within a tier, what blocks the most work first.

## Who approves: decide or escalate

The PO decides (owner approval **not** required) when all of these hold:
- the decision is a product, operational, workflow or technical choice;
- every legal question in it is resolved by the `lca` input, meaning the recommended default is compliant under every plausible interpretation, or no legal question is involved;
- it approves no clinical rule (a care, safety, quality, LTCF, PAG or MQI rule);
- it is reversible, and touches no live system and no production secret.

Escalate, and only then, when:
- a **legal interpretation remains unresolved** after the `lca` review → `legal` (advisers named by the owner) or, if none are named, `owner`;
- a **clinical governance decision** needs the named Clinical Owner → `clinical`;
- a **commercial, strategic or business** decision is needed → `owner`;
- **regulatory liability** needs explicit owner approval (licence, OKP admission, the legal entity, qualification verification) → `owner`;
- **funding, pricing or partnership** is involved → `owner`;
- carried over from the coordination rules (COORDINATION.md rule 5): an **irreversible production change** or access to the live database → `owner`.

An escalated package names exactly what is asked ("approve option B as recommended" or "pick one of A, C"), the default that applies until then, and what it blocks. The person answers in one line; the PO records the answer in *Decided*.

## Package status (kept in [`decisions/INDEX.md`](decisions/INDEX.md))

`not-started` · `inputs-requested` · `po-decided` · `awaiting-approval: owner` · `awaiting-approval: clinical` · `awaiting-approval: legal` · `decided`

**Confidence:** *High*: inputs from every needed role, sources cited, no UNKNOWN in the recommendation. *Medium*: inputs complete, but one UNKNOWN that the safe default covers. *Low*: an input is missing or an UNKNOWN changes the recommendation. A *Low* package is never `po-decided`.

## Recording

- **PO decides:** the row moves to *Decided* with owner `po`, the answer, the date and a link to the package. The journal entry names it. The rule about *Blocked by* rows (README) still applies.
- **Escalated:** the row stays in *Open* with its owner; its *Recommendation* cell starts with `**Package:** [decisions/<ID>.md](decisions/<ID>.md), awaiting approval: <role>`.
- **Order:** the PO works the backlog in the order of `decisions/INDEX.md` (tiers under *Priority*), about three packages per run, alongside the review cycle.

## Limits

- An agent's legal or clinical analysis is preparation, never advice and never authoritative (D-27 for clinical). It becomes a rule only through a decision taken by the role this file names.
- No package invents a medical, clinical, legal, tariff or regulatory rule. What is not known is written UNKNOWN with the owner who must answer it.
- No personal or health data in any package.
