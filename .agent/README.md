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
rokit install     # installs all pinned tools
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

## Layout

- `src/shared` — pure game logic (no Roblox APIs; unit-tested under Lune)
- `src/server` — services (pure, dependency-injected, tested) + adapters/composition root (thin Roblox glue)
- `src/client` — thin client glue
- `src/world` — source-controlled static Workspace content managed by Rojo
- `tests` — [tiniest](https://github.com/dphfox/tiniest) specs + fakes
- `lune` — task scripts and vendored libs
- `docs/cloud-integration-tests.md` — planned Roblox Open Cloud test harness (not wired up yet)

## Quality Gates

- `config parity` - All duplicated facts have been set
- `format` - Styling is compliant
- `lint` - No undefined globals, no suspicious code
- `types` - No strict Luau type errors
- `unit tests` - No unit tests (client is not unit tested)
- `build` - Build succeeded

## Testing

- All tests are in `tests/Currency/`
- Tests are deterministic and do not depend on real time
- Tests use fakes for service construction
- Client is not unit tested (only renders results)
