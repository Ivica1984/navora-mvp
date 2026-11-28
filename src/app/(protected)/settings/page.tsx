import { connection } from "next/server";
import { getMyPushState } from "@/features/push/queries";
import SettingsClient from "./settings-client";

// SIG2-1: the member's own settings. "Benachrichtigung ausserhalb der App" (opt-in, member information first).
export default async function SettingsPage() {
  await connection();
  const state = await getMyPushState();
  return <SettingsClient state={state} />;
}
