--!strict
local WaveManager = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyAI = require(script.Parent:WaitForChild("EnemyAI") :: ModuleScript)
local PathPreview = require(script.Parent:WaitForChild("PathPreview") :: ModuleScript)
local EnvironmentSetup = require(script.Parent:WaitForChild("EnvironmentSetup") :: ModuleScript)
local LightingController = require(script.Parent:WaitForChild("LightingController") :: ModuleScript)
local Assets = ReplicatedStorage:WaitForChild("Assets")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateWave    = RemoteEvents:WaitForChild("UpdateWave")    :: RemoteEvent
local UpdateBaseHP  = RemoteEvents:WaitForChild("UpdateBaseHP")  :: RemoteEvent
local RequestStartWave = RemoteEvents:WaitForChild("RequestStartWave") :: RemoteEvent

export type WaveStatus = "Intermission" | "Active" | "Completed" | "GameOver"

local MAX_BASE_HP = 100
local baseHP      = MAX_BASE_HP

local WAVES = {
	[1] = {
		enemies = {
			{name = "BasicEnemy", count = 3,  spawnDelay = 4.2, routeIndex = 1, speed = 6},
		},
	},
	[2] = {
		enemies = {
			{name = "BasicEnemy", count = 4,  spawnDelay = 3.8, routeIndex = 1, speed = 7},
		},
	},
	[3] = {
		enemies = {
			{name = "BasicEnemy", count = 3,  spawnDelay = 4.0, routeIndex = 1, speed = 6},
			{name = "BasicEnemy", count = 3,  spawnDelay = 4.2, routeIndex = 2, speed = 6},
			{name = "StealthEnemy", count = 2, spawnDelay = 4.5, routeIndex = 1, speed = 7},
		},
	},
	[4] = {
		enemies = {
			{name = "BasicEnemy", count = 6,  spawnDelay = 2.8, routeIndex = 1, speed = 10},
			{name = "BasicEnemy", count = 4,  spawnDelay = 3.0, routeIndex = 2, speed = 10},
		},
	},
	[5] = {
		enemies = {
			{name = "BasicEnemy", count = 8,  spawnDelay = 2.2, routeIndex = 1, speed = 11},
			{name = "BasicEnemy", count = 6,  spawnDelay = 2.4, routeIndex = 2, speed = 11},
		},
	},
	[6] = {
		enemies = {
			{name = "BasicEnemy",  count = 8,  spawnDelay = 2.0, routeIndex = 1, speed = 12},
			{name = "StealthEnemy",count = 3,  spawnDelay = 2.5, routeIndex = 2, speed = 13},
		},
	},
	[7] = {
		enemies = {
			{name = "BasicEnemy",  count = 10, spawnDelay = 1.6, routeIndex = 1, speed = 14},
			{name = "StealthEnemy",count = 5,  spawnDelay = 1.8, routeIndex = 2, speed = 15},
			{name = "BasicEnemy",  count = 6,  spawnDelay = 1.6, routeIndex = 3, speed = 14},
		},
	},
}

local currentWave = 0
local status: WaveStatus = "Intermission"
local waitingForStartSignal = false

local function resolveRouteId(routeIndex: number): string
	local routeIds = EnvironmentSetup.getRouteIds()
	if #routeIds == 0 then
		warn("[WaveManager] No routes available to resolve routeIndex " .. routeIndex)
		return "A"
	end
	local wrappedIndex = ((routeIndex - 1) % #routeIds) + 1
	return routeIds[wrappedIndex]
end

local function getActiveRoutes(waveIndex: number): {string}
	local waveData = WAVES[waveIndex]
	if not waveData then return {} end
	local seen: {[string]: boolean} = {}
	local routes: {string} = {}
	for _, group in ipairs(waveData.enemies) do
		local id = resolveRouteId(group.routeIndex)
		if not seen[id] then
			seen[id] = true
			table.insert(routes, id)
		end
	end
	return routes
end

local function getRouteWaypoints(routeId: string): {Vector3}
	return EnvironmentSetup.getRouteWaypoints(routeId)
end

function WaveManager.spawnEnemy(enemyName: string, routeId: string, speedOverride: number?)
	local original = Assets:FindFirstChild(enemyName)
	if not original or not original:IsA("Model") then
		warn("[WaveManager] Could not find enemy model: " .. enemyName)
		return
	end

	local newEnemy = original:Clone() :: Model

	local spawnPos = EnvironmentSetup.getSpawnPosition(routeId)
	if spawnPos then
		newEnemy:PivotTo(CFrame.new(spawnPos))
	end
	newEnemy.Parent = Workspace

	local isStealth = (enemyName == "StealthEnemy")
	local baseSpeed = if isStealth then 16 else 12
	local speed     = speedOverride or baseSpeed
	local hp        = if isStealth then 60 else 100
	local dmg       = 10
	local reward    = if isStealth then 25 else 15

	EnemyAI.setupEnemy(newEnemy, hp, speed, dmg, isStealth, reward)

	local waypoints = getRouteWaypoints(routeId)
	EnemyAI.moveAlongWaypoints(newEnemy, waypoints)
end

function WaveManager.damageBase(amount: number)
	baseHP = math.max(0, baseHP - amount)
	UpdateBaseHP:FireAllClients(baseHP, MAX_BASE_HP)

	if baseHP <= 0 then
		status = "GameOver"
		print("[WaveManager] GAME OVER! Base destroyed!")
		UpdateWave:FireAllClients(currentWave, "GameOver")
	end
end

function WaveManager.getBaseHP(): number
	return baseHP
end

function WaveManager.resetForNewMatch()
	currentWave = 0
	status = "Intermission"
	baseHP = MAX_BASE_HP
	waitingForStartSignal = false
end

function WaveManager.onPlayerRequestStart(player: Player)
	if not waitingForStartSignal then return end
	waitingForStartSignal = false
	print("[WaveManager] " .. player.Name .. " started the battle!")
	WaveManager.startWave()
end

function WaveManager.startWave()
	if status ~= "Intermission" then return end

	currentWave += 1
	local waveData = WAVES[currentWave]

	if not waveData then
		status = "Completed"
		print("[WaveManager] All waves completed! VICTORY!")
		UpdateWave:FireAllClients(currentWave, "Victory")
		return
	end

	status = "Active"
	waitingForStartSignal = false
	print("[WaveManager] Wave " .. currentWave .. " started!")
	UpdateWave:FireAllClients(currentWave, "Active")

	-- Night falls at the end of every 3rd wave (one "day" = 3 waves)
	if currentWave % 3 == 0 then
		LightingController.setPhase("Night", 4)
	else
		LightingController.setPhase("Day", 4)
	end

	PathPreview.clearAll()

	local groupsRemaining = #waveData.enemies
	local thisWaveToken   = currentWave

	for _, enemyGroup in ipairs(waveData.enemies) do
		local resolvedRouteId = resolveRouteId(enemyGroup.routeIndex)
		local speedOverride: number? = enemyGroup.speed
		task.spawn(function()
			for _ = 1, enemyGroup.count do
				if status ~= "Active" or currentWave ~= thisWaveToken then return end
				WaveManager.spawnEnemy(enemyGroup.name, resolvedRouteId, speedOverride)
				task.wait(enemyGroup.spawnDelay)
			end

			groupsRemaining -= 1
			if groupsRemaining <= 0 then
				WaveManager.waitForWaveClear(thisWaveToken)
			end
		end)
	end
end

function WaveManager.waitForWaveClear(waveToken: number)
	local SAFETY_TIMEOUT = 120
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if status ~= "Active" or currentWave ~= waveToken then
			connection:Disconnect()
			return
		end
		if next(EnemyAI.getActiveEnemies()) == nil or elapsed >= SAFETY_TIMEOUT then
			connection:Disconnect()
			if elapsed >= SAFETY_TIMEOUT then
				warn("[WaveManager] Safety timeout on wave " .. waveToken)
			end
			WaveManager.endWave()
		end
	end)
end

function WaveManager.endWave()
	if status ~= "Active" then return end

	status = "Intermission"
	print("[WaveManager] Wave " .. currentWave .. " completed!")
	UpdateWave:FireAllClients(currentWave, "Intermission")

	LightingController.setPhase("Day", 2.5)

	local nextWave = currentWave + 1
	if not WAVES[nextWave] then
		status = "Completed"
		UpdateWave:FireAllClients(currentWave, "Victory")
		return
	end

	task.spawn(function()
		print("[WaveManager] Intermission: show path preview for wave " .. nextWave)

		local nextRoutes = getActiveRoutes(nextWave)
		if #nextRoutes > 0 then
			PathPreview.showRoutes(nextRoutes)
		end

		waitingForStartSignal = true
		local nextWaveIsNight = (nextWave % 3 == 0)
		RequestStartWave:FireAllClients("ready", nextWave, nextWaveIsNight)
	end)
end

function WaveManager.beginMatch()
	task.spawn(function()
		task.wait(2)

		local firstRoutes = getActiveRoutes(1)
		PathPreview.showRoutes(firstRoutes)

		UpdateWave:FireAllClients(0, "Intermission")
		UpdateBaseHP:FireAllClients(baseHP, MAX_BASE_HP)

		waitingForStartSignal = true
		RequestStartWave:FireAllClients("ready", 1)
	end)
end

RequestStartWave.OnServerEvent:Connect(function(player: Player)
	WaveManager.onPlayerRequestStart(player)
end)

return WaveManager
