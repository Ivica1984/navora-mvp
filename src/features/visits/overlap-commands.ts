"use server";

// VIS2-1 / VIS2-2 (ADR-121, migration 0098): the one read path behind the overlap sentence in the /team planning form,
// the /team move and "Heute machen" on /field. The database answers only a caller who may already read the client and
// never shows another team's visit in detail; this only validates input and parses the answer. It writes nothing.

import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { parseOverlapFact, type OverlapFact } from "@/features/visits/overlap-rules";

const time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
const overlapSchema = z
  .object({
    caseId: z.uuid().nullable(),
    visitId: z.uuid().nullable(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    start: time,
    end: time,
  })
  .refine((d) => d.caseId !== null || d.visitId !== null);

export async function getClientOverlapFact(input: unknown): Promise<OverlapFact> {
  const parsed = overlapSchema.safeParse(input);
  // An incomplete slot (still typing) has no answer: no sentence, no request.
  if (!parsed.success || parsed.data.end <= parsed.data.start) return null;
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("client_visit_overlap", {
    // Generated RPC types mark every argument as required; null = not given (the database derives the case).
    p_case_id: d.caseId as string,
    p_visit_id: d.visitId as string,
    p_visit_date: d.date,
    p_time_start: d.start,
    p_time_end: d.end,
  });
  if (error) {
    logEvent("warn", "query.failed", { op: "client_visit_overlap", ...errorFields(error) });
    return null;
  }
  return parseOverlapFact(data);
}
