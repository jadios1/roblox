--!strict
-- Refreshes the committed Roblox type definitions to match the luau-lsp version
-- pinned in rokit.toml. This is the ONLY thing that touches the network, and it
-- is deliberately not a gate — run it by hand after bumping luau-lsp:
--
--   lune run update-types
--
-- Then re-run `lune run check` and commit both globalTypes.d.luau and
-- globalTypes.version. The parity gate fails until those agree with rokit.toml.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local pins = require("./util/pins")

local version = pins.toolVersion("luau-lsp")
local url = pins.globalTypesUrl(version)

print(`fetching Roblox type definitions for luau-lsp {version}`)
print(`  {url}`)

local response = net.request(url)
if not response.ok then
	print(`error: download failed (HTTP {response.statusCode})`)
	print("       check that the luau-lsp version in rokit.toml is a real release tag")
	process.exit(1)
end

fs.writeFile(pins.GLOBAL_TYPES_PATH, response.body)
fs.writeFile(pins.GLOBAL_TYPES_VERSION_PATH, `{version}\n`)

print(`\nwrote {pins.GLOBAL_TYPES_PATH} ({#response.body} bytes)`)
print(`wrote {pins.GLOBAL_TYPES_VERSION_PATH} ({version})`)
print('\nnow run "lune run check" and commit both files')
