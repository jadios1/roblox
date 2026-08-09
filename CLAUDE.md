@AGENTS.md
@STYLE.md

## Claude Code specifics

- The canonical project instructions are in AGENTS.md and STYLE.md (imported
  above): AGENTS.md owns structure, tooling and process; STYLE.md owns the
  error contract and naming. Keep the shared body there so Codex sees the same
  rules; put only Claude-specific notes in this file.
- Quality gates are non-negotiable: run `lune run check` before reporting any
  task as complete, and paste the summary block into your final report.
- When exploring the Roblox API surface, prefer reading the committed
  `globalTypes.d.luau` at the repo root over recalling APIs from training data.
  It is pinned to the luau-lsp version in `rokit.toml`.
