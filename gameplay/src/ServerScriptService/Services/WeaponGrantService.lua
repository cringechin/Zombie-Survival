local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local WeaponGrantService = {}
WeaponGrantService.Order = 40

local DISASTER_WEAPONS = {
	"Lightning",
	"Meteor",
	"Tornado",
}

local watchedPlayers = {}

local function hasTool(container, toolName)
	local tool = container and container:FindFirstChild(toolName)
	return tool and tool:IsA("Tool")
end

local function cleanupDuplicateTools(player, toolName)
	local containers = {
		player.Character,
		player:FindFirstChildOfClass("Backpack"),
		player:FindFirstChild("StarterGear"),
	}
	local keptTool = nil

	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child.Name == toolName then
					if keptTool then
						child:Destroy()
					else
						keptTool = child
					end
				end
			end
		end
	end

	return keptTool
end

local function grantTool(player, toolName, slotIndex)
	local weaponTemplates = ServerStorage:FindFirstChild("WeaponTemplates")
	local template = StarterPack:FindFirstChild(toolName) or (weaponTemplates and weaponTemplates:FindFirstChild(toolName))
	if not template or not template:IsA("Tool") then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local existingTool = cleanupDuplicateTools(player, toolName)

	if existingTool then
		existingTool:SetAttribute("LoadoutSlot", slotIndex or 0)
		return
	end

	if backpack and not hasTool(backpack, toolName) and not hasTool(character, toolName) then
		local clone = template:Clone()
		clone:SetAttribute("LoadoutSlot", slotIndex or 0)
		clone.Parent = backpack
	end
end

local function removeTool(player, toolName)
	local containers = {
		player.Character,
		player:FindFirstChildOfClass("Backpack"),
		player:FindFirstChild("StarterGear"),
	}

	for _, container in containers do
		if not container then
			continue
		end

		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child.Name == toolName then
				child:Destroy()
			end
		end
	end
end

local function getLoadoutSlot(player, toolName)
	for index = 1, 3 do
		if player:GetAttribute(`DisasterLoadoutSlot{index}`) == toolName then
			return index
		end
	end

	return nil
end

function WeaponGrantService.grantWeapon(player, toolName)
	grantTool(player, toolName, getLoadoutSlot(player, toolName) or 0)
end

local function grantStartingWeapons(player)
	for _, toolName in DISASTER_WEAPONS do
		local slotIndex = getLoadoutSlot(player, toolName)
		if slotIndex then
			grantTool(player, toolName, slotIndex)
		else
			removeTool(player, toolName)
		end
	end
end

local function watchPlayer(player)
	if watchedPlayers[player] then
		return
	end

	watchedPlayers[player] = true

	player.CharacterAdded:Connect(function()
		task.delay(0.25, grantStartingWeapons, player)
	end)

	for index = 1, 3 do
		player:GetAttributeChangedSignal(`DisasterLoadoutSlot{index}`):Connect(function()
			grantStartingWeapons(player)
		end)
	end

	task.delay(0.25, grantStartingWeapons, player)
end

function WeaponGrantService.start()
	Players.PlayerAdded:Connect(function(player)
		watchPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		watchedPlayers[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return WeaponGrantService
