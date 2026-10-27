// UX1-18 (ADR-106, `uxa` UXR-15): the secondary-text colour for pages still written with inline styles (/teams,
// /visits, /partners, /operations). Same value as the `text-secondary` class (globals.css: stone-700, at least 4.5:1
// on white and #f4f7f4); the hex fallback is Tailwind's stone-700. The old inline greys (#6b8075, #5f766d, #6d857c,
// #6B7280) were below 4.5:1 on #f4f7f4; tests/unit/ux1-contrast.test.ts keeps them out.
export const SECONDARY_TEXT = "var(--color-stone-700, #44403b)";
