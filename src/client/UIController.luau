--!strict
local UIController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateMoney = RemoteEvents:WaitForChild("UpdateMoney") :: RemoteEvent
local UpdateWave = RemoteEvents:WaitForChild("UpdateWave") :: RemoteEvent
local UpdateBaseHP = RemoteEvents:WaitForChild("UpdateBaseHP") :: RemoteEvent
local RequestPlacement = RemoteEvents:WaitForChild("RequestPlacement") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import PlacementSystem to trigger placement from shop buttons
local PlacementSystem = require(script.Parent:WaitForChild("PlacementSystem") :: ModuleScript)

-- ══════════════════════════════════════════════════════
-- BUILD THE HUD
-- ══════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ── TOP BAR ──────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
topBar.BackgroundTransparency = 0.3
topBar.BorderSizePixel = 0
topBar.Parent = screenGui

-- Wave Label (top-left)
local waveLabel = Instance.new("TextLabel")
waveLabel.Name = "WaveLabel"
waveLabel.Size = UDim2.new(0, 200, 1, 0)
waveLabel.Position = UDim2.new(0, 15, 0, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.Text = "⚔ Wave: 0"
waveLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
waveLabel.TextSize = 22
waveLabel.Font = Enum.Font.GothamBold
waveLabel.TextXAlignment = Enum.TextXAlignment.Left
waveLabel.Parent = topBar

-- Base HP Bar (top-center)
local hpContainer = Instance.new("Frame")
hpContainer.Name = "HPContainer"
hpContainer.Size = UDim2.new(0, 300, 0, 24)
hpContainer.Position = UDim2.new(0.5, -150, 0.5, -12)
hpContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
hpContainer.BorderSizePixel = 0
hpContainer.Parent = topBar

local hpCorner = Instance.new("UICorner")
hpCorner.CornerRadius = UDim.new(0, 6)
hpCorner.Parent = hpContainer

local hpFill = Instance.new("Frame")
hpFill.Name = "HPFill"
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpContainer

local hpFillCorner = Instance.new("UICorner")
hpFillCorner.CornerRadius = UDim.new(0, 6)
hpFillCorner.Parent = hpFill

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Text = "Base HP: 100/100"
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.TextSize = 14
hpText.Font = Enum.Font.GothamBold
hpText.ZIndex = 2
hpText.Parent = hpContainer

-- Money Label (top-right)
local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Size = UDim2.new(0, 200, 1, 0)
moneyLabel.Position = UDim2.new(1, -215, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Text = "💰 $500"
moneyLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
moneyLabel.TextSize = 22
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.TextXAlignment = Enum.TextXAlignment.Right
moneyLabel.Parent = topBar

-- Status Label (below top bar)
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(0, 300, 0, 30)
statusLabel.Position = UDim2.new(0.5, -150, 0, 55)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Preparing..."
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextSize = 16
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Parent = screenGui

-- ── TOWER SHOP (Bottom) ──────────────────────────────
local shopFrame = Instance.new("Frame")
shopFrame.Name = "TowerShop"
shopFrame.Size = UDim2.new(0, 500, 0, 80)
shopFrame.Position = UDim2.new(0.5, -250, 1, -95)
shopFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
shopFrame.BackgroundTransparency = 0.3
shopFrame.BorderSizePixel = 0
shopFrame.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 10)
shopCorner.Parent = shopFrame

local shopLayout = Instance.new("UIListLayout")
shopLayout.FillDirection = Enum.FillDirection.Horizontal
shopLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
shopLayout.VerticalAlignment = Enum.VerticalAlignment.Center
shopLayout.Padding = UDim.new(0, 10)
shopLayout.Parent = shopFrame

-- Tower definitions for shop buttons
local TOWER_SHOP = {
	{name = "ArcherTower_Roblox", label = "Archer", cost = 50, color = Color3.fromRGB(180, 80, 60), key = "B"},
	{name = "MageTower_Roblox", label = "Mage", cost = 80, color = Color3.fromRGB(100, 60, 180), key = "N"},
	{name = "CannonTower_Roblox", label = "Cannon", cost = 120, color = Color3.fromRGB(80, 80, 80), key = "M"},
	{name = "LightNode_Roblox", label = "Light", cost = 30, color = Color3.fromRGB(255, 220, 60), key = "L"},
}

for _, towerInfo in ipairs(TOWER_SHOP) do
	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. towerInfo.name
	btn.Size = UDim2.new(0, 110, 0, 60)
	btn.BackgroundColor3 = towerInfo.color
	btn.Text = towerInfo.label .. "\n$" .. towerInfo.cost .. " [" .. towerInfo.key .. "]"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamBold
	btn.Parent = shopFrame
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn
	
	btn.MouseButton1Click:Connect(function()
		PlacementSystem.startPlacement(towerInfo.name)
	end)
end

-- ══════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ══════════════════════════════════════════════════════

UpdateMoney.OnClientEvent:Connect(function(amount)
	moneyLabel.Text = "💰 $" .. tostring(amount)
end)

UpdateWave.OnClientEvent:Connect(function(waveNum, waveStatus)
	waveLabel.Text = "⚔ Wave: " .. tostring(waveNum)
	
	if waveStatus == "Active" then
		statusLabel.Text = "🔥 Wave " .. waveNum .. " in progress!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 120, 80)
	elseif waveStatus == "Intermission" then
		statusLabel.Text = "⏳ Intermission — Place your towers!"
		statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	elseif waveStatus == "Victory" then
		statusLabel.Text = "🏆 VICTORY! All waves cleared!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	elseif waveStatus == "GameOver" then
		statusLabel.Text = "💀 GAME OVER — Base destroyed!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	end
end)

UpdateBaseHP.OnClientEvent:Connect(function(currentHP, maxHP)
	local ratio = currentHP / maxHP
	hpFill.Size = UDim2.new(ratio, 0, 1, 0)
	hpText.Text = "Base HP: " .. tostring(currentHP) .. "/" .. tostring(maxHP)
	
	-- Color shift: green → yellow → red
	if ratio > 0.5 then
		hpFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	elseif ratio > 0.25 then
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	else
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end
end)

return UIController
