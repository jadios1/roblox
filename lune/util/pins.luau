--!strict
-- Reads the pinned tool versions out of rokit.toml so scripts never restate a
-- version that is already declared there. Anything that needs to agree with a
-- pin should read it from here and let `lune run check` enforce the agreement
-- (see the config parity gate in lune/parity.luau).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local ROKIT_MANIFEST = "rokit.toml"

local pins = {}

pins.GLOBAL_TYPES_PATH = "globalTypes.d.luau"
pins.GLOBAL_TYPES_VERSION_PATH = "globalTypes.version"

-- Returns the version of a tool as pinned in rokit.toml, e.g. "1.68.1" for
-- `luau-lsp = "JohnnyMorganz/luau-lsp@1.68.1"`.
function pins.toolVersion(tool: string): string
	local manifest = serde.decode("toml", fs.readFile(ROKIT_MANIFEST)) :: {
		tools: { [string]: string }?,
	}
	local tools = manifest.tools
	assert(tools, `{ROKIT_MANIFEST} has no [tools] table`)

	local spec = tools[tool]
	assert(spec, `{ROKIT_MANIFEST} does not pin a tool named "{tool}"`)

	local version = string.match(spec, "@(.+)$")
	assert(version, `cannot read a version out of "{spec}" in {ROKIT_MANIFEST}`)
	return version
end

-- The luau-lsp release tag that globalTypes.d.luau was taken from. Note the tag
-- has no "v" prefix.
function pins.globalTypesUrl(luauLspVersion: string): string
	return `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{luauLspVersion}/scripts/globalTypes.d.luau`
end

-- The version recorded alongside the committed definitions, or nil if missing.
function pins.committedGlobalTypesVersion(): string?
	if not fs.isFile(pins.GLOBAL_TYPES_VERSION_PATH) then
		return nil
	end
	local contents = fs.readFile(pins.GLOBAL_TYPES_VERSION_PATH)
	local trimmed = string.match(contents, "^%s*(.-)%s*$")
	if trimmed == nil or trimmed == "" then
		return nil
	end
	return trimmed
end

return pins
