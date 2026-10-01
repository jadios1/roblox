--!strict
-- Thin Roblox adapter for the WanderService. No game logic — one call per method.
-- Provides a StoreLike for the composition root to wire.

local WanderService = require("../Services/WanderService")

function WanderService.new(storeName: string): WanderService
	local store = DataStoreService:GetDataStore(storeName)
	local self = {}

	function self.load(key: string): LoadResult
		local data = store:GetData(key)
		return data ~= nil, data
	end

	function self.save(key: string, data: unknown): SaveResult
		store:SetData(key, data)
		return true
	end

	return self
end

local DataStoreService = game:GetService("DataStoreService")

return WanderService.new
