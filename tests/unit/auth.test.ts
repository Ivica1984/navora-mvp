import { describe, expect, it } from "vitest";
import { signInSchema } from "@/features/auth/schema";
import { isPublicPath } from "@/lib/auth/paths";
import { assignTeamCoachSchema, setTeamPrioritySchema } from "@/features/teams/command-schemas";
import { visitIdSchema } from "@/features/visits/command-schemas";

const TEAM_ID = "00000000-0000-4000-a000-000000000101";

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
    expect(setTeamPrioritySchema.safeParse({ teamId: TEAM_ID, priority: true }).success).toBe(true);
    expect(assignTeamCoachSchema.parse({ teamId: TEAM_ID, coachName: "  Coach Test 1 " }).coachName).toBe("Coach Test 1");
  });

  it.each([
    [setTeamPrioritySchema, { teamId: "not-a-uuid", priority: true }],
    [setTeamPrioritySchema, { teamId: TEAM_ID, priority: "true" }],
    [assignTeamCoachSchema, { teamId: TEAM_ID, coachName: "   " }],
    [assignTeamCoachSchema, { teamId: TEAM_ID, coachName: "x".repeat(121) }],
    [assignTeamCoachSchema, { teamId: "'; drop table teams; --", coachName: "x" }],
  ])("reject invalid input %#", (schema, input) => {
    expect(schema.safeParse(input).success).toBe(false);
  });
});

describe("visit command schema", () => {
  it("accepts a uuid and rejects anything else", () => {
    expect(visitIdSchema.safeParse({ visitId: "00000000-0000-4000-a000-000000000501" }).success).toBe(true);
    expect(visitIdSchema.safeParse({ visitId: "501" }).success).toBe(false);
    expect(visitIdSchema.safeParse({}).success).toBe(false);
  });
});
