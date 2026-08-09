--!strict
-- THE quality gate. Runs every check the project has; all of them must pass
-- before any change is considered done (see AGENTS.md).
-- Run from the repo root:   lune run check
--
-- The gate list lives in lune/util/gates.luau because the parity gate reads it
-- too. CI runs this script and nothing else, so adding a gate there is all it
-- takes to have it enforced everywhere.

local process = require("@lune/process")

local gates = require("./util/gates")

local failed: { string } = {}

for _, gate in gates.GATES do
	print(`\n=== {gate.name} ===`)
	local result = process.exec(gate.program, gate.args, { stdio = "inherit" })
	if not result.ok then
		table.insert(failed, gate.name)
	end
end

print("\n=== summary ===")
for _, gate in gates.GATES do
	local status = if table.find(failed, gate.name) then "FAIL" else "ok"
	print(`  [{status}] {gate.name}`)
end

if #failed > 0 then
	print(`\n{#failed} gate(s) failed`)
	process.exit(1)
end
print("\nall gates passed")
