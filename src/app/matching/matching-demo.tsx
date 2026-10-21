"use client";

import Sidebar from "@/components/layout/Sidebar";
import { useState } from "react";

const requests = [
  {
    id: "req-1",
    institution: "Spitex Bern Nord",
    station: "Ambulantes Team Nord",
    region: "Bern West",
    shift: "Frühdienst",
    date: "12.08.2026",
    urgency: "hoch",
    requiredSkills: ["Ambulante Pflege", "Demenz", "Führerschein"],
    requestedCount: 2,
    status: "Offen",
    coach: "Miriam Keller",
    notes: "Kurzfristige Unterdeckung wegen Ausfall im Frühdienst.",
  },
  {
    id: "req-2",
    institution: "Pflegezentrum Zürich See",
    station: "Übergangspflege",
    region: "Zürich Pilot",
    shift: "Spätdienst",
    date: "13.08.2026",
    urgency: "mittel",
    requiredSkills: ["Reha", "Dokumentation"],
    requestedCount: 1,
    status: "Matching läuft",
    coach: "Clara Meier",
    notes: "Patienten mit erhöhtem Koordinationsbedarf nach Austritt.",
  },
];

const teams = [
  {
    name: "Team Bern West A",
    region: "Bern West",
    skills: ["Ambulante Pflege", "Demenz", "Führerschein"],
    utilization: 92,
    openSlots: 0,
    status: "active",
    priority: false,
    coach: "Miriam Keller",
    distanceKm: 4,
  },
  {
    name: "Team Bern West B",
    region: "Bern West",
    skills: ["Ambulante Pflege", "Führerschein"],
    utilization: 78,
    openSlots: 1,
    status: "building",
    priority: true,
    coach: "Anita Hansen",
    distanceKm: 6,
  },
  {
    name: "Team Zürich 1",
    region: "Zürich Pilot",
    skills: ["Reha", "Dokumentation", "Ambulante Pflege"],
    utilization: 84,
    openSlots: 0,
    status: "active",
    priority: false,
    coach: "Clara Meier",
    distanceKm: 3,
  },
];
function calculateMatchScore(
  request: (typeof requests)[number],
  team: (typeof teams)[number]
) {
  let score = 0;

  const matchingSkills = request.requiredSkills.filter((skill) =>
    team.skills.includes(skill)
  ).length;

  const skillCoverage = request.requiredSkills.length
    ? matchingSkills / request.requiredSkills.length
    : 0;

  if (request.region === team.region) score += 30;
  score += Math.round(skillCoverage * 35);

  if (team.openSlots > 0) score += 15;
  if (team.utilization <= 85) score += 10;
  else if (team.utilization <= 92) score += 5;

  if (team.status === "active") score += 5;
  if (team.priority) score += 3;

  if (team.distanceKm <= 5) score += 7;
  else if (team.distanceKm <= 10) score += 3;

  return Math.min(score, 100);
}
function getMatchSignals(
  request: (typeof requests)[number],
  team: (typeof teams)[number]
) {
  const signals: string[] = [];

  const matchingSkills = request.requiredSkills.filter((skill) =>
    team.skills.includes(skill)
  ).length;

  if (request.region === team.region) signals.push("Region passt");
  if (matchingSkills >= Math.max(1, request.requiredSkills.length - 1)) {
    signals.push("Skills passen");
  } else if (matchingSkills > 0) {
    signals.push("Teilweise Skillfit");
  }

  if (team.openSlots > 0) signals.push("Kapazität vorhanden");
  if (team.priority) signals.push("Coach-Fokus");
  if (team.utilization >= 90) signals.push("Hohe Auslastung");

  return signals;
}
export default function MatchingDemo() {
  const [selectedRequestId, setSelectedRequestId] = useState(requests[0].id);
const selectedRequest =
  requests.find((request) => request.id === selectedRequestId) ?? requests[0];
  const selectedMatches = teams
  .map((team) => ({
    ...team,
    teamFit: calculateMatchScore(selectedRequest, team),
  }))
  .filter((team) => team.teamFit > 0)
  .sort((a, b) => b.teamFit - a.teamFit);

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
      <Sidebar active="matching" />

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
            Admin / Coach Portal
          </div>
          <h2 style={{ margin: 0, fontSize: "24px" }}>Matching-Übersicht</h2>
          <p style={{ color: "#5f766d", marginTop: "10px" }}>
            Offene Einsatzanfragen, passende Teams und nächste Matching-Aktionen.
          </p>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1.05fr 1.1fr 0.95fr",
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
            <h3 style={{ marginTop: 0 }}>Offene Einsatzanfragen</h3>

            {requests.map((request) => (
              <div
                key={request.id}
                onClick={() => setSelectedRequestId(request.id)}
                style={{
                  background: "white",
                  borderRadius: "18px",
                  padding: "16px",
                  marginBottom: "12px",
                  cursor: "pointer",
                  border:
                    request.id === selectedRequest.id
                      ? "2px solid #0f4333"
                      : "2px solid transparent",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    gap: "10px",
                    alignItems: "center",
                  }}
                >
                  <strong>{request.institution}</strong>
                  <span
                    style={{
                      display: "inline-block",
                      padding: "5px 10px",
                      borderRadius: "999px",
                      fontSize: "12px",
                      fontWeight: 700,
                      background:
                        request.urgency === "hoch"
                          ? "rgba(239,68,68,0.14)"
                          : "rgba(245,158,11,0.14)",
                      color: request.urgency === "hoch" ? "#b91c1c" : "#b45309",
                    }}
                  >
                    {request.urgency === "hoch" ? "Hoch" : "Mittel"}
                  </span>
                </div>

                <div style={{ color: "#5f766d", marginTop: "8px", fontSize: "14px" }}>
                  {request.station} · {request.region}
                </div>

                <div style={{ color: "#5f766d", marginTop: "6px", fontSize: "14px" }}>
                  {request.date} · {request.shift} · {request.requestedCount} Person(en)
                </div>

                <div style={{ marginTop: "10px", display: "flex", gap: "8px", flexWrap: "wrap" }}>
                  {request.requiredSkills.map((skill) => (
                    <span
                      key={skill}
                      style={{
                        fontSize: "12px",
                        padding: "5px 10px",
                        borderRadius: "999px",
                        background: "#edf2ef",
                        color: "#37554a",
                      }}
                    >
                      {skill}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>

          <div
            style={{
              background: "#dfe6e1",
              borderRadius: "24px",
              padding: "18px",
            }}
          >
<h3 style={{ marginTop: 0 }}>
  Passende Teams für {selectedRequest.institution}
</h3>
<div style={{ color: "#5f766d", fontSize: "14px", marginBottom: "14px" }}>
  {selectedRequest.station} · {selectedRequest.region} · {selectedRequest.date} · {selectedRequest.shift}
</div>
            {selectedMatches.map((team, index) => (
              <div
                key={team.name}
                style={{
                  background: "white",
                  borderRadius: "18px",
                  padding: "16px",
                  marginBottom: "12px",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    gap: "10px",
                    alignItems: "center",
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "8px", flexWrap: "wrap" }}>
  <strong>{team.name}</strong>
  {index === 0 && (
    <span
      style={{
        fontSize: "12px",
        padding: "5px 10px",
        borderRadius: "999px",
        background: "rgba(15,67,51,0.1)",
        color: "#0f4333",
        fontWeight: 700,
      }}
    >
      Top-Match
    </span>
  )}
</div>
                  <span
                    style={{
                      display: "inline-block",
                      padding: "5px 10px",
                      borderRadius: "999px",
                      fontSize: "12px",
                      fontWeight: 700,
                      background: "rgba(15,67,51,0.1)",
                      color: "#0f4333",
                    }}
                  >
                    Teamfit {team.teamFit}%
                  </span>
                </div>

                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "repeat(2, 1fr)",
                    gap: "8px",
                    marginTop: "12px",
                    color: "#5f766d",
                    fontSize: "14px",
                  }}
                >
                  <div>Region: {team.region}</div>
                  <div>Distanz: {team.distanceKm} km</div>
                  <div>Auslastung: {team.utilization}%</div>
                  <div>Offene Slots: {team.openSlots}</div>
                </div>

                <div
                  style={{
                    marginTop: "12px",
                    display: "flex",
                    gap: "8px",
                    flexWrap: "wrap",
                  }}
                >
                  <span
                    style={{
                      fontSize: "12px",
                      padding: "5px 10px",
                      borderRadius: "999px",
                      background:
                        team.status === "active"
                          ? "rgba(34,197,94,0.14)"
                          : "rgba(245,158,11,0.14)",
                      color: team.status === "active" ? "#15803d" : "#b45309",
                    }}
                  >
                    {team.status === "active" ? "Aktiv" : "Im Aufbau"}
                  </span>

                  <span
                    style={{
                      fontSize: "12px",
                      padding: "5px 10px",
                      borderRadius: "999px",
                      background: team.priority
                        ? "rgba(239,68,68,0.14)"
                        : "rgba(148,163,184,0.14)",
                      color: team.priority ? "#b91c1c" : "#475569",
                    }}
                  >
                    {team.priority ? "Coach-Fokus" : "Normal"}
                  </span>
                </div>
                <div
  style={{
    marginTop: "10px",
    display: "flex",
    gap: "8px",
    flexWrap: "wrap",
  }}
>
  {getMatchSignals(selectedRequest, team).map((signal) => (
    <span
      key={signal}
      style={{
        fontSize: "12px",
        padding: "5px 10px",
        borderRadius: "999px",
        background: "#edf2ef",
        color: "#37554a",
      }}
    >
      {signal}
    </span>
  ))}
</div>
              </div>
            ))}
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
              Match Detail
            </div>

            <h3 style={{ marginTop: 0, marginBottom: "10px" }}>
              {selectedRequest.institution}
            </h3>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
                marginBottom: "12px",
              }}
            >
              <strong>Status der Anfrage</strong>
              <div style={{ marginTop: "8px" }}>{selectedRequest.status}</div>
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
              <div style={{ marginTop: "8px" }}>{selectedRequest.coach}</div>
            </div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
                marginBottom: "12px",
              }}
            >
              <strong>Nächste Aktion</strong>
              <div style={{ marginTop: "8px" }}>Top-Match mit Institution bestätigen</div>
            </div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "16px",
                padding: "14px",
                marginBottom: "14px",
              }}
            >
              <strong>Notizen</strong>
              <div style={{ marginTop: "8px", lineHeight: 1.5 }}>{selectedRequest.notes}</div>
            </div>

            <div style={{ display: "grid", gap: "10px" }}>
              <button
                style={{
                  background: "white",
                  color: "#153328",
                  border: "none",
                  borderRadius: "999px",
                  padding: "12px 14px",
                  cursor: "pointer",
                  fontWeight: 600,
                }}
              >
                Anfrage an Team senden
              </button>

              <button
                style={{
                  background: "rgba(255,255,255,0.14)",
                  color: "white",
                  border: "1px solid rgba(255,255,255,0.18)",
                  borderRadius: "999px",
                  padding: "12px 14px",
                  cursor: "pointer",
                }}
              >
                Coach neu zuweisen
              </button>

              <button
                style={{
                  background: "rgba(255,255,255,0.14)",
                  color: "white",
                  border: "1px solid rgba(255,255,255,0.18)",
                  borderRadius: "999px",
                  padding: "12px 14px",
                  cursor: "pointer",
                }}
              >
                Als dringend markieren
              </button>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}