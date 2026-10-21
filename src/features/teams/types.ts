export type TeamStatus = "active" | "building" | "paused" | "closed";

export type TeamRow = {
  id: string;
  name: string;
  region: string | null;
  care_focus: string | null;
  status: TeamStatus | string | null;
  open_slots: number | null;
  utilization: number | null;
  lead_name: string | null;
  next_step: string | null;
  created_at: string;
  priority: boolean | null;
  coach_name: string | null;
};

export function getTeamStatusLabel(status: string | null) {
  if (status === "active") return "Aktiv";
  if (status === "building") return "Im Aufbau";
  if (status === "paused") return "Pausiert";
  if (status === "closed") return "Geschlossen";

  return "Unbekannt";
}

export function getTeamOpenSlotLabel(team: TeamRow) {
  const openSlots = team.open_slots ?? 0;

  if (openSlots === 0) return "Keine offenen Slots";
  if (openSlots === 1) return "1 offener Slot";

  return `${openSlots} offene Slots`;
}

export function getAverageUtilization(teams: TeamRow[]) {
  if (teams.length === 0) return 0;

  const total = teams.reduce((sum, team) => {
    return sum + (team.utilization ?? 0);
  }, 0);

  return Math.round(total / teams.length);
}

export function getActiveTeamsCount(teams: TeamRow[]) {
  return teams.filter((team) => team.status === "active").length;
}

export function getOpenSlotsCount(teams: TeamRow[]) {
  return teams.reduce((sum, team) => {
    return sum + (team.open_slots ?? 0);
  }, 0);
}
