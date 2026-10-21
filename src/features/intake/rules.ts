// Intake rules (J1) — pure TypeScript (ADR-002).

/** Roles allowed to record and convert referrals (placeholders, Q4). The database enforces the same. */
export const INTAKE_ROLES: ReadonlyArray<string> = ["admin", "operations"];

export type Membership = { organization_id: string; role: string };

/** The organisation the caller does intake for: the first membership with an intake role, else null. */
export function intakeOrganization(memberships: ReadonlyArray<Membership>): string | null {
  return memberships.find((m) => INTAKE_ROLES.includes(m.role))?.organization_id ?? null;
}

/** "Grundpflege, Wundversorgung ,," → ["Grundpflege", "Wundversorgung"] (max 20, unique). */
export function parseServices(input: string): string[] {
  const seen = new Set<string>();
  for (const part of input.split(/[,\n;]/)) {
    const s = part.trim();
    if (s && s.length <= 80) seen.add(s);
  }
  return [...seen].slice(0, 20);
}

export const URGENCIES = ["niedrig", "mittel", "hoch"] as const;
export type Urgency = (typeof URGENCIES)[number];

export const PARTNER_TYPES = ["Spital", "Pflegeheim", "Hausarzt", "Privat / Angehörige", "Andere"] as const;
