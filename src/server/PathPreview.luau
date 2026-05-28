--!strict
local PathPreview = {}

local Workspace = game:GetService("Workspace")

type PathLine = {
	parts: {Part}
}

local activePreviewParts: {Part} = {}

-- Draw a line (thin Part) between two points
local function createLinePart(from: Vector3, to: Vector3, color: Color3): Part
	local distance = (to - from).Magnitude
	local line = Instance.new("Part")
	line.Name = "PathLine"
	line.Anchored = true
	line.CanCollide = false
	line.Size = Vector3.new(0.8, 0.3, distance)
	line.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	line.Color = color
	line.Material = Enum.Material.Neon
	line.Transparency = 0.3
	line.Parent = Workspace
	return line
end

-- Clear all existing path previews
function PathPreview.clearAll()
	for _, part in ipairs(activePreviewParts) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	activePreviewParts = {}
end

-- Show path preview for a given list of route IDs
function PathPreview.showRoutes(routeIds: {string})
	PathPreview.clearAll()
	
	for _, routeId in ipairs(routeIds) do
		local routeFolder = Workspace:FindFirstChild("Route_" .. routeId)
		if not routeFolder then continue end
		
		-- Get spawn point color for this route
		local spawnPoint = Workspace:FindFirstChild("SpawnPoint_" .. routeId)
		local color = if spawnPoint and spawnPoint:IsA("BasePart") then spawnPoint.Color else Color3.fromRGB(255, 200, 0)
		
		-- Collect and sort waypoints
		local nodes = routeFolder:GetChildren()
		table.sort(nodes, function(a, b)
			return tonumber(a.Name) < tonumber(b.Name)
		end)
		
		-- Draw lines between consecutive waypoints
		for i = 1, #nodes - 1 do
			local nodeA = nodes[i]
			local nodeB = nodes[i + 1]
			if nodeA:IsA("BasePart") and nodeB:IsA("BasePart") then
				local line = createLinePart(nodeA.Position, nodeB.Position, color)
				table.insert(activePreviewParts, line)
			end
		end
	end
end

-- Fade out and remove previews over time
function PathPreview.fadeOut(duration: number)
	task.spawn(function()
		local steps = 20
		local interval = duration / steps
		for step = 1, steps do
			local alpha = step / steps
			for _, part in ipairs(activePreviewParts) do
				if part and part.Parent then
					part.Transparency = 0.3 + (0.7 * alpha)
				end
			end
			task.wait(interval)
		end
		PathPreview.clearAll()
	end)
end

return PathPreview
