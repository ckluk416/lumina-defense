--!strict
local UIController = {}

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateMoney      = RemoteEvents:WaitForChild("UpdateMoney")      :: RemoteEvent
local UpdateWave       = RemoteEvents:WaitForChild("UpdateWave")       :: RemoteEvent
local UpdateBaseHP     = RemoteEvents:WaitForChild("UpdateBaseHP")     :: RemoteEvent
local UpdateDayNight   = RemoteEvents:WaitForChild("UpdateDayNight")   :: RemoteEvent
local UpdateTowerCount = RemoteEvents:WaitForChild("UpdateTowerCount") :: RemoteEvent
local RequestStartWave = RemoteEvents:WaitForChild("RequestStartWave") :: RemoteEvent

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PlacementSystem = require(script.Parent:WaitForChild("PlacementSystem") :: ModuleScript)

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

local topBar = Instance.new("Frame")
topBar.Size                  = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3      = Color3.fromRGB(15, 15, 25)
topBar.BackgroundTransparency = 0.3
topBar.BorderSizePixel        = 0
topBar.Parent                 = screenGui

local waveLabel = Instance.new("TextLabel")
waveLabel.Size               = UDim2.new(0, 200, 1, 0)
waveLabel.Position           = UDim2.new(0, 15, 0, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.Text               = "⚔ Wave: 0"
waveLabel.TextColor3         = Color3.fromRGB(255, 220, 100)
waveLabel.TextSize           = 22
waveLabel.Font               = Enum.Font.GothamBold
waveLabel.TextXAlignment     = Enum.TextXAlignment.Left
waveLabel.Parent             = topBar

local hpContainer = Instance.new("Frame")
hpContainer.Size                   = UDim2.new(0, 300, 0, 24)
hpContainer.Position               = UDim2.new(0.5, -150, 0.5, -12)
hpContainer.BackgroundColor3       = Color3.fromRGB(40, 40, 50)
hpContainer.BorderSizePixel        = 0
hpContainer.Parent                 = topBar
Instance.new("UICorner", hpContainer).CornerRadius = UDim.new(0, 6)

local hpFill = Instance.new("Frame")
hpFill.Size             = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
hpFill.BorderSizePixel  = 0
hpFill.Parent           = hpContainer
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)

local hpText = Instance.new("TextLabel")
hpText.Size                  = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Text                  = "Base HP: 100/100"
hpText.TextColor3            = Color3.fromRGB(255, 255, 255)
hpText.TextSize              = 14
hpText.Font                  = Enum.Font.GothamBold
hpText.ZIndex                = 2
hpText.Parent                = hpContainer

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Size               = UDim2.new(0, 200, 1, 0)
moneyLabel.Position           = UDim2.new(1, -215, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Text               = "💰 $500"
moneyLabel.TextColor3         = Color3.fromRGB(100, 255, 100)
moneyLabel.TextSize           = 22
moneyLabel.Font               = Enum.Font.GothamBold
moneyLabel.TextXAlignment     = Enum.TextXAlignment.Right
moneyLabel.Parent             = topBar

local timeIndicator = Instance.new("TextLabel")
timeIndicator.Size               = UDim2.new(0, 180, 1, 0)
timeIndicator.Position           = UDim2.new(0, 185, 0, 0)
timeIndicator.BackgroundTransparency = 1
timeIndicator.Text               = "☀️ Siang"
timeIndicator.TextColor3         = Color3.fromRGB(255, 200, 50)
timeIndicator.TextSize           = 18
timeIndicator.Font               = Enum.Font.GothamBold
timeIndicator.TextXAlignment     = Enum.TextXAlignment.Left
timeIndicator.Parent             = topBar

local statusLabel = Instance.new("TextLabel")
statusLabel.Size                  = UDim2.new(0, 400, 0, 30)
statusLabel.Position              = UDim2.new(0.5, -200, 0, 55)
statusLabel.BackgroundTransparency = 1
statusLabel.Text                  = "Preparing..."
statusLabel.TextColor3            = Color3.fromRGB(200, 200, 200)
statusLabel.TextSize              = 16
statusLabel.Font                  = Enum.Font.GothamMedium
statusLabel.Parent                = screenGui

local towerCountLabel = Instance.new("TextLabel")
towerCountLabel.Size                  = UDim2.new(0, 200, 0, 24)
towerCountLabel.Position              = UDim2.new(0, 15, 0, 55)
towerCountLabel.BackgroundTransparency = 1
towerCountLabel.Text                  = "🏰 Tower: 0/12"
towerCountLabel.TextColor3            = Color3.fromRGB(180, 220, 255)
towerCountLabel.TextSize              = 15
towerCountLabel.Font                  = Enum.Font.GothamMedium
towerCountLabel.TextXAlignment        = Enum.TextXAlignment.Left
towerCountLabel.Parent                = screenGui

local removeModeBtn = Instance.new("TextButton")
removeModeBtn.Name            = "RemoveModeBtn"
removeModeBtn.Size            = UDim2.new(0, 130, 0, 36)
removeModeBtn.Position        = UDim2.new(0, 15, 0, 90)
removeModeBtn.BackgroundColor3= Color3.fromRGB(120, 30, 30)
removeModeBtn.Text            = "🗑 Mode Hapus"
removeModeBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
removeModeBtn.TextSize        = 14
removeModeBtn.Font            = Enum.Font.GothamBold
removeModeBtn.Parent          = screenGui
Instance.new("UICorner", removeModeBtn).CornerRadius = UDim.new(0, 8)

local removeModeActive = false
removeModeBtn.MouseButton1Click:Connect(function()
	removeModeActive = not removeModeActive
	PlacementSystem.setRemoveModeEnabled(removeModeActive)
	if removeModeActive then
		removeModeBtn.Text = "❌ Batal Hapus"
		removeModeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		statusLabel.Text = "🗑 Klik tower untuk menghapus (refund 50%)"
	else
		removeModeBtn.Text = "🗑 Mode Hapus"
		removeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
	end
end)

local shopFrame = Instance.new("Frame")
shopFrame.Size                  = UDim2.new(0, 520, 0, 80)
shopFrame.Position              = UDim2.new(0.5, -260, 1, -95)
shopFrame.BackgroundColor3      = Color3.fromRGB(15, 15, 25)
shopFrame.BackgroundTransparency = 0.3
shopFrame.BorderSizePixel       = 0
shopFrame.Parent                = screenGui
Instance.new("UICorner", shopFrame).CornerRadius = UDim.new(0, 10)

local shopLayout = Instance.new("UIListLayout")
shopLayout.FillDirection         = Enum.FillDirection.Horizontal
shopLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Center
shopLayout.VerticalAlignment     = Enum.VerticalAlignment.Center
shopLayout.Padding               = UDim.new(0, 8)
shopLayout.Parent                = shopFrame

local TOWER_SHOP = {
	{name = "ArcherTower_Roblox",  label = "Archer",  cost = 50,  color = Color3.fromRGB(180, 80, 60),  key = "B"},
	{name = "Mortar_Roblox",       label = "Mortar",  cost = 150, color = Color3.fromRGB(80, 80, 80),   key = "M"},
	{name = "LightNode_Roblox",    label = "Light",   cost = 30,  color = Color3.fromRGB(255, 220, 60), key = "L"},
	{name = "MageTower_Roblox",    label = "Mage",    cost = 80,  color = Color3.fromRGB(100, 60, 180), key = "N"},
}

local shopButtons: {TextButton} = {}

for _, towerInfo in ipairs(TOWER_SHOP) do
	local btn = Instance.new("TextButton")
	btn.Name            = "Btn_" .. towerInfo.name
	btn.Size            = UDim2.new(0, 115, 0, 60)
	btn.BackgroundColor3= towerInfo.color
	btn.Text            = towerInfo.label .. "\n$" .. towerInfo.cost .. " [" .. towerInfo.key .. "]"
	btn.TextColor3      = Color3.fromRGB(255, 255, 255)
	btn.TextSize        = 13
	btn.Font            = Enum.Font.GothamBold
	btn.Parent          = shopFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseButton1Click:Connect(function()
		PlacementSystem.startPlacement(towerInfo.name)
	end)

	table.insert(shopButtons, btn)
end

local startBattleBtn = Instance.new("TextButton")
startBattleBtn.Name            = "StartBattleBtn"
startBattleBtn.Size            = UDim2.new(0, 220, 0, 52)
startBattleBtn.Position        = UDim2.new(0.5, -110, 1, -165)
startBattleBtn.BackgroundColor3= Color3.fromRGB(220, 60, 60)
startBattleBtn.Text            = "⚔ MULAI BATTLE!"
startBattleBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
startBattleBtn.TextSize        = 20
startBattleBtn.Font            = Enum.Font.GothamBold
startBattleBtn.Visible         = false
startBattleBtn.ZIndex          = 10
startBattleBtn.Parent          = screenGui
Instance.new("UICorner", startBattleBtn).CornerRadius = UDim.new(0, 10)

local pulseTween: Tween? = nil
local function startPulse()
	if pulseTween then pulseTween:Cancel() end
	pulseTween = TweenService:Create(
		startBattleBtn,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{BackgroundColor3 = Color3.fromRGB(255, 90, 90)}
	)
	pulseTween:Play()
end

local function stopPulse()
	if pulseTween then pulseTween:Cancel(); pulseTween = nil end
	startBattleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
end

startBattleBtn.MouseButton1Click:Connect(function()
	if not startBattleBtn.Visible then return end
	startBattleBtn.Visible = false
	stopPulse()
	PlacementSystem.cancelPlacement()
	RequestStartWave:FireServer()
end)

local function setShopEnabled(enabled: boolean)
	for _, btn in ipairs(shopButtons) do
		btn.Active             = enabled
		btn.BackgroundTransparency = if enabled then 0 else 0.5
	end
	PlacementSystem.setPlacingEnabled(enabled)
end

UpdateMoney.OnClientEvent:Connect(function(amount)
	moneyLabel.Text = "💰 $" .. tostring(amount)
end)

UpdateTowerCount.OnClientEvent:Connect(function(current, max)
	towerCountLabel.Text = "🏰 Tower: " .. current .. "/" .. max
	if current >= max then
		towerCountLabel.TextColor3 = Color3.fromRGB(255, 120, 80)
	else
		towerCountLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
	end
end)

UpdateWave.OnClientEvent:Connect(function(waveNum, waveStatus)
	waveLabel.Text = "⚔ Wave: " .. tostring(waveNum)

	if waveStatus == "Active" then
		statusLabel.Text      = "🔥 Wave " .. waveNum .. " in progress!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 120, 80)
		setShopEnabled(false)
		startBattleBtn.Visible = false
		stopPulse()

	elseif waveStatus == "Intermission" then
		statusLabel.Text       = "⏳ Intermission — Pasang tower, lalu MULAI!"
		statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		setShopEnabled(true)

	elseif waveStatus == "Victory" then
		statusLabel.Text      = "🏆 VICTORY! Semua wave selesai!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
		setShopEnabled(false)
		startBattleBtn.Visible = false

	elseif waveStatus == "GameOver" then
		statusLabel.Text      = "💀 GAME OVER — Base hancur!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		setShopEnabled(false)
		startBattleBtn.Visible = false
	end
end)

UpdateBaseHP.OnClientEvent:Connect(function(currentHP, maxHP)
	local ratio = currentHP / maxHP
	hpFill.Size = UDim2.new(ratio, 0, 1, 0)
	hpText.Text = "Base HP: " .. tostring(currentHP) .. "/" .. tostring(maxHP)
	if ratio > 0.5 then
		hpFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	elseif ratio > 0.25 then
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	else
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end
end)

UpdateDayNight.OnClientEvent:Connect(function(phase: string)
	if phase == "Day" then
		timeIndicator.Text      = "☀️ Siang"
		timeIndicator.TextColor3 = Color3.fromRGB(255, 200, 50)
	else
		timeIndicator.Text      = "🌙 Malam – Stealth aktif!"
		timeIndicator.TextColor3 = Color3.fromRGB(150, 100, 255)
	end
end)

RequestStartWave.OnClientEvent:Connect(function(signal: string, nextWave: number, hasStealth: boolean?)
	if signal == "ready" then
		startBattleBtn.Text    = "⚔ MULAI WAVE " .. tostring(nextWave) .. "!"
		startBattleBtn.Visible = true
		startPulse()
		setShopEnabled(true)

		if hasStealth then
			statusLabel.Text       = "🌙 Wave malam akan datang — musuh siluman muncul! Pasang Light Node."
			statusLabel.TextColor3 = Color3.fromRGB(150, 130, 255)
		else
			statusLabel.Text       = "🗺 Lihat jalur musuh → pasang tower → MULAI!"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 180)
		end
	end
end)

return UIController
