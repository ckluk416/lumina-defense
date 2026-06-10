--!strict
local CombatManager = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerAttack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TowerAttack") :: ModuleScript)
local EnemyAI = require(script.Parent:WaitForChild("EnemyAI") :: ModuleScript)

-- Hardcoded Tower Stats
local TOWER_STATS = {
	["ArcherTower_Roblox"] = {
		isLightNode = false,
		isAOE = false,
		damage = 10,
		range = 35,
		fireRate = 0.8
	},
	["MageTower_Roblox"] = {
		isLightNode = false,
		isAOE = true,
		aoeRadius = 12,
		damage = 25,
		range = 30,
		fireRate = 1.5
	},
	["CannonTower_Roblox"] = {
		isLightNode = false,
		isAOE = true,
		aoeRadius = 16,
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
				local targetPos = bestTarget.PrimaryPart and bestTarget.PrimaryPart.Position or bestTarget:GetPivot().Position
				
				if struct.stats.isAOE then
					local splashRadius = struct.stats.aoeRadius or 12
					-- Apply damage to all enemies in range of the target
					for enemyModel, enemyData in pairs(activeEnemies) do
						local enemyPos = enemyModel.PrimaryPart and enemyModel.PrimaryPart.Position or enemyModel:GetPivot().Position
						if (enemyPos - targetPos).Magnitude <= splashRadius then
							EnemyAI.damageEnemy(enemyModel, struct.stats.damage)
						end
					end
					
					-- Visual splash/laser visual
					createLaser(structPos + Vector3.new(0, 5, 0), targetPos)
					
					-- Create visual blast ring for splash damage
					local ring = Instance.new("Part")
					ring.Name = "SplashEffect"
					ring.Shape = Enum.PartType.Ball
					ring.Size = Vector3.new(2, 2, 2)
					ring.Position = targetPos
					ring.Anchored = true
					ring.CanCollide = false
					ring.Transparency = 0.6
					ring.Color = struct.name == "MageTower_Roblox" and Color3.fromRGB(150, 50, 250) or Color3.fromRGB(250, 150, 50)
					ring.Material = Enum.Material.Neon
					ring.Parent = Workspace
					
					-- Animate expansion and fade out
					task.spawn(function()
						local steps = 10
						for i = 1, steps do
							task.wait(0.02)
							if ring and ring.Parent then
								local scale = i / steps
								ring.Size = Vector3.new(splashRadius * 2 * scale, splashRadius * 2 * scale, splashRadius * 2 * scale)
								ring.Transparency = 0.6 + (0.4 * scale)
							end
						end
						if ring and ring.Parent then
							ring:Destroy()
						end
					end)
				else
					EnemyAI.damageEnemy(bestTarget, struct.stats.damage)
					createLaser(structPos + Vector3.new(0, 5, 0), targetPos)
				end
			end
		end
	end
end)

return CombatManager
