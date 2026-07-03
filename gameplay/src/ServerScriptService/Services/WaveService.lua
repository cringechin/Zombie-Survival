local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerLifeService = require(ServerScriptService.Services.PlayerLifeService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local WaveStatus = require(ReplicatedStorage.Shared.Network.WaveStatus)
local ZombieService = require(ServerScriptService.Services.ZombieService)

local WaveService = {}
WaveService.Order = 60

local TOTAL_WAVES = GameConfig.TotalWaves or 8
local BOSS_WAVE = GameConfig.BossWave or TOTAL_WAVES
local currentWave = 0
local lastWaveStatus = {
	wave = 1,
	status = WaveStatus.Intermission,
	seconds = GameConfig.IntermissionSeconds,
	zombiesRemaining = 0,
	zombiesTotal = 0,
	zombiesAlive = 0,
}
local running = false
local requestedWave = nil
local victoryTriggered = false

local ADMIN_COMMANDS = {
	["!wave3"] = 3,
	["/wave3"] = 3,
	["!skipwave3"] = 3,
	["/skipwave3"] = 3,
	["!wave8"] = 8,
	["/wave8"] = 8,
	["!skipwave8"] = 8,
	["/skipwave8"] = 8,
}

local function sendWaveStatus(data)
	data.zombiesRemaining = data.zombiesRemaining or 0
	data.zombiesTotal = data.zombiesTotal or 0
	data.zombiesAlive = data.zombiesAlive or ZombieService.getLiveCount()
	lastWaveStatus = data
	Network.waveStatus.sendToAll(data)
end

local function sendNotification(title, body, tone)
	Network.gameNotification.sendToAll({
		title = title,
		body = body,
		tone = tone or "info",
	})
end

local function getRunDurationSeconds()
	local runStartedAt = workspace:GetAttribute("RunStartedAt")
	local now = workspace:GetServerTimeNow()
	if typeof(runStartedAt) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(now - runStartedAt))
end

local function setVictoryState(active, returnAt)
	workspace:SetAttribute("VictoryActive", active)
	workspace:SetAttribute("VictoryWave", if active then currentWave else 0)
	workspace:SetAttribute("VictoryDuration", if active then getRunDurationSeconds() else 0)
	workspace:SetAttribute("VictoryReturnAt", if active then (returnAt or 0) else 0)
end

local function finishRunVictory()
	if victoryTriggered then
		return
	end

	victoryTriggered = true
	running = false
	local returnDelay = GameConfig.VictoryReturnDelay or 15
	local returnAt = workspace:GetServerTimeNow() + returnDelay
	setVictoryState(true, returnAt)
	sendNotification("VICTORY", "Storm Bringer defeated. Returning to lobby soon.", "success")

	task.delay(returnDelay, function()
		if #Players:GetPlayers() > 0 then
			setVictoryState(false, 0)
			PlayerLifeService.returnAllPlayersToLobby()
		end
	end)
end

local function setCurrentWave(waveNumber)
	currentWave = waveNumber
	if not PlayerLifeService.shouldHoldWaveStartForSoloDowned() then
		PlayerLifeService.respawnDownedPlayers()
	end

	for _, player in Players:GetPlayers() do
		PlayerDataService.setWave(player, waveNumber)
	end

	sendWaveStatus({
		wave = waveNumber,
		status = WaveStatus.Started,
		seconds = 0,
		zombiesRemaining = 0,
		zombiesTotal = 0,
		zombiesAlive = 0,
	})
end

local function waitForSoloReviveBeforeWaveStart(waveNumber)
	local notified = false

	while running and not requestedWave and PlayerLifeService.shouldHoldWaveStartForSoloDowned() do
		if not notified then
			notified = true
			sendNotification("REVIVE REQUIRED", "Revive before the next wave starts.", "danger")
		end

		sendWaveStatus({
			wave = waveNumber,
			status = WaveStatus.Intermission,
			seconds = 0,
			zombiesRemaining = 0,
			zombiesTotal = 0,
			zombiesAlive = 0,
		})

		task.wait(1)
	end
end

local function isAdmin(player)
	if RunService:IsStudio() then
		return true
	end

	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function requestWave(waveNumber)
	requestedWave = math.clamp(math.floor(waveNumber), 1, TOTAL_WAVES)
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

local function getSpawnInGroupDelay()
	if GameConfig.StressTestEnabled then
		return 0
	end

	return GameConfig.TimeBetweenZombiesInGroup or 0
end

local function run()
	while running do
		if currentWave >= TOTAL_WAVES then
			finishRunVictory()
			break
		end

		for secondsRemaining = GameConfig.IntermissionSeconds, 1, -1 do
			if requestedWave then
				break
			end

			if secondsRemaining == GameConfig.IntermissionSeconds then
				sendNotification(
					`WAVE {currentWave + 1}/{TOTAL_WAVES}`,
					if currentWave + 1 == BOSS_WAVE then "Final boss incoming. Get ready." else "Prepare defenses.",
					if currentWave + 1 == BOSS_WAVE then "danger" else "info"
				)
			end

			sendWaveStatus({
				wave = currentWave + 1,
				status = WaveStatus.Intermission,
				seconds = secondsRemaining,
				zombiesRemaining = 0,
				zombiesTotal = 0,
				zombiesAlive = 0,
			})

			task.wait(1)
		end

		waitForSoloReviveBeforeWaveStart(currentWave + 1)

		local nextWave = consumeRequestedWave() or (currentWave + 1)
		setCurrentWave(nextWave)
		sendNotification(
			`WAVE {currentWave}/{TOTAL_WAVES}`,
			if currentWave == BOSS_WAVE then "Storm Bringer has entered the arena." else "Zombies are breaching the perimeter.",
			if currentWave == BOSS_WAVE then "boss" else "wave"
		)

		if currentWave == BOSS_WAVE then
			sendWaveStatus({
				wave = currentWave,
				status = WaveStatus.Started,
				seconds = 0,
				zombiesRemaining = 0,
				zombiesTotal = 0,
				zombiesAlive = 1,
			})
			ZombieService.spawnLightningBoss(currentWave)
		else
			local zombiesToSpawn = getWaveSize(currentWave)
			local spawned = 0
			sendWaveStatus({
				wave = currentWave,
				status = WaveStatus.Started,
				seconds = 0,
				zombiesRemaining = zombiesToSpawn,
				zombiesTotal = zombiesToSpawn,
				zombiesAlive = ZombieService.getLiveCount(),
			})

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

					if spawnedThisGroup < groupSize then
						task.wait(getSpawnInGroupDelay())
					end
				end
				sendWaveStatus({
					wave = currentWave,
					status = WaveStatus.Started,
					seconds = 0,
					zombiesRemaining = math.max(zombiesToSpawn - spawned, 0),
					zombiesTotal = zombiesToSpawn,
					zombiesAlive = ZombieService.getLiveCount(),
				})

				task.wait(getSpawnGroupDelay())
			end
		end

		while ZombieService.getLiveCount() > 0 and running and not requestedWave do
			sendWaveStatus({
				wave = currentWave,
				status = WaveStatus.Started,
				seconds = 0,
				zombiesRemaining = 0,
				zombiesTotal = 0,
				zombiesAlive = ZombieService.getLiveCount(),
			})
			task.wait(1)
		end

		sendWaveStatus({
			wave = currentWave,
			status = WaveStatus.Ended,
			seconds = 0,
			zombiesRemaining = 0,
			zombiesTotal = 0,
			zombiesAlive = 0,
		})

		if currentWave == BOSS_WAVE then
			sendNotification("BOSS DEFEATED", "Storm Bringer is down. Mission complete.", "success")
			finishRunVictory()
			break
		else
			sendNotification(`WAVE {currentWave} CLEARED`, "Regroup before the next push.", "success")
		end
	end
end

function WaveService.start()
	if running then
		return
	end

	running = true
	victoryTriggered = false
	setVictoryState(false, 0)
	workspace:SetAttribute("RunStartedAt", workspace:GetServerTimeNow())
	workspace:SetAttribute("TotalWaves", TOTAL_WAVES)
	workspace:SetAttribute("BossWave", BOSS_WAVE)
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
