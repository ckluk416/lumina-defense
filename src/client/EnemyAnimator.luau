--!strict
-- Procedural enemy walk animation, run CLIENT-SIDE.
-- We tried driving Motor6D.Transform from the SERVER (in EnemyAI), but
-- verified visually via screenshots that the pose never changed on the
-- client despite the server-side values updating correctly every frame --
-- Motor6D.Transform changes from the server were not reliably replicating.
-- Since this is purely cosmetic, each client instead computes its own
-- swing locally based on the enemy's replicated Position (which DOES
-- replicate correctly -- enemies visibly move across the map), so no
-- network replication of the animation itself is required at all.

local RunService = game:GetService("RunService")
local Workspace   = game:GetService("Workspace")

local EnemyAnimator = {}

local WALK_SWING_AMPLITUDE_ARM = math.rad(35)
local WALK_SWING_AMPLITUDE_LEG = math.rad(25)
local WALK_CYCLE_SPEED         = 6

local ENEMY_NAMES = {
	BasicEnemy = true,
	StealthEnemy = true,
}

local animated: {[Model]: boolean} = {}

local function animate(enemyModel: Model)
	if animated[enemyModel] then return end
	animated[enemyModel] = true

	local humanoid = enemyModel:WaitForChild("Humanoid", 3) :: Humanoid?
	local torso = enemyModel:WaitForChild("Torso", 3) :: BasePart?
	local rootPart = enemyModel:WaitForChild("HumanoidRootPart", 3) :: BasePart?
	if not (humanoid and torso and rootPart) then
		animated[enemyModel] = nil
		return
	end

	-- The motors are created by the server (ensureR6Motors in EnemyAI) and
	-- replicate to the client as part of the model hierarchy; wait briefly
	-- in case this client sees the model slightly before the motors exist.
	local leftShoulder, rightShoulder, leftHip, rightHip
	for _ = 1, 30 do
		leftShoulder  = torso:FindFirstChild("Left Shoulder")  :: Motor6D?
		rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
		leftHip       = torso:FindFirstChild("Left Hip")  :: Motor6D?
		rightHip      = torso:FindFirstChild("Right Hip") :: Motor6D?
		if leftShoulder and rightShoulder and leftHip and rightHip then break end
		task.wait(0.1)
	end
	if not (leftShoulder and rightShoulder and leftHip and rightHip) then
		animated[enemyModel] = nil
		return
	end

	local phase = 0
	local lastPos = rootPart.Position

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not enemyModel.Parent or not rootPart.Parent then
			conn:Disconnect()
			animated[enemyModel] = nil
			return
		end

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
			leftHip.Transform  = CFrame.Angles(-swing * WALK_SWING_AMPLITUDE_LEG, 0, 0)
			rightHip.Transform = CFrame.Angles(swing * WALK_SWING_AMPLITUDE_LEG, 0, 0)
		else
			leftShoulder.Transform  = leftShoulder.Transform:Lerp(CFrame.new(), 0.2)
			rightShoulder.Transform = rightShoulder.Transform:Lerp(CFrame.new(), 0.2)
			leftHip.Transform  = leftHip.Transform:Lerp(CFrame.new(), 0.2)
			rightHip.Transform = rightHip.Transform:Lerp(CFrame.new(), 0.2)
		end
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") and ENEMY_NAMES[child.Name] then
		task.spawn(animate, child)
	end
end)

for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("Model") and ENEMY_NAMES[child.Name] then
		task.spawn(animate, child)
	end
end

return EnemyAnimator
