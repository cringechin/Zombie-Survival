local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local PlayerDataSchema = require(ServerScriptService.Data.PlayerDataSchema)
local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

local PlayerDataService = {}

local playerStore = ProfileStore.New(PlayerDataSchema.StoreName, PlayerDataSchema.Template)
local profiles = {}
local currentWaves = {}
local runData = {}

local function getProfileKey(player)
	return `Player_{player.UserId}`
end

local function getOrCreateInt(parent, name)
	local value = parent:FindFirstChild(name)
	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Parent = parent
	end

	return value
end

local function getLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	return leaderstats
end

local function getRunData(player)
	local data = runData[player]
	if not data then
		local lightningLevel = if GameConfig.StressTestEnabled and GameConfig.StressTestMaxLightning
			then DisasterWeaponConfig.Lightning.MaxUpgradeLevel
			else 0

		data = {
			Upgrades = {
				LightningLevel = lightningLevel,
			},
			UnlockedWeapons = {
				Lightning = true,
			},
		}
		runData[player] = data
	end

	return data
end

local function syncLeaderstats(player)
	local leaderstats = getLeaderstats(player)
	local profile = profiles[player]
	local stats = profile and profile.Data.Stats
	local runtime = getRunData(player)

	getOrCreateInt(leaderstats, GameConfig.LeaderstatNames.Wave).Value = currentWaves[player] or 0
	getOrCreateInt(leaderstats, GameConfig.LeaderstatNames.Kills).Value = stats and stats.Kills or 0
	getOrCreateInt(leaderstats, GameConfig.LeaderstatNames.BestWave).Value = stats and stats.BestWave or 0
	getOrCreateInt(leaderstats, GameConfig.LeaderstatNames.Coins).Value = profile and profile.Data.Currency.Coins or 0

	player:SetAttribute("LightningLevel", runtime.Upgrades.LightningLevel)
end

local function loadProfile(player)
	getRunData(player)
	getLeaderstats(player)
	syncLeaderstats(player)

	local profile = playerStore:StartSessionAsync(getProfileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Profile failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		currentWaves[player] = nil
		runData[player] = nil

		if player.Parent == Players then
			player:Kick("Profile session ended. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	profile.Data.Currency.Coins = 0
	syncLeaderstats(player)
end

function PlayerDataService.addKill(player)
	local profile = profiles[player]
	if not profile then
		return
	end

	profile.Data.Stats.Kills += 1
	profile.Data.Currency.Coins += 10
	syncLeaderstats(player)
end

function PlayerDataService.getCoins(player)
	local profile = profiles[player]
	return profile and profile.Data.Currency.Coins or 0
end

function PlayerDataService.spendCoins(player, amount)
	local profile = profiles[player]
	if not profile or profile.Data.Currency.Coins < amount then
		return false
	end

	profile.Data.Currency.Coins -= amount
	syncLeaderstats(player)

	return true
end

function PlayerDataService.getLightningLevel(player)
	return getRunData(player).Upgrades.LightningLevel
end

function PlayerDataService.setLightningLevel(player, level)
	local runtime = getRunData(player)
	runtime.Upgrades.LightningLevel = level
	syncLeaderstats(player)

	return true
end

function PlayerDataService.resetRunData(player)
	runData[player] = nil
	getRunData(player)
	syncLeaderstats(player)
end

function PlayerDataService.setWave(player, waveNumber)
	currentWaves[player] = waveNumber

	local profile = profiles[player]
	if profile and waveNumber > profile.Data.Stats.BestWave then
		profile.Data.Stats.BestWave = waveNumber
	end

	syncLeaderstats(player)
end

function PlayerDataService.getProfile(player)
	return profiles[player]
end

function PlayerDataService.endSession(player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end

	profiles[player] = nil
	currentWaves[player] = nil
	runData[player] = nil
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.endSession(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

return PlayerDataService
