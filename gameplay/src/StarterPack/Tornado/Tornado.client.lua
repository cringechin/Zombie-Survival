local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientFeedback = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientFeedback"))
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)

local MAX_RAY_DISTANCE = 1000
local TORNADO_CONFIG = DisasterWeaponConfig.Tornado

local localPlayer = Players.LocalPlayer
local tool = script.Parent
local lastLocalCastAt = 0

local function isLocalPlayerAlive()
	if localPlayer:GetAttribute("IsDowned") == true then
		return false
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function getFlatAimDirection()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		localPlayer.Character,
	}

	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
	local worldPosition = result and result.Position or (ray.Origin + (ray.Direction * 180))

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local flatDirection = Vector3.new(worldPosition.X - root.Position.X, 0, worldPosition.Z - root.Position.Z)
	if flatDirection.Magnitude <= 0.05 then
		local lookVector = camera.CFrame.LookVector
		flatDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
	end

	if flatDirection.Magnitude <= 0.05 then
		return nil, nil
	end

	return flatDirection.Unit, worldPosition
end

tool.Activated:Connect(function()
	if not isLocalPlayerAlive() then
		return
	end

	local now = os.clock()
	local cooldownEndsAt = tool:GetAttribute("CooldownEndsAt")
	if typeof(cooldownEndsAt) == "number" and cooldownEndsAt > now then
		return
	end

	if now - lastLocalCastAt < TORNADO_CONFIG.Cooldown then
		return
	end

	lastLocalCastAt = now
	local direction, targetPosition = getFlatAimDirection()
	if not direction then
		return
	end

	local cooldown = TORNADO_CONFIG.Cooldown
	tool:SetAttribute("CooldownDuration", cooldown)
	tool:SetAttribute("CooldownEndsAt", now + cooldown)

	ClientFeedback.cameraKick(0.9, 0.18)
	ClientFeedback.screenFlash(Color3.fromRGB(190, 235, 235), 0.14, 0.82)
	ClientFeedback.castPulse(Color3.fromRGB(190, 235, 235))

	Network.disasterWeaponCast.send({
		weapon = "Tornado",
		direction = direction,
		targetPosition = targetPosition or Vector3.zero,
	})
end)
