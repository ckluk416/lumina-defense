--!strict
print("[Server] Initializing...")

-- Procedural map generation: builds a fresh layout (2-4 random routes from
-- portals to Base) for this match. Must run BEFORE EnvironmentSetup.init()
-- and BEFORE WaveManager starts, since both depend on the generated
-- SpawnPoint_<id> / Route_<id> / Portal objects existing in Workspace.
local MapGenerator = require(script:WaitForChild("MapGenerator") :: ModuleScript)
local EnvironmentSetup = require(script:WaitForChild("EnvironmentSetup") :: ModuleScript)
local LobbyBuilder = require(script:WaitForChild("LobbyBuilder") :: ModuleScript)

LobbyBuilder.build()

local generatedRouteIds = MapGenerator.generate()
EnvironmentSetup.setRouteIds(generatedRouteIds)
EnvironmentSetup.init()

-- Core systems (order matters: CombatManager before PlacementHandler)
local EconomyManager = require(script:WaitForChild("EconomyManager") :: ModuleScript)
require(script:WaitForChild("CombatManager") :: ModuleScript)
require(script:WaitForChild("PlacementHandler") :: ModuleScript)
require(script:WaitForChild("LightingController") :: ModuleScript)
require(script:WaitForChild("PathPreview") :: ModuleScript)
local WaveManager = require(script:WaitForChild("WaveManager") :: ModuleScript)
require(script:WaitForChild("VisualEffects") :: ModuleScript)

-- Start the match: resets wave/base state, then kicks off Wave 1 after the
-- initial preview buffer.
WaveManager.resetForNewMatch()
WaveManager.beginMatch()

-- Send initial money to each player when they join
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.PlayerAdded:Connect(function(player)
	task.wait(1.5) -- Wait for client scripts to load
	local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UpdateMoney = RemoteEvents:FindFirstChild("UpdateMoney") :: RemoteEvent
	if UpdateMoney then
		UpdateMoney:FireClient(player, EconomyManager.getMoney(player))
	end
end)

print("[Server] Initialization Complete.")
