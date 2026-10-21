import { describe, expect, it } from "vitest";
import { toCommandResult } from "@/lib/commands/result";

const M = { rejected: "abgelehnt", failed: "fehlgeschlagen" };

describe("toCommandResult", () => {
  it("treats ok and a replayed key (duplicate) as success", () => {
    expect(toCommandResult("ok", null, M)).toEqual({ ok: true });
    expect(toCommandResult("duplicate", null, M)).toEqual({ ok: true });
  });

  it("maps rejected to the caller's message", () => {
    expect(toCommandResult("rejected", null, M)).toEqual({ ok: false, error: "abgelehnt" });
  });

  it("maps database error codes", () => {
    expect(toCommandResult(null, { code: "23514" }, M)).toEqual({
      ok: false,
      error: "Dieser Statuswechsel ist nicht erlaubt.",
    });
    expect(toCommandResult(null, { code: "22023" }, M)).toEqual({ ok: false, error: "Ungültige Eingabe." });
    expect(toCommandResult(null, { code: "42501" }, M)).toEqual({ ok: false, error: "fehlgeschlagen" });
  });

  it("never reports success for an unknown response", () => {
    expect(toCommandResult("something-else", null, M)).toEqual({ ok: false, error: "fehlgeschlagen" });
    expect(toCommandResult(undefined, null, M)).toEqual({ ok: false, error: "fehlgeschlagen" });
  });
});
