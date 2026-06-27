local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local GameplayConfig = require(ReplicatedStorage.GameplayConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local PlayerLifeService = {}
PlayerLifeService.Order = 5

local downedPlayers = {}

local function setDowned(player, isDowned)
	downedPlayers[player] = if isDowned then true else nil
	player:SetAttribute("IsDowned", isDowned)
end

local function bindCharacter(player, character)
	setDowned(player, false)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		if player.Parent == Players then
			setDowned(player, true)
		end
	end)
end

local function loadCharacter(player)
	if player.Parent ~= Players then
		return
	end

	player:LoadCharacter()
end

local function returnPlayersToLobby(playersToReturn)
	if #playersToReturn == 0 then
		return
	end

	local lobbyPlaceId = GameplayConfig.LobbyPlaceId or 0
	if lobbyPlaceId > 0 and not RunService:IsStudio() then
		pcall(function()
			TeleportService:TeleportAsync(lobbyPlaceId, playersToReturn)
		end)
		return
	end

	for _, player in playersToReturn do
		if player.Parent == Players then
			setDowned(player, false)
			loadCharacter(player)
		end
	end
end

function PlayerLifeService.respawnDownedPlayers()
	for player in downedPlayers do
		if player.Parent == Players then
			setDowned(player, false)
			task.defer(loadCharacter, player)
		else
			downedPlayers[player] = nil
		end
	end
end

function PlayerLifeService.returnAllPlayersToLobby()
	local playersToReturn = {}
	for _, player in Players:GetPlayers() do
		table.insert(playersToReturn, player)
	end

	returnPlayersToLobby(playersToReturn)
end

function PlayerLifeService.start()
	Players.CharacterAutoLoads = false

	Network.returnToLobbyRequest.listen(function(_, player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		returnPlayersToLobby({ player })
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("IsDowned", false)
		player.CharacterAdded:Connect(function(character)
			bindCharacter(player, character)
		end)

		task.defer(loadCharacter, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		downedPlayers[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		player:SetAttribute("IsDowned", false)
		player.CharacterAdded:Connect(function(character)
			bindCharacter(player, character)
		end)

		if not player.Character then
			task.defer(loadCharacter, player)
		else
			bindCharacter(player, player.Character)
		end
	end
end

return PlayerLifeService
