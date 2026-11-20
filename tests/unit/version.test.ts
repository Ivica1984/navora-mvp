import { describe, expect, it } from "vitest";
import { isPublicPath } from "@/lib/auth/paths";
import { appVersion, highestMigration, versionLine } from "@/lib/version";

describe("Q1 (a) version (ADR-220)", () => {
  it("takes the Render commit and the build's migration level, and nothing that is not one", () => {
    expect(appVersion({ RENDER_GIT_COMMIT: "5FCF223642AE619A6FBEE7AFBC7781A3A72B663F", NAVORA_MIGRATION: "20261021000152" })).toEqual({
      commit: "5fcf223642ae619a6fbee7afbc7781a3a72b663f",
      migration: "20261021000152",
    });
    expect(appVersion({ RENDER_GIT_COMMIT: "main; rm -rf", NAVORA_MIGRATION: "x" })).toEqual({ commit: null, migration: null });
    expect(appVersion({})).toEqual({ commit: null, migration: null });
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

describe("Q1 (a) build-time migration level reaches the running app (ADR-220 fix)", () => {
  // Staging 2026-11-20 (staging-version run 44682756909): /api/version gave the commit but no migration, because
  // Next replaces `process.env.NAVORA_MIGRATION` only where it is written literally; passing `process.env` as an object
  // reads the runtime environment, where the build value does not exist. The readers must use `buildVersionEnv()`.
  it("route and footer read the version through the literal build-time accessor", async () => {
    const { readFileSync } = await import("node:fs");
    const src = readFileSync("src/lib/version.ts", "utf8");
    expect(src).toMatch(/NAVORA_MIGRATION:\s*process\.env\.NAVORA_MIGRATION/);
    for (const f of ["src/app/api/version/route.ts", "src/app/layout.tsx"]) {
      const s = readFileSync(f, "utf8");
      expect(s, f).not.toContain("appVersion(process.env)");
      expect(s, f).toContain("appVersion(buildVersionEnv())");
    }
  });
});
