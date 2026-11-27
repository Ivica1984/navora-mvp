import { describe, expect, it } from "vitest";
import { INTERRUPTED_TEXT, settleAction } from "@/features/team/settle-action";

// HD-3s-F2-F1 (review (e) on #1825): the plan and move forms must not hang when the server action call throws.
describe("settleAction (plan and move forms)", () => {
  it("turns a thrown call into a neutral sentence that never claims «nicht gespeichert»", async () => {
    const result = await settleAction(() => Promise.reject(new TypeError("Failed to fetch")));
    expect(result).toEqual({ ok: false, error: INTERRUPTED_TEXT, interrupted: true });
    expect(INTERRUPTED_TEXT).not.toMatch(/nicht gespeichert/i);
    expect(INTERRUPTED_TEXT).toMatch(/neu laden/);
  });

  it("passes the server's own rejection through unchanged", async () => {
    const rejected = { ok: false as const, error: "Nicht gespeichert: …" };
    await expect(settleAction(() => Promise.resolve(rejected))).resolves.toBe(rejected);
  });

  it("passes a success through unchanged", async () => {
    const ok = { ok: true as const, flags: [] as string[] };
    await expect(settleAction(() => Promise.resolve(ok))).resolves.toBe(ok);
  });

  it("calls the action exactly once (one idempotency key per attempt)", async () => {
    let calls = 0;
    await settleAction(async () => {
      calls += 1;
      throw new Error("network");
    });
    expect(calls).toBe(1);
  });
});
