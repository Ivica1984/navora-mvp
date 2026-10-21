"use server";

import { redirect } from "next/navigation";
import { HOME_PATH, LOGIN_PATH } from "@/lib/auth/paths";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SIGN_IN_FAILED, signInSchema, type SignInState } from "./schema";
import { errorFields, logEvent } from "@/lib/log";

export async function signIn(
  _previous: SignInState,
  formData: FormData
): Promise<SignInState> {
  const parsed = signInSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!parsed.success) {
    return { error: SIGN_IN_FAILED };
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);

  if (error) {
    // Log the category only — never the e-mail address or password.
    logEvent("warn", "auth.sign_in_failed", errorFields(error));
    return { error: SIGN_IN_FAILED };
  }

  // Fixed destination: no user-controlled redirect target (no open redirect).
  redirect(HOME_PATH);
}

export async function signOut(): Promise<void> {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect(LOGIN_PATH);
}
