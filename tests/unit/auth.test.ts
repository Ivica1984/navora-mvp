import { describe, expect, it } from "vitest";
import { signInSchema } from "@/features/auth/schema";
import { isPublicPath } from "@/lib/auth/paths";
import { assignTeamCoachSchema, setTeamPrioritySchema } from "@/features/teams/command-schemas";
import { visitCommandSchema } from "@/features/visits/command-schemas";

const TEAM_ID = "00000000-0000-4000-a000-000000000101";
const KEY = "aaaaaaaa-0000-4000-8000-000000000001";

describe("isPublicPath", () => {
  it.each([
    ["/login", true],
    ["/login/", true],
    ["/", false],
    ["/operations", false],
    ["/teams", false],
    ["/visits", false],
    ["/matching", false],
    ["/login-bypass", false],
    ["/loginx", false],
    ["/LOGIN", false],
    // SIG2: the service worker and the sender's bearer-protected entry point; nothing else under /api
    ["/sw.js", true],
    ["/api/push/dispatch", true],
    ["/api/push", false],
    ["/api/push/dispatch/x", false],
  ])("%s → %s", (path, expected) => {
    expect(isPublicPath(path)).toBe(expected);
  });
});

describe("signInSchema", () => {
  it("accepts and normalises a valid e-mail", () => {
    const parsed = signInSchema.parse({ email: "  Coach.Test@Navora.TEST ", password: "x" });
    expect(parsed.email).toBe("coach.test@navora.test");
  });

  it.each([
    [{ email: "not-an-email", password: "x" }],
    [{ email: "a@b.ch", password: "" }],
    [{ email: "a@b.ch" }],
    [{ email: null, password: null }],
    [{ email: "a@b.ch", password: "x".repeat(201) }],
  ])("rejects %j", (input) => {
    expect(signInSchema.safeParse(input).success).toBe(false);
  });
});

describe("team command schemas", () => {
  it("accept valid input", () => {
    expect(setTeamPrioritySchema.safeParse({ teamId: TEAM_ID, priority: true, idempotencyKey: KEY }).success).toBe(true);
    expect(
      assignTeamCoachSchema.parse({ teamId: TEAM_ID, coachName: "  Coach Test 1 ", idempotencyKey: KEY }).coachName
    ).toBe("Coach Test 1");
  });

  it.each([
    [setTeamPrioritySchema, { teamId: "not-a-uuid", priority: true, idempotencyKey: KEY }],
    [setTeamPrioritySchema, { teamId: TEAM_ID, priority: "true", idempotencyKey: KEY }],
    [setTeamPrioritySchema, { teamId: TEAM_ID, priority: true }],
    [assignTeamCoachSchema, { teamId: TEAM_ID, coachName: "   ", idempotencyKey: KEY }],
    [assignTeamCoachSchema, { teamId: TEAM_ID, coachName: "x".repeat(121), idempotencyKey: KEY }],
    [assignTeamCoachSchema, { teamId: "'; drop table teams; --", coachName: "x", idempotencyKey: KEY }],
    [assignTeamCoachSchema, { teamId: TEAM_ID, coachName: "x", idempotencyKey: "1" }],
  ])("reject invalid input %#", (schema, input) => {
    expect(schema.safeParse(input).success).toBe(false);
  });
});

describe("visit command schema", () => {
  const VISIT = "00000000-0000-4000-a000-000000000501";
  it("requires a visit uuid and an idempotency key", () => {
    expect(visitCommandSchema.safeParse({ visitId: VISIT, idempotencyKey: KEY }).success).toBe(true);
    expect(visitCommandSchema.safeParse({ visitId: VISIT }).success).toBe(false);
    expect(visitCommandSchema.safeParse({ visitId: "501", idempotencyKey: KEY }).success).toBe(false);
    expect(visitCommandSchema.safeParse({}).success).toBe(false);
  });
});
