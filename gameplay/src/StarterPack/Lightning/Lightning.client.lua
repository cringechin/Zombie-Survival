local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local primaryFireHeld = false
local lastLocalFeedbackAt = 0
local lastLocalCastAt = 0
local stopFiring

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

local function castLightning()
	if not isLocalPlayerAlive() then
		primaryFireHeld = false
		stopFiring()
		return
	end

	local direction, targetPosition = getFlatAimDirection()
	if not direction then
		return
	end

	local now = os.clock()
	if now - lastLocalCastAt < LIGHTNING_COOLDOWN then
		return
	end

	lastLocalCastAt = now
	tool:SetAttribute("CooldownDuration", LIGHTNING_COOLDOWN)
	tool:SetAttribute("CooldownEndsAt", now + LIGHTNING_COOLDOWN)

	Network.disasterWeaponCast.send({
		weapon = "Lightning",
		direction = direction,
		targetPosition = targetPosition or Vector3.zero,
	})

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

	if not isLocalPlayerAlive() then
		primaryFireHeld = false
		return
	end

	firing = true
	task.spawn(function()
		while firing and equipped and primaryFireHeld and isLocalPlayerAlive() do
			castLightning()
			task.wait(FIRE_INTERVAL)
		end

		primaryFireHeld = false
		firing = false
	end)
end

function stopFiring()
	firing = false
end

tool.Equipped:Connect(function()
	equipped = true
end)

tool.Unequipped:Connect(function()
	equipped = false
	primaryFireHeld = false
	stopFiring()
end)

tool.Activated:Connect(function()
	if not isLocalPlayerAlive() then
		primaryFireHeld = false
		stopFiring()
		return
	end

	primaryFireHeld = true
	startFiring()
end)

tool.Deactivated:Connect(function()
	primaryFireHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	if not primaryFireHeld then
		stopFiring()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		primaryFireHeld = false
		stopFiring()
	end
end)

RunService.Heartbeat:Connect(function()
	if not isLocalPlayerAlive() then
		primaryFireHeld = false
		stopFiring()
		return
	end

	if equipped and not firing and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		primaryFireHeld = true
		startFiring()
	end
end)

localPlayer:GetAttributeChangedSignal("IsDowned"):Connect(function()
	if localPlayer:GetAttribute("IsDowned") == true then
		primaryFireHeld = false
		stopFiring()
	end
end)
