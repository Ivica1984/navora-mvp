// DEMO1 (ADR-212, founder live session 2026-11-19): the founder signs in as a synthetic seed person with one click,
// to see NAVORA as a nursing home, a team member or the organisation sees it. Staging only, synthetic seed only.
// The seed password is public in this repository (owner decision for staging, ADR-190 amendment 2026-11-17); this
// module adds no new secret and no new account. Pure module, unit-tested (tests/unit/demo-login.test.ts).

/** Live Supabase project: the demo sign-in is never offered there (agent hard rule). */
const LIVE_PROJECT_REF = "jwmfxrmougneeceldhsa";
/** Staging project (navora-staging). */
const STAGING_PROJECT_REF = "qpmdryxkktbqqkqpsnkj";

/** Public password of every synthetic seed account (supabase/seed.sql). */
export const DEMO_SEED_PASSWORD = "navora-local-only";

export type DemoView = "heim" | "team" | "organisation";

export type DemoPersona = {
  key: string;
  view: DemoView;
  email: string;
  title: string;
  description: string;
};

// Only accounts that exist on navora-staging (read 2026-11-19 15:20: kolleginbs.test is not seeded there, ADR-190).
export const DEMO_PERSONAS: readonly DemoPersona[] = [
  {
    key: "heim",
    view: "heim",
    email: "kundebs.test@navora.test",
    title: "Als Heim",
    description: "Testheim Rhein bestellt einen Einsatz und sieht, ob er gedeckt ist.",
  },
  {
    key: "pflege",
    view: "team",
    email: "pflegebs.test@navora.test",
    title: "Als Team: Pflegefachfrau",
    description: "Testteam Basel: Angebote übernehmen, Einsatz und Bericht in «Mein Tag».",
  },
  {
    key: "einsatzleitung",
    view: "organisation",
    email: "opsbs.test@navora.test",
    title: "Als Organisation: Einsatzleitung",
    description: "Testorganisation S: Anfragen aufnehmen und Fälle eröffnen.",
  },
];

type Env = Record<string, string | undefined>;

function hostOf(url: string): string | null {
  try {
    return new URL(url).hostname;
  } catch {
    return null;
  }
}

/**
 * Offered only on staging (exact staging host) or on a local stack with NAVORA_DEMO_LOGIN=1.
 * Never on the live project. NAVORA_DEMO_LOGIN=off switches it off everywhere. Anything else: off (fail closed).
 */
export function demoLoginEnabled(env: Env): boolean {
  const url = env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const host = hostOf(url);
  if (!host) return false;
  if (host.includes(LIVE_PROJECT_REF)) return false;
  if (env.NAVORA_DEMO_LOGIN === "off") return false;
  if (host === `${STAGING_PROJECT_REF}.supabase.co`) return true;
  if ((host === "127.0.0.1" || host === "localhost") && env.NAVORA_DEMO_LOGIN === "1") return true;
  return false;
}

/** The persona for a key from the fixed list; never an e-mail address from the request. */
export function demoPersona(key: unknown): DemoPersona | null {
  if (typeof key !== "string") return null;
  return DEMO_PERSONAS.find((p) => p.key === key) ?? null;
}
