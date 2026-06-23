--!strict
-- VisualEffects: handles purely cosmetic orbital-ring rotation for
-- Base (Core_OrbitalRing_0..2) and LightNode (Orb_EnergyRing_0..2).
-- No gameplay logic lives here; safe to run independently on the server
-- so the effect is consistent for every connected client.

local VisualEffects = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type SpinTask = {
	part: BasePart,
	axis: Vector3,
	speedDegPerSec: number,
	centerCFrame: CFrame,
}

local spinTasks: {SpinTask} = {}

-- Registers a part to spin around its own center on a given local axis.
-- axis should be a unit Vector3 in the part's local space, e.g. Vector3.yAxis.
local function registerSpin(part: BasePart, axis: Vector3, speedDegPerSec: number)
	if not part or not part:IsA("BasePart") then return end
	table.insert(spinTasks, {
		part = part,
		axis = axis,
		speedDegPerSec = speedDegPerSec,
		centerCFrame = part.CFrame,
	})
end

-- Sets up the 3 gyroscopic rings on a Base model (Core_OrbitalRing_0..2),
-- each spinning on a different axis for a layered orbital look.
function VisualEffects.setupBaseRings(baseModel: Model)
	local ring0 = baseModel:FindFirstChild("Core_OrbitalRing_0")
	local ring1 = baseModel:FindFirstChild("Core_OrbitalRing_1")
	local ring2 = baseModel:FindFirstChild("Core_OrbitalRing_2")

	if ring0 and ring0:IsA("BasePart") then
		registerSpin(ring0, Vector3.yAxis, 18) -- flat ring: spins around Y
	end
	if ring1 and ring1:IsA("BasePart") then
		registerSpin(ring1, Vector3.xAxis, -24) -- vertical ring: spins around X
	end
	if ring2 and ring2:IsA("BasePart") then
		registerSpin(ring2, Vector3.zAxis, 24) -- vertical ring: spins around Z
	end
end

-- Sets up the 3 energy rings on a LightNode model (Orb_EnergyRing_0..2).
function VisualEffects.setupLightNodeRings(nodeModel: Model)
	local ring0 = nodeModel:FindFirstChild("Orb_EnergyRing_0")
	local ring1 = nodeModel:FindFirstChild("Orb_EnergyRing_1")
	local ring2 = nodeModel:FindFirstChild("Orb_EnergyRing_2")

	if ring0 and ring0:IsA("BasePart") then
		registerSpin(ring0, Vector3.yAxis, 30)
	end
	if ring1 and ring1:IsA("BasePart") then
		registerSpin(ring1, Vector3.xAxis, -36)
	end
	if ring2 and ring2:IsA("BasePart") then
		registerSpin(ring2, Vector3.zAxis, 36)
	end
end

-- Removes spin tasks belonging to parts that no longer exist (cleanup safety).
local function pruneDestroyed()
	for i = #spinTasks, 1, -1 do
		local task_ = spinTasks[i]
		if not task_.part or not task_.part.Parent then
			table.remove(spinTasks, i)
		end
	end
end

local elapsedTime = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsedTime += dt
	for _, task_ in ipairs(spinTasks) do
		if task_.part and task_.part.Parent then
			local angle = task_.speedDegPerSec * elapsedTime
			task_.part.CFrame = task_.centerCFrame * CFrame.fromAxisAngle(task_.axis, math.rad(angle))
		end
	end

	-- Occasionally prune destroyed parts (cheap, not every frame)
	if math.floor(elapsedTime) % 5 == 0 then
		pruneDestroyed()
	end
end)

-- Auto-detect: scan Workspace for any existing Base model and wire it up,
-- and watch for new LightNode_Roblox clones placed via PlacementHandler.
function VisualEffects.init()
	-- Base is placed manually in Workspace
	local existingBase = Workspace:FindFirstChild("Base")
	if existingBase and existingBase:IsA("Model") then
		VisualEffects.setupBaseRings(existingBase)
	end

	-- LightNodes are cloned dynamically at runtime by PlacementHandler.
	-- Watch Workspace for new descendants named "LightNode_Roblox".
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and descendant.Name == "LightNode_Roblox" then
			VisualEffects.setupLightNodeRings(descendant)
		end
	end)
end

VisualEffects.init()

return VisualEffects