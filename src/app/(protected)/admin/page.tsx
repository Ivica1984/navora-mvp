import { connection } from "next/server";
import { getAdminData } from "@/features/admin/queries";
import AdminClient from "./admin-client";

// ADM1: pilot administration. Administrators of an organisation only; everybody else sees a notice
// (the database functions return nothing to them either).
export default async function AdminPage() {
  await connection();
  const data = await getAdminData();
  return <AdminClient data={data} />;
}
