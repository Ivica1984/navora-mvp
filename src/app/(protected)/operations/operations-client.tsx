"use client";

import { useMemo, useState } from "react";
import SignalBanner from "@/components/signals/SignalBanner";
import EvaluatorHealthNotice from "@/components/signals/EvaluatorHealth";
import type { EvaluatorHealth, SignalRow } from "@/features/signals/rules";
import Sidebar from "@/components/layout/Sidebar";
import type {
  OperationsDashboard,
  OperationsVisit,
} from "@/features/operations/types";
import {
  getCaseDisplayName,
  getCaseNeedSummary,
  getCaseRegion,
  type CaseSummaryRow,
} from "@/features/cases/types";
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

type LocalVisit = OperationsVisit;

type CaseWithRelations = CaseSummaryRow & {
  care_visits?: LocalVisit[];
  pflegeteam?: TeamRow | null;
};

type SelectedEntity =
  | { type: "case"; id: string }
  | { type: "team"; id: string }
  | { type: "visit"; id: string };

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

function getStatusLabel(status: string | null) {
  if (status === "neu") return "Neuaufnahme";
  if (status === "teampruefung") return "Teamentscheid";
  if (status === "laufend") return "Laufende Versorgung";
  return "Unbekannt";
}

function getResponsibleTeam(careCase: CaseWithRelations) {
  if (careCase.pflegeteam?.name) return careCase.pflegeteam.name;
  if (careCase.assigned_team) return careCase.assigned_team;
  return "Noch kein Pflegeteam";
}

function getAverageUtilization(teams: TeamRow[]) {
  if (teams.length === 0) return 0;

  const total = teams.reduce((sum, team) => sum + (team.utilization ?? 0), 0);
  return Math.round(total / teams.length);
}

function getRiskColor(score: number) {
  if (score >= 70) {
    return {
      label: "Kritisch",
      bg: "#FEF2F2",
      text: "#991B1B",
      border: "#FCA5A5",
      dot: "🔴",
    };
  }

  if (score >= 40) {
    return {
      label: "Aufmerksamkeit",
      bg: "#FFFBEB",
      text: "#92400E",
      border: "#FCD34D",
      dot: "🟠",
    };
  }

  return {
    label: "Normal",
    bg: "#F0FDF4",
    text: "#166534",
    border: "#86EFAC",
    dot: "🟢",
  };
}

function getTeamRiskScore(team: TeamRow) {
  let score = 0;

  const utilization = team.utilization ?? 0;
  const openSlots = team.open_slots ?? 0;

  if (utilization >= 95) score += 45;
  else if (utilization >= 90) score += 35;
  else if (utilization >= 80) score += 20;

  if (openSlots === 0) score += 25;
  else if (openSlots <= 2) score += 10;

  if (team.priority) score += 15;

  if (team.status !== "active") score += 10;

  return Math.min(score, 100);
}

function getCaseAgeHours(careCase: CaseSummaryRow) {
  const created = new Date(careCase.created_at).getTime();
  const now = Date.now();

  return Math.max(0, Math.floor((now - created) / (1000 * 60 * 60)));
}

function getSlaStatus(careCase: CaseSummaryRow) {
  const age = getCaseAgeHours(careCase);
  const assignedTeamId = careCase.assigned_team_id;

  if (!assignedTeamId && age > 48) return "violated";
  if (!assignedTeamId && age > 24) return "risk";
  return "ok";
}

export default function OperationsClient({ dashboard, holds, continuity, billing, month, lifecycle, signals = [], evaluator = [] }: OperationsClientProps) {
  const {
    cases,
    teams,
    visits,
  } = dashboard;

  const typedVisits: LocalVisit[] = visits;

  const enrichedCases = useMemo<CaseWithRelations[]>(() => {
    return cases.map((careCase) => {
      const assignedTeamId = careCase.assigned_team_id;

      return {
        ...careCase,
        care_visits: typedVisits.filter((visit) => visit.case_id === careCase.id),
        pflegeteam: teams.find((team) => team.id === assignedTeamId) ?? null,
      };
    });
  }, [cases, typedVisits, teams]);

  const [selectedEntity, setSelectedEntity] = useState<SelectedEntity | null>(null);

  const activeCases = enrichedCases.filter((item) => item.status === "laufend");
  const unassignedCases = enrichedCases.filter(
    (item) => !item.assigned_team_id && item.status !== "laufend"
  );

  const openSlots = teams.reduce((sum, team) => sum + (team.open_slots ?? 0), 0);
  const avgUtilization = getAverageUtilization(teams);

  const slaViolatedCases = enrichedCases.filter(
    (item) => getSlaStatus(item) === "violated"
  );

  const teamsByRisk = [...teams]
    .map((team) => ({
      team,
      risk: getTeamRiskScore(team),
    }))
    .sort((a, b) => b.risk - a.risk);

  const riskCases = enrichedCases
    .filter((careCase) => {
      const sla = getSlaStatus(careCase);
      const assignedTeamId = careCase.assigned_team_id;

      return (
        sla !== "ok" ||
        !assignedTeamId ||
        careCase.status === "teampruefung" ||
        careCase.urgency === "hoch"
      );
    })
    .sort((a, b) => getCaseAgeHours(b) - getCaseAgeHours(a))
    .slice(0, 8);

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        gridTemplateColumns: "240px 1fr",
        background: "#F8FAF9",
        color: "#153328",
        fontFamily: "Inter, Segoe UI, sans-serif",
      }}
    >
      <Sidebar active="operations" />

      <main style={{ padding: "24px", display: "grid", gap: "16px" }}>
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
          slaViolations={slaViolatedCases.length}
          /* QG1: Operations sees serious events through the OPS1 exceptions, not the event table. */
          qualityRisks={dashboard.exceptions.filter((e) => e.exception_type === "quality_serious_open").length}
        />

        <ExceptionCenter exceptions={dashboard.exceptions} />

        <HoldsPanel holds={holds} />

        <ContinuityPanel rows={continuity} />
        <CaseLifecyclePanel items={lifecycle} />

        <BillingPreview rows={billing} month={month} />

        {/* ADM1: the unvalidated prototype hints ("Weitere Hinweise") were removed; the OPS1 exception list above is the validated source. */}

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "16px",
          }}
        >
          <TeamHealthTable
            teamsByRisk={teamsByRisk}
            onSelectTeam={(id) => setSelectedEntity({ type: "team", id })}
          />

          <CapacityMonitor teamsByRisk={teamsByRisk} />
        </section>

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "0.9fr 1.1fr 1fr",
            gap: "16px",
          }}
        >
          <SlaMonitor cases={enrichedCases} />

          <RiskCases
            cases={riskCases}
            onSelectCase={(id) => setSelectedEntity({ type: "case", id })}
          />

          <ContextPanel
            selectedEntity={selectedEntity}
            cases={enrichedCases}
            teams={teams}
          />
        </section>
      </main>
    </div>
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
    <header style={{ height: "64px" }}>
      <p
        style={{
          margin: 0,
          fontSize: "12px",
          fontWeight: 800,
          letterSpacing: "0.08em",
          color: "#6B7280",
          textTransform: "uppercase",
        }}
      >
        Operations
      </p>
      <h1 style={{ margin: "6px 0 0", fontSize: "32px", lineHeight: 1 }}>
        Navora Operations Control Tower
      </h1>
      <p style={{ margin: "8px 0 0", color: "#6B7280" }}>
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
  slaViolations,
  qualityRisks,
}: {
  activeCases: number;
  avgUtilization: number;
  openSlots: number;
  unassignedCases: number;
  slaViolations: number;
  qualityRisks: number;
}) {
  return (
    <section
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(6, minmax(0, 1fr))",
        gap: "16px",
      }}
    >
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
      <KpiCard
        label="SLA-Verletzungen"
        value={slaViolations}
        status={slaViolations > 0 ? "critical" : "normal"}
        context="Intake / Teamzuweisung"
      />
      <KpiCard
        label="Qualitätsrisiken"
        value={qualityRisks}
        status={qualityRisks > 2 ? "critical" : qualityRisks > 0 ? "warning" : "normal"}
        context="offene Ereignisse"
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
        <p style={{ margin: 0, color: "#6B7280", fontSize: "13px" }}>{label}</p>
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

function TeamHealthTable({
  teamsByRisk,
  onSelectTeam,
}: {
  teamsByRisk: { team: TeamRow; risk: number }[];
  onSelectTeam: (id: string) => void;
}) {
  return (
    <section style={panelStyle}>
      <h2 style={sectionTitle}>Team Health</h2>
      <p style={sectionSubtitle}>Nach Risiko sortiert, nicht alphabetisch.</p>

      <table style={{ width: "100%", borderCollapse: "collapse", marginTop: "12px" }}>
        <thead>
          <tr style={{ color: "#6B7280", fontSize: "12px", textAlign: "left" }}>
            <th style={thStyle}>Pflegeteam</th>
            <th style={thStyle}>Risk</th>
            <th style={thStyle}>Auslastung</th>
            <th style={thStyle}>Slots</th>
            <th style={thStyle}>Status</th>
          </tr>
        </thead>
        <tbody>
          {teamsByRisk.map(({ team, risk }) => {
            const color = getRiskColor(risk);

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
                <td style={tdStyle}>
                  <span
                    style={{
                      background: color.bg,
                      color: color.text,
                      border: `1px solid ${color.border}`,
                      borderRadius: "999px",
                      padding: "4px 8px",
                      fontWeight: 800,
                      fontSize: "12px",
                    }}
                  >
                    {color.dot} {risk}
                  </span>
                </td>
                <td style={tdStyle}>{team.utilization ?? 0}%</td>
                <td style={tdStyle}>{team.open_slots ?? 0}</td>
                <td style={tdStyle}>{team.status === "active" ? "Aktiv" : "Im Aufbau"}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </section>
  );
}

function CapacityMonitor({
  teamsByRisk,
}: {
  teamsByRisk: { team: TeamRow; risk: number }[];
}) {
  return (
    <section style={panelStyle}>
      <h2 style={sectionTitle}>Kapazitätsmonitor</h2>
      <p style={sectionSubtitle}>Auslastung je Pflegeteam.</p>

      <div style={{ display: "grid", gap: "12px", marginTop: "14px" }}>
        {teamsByRisk.map(({ team }) => {
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

function SlaMonitor({ cases }: { cases: CaseWithRelations[] }) {
  const violated = cases.filter((item) => getSlaStatus(item) === "violated").length;
  const risk = cases.filter((item) => getSlaStatus(item) === "risk").length;
  const ok = cases.filter((item) => getSlaStatus(item) === "ok").length;

  return (
    <section style={panelStyle}>
      <h2 style={sectionTitle}>SLA Monitor</h2>
      <p style={sectionSubtitle}>Teamzuweisung / Intake Aging.</p>

      <div style={{ display: "grid", gap: "10px", marginTop: "14px" }}>
        <SlaRow label=">48h verletzt" value={violated} tone="critical" />
        <SlaRow label="24–48h gefährdet" value={risk} tone="warning" />
        <SlaRow label="<24h innerhalb SLA" value={ok} tone="normal" />
      </div>
    </section>
  );
}

function SlaRow({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: "critical" | "warning" | "normal";
}) {
  const color =
    tone === "critical" ? "#DC2626" : tone === "warning" ? "#F59E0B" : "#22C55E";

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", fontSize: "13px" }}>
        <span>{label}</span>
        <strong>{value}</strong>
      </div>
      <div style={{ height: "10px", background: "#E5E7EB", borderRadius: "999px", marginTop: "5px" }}>
        <div
          style={{
            height: "100%",
            width: `${Math.min(value * 20, 100)}%`,
            background: color,
            borderRadius: "999px",
          }}
        />
      </div>
    </div>
  );
}

function RiskCases({
  cases,
  onSelectCase,
}: {
  cases: CaseWithRelations[];
  onSelectCase: (id: string) => void;
}) {
  return (
    <section style={panelStyle}>
      <h2 style={sectionTitle}>Top Risiko-Fälle</h2>
      <p style={sectionSubtitle}>Nur Fälle mit Handlungsbedarf.</p>

      <div style={{ display: "grid", gap: "8px", marginTop: "12px" }}>
        {cases.length === 0 && <p style={{ color: "#166534" }}>Keine Risikofälle.</p>}

        {cases.map((careCase) => {
          const sla = getSlaStatus(careCase);
          const age = getCaseAgeHours(careCase);

          return (
            <button
              key={careCase.id}
              type="button"
              onClick={() => onSelectCase(careCase.id)}
              style={{
                textAlign: "left",
                background: sla === "violated" ? "#FEF2F2" : sla === "risk" ? "#FFFBEB" : "white",
                border:
                  sla === "violated"
                    ? "1px solid #FCA5A5"
                    : sla === "risk"
                    ? "1px solid #FCD34D"
                    : "1px solid #E5E7EB",
                borderRadius: "12px",
                padding: "10px",
                cursor: "pointer",
                font: "inherit",
              }}
            >
              <strong>{getCaseDisplayName(careCase)}</strong>
              <p style={{ margin: "4px 0 0", color: "#6B7280" }}>
                {getStatusLabel(careCase.status)} · {age}h offen · {getResponsibleTeam(careCase)}
              </p>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function ContextPanel({
  selectedEntity,
  cases,
  teams,
}: {
  selectedEntity: SelectedEntity | null;
  cases: CaseWithRelations[];
  teams: TeamRow[];
}) {
  if (!selectedEntity) {
    return (
      <section style={panelStyle}>
        <h2 style={sectionTitle}>Drilldown</h2>
        <p style={sectionSubtitle}>Wähle ein Element aus.</p>
      </section>
    );
  }

  if (selectedEntity.type === "case") {
    const careCase = cases.find((item) => item.id === selectedEntity.id);

    if (!careCase) return null;

    return (
      <section style={panelStyle}>
        <h2 style={sectionTitle}>Klientenfall Detail</h2>
        <StatusPill label="Klient / Fall" tone="info" />
        <h3>{getCaseDisplayName(careCase)}</h3>
        <p>{getCaseRegion(careCase)} · {getStatusLabel(careCase.status)}</p>
        <p><strong>Pflegeteam:</strong> {getResponsibleTeam(careCase)}</p>
        <p><strong>Bedarf:</strong> {getCaseNeedSummary(careCase)}</p>
      </section>
    );
  }

  if (selectedEntity.type === "team") {
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

  return (
    <section style={panelStyle}>
      <h2 style={sectionTitle}>Drilldown</h2>
      <p>Detail für dieses Objekt wird als nächstes erweitert.</p>
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
  color: "#6B7280",
  fontSize: "14px",
};

const thStyle = {
  padding: "8px",
  fontWeight: 700,
};

const tdStyle = {
  padding: "8px",
};
