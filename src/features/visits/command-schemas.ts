import { z } from "zod";

export const visitCommandSchema = z.object({
  visitId: z.uuid(),
  idempotencyKey: z.uuid(),
});

export type { CommandResult } from "@/lib/commands/result";
