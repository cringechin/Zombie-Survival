local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZombieService = require(script.Parent.ZombieService)

local DisasterWeaponService = {}

local lastCastTimes = {}

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

local function createBoltSegment(fromPosition, toPosition, thickness, lifetime)
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
	part.Color = Color3.fromRGB(115, 180, 225)
	part.Size = Vector3.new(thickness, thickness, distance)
	part.CFrame = CFrame.new(fromPosition, toPosition) * CFrame.new(0, 0, -distance / 2)
	part.Parent = Workspace

	tweenAndDestroy(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(thickness * 0.2, thickness * 0.2, distance),
	})
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

local function createLightningBeamVFX(startPosition, endPosition, config)
	local lastPosition = startPosition
	local boltPoints = { startPosition }
	local direction = (endPosition - startPosition)
	local right = Vector3.new(-direction.Z, 0, direction.X)

	if right.Magnitude <= 0.05 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	for index = 1, config.BoltSegments do
		local alpha = index / config.BoltSegments
		local basePosition = startPosition:Lerp(endPosition, alpha)
		local jitterScale = math.max(0.5, 3 * (1 - alpha))
		local jitter = (right * ((math.random() - 0.5) * jitterScale)) + Vector3.new(0, (math.random() - 0.5) * 1.4, 0)
		local nextPosition = if index == config.BoltSegments then endPosition else basePosition + jitter

		createBoltSegment(lastPosition, nextPosition, 0.22, 0.11)
		table.insert(boltPoints, nextPosition)
		lastPosition = nextPosition
	end

	for _ = 1, config.BranchCount do
		local branchStart = boltPoints[math.random(2, math.max(2, #boltPoints - 1))]
		local branchEnd = branchStart + (right * math.random(-8, 8)) + Vector3.new(0, math.random(-4, 4), 0)
		createBoltSegment(branchStart, branchEnd, 0.08, 0.09)
	end

	createMuzzleFlash(startPosition)
	createMuzzleFlash(endPosition)
end

local function applyDeathKnockback(root, direction, config)
	if GameConfig.LightweightZombieMovement then
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

	for _, model in zombiesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local candidate = getBeamCandidate(startPosition, direction, model, maxDistance, config.AimAssistRadius)
		if candidate and (not bestCandidate or candidate.DistanceFromBeam < bestCandidate.DistanceFromBeam) then
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

local function damageZombie(player, candidate, direction, config, damage)
	if not candidate then
		return
	end

	local healthBefore = candidate.Humanoid.Health
	ZombieService.damageNpc(candidate.NPC, player, damage)

	if healthBefore > 0 and candidate.Humanoid.Health <= 0 then
		applyDeathKnockback(candidate.Root, direction, config)
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
			createLightningBeamVFX(currentCandidate.Root.Position, nextCandidate.Root.Position, config)
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

local function canCast(player, weaponName, config)
	if not getEquippedTool(player, weaponName) then
		return false
	end

	local playerCastTimes = lastCastTimes[player]
	if not playerCastTimes then
		playerCastTimes = {}
		lastCastTimes[player] = playerCastTimes
	end

	local lastCastTime = playerCastTimes[weaponName] or 0
	if os.clock() - lastCastTime < config.Cooldown then
		return false
	end

	playerCastTimes[weaponName] = os.clock()
	return true
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
	local hitZombie = findAimAssistZombie(startPosition, flatDirection, maxDistance, config)
		or findFirstZombieOnBeam(startPosition, flatDirection, maxDistance, config.Radius)

	if hitZombie then
		endPosition = hitZombie.Root.Position
	end

	createLightningBeamVFX(startPosition, endPosition, config)
	damageLightningChain(player, hitZombie, flatDirection, config, PlayerDataService.getLightningLevel(player))
end

function DisasterWeaponService.start()
	Network.disasterWeaponCast.listen(function(data, player)
		if typeof(data) ~= "table" or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		if data.weapon == "Lightning" and typeof(data.direction) == "Vector3" then
			castLightning(player, data.direction)
		end
	end)

	Network.weaponUpgradeRequest.listen(function(data, player)
		if typeof(data) ~= "table" or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		if data.weapon == "Lightning" then
			upgradeLightning(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCastTimes[player] = nil
	end)
end

return DisasterWeaponService
