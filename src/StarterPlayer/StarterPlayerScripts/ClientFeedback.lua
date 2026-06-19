local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClientFeedback = {}

local localPlayer = Players.LocalPlayer
local CAMERA_SHAKE_BINDING = "ZombieSurvivalCameraShake"
local activeCameraShake = false
local cameraShakeToken = 0

local function getFeedbackGui()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	local gui = playerGui:FindFirstChild("ActionFeedback")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "ActionFeedback"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 160
	gui.Parent = playerGui

	return gui
end

function ClientFeedback.cameraKick(intensity, duration)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	intensity = intensity or 0.25
	duration = duration or 0.18

	if activeCameraShake then
		RunService:UnbindFromRenderStep(CAMERA_SHAKE_BINDING)
		activeCameraShake = false
	end

	local startTime = os.clock()
	local seed = math.random() * 1000
	cameraShakeToken += 1
	local shakeToken = cameraShakeToken

	activeCameraShake = true
	RunService:BindToRenderStep(CAMERA_SHAKE_BINDING, Enum.RenderPriority.Camera.Value + 3, function()
		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local fade = (1 - alpha) * (1 - alpha)
		local time = (os.clock() - startTime) * 38
		local yaw = math.noise(seed, time, 0) * intensity * fade
		local pitch = math.noise(seed, 0, time) * intensity * 0.72 * fade
		local roll = math.sin(time * 1.35 + seed) * intensity * 0.38 * fade

		camera = Workspace.CurrentCamera
		if not camera or shakeToken ~= cameraShakeToken then
			RunService:UnbindFromRenderStep(CAMERA_SHAKE_BINDING)
			activeCameraShake = false
			return
		end

		local baseCFrame = camera.CFrame
		local shakenCFrame = baseCFrame * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
		camera.CFrame = CFrame.new(baseCFrame.Position) * shakenCFrame.Rotation

		if alpha >= 1 then
			RunService:UnbindFromRenderStep(CAMERA_SHAKE_BINDING)
			activeCameraShake = false
		end
	end)
end

function ClientFeedback.screenFlash(color, duration, peakTransparency)
	local gui = getFeedbackGui()
	if not gui then
		return
	end

	local flash = Instance.new("Frame")
	flash.Name = "ScreenFlash"
	flash.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 200
	flash.Parent = gui

	local fadeIn = TweenService:Create(flash, TweenInfo.new(0.035, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = peakTransparency or 0.82,
	})
	fadeIn:Play()
	fadeIn.Completed:Once(function()
		if not flash.Parent then
			return
		end

		local fadeOut = TweenService:Create(flash, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		fadeOut:Play()
		fadeOut.Completed:Once(function()
			if flash.Parent then
				flash:Destroy()
			end
		end)
	end)
end

function ClientFeedback.castPulse(color)
	local gui = getFeedbackGui()
	if not gui then
		return
	end

	local ring = Instance.new("Frame")
	ring.Name = "CastPulse"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(28, 28)
	ring.ZIndex = 201
	ring.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Parent = ring

	TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(74, 74),
	}):Play()

	local fade = TweenService:Create(stroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Thickness = 0,
	})
	fade:Play()
	fade.Completed:Once(function()
		if ring.Parent then
			ring:Destroy()
		end
	end)
end

function ClientFeedback.worldBurst(position, color, radius)
	local burst = Instance.new("Part")
	burst.Name = "PlacementBurst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CastShadow = false
	burst.Material = Enum.Material.Neon
	burst.Color = color or Color3.fromRGB(95, 210, 255)
	burst.Shape = Enum.PartType.Cylinder
	burst.Size = Vector3.new(0.08, 0.2, 0.2)
	burst.Transparency = 0.15
	burst.CFrame = CFrame.new(position + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90))
	burst.Parent = Workspace

	local size = radius or 6
	local tween = TweenService:Create(burst, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, size, size),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		if burst.Parent then
			burst:Destroy()
		end
	end)
end

return ClientFeedback
