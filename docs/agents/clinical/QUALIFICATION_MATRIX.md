# Qualification and Activity Matrix (QAM): activities, contexts, roles and their use in planning

**Maintained by:** Clinical & Regulatory Architect (`cra`; review role, an AI agent, not a licensed clinician) · **Requested by:** the founder, 2026-11-06 (FE-039; founder letter of 2026-11-06 evening, "Qualifikationsmatrix: Einsatzkontexte, Rollen, KI-Planung, Ausfallfall") · **Checked with:** `lca` (legal questions L-1 to L-10, issue #924); `po` (data needs §6, simulation §7) · **Version:** 0.2, 2026-11-06 22:35 CET (v0.1: 21:50, PR #923) · **Status of every cell, rule and role: PROPOSED.** Nothing here is `APPROVED` or *freigegeben*. Only the approval function decided under D-43 can release a cell or rule, and only a qualified person (D-27). Phase A modelling and testing on synthetic data are **not** a release for real care (founder, 2026-11-06).

**What this matrix is not:** it is **not a "matrix prescribed by the BAG"**. No federal text contains such a matrix. The activity limits are derived from several layers (§1.2), each with its own source and its own owner. Where a layer was not read, the cell says so.

**Register rows:** CR-174 to CR-178 (v0.1) and CR-179 to CR-184 (v0.2) in [`CLINICAL_RULE_REGISTER.md`](CLINICAL_RULE_REGISTER.md), section *Proposed rules (not in code)*. Findings: CGR-145, CGR-146 (v0.1), CGR-147, CGR-148 (v0.2) in [`../reports/CLINICAL_GOVERNANCE.md`](../reports/CLINICAL_GOVERNANCE.md).

No personal or health data in this file. All examples are synthetic.

---

## 0. Three things that are not the same (my understanding, in my own words)

- **Professional responsibility (*fachliche Verantwortung*)** belongs to one activity, one client and one point in time. It asks: is the person who does this competent, and has someone qualified checked that she is, for this client? It rests on a person's qualification and, where needed, on a named delegation by a qualified nurse who then also supervises. It can sit with a team member who is otherwise an equal colleague. It gives her no power over anyone's roster.
- **A formally required function (*formell erforderliche Funktion*)** is a position that a law or licence ties to an **organisation**: for example the Pflegedienstleitung of a BS nursing home, or the *pflegefachverantwortliche Person* of a BL Spitex organisation. It exists because the organisation holds a licence, not because a task is being done. It answers to the authority: for staff, for rules and for quality. It is held by one named, licensed person and a deputy. It applies to the licence holder. It does **not** automatically attach to every team that works for or inside that organisation.
- **Hierarchical operational leadership (*hierarchische Einsatzleitung*)** decides who works when and where, and gives day-to-day instructions. NAVORA does not need it: the team organises its own day. But neither of the first two may be dropped by pointing at self-organisation. Where a licence ties directive authority to the formal function (§3.3, limit L-2), that authority is held and documented. It is then exercised through rules, delegations and exceptions, not through daily dispatching.

---

## 1. Basis

### 1.1 What changed against v0.1

1. **Current law partly read.** Since 1 July 2024, Pflegefachpersonen may provide and bill the KLV Art. 7 Abs. 2 **Bst. a** services (assessment, advice, coordination) and **Bst. c** services (Grundpflege) **without a medical order**. Bst. b (examination and treatment) still needs a medical order. The family doctor must be informed (KLV Art. 8a Abs. 1bis) [Q10, Q11]. In nursing homes, billing by care level still needs a doctor's confirmation of a new level [Q10]. **The consolidated KLV text in force is still not read** (`lca` L-1). These points come from the BAG Q&A and the ARTISET leaflet, not from the ordinance.
2. **Licensing read for BS and BL Spitex.**
   - **BS:** a Spitex organisation needs at least one *pflegeverantwortliche Fachperson*, a Pflegedienstleitung with a practice licence and a deputy (§ 22 Bewilligungsverordnung, cited by the canton). Every person working "fachlich eigenverantwortlich" needs a practice licence (HF/FH) [Q12].
   - **BL:** the application names a *pflegefachverantwortliche Person* and a deputy: HF/FH diploma, at least **two years' full-time practice** under a qualified nurse, B2 German, criminal record extract, and a staffing plan with qualifications [Q13].
   - This supersedes v0.1's "BS/BL Spitex rule not read" (CGR-146 evidence widened).
3. **Four contexts** instead of two (§2). External team in a nursing home, the home's own teams, hospital (inside and after discharge), private person.
4. **Six functions** kept apart (§3), with a proposal for scoped professional responsibility without line authority (§3.2) and its limit (§3.3).
5. **Per-row fields** (§4.3): requirement beyond the grade, delegation conditions, who grants, reviews and revokes, evidence and validity, responsibility, sources, status.
6. **Planning use** (§6), **cover simulation acceptance criteria and negative tests** (§7), **pre-pilot confirmation list** (§8), **K and L questions as options with consequences** (§9).

### 1.2 Where activity limits come from (four layers)

| Layer | Question it answers | Source type | Owner of the reading |
|---|---|---|---|
| L1 Insurance law | Which services exist, who must assess, what needs a medical order, what is billable | KVG, KVV, KLV [Q1, Q10, Q11] | `lca` (L-1) |
| L2 Training scope | What a grade may do at all | Bildungspläne, Rahmenlehrplan, SRK rules [Q3, Q4, Q9] | Clinical reviewer, `lca` for currency (L-4) |
| L3 Health-police and licensing law | Who must hold a licence, which functions an organisation needs, staffing | Cantonal health law and licences [Q6, Q7, Q12, Q13] | `lca` (L-2, L-7) |
| L4 Organisation rules | What this organisation allows this person for this client: competence rules, delegation | The licence holder's own *Kompetenzenordnung und Delegationsregeln* [Q5], approved by its formal function | The organisation (F5, §3) |

A cell is only as strong as its **weakest layer**. NAVORA can hold L4 as structured data (matrix version, delegations). It cannot replace L1 to L3.

### 1.3 Status vocabulary (per cell, per rule, per role)

The founder's four steps, in order. Each step is recorded with person, date and source; none is skipped.

| Status | Meaning | Who sets it | Usable for |
|---|---|---|---|
| `PROPOSED` | Architect's proposal with sources; may contain **?** | `cra` | Phase A synthetic modelling only, shown as provisional |
| `fachlich geprüft` | A qualified nurse (D-43 approval function) has checked the cell against practice and training scope | the D-43 approval function | Phase A; not real care |
| `rechtlich geprüft` | `lca` has checked layers L1 and L3 with sources and found no open legal question. Where `lca` says "needs legal adviser", the adviser has answered | `lca`; `legal` where required | Phase A; not real care |
| `freigegeben` | Approved for a named context, canton and validity date by the D-43 approval function, **and** adopted by the formal function F5 of the organisation that applies it (D-43 option D) | D-43 function plus F5 of the organisation | real care (Phase B), in that context and canton only |

**Mapping to the PO's vocabulary (#924):** `unresolved` means a **?** cell, or a cell whose layer is unread. `provisional` means `PROPOSED`, `fachlich geprüft` or `rechtlich geprüft`. `confirmed` means `freigegeben`.

**Hard rule (CR-179):** only `freigegeben` counts as proof of suitability for real care. A **?** cell counts as **–** in every phase, including Phase A, so the simulation never shows suitability that is unresolved.

---

## 2. Four contexts

### 2.1 Context table

The same activity can have different requirements in different contexts. **No rule is assumed to carry over.**

| Code | Context | Who holds the licence for the care | Who bills (KVG) | Which matrix applies | Status |
|---|---|---|---|---|---|
| **NH-OWN** | A nursing home organises its own teams and its whole care day with NAVORA (B2B) | the home (BS: Pflegeheimbewilligung with Pflegedienstleitung and deputy, HF/FH, practice licence [Q6]; BL: pflegefachverantwortliche Person and deputy [Q7]) | the home, by care level (BS: RAI levels; BL: UNKNOWN, `lca` D-22); doctor confirms a new level [Q10] | the **home's** matrix version (L4), approved by its F5; NAVORA's matrix is the template | PROPOSED |
| **NH-EXT** | An external self-organised team takes a job in a nursing home (for example cover for an absence) | the **home** for its residents' care; the team for its own conduct; how the two split is **UNKNOWN** (L-7) | the home bills the resident's care level; the team is paid by the home under a contract (no separate KVG billing per activity is plausible: UNKNOWN, L-7) | **UNKNOWN which**: the home's version, the team's, or a joint *Einsatzvereinbarung* (§2.3) | unresolved |
| **HOSP-IN** | A team works inside a hospital | the hospital (cantonal hospital licence and hospital list) | the hospital, by hospital tariffs (Art. 49 KVG); not KLV | **not this matrix.** The KLV rows do not apply inside a hospital. The hospital's own competence rules apply | out of scope for Phase A; **no proposal** (§6.4) |
| **HOSP-POST** | A team takes a job from a hospital for after discharge | the team as an admitted home-care provider (Art. 51 KVV organisation or Art. 49 KVV nurse; BS: Betriebsbewilligung, OKP admission [Q12]; BL [Q13]) | (a) **acute and transitional care** (AÜP): ordered **by the hospital physician**, at most **two weeks**, hospital financing rules (Art. 25a Abs. 2 KVG [Q14]); (b) otherwise ordinary home care under KLV | home-care matrix (rows as NH-OWN), plus **input conditions**: the order, the discharge information, and for AÜP its end date | PROPOSED |
| **PRIV** | A team takes a job for a private person (at home) | the team, as above. A private person cannot hold professional responsibility or delegate nursing activities | (a) KVG: only as an admitted provider; Bst. b needs a medical order; Bst. a and c not since 2024-07-01 [Q10, Q11]; (b) self-pay: no KVG, but BS still requires a practice licence for work "fachlich eigenverantwortlich" [Q12] | home-care matrix | PROPOSED |

### 2.2 Responsibility of the commissioning party versus the executing team

| Context | Commissioning party carries (PROPOSED reading; L-7 to L-10) | Executing team carries |
|---|---|---|
| NH-OWN | (home and team are one licence holder) the formal function F5, the matrix version, the staffing duty ("erforderliches Fachpersonal" [Q6, Q12]) | operative coordination F1; case and delegation acts F3, F4 inside the home's rules |
| NH-EXT | the residents' care under its licence; the **activity list** of the job; the medical orders and care plans of its residents; the staffing duty, which **does not pass to the team** by contract (UNKNOWN, L-7) | the members' qualification and evidence; that each member does only activities that are E for her, or D under a valid delegation; its own coordination; reporting a gap at once |
| HOSP-IN | everything clinical, under the hospital's rules and instructions (likely staff hiring, L-8) | the members' qualification and evidence; conduct; nothing that NAVORA can plan by this matrix |
| HOSP-POST | a correct order (AÜP: hospital physician) and the discharge information; it does **not** carry the care after discharge | the whole home-care responsibility: needs assessment by a Pflegefachperson, care plan, delegations, documentation, escalation, informing the family doctor (Art. 8a Abs. 1bis) |
| PRIV | none clinically; consent, access to the home, payment | everything clinical, as HOSP-POST; the medical order for any Bst. b activity |

### 2.3 Consequence for NH-EXT (the founder's main use case)

Whichever legal form applies (L-7), **one resident's activity must have exactly one delegation source and one escalation addressee.** Two parties each assuming the other checked is the hazard (H-33, new). Proposed control (CR-182): before an NH-EXT job is offered to a team, NAVORA records a structured **Einsatzvereinbarung** with:
- the context and the canton;
- the activity list (matrix rows), with the medical order present yes/no for each Bst. b row;
- whose matrix version applies;
- who may delegate D activities for this job: (i) the home's nurse, or (ii) a nurse of the team who has the residents' information;
- the home's reachable formal function, or a named substitute, for escalation;
- start and end.

If any field is missing, the job **cannot be offered**: NAVORA shows what is missing, and no suitability is shown. Which option (i) or (ii) is lawful is L-7. Until it is answered, Phase A simulates both, and Phase B allows **neither** without `rechtlich geprüft`.

---

## 3. Six functions

### 3.1 The functions

| # | Function | What it is | Who can hold it | What it may do in NAVORA | What it may **not** do | Required by (source) | Status |
|---|---|---|---|---|---|---|---|
| **F1** | Operative coordination of the team | the team's own decisions on who does what and when, by the rules the team agreed | any member, by the team's rule (rotating, consensus, or a coordinator the team chooses) | plan, swap, take, accept or change AI proposals (the existing PLAN3 confirm, take, swap and hand assignment) | override F2 or F3 checks; mark anyone as suitable; give a delegation | nothing found that requires a line manager for this (ZH requires no ward leader [lca L9]; BS/BL ward level not read) | PROPOSED |
| **F2** | Qualification for an activity | an **attribute of a person**: grade, recognised evidence, additional competence or experience (for example two years for A3 and A4 [Q1]), and an instruction where the row asks for one | each person, for herself | maintain her profile; self-confirmation is recorded but is **not evidence** (FE-039) | check her own evidence | L1, L2 | PROPOSED |
| **F3** | Delegation, instruction and supervision | an **act**: a qualified nurse entrusts a D activity to a named member for a named client, instructs her and supervises | a `nurse_hf_fh` with verified evidence and, where required, a practice licence [Q12], of the party that carries the client's professional responsibility (§2.2) | record, review, extend (not beyond the limit set under K-4), revoke | delegate what is **–** or **?** for the grade; delegate to herself; delegate without an instruction date; an AI never does any of this (D-40) | delegation conditions "ausgewählt, instruiert und überwacht" [Q2, Q5]; BS/BL applicability L-3 | PROPOSED |
| **F4** | Professional responsibility within a team | **case responsibility** (*Fallverantwortung*): the needs assessment, the care plan and its evaluation for one client, and being the first contact for that client's clinical questions; plus an optional **team professional contact** for qualification questions | a `nurse_hf_fh` member of the team, one per case (the primary nurse already in NAVORA, CR-051); rotatable by the team | assess (A1), plan, set the activity list of the client's visits, delegate (F3), escalate | assign anyone's visit; change anyone's roster; approve the organisation's matrix version | Bedarfsermittlung by a Pflegefachperson [Q1 Art. 8a; Q11] | PROPOSED |
| **F5** | Formally required function of an organisation | the licence's named *Pflegedienstleitung* or *pflegefachverantwortliche Person* and its deputy; **only for the licence holder** | the person named in the licence (BS: HF/FH with practice licence, deputy [Q6, Q12]; BL: HF/FH, two years' practice, deputy [Q7, Q13]) | adopt the organisation's matrix version (L4) and its delegation rules; read every delegation and revoke one; be the last escalation for qualification and coverage; receive unresolved gaps | dispatch; plan anyone (CGR-146 test) | BS § 22 Bewilligungsverordnung as cited [Q12]; BS nursing homes [Q6]; BL Spitex [Q13] and homes [Q7] | PROPOSED; the duties in detail are L-2 |
| **F6** | Clinical release of rules NAVORA automates | approving matrix cells and register rules as `fachlich geprüft` and `freigegeben` for a context, a canton and a validity date | the D-43 approval function (named professional or review board; owner decision) | change a cell's status; never a single visit | plan; delegate; act as F5 for a partner | D-27, D-43 | OPEN (D-43) |

**F5 applies to the organisation that holds the licence, not to every team** (founder's point 2). An external team in NH-EXT is not thereby required to have a Pflegedienstleitung. If the team itself is a licensed Spitex organisation (HOSP-POST, PRIV), it needs its own F5 [Q12, Q13]. Whether an NH-EXT team must be one is L-7.

### 3.2 Proposal: professional responsibility without line authority

1. **Responsibility is attached to an object, not to a rank.**
   - F3 attaches to one delegation (activity, client, member, dates).
   - F4 attaches to one case.
   - F5 attaches to one organisation's licence and its matrix version.

   Each is a recorded **mandate** with a start, an end and the person who holds it.
2. **Each mandate has a closed list of commands**, the same pattern as the RLS read paths. F3 and F4 commands are *delegate, revoke, assess, plan the care of this case, escalate*. F5 commands are *adopt matrix version, revoke any delegation, receive escalations*. **No mandate includes a command that assigns or moves another person's visit or shift.** That stays F1, with the same checks for everyone.
3. **Holding a mandate changes nothing in the roster rights.** A primary nurse is an equal team member in F1.
4. **Visible, not hierarchical.** Each delegation shows its delegating and supervising nurse, and each case shows its F4. Anyone in the team can see who answers for what. Nobody needs to "ask the boss" for a shift.
5. **Testable** (CGR-146, CGR-148): for every role, a pgTAP test that a holder of F3, F4 or F5 cannot run any assignment command on another member's visit that a plain member could not run; and that only F5 can adopt a matrix version.

### 3.3 Limit and alternative

Where a licence requires the organisation chart to show **directive and supervisory authority** of the nursing function, and a **written** delegation for any responsibility handed outside the management (ZH, read by `lca` [lca L9 2.4.1, 3.4]; BS and BL equivalents UNKNOWN, L-2), the formal function cannot be purely advisory. **Alternative:** F5 holds the directive authority formally, limited to professional matters. A written document from F5 hands the daily organisation (F1) to the self-organised team, and NAVORA keeps that document's version and date. F5 then acts through:
- the matrix version;
- the delegation rules;
- revoking a delegation;
- the escalation path.

F5 does not act through rosters. If an authority rejects this arrangement for a licence (L-2, L-7), the alternative fails for that licence. The fallback is a conventional nursing lead for that organisation, with the team keeping F1 by that lead's written delegation. This is a founder decision with commercial consequences (§9, FD-Q2).

---

## 4. The matrix

### 4.1 Legend

- **E**: within the grade's own scope, **inside the care plan set by the case's F4 nurse**. May be planned without a delegation.
- **D**: only with a **valid delegation** (F3) for this client and this activity, inside the grade's training scope.
- **–**: not to be planned for this grade.
- **?**: UNKNOWN. Treated as **–** in every phase (CR-179).

**E never includes the needs assessment.** Every Bst. b activity additionally needs a **medical order** in the client's record (KLV; [Q11]: "muss in jedem Fall vom Hausarzt verordnet werden").

### 4.2 Grade values (home care: HOSP-POST, PRIV; nursing home: NH-OWN; NH-EXT only after L-7)

Rows marked **[seed]** are used by the synthetic seed today (`Abklärung`, `Medikamentengabe`, `Wundversorgung`, `Grundpflege`, `Mobilisation`). They are modelled first (FE-039).

| # | Activity (Verrichtung) | KLV | HF/FH | FaGe EFZ | AGS EBA | PH SRK | trained other | Change v0.1 → v0.2 |
|---|---|---|---|---|---|---|---|---|
| A1 **[seed]** | Needs assessment and planning of measures, incl. reassessment | Bst. a Ziff. 1; Art. 8a | **E** (since 2024-07-01 without a medical order; inform the family doctor) [Q1, Q10, Q11] | – | – | – | – | order rule added |
| A2 | Advice to client and relatives | Bst. a Ziff. 2 | **E** (no order since 2024-07-01) [Q10] | ? | – | – | – | order rule added |
| A3 | Coordination in complex and unstable situations | Bst. a Ziff. 3 | **E** with ≥ 2 years' experience [Q1 Abs. 2bis] | – | – | – | – | – |
| A4 | Psychiatric needs assessment (Abs. 2bis cases) | Abs. 2bis | **E** with ≥ 2 years' psychiatric experience [Q1] | – | – | – | – | – |
| B1 | Vital signs, weight | Bst. b Ziff. 1 | **E** | **D** [Q3 D.1] | **D**, values reported at once to the responsible professional [Q4 1.6] (K-6) | ? | – | – |
| B2 | Venous and capillary blood sampling | Bst. b | **E** | **D** [Q3 D.2] | – | – | – | – |
| B3 **[seed]** | Preparing and administering medication | Bst. b | **E** | **D** [Q3 D.3]; high-risk drugs ? (K-2) | – [Q4 2.4] | – | – | high-risk split out |
| B4 | s.c. and i.m. injections | Bst. b | **E** | **D** [Q3 D.6]; **insulin ?** (K-2) | – | – | – | – |
| B5 | Infusion without additives on an existing peripheral line | Bst. b | **E** | **D** [Q3 D.4] | – | – | – | – |
| B6 | Tube feeding on an existing access | Bst. b | **E** | **D** [Q3 D.5] | – | – | – | – |
| B7 **[seed]** | Dressing change, primary and secondary wound healing | Bst. b | **E** | **D** [Q3] | – | – | – | – |
| B8 | Complex wound care (e.g. negative pressure, wound assessment) | Bst. b | **E** (specialist training ?, K-3) | ? (K-3) | – | – | – | HF/FH extra competence flagged |
| B9 | Bladder catheter, insert and remove | Bst. b | **E** | **D** [Q3 B.3] | – | – | – | – |
| B10 | Breathing support, oxygen, inhalation on order | Bst. b | **E** | **D** [Q3 B.4] | – | – | – | – |
| B11 | Putting on medical compression or anti-thrombosis stockings | Bst. b or c: ? | **E** | ? | **D** [Q4 1.4] | ? (BAG example: staff with a Pflegehilfe course put on stockings [Q11]; not a rule) | ? | BAG example added; stays ? |
| B12 | Compression bandages | Bst. b | **E** | ? | – [Q4] | – | – | – |
| B13 | Any other Bst. b activity | Bst. b | **E** | ? | – | – | – | – |
| C1 **[seed]** | Grundpflege: hygiene, dressing, excretion, **mobilisation**, transfers, eating and drinking, prophylaxis | Bst. c Ziff. 1 | **E** | **E** [Q3]; BAG calls the FaGe's showering "delegiert" [Q11] (K-7) | **E** [Q4] | **E** [Q9] | **E** with selection, instruction and supervision [Q2] | delegation wording flagged |
| C2 | Daily-life support in psychiatric illness | Bst. c Ziff. 2 | **E** | ? | ? | ? | – | – |
| C3 | Recognise an emergency and get help | – | **E** | **E** | **E** | **E** | **E** | – |
| N1 | Non-KLV support (structure of the day, household, accompanying) | – | **E** | **E** | **E** | **E** | **E** | – |

**Context modifiers (CR-180):**
- **HOSP-IN:** every row **?** (not this matrix).
- **NH-EXT:** every **D** becomes **?** until L-7 names the lawful delegation source. Every **E** in rows B* also becomes **?** until the Einsatzvereinbarung (§2.3) is complete.
- **NH-OWN:** as in the table, inside the home's own version. Shift-level minimums are K-5 and NH-A.
- **HOSP-POST AÜP:** the order is the hospital physician's, and its end date (at most 2 weeks [Q14]) bounds every visit. A visit after the end date has no order.

### 4.3 Per-row fields (the founder's list, point 3)

**Generic answers** apply unless a row says otherwise:
- **Grant:** a `nurse_hf_fh` (F3) of the party holding the client's professional responsibility (§2.2), with verified evidence and a practice licence where the canton requires one.
- **Review:** the delegating nurse on every reassessment; F4 of the case; F5 at any time.
- **Revoke:** the delegating nurse, F4 of the case, or F5, at any time. Revocation is automatic on expiry, on a grade change, when evidence lapses, or when access ends.
- **Evidence validity:** UNKNOWN unless stated. A diploma or certificate has no expiry. The **practice licence**, the **delegation** and any **instruction** do. Their periods are K-4 and L-1.

| # | Requirement beyond the grade | E / D conditions | Evidence NAVORA needs (who may check it: D-29, L-9) | Professional responsibility | Sources | Status |
|---|---|---|---|---|---|---|
| A1 | Pflegefachperson under Art. 49 KVV; practice licence (BS [Q12]) | E only for `nurse_hf_fh`; never delegable | diploma; NAREG entry; cantonal practice licence (expiry as issued) | F4 of the case | Q1, Q10, Q11, Q12 | PROPOSED |
| A2 | as A1 | E HF/FH; FaGe ? | as A1 | F4 | Q1, Q10 | PROPOSED |
| A3, A4 | as A1, plus ≥ 2 years (A4: psychiatric) | E only with recorded experience | employment certificates (BL asks this form for F5 [Q13]) | F4 | Q1 | PROPOSED |
| B1 | AGS: report values at once | D: delegation names the thresholds for reporting **from the client's care plan** (NAVORA sets none) | grade evidence; delegation record | delegating nurse | Q3, Q4 | PROPOSED |
| B2 | instruction in the organisation's sampling standard | D | grade evidence; instruction date | delegating nurse | Q3 | PROPOSED |
| B3 | medical order with medication list in the record; instruction in the organisation's medication standard | D; high-risk drugs (list UNKNOWN) ? (K-2) | grade evidence; delegation; the order present | delegating nurse; the prescribing physician for the order | Q3, Q11 | PROPOSED |
| B4 | as B3 | D; insulin ? (K-2) | as B3 | as B3 | Q3, Q5 | PROPOSED |
| B5, B6, B9, B10 | existing access; instruction | D | grade evidence; delegation; order | delegating nurse | Q3 | PROPOSED |
| B7 | wound documentation standard; instruction for this wound | D; the delegation may carry the condition "only while stable" | grade evidence; delegation; order | delegating nurse | Q3 | PROPOSED |
| B8 | wound specialist training: UNKNOWN whether required (K-3) | ? for FaGe | specialist certificate if K-3 requires it | F4 | – | PROPOSED, unresolved |
| B11, B12 | KLV category UNKNOWN (L-1) | see 4.2 | as delegated | delegating nurse | Q4, Q11 | PROPOSED, unresolved |
| C1 | trained other: selection, instruction, supervision recorded | E inside the care plan; K-7 decides whether NAVORA records it as a delegation | grade evidence; for trained other the instruction record | F4 sets the plan | Q2, Q3, Q4, Q9, Q11 | PROPOSED |
| C3, N1 | none | E | membership | each person | – | PROPOSED |

---

## 5. Delegation record (CR-176, refined)

These fields are unchanged from v0.1:
- activity row;
- case;
- member;
- delegating nurse;
- supervising nurse (may be the same);
- instruction date;
- a fixed end date (never open-ended; the maximum is K-4);
- optional conditions;
- append-only, revocable, audited, never set by an AI.

**New in v0.2:**
- **Context and party:** the context code and the party whose matrix version it rests on (§2.2). A delegation in NH-EXT is **invalid** while L-7 is open, in Phase B.
- **Delegator's own state:** the delegator's grade evidence and practice licence must be valid **on every day of use**. If they lapse, every delegation she gave goes to "review needed". Her delegations do **not** silently continue. The case's F4 or F5 reviews them.
- **Activity scope:** a delegation never covers a row that is **–** or **?** for the delegate's grade. The database refuses to record it (CR-176a).

---

## 6. Use in planning (with the PO)

### 6.1 What NAVORA needs per job and per member (proposal to `po`)

**Per job (visit, shift, NH-EXT job):**
- context code; canton;
- commissioning party; executing team;
- **activity list** (matrix rows; a visit without an activity list cannot be assigned in Phase B);
- for each Bst. b row: order present yes/no, and the order's end date (AÜP);
- the case's F4;
- for NH-EXT, the Einsatzvereinbarung (§2.3);
- the time window.

**Per member:**
- grade and its **evidence state** (§6.2);
- practice licence and its expiry, for `nurse_hf_fh`;
- additional competences (experience years for A3/A4; K-3 specialist training);
- delegations held;
- access state; team membership;
- availability and overlapping commitments (existing PLAN3 facts).

**Never** a health datum about the member. Never another team's client details (existing CGR-137 rule).

### 6.2 Evidence states (CR-181)

| State | Meaning | Counts in Phase A | Counts in Phase B |
|---|---|---|---|
| `nachgewiesen` | checked by an authorised checker (who: D-29, L-9) against the document; date and checker recorded | yes (synthetic, labelled) | yes, until expiry |
| `selbst bestätigt` | the member says so; nothing checked | no | no |
| `fehlt` | nothing recorded | no | no |
| `abgelaufen` | was `nachgewiesen`, expiry passed | no | no |
| `widersprüchlich` | two records disagree (for example grade versus diploma, or two teams with different grades) | no | no |

### 6.3 One check, every path (CR-177, widened)

The same database function decides on every path:
- PLAN3 proposal; PLAN2 series;
- hand assignment;
- self-take;
- swap (both sides);
- short-notice cover (COVER1);
- NH-EXT offer and acceptance;
- start of a visit (re-check at start: the evidence may have lapsed since planning).

For each member and each activity of the job, it returns one of four results:
- `geeignet`: E, with grade evidence `nachgewiesen`.
- `geeignet mit Delegation`: D, with a valid delegation and the delegator's state valid.
- `nicht geeignet`: **–**.
- `ungeklärt`: **?**, evidence not `nachgewiesen`, a delegation missing or expired, or the context modifier applies.

**Only the first two allow the member to be responsible for the job.** The other two are a **refusal** naming the activity and the reason (not the client's data to anyone outside the case). The UI and the AI must never show `ungeklärt` as suitable, as "probably suitable" or with a score.

### 6.4 Safe flows

| Situation | What NAVORA does | What it never does |
|---|---|---|
| Evidence `fehlt` or `selbst bestätigt` | refuses; tells the member which evidence to provide, and the checker who may verify it | treat a self-confirmation as evidence (FE-039) |
| Evidence `abgelaufen` (planned visit in the future) | marks every affected future visit "Eignung ungeklärt", releases them to the team as open (CR-051 pattern), raises a coverage fact; **at start time** refuses the start | let a visit start on lapsed evidence |
| Evidence `widersprüchlich` | as `fehlt`, plus a review task to F5 (or, without F5, to the F4 nurses of affected cases) | pick the higher grade |
| Delegation missing for a D row | refuses; offers the case's F4 nurse a **request** "Delegation prüfen" (a human decides) | create, suggest-and-auto-accept or extend a delegation; an AI never grants one |
| Delegation expires before the visit | as `abgelaufen`; the "expires in ≤ n days" fact goes to the delegating nurse and the team (n is K-4) | silently extend it |
| **?** cell | refuses as `ungeklärt`, naming the open question (K or L number) | fall back to a looser value |
| HOSP-IN job | no proposal, no suitability; states "Spitaleinsatz: Tätigkeitsregeln des Spitals nicht hinterlegt" | apply the home-care matrix |
| NH-EXT without a complete Einsatzvereinbarung | job not offerable; lists the missing fields | show members as suitable |

### 6.5 What the AI may do

**May:**
- propose only members whose check returns `geeignet` or `geeignet mit Delegation`;
- give its reason per activity (grade E, or delegation by whom, until when);
- show a gap when nobody passes;
- show delegations that are expiring.

**May not:**
- create, extend or infer a delegation;
- rank `ungeklärt` members;
- propose a member with an overlapping commitment (PLAN3-14 refuses on overlap at confirm; the hand paths show the fact, CGR-137, founder decision).

The **team** confirms or changes the proposal through F1. A change runs the same check.

---

## 7. Cover simulation: acceptance criteria (for the PO's simulation; Phase A, synthetic)

**Scenario:** a nursing home (NH-OWN, and separately NH-EXT) reports at short notice that a care worker is absent for a named shift. The shift has a named activity list. NAVORA searches for a replacement, checks qualification, evidence and delegation, proposes, and the team accepts or changes it. If nobody is suitable, NAVORA shows the coverage gap and escalates.

**Synthetic fixture (new, created for this test, D-1):** one home; one ward; one absent member; one shift with activity list `{C1, B3, B7}`, with an order present for B3 and B7.

| Candidate | Grade, evidence | Delegation | Busy at the shift time |
|---|---|---|---|
| M1 | `nurse_hf_fh`, `nachgewiesen` | – | no |
| M2 | `fage_efz`, `nachgewiesen` | valid for B3, B7 for the resident | no |
| M3 | `fage_efz`, `nachgewiesen` | B7 expired yesterday | no |
| M4 | `fage_efz`, `selbst bestätigt` | – | no |
| M5 | `ags_eba`, `nachgewiesen` | – | no |
| M6 | `nurse_hf_fh`, `nachgewiesen` | – | **yes**, overlapping visit |

### 7.1 Acceptance criteria

| ID | Criterion (testable) |
|---|---|
| AK-1 | The absence report creates a **coverage need** with the shift's activity list. Nothing is reassigned automatically |
| AK-2 | The proposal lists only M1 and M2. For M2 the reason names B3 and B7 "Delegation von <nurse label>, gültig bis <date>" and C1 "eigener Kompetenzbereich". For M1 every row reads "eigener Kompetenzbereich" |
| AK-3 | M3, M4, M5 and M6 are **not** proposed. The reason for each is available to the team without another team's client data: M3 "Delegation B7 abgelaufen", M4 "Nachweis nicht geprüft", M5 "B3, B7 nicht im Kompetenzbereich", M6 "zu dieser Zeit schon eingeplant" |
| AK-4 | The proposal is a proposal: nothing is assigned until a team member confirms (F1). The confirming member, the time and the version of the matrix and rules used are recorded |
| AK-5 | The team changes the proposal to M3 by hand: refused (`ungeklärt`, delegation expired); to M5: refused (`nicht geeignet`); to M6: allowed, with the overlap **fact** shown (founder decision, CGR-137), and the check of the activities still runs |
| AK-6 | Re-check at confirm: if M2's delegation is revoked between proposal and confirm, the confirm is refused with the reason |
| AK-7 | Re-check at start: if M2's evidence lapses after confirm, the start is refused and the gap is raised (AK-9) |
| AK-8 | Every screen and the AI text label the rules as **provisional (synthetic test, not released)** (PLAN3-18) |
| AK-9 | **No suitable replacement** (fixture without M1 and M2): NAVORA shows "Versorgungslücke: <shift>, <activities without suitable cover>". It notifies the escalation chain (7.3) and assigns nobody. The gap stays visible until covered or closed by a named person, with a reason (closing is not "acknowledging") |
| AK-10 | Audit: for every proposal, refusal, confirm and escalation, an append-only record with the rule version and the matrix version (CR-179), with no health data of members |

### 7.2 Negative tests (each a pgTAP plus one e2e)

| ID | Setup | Expected |
|---|---|---|
| NT-1 missing evidence | only candidate M4 | not proposed; hand assignment refused "Nachweis nicht geprüft"; gap raised |
| NT-2 expired delegation | only candidate M3 | not proposed; hand assignment refused; the fact goes to the delegating nurse |
| NT-3 unresolved cell | shift activity B8 (FaGe **?**); only FaGe candidates | none proposed; reason names K-3; gap raised; no fallback to a looser value |
| NT-4 overlap | only candidate M6 | not proposed by the AI; hand assignment allowed with the overlap fact (activities pass) |
| NT-5 nobody suitable | only M5 for `{C1, B3}` | AK-9 path; M5 not offered even for "C1 only" unless the team **splits** the shift into separate jobs by hand (each job checked on its own) |
| NT-6 contradictory evidence | M2 has a second record `ags_eba` | `ungeklärt`; review task to F5 |
| NT-7 delegation for another resident | M2's delegation names another case | not valid for this shift |
| NT-8 delegator lapsed | the delegating nurse's practice licence expired | M2's delegation is "review needed", not valid |
| NT-9 NH-EXT incomplete | NH-EXT job without a delegation source | not offerable; missing field named |
| NT-10 AI cannot grant | the agent role calls the delegation command | refused (permission), recorded |

### 7.3 Who is informed when a gap stays unresolved (proposal; the time steps are K-8)

| Context | Order of addressees |
|---|---|
| NH-OWN | (1) the team; (2) the home's F5 (Pflegedienstleitung or pflegefachverantwortliche Person, and the deputy). The home's staffing duty is the licence holder's [Q6, Q7] |
| NH-EXT | (1) the executing team; (2) the **home's** F5, named in the Einsatzvereinbarung, because the residents' care stays the home's responsibility; (3) the team's own F5, where the team is a licensed organisation |
| HOSP-POST, PRIV | (1) the team; (2) the case's F4 nurse; (3) the team's F5; (4) where a Bst. b activity would be missed, the **ordering physician**, by the F4 nurse (NAVORA prompts, a human calls); (5) the client or her representative |

The AI log is never the only addressee. Reuse SIG1 and SIG2 (escalation, outside delivery), but with **coverage-gap** reasons. The SIG1 thresholds stay PROVISIONAL (D-28).

---

## 8. Must be confirmed before a real pilot (list for the PO; Phase B gate)

| # | Item | Confirmed by |
|---|---|---|
| P-1 | Every cell used in the pilot context and canton: from `PROPOSED` to `freigegeben` | D-43 function (fachlich), `lca` (rechtlich), the partner's F5 (adoption) |
| P-2 | Every **?** used by the pilot's activity lists resolved, or the activity excluded from the pilot | D-43 function |
| P-3 | Delegation rule: who may delegate, maximum validity, reminder period, conditions (K-4); the delegation conditions in BS/BL (L-3) | D-43 function; `lca` |
| P-4 | F3, F4 and F5 as defined in §3, including the limit in §3.3 and the written delegation of F1 to the team where required (L-2) | `lca`; the partner's F5; owner (FD-Q2) |
| P-5 | The legal form of NH-EXT and who delegates there (L-7) | `lca`, legal adviser where needed; owner (FD-Q1) |
| P-6 | Escalation chain and time steps per context (§7.3, K-8) | D-43 function; the partner's F5 |
| P-7 | Evidence checking: who may check, and against what (D-29, L-9) | owner; `lca` |
| P-8 | Shift minimums for the nursing home (K-5; ZH-style ratios are not BS/BL rules) | `lca` (BS/BL instrument); D-43 function |
| P-9 | Billing dependence on the performer's grade (L-5) | `lca` |

---

## 9. Questions, prepared as options with consequences

The point is that the founder decides concrete options, not "who is the Clinical Owner". The **approval function** itself is D-43 (options A to D there). The questions below are what that function, `lca` or the founder must answer. Each one names who answers.

### 9.1 Clinical questions (for the D-43 approval function once named; Phase A runs the strict default)

| ID | Question | Options | Consequence | Strict default until answered |
|---|---|---|---|---|
| K-1 | Release the cells of §4.2 per context and canton | (a) row by row, the seed rows first (A1, B3, B7, C1); (b) all at once | (a) the pilot can start with a narrow activity set; (b) later start, fewer re-releases | as v0.1: Bst. b only by `nurse_hf_fh` (CR-007) |
| K-2 | FaGe and high-risk drugs (B3), insulin (B4) | (a) **D** with a named list and extra instruction; (b) **–** for the list; (c) **D** without a list | (a) needs a versioned drug-class list (NAVORA invents none); (b) more HF/FH visits; (c) not recommended: no control of the highest-risk drugs | **?**, which counts as – |
| K-3 | Complex wound care (B8): what counts, and is specialist training required? | (a) definition plus specialist certificate for B8; (b) definition, HF/FH only; (c) no split (B7 = B8) | (a) a new evidence type; (b) simple; (c) loses the control | ? |
| K-4 | Maximum validity of a delegation; reminder period; review on reassessment | (a) tied to the reassessment interval of the case; (b) a fixed maximum; (c) per activity | (a) one rule, follows the client; (b) simplest; (c) most precise, most data | none valid beyond the next reassessment (proposal; not a rule) |
| K-5 | Nursing home: minimum grade and presence per shift, incl. nights | (a) from the canton's instrument (L-2, P-8); (b) the home's own staffing plan as L4 | (a) a versioned rule row per canton; (b) per home | the shift is not "covered" without one `nurse_hf_fh` reachable (proposal) |
| K-6 | AGS vital signs (B1): D or E with reporting | (a) D; (b) E with immediate reporting | (a) more delegation records; (b) depends on the care-plan thresholds being set by F4 | D |
| K-7 (new) | Grundpflege by FaGe, AGS, PH (C1): record as a delegation or as E inside the care plan? (BAG calls it "delegiert" [Q11]) | (a) E inside the F4 care plan; (b) a delegation record for C1 too | (a) less paperwork, the care plan is the instruction; (b) uniform, more records | (a), with the care plan required |
| K-8 (new) | Time steps of the coverage-gap escalation per context | (a) reuse the SIG1 steps; (b) separate steps per context | (a) one mechanism; (b) fits shift work | (a), PROVISIONAL (D-28) |

### 9.2 Legal questions for `lca` (issue #924; with `legal` where `lca` says so)

| ID | Question | Why it matters | Possible answers and their consequence |
|---|---|---|---|
| L-1 | The consolidated KLV Art. 7, 7a, 8, 8a in force; which Bst. a and c services may be provided without an order **and by whom** (only the Art. 49 KVV nurse, or staff of an organisation under her assessment); whether B11 and B12 are Bst. b or c | A1, A2, C1, B11, B12 cells; billing | reserved to HF/FH → as proposed; open to others → cells change, K-1 again |
| L-2 | BS and BL: the duties of the Spitex and nursing-home F5 (BS § 22 Bewilligungsverordnung; BL licence); does the licence require directive authority, an organisation chart and written delegation (as in ZH)? | §3.3 limit | not required → §3.2 holds as is; required → the §3.3 alternative; rejected → conventional lead (FD-Q2) |
| L-3 | Delegation conditions (selection, instruction, supervision) in BS and BL; is delegation by a team nurse without a line manager enough for the organisation's duty under Art. 51 KVV? | F3, CR-176 | yes → as proposed; only via F5 rules → F5 adopts delegation rules first (already proposed) |
| L-4 | Current AGS Bildungsplan and SRK rules; PH SRK recognition in BS and BL | B1, B11, C1 cells | narrower → cells to –; wider → K-1 |
| L-5 | Does KVG payment of a Bst. b activity depend on the performer's grade? | billing gate (CR-028) | yes → a billing gate on the check result; no → only clinical |
| L-6 | Apprentices (FaGe in training): B activities under supervision? | new grade value | yes → a sixth value with supervision; no → excluded |
| L-7 (new) | **NH-EXT legal form:** when an external team works in a home, is this staff hiring (AVG, licence, the home's directive authority [Q15]) or a contracted service with the team's own professional responsibility? Must the team be a licensed Spitex organisation? Who may delegate to a team member for a resident? Does the home's staffing duty allow counting the team? | the founder's main use case; §2.3 | staff hiring → the home's F5 directs, the home's nurses delegate, a licensed hirer is needed (NAVORA does not employ, D-12); service contract → the team delegates, but the home's licence may still require its F5 to approve; unresolved → NH-EXT not in Phase B |
| L-8 (new) | HOSP-IN: is a team working inside a hospital always staff hiring? | HOSP-IN scope | yes → out of the planning matrix, only time and evidence |
| L-9 (new) | **Who may check evidence:** may a team member check another's diploma or licence (D-29)? Is the NAREG or cantonal register look-up the evidence? | evidence state `nachgewiesen` | register look-up by F5 → simple; any member → needs a rule against self-checking |
| L-10 (new) | PRIV self-pay: does practice-licence and liability law apply in full without KVG? | PRIV cells | yes → identical to KVG cells (proposed) |

### 9.3 Founder decisions this prepares (only if `lca` confirms they are needed)

- **FD-Q1, form of the external team for NH-EXT.**
  - **Options:** (a) the team is, or belongs to, a licensed Spitex organisation that contracts a service with the home; (b) the team's members are hired through a licensed staff-hiring company, and the home directs; (c) the home employs a pool, and NAVORA is its software; (d) do not offer NH-EXT in Phase B.
  - **Consequences:** (a) needs an F5 in the team's organisation, an OKP admission is not needed for this, and the team delegates (if L-7 allows); (b) the home's nurses delegate, the team's autonomy is limited to coordination, and NAVORA must not become the employer (D-12); (c) simplest legally, but it is NH-OWN, not a team marketplace; (d) no risk, no product test.
  - **My clinical preference** (advisory): (a) or (c). Both keep one delegation source per resident.
- **FD-Q2, if a licence requires directive authority** (L-2): (a) the §3.3 alternative (F5 holds it formally and delegates F1 to the team in writing); (b) a conventional nursing lead for that organisation; (c) do not partner with that organisation type.

---

## 10. Phase A and Phase B

- **Phase A (now, synthetic):** the matrix, the check, the delegation record, the evidence states and the cover simulation may be **built and tested** on newly created synthetic data, labelled provisional (FE-021, D-1, D-28).
  - **?** counts as –.
  - Evidence `nachgewiesen` exists only as a labelled synthetic state.
  - NH-EXT is simulated in both delegation variants (L-7).
- **Not a release.** The founder's request to model and test these rules does not lift D-27 and is not a release for real care. CR-174 to CR-184 and every cell stay `PROPOSED` until the §1.3 steps are recorded.
- **Until built:** the code keeps the stricter rule: Bst. b and the needs assessment by `registered_nurse` only (CR-007, CR-164).

---

## 11. Sources

v0.1 sources Q1 to Q9 are unchanged (read 2026-11-06):
- [Q1] KLV extract, 1 January 2022;
- [Q2] Gutachten Kellerhals Carrard 2025;
- [Q3] Bildungsplan FaGe;
- [Q4] Bildungsplan AGS 2010;
- [Q5] CURAVIVA/INSOS 2024;
- [Q6] BS Pflegeheimbewilligung;
- [Q7] BL Pflegeheime;
- [Q8] BS Spitex Merkblatt March 2025;
- [Q9] BFH PH SRK.

Links are in git history (v0.1, PR #923).

**New, read 2026-11-06 22:00-22:30 CET (a web tool returned summaries; quoted phrases are as the tool reported them, to be checked by `lca` in the original):**
- **[Q10]** ARTISET, "Umsetzung der ersten Etappe der Pflegeinitiative", Merkblatt 2024: [artiset.ch](https://artiset.ch/files/EA0ISQ9/umsetzung_der_ersten_etappe_der_pflegeinitiative__merkblatt__artiset__2024.pdf).
  - KLV Art. 7 Abs. 2 Bst. a and c without a medical order from 2024-07-01;
  - Art. 7 Abs. 4 (services determined through the needs assessment);
  - Art. 8a Abs. 1bis (inform the family doctor);
  - nursing homes unchanged (care level, doctor confirms a new level, review at least every 9 months).
- **[Q11]** BAG, "Direkte Abrechnung der Pflegeleistungen – Fallbeispiele", Q&A, 8 May 2024: [bag.admin.ch](https://www.bag.admin.ch/dam/bag/de/dokumente/berufe-gesundheitswesen/teritaerstufe/pflegeinitiative/faq-direkte-abrechnung-pflegeleistungen.pdf.download.pdf/20240508_Q&A_Direkte%20Abrechnung%20Pflegeleis-tungen_Fallbeispiele_DE.pdf).
  - The "diplomierte Pflegefachperson" carries out the standardised needs assessment and informs the family doctor.
  - Behandlungspflege "muss in jedem Fall vom Hausarzt verordnet werden".
  - Examples: FaGe showering "delegiert"; a staff member with a Pflegehilfe course putting on stockings.
- **[Q12]** Kanton Basel-Stadt, Spitexbewilligung: [bs.ch](https://www.bs.ch/themen/arbeit-und-steuern/arbeitsbewilligungen/medizinische-berufe/spitex-pflegeheime-und-weitere/spitexbewilligung).
  - At least one "pflegeverantwortliche Fachperson";
  - Pflegedienstleitung with practice licence and a "stellvertretende Pflegedienstleitung" (§ 22 Bewilligungsverordnung);
  - "das erforderliche Fachpersonal ist verfügbar";
  - practice licence for anyone working "fachlich eigenverantwortlich" (HF/FH);
  - OKP admission for self-employed nurses with two years' practice.
- **[Q13]** Kanton Basel-Landschaft, Gesuchsformular Spitex 2026: [baselland.ch](https://bl-api.webcloud7.ch/politik-und-behorden/direktionen/volkswirtschafts-und-gesundheitsdirektion/amt-fur-gesundheit/bewilligungen/dokumente-bewilligungen/2026_gesuchsformular_spitex.pdf).
  - Pflegefachverantwortliche Person and deputy: HF/FH, "mindestens zweijährige praktische Tätigkeit (Vollzeit)", B2 German, criminal record extract;
  - Stellenplan with qualifications;
  - Betreuungs- und Pflegekonzept;
  - qualivista ambulant self-assessment.
- **[Q14]** H+, Positionspapier Akut- und Übergangspflege, 3 December 2018: [hplus.ch](https://cug.hplus.ch/fileadmin/hplus.ch/public/Politik/UEbergangspflege/20181203_AUeP_Positionspapier_dt.pdf). Quotes Art. 25a Abs. 2 KVG: services "im Spital ärztlich angeordnet", "während längstens zwei Wochen", financed under hospital financing rules. A position paper, not the law; `lca` to check the current text.
- **[Q15]** WEKA, "Personalverleih: Vorsicht beim Outsourcing von Personal": [weka.ch](https://www.weka.ch/themen/recht/arbeitsrecht/schweizer-arbeitsrecht/article/personalverleih-vorsicht-beim-outsourcing-von-personal/). Quotes BGer 2C_470/2020: the "Abtreten wesentlicher Weisungsbefugnisse an den Einsatzbetrieb" is the key feature of staff hiring; further indicators are integration into the host's organisation, its tools, and pay by the hour. A commentary, not the AVG; `lca` (L-7).
- **[lca L9]** as read by `lca` in D-25 (ZH Merkblatt Pflegeinstitution December 2024 / September 2025): organisation chart with directive and supervisory authority; written delegation outside the management. ZH, used only as an example of the §3.3 limit.

**Still not read:**
- the consolidated KLV and KVV, KVG Art. 25a, the AVG and AVV;
- the BS Bewilligungsverordnung (§ 22) itself, and the BL Spitex and nursing-home ordinances;
- BS and BL nursing-home staffing instruments;
- the current AGS plan and SRK rules;
- the Rahmenlehrplan Pflege HF;
- hospital competence rules.
