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
local RequestUpgradeTower = RemoteEvents:WaitForChild("RequestUpgradeTower") :: RemoteEvent
local Assets           = ReplicatedStorage:WaitForChild("Assets")
local TowerAttack      = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TowerAttack"))

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
local upgradeModeEnabled = false

local removeHighlight: Highlight? = nil
local hoveredTowerModel: Model? = nil
local upgradeTooltip: BillboardGui? = nil

local upgradeCurRangeRing: Part? = nil
local upgradeNextRangeRing: Part? = nil
local upgradeTooltip: BillboardGui? = nil

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

local function clearUpgradeRangeRings()
	if upgradeCurRangeRing then upgradeCurRangeRing:Destroy(); upgradeCurRangeRing = nil end
	if upgradeNextRangeRing then upgradeNextRangeRing:Destroy(); upgradeNextRangeRing = nil end
end

local function updateUpgradeRangeRings(position: Vector3, curRange: number, nextRange: number)
	if not upgradeCurRangeRing then
		upgradeCurRangeRing = Instance.new("Part")
		upgradeCurRangeRing.Name = "UpgradeCurRange"
		upgradeCurRangeRing.Shape = Enum.PartType.Cylinder
		upgradeCurRangeRing.Anchored = true
		upgradeCurRangeRing.CanCollide = false
		upgradeCurRangeRing.CanQuery = false
		upgradeCurRangeRing.CastShadow = false
		upgradeCurRangeRing.Material = Enum.Material.Neon
		upgradeCurRangeRing.Color = Color3.fromRGB(100, 180, 255)
		upgradeCurRangeRing.Transparency = 0.55
		upgradeCurRangeRing.Parent = Workspace
	end
	local curDiam = curRange * 2
	upgradeCurRangeRing.Size = Vector3.new(0.14, curDiam, curDiam)
	upgradeCurRangeRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))

	if not upgradeNextRangeRing then
		upgradeNextRangeRing = Instance.new("Part")
		upgradeNextRangeRing.Name = "UpgradeNextRange"
		upgradeNextRangeRing.Shape = Enum.PartType.Cylinder
		upgradeNextRangeRing.Anchored = true
		upgradeNextRangeRing.CanCollide = false
		upgradeNextRangeRing.CanQuery = false
		upgradeNextRangeRing.CastShadow = false
		upgradeNextRangeRing.Material = Enum.Material.Neon
		upgradeNextRangeRing.Color = Color3.fromRGB(255, 215, 60)
		upgradeNextRangeRing.Transparency = 0.50
		upgradeNextRangeRing.Parent = Workspace
	end
	local nextDiam = nextRange * 2
	upgradeNextRangeRing.Size = Vector3.new(0.14, nextDiam, nextDiam)
	upgradeNextRangeRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
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
		upgradeModeEnabled = false
		PlacementSystem.cancelPlacement()
	else
		if removeHighlight then removeHighlight:Destroy(); removeHighlight = nil end
		if upgradeTooltip then upgradeTooltip:Destroy(); upgradeTooltip = nil end
		hoveredTowerModel = nil
	end
end

function PlacementSystem.setUpgradeModeEnabled(enabled: boolean)
	upgradeModeEnabled = enabled
	if enabled then
		removeModeEnabled = false
		PlacementSystem.cancelPlacement()
	else
		if removeHighlight then removeHighlight:Destroy(); removeHighlight = nil end
		if upgradeTooltip then upgradeTooltip:Destroy(); upgradeTooltip = nil end
		clearUpgradeRangeRings()
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
	clearUpgradeRangeRings()
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
	if removeModeEnabled or upgradeModeEnabled then
		local target = mouse.Target
		local model = target and target:FindFirstAncestorOfClass("Model")
		if model and OWNED_TOWER_NAMES[model.Name] then
			if hoveredTowerModel ~= model then
				hoveredTowerModel = model
				if removeHighlight then removeHighlight:Destroy() end
				removeHighlight = Instance.new("Highlight")
				removeHighlight.FillColor = if upgradeModeEnabled then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 180, 50)
				removeHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				removeHighlight.FillTransparency = 0.5
				removeHighlight.Parent = model
			end
		else
			hoveredTowerModel = nil
			if removeHighlight then removeHighlight:Destroy(); removeHighlight = nil end
		end
		if upgradeModeEnabled then
			if hoveredTowerModel then
				local levelVal = hoveredTowerModel:FindFirstChild("TowerLevel") :: IntValue?
				local pos = hoveredTowerModel:GetPivot().Position
				if levelVal and levelVal.Value < TowerAttack.MAX_TOWER_LEVEL then
					local preview = TowerAttack.getUpgradePreview(hoveredTowerModel.Name, levelVal.Value)
					if preview and preview.next then
						if not upgradeTooltip then
							local anchor = hoveredTowerModel.PrimaryPart or hoveredTowerModel:FindFirstChildOfClass("BasePart")
							if anchor then
								local billboard = Instance.new("BillboardGui")
								billboard.Name = "UpgradeTooltip"
								billboard.Size = UDim2.new(0, 140, 0, 60)
								billboard.StudsOffset = Vector3.new(0, 8, 0)
								billboard.Adornee = anchor
								billboard.AlwaysOnTop = true
								billboard.Parent = hoveredTowerModel
								local lines = {"⬆ " .. hoveredTowerModel.Name .. " Lv." .. levelVal.Value .. "→" .. (levelVal.Value + 1)}
								local c, n = preview.current, preview.next
								if c.damage then table.insert(lines, "Dmg: " .. c.damage .. "→" .. n.damage) end
								if c.range then table.insert(lines, "Rng: " .. math.floor(c.range) .. "→" .. math.floor(n.range)) end
								if c.fireRate then table.insert(lines, "Spd: " .. string.format("%.2f", c.fireRate) .. "→" .. string.format("%.2f", n.fireRate) .. "s") end
								table.insert(lines, "💰 $" .. preview.cost)
								local label = Instance.new("TextLabel")
								label.Size = UDim2.new(1, 0, 1, 0)
								label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
								label.BackgroundTransparency = 0.15
								label.TextColor3 = Color3.fromRGB(255, 255, 200)
								label.Font = Enum.Font.GothamMedium
								label.TextSize = 13
								label.Text = table.concat(lines, "\n")
								label.TextWrapped = true
								label.Parent = billboard
								upgradeTooltip = billboard
							end
						end
						if preview.current.range and preview.next.range then
							updateUpgradeRangeRings(Vector3.new(pos.X, pos.Y + 0.15, pos.Z), preview.current.range, preview.next.range)
						else
							clearUpgradeRangeRings()
						end
					end
				elseif levelVal and levelVal.Value >= TowerAttack.MAX_TOWER_LEVEL then
					if not upgradeTooltip then
						local anchor = hoveredTowerModel.PrimaryPart or hoveredTowerModel:FindFirstChildOfClass("BasePart")
						if anchor then
							local billboard = Instance.new("BillboardGui")
							billboard.Name = "UpgradeTooltip"
							billboard.Size = UDim2.new(0, 120, 0, 24)
							billboard.StudsOffset = Vector3.new(0, 8, 0)
							billboard.Adornee = anchor
							billboard.AlwaysOnTop = true
							billboard.Parent = hoveredTowerModel
							local label = Instance.new("TextLabel")
							label.Size = UDim2.new(1, 0, 1, 0)
							label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
							label.BackgroundTransparency = 0.15
							label.TextColor3 = Color3.fromRGB(255, 220, 50)
							label.Font = Enum.Font.GothamBold
							label.TextSize = 14
							label.Text = "✅ MAX Lv." .. levelVal.Value
							label.Parent = billboard
							upgradeTooltip = billboard
						end
					end
					clearUpgradeRangeRings()
				end
			else
				if upgradeTooltip then upgradeTooltip:Destroy(); upgradeTooltip = nil end
				clearUpgradeRangeRings()
			end
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

	if input.UserInputType == Enum.UserInputType.MouseButton1 and upgradeModeEnabled and hoveredTowerModel then
		RequestUpgradeTower:FireServer(hoveredTowerModel)
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
