--!strict
local UIController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateMoneyEvent = RemoteEvents:WaitForChild("UpdateMoney") :: RemoteEvent

-- A basic function to update the money display in UI
function UIController.updateMoneyDisplay(newAmount: number)
	-- Example of updating a TextLabel, assuming we have a HUD ScreenGui
	local hud = PlayerGui:FindFirstChild("HUD")
	if hud then
		local moneyLabel = hud:FindFirstChild("MoneyLabel", true) :: TextLabel?
		if moneyLabel then
			moneyLabel.Text = "$ " .. tostring(newAmount)
		end
	end
end

-- Listen for server money updates
UpdateMoneyEvent.OnClientEvent:Connect(function(newAmount: number)
	UIController.updateMoneyDisplay(newAmount)
end)

return UIController
