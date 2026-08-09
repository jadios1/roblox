--!strict
-- IF-CHANGE-THEN-CHANGE gate.
--
-- Some facts unavoidably appear in more than one file: a tool version pinned in
-- rokit.toml also has to appear in .luaurc, an instance name in
-- default.project.json is load-bearing for require-by-string, and CI has to be
-- told what to run. Comments asking people to keep those in sync do not work.
-- This gate fails the build when they drift.
--
-- Run directly:   lune run parity
-- Part of:        lune run check
--
-- Override (rare — an intentional, temporary divergence):
--   ROB_ALLOW_CONFIG_DRIFT=1 lune run check
-- That downgrades every failure here to a warning. If you use it, say why in
-- the commit message; it is not meant to survive a review.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local gates = require("./util/gates")
local pins = require("./util/pins")

type Check = {
	name: string,
	run: () -> string?, -- returns nil when it passes, else the reason it failed
}

local CHECKS: { Check } = {
	{
		-- .luaurc cannot interpolate, so the Lune version is spelled out in the
		-- typedefs alias. Bumping Lune in rokit.toml without editing .luaurc used
		-- to produce a confusing unresolved-alias error instead of a clear one.
		name = ".luaurc lune alias matches the rokit.toml pin",
		run = function(): string?
			local pinned = pins.toolVersion("lune")
			local luaurc = serde.decode("json", fs.readFile(".luaurc")) :: {
				aliases: { [string]: string }?,
			}
			local aliases = luaurc.aliases
			if aliases == nil or aliases.lune == nil then
				return '.luaurc has no "lune" alias'
			end
			local aliased = string.match(aliases.lune, "%.typedefs/([^/]+)")
			if aliased == nil then
				return `cannot read a version out of the .luaurc lune alias "{aliases.lune}"`
			end
			if aliased ~= pinned then
				return `.luaurc points at Lune typedefs {aliased} but rokit.toml pins lune {pinned}`
					.. `\n    fix: set the "lune" alias to "~/.lune/.typedefs/{pinned}/" and run "lune setup"`
			end
			return nil
		end,
	},
	{
		-- The committed Roblox definitions must come from the pinned luau-lsp.
		name = "globalTypes.d.luau matches the rokit.toml luau-lsp pin",
		run = function(): string?
			local pinned = pins.toolVersion("luau-lsp")
			if not fs.isFile(pins.GLOBAL_TYPES_PATH) then
				return `{pins.GLOBAL_TYPES_PATH} is missing`
					.. '\n    fix: run "lune run update-types"'
			end
			local committed = pins.committedGlobalTypesVersion()
			if committed == nil then
				return `{pins.GLOBAL_TYPES_VERSION_PATH} is missing or empty`
					.. '\n    fix: run "lune run update-types"'
			end
			if committed ~= pinned then
				return `{pins.GLOBAL_TYPES_PATH} was taken from luau-lsp {committed} but rokit.toml pins {pinned}`
					.. '\n    fix: run "lune run update-types" and commit both files'
			end
			return nil
		end,
	},
	{
		-- CI must defer to the gate list rather than restating it, so that adding
		-- a gate cannot silently skip CI.
		name = "CI defers to `lune run check`",
		run = function(): string?
			local ci = fs.readFile(".github/workflows/ci.yml")
			if not string.find(ci, "lune run check", 1, true) then
				return "ci.yml does not run `lune run check`"
					.. "\n    fix: make the gate step `run: lune run check`"
			end
			local duplicated: { string } = {}
			for _, gate in gates.GATES do
				local sig = gates.signature(gate)
				if string.find(ci, sig, 1, true) then
					table.insert(duplicated, `{sig} ({gate.name})`)
				end
			end
			if #duplicated > 0 then
				return `ci.yml re-runs gates that "lune run check" already runs:\n      `
					.. table.concat(duplicated, "\n      ")
					.. '\n    fix: delete those steps — CI should only do setup then "lune run check"'
			end
			return nil
		end,
	},
	{
		-- Relative requires in src/server resolve through this mount. Renaming the
		-- instance breaks every `require("../../shared/…")` at runtime, which no
		-- other gate catches.
		name = "default.project.json mounts src/shared where requires expect it",
		run = function(): string?
			local project = serde.decode("json", fs.readFile("default.project.json")) :: {
				tree: { [string]: any }?,
			}
			local tree = project.tree
			if tree == nil then
				return "default.project.json has no tree"
			end

			local expected = {
				{ service = "ServerScriptService", name = "shared" },
				{ service = "ReplicatedStorage", name = "shared" },
			}
			for _, mount in expected do
				local service = tree[mount.service]
				if service == nil then
					return `default.project.json has no {mount.service}`
				end
				local entry = service[mount.name]
				if entry == nil or entry["$path"] ~= "src/shared" then
					return `{mount.service}.{mount.name} must mount "src/shared"`
						.. "\n    this name is load-bearing for require-by-string — see AGENTS.md"
				end
			end

			local sss = tree.ServerScriptService
			if sss.Server == nil or sss.Server["$path"] ~= "src/server" then
				return 'ServerScriptService.Server must mount "src/server" so that'
					.. ' `require("../../shared/…")` resolves to the sibling shared mount'
			end
			return nil
		end,
	},
}

local allowDrift = process.env.ROB_ALLOW_CONFIG_DRIFT == "1"
local failures = 0

for _, check in CHECKS do
	local reason = check.run()
	if reason == nil then
		print(`  [ok] {check.name}`)
	else
		failures += 1
		print(`  [{if allowDrift then "warn" else "FAIL"}] {check.name}`)
		print(`    {reason}`)
	end
end

if failures == 0 then
	print("\nconfig parity: everything agrees")
elseif allowDrift then
	print(`\nconfig parity: {failures} problem(s) ignored via ROB_ALLOW_CONFIG_DRIFT=1`)
else
	print(`\nconfig parity: {failures} problem(s)`)
	print("override for an intentional divergence: ROB_ALLOW_CONFIG_DRIFT=1")
	process.exit(1)
end
