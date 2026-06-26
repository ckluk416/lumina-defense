--!strict
local PlacementHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent
local RequestRemoveTower = RemoteEvents:WaitForChild("RequestRemoveTower") :: RemoteEvent
local RequestBuySlot = RemoteEvents:WaitForChild("RequestBuySlot") :: RemoteEvent
local UpdateExtraSlotInfo = RemoteEvents:WaitForChild("UpdateExtraSlotInfo") :: RemoteEvent
local Assets           = ReplicatedStorage:WaitForChild("Assets")

local EconomyManager = require(script.Parent:WaitForChild("EconomyManager") :: ModuleScript)
local CombatManager  = require(script.Parent:WaitForChild("CombatManager")  :: ModuleScript)

local ALLOWED_TOWERS = {
	["ArcherTower_Roblox"]  = {cost = 50},
	["LightNode_Roblox"]    = {cost = 30},
	["MageTower_Roblox"]    = {cost = 80},
	["Mortar_Roblox"]       = {cost = 220},
}

local MAX_TOWERS_PER_PLAYER = 12
local MINIMUM_DISTANCE = 14
local REFUND_RATIO = 0.5
local SLOT_BASE_COST = 300
local SLOT_COST_MULTIPLIER = 1.6

local extraSlots: {[number]: number} = {}

local function getMaxTowers(player: Player): number
	return MAX_TOWERS_PER_PLAYER + (extraSlots[player.UserId] or 0)
end

local function getNextSlotCost(player: Player): number
	local bought = extraSlots[player.UserId] or 0
	return math.floor(SLOT_BASE_COST * (SLOT_COST_MULTIPLIER ^ bought))
end

local function broadcastSlotInfo(player: Player)
	UpdateExtraSlotInfo:FireClient(player, getMaxTowers(player), getNextSlotCost(player))
end

type PlacedEntry = {model: Model, position: Vector3, towerName: string}

local placedTowers: {[number]: {PlacedEntry}} = {}
local towerOwner:   {[Model]: Player}          = {}

local function getPlayerTowerCount(player: Player): number
	return placedTowers[player.UserId] and #placedTowers[player.UserId] or 0
end

local function isTooCloseToAny(position: Vector3): boolean
	for _, entries in pairs(placedTowers) do
		for _, entry in ipairs(entries) do
			if (entry.position - Vector3.new(position.X, entry.position.Y, position.Z)).Magnitude < MINIMUM_DISTANCE then
				return true
			end
		end
	end
	return false
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

	if getPlayerTowerCount(player) >= getMaxTowers(player) then
		warn(player.Name .. " exceeded tower limit (" .. getMaxTowers(player) .. ")")
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
	if not placedTowers[uid] then placedTowers[uid] = {} end
	table.insert(placedTowers[uid], {model = newTower, position = position, towerName = towerName})
	towerOwner[newTower] = player

	local UpdateMoney      = RemoteEvents:FindFirstChild("UpdateMoney")      :: RemoteEvent
	local UpdateTowerCount = RemoteEvents:FindFirstChild("UpdateTowerCount") :: RemoteEvent
	if UpdateMoney      then UpdateMoney:FireClient(player, EconomyManager.getMoney(player)) end
	if UpdateTowerCount then UpdateTowerCount:FireClient(player, getPlayerTowerCount(player), getMaxTowers(player)) end

	print(player.Name .. " placed " .. towerName .. " (" .. getPlayerTowerCount(player) .. "/" .. getMaxTowers(player) .. ")")
end)

RequestRemoveTower.OnServerEvent:Connect(function(player: Player, model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end

	if towerOwner[model] ~= player then
		warn(player.Name .. " tried to remove a tower they don't own")
		return
	end

	local uid = player.UserId
	local entries = placedTowers[uid]
	if not entries then return end

	local removedEntry: PlacedEntry? = nil
	for i, entry in ipairs(entries) do
		if entry.model == model then
			removedEntry = entry
			table.remove(entries, i)
			break
		end
	end
	if not removedEntry then return end

	towerOwner[model] = nil
	CombatManager.removeStructure(model)
	model:Destroy()

	local towerInfo = ALLOWED_TOWERS[removedEntry.towerName]
	if towerInfo then
		local refund = math.floor(towerInfo.cost * REFUND_RATIO)
		EconomyManager.addMoney(player, refund)
	end

	local UpdateMoney      = RemoteEvents:FindFirstChild("UpdateMoney")      :: RemoteEvent
	local UpdateTowerCount = RemoteEvents:FindFirstChild("UpdateTowerCount") :: RemoteEvent
	if UpdateMoney      then UpdateMoney:FireClient(player, EconomyManager.getMoney(player)) end
	if UpdateTowerCount then UpdateTowerCount:FireClient(player, getPlayerTowerCount(player), getMaxTowers(player)) end

	print(player.Name .. " removed " .. removedEntry.towerName .. " (" .. getPlayerTowerCount(player) .. "/" .. getMaxTowers(player) .. ")")
end)

RequestBuySlot.OnServerEvent:Connect(function(player: Player)
	local cost = getNextSlotCost(player)
	if not EconomyManager.deductMoney(player, cost) then
		warn(player.Name .. " can't afford a new slot ($" .. cost .. ")")
		return
	end

	extraSlots[player.UserId] = (extraSlots[player.UserId] or 0) + 1

	local UpdateMoney      = RemoteEvents:FindFirstChild("UpdateMoney")      :: RemoteEvent
	local UpdateTowerCount = RemoteEvents:FindFirstChild("UpdateTowerCount") :: RemoteEvent
	if UpdateMoney      then UpdateMoney:FireClient(player, EconomyManager.getMoney(player)) end
	if UpdateTowerCount then UpdateTowerCount:FireClient(player, getPlayerTowerCount(player), getMaxTowers(player)) end
	broadcastSlotInfo(player)

	print(player.Name .. " bought a slot! Max is now " .. getMaxTowers(player))
end)

game.Players.PlayerAdded:Connect(function(player: Player)
	task.wait(2)
	broadcastSlotInfo(player)
end)

function PlacementHandler.getMaxTowers(): number
	return MAX_TOWERS_PER_PLAYER
end

return PlacementHandler
