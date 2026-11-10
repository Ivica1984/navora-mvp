#!/usr/bin/env node
// B0 runner ports (ADR-174): helper for scripts/ci-supabase-start.sh.
//
// Cause class (IDENTIFIED from 16 failed CI jobs, 2026-10-23 to 2026-11-10): "Start local Supabase" stops with
// "failed to bind host port 0.0.0.0:54322|54324/tcp: address already in use" on a fresh GitHub-hosted runner. The local
// Supabase ports 54320-54329 lie inside Linux's ephemeral port range (default 32768-60999), so an outbound connection
// opened during the image pulls or the migrations can take one of them as its source port just before Docker binds it.
// Mechanism: PROBABLE; the wrapper prints the socket holding the port on the next failure, which confirms or refutes it.
//
// CLI:
//   node scripts/ci-supabase-start.mjs --range                 prints "54320-54329" (for sysctl)
//   node scripts/ci-supabase-start.mjs --check-config <toml>   exit 1 if a port in config.toml is outside the range
//   node scripts/ci-supabase-start.mjs --classify <log>        prints the infrastructure annotation (or nothing), exit 0
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

/** Ports reserved from the kernel's ephemeral range before `supabase start` (net.ipv4.ip_local_reserved_ports). */
export const RESERVED_PORTS = Object.freeze({ from: 54320, to: 54329 });

/** Every `port = N` / `*_port = N` set in supabase/config.toml. */
export function configPorts(toml) {
  const ports = [];
  for (const m of String(toml).matchAll(/^\s*[a-z_]*port\s*=\s*(\d+)\s*(?:#.*)?$/gm)) ports.push(Number(m[1]));
  return ports;
}

// Both Docker message shapes seen in the logs:
//   failed to bind host port 0.0.0.0:54324/tcp: address already in use
//   failed to bind host port for 0.0.0.0:54324:172.18.0.7:8025/tcp: address already in use
const BIND = /failed to bind host port (?:for )?[0-9a-f.:[\]]*?:(\d+)(?::[0-9.]+:\d+)?\/tcp: address already in use/g;
const REGISTRY = /toomanyrequests: (?:Rate exceeded|Data limit exceeded)/;
const SQL = /\bERROR:|SQLSTATE/;

/**
 * Classifies the output of a failed `supabase start`. Fail-closed: only the two infrastructure shapes are named as
 * infrastructure; a migration or seed error, empty output or anything unknown stays a test failure.
 * @param {string} text
 * @returns {{ kind: "runner-port-in-use" | "registry-limit" | "not-infrastructure", ports: number[] }}
 */
export function classifyStartFailure(text) {
  const t = String(text ?? "");
  if (SQL.test(t)) return { kind: "not-infrastructure", ports: [] };
  const ports = [...new Set([...t.matchAll(BIND)].map((m) => Number(m[1])))].sort((a, b) => a - b);
  if (ports.length > 0) return { kind: "runner-port-in-use", ports };
  if (REGISTRY.test(t)) return { kind: "registry-limit", ports: [] };
  return { kind: "not-infrastructure", ports: [] };
}

/** One GitHub annotation line, or "" when the failure is not infrastructure. */
export function formatAnnotation({ kind, ports }) {
  const tail = "This is not a test result: the job stopped before any test ran. Re-run the job; the test status of this commit stays unknown until it ran.";
  if (kind === "runner-port-in-use") {
    return `::error title=infrastructure: runner port in use (${ports.join(", ")})::Docker could not bind ${ports.join(", ")} on the runner (ADR-174). ${tail}`;
  }
  if (kind === "registry-limit") {
    return `::error title=infrastructure: registry limit::The image registry refused the pull (toomanyrequests). ${tail}`;
  }
  return "";
}

function main(argv) {
  const [cmd, file] = argv;
  if (cmd === "--range") {
    process.stdout.write(`${RESERVED_PORTS.from}-${RESERVED_PORTS.to}\n`);
    return 0;
  }
  if (cmd === "--check-config" && file) {
    const outside = configPorts(readFileSync(file, "utf8")).filter((p) => p < RESERVED_PORTS.from || p > RESERVED_PORTS.to);
    if (outside.length > 0) {
      process.stderr.write(`ports outside the reserved range ${RESERVED_PORTS.from}-${RESERVED_PORTS.to}: ${outside.join(", ")} (ADR-174)\n`);
      return 1;
    }
    return 0;
  }
  if (cmd === "--classify" && file) {
    const line = formatAnnotation(classifyStartFailure(readFileSync(file, "utf8")));
    if (line) process.stdout.write(`${line}\n`);
    return 0;
  }
  process.stderr.write("usage: ci-supabase-start.mjs --range | --check-config <toml> | --classify <log>\n");
  return 2;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main(process.argv.slice(2)));
}
