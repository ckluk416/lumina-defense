--!strict
local EnemyAI = {}

local RunService = game:GetService("RunService")

-- Simplified function to move an enemy model along a series of waypoints
function EnemyAI.moveAlongWaypoints(enemy: Model, waypoints: {Vector3})
	task.spawn(function()
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		for _, waypoint in ipairs(waypoints) do
			humanoid:MoveTo(waypoint)
			-- Wait until the enemy reaches the waypoint or a timeout occurs
			humanoid.MoveToFinished:Wait()
		end
		
		-- Logic for when enemy reaches the end (Base)
		print("Enemy reached the base!")
	end)
end

return EnemyAI
