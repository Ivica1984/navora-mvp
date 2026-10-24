import { connection } from "next/server";
import { getAdminData } from "@/features/admin/queries";
import { getAdminPush } from "@/features/push/queries";
import { getSignalEvaluatorHealth } from "@/features/signals/queries";
import AdminClient from "./admin-client";

// ADM1: pilot administration. Administrators of an organisation only; everybody else sees a notice
// (the database functions return nothing to them either).
export default async function AdminPage() {
  await connection();
  const data = await getAdminData();
  // SIG2-3 / SIG2-6: outside delivery and watched hours of the organisation.
  const push = data ? await getAdminPush(data.organizationId) : null;
  // SIG2-11: "Signalprüfung läuft nicht" for this organisation.
  const evaluator = data ? (await getSignalEvaluatorHealth()).filter((h) => h.organization_id === data.organizationId) : [];
  return <AdminClient data={data} push={push} evaluator={evaluator} />;
}
