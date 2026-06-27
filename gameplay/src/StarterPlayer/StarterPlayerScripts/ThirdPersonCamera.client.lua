local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local CAMERA_BINDING = "ZombieSurvivalCameraPolish"
local SHOULDER_OFFSET = Vector3.new(1.45, 0.35, 0)
local OFFSET_SMOOTHNESS = 12
local FOV_SMOOTHNESS = 8
local DEFAULT_FOV = 70
local SHIFTLOCK_FOV = 72

local character = nil
local humanoid = nil
local currentOffset = Vector3.zero
local reticleGui = nil

local function createReticlePart(parent, name, size, position)
	local part = Instance.new("Frame")
	part.Name = name
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.BackgroundColor3 = Color3.fromRGB(235, 248, 255)
	part.BackgroundTransparency = 0.16
	part.BorderSizePixel = 0
	part.Position = position
	part.Size = size
	part.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 28, 34)
	stroke.Transparency = 0.45
	stroke.Thickness = 1
	stroke.Parent = part
end

local function ensureReticle()
	if reticleGui and reticleGui.Parent then
		return reticleGui
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShiftLockReticle"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 120
	gui.Enabled = false
	gui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Reticle"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromOffset(26, 26)
	container.Parent = gui

	createReticlePart(container, "Top", UDim2.fromOffset(2, 6), UDim2.fromScale(0.5, 0.2))
	createReticlePart(container, "Bottom", UDim2.fromOffset(2, 6), UDim2.fromScale(0.5, 0.8))
	createReticlePart(container, "Left", UDim2.fromOffset(6, 2), UDim2.fromScale(0.2, 0.5))
	createReticlePart(container, "Right", UDim2.fromOffset(6, 2), UDim2.fromScale(0.8, 0.5))

	reticleGui = gui
	return gui
end

local function setCharacter(nextCharacter)
	character = nextCharacter
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	currentOffset = Vector3.zero

	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
	end
end

local function refreshCharacter()
	if character ~= localPlayer.Character then
		setCharacter(localPlayer.Character)
		return
	end

	if character and (not humanoid or not humanoid.Parent) then
		humanoid = character:FindFirstChildOfClass("Humanoid")
	end
end

local function isShiftLockActive()
	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

local function updateCameraPolish(deltaTime)
	refreshCharacter()

	local camera = Workspace.CurrentCamera
	local locked = isShiftLockActive()
	local targetOffset = if locked then SHOULDER_OFFSET else Vector3.zero
	local offsetAlpha = 1 - math.exp(-OFFSET_SMOOTHNESS * deltaTime)
	currentOffset = currentOffset:Lerp(targetOffset, offsetAlpha)

	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = currentOffset
	end

	if camera then
		local targetFov = if locked then SHIFTLOCK_FOV else DEFAULT_FOV
		local fovAlpha = 1 - math.exp(-FOV_SMOOTHNESS * deltaTime)
		camera.FieldOfView += (targetFov - camera.FieldOfView) * fovAlpha
	end

	ensureReticle().Enabled = locked
end

localPlayer.CharacterAdded:Connect(setCharacter)
localPlayer.CharacterRemoving:Connect(function()
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
		humanoid.AutoRotate = true
	end

	setCharacter(nil)
end)

setCharacter(localPlayer.Character)
RunService:BindToRenderStep(CAMERA_BINDING, Enum.RenderPriority.Camera.Value + 1, updateCameraPolish)
