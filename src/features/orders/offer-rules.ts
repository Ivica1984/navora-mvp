// BK-c2 screens (ADR-200; brief docs/agents/briefs/BK.md 04:39 (3), (4); 05:39 (3); 08:39 (2)–(4); 09:39 (2) (d)).
// Pure wording of the team card states (`/team`) and the client status (`/order`). Words: BK5_OFFER_TEMPLATE.md §2–§4
// and UX_REVIEW.md 07:52 (`uxa`, PROPOSED; placed by the PO for the simulation). The database decides every state;
// these functions only word what `team_order_offers()` and `client_orders()` return. No rule is made here.

/** One row of `public.team_order_offers()` (migration 0136). */
export type TeamOrderOfferRow = {
  order_id: string;
  team_id: string;
  sentence: string | null;
  starts_at: string;
  ends_at: string;
  duration_minutes: number | null;
  postcode: string | null;
  place_name: string | null;
  grade: string | null;
  activity_tags: string[] | null;
  required_tags: string[] | null;
  distance_km: number | null;
  limit_km: number | null;
  offer_state: string;
  taken_member_id: string | null;
  taken_by: string | null;
  taken_at: string | null;
  acknowledged_at: string | null;
  latest_cover_at: string | null;
  caller_free: boolean | null;
  release_kind: string | null;
  released_member_id: string | null;
};

/** One row of `public.order_take_candidates()`: members at step 4 only, never a step (AUT-132). */
export type TakeCandidateRow = { user_id: string; is_caller: boolean };

const ZURICH = "Europe/Zurich";
const WEEKDAY: Record<string, string> = { Mon: "Mo", Tue: "Di", Wed: "Mi", Thu: "Do", Fri: "Fr", Sat: "Sa", Sun: "So" };

function zurichParts(iso: string): Record<string, string> {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: ZURICH,
    weekday: "short",
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(iso));
  return Object.fromEntries(parts.map((p) => [p.type, p.value]));
}

/** «14:31», Zurich time. */
export function zurichTime(iso: string): string {
  const p = zurichParts(iso);
  return `${p.hour}:${p.minute}`;
}

/** «Sa 21.11., 07:00», Zurich time. */
export function zurichDayTime(iso: string): string {
  const p = zurichParts(iso);
  return `${WEEKDAY[p.weekday] ?? p.weekday} ${p.day}.${p.month}., ${p.hour}:${p.minute}`;
}

/** «[Vorname N.]» from a display name (first word, initial of the second); never an invented name. */
export function shortName(displayName: string | null | undefined): string {
  const words = (displayName ?? "").trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return "Ein Teammitglied";
  if (words.length === 1) return words[0];
  return `${words[0]} ${words[1].charAt(0)}.`;
}

/** «[Vorname]» from a display name. */
export function firstName(displayName: string | null | undefined): string {
  const words = (displayName ?? "").trim().split(/\s+/).filter(Boolean);
  return words[0] ?? "das Teammitglied";
}

export type TeamOfferView =
  | {
      kind: "offer";
      tag: "Neues Angebot";
      broadcast: string;
      /** CGR-234 (d): the own team's earlier take was released and the new round still offers the order to the team. */
      releaseLine: string | null;
      /** H-BK-06:39 / AUT-132: one neutral line when the caller herself is not free; never the reason. */
      callerNotFree: string | null;
      candidates: { userId: string; label: string }[];
      preselected: string | null;
      /** The primary button's label before a person is ticked. */
      chooseLabel: "Person wählen" | "Andere Person wählen";
    }
  | { kind: "taken"; tag: "Übernommen" | "Für dich eingeteilt"; lines: string[]; actions: boolean; mine: boolean }
  | { kind: "released"; line: string };

export const BROADCAST_LINE = "Alle passenden Teams sehen dieses Angebot.";
export const TAKE_FOOTER =
  "Beim Übernehmen prüft NAVORA alle Bedingungen für die gewählte Person erneut; ‹Gedeckt› sieht der Auftraggeber erst mit einer benannten, geprüften Person.";

function releaseText(kind: string | null, member: string, latestCoverAt: string | null): string | null {
  switch (kind) {
    case "member_cannot":
      return `Nicht mehr übernommen: ${member} kann diese Schicht nicht übernehmen.`;
    case "not_acknowledged":
      return `Die Übernahme gilt nicht mehr: ${member} hat nicht bis ${latestCoverAt ? zurichTime(latestCoverAt) : "zur Deckungszeit"} bestätigt.`;
    case "no_longer_eligible":
      return `Nicht mehr gedeckt: ${member} erfüllt die Bedingungen für diese Schicht nicht mehr.`;
    default:
      return null;
  }
}

/** The card for one offer row, as seen by the caller (`callerId`). */
export function teamOfferView(
  row: TeamOrderOfferRow,
  callerId: string,
  names: Map<string, string>,
  candidates: TakeCandidateRow[],
): TeamOfferView {
  const nameOf = (id: string | null) => shortName(id ? names.get(id) : null);
  if (row.offer_state === "released") {
    return { kind: "released", line: releaseText(row.release_kind, nameOf(row.released_member_id), row.latest_cover_at) ?? "Die Übernahme gilt nicht mehr." };
  }
  if (row.offer_state === "taken_by_us") {
    const member = row.taken_member_id;
    const mine = member === callerId;
    const selfNamed = member !== null && member === row.taken_by;
    if (selfNamed) {
      return { kind: "taken", tag: "Übernommen", lines: [`Ihr habt diese Schicht übernommen. Es geht: ${nameOf(member)}.`], actions: false, mine };
    }
    if (row.acknowledged_at) {
      return mine
        ? { kind: "taken", tag: "Für dich eingeteilt", lines: ["Du bist für diese Schicht eingeteilt."], actions: false, mine }
        : { kind: "taken", tag: "Übernommen", lines: [`Es geht: ${nameOf(member)} · bestätigt um ${zurichTime(row.acknowledged_at)}`], actions: false, mine };
    }
    const until = row.latest_cover_at ? zurichDayTime(row.latest_cover_at) : null;
    if (mine) {
      return {
        kind: "taken",
        tag: "Für dich eingeteilt",
        lines: [
          `${nameOf(row.taken_by)} hat diese Schicht für euer Team übernommen und dich eingeteilt.`,
          until ? `Bitte bis ${until} bestätigen.` : "Bitte bestätigen.",
        ],
        actions: true,
        mine,
      };
    }
    return {
      kind: "taken",
      tag: "Übernommen",
      lines: [
        `Es geht: ${nameOf(member)} · Bestätigung ausstehend`,
        `Übernommen von ${nameOf(row.taken_by)}${row.taken_at ? ` um ${zurichTime(row.taken_at)}` : ""}.`,
        ...(until ? [`Bestätigt ${firstName(member ? names.get(member) : null)} nicht bis ${until}, gilt die Übernahme nicht mehr.`] : []),
      ],
      actions: false,
      mine,
    };
  }
  const list = candidates.map((c) => ({
    userId: c.user_id,
    label: c.is_caller ? `Ich (${firstName(names.get(c.user_id))})` : shortName(names.get(c.user_id)),
  }));
  const callerListed = candidates.some((c) => c.is_caller);
  const releaseLine = releaseText(row.release_kind, nameOf(row.released_member_id), row.latest_cover_at);
  return {
    kind: "offer",
    tag: "Neues Angebot",
    broadcast: BROADCAST_LINE,
    releaseLine,
    callerNotFree: row.caller_free && callerListed ? null : "Du selbst kannst diese Schicht nicht übernehmen.",
    candidates: list,
    preselected: row.caller_free && callerListed ? callerId : null,
    chooseLabel: releaseLine ? "Andere Person wählen" : "Person wählen",
  };
}

/** The offer card's distance line: this team only (template §2 (2)). */
export function offerPlaceLine(row: Pick<TeamOrderOfferRow, "postcode" | "place_name" | "distance_km">): string {
  const place = [row.postcode, row.place_name].filter(Boolean).join(" ");
  if (row.distance_km === null || row.distance_km === undefined) return place;
  return `${place} · ${String(row.distance_km).replace(".", ",")} km von eurem Einsatzgebiet`;
}

/** The ordered level in the client's words (CGR-226 (a): the ordered level, never the person's own grade). */
const LEVEL: Record<string, string> = { ags_eba: "AGS", fage_efz: "FaGe", nurse_hf_fh: "HF" };

export type ClientCoverInput = {
  cover_state: string;
  cover_detail: string | null;
  starts_at: string;
  latest_cover_at: string | null;
  covered_team_name: string | null;
  taken_at: string | null;
  grade: string | null;
};

/** The client's status line (`role="status"`) and its detail. Anything unknown reads «Noch nicht gedeckt». */
export function clientCoverLines(o: ClientCoverInput): { headline: string; detail: string | null } {
  const begin = `Beginn ${zurichDayTime(o.starts_at)}`;
  if (o.cover_state === "covered") {
    const level = o.grade ? (LEVEL[o.grade] ?? null) : null;
    return {
      headline: level ? `Gedeckt · Person benannt, geprüft für ${level}` : "Gedeckt · Person benannt, geprüft",
      detail: [o.covered_team_name ? `Team ${o.covered_team_name}` : null, o.taken_at ? `übernommen um ${zurichTime(o.taken_at)}` : null]
        .filter(Boolean)
        .join(" · ") || null,
    };
  }
  if (o.cover_state === "not_covered") {
    switch (o.cover_detail) {
      case "started":
        return { headline: `Nicht gedeckt · Die Schicht hat um ${zurichTime(o.starts_at)} begonnen.`, detail: null };
      case "cover_time_reached":
        return { headline: `Nicht gedeckt · ${begin}`, detail: "Bis jetzt hat kein Team diese Schicht übernommen." };
      default:
        // F-1: «no team eligible» and «all declined» are one neutral state for the client.
        return { headline: `Nicht gedeckt · ${begin}`, detail: "Kein passendes Team ist frei." };
    }
  }
  if (o.cover_state === "no_longer_covered") {
    return {
      headline: `Nicht mehr gedeckt · ${begin}`,
      detail: "Die eingeteilte Person kann nicht. Das Angebot geht wieder an alle passenden Teams.",
    };
  }
  if (o.cover_state === "open" && o.cover_detail === "awaiting_acknowledgement") {
    return { headline: `Noch nicht gedeckt · ${begin}`, detail: "Ein Team hat übernommen; die eingeteilte Person bestätigt noch." };
  }
  return { headline: `Noch nicht gedeckt · ${begin}`, detail: o.cover_state === "open" ? "Angebot an alle passenden Teams gleichzeitig." : null };
}

/** The words for a command answer on the team card; never a step code or a reason about a person (AUT-132, `lca`). */
export const ALREADY_TAKEN_TEXT = "Bereits übernommen. Ein anderes Team hat diese Schicht übernommen. Für euch ist nichts gespeichert.";
export const DECLINED_TEXT = "Abgelehnt. Ihr seht dieses Angebot nicht mehr.";

export function offerCommandText(reason: string | null | undefined): string {
  switch (reason) {
    case "already_taken":
      return ALREADY_TAKEN_TEXT;
    case "already_declined":
      return DECLINED_TEXT;
    case "member_not_eligible":
      return "Die gewählte Person kann diese Schicht zurzeit nicht übernehmen. Bitte eine andere Person wählen.";
    case "order_started":
      return "Die Schicht hat bereits begonnen.";
    case "not_offered":
    case "not_team_member":
    case "member_not_in_team":
      return "Dieses Angebot ist für euer Team nicht mehr offen.";
    case "taken_by_us":
      return "Euer Team hat diese Schicht bereits übernommen.";
    default:
      return "Diese Übernahme ist nicht mehr offen.";
  }
}
