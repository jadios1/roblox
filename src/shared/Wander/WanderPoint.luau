--!strict
-- Pure game content module for WanderPoints. These are visual objects that
-- exist in the game world and can be walked to.

export type WanderPoint = { location: string }

local WanderPoint = {}
WanderPoint.__index = WanderPoint

local function newWanderPoint(loc: string): WanderPoint
	return setmetatable({ location = loc }, WanderPoint)
end

return WanderPoint
