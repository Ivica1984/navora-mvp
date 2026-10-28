"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { completeVisit, startVisit } from "@/features/visits/commands";
import Sidebar from "@/components/layout/Sidebar";
import CommandError from "@/components/feedback/CommandError";
import {
  getVisitServices,
  getVisitStatusLabel,
  getVisitTimeRange,
  type CareVisitRow,
} from "@/features/visits/types";
import { SECONDARY_TEXT } from "@/lib/ui/colors";

type VisitsClientProps = {
  visits: CareVisitRow[];
};

function getVisitsByStatus(visits: CareVisitRow[], status: string) {
  return visits.filter((visit) => visit.status === status);
}

function getDateLabel(date: string | null) {
  if (!date) return "Datum offen";

  return new Intl.DateTimeFormat("de-CH", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(new Date(date));
}

function getStatusStyles(status: string | null) {
  if (status === "completed") {
    return {
      background: "#dcfce7",
      color: "#166534",
    };
  }

  if (status === "started" || status === "on_the_way") {
    return {
      background: "#dbeafe",
      color: "#1d4ed8",
    };
  }

  if (status === "cancelled" || status === "no_show" || status === "interrupted") {
    return {
      background: "#fee2e2",
      color: "#b91c1c",
    };
  }

  return {
    background: "#fef3c7",
    color: "#92400e",
  };
}

export default function VisitsClient({ visits }: VisitsClientProps) {
  const [selectedVisitId, setSelectedVisitId] = useState<string | null>(
    visits[0]?.id ?? null
  );

  const [isUpdating, setIsUpdating] = useState(false);
  const [commandError, setCommandError] = useState<string | null>(null);
  const router = useRouter();

  const selectedVisit = useMemo(() => {
    return visits.find((visit) => visit.id === selectedVisitId) ?? null;
  }, [visits, selectedVisitId]);

  const plannedCount = getVisitsByStatus(visits, "planned").length;
  const activeCount =
    getVisitsByStatus(visits, "started").length +
    getVisitsByStatus(visits, "on_the_way").length;
  const completedCount = getVisitsByStatus(visits, "completed").length;

  async function runTransition(command: typeof startVisit) {
    if (!selectedVisit) return;

    setIsUpdating(true);
    // One key per user action: a retried request is applied at most once (T10).
    const result = await command({
      visitId: selectedVisit.id,
      idempotencyKey: crypto.randomUUID(),
    });
    setIsUpdating(false);

    setCommandError(result.ok ? null : result.error);

    router.refresh();
  }

  const handleStartVisit = () => runTransition(startVisit);
  const handleCompleteVisit = () => runTransition(completeVisit);

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        gridTemplateColumns: "280px 1fr",
        background: "#f4f7f4",
        fontFamily: "Inter, sans-serif",
        color: "#153328",
      }}
    >
      <Sidebar active="visits" />

      <main style={{ padding: "32px" }}>
        <section style={{ marginBottom: "24px" }}>
          <p
            style={{
              fontSize: "12px",
              fontWeight: 700,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              color: SECONDARY_TEXT,
              marginBottom: "8px",
            }}
          >
            Einsätze
          </p>

          <h1 style={{ fontSize: "32px", margin: 0 }}>
            Online-Einsatzübersicht
          </h1>

          <p style={{ color: SECONDARY_TEXT, marginTop: "8px" }}>
            Echte Übersicht über geplante, laufende und abgeschlossene Einsätze.
          </p>
        </section>

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
            gap: "16px",
            marginBottom: "24px",
          }}
        >
          <MetricCard label="Geplant" value={plannedCount} />
          <MetricCard label="Laufend / unterwegs" value={activeCount} />
          <MetricCard label="Abgeschlossen" value={completedCount} />
        </section>

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "1.4fr 0.8fr",
            gap: "20px",
            alignItems: "start",
          }}
        >
          <section
            style={{
              background: "#eef3ef",
              borderRadius: "24px",
              padding: "20px",
              minHeight: "420px",
            }}
          >
            <h2 style={{ marginTop: 0 }}>Alle Einsätze</h2>

            <div style={{ display: "grid", gap: "12px" }}>
              {visits.map((visit) => {
                const isSelected = selectedVisitId === visit.id;

                return (
                  <button
                    key={visit.id}
                    type="button"
                    onClick={() => {
                      setSelectedVisitId(visit.id);
                      setCommandError(null);
                    }}
                    style={{
                      textAlign: "left",
                      background: "white",
                      borderRadius: "18px",
                      padding: "16px",
                      boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
                      border: isSelected
                        ? "2px solid #16392d"
                        : "2px solid transparent",
                      display: "grid",
                      gridTemplateColumns: "1fr auto",
                      gap: "16px",
                      alignItems: "start",
                      cursor: "pointer",
                      font: "inherit",
                    }}
                  >
                    <div>
                      <strong>
                        {getDateLabel(visit.visit_date)} ·{" "}
                        {getVisitTimeRange(visit)}
                      </strong>

                      <p style={{ margin: "8px 0 0", color: SECONDARY_TEXT }}>
                        Pflegekraft: {visit.team_member_name || "Noch offen"}
                      </p>

                      <p style={{ margin: "8px 0 0", color: "#153328" }}>
                        {getVisitServices(visit)}
                      </p>

                      {visit.notes && (
                        <p style={{ margin: "8px 0 0", color: SECONDARY_TEXT }}>
                          Notiz: {visit.notes}
                        </p>
                      )}
                    </div>

                    <span
                      style={{
                        borderRadius: "999px",
                        padding: "6px 12px",
                        fontSize: "12px",
                        fontWeight: 700,
                        whiteSpace: "nowrap",
                        ...getStatusStyles(visit.status),
                      }}
                    >
                      {getVisitStatusLabel(visit.status)}
                    </span>
                  </button>
                );
              })}

              {visits.length === 0 && (
                <div
                  style={{
                    background: "rgba(255,255,255,0.6)",
                    borderRadius: "18px",
                    padding: "16px",
                    border: "1px dashed rgba(21,51,40,0.18)",
                    color: SECONDARY_TEXT,
                  }}
                >
                  Noch keine Einsätze vorhanden.
                </div>
              )}
            </div>
          </section>

          <aside
            style={{
              background: "#16392d",
              color: "white",
              borderRadius: "24px",
              padding: "24px",
              minHeight: "320px",
              boxShadow: "0 16px 40px rgba(21,51,40,0.18)",
            }}
          >
            <p
              style={{
                fontSize: "12px",
                textTransform: "uppercase",
                letterSpacing: "0.08em",
                color: "rgba(255,255,255,0.7)",
                marginTop: 0,
              }}
            >
              Einsatz Detail
            </p>

            <CommandError message={commandError} />

            {selectedVisit ? (
              <>
                <h2 style={{ marginTop: "8px" }}>
                  {getDateLabel(selectedVisit.visit_date)}
                </h2>

                <p style={{ color: "rgba(255,255,255,0.75)" }}>
                  {getVisitTimeRange(selectedVisit)}
                </p>

                <DetailBox
                  label="Pflegekraft"
                  value={selectedVisit.team_member_name || "Noch offen"}
                />

                <DetailBox
                  label="Status"
                  value={getVisitStatusLabel(selectedVisit.status)}
                />

                <DetailBox
                  label="Leistungen"
                  value={getVisitServices(selectedVisit)}
                />

                <DetailBox
                  label="Notizen"
                  value={selectedVisit.notes || "Keine Notiz vorhanden"}
                />

                <DetailBox
                  label="Abrechenbar"
                  value={selectedVisit.billable ? "Ja" : "Nein"}
                />

                {selectedVisit.status === "planned" && (
                  <button
                    type="button"
                    onClick={handleStartVisit}
                    disabled={isUpdating}
                    style={{
                      width: "100%",
                      marginTop: "18px",
                      border: "none",
                      borderRadius: "999px",
                      padding: "14px 18px",
                      background: isUpdating ? "#9ca3af" : "white",
                      color: "#16392d",
                      fontWeight: 800,
                      cursor: isUpdating ? "not-allowed" : "pointer",
                    }}
                  >
                    {isUpdating ? "Starte Einsatz..." : "Einsatz starten"}
                  </button>
                )}

                {selectedVisit.status === "started" && (
                  <button
                    type="button"
                    onClick={handleCompleteVisit}
                    disabled={isUpdating}
                    style={{
                      width: "100%",
                      marginTop: "18px",
                      border: "none",
                      borderRadius: "999px",
                      padding: "14px 18px",
                      background: isUpdating ? "#9ca3af" : "white",
                      color: "#16392d",
                      fontWeight: 800,
                      cursor: isUpdating ? "not-allowed" : "pointer",
                    }}
                  >
                    {isUpdating ? "Schließe Einsatz ab..." : "Einsatz abschließen"}
                  </button>
                )}
              </>
            ) : (
              <p style={{ color: "rgba(255,255,255,0.75)" }}>
                Kein Einsatz vorhanden.
              </p>
            )}
          </aside>
        </section>
      </main>
    </div>
  );
}

function MetricCard({ label, value }: { label: string; value: number }) {
  return (
    <div
      style={{
        background: "white",
        borderRadius: "20px",
        padding: "20px",
        boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
      }}
    >
      <p style={{ margin: 0, color: SECONDARY_TEXT, fontSize: "14px" }}>
        {label}
      </p>
      <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>{value}</h2>
    </div>
  );
}

function DetailBox({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        background: "rgba(255,255,255,0.08)",
        borderRadius: "18px",
        padding: "16px",
        marginTop: "12px",
      }}
    >
      <strong>{label}</strong>
      <p style={{ color: "rgba(255,255,255,0.8)", marginBottom: 0 }}>
        {value}
      </p>
    </div>
  );
}
