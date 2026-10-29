---
id: OBS1
title: Every observation shows who wrote it, and whether her qualification was recorded when she wrote it
author: po
status: approved
updated: 2026-10-29
---

# OBS1 — Every observation shows who wrote it

## Problem
IMPLEMENTED (as read by `cra` 13:40, CGR-93, and by `lca` 13:57 in the D-15 re-check; the PO read 0016:127-133): any active member of the visit's team may add an observation to a team visit that is `on_the_way`, `started`, `paused` or `completed` (`record_observation`, 0040:142-144), optionally for the handover. The author is stored (`visit_observations.author_id`), but:
- the handover (`field_notes`, 0009:133) returns only whether the reader wrote it herself (`own`), not who did;
- the report snapshot the performer drafts, signs and a registered nurse countersigns holds `content`, `recorded_at`, `handover` and `edited` per observation, **no author** (0016:127-133).

So the performer signs, and a registered nurse countersigns, a report whose observations may come from a colleague, without seeing that. Two consequences:
1. **Compliance:** `lca` 13:57 (ZH GesG § 13 Abs. 1 with § 39, read on lexfind and a hospital copy, not the official current zh.ch text): in a Spitex institution "die Urheberschaft der Einträge muss unmittelbar ersichtlich sein". Author shown for every observation in handover and snapshot: **compliant under every plausible interpretation** on the sources read; the system as built, or a qualification marker alone: **unresolved, needs a legal adviser** (question 9) and owner (D-11, D-12).
2. **Safety (`cra` CGR-93, advisory S2, H-04, PS-82):** since ADM2 (0091) an admitted member may have no recorded qualification. ADM2-16 stops her performing a visit, but her observation enters the handover and the performer's signed snapshot like any other. Refusing her observation is not the protective option (an observation of a fall, a wound or distress must not be lost); its origin must be visible where it is relied on.

And a coordination cost (challenge row 2026-10-29 14:35): a nurse who reads a handover note and wants to ask a follow-up question cannot see whom to ask.

## Users and journey step
Nurses and care assistants reading the handover (HAND1, `/field`); the performer drafting and signing her report (F6, F7); the registered nurse countersigning (F6, D-10); everyone who already reads a signed report (RLS2, RLS3). Step: Visit → Documentation.

## Outcome
Wherever an observation is relied on (the handover and the signed report), the reader sees who wrote it; if the author had no recorded qualification in the visit's team when she wrote it, the reader also sees that, without the observation being refused or hidden.

## Acceptance criteria
- [ ] **OBS1-1 Marker recorded at the time of writing.** When an observation is recorded, NAVORA records with it whether its author had a recorded qualification in the visit's team at that moment (for a covering nurse on a covered visit: in her cover team, the ADM2-16 rule `private.actor_may_perform_visit`, without a new rule). The value is fixed at write time; a later `set_member_qualification` does not change it. An observation is **never refused** for a missing qualification (pgTAP: the 094 member without a qualification records an observation on a visit a care assistant started → `ok`).
- [ ] **OBS1-2 Handover shows the author.** `field_notes` (or its current successor) returns for every observation the author's display name (ADM1 name, as the team list shows it) and the OBS1-1 marker, in addition to `own`. pgTAP: a colleague reading the handover sees the author's name and, for the 094 member's observation, the marker; after `set_member_qualification` a new observation by her carries no marker and the old one keeps it; observations by qualified members carry none.
- [ ] **OBS1-3 The report snapshot names the author.** Every snapshot created **after** this change (`create_report_draft` and every later path that builds a snapshot) holds per observation the author's identity, her display name at the time of the snapshot, and the OBS1-1 marker. **Signed snapshots created before the change are not rewritten** (CSR1: signed means immutable); the report view shows for such an observation one neutral line that its author is not part of the stored version (wording `uxa`'s), never a guessed name. pgTAP: a draft created after an observation by the 094 member carries her identity and the marker; a snapshot written before the migration is byte-for-byte unchanged.
- [ ] **OBS1-4 Screens.** The handover on `/field` (HAND1 section) and the report view the performer signs and the registered nurse countersigns show the author's name per observation and, where set, the marker as one short text in `info` tone (wording `uxa`'s, no internal code, no word that judges the person or the content, no red). Playwright at 390 px: one observation by a colleague with a qualification shows her name and no marker; one by the 094 member shows her name and the marker; the signer sees both before signing.
- [ ] **OBS1-5 No read widened, no per-person list.** No person gains a read she did not have: the author's name reaches only people who already read that observation (RLS2 `private.reads_visit`, RLS3) and is returned **per observation, never as a list, count or filter per person** (D-23 term b, RLS3-4). `field_notes` and the snapshot path are listed in `docs/engineering/READ_PATHS.md` under RLS3-4 with the task "authorship of a clinical entry (ZH GesG § 13, `lca` 13:57)"; the RLS3-4 pgTAP list is updated by that entry only. pgTAP: a nurse of another team, a coach and Operations read no author through the new fields; no AN1, AN2, OPS1 or export reader returns author identities of observations.
- [ ] **OBS1-6 `lca` read before merge.** Because G-18 (no teammate reads who performed each visit event row by row) and authorship meet here, `lca` reads the PR before merge and states whether OBS1-5 keeps G-18 and D-23 term b intact; `cra` reads it as its CGR-93 gate. Neither read is a legal or clinical determination.
- [ ] **Negative.** No observation is refused, hidden, reordered, ranked or routed by the marker; no signal, OPS1 exception, quality event or billing fact reads it. No change to who may record an observation (that is the Clinical Owner's, D-15). No new free-text field. ADM2-16, VIS1 and CGR-12 unchanged (their pgTAP suites pass unmodified).

## Rules and their input class
- OBS1-1 marker: *visit/schedule fact* (a recorded qualification state at a recorded time, no judgement). It only **displays**; it does not rank, route or escalate. No clinical rule: whether such observations are allowed, need a countersignature or need nothing stays the Clinical Owner's (`cra` CGR-93, D-15). The PO chose the marker (the `cra` remedy (1)) over "no marker" as the protective default; the Clinical Owner may later record that it is not needed.
- Author display: a documentation requirement as read by `lca` (advisory), not a NAVORA rule.

## Out of scope
- Whether a member without a recorded qualification may write observations at all, and any countersignature or review of them (Clinical Owner, D-15, D-10).
- A legal determination of ZH GesG § 13 (adviser question 9; D-11 names the canton).
- Authorship of other entry types (time corrections, care-plan entries, reports already carry their author); `cra` or `lca` may name another entry type in a later finding.
- UX2-22 (hiding refused field controls) stays in UX2.

## Constraints and references
`cra` CGR-93 (13:40, PR #666), `lca` 13:57 D-15 re-check (`decisions/D-15.md`), H-04, PS-82, CR-137, CR-140; HAND1 (0009), F6/F7 snapshot (0016, CSR1 immutability), `record_observation` (0040), ADM2-6, ADM2-16 (0094, ADR-117), RLS2, RLS3-4, G-18, D-23 term b, D-15, D-10. Synthetic data only.

**Release gates:** OBS1 accepted is a precondition of **G-23** (before a real organisation switches on team admission; `cra` 13:40 recommendation) and of the first real client in any organisation (authorship, `lca` 13:57), recorded in `CARE_OPERATING_MODEL.md`.

## Open questions for engineering
1. Marker as a column on `visit_observations` written by `record_observation`, or derived from the qualification history (0018 change log) at read time? The PO prefers the column (fixed at write time, one probe), but the choice is Engineering's; state it in the ADR.
2. The current definition of the snapshot builder after 0016 (later migrations may have replaced it): name every path that writes a snapshot.

## Pilot measures (AN2 candidates, counts only, never per person)
- Share of observations in signed reports written by someone other than the performer (hypothesis: under 1 in 10; if higher, the handover is carrying team communication that belongs elsewhere).
- Observations with the marker per month (target 0 once D-29 lets a qualification be verified before "Vertrag erfasst").

## PO notes
**2026-10-29 14:35 CET, approved (po).** Placed from `cra` CGR-93 and `lca` 13:57 together, because the two remedies are one change: the author is the protective fact for both, and the marker is one more field on the same line. Value 2 (continuity: the reader knows whom to ask), 5 (less coordination: no phone round to find who wrote a note); compliance precondition for real clients. Small: one column or derivation, two read paths, two screens. *Next up* 1, ahead of AIG1, because it closes a documentation gap in records that are already signed every day on synthetic data and gates both G-23 and the first real client.
