import { describe, expect, it } from "vitest";
import { isPublicPath } from "@/lib/auth/paths";
import { appVersion, highestMigration, runningVersion, versionLine } from "@/lib/version";

describe("Q1 (a) version (ADR-220)", () => {
  it("takes the Render commit and the build's migration level, and nothing that is not one", () => {
    expect(appVersion({ RENDER_GIT_COMMIT: "5FCF223642AE619A6FBEE7AFBC7781A3A72B663F", NAVORA_MIGRATION: "20261021000152" })).toEqual({
      commit: "5fcf223642ae619a6fbee7afbc7781a3a72b663f",
      migration: "20261021000152",
    });
    expect(appVersion({ RENDER_GIT_COMMIT: "main; rm -rf", NAVORA_MIGRATION: "x" })).toEqual({ commit: null, migration: null });
    expect(appVersion({})).toEqual({ commit: null, migration: null });
  });

  it("reads the running build's commit and migration by their literal names", () => {
    const before = { c: process.env.RENDER_GIT_COMMIT, m: process.env.NAVORA_MIGRATION };
    process.env.RENDER_GIT_COMMIT = "abcdef1";
    process.env.NAVORA_MIGRATION = "20261021000153";
    try {
      expect(runningVersion()).toEqual({ commit: "abcdef1", migration: "20261021000153" });
    } finally {
      if (before.c === undefined) delete process.env.RENDER_GIT_COMMIT; else process.env.RENDER_GIT_COMMIT = before.c;
      if (before.m === undefined) delete process.env.NAVORA_MIGRATION; else process.env.NAVORA_MIGRATION = before.m;
    }
  });

  it("finds the highest migration from the file names only", () => {
    expect(highestMigration(["20261021000150_a.sql", "20261021000152_b.sql", "20261021000151_c.sql", "README.md"])).toBe("20261021000152");
    expect(highestMigration(["notes.txt"])).toBeNull();
  });

  it("writes one short footer line", () => {
    expect(versionLine({ commit: "5fcf223642ae", migration: "20261021000152" })).toBe("Version 5fcf223 · Datenbank 0152");
    expect(versionLine({ commit: null, migration: null })).toBe("Version lokal · Datenbank unbekannt");
  });

  it("/api/version is reachable without a session; nothing else new is", () => {
    expect(isPublicPath("/api/version")).toBe(true);
    expect(isPublicPath("/api/versions")).toBe(false);
  });
});

describe("AI1 /api/version report_draft (ADR-227 point 7)", () => {
  const model = {
    AI_REPORT_DRAFT_MODE: "model",
    AI_MODEL_PROVIDER: "anthropic",
    AI_MODEL_API_KEY: "secret-test-key",
    AI_MODEL_NAME: "claude-x",
    NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  };

  it("names the configured draft by the environment guards only", async () => {
    const { configuredReportDraftMode } = await import("@/lib/ai/report-draft/config");
    expect(configuredReportDraftMode({})).toBe("rule");
    expect(configuredReportDraftMode({ AI_REPORT_DRAFT_MODE: "off" })).toBe("off");
    expect(configuredReportDraftMode(model)).toBe("model");
    expect(configuredReportDraftMode({ ...model, AI_KILL_SWITCH: "on" })).toBe("rule");
    expect(configuredReportDraftMode({ ...model, AI_MODEL_API_KEY: "" })).toBe("rule");
    expect(configuredReportDraftMode({ ...model, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321" })).toBe("rule");
  });

  it("the endpoint answers one word and never the key or the model name", async () => {
    const before = { ...process.env };
    Object.assign(process.env, model);
    try {
      const { GET } = await import("@/app/api/version/route");
      const text = await GET().text();
      expect(JSON.parse(text).report_draft).toBe("model");
      expect(text).not.toMatch(/secret-test-key|claude-x|anthropic/);
    } finally {
      for (const k of Object.keys(model)) {
        if (before[k] === undefined) delete process.env[k];
        else process.env[k] = before[k];
      }
    }
  });
});
