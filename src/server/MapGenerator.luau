--!strict
-- MapGenerator: Procedurally generates a fresh map layout (portals, routes,
-- and decoration) each time a match restarts. Replaces the old fully-manual
-- map authored directly in Workspace.
--
-- Generated structure (kept compatible with EnvironmentSetup/WaveManager/PathPreview):
--   Workspace/
--     SpawnPoint_<id>    (Part)              -- one per route, <id> is "A".."D"
--     Route_<id>/        (Folder)
--       1, 2, 3...       (Part waypoints)     -- last one overlaps Base position
--     Portal_SpawnPoint_<id> (Model, clone of SpawnPortal_Roblox)
--     MapDecoration/     (Folder)             -- procedural decor, cleared+rebuilt each generation

local MapGenerator = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local BASE_POSITION = Vector3.new(0, 0, 0)
local MIN_ROUTES = 2
local MAX_ROUTES = 4
local PORTAL_RADIUS_MIN = 75
local PORTAL_RADIUS_MAX = 100
local MIN_ANGLE_SEPARATION_DEG = 50 -- keep portals from spawning too close to each other
local WAYPOINTS_PER_ROUTE_MIN = 4
local WAYPOINTS_PER_ROUTE_MAX = 6
local PATH_BEND_STRENGTH = 18 -- max sideways offset (studs) applied to middle waypoints, for a "winding" feel
local WAYPOINT_Y = 3

local ROUTE_LETTERS = {"A", "B", "C", "D"}

-- Track what we generated so the next call can clean it all up first
local generatedRouteIds: {string} = {}

local function clearPreviousGeneration()
	for _, id in ipairs(generatedRouteIds) do
		local sp = Workspace:FindFirstChild("SpawnPoint_" .. id)
		if sp then sp:Destroy() end

		local routeFolder = Workspace:FindFirstChild("Route_" .. id)
		if routeFolder then routeFolder:Destroy() end

		local portal = Workspace:FindFirstChild("Portal_SpawnPoint_" .. id)
		if portal then portal:Destroy() end
	end
	generatedRouteIds = {}

	local decoFolder = Workspace:FindFirstChild("MapDecoration")
	if decoFolder then decoFolder:Destroy() end
end

-- Picks N angles (degrees) around a circle, spaced apart by at least minSeparation,
-- with some randomness so layouts differ between generations.
local function pickSpreadAngles(count: number, minSeparation: number): {number}
	local baseStep = 360 / count
	local angles: {number} = {}
	local jitterRange = math.max(0, (baseStep - minSeparation) / 2)

	for i = 1, count do
		local base = (i - 1) * baseStep
		local jitter = (math.random() * 2 - 1) * jitterRange
		table.insert(angles, base + jitter)
	end

	-- Rotate the whole layout by a random offset so it's not always portal #1 at angle 0
	local rotationOffset = math.random() * 360
	for i = 1, count do
		angles[i] = (angles[i] + rotationOffset) % 360
	end

	return angles
end

-- Builds a winding set of waypoints from a spawn point to the Base, with a
-- given number of intermediate bends.
local function buildWaypoints(spawnPos: Vector3, basePos: Vector3, waypointCount: number): {Vector3}
	local waypoints: {Vector3} = {}

	local direction = (basePos - spawnPos)
	local totalDistance = direction.Magnitude
	local forward = direction.Unit
	local perpendicular = Vector3.new(-forward.Z, 0, forward.X)

	table.insert(waypoints, Vector3.new(spawnPos.X, WAYPOINT_Y, spawnPos.Z))

	for i = 1, waypointCount - 2 do
		local t = i / (waypointCount - 1)
		local straightPoint = spawnPos + forward * (totalDistance * t)

		local taper = math.sin(t * math.pi)
		local bendOffset = (math.random() * 2 - 1) * PATH_BEND_STRENGTH * taper

		local bentPoint = straightPoint + perpendicular * bendOffset
		table.insert(waypoints, Vector3.new(bentPoint.X, WAYPOINT_Y, bentPoint.Z))
	end

	table.insert(waypoints, Vector3.new(basePos.X, WAYPOINT_Y, basePos.Z))

	return waypoints
end

-- Creates the invisible-ish waypoint Part, matching the style of the
-- original hand-placed waypoints (small, semi-transparent).
local function createWaypointPart(position: Vector3, index: number, parent: Instance, color: Color3)
	local part = Instance.new("Part")
	part.Name = tostring(index)
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.6
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = parent
end

local ROUTE_COLORS = {
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(0, 200, 255),
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(120, 255, 120),
}

-- Spawns a Portal model at the given position.
-- NOTE: deliberately uses TranslateBy, not PivotTo — SpawnPortal_Roblox's
-- pivot rotation is verified identity, but we keep this consistent with the
-- rest of the codebase's safe-placement pattern in case the asset is
-- replaced later with one that has a baked pivot offset.
local function spawnPortal(position: Vector3, routeId: string): Model
	local template = Assets:FindFirstChild("SpawnPortal_Roblox") :: Model
	local portal = template:Clone()
	portal.Name = "Portal_SpawnPoint_" .. routeId

	local sumX, sumZ, count = 0, 0, 0
	local lowestY = math.huge
	for _, part in ipairs(portal:GetDescendants()) do
		if part:IsA("BasePart") then
			sumX += part.Position.X
			sumZ += part.Position.Z
			count += 1
			lowestY = math.min(lowestY, part.Position.Y - part.Size.Y / 2)
		end
	end
	local currentCenter = Vector3.new(sumX / count, 0, sumZ / count)

	local delta = Vector3.new(
		position.X - currentCenter.X,
		0 - lowestY,
		position.Z - currentCenter.Z
	)
	portal:TranslateBy(delta)
	portal.Parent = Workspace
	return portal
end

-- ===== Decoration =====
-- Mixed sci-fi/neon (small glowing crystal pylons, matching the Base's
-- crystal theme) + fantasy/natural (chunky rock clusters) decoration,
-- scattered near each route so the map doesn't feel empty, without
-- blocking the enemy path itself.

local DECORATION_MIN_OFFSET = 6   -- min distance from the path centerline
local DECORATION_MAX_OFFSET = 14  -- max distance from the path centerline
local DECORATION_CHANCE_PER_SEGMENT = 0.6 -- probability of decor per path segment, per side

-- Small glowing crystal pylon (sci-fi/neon theme)
local function createCrystalPylon(position: Vector3, parent: Instance)
	local height = 3 + math.random() * 3
	local crystal = Instance.new("Part")
	crystal.Name = "CrystalPylon"
	crystal.Shape = Enum.PartType.Block
	crystal.Size = Vector3.new(1.2, height, 1.2)
	crystal.Position = position + Vector3.new(0, height / 2, 0)
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Material = Enum.Material.Neon
	crystal.Color = Color3.fromRGB(120, 200, 255)
	crystal.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(140, 210, 255)
	light.Brightness = 2
	light.Range = 14
	light.Parent = crystal
end

-- Chunky natural rock cluster (fantasy/organic theme). Slightly bigger and
-- more varied than the engine's own ambient terrain rocks, with a touch of
-- random tilt so the cluster doesn't look like uniform stacked spheres.
local ROCK_COLORS = {
	Color3.fromRGB(132, 124, 116),
	Color3.fromRGB(96, 90, 84),
	Color3.fromRGB(150, 140, 128),
}

local function createRockCluster(position: Vector3, parent: Instance)
	local rockCount = math.random(2, 4)
	for i = 1, rockCount do
		local size = 2.5 + math.random() * 3.5
		local rock = Instance.new("Part")
		rock.Name = "RockDecor"
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.new(size, size * 0.8, size)
		local jitter = Vector3.new((math.random() * 2 - 1) * 3, 0, (math.random() * 2 - 1) * 3)
		-- size*0.4 lifts the rock so it rests on top of the ground rather
		-- than looking half-buried, since the ball's vertical radius is
		-- size*0.8/2 = size*0.4.
		rock.CFrame = CFrame.new(position + jitter + Vector3.new(0, size * 0.4, 0))
			* CFrame.Angles(0, math.rad(math.random(0, 359)), math.rad(math.random(-8, 8)))
		rock.Anchored = true
		rock.CanCollide = false
		rock.Material = Enum.Material.Rock
		rock.Color = ROCK_COLORS[math.random(1, #ROCK_COLORS)]
		rock.Parent = parent
	end
end

-- Scatters decoration along a route's waypoints, offset to either side so
-- it frames the path without obstructing it.
local function decorateRoute(waypoints: {Vector3}, decorationFolder: Instance)
	for i = 1, #waypoints - 1 do
		local fromPoint = waypoints[i]
		local toPoint = waypoints[i + 1]
		local segmentDir = (toPoint - fromPoint)
		if segmentDir.Magnitude < 0.01 then continue end

		local forward = segmentDir.Unit
		local perpendicular = Vector3.new(-forward.Z, 0, forward.X)
		local midpoint = fromPoint + segmentDir * 0.5

		for _, side in ipairs({-1, 1}) do
			if math.random() <= DECORATION_CHANCE_PER_SEGMENT then
				local offsetDist = DECORATION_MIN_OFFSET + math.random() * (DECORATION_MAX_OFFSET - DECORATION_MIN_OFFSET)
				local decorPos = midpoint + perpendicular * (offsetDist * side)
				decorPos = Vector3.new(decorPos.X, 0, decorPos.Z)

				-- Mix of sci-fi and fantasy decor, roughly half and half
				if math.random() < 0.5 then
					createCrystalPylon(decorPos, decorationFolder)
				else
					createRockCluster(decorPos, decorationFolder)
				end
			end
		end
	end
end

-- Generates a brand-new map layout: 2-4 random routes from portals to Base.
-- Returns the list of generated route IDs (e.g. {"A", "B", "C"}).
function MapGenerator.generate(): {string}
	clearPreviousGeneration()

	local decorationFolder = Instance.new("Folder")
	decorationFolder.Name = "MapDecoration"
	decorationFolder.Parent = Workspace

	local routeCount = math.random(MIN_ROUTES, MAX_ROUTES)
	local angles = pickSpreadAngles(routeCount, MIN_ANGLE_SEPARATION_DEG)
	local routeIds: {string} = {}

	for i = 1, routeCount do
		local routeId = ROUTE_LETTERS[i]
		table.insert(routeIds, routeId)

		local radius = PORTAL_RADIUS_MIN + math.random() * (PORTAL_RADIUS_MAX - PORTAL_RADIUS_MIN)
		local angleRad = math.rad(angles[i])
		local spawnPos = Vector3.new(
			BASE_POSITION.X + math.cos(angleRad) * radius,
			0,
			BASE_POSITION.Z + math.sin(angleRad) * radius
		)

		-- SpawnPoint part (used by EnemyAI/WaveManager to know where to spawn enemies)
		local spawnPoint = Instance.new("Part")
		spawnPoint.Name = "SpawnPoint_" .. routeId
		spawnPoint.Size = Vector3.new(4, 1, 4)
		spawnPoint.Position = Vector3.new(spawnPos.X, 3, spawnPos.Z)
		spawnPoint.Anchored = true
		spawnPoint.CanCollide = false
		spawnPoint.Transparency = 1
		spawnPoint.Color = ROUTE_COLORS[i]
		spawnPoint.Parent = Workspace

		-- Route folder with winding waypoints
		local routeFolder = Instance.new("Folder")
		routeFolder.Name = "Route_" .. routeId
		routeFolder.Parent = Workspace

		local waypointCount = math.random(WAYPOINTS_PER_ROUTE_MIN, WAYPOINTS_PER_ROUTE_MAX)
		local waypoints = buildWaypoints(spawnPos, BASE_POSITION, waypointCount)
		for idx, point in ipairs(waypoints) do
			createWaypointPart(point, idx, routeFolder, ROUTE_COLORS[i])
		end

		-- Visible Portal model at the spawn point
		spawnPortal(spawnPos, routeId)

		-- Decorate alongside this route (mixed sci-fi crystals + natural rocks)
		decorateRoute(waypoints, decorationFolder)
	end

	generatedRouteIds = routeIds
	print("[MapGenerator] Generated " .. routeCount .. " route(s): " .. table.concat(routeIds, ", "))

	return routeIds
end

function MapGenerator.getGeneratedRouteIds(): {string}
	return generatedRouteIds
end

return MapGenerator