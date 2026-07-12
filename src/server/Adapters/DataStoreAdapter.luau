--!strict
-- Thin wrapper around DataStoreService implementing CurrencyService.StoreLike.
-- Roblox-only: this is deliberately the ONLY server file (besides the
-- composition root) allowed to touch a Roblox service. Keep it free of logic —
-- it is not unit-testable under Lune and is covered later by cloud integration
-- tests (docs/cloud-integration-tests.md).
--
-- NOTE: calls are not retried and errors propagate to the caller. A production
-- game needs retry/backoff and session-locking (or use a battle-tested
-- persistence library — see the dependency policy in AGENTS.md).

local DataStoreService = game:GetService("DataStoreService")

local Currency = require("../../shared/Currency")

local DataStoreAdapter = {}

function DataStoreAdapter.new(storeName: string)
	local store = DataStoreService:GetDataStore(storeName)
	local self = {}

	function self.load(key: string): Currency.WalletData?
		local value = store:GetAsync(key)
		if value == nil then
			return nil
		end
		return value :: Currency.WalletData
	end

	function self.save(key: string, data: Currency.WalletData): ()
		store:SetAsync(key, data)
	end

	return self
end

return DataStoreAdapter
