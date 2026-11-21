// The qualification texts (J3), in a module of their own so that `rules.ts` and `member-label.ts` both read them
// without importing each other (PLAN3-17 (2), ADR-159). Pure TypeScript (ADR-002).

export const QUALIFICATION_LABEL: Record<string, string> = {
  registered_nurse: "Pflegefachperson",
  care_assistant: "Pflegeassistenz",
};
