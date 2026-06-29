local MatchManager = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateMoney = RemoteEvents:WaitForChild("UpdateMoney") :: RemoteEvent
local UpdateWave = RemoteEvents:WaitForChild("UpdateWave") :: RemoteEvent
local UpdateBaseHP = RemoteEvents:WaitForChild("UpdateBaseHP") :: RemoteEvent
local UpdateTowerCount = RemoteEvents:WaitForChild("UpdateTowerCount") :: RemoteEvent
local UpdateWaveStats = RemoteEvents:WaitForChild("UpdateWaveStats") :: RemoteEvent

local Players = game:GetService("Players")

function MatchManager.resetMatch()
	local EnemyAI = require(script.Parent:WaitForChild("EnemyAI"))
	local PlacementHandler = require(script.Parent:WaitForChild("PlacementHandler"))
	local WaveManager = require(script.Parent:WaitForChild("WaveManager"))
	local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
	local MapGenerator = require(script.Parent:WaitForChild("MapGenerator"))
	local EnvironmentSetup = require(script.Parent:WaitForChild("EnvironmentSetup"))

	EnemyAI.clearAllEnemies()
	PlacementHandler.resetAllTowers()
	WaveManager.resetForNewMatch()
	EconomyManager.resetAll()

	local generatedRouteIds = MapGenerator.generate()
	EnvironmentSetup.setRouteIds(generatedRouteIds)
	EnvironmentSetup.init()

	for _, player in ipairs(Players:GetPlayers()) do
		EconomyManager.initPlayer(player)
		UpdateMoney:FireClient(player, EconomyManager.getMoney(player))
		UpdateWave:FireClient(player, 0, "Intermission")
		UpdateBaseHP:FireClient(player, WaveManager.getBaseHP(), WaveManager.getMaxBaseHP())
		UpdateTowerCount:FireClient(player, 0, PlacementHandler.getMaxTowers())
	end

	WaveManager.beginMatch()

	print("[MatchManager] Match reset complete")
end

return MatchManager
