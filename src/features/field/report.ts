import type { Database } from "@/lib/supabase/database.types";

/** One row of public.field_reports() — latest report version per visit (F6, migration 0016). */
export type FieldReport = Database["public"]["Functions"]["field_reports"]["Returns"][number];

export type ReportAction = "create" | "edit" | "sign" | "countersign" | "return" | "correct" | "withdraw";

export type ReportView = {
  /** Short status line shown on the card. */
  label: string;
  tone: "open" | "waiting" | "final";
  actions: ReportAction[];
  /** Explains why the user cannot act (e.g. someone else signs). */
  hint: string | null;
};

/**
 * What the /field card shows for the visit report (F6, brief docs/agents/briefs/F6.md).
 * The database enforces every rule again; this only decides which buttons to offer.
 */
export function reportView(visitStatus: string | null, report: FieldReport | null): ReportView | null {
  if (visitStatus !== "completed") return null;

  if (!report) {
    // F7: completion creates the draft; a completed visit without one means the automatic draft failed.
    return {
      label: "Bericht nicht automatisch erstellt",
      tone: "open",
      actions: ["create"],
      hint: "Beim Abschluss konnte kein Entwurf entstehen. Bitte jetzt erstellen; die Meldung zeigt den Grund.",
    };
  }

  const version = report.version > 1 ? ` (Fassung ${report.version})` : "";

  if (report.status === "draft" && report.returned) {
    // F6R (migration 0065): a registered nurse returned the signed version; only the performer corrects and signs again.
    return report.i_am_performer
      ? {
          label: `Zurückgegeben: bitte korrigieren und neu unterschreiben${version}`,
          tone: "open",
          actions: ["edit", "sign"],
          hint: null,
        }
      : {
          label: `Zurückgegeben – wartet auf neue Unterschrift${version}`,
          tone: "waiting",
          actions: [],
          hint: "Korrigieren und neu unterschreiben kann nur die Person, die den Einsatz durchgeführt hat. Danach wird gegengezeichnet.",
        };
  }

  if (report.status === "draft") {
    // CSR1 / CGR-24-W (migration 0049): the performer may withdraw her own correction draft while it is untouched.
    // The database decides "untouched" (no time correction, observation or summary change since it was opened).
    const isCorrection = report.correction_reason != null;
    return report.i_am_performer
      ? { label: `Entwurf${version}`, tone: "open", actions: isCorrection ? ["edit", "sign", "withdraw"] : ["edit", "sign"], hint: null }
      : {
          label: `Entwurf${version}`,
          tone: "waiting",
          actions: [],
          hint: "Unterschreiben kann nur die Person, die den Einsatz durchgeführt hat.",
        };
  }

  if (report.status === "signed") {
    // F6R: next to "Gegenzeichnen", a registered nurse may return a version she knows is wrong (database: return_report).
    return report.i_can_countersign
      ? {
          label: `Unterschrieben – Gegenzeichnung offen${version}`,
          tone: "waiting",
          actions: report.i_can_return ? ["countersign", "return"] : ["countersign"],
          hint: null,
        }
      : {
          label: `Unterschrieben – Gegenzeichnung offen${version}`,
          tone: "waiting",
          actions: [],
          hint: report.i_am_performer
            ? "Eine Pflegefachperson deines Teams zeichnet gegen."
            : "Gegenzeichnen kann eine Pflegefachperson des Teams, nicht die ausführende Person.",
        };
  }

  if (report.status === "final") {
    return { label: `Bericht abgeschlossen${version}`, tone: "final", actions: ["correct"], hint: null };
  }

  return { label: "Berichtstatus unbekannt", tone: "waiting", actions: [], hint: null };
}

/** German messages for rejection reasons returned by the report commands (migrations 0016, 0041, 0044, 0049, 0065). */
export const REPORT_REJECTION_MESSAGE: Record<string, string> = {
  not_team_member: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team.",
  visit_not_completed: "Ein Bericht ist erst nach Abschluss des Einsatzes möglich.",
  no_performer: "Für diesen Einsatz ist kein Start erfasst; der Bericht braucht die ausführende Person.",
  draft_exists: "Für diesen Einsatz gibt es bereits einen Bericht.",
  not_draft: "Der Bericht ist bereits unterschrieben und kann nicht mehr geändert werden.",
  not_performer: "Den Bericht erstellt und unterschreibt die Person, die den Einsatz durchgeführt hat.",
  not_awaiting_countersignature: "Dieser Bericht wartet nicht auf eine Gegenzeichnung.",
  rn_required: "Gegenzeichnen kann nur eine Pflegefachperson des Teams.",
  own_report: "Den eigenen Bericht kann man nicht gegenzeichnen.",
  not_final: "Korrigiert werden kann nur ein abgeschlossener Bericht.",
  not_latest: "Es gibt bereits eine neuere Fassung dieses Berichts.",
  // CSR1 / CGR-02 (migration 0041): the facts changed after they were shown; nothing was signed.
  // CSR1 / CGR-19 (migration 0044, interim until D-30): only the performer signs a correction, and she left the team.
  performer_not_in_team:
    "Korrektur nicht möglich: Die Person, die den Einsatz durchgeführt hat, gehört nicht mehr zum Team und könnte die Korrektur nicht unterschreiben. Der abgeschlossene Bericht bleibt gültig. Wer in diesem Fall korrigieren darf, ist noch nicht geregelt.",
  // CSR1 / CGR-24-W (migration 0049): withdrawing a correction draft.
  not_correction: "Zurückziehen geht nur bei einer Korrektur; der erste Bericht wird unterschrieben.",
  draft_has_changes:
    "Nicht zurückgezogen: Seit dem Öffnen der Korrektur wurden Zeiten, Beobachtungen oder die Zusammenfassung geändert. Diese Änderungen müssen unterschrieben werden.",
  awaiting_countersignature:
    "Nicht zurückgezogen: Die Korrektur ist unterschrieben und wartet auf die Gegenzeichnung.",
  // F6R (migration 0065): returning a report.
  reason_too_short: "Bitte begründen, was korrigiert werden muss (mindestens 10 Zeichen).",
  returned_report:
    "Ein zurückgegebener Bericht wird nicht zurückgezogen: Bitte korrigieren und neu unterschreiben; danach wird gegengezeichnet.",
  facts_changed:
    "Nicht unterschrieben: Zeiten oder Beobachtungen haben sich geändert, seit du den Bericht geöffnet hast. Bitte die aktualisierten Angaben prüfen und erneut unterschreiben.",
};

export function reportRejectionMessage(reason: unknown): string {
  return (typeof reason === "string" && REPORT_REJECTION_MESSAGE[reason]) || "Bericht konnte nicht gespeichert werden.";
}

/**
 * CSR1 / CGR-03 (migration 0040): the visit's times and observations are fixed while its latest report version is
 * `signed` or `final`. They change again only through a report correction version ("Bericht korrigieren"), which
 * opens a new draft. The database enforces the same rule (`private.visit_facts_locked`); this only hides the buttons.
 */
export function visitFactsLocked(
  report: (Pick<FieldReport, "status"> & Partial<Pick<FieldReport, "returned" | "i_am_performer">>) | null,
): boolean {
  if (report?.status === "signed" || report?.status === "final") return true;
  // F6R-3 (migration 0065): after a return only the performer changes the visit's facts.
  return report?.status === "draft" && report.returned === true && report.i_am_performer !== true;
}

/** F6R: the visit's facts are open, but only for the performer of a returned report. */
export const RETURNED_LOCKED_HINT =
  "Der Bericht wurde zurückgegeben. Zeiten und Beobachtungen korrigiert nur die Person, die den Einsatz durchgeführt hat.";

/** F6R-8: what the countersigner confirms before returning. */
export function returnConfirmation(performerName: string | null | undefined): string {
  const who = performerName?.trim() ? performerName.trim() : "die ausführende Person";
  return `Der Bericht geht an ${who} zurück und wird erst nach erneuter Unterschrift und deiner Gegenzeichnung gültig.`;
}

export const FACTS_LOCKED_HINT =
  "Der Bericht ist unterschrieben. Zeiten und Beobachtungen ändern sich nur noch über «Bericht korrigieren» (neue Fassung).";
