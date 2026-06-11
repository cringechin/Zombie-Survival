local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ZombieNavigator = require(ServerScriptService.Classes.Navigation.ZombieNavigator)

local NPC = {}
NPC.__index = NPC

local ZOMBIE_COLLISION_GROUP = "Zombies"
local collisionGroupReady = false
local HEALTH_PER_SEGMENT = 25
local MIN_HEALTH_SEGMENTS = 3
local MAX_HEALTH_SEGMENTS = 16

local function setupCollisionGroup()
	if collisionGroupReady then
		return
	end

	pcall(function()
		PhysicsService:RegisterCollisionGroup(ZOMBIE_COLLISION_GROUP)
	end)

	PhysicsService:CollisionGroupSetCollidable(ZOMBIE_COLLISION_GROUP, ZOMBIE_COLLISION_GROUP, false)
	collisionGroupReady = true
end

local function getInstanceFromPath(path)
	local current = game

	for _, name in path do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return current
end

local function getAlivePlayers()
	local alivePlayers = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid and root and humanoid.Health > 0 then
			table.insert(alivePlayers, player)
		end
	end

	return alivePlayers
end

local function createFallbackModel(config, spawnCFrame)
	local appearance = config.Appearance or {}
	local skinColor = appearance.SkinColor or Color3.fromRGB(154, 210, 120)
	local shirtColor = appearance.ShirtColor or Color3.fromRGB(116, 78, 49)
	local pantsColor = appearance.PantsColor or Color3.fromRGB(93, 60, 38)
	local eyeColor = appearance.EyeColor or Color3.fromRGB(25, 35, 20)
	local model = Instance.new("Model")
	model.Name = config.Subclass

	local function part(name, size, color, offset)
		local bodyPart = Instance.new("Part")
		bodyPart.Name = name
		bodyPart.Size = size
		bodyPart.CFrame = spawnCFrame * CFrame.new(offset)
		bodyPart.Color = color
		bodyPart.Material = Enum.Material.SmoothPlastic
		bodyPart.TopSurface = Enum.SurfaceType.Smooth
		bodyPart.BottomSurface = Enum.SurfaceType.Smooth
		bodyPart.Parent = model

		return bodyPart
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.fromRGB(80, 80, 80), Vector3.new(0, 2, 0))
	root.Transparency = 1
	root.CanCollide = false

	local torso = part("Torso", Vector3.new(2, 2, 1), shirtColor, Vector3.new(0, 2, 0))
	local head = part("Head", Vector3.new(2, 1, 1), skinColor, Vector3.new(0, 3.5, 0))
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), skinColor, Vector3.new(-1.5, 2, 0))
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), skinColor, Vector3.new(1.5, 2, 0))
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), pantsColor, Vector3.new(-0.5, 0, 0))
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), pantsColor, Vector3.new(0.5, 0, 0))

	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Color3 = eyeColor
	face.Parent = head

	local function motor(name, part0, part1, c0, c1)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0 = part0
		joint.Part1 = part1
		joint.C0 = c0
		joint.C1 = c1
		joint.Parent = part0

		return joint
	end

	motor("RootJoint", root, torso, CFrame.new(0, 0, 0), CFrame.new(0, 0, 0))
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = config.DisplayName or config.Subclass
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model

	model.PrimaryPart = root

	return model
end

local function getGroundPosition(position, model)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { model, Workspace:WaitForChild("Zombies") }

	local origin = position + Vector3.new(0, 20, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -120, 0), raycastParams)

	return if result then result.Position else position
end

local function placeModelOnGround(model, groundPosition)
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - (boundingSize.Y / 2)
	local groundOffset = groundPosition.Y - bottomY + 0.05

	model:PivotTo(model:GetPivot() + Vector3.new(0, groundOffset, 0))
end

local function setSpawnCollisionState(model, root)
	local collisionStates = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			collisionStates[descendant] = descendant.CanCollide
			descendant.CanCollide = descendant == root
		end
	end

	return collisionStates
end

local function restoreCollisionState(collisionStates)
	for part, canCollide in collisionStates do
		if part.Parent then
			part.CanCollide = canCollide
		end
	end
end

local function setModelAnchored(model, anchored)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
		end
	end
end

local function prepareSpawnAnchoring(model, root)
	setModelAnchored(model, false)
	root.Anchored = true
end

local function setServerNetworkOwner(root)
	if root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

local function getHealthColor(ratio)
	if ratio > 0.6 then
		return Color3.fromRGB(127, 235, 76)
	elseif ratio > 0.3 then
		return Color3.fromRGB(255, 211, 66)
	end

	return Color3.fromRGB(255, 86, 86)
end

local function getDamageColor(damage, maxHealth)
	local ratio = damage / math.max(maxHealth, 1)

	if ratio >= 0.45 then
		return Color3.fromRGB(255, 69, 122)
	elseif ratio >= 0.25 then
		return Color3.fromRGB(255, 136, 45)
	elseif ratio >= 0.12 then
		return Color3.fromRGB(255, 226, 76)
	end

	return Color3.fromRGB(145, 224, 255)
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function unitOrZero(vector)
	if vector.Magnitude <= 0.001 then
		return Vector3.zero
	end

	return vector.Unit
end

local function setModelCollision(model, canCollide)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = canCollide
			descendant.CanTouch = false
		end
	end
end

local function getPivotForRootCFrame(model, root, rootCFrame)
	local rootToPivot = root.CFrame:ToObjectSpace(model:GetPivot())
	return rootCFrame * rootToPivot
end

local function getMovementRaycastParams(model)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { model, Workspace:WaitForChild("Zombies") }

	return raycastParams
end

function NPC.new(config)
	local self = setmetatable({}, NPC)

	self.Config = config
	self.Model = nil
	self.Humanoid = nil
	self.Root = nil
	self.Animator = nil
	self._alive = false
	self._canMove = false
	self._isAttacking = false
	self._lastAttackTime = 0
	self._facingAlign = nil
	self._navigator = nil
	self._surroundAngle = math.random() * math.pi * 2
	self._surroundRadius = config.SurroundRadius + (math.random(-10, 10) / 10)

	return self
end

function NPC:_getAssetTemplate()
	local template = getInstanceFromPath(self.Config.AssetPath)
	if template and template:IsA("Model") and #template:GetChildren() > 0 then
		return template
	end

	return nil
end

function NPC:_createModel(spawnCFrame)
	local template = self:_getAssetTemplate()
	local model = if template then template:Clone() else createFallbackModel(self.Config, spawnCFrame)

	model.Name = self.Config.Subclass

	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root then
		root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 2)
		root.Parent = model
	end

	model.PrimaryPart = root

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	model:PivotTo(spawnCFrame)

	local groundPosition = getGroundPosition(spawnCFrame.Position, model)
	placeModelOnGround(model, groundPosition)

	self.Model = model
	self.Humanoid = humanoid
	self.Root = root
	self.Animator = animator
end

function NPC:_createSpawnDirt(spawnCFrame)
	local groundPosition = getGroundPosition(spawnCFrame.Position, self.Model)

	local dirt = Instance.new("Part")
	dirt.Name = `{self.Config.Subclass}_SpawnDirt`
	dirt.Anchored = true
	dirt.CanCollide = false
	dirt.CanQuery = false
	dirt.CanTouch = false
	dirt.Color = Color3.fromRGB(99, 72, 45)
	dirt.Material = Enum.Material.Ground
	dirt.Shape = Enum.PartType.Cylinder
	dirt.Size = Vector3.new(0.1, 0.12, 0.1)
	dirt.Transparency = 0.12
	dirt.CFrame = CFrame.new(groundPosition + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
	dirt.Parent = Workspace

	local growTween = TweenService:Create(
		dirt,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.18, 7, 7) }
	)
	growTween:Play()

	task.delay(1.2, function()
		if not dirt.Parent then
			return
		end

		local fadeTween = TweenService:Create(
			dirt,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1, Size = Vector3.new(0.12, 8.5, 8.5) }
		)
		fadeTween:Play()
		fadeTween.Completed:Once(function()
			dirt:Destroy()
		end)
	end)
end

function NPC:_setupSmoothFacing()
	local attachment = Instance.new("Attachment")
	attachment.Name = "FacingAttachment"
	attachment.Parent = self.Root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "SmoothFacing"
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.Responsiveness = self.Config.FacingResponsiveness
	alignOrientation.MaxTorque = 50000
	alignOrientation.Parent = self.Root

	self._facingAlign = alignOrientation
end

function NPC:_facePosition(position)
	if not self._facingAlign or not self.Root then
		return
	end

	local rootPosition = self.Root.Position
	local flatTarget = Vector3.new(position.X, rootPosition.Y, position.Z)

	if (flatTarget - rootPosition).Magnitude < 0.05 then
		return
	end

	self._facingAlign.CFrame = CFrame.lookAt(rootPosition, flatTarget)
end

function NPC:_playSpawnAnimation()
	local animationId = self.Config.SpawnAnimationId
	if not animationId or animationId == "" then
		task.wait(self.Config.SpawnAnimationDuration or 0)
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local ok, track = pcall(function()
		return self.Animator:LoadAnimation(animation)
	end)

	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.1)
	end

	task.wait(self.Config.SpawnAnimationDuration or 0)

	if track then
		track:Stop(0)
	end

	animation:Destroy()
end

function NPC:_createHealthBar()
	local head = self.Model:FindFirstChild("Head")
	if not head then
		return
	end

	local maxHealth = math.max(self.Humanoid.MaxHealth, 1)
	local segmentCount = math.clamp(math.ceil(maxHealth / HEALTH_PER_SEGMENT), MIN_HEALTH_SEGMENTS, MAX_HEALTH_SEGMENTS)
	local barWidth = math.clamp(28 + (segmentCount * 4), 40, 92)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 140
	billboard.Size = UDim2.fromOffset(barWidth, 4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.35, 0)
	billboard.Parent = head

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	background.BackgroundTransparency = 0.55
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(8, 10, 14)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.28
	stroke.Parent = background

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(1, 0)
	backgroundCorner.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 1)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = background

	local segments = {}

	for index = 1, segmentCount do
		local segment = Instance.new("Frame")
		segment.Name = `Segment{index}`
		segment.BackgroundColor3 = Color3.fromRGB(42, 45, 53)
		segment.BackgroundTransparency = 0.42
		segment.BorderSizePixel = 0
		segment.LayoutOrder = index
		segment.ClipsDescendants = true
		segment.Size = UDim2.new(1 / segmentCount, -1, 1, 0)
		segment.Parent = background

		local segmentCorner = Instance.new("UICorner")
		segmentCorner.CornerRadius = UDim.new(1, 0)
		segmentCorner.Parent = segment

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Color3.fromRGB(127, 235, 76)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = segment

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		segments[index] = fill
	end

	local function update()
		local ratio = math.clamp(self.Humanoid.Health / self.Humanoid.MaxHealth, 0, 1)
		local fillColor = getHealthColor(ratio)

		for index, fill in segments do
			local segmentStart = (index - 1) / segmentCount
			local segmentEnd = index / segmentCount
			local segmentRatio = math.clamp((ratio - segmentStart) / (segmentEnd - segmentStart), 0, 1)

			TweenService:Create(fill, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundColor3 = fillColor,
				Size = UDim2.fromScale(segmentRatio, 1),
			}):Play()
		end

		TweenService:Create(
			billboard,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Size = UDim2.fromOffset(barWidth + 4, 6) }
		):Play()
	end

	self.Humanoid.HealthChanged:Connect(update)
	update()
end

function NPC:_showDamageNumber(damage)
	local head = self.Model and self.Model:FindFirstChild("Head")
	if not head or damage <= 0 then
		return
	end

	local roundedDamage = math.max(math.floor(damage + 0.5), 1)
	local damageRatio = damage / math.max(self.Humanoid.MaxHealth, 1)
	local textSize = math.clamp(16 + (damageRatio * 34), 18, 36)
	local popScale = math.clamp(1 + (damageRatio * 1.4), 1.15, 1.8)
	local rise = math.clamp(0.85 + (damageRatio * 1.6), 1, 2.3)
	local sideOffset = math.random(-18, 18) / 10

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 160
	billboard.Size = UDim2.fromOffset(72, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(sideOffset, 1.65, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = `{roundedDamage}`
	label.TextColor3 = getDamageColor(damage, self.Humanoid.MaxHealth)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(20, 16, 18)
	label.TextStrokeTransparency = 0.15
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 0.55
	scale.Parent = label

	TweenService
		:Create(scale, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = popScale })
		:Play()

	task.delay(0.13, function()
		if scale.Parent then
			TweenService
				:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
	end)

	TweenService:Create(
		billboard,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(sideOffset, 1.65 + rise, 0) }
	):Play()

	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.32),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	fadeTween:Play()
	fadeTween.Completed:Once(function()
		if billboard.Parent then
			billboard:Destroy()
		end
	end)
end

function NPC:_setupDamageNumbers()
	local previousHealth = self.Humanoid.Health

	self.Humanoid.HealthChanged:Connect(function(health)
		if health < previousHealth then
			self:_showDamageNumber(previousHealth - health)
		end

		previousHealth = health
	end)
end

function NPC:_getNearestTarget()
	local nearestPlayer = nil
	local nearestDistance = math.huge

	for _, player in getAlivePlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - self.Root.Position).Magnitude
			if distance <= self.Config.AggroRange and distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
			end
		end
	end

	return nearestPlayer, nearestDistance
end

function NPC:_tryAttack(targetPlayer, distance)
	if not self._canMove then
		return
	end

	if self._isAttacking then
		return
	end

	if distance > self.Config.AttackRange then
		return
	end

	if os.clock() - self._lastAttackTime < self.Config.AttackCooldown then
		return
	end

	local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid then
		return
	end

	self._lastAttackTime = os.clock()
	self._isAttacking = true

	task.delay(self.Config.AttackWindup, function()
		self._isAttacking = false

		if not self._alive or not self.Root or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
			return
		end

		local confirmedDistance = (targetRoot.Position - self.Root.Position).Magnitude
		if confirmedDistance <= self.Config.AttackRange then
			targetHumanoid:TakeDamage(self.Config.Damage)
		end
	end)
end

function NPC:_getSurroundPosition(targetRoot)
	local targetPosition = targetRoot.Position
	local offset = Vector3.new(
		math.cos(self._surroundAngle) * self._surroundRadius,
		0,
		math.sin(self._surroundAngle) * self._surroundRadius
	)

	local desiredPosition = targetPosition + offset
	local groundPosition = getGroundPosition(desiredPosition, self.Model)

	return Vector3.new(desiredPosition.X, groundPosition.Y, desiredPosition.Z)
end

function NPC:_getLightweightSeparation(allNpcs)
	local separation = Vector3.zero
	local rootPosition = self.Root.Position

	if not allNpcs then
		return separation
	end

	for _, npc in allNpcs do
		if npc ~= self and npc.Root and npc.Model and npc.Model.Parent then
			local away = flat(rootPosition - npc.Root.Position)
			local distance = away.Magnitude

			if distance > 0.05 and distance < GameConfig.ZombieSeparationDistance then
				separation += away.Unit * ((GameConfig.ZombieSeparationDistance - distance) / GameConfig.ZombieSeparationDistance)
			end
		end
	end

	return separation
end

function NPC:_steerLightweight(destination, deltaTime, allNpcs)
	local rootPosition = self.Root.Position
	local toDestination = flat(destination - rootPosition)
	local distance = toDestination.Magnitude

	if distance <= 0.05 then
		return
	end

	local desiredDirection = unitOrZero(toDestination)
	local separation = unitOrZero(self:_getLightweightSeparation(allNpcs)) * GameConfig.ZombieSeparationWeight
	local moveDirection = unitOrZero(desiredDirection + separation)

	if moveDirection == Vector3.zero then
		moveDirection = desiredDirection
	end

	local stepDistance = math.min(distance, self.Config.WalkSpeed * deltaTime)
	local movePosition = rootPosition + (moveDirection * stepDistance)
	local groundPosition = getGroundPosition(movePosition, self.Model)

	if math.abs(groundPosition.Y - rootPosition.Y) > GameConfig.ZombieMaxGroundStepHeight then
		if self._navigator then
			self._navigator:ForceRepath()
		end
		return
	end

	local stepVector = Vector3.new(groundPosition.X - rootPosition.X, 0, groundPosition.Z - rootPosition.Z)
	if stepVector.Magnitude > 0.05 then
		local result = Workspace:Raycast(
			rootPosition + Vector3.new(0, 2, 0),
			stepVector.Unit * math.min(stepVector.Magnitude + 1, self.Config.ObstacleFeelerDistance),
			getMovementRaycastParams(self.Model)
		)

		if result and result.Instance and result.Instance.CanCollide and result.Instance.Transparency < 1 then
			if self._navigator then
				self._navigator:ForceRepath()
			end
			return
		end
	end

	local nextPosition = Vector3.new(movePosition.X, groundPosition.Y, movePosition.Z)
	local lookAtPosition = Vector3.new(destination.X, nextPosition.Y, destination.Z)
	local rootCFrame

	if (lookAtPosition - nextPosition).Magnitude <= 0.05 then
		rootCFrame = CFrame.new(nextPosition)
	else
		rootCFrame = CFrame.lookAt(nextPosition, lookAtPosition)
	end

	self.Model:PivotTo(getPivotForRootCFrame(self.Model, self.Root, rootCFrame))
end

function NPC:_steer(destination, deltaTime, allNpcs)
	if GameConfig.LightweightZombieMovement then
		local movePosition = if self._navigator then self._navigator:GetMovePosition(destination) else destination
		self:_steerLightweight(movePosition, deltaTime, allNpcs)
		return
	end

	local movePosition = self._navigator:GetMovePosition(destination)

	self:_facePosition(movePosition)
	self.Humanoid:MoveTo(movePosition)
end

function NPC:_stepBrain(deltaTime, allNpcs)
	local targetPlayer, distance = self:_getNearestTarget()
	local targetRoot = targetPlayer
		and targetPlayer.Character
		and targetPlayer.Character:FindFirstChild("HumanoidRootPart")

	if targetRoot then
		self:_facePosition(targetRoot.Position)

		if self._canMove then
			local destination
			if GameConfig.LightweightZombieMovement then
				local targetPosition = getGroundPosition(targetRoot.Position, self.Model)
				local offset = Vector3.new(
					math.cos(self._surroundAngle) * self._surroundRadius,
					0,
					math.sin(self._surroundAngle) * self._surroundRadius
				)
				destination = getGroundPosition(
					Vector3.new(targetPosition.X + offset.X, targetPosition.Y, targetPosition.Z + offset.Z),
					self.Model
				)
			else
				destination = self:_getSurroundPosition(targetRoot)
			end

			self:_steer(destination, deltaTime or self.Config.MovementTick, allNpcs)
		end

		self:_tryAttack(targetPlayer, distance)
	end
end

function NPC:_runBrain()
	task.spawn(function()
		while self._alive and self.Model and self.Model.Parent and self.Humanoid.Health > 0 do
			self:_stepBrain(self.Config.MovementTick)
			task.wait(self.Config.MovementTick)
		end
	end)
end

function NPC:StepLightweight(now, allNpcs)
	if not self._alive or not self._canMove or not self.Model or not self.Model.Parent or self.Humanoid.Health <= 0 then
		return
	end

	local lastStepAt = self._lastLightweightStepAt or now
	self._lastLightweightStepAt = now
	self:_stepBrain(math.min(now - lastStepAt, 0.1), allNpcs)
end

function NPC:Spawn(spawnCFrame, parent)
	self:_createModel(spawnCFrame)
	setupCollisionGroup()

	for _, descendant in self.Model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = ZOMBIE_COLLISION_GROUP
		end
	end

	local spawnCollisionStates = setSpawnCollisionState(self.Model, self.Root)
	prepareSpawnAnchoring(self.Model, self.Root)
	self.Humanoid.MaxHealth = self.Config.Health
	self.Humanoid.Health = self.Config.Health
	self.Humanoid.WalkSpeed = 0
	self.Humanoid.AutoJumpEnabled = false
	self.Humanoid.JumpHeight = 0
	self.Humanoid.JumpPower = 0
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self.Model:SetAttribute("Class", self.Config.Class)
	self.Model:SetAttribute("Subclass", self.Config.Subclass)
	self.Model:SetAttribute("Damage", self.Config.Damage)
	self.Model:SetAttribute("WalkSpeed", self.Config.WalkSpeed)
	self.Model:SetAttribute("Health", self.Humanoid.Health)
	self.Model:SetAttribute("MaxHealth", self.Humanoid.MaxHealth)
	self.Model.Parent = parent or Workspace
	setServerNetworkOwner(self.Root)

	self._alive = true
	self:_createHealthBar()
	self:_setupDamageNumbers()
	self:_setupSmoothFacing()
	self:_createSpawnDirt(spawnCFrame)

	task.spawn(function()
		self:_playSpawnAnimation()

		if self._alive and self.Humanoid then
			restoreCollisionState(spawnCollisionStates)
			setModelAnchored(self.Model, false)
			self.Humanoid.PlatformStand = false
			self.Humanoid.Sit = false
			self.Humanoid.WalkSpeed = self.Config.WalkSpeed
			self.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
			self._canMove = true
			self._navigator = ZombieNavigator.new(self, self.Config)
			self:_stepBrain()
			self:_runBrain()
		end
	end)

	return self.Model
end

function NPC:Destroy()
	self._alive = false

	if self.Root then
		self.Root.Anchored = false
	end

	if self.Model and self.Model.Parent then
		self.Model:Destroy()
	end
end

return NPC
