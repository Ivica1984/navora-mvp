// #1642: prints the app commit navora-staging serves (/api/version), or nothing when it cannot be read. Read-only, no
// credentials; the host is fixed (the staging smoke never opens another one). Used before and after the click paths.
const APP = "https://navora-staging.onrender.com";

try {
  const res = await fetch(`${APP}/api/version`, { signal: AbortSignal.timeout(20_000) });
  const commit = res.ok ? String((await res.json()).commit ?? "") : "";
  process.stdout.write(/^[0-9a-f]{7,40}$/.test(commit) ? commit : "");
} catch {
  process.stdout.write("");
}
