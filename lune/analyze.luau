--!strict
-- Static type analysis via luau-lsp. Two passes:
--   1. src/       — Roblox platform, with Roblox global types + Rojo sourcemap
--   2. tests/lune — standard platform (Lune), with @lune/* typedef aliases
-- Run from the repo root:   lune run analyze

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local GLOBAL_TYPES_URL =
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
local CACHE_DIR = ".cache"
local GLOBAL_TYPES_PATH = `{CACHE_DIR}/globalTypes.d.luau`

local function run(program: string, args: { string }): ()
	print(`\n$ {program} {table.concat(args, " ")}`)
	local result = process.exec(program, args, { stdio = "inherit" })
	if not result.ok then
		print(`error: {program} exited with code {result.code}`)
		process.exit(result.code)
	end
end

if not fs.isDir(CACHE_DIR) then
	fs.writeDir(CACHE_DIR)
end

-- Fetch Roblox global type definitions (cached; delete .cache/ to refresh).
if not fs.isFile(GLOBAL_TYPES_PATH) then
	print(`fetching {GLOBAL_TYPES_URL}`)
	local response = net.request(GLOBAL_TYPES_URL)
	if not response.ok then
		print(`error: failed to download Roblox global types (HTTP {response.statusCode})`)
		process.exit(1)
	end
	fs.writeFile(GLOBAL_TYPES_PATH, response.body)
end

-- The sourcemap lets luau-lsp resolve instance paths the way the engine will.
run("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })

-- Pass 1: game code against the Roblox API surface.
run("luau-lsp", {
	"analyze",
	"--platform",
	"roblox",
	`--definitions:@roblox={GLOBAL_TYPES_PATH}`,
	"--sourcemap",
	"sourcemap.json",
	"--base-luaurc",
	".luaurc",
	"src",
})

-- Pass 2: Lune-world code (tests + task scripts). @lune/* requires resolve via
-- the "lune" alias in .luaurc, which points at the typedefs installed by
-- `lune setup` (~/.lune/.typedefs/<version>/).
local home = process.env.HOME
local typedefsDir = if home then `{home}/.lune/.typedefs` else nil
if typedefsDir == nil or not fs.isDir(typedefsDir) then
	print('error: Lune typedefs not found — run "lune setup" once first')
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
