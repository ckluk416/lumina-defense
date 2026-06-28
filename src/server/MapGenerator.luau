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

-- ===== Natural Decoration (model-based) =====
-- Trees, rocks, and trunks cloned from pre-made models in
-- ReplicatedStorage.Assets. Item type and density vary with
-- radial distance from the base (center): small items near
-- combat, full forest near the mountain walls.

-- Helper: clone a model from Assets, position it so its lowest
-- point sits at GROUND_LEVEL, random Y rotation, optional scale.
local function placeModel(template: Instance, position: Vector3, parent: Instance, scale: number?)
	local clone = template:Clone()
	clone.Parent = parent

	local rotY = math.random(0, 359)
	clone:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(rotY), 0))

	if scale and scale ~= 1 then
		if clone:IsA("Model") then
			clone:ScaleTo(scale)
		else
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Size = Vector3.new(part.Size.X * scale, part.Size.Y * scale, part.Size.Z * scale)
				end
			end
		end
	end

	-- Snap lowest point to GROUND_LEVEL so models sit on terrain
	local lowestY = math.huge
	if clone:IsA("BasePart") then
		lowestY = math.min(lowestY, clone.Position.Y - clone.Size.Y / 2)
	end
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			local bottom = part.Position.Y - part.Size.Y / 2
			if bottom < lowestY then lowestY = bottom end
		end
	end
	if lowestY ~= math.huge and lowestY ~= GROUND_LEVEL then
		local pivot = clone:GetPivot()
		clone:PivotTo(pivot + Vector3.new(0, GROUND_LEVEL - lowestY, 0))
	end

	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
	end
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
end

local function randomFrom(folderName: string): Instance?
	local folder = Assets:FindFirstChild(folderName)
	if not folder then return nil end
	local children = folder:GetChildren()
	if #children == 0 then return nil end
	return children[math.random(1, #children)]
end

local function createTree(position: Vector3, parent: Instance, sizeMult: number?)
	local template = randomFrom("TreeModels")
	if template then
		local baseScale = 0.8 + math.random() * 0.4
		placeModel(template, position, parent, baseScale * (sizeMult or 1))
	end
end

local function createRockCluster(position: Vector3, parent: Instance, folderName: string, sizeMult: number?)
	local folder = Assets:FindFirstChild(folderName)
	if not folder then return end
	local templates = folder:GetChildren()
	if #templates == 0 then return end

	local count = 1 + math.random(0, 2)
	for _ = 1, count do
		local template = templates[math.random(1, #templates)]
		local jitter = Vector3.new(
			(math.random() * 2 - 1) * 3,
			0,
			(math.random() * 2 - 1) * 3
		)
		local baseScale = 0.6 + math.random() * 0.5
		placeModel(template, position + jitter, parent, baseScale * (sizeMult or 1))
	end
end

-- Decoration along each route segment. Item type is chosen by
-- radial distance from base centre: small items near combat,
-- full variety toward the outer map.
--
-- Exclusion rules (to stop models blocking combat areas):
--   BASE_EXCLUSION_RADIUS  : nothing within this radius of Base (0,0,0)
--   PORTAL_EXCLUSION_RADIUS: nothing within this radius of any portal/spawn
--   PATH_SIDE_MIN_OFFSET   : minimum lateral distance from the path centreline
--   MIN_ITEM_SPACING       : minimum distance between any two placed items
local BASE_EXCLUSION_RADIUS   = 28  -- studs; keeps Base platform clear
local PORTAL_EXCLUSION_RADIUS = 22  -- studs; keeps each portal entrance clear
local PATH_SIDE_MIN_OFFSET    = 14  -- studs from path centreline (footpath is 7 wide, so ~7.5 gap minimum)
local MIN_ITEM_SPACING        = 8   -- studs; prevents two items spawning on top of each other

-- Shared list of placed-item positions (reset each generate() call via decorationFolder reuse)
local placedItemPositions: {Vector3} = {}

local function isTooCloseToPlaced(pos: Vector3): boolean
	for _, p in ipairs(placedItemPositions) do
		local dx = pos.X - p.X
		local dz = pos.Z - p.Z
		if dx*dx + dz*dz < MIN_ITEM_SPACING * MIN_ITEM_SPACING then
			return true
		end
	end
	return false
end

local function isTooCloseToPortals(pos: Vector3, allWaypoints: {Vector3}): boolean
	-- The first waypoint of every route IS the portal/spawn position
	-- (passed in via the full allWaypoints list from generate())
	for _, wp in ipairs(allWaypoints) do
		local dx = pos.X - wp.X
		local dz = pos.Z - wp.Z
		if dx*dx + dz*dz < PORTAL_EXCLUSION_RADIUS * PORTAL_EXCLUSION_RADIUS then
			return true
		end
	end
	return false
end

local function tryPlaceDecoration(pos: Vector3, decorationFolder: Instance, distFromCenter: number, allWaypoints: {Vector3})
	local bx, bz = pos.X - BASE_POSITION.X, pos.Z - BASE_POSITION.Z
	if bx*bx + bz*bz < BASE_EXCLUSION_RADIUS * BASE_EXCLUSION_RADIUS then return end
	if isTooCloseToPortals(pos, allWaypoints) then return end
	if isTooCloseToPlaced(pos) then return end

	table.insert(placedItemPositions, pos)

	-- Smooth gradient from base to outer wall
	-- t = 0 near base edge (dist≈28), t = 1 near mountain wall (dist≈190)
	local t = math.max(0, math.min(1, (distFromCenter - 28) / 162))
	local sizeMult = 0.5 + t * 0.7

	if math.random() < t * 0.65 then
		createTree(pos, decorationFolder, sizeMult)
	else
		createRockCluster(pos, decorationFolder, "RockModels", sizeMult)
	end
end

local function decorateRoute(waypoints: {Vector3}, decorationFolder: Instance, allWaypoints: {Vector3})
	for i = 1, #waypoints - 1 do
		local fromPoint = waypoints[i]
		local toPoint = waypoints[i + 1]
		local segmentDir = (toPoint - fromPoint)
		if segmentDir.Magnitude < 0.01 then continue end

		local fwd = segmentDir.Unit
		local perp = Vector3.new(-fwd.Z, 0, fwd.X)

		for _, side in ipairs({-1, 1}) do
			local offsetDist = PATH_SIDE_MIN_OFFSET + math.random() * 30
			local t = math.random()
			local pos = fromPoint + fwd * (segmentDir.Magnitude * t) + perp * (offsetDist * side)
			pos = Vector3.new(pos.X, GROUND_LEVEL, pos.Z)

			local distFromCenter = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
			-- Density scales with distance from base: ~52% at dist=50 → ~90% at dist=150+
			local chance = 0.4 + distFromCenter / 240
			if math.random() <= math.min(0.9, chance) then
				tryPlaceDecoration(pos, decorationFolder, distFromCenter, allWaypoints)
			end
		end
		task.wait() -- yield once per route segment so this never blocks a full frame
	end
end

-- Fills the outer ring (between routes and mountain walls) with
-- dense forest so the map doesn't feel empty past the paths.
-- Density and item size increase as radius approaches the mountain walls.
local function decorateOuterArea(decorationFolder: Instance, allWaypoints: {Vector3})
	local OUTER_COUNT = 100
	local MIN_RADIUS = 60
	local MAX_RADIUS = 190
	local PATH_CLEARANCE = 14

	for i = 1, OUTER_COUNT do
		local angle = math.random() * 2 * math.pi
		-- Bias toward outer wall: ~70% of items end up at radius ≥ 125
		local radius = MIN_RADIUS + (MAX_RADIUS - MIN_RADIUS) * math.random() ^ 0.5
		local pos = Vector3.new(
			math.cos(angle) * radius,
			GROUND_LEVEL,
			math.sin(angle) * radius
		)

		local tooClose = false
		for _, wp in ipairs(allWaypoints) do
			local dx = pos.X - wp.X
			local dz = pos.Z - wp.Z
			if dx * dx + dz * dz < PATH_CLEARANCE * PATH_CLEARANCE then
				tooClose = true
				break
			end
		end

		local bx, bz = pos.X - BASE_POSITION.X, pos.Z - BASE_POSITION.Z
		local tooCloseToBase = bx*bx + bz*bz < BASE_EXCLUSION_RADIUS * BASE_EXCLUSION_RADIUS

		if not tooClose and not tooCloseToBase and not isTooCloseToPlaced(pos) then
			table.insert(placedItemPositions, pos)
			local outerT = (radius - MIN_RADIUS) / (MAX_RADIUS - MIN_RADIUS)
			local sizeMult = 0.7 + outerT * 0.6
			if math.random() < 0.25 + outerT * 0.50 then
				createTree(pos, decorationFolder, sizeMult)
			else
				createRockCluster(pos, decorationFolder, "RockModels", sizeMult)
			end

			-- Natural clustering: extra items near this position
			if math.random() < 0.3 + outerT * 0.3 then
				local count = math.random(1, 2)
				for _ = 1, count do
					local a = math.random() * 2 * math.pi
					local d = 8 + math.random() * 6
					local cp = pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
					if isTooCloseToPlaced(cp) then continue end
					if isTooCloseToPortals(cp, allWaypoints) then continue end
					table.insert(placedItemPositions, cp)
					if math.random() < 0.6 then
						createTree(cp, decorationFolder, sizeMult * (0.8 + math.random() * 0.4))
					else
						createRockCluster(cp, decorationFolder, "RockModels", sizeMult * 0.8)
					end
				end
			end
		end
		if i % 8 == 0 then task.wait() end
	end
end

-- ===== Mountain Wall Ring =====
-- Three concentric rings forming a mountain range that encloses the
-- playable area. Heights use sine-wave + jitter for a natural skyline.
local MOUNTAIN_RINGS = {
	{
		radius = 205,
		heightMin = 20, heightMax = 35,
		segWidth = 12, segThickness = 8,
		colors = {
			Color3.fromRGB(110, 102, 92),
			Color3.fromRGB(100, 92, 84),
		},
	},
	{
		radius = 222,
		heightMin = 35, heightMax = 55,
		segWidth = 14, segThickness = 10,
		colors = {
			Color3.fromRGB(90, 82, 74),
			Color3.fromRGB(78, 72, 66),
		},
	},
	{
		radius = 242,
		heightMin = 45, heightMax = 70,
		segWidth = 16, segThickness = 12,
		colors = {
			Color3.fromRGB(70, 64, 58),
			Color3.fromRGB(58, 52, 48),
		},
	},
}
local SNOW_CAP_COLOR = Color3.fromRGB(235, 235, 240)
local function buildMountainRing(mountainFolder: Instance)
	for _, ring in ipairs(MOUNTAIN_RINGS) do
		local circumference = 2 * math.pi * ring.radius
		local segmentCount = math.floor(circumference / ring.segWidth)
		local heightSpread = ring.heightMax - ring.heightMin
		for i = 1, segmentCount do
			local angle = (i / segmentCount) * 360
			local angleRad = math.rad(angle)
			local wave = math.sin(angleRad * 3 + i * 0.7) * 0.5 + 0.5
			local jitter = math.random() * 0.3
			local height = ring.heightMin + (wave * 0.7 + jitter * 0.3) * heightSpread
			local pos = Vector3.new(
				math.cos(angleRad) * ring.radius,
				GROUND_LEVEL,
				math.sin(angleRad) * ring.radius
			)
			local segment = Instance.new("Part")
			segment.Name = "MountainSeg"
			segment.Size = Vector3.new(ring.segWidth * 1.05, height, ring.segThickness)
			segment.CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, -angleRad, 0)
			segment.Anchored = true
			segment.CanCollide = true
			segment.Material = Enum.Material.Rock
			segment.Color = ring.colors[math.random(1, #ring.colors)]
			segment.Parent = mountainFolder
			if height >= ring.heightMax - (heightSpread * 0.2) then
				local cap = Instance.new("Part")
				cap.Name = "SnowCap"
				cap.Shape = Enum.PartType.Ball
				cap.Size = Vector3.new(3 + math.random() * 2, 2 + math.random() * 1.5, 3 + math.random() * 2)
				cap.CFrame = CFrame.new(pos + Vector3.new(0, height + 1, 0))
				cap.Anchored = true
				cap.CanCollide = false
				cap.Material = Enum.Material.Snow
				cap.Color = SNOW_CAP_COLOR
				cap.Parent = mountainFolder
			end
			if i % 40 == 0 then task.wait() end
		end
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

	local mountainFolder = Instance.new("Folder")
	mountainFolder.Name = "MapBoundary"
	mountainFolder.Parent = Workspace
	buildMountainRing(mountainFolder)

	local routeCount = pickWeightedRouteCount()
	local angles = pickSpreadAngles(routeCount, MIN_ANGLE_SEPARATION_DEG)
	local routeIds: {string} = {}
	local allWaypoints: {Vector3} = {}
	local routeWaypointsList: {{Vector3}} = {}

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
		for _, wp in ipairs(waypoints) do
			table.insert(allWaypoints, wp)
		end
		for idx, point in ipairs(waypoints) do
			createWaypointPart(point, idx, routeFolder, ROUTE_COLORS[i])
		end

		-- Visible Portal model at the spawn point
		spawnPortal(spawnPos, routeId)

		-- Lay a flat stone footpath following this route
		layRouteFootpath(waypoints, footpathFolder)

		table.insert(routeWaypointsList, waypoints)
	end

	-- Decoration (tree/rock/trunk model cloning) is the expensive part --
	-- each clone involves MeshParts with collision geometry from the Creator
	-- Store. Running ~50-100 of these synchronously in one frame is what
	-- caused the long "Preparing..." freeze on join. We return the route
	-- data immediately so WaveManager/EnvironmentSetup/LobbyBuilder can start
	-- right away, and let decoration trickle in over the next second or two
	-- in the background (task.wait() yields inside decorateRoute/
	-- decorateOuterArea already spread this across many frames).
	task.spawn(function()
		-- Reset placed-item tracker each generation
		placedItemPositions = {}
		for _, waypoints in ipairs(routeWaypointsList) do
			decorateRoute(waypoints, decorationFolder, allWaypoints)
		end
		decorateOuterArea(decorationFolder, allWaypoints)
	end)

	generatedRouteIds = routeIds
	print("[MapGenerator] Generated " .. routeCount .. " route(s): " .. table.concat(routeIds, ", "))

	return routeIds
end

function MapGenerator.getGeneratedRouteIds(): {string}
	return generatedRouteIds
end

return MapGenerator
