--!strict
-- Composition root: the ONLY place where real Roblox adapters get wired into
-- services. Everything here is glue — if you find yourself writing logic in
-- this file, move it into a service (src/server/Services) or a shared module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyService = require("@self/Services/CurrencyService")
local DataStoreAdapter = require("@self/Adapters/DataStoreAdapter")

local currency = CurrencyService.new({
	store = DataStoreAdapter.new("PlayerCurrency"),
})

local getBalance = Instance.new("RemoteFunction")
getBalance.Name = "GetBalance"
getBalance.Parent = ReplicatedStorage

getBalance.OnServerInvoke = function(player: Player): number?
	return currency:getBalance(player.UserId)
end

Players.PlayerAdded:Connect(function(player: Player)
	currency:loadPlayer(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	currency:unloadPlayer(player.UserId)
end)
