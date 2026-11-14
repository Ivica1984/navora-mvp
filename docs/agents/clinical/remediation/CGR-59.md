# Remediation plan: CGR-59 (the billing view did not say whether a correction is in the billed version)

**Written by:** Engineering (`eng`) · 2026-10-25 16:20 (Europe/Zurich) · **Item:** FUP1-3 (= RLS3-4c, Q15) · **Brief:** `briefs/FUP1.md`
**Finding:** Clinical Governance Report section 2026-10-25 13:26 CET (PR #374), CGR-59, **advisory (S2; before invoicing, gate C)**. ADR-084, migration 0071, pgTAP 071.

## Risk

`visit_correction_history` (0070, RLS3-4b) level (b) returned old and new value, the time of each correction and the version the billing fact rests on, but not whether the correction is contained in that version. A correction made after the countersignature is not in the billed snapshot (0043), and the billing reader could not tell it from one that is.

## Affected code and data

`public.visit_correction_history`. No data change.

## Steps

1. IMPLEMENTED (0071): per correction `in_billed_version` = correction time ≤ the countersignature time of the version the current (not superseded) billing fact rests on, or its signature time when no countersignature is required; false after it; null without a billing fact. Both levels; level (b) still returns no reason and no corrector; no grouping or counting per person.

## Tests

pgTAP 071 (+7): two corrections before the countersignature → true; a third after it → false (levels (a) and (b)); level (b) still without reason and corrector; a visit without a billing fact → null; no countersignature required → the signature time decides (before → true, after → false). The RLS3-4 / D-23 (b) catalogue checks re-run on the new body. **CI is the runner.**

## Needs a decision

None for this item. What invoicing does with `in_billed_version = false` is D-18 and the invoice brief, not this item.
