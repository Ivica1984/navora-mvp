import { redirect } from "next/navigation";
import { getOptionalUser } from "@/lib/auth/session";
import { getHomePath } from "@/lib/auth/home";
import LoginForm from "./login-form";

// UX1-15, UX1-16 (ADR-105): one sign-in page for every role. Below 768 px one column with the sign-in card first;
// from 768 px the short explanatory panel sits beside it. Sign-in logic, session check and redirect are unchanged.
export default async function LoginPage() {
  // Already signed in: go straight to the app.
  if (await getOptionalUser()) {
    redirect(await getHomePath());
  }

  return (
    <main className="grid min-h-screen bg-[#f4f7f4] text-[#153328] md:grid-cols-[1fr_0.9fr]">
      <section className="flex items-start justify-center px-4 py-8 md:order-2 md:items-center md:p-14">
        <div className="w-full max-w-[460px] rounded-3xl bg-white p-6 shadow-[0_20px_60px_rgba(21,51,40,0.08)] md:p-8">
          <h1 className="mb-2 mt-0 text-2xl font-semibold">Bei NAVORA anmelden</h1>

          <p className="text-secondary mb-6 leading-relaxed">
            Melde dich mit deinem NAVORA-Zugang an. Neue Zugänge werden durch einen Admin eingerichtet.
          </p>

          <LoginForm />
        </div>
      </section>

      <section className="bg-[#16392d] px-4 py-8 text-white md:order-1 md:flex md:flex-col md:justify-center md:p-14">
        <div className="max-w-[480px] rounded-2xl bg-white/10 p-4">
          <strong>Geschützter Zugriff</strong>
          <p className="mb-0 mt-1.5 text-white">
            Alle Seiten erfordern eine Anmeldung. Die Sitzung wird serverseitig geprüft.
          </p>
        </div>
      </section>
    </main>
  );
}
