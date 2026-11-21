import { readdirSync } from "node:fs";
import type { NextConfig } from "next";
import { STATIC_SECURITY_HEADERS } from "./src/lib/security/csp";
import { highestMigration } from "./src/lib/version";

const nextConfig: NextConfig = {
  // Do not advertise the framework (T11).
  poweredByHeader: false,

  // Q1 (a), ADR-220: the migration level this build expects, shown in the footer and on /api/version.
  env: { NAVORA_MIGRATION: highestMigration(readdirSync("supabase/migrations")) ?? "" },

  async headers() {
    return [
      {
        source: "/:path*",
        headers: [...STATIC_SECURITY_HEADERS],
      },
    ];
  },
};

export default nextConfig;
