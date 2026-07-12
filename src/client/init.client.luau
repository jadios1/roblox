--!strict
-- Thin client glue: no game logic here. Anything worth testing belongs in
-- src/shared (pure + Lune-testable); the client only renders results. Shared
-- modules are available to the client at ReplicatedStorage.Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getBalance = ReplicatedStorage:WaitForChild("GetBalance") :: RemoteFunction

local balance = getBalance:InvokeServer() :: number?
print(`[rob] Current balance: {balance ~= nil and balance or "not loaded yet"}`)
