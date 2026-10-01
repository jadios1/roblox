--!strict
-- Pure server-side service for the Wander mechanic. Testable under Lune:
-- all external effects go through an injected adapter; logic stays here.

local WanderPoint = require("../shared/Wander/WanderPoint")

export type WanderService = {
	wanderPoints: { [string]: WanderPoint },
	startWander: (playerId: number, points: { string: WanderPoint }) -> (boolean, string?),
	departWander: (playerId: number, points: { string: WanderPoint }) -> (boolean, string?),
	getBalance: (playerId: number) -> number?,
}

export type Deps = {}

local DEFAULT_STARTING_BALANCE = 100

function WanderService.new(deps: Deps): WanderService
	local balance = deps.startingBalance or DEFAULT_STARTING_BALANCE
	assert(balance == balance
		and balance >= 0
		and balance == math.floor(balance))
	return setmetatable({
		wanderPoints = {},
		startWander = function(playerId: number, points: { string: WanderPoint })
			-- Store the WanderPoints for this user.
			self.wanderPoints[`player/{playerId}`] = points
			return true, nil
		end,
		departWander = function(playerId: number, points: { string: WanderPoint })
			local key = `player/{playerId}`
			local stored = self.wanderPoints[key]
			if stored then
				-- Check if the point matches
				for _, existingPoint in stored do
					if existingPoint.location == points.location then
						self.wanderPoints[key] = {}
						return true, nil
					end
				end
				return false, "no points to depart from"
			end
			return false, "no points to depart from"
		end,
		getBalance = function(playerId: number)
			return balance
		end,
}, {})

return WanderService
