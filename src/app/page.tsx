import { redirect } from "next/navigation";
import { getHomePath } from "@/lib/auth/home";

// The proxy sends visitors without a session to /login first.
// Nurses land in the field tool, everybody else in Operations (F1).
export default async function HomePage() {
  redirect(await getHomePath());
}
