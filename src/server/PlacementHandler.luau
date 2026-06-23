--!strict
local PlacementHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent
local Assets           = ReplicatedStorage:WaitForChild("Assets")

local EconomyManager = require(script.Parent:WaitForChild("EconomyManager") :: ModuleScript)
local CombatManager  = require(script.Parent:WaitForChild("CombatManager")  :: ModuleScript)

local ALLOWED_TOWERS = {
	["ArcherTower_Roblox"]  = {cost = 50},
	["LightNode_Roblox"]    = {cost = 30},
	["MageTower_Roblox"]    = {cost = 80},
	["CannonTower_Roblox"]  = {cost = 120},
}

local MAX_TOWERS_PER_PLAYER = 12
local MINIMUM_DISTANCE = 14

local placedPositions: {[number]: {Vector3}} = {}
local towerCount:      {[number]: number}    = {}

local function isTooCloseToAny(position: Vector3): boolean
	for _, positions in pairs(placedPositions) do
		for _, existingPos in ipairs(positions) do
			if (existingPos - Vector3.new(position.X, existingPos.Y, position.Z)).Magnitude < MINIMUM_DISTANCE then
				return true
			end
		end
	end
	return false
end

local function getPlayerTowerCount(player: Player): number
	return towerCount[player.UserId] or 0
end

local function placeModel(original: Model, position: Vector3): Model
	local newModel = original:Clone() :: Model

	local sumX, sumY, sumZ, partCount = 0, 0, 0, 0
	for _, p in ipairs(newModel:GetDescendants()) do
		if p:IsA("BasePart") then
			sumX += p.Position.X; sumY += p.Position.Y
			sumZ += p.Position.Z; partCount += 1
		end
	end
	local center = Vector3.new(sumX / partCount, sumY / partCount, sumZ / partCount)

	local lowestY = math.huge
	for _, p in ipairs(newModel:GetDescendants()) do
		if p:IsA("BasePart") then
			lowestY = math.min(lowestY, p.Position.Y - p.Size.Y / 2)
		end
	end

	newModel:TranslateBy(Vector3.new(
		position.X - center.X,
		position.Y - lowestY,
		position.Z - center.Z
	))

	for _, p in ipairs(newModel:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end

	newModel.Parent = Workspace
	return newModel
end

RequestPlacement.OnServerEvent:Connect(function(player: Player, towerName, position)
	if typeof(towerName) ~= "string" or typeof(position) ~= "Vector3" then return end

	local towerInfo = ALLOWED_TOWERS[towerName]
	if not towerInfo then return end

	if getPlayerTowerCount(player) >= MAX_TOWERS_PER_PLAYER then
		warn(player.Name .. " exceeded tower limit (" .. MAX_TOWERS_PER_PLAYER .. ")")
		return
	end

	if isTooCloseToAny(position) then
		warn(player.Name .. " tried to place " .. towerName .. " too close to another structure!")
		return
	end

	if not EconomyManager.deductMoney(player, towerInfo.cost) then
		warn(player.Name .. " can't afford " .. towerName)
		return
	end

	local original = Assets:FindFirstChild(towerName)
	if not original or not original:IsA("Model") then
		EconomyManager.addMoney(player, towerInfo.cost)
		warn("Failed to find tower model in Assets: " .. towerName)
		return
	end

	local newTower = placeModel(original, position)
	CombatManager.registerStructure(newTower, towerName)

	local uid = player.UserId
	if not placedPositions[uid] then placedPositions[uid] = {} end
	table.insert(placedPositions[uid], position)
	towerCount[uid] = (towerCount[uid] or 0) + 1

	local UpdateMoney      = RemoteEvents:FindFirstChild("UpdateMoney")      :: RemoteEvent
	local UpdateTowerCount = RemoteEvents:FindFirstChild("UpdateTowerCount") :: RemoteEvent
	if UpdateMoney      then UpdateMoney:FireClient(player, EconomyManager.getMoney(player)) end
	if UpdateTowerCount then UpdateTowerCount:FireClient(player, towerCount[uid], MAX_TOWERS_PER_PLAYER) end

	print(player.Name .. " placed " .. towerName .. " (" .. towerCount[uid] .. "/" .. MAX_TOWERS_PER_PLAYER .. ")")
end)

function PlacementHandler.getMaxTowers(): number
	return MAX_TOWERS_PER_PLAYER
end

return PlacementHandler
