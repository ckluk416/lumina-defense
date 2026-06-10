--!strict
-- EnvironmentSetup: Map Configuration Module
--
-- IMPORTANT: This module NO LONGER generates map objects.
-- All map objects must be placed MANUALLY in Roblox Studio:
--
--   Workspace/
--     Base                      (Part, anchored, any size — the main objective)
--     SpawnPoint_A              (Part, anchored — where Route A enemies spawn)
--     SpawnPoint_B              (Part, anchored — where Route B enemies spawn)
--     SpawnPoint_C              (Part, anchored — where Route C enemies spawn)
--     Route_A/  (Folder)
--       1  (Part, anchored) — first waypoint
--       2  (Part, anchored)
--       ...                    — last waypoint should overlap Base position
--     Route_B/  (Folder)
--       1, 2, 3...
--     Route_C/  (Folder)
--       1, 2, 3...
--
-- Use the Terrain editor (top toolbar > Terrain) to paint Grass terrain.
-- Make sure all SpawnPoints and Waypoint parts are invisible (Transparency=1)
-- or small so they don't block gameplay.

local EnvironmentSetup = {}

local Workspace = game:GetService("Workspace")

-- Route IDs used by WaveManager. Add more if you add more routes.
local ROUTE_IDS = {"A", "B", "C"}

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
	if base and base:IsA("BasePart") then
		return base.Position
	end
	return Vector3.new(0, 0, 0)
end

-- On init: just print a status so we know it's running.
function EnvironmentSetup.init()
	-- Verify map objects exist
	local ok = true
	if not Workspace:FindFirstChild("Base") then
		warn("[EnvironmentSetup] ⚠ 'Base' Part not found in Workspace. Place it manually!")
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

EnvironmentSetup.init()

return EnvironmentSetup
