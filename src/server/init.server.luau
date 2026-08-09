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
		-- The player stays walletless rather than being handed an invented
		-- balance. Surfacing it here is what stops that being silent.
		warn(`failed to load currency for a player: {err}`)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Players can join before this script finishes initialising; PlayerAdded will
-- not fire for them, so they would never get a wallet.
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	currency:unloadPlayer(player.UserId)
end)

-- PlayerRemoving is not guaranteed to fire on shutdown. Without this flush,
-- every online player loses the session's balance changes on every deploy.
-- Roblox holds the server open until this callback returns.
game:BindToClose(function()
	currency:unloadAll()
end)
