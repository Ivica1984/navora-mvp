import { z } from "zod";

// Input schemas for team commands. Kept out of commands.ts because a
// "use server" module may only export async functions.
// idempotencyKey: one random UUID per user action (crypto.randomUUID() in the
// client); a replay of the same key changes nothing (T10).

export const setTeamPrioritySchema = z.object({
  teamId: z.uuid(),
  priority: z.boolean(),
  idempotencyKey: z.uuid(),
});

export const assignTeamCoachSchema = z.object({
  teamId: z.uuid(),
  coachName: z.string().trim().min(1).max(120),
  idempotencyKey: z.uuid(),
});

export type { CommandResult } from "@/lib/commands/result";
