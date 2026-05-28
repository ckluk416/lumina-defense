--!strict
local PlacementSystem = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent
local Assets = ReplicatedStorage:WaitForChild("Assets")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local currentPreview: Model? = nil
local isPlacing = false
local currentTowerName = ""
local originalRotation: CFrame = CFrame.new() -- Store original rotation of the model

-- Grid snapping logic
function PlacementSystem.snapToGrid(position: Vector3, gridSize: number): Vector3
	return Vector3.new(
		math.round(position.X / gridSize) * gridSize,
		position.Y,
		math.round(position.Z / gridSize) * gridSize
	)
end

-- Clear the current preview model
function PlacementSystem.cancelPlacement()
	isPlacing = false
	if currentPreview then
		currentPreview:Destroy()
		currentPreview = nil
	end
	currentTowerName = ""
end

-- Make all parts in a model transparent and non-collidable
local function setupPreviewModel(model: Model)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = 0.5
			desc.CanCollide = false
			desc.CastShadow = false
			desc.Anchored = true
		end
	end
end

-- Start the placement mode for a specific tower
function PlacementSystem.startPlacement(towerName: string)
	PlacementSystem.cancelPlacement()
	
	local originalModel = Assets:FindFirstChild(towerName)
	if not originalModel or not originalModel:IsA("Model") then
		warn("Model " .. towerName .. " not found in Assets or not a Model")
		return
	end
	
	currentTowerName = towerName
	isPlacing = true
	
	-- Store the original rotation from the source model
	originalRotation = originalModel:GetPivot().Rotation
	
	currentPreview = originalModel:Clone() :: Model
	if currentPreview then
		setupPreviewModel(currentPreview)
		currentPreview.Parent = Workspace
	end
end

-- Update the preview position every frame
RunService.RenderStepped:Connect(function()
	if isPlacing and currentPreview then
		-- Ignore the preview model itself for mouse raycasting
		mouse.TargetFilter = currentPreview
		
		if mouse.Target then
			local hitPosition = mouse.Hit.Position
			local snappedPosition = PlacementSystem.snapToGrid(hitPosition, 4)
			
			-- Preserve original model rotation, only change position
			currentPreview:PivotTo(CFrame.new(snappedPosition) * originalRotation)
		end
	end
end)

-- Handle clicking to place
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Keybinds for tower placement
	if not isPlacing then
		if input.KeyCode == Enum.KeyCode.B then
			PlacementSystem.startPlacement("ArcherTower_Roblox")
		elseif input.KeyCode == Enum.KeyCode.N then
			PlacementSystem.startPlacement("MageTower_Roblox")
		elseif input.KeyCode == Enum.KeyCode.M then
			PlacementSystem.startPlacement("CannonTower_Roblox")
		elseif input.KeyCode == Enum.KeyCode.L then
			PlacementSystem.startPlacement("LightNode_Roblox")
		end
	end
	
	-- Cancel placement with Escape
	if input.KeyCode == Enum.KeyCode.Escape and isPlacing then
		PlacementSystem.cancelPlacement()
	end
	
	-- Click to place
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isPlacing and currentPreview then
		local placementPos = currentPreview:GetPivot().Position
		RequestPlacement:FireServer(currentTowerName, placementPos)
		PlacementSystem.cancelPlacement()
	end
end)

return PlacementSystem
