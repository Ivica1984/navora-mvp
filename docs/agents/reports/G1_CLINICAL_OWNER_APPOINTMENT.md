# Appointing the Clinical Owner (G-1): requirements and recommendation

**Prepared by:** Product Owner (`po`), 2026-10-27 11:45 CET, on owner instruction 2026-10-27. **Decision owner:** the company owner (who, contract and pay are commercial decisions). **Basis:** D-27 (owner 2026-10-22: a named, qualified human approves clinical rules, care quality rules, LTCF, PAG and MQI interpretations and patient-safety rules; AI guidance is never authoritative). G-1 in [`CARE_OPERATING_MODEL.md`](../../product/CARE_OPERATING_MODEL.md). **Briefing for the person appointed:** [`CLINICAL_OWNER_BRIEFING_PACK.md`](CLINICAL_OWNER_BRIEFING_PACK.md).

Status labels: requirements marked *PO recommendation* are product judgement. Requirements that depend on Swiss or cantonal law are marked **to be confirmed by `lca`** and become final once D-11 (pilot canton) and D-12 (licensed provider) are answered. **No agent can hold this role** (owner 2026-10-27: no Clinical Owner Agent).

## 1 Why it matters now

Ten clinical decisions are prepared and wait only for this person (section 5). 126 rules in the Clinical Rule Register are labelled `PROVISIONAL` or `UNVALIDATED`. The build is not blocked: NAVORA runs on synthetic data under strict defaults. What is blocked is the first real client. Every week without a Clinical Owner is a week the pilot cannot start, however much else is ready.

## 2 Required qualifications

**Must have**
1. **Registered nurse** with a Swiss diploma (HF, or Bachelor of Science in Nursing FH or higher) or a foreign diploma recognised in Switzerland, entered in the national register of health professions. Which register and which practice licence apply to this role: **to be confirmed by `lca`**.
2. **Home-care (Spitex) practice:** at least five years of clinical home-care work, at least two of them in a leadership, quality or clinical-specialist role, for example Pflegedienstleitung, quality manager, or advanced practice nurse (*PO recommendation*). Whether the pilot canton's rules for a home-care organisation's nursing management set a higher bar: **to be confirmed by `lca`** after D-11.
3. **Needs assessment and care planning** under KLV Art. 7 and 8 in daily practice, ideally as a trained interRAI HC assessor. That is the instrument most of the packages refer to, and it lets this person verify the *interRAI reference* sections if the licence allows (D-36).
4. **Quality and safety management:** has run incident reporting (CIRS) or quality-event review, and has set or reviewed clinical escalation rules.
5. **Independence:** the role can refuse a rule even when that delays the pilot. Interests in NAVORA (shares, a sales role, the owner's family) are declared in writing; a conflict does not exclude a person, but it is recorded with the appointment.
6. **German** at professional level (the pilot language; D-11 criteria).

**Should have**
- A master's degree in nursing (MScN) or an advanced practice role.
- Experience with digital care documentation, and basic knowledge of risk management for software. The latter becomes relevant if the owner's D-34 answer makes parts of NAVORA a medical device.
- Familiarity with self-organised teams (the care model, `CARE_OPERATING_MODEL.md`), so that a clinical rule does not quietly rebuild the hierarchy the model removes.
- French or Italian, for later regions.

## 3 Responsibilities

**The Clinical Owner does:**
1. **Decide the clinical decision packages:** approve, approve with changes, or reject each ask, with reasons. The answer is recorded in `OPEN_DECISIONS.md` with name and date.
2. **Approve clinical rules** in the Clinical Rule Register: move a rule from `PROVISIONAL`/`UNVALIDATED` to approved, or name the change. No rule is marked clinically approved without this signature (D-27).
3. **Answer clinical findings:** respond to the Clinical & Regulatory Architect's findings (CGR) of severity S1 and S2 within an agreed time (*PO recommendation*: S1 within two working days, S2 within ten).
4. **Sign the clinical go-live readiness** before the first real client. This covers every clinical decision answered or explicitly accepted as provisional with a stated limit, and the safety risk register reviewed.
5. **Verify interRAI references** where the licence allows (D-36), or name the entitled person who does.
6. **During the pilot:**
   - review serious quality events and the safety-signal statistics (AN2) monthly;
   - recalibrate thresholds on evidence;
   - stop a rule or a feature when it endangers clients.
7. **Name a deputy** for absences, with the same qualifications or the licensed provider's nursing management.

**The Clinical Owner does not:**
- give legal verdicts (legal adviser);
- set prices, contracts or the product order (owner, `po`);
- write code;
- act as the operational on-call nurse. Operational clinical responsibility for clients stays with the licensed provider's nursing management (D-12), which must be able to accept every rule the Clinical Owner approves for its organisation.

## 4 Estimated time commitment (*PO estimate; UNKNOWN until the first sitting*)

| Phase | Work | Estimate |
|---|---|---|
| Onboarding and backlog (first 3 to 4 weeks) | read the briefing pack and the ten packages (about 460 KB, read selectively); three decision sittings of about half a day; the Clinical Rule Register by decision group (126 rules, most answered by the ten decisions); questions to `cra` | **25 to 35 hours** |
| Before the pilot (steady state) | new packages and findings, go-live readiness | **2 to 4 hours a week** |
| First three pilot months | monthly serious-event and signal review, threshold recalibration, S1/S2 findings | **4 to 8 hours a week** |
| After the first three months | monthly review, new features, annual rule review | **about half a day a month** per pilot organisation, plus S1 findings as they arise |

As a role size this is about **0.1 to 0.2 FTE** during the pilot (*PO estimate*).

## 5 Decisions currently blocked by G-1

In decision-index order. Defaults in force and the exact asks are in the [briefing pack](CLINICAL_OWNER_BRIEFING_PACK.md), section 2.

| ID | What waits | What it blocks |
|---|---|---|
| D-28 | Thresholds and responders for overdue or stuck visits; P1 take by a care assistant | CSR1 thresholds leave `PROVISIONAL`; team choice inside a band |
| D-31 | Documentation and follow-up of a broken-off visit | OPS1 `PROVISIONAL` label; the first real client |
| D-3 (b) | Cover-read field list | COVER1 for real clients |
| D-30 | Correction of a report whose author has left | F6 correction path; then the legal adviser |
| D-16 | Quality event taxonomy, severity, hold lift | QG1 relaxation; any typed quality event |
| D-19 | On-site protocol when the client does not open | Option B; CR-014; PS-4 |
| D-17 | Clinical safety-alert categories before the first visit | Clinical half of J1's safety alerts; H-03 |
| D-34 question 7 (clinical half) | Is the intake urgency a clinical judgement, and who may make it | The regulatory adviser's answer to question 7 |
| D-15 | Readiness checklist, care-plan fields, service catalogue and KLV mapping | J1, J3 clinical sign-off; BL-6; C-1; CR-010 |
| D-10 | Countersignature of care-assistant reports | F6 relaxation |
| Register | 126 rules `PROVISIONAL` or `UNVALIDATED` | Any rule marked clinically approved |

## 6 Recommendation (*PO*)

| Route | What it means | For | Against |
|---|---|---|---|
| **A** Nursing management of the licensed partner (D-12 option B) | the partner's Pflegedienstleitung is also NAVORA's Clinical Owner | the person already carries operational clinical responsibility, so rules and practice match | only possible once D-12 names a partner; ties NAVORA's rules to one organisation; less independence |
| **B** Independent registered nurse on a part-time mandate | a qualified home-care nurse leader (section 2) contracted for about 0.1 to 0.2 FTE | can start now; independent of any one provider; decisions are portable to later partners | one more contract; she must agree her rules with each partner's nursing management |
| **C** Employee of NAVORA | a clinical lead on staff | fully available | the largest fixed cost before the pilot; weaker independence |

**Recommended: B now, with A as a co-signature at go-live.** Appoint an independent Clinical Owner on a written part-time mandate now, so the ten decisions move this month. When D-12 names the licensed partner, that partner's nursing management co-signs the approved rule set for its organisation before the first real client.

The mandate should state:
- the scope in section 3;
- the response times;
- access to synthetic data only until go-live;
- professional secrecy and confidentiality;
- professional liability insurance, with the insurance question **to be confirmed by `lca`**;
- that the role is recorded as `clinical` in README *Roles* with name and date.

**Asked of the owner:** "name the Clinical Owner (route B recommended) and a deputy, or tell `po` to prepare a search profile and a mandate draft for route B." Until then, every clinical package stays complete and waiting, and the strict defaults stay in force.
