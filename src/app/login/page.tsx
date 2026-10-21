"use client";

import Link from "next/link";
import { useState } from "react";
import { supabase } from "../../lib/supabase";

export default function LoginPage() {
    const [email, setEmail] = useState("");
const [password, setPassword] = useState("");
const [errorMessage, setErrorMessage] = useState("");

async function handleLogin() {
  setErrorMessage("");

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    setErrorMessage("Login fehlgeschlagen. Bitte Zugang prüfen.");
    return;
  }

  window.location.href = "/matching";
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
            Interner Zugang für Matching, Teamsteuerung und Coach-Begleitung
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
            Dieses Portal ist für Navora Admins und Coaches. Hier werden
            Team-Matching, Coach-Fokus, regionale Teamübersicht und operative
            Entscheidungen gesteuert.
          </p>
        </div>

        <div
          style={{
            display: "grid",
            gap: "12px",
            maxWidth: "420px",
          }}
        >
          <div
            style={{
              background: "rgba(255,255,255,0.08)",
              borderRadius: "18px",
              padding: "16px",
            }}
          >
            <strong>Matching-Übersicht</strong>
            <div style={{ marginTop: "6px", color: "rgba(255,255,255,0.75)" }}>
              Offene Einsatzanfragen, Teamfit und nächste Aktionen.
            </div>
          </div>

          <div
            style={{
              background: "rgba(255,255,255,0.08)",
              borderRadius: "18px",
              padding: "16px",
            }}
          >
            <strong>Teams Übersicht</strong>
            <div style={{ marginTop: "6px", color: "rgba(255,255,255,0.75)" }}>
              Coach-Fokus, Teamstatus und regionale Steuerung.
            </div>
          </div>

          <div
            style={{
              background: "rgba(255,255,255,0.08)",
              borderRadius: "18px",
              padding: "16px",
            }}
          >
            <strong>Geschützter Zugriff</strong>
            <div style={{ marginTop: "6px", color: "rgba(255,255,255,0.75)" }}>
              Die Authentifizierung wird im nächsten Schritt mit Supabase
              verbunden.
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
            Für den Moment ist dies die Einstiegseite des geschützten Portals.
            Im nächsten Schritt verbinden wir sie mit Supabase Auth.
          </p>

          <div style={{ display: "grid", gap: "14px" }}>
            <div>
              <label
                style={{
                  display: "block",
                  fontSize: "14px",
                  marginBottom: "8px",
                  color: "#37554a",
                }}
              >
                E-Mail
              </label>
              <input
                type="email"
                value={email}
onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@navora.de"
                style={{
                  width: "100%",
                  border: "1px solid #d8e0db",
                  borderRadius: "16px",
                  padding: "14px 16px",
                  fontSize: "15px",
                  outline: "none",
                  boxSizing: "border-box",
                }}
              />
            </div>

            <div>
              <label
                style={{
                  display: "block",
                  fontSize: "14px",
                  marginBottom: "8px",
                  color: "#37554a",
                }}
              >
                Passwort
              </label>
              <input
                type="password"
                value={password}
onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••"
                style={{
                  width: "100%",
                  border: "1px solid #d8e0db",
                  borderRadius: "16px",
                  padding: "14px 16px",
                  fontSize: "15px",
                  outline: "none",
                  boxSizing: "border-box",
                }}
              />
            </div>

            <button
            onClick={handleLogin}
              style={{
                marginTop: "8px",
                background: "#16392d",
                color: "white",
                border: "none",
                borderRadius: "999px",
                padding: "14px 18px",
                fontSize: "15px",
                fontWeight: 600,
                cursor: "pointer",
              }}
            >
              Ins Admin / Coach Portal
            </button>
{errorMessage && (
  <div
    style={{
      marginTop: "10px",
      color: "#b42318",
      fontSize: "14px",
      textAlign: "center",
    }}
  >
    {errorMessage}
  </div>
)}
            <Link
              href="/matching"
              style={{
                textAlign: "center",
                color: "#37554a",
                textDecoration: "none",
                fontSize: "14px",
                marginTop: "8px",
              }}
            >
              Zum aktuellen internen MVP-Stand
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}