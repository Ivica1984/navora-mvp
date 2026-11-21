// UX2-23 (uxa UXR-43; wording uxa 16:10, taken in by po 16:24; ADR-124): a switch with organisation-wide or privacy
// consequences asks once. Pure module: the sentences are pinned by vitest (no internal code in them).

/** Team admission (ADM2-1) switched on: who admits colleagues afterwards (ADM2-6: the administrator records the contract). */
export const ADMISSION_ON_CONSEQUENCE =
  "Danach nehmen die Teams neue Kolleginnen selbst auf. Die Administration erfasst nur noch den Vertrag.";

/**
 * Team admission switched off. The brief's optional second sentence ("Offene Vorschläge und Aufnahmen, die auf
 * «Vertrag erfasst» warten, ruhen, bis wieder eingeschaltet wird.") is NOT shown: as built, while the switch is off an
 * open proposal still lapses 14 Zurich days after it was made, and an admitted one without a recorded contract 14 days
 * after its admission (ADM2-8), because the administrators' and the team's readers run the lapse sweep whatever the
 * switch (0091 `admin_team_admissions` / `team_admissions` → `private.adm2_sweep`, lapse rule as patched in 0092).
 * "ruhen" would be false for both (ADR-124, deviation 1).
 */
export const ADMISSION_OFF_CONSEQUENCE = "Danach nimmt nur die Administration neue Mitglieder auf.";

/** "Vertragsende entfernen" (ADM2-11): her access no longer ends by itself (ADM2-13). */
export const CONTRACT_END_REMOVE_CONSEQUENCE = "Der Zugang endet dann nicht mehr automatisch.";

/** The cancelling button of every confirming step (action-outline). */
export const CONFIRM_CANCEL_LABEL = "Abbrechen";
