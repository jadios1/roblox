--!strict
-- Composition root: the ONLY place where real Roblox adapters get wired into
-- services. Everything here is glue — if you find yourself writing logic in
-- this file, move it into a service (src/server/Services) or a shared module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyService = require("@self/Services/CurrencyService")
local DataStoreAdapter = require("@self/Adapters/DataStoreAdapter")
local WanderService = require("@self/Services/WanderService")
local WanderAdapter = require("@self/Adapters/WanderAdapter")

local currency = CurrencyService.new({
	store = DataStoreAdapter.new("PlayerCurrency"),
	wait = task.wait,
	log = warn,
})

local getBalance = Instance.new("RemoteFunction")
getBalance.Name = "GetBalance"
getBalance.Parent = ReplicatedStorage

getBalance.OnServerInvoke = function(player: Player): number?
	return currency:getBalance(player.UserId)
end

local function onPlayerAdded(player: Player)
	local ok, err = currency:loadPlayer(player.UserId)
	if not ok then
		warn(`failed to load currency for a player: {err}`)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Players can join before this script finishes initialising; PlayerAdded will
-- not fire for them, so they would never get a wallet.
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

local wanderService = WanderService.new({
	store = WanderAdapter.new("PlayerWander"),
	wait = task.wait,
	log = warn,
})

local getWanderEnter = Instance.new("RemoteFunction")
getWanderEnter.Name = "WanderEnter"
getWanderEnter.Parent = ReplicatedStorage

getWanderEnter.OnServerInvoke = function(player: Player)
	return wanderService:startWander(player.UserId, { "ball": WanderPoint("ball") })
end

local getWanderLeave = Instance.new("RemoteFunction")
getWanderLeave.Name = "WanderLeave"
getWanderLeave.Parent = ReplicatedStorage

getWanderLeave.OnServerInvoke = function(player: Player)
	return wanderService:departWander(player.UserId, { "ball": WanderPoint("ball") })
end

Players.PlayerAdded:Connect(function(player: Player)
	warn(`player entered: {player.UserId}`)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	warn(`player leaving: {player.UserId}`)
end)

game:BindToClose(function()
	currency:unloadAll()
end)
