--!strict
local EnemyAI = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateMoney = RemoteEvents:WaitForChild("UpdateMoney") :: RemoteEvent

export type EnemyData = {
	model: Model,
	health: number,
	maxHealth: number,
	speed: number,
	damage: number,
	isStealth: boolean,
	reward: number,     -- Money rewarded when killed
	hpBar: Frame?,      -- Reference to the HP fill frame for updates
	connection: RBXScriptConnection?
}

local activeEnemies: {[Model]: EnemyData} = {}

function EnemyAI.getActiveEnemies()
	return activeEnemies
end

-- Create a floating HP bar above the enemy using BillboardGui
local function createHPBar(enemyModel: Model): Frame?
	local rootPart = enemyModel.PrimaryPart or enemyModel:FindFirstChildOfClass("BasePart")
	if not rootPart then return nil end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HPBar"
	billboard.Size = UDim2.new(0, 80, 0, 10)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Adornee = rootPart
	billboard.Parent = enemyModel

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 220, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	return fill
end

-- Update the HP bar fill for an enemy
local function updateHPBar(data: EnemyData)
	if data.hpBar then
		local ratio = math.clamp(data.health / data.maxHealth, 0, 1)
		data.hpBar.Size = UDim2.new(ratio, 0, 1, 0)
		-- Color shift: green -> yellow -> red
		if ratio > 0.5 then
			data.hpBar.BackgroundColor3 = Color3.fromRGB(0, 220, 60)
		elseif ratio > 0.25 then
			data.hpBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		else
			data.hpBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		end
	end
end

function EnemyAI.damageEnemy(enemyModel: Model, amount: number)
	local data = activeEnemies[enemyModel]
	if data then
		data.health -= amount
		updateHPBar(data)

		if data.health <= 0 then
			EnemyAI.killEnemy(enemyModel, true)
		end
	end
end

-- killEnemy: if byPlayer=true, reward money to all players (simple broadcast)
function EnemyAI.killEnemy(enemyModel: Model, byPlayer: boolean?)
	local data = activeEnemies[enemyModel]
	if data then
		if data.connection then
			data.connection:Disconnect()
		end

		-- Reward all players when killed by tower
		if byPlayer then
			local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
			for _, player in ipairs(Players:GetPlayers()) do
				EconomyManager.addMoney(player, data.reward)
				UpdateMoney:FireClient(player, EconomyManager.getMoney(player))
			end
			print("[EnemyAI] Enemy killed! Each player earned $" .. data.reward)
		end

		activeEnemies[enemyModel] = nil
	end
	if enemyModel and enemyModel.Parent then
		enemyModel:Destroy()
	end
end

function EnemyAI.cleanupEnemy(enemyModel: Model)
	EnemyAI.killEnemy(enemyModel, false)
end

function EnemyAI.setupEnemy(enemyModel: Model, maxHealth: number, speed: number, damage: number, isStealth: boolean?, reward: number?)
	local stealthValue = if isStealth ~= nil then isStealth else false
	local rewardValue = if reward ~= nil then reward else 15

	-- Create floating HP bar
	local hpBarFill = createHPBar(enemyModel)

	activeEnemies[enemyModel] = {
		model = enemyModel,
		health = maxHealth,
		maxHealth = maxHealth,
		speed = speed,
		damage = damage,
		isStealth = stealthValue,
		reward = rewardValue,
		hpBar = hpBarFill
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

			if not enemyModel.Parent or not activeEnemies[enemyModel] then
				return
			end
		end

		-- Enemy reached the Base
		local data = activeEnemies[enemyModel]
		if data then
			local WaveManager = require(script.Parent:WaitForChild("WaveManager"))
			WaveManager.damageBase(data.damage)
			print("[EnemyAI] " .. enemyModel.Name .. " reached base! Dealt " .. data.damage .. " damage.")
			EnemyAI.cleanupEnemy(enemyModel)
		end
	end)
end

return EnemyAI
