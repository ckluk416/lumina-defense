--!strict
-- EnvironmentSetup: Map Configuration Module
--
-- Reads map objects from Workspace and exposes them to WaveManager/EnemyAI.
-- As of the procedural map update, the actual map objects (SpawnPoints,
-- Route_<id> folders, Portals) are created at runtime by MapGenerator on
-- every match restart, instead of being placed manually in Studio:
--
--   Workspace/
--     Base                       (Model -- placed once, stays fixed at origin)
--     SpawnPoint_<id>             (Part)              -- one per generated route
--     Route_<id>/  (Folder)
--       1, 2, 3...    (Part waypoints) -- last one overlaps Base position
--     Portal_SpawnPoint_<id>      (Model)
--
-- Call order: MapGenerator.generate() -> EnvironmentSetup.setRouteIds(...)
-- with the returned route IDs -> EnvironmentSetup.init() to verify.
-- See Server (init script) for the exact call order.

local EnvironmentSetup = {}

local Workspace = game:GetService("Workspace")

-- Route IDs are now determined dynamically by MapGenerator at the start of
-- each match (2-4 random routes), instead of a fixed {"A","B","C"} list.
-- This is set via EnvironmentSetup.setRouteIds() right after generation.
local ROUTE_IDS: {string} = {}

function EnvironmentSetup.setRouteIds(routeIds: {string})
	ROUTE_IDS = routeIds
end

function EnvironmentSetup.getRouteIds(): {string}
	return ROUTE_IDS
end

-- Returns the Position of a SpawnPoint by route ID.
function EnvironmentSetup.getSpawnPosition(routeId: string): Vector3?
	local sp = Workspace:FindFirstChild("SpawnPoint_" .. routeId)
	if sp and sp:IsA("BasePart") then
		return sp.Position
	end
	warn("[EnvironmentSetup] SpawnPoint_" .. routeId .. " not found in Workspace!")
	return nil
end

-- Returns ordered waypoint positions for a route.
function EnvironmentSetup.getRouteWaypoints(routeId: string): {Vector3}
	local waypoints: {Vector3} = {}
	local folder = Workspace:FindFirstChild("Route_" .. routeId)
	if not folder then
		warn("[EnvironmentSetup] Route_" .. routeId .. " folder not found in Workspace!")
		return waypoints
	end

	local nodes = folder:GetChildren()
	table.sort(nodes, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)

	for _, node in ipairs(nodes) do
		if node:IsA("BasePart") then
			table.insert(waypoints, node.Position)
		end
	end

	return waypoints
end

-- Returns Base position.
function EnvironmentSetup.getBasePosition(): Vector3
	local base = Workspace:FindFirstChild("Base")
	if base then
		if base:IsA("BasePart") then
			return base.Position
		elseif base:IsA("Model") then
			if base.PrimaryPart then
				return base.PrimaryPart.Position
			else
				return base:GetPivot().Position
			end
		end
	end
	return Vector3.new(0, 0, 0)
end

-- On init: just print a status so we know it's running.
function EnvironmentSetup.init()
	-- Verify map objects exist
	local ok = true
	if not Workspace:FindFirstChild("Base") then
		warn("[EnvironmentSetup] ⚠ 'Base' not found in Workspace. Place it manually!")
		ok = false
	end
	for _, id in ipairs(ROUTE_IDS) do
		if not Workspace:FindFirstChild("SpawnPoint_" .. id) then
			warn("[EnvironmentSetup] ⚠ 'SpawnPoint_" .. id .. "' not found. Place it manually!")
			ok = false
		end
		if not Workspace:FindFirstChild("Route_" .. id) then
			warn("[EnvironmentSetup] ⚠ 'Route_" .. id .. "' folder not found. Create it manually!")
			ok = false
		end
	end
	if ok then
		print("[EnvironmentSetup] ✓ All map objects found!")
	else
		print("[EnvironmentSetup] ⚠ Some map objects missing — see warnings above.")
	end
end

-- NOTE: EnvironmentSetup.init() is intentionally NOT auto-called here.
-- It must run after MapGenerator.generate() + EnvironmentSetup.setRouteIds(),
-- which Server (init script) orchestrates in the correct order.

return EnvironmentSetup