--!strict
-- In-memory implementation of CurrencyService.StoreLike for unit tests.
-- Structural typing makes this a drop-in for the real DataStoreAdapter.
--
-- Failures are scripted rather than random: `failLoads`/`failSaves` set how
-- many of the next calls fail, so retry behaviour is exercised deterministically
-- (AGENTS.md testing policy).

local CurrencyService = require("@server/Services/CurrencyService")

local FakeDataStore = {}

function FakeDataStore.new()
	local records: { [string]: unknown } = {}
	local self = {
		saveCount = 0,
		loadCount = 0,
		failLoads = 0,
		failSaves = 0,
	}

	function self.load(key: string): CurrencyService.LoadResult
		self.loadCount += 1
		if self.failLoads > 0 then
			self.failLoads -= 1
			return { ok = false, err = "store unavailable" }
		end
		return { ok = true, data = records[key] }
	end

	function self.save(key: string, data: unknown): CurrencyService.SaveResult
		if self.failSaves > 0 then
			self.failSaves -= 1
			return { ok = false, err = "store unavailable" }
		end
		records[key] = data
		self.saveCount += 1
		return { ok = true }
	end

	-- Test-only helpers below (not part of StoreLike).

	function self.seed(key: string, data: unknown): ()
		records[key] = data
	end

	function self.peek(key: string): unknown
		return records[key]
	end

	return self
end

return FakeDataStore
