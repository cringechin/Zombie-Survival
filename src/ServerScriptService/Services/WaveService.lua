local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local WaveStatus = require(ReplicatedStorage.Shared.Network.WaveStatus)
local ZombieService = require(ServerScriptService.Services.ZombieService)

local WaveService = {}

local LIGHTNING_BOSS_WAVE = 3
local currentWave = 0
local lastWaveStatus = {
	wave = 1,
	status = WaveStatus.Intermission,
	seconds = GameConfig.IntermissionSeconds,
}
local running = false
local requestedWave = nil

local ADMIN_COMMANDS = {
	["!wave3"] = 3,
	["/wave3"] = 3,
	["!skipwave3"] = 3,
	["/skipwave3"] = 3,
}

local function sendWaveStatus(data)
	lastWaveStatus = data
	Network.waveStatus.sendToAll(data)
end

local function setCurrentWave(waveNumber)
	currentWave = waveNumber

	for _, player in Players:GetPlayers() do
		PlayerDataService.setWave(player, waveNumber)
	end

	sendWaveStatus({
		wave = waveNumber,
		status = WaveStatus.Started,
		seconds = 0,
	})
end

local function isAdmin(player)
	if RunService:IsStudio() then
		return true
	end

	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function requestWave(waveNumber)
	requestedWave = math.max(math.floor(waveNumber), 1)
	ZombieService.clearAll()
end

local function consumeRequestedWave()
	local waveNumber = requestedWave
	requestedWave = nil
	return waveNumber
end

local function bindAdminCommands(player)
	player.Chatted:Connect(function(message)
		if not isAdmin(player) then
			return
		end

		local command = string.lower(string.gsub(message, "%s+", ""))
		local waveNumber = ADMIN_COMMANDS[command]
		if not waveNumber then
			local lowerMessage = string.lower(message)
			waveNumber = string.match(lowerMessage, "^[!/]wave%s+(%d+)$")
				or string.match(lowerMessage, "^[!/]skipwave%s+(%d+)$")
			waveNumber = waveNumber and tonumber(waveNumber) or nil
		end

		if waveNumber then
			requestWave(waveNumber)
		end
	end)
end

local function getWaveSize(waveNumber)
	if GameConfig.StressTestEnabled then
		return GameConfig.StressTestZombieCount
	end

	local waveMultiplier = GameConfig.WaveSizeMultiplier or 2
	return math.max(1, math.floor(GameConfig.StartingWaveSize * (waveMultiplier ^ (waveNumber - 1))))
end

local function getSpawnGroupSize(remainingZombies)
	if GameConfig.StressTestEnabled then
		return math.min(GameConfig.StressTestSpawnGroupSize, remainingZombies)
	end

	local minGroupSize = GameConfig.MinSpawnGroupSize or 1
	local maxGroupSize = GameConfig.MaxSpawnGroupSize or minGroupSize
	local groupSize = math.random(minGroupSize, maxGroupSize)

	return math.min(groupSize, remainingZombies)
end

local function getSpawnGroupDelay()
	if GameConfig.StressTestEnabled then
		return GameConfig.StressTestTimeBetweenSpawnGroups
	end

	return GameConfig.TimeBetweenSpawnGroups
end

local function run()
	while running do
		for secondsRemaining = GameConfig.IntermissionSeconds, 1, -1 do
			if requestedWave then
				break
			end

			sendWaveStatus({
				wave = currentWave + 1,
				status = WaveStatus.Intermission,
				seconds = secondsRemaining,
			})

			task.wait(1)
		end

		local nextWave = consumeRequestedWave() or (currentWave + 1)
		setCurrentWave(nextWave)

		if currentWave == LIGHTNING_BOSS_WAVE then
			ZombieService.spawnLightningBoss(currentWave)
		else
			local zombiesToSpawn = getWaveSize(currentWave)
			local spawned = 0

			while spawned < zombiesToSpawn and running and not requestedWave do
				if not ZombieService.canSpawn() then
					task.wait(getSpawnGroupDelay())
					continue
				end

				local groupSize = getSpawnGroupSize(zombiesToSpawn - spawned)
				local spawnedThisGroup = 0

				while
					spawnedThisGroup < groupSize
					and spawned < zombiesToSpawn
					and ZombieService.canSpawn()
					and not requestedWave
				do
					spawned += 1
					spawnedThisGroup += 1
					ZombieService.spawnZombie(currentWave, spawned)
				end

				task.wait(getSpawnGroupDelay())
			end
		end

		while ZombieService.getLiveCount() > 0 and running and not requestedWave do
			task.wait(1)
		end

		sendWaveStatus({
			wave = currentWave,
			status = WaveStatus.Ended,
			seconds = 0,
		})
	end
end

function WaveService.start()
	if running then
		return
	end

	running = true
	Players.PlayerAdded:Connect(function(player)
		bindAdminCommands(player)
		task.delay(0.5, function()
			if player.Parent == Players then
				Network.waveStatus.sendTo(lastWaveStatus, player)
				ZombieService.sendBossStatusTo(player)
			end
		end)
	end)

	for _, player in Players:GetPlayers() do
		bindAdminCommands(player)
	end

	task.spawn(run)
end

return WaveService
