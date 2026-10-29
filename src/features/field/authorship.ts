// OBS1 — who wrote an observation, and whether her qualification was recorded when she wrote it (ADR-118,
// migration 0095, `cra` CGR-93, `lca` 13:57). Pure display: the database records the facts; this module only turns
// them into one line. Nothing here refuses, hides, reorders or ranks an observation.

/**
 * The OBS1-1 marker as one short neutral text in `info` tone. PROVISIONAL wording (eng): `uxa` owns it (OBS1-4);
 * no internal code, no word that judges the person or the content.
 */
export const QUALIFICATION_NOT_RECORDED_TEXT = "Qualifikation war beim Schreiben nicht erfasst";

/**
 * A report version signed before OBS1 holds no author. PROVISIONAL wording (eng): `uxa` owns it (OBS1-3).
 * Never a guessed name.
 */
export const AUTHOR_NOT_STORED_TEXT = "Wer dies geschrieben hat, ist in dieser Fassung nicht gespeichert";

/** A member without an ADM1 display name. */
export const AUTHOR_WITHOUT_NAME_TEXT = "Teammitglied ohne Namen";

/** The author line of an observation on the visit card and in the handover. */
export function observationAuthor(note: { own: boolean; author_name?: string | null }): string {
  if (note.own) return "von dir";
  const name = note.author_name?.trim();
  return name ? name : AUTHOR_WITHOUT_NAME_TEXT;
}

/** Whether the OBS1-1 marker is shown: only when the fact was recorded as missing. */
export function showsQualificationMarker(value: unknown): boolean {
  return value === true;
}

export type SnapshotObservation = {
  content: string;
  recorded_at: string;
  handover?: boolean;
  edited?: boolean;
  author_id?: string | null;
  author_name?: string | null;
  author_qualification_missing?: boolean | null;
};

export type SnapshotAuthor =
  | { stored: false; text: string; marker: false }
  | { stored: true; text: string; marker: boolean };

/**
 * The author of one observation as the stored report version holds it (OBS1-3). A version without the author key was
 * written before OBS1: it says so in one neutral line and shows no name.
 */
export function snapshotAuthor(o: SnapshotObservation): SnapshotAuthor {
  if (!o || typeof o !== "object" || !("author_id" in o) || !o.author_id) {
    return { stored: false, text: AUTHOR_NOT_STORED_TEXT, marker: false };
  }
  const name = typeof o.author_name === "string" ? o.author_name.trim() : "";
  return { stored: true, text: name || AUTHOR_WITHOUT_NAME_TEXT, marker: showsQualificationMarker(o.author_qualification_missing) };
}
