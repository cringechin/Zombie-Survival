local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientFeedback = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientFeedback"))
local Sounds = require(
	Players.LocalPlayer
		:WaitForChild("PlayerScripts")
		:WaitForChild("UI")
		:WaitForChild("Components")
		:WaitForChild("GameplaySounds")
)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)

local MAX_RAY_DISTANCE = 1000
local METEOR_CONFIG = DisasterWeaponConfig.Meteor

local localPlayer = Players.LocalPlayer
local tool = script.Parent
local previewPart = nil
local previewTween = nil
local getFlatAimDirection

local function isLocalPlayerAlive()
	if localPlayer:GetAttribute("IsDowned") == true then
		return false
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function getMeteorLevel()
	return localPlayer:GetAttribute("MeteorLevel") or 0
end

local function clampAimTargetToRange(rootPosition, targetPosition)
	local flatDelta = Vector3.new(targetPosition.X - rootPosition.X, 0, targetPosition.Z - rootPosition.Z)
	local magnitude = flatDelta.Magnitude
	if magnitude <= 0.05 then
		return rootPosition + Vector3.new(0, 0, -1)
	end

	local clampedDistance = math.min(magnitude, METEOR_CONFIG.Range or 95)
	local flatPosition = rootPosition + (flatDelta.Unit * clampedDistance)
	return Vector3.new(flatPosition.X, targetPosition.Y, flatPosition.Z)
end

local function getGroundImpactPosition(targetPosition)
	local zombiesFolder = Workspace:FindFirstChild("Zombies")
	local filterList = {
		localPlayer.Character,
	}
	if zombiesFolder then
		table.insert(filterList, zombiesFolder)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filterList

	local result = Workspace:Raycast(targetPosition + Vector3.new(0, 80, 0), Vector3.new(0, -180, 0), raycastParams)
	return result and result.Position or targetPosition
end

local function ensurePreviewPart()
	if previewPart and previewPart.Parent then
		return previewPart
	end

	local ring = Instance.new("Part")
	ring.Name = "MeteorLandingPreview"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 126, 45)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, METEOR_CONFIG.FireRadius * 2, METEOR_CONFIG.FireRadius * 2)
	ring.Transparency = 0.42
	ring.Parent = Workspace
	previewPart = ring

	local light = Instance.new("PointLight")
	light.Name = "MeteorLandingGlow"
	light.Brightness = 1.3
	light.Color = Color3.fromRGB(255, 126, 45)
	light.Range = METEOR_CONFIG.FireRadius * 0.55
	light.Parent = ring

	previewTween = TweenService:Create(
		ring,
		TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			Size = Vector3.new(0.16, METEOR_CONFIG.FireRadius * 2.18, METEOR_CONFIG.FireRadius * 2.18),
			Transparency = 0.24,
		}
	)
	previewTween:Play()

	return previewPart
end

local function hidePreviewPart()
	if previewTween then
		previewTween:Cancel()
		previewTween = nil
	end

	if previewPart and previewPart.Parent then
		previewPart:Destroy()
	end
	previewPart = nil
end

local function showLockedLandingPreview(targetPosition)
	if getMeteorLevel() < 4 then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local clampedTargetPosition = clampAimTargetToRange(root.Position, targetPosition)
	local groundImpact = getGroundImpactPosition(clampedTargetPosition)
	local ring = ensurePreviewPart()
	ring.CFrame = CFrame.new(groundImpact + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90))
	task.delay((METEOR_CONFIG.AirStrikeFallTime or 0.9) + 0.75, function()
		if previewPart == ring and ring.Parent then
			if previewTween then
				previewTween:Cancel()
				previewTween = nil
			end
			ring:Destroy()
			previewPart = nil
		end
	end)
end

local function getMeteorCooldown()
	local meteorLevel = getMeteorLevel()
	if meteorLevel >= 1 and meteorLevel <= 3 then
		return METEOR_CONFIG.HandCooldown or METEOR_CONFIG.Cooldown
	end

	return METEOR_CONFIG.Cooldown
end

getFlatAimDirection = function()
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

tool.Equipped:Connect(function()
	-- Preview for stage 4/5 is click-triggered only.
end)

tool.Unequipped:Connect(function()
	hidePreviewPart()
end)

tool.Activated:Connect(function()
	if not isLocalPlayerAlive() then
		hidePreviewPart()
		return
	end

	if getMeteorLevel() <= 0 then
		return
	end

	local cooldownEndsAt = tool:GetAttribute("CooldownEndsAt")
	if typeof(cooldownEndsAt) == "number" and cooldownEndsAt > os.clock() then
		return
	end

	local direction, targetPosition = getFlatAimDirection()
	if not direction then
		return
	end

	showLockedLandingPreview(targetPosition)
	Sounds.play("danger")
	ClientFeedback.cameraKick(if getMeteorLevel() >= 4 then 1.65 else 1.1, 0.22)
	ClientFeedback.screenFlash(Color3.fromRGB(255, 132, 54), 0.18, 0.88)
	ClientFeedback.castPulse(Color3.fromRGB(255, 132, 54))

	local cooldown = getMeteorCooldown()
	tool:SetAttribute("CooldownDuration", cooldown)
	tool:SetAttribute("CooldownEndsAt", os.clock() + cooldown)

	Network.disasterWeaponCast.send({
		weapon = "Meteor",
		direction = direction,
		targetPosition = targetPosition or Vector3.zero,
	})
end)

localPlayer:GetAttributeChangedSignal("IsDowned"):Connect(function()
	if localPlayer:GetAttribute("IsDowned") == true then
		hidePreviewPart()
	end
end)

tool.Destroying:Connect(hidePreviewPart)
