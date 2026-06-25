--!strict
local PlacementSystem = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent
local RequestRemoveTower = RemoteEvents:WaitForChild("RequestRemoveTower") :: RemoteEvent
local Assets           = ReplicatedStorage:WaitForChild("Assets")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local TOWER_RANGES: {[string]: number} = {
	["ArcherTower_Roblox"]  = 35,
	["MageTower_Roblox"]    = 30,
	["Mortar_Roblox"]       = 50,
	["LightNode_Roblox"]    = 15,
}

local currentPreview:    Model? = nil
local rangeIndicator:    Part?  = nil
local innerRangeIndicator: Part? = nil

local TOWER_INNER_RANGES: {[string]: number} = {
	["Mortar_Roblox"] = 15,
}
local isPlacing        = false
local currentTowerName = ""
local placingEnabled   = true
local removeModeEnabled = false

local removeHighlight: Highlight? = nil
local hoveredTowerModel: Model? = nil

local function clearRangeIndicator()
	if rangeIndicator then
		rangeIndicator:Destroy()
		rangeIndicator = nil
	end
	if innerRangeIndicator then
		innerRangeIndicator:Destroy()
		innerRangeIndicator = nil
	end
end

local function updateInnerRangeIndicator(position: Vector3, innerRange: number)
	if not innerRangeIndicator then
		innerRangeIndicator = Instance.new("Part")
		innerRangeIndicator.Name        = "InnerRangeIndicator"
		innerRangeIndicator.Shape       = Enum.PartType.Cylinder
		innerRangeIndicator.Anchored    = true
		innerRangeIndicator.CanCollide  = false
		innerRangeIndicator.CanQuery    = false
		innerRangeIndicator.CastShadow  = false
		innerRangeIndicator.Material    = Enum.Material.Neon
		innerRangeIndicator.Color       = Color3.fromRGB(255, 80, 80)
		innerRangeIndicator.Transparency = 0.55
		innerRangeIndicator.Parent      = Workspace
	end
	local diameter = innerRange * 2
	innerRangeIndicator.Size  = Vector3.new(0.16, diameter, diameter)
	innerRangeIndicator.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function updateRangeIndicator(position: Vector3, range: number)
	if not rangeIndicator then
		rangeIndicator = Instance.new("Part")
		rangeIndicator.Name        = "RangeIndicator"
		rangeIndicator.Shape       = Enum.PartType.Cylinder
		rangeIndicator.Anchored    = true
		rangeIndicator.CanCollide  = false
		rangeIndicator.CanQuery    = false -- CRITICAL: excludes this part from mouse raycasts
		                                    -- entirely. Without this, mouse.Hit could land on
		                                    -- the disc itself next frame (TargetFilter only
		                                    -- excludes ONE instance -- currentPreview -- not
		                                    -- this disc), nudging the computed ground height
		                                    -- upward every frame and making the preview drift
		                                    -- skyward the longer the mouse stayed still.
		rangeIndicator.CastShadow  = false
		rangeIndicator.Material    = Enum.Material.Neon
		rangeIndicator.Color       = Color3.fromRGB(255, 255, 255)
		rangeIndicator.Transparency = 0.70
		rangeIndicator.Parent      = Workspace
	end
	local diameter = range * 2
	rangeIndicator.Size  = Vector3.new(0.15, diameter, diameter)
	rangeIndicator.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function setupPreviewModel(model: Model)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = 0.5
			desc.CanCollide   = false
			desc.CanQuery     = false -- belt-and-suspenders alongside mouse.TargetFilter:
			                          -- ensures the preview itself can never be hit by the
			                          -- placement raycast, even if TargetFilter is reset
			                          -- or fails to apply for any reason.
			desc.CastShadow   = false
			desc.Anchored     = true
		end
	end
end

local function movePreviewTo(model: Model, targetPos: Vector3): Vector3
	local sumX, sumY, sumZ, n = 0, 0, 0, 0
	local lowestY = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			sumX += p.Position.X; sumY += p.Position.Y; sumZ += p.Position.Z; n += 1
			lowestY = math.min(lowestY, p.Position.Y - p.Size.Y / 2)
		end
	end
	if n == 0 then return targetPos end

	local center = Vector3.new(sumX / n, sumY / n, sumZ / n)
	local delta  = Vector3.new(
		targetPos.X - center.X,
		targetPos.Y - lowestY,
		targetPos.Z - center.Z
	)
	model:TranslateBy(delta)

	return Vector3.new(targetPos.X, targetPos.Y - lowestY + (center.Y - sumY / n), targetPos.Z)
end

local function snapToGrid(position: Vector3, gridSize: number): Vector3
	return Vector3.new(
		math.round(position.X / gridSize) * gridSize,
		position.Y,
		math.round(position.Z / gridSize) * gridSize
	)
end

function PlacementSystem.setPlacingEnabled(enabled: boolean)
	placingEnabled = enabled
	if not enabled then
		PlacementSystem.cancelPlacement()
	end
end

function PlacementSystem.setRemoveModeEnabled(enabled: boolean)
	removeModeEnabled = enabled
	if enabled then
		PlacementSystem.cancelPlacement()
	else
		if removeHighlight then removeHighlight:Destroy(); removeHighlight = nil end
		hoveredTowerModel = nil
	end
end

local OWNED_TOWER_NAMES = {
	["ArcherTower_Roblox"] = true, ["MageTower_Roblox"] = true,
	["LightNode_Roblox"]   = true, ["Mortar_Roblox"]    = true,
}

function PlacementSystem.cancelPlacement()
	isPlacing = false
	currentTowerName = ""
	if currentPreview then
		currentPreview:Destroy()
		currentPreview = nil
	end
	clearRangeIndicator()
end

function PlacementSystem.startPlacement(towerName: string)
	if not placingEnabled then return end
	PlacementSystem.cancelPlacement()

	local originalModel = Assets:FindFirstChild(towerName)
	if not originalModel or not originalModel:IsA("Model") then
		warn("Model " .. towerName .. " not found in Assets")
		return
	end

	currentTowerName = towerName
	isPlacing        = true

	currentPreview = originalModel:Clone() :: Model
	if currentPreview then
		setupPreviewModel(currentPreview)
		currentPreview.Parent = Workspace
	end
end

-- BUG FIX: mouse.TargetFilter only accepts a SINGLE Instance, not a list,
-- so it was only excluding currentPreview from raycasts -- NOT the
-- rangeIndicator disc. Once the disc existed, the very next frame's
-- mouse.Hit could land ON TOP of the disc (which floats slightly above
-- the ground) instead of the real ground, nudging the computed Y position
-- upward. That higher Y then became the disc's new height, which again
-- got hit next frame, and so on -- the preview (and disc) crept upward
-- every frame, looking like it was "growing"/floating. Parenting the disc
-- under a Folder with no raycast target (or just making it
-- CanQuery = false) keeps the mouse raycast hitting only real terrain/parts.
RunService.RenderStepped:Connect(function()
	if removeModeEnabled then
		local target = mouse.Target
		local model = target and target:FindFirstAncestorOfClass("Model")
		if model and OWNED_TOWER_NAMES[model.Name] then
			if hoveredTowerModel ~= model then
				hoveredTowerModel = model
				if removeHighlight then removeHighlight:Destroy() end
				removeHighlight = Instance.new("Highlight")
				removeHighlight.FillColor = Color3.fromRGB(255, 60, 60)
				removeHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				removeHighlight.FillTransparency = 0.5
				removeHighlight.Parent = model
			end
		else
			hoveredTowerModel = nil
			if removeHighlight then removeHighlight:Destroy(); removeHighlight = nil end
		end
		return
	end

	if not (isPlacing and currentPreview) then
		clearRangeIndicator()
		return
	end

	mouse.TargetFilter = currentPreview
	if not mouse.Target then return end

	local hitPos     = mouse.Hit.Position
	local snapped    = snapToGrid(hitPos, 4)

	movePreviewTo(currentPreview, snapped)

	local range = TOWER_RANGES[currentTowerName]
	if range then
		updateRangeIndicator(Vector3.new(snapped.X, snapped.Y + 0.15, snapped.Z), range)
	else
		clearRangeIndicator()
	end

	local innerRange = TOWER_INNER_RANGES[currentTowerName]
	if innerRange then
		updateInnerRangeIndicator(Vector3.new(snapped.X, snapped.Y + 0.18, snapped.Z), innerRange)
	elseif innerRangeIndicator then
		innerRangeIndicator:Destroy()
		innerRangeIndicator = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and removeModeEnabled and hoveredTowerModel then
		RequestRemoveTower:FireServer(hoveredTowerModel)
		hoveredTowerModel = nil
		if removeHighlight then removeHighlight:Destroy(); removeHighlight = nil end
		return
	end

	if not isPlacing then
		if input.KeyCode == Enum.KeyCode.B then PlacementSystem.startPlacement("ArcherTower_Roblox")
		elseif input.KeyCode == Enum.KeyCode.N then PlacementSystem.startPlacement("MageTower_Roblox")
		elseif input.KeyCode == Enum.KeyCode.M then PlacementSystem.startPlacement("Mortar_Roblox")
		elseif input.KeyCode == Enum.KeyCode.L then PlacementSystem.startPlacement("LightNode_Roblox")
		end
	end

	if input.KeyCode == Enum.KeyCode.Escape and isPlacing then
		PlacementSystem.cancelPlacement()
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 and isPlacing then
		PlacementSystem.cancelPlacement()
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isPlacing and currentPreview then
		local pos = mouse.Hit.Position
		local snapped = snapToGrid(pos, 4)
		RequestPlacement:FireServer(currentTowerName, snapped)
		PlacementSystem.cancelPlacement()
	end
end)

return PlacementSystem
