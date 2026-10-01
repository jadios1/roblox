--!strict
-- Player2: Anchored at (61, 6.0, 0.0) on NorthWall with position (61.0, 6.0, 0.0)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getBalance = ReplicatedStorage:WaitForChild("GetBalance") :: RemoteFunction
local balance = getBalance:InvokeServer() :: number?
print(`[rob] Current balance: {balance ~= nil and balance or "not loaded yet"}`)

local onPlayerMove = function(player: Player)
    local ok, err = currency:deposit(player.UserId, 1)
    if not ok then
        -- The player stays on the same spot (no movement)
        warn(`failed to deposit balance for movement: {err}`)
    end
end

local onPlayerAttack = function(player: Player)
    local ok, err = currency:deposit(player.UserId, 1)
    if not ok then
        -- The player stays on the same spot (no damage)
        warn(`failed to deposit balance for attack: {err}`)
    end
    -- Damage the ball (15 damage per attack)
    local damage = 15
    if damage > 15 then
        damage = 15
    end
    local ok, damageResult = currency:deposit(player.UserId, damage)
    if not damageResult.ok then
        -- Damage not possible due to insufficient balance
        warn(`insufficient balance to damage ball: {result.err}`)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
    currency:unloadPlayer(player.UserId)
end)

-- PlayerRemoving is not guaranteed to fire on shutdown.
-- Without this flush, every online player loses the session's changes on every deploy.
-- Roblox holds the server open until this callback returns.
game:BindToClose(function()
    currency:unloadAll()
end)