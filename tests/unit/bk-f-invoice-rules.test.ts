// BK-f (contract 2026-11-20 06:39 point 5 «Unit: arithmetic and label texts»; migration 0156): the pure rules of the
// simulated invoice views. The amount itself is computed by the database (pgTAP 156); here only formatting and words.
import { describe, expect, it } from "vitest";
import {
  canRetry,
  fieldInvoiceLine,
  formatChf,
  formatHours,
  formatMinutes,
  INVOICE_LABEL,
  parsePrice,
  PRICE_LABEL,
  REFUSAL_CODES,
  refusalLine,
  refusalText,
  stateLabel,
} from "@/features/invoices/rules";

describe("BK-f invoice label (contract point 1)", () => {
  it("is exactly the contract text", () => {
    expect(INVOICE_LABEL).toBe("Simulierte Rechnung – synthetische Daten, Beispielpreis, kein Tarif, keine Zahlung über NAVORA");
  });
});

describe("BK-f arithmetic display", () => {
  it("formats CHF with 2 decimals", () => {
    expect(formatChf(285.6)).toMatch(/^CHF 285\.60$/);
    expect(formatChf("72")).toMatch(/^CHF 72\.00$/);
    expect(formatChf(null)).toBe("–");
  });
  it("shows hours from minutes with 2 decimals (238 min = 3.97 Std.)", () => {
    expect(formatHours(238)).toBe("3.97 Std.");
    expect(formatHours(240)).toBe("4.00 Std.");
    expect(formatHours(null)).toBe("–");
  });
  it("shows minutes", () => {
    expect(formatMinutes(180)).toBe("180 Min.");
    expect(formatMinutes("238.50")).toBe("238.50 Min.");
  });
});

describe("BK-f refusals (BK-8n, BK-9n): visible, never silent", () => {
  it("has a German text for every refusal code of migration 0156", () => {
    for (const c of REFUSAL_CODES) {
      expect(refusalText(c)).not.toBe("Kein Rechnungsentwurf.");
      expect(refusalText(c)).not.toMatch(/_/);
    }
  });
  it("words an unknown code without showing it", () => {
    expect(refusalText("something_new")).toBe("Kein Rechnungsentwurf.");
  });
  it("names both durations when the times disagree", () => {
    expect(refusalLine("times_disagree", 180, 240)).toBe("Zeiten weichen ab. Erfasst 180 Min., bestellt 240 Min.");
    expect(refusalLine("times_disagree", null, 240)).toBe("Zeiten weichen ab.");
  });
  it("offers «Neu prüfen» only where a second attempt can pass", () => {
    expect(canRetry("on_hold")).toBe(true);
    expect(canRetry("no_tolerance")).toBe(true);
    expect(canRetry("times_disagree")).toBe(false);
    expect(canRetry("already_drafted")).toBe(false);
  });
});

describe("BK-f /field line after signing", () => {
  it("says the draft was built, or why not", () => {
    expect(fieldInvoiceLine("draft", null)).toBe("Rechnungsentwurf für das Team erstellt.");
    expect(fieldInvoiceLine("refused", "on_hold")).toBe("Kein Rechnungsentwurf: Der Einsatz ist gesperrt (offene Qualitätssperre).");
    expect(fieldInvoiceLine("sent", null)).toBe("Rechnung an den Auftraggeber gesendet.");
    expect(fieldInvoiceLine(null, null)).toBeNull();
  });
  it("labels states for team and client", () => {
    expect(stateLabel("sent", "team")).toBe("Gesendet");
    expect(stateLabel("sent", "client")).toBe("Erhalten");
    expect(stateLabel("void", "client")).toBe("Ungültig (Bericht korrigiert)");
  });
});

describe("BK-f team price input (contract point 2 (a), 0155)", () => {
  it("reads CHF with at most two decimals, comma or point", () => {
    expect(parsePrice("68")).toBe(68);
    expect(parsePrice(" 68.50 ")).toBe(68.5);
    expect(parsePrice("68,05")).toBe(68.05);
  });
  it("refuses zero, 1000 and more, three decimals, signs and words", () => {
    for (const t of ["0", "0.00", "1000", "68.505", "-5", "abc", "", "1e2"]) expect(parsePrice(t)).toBeNull();
  });
  it("labels the price as an example, never a tariff", () => {
    expect(PRICE_LABEL).toContain("Beispielwert, kein Tarif");
  });
});
