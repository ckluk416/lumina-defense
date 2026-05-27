--!strict
local WaveManager = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

export type WaveStatus = "Intermission" | "Active" | "Completed" | "GameOver"

local currentWave = 1
local maxWaves = 10
local status: WaveStatus = "Intermission"

function WaveManager.startWave()
	if status == "Intermission" then
		status = "Active"
		print("Wave " .. currentWave .. " started!")
		-- Logic to spawn enemies will go here
	end
end

function WaveManager.endWave()
	if status == "Active" then
		status = "Intermission"
		print("Wave " .. currentWave .. " completed!")
		currentWave += 1
		if currentWave > maxWaves then
			status = "Completed"
			print("Victory!")
		end
	end
end

return WaveManager
