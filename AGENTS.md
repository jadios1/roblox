# rob — agent instructions

Roblox game written in native Luau. This file is the canonical instruction set
for ALL coding agents. Codex reads it directly; Claude Code reads it through
`CLAUDE.md`, which is a symlink to this file. Keep it up to date: when you
change tooling, structure, or policy, update this file in the same commit.

Split of responsibilities: **this file** owns structure, tooling and process.
**[STYLE.md](STYLE.md)** owns the error contract (throw vs return), naming and
commenting. Read both before writing code.

@STYLE.md

## Project map

```
src/shared/    Pure Luau only. No Roblox globals (game, Instance, task, …).
               Runs under Lune. This is where game logic lives.
src/server/    Services/  — pure orchestration, all effects behind injected deps (Lune-testable)
               Adapters/  — thin wrappers around Roblox services (DataStore, …); NO logic
               init.server.luau — composition root; the only place adapters get wired in
src/client/    Thin rendering/input glue. No game logic.
tests/         Lune unit tests (*.spec.luau) + fakes in tests/helpers/
lune/          Task scripts (`lune run <name>`); shared helpers in lune/util/
               and vendored libs in lune/lib/
docs/          Design notes, including the cloud integration test stub
```

Committed at the repo root: `roblox.yml` (pinned selene std) and
`globalTypes.d.luau` + `globalTypes.version` (pinned Roblox type definitions).
Both are generated files kept in git on purpose — see Guardrails.

Layer rules (enforced by review, not tooling — do not break them):

1. `src/shared/**` and `src/server/Services/**` must never touch a Roblox
   global. If code needs a Roblox service, define a minimal structural
   interface (see `StoreLike` in `CurrencyService.luau`), implement it in
   `src/server/Adapters/`, and inject it from the composition root.
2. Adapters contain zero logic — one Roblox API call per method, nothing else.
   Logic in an adapter is logic you can't test.
3. Composition roots (`init.server.luau`, `init.client.luau`) only wire things
   together. If a root grows logic, extract it into a service.

## Quality gates — always run them

**Before considering ANY work done, run `lune run check` from the repo root
and get every gate green.** No exceptions, including "trivial" changes.

| Gate | Command | What it catches |
|---|---|---|
| config parity | `lune run parity` | duplicated facts drifting apart (see below) |
| format | `stylua --check src tests lune` | style drift |
| lint | `selene src tests lune` | undefined globals, suspicious code |
| types | `lune run analyze` | strict Luau type errors vs real Roblox/Lune APIs |
| unit tests | `lune run test` | behavior regressions |
| build | `rojo build default.project.json --output build.rbxl` | invalid project/instance tree |

**The gate list lives in one place: `lune/util/gates.luau`.** Add a gate there
and it runs locally and in CI automatically. CI does setup and then runs
`lune run check` — nothing else. Never add a gate step to `ci.yml`; the parity
gate fails the build if you do.

`stylua src tests lune` (no `--check`) auto-fixes formatting.
`lune run test -- --update-snapshots` refreshes tiniest snapshots.

### Config parity (IF-CHANGE-THEN-CHANGE)

A few facts unavoidably appear in two files. `lune run parity` fails when they
drift, so a stale copy is a build failure rather than a confusing error later:

| If you change | You must also change |
|---|---|
| `lune` pin in `rokit.toml` | the `lune` typedefs alias in `.luaurc`, then `lune setup` |
| `luau-lsp` pin in `rokit.toml` | run `lune run update-types`, commit both `globalTypes.*` |
| the gate list | nothing — but do not re-add gate steps to `ci.yml` |
| mount names in `default.project.json` | see the require rules below; the names are load-bearing |

For a deliberate, temporary divergence: `ROB_ALLOW_CONFIG_DRIFT=1 lune run check`
downgrades parity failures to warnings. Say why in the commit message — it is
not meant to survive review.

## Guardrails

- **Never trust your memorized knowledge of library versions or APIs.** The
  Roblox toolchain moves fast and your training data is stale. Before adding,
  upgrading, or writing code against any tool or library: check the actual
  GitHub releases page / registry entry / `--help` output / bundled type
  definitions, and pin exact versions. This applies to Roblox engine APIs too
  — verify against the committed `globalTypes.d.luau` rather than assuming a
  method exists.
- **Gates must not download their own inputs.** `roblox.yml` and
  `globalTypes.d.luau` are committed so that a check can only fail for reasons
  that are in the repo. `lune run update-types` is the one script allowed to
  touch the network, and it is not a gate — run it by hand after bumping
  `luau-lsp` and commit the result.
- **All tools are pinned in `rokit.toml`.** Install with `rokit install`;
  never install ad-hoc tool versions or invoke tools not listed there. To
  upgrade a tool: verify the new version's release notes, bump `rokit.toml`,
  run all gates, and note anything that changed behavior.
- **Do not commit generated artifacts**: `build.rbxl`, `sourcemap.json`,
  `.cache/` are gitignored — keep it that way. `roblox.yml` (pinned selene std;
  refresh with `selene update-roblox-std`) and `globalTypes.d.luau` /
  `globalTypes.version` (pinned Roblox types; refresh with
  `lune run update-types`) ARE committed on purpose.
- **Never edit `lune/lib/**` (vendored third-party code).** See
  `lune/lib/tiniest/VENDOR.md` for how to update it.
- **Secrets never enter this repo.** Roblox Open Cloud API keys live in
  GitHub Actions secrets / local env vars only.

## Require rules (important — two runtimes, one style)

- Inside `src/**`: **relative string requires only** — `require("./Sibling")`,
  `require("../../shared/Currency")`. In an `init.luau`, a child of the module
  is `require("@self/Child")`. These resolve identically in the Roblox engine
  (require-by-string) and Lune because `default.project.json` mounts
  `src/shared` as a sibling of `src/server` inside ServerScriptService.
  Do NOT use `.luaurc` aliases in `src/**` — engine support for aliases is not
  established.
- **The mount names in `default.project.json` are load-bearing.** A server file
  resolving `require("../../shared/Currency")` walks up out of
  `ServerScriptService.Server` and looks for a sibling named exactly `shared` —
  lowercase, matching the on-disk directory. Renaming that instance (or
  `Server`) breaks every server require at runtime, which no other gate
  catches, so the parity gate asserts both mounts. `src/shared` is mounted
  twice on purpose (ReplicatedStorage for the client, ServerScriptService for
  the server). Consequence: they are two distinct instance trees with separate
  require caches. Fine while shared modules are stateless — but a shared module
  holding module-level state would have one copy per side, so keep state in
  services, not in shared modules.
- Inside `tests/**` and `lune/**` (Lune-only code): aliases from `.luaurc` are
  fine and preferred: `@shared/...`, `@server/...`, `@tiniest/...`, plus the
  Lune builtins `@lune/fs`, `@lune/process`, etc.
- Composition roots and adapters may use classic instance access
  (`game:GetService(...)`) — they are Roblox-only glue.

## Luau strict-mode notes

- All code is `--!strict` (set project-wide in `.luaurc`).
- Don't compare metatable-based types (e.g. `Wallet`) against `nil` with
  `==`/`~=` — strict Luau rejects it ("do not have the same metatable").
  Use truthiness: `if not wallet then`.
- No gate is ever skipped: a missing tool makes its gate FAIL, it does not pass
  quietly. If `rokit install` has not been run, expect failures rather than a
  green summary — read the summary block, do not assume it.

## Testing policy

- Every module in `src/shared/**` gets a spec in `tests/**` mirroring its
  path (`src/shared/Currency/Wallet.luau` → `tests/Currency/Wallet.spec.luau`).
- Every service in `src/server/Services/**` gets a spec that constructs it
  with fakes (see `tests/helpers/FakeDataStore.luau`). If you can't construct
  a service without Roblox, its design is wrong — extract an adapter.
- Spec format: the file returns `function(t)` and registers
  `t.describe`/`t.test` blocks; the runner (`lune/test.luau`) discovers
  `tests/**/*.spec.luau` automatically — no registration list to maintain.
- Adapters and composition roots are NOT unit-tested. They stay thin and are
  covered by cloud integration tests later
  (see `docs/cloud-integration-tests.md` — not wired up yet).
- Tests must be deterministic: no timing dependence, no ordering dependence.
  Inject clocks/randomness as deps if a feature needs them. `CurrencyService`
  takes `wait` and `log` for exactly this reason — retries and recovery
  reporting are asserted without real time passing or real output.
- **A test you have not seen fail proves nothing.** After writing a test for a
  behavior, break that behavior on purpose and confirm the test goes red, then
  restore it. This catches tests whose setup makes the bug unreachable, which
  is a real failure mode here: an earlier version of the "refuses to overwrite
  unreadable data" spec passed even with the guard removed, because the fake
  was failing every write anyway.

## Dependency policy

There are currently **zero runtime dependencies** — do not add one casually.
When a real need appears (e.g. a persistence library with session locking):

1. Check the package exists and is maintained on the **pesde** registry
   (https://pesde.dev) — pesde is the active package manager for Luau
   (Wally is stale since 2024; pesde can also consume Wally packages).
2. Verify the version you're adding against its actual release notes.
3. Add pesde itself to `rokit.toml` (verify its current version first),
   commit the manifest + lockfile, and update this section.

Vendored code (currently only `tiniest`) lives in `lune/lib/` with a
`VENDOR.md` recording provenance.

## Toolchain reference

Pinned in `rokit.toml` (see that file for exact versions): Rojo (build/sync),
StyLua (format), selene (lint), luau-lsp (type analysis), Lune (Luau runtime
for tests/scripts). Bootstrap on a fresh machine:

```sh
# install rokit once: https://github.com/rojo-rbx/rokit
rokit install     # installs all pinned tools
lune setup        # installs @lune/* type definitions (once per Lune version)
lune run check    # everything should be green before you start work
```

## Roblox-facing work (out of local scope)

Anything that needs a real Roblox server — DataStore behavior, replication,
Player lifecycle — is validated via Roblox Open Cloud, not locally. The
planned harness is documented in `docs/cloud-integration-tests.md`. Until it
exists, keep Roblox-touching code inside adapters/roots so the untestable
surface stays minimal.

Known gaps in the persistence slice, deliberately not solved yet — do not
copy the omission into a new feature without noting it:

- **No session locking.** Two servers holding the same player can still clobber
  each other. `SetAsync` is used where a real game needs `UpdateAsync` plus a
  lock, or a maintained persistence library (see the dependency policy).
- **No balance ceiling.** `Wallet` accepts any positive integer, so past 2^53
  a deposit silently stops changing the balance instead of failing loudly.
- The shutdown flush (`BindToClose` → `unloadAll`) is unit-tested but its
  interaction with Roblox's shutdown deadline is not — that needs the cloud
  harness.
