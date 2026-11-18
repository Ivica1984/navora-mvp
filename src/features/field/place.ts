// BK-e1 / UXR-190 (#1232, `cra` CGR-212; ADR-202 (1)): the «Ort» line of the /field visit card.
// A visit with a postcode but no street must not read as a complete address: the nurse could not find the door and
// the team would not notice the gap. Presentation only; whether such a visit may be planned is not decided here (OPEN).

export const ADDRESS_MISSING = "Adresse fehlt – im Team klären";
export const STREET_MISSING = "Strasse fehlt – im Team klären";

export type PlaceLine = { text: string; missing: boolean };

function clean(value: string | null | undefined): string {
  return (value ?? "").trim();
}

export function placeLine(address: string | null | undefined, plz: string | null | undefined, ort: string | null | undefined): PlaceLine {
  const street = clean(address);
  const town = [clean(plz), clean(ort)].filter(Boolean).join(" ");
  if (street) return { text: [street, town].filter(Boolean).join(", "), missing: false };
  if (town) return { text: `${town} · ${STREET_MISSING}`, missing: true };
  return { text: ADDRESS_MISSING, missing: true };
}
