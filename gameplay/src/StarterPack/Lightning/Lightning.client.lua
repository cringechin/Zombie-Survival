local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientFeedback = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientFeedback"))
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)

local MAX_RAY_DISTANCE = 1000
local LIGHTNING_COOLDOWN = DisasterWeaponConfig.Lightning.Cooldown
local FIRE_INTERVAL = LIGHTNING_COOLDOWN + 0.01

local localPlayer = Players.LocalPlayer
local tool = script.Parent
local firing = false
local equipped = false
local lastLocalFeedbackAt = 0

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

local function castLightning()
	local direction, targetPosition = getFlatAimDirection()
	if not direction then
		return
	end

	tool:SetAttribute("CooldownDuration", LIGHTNING_COOLDOWN)
	tool:SetAttribute("CooldownEndsAt", os.clock() + LIGHTNING_COOLDOWN)

	Network.disasterWeaponCast.send({
		weapon = "Lightning",
		direction = direction,
		targetPosition = targetPosition or Vector3.zero,
	})

	local now = os.clock()
	if now - lastLocalFeedbackAt > 0.08 then
		lastLocalFeedbackAt = now
		ClientFeedback.cameraKick(0.75, 0.13)
		ClientFeedback.screenFlash(Color3.fromRGB(112, 215, 255), 0.12, 0.9)
		ClientFeedback.castPulse(Color3.fromRGB(112, 215, 255))
	end
end

local function startFiring()
	if firing then
		return
	end

	firing = true
	task.spawn(function()
		while firing and equipped do
			castLightning()
			task.wait(FIRE_INTERVAL)
		end
	end)
end

local function stopFiring()
	firing = false
end

tool.Equipped:Connect(function()
	equipped = true
end)

tool.Unequipped:Connect(function()
	equipped = false
	stopFiring()
end)

tool.Activated:Connect(function()
	startFiring()
end)

tool.Deactivated:Connect(function()
	stopFiring()
end)
