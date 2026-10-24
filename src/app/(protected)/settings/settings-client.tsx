"use client";

import { useEffect, useState, useSyncExternalStore, useTransition } from "react";
import Sidebar from "@/components/layout/Sidebar";
import { disableOutsideDelivery, enableOutsideDelivery } from "@/features/push/commands";
import type { MyPushState } from "@/features/push/queries";
import { ENABLE_MESSAGES, memberInformation, NOT_AVAILABLE, OUTSIDE_LABEL, statusText } from "@/features/push/rules";

const button = "min-h-11 rounded-lg bg-emerald-800 px-4 text-sm font-bold text-white disabled:opacity-60";
const secondary = "min-h-11 rounded-lg border border-stone-400 bg-white px-4 text-sm font-semibold disabled:opacity-60";

function pushSupported(): boolean {
  return typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
}

const noSubscribe = () => () => undefined;

function keyBytes(b64: string): Uint8Array<ArrayBuffer> {
  const s = atob(b64.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((b64.length + 3) % 4));
  const out = new Uint8Array(new ArrayBuffer(s.length));
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

export default function SettingsClient({ state }: { state: MyPushState }) {
  const [pending, start] = useTransition();
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  // null while rendering on the server; the browser's answer after hydration.
  const supported = useSyncExternalStore(noSubscribe, pushSupported, () => null);
  const [deviceOn, setDeviceOn] = useState(false);

  useEffect(() => {
    if (!pushSupported()) return;
    navigator.serviceWorker.getRegistration("/").then(async (reg) => {
      setDeviceOn(Boolean(await reg?.pushManager.getSubscription()));
    }).catch(() => setDeviceOn(false));
  }, []);

  const enable = () => start(async () => {
    setMessage(null);
    setError(null);
    if (!pushSupported() || !state.vapidPublicKey) return setError(NOT_AVAILABLE);
    try {
      const permission = await Notification.requestPermission();
      if (permission !== "granted") return setError(ENABLE_MESSAGES.denied);
      const reg = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
      await navigator.serviceWorker.ready;
      const sub = (await reg.pushManager.getSubscription())
        ?? (await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(state.vapidPublicKey) }));
      const result = await enableOutsideDelivery({ subscription: sub.toJSON(), idempotencyKey: crypto.randomUUID() });
      if (result.ok) {
        setDeviceOn(true);
        setMessage(result.message);
      } else {
        // Not stored (e.g. Apple or Mozilla endpoint): remove the browser side too, nothing stays half on.
        await sub.unsubscribe().catch(() => undefined);
        setError(result.message);
      }
    } catch {
      setError(NOT_AVAILABLE);
    }
  });

  const disable = () => start(async () => {
    setMessage(null);
    setError(null);
    let endpoint: string | null = null;
    try {
      const reg = await navigator.serviceWorker.getRegistration("/");
      const sub = await reg?.pushManager.getSubscription();
      endpoint = sub?.endpoint ?? null;
      await sub?.unsubscribe();
    } catch {
      endpoint = null;
    }
    // Without this device's endpoint every device of hers is switched off (never fewer than she asked for).
    const result = await disableOutsideDelivery({ endpoint, idempotencyKey: crypto.randomUUID() });
    if (result.ok) {
      setDeviceOn(false);
      setMessage("Ausgeschaltet. Du erhältst Signale in der App.");
    } else setError(result.error);
  });

  return (
    <div style={{ minHeight: "100vh", display: "grid", gridTemplateColumns: "280px 1fr", background: "#f4f7f4", color: "#153328" }}>
      <Sidebar active="settings" />
      <main className="grid max-w-3xl content-start gap-6 p-8">
        <header>
          <p className="text-xs uppercase tracking-widest text-stone-500">Einstellungen</p>
          <h2 className="text-2xl font-bold">Meine Einstellungen</h2>
        </header>
        <section aria-label={OUTSIDE_LABEL} className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
          <h3 className="text-lg font-bold">{OUTSIDE_LABEL}</h3>
          <p data-testid="push-status" className="text-sm font-semibold">{statusText(state.active)}</p>
          <ul data-testid="push-information" className="grid list-disc gap-1 pl-5 text-sm text-stone-700">
            {memberInformation(state.vendors).map((line) => <li key={line}>{line}</li>)}
          </ul>
          {!state.channelOn ? (
            <p data-testid="push-channel-off" className="rounded-lg border border-stone-300 bg-stone-50 p-2 text-sm">{ENABLE_MESSAGES.channel_off}</p>
          ) : supported === false || !state.vapidPublicKey ? (
            <p data-testid="push-unsupported" className="rounded-lg border border-stone-300 bg-stone-50 p-2 text-sm">{NOT_AVAILABLE}</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {!deviceOn && <button type="button" className={button} disabled={pending || supported === null} onClick={enable}>Auf diesem Gerät einschalten</button>}
              {deviceOn && <button type="button" className={secondary} disabled={pending} onClick={disable}>Ausschalten</button>}
            </div>
          )}
          {state.devices.length > 0 && (
            <button type="button" className="justify-self-start text-sm underline" disabled={pending}
              onClick={() => start(async () => {
                const r = await disableOutsideDelivery({ endpoint: null, idempotencyKey: crypto.randomUUID() });
                if (r.ok) { setDeviceOn(false); setMessage("Auf allen Geräten ausgeschaltet."); } else setError(r.error);
              })}>
              Auf allen Geräten ausschalten ({state.devices.length})
            </button>
          )}
          {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 text-sm font-semibold text-rose-800">{error}</p>}
          {message && <p role="status" className="text-sm text-emerald-900">{message}</p>}
        </section>
      </main>
    </div>
  );
}
