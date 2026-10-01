--!strict
-- Thin client glue: no game logic here. Anything worth testing belongs in
-- src/shared (pure + Lune-testable); the client only renders results. Shared
-- modules are available to the client at ReplicatedStorage.shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getBalance = ReplicatedStorage:WaitForChild("GetBalance") :: RemoteFunction
local getWanderEnter = ReplicatedStorage:WaitForChild("WanderEnter") :: RemoteFunction
local getWanderLeave = ReplicatedStorage:WaitForChild("WanderLeave") :: RemoteFunction

local balance = getBalance:InvokeServer() :: number?
local entered = getWanderEnter:InvokeServer() :: (boolean, string?)
local left = getWanderLeave:InvokeServer() :: (boolean, string?)

print(`[rob] Balance: {balance ~= nil and balance or "not loaded yet"}`)
print(`[rob] WanderEnter: {entered}`)
print(`[rob] WanderLeave: {left}`)
