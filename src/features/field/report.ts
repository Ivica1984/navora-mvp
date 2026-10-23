import type { Database } from "@/lib/supabase/database.types";

/** One row of public.field_reports() — latest report version per visit (F6, migration 0016). */
export type FieldReport = Database["public"]["Functions"]["field_reports"]["Returns"][number];

export type ReportAction = "create" | "edit" | "sign" | "countersign" | "correct" | "withdraw";

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
    return report.i_can_countersign
      ? { label: `Unterschrieben – Gegenzeichnung offen${version}`, tone: "waiting", actions: ["countersign"], hint: null }
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

/** German messages for rejection reasons returned by the report commands (migrations 0016, 0041, 0044, 0049). */
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
export function visitFactsLocked(report: Pick<FieldReport, "status"> | null): boolean {
  return report?.status === "signed" || report?.status === "final";
}

export const FACTS_LOCKED_HINT =
  "Der Bericht ist unterschrieben. Zeiten und Beobachtungen ändern sich nur noch über «Bericht korrigieren» (neue Fassung).";
