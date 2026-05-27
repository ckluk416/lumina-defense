--!strict
local TowerAttack = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type TowerInfo = {
	Range: number,
	Damage: number,
	FireRate: number,
}

-- Checks if the target is within a certain distance from the origin
function TowerAttack.isInRange(originPosition: Vector3, targetPosition: Vector3, range: number): boolean
	return (originPosition - targetPosition).Magnitude <= range
end

-- Checks if a stealth enemy is revealed by any Light Node
function TowerAttack.isEnemyRevealed(enemyPosition: Vector3, lightNodes: {Instance}): boolean
	for _, node in ipairs(lightNodes) do
		if node:IsA("BasePart") then
			-- Assume Light Node has a fixed radius, e.g., 15 studs
			if TowerAttack.isInRange(node.Position, enemyPosition, 15) then
				return true
			end
		end
	end
	return false
end

return TowerAttack
