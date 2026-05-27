--!strict
local LightingController = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

export type TimeOfDay = "Day" | "Night"
local currentPhase: TimeOfDay = "Day"

-- Shift time gradually
function LightingController.shiftTime(targetClockTime: number, duration: number)
	local startClockTime = Lighting.ClockTime
	local elapsed = 0
	
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		Lighting.ClockTime = startClockTime + (targetClockTime - startClockTime) * alpha
		
		if alpha >= 1 then
			connection:Disconnect()
			-- Update current phase based on ClockTime
			if Lighting.ClockTime >= 18 or Lighting.ClockTime <= 6 then
				currentPhase = "Night"
			else
				currentPhase = "Day"
			end
			print("Time shifted to " .. currentPhase)
		end
	end)
end

function LightingController.getCurrentPhase(): TimeOfDay
	return currentPhase
end

return LightingController
