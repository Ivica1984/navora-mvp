import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  REFUSAL_TEXT,
  agentStatusText,
  expiredText,
  openStops,
  parseAgentStops,
  stopHistoryText,
  stopOpenText,
} from "@/features/ai/labels";

// AIG1-C4 (CGR-107) and AIG1-C5 (AUT-30) (ADR-139, migration 0105). Texts of the health list. The rules stay in the
// database: which proposal has expired, which stop still has open lines and whether an exception is listed.
const root = process.cwd();
const healthPage = readFileSync(join(root, "src/app/(protected)/operations/assistenten/page.tsx"), "utf8");

describe("AIG1-C4 (3): expired proposals are counted apart, next to the decided count", () => {
  it("names the count, also at 0", () => {
    expect(expiredText(1)).toBe("Abgelaufen ohne Entscheid: 1");
    expect(expiredText(0)).toBe("Abgelaufen ohne Entscheid: 0");
  });
  it("shows nothing before the first closed window", () => {
    expect(expiredText(null)).toBeNull();
    expect(expiredText(undefined)).toBeNull();
  });
  it("the refusal of an expired proposal reads as the existing not_open text", () => {
    expect(REFUSAL_TEXT.not_open).toBe("Nicht übernommen: Der Einsatz ist nicht mehr offen.");
  });
});

describe("AIG1-C5 (c): the agent's state is a status, never a to-do", () => {
  it("words each state", () => {
    expect(agentStatusText("stopped", "2026-10-31T09:00:00Z")).toBe("Gestoppt seit 31.10.2026");
    expect(agentStatusText("stopped", null)).toBe("Gestoppt");
    expect(agentStatusText("off", null)).toBe("Aus");
    expect(agentStatusText("on", null)).toBe("Ein");
  });
  it("passes an unknown state through", () => {
    expect(agentStatusText("other", null)).toBe("other");
  });
});

describe("AIG1-C5 (a)/(b): stops of one agent from agent_health.stops", () => {
  const raw = [
    { stop_id: "00000000-0000-4000-a000-0000000006f2", reason: "threshold", stopped_at: "2026-11-01T08:00:00Z", open: 2, not_open: 1 },
    { stop_id: "00000000-0000-4000-a000-0000000006f1", reason: "version_changed", stopped_at: "2026-10-20T08:00:00Z", open: 0, not_open: 3 },
  ];
  it("parses the database's array and keeps its order (newest first)", () => {
    const stops = parseAgentStops(raw);
    expect(stops.map((s) => s.stop_id)).toEqual([raw[0].stop_id, raw[1].stop_id]);
    expect(stops[0]).toEqual({ ...raw[0] });
  });
  it("drops anything that is not a stop row (never invents a count)", () => {
    expect(parseAgentStops(null)).toEqual([]);
    expect(parseAgentStops("x")).toEqual([]);
    expect(parseAgentStops([{ stop_id: "x" }, { stop_id: raw[0].stop_id, open: "2" }])).toEqual([]);
  });
  it("a stop with open lines is followed up; at 0 offen it is history", () => {
    const stops = parseAgentStops(raw);
    expect(openStops(stops).map((s) => s.stop_id)).toEqual([raw[0].stop_id]);
    expect(stopOpenText(stops[0])).toBe("Gestoppt am 01.11.2026 · Werte: 2 offen · 1 nicht mehr offen");
    expect(stopHistoryText(stops[1])).toBe("gestoppt am 20.10.2026 · 0 offen · 3 nicht mehr offen");
  });
});

describe("AIG1-C5 (b): the health list links every stop with open lines, whatever the state", () => {
  it("the link is not tied to state === 'stopped'", () => {
    expect(healthPage).toContain("Betroffene Werte ansehen");
    expect(healthPage).not.toMatch(/state === "stopped" \?/);
    expect(healthPage).toContain("openStops(");
  });
  it("shows the expired count and the status text", () => {
    expect(healthPage).toContain("expiredText(");
    expect(healthPage).toContain("agentStatusText(");
  });
});
