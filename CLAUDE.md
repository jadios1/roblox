@AGENTS.md

## Claude Code specifics

- The canonical project instructions are in AGENTS.md (imported above). Keep
  the shared body there so Codex sees the same rules; put only
  Claude-specific notes in this file.
- Quality gates are non-negotiable: run `lune run check` before reporting any
  task as complete, and paste the summary block into your final report.
- When exploring the Roblox API surface, prefer reading
  `.cache/globalTypes.d.luau` (created by `lune run analyze`) over recalling
  APIs from training data.
