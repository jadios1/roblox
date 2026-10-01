--!strict
-- Thin wrapper around DataStoreService implementing CurrencyService.StoreLike.
-- Roblox-only: this is deliberately the ONLY server file (besides the
-- composition root) allowed to touch a Roblox service. Keep it free of logic —
-- it is not unit-testable under Lune and is covered later by cloud integration
-- tests (docs/cloud-integration-tests.md).
--
-- The pcall wrapping is the layer boundary required by STYLE.md: DataStore
-- calls throw, and no Roblox error may reach a service. Converting a thrown
-- error into a tagged result is the one and only thing done here beyond the
-- call itself. Retry policy is NOT here — it is the service's decision, so it
-- lives where it can be tested.
--
-- NOTE: session-locking is still missing. Two servers holding the same player
-- can still clobber each other. A production game needs UpdateAsync with a
-- lock, or a battle-tested persistence library (see AGENTS.md dependency policy).

local DataStoreService = game:GetService("DataStoreService")

local CurrencyService = require("../Services/CurrencyService")

function DataStoreAdapter.new(storeName: string): CurrencyService.StoreLike
	local store = DataStoreService:GetDataStore(storeName)
	local self = {}

	function self.load(key: string): CurrencyService.LoadResult
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if not ok then
			return { ok = false, err = tostring(result) }
		end
		return { ok = true, data = result }
	end

	function self.save(key: string, data: unknown): CurrencyService.SaveResult
		local ok, err = pcall(function()
			store:SetAsync(key, data)
		end)
		if not ok then
			return { ok = false, err = tostring(err) }
		end
		return { ok = true }
	end

	return self
end

return DataStoreAdapter
