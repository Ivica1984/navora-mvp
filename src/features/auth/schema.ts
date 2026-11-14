import { z } from "zod";

// Pure input schema for the sign-in action — unit-tested.
export const signInSchema = z.object({
  // Normalise first, then validate: in zod 4, z.email().trim() would validate
  // the untrimmed value (checks run in chain order).
  email: z.string().trim().toLowerCase().max(254).pipe(z.email()),
  password: z.string().min(1).max(200),
});

export type SignInState = { error: string | null };

/** One message for every failure, so the form does not reveal which accounts exist. */
export const SIGN_IN_FAILED = "Anmeldung fehlgeschlagen. Bitte Zugangsdaten prüfen.";
