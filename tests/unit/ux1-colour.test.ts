import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";
import { URGENCIES, URGENCY_BADGE_CLASS, urgencyBadgeClass } from "@/features/intake/rules";

// UX1-23 (`uxa` UXR-5 (a), UXR-16; `cra` C-2 (a) "confirm"; ADR-109): red only for safety signals.
// Source scan, not a render: the classes are static strings in these files.

const ROOT = join(__dirname, "..", "..");
const read = (path: string) => readFileSync(join(ROOT, path), "utf8");

function tsxFiles(dir: string): string[] {
  return readdirSync(join(ROOT, dir)).flatMap((name) => {
    const path = join(dir, name);
    return statSync(join(ROOT, path)).isDirectory() ? tsxFiles(path) : path.endsWith(".tsx") ? [path] : [];
  });
}

describe("UX1-23: the intake urgency is a word in amber, never the P1 colour", () => {
  it("every level has a badge class without a rose- class; 'hoch' is amber", () => {
    for (const level of URGENCIES) expect(URGENCY_BADGE_CLASS[level]).not.toMatch(/\brose-/);
    expect(URGENCY_BADGE_CLASS.hoch).toMatch(/\bamber-/);
  });

  it("an unknown stored value is neutral", () => {
    expect(urgencyBadgeClass("unbekannt")).toBe("bg-stone-200 text-stone-800");
  });

  it("/intake and /team use the shared map, not a local one", () => {
    for (const path of ["src/app/(protected)/intake/intake-client.tsx", "src/app/(protected)/team/team-client.tsx"]) {
      const source = read(path);
      expect(source, path).toContain("urgencyBadgeClass(");
      expect(source, path).not.toMatch(/URGENCY_CLASS/);
    }
  });
});

describe("UX1-23 (widened, UXR-16): no rose- class in field-client.tsx", () => {
  it("the /field visit card, its status badges and its error lines carry no P1 colour", () => {
    // The signal components (SignalBanner) live in src/components/signals and are not part of this file.
    expect(read("src/app/(protected)/field/field-client.tsx")).not.toMatch(/\brose-/);
  });
});

describe("UX1-23: the P1 signal card's border colour appears only in signal components", () => {
  it("border-rose-700 (design system `signal-p1`) is used only under src/components/signals", () => {
    const users = [...tsxFiles("src/app"), ...tsxFiles("src/components")]
      .filter((path) => /\bborder-rose-700\b/.test(read(path)))
      .map((path) => relative(ROOT, join(ROOT, path)));
    expect(users.length).toBeGreaterThan(0);
    for (const path of users) expect(path, path).toMatch(/^src\/components\/signals\//);
  });
});
