--!strict
-- MapGenerator: Procedurally generates a fresh map layout (portals, routes,
-- stone footpaths, natural decoration, and a perimeter wall) each time a
-- match restarts. Replaces the old fully-manual map authored directly in
-- Workspace.
--
-- Generated structure (kept compatible with EnvironmentSetup/WaveManager/PathPreview):
--   Workspace/
--     SpawnPoint_<id>    (Part)              -- one per route, <id> is "A".."D"
--     Route_<id>/        (Folder)
--       1, 2, 3...       (Part waypoints)     -- last one overlaps Base position
--     Portal_SpawnPoint_<id> (Model, clone of SpawnPortal_Roblox)
--     MapDecoration/     (Folder)             -- procedural trees/rocks, cleared+rebuilt each generation
--     MapBoundary/       (Folder)             -- perimeter wall, cleared+rebuilt each generation
--     MapFootpaths/       (Folder)            -- flat stone footpath segments following each route

local MapGenerator = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")

-- The Terrain's actual visible surface sits at world Y=2 (its voxel fill
-- spans Y=-2..2), confirmed via raycast at many points across the map.
-- Everything that should "sit on the ground" (portals, footpaths, wall,
-- decoration base) must use this instead of Y=0.
local GROUND_LEVEL = 2

local BASE_POSITION = Vector3.new(0, GROUND_LEVEL, 0)
local MIN_ROUTES = 2
local MAX_ROUTES = 4
-- Weighted so 4 routes is rarer: roughly 2->35%, 3->40%, 4->25%
local ROUTE_COUNT_WEIGHTS = {
	[2] = 35,
	[3] = 40,
	[4] = 25,
}
local PORTAL_RADIUS_MIN = 90
local PORTAL_RADIUS_MAX = 160 -- wider spread than before for more position variety
local MIN_ANGLE_SEPARATION_DEG = 35 -- lower than before, allows more varied/closer arrangements
local WAYPOINTS_PER_ROUTE_MIN = 4
local WAYPOINTS_PER_ROUTE_MAX = 6
local PATH_BEND_STRENGTH = 24 -- max sideways offset (studs) applied to middle waypoints, for a "winding" feel
local WAYPOINT_Y = GROUND_LEVEL + 1 -- slightly above ground so EnemyAI's pathing height looks natural
local OVERLAP_ROUTE_CHANCE = 0.35 -- chance a route gets a deliberate detour that crosses near another route, making it feel longer

local ROUTE_LETTERS = {"A", "B", "C", "D"}

-- Track what we generated so the next call can clean it all up first
local generatedRouteIds: {string} = {}

-- IMPORTANT: this does NOT rely on the generatedRouteIds module variable,
-- because that variable lives only in server script memory and resets to
-- empty every time a new Luau VM starts (e.g. each Play session). The
-- Workspace itself is what persists across sessions in the .rbxl file, so
-- we scan Workspace directly by name pattern and destroy ALL previously
-- generated objects, regardless of which session created them. This is
-- what actually prevents portals/routes from one playtest piling up on
-- top of the next one.
local function clearPreviousGeneration()
	for _, child in ipairs(Workspace:GetChildren()) do
		local name = child.Name
		if string.match(name, "^SpawnPoint_%a$")
			or string.match(name, "^Route_%a$")
			or string.match(name, "^Portal_SpawnPoint_%a$")
			or name == "MapDecoration"
			or name == "MapBoundary"
			or name == "MapFootpaths"
		then
			child:Destroy()
		end
	end
	generatedRouteIds = {}
end

-- Picks a random route count using ROUTE_COUNT_WEIGHTS (weighted random pick).
local function pickWeightedRouteCount(): number
	local totalWeight = 0
	for _, w in pairs(ROUTE_COUNT_WEIGHTS) do
		totalWeight += w
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for count = MIN_ROUTES, MAX_ROUTES do
		cumulative += ROUTE_COUNT_WEIGHTS[count] or 0
		if roll <= cumulative then
			return count
		end
	end
	return MAX_ROUTES
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
-- given number of intermediate bends. If detourSide is provided (-1 or 1),
-- an extra detour leg is inserted partway through that swings the path out
-- toward a neighboring route's general direction before continuing to Base,
-- making the route feel deliberately longer / overlapping with its neighbor.
local function buildWaypoints(spawnPos: Vector3, basePos: Vector3, waypointCount: number, detourSide: number?): {Vector3}
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

	-- Deliberate detour: swing wide to one side around the 40%-70% mark of
	-- the route before heading to Base, so the path reads as longer and can
	-- visually cross near another route.
	if detourSide then
		local detourT = 0.55
		local detourPoint = spawnPos + forward * (totalDistance * detourT)
		local detourOffset = perpendicular * (detourSide * (PATH_BEND_STRENGTH * 2.2))
		local insertPos = math.max(1, math.floor(#waypoints * 0.6))
		table.insert(waypoints, insertPos + 1, Vector3.new(
			detourPoint.X + detourOffset.X, WAYPOINT_Y, detourPoint.Z + detourOffset.Z
		))
	end

	table.insert(waypoints, Vector3.new(basePos.X, WAYPOINT_Y, basePos.Z))

	return waypoints
end

-- Creates the waypoint marker Part. Solid (not Neon) and mostly transparent
-- so it stays usable for EnemyAI/PathPreview without reading as a glowing
-- decoration in normal gameplay.
local function createWaypointPart(position: Vector3, index: number, parent: Instance, color: Color3)
	local part = Instance.new("Part")
	part.Name = tostring(index)
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.88
	part.Material = Enum.Material.SmoothPlastic
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
		GROUND_LEVEL - lowestY,
		position.Z - currentCenter.Z
	)
	portal:TranslateBy(delta)
	portal.Parent = Workspace
	return portal
end

-- ===== Stone Footpath =====
-- A flat stone walkway built from Parts (not carved terrain), laid along
-- each route's waypoints so the trail from portal to Base has clean,
-- controlled edges instead of an organic terrain blob.

local FOOTPATH_WIDTH = 7
local FOOTPATH_THICKNESS = 0.4
-- Footpath slabs must sit just above the real terrain surface (GROUND_LEVEL),
-- or they end up buried under the terrain and invisible from above.
local FOOTPATH_Y = GROUND_LEVEL + 0.1
local FOOTPATH_MATERIAL = Enum.Material.Slate
local FOOTPATH_COLORS = {
	Color3.fromRGB(120, 112, 100),
	Color3.fromRGB(110, 102, 92),
	Color3.fromRGB(128, 120, 108),
}

-- Lays one straight footpath segment (a flat slab) between two waypoints.
local function layFootpathSegment(fromPoint: Vector3, toPoint: Vector3, parent: Instance)
	local segmentDir = toPoint - fromPoint
	local distance = segmentDir.Magnitude
	if distance < 0.01 then return end

	local midpoint = (fromPoint + toPoint) / 2
	local cf = CFrame.lookAt(
		Vector3.new(midpoint.X, FOOTPATH_Y, midpoint.Z),
		Vector3.new(midpoint.X, FOOTPATH_Y, midpoint.Z) + segmentDir
	)

	local slab = Instance.new("Part")
	slab.Name = "FootpathSlab"
	-- Extend length slightly so consecutive segments overlap cleanly at corners/turns.
	slab.Size = Vector3.new(FOOTPATH_WIDTH, FOOTPATH_THICKNESS, distance + FOOTPATH_WIDTH * 0.5)
	slab.CFrame = cf
	slab.Anchored = true
	slab.CanCollide = false
	slab.Material = FOOTPATH_MATERIAL
	slab.Color = FOOTPATH_COLORS[math.random(1, #FOOTPATH_COLORS)]
	slab.Parent = parent

	-- A circular slab at each joint smooths out corners between segments.
	local joint = Instance.new("Part")
	joint.Name = "FootpathJoint"
	joint.Shape = Enum.PartType.Cylinder
	joint.Size = Vector3.new(FOOTPATH_THICKNESS, FOOTPATH_WIDTH, FOOTPATH_WIDTH)
	joint.CFrame = CFrame.new(Vector3.new(fromPoint.X, FOOTPATH_Y, fromPoint.Z)) * CFrame.Angles(0, 0, math.rad(90))
	joint.Anchored = true
	joint.CanCollide = false
	joint.Material = FOOTPATH_MATERIAL
	joint.Color = FOOTPATH_COLORS[1]
	joint.Parent = parent
end

-- Lays the full footpath for a route by walking through its waypoints.
local function layRouteFootpath(waypoints: {Vector3}, footpathFolder: Instance)
	for i = 1, #waypoints - 1 do
		layFootpathSegment(waypoints[i], waypoints[i + 1], footpathFolder)
	end
	-- Final joint circle at the Base end so the path doesn't end with a sharp square cut.
	local lastPoint = waypoints[#waypoints]
	local joint = Instance.new("Part")
	joint.Name = "FootpathJoint"
	joint.Shape = Enum.PartType.Cylinder
	joint.Size = Vector3.new(FOOTPATH_THICKNESS, FOOTPATH_WIDTH, FOOTPATH_WIDTH)
	joint.CFrame = CFrame.new(Vector3.new(lastPoint.X, FOOTPATH_Y, lastPoint.Z)) * CFrame.Angles(0, 0, math.rad(90))
	joint.Anchored = true
	joint.CanCollide = false
	joint.Material = FOOTPATH_MATERIAL
	joint.Color = FOOTPATH_COLORS[1]
	joint.Parent = footpathFolder
end

-- ===== Natural Decoration (trees + rocks) =====
-- Fully natural/fantasy theme: low-poly procedural trees and rock clusters
-- scattered near each route, offset enough to frame the path without
-- blocking it.

local DECORATION_MIN_OFFSET = 11   -- min distance from the path centerline (clears the footpath width)
local DECORATION_MAX_OFFSET = 26  -- max distance from the path centerline
local DECORATION_CHANCE_PER_SEGMENT = 0.6 -- probability of decor per path segment, per side

local TRUNK_COLORS = {
	Color3.fromRGB(92, 64, 42),
	Color3.fromRGB(74, 52, 36),
}

local LEAF_COLORS = {
	Color3.fromRGB(58, 102, 48),
	Color3.fromRGB(70, 118, 56),
	Color3.fromRGB(48, 90, 42),
}

-- Simple low-poly tree: cylinder trunk + a stacked "canopy" of spheres.
local function createTree(position: Vector3, parent: Instance)
	local trunkHeight = 5 + math.random() * 3
	local trunkRadius = 0.6 + math.random() * 0.3

	local trunk = Instance.new("Part")
	trunk.Name = "TreeTrunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(trunkHeight, trunkRadius * 2, trunkRadius * 2)
	-- Cylinder's default orientation has its length along X; rotate so it stands upright along Y.
	trunk.CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = TRUNK_COLORS[math.random(1, #TRUNK_COLORS)]
	trunk.Parent = parent

	local canopyColor = LEAF_COLORS[math.random(1, #LEAF_COLORS)]
	local canopyBaseY = position.Y + trunkHeight * 0.75
	local canopyLayers = math.random(2, 3)
	for layer = 1, canopyLayers do
		local layerSize = (3.2 - (layer - 1) * 0.6) + math.random() * 0.6
		local leaf = Instance.new("Part")
		leaf.Name = "TreeCanopy"
		leaf.Shape = Enum.PartType.Ball
		leaf.Size = Vector3.new(layerSize, layerSize * 0.85, layerSize)
		leaf.Position = position + Vector3.new(0, canopyBaseY - position.Y + (layer - 1) * (layerSize * 0.55), 0)
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Material = Enum.Material.Grass
		leaf.Color = canopyColor
		leaf.Parent = parent
	end
end

-- Chunky natural rock cluster. Slightly bigger and more varied than the
-- engine's own ambient terrain rocks, with a touch of random tilt so the
-- cluster doesn't look like uniform stacked spheres.
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
				decorPos = Vector3.new(decorPos.X, GROUND_LEVEL, decorPos.Z)

				-- Mix of trees and rocks, roughly half and half
				if math.random() < 0.5 then
					createTree(decorPos, decorationFolder)
				else
					createRockCluster(decorPos, decorationFolder)
				end
			end
		end
	end
end

-- ===== Perimeter Wall =====
-- A ring of chunky stone/earth blocks around the playable area, so the map
-- feels enclosed instead of fading into open grass forever.

local WALL_RADIUS = 205 -- pushed out a bit further since portals can now spawn up to radius 160
local WALL_SEGMENT_WIDTH = 10
local WALL_HEIGHT_MIN = 8
local WALL_HEIGHT_MAX = 14
local WALL_MATERIAL = Enum.Material.Rock
local WALL_COLOR = Color3.fromRGB(110, 102, 92)

local function buildPerimeterWall(wallFolder: Instance)
	local circumference = 2 * math.pi * WALL_RADIUS
	local segmentCount = math.floor(circumference / WALL_SEGMENT_WIDTH)

	for i = 1, segmentCount do
		local angle = (i / segmentCount) * 360
		local angleRad = math.rad(angle)
		local pos = Vector3.new(
			BASE_POSITION.X + math.cos(angleRad) * WALL_RADIUS,
			GROUND_LEVEL,
			BASE_POSITION.Z + math.sin(angleRad) * WALL_RADIUS
		)

		local height = WALL_HEIGHT_MIN + math.random() * (WALL_HEIGHT_MAX - WALL_HEIGHT_MIN)
		local segment = Instance.new("Part")
		segment.Name = "WallSegment"
		segment.Size = Vector3.new(WALL_SEGMENT_WIDTH * 1.05, height, 6) -- slight overlap so there are no visible gaps
		segment.CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, -angleRad, 0)
		segment.Anchored = true
		segment.CanCollide = true
		segment.Material = WALL_MATERIAL
		segment.Color = WALL_COLOR
		segment.Parent = wallFolder
	end
end

-- Generates a brand-new map layout: 2-4 random routes from portals to Base,
-- with a stone footpath, natural decoration, and a perimeter wall.
-- Returns the list of generated route IDs (e.g. {"A", "B", "C"}).
function MapGenerator.generate(): {string}
	clearPreviousGeneration()

	local decorationFolder = Instance.new("Folder")
	decorationFolder.Name = "MapDecoration"
	decorationFolder.Parent = Workspace

	local footpathFolder = Instance.new("Folder")
	footpathFolder.Name = "MapFootpaths"
	footpathFolder.Parent = Workspace

	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "MapBoundary"
	wallFolder.Parent = Workspace
	buildPerimeterWall(wallFolder)

	local routeCount = pickWeightedRouteCount()
	local angles = pickSpreadAngles(routeCount, MIN_ANGLE_SEPARATION_DEG)
	local routeIds: {string} = {}

	for i = 1, routeCount do
		local routeId = ROUTE_LETTERS[i]
		table.insert(routeIds, routeId)

		local radius = PORTAL_RADIUS_MIN + math.random() * (PORTAL_RADIUS_MAX - PORTAL_RADIUS_MIN)
		local angleRad = math.rad(angles[i])
		local spawnPos = Vector3.new(
			BASE_POSITION.X + math.cos(angleRad) * radius,
			GROUND_LEVEL,
			BASE_POSITION.Z + math.sin(angleRad) * radius
		)

		-- SpawnPoint part (used by EnemyAI/WaveManager to know where to spawn enemies)
		local spawnPoint = Instance.new("Part")
		spawnPoint.Name = "SpawnPoint_" .. routeId
		spawnPoint.Size = Vector3.new(4, 1, 4)
		spawnPoint.Position = Vector3.new(spawnPos.X, WAYPOINT_Y, spawnPos.Z)
		spawnPoint.Anchored = true
		spawnPoint.CanCollide = false
		spawnPoint.Transparency = 1
		spawnPoint.Color = ROUTE_COLORS[i]
		spawnPoint.Parent = Workspace

		-- Route folder with winding waypoints
		local routeFolder = Instance.new("Folder")
		routeFolder.Name = "Route_" .. routeId
		routeFolder.Parent = Workspace

		-- Only some routes get the deliberate "longer/overlapping" detour,
		-- and only when there's at least one other route to overlap with.
		local detourSide: number? = nil
		if routeCount > 1 and math.random() <= OVERLAP_ROUTE_CHANCE then
			detourSide = if math.random() < 0.5 then -1 else 1
		end

		local waypointCount = math.random(WAYPOINTS_PER_ROUTE_MIN, WAYPOINTS_PER_ROUTE_MAX)
		local waypoints = buildWaypoints(spawnPos, BASE_POSITION, waypointCount, detourSide)
		for idx, point in ipairs(waypoints) do
			createWaypointPart(point, idx, routeFolder, ROUTE_COLORS[i])
		end

		-- Visible Portal model at the spawn point
		spawnPortal(spawnPos, routeId)

		-- Lay a flat stone footpath following this route
		layRouteFootpath(waypoints, footpathFolder)

		-- Decorate alongside this route (trees + rocks, fully natural theme)
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
