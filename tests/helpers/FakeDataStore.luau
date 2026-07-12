--!strict
-- In-memory implementation of CurrencyService.StoreLike for unit tests.
-- Structural typing makes this a drop-in for the real DataStoreAdapter.

local Currency = require("@shared/Currency")

local FakeDataStore = {}

function FakeDataStore.new()
	local records: { [string]: Currency.WalletData } = {}
	local self = {
		saveCount = 0,
	}

	function self.load(key: string): Currency.WalletData?
		return records[key]
	end

	function self.save(key: string, data: Currency.WalletData): ()
		records[key] = data
		self.saveCount += 1
	end

	-- Test-only helpers below (not part of StoreLike).

	function self.seed(key: string, data: Currency.WalletData): ()
		records[key] = data
	end

	function self.peek(key: string): Currency.WalletData?
		return records[key]
	end

	return self
end

return FakeDataStore
