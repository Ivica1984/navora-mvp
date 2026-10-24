import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  formatWatchedDay, memberInformation, parseWatchedDay, PUSH_PAYLOAD, PUSH_TEXT, PUSH_URL, pushOutcome, readSubscription, statusText,
} from "@/features/push/rules";

// SIG2 (migration 0062, ADR-076): fixed text, member information, watched-hours input, subscription shape.

describe("SIG2-8: the push payload", () => {
  it("is the one fixed text and the /field link, nothing else", () => {
    expect(PUSH_TEXT).toBe("NAVORA: Ein Sicherheitssignal wartet auf dich.");
    expect(PUSH_URL).toBe("/field?von=push");
    expect(JSON.parse(PUSH_PAYLOAD)).toEqual({ text: PUSH_TEXT, url: PUSH_URL });
  });

  it("carries no ID: the link has no visit, client or date parameter", () => {
    const url = new URL(PUSH_URL, "https://navora.test");
    expect([...url.searchParams.keys()]).toEqual(["von"]);
    expect(PUSH_PAYLOAD).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}-/i);
  });

  it("the service worker shows the same constant text", () => {
    const sw = readFileSync("public/sw.js", "utf8");
    expect(sw).toContain(`const TEXT = "${PUSH_TEXT}";`);
    expect(sw).toContain(`const URL_ON_TAP = "${PUSH_URL}";`);
    expect(sw).not.toMatch(/event\.data/);   // the payload never changes what is shown
  });
});

describe("SIG2-1: member information (DSG Art. 19)", () => {
  const vendors = [
    { vendor: "google_fcm", legal_entity: "Google LLC", country: "USA", dpf_read_on: "2026-10-24" },
    { vendor: "microsoft_wns", legal_entity: "Microsoft Corporation", country: "USA", dpf_read_on: "2026-10-24" },
  ];
  it("names what, when, the vendors with their country, and how to switch off", () => {
    const text = memberInformation(vendors).join(" ");
    expect(text).toContain(PUSH_TEXT);
    expect(text).toContain("Keine Klientendaten");
    expect(text).toContain("geplanten Arbeitszeit");
    expect(text).toContain("Google LLC, USA");
    expect(text).toContain("Microsoft Corporation, USA");
    expect(text).toContain("Ausschalten");
  });
  it("SIG2-12: says that Operations is reached outside the app only during the watched hours", () => {
    expect(memberInformation(vendors).join(" ")).toContain("nur während der überwachten Zeiten");
    expect(memberInformation(vendors).join(" ")).not.toContain("zu jeder Zeit");
  });
  it("says so when no vendor is released", () => {
    expect(memberInformation([]).join(" ")).toContain("kein Anbieter freigegeben");
  });
});

describe("SIG2-2: status text", () => {
  it("is active / not active only", () => {
    expect(statusText(true)).toBe("Benachrichtigung ausserhalb der App: aktiv");
    expect(statusText(false)).toBe("Benachrichtigung ausserhalb der App: nicht aktiv");
  });
});

describe("SIG2-6: watched hours input", () => {
  it("parses one or more periods for a weekday", () => {
    expect(parseWatchedDay(1, "07:00-20:00")).toEqual([{ weekday: 1, starts: "07:00", ends: "20:00" }]);
    expect(parseWatchedDay(2, "13:00-20:00, 07:00-12:00")).toEqual([
      { weekday: 2, starts: "07:00", ends: "12:00" }, { weekday: 2, starts: "13:00", ends: "20:00" }]);
    expect(parseWatchedDay(7, "22:00-24:00")).toEqual([{ weekday: 7, starts: "22:00", ends: "24:00" }]);
    expect(parseWatchedDay(3, "  ")).toEqual([]);
  });
  it.each(["20:00-07:00", "07:00-07:00", "7:00-20:00", "07:00-12:00, 11:00-20:00", "24:00-24:00", "07:00-25:00", "abc"])(
    "refuses %s", (t) => expect(parseWatchedDay(1, t)).toBeNull());
  it("formats back for the form", () => {
    expect(formatWatchedDay([{ starts: "07:00:00", ends: "20:00:00" }, { starts: "22:00", ends: "24:00:00" }])).toBe("07:00-20:00, 22:00-24:00");
  });
});

describe("SIG2-1: subscription shape", () => {
  const keys = { p256dh: "B".repeat(87), auth: "a".repeat(22) };
  it("accepts an https endpoint with both keys", () => {
    expect(readSubscription({ endpoint: "https://fcm.googleapis.com/fcm/send/x", keys })).toEqual({
      endpoint: "https://fcm.googleapis.com/fcm/send/x", ...keys });
  });
  it.each([
    [{ endpoint: "http://fcm.googleapis.com/x", keys }],
    [{ endpoint: "https://fcm.googleapis.com/x", keys: { p256dh: "short", auth: keys.auth } }],
    [{ endpoint: "https://fcm.googleapis.com/x", keys: { p256dh: keys.p256dh, auth: "a/b" } }],
    [{ endpoint: "https://fcm.googleapis.com/x" }],
    [null],
  ])("refuses %j", (input) => expect(readSubscription(input)).toBeNull());
});

describe("push service responses (RFC 8030)", () => {
  it("maps status codes", () => {
    expect(pushOutcome(201)).toEqual({ ok: true, gone: false });
    expect(pushOutcome(410)).toEqual({ ok: false, gone: true });
    expect(pushOutcome(404)).toEqual({ ok: false, gone: true });
    expect(pushOutcome(429)).toEqual({ ok: false, gone: false });
  });
});
