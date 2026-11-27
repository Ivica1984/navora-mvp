import { describe, expect, it } from "vitest";
import {
  isTakeWindowError,
  parseTakeWindow,
  takeWindowText,
  workDateLabel,
} from "@/features/team/take-window";

// HD-3s-F2-F1 (CGR-289 (c)): wording of the hand-path rejection. The facts come from the server (migration 0185).
const split = { work_date: "2026-11-19", blocks: "07:00 – 11:30 und 16:00 – 20:00", split: true, own_team: true,
  client_name: "Testheim Rhein (synthetisch)" };

describe("take window rejection (HD-3s-F2-F1)", () => {
  it("names date, both blocks, the pause and the home of the own team's take", () => {
    const text = takeWindowText(parseTakeWindow(split), "plan");
    expect(text).toBe(
      "Nicht gespeichert: Die verantwortliche Person hat am Do 19.11.2026 eine laufende geteilte Übernahme für " +
        "Testheim Rhein (synthetisch): 07:00 – 11:30 und 16:00 – 20:00. Die Pause zwischen den Blöcken gilt als belegt. " +
        "Bitte eine andere Person oder eine andere Zeit wählen.",
    );
  });

  it("never names a home for another team's take, even if a name were sent (CGR-137)", () => {
    const f = parseTakeWindow({ ...split, own_team: false });
    expect(f?.clientName).toBeNull();
    const text = takeWindowText(f, "plan");
    expect(text).toContain("in einem anderen Team");
    expect(text).not.toContain("Testheim");
  });

  it("words a one-block take without a pause line", () => {
    const text = takeWindowText(
      parseTakeWindow({ work_date: "2026-11-19", blocks: "08:00 – 10:00", split: false, own_team: true }),
      "move",
    );
    expect(text).toBe(
      "Nicht verschoben: Die verantwortliche Person hat am Do 19.11.2026 eine laufende Übernahme: 08:00 – 10:00. " +
        "Bitte eine andere Zeit wählen.",
    );
  });

  it("speaks to the nurse herself when she takes an open visit", () => {
    expect(takeWindowText(parseTakeWindow(split), "take")).toMatch(/^Nicht übernommen: Du hast am Do 19\.11\.2026 /);
  });

  it("falls back to a text without facts for the backstop error or malformed facts", () => {
    expect(parseTakeWindow({ work_date: "19.11.2026", blocks: "x" })).toBeNull();
    expect(parseTakeWindow(null)).toBeNull();
    expect(takeWindowText(null, "plan")).toBe(
      "Nicht gespeichert: Die verantwortliche Person hat zu dieser Zeit eine laufende Übernahme. Bei einem geteilten " +
        "Dienst gilt auch die Pause zwischen den Blöcken als belegt. Bitte eine andere Person oder eine andere Zeit wählen.",
    );
    expect(isTakeWindowError({ code: "P0001", message: "member_take_window" })).toBe(true);
    expect(isTakeWindowError({ code: "P0001", message: "other" })).toBe(false);
    expect(isTakeWindowError(null)).toBe(false);
  });

  it("labels calendar dates without a time-zone shift", () => {
    expect(workDateLabel("2026-11-19")).toBe("Do 19.11.2026");
    expect(workDateLabel("2027-03-28")).toBe("So 28.03.2027");
  });
});
