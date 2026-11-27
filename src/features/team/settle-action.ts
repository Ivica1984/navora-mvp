// HD-3s-F2-F1 (review (e) on #1825): the plan and move forms call their server action from `onSubmit`, not as a form
// action. A call that throws (lost connection on a phone, deploy swap during the call) must not leave the button disabled
// without a message. The server may already have saved before the connection dropped, so the sentence never says
// «nicht gespeichert»: it asks to reload and check. Pure helper; the server action's own `{ ok: false }` passes through.

export const INTERRUPTED_TEXT =
  "Verbindung unterbrochen. Bitte die Seite neu laden und prüfen, ob die Änderung gespeichert wurde.";

export type Interrupted = { ok: false; error: string; interrupted: true };

/** Awaits the call; a thrown error becomes `{ ok: false, error: INTERRUPTED_TEXT }` instead of an unhandled rejection. */
export async function settleAction<T>(call: () => Promise<T>): Promise<T | Interrupted> {
  try {
    return await call();
  } catch {
    return { ok: false, error: INTERRUPTED_TEXT, interrupted: true };
  }
}
