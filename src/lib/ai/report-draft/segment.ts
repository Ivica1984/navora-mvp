import type { Segment } from "./contract";

/** Upper bound for one typed input. Longer input is refused, never truncated (nothing dropped silently). */
export const MAX_INPUT_CHARS = 8000;
/**
 * AI1 / ADR-227 point 6: the longest text sent to a model. Longer notes are refused for the model before any call is
 * reserved (the rule draft keeps 8,000 characters); nothing is cut.
 */
export const MAX_MODEL_INPUT_CHARS = 4000;

/**
 * Splits typed text into segments: at line breaks, and after «.», «!», «?» or «;» followed by white space.
 * Purely mechanical; it interprets nothing.
 */
export function segmentInput(text: string): Segment[] {
  if (text.length > MAX_INPUT_CHARS) throw new Error("input_too_long");
  const pieces = text
    .split(/\r?\n/)
    .flatMap((line) => line.split(/(?<=[.!?;])\s+/))
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
  return pieces.map((t, n) => ({ id: `s${n + 1}`, text: t }));
}
