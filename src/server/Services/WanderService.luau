--!strict
-- Pure server-side service for the Wander mechanic. Testable under Lune:
-- all external effects go through an injected adapter; logic stays here.

local WanderPoint = require("../shared/Wander/WanderPoint")

export type WanderService = {
	wanderPoints: { [string]: WanderPoint },
	balance: number,
	startWander: (playerId: number, points: { string: WanderPoint }) -> (boolean, string?),
	departWander: (playerId: number, points: { string: WanderPoint }) -> (boolean, string?),
	getBalance: (playerId: number) -> number?,
}

export type Deps = {}

local DEFAULT_STARTING_BALANCE = 100

function WanderService.new(deps: Deps): WanderService
	local startingBalance = deps.startingBalance
	assert(startingBalance == startingBalance
		and startingBalance >= 0
		and startingBalance == math.floor(startingBalance))
	local balance = startingBalance or DEFAULT_STARTING_BALANCE
	return setmetatable({
		wanderPoints = {},
		balance = balance,
		startWander = function(playerId: number, points: { string: WanderPoint })
			local key = `player/{playerId}`
			self.wanderPoints[key] = points
			self.balance = self.balance + 10
			return true, nil
		end,
		departWander = function(playerId: number, points: { string: WanderPoint })
			local key = `player/{playerId}`
			local stored = self.wanderPoints[key]
			if stored then
				-- Check if the point matches
				for _, existingPoint in stored do
					if existingPoint.location == points.location then
						local bal = self.balance
					if bal >= 10 then
						self.balance = bal - 10
						self.wanderPoints[key] = {}
						return true, nil
					end
				end
			end
			return false, "no points to depart from"
		end,
		getBalance = function(playerId: number)
			return self.balance
		end,
}, {})

return WanderService
