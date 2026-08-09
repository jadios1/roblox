--!strict
-- Static type analysis via luau-lsp. Two passes:
--   1. src/       — Roblox platform, with Roblox global types + Rojo sourcemap
--   2. tests/lune — standard platform (Lune), with @lune/* typedef aliases
-- Run from the repo root:   lune run analyze
--
-- This script does no network I/O. globalTypes.d.luau is committed and pinned
-- to the luau-lsp version in rokit.toml, for the same reason roblox.yml is
-- committed: a gate that downloads its own inputs from a moving branch is not
-- a gate — it can fail or pass for reasons that are not in the repo.
-- Refresh it with `lune run update-types` after bumping luau-lsp.

local fs = require("@lune/fs")
local process = require("@lune/process")

local pins = require("./util/pins")

local function run(program: string, args: { string }): ()
	print(`\n$ {program} {table.concat(args, " ")}`)
	local result = process.exec(program, args, { stdio = "inherit" })
	if not result.ok then
		print(`error: {program} exited with code {result.code}`)
		process.exit(result.code)
	end
end

if not fs.isFile(pins.GLOBAL_TYPES_PATH) then
	print(`error: {pins.GLOBAL_TYPES_PATH} is missing — run "lune run update-types"`)
	process.exit(1)
end

-- The sourcemap lets luau-lsp resolve instance paths the way the engine will.
run("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })

-- Pass 1: game code against the Roblox API surface.
run("luau-lsp", {
	"analyze",
	"--platform",
	"roblox",
	`--definitions:@roblox={pins.GLOBAL_TYPES_PATH}`,
	"--sourcemap",
	"sourcemap.json",
	"--base-luaurc",
	".luaurc",
	"src",
})

-- Pass 2: Lune-world code (tests + task scripts). @lune/* requires resolve via
-- the "lune" alias in .luaurc, which points at the typedefs installed by
-- `lune setup`. The alias is version-pinned, so check that exact directory —
-- checking only the parent would let a Lune bump produce an unresolved-alias
-- error instead of this message. The parity gate keeps the pin honest.
local home = process.env.HOME
local luneVersion = pins.toolVersion("lune")
local typedefsDir = if home then `{home}/.lune/.typedefs/{luneVersion}` else nil
if typedefsDir == nil or not fs.isDir(typedefsDir) then
	print(`error: Lune {luneVersion} typedefs not found at {typedefsDir or "$HOME (unset)"}`)
	print('       run "lune setup" once with the pinned Lune version')
	process.exit(1)
end

run("luau-lsp", {
	"analyze",
	"--platform",
	"standard",
	"--base-luaurc",
	".luaurc",
	"tests",
	"lune",
})

print("\nanalyze: all passes clean")
