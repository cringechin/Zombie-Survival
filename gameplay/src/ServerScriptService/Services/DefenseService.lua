local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZombieService = require(script.Parent.ZombieService)

local DefenseService = {}
DefenseService.Order = 20

local DEFENSES_FOLDER_NAME = "Defenses"
local LIGHTNING_TURRET_ID = "LightningTurret"
local HEALTH_PER_SEGMENT = 25
local MIN_HEALTH_SEGMENTS = 3
local MAX_HEALTH_SEGMENTS = 16

local defensesFolder = nil
local turretsByPlayer = {}
local turretRecordsByModel = {}

local function ensureDefensesFolder()
	if defensesFolder and defensesFolder.Parent then
		return defensesFolder
	end

	defensesFolder = Workspace:FindFirstChild(DEFENSES_FOLDER_NAME)
	if not defensesFolder then
		defensesFolder = Instance.new("Folder")
		defensesFolder.Name = DEFENSES_FOLDER_NAME
		defensesFolder.Parent = Workspace
	end

	return defensesFolder
end

local function getTurretConfig()
	return GameConfig.Defenses and GameConfig.Defenses.LightningTurret
end

local function getPlacementExclusions(player)
	local exclusions = {}

	local zombiesFolder = Workspace:FindFirstChild("Zombies")
	if zombiesFolder then
		table.insert(exclusions, zombiesFolder)
	end

	if player.Character then
		table.insert(exclusions, player.Character)
	end

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player and otherPlayer.Character then
			table.insert(exclusions, otherPlayer.Character)
		end
	end

	return exclusions
end

local function getGroundPosition(position, exclusions)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = exclusions

	local rayOrigin = position + Vector3.new(0, 55, 0)
	local rayResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -150, 0), raycastParams)
	return rayResult and rayResult.Position or nil, rayResult and rayResult.Instance or nil
end

local function canIgnoreGroundPart(groundPart)
	if not groundPart then
		return false
	end

	local defenses = ensureDefensesFolder()
	if groundPart:IsDescendantOf(defenses) then
		return false
	end

	return true
end

local function isGroundPartDefense(groundPart)
	if not groundPart then
		return false
	end

	return groundPart:IsDescendantOf(ensureDefensesFolder())
end

local function isPlacementFree(position, exclusions, ignoredPart)
	local filterList = table.clone(exclusions)
	if canIgnoreGroundPart(ignoredPart) then
		table.insert(filterList, ignoredPart)
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = filterList

	local boxSize = Vector3.new(4.2, 5.2, 4.2)
	local boxCFrame = CFrame.new(position + Vector3.new(0, 2.8, 0))
	local parts = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)

	for _, part in parts do
		if part.CanCollide and part.Transparency < 1 then
			return false
		end
	end

	return true
end

local function snapToGrid(position, gridSize)
	if gridSize <= 0 then
		return position
	end

	return Vector3.new(
		math.floor((position.X / gridSize) + 0.5) * gridSize,
		position.Y,
		math.floor((position.Z / gridSize) + 0.5) * gridSize
	)
end

local function clampPlacementDistance(origin, target, maxDistance)
	local flatDelta = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	if flatDelta.Magnitude <= maxDistance then
		return target
	end

	local clampedFlat = flatDelta.Unit * maxDistance
	return Vector3.new(origin.X + clampedFlat.X, target.Y, origin.Z + clampedFlat.Z)
end

local function findPlacementCFrame(player, requestedPosition, config)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local exclusions = getPlacementExclusions(player)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude <= 0.05 then
		forward = Vector3.new(0, 0, 1)
	else
		forward = forward.Unit
	end

	local placementTarget = requestedPosition
	if typeof(placementTarget) ~= "Vector3" then
		placementTarget = root.Position + (forward * config.SpawnOffset)
	end

	placementTarget = clampPlacementDistance(root.Position, placementTarget, config.MaxPlacementDistance)
	placementTarget = snapToGrid(placementTarget, config.GridSize)

	local rootDistance = (Vector3.new(placementTarget.X, 0, placementTarget.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	if rootDistance > config.MaxPlacementDistance then
		return nil
	end

	local groundPosition, groundPart = getGroundPosition(placementTarget, exclusions)
	if not groundPosition or isGroundPartDefense(groundPart) or not isPlacementFree(groundPosition, exclusions, groundPart) then
		return nil
	end

	local turretPosition = Vector3.new(placementTarget.X, groundPosition.Y + 2.1, placementTarget.Z)
	local lookAtPosition = Vector3.new(root.Position.X, turretPosition.Y, root.Position.Z)
	return CFrame.lookAt(turretPosition, lookAtPosition)
end

local function getTurretHealthColor(ratio)
	if ratio > 0.6 then
		return Color3.fromRGB(92, 233, 255)
	elseif ratio > 0.3 then
		return Color3.fromRGB(66, 154, 255)
	end

	return Color3.fromRGB(96, 115, 255)
end

local function createTurretHealthBar(model, humanoid)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end

	local maxHealth = math.max(humanoid.MaxHealth, 1)
	local segmentCount = math.clamp(math.ceil(maxHealth / HEALTH_PER_SEGMENT), MIN_HEALTH_SEGMENTS, MAX_HEALTH_SEGMENTS)
	local barWidth = math.clamp(28 + (segmentCount * 4), 40, 92)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 140
	billboard.Size = UDim2.fromOffset(barWidth, 4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.15, 0)
	billboard.Parent = head

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(13, 20, 35)
	background.BackgroundTransparency = 0.5
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(14, 26, 52)
	stroke.Thickness = 1.4
	stroke.Transparency = 0.18
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
		segment.BackgroundColor3 = Color3.fromRGB(23, 34, 58)
		segment.BackgroundTransparency = 0.38
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
		fill.BackgroundColor3 = Color3.fromRGB(92, 233, 255)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = segment

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		segments[index] = fill
	end

	local function update()
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		local fillColor = getTurretHealthColor(ratio)

		for index, fill in segments do
			local segmentStart = (index - 1) / segmentCount
			local segmentEnd = index / segmentCount
			local segmentRatio = math.clamp((ratio - segmentStart) / (segmentEnd - segmentStart), 0, 1)

			TweenService:Create(fill, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundColor3 = fillColor,
				Size = UDim2.fromScale(segmentRatio, 1),
			}):Play()
		end
	end

	humanoid.HealthChanged:Connect(update)
	update()
end

local function addTurretPart(model, name, size, color, material, cframe)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.Material = material or Enum.Material.Metal
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function createBoltSegment(fromPosition, toPosition, thickness, lifetime)
	local direction = toPosition - fromPosition
	local distance = direction.Magnitude
	if distance <= 0.05 then
		return
	end

	local segment = Instance.new("Part")
	segment.Name = "TurretLightning"
	segment.Anchored = true
	segment.CanCollide = false
	segment.CanTouch = false
	segment.CanQuery = false
	segment.CastShadow = false
	segment.Material = Enum.Material.Neon
	segment.Color = Color3.fromRGB(95, 210, 255)
	segment.Size = Vector3.new(thickness, thickness, distance)
	segment.CFrame = CFrame.new(fromPosition, toPosition) * CFrame.new(0, 0, -distance / 2)
	segment.Parent = Workspace

	TweenService:Create(segment, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()

	task.delay(lifetime, function()
		if segment.Parent then
			segment:Destroy()
		end
	end)
end

local function createLightningStrike(startPosition, endPosition)
	local direction = endPosition - startPosition
	local right = Vector3.new(-direction.Z, 0, direction.X)

	if right.Magnitude <= 0.05 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	local previous = startPosition
	local segments = 9

	for index = 1, segments do
		local alpha = index / segments
		local basePosition = startPosition:Lerp(endPosition, alpha)
		local jitter = if index == segments
			then Vector3.zero
			else (right * ((math.random() - 0.5) * 1.7)) + Vector3.new(0, (math.random() - 0.5) * 1.05, 0)
		local nextPosition = basePosition + jitter
		createBoltSegment(previous, nextPosition, 0.15, 0.12)
		previous = nextPosition
	end
end

local function createTurretSpawnBurst(position)
	local ring = Instance.new("Part")
	ring.Name = "TurretSpawnBurst"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(95, 210, 255)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 0.6, 0.6)
	ring.Transparency = 0.1
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Name = "TurretSpawnLight"
	light.Brightness = 2.1
	light.Color = Color3.fromRGB(95, 210, 255)
	light.Range = 18
	light.Parent = ring

	local tween = TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, 9, 9),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		if ring.Parent then
			ring:Destroy()
		end
	end)
end

local function pulseTurretHead(head)
	if not head or not head.Parent then
		return
	end

	local originalColor = head.Color
	TweenService:Create(head, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(190, 245, 255),
		Size = head.Size * 1.12,
	}):Play()

	task.delay(0.08, function()
		if head.Parent then
			TweenService:Create(head, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = originalColor,
				Size = Vector3.new(1.3, 0.6, 1.3),
			}):Play()
		end
	end)
end

local function getNearestZombie(position, range)
	local zombiesFolder = Workspace:FindFirstChild("Zombies")
	if not zombiesFolder then
		return nil
	end

	local nearest = nil
	local nearestDistance = math.huge

	for _, zombieModel in zombiesFolder:GetChildren() do
		if zombieModel:IsA("Model") then
			local candidate = ZombieService.getCandidateFromModel(zombieModel)
			if candidate then
				local distance = (candidate.Root.Position - position).Magnitude
				if distance <= range and distance < nearestDistance then
					nearestDistance = distance
					nearest = candidate
				end
			end
		end
	end

	return nearest
end

local function removeTurretFromOwner(player, model)
	local records = turretsByPlayer[player]
	if not records then
		return
	end

	for index = #records, 1, -1 do
		if records[index].Model == model then
			table.remove(records, index)
		end
	end

	if #records == 0 then
		turretsByPlayer[player] = nil
	end
end

local function destroyTurretRecord(record)
	if not record or record.Destroyed then
		return
	end

	record.Destroyed = true
	turretRecordsByModel[record.Model] = nil
	removeTurretFromOwner(record.Owner, record.Model)

	if record.Model and record.Model.Parent then
		record.Model:Destroy()
	end
end

local function runTurretLoop(record)
	local config = record.Config
	local model = record.Model
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local humanoid = record.Humanoid

	while model.Parent and root and humanoid.Health > 0 do
		local nearestZombie = getNearestZombie(root.Position, config.AttackRange)
		if nearestZombie then
			local startPosition = root.Position + Vector3.new(0, 2.05, 0)
			local endPosition = nearestZombie.Root.Position + Vector3.new(0, 1.4, 0)
			pulseTurretHead(record.Head)
			createLightningStrike(startPosition, endPosition)
			ZombieService.damageNpc(nearestZombie.NPC, record.Owner, config.Damage)
		end

		task.wait(config.FireCooldown)
	end

	destroyTurretRecord(record)
end

local function createLightningTurretModel(player, spawnCFrame, config)
	local model = Instance.new("Model")
	model.Name = LIGHTNING_TURRET_ID

	local root = addTurretPart(
		model,
		"HumanoidRootPart",
		Vector3.new(3, 2.2, 3),
		Color3.fromRGB(38, 71, 112),
		Enum.Material.Metal,
		spawnCFrame
	)
	model.PrimaryPart = root

	addTurretPart(
		model,
		"Base",
		Vector3.new(3.6, 0.9, 3.6),
		Color3.fromRGB(27, 47, 77),
		Enum.Material.Metal,
		spawnCFrame * CFrame.new(0, -1.55, 0)
	)
	addTurretPart(
		model,
		"Coil",
		Vector3.new(1.8, 2.2, 1.8),
		Color3.fromRGB(67, 132, 221),
		Enum.Material.Metal,
		spawnCFrame * CFrame.new(0, 0.9, 0)
	)
	local emitter = addTurretPart(
		model,
		"Head",
		Vector3.new(1.3, 0.6, 1.3),
		Color3.fromRGB(88, 202, 255),
		Enum.Material.Neon,
		spawnCFrame * CFrame.new(0, 2.1, 0)
	)
	emitter.CanCollide = false

	local glow = Instance.new("PointLight")
	glow.Name = "ChargeGlow"
	glow.Brightness = 1.2
	glow.Color = Color3.fromRGB(95, 210, 255)
	glow.Range = 14
	glow.Parent = emitter

	TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Brightness = 2.2,
		Range = 18,
	}):Play()

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = config.Health
	humanoid.Health = config.Health
	humanoid.WalkSpeed = 0
	humanoid.AutoJumpEnabled = false
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model:SetAttribute("DefenseType", LIGHTNING_TURRET_ID)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = ensureDefensesFolder()

	createTurretHealthBar(model, humanoid)

	local record = {
		Model = model,
		Humanoid = humanoid,
		Owner = player,
		Config = config,
		Head = emitter,
		Destroyed = false,
	}

	turretRecordsByModel[model] = record
	turretsByPlayer[player] = turretsByPlayer[player] or {}
	table.insert(turretsByPlayer[player], record)

	humanoid.Died:Connect(function()
		task.delay(1.8, function()
			destroyTurretRecord(record)
		end)
	end)
	model.Destroying:Connect(function()
		destroyTurretRecord(record)
	end)

	task.spawn(runTurretLoop, record)
	createTurretSpawnBurst(spawnCFrame.Position - Vector3.new(0, 2.05, 0))

	if config.LifeTime and config.LifeTime > 0 then
		task.delay(config.LifeTime, function()
			if model.Parent and humanoid.Health > 0 then
				destroyTurretRecord(record)
			end
		end)
	end
end

local function purchaseLightningTurret(player, requestedPosition)
	local config = getTurretConfig()
	if not config then
		return
	end

	local placement = findPlacementCFrame(player, requestedPosition, config)
	if not placement then
		return
	end

	local turretCost = PlayerDataService.getLightningTurretCost(player)
	if not PlayerDataService.spendCoins(player, turretCost) then
		return
	end

	PlayerDataService.incrementLightningTurretsPlaced(player)
	createLightningTurretModel(player, placement, config)
end

local function clearPlayerTurrets(player)
	local records = turretsByPlayer[player]
	if not records then
		return
	end

	for index = #records, 1, -1 do
		destroyTurretRecord(records[index])
	end

	turretsByPlayer[player] = nil
end

function DefenseService.start()
	ensureDefensesFolder()

	Network.gearPurchaseRequest.listen(function(data, player)
		if typeof(data) ~= "table" or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		if data.gear == LIGHTNING_TURRET_ID and typeof(data.position) == "Vector3" then
			purchaseLightningTurret(player, data.position)
		end
	end)

	Players.PlayerRemoving:Connect(clearPlayerTurrets)
end

return DefenseService
