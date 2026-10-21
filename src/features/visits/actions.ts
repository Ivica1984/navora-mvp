"use server";

import { revalidatePath } from "next/cache";
import { supabase } from "@/lib/supabase";

export async function startVisit(visitId: string) {
  const { error } = await supabase
    .from("care_visits")
    .update({
      status: "started",
    })
    .eq("id", visitId);

  if (error) {
    console.error("Error starting visit:", error);
    throw new Error("Einsatz konnte nicht gestartet werden.");
  }

  revalidatePath("/visits");
}
