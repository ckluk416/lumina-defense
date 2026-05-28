--!strict
local EnvironmentSetup = {}

local Workspace = game:GetService("Workspace")

-- Route definitions: each route has a spawn point position and a list of waypoints
-- The map is ~200x200 studs. Base is at center-back.
export type RouteConfig = {
	spawnPosition: Vector3,
	spawnColor: Color3,
	waypoints: {Vector3}
}

local BASE_POSITION = Vector3.new(0, 2.5, 0)
local BASE_SIZE = Vector3.new(16, 5, 16)

local ROUTES: {[string]: RouteConfig} = {
	["A"] = {
		spawnPosition = Vector3.new(-80, 2, -80),
		spawnColor = Color3.fromRGB(255, 80, 80), -- Red
		waypoints = {
			Vector3.new(-80, 1, -80),
			Vector3.new(-60, 1, -40),
			Vector3.new(-30, 1, -20),
			Vector3.new(-10, 1, -5),
			BASE_POSITION,
		}
	},
	["B"] = {
		spawnPosition = Vector3.new(80, 2, -80),
		spawnColor = Color3.fromRGB(80, 200, 255), -- Cyan
		waypoints = {
			Vector3.new(80, 1, -80),
			Vector3.new(60, 1, -40),
			Vector3.new(30, 1, -20),
			Vector3.new(10, 1, -5),
			BASE_POSITION,
		}
	},
	["C"] = {
		spawnPosition = Vector3.new(0, 2, 90),
		spawnColor = Color3.fromRGB(200, 80, 255), -- Purple
		waypoints = {
			Vector3.new(0, 1, 90),
			Vector3.new(-20, 1, 60),
			Vector3.new(20, 1, 35),
			Vector3.new(5, 1, 10),
			BASE_POSITION,
		}
	}
}

function EnvironmentSetup.getRoutes(): {[string]: RouteConfig}
	return ROUTES
end

function EnvironmentSetup.getBasePosition(): Vector3
	return BASE_POSITION
end

function EnvironmentSetup.init()
	-- 1. Create Ground Plane (large grass field)
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(220, 1, 220)
	ground.Position = Vector3.new(0, -0.5, 0)
	ground.Anchored = true
	ground.Color = Color3.fromRGB(75, 130, 65) -- Dark grass green
	ground.Material = Enum.Material.Grass
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.BottomSurface = Enum.SurfaceType.Smooth
	ground.Parent = Workspace
	
	-- 2. Create Base (Markas) at center
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = BASE_SIZE
	base.Position = BASE_POSITION
	base.Anchored = true
	base.Color = Color3.fromRGB(0, 120, 255)
	base.Material = Enum.Material.Neon
	base.Transparency = 0.1
	base.Parent = Workspace
	
	-- Add a glowing ring around base
	local baseRing = Instance.new("Part")
	baseRing.Name = "BaseRing"
	baseRing.Size = Vector3.new(20, 0.5, 20)
	baseRing.Position = Vector3.new(0, 0.25, 0)
	baseRing.Anchored = true
	baseRing.Color = Color3.fromRGB(0, 180, 255)
	baseRing.Material = Enum.Material.Neon
	baseRing.Transparency = 0.5
	baseRing.Shape = Enum.PartType.Cylinder
	baseRing.Orientation = Vector3.new(0, 0, 90)
	baseRing.CanCollide = false
	baseRing.Parent = Workspace
	
	-- 3. Create Spawn Points and Route Waypoints
	for routeId, routeData in pairs(ROUTES) do
		-- Spawn point marker
		local spawnPoint = Instance.new("Part")
		spawnPoint.Name = "SpawnPoint_" .. routeId
		spawnPoint.Size = Vector3.new(6, 1, 6)
		spawnPoint.Position = routeData.spawnPosition
		spawnPoint.Anchored = true
		spawnPoint.Color = routeData.spawnColor
		spawnPoint.Material = Enum.Material.Neon
		spawnPoint.Transparency = 0.3
		spawnPoint.CanCollide = false
		spawnPoint.Parent = Workspace
		
		-- Route waypoints folder
		local routeFolder = Instance.new("Folder")
		routeFolder.Name = "Route_" .. routeId
		routeFolder.Parent = Workspace
		
		for i, pos in ipairs(routeData.waypoints) do
			local node = Instance.new("Part")
			node.Name = tostring(i)
			node.Size = Vector3.new(1.5, 1.5, 1.5)
			node.Position = pos
			node.Anchored = true
			node.CanCollide = false
			node.Transparency = 0.7
			node.Color = routeData.spawnColor
			node.Shape = Enum.PartType.Ball
			node.Parent = routeFolder
		end
	end
	
	print("[EnvironmentSetup] Map generated: Ground, Base, 3 SpawnPoints, 3 Routes.")
end

-- Run on startup
EnvironmentSetup.init()

return EnvironmentSetup
