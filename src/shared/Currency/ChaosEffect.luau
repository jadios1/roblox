--!strict
-- Pure chaos effect logic for balance warping.
-- No Roblox APIs — this module must stay runnable under Lune.
--
-- The warp effect applies to deposits with a small probability, randomly
-- increasing or decreasing the deposited amount by a small percentage.
-- This creates "void" chaos where deposits are uncertain.

export type WarpResult = {
	-- Whether the warp was applied
	applied: boolean,
	-- The amount actually added (may differ from requested)
	actualAmount: number,
	-- Message explaining what happened (for UI/feedback)
	message: string,
}

export type Deps = {
	-- Chaos seed for deterministic testing. Omit for random behavior.
	seed: number?,
	-- Probability of warping a deposit (0.0 to 1.0)
	-- 0.01 = 1% chance of warp
	warpProbability: number,
	-- Maximum absolute warp percentage (e.g., 0.10 = ±10%)
	maxWarpPercentage: number,
}

export type WarpEffect = {
	warpDeposit: (amount: number) -> WarpResult,
}

local WarpEffect = {}
WarpEffect.__index = WarpEffect

local DEFAULT_WARP_PROBABILITY = 0.01
local DEFAULT_MAX_WARP_PERCENTAGE = 0.10

local function seededRandom(seed: number): number
	-- Simple linear congruential generator for deterministic randomness
	local x = seed
	return ((x * 1103515245 + 12345) % 2147483648) / 2147483648
end

function WarpEffect.new(deps: Deps): WarpEffect
	local warpProbability = deps.warpProbability or DEFAULT_WARP_PROBABILITY
	local maxWarpPercentage = deps.maxWarpPercentage or DEFAULT_MAX_WARP_PERCENTAGE
	
	assert(
		warpProbability >= 0 and warpProbability <= 1,
		"warpProbability must be between 0 and 1"
	)
	assert(
		maxWarpPercentage >= 0 and maxWarpPercentage <= 1,
		"maxWarpPercentage must be between 0 and 1"
	)
	assert(
		maxWarpPercentage >= warpProbability,
		"maxWarpPercentage must be >= warpProbability"
	)

	return setmetatable({
		_seed = deps.seed,
		_warpProbability = warpProbability,
		_maxWarpPercentage = maxWarpPercentage,
		_warpCount = 0,
		_totalWarpAmount = 0,
	}, WarpEffect)
end

function WarpEffect:reset(self: WarpEffect): ()
	-- Reset internal state for testing or between sessions
	self._warpCount = 0
	self._totalWarpAmount = 0
end

function WarpEffect:warpDeposit(self: WarpEffect, amount: number): WarpResult
	local seed = self._seed
	if seed == nil then
		-- No seed: generate a new one each time for true randomness
		-- This means the effect can't be predicted or tested deterministically
		seed = math.random(0, 2147483647)
		self._seed = seed
	end

	-- Decide whether to warp
	local shouldWarp = false
	if self._seed == nil then
		-- Use Lua's random for non-deterministic case
		shouldWarp = math.random(1, 100) <= (self._warpProbability * 100)
	else
		-- Use seeded random for deterministic case
		local r = seededRandom(self._seed)
		shouldWarp = r <= self._warpProbability
		self._seed = math.floor(r * 2147483648)
	end

	if not shouldWarp then
		-- No warp: deposit the full amount
		return {
			applied = false,
			actualAmount = amount,
			message = "Deposit processed normally",
		}
	end

	-- Apply warp: randomly increase or decrease
	local r = seededRandom(self._seed)
	self._seed = math.floor(r * 2147483648)

	-- Determine direction: 0 = increase, 1 = decrease
	local direction = r < 0.5 and 1 or 0

	-- Warp amount within bounds
	local warpPct = r * self._maxWarpPercentage
	local warpValue = amount * warpPct

	local actualAmount = amount + (direction == 0 and warpValue or -warpValue)

	-- Ensure we don't go below 0 (shouldn't happen with small percentages,
	-- but be defensive)
	if actualAmount < 0 then
		actualAmount = 0
	end

	-- Update internal stats
	self._warpCount += 1
	self._totalWarpAmount += math.abs(actualAmount - amount)

	-- Build message
	local warpType = direction == 0 and "lost to the void" or "found by the void"
	local warpPctPct = math.floor(warpPct * 100)
	local warpValueStr = math.floor(warpValue)
	local amountStr = math.floor(actualAmount)
	
	return {
		applied = true,
		actualAmount = actualAmount,
		message = `chaos! ${warpType} ${warpValueStr} coins (±${warpPctPct}%) — now have ${amountStr}`,
	}
end

return WarpEffect
