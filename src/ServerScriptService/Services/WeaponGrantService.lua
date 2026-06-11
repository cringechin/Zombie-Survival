local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local WeaponGrantService = {}

local STARTING_WEAPONS = {
	"Lightning",
}

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

	return keptTool ~= nil
end

local function grantTool(player, toolName)
	local template = StarterPack:FindFirstChild(toolName)
	if not template or not template:IsA("Tool") then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	if cleanupDuplicateTools(player, toolName) then
		return
	end

	if backpack and not hasTool(backpack, toolName) and not hasTool(character, toolName) then
		template:Clone().Parent = backpack
	end
end

local function grantStartingWeapons(player)
	for _, toolName in STARTING_WEAPONS do
		grantTool(player, toolName)
	end
end

function WeaponGrantService.start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(0.25, grantStartingWeapons, player)
		end)

		task.delay(0.25, grantStartingWeapons, player)
	end)

	for _, player in Players:GetPlayers() do
		task.delay(0.25, grantStartingWeapons, player)
	end
end

return WeaponGrantService
