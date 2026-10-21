import { z } from "zod";

// Pure input schema for the sign-in action — unit-tested.
export const signInSchema = z.object({
  email: z.email().trim().toLowerCase().max(254),
  password: z.string().min(1).max(200),
});

export type SignInState = { error: string | null };

/** One message for every failure, so the form does not reveal which accounts exist. */
export const SIGN_IN_FAILED = "Anmeldung fehlgeschlagen. Bitte Zugangsdaten prüfen.";
