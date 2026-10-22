// COVER1 — pure helpers and labels (ADR-045).

export const COVER_MESSAGES: Record<string, string> = {
  invalid: "Ungültige Anfrage.",
  failed: "Die Übernahme konnte nicht gespeichert werden.",
  taken: "Schon vergeben: jemand anderes hat den Einsatz übernommen, oder das Angebot ist abgelaufen.",
  rejected: "Dieses Angebot ist nicht für dich (Team, Region oder Qualifikation).",
};

/** "A 30 · B 20 min" from the offer minutes; categories with 0 minutes are left out. */
export function offerMinutes(a: number | null, b: number | null, c: number | null): string {
  const parts = [["A", a], ["B", b], ["C", c]].filter(([, m]) => typeof m === "number" && m > 0).map(([k, m]) => `${k} ${m}`);
  return parts.length ? `${parts.join(" · ")} min` : "–";
}
