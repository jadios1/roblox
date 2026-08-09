# rob — code style

Conventions that formatters and linters can't enforce. StyLua owns layout and
selene owns lint; this file owns the decisions they can't make. Read it
alongside [AGENTS.md](AGENTS.md), which owns structure, tooling and process.

## Error contract

Every failure in this codebase is one of exactly two kinds. Deciding which one
you have is the first thing to do when writing a function that can fail.

### 1. Expected failures — return them, never throw

Bad input from a player, a rejected business rule, unreadable persisted data, a
DataStore request that failed. These are ordinary outcomes of a correct
program. The caller is expected to handle them.

- An operation that succeeds or fails returns `(ok: boolean, err: string?)`.
- An operation that produces a value returns `(value: T?, err: string?)`.
- Exactly one of the two results is non-nil. Never return `(nil, nil)` to mean
  "nothing happened" — add an explicit result type if you need a third state.

```lua
function Wallet.withdraw(self: Wallet, amount: number): (boolean, string?)
	if amount > self._balance then
		return false, "insufficient funds"
	end
	self._balance -= amount
	return true, nil
end
```

Where a failure needs to carry more than a message, or where "no value" and
"failed" are genuinely different states, use a tagged result table instead of
overloading `nil`:

```lua
export type LoadResult = { ok: true, data: unknown } | { ok: false, err: string }
```

`data` being `nil` inside an `ok` result means "no record exists" — which is
not an error. That distinction is exactly why this type is tagged.

### 2. Programmer errors — assert, as early as possible

A dependency wired up wrong, an invariant broken by our own code, a constructor
handed a value that only our code could have produced. These are bugs. They
should stop the program loudly rather than degrade.

- Use `assert` with a message describing the requirement.
- **Assert at construction time, not at use time.** A service given a bad
  `startingBalance` must fail when it is constructed in the composition root —
  at server startup, where it is one obvious crash — not later inside a
  `PlayerAdded` handler, where it is an intermittent failure affecting one
  player at a time.

```lua
function CurrencyService.new(deps: Deps): CurrencyService
	local startingBalance = deps.startingBalance or DEFAULT_STARTING_BALANCE
	assert(
		startingBalance >= 0 and startingBalance == math.floor(startingBalance),
		"startingBalance must be a non-negative integer"
	)
	-- ...
end
```

### 3. No Roblox error crosses a layer boundary

Roblox APIs that throw (DataStore, HttpService, MarketplaceService, …) are
called only inside `src/server/Adapters/**`, and the adapter `pcall`s them and
converts the result into a kind-1 return value. A service must never have to
`pcall` anything: if it does, effects have leaked into it.

This is what keeps services testable — a fake can return a failure result, but
it cannot realistically reproduce a Roblox runtime error.

### 4. Failures that nobody is waiting for go to an injected log

A service that wants to report something it recovered from takes a
`log: ((message: string) -> ())?` dependency rather than calling `print` or
`warn`. Composition roots pass the real logger; tests pass a collector and
assert on it. Never call `print`/`warn` from `src/shared/**` or
`src/server/Services/**` — it is an untestable side effect.

### 5. Error message style

- Lowercase, no trailing period: `"amount must be positive"`.
- State the requirement, not the failure: prefer `"amount must be an integer"`
  over `"invalid amount"`.
- Never interpolate user IDs, keys, or stored payloads into a message. Messages
  reach logs; identifiers and player data do not belong there.
- Messages are part of the contract when a caller branches on them. Tests
  asserting an exact string are fine — changing the string is then a
  deliberate, visible change.

## Naming

- Modules, types and constructors: `PascalCase` (`Wallet`, `CurrencyService`).
- Functions, locals and fields: `camelCase`.
- Private fields on a class table: leading underscore (`_balance`).
- Module-level constants: `SCREAMING_SNAKE_CASE`.
- Instance names in `default.project.json` are load-bearing for
  require-by-string — see the mount note in [AGENTS.md](AGENTS.md) before
  renaming one.

## Comments

Comment why, not what. Every file opens with a short header saying what the
module is for and which layer rule governs it — that header is how an agent
picks the right file to change. Do not restate the code; do record decisions,
trade-offs, and anything deliberately left undone (with the reason).
