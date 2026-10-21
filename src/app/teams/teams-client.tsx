"use client";
import Sidebar from "@/components/layout/Sidebar";

import { useMemo, useState } from "react";
import type { TeamRow } from "@/features/teams/types";
import { supabase } from "../../lib/supabase";

type Team = TeamRow;

type TeamsClientProps = {
  teams: Team[];
};

export default function TeamsClient({ teams }: TeamsClientProps) {
  const [selectedRegion, setSelectedRegion] = useState<string>("Alle Regionen");
const [selectedTeamId, setSelectedTeamId] = useState<string | null>(teams[0]?.id ?? null);
const [coachInput, setCoachInput] = useState("");
const [teamsState, setTeamsState] = useState(teams);

  const regions = useMemo(() => {
    const uniqueRegions = Array.from(new Set(teamsState.map((team) => team.region)));
    return ["Alle Regionen", ...uniqueRegions];
  }, [teamsState]);

  const filteredTeams = useMemo(() => {
    if (selectedRegion === "Alle Regionen") return teamsState;
    return teamsState.filter((team) => team.region === selectedRegion);
  }, [teamsState, selectedRegion]);

  const bernTeams = filteredTeams.filter((team) => team.region === "Bern West");
  const zurichTeams = filteredTeams.filter((team) => team.region === "Zürich Pilot");

  const selectedTeam =
    filteredTeams.find((team) => team.id === selectedTeamId) ??
    filteredTeams[0] ??
    teamsState[0];

  const activeTeams = filteredTeams.filter((team) => team.status === "active").length;
  const totalOpenSlots = filteredTeams.reduce((sum, team) => sum + (team.open_slots ?? 0), 0);
  const avgUtilization = filteredTeams.length
    ? Math.round(
        filteredTeams.reduce((sum, team) => sum + (team.utilization ?? 0), 0) /
          filteredTeams.length
      )
    : 0;
    async function handleTogglePriority() {
  if (!selectedTeam) return;

  const newPriority = !selectedTeam.priority;

  const { error } = await supabase
    .from("teams")
    .update({ priority: newPriority })
    .eq("id", selectedTeam.id);

  if (error) {
    console.error("Priority update failed:", error);
    return;
  }

  setTeamsState((prev) =>
  prev.map((team) =>
    team.id === selectedTeam.id
      ? { ...team, priority: newPriority }
      : team
  )
);
}
async function handleAssignCoach() {
  if (!selectedTeam) return;
  if (!coachInput.trim()) return;

  const { error } = await supabase
    .from("teams")
    .update({ coach_name: coachInput.trim() })
    .eq("id", selectedTeam.id);

  if (error) {
    console.error("Coach update failed:", error);
    return;
  }

setTeamsState((prev) =>
  prev.map((team) =>
    team.id === selectedTeam.id
      ? { ...team, coach_name: coachInput.trim() }
      : team
  )
);
setCoachInput("");
}
  const renderTeamCard = (team: Team) => {
    const isSelected = selectedTeam?.id === team.id;

    return (
      <button
        key={team.id}
        onClick={() => setSelectedTeamId(team.id)}
        style={{
          background: "white",
          borderRadius: "16px",
          padding: "14px",
          marginBottom: "12px",
          border: isSelected ? "2px solid #0f4333" : "2px solid transparent",
          textAlign: "left",
          cursor: "pointer",
          width: "100%",
        }}
      >
        <strong>{team.name}</strong>
        <div style={{ color: "#5f766d", marginTop: "6px" }}>
          {team.open_slots === 0
            ? `Auslastung ${team.utilization}%`
            : `${team.open_slots} offener Slot`}
        </div>
      </button>
    );
  };

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
      <Sidebar active="teams" />

      <main style={{ padding: "32px" }}>
        <div style={{ marginBottom: "28px" }}>
          <div
            style={{
              fontSize: "12px",
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              color: "#6d857c",
              marginBottom: "10px",
            }}
          >
            Teams Übersicht
          </div>
          <h2 style={{ margin: 0, fontSize: "24px" }}>Teams Übersicht</h2>
          <p style={{ color: "#5f766d", marginTop: "10px" }}>
            Regionale Übersicht über Teamstatus, offene Slots und Koordinationsbedarf.
          </p>
        </div>

        <div
          style={{
            display: "flex",
            gap: "12px",
            marginBottom: "20px",
            alignItems: "center",
            flexWrap: "wrap",
          }}
        >
          <div style={{ fontSize: "14px", color: "#5f766d" }}>Region filtern:</div>
          {regions.map((region) => {
            const isActive = selectedRegion === region;
            return (
              <button
                key={region}
                onClick={() => setSelectedRegion(region ?? "Alle Regionen")}
                style={{
                  background: isActive ? "#16392d" : "white",
                  color: isActive ? "white" : "#153328",
                  border: "1px solid #d8e0db",
                  borderRadius: "999px",
                  padding: "10px 14px",
                  cursor: "pointer",
                }}
              >
                {region}
              </button>
            );
          })}
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, 1fr)",
            gap: "14px",
            marginBottom: "22px",
          }}
        >
          <div style={{ background: "white", borderRadius: "18px", padding: "18px" }}>
            <div style={{ color: "#6d857c", fontSize: "14px" }}>Aktive Teams</div>
            <div style={{ fontSize: "36px", marginTop: "8px" }}>{activeTeams}</div>
          </div>

          <div style={{ background: "white", borderRadius: "18px", padding: "18px" }}>
            <div style={{ color: "#6d857c", fontSize: "14px" }}>Offene Slots</div>
            <div style={{ fontSize: "36px", marginTop: "8px" }}>{totalOpenSlots}</div>
          </div>

          <div style={{ background: "white", borderRadius: "18px", padding: "18px" }}>
            <div style={{ color: "#6d857c", fontSize: "14px" }}>Ø Auslastung</div>
            <div style={{ fontSize: "36px", marginTop: "8px" }}>{avgUtilization}%</div>
          </div>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1.2fr 1fr",
            gap: "16px",
          }}
        >
          <div
            style={{
              background: "#dfe6e1",
              borderRadius: "24px",
              padding: "18px",
            }}
          >
            {bernTeams.length > 0 && (
              <>
                <h3 style={{ marginTop: 0 }}>Bern West</h3>
                {bernTeams.map(renderTeamCard)}
              </>
            )}

            {zurichTeams.length > 0 && (
              <>
                <h3 style={{ marginTop: bernTeams.length > 0 ? "20px" : 0 }}>Zürich Pilot</h3>
                {zurichTeams.map(renderTeamCard)}
              </>
            )}

            {filteredTeams.length === 0 && (
              <div style={{ color: "#5f766d" }}>Keine Teams in dieser Region gefunden.</div>
            )}
          </div>

          <div
            style={{
              background: "#0f4333",
              color: "white",
              borderRadius: "24px",
              padding: "20px",
            }}
          >
            <div
              style={{
                fontSize: "12px",
                textTransform: "uppercase",
                letterSpacing: "0.08em",
                opacity: 0.75,
                marginBottom: "12px",
              }}
            >
              Team Detail
            </div>

            <h3 style={{ marginTop: 0, marginBottom: "10px" }}>{selectedTeam?.name}</h3>

            <div
              style={{
                display: "flex",
                gap: "10px",
                flexWrap: "wrap",
                marginBottom: "14px",
              }}
            >
              <button
                style={{
                  background: "white",
                  color: "#153328",
                  border: "none",
                  borderRadius: "999px",
                  padding: "10px 14px",
                  cursor: "pointer",
                }}
              >
                Team öffnen
              </button>
              <button
                style={{
                  background: "rgba(255,255,255,0.14)",
                  color: "white",
                  border: "1px solid rgba(255,255,255,0.18)",
                  borderRadius: "999px",
                  padding: "10px 14px",
                  cursor: "pointer",
                }}
              >
                Anfrage senden
              </button>
             <div style={{ display: "flex", gap: "8px", alignItems: "center", flexWrap: "wrap" }}>
  <input
    type="text"
    value={coachInput}
    onChange={(e) => setCoachInput(e.target.value)}
    placeholder="Coach-Name eingeben"
    style={{
      background: "white",
      color: "#153328",
      border: "none",
      borderRadius: "999px",
      padding: "10px 14px",
      minWidth: "180px",
      outline: "none",
    }}
  />
  <button
    onClick={handleAssignCoach}
    style={{
      background: "rgba(255,255,255,0.14)",
      color: "white",
      border: "1px solid rgba(255,255,255,0.18)",
      borderRadius: "999px",
      padding: "10px 14px",
      cursor: "pointer",
    }}
  >
    Coach zuweisen
  </button>
</div>
              <button
              onClick={handleTogglePriority}
                style={{
                  background: "rgba(255,255,255,0.14)",
                  color: "white",
                  border: "1px solid rgba(255,255,255,0.18)",
                  borderRadius: "999px",
                  padding: "10px 14px",
                  cursor: "pointer",
                }}
              >
                Coach-Fokus setzen
              </button>
            </div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
                marginBottom: "12px",
              }}
            >
              <strong>Leitung</strong>
              <div style={{ marginTop: "6px" }}>{selectedTeam?.lead_name}</div>
            </div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
                marginBottom: "12px",
              }}
            >
              <strong>Offen</strong>
              <div style={{ marginTop: "6px" }}>
                {selectedTeam?.open_slots
                  ? `${selectedTeam.open_slots} offener Slot`
                  : "Keine offenen Slots"}
              </div>
            </div>
            <div
  style={{
    background: "rgba(255,255,255,0.08)",
    borderRadius: "16px",
    padding: "14px",
    marginBottom: "12px",
  }}
>
  <strong>Status</strong>
  <div style={{ marginTop: "10px" }}>
    <span
      style={{
        display: "inline-block",
        padding: "6px 12px",
        borderRadius: "999px",
        fontSize: "13px",
        fontWeight: 600,
        background:
          selectedTeam?.status === "active"
            ? "rgba(34,197,94,0.18)"
            : "rgba(245,158,11,0.18)",
        color: selectedTeam?.status === "active" ? "#bbf7d0" : "#fde68a",
        border:
          selectedTeam?.status === "active"
            ? "1px solid rgba(34,197,94,0.32)"
            : "1px solid rgba(245,158,11,0.32)",
      }}
    >
      {selectedTeam?.status === "active" ? "Aktiv" : "Im Aufbau"}
    </span>
  </div>
</div>
            <div
  style={{
    background: "rgba(255,255,255,0.08)",
    borderRadius: "16px",
    padding: "14px",
    marginBottom: "12px",
  }}
>
  <strong>Coach-Fokus</strong>
  <div style={{ marginTop: "10px" }}>
  <span
    style={{
      display: "inline-block",
      padding: "6px 12px",
      borderRadius: "999px",
      fontSize: "13px",
      fontWeight: 600,
      background: selectedTeam?.priority
        ? "rgba(239,68,68,0.18)"
        : "rgba(148,163,184,0.18)",
      color: selectedTeam?.priority ? "#fecaca" : "#cbd5e1",
      border: selectedTeam?.priority
        ? "1px solid rgba(239,68,68,0.32)"
        : "1px solid rgba(148,163,184,0.32)",
    }}
  >
    {selectedTeam?.priority ? "Aktiv" : "Normal"}
  </span>
</div>
</div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
                marginBottom: "12px",
              }}
            >
               <strong>Coach</strong>
  <div style={{ marginTop: "6px" }}>
    {(selectedTeam as any)?.coach_name ?? "Noch nicht zugewiesen"}
  </div>
</div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
              }}
            >
              <strong>Nächster Schritt</strong>
              <div style={{ marginTop: "6px" }}>{selectedTeam?.next_step}</div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}