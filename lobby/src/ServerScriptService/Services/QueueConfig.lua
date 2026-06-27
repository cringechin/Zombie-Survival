local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("LobbyConfig"))

local QueueConfig = {}

local SETTINGS_BY_TYPE = {
	boolean = {
		InstantTeleportWhenFull = true,
	},
	number = {
		GameplayPlaceId = true,
		MaximumPlayers = true,
		MinimumPlayers = true,
		CreationTime = true,
		CountdownTime = true,
		CountdownScalePerPlayer = true,
		FullQueueSpeedMultiplier = true,
	},
}

local function readSetting(room, key, defaultValue)
	local attributeValue = room:GetAttribute(key)

	if attributeValue ~= nil then
		return attributeValue
	end

	local settingsFolder = room:FindFirstChild("Settings")
	local valueObject = settingsFolder and settingsFolder:FindFirstChild(key)

	if valueObject and valueObject:IsA("ValueBase") then
		return valueObject.Value
	end

	return defaultValue
end

function QueueConfig.forRoom(room)
	local config = {}

	for key in SETTINGS_BY_TYPE.number do
		config[key] = tonumber(readSetting(room, key, LobbyConfig[key])) or LobbyConfig[key]
	end

	for key in SETTINGS_BY_TYPE.boolean do
		config[key] = readSetting(room, key, LobbyConfig[key]) == true
	end

	config.MaximumPlayers = math.max(1, math.floor(config.MaximumPlayers))
	config.MinimumPlayers = math.clamp(math.floor(config.MinimumPlayers), 1, config.MaximumPlayers)
	config.CreationTime = math.max(1, math.floor(config.CreationTime))
	config.CountdownTime = math.max(1, math.floor(config.CountdownTime))
	config.CountdownScalePerPlayer = math.max(0, config.CountdownScalePerPlayer)
	config.FullQueueSpeedMultiplier = math.max(0.01, config.FullQueueSpeedMultiplier)

	return config
end

return QueueConfig
