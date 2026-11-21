// Structured server logging without personal or health data (TD-17, SR-25).
//
// One JSON object per line on stdout/stderr, so a log host can index it.
// The API is an allowlist on purpose: only the keys in `LogFields` exist, and
// string values must look like a code (letters, digits, `_ . : / -`, max 64
// chars). Anything else is replaced by "[redacted]". Free text such as a
// database error's `message`, `details` or `hint` cannot be logged at all,
// because Postgres puts row values (names, notes, diagnoses) into exactly those fields.
//
// This is the only module allowed to call `console.*` in `src/` (ESLint rule).

export type LogLevel = "info" | "warn" | "error";

export type LogFields = {
  /** Machine-readable error or status code, e.g. Postgres `42501`, PostgREST `PGRST116`, auth `invalid_credentials`. */
  code?: string;
  /** HTTP status of an upstream call. */
  status?: number;
  /** Name of the operation, e.g. an RPC or query name. */
  op?: string;
  /** Number of items, never their content. */
  count?: number;
  durationMs?: number;
};

const SAFE_TOKEN = /^[A-Za-z0-9_.:/-]{1,64}$/;
const REDACTED = "[redacted]";
const ALLOWED_KEYS = ["code", "status", "op", "count", "durationMs"] as const;

function safeToken(value: unknown): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  const text = String(value);
  return SAFE_TOKEN.test(text) ? text : REDACTED;
}

function safeNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

export function sanitizeFields(fields: Record<string, unknown> = {}): LogFields {
  const out: LogFields = {};
  for (const key of ALLOWED_KEYS) {
    const value = fields[key];
    if (key === "code" || key === "op") {
      const token = safeToken(value);
      if (token !== undefined) out[key] = token;
    } else {
      const n = safeNumber(value);
      if (n !== undefined) out[key] = n;
    }
  }
  return out;
}

export function formatLogLine(
  level: LogLevel,
  event: string,
  fields: Record<string, unknown> = {},
  now: Date = new Date()
): string {
  return JSON.stringify({
    ts: now.toISOString(),
    level,
    event: safeToken(event) ?? REDACTED,
    ...sanitizeFields(fields),
  });
}

export function logEvent(level: LogLevel, event: string, fields?: LogFields): void {
  const line = formatLogLine(level, event, fields);
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.info(line);
}

/**
 * Safe projection of a Supabase/PostgREST/Auth error: code and HTTP status only.
 * Never pass the error object itself to a logger.
 */
export function errorFields(error: unknown): Pick<LogFields, "code" | "status"> {
  if (!error || typeof error !== "object") return {};
  const e = error as { code?: unknown; status?: unknown };
  return sanitizeFields({ code: e.code, status: e.status });
}
