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

/**
 * IPA1-7 (migration 0086, ADR-100): who set the urgency. Only the two recorded values can be chosen; rows from
 * before IPA1-7 read "unknown". NAVORA sets no criteria for a level or a source (D-34 question 7 stays with clinical).
 */
/**
 * UX1-23 (`uxa` UXR-5 (a), `cra` C-2 (a) "confirm"; CR-125, CR-129): the referral's urgency is a criteria-free label,
 * not a SIG1 safety signal. "hoch" is shown in amber (`attention`) with the word kept, never in the P1 signal colour.
 * One map for every badge that shows it (`/intake`, `/team`); tests/unit/ux1-colour.test.ts.
 */
export const URGENCY_BADGE_CLASS: Record<Urgency, string> = {
  hoch: "bg-amber-100 text-amber-900 ring-1 ring-amber-800",
  mittel: "bg-amber-50 text-amber-900",
  niedrig: "bg-stone-200 text-stone-800",
};

/**
 * CGR-215 (d) (BK amendment 2026-11-13 21:39): a row without urgency is shown, never dropped. The gap is named in
 * words; NAVORA sets no level for it (IPA1-7, D-34 question 7).
 */
export const URGENCY_MISSING_LABEL = "Dringlichkeit fehlt";

/**
 * UXR-202 (BK amendment 2026-11-14 01:39 (3), `cra` 01:35): a missing urgency looks different from every stored level:
 * outlined, white fill, dark text, the words «Dringlichkeit fehlt». Never red (UX1-23: red only for safety signals), and
 * no re-ordering (the list stays by arrival). tests/unit/bk-a-uxr202-urgency-missing-badge.test.ts.
 */
export const URGENCY_MISSING_BADGE_CLASS = "bg-white text-stone-900 ring-1 ring-stone-700";

/**
 * The badge class for a stored urgency. No value: the UXR-202 outline. An unknown stored value stays neutral grey
 * (UX1-23; the word shows what is stored).
 */
export function urgencyBadgeClass(urgency: string | null | undefined): string {
  if (!urgency) return URGENCY_MISSING_BADGE_CLASS;
  return (URGENCY_BADGE_CLASS as Record<string, string>)[urgency] || "bg-stone-200 text-stone-800";
}

/** The badge text: the stored level, or «Dringlichkeit fehlt» when none is stored. */
export function urgencyBadgeText(urgency: string | null | undefined): string {
  return urgency ? urgency : URGENCY_MISSING_LABEL;
}

/**
 * CGR-215 (d): keeps every row in its order and lists the ids without urgency, so the caller can log an error event.
 * It never filters.
 */
export function intakeRowsWithUrgencyCheck<T extends { id: string; urgency: string | null }>(
  rows: ReadonlyArray<T>,
): { rows: T[]; missingUrgency: string[] } {
  return { rows: [...rows], missingUrgency: rows.filter((r) => !r.urgency).map((r) => r.id) };
}

export const URGENCY_SOURCES = ["referrer_stated", "intake_assessed"] as const;
export type UrgencySource = (typeof URGENCY_SOURCES)[number];

const URGENCY_SOURCE_LABEL: Record<string, string> = {
  referrer_stated: "vom Zuweiser angegeben",
  intake_assessed: "bei der Aufnahme eingeschätzt",
  unknown: "Quelle nicht erfasst",
};

/** "vom Zuweiser angegeben" | "bei der Aufnahme eingeschätzt" | "Quelle nicht erfasst" (also for any other value). */
export function urgencySourceLabel(source: string | null | undefined): string {
  return (source && URGENCY_SOURCE_LABEL[source]) || URGENCY_SOURCE_LABEL.unknown;
}

/**
 * IPA1-7: "Dringlichkeit: hoch (vom Zuweiser angegeben)", the level always with its source; «Dringlichkeit fehlt» when
 * no level is stored (CGR-215 (d)).
 */
export function urgencyWithSource(urgency: string | null | undefined, source: string | null | undefined): string {
  if (!urgency) return URGENCY_MISSING_LABEL;
  return `Dringlichkeit: ${urgency} (${urgencySourceLabel(source)})`;
}

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
  /** J2 (offer fields): optional; shown to offered teams before acceptance. */
  expected_hours_per_week?: number;
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
  const hours = Number.parseFloat(get("expected_hours_per_week").replace(",", "."));
  if (Number.isFinite(hours) && hours > 0) facts.expected_hours_per_week = Math.round(hours * 10) / 10;
  return facts;
}

export type ReadinessItem = { item: string; reason: string };

export function parseMissing(raw: unknown): ReadinessItem[] {
  return Array.isArray(raw)
    ? raw.filter((m): m is ReadinessItem => typeof m === "object" && m !== null && typeof (m as ReadinessItem).reason === "string")
    : [];
}
