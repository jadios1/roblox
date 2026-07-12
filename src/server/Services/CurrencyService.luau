--!strict
-- Pure server-side orchestration for player currency. Testable under Lune:
-- every external effect (persistence) goes through an injected StoreLike, so
-- this file must never touch Roblox globals. The relative require below works
-- in both runtimes because default.project.json mounts src/shared as a sibling
-- of src/server inside ServerScriptService.

local Currency = require("../../shared/Currency")

local Wallet = Currency.Wallet

export type StoreLike = {
	load: (key: string) -> Currency.WalletData?,
	save: (key: string, data: Currency.WalletData) -> (),
}

export type Deps = {
	store: StoreLike,
	startingBalance: number?,
}

local DEFAULT_STARTING_BALANCE = 100

local CurrencyService = {}
CurrencyService.__index = CurrencyService

export type CurrencyService = typeof(setmetatable(
	{} :: {
		_store: StoreLike,
		_startingBalance: number,
		_wallets: { [number]: Currency.Wallet },
	},
	CurrencyService
))

local function storeKey(userId: number): string
	return `player/{userId}`
end

function CurrencyService.new(deps: Deps): CurrencyService
	return setmetatable({
		_store = deps.store,
		_startingBalance = deps.startingBalance or DEFAULT_STARTING_BALANCE,
		_wallets = {},
	}, CurrencyService)
end

function CurrencyService.loadPlayer(self: CurrencyService, userId: number): ()
	-- Truthiness instead of `~= nil`: strict Luau rejects nil comparisons
	-- against metatable-based types like Wallet.
	if self._wallets[userId] then
		return
	end
	local data = self._store.load(storeKey(userId))
	local wallet: Currency.Wallet
	if data ~= nil then
		local restored = Wallet.deserialize(data)
		-- Corrupt data falls back to a fresh wallet. A real game should park the
		-- bad payload somewhere recoverable instead of discarding it silently.
		wallet = restored or Wallet.new(self._startingBalance)
	else
		wallet = Wallet.new(self._startingBalance)
	end
	self._wallets[userId] = wallet
end

function CurrencyService.unloadPlayer(self: CurrencyService, userId: number): ()
	local wallet = self._wallets[userId]
	if not wallet then
		return
	end
	self._store.save(storeKey(userId), wallet:serialize())
	self._wallets[userId] = nil
end

function CurrencyService.getBalance(self: CurrencyService, userId: number): number?
	local wallet = self._wallets[userId]
	if not wallet then
		return nil
	end
	return wallet:balance()
end

function CurrencyService.deposit(
	self: CurrencyService,
	userId: number,
	amount: number
): (boolean, string?)
	local wallet = self._wallets[userId]
	if not wallet then
		return false, "player is not loaded"
	end
	return wallet:deposit(amount)
end

function CurrencyService.withdraw(
	self: CurrencyService,
	userId: number,
	amount: number
): (boolean, string?)
	local wallet = self._wallets[userId]
	if not wallet then
		return false, "player is not loaded"
	end
	return wallet:withdraw(amount)
end

return CurrencyService
