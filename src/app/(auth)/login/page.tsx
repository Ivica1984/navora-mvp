import { redirect } from "next/navigation";
import { getOptionalUser } from "@/lib/auth/session";
import { getHomePath } from "@/lib/auth/home";
import LoginForm from "./login-form";

const infoCard = {
  background: "rgba(255,255,255,0.08)",
  borderRadius: "18px",
  padding: "16px",
};

const infoText = { marginTop: "6px", color: "rgba(255,255,255,0.75)" };

export default async function LoginPage() {
  // Already signed in: go straight to the app.
  if (await getOptionalUser()) {
    redirect(await getHomePath());
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#f4f7f4",
        fontFamily: "Inter, sans-serif",
        display: "grid",
        gridTemplateColumns: "1.05fr 0.95fr",
        color: "#153328",
      }}
    >
      <section
        style={{
          background: "#16392d",
          color: "white",
          padding: "56px",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        <div>
          <div
            style={{
              fontSize: "12px",
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              color: "rgba(255,255,255,0.72)",
              marginBottom: "14px",
            }}
          >
            Admin / Coach Portal
          </div>

          <h1
            style={{
              fontSize: "42px",
              lineHeight: 1.05,
              margin: 0,
              maxWidth: "520px",
            }}
          >
            Interner Zugang für Teamsteuerung und Coach-Begleitung
          </h1>

          <p
            style={{
              marginTop: "22px",
              maxWidth: "540px",
              color: "rgba(255,255,255,0.78)",
              lineHeight: 1.6,
              fontSize: "17px",
            }}
          >
            Dieses Portal ist für Navora Admins und Coaches: Operations-Lage,
            regionale Teamübersicht und Pflegeeinsätze.
          </p>
        </div>

        <div style={{ display: "grid", gap: "12px", maxWidth: "420px" }}>
          <div style={infoCard}>
            <strong>Operations</strong>
            <div style={infoText}>Attention Center, Kapazität und Teamentscheide.</div>
          </div>

          <div style={infoCard}>
            <strong>Teams Übersicht</strong>
            <div style={infoText}>Coach-Fokus, Teamstatus und regionale Steuerung.</div>
          </div>

          <div style={infoCard}>
            <strong>Geschützter Zugriff</strong>
            <div style={infoText}>
              Alle Seiten erfordern eine Anmeldung. Die Sitzung wird serverseitig geprüft.
            </div>
          </div>
        </div>
      </section>

      <section
        style={{
          padding: "56px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <div
          style={{
            width: "100%",
            maxWidth: "460px",
            background: "white",
            borderRadius: "28px",
            padding: "30px",
            boxShadow: "0 20px 60px rgba(21,51,40,0.08)",
          }}
        >
          <div
            style={{
              fontSize: "12px",
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              color: "#6d857c",
              marginBottom: "10px",
            }}
          >
            Login
          </div>

          <h2 style={{ marginTop: 0, fontSize: "28px", marginBottom: "10px" }}>
            Admin / Coach anmelden
          </h2>

          <p style={{ color: "#5f766d", marginBottom: "24px", lineHeight: 1.6 }}>
            Melde dich mit deinem NAVORA-Zugang an. Neue Zugänge werden durch einen
            Admin eingerichtet.
          </p>

          <LoginForm />
        </div>
      </section>
    </main>
  );
}
