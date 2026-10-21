# Agent journal

Newest first. One short entry per session or hand-off: date and time (Europe/Zurich), role, what changed, what the next agent should know. Never edit old entries; correct them with a new entry.

---

## 2026-10-21 18:40 · eng (Lead Engineer)
- The owner approved the multi-agent coordination model. **Official layer:** `docs/agents/NEXT_CAPABILITY.md` (PO), `IMPLEMENTATION_STATUS.md` (eng), `OPEN_DECISIONS.md` (all). Protocol in `README.md`; CI validates the files (`npm run agents:check`).
- The owner approved the PO priority order **F0 → J1 → J2 → J3**. The PO briefs are **not** in the repository (COORD-1).
- J1, J2 and J3 were already delivered from `ARCHITECTURE.md` / `DOMAIN_RULES` (PRs #23–#25) before the briefs were visible. They need PO acceptance against the briefs.
- F0 is blocked until its brief exists. Proposals waiting for the PO: J4 (team capacity), F6 (visit report), see COORD-2.
- Next agent: if `briefs/F0.md` exists, start F0. Otherwise check COORD-1 and COORD-2 and continue with whatever the PO queue says.
