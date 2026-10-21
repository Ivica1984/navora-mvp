import { redirect } from "next/navigation";
import { HOME_PATH } from "@/lib/auth/paths";

// The proxy sends visitors without a session to /login first.
export default function HomePage() {
  return redirect(HOME_PATH);
}
