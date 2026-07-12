# rob

A Roblox game in native Luau, set up so that as much as possible is verified
**before** anything touches a Roblox server: strict type-checking, linting,
formatting, headless unit tests, and a headless place build — all runnable on
Linux/CI with zero Roblox credentials.

Working with an AI coding agent? The rules live in [AGENTS.md](AGENTS.md)
(Codex et al.) and [CLAUDE.md](CLAUDE.md) (Claude Code — imports the same file).

## Quickstart

1. Install [Rokit](https://github.com/rojo-rbx/rokit) (toolchain manager).
2. Then:

```sh
rokit install     # installs pinned Rojo, StyLua, selene, luau-lsp, Lune
lune setup        # one-time: @lune/* type definitions
lune run check    # run every quality gate
```

## Commands

| Command | What it does |
|---|---|
| `lune run check` | all quality gates (format, lint, types, tests, build) |
| `lune run test` | unit tests only (append `-- --update-snapshots` to refresh snapshots) |
| `lune run analyze` | strict type analysis via luau-lsp (Roblox + Lune passes) |
| `stylua src tests lune` | auto-format |
| `rojo build default.project.json -o build.rbxl` | build the place file |
| `rojo serve` | live-sync into Roblox Studio while editing |

## Layout

- `src/shared` — pure game logic (no Roblox APIs; unit-tested under [Lune](https://github.com/lune-org/lune))
- `src/server` — services (pure, dependency-injected, tested) + adapters/composition root (thin Roblox glue)
- `src/client` — thin client glue
- `tests` — [tiniest](https://github.com/dphfox/tiniest) specs + fakes
- `lune` — task scripts and vendored libs
- `docs/cloud-integration-tests.md` — planned Roblox Open Cloud test harness (not wired up yet)

The example feature slice (player currency: `Wallet` + `CurrencyService` +
`DataStoreAdapter`) demonstrates the architecture every new feature should
follow — pure logic in shared, effects behind injected interfaces, glue kept
too thin to need tests.
