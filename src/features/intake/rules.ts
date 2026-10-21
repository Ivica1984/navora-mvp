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

// J1 (PO brief): funding facts at intake. Value sets mirror the database checks (migration 0013).
export const CANTONS = [
  "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR", "JU", "LU", "NE",
  "NW", "OW", "SG", "SH", "SO", "SZ", "TG", "TI", "UR", "VD", "VS", "ZG", "ZH",
] as const;

export const INSURANCE_TYPES = ["KVG", "IV", "UV", "MV", "private", "unknown"] as const;

export const MEDICAL_ORDER_STATUSES = ["present", "requested", "not-required-A/C-only"] as const;

export const MEDICAL_ORDER_LABEL: Record<(typeof MEDICAL_ORDER_STATUSES)[number], string> = {
  present: "liegt vor",
  requested: "angefragt",
  "not-required-A/C-only": "nicht nötig (nur Kategorie A/C)",
};

export const TASK_LABEL: Record<string, string> = {
  gp_missing: "Hausärztin/Hausarzt erfassen",
  other_providers_unknown: "Andere Leistungserbringer klären",
  language_unknown: "Sprache / Verständigung klären",
  access_unknown: "Zugang zur Wohnung klären",
  inform_gp: "Hausärztin/Hausarzt informieren (A/C ohne Verordnung)",
};

export type IntakeFacts = {
  residence_municipality?: string;
  residence_canton?: string;
  insurer_name?: string;
  insurance_type?: string;
  medical_order_status?: string;
  medical_order_valid_until?: string;
  gp_named?: boolean;
  other_providers_active?: boolean;
  requested_start?: string;
  language_notes?: string;
  access_notes?: string;
};

const yesNo = (v: string): boolean | undefined => (v === "yes" ? true : v === "no" ? false : undefined);

/**
 * Builds the facts object from a form: empty inputs are left out, so a later update
 * never blanks a fact that was recorded before. Booleans come from yes/no/"" selects.
 */
export function factsFromForm(get: (name: string) => string): IntakeFacts {
  const facts: IntakeFacts = {};
  const text = ["residence_municipality", "residence_canton", "insurer_name", "insurance_type", "medical_order_status",
    "medical_order_valid_until", "requested_start", "language_notes", "access_notes"] as const;
  for (const key of text) {
    const v = get(key).trim();
    if (v) facts[key] = v;
  }
  const gp = yesNo(get("gp_named"));
  if (gp !== undefined) facts.gp_named = gp;
  const other = yesNo(get("other_providers_active"));
  if (other !== undefined) facts.other_providers_active = other;
  return facts;
}

export type ReadinessItem = { item: string; reason: string };

export function parseMissing(raw: unknown): ReadinessItem[] {
  return Array.isArray(raw)
    ? raw.filter((m): m is ReadinessItem => typeof m === "object" && m !== null && typeof (m as ReadinessItem).reason === "string")
    : [];
}
