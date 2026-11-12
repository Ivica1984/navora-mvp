# Automation Review

**Owner:** AI & Automation Architect (`aia`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *Automation review*. **Mandate:** [`ROLE_PROPOSALS_AIA_CSA.md`](ROLE_PROPOSALS_AIA_CSA.md) (approved by the owner 2026-10-27).

**How to read this file:**
- The newest dated section comes first. Never edit an earlier section; correct it in a new one.
- Each finding is a row `AUT-<n>` with:
  - workflow step and role;
  - today's effort and its evidence (events, code, report, source);
  - verdict (eliminate, simplify, automate, AI-support, replace with a different operating model);
  - estimated direct-care time gain, at team level, labelled as an estimate;
  - device level (L, G, H);
  - gate;
  - measure;
  - severity (`high`, `medium`, `low`);
  - issue.

**Success measures (owner 2026-10-27), in this order:**
1. more direct care time;
2. less administrative burden;
3. stronger self-organised teams.

---

**Owner priority (2026-10-27, 13:50):** the largest care-delivery bottlenecks first, each with an estimate of the direct-care time it could return. For every major bottleneck, one verdict:
- **eliminate**;
- **simplify**;
- **automate**;
- **support it through AI**;
- **replace it entirely with a different operating model**.

---

## 2026-11-12 14:25 CET · aia review 49: the PO's three questions to `aia` answered: the departure tap is **already optional** in code (a `planned` card offers «Einsatz starten»; `planned → started` allowed), so the three taps are the BD spec's path, not a product cost (AUT-100, low); AN2 counts a no-show after departure as `started_late` because it classifies the first event, and after the B4 DOOR1 change a direct no-show would fall into `other` (AUT-101, low: classify without `departed`); «Fall eröffnen» by hand, 23 of 75 measured acts, as a rule with the four CGR-193 controls moved to the form and a person only for exceptions (AUT-102, medium); CGR-191 (5), NA-1 to NA-5, BD-7, L-3 row supported; no `high` finding, no issue

**Read:** `recovery/main` at `4891ac3` (since review 48 at `742f694`): journal files 2026-11-12-0824-lca to 2026-11-12-1139-po; brief BD amendments 08:39 to 11:39 (BD-7), J5 08:39, ORD0 08:39 and 09:39; `NEXT_CAPABILITY.md` challenge rows 08:39 (departure tap), 09:39 (B4 «nicht erreicht»), 11:39 (L-3). On their open branches (not merged, read as proposals): PO #1129 (journals 12:39, 13:39, 13:44; challenge row 12:39 «Fall eröffnen»; `FOUNDER_DECISIONS.md` v19 FE-068, FE-069; `docs/product/specs/`), `cra` #1130 (CGR-191 (5), CGR-193), `uxa` #1126 (NA-1 to NA-5, M-1 to M-4, UXR-165 to UXR-168), `lca` #1128, `eng` #1127 (BD-7, test only). **Code read:** `src/features/field/rules.ts` 51-90 (`fieldActions`), `src/app/(protected)/field/visit-lifecycle.tsx` 54-55, migration 0094 101-112 (transition table), 0081 75-110 (`working_day_proposal`), 0058 25-45 and 440-475 (AN2 measure 8), 0089 header (VIS1), 0013 227 and 289 (`convert_partner_request`), `tests/e2e/durchgang-ambulant.spec.ts` 123-140 and 195-214. Open `automation` issues: #912, #940, #1030 (unchanged).

**Measured versus estimated:** act counts are the measured BD tables of reviews 46 and 48 (CI, synthetic seed); everything else is a code reading or an estimate and is labelled. I ran no tests and read no database. **Contradiction check (README rule 10):** none with `FOUNDER_DECISIONS.md` v18 on `recovery/main`. v19 (FE-068, FE-069) is on the unmerged PO branch; the PO asks the owner to confirm its narrow FE-069 reading, so I read FE-069 as proposed, not in force. **Documentation versus code (CLAUDE.md):** one: the 08:39 challenge row says «each visit costs three state taps»; the code offers start directly from `planned` (AUT-100). Documented here, nothing changed. **Task adjustment (README rule 11):** the PO asked `aia` three times (08:39, 10:39, 12:39) for input; this run answers all three before anything else. The bottleneck map is not due (2026-11-17).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-100 | Visit (step 5), the nurse on `/field`: answer to the PO challenge 08:39 «why does the nurse tap «unterwegs» before every visit?» | **IMPLEMENTED (code):** the departure tap is optional. `fieldActions("planned")` returns `["depart", "start"]` (`field/rules.ts` 61-66), so a `planned` card shows «Losfahren» **and** «Einsatz starten»; the database allows `planned → started` (0094:110). The minimum is two state taps (start, end), not three. The BD spec taps all three (`durchgang-ambulant.spec.ts` 131-134), so the act table counts 3. **The only place the tap is forced today** is «Klient:in nicht angetroffen» (`canNoShow` needs `on_the_way`, `visit-lifecycle.tsx` 55; 0072:104), which the B4 «nicht erreicht» row with CGR-191 (5) removes. **What the tap buys, automatically, when a nurse uses it:** (a) a `travel` segment in her WORK1 working-day proposal (0081: `departed` → kind `travel`), so travel time is not typed; (b) the en-route monitor `visit_stuck` (0038); (c) the team's «unterwegs» view, which lets colleagues see who is out without a call; (d) CR-051 keeps an `on_the_way` visit with its member on release. Without it, no safety signal is lost before the start: `visit_overdue` stays open while the visit is `planned` (0038, `eng` 10:13) | **Keep as is: optional, no change to the product** (nothing to eliminate; it is already a choice, and the four uses above are automation the team gets for one tap). **Do not derive travel from gaps** between visits: a gap may be a break or private time, so a derived «travel» segment would be an invented fact in a record the member confirms, and any tariff use is FE-060. **Rule for the BD counter (test code, with AUT-99):** tag the departure act `optional`, so the per-visit minimum reads 2 and the founder does not read 3 as the product's cost. **Measure replaced:** the 08:39 row proposes «how often «unterwegs» is tapped later than the start»; that cannot happen (the state machine allows no departure after a start). Use instead: share of started visits with a prior `departed` event, per team and month (team level only, never per person) | L | stage 0; `eng` (counter tag), PO (row text); `cra` (whether an en-route signal is needed for the nurse's own safety: UNKNOWN, Clinical Owner, D-28, unchanged) | BD row 5 minimum state taps per visit (code reading: 2; shown as 2 + 1 optional); share of started visits with a departure, per team (pilot; no target, it shows whether teams value the travel segment) | low | report only |
| AUT-101 | AN2 pilot measure 8 (`absence_past_visit_end`): answer to the PO question 10:39 «why does a client not reached count as a late start?» | **IMPLEMENTED (code, 0058 25-45, 440-475):** the measure takes past `planned` visits flagged when a member's absence is recorded (CGR-32) and classifies **the first visit event after the recording**: `departed` or `started` → `started_late`, `cancelled` → `cancelled` / `cancelled_without_mark`, a move → `moved` / `moved_before_capture`, none → `still_open`, else `other`. It answers «was a flagged visit picked up, and how», not «how did the visit end». A no-show is today always preceded by `departed` (0072:104), so it counts as `started_late`. The door outcome itself is not lost: it is the `no_show_open` exception and the SIG1 signal (0024:531, 0060:176), which are the safety path; AN2 is a pilot hypothesis, never a safety monitor (no P1 triage). **Gap after B4 (PLANNED):** once «nicht erreicht» is allowed from `planned` (B4 row, CGR-191 (5)), a direct no-show's first event is `no_show`, which falls into `other`: a visit that was picked up would read as unexplained | **Rule (one line in the CASE, no new measure):** classify by the first event **other than `departed`**: `started` → `started_late`; `no_show` → new ending `no_show`; `cancelled` and moves as today; only `departed` and nothing after it → `started_late` (someone set off). This keeps «picked up» separate from «not reached», with and without the departure tap, and needs no new data. Place it in the B4 brief with the DOOR1 change (AN2 is not the active block; BD-6). pgTAP: three flagged visits, (i) `departed` → `no_show` → `no_show`, (ii) `planned` → `no_show` → `no_show`, (iii) `departed` → `started` → `started_late`. Endings list (0058:475) gains `no_show`; words in the AN2 view `uxa`'s | L | stage 0; PO (placement B4), `eng` how; `cra` informed (H-01 context; no care rule is set: the measure only counts) | the three pgTAP cases; on the synthetic seed: flagged visits ending `other` (target: only those with an event the list does not name) | low | report only |
| AUT-102 | Intake (step 1), Operations: «Prüfen und in Fall überführen», then «Fall eröffnen», before any team sees the search (PO challenge row 12:39; `cra` CGR-193; `uxa` UXR-165) | **Measured (BD act table, reviews 46 and 48):** intake is the largest measured share: 23 of 61 product acts at baseline, 23 of 75 after #1109 (31 %), 18 of them inputs. **IMPLEMENTED (spec 195-214):** Operations types the referral (title, need, services, save), opens it again («Prüfen und in Fall überführen»), types 10 more fields (first and last name, municipality, canton, insurer, insurance type, order status, order valid until, start, hours per week), ticks consent and taps «Fall eröffnen». `convert_partner_request` copies `request_title` into the case's `bedarf` and does not carry `need_summary` (0013:227, 289; CGR-193 (4b)). Today one person types both forms in the run; whether partners enter referrals themselves in Phase B is OPEN | **In the design order:** (1) **eliminate the transcription** (independent of automation): the referrer's need text goes to the case (CGR-193 (4b), already placed first in the intake block by the PO 13:39) and the referral's services prefill the care-plan choice (AUT-96). (2) **One form when Operations enters the referral itself:** referral and case fields in one form; «Fall eröffnen» is its save. Removes the second open and save and the retyped title (estimate −3 of 23 acts). (3) **Rule for complete referrals:** a deterministic completeness check opens the team search without an Operations act when every `case_readiness` item is met (0073) **and** the four CGR-193 controls are met where the data are entered: (1) identity fields required; (2) consent confirmed by the person who enters it (who and how: `lca`, CGR-193 (2), UNKNOWN); (3) the question «bereits Klient:in bei uns?» answered explicitly by that person, never by automatic matching (H-05); (4) the referral's structured facts are the form's fields, and the free text travels to the case. (4) **Monitor:** a referral the rule cannot open (a missing item, «unsicher» on the returning-client question, a safety alert to set) appears in Operations' list with the missing item named; UXR-165's status line serves both paths. (5) **AI at the edge, later only:** proposing structured alerts from the referrer's free text for a named team confirmer is stage 2 or later (real referral text is client data, D-35 rule A); not proposed now. No care rule is invented: whether a person must check every referral stays UNKNOWN (`cra`: none known; Clinical Owner, `lca`) | L (intake form and rule); the alert text is G content entered by people | stage 0; PO (intake block after BD), `cra` (CGR-193 acceptance), `lca` (CGR-193 (2), (4b)), `uxa` (form, UXR-165), `eng` how | **Measure replaced:** the row's «share of referrals Operations changes before «Fall eröffnen»» is not measurable as stated, because Operations mostly adds fields rather than changing the referrer's; use (a) share of referrals that reach the team search with no Operations act, (b) median minutes from referral saved to team search open (AUT-3 intake span, team and organisation level), (c) BD row 1 acts (measured 23; estimate 20 with the one form, about 5 for Operations on a complete partner referral, the rest moved to the referrer who holds the data) | medium | report only |

### 2 Answers to the PO (08:39, 10:39, 12:39)

- **08:39 departure tap («is the state needed for any automation?»):** yes, for four (AUT-100: WORK1 travel segment, `visit_stuck`, the team's on-the-way view, CR-051 release), but the tap is already optional in the product, and the only place it is forced goes with the B4 «nicht erreicht» row. Nothing to build; the row's premise «three taps per visit» describes the BD spec, not the product, and its measure should be replaced as in AUT-100.
- **10:39 AN2 category of a no-show:** AUT-101. The category describes the first reaction to an absence flag, not the door; the door outcome is the safety path (exception, SIG1). One rule change keeps «picked up» and «not reached» apart and closes the `other` gap the B4 change would open; it rides the B4 brief.
- **12:39 «Fall eröffnen» measurement:** AUT-102, with a measurable replacement for the proposed measure.

### 3 Review of the items placed since review 48 (automation and challenge duty)

- **CGR-191 (5) and the PO decision 13:39 (#1129: «nicht erreicht» never refused on qualification grounds; `start_visit` stays refused):** supported. It removes a block in front of the only record that a client was not reached, and it moves no care act behind a weaker check. With it the B4 row also removes the last forced use of the departure tap (AUT-100).
- **`uxa` NA-1 to NA-5 with `cra` NA-4a, NA-3 (#1126, #1130):** supported. One place on the card in both states, door question first, no «Mehr» menu: no act added against today's `on_the_way` path, one tap fewer for a nurse who did not depart.
- **`uxa` M-1 to M-4 (minutes «aus Pflegeplan»):** supported; they are the display of AUT-91 and AUT-98's same-unit default, form only.
- **BD-7 (#1127, test only) and L-1, L-2:** no act added in the product; the counter is unchanged. No finding.
- **L-3 row (11:39, coordinators outside the team see date, reason, case reference only):** supported. It removes an organisation-wide read and adds no step for the team, which already sees the name on its case.
- **«Fall eröffnen» row (12:39) and CGR-193:** AUT-102. CGR-193 is the right list of controls; the challenge concerns where they are done (by a second person, after the fact), not whether.
- **FE-068 (specifications for every block) and `specs/B1.md` (on #1129, not merged):** documentation for the founder, design and engineering; no step for a nurse or a team. Δ11 (a reopened case closed before any team accepted can never be matched again and raises no exception) is supported as the first B1 PR: a case stuck with no signal is exactly the kind of silent coordination gap a rule plus a monitor should close.
- **FE-069 (on #1129, narrow reading pending the owner):** if confirmed, the D-18 billing mechanism with labelled simulation rules is the deterministic pre-send check path of FE-028 (stage 0); AI Operating Model Review §8 controls apply (no accept-all, provenance per value, named confirmer). No finding until the owner confirms.
- **Challenge check:** no item placed since review 48 adds a step, approval, role or field without a care benefit.

### 4 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-100, AUT-101, AUT-102 | new, open | §1 |
| AUT-96 | open; now also part of AUT-102 step (1) | §1 |
| AUT-99 | open; extended by the `optional` tag (AUT-100) | §1 |
| AUT-54, AUT-61, AUT-74, AUT-76, AUT-78 to AUT-86, AUT-91, AUT-94, AUT-95, AUT-97, AUT-98 | open, unchanged | – |

Closed: none.

### 5 AI readiness and stage tracking

- No delivered item since review 48 proposes, drafts or ranks (#1127 is a test). PLAN3 ledger, AIG1 register and stop rule unchanged.
- **Stage 0** stays the only stage in force (D-35). Stage 1 entry conditions unchanged: D-41 model path OPEN (owner); the production host (FE-062 to FE-064) is an application host, not an AI host. AUT-102 step (5) is named so that a later stage has its edge defined, not proposed now.

### 6 Top bottlenecks (estimates from map v3 with the measured act counts; not time measurements)

1. Documentation per visit and per shift (not yet in the measured run; B6). 2. Intake: 23 of 75 product acts (31 %); AUT-102 removes about 3 on the one-person path and most of Operations' share on complete partner referrals (estimate). 3. Planning and cover (AUT-91: −2 per hand-typed slot). 4. Assessment and care plan (16 acts; AUT-13 import for the ASM1 part). 5. Order and assessment chasing (AUT-76, AUT-97). 6. Qualification and delegation upkeep. 7. Billing preparation (J5-S, PLANNED). The visit itself costs 2 state taps (AUT-100), not 3. Recoverable direct-care time per bottleneck: as in map v3 (estimates); map v4 on 2026-11-17.

---

## 2026-11-12 08:23 CET · aia review 48: #1109 act table read (97 acts, 22 test-only, **75 product acts** against the 61-act baseline; +14 from ASM1 and the PLAN3 path); the PO's 06:39 challenge «minutes typed three times» answered (AUT-98, low: only the visit-plan entry is removable, AUT-91; the care-plan entry is the nurse's translation and stays typed); act-table reading for one-visit runs (AUT-99, low); ORD0-C3 (a') with `uxa` OF-1 to OF-6 supported; brief PROD (draft), FE-062 to FE-067 and the PO's two merge-process proposals read; no `high` finding, no issue

**Read:** `recovery/main` at `742f694` (since review 47 at `89f160e`): journal files 2026-11-12-0315-eng to 2026-11-12-0739-po; `FOUNDER_DECISIONS.md` v18 (FE-062 to FE-067); brief PROD (draft, 04:39, with `lca` (P-a) to (P-d) and `cra` CGR-190); brief ORD0 note 05:39 (ORD0-C3 (a'), CGR-189); brief J5 amendment 05:39 (F-6c); brief BD amendment 06:39; `NEXT_CAPABILITY.md` challenge rows 06:39 and 07:39; merged #1104 (CGR-185), #1109 (BD-2 steps 1b ASM1 and 3-4 PLAN3/AIG1), #1105 (my review 47), #1107, #1108, #1110, #1111, #1112. Open PRs on their heads: #1114 (`uxa` 07:52, ORD0-C3 (a') OF-1 to OF-6, UXR-164), #1113 (`eng` BD status row), #1102, #1087, #1084. **Measurement read:** the AUT-88 table printed by the `e2e` job of #1109's head `b15aa72` (`ci` 43150837874, job 130959330946, log lines 1260-1278). **Code read:** `src/app/(protected)/team/team-client.tsx` 845-925 (care-plan block and item form), `plan-assessment-basis.tsx` (ASM1-11 display), `tests/e2e/durchgang-ambulant.spec.ts` 255-320; ADR-123 (`DECISIONS.md` 2157). Open `automation` issues: #912, #940, #1030 (unchanged).

**Measured versus estimated:** the act counts below are measured by the BD-2 spec in CI (one run, synthetic seed of Testorganisation S); the time readings are estimates. I ran no tests and read no database. **Contradiction check (README rule 10):** none with `FOUNDER_DECISIONS.md` v18. FE-062 against FE-054 is the PO's open owner question (03:39), not mine to resolve. **Documentation versus code (CLAUDE.md):** none new. **Task adjustment (README rule 11):** the PO's 06:39 challenge row addressed `cra` and `uxa`; I answer the automation side because it is an act-count question (my AUT-88 counter and AUT-91), without taking `cra`'s part (whether a carried value invites unchecked confirmation) or `uxa`'s (how it is marked). The bottleneck map is not due (2026-11-17).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-98 | Assessment → care plan → visit plan (steps 1b to 3): the registered nurse; answer to the PO challenge 06:39 «minutes typed three times» | **IMPLEMENTED (measured, #1109):** the same C value is typed three times: ASM1 «Minuten C» plus «Zeitraum C» (spec 272-273), care-plan item «Minuten pro Einsatz» (287), visit plan field «C» (305). The three are not one value: ASM1 holds minutes **per period** as the provider's instrument states them (ADR-123 2, CGR-84: no conversion), the item holds minutes **per occurrence** with a free-text frequency, the visit holds the minutes **of this visit**. ASM1-11 already shows the assessed minutes with their period beside the plan's items, in the same «Pflegeplan» section and above the item form (`team-client.tsx` 845-892, `plan-assessment-basis.tsx`, IMPLEMENTED). `cra`'s condition on AUT-96 (J5 21:39): no KLV category or minutes preselected in the care-plan item. AUT-91 (medium, on the BD follow-up list for B2): the visit plan form has no B/C default from the care plan; #1109 shows this holds on the PLAN3 path too, because the team must still type the slot («Von», «Bis», «C») before the day proposal can assign it | **Per hop, in the design order:** (1) ASM1 entry: stays typed until the header import (AUT-13: deterministic import into a draft confirmed value by value; D-36, D-37, `lca`), the only route that removes it. (2) Care-plan item: **keep typed, no carry.** Turning minutes per period into minutes per visit is the nurse's planning judgement; a carried value here would be the conversion ADR-123 and CGR-84 forbid, and AUT-96's condition excludes it. The reference she needs is already on screen (ASM1-11); nothing to build. (3) Visit plan: **eliminate by rule (AUT-91, unchanged):** B and C default from the case's active care-plan items of that category, «Bis» from «Von» plus their sum; the CGR-179 deviation warning then fires only on a real change. This is a planning default from the care plan, not a clinical value: the care plan is the confirmed source and the person changes only an exception. Net: three typed entries become two, and the removed one is the one that caused the CGR-179 mismatch. No new field, no confirmation step | L (hop 3); hop 2 stays G content entered by the nurse | stage 0; `eng` how; `cra` decides whether the hop-3 default needs a mark (PO 06:39 question); `uxa` how it is shown | typed fields in BD-2 rows «3 Pflegeeinsatz für das Team planen» (today 5 inputs) and the care-plan part of «1b» (today 6); target −2 in row 3, 0 change in 1b; share of planned visits whose category minutes differ from the care plan (team level) | low | report only |
| AUT-99 | Reading the BD act table (AUT-88) after #1109: the founder and the PO judging whether administration fell | **Measured (#1109, `ci` 43150837874):** 97 acts, 22 test-only, **75 product acts** (baseline 61, #1069). Of the +14, 13 are ASM1 (8: open, 6 fields, save; counted under the row «1b Bedarfsabklärung erfassen (ASM1)», which also holds the care-plan item's 8 acts because no `acts.step` marker precedes the item, so the row «1b Pflegeplan: Leistung erfassen» shows 1 act), the day proposal (4: link, switch, date, request) and the AIG1 confirmation (1); the last one I did not attribute against the #1069 table (UNKNOWN). Two of these are not per-visit costs: the team's switch (PLAN3-10) is set once per team, and the request is once per day for all visits. With one care visit in the run, PLAN3 reads as +5 acts against the hand path; on a day of n visits the hand path costs n picks and PLAN3 one request plus n one-tap confirmations | **Rule for the counter (test code only):** (a) one `acts.step` marker before the care-plan item, so ASM1 and the item are separate rows again and row «1b Pflegeplan» stays comparable with the baseline; (b) each act tagged by scope, `once` (team or organisation setting), `per day`, `per visit`, `per case`, in one extra column, so the founder reads the per-visit cost without a second run. No new assertion, no limit (AUT-88 rule). A multi-visit day is not added to BD (BD-6); it belongs to the B5 PLAN3 measure | L | stage 0; `eng` (test code, CI table), PO (reading in the BD acceptance text) | the same table with a scope column; per-visit product acts of the run (target: shown, not asserted) | low | report only |

### 2 Answer to the PO challenge 06:39 («why does the nurse type the same minutes three times?»)

AUT-98. In short: the hypothesis is right for one of three entries. The visit-plan entry is a re-entry of a confirmed care-plan value and goes by rule (AUT-91, already on the BD follow-up list for B2; with #1109 it also costs acts on the PLAN3 path, so I suggest the PO places it with the PLAN3 slot form in B5 or B2, whichever comes first). The care-plan entry is not a re-entry: it is where the nurse turns «30 Minuten pro Tag» from the instrument into a per-visit plan; it stays typed, and the instrument value is already shown beside it. The ASM1 entry goes only with the header import (AUT-13, Phase B questions with `lca`). Whether a defaulted visit-plan value needs a visible mark is `cra`'s and `uxa`'s, as the PO wrote.

### 3 Review of the items placed since review 47 (automation and challenge duty)

- **ORD0-C3 (a') (CGR-189, PO 05:39) and `uxa` OF-1 to OF-6 (#1114, open):** supported. The order fact moves to where the person at the door decides, with no act added: OF-5 «no dismiss control, gone when the order is `present` again» is AUT-97's condition word for word. OF-4 (the start control's accessible description, never disabled) keeps the signal from becoming a hidden refusal. UXR-164 (amber, not P1 colour, for the team count): supported; one fact, one colour also means one count to read. No comment on #1114 (no finding against it).
- **CGR-190 (PROD3 organisations are simulation organisations):** supported; it keeps the QUAL1 checks identical in CI, staging and production, so no second checking path exists to maintain.
- **Brief PROD (draft) and FE-062 to FE-067:** no care workflow; it removes hand work from deployment (migrations and build only from CI). Notes for the brief, no finding: (i) open question 1 (reuse the STG1 job for PROD1): from the automation side yes, one deploy logic is one thing to keep working; (ii) open question 2 (Free pauses after 7 days): a scheduled smoke run is also the FE-048 uptime monitor, a monitor instead of someone noticing a paused project; `eng` decides how; (iii) FE-067 allows accounts by CI or by the owner: prefer CI from the PROD3 seed's declared list, so the owner has no recurring account chore and every rebuild gives the same accounts. Placement under FE-054 is the owner's question; I take no side.
- **PO proposals 04:39 (role docs PRs by auto-merge once green) and 07:39 (an `eng` PR touching only its own documentation files follows the role docs conditions):** supported from the automation side, advisory to the V1-V14 consolidation. Both conditions are mechanical (CI green, own files only, no threads), so a machine can check them; the PO keeps every behaviour merge, so no control is removed. The cost today is visible in the journals: #1109 waited from 06:39 to 07:39 with all seven conditions met because a run's merge call was refused, and docs PRs take the one Engineering slot.
- **F-6c (J5 05:39), CGR-185 (#1104), BD-2 steps 1b and 3-4 (#1109):** no step added beyond what the care flow requires; measured in AUT-99. No finding.
- **Challenge check:** no item placed since review 47 adds a step, approval, role or field without a care benefit.

### 4 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-91 | open; evidence extended: the visit-plan re-entry also costs acts on the PLAN3 path (#1109 row 3: 5 inputs) | §1 AUT-98 |
| AUT-97 | open; its condition is in `uxa` OF-5 (#1114, PROPOSED) and ORD0-C3 (a') | brief ORD0 note 05:39; #1114 |
| AUT-98, AUT-99 | new, open | §1 |
| AUT-54, AUT-61, AUT-74, AUT-76, AUT-78 to AUT-86, AUT-94 to AUT-96 | open, unchanged | – |

Closed: none.

### 5 AI readiness and stage tracking

- **PLAN3 in the continuous run (#1109, IMPLEMENTED in test):** the first BD proof of a proposing rule agent with its ledger: the proposed line is confirmed by one tap and stored as `day_plan` with reason `knows_client` and state `confirmed`, read back as the nurse through RLS. Against §8 of the AI Operating Model Review: suggestion ledger yes (`day_plan`); provenance per value yes (reason per line); named confirmer yes (the nurse); no accept-all yes (one line, one tap); correction rate per agent and field and the stop rule: unchanged, not exercised by a one-line run (a rejection path is not in BD; B5 measure).
- **Stage 0** stays the only stage in force (D-35). Stage 1 entry conditions: D-41 model path OPEN (owner); D-2: production on synthetic data only is now directed (FE-062 to FE-064) and compliant on (P-a) to (P-d) (`lca` 04:27), but it is an application host, not an AI host, so it meets no stage-1 condition; real data on that stack is unresolved (adviser, owner). AIG1 register IMPLEMENTED for rule agents only.

### 6 Top bottlenecks (estimates from map v3, act counts measured in #1109; not time measurements)

1. Documentation per visit and per shift (not yet in the measured run; steps 6-7 «nicht nachgewiesen», B6). 2. Intake: 23 of 75 product acts (31 %), unchanged in count. 3. Planning and cover: rows 1b plan, 3 and 4 hold 18 acts for two visits; AUT-91 removes 2 per hand-typed slot. 4. Assessment and care plan: 16 acts (ASM1 about 8, item about 8), new in the run; only AUT-13's import removes the ASM1 part. 5. Order and assessment chasing (AUT-76; ORD0-C3 at zero acts with AUT-97). 6. Qualification and delegation upkeep. 7. Billing preparation (2 acts, J5-S PLANNED). Direct-care time recoverable per bottleneck: as in map v3 (estimates); map v4 on 2026-11-17.

---

## 2026-11-12 02:22 CET · aia review 47: my review-46 support line for CGR-182 corrected to CGR-184 (whoever holds the right to plan sees the count only); `cra`'s CGR-186 correction to AUT-95 accepted (the assessment summary shows text and structure side by side, unmarked); ORD0-C3 (CGR-187) supported as a derived signal with one condition, new AUT-97 (low); BD-4 part 1 (#1093) and part 2 (#1096), FE-057 to FE-061 and COORD-7 (4a-c2) read; no `high` finding, no issue

**Read:** `recovery/main` at `89f160e` (since review 46 at `b87ffec`): journal files 2026-11-11-2022-lca to 2026-11-12-0139-po; brief J5 amendments 21:39 and 01:39, brief BD amendments 21:39 and 01:39, brief ORD0 note 01:39; `FOUNDER_DECISIONS.md` v17 (FE-057 to FE-061); merged #1069 (BD-2), #1091 (my review 46), #1093 (BD-4 part 1), #1094, #1099, #1101, #1103. Open PRs on their heads: #1096 (BD-4 part 2, pgTAP 128, `83a9fcb`), #1104 (CGR-185 assertions, `3ef831e`), #1100, #1102 (`eng` docs), #1087 (STG1), #1084 (dependabot). Code read: `private.visit_flags` (migrations 0024 line 427, 0030 line 248), `src/features/team/rules.ts` line 8. Open `automation` issues: #912, #940, #1030 (unchanged).

**Measured versus estimated:** no new measurement this run; the 61-act baseline of review 46 §2 stands (measured by `eng`, CI run 43037240509). I ran no tests and read no database. **Contradiction check (README rule 10):** none with `FOUNDER_DECISIONS.md` v17. **Documentation versus code (CLAUDE.md):** none new. **Task adjustment (README rule 11):** the PO (21:39) and `cra` (21:27, 01:31) asked `aia` to align with CGR-184; done first in §2. The bottleneck map is not due (2026-11-17).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-97 | Planning and visit start after an order change (steps 3-5, ORD0-C3 in B7): the team of the case | **IMPLEMENTED:** `order_expired` is a derived visit flag (`private.visit_flags`, 0024 line 427), counted in the team's plan status (0030 line 248) and shown on `/team` («nach Ablauf der Verordnung», `team/rules.ts` 8); nobody sets or clears it. **PLANNED (ORD0-C3, PO 01:39):** a second flag for B minutes whose order is not `present` on the visit date. **OPEN:** whether it joins the same derived family and the same team count, or becomes a separate exception or task. ORD0-4 already raises a P3 exception that ends by itself; ORD0 exists because a task that no command can close taught teams to ignore tasks (CGR-36) | **Rule (one derived order signal):** ORD0-C3 is computed in `visit_flags` like `order_expired` (no stored row, no task, nothing to close by hand); it is counted with `order_expired` in the team's one plan-status count of visits needing an order («Verordnung fehlt oder abgelaufen», words `uxa`'s); it clears when the order is `present` again (ORD0-C3 (b) already tests this). No new rule about care: whether the start is refused stays D-22/D-28 (Clinical Owner, `legal`). Test (pgTAP, with ORD0-C3 (b)): after the order is set back, the team count rises by the number of affected B visits and falls back when it is `present` again, with no command by a person | L (signal only) | stage 0; `eng` how, `uxa` (words, one count), `cra` confirms the flag text (ORD0-C3 (c)) | manual acts to raise or clear the order signal per affected visit (target 0); order counts the team must read on `/team` (target one, not two) | low | report only |

### 2 Correction of review 46 (CGR-184) and of AUT-95 (CGR-186)

- **CGR-184:** review 46 §3 supported the 17:39 text as written, which gave the per-visit short-visit lines to members **with** the right to plan. That was the reverse of (c3); my proposed B8 test («a member given the right by her team sees the lines») was wrong in the same way. **Corrected:** I support CGR-184 as adopted (J5 21:39): whoever holds the right to plan for the visit's team sees the W-2 count only; a reader without that right may see the lines; e2e «a member given the right by her team: the lines disappear». My condition stands unchanged and is in the J5 21:39 text: C-3 is a right the team gives its own members, not a role above the team. From the automation side the count is enough for a planner: no planning act needs the per-visit lines, so the correction removes no step and adds none. Lesson for my own reviews: I quote the `cra` remedy's test sentence when I support a PO paraphrase (the PO's 21:39 process proposal), instead of checking only the challenge side.
- **AUT-95 / CGR-186:** `cra` 21:27 is right; the assessment summary shows the frequency text and the PLAN2 structure side by side (`assessment/rules.ts` 309-312), but unmarked; only the handover shows the text alone. AUT-95's proposal and measure are unchanged; the PO placed it on the B2 follow-up list with `cra`'s interim (structure in the handover, a mismatch marked on both views).

### 3 Review of the items placed since review 46 (automation and challenge duty)

- **ORD0-C3 (CGR-187, PO 01:39):** supported. It replaces a late discovery at billing (`b_without_valid_order` on the fact, after the visit) with a signal before the visit, at no act for the team; the condition is AUT-97 (one derived family, one count, nothing to close by hand).
- **CGR-188 (J5 01:39, grade-neutral marker):** no act added; no finding. The test is a string check, cheap and kept.
- **BD-4 part 1 (#1093, merged) and part 2 (#1096, open; #1104 CGR-185):** test only; they prove existing refusals on the BD case shape. No act added; no finding.
- **FE-058 ((G-b) A, owner):** the PLAN3 day proposal is switched on by a synthetic administrator and counted as its own row. **Note for reading the measure (no finding, the decision stands):** the row is a one-off organisation setting, not a per-case act; the BD act table should keep it apart from the per-run product acts so later runs stay comparable with the 61-act baseline. H-BD-1 (the team's own switch, review 45) is unchanged: the team still owns whether it plans with the proposal.
- **FE-061 (lost merge-commit run: `ci` plus `ci-repeat` 10/10):** engineering governance, no care workflow; no finding.
- **COORD-7 (4a-c2), three-dot carry-over diff (`cra` 01:31):** supported from the automation side: it removes the re-gate of a head whose new diff is only already-cleared `recovery/main` code (#1093 waited two PO runs for that), with equal safety because the PR's own change still needs a gate line. A coordination step removed, no control removed. Advisory to the PO's COORD-7 consolidation.
- **Challenge check:** no item placed since review 46 adds a step, approval, role or field without a care benefit.

### 4 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-95 | open; placed on the B2 follow-up list with `cra`'s interim (CGR-186); evidence corrected (§2) | brief J5 amendment 21:39 |
| AUT-96 | open; placed on the B2 follow-up list with `cra`'s condition (no KLV category or minutes preselected) | brief J5 amendment 21:39 |
| AUT-97 | new, open | §1 |
| AUT-54, AUT-61, AUT-74, AUT-76, AUT-78 to AUT-86, AUT-91, AUT-94 | open, unchanged | – |

### 5 AI readiness and stage tracking

- No delivered item proposes, drafts or ranks since review 46 (#1069, #1093: tests). The PLAN3 ledger, register and stop rule are unchanged.
- **Stage 0** stays the only stage in force (D-35). Stage 1 entry conditions unchanged: D-41 model path OPEN (owner); D-2 hosting: staging stays on Free with synthetic data only until Phase B (FE-059), which is a CI target, not an AI host; AIG1 register IMPLEMENTED for rule agents only. FE-060 confirms the Phase B billing inputs (D-18, D-22, D-44, BS/BL residual financing) are OPEN, so no billing-preparation agent beyond the deterministic J5 path can be specified yet.

### 6 Top bottlenecks (estimates from map v3 with the measured act counts of review 46; not time measurements)

Unchanged from review 46 §6: 1. documentation per visit and per shift (not yet in the measured run); 2. intake (23 of 61 measured acts); 3. planning and cover (21 of 61 on the hand path); 4. order and assessment chasing (AUT-76; AUT-97 keeps ORD0-C3 at zero acts); 5. qualification and delegation upkeep; 6. billing preparation (2 measured acts, removed by J5-S, PLANNED). Map v4 on 2026-11-17.

---

## 2026-11-11 20:20 CET · aia review 46: measured AUT-88 baseline (#1069, 61 product acts) compared with the static count of review 45 (they agree up to the two sign-ins); AUT-88, AUT-92, AUT-93 closed (measured, adopted); CGR-182 count-only default and K-3 (no catch-up button) supported; new AUT-95 (medium: a care-plan item's frequency is entered twice, once as free text the next nurse reads and once as the structure the series planner uses, and the two can differ), AUT-96 (low: the service named in the referral is typed again for the care-plan item); the act distribution of the measured run as the first measured input to map v4

**Read:** `recovery/main` at `b87ffec` (since review 45 at `1548e20`): journal files 2026-11-11-1439-po to 1839-po (`uxa` 15:48, `lca` 16:25, `eng` 17:05 and 18:13, `cra` 17:27); brief J5 amendments 14:39, 16:39, 17:39; brief BD amendments 17:39, 18:39; merged #1071, #1072, #1077 to #1082, #1085, #1086, #1088, #1089. Open PRs on their heads: #1069 (`eng`, BD-2, head `2c5149a`, merge of `recovery/main`; the AUT-88 table comment of 17:12 UTC read in full), #1087 (STG1, waits for the owner record FE-057), #1090 (`uxa` 19:53, UXR-163), #1084 (dependabot). Code read: `src/app/(protected)/team/team-client.tsx` (346, 889-913), `src/app/(protected)/team/auto-plan.tsx` (119-157), `src/features/handover/rules.ts` (195), `src/features/assessment/rules.ts` (308-312), `tests/e2e/durchgang-ambulant.spec.ts` on `2c5149a` (act counter 60-95, step 1 178-210). Open `automation` issues: #912, #940, #1030 (unchanged).

**Measured versus estimated.** The table in §2 is **measured** by `eng` on the synthetic seed (Testorganisation S), copied from CI run 43037240509; I did not run it. Everything else below is a reading of code or documents, or an estimate, and is labelled so. I ran no tests and read no database. **Contradiction check (README rule 10):** none with `FOUNDER_DECISIONS.md` v16. **Documentation versus code (CLAUDE.md):** none new. **Task adjustment (README rule 11):** the bottleneck map is not due (2026-11-17); the PO asked `aia` (18:39) to compare the measured baseline with the static count, so this run does that and uses the measured distribution as the first measured input for map v4.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-95 | Care plan and series planning (steps 1b to 4, PLAN2/PLAN3): the registered nurse who writes the care-plan item, the next nurse who reads it | **IMPLEMENTED:** the item form asks «Häufigkeit» as required free text (`team-client.tsx` 912-913, «z. B. 3x pro Woche»). To plan the item as a series, the nurse opens «Rhythmus» and enters the frequency again as structure: period (default «pro Woche», `auto-plan.tsx` 119), times per week, weekdays, window «Von»/«Bis» (133-157). The text is not parsed and not checked against the structure. The handover (`handover/rules.ts` 195) and the assessment summary (`assessment/rules.ts` 312) show the **text**; the series planner uses the **structure**. A text «3x pro Woche» with a structure «täglich» saves without a hint, so what the next nurse reads and what NAVORA plans can differ | **Rule (one entry, text derived):** the item form takes the frequency once, as the structure PLAN2 already stores (period, times, optional weekdays, optional window); the display text is generated from it («3× pro Woche, Mo/Mi/Fr, 08:00-10:00»); a free note stays optional for what the structure cannot say («nach Rücksprache»). An item without a structure (only a note) is planned by hand as today. No new field, no new rule about care; the structure is the one PLAN2 has. Test: an item saved with «3 pro Woche, Mo/Mi/Fr» shows that text in the handover and the planner creates three visits in a week; there is no path that stores a text and a structure that disagree | L (form and derivation; the care-plan content does not change) | stage 0; `cra` (care-plan display, what the handover must show), `eng` how, `uxa` (form) | typed or selected fields per care-plan item planned as a series (code reading today: 6 in the item form plus 4 to 10 in «Rhythmus»; target: one form); items whose text and structure differ on the synthetic seed (target 0, a check `eng` can run on the seed) | medium | report only |
| AUT-96 | Care-plan item after intake (step 1b): the registered nurse | **IMPLEMENTED:** the referral records «Leistungen (mit Komma getrennt)» (`intake-client.tsx`; BD-2: «Grundpflege»), shown on the team's offer as `required_services` (`team-client.tsx` 346). The care-plan item asks «Leistung» as free text again (889-913; BD-2: «Grundpflege» typed a second time) | **Rule (prefill from the care graph):** «Leistung hinzufügen» offers the case's referral services as choices; the nurse picks one or types another. The referral's words are a starting point, not a care decision; the category, minutes and goal stay the nurse's entries | L | stage 0; `eng` how, `uxa` (form); `cra` only if the choice list may suggest a KLV category (I propose it does not) | typed fields in the care-plan step of the BD-2 run (measured today 6 inputs; target 5) | low | report only |

### 2 Measured AUT-88 baseline against the static count (review 45 §2)

Measured: `eng`, CI run 43037240509, job 130662360122, 2026-11-11 (synthetic seed). The spec counts a selection and a tick as an «Eingabe» and a sign-in as one act (spec 60-95).

| Step | Measured total (product) | Static count, review 45 | Difference and reason |
|---|---|---|---|
| 1 intake and case (Operations) | 23 (18 inputs incl. 1 tick) | 22 (17 fields, 1 tick separately) | +1 sign-in; inputs agree (17 fields + 1 tick = 18) |
| 1 team takes the case | 3 | 2 | +1 sign-in |
| 1b plan the assessment visit | 6 | 6 | – |
| 5 + 8 assessment visit run and sign | 6 | 6 | – |
| 1b care-plan item | 9 | 9 | – |
| 4 plan the care visit (hand) | 6 | 6 | – |
| 5 + 8 care visit run and sign | 6 | 6 | – |
| 9 billing facts | 2 | 2 | – |
| **Total product acts** | **61** | **59** | the two sign-ins |
| Test-only (F3 «Testlauf») | 22 | 24 | the static count included the two reloads; the spec does not count them |

**Reading (IMPLEMENTED baseline; the time per act is UNKNOWN, so no minutes are claimed):**
- **Intake** carries 23 of 61 acts (38 %): the largest single block, as the PO's 18:39 challenge states. **Planning** (assessment slot, care-plan item, care-visit slot) carries 21 (34 %). **Visit execution and signature** carry 12 (20 %), i.e. 6 per visit, of which 3 are status taps. **Team take-over** 3, **billing** 2.
- **Design arithmetic, not a measurement:** AUT-91 (−2 typed fields per hand-planned visit), AUT-94 (−1 to −2 at intake), AUT-96 (−1 per care-plan item) and J5-S (−2, B8 PLANNED) would bring this run from 61 to about 54 to 55 product acts. Intake stays the largest block; only REF2 (structured referral, agent A1 as a rule, A8 later at level H) can remove most of its 18 inputs, and A8 needs the D-34 module, the Clinical Owner and D-35 stage 1 or later.
- **Not in the run** (so not yet measured): steps 3-4 PLAN3/AIG1 and 6-7 B6 documentation; the PLAN2 series path where AUT-95 sits; the ward. The map v4 rows for documentation and cover therefore stay estimates.

### 3 Review of the items placed since review 45 (automation and challenge duty)

- **J5-S with K-3 (no catch-up button, scheduled catch-up, one team group count K-1, failure on the visit line K-4, nothing at signature K-5; PO 14:39, 16:39):** supported; it is AUT-92 as proposed and removes the monthly team act in full. `lca` 16:25: derivation at signature changes when reference rows are read, not which (IMPLEMENTED `build_billable_fact` by `visit_date`). **Closed AUT-92 (adopted, PLANNED B8).** For the AI operating model this is the first PLANNED instance of agent A6 (control health) as a deterministic job.
- **CGR-180 (2) with CGR-183 (f1)-(f3) and `uxa` F-1 to F-6:** the check at the F3 save, never a refusal, a warning saved through stays visible on the fact and the report review. **Closed AUT-93 (adopted, PLANNED B8/BILL1).** (f2) adds no act: the stored warning is written by the save, not by a person.
- **CGR-182 (count-only short-visit line for team members by default; per-visit lines with the right to plan for the team, C-3; PO 17:39):** supported; no review list arises for team members. **Challenge check (condition, not a finding):** C-3 must stay a right the team holds and gives to its own members (any member may hold it, the team changes it, audited), not a role above the team; who holds the right is UNKNOWN today (`uxa` C-3). Test for the B8 PR: a team member without the right to plan who is given it by the team sees the lines without any role outside the team acting. If the B8 brief ties C-3 to a coordination or management role, I will raise it as a finding.
- **D-18/12, D-18/13 (`lca`, Phase B/M4):** no Phase A act; M4 must take insurer and residence as of the visit date from the case history, not by a person re-checking each fact (note for the M4 brief, PLANNED).
- **#1087 (STG1) and the CI install outage (PO 17:39 challenge):** no care workflow; no finding. The four hours of red required checks without a code cause cost block delivery, not care time; the PO's proposal to `eng` (cache or pin the browser, keep all four checks) is supported.
- **#1090 (`uxa` UXR-163):** internal codes on `/field`; covered by #508; no act added; no finding.
- **Challenge check:** no item placed since review 45 adds a step, approval, role or field without a care benefit.

### 4 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-88 | **Closed (implemented):** the BD-2 spec counts acts per step; the measured table is the BD reference count (61 product acts, 22 test-only) | #1069 comment 17:12 UTC (run 43037240509); brief BD amendment 18:39 |
| AUT-92 | **Closed (adopted):** J5-S scheduled catch-up only, K-1 team count, no button (K-3); PLANNED B8 | brief J5 amendments 14:39, 16:39 |
| AUT-93 | **Closed (adopted):** CGR-180 (2) at the F3 save and on the fact, CGR-183 (f1)-(f3); PLANNED B8/BILL1 | brief J5 amendments 14:39, 17:39; `cra` 17:27 |
| AUT-91, AUT-94 | open; recorded for the B2 follow-up list (PO 14:39); open until built | PO 14:39 |
| AUT-74 | open; AUT-88's counter is its first step (B11 reuses it) | – |
| AUT-54, AUT-61, AUT-76, AUT-78 to AUT-86 | open, unchanged | – |

### 5 AI readiness and stage tracking

- No delivered item proposes, drafts or ranks since review 45 (#1072: texts; #1071: seed). The PLAN3 ledger, register and stop rule are unchanged.
- **Stage 0** stays the only stage in force (D-35). Stage 1 entry conditions unchanged: D-41 model path OPEN (owner), D-2 hosting OPEN (STG1 `navora-staging` is a CI target for synthetic migrations, not an AI host; its record FE-057 is OPEN), AIG1 register IMPLEMENTED for rule agents only. New this run: a **measured act baseline** exists (AUT-88), so every later stage can be compared with the same counter (AI Operating Model Review §12, "measure acts before agent stages").

### 6 Top bottlenecks (estimates from map v3, 2026-11-10 02:20, with the first measured act counts; not time measurements)

1. Documentation per visit (home care) and per shift (ward): AUT-54/-72; not in the measured run. 2. Intake: 23 of 61 measured acts (AUT-94, REF2, A1/A8). 3. Planning and cover: 21 of 61 measured acts on the hand path (AUT-91, AUT-95, AUT-96); cover after absence PLAN3, COVER1, POOL1 (AUT-83) not measured. 4. Order and assessment chasing: AUT-76. 5. Qualification and delegation upkeep: AUT-78 to AUT-81, AUT-86. 6. Billing preparation: 2 measured acts, removed by J5-S (PLANNED). Map v4 on 2026-11-17 will rank intake against documentation once B6 runs in BD; until then documentation stays first on the estimate.

---

## 2026-11-11 14:24 CET · aia review 45: PO runs 08:39 to 13:39, D-18 Phase A decided (M3, J5-v4 in B8), #1064 merged with the deny-by-default guard, `eng` J5 derive-on-sign answer (#1077), `cra` CGR-180/-181 (#1078), BD-2 spec on #1069 read; AUT-87 closed (implemented), AUT-89 and AUT-90 closed (adopted, PLANNED B8); H-BD-1 and derive-on-sign supported; new AUT-91 (medium: a care visit's minutes are typed three times and never prefilled from the care plan), AUT-92 (medium: a failed or missing derivation needs a monitor, not a monthly catch-up button), AUT-93 (medium: the sequence and overlap check of CGR-180 (2) belongs at the F3 save, where the person knows the true times), AUT-94 (low: the client's location is entered three times at intake); a first static act count of BD-2 (not a measurement)

**Read:** `recovery/main` at `1548e20` (since review 44 at `2da7569`): journal files 2026-11-11-0839-po to 1239-po (`eng` 08:40, 09:13; `lca` 08:45, 12:32; `cra` 09:32; `uxa` 11:48); D-18 PO decision 08:39 (Phase A M3, `J5-v4`, B8; Phase B `awaiting-approval: owner`, frozen); brief J5 amendments 08:39, 10:39, 12:39; brief BD amendments 08:39, 10:39; #1064 merged (`b4f4577`). Open PRs on their heads: #1069 (`eng`, BD-2, head `f782230` with the CGR-180 (1) fix of 14:20; spec read in full), #1071 (seed G-a/G-b, `cra` clear), #1072 (G-6 codes, `cra` clear), #1077 (`eng` J5 answer; comment on #1069), #1078 (`cra` 13:30, CGR-180, CGR-181), #1079 (PO 13:39: merges refused by the session's permission check). Code read: `src/app/(protected)/team/team-client.tsx` (plan form, lines 480-500, 1010-1040), `src/app/(protected)/intake/intake-client.tsx` (lines 160-170, 335-360). Open `automation` issues: #912, #940, #1030 (unchanged).

**Nothing below is a measurement.** I ran no tests and read no database; CI states are as `eng` and the PO record them. The act count in §2 is a **static count of the commands in the BD-2 spec** (`tests/e2e/durchgang-ambulant.spec.ts` on `f782230`), not a count from a run and not the AUT-88 table (still owed by `eng`, PO comment on #1069 09:43). **Contradiction check (README rule 10):** none with `FOUNDER_DECISIONS.md` v16. **Documentation versus code (CLAUDE.md):** none new. **Task adjustment (README rule 11):** the bottleneck map is not due (2026-11-17). This run uses the BD-2 spec as the first full list of acts NAVORA asks for along steps 1 to 9 and reviews the B8 items placed today.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-91 | Planning a care visit (steps 2 to 4, hand path): the registered nurse or the team member who plans | **IMPLEMENTED:** the care-plan item already holds «Minuten pro Einsatz» (BD-2 spec: 30 for category C). The plan form then asks again for «Von», «Bis» and «Geplante Minuten pro KLV-Kategorie» (`team-client.tsx` 1027-1036): A defaults to 45 only before the assessment; **B and C have no default**; «Bis» is not derived from the minutes. In BD-2 the same 30 minutes are entered three times (care plan, slot length, field C). `cra` CGR-179: hand-planned category minutes are not checked against the care plan, and the fact takes them from the snapshot (D-18 (I3)): the re-entry is also the source of the mismatch | **Eliminate through the care graph (rule):** the plan form prefills B and C from the case's active care-plan items of that category and «Bis» from «Von» plus their sum; the person changes only an exception, and the CGR-179 warning then fires only on a real deviation. PLAN3 already plans from the care plan (no new logic, the same source). No new field, no confirmation; the prefill is a default, not a care-plan change. Test: for a case with one active C item of 30 minutes, the form opens with C = 30 and «Bis» = «Von» + 30; a deviation still saves (warning as CGR-179 decides) | L | stage 0; `eng` how, `cra` (CGR-179 owner; (I3)), `uxa` (form) | typed fields per hand-planned visit on the BD-2 run (today 4 plus save; target 2: date, start); share of planned visits whose category minutes differ from the care plan (team level) | medium | report only |
| AUT-92 | Billable fact (step 9, J5) if derived on sign (PO challenge 12:39, `eng` #1077, `cra` CGR-181) | **IMPLEMENTED:** the normal case (report final, no hold) gets its fact only from «Abrechnungsfakten erzeugen» (`generate_billable_facts`, 0051), a manual act per team and month (`eng` #1077 (1)). **PLANNED if placed:** a trigger on `final` calls the same `build_billable_fact`; `eng` proposes that a build error never rolls back the signature and leaves the report in `not_generated`, "the catch-up path picks it up"; CGR-181: a failed derivation must never be silent. If the catch-up path stays a button, someone must remember to press it and look for gaps; that is the act derive-on-sign removes | **Monitor instead of a catch-up act:** keep `generate_billable_facts` as a scheduled catch-up (no person), and add one control-health line at team level: "final reports without a fact older than 24 h: n" (target 0; the 24 h is a proposal for `po`, not a rule), shown on `/abrechnung` (CGR-178 placement), never on `/field` or the plan form. The button can then disappear or become an exceptions view (`uxa`). Test: a forced build failure keeps the signature (as `eng` proposes), leaves the report without a fact, and the line shows 1 until the catch-up builds it | L | stage 0; `po` (B8 placement), `eng` how, `cra` (CGR-181 (s1)-(s5)), `lca` (reference-data timing, `eng` #1077 (3)) | manual billing acts per team and month (target 0); final reports without a fact older than 24 h (target 0) | medium | report only; comment on #1077 |
| AUT-93 | Time correction F3 (`correct_visit_time`) and the billing review after it: the nurse who corrects, the team that reviews | **IMPLEMENTED:** F3 has no lower bound and no sequence check (0040:63-64, 95-96; `cra` CGR-180, CR-206 UNVALIDATED); planning refuses a care visit before the assessment (CR-002, 0014:214-219), but a correction can create that order and an overlap of the same nurse's two visits. **PLANNED** (CGR-180 (2), B8/BILL1): warnings `started_before_needs_assessment` and `overlaps_own_visit` on the fact. A warning first seen on the fact is seen weeks later by someone reviewing billing, who must then find out the true times from the nurse (one review item plus one coordination per case) | **Rule at the source, plus the fact warning:** the same two checks run when the correction is saved and are shown to the person correcting, before she saves («Dieser Einsatz beginnt vor dem Ende der Bedarfsabklärung» / «überschneidet sich mit deinem Einsatz …»; words `uxa`); she may still save (never a refusal, as CGR-180 (2)), and only then does the fact carry the warning. One check function for both places, so they cannot drift. The person who knows the true times answers the question at the moment she knows them; the billing review sees only what was saved knowingly | L | stage 0; `cra` (CGR-180 owner, CR-206), `eng` how, `uxa` (words) | warnings of the two kinds per 100 facts on the synthetic run; share first raised at F3 versus first raised on the fact (target: all at F3) | medium | report only |
| AUT-94 | Intake (step 1, J1): Operations recording a referral and opening the case | **IMPLEMENTED:** the referral asks «Region» as free text (`intake-client.tsx` 167-168, required); the case form asks «Wohngemeinde» (free text) and «Kanton» (list, 345-355). In BD-2: «Basel-Stadt», «Basel», «BS»: three entries of one place. Of 22 acts in step 1 (§2), 17 are typed or selected fields | **Rule (derive):** the canton is offered from the municipality (official Swiss municipality register, BFS; a reference table, not a NAVORA rule), and the case form takes the region over from the referral; the person corrects only when they differ. Whether «Region» (team routing) and canton (financing) may differ is a product question for `po` (UNKNOWN). No field removed without that answer | L | stage 0; `po` (region meaning), `eng` how, `lca` (none expected: same data, fewer entries) | typed or selected fields in step 1 on the BD-2 run (today 17) | low | report only |

### 2 Static act count of BD-2 (commands in the spec on `f782230`; not a run measurement)

Counted: every `click`, `fill`, `selectOption`, `check` the spec performs as a person. Navigation = a menu or tab link. **Test-only** = the F3 corrections of Q-BD-1 (A) and the reload; they would not exist in real work. Steps 3-4 (PLAN3/AIG1) and 6-7 (B6) are not in the run yet.

| Step (spec section) | Who | Product acts | of which typed or selected fields | Test-only acts |
|---|---|---|---|---|
| 1 J1 referral and case | Operations | 22 (1 nav, 2 forms: 7 + 10 fields, 1 tick, 3 buttons) | 17 | 0 |
| 1 J2 team takes the case | nurse | 2 | 0 | 0 |
| 1b plan the assessment visit | nurse | 6 | 4 | 0 |
| 5/8 run and sign the assessment visit | nurse | 6 (1 nav, 3 status taps, 1 optional summary, 1 sign) | 1 (optional) | 14 (open F3, 3 × 4 correction acts, reload) |
| care-plan item | nurse | 9 (1 nav, 1 add, 6 fields, 1 save) | 6 | 0 |
| 2/4 plan the care visit (hand path) | nurse | 6 | 4 | 0 |
| 5/8 run and sign the care visit | nurse | 6 | 1 (optional) | 10 (open F3, 2 × 4, reload) |
| 9 billing facts | nurse (team) | 2 | 0 | 0 |
| **Total** | | **59** | **33** | **24** |

Reading (estimate, labelled): the nurse's visit execution is already lean (3 taps and 1 signature per visit, report drafted from the visit data). The acts sit in **intake** (17 fields, AUT-94 touches 3) and in **planning** (minutes typed again, AUT-91 removes 2 per visit). Step 9 disappears with derive-on-sign (AUT-92). This replaces no AUT-88 table; it gives `eng` and the PO a list to compare the run's table against.

### 3 Review of today's B8 items, BD and H-BD-1 (automation and challenge duty)

- **D-18 Phase A M3 (PO 08:39):** adopted as AUT-89 proposed; no short visit becomes a review item. **Closed AUT-89.**
- **CGR-178 (billing page `/abrechnung`, P-1 to P-6, P-3 every team member sees her own team's page):** removes billing from the planning view (AUT-90's question). Supported; the team-level view without a coordination role between keeps billing preparation with the team. `cra` (c3) short-visit lines as a count only: supported (no per-visit review list). **Closed AUT-90.**
- **CGR-179 Phase B direction (warning at planning, invoice hold, never a refusal of care):** no administration added in Phase A. For Phase B the hold release is a person's act per held line (D-18/11 OPEN); AUT-91 lowers how often a hold arises. No challenge now; re-check when the release rule is drafted.
- **J5 derive on sign (PO challenge 12:39, `eng` #1077, CGR-181):** supported; it is UXR-157 and removes one act per team and month. AUT-92 adds the monitor so the catch-up needs no person.
- **H-BD-1 (team-owned day-proposal switch, PO 10:39, asked of `aia`):** supported. The setting belongs to the team that plans with it; any member switches it, audited, no administrator role (#1071 seeds the organisation setting only; the team switch is a team act in the run). Measure at team level only: switch-offs per team and month with the stated reason; never who switched. **Challenge check:** none; this removes a hierarchy step.
- **CGR-180 (1) on #1069 (test only):** a test correctness fix, no product act; no finding. CGR-180 (2): see AUT-93.
- **#1072 (codes to `data-ref`) and #1071 (seed):** no act added; no finding.
- **Challenge check:** no item placed today adds a step, approval, role or field without a care benefit. The seeded organisation setting in #1071 bypasses the AIG1 act (`cra` residual); fixture only, correct for BD, and consistent with H-BD-1.

### 4 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-87 | **Closed (implemented):** the app guard is deny by default over every `.ts`/`.tsx` under `src`, nine named readers, fixture with two unlisted folders fails | #1064 merged `b4f4577` (PO 11:39), CI green on the merge commit (PO 12:39); `eng` 09:13 |
| AUT-88 | **Adopted** (BD amendment 08:39); open until `eng` posts the per-step table on #1069 (PO comment 09:43). §2 gives a static cross-check | PO 08:39; #1069 comments |
| AUT-89 | **Closed (adopted):** D-18 Phase A M3; built in B8 as `J5-v4` (PLANNED); M1 stays UNVALIDATED until then | `decisions/D-18.md` PO 08:39; brief J5 08:39 |
| AUT-90 | **Closed (answered):** CGR-178 moves the billing preview to its own page (PLANNED B8) | `cra` 09:32; PO 10:39, 12:39 |
| AUT-74 | open; AUT-88 is its first step | – |
| AUT-54, AUT-61, AUT-76, AUT-78 to AUT-86 | open, unchanged | – |

### 5 AI readiness and stage tracking

- No delivered item proposes, drafts or ranks since review 44. #1071 switches the PLAN3 rule agent on for Testorganisation S by seed (fixture); the AIG1 register, ledger and stop rule of PLAN3 are unchanged.
- **Stage 0** stays the only stage in force (D-35). Stage 1 entry conditions unchanged: D-41 model path OPEN (owner), D-2 hosting OPEN, AIG1 register IMPLEMENTED for rule agents only. The (I1) control is now IMPLEMENTED on both sides (pgTAP 125, app guard).

### 6 Top bottlenecks (estimates, unchanged from map v3, 2026-11-10 02:20; not measurements)

1. Documentation per visit (home care) and per shift (ward): AUT-54/-72. 2. Planning and cover after absence: PLAN3, COVER1, POOL1 (AUT-83); hand planning re-entry AUT-91. 3. Order and assessment chasing: AUT-76. 4. Qualification and delegation upkeep: AUT-78 to AUT-81, AUT-86. 5. Billing preparation: derive on sign (AUT-92), F3 conflicts at the source (AUT-93). Intake (AUT-94) enters map v4 as its own row: in the static count it is the largest block of typed fields. Next refresh 2026-11-17.

---

## 2026-11-11 08:20 CET · aia review 44: BD-1 inventory (#1057), BD amendments 04:39 to 06:39, D-18 `cra` template 05:26, UXR-155 (#1060) and open PRs #1062, #1063, #1064 read; UXR-157 and the `uxa` answer on a positive QUAL1 line supported; new AUT-87 (medium: the D-18 (I1) app guard in #1064 lists guarded folders, so the PLAN3 day proposal, the AIG1 confirmation page, assessment and care-plan code and every future proposing feature are outside it), AUT-88 (medium: BD-2 is the first end-to-end run and can give the first measured count of human acts per step, now instead of B11), AUT-89 (medium: D-18 M1 turns every correctly short visit into a not-billable fact and a correction incentive; M3 supported from the administration side), AUT-90 (low: the planning form and the team's billing preview share one page, `cra` to judge against hazard (h2))

**Read:** `recovery/main` at `2da7569` (since review 43 at `8186b80`): PO runs 02:39 to 06:39 (merges #1048, #1050, #1039, #1051 to #1061; B0 accepted 03:39 under FE-054 (3); BD active); `FOUNDER_DECISIONS.md` v16 (FE-056: GitHub Actions is the agents' test environment); `briefs/BD.md` amendments 02:39, 04:39, 05:39, 06:39 (Q-BD-1 (A), Q-BD-2 yes, Q-BD-3 Basel-Stadt; UXR-155 to UXR-157); `docs/engineering/DURCHGANG_INVENTORY.md` (BD-1); `decisions/D-18.md` `cra` template 05:26 (M1 to M4, invariants (I1) to (I5)) and D-14 `lca` re-check 04:20; `CLINICAL_GOVERNANCE.md` 05:26 (CGR-176, CGR-177); `UX_REVIEW.md` 03:52; #1060 diff (`src/features/field/todo.ts`, `field-client.tsx`). Open PRs on their heads: #1062 (`eng`, Q-BD-2 seed organisation S, migration 0124, pgTAP 124), #1063 (`uxa` 07:52, UXR-158, answer on a «geprüft» line), #1064 (`eng`, D-18 (I1) pgTAP 125 and unit guard, M3 size). Open `automation` issues: #912, #940, #1030 (unchanged).

**Nothing below is a measurement.** I ran no tests and read no database; CI states are as the PO records them. A grep of `src` for billing imports and tables (this run, on `2da7569`) is the only evidence I produced. **Contradiction check (README rule 10):** none with `FOUNDER_DECISIONS.md` v16. FE-056 matches the CI-only test path my findings assume. **Documentation versus code (CLAUDE.md):** none new; the inventory's PARTIAL and MISSING labels match the code I read (QUAL1 matrix only in a simulation organisation; `visit_qualification_check` has no caller in `src/`). **Task adjustment (README rule 11):** the bottleneck map is not due (next refresh 2026-11-17). BD is the active block, so this run reviews BD from the administration side and checks the one proposing-adjacent guard (#1064).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-87 | Planning, proposals and AI drafts (D-18 invariant (I1)): every rule agent and future AI agent | **OPEN, #1064:** `tests/unit/d18-i1-no-billing-in-planning.test.ts` checks a **list of guarded folders** (`features/planning`, `ai`, `field`, `cover`, `absence`, `signals`, `work`, `handover`, `visits`, `qualification`, three routes). Outside the list: `app/(protected)/team/tagesplan` (PLAN3 day proposal), `team/vorschlaege` (AIG1 confirmation), `team/auto-plan.tsx`, `features/assessment`, `features/cases`, `features/team` (where planned minutes and the care plan live, the core of (I1)), and every new folder a proposing feature will get (POOL1 matcher A13, the documentation path A7). The guard passes when such code imports billing. **Evidence:** grep of `src` on `2da7569` for `@/features/billing`, `@/components/billing`, `billing_preview`, `billing_rules`, `tariff_rates`, `min_billable_minutes`, `billable_facts`: the only files are `features/billing/*`, `components/billing/billing-preview.tsx`, `features/analytics/hypotheses.ts`, `app/(protected)/analytics/page.tsx`, `operations/page.tsx`, `operations-client.tsx`, `team/page.tsx`, `team-client.tsx`, `lib/supabase/database.types.ts`. pgTAP 125 is already deny-by-default on the database side (a new reader fails) | **Rule (guard), deny by default:** invert the app test like pgTAP 125: every `.ts`/`.tsx` file under `src` is guarded **except** a named list of billing readers (today the nine files above); a new reader fails and is reviewed against (I1). Adds no step and no screen; makes every future agent folder guarded from its first commit. Test: a fixture import of `@/features/billing` in a new folder under `src/features/` fails the guard; the current tree passes | L | stage 0 (guard for every later stage); `eng` how, `cra` (I1 owner) | number of billing readers outside the named list (target 0, CI) | medium | report only; comment on #1064 |
| AUT-88 | Durchgang ambulant BD-2, all steps 1 to 9 (FE-054): the founder judging whether administration fell | **PLANNED** AUT-74 (adopted for B11, `PRODUCT_BLOCKS.md` §5 "Protokoll der Administration"): human acts per flow step from the same run, no threshold. **BD-2** (brief, inventory §3) is the first test that runs steps 1 to 9 through screens only (G-1, no `page.goto` but `/login`) at 390 px. Each command the test performs is a human act the product demands; today nobody counts them, and the bottleneck map (v3) rests on estimates only | **Monitor, no new tap:** the BD-2 spec records per step the acts it performs (submitting controls, typed fields, ticks, confirmations, screen changes) and writes them to the CI artifact next to the run. Test-only acts are tagged and not counted as product acts (the F3 correction «Testlauf: simulierte Einsatzdauer» of Q-BD-1 (A)). Not a pass criterion, no new rule (BD-6 holds); the same counter serves B11 later. Synthetic seed only | L | stage 0; `po` (BD acceptance text), `eng` how | acts per step and per flow on the synthetic run; the first measured baseline of map v3 rows 1 to 9; compared later with BD-H and with the pattern-3/A7 path of step 7 (AUT-72) | medium | report only |
| AUT-89 | Billable fact (BD step 9, J5) and the billing review that follows it: team and operations | **IMPLEMENTED (CR-029, UNVALIDATED, reading disputed):** a visit whose billable minutes are under 10 gets `below_minimum` and is **not billable** (0051:214-216). Every correctly short visit (eye drops, a medication-box check) then becomes a not-billable fact with a reason, i.e. an item someone must look at, explain or correct. The only path that makes it billable is a time correction (F3, `correct_visit_time`), which BD now uses on its main path (Q-BD-1 (A)) and which the fact does not show (CGR-176 (3), D-18 hazard (h4)). The administrative cost: a review queue of not-billable facts that are not errors, plus a standing incentive to correct times | **Rule (none applied):** support `cra` option **M3** for Phase A: the fact stores measured and billable minutes with no minimum or unit; "under 10 minutes" is a warning, not a reason. No review queue arises from a correctly short visit, no correction is needed to reach billability, and BD's main path would need no F3 correction (one test-only act and one acceptance sentence less). With M3 or not: the warning of CGR-176 (3) on corrected minutes stays (it is what makes a correction visible without a review step). Owner decision (D-18); nothing set by me | L | stage 0; owner (D-18), `lca` (questions 1, 9), `cra` (I1 to I5) | team level: share of facts not billable only because of `below_minimum` on the synthetic run; F3 corrections per 100 visits | medium | report only; comment on #80 |
| AUT-90 | Planning a visit on `/team` (registered nurse planning minutes and the responsible member) | **IMPLEMENTED:** `team/page.tsx` and `team-client.tsx` render the team's «Abrechnungsvorschau» (`components/billing/billing-preview.tsx`) on the same page as «Einsatz planen» with planned minutes. D-18 (I1) covers functions, not what the planning person sees; `cra` (h2): the split incentive "becomes real only when someone or something plans with billing data in view". The field app shows no billing data (I2, IMPLEMENTED) | **No proposal of mine on the rule:** a question to `cra` whether the preview belongs on the planning page; if not, it moves to its own team page (B8, UXR-156/-157 already reshape it). Adds no step; removes billing from the planning view | L | stage 0; `cra` (h2), `uxa` where it goes | – | low | report only |

### 2 Review of BD and the D-18 template (automation and challenge duty)

- **BD-1 inventory:** a clean map of acts and commands per step; no step added. Steps 3 and 4 (PLAN3, AIG1) are already rule plus confirmation (stage 0). The breaks are test-path breaks, not new administration. AUT-88 uses the run.
- **UXR-155 (#1060, merged):** one «Zu erledigen» link with a count, no client name, absent at 0. A monitor cue that removes a coordination call; supported. The count is of the team's open offers, not a per-person figure.
- **UXR-157 (routed to B8):** supported: the billable fact is derived when the report is signed, by the same command, no button (eliminates a monthly manual act per team). Same direction as AUT-89.
- **QUAL1 positive line (PO question, `uxa` 07:52 in #1063):** supported option 3 (a): the plan dialog offers only members the rule allows, so the refusal never appears in normal work (eliminate, not display). Against a per-visit stored pass written by a person; if `cra` wants the fact, the backstop writes it with the rule version (no act).
- **Q-BD-2 seed (#1062):** synthetic, fixture-only evidence, no person enters anything; no finding.
- **Challenge check:** no BD amendment adds a step, approval, role or field for a person in the product. The F3 correction of Q-BD-1 (A) is a test act, labelled as such; AUT-88 keeps it out of the act count, AUT-89 would remove it.

### 3 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-74 | open; AUT-88 proposes to start the count in BD-2 instead of B11 | `PRODUCT_BLOCKS.md` §5 "Protokoll der Administration" |
| AUT-54, AUT-61, AUT-76, AUT-78 to AUT-86 | open, unchanged | – |

### 4 AI readiness and stage tracking

- No delivered item proposes, drafts or ranks since review 43 (#1060 is a count link; #1062 a seed and a guard). #1064 is a control for every future agent; AUT-87 makes it cover the agent folders by default.
- **Stage 0** stays the only stage in force (D-35). Stage 1 entry conditions unchanged: D-41 model path OPEN (owner), D-2 hosting OPEN, AIG1 register IMPLEMENTED for rule agents only. New control candidate for the catalogue: no agent input reads a billing parameter, tested deny-by-default on both sides (pgTAP 125 IMPLEMENTED on its PR; app side AUT-87).

### 5 Top bottlenecks (estimates, unchanged from map v3, 2026-11-10 02:20; not measurements)

1. Documentation per visit (home care) and per shift (ward): AUT-54/-72 path. 2. Planning and cover after absence: PLAN3, COVER1, POOL1 (AUT-83). 3. Order and assessment chasing: AUT-76. 4. Qualification and delegation upkeep: AUT-78 to AUT-81, AUT-86. 5. Billing review of facts that are not errors: AUT-89, UXR-157. Next refresh 2026-11-17; AUT-88 would give rows 1 to 9 their first measured act counts.

---

## 2026-11-11 02:30 CET · aia review 43: FE-053 to FE-055 and briefs FEE1, GMSEP, POOL1, ONB1, RDATA1, BD read; AUT-80 adopted as B2-T12e (e2)/(e3) with CR-205 as test basis and AUT-81 with CGR-171 (both PLANNED, open until green); `cra` CGR-172 (FEE1 rewards unconfirmed days) supported; new AUT-82 (medium: the FEE1 fee also charges every declared minute of administration, so the admin measure decays), AUT-83 (high: POOL1 needs an availability entry and an undefined team decision per offer), AUT-84 (medium: the POOL1 "AI" is a rule at stage 0 and must be registered as one), AUT-85 (low: business model derived, never typed), AUT-86 (medium: an open self-confirmation contradiction needs an age signal to the verification path); V1-V14 statement in `proposals/2026-11-10-konflikte-qualitaet/aia.md`

**Read:** `recovery/main` at `c651a24` (since review 42, `72e794c`): PO merges #1031 (my review 42), #1027, #1028, #1034, #1020 (B0-7), #1032 (B0-1), #1033, #1035, #1040, #1041, #1046, #1047; `FOUNDER_DECISIONS.md` v15 (FE-053 journal per file, FE-054 block for block and merge only with green tests, FE-055 management brief); briefs `BD.md`, `FEE1.md`, `GMSEP.md`, `POOL1.md`, `ONB1.md`, `RDATA1.md`; `PRODUCT_BLOCKS.md` B2-T12e; `CLINICAL_GOVERNANCE.md` 21:27 (CGR-170, CGR-171, CR-205); proposals folder `2026-11-10-konflikte-qualitaet/` (README, `eng.md`); journal files 2026-11-10-2227-po to 2026-11-11-0039-po. Open PRs on their heads: `cra` #1048 (01:26: CGR-172 to CGR-175, `cra.md`), `eng` #1039 (B0-4). Briefs `WORK1.md`, `COVER1.md`, `PLAN3.md` read for the pooling and fee paths. Code read: `grep -i availab` over `supabase/migrations` (only ABS1 absence and ADM2 reason code `availability_mismatch`; **no availability record exists**). Open `automation` issues: #912 (AUT-54), #940 (AUT-61), #1030 (AUT-80).

**Nothing below is a measurement.** I ran no tests and read no database; CI states are as the PO and `cra` record them. **Contradiction check (README rule 10):** my prompt (step 7) limits my PR to three files; FE-054 (4) and the PO's procedure (proposals README, 22:50) ask every role for a statement in its own file `aia.md`. I follow FE-054 and add that fourth file; recorded in my journal entry. No other contradiction with `FOUNDER_DECISIONS.md` v15. **Documentation versus code (CLAUDE.md):** POOL1-2 names "unplanned confirmed availability"; no such record exists in code (AUT-83). I change nothing. **Task adjustment (README rule 11):** bottleneck map not due (next refresh 2026-11-17; POOL1 and FEE1 enter it then as rows under cover and billing); this run reviews the FE-055 briefs, which are approved but not yet built, the cheapest moment to remove a step.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-82 | Billing team → NAVORA (FEE1) and team self-organisation, working time (each member) | **PLANNED** FEE1-3: FTE from **confirmed** working time (WORK1). WORK1-2 asks for work outside visits (team meeting, training, administration, on-call) before a day can be confirmed; WORK1-6 uses the confirmed paid minutes as the denominator of the North Star. Under FEE1 every declared outside-visit minute **raises the team's fee** (until the 1.0 cap). `cra` CGR-172 (1) covers the unconfirmed day; this is the confirmed day: a team pays less by declaring less administration. NAVORA's second success measure (administrative burden) and the denominator of its first (direct-care share) are then fed by an entry the fee penalises. **Patient-care benefit of charging per declared admin minute:** none shown; the founder chose FTE weighting for fairness between teams (FE-055 (3)), not per minute | **Rule (decouple the margin), for `po` and the owner (D-14):** (1) support CGR-172 (a), (b) (a visit-derived floor; unconfirmed visit days counted, team level); (2) the fee FTE per member and month is taken in **bands** (band width a D-14 parameter, owner; not set here), so a member's declared outside-visit minutes move the fee only when the band changes; (3) test: adding or removing up to one band width of outside-visit segments in a confirmed month never changes the fee, crossing a band does; FEE1-4 firewall test unchanged. If the owner rejects bands: (2') the fee FTE counts the visit-derived day plus a fixed share, and declared outside-visit segments stay in WORK1 only (the owner must weigh this against FEE1-4's "no billed-hours input") | L | Stage 0, deterministic; gate D-14 (owner), `lca` L-14 (does banding change the reading), `cra` (CGR-172) | team level, Phase B only (synthetic data show no behaviour): share of confirmed member-days with an outside-visit segment, and median declared outside-visit minutes per confirmed day, before and after the fee takes effect | medium | report |
| AUT-83 | Cover and pooling (POOL1): team self-organisation, Matching, Team Decision (each member; the team) | **PLANNED** POOL1-2: idle capacity "from its own plan (unplanned confirmed availability)". **IMPLEMENTED:** NAVORA holds no availability record; a member is plannable unless an ABS1 absence covers the interval (0048:12, 163). So POOL1 as written needs **a new per-member entry** ("I am available on …") before any match, repeated every week a member wants pooled work, kept current or wrong. POOL1-4 "the team decides (accept/decline)" names no actor: if every offer goes to a team vote, a short-term shift waits on a coordination round, the slowest step of exactly the case pooling is for. COVER1 already answers both: the covering member accepts for herself (`accept_cover`), absence is the only availability fact. **Patient-care benefit of an availability entry or a per-offer team vote:** none shown (POOL1-3, -6 protect qualification and data, and need neither) | **Eliminate through the care graph + team rule:** (1) idle capacity = interval with no planned visit or shift of the member and no ABS1 absence, from existing facts only; **no availability entry** (a member who does not want pooled work says so once, as a standing setting, not per week); (2) the team sets **once** a standing pooling mandate (FE-028 "routine cases only under an explicit team mandate"): pooling on/off, and any limit it chooses; off by default (PLAN3-10 pattern); (3) within the mandate the **member named in the match accepts for herself**, as in COVER1; no per-offer vote; the team sees every accepted engagement at once (team level); (4) `cra` CGR-173 (3) (overlap refused, absence releases) applies unchanged | L | Stage 0 (rule); gate `po` (brief text), `cra` (CGR-173 holds), `lca` L-7 before real use (already in POOL1) | team level: entries a member makes before her first pooled match (target 0); time from release of demand to acceptance (synthetic run, BD/POOL1-8); accepted engagements per month and team | **high** | #1049 |
| AUT-84 | Matching (POOL1-3, AI leverage 4): proposal of released demand to a team | **PLANNED** POOL1 says "the AI proposes matches" and "a ranked list … level L"; D-35: only stage 0 is in force (rules, synthetic data), and FE-051 patterns 1-3 run as rules inside NAVORA. The brief does not say the matcher is a rule, does not register it in AIG1, names no ranking keys, no ledger, no stop rule. PLAN3 (`plan3_day_proposal`, kind `rule`, PLAN3-6) is the pattern | **Rule, registered like an agent:** POOL1 matcher as AIG1 agent kind `rule`, level L, off by default, synthetic evaluation fixture (AIG1-9), stop threshold, every shown match in the suggestion ledger with its inputs (idle interval, QUAL1 state per named member **in context NH-EXT**, CGR-173 (1)), field allow-list (no residents' or institution staff data); ordering by fixed, published keys chosen by `po` (not learned); wording "NAVORA schlägt vor (Regel)", not "KI". A learned ranking is a later stage and a new decision | L | Stage 0; gate `po`, `uxa` (wording), `cra` (context) | team level: share of shown matches accepted, declined and ignored per month; ledger completeness 100 % (test) | medium | report |
| AUT-85 | Referral/order and billing (GMSEP-1): whoever creates an order or engagement | **PLANNED** GMSEP-1: every order carries `business_model` and constellation, "set at creation". The brief does not say by whom; if a person picks two values per order, that is two fields per order with no care benefit, and a wrong pick is unchangeable (correction = new record) | **Rule:** both values derived from the creating path (team order from a client or institution → `gm1_team` with its constellation; an institution's own staff use under its licence → `gm2_b2b`; POOL1 acceptance → `gm1_team`/KON-1, POOL1-5); never a field on a form; test: no screen offers either value, every creating command sets them | L | Stage 0; gate `po`, `eng` (inventory, open question 1) | records without business model: 0 (GMSEP nightly check); form fields per order unchanged by GMSEP (0 added) | low | report |
| AUT-86 | Team self-organisation, qualification record (B2-T12e under CR-205 option B): the member, the verification path | **PLANNED** CR-205 (2): a differing self-confirmation keeps the member `contradictory` until the verification path writes a newer verified record or a resolution record; nothing else ends it, and the release under (b5) has already returned her delegates' visits. Today nothing tells the verification path that a contradiction is open or how old it is; the lockout lasts as long as nobody notices. The rule itself is right (a member must not clear her own flag) | **Monitor:** a deterministic list for the verification path of open contradictions with their age and the count of released visits (no grade shown beyond what the path already holds), plus the A6 control-health line "open contradictions older than N days" (N set by the Clinical Owner with CR-205; not set here); B2-T12d's preview tells the member before she saves that a differing grade can only be ended by verification (`uxa` words) | L | Stage 0; gate Clinical Owner (N, with CR-205), `cra`, `uxa`; Phase B writer `lca`/D-29 | team level: open contradictions and their age at the end of each week; visits released by a contradiction per month | medium | report |

### 2 Review of FE-055 briefs and BD (automation and challenge duty)

- **FEE1:** removes manual fee calculation (good); no AI, correctly. CGR-172 (a)-(d) supported; AUT-82 adds the confirmed-day margin. FEE1-5 n = 2 notice adds no step. No other finding.
- **GMSEP:** a database rule, monitored nightly; no AI, correctly. AUT-85 only.
- **POOL1:** the right problem (idle hours are the main GM-1 income risk) and the right boundary (team decides, own GM-1 order). AUT-83, AUT-84; `cra` CGR-173 covers the clinical conditions.
- **ONB1:** one step at founding, information only, reminder at team level after 30 days, no AI. **Challenge check:** the step protects nurses from unlimited joint liability, a legal duty in substance; its form (one record "chosen" or "not yet", no per-screen confirmation) is lean. No finding; `cra` CGR-174 (Phase B gate) supported, as a rule on the existing record, no new step.
- **RDATA1:** arithmetic over aggregated figures, no AI, no nurse effort. No finding.
- **BD:** the flow test is where administration becomes testable (AUT-74, OPEN): see V-aia-2 in `aia.md`.

### 3 Status of open findings changed by this run

| AUT | Status | Evidence |
|---|---|---|
| AUT-80 | **Adopted** as B2-T12e (e2) stop case and (e3) with CR-205 as test basis (PO 21:39); career case removed with no added step (option A); slip case left to the verification path (option B), see AUT-86. Open until (e3) is green after the Clinical Owner's decision (D-43). #1030 stays open | `PRODUCT_BLOCKS.md` B2-T12e; `CLINICAL_GOVERNANCE.md` 21:27 |
| AUT-81 | **Adopted** with CGR-171 (a revoke never waits on its replacement) for the delegation screen (QUAL1 part 2). Open until built | `PRODUCT_BLOCKS.md` B2 row (PO 21:39) |
| AUT-54, AUT-61, AUT-74, AUT-76, AUT-78, AUT-79 | open, unchanged | – |

### 4 AI readiness and stage tracking

- No delivered item proposes, drafts or ranks since review 42 (B0-1, B0-7 are CI tooling). POOL1 is the first new proposing item: AUT-84 lists the controls it needs before build.
- **Stage 0** stays the only stage in force (D-35). Entry conditions for stage 1 unchanged: D-41 model path OPEN (owner), D-2 hosting OPEN, AIG1 register IMPLEMENTED for rule agents only. FE-055 adds no AI service: FEE1, GMSEP, ONB1, RDATA1 state "no AI", POOL1 runs inside NAVORA (D-35 rule A).

### 5 Top bottlenecks (estimates, unchanged from map v3, 2026-11-10 02:20; not measurements)

1. Documentation per visit (home care) and per shift (ward): largest recoverable share; AUT-54/-72 path. 2. Planning and cover after absence: PLAN3, COVER1, now POOL1 (AUT-83 keeps it at zero added entries). 3. Order and assessment chasing: AUT-76. 4. Qualification and delegation upkeep: AUT-78 to AUT-81, AUT-86. Next refresh 2026-11-17.

---

## 2026-11-10 20:30 CET · aia review 42: PO runs 14:39 to 18:39, `cra` 17:35, `uxa` 15:50 read; AUT-78 adopted as B2-T12d (d1)/(d2) and AUT-79 as B2-T12b (b4) (both PLANNED, open until green); B2-T12b (b5) "release as the result of the re-check after every write" supported; correction of my AUT-78 measure; new AUT-80 (high: a grade contradiction is permanent in code, so one differing self-confirmation or a grade change over a career locks a nurse out for good and, under (b5), returns every dependent visit to the team, with no resolution path), AUT-81 (low: correcting a delegation releases its visits if revoked before the replacement is recorded)

**Read:** `recovery/main` at `72e794c` (since review 41, `0f7858b`): PO merges #1017 (my review 41), #1018 (B0-2 interim evidence), #1019, #1021, #1023, #1025 (PO runs 14:39 to 18:39; Blueprint v2.39 to v2.43), #1022 (`uxa` 15:50: UXR-151 to -153), #1024 (`cra` 17:35: CGR-168, CGR-169), #1026 (B0-8 migration-order check, ADR-177). Files: `PRODUCT_BLOCKS.md` B2 row (B2-T12b (b4), (b5); B2-T12c (1), (4); B2-T12d (d1), (d2)), `CLINICAL_GOVERNANCE.md` 17:35, `UX_REVIEW.md` 15:50. Open PRs read on their heads: `lca` #1027 (D-22, D-43 Q-43a; B2-T12d count "compliant under every plausible interpretation"), `uxa` #1028 (expiry form), `eng` #1020 (B0-7), #1029 (B0-1 negative probe, never merged). Code read: `20261021000120_qual1_1_matrix_evidence_check.sql` (evidence table and guard :200-245, `qual_evidence_state` :249-270, `record_delegation` :466-547, `revoke_delegation` :549-583, delegation match :703-711); `grep` under `src` for `record_delegation`, `revoke_delegation`, `confirm_my_qualification` (only `database.types.ts`). Open `automation` issues: #912 (AUT-54), #940 (AUT-61).

**Nothing below is a measurement.** I ran no tests and read no database; CI states are as the PO records them. **Contradiction check (README rule 10):** none between my prompt and `FOUNDER_DECISIONS.md` (v12, unchanged). **Documentation versus code (CLAUDE.md):** the Blueprint (§1.6 evidence states, "treated as '?' **until a person resolves it**") and QUAL1-5 promise a resolution; the code derives `contradictory` from every grade record ever written to an append-only table, with no resolving record or command (AUT-80). I change nothing; I document it and propose. **Task adjustment (README rule 11):** the bottleneck map is not due (next refresh 2026-11-17); FE-052 §8 (5) keeps `aia` on concept work beside B0. This run follows the B2 release rules to the states that start them, to see whether a release can become permanent.

**Correction of review 41 (AUT-78 measure):** I proposed to count "L1 releases followed within 24 h by a grade record that would have restored them (a proxy for slips)". In the code no later grade record restores anything: once two grade records differ, the state stays `contradictory` (AUT-80). The measure is replaced by AUT-80's. My review-41 text stays as written.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-80 | Team self-organisation, qualification record (any member; the delegating or supervising nurse in particular), then planning (the team) | **IMPLEMENTED:** `member_qualification_evidence` is append-only (`qual_guard_evidence`, 0120:225-229). `qual_evidence_state` returns `contradictory` when `count(distinct grade)` over **all** grade records of the member is above 1, whatever their state (`self_confirmed` or `verified`), date or expiry (0120:254-261). Nothing writes a resolving record and no command clears it; the migration header says "nothing is resolved automatically" (0120:22), and no person can resolve it either. **Effects:** (1) one self-confirmation with a different grade, also a slip, makes the member `contradictory` **for good**: she fails every grade-dependent check and, if she delegates or supervises, `qual_may_delegate` fails (0120:455-462), so every delegation she gave stops counting (0120:709-710). (2) A grade change over a career (a second **verified** grade record) has the same effect. (3) **PLANNED** B2-T12b (b2)(i) and (b5)(1) release every dependent future visit of her delegates in that moment; B2-T12d shows her the count, but after saving nothing can bring the visits or her plannability back. The team re-plans her and her delegates' work, and keeps doing so for every later delegation she can no longer give. **Patient-safety benefit of "contradictory → refuse":** shown (no guess between two grades, CR-181). **Benefit of making it permanent with no resolution path:** none shown; the Blueprint and QUAL1-5 promise a resolution "by a person" that is not built and not in the B2 test basis | **Rule, the resolution as a recorded fact, no new approval role:** the contradiction is derived from the records **in force**, and there is one way to end it that the verification path already owns. Options for `cra` and the Clinical Owner (the rule is theirs; I set none): (A) a newer **verified** grade record supersedes older verified ones (the verification is the resolving person, D-29), and a `self_confirmed` record that differs makes the grade `contradictory` only until a newer verified record or a newer matching self-confirmation exists; (B) an append-only resolution record written only by the path that writes `verified` (never an app user, never an agent, QUAL1-3, AIG1 class `qualification`). Either keeps "contradictory → refuse" and "never resolved to the higher grade" (CR-181) unchanged. Until decided: B2 names the gap (stop case or scoped out by name), so B2 is not accepted with a one-way state | L (state derivation); the resolution rule is a qualification rule (`cra`, Clinical Owner, D-43) and its Phase B verification process is D-29 (`lca`) | stage 0; `po` (B2 test basis or scope line), `cra` (rule A, B or other), `lca` (who may write the resolving record in Phase B), `eng` | pgTAP on the synthetic seed: (i) verified `fage_efz`, later verified `nurse_hf_fh` → the state the chosen rule names, not `contradictory` for ever; (ii) a differing self-confirmation followed by the resolving record → the grade counts again and a new assignment is allowed; (iii) the resolution never yields the higher grade without a verified record. Team-level measure: members in `contradictory` longer than 7 days; visits released by contradictory transitions, per team and month | **high** | #1030 |
| AUT-81 | Delegation correction (delegating, supervising or primary nurse), then planning (the team) | **IMPLEMENTED:** a delegation's fields cannot be edited; a correction is `revoke_delegation` plus a new `record_delegation` (0120:466-583). The check takes any valid, unrevoked delegation for the visit (0120:703-711, newest `valid_until` first), so several may stand side by side. **PLANNED** (b5)(1): the release follows the re-check after each write. So "record the new one, then revoke the old one" releases nothing the new one covers, while "revoke, then record" releases every dependent visit of that delegate, case and activity, and the team must re-assign them although the cover never lapsed for a day. No screen calls either command yet (`src` only in `database.types.ts`) | **Rule in the command, no new step:** when the delegation screen is built, "Delegation ändern" records the replacement and revokes the old one in one transaction, in that order; a plain revoke stays immediate (a safety act, never delayed or made costly). pgTAP: a replacement that covers the same future visits releases none of them; a plain revoke releases them (as (b)) | L | stage 0; `po` (with the delegation screen, QUAL1 part 2), `uxa` (one act, wording), `eng` | per team and month on the synthetic seed: releases caused by a revoke followed within the same day by a delegation covering the same visits (target: none). Team level only | low | report only |

### 2 Briefs, packages and items reviewed (challenge duty)

- **B2-T12b (b5) (PO 17:39 after CGR-168):** the release is the result of the re-check after **every** write that can change it, and keeps `on_the_way`, `started`, `paused` with their person, as CR-051. **Supported:** it adds no act and makes the rule true on paths no one would think to list (the fixture write); keeping a started visit avoids a mid-care hand-back. It also makes the replacement order of AUT-81 safe, and it is exactly why AUT-80 matters: every contradictory transition now releases.
- **B2-T12d split (d1) now, (d2) with the profile screen (UXR-152), with the `cra` conditions (release independent of the preview; one function):** **supported**; the count shows what the unchanged rule does and holds nothing back. `cra`'s integrity note (cancelling must not discourage a true record) is right and is the reason AUT-80 must be solved in the derivation, not by a heavier warning in the preview.
- **B2-T12c (1) position on `/team` and `/visits/<id>` (UXR-151), (4) last valid day (UXR-153, CGR-169):** display only, no act; the line sits where the team already works. Supported.
- **B2-T12b (b4) (AUT-79):** adopted as proposed. Supported.
- **B0-8 migration-order check (#1026, ADR-177), B0-7 (#1020), B0-2 interim evidence:** test infrastructure; no workflow step. No finding.
- **`lca` #1027 (D-22/3, D-22/9, D-43 Q-43a):** legal questions for the owner's adviser; no care-team act added. The B2-T12d answer (count only) closes the `lca` part of AUT-78's gate on merge. No finding.
- **`uxa` #1028 (one expiry form «gültig bis <Tag> (abgelaufen)»):** wording; no act. No finding.

### 3 AI readiness of delivered items (§8)

Nothing merged since review 41 proposes, drafts or ranks. No §8 check due. AUT-80 touches the AIG1 prohibited class `qualification` only to confirm it: no agent may write the resolving record.

### 4 Stage tracking

Unchanged from review 41: stage 0 met on the main line ("gemergt", no block "abgenommen"); pattern 4 preparation OPEN (AIO1 frozen, no model server, D-2 hosting not chosen, synthetic marker missing, Clinical Owner's evaluation bar UNKNOWN); stage 1 not decided (FE-051). B2 not acceptable (B2-T12a to -T12d not written, CGR-168); AUT-80 adds one more open point, so the PLAN3 rule agent's qualification input is not yet block-accepted.

### 5 Findings closed and state changes

- **AUT-78:** adopted by the PO 14:39 as B2-T12d, split 16:39 into (d1) (function, with B2) and (d2) (e2e with the profile screen); `cra` 17:35: sets no rule; `lca` #1027: count only is compliant. Open until (d1) is green.
- **AUT-79:** adopted by the PO 14:39 as B2-T12b (b4). Open until green.
- **AUT-76, AUT-67 (2), AUT-54 (#912), AUT-61 (#940), AUT-49, AUT-69 to AUT-71, AUT-74, AUT-75:** open, unchanged.

---

## 2026-11-10 14:30 CET · aia review 41: PO runs 08:39 to 13:39 and `cra` 09:35, 13:35 read; AUT-77 closed (B2-T12a to -T12c in the B2 test basis) with a correction of my review-40 premise; AUT-76 adopted with CGR-165 conditions (PLANNED, build blocked on the lead value); B2-T12b (b2), (b3) and B7-T6 reviewed; (b3) "release, not fail-closed" supported; new AUT-78 (medium: one self-confirmation by a delegating nurse can return every dependent delegate visit to the team without her seeing the consequence), AUT-79 (low: B2-T12b tests the release, not that the team can re-cover the released visits from its normal list)

**Read:** `recovery/main` at `0f7858b` (since review 40, `169dde2`): PO merges #1004 (my review 40), #1006, #1009, #1010, #1014, #1016 (PO runs 08:39 to 13:39; Blueprint v2.34 to v2.38), #1007 and #1015 (`cra` 09:35, 13:35: CGR-164 to CGR-167), #1003, #1011 (`uxa`: UXR-148 to UXR-150), #1002, #1005, #1008 (B0-3 parts 3 to 5, tests only), #1012 (B0 runner ports, ADR-174). Files: `PRODUCT_BLOCKS.md` (B0-2 counting rule, B0-3, B2-T12a to -T12c, B7 AUT-76 with B7-T4 to -T6, §9), `decisions/D-43.md` (addendum 13:39), `CLINICAL_GOVERNANCE.md` 09:35 and 13:35 (L1 to L4 table). Code read: `20261021000120_qual1_1_matrix_evidence_check.sql` (`confirm_my_qualification` from line 273), `20261021000121_qual1_2_every_path_and_start.sql`. Open PRs: #998 (`lca`), #3 (M2); no `aia` PR open. Open `automation` issues: #912 (AUT-54), #940 (AUT-61).

**Nothing below is a measurement.** I ran no tests and read no database; CI states are as the PO records them. **Contradiction check (README rule 10):** none between my prompt and `FOUNDER_DECISIONS.md` (v12, unchanged). **Task adjustment (README rule 11):** the bottleneck map is not due (refreshed in review 39; next refresh 2026-11-17); FE-052 §8 (5) keeps `aia` on concept work beside B0. This run reviews the post-assignment release rules for the re-planning work they hand to the team.

**Correction of review 40 (AUT-77):** I wrote that the planning-time prevention of a lapse foreseeable from a recorded end date (QUAL1-22) was PLANNED. `cra` CGR-164 (i) shows it is **IMPLEMENTED as a refusal**, stronger than the notice I proposed: in a simulation organisation every assignment path reads the evidence at the visit's planned end and the delegation for the visit's date, refuses with `qualification_not_allowed`, and PLAN3 does not propose the member (0120:257, :662-666, :703-711; 0121:12-20). The real gap is a lapse recorded **after** assignment (QUAL1-22 (2)). My review-40 text stays as written; this line corrects it.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-78 | Team self-organisation, qualification record (the delegating or supervising nurse herself), and then planning (the team) | **PLANNED (B2-T12b (b2)(i), PO 13:39 after CGR-166):** when a delegating nurse records a different grade with `confirm_my_qualification`, every future planned visit of every delegate that depends on one of her delegations is released to the team as open, in the same transaction. Per `cra` (L1, 13:35) a self-confirmed grade that differs makes her grade `contradictory`, so the release follows from an ordinary self-service command (0120:273 ff.), also for a correction or a slip. The command today returns no count of dependent visits (0120:273-300 read: it records the grade; no impact listing). So one tap by one nurse can hand the team an unplanned re-planning batch, and she learns of it only when colleagues see open visits. Patient-safety benefit of the release itself: shown (the start check would refuse the visit at the door, H-01); benefit of doing it **unseen**: none shown | **Rule, shown at the act, no new approval:** before `confirm_my_qualification` saves a grade that would release dependent visits, the screen tells the acting nurse **only** the consequence at team level ("Damit gehen <n> geplante Einsätze ans Team zurück"), with save and cancel; n = 0 shows nothing, so the normal case gets no extra step. The release rule (b2) stays unchanged; nothing is held back once she saves. The count is computed by the same re-check the release uses (one function, so preview and release cannot disagree). No colleague sees her grade (CGR-152); the coverage fact on the released visits names no person's qualification | L (consequence of a recorded fact; no clinical rule set) | stage 0; `po` (add to B2-T12b), `uxa` (wording, place), `cra` (that the preview sets no rule), `lca` (what the acting nurse may see of delegates' visits: a count only) | per team and month on the synthetic seed: visits released by L1 events; L1 releases followed within 24 h by a grade record that would have restored them (a proxy for slips). Team level only | medium | report only |
| AUT-79 | Planning after a release (the team) | **PLANNED (B2-T12b (b), (b2), (b3)):** each release puts visits back as open with a coverage fact; (b3) may release many at once when a matrix version loads. B2-T12a already asserts that a visit PLAN3 cannot fill stays in `team_open_visits`; B2-T12b asserts the release and the coverage fact, but not that a released visit is in `team_open_visits` and is taken by the team's normal PLAN3 request (`plan3` on-request proposals, AUT-51: a fresh request replaces stale lines). Without that assertion a release could pass its test and still leave the team re-covering by hand from the migration output (b3) | **Test assertion, no new step:** extend B2-T12b by one positive case per release source: the released visit appears in `team_open_visits` with its coverage fact, and a PLAN3 request for that day proposes a member who passes the check (or none, and the visit stays listed, as B2-T12a). The (b3) migration listing stays for `eng` and the PO, not as the team's work list | L | stage 0; `po` (test basis), `eng` | per team and release event on the synthetic seed: released visits; share re-assigned through a PLAN3 line versus by hand; time from release to re-assignment (from coverage facts and assignment events). Team level only | low | report only |

### 2 Briefs, packages and items reviewed (challenge duty)

- **B2-T12a to -T12c (PO 10:39, 12:39, 13:39 after CGR-164, UXR-149/150, `cra` 13:35):** a regression for the IMPLEMENTED refusal plus the post-assignment release. **Supported**: the release moves a refusal at the client's door to the moment the fact is recorded, so the team re-plans before the day, not mid-care (AUT-67's aim). B2-T12c drops both "endet vor" texts because no state reaches them: one fewer line on the team screen, no loss of safety. **Supported.** L1, L2 exist only inside the releasing transaction; their tests show the line does not appear afterwards. No finding.
- **B2-T12c team sentence (`cra` proposed, `lca` open):** "Für <Anzeigename> ist für diesen Einsatz nicht mehr alles erfasst, was die vorläufige Regel verlangt." It names the assigned member on her visit line, which the team already sees, and carries no detail, date or score; after (b2), (b3) it remains only for L3 (an overdue, not started visit). Not a per-person performance view. No challenge; `lca` decides what colleagues may read.
- **B2-T12b (b3) "release, not fail-closed" (PO product decision 13:39):** **supported** from the automation side: a fail-closed migration would make a rule update wait for someone to reassign by hand (an added coordination step with no care benefit, since the start check refuses failing visits anyway). AUT-79 asks that the team's normal list and PLAN3 carry the released visits.
- **B2-T12b (b2) release as the safe default until the Clinical Owner decides "release or flag" (D-43 addendum):** release is the leaner form too: a flag "for the delegating nurse's review" would add a review step per visit and keep the visit at risk until someone acts. If the Clinical Owner chooses the flag, I review that form again. AUT-78 addresses only how the release is triggered.
- **B7 AUT-76 with CGR-165 (1), (3) and B7-T6 (PO 10:39, 13:39):** (1) a reassessment folded into an existing visit passes the same needs-assessment qualification check: a safety control, not administration; it keeps my "no extra trip" aim. (3) `reassessment_due` ends only with a new review date: the date is the record that the plan was reviewed, so no extra act is added. B7-T6 closes a direct-write path: safety control, no workflow step. **All supported.** The lead value stays UNKNOWN (Clinical Owner, D-43); build blocked until then, as the PO set.
- **B0-2 counting rule, ADR-174 (runner ports), B0-3 parts 3 to 5:** test infrastructure; the rule that an aborted-before-tests attempt is "not run" avoids re-runs being argued case by case. No workflow step. No finding.
- **UXR-148 (save-button state on contract end):** UI state, no act added. No finding.

### 3 AI readiness of delivered items (§8)

Nothing merged since review 40 proposes, drafts or ranks (B0-3 parts are tests; ADR-174 is CI). No §8 check due.

### 4 Stage tracking

Unchanged from review 40: stage 0 met on the main line ("gemergt", no block "abgenommen"); pattern 4 preparation OPEN (AIO1 frozen, no model server, D-2 hosting not chosen, synthetic marker missing, Clinical Owner's evaluation bar UNKNOWN); stage 1 not decided (FE-051: legal opinion and DPIA first). B2 not acceptable (B2-T12a to -T12c not written), so the PLAN3 rule agent's qualification input is not yet block-accepted.

### 5 Findings closed and state changes

- **AUT-77 closed** on evidence: `PRODUCT_BLOCKS.md` B2 row (PO 10:39, 13:39): B2-T12a (regression of the IMPLEMENTED refusal, both boundaries) and B2-T12b (post-assignment release, extended by (b2), (b3)) are in the test basis, and "B2 ist ohne B2-T12a bis -T12c nicht abnahmebereit". Premise corrected above.
- **AUT-76:** adopted by the PO 08:39 (B7, GEPLANT), conditions CGR-165 (1), (3) added 10:39; build blocked on the lead value (Clinical Owner). Open until built and tested.
- **AUT-67 (QUAL1-22):** part (1) IMPLEMENTED as refusal (CGR-164 (i)); part (2) PLANNED as B2-T12b. Open until B2-T12b is green.
- **AUT-54 (#912), AUT-61 (#940), AUT-49, AUT-69 to AUT-71, AUT-74, AUT-75:** open, unchanged.

---

## 2026-11-10 08:30 CET · aia review 40: PO runs 04:39, 05:39, 06:39 read; AUT-72 and AUT-73 closed on the PO's amended texts, AUT-74 and AUT-75 adopted (PLANNED, open until built); Phase A stop cases (a) to (g) reviewed; stop case (g) "no care stop for a late reassessment" supported; new AUT-76 (medium: a care-plan review date is shown only after it has passed, while an order end is shown seven days ahead), AUT-77 (medium: the B2 test basis tests the start backstop but not the planning-time prevention QUAL1-22)

**Read:** `recovery/main` at `169dde2` (since review 39, merge `a151d5a`): PO merges #996, #1000, #1001 (PO runs 04:39, 05:39, 06:39; Blueprint v2.31 to v2.33), #971 (owner answers on production readiness; FE-045 to FE-051 already carry them), #993 (`uxa` 03:50), #995 (`csa` 04:40: STR-27 to STR-34), #997 (`lca` 04:46: D-18, D-22, D-43 legal parts), #999 (`cra` 05:35: CGR-163), #991 (B0-3 parts 1+2). Files: `PRODUCT_BLOCKS.md` (§2 term and product invariant, §5 stop cases (a) to (g), ward step 4, B11 protocol, §7 E-3), `decisions/D-41.md` (addendum 04:39), D-18, D-22, D-43, `briefs/NH-A1.md` (gate (c) given 05:39). Open PRs read on their heads: `eng` #1002 (B0-3 part 3, tests only), `uxa` #1003 (no screen change), `lca` #998. Code read for AUT-76: migrations 0019 (`operations_exceptions`), 0024 (`visit_flags`). Open `automation` issues: #912 (AUT-54), #940 (AUT-61).

**Nothing below is a measurement.** I ran no tests and read no database; CI states are as the PO and `eng` record them. **Contradiction check (README rule 10):** none between my prompt and `FOUNDER_DECISIONS.md`. The two contradictions reported in review 39 (E-3 option B, D-41 default point 2) are resolved by the PO in its own files (below). **Task adjustment (README rule 11):** the bottleneck map was refreshed in review 39 (next refresh 2026-11-17); FE-052 §8 (5) still sets `aia` to concept work beside B0. This run reviews the new Phase A stop cases for administration and care time, and checks the code behind stop case (g).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-76 | Care-plan review and reassessment (primary nurse, team); home-care rank 5, ward W1 | **IMPLEMENTED asymmetry:** an expiring medical order appears as `order_expiring` **7 days before** its end (rule row in 0019:45, query 0019:181); a care-plan review date appears only **after** it has passed, as `care_plan_review_overdue` (`having min(i.review_date) < current_date`, 0019:190-197) and as the visit flag `reassessment_due` (`p_date > min(review_date)`, 0024:428). PO 05:39 (stop case (g), CGR-163) keeps it pull-only P3. So the team learns of a due reassessment only once it is late, and then arranges the reassessment visit as an extra, unplanned step; on the ward the same pattern would repeat for every observation period (W1, `NURSING_HOME_TRANSFORMATION.md` §2) | **Rule, no new tap:** show the review date ahead, as the order end already is: a `care_plan_review_due` item from the record with a lead window, so the reassessment is planned inside the normal planning (ideally on an existing visit of the primary nurse, no extra trip) and the overdue state becomes the exception. The lead window value is **UNKNOWN** and is the Clinical Owner's (`cra`, D-43); it must not be copied from the order rule's 7 days. Stop case (g) stays unchanged (no care stop); the overdue item stays as the backstop | L (display of a recorded date); the lead value is a clinical rule (`cra`) | stage 0; `po` (brief line, e.g. with ASM1 or NH-A2), `cra` (lead value, wording), `uxa` (where the due item shows) | per team and month on the synthetic seed: share of active cases whose review date passed without a planned reassessment visit (from `care_plan_review_overdue`); count of reassessment visits planned before the review date. Team level only | medium | report only |
| AUT-77 | B2 block acceptance (`PRODUCT_BLOCKS.md` B2; `cra` B2-T1 to -T11, taken by the PO 04:39): the nurse at visit start or resume | **PLANNED:** B2-T7 and B2-T8 test what happens when a start or a resume is refused for a lapsed evidence or delegation (stop cases (a), (b): "Lücke, kein Alarm", expected behaviour UNKNOWN until the Clinical Owner's rule). The prevention adopted on 2026-11-07 (QUAL1-22, from AUT-67: a lapse foreseeable from a recorded end date is shown at planning and limits the proposal) is in neither the B2 test basis nor the B2 list of PLANNED parts that keep B2 "nicht abnahmebereit". B2 could therefore be accepted with only the backstop, so a foreseeable lapse would keep surfacing in the client's home, mid-care | **Name QUAL1-22 in B2:** either as a test case (for example: a visit planned past an evidence end date shows "Nachweis endet vor Einsatzende" on the planning line, and PLAN3 does not propose that member for it; the start check stays the backstop) or scoped out of B2 by name, as the block section already requires for other PLANNED parts. No new act for the team: the fact is shown, not confirmed | L | stage 0; `po` (B2 test basis), `cra` (the test wording), `eng` (pgTAP after B0) | per team and month on the synthetic seed: refused starts and resumes caused by a lapse that was recorded before the visit was planned (target: none); QUAL1-15 refusal records (AUT-68) | medium | report only |

### 2 Briefs, packages and items reviewed (challenge duty)

- **Phase A stop case "keine geeignete Vertretung" rewritten to the built behaviour (CGR-160 (1)):** the uncovered visit stays visible to the team (`/team`, OPS1, P2), no delivery to a person except a hospital discharge. **Supported** from the automation side: the team acts from its own list, no dispatcher is re-created. Whether a plain uncovered visit must reach a person is the Clinical Owner's rule (UNKNOWN); if one is set, my review-39 note stands (a notice to the members on duty of that team, closed by the team's own act).
- **Stop cases (a) to (e) (CGR-161):** safety controls, not challenged. (a) and (b): AUT-77 (prevention first, backstop second). (c), (d): IMPLEMENTED controls, no act added. (e): NH-A1 uncovered list, as AUT-69.
- **Stop case (f), (g) (PO 05:39 after CGR-163):** (f) only the assessment visit is plannable before a completed assessment: an existing rule, no act added. (g) a passed review date flags the visit but **does not stop care**: **supported**; a care stop would turn a late document into a missed visit (H-01). AUT-76 asks for the date to be seen before it passes.
- **Term "Clinical Owner" = approval function per D-43 (STR-33) and product invariant "the planned team always confirms" (STR-27):** both strengthen team autonomy and add no act. Supported.
- **D-43 (escalated 05:39, B + D):** approves product rules, never plans; the per-organisation adoption record (option D) is a Phase B act of the partner's responsible function, not of the care team. `csa` STR-29 on its scale (115 cells per provider) is noted; the leaner form, if the owner wants one, is adoption **per matrix version** rather than per cell, which is already how the `eng` impact text models it (one record per version). No AUT.
- **D-18, D-22 (`lca` 04:46):** legal readings; "no billing from planned minutes" now has a 2025 contract source. No care-team act added. No finding.
- **NH-A1 gate (c) (05:39):** conditions (1) to (3) are help texts and a Phase A device rule (personal sign-in, attribution per person); no confirm act per shift added. Supported. The sign-out timeout value (`eng`) should be chosen so that a ward member is not signed out between two residents of one round; that is a UX and `lca` balance, not mine to set.
- **B0-3 (#991 merged, #1002 open):** test infrastructure; no workflow step. No finding.

### 3 AI readiness of delivered items (§8)

Nothing merged since review 39 proposes, drafts or ranks. No §8 check due.

### 4 Stage tracking

Unchanged from review 39: stage 0 met on the main line ("gemergt", no block "abgenommen", FE-052); pattern 4 preparation OPEN (AIO1 frozen, no model server, host not chosen, synthetic marker missing, Clinical Owner's evaluation bar UNKNOWN); stage 1 not decided (FE-051: legal opinion and DPIA first). New since review 39: the D-41 default now names NAVORA's own Swiss hosting for real data (PO 04:39), so the next-stage entry condition reads "model server inside the D-2 hosting", not "provider contract".

### 5 Findings closed and state changes

- **AUT-72 closed** on evidence: `PRODUCT_BLOCKS.md` §7 E-3, PO recommendation 04:39 (in `169dde2`): "A als Kern plus ein Agent am Rand … hinter der Schnittstelle von Muster 4"; the old recommendation B is struck. The founder still decides E-3; if B is chosen, I review it again. The measure part is carried by AUT-74.
- **AUT-73 closed** on evidence: `decisions/D-41.md` default points 2 and 5 amended in place (04:39): "C's hosting with B's governance for real data; an external provider only as a synthetic-only stand-in".
- **AUT-74, AUT-75:** adopted by the PO 04:39 into `PRODUCT_BLOCKS.md` (B11 "Protokoll der Administration", GEPLANT; ward step 4 reworded, test "keine Handlung für eine Bewohnerin, deren bisherige Zuständige in der Schicht ist"). Open until built and tested.
- **AUT-54 (#912), AUT-61 (#940), AUT-49, AUT-67 (QUAL1-22), AUT-69 to AUT-71:** open, unchanged.

---

## 2026-11-10 02:20 CET · aia review 39: bottleneck map v3 (weekly refresh, first nursing-home ward column, mapped to the FE-052 blocks); D-41 mapping of option B onto FE-051 patterns 1-4 (the `aia` input asked on 2026-11-07); FE-045 to FE-052, `PRODUCT_BLOCKS.md`, B0 brief and E-1 to E-4 read; AUT-69 to AUT-71 adopted into NH-A1 (#969 closed by the PO; findings stay open until built); new AUT-72 (high, #912: E-3 re-opens the AUT-54 re-draft), AUT-73 (medium: the D-41 default still names an external provider), AUT-74 (medium: Phase A tests stops, not administration), AUT-75 (low: ward step 4 of the Phase A flow names an act NH-A1 removed)

**Read:** `recovery/main` at `1795728` (since review 38, `be2af00`): PO merges #970 (aia review 38), #965, #837 (M1.4), #972 to #975, **#815 (ASM1-C6, `5d15391`)**, **#978 (FE-052, `PRODUCT_BLOCKS.md`, inventory)**, **#980 (CI2 with B0-1)**, #983 (`uxa` 19:55), #984, **#985 (B0-2 repeat mechanism)**, #986 (PO 00:39: B0 brief approved, B1 "Rückfrage" PLANNED as a direct team-to-referrer question). `FOUNDER_DECISIONS.md` v12 (FE-045 to FE-052). Packages: `decisions/D-41.md` (addenda 15:39 and 17:39), D-2, D-22, D-43. Open PRs read on their branches: `cra` #988 (01:35: B5/B2 block test cases, CGR-160 to CGR-162, D-41 patterns 2-4), PO #989, `eng` #990/#991 (B0-3), #971, #907. Open `automation` issues: #940 (AUT-61), #912 (AUT-54). #969 (AUT-69) closed by the PO after adopting it.

**Nothing below is a measurement.** I ran no tests and read no database. CI states are as the PO records them. **Contradiction check (README rule 10):** none between my prompt and `FOUNDER_DECISIONS.md` v12. One between a PO recommendation and FE-051 is reported as AUT-72 (E-3 option B) and AUT-73 (D-41 recommended default point 2); neither founder decision is changed.

**Task adjustment (README rule 11):** FE-052 §8 (5) sets `aia` to concept work in parallel with B0, no code merge. This run therefore does the due weekly map refresh, the D-41 mapping asked of `aia` on 2026-11-07 15:39, and reviews the block definitions for administration. No AUT for B0 itself: B0 is test infrastructure and adds no step for a care team. The MERGE1 build is frozen with all features; AUT-49 stays open.

### 1 Bottleneck map v3 (weekly refresh; v2 review 18, 2026-11-03)

**Evidence used:** home care as in v2 ([E1], [E2] review 1, [E3] review 18, not re-read; a Swiss home-care direct-care share stays UNKNOWN). Ward: `NURSING_HOME_TRANSFORMATION.md` §2 (volumes derived from the source's ratios, minutes UNKNOWN by its own statement), NH-A1 brief, the PO's Phase A flow (`PRODUCT_BLOCKS.md` §5). **No new published study was read this week**, so no new figure is used. **Rank** = estimated direct-care time recoverable at team level, ordinal, 1 = largest. **Block** = FE-052 leading block.

**Home care (Spitex team)**

| Rank | Step (role) | Block | Moved since 2026-11-03 (status) | What still costs a person time | Verdict | What unblocks it | Finding |
|---|---|---|---|---|---|---|---|
| 1 | Travel and day order (nurse) | B3 | nothing (OPEN); PLAN3 still excludes order and route | she orders her own day and route | replace (team geography), then a day-order rule (AUT-5) | Q7 (`lca`), D-11 answered for BS/BL (FE), geography design not briefed | AUT-5, AUT-32, AUT-36 |
| 2 | Documentation per visit (nurse; RN countersign) | B6 | DOC-AI narrowed to the nurse's own note (AUT-54 adopted, PLANNED, not built); FE-051 pattern 3 makes the rule report the core; E-3 open | one report per visit; countersign of every assistant report (0016) | replace by documentation by exception and risk-based review (D-10); A7 at the edge | D-10 and G-1 (Clinical Owner not named); E-3 (owner) | AUT-4, AUT-54, **AUT-72** |
| 3 | GP orders, hospital referrals, relatives (primary nurse) | B1, B7 | B1 "Rückfrage" PLANNED as a direct question to the referrer, no Operations relay (PO 00:39): **supported**, it is the eliminate step; D-22 template written (FE-042), still open | phone and fax for orders; referral re-typed at intake | eliminate (structured order and referral, external actors as record nodes) | D-22, D-9 (owner, legal); REF2 draft | AUT-6 |
| 4 | Who takes which visit (team) | B3 | PLAN3 merged (FE-041) with QUAL1 rule-before-agent; **not block-accepted** (B3 "implementiert, nicht ausreichend getestet") | a confirmed list per day; manual moves for early visits | eliminated by rule (PLAN3); P-28 window would remove early moves | B3 block test (FE-052 step 3) | AUT-1, AUT-19 |
| 5 | Assessment → care plan (RN) | B7 | ASM1-C6 void act merged (`5d15391`, one tap with a preset); ASM1-C7 open | minutes per category typed from the provider's tool | one clinical language; import later | D-37, D-36 | AUT-2, AUT-13 |
| 6 | Absence and short-notice cover (team) | B3 | nothing; PLAN4 (mandated rule lines) has no brief (draft due 2026-12-04); CGR-160: a plain uncovered visit notifies nobody | calls to find cover | rule under a team mandate (PLAN4); see §3 on CGR-160 | PLAN4 brief; Clinical Owner for the priority | AUT-51 (closed), – |
| 7 | Working time (nurse) | B4 | nothing | one confirmation per day | simplify the form; the duty stays | `lca` (D-23) | AUT-8 |
| 8 | Billing preparation | B8 | nothing; BILL1 not built (frozen) | none before the invoice (J5 derives facts) | eliminated; pre-send checks as QG1 holds | D-18, D-22 | AUT-59 |
| 9 | Visit status taps, referral → team decision, quality, analytics | B4, B1, B10 | AN3 merged (#841) but not block-accepted (B10) | as v2 | as v2 | – | – |
| 10 | Team self-organisation (onboarding, offboarding, team split, cross-team cover) | B2, B3 | QUAL1 self-confirmed profiles (FE-028) in part; P-32 and COVER1 unchanged | as v2 | as v2 | as v2 | AUT-21 |

**Nursing-home ward (simulated, FE-031; first sketch)**

| Rank (ward) | Step (role) | Block | Status | What costs time today (source) | Verdict | What unblocks it | Finding |
|---|---|---|---|---|---|---|---|
| W1 | Reassessment periods and their coordination (coordinator, supervisor, ward team) | B7, B9 | OPEN (NH-A2 no brief; interRAI by name only, D-36 A) | for 96 residents about 130-195 observation periods a year, three meetings each, item-by-item documentation of stable items, coding and checking (`NURSING_HOME_TRANSFORMATION.md` §2, derived from source ratios; minutes UNKNOWN) | **eliminate** the coordination (due dates from the record, item gaps shown, completeness check before signature); the classification rules come only from the licensed specification | D-36, D-37 (owner), NH-A2 brief (PO), Clinical Owner | – (next review, once NH-A2 is drafted) |
| W2 | Shift handover (*Rapport*), every shift, the whole shift team | B9 | OPEN (NH-A3 no brief); HAND1 exists for home care | a meeting per shift change; what changed is told, not read (same report §4) | **eliminate the meeting as the carrier**: "since your last shift" per resident (HAND1 reuse); a short team talk stays for judgement | NH-A3 brief (PO), `cra` (what must be told in person) | – |
| W3 | Documentation per shift (FaGe, RN) | B6, B9 | as home-care rank 2 | per resident per shift | as rank 2: structured entry at the moment of care, report by rule (pattern 3) | as rank 2 | AUT-72 |
| W4 | Shift allocation and roster upkeep (ward leader today) | B9 | PLANNED (NH-A1 approved, AUT-69 and AUT-70 taken in; no build, FE-052 freeze) | a planner's roster and allocation round per shift | **eliminated by rule** (own shifts, own pattern, continuity default, uncovered list) | B0 accepted, NH-A1 gate (c) `lca` | AUT-69, AUT-70, AUT-71 |
| W5 | Absence on the ward (team) | B9 | OPEN (NH-A4 no brief) | calls for cover per shift | the NH-A1 uncovered list plus a cover rule like PLAN4; priority of an uncovered resident is the Clinical Owner's (CGR-159) | NH-A4 brief; Clinical Owner | – |
| W6 | Billing per resident day | B8, B9 | OPEN (NH-A5 no brief) | UNKNOWN | rule from recorded days; no AI target (AIR1) | D-18, NH-A5 | – |

**What the refresh shows (estimate, not a measurement):**
- The three largest home-care bottlenecks (ranks 1-3) still have no built change; only rank 3 moved on paper (direct question to the referrer). Every built item since 2026-10-27 sits at ranks 4, 5 and the governance layer.
- On the ward, the largest administrative driver the source shows is the reassessment cycle (W1), not the roster (W4). The only ward brief so far (NH-A1) addresses W4. **For the PO:** when the NH-A2 brief is drafted, its scope decides most of the ward gain; I review it then.
- FE-052 changes how a gain will be shown: no block is accepted, so no gain is "delivered" yet in the founder's sense. The first value-1 evidence can only come from the two Phase A flows (AUT-74).
- Minutes per step on the ward and the share of a shift in handover and documentation stay **UNKNOWN**; the synthetic seed cannot answer them. Next refresh 2026-11-17.

### 2 D-41: option B mapped onto FE-051 patterns 1-4 (`aia` input; advisory; the package is the PO's)

FE-051 asks `cra`, `eng` and `aia` to map option B (orchestrator only, conditions 1-10, entry gate per agent, L before G) onto patterns 1-4 and to name what changes in the recommended default. `cra` answered pattern 1 (17:29, allow-list) and patterns 2-4 (01:35, #988). This is the automation side. **None of it is decided; rule A stays (FE-024).**

| Pattern (FE-051) | Agents and work flows it carries | Does it need option B? | Conditions of option B that apply | What is IMPLEMENTED today |
|---|---|---|---|---|
| **1** planning with identifiers and planning facts | PLAN3 day plan; PLAN4 mandated rule lines; NH-A1 continuity default; ABS1/COVER1 cover; a later day-order or route solver (AUT-5) | **No, while the work runs as a rule or solver inside NAVORA's own database** (`lca` 16:10: level L without an AI service has "no AI question at all"). Yes only if a language model is attached (then it is pattern 4) | Even as rules: the AIG1 ledger, a named confirmer, stop rule, kill switch (already IMPLEMENTED); and the `cra` allow-list of admitted fields (17:29) as a register field per agent with a test that refuses any other field (it is AIR1-C1's allow-list, CGR-115). On the ward, *zuständig* plus ward is health data (`cra`): it may be used inside the database, never passed to a model | PLAN3 (rule, kind `rule`), AIG1, AIR1 (synthetic) |
| **2** team measures only | AN1 to AN3, WORK1-6, M-11, M-12, M-15 to M-17 | **No** for computing them (SQL aggregates). Yes only for a model that writes a narrative over the measures (pattern 4) | small-count suppression and never per person (D-23, AN1); a `cra` line per measure name (01:35) | AN1, AN2, AN3 (synthetic; B10 not accepted) |
| **3** structured entry, report by rule | F6/F7 report snapshot, OBS1, HAND1 | **No.** It is the AUT-54 scope: the structured report is a rule and needs no review step beyond the existing signature | H-14 completeness test (`cra` 01:35: every entered fact once, nothing else) | F6, F7, F6R, OBS1 (synthetic) |
| **4** own language model in a Swiss NAVORA data centre, synthetic first | A7 (the nurse's own unstructured note → proposed observations, level G); unstructured referral intake (a free-text or PDF referral → proposed fields, level L for administrative fields); later dictation with consent of everyone present (AUT-65) | **Yes, in full.** It is the only pattern in which a model processes content | Orchestrator only route (B 2 (a)); minimisation per agent (B 2 (c)); model version pinned and written to the ledger (B 2 (b)); evaluation harness on synthetic cases with the Clinical Owner's bar (B 2 (d); bar UNKNOWN); stop rule and kill switch reach the model server (B 2 (e)); the kind-`ai` refusal lifted only per approved agent (B 2 (f)); the synthetic marker of Engineering point 4 (iv) before any call; condition (9) applies to the **hosting** processor and to NAVORA's own staff instead of an AI provider | nothing (AIO1 PLANNED, M8; no model server; host not chosen, D-2) |

**What changes in the recommended default (proposal, `aia`):**
1. **Point 2 of the default ("one contracted CH/EU provider per agent") no longer matches FE-051.** Pattern 5 is not chosen and pattern 4 is the only model path the direction prepares, so for real data the model runs in NAVORA's own Swiss hosting: option C's hosting with option B's governance. Option C moves from "fallback" to the target hosting; an external model provider stays at most a synthetic-only stand-in (O-4, `lca` (i)-(iv)). This needs no new owner choice if the PO reads FE-051 that way; whether it does is the PO's call (AUT-73).
2. **Patterns 1 to 3 need no AI service at all** and therefore no stage beyond 0; the `lca` question "is pattern 1 inside rule A" arises only if pattern 1 facts go to a model. Recommended wording: "pattern 1 runs as rules or solvers in NAVORA's database; a model receives pattern 1 facts only under pattern 4 and the allow-list."
3. **Order of entry stays L before G**, now inside pattern 4: unstructured referral intake (administrative fields, L) before A7 (G).
4. **Unchanged:** prohibition D in every option; rule A until the owner decides a pattern 4 switch-on with a legal opinion and a DPIA (FE-051).

### 3 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-72 | Phase A step 7 "KI-Dokumentationsentwurf" and E-3 (`PRODUCT_BLOCKS.md` §5, §7): the nurse per visit, the ward per shift | **OPEN (founder question E-3):** option A (report by rule from structured entry) "beweist aber keinen KI-Mehrwert"; the PO recommends **B**, a language model on synthetic data with a CH/EU provider. If B drafts the visit report, it re-opens what the PO adopted on 2026-11-06 (AUT-54, #912; D-41 PO note): a second text of facts NAVORA already holds, and a review of that text on every visit, with no patient-care benefit named. It also tests a model path FE-051 does not foresee for real data (pattern 5 not chosen; pattern 4 is the model path), so the Phase A evidence would not carry over to Phase B | **Rule plus an agent at the edge:** step 7 = the report by rule (pattern 3, E-3 A) **plus** one agent that turns the nurse's own unstructured note (typed or, with consent, dictated) into proposed observations with their source span (A7, level G), confirmed value by value. Run it behind the pattern 4 interface (AIO1 adapter, model version in the ledger); whether a hosted stand-in model may serve on synthetic data is `lca`'s (i)-(iv) and the owner's. The AI gain is shown where it exists: free text that would otherwise be re-typed into fields | G (A7); L for the report | stage 0 (synthetic); owner (E-3), `cra` (A7 controls, CGR-119), `lca` (stand-in model) | per team and month on the synthetic seed: confirm acts per visit vs the pattern-3-only flow; correction rate per field (AIG1); share of notes with a proposed observation the nurse rejects; never per person | **high** | #912 (existing; comment) |
| AUT-73 | D-41 recommended default point 2 (`po`; owner later) | **OPEN:** the default still reads "one contracted CH/EU provider per agent" (00:39 on 2026-11-07), written before FE-051 | adjust the default as in §2 points 1-2 (C hosting with B governance; patterns 1-3 without an AI service); ask the owner only if the PO does not read FE-051 as already excluding an external provider for real data | – | stage 0; `po` (package), `lca` (pattern 1 question narrowed), `eng` (B 2 (b) becomes a model server in the D-2 hosting) | – | medium | report only (comment on #905) |
| AUT-74 | Phase A pass (`PRODUCT_BLOCKS.md` §5, FE-052 (6)): the founder judging Phase A | **PLANNED:** both flows prove that NAVORA **stops** in the listed cases. Nothing in the pass criteria shows whether administration fell, which is the first and second success measure (owner 2026-10-27) and the point of the AI work flows | **monitor, no new tap:** the Phase A protocol records, per flow and step, the human acts the events already show (taps, confirms, typed fields, hand-offs) and the AN3 spans, from the same run. Not a pass threshold: a number beside each step so the founder sees where administration remains. Team level only | L | stage 0; `po` (B11 protocol), AN3 | acts per flow step, per flow; AN3 spans; compared between the pattern-3 and the agent path of step 7 (AUT-72) | medium | report only |
| AUT-75 | Phase A ward step 4 "Mitglied setzt *zuständig*" (`PRODUCT_BLOCKS.md` §5) | **PLANNED:** after AUT-69 (NH-A1 14:39) the continuity default takes effect without an act; a member acts only to change it. A Phase A test written to the step as worded would test an act per resident that NH-A1 removed | reword step 4 for the ward: "Default wirkt (Quelle Kontinuität); ein Mitglied ändert, wo nötig; Lücken erscheinen in der Liste". Test: no act needed for a resident whose previous member is on shift; an act for a change; the uncovered list counts what stays empty (NH-A1-5, CGR-159) | L | stage 0; `po` | changes from the default per ward and month (NH-A1 measures) | low | report only |

### 4 Briefs, packages and items reviewed (challenge duty)

- **FE-052 and `PRODUCT_BLOCKS.md`:** evidence over merge count, block states, gates on the merged commit. **Supported.** It adds no step for a care team; it is test and acceptance discipline. One form point: the block acceptance protocol (§3, eight parts) is per block, not per PR, which keeps the review load proportional. AUT-74 and AUT-75 are about what Phase A measures.
- **B0 brief (approved 00:39):** infrastructure; no workflow step for a team. No finding.
- **B1 "Rückfrage" as a direct question to the referrer (PO 00:39):** **supported**; it removes a hand-off and a waiting step (eliminate).
- **E-1, E-2, E-4:** engineering and schedule questions; no `aia` position. **E-3:** AUT-72.
- **FE-045 to FE-050:** hosting, repository protection, red-team testing, legal timeline; no team workflow added. FE-048's hosting is where pattern 4 would run (AUT-73).
- **`cra` #988 (open): CGR-160** (a plain uncovered visit is P2 and pull-only, nobody notified): from the automation side, a notification to a single "Disponent" would re-create a coordinator; if the Clinical Owner sets one, the leaner form is a delivered notice to the members on duty of that team, closed by the team's own act. The priority itself is the Clinical Owner's (not mine). **CGR-161** (five missing stop cases) and **CGR-162** (keep "nicht erfasst"): safety controls, not challenged.
- **ASM1-C6 (merged):** the void act is one tap with a preset reason (P-37). Supported; no step added.

### 5 AI readiness of delivered items (§8)

Nothing merged since review 38 proposes, drafts or ranks. ASM1-C6 and the CI changes are not agents. No §8 check due.

### 6 Stage tracking

| Stage | Entry condition | State |
|---|---|---|
| 0 | Governance layer and first rule agent on the main line | met (unchanged); **no block accepted** (FE-052), so both are "gemergt", not "abgenommen" |
| 0 | Pattern 4 prepared on synthetic data (FE-051) | **new, OPEN:** needs AIO1 (PLANNED, M8; frozen with all features), a model server in the D-2 hosting (host not chosen), the synthetic marker (Engineering D-41 point 4 (iv), missing), an evaluation harness and the Clinical Owner's bar (UNKNOWN) |
| 1 | Owner switches on a pattern-4 agent for real data | not decided; needs a legal opinion and a DPIA (FE-051), rule A in force |

### 7 Findings closed and state changes

- **AUT-69, AUT-70, AUT-71:** adopted into NH-A1 by the PO (14:39); #969 closed by the PO. Each stays open in this report until NH-A1 is built (frozen until B0).
- **AUT-49:** MERGE1 approved, not built (FE-052 freeze); stays open.
- **AUT-54 (#912), AUT-61 (#940):** open; #912 receives the AUT-72 comment.
- Closed with evidence: none.

## 2026-11-07 14:20 CET · aia review 38: NH-A1 (ward and 24-hour shift model, approved 13:39) and MERGE1 (approved 12:39) reviewed; AUT-67 adopted as QUAL1-22 and AUT-68 adopted as the QUAL1-15 record shape (both PLANNED, open); new AUT-69 (high, #969: a per-shift confirm of the continuity default, and an undefined covered state), AUT-70 (medium: own shifts entered one by one), AUT-71 (low: the ward measure needs its event source)

**Read:** `recovery/main` at `be2af00` (since review 37, `4a3ad57`): PO merges #954 (aia review 37), #951, #937 (`cra`), **#953 (QUAL1 part 2 slice 3, QUAL1-21, `ac6a303`)**, #955 to #958, #835 (M1.3), #959 (`uxa` 11:50 and NH-A proposal), #963, **#961 (MERGE1 proposed, COORD-7)**, #967. New: `briefs/MERGE1.md` (approved 12:39), **`briefs/NH-A1.md` (approved 13:39)**, `decisions/COORD-7.md`, `design/proposals/NH-A_WARD_SHIFT_SCREENS.md`, QUAL1-22 and the PO placements 08:39/09:39 in `briefs/QUAL1.md`. `FOUNDER_DECISIONS.md` v10 (FE-042 structured milestone work, FE-043 `uxa` proposals, FE-044 Engineering test and CI rule): no contradiction with my prompt. Open PRs: #965 (`cra` 13:25, read on its branch), #907, #837, #815. Open issues: #968 (NH-A1 build), #964 (MERGE1 build), #966; `automation`: #940, #912.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 stands; the weekly refresh with the nursing-home ward sketch is due 2026-11-10 (OPEN). NH-A1 now gives the ward column its first PLANNED design: the shift allocation round and roster upkeep (map v2, ward "Planning").

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-69 | Ward planning, shift start (NH-A1-6): the ward team, every shift | **PLANNED (NH-A1-6):** the continuity default is "a proposal only … the team confirms it in one act per shift for all residents". With the seed's three shifts that is about 3 acts a day, about 1 100 a year per ward (arithmetic on the brief, not a measurement), nearly all accept-all. The rule uses schedule facts only, and the proposed member already passed NH-A1-4 (planned in the shift, access valid) and sees the resident on her N-01. **No patient-care benefit is named** for the confirm (brief; `cra` 13:25 requires a named member per resident per shift and an uncovered list that counts residents, both met without it). **Gap:** the brief does not say whether an unconfirmed default counts as *zuständig* for NH-A1-5: if not, every resident is "ohne Zuständige" at each shift start until someone taps (the list stops meaning anything); if yes, the act has no effect | **eliminate the act, keep the rule:** the default takes effect when the shift becomes the next shift (source "Kontinuität", logged, shown "wie letzte …", changeable in one act by any member); NH-A1-5 lists only residents with nobody after the default; no team-wide accept-all. If the Clinical Owner asks for an acknowledgement, it is the named member's own "Gesehen" on her N-01, not a coordinator's tap. Whether an explicit confirmation of shift responsibility has a clinical reason: **UNKNOWN**, `cra` | L | stage 0, no AI; `po` (brief), `cra` (is a confirmation clinically required?), `uxa` (N-01/N-02 text) | changes from the default per ward and month (replaces "confirmed without a change"); residents uncovered at shift start per ward and month; never per person | **high** | #969 |
| AUT-70 | Ward planning, roster (NH-A1-3): every ward member | **PLANNED (NH-A1-3):** each member "enters, changes and withdraws her own planned shifts", one by one. Removing the planner (PO decision 4) is right: **supported.** **Form cost:** most ward staff work a recurring pattern (fixed days, part-time rhythm); entering every single shift for weeks ahead moves the planner's typing to every member rather than removing it. The brief has no repeat entry | **simplify through the care graph:** a member may record her **own** recurring pattern (shift definition, weekdays, from–to) once; the planned shifts are generated from it like a PLAN2 series, each single shift then changeable or withdrawn as an exception; changing the pattern changes only future shifts that have no exception. Still own entries only: no command takes another member's pattern or a roster (NH-A1-3 negative case unchanged). No rest-period or working-time rule added (NH-A1-12 stays `lca`) | L | stage 0; `po` (brief), `eng` (shares the PLAN2 series mechanism?), `lca` (none new: planned time only, NH-A1-12) | entry acts per planned shift per ward and month (target well below 1); share of shifts entered as exceptions | medium | report only |
| AUT-71 | Ward planning, measure (NH-A1 "AI leverage", M9.0): AN3 | **PLANNED:** "Administrative step removed: shift allocation and roster upkeep. The baseline is UNKNOWN for a real home; in Phase A the measures are the AN3 spans per ward and month, plus NH-A1-6's share." No AN3 span is named for a ward, and a ward has no visit start/stop to bound one (PO decision 2, rightly) | **measure from the events NH-A1 already writes**, no new tap (AUT-55 rule): (1) residents covered when the shift begins, per ward and shift definition; (2) minutes from shift begin until every resident has a member; (3) responsibility changes after shift begin; (4) roster entry acts per planned shift (AUT-70). Team level only, never per person | L | stage 0; `po` (brief), AN3 (`aia` with `po`) | the four values above per ward and month on the synthetic seed | low | report only |

### 2 Briefs, plans and packages reviewed (challenge duty)

- **NH-A1 (approved 13:39), PO decisions 1 to 5:**
  - **Planning unit: the resident per shift, no per-episode start and stop (decision 2): strongly supported.** It eliminates a timing act on every care contact in the ward; it is the AUT-55/AUT-56 rule (no time tap per resident for measurement) built into the model.
  - **No planner role, no roster approval (decision 4), team-visible gaps, derived uncovered list (NH-A1-5): supported.** This is the "eliminate through the care graph" step for the ward's allocation round. AUT-70 and AUT-69 are about the form only.
  - **"Zuständig in dieser Schicht" kept apart from authority and formal responsibility (decision 3): supported**; it keeps QUAL1 the only place that decides "who may do this activity".
  - **NH-A1-7 "Nicht überwacht" list, NH-A1-9 counts only (no staffing target), NH-A1-12 no working-time rule until `lca`: safety and honesty controls, not challenged.** Nothing invented.
  - **"AI prepares: none in NH-A1": supported.** Rule before agent; ward data under D-35 rule A.
- **MERGE1 (approved 12:39, from AUT-49 and COORD-7 point 1): supported as written.** It removes whole agent runs spent only on conflicts (the Engineering run of 2026-11-07 11:10). MERGE1-10 measures it (M-04). **AUT-49 stays open until MERGE1 is merged and M-04 is recorded.**
- **COORD-7 point 4 (b) (`uxa`/`aia` daily, owner's choice):** no position on my own cadence; it is the owner's (scheduled tasks). One fact for the package: most of what a 6-hourly `aia` run costs other roles is the `JOURNAL.md` conflict, which MERGE1 removes; after MERGE1 the case for (b) rests on review load only.
- **QUAL1-22 (from AUT-67) and the QUAL1-15 refusal record in the AUT-68 shape:** match the proposals. Both stay open until built.
- **CGR-155 (4) with the PO challenge 09:39 (the "not completed" reason pre-set from the refusal, the nurse confirms instead of typing): supported**; a stop the system caused costs the nurse no free text.
- **FE-042 to FE-044, `cra` 13:25 (#965: D-43 and D-22 templates, CGR-156, CGR-157 as ORD1-C1/-C2):** no care-team act added. No finding.

### 3 AI readiness of delivered items (§8)

- **#953 (QUAL1-21, merged):** label texts only; no agent proposal changed. The AIG1 `not_qualified` verdict on a person is gone from user text. No finding.
- **No new agent delivered or planned.** NH-A1's continuity default is a deterministic rule outside the AIG1 ledger; if it is ever registered as an agent, it needs the full §8 set (ledger, provenance, named confirmer, stop, correction rate). With AUT-69's proposal it stays a rule with a logged source, not an agent.
- Missing for any model-based agent: an evaluation harness on synthetic cases (none needed at stage 0).

### 4 Stage tracking (D-35)

Stage 0 only (FE-024, rule A). Stage-1 entry conditions unchanged since review 36: governance layer merged (met); first rule agent with its controls on the main line (met, PLAN3); provider and contract: D-41 escalated, not decided; three stable pilot months: none (Phase A). No real data to any AI service.

### 5 Findings: state changes and closed

- **AUT-67:** adopted as QUAL1-22 (PLANNED, part 3); open until built.
- **AUT-68:** adopted as the QUAL1-15 record shape (part 2 condition); open until built.
- **AUT-61 (#940), AUT-62 to AUT-66, AUT-54 (#912), AUT-59, AUT-49:** unchanged, open.
- **Closed this review:** none.

---

## 2026-11-07 08:20 CET · aia review 37: QUAL1 part 1 (#939, `4878ace`) and part 2 slices 1+2 (#945 incl. #943, `f1bfe55`) merged and read; AUT-61 taken in as QUAL1-20 (PLANNED, stays open); open PR #953 (QUAL1-21) reviewed; new AUT-67 (medium: a lapse found at depart, start or resume is a mid-care stop; prevent it at planning), AUT-68 (low: QUAL1 refusals leave no record to measure)

**Read:** `recovery/main` at `953dc3c` (since review 36, `f061797`): PO merges #941 (aia review 36), #942, #936 (`uxa`), #946, #947 (`lca`: D-42, D-43, D-44), #948, **#939 (QUAL1 part 1, migration 0120)**, #949, **#945 incl. #943 (QUAL1 part 2 slices 1+2, migrations 0121, 0122, ADR-164, ADR-165)**, #952. `briefs/QUAL1.md`: QUAL1-20 (from AUT-61), QUAL1-21 (UXR-129 to -133), PO reviews of part 1 and slices 1+2 with the deviations decided (ADR-164 (1) to (4), ADR-165 (1) to (4), CGR-153, CGR-154 as part 2 conditions). Open PRs read: **#953** (QUAL1-21, ADR-166, no migration), #951 (`uxa`, UXR-134 #950), #937 (`cra`). Issues: #940 (PO 02:45: taken in as QUAL1-20), #950, #944; open `automation` issues #940, #912. `FOUNDER_DECISIONS.md` unchanged since v8; no contradiction with my prompt.

**Nothing below is a measurement.** I ran no tests and read no database; CI states are the PO's record (merge commits `4878ace`, `f1bfe55` green per the PO, not checked by me). Bottleneck map v2 stands; the weekly refresh with the nursing-home ward sketch is due 2026-11-10 (OPEN).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-67 | Visit start (QUAL1-17): the member at **Losfahren**, **Einsatz starten** and **Fortsetzen**; in a ward the FaGe mid-round | **IMPLEMENTED (0121 `qual_guard_start`, `recovery/main`):** every transition into `on_the_way` or `started` in a simulation organisation re-runs the QUAL1 check, including a resume from `paused`; a lapse refuses with `qualification_lapsed` and the visit stays assigned (ADR-164 (3), release PLANNED with CGR-154). UXR-134 (#950): after a refused resume the visit has begun and the next step is UNKNOWN (CR-194, `cra`). The check itself is a safety control: **not challenged.** **Form cost:** every lapse found here is discovered by the nurse at the door or at the client's side, then a phone round to find a cover (the bottleneck QUAL1 removes), and mid-visit it interrupts care. Nearly every such lapse is foreseeable at planning: an end date of evidence or delegation is recorded data; only a revocation is not | **prevent at planning, keep the start check as backstop:** (1) the AUT-63 forecast, extended: a planned visit whose responsible member's evidence or delegation ends before the visit's planned end is marked from the lead time on and enters the PLAN3 day plan as a limit (no proposal the start check would refuse); (2) a revocation re-runs the check at once for every future planned visit of that delegation and releases them to the team as open (QUAL1-20 (2) pattern), so the start check only meets the residual case; (3) whether a visit begun under valid cover may be completed after a lapse, and what the nurse does then, is `cra`'s (CR-194): **UNKNOWN**, nothing invented here; no agent decides it | L (forecast and release); the continue-or-stop rule is G (`cra`) | stage 0, no AI; `po` (part 2 criterion with CGR-154), `cra` (CR-194), `uxa` (UXR-134 text) | refusals at depart, start and resume per 100 visits per team and month (target near 0; needs AUT-68); share of those caused by an end date known at planning (target 0) | medium | report only; comment on #953 |
| AUT-68 | QUAL1 refusals on every path (QUAL1-15): the team and AN3 | **IMPLEMENTED with a deviation (ADR-164 (1), ADR-165 (4), accepted for the simulation):** a backstop refusal is a database error without its own audit row; the PO made a refusal record a QUAL1-15 acceptance condition. Without it no measure in QUAL1's own baseline (QUAL1 "Removed step and baseline", AUT-63, AUT-66, AUT-67) has an event source, and a refusal at an AIG1 confirm cannot be told apart from a wrong proposal in the correction rate (§8) | **supported; record shape for the measures:** (1) one event per refusal with path (assignment, take, swap, cover, PLAN2, PLAN3 confirm, start, resume), reason code, team, visit and time; (2) a refusal at an AIG1 confirm because evidence lapsed between proposal and confirm is counted apart from the agent's correction rate (cause: time, not the proposal); (3) shown and counted per team only, never per person (no per-person view) | L | stage 0; `po` (QUAL1-15 condition), `eng` (where) | refusals per path and reason per 100 visits per team and month | low | report only |

### 2 Briefs, plans and packages reviewed (challenge duty)

- **QUAL1-20 (PO 02:45, from AUT-61):** matches the proposal: list kept once on order line or series, per-visit change as the recorded exception, re-check of future planned visits with release, started visits keep their checked list, empty list strict (CGR-149). Removing an inherited activity for one visit waits for `cra`. **AUT-61 stays open until QUAL1-20 is built and tested** (pgTAP named in the criterion); #940 stays open.
- **QUAL1 slices 1+2 (`f1bfe55`):** one decision function on every patched path, a trigger backstop below every command, no override: **safety controls, supported, not challenged.** This is the "eliminate through the care graph and rule" step for "who may do this visit": no person checks it by memory. ADR-165 (1) (deputy tried only after the primary) is stricter: no objection. ADR-165 (3) (the PLAN2 summary names the number of visits left open by QUAL1, without names, as a part 2 condition): supported; it is the team-level fact a team needs to re-plan, with no per-person view.
- **ADR-164 (3) / PO challenge 07:45 (a refused visit stays with the person who may not do it):** supported; AUT-67 adds that most of these refusals should not reach the start at all.
- **CGR-153 (per-case isolation in `generate_all_plans`):** supported; one refused visit must not stop the daily plan for every team. No finding.
- **PR #953 (QUAL1-21, one text per reason):** no added act; the AIG1 `not_qualified` verdict on a person is gone. No objection. AUT-67 comment left (the resume text depends on CR-194).
- **D-42, D-43, D-44 (`lca` sections 04:56, escalated):** no care-team act added. No finding.

### 3 AI readiness of delivered items (§8)

- **PLAN3 with QUAL1 (`f1bfe55`):** `private.plan3_lines` no longer proposes a member who fails the check, and `aig1_apply_visit_responsible` re-checks at confirm. That is the right order (rule before agent): the confirmer never has to reject an ineligible proposal, so the correction rate measures the proposal's quality, not the matrix. Open: AUT-68 (2), counting a confirm-time lapse apart.
- **No new agent.** The prohibited class `qualification` is on `recovery/main` (0120). The profile draft (AUT-64) has no landing yet: unchanged, noted by the PO for the part 2 plan review.
- Missing for any model-based agent: an evaluation harness on synthetic cases (none needed at stage 0).

### 4 Stage tracking (D-35)

Stage 0 only (FE-024, rule A). Stage-1 entry conditions unchanged since review 36: governance layer merged (met); first rule agent with its controls on the main line (met, PLAN3); provider and contract: D-41 escalated, not decided; three stable pilot months: none (Phase A). No real data to any AI service.

### 5 Findings: state changes and closed

- **AUT-61 (high, #940):** answered by the PO and taken in as QUAL1-20 (PLANNED); open until built.
- **AUT-62, AUT-63, AUT-64, AUT-65, AUT-66:** noted by the PO for the QUAL1 part 2 plan review; open. AUT-63 gains AUT-67 as its strongest reason.
- **AUT-54 (#912), AUT-59:** unchanged, open.
- **Closed this review:** none.

---

## 2026-11-07 02:20 CET · aia review 36: PLAN3 merged and accepted (#934, FE-041), FE-038 to FE-041, QUAL1 brief and QUAL1 part 1 (#939) read; AUT-25, AUT-30, AUT-31, AUT-51, AUT-52 closed on `48cdb0c`; new AUT-61 (high: QUAL1 activities are stored per visit, so a team would tag every visit of a series by hand), AUT-62, AUT-63, AUT-64, AUT-65 (medium), AUT-66 (low)

**Read:** `recovery/main` at `f061797` (since review 35, `2997556`): PO merges #841 (AN3), #860 (`lca`), #899 (`csa`), #917, #850 (`uxa`), #872 and #876 (PLAN3 part (a), PLAN3-14), #921, #923, #922 (CGR-110), #920 (FE-038, FE-039), #929 (`cra` QAM v0.2), #930 (FE-040, QUAL1 approved, D-44), #933 (FE-041), **#934 (PLAN3 consolidation, `48cdb0c`)**, #938 (PLAN3 accepted, Blueprint v2.14). New or changed: `FOUNDER_DECISIONS.md` v8 (FE-038 to FE-041), `briefs/QUAL1.md`, `clinical/QUALIFICATION_MATRIX.md` v0.2, `BUSINESS_MODELS_AND_CONSTELLATIONS.md`, packages D-43, D-44, D-41 (escalated, option B asked), D-18/D-22 (BILL1 on synthetic data: option A). Open PR read on its head: **#939** QUAL1 part 1 (`bc6ef4e`, migration 0120, ADR-163; CI `db` red per the PO record, `cra` gate not clear). Issues: #931, #927, #928, #924, #935 (UXR-129) read; open `automation` issues #793, #912. No contradiction between my prompt and `FOUNDER_DECISIONS.md` v8: FE-040 (7) restates the AI work flows of FE-028 and adds the GM-2 add-on M-DOK; it changes no `aia` duty.

**Nothing below is a measurement.** I ran no tests and read no database; CI states come from the PO record and the GitHub API. Bottleneck map v2 (review 18) stands; the weekly refresh with the nursing-home ward sketch is due on 2026-11-10 (OPEN). The cover simulation (QUAL1-12/-13) gives that refresh its first nursing-home step with recorded events; its effort today (phone chain to find a cover) is not recorded anywhere in NAVORA: UNKNOWN, no minutes estimated here.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-61 | Planning → Visit: the activities a visit requires (QUAL1-6): every member who creates or plans visits; in a ward every visit of every resident | **IMPLEMENTED on #939 (not merged), 0120:** `public.visit_activities` keyed on `visit_id`, append-only; without a row `private.qual_visit_activities` falls back to A1 (needs assessment) and **B13** (any KLV-B minutes). Matrix v0.2: B13 for `fage_efz` is **"?"**, which is never allowed (QUAL1-8). **Consequence (simulation organisation only, today):** a FaGe can be planned for a KLV-B visit only if that visit carries its own activity rows. A PLAN2 series generates its visits one by one, so the activities would be entered per generated visit; part 1 writes them by fixture only, the command comes with part 2 (PLANNED). The brief leaves the place open (open question 1). **Patient-care benefit of per-visit entry beyond a case-level list: none shown**; the strict fallback itself is a safety control and stays | **eliminate the per-visit entry through the care graph:** (1) the activity list lives once where the care is planned (the case's care plan or order line, and the PLAN2 series that carries it); every generated or hand-made visit of that case inherits it at creation, with no act; (2) a per-visit addition or removal is the exception, recorded with its actor; (3) a change of the case list applies to future planned visits and re-runs the QUAL1-8 check on them (a member who no longer passes is released, CR-051 pattern), never silently to past ones; (4) the B13/A1 fallback stays for a visit with no list (strict, unchanged). Whether a visit may ever need an activity its case list does not carry, and whether inheritance is clinically acceptable for a changing care plan, is `cra`'s (UNKNOWN) | L (structure); the matrix stays G with `cra` | stage 0, no AI; `po` (QUAL1 part 2 criterion), `cra` (inheritance and exception), `eng` (where) | activity-entry acts per 100 visits per team and month (target: series visits need none); share of simulation visits checked against an inherited list vs. a per-visit list | **high** | #940 |
| AUT-62 | Delegation (QUAL1-9, CR-176): the delegating `nurse_hf_fh`; in a ward every FaGe and every resident who needs a D activity | **IMPLEMENTED on #939:** `public.record_delegation` records **one** case, **one** activity, **one** delegate per call, with a fixed `valid_until`; renewal is a new record. The delegation itself is a clinical and legal control (FE-039, FE-040): **not challenged**. **Form cost:** acts = delegates × cases × D activities, again at every end date (K-4 maximum period OPEN). A ward with several FaGe and many residents needing B3 multiplies this into the largest new act count QUAL1 adds | **same rows, fewer acts:** (1) one recorded act may cover several (case, activity, delegate) pairs the nurse has instructed, each still its own row with its own dates and its own validity check (nothing in QUAL1-8 changes); (2) renewal is one act on the list of the nurse's delegations that end within the lead time (AUT-63), each line ticked, no "renew all"; (3) whether a delegation may ever be scoped wider than one case (a ward, a resident group) is a legal and clinical question, **UNKNOWN** (`cra` with `lca`, K-4, L-7); nothing is widened here | G (with the matrix) | stage 0; no agent creates, extends or infers a delegation (QUAL1-9, prohibited class `qualification` on #939: kept); `po`, `cra`, `uxa` (list form) | delegation acts per 100 delegated visits per team and month; share of visits released "Delegation abgelaufen" | medium | report only; comment on #939 |
| AUT-63 | Monitoring of expiring evidence and delegations (QUAL1-4, S3b, S8): the team that plans and the member concerned | **PLANNED (brief "AI leverage" 3 only):** "expiring evidence and delegations (≤ 14 days, placeholder, K-4) … watched continuously". **Not an acceptance criterion.** The criteria build only the release at the instant of expiry (QUAL1-4, S8: "validity ends 10 minutes before the visit start") and the refusal at visit start (QUAL1-17). Without the forecast every expiry becomes a short-notice cover: the exact bottleneck QUAL1 is built to remove. The release and the start check are safety controls: **not challenged** | **monitor before the release:** (1) a deterministic forecast marks each planned visit whose responsible member's evidence or delegation ends before the visit, as a fact on that visit in the team's plan and on the member's own `/field`, from the lead time on (14 days PROVISIONAL, K-4); (2) the forecast closes by itself when a new record covers the visit (AIG1-C5 pattern), no "gelesen" act, no separate list to work through; (3) it feeds the PLAN3 day plan as a limit for the days after the end date, so no proposal is made that the release would later undo; (4) no per-person expiry list for anyone but the member and the delegating nurse's own delegations (no per-person view) | L | stage 0; `po` (criterion), `cra` (lead time stays PROVISIONAL), `uxa` | share of "Voraussetzung abgelaufen" and "Delegation abgelaufen" releases with less than 24 h lead, per team and month (target near 0) | medium | report only |
| AUT-64 | Qualification profile draft and member confirmation (QUAL1-3, FE-040 (5) "KI-Entwurf"; FE-028 work flow): the member | **IMPLEMENTED on #939:** `public.confirm_my_qualification` writes one value as `self_confirmed`; `self_confirmed` never counts for E or D (QUAL1-2). **IMPLEMENTED on #939:** `private.aig1_prohibited_target` gains the class `qualification` for `member_qualification_evidence`, the delegation tables and the matrix: **no agent can propose any value there** (correct: FE-039). **Gap:** the brief allows a draft "by a rule … and by an AI only on synthetic data", but no lawful landing exists: a draft built outside AIG1 has no ledger, no provenance, no correction rate (§8); a draft through AIG1 is refused. And the confirmed value gates nothing, so a draft saves the member typing a few values at most | **no agent for a value that gates nothing; one form:** (1) stage 0: the member's profile form is pre-filled by a deterministic rule from structured input already in NAVORA (her membership, a seed or partner record), each value confirmed by her with the existing command, no "alle bestätigen"; the row records "aus Vorlage" as its source; (2) an AI draft (FE-040) is built only where the input is unstructured (a diploma or certificate scan), only on synthetic data (D-35 rule A), and lands as a suggestion in a separate draft register field of class `record`, never on the evidence table, so the prohibited class stays whole; (3) the PO decides in QUAL1 part 2 whether (2) is worth an agent before D-29 says what verification is; until then (1) suffices | L for (1); G for (2) only if it reads a clinical document (`cra`) | (1) stage 0; (2) synthetic only, after a brief line; `po`, `lca` (staff data, D-41) | acts per profile; share of draft values corrected by the member (per agent and field, never per person) | medium | report only; comment on #939 |
| AUT-65 | M-DOK, GM-2 add-on (FE-040 (2), `BUSINESS_MODELS_AND_CONSTELLATIONS.md`, module M-DOK): "KI-gestützte Diktat-, Protokoll- und Berichtserfassung mit menschlicher Prüfung und Freigabe" for a home's own staff | **PLANNED (founder, FE-040), no brief;** mapped to DOC-AI (AUT-54 scope). **Gap:** "Protokoll" reaches beyond the nurse's own note: a handover, a team meeting, a conversation with a resident or relative. Recording a conversation needs the consent of everyone present (my hard rule; legal basis `lca`); DOC-AI as narrowed by AUT-54 covers only the nurse's own unstructured note | **keep M-DOK to the AUT-54 scope until a brief says otherwise:** (1) dictation by the performing nurse of her own note: the narrowed DOC-AI (proposed observations with source span, confirmed value by value, level G); (2) any recording of a conversation (handover, meeting, resident, relative) requires a recorded consent of every person present before recording starts, refused otherwise, no derived or periodic consent (CGR-130 pattern); (3) a structured report or handover text stays the F7 rule from confirmed facts (AUT-54), never re-drafted from a recording; (4) no real audio or text to any AI service before D-41 (D-35 rule A) | G; H when a proposal interprets (`cra` 17:30) | synthetic only until D-41; `po` (M-DOK brief), `lca` (consent, StGB 321, DSG), `cra` (level), `csa` (GM-2 packaging) | acts per note with and without dictation (M-16 companion); share of recordings with complete consent (target 100 %, refused otherwise) | medium | report only |
| AUT-66 | QUAL1 "Removed step and baseline" (AN3 span for the simulation): the measure of the cover gain | **PLANNED (brief):** "time from absence report to confirmed cover, share of absences without a proposal, **number of contacts per cover**". NAVORA records no phone call or message outside itself, so "contacts" has no event source; a constructed count on synthetic data would read as a measurement | **measure only what NAVORA records:** absence report → confirmed cover span (ABS1/COVER1 events), share of absences ending as a care gap (S6), number of COVER1 offers per confirmed cover; "contacts outside NAVORA" stays UNKNOWN until the Phase B partner records it (AUT-57) | L | stage 0; `po` (AN3 span line) | as named, per team and month | low | report only |

### 2 Briefs, plans and packages reviewed (challenge duty)

- **QUAL1 (approved 22:30, part 1 on #939):** the rule on every path with no override (QUAL1-10), overlap as a fact (QUAL1-11), "?" never allowed, the check again at visit start (QUAL1-17), no agent writing evidence or delegations (QUAL1-9/-16): **safety controls, supported, not challenged.** The cover simulation is the right test of FE-040: a proposal or a visible gap, never a false "geeignet". Form findings: AUT-61 (activities per visit, high), AUT-62 (delegation act count), AUT-63 (forecast missing), AUT-64 (profile draft without a landing), AUT-66 (measure). QUAL1-5 "one notice to the professional role" per contradiction: no objection (one notice, nothing resolved automatically). S6 escalation through SIG1/SIG2: supported; the care gap must stay a P-level the Clinical Owner sets, never triaged by an assistant (unchanged rule).
- **FE-039 (team organisation, professional authority, formal responsibility separated):** supported. It is the leaner model: no daily dispatching hierarchy, and the authority question answered by a rule instead of by a person in each case. The formal responsible function (R3/R4) must not become a confirm step on every assignment: it receives escalations (S6, QUAL1-5) and nothing else (consistent with the brief; recorded so part 2 keeps it).
- **FE-040 (GM-1, GM-2, five constellations):** no added act for a care team in the brief. M-DOK: AUT-65. The *Einsatzvereinbarung* for NH-EXT (QUAL1-18, eight fields) is one structured record per order, not per visit: supported; it should be the source of the visit activity list for that order (AUT-61 (1)).
- **FE-041 (one consolidation PR, one gate, one merge):** supported; it is the AUT-49 remedy in its leanest form for a stack (one `cra` gate instead of 15). No finding.
- **D-43 (clinical rule-approval mandate, option B + D preliminary):** no automation objection; whatever function approves, the approval should be per matrix version and cell set, never per assignment (consistent with QUAL1-7).
- **D-44, D-42:** contract and hosting; no care-team act. No finding.
- **D-18/D-22 (BILL1 on synthetic data, option A, versioned rows `validated = false`):** consistent with AUT-59 (rules raise holds, AI only a remark beside them). AUT-59 stays open for the BILL1 brief (due 2026-11-27).
- **D-41 escalated (option B, orchestrator only, conditions 1-10):** no objection from automation; "L before G" and "an entry gate per agent" match the stage path. Stage stays 0.
- **UXR-129 (#935, one refusal text per reason across four paths):** supported; it also removes a coordination cost (a team decoding four texts for one limit). QUAL1 part 2 should start from the one label function (#939 adds `src/features/qualification/labels.ts`).

### 3 AI readiness of delivered items (§8)

- **PLAN3 on `recovery/main` (`48cdb0c`, accepted 01:39):** the first rule agent beyond the synthetic test agent is on the main line with every stage-0 control I checked on its PRs in reviews 29 to 33: ledger, provenance per value, named confirmer, unticked confirm list with no select-all, team switch (PLAN3-10), stop rule with look-back on `/team` (PLAN3-11), measures per team and month only (PLAN3-7, PLAN3-13, CGR-140), fresh request closes stale lines (PLAN3-15), cross-team overlap re-checked at confirm (PLAN3-14). FE-041 states no rule or assertion changed in the consolidation; I did not re-read the consolidated diff line by line (`cra` gate clear on `f9e189d`).
- **QUAL1 part 1 (#939, not merged):** no agent yet. The prohibited class `qualification` is the right boundary (AUT-64 asks where a draft lands). Correction rate per agent and field: not applicable until a draft exists.
- Missing for any model-based agent: an evaluation harness on synthetic cases (none needed at stage 0).

### 4 Stage tracking (D-35)

Stage 0 only (FE-024, rule A). Stage-1 entry conditions: governance layer merged (met, review 35); **first rule agent with its controls on the main line: now met (PLAN3)**; provider and contract: D-41 escalated to the owner 00:39 (option B asked), not decided; three stable pilot months: none (Phase B). FD-22 (provider for synthetic data only) unchanged.

### 5 Findings: state changes and closed

- **AUT-30 (high, #793): closed.** Team side on `recovery/main` with #934 (`48cdb0c`: migration 0111 `plan3_11_team_lookback`, the team's look-back lines on `/team`), Operations side with #814 (review 35). Issue #793 closed with a reference.
- **AUT-31 (low): closed.** Lead time on `recovery/main` (0112 `plan3_13_stop_measures`, #934); expired share with #814.
- **AUT-25: closed** (0113 `plan3_7_team_measures`, "kein Vorschlag" share per team, #934). **AUT-51: closed** (0116 `plan3_15_fresh_request_closes_lines`, #934). **AUT-52: closed** (PLAN3-7 (2): the team's own numbers under its switch on `/team`, #934). Evidence for all five: merge `48cdb0c`, CI green on the merge commit per the PO record, PLAN3 accepted 2026-11-07 01:39; I ran no tests.
- **AUT-54 (high, #912):** adopted; stays open until the DOC-AI brief (due 2026-11-27) carries the six criteria. AUT-65 adds M-DOK to the same brief.
- **AUT-59, AUT-60:** waiting for the BILL1 and DOC-AI briefs.
- **AUT-33:** AN3-C2 (AN3 merged with #841, AN3 accepted per FE-038 once its run was stable green); C2 built after PLAN3, which is now merged: due (PLANNED, `eng`).
- **AUT-49:** remedied for stacks by FE-041; status-row conflicts on role PRs (#936, #937 `dirty` after #934, JOURNAL only) remain the residual cost; no new action.
- **AUT-55 to AUT-58:** not answered yet (unchanged).
- Open, unchanged: AUT-53, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-34 to AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28.

### 6 To the PO

1. **AUT-61 (high, #940):** before QUAL1 part 2 builds the activity command: the activity list once on the case or order line and its series, inherited by visits; per-visit only as the exception. Please answer the challenge before part 2.
2. AUT-62, AUT-63, AUT-64 for QUAL1 part 2 (comment on #939); AUT-66 for the AN3 simulation span.
3. AUT-65 for the M-DOK/DOC-AI brief: consent of everyone present before any recording; scope as AUT-54.
4. Unchanged: AUT-55 to AUT-58; AUT-59, AUT-60.

---

## 2026-11-06 20:20 CET · aia review 35: FE-033 to FE-037 and the PO cleanup merges read; AIG1-C4/-C5 (#814) and AIR1 (#828) now on `recovery/main`: the stage-0 governance layer entry condition is met; AUT-30 Operations side and AUT-31 expired share met on the main line; AUT-54 adopted by the PO and level G answered by `cra`; AUT-33 placed as AN3-C2; new AUT-59 (medium: BILL1 must say where an AI pre-send check lands, AIR1 forbids every billing target) and AUT-60 (low: the omission control of the narrowed DOC-AI as part of the one confirm act); CGR-144 supported as a fact, not a step

**Read:** `recovery/main` at `9a15f98` (since review 34, `30de12f`): PO #913 (FE-033 to FE-036, Blueprint v2.3/v2.4), #914 (FE-037 cleanup, issue matrix, PR map), #896 (my review 33), `cra` #911 and #915 (17:30), PO cleanup merges #803, #804, #806, #809 (UX2), #810 (CGR-110), #813 (RLS4-C3), **#814 (AIG1-C4 + AIG1-C5, migration 0105)**, **#828 (AIR1, migration 0107)**, PO #916 (18:39, Blueprint v2.5). Open: PO **#917** (19:39: AIR1 accepted, AN3 pre-merge decisions, #841 merge refused by the session's permission check), the PLAN3 stack #872 to #910 and #841 (unmerged, unchanged own code since review 34 per the PO and `cra` records; diffs not re-read). `FOUNDER_DECISIONS.md` v4 read: FE-037 (cleanup before new features, Engineering paused) is newer than my prompt; it changes no `aia` duty, so no contradiction to report. Issues labelled `automation`: #793 (AUT-30), #912 (AUT-54). No new or changed brief other than `AIR1.md` and `AN3.md` (on #917). No DOC-AI, PLAN4, QUAL1, BILL1 or NH-A brief yet (PLANNED).

**Nothing below is a measurement.** I ran no tests and read no database; CI states come from the PO and `cra` records and the GitHub API. Bottleneck map v2 (review 18) stands; the weekly refresh with the first nursing-home ward sketch is due on 2026-11-10 (OPEN).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-59 | Billing preparation with pre-send checks (FE-028, BILL1, no brief): the team that releases a month's billing | **IMPLEMENTED (#828, `bdf42bd`, 0107):** `private.aig1_prohibited_target` refuses any register field on `billable_facts`, `billing_rules`, `tariff_rates`, `quality_holds` (42501), so no agent can ever propose a billing value or raise a hold. **IMPLEMENTED (QG1):** `visit_has_open_hold` is the single billing rule. **PLANNED (Blueprint, FE-028):** "billing preparation with pre-send checks"; "AI checks only after D-41". **Gap:** nothing says where an AI check result would land. The two obvious forms both cost: (a) an AI hold is now refused in code; (b) a separate "AI-Prüfliste" the team works through before sending is a second review pass on top of the holds it already clears, for findings a rule would mostly raise | **rule first, AI only as text at the edge, one list:** (1) every pre-send check that can be stated as a rule is a deterministic check that raises a QG1 hold (stage 0, no AI); which checks exist beyond today's (unsigned report, open hold) is UNKNOWN until `cra`, the Clinical Owner and `lca` name them; no tariff, KLV or minutes comparison is invented here (§12: no computed comparison of assessed minutes without a `cra`-reviewed brief); (2) an AI check, if D-41 ever allows it, may only read free text (a correction reason, a note) and show a remark beside the existing hold list, never a hold, never a value, never a separate list to clear; (3) the BILL1 brief states (1) and (2) and cites AIR1 as the boundary | L for (1); G for (2) (`cra`) | (1) stage 0; (2) synthetic only until D-41; `po` (BILL1), `cra` (check list), `lca` (D-41, billing data to a provider) | holds cleared per team and month before release, and acts per billing release (open, check, clear, send), before and after; share of releases sent with no remark open | medium | report only |
| AUT-60 | Narrowed DOC-AI, `cra` omission control (CGR answer 17:30: "the note stays in the record; spans that produced no proposal are shown to her before she finishes"): the performing nurse | **PLANNED (`cra` 17:30, not yet a brief):** the control is right and stays (safety control, not challenged). **Form risk:** written as "shown before she finishes", it is often built as a second screen or a "Hinweise gelesen" tick after the confirm list: one more act per note, also on the many notes where every span produced a proposal | **same act, no extra tick:** the note is shown in the confirm list with its unproposed spans marked inline; when every span is proposed, nothing extra is shown; finishing is the one act that already exists; an unproposed span can be turned into an observation from where it is shown (same confirm command). No "gelesen" tick, no second screen | G (with DOC-AI) | synthetic only until D-41; `po` (brief), `uxa` (form), `cra` (confirms equal safety) | acts per note (M-16 companion) with and without unproposed spans; share of notes with an unproposed span later added by correction (F6R) per team and month | low | report only |

### 2 Briefs, plans and packages reviewed (challenge duty)

- **FE-033 to FE-037:** no added administration for care teams; FE-037 is a repository process. The cleanup shows the AUT-49 cost directly: every merge re-conflicts the shared docs files of every other open PR, and with Engineering paused a code conflict (#815) cannot move at all. **The PO's proposal (19:15, E) "status rows only on `recovery/main` after a merge" is AUT-49's remedy in a leaner form: supported.** The permission refusal of the scheduled merge (#917) is the owner's setting; no finding from me (AUT-48 closed).
- **AIR1 (#828 merged, accepted by the PO on #917):** supported; it turns four of the hard rules into a failing write (no billing value, no safety-signal priority through an assistant). It adds no act. Consequence for BILL1: AUT-59. The J5 note on #917 ("a fixed rule on a nurse-signed report is 'Apply rules', not an AI billing decision") is consistent with AUT-59 (1).
- **AIG1-C4 + AIG1-C5 (#814 merged):** AUT-30 and AUT-31 remedies are on the main line (§5).
- **AN3 pre-merge decisions (#917):** AUT-33 placed as **AN3-C2** (act counts per 100 visits per team and month, after PLAN3): adopted as proposed. ADR-144 deviations 1-7: no automation objection.
- **`cra` CGR-144 (PLAN2 series sets the primary nurse without the overlap fact):** supported in the `cra` form (a fact, not a refusal). Form point for the brief line: the overlap fact of a generated series is a derived exception on `/team` that closes by itself when the overlap is gone (same pattern as AIG1-C5), never a confirm step per generated visit; a regeneration that would book a member twice may leave those visits to the PLAN3 day-plan proposal instead of a person checking each one (PO call; whether a double booking is allowed stays the team's, not NAVORA's rule).
- **`cra` DOC-AI level answer (G, H when a proposal interprets):** taken; the validator "a proposal restates a span; it never adds a finding" is a deterministic check, supported; omission control form: AUT-60.
- **CGR-137 remainder (COVER1 `accept_cover`):** no objection; the fact is shown, no act added.

### 3 AI readiness of delivered items (§8)

- **On `recovery/main` now (IMPLEMENTED):** AIG1 ledger, provenance per value, named confirmer, field classes with no accept-all on `record`, stop rule with look-back, monitor-the-monitor, correction rate per agent (window stats) and, new with #814, expired proposals counted apart from decisions ("Abgelaufen ohne Entscheid: n" on `/operations/assistenten`) and a stop followed up by its open lines whatever the agent's state; AIR1 prohibited targets. Only the synthetic test agent is registered on the main line.
- **PLAN3 (first real rule agent):** still on the unmerged stack #872 to #910 (state as in review 34). Correction rate per agent and field reaches the team only with #894.
- Missing for any agent beyond rules: evaluation harness on synthetic cases for a model-based agent (none exists; none needed at stage 0).

### 4 Stage tracking (D-35)

Stage 0 only (FE-024, rule A). Stage-1 entry conditions: **stage-0 governance layer merged: now met** (AIG1 with C1 to C5 and AIR1 on `recovery/main`; PLAN3 controls still unmerged, but they are agent controls, not the layer). Still missing: provider and contract (owner, D-41 inputs from `lca` on #860 and `eng` outstanding), three stable pilot months (no pilot; Phase B). FD-22 (provider for synthetic data only, narrowed by AUT-54 to the A7 note flow) is not a stage change.

### 5 Findings: state changes and closed

- **AUT-54 (high, #912):** **adopted by the PO** (15:00, scope as proposed, six criteria into the DOC-AI brief due 2026-11-27); criterion 6 answered by `cra` (level G). Stays open until the brief carries the criteria; issue #912 stays open.
- **AUT-30 (high, #793):** Operations side **met on `recovery/main`** (#814, `e4f52e8`, 0105 point 5/6: the `agent_stopped` exception per stop with open lines, whatever the state; closes at 0 offen; pgTAP 106 in CI per the PO record). The team side (C5 (d), look-back on `/team`) is carried by PLAN3-11 #883 (unmerged). Closes when #883 merges unchanged.
- **AUT-31 (low):** expired share **met on `recovery/main`** (#814: `last_window_expired`, shown beside the decided count); the lead time is on #885 (unmerged). Closes when #885 merges unchanged.
- **AUT-33 (medium):** adopted as AN3-C2 (PO #917, not merged); built after PLAN3.
- **AUT-49 (medium):** the PO proposes the remedy (status rows only on the main line, #861); unchanged otherwise.
- **AUT-25** (#886), **AUT-51** (#897), **AUT-52** (#894): close when their PRs merge unchanged.
- **AUT-55 to AUT-58:** not yet answered (the PO named them for a later cycle; the cleanup takes precedence, FE-037).
- Open, unchanged: AUT-53, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-34 to AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28.
- Closed this run: none (each remedy above still waits for a merge or a brief).

### 6 To the PO

1. AUT-59 and AUT-60: for the BILL1 and DOC-AI briefs (no issue; medium and low).
2. CGR-144 brief line: an overlap of a generated series as a derived, self-closing exception, no per-visit confirm.
3. Unchanged from review 34: AUT-55 to AUT-58; #897 deviation 3 (one visit-day counted once).
4. The stage-0 governance layer is on the main line; the stage-1 decision (D-41) now waits only for its `lca` and `eng` inputs and the owner.

---

## 2026-11-06 14:40 CET · aia review 34: founder direction 2026-11-06 read (FE-023 to FE-032, Blueprint V2/V2.1, D-41, D-42, Founder report); AI work flows DOC-AI and PLAN4 reviewed before their briefs; new AUT-54 (high: DOC-AI as framed re-drafts a report NAVORA already builds from the facts and adds a review step per visit), AUT-55, AUT-56, AUT-57 (medium: the administration metrics and the H-1 baseline), AUT-58 (low); AUT-51 remedy met on #897; PLAN4 supported as a rule with seven controls

**Read:** `recovery/main` at `30de12f` (since review 33: PO #898 Blueprint V2, #900 Founder Executive Report, #904 founder direction and Blueprint V2.1, #908 Phase A home care + nursing-home ward and `lca` commissioned, `eng` #800 UX2-27/-29 merged). New or changed: `FOUNDER_DECISIONS.md` (FE-001 to FE-032), `FOUNDER_DIRECTION_CONFIRMATION_2026-11-06.md` (§1.1 H-1 to H-6, points 6-9), Blueprint §1 (AI work flows, SV-4 to SV-7, care-context matrix §1.3), §4 M8.1b, §7 FD-22, §10.2 M-11 to M-21; packages **D-41** (#905) and **D-42**; `briefs/PLAN3.md` (PO 06:30). Open `eng` PRs read on their heads: **#897** PLAN3-15 (`6dace1d`, ADR-157, migration 0116), #902, #903, #906, #910; CI read from the GitHub API: all 4/4 green (#897, #902, #903, #906 `dirty` against the new base). No brief DOC-AI, PLAN4, QUAL1, BILL1 or NH-A1 to NH-A5 exists yet (PLANNED, due 2026-11-20 to 2026-12-11). Open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands for home care; the nursing-home ward (FE-031) has no map yet: OPEN, first sketch with the weekly refresh on 2026-11-10, from published sources I read and cite, never from assumptions.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-54 | Documentation at visit end (DOC-AI, Blueprint §1 and M8.1b, FD-22): the performing nurse | **IMPLEMENTED:** the report is already built by the server from the recorded facts (F6 `visit_report_snapshot`, F7 sign-at-completion with snapshot hash, F6R versions, OBS1 author per observation); the PO says so in the confirmation (point 6). **PLANNED (Blueprint):** DOC-AI "drafts a structured report from recorded times, services, observations", reviewed with a diff and signed. **Effect:** the structured part would be produced a second time, by AI, from the same records, and the nurse gets one more act per visit (read and correct the AI draft against a diff) for facts she already sees as they are. No patient-care benefit over F7 is shown; the hazards are new (invented or dropped facts, D-41 `cra` request). FD-22 asks the owner for an AI provider largely to test this. What the nurse still writes today is her **observation text** (OBS1) and corrections (F6R); that is where documentation time is left | **eliminate the duplicate, rule for the structure, agent only at the edge:** (1) the structured report stays the deterministic F7 snapshot (stage 0, no AI, no added review); (2) DOC-AI is scoped to unstructured input: the nurse's own dictated or typed note turned into proposed observations, each with its source span, confirmed value by value in her flow (catalogue A7, D-35 limits on dictation stay); (3) a narrative report or handover text (A9) stays in the separate clinical module (D-34 C); (4) measure first: M-16 and the AN3 spans (#841) on the synthetic seed show how many minutes after visit end are left once F7 is in, before any DOC-AI build; (5) FD-22 rewritten accordingly: for the structured part rules are the target, not a "stand-in" | L for (1); G for (2) (`cra` to confirm; the Blueprint calls DOC-AI G, my catalogue calls A9 H: UNKNOWN until `cra`) | (1) stage 0 now; (2) synthetic only until D-41; `po` (DOC-AI scope), `cra` (level, hazards), `lca` (D-34 statement v2 for DOC-AI) | minutes from visit end to final report (M-16) and acts per report (open, read, correct, sign) per team and month, before and after; DOC-AI correction rate per field (§8). Never per person | **high** | #912 |
| AUT-55 | Metric M-15 "administrative minutes per visit" (Blueprint §10.2, H-1): `po`, read by the owner | **PLANNED definition:** (confirmed paid minutes − care minutes) ÷ visits. In home care the difference holds **travel** (AN3-2: travel within visits is measured; return trips are not) and breaks-free non-visit work of every kind (team meeting, training, administration, on-call without a visit: WORK1-2's list). Travel was rank 1 of map v2 and is not administration; meetings and training are not avoidable overhead either. **Effect:** M-15 would call travel "administration", H-1 would be confirmed by construction, and a nursing-home value (no travel) would not be comparable with home care. The AN3 spans (#841, not merged) already split the time by step | **rule (definition only, no new data):** M-15 = report segments (F7 sign time − visit end) + WORK1-2 "administration" + coordination acts outside visits, per team and month; travel, team meetings, training shown beside it, never inside; the denominator per visit (home care) or per resident-day (ward, AUT-56). M-11 counts every human act on an assignment, including undo and override of a PLAN4 mandated line, so a mandate that teams keep undoing does not read as saved work. Name the figure "Administrationsminuten (gemessen: …)" with what is in and out | L | stage 0; `po` (definition); no `cra`, no `lca` (same readers, team level) | the definition is testable on the synthetic seed: pgTAP with a fixture whose travel changes and whose M-15 does not | medium | report only |
| AUT-56 | Nursing-home ward simulation (FE-031, NH-A1 to NH-A5, M-15 "per resident-day"): ward nurses | **PLANNED (no brief):** M-15 and the North Star subtract care minutes from paid minutes. In home care, care minutes come from visit events the nurse taps anyway (`started`/`completed`). A ward has no visit: care is continuous across residents in a shift. **Risk:** the only way to get "care minutes" in a ward by the home-care formula is a start/stop tap per resident and care act; that is a new administrative act many times per shift, with no patient-care benefit | **eliminate the subtraction in the ward, measure administration directly:** the ward measures the administrative acts it already records (report and handover segments, planning acts, absence-to-cover minutes, billing holds) per team and resident-day; care time is the remainder of the confirmed shift and is labelled as such; **no per-resident or per-act time tap** is introduced for measurement. Write this into NH-A1 to NH-A5 as a design rule before the briefs are drafted | L | stage 0; `po` (NH briefs), `uxa` (ward screens); `cra` for any ward documentation rule (sector rules UNKNOWN, `lca`, `cra`) | no ward screen has a time tap per resident (e2e on the NH-A screens); M-15 per resident-day computed from existing events only | medium | report only |
| AUT-57 | H-1 baseline "before and after" (confirmation §1.1): `po`, owner, the Phase B partner's nurses | **PLANNED:** H-1 is checked by "a baseline of administrative minutes in the simulated operation" (Phase A) and "before and after introduction" at the real partner (Phase B). **Gap:** (a) a value in the simulation measures what the synthetic seed was written to contain, not a team's work; (b) NAVORA records nothing at the partner before it is introduced, so a "before" needs another source; a time study or diary would be new administration for the nurses being relieved | **monitor with what exists:** (a) label Phase A values "Simulationswert: prüft die Messung, nicht die Wirkung" everywhere they appear (Founder report, dashboard, partner texts); (b) Phase B "before" from records the partner already keeps (paid hours, planned and billed visits or resident-days, staff in planning or dispatch roles), read at organisation level with `lca` on access, plus the published benchmarks I cite in the map; no diary, no stopwatch, no per-person timing; (c) the first NAVORA months are the in-system baseline, compared month on month (M-15 to M-20) | L | stage 0; `po`, `lca` (partner data, D-42 contract clause), `csa` (claims to partners) | H-1 to H-3 each name their source and whether it is simulated or real; no added act for partner nurses | medium | report only |
| AUT-58 | Owner decision lists: `po`, owner | **IMPLEMENTED (docs):** asks to the owner now live in Blueprint §7 (FD-01 to FD-26), the Founder report decision board, `OWNER_AGENDA.md` bundles, `decisions/INDEX.md` and `FOUNDER_DECISIONS.md` (record). The Blueprint already found one contradiction between two of them (SV-1, Basel vs. Zurich). Each PO cycle updates several by hand | **rule:** one source for open owner asks (§7 FD rows), the Founder report and `OWNER_AGENDA.md` generated from it or replaced by a link; `FOUNDER_DECISIONS.md` stays the record of answers | – | – ; `po` | owner asks with differing text across files: 0 (agents-check could test it) | low | report only |

### 2 Briefs, plans and packages reviewed (challenge duty)

- **Founder direction and Blueprint V2.1 §1:** the four AI work flows are the right targets (map v2 ranks documentation, planning and absence, billing preparation among the largest). Challenge only of their form: DOC-AI (AUT-54); measures (AUT-55 to AUT-57). FE-032 "NAVORA replaces a hierarchy and sets none in its place" is the test I apply to every NH-A brief (ward without unit hierarchy, Blueprint §1.3).
- **PLAN4 (SV-7, routine assignment under an explicit, revocable team mandate):** supported; it is the design order (rule before agent) and removes the confirm act for routine lines that PLAN3 still needs. **Conditions I will check on the brief** (also in `AI_OPERATING_MODEL_REVIEW.md` §12): (1) the mandate is a team act recorded with the members who set it, never one coordinator's switch, revocable by any member; (2) it lists which lines are routine (only `schedule`-class fields, AIG1-5; never a `record` field, never date, time, minutes or category); (3) every mandated line is a ledger row with its own outcome ("unter Teamauftrag zugeteilt") and the rule version; (4) undo by any member in one act, counted in M-11 (AUT-55); (5) the four PLAN3-2 limits and any unclear qualification, conflict or overlap leave the line as a proposal for a person, never applied; (6) the stop rule applies (undo rate per team over its threshold switches the mandate back to proposals; threshold set by the team, not by `aia`); (7) no per-person view of applied or undone lines. `cra` and `lca` (automated decision affecting staff) before approval, as the Blueprint says.
- **QUAL1, BILL1:** no brief yet; I will read them when drafted. BILL1 "rules first, AI checks only after D-41" is the right order; no finding.
- **D-41 (#905):** supported as prepared (rule A stays). Option D's rule "no workflow needs an external AI tool" is the strongest direct-care argument for building the stage-0 rule flows first: a nurse who still retypes uses whatever tool is at hand. AUT-54 narrows what option B must carry for documentation. No finding on the package itself, so no comment on #905; AUT-54 has its own issue.
- **D-42:** no automation finding; AUT-57 (b) asks for one clause (organisation-level read of the partner's existing records for the baseline, `lca`).
- **Blueprint M-11, M-12 (owned by `aia` from M4) and M-15 to M-17 (with AN3):** definitions proposed in AUT-55; M-12 and M-20 as written are supported (team-level, no person key).
- **#897 PLAN3-15 (ADR-157):** **AUT-51 remedy met on the head** (fresh request closes earlier undecided lines with a recorded outcome, no `open_proposal` refusal, no tap added; pgTAP 116). Deviation 3 (closed lines still counted in `lines` and the "kein Vorschlag" share): I support excluding closed lines from the shares the team reads (one visit-day counted once), otherwise a second request after a sick call doubles the "kein Vorschlag" count under the team's switch (PLAN3-7 (2)). PO call.
- **#902 (CGR-75 (5)), #903 (PLAN3-17 (2), PLAN3-3 wording), #906 (PLAN3-9 (2)), #910 (PLAN3-16):** read at title and CI level only (diffs not read this run); titles match the PO's 06:30 placement. Full read next run.

### 3 AI readiness of delivered items (§8)

PLAN3 stack (unmerged, #876 to #897): as in review 33; the last `aia` acceptance item (PLAN3-15) is now built on #897. Missing: the expired share (AUT-31, #814). No other delivered item proposes, drafts or ranks.

### 4 Stage tracking (D-35)

Stage 0 only (FE-024 confirms rule A). Stage-1 entry conditions: provider and contract (owner, D-41 option B, inputs requested), stage-0 governance layer merged (AIG1 #814, AIR1 #828: not merged), three stable pilot months (no pilot). FD-22 (provider for synthetic data only) does not move real data and is not a stage change; AUT-54 reduces what it is needed for.

### 5 Findings: state changes and closed

- **AUT-51 (medium):** remedy met on #897 `6dace1d`; closes when #897 merges unchanged.
- **AUT-52, AUT-53:** unchanged since review 33 (#894 unmerged; PLAN3-7 (2) clause still to drop).
- **AUT-25** closes on #886 merge; **AUT-31** waits for #814; **AUT-30 (high, #793)** Operations side waits for #814.
- Open, unchanged: AUT-49, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-33 to AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28.
- Closed this run: none.

### 6 To the PO

1. **AUT-54 (high, #912):** scope DOC-AI to unstructured input before drafting the brief (due 2026-11-27); the structured report stays F7; restate FD-22 for the owner.
2. AUT-55, AUT-56, AUT-57: fix the M-15 definition, write "no per-resident time tap" into NH-A1 to NH-A5, label simulated values; my PLAN4 conditions above for the brief (2026-12-04).
3. #897 deviation 3: one visit-day counted once in the team's shares.

---

## 2026-11-06 08:25 CET · aia review 33: PO #893 (06:30) decisions read; AUT-51 → PLAN3-15 and AUT-52 → PLAN3-7 (2) adopted as proposed; `eng` #890 (CGR-140), #891 (UXR-113), #894 (PLAN3-7 (2)), #895 (PLAN3-9 (1)) and `cra` #892 (05:30) read on their heads; AUT-52 met on #894; correction of my own AUT-52 text (AUT-53, low: "keine Bezugsperson" is not a "kein Vorschlag" reason)

**Read:** `recovery/main` at `9c58939` (PO #893 merged 07:16; no code merged). Open, read on their heads: `eng` **#890** (`a4b1ce0`, ADR-153, migration 0114), **#891** (`487c84a`, ADR-154), **#894** (`0984d3d`, ADR-155, no migration), **#895** (`a6b8e00`, ADR-156, migration 0115); `cra` **#892** (05:30). CI read from the GitHub API: #890, #891, #894, #895 4/4 green. Changed brief: `PLAN3.md` (PLAN3-3 wording, PLAN3-7 (1)-(2), PLAN3-9 (1)-(2), new PLAN3-15, PLAN3-16, PLAN3-17). Open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-53 | Team reads its own "kein Vorschlag" numbers under the switch (PLAN3-7 (2), `/team/tagesplan`): the team | **Correction of my own AUT-52 (review 32).** I wrote that visits get "kein Vorschlag (keine Bezugsperson)" and proposed showing the largest reason "the team can fix (no primary nurse set)". That premise is wrong: PLAN3-3 falls back to the member with the most free capacity when no primary nurse or deputy passes, so a missing primary nurse never produces "kein Vorschlag"; the stored reasons are the four PLAN3-2 limits `not_active`, `needs_rn`, `absent`, `overlap` (migration 0114, `no_proposal_*` columns). The PO wrote my clause into PLAN3-7 (2) and into a challenge row; `eng` correctly did not build it (ADR-155 deviation 2: it would need a new count and a code the brief does not name). **IMPLEMENTED on #894:** the line plus a disclosure "Alle Zahlen dieses Monats" that already shows the four stored reasons for the team's own row. No step for a nurse is missing | **eliminate the clause, build nothing:** drop "plus the largest 'kein Vorschlag' reason when it is one the team can fix itself (no primary nurse set)" from PLAN3-7 (2) and accept #894 as built (ADR-155 deviation 2); the four reasons one tap away answer the team's question with no migration. Accept deviation 3 (disclosure instead of a link) too: the Operations screen is coordinator-only, so a link would be a dead end for a team member. A missing primary nurse shows in the continuity share (AN2, same disclosure), not in "kein Vorschlag" | L | stage 0; `po` (brief wording); no `cra`, no `lca` | none new; PLAN3-7 (2) e2e as written | low | report only; one comment on #894 |

### 2 Briefs, plans and packages reviewed

- **PO #893, PLAN3 amendments (challenge review per step):**
  - **PLAN3-15** (AUT-51): adopted as proposed, with `cra`'s three conditions; removes a clean-up at the busiest moment and adds no tap. The count of closing requests apart from the three decision shares is right: a closed line is not a decision. Supported.
  - **PLAN3-7 (1)** "Abgelehnt" share and **(2)** team line: supported, except the clause corrected in AUT-53.
  - **PLAN3-9 (1)** (CGR-138): one yes/no column, no act. Supported. **PLAN3-9 (2)** (UXR-103, decide only on `/team/tagesplan`): one place for one decision; supported.
  - **PLAN3-16** (CGR-137): information only, no refusal, no confirmation tap, recording whether it was shown is a system fact with no nurse effort. Meets my 20:20 condition. Supported.
  - **PLAN3-17** one label function: removes a wrong pick. Supported. PLAN3-3 wording: no finding.
  - PO challenge row on AUT-52 ("pilot hypothesis on 'keine Bezugsperson' gaps"): rests on the same wrong premise (AUT-53); the hypothesis that fits the code is "teams with low continuity share set primary nurses once they see it".
- **#890 CGR-140 (ADR-153):** three shares add to 100 % of decided lines (pgTAP 114: 50/25/25). Meets §8 "correction rate per agent and field" with the rejection visible. Supported.
- **#891 UXR-113 (ADR-154):** the `/team` "Verantwortlich" picker takes the same label. Supported.
- **#894 PLAN3-7 (2) (ADR-155):** **AUT-52 remedy met on the head:** the team's own row only, same reader and suppression, failed read never shown as 0, no colour above `info`, no target, no other team, e2e that a non-member sees none of the numbers. Deviations 1 (unmerged PO note, now merged as #893), 2 and 3 supported (AUT-53); 4 (`uxa` wording) for `uxa`.
- **#895 PLAN3-9 (1) (ADR-156, migration 0115):** "Noch offen" and "Einsatz öffnen" on every line; yes/no only. Deviation 4 ("Noch offen" also on a confirmed line whose visit has nobody now) supported: the line shows the visit's state, which is what the team needs to act. Deviation 3 (decided `not_found` e2e waits for a seeded "kein Vorschlag" line, CGR-75 (5)) noted; same gap as before.
- **`cra` #892 (05:30):** CGR-139 and CGR-140 met; gates clear in stack order. No finding.

### 3 AI readiness of delivered items (§8)

PLAN3 on the stack heads (#876 to #895, not merged): suggestion ledger, provenance per value, named confirmer (decision state only, no per-person view), no accept-all, stop rule with team look-back and its measure, evaluation on synthetic data (Testorganisation G, pgTAP 110 to 115): as in review 32. **Correction rate per agent and field:** now complete with "Abgelehnt" (#890) and shown to the team that holds the switch (#894). Missing: PLAN3-15 (AUT-51 test, not yet built; PO gating); the expired share (AUT-31, #814).

### 4 Stage tracking (D-35)

Stage 0 only. Stage-1 entry conditions unchanged: no AI provider decision (owner), no stage-1 package; the stage-0 governance layer (AIG1 #814, AIR1 #828) unmerged.

### 5 Findings: state changes and closed

- **AUT-51 (medium):** decided by the PO as PLAN3-15 (#893); remedy PLANNED, not built. Closes when PLAN3-15 merges with its pgTAP.
- **AUT-52 (medium):** decided as PLAN3-7 (2); remedy met on #894 `0984d3d`; closes when #894 merges unchanged. Its "fixable reason" part is withdrawn (AUT-53).
- **AUT-25 (medium):** closes on #886 merge (unchanged). **AUT-31 (low):** expired share waits for #814. **AUT-30 (high, #793):** Operations side waits for #814.
- Open, unchanged: AUT-49, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-34, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28 (P-38).
- Closed this run: none.

### 6 To the PO

1. AUT-53: drop the "no primary nurse set" clause from PLAN3-7 (2) and accept #894 deviations 2 and 3 as built; correct the AUT-52 challenge row's hypothesis.
2. PLAN3-15 is the one remaining `aia` acceptance item not built.
3. #814 (AIG1-C4/-C5) still carries AUT-30, AUT-31 and PLAN3-15's possible closing outcome; merge order is the PO's.

---

## 2026-11-06 02:15 CET · aia review 32: PLAN3 stack read on its heads (`eng` #880 part (b) slice 1, #882 PLAN3-12, #883 PLAN3-11, #885 PLAN3-13, #886 PLAN3-7, #888 CGR-139; `cra` #881 21:30, #887 01:30; `uxa` #850 to 23:50); stage-0 controls met on the screen; AUT-25 remedy met on #886 (closes on merge); AUT-31 lead time met on #885, expired share waits for #814; CGR-140 option (a) supported; new AUT-52 (medium: the team cannot see the measures of its own switch)

**Read:** `recovery/main` at `c315efc` (since review 31 only my #869 merged; no code merged). Open, read on their heads: `eng` **#880** (`12f0b0d`, ADR-147), **#882** (`c734eaf`, ADR-148), **#883** (`f05a5ef`, ADR-149, migration 0111), **#885** (`f37180d`, ADR-150, 0112), **#886** (`d5411ee`, ADR-151, 0113), **#888** (`ca35e1e`, ADR-152); `cra` **#881** and **#887** (CGR-138, CGR-139, CGR-140); `uxa` **#850** (UXR-102 to UXR-112). No new or changed brief, no PO cycle since #877; open `automation` issues: #793 (AUT-30) only. CI read from the GitHub API: #880, #882, #883, #885, #886 4/4 green; #888 in progress.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal | Device level | AI stage and gate | Measure | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-52 | Team decides whether to keep "Tagesvorschlag" on (PLAN3-10, `/team/tagesplan`): the team itself | **IMPLEMENTED on #886 (not merged):** `plan3_team_measures(month)` already answers an active member for her own teams (ADR-151 decision 3), but the only screen is `/operations/assistenten/tagesvorschlag` (desktop, coordinators); a `/team` entry is PLANNED only if the PO asks (ADR-151 deviation 6). The switch on `/team/tagesplan` shows only "eingeschaltet am <Datum>". **Effect:** the team owns the switch (PLAN3-10), but the numbers that say whether the assistant saves it work (unchanged share, "kein Vorschlag" share by reason, confirm actions per plan, continuity before/after) reach only the hierarchy. A team that cannot see that half its visits get "kein Vorschlag (keine Bezugsperson)" cannot fix the care-graph gap itself (AUT-25), and the decision to keep or drop the assistant moves to Operations. No new step for a nurse today; the gap is in team autonomy | **monitor, no new read, no new act:** one information line under the switch on `/team/tagesplan`, from the same reader and the same suppression: "Diesen Monat: <n> Tagesvorschläge · <x> % unverändert bestätigt · <y> % ohne Vorschlag", plus the largest "kein Vorschlag" reason when it is one the team can fix (no primary nurse set); a link to the month's cells. Suppressed values read as on Operations; no colour, no target, no comparison between teams | L | stage 0; `po` (scope, PLAN3-7 screen line), `uxa` (form); no `cra` (no clinical rule), no `lca` (same reader, team level) | share of teams with the assistant on that change a "kein Vorschlag" cause (primary nurse set) within the month; switch-offs explained by the team's own numbers. Never per person | medium | report only |

### 2 Briefs, plans and packages reviewed

- **#880 PLAN3 part (b) slice 1 (ADR-147):** one route per team and day, every line unticked, no "select all", the button names its count, refused lines keep their reason and stay "Noch offen". Meets §8 "no accept-all" and "named confirmer" on screen; no step or field added beyond the brief. Supported. ADR-147 deviation 3 ("Ablehnen" on a day-plan line): supported; it is one act the team needs when a proposal is wrong, and its result is recorded. **CGR-138** (`cra`: a decided line without a responsible member loses "Einsatz öffnen"): supported; keeping the link removes a search for the uncovered visit and adds no act.
- **#882 PLAN3-12 (ADR-148):** count from the existing reader, no badge, no colour (H-20). Supported. Deviation 4 (the count includes proposals of past visits until AIG1-C4 #814 merges) inflates a number shown to the team every day; one more reason to merge #814 before PLAN3 is accepted, not a new finding.
- **#883 PLAN3-11 (ADR-149):** the team finds its own look-back lines, keyed on the stop, not on the agent's state. **This is part (2) of AUT-30 (#793) for the team side** (the entry survives an agent switched off after its stop); the Operations side stays with AIG1-C5 (#814). Supported.
- **#885 PLAN3-13 (ADR-150):** six counts per stop and team, no person column, no target. Supported. **AUT-31:** the median lead time from proposal to visit start is built; the expired share waits for #814 (ADR-150 deviation 2). Deviation 5 (no small-team suppression on counts of values): supported as built; these are counts of records, not of people.
- **#886 PLAN3-7 (ADR-151):** **AUT-25 remedy met on the head:** the "kein Vorschlag" count and share per team and month, split by the four stored PLAN3-2 limits, suppression as AIG1-7. Closes on merge. Deviation 4 (confirm-time refusals are not stored, so not counted): this is the same gap as AUT-51; AUT-51's remedy (a fresh request closes the refused line with a recorded outcome) also makes the refusal countable without a new table. AUT-52 above.
- **CGR-140 (`cra`, rejected lines in neither share):** I support **option (a)**, a third share "Abgelehnt". A correction ("right visit, other member") and a rejection ("this proposal is not wanted") tell the team and the PO different things: a high correction share points at the member rule, a high rejection share at the proposal itself or at visits the team plans differently. Merged into one balancing share the two cannot be told apart, and §8 asks for the rate per agent and field. Test as `cra` wrote it: one rejected line in pgTAP 114, the three shares sum to 100 % of `decided_lines` (±0.1).
- **#888 CGR-139 (ADR-152):** one label function for every picker, no new read. Supported; it removes a wrong pick without adding an act.
- **`uxa` UXR-102 to UXR-112:** wording and placement; UXR-110 (weekday with the date) lowers the chance of planning the wrong day at no cost. No finding.

### 3 AI readiness of delivered items (§8)

PLAN3 on the stack heads (#880 to #888, not merged): **suggestion ledger** and **provenance per value** unchanged from #876; **named confirmer** shown as the line's decision state only, never a per-person view (ADR-147 decision 4, pgTAP 114 catalogue check: no confirmer column in the measures); **no accept-all** on screen (unticked list, no "select all"); **correction rate per agent and field** built per team and month (PLAN3-7), rejected lines missing from both shares (CGR-140); **stop rule** with a team entry for its look-back (PLAN3-11) and its measure (PLAN3-13); **evaluation on synthetic data** (Testorganisation G, pgTAP 110 to 114). Missing, as before: the AUT-51 test (a fresh request after a line refused at confirm); the expired share (AUT-31, #814).

### 4 Stage tracking (D-35)

Stage 0 only. Stage-1 entry conditions unchanged since review 31: no AI provider decision (owner), no stage-1 package; the stage-0 governance layer (AIG1 #814, AIR1 #828) still unmerged. PLAN3 adds no stage-1 condition.

### 5 Findings: state changes and closed

- **AUT-25 (medium):** remedy met on #886 `d5411ee` (stored reasons); closes when #886 merges unchanged. The refusal part moves to AUT-51.
- **AUT-31 (low):** lead time met on #885 `f37180d`; the expired share stays open until #814 merges.
- **AUT-30 (high, #793):** team-side entry met on #883 (keyed on the stop); Operations side open (#814).
- **AUT-51 (medium):** unchanged, still not decided; ADR-148 deviation 1 confirms the refused line keeps counting in "Vorschläge (<n>)", and ADR-151 deviation 4 shows it is not counted as a refusal.
- Open, unchanged: AUT-49, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-34, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28 (P-38).

### 6 To the PO

1. AUT-52: a line under the team switch from the reader the team already may read (scope and `uxa` form).
2. CGR-140: option (a), a separate "Abgelehnt" share.
3. AUT-51 still open before PLAN3 is accepted; its remedy also gives ADR-151 deviation 4 its refusal count.
4. #814 (AIG1-C4/-C5) is the dependency of ADR-147 dev. 2, ADR-148 dev. 4, ADR-150 dev. 2 and AUT-30; merge order is the PO's.

---

## 2026-11-05 20:20 CET · aia review 31: `eng` #876 (PLAN3-14 built, head `566a7dd`), PO #877 (16:30), `cra` #879 (17:00, 17:30, merged) and `uxa` #850 (19:50) read; PLAN3-14 build meets the stage-0 controls; AUT-51 now shown in the code (a line refused at confirm for `overlap` stays undecided and blocks a fresh proposal for that team and day); CGR-137 (display-only member overlap on hand assignment) supported with one condition; no new finding

**Read:** `recovery/main` at `eccf30c` (since review 30: PO #874 and #877, `cra` #879 merged; docs only, `git diff 8e7d392 eccf30c -- src supabase tests e2e` empty). Open, read on their branches: `eng` **#876** (head `566a7dd`, migrations 0109 and 0110, pgTAP 110 and 111, ADR-146); `uxa` **#850** (19:50: wording for the `overlap` refusal and the other-team day-load line, CGR-137 notice text PROPOSED, UXR-98 to UXR-101). No other new or changed brief; open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database; CI states are read from the GitHub API only. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

None.

### 2 Briefs, plans and packages reviewed

- **PLAN3-14 build (#876, IMPLEMENTED on the PR head, not merged):** (1) busy time over every visit of the member in any team through a definer function granted to nobody, returning only `overlap`; (2) confirm re-checks overlap for day-plan lines and refuses the line, the visit stays unassigned and the other ticked lines are set; day load gets a yes/no `other_team_visits`. All deterministic rules; no step, field, approval or role added for a nurse. Supported.
- **ADR-146 deviation 1 (corrections also checked for overlap):** supported; a correction is a confirm with another member, the same safety reason holds, no added act.
- **ADR-146 deviation 3 (reason order, `overlap` before qualification/contract/absence at confirm):** no automation effect; the reason shown is one, the act is the same. Clinical ordering is `cra`'s call.
- **CGR-137 (`cra` 17:00, ADR-146 deviation 2): display-only member-overlap fact on hand assignment, never a refusal:** supported as a rule that moves a double booking from the road to the moment of assignment, with no added act. **Condition:** it stays a line of information on the existing assignment act, as `uxa` 19:50 proposes ("<Anzeigename> hat zu dieser Zeit schon einen Einsatz."); no "trotzdem zuteilen" confirmation tap and no reason field. A tap on every overlap would add an act on each cover day, when overlaps are frequent and often intended (two short visits back to back). If the Clinical Owner later wants a confirmation, it is a clinical control and not challenged; its form then follows the AIG1 pattern (one act, recorded).
- **PO #877 (merge order within a run: Engineering first, role docs next, own PR last):** a process rule that reduces the conflict cascade one merge causes; no added act for a team. Supported. AUT-49 (one journal file per entry) would make the order irrelevant.
- **`uxa` 19:50 wordings:** information lines only, no act; no finding.

### 3 AI readiness of delivered items (§8)

PLAN3 agent on the #876 head, changes only: confirm now re-checks overlap across teams (§8 "every line re-checked at confirm", met for the new limit); provenance unchanged (only `overlap`, no other team's data in the ledger or the readers, pgTAP 111 asserts no other-team column or id). Missing, as before: a test that a fresh request succeeds after a line was refused at confirm (AUT-51).

### 4 Findings: state changes and closed

- **AUT-51 (medium), evidence now in code, not decided:** in 0109 `propose_day_plan` refuses while any earlier line of that team and day has no `ai_confirmations` row and its visit is still `planned`, unsuspended and uncovered. A confirm refused for `overlap` writes no confirmation and leaves the visit unassigned (0110 `aig1_apply` returns `overlap`), so exactly this line keeps the next proposal blocked until someone rejects or corrects it by hand. pgTAP 111 has no case for a fresh request after such a refusal. Proposal unchanged (review 29): a new request closes the earlier undecided lines with a recorded outcome and lists each open visit once; test: a line refused at confirm for `overlap`, then a fresh request for the same team and day succeeds and lists the visit once. Comment left on #876 (it supersedes #872, where AUT-51 was first noted).
- Open, unchanged: AUT-49, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-30 (#793), AUT-34, AUT-25, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)

No change. Stage 0 in force; stage 1 entry conditions unchanged (real data blocked, D-1; adviser not named; G-3 open).

### 6 Waiting for the PO

- **AUT-51 (medium):** decide ADR-145 deviation 3 before PLAN3 part (b); the #876 code shows the block.
- **CGR-137 brief row:** keep the notice as information without a confirmation tap (condition in §2).
- AUT-49 and AUT-50; AUT-44, AUT-45; AUT-46 only under the owner's variant; AUT-42, AUT-43, AUT-41, AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments

- No issue opened (no `high` finding). One comment on #876 (AUT-51 evidence, CGR-137 condition).

---

## 2026-11-05 15:05 CET · aia review 30: PO #874 (14:50) read: PLAN3-14 (`cra` CGR-136 decided by the PO: overlap across teams and again at confirm) supported, no added act; it makes AUT-51 more likely to bite (a confirm-time `overlap` refusal is exactly when a team needs a fresh proposal); scheduled PO merge refused at 14:46, escalated by the PO to the owner, supported; no new finding

**Read:** `recovery/main` at `8e7d392` (unchanged since review 29). Open, read on its branch: PO **#874** (head `ccac0f4`: `briefs/PLAN3.md` PLAN3-14 and PO note, `PO_MERGE_PROCESS.md` §0a, `OWNER_AGENDA.md` bundle 1 "Merge in scheduled runs", `NEXT_CAPABILITY.md` *Active now*, `JOURNAL.md`). Heads of #872 (`c382272`) and #873 (`c09169d`) unchanged since review 29. No other new or changed brief; open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

None.

### 2 Briefs, plans and packages reviewed

- **PLAN3-14 (PO 14:50, brief changed, PLANNED for part (b)):** supported. Both parts are deterministic rules inside the definer function: (1) the overlap limit counts every visit the member is responsible for in any team and returns only `overlap`; (2) confirm re-runs the test and refuses the line. No step, approval, field or role is added for a nurse; the day-load line "weitere Einsätze in anderen Teams" is information, not an act, and carries no count, client or time (as the PO wrote; keep it so, also for `uxa`'s wording). It removes a double booking that would otherwise be found on the road (H-01, H-20). Patient-care benefit shown; nothing to challenge.
- **Scheduled PO merge refused (`PO_MERGE_PROCESS.md` §0a 14:46, IMPLEMENTED fact as stated by the PO):** the PO's ask to the owner (bundle 1 "Merge in scheduled runs") is supported; it is a setting only the owner can change, not a new control. Until answered, merges happen only in attended PO sessions, so every merge-ready PR waits on the owner's time: the AUT-48 pattern in a narrower form. Not a new finding (the PO has escalated it; no duplicate). AUT-49 and AUT-50 matter more under it: each attended session can then merge the whole merge-ready list without a `JOURNAL.md` conflict after each merge.

### 3 AI readiness of delivered items (§8)

No delivered item changed since review 29. PLAN3-14 adds one control to the PLAN3 agent at confirm (re-check), consistent with §8 "every line re-checked at confirm"; no change to the §8 table of review 29.

### 4 Findings: state changes and closed

- **AUT-51 (medium), strengthened, not decided:** PLAN3-14 (2) refuses a confirm as `overlap` and returns the visit to the uncovered list. That is the moment a team most needs a new proposal for that visit; under ADR-145 deviation 3 the new request is refused while other lines of the earlier proposal stay undecided. The proposal of review 29 (a new request closes the earlier undecided lines with a recorded outcome) covers this case too; decide it together with PLAN3-14 for part (b). Test to add then: a line refused at confirm for `overlap`, then a fresh request for the same team and day succeeds and lists the visit once.
- AUT-48 stays closed (the owner decided the path; the remaining block is a setting the PO escalated).
- Open, unchanged: AUT-49, AUT-50, AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-30 (#793), AUT-34, AUT-25, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)

No change. Stage 0 in force; stage 1 entry conditions unchanged (real data blocked, D-1; adviser not named; G-3 open).

### 6 Waiting for the PO

- **AUT-51 (medium):** decide ADR-145 deviation 3 together with PLAN3-14 before part (b).
- AUT-49 and AUT-50 (changes D and E); AUT-44, AUT-45; AUT-46 only under the owner's variant; AUT-42, AUT-43, AUT-41, AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments

- No issue opened (no `high` finding). No new comment: AUT-51 is already on #872 (review 29); the PLAN3-14 interplay is recorded here for the PO.

---

## 2026-11-05 14:20 CET · aia review 29: owner merge decision read (the PO merges, seven conditions, `PO_MERGE_PROCESS.md` IN FORCE; #799, #833, #838 merged): AUT-48 closed; AUT-49 and AUT-50 adopted into the PO's plan (PLANNED); PLAN3 part (a) (#872, first agent beyond the synthetic test agent) checked against §8: every stage-0 control present in the database; `cra` #873 CGR-136 supported; new AUT-51 (medium: a sick call in the morning cannot get a fresh day proposal until every undecided line of the earlier one is decided by hand)

**Read:** `recovery/main` at `8e7d392` (since review 28: PO #868 and #871 merged, carrying the owner's merge decision, `PO_MERGE_PROCESS.md`, `COORDINATION.md` rule 4; PO merges of #799 UX2-1/UX2-31 shell `c8d2db7`, #833 `IMPLEMENTATION_SEQUENCE.md` `0e79e5f`, #838 D-2 hosting support `847bd4a`). Open, read on their branches: Engineering **#872** (PLAN3 part (a), head `c382272`, ADR-145, migration 0109, pgTAP 110; the four check runs on that head show `success` on GitHub, I ran nothing) and `cra` **#873** (13:30: #872 clinical gate clear, CGR-136, CGR-135 closed, governance chain rebuilt). My #869 continued (base merged in, journal conflict resolved keeping every entry). No new or changed brief (PLAN3 approved and unchanged; FAM1 draft unchanged). Open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10. Absence and short-notice cover stays among its top bottlenecks (estimate, review 18), which is why AUT-51 is rated `medium`.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-51 | Planning after a short-notice change (sick call, new absence, a visit added): team member re-asks for the day proposal (PLAN3, team) | IMPLEMENTED on #872, not merged (ADR-145 decision 6, deviation 3): `propose_day_plan` refuses with `open_proposal` while an earlier proposal of the same team and day still has undecided lines of open visits. A member who records a colleague's absence at 06:30 and wants a fresh proposal must first decide or reject each undecided line by hand, although the earlier lines were computed before the absence and are partly invalid. The refusal is not in the brief. Benefit stated by `eng`: `open_suggestions` and the PLAN3-12 count would otherwise list two proposals for one visit. That benefit is real (H-20: no double list that invites a bulk confirm), but the form makes the busiest moment of the day the one with the most taps. The safety does not depend on it: every line is re-checked at confirm (J3, ABS1), so a stale line is refused anyway, only later | **Rule (same single list, no manual clean-up):** a new request for the same team and day closes the earlier proposal's undecided lines with a recorded ledger outcome before writing the new lines (they leave `/team/vorschlaege` and the count; nothing is deleted; lines already confirmed stay). Whether AIG1-C4's expiry outcome (#814) can carry this or a new outcome is needed: UNKNOWN, `eng` decides how. Until built, the refusal text names the earlier proposal and offers "Ältere offene Zeilen verwerfen und neu vorschlagen" as one act (the act exists already as reject; this only bundles it with the request). No new role, approval or field; the per-line confirmation and the J3 re-check stay | L | Stage 0; gate PO (deviation 3 is its call), `uxa` (refusal wording), `cra` only if the new outcome is read by a safety path (UNKNOWN; none known) | per team and month: share of day-plan requests refused `open_proposal`; median minutes from a recorded absence to the last confirmed line of that day (PLAN3-7 already counts confirm actions per day plan) | medium | — (report; comment on #872) |

Severity `medium`, not `high`: a care-side benefit (one list per visit) is shown; the finding is the form, and it only matters once part (b) exposes it to teams.

### 2 Briefs, plans and packages reviewed

- **Owner merge decision and `PO_MERGE_PROCESS.md` (IN FORCE):** the seven conditions are the owner's controls and are not challenged. Their form: §4 condition 2 takes in AUT-50 as a hand check, and §7 specifies `scripts/po-merge-gate.mjs` with the fixture "a cleared head followed by a code push"; together with change E (AUT-49) that is the deterministic form I proposed. The §6 merge record comment is today written by hand per PR; once §7 exists it should be the script's output pasted, not a second write-up (folded into AUT-50, no new finding). Role docs PRs: merged by the PO on conditions 1 and 5 plus the CGR-135 scope rule; I therefore no longer self-merge, my task text notwithstanding (owner decision governs; the PO merges #869).
- **PLAN3 part (a), #872:** removes the daily hand assignment of open visits for teams that switch it on, using facts the graph already holds (primary nurse, deputy, visits known, absences, qualification). Supported in substance. Two observations without a finding: (i) "visits known" counts performed visits (first `started` event), which is the continuity measure J6 already uses; consistent. (ii) `day_plan_load` shows minutes per member for the team's own planning, with no maximum; it is a load view for the day, not a person's performance, and is readable only by the team's members; no per-person history or ranking is built. Keep it that way in part (b) (no month view per person).
- **CGR-136 (`cra` 13:30, advisory S2):** supported. Checking the overlap against the member's own visits of every team (output stays "überschneidet", no detail) and again at confirm time is a deterministic rule with no act; it removes a double booking a nurse would otherwise discover on the road.
- **#799 shell merged:** one navigation for every protected route; no act added for a nurse; no finding.
- **D-2 hosting support (#838):** no AI provider, no automation step; no finding.

### 3 AI readiness of delivered items (§8)

PLAN3 part (a) (#872, head `c382272`, not merged), level-L rule agent `plan3_day_proposal`:

| Control (§8) | State on the head | Evidence |
|---|---|---|
| Suggestion ledger | present | one `ai_suggestions` row per line, one proposal id, input references visit, case, team (ADR-145 6) |
| Provenance per value | present | `responsible_user_id` becomes record content only through `confirm_suggestion(s)`; reason and limit kept on `day_plan_lines` |
| Named confirmer | present | AIG1 confirmation rows; `day_plan` returns no confirmer (no per-person view of confirmations) |
| No accept-all on listed fields | present | ticked-list bulk confirm only for class `schedule` (CGR-78, AIG1-5); no "alle übernehmen" without the list (PLAN3-5) |
| "Not found" explicit | present | `not_found` with the limit the closest candidate failed |
| Correction rate per agent and field, per team | generic only | AIG1-7 readers; the PLAN3-7 measures are PLANNED (part b) |
| Stop rule | present | refusal `agent_stopped` after `aig1_check`, no ledger row |
| Evaluation on synthetic data | present | fixture `aig1_eval_plan3_day_proposal`, bar 100, pure ranking `private.plan3_choose` |
| Team decides use | present | `set_team_day_proposal`, actor only in the audit row (PLAN3-10) |
| Writes nothing to the record | present | pgTAP hash of `care_visits` before and after |

Readiness at stage 0: met at database level (PLANNED for teams until part (b) and the merge). Gaps: the PLAN3-7/-13 measures (part b) and AIG1-C4/-C5 (#814) before part (b), as ADR-145 says.

### 4 Findings: state changes and closed

- **AUT-48 closed** with evidence: the owner decided the merge path (PO merges under seven conditions, `PO_MERGE_PROCESS.md` §0, §0a); the PO merged #799 (`c8d2db7`), #833 (`0e79e5f`) and #838 (`847bd4a`) on 2026-11-05 12:00; role docs PRs are covered (§4 stop rules). The remaining delay is the serial conflict queue (AUT-49), not a missing hand-off.
- **AUT-49:** adopted as direction (PO 10:56) and placed as change E of `PO_MERGE_PROCESS.md`, built with D; PLANNED. Stays open until built. The PO's 12:00 run found 14 Engineering PRs conflicting with `recovery/main` after three merges: the same pattern.
- **AUT-50:** adopted in substance (§4 condition 2, §7 fixture), PLANNED; `cra` 13:30 clarifies the comparison after a base merge (the PR's own change, not the plain head diff), which the script must implement. Stays open until §7 is built.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (both now conflict, PO 12:00).
- AUT-25: PLAN3-7 carries the "kein Vorschlag" share (part b); unchanged until built.
- Open, unchanged: AUT-46, AUT-47, AUT-44, AUT-45, AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: AUT-48.

### 5 Stage tracking (D-35 stages; changes only)

- Stage 0 entry evidence widened: the first agent beyond the synthetic test agent exists at database level (PLAN3, rule, L) with every §8 control (table above), not merged. Stage 1 still not opened; real data blocked (D-1); adviser not named; G-3 (named human approves clinical or billing migrations before real data) still open, restated by `cra` 13:30.

### 6 Waiting for the PO

- **AUT-51 (medium):** decide ADR-145 deviation 3 (refuse vs. close the earlier undecided lines) before part (b).
- AUT-49 and AUT-50 in D/E; AUT-44, AUT-45; AUT-46 only under the owner's variant; CGR-136 into PLAN3 part (b).
- AUT-42, AUT-43, AUT-41, AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments

- No issue opened (no `high` finding). One comment on #872 (AUT-51, §8 readiness, CGR-136 supported). Comment on #861 not needed (closed by the owner's decision).

---

## 2026-11-05 10:15 CET · aia review 28: `cra` #870 (09:30) read: option C supported by `cra` at stage 0 with three conditions; condition (2) and (3) supported (safety controls, not challenged); condition (1) supported in substance, new AUT-50 (low: make the head-diff check a rule instead of a note written before each merge); CGR-135 role-scope check supported (it turns "touches only my files" from a claim into a rule); AUT-48 widened: my own self-merge (#869) is refused by the same permission check, so docs PRs of every role queue too

**Read:** `recovery/main` at `9e3b998` (unchanged since review 27; nothing merged, no code, brief or decision). Continued on my open PR #869 (self-merge refused at 08:20 by the session's permission check "merge without review"; not worked around). Read on its branch: `cra` **#870** (09:30, `9fc0636`: CGR-134 sentence 5 met at document level, CGR-132 reverse line confirmed, option C input with three conditions, new CGR-135 on PO #868 carrying the #799 code) and the `cra` comments on #861, #868 and #850 (08:32 UTC). `uxa` #850, `lca` #860 and PO #868 heads unchanged since review 27. No new or changed brief (FAM1 draft unchanged). Open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-50 | Merge of a code PR under option C (`eng`), gate validity (`cra`) | PLANNED (`cra` 09:30, #870, condition 1, only if the owner adopts C): before each merge `eng` writes in the PR that `git diff <head cra cleared> <merge head> -- src supabase tests e2e` is empty; otherwise the merge waits for the next `cra` run. The cleared head is today only a SHA in a markdown table (`CLINICAL_GOVERNANCE.md` *Gate status*). With 17 queued PRs and a base merge before almost every merge (AUT-49), that is one hand-written note per merge, and a note can be skipped or copied wrong. The control itself (the gate covers the code being merged) has a safety benefit and is not challenged; its form adds a manual step | **Rule (same control, no note):** `cra` records each cleared head in one machine-readable line per PR (e.g. `cra-gate: #<PR> <sha> clear`) in its gate file; a small check (in `scripts/agents-check.mjs` or a CI job, `eng` decides how) computes the same path-scoped diff against the merge head and fails when it is non-empty or when the PR has no `clear` line. Condition (2) folds into the same line: a finding `cra` wants before merge is written as `blocking` there, so the check reads one field, not two categories. No new role, approval or field for a person; the `cra` judgement and the waiting rule on a code change stay | L (repository process, no product change) | Stage 0; gate `cra` (line format), `eng` (check), PO (places it); owner only as part of option C | merges whose code differs from the cleared head (target 0); hand-written gate notes per merge (target 0) | low | — (report) |

Severity `low`: the step has a stated safety benefit; only its form is leaner, and it exists only if the owner adopts C.

### 2 Briefs, plans and packages reviewed

- **Option C, `cra` conditions (#870, #861):** (2) "before merge" findings count as blocking: a safety control, supported (AUT-50 only proposes one label for it). (3) C is a stage-0 merge rule; before real data a named human approves each migration touching clinical or billing logic (G-3): a legal and safety duty before gate C, not administration; supported, and it is scoped to those migrations only, which is the lean form. (1) supported in substance, form in AUT-50.
- **CGR-135 (PO #868 carries the #799 code; role-scope check):** supported. The remedy (a check that fails a `po/`, `gov/`, `aia/`, `lca/`, `ux/` PR whose diff touches `src/`, `supabase/`, `tests/` or `e2e/`) replaces a trust claim with a deterministic rule and adds no act. It is also the precondition for letting role docs PRs merge without a human look at all: the permission check refused my self-merge as "merge without review", and a verified docs-only scope is the review such a merge needs. Recorded under AUT-48 below; the decision stays with the PO and the owner.
- **CGR-134 sentence 5, CGR-132 reverse line (`cra` confirmed):** wording; no act added; no finding.
- **AUT-49:** `cra` no objection, condition that entries stay never edited and the check covers the governance review files' names. I accept it; it adds no act.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking delivered since review 27. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged, open, held by the merge path (AUT-48).

### 4 Findings: state changes and closed
- **AUT-48:** widened (IMPLEMENTED facts, GitHub): the permission check that refused the PO's option A also refused my own docs-only self-merge (#869, 08:20). Role docs PRs therefore queue as well (`aia` #869, `cra` #855 … #870, `lca` #860, `uxa` #850, PO #868 open), each later conflicting on `JOURNAL.md` (AUT-49). Option C as escalated covers Engineering PRs only; the role docs PRs need the same answer (a merge rule for PRs whose diff a check proves is the role's own files, CGR-135). With the owner via the PO; stays open.
- AUT-49: `cra` no objection (condition accepted); waiting for the PO.
- AUT-46, AUT-47, AUT-44, AUT-45: unchanged.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge.
- Open, unchanged: AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)
- No change. Stage 0 only in force; stage 1 not opened; real data blocked (D-1); adviser not named. `cra` condition (3) restates that G-3 (human approval of clinical and billing migrations) is an entry condition before real data; already listed for gate C.

### 6 Waiting for the PO
- **AUT-48 (widened):** the merge path for role docs PRs as well as Engineering PRs; CGR-135 check as its precondition.
- **AUT-50 (low):** the gate line and check, if the owner adopts C.
- AUT-49; AUT-44, AUT-45; AUT-46 only under the owner's variant; CGR-131 to CGR-135.
- AUT-42, AUT-43, AUT-41, AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on #861 (AUT-50, AUT-48 widened to role docs PRs, CGR-135 supported). No comment on #870, #868 or #850.

---

## 2026-11-05 08:20 CET · aia review 27: PO #868 (06:05, #861 escalated to the owner as option C), `cra` #867 (05:30, CGR-134, CGR-132 both pairs, CGR-110 recurred), `lca` #860 (04:45) and `uxa` #850 (03:50, 07:50) read; AUT-48 supported in the PO's option C form; CGR-132 (both pairs), CGR-134 and the `lca` AUT-46 addition supported (no added act); new AUT-49 (medium: the single shared `JOURNAL.md` forced 109 conflict merges on agent branches in seven days)

**Read:** `recovery/main` at `9e3b998` (my #866 only since review 26; no code, brief or decision merged). Open, read on their branches:
- PO **#868** (06:05, `52d1803`: option A tried and refused by the PO routine's permission check; #861 escalated to the owner in `OWNER_AGENDA.md` bundle 1 as **option C**: Engineering merges its own PRs once CI is green and `cra` has no blocking finding, the PO accepts after the merge);
- `cra` **#867** (05:30: CGR-133 met at document level, CGR-132 widened to the reverse pair, new CGR-134, CGR-110 recurred in pgTAP 064, AUT-48 supported with one condition: the hand-off shows the `cra` gate status);
- `lca` **#860** (04:45: client information confirmed against *informed*, reverse pair to be refused (ZGB Art. 19c), AUT-46 addition "hat die Information oben erhalten", real relatives still need the legal adviser);
- `uxa` **#850** (03:50, 07:50: CGR-133 constant, CGR-134 end-cause sentence, reverse-pair refusal line; noted that #868 carries the #799 shell code, `819c5c6`).

No new or changed brief (FAM1 draft unchanged). Open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. The counts in AUT-49 are from `git log --all --merges` on the clone (IMPLEMENTED facts about the repository, not about care). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-49 | Coordination record of every role: the one shared `docs/agents/JOURNAL.md` (all roles; `eng` also on `IMPLEMENTATION_STATUS.md` and `docs/engineering/DECISIONS.md`) | IMPLEMENTED (repository history, 2026-10-29 to 2026-11-05): 112 merge commits "Merge recovery/main into <agent branch>", 109 of them naming a journal conflict ("every entry kept, newest first"). Every merge into `recovery/main` puts every other open branch in conflict on the same top lines; PO #868 found the same for Engineering PRs (only the first of 17 merges cleanly). Each resolution is a run spent on rework with no change in content, and it delays every delivery, FAM1's inputs included (PO 06:05: FAM1 approval waits for `lca`/`cra` inputs to reach `recovery/main`). No care benefit: the journal's value is the record, not its being one file | **Eliminate the conflict (keep the record):** one file per entry, `docs/agents/journal/<YYYY-MM-DD-HHMM>-<role>.md`, never edited after merge; "newest first" becomes the sort of the file names; `scripts/agents-check.mjs` checks name, role and date format. `JOURNAL.md` keeps the history up to the cut-over and a pointer. Same pattern for the `eng` status and decision rows if `eng` agrees (UNKNOWN; `eng` decides how). No new role, approval or field; the PO acceptance and the `cra` gate are unchanged | L (repository process, no product change) | Stage 0; gate PO (README *Journal* rule), `eng` (check script); owner only if the scheduled task texts must change (they name `JOURNAL.md`) | base-merges naming a journal conflict per week across agent branches (target 0); share of green PRs that merge without a base-merge | medium | — (report; noted on #861) |

Severity `medium`, not `high`: the cost is delivery latency and repeated rework, not an added care-side step, and nobody recommended the single file as a control.

### 2 Briefs, plans and packages reviewed

- **#861 merge path, PO option C (owner agenda bundle 1):** supported; it is the AUT-48 proposal in a leaner form. It removes the waiting step (a pre-merge PO look nobody can trigger or perform) and keeps both controls that carry a safety benefit: the `cra` gate stays before the merge (as merge condition, which also meets the `cra` 05:30 condition), the PO acceptance stays after it. At stage 0 nothing reaches a real client (D-1), so acceptance after merge loses no patient protection. My option B (a watcher hand-off) is not needed under C; the existing PO step C hand-off on `in-review` covers acceptance. Not challenged; the decision is the owner's. Without AUT-49, option C still means 17 sequential merges each followed by a conflict resolution by `eng`.
- **CGR-132 widened (refuse the reverse pair, `lca` ZGB Art. 19c):** a second deterministic refusal on the same two answers; no question or act added. Supported.
- **CGR-134 (`uxa` 07:50 end-cause sentence):** one informing sentence, read by the client; no act for the RN or the relative. Supported. It also states that the view does not restart by itself after a pause, which spares the team a later "why can I see nothing" call.
- **`lca` AUT-46 addition ("hat die Information oben erhalten"):** extends the one statement above the save button; still no checkbox and no extra act. Supported.
- **`lca` "Datenschutz" link on F-01/F-02, session length as a DSV Art. 3 measure:** no team act. The session length affects relatives' re-sign-ins, not nurse time; no finding.
- **CGR-110 recurrence (pgTAP lock missing in ten files):** a red re-run costs a cycle under any merge path; supported as stated by `cra` (lock in every file calling `evaluate_signals`).

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking delivered since review 26. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged, open, held by the merge path (AUT-48).

### 4 Findings: state changes and closed
- **AUT-48:** escalated by the PO to the owner as option C (IMPLEMENTED escalation, #868 open); I support C. Stays open until the merge path works; then closes with the first merged Engineering PR.
- **AUT-46:** form widened by the `lca` addition, confirmed by `cra`; still only under the owner's variant; stays open until FAM1 carries it.
- AUT-47, AUT-44, AUT-45: unchanged.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge.
- Open, unchanged: AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)
- No change. Stage 0 only in force; stage 1 not opened; real data blocked (D-1); adviser not named.

### 6 Waiting for the PO
- **AUT-49 (medium):** one journal file per entry; ask `eng` about the status and decision rows.
- **AUT-48:** with the owner (option C); nothing for me until answered.
- AUT-44, AUT-45; AUT-46 (form with the `lca` addition) only under the owner's variant; CGR-131 to CGR-134 into FAM1.
- AUT-42, AUT-43, AUT-41, AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on #861 (AUT-48 supports option C; AUT-49 as the cause of the serial conflicts). No PR comment on #867, #860, #850 or #868.

---

## 2026-11-05 02:25 CET · aia review 26: `cra` #864 (21:30) and #865 (01:30), `uxa` #850 (23:50) read; AUT-46 form placed by `uxa` and confirmed by `cra` at document level (PLANNED, only under the owner's variant); AUT-47 consistent across both gates; CGR-131 to CGR-133 supported (one constant, no added act); new AUT-48 (medium: 17 green Engineering PRs wait for a merge hand-off nobody receives, issue #861)

**Read:** `recovery/main` at `a236c10` (my #863 only since review 25; no code, brief or decision merged). Open, read on their branches:
- `cra` **#864** (21:30: CGR-131, CGR-132; AUT-46 supported with conditions (i) save is the RN's attestation, (ii) capacity question required, unpreselected, "Nein" refuses; AUT-47 supported in form);
- `uxa` **#850** (23:50, `2cf39ee`: CGR-131 status list from the F-02 constant, CGR-132 refusal line, AUT-46 form with the statement directly above the save button, AUT-47 no screen);
- `cra` **#865** (01:30: `uxa` parts of CGR-131/-132 met at document level, AUT-46 placement meets (i) and (ii); new CGR-133, one explanation constant for the neutral state without "noch");
- issue **#861** (`eng` 17:15, for `po`: 17 green Engineering PRs open, no merge hand-off; not read in review 25, read now). No new or changed brief (FAM1 draft unchanged since #856). Open `automation` issues: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-48 | Delivery of built items to teams: hand-off from a green Engineering PR to the PO merge (`eng`, `po`) | IMPLEMENTED (issue #861, `eng` 17:15): 17 Engineering PRs are green and mergeable, the oldest (#799) since 2026-11-03 00:21; the engineering task forbids self-merge, the `in-review` row lives only on the PR branch, and the watcher (`plan.mjs`) opens a `po:<ID>` hand-off only for `ready-for-review`/`delivered` on `recovery/main`. So the acceptance step exists but no one is told it is due. Held items include AUT-30 (#814) and AUT-34 (#841), each returning nurse time once teams use them (estimates in reviews 18-21, not measured). Each merge elsewhere re-opens `JOURNAL.md` conflicts on all 17 branches: repeated rework with no care benefit | **Rule (eliminate the waiting, keep the review):** the PO acceptance review is a quality control and is not challenged; its trigger is. A deterministic rule creates the hand-off from facts already in GitHub: every open Engineering PR that is green and sets a row to `in-review` gets one `po:<ID>` merge-review hand-off (`eng` option B, unit test first), reviewed in *Active now* order. Until it is built, the PO run lists green `feature/`/`feat/`/`fix/` PRs itself (option A). No new role, approval or field; `COORDINATION.md` rule 4 made to match whichever instruction stands (owner/PO, not me) | L | Stage 0; gate PO (rule 4 and option); owner only if the task instruction is changed | days from green CI to merge per Engineering PR (median over the pilot repository, never per person); count of green PRs older than 24 h, target 0 | medium | #861 (comment) |

Severity `medium`, not `high`: the step that blocks (PO acceptance) has a stated benefit (review before delivery); the finding is the missing trigger, a leaner equal-safety form exists, and `eng` already proposed it.

### 2 Briefs, plans and packages reviewed

- **CGR-131 (one status constant for F-02 and the client information) and CGR-133 (one explanation constant, without "noch"):** supported. Both are single sources rendered in two places; they remove a future double maintenance and add no act for the RN or the client. CGR-133 is a safety wording control (H-30) and not challenged.
- **CGR-132 (refuse "gives it herself" with "cannot decide"):** a deterministic refusal on two answers already given, in the command (pgTAP) and on screen; adds no question and no act. Supported.
- **AUT-46 form (`uxa` 23:50, `cra` 01:30):** the first question disappears under the variant and is replaced by one fixed statement above the save button; no checkbox. That is the proposal, placed where `cra` (i) needs it. I accept the placement above the button instead of above the information block (review 25 wording); no act added.
- **AUT-47:** `uxa` sets no screen and no periodic prompt; a later rule goes to the team's existing exception list. Matches the proposal.
- **UXR-97, UXR-95, UXR-96:** unchanged; no finding.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking delivered since review 25. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open, both among the 17 waiting PRs (AUT-48). No change to the AI operating model controls beyond the change-log note.

### 4 Findings: state changes and closed
- **AUT-46:** form PLANNED and confirmed at document level by `uxa` and `cra`; applies only if the owner takes the "client consents herself only" variant; `lca` to confirm the sentence. Stays open until FAM1 carries it.
- **AUT-47:** consistent with both gates; waits for the Clinical Owner (after G-1) to decide whether any re-check exists (UNKNOWN). Stays open.
- **AUT-44, AUT-45:** unchanged; waiting for the PO.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (now tracked under AUT-48).
- Open, unchanged: AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)
- No change. Stage 0 only in force; stage 1 not opened; real data blocked (D-1); adviser not named.

### 6 Waiting for the PO
- **AUT-48 (medium):** choose option A now and B as the lasting rule (#861); align `COORDINATION.md` rule 4.
- AUT-44, AUT-45 (medium); AUT-46 (form as `uxa` 23:50) only under the owner's variant; CGR-131 to CGR-133 into FAM1-2/-6.
- AUT-42, AUT-43, AUT-41, AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on #861 (AUT-48). No PR comment on #864, #865 or #850: they adopt my findings and need nothing from me.

---

## 2026-11-04 20:20 CET · aia review 25: `cra` #859 (16:45) and #862 (17:30), `lca` #860 (16:55, D-40 / FAM1 re-check) and `uxa` #850 (15:50, 19:50) read; AUT-44 supported by all three gates with conditions (one act stands; the act must carry every consent field); AUT-45 no objection, `uxa` prefers (b); the two `lca` pilot variants supported as simplifications; AUT-46 (low: under "client consents herself only" the first consent question has one possible answer); AUT-47 (low: a later capacity re-check, if the Clinical Owner sets one, follows named events, never a periodic re-confirmation of every consent)

**Read:** `recovery/main` at `39a4883` (unchanged since my review 24, #858; no code, brief or decision merged since). Open, read on their branches:
- `cra` **#859** (16:45: CGR-128 current-slot "Verschoben", CGR-129 resend and one-act invitation never re-open access; AUT-44 supported with conditions, AUT-45 no clinical objection);
- `lca` **#860** (16:55, `decisions/D-40.md`: consent requirements (express, specific, informed, free, documented, revocable), representation UNKNOWN, staff name; AUT-44 legally neutral with one data-security condition; two pilot variants proposed to the PO);
- `cra` **#862** (17:30: CGR-130, capacity fact a required RN act, never a default or derived; revocation reason "Kann diese Einwilligung nicht mehr selbst geben"; both `lca` variants supported clinically);
- `uxa` **#850** (15:50: F-02 wording, UXR-95, UXR-96, AUT-44/-45 inputs; 19:50: CGR-128/-129/-130 wording, client information before consent, UXR-97).
- Open issues labelled `automation`: #793 (AUT-30) only. No new or changed brief (FAM1 unchanged since #856).

**Nothing below is a measurement.** I ran no tests and read no database. How often relatives phone a team about the schedule is still **UNKNOWN** (NAVORA records no calls; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10. Map item "phone coordination with relatives": first remedy PLANNED (FAM1 draft, not approvable until CGR-125 is in FAM1-6).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-46 | Relative consent step (FAM1-2, PROPOSED form `uxa` 19:50 for CGR-130 (1)): registered nurse | PROPOSED: two required radio questions without preselection, (1) "Gibt <Name> diese Einwilligung selbst?" and (2) "Hältst du <Name> für fähig, über diese Einwilligung selbst zu entscheiden?"; under the `lca` pilot variant "client consents herself only" a "Nein" on either refuses the save. Under that variant question (1) has exactly one answer that lets the act continue: it is a statement of the form's scope, asked as a question, on every consent. Question (2) is the capacity fact `cra` and `lca` require (a patient-protection and evidence control, **not challenged**). Effort: one extra answer per consent (small; estimate); the cost is the principle (no question with one possible outcome, the same reason as AUT-42) and a record field that carries no information | **simplify (rule):** if the owner takes the variant, the form states "Die Klientin / der Klient willigt selbst ein" as fixed text above the information block, the command stores `consent_given_by = client` as a constant (no input), and only question (2) is asked, required, with no preselection (CGR-130 (1) unchanged). If the owner does **not** take the variant, question (1) stays as `uxa` worded it, because it then has two outcomes. Equal safety: the stored record is identical; the capacity act stays explicit. Testable: under the variant the consent command has no input for who consented and rejects any value but `client` (pgTAP); the form renders one required question (vitest) | L (consent logistics; the capacity judgement itself is the RN's and the Clinical Owner's, not NAVORA's) | stage 0; gate: PO (FAM1-2), owner (variant), `cra` and `lca` confirm the stored fact is unchanged, `uxa` (form) | per team: acts and answers per consent record (target: one act, one answer); never per person | low | – |
| AUT-47 | Re-check of a relative consent after a change in the client's capacity (CGR-130 clinical question, UNKNOWN; FAM1-3): team | OPEN: `cra` 17:30 leaves to the Clinical Owner (after G-1) whether and when a team must re-check capacity for an existing consent and sets no trigger until a rule is approved (D-27); `lca` 16:55 (2)(d) marks the survival of a consent after a loss of capacity UNKNOWN. A common form for such a rule in consent processes is a periodic re-confirmation of every record (for example every n months), which would add one act per consent per period for every team, also for clients whose situation did not change. No rule exists yet; this finding names no trigger and no interval | **monitor, not re-confirm (form only):** if the Clinical Owner sets a re-check, the brief expresses it as a line on the team's existing exception list when an event the Clinical Owner names is **recorded anyway** in NAVORA (examples of where such events already live: a case pause and its resumption, ASM1 reassessment; which events count is clinical and UNKNOWN), showing the consent and the CGR-130 (3) revocation reason in one place; the line clears by either keeping the consent (one tap) or recording the revocation. No calendar re-confirmation of unaffected consents unless the Clinical Owner's rule requires it explicitly. NAVORA never ends or flags a consent from a score or diagnosis (CGR-130 (2), unchanged) | G if the trigger events are clinical (the Clinical Owner's rule decides); the line itself carries no clinical content | stage 0 (deterministic, on recorded events); gate: Clinical Owner after G-1 (rule), `cra`, PO | per team and month: re-check lines raised and cleared, median days open; acts per consent per year; never per person | low | – |

### 2 Briefs, plans and packages reviewed

- **`lca` 16:55 consent requirements (FAM1-2):** express, specific, informed, free, documented, revocable through any team member. Each is a legal duty, not administration to remove; their **form** fits one act: the information is four fixed sentences on the RN's screen (`uxa` 19:50), the evidence is the record itself, no signature on the sources read (cantonal form UNKNOWN, D-12). No challenge. The negative test "no view, list or count orders or flags clients by consent status" is also a guard against the AUT-45 measure growing into a consent-rate figure: supported; the measure stays on page views (FAM1-14) and the retrospective answer.
- **`lca` pilot variants ("client consents herself only"; "Ihr Pflegeteam" as default):** **supported as simplifications.** The first removes a representation form and a document check from the admission step; the second removes a per-person staff switch from every nurse's settings (`uxa` 19:50) and the wrong-name hazard (CGR-127 (3)). Cost for the measured gain, stated for the PO: `cra` 17:30 notes that relatives of clients with dementia most often want the schedule; under the first variant their calls stay with the team, so the pilot will under-show FAM1's gain. Reported, not a finding (legal reason; the owner decides through the PO).
- **Adviser questions 1, 2, 6-8 with D-9 in one round (`lca`):** supported; one round instead of two lowers PO and owner coordination.
- **CGR-128 (current-slot "Verschoben"):** a derivation rule on data already recorded; adds no act. Supported.
- **CGR-129 and `uxa` 19:50 resend:** self-service resend on the expired-link page, one answer sentence, no address field. It keeps "my link does not work" calls away from the team while closing the re-open path. Supported; identity verification with `lca` (UNKNOWN).
- **CGR-130 (1)-(3):** capacity a required explicit act, never derived; revocation reason by any RN. Patient-protection controls; their form is one required answer and one preset. Not challenged; AUT-46 on the neighbouring question only, AUT-47 on a later re-check.
- **UXR-97 (one client per sign-in or a label):** relative-side effort only; with AUT-44 each consent record is one act whichever option is taken. No finding.
- **UXR-95 (a)-(d):** two steps for a returning relative and a team-level count of failed sign-ins: supported (adoption decides whether calls fall).

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 24. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open. **CGR-130 (2)** (no AIG1 path writes the consent record; no function reads assessment, diagnosis or AI output to set, pre-fill, check or revoke the capacity fact) follows the AIR1 refusal pattern: supported and added to the AI operating model controls.

### 4 Findings: state changes and closed
- **AUT-44:** supported by `cra` (16:45, conditions CGR-129 (3)-(4): the one command refuses unless every FAM1-2 field and any capacity confirmation are present; nomination at admission optional, no preselected answer), by `lca` (16:55, legally neutral; the sign-in contact is taken in the consent conversation and bound to one relative; the invitation names no client before sign-in) and by `uxa` (15:50, one confirming step showing the scope sentence). I accept every condition: none adds an act. Waiting for the PO. Stays open.
- **AUT-45:** no clinical objection (`cra` 16:45); `uxa` 15:50 prefers (b) (no control on any nurse screen; if (a), paper). Waiting for the PO. Stays open.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)
- No change. Stage 0 only in force; stage 1 not opened (provider terms written, D-34); real data blocked (D-1); adviser not named. D-39 A and D-40 (no AI on the relative path) as in review 24.

### 6 Waiting for the PO
- **AUT-44 (medium)** with the `cra` and `lca` conditions; **AUT-45 (medium)**, `uxa` prefers (b).
- **AUT-46 (low)** only if the owner takes the "client consents herself only" variant; **AUT-47 (low)** only when the Clinical Owner sets a re-check rule.
- AUT-42 (ADR-143 point 9 choice), AUT-43, AUT-41 (Clinical Owner gate after G-1), AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). No PR comment: the findings concern a draft brief (FAM1) with no open PO PR; they reach the PO through this report.

---

## 2026-11-04 14:20 CET · aia review 24: owner decisions D-39 (A) and D-40 (minimal read-only relative view) and brief FAM1 draft (#856) read; FAM1 supported in substance (it removes relatives' schedule calls by rules alone); AUT-44 (medium: relative consent and invitation as one act, nominated in the intake consent conversation); AUT-45 (medium: the pilot measure asks teams to count relatives' calls); AUT-39 closed (owner decision); AUT-42 supported by `cra` and written into ADR-143 as an option

**Read:** `recovery/main` at `d31669a`:
- merged since review 23 (#854): PO **#856** (12:45: D-39 decided A; D-40 decided as a minimal option B; brief **FAM1** draft; `DELIVERY_PROGRAM.md` §0d, M7 objective now FAM1);
- open, read on their branches: `cra` **#857** (13:30: FAM1 reviewed, CGR-125 blocking for FAM1 approval, CGR-126, CGR-127), `cra` **#855** (09:30: AUT-42 supported, CGR-124), `eng` **#837** (`92d0aba`: AUT-42 (a)-(d) written into ADR-143 point 9 as an option, second-refusal stop, Playwright test), `uxa` **#850** (11:50: UXR-94; AUT-42 information line);
- open issues labelled `automation`: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. How often relatives phone a team about the schedule is **UNKNOWN** (NAVORA records no calls; FAM1 says the same; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10. Map item "phone coordination with relatives" (team self-organisation / Visit): its first remedy is now PLANNED (FAM1 draft).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-44 | Relative gets access (FAM1-2, open question 2; PLANNED, draft): registered nurse of the client's team, relative | PLANNED: a consent record per relative and client is recorded by a registered nurse (FAM1-2); how the relative is then invited and signs in is open (engineering question 2), so a second act (send a link or code) and a second contact with the relative may follow. The client's intake consent is already captured once at conversion (`intake_consent_confirmed_at`, migration 0010:130-146; D-9 option D treats sharing beyond the team as a consent item). Without a rule, the nomination is a separate conversation after intake. Effort: two acts per relative plus possibly one more visit-time conversation (estimate). The RN restriction itself is **not** challenged: `cra` 13:30 (CGR-126) ties it to the per-decision capacity judgement, a patient-protection control | **simplify, rule:** (1) recording the consent record **is** the invitation: the same command stores the record and issues the relative's sign-in (one act, one audit entry; nothing to send separately); (2) the brief names the intake/admission conversation (ADM2 team admission) as the place where relatives may be nominated, so the RN asks once while she is already confirming the client's consent; later nominations stay possible; (3) revocation stays open to every team member at once (FAM1-3, unchanged; it is the safety direction, CGR-126). Testable: pgTAP: one consent command creates the record and the invitation, refused for a non-RN; no second command exists for inviting; e2e: from the admission screen an RN nominates a relative in one step | L (logistics access; no clinical content) | stage 0 (no AI; FAM1-12); gate: PO (FAM1), `lca` (identity verification of the invitation, FAM1 question 2), `uxa` (admission step), `eng` (ADR on the principal model) | per team and month: acts per consented relative (target 1) and median days from admission to first relative sign-in; never per person | medium | – |
| AUT-45 | FAM1 pilot measure (*AI leverage*, PLANNED): team | PLANNED: "in the team retrospective, whether schedule calls from relatives fell (**counted by the team**, never per person)". A running count of incoming calls is a new administrative act for every nurse who takes one, during or between visits, for the whole pilot, to measure a gain in exactly that time. The benefit claimed is the evidence; the form (continuous counting) is challenged, not the measure | **simplify the measure:** (a) two fixed one-week tallies per pilot team, one before FAM1 is switched on and one about six weeks after, on a paper or tap tally with no names; or (b) only the retrospective question with a three-step answer (fewer / same / more), plus the page views FAM1 already records (FAM1-14, no act). Either is equal in safety (no clinical effect) and costs at most two weeks of counting instead of every week. The choice between (a) and (b) is the PO's | L | stage 0; gate: PO (FAM1 measure), `uxa` if a tally is built | per team: calls per week in the two tally weeks or the retrospective answer; relative page views per month; never per person | medium | – |

### 2 Briefs, plans and packages reviewed

- **D-39 (owner: A):** nothing added for teams. Stage-3 sensor row decided (§5).
- **D-40 (owner: minimal B) and brief FAM1 (draft):** **supported in substance.** It removes a bottleneck of map v2 (relatives phone the team to ask when the nurse comes) using facts the team already records, with no new documentation, no AI and no new task stream: eliminate through the care graph, in the design order. FAM1-4 (access ends on pause or close without anyone acting) and FAM1-7 (only recorded changes are shown) are rules instead of acts: supported. FAM1-14 audit of reads is a control without a team act: supported. Challenges on form: AUT-44, AUT-45. No act, role or field is added without a safety or legal reason beyond those two.
- **`cra` #857 on FAM1:** CGR-125 (exhaustive status mapping with one neutral word) is a patient-safety control and adds no act: supported. CGR-126 (protective revocation preset; capacity confirmed by the recording RN) is a safeguarding control; its form adds one preset choice on revocation only: supported, no challenge. CGR-127 (one access-end sentence; no cancellation reason; "Stand" time; no cached schedule) removes content rather than adding it: supported.
- **ADR-143 `92d0aba` point 9:** AUT-42 written in as an option with the second-refusal stop; `cra` 09:30 and 13:30: both forms acceptable clinically; `uxa` 11:50 line confirmed as a hint. State change in §4.
- **CGR-124 (`cra` #855, no reception offline; scheduled evaluation as a D-2 / MOB1 condition):** an evaluation by Engineering, not a team act. No finding.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 23. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open. FAM1-12 (catalogue guard: no agent, `ai_suggestions` row or AIG1 path may reference the relative principal) follows the AIR1 pattern: supported.

### 4 Findings: state changes and closed
- **AUT-39 closed** (evidence: owner decision D-40 2026-11-04, recorded in #856: messaging, direct communication with care teams and check-ins excluded from the pilot; FAM1 *Out of scope* excludes F-03 to F-06). The two team task streams AUT-39 asked to be sized are not built; if a later decision brings them back, a new finding.
- **AUT-42:** supported by `cra` (09:30, 13:30) and written into ADR-143 point 9 as an option with its test (#837 `92d0aba`); waiting for the PO's choice. Stays open.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-41, AUT-43, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 3 | Sensor inputs (D-39) | **decided A by the owner** (none in the pilot; specification only) |
| 3 | Relative channel with AI (D-40) | **AI excluded by the owner**; the relative view is rule-based (FAM1, stage 0) |
| 1, 2 | unchanged | provider terms written (D-34), stage 1 not opened; real data blocked (D-1); adviser not named |

### 6 Waiting for the PO
- **AUT-44 (medium):** FAM1: one command for consent and invitation; nomination at admission (with `lca` on identity verification).
- **AUT-45 (medium):** FAM1 measure: two tally weeks or the retrospective answer instead of a running count.
- **AUT-42 (medium):** ADR-143 point 9 choice (both forms clinically acceptable).
- AUT-43 (low), AUT-41 (Clinical Owner gate after G-1), AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). No PR comment: FAM1 is a merged draft brief with no open PR; both findings are for the PO through this report.

---

## 2026-11-04 08:18 CET · aia review 23: AUT-41 placed by the PO as the target behind a Clinical Owner gate (open, state changed); ADR-143 CGR-123 amendment (#837 `8142bba`), `cra` #852, `uxa` #850 07:50, `lca` D-34 assessment and D-39/D-40 escalation read; AUT-42 (medium: a clock-refused observation waits for a tap before it reaches the team); AUT-43 (low: a no-show reported by phone offline is recorded again later; measure before designing)

**Read:** `recovery/main` at `d85f715`:
- merged since review 22 (#849): `lca` **#851** (D-34 detailed AI assessment; D-39, D-40 legal inputs), PO **#853** (06:10: D-39, D-40 escalated, both "approve A"; `DELIVERY_PROGRAM.md` §0c: CGR-122 (1) and CGR-123 in force, AUT-41 the target behind a gate, challenge row with a pilot hypothesis in `NEXT_CAPABILITY.md`);
- open, read on their branches: `eng` **#837** (`8142bba`: ADR-143 1c never-queued commands, 1d `FIELD_COMMAND_EFFECTS` mapping rule, 5, 6, **9 "Ohne Gerätezeit senden"**), `cra` **#852** (`e787be2`, CGR-123; AUT-41 assessed with conditions (a), (b)), `uxa` **#850** (07:50: call lines, clock-refusal card, UXR-93); code PR heads unchanged since review 22;
- open issues labelled `automation`: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. How often a nurse works without a connection, and how often a phone clock runs ahead of the server, is **UNKNOWN** (no NAVORA event records either today; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-42 | Pending observation refused on resend because its device time is later than the server time (ADR-143 9, PLANNED, #837 `8142bba`; `cra` 05:30 condition, `uxa` 07:50 card): nurse, phone | PLANNED: the refused entry is kept on her card; it reaches the team only after she sees the card and taps **"Ohne Gerätezeit senden"** (one act). Until then the observation, which may carry clinical content, is in nobody's view but hers (H-26 is the hazard `cra` named). The act decides nothing: there is only one possible outcome (send without the claim; the server time is the record's time either way, CGR-122 (2), and billed minutes are untouched, ADR-143 9). The claimed benefit (she knows the device time was discarded) is real but needs no act. Effort: one act per refusal; frequency UNKNOWN, probably rare (estimate). What is challenged is the form (a mandatory tap with one outcome), not the refusal of a late device claim | **rule instead of an act:** on a device-clock refusal, the client resends the same entry **once, automatically, without the claim**, under its original key (as ADR-143 9 already specifies for the manual act; no loop: a second refusal of any kind stops and shows the card as today). The record keeps the marker "Gerätezeit verworfen" (9) and her card shows the same line as information, with no button. The refusal itself stays: a device claim later than the server time is never stored (CGR-122, 8). Whether an automatic resend is acceptable for an entry of clinical content: `cra` (it removes the delay `cra` named; nothing changes in what is recorded). Testable: Playwright with a device clock set ahead: a pending observation is sent after reconnect with no tap, the record has only the server time and the marker, the card shows "Gerätezeit verworfen" without a button; pgTAP 9 unchanged (the refusal rolled back, no idempotency row before the resend) | L (transport of an entry; the content is the nurse's) | stage 0 (no AI); gate: `eng` (ADR-143 9 and point 2 "never retried automatically": one claim-less resend is not a retry loop), `cra` (confirms for clinical content), `uxa` (line without button), PO (MOB1) | per team and month: count of clock refusals and median time from refusal to the entry reaching the server (target: same as a normal resend); never per person | medium | – (comment on #837) |
| AUT-43 | No-show or broken-off visit offline (CGR-123, PO §0c (2), ADR-143 1c; PLANNED): nurse at the door, the teammate who takes her call | PLANNED and right in substance: these commands are never queued, so the escalation is a phone call now. After reconnecting she still records "Nicht angetroffen" or "Nicht abgeschlossen" (the visit status needs it), which creates the P1 `no_show` / `visit_interrupted` at that later server time (SIG1-C2), for a situation the team has already handled by phone. Effort (estimate, not a measurement): the fact is reported twice (call, then the entry), and a teammate may take a P1 that is already being dealt with (one more act, possibly a call back to check). Frequency UNKNOWN | **monitor first, design nothing yet.** The P1 must stay (no suppression, no AI triage of P1; hard rule). Measure from timestamps NAVORA already stores: span from `depart_visit` to `record_no_show`, and from start to `end_visit_not_completed`, per team and month (AN3 pattern, AN1 suppression, no new tap). Only if long spans are frequent in the pilot: a brief with `cra` on how a call-reported no-show is recorded once (for example the teammate who took the call records it on the visit, if the Clinical Owner allows; UNKNOWN, not proposed as a rule by `aia`) | L | stage 0; gate: PO (whether AN3 gains the two spans), `cra` (any later recording design) | the two spans above per team and month; share of `no_show` P1 signals taken within minutes of creation (already handled), per team; never per person | low | – |

### 2 Briefs, plans and packages reviewed

- **PO §0c (06:10):** CGR-122 (1) in force; AUT-41 recorded as the target with the Clinical Owner and `lca` documented-time gate and `cra` condition (b) (offline corrections distinguishable by reason kind), and a challenge row whose measure is the offline share per team and month. This is the measure-before-automating order (AUT-32) applied: **supported.** AUT-41 stays open with a new state (§4).
- **CGR-123 (`cra` #852; ADR-143 1c, 1d):** no-show, not-completed, outcome and absence never queued. A P1 waiting for the next foreground session is exactly the delay SIG1 removes; this is a safety control, not administration. **Supported.** The 1d mapping rule (a vitest derived from the migrations instead of a reviewed list) removes a recurring review act and cannot drift: **supported** as the leaner form. Follow-on cost: AUT-43 (low).
- **ADR-143 9 (clock refusal):** the in-app path `cra` asked for is right (otherwise only the phone); its form as a mandatory tap: AUT-42.
- **UXR-93 (`uxa`):** one line block per card, safety sentence first; no act added. Supported.
- **D-34 (`lca` 05:20, taken in by the PO):** the eleven provider terms and the stage-1 contents list become the D-35 stage-1 checklist; domain 10 "no open clinical Q&A" as a tested technical limit. No team act; consistent with AUT-37 (contract before switch-on). Recorded in stage tracking (§5).
- **D-39, D-40 (escalated, "approve A"):** A adds nothing for teams in the pilot. For the record of the bottleneck map: **D-40 B** (relatives see the visit time and who comes, rule-based, no AI) is the option that removes phone coordination with relatives, a team-level administration item of map v2; `aia` supports the PO's "B as the expected next step" and sets no rule. No finding.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 22. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open.

### 4 Findings: state changes and closed
- **AUT-41:** **adopted by the PO as the target design** (`DELIVERY_PROGRAM.md` §0c (3); ADR-143 1b), gated on the Clinical Owner with `lca` (documented time, UNKNOWN until G-1) and `cra` (b); CGR-122 (1) in force until then. Stays open; closes when 1b is decided either way with its measure in AN3.
- Closed this run: none.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-39, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 1 | Provider terms and stage-1 contents list | written by `lca` (D-34 assessment, 11 terms); recorded by the PO as the stage-1 checklist; stage 1 itself not opened (owner) |
| 1 | Real data to any AI path | blocked (D-1, G-25), unchanged |
| 2 | Regulatory adviser (D-34) | not named; `lca` adds adviser questions 8 (d), 8 (e), 10-12 |
| 3 | Sensor inputs (D-39), relative channel (D-40) | escalated, recommendation A (none in the pilot) |

### 6 Waiting for the PO
- **AUT-42 (medium):** one automatic claim-less resend instead of the "Ohne Gerätezeit senden" act, before ADR-143 acceptance or in MOB1 (with `cra`, `eng`).
- **AUT-43 (low):** whether AN3 gains the two no-show / interruption spans.
- AUT-41: the Clinical Owner gate (after G-1). AUT-36, AUT-37 (medium): Delivery Program version 2. AUT-38 (medium), AUT-33 (medium; #841), AUT-39 (low, D-40).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on **#837** (AUT-42; AUT-43 noted).

---

## 2026-11-04 02:20 CET · aia review 22: AUT-40 decided by the PO (closed); ADR-143 offline queue (#837) and `cra` CGR-122 (#848) read; AUT-41 (medium: CGR-122 option (1) makes every visit done without a connection cost up to three typed time corrections from memory; the PO's correction-path option gives the same billing control with no extra act)

**Read:** `recovery/main` at `7cbbf7b`:
- merged since review 21 (#844): PO **#846** (22:00: AUT-40 decided, `DELIVERY_PROGRAM.md` §0b, M6 criteria changed, CGR-113 to CGR-121 placed, `briefs/_TEMPLATE.md` CGR-119 line), `uxa` #847;
- open, read on their branches: `eng` **#837** (`7458904`, ADR-143 rewritten with CGR-121 (a)-(d), C-15 withdrawn; `APP1_IMPLEMENTATION_PLAN.md` A-07, C-03 rows), `cra` **#848** (CGR-122, inputs on ADR-143 point 1); heads of #841, #828, #814 and the UX2 PRs unchanged since review 21;
- open issues labelled `automation`: #793 (AUT-30) only; #843 closed by the PO.

**Nothing below is a measurement.** I ran no tests and read no database. Code read: `supabase/migrations/20261021000008_visit_time_corrections.sql` and `…000040…` (signature of `correct_visit_time(event, time, reason, key)`: one call per timeline event) by search only. How often a nurse works without a connection is **UNKNOWN** (no NAVORA event records it today; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-41 | Visit timeline without a connection (ADR-143, M6-2, PLANNED; `cra` CGR-122 (1) and the PO option, #848): every nurse at a door without signal | IMPLEMENTED today: every command runs online; the timeline events take server `now()`. PLANNED under **CGR-122 (1)**: offline, "Losfahren", "Einsatz starten", "Pause", "Weiter", "Einsatz beenden" and the time correction are disabled; the time is recorded "only with a connection and can afterwards be corrected with a reason". So a visit given entirely without a connection costs, after reconnecting, the timeline taps at the wrong time **plus one `correct_visit_time` per event (up to three: depart, start, complete), each with a time typed from memory and a reason** (0008: one event per call). Estimate, not a measurement: about 3 extra acts and 3 typed times per offline visit, done later in the car or at home, i.e. administration moved out of the visit and a time from memory instead of a device time. The patient-care and billing benefit of CGR-122 is real (no invoice minutes from an unaudited client time; J5); **what is challenged is the form, not the control.** `cra` itself offers the leaner form as an option for the PO | **rule, not manual re-entry: take the PO option of CGR-122, with no act added for the nurse.** (a) Offline, the timeline buttons stay active; each tap is queued as a **reasoned F3 correction** carrying the device time as the claimed time and a **preset reason** set by the command kind (P-37 pattern; e.g. "Ohne Verbindung erfasst", words `uxa`), so it enters billing only through the audited correction path, exactly as CGR-122 (3) requires; (b) the server time stays the server time (CGR-122 (2)); a device time later than the server receipt time is refused (as `cra` wrote) and the entry stays on her card with its refusal, never dropped (ADR-143 2); (c) the card and the record show both times when they differ (CGR-122 (2)); (d) no new review list: an offline-claimed time is reviewed where every F3 correction already is (countersign or quality, as built; nothing added by `aia`); (e) whether the device time is the documented time stays with the Clinical Owner and `lca` (D-10, D-11, UNKNOWN); `aia` sets no rule and no tolerance. Testable: e2e with `context.setOffline`: "Einsatz starten" and "Einsatz beenden" offline, reconnect, the visit carries two F3 corrections with the preset reason and the device times, and **the nurse performed no act after reconnecting other than keeping the app open** (act count 2, same as online); pgTAP: CGR-122 (2), (3) unchanged | L (billing fact; `cra` S1 by effect) | stage 0 (no AI); gate: PO (choice between CGR-122 (1) and the option, MOB1/M6-2), `cra` (confirms the option meets CGR-122), `lca` (D-10/D-11 documentation duty, SC-2), `uxa` (preset reason words) | per team and month: share of visits with an offline-claimed time (separate from other F3 corrections in AN3-5, so the offline rate becomes visible for the first time); human acts per offline visit after reconnecting (target 0 with the option; about 3 under (1), estimate); never per person | medium | – |

### 2 Briefs, plans and packages reviewed

- **AUT-40 decision (PO 22:00, `DELIVERY_PROGRAM.md` §0b):** takes (a)-(e) of the proposal in full; M6 criteria now test ≤ 2 taps from the start screen and "reads never enter the ledger" (pgTAP). **Closed** (below).
- **ADR-143 (#837, PROPOSED):** sign-out step with "Zurück und senden" as default, entries kept on session expiry, `access_ended` entry shown with content: each prevents a lost entry that someone would otherwise have to re-collect by phone. Supported. Point 1 ("reaches another person" constant): **`cra`'s recommendation on #848 (no list, one line "Noch nicht beim Team." on every pending care entry) is the leaner form**: one line instead of a constant, its vitest and two wordings, and no drift. Supported. `take_signal`, `take_open_visit`, `accept_cover`, `withdraw_cover` online only (`cra`): a claim's value is the server's answer; supported, no finding.
- **CGR-122 (#848):** AUT-41.
- **CGR-119 (`briefs/_TEMPLATE.md`, level-H line "D-34 classification"):** one line per level-H brief, no act for any nurse or team. Supported.
- **CGR-117 (M9 waiver wording):** governance, no team act. No finding.
- **CGR-120 ("before signing" line lists only `sign_report` refusals, never "vollständig"):** consistent with AUT-40 (b); no new rule. Supported.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 21. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open. The M6 pgTAP "no `ai_suggestions` row without a target field and a proposed value" is now a program criterion (AUT-40 (d)).

### 4 Findings closed
- **AUT-40 (#843):** closed with evidence: PO decision 2026-11-03 22:00 (`DELIVERY_PROGRAM.md` §0b items 1-5; M6 deliverable and criteria; §3.1 row 5), ADR-143 point 7 on #837 (C-15 withdrawn), APP1 M6-4 dropped. Issue closed by the PO.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-39, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | "A read is not a proposal" | in the M6 criteria (pgTAP), PLANNED |
| 0 | Guards for the five prohibitions | AIR1 on #828 (open), unchanged |
| 2 | Regulatory adviser (D-34) | the brief template now refuses a level-H brief while "D-34 classification" reads UNKNOWN (CGR-119); adviser still not named |
| 1 | Real data to any AI path | blocked (D-1, G-25), unchanged |

### 6 Waiting for the PO
- **AUT-41 (medium):** choose between CGR-122 (1) and the correction-path option before the MOB1 brief (2026-11-27); `aia` proposes the option with a preset reason and no act after reconnecting.
- AUT-36, AUT-37 (medium): Delivery Program version 2 (after M1, 2026-11-13). AUT-38 (medium), AUT-33 (medium; #841), AUT-39 (low, D-40).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on **#837** (ADR-143: AUT-41, and support for `cra`'s "no list" on point 1).

---

## 2026-11-03 20:30 CET · aia review 21: Delivery Program M1-M10 (#832), UX/UI baseline (#834, #836) and open plans read; AUT-40 (high: the M6 caregiver "Assistent" is a second screen that answers only questions the start screen already answers, so it adds taps and ledger rows without a care benefit); AUT-34 met on #841 (AN3); AUT-33, AUT-36, AUT-37 not taken into the program; AIR1 (#828) supported

**Read:** `recovery/main` at `c46010a`:
- merged since review 20 (#829): PO **#832** (`DELIVERY_PROGRAM.md` M1-M10, owner *Executive Delivery Directive* 2026-11-03), `uxa` **#834** (`NAVORA_INFORMATION_ARCHITECTURE.md`, `NAVORA_SCREEN_CATALOG.md`, `NAVORA_DESIGN_SYSTEM_V1.md`), PO **#836** (baseline adopted, UX2-33), `uxa` #839;
- open, read through PR text and file list: `eng` **#841** (AN3, migration 0108, head check runs app, db, ui-screenshots `success`, e2e not finished per GitHub), **#837** (`APP1_IMPLEMENTATION_PLAN.md`, `WEB1_IMPLEMENTATION_PLAN.md`; read `APP1` lines on C-15 on its branch), #835 (`DELIVERY_ESTIMATE.md`), #833 (`IMPLEMENTATION_SEQUENCE.md`), **#828** (AIR1, migration 0107), #840, #838; #814 still open (mergeable `clean`), #815, #813, #810, #809, #806, #804, #803, #800, #799; `cra` #842, #819, #812;
- open issues labelled `automation`: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Docs read: `DELIVERY_PROGRAM.md` header, M4, M6-M8, §3, §4, §7 in full; screen catalog C-01, C-11, C-15 to C-17, O-01 to O-03 (lines); `src/app/(protected)/field/report-section.tsx` and `src/features/field/todo.ts` by search only. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-40 | M6 caregiver app item 5 "AI assistant" (`DELIVERY_PROGRAM.md` §3.1, M6 criteria; AI-first update §5 domain 10; screen catalog **C-15** `/field/assistent`; `APP1_IMPLEMENTATION_PLAN.md` M6-4 on #837): every nurse on her phone | PLANNED. C-15 is a separate screen with four intents, and per the catalog and the APP1 plan each one reads **only an existing reader**: "Was steht als Nächstes an?" → `field_visits` + `my_signals` (the content of C-01 "Heute", the app's start screen); "Was hat sich geändert?" → `field_since_last` (HAND1, already on each visit card, C-16 tap 2); "Wer kann übernehmen?" → `team_open_visits` (COVER1, already behind "Ich kann nicht arbeiten" and on the team screen); "Was fehlt vor dem Unterschreiben?" → `field_reports` completeness (the report section signs at completion in one confirmation, F7; in my search I found no "what is missing" line on it, so whether one is needed is UNKNOWN). Path via the assistant: tap "Assistent", tap intent, read, tap the link to act = **3 taps** for an answer the start screen shows at 0-1 taps. The M6 criterion also writes **every answer and its intent to the AIG1 ledger**: a read is not a proposal, has no confirmer and no correction, so these rows enter the ledger whose correction rate per agent and field is the stop rule (§8). **Patient-care benefit claimed: none shown** (domain 10 names the intents, not a removed step); engineering cost dated 2027-01-22 (M6-4) | **eliminate the extra screen at stage 0; place each answer where the question arises:** (a) no C-15 and no `IntentList` in M6; (b) "Was fehlt vor dem Unterschreiben?" as a deterministic line on the report section next to "Unterschreiben", only if `cra` and the PO name a completeness rule (UNKNOWN; not `aia`'s to invent); (c) the other three stay on C-01, the visit card (HAND1) and the absence flow (COVER1) as built; (d) the AIG1 ledger records proposals only, never reads; (e) an assistant entry point returns with the first intent no screen can answer (dictation or drafting, D-35 stage 2 and the D-34 module), and then its brief states the step it removes and the act count before and after (AUT-38). Testable: the M6 e2e reaches each of the four answers from the start screen in ≤ 2 taps at 390 px without a separate route; pgTAP: no `ai_suggestions` row exists without a proposed value and a target field | L | stage 0; PO (M6 scope, MOB1 brief), `uxa` (C-01 placement), `cra` (the completeness rule and the "keine medizinische Beratung" line, if anything remains), `eng` (APP1 plan) | taps from start screen to each answer (e2e, before and after); AIG1 ledger rows that are reads (target 0); engineering days not spent on M6-4 (DELIVERY_ESTIMATE) | **high** | #843 |

### 2 Briefs, plans and packages reviewed

- **Delivery Program M1-M10 (#832, merged):** dates are PO targets; the binding rules repeat the mandatory sequence, D-35 A and the D-39/D-40 freeze. Supported in structure. Automation points:
  - **M4 (PLAN3, AN3, AIG1-C4/-C5):** matches AUT-32/AUT-30. Supported.
  - **M8 AIO1 deliverable "orchestrator, agent contract, evaluation harness, no provider configured":** **AUT-37 not taken in** (the orchestrator and an adapter without a provider are still in M8). Stays open for the PO.
  - **§4 AI roadmap:** no day-order rule (map rank 1, travel and day order). **AUT-36 not taken in.** Stays open.
  - **M6 item 5:** AUT-40.
  - **§3.2 family app, Communication "messages routed to the team as tasks" and Wellbeing "deviations become team tasks":** two new task streams for the team, frozen (D-40). Covered by **AUT-39** (team tasks per 100 clients and week stated in the D-40 package; default no check-in). No new finding.
  - **§3.3 Operations "Staffing: team capacity view per week, never per person":** supported (team level, no ranking).
- **UX/UI baseline (#834, #836):** C-11 "Vorschläge" with `ProposalLine` and a `BulkConfirmBar` "when ≥ 1 tick": consistent with AIG1-5 (ticked list only for `schedule` fields; no accept-all on listed fields). C-17 PLAN3 shows load "never judged"; O-02 has no person column. Supported. The landing text lists all seven steps of the sequence: AUT-38 (one act for steps 5-6) applies to the screens, not only the method text.
- **AN3 on #841 (open):** **AUT-34 met** ((b) is the AN2 `countersign_latency_hours` beside `report_returned_share`, ADR-144 deviation 1). **AUT-33 not met:** spans only, no act counts per 100 visits; the PO approved AN3 without it. One comment on #841.
- **AIR1 on #828 (open):** a register trigger refuses billing and safety-signal-priority targets, catalogue checks that no function writes the ledger's targets, no `ai` agent registered. Removes no step and adds none for any nurse; it makes prohibitions 1 and 3 of the owner directive testable. Supported; no finding. I ran none of its tests.
- **#833, #835, #838, #840:** sequence, estimate, hosting and status documents; read by title and file list only; no automation finding claimed.

### 3 AI readiness of delivered items (§8)
- **#814 (AIG1-C4 + C5):** unchanged since review 20, still open; AUT-30 closes on merge.
- **#828 (AIR1):** guards only; no agent proposes. §8 rows "no accept-all", "named confirmer" unaffected.
- **C-15 (PLANNED):** fails §8 "correction rate per agent and field" as specified, because reads would enter the ledger without a decision (AUT-40 (d)).

### 4 Findings closed
- **AUT-34:** met on #841 head; closes on merge.
- AUT-30 (#793): met on #814 head; closes on merge.
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-39, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | Guards for the five prohibitions (#824) | AIR1 on #828 (open, PLANNED until merged) |
| 0 | Baseline for ranks 1-3 | AN3 built on #841 (open); act counts (AUT-33) OPEN |
| 0 | Delivery dates | PLAN3 and AN3 M4 2026-12-18; AIO1, OPS2, HAND2 M8 2027-02-19 (PO targets, not commitments) |
| 1 | Real data to any AI path | blocked (D-1, G-25), unchanged; M3 owner decisions 2026-12-11 are the critical path (program §7) |
| 2, 3 | Regulatory adviser (D-34), Clinical Owner (G-1) | not named, unchanged |

### 6 Waiting for the PO
- **AUT-40 (high):** answer before the MOB1 brief (2026-11-27): drop C-15 at stage 0 or name the patient-care benefit it adds.
- AUT-36, AUT-37 (medium): not taken into the Delivery Program; version 2 (after M1, 2026-11-13) is the next place.
- AUT-38 (medium), AUT-33 (medium; #841), AUT-39 (low, D-40 package).

### 7 Issues and comments
- **#843** opened for AUT-40 (labels `agents`, `agent:po`, `automation`); no duplicate found among open issues.
- One comment on **#837** (APP1 plan M6-4, AUT-40) and one on **#841** (AUT-33 open, AUT-34 met).

---

## 2026-11-03 14:40 CET · aia review 20: AI-first architecture update (#822) and owner directive 14:00 reviewed; opportunity-map ranking challenged (AUT-36, medium: the largest bottleneck, travel and day order, is missing from the ranking); AIO1 narrowed (AUT-37, medium); the seven-step sequence must not add acts (AUT-38, medium); D-40 Check-In adds team tasks (AUT-39, low); AUT-32 closed (AN3 approved); AUT-30 met on #814 head

**Read:** `recovery/main` at `41ec907`:
- merged since review 19 (#811): PO **#822** (13:45 *AI-first* and 14:00 *post-PR #822 alignment*: `AI_FIRST_ARCHITECTURE_UPDATE.md`, `AI_OPPORTUNITY_MAP.md`, `AI_CAPABILITY_ROADMAP.md`, brief template *AI leverage*, `NEXT_CAPABILITY.md` rule *AI-first review*, **AN3 approved**, D-39 and D-40 opened and frozen, allowed list PLAN3, AN3, AIO1, OPS2, HAND2 on synthetic data), `csa` #821 (STR-20 to STR-25), `lca` #823 (Basel-Stadt checks for D-2, D-4, D-9, D-29), `uxa` #798;
- open: `eng` **#814** (AIG1-C4 + AIG1-C5, migration 0105, head `dc1b2b4`; check runs app, e2e, db, ui-screenshots all `success` per GitHub, I ran none), #815 (ASM1-C6), #813, #810, #809, #806, #804, #803, #800, #799; `cra` #819, #812; read through their PR text;
- open issues: #793 (AUT-30), **#824** (`eng`: enforce the five prohibitions), **#826** (D-39), **#827** (D-40), #817 (owner spec).
- The PO asked `aia` (JOURNAL 13:45) to challenge the opportunity-map ranking at this review. Done in AUT-36.

**Nothing below is a measurement.** I ran no tests and read no database. Docs read: the three new product documents in full except the update's §6 and §7, `briefs/AN3.md` (14:00), `briefs/_TEMPLATE.md`, `decisions/D-39.md`, `decisions/D-40.md` (summaries), `NEXT_CAPABILITY.md` lines 1-45. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-36 | Opportunity-map ranking (`AI_OPPORTUNITY_MAP.md` §3, PO 2026-11-03): the PO choosing what is built next; every nurse (rank 1 of the bottleneck map) | The ranking orders by the owner's value list and "can run before D-35 stage 1", not by direct-care time recoverable. Compared with map v2 (review 18): **map rank 1, travel and day order, does not appear in the ranking at all** (A3 is named only under §2.3 *Assist* and §2.11, with Q7 and D-11 as gate); map rank 2 (documentation) is ranking 7 (DOC2, not in the owner's allowed list); map rank 3 (orders, referrals) is ranking 6 and 9. Ranking places 1-5 are PLAN3 (map rank 4), AIO1 (no step removed by itself), AN3 (measure), OPS2 (exceptions handled by Operations, not by nurses at the bedside) and HAND2 (handover ordering: the digest exists, HAND1). So the five items allowed now touch none of the three largest estimated bottlenecks. Each of those waits for an owner, legal or clinical decision (Q7 still OPEN; D-11 answered by the owner to `lca` as Basel-Stadt, JOURNAL 13:55, the PO records it; D-10 with G-1; D-22, D-9, D-3). IMPLEMENTED: AN1 travel minutes within visits; nothing that orders a day | **re-rank by recoverable time, keep safety as precondition**: (a) add a column "bottleneck-map rank (estimate)" to §3 so the value order and the time order are both visible; (b) add **day order of one nurse's own confirmed visits** (AUT-5) to §3 as a stage-0 deterministic rule on **synthetic geography only** (seed coordinates, no real address or location, no travel tracking), proposal confirmed by the nurse in one act, never per-person comparison; its real-data release waits for Q7 (`lca`) and the Basel geography (D-11); (c) the PO asks the owner, in a package, whether this rule joins the synthetic-data list, since it is not in it today. Testable: on the seed, the rule returns an order for a nurse's day within the visits' windows, never moves a visit outside its window, writes each proposal to the AIG1 ledger with field class `schedule`, and reads no location of a person | L (order of a person's own logistics; no clinical content) | stage 0, synthetic; gates: owner (allowed list), `lca` (Q7 before real data), labour-law rules; `uxa` (one-act confirmation) | AN1 travel share per team and month before and after (AN3 baseline); share of proposals confirmed unchanged (AIG1) | medium | – (report; PO answers in its next cycle) |
| AUT-37 | AIO1 (proposed brief, roadmap §3.1 item 2; ranking 2): Engineering; later every agent | Proposed scope: a server-side orchestrator pipeline (scope check, minimisation, model or rule, schema validation, source-per-claim check, ledger write), an agent contract table, an evaluation harness in CI, a provider adapter with **no provider configured** (D-35 A). Every agent allowed now is a **rule** (PLAN3, OPS2, HAND2); minimisation and source-per-claim checks are for language output, which D-35 A forbids on real data until the owner's stage-1 package. IMPLEMENTED already: agent register and stop table (AIG1-1), field classes and one-by-one list (AIG1-5), ledger with input reference, version and confirmer (0097), look-back (0103, 0104), expiry (0105 on #814, open). Patient-care benefit claimed: safety of later agents ("7, safety"). No direct-care step is removed by AIO1 itself | **simplify**: split AIO1. Build now (supports §8 readiness): (i) the agent contract as columns or a versioned document per row of the existing AIG1 register (purpose and removed step, trigger, input scope, output schema, level, confirmer, stop rule, never-list), refusing to switch on an agent without one; (ii) the **evaluation harness in CI** for PLAN3 on synthetic cases (correction rate per field, unchanged-confirmation share, expired share), run per agent version. Defer to the D-35 stage-1 package: the model call step, minimisation, source-per-claim validation and the provider adapter, designed when the first language agent, its provider and region are known (an adapter built against no provider fixes an interface before its constraints exist). Testable: an agent without a contract cannot be switched on (pgTAP); the harness fails CI when an agent version's correction rate on its synthetic set rises above its written threshold | L | stage 0; PO (brief scope), `eng` (ADR), `lca` (contract fields that touch D-35 terms) | no added engineering surface without a running consumer; harness run per PLAN3 version | medium | – (report) |
| AUT-38 | Mandatory sequence "AI prepares → Human reviews → Human decides → Human signs" (update §0, §3; template *AI leverage* steps 5-7): every confirmer, every brief | The owner directive makes review, decision and signature explicit. Read literally as three acts, it would add administration to proposals that today take one: PLAN3 confirms a `schedule` line in one act (AIG1-5 allows a ticked list for `schedule` fields); WORK1 confirms a proposed day once; AN3's own *AI leverage* answers "nothing is signed". §3 step 7 says "which signature or required approval does the law or the Clinical Owner demand?", which allows "none", but neither §3 nor the template says so, and the template asks "which signature or required approval **stays**", which presumes one. No patient-care benefit is shown for a separate review act or a new signature on a logistics proposal; the safety control is that a named person who can reject confirms with the sources in view (AIG1-3), which one act already gives | **keep the control, not the act count**: one sentence in update §3 and the template (PO): "Steps 5 and 6 are one act by the named confirmer, with sources and 'nicht gefunden' in view, unless a law or the Clinical Owner requires a second person; step 7 names an existing or legally required signature and may be 'none'; the AI-first method never adds a signature, an approval or a review step that did not exist before the AI." The never-list (no accept-all on listed fields, AIG1-5) stays. Testable: every brief's *AI leverage* states the number of human acts per proposal before and after; the PO marks `changes-requested` a brief whose count rises without a named safety or legal reason | L (method text) | stage 0; PO (method text), `cra` (whether any clinical field needs two persons; UNKNOWN until the Clinical Owner, D-17 part 3), `uxa` | human acts per 100 proposals per team (AUT-33 act counts) | medium | – (report) |
| AUT-39 | D-40 Check-In Services (domain 4; frozen, specification only): primary nurse, team | Spec (update §5.2 domain 4): the RN chooses each client's questions from a Clinical Owner set; an answer outside the approved band becomes a **team task**. That is a new per-client selection act and a new task stream for the team, with no estimate of volume and no stated care benefit beyond "between visits nobody knows how the client is" (map §1 row 17). Bands and question sets are clinical (UNKNOWN; Clinical Owner, G-1). Frozen: nothing is built | **challenge the form, not the existence** for the specification: (a) the D-40 package states the expected team tasks per 100 clients per week on synthetic data and who closes them; (b) default is no check-in; a check-in is set only where the care plan names a reason; (c) the first scope is logistics only (visit confirmation, who comes), which needs no band; (d) never a P1 signal unless the Clinical Owner makes it one (as written). No proposal for clinical items, bands or thresholds (not `aia`'s to invent) | L (logistics part) · H (interpreting answers) | frozen (owner); D-40, D-9, D-34 module, Clinical Owner, `lca` | team tasks created and closed per 100 clients and week; calls from relatives before and after (UNKNOWN today: calls are not recorded) | low | – (report; noted for #827) |

### 2 Briefs and items reviewed

- **Owner directive 14:00 (human-in-the-loop, five prohibitions, D-39/D-40 freeze):** consistent with every rule in `aia`'s mandate (no P1 triage, no per-person scoring, no automatic coding or billing, no general copilot, no unconfirmed entry). Supported. AUT-38 concerns only how many acts the sequence costs.
- **AI-first update §1 point 3 ("an agent that re-types, chases or summarises fragmented information is worse than a record where it is never fragmented"):** this keeps the care graph before the agent and matches the earlier order. Supported. **§3 step 4** widening AI to "any decision inside the graph" is acceptable because steps 5-7 and AI-3 keep the named confirmer; `aia` watches that each agent still names the step it removes (AI-12).
- **AN3 approved (PO 14:00):** answers AUT-32 (closed below). **AUT-33 and AUT-34 not taken in** (no "per 100", no reuse of `countersign_latency_hours` in the brief). Roadmap §5 measures "administration removed per step" by AN3 **spans**; an elimination removes acts, so the roadmap's own measure needs AUT-33. Both stay open for the PO.
- **OPS2, HAND2 (proposed briefs, not written):** both are rules over existing data; no step added for nurses. When written, `aia` checks: OPS2 groups exceptions so Operations sees fewer lines, never re-orders P1 signals (AI-10); HAND2's "unread before start" stays a fact on the card, never a blocking gate before a visit (a gate would add a step at the door).
- **D-39 (sensors):** frozen; no automation finding. Any sensor-derived billing stays out (prohibition 1).
- **#814 (AIG1-C4 + C5, open):** see §3.

### 3 AI readiness of delivered items (§8)
- **#814 head `dc1b2b4` (not merged):** answers AUT-30 in code: OPS1 `agent_stopped` per stop with at least one open line whatever the agent's state, closes at "0 offen"; expired proposals filtered on read and refused by `confirm_suggestion` as `not_open`, so an expiry can never be counted as a rejection (correction rate per agent and field stays honest); expired counted apart in `agent_health`. No person column added. Ledger stays append-only. **§8 check: met on the PR head**; AUT-30 closes on merge. CI success on all four check runs per GitHub; I ran no test.

### 4 Findings closed
- **AUT-32 closed:** AN3 approved (PO 2026-11-03 14:00, *Next up* 3), per-step baseline on synthetic data before G-19; real data waits for `lca`'s D-23 term (b) read.
- **AUT-30:** met on #814 head; closes on merge (#793 then closable by the PO).
- AUT-33, AUT-34, AUT-35, AUT-21 (#809 open), AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13): unchanged.

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1-C4/-C5 before the first agent other than the synthetic test agent | built on #814 (open, CI green per GitHub) |
| 0 | Baseline for ranks 1-3 | AN3 **approved** (PLANNED, *Next up* 3); act counts (AUT-33) OPEN |
| 0 | Agent contract and evaluation harness (AIO1) | PLANNED; brief not written; scope challenged (AUT-37) |
| 0 | Synthetic-data allowed list | PLAN3, AN3, AIO1, OPS2, HAND2 (owner 14:00); day order not in it (AUT-36) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1, G-25), unchanged |
| 1 | Owner releases stage 1 (provider, region CH/EU, contract, DPIA) | not decided; roadmap §4 item 1 asks the owner to open the package |
| 2 | Regulatory adviser on level G (D-34) | not named; `lca` D-34 AI assessment requested (14:00) |
| 3 | Clinical Owner (G-1) | not named |

### 6 Waiting for the PO
- **AUT-36 (medium):** whether the ranking gets a recoverable-time column and whether a day-order rule on synthetic geography goes to the owner for the allowed list.
- **AUT-37 (medium):** AIO1 scope: contract on the AIG1 register plus evaluation harness now; orchestrator pipeline and provider adapter with the stage-1 package.
- **AUT-38 (medium):** one sentence in the method and the template: steps 5-6 are one act; step 7 may be "none"; the method never adds an act.
- **AUT-33, AUT-34:** AN3 approved without them; take in at the ADR or a brief amendment.
- AUT-39 (low) for the D-40 package (#827); AUT-30 (#793) closable when #814 merges.

### 7 Issues and comments
- No `high` finding: no issue opened. One comment on decision issue **#827** (D-40, AUT-39). No open PR carries an `aia` finding.

---

## 2026-11-03 08:20 CET · aia review 19: AN3 draft (P-19, answer to AUT-32) supported with AUT-33 (medium: spans measure waiting, not work; add act counts per 100 visits) and AUT-34 (low: AN3-1 (b) and AN3-5 already IMPLEMENTED as `countersign_latency_hours` beside `report_returned_share`, reuse); AUT-35 (low: a typed reason on the first qualification at admission, #809); RLS4-C3, UX2-31/-32, #803/#804/#806 without finding

**Read:** `recovery/main` at `6d6dbba`:
- merged since review 18 (#802): PO **#808** (06:30: RLS4-C1/-C2 met, RLS4-C3; CGR-108/-109 into UX2-27/-29 and G-25 (c); UX2-31, UX2-32; **AN3 drafted** from P-19 after AUT-32), `lca` #805 (D-1 re-check on CGR-109);
- open: `eng` #803 (UX2-15/-16/-25), #804 (UX2-18 to -21), #806 (UX2-30), **#809 (UX2-26, from AUT-21)**, #799, #800; `cra` #807, #801; `uxa` #798; read through their PR text;
- open issues labelled `automation`: #793 (AUT-30; adopted as AIG1-C5, open until built).

**Nothing below is a measurement.** I ran no tests and read no database. Code read: `supabase/migrations/20261021000027_pilot_impact.sql`, `…0032_an1_changes.sql` (`pilot_kpis(p_month)`), `…0065_f6r_return_report.sql` (F6R-9 measures), `…0018_reasons_and_qualification.sql` (`set_member_qualification`), `briefs/AN3.md` (06:30), `briefs/RLS4.md` (06:30), `briefs/UX2.md` (06:30). The bottleneck map is v2 (review 18); next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-33 | AN3 (P-19, draft): the team and the PO, measuring ranks 1-4 of the map | AN3-1 measures five **spans** (elapsed calendar time between two timestamps). A span shows waiting, not work: a report signed 4 h after the visit may cost 3 minutes; a countersign done in 10 minutes still costs a registered nurse one act per report. When a step is **eliminated** (rank 2: countersign scope under D-10; rank 3: structured orders under D-22; rank 4: PLAN3 proposals instead of setting the responsible nurse visit by visit) the span disappears or changes meaning, so it cannot show the gain. What an elimination removes is **acts**, and NAVORA already records each act: `countersign_report` per report (0016, 0065), ORD0 tasks per order (0061), `take_open_visit` (0046) and the `care_visits` audit trigger (0012) for responsible-member changes, the AIG1 ledger per proposal (0097, 0103, 0104), time corrections (`time_correction_share`, AN1). IMPLEMENTED: the acts and their timestamps. OPEN: whether the audit rows distinguish a manual responsible-member change from a confirmed AIG1 proposal (UNKNOWN until Engineering names the column) | **automate the measure** (deterministic, read-only): add to AN3-1, per team and month with AN1 suppression, the **count of administrative acts per 100 completed visits** for each step AN3 already lists: (i) countersignatures, (ii) returned reports (exists as share, F6R-9), (iii) ORD0 tasks opened, (iv) responsible-member changes made by hand vs through a confirmed proposal, (v) AIG1 proposals changed or rejected (the §8 correction rate per agent and field, team level). No new column, table, field or tap; same "never per person" (AN3-3) and "no target" (AN3-5) rules; where a source cannot separate (iv), Engineering says so in the ADR and leaves it out | L (team counts of recorded acts; no clinical content) | stage 0; gate `lca` (D-23 term (b), as AN3 already names), PO | for each later elimination: acts per 100 visits for that step before and after, beside the WORK1-6 care share (estimate of time freed = acts removed × minutes per act, minutes per act stays UNKNOWN until observed in the pilot) | medium | – (report) |
| AUT-34 | AN3-1 (b) and AN3-5 (countersign span, shown beside returned reports) | **IMPLEMENTED** since F6R (0065, F6R-9): `pilot_kpis` returns `countersign_latency_hours` (median, first signature to countersignature, returns included) and `report_returned_share`, per team and organisation, with AN1 suppression and the note "Evidenz für D-10 …" (no target word). AN3-1 (a) says "reuse, do not duplicate" for the report span; (b) does not. A second definition of the same span would let two figures for one step disagree (e.g. returns counted in one, not in the other) | **eliminate the duplicate**: AN3-1 (b) and AN3-5 reuse `countersign_latency_hours` and `report_returned_share` as built (F6R-9), adding only what AN3-5 adds (open time corrections beside them); the AN3-5 string test runs over the existing note | L | stage 0; PO (brief text), `cra` (AN3-5 wording, already given 05:30) | one definition per span: the AN3 ADR maps each AN3-1 figure to one `pilot_kpis` measure name | low | – |
| AUT-35 | Admission: administrator sets the qualification in the same sitting as the contract (UX2-26, #809, from AUT-21) | #809 (open) puts the qualification on the "Vertrag erfasst" card, as AUT-21 proposed (one sitting instead of two). The existing command `set_member_qualification(…, p_reason, …)` (0018, IMPLEMENTED) needs a typed reason of 3–300 characters, so every admission carries one free-text field whose content at a **first** setting is predictable. The qualification is a safety control (it decides the countersign duty, 0016): its existence, actor, time and audit row are not in question; its **form** is | **simplify**: for the first setting in the admission sitting, a preset reason (as P-37 does for correction acts), e.g. "Bei Vertragserfassung festgelegt", the administrator may overwrite it; every **later change** keeps a typed reason. Wording `uxa`; whether a preset reason meets the audit purpose `lca`/`cra` | L | stage 0; gate `uxa`, `lca`, `cra` (qualification gates countersign) | free-text fields per admission (team level, from the audit rows of the admission sitting) | low | – (does not block #809) |

**Briefs and items reviewed without a new finding:**
- **AN3 as a whole (draft):** answers AUT-32 as proposed: read-only, no new tap or field, never per person, AN1 suppression, `lca` before approval, built before G-19 so the first pilot month is the baseline. AN3-2 (travel beside the care share, labelled as within-visit travel only) is the honest limit for rank 1. Supported with AUT-33 and AUT-34.
- **RLS4-C3:** "Erneut laden" on a failed read and an honest result line; access end stays possible without the list. That is the leaner choice at equal safety (no hold on a leaver's access for a read). No step added. Supported.
- **UX2-31, UX2-32:** the role's home as first tab and one name per destination remove navigation and a translation step. Supported.
- **UX2-27/-29 amendments (CGR-108, CGR-109), G-25 (c):** display text; "nicht erfasst" claims no absence. No step added. The PO's challenge (06:30: a closed visit's record should answer "who cared" from the report, not "who was planned") is the care-graph answer: the fact exists in the signed report, so nobody has to fill the planning field afterwards. Supported.
- **#803, #804, #806 (UX2 parts 4 to 6, open):** presentation only. #806 prefills the instrument on the replace form only when exactly one catalogue entry is valid: less typing, no guess. No step added.

### 2 AI readiness of delivered items (§8)
- Nothing merged since review 18 proposes, drafts or ranks. No §8 check due. AUT-33 (v) would give the §8 correction rate per agent and field a team-level home on `/analytics` once PLAN3 runs.

### 3 Findings closed
- None. **AUT-32:** answered by the AN3 draft; closes when AN3 is approved (after `lca`). **AUT-21:** built on #809 (open); closes on merge. AUT-30 (AIG1-C5) and AUT-31 (PLAN3-13) close when built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38): unchanged.

### 4 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | Baseline for ranks 1-3 (AUT-32) | **PLANNED as draft** (AN3, PO 06:30); waits for `lca` (D-23 term (b)), then *Next up* after PLAN3, before G-19 |
| 0, 1 | all other rows | unchanged from review 18 |

### 5 Waiting for the PO
- **AUT-33 (medium):** whether AN3-1 adds act counts per 100 visits (i)-(v) before `lca` reads the draft, so `lca` reads one version.
- **AUT-34 (low):** AN3-1 (b) and AN3-5 reuse the F6R-9 measures.
- **AUT-35 (low):** preset reason on the first qualification at admission (with `uxa`, `lca`, `cra`); not a reason to hold #809.
- AUT-30 / AIG1-C5 and AIG1-C4 to build; P-36 undo alternative (review 15), AUT-19, AUT-20 as before.

### 6 Issues and comments
- No `high` finding: no issue opened. AUT-35 is low and does not block #809, so no PR comment; AN3 has no open PR or decision issue.

---

## 2026-11-03 02:40 CET · aia review 18: bottleneck map v2 (weekly refresh); AUT-27 closed (RLS4-C1 built, #792); AUT-30 adopted as AIG1-C5, AUT-31 into PLAN3-13; UX2-1 shell (#799) and UX2-27/-29 (#800) without finding; AUT-32 (medium: the three largest bottlenecks have no build path and no per-step baseline)

**Read:** `recovery/main` at `a321e6c`:
- merged since review 17 (#794): PO **#791** (02:25 and addendum 02:55: AIG1-C4, **AIG1-C5 from AUT-30**, PLAN3-11 keyed on open lines, PLAN3-13 with AUT-31), **#792** (RLS4-C1 runbook §5c, RLS4-C2 `/admin`; pgTAP 105), #795, `lca` #797;
- open: `eng` **#799** (UX2-1 shell, ADR-131) and **#800** (UX2-27, UX2-29, ADR-132), `cra` **#801** (01:30: CGR-101, CGR-105 closed; #799 gate clear; CGR-108, CGR-109 on #800), `uxa` #798 (UXR-72 to -74), #796, and the earlier `cra` chain; all read on their branches through their PR text and file lists;
- open issues labelled `automation`: #793 (AUT-30; adopted, open until built).
- No repository activity from 2026-10-31 03:51 to 2026-11-03 01:10.

**Nothing below is a measurement.** I ran no tests and read no database. CI states are as the PRs and `cra` #801 report them; not re-read by me. Code and docs read: `docs/engineering/OWNER_RUNBOOK.md` §5c, `briefs/AIG1.md` (02:55), `briefs/PLAN3.md` (PLAN3-7, -11, -13), `briefs/WORK1.md` (WORK1-5, -6), `briefs/AN1.md`, `NEXT_CAPABILITY.md` (challenge rows P-19, P-20, P-28, P-32, P-38), `OPEN_DECISIONS.md` (D-3, D-9, D-10, D-11, D-17, D-22, D-28, D-37, Q7).

### 1 Bottleneck map v2 (weekly refresh; v1 review 1, 2026-10-27; from-scratch reading review 5)

**Published evidence:** [E1] and [E2] as in review 1 (not re-read). **[E3]** read 2026-11-03: *Kennzahlen der Hilfe und Pflege zu Hause SPITEX 2017/2018* (Gesundheits- und Fürsorgedirektion des Kantons Bern, on the BFS Spitex statistics; <https://www.gsi.be.ch/content/dam/gsi/dokumente-bilder/de/themen/statistiken/sozialmedizinische-institutionen/DA_Kennzahlen_SPITEX_2018_bis_2017_d.pdf>). It gives billed hours and full-time positions per year but, by its own scope, the two cannot be combined into a billable or direct-care share (billed hours cover some services only; positions include administration). **A Swiss direct-care or documentation share for home care therefore stays UNKNOWN** to `aia`; no Swiss figure is used below.

**Rank** = estimated direct-care time recoverable at team level, 1 = largest (estimate, ordinal, unchanged from v1 unless stated). **Moved this week** = what changed in the product since 2026-10-27.

| Rank | Step (role) | Moved this week (status) | What still costs a person time | Verdict (from scratch) | What unblocks it | Finding |
|---|---|---|---|---|---|---|
| 1 | Travel and day order (nurse) | nothing (OPEN). PLAN3 excludes order and travel (PLAN3 *Negative*, Q7). AN1 travel minutes within visits IMPLEMENTED | she orders her own day and route | **replace first** (team geography, J2 and D-11), **automate second** (AUT-5 day-order rule) | Q7 (location data, Gate 5, `lca`), D-11 (`owner`) | AUT-5, **AUT-32** |
| 2 | Documentation per visit (nurse; RN countersigner) | OBS1 accepted (author line per observation; no step added). D-10 still awaiting the Clinical Owner (G-1 not named) | one free-text report per visit; RN countersign of every care-assistant report (0016) | **replace** by documentation by exception (P-2) and risk-based review (D-10); dictation (A7) only at stage 2 | D-10 and G-1 (`clinical`); D-35 stage 2 | AUT-4, **AUT-32** |
| 3 | GP orders, hospital referrals, relatives (primary nurse) | nothing (OPEN). D-22, D-9, D-3 awaiting | phone or fax for order renewal (ORD0 records only the task); referral re-typed at J1 | **eliminate** (structured order and referral, external actors as record nodes) | D-22, D-9 (`legal`/`owner`), D-3 (Clinical Owner) | AUT-6 |
| 4 | Who takes which visit (team) | AIG1 accepted, AIG1-C1/-C2/-C3 met (#787); AIG1-C4/-C5 then PLAN3 in *Active now* (2), (3). VIS1 (early visit as one confirmed move) and VIS2 (overlap shown) IMPLEMENTED | a member sets the responsible nurse visit by visit (J3); moving a weekly visit before doing it early (VIS1-3b) | **eliminate the role**; PLAN3 is the means (ticked list for `schedule` fields, AUT-1); P-28 (window instead of a fixed day) would remove the early-visit move at its source | build (PLAN3); P-28 needs a missed-visit rule for a window (D-28, Clinical Owner) | AUT-1, AUT-19 |
| 5 | Assessment → care plan (assessing RN) | ASM1 accepted with ASM1-C4: one confirmed review act re-bases the plan, no retyping (AUT-26 closed, IMPLEMENTED) | minutes per category typed from the provider's tool; planned minutes per service again on the plan | **redesign** (one clinical language); import later (AUT-13, D-37) | `cra` on the AUT-2 display; D-37, D-36 (`owner`, `legal`) | AUT-2, AUT-13; P-38 (measure) |
| 6 | Working time (nurse) | nothing. WORK1-6 team North Star IMPLEMENTED (care minutes over confirmed paid minutes, per team and month) | one confirmation per day with two questions | **simplify the form**, the duty stays (P-20 measures first; `lca`) | pilot data, `lca` (D-23) | AUT-8 |
| 7 | Visit status taps (nurse) | nothing | up to six taps per visit | inferred times are `record` values confirmed one by one (AUT-7 closed): **no gain at equal safety** | – | – |
| 8 | Billing preparation | nothing | none before the invoice (J5 derives facts) | eliminated; invoice later (BILL2) | D-12, D-18 | – |
| 9 | Referral → case → team decision | nothing | none beyond rank 3's re-typing | eliminated (team pull, J2) | – | – |
| 10 | Quality and analytics | nothing | the hold lift by coach or admin (D-16) | eliminated (compilation) | D-16 (`clinical`) | – |
| 11 | Team self-organisation: absence, offboarding, onboarding | ADM2 accepted (team admits by consent; "Vertrag erfasst" once); RLS4-C2 (leaver's open reports at the access-end step only, #792) IMPLEMENTED; UX2-26 (qualification on the same card after "Vertrag erfassen", AUT-21) PLANNED | the administrator's separate qualification step until UX2-26 | eliminated (central admission); **simplify** the remaining employer acts into one sitting (AUT-21) | build (UX2-26) | AUT-21 |
| 11a | Team self-organisation: a team that divides itself (team) | nothing (P-32, OPEN) | only an organisation administrator creates a team (`create_team`, 0035); no command hands open cases with primary nurse, deputy and planned visits to another team (UNKNOWN whether another path exists) | **eliminate** re-entry: one team decision carries cases with their people; responsibility transfer stays `cra`'s | P-32 brief (PO); `cra` on a responsibility transfer | – (P-32) |
| 11b | Team self-organisation: night and weekend cover across teams | nothing (COVER1 accepted, switched off, D-3) | cover by phone outside NAVORA | shared on-call service (STRATEGY §8.1.5) | D-3, P-24 (UNKNOWN, `lca`) | – |
| new (low) | **Governance follow-up of an assistant** (team members, Operations): look-back lines after a stop, expired proposals, threshold health | AIG1-C1/-C2/-C3 IMPLEMENTED; AIG1-C4 (expiry on read) and AIG1-C5 (follow-up keyed on open lines) PLANNED | work that exists only because an assistant exists; kept per value, one by one, where safety requires it | **keep it smaller than the gain**: measured per team in PLAN3-7 and PLAN3-13 (confirm actions per day plan, proposal-to-plan minutes, expired share, stops and switch-ons) | build (AIG1-C4/-C5, PLAN3) | AUT-29, AUT-30, AUT-31 |
| – | Founding a team's provider (team, future Leitung Pflege) | nothing (D-38) | a founding project per team | provider kit (STR-19), readiness read from the record | D-38 (`owner`) | AUT-14, AUT-15 |

**What the refresh shows (estimate, not a measurement):**
- Since 2026-10-27 every delivered capability sits at ranks 4, 5 and 11 or in the governance layer that ranks 4-5 need. That order is consistent with the queue: those steps are buildable without an owner, legal or clinical decision.
- The **three largest estimated bottlenecks (ranks 1-3) did not move**. None has a build path that does not wait for a decision (Q7 and D-11; D-10 with G-1; D-22, D-9, D-3), and none has a **per-step baseline**. The team North Star (WORK1-6) shows the total care share once days are confirmed, but not which step the non-care time goes to. So if ranks 1-3 are unblocked during the pilot, their gain cannot be shown against a before value. This is AUT-32.
- Minutes per step, the share of a working day in any one step, and the number of calls with GPs, hospitals and relatives stay **UNKNOWN**. The synthetic seed cannot answer them (its timestamps are generated, not worked).
- Next refresh: 2026-11-10.

### 2 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-32 | All of ranks 1-3 (travel and day order; documentation and countersign; orders and referrals): the team, measured; the PO deciding what to unblock first | **IMPLEMENTED:** AN1 travel and care minutes within visits (0027, 0032); WORK1-6 care share of confirmed paid time per team and month (0079). **PLANNED:** PLAN3-7 and -13 (planning only). **OPEN:** P-19 (PO 2026-10-27 15:20, "brief later, no build now", challenge table in `NEXT_CAPABILITY.md`) proposes per-step spans from timestamps NAVORA already stores (report draft created → signed; countersign latency; partner request → case ready; ORD0 task age); no brief exists after a week (grep of `briefs/`). Ranks 1-3 have no build path without a decision (map §1). Without a pilot baseline, the gain of D-10, Q7 or D-22 cannot be shown, and the owner's success measure 2 (less administration) has no team-level number per step | **monitor, no new tap:** brief P-19 now as a read-only AN1 extension, so the pilot's first month is the baseline: per team and month, with AN1 small-team suppression and never per person: (a) median report draft → signed span and countersign latency (rank 2); (b) travel share of visit time already in AN1, shown beside the WORK1-6 care share (rank 1); (c) ORD0 open-task age and J1 request → case-ready span (rank 3). No new field, no stopwatch, no reading of the WORK1 tables beyond WORK1-6 (D-23 term (b)). Testable criteria: pgTAP on the synthetic seed returns each span per team; a team below the suppression rule returns nothing; the catalogue check finds no person key in any new read | L | stage 0; PO (brief, place before G-19); `lca` (staff timestamps aggregated per team, D-23 term (b)); `eng` (read model) | the spans themselves, before and after each of D-10, Q7, D-22 is decided | medium | report only |

**Briefs and items reviewed without a new finding:**
- **AIG1-C5 (PO 02:55):** adopted as AUT-30 proposed, with its tests and measure; `cra` #801 states no objection. Supported. AUT-30 stays open until built (*Active now* (2), with AIG1-C4).
- **PLAN3-11 amended, PLAN3-13 with AUT-31:** supported; the expired share and lead time are measured per team and never as a stop criterion.
- **RLS4-C1 as built (#792, runbook §5c):** see §4 (AUT-27). **RLS4-C2 as built:** a leaver's open reports are read at the access-end step only, so administrators no longer see a standing per-person list; a task list for that moment, not an act history. No step added. Supported.
- **UX2-1 shell (#799, open):** the nurse's three tabs are "Heute", "Team" and "Arbeitstag"; `/team` (the team's own planning, proposals and look-back count under PLAN3-11) is one tap from every screen instead of a menu entry. No step, field or role added; nothing removed from any role (one source, `menuItemsFor`). Deviation 3 (coordination roles on a phone have one tab, "Ausnahmen" under "Mehr"): from the team-autonomy side this is right, since the phone is the team's tool and exceptions work happens at a desk (P-40); a product call for the PO and `uxa`. Supported.
- **UX2-27, UX2-29 (#800, open):** display text only ("von <Name>", "Verantwortlich", "noch niemand"); one word set across `/field` and `/visits` removes a translation step for the reader. No step added. CGR-108 and CGR-109 are `cra`'s wording questions; `aia` adds nothing. ADR-132 note 1 (AIG1 lines still say "Zuständig") is `uxa`'s.
- **UXR-73, UXR-74 (#798):** `uxa`'s; UXR-74's count cap on the proposals link adds no step.

### 3 AI readiness of delivered items (§8)
- **Nothing merged since review 17 proposes, drafts or ranks.** #792 is a runbook in which a person decides each legacy name; NAVORA does no name-to-member matching and the runbook forbids writing a matching rule (§5c step 3). That is the "no automatic coding" boundary applied to data reconciliation. No §8 check due.

### 4 Findings closed
- **AUT-27 closed:** built as proposed in RLS4-C1 (#792 merged `6fd9507`; CI green as Engineering and `cra` #801 report): the review list is grouped by team and legacy name on the live project only; a person decides **once per name and team**, a doubtful name visit by visit; the mapping applies in one transaction with a membership guard and a row-count check; count before and after, who and when in the reconciliation record; no names or mapping in the repository; pgTAP 105 on a synthetic fixture. The live reconciliation itself stays OPEN for the D-1 owner (G-25).
- **AUT-30:** adopted as AIG1-C5 (PO 02:55); closes when built. **AUT-31:** adopted into PLAN3-13; closes with PLAN3.
- AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21, AUT-25, AUT-28 (P-38): unchanged.

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 governance layer | met on synthetic data (unchanged); AIG1-C4 and **AIG1-C5** PLANNED (*Active now* (2)) before the first agent other than the synthetic test agent |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, *Active now* (3), after RLS4-C1/-C2 (**delivered**, #792) and UX2 (#799, #800 open) |
| 0 | Baseline for ranks 1-3 (AUT-32) | OPEN (P-19 not briefed) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged |
| 1 | Owner releases stage 1 (provider, region, contract) | not decided (owner, D-35), unchanged |

### 6 Waiting for the PO
- **AUT-32 (medium):** whether P-19 is briefed now as a read-only AN1 extension, placed before G-19, so the pilot's first month is the baseline for ranks 1-3.
- AUT-30 / AIG1-C5 and AIG1-C4: build (in *Active now*). #793 can be closed by the PO when built.
- P-36 undo alternative (review 15), AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: next due 2026-11-10.

### 7 Issues and comments
- No `high` finding: no issue opened. No comment on an open PR (#799, #800 have no `aia` finding).

---

## 2026-10-31 02:40 CET · aia review 17: AUT-29 closed (AIG1-C1 built, #787, 0104); AUT-23 closed; AIG1-C2/-C3 and AIG1-C4 (PO PR #791) supported; AUT-30 (high: the stop's look-back is tied to the agent's state, so switching a stopped assistant off or on drops open lines from every screen, and at "0 offen" the exception never ends while it stays stopped); AUT-31 (low)

**Read:** `recovery/main` at `1275708`:
- merged since review 16 (#775): #776 (AIG1 part (b) UI, ADR-129), #778, #780, #777, #783, #781 (CGR-96 test fix), #784, #786, #785 (`uxa` 23:55), **#787** (AIG1-C1, -C2, -C3, migration 0104, ADR-130), #789, #790 (`lca` 01:40);
- open: PO **#791** (02:25: AIG1-C1/-C2/-C3 met, **AIG1-C4**, **PLAN3-13**; read on its branch `b09b395`), `cra` #788 (01:30, CGR-106, CGR-107; read on its branch), #782 and the earlier `cra` chain;
- open issues labelled `automation`: #774 (AUT-29; met, see §4).

**Nothing below is a measurement.** I ran no tests. CI as the PO reports it on #791 (head `65a1278` and merge commit `c6f038b`: `app`, `db`, `e2e`, `ui-screenshots` green); not re-read by me. Code read: 0097 (`set_agent_state`, `agent_health`, OPS1 `agent_stopped`), 0104, `src/app/(protected)/operations/assistenten/page.tsx`, `tests/e2e/aig1.spec.ts`.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-30 | After a stop: Operations and the organisation administrator deciding what to do with a stopped assistant; team members and Operations working its look-back list (AIG1-12) | **IMPLEMENTED, from code (not run):** the OPS1 exception `agent_stopped` and its "<n> offen · <m> nicht mehr offen" exist only `where g.state = 'stopped'` (0097 `derived_exceptions`, patched by 0104); the health list returns `stop_id`, and so the link "Betroffene Werte ansehen", only for `state = 'stopped'` (0097 `agent_health`: `left join ai_agent_stops st on st.id = s.last_stop_id and s.state = 'stopped'`; `assistenten/page.tsx:69-77`). `set_agent_state(…, p_on => false)` moves a `stopped` agent to `off` with no check of open lines (0097:519-524); a new switch-on also ends `stopped`. **Two effects:** (1) an administrator who switches a stopped assistant **off** ("we no longer use it", the natural act after a stop) or **on** again removes every screen path to the stop's still-open lines; they remain only at the bare address `/operations/assistenten/rueckblick/<stopId>`. PLAN3-11 (team entry) is keyed on `stopped` too. That is the "silent leave" `lca` proviso (a) and CGR-95 exclude; no brief criterion (AIG1-8, -12, -C1) states what happens to open lines on off or on. (2) Conversely, once every open line is handled the exception stays "0 offen · <m> nicht mehr offen" for as long as the agent stays stopped (AIG1-C1 (4), PO 21:25): a P2 to-do with nothing to do, cleared only by the same off/on act. **No patient-care benefit is shown** for an exception that outlives its work, or for losing a path to open lines | **rule, no new step, more safety:** key the stop's follow-up on its **open lines**, not on the agent's state. (a) One OPS1 exception per stop with at least one open line, whatever the agent's state now (`stopped`, `off` or `on`); it closes by itself at "0 offen". (b) The health list shows each stop with open lines and its link, whatever the state; a stop at "0 offen" stays readable from the agent's row as history ("gestoppt am <Datum> · 0 offen · <m> nicht mehr offen"), not as an exception. (c) The agent's state stays shown as status ("Gestoppt seit …", "Aus") on the health list and PLAN3-6 on `/team`, never as a to-do. (d) PLAN3-11 keys on open lines of the team's stops, not on `stopped`. Nothing about re-check duty is set (D-17, UNKNOWN). Testable criteria on the issue | L | stage 0 (before the first agent other than the synthetic test agent, with AIG1-C4); PO (amend AIG1-8/-12 and AIG1-C1 (4)); `cra` (CGR-95, H-20: confirms nothing is lost); `lca` (proviso (a): stronger, no new read or role); `uxa` (status vs exception wording) | per team and stop: stops whose agent was switched off or on with open lines (should be 0 lines lost: the exception stays); days from stop to "0 offen"; days an exception shows "0 offen" (should be 0); switch-ons within 24 h of a stop (restart pressure, H-20). Never per person | high | #793 |
| AUT-31 | Proposals that expire undecided (AIG1-C4, PLANNED): team members on `/team/vorschlaege`; Operations on `/operations/assistenten` | PLANNED (PO 02:25, #791): an undecided proposal of a visit no longer open leaves the list without a human act, is not a correction, and is counted "Abgelaufen ohne Entscheid: <n>" per agent and window. Supported (eliminate). The open question (AIG1-C4 (4), D-17) is whether expiry is the assistant's fault; from the team side the answer that matters is **lead time**: a proposal that arrives after the team has already planned by hand returns no care time. Share expiring per team: UNKNOWN (no agent built) | **monitor, no step:** PLAN3's usefulness measure (with AUT-25's "no proposal" share) adds, per team and window, the expired share and the median time from proposal to visit start of decided vs expired proposals. Not a stop criterion and not shown to the team as a fault; it tells the PO whether proposals come early enough to be used (PLAN3 generation time) | L | stage 0; PO (PLAN3-13 or PLAN3 measure line) | expired share per team and window; median proposal-to-visit lead time, decided vs expired. Never per person | low | report only |

**Briefs and items reviewed without a new finding:**
- **AIG1-C1 as built (0104, ADR-130):** see §4 (AUT-29). Deviation 1 (no rejection of an applied value) removes a path that would silently drop a listed line; supported.
- **AIG1-C2 as built:** the team member re-confirms or changes an open-visit value one by one on the record page, refusals show their reason, coordinators get no control. This is the first team-side exit from a look-back line; it puts the act with the people who plan (no dispatcher). `record_lookback_lines` returns only the record's own team's lines, no person column: supported. CGR-106 tests ("Ändern") go into AIG1-C4 (5): supported.
- **AIG1-C3 as built:** back link by origin, refusals on their line with both counts, 44 px tick rows, flag in the "Mindestzahl" cell. Fewer dead ends and re-taps on the phone; no step added. Supported.
- **UXR-71 first half not adopted (PO 02:25):** a rejection changes nothing on the visit (ADR-130 decision 13), so a confirm step after "Ablehnen" would add a tap to every correct rejection for no safety gain. Supported; this is the challenge duty applied by the PO.
- **AIG1-C4 (1)-(3) (#791):** the PO's question "why must a nurse reject a proposal time has made moot?" is the right one; filtering on read, no write, and a separate expired count keep the stop share honest without anyone's act. Supported, with AUT-31 as the measure addition.
- **PLAN3-13 (#791):** the P-6 measure extension placed before the first non-test agent, per stop and team, no person column. It is where AUT-30's measures belong. Supported.
- **P-40 (PO 00:10, hypothesis):** Operations needs counts per team, the team needs the lines. Consistent with AUT-30 (b)-(c); supported as a pilot hypothesis.

### 2 AI readiness of delivered items (§8)
- **#787 (AIG1-C1/-C2/-C3):** suggestion ledger and provenance per value unchanged (IMPLEMENTED). **Named confirmer:** a re-confirmation or change on the record page is the team member's own `confirm_suggestion`, with the AIG1-15 checks; on a visit no longer open nothing is recorded (`not_open`, IMPLEMENTED). **No accept-all on listed fields:** look-back values one by one only (AIG1-13 (a), IMPLEMENTED); bulk refusals now stay on their line (AIG1-C3 (2)). **Correction rate per agent and field:** unchanged; expired proposals still count as decided only through a rejection until AIG1-C4 (PLANNED). **Stop rule:** IMPLEMENTED; its follow-up depends on the agent's state (AUT-30, OPEN). **Evaluation on synthetic data:** pgTAP 104, `aig1.spec` tests 3-8, seed organisations E and F (CI per the PO).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 governance layer | **met on synthetic data**: AIG1 `accepted` (PO 22:15), AIG1-C1/-C2/-C3 met (PO 02:25, #791 not yet merged); AIG1-C4 and AUT-30 (if adopted) PLANNED before the first agent other than the synthetic test agent |
| 0 | First real stage-0 agent (PLAN3) | PLANNED: PLAN3 (with PLAN3-11, -12, -13) after RLS4-C1/-C2 and UX2 in *Active now*; AIG1-C4 in or before the PLAN3 PR |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged; past-visit rectification (DSG Art. 32) UNKNOWN in D-35, Clinical Owner (D-17) and legal adviser after D-11 |
| 1 | Owner releases stage 1 (provider, region, contract) | not decided (owner, D-35), unchanged |

### 4 Findings closed
- **AUT-29 closed:** built as written in AIG1-C1 as amended (0104 `aig1_apply_visit_responsible` refuses re-confirmation and correction `not_open`, no row; `agent_stop_lookback.not_open`; OPS1 detail "<n> offen · <m> nicht mehr offen"; pgTAP 104 "0 offen · 3 nicht mehr offen" with the agent `stopped`; e2e test 4 and 8), merged as `c6f038b` with CI green as the PO reports; PO 02:25 "met". #774 can be closed by the PO. The part of AUT-29's concern that remains (the exception's life is keyed on state) is new evidence and is AUT-30, not a reopening.
- **AUT-23 closed:** (a) bulk refused on listed values and (b) "überholt am <Datum>" labelled and out of the open count, now also on screen (`aig1.spec.ts:155-177`).
- AUT-25 closes with PLAN3 (AUT-31 adds to the same measure). AUT-27 closes when RLS4-C1 is built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21, AUT-28 (P-38): unchanged.

### 5 Waiting for the PO
- **AUT-30 (high):** answer before the first agent other than the synthetic test agent (same deadline as AIG1-C4); amend AIG1-8/-12 and AIG1-C1 (4), or state the patient-care benefit of keying the stop's follow-up on the agent's state.
- AUT-31 (low): optional addition to PLAN3-13 or PLAN3's measure line.
- P-36 undo alternative (review 15), AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32, care-plan maintenance after reassessment with P-38).

### 6 Issues and comments
- AUT-30: issue #793 opened; one comment on PO PR #791 (AUT-30, AUT-31, AUT-29 closed).

---

## 2026-10-30 20:18 CET · aia review 16: AUT-26 closed (#747 merged, ASM1 accepted); AUT-28 adopted as P-38; AIG1 part (b) database half (#770, 0103) §8 check: AIG1-15/-16 supported; AIG1-C1 (PO PR #769, not merged) read: AUT-29 (high: a past-visit look-back line can never leave "offen", so the stop exception clears only by switching the agent back on)

**Read:** `recovery/main` at `65fe6e6`:
- merged since review 15 (#756): #747 (ASM1-C1 to -C5, C4 (d), `752ecbc`), #757, #759, #760 (PO 15:55: ASM1 `accepted`, P-38), #761 to #765 (WORK1-C5, CGR-96 test fixes), #767 (PO 17:45), #768, #773 (`lca` 17:45, 19:45), #770 (AIG1 part (b) database half: AIG1-15, AIG1-16, migration 0103, ADR-128, pgTAP 103), #771;
- open: PO #769 (18:25 + 20:25: CGR-96 back to (0), P-37 in force, ASM1-C6 (8) (iv)/(v) narrowed, AIG1 part (b) database half reviewed, **AIG1-C1**; read on its branch), `cra` #766, #753 and earlier;
- open issues labelled `automation`: none at start (#732 closed by the PO 15:55).

**Nothing below is a measurement.** I ran no tests. CI as reported by the PO and `eng` (check runs on #770 head `89b0afb` and merge commit `6c1a83f`: `app`, `db`, `e2e`, `ui-screenshots` green); not re-read by me.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-29 | After an assistant is stopped (AIG1-8): team members and Operations working the AIG1-12 look-back list; the OPS1 exception "Assistent gestoppt" | **Challenge of the form of AIG1-C1, not of what it declines to write** (no "bestätigt" on a past visit: supported). IMPLEMENTED: a **correction** of a visit no longer open is refused `not_open` (0103:66-69); the OPS1 detail counts every non-superseded line as "offen" (0097 `derived_exceptions`), and the exception closes only when the agent is switched on again (0097 comment). PLANNED (AIG1-C1, PO 20:25, #769 not merged): a **re-confirmation** of such a line is refused too, the line stays and **still counts as open**. Result: a past-visit line has no exit at all (not re-confirmable, not correctable, not `superseded` because the record still holds the value), so "<n> offen" can never fall to what can still be acted on, and the only way to make it go away is to restart the stopped assistant (the pressure runs against H-20). No patient-care benefit is shown for counting unactionable lines as open. Share of past-visit lines per stop: UNKNOWN (no agent built); structurally high, since the threshold window is closed and PLAN3 proposes responsibility for visits that are mostly performed by the time a stop is read | **rule, no new step, equal safety:** keep AIG1-C1's action (no confirm control, `not_open`, no `ai_confirmations` row, line not removed, opens its record). Label the line as a visit fact, like `superseded`: "Besuch nicht mehr offen" with the visit date (`uxa` wording); **not counted as open**; OPS1 detail shows "<n> offen · <m> nicht mehr offen". NAVORA sets no re-check rule; if the Clinical Owner names fields after G-1 (D-17, UNKNOWN), those go to the CIRS/incident path, not to a confirm click. Testable criteria on #774 (pgTAP: past-visit line listed, flagged, out of the open count, no person column; re-confirm and correct both refused with no row; `0 offen` reachable while the agent stays `stopped`; e2e: sentence, no confirm control, both counts) | L | stage 0 (AIG1-C1 / part (b) UI); PO (amend AIG1-C1 before the UI PR), `uxa` (wording), `lca` (terms (i)-(iii) unchanged; label is a visit fact, no person), `cra` / Clinical Owner only for re-check duty | per team and stop: lines at stop; left by correction, by re-confirmation; "überholt"; "nicht mehr offen" at stop and **became** "nicht mehr offen" while listed (whether the list is worked in time); days to `0 offen`. Never per person | high | #774 (comment on #769) |

**Briefs and items reviewed without a new finding:**
- **AIG1-15 as built (0103):** a look-back re-confirmation on an open visit runs `may_perform_visit`, `adm2_in_contract`, `member_absent_during` in the first confirmation's order; refusal writes no row and the line stays (pgTAP 103 per PO 20:25 table). It also covers a first confirmation meeting a hand assignment (ADR-128, accepted). No step for anyone; it makes "bestätigt von" mean a check ran. Supported.
- **AIG1-16 as built (0103):** share ≥ 100 refused `threshold_missing`; `agent_health` returns share, minimum, window and `last_window_min_reached`, null before the first closed window (ADR-128 deviation 1, accepted). Monitoring of the monitor at no team cost. Supported; the null case needs its own sentence in the UI (`uxa`), as the PO states.
- **P-37 in force (PO 18:25, #769) with the `cra` "Ersetzen" sentence:** one tap for the common cause, free text only for "Anderer Grund", one sentence that steers a wrong value to "Ersetzen". The sentence is read, not answered: no extra tap; it protects the correction chain (H-05). Supported (review 15).
- **ASM1-C6 (8) (iv) narrowed (PO 18:25):** no review act "against nothing"; the sentence stays until a new record exists. No step added; it keeps a true fact visible. Supported.
- **CGR-96 back to (0), WORK1-C5 (b) watch rule, e2e own-data rule (PO 16:55, 17:45, 18:25):** test-only; no nurse or team step. The rule "a red privacy test is a finding with a name, not a re-run" is monitoring done right. Supported.
- **P-38 (PO 15:55) = AUT-28:** adopted as a pilot hypothesis in the measured form `aia` proposed (C4 acts within 24 h of a record, markers older than 14 days, team level), never bundled into the save. AUT-28 adopted; it closes when P-38 is evaluated.

### 2 AI readiness of delivered items (§8)
- **#770 (AIG1 part (b), database half):** suggestion ledger, provenance per value, confirmer per value only: unchanged from part (a) (IMPLEMENTED). **Named confirmer:** a re-confirmation now stands for the same checks as a first confirmation on open visits (AIG1-15, IMPLEMENTED); on past visits it still returns `ok` without checks until AIG1-C1 is built (PLANNED, with AUT-29 on its count). **No accept-all on listed fields:** unchanged (AIG1-13 (a), IMPLEMENTED). **Correction rate per agent and field:** unchanged. **Stop rule:** a threshold that cannot fire is refused, and the health read shows threshold and minimum reached (AIG1-16, IMPLEMENTED at database level; screen PLANNED). **Evaluation on synthetic data:** pgTAP 103 on the synthetic test agent only; no real agent. Still no AI service and no real data (D-1 precaution).
- **#747 (ASM1), #761, #764:** propose, draft and rank nothing.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | ASM1 built | **met on synthetic data** (#747 merged `752ecbc`, PO `accepted` 15:55); ASM1-C6 with C6 (8) PLANNED before the first real assessment record |
| 0 | AIG1 part (b) | database half IMPLEMENTED (#770, `6c1a83f`); UI half PLANNED; AIG1-C1 PLANNED (with AUT-29); `cra` section on 0097/0103 not yet merged |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, unchanged; AIG1-C1 must hold before any agent other than the synthetic test agent is switched on (PO 20:25) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged |

### 4 Findings closed
- **AUT-26 closed:** ASM1-C4 merged unchanged in substance (#747, `752ecbc`; CI green on head `6339c24` and on `recovery/main` `5ce5feb` as the PO reports), ASM1 `accepted` (PO 15:55), #732 closed by the PO.
- **AUT-28 adopted** as P-38 (PO 15:55); stays open as a hypothesis until evaluated.
- AUT-23: (a) and (b) IMPLEMENTED at database level; closes with the part (b) UI e2e ("überholt"). AUT-25 closes with PLAN3. AUT-27 closes when RLS4-C1 is built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21: unchanged.

### 5 Waiting for the PO
- **AUT-29 (high, #774):** answer before the AIG1 part (b) UI PR; amend AIG1-C1 or state the patient-care benefit of counting past-visit lines as open.
- P-36 undo alternative (review 15), AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32, care-plan maintenance after reassessment, now with the P-38 measure).

---

## 2026-10-30 15:04 CET · aia review 15: AUT-26 met in code on #747 (ASM1-C4, 0101; CI green, `cra` clear to merge; closes on merge); P-37 preset void reason supported; CGR-104 / ASM1-C6 (8) and P-35 supported; AUT-28 (low: a reassessment and the plan review are two separate acts on two screens, measure first)

**Read:** `recovery/main` at `29d751e`:
- merged since review 14 (#733): #735 to #752 PO, `lca`, `uxa` cycles (PO 08:15 to 13:28, `lca` 08:42 to 13:42, `uxa` 11:55), #742 (UX2-22/-23, `ea94bba`), #727 (ASM1, `e42fde6`, PO `changes-requested` 10:15);
- open: **#747 (ASM1-C1 to -C5 and C4 (d), migration 0101, ADR-125, head `fcb84eb`)**, PO #755 (15:00: CGR-104 as ASM1-C6 (8)), `cra` #753 (13:30) and its chain (#737, #723 and earlier);
- briefs changed: ASM1 (C4 decided 09:15 = AUT-26, C4 (a)-(c) `cra`, C4 (d) = UXR-60, C5, C6 with (7) output rule, P-37 proposal), UX2 (ADR-124 deviation 1 answered 11:10); D-13 (`lca` 09:40 to 13:42), D-4 item (7);
- open issues labelled `automation`: #732 (AUT-26) only.

**Nothing below is a measurement.** I ran no tests. CI read by me as GitHub check runs on #747: `app`, `db`, `e2e`, `ui-screenshots` success.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-28 | Reassessment, then plan review (ASM1-1 record, ASM1-C4 act): the team's registered nurse | PLANNED to be IMPLEMENTED with #747. After she records a new assessment on the case card, the plan shows "Neuere Bedarfsabklärung vom <Datum>" and she then opens the care-plan block, scrolls past the categories to the review command (C4 (d): last in the block) and confirms once more (confirming step). Where the same nurse does both on the same visit to the record, that is two places and three taps for one sitting. How often the recorder and the reviewer are the same person and the same day: UNKNOWN (no data; synthetic seed only). The separation itself is a clinical control (the plan review is a distinct judgement, `cra` (a)-(c)) and is not challenged | **measure first, then simplify the path, same control:** count per team and month how many C4 acts follow a new record of the same case within 24 h, without naming who. If most do, propose that the record's saved state offers the same review act as a second, separate, not preselected command ("Pflegeplan jetzt prüfen", jumping to the care-plan block with the marker still shown), never a checkbox inside the assessment save and never an act recorded by the save itself. Whether a plan review may be offered at that moment is `cra`'s; nothing bundled before that | L | stage 0; PO (whether to measure in the ASM1 pilot hypotheses), `cra` (whether offering the act there weakens the review), `uxa` (where) | per team and month: C4 acts within 24 h of a new record of the same case / all C4 acts; median days from record to act (AUT-26 measure). Never per person | low | – (report) |

**Briefs and items reviewed without a new finding:**
- **ASM1-C4 as built on #747 (AUT-26): met in code.** `review_care_plan_against_assessment` (0101:104) inserts one append-only row into `care_plan_assessment_reviews` (no grant, no policy, 0101:57-58) and changes no `care_plan_items` row: pgTAP 101 compares an md5 over the case's items before and after (101:80), refuses an assistant, another team's nurse, another organisation and a non-current record (101:117-136), clears `plan_without_basis` with one act (101:123), and asserts PLAN2 visits, minutes and billing facts unchanged (101:169). AUT-26 closes when #747 is merged unchanged in substance.
- **ASM1-C4 (d) one confirming step (UXR-60, PO 12:14, `cra` keeps it):** one extra tap on a rare act (once per reassessment or correction per case) guarding an S2 fact; a patient-care benefit is shown, so no challenge. P-36 (cancellations per team and month) is the right exit test; `aia` adds one lean alternative for when P-36 says drop it: an undo command on the recorded line ("Prüfung zurücknehmen", append-only, restores the marker) instead of the step, equal safety for a mis-tap.
- **P-37 preset void reason (PO 13:28, `lca` 13:42 compliant):** supported. It removes typing for the expected common cause and keeps another client's details out of free text: less administration and more privacy at once. Measure: share of voids with "Anderer Grund" per team and month (shows whether the preset fits). Nothing preselected (`lca` (a)). `aia` is not one of the confirmers P-37 needs (`cra` or `uxa`).
- **ASM1-C6 (8) basis by identity (`cra` CGR-104, PO #755):** no step for anyone; it makes the marker true after a same-date record or a void, so the team is not sent to review a plan that needs none, nor left without a marker it needs. Supported.
- **ASM1-C6 (7) standing output rule (PO 13:28):** a test duty on each later brief, no nurse step. Supported.
- **ASM1-C1 as built (`/field` "Zu bestätigen: Bedarfsabklärung (<n>)"):** her own read path, `info`, gone on confirm or supersede. Removes chasing between colleagues. Supported (review 14).
- **P-35 (PO 11:10, organisation-wide admission off-switch):** supported. The off-switch is a hierarchy step over every team's own admission; a team-controlled pause keeps the same safety (qualification and contract checks stay). ADR-124 deviation 1 (no lapse pause while off) is data minimisation, not administration; not challenged.
- **UX2-22 (`/field` hides acts for a missing qualification) and UX2-23 (one confirming step for the admission switch and "Vertragsende entfernen"):** UX2-22 removes refused attempts at the door. UX2-23 sits on rare administrator acts with organisation-wide or contract effect; not challenged.

### 2 AI readiness of delivered items (§8)
- **#747 (ASM1-C1 to -C5):** proposes, drafts and ranks nothing; no ledger entry needed. The C4 act is the confirmation end point a later A10 proposer would use: it stores the record and the record's state at the act (`cra` (a)), so a later proposal can be tied to the exact record it was made against (provenance per value, §8). The act's actor is not selectable (pgTAP 101:105-108), consistent with AIG1-11.
- **UX2-22/-23 (#742):** propose nothing.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | ASM1 built | #727 merged; C1 to C5 and C4 (d) on #747 (CI green, `cra` clear to merge, not merged); acceptance by the PO after merge; C6 PLANNED before the first real assessment record |
| 0 | Plan basis read by record identity (needed before any proposer reads "the plan's assessment") | PLANNED (ASM1-C6 (8), PO #755) |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, unchanged |
| 0 | AIG1 part (b) | not started (#705) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged |

### 4 Findings closed
- None closed this run. **AUT-26:** met in code on #747 (evidence above); closes on merge. AUT-23 closes with AIG1 part (b) (#705). AUT-25 closes with PLAN3. AUT-27 adopted in RLS4-C1 (1) (PO 09:15); closes when RLS4-C1 is built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21: unchanged.

### 5 Waiting for the PO
- **#747** merge and the ASM1 review; AUT-26 / #732 closes with it.
- **AUT-28 (low):** whether the ASM1 pilot hypotheses count C4 acts within 24 h of a new record (team level).
- **P-36:** the undo alternative above, if the step is dropped.
- AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32, care-plan maintenance after reassessment).

---

## 2026-10-30 08:25 CET · aia review 14: AUT-24 closed (RLS4 delivered, #715, 0099); AUT-25 adopted (PLAN3-7); ASM1 #727 read: AUT-26 (high: the only way to clear "Neuere Bedarfsabklärung" is to retire and retype every care-plan item); AUT-27 (medium: RLS4-C1 maps legacy names visit by visit); RLS4-C2, ASM1-C1, VIS2-C3 supported

**Read:** `recovery/main` at `b6559ea`:
- merged since review 13 (#714): #712, #719, #725, #728 (`lca` 01:50 to 06:41), #716, #718, #720, #726, #729 (PO 03:10 to 07:20), #717, #730 (`uxa`), **#715 (RLS4, migration 0099, ADR-122, merge `d148f7f`)**, #722 (RLS4-5 (c) evidence);
- open: **#727 (ASM1, migration 0100, ADR-123, head `ad98160`)**, PO #731 (08:15: ASM1-C1 to C3, UX2-30), `cra` #723 (05:30: CGR-101) and its chain (#711 and earlier), #721;
- briefs changed: RLS4 (RLS4-3 addendum = AUT-24, RLS4-5/-6, accepted 06:10 with RLS4-C1; RLS4-C2 at 07:20), PLAN3 (PLAN3-7 amended = AUT-25), VIS2 (VIS2-C2, VIS2-C3), UX2 (UX2-28, -29; UX2-30 on #731), ASM1 (ASM1-C1 to C3 on #731); gate G-25 added (`CARE_OPERATING_MODEL.md`);
- no open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests. CI read by me as GitHub check runs: #715 head `bc47bee` and #727 head `ad98160`: `app`, `db`, `e2e`, `ui-screenshots` success.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-26 | Care plan after a reassessment (ASM1-7): the team's registered nurse who keeps the care plan current | **Challenge (ADR-123 deviation 2, OPEN; #727 not merged).** As built in 0100: `care_plan_items.assessment_id` is set only by the insert trigger; the plan's basis is the oldest current assessment among active items, and "Neuere Bedarfsabklärung vom <Datum>" shows while any active item rests on an older record **or was written before any record** (`team_case_assessments`, `plan_without_basis`). The only way to clear it is, per item, `retire_care_plan_item` with a typed reason (0014:395-414) and a new item with service, category, minutes per occurrence, frequency text and, where used, PLAN2's structured frequency, weekdays and window (0025). For a plan of n items: 2n actions and n retyped items, even when the assessment changed nothing in the plan. Two costs: (1) **administration without patient-care benefit**: retyping an unchanged plan proves no review; (2) **a new hazard**: a retyped frequency or window feeds PLAN2 visit generation (transcription error, H-24 pattern), and a team that does not retype keeps a marker that never clears, so the marker turns into noise on every case card (all pre-ASM1 plans show it as soon as one record exists). Effort per plan: UNKNOWN (not measured); the pattern is one review act being replaced by n rewrites | **rule (one confirmed act), no rewrite:** a per-plan command "Pflegeplan gegen Bedarfsabklärung vom <Datum> geprüft" by a named team member, audited per record (actor per record only, RLS4 pattern), that sets the plan's basis to the current record without changing any item; items the review finds wrong are changed with the existing commands. Which qualification may confirm (a registered nurse?) is `cra`/Clinical Owner (UNKNOWN; not invented here). No due date, reminder or signal (ASM1 negative unchanged). Later (A10, D-35 stage 1 or later): the review act is the confirmation an assistant's draft would end in, value by value, never accept-all on care-plan fields (§8) | L (the act); the qualification rule G if `cra` says so | stage 0; PO (deviation 2 answer before ASM1 acceptance), `cra` (who confirms), `uxa` (where the act sits on the card) | per team and month: median days from a new assessment record to the plan's basis matching it, and the share of cases with an open marker older than 30 days (display window, no clinical meaning); balancing: care-plan items retired and re-added on the same day per team (should fall). Never per person | high | #732 |
| AUT-27 | Data reconciliation before G-25 (RLS4-C1 (1)): the person doing the D-1 live reconciliation | PLANNED (RLS4-C1, accepted 06:10; not built). The runbook check returns the **count** of future, non-cancelled visits with `team_member_name` and no `responsible_user_id`; "a person maps **each such visit** to a member or confirms it unassigned". With PLAN2 generating visits ahead, one nurse's name stands on many future visits; visit-by-visit mapping repeats one decision per occurrence (e.g. one team with weeks of generated visits: hundreds of identical decisions; UNKNOWN on real data, D-1). The control itself (a person decides, no automatic matching, count before and after) is a patient-safety control (H-10, H-01) and is not challenged | **simplify, same control:** the runbook groups the remaining visits by team and legacy name (shown only on the live project, never in the repository); the person decides **once per name and team** (member, or unassigned) and that decision is applied to that name's future visits in the group; a name that two members could carry, or that the person is unsure of, is decided visit by visit; the count check still must return 0, and the record keeps count before and after, who and when (no names, no mapping in the repository, as RLS4-C1). Still no automatic name-to-member matching: every name is decided by a person | L | stage 0; PO (RLS4-C1 wording), `eng` (runbook), D-1 owner; `lca` aware (D-1 notes) | the decisions made per reconciliation (one per name, plus exceptions) against the visit count; the check returns 0 | medium | – (report) |

**Briefs and items reviewed without a new finding:**
- **RLS4-C2 (PO 07:20, `lca` 06:41):** removes a standing per-employee documentation-backlog list held by the employer; the list appears only in the access-end step. Less hierarchy, no step for the team, no open report hidden from anyone who must act. Strongly supported; the same reasoning as COND1-5a and PLAN3-10.
- **ASM1-C1 (on #731, `uxa` UXR-59):** a confirmation step the confirming nurse cannot see becomes phone calls between colleagues; one count line in her existing "Zu erledigen" removes that coordination. No reminder, no per-person count for anyone else. Supported; this is what makes ASM1-5 cheap.
- **ASM1-C2, ASM1-C3 (on #731):** less scrolling, fewer second attempts; no step. Supported.
- **ASM1-5 (named assessor confirms), ASM1-2 (supersede with a reason):** D-13 criteria from `lca` and `cra` (legal and safety duty); not administration to remove; form not challenged (one tap, only when someone else entered the record).
- **ASM1-11 as built (no sum, items as written, dated facts younger than the assessment):** a display of recorded facts, no signal; the right design order (care graph first). Supported.
- **UX2-30 / UXR-57 (prefill instrument and assessor on a replacement):** ADR-123 trade-off deliberately does not prefill them. Prefilling the person's own earlier record is not an agent proposal (no ledger needed), but it is a value carried over without a look; `cra` weighs it with UX2-30. No finding from me.
- **VIS2-C2, VIS2-C3 (save step only when another team's visit overlaps the edited interval):** a patient-safety fact (double booking at the client's door) shown once, nothing refused, and the PO declined a per-person log of look-ups (option (b), (y)). The step appears only in the rare overlap case; not challenged.
- **UX2-28, UX2-29:** wording; no step. Supported.

### 2 AI readiness of delivered items (§8)
- **RLS4 (#715):** proposes, drafts and ranks nothing. Its act-closing pattern (actor per record only) is the one AIG1-11 already uses for confirmers; consistent.
- **ASM1 (#727, not merged):** proposes, drafts and ranks nothing; nothing is computed from the record; no ledger entry needed. Provenance per value for a later import (AUT-13, `cra` condition (3)) is not built and not needed until an import is briefed. AUT-26's review act is the future end point of A10 (care-plan review proposer).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | ASM1 built | **in review** (#727, CI green on `ad98160`); acceptance after ASM1-C1 to C3 (#731) and the `cra` read; deviation 2 (AUT-26) OPEN |
| 0 | Per-record acts readable only per record (prerequisite for any per-value confirmer display) | **IMPLEMENTED** (RLS4, #715, 0099; G-18 met 06:10) |
| 0 | First real stage-0 agent (PLAN3) | PLANNED; AUT-25 measure now in PLAN3-7 |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution; G-25 added for real visit data) |
| 0-3 | other conditions unchanged from review 13 | as stated there |

### 4 Findings closed
- **AUT-24 (low): closed with evidence.** RLS4-3 addendum IMPLEMENTED: pgTAP 099:291-293 asserts `my_signals()` still returns `taken_by_name` for an open, taken signal to a team member; `safety_signals.taken_by` closed as a raw column (0099:55; pgTAP 099:72); CI on #715 head `bc47bee` green (check runs read by me).
- **AUT-25 (low): adopted** by the PO 03:10 in PLAN3-7 as proposed (share of "kein Vorschlag" per team and month by reason; no stop criterion). Closes when PLAN3 is delivered with that measure.
- AUT-23 closes with AIG1 part (b) (#705, not started). AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21: unchanged.

### 5 Waiting for the PO
- **AUT-26 (high, #732):** answer ADR-123 deviation 2 before ASM1 acceptance: one confirmed review act per plan instead of retire-and-retype; `cra` on who may confirm.
- **AUT-27 (medium):** one wording change in RLS4-C1 (1): decide once per legacy name and team, exceptions per visit; before the RLS4-C1 PR.
- AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); care-plan maintenance after reassessment (AUT-26) added as a candidate next to onboarding contract to first visit, P-28, P-32.

---

## 2026-10-30 02:18 CET · aia review 13: AIG1 part (a) delivered (#701, 0097), §8 readiness checked, AUT-22 closed; VIS2 delivered and (PR #713) accepted; PLAN3-10 supported; AIG1-15/-16, VIS2-C1 supported; AUT-24 (low, RLS4 signal taker), AUT-25 (low, PLAN3 has no "no proposal" measure)

**Read:** `recovery/main` at `183748f`:
- merged since review 12: #695 (review 12), #698, #704, #708 (PO 23:15, 00:15, 01:10/01:45), #702, #706 (`lca` 23:50, 00:40), #685 (`uxa`), **#701 (AIG1 part (a), migration 0097, ADR-120, merge `85a4fd6`)**, #703, **#707 (VIS2, migration 0098, ADR-121, merge `4c8f2a6`)**, #709;
- open: PO #713 (02:10: VIS2 accepted with VIS2-C1; AIG1-15, AIG1-16), `lca` #712 (01:50), `cra` #711 (01:45: CGR-98, CGR-99, CGR-100) and its chain (#696 and earlier); issue #693 (CGR-96) open;
- briefs changed: AIG1 (AIG1-13, AIG1-14, part (a) review; AIG1-15/-16 on #713), PLAN3 (PLAN3-10 and its actor amendment), VIS2 (new, delivered), RLS4 (new, approved), J5 (invoicing note), OBS1, ADM2;
- no open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests. CI on #701 head: `app`, `db` (pgTAP), `e2e`, `ui-screenshots` success (GitHub check runs read by me); merge commits as the PO reports them.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-24 | Taking a P1 safety signal (SIG1) and seeing who took it: every team member on `/field` and Operations | **Not a challenge of RLS4 (it removes a per-person list and adds no step), a guard on its scope.** PLANNED (RLS4 approved 23:15, not built): RLS4-1 closes `safety_signals.taken_by` as an *act*. IMPLEMENTED today: while a signal is open, `taken_by` is how the team knows it is being handled: the signal reader returns `taken_by_me` and `taken_by_name` (0060:365-387) and the card says "übernommen von <Name>" (`src/features/signals/rules.ts:123`); unclaimed signals sort first (0060:387). So while open it works as an *assignment* (who handles it now), and after it ends as an act. If the reader output were lost in RLS4, teammates would phone round to find out whether a P1 signal is handled, or two would respond (H-04, patient safety, and direct care time). RLS4-2 and RLS4-3 already cover this in general wording ("each current reader keeps its output"; a column read as an assignment is named as a deviation); nothing names this column | **rule (test), no new step:** in the RLS4 PR, name `safety_signals.taken_by` in the ADR as act-and-assignment; the raw column may close (RLS4-1), and the open-signal reader keeps "übernommen von <Name>" for the team; add one pgTAP assertion that the reader still returns `taken_by_name` for an open, taken signal to an active member of its team (no per-person list: the reader is per signal, scoped to open signals of the team) | L | stage 0; PO (one line in RLS4-3 or the ADR), `eng`; `cra` aware (H-04, signal handling) | pgTAP as stated; after go-live, per team: share of P1 signals where a take attempt returned `duplicate` with "übernommen von" (0060:411-413), never per person | low | – (report) |
| AUT-25 | Day plan with PLAN3 (`/team`): the team member who assembles tomorrow | PLANNED (PLAN3 approved, PLAN3-7): measures are the shares confirmed unchanged and corrected, confirm actions per day plan, minutes from proposal to the last confirmed line, and continuity. A line with **"kein Vorschlag"** (PLAN3: the visit stays in the uncovered path, assigned by hand) is in none of them; ADR-120 deviation 4 (accepted 00:15) excludes `not_found` from the correction share and makes it no stop criterion, and AIG1-7 shows it only as a count per cell. Effect: the measure of PLAN3's gain (hand assembly removed) can look good while most visits still get no proposal. Share: UNKNOWN (not built) | **monitor, no new step:** add to PLAN3-7, per team and month, the share of the day plan's open visits that received "kein Vorschlag", by its stated reason (no primary nurse, not qualified, absent, outside contract; the reasons PLAN3 already shows), from the existing ledger (`not_found`) and refusal results; balancing measure as now. Read per team only, small-team suppression as AIG1-7. A high share points to missing care-graph data (primary nurse not set: J6), which the team can fix once, not to the agent | L | stage 0; PO (PLAN3-7 wording before build); no clinical content | the share itself, per team and month, before and after the team's PLAN3-10 switch date; target direction down | low | – (report) |

**Briefs and items reviewed without a new finding:**
- **PLAN3-10 (PO 00:15, actor amended 01:10), challenge test:** removes a central rollout decision (administrator) and gives it to the team; one audited switch per team, default off, actor per record only. Less hierarchy, no added step for daily work, and it gives PLAN3-7 its "before/after for that team" date. Strongly supported; this is the operating model as the owner describes it.
- **AIG1-13 as adopted (23:15) and built:** (a) one by one, as proposed; (b) labelled "überholt", out of the open count, not removed. The team gets the relief I sought (nothing to do by default for a superseded value) without NAVORA deciding the clinical re-check question. I accept the PO's form; it is better than my proposal at equal effort.
- **AIG1-14 (`uxa` UXR-49):** removes names from the look-back screen; no step. Supported.
- **AIG1-15 (CGR-98, on #713):** a re-confirmation that runs no check would put a nurse's name under a check that did not happen; the fix reuses the first-confirmation checks and adds no step. Patient-safety control; supported.
- **AIG1-16 (CGR-100, on #713):** refuses an arithmetic threshold that cannot fire, and shows threshold and "Mindestzahl erreicht" on the health list. This is monitoring of the monitor, the right design order; no step for a nurse. Supported.
- **VIS2 (delivered #707, accepted on #713):** a fact at the moment of planning instead of a later duplicate check by a coordinator (the "eliminate through the care graph" order); no tap, nothing refused. `p_overlap_shown` is recorded by the command, nobody types it. Supported.
- **VIS2-C1 (CGR-99, on #713):** the generation count is the measure of the hypothesis that hand planning and PLAN2 generation duplicate work (H-PLAN-dup). I propose no rule before the count exists; if the pilot shows a non-zero share, the leaner fix is in the care graph (generation knows the hand-planned visit), and its rule is the Clinical Owner's (UNKNOWN).
- **RLS4 (approved 23:15):** removes per-person act lists; keeps assignments; no step. Supported, with AUT-24.
- **J5 invoicing note (`lca` D-18):** a legal duty before invoicing (a person confirms overlapping facts); not administration to remove; not challenged. Its effort is bounded by VIS2 (overlaps seen at planning).

### 2 AI readiness of delivered items (§8)
**AIG1 part (a) (#701, 0097), checked against §8, database level:**
- Suggestion ledger: **IMPLEMENTED**, append-only for every role including owner and `service_role` (0097:239-257), input references ids only.
- Provenance per value: **IMPLEMENTED** (`value_provenance`); the screen line is part (b), PLANNED.
- Named confirmer: **IMPLEMENTED**, read per value or per record only; no table grant to `authenticated`/`anon` on the seven AIG1 tables, RLS on without policy (0097:228-238), pgTAP 097 AIG1-11 block (direct select, `select *`, `group by` refused).
- No accept-all on listed fields: **IMPLEMENTED** (field-class trigger, bulk only for `schedule` and while `on`, never a decided or look-back value; `check (not bulk or outcome = 'confirmed')`, 0097:220).
- Correction rate per agent and field: **IMPLEMENTED**, rule of three per cell. `not_found` excluded from the share (ADR-120 (4)): see AUT-25 for the usefulness side.
- Stop rule: **IMPLEMENTED**, evaluated lazily at the next proposal, bulk confirm or health read; OPS1 `agent_stopped`; look-back with "superseded". Gap found by `cra` (CGR-98) placed as AIG1-15; unreachable threshold as AIG1-16 (both PLANNED, #713).
- Evaluation on synthetic data: **IMPLEMENTED** (fixture harness, synthetic test agent, bar checked on every PR; switch-on without fixture refused).
- Only agent registered: the synthetic test agent. No real agent proposes anything yet; PLAN3 is the first (PLANNED).
**VIS2 (#707):** proposes, drafts and ranks nothing; a deterministic fact. No ledger entry needed.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | **part (a) IMPLEMENTED** (#701, 0097; CI green on head `4bc7236`); part (b) (screens, e2e) and AIG1-15/-16 PLANNED; acceptance also needs a `cra` section on 0097 (CGR-98 is S2 before acceptance) |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, *Next up*; now team-switched (PLAN3-10). Open: AUT-25 measure |
| 0 | Per-entry provenance in clinical records | IMPLEMENTED for observations (OBS1, OBS1-C1); drafts OPEN |
| 0 | ASM1 built | PLANNED, not started |
| 1 | Employee information names confirmations, look-back purpose **and the team switch** (D-9; `lca` 00:40 term (v)) | OPEN, owner (pilot precondition) |
| 1 | Real data may reach any test, pilot or AI path | blocked (owner precaution until D-1 is clarified; owner package required by D-35) |
| 1-3 | other conditions unchanged from review 1 | OPEN |

### 4 Findings closed
- **AUT-22 (high, #686, closed by the PO 21:15): closed with evidence.** AIG1-11 IMPLEMENTED in 0097 more strictly than proposed (no table grant at all; RLS without policy), pgTAP 097 AIG1-11 block; CI on #701 head `4bc7236` green (check runs `app`, `db`, `e2e`, `ui-screenshots`: success).
- **AUT-23 (medium):** (a) IMPLEMENTED (bulk of a listed value refused, 42501; pgTAP AIG1-13 block); (b) adopted in the PO's form and IMPLEMENTED at database level (`superseded`, `superseded_at`, out of the OPS1 open count). Stays OPEN only for the part (b) e2e ("überholt" shown); closes with part (b).
- AUT-21 (UX2-26), AUT-14, AUT-15, AUT-17, AUT-19, AUT-20: unchanged.

### 5 Waiting for the PO
- **AUT-25 (low):** one PLAN3-7 measure line before PLAN3 build. **AUT-24 (low):** one RLS4 test line before the RLS4 PR.
- AUT-19, AUT-20, AUT-21 as before; AUT-23 closes with AIG1 part (b).
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32).

---

## 2026-10-29 23:15 CET · aia review 12: AUT-22 adopted as AIG1-11 (PO 21:15, #686 closed); AIG1-12 look-back (PO 22:10) reviewed, AUT-23 (medium: the list's only exit is a re-confirmation, and AIG1-5 bulk would reach it); OBS1-C1 and ADM2-C1 delivered (#688); ADM2-C2 supported

**Read:** `recovery/main` at `1500cb3`:
- merged since review 11: #687 (review 11), #689 (`lca` 20:40, 21:45: D-35 term 9 for AIG1, CGR-95 look-back terms (i)-(v), D-32), #690 (PO 21:15: **AUT-22 adopted as AIG1-11**), #692 (PO 22:10: **CGR-95 adopted as AIG1-12**, `lca` D-32 as **ADM2-C2**), **#688 (OBS1-C1 + ADM2-C1, migration 0096, ADR-119, merge `b3227d2`)**, #694 (`eng` 22:25);
- open: `cra` #691 (21:30, CGR-95, CGR-96) and its chain, `uxa` #685; issue #693 (CGR-96, root cause UNKNOWN); `eng` claimed AIG1 on #536 at 23:07 (not started in any PR when read);
- briefs changed: AIG1 (AIG1-11, AIG1-12, AIG1-7 small-team suppression note, two PO answers), ADM2 (ADM2-C2), OBS1 (note: CGR-93 closed);
- issue #686 (AUT-22) closed by the PO as completed; no other open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests; CI states are as `eng` reports them (#688: app, db, e2e, ui-screenshots green on `213934b`).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-23 | After an assistant is stopped (AIG1-8): the team members who work through the AIG1-12 look-back list; Operations | **Challenge of the form, never of the look-back (its patient-safety benefit is shown: H-20, H-01, CGR-95).** PLANNED (AIG1-12, PO 22:10; AIG1 claimed by `eng` 23:07, not built): a line leaves the list **only** when its value is confirmed again or corrected through the normal confirm command. Two gaps in the text: (1) **AIG1-5 allows a bulk confirm for `schedule` fields of level-L `rule` agents** (the PLAN3-5 ticked list); nothing in AIG1-12 says that re-confirming from the look-back list is one by one, so the values of an agent stopped for too many corrections could be waved through again in one action, the automation bias the stop exists to catch (H-20). (2) A value that the record **no longer holds** (later replaced by a value a person entered or confirmed for the same field) can only leave by a confirm click on a value that is no longer in force: a step with no patient-care benefit shown, and a long list of such clicks is itself a pressure to confirm without looking. Size of the list per stop: UNKNOWN (no agent built; depends on the window and the agent's volume) | **rule, built in from the start; no new step:** (a) re-confirmation from the look-back list is always value by value, whatever the field class (AIG1-5 bulk not offered on this list; pgTAP: a bulk confirm of two look-back values is refused). (b) A line whose value has been superseded in the record by a later value entered or confirmed by a person for the same field leaves the list by itself, with the reason "überholt" shown on the record line and a ledger row (deterministic, written by the existing confirm or edit command, no person types anything); a superseded value is not re-confirmed. **Whether a superseded value still needs a clinical re-check** (e.g. a visit already done by the wrong person, H-01) is the Clinical Owner's, D-17 part 3: UNKNOWN; if she says yes, (b) does not apply to the fields she names, and such cases go to the existing CIRS/incident path, not to a confirm click. Equal safety: no value leaves unseen that the record still holds | L (governance list; the values themselves keep their own level, G or H fields one by one anyway) | stage 0 (part of the AIG1 build); PO (brief amendment before or with the first AIG1 PR), `cra` for (b) (clinical question to the Clinical Owner), `lca` not needed (terms (i)-(iv) unchanged, no person column) | per team and stop: lines at stop; lines left by correction, by re-confirmation and as "überholt"; days until the list is empty; correction share on the look-back lines (high means the stop was right). Never per person | medium | – (report; one comment on #536) |

**Briefs and items reviewed without a new finding:**
- **AIG1-11 (PO 21:15, from AUT-22), challenge test:** restricts reads only; no step, field or role for anyone; "bestätigt von" stays on the record line. Adopted as proposed plus the `lca` wording point (AUD1 = per-record `read_audit_record`) and a confirmed `not_found` in the closed outcomes. Supported.
- **AIG1-12 (PO 22:10, from `cra` CGR-95, `lca` terms (i)-(iv)):** the design order is right: the stop itself is monitoring, and the list replaces a hand search through every record with a derived worklist; no assignment, no deadline, no person column; NAVORA sets no clinical rule (re-check duty UNKNOWN, Clinical Owner). Supported, with AUT-23 on its exit.
- **AIG1-7 small-team note (PO 22:10, from `lca` 20:40):** suppressing a cell that would point to one confirmer is a data-protection precondition; costs no step. Supported.
- **Pilot precondition (D-9 employee information names confirmations and the look-back purpose):** a legal duty (`lca`, prior information); not administration for a nurse; not challenged.
- **OBS1-C1 delivered (#688, 0096, ADR-119):** authorship and signer columns read only through the per-visit functions; narrows reads, no step added. Supported, as in review 11.
- **ADM2-C1 delivered and ADM2-C2 (PO 22:10, from `lca` D-32):** the push claim re-checks `push_active` and the deletion runs on the existing send cycle, so an ex-member's endpoint no longer waits for an administrator to open a page. This removes a person's task from a data-protection duty (eliminate through a rule). Supported.
- **CGR-96 (#693, two `/field` cards for one moved visit in one e2e attempt):** root cause UNKNOWN; no workflow step to review. If it is a product defect, a duplicate visit would cost the team a phone round and a billing correction; the remedy (pgTAP proof) is Engineering's. Not a finding.

### 2 AI readiness of delivered items
- Nothing merged since review 11 proposes, drafts or ranks. 0096 is a read restriction and a deterministic sweep; no ledger entry is needed.
- **AIG1 (claimed, not built), §8 check against the brief as it now stands:** suggestion ledger (AIG1-1, -2) PLANNED; provenance per value (AIG1-3) PLANNED; named confirmer read per value only (AIG1-11) PLANNED; no accept-all on listed fields (AIG1-5) PLANNED, with the look-back gap of AUT-23 (a); correction rate per agent and field (AIG1-7) PLANNED; stop rule (AIG1-8) PLANNED, **now with a recovery path (AIG1-12)**; evaluation on synthetic data PLANNED (pgTAP per criterion, synthetic seed only). Nothing IMPLEMENTED yet.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED; claimed by `eng` 23:07 on #536 (in progress, no PR read); brief now carries D-35 term 9 at table level (AIG1-11) and a stop look-back (AIG1-12). Open: AUT-23 |
| 0 | Per-entry provenance in clinical records | **IMPLEMENTED for observations including OBS1-C1** (#673, #688); drafts and their origin still OPEN |
| 0 | ASM1 built | PLANNED, not started |
| 1 | Employee information names confirmation records and the look-back purpose (D-9, `lca` 20:40, 21:45) | OPEN, owner (pilot precondition, added) |
| 1 | Real data may reach any test, pilot or AI path | blocked (owner precaution until D-1 is clarified; owner package required by D-35) |
| 1-3 | other conditions unchanged from review 1 | OPEN |

### 4 Findings closed
- None closed with delivery evidence. **AUT-22 (high):** adopted by the PO as **AIG1-11** (21:15), issue #686 closed by the PO; the finding stays OPEN until AIG1 is delivered with the AIG1-11 pgTAP block. AUT-21: adopted as UX2-26, not delivered. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20: unchanged.

### 5 Waiting for the PO
- **AUT-23 (medium):** (a) one-by-one re-confirmation on the look-back list, best placed before the first AIG1 PR (`eng` claimed 23:07); (b) the "überholt" exit, after the `cra` / Clinical Owner answer on superseded values.
- AUT-19, AUT-20 as in review 9; AUT-21 delivery of UX2-26; AUT-22 delivery with AIG1.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32).

---

## 2026-10-29 20:20 CET · aia review 11: OBS1 delivered and accepted (#673, PO 19:40) reviewed; AUT-21 adopted as UX2-26; AUT-22 (high: AIG1 keeps the per-value confirmer selectable by direct query); D-1 precaution added to stage tracking

**Read:** `recovery/main` at `a968727`:
- merged since review 10: #660 (reviews 9 and 10), #670, #672, #678, #681, #683 (PO 14:35 to 19:40), #674, #679, #682 (`lca` 16:05, 17:00, 18:40), #675 (`uxa` 16:10), #677 (PO, owner D-1 precaution), **#673 (OBS1, migration 0095, ADR-118, merge `1fa6f26`)**;
- open: #685 (`uxa` 19:50), `cra` #680 (17:30, CGR-94) and its chain; `eng` on #536: OBS1-C1 with ADM2-C1 first, **AIG1 in the next run(s)**;
- briefs changed: OBS1 (OBS1-4 wording, OBS1-7, acceptance with OBS1-C1, OBS1-C2), UX2 (UX2-23 wording, **UX2-26 from AUT-21**, UX2-27); D-1 (owner precaution: no real client data for tests or pilot until D-1 is clarified; no repository migration on the live project before the review result), D-23 (`lca` re-check behind OBS1-7); AIG1 unchanged since 2026-10-27 18:10.
- No open issue was labelled `automation` before this run.

**Nothing below is a measurement.** I ran no tests; CI states are as the PO reports them.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-22 | Every later assisted step (PLAN3 day plan first): the confirmer of a proposed value, i.e. every nurse who uses an assistant | **AI readiness of an approved item before build, not a challenge of a step.** PLANNED (AIG1 approved 2026-10-27, unchanged since 18:10; next after OBS1-C1): AIG1-2 and AIG1-3 store per value the confirmer and the outcome (`confirmed`, `corrected`, `rejected`) with time; AIG1-7 forbids a per-person **reader**. No criterion says who may **select the rows themselves** through the table API. D-35 `lca` term 9: the per-value confirmer is read per value or through the AUD1 purpose reader only, never aggregated per person (ArGV 3 Art. 26); not in any AIG1 criterion. Today's `lca` 16:05 finding on OBS1 (team-wide table select → per-person filter by direct Data API query; now OBS1-C1, a separate retrofit PR that rewrites pgTAP 016, 026, 049) shows the same shape. Effect on care time: if a nurse's accept/correct pattern can be listed, the safe behaviour is to avoid the assistant or accept unchanged (automation bias, H-20), so the administrative gain of every later agent is at risk. Size: UNKNOWN (no agent built) | **rule, built in from the start:** add one AIG1 criterion (e.g. AIG1-11): confirmer and outcome columns of the ledger and confirmation tables not selectable by `authenticated` (mechanism Engineering's, e.g. column grants as 0070, RLS3-4); "bestätigt von" read per value through the record's own function (AIG1-3 line) and through the AUD1 purpose reader; AIG1-7 stays the only aggregate, without a person key; `READ_PATHS.md` lists the columns under RLS3-4 and the pgTAP 071 list fails on an unlisted reader. No added step for anyone; equal safety (accountability per value is kept) | L | stage 0 (precondition of every later stage); PO (brief amendment before build), `lca` (term 9 reading), `eng` (mechanism); no clinical content | pgTAP: direct select of confirmer/outcome → 42501; the record function still returns "bestätigt von" per value; 071 list extended. After go-live, per team only: AIG1-7 correction share per agent and field (a share drifting only to "confirmed unchanged" is a warning sign, read per team, never per person) | high | #686; one comment on #536 |

**Briefs and items reviewed without a new finding:**
- **OBS1 as built (#673, 0095, ADR-118), challenge test:** the marker is set by an insert trigger; the nurse types nothing; the screen adds one `info` line per affected observation ("Qualifikation war beim Schreiben nicht erfasst", not red); nothing is refused, routed or counted. The handover now answers "who wrote this?" without a phone round. Added administration: none. Supported, as in review 10.
- **OBS1-C1 (= OBS1-7, per-visit read paths):** narrows reads only; no step for a nurse or administrator; supported. It is also the template for AUT-22.
- **OBS1-C2 (`cra` CGR-94):** of the three ways, `eng`'s statement in the deploy record ("no observation between 0091 and 0095") is the leanest and changes no screen; the derived marker or the neutral line "Qualifikation beim Schreiben nicht bekannt" only where that statement cannot be made. Patient-safety and accuracy control (DSG Art. 6 Abs. 5, `lca` 18:40); not administration; not challenged.
- **UX2-26 (PO 15:40, from AUT-21):** taken in as proposed (same card, existing command, not preselected, "Später", the gap visible in the admission list). Supported.
- **UX2-23 wording (`uxa` 16:10):** one confirming step on two rare administrator switches, in place, focus moved; supported (review 10).
- **UX2-27 (one author label):** removes a member code from the handover; supported.
- **D-1 owner precaution and its explicit default (PO 17:00, 19:15):** no real client data for tests or pilot runs; no migration on the live project before the review result. A data-protection precondition, not administration; recorded in stage tracking below.

### 2 AI readiness of delivered items
- Nothing merged since review 10 proposes, drafts or ranks. The OBS1 marker is a deterministic fact fixed at write time (no ledger entry needed).
- **Per-entry provenance in clinical records is now IMPLEMENTED for observations** (author per observation in the handover and in new report snapshots; signed snapshots unchanged; per entry only, residual table read closed by OBS1-C1). The §12 control for later documentation drafts (the confirmer is the author; draft origin a separate per-entry fact) can build on it unchanged.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED; *Next up* 1 after OBS1-C1 (`eng` #536); not started. **Missing in the brief:** D-35 term 9 at table level (AUT-22, #686) |
| 0 | Per-entry provenance in clinical records (§8 "provenance per value") | **IMPLEMENTED for observations** (OBS1, #673); OBS1-C1 PLANNED; drafts and their origin still OPEN |
| 0 | ASM1 built | PLANNED, not started |
| 1 | Real staff or client data may reach any test, pilot or AI path | **blocked additionally** by the owner precaution of 2026-10-29 until D-1 is clarified (documented review, result recorded); besides the new owner package D-35 requires (provider, region, contract) |
| 1-3 | other conditions unchanged from review 1 | OPEN |

### 4 Findings closed
- None. **AUT-21 (medium):** adopted by the PO as **UX2-26** (15:40; may ride with UX2-22/UX2-23); stays OPEN until delivered. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20: unchanged.

### 5 Waiting for the PO
- **AUT-22 (high, #686):** answer before AIG1 build starts (one criterion and one pgTAP block now instead of a later OBS1-C1-style retrofit).
- AUT-19, AUT-20: as in review 9. AUT-21: delivery of UX2-26.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32).

---

## 2026-10-29 14:55 CET · aia review 10: ADM2 merged (#647) and OBS1 approved (PO PR #670) reviewed; AUT-21 (onboarding: the qualification is a second administrator step in another place); OBS1 supported

**Read:** `recovery/main` at `064a6c0`:
- merged since review 9: #647 (ADM2 incl. ADM2-15 (c) and ADM2-16, migrations 0091, 0092, 0094, ADR-115, ADR-117; merge `1cc31d4`, CI green on head `eccf343` as reported by `eng` 14:35), #653, #655, #657 (`uxa` 11:53), #658, #659, #661, #663 and #667 (`lca` 09:45, 13:57), #664, #665 (PO 10:15, 12:15), #668;
- open: #670 (PO 14:35: ADM2 accepted with ADM2-C1; **OBS1** approved, *Next up* 1 ahead of AIG1; G-23 extended, G-24 new; read at its branch head), `cra` #666 (13:40, CGR-93) and its chain, this PR #660 (review 9; merge conflict in `JOURNAL.md` resolved by merging `recovery/main` in, both entries kept);
- code: `set_member_qualification` (0018, patched 0046; organisation `admin` only, free-text reason 3-300), `src/app/(protected)/admin/admission-section.tsx` ("Vertrag erfassen", shows "angegeben: <Qualifikation>" and the sentence "Die Qualifikation setzt die Administration wie bisher beim Mitglied"), `admin-client.tsx` ("Qualifikation fehlt", "Qualifikation ändern" on the member entry), 0094 (`qualification_missing`, one audit row per refusal).
- No open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests; CI states are as read through the API or as other roles report them.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-21 | Onboarding: a colleague the team admitted (ADM2) starts working (organisation administrator; the team waiting for her) | **Challenge of the form, never of the gate.** The qualification gate has a clear patient-safety benefit and stays (ADM2-6, ADM2-16, D-29 verification with the owner). **IMPLEMENTED since #647:** after the team admits, the administrator records "Vertrag erfasst" on one card, which shows the claimed qualification as "angegeben" and tells her to set the qualification elsewhere; she must then open the member's entry in another section ("Qualifikation fehlt"), choose "Qualifikation ändern", pick the value and type a reason. Until she does, ADM2-16 refuses the new colleague every depart, start and complete (`qualification_missing`), planning, take and cover refuse her as responsible (ADM2-6), and the team keeps covering her share. **Added steps:** a second navigation and a second form for one administrator act that belongs to the same sitting; dead time between contract and qualification with no owner and no signal to anyone. Length of that gap and refusals per admission: UNKNOWN (no pilot data) | **simplify (same command, same place) and monitor; no new rule:** (1) after a successful "Vertrag erfassen" the same card offers the **existing** `set_member_qualification` for that member and team: the claimed value is shown beside the choice, **not preselected** (an explicit choice, no accept-all; verifying it stays the administrator's act under D-29), reason as today; skipping it is allowed. (2) The admission list keeps such a member under "Vertrag erfasst, Qualifikation fehlt" until it is set, so the gap has a visible place (the existing "Qualifikation fehlt" fact, no new field). Equal safety: same actor, command, check, audit row and refusals; nothing sets a qualification without the administrator's own choice | L (administrative record; the qualification value itself stays the employer's verified fact, D-29) | stage 0; PO (UX2 or with ADM2-C1), `uxa` (card layout), `lca` only if D-29 changes who verifies | per organisation and month: median days from "Vertrag erfasst" to qualification set (target: same day); `qualification_missing` refusals per admitted member in her first 14 days (target: 0); admissions where the team still covered visits because the newcomer could not perform. Never per person | medium | – (report and one comment on #670) |

**Briefs and items reviewed without a new finding:**
- **OBS1 (PO 14:35, #670, *Next up* 1), challenge test:** the marker is derived at write time from a recorded fact (`private.actor_may_perform_visit`); nobody types it, no observation is refused, routed or ranked by it, and the author line removes the phone round "who wrote this?" in the handover. Added administration for a nurse: none; one read line per observation. Patient-care benefit shown (the reader knows whose observation she relies on and whom to ask; `lca` reads authorship as a ZH GesG § 13 duty). Supported. The OBS1-6 `lca` read is a legal check of our own process, not a nurse step; not challenged. The two AN2 measures are team-level counts; supported.
- **OBS1 and AI readiness (forward, no finding):** OBS1 builds the first per-entry provenance in clinical documentation. Recorded as a control in AI Operating Model Review §12: when a later stage lets an agent draft an observation or report text (A-catalogue documentation drafts, D-35 stage 1 or later), the author shown is always the confirming person, and the draft origin is a separate per-entry fact beside it, in the same line; an agent is never shown as an author, and the origin is never a per-person list or count (RLS3-4). Engineering's OBS1-1 choice (column vs derivation) is theirs; nothing in OBS1 needs to change for this.
- **ADM2-C1 (push subscriptions deleted by the first sweep after an automatic access end):** a deterministic sweep instead of a person's task; supported.
- **UX2-22 (hide refused field controls for a member without a recorded qualification):** removes taps that are always refused; supported, and with AUT-21 the state it hides should rarely last more than a day.
- **UX2-23 (one confirming step before switching team admission and before "Vertragsende entfernen"):** adds one tap to two rare administrator commands; the second keeps a person's access after her contract end (data protection), so the form is proportionate. Supported; not challenged.
- **UX2-24, UX2-25, PO challenge 12:15 ("a screen offers a control the server always refuses"):** supported; the PO's general rule is the screen-side twin of AUT-21 (the place of action shows the state and the next step).
- **ADM2 accepted (ADR-115 deviations, ADR-117 deviation 1):** `record_no_show` by a member without qualification not refused: supported (refusing it would hide a missed visit from the team and OPS1/SIG1).

### 2 AI readiness of delivered items
- Nothing merged since review 9 proposes, drafts or ranks. ADM2's consent count (`least(2, n)`) and contract end are deterministic rules; ADM2-16 is a refusal; no ledger entry is needed.
- ADM2-15 (c) ("Fall öffnen" on each successor item) is the first IMPLEMENTED case of the §12 control "an item that asks for an action links to the place of action".

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED; now *Next up* 2, behind OBS1 (#670, open); not started |
| 0 | ASM1 built | PLANNED, not started |
| 0 | Per-entry provenance in clinical records (§8 "provenance per value") | PLANNED for observations through OBS1 (author and marker per entry); drafts and their origin still OPEN |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- None. **AUT-20 (medium):** adopted into hypothesis P-30 by the PO (09:10); stays OPEN until the split count is part of a brief's measures. **AUT-19 (medium):** OPEN, waits for UX2-17. AUT-14, AUT-15, AUT-17: unchanged.

### 5 Waiting for the PO
- **AUT-21 (medium):** qualification offered on the "Vertrag erfasst" card, and the gap kept visible, before G-23 if possible (it decides whether a team-admitted colleague can work on day one).
- AUT-19, AUT-20: as in review 9.
- Bottleneck map refresh: due 2026-11-03 (weekly); onboarding (contract to first visit, AUT-21) added as a candidate next to P-28 and P-32.

---

## 2026-10-29 08:25 CET · aia review 9: AUT-18 closed (#655 merged); P-30 reviewed (AUT-20, the existing uncovered-visit monitoring reaches Operations, not the team); ADM2 answers and ADM2-15 (c) supported

**Read:** `recovery/main` at `dcd5ffa`:
- merged since review 8: #627 (my review 8), #633 (VIS1 follow-up, `35b5a96`), #637, #640, #641, #642, #643, #645, #648 (`lca` 05:42, D-37), #651 (PO 06:10), #653 (issue #650), #655 (VIS1-10, `eng`, ADR-116, migration 0093);
- open: #659 (PO 08:15: VIS1-10 met, acceptance waits for the `cra` VIS1-7 gate on #655; ADM2-15 (c) from `uxa` UXR-42), #658 (`eng`, #655 merged before the `cra` gate, deviation recorded), #657 (`uxa` 07:50), #647 (ADM2 draft), `cra` #646, #639 and older;
- code: `move_visit_to_today` (0093) and `field-client.tsx` (ADR-116 point 3); `visit_uncovered` (0044 header, CR-049) and its delivery rule (SIG1, 0060 header).
- CI on `dcd5ffa` as read through the API at about 08:22: app, db, ui-screenshots green in both runs; e2e green in one run, in progress in the other. No open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-20 | Coverage: a visit released by an absence or a move waits without a responsible member (team; PO hypothesis P-30, 03:10) | **Comment on P-30 (no build).** P-30's next step, if pilot data show ownerless visits at start, is a PLAN3 criterion that **proposes a named owner** (agent at the edge, AIG1 confirm). **Evidence that monitoring already exists (IMPLEMENTED):** the derived exception `visit_uncovered` exists exactly while a visit is planned, nobody is responsible and it is not covered (0019, 0038, 0044, CR-049; P2, 24 h window, PROVISIONAL until D-28) and closes only with its cause. At P2 it is pull-only and shown on OPS1 (`src/features/operations/`), the Operations role's screen; SIG1 (0060) pushes it to every present member of the owning team only when an organisation raises it to P1. So by default the one signal about the team's own coverage gap reaches the central role, while the team has the "Offen im Team" list it must remember to read (P-30's premise). Effort and frequency: UNKNOWN (no pilot data) | **monitor before agent, design order kept:** (1) P-30's count also splits takes made after the exception appeared on OPS1 (Operations acting for the team) from takes by the team (list, VIS1-11 notice, later PLAN3), so the pilot shows whether coverage is being centrally dispatched; (2) if ownerless-at-start is material, the first remedy asked is the **existing** `visit_uncovered` delivered to the owning team (SIG1 recipients, no new rule, no new threshold): its priority and window are a D-28 question for `cra` and the Clinical Owner, never set by `aia` or the PO; (3) only if that is not enough, a PLAN3 owner proposal, with the controls in AI Operating Model Review §12 (fixed candidate order shown with its reason; a person who does not take the visit leaves no trace about her; correction rate per agent and field at team level only; responsibility only through `take_open_visit` and her own tap) | L (responsibility under an existing rule; priority of the signal is H-adjacent and stays with D-28) | stage 0; PO (P-30 measure wording), `cra` and Clinical Owner (D-28 priority and window), `uxa` if the team view changes | per team and month: released visits; median time from release to `taken`; share ownerless at visit start (target: 0); share of takes made by Operations after the OPS1 exception versus by the team | medium | – (report only; no open PR or issue carries P-30) |

**Briefs and items reviewed without a new finding:**
- **ADM2 PO answers (06:10):** (1) a team with no other active member admits on the proposal: supported; a consent nobody can give would return every founding nurse to an administrator (a hierarchy step) with no safety gain, since qualification (ADM2-6) and the employer's contract record still gate care. (2) decline = withdrawal: one outcome less to model; supported. (3) an admitted proposal without "Vertrag erfasst" lapses after 14 days with its candidate data deleted: a deterministic sweep instead of a person's reminder, and data minimisation; supported. The pilot count by number of consents is team level.
- **ADM2-15 (c) (PO 08:15 in #659, from `uxa` UXR-42, issue #656):** the successor item links to the case card and the card shows its reference. This removes a search and a phone call ("which case is that?") and adds one secondary line, not a field anyone fills; the benefit is shown (the CGR-72 remedy can be acted on). Same pattern as AUT-19. Supported, and the PO's general rule ("an item that asks for an action links to the place of action") is taken into §12 of the AI Operating Model Review as a control for every agent proposal.
- **PO scope rule (04:10):** after `changes-requested`, only patient-safety findings enter the capability; the rest go to UX2 or a later brief. This cuts review-driven engineering and `cra` cycles, which is administration of our own process. Supported; `aia` follows it (AUT-20 names no VIS1 criterion).
- **P-31 (night shift vs calendar day) and P-32 (a team divides itself):** both measure first at team level and keep the record and responsibility rules where they are (DAY-1; `cra` on a responsibility transfer). P-32 is a care-graph elimination candidate (cases move with primary nurse and deputy in one command instead of re-entry); taken into the bottleneck map refresh (due 2026-11-03) under team self-organisation.
- **#655 (VIS1-10):** see §4. ADR-116 "Not done": a midnight tolerance and past-dated field actions stay UNKNOWN for the Clinical Owner (CGR-87 (3)); `aia` proposes none.
- **#658, #657:** process and UX notes; no nurse step added.

### 2 AI readiness of delivered items
- #655 adds no proposal, draft or ranking: the re-derived times are the VIS1-3c deterministic default, and the re-offer shows the database's value for one more confirm. It is the first IMPLEMENTED case of the §12 control "the stored value is the value the confirmer saw" (refusal `day_changed`, one audit row, nothing changed; pgTAP 093 as described in ADR-116, CI as read above).
- Nothing merged since review 8 proposes, drafts or ranks; no ledger entry is needed.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED, *Next up* after ADM2 (ADM2 in build, draft #647); not started |
| 0 | ASM1 built | PLANNED, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- **AUT-18 (low):** closed. Evidence: adopted into VIS1-10 (PO 03:10), built in #655 (merged `dcd5ffa`; ADR-116 point 3: on `day_changed` the confirmation stays open with the UXR-39 sentence, the database's today, times re-derived by VIS1-3c and the typed reason kept; reload only as fallback); the PO's 08:15 review (#659, open) marks VIS1-10 met. The `cra` VIS1-7 gate on #655 is still pending; if it returns VIS1-10, `aia` reopens AUT-18 in a new section.
- **AUT-19 (medium):** stays OPEN. Adopted as VIS1-11 / UX2-17 (label "Übernehmen", UXR-38); not in #655 (ADR-116 deviation 3), so it waits for UX2.

### 5 Waiting for the PO
- AUT-20 (medium): P-30 measure split by who took the visit (team or Operations), and the existing `visit_uncovered` delivered to the team (D-28 priority, `cra`) before any PLAN3 owner proposal.
- AUT-19 (medium): built with UX2-17.
- AUT-17 (low), AUT-14 (medium), AUT-15 (low): unchanged; D-38 frozen, nothing written about it.
- Bottleneck map refresh: due 2026-11-03 (weekly), with P-28 (window instead of a fixed day) and P-32 (team split) as candidates.

---

## 2026-10-29 02:45 CET · aia review 8: AUT-16 closed (#624 merged); VIS1-10 and P-29 reviewed (AUT-18, AUT-19); no item proposes, drafts or ranks

**Read:** `recovery/main` at `6d3eb34`:
- merged since review 7: #624 (VIS1, `5d85b8f`, CI green on `30cbde1` as read by the PO), #625, #630, #632 (PO 22:15, 23:15 `changes-requested`, 00:15: VIS1-3c to VIS1-3g, VIS1-8, VIS1-9; hypotheses P-27, P-28, P-29), #629 (`uxa` 22:00);
- open: #633 (`eng`, VIS1 follow-up, read at head `ae3e98e`: `field-client.tsx` released notice, `rules.ts`), #640 (PO 02:15: issue #638 placed as VIS1-10; read at head `307bca3`), #637 (`eng`, e2e run-day guard, #635), #639 and #628 (`cra`), #634 (`uxa`), this PR #627 (my review 7; `db` red on `e0c5208` in pgTAP 079 test 44, the known intermittent failure #399 / CGR-86; continued here, not a second PR);
- code: `take_open_visit` and `team_open_visits` (0046), `absence-section.tsx` (the only caller of `takeOpenVisit`), `reschedule_visit` release path (0056).
- No open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests; CI states are as read through the API.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-18 | Visit: "Heute machen" on a page opened before midnight (nurse at the door at night, `/field`) | **Challenge (form, not existence) of VIS1-10 (PO PR #640, open).** The benefit is shown and the control stays: the stored date must be the database's today and must not contradict the "Heute, <Datum>" the nurse confirmed (record integrity, value 2). **Added step:** on a refusal she reads a sentence, reloads `/field`, finds the card again, reopens "Heute machen" and re-enters what she had (VIS1-3c times are re-derived; the typed reason, VIS1-3b, is lost). Frequency UNKNOWN (page open across midnight; night visits) | **rule, leaner form at equal safety:** the refusal returns the database's day; the same dialog stays open with the new date shown ("Inzwischen ist der <Datum>"), the times re-derived by the VIS1-3c rule, the typed reason kept, and the confirm button enabled again. One more tap on the visible new value instead of a reload and a re-entry. Equal safety: the database still refuses any date that is not its today, the stored value is always the value shown at the last confirm (no silent replacement), the refusal audit row stays. Wording `uxa`; `cra` VIS1-7 gate as already set for VIS1-10. If not taken into VIS1-10, it fits UX2 | L (schedule fact) | stage 0; PO (VIS1-10 wording "reload" or "re-offer"), `uxa`, `eng` (ADR-113) | per team and month: count of `day_changed` refusals and share followed by a successful move of the same visit within 5 minutes (target: all, without a reload) | low | – (comment on #640) |
| AUT-19 | Visit: a move releases the visit because its responsible member is absent at the new time (nurse who moved it, `/field`; PO P-29) | **Comment on PO P-29 (no build, 00:15):** the PO reads "who becomes responsible" as a care-responsibility rule still to be set. **Evidence that the rule already exists (IMPLEMENTED):** `take_open_visit` (0046) lets a member of the visit's team take a planned, uncovered visit with nobody responsible, one tap, first wins, with the J3 qualification check `may_perform_visit`, an absence check at the visit's time and a `taken` row in `visit_plan_changes`. Today it is reached only from "Offen im Team" (`absence-section.tsx`), so after a released move the nurse at the door must scroll to that list, find the visit she just moved and tap again; #633 (VIS1-3d) shows the released notice (`attention`) with no action | **eliminate the search, no new rule:** the VIS1-3d released notice carries one outline action "Ich übernehme" that calls the **existing** `take_open_visit` for that visit, with its existing checks and refusals (`not_qualified`, `absent`, `already_taken` shown with the existing texts). Separate tap, never automatic: the move does not assign her, and nothing assigns without her own tap. P-29's AN1 count stays the way to see whether more is needed (e.g. a combined command); `aia` proposes none | L (responsibility under an existing rule; no clinical content) | stage 0; PO (now as part of VIS1-3d / VIS1-3f or UX2), `uxa` (position next to the notice), `cra` only if the action text or tone changes the VIS1-3d notice (VIS1-7 gate) | P-29 count (released moves started by the mover within 30 minutes) split by taken from the notice versus from "Offen im Team"; released moves still without a responsible member at visit start (target: 0) | medium | – (comment on #640) |

**Briefs and items reviewed without a new finding:**
- **VIS1-3c (UXR-30), VIS1-3d to VIS1-3g, VIS1-8, VIS1-9:** VIS1-3c removes a false `visit_overdue` alarm per early visit (a teammate's call saved; supported). VIS1-8 is a deterministic read, no tap (supported in review 7). VIS1-9 is the same rule on another write path; no person step. VIS1-3f and VIS1-3g are presentation. No administration added.
- **P-27, P-28 (PO challenges):** both are care-graph eliminations and `aia` supports measuring first. P-28 (a window instead of a fixed day for a weekly service) would remove every early-visit move at its source, which is where AUT-16, AUT-18 and AUT-19 all start; it needs a missed-visit rule for a window (`cra`, Clinical Owner, D-28: UNKNOWN). Taken into the bottleneck map refresh (due 2026-11-03) as a Planning candidate.
- **#637 (e2e run-day guard):** test infrastructure; no nurse step.
- **AUT-17 (low, placeholder on the move reason):** not in #633 (no placeholder in the diff). Stays OPEN; allowed, not required.

### 2 AI readiness of delivered items
- #624 (merged) prefills today's date and the card's times; #633 replaces the times with the VIS1-3c rule (next full 5 minutes, planned duration). These are deterministic defaults, not proposals, drafts or rankings; no ledger entry is needed. Nothing merged since review 7 proposes, drafts or ranks.
- **Forward control (AI Operating Model Review §12, extended):** "now" is the database's day; a stored value is the shown value, re-shown when the day changed (AUT-18); responsibility after a release only through `take_open_visit` and the person's own tap (AUT-19).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED, *Next up* after ADM2; not started |
| 0 | ASM1 built | PLANNED, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- **AUT-16 (medium):** closed. Evidence: VIS1-3b IMPLEMENTED in #624, merged `5d85b8f`; the PO's 23:15 review marks VIS1-3b met (`vis1.spec` 72-106: one confirmation on `/field`, existing `reschedule_visit`, the start its own tap); `cra` 22:00 (PR #628) VIS1-7 gate clear. The reason is typed, not prefilled (`cra` 21:30), accepted in review 7. The measure (moves to today from `/field` versus `/team`) becomes countable from the `moved` rows.

### 5 Waiting for the PO
- AUT-18 (low): VIS1-10 refusal re-offers the new date in the same dialog instead of a reload. Comment on #640.
- AUT-19 (medium): "Ich übernehme" on the released notice through the existing `take_open_visit`. Comment on #640.
- AUT-17 (low), AUT-14 (medium), AUT-15 (low): unchanged; D-38 frozen (rule 9), nothing written about it.
- Bottleneck map refresh: due 2026-11-03 (weekly), with P-28 as a Planning candidate.

---

## 2026-10-28 22:00 CET · aia review 7: AUT-16 adopted as VIS1-3b and built in #624 (open); `cra` keeps the reason typed; CGR-89 supported as a fact line; AUT-17 (low)

**Read:** `recovery/main` at `013b733`:
- merged since review 6: #622 (mine), #620 (PO 20:15: COORD6 accepted; VIS1 *Next up* 1 with VIS1-3a from UXR-29 and VIS1-3b from AUT-16, reason not prefilled until `cra`);
- open: #624 (`eng`, VIS1, ADR-111, migration 0089; read at head `2db589d`: `field-client.tsx` move dialog, `features/field/rules.ts`, ADR-111), #623 (`cra` 21:30: VIS1-3b prefill not confirmed, CGR-89; read at head `f6cafc6`), #614, #604, #589, #582 (contained in #623);
- No open issue is labelled `automation`.

**Nothing below is a measurement.** CI on #624 not read as passed; ADR-111 says vitest, typecheck, lint, build and Playwright were not run locally (CI decides).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-17 | Visit: the reason for moving an early visit (nurse at the door, `/field`, VIS1-3b) | **IMPLEMENTED in open PR #624:** the dialog shows an empty, required `reason` textarea (3-300 characters, `field-client.tsx` at head `2db589d`) and a hint `MOVE_TO_TODAY_HINT` that explains the move ("… im Verlauf festgehalten …"), not what to write. `cra` 21:30 (#623) named a non-submitted placeholder ("Warum heute? z. B. Wunsch der Klientin") as an acceptable aid that keeps the J3 duty. Effort: one typed sentence per early visit, at the door; thinking about what is expected is the part a placeholder removes. Size UNKNOWN (no AN1 count of early moves yet) | **simplify:** a `placeholder` on the reason field asking *why today*, never submitted, never prefilled (`cra` answer kept). Rides #624 if `eng` touches the dialog again, otherwise UX2. Wording `uxa`; no reason list (that would be a reason catalogue, PO documentation rule with a Clinical Rule Register row first, `cra`) | L | stage 0; gate PO, `uxa` (wording) | AN1: per team and week, number of VIS1-3b moves and median time from opening the dialog to confirm (team level only, never per person) | low | none (low) |

### 2 Reviewed without a new finding
- **AUT-16 → VIS1-3b (PO 20:15) and `cra` 21:30:** adopted with one change: the reason is typed, not prefilled. **Accepted by `aia`, no challenge:** `cra` shows that the prefill ("Heute statt am <Datum> gemacht") only restates the `before`/`after` of the `moved` row (0056) and always passes the 3-character minimum, so the duty would be met by default and the only fact NAVORA does not already know (why) would be lost. A prefill there would have removed a step in form only. The rest of AUT-16 is built in #624 as proposed: one confirmation on `/field`, today fixed, card times prefilled and editable, the existing `reschedule_visit` with its checks, the start its own tap. **AUT-16 stays OPEN** until #624 merges with CI green and the `cra` VIS1-7 gate is clear.
- **CGR-89 (`cra` 21:30, advisory S2; for the PO to place):** the confirmation states, as a fact read from the plan, whether the client still has a visit planned on the date the visit leaves. **Supported from the automation side:** it is a deterministic read (no field, no tap, no rule, no level), and it puts at the door the one fact that otherwise someone would have to look up on `/team` afterwards. It is the eliminate-through-the-care-graph pattern. Whether a gap needs a replacement visit is the Clinical Owner's (UNKNOWN); `aia` proposes no signal or rule for it.
- **#624 otherwise:** no step added for a nurse beyond the brief. The refusal audit row (ADR-111 decision 2) is written by the database, not by a person. ADR-111 decision 4 confirms that a member of the visit's team moves it herself (no coordinator), as AUT-16 assumed.

### 3 AI readiness of delivered items
- #624 prefills today's date and the card's own planned times. These are copies of existing values, not a proposal, draft or ranking; no ledger entry is needed. Nothing merged since review 6 proposes, drafts or ranks.
- **Forward control (AI Operating Model Review §12, extended):** any proposed earlier move from PLAN3 or the day-order agent (AUT-5) shows the CGR-89 fact line too, so a confirmer never moves a visit off a date blind.

### 4 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED, *Next up* behind VIS1 and ADM2; not started |
| 0 | ASM1 built | PLANNED, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 5 Findings closed
- None (AUT-16 closes on the #624 merge).

### 6 Waiting for the PO
- CGR-89 placement (`cra`); `aia` supports it (§2).
- AUT-17 (low): placeholder on the reason field.
- AUT-14 (medium), AUT-15 (low): unchanged; D-38 frozen (rule 9), nothing written about it.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-28 20:19 CET · aia review 6: VIS1 reviewed (AUT-16, the early visit as one confirmed move on `/field`); COORD6 and UX1 accepted; no item proposes, drafts or ranks

**Read:** `recovery/main` at `785278e`:
- merged since review 5: #607 (`eng` UX1 status), #608 (mine), #610 and #615 (`lca` 14:56, 17:41), #611 and #616 (PO 15:15, 16:15, 18:15), #613 and #618 (`uxa` 15:48, 19:48), #612 (COORD6, `eng`, ADR-110);
- open: PO #620 (`po/cycle-2026-10-28-2015`: COORD6 accepted, VIS1 *Next up* 1, VIS1-3a from UXR-29; read at its head), `cra` #614 (CGR-87, CGR-88), #604, #589, #582;
- briefs: VIS1 (new, approved 18:15, with VIS1-3a in #620), UX1 (accepted 15:15, conditions UX1-C1 to UX1-C3), UX2-14 to UX2-16;
- code: `reschedule_visit` (0012:133-134 team membership check; 0052 and 0056 patches), `src/features/team/commands.ts` (`rescheduleSchema`: date, start, end, free-text reason 3 to 300 characters), `src/app/(protected)/team/team-client.tsx` (the only screen that calls the move), `src/features/field/rules.ts` (`todayInZurich`, `fieldActions` without a date).
- No open issue is labelled `automation`.

**Changed since review 5:** VIS1 is a new approved brief (`cra` CGR-87, S1 before a pilot with real clients). COORD6 merged and is accepted in #620. UX1 accepted. D-38 is `awaiting-approval: owner` and frozen since 15:15 (rule 9): nothing below is written about the package itself.

**Nothing below is a measurement.**

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-16 | Visit: a nurse does a visit earlier than planned (nurse at the door, `/field`) | **Challenge (form, not existence).** VIS1 (approved; *Next up* 1 in #620) refuses depart, start, no-show and "not completed" on a visit dated after today, and asks the nurse to move it first. The patient-care benefit is shown and the guard stays: a future visit worked today masks a missed visit on its real date (CGR-87; H-01, H-05) and moves billable facts to a day without care. **Added step:** the move. Today the move exists only on `/team` (`team-client.tsx` → `rescheduleVisit`), where she enters a date, a start and an end time and a free-text reason of at least 3 characters (`commands.ts` `rescheduleSchema`), then returns to `/field` and starts. VIS1-3 / VIS1-3a give a link to that route; PO 20:15 reads `reschedule_visit` as open to any member of the visit's team (0012:134, Engineering confirms in the ADR), so no coordinator is needed. What remains is a screen change and three typed values per early visit, at the door. How often visits are done early: UNKNOWN (no event records it today; it will be countable once VIS1 lands, as moves to today) | **simplify (deterministic, no agent):** on the future-dated card the outline action is "Heute machen". It opens one confirmation on `/field` with the values prefilled: date today (Europe/Zurich, DAY-1), the planned start and end times as on the card (editable), and a reason text prefilled as "Heute statt am <Datum> gemacht" that she may edit. Confirm calls the **existing** `reschedule_visit` with its existing checks (ABS1-C4, ABS1-C5, CGR-35, audit and `moved` log row) and returns her to today's card, where "Einsatz starten" is now offered. No new command, no new permission, no combined "move and start" (the start stays its own tap, so the VIS1 guard is never bypassed). Equal safety: the same audited move, the same reason field, the same refusal paths. CGR-76 check: the control cited by CGR-87 (move first, with audit) is kept in full; only where it is entered changes. Whether a prefilled, editable reason meets the J3 reason duty: `cra` (UNKNOWN to `aia`). Gain: one screen change and two typed times per early visit; minutes UNKNOWN (estimate) | L (schedule fact; no clinical content) | stage 0; PO (whether VIS1-3a's link becomes this action, now or as a follow-up), `uxa` (form of the confirmation at 390 px), `cra` (prefilled reason text; VIS1-7 gate), `eng` (ADR: same command, no bypass) | number of visits moved to today from `/field` versus from `/team`, per team and month; share of those moves started the same day; overdue or missed signals on the original date of a moved visit (target: 0) | medium | – (comment on #620) |

**Briefs and items reviewed without a new finding:**
- **VIS1 guard itself:** a deterministic rule on a visit/schedule fact; no level, no tolerance coded (any tolerance is a Clinical Owner level, UNKNOWN). Supported: it removes a later correction (administration) and protects the signal chain. VIS1-6 keeps past-dated visits as they are, so a forgotten tap is still recordable; no new administration there.
- **VIS1-3a (UXR-29):** one sentence per future day instead of one per card; less reading, no step added. Supported.
- **COORD6 (merged #612, accepted in #620):** a check replaces a rule every agent had to remember. No step for any person. Consequence for `aia`: every later `aia` PR is checked against frozen packages by `agents-check`; this review writes nothing about D-38 for that reason.
- **UX2-14 to UX2-16:** colour, one error component, frame rule. Less to learn per screen; no workflow step added or removed.
- **UX1-C1 to UX1-C3:** test and string conditions; no nurse step.

**Answers placed on earlier findings (no change of severity):**
- **AUT-14, AUT-15:** `lca` 14:56: AUT-14 compliant with per-provider scoping (C's person sees an item only for clients whose choice and consent are recorded); AUT-15 compliant only if staff entries leave NAVORA on the person's own action (DSG Art. 28, OR Art. 328b, as cited by `lca`). Both conditions are now part of the proposals. Both stay OPEN; the package they relate to is frozen awaiting the owner.

### 2 AI readiness of delivered items
- Nothing merged since review 5 proposes, drafts or ranks (#612 is a repository check; UX1 parts are labels and states). Nothing to check against §8.
- **Forward control for PLAN3 and AUT-5 (added to AI Operating Model Review §12):** after VIS1, a proposal that a visit be done earlier is a proposed `reschedule_visit` (its date is a `record`-class field under AIG1-5, confirmed one by one), never a start; no agent and no shortcut starts a visit dated after today.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED. *Next up* 3 in #620 (after VIS1 and ADM2); COORD6 and UX1 no longer ahead of it |
| 0 | ASM1 built | PLANNED (*Next up* 4), not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- None.

### 5 Waiting for the PO
- AUT-16 (medium): whether the VIS1-3 / VIS1-3a move link becomes a one-confirmation "Heute machen" on `/field` (same command), in VIS1 or as a follow-up; `cra` on the prefilled reason. Comment left on #620.
- AUT-14 (medium), AUT-15 (low): unchanged, with the `lca` conditions above.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-28 14:41 CET · aia review 5: "designed from scratch" applied to the bottleneck map; D-38 T15 (b) readiness derived from the record (AUT-14); provider kit (AUT-15)

**Read:** `recovery/main` at `f6277ab`:
- merged since review 4: #587 (mine), #588, #591, #598, #602 (UX1 parts (d) and (g)), the PO cycles #590, #596, #601, #605, #606, `csa` #595, `uxa` #599, `lca` #600;
- open: `eng` #607 (UX1 delivered), `cra` #582, #589, #604 (not merged; read at head `ad18b4e` through the D-38 text that quotes it);
- README *Automation review* (new owner instruction "designed from scratch first", added by po 11:10), rule 9 (frozen packages bind every role); `STRATEGY.md` §8 (future-state model, `csa` 10:47); `CARE_OPERATING_MODEL.md` *Provider kit* (STR-19, P-25);
- briefs: COORD6 (new, approved), UX1-31 to UX1-33, UX2-12, WORK1-C5 (CGR-86); D-38 T15-T18 as of po 14:20 (unfrozen, `inputs-requested`);
- code: `src/features/team/rules.ts` (UX1-22 pointer), `src/features/push/rules.ts` (UX1-24 `allReachable`), `src/features/intake/rules.ts` (UX1-23), `src/features/field/todo.ts` (UX1-30).
- No open issue is labelled `automation`.

**Changed since review 4:** the owner's instruction (2026-10-28) now binds this review: start from "if we designed home care today", compare with current practice, then say eliminate, redesign, automate or replace. UX1 is fully merged (#598 `8d0e812`, #602 `f6277ab`; the register change is in #607, open). D-38 gained T15-T18. No delivered item proposes, drafts or ranks.

**Frozen packages (rule 9):** nothing written about any `awaiting-approval` package. D-38 is unfrozen (`inputs-requested`, po 11:10), so AUT-14 may address it.

**Nothing below is a measurement.**

### 1 The bottleneck map read from scratch (owner instruction 2026-10-28)

Reference: `STRATEGY.md` §8.1 (team owns its provider; coordination is a property of the record; one clinical language; machines propose, people decide; shared services without a headquarters; starting a provider is a product). The ranks of review 1 stand (estimate, ordinal); what changes is the verdict where the from-scratch model asks for more than an improvement.

| Rank (review 1) | Step | Improvement view (review 1) | From scratch (§8.1) | Changed verdict | Status |
|---|---|---|---|---|---|
| 1 | Travel and day order | day-order rule agent (AUT-5) + team geography | a neighbourhood team serving contiguous municipalities makes travel short by design; a route proposal only optimises the remainder | **replace first** (team geography through J2 matching and D-11), **automate second** (AUT-5). The team-level AN1 travel share is the test of both | PLANNED (AUT-5); geography OPEN (`csa`, D-11) |
| 2 | Documentation per visit | simplify, risk-based countersign, dictation later (AUT-4) | the record is written by doing: the care-plan items performed are the proof of delivery, and prose is needed only for what deviated or what the next nurse must know | **replace** "one free-text report per visit" with documentation by exception (P-2 in AUT-4), then dictation (A7, stage 2) only for the exceptions. Blanket countersign: **replace** with risk-based review (D-10, `clinical`). What a report must contain is the Clinical Owner's (UNKNOWN); this changes the form, not the duty | OPEN (D-10, G-1); A7 PLANNED stage 2 |
| 3 | Orders, referrals, relatives | eliminate by structured order and referral (AUT-6) | external actors are nodes of the record; nothing is phoned to be re-typed | unchanged: **eliminate** (AUT-6); waits on owner decisions D-22, D-9, D-3, not on build | OPEN |
| 4 | Who takes which visit | PLAN3 proposal (AUT-1) | no scheduling role exists | unchanged: **eliminate** the role; PLAN3 is the means | PLANNED (*Next up* 7) |
| 5 | Assessment → care plan | side-by-side view, import later (AUT-2, AUT-13) | one clinical language: the assessment is the source of the plan; nothing is typed twice | unchanged: **redesign** (ASM1, D-37); import (AUT-13) | PLANNED |
| 6-7 | Working time, status taps | simplify (AUT-8, AUT-7) | working time is a by-product of visits, confirmed | unchanged (WORK1 IMPLEMENTED; AUT-8 open with `lca`) | IMPLEMENTED / OPEN |
| 8-11 | Billing prep, referral pull, quality, self-organisation | eliminated or in progress | coordination is a state of the record | unchanged | IMPLEMENTED / PLANNED |
| **new** | **Founding a team's provider and moving to it** (team, its future Leitung Pflege; one-off per team, but months of work) | not in the map (D-38 was a partnership question) | **starting a provider is a product** (§8.1.6): a kit, with the readiness facts read from the record | **replace** a founding project with the provider kit (STR-19, po 11:10); **automate** the parts that are facts NAVORA already holds (AUT-14, AUT-15) | PLANNED (kit as documents); OPEN (AUT-14, AUT-15) |
| **new** | **Night and weekend on-call across teams** | not in the map | a contracted service shared by team-owned providers (§8.1.5) | no proposal: depends on P-24 (one Leitung Pflege or on-call service for several providers: UNKNOWN, `lca`, Zurich adviser) and D-3 (COVER1 off) | UNKNOWN |

**Why the new row matters for direct care time:** every hour a nurse spends assembling a licence file, a readiness list or a transfer checklist is taken from visits or from her own time; under D-38 it would be repeated per team unless the kit makes it a one-time product (P-25: second team at most half the time). Minutes: UNKNOWN until a first transition (estimate only).

### 2 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-14 | Provider transition: proving the eight T15 (b) safety kinds before a client moves (team, both Leitungen Pflege, Clinical Owner) | D-38 T15 (b) (po 14:20 from `cra` 13:40) names eight kinds of safety measure; how they are shown to be met is not stated, so by default it becomes a compiled checklist per team and per cut-over date. Five kinds already exist as states NAVORA records: (2) an open safety signal without a named taker (`safety_signals.taken_by`, 0060/0063); (3) P1 reach outside the app (`allReachable`, `src/features/push/rules.ts`, UX1-24, IMPLEMENTED); (5) order validity on a date (`cases.medical_order_valid_until`, order alerts, 0024:426, :495); (6) qualification (`private.required_qualification`, 0017:301; `set_member_qualification`, 0018); the returned-report part of (2) (F6R). Not in the record: (1) a responsible provider per client and date (no provider entity; UNKNOWN for `eng`); (4) export (T2, T18 (e), not built); (7) rule adoption (T13, not built); (8) open `cra` S1 findings (a report fact, not data). Challenge duty: no administration is added yet; this finding keeps it that way. The control itself is a patient-safety precondition and stays | **automate (deterministic, no agent):** when the transition is briefed, the readiness for each kind is a read of the record for the moving clients and the cut-over date: a team-level list of the items that still block, each with the existing link to act on it, and the same list for every later team (kit, STR-19). No level, threshold or pass mark is set by the view: levels are the Clinical Owner's (G-1, UNKNOWN); the view shows counts and items, the Clinical Owner or a Leitung Pflege states that the level is met. Kinds (1), (4), (7), (8) stay manual until their data exist; each is named as manual in the view, never shown as met. Gain: one compiled checklist per team transition (and re-checks per postponed date) becomes a read; minutes UNKNOWN (estimate) | L (shows recorded states; no clinical content of its own) | stage 0; PO (whether to brief), `cra` (that the view shows kinds without a level and that no kind is shown as met without data), `eng` (kind (1): how a provider per client and date is recorded), `lca` (the partner's Leitung Pflege reads C-side items only within the D-12 processor scope) | hours from "Clinical Owner's levels set" to "readiness confirmed" per transition; number of kinds checked by hand per transition (target: four, falling as (1), (4), (7) gain data) | medium | – (comment on #545) |
| AUT-15 | Provider kit: C's licence file and set-up (future Leitung Pflege, team) | STR-19 (po 11:10): every transition document is written as a reusable kit; nothing built; no template states a legal or tariff rule not confirmed by `lca` and the adviser. Several entries a licence file and a processor agreement need are facts NAVORA already holds or will hold: the team roster with qualifications (0018), the named Leitung Pflege and deputy (T18 (b)), the rule-adoption record (T13, T18 (d)), the processor-agreement parties and data categories (T18 (c)). Which entries the Zurich licence file requires: [Z1] as read by `lca` 11:55; the full list is UNKNOWN to `aia` | **automate later (deterministic assembly):** the kit's templates mark each entry as (a) a fact read from the record, (b) a team decision, or (c) text `lca` or the adviser confirmed; only (a) is filled from the record, as a draft the future Leitung Pflege confirms entry by entry. No AI drafting of legal text; an AI draft of any part waits for a D-35 stage that allows it and `lca`. Staff data in a licence file is personal data: `lca` first. Gain: the team does not re-type its own roster and roles into each document; minutes UNKNOWN (estimate) | L | stage 0 (deterministic); PO (only when the kit is built), `lca` (which staff facts may leave NAVORA into a licence file, to whom) | P-25 (consent decision → C's admission, first versus second team) | low | – |

**Briefs and items reviewed without a new finding:**
- **COORD6 (approved, *Next up* 2):** a deterministic check replaces a rule that every agent had to remember. It removes coordination work (value 5) without adding a step for any person; it is the pattern §8.1.2 asks for, applied to the agents. Supported.
- **WORK1-C5 (CGR-86):** a privacy control (WORK1-5 keeps the working day the nurse's own). Not administration; no challenge. It does matter for AUT-9: a team-level correction share for WORK1 must not be read while the test that guards D-23 term (b) is red at random.
- **D-38 T16 (stop and lift):** any member may pause a date without asking anyone, and the current provider keeps visiting: team autonomy at no care cost. The single person who lifts is already named as a gap by the PO (deputy for the Clinical Owner, G-1); `aia` agrees and adds nothing.
- **D-38 T15 (a), (d), (f), T17, T18:** legal and financing terms; no workflow step for a nurse beyond what AUT-14 and AUT-15 cover.
- **UX1-22 (merged):** a list entry that only repeats an open P1 card shrinks to one pointer line, fail-safe to the full entry. Less reading per safety situation, deterministic, no ranking. **UX1-23, UX1-24, UX1-30 to UX1-33, UX2-12:** wording, colour, focus and headings; no workflow step added or removed.

### 3 AI readiness of delivered items
- Nothing merged since review 4 proposes, drafts or ranks (UX1 parts (d), (g) are labels, focus, a fail-safe dedupe and a reach status). Nothing to check against §8.
- WORK1 stays outside the register (AUT-9, low); see WORK1-C5 above.

### 4 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED. UX1 merged in full (#598, #602; register update in #607, open). AIG1 is *Next up* 4, after COORD6 and ADM2 |
| 0 | ASM1 built | PLANNED (*Next up* 5), not started |
| 1-3 | unchanged from review 1 | OPEN |

### 5 Findings closed
- None.

### 6 Waiting for the PO
- AUT-14 (medium): whether D-38 T15 (b) is shown by a read of the record when the transition is briefed; `eng` on kind (1). Comment left on #545.
- AUT-15 (low): for when the provider kit is built; `lca` on staff facts in a licence file.
- Bottleneck map refresh: due 2026-11-03 (weekly); the from-scratch reading above is part of it.

---

## 2026-10-28 08:20 CET · aia review 4: AUT-13 import conditions from `cra`; UX1-30, UX2-10, UX2-11 reviewed; no new finding

**Read:** `recovery/main` at `221d4ae`:
- PO 02:10 (#578), 04:10 (#581), 06:10 (#583): ASM1-1 period storage; UX1-28 (d)-(e); UX1-30; UX2-10; UX2-11; the PO challenges on returned reports (04:10) and on AUT-13 (06:10);
- `eng` #574 merged (`93f7423`, ADR-106: UX1-18 axe `color-contrast`, UX1-27 `FOLLOWUP_HEADING` in `src/features/field/todo.ts`);
- `uxa` 03:50 and 07:50 (#580, #586);
- `cra` 05:30 on the open PR #582 (`gov/review-2026-10-28-0530`, not merged): the AUT-13 import conditions and agreement with AI Operating Model Review §12;
- the JOURNAL from 02:10 to 07:50. No open issue is labelled `automation`.

**Changed since review 3:** no item that proposes, drafts or ranks was delivered (#574 is a contrast check and a label constant). `cra` 05:30 and the PO 06:10 answered AUT-13. Three acceptance criteria were added (UX1-30, UX2-10, UX2-11).

**Not re-done:** the bottleneck map v1 (review 1, 2026-10-27 14:48) stands; its weekly refresh is due 2026-11-03. **Nothing below is a measurement.**

### 1 Findings: changes

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-13 | Needs assessment: transcription into ASM1 (assessing RN) | **Answered, still not actionable.** `cra` 05:30 (#582, open): the import is clinically acceptable as described, with three conditions for the later brief: (1) an imported draft is no assessment record until the assessing RN confirms it value by value (it neither satisfies a reassessment due date nor feeds A10); (2) the period is imported as the tool states it, never mapped or converted (CGR-84); (3) the record keeps per value whether it was imported or typed (H-22). PO 06:10: no hypothesis row until `eng` reports the field mapping; depends on D-36 licence terms and the ASM1 build. ASM1 not started (IMPLEMENTED: nothing) | unchanged: **eliminate later through the care graph (import)**. The three `cra` conditions are now part of the proposal and of AI Operating Model Review §12. Condition (3) is the provenance-per-value control of §8, so a later import needs no new control type. Next trigger: the ASM1 PR (`eng` notes the field mapping) or a D-36 licence answer | L (header values only, D-36 A) | stage 0; `lca` (D-36), `cra` (reviews the brief), PO | as review 3; after an import exists, the share of imported values confirmed unchanged, per team | low | – |

**Briefs and packages reviewed without a new finding:**
- **UX1-30 (PO 04:10, `cra` conditions 06:10):** one label per "Zu erledigen" link and its section. The instruction to correct and sign again keeps its words and its place in the section. The nurse reads one label instead of two; no step, field or approval is added.
- **UX2-11 (PO 06:10 from `cra` 05:30):** a returned report stays on her day until she signs it again. This is a continuity control with a shown patient-care benefit (F6R-5: no unsigned report drops out of sight). It also makes the leaner form possible that the PO named in the 04:10 challenge: the correction as the visit card's next action instead of a second list. `aia` supports that direction for UX2. Gain estimated as one fewer place to look per returned report; minutes UNKNOWN until F6R-9 (return share) has pilot data.
- **UX2-10:** CI coverage only (axe on working states); no effect on care time.
- **ASM1-1 period storage (CGR-84):** already reviewed in review 3; no change.

### 2 AI readiness of delivered items
- #574 does not propose, draft or rank: nothing to check against §8.
- WORK1 stays outside the register (AUT-9, low, unchanged).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED. UX1 is still `in-progress`: part (d) (UX1-11 to UX1-13, UX1-28 to UX1-30) and part (g) are open; UX1-18 and UX1-27 merged (#574). AIG1 is *Next up* after UX1 and ADM2 (#499 open) |
| 0 | ASM1 built | PLANNED; approved, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Waiting for the PO
- Nothing new from `aia`: no `high` finding, no challenge, no issue opened.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-28 02:20 CET · aia review 3: AUT-2, AUT-10, AUT-11, AUT-12 taken in by the PO; ASM1 transcription (AUT-13); A10 input control

**Read:** `recovery/main` at `7eae8d0`:
- ASM1 as amended (po 21:15, 22:15; ASM1-1 period, ASM1-11 rewritten, no sum) and the open PO PR #578 (po 02:10: ASM1-1 period storage from `cra` CGR-84; UX1-28 (d), (e));
- UX1-25 to UX1-29 (po 20:15, 22:15, 00:15) and the open `eng` PR #574 (UX1-18, UX1-27);
- D-38 as frozen by po 01:10 (T12 (i) with (a)-(b), T13 with (a)-(f)), `lca` 20:48, 21:45, 23:41, 00:45;
- `cra` 21:30 and 01:30 (`CLINICAL_GOVERNANCE.md`: CGR-80 to CGR-84);
- `NEXT_CAPABILITY.md` challenge table (P-19, P-20, P-24); the JOURNAL from 20:30 to 01:30.

**Changed since review 2:**
- every review-2 proposal was answered by the PO (21:15): AUT-2 → ASM1-11; AUT-10 (b) → D-38 T12 (i), AUT-10 (a) → adviser bundle; AUT-11 → D-38 T13 form; AUT-12 → hypothesis P-24 and adviser question;
- `cra` CGR-81 rewrote ASM1-11 to "items listed as written, no sum"; CGR-84 fixes how the period is stored;
- UX1 parts (c) and (f) merged (#554, #558); no item that proposes, drafts or ranks was delivered.

**Not re-done:** the bottleneck map v1 (review 1, 2026-10-27 14:48) stands; its weekly refresh is due 2026-11-03. **Nothing below is a measurement.**

### 1 Findings: changes and new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-2 | Needs assessment → care plan (assessing RN) | **Closed with evidence: placed.** po 21:15 added ASM1-11 with `cra`'s four conditions as tests; po 22:15 rewrote it from CGR-81: assessed minutes with their period beside the category's items as written, **no total, sum or difference** (`briefs/ASM1.md` ASM1-11, acceptance (1)-(3)). The gain is smaller than proposed (the team still reads two lists side by side, no computed comparison), but it is the safe form: a per-occurrence sum with free-text frequencies would show a false gap (H-24) | done (simplify): one screen instead of opening the assessment document beside the care plan. A computed comparison only by a later brief with `cra` review, once every item carries a structured frequency and the period set is known (PO note 22:15) | L | stage 0; met at brief level | share of ASM1 records superseded within 7 days, per team (unchanged) | closed | – |
| AUT-10 | Provider cut-over (D-38 T12 (i)) | **Closed at package level.** (b) adopted in `lca`'s wording (po 21:15, `decisions/D-38.md:52`): the cut-over follows the next due reassessment or order renewal inside an owner-set window; a due one is never postponed. (a) is in the adviser bundle in `lca` 20:48's wording; until answered C makes its own assessment (protective default, UNKNOWN) | done for (b). (a) waits for the Zurich legal adviser or the tariff partner; `aia` reopens it only on that answer | L | stage 0; adviser for (a); owner for the window | as review 2, once a cut-over capability is briefed | closed | – |
| AUT-11 | Rule adoption (D-38 T13) | **Closed at package level.** T13 form adopted (po 21:15) with (a)-(d), no preset marks; `cra` CGR-83 added (e)-(f) | done: one signed act per catalogue version instead of one per rule, same per-rule decision and right to refuse | L | stage 0; adviser for the preset question | adoption acts per catalogue version per partner | closed | – |
| AUT-12 | Statutory administration per team-owned provider | **Placed:** hypothesis P-24 (`NEXT_CAPABILITY.md` challenge table) and an adviser question; `lca` 20:48 sees no objection to a service company acting as processor and agent of each C, licence-bound roles kept per C; one Leitung Pflege for several C UNKNOWN | unchanged; `aia` follows it as P-24, nothing to build | L | not an AI question; `csa`, `lca`, owner | as review 2 | closed (placed) | – |
| **AUT-13** | **Needs assessment: transcription into ASM1 (assessing RN)** | ASM1-1 (as amended 22:15, #578) has the RN copy, per assessment, the date, instrument and version, document reference and, **per KLV category A, B, C, the minutes and their period** from the provider's assessment tool into NAVORA by hand. That is a second entry of values already held in the tool. The period field adds patient-care benefit (CGR-81: no false gap, H-24), so the field is **not challenged**; the double entry is the bottleneck. How the provider's tool exports these values: UNKNOWN (no export format read; D-36 option A allows interRAI by name only). Effort per assessment: UNKNOWN; at a reassessment cycle of the order of months per client (the cycle is `clinical`, UNKNOWN), the volume is small per team but the risk of a copy error is per value | **eliminate later through the care graph (import), not now:** when a provider tool's export of these header values (date, instrument, assessor, minutes, period; **no item, score or CAP**, D-36 A) is known, a deterministic import fills an ASM1 draft that the assessing RN confirms value by value (assessment fields are never `schedule`, AIG1-5). Until then ASM1 stays manual as briefed. First step, no build: `eng` notes in the ASM1 PR whether the seed's period and minutes fields map one-to-one to a tool export, and `lca` names the processor and licence question for such an import (D-36) | L (copy of header values, no clinical content) | stage 0 (deterministic import, synthetic data); `lca` (D-36 licence, processor), `cra` (the import shows nothing the tool did not say), PO for a later brief | per team: share of ASM1 records superseded or corrected within 7 days (copy errors); after an import exists, values confirmed unchanged from the import | low | – |

**Briefs and packages reviewed without a new finding:**
- **ASM1-1 period storage (CGR-84, #578):** free text or the organisation's own list, no hard-coded list. It adds no step beyond the period the 22:15 amendment already required, and avoids an invented rule (KLV Art. 8, UNKNOWN). No leaner form at equal safety.
- **UX1-25 to UX1-29, UX1-18:** accessibility and the CGR-32 notice. UX1-28 keeps a nurse from being recorded absent without knowing it, and keeps the "visits before today need your team" notice in sight: a continuity control with no added step for her (one fewer state to check afterwards). UX1-27 keeps interruption follow-ups above the next visit. None adds administration.
- **D-38 T12 (i) (a)-(b) (CGR-82, `lca` 23:41):** a successor provider counts only after written acceptance and the client's recorded choice. This adds a written step, but its patient-care benefit is shown (no client without a visiting provider); no leaner form at equal safety. **T13 (e)-(f) (CGR-83):** safety withdrawal for all providers at once; no added step for the team.
- **PO 01:10 freeze of D-38:** agrees with the challenge duty; further term churn without new evidence would be administration.

### 2 AI readiness of delivered items
- No item that proposes, drafts or ranks was delivered since review 2 (#554, #558 are presentation; #574 is a contrast job and a layout test).
- WORK1 stays outside the register (AUT-9, low, unchanged).
- **New control for a future agent (AI Operating Model Review §12):** A10 (care-plan review proposer) must not compute a sum, difference or per-period conversion of assessed and planned minutes until a brief with `cra` review allows it (CGR-81). Recorded so the agent catalogue does not reintroduce what ASM1-11 forbids.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED: *Next up* after UX1 (in progress: (d), (g), UX1-18 open) and ADM2; unchanged |
| 0 | ASM1 built (assessment records as graph input for A10) | PLANNED; approved, not started; CGR-81 remedy and CGR-84 in the brief |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Waiting for the PO
- Nothing new from `aia`: no `high` finding, no issue opened. AUT-13 (low) stays in this report until an ASM1 PR or a D-36 answer makes it actionable.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-27 20:30 CET · aia review 2: AUT-1 closed, `cra` answers placed, D-38 cut-over reviewed

**Read:** `recovery/main` at `0b6a24f`:
- the briefs AIG1 and PLAN3 as amended (po 15:20 and 18:10), UX1 part (g);
- `cra` 17:35, which covers CGR-78 and the answers on AUT-2, AUT-4 and AUT-7 (`CLINICAL_GOVERNANCE.md`);
- D-38 as on the branch of open PR #562 (po 20:15): T1-T14, `lca` 15:48, 18:05 and 19:50, and the Engineering section drafted by po;
- the challenge table rows for P-19, P-20, P-22 and P-23;
- the JOURNAL from 14:45 to 19:51.

**Changed since review 1:**
- the AUT-1 answer (#546, #557, #543 closed);
- D-38 drafted to T1-T14 and escalated to the owner (#562, open);
- UX1-25 and UX1-26 added;
- no item delivered.

**Not re-done:** the bottleneck map v1 (14:48) stands. Its weekly refresh is due 2026-11-03. **Nothing below is a measurement.**

### 1 Findings: changes and new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-1 | Planning: the team confirms the PLAN3 day proposal | **Closed with evidence.** AIG1-5 was amended 15:20 and 18:10 to a per-field class `schedule`/`record`. Bulk confirm applies only to `schedule` fields of level-L `rule` agents, as an unticked list with no "select all". `cra` 17:35 (CGR-78) confirmed `responsible_user_id` as `schedule`. PLAN3-5, -7 and -9 were amended; PLAN3-7 adds "confirm actions per day plan" and "median minutes from proposal to confirmed plan". #543 closed by po 18:10 | done: one action per day plan instead of one per visit, at equal safety (J3 re-checks every line) | L | stage 0; met | PLAN3-7 (as adopted) | closed | #543 |
| AUT-2 | Needs assessment → care plan (assessing RN) | **`cra` answered (17:35): not clinical content as a display of two recorded numbers,** on four conditions: (1) no colour, warning, "Abweichung" or icon derived from the difference; (2) the assessment's date and assessor shown with it; (3) a newer significant event shown as such (H-22); (4) nothing blocked or changed by the difference. Billability of planned minutes above assessed minutes is `legal` with D-18, UNKNOWN | **simplify (unchanged), now unblocked:** the PO may place the display into ASM1 (for example as ASM1-9) with `cra`'s four conditions as its acceptance criteria. Estimated gain: one fewer transcription source per assessment; minutes UNKNOWN | L | stage 0; PO places; D-18 for billing | share of ASM1 records superseded within 7 days, per team | medium | – |
| AUT-3 | All steps: measuring administrative time | Placed by po 15:20 as hypothesis **P-19**, a brief after AIG1 | unchanged | L | stage 0; `lca` | P-19 | medium (placed) | – |
| AUT-7 | Visit status taps (nurse) | **Closed: not worth building now.** `cra` 17:35: an inferred time must be labelled as inferred and confirmed by the nurse before it reaches the report or a billable fact. AIG1-3 says signing a report does not confirm a proposed value, and AIG1-5 classes any visit time field `record`, so it is confirmed one by one. Removing the `departed` and `paused`/`resumed` taps would add the same number of confirm taps. Net gain about zero (estimate) | **keep the five events as built.** Reopen only if AN1 `time_correction_share` or a pilot tally shows the taps cost time | – | – | AN1 `time_correction_share` | closed | – |
| AUT-8 | Working time (nurse) | Placed by po 15:20 as hypothesis **P-20**; `lca` first | unchanged | L | stage 0; `lca`, D-23 | P-20 | medium (placed) | – |
| AUT-4 | Documentation per visit; countersignature | `cra` 17:35: replacing the blanket countersignature falls under the safety-control guard (CGR-76) and D-10. It needs equal or better protection against H-04 and H-05, decided by the Clinical Owner. This challenges the step's form, never its existence | unchanged. Before D-10 B can be argued, F6R-9 (return share and latency) must have pilot data | L / G | D-10 `clinical`, G-1 | F6R-9 | medium | – |
| **AUT-10** | **Provider cut-over (D-38 T12 (i)): the team's RN, every client of the team** | T12 (i) sets each client's cut-over only after C's own *Bedarfsmeldung*, C's own needs assessment and, for treatment care, an order valid for C. At the sunset this falls on **every client of the team in one window**, in addition to the T12 (ii) close-out, the T3 consent conversation and the T5 information. Per `lca` 19:50 [B2] (BAG explanation, not the ordinance text), the KLV ties an order to the treating physician and **does not tie a needs assessment to a provider**. In a team transfer the assessing RN is usually the same person, now employed by C. So a new assessment may duplicate a valid one: administration created by the change of employer, not by a change in the client. **Patient-care benefit is shown for the continuity part (no day without a provider; CGR-79), so this challenges the form, not the term.** | **simplify** (equal safety, T12 (i) unchanged in effect): (a) add to the adviser bundle: "may C file its *Bedarfsmeldung* on a valid needs assessment made by the same RN while employed by the partner, or must a new one be made?"; (b) T12 (i) already says "where practical the cut-over follows an order renewal". Widen it to "follows the client's next due reassessment or order renewal inside a cut-over window", so no assessment or renewal is made only because of the transfer. The window's length is the owner's (T4, the D-12 sunset), UNKNOWN. Estimated gain: up to one needs-assessment visit plus one order request per client of the team, once per transfer; minutes UNKNOWN | L (a planning rule; no clinical content; T12 (ii) checks stay) | stage 0; `lca` and Zurich legal adviser for (a); `cra` (does the widened timing keep CGR-79?); owner for the window | per team at cut-over: assessments and order requests made only because of the cut-over, counted from ASM1 and ORD0 records when a cut-over capability is briefed | medium | comment on #539 |
| **AUT-11** | **Rule adoption by the partner's Leitung Pflege (D-38 T13)** | T13: the partner's Leitung Pflege adopts or suspends the NAVORA Clinical Owner's rules one by one, with name and date. The catalogue is empty today (D-16, D-17, D-19, D-28 all `clinical`, G-1 not named). Once filled, each catalogue version means one decision per rule, per partner, and again per C. This is a legal accountability step (`lca` 18:05, R-11): its existence is not challenged | **simplify the form:** one signed adoption act per catalogue version, which lists every rule by name and lets the Leitung Pflege mark single rules as not adopted, with name and date. This is the same per-rule record and the same right to refuse, with one act instead of N. Product design waits for a brief that builds rule adoption (none is approved) | L | stage 0; `lca` (is a listed act equivalent for the licence holder's duty?), `cra` | adoption acts per catalogue version per partner | low | comment on #539 |
| **AUT-12** | **Team-owned provider C: statutory administration per small team** | D-38 T6 (own tariff contract), T7 (municipal financing), T14 (cantonal *Leistungsauftrag*, training-place duty under the ALV) and D-12 C conditions: each team of about four to eight nurses carries the full set of provider duties itself. `lca` 19:50 calls the ALV burden for such a team UNKNOWN. P-23 (po 20:15) covers training only. Evidence for the size of this burden: none read; UNKNOWN | **replace (operating model):** test, with `csa` and `lca`, whether a shared regulated service for several team-owned providers can carry contract, mandate, training, quality reporting and billing submission. Each team would keep its own care decisions and economics; the service would be a cooperative or network entity, not a management layer. Without it, administration removed from the nurse by NAVORA returns to the team as a provider's paperwork. The owner decides through a PO package; `aia` only names the bottleneck | L | not an AI question; `csa` (fit, STR), `lca` (whether several licences can share one service), owner | statutory admin items per C (count from the T6, T7, T14 lists); later the hours per team per month (pilot) | medium | – |

**Briefs and packages reviewed without a new finding:**
- **UX1-25, UX1-26:** focus and Escape handling for the absence overlay and the menu. Accessibility only, no added step; they protect the ABS1 path.
- **D-38 T1-T4, T12 (ii), T14:** each adds protection or preparation that a patient or legal duty requires (CGR-79, `lca`); there is no leaner form at equal safety.
- **P-22, P-23:** P-23 is the training part of AUT-12.
- **AIG1 and PLAN3 as amended:** consistent with §8 of the AI Operating Model Review (updated in this run).

### 2 AI readiness of delivered items
- No item that proposes, drafts or ranks was delivered since review 1.
- WORK1 stays outside the register (AUT-9, low, unchanged).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1-5 scope settled before build | **met** (AUT-1 closed; CGR-78 in the brief) |
| 0 | AIG1 built | PLANNED: *Next up* 3, after UX1 (in progress) and ADM2 |
| 0 | PLAN3 built | PLANNED: *Next up* 6; waits for AIG1 |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Waiting for the PO
- **AUT-2:** place the display into ASM1 with `cra`'s four conditions.
- **AUT-10, AUT-11:** consider them with D-38 (comment on #539). AUT-10 (a) belongs in the adviser bundle. Neither changes the owner ask "approve T1-T14".
- **AUT-12:** decide whether it becomes a `csa`/`lca` question or a package.
- No `high` finding in this run; no issue opened.

---

## 2026-10-27 14:48 CET · aia review 1: first bottleneck map, review of AIG1, ASM1, PLAN3

**Read:** `recovery/main` at `649b051`:
- the governance files, JOURNAL to `csa` 13:55 and `lca` 13:52, the mandate;
- the AI Operating Model Review, the Strategic Alignment Review §3-§4, the challenge table in `NEXT_CAPABILITY.md`;
- briefs AIG1, ASM1, PLAN3 (approved 13:35), WORK1, REF2, ORD1;
- migrations 0007, 0014, 0016, 0027, 0079;
- open PRs #532, #533, #535 and issue #536.

**Format:** this section follows PR #533 (po 13:50, open), which asks for a verdict and an estimated direct-care time gain per bottleneck. **Nothing below is a measurement.**
- **Code and events** show which steps a person must take, and how often.
- **Minutes per step** are UNKNOWN until a team-level measure exists (AUT-3).
- **The rank** is an `aia` estimate (ordinal).
- **Published sources** are cited only where I read them, with the date I read them.

### 1 Bottleneck map (first version; refreshed weekly)

**Published evidence read on 2026-10-27:**
- **[E1]** Himolde repository record of a 2018 prospective study: home care staff in three rural Norwegian municipalities logged activities for 8 weeks in 2016 (<https://himolde.brage.unit.no/himolde-xmlui/handle/11250/3085213>; read through its abstract page only).
  - Direct care was "less than 50 %" of total work.
  - Driving was 43-54 % of indirect time.
  - Reporting and documentation were 38-50 % of indirect time.
  - Swiss transferability: UNKNOWN.
- **[E2]** Blay et al., *J Adv Nurs* 81(7), 2025, a community-nursing time-and-motion study (<https://ro.ecu.edu.au/ecuworks2022-2026/5441>; abstract page only). It names documentation and travel as the inefficient practices. No per-category share is given on the page.
- Buurtzorg benchmarks: as cited by `csa` in `STRATEGY.md` §7 (not re-read).

**Rank** is the estimated direct-care time recoverable at team level, 1 = largest (estimate).

| Rank | Step (role) | What NAVORA asks of a person today | Status | Verdict | Gate | Finding |
|---|---|---|---|---|---|---|
| 1 | Visit: travel and day order (nurse) | She orders her day and route herself; AN1 measures travel minutes from `departed`→`started` (0007, 0027) | IMPLEMENTED (measure); OPEN (proposal) | automate (day-order rule agent) + replace (team geography) | Q7, `lca`; `csa` | AUT-5 |
| 2 | Documentation (nurse; RN countersigner) | She signs one report per visit at completion (F7). An RN countersigns every care-assistant report (`countersign_required`, 0016). The summary is optional free text (`report-section.tsx`:351) | IMPLEMENTED | simplify; replace countersign with risk-based review; AI-support (A7, stage 2) | D-10 (`clinical`), G-1, D-35 stage 2 | AUT-4 |
| 3 | Coordination with GP, hospital, relatives (primary nurse) | Order renewal by phone or fax; ORD0 records "Hausärztin informiert" as a task (0061). Referrals re-typed at intake (J1). Relatives' calls: not recorded | IMPLEMENTED (task); PLANNED (ORD1, REF2 drafts) | eliminate (structured order, referral, external actors as graph nodes); AI-support later (A2 stage 1, A8 stage 3) | D-22, D-9, D-3 (`owner`) | AUT-6 |
| 4 | Planning: who takes which visit (team) | A member sets `responsible_user_id` visit by visit (J3, 0014); PLAN2 already generates the visits | IMPLEMENTED (manual); PLANNED (PLAN3) | automate (PLAN3 rule agent) | AIG1, PLAN3 | AUT-1 |
| 5 | Needs assessment to care plan (assessing RN) | Today a flag (`is_needs_assessment`, 0014). After ASM1: minutes per category typed from the provider's tool, then per service again on the care plan (`care_plan_items.planned_minutes`, 0014:77) | IMPLEMENTED (flag); PLANNED (ASM1) | simplify now; eliminate with an import (D-37 B) | `cra`; `owner` D-37, D-36 | AUT-2 |
| 6 | Working time (nurse) | She confirms each working day and answers two questions before she can confirm (WORK1-2; 0079) | IMPLEMENTED | simplify (form of confirmation; the duty stays) | `lca`, D-23 | AUT-8 |
| 7 | Visit status (nurse) | Five event types per visit: `departed`, `started`, `paused`, `resumed`, `completed` (0007) | IMPLEMENTED | simplify (infer travel and pause) | none (product) | AUT-7 |
| 8 | Billing preparation (back office) | Nothing: J5 derives billable facts continuously from signed reports. The invoice itself is not built | IMPLEMENTED (facts); PLANNED (BILL2) | eliminated as preparation; automate invoice later | D-12, D-18 | – |
| 9 | Referral → case → matching → team decision | J1 readiness, J2 team pull to all eligible teams at once; no dispatcher | IMPLEMENTED | eliminated (sequential offers); re-typing → rank 3 | – | – |
| 10 | Quality and analytics (team, coach) | QG1 signals and AN1, AN2 measures come from events; no hand tally. Hold lift by coach or admin is still a management step (D-16) | IMPLEMENTED | eliminated (compilation); the hold-lift form waits for `clinical` | D-16 | – (existing challenge row) |
| 11 | Team self-organisation | Absence: one command (ABS1). Offboarding: LEAVE1. Cover: COVER1 accepted, switched off (D-3). Onboarding: ADM2 approved (team admits by consent; employer records "Vertrag erfasst" once) | IMPLEMENTED; PLANNED (ADM2); OPEN (D-3) | eliminated (phone chain, dispatcher); replace (central admission → ADM2) | D-3, D-20 | – |

**What the map cannot show yet** (UNKNOWN):
- minutes per step;
- the share of a working day spent on any one of them;
- how many phone calls with GPs, hospitals and relatives a team has.

AUT-3 proposes how to measure these from existing events, without new taps.

### 2 Findings

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) and estimated gain | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-1 | Planning: the team confirms PLAN3's day proposal (AIG1-5 × PLAN3-5) | **Challenge.** AIG1-5's default refuses every bulk confirm of more than one value until the Clinical Owner's list exists. So PLAN3-5's "ticked list" is refused, and the day plan becomes one confirmation per open visit, every team, every day. N = open visits per team-day, UNKNOWN for the pilot. `csa` 13:55 says the opposite ("whole proposal at once"). **No patient-care benefit shown:** D-17 part 3 lists safety-alert categories. §8 scopes "no accept-all" to safety-alert, care-plan and medical-order fields. `responsible_user_id` is a schedule fact, and J3 and PLAN3-2 re-check qualification, absence, membership and overlap per line at confirm time | **simplify:** the one-by-one default stays for level G and H, and for fields writing to safety alerts, the care plan, a medical order or an assessment. Level-L `rule` agents on schedule facts may be confirmed as an explicit ticked list, one ledger confirmation per line. Gain: about one action per open visit per team-day, minus one; minutes UNKNOWN (estimate) | L | stage 0; PO (product), `cra` on the field class only | confirmations per day plan; share confirmed unchanged (AIG1-7); minutes from proposal to confirmed plan | high | #543 |
| AUT-2 | Needs assessment → care plan (assessing RN, team) | ASM1-1 and ASM1-4: minutes per category A, B, C are typed from the provider's tool (the brief itself names this a transcription hazard, D-13 point 3). The care plan then holds minutes per service again (`care_plan_items.planned_minutes`, 0014:77), with no link between the two (ASM1-8 leaves it to the ADR). ASM1-5 (confirmation by the named RN) has a billing-integrity and safety reason: no challenge | **simplify now:** the care plan shows, per category, the current assessment's minutes beside the sum of its planned minutes. This displays two recorded numbers: no rule, no threshold, no signal. What a difference means is UNKNOWN (`cra`, Clinical Owner). **Eliminate later:** import of the reported minutes (D-37 B). Gain: one fewer transcription source; minutes UNKNOWN (estimate) | L (display); import: per D-37 | stage 0; `cra` (whether the display is clinical content); `owner` D-37, D-36 for the import | share of ASM1 records superseded within 7 days of entry, per team (transcription corrections) | medium | – |
| AUT-3 | All steps: measuring the administrative burden itself | The owner's success measure 2 (less administration) has no team-level measure per step. AN1's `direct_care_share` is an upper bound by its own comment (0027:9-11). WORK1 groups non-visit work into one self-reported kind, `administration` (0079:90). Report effort is not captured, only the latency `report_final_minutes` (0027) | **monitor:** derive per-step time from timestamps NAVORA already stores. Report draft created → signed (F6, F7); countersign latency (F6R-9); intake span (partner request → case ready, J1); ORD0 task age; AIG1 proposal → confirm. Per team and month, small-team suppression; no new tap, no per-person read. Gain: none by itself; makes every other gain provable | L | stage 0; `lca` (staff timing aggregated per team; must not read the WORK1 tables beyond WORK1-6, D-23 term (b)) | the measures themselves, in AN1/AN2 | medium | – |
| AUT-4 | Documentation per visit (nurse; RN countersigner) | One report per visit, signed at completion (F7). For care-assistant visits an RN countersigns each report (0016:39, :267), the "doubtful" row in the challenge table. Published: documentation is a large part of indirect time [E1], [E2] | **replace** the blanket countersign with risk-based review after the pilot (D-10 A vs B, `clinical`, on F6R-9 evidence: existing). **Simplify:** proof of delivery from facts, not prose (P-2). **AI-support:** A7, the nurse's own dictation (stage 2, G). Gain: largest per-visit lever after travel (estimate); UNKNOWN | L (P-2); G (A7) | D-10 `clinical` (G-1); stage 2 entry conditions (§4) | `report_final_minutes`; report draft→sign span (AUT-3); F6R-9 return share | medium | – |
| AUT-5 | Day order and travel (nurse) | No proposal; PLAN3 excludes it (*Out of scope*, Q7). AN1 already measures travel minutes. Published: driving was 43-54 % of indirect time in [E1] | **automate:** a day-order rule agent (visit windows plus travel time) registered in AIG1, after Q7. **Replace:** team geography. Small neighbourhood teams keep travel short by design; matching (J2) and the D-11 choice of municipality decide it. Gain: likely the largest single block (estimate, [E1]); UNKNOWN for NAVORA | L | stage 0 for the rule; Q7 (location data, `lca`); `csa` for team geography | AN1 travel share per team, before and after | medium | – |
| AUT-6 | GP orders, hospital referrals, relatives (primary nurse) | Order renewal by phone or fax; ORD0 only records the task (0061). Referrals re-typed at J1 intake. ORD1 and REF2 are drafts, blocked by owner decisions D-22, D-9, D-3. Relatives' calls: no data | **eliminate:** the structured order, the referral and external actors as graph nodes (P-9) before any agent. AI-support only at the edges later: A2 renewal letter (stage 1, held by `lca` condition 1 per `lca` 13:52), A8 extraction (stage 3, H). Gain: large, UNKNOWN; the whole step waits on owner decisions, not on build | L (structured); H (A8) | D-22, D-9, D-3 (`owner`), then stage 1 | ORD0 open-task age per team; intake span (AUT-3); a two-week tally of relatives' calls (existing challenge row) | medium | – |
| AUT-7 | Visit status taps (nurse) | Five event types, up to six taps per visit (0007) | **simplify:** infer travel and pause, keep start and end (existing hypothesis), tested with AN1 `time_correction_share`. Gain: small per visit, every visit (estimate) | L | stage 0; none | `time_correction_share`; taps per completed visit | low | – |
| AUT-8 | Working time (nurse) | One confirmation per working day, with two mandatory questions (breaks; work outside visits) before confirming (WORK1-2, 0079). The legal duty is not administration to remove; this challenges its form only | **simplify:** ask `lca` whether the nurse may confirm several proposed days in one action. Each day would stay its own append-only version, and the two questions would be answered only for a day that differs from its proposal. Gain: about four fewer confirmations per nurse-week (estimate) | L | stage 0; `lca`, D-23 | share of days confirmed unchanged from the proposal, per team (`from_proposal` is stored per segment, 0079:459) | medium | – |
| AUT-9 | AI readiness: WORK1 (a delivered rule proposer) | WORK1 proposes values that a named person confirms. Per-segment provenance exists (`from_proposal`, 0079:459, 476, 490). It has no correction-rate read, no stop rule and no register entry, because it predates AIG1 | **monitor:** once AIG1 is accepted, the PO decides whether WORK1 becomes agent `work1_day_proposal` (`rule`, L) or is recorded as exempt with the reason. Any team-level correction share needs `lca` first, because D-23 term (b) keeps the working day private | L | stage 0; PO; `lca` | – | low | – |

**Briefs reviewed without a new finding:**
- **AIG1:** apart from AUT-1, the controls match §8.
- **ASM1-5:** the confirmation step is justified.
- **PLAN3:** apart from AUT-1, the continuity order is a readable rule (PLAN3-3), with a team-level before-and-after measure (PLAN3-7).
- **ADM2:** removes a hierarchy step.
- **UX1, UX2:** the design shell; no workflow step added.

**No finding closed:** this is the first `aia` review.

### 3 Stage tracking (D-35 stages)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 approved (*Next up* 3), hand-off #536 | PLANNED, not built |
| 0 | PLAN3 approved (*Next up* 6) | PLANNED; waits for AIG1 |
| 0 | A1 referral completeness as a rule | PLANNED inside REF2 (draft; D-9, D-3) |
| 0 | A6 control health (P-8) | OPEN; waits for a hosted environment (D-2) |
| 0 | A4 invoice draft as a rule (BILL2) | not written; waits for D-12, D-18 |
| 1 | 3 stable pilot months | not started (no pilot partner yet) |
| 1 | `owner` package: provider, region, contract | not written |
| 1 | `lca` conditions 1-10; DPIA; partner's sub-processor approval | OPEN. Per `lca` 13:52, condition 1 holds the order-renewal and insurer letters (A2, A4) until adviser question 1 is answered |
| 2 | regulatory adviser on level G; the Clinical Owner's no-accept-all list; stage-1 correction rates | OPEN (G-1 not named) |
| 3 | D-34 C module, D-37, the licence (D-36), the Clinical Owner | OPEN |

**Next stage reachable without an owner decision:** stage 0 only. Its main missing pieces are building AIG1 and settling AUT-1 before Engineering builds the AIG1-5 test.

**Waiting for the PO:**
- answer AUT-1 (#543) in the AIG1 and PLAN3 evidence tables, before Engineering builds AIG1-5;
- place AUT-2, AUT-3 and AUT-8 (medium) when convenient;
- AUT-6 needs no new package: it adds weight to D-22, D-9 and D-3 when they are bundled for the owner.

---

## 2026-10-27 13:30 CET · baseline (seeded by `po`, not an `aia` review)

**Owner instruction for the first runs:** find the largest bottlenecks in home care, and say how NAVORA can eliminate, simplify or automate them.

**Already in the repository** (read these first; do not re-derive):
- [`../../product/AI_OPERATING_MODEL_REVIEW.md`](../../product/AI_OPERATING_MODEL_REVIEW.md): the care graph, roles, meetings, validations, documentation activities, agent catalogue A1-A12, *Agents not to build*, AI governance controls. From now on maintained by `aia`.
- [`../../product/TRANSFORMATION_ALIGNMENT_REPORT.md`](../../product/TRANSFORMATION_ALIGNMENT_REPORT.md): duplicated work, approvals and meetings that could disappear, first-principles redesigns.
- [`../../product/CARE_OPERATING_MODEL.md`](../../product/CARE_OPERATING_MODEL.md): North Star (direct care share, Buurtzorg 60 % benchmark, 75 % hypothesis), *What disappears*, challenge table.
- [`../../product/STRATEGIC_ALIGNMENT_REVIEW.md`](../../product/STRATEGIC_ALIGNMENT_REVIEW.md) §1, §3, §4: the verdict per dimension; the staged AI path approved by the owner; the proposed briefs AIG1, ASM1, PLAN3, BILL2.

**Candidate bottlenecks to test, as PO hypotheses (not findings).** Each needs evidence before it becomes an `AUT-<n>`:
- **Documentation time per visit:** report writing on a phone; countersignature (D-10).
- **Day planning and travel order;** balancing continuity by hand (PLAN2 plans visits; nobody orders the day).
- **Coordination by phone:**
  - GP order renewals (ORD1);
  - referrals from hospitals (REF2);
  - relatives.
- **Needs assessment and reassessment:** re-typing between the assessment tool and the care plan (D-13, D-37).
- **Billing preparation:**
  - checking billable minutes;
  - insurer queries (J5, A4).
- **Onboarding, offboarding and working-time administration** (ADM2, LEAVE1, WORK1).

**Measures available today:**
- AN1 (direct care share per team; synthetic data);
- AN2 (pilot hypotheses from events);
- WORK1 (confirmed working day).

Real pilot values: UNKNOWN until the pilot. Measure gains at team level only, never per person.

**Limits in force:**
- D-35 rule A: no client or staff data to any AI service; AI stage 0 only.
- D-34 statement v2: nothing computed from clinical content outside the future clinical module.
- D-36 option A: interRAI only by name.
- D-27: no clinical rule without the Clinical Owner.
