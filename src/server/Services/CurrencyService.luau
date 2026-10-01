--!strict
-- Pure server-side orchestration for player currency. Testable under Lune:
-- every external effect (persistence) goes through an injected StoreLike, so
-- this file must never touch Roblox globals. The relative require below works
-- in both runtimes because default.project.json mounts src/shared as a sibling
-- of src/server inside ServerScriptService.
--
-- Failure handling follows the error contract in STYLE.md: the store returns
-- tagged results rather than throwing, and this service converts them into
-- (ok, err) pairs. Nothing here pcalls.

local Currency = require("../../shared/Currency")

local Wallet = Currency.Wallet
local WarpEffect = Currency.WarpEffect

-- `data` is nil inside an ok result when no record exists — that is a normal
-- outcome, not a failure, which is why this type is tagged rather than using
-- nil to mean both things.
export type LoadResult = { ok: true, data: unknown } | { ok: false, err: string }
export type SaveResult = { ok: true } | { ok: false, err: string }

-- Persistence is untyped on purpose: a DataStore can hand back anything that
-- was ever written to it. Validation belongs in Wallet.deserialize.
export type StoreLike = {
	load: (key: string) -> LoadResult,
	save: (key: string, data: unknown) -> SaveResult,
}

export type Deps = {
	store: StoreLike,
	startingBalance: number?,
	-- Retries cover transient store failures. `wait` is injected so tests stay
	-- deterministic (AGENTS.md testing policy); omitting it retries with no delay.
	maxAttempts: number?,
	retryDelay: number?,
	wait: ((seconds: number) -> ())?,
	-- Recovered-from problems are reported here rather than via print/warn,
	-- which would be an untestable side effect in a service. See STYLE.md.
	log: ((message: string) -> ())?,
}

local DEFAULT_STARTING_BALANCE = 100
local DEFAULT_MAX_ATTEMPTS = 3
local DEFAULT_RETRY_DELAY = 1

-- A session is a loaded wallet plus whether it may be written back. A wallet
-- that replaced unreadable data is NOT persistable unless the original payload
-- was safely quarantined first — otherwise unloading would overwrite a
-- recoverable record with a starting balance.
type Session = {
	wallet: Currency.Wallet,
	persistable: boolean,
}

local CurrencyService = {}
CurrencyService.__index = CurrencyService

export type CurrencyService = typeof(setmetatable(
	{} :: {
		_store: StoreLike,
		_startingBalance: number,
		_maxAttempts: number,
		_retryDelay: number,
		_wait: (seconds: number) -> (),
		_log: (message: string) -> (),
		_sessions: { [number]: Session },
	},
	CurrencyService
))

local function storeKey(userId: number): string
	return `player/{userId}`
end

-- Unreadable payloads are parked here so support can recover them. One slot per
-- player: a second corruption overwrites the first.
local function quarantineKey(userId: number): string
	return `player/{userId}/corrupt`
end

function CurrencyService.new(deps: Deps): CurrencyService
	-- Assert at construction, not at player join: a misconfigured service should
	-- crash the server at startup, not fail one player at a time. See STYLE.md.
	local startingBalance = deps.startingBalance or DEFAULT_STARTING_BALANCE
	assert(
		startingBalance == startingBalance
			and startingBalance >= 0
			and startingBalance == math.floor(startingBalance),
		"startingBalance must be a non-negative integer"
	)
	local maxAttempts = deps.maxAttempts or DEFAULT_MAX_ATTEMPTS
	assert(
		maxAttempts >= 1 and maxAttempts == math.floor(maxAttempts),
		"maxAttempts must be a positive integer"
	)

	return setmetatable({
		_store = deps.store,
		_startingBalance = startingBalance,
		_maxAttempts = maxAttempts,
		_retryDelay = deps.retryDelay or DEFAULT_RETRY_DELAY,
		_wait = deps.wait or function() end,
		_log = deps.log or function() end,
		_sessions = {},
	}, CurrencyService)
end

function CurrencyService.loadWithRetry(self: CurrencyService, key: string): LoadResult
	local result = self._store.load(key)
	local attempt = 1
	while not result.ok and attempt < self._maxAttempts do
		self._wait(self._retryDelay)
		attempt += 1
		result = self._store.load(key)
	end
	return result
end

function CurrencyService.saveWithRetry(
	self: CurrencyService,
	key: string,
	data: unknown
): SaveResult
	local result = self._store.save(key, data)
	local attempt = 1
	while not result.ok and attempt < self._maxAttempts do
		self._wait(self._retryDelay)
		attempt += 1
		result = self._store.save(key, data)
	end
	return result
end

-- Returns false when the player has no usable wallet — the caller must treat
-- that as "this player is not playing yet", never as an empty wallet.
function CurrencyService.loadPlayer(self: CurrencyService, userId: number): (boolean, string?)
	-- Truthiness instead of `~= nil`: strict Luau rejects nil comparisons
	-- against metatable-based types like Wallet.
	if self._sessions[userId] then
		return true, nil
	end

	local result = self:loadWithRetry(storeKey(userId))
	if not result.ok then
		-- No wallet is created. Deliberate: a wallet invented after a failed read
		-- would be saved over the real record on unload.
		return false, result.err
	end

	if result.data == nil then
		self._sessions[userId] = {
			wallet = Wallet.new(self._startingBalance),
			persistable = true,
		}
		return true, nil
	end

	local restored, err = Wallet.deserialize(result.data)
	if restored then
		self._sessions[userId] = { wallet = restored, persistable = true }
		return true, nil
	end

	-- Unreadable data. Park the raw payload before handing the player a fresh
	-- wallet; if we cannot park it, the fresh wallet must never be written back.
	self._log(`wallet data unreadable, quarantining: {err}`)
	local quarantined = self:saveWithRetry(quarantineKey(userId), result.data)
	if not quarantined.ok then
		self._log(`quarantine failed, wallet will not be persisted: {quarantined.err}`)
	end
	self._sessions[userId] = {
		wallet = Wallet.new(self._startingBalance),
		persistable = quarantined.ok,
	}
	return true, nil
end

-- Returns false when the wallet could not be persisted. The session is evicted
-- either way: the player has left and holding the entry would leak.
function CurrencyService.unloadPlayer(self: CurrencyService, userId: number): (boolean, string?)
	local session = self._sessions[userId]
	if not session then
		return true, nil
	end
	self._sessions[userId] = nil

	if not session.persistable then
		local err =
			"wallet not persisted: original data was unreadable and could not be quarantined"
		self._log(err)
		return false, err
	end

	local result = self:saveWithRetry(storeKey(userId), session.wallet:serialize())
	if not result.ok then
		self._log(`failed to persist wallet: {result.err}`)
		return false, result.err
	end
	return true, nil
end

-- Flush every live session. Called from BindToClose: PlayerRemoving is not
-- guaranteed to fire during a server shutdown, so without this every online
-- player loses the session's changes.
function CurrencyService.unloadAll(self: CurrencyService): (boolean, string?)
	local userIds: { number } = {}
	for userId in self._sessions do
		table.insert(userIds, userId)
	end
	-- Deterministic order so a partial failure is reproducible.
	table.sort(userIds)

	local firstErr: string? = nil
	for _, userId in userIds do
		local ok, err = self:unloadPlayer(userId)
		if not ok and firstErr == nil then
			firstErr = err
		end
	end
	if firstErr then
		return false, firstErr
	end
	return true, nil
end

function CurrencyService.getBalance(self: CurrencyService, userId: number): number?
	local session = self._sessions[userId]
	if not session then
		return nil
	end
	return session.wallet:balance()
end

function CurrencyService.deposit(
	self: CurrencyService,
	userId: number,
	amount: number
): (boolean, string?)
	local session = self._sessions[userId]
	if not session then
		return false, "player is not loaded"
	end
	return session.wallet:deposit(amount)
end

function CurrencyService.withdraw(
	self: CurrencyService,
	userId: number,
	amount: number
): (boolean, string?)
	local session = self._sessions[userId]
	if not session then
		return false, "player is not loaded"
	end
	return session.wallet:withdraw(amount)
end

return CurrencyService
