"use client";

import { useState } from "react";
import SignalBanner from "@/components/signals/SignalBanner";
import EvaluatorHealthNotice from "@/components/signals/EvaluatorHealth";
import type { EvaluatorHealth, SignalRow } from "@/features/signals/rules";
import { AppFrame } from "@/components/layout/Sidebar";
import type { OperationsDashboard } from "@/features/operations/types";
import type { TeamRow } from "@/features/teams/types";
import ExceptionCenter from "./exception-center";
import HoldsPanel from "./holds-panel";
import ContinuityPanel from "./continuity-panel";
import CaseLifecyclePanel from "./case-lifecycle-panel";
import type { CaseLifecycle } from "@/features/lifecycle/queries";
import BillingPreview from "@/components/billing/billing-preview";
import type { BillingPreviewRow } from "@/features/billing/queries";
import type { ContinuityRow } from "@/features/team/queries";
import type { OpenHold } from "@/features/quality/queries";
import { SECONDARY_TEXT } from "@/lib/ui/colors";

// IPA1-1 (ADR-099): the case drill-down was reachable only from the removed client-ranked case panel.
type SelectedEntity = { type: "team"; id: string };

type OperationsClientProps = {
  dashboard: OperationsDashboard;
  holds: OpenHold[];
  continuity: ContinuityRow[];
  billing: BillingPreviewRow[];
  month: string;
  lifecycle: CaseLifecycle[];
  /** SIG1: P1 safety signals delivered to Operations (fallback or untaken). */
  signals?: SignalRow[];
  /** SIG2-11: the scheduled evaluator's health ("Signalprüfung läuft nicht"). */
  evaluator?: EvaluatorHealth[];
};

function getAverageUtilization(teams: TeamRow[]) {
  if (teams.length === 0) return 0;

  const total = teams.reduce((sum, team) => sum + (team.utilization ?? 0), 0);
  return Math.round(total / teams.length);
}

export default function OperationsClient({ dashboard, holds, continuity, billing, month, lifecycle, signals = [], evaluator = [] }: OperationsClientProps) {
  const { cases, teams } = dashboard;

  const [selectedEntity, setSelectedEntity] = useState<SelectedEntity | null>(null);

  // Counts of organisational facts (status, team assigned); no ranking or risk label (IPA1-1).
  const activeCases = cases.filter((item) => item.status === "laufend");
  const unassignedCases = cases.filter(
    (item) => !item.assigned_team_id && item.status !== "laufend"
  );

  const openSlots = teams.reduce((sum, team) => sum + (team.open_slots ?? 0), 0);
  const avgUtilization = getAverageUtilization(teams);

  // IPA1-1/-2 (ADR-099): no case is filtered or ranked here as a "risk", and no team gets a risk score.
  // Teams are listed by name; cases needing a decision come from the OPS1 server model (ExceptionCenter).
  const teamsByName = [...teams].sort((a, b) => (a.name ?? "").localeCompare(b.name ?? "", "de-CH"));

  return (
    <AppFrame
      active="operations"
      style={{
        background: "#F8FAF9",
        color: "#153328",
        fontFamily: "Inter, Segoe UI, sans-serif",
      }}
    >
      {/* UX1-1: one column below 768 px; the side column from 768 px (AppFrame). */}
      <main className="grid min-w-0 gap-4 p-4 md:p-6">
        <EvaluatorHealthNotice health={evaluator} />
        <SignalBanner initial={signals} />
        <Header
          activeCases={activeCases.length}
          openSlots={openSlots}
        />

        <ExecutiveKpis
          activeCases={activeCases.length}
          avgUtilization={avgUtilization}
          openSlots={openSlots}
          unassignedCases={unassignedCases.length}
          /* QG1: Operations sees serious events through the OPS1 exceptions, not the event table. */
          seriousQualityEvents={dashboard.exceptions.filter((e) => e.exception_type === "quality_serious_open").length}
        />

        <ExceptionCenter exceptions={dashboard.exceptions} />

        <HoldsPanel holds={holds} />

        <ContinuityPanel rows={continuity} />
        <CaseLifecyclePanel items={lifecycle} />

        <BillingPreview rows={billing} month={month} />

        {/* ADM1: the unvalidated prototype hints ("Weitere Hinweise") were removed; the OPS1 exception list above is the validated source. */}

        <section className="grid gap-4 lg:grid-cols-2">
          <TeamTable
            teams={teamsByName}
            onSelectTeam={(id) => setSelectedEntity({ type: "team", id })}
          />

          <UtilizationPanel teams={teamsByName} />
        </section>

        <ContextPanel selectedEntity={selectedEntity} teams={teams} />
      </main>
    </AppFrame>
  );
}

function Header({
  activeCases,
  openSlots,
}: {
  activeCases: number;
  openSlots: number;
}) {
  return (
    <header style={{ minHeight: "64px" }}>
      <p
        style={{
          margin: 0,
          fontSize: "12px",
          fontWeight: 800,
          letterSpacing: "0.08em",
          color: SECONDARY_TEXT,
          textTransform: "uppercase",
        }}
      >
        Operations
      </p>
      <h1 style={{ margin: "6px 0 0", fontSize: "32px", lineHeight: 1 }}>
        Navora Operations Control Tower
      </h1>
      <p style={{ margin: "8px 0 0", color: SECONDARY_TEXT }}>
        Stand: jetzt · {activeCases} laufende Klientenfälle · {openSlots} freie Pflegeslots
      </p>
    </header>
  );
}

function ExecutiveKpis({
  activeCases,
  avgUtilization,
  openSlots,
  unassignedCases,
  seriousQualityEvents,
}: {
  activeCases: number;
  avgUtilization: number;
  openSlots: number;
  unassignedCases: number;
  seriousQualityEvents: number;
}) {
  return (
    <section className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-5">
      <KpiCard label="Aktive Klientenfälle" value={activeCases} status="normal" context="laufende Versorgung" />
      <KpiCard
        label="Kapazitätsauslastung"
        value={`${avgUtilization}%`}
        status={avgUtilization > 90 ? "critical" : avgUtilization >= 80 ? "warning" : "normal"}
        context={avgUtilization > 90 ? "kritisch" : avgUtilization >= 80 ? "angespannt" : "stabil"}
      />
      <KpiCard
        label="Freie Pflegeslots"
        value={openSlots}
        status={openSlots < 5 ? "critical" : openSlots <= 10 ? "warning" : "normal"}
        context={openSlots < 5 ? "knapp" : "verfügbar"}
      />
      <KpiCard
        label="Offene Teamzuweisungen"
        value={unassignedCases}
        status={unassignedCases > 5 ? "critical" : unassignedCases >= 3 ? "warning" : "normal"}
        context="Klientenfälle ohne Team"
      />
      {/* IPA1-1 (ADR-099): the client-side "SLA-Verletzungen" age rule was removed; the OPS1 exceptions carry the server's thresholds. */}
      <KpiCard
        label="Schwere Qualitätsereignisse"
        value={seriousQualityEvents}
        status={seriousQualityEvents > 0 ? "warning" : "normal"}
        context="offen, aus den Ausnahmen"
      />
    </section>
  );
}

function KpiCard({
  label,
  value,
  status,
  context,
}: {
  label: string;
  value: string | number;
  status: "critical" | "warning" | "normal";
  context: string;
}) {
  const color =
    status === "critical"
      ? { top: "#DC2626", bg: "#FEF2F2", text: "#991B1B" }
      : status === "warning"
      ? { top: "#F59E0B", bg: "#FFFBEB", text: "#92400E" }
      : { top: "#22C55E", bg: "#F0FDF4", text: "#166534" };

  return (
    <div
      style={{
        background: "white",
        border: "1px solid #E5E7EB",
        borderRadius: "12px",
        overflow: "hidden",
        boxShadow: "0 1px 2px rgba(0,0,0,.05)",
      }}
    >
      <div style={{ height: "4px", background: color.top }} />
      <div style={{ padding: "16px" }}>
        <p style={{ margin: 0, color: SECONDARY_TEXT, fontSize: "13px" }}>{label}</p>
        <div style={{ marginTop: "8px", fontSize: "32px", fontWeight: 800 }}>
          {value}
        </div>
        <p style={{ margin: "6px 0 0", color: color.text, fontSize: "13px" }}>
          {context}
        </p>
      </div>
    </div>
  );
}

function TeamTable({
  teams,
  onSelectTeam,
}: {
  teams: TeamRow[];
  onSelectTeam: (id: string) => void;
}) {
  return (
    <section style={panelStyle} aria-label="Pflegeteams">
      <h2 style={sectionTitle}>Pflegeteams</h2>
      <p style={sectionSubtitle}>Alphabetisch, mit Auslastung und freien Slots.</p>

      {/* UX1-1: a wide table scrolls inside its panel, never the page. */}
      <div className="overflow-x-auto">
      <table style={{ width: "100%", borderCollapse: "collapse", marginTop: "12px" }}>
        <thead>
          <tr style={{ color: SECONDARY_TEXT, fontSize: "12px", textAlign: "left" }}>
            <th style={thStyle}>Pflegeteam</th>
            <th style={thStyle}>Auslastung</th>
            <th style={thStyle}>Slots</th>
            <th style={thStyle}>Status</th>
          </tr>
        </thead>
        <tbody>
          {teams.map((team) => {
            return (
              <tr
                key={team.id}
                onClick={() => onSelectTeam(team.id)}
                style={{
                  height: "48px",
                  borderTop: "1px solid #E5E7EB",
                  cursor: "pointer",
                }}
              >
                <td style={tdStyle}>{team.name}</td>
                <td style={tdStyle}>{team.utilization ?? 0}%</td>
                <td style={tdStyle}>{team.open_slots ?? 0}</td>
                <td style={tdStyle}>{team.status === "active" ? "Aktiv" : "Im Aufbau"}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
      </div>
    </section>
  );
}

function UtilizationPanel({ teams }: { teams: TeamRow[] }) {
  return (
    <section style={panelStyle} aria-label="Auslastung je Pflegeteam">
      <h2 style={sectionTitle}>Auslastung je Pflegeteam</h2>
      <p style={sectionSubtitle}>Belegte Kapazität und freie Slots.</p>

      <div style={{ display: "grid", gap: "12px", marginTop: "14px" }}>
        {teams.map((team) => {
          const utilization = team.utilization ?? 0;
          const status =
            utilization > 90 ? "critical" : utilization >= 80 ? "warning" : "normal";

          const color =
            status === "critical"
              ? "#DC2626"
              : status === "warning"
              ? "#F59E0B"
              : "#22C55E";

          return (
            <div key={team.id}>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  marginBottom: "5px",
                  fontSize: "13px",
                }}
              >
                <strong>{team.name}</strong>
                <span>{utilization}% · {team.open_slots ?? 0} Slots</span>
              </div>
              <div
                style={{
                  height: "12px",
                  borderRadius: "999px",
                  background: "#E5E7EB",
                  overflow: "hidden",
                }}
              >
                <div
                  style={{
                    height: "100%",
                    width: `${Math.min(utilization, 100)}%`,
                    background: color,
                    borderRadius: "999px",
                  }}
                />
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function ContextPanel({
  selectedEntity,
  teams,
}: {
  selectedEntity: SelectedEntity | null;
  teams: TeamRow[];
}) {
  if (!selectedEntity) {
    return (
      <section style={panelStyle}>
        <h2 style={sectionTitle}>Drilldown</h2>
        <p style={sectionSubtitle}>Wähle ein Pflegeteam aus.</p>
      </section>
    );
  }

  const team = teams.find((item) => item.id === selectedEntity.id);

  if (!team) return null;

  return (
    <section style={panelStyle}>
      <h2 style={sectionTitle}>Pflegeteam Detail</h2>
      <StatusPill label="Pflegeteam" tone="info" />
      <h3>{team.name}</h3>
      <p>{team.region ?? "Region offen"}</p>
      <p><strong>Auslastung:</strong> {team.utilization ?? 0}%</p>
      <p><strong>Freie Slots:</strong> {team.open_slots ?? 0}</p>
      <p><strong>Coach:</strong> {team.coach_name || "Noch offen"}</p>
    </section>
  );
}

function StatusPill({
  label,
  tone,
}: {
  label: string;
  tone: "critical" | "warning" | "normal" | "info";
}) {
  const color =
    tone === "critical"
      ? { bg: "#FEF2F2", text: "#991B1B", border: "#FCA5A5" }
      : tone === "warning"
      ? { bg: "#FFFBEB", text: "#92400E", border: "#FCD34D" }
      : tone === "normal"
      ? { bg: "#F0FDF4", text: "#166534", border: "#86EFAC" }
      : { bg: "#F3F4F6", text: "#374151", border: "#E5E7EB" };

  return (
    <span
      style={{
        display: "inline-flex",
        width: "fit-content",
        borderRadius: "999px",
        padding: "4px 8px",
        background: color.bg,
        color: color.text,
        border: `1px solid ${color.border}`,
        fontSize: "12px",
        fontWeight: 800,
      }}
    >
      {label}
    </span>
  );
}

const panelStyle = {
  background: "white",
  border: "1px solid #E5E7EB",
  borderRadius: "12px",
  padding: "16px",
  boxShadow: "0 1px 2px rgba(0,0,0,.05)",
};

const sectionTitle = {
  margin: 0,
  fontSize: "20px",
  fontWeight: 700,
};

const sectionSubtitle = {
  margin: "6px 0 0",
  color: SECONDARY_TEXT,
  fontSize: "14px",
};

const thStyle = {
  padding: "8px",
  fontWeight: 700,
};

const tdStyle = {
  padding: "8px",
};
