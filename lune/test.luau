--!strict
-- Unit test runner: discovers tests/**/*.spec.luau and runs them with tiniest.
-- Run from the repo root:   lune run test [-- --update-snapshots]
-- Each spec module returns `function(t: Tiniest)` and registers describe/test
-- blocks on the passed-in instance.

local fs = require("@lune/fs")
local process = require("@lune/process")

local tiniest_for_lune = require("@tiniest/tiniest_for_lune")

if not fs.isDir("tests") then
	print("error: no ./tests directory — run this from the repository root")
	process.exit(1)
end

local function findSpecs(dir: string, found: { string }): { string }
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			findSpecs(path, found)
		elseif name:match("%.spec%.luau$") then
			table.insert(found, path)
		end
	end
	return found
end

local specPaths = findSpecs("tests", {})
table.sort(specPaths)

if #specPaths == 0 then
	print(
		"error: found no tests/**/*.spec.luau files — discovery is broken or tests were deleted"
	)
	process.exit(1)
end

local updateSnapshots = table.find(process.args, "--update-snapshots") ~= nil

local tiniest = tiniest_for_lune.configure({
	snapshot_path = "tests/__snapshots__",
	save_snapshots = updateSnapshots,
})

local tests = tiniest.collect_tests(function()
	for _, path in specPaths do
		-- Requires are resolved relative to this file, hence the leading "../".
		local requirePath = "../" .. path:gsub("%.luau$", "")
		local suite = (require :: any)(requirePath)
		tiniest.describe(path, function()
			suite(tiniest)
		end)
	end
end)

local report = tiniest.run_tests(tests, {})
process.exit(if report.status_tally.fail > 0 then 1 else 0)
