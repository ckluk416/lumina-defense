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
-- Fired server→client to tell the UI whether the Start Battle button is usable
local RequestStartWave = RemoteEvents:WaitForChild("RequestStartWave") :: RemoteEvent

export type WaveStatus = "Intermission" | "Active" | "Completed" | "GameOver"

local MAX_BASE_HP = 100
local baseHP      = MAX_BASE_HP

-- ────────────────────────────────────────────────────────────────
-- WAVE DATA
-- spawnDelay  = seconds between each enemy in the group (pace)
-- routeIndex  = 1-based; resolved to actual route letter at runtime
-- speed       = WalkSpeed override for enemies in this wave/group
--               (nil = use EnemyAI default per enemy type)
-- Wave 1-2 are slow and sparse; wave 3-4 ramp up intensity.
-- ────────────────────────────────────────────────────────────────
local WAVES = {
	[1] = {
		-- Very slow, few enemies – let the player settle in.
		enemies = {
			{name = "BasicEnemy", count = 4,  spawnDelay = 3.5, routeIndex = 1, speed = 10},
		},
	},
	[2] = {
		enemies = {
			{name = "BasicEnemy", count = 5,  spawnDelay = 2.5, routeIndex = 1, speed = 11},
			{name = "BasicEnemy", count = 3,  spawnDelay = 3.0, routeIndex = 2, speed = 11},
		},
	},
	[3] = {
		-- Speed and count pick up; first stealth enemies appear.
		enemies = {
			{name = "BasicEnemy",  count = 8,  spawnDelay = 1.8, routeIndex = 1, speed = 13},
			{name = "BasicEnemy",  count = 5,  spawnDelay = 2.0, routeIndex = 2, speed = 13},
			{name = "StealthEnemy",count = 3,  spawnDelay = 2.5, routeIndex = 3, speed = 14},
		},
	},
	[4] = {
		-- Full intensity: fast, many, several stealth.
		enemies = {
			{name = "BasicEnemy",  count = 12, spawnDelay = 1.0, routeIndex = 1, speed = 16},
			{name = "StealthEnemy",count = 6,  spawnDelay = 1.2, routeIndex = 2, speed = 18},
			{name = "BasicEnemy",  count = 8,  spawnDelay = 1.0, routeIndex = 3, speed = 16},
		},
	},
}

local currentWave = 0
local status: WaveStatus = "Intermission"

-- Whether the server is currently waiting for a player to press Start Battle.
local waitingForStartSignal = false

-- ────────────────────────────────────────────────────────────────
-- HELPERS
-- ────────────────────────────────────────────────────────────────

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

-- ────────────────────────────────────────────────────────────────
-- ENEMY SPAWNING
-- ────────────────────────────────────────────────────────────────

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

-- ────────────────────────────────────────────────────────────────
-- BASE DAMAGE
-- ────────────────────────────────────────────────────────────────

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

-- ────────────────────────────────────────────────────────────────
-- MATCH LIFECYCLE
-- ────────────────────────────────────────────────────────────────

function WaveManager.resetForNewMatch()
	currentWave = 0
	status = "Intermission"
	baseHP = MAX_BASE_HP
	waitingForStartSignal = false
end

-- Called by a client (via RequestStartWave RemoteEvent) to begin the wave
-- once they've finished placing towers during intermission.
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

	-- Day/Night phase
	local waveHasStealthEnemy = false
	for _, enemyGroup in ipairs(waveData.enemies) do
		if enemyGroup.name == "StealthEnemy" then
			waveHasStealthEnemy = true
			break
		end
	end
	if waveHasStealthEnemy then
		LightingController.setPhase("Night", 4)
	else
		LightingController.setPhase("Day", 4)
	end

	-- Clear path preview now that the battle has started
	PathPreview.clearAll()

	-- Spawn enemy groups in parallel
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

-- ────────────────────────────────────────────────────────────────
-- WAVE CLEAR / INTERMISSION
-- ────────────────────────────────────────────────────────────────

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

	-- If there's a next wave, enter manual-start intermission.
	-- Otherwise trigger victory.
	local nextWave = currentWave + 1
	if not WAVES[nextWave] then
		-- No more waves
		status = "Completed"
		UpdateWave:FireAllClients(currentWave, "Victory")
		return
	end

	task.spawn(function()
		print("[WaveManager] Intermission: show path preview for wave " .. nextWave)

		-- Show path preview for the upcoming wave's routes during intermission
		local nextRoutes = getActiveRoutes(nextWave)
		if #nextRoutes > 0 then
			PathPreview.showRoutes(nextRoutes)
		end

		-- Signal client: intermission ready, show Start Battle button
		waitingForStartSignal = true
		-- Fire to ALL clients so any player can start
		-- (in a multiplayer game you might restrict this to host/first player)
		RequestStartWave:FireAllClients("ready", nextWave)
	end)
end

-- ────────────────────────────────────────────────────────────────
-- INITIAL MATCH START
-- ────────────────────────────────────────────────────────────────

function WaveManager.beginMatch()
	task.spawn(function()
		task.wait(2) -- let map finish loading on clients

		-- Show path preview for wave 1
		local firstRoutes = getActiveRoutes(1)
		PathPreview.showRoutes(firstRoutes)

		UpdateWave:FireAllClients(0, "Intermission")
		UpdateBaseHP:FireAllClients(baseHP, MAX_BASE_HP)

		-- Signal clients: ready to start wave 1
		waitingForStartSignal = true
		RequestStartWave:FireAllClients("ready", 1)
	end)
end

-- ────────────────────────────────────────────────────────────────
-- REMOTE EVENT LISTENER (client requests start)
-- ────────────────────────────────────────────────────────────────
RequestStartWave.OnServerEvent:Connect(function(player: Player)
	WaveManager.onPlayerRequestStart(player)
end)

return WaveManager
