import { requireUser } from "@/lib/auth/session";

// Second guard after the proxy: no protected route renders without a valid
// session. Queries and commands check again themselves (ADR-017).
export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireUser();

  return children;
}
