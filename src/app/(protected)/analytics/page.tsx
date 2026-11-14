import { connection } from "next/server";
import { getPilotHypotheses, getPilotKpis, getPilotStepSpans } from "@/features/analytics/queries";
import { monthStart } from "@/features/billing/rules";
import { todayInZurich } from "@/features/field/rules";
import AnalyticsClient from "./analytics-client";

// AN1: pilot impact dashboard; AN2: pilot hypotheses; AN3: per-step spans. Aggregates only; teams see their own team, coordination roles all teams.
export default async function AnalyticsPage({ searchParams }: PageProps<"/analytics">) {
  await connection();
  const { monat } = await searchParams;
  const current = monthStart(todayInZurich());
  const month = typeof monat === "string" && /^\d{4}-\d{2}$/.test(monat) ? `${monat}-01` : current;
  const [rows, hypotheses, spans] = await Promise.all([getPilotKpis(month), getPilotHypotheses(month), getPilotStepSpans(month)]);
  return <AnalyticsClient rows={rows} hypotheses={hypotheses} spans={spans} month={month} />;
}
