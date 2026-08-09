# rob

A Roblox game in native Luau, set up so that as much as possible is verified
**before** anything touches a Roblox server: strict type-checking, linting,
formatting, headless unit tests, and a headless place build — all runnable on
Linux/CI with zero Roblox credentials.

Working with an AI coding agent? The rules live in [AGENTS.md](AGENTS.md)
(structure, tooling, process) and [STYLE.md](STYLE.md) (error contract,
naming). [CLAUDE.md](CLAUDE.md) imports both for Claude Code; Codex reads them
directly.

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
| `lune run check` | all quality gates (parity, format, lint, types, tests, build) |
| `lune run test` | unit tests only (append `-- --update-snapshots` to refresh snapshots) |
| `lune run analyze` | strict type analysis via luau-lsp (Roblox + Lune passes) |
| `lune run parity` | checks that duplicated config facts have not drifted |
| `lune run update-types` | refresh the pinned Roblox type definitions after bumping luau-lsp |
| `stylua src tests lune` | auto-format |
| `rojo build default.project.json -o build.rbxl` | build the place file |
| `rojo serve` | live-sync into Roblox Studio while editing |

CI runs `lune run check` and nothing else, so anything CI catches is
reproducible locally with one command.

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
