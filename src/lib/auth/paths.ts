// Pure route rules for the proxy — no Next or Supabase imports, unit-tested.

/** Routes reachable without a session. Everything else requires sign-in. */
const PUBLIC_PATHS: ReadonlySet<string> = new Set(["/login"]);

export const LOGIN_PATH = "/login";
export const HOME_PATH = "/operations";

export function isPublicPath(pathname: string): boolean {
  const normalized =
    pathname.length > 1 && pathname.endsWith("/") ? pathname.slice(0, -1) : pathname;

  return PUBLIC_PATHS.has(normalized);
}
