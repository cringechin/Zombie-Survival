local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WeaponGrantService = require(script.Parent.WeaponGrantService)
local ZombieService = require(script.Parent.ZombieService)

local DisasterWeaponService = {}
DisasterWeaponService.Order = 30

local lastCastTimesByUserId = {}
local METEOR_ASSET_PATH = { "Assets", "VFX", "Disasters", "Meteor", "Meteor" }
local METEOR_VFX_ROOT_PATH = { "Assets", "VFX", "Disasters", "Meteor" }
local TORNADO_VFX_ROOT_PATHS = {
	{ "Assets", "VFX", "Disasters", "Tornado" },
	{ "Assets", "Disasters", "Tornado" },
}
local TORNADO_ASSET_NAMES = { "TornadoVFX", "Tornado", "Tornado-01", "Tornado01" }
local LIGHTNING_BOLT_SOUND_ID = "rbxassetid://95495457829413"
local TORNADO_GROUND_RAY_HEIGHT = 6
local TORNADO_GROUND_RAY_DEPTH = 38
local TORNADO_MAX_GROUND_ABOVE = 2.5
local TORNADO_MAX_GROUND_BELOW = 14

local function isPlayerAlive(player)
	if player:GetAttribute("IsDowned") == true then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function getEquippedTool(player, weaponName)
	local character = player.Character
	if not character then
		return nil
	end

	local tool = character:FindFirstChild(weaponName)
	if tool and tool:IsA("Tool") then
		return tool
	end

	return nil
end

local function tweenAndDestroy(instance, tweenInfo, properties)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	tween.Completed:Once(function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function randomBetween(minValue, maxValue)
	return minValue + ((maxValue - minValue) * math.random())
end

local function unitOrZero(vector)
	if vector.Magnitude <= 0.001 then
		return Vector3.zero
	end

	return vector.Unit
end

local function createBoltSegment(fromPosition, toPosition, thickness, lifetime, color, transparency)
	local direction = toPosition - fromPosition
	local distance = direction.Magnitude
	if distance <= 0 then
		return
	end

	local part = Instance.new("Part")
	part.Name = "LightningBolt"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(115, 180, 225)
	part.Transparency = transparency or 0
	part.Size = Vector3.new(thickness, thickness, distance)
	part.CFrame = CFrame.new(fromPosition, toPosition) * CFrame.new(0, 0, -distance / 2)
	part.Parent = Workspace

	tweenAndDestroy(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(thickness * 0.2, thickness * 0.2, distance),
	})
end

local function createBoltGlowSegment(fromPosition, toPosition, coreThickness, lifetime, color)
	createBoltSegment(fromPosition, toPosition, coreThickness * 4.2, lifetime + 0.04, color, 0.64)
	createBoltSegment(
		fromPosition,
		toPosition,
		coreThickness * 1.7,
		lifetime + 0.02,
		Color3.fromRGB(104, 220, 255),
		0.14
	)
	createBoltSegment(fromPosition, toPosition, coreThickness, lifetime, Color3.fromRGB(245, 255, 255), 0)
end

local function createMuzzleFlash(position)
	local flash = Instance.new("Part")
	flash.Name = "LightningMuzzleFlash"
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(110, 185, 230)
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.55, 0.55, 0.55)
	flash.CFrame = CFrame.new(position)
	flash.Parent = Workspace

	tweenAndDestroy(flash, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(2.25, 2.25, 2.25),
	})

	local light = Instance.new("PointLight")
	light.Name = "LightningMuzzleLight"
	light.Brightness = 1.8
	light.Color = Color3.fromRGB(120, 185, 230)
	light.Range = 10
	light.Parent = flash
end

local function playLightningBoltSound(position, isChain)
	local anchor = Instance.new("Part")
	anchor.Name = "LightningBoltSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace

	local sound = Instance.new("Sound")
	local minPitch = if isChain then 1.06 else 0.86
	local maxPitch = if isChain then 1.22 else 1.12

	sound.Name = if isChain then "LightningChainSFX" else "LightningBoltSFX"
	sound.SoundId = LIGHTNING_BOLT_SOUND_ID
	sound.Volume = if isChain then 0.07 else 0.16
	sound.PlaybackSpeed = randomBetween(minPitch, maxPitch)
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = if isChain then 58 else 82
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, 4)
end

local function createLightningImpactPop(position, radius, color)
	local pop = Instance.new("Part")
	pop.Name = "LightningImpactPop"
	pop.Anchored = true
	pop.CanCollide = false
	pop.CanQuery = false
	pop.CanTouch = false
	pop.CastShadow = false
	pop.Material = Enum.Material.Neon
	pop.Color = color or Color3.fromRGB(110, 220, 255)
	pop.Shape = Enum.PartType.Ball
	pop.Size = Vector3.new(radius, radius, radius)
	pop.CFrame = CFrame.new(position)
	pop.Parent = Workspace

	tweenAndDestroy(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(radius * 3.2, radius * 3.2, radius * 3.2),
	})

	local sparkLight = Instance.new("PointLight")
	sparkLight.Name = "LightningImpactLight"
	sparkLight.Brightness = 2.6
	sparkLight.Color = Color3.fromRGB(105, 225, 255)
	sparkLight.Range = radius * 9
	sparkLight.Parent = pop
end

local function findChildCaseInsensitive(parent, childName)
	local directChild = parent:FindFirstChild(childName)
	if directChild then
		return directChild
	end

	local lowerName = string.lower(childName)
	for _, child in parent:GetChildren() do
		if string.lower(child.Name) == lowerName then
			return child
		end
	end

	return nil
end

local function getMeteorAsset()
	local current = ReplicatedStorage
	for _, childName in METEOR_ASSET_PATH do
		current = findChildCaseInsensitive(current, childName)
		if not current then
			return nil
		end
	end

	return current
end

local function getMeteorVFXRoot()
	local current = ReplicatedStorage
	for _, childName in METEOR_VFX_ROOT_PATH do
		current = findChildCaseInsensitive(current, childName)
		if not current then
			return nil
		end
	end

	return current
end

local function findAssetByNames(parent, names)
	if not parent then
		return nil
	end

	for _, name in names do
		local asset = findChildCaseInsensitive(parent, name)
		if asset then
			return asset
		end
	end

	return nil
end

local function getMeteorVFXAsset(assetType)
	local root = getMeteorVFXRoot()
	if not root then
		return nil
	end

	local candidateNames
	if assetType == "Explosion" then
		candidateNames = { "ExplosionVFX", "Explosion", "ExplotionVFX", "Explotion", "ImpactVFX", "Impact" }
	elseif assetType == "GroundFire" then
		candidateNames = { "GroundFireVFX", "GroundFire", "groundFireVFX", "groundFire", "FireVFX", "Fire" }
	else
		return nil
	end

	local directAsset = findAssetByNames(root, candidateNames)
	if directAsset then
		return directAsset
	end

	local nestedFolder = findChildCaseInsensitive(root, "MeteorVFX")
	if nestedFolder then
		return findAssetByNames(nestedFolder, candidateNames)
	end

	return nil
end

local function setupVFXAttachment(anchor, vfx)
	if vfx:IsA("ParticleEmitter") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "VFXAttachment"
		attachment.Parent = anchor
		vfx.Parent = attachment
	elseif vfx:IsA("Attachment") then
		vfx.Parent = anchor
	else
		vfx.Parent = anchor
	end
end

local function prepareVFXDescendants(
	vfxRoot,
	lifetime,
	emitDuration,
	emitScale,
	activeDuration,
	postDisableDuration,
	hideCarrierParts
)
	emitScale = emitScale or 1
	postDisableDuration = postDisableDuration or 0
	local emitters = {}
	local effectiveLifetime = lifetime

	for _, descendant in vfxRoot:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			if hideCarrierParts then
				descendant.Transparency = 1
			end
		elseif descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant)
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end

	local disableAfter = activeDuration or emitDuration
	if activeDuration and activeDuration > 0 then
		effectiveLifetime = math.max(effectiveLifetime, activeDuration + postDisableDuration)
	end

	for _, emitter in emitters do
		local burstCount = emitter:GetAttribute("EmitCount")
		if typeof(burstCount) ~= "number" then
			burstCount = emitter:GetAttribute("BurstCount")
		end

		local scaledBurstCount = 0
		if typeof(burstCount) == "number" and burstCount > 0 then
			scaledBurstCount = math.max(1, math.floor(burstCount * emitScale))
		else
			local inferredBurst = if emitter.Rate > 0 then emitter.Rate * math.max(emitDuration, 0.1) else 24
			scaledBurstCount = math.max(12, math.floor(inferredBurst * emitScale))
		end

		emitter:Emit(scaledBurstCount)
		if emitter.Rate > 0 or (activeDuration and activeDuration > 0) then
			emitter.Enabled = true
			task.delay(disableAfter, function()
				if emitter.Parent then
					emitter.Enabled = false
				end
			end)
		end
	end

	Debris:AddItem(vfxRoot, effectiveLifetime)
end

local function playMeteorNamedVFX(assetType, position, options)
	options = options or {}

	local lifetime = options.Lifetime or 1.8
	local emitDuration = options.EmitDuration or 0.35
	local scale = options.Scale or 1
	local emitScale = options.EmitScale or 1
	local activeDuration = options.ActiveDuration
	local postDisableDuration = options.PostDisableDuration or 0
	local hideCarrierParts = if options.HideCarrierParts == nil then true else options.HideCarrierParts

	local template = getMeteorVFXAsset(assetType)
	if not template then
		return false
	end

	local vfx = template:Clone()
	local anchor = nil

	if vfx:IsA("Model") then
		if scale ~= 1 then
			pcall(function()
				vfx:ScaleTo(scale)
			end)
		end
		vfx:PivotTo(CFrame.new(position))
		vfx.Parent = Workspace
	elseif vfx:IsA("BasePart") then
		if scale ~= 1 then
			vfx.Size *= scale
		end
		vfx.CFrame = CFrame.new(position)
		vfx.Parent = Workspace
	else
		anchor = Instance.new("Part")
		anchor.Name = `{assetType}VFXAnchor`
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(position)
		anchor.Parent = Workspace
		setupVFXAttachment(anchor, vfx)
		vfx = anchor
	end

	prepareVFXDescendants(vfx, lifetime, emitDuration, emitScale, activeDuration, postDisableDuration, hideCarrierParts)
	return true
end

local function prepareMeteorInstance(instance, scale)
	if instance:IsA("Model") then
		if scale and scale ~= 1 then
			pcall(function()
				instance:ScaleTo(scale)
			end)
		end

		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
	elseif instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
		instance.Size *= scale or 1
	end
end

local function createFallbackMeteor(scale)
	local meteor = Instance.new("Part")
	meteor.Name = "Meteor"
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.CanQuery = false
	meteor.CanTouch = false
	meteor.CastShadow = false
	meteor.Material = Enum.Material.Neon
	meteor.Color = Color3.fromRGB(255, 92, 28)
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(3.5, 3.5, 3.5) * (scale or 1)

	local light = Instance.new("PointLight")
	light.Name = "MeteorGlow"
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 111, 32)
	light.Range = 22
	light.Parent = meteor

	return meteor
end

local function createMeteorVisual(scale)
	local asset = getMeteorAsset()
	local meteor = asset and asset:Clone() or createFallbackMeteor(scale)
	meteor.Name = "MeteorProjectile"
	prepareMeteorInstance(meteor, scale or 1)
	meteor.Parent = Workspace
	return meteor
end

local function pivotMeteor(meteor, cframe)
	if meteor:IsA("Model") then
		meteor:PivotTo(cframe)
	else
		meteor.CFrame = cframe
	end
end

local function animateMeteor(meteor, fromPosition, toPosition, travelTime)
	local direction = toPosition - fromPosition
	local lookAt = if direction.Magnitude > 0.05
		then CFrame.lookAt(fromPosition, toPosition)
		else CFrame.new(fromPosition)
	local startTime = os.clock()
	local connection = nil

	pivotMeteor(meteor, lookAt)
	connection = RunService.Heartbeat:Connect(function()
		if not meteor.Parent then
			connection:Disconnect()
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / travelTime, 0, 1)
		local position = fromPosition:Lerp(toPosition, alpha)
		local remainingDirection = toPosition - position
		local cframe = if remainingDirection.Magnitude > 0.05
			then CFrame.lookAt(position, toPosition)
			else CFrame.new(position)
		pivotMeteor(meteor, cframe)

		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

local function createMeteorImpact(position, radius, meteorScale)
	local vfxScale = math.clamp((radius / 14) * (1 + ((meteorScale or 1) * 0.35)), 0.8, 3.2)
	local playedExplosionVFX = playMeteorNamedVFX("Explosion", position + Vector3.new(0, 0.1, 0), {
		Lifetime = 2,
		EmitDuration = 0.35,
		Scale = vfxScale,
		EmitScale = math.clamp(vfxScale * 1.2, 1, 4),
		HideCarrierParts = true,
	})
	if playedExplosionVFX then
		return
	end

	local shockwave = Instance.new("Part")
	shockwave.Name = "MeteorShockwave"
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.CanQuery = false
	shockwave.CanTouch = false
	shockwave.CastShadow = false
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 126, 38)
	shockwave.Shape = Enum.PartType.Ball
	shockwave.Size = Vector3.new(4, 4, 4)
	shockwave.CFrame = CFrame.new(position)
	shockwave.Parent = Workspace

	tweenAndDestroy(shockwave, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(radius * 2, radius * 0.32, radius * 2),
	})

	local light = Instance.new("PointLight")
	light.Name = "MeteorImpactLight"
	light.Brightness = 4
	light.Color = Color3.fromRGB(255, 128, 42)
	light.Range = radius * 1.8
	light.Parent = shockwave
end

local function createLightningBeamVFX(startPosition, endPosition, config, isChain)
	local direction = endPosition - startPosition
	local distance = direction.Magnitude
	if distance <= 0.1 then
		return
	end

	local forward = direction.Unit
	local right = forward:Cross(Vector3.yAxis)
	if right.Magnitude <= 0.05 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	local up = right:Cross(forward).Unit
	local segmentCount = math.max(4, math.floor((config.BoltSegments or 12) * (if isChain then 0.7 else 1)))
	local arcNoise = if isChain then 1.25 else 2.2
	local coreThickness = if isChain then 0.11 else 0.18
	local lifetime = if isChain then 0.12 else 0.16
	local stepDelay = if isChain then 0.004 else 0.007
	local boltColor = if isChain then Color3.fromRGB(120, 245, 255) else Color3.fromRGB(62, 202, 255)
	local boltPoints = { startPosition }

	for index = 1, segmentCount do
		local alpha = index / segmentCount
		local basePosition = startPosition:Lerp(endPosition, alpha)
		local taper = math.sin(alpha * math.pi)
		local jitter = (right * ((math.random() - 0.5) * arcNoise * taper))
			+ (up * ((math.random() - 0.5) * arcNoise * 0.8 * taper))
		local nextPosition = if index == segmentCount then endPosition else basePosition + jitter

		table.insert(boltPoints, nextPosition)
	end

	if not isChain then
		createMuzzleFlash(startPosition)
	end
	playLightningBoltSound(if isChain then startPosition:Lerp(endPosition, 0.5) else startPosition, isChain)

	for index = 1, #boltPoints - 1 do
		local fromPosition = boltPoints[index]
		local toPosition = boltPoints[index + 1]
		task.delay((index - 1) * stepDelay, function()
			createBoltGlowSegment(fromPosition, toPosition, coreThickness, lifetime, boltColor)
		end)
	end

	local branchCount = if isChain
		then math.max(1, math.floor((config.BranchCount or 0) * 0.35))
		else (config.BranchCount or 0)
	for _ = 1, branchCount do
		local branchIndex = math.random(2, math.max(2, #boltPoints - 1))
		local branchStart = boltPoints[branchIndex]
		local branchDirection = (right * (if math.random(1, 2) == 1 then 1 else -1)) + (up * (math.random() - 0.5))
		local branchLength = math.random(28, 68) / 10 * (if isChain then 0.65 else 1)
		local branchEnd = branchStart + branchDirection.Unit * branchLength
		local delayTime = math.max(0, (branchIndex - 2) * stepDelay)

		task.delay(delayTime, function()
			createBoltGlowSegment(branchStart, branchEnd, coreThickness * 0.48, lifetime * 0.72, boltColor)
		end)
	end

	task.delay(math.max(0, (#boltPoints - 2) * stepDelay), function()
		createLightningImpactPop(endPosition, if isChain then 0.34 else 0.52, boltColor)
	end)
end

local function applyDeathKnockback(candidate, direction, config)
	if GameConfig.LightweightZombieMovement then
		return
	end

	if candidate.NPC and candidate.NPC.ApplyDeathKnockback then
		local handled = candidate.NPC:ApplyDeathKnockback(direction, config.KillKnockback, config.KnockbackUpward)
		if handled then
			return
		end
	end

	local root = candidate.Root
	if not root then
		return
	end

	local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)

	if horizontalDirection.Magnitude <= 0.05 then
		horizontalDirection = Vector3.new(1, 0, 0)
	end

	local attachment = root:FindFirstChild("LightningKnockbackAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "LightningKnockbackAttachment"
		attachment.Parent = root
	end

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "LightningDeathKnockback"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = (horizontalDirection.Unit * config.KillKnockback)
		+ Vector3.new(0, config.KnockbackUpward, 0)
	linearVelocity.Parent = root

	Debris:AddItem(linearVelocity, config.KnockbackDuration)
end

local function getHandPosition(character, root)
	local rightHand = character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("RightLowerArm")

	if rightHand and rightHand:IsA("BasePart") then
		return rightHand.Position
	end

	return root.Position + (root.CFrame.RightVector * 1.4) + Vector3.new(0, 0.7, 0)
end

local function getLightningHit(player, startPosition, direction, config)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		player.Character,
		Workspace:WaitForChild("Zombies"),
	}

	local result = Workspace:Raycast(startPosition, direction * config.Range, raycastParams)
	if result then
		return result.Position, result.Distance
	end

	return startPosition + (direction * config.Range), config.Range
end

local function getBeamCandidate(startPosition, direction, model, maxDistance, radius)
	local zombieCandidate = ZombieService.getCandidateFromModel(model)
	local root = zombieCandidate and zombieCandidate.Root

	if not zombieCandidate or not zombieCandidate.Humanoid or not root then
		return nil
	end

	local toZombie = root.Position - startPosition
	local projected = toZombie:Dot(direction)

	if projected < 0 or projected > maxDistance then
		return nil
	end

	local closestPoint = startPosition + (direction * projected)
	local distanceFromBeam = (root.Position - closestPoint).Magnitude

	if distanceFromBeam > radius then
		return nil
	end

	return {
		NPC = zombieCandidate.NPC,
		Humanoid = zombieCandidate.Humanoid,
		Root = root,
		Projected = projected,
		DistanceFromBeam = distanceFromBeam,
	}
end

local function findFirstZombieOnBeam(startPosition, direction, maxDistance, radius)
	local zombiesFolder = Workspace:WaitForChild("Zombies")
	local bestCandidate = nil

	for _, model in zombiesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local candidate = getBeamCandidate(startPosition, direction, model, maxDistance, radius)
		if candidate and (not bestCandidate or candidate.Projected < bestCandidate.Projected) then
			bestCandidate = candidate
		end
	end

	return bestCandidate
end

local function findAimAssistZombie(startPosition, direction, maxDistance, config)
	local zombiesFolder = Workspace:WaitForChild("Zombies")
	local bestCandidate = nil
	local bestScore = math.huge
	local forwardBias = config.AimAssistForwardBias or 0.35

	for _, model in zombiesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local candidate = getBeamCandidate(startPosition, direction, model, maxDistance, config.AimAssistRadius)
		if candidate then
			local score = candidate.Projected + (candidate.DistanceFromBeam * forwardBias)
			if score < bestScore then
				bestScore = score
				bestCandidate = candidate
			end
		end
	end

	return bestCandidate
end

local function findDirectAimZombie(startPosition, direction, maxDistance, config)
	local zombiesFolder = Workspace:WaitForChild("Zombies")
	local bestCandidate = nil
	local directRadius = config.DirectHitRadius or config.Radius or 2.5

	for _, model in zombiesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local candidate = getBeamCandidate(startPosition, direction, model, maxDistance, directRadius)
		if candidate and (not bestCandidate or candidate.Projected < bestCandidate.Projected) then
			bestCandidate = candidate
		end
	end

	return bestCandidate
end

local function findNearestChainZombie(originPosition, ignoredRoots, config)
	local zombiesFolder = Workspace:WaitForChild("Zombies")
	local bestCandidate = nil
	local bestDistance = math.huge

	for _, model in zombiesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local zombieCandidate = ZombieService.getCandidateFromModel(model)
		local root = zombieCandidate and zombieCandidate.Root

		if not zombieCandidate or not root or ignoredRoots[root] then
			continue
		end

		local distance = (root.Position - originPosition).Magnitude
		if distance <= config.ChainRange and distance < bestDistance then
			bestDistance = distance
			bestCandidate = {
				NPC = zombieCandidate.NPC,
				Humanoid = zombieCandidate.Humanoid,
				Root = root,
			}
		end
	end

	return bestCandidate
end

local function getZombieCandidates()
	local zombiesFolder = Workspace:WaitForChild("Zombies")
	local candidates = {}

	for _, model in zombiesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local candidate = ZombieService.getCandidateFromModel(model)
		if candidate then
			table.insert(candidates, candidate)
		end
	end

	return candidates
end

local function damageZombiesInRadius(player, position, radius, damage, ignoredRoot)
	for _, candidate in getZombieCandidates() do
		if ignoredRoot and candidate.Root == ignoredRoot then
			continue
		end

		if (candidate.Root.Position - position).Magnitude <= radius then
			ZombieService.damageNpc(candidate.NPC, player, damage)
		end
	end
end

local function findBiggestZombieGroup(radius)
	local candidates = getZombieCandidates()
	local bestCandidate = nil
	local bestCount = 0

	for _, candidate in candidates do
		local count = 0
		for _, otherCandidate in candidates do
			if (otherCandidate.Root.Position - candidate.Root.Position).Magnitude <= radius then
				count += 1
			end
		end

		if count > bestCount then
			bestCount = count
			bestCandidate = candidate
		end
	end

	return bestCandidate
end

local function getMeteorRaycastParams(player)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		player.Character,
		Workspace:WaitForChild("Zombies"),
	}

	return raycastParams
end

local function getGroundImpactPosition(player, position)
	local result =
		Workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -180, 0), getMeteorRaycastParams(player))

	return result and result.Position or position
end

local function getTornadoGroundPosition(player, position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local referenceY = root and root.Position.Y or position.Y
	local rayOrigin = Vector3.new(position.X, referenceY + TORNADO_GROUND_RAY_HEIGHT, position.Z)
	local result =
		Workspace:Raycast(rayOrigin, Vector3.new(0, -TORNADO_GROUND_RAY_DEPTH, 0), getMeteorRaycastParams(player))

	if result then
		local verticalOffset = result.Position.Y - referenceY
		if verticalOffset <= TORNADO_MAX_GROUND_ABOVE and verticalOffset >= -TORNADO_MAX_GROUND_BELOW then
			return result.Position
		end
	end

	local fallbackY = if root then root.Position.Y - 2.8 else position.Y
	return Vector3.new(position.X, fallbackY, position.Z)
end

local function getChildAtPath(root, path)
	local current = root
	for _, childName in path do
		current = findChildCaseInsensitive(current, childName)
		if not current then
			return nil
		end
	end

	return current
end

local function getTornadoVFXRoot()
	for _, path in TORNADO_VFX_ROOT_PATHS do
		local root = getChildAtPath(ReplicatedStorage, path)
		if root then
			return root
		end
	end

	return nil
end

local function createTornadoCarrier(position)
	local holder = Instance.new("Model")
	holder.Name = "TornadoDisaster"

	local anchor = Instance.new("Part")
	anchor.Name = "TornadoVFXAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = holder

	holder.PrimaryPart = anchor
	return holder, anchor
end

local function mountLooseTornadoVFX(vfx, anchor)
	if vfx:IsA("ParticleEmitter") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "TornadoVFXAttachment"
		attachment.Parent = anchor
		vfx.Parent = attachment
		return
	end

	if vfx:IsA("Attachment") then
		vfx.Parent = anchor
		return
	end

	local looseAttachment = nil
	for _, descendant in vfx:GetDescendants() do
		if descendant:IsA("Attachment") then
			local parent = descendant.Parent
			if
				not parent or (not parent:IsA("BasePart") and not parent:IsA("Bone") and parent ~= Workspace.Terrain)
			then
				descendant.Parent = anchor
			end
		elseif descendant:IsA("ParticleEmitter") then
			local parent = descendant.Parent
			if parent and (parent:IsA("Attachment") or parent:IsA("BasePart")) then
				continue
			end

			if not looseAttachment then
				looseAttachment = Instance.new("Attachment")
				looseAttachment.Name = "TornadoLooseParticles"
				looseAttachment.Parent = anchor
			end

			descendant.Parent = looseAttachment
		end
	end
end

local function getTornadoAsset()
	local root = getTornadoVFXRoot()
	if not root then
		return nil
	end

	local asset = findAssetByNames(root, TORNADO_ASSET_NAMES)
	if asset then
		return asset
	end

	if root:IsA("Model") or root:IsA("BasePart") then
		return root
	end

	return nil
end

local function prepareTornadoBasePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function activateTornadoEmitter(emitter)
	if emitter.Rate <= 0 then
		local sustainRate = emitter:GetAttribute("SustainRate") or emitter:GetAttribute("TornadoRate")
		emitter.Rate = if typeof(sustainRate) == "number" and sustainRate > 0 then sustainRate else 35
	end

	emitter.Enabled = true

	local burstCount = emitter:GetAttribute("EmitCount")
	if typeof(burstCount) ~= "number" then
		burstCount = emitter:GetAttribute("BurstCount")
	end

	if typeof(burstCount) == "number" and burstCount > 0 then
		emitter:Emit(math.floor(burstCount))
	elseif emitter.Rate <= 0 then
		emitter:Emit(24)
	end
end

local function prepareTornadoVFX(instance)
	if instance:IsA("BasePart") then
		prepareTornadoBasePart(instance)
	elseif instance:IsA("ParticleEmitter") then
		activateTornadoEmitter(instance)
	elseif instance:IsA("Trail") or instance:IsA("Beam") then
		instance.Enabled = true
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			prepareTornadoBasePart(descendant)
		elseif descendant:IsA("ParticleEmitter") then
			activateTornadoEmitter(descendant)
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end
end

local function setTornadoVisualCFrame(visual, cframe)
	if visual:IsA("Model") then
		visual:PivotTo(cframe)
	elseif visual:IsA("BasePart") then
		visual.CFrame = cframe
	else
		local pivotPart = visual:FindFirstChildWhichIsA("BasePart", true)
		if not pivotPart then
			return
		end

		local delta = cframe * pivotPart.CFrame:Inverse()
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CFrame = delta * descendant.CFrame
			end
		end
	end
end

local function createFallbackTornadoVisual(position, config)
	local height = config.Height or 34
	local radius = config.Radius or 18
	local holder = Instance.new("Model")
	holder.Name = "TornadoDisaster"
	holder.Parent = Workspace

	local funnel = Instance.new("Part")
	funnel.Name = "TornadoFunnel"
	funnel.Anchored = true
	funnel.CanCollide = false
	funnel.CanQuery = false
	funnel.CanTouch = false
	funnel.CastShadow = false
	funnel.Color = Color3.fromRGB(178, 215, 218)
	funnel.Material = Enum.Material.ForceField
	funnel.Shape = Enum.PartType.Cylinder
	funnel.Size = Vector3.new(radius * 1.1, height, radius * 1.1)
	funnel.CFrame = CFrame.new(position + Vector3.new(0, height * 0.5, 0))
	funnel.Transparency = 0.38
	funnel.Parent = holder

	local light = Instance.new("PointLight")
	light.Name = "TornadoGlow"
	light.Brightness = 1.1
	light.Color = Color3.fromRGB(190, 235, 235)
	light.Range = radius * 1.8
	light.Parent = funnel

	for index = 1, 4 do
		local ring = Instance.new("Part")
		ring.Name = `TornadoRing{index}`
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Color = Color3.fromRGB(220, 240, 242)
		ring.Material = Enum.Material.Neon
		ring.Shape = Enum.PartType.Cylinder
		local ringRadius = radius * (0.42 + index * 0.16)
		ring.Size = Vector3.new(0.16, ringRadius * 2, ringRadius * 2)
		ring.CFrame = CFrame.new(position + Vector3.new(0, index * (height / 5), 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.42
		ring.Parent = holder

		TweenService:Create(ring, TweenInfo.new(config.Duration or 4, Enum.EasingStyle.Linear), {
			Orientation = ring.Orientation + Vector3.new(0, 360 * (if index % 2 == 0 then -1 else 1), 0),
			Transparency = 1,
		}):Play()
	end

	TweenService:Create(funnel, TweenInfo.new(config.Duration or 4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(radius * 1.65, height * 1.08, radius * 1.65),
	}):Play()

	Debris:AddItem(holder, (config.Duration or 4) + 0.4)
	return holder
end

local function createTornadoVisual(position, config)
	local template = getTornadoAsset()
	if not template then
		return createFallbackTornadoVisual(position, config)
	end

	local holder, anchor = createTornadoCarrier(position)
	local visual = template:Clone()
	visual.Name = "TornadoVFX"
	local mountedLooseVFX = false
	if visual:IsA("Model") then
		if config.VFXScale and config.VFXScale ~= 1 then
			pcall(function()
				visual:ScaleTo(config.VFXScale)
			end)
		end
		setTornadoVisualCFrame(visual, CFrame.new(position))
		visual.Parent = holder
	elseif visual:IsA("BasePart") then
		if config.VFXScale and config.VFXScale ~= 1 then
			visual.Size *= config.VFXScale
		end
		visual.CFrame = CFrame.new(position)
		visual.Parent = holder
	else
		mountLooseTornadoVFX(visual, anchor)
		mountedLooseVFX = true
	end

	if not mountedLooseVFX then
		mountLooseTornadoVFX(visual, anchor)
	end
	holder.Parent = Workspace
	prepareTornadoVFX(holder)
	Debris:AddItem(holder, (config.Duration or 4) + 1.5)
	return holder
end

local function getTornadoVictims(position, radius)
	local victims = {}

	for _, candidate in getZombieCandidates() do
		local root = candidate.Root
		if not root then
			continue
		end

		local offset = position - root.Position
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		if flatOffset.Magnitude <= radius then
			table.insert(victims, candidate)
		end
	end

	return victims
end

local function canTornadoDrag(candidate)
	local humanoid = candidate and candidate.Humanoid
	return humanoid and humanoid.RigType == Enum.HumanoidRigType.R6
end

local function applyTornadoPull(candidate, position, config)
	if not canTornadoDrag(candidate) then
		return
	end

	local root = candidate.Root
	if not root or not root.Parent then
		return
	end

	local toCenter = position - root.Position
	local flatToCenter = Vector3.new(toCenter.X, 0, toCenter.Z)
	local distance = flatToCenter.Magnitude
	local inward = unitOrZero(flatToCenter)
	local tangent = if inward == Vector3.zero then Vector3.zero else Vector3.new(-inward.Z, 0, inward.X)
	local radius = config.Radius or 16
	local distanceAlpha = 1 - math.clamp(distance / radius, 0, 1)
	local holdRadius = config.HoldRadius or 5.5
	local targetLift = math.clamp((config.Height or 34) * 0.32, 6, 16)
	local verticalOffset = (position.Y + targetLift) - root.Position.Y
	local pullScale = if distance <= holdRadius then 0.22 else 0.65 + distanceAlpha
	local velocity = (inward * (config.PullStrength or 62) * pullScale)
		+ (tangent * (config.SwirlStrength or 44) * (0.4 + distanceAlpha))
		+ Vector3.new(0, math.clamp(verticalOffset * 5, 8, config.LiftStrength or 24), 0)

	root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(velocity, 0.55)
	root.AssemblyAngularVelocity = Vector3.new(0, 8 + (distanceAlpha * 12), 0)
end

local function releaseTornadoVictim(candidate, position, config)
	if not canTornadoDrag(candidate) then
		return
	end

	local root = candidate.Root
	if not root or not root.Parent or candidate.Humanoid.Health <= 0 then
		return
	end

	local away = root.Position - position
	local flatAway = Vector3.new(away.X, 0, away.Z)
	local fallbackDirection = unitOrZero(Vector3.new(math.random() - 0.5, 0, math.random() - 0.5))
	if fallbackDirection == Vector3.zero then
		fallbackDirection = Vector3.new(1, 0, 0)
	end
	local direction = if flatAway.Magnitude > 0.05 then flatAway.Unit else fallbackDirection
	local velocity = (direction * (config.ReleaseHorizontal or 72)) + Vector3.new(0, config.ReleaseUpward or 38, 0)

	if candidate.NPC.ApplyTornadoRelease then
		candidate.NPC:ApplyTornadoRelease(
			direction,
			config.ReleaseHorizontal,
			config.ReleaseUpward,
			config.ReleaseRagdollDuration
		)
	else
		root.AssemblyLinearVelocity = velocity
	end
end

local function damageAndPullTornadoVictims(player, position, config, damage, captured)
	local radius = config.Radius or 18

	for _, candidate in getTornadoVictims(position, radius) do
		ZombieService.damageNpc(candidate.NPC, player, damage)
		if canTornadoDrag(candidate) and not GameConfig.LightweightZombieMovement then
			captured[candidate.Root] = candidate
			applyTornadoPull(candidate, position, config)
		end
	end
end

local function findTornadoTrackingTarget(position, config)
	local bestCandidate = nil
	local bestDistance = config.TrackingRange or 55

	for _, candidate in getZombieCandidates() do
		local root = candidate.Root
		if not root then
			continue
		end

		local flatOffset = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
		local distance = flatOffset.Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestCandidate = candidate
		end
	end

	return bestCandidate
end

local function runTornadoProjectile(player, startPosition, direction, config, tornadoLevel)
	local visual = createTornadoVisual(startPosition, config)
	local position = startPosition
	local travelDirection = direction
	local damage = (config.Damage or 10) + (math.max(tornadoLevel - 1, 0) * (config.DamagePerUpgrade or 0))
	local expireAt = os.clock() + (config.Duration or 4.2)
	local nextDamageAt = 0
	local nextRetargetAt = 0
	local captured = {}

	while os.clock() < expireAt do
		local deltaTime = RunService.Heartbeat:Wait()
		local now = os.clock()
		local speed = config.ProjectileSpeed or 32

		if tornadoLevel >= 4 and now >= nextRetargetAt then
			nextRetargetAt = now + (config.TrackingRetargetInterval or 0.35)
			local target = findTornadoTrackingTarget(position, config)
			if target and target.Root then
				local toTarget =
					Vector3.new(target.Root.Position.X - position.X, 0, target.Root.Position.Z - position.Z)
				local targetDirection = unitOrZero(toTarget)
				if targetDirection ~= Vector3.zero then
					travelDirection =
						unitOrZero(travelDirection:Lerp(targetDirection, if tornadoLevel >= 5 then 0.72 else 0.48))
				end
			end
		end

		if tornadoLevel >= 4 then
			speed = config.TrackingSpeed or speed
		end

		position += travelDirection * speed * deltaTime
		position = getTornadoGroundPosition(player, position) + Vector3.new(0, 0.35, 0)
		setTornadoVisualCFrame(visual, CFrame.new(position, position + travelDirection))

		if now >= nextDamageAt then
			nextDamageAt = now + (config.TickInterval or 0.35)
			damageAndPullTornadoVictims(player, position, config, damage, captured)
		elseif not GameConfig.LightweightZombieMovement then
			for _, candidate in getTornadoVictims(position, config.Radius or 16) do
				if canTornadoDrag(candidate) then
					captured[candidate.Root] = candidate
					applyTornadoPull(candidate, position, config)
				end
			end
		end
	end

	for root, candidate in captured do
		if root and root.Parent then
			releaseTornadoVictim(candidate, position, config)
		end
	end

	if visual and visual.Parent then
		visual:Destroy()
	end
end

local function createMeteorFire(player, position, config, meteorScale)
	local groundFireScale = math.clamp((config.FireRadius / 12) * (1.65 + ((meteorScale or 1) * 2.2)), 4, 18)
	local playedGroundFireVFX = playMeteorNamedVFX("GroundFire", position + Vector3.new(0, 0.05, 0), {
		Lifetime = config.FireDuration + 3,
		EmitDuration = 0.5,
		ActiveDuration = config.FireDuration,
		PostDisableDuration = 3,
		Scale = groundFireScale,
		EmitScale = math.clamp(groundFireScale * 2.8, 6, 36),
		HideCarrierParts = true,
	})
	local fire = nil

	if not playedGroundFireVFX then
		fire = Instance.new("Part")
		fire.Name = "MeteorFire"
		fire.Anchored = true
		fire.CanCollide = false
		fire.CanQuery = false
		fire.CanTouch = false
		fire.CastShadow = false
		fire.Material = Enum.Material.Neon
		fire.Color = Color3.fromRGB(255, 96, 18)
		fire.Shape = Enum.PartType.Cylinder
		fire.Size = Vector3.new(0.25, config.FireRadius * 2, config.FireRadius * 2)
		fire.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		fire.Transparency = 0.35
		fire.Parent = Workspace

		local pointLight = Instance.new("PointLight")
		pointLight.Name = "MeteorFireLight"
		pointLight.Brightness = 1.6
		pointLight.Color = Color3.fromRGB(255, 112, 35)
		pointLight.Range = config.FireRadius
		pointLight.Parent = fire

		Debris:AddItem(fire, config.FireDuration)
	end

	task.spawn(function()
		local expireAt = os.clock() + config.FireDuration
		while os.clock() < expireAt do
			damageZombiesInRadius(player, position, config.FireRadius, config.FireDamage)
			task.wait(config.FireTickInterval)
		end
	end)

	if fire then
		tweenAndDestroy(fire, TweenInfo.new(config.FireDuration, Enum.EasingStyle.Linear), {
			Transparency = 1,
		})
	end
end

local function damageZombie(player, candidate, direction, config, damage)
	if not candidate then
		return
	end

	local healthBefore = candidate.Humanoid.Health
	ZombieService.damageNpc(candidate.NPC, player, damage)

	if healthBefore > 0 and candidate.Humanoid.Health <= 0 then
		applyDeathKnockback(candidate, direction, config)
	end
end

local function damageLightningChain(player, firstCandidate, direction, config, lightningLevel)
	lightningLevel = math.clamp(math.floor(lightningLevel or 0), 0, config.MaxUpgradeLevel)
	local damage = config.Damage + (lightningLevel * config.DamagePerUpgrade)
	local chainTargets = lightningLevel * config.ChainTargetsPerUpgrade
	local currentCandidate = firstCandidate
	local previousPosition = nil
	local ignoredRoots = {}

	if not currentCandidate then
		return
	end

	if lightningLevel <= 0 then
		damageZombie(player, currentCandidate, direction, config, damage)
		return
	end

	for chainIndex = 0, chainTargets do
		if not currentCandidate then
			return
		end

		ignoredRoots[currentCandidate.Root] = true
		local hitDirection = direction
		if previousPosition then
			local chainDirection = currentCandidate.Root.Position - previousPosition
			if chainDirection.Magnitude > 0.05 then
				hitDirection = chainDirection.Unit
			end
		end

		damageZombie(player, currentCandidate, hitDirection, config, damage)
		previousPosition = currentCandidate.Root.Position

		if chainIndex >= chainTargets then
			return
		end

		local nextCandidate = findNearestChainZombie(currentCandidate.Root.Position, ignoredRoots, config)
		if nextCandidate then
			createLightningBeamVFX(currentCandidate.Root.Position, nextCandidate.Root.Position, config, true)
		end

		currentCandidate = nextCandidate
	end
end

local function upgradeLightning(player)
	local config = DisasterWeaponConfig.Lightning
	local currentLevel = PlayerDataService.getLightningLevel(player)

	if currentLevel >= config.MaxUpgradeLevel then
		return
	end

	local nextLevel = currentLevel + 1
	local cost = config.UpgradeCosts[nextLevel]
	if not cost then
		return
	end

	if not PlayerDataService.spendCoins(player, cost) then
		return
	end

	PlayerDataService.setLightningLevel(player, nextLevel)
end

local function upgradeMeteor(player)
	local config = DisasterWeaponConfig.Meteor
	local currentLevel = PlayerDataService.getMeteorLevel(player)

	if
		not PlayerDataService.hasUnlockedWeapon(player, "Meteor")
		or not PlayerDataService.hasEquippedWeapon(player, "Meteor")
	then
		return
	end

	if currentLevel >= config.MaxUpgradeLevel then
		return
	end

	local nextLevel = currentLevel + 1
	local cost = config.UpgradeCosts[nextLevel]
	if not cost then
		return
	end

	if not PlayerDataService.spendCoins(player, cost) then
		return
	end

	PlayerDataService.setMeteorLevel(player, nextLevel)
	WeaponGrantService.grantWeapon(player, "Meteor")

	-- Let the player cast immediately after upgrading into stage 4/5.
	local playerCastTimes = lastCastTimesByUserId[player.UserId]
	if not playerCastTimes then
		playerCastTimes = {}
		lastCastTimesByUserId[player.UserId] = playerCastTimes
	end
	playerCastTimes.Meteor = 0
end

local function upgradeTornado(player)
	local config = DisasterWeaponConfig.Tornado
	local currentLevel = PlayerDataService.getTornadoLevel(player)

	if
		not PlayerDataService.hasUnlockedWeapon(player, "Tornado")
		or not PlayerDataService.hasEquippedWeapon(player, "Tornado")
	then
		return
	end

	if currentLevel >= config.MaxUpgradeLevel then
		return
	end

	local nextLevel = currentLevel + 1
	local cost = config.UpgradeCosts[nextLevel]
	if not cost then
		return
	end

	if not PlayerDataService.spendCoins(player, cost) then
		return
	end

	PlayerDataService.setTornadoLevel(player, nextLevel)
	WeaponGrantService.grantWeapon(player, "Tornado")
end

local function canCast(player, weaponName, config, cooldownOverride)
	if not isPlayerAlive(player) then
		return false, nil
	end

	local tool = getEquippedTool(player, weaponName)
	if not tool then
		return false, nil
	end

	return true, tool
end

local function castLightning(player, direction)
	local config = DisasterWeaponConfig.Lightning
	if not canCast(player, "Lightning", config) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude <= 0.05 then
		return
	end

	flatDirection = flatDirection.Unit
	local handPosition = getHandPosition(character, root)
	local startPosition = Vector3.new(handPosition.X, root.Position.Y + config.BeamHeight, handPosition.Z)
	local endPosition, maxDistance = getLightningHit(player, startPosition, flatDirection, config)
	local hitZombie = findDirectAimZombie(startPosition, flatDirection, maxDistance, config)
		or findAimAssistZombie(startPosition, flatDirection, maxDistance, config)
		or findFirstZombieOnBeam(startPosition, flatDirection, maxDistance, config.Radius)

	if hitZombie then
		endPosition = hitZombie.Root.Position
	end

	createLightningBeamVFX(startPosition, endPosition, config)
	damageLightningChain(player, hitZombie, flatDirection, config, PlayerDataService.getLightningLevel(player))
end

local function getHandMeteorImpact(player, startPosition, direction, config)
	local targetCandidate = findAimAssistZombie(startPosition, direction, config.Range, {
		AimAssistRadius = config.HandAimAssistRadius,
	})
	if targetCandidate then
		return targetCandidate.Root.Position, (targetCandidate.Root.Position - startPosition).Magnitude, targetCandidate
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		player.Character,
		Workspace:WaitForChild("Zombies"),
	}

	local result = Workspace:Raycast(startPosition, direction * config.Range, raycastParams)
	if result then
		return result.Position, result.Distance
	end

	return startPosition + (direction * config.Range), config.Range
end

local function castHandMeteor(player, direction, levelConfig, config, character, root)
	local handPosition = getHandPosition(character, root)
	local startPosition = handPosition + Vector3.new(0, 0.2, 0)
	local impactPosition, distance, targetCandidate = getHandMeteorImpact(player, startPosition, direction, config)
	local travelTime = math.max(distance / config.ProjectileSpeed, 0.08)
	local meteor = createMeteorVisual(levelConfig.Scale)

	animateMeteor(meteor, startPosition, impactPosition, travelTime)

	task.delay(travelTime, function()
		if meteor.Parent then
			meteor:Destroy()
		end

		createMeteorImpact(impactPosition, levelConfig.Radius, levelConfig.Scale)
		local ignoredRoot = nil
		if targetCandidate and targetCandidate.Humanoid and targetCandidate.Humanoid.Health > 0 then
			damageZombie(player, targetCandidate, direction, config, levelConfig.Damage)
			ignoredRoot = targetCandidate.Root
		end

		damageZombiesInRadius(player, impactPosition, levelConfig.Radius, levelConfig.Damage, ignoredRoot)
	end)
end

local function getAirStrikeTargetPosition(rootPosition, direction, range, requestedTargetPosition)
	local fallbackTargetPosition = rootPosition + (direction * 36)
	if typeof(requestedTargetPosition) ~= "Vector3" then
		return fallbackTargetPosition
	end

	local flatDelta =
		Vector3.new(requestedTargetPosition.X - rootPosition.X, 0, requestedTargetPosition.Z - rootPosition.Z)
	local distance = flatDelta.Magnitude
	if distance <= 0.05 then
		return fallbackTargetPosition
	end

	local clampedDistance = math.min(distance, range)
	local clampedFlatPosition = rootPosition + (flatDelta.Unit * clampedDistance)
	return Vector3.new(clampedFlatPosition.X, requestedTargetPosition.Y, clampedFlatPosition.Z)
end

local function castAirStrikeMeteor(player, direction, levelConfig, config, root, requestedTargetPosition)
	local targetPosition = getAirStrikeTargetPosition(root.Position, direction, config.Range, requestedTargetPosition)
	local impactPosition = getGroundImpactPosition(player, targetPosition) + Vector3.new(0, config.ImpactLift, 0)
	local startPosition = impactPosition + Vector3.new(-18, config.AirStrikeHeight, -18)
	local meteor = createMeteorVisual(levelConfig.Scale)

	animateMeteor(meteor, startPosition, impactPosition, config.AirStrikeFallTime)

	task.delay(config.AirStrikeFallTime, function()
		if meteor.Parent then
			meteor:Destroy()
		end

		createMeteorImpact(impactPosition, levelConfig.Radius, levelConfig.Scale)
		damageZombiesInRadius(player, impactPosition, levelConfig.Radius, levelConfig.Damage)
		createMeteorFire(player, impactPosition, config, levelConfig.Scale)
	end)
end

local function castMeteor(player, direction, targetPosition)
	local config = DisasterWeaponConfig.Meteor
	local meteorLevel = PlayerDataService.getMeteorLevel(player)
	if
		not PlayerDataService.hasUnlockedWeapon(player, "Meteor")
		or not PlayerDataService.hasEquippedWeapon(player, "Meteor")
	then
		return
	end

	if meteorLevel <= 0 then
		return
	end

	local cooldown = if meteorLevel <= 3 then config.HandCooldown or config.Cooldown else config.Cooldown
	if not canCast(player, "Meteor", config, cooldown) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude <= 0.05 then
		return
	end

	flatDirection = flatDirection.Unit
	local levelConfig = config.AirStrikeLevels[meteorLevel]
		or config.HandCastLevels[meteorLevel]
		or config.HandCastLevels[1]

	if meteorLevel >= 4 then
		castAirStrikeMeteor(player, flatDirection, levelConfig, config, root, targetPosition)
	else
		castHandMeteor(player, flatDirection, levelConfig, config, character, root)
	end
end

local function castTornado(player, direction, targetPosition)
	local config = DisasterWeaponConfig.Tornado
	local tornadoLevel = math.max(PlayerDataService.getTornadoLevel(player), 1)

	if not getEquippedTool(player, "Tornado") then
		return
	end

	if not canCast(player, "Tornado", config) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude <= 0.05 then
		return
	end

	flatDirection = flatDirection.Unit
	local handPosition = getHandPosition(character, root)
	local startPosition = getTornadoGroundPosition(player, handPosition + (flatDirection * 5)) + Vector3.new(0, 0.35, 0)

	task.spawn(runTornadoProjectile, player, startPosition, flatDirection, config, tornadoLevel)
end

function DisasterWeaponService.start()
	Network.disasterWeaponCast.listen(function(data, player)
		if typeof(data) ~= "table" or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		if data.weapon == "Lightning" and typeof(data.direction) == "Vector3" then
			castLightning(player, data.direction)
		elseif data.weapon == "Meteor" and typeof(data.direction) == "Vector3" then
			castMeteor(player, data.direction, data.targetPosition)
		elseif data.weapon == "Tornado" and typeof(data.direction) == "Vector3" then
			castTornado(player, data.direction, data.targetPosition)
		end
	end)

	Network.weaponUpgradeRequest.listen(function(data, player)
		if typeof(data) ~= "table" or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		if data.weapon == "Lightning" then
			upgradeLightning(player)
		elseif data.weapon == "Meteor" then
			upgradeMeteor(player)
		elseif data.weapon == "Tornado" then
			upgradeTornado(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCastTimesByUserId[player.UserId] = nil
	end)
end

return DisasterWeaponService
