local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BasicZombie = require(ServerScriptService.Subclasses.NPCs.BasicZombie)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local ZombieService = {}

local zombiesFolder = Workspace:WaitForChild("Zombies")
local spawnsFolder = Workspace:WaitForChild("ZombieSpawns")

local liveZombies = {}
local liveZombieList = {}
local liveZombieListDirty = false
local modelToNpc = {}
local updateCursor = 1
local recentlyUsedSpawns = {}

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

local function getSpawnExclusions()
	local exclusions = {
		zombiesFolder,
	}

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
	liveZombieListDirty = true
end

local function getLiveCap()
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
	local model = npc:Spawn(getSpawnCFrame(spawnIndex), zombiesFolder)
	local humanoid = model:FindFirstChildOfClass("Humanoid")

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

function ZombieService.spawnZombie(waveNumber, spawnIndex)
	return ZombieService.spawnBasicZombie(waveNumber, spawnIndex)
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
