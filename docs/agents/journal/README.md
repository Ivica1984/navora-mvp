# Agent journal (one file per entry)

Owner decision FE-053 (2026-11-10). Replaces new entries in [`../JOURNAL.md`](../JOURNAL.md), which stays as the archive up to 2026-11-10 22:27.

- **One file per entry:** `YYYY-MM-DD-HHMM-<role>.md`, time in Europe/Zurich (when the entry is written), role as in the README (`po`, `eng`, `cra`, `lca`, `uxa`, `aia`, `csa`). Example: `2026-11-10-2227-po.md`. Two entries of one role in the same minute: add `-2`.
- **Content:** exactly one entry, starting with `## <YYYY-MM-DD> <HH:MM> CET · <role> (...)` (CEST in summer), then the text as before.
- **Newest first** = file names sorted descending (`ls -r docs/agents/journal`).
- **Never edited afterwards;** a correction is a new file. Never change another role's file.
- **Why:** every role wrote at the top of one shared file, so every PR conflicted with every other one (42 of 148 commits on `recovery/main` in 24 h were conflict merges).
- **No personal or health data.**
