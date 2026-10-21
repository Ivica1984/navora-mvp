// Pure route rules for the proxy — no Next or Supabase imports, unit-tested.

/** Routes reachable without a session. Everything else requires sign-in. */
const PUBLIC_PATHS: ReadonlySet<string> = new Set(["/login"]);

export const LOGIN_PATH = "/login";
export const HOME_PATH = "/operations";
/** The nurse's day view (F1). */
export const FIELD_PATH = "/field";

/**
 * Landing page after sign-in, derived from the user's organisation roles
 * (server data, never a request parameter → no open redirect).
 * Users whose only role is `nurse` land in the field tool; everybody else,
 * including users without any membership, lands in Operations.
 * Role names are placeholders until Q4 / D-3.
 */
export function homePathForRoles(roles: ReadonlyArray<string>): string {
  return roles.length > 0 && roles.every((role) => role === "nurse") ? FIELD_PATH : HOME_PATH;
}

export function isPublicPath(pathname: string): boolean {
  const normalized =
    pathname.length > 1 && pathname.endsWith("/") ? pathname.slice(0, -1) : pathname;

  return PUBLIC_PATHS.has(normalized);
}
