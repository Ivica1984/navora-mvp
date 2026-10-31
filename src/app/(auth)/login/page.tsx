import { redirect } from "next/navigation";
import { getOptionalUser } from "@/lib/auth/session";
import { getHomePath } from "@/lib/auth/home";
import LoginForm from "./login-form";

// UX1-15, UX1-16 (ADR-105): one sign-in page for every role, one column with the sign-in card. UX1-16 widened (uxa
// UXR-17, PO 2026-10-28 02:10): the explanatory panel is gone and nothing replaces it (a nurse cannot act on it).
// Sign-in logic, session check and redirect are unchanged.
export default async function LoginPage() {
  // Already signed in: go straight to the app.
  if (await getOptionalUser()) {
    redirect(await getHomePath());
  }

  return (
    <main className="min-h-screen bg-[#f4f7f4] text-[#153328]">
      <section className="flex min-h-screen items-start justify-center px-4 py-8 md:items-center md:p-14">
        <div className="w-full max-w-[460px] rounded-3xl bg-white p-6 shadow-[0_20px_60px_rgba(21,51,40,0.08)] md:p-8">
          <h1 className="mb-2 mt-0 text-2xl font-semibold">Bei NAVORA anmelden</h1>

          <p className="text-secondary mb-6 leading-relaxed">
            Melde dich mit deinem NAVORA-Zugang an. Neue Zugänge werden durch einen Admin eingerichtet.
          </p>

          <LoginForm />
        </div>
      </section>
    </main>
  );
}
