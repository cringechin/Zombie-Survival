local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientFeedback = require(script.Parent:WaitForChild("ClientFeedback"))
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local Sounds = require(script.Parent:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GameplaySounds"))

local GearPlacementController = {}

local LIGHTNING_TURRET_ID = "LightningTurret"
local MAX_RAY_DISTANCE = 800
local PREVIEW_VALID_COLOR = Color3.fromRGB(85, 214, 255)
local PREVIEW_INVALID_COLOR = Color3.fromRGB(255, 95, 95)
local GRID_VALID_COLOR = Color3.fromRGB(80, 235, 120)
local GRID_INVALID_COLOR = Color3.fromRGB(255, 90, 90)
local HINT_GUI_NAME = "GearPlacementHint"

local localPlayer = Players.LocalPlayer

local state = {
	Active = false,
	Gear = nil,
	Config = nil,
	PreviewModel = nil,
	GridPart = nil,
	InputConnection = nil,
	RenderConnection = nil,
	LastPlacementRequest = nil,
	LastPlacementCFrame = nil,
	LastCanPlace = false,
	HintGui = nil,
	HintLabel = nil,
	StartedAt = 0,
}

local function snapToGrid(position, gridSize)
	if gridSize <= 0 then
		return position
	end

	return Vector3.new(
		math.floor((position.X / gridSize) + 0.5) * gridSize,
		position.Y,
		math.floor((position.Z / gridSize) + 0.5) * gridSize
	)
end

local function clampPlacementDistance(origin, target, maxDistance)
	local flatDelta = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	if flatDelta.Magnitude <= maxDistance then
		return target
	end

	return Vector3.new(origin.X, target.Y, origin.Z) + (flatDelta.Unit * maxDistance)
end

local function destroyPreview()
	if state.GridPart and state.GridPart.Parent then
		state.GridPart:Destroy()
	end
	state.GridPart = nil

	if state.PreviewModel and state.PreviewModel.Parent then
		state.PreviewModel:Destroy()
	end
	state.PreviewModel = nil
end

local function destroyHintGui()
	if state.HintGui and state.HintGui.Parent then
		state.HintGui:Destroy()
	end
	state.HintGui = nil
	state.HintLabel = nil
end

local function createHintGui()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local existing = playerGui:FindFirstChild(HINT_GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = HINT_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 120
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -66)
	frame.Size = UDim2.fromOffset(300, 42)
	frame.BackgroundColor3 = Color3.fromRGB(15, 21, 36)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(82, 172, 255)
	stroke.Thickness = 1.4
	stroke.Transparency = 0.15
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "LMB: Place Turret    RMB / Esc: Cancel"
	label.TextColor3 = Color3.fromRGB(228, 240, 255)
	label.TextStrokeColor3 = Color3.fromRGB(14, 16, 22)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = frame

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 20
	sizeConstraint.MinTextSize = 14
	sizeConstraint.Parent = label

	state.HintGui = screenGui
	state.HintLabel = label

	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

local function disconnectPlacementSignals()
	if state.InputConnection then
		state.InputConnection:Disconnect()
		state.InputConnection = nil
	end

	if state.RenderConnection then
		state.RenderConnection:Disconnect()
		state.RenderConnection = nil
	end
end

local function cancelPlacement()
	state.Active = false
	state.Gear = nil
	state.Config = nil
	state.LastPlacementRequest = nil
	state.LastPlacementCFrame = nil
	state.LastCanPlace = false
	disconnectPlacementSignals()
	destroyPreview()
	destroyHintGui()
end

local function createPreviewModel()
	local model = Instance.new("Model")
	model.Name = "LightningTurretPreview"

	local function createPart(name, size, cframe, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = material or Enum.Material.SmoothPlastic
		part.Color = PREVIEW_VALID_COLOR
		part.Transparency = 0.55
		part.Size = size
		part.CFrame = cframe
		part.Parent = model
		return part
	end

	local root = createPart("HumanoidRootPart", Vector3.new(3, 2.2, 3), CFrame.new(), Enum.Material.ForceField)
	model.PrimaryPart = root
	createPart("Base", Vector3.new(3.6, 0.9, 3.6), CFrame.new(0, -1.55, 0), Enum.Material.ForceField)
	createPart("Coil", Vector3.new(1.8, 2.2, 1.8), CFrame.new(0, 0.9, 0), Enum.Material.Neon)
	createPart("Head", Vector3.new(1.3, 0.6, 1.3), CFrame.new(0, 2.1, 0), Enum.Material.Neon)

	model.Parent = Workspace
	return model
end

local function createGridPart(gridSize)
	local gridPart = Instance.new("Part")
	gridPart.Name = "TurretPlacementGrid"
	gridPart.Anchored = true
	gridPart.CanCollide = false
	gridPart.CanTouch = false
	gridPart.CanQuery = false
	gridPart.Material = Enum.Material.Neon
	gridPart.Color = GRID_VALID_COLOR
	gridPart.Transparency = 0.6
	gridPart.Size = Vector3.new(math.max(gridSize - 0.2, 1), 0.15, math.max(gridSize - 0.2, 1))
	gridPart.Parent = Workspace

	local selection = Instance.new("SelectionBox")
	selection.Name = "Outline"
	selection.Adornee = gridPart
	selection.Color3 = GRID_VALID_COLOR
	selection.LineThickness = 0.035
	selection.Parent = gridPart

	return gridPart
end

local function getPlacementExclusions()
	local exclusions = {}
	local character = localPlayer.Character
	if character then
		table.insert(exclusions, character)
	end

	if state.PreviewModel then
		table.insert(exclusions, state.PreviewModel)
	end

	local zombiesFolder = Workspace:FindFirstChild("Zombies")
	if zombiesFolder then
		table.insert(exclusions, zombiesFolder)
	end

	return exclusions
end

local function getMouseWorldPosition()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = getPlacementExclusions()

	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
	return result and result.Position or nil
end

local function getGroundPosition(position, exclusions)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = exclusions
	local result = Workspace:Raycast(position + Vector3.new(0, 55, 0), Vector3.new(0, -150, 0), raycastParams)
	return result and result.Position or nil, result and result.Instance or nil
end

local function isPlacementFree(groundPosition, exclusions, ignoredPart)
	local filter = table.clone(exclusions)
	local defensesFolder = Workspace:FindFirstChild("Defenses")
	local shouldIgnoreGroundPart = ignoredPart and (not defensesFolder or not ignoredPart:IsDescendantOf(defensesFolder))
	if shouldIgnoreGroundPart then
		table.insert(filter, ignoredPart)
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = filter

	local boxSize = Vector3.new(4.2, 5.2, 4.2)
	local boxCFrame = CFrame.new(groundPosition + Vector3.new(0, 2.8, 0))
	local parts = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)

	for _, part in parts do
		if part.CanCollide and part.Transparency < 1 then
			return false
		end
	end

	return true
end

local function isGroundPartDefense(groundPart)
	local defensesFolder = Workspace:FindFirstChild("Defenses")
	if not defensesFolder or not groundPart then
		return false
	end

	return groundPart:IsDescendantOf(defensesFolder)
end

local function setPreviewColor(canPlace)
	local previewColor = if canPlace then PREVIEW_VALID_COLOR else PREVIEW_INVALID_COLOR
	local gridColor = if canPlace then GRID_VALID_COLOR else GRID_INVALID_COLOR

	if state.PreviewModel then
		for _, descendant in state.PreviewModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = previewColor
			end
		end
	end

	if state.GridPart then
		state.GridPart.Color = gridColor
		local selection = state.GridPart:FindFirstChild("Outline")
		if selection and selection:IsA("SelectionBox") then
			selection.Color3 = gridColor
		end
	end

	if state.HintLabel then
		if canPlace then
			state.HintLabel.Text = "LMB: Place Turret    RMB / Esc: Cancel"
			state.HintLabel.TextColor3 = Color3.fromRGB(228, 240, 255)
		else
			state.HintLabel.Text = "Can't place here    RMB / Esc: Cancel"
			state.HintLabel.TextColor3 = Color3.fromRGB(255, 118, 118)
		end
	end
end

local function updatePlacementPreview()
	if not state.Active or not state.Config then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		state.LastCanPlace = false
		setPreviewColor(false)
		return
	end

	local targetPosition = getMouseWorldPosition()
	if not targetPosition then
		state.LastCanPlace = false
		setPreviewColor(false)
		return
	end

	local config = state.Config
	local clampedTarget = clampPlacementDistance(root.Position, targetPosition, config.MaxPlacementDistance)
	local snappedTarget = snapToGrid(clampedTarget, config.GridSize)
	local exclusions = getPlacementExclusions()
	local groundPosition, groundPart = getGroundPosition(snappedTarget, exclusions)
	if not groundPosition then
		state.LastCanPlace = false
		setPreviewColor(false)
		return
	end

	local canPlace = (not isGroundPartDefense(groundPart)) and isPlacementFree(groundPosition, exclusions, groundPart)
	local placementPosition = Vector3.new(snappedTarget.X, groundPosition.Y + 2.1, snappedTarget.Z)
	local placementCFrame = CFrame.lookAt(
		placementPosition,
		Vector3.new(root.Position.X, placementPosition.Y, root.Position.Z)
	)

	if state.PreviewModel then
		local elapsed = os.clock() - state.StartedAt
		local hoverOffset = Vector3.new(0, math.sin(elapsed * 5.5) * 0.12, 0)
		local yaw = math.sin(elapsed * 3) * math.rad(2)
		state.PreviewModel:PivotTo((placementCFrame + hoverOffset) * CFrame.Angles(0, yaw, 0))
	end

	if state.GridPart then
		local pulse = 1 + (math.sin((os.clock() - state.StartedAt) * 6) * 0.08)
		state.GridPart.CFrame = CFrame.new(snappedTarget.X, groundPosition.Y + 0.08, snappedTarget.Z)
		state.GridPart.Size = Vector3.new(
			math.max((config.GridSize or 6) - 0.2, 1) * pulse,
			0.15,
			math.max((config.GridSize or 6) - 0.2, 1) * pulse
		)
	end

	state.LastCanPlace = canPlace
	state.LastPlacementCFrame = placementCFrame
	state.LastPlacementRequest = Vector3.new(snappedTarget.X, groundPosition.Y, snappedTarget.Z)
	setPreviewColor(canPlace)
end

local function bindPlacementInputs()
	state.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not state.Active then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if state.LastCanPlace and state.LastPlacementRequest and state.Gear then
				Network.gearPurchaseRequest.send({
					gear = state.Gear,
					position = state.LastPlacementRequest,
				})
				Sounds.play("success")
				ClientFeedback.cameraKick(0.15, 0.12, 0.8)
				ClientFeedback.worldBurst(state.LastPlacementRequest, Color3.fromRGB(95, 215, 255), 8)
				cancelPlacement()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
			Sounds.play("click")
			cancelPlacement()
		end
	end)

	state.RenderConnection = RunService.RenderStepped:Connect(updatePlacementPreview)
end

local function getConfigForGear(gear)
	if gear == LIGHTNING_TURRET_ID then
		return GameConfig.Defenses and GameConfig.Defenses.LightningTurret
	end

	return nil
end

function GearPlacementController.beginGearPlacement(gear)
	local config = getConfigForGear(gear)
	if not config then
		return false
	end

	if state.Active and state.Gear == gear then
		Sounds.play("click")
		cancelPlacement()
		return false
	end

	cancelPlacement()
	Sounds.play("info")

	state.Active = true
	state.Gear = gear
	state.Config = config
	state.StartedAt = os.clock()
	state.PreviewModel = createPreviewModel()
	state.GridPart = createGridPart(config.GridSize or 6)
	createHintGui()
	bindPlacementInputs()
	updatePlacementPreview()

	return true
end

function GearPlacementController.cancelPlacement()
	cancelPlacement()
end

return GearPlacementController
