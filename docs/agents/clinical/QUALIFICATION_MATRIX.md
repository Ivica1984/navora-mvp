# Qualification and activity matrix (skill and grade mix): home care and nursing homes

**Maintained by:** Clinical & Regulatory Architect (`cra`; review role, an AI agent, not a licensed clinician) · **Requested by:** the founder, 2026-11-06 (attended session; the PO records the decision in `FOUNDER_DECISIONS.md`) · **Version:** 0.1, 2026-11-06 21:50 CET · **Status of every cell: PROPOSED.** Nothing here is `APPROVED`. Only the named Clinical Owner can approve a cell, and only after G-1 (D-27). Each approval is recorded in `approvals/CR-nnn.md`. The legal reading is advisory; `lca` checks it (questions L-1 to L-6 below).

**Register rows:** CR-174 to CR-178 in [`CLINICAL_RULE_REGISTER.md`](CLINICAL_RULE_REGISTER.md), section *Proposed rules (not in code)*.

No personal or health data in this file.

---

## 1. What the founder asked for and what the sources say

The founder set two principles (2026-11-06, binding as a founder decision once the PO records it):
1. **Self-organisation, not a hierarchical Pflegeleitung.**
2. **Competence limits still apply.** Every member's verified qualification profile is stored. The planning engine (PLAN3) proposes a visit only to members whose qualification allows every activity in it.

He also proposed three grades:
- **HF/FH:** needs assessment, complex Behandlungspflege, care planning.
- **FaGe EFZ:** Grundpflege and delegated Behandlungspflege.
- **AGS EBA / Pflegehelfer SRK:** Grundpflege and daily-life support only, no delegated medical treatment.

What the sources read on 2026-11-06 add (details in §5):

| # | Statement in the request | What the sources say | Consequence for NAVORA |
|---|---|---|---|
| 1 | "KLV Art. 7 sets clear competence limits" | **Only partly.** KLV and KVV assign only a few activities to a person: the needs assessment (*Bedarfsermittlung*) to a Pflegefachperson under Art. 49 KVV [Q1 Art. 8a Abs. 1]; coordination in complex situations (Art. 7 Abs. 2 Bst. a Ziff. 3) and certain psychiatric assessments to a Pflegefachperson with two years' experience [Q1 Art. 7 Abs. 2bis]. Otherwise "weder KVG noch KVV oder KLV konkretisieren das Zulassungskriterium des erforderlichen Fachpersonals" [Q2]. The grade limits come from the **training ordinances and plans** [Q3, Q4], from the **organisation's competence and delegation rules** [Q4 "Kompetenzenordnung und Delegationsregeln"; Q5] and from **cantonal licensing** [Q6, Q7] | The matrix cannot be derived from KLV Art. 7 alone. It has three layers: KLV (who may assess and coordinate), training scope (what a grade may do at all), and delegation (what this person may do for this client) |
| 2 | FaGe: Grundpflege plus delegated Behandlungspflege | **Consistent with the FaGe training plan.** Its activities in this area are "übertragene" (assigned) medizinaltechnische Verrichtungen "gemäss den betrieblichen Standards" [Q3 Bereich D] | FaGe may do Bst. b activities only when they are assigned (delegated) and inside the training scope (§3) |
| 3 | AGS / Pflegehelfer: "no delegated medical treatment" | **Too coarse in one place.** The AGS training plan includes "Kontrolle von Vitalzeichen" and weight [Q4 1.6]. KLV counts the measurement of vital signs as *Untersuchung und Behandlung*, Bst. b [Q1 Art. 7 Abs. 2 Bst. b Ziff. 1]. Medication administration, wound dressings and compression bandages are **not** in the AGS plan read [Q4: "Bindet Beine ein (keine Kompressionsverbände)"] | A rule at the level of the KLV category ("AGS: no B") would either forbid what AGS are trained for, or, if relaxed, let B in wholesale. The rule must work per **activity** (Verrichtung), not per KLV category |
| 4 | No hierarchical Pflegeleitung | **Compatible, with one condition.** Basel-Stadt requires every nursing home to have a **Pflegedienstleitung and a deputy** with a tertiary nursing degree (HF/FH) and a professional practice licence [Q6]. Basel-Landschaft requires a **pflegefachverantwortliche Person and a deputy**, licensed through the home's operating licence [Q7]. For Spitex in Basel-Stadt, the cantonal leaflet covers both the operating licence and the practice licence of a Pflegefachperson [Q8]; whether a named nursing-responsible person is required, and with which duties, is in the Bewilligungsverordnung, which was not read (L-2) | Self-organisation stays: no one dictates rosters. **But each licensed organisation needs one named, licensed person with professional responsibility for nursing**: a role with defined duties, not a line manager. NAVORA can carry it as a **role with an audit trail**: approves the competence and delegation rules, sees the delegation record, is reachable for escalation. See §4 |
| 5 | "The AI secures treatment quality in the background" | **Partly.** A qualification filter is a necessary control, but not a sufficient one. Delegation is lawful when the person is "sorgfältig ausgewählt, instruiert und überwacht" [Q5]; a training certificate covers selection and instruction, "nicht aber die Überwachung" [Q5]. D-40 / AIR1 forbid "AI replacing an accountable human decision" | The **rule lives in the database**, not in the AI: the same check refuses a hand assignment and filters a PLAN3 proposal (it extends today's `may_perform_visit`, CR-164). The AI only proposes within it. The accountable act (the delegation) stays with a named Pflegefachperson in the team, recorded as structured data |

---

## 2. Grades (proposed qualification values)

Today NAVORA knows two values: `registered_nurse` and `care_assistant` (CR-009). `care_assistant` lumps FaGe, AGS, Pflegehelfer and untrained staff together (H-04, D-29 context). Proposed values, each needing verified evidence before it counts (D-29, CGR-16):

| Value (proposed) | Grade | Evidence to record (D-29, `lca`/owner) | Source of scope |
|---|---|---|---|
| `nurse_hf_fh` | Dipl. Pflegefachperson HF or FH (Art. 49 KVV) | diploma; GesBG register entry (NAREG); cantonal practice licence where required | KLV [Q1]; GesBG (not read: L-1) |
| `fage_efz` | Fachfrau/Fachmann Gesundheit EFZ | EFZ certificate | Bildungsplan FaGe [Q3] |
| `ags_eba` | Assistent/in Gesundheit und Soziales EBA | EBA certificate | Bildungsplan AGS [Q4] (version read: 20 Dec 2010; the current version is UNKNOWN, L-4) |
| `pflegehelfer_srk` | Pflegehelfer/in SRK | SRK course certificate | BFH summary [Q9]: Grundpflege "entsprechend ihren Kompetenzen selbständig"; course length and recognition status UNKNOWN (L-4) |
| `trained_other` | Other staff, trained on the job | internal instruction record | Gutachten Kellerhals Carrard 2025 [Q2] (Bern, commissioned by the canton; applicability in BS/BL is UNKNOWN, L-3) |

Not in scope of this version: FaBe, MPA, Sozialpädagogik, students and apprentices (their status during training is UNKNOWN: Clinical Owner and `lca`).

---

## 3. The matrix (PROPOSED)

**Legend:**
- **E**: within the grade's own scope; may be planned without a delegation.
- **D**: only on a **valid delegation** by a `nurse_hf_fh` of the team for this client and this activity (§4), inside the grade's training scope.
- **–**: not to be planned for this grade.
- **?**: UNKNOWN; the Clinical Owner decides. Until then the strict reading applies, which is "–".

The source tag follows the cell.

| # | Activity (Verrichtung) | KLV | HF/FH | FaGe EFZ | AGS EBA | PH SRK | trained other |
|---|---|---|---|---|---|---|---|
| A1 | Needs assessment (*Bedarfsermittlung*) and planning of measures, incl. reassessment | Art. 7 Abs. 2 Bst. a Ziff. 1; Art. 8a | **E** [Q1 Art. 8a Abs. 1] | – [Q1] | – [Q1] | – [Q1] | – [Q1] |
| A2 | Advice to the client and relatives (*Beratung*) | Bst. a Ziff. 2 | **E** [Q1] | ? | – | – | – |
| A3 | Coordination in complex and unstable situations | Bst. a Ziff. 3 | **E only with ≥ 2 years' experience** in networking or case management [Q1 Abs. 2bis] | – [Q1] | – [Q1] | – [Q1] | – [Q1] |
| A4 | Psychiatric needs assessment (cases named in Abs. 2bis) | Abs. 2bis | **E only with ≥ 2 years' psychiatric experience** [Q1 Abs. 2bis] | – [Q1] | – [Q1] | – [Q1] | – [Q1] |
| B1 | Vital signs (pulse, blood pressure, temperature, respiration, weight) | Bst. b Ziff. 1 | **E** | **D** [Q3 D.1] | **D** [Q4 1.6; reports values "unmittelbar der zuständigen Fachperson"] | ? [Q9: not named] | – |
| B2 | Venous and capillary blood sampling | Bst. b (lab sampling) | **E** | **D** [Q3 D.2] | – [Q4: not in plan] | – | – |
| B3 | Preparing and administering medication (oral and others as in the plan) | Bst. b | **E** | **D** [Q3 D.3] | – [Q4 2.4: only "hält sich an die Anordnung der Medikamentenabgabe"] | – | – |
| B4 | Subcutaneous and intramuscular injections | Bst. b | **E** | **D** [Q3 D.6]; **insulin: ?**, as a source calls it core nursing (Kernbereich), not delegable [Q5, citing German case law] | – | – | – |
| B5 | Infusions without drug additives on an existing peripheral venous line | Bst. b | **E** | **D** [Q3 D.4] | – | – | – |
| B6 | Tube feeding on an existing access | Bst. b | **E** | **D** [Q3 D.5] | – | – | – |
| B7 | Dressing change on primary- and secondary-healing wounds | Bst. b | **E** | **D** [Q3 qualification profile] | – [Q4: not in plan] | – | – |
| B8 | Complex wound care (e.g. negative-pressure therapy, assessment of the wound course) | Bst. b | **E** | ? (not named in [Q3]) | – | – | – |
| B9 | Transurethral bladder catheter: insert and remove | Bst. b | **E** | **D** [Q3 B.3] | – | – | – |
| B10 | Delegated breathing support, oxygen and inhalation on medical order | Bst. b | **E** | **D** [Q3 B.4] | – | – | – |
| B11 | Compression: putting on medical anti-thrombosis or compression stockings | Bst. b or c: ? | **E** | **E** or **D**: ? | **D** [Q4 1.4 "unterstützt beim Anziehen"] | ? | ? |
| B12 | Compression bandages | Bst. b | **E** | ? | – [Q4 "keine Kompressionsverbände"] | – | – |
| B13 | Any Bst. b activity not listed above | Bst. b | **E** | ? | – | – | – |
| C1 | Grundpflege: dressing, hygiene, excretion, mobility, transfers, eating and drinking, prophylaxis | Bst. c Ziff. 1 | **E** | **E** [Q3] | **E** [Q4 1.1-1.5, 2.4] | **E** [Q9] | **E with selection, instruction and supervision** [Q2] |
| C2 | Supervision and support of persons with psychiatric illness in daily life | Bst. c Ziff. 2 | **E** | ? | ? | ? | – |
| C3 | Recognising an extraordinary situation and getting help | – (duty of all) | **E** | **E** [Q3 A.1] | **E** [Q4 1.7] | **E** | **E** |
| N1 | Non-KLV support (daily structure, household, accompanying) | not KLV | **E** | **E** | **E** [Q4 2, 3] | **E** | **E** |

**Nursing home (FE-031, simulated ward in Phase A):** the same activity rows apply. KLV Art. 7 Abs. 2ter says the services can be provided "ambulant oder in einem Pflegeheim" [Q1]. Ward-specific questions are UNKNOWN and belong to the NH-A briefs (CGR-142): minimum grade per shift (in particular nights), who must be reachable, and the per-canton instrument for care levels (BS: RAI levels, BL: UNKNOWN; `lca` D-22).

---

## 4. Delegation without a hierarchy (proposed control)

**Why the control exists:** a person must not perform an activity for which nobody checked she is competent with this client. In a hierarchy this is checked by the Pflegeleitung through job descriptions, rosters and supervision.

**Replacement (structured data, workflow, audit trail):**
1. **Delegation record:** any `nurse_hf_fh` of the team records it, normally the case's primary nurse:
   - which activity (matrix row);
   - for which client (case);
   - to which member;
   - instruction given on (date);
   - valid until (a date, never open-ended);
   - optional conditions (for example "only on a stable wound").

   It is revocable at any time, append-only and audited, and it is never set by an AI (D-40).
2. **Hard rule in the database** (extends `may_perform_visit`, CR-164; applies to every path: PLAN3 proposal, PLAN2 series, hand assignment, take, cover):
   - A visit may have a member as responsible only if, for **every** activity of the visit, the matrix gives her grade **E**, or gives **D** and she holds a valid delegation.
   - Otherwise the visit is refused, with the reason named.
   - This is a refusal, unlike the overlap fact (CGR-137): an overlap may be intended, an activity beyond competence may not.
3. **Supervision:** each delegation names its supervising `nurse_hf_fh`. The fact "delegation expires in ≤ 14 days" is shown to the team (the period is a placeholder; the Clinical Owner sets it). Expiry, a downgrade or the end of access ends the delegation automatically, which releases her affected visits (CR-051 pattern).
4. **The licensed role (§1 row 4):** the organisation's *pflegefachverantwortliche Person*:
   - approves the organisation's matrix version;
   - can read every delegation record and revoke one;
   - is the escalation fallback for qualification questions.

   She is not a dispatcher and plans nobody.
5. **What the AI does:** it proposes only members who already pass rule 2, shows the delegations that a plan relies on, and shows delegations that will expire. It never creates, extends or infers a delegation.

This keeps team autonomy (the team delegates within itself), removes the office hierarchy, and is more auditable than a paper job description: every activity on every visit can be traced to a grade or a named delegation.

---

## 5. Sources (read 2026-11-06, text extraction)

- **[Q1]** KLV (SR 832.112.31), extract "Stand am 1. Januar 2022", Spitex Verband Kanton Zürich: [auszug_klv](https://www.spitexzh.ch/files/EW29T1D/auszug_klv_1120222.pdf). Art. 7 Abs. 1, 2 (a, b Ziff. 1, c), 2bis, 2ter; Art. 8; Art. 8a. **The consolidated text in force today was not readable** (fedlex needs JavaScript). Later changes, in particular the services without a medical order since the KVG revision for the nursing initiative, are to be checked by `lca` (L-1; `lca` has read the BS leaflet 2026 for D-22).
- **[Q2]** Kellerhals Carrard (Jäger, Helmle, Hauck), Rechtsgutachten "Massnahmen der Grundpflege in Spitex-Organisationen nach Art. 51 KVV", for the Amt für Integration und Soziales Kanton Bern, 21 March 2025: [gsi.be.ch](https://www.gsi.be.ch/content/dam/gsi/dokumente-bilder/de/themen/soziales/behinderung/blg/rechtliche-grundlagen/rechtsgutachten%20kc%20grundpflege.pdf). Excerpt; conclusions VII and VIII not in the text read.
- **[Q3]** OdASanté, Bildungsplan Fachfrau/Fachmann Gesundheit EFZ (Ausbildungshandbuch, Register E; version date not in the text read): [FaGe_BiPlan.pdf](https://bbzolten.so.ch/fileadmin/bbz-olten/GSBS/Grundbildung/FaGe/FaGe_BiPlan.pdf). Bereich D (D.1 to D.6), B.3, B.4, A.1, qualification profile.
- **[Q4]** Bildungsplan Assistent/in Gesundheit und Soziales EBA, 20 December 2010: [Bildungsplan_AGS.pdf](https://bbzolten.so.ch/fileadmin/bbz-olten/GSBS/Grundbildung/AGS/AGS_Grundausbildung/Bildungsplan_AGS.pdf). Handlungskompetenzen 1.1 to 6.3. A revised version may be in force (L-4).
- **[Q5]** CURAVIVA / INSOS, "Pflege in Institutionen für Menschen mit Behinderung: wer hat welche Kompetenzen" (2024), citing the Gutachten Landolt of 3 April 2017: [curaviva.ch](https://www.age.curaviva.ch/files/D734JND/pflege_in_institutionen_fuer_menschen_mit_behinderung__wer_hat_welche_kompetenzen__curaviva_insos__2024.pdf). Disability institutions, not home care; used only for the delegation conditions.
- **[Q6]** Kanton Basel-Stadt, Pflegeheimbewilligung: [bs.ch](https://www.bs.ch/themen/arbeit-und-steuern/arbeitsbewilligungen/medizinische-berufe/spitex-pflegeheime-und-weitere/pflegeheimbewilligung). Pflegedienstleitung and deputy: "ein tertiärer Abschluss Pflege auf Niveau FH / HF muss vorliegen"; "das erforderliche Fachpersonal ist verfügbar".
- **[Q7]** Kanton Basel-Landschaft, Amt für Gesundheit, Pflegeheime und Pflegewohnungen: [baselland.ch](https://www.baselland.ch/politik-und-behorden/direktionen/volkswirtschafts-und-gesundheitsdirektion/amt-fur-gesundheit/bewilligungen/betriebsbewilligungen-1/pflegeheime-und-pflegewohnungen). Pflegefachverantwortliche Person and deputy, licensed within the operating-licence procedure. No staffing ratio in the page read.
- **[Q8]** Gesundheitsdepartement Basel-Stadt, SPITEX Merkblatt zum Gesuch um Betriebsbewilligung bzw. Berufsausübungsbewilligung, March 2025: [media.bs.ch](https://media.bs.ch/original_file/7355b605d5d8d8a7fda525dba9cb20fbd46b711f/merkblatt-gesuch-erteilung-bab-und-bb-spitex-2025-03-05.pdf). Legal bases listed; the leadership and staffing rules are in the Bewilligungsverordnung (not read).
- **[Q9]** Berner Fachhochschule, summary of the research report on Pflegehelfende SRK (no date or author in the text read): [bfh.ch](https://www.bfh.ch/dam/jcr:71b12d3f-aa82-45cf-bb64-4336aa445f03/IG_PH_SRK_Zusammenfassung_Forschungsbericht_D.pdf).

**Not read:**
- the consolidated KLV and KVV in force;
- the GesBG and its competence ordinance;
- the BS Bewilligungsverordnung and the BL equivalent;
- BS and BL nursing-home staffing guidelines;
- the SRK course regulations;
- the current AGS Bildungsplan;
- the Rahmenlehrplan Pflege HF;
- Spitex Schweiz or ARTISET delegation guidance;
- the KGL activity list as a grade source. The KGL activity list (2015) was opened; it assigns activities to cost bearers, not to grades.

---

## 6. Questions for `lca` (legal, advisory) and for the Clinical Owner

**For `lca`:**
- **L-1:** The consolidated KLV Art. 7, 7a, 8, 8a in force on 2026-11-06, the services a Pflegefachperson may now provide without a medical order, and whether these are reserved to `nurse_hf_fh` (affects A1 and B rows; CR-004).
- **L-2:** BS and BL Spitex licensing: is a named, licensed Pflegefachperson with professional responsibility required (title, duties, experience), and may she hold that role without line authority? Nursing homes likewise ([Q6], [Q7]).
- **L-3:** Are the delegation conditions (selection, instruction, supervision) [Q2], [Q5] the applicable standard in BS and BL? Does a delegation by a team nurse, without a line manager, meet the organisation's duty under Art. 51 KVV ("erforderliches Fachpersonal")?
- **L-4:** Current versions of the AGS EBA Bildungsplan and the SRK Pflegehelfer regulations, and the recognition status of PH SRK in BS and BL (cantonal staffing counts).
- **L-5:** Billing: does KVG reimbursement of a Bst. b activity depend on the performer's grade, or on the organisation alone? This affects BL-6 ("billing ignores qualification") and CR-028.
- **L-6:** Can apprentices (FaGe in training) perform B activities under supervision in Spitex and nursing homes?

**For the Clinical Owner** (after G-1; every **?** and every **D** cell):
- **K-1:** Approve or change each cell in §3.
- **K-2:** Insulin and other high-risk drugs for FaGe (B4).
- **K-3:** Which wound care counts as complex (B8).
- **K-4:** The maximum validity of a delegation and the reminder period (§4.3).
- **K-5:** The minimum grade and reachability per nursing-home shift (NH-A).
- **K-6:** Whether vital-sign measurement by AGS (B1) needs a delegation, or is within her own scope with reporting.

---

## 7. What stays as it is until approval (safe default)

- The code keeps today's stricter rule:
  - category B and needs-assessment visits are planned, started, resumed and completed by a `registered_nurse` only (CR-007, CR-164);
  - everyone else is `care_assistant`.
- The matrix **loosens** this rule for FaGe (D cells). It may be **built** in Phase A on synthetic data, behind the PROVISIONAL label. It must **not** be active for real clients or residents before the Clinical Owner has approved the cells and D-29 (verified qualification) is decided (S1, CGR-145).
- The overlap rule stays as decided by the founder (2026-11-06): **a fact, never a refusal** (CGR-137, CGR-144). The provisional signal thresholds stay PROVISIONAL for Phase A (D-28).
