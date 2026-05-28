--!strict
local EnemyAI = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type EnemyData = {
	model: Model,
	health: number,
	maxHealth: number,
	speed: number,
	damage: number,
	isStealth: boolean,
	connection: RBXScriptConnection?
}

local activeEnemies: {[Model]: EnemyData} = {}

function EnemyAI.getActiveEnemies()
	return activeEnemies
end

function EnemyAI.damageEnemy(enemyModel: Model, amount: number)
	local data = activeEnemies[enemyModel]
	if data then
		data.health -= amount
		-- Optional: Update health bar here if one is attached to the model
		
		if data.health <= 0 then
			EnemyAI.killEnemy(enemyModel)
		end
	end
end

function EnemyAI.killEnemy(enemyModel: Model)
	local data = activeEnemies[enemyModel]
	if data then
		if data.connection then
			data.connection:Disconnect()
		end
		activeEnemies[enemyModel] = nil
	end
	enemyModel:Destroy()
end

function EnemyAI.cleanupEnemy(enemyModel: Model)
	EnemyAI.killEnemy(enemyModel)
end

function EnemyAI.setupEnemy(enemyModel: Model, maxHealth: number, speed: number, damage: number, isStealth: boolean?)
	local stealthValue = if isStealth ~= nil then isStealth else false
	
	activeEnemies[enemyModel] = {
		model = enemyModel,
		health = maxHealth,
		maxHealth = maxHealth,
		speed = speed,
		damage = damage,
		isStealth = stealthValue
	}
	
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth
	end
end

function EnemyAI.moveAlongWaypoints(enemyModel: Model, waypoints: {Vector3})
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	task.spawn(function()
		for _, waypoint in ipairs(waypoints) do
			humanoid:MoveTo(waypoint)
			humanoid.MoveToFinished:Wait()
			
			-- Check if enemy was destroyed mid-walk
			if not enemyModel.Parent or not activeEnemies[enemyModel] then
				return
			end
		end
		
		-- Logic for when enemy reaches the end (Base)
		local data = activeEnemies[enemyModel]
		if data then
			-- Lazy require to avoid circular dependency
			local WaveManager = require(script.Parent:WaitForChild("WaveManager"))
			WaveManager.damageBase(data.damage)
			print(enemyModel.Name .. " reached the base and dealt " .. data.damage .. " damage!")
			EnemyAI.cleanupEnemy(enemyModel)
		end
	end)
end

return EnemyAI
