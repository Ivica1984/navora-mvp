import type { CSSProperties, ReactNode } from "react";

/**
 * UX2-1 (ADR-131): the page background of the pages that used the first-MVP side column (`AppFrame` until UX2). The
 * navigation now comes from the one shell (`AppShell`, rendered by the protected layout); this frame only keeps each
 * page's background and text colour until UX2-3 moves them onto tokens. `min-w-0` lets the content column shrink
 * instead of widening the page (UX1-1).
 */
export function PageFrame({ className, style, children }: { className?: string; style?: CSSProperties; children: ReactNode }) {
  return (
    <div className={`min-h-screen min-w-0 ${className ?? ""}`} style={style}>
      {children}
    </div>
  );
}
