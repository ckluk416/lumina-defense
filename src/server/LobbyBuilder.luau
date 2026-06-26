--!strict
-- Builds a small, minimalist lobby area far away from the tower-defense map
-- (so the two never overlap): a spawn platform, a how-to-play sign, a
-- leaderboard sign, light decoration, and a portal that teleports the
-- player into the actual game map.
local LobbyBuilder = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService") :: ModuleScript)

-- Far enough from the main map (whose perimeter wall sits at radius ~205)
-- that nothing overlaps.
local LOBBY_CENTER = Vector3.new(0, 0.5, 600)
local PLATFORM_RADIUS = 32
local GAME_SPAWN_POSITION = Vector3.new(8, 5, 12) -- just inside the main map, near Base

local function buildPlatform(folder: Instance)
	local platform = Instance.new("Part")
	platform.Name = "LobbyPlatform"
	platform.Shape = Enum.PartType.Cylinder
	platform.Size = Vector3.new(2, PLATFORM_RADIUS * 2, PLATFORM_RADIUS * 2)
	platform.CFrame = CFrame.new(LOBBY_CENTER) * CFrame.Angles(0, 0, math.rad(90))
	platform.Anchored = true
	platform.Material = Enum.Material.SmoothPlastic
	platform.Color = Color3.fromRGB(235, 235, 240)
	platform.Parent = folder

	-- Thin colored ring accent, minimalist style
	local ring = Instance.new("Part")
	ring.Name = "LobbyPlatformRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, PLATFORM_RADIUS * 2 + 2, PLATFORM_RADIUS * 2 + 2)
	ring.CFrame = CFrame.new(LOBBY_CENTER + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 170, 255)
	ring.Parent = folder
end

local function buildSpawn(folder: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = LOBBY_CENTER + Vector3.new(0, 1.5, 18)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(200, 210, 225)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
end

local function buildSign(folder: Instance, position: Vector3, title: string, body: string, accentColor: Color3): SurfaceGui
	local post = Instance.new("Part")
	post.Name = "SignPost"
	post.Size = Vector3.new(0.6, 6, 0.6)
	post.Position = position + Vector3.new(0, 3, 0)
	post.Anchored = true
	post.Material = Enum.Material.Metal
	post.Color = Color3.fromRGB(90, 90, 95)
	post.Parent = folder

	local board = Instance.new("Part")
	board.Name = "SignBoard"
	board.Size = Vector3.new(10, 6, 0.4)
	board.Position = position + Vector3.new(0, 7, 0)
	board.Anchored = true
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(250, 250, 252)
	board.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 60)
	titleLabel.BackgroundColor3 = accentColor
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 28
	titleLabel.Parent = gui

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, -20, 1, -70)
	bodyLabel.Position = UDim2.new(0, 10, 0, 65)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Text = body
	bodyLabel.TextColor3 = Color3.fromRGB(35, 35, 40)
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 20
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Parent = gui

	return gui
end

local function buildHowToPlay(folder: Instance)
	local body = table.concat({
		"Tujuan: bertahan dari gelombang musuh tanpa biarkan mereka",
		"mencapai Base.",
		"",
		"• Pasang tower: klik tombol toko atau tombol [B][N][L][M]",
		"• Hapus tower: tombol Mode Hapus, lalu klik tower-nya",
		"• Klik kanan / Esc: batal pasang tower",
		"• Setiap 3 wave = 1 hari. Akhir hari = malam, musuh siluman",
		"  muncul -- pasang Light Node untuk mendeteksinya!",
		"• Slot tower terbatas, tapi bisa dibeli tambahan (makin mahal)",
	}, "\n")
	buildSign(folder, LOBBY_CENTER + Vector3.new(-20, 0, 0), "📖 CARA BERMAIN", body, Color3.fromRGB(60, 130, 200))
end

local function buildLeaderboard(folder: Instance)
	local gui = buildSign(folder, LOBBY_CENTER + Vector3.new(20, 0, 0), "🏆 LEADERBOARD", "Memuat...", Color3.fromRGB(200, 160, 50))
	local bodyLabel = gui:WaitForChild("Body") :: TextLabel

	local function refresh()
		local top = LeaderboardService.getTop(5)
		if #top == 0 then
			bodyLabel.Text = "Belum ada data\n(atau DataStore API tidak aktif di Studio)"
			return
		end
		local lines = {}
		for i, entry in ipairs(top) do
			table.insert(lines, i .. ". " .. entry.name .. " -- Wave " .. entry.wave)
		end
		bodyLabel.Text = table.concat(lines, "\n")
	end

	refresh()
	task.spawn(function()
		while true do
			task.wait(30)
			refresh()
		end
	end)
end

local DECOR_TREE_POSITIONS = {
	Vector3.new(-26, 0, 26), Vector3.new(26, 0, 26),
	Vector3.new(-26, 0, -10), Vector3.new(26, 0, -10),
}

local function buildDecoration(folder: Instance)
	-- Minimalist: just a handful of simple rock accents, no trees, to keep
	-- the lobby clean per the requested style.
	for _, offset in ipairs(DECOR_TREE_POSITIONS) do
		local rock = Instance.new("Part")
		rock.Name = "LobbyRock"
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.new(4, 3.2, 4)
		rock.Position = LOBBY_CENTER + offset + Vector3.new(0, 1.6, 0)
		rock.Anchored = true
		rock.CanCollide = true
		rock.Material = Enum.Material.Rock
		rock.Color = Color3.fromRGB(140, 132, 124)
		rock.Parent = folder
	end
end

local function buildPortal(folder: Instance)
	local template = Assets:FindFirstChild("SpawnPortal_Roblox") :: Model?
	local portalPos = LOBBY_CENTER + Vector3.new(0, 0, -20)

	if template then
		local portal = template:Clone()
		local sumX, sumZ, count, lowestY = 0, 0, 0, math.huge
		for _, p in ipairs(portal:GetDescendants()) do
			if p:IsA("BasePart") then
				sumX += p.Position.X; sumZ += p.Position.Z; count += 1
				lowestY = math.min(lowestY, p.Position.Y - p.Size.Y / 2)
			end
		end
		local center = Vector3.new(sumX / count, 0, sumZ / count)
		portal:TranslateBy(Vector3.new(portalPos.X - center.X, 0.5 - lowestY, portalPos.Z - center.Z))
		portal.Parent = folder
	end

	-- Invisible trigger zone in front of the portal (reliable Touched
	-- detection regardless of the portal model's exact geometry).
	local trigger = Instance.new("Part")
	trigger.Name = "PortalTrigger"
	trigger.Size = Vector3.new(10, 8, 4)
	trigger.Position = portalPos + Vector3.new(0, 4, 0)
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Parent = folder

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.new(0, 200, 0, 50)
	label.StudsOffset = Vector3.new(0, 6, 0)
	label.Adornee = trigger
	label.Parent = trigger
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "⚔ MASUK GAME"
	text.TextColor3 = Color3.fromRGB(255, 220, 100)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 22
	text.TextStrokeTransparency = 0
	text.Parent = label

	local debounce: {[Player]: boolean} = {}
	trigger.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or debounce[player] then return end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRootPart then return end

		debounce[player] = true
		humanoidRootPart.CFrame = CFrame.new(GAME_SPAWN_POSITION)
		task.delay(2, function() debounce[player] = nil end)
	end)
end

function LobbyBuilder.build()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = Workspace

	buildPlatform(folder)
	buildSpawn(folder)
	buildHowToPlay(folder)
	buildLeaderboard(folder)
	buildDecoration(folder)
	buildPortal(folder)

	-- Make this the default spawn for new players instead of the old
	-- Workspace.SpawnLocation sitting in the middle of the game map.
	local oldSpawn = Workspace:FindFirstChild("SpawnLocation")
	if oldSpawn then oldSpawn:Destroy() end

	print("[LobbyBuilder] Lobby built at " .. tostring(LOBBY_CENTER))
end

return LobbyBuilder
