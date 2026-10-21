import { z } from "zod";

export const visitIdSchema = z.object({ visitId: z.uuid() });

export type CommandResult = { ok: true } | { ok: false; error: string };
