import { z } from "zod";

// Input schemas for team commands. Kept out of commands.ts because a
// "use server" module may only export async functions.

export const setTeamPrioritySchema = z.object({
  teamId: z.uuid(),
  priority: z.boolean(),
});

export const assignTeamCoachSchema = z.object({
  teamId: z.uuid(),
  coachName: z.string().trim().min(1).max(120),
});

export type CommandResult = { ok: true } | { ok: false; error: string };
