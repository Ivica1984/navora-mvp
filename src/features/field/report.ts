import type { Database } from "@/lib/supabase/database.types";

/** One row of public.field_reports() — latest report version per visit (F6, migration 0016). */
export type FieldReport = Database["public"]["Functions"]["field_reports"]["Returns"][number];

export type ReportAction = "create" | "edit" | "sign" | "countersign" | "correct";

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
    return report.i_am_performer
      ? { label: `Entwurf${version}`, tone: "open", actions: ["edit", "sign"], hint: null }
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

/** German messages for rejection reasons returned by the report commands (migration 0016). */
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
