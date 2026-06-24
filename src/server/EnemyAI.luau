--!strict
local EnemyAI = {}

local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateMoney  = RemoteEvents:WaitForChild("UpdateMoney") :: RemoteEvent

export type EnemyData = {
	model:      Model,
	health:     number,
	maxHealth:  number,
	speed:      number,
	damage:     number,
	isStealth:  boolean,
	reward:     number,
	hpBar:      Frame?,
	connection: RBXScriptConnection?,
	walkConnection: RBXScriptConnection?,
	dying:      boolean,
}

local activeEnemies: {[Model]: EnemyData} = {}

function EnemyAI.getActiveEnemies()
	return activeEnemies
end

local function createHPBar(enemyModel: Model): Frame?
	local rootPart = enemyModel.PrimaryPart or enemyModel:FindFirstChildOfClass("BasePart")
	if not rootPart then return nil end

	local billboard = Instance.new("BillboardGui")
	billboard.Name        = "HPBar"
	billboard.Size        = UDim2.new(0, 80, 0, 10)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Adornee     = rootPart
	billboard.Parent      = enemyModel

	local bg = Instance.new("Frame")
	bg.Size              = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3  = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel   = 0
	bg.Parent            = billboard
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Name            = "Fill"
	fill.Size            = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3= Color3.fromRGB(0, 220, 60)
	fill.BorderSizePixel = 0
	fill.Parent          = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	return fill
end

local function updateHPBar(data: EnemyData)
	if data.hpBar then
		local ratio = math.clamp(data.health / data.maxHealth, 0, 1)
		data.hpBar.Size = UDim2.new(ratio, 0, 1, 0)
		data.hpBar.BackgroundColor3 =
			if ratio > 0.5 then Color3.fromRGB(0, 220, 60)
			elseif ratio > 0.25 then Color3.fromRGB(255, 200, 0)
			else Color3.fromRGB(255, 50, 50)
	end
end

local WALK_ANIM_ID    = "rbxassetid://180426354" -- official R6 walk animation (kept for reference, no longer used -- see startProceduralWalk below)
local DIE_ANIM_ID     = nil :: string? -- no animation; death uses a programmatic ragdoll-fall instead (see playDeathEffect)

-- R6 rig models built from individual unwelded parts (like our enemy models)
-- often ship with rigid WeldConstraints instead of Motor6Ds. WeldConstraints
-- cannot be animated at all -- they're a static, immovable joint -- which is
-- why animations were "playing" (IsPlaying=true) but produced zero visible
-- movement. This function replaces them with proper Motor6D joints using
-- the standard R6 part offsets, so animations can actually pose the limbs.
local R6_MOTOR_OFFSETS = {
	-- {motorName, part0Name, part1Name, C0, C1}
	{"Neck",      "Torso", "Head",      CFrame.new(0, 1, 0),     CFrame.new(0, -0.5, 0)},
	{"Left Shoulder", "Torso", "Left Arm",  CFrame.new(-1, 0.5, 0), CFrame.new(0, 0.5, 0)},
	{"Right Shoulder","Torso", "Right Arm", CFrame.new(1, 0.5, 0),  CFrame.new(0, 0.5, 0)},
	{"Left Hip",  "Torso", "Left Leg",  CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0)},
	{"Right Hip", "Torso", "Right Leg", CFrame.new(0.5, -1, 0),  CFrame.new(0, 1, 0)},
}

local function ensureR6Motors(enemyModel: Model)
	local torso = enemyModel:FindFirstChild("Torso")
	local rootPart = enemyModel:FindFirstChild("HumanoidRootPart")
	if not torso or not rootPart then return end

	-- Already rigged (avoid double-processing if this somehow runs twice)
	if torso:FindFirstChild("RootJoint") then return end

	-- Strip EVERY WeldConstraint in the model first. The original model welds
	-- HumanoidRootPart rigidly to Torso, Head, Eye, both Arms, and both Legs --
	-- removing only some of these (e.g. just the ones in R6_MOTOR_OFFSETS)
	-- left Head/Eye still rigidly glued to the root, fighting the new Neck
	-- motor. A clean slate avoids any such conflicts.
	for _, w in ipairs(enemyModel:GetDescendants()) do
		if w:IsA("WeldConstraint") then
			w:Destroy()
		end
	end

	-- Root joint: HumanoidRootPart <-> Torso (required for the Humanoid/Animator to drive anything)
	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name  = "RootJoint"
	rootJoint.Part0 = rootPart
	rootJoint.Part1 = torso
	rootJoint.Parent = torso

	for _, info in ipairs(R6_MOTOR_OFFSETS) do
		local motorName, part0Name, part1Name, c0, c1 = info[1], info[2], info[3], info[4], info[5]
		local part0 = enemyModel:FindFirstChild(part0Name)
		local part1 = enemyModel:FindFirstChild(part1Name)
		if part0 and part1 then
			local motor = Instance.new("Motor6D")
			motor.Name  = motorName
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0    = c0
			motor.C1    = c1
			motor.Parent = part0
		end
	end

	-- Eye is purely cosmetic (attached to Head in the source model); re-weld
	-- it to Head specifically (not the root) so it follows head rotation
	-- without needing its own Motor6D.
	local head = enemyModel:FindFirstChild("Head")
	local eye  = enemyModel:FindFirstChild("Eye")
	if head and eye then
		local eyeWeld = Instance.new("WeldConstraint")
		eyeWeld.Part0 = head
		eyeWeld.Part1 = eye
		eyeWeld.Parent = head
	end
end

-- PROCEDURAL WALK: the official R6 walk animation (180426354), when played
-- through our motors, rotates Left/Right Shoulder & Hip dominantly around
-- the Z-axis (side-to-side ab/adduction) instead of the X-axis (front-back
-- swing) -- verified live by sampling Motor.Transform:ToEulerAnglesXYZ()
-- during playback, which showed Z components up to ~70 deg vs near-zero X.
-- That's why limbs visibly swing sideways ("tangan kanan, kaki kiri")
-- instead of a normal forward gait. Rather than depend on that animation
-- asset's compatibility with this custom rig, we drive the 4 limb motors
-- directly every frame with a simple contralateral sine-wave gait, rotating
-- ONLY around local X (guaranteed correct front-back swing).
local WALK_SWING_AMPLITUDE_ARM = math.rad(35)
local WALK_SWING_AMPLITUDE_LEG = math.rad(25)
local WALK_CYCLE_SPEED         = 6 -- radians per stud moved, roughly matches a natural stride rate

local function startProceduralWalk(enemyModel: Model, humanoid: Humanoid): RBXScriptConnection?
	local torso = enemyModel:FindFirstChild("Torso")
	local rootPart = enemyModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not torso or not rootPart then return nil end

	local leftShoulder  = torso:FindFirstChild("Left Shoulder")  :: Motor6D?
	local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
	local leftHip        = torso:FindFirstChild("Left Hip")  :: Motor6D?
	local rightHip       = torso:FindFirstChild("Right Hip") :: Motor6D?
	if not (leftShoulder and rightShoulder and leftHip and rightHip) then return nil end

	-- NOTE: Humanoid.MoveDirection is driven by player input controllers and is
	-- NOT populated for NPCs moved via Humanoid:MoveTo() -- verified live, it
	-- stayed exactly 0 the whole time even while the enemy was visibly walking
	-- across the map. So instead of reading MoveDirection, we measure ACTUAL
	-- horizontal displacement per frame to detect real movement.
	local phase = 0
	local lastPos = rootPart.Position
	return RunService.Heartbeat:Connect(function(dt: number)
		if not enemyModel.Parent or not rootPart.Parent then return end
		local currentPos = rootPart.Position
		local horizontalDelta = Vector3.new(currentPos.X - lastPos.X, 0, currentPos.Z - lastPos.Z)
		local measuredSpeed = dt > 0 and (horizontalDelta.Magnitude / dt) or 0
		lastPos = currentPos

		local moveSpeed = measuredSpeed > 0.75 and humanoid.WalkSpeed or 0

		if moveSpeed > 0 then
			phase += dt * WALK_CYCLE_SPEED * (moveSpeed / 16)
			local swing = math.sin(phase)

			leftShoulder.Transform  = CFrame.Angles(swing * WALK_SWING_AMPLITUDE_ARM, 0, 0)
			rightShoulder.Transform = CFrame.Angles(-swing * WALK_SWING_AMPLITUDE_ARM, 0, 0)
			-- contralateral gait: left leg swings opposite to left arm
			leftHip.Transform  = CFrame.Angles(-swing * WALK_SWING_AMPLITUDE_LEG, 0, 0)
			rightHip.Transform = CFrame.Angles(swing * WALK_SWING_AMPLITUDE_LEG, 0, 0)
		else
			-- ease back to neutral standing pose when not moving
			leftShoulder.Transform  = leftShoulder.Transform:Lerp(CFrame.new(), 0.2)
			rightShoulder.Transform = rightShoulder.Transform:Lerp(CFrame.new(), 0.2)
			leftHip.Transform        = leftHip.Transform:Lerp(CFrame.new(), 0.2)
			rightHip.Transform       = rightHip.Transform:Lerp(CFrame.new(), 0.2)
		end
	end)
end

local function playAnimation(enemyModel: Model, animId: string, looped: boolean): AnimationTrack?
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
		or humanoid:FindFirstChildOfClass("AnimationController")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = humanoid
		animator = a
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	anim:Destroy()
	if not ok or not track then return nil end

	track.Looped = looped
	track:Play()
	return track :: AnimationTrack
end

-- Death: a simple "falls over and lies on the ground" effect, not a shrink-
-- in-place. We rotate the whole model 90 degrees onto its side around its
-- current position (a believable ragdoll-style collapse without needing a
-- physics ragdoll setup), hold briefly on the ground, then fade out.
local function playDeathEffect(enemyModel: Model, callback: () -> ())
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	local rootPart = enemyModel:FindFirstChild("HumanoidRootPart") :: BasePart?

	if humanoid then
		humanoid:UnequipTools()
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.PlatformStand = true -- let the model topple instead of staying humanoid-upright
	end

	-- Stop the walk animation track so the legs/arms freeze in place instead
	-- of continuing to cycle while the body falls over.
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.1)
		end
	end

	-- Stop the procedural walk loop so the legs/arms freeze in place instead
	-- of continuing to cycle while the body falls over.
	local data = activeEnemies[enemyModel]
	if data and data.walkConnection then
		data.walkConnection:Disconnect()
		data.walkConnection = nil
	end

	local FALL_DURATION = 0.4
	local LIE_DURATION   = 0.9
	local FADE_DURATION  = 0.5

	if rootPart then
		-- Fall to one side (random left/right) and drop slightly to rest on the ground
		local fallDirection = if math.random() < 0.5 then 1 else -1
		local fallCFrame = rootPart.CFrame
			* CFrame.Angles(0, 0, math.rad(90) * fallDirection)
			* CFrame.new(0, -1, 0)

		local fallTween = TweenService:Create(rootPart,
			TweenInfo.new(FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{CFrame = fallCFrame}
		)
		fallTween:Play()
	end

	-- After lying on the ground for a moment, fade everything out and destroy
	task.delay(FALL_DURATION + LIE_DURATION, function()
		local parts: {BasePart} = {}
		for _, d in ipairs(enemyModel:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(parts, d) end
		end
		for _, part in ipairs(parts) do
			local tw = TweenService:Create(part,
				TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Transparency = 1}
			)
			tw:Play()
		end

		task.delay(FADE_DURATION + 0.05, function()
			callback()
		end)
	end)
end

function EnemyAI.damageEnemy(enemyModel: Model, amount: number)
	local data = activeEnemies[enemyModel]
	if not data or data.dying then return end

	data.health -= amount
	updateHPBar(data)

	if data.health <= 0 then
		EnemyAI.killEnemy(enemyModel, true)
	end
end

function EnemyAI.killEnemy(enemyModel: Model, byPlayer: boolean?)
	local data = activeEnemies[enemyModel]
	if not data then return end
	if data.dying then return end
	data.dying = true

	if data.connection then
		data.connection:Disconnect()
	end

	activeEnemies[enemyModel] = nil

	if byPlayer then
		local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
		for _, p in ipairs(Players:GetPlayers()) do
			EconomyManager.addMoney(p, data.reward)
			UpdateMoney:FireClient(p, EconomyManager.getMoney(p))
		end
		print("[EnemyAI] Enemy killed! Each player earned $" .. data.reward)
	end

	playDeathEffect(enemyModel, function()
		if enemyModel and enemyModel.Parent then
			enemyModel:Destroy()
		end
	end)
end

function EnemyAI.cleanupEnemy(enemyModel: Model)
	local data = activeEnemies[enemyModel]
	if data and data.connection then data.connection:Disconnect() end
	if data and data.walkConnection then data.walkConnection:Disconnect() end
	activeEnemies[enemyModel] = nil
	if enemyModel and enemyModel.Parent then enemyModel:Destroy() end
end

function EnemyAI.setupEnemy(
	enemyModel: Model,
	maxHealth:  number,
	speed:      number,
	damage:     number,
	isStealth:  boolean?,
	reward:     number?
)
	local stealthValue = if isStealth ~= nil then isStealth else false
	local rewardValue  = if reward ~= nil then reward else 15

	-- Fix the rig BEFORE creating the HP bar / setting up data, so the
	-- Motor6Ds exist by the time the procedural walk loop attaches below.
	ensureR6Motors(enemyModel)

	local hpBarFill = createHPBar(enemyModel)

	activeEnemies[enemyModel] = {
		model     = enemyModel,
		health    = maxHealth,
		maxHealth = maxHealth,
		speed     = speed,
		damage    = damage,
		isStealth = stealthValue,
		reward    = rewardValue,
		hpBar     = hpBarFill,
		dying     = false,
	}

	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
		humanoid.MaxHealth = maxHealth
		humanoid.Health    = maxHealth

		local walkConn = startProceduralWalk(enemyModel, humanoid)
		if walkConn then
			(activeEnemies[enemyModel] :: EnemyData).walkConnection = walkConn
		end
	end
end

function EnemyAI.moveAlongWaypoints(enemyModel: Model, waypoints: {Vector3})
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	task.spawn(function()
		for _, waypoint in ipairs(waypoints) do
			if not enemyModel.Parent or not activeEnemies[enemyModel] then return end
			humanoid:MoveTo(waypoint)
			humanoid.MoveToFinished:Wait()
			if not enemyModel.Parent or not activeEnemies[enemyModel] then return end
		end

		local data = activeEnemies[enemyModel]
		if data then
			local WaveManager = require(script.Parent:WaitForChild("WaveManager"))
			WaveManager.damageBase(data.damage)
			print("[EnemyAI] " .. enemyModel.Name .. " reached base! Dealt " .. data.damage .. " damage.")
			EnemyAI.cleanupEnemy(enemyModel)
		end
	end)
end

return EnemyAI
