import { describe, expect, it } from "vitest";
import { SMOKE_EMAILS, smokeAccounts, smokeDayOffsets, stagingTarget } from "../staging-smoke/target";

// ADR-205: where the staging smoke may run, with which accounts, on which days. Guards, not a skip: every refusal throws.
const PW = { STAGING_SMOKE_PW_KUNDEBS: "a", STAGING_SMOKE_PW_PFLEGEBS: "b", STAGING_SMOKE_PW_PFLEGE: "c" };

describe("stagingTarget", () => {
  it("defaults to the staging host", () => {
    expect(stagingTarget({})).toBe("https://navora-staging.onrender.com");
    expect(stagingTarget({ STAGING_SMOKE_BASE_URL: "  " })).toBe("https://navora-staging.onrender.com");
    expect(stagingTarget({ STAGING_SMOKE_BASE_URL: "https://navora-staging.onrender.com/login" })).toBe(
      "https://navora-staging.onrender.com",
    );
  });
  it.each([
    ["http://navora-staging.onrender.com", /only https/],
    ["https://navora.onrender.com", /not a staging host/],
    ["https://navora-staging.onrender.com.evil.example", /not a staging host/],
    ["http://127.0.0.1:3000", /only https/],
    ["https://jwmfxrmougneeceldhsa.supabase.co", /live project/],
    ["https://u:p@navora-staging.onrender.com", /no credentials/],
    ["not a url", /not a URL/],
  ])("refuses %s", (url, why) => {
    expect(() => stagingTarget({ STAGING_SMOKE_BASE_URL: url })).toThrow(why);
  });
});

describe("smokeAccounts", () => {
  it("pairs the seed e-mails with the three secrets", () => {
    const a = smokeAccounts({ ...PW, STAGING_SMOKE_PW_PFLEGE: " c " });
    expect(a.kunde).toEqual({ email: SMOKE_EMAILS.kunde, password: "a" });
    expect(a.pflegeBs).toEqual({ email: "pflegebs.test@navora.test", password: "b" });
    expect(a.pflegeNord).toEqual({ email: "pflege.test@navora.test", password: "c" });
  });
  it("fails, naming only the missing variables, never a value", () => {
    let message = "";
    try {
      smokeAccounts({ STAGING_SMOKE_PW_KUNDEBS: "secret-value", STAGING_SMOKE_PW_PFLEGE: "" });
    } catch (e) {
      message = (e as Error).message;
    }
    expect(message).toBe("staging-smoke: missing secrets STAGING_SMOKE_PW_PFLEGEBS, STAGING_SMOKE_PW_PFLEGE");
    expect(message).not.toContain("secret-value");
  });
});

describe("smokeDayOffsets", () => {
  it("keeps clear of the CI e2e days (30–37) and the day and night ranges never meet", () => {
    for (let n = 0; n < 200; n++) {
      const { day, night } = smokeDayOffsets(n);
      expect(day).toBeGreaterThanOrEqual(40);
      expect(day).toBeLessThanOrEqual(69);
      expect(night).toBeGreaterThanOrEqual(75);
      expect(night).toBeLessThanOrEqual(104);
    }
  });
  it("gives 30 consecutive runs 30 different days", () => {
    const days = new Set(Array.from({ length: 30 }, (_, i) => smokeDayOffsets(1000 + i).day));
    expect(days.size).toBe(30);
  });
  it("treats a missing or odd run number as run 0", () => {
    expect(smokeDayOffsets(Number.NaN)).toEqual({ day: 40, night: 75 });
    expect(smokeDayOffsets(-3)).toEqual({ day: 40, night: 75 });
  });
});
