import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { connection } from "next/server";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "NAVORA",
  description: "NAVORA – Plattform für selbstorganisierte Pflegeteams (Staging, synthetische Daten)",
  robots: { index: false, follow: false },
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  // Every page renders per request: required for the per-request CSP nonce
  // (T11) and consistent with "no caching of care data" (ADR-010).
  await connection();

  return (
    <html
      lang="de-CH"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        {/* Required until the security foundation (M3) is complete — SR-02, SR-07. */}
        <div
          role="alert"
          style={{
            background: "#7f1d1d",
            color: "white",
            padding: "6px 16px",
            fontSize: "13px",
            fontWeight: 700,
            textAlign: "center",
          }}
        >
          Entwicklungsstand – nicht für echte Patientendaten. Nur synthetische Testdaten verwenden.
        </div>
        {children}
      </body>
    </html>
  );
}
