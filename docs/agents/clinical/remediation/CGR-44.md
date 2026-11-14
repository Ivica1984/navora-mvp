# Remediation plan: CGR-44 (a case never asks again after its first "doctor informed" record)

**Written by:** Engineering (`eng`) · 2026-10-24 20:40 (Europe/Zurich) · **Item:** ORD0 condition ORD0-C2 (*Next up* 1) · **Brief:** `briefs/ORD0.md` (PO 15:10, widened 16:20)
**Finding:** Clinical Governance Report section 2026-10-24 14:27 (PR #294), CGR-44, **advisory (S2)**, decided by the PO as ORD0-C2 (Q12 (c), widened to (b)+(c) after `lca` 16:05). Related: D-22 question 6, CR-069.

## Risk

After the first record, planning and PLAN2 never open `inform_gp` again for the case (ADR-075). A client whose A/C care grows months later, or who is reassessed, can go on without the doctor being told (continuity of care; tarifsuisse contract Art. 9 Abs. 1 as read by `lca`).

## Affected code and data

- Triggers on `public.care_plan_items` (active, category) and `public.care_visits` (status), one function `private.open_inform_gp_after_event`; `public.case_tasks` (`inform_gp`, one open per case).
- No new data. The live project is not touched.

## Steps

1. IMPLEMENTED (0063, ORD0-C2 (a)): an A or C item that becomes active in a case without an order `present`, with no record dated on or after that day → one task.
2. IMPLEMENTED (0063, (a′)): a needs-assessment visit that reaches `completed` under the same conditions → one task.
3. IMPLEMENTED (unchanged, (b)-(c)): the record closes it; B with an order `present`, a closed case, an open task or a covering record → nothing; refreshes never reopen.
4. NOT software: the deadline, the content of the information, and whether a reassessment result must be sent (D-22 question 6, legal adviser and Clinical Owner).

## Tests

pgTAP 065: record, then a new active C item → one new task; refreshes → still one; record → done; new A item covered by a record of that day → no task; B item or C item with the order present → no task; record, then a completed needs-assessment visit → one new task; with the order present → none; assessment and C item on the same day → one task; a re-activated item on a covered day → none; closed case → none. pgTAP 063 (ORD0-C1): HAND1 `gp_informed` entry; order no longer `present` ends the exception. CI is the runner.

## Needs a decision

- **legal / clinical (D-22 question 6):** deadline and content; nothing here sets them.
