local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Shared.Network.Packets)
local PlayerDataSchema = require(ServerScriptService.Data.PlayerDataSchema)
local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

local PlayerDataService = {}
PlayerDataService.Order = 5

local METEOR_COST = 150
local TORNADO_COST = 300
local LOADOUT_LIMIT = 3
local DISASTER_COSTS = {
	Meteor = METEOR_COST,
	Tornado = TORNADO_COST,
}

local playerStore = ProfileStore.New(PlayerDataSchema.StoreName, PlayerDataSchema.Template)
local profiles = {}

local function getProfileKey(player)
	return `Player_{player.UserId}`
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

local function clampSlot(slot)
	if type(slot) ~= "number" then
		return 1
	end

	return math.clamp(math.floor(slot), 1, LOADOUT_LIMIT)
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

local function sendStoreState(player)
	local profile = profiles[player]
	if not profile then
		return
	end

	normalizeProfile(profile)

	Network.storeState.sendTo({
		coins = profile.Data.Currency.Coins,
		meteorUnlocked = profile.Data.Weapons.Meteor,
		meteorEquipped = tableIncludes(profile.Data.DisasterLoadout, "Meteor"),
		meteorCost = METEOR_COST,
		tornadoUnlocked = profile.Data.Weapons.Tornado,
		tornadoEquipped = tableIncludes(profile.Data.DisasterLoadout, "Tornado"),
		tornadoCost = TORNADO_COST,
		loadoutSlot1 = profile.Data.DisasterLoadout[1],
		loadoutSlot2 = profile.Data.DisasterLoadout[2],
		loadoutSlot3 = profile.Data.DisasterLoadout[3],
	}, player)
end

local function equipWeaponInSlot(profile, weaponName, slot)
	normalizeProfile(profile)

	if not profile.Data.Weapons[weaponName] then
		return false
	end

	local loadout = profile.Data.DisasterLoadout
	local targetSlot = clampSlot(slot)
	removeFromLoadout(loadout, weaponName)
	loadout[targetSlot] = weaponName
	return true
end

local function loadProfile(player)
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

		if player.Parent == Players then
			player:Kick("Profile session ended. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	sendStoreState(player)
end

local function handleDisasterPurchaseRequest(data, player)
	local profile = profiles[player]
	if not profile or typeof(data) ~= "table" or type(data.weapon) ~= "string" then
		return
	end

	local weaponName = data.weapon
	local cost = DISASTER_COSTS[weaponName]
	if not cost then
		return
	end

	normalizeProfile(profile)
	local requestedSlot = clampSlot(data and data.slot)

	if not profile.Data.Weapons[weaponName] then
		if profile.Data.Currency.Coins < cost then
			sendStoreState(player)
			return
		end

		profile.Data.Currency.Coins -= cost
		profile.Data.Weapons[weaponName] = true
	end

	equipWeaponInSlot(profile, weaponName, requestedSlot)
	sendStoreState(player)
end

local function handleDisasterEquipRequest(data, player)
	local profile = profiles[player]
	if not profile or typeof(data) ~= "table" or type(data.weapon) ~= "string" then
		return
	end

	equipWeaponInSlot(profile, data.weapon, data.slot)
	sendStoreState(player)
end

function PlayerDataService.hasEquippedDisaster(player)
	local profile = profiles[player]
	if not profile then
		return false
	end

	normalizeProfile(profile)
	return hasAnyEquippedDisaster(profile.Data.DisasterLoadout)
end

function PlayerDataService.start()
	Network.meteorStoreRequest.listen(function(data, player)
		handleDisasterPurchaseRequest({
			weapon = "Meteor",
			slot = data and data.slot or 1,
		}, player)
	end)

	Network.disasterPurchaseRequest.listen(function(data, player)
		handleDisasterPurchaseRequest(data, player)
	end)

	Network.disasterEquipRequest.listen(function(data, player)
		handleDisasterEquipRequest(data, player)
	end)

	Network.storeStateRequest.listen(function(_, player)
		sendStoreState(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end

		profiles[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

return PlayerDataService
