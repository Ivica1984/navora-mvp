import type { NextConfig } from "next";
import { STATIC_SECURITY_HEADERS } from "./src/lib/security/csp";

const nextConfig: NextConfig = {
  // Do not advertise the framework (T11).
  poweredByHeader: false,

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
