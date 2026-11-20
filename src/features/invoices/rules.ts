// BK-f (PO package contract 2026-11-20 06:39; migration 0156): pure rules of the simulated invoice views. No Next or
// Supabase imports, unit-tested (tests/unit/bk-f-invoice-rules.test.ts). The database decides every state, refusal,
// minute and amount (`private.take_invoice_build`); this module only words the codes and formats the numbers.
// Every function here is a fixed, checkable rule; no AI model. Words: PROPOSED by `eng` for `uxa`; the label text of
// contract point 1 is the contract's and goes to `lca` at the gate (UWG Art. 3, W-7).

/** Contract point 1: on every invoice view. */
export const INVOICE_LABEL =
  "Simulierte Rechnung – synthetische Daten, Beispielpreis, kein Tarif, keine Zahlung über NAVORA";

export const INVOICE_STATES = ["draft", "sent", "void", "refused"] as const;
export type InvoiceState = (typeof INVOICE_STATES)[number];

/** Refusal codes of `private.take_invoice_build` (0156), in the order the rule checks them. */
export const REFUSAL_CODES = [
  "not_signed",
  "superseded",
  "already_drafted",
  "on_hold",
  "no_tolerance",
  "no_price",
  "no_times",
  "times_disagree",
  "build_failed",
] as const;
export type RefusalCode = (typeof REFUSAL_CODES)[number];

const REFUSAL_TEXT: Record<RefusalCode, string> = {
  not_signed: "Der Bericht ist noch nicht unterschrieben.",
  superseded: "Der Bericht wurde inzwischen korrigiert.",
  already_drafted: "Für diesen Einsatz gibt es schon einen Rechnungsentwurf.",
  on_hold: "Der Einsatz ist gesperrt (offene Qualitätssperre).",
  no_tolerance: "Der Zeitabgleich ist noch nicht eingerichtet.",
  no_price: "Das Team hat noch keinen Stundenpreis.",
  no_times: "Im Bericht fehlt die Arbeitszeit.",
  times_disagree: "Zeiten weichen ab.",
  build_failed: "Technischer Fehler. Bitte später erneut versuchen.",
};
const UNKNOWN_REFUSAL = "Kein Rechnungsentwurf.";

export function isRefusalCode(code: string | null | undefined): code is RefusalCode {
  return typeof code === "string" && (REFUSAL_CODES as ReadonlyArray<string>).includes(code);
}

export function refusalText(code: string | null | undefined): string {
  return isRefusalCode(code) ? REFUSAL_TEXT[code] : UNKNOWN_REFUSAL;
}

/** Refusals the team can clear and then build again («Neu prüfen»): the rule may pass on a second attempt. */
export function canRetry(code: string | null | undefined): boolean {
  return code === "on_hold" || code === "no_tolerance" || code === "no_price" || code === "build_failed";
}

function num(v: number | string | null | undefined): number | null {
  if (v === null || v === undefined || v === "") return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

/** CHF with 2 decimals, Swiss grouping («CHF 1’285.60»). The database already rounded to 2 decimals. */
export function formatChf(v: number | string | null | undefined): string {
  const n = num(v);
  if (n === null) return "–";
  return `CHF ${new Intl.NumberFormat("de-CH", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)}`;
}

/** Hours from minutes, 2 decimals («3.97 Std.»); display only, the amount comes from the database. */
export function formatHours(minutes: number | string | null | undefined): string {
  const n = num(minutes);
  if (n === null) return "–";
  return `${(Math.round((n / 60) * 100) / 100).toFixed(2)} Std.`;
}

export function formatMinutes(minutes: number | string | null | undefined): string {
  const n = num(minutes);
  if (n === null) return "–";
  return `${Number.isInteger(n) ? n : n.toFixed(2)} Min.`;
}

/** The refusal reason, with the two durations when the times disagree (shown while the carer still remembers). */
export function refusalLine(code: string | null | undefined, recorded?: number | string | null, ordered?: number | string | null): string {
  if (code === "times_disagree" && num(recorded) !== null && num(ordered) !== null) {
    return `${REFUSAL_TEXT.times_disagree} Erfasst ${formatMinutes(recorded)}, bestellt ${formatMinutes(ordered)}`;
  }
  return refusalText(code);
}

/** /field: the one line after «Bericht unterschreiben» on a taken shift (contract point 1). */
export function fieldInvoiceLine(state: string | null | undefined, reason: string | null | undefined): string | null {
  switch (state) {
    case "draft":
      return "Rechnungsentwurf für das Team erstellt.";
    case "sent":
      return "Rechnung an den Auftraggeber gesendet.";
    case "void":
      return "Rechnung ungültig, weil der Bericht korrigiert wurde.";
    case "refused":
      return `Kein Rechnungsentwurf: ${refusalText(reason)}`;
    default:
      return null;
  }
}

/** /team and /order: the state word of one invoice row. */
export function stateLabel(state: string, audience: "team" | "client"): string {
  switch (state) {
    case "draft":
      return "Entwurf";
    case "sent":
      return audience === "team" ? "Gesendet" : "Erhalten";
    case "void":
      return "Ungültig (Bericht korrigiert)";
    case "refused":
      return "Nicht erstellt";
    default:
      return state;
  }
}

/** /team: what a void after sending asks of the team (CGR-210 (b)). */
export const VOID_AFTER_SEND_TEXT =
  "Diese Rechnung wurde nach dem Senden ungültig, weil der Bericht korrigiert wurde. Der Auftraggeber sieht das.";
/** /order: the same void from the client's side. */
export const CLIENT_VOID_TEXT = "Ungültig: Das Team hat den Bericht korrigiert. Eine neue Rechnung folgt, sobald das Team sie sendet.";

export const SEND_BUTTON = "Bestätigen und senden";
export const SEND_HINT = "Der Auftraggeber sieht die Rechnung danach unter «Rechnungen». NAVORA zieht kein Geld ein.";

/** /team: the label next to the team's own price (contract point 2 (a), W-7). */
export const PRICE_LABEL = "Beispielwert, kein Tarif. Euer Team legt den Preis selbst fest; NAVORA gibt keinen Wert vor.";

/**
 * The team's price per hour as typed («68», «68.50», «68,50»): CHF with at most 2 decimals, above 0 and below 1000
 * (the same bounds as `set_team_price`, 0155, which decides again). Returns null when it is not such a number.
 */
export function parsePrice(text: string): number | null {
  const t = text.trim().replace(",", ".");
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(t)) return null;
  const n = Number(t);
  return n > 0 && n < 1000 ? n : null;
}
