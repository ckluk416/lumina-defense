--!strict
print("[Server] Initializing...")

-- Environment first (generates map)
require(script:WaitForChild("EnvironmentSetup") :: ModuleScript)

-- Core systems
require(script:WaitForChild("EconomyManager") :: ModuleScript)
require(script:WaitForChild("CombatManager") :: ModuleScript)
require(script:WaitForChild("PlacementHandler") :: ModuleScript)
require(script:WaitForChild("LightingController") :: ModuleScript)
require(script:WaitForChild("PathPreview") :: ModuleScript)
require(script:WaitForChild("WaveManager") :: ModuleScript)

-- Send initial money to each player when they join
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyManager = require(script:WaitForChild("EconomyManager") :: ModuleScript)

Players.PlayerAdded:Connect(function(player)
	-- Wait a bit for client to load
	task.wait(1)
	local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UpdateMoney = RemoteEvents:FindFirstChild("UpdateMoney") :: RemoteEvent
	if UpdateMoney then
		UpdateMoney:FireClient(player, EconomyManager.getMoney(player))
	end
end)

print("[Server] Initialization Complete.")
