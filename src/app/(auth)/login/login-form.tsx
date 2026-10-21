"use client";

import { useActionState } from "react";
import { signIn } from "@/features/auth/actions";
import type { SignInState } from "@/features/auth/schema";

const initialState: SignInState = { error: null };

const inputStyle = {
  width: "100%",
  border: "1px solid #d8e0db",
  borderRadius: "16px",
  padding: "14px 16px",
  fontSize: "15px",
  outline: "none",
  boxSizing: "border-box" as const,
};

const labelStyle = {
  display: "block",
  fontSize: "14px",
  marginBottom: "8px",
  color: "#37554a",
};

export default function LoginForm() {
  const [state, formAction, isPending] = useActionState(signIn, initialState);

  return (
    <form action={formAction} style={{ display: "grid", gap: "14px" }}>
      <div>
        <label htmlFor="email" style={labelStyle}>
          E-Mail
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          required
          placeholder="vorname.name@beispiel.ch"
          style={inputStyle}
        />
      </div>

      <div>
        <label htmlFor="password" style={labelStyle}>
          Passwort
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          style={inputStyle}
        />
      </div>

      <button
        type="submit"
        disabled={isPending}
        style={{
          marginTop: "8px",
          background: isPending ? "#6b8075" : "#16392d",
          color: "white",
          border: "none",
          borderRadius: "999px",
          padding: "14px 18px",
          fontSize: "15px",
          fontWeight: 600,
          cursor: isPending ? "not-allowed" : "pointer",
        }}
      >
        {isPending ? "Anmeldung läuft …" : "Anmelden"}
      </button>

      {state.error && (
        <div
          role="alert"
          style={{
            marginTop: "10px",
            color: "#b42318",
            fontSize: "14px",
            textAlign: "center",
          }}
        >
          {state.error}
        </div>
      )}
    </form>
  );
}
