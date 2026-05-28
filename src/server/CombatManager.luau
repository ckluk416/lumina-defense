--!strict
local CombatManager = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TowerAttack = require(game.ReplicatedStorage.Shared.TowerAttack)
local EnemyAI = require(script.Parent:WaitForChild("EnemyAI") :: ModuleScript)

-- Hardcoded Tower Stats
local TOWER_STATS = {
	["ArcherTower_Roblox"] = {
		isLightNode = false,
		damage = 10,
		range = 35,
		fireRate = 0.8
	},
	["MageTower_Roblox"] = {
		isLightNode = false,
		damage = 25,
		range = 30,
		fireRate = 1.5
	},
	["CannonTower_Roblox"] = {
		isLightNode = false,
		damage = 40,
		range = 25,
		fireRate = 2.5
	},
	["LightNode_Roblox"] = {
		isLightNode = true,
		range = 25,
	}
}

type PlacedStructure = {
	model: Model,
	name: string,
	stats: any,
	lastFired: number
}

local activeStructures: {PlacedStructure} = {}

function CombatManager.registerStructure(model: Model, name: string)
	local stats = TOWER_STATS[name]
	if not stats then
		warn("No stats found for structure: " .. name)
		return
	end
	
	table.insert(activeStructures, {
		model = model,
		name = name,
		stats = stats,
		lastFired = 0
	})
	
	print("Registered " .. name .. " to CombatManager")
end

-- Helper to check if a position is within ANY Light Node's radius
local function isPositionRevealedByLight(position: Vector3): boolean
	for _, struct in ipairs(activeStructures) do
		if struct.stats.isLightNode then
			local structPos = struct.model.PrimaryPart and struct.model.PrimaryPart.Position or struct.model:GetPivot().Position
			if (structPos - position).Magnitude <= struct.stats.range then
				return true
			end
		end
	end
	return false
end

-- Draw a temporary laser for visual effect
local function createLaser(fromPos: Vector3, toPos: Vector3)
	local distance = (toPos - fromPos).Magnitude
	local laser = Instance.new("Part")
	laser.Name = "Laser"
	laser.Anchored = true
	laser.CanCollide = false
	laser.Size = Vector3.new(0.5, 0.5, distance)
	laser.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
	laser.Color = Color3.fromRGB(255, 0, 0)
	laser.Material = Enum.Material.Neon
	laser.Parent = Workspace
	
	-- Destroy after 0.1 seconds
	task.delay(0.1, function()
		laser:Destroy()
	end)
end

-- The main combat loop
RunService.Heartbeat:Connect(function(deltaTime)
	local currentTime = tick()
	local activeEnemies = EnemyAI.getActiveEnemies()
	
	for _, struct in ipairs(activeStructures) do
		if struct.stats.isLightNode then continue end -- Light nodes don't shoot
		
		-- Check fire rate
		if currentTime - struct.lastFired >= struct.stats.fireRate then
			local structPos = struct.model.PrimaryPart and struct.model.PrimaryPart.Position or struct.model:GetPivot().Position
			
			-- Find closest valid enemy
			local bestTarget = nil
			local closestDist = struct.stats.range
			
			for enemyModel, enemyData in pairs(activeEnemies) do
				local enemyPos = enemyModel.PrimaryPart and enemyModel.PrimaryPart.Position or enemyModel:GetPivot().Position
				local dist = (structPos - enemyPos).Magnitude
				
				if dist <= closestDist then
					-- Stealth check
					local canSee = true
					if enemyData.isStealth then
						canSee = isPositionRevealedByLight(enemyPos)
					end
					
					if canSee then
						closestDist = dist
						bestTarget = enemyModel
					end
				end
			end
			
			-- Shoot
			if bestTarget then
				struct.lastFired = currentTime
				EnemyAI.damageEnemy(bestTarget, struct.stats.damage)
				
				local enemyPos = bestTarget.PrimaryPart and bestTarget.PrimaryPart.Position or bestTarget:GetPivot().Position
				createLaser(structPos + Vector3.new(0, 5, 0), enemyPos) -- Shoot from slightly above base
			end
		end
	end
end)

return CombatManager
