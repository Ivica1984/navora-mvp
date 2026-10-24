import { afterEach, describe, expect, it, vi } from "vitest";
import { errorFields, formatLogLine, logEvent, sanitizeFields } from "@/lib/log";

const NOW = new Date("2026-10-21T12:00:00.000Z");

// A realistic PostgREST error: Postgres copies row values into message/details.
const pgError = {
  code: "23505",
  message: 'duplicate key value violates unique constraint "cases_pkey"',
  details: "Key (last_name)=(Muster) already exists. Diagnose: Diabetes Typ 2",
  hint: "Patientin Anna Muster, AHV 756.1234.5678.97",
  status: 409,
};

describe("structured logging (TD-17)", () => {
  afterEach(() => vi.restoreAllMocks());

  it("emits exactly one JSON line with ts, level and event", () => {
    const line = formatLogLine("error", "teams.load_failed", { code: "42501" }, NOW);
    expect(line).not.toContain("\n");
    expect(JSON.parse(line)).toEqual({
      ts: "2026-10-21T12:00:00.000Z",
      level: "error",
      event: "teams.load_failed",
      code: "42501",
    });
  });

  it("errorFields keeps code and status and drops message, details and hint", () => {
    expect(errorFields(pgError)).toEqual({ code: "23505", status: 409 });
  });

  it("no personal or health text survives even if the error object is passed as fields", () => {
    const line = formatLogLine("error", "x", pgError as unknown as Record<string, unknown>, NOW);
    for (const leak of ["Muster", "Diabetes", "Anna", "756.", "duplicate", "Key ("]) {
      expect(line).not.toContain(leak);
    }
  });

  it("drops keys outside the allowlist", () => {
    expect(
      sanitizeFields({ code: "PGRST116", email: "a@b.ch", userId: "u1", notes: "Wunde" })
    ).toEqual({ code: "PGRST116" });
  });

  it("redacts free-text values in code/op and in the event name", () => {
    expect(sanitizeFields({ code: "Anna Muster hat Fieber", op: "start_visit" })).toEqual({
      code: "[redacted]",
      op: "start_visit",
    });
    expect(JSON.parse(formatLogLine("info", "Patient Muster", {}, NOW)).event).toBe("[redacted]");
  });

  it("drops non-numeric status/count and empty codes", () => {
    expect(sanitizeFields({ status: "409", count: Number.NaN, code: "" })).toEqual({});
  });

  it("errorFields tolerates non-objects", () => {
    expect(errorFields(null)).toEqual({});
    expect(errorFields("boom")).toEqual({});
  });

  it("routes levels to the matching console method", () => {
    const err = vi.spyOn(console, "error").mockImplementation(() => {});
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const info = vi.spyOn(console, "info").mockImplementation(() => {});
    logEvent("error", "a");
    logEvent("warn", "b");
    logEvent("info", "c");
    expect(err).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(info).toHaveBeenCalledTimes(1);
  });
});
