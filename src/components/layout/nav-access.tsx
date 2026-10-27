"use client";

import { createContext, useContext, type ReactNode } from "react";
import { NO_ACCESS, type NavAccess } from "@/lib/auth/nav";

// UX1-3 (ADR-103): the protected layout reads the caller's roles once per request and hands them to the menu here.
// Outside the provider the menu shows no item (fail closed).
const NavAccessContext = createContext<NavAccess>(NO_ACCESS);

export function NavAccessProvider({ access, children }: { access: NavAccess; children: ReactNode }) {
  return <NavAccessContext.Provider value={access}>{children}</NavAccessContext.Provider>;
}

export function useNavAccess(): NavAccess {
  return useContext(NavAccessContext);
}
