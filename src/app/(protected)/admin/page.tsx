import { connection } from "next/server";
import { getAdminData } from "@/features/admin/queries";
import { getAdminPush } from "@/features/push/queries";
import { getSignalEvaluatorHealth, getVisitsOutsideWatchedHours } from "@/features/signals/queries";
import { getAdminAdmissions } from "@/features/admission/queries";
import { getAdminContracts, getContractEndHandover } from "@/features/contract-end/queries";
import { todayInZurich } from "@/features/field/rules";
import { withContractEnds } from "@/features/contract-end/rules";
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
  // SIG2-C1 (2): planned visits of the next 7 days outside the watched hours of this organisation.
  const outside = data ? await getVisitsOutsideWatchedHours(false) : null;
  const outsideWatched = outside === null ? null : outside.filter((v) => v.organization_id === data?.organizationId);
  // ADM2-1/-6/-9: team admission switch, "Vertrag erfassen" and every admission of the organisation.
  const admissions = data ? await getAdminAdmissions(data.organizationId) : null;
  // ADM2-11 / ADM2-12: the recorded contract per member and the leavers of the next 14 days.
  const contracts = data ? await getAdminContracts(data.organizationId) : {};
  const leavers = data ? await getContractEndHandover() : [];
  const today = todayInZurich();
  // ADM2-13: an access her contract end ended shows as ended ("Vertragsende") and can be restored.
  const shown = data ? { ...data, access: withContractEnds(data.access, contracts, data.lastAccessEventAt, today) } : null;
  return (
    <AdminClient data={shown} push={push} evaluator={evaluator} outsideWatched={outsideWatched} admissions={admissions}
      contracts={contracts} leavers={leavers} today={today} />
  );
}
