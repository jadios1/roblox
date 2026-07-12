--!strict
-- THE quality gate. Runs every check the project has; all of them must pass
-- before any change is considered done (see AGENTS.md).
-- Run from the repo root:   lune run check

local process = require("@lune/process")

type Gate = {
	name: string,
	program: string,
	args: { string },
}

local GATES: { Gate } = {
	{ name = "format (stylua)", program = "stylua", args = { "--check", "src", "tests", "lune" } },
	{ name = "lint (selene)", program = "selene", args = { "src", "tests", "lune" } },
	{ name = "types (luau-lsp)", program = "lune", args = { "run", "analyze" } },
	{ name = "unit tests (tiniest)", program = "lune", args = { "run", "test" } },
	{
		name = "build (rojo)",
		program = "rojo",
		args = { "build", "default.project.json", "--output", "build.rbxl" },
	},
}

local failed: { string } = {}

for _, gate in GATES do
	print(`\n=== {gate.name} ===`)
	local result = process.exec(gate.program, gate.args, { stdio = "inherit" })
	if not result.ok then
		table.insert(failed, gate.name)
	end
end

print("\n=== summary ===")
for _, gate in GATES do
	local status = if table.find(failed, gate.name) then "FAIL" else "ok"
	print(`  [{status}] {gate.name}`)
end

if #failed > 0 then
	print(`\n{#failed} gate(s) failed`)
	process.exit(1)
end
print("\nall gates passed")
