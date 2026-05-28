--!strict
local WaveManager = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyAI = require(script.Parent:WaitForChild("EnemyAI"))
local PathPreview = require(script.Parent:WaitForChild("PathPreview"))
local Assets = ReplicatedStorage:WaitForChild("Assets")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateWave = RemoteEvents:WaitForChild("UpdateWave") :: RemoteEvent
local UpdateBaseHP = RemoteEvents:WaitForChild("UpdateBaseHP") :: RemoteEvent

export type WaveStatus = "Intermission" | "Active" | "Completed" | "GameOver"

-- Base HP
local MAX_BASE_HP = 100
local baseHP = MAX_BASE_HP

-- Wave data: each enemy group has a `route` field ("A", "B", or "C")
local WAVES = {
	[1] = {
		enemies = {
			{name = "BasicEnemy", count = 5, spawnDelay = 1.5, route = "A"},
		}
	},
	[2] = {
		enemies = {
			{name = "BasicEnemy", count = 6, spawnDelay = 1.2, route = "A"},
			{name = "BasicEnemy", count = 4, spawnDelay = 1.5, route = "B"},
		}
	},
	[3] = {
		enemies = {
			{name = "BasicEnemy", count = 8, spawnDelay = 1.0, route = "A"},
			{name = "BasicEnemy", count = 5, spawnDelay = 1.0, route = "B"},
			{name = "StealthEnemy", count = 3, spawnDelay = 1.5, route = "C"},
		}
	},
	[4] = {
		enemies = {
			{name = "BasicEnemy", count = 10, spawnDelay = 0.8, route = "A"},
			{name = "StealthEnemy", count = 5, spawnDelay = 1.0, route = "B"},
			{name = "BasicEnemy", count = 6, spawnDelay = 0.8, route = "C"},
		}
	},
}

local currentWave = 0
local status: WaveStatus = "Intermission"

-- Collect unique route IDs from a wave
local function getActiveRoutes(waveIndex: number): {string}
	local waveData = WAVES[waveIndex]
	if not waveData then return {} end
	
	local seen: {[string]: boolean} = {}
	local routes: {string} = {}
	for _, group in ipairs(waveData.enemies) do
		if not seen[group.route] then
			seen[group.route] = true
			table.insert(routes, group.route)
		end
	end
	return routes
end

-- Get waypoints for a specific route
local function getRouteWaypoints(routeId: string): {Vector3}
	local waypoints: {Vector3} = {}
	local routeFolder = Workspace:FindFirstChild("Route_" .. routeId)
	if routeFolder then
		local nodes = routeFolder:GetChildren()
		table.sort(nodes, function(a, b)
			return tonumber(a.Name) < tonumber(b.Name)
		end)
		for _, node in ipairs(nodes) do
			if node:IsA("BasePart") then
				table.insert(waypoints, node.Position)
			end
		end
	end
	return waypoints
end

-- Spawn a single enemy on a given route
function WaveManager.spawnEnemy(enemyName: string, routeId: string)
	local original = Assets:FindFirstChild(enemyName)
	if not original or not original:IsA("Model") then
		warn("[WaveManager] Could not find enemy model: " .. enemyName)
		return
	end
	
	local newEnemy = original:Clone() :: Model
	
	-- Position at spawn point
	local spawnPoint = Workspace:FindFirstChild("SpawnPoint_" .. routeId)
	if spawnPoint and spawnPoint:IsA("BasePart") then
		newEnemy:PivotTo(CFrame.new(spawnPoint.Position + Vector3.new(0, 3, 0)))
	end
	
	newEnemy.Parent = Workspace
	
	-- Determine stealth
	local isStealth = (enemyName == "StealthEnemy")
	
	-- Setup with HP, speed, damage
	local hp = if isStealth then 60 else 100
	local speed = if isStealth then 20 else 16
	local dmg = 10
	EnemyAI.setupEnemy(newEnemy, hp, speed, dmg, isStealth)
	
	-- Get waypoints for this route and move
	local waypoints = getRouteWaypoints(routeId)
	EnemyAI.moveAlongWaypoints(newEnemy, waypoints)
end

-- Damage the base when an enemy reaches it
function WaveManager.damageBase(amount: number)
	baseHP = math.max(0, baseHP - amount)
	-- Broadcast to all clients
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
	print("[WaveManager] Wave " .. currentWave .. " started!")
	UpdateWave:FireAllClients(currentWave, "Active")
	
	-- Show path preview for active routes
	local activeRoutes = getActiveRoutes(currentWave)
	PathPreview.showRoutes(activeRoutes)
	
	-- Fade out path preview after 3 seconds
	task.delay(3, function()
		PathPreview.fadeOut(2)
	end)
	
	-- Spawn enemy groups in parallel (different routes simultaneously)
	local groupsRemaining = #waveData.enemies
	
	for _, enemyGroup in ipairs(waveData.enemies) do
		task.spawn(function()
			for i = 1, enemyGroup.count do
				if status ~= "Active" then return end
				WaveManager.spawnEnemy(enemyGroup.name, enemyGroup.route)
				task.wait(enemyGroup.spawnDelay)
			end
			
			groupsRemaining -= 1
			
			-- When all groups have finished spawning, wait then end wave
			if groupsRemaining <= 0 then
				-- Wait for enemies to either die or reach base
				task.wait(8)
				WaveManager.endWave()
			end
		end)
	end
end

function WaveManager.endWave()
	if status ~= "Active" then return end
	
	status = "Intermission"
	print("[WaveManager] Wave " .. currentWave .. " completed!")
	UpdateWave:FireAllClients(currentWave, "Intermission")
	
	-- Start next wave after intermission
	task.spawn(function()
		print("[WaveManager] Intermission... next wave in 8 seconds.")
		task.wait(8)
		
		-- Show path preview during intermission for upcoming wave
		local nextRoutes = getActiveRoutes(currentWave + 1)
		if #nextRoutes > 0 then
			PathPreview.showRoutes(nextRoutes)
		end
		
		task.wait(2) -- Let players see the preview
		WaveManager.startWave()
	end)
end

-- Kickstart the game
task.spawn(function()
	task.wait(3) -- Initial buffer
	
	-- Show preview for Wave 1 routes before starting
	local firstRoutes = getActiveRoutes(1)
	PathPreview.showRoutes(firstRoutes)
	
	UpdateWave:FireAllClients(0, "Intermission")
	UpdateBaseHP:FireAllClients(baseHP, MAX_BASE_HP)
	
	task.wait(4) -- Let players see the preview
	WaveManager.startWave()
end)

return WaveManager
