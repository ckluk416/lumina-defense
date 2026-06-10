--!strict
local LightingController = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateDayNight = RemoteEvents:WaitForChild("UpdateDayNight") :: RemoteEvent

export type TimeOfDay = "Day" | "Night"
local currentPhase: TimeOfDay = "Day"
local isTransitioning = false

-- Day profile settings
local DAY_PROFILE = {
	ClockTime = 14,
	Ambient = Color3.fromRGB(150, 150, 150),
	OutdoorAmbient = Color3.fromRGB(120, 120, 120),
	Brightness = 2.5,
}

-- Night profile settings
local NIGHT_PROFILE = {
	ClockTime = 22,
	Ambient = Color3.fromRGB(15, 15, 30),
	OutdoorAmbient = Color3.fromRGB(10, 10, 20),
	Brightness = 0.3,
}

local function lerpColor(c1: Color3, c2: Color3, alpha: number): Color3
	return Color3.new(
		c1.R + (c2.R - c1.R) * alpha,
		c1.G + (c2.G - c1.G) * alpha,
		c1.B + (c2.B - c1.B) * alpha
	)
end

-- Initialize lighting settings for the game
local function init()
	Lighting.ClockTime = DAY_PROFILE.ClockTime
	Lighting.Ambient = DAY_PROFILE.Ambient
	Lighting.OutdoorAmbient = DAY_PROFILE.OutdoorAmbient
	Lighting.Brightness = DAY_PROFILE.Brightness
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	
	-- Create an Atmosphere object for misty sci-fi vibe if not present
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmos = Instance.new("Atmosphere")
		atmos.Density = 0.2
		atmos.Color = Color3.fromRGB(180, 200, 220)
		atmos.Decay = Color3.fromRGB(90, 100, 110)
		atmos.Glare = 0.1
		atmos.Haze = 0.5
		atmos.Parent = Lighting
	end
end

init()

-- Set phase ("Day" or "Night") and transition smoothly
function LightingController.setPhase(targetPhase: TimeOfDay, duration: number)
	if currentPhase == targetPhase then return end
	currentPhase = targetPhase
	isTransitioning = true
	
	local startClockTime = Lighting.ClockTime
	local startAmbient = Lighting.Ambient
	local startOutdoorAmbient = Lighting.OutdoorAmbient
	local startBrightness = Lighting.Brightness
	
	local targetProfile = if targetPhase == "Day" then DAY_PROFILE else NIGHT_PROFILE
	local targetClockTime = targetProfile.ClockTime
	
	-- Handle clock time wrap-around logic if necessary (day is 14, night is 22 - direct lerp works fine)
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		
		Lighting.ClockTime = startClockTime + (targetClockTime - startClockTime) * alpha
		Lighting.Ambient = lerpColor(startAmbient, targetProfile.Ambient, alpha)
		Lighting.OutdoorAmbient = lerpColor(startOutdoorAmbient, targetProfile.OutdoorAmbient, alpha)
		Lighting.Brightness = startBrightness + (targetProfile.Brightness - startBrightness) * alpha
		
		if alpha >= 1 then
			connection:Disconnect()
			isTransitioning = false
			UpdateDayNight:FireAllClients(currentPhase)
			print("[LightingController] Transition complete. Phase is now: " .. currentPhase)
		end
	end)
end

function LightingController.getCurrentPhase(): TimeOfDay
	return currentPhase
end

return LightingController

