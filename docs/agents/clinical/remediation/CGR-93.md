# Remediation plan: CGR-93 (an observation by a member without a recorded qualification enters the handover and a colleague's signed report without author or qualification)

**Finding:** `cra` CGR-93, Clinical Governance Report 2026-10-29 13:40 (PR #666), **advisory (S2)**, recommended precondition of release gate G-23. `lca` 13:57 (D-15 re-check, `decisions/D-15.md`): author shown for every observation in handover and snapshot is compliant under every plausible interpretation on the sources read (ZH GesG § 13 Abs. 1, "Urheberschaft der Einträge … unmittelbar ersichtlich"); the marker alone is unresolved. Placed by the PO as **OBS1** (`briefs/OBS1.md`, approved 14:35). Engineering: ADR-118, migration 0095.

**Risk:** since 0091 an admitted member may have no recorded qualification. ADM2-16 stops her performing a visit, but `record_observation` accepts her observation on any team visit in progress or completed. The handover (`field_notes`, HAND1) and the report snapshot the performer signs and a registered nurse countersigns did not show who wrote an observation, so its origin was not visible where it is relied on. Refusing her observation is not the protective option (an observation of a fall, a wound or distress must not be lost).

**Affected code and data:** `public.visit_observations` (new column, trigger, column grants), `public.field_notes` (re-created), `private.handover_entries` (patched), `private.visit_report_snapshot` (replaced); app: `/field` visit card, HAND1 section, report facts. No data migration; observations recorded before 0095 carry no marker value.

**Steps (IMPLEMENTED in PR #673, CI decides):**
1. OBS1-1: the qualification fact recorded with every observation at write time (ADM2-16 rule), fixed afterwards; never refused.
2. OBS1-2: handover and HAND1 name the author and carry the marker.
3. OBS1-3: new snapshots name the author (identity, display name at the time, marker); signed snapshots unchanged.
4. OBS1-4: the screens show name and marker (`info` tone, no red); the countersigning registered nurse sees the facts.
5. OBS1-5: the marker is not selectable through the table API; no read widened; no per-person list.

**Tests:** pgTAP `095_obs1_observation_authorship.test.sql` (47), pgTAP 071 (RLS3-4 list), vitest `obs1-authorship`, Playwright `obs1.spec.ts`. ADM2-16 (094), VIS1 (089, 090) and CGR-12 (038) suites unmodified.

**Needs a decision (not coded):** whether observations by a member without a recorded qualification are allowed, need a countersignature or a review, or need no marker (**Clinical Owner**, D-15, D-10; after G-1). A legal determination of ZH GesG § 13 (**legal adviser**, question 9; canton D-11). The on-screen wording (`uxa`).
