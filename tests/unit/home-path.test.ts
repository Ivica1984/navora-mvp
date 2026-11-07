import { describe, expect, it } from "vitest";
import { FIELD_PATH, HOME_PATH, homePathForRoles } from "@/lib/auth/paths";

describe("landing page by role (F1)", () => {
  it("nurses land in the field tool", () => {
    expect(homePathForRoles(["nurse"])).toBe(FIELD_PATH);
    expect(homePathForRoles(["nurse", "nurse"])).toBe(FIELD_PATH);
  });

  it("everybody else lands in Operations", () => {
    expect(homePathForRoles(["coach"])).toBe(HOME_PATH);
    expect(homePathForRoles(["nurse", "coach"])).toBe(HOME_PATH);
    expect(homePathForRoles(["admin"])).toBe(HOME_PATH);
    expect(homePathForRoles([])).toBe(HOME_PATH);
  });
});
