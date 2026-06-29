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
local UpdateWaveStats  = RemoteEvents:WaitForChild("UpdateWaveStats")  :: RemoteEvent
local RequestBuySlot   = RemoteEvents:WaitForChild("RequestBuySlot")   :: RemoteEvent
local UpdateExtraSlotInfo = RemoteEvents:WaitForChild("UpdateExtraSlotInfo") :: RemoteEvent
local UpdateMapState   = RemoteEvents:WaitForChild("UpdateMapState")   :: RemoteEvent
local RequestReturnToLobby = RemoteEvents:WaitForChild("RequestReturnToLobby") :: RemoteEvent

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PlacementSystem = require(script.Parent:WaitForChild("PlacementSystem") :: ModuleScript)

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui
screenGui.Enabled        = false -- hidden until the player enters the TD map; LobbyBuilder/Game toggles this via UpdateMapState

local topBar = Instance.new("Frame")
topBar.Size                  = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3      = Color3.fromRGB(15, 15, 25)
topBar.BackgroundTransparency = 0.3
topBar.BorderSizePixel        = 0
topBar.Parent                 = screenGui

local waveLabel = Instance.new("TextLabel")
waveLabel.Size               = UDim2.new(0, 260, 1, 0)
waveLabel.Position           = UDim2.new(0, 15, 0, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.Text               = "⚔ Hari 1 • Wave 0"
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
towerCountLabel.TextSize              = 17
towerCountLabel.Font                  = Enum.Font.GothamMedium
towerCountLabel.TextXAlignment        = Enum.TextXAlignment.Left
towerCountLabel.Parent                = screenGui

local statsLabel = Instance.new("TextLabel")
statsLabel.Size                  = UDim2.new(0, 420, 0, 20)
statsLabel.Position              = UDim2.new(0, 230, 0, 55)
statsLabel.BackgroundTransparency = 1
statsLabel.Text                  = "🗡️ 0  🌙 0  •  Sisa: 0/0"
statsLabel.TextColor3            = Color3.fromRGB(210, 210, 220)
statsLabel.TextSize              = 16
statsLabel.Font                  = Enum.Font.Gotham
statsLabel.TextXAlignment        = Enum.TextXAlignment.Left
statsLabel.Parent                = screenGui

local buySlotBtn = Instance.new("TextButton")
buySlotBtn.Name            = "BuySlotBtn"
buySlotBtn.Size            = UDim2.new(0, 150, 0, 36)
buySlotBtn.Position        = UDim2.new(0, 155, 0, 90)
buySlotBtn.BackgroundColor3= Color3.fromRGB(30, 90, 50)
buySlotBtn.Text            = "➕ Slot ($300)"
buySlotBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
buySlotBtn.TextSize        = 14
buySlotBtn.Font            = Enum.Font.GothamBold
buySlotBtn.Parent          = screenGui
Instance.new("UICorner", buySlotBtn).CornerRadius = UDim.new(0, 8)

buySlotBtn.MouseButton1Click:Connect(function()
	RequestBuySlot:FireServer()
end)

local removeModeBtn = Instance.new("TextButton")
removeModeBtn.Name            = "RemoveModeBtn"
removeModeBtn.Size            = UDim2.new(0, 130, 0, 36)
removeModeBtn.Position        = UDim2.new(0, 15, 0, 90)
removeModeBtn.BackgroundColor3= Color3.fromRGB(120, 30, 30)
removeModeBtn.Text            = "💰 Mode Jual"
removeModeBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
removeModeBtn.TextSize        = 14
removeModeBtn.Font            = Enum.Font.GothamBold
removeModeBtn.Parent          = screenGui
Instance.new("UICorner", removeModeBtn).CornerRadius = UDim.new(0, 8)

local removeModeActive = false

local upgradeModeBtn = Instance.new("TextButton")
upgradeModeBtn.Name            = "UpgradeModeBtn"
upgradeModeBtn.Size            = UDim2.new(0, 150, 0, 36)
upgradeModeBtn.Position        = UDim2.new(0, 315, 0, 90)
upgradeModeBtn.BackgroundColor3= Color3.fromRGB(120, 95, 20)
upgradeModeBtn.Text            = "⬆ Mode Upgrade"
upgradeModeBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
upgradeModeBtn.TextSize        = 14
upgradeModeBtn.Font            = Enum.Font.GothamBold
upgradeModeBtn.Parent          = screenGui
Instance.new("UICorner", upgradeModeBtn).CornerRadius = UDim.new(0, 8)

local upgradeModeActive = false

removeModeBtn.MouseButton1Click:Connect(function()
	removeModeActive = not removeModeActive
	if removeModeActive then upgradeModeActive = false; upgradeModeBtn.Text = "⬆ Mode Upgrade"; upgradeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 95, 20) end
	PlacementSystem.setRemoveModeEnabled(removeModeActive)
	if removeModeActive then
		removeModeBtn.Text = "❌ Batal Jual"
		removeModeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		statusLabel.Text = "💰 Klik tower untuk menjual (refund 50%)"
	else
		removeModeBtn.Text = "💰 Mode Jual"
		removeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
	end
end)

upgradeModeBtn.MouseButton1Click:Connect(function()
	upgradeModeActive = not upgradeModeActive
	if upgradeModeActive then removeModeActive = false; removeModeBtn.Text = "💰 Mode Jual"; removeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20) end
	PlacementSystem.setUpgradeModeEnabled(upgradeModeActive)
	if upgradeModeActive then
		upgradeModeBtn.Text = "❌ Batal Upgrade"
		upgradeModeBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
		statusLabel.Text = "⬆ Klik tower untuk upgrade (damage/range naik, biaya bertambah per level)"
	else
		upgradeModeBtn.Text = "⬆ Mode Upgrade"
		upgradeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 95, 20)
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
	{name = "Mortar_Roblox",       label = "Mortar",  cost = 220, color = Color3.fromRGB(80, 80, 80),   key = "M"},
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

local returnToLobbyBtn = Instance.new("TextButton")
returnToLobbyBtn.Name            = "ReturnToLobbyBtn"
returnToLobbyBtn.Size            = UDim2.new(0, 240, 0, 56)
returnToLobbyBtn.Position        = UDim2.new(0.5, -120, 0.5, 40)
returnToLobbyBtn.BackgroundColor3= Color3.fromRGB(60, 90, 200)
returnToLobbyBtn.Text            = "🏠 Kembali ke Lobby"
returnToLobbyBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
returnToLobbyBtn.TextSize        = 20
returnToLobbyBtn.Font            = Enum.Font.GothamBold
returnToLobbyBtn.Visible         = false
returnToLobbyBtn.ZIndex          = 10
returnToLobbyBtn.Parent          = screenGui
Instance.new("UICorner", returnToLobbyBtn).CornerRadius = UDim.new(0, 10)

returnToLobbyBtn.MouseButton1Click:Connect(function()
	returnToLobbyBtn.Visible = false
	RequestReturnToLobby:FireServer()
end)

local earlyTallyBtn = Instance.new("TextButton")
earlyTallyBtn.Name            = "EarlyTallyBtn"
earlyTallyBtn.Size            = UDim2.new(0, 160, 0, 36)
earlyTallyBtn.Position        = UDim2.new(1, -175, 0, 130)
earlyTallyBtn.BackgroundColor3= Color3.fromRGB(180, 120, 30)
earlyTallyBtn.Text            = "🏳 Early Tally"
earlyTallyBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
earlyTallyBtn.TextSize        = 14
earlyTallyBtn.Font            = Enum.Font.GothamBold
earlyTallyBtn.Visible         = false
earlyTallyBtn.ZIndex          = 10
earlyTallyBtn.Parent          = screenGui
Instance.new("UICorner", earlyTallyBtn).CornerRadius = UDim.new(0, 8)

earlyTallyBtn.MouseButton1Click:Connect(function()
	earlyTallyBtn.Visible = false
	RequestReturnToLobby:FireServer()
end)

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

local function setShopVisible(visible: boolean)
	local tw = TweenService:Create(shopFrame, TweenInfo.new(0.25), {BackgroundTransparency = if visible then 0.3 else 1})
	tw:Play()
	for _, btn in ipairs(shopButtons) do
		btn.Visible = visible
	end
	removeModeBtn.Visible = visible
	upgradeModeBtn.Visible = visible
	buySlotBtn.Visible = visible
end

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

UpdateExtraSlotInfo.OnClientEvent:Connect(function(maxTowers: number, nextCost: number)
	buySlotBtn.Text = "➕ Slot ($" .. nextCost .. ")"
end)

UpdateWaveStats.OnClientEvent:Connect(function(day: number, wave: number, basicKills: number, stealthKills: number, remaining: number, total: number)
	waveLabel.Text = "⚔ Hari " .. day .. " • Wave " .. wave
	statsLabel.Text = "🗡️ " .. basicKills .. "  🌙 " .. stealthKills .. "  •  Sisa: " .. remaining .. "/" .. total
end)

UpdateWave.OnClientEvent:Connect(function(waveNum, waveStatus)
	if waveStatus == "Active" then
		statusLabel.Text      = "🔥 Wave " .. waveNum .. " in progress! (toko ditutup sampai intermission)"
		statusLabel.TextColor3 = Color3.fromRGB(255, 120, 80)
		setShopEnabled(false)
		setShopVisible(false)
		startBattleBtn.Visible = false
		earlyTallyBtn.Visible = true
		stopPulse()
		if removeModeActive then
			removeModeActive = false
			removeModeBtn.Text = "💰 Mode Jual"
			removeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
			PlacementSystem.setRemoveModeEnabled(false)
		end
		if upgradeModeActive then
			upgradeModeActive = false
			upgradeModeBtn.Text = "⬆ Mode Upgrade"
			upgradeModeBtn.BackgroundColor3 = Color3.fromRGB(120, 95, 20)
			PlacementSystem.setUpgradeModeEnabled(false)
		end

	elseif waveStatus == "Intermission" then
		statusLabel.Text       = "⏳ Intermission — Pasang tower, lalu MULAI!"
		statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		setShopEnabled(true)
		setShopVisible(true)
		earlyTallyBtn.Visible = true

	elseif waveStatus == "GameOver" then
		statusLabel.Text      = "💀 GAME OVER — Base hancur!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		setShopEnabled(false)
		setShopVisible(false)
		startBattleBtn.Visible = false
		earlyTallyBtn.Visible = false
		returnToLobbyBtn.Visible = true
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
		returnToLobbyBtn.Visible = false
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

UpdateMapState.OnClientEvent:Connect(function(inMap: boolean)
	screenGui.Enabled = inMap
end)

return UIController
