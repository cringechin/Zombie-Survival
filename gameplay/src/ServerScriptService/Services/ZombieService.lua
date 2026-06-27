local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BasicZombie = require(ServerScriptService.Subclasses.NPCs.BasicZombie)
local LightningBoss = require(ServerScriptService.Subclasses.NPCs.LightningBoss)
local LightningMinion = require(ServerScriptService.Subclasses.NPCs.LightningMinion)
local Sprinter = require(ServerScriptService.Subclasses.NPCs.Sprinter)
local Tank = require(ServerScriptService.Subclasses.NPCs.Tank)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local ZombieService = {}
ZombieService.Order = 50

local zombiesFolder = Workspace:WaitForChild("Zombies")
local spawnsFolder = Workspace:WaitForChild("ZombieSpawns")
local bossLightningVfxEvent = ReplicatedStorage:FindFirstChild("BossLightningVfxEvent")
if not bossLightningVfxEvent then
	bossLightningVfxEvent = Instance.new("RemoteEvent")
	bossLightningVfxEvent.Name = "BossLightningVfxEvent"
	bossLightningVfxEvent.Parent = ReplicatedStorage
end

local liveZombies = {}
local liveZombieList = {}
local liveZombieListDirty = false
local modelToNpc = {}
local updateCursor = 1
local recentlyUsedSpawns = {}
local zombieSpawnWeights = GameConfig.ZombieSpawnWeights or {}
local activeBoss = nil
local getLiveCap

local function getAlivePlayerRoots()
	local roots = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid and root and humanoid.Health > 0 then
			table.insert(roots, root)
		end
	end

	return roots
end

local function getAliveDamageTargets()
	local targets = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid and root and humanoid.Health > 0 then
			table.insert(targets, {
				Humanoid = humanoid,
				Root = root,
			})
		end
	end

	local defensesFolder = Workspace:FindFirstChild("Defenses")
	if defensesFolder then
		for _, defense in defensesFolder:GetChildren() do
			if defense:IsA("Model") then
				local humanoid = defense:FindFirstChildOfClass("Humanoid")
				local root = defense.PrimaryPart or defense:FindFirstChild("HumanoidRootPart")
				if humanoid and root and humanoid.Health > 0 then
					table.insert(targets, {
						Humanoid = humanoid,
						Root = root,
					})
				end
			end
		end
	end

	return targets
end

local function getSpawnExclusions()
	local exclusions = {
		zombiesFolder,
	}

	local defensesFolder = Workspace:FindFirstChild("Defenses")
	if defensesFolder then
		table.insert(exclusions, defensesFolder)
	end

	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclusions, player.Character)
		end
	end

	return exclusions
end

local function getUsableSpawnParts()
	local spawnParts = {}

	for _, spawnPart in spawnsFolder:GetChildren() do
		if spawnPart:IsA("BasePart") then
			table.insert(spawnParts, spawnPart)
		end
	end

	return spawnParts
end

local function rememberSpawn(spawnPart)
	recentlyUsedSpawns[spawnPart] = os.clock()
end

local function getRandomSpawnPart()
	local spawnParts = getUsableSpawnParts()
	if #spawnParts == 0 then
		return nil
	end

	local now = os.clock()
	local candidates = {}

	for _, spawnPart in spawnParts do
		local lastUsedAt = recentlyUsedSpawns[spawnPart]
		if not lastUsedAt or now - lastUsedAt > 2.5 then
			table.insert(candidates, spawnPart)
		end
	end

	if #candidates == 0 then
		candidates = spawnParts
	end

	local spawnPart = candidates[math.random(1, #candidates)]
	rememberSpawn(spawnPart)

	return spawnPart
end

local function getGroundPosition(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = getSpawnExclusions()

	local origin = position + Vector3.new(0, 70, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -180, 0), raycastParams)

	return result and result.Position or nil
end

local function getGroundPositionForEffect(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = getSpawnExclusions()

	local result = Workspace:Raycast(position + Vector3.new(0, 90, 0), Vector3.new(0, -220, 0), raycastParams)
	return result and result.Position or position
end

local function isFreeSpawnSpace(position)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = getSpawnExclusions()

	local boxSize = Vector3.new(4, 6, 4)
	local boxCFrame = CFrame.new(position + Vector3.new(0, (boxSize.Y / 2) + 0.2, 0))
	local parts = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)

	for _, part in parts do
		if part.CanCollide and part.Transparency < 1 then
			return false
		end
	end

	return true
end

local function getPlayerSpawnCFrame()
	local roots = getAlivePlayerRoots()
	if #roots == 0 then
		return nil
	end

	for _ = 1, GameConfig.PlayerSpawnAttempts do
		local targetRoot = roots[math.random(1, #roots)]
		local angle = math.random() * math.pi * 2
		local radius = math.random(GameConfig.PlayerSpawnMinDistance * 10, GameConfig.PlayerSpawnMaxDistance * 10) / 10
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local groundPosition = getGroundPosition(targetRoot.Position + offset)

		if groundPosition and isFreeSpawnSpace(groundPosition) then
			local spawnPosition = groundPosition + Vector3.new(0, 3, 0)
			local lookAtPosition = Vector3.new(targetRoot.Position.X, spawnPosition.Y, targetRoot.Position.Z)

			return CFrame.lookAt(spawnPosition, lookAtPosition)
		end
	end

	return nil
end

local function addSpawnJitter(cframe)
	local radius = math.random(25, 80) / 10
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

	return cframe + offset
end

local function getSpawnCFrameNearPosition(position, index, minDistance, maxDistance)
	for _ = 1, GameConfig.PlayerSpawnAttempts do
		local angle = math.random() * math.pi * 2
		local radius = math.random((minDistance or 8) * 10, (maxDistance or 18) * 10) / 10
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local groundPosition = getGroundPosition(position + offset)

		if groundPosition and isFreeSpawnSpace(groundPosition) then
			return CFrame.lookAt(groundPosition + Vector3.new(0, 3, 0), position)
		end
	end

	return getSpawnCFrame(index)
end

local function getSpawnCFrame(index)
	local playerSpawnCFrame = getPlayerSpawnCFrame()
	if playerSpawnCFrame then
		return playerSpawnCFrame
	end

	local spawnPart = getRandomSpawnPart()
	if spawnPart then
		return addSpawnJitter(spawnPart.CFrame + Vector3.new(0, 3, 0))
	end

	local angle = (index * 0.9) + (math.random() * 0.5)
	local radius = math.random(620, 820) / 10
	return CFrame.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
end

local function removeZombie(npc)
	liveZombies[npc] = nil
	if npc.Model then
		modelToNpc[npc.Model] = nil
	end
	if activeBoss == npc then
		activeBoss = nil
		Network.bossStatus.sendToAll({
			active = 0,
			name = "",
			health = 0,
			maxHealth = 0,
		})
	end
	liveZombieListDirty = true
end

local function sendBossStatus(npc)
	if not npc or not npc.Humanoid or npc.Humanoid.Health <= 0 then
		Network.bossStatus.sendToAll({
			active = 0,
			name = "",
			health = 0,
			maxHealth = 0,
		})
		return
	end

	Network.bossStatus.sendToAll({
		active = 1,
		name = npc.Config.DisplayName or "Boss",
		health = math.clamp(math.floor(npc.Humanoid.Health + 0.5), 0, 65535),
		maxHealth = math.clamp(math.floor(npc.Humanoid.MaxHealth + 0.5), 1, 65535),
	})
end

local function registerZombie(npc)
	local model = npc.Model
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not humanoid then
		return nil
	end

	liveZombies[npc] = true
	modelToNpc[model] = npc
	liveZombieListDirty = true

	humanoid.Died:Connect(function()
		local creator = humanoid:FindFirstChild("creator")
		if creator and creator.Value and creator.Value:IsA("Player") then
			PlayerDataService.addKill(creator.Value)
		end

		removeZombie(npc)
		task.delay(3, function()
			npc:Destroy()
		end)
	end)

	model.Destroying:Connect(function()
		removeZombie(npc)
	end)

	return model
end

local function createLightningWarning(position, radius, warningTime)
	local warning = Instance.new("Part")
	warning.Name = "LightningStrikeWarning"
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanQuery = false
	warning.CanTouch = false
	warning.CastShadow = false
	warning.Color = Color3.fromRGB(255, 42, 42)
	warning.Material = Enum.Material.Neon
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.12, radius * 2, radius * 2)
	warning.Transparency = 0.42
	warning.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Parent = Workspace

	local tween = TweenService:Create(
		warning,
		TweenInfo.new(warningTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{
			Size = Vector3.new(0.16, radius * 2.35, radius * 2.35),
			Transparency = 0.12,
		}
	)
	tween:Play()
	Debris:AddItem(warning, warningTime + 0.1)

	local alertGui = Instance.new("BillboardGui")
	alertGui.Name = "LightningWarningAlert"
	alertGui.AlwaysOnTop = true
	alertGui.LightInfluence = 0
	alertGui.MaxDistance = 180
	alertGui.Size = UDim2.fromOffset(52, 52)
	alertGui.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	alertGui.Parent = warning

	local alertLabel = Instance.new("TextLabel")
	alertLabel.Name = "Alert"
	alertLabel.BackgroundTransparency = 1
	alertLabel.Font = Enum.Font.GothamBlack
	alertLabel.Size = UDim2.fromScale(1, 1)
	alertLabel.Text = "!"
	alertLabel.TextColor3 = Color3.fromRGB(255, 245, 245)
	alertLabel.TextScaled = true
	alertLabel.TextStrokeColor3 = Color3.fromRGB(210, 16, 16)
	alertLabel.TextStrokeTransparency = 0
	alertLabel.Parent = alertGui

	local alertTween = TweenService:Create(
		alertLabel,
		TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			TextColor3 = Color3.fromRGB(255, 45, 45),
			TextStrokeTransparency = 0.18,
		}
	)
	alertTween:Play()

	for index = 1, 3 do
		local ring = Instance.new("Part")
		ring.Name = "LightningWarningRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Color = if index == 1 then Color3.fromRGB(255, 55, 55) else Color3.fromRGB(255, 130, 40)
		ring.Material = Enum.Material.Neon
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.1, radius * 0.45, radius * 0.45)
		ring.Transparency = 0.28
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.11 + (index * 0.015), 0)) * CFrame.Angles(
			0,
			0,
			math.rad(90)
		)
		ring.Parent = Workspace

		local delayTime = (index - 1) * warningTime * 0.18
		task.delay(delayTime, function()
			if not ring.Parent then
				return
			end

			local ringTween = TweenService:Create(
				ring,
				TweenInfo.new(math.max(warningTime - delayTime, 0.1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = Vector3.new(0.12, radius * 2.55, radius * 2.55),
					Transparency = 1,
				}
			)
			ringTween:Play()
			ringTween.Completed:Once(function()
				if ring.Parent then
					ring:Destroy()
				end
			end)
		end)
	end
end

local function createLightningImpact(position, radius)
	bossLightningVfxEvent:FireAllClients(position)
end

local function damageTargetsInRadius(position, radius, damage)
	for _, target in getAliveDamageTargets() do
		local offset = Vector3.new(target.Root.Position.X - position.X, 0, target.Root.Position.Z - position.Z)
		if offset.Magnitude <= radius then
			target.Humanoid:TakeDamage(damage)
		end
	end
end

local function getRandomPlayerRoot()
	local roots = getAlivePlayerRoots()
	if #roots == 0 then
		return nil
	end

	return roots[math.random(1, #roots)]
end

local function getPredictedLightningPositions(config, warningTime)
	local strikeCount = math.random(config.LightningVolleyMin or 3, config.LightningVolleyMax or 5)
	local positions = {}
	local targetRoot = getRandomPlayerRoot()
	if not targetRoot then
		return positions
	end

	local velocity = targetRoot.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local predictionTime = config.LightningPredictionTime or (warningTime + 0.35)
	local predictedPosition = targetRoot.Position
	local forward = Vector3.new(0, 0, -1)
	if flatVelocity.Magnitude > 1 then
		local leadDistance = math.min(flatVelocity.Magnitude * predictionTime, config.LightningMaxPredictionLead or 22)
		forward = flatVelocity.Unit
		predictedPosition += forward * leadDistance
	end

	local right = Vector3.new(-forward.Z, 0, forward.X)
	local spreadRadius = config.LightningScatterRadius or 16
	local minSpacing = config.LightningMinStrikeSpacing or 15
	local maxAttempts = 10

	for index = 1, strikeCount do
		local chosenPosition = nil

		for attempt = 1, maxAttempts do
			local laneOffset = (index - ((strikeCount + 1) * 0.5)) * minSpacing
			local forwardOffset = math.random(-spreadRadius * 60, spreadRadius * 80) / 100
			local sideJitter = math.random(-math.floor(spreadRadius * 45), math.floor(spreadRadius * 45)) / 100
			local candidate = predictedPosition + (right * (laneOffset + sideJitter)) + (forward * forwardOffset)
			local groundPosition = getGroundPositionForEffect(candidate)
			local farEnough = true

			for _, existingPosition in positions do
				local offset = Vector3.new(
					existingPosition.X - groundPosition.X,
					0,
					existingPosition.Z - groundPosition.Z
				)
				if offset.Magnitude < minSpacing then
					farEnough = false
					break
				end
			end

			if farEnough or attempt == maxAttempts then
				chosenPosition = groundPosition
				break
			end
		end

		if chosenPosition then
			table.insert(positions, chosenPosition)
		end
	end

	return positions
end

local function castBossLightning(npc)
	local config = npc.Config.SpecialAttacks
	local radius = config.LightningRadius or 8
	local warningTime = config.LightningWarningTime or 1
	local impactPositions = getPredictedLightningPositions(config, warningTime)
	if #impactPositions == 0 then
		return
	end

	npc._movementLockedUntil = os.clock() + warningTime + 0.35
	if npc.Humanoid then
		npc.Humanoid.WalkSpeed = 0
	end
	if npc._stopWalkAnimation then
		npc:_stopWalkAnimation()
	end
	if npc._playIdleAnimation then
		npc:_playIdleAnimation()
	end

	for _, impactPosition in impactPositions do
		createLightningWarning(impactPosition, radius, warningTime)
	end

	task.delay(warningTime, function()
		if not npc.Model or not npc.Model.Parent or not npc.Humanoid or npc.Humanoid.Health <= 0 then
			return
		end

		for _, impactPosition in impactPositions do
			createLightningImpact(impactPosition, radius)
			damageTargetsInRadius(impactPosition, radius, config.LightningDamage or 30)
		end

		task.delay(0.25, function()
			if npc.Humanoid and npc.Humanoid.Health > 0 and os.clock() >= (npc._movementLockedUntil or 0) then
				npc.Humanoid.WalkSpeed = npc.Config.WalkSpeed
			end
		end)
	end)
end

local function spawnLightningMinion(waveNumber, spawnCFrame)
	if ZombieService.getLiveCount() >= getLiveCap() then
		return nil
	end

	local npc = LightningMinion.new(waveNumber)
	npc:Spawn(spawnCFrame, zombiesFolder)
	return registerZombie(npc)
end

local function summonBossMinions(npc, waveNumber)
	local config = npc.Config.SpecialAttacks
	local count = config.SummonCount or 3
	local rootPosition = npc.Root and npc.Root.Position
	if not rootPosition then
		return
	end

	for index = 1, count do
		spawnLightningMinion(waveNumber, getSpawnCFrameNearPosition(rootPosition, index, 10, 24))
	end
end

local function runBossAbilities(npc, waveNumber)
	task.spawn(function()
		local config = npc.Config.SpecialAttacks
		local nextLightningAt = os.clock() + 1.8
		local nextSummonAt = os.clock() + 4

		while npc.Model and npc.Model.Parent and npc.Humanoid and npc.Humanoid.Health > 0 do
			local now = os.clock()

			if now >= nextLightningAt then
				castBossLightning(npc)
				nextLightningAt = now + (config.LightningCooldown or 3.2)
			end

			if now >= nextSummonAt then
				summonBossMinions(npc, waveNumber)
				nextSummonAt = now + (config.SummonCooldown or 8)
			end

			task.wait(0.2)
		end
	end)
end

getLiveCap = function()
	if GameConfig.StressTestEnabled then
		return GameConfig.StressTestLiveCap
	end

	local playerCount = math.max(#Players:GetPlayers(), 1)
	return math.min(GameConfig.MaxLiveZombies, playerCount * GameConfig.MaxLiveZombiesPerPlayer)
end

local function rebuildLiveZombieList()
	table.clear(liveZombieList)

	for npc in liveZombies do
		local model = npc.Model
		if model and model.Parent then
			table.insert(liveZombieList, npc)
		else
			liveZombies[npc] = nil
		end
	end

	liveZombieListDirty = false
	if updateCursor > #liveZombieList then
		updateCursor = 1
	end
end

local function stepLightweightZombies()
	if not GameConfig.LightweightZombieMovement then
		return
	end

	if liveZombieListDirty then
		rebuildLiveZombieList()
	end

	local liveCount = #liveZombieList
	if liveCount == 0 then
		return
	end

	local now = os.clock()
	local updatesThisFrame = math.min(GameConfig.ZombieUpdatesPerFrame, liveCount)

	for _ = 1, updatesThisFrame do
		local npc = liveZombieList[updateCursor]
		if npc then
			npc:StepLightweight(now, liveZombieList)
		end

		updateCursor += 1
		if updateCursor > liveCount then
			updateCursor = 1
		end
	end
end

function ZombieService.spawnBasicZombie(waveNumber, spawnIndex)
	if ZombieService.getLiveCount() >= getLiveCap() then
		return nil
	end

	local npc = BasicZombie.new(waveNumber)
	npc:Spawn(getSpawnCFrame(spawnIndex), zombiesFolder)
	return registerZombie(npc)
end

local function chooseZombieClass(waveNumber)
	local weightedPool = {}
	local totalWeight = 0

	local function addType(unlockWave, weight, constructor)
		if waveNumber < unlockWave or weight <= 0 then
			return
		end

		totalWeight += weight
		table.insert(weightedPool, {
			Weight = weight,
			Constructor = constructor,
		})
	end

	addType(1, zombieSpawnWeights.BasicZombie or 100, BasicZombie.new)
	addType(3, zombieSpawnWeights.Sprinter or 36, Sprinter.new)
	addType(5, zombieSpawnWeights.Tank or 14, Tank.new)

	if totalWeight <= 0 then
		return BasicZombie.new
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, entry in weightedPool do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.Constructor
		end
	end

	return weightedPool[#weightedPool].Constructor
end

local function spawnZombieFromConstructor(constructor, waveNumber, spawnIndex)
	if ZombieService.getLiveCount() >= getLiveCap() then
		return nil
	end

	local npc = constructor(waveNumber)
	npc:Spawn(getSpawnCFrame(spawnIndex), zombiesFolder)
	return registerZombie(npc)
end

function ZombieService.spawnZombie(waveNumber, spawnIndex)
	local constructor = chooseZombieClass(waveNumber)
	return spawnZombieFromConstructor(constructor, waveNumber, spawnIndex)
end

function ZombieService.spawnLightningBoss(waveNumber)
	if activeBoss and activeBoss.Model and activeBoss.Model.Parent then
		return activeBoss.Model
	end

	local npc = LightningBoss.new(waveNumber)
	npc:Spawn(getSpawnCFrame(1), zombiesFolder)
	local model = registerZombie(npc)
	activeBoss = npc

	if npc.Humanoid then
		sendBossStatus(npc)
		npc.Humanoid.HealthChanged:Connect(function()
			if activeBoss == npc then
				sendBossStatus(npc)
			end
		end)
	end

	runBossAbilities(npc, waveNumber)
	return model
end

function ZombieService.canSpawn()
	return ZombieService.getLiveCount() < getLiveCap()
end

function ZombieService.getLiveCount()
	local count = 0

	for npc in liveZombies do
		local model = npc.Model
		if model and model.Parent then
			count += 1
		else
			liveZombies[npc] = nil
		end
	end

	return count
end

function ZombieService.clearAll()
	local zombiesToDestroy = {}

	for npc in liveZombies do
		table.insert(zombiesToDestroy, npc)
	end

	for _, npc in zombiesToDestroy do
		removeZombie(npc)
		npc:Destroy()
	end

	table.clear(liveZombies)
	table.clear(liveZombieList)
	table.clear(modelToNpc)
	liveZombieListDirty = false
	activeBoss = nil
	Network.bossStatus.sendToAll({
		active = 0,
		name = "",
		health = 0,
		maxHealth = 0,
	})
end

function ZombieService.sendBossStatusTo(player)
	if activeBoss and activeBoss.Humanoid and activeBoss.Humanoid.Health > 0 then
		Network.bossStatus.sendTo({
			active = 1,
			name = activeBoss.Config.DisplayName or "Boss",
			health = math.clamp(math.floor(activeBoss.Humanoid.Health + 0.5), 0, 65535),
			maxHealth = math.clamp(math.floor(activeBoss.Humanoid.MaxHealth + 0.5), 1, 65535),
		}, player)
	else
		Network.bossStatus.sendTo({
			active = 0,
			name = "",
			health = 0,
			maxHealth = 0,
		}, player)
	end
end

function ZombieService.getNpcFromModel(model)
	return modelToNpc[model]
end

function ZombieService.getCandidateFromModel(model)
	local npc = modelToNpc[model]
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")

	if not npc or not npc.Root or not npc.Model or not npc.Model.Parent or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return {
		NPC = npc,
		Humanoid = humanoid,
		Root = npc.Root,
		Health = humanoid.Health,
		MaxHealth = humanoid.MaxHealth,
	}
end

function ZombieService.damageNpc(npc, player, damage)
	if not npc or not npc.Model then
		return false
	end

	local humanoid = npc.Model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local creator = humanoid:FindFirstChild("creator")
	if not creator then
		creator = Instance.new("ObjectValue")
		creator.Name = "creator"
		creator.Parent = humanoid
	end

	creator.Value = player
	game:GetService("Debris"):AddItem(creator, 3)
	humanoid:TakeDamage(damage)

	return true
end

function ZombieService.start()
	RunService.Heartbeat:Connect(stepLightweightZombies)
end

return ZombieService
