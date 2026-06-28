--!strict
local TowerAttack = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type TowerInfo = {
	Range: number,
	Damage: number,
	FireRate: number,
}

export type TowerStats = {
	damage: number?,
	range: number,
	fireRate: number?,
	aoeRadius: number?,
	innerRange: number?,
}

local TOWER_BASE_STATS: {[string]: TowerStats} = {
	["ArcherTower_Roblox"]  = {damage = 10, range = 35, fireRate = 0.8},
	["MageTower_Roblox"]    = {damage = 25, range = 30, fireRate = 1.5, aoeRadius = 12},
	["Mortar_Roblox"]       = {damage = 45, range = 50, fireRate = 3.0, aoeRadius = 14, innerRange = 15},
	["LightNode_Roblox"]    = {range = 25},
}

TowerAttack.MAX_TOWER_LEVEL = 3

local function cloneStats(s: TowerStats): TowerStats
	local t: TowerStats = {}
	for k, v in pairs(s) do t[k] = v end
	return t
end

local function applyUpgrade(stats: TowerStats)
	if stats.damage then stats.damage = math.floor(stats.damage * 1.3) end
	if stats.range then stats.range = stats.range * 1.12 end
	if stats.fireRate then stats.fireRate = stats.fireRate * 0.92 end
end

local TOWER_COSTS: {[string]: number} = {
	["ArcherTower_Roblox"]  = 50,
	["LightNode_Roblox"]    = 30,
	["MageTower_Roblox"]    = 80,
	["Mortar_Roblox"]       = 220,
}

local COST_RATIO = 0.7

function TowerAttack.getUpgradePreview(towerName: string, currentLevel: number): {current: TowerStats, next: TowerStats, cost: number}?
	local base = TOWER_BASE_STATS[towerName]
	if not base then return nil end
	local current = cloneStats(base)
	for _ = 2, currentLevel do applyUpgrade(current) end
	local nextStats = cloneStats(current)
	applyUpgrade(nextStats)
	local baseCost = TOWER_COSTS[towerName] or 50
	local cost = math.floor(baseCost * COST_RATIO * currentLevel)
	return {current = current, next = nextStats, cost = cost}
end

function TowerAttack.getBaseStats(towerName: string): TowerStats?
	return TOWER_BASE_STATS[towerName]
end

function TowerAttack.isInRange(originPosition: Vector3, targetPosition: Vector3, range: number): boolean
	return (originPosition - targetPosition).Magnitude <= range
end

function TowerAttack.isEnemyRevealed(enemyPosition: Vector3, lightNodes: {Instance}): boolean
	for _, node in ipairs(lightNodes) do
		if node:IsA("BasePart") then
			if TowerAttack.isInRange(node.Position, enemyPosition, 15) then
				return true
			end
		end
	end
	return false
end

return TowerAttack
