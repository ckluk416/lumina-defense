--!strict
local PlacementSystem = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Example function to handle grid snapping (e.g. snap to nearest 4 studs)
function PlacementSystem.snapToGrid(position: Vector3, gridSize: number): Vector3
	return Vector3.new(
		math.round(position.X / gridSize) * gridSize,
		position.Y, -- Usually keep Y as the surface level
		math.round(position.Z / gridSize) * gridSize
	)
end

-- A placeholder function to request placing a tower
function PlacementSystem.requestPlaceTower(towerName: string)
	-- Raycast from mouse to find position
	if mouse.Target then
		local hitPosition = mouse.Hit.Position
		local snappedPosition = PlacementSystem.snapToGrid(hitPosition, 4)
		
		-- Ask server to place the tower
		RequestPlacement:FireServer(towerName, snappedPosition)
	end
end

return PlacementSystem
