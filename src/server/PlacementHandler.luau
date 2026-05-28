--!strict
local PlacementHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent
local Assets = ReplicatedStorage:WaitForChild("Assets")

local EconomyManager = require(script.Parent:WaitForChild("EconomyManager") :: ModuleScript)
local CombatManager = require(script.Parent:WaitForChild("CombatManager") :: ModuleScript)

-- List of allowed tower names
local ALLOWED_TOWERS = {
	["ArcherTower_Roblox"] = {cost = 50},
	["LightNode_Roblox"] = {cost = 30},
	["MageTower_Roblox"] = {cost = 80},
	["CannonTower_Roblox"] = {cost = 120},
}

-- Track placed towers for collision checking
local placedTowers: {Vector3} = {}
local MINIMUM_DISTANCE = 8 -- Minimum studs between towers

-- Check if a position is too close to any existing tower
local function isTooCloseToExisting(position: Vector3): boolean
	for _, existingPos in ipairs(placedTowers) do
		if (existingPos - position).Magnitude < MINIMUM_DISTANCE then
			return true
		end
	end
	return false
end

RequestPlacement.OnServerEvent:Connect(function(player, towerName, position)
	-- 1. Validate inputs
	if typeof(towerName) ~= "string" or typeof(position) ~= "Vector3" then return end
	
	-- 2. Validate tower exists in our allowed list
	local towerInfo = ALLOWED_TOWERS[towerName]
	if not towerInfo then return end
	
	-- 3. Collision check
	if isTooCloseToExisting(position) then
		warn(player.Name .. " tried to place " .. towerName .. " too close to another tower!")
		return
	end
	
	-- 4. Check Economy
	if EconomyManager.deductMoney(player, towerInfo.cost) then
		-- 5. Clone and place tower
		local original = Assets:FindFirstChild(towerName)
		if original and original:IsA("Model") then
			local newTower = original:Clone() :: Model
			
			-- Preserve the original rotation of the model
			local originalRotation = original:GetPivot().Rotation
			newTower:PivotTo(CFrame.new(position) * originalRotation)
			
			-- Anchor all parts
			for _, part in ipairs(newTower:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			
			newTower.Parent = Workspace
			
			-- Record position for collision checking
			table.insert(placedTowers, position)
			
			-- Register to CombatManager
			CombatManager.registerStructure(newTower, towerName)
			
			-- Notify client of money change
			local UpdateMoney = RemoteEvents:FindFirstChild("UpdateMoney") :: RemoteEvent
			if UpdateMoney then
				UpdateMoney:FireClient(player, EconomyManager.getMoney(player))
			end
			
			print(player.Name .. " placed " .. towerName .. " at " .. tostring(position))
		else
			EconomyManager.addMoney(player, towerInfo.cost)
			warn("Failed to find tower model in Assets: " .. towerName)
		end
	else
		warn(player.Name .. " tried to place " .. towerName .. " without enough money!")
	end
end)

return PlacementHandler
