--!strict
local CameraController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isTactical = false
local currentCenter = Vector3.new(0, 0, 0)
local currentHeight = 150
local minHeight = 50
local maxHeight = 250
local panSpeed = 100 -- studs per second

local keysDown = {
	W = false,
	A = false,
	S = false,
	D = false,
	Up = false,
	Down = false,
	Left = false,
	Right = false,
}

local renderConnection: RBXScriptConnection? = nil

-- Find the base position to initialize camera focus
local function getInitialFocus(): Vector3
	local base = Workspace:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		return base.Position
	end
	return Vector3.new(0, 0, 0)
end

-- Update camera position and zoom
local function updateCamera(dt: number)
	if not isTactical then return end
	
	-- Calculate move direction
	local moveX = 0
	local moveZ = 0
	
	if keysDown.W or keysDown.Up then
		moveZ -= 1
	end
	if keysDown.S or keysDown.Down then
		moveZ += 1
	end
	if keysDown.A or keysDown.Left then
		moveX -= 1
	end
	if keysDown.D or keysDown.Right then
		moveX += 1
	end
	
	-- Normalize movement vector
	local moveDir = Vector3.new(moveX, 0, moveZ)
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
		currentCenter = currentCenter + moveDir * panSpeed * dt
	end
	
	-- Apply to camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(currentCenter + Vector3.new(0, currentHeight, 0)) * CFrame.Angles(-math.pi/2, 0, 0)
end

-- Enable tactical top-down view
function CameraController.enableTactical()
	if isTactical then return end
	isTactical = true
	
	-- Reset center to Base position
	currentCenter = getInitialFocus()
	
	-- Stop player character movement
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
		end
	end
	
	-- Change camera type and focus
	camera.CameraType = Enum.CameraType.Scriptable
	
	-- Bind update loop
	renderConnection = RunService.RenderStepped:Connect(updateCamera)
	print("Tactical Camera Enabled. Use WASD/Arrows to pan, Mouse Scroll to zoom.")
end

-- Disable tactical view, return to standard Roblox camera
function CameraController.disableTactical()
	if not isTactical then return end
	isTactical = false
	
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	
	-- Restore player character movement
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 -- Roblox default
		end
	end
	
	-- Restore camera type
	camera.CameraType = Enum.CameraType.Custom
	print("Tactical Camera Disabled. Returned to default camera.")
end

-- Toggle camera mode
function CameraController.toggleCamera()
	if isTactical then
		CameraController.disableTactical()
	else
		CameraController.enableTactical()
	end
end

-- Track key presses
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.W then
		keysDown.W = true
	elseif input.KeyCode == Enum.KeyCode.A then
		keysDown.A = true
	elseif input.KeyCode == Enum.KeyCode.S then
		keysDown.S = true
	elseif input.KeyCode == Enum.KeyCode.D then
		keysDown.D = true
	elseif input.KeyCode == Enum.KeyCode.Up then
		keysDown.Up = true
	elseif input.KeyCode == Enum.KeyCode.Down then
		keysDown.Down = true
	elseif input.KeyCode == Enum.KeyCode.Left then
		keysDown.Left = true
	elseif input.KeyCode == Enum.KeyCode.Right then
		keysDown.Right = true
	elseif input.KeyCode == Enum.KeyCode.V then
		CameraController.toggleCamera()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then
		keysDown.W = false
	elseif input.KeyCode == Enum.KeyCode.A then
		keysDown.A = false
	elseif input.KeyCode == Enum.KeyCode.S then
		keysDown.S = false
	elseif input.KeyCode == Enum.KeyCode.D then
		keysDown.D = false
	elseif input.KeyCode == Enum.KeyCode.Up then
		keysDown.Up = false
	elseif input.KeyCode == Enum.KeyCode.Down then
		keysDown.Down = false
	elseif input.KeyCode == Enum.KeyCode.Left then
		keysDown.Left = false
	elseif input.KeyCode == Enum.KeyCode.Right then
		keysDown.Right = false
	end
end)

-- Handle zoom with mouse scrollwheel
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not isTactical then return end
	
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local scroll = input.Position.Z
		currentHeight = math.clamp(currentHeight - scroll * 15, minHeight, maxHeight)
	end
end)

return CameraController
