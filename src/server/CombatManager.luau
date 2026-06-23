--!strict
local CombatManager = {}

local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local TweenService  = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerAttack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TowerAttack") :: ModuleScript)
local EnemyAI     = require(script.Parent:WaitForChild("EnemyAI") :: ModuleScript)

local TOWER_STATS = {
	["ArcherTower_Roblox"] = {
		isLightNode = false, isAOE = false,
		damage = 10, range = 35, fireRate = 0.8,
	},
	["MageTower_Roblox"] = {
		isLightNode = false, isAOE = true,
		aoeRadius = 12, damage = 25, range = 30, fireRate = 1.5,
	},
	["CannonTower_Roblox"] = {
		isLightNode = false, isAOE = true,
		aoeRadius = 16, damage = 40, range = 25, fireRate = 2.5,
	},
	["Mortar_Roblox"] = {
		isLightNode = false, isAOE = true,
		aoeRadius = 14, damage = 45, range = 50, innerRange = 20, fireRate = 3.0,
	},
	["LightNode_Roblox"] = {
		isLightNode = true, range = 25,
	},
}

type PlacedStructure = {
	model:     Model,
	name:      string,
	stats:     any,
	lastFired: number,
}

local activeStructures: {PlacedStructure} = {}

local FIRING_POINT_NAMES = {
	"Ballista_Body", "Ballista_Pivot",
	"Turret_Crystal", "Turret_GlowRing",
	"Turret_Housing", "Barrel_Left",
	"Barrel_MuzzleFlare", "Barrel_Main",
	"Barrel",
}

local function getFiringOrigin(model: Model): Vector3
	for _, name in ipairs(FIRING_POINT_NAMES) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return Vector3.new(part.Position.X, part.Position.Y + part.Size.Y / 2, part.Position.Z)
		end
	end

	local highestY = -math.huge
	local bestPos  = model:GetPivot().Position
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local top = p.Position.Y + p.Size.Y / 2
			if top > highestY then
				highestY = top
				bestPos  = Vector3.new(p.Position.X, top, p.Position.Z)
			end
		end
	end
	return bestPos
end

local function fireArrow(origin: Vector3, target: Vector3)
	local arrow = Instance.new("Part")
	arrow.Name       = "Arrow"
	arrow.Size       = Vector3.new(0.15, 0.15, 2.5)
	arrow.Anchored   = true
	arrow.CanCollide = false
	arrow.Material   = Enum.Material.Wood
	arrow.Color      = Color3.fromRGB(160, 110, 60)
	arrow.CFrame     = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -1.25)
	arrow.Parent     = Workspace

	local mid = (origin + target) / 2 + Vector3.new(0, 3, 0)
	local distance = (target - origin).Magnitude
	local duration = math.clamp(distance / 60, 0.12, 0.35)

	task.spawn(function()
		local steps  = 12
		local step_t = duration / steps
		for i = 1, steps do
			task.wait(step_t)
			if not arrow.Parent then return end
			local t    = i / steps
			local pos  = (1-t)^2 * origin + 2*(1-t)*t * mid + t^2 * target
			local nxt = if i < steps
				then (1-(t + 1/steps))^2 * origin + 2*(1-(t+1/steps))*(t+1/steps) * mid + (t+1/steps)^2 * target
				else target
			arrow.CFrame = CFrame.lookAt(pos, nxt) * CFrame.new(0, 0, -1.25)
		end
		arrow:Destroy()
	end)
end

local function fireMageOrb(origin: Vector3, target: Vector3, splashRadius: number)
	local orb = Instance.new("Part")
	orb.Name        = "MageOrb"
	orb.Shape       = Enum.PartType.Ball
	orb.Size        = Vector3.new(1.2, 1.2, 1.2)
	orb.Anchored    = true
	orb.CanCollide  = false
	orb.Material    = Enum.Material.Neon
	orb.Color       = Color3.fromRGB(150, 50, 250)
	orb.Position    = origin
	orb.Parent      = Workspace

	local duration  = math.clamp((target - origin).Magnitude / 55, 0.15, 0.35)
	local steps     = 14
	local step_t    = duration / steps

	task.spawn(function()
		for i = 1, steps do
			task.wait(step_t)
			if not orb.Parent then return end
			local t   = i / steps
			orb.Position = origin:Lerp(target, t)
		end
		orb:Destroy()
		local ring = Instance.new("Part")
		ring.Shape       = Enum.PartType.Ball
		ring.Size        = Vector3.new(0.5, 0.5, 0.5)
		ring.Position    = target
		ring.Anchored    = true
		ring.CanCollide  = false
		ring.Transparency = 0.5
		ring.Color       = Color3.fromRGB(180, 80, 255)
		ring.Material    = Enum.Material.Neon
		ring.Parent      = Workspace
		local tw = TweenService:Create(ring,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(splashRadius*2, splashRadius*2, splashRadius*2), Transparency = 1}
		)
		tw:Play()
		tw.Completed:Connect(function() ring:Destroy() end)
	end)
end

local function fireCannonShell(origin: Vector3, target: Vector3, splashRadius: number)
	local shell = Instance.new("Part")
	shell.Name       = "CannonShell"
	shell.Shape      = Enum.PartType.Ball
	shell.Size       = Vector3.new(1.0, 1.0, 1.0)
	shell.Anchored   = true
	shell.CanCollide = false
	shell.Material   = Enum.Material.Metal
	shell.Color      = Color3.fromRGB(50, 50, 50)
	shell.Position   = origin
	shell.Parent     = Workspace

	local mid = (origin + target) / 2 + Vector3.new(0, 8, 0)
	local distance = (target - origin).Magnitude
	local duration = math.clamp(distance / 45, 0.2, 0.5)
	local steps    = 14
	local step_t   = duration / steps

	task.spawn(function()
		for i = 1, steps do
			task.wait(step_t)
			if not shell.Parent then return end
			local t   = i / steps
			local pos = (1-t)^2 * origin + 2*(1-t)*t * mid + t^2 * target
			shell.Position = pos
		end
		shell:Destroy()
		local boom = Instance.new("Part")
		boom.Shape       = Enum.PartType.Ball
		boom.Size        = Vector3.new(1, 1, 1)
		boom.Position    = target
		boom.Anchored    = true
		boom.CanCollide  = false
		boom.Transparency = 0.3
		boom.Color       = Color3.fromRGB(255, 150, 50)
		boom.Material    = Enum.Material.Neon
		boom.Parent      = Workspace
		local tw = TweenService:Create(boom,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(splashRadius*2.5, splashRadius*2.5, splashRadius*2.5), Transparency = 1}
		)
		tw:Play()
		tw.Completed:Connect(function() boom:Destroy() end)
	end)
end

local function fireMortarMissile(origin: Vector3, target: Vector3, splashRadius: number)
	local missile = Instance.new("Part")
	missile.Name       = "MortarMissile"
	missile.Shape      = Enum.PartType.Cylinder
	missile.Size       = Vector3.new(1.6, 0.35, 0.35)
	missile.Anchored   = true
	missile.CanCollide = false
	missile.Material   = Enum.Material.Metal
	missile.Color      = Color3.fromRGB(60, 60, 65)
	missile.Parent     = Workspace

	local fin = Instance.new("Part")
	fin.Name       = "MortarMissile_Fin"
	fin.Size       = Vector3.new(0.5, 0.05, 0.6)
	fin.Anchored   = true
	fin.CanCollide = false
	fin.Material   = Enum.Material.Metal
	fin.Color      = Color3.fromRGB(35, 35, 38)
	fin.Parent     = Workspace

	local arcHeight = 14
	local mid = (origin + target) / 2 + Vector3.new(0, arcHeight, 0)
	local distance = (target - origin).Magnitude
	local duration = math.clamp(distance / 38, 0.45, 0.9)

	task.spawn(function()
		local steps  = 22
		local step_t = duration / steps
		for i = 1, steps do
			task.wait(step_t)
			if not missile.Parent then return end
			local t    = i / steps
			local pos  = (1-t)^2 * origin + 2*(1-t)*t * mid + t^2 * target
			local nextT = math.min(t + 1/steps, 1)
			local nxt  = (1-nextT)^2 * origin + 2*(1-nextT)*nextT * mid + nextT^2 * target

			local travelCFrame = CFrame.lookAt(pos, nxt) * CFrame.Angles(0, math.rad(90), 0)
			missile.CFrame = travelCFrame
			fin.CFrame     = travelCFrame * CFrame.new(-0.85, 0, 0)
		end
		missile:Destroy()
		fin:Destroy()

		local boom = Instance.new("Part")
		boom.Shape       = Enum.PartType.Ball
		boom.Size        = Vector3.new(1.2, 1.2, 1.2)
		boom.Position    = target
		boom.Anchored    = true
		boom.CanCollide  = false
		boom.Transparency = 0.25
		boom.Color       = Color3.fromRGB(255, 130, 30)
		boom.Material    = Enum.Material.Neon
		boom.Parent      = Workspace
		local tw = TweenService:Create(boom,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(splashRadius*2.2, splashRadius*2.2, splashRadius*2.2), Transparency = 1}
		)
		tw:Play()
		tw.Completed:Connect(function() boom:Destroy() end)
	end)
end

local TURRET_PART_NAMES = {"Turret_Housing", "Turret_Dome", "Turret_Mount", "Turret_Breach"}

local function rotateTurretToward(model: Model, targetPos: Vector3)
	local turret: BasePart? = nil
	for _, name in ipairs(TURRET_PART_NAMES) do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then turret = p; break end
	end
	if not turret then return end

	local origin = turret.Position
	local flatDir = Vector3.new(targetPos.X - origin.X, 0, targetPos.Z - origin.Z)
	if flatDir.Magnitude < 0.01 then return end
	turret.CFrame = CFrame.new(origin) * CFrame.lookAt(Vector3.zero, flatDir)
end

local function isPositionRevealedByLight(position: Vector3): boolean
	for _, struct in ipairs(activeStructures) do
		if struct.stats.isLightNode then
			local pos = struct.model.PrimaryPart
				and struct.model.PrimaryPart.Position
				or struct.model:GetPivot().Position
			if (pos - position).Magnitude <= struct.stats.range then
				return true
			end
		end
	end
	return false
end

function CombatManager.registerStructure(model: Model, name: string)
	local stats = TOWER_STATS[name]
	if not stats then
		warn("No stats found for structure: " .. name)
		return
	end
	table.insert(activeStructures, {
		model     = model,
		name      = name,
		stats     = stats,
		lastFired = 0,
	})
	print("Registered " .. name .. " to CombatManager")
end

RunService.Heartbeat:Connect(function()
	local now         = tick()
	local activeEnemies = EnemyAI.getActiveEnemies()

	for _, struct in ipairs(activeStructures) do
		if struct.stats.isLightNode then continue end
		if now - struct.lastFired < struct.stats.fireRate then continue end

		local structPos = struct.model.PrimaryPart
			and struct.model.PrimaryPart.Position
			or struct.model:GetPivot().Position

		local innerRange: number = struct.stats.innerRange or 0

		local bestTarget:  Model?  = nil
		local closestDist: number  = struct.stats.range

		for enemyModel, enemyData in pairs(activeEnemies) do
			local ePos = enemyModel.PrimaryPart
				and enemyModel.PrimaryPart.Position
				or enemyModel:GetPivot().Position
			local dist = (structPos - ePos).Magnitude

			if dist <= closestDist and dist >= innerRange then
				local canSee = not enemyData.isStealth or isPositionRevealedByLight(ePos)
				if canSee then
					closestDist = dist
					bestTarget  = enemyModel
				end
			end
		end

		if not bestTarget then continue end

		struct.lastFired = now

		local targetPos = bestTarget.PrimaryPart
			and bestTarget.PrimaryPart.Position
			or bestTarget:GetPivot().Position

		local origin = getFiringOrigin(struct.model)

		if struct.name == "ArcherTower_Roblox" then
			fireArrow(origin, targetPos)
			EnemyAI.damageEnemy(bestTarget, struct.stats.damage)

		elseif struct.name == "MageTower_Roblox" then
			local sr = struct.stats.aoeRadius or 12
			fireMageOrb(origin, targetPos, sr)
			for enemyModel in pairs(activeEnemies) do
				local ePos = enemyModel.PrimaryPart
					and enemyModel.PrimaryPart.Position
					or enemyModel:GetPivot().Position
				if (ePos - targetPos).Magnitude <= sr then
					EnemyAI.damageEnemy(enemyModel, struct.stats.damage)
				end
			end

		elseif struct.name == "CannonTower_Roblox" then
			local sr = struct.stats.aoeRadius or 16
			rotateTurretToward(struct.model, targetPos)
			fireCannonShell(origin, targetPos, sr)
			for enemyModel in pairs(activeEnemies) do
				local ePos = enemyModel.PrimaryPart
					and enemyModel.PrimaryPart.Position
					or enemyModel:GetPivot().Position
				if (ePos - targetPos).Magnitude <= sr then
					EnemyAI.damageEnemy(enemyModel, struct.stats.damage)
				end
			end

		elseif struct.name == "Mortar_Roblox" then
			local sr = struct.stats.aoeRadius or 14
			fireMortarMissile(origin, targetPos, sr)
			for enemyModel in pairs(activeEnemies) do
				local ePos = enemyModel.PrimaryPart
					and enemyModel.PrimaryPart.Position
					or enemyModel:GetPivot().Position
				if (ePos - targetPos).Magnitude <= sr then
					EnemyAI.damageEnemy(enemyModel, struct.stats.damage)
				end
			end
		end
	end
end)

return CombatManager
