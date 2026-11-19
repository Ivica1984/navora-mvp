import { describe, expect, it } from "vitest";
import { DEMO_PERSONAS, demoLoginEnabled, demoPersona } from "@/features/auth/demo-login";

// DEMO1 (ADR-212, founder live session 2026-11-19): one-click sign-in as a synthetic seed person, staging only.
const STAGING = "https://qpmdryxkktbqqkqpsnkj.supabase.co";
const LIVE = "https://jwmfxrmougneeceldhsa.supabase.co";

describe("demoLoginEnabled", () => {
  it("is on for the staging project", () => {
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: STAGING })).toBe(true);
  });
  it("is never on for the live project, whatever the flag says", () => {
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: LIVE })).toBe(false);
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: LIVE, NAVORA_DEMO_LOGIN: "1" })).toBe(false);
  });
  it("can be switched off on staging", () => {
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: STAGING, NAVORA_DEMO_LOGIN: "off" })).toBe(false);
  });
  it("is on for a local stack only with the explicit flag", () => {
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321" })).toBe(false);
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321", NAVORA_DEMO_LOGIN: "1" })).toBe(true);
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: "http://localhost:54321", NAVORA_DEMO_LOGIN: "1" })).toBe(true);
  });
  it("is off for any other project or a missing URL (fail closed)", () => {
    expect(demoLoginEnabled({})).toBe(false);
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: "https://other.supabase.co", NAVORA_DEMO_LOGIN: "1" })).toBe(false);
    // a host that only contains the staging ref as a path or a sub-string of another host is not staging
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: "https://evil.example/qpmdryxkktbqqkqpsnkj.supabase.co" })).toBe(false);
    expect(demoLoginEnabled({ NEXT_PUBLIC_SUPABASE_URL: "not a url", NAVORA_DEMO_LOGIN: "1" })).toBe(false);
  });
});

describe("DEMO_PERSONAS", () => {
  it("are synthetic seed accounts only", () => {
    expect(DEMO_PERSONAS.length).toBeGreaterThanOrEqual(3);
    for (const p of DEMO_PERSONAS) expect(p.email).toMatch(/^[a-z]+\.test@navora\.test$/);
  });
  it("cover the nursing home, the team and the organisation view", () => {
    const views = new Set(DEMO_PERSONAS.map((p) => p.view));
    expect(views).toEqual(new Set(["heim", "team", "organisation"]));
  });
  it("have unique keys", () => {
    const keys = DEMO_PERSONAS.map((p) => p.key);
    expect(new Set(keys).size).toBe(keys.length);
  });
});

describe("demoPersona", () => {
  it("resolves a known key", () => {
    expect(demoPersona("heim")?.email).toBe("kundebs.test@navora.test");
  });
  it("never resolves an e-mail address or an unknown key (no user-controlled account)", () => {
    expect(demoPersona("kundebs.test@navora.test")).toBeNull();
    expect(demoPersona("admin")).toBeNull();
    expect(demoPersona(null)).toBeNull();
    expect(demoPersona("__proto__")).toBeNull();
  });
});
