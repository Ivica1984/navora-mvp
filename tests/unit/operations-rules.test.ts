// Pins the IMPLEMENTED (legacy) attention thresholds from the recovered code.
// These tests describe current behaviour, not validated product rules
// (DOMAIN_RULES "Operations Attention"). A failing test after an intentional
// rule change is expected — update the test together with the decision record.
import { describe, expect, it } from "vitest";
import { buildAttentionItems, getHoursSince } from "@/features/operations/rules";
import type { CaseRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import type { CareVisitRow } from "@/features/visits/types";
import type {
  CareNoteRow,
  PartnerRequestRow,
  QualityEventRow,
} from "@/features/operations/types";

const NOW = Date.parse("2026-10-21T12:00:00Z");
const hoursAgo = (h: number) => new Date(NOW - h * 3_600_000).toISOString();

function team(overrides: Partial<TeamRow>): TeamRow {
  return {
    id: "t",
    name: "Testteam",
    region: "Testregion",
    care_focus: null,
    status: "active",
    open_slots: 5,
    utilization: 50,
    lead_name: null,
    next_step: null,
    created_at: hoursAgo(1000),
    priority: false,
    coach_name: null,
    ...overrides,
  };
}

function careCase(overrides: Partial<CaseRow>): CaseRow {
  return {
    id: "c",
    created_at: hoursAgo(1),
    name: "Testfall",
    region: "Testregion",
    status: "neu",
    bedarf: null,
    urgency: "mittel",
    time_info: null,
    first_name: "Testfall",
    last_name: "01",
    date_of_birth: null,
    gender: null,
    address: null,
    plz: null,
    ort: null,
    phone: null,
    emergency_contact_name: null,
    emergency_contact_phone: null,
    mobility_status: null,
    cognitive_status: null,
    diagnosis_tags: null,
    care_needs: null,
    care_level: null,
    referral_source: null,
    insurance_provider: null,
    start_date: null,
    next_step: null,
    notes: null,
    assigned_team: null,
    assigned_team_id: "t",
    intake_consent_confirmed_at: null,
    intake_consent_confirmed_by: null,
    // J1 (PO changes): funding facts and readiness
    source_partner_request_id: null,
    residence_municipality: null,
    residence_canton: null,
    insurer_name: null,
    insurance_type: null,
    medical_order_status: null,
    medical_order_valid_until: null,
    gp_named: null,
    other_providers_active: null,
    requested_start: null,
    language_notes: null,
    access_notes: null,
    ready_for_matching_at: null,
    ...overrides,
  };
}

function partner(overrides: Partial<PartnerRequestRow>): PartnerRequestRow {
  return {
    id: "p",
    created_at: hoursAgo(1),
    partner_name: "Testpartner",
    partner_type: null,
    region: "Testregion",
    city: null,
    urgency: "mittel",
    time_info: null,
    request_title: "Test",
    need_summary: "Synthetisch",
    requested_services: null,
    status: "open",
    converted_case_id: null,
    notes: null,
    ...overrides,
  };
}

function visit(overrides: Partial<CareVisitRow>): CareVisitRow {
  return {
    id: "v",
    case_id: "c",
    visit_date: "2026-10-20",
    time_start: "08:00",
    time_end: "08:30",
    team_member_name: "Pflegekraft Test",
    services_provided: null,
    notes: null,
    billable: false,
    status: "completed",
    created_at: hoursAgo(30),
    ...overrides,
  };
}

function note(overrides: Partial<CareNoteRow>): CareNoteRow {
  return {
    id: "n",
    created_at: hoursAgo(20),
    visit_id: "v",
    case_id: "c",
    team_id: "t",
    author_name: null,
    note_type: "visit_report",
    content: "Synthetisch",
    status: "approved",
    ...overrides,
  };
}

function quality(overrides: Partial<QualityEventRow>): QualityEventRow {
  return {
    id: "q",
    created_at: hoursAgo(2),
    case_id: null,
    visit_id: null,
    team_id: null,
    event_type: "process",
    severity: "low",
    title: "Testereignis",
    description: null,
    status: "open",
    ...overrides,
  };
}

const empty = {
  partnerRequests: [] as PartnerRequestRow[],
  cases: [] as CaseRow[],
  teams: [] as TeamRow[],
  visits: [] as CareVisitRow[],
  careNotes: [] as CareNoteRow[],
  qualityEvents: [] as QualityEventRow[],
  now: NOW,
};

const run = (input: Partial<typeof empty>) =>
  buildAttentionItems({ ...empty, ...input });

describe("getHoursSince", () => {
  it("returns whole hours and 0 for missing dates", () => {
    expect(getHoursSince(hoursAgo(25.9), NOW)).toBe(25);
    expect(getHoursSince(null, NOW)).toBe(0);
  });
});

describe("team capacity rules (legacy)", () => {
  it.each([
    [90, 5, "P1"],
    [89, 5, "P2"],
    [80, 5, "P2"],
    [79, 1, "P2"], // open_slots <= 1
    [79, 2, null],
  ])("utilization %i%% with %i slots → %s", (utilization, open_slots, expected) => {
    const items = run({ teams: [team({ utilization, open_slots })] });
    expect(items[0]?.priority ?? null).toBe(expected);
  });

  it("treats missing utilization and slots as 0 (fires P2 via open_slots <= 1)", () => {
    const items = run({ teams: [team({ utilization: null, open_slots: null })] });
    expect(items.map((i) => i.priority)).toEqual(["P2"]);
  });
});

describe("case rules (legacy)", () => {
  it("case without team: P1 when urgency hoch", () => {
    const items = run({ cases: [careCase({ assigned_team_id: null, urgency: "hoch" })] });
    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({ priority: "P1", category: "case" });
  });

  it("case without team: P1 at >= 24 h, P2 before", () => {
    expect(run({ cases: [careCase({ assigned_team_id: null, created_at: hoursAgo(24) })] })[0].priority).toBe("P1");
    expect(run({ cases: [careCase({ assigned_team_id: null, created_at: hoursAgo(23) })] })[0].priority).toBe("P2");
  });

  it("running case without team does not fire", () => {
    expect(run({ cases: [careCase({ assigned_team_id: null, status: "laufend" })] })).toHaveLength(0);
  });

  it("teampruefung: P1 at >= 24 h, P2 before", () => {
    expect(run({ cases: [careCase({ status: "teampruefung", created_at: hoursAgo(24) })] })[0].priority).toBe("P1");
    expect(run({ cases: [careCase({ status: "teampruefung", created_at: hoursAgo(2) })] })[0].priority).toBe("P2");
  });

  it("KNOWN ISSUE TD-09: one case can produce two items (no team AND teampruefung)", () => {
    const items = run({ cases: [careCase({ assigned_team_id: null, status: "teampruefung" })] });
    expect(items.map((i) => i.id).sort()).toEqual(["case-without-team-c", "team-decision-c"]);
  });

  it("recommended action for a case without team mentions matching (legacy wording)", () => {
    const [item] = run({ cases: [careCase({ assigned_team_id: null })] });
    expect(item.recommendedAction).toContain("Matching starten");
  });
});

describe("partner request rules (legacy)", () => {
  it("open or ready_to_convert fire; urgent or >= 24 h is P1", () => {
    expect(run({ partnerRequests: [partner({ urgency: "hoch" })] })[0].priority).toBe("P1");
    expect(run({ partnerRequests: [partner({ created_at: hoursAgo(24) })] })[0].priority).toBe("P1");
    expect(run({ partnerRequests: [partner({ status: "ready_to_convert" })] })[0].priority).toBe("P2");
    expect(run({ partnerRequests: [partner({ status: "converted" })] })).toHaveLength(0);
  });
});

describe("visit report rules (legacy)", () => {
  it("completed visit without note → P2", () => {
    expect(run({ visits: [visit({})] })[0]).toMatchObject({ priority: "P2", category: "visit" });
  });

  it.each(["draft", "submitted"])("completed visit with %s note → P2", (status) => {
    expect(run({ visits: [visit({})], careNotes: [note({ status })] })).toHaveLength(1);
  });

  it("completed visit with approved note does not fire", () => {
    expect(run({ visits: [visit({})], careNotes: [note({ status: "approved" })] })).toHaveLength(0);
  });

  it("non-completed visit does not fire", () => {
    expect(run({ visits: [visit({ status: "started" })] })).toHaveLength(0);
  });
});

describe("quality rules (legacy)", () => {
  it.each([
    ["critical", "P1"],
    ["high", "P1"],
    ["medium", "P2"],
    ["low", "P2"],
  ])("open %s event → %s", (severity, expected) => {
    expect(run({ qualityEvents: [quality({ severity })] })[0].priority).toBe(expected);
  });

  it("closed event does not fire", () => {
    expect(run({ qualityEvents: [quality({ status: "closed" })] })).toHaveLength(0);
  });
});

describe("ordering", () => {
  it("sorts P1 before P2", () => {
    const items = run({
      qualityEvents: [quality({ id: "q1", severity: "low" }), quality({ id: "q2", severity: "high" })],
    });
    expect(items.map((i) => i.priority)).toEqual(["P1", "P2"]);
  });
});
