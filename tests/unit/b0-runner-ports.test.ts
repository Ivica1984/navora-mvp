import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  RESERVED_PORTS,
  classifyStartFailure,
  configPorts,
  fallbackRegistry,
  formatAnnotation,
} from "../../scripts/ci-supabase-start.mjs";

// B0 (PO 2026-11-10 11:39, ADR-174): "Start local Supabase" failed 16 times since 2026-10-23 on a GitHub-hosted runner
// with "failed to bind host port 0.0.0.0:54322|54324/tcp: address already in use". The ports 54320-54329 lie inside
// Linux's ephemeral range (32768-60999), so an outbound connection made during the image pulls or the migrations can
// take one of them as its source port. The wrapper reserves the range before `supabase start` and, when the start still
// fails, names the class as infrastructure in an annotation, so nobody re-runs a test to find out it was the runner.

const ROOT = process.cwd();
const CI = readFileSync(join(ROOT, ".github/workflows/ci.yml"), "utf8");
const REPEAT = readFileSync(join(ROOT, ".github/workflows/ci-repeat.yml"), "utf8");
const CONFIG = readFileSync(join(ROOT, "supabase/config.toml"), "utf8");
const SCRIPT = join(ROOT, "scripts/ci-supabase-start.mjs");
const WRAPPER = join(ROOT, "scripts/ci-supabase-start.sh");

// Synthetic copies of the two message shapes in the job logs (no personal data; container ids shortened).
const BIND_NEW =
  'failed to start docker container "supabase_inbucket_navora-mvp": Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint supabase_inbucket_navora-mvp (cc93a793233e): failed to bind host port 0.0.0.0:54324/tcp: address already in use';
const BIND_OLD =
  'failed to start docker container "supabase_db_navora-mvp": Error response from daemon: driver failed programming external connectivity on endpoint supabase_db_navora-mvp (4409e013cdf2): failed to bind host port for 0.0.0.0:54322:172.18.0.3:5432/tcp: address already in use';
const RATE = "Error response from daemon: toomanyrequests: Rate exceeded";
const DATA = "Error response from daemon: toomanyrequests: Data limit exceeded";
// The shape public.ecr.aws (the Supabase CLI default registry) sent on 2026-11-18 (job 134593805851).
const ECR_RATE = "Error response from daemon: error from registry: Rate exceeded\nRetrying after 4s: public.ecr.aws/supabase/gotrue:v2.197.0";

describe("B0 runner ports: classification of a failed `supabase start`", () => {
  it("names a host-port bind failure as infrastructure, with the port (current Docker message)", () => {
    expect(classifyStartFailure(`Starting database...\n${BIND_NEW}\nTry rerunning the command with --debug`)).toEqual({
      kind: "runner-port-in-use",
      ports: [54324],
    });
  });

  it("recognises the older Docker message shape (host:port:container-ip:port)", () => {
    expect(classifyStartFailure(BIND_OLD)).toEqual({ kind: "runner-port-in-use", ports: [54322] });
  });

  it("a pull that hit the registry limit and then failed is infrastructure too", () => {
    expect(classifyStartFailure(`${RATE}\n${RATE}\nfailed to pull image`)).toEqual({ kind: "registry-limit", ports: [] });
    expect(classifyStartFailure(DATA)).toEqual({ kind: "registry-limit", ports: [] });
  });

  it("a port collision wins over earlier, retried registry messages (the bind is what stopped the start)", () => {
    expect(classifyStartFailure(`${RATE}\nRetrying after 4s\n${BIND_NEW}`).kind).toBe("runner-port-in-use");
  });

  it("a migration or seed error is NOT infrastructure: it stays a test failure", () => {
    const sql = 'Applying migration 20261021000099_x.sql...\nERROR: column "y" does not exist (SQLSTATE 42703)';
    expect(classifyStartFailure(sql)).toEqual({ kind: "not-infrastructure", ports: [] });
    // Even with registry noise before it: the SQL error is what failed.
    expect(classifyStartFailure(`${RATE}\nRetrying after 4s\n${sql}`).kind).toBe("not-infrastructure");
  });

  it("empty or unknown output is never classified as infrastructure (fail-closed)", () => {
    expect(classifyStartFailure("").kind).toBe("not-infrastructure");
    expect(classifyStartFailure("something else went wrong").kind).toBe("not-infrastructure");
  });

  it("the annotation says infrastructure and names the port; a test failure gets no infrastructure title", () => {
    const a = formatAnnotation({ kind: "runner-port-in-use", ports: [54324] });
    expect(a).toMatch(/^::error title=infrastructure: runner port in use \(54324\)::/);
    expect(a).toContain("not a test result");
    expect(formatAnnotation({ kind: "registry-limit", ports: [] })).toMatch(/^::error title=infrastructure: registry limit::/);
    expect(formatAnnotation({ kind: "not-infrastructure", ports: [] })).toBe("");
  });
});

describe("B0 runner ports: the reserved range covers every Supabase port", () => {
  it("reserves 54320-54329", () => {
    expect(RESERVED_PORTS).toEqual({ from: 54320, to: 54329 });
  });

  it("every port set in supabase/config.toml lies in the reserved range", () => {
    const ports = configPorts(CONFIG);
    expect(ports).toEqual(expect.arrayContaining([54320, 54321, 54322]));
    for (const p of ports) {
      expect(p).toBeGreaterThanOrEqual(RESERVED_PORTS.from);
      expect(p).toBeLessThanOrEqual(RESERVED_PORTS.to);
    }
  });

  it("the --check-config CLI fails when config.toml gets a port outside the range", () => {
    const dir = mkdtempSync(join(tmpdir(), "b0-ports-"));
    const bad = join(dir, "config.toml");
    writeFileSync(bad, CONFIG.replace("port = 54321", "port = 8000"));
    expect(() => execFileSync("node", [SCRIPT, "--check-config", bad], { stdio: "pipe" })).toThrow();
    expect(() => execFileSync("node", [SCRIPT, "--check-config", join(ROOT, "supabase/config.toml")], { stdio: "pipe" })).not.toThrow();
  });

  it("the classify CLI reads a log file and prints the annotation, exit 0", () => {
    const dir = mkdtempSync(join(tmpdir(), "b0-ports-"));
    const log = join(dir, "start.log");
    writeFileSync(log, BIND_NEW);
    const out = execFileSync("node", [SCRIPT, "--classify", log], { encoding: "utf8" });
    expect(out).toMatch(/title=infrastructure: runner port in use \(54324\)/);
  });
});

describe("B0 runner ports: wiring in ci.yml and ci-repeat.yml", () => {
  it("no job calls a bare `supabase start` any more", () => {
    expect(CI).not.toMatch(/run: supabase start\s*$/m);
    expect(REPEAT).not.toMatch(/run: supabase start\s*$/m);
  });

  it("db, e2e and ui-screenshots start Supabase through the wrapper, once each", () => {
    const uses = CI.match(/run: scripts\/ci-supabase-start\.sh\s*$/gm) ?? [];
    expect(uses.length).toBe(3);
    // ci-repeat.yml repeats db and e2e with identical steps (ADR-168).
    expect((REPEAT.match(/run: scripts\/ci-supabase-start\.sh\s*$/gm) ?? []).length).toBe(2);
  });

  it("the wrapper keeps the exit status of `supabase start` (no hidden failure; one start call site)", () => {
    const sh = readFileSync(WRAPPER, "utf8");
    expect(sh).toMatch(/set -uo pipefail/);
    expect(sh).toContain("ip_local_reserved_ports");
    expect(sh).toMatch(/exit "\$status"/);
    expect(sh).not.toMatch(/\|\|\s*true\s*$/m);
    expect((sh.match(/^\s*supabase start\b/gm) ?? []).length).toBe(1);
  });

  // ADR-204 (owner, live session 2026-11-18): a start refused by the registry limit is retried ONCE from Docker Hub
  // with the owner's account, and only then. Every other failure keeps ADR-174: no retry.
  it("ADR-204: the only retry is the Docker Hub fallback decided by --fallback, at most once", () => {
    const sh = readFileSync(WRAPPER, "utf8");
    expect(sh).toContain('--fallback "$out"');
    expect(sh).toContain("SUPABASE_INTERNAL_IMAGE_REGISTRY");
    expect(sh).toMatch(/docker login --username "\$DOCKERHUB_USERNAME" --password-stdin/);
    expect(sh).not.toMatch(/echo "\$DOCKERHUB_TOKEN"/); // the token never goes to the log
    expect((sh.match(/^\s*start_stack "\$@"/gm) ?? []).length).toBe(2); // first try + the one fallback
    expect(sh).not.toMatch(/\b(?:while|until)\b/); // no loop
  });

  it("ADR-204: every Supabase start step gets the two Docker Hub secrets, nothing else", () => {
    for (const [name, text, n] of [["ci.yml", CI, 3], ["ci-repeat.yml", REPEAT, 2]] as const) {
      const steps = text.split(/\n(?=\s*- name:)/).filter((s) => /run: scripts\/ci-supabase-start\.sh\s*$/m.test(s));
      expect(steps.length, name).toBe(n);
      for (const st of steps) {
        expect(st, name).toContain("DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}");
        expect(st, name).toContain("DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}");
      }
    }
  });
});

describe("ADR-204: Docker Hub fallback after a registry limit", () => {
  const creds = { DOCKERHUB_USERNAME: "navora-ci", DOCKERHUB_TOKEN: "dckr_pat_synthetic" };

  it("the public.ecr.aws message «error from registry: Rate exceeded» is a registry limit (missed before)", () => {
    expect(classifyStartFailure(`${ECR_RATE}\nfailed to pull image`)).toEqual({ kind: "registry-limit", ports: [] });
  });

  it("a registry limit with both secrets set falls back to docker.io", () => {
    expect(fallbackRegistry({ kind: "registry-limit", ports: [] }, creds)).toBe("docker.io");
  });

  it("no fallback without both secrets (blank counts as missing)", () => {
    expect(fallbackRegistry({ kind: "registry-limit", ports: [] }, {})).toBe("");
    expect(fallbackRegistry({ kind: "registry-limit", ports: [] }, { ...creds, DOCKERHUB_TOKEN: "  " })).toBe("");
    expect(fallbackRegistry({ kind: "registry-limit", ports: [] }, { DOCKERHUB_TOKEN: "x" })).toBe("");
  });

  it("no fallback for any other failure: a port collision, a migration error, unknown output", () => {
    expect(fallbackRegistry({ kind: "runner-port-in-use", ports: [54324] }, creds)).toBe("");
    expect(fallbackRegistry({ kind: "not-infrastructure", ports: [] }, creds)).toBe("");
  });

  it("never a second fallback: once the registry is already docker.io, nothing more", () => {
    expect(fallbackRegistry({ kind: "registry-limit", ports: [] }, { ...creds, SUPABASE_INTERNAL_IMAGE_REGISTRY: "docker.io" })).toBe("");
  });

  it("the --fallback CLI reads the log and the environment and prints the registry or nothing", () => {
    const dir = mkdtempSync(join(tmpdir(), "adr204-"));
    const log = join(dir, "start.log");
    writeFileSync(log, ECR_RATE);
    const env = { PATH: process.env.PATH ?? "", NODE_ENV: "test" } as NodeJS.ProcessEnv;
    expect(execFileSync("node", [SCRIPT, "--fallback", log], { encoding: "utf8", env: { ...env, ...creds } }).trim()).toBe("docker.io");
    expect(execFileSync("node", [SCRIPT, "--fallback", log], { encoding: "utf8", env }).trim()).toBe("");
    writeFileSync(log, BIND_NEW);
    expect(execFileSync("node", [SCRIPT, "--fallback", log], { encoding: "utf8", env: { ...env, ...creds } }).trim()).toBe("");
  });
});
