local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local PlayerDataSchema = require(ServerScriptService.Data.PlayerDataSchema)
local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

local PlayerDataService = {}
PlayerDataService.Order = 10

local playerStore = ProfileStore.New(PlayerDataSchema.StoreName, PlayerDataSchema.Template)
local profiles = {}
local currentWaves = {}
local runData = {}

local LOADOUT_LIMIT = 3

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

local function tableIncludes(list, value)
	for index = 1, LOADOUT_LIMIT do
		if list[index] == value then
			return true
		end
	end

	return false
end

local function removeFromLoadout(loadout, weaponName)
	for index = 1, LOADOUT_LIMIT do
		if loadout[index] == weaponName then
			loadout[index] = ""
		end
	end
end

local function hasAnyEquippedDisaster(loadout)
	for index = 1, LOADOUT_LIMIT do
		if type(loadout[index]) == "string" and loadout[index] ~= "" then
			return true
		end
	end

	return false
end

local function equipWeaponInFirstOpenSlot(loadout, weaponName)
	if tableIncludes(loadout, weaponName) then
		return
	end

	for index = 1, LOADOUT_LIMIT do
		if loadout[index] == "" then
			loadout[index] = weaponName
			return
		end
	end
end

local function applyGameplayTestWeaponOverrides(data)
	if not GameConfig.TestUnlockTornado then
		return
	end

	data.UnlockedWeapons.Tornado = true
	equipWeaponInFirstOpenSlot(data.DisasterLoadout, "Tornado")
end

local function normalizeProfile(profile)
	local data = profile.Data
	data.Stats = data.Stats or { Kills = 0, BestWave = 0 }
	data.Currency = data.Currency or { Coins = 0 }
	data.Weapons = data.Weapons or {}
	data.Weapons.Lightning = true
	data.Weapons.Meteor = data.Weapons.Meteor == true
	data.Weapons.Tornado = data.Weapons.Tornado == true
	local savedLoadout = data.DisasterLoadout or { "Lightning" }
	local normalizedLoadout = {}
	local usedWeapons = {}

	for index = 1, LOADOUT_LIMIT do
		local weaponName = savedLoadout[index]
		if type(weaponName) ~= "string" then
			weaponName = ""
		end

		if weaponName ~= "" and (not data.Weapons[weaponName] or usedWeapons[weaponName]) then
			weaponName = ""
		end

		normalizedLoadout[index] = weaponName
		if weaponName ~= "" then
			usedWeapons[weaponName] = true
		end
	end

	data.DisasterLoadout = normalizedLoadout

	if not hasAnyEquippedDisaster(data.DisasterLoadout) then
		data.DisasterLoadout[1] = "Lightning"
	end
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
				MeteorLevel = 0,
				TornadoLevel = 0,
			},
			UnlockedWeapons = {
				Lightning = true,
				Meteor = false,
				Tornado = false,
			},
			DisasterLoadout = {
				"Lightning",
				"",
				"",
			},
			Defenses = {
				LightningTurretsPlaced = 0,
			},
			SessionStats = {
				Kills = 0,
				CoinsEarned = 0,
				Coins = GameConfig.StartingCoins or 0,
				CreditsEarned = 0,
				CreditsSettled = false,
			},
		}
		runData[player] = data
	end

	data.Upgrades = data.Upgrades or {}
	data.Upgrades.LightningLevel = data.Upgrades.LightningLevel or 0
	data.Upgrades.MeteorLevel = data.Upgrades.MeteorLevel or 0
	data.Upgrades.TornadoLevel = data.Upgrades.TornadoLevel or 0
	data.UnlockedWeapons = data.UnlockedWeapons or { Lightning = true }
	data.UnlockedWeapons.Lightning = true
	data.UnlockedWeapons.Meteor = data.UnlockedWeapons.Meteor == true
	data.UnlockedWeapons.Tornado = data.UnlockedWeapons.Tornado == true
	data.DisasterLoadout = data.DisasterLoadout or { "Lightning" }
	for index = 1, LOADOUT_LIMIT do
		data.DisasterLoadout[index] = data.DisasterLoadout[index] or ""
	end
	data.Defenses = data.Defenses or {}
	data.Defenses.LightningTurretsPlaced = data.Defenses.LightningTurretsPlaced or 0
	data.SessionStats = data.SessionStats or {}
	data.SessionStats.Kills = data.SessionStats.Kills or 0
	data.SessionStats.CoinsEarned = data.SessionStats.CoinsEarned or 0
	data.SessionStats.Coins = data.SessionStats.Coins or GameConfig.StartingCoins or 0
	data.SessionStats.CreditsEarned = data.SessionStats.CreditsEarned
		or (data.SessionStats.Kills * (GameConfig.CreditsPerZombieKill or 3))
	data.SessionStats.CreditsSettled = data.SessionStats.CreditsSettled == true
	applyGameplayTestWeaponOverrides(data)
	if data.UnlockedWeapons.Tornado and tableIncludes(data.DisasterLoadout, "Tornado") and data.Upgrades.TornadoLevel <= 0 then
		data.Upgrades.TornadoLevel = 1
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
	getOrCreateInt(leaderstats, GameConfig.LeaderstatNames.Coins).Value = runtime.SessionStats.Coins

	local turretConfig = GameConfig.Defenses and GameConfig.Defenses.LightningTurret
	local turretBaseCost = turretConfig and turretConfig.Cost or 0
	local turretCostIncrease = turretConfig and turretConfig.CostIncreasePerTower or 0
	local placedTurrets = runtime.Defenses.LightningTurretsPlaced

	player:SetAttribute("LightningLevel", runtime.Upgrades.LightningLevel)
	player:SetAttribute("MeteorLevel", runtime.Upgrades.MeteorLevel)
	player:SetAttribute("TornadoLevel", runtime.Upgrades.TornadoLevel)
	player:SetAttribute("MeteorUnlocked", runtime.UnlockedWeapons.Meteor)
	player:SetAttribute("TornadoUnlocked", runtime.UnlockedWeapons.Tornado)
	player:SetAttribute("LightningEquipped", tableIncludes(runtime.DisasterLoadout, "Lightning"))
	player:SetAttribute("MeteorEquipped", tableIncludes(runtime.DisasterLoadout, "Meteor"))
	player:SetAttribute("TornadoEquipped", tableIncludes(runtime.DisasterLoadout, "Tornado"))
	for index = 1, LOADOUT_LIMIT do
		player:SetAttribute(`DisasterLoadoutSlot{index}`, runtime.DisasterLoadout[index] or "")
	end
	player:SetAttribute("LightningTurretCount", placedTurrets)
	player:SetAttribute("LightningTurretNextCost", turretBaseCost + (placedTurrets * turretCostIncrease))
	player:SetAttribute("RunKills", runtime.SessionStats.Kills)
	player:SetAttribute("RunCoinsEarned", runtime.SessionStats.CoinsEarned)
	player:SetAttribute("RunCreditsEarned", runtime.SessionStats.CreditsEarned)
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
	normalizeProfile(profile)

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

	local runtime = getRunData(player)
	runtime.UnlockedWeapons.Meteor = profile.Data.Weapons.Meteor
	runtime.UnlockedWeapons.Tornado = profile.Data.Weapons.Tornado
	runtime.DisasterLoadout = table.clone(profile.Data.DisasterLoadout)
	runtime.Upgrades.MeteorLevel = if profile.Data.Weapons.Meteor and tableIncludes(profile.Data.DisasterLoadout, "Meteor") then 1 else 0
	runtime.Upgrades.TornadoLevel = if profile.Data.Weapons.Tornado and tableIncludes(profile.Data.DisasterLoadout, "Tornado") then 1 else 0
	syncLeaderstats(player)
end

function PlayerDataService.addKill(player)
	local profile = profiles[player]
	if not profile then
		return
	end

	local runtime = getRunData(player)
	runtime.SessionStats.Kills += 1
	runtime.SessionStats.CoinsEarned += 10
	runtime.SessionStats.Coins += 10
	runtime.SessionStats.CreditsEarned = runtime.SessionStats.Kills * (GameConfig.CreditsPerZombieKill or 3)
	profile.Data.Stats.Kills += 1
	syncLeaderstats(player)
end

function PlayerDataService.getCoins(player)
	return getRunData(player).SessionStats.Coins
end

function PlayerDataService.spendCoins(player, amount)
	local runtime = getRunData(player)
	if runtime.SessionStats.Coins < amount then
		return false
	end

	runtime.SessionStats.Coins -= amount
	syncLeaderstats(player)

	return true
end

function PlayerDataService.settleRunCredits(player)
	local profile = profiles[player]
	local runtime = getRunData(player)
	if not profile or runtime.SessionStats.CreditsSettled then
		return 0
	end

	local credits = math.max(math.floor((runtime.SessionStats.Kills or 0) * (GameConfig.CreditsPerZombieKill or 3)), 0)

	runtime.SessionStats.CreditsEarned = credits
	runtime.SessionStats.CreditsSettled = true
	profile.Data.Currency.Coins += credits
	syncLeaderstats(player)

	return credits
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

function PlayerDataService.getMeteorLevel(player)
	return getRunData(player).Upgrades.MeteorLevel
end

function PlayerDataService.setMeteorLevel(player, level)
	local runtime = getRunData(player)
	runtime.Upgrades.MeteorLevel = level
	syncLeaderstats(player)

	return true
end

function PlayerDataService.getTornadoLevel(player)
	return getRunData(player).Upgrades.TornadoLevel
end

function PlayerDataService.setTornadoLevel(player, level)
	local runtime = getRunData(player)
	runtime.Upgrades.TornadoLevel = level
	syncLeaderstats(player)

	return true
end

function PlayerDataService.hasUnlockedWeapon(player, weaponName)
	return getRunData(player).UnlockedWeapons[weaponName] == true
end

function PlayerDataService.hasEquippedWeapon(player, weaponName)
	return tableIncludes(getRunData(player).DisasterLoadout, weaponName)
end

function PlayerDataService.getLightningTurretsPlaced(player)
	return getRunData(player).Defenses.LightningTurretsPlaced
end

function PlayerDataService.getLightningTurretCost(player)
	local turretConfig = GameConfig.Defenses and GameConfig.Defenses.LightningTurret
	local baseCost = turretConfig and turretConfig.Cost or 0
	local costIncrease = turretConfig and turretConfig.CostIncreasePerTower or 0
	return baseCost + (PlayerDataService.getLightningTurretsPlaced(player) * costIncrease)
end

function PlayerDataService.incrementLightningTurretsPlaced(player)
	local runtime = getRunData(player)
	runtime.Defenses.LightningTurretsPlaced += 1
	syncLeaderstats(player)

	return runtime.Defenses.LightningTurretsPlaced
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
