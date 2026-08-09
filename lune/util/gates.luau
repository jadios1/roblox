--!strict
-- The single definition of what "the quality gates" are.
--
-- lune/check.luau runs this list. lune/parity.luau reads the same list to prove
-- CI has not started reimplementing it. Adding a gate here is therefore enough:
-- it runs locally and in CI, and nothing else needs editing.

export type Gate = {
	name: string,
	program: string,
	args: { string },
}

local GATES: { Gate } = {
	-- Cheapest first: config drift is a one-line failure, so surface it before
	-- spending time on analysis and tests.
	{ name = "config parity", program = "lune", args = { "run", "parity" } },
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

-- A short signature used to spot a gate being re-run by hand somewhere else,
-- e.g. "stylua --check", "rojo build", "lune run test".
--
-- Two args, not one: every Lune gate starts "lune run", so a one-arg signature
-- would make them all identical and match `lune run check` itself — the parity
-- check would then quietly verify nothing.
local function signature(gate: Gate): string
	local parts = { gate.program }
	for index = 1, math.min(2, #gate.args) do
		table.insert(parts, gate.args[index])
	end
	return table.concat(parts, " ")
end

return {
	GATES = GATES,
	signature = signature,
}
